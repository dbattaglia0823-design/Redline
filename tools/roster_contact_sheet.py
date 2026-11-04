from pathlib import Path
from PIL import Image,ImageDraw
import json
r=Path(__file__).resolve().parents[1]; rows=json.loads((r/'assets/data/roster.json').read_text()); benchmarks=json.loads((r/'assets/data/factory_benchmarks.json').read_text())
sheet=Image.new('RGB',(1500,6*155),'#050d15'); draw=ImageDraw.Draw(sheet)
for i,(id,s) in enumerate(rows.items()):
 image=Image.open(r/'validation/roster_art'/f'{id}.png').convert('RGB')
 crop=image.crop((36,246,762,516)).resize((300,112))
 x=(i%5)*300; y=(i//5)*155; sheet.paste(crop,(x,y))
 draw.text((x+7,y+116),f"{s['year']} {s['name']}",fill='#d5e7ef')
 draw.text((x+7,y+133),benchmarks[id]['class']+' measured / original illustration',fill='#729aae')
sheet.save(r/'validation/roster_contact_sheet.png')

