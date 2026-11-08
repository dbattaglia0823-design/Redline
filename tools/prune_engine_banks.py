"""Retire unused engine renders into an untracked local backup before removing them."""
from pathlib import Path
import argparse,json,shutil
root=Path(__file__).resolve().parents[1];folder=(root/'assets/audio/engines').resolve()
bank=json.loads((folder/'bank.json').read_text())
collections=list(bank['families'].values())+[v['rows'] for v in bank.get('vehicles',{}).values()]
active={(root/p.removeprefix('res://')).resolve() for rows in collections for row in rows for p in row['files'].values()}
unused=[p for p in folder.glob('*/*.wav') if p.resolve() not in active]
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--apply',action='store_true');args=parser.parse_args()
archive=(root/'.qa/retired_engine_banks').resolve()
size=sum(p.stat().st_size for p in unused)
if args.apply:
 for source in unused:
  for p in [source,Path(str(source)+'.import')]:
   if not p.exists(): continue
   resolved=p.resolve();resolved.relative_to(folder)
   destination=(archive/resolved.relative_to(folder)).resolve();destination.relative_to(archive)
   if destination.exists(): raise RuntimeError('Refusing to overwrite backup '+str(destination))
   destination.parent.mkdir(parents=True,exist_ok=True);shutil.move(str(resolved),str(destination))
 manifest_path=root/'assets/audio/asset_manifest.json';manifest=json.loads(manifest_path.read_text())
 manifest['assets']=[x for x in manifest['assets'] if (root/x['path']).resolve() in active]
 manifest['note']='Original generated audio only. Retired outputs archived locally in .qa/retired_engine_banks (gitignored). No authentic recordings or engine-sim output claimed.'
 manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')
 # Non-synthesis design annotations must stay consistent with the active config.
 designs=json.loads((root/'assets/audio/engine_designs.json').read_text())['vehicles']
 for identity,value in bank.get('vehicles',{}).items(): value['design']=designs[identity]
 (folder/'bank.json').write_text(json.dumps(bank,indent=2)+'\n')
print(json.dumps({'applied':args.apply,'retired_wav_files':len(unused),'retired_bytes':size,'active_wav_files':len(active),'originals_preserved':True}))
