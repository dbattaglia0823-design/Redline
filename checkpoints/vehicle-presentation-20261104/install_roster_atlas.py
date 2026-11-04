"""Install processed original atlases into the existing modular manifest (no image editing)."""
from pathlib import Path
import csv,json
r=Path(__file__).resolve().parents[1]
manifest=json.loads((r/'assets/vehicles/manifest.json').read_text())
rows=json.loads((r/'assets/data/roster.json').read_text())
for item in csv.DictReader((r/'assets/vehicles/atlas_geometry.csv').open()):
 id=item['id']; d=manifest[id]; rear=int(item['rear_x']); front=int(item['front_x']); radius=int(item['radius'])
 d.update(rear=[rear,274],front=[front,274],radius=radius,body=f'res://assets/vehicles/{id}/body_%d_%s.png',art_status='Original generated illustration with processed opaque body, independent runtime wheels, paint and window masks; likeness/edge QA required')
 for key in ['paint_mask','glass','lamps','tint','stripe','spoiler']: d['layers'][key]=f'res://assets/vehicles/{id}/{key}.png'
 d['race_body']=f'res://assets/vehicles/{id}/race_body_%d_%s.png'
 d['rim_radius']=[round(radius*.72,2),round(radius*.72,2)]
 d['stock_wheels']=[f'res://assets/vehicles/{id}/rear_wheel.png',f'res://assets/vehicles/{id}/front_wheel.png']
 # Factory wings are baked into these illustrations; unsupported removal is hidden.
 d['compatible']=[key for key in d['compatible'] if key not in ('spoiler','headlight','taillight')]
 rows[id].update(wheelbase=[rear,front],wheel_radius=radius,wheel_y=274)
(r/'assets/vehicles/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(r/'assets/data/roster.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Installed detailed atlas bodies for 30 vehicles; legacy artwork remains in checkpoint')


