"""Deterministic original surface illustrations, rasterized by Godot at import.
The location panoramas are original generated artwork, not stock photography.
No filters, runtime noise, or per-frame geometry is needed for surface detail.
"""
from pathlib import Path
import random
ROOT = Path(__file__).resolve().parents[1] / 'assets/strip'

def save(name, w, h, body):
    (ROOT / (name + '.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n')

rng = random.Random(27182)
body = ['<defs><linearGradient id="road" x2="0" y2="1"><stop stop-color="#23282e"/><stop offset=".45" stop-color="#45474a"/><stop offset="1" stop-color="#292d32"/></linearGradient></defs>', '<path d="M0 0H1024V256H0Z" fill="url(#road)"/>']
for i in range(4300):
    x, y = rng.randrange(1024), rng.randrange(256)
    c = rng.choice(['#99928a', '#070b12', '#616467', '#bec0bc'])
    body.append(f'<path d="M{x} {y}h{rng.choice([.6,1,1.5,2.4])}" stroke="{c}" stroke-width="{rng.choice([.5,.8,1.1])}" opacity="{rng.uniform(.08,.24):.2f}"/>')
# Longitudinal laid-rubber grooves in both lanes; aligned with tire contact patches.
for lane in [0, 128]:
    for center in [48, 83]:
        for i in range(24):
            y = lane + center + rng.uniform(-8,8)
            x = rng.uniform(-100,850)
            body.append(f'<path d="M{x:.1f} {y:.1f}h{rng.uniform(120,420):.1f}" stroke="#080b0f" stroke-width="{rng.uniform(.4,2):.1f}" opacity="{rng.uniform(.1,.3):.2f}"/>')
for x in [119,618]:
    body.append(f'<path d="M{x} 0l3 24 -5 13 4 30 -2 38 4 32 -4 45 2 74" fill="none" stroke="#171c20" stroke-width="1.2"/>')
body.append('<path d="M0 3H1024M0 253H1024" stroke="#d6d2bc" stroke-width="2" opacity=".8"/><path d="M0 128H1024" stroke="#0c1016" stroke-width="4"/><path d="M0 126H1024" stroke="#c0bfae" stroke-width="2" opacity=".6"/>')
save('race_surface',1024,256,''.join(body))
for key, base, top, accent in [('dockside','#898e8c','#d5d1c4','#bf7840'),('midnight','#465764','#8eabb6','#58b9cd'),('redline','#a8acac','#f1efdf','#bf3b34')]:
    parts=[f'<path d="M0 0H768V10H0Z" fill="{top}"/><path d="M0 10H768V43H0Z" fill="{base}"/><path d="M0 43H768V52H0Z" fill="#17232b"/><path d="M0 14H768" stroke="{accent}" stroke-width="4"/>']
    for x in range(0,768,96):
        parts.append(f'<path d="M{x} 10v33" stroke="#24333c" opacity=".5"/><path d="M{x+1} 10v33" stroke="#e7e3d6" opacity=".25"/>')
        for y in [22,36]: parts.append(f'<circle cx="{x+7}" cy="{y}" r="1.1" fill="#2d3a40"/>')
    for i in range(150):
        x,y=rng.randrange(768),rng.randrange(18,43)
        parts.append(f'<path d="M{x} {y}h{rng.randrange(1,10)}" stroke="#25323a" opacity=".14"/>')
    parts.append(f'<path d="M36 25h94m290 0h100" stroke="{top}" stroke-width="2" opacity=".5"/>')
    save(key+'_wall',768,52,''.join(parts))
# One reusable soft ellipse for contact lighting, reflections and smoke.
save('soft_glow',128,128,'<defs><radialGradient id="g"><stop stop-color="white" stop-opacity=".75"/><stop offset=".4" stop-color="white" stop-opacity=".3"/><stop offset="1" stop-color="white" stop-opacity="0"/></radialGradient></defs><circle cx="64" cy="64" r="64" fill="url(#g)"/>')
print('Authored asphalt, location barriers and soft particle sprite generated.')
