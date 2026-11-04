"""Original offline cylinder-pulse/resonator synthesis; no recordings or engine-sim code.
PCM banks are periodic in whole 720-degree cycles and use absolute source RPM metadata.
"""
from pathlib import Path
import argparse, hashlib, json, math, wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'assets/audio/engines'; OUT.mkdir(parents=True,exist_ok=True)
RATE=22050; ANCHORS=[650,800,1000,1250,1560,1950,2440,3050,3810,4760,5950,7440,9300,11625]
DESIGNS=json.loads((ROOT/'assets/audio/engine_designs.json').read_text())['vehicles']
# cylinders, exhaust-bank imbalance, exhaust resonances, air resonance, smoothness
FAMILIES={
'i4_na':(4,.04,[110,240,630,1550],1350,.06),'i4_vtec':(4,.02,[135,310,840,2250],1900,.04),
'i4_turbo':(4,.04,[95,205,540,1300],1450,.05),'h4_na':(4,.11,[100,230,500,1250],1300,.08),
'h4_turbo':(4,.32,[80,170,430,1050],1150,.15),'i6_na':(6,.02,[120,270,750,1800],1600,.02),
'i6_turbo':(6,.03,[85,185,460,1200],1350,.03),'vr6_na':(6,.14,[95,195,580,1500],1300,.10),
'v6_na':(6,.12,[105,260,670,1750],1550,.08),'v6_tt':(6,.08,[80,195,510,1400],1500,.06),
'v8_cross':(8,.30,[65,145,360,950],1000,.14),'v8_flat':(8,.03,[110,280,700,2100],1900,.03),
'v8_super':(8,.27,[60,130,330,850],1100,.13),'v8_flat_tt':(8,.035,[90,210,590,1700],1750,.035),
'v10_na':(10,.045,[115,290,850,2400],2100,.025),'h6_na':(6,.09,[105,235,650,1700],1650,.04),
'h6_turbo':(6,.08,[85,195,530,1350],1500,.04),'w16_tt':(16,.10,[55,125,310,900],1350,.025)}

def shaped(signal, freqs, resonances, cutoff):
 f=np.fft.rfftfreq(len(signal),1/RATE)
 eq=np.full_like(f,.16)
 for j,res in enumerate(resonances): eq += (1.0/(1+j*.65))*np.exp(-.5*((f-res)/(res*.40+30))**2)
 eq*=1/(1+(f/cutoff)**4); eq*=1-np.exp(-(f/28)**2)
 return np.fft.irfft(np.fft.rfft(signal)*eq,len(signal))

def synth(family,rpm,layer,design=None,identity=None):
 cyl,imb,res,air,irregular=FAMILIES[family]; cycles=max(6,round(rpm/120*1.15)); n=round(cycles*120/rpm*RATE)
 if design:
  res=design['resonances'];air=design['intake_hz'];irregular=design['roughness']
 actual=cycles*120*RATE/n; t=np.arange(n)/RATE; cycle=np.arange(n)/n*cycles
 # Per-bank unequal exhaust arrival reproduces bank-pulse structure, not arbitrary RPM offsets.
 left=np.zeros(n); right=np.zeros(n)
 for event in range(cycles*cyl):
  bank=event%2
  if family in ('v8_cross','v8_super'): bank=[0,1,0,0,1,0,1,1][event%8]
  elif family=='h4_turbo': bank=[0,0,1,1][event%4]
  phase=event/cyl/cycles
  # Runner arrival differences are acoustic delays, not changes to firing RPM.
  runner=(design['runner_ms'][event%cyl]/1000) if design else 0
  jitter=irregular*.00010*math.sin(event*2.399)+runner
  index=int(round((phase*n+jitter*RATE)))%n
  (left if bank==0 else right)[index]+=1+irregular*math.sin(event*1.19)
 f=np.fft.rfftfreq(n,1/RATE)
 # Damped pressure pulse; circular filtering makes all seams periodic.
 decay=(design['pulse_ms']/1000 if design else .0014)*(1 if layer.endswith('on') else 1.7)
 kernel=np.exp(-np.arange(n)/RATE/decay)-.64*np.exp(-np.arange(n)/RATE/(decay*3))
 bank_delay=0 if design else .00025+imb*.006
 train=np.fft.irfft((np.fft.rfft(left)+np.fft.rfft(right)*np.exp(-2j*np.pi*f*bank_delay))*np.fft.rfft(kernel),n)
 rng=np.random.default_rng(int(hashlib.sha256(((identity or family)+layer+str(rpm)).encode()).hexdigest()[:8],16))
 noise=rng.normal(0,1,n); engine_hz=actual*cyl/120
 if layer.startswith('exhaust'):
  on=layer.endswith('on'); y=shaped(train,None,res,3900 if on else 1650)
  y/=max(1e-8,np.sqrt(np.mean(y*y))); y=np.tanh(y*(1.2 if on else .65))
  y+=shaped(noise,None,[650,1450,2800],4400)*(.065 if on else .025)
  y*=1+np.sin(2*np.pi*cycle)*irregular*.22
  target=.18 if on else .13
 elif layer.startswith('intake'):
  on=layer.endswith('on'); y=shaped(noise,None,[air,air*1.9],6500)*(0.45+0.55*np.clip(train/max(.01,np.max(train)),0,1))
  y+=shaped(train,None,[air*.6,air],4500)*.18; target=.09 if on else .035
 else:
  y=shaped(noise,None,[900,2600,4800],6500)*.4
  y+=np.sin(2*np.pi*cycle*cyl*2)*.04+shaped(train,None,[500,1700],4000)*.12; target=.055
 y-=np.mean(y); y*=target/max(1e-8,np.sqrt(np.mean(y*y)))
 y=np.tanh(y); pcm=np.round(y*32767).astype('<i2')
 return pcm,actual

