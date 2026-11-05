"""Contact sheets of native game captures for visual review, not replacement art."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
import sys
root=Path(__file__).resolve().parents[1]
roster=json.loads((root/'assets/data/roster.json').read_text())
regions={'garage':(170,225,1005,542),'dealer':(80,275,690,512),'collection':(605,235,1145,460),'customize':(250,185,940,425),'appearance_preview':(250,185,940,425),'upgrades':(90,246,700,416),'race':(180,390,610,555)}
out=root/'validation/vehicle_art'
if '--roster-review' in sys.argv:
 out=root/'validation/studio_roster'
 regions={'garage':(170,179,1030,470),'race':regions['race']}
authoring=json.loads((root/'assets/vehicles/source_premium/authoring.json').read_text())
for view,region in regions.items():
 canvas=Image.new('RGB',(1600,960),'#070e16'); draw=ImageDraw.Draw(canvas)
 for i,(model,spec) in enumerate(roster.items()):
  path=out/model/(view+'.png')
  if not path.exists(): continue
  image=Image.open(path).convert('RGB').crop(region)
  image.thumbnail((312,125),Image.Resampling.LANCZOS)
  x=i%5*320; y=i//5*160
  canvas.paste(image,(x+(320-image.width)//2,y+(126-image.height)//2))
  draw.text((x+7,y+128),f"{spec['year']} {spec['name']}",fill='#d7e5ed')
  draw.text((x+7,y+143),'Studio side profile' if authoring.get(model,{}).get('source','').endswith('_studio.png') else 'Earlier source',fill='#8aa5b8')
 canvas.save(out/('sheet_'+view+'.jpg'),quality=94)
print(f'Saved {len(regions)} contact sheets from actual rendered game views.')
