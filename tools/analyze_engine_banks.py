"""Objective bank checks. Does not substitute for listening tests."""
from pathlib import Path
import json, wave
import numpy as np
r=Path(__file__).resolve().parents[1]; folder=r/'assets/audio/engines'; bank=json.loads((folder/'bank.json').read_text()); rows=[]
collections=list(bank['families'].items())+[("vehicle_"+name,value['rows']) for name,value in bank.get('vehicles',{}).items()]
for family,anchors in collections:
 for anchor in anchors:
  for layer,path in anchor['files'].items():
   p=r/path.removeprefix('res://')
   with wave.open(str(p),'rb') as w: rate=w.getframerate(); data=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
   peak=float(np.max(np.abs(data))); rms=float(np.sqrt(np.mean(data*data))); seam=float(abs(data[0]-data[-1])); adjacent=float(np.max(np.abs(np.diff(data))))
   assert peak<.98 and rms>.005 and abs(float(np.mean(data)))<.01,(family,layer,peak,rms)
   assert seam<max(.04,adjacent*1.2),(family,layer,'loop seam',seam,adjacent)
   rows.append({'family':family,'rpm':anchor['rpm'],'layer':layer,'peak':peak,'rms':rms,'seam_jump':seam,'max_internal_step':adjacent})
(r/'validation/audio_bank_metrics.json').write_text(json.dumps({'passed':True,'files':len(rows),'families':len(bank['families']),'vehicles':len(bank.get('vehicles',{})),'rows':rows},indent=2))
print(json.dumps({'passed':True,'files':len(rows),'families':len(bank['families']),'vehicles':len(bank.get('vehicles',{})),'max_peak':max(x['peak'] for x in rows)}))