def build(names,vehicles=False,vehicle_ids=None):
 manifest={"format_version":2,"sample_rate":RATE,"origin":"Original offline cylinder-pulse and resonator synthesis; not recorded vehicles and not engine-sim output","families":{},"vehicles":{}}
 prior=OUT/'bank.json'
 if prior.exists(): manifest=json.loads(prior.read_text())
 manifest['format_version']=2
 for family in names:
  folder=OUT/family; folder.mkdir(exist_ok=True); rows=[]
  for rpm in ANCHORS:
   files={}; actual=None
   for layer in ['exhaust_on','exhaust_off','intake_on','intake_off','mechanical']:
    pcm,actual=synth(family,rpm,layer); path=folder/f'{rpm}_{layer}.wav'
    with wave.open(str(path),'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(pcm.tobytes())
    files[layer]='res://'+str(path.relative_to(ROOT)).replace('\\','/')
   rows.append({"rpm":actual,"nominal_rpm":rpm,"files":files})
  manifest['families'][family]=rows; print(family,flush=True)
 if vehicles:
  manifest.setdefault('vehicles',{})
  for identity,design in DESIGNS.items():
   if vehicle_ids and identity not in vehicle_ids: continue
   family=design['family'];folder=OUT/('vehicle_'+identity);folder.mkdir(exist_ok=True);rows=[]
   for rpm in ANCHORS:
    files={}
    for layer in ['exhaust_on','exhaust_off','intake_on','intake_off','mechanical']:
     pcm,actual=synth(family,rpm,layer,design,identity);path=folder/f'{rpm}_{layer}.wav'
     with wave.open(str(path),'wb') as w: w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(pcm.tobytes())
     files[layer]='res://'+str(path.relative_to(ROOT)).replace('\\','/')
    rows.append({'rpm':actual,'nominal_rpm':rpm,'files':files})
   manifest['vehicles'][identity]={'family':family,'rows':rows,'design':design,'origin':'Original synthesized acoustic approximation, not an OEM recording'}
   print(identity,flush=True)
 prior.write_text(json.dumps(manifest,indent=2)+'\n')
 files=[]
 for p in sorted(OUT.glob('*/*.wav')):
  files.append({"path":str(p.relative_to(ROOT)).replace('\\','/'),"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"author":"REDLINE project procedural audio generator","source":"tools/generate_engine_audio.py","license":"Original project-generated audio; no external recording incorporated","attribution_required":False,"intended_use":"RPM and load engine bank"})
 (ROOT/'assets/audio/asset_manifest.json').write_text(json.dumps({"assets":files,"external_recordings":[],"note":"Do not describe these synthetic engine loops as authentic recordings."},indent=2)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser(); p.add_argument('--families',default=','.join(FAMILIES));p.add_argument('--vehicles',action='store_true');p.add_argument('--vehicle-ids',default=''); a=p.parse_args()
 selected=[x for x in a.vehicle_ids.split(',') if x]
 if set(selected)-set(DESIGNS): p.error('Unknown vehicle IDs')
 build([x for x in a.families.split(',') if x],a.vehicles or bool(selected),selected)
