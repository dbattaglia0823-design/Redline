"""Objective native-output review plus audition copies. Not a realism rating."""
from pathlib import Path
import json,math,wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
def read(path):
 with wave.open(str(path),'rb') as wav:
  assert wav.getsampwidth()==2
  rate=wav.getframerate(); channels=wav.getnchannels()
  samples=np.frombuffer(wav.readframes(wav.getnframes()),'<i2').astype(float).reshape(-1,channels)/32768
 return rate,samples
def metrics(rate,samples):
 return {'sample_rate':rate,'duration_s':len(samples)/rate,'rms':float(np.sqrt(np.mean(samples*samples))),'peak':float(np.max(np.abs(samples))),'dc':float(np.mean(samples)),'max_adjacent_step':float(np.max(np.abs(np.diff(samples,axis=0))))}
def power(rate,samples):
 x=samples.mean(axis=1); n=min(16384,len(x)); window=np.hanning(n)
 segments=[np.abs(np.fft.rfft(x[i:i+n]*window))**2 for i in range(0,len(x)-n+1,max(1,n//2))]
 return np.fft.rfftfreq(n,1/rate),np.mean(segments,axis=0)
def audition(source,destination):
 rate,samples=read(source); length=min(int(.020*rate),len(samples)//2)
 fade=np.sin(np.linspace(0,np.pi/2,length))**2
 samples[:length]*=fade[:,None];samples[-length:]*=fade[::-1,None]
 with wave.open(str(destination),'wb') as wav:
  wav.setnchannels(samples.shape[1]);wav.setsampwidth(2);wav.setframerate(rate)
  wav.writeframes(np.round(np.clip(samples,-1,1)*32767).astype('<i2').tobytes())

roster=json.loads((ROOT/'assets/data/roster.json').read_text())
rows=[]
for identity in roster:
 path=ROOT/'validation'/f'native_engine_{identity}.wav';rate,samples=read(path)
 values=metrics(rate,samples)
 assert values['peak']<.84 and values['rms']>.001 and abs(values['dc'])<.01,(identity,values)
 loaded=samples[round(.35*rate):round(.75*rate)]
 lifted=samples[round(1.05*rate):round(1.25*rate)]
 values['loaded_rms']=float(np.sqrt(np.mean(loaded**2)));values['lift_rms']=float(np.sqrt(np.mean(lifted**2)))
 values['load_to_lift_db']=20*math.log10(max(1e-9,values['lift_rms'])/max(1e-9,values['loaded_rms']))
 before=ROOT/'validation/audio_baseline'/path.name
 if before.exists():
  br,bs=read(before);values['previous_capture_peak']=metrics(br,bs)['peak']
 rows.append({'id':identity,'engine':roster[identity]['engine'],**values})

out=ROOT/'validation/audio_listening';out.mkdir(exist_ok=True)
listening=[];steady=[];pulls=[]
for path in sorted((ROOT/'validation/audio_steady').glob('*.wav')):
 rate,samples=read(path); values=metrics(rate,samples)
 assert values['duration_s']>=3.0 and values['peak']<.84 and values['rms']>.001
 assert values['max_adjacent_step']<.25,(path,'Unexpected native sample discontinuity',values)
 steady.append({'id':path.stem,**values})
 destination=out/('steady_'+path.name);audition(path,destination);listening.append(str(destination.relative_to(ROOT)))
for identity in ['mustang','sti','s2000','chiron']:
 for build in ['stock','upgraded']:
  path=ROOT/'validation/audio_demo'/f'{identity}_{build}.wav';rate,samples=read(path);values=metrics(rate,samples)
  assert values['duration_s']>=7.9 and values['peak']<.84 and values['rms']>.001
  pulls.append({'id':identity,'build':build,**values})
  destination=out/path.name;audition(path,destination);listening.append(str(destination.relative_to(ROOT)))
assert len(rows)==30 and len(steady)==10 and len(pulls)==8
result={'passed':True,'native_vehicles':rows,'steady_loops':steady,'physical_pulls':pulls,'listening_files':listening,'audition_processing':'20ms fades at file edges only; no loudness normalization or pitch alteration. Raw diagnostic captures retained.','limitations':'Numerical headroom/continuity tests do not establish absence of perceived clicks, authentic timbre, or speaker/device latency.'}
(ROOT/'validation/audio_quality_results.json').write_text(json.dumps(result,indent=2)+'\n')
(out/'README.md').write_text('# Listening comparisons\n\nOriginal synthesis, not vehicle recordings. Stock/upgraded files are eight-second native physics pulls. steady_* files are controlled 3000 RPM acoustic fixtures, not performance runs. Only 20ms edge fades were applied to listening copies; diagnostic originals are unchanged. No loudness normalization.\n\nUse F7 Audio Lab to repeat tests with current installed parts.\n')

try:
 import matplotlib
 matplotlib.use('Agg')
 import matplotlib.pyplot as plt
 pairs=[('s2000','sti'),('supra','m3'),('mustang','redeye'),('gtr','turbo_s'),('r8','chiron')]
 fig,axes=plt.subplots(5,1,figsize=(11,13),layout='constrained',facecolor='#07111c')
 for ax,pair in zip(axes,pairs):
  ax.set_facecolor('#0c1b29')
  for identity,color in zip(pair,['#5eb9e3','#f18a4b']):
   rate,samples=read(ROOT/'validation/audio_steady'/f'{identity}.wav');f,p=power(rate,samples)
   db=10*np.log10(np.maximum(p,1e-14)/max(1e-14,p.max()))
   ax.semilogx(f,db,color=color,lw=1,label=roster[identity]['name'])
  ax.set_xlim(40,6500);ax.set_ylim(-65,3);ax.grid(alpha=.14);ax.tick_params(colors='#c4d3df')
  ax.set_ylabel('Relative power (dB)',color='#c4d3df');ax.legend(facecolor='#142839',labelcolor='white',loc='upper right')
 axes[-1].set_xlabel('Frequency (Hz)',color='#c4d3df')
 fig.suptitle('Native 3000 RPM spectra — tonal differences, not realism scores',color='white',fontsize=14)
 fig.savefig(ROOT/'validation/audio_spectral_comparison.png',dpi=140);plt.close(fig)
except ImportError:
 pass
print(json.dumps({'passed':True,'native_vehicles':len(rows),'steady_loop_captures':len(steady),'physics_pull_captures':len(pulls),'max_native_peak':max(row['peak'] for row in rows),'max_pull_peak':max(row['peak'] for row in pulls),'listening_copies':len(listening)}))
