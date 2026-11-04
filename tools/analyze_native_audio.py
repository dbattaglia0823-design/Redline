from pathlib import Path
import json, wave
import numpy as np
r=Path(__file__).resolve().parents[1]; rows=[]
for p in (r/'validation').glob('native_engine_*.wav'):
 with wave.open(str(p),'rb') as w:
  rate=w.getframerate(); channels=w.getnchannels(); data=np.frombuffer(w.readframes(w.getnframes()),'<i2').astype(float)/32768
 mono=data.reshape(-1,channels).mean(axis=1); start=mono[int(rate*.35):int(rate*.75)]
 spectrum=np.abs(np.fft.rfft(start*np.hanning(len(start))))**2; f=np.fft.rfftfreq(len(start),1/rate)
 rows.append({'vehicle':p.stem.removeprefix('native_engine_'),'rms':float(np.sqrt(np.mean(data*data))),'peak':float(np.max(np.abs(data))),'dc':float(np.mean(data)),'centroid_hz':float((f*spectrum).sum()/max(1e-12,spectrum.sum()))})
assert all(x['rms']>.001 and x['peak']<.98 and abs(x['dc'])<.01 for x in rows)
(r/'validation/native_audio_metrics.json').write_text(json.dumps({'passed':True,'captures':rows,'note':'Numerical measurements only; sound realism and subjective balance require listening.'},indent=2))
print(json.dumps({'passed':True,'captured_vehicles':len(rows),'max_peak':max(x['peak'] for x in rows)}))
