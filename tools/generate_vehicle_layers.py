"""Split original SVG artwork into reusable presentation layers. No third-party assets."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'vehicles'
OUT.mkdir(exist_ok=True)
# Authored positions in the existing 1000 x 360 artwork coordinate system.
REAR = dict(kaze=(215,73,158), nori=(208,70,139), aster=(212,76,157),
            vanta=(209,78,174), mika=(215,73,130), brindle=(215,73,170),
            comet=(215,73,172), rikka=(215,73,164), velora=(215,73,171),
            solenne=(215,73,194), aurora=(215,73,201), hammer=(215,73,170))
ROOF_WINGS = {'nori': [148,30], 'mika': [148,47]}
manifest = {}
for model, (rear, radius, deck) in REAR.items():
    folder = OUT / model
    folder.mkdir(exist_ok=True)
    source = (ROOT / 'assets' / f'{model}_0.svg').read_text(encoding='utf-8')
    defs = re.search(r'<defs>.*?</defs>', source, re.S).group()
    glass = re.search(r'<path d="[^"]+" fill="url\(#glass\)".*?</g>', source, re.S).group()
    lamps = re.search(r'<path d="M42 210.*?<path d="M902 191[^>]+/>', source, re.S).group()
    spoiler = re.search(r'<path d="M82 145.*?</svg>', source, re.S).group().replace('</svg>', '')
    def svg(content):
        return '<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="360" viewBox="0 0 1000 360">' + defs + content + '</svg>'
    for name, content in [('glass',glass),('lamps',lamps),('spoiler',spoiler)]:
        (folder / f'{name}.svg').write_text(svg(content), encoding='utf-8')
    # Tint and decals are clipped to authored surfaces rather than rectangular overlays.
    glass_path = re.search(r'<clipPath id="windows">(.*?)</clipPath>', defs, re.S).group(1)
    (folder/'tint.svg').write_text(svg(glass_path.replace('/>', ' fill="#030812"/>')), encoding='utf-8')
    body_d = re.search(r'<clipPath id="body"><path d="([^"]+)"',defs).group(1)
    window_d = re.search(r'd="([^"]+)"',glass_path).group(1)
    (folder/'paint_mask.svg').write_text(svg(f'<path d="{body_d} {window_d}" fill="#fff" fill-rule="evenodd"/>'),encoding='utf-8')
    for name, content in {
        'stripe':'<path d="M305 194 H680 V207 H305 Z M305 214 H650 V218 H305 Z" fill="#edf3ed"/>',
        'number':'<path d="M410 180 H520 V236 H410 Z" fill="#ecede3"/><path d="M435 190 H475 L450 226 M483 190 H496 V226" fill="none" stroke="#192433" stroke-width="7"/>',
    }.items():
        (folder/f'{name}.svg').write_text(svg('<g clip-path="url(#body)">'+content+'</g>'), encoding='utf-8')
    for paint in range(6):
        original = (ROOT/'assets'/f'{model}_{paint}.svg').read_text(encoding='utf-8')
        clean = original.replace(glass,'').replace(lamps,'').replace(spoiler,'')
        # Glass/lamps contain no paint references, so the original match is reusable.
        for finish in ('gloss','matte','metallic'):
            art = clean
            if finish == 'matte':
                gradient = re.search(r'<linearGradient id="paint".*?</linearGradient>', art, re.S).group()
                colors = re.findall(r'(?:stop-color=")(#[a-fA-F0-9]+)', gradient)
                base = colors[1]
                art = art.replace(gradient, '<linearGradient id="paint" x2="0" y2="1"><stop stop-color="'+base+'"/><stop offset="1" stop-color="'+base+'" stop-opacity=".83"/></linearGradient>')
                art = art.replace('opacity=".25"','opacity=".06"').replace('opacity=".26"','opacity=".08"')
            elif finish == 'metallic':
                flecks = ''.join(f'<circle cx="{70+i*37%875}" cy="{165+i*19%100}" r=".9" fill="#fff" opacity=".32"/>' for i in range(110))
                art = art.replace('</svg>','<g clip-path="url(#body)">'+flecks+'</g></svg>')
            (folder/f'body_{paint}_{finish}.svg').write_text(art,encoding='utf-8')
    manifest[model] = dict(size=[1000,360], rear=[rear,274], front=[786 if model=='nori' else 794 if model=='aster' else 799 if model=='vanta' else 790,274],
                           radius=radius, pivot=[500,274], exhaust=[27,259], spoiler=ROOF_WINGS.get(model,[95,deck-10]),
                           headlight=[[902,191],[936,200]], taillight=[[44,213],[73,208]],
                           body=f'res://assets/vehicles/{model}/body_%d_%s.svg',
                           layers={name:f'res://assets/vehicles/{model}/{name}.svg' for name in ['glass','lamps','spoiler','tint','stripe','number','paint_mask']},
                           compatible=['paint','finish','design','rim','sidewall','caliper','tint','stance','spoiler','headlight','taillight','decal'])
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(f'Generated layered artwork for {len(manifest)} vehicles')
