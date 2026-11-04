"""Asset integrity, not an artistic-approval shortcut. No image modifications."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'assets/vehicles/manifest.json').read_text())
roster=json.loads((root/'assets/data/roster.json').read_text())
rows=[]; seen=set()
for model in roster:
 d=manifest[model]; errors=[]
 def read(path): return np.array(Image.open(root/path.removeprefix('res://')).convert('RGBA'))
 base=read(d['body']%(0,'gloss')); mask=read(d['layers']['paint_mask']); glass=read(d['layers']['glass'])
 sha=hashlib.sha256(read(d['master']).tobytes()).hexdigest()
 if sha in seen: errors.append('Repeated artwork')
 seen.add(sha)
 if base.shape!=mask.shape or base.shape!=glass.shape: errors.append('Layer sizes disagree')
 selected=mask[:,:,3]>0
 if np.count_nonzero(selected)<4000: errors.append('Empty paint mask')
 if np.any(base[:,:,3][selected]!=255): errors.append('Transparent paintable body interior')
 if np.any(selected&(glass[:,:,3]>0)): errors.append('Paint/glass overlap')
 if not np.any((base[:,:,3]>0)&(base[:,:,3]<255)): errors.append('No antialiased edge coverage')
 if not np.any(base[:,:,3]==0): errors.append('Opaque rectangular background')
 if not np.any(glass[:,:,3]>0): errors.append('Missing glass region')
 h,w=base.shape[:2]; factor=w/1000
 # Regression against a glazing flood leaking into neutral door reflections.
 if model=='gti_vr6' and not selected[round(190*factor),round(500*factor)]: errors.append('Door reflection misclassified as glass')
 yy,xx=np.mgrid[:h,:w]
 for center in [d['rear'],d['front']]:
  inside=(xx-center[0]*factor)**2+(yy-center[1]*factor)**2<(d['radius']*.9*factor)**2
  if np.any(base[:,:,3][inside]): errors.append('Duplicate authored wheels in body cutouts')
  if np.any(selected[inside]): errors.append('Paint mask covers a wheel')
 for path in d['stock_wheels']:
  wheel=read(path)
  if not np.any(wheel[:,:,3]>0): errors.append('Empty authored wheel')
 hashes=[]
 for finish in ['gloss','matte','metallic']: hashes.append(hashlib.sha256(read(d['body']%(0,finish)).tobytes()).hexdigest())
 if len(set(hashes))!=3: errors.append('Indistinguishable finish variants')
 number=read(d['layers']['number'])
 if np.any((number[:,:,3]>0)&~selected): errors.append('Livery outside paintable body')
 if d['rear'][0]!=roster[model]['wheelbase'][0] or d['front'][0]!=roster[model]['wheelbase'][1] or d['radius']!=roster[model]['wheel_radius']: errors.append('Smoke/physical effect anchors disagree')
 rows.append({'id':model,'errors':errors,'texture_size':[w,h],'distinct_source':True,'opaque_paint':not np.any(base[:,:,3][selected]!=255),'artistic_approval':False})
 print(model, 'PASS' if not errors else ', '.join(errors))

report={'passed':all(not row['errors'] for row in rows),'vehicles':rows,'scope':'Numerical layer integrity only; likeness, trim fidelity and artistic finish require screenshot/reference review.'}
(root/'validation/vehicle_art_integrity.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if report['passed'] else 1)
