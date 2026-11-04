"""Build original, resolution-independent vehicle and environment artwork."""
from pathlib import Path
from math import cos, sin, pi

ROOT = Path(__file__).resolve().parents[1] / "assets"
ROOT.mkdir(exist_ok=True)
PAINTS = ["eb704e","b8d6cb","e8dfc6","7b93cf","e7b44d","c68aad"]

def shade(value, factor):
    c = [int(value[i:i+2],16) for i in (0,2,4)]
    return "#" + "".join(f"{min(255,int(v*factor)):02x}" for v in c)

SHAPES = {
"kaze": (
"M35 215 L48 177 Q55 163 84 158 L230 144 L342 69 Q362 57 391 57 L565 57 Q590 58 615 79 L719 147 L893 164 Q938 171 956 202 L968 245 L947 280 L47 280 L27 254 Z",
"M267 146 L355 78 L453 78 L453 146 Z M467 78 L562 78 Q581 79 601 95 L673 146 L467 146 Z",
"M460 153 L460 260 M700 161 L688 259", 215,790,73),
"nori": (
"M52 259 L51 139 L108 53 Q117 38 143 38 L548 38 Q578 39 598 66 L681 142 L859 157 Q922 163 948 195 L958 247 L938 280 L61 280 Z",
"M87 135 L132 56 L418 56 L418 134 Z M436 56 L539 56 Q561 59 577 80 L630 137 L436 137 Z",
"M429 142 L430 264 M662 151 L654 263",208,786,70),
"aster": (
"M30 211 L60 170 Q73 158 105 157 L251 139 L359 70 Q386 54 417 55 L600 57 Q627 59 649 81 L732 148 L886 160 Q939 167 964 209 L966 251 L946 282 L43 282 L23 254 Z",
"M285 142 L371 82 Q391 72 417 74 L478 74 L478 144 Z M492 74 L590 76 Q611 78 628 95 L683 145 L492 145 Z",
"M485 153 L486 264 M713 159 L701 264",212,794,76),
"vanta": (
"M27 225 L43 174 L177 166 L290 147 L392 102 Q414 94 446 94 L568 94 Q595 95 626 116 L694 157 L867 174 L945 193 L977 228 L967 269 L910 282 L45 282 L20 256 Z",
"M328 150 L404 110 L465 110 L465 154 Z M480 110 L562 110 Q586 112 604 126 L646 157 L480 154 Z",
"M474 163 L471 263 M685 167 L664 264",209,799,78),
}
import json
SHAPES.update(json.loads((Path(__file__).parent / "vehicle_shapes.json").read_text()))
for model,(body,glass,seams,back,front,radius) in SHAPES.items():
    for index,paint in enumerate(PAINTS):
        tinyvents = "".join(f'<path d="M{722+i*9} 212 l-5 17" stroke="#101923" stroke-width="4"/>' for i in range(7))
        mesh = "".join(f'<path d="M{875+i*7} 238 l12 12" stroke="#52626c" stroke-width="1"/>' for i in range(11))
        art = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="360" viewBox="0 0 1000 360">
<defs>
 <linearGradient id="paint" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{shade(paint,1.25)}"/><stop offset=".30" stop-color="#{paint}"/><stop offset=".52" stop-color="{shade(paint,.86)}"/><stop offset=".65" stop-color="{shade(paint,1.1)}"/><stop offset="1" stop-color="{shade(paint,.44)}"/></linearGradient>
 <linearGradient id="glass" x1="0" y1="0" x2=".7" y2="1"><stop stop-color="#617e91"/><stop offset=".22" stop-color="#304a59"/><stop offset=".65" stop-color="#162a36"/><stop offset="1" stop-color="#0b1721"/></linearGradient>
 <linearGradient id="chrome" x2="0" y2="1"><stop stop-color="#bac5c9"/><stop offset=".4" stop-color="#23333e"/><stop offset=".7" stop-color="#9aaab5"/><stop offset="1" stop-color="#192630"/></linearGradient>
 <clipPath id="body"><path d="{body}"/></clipPath>
 <clipPath id="windows"><path d="{glass}"/></clipPath>
</defs>
<ellipse cx="500" cy="342" rx="460" ry="14" fill="#000" opacity=".16"/>
<ellipse cx="500" cy="338" rx="435" ry="7" fill="#000" opacity=".24"/>
<path d="{body}" fill="url(#paint)" stroke="#0b1219" stroke-width="5" stroke-linejoin="round"/>
<g clip-path="url(#body)">
 <path d="M0 168 Q320 136 1000 191 L1000 196 Q350 149 0 181 Z" fill="#fff" opacity=".25"/>
 <path d="M45 197 Q397 184 940 210" fill="none" stroke="{shade(paint,.56)}" stroke-width="3"/>
 <path d="M35 203 Q390 192 944 215" fill="none" stroke="#fff" stroke-width="2" opacity=".13"/>
 <path d="M100 247 L897 247 L919 266 L84 266 Z" fill="{shade(paint,.65)}"/>
 <path d="M105 248 L889 248" stroke="#fff" opacity=".26" stroke-width="3"/>
 <path d="M{back-radius-6} 275 A{radius+6} {radius+6} 0 0 1 {back+radius+6} 275" fill="#09121a" stroke="{shade(paint,.38)}" stroke-width="10"/>
 <path d="M{front-radius-6} 275 A{radius+6} {radius+6} 0 0 1 {front+radius+6} 275" fill="#09121a" stroke="{shade(paint,.38)}" stroke-width="10"/>
</g>
<path d="{glass}" fill="url(#glass)" stroke="#101d27" stroke-width="7" stroke-linejoin="round"/>
<g clip-path="url(#windows)"><path d="M300 45 L405 45 L245 180 L140 180 Z M520 40 L551 40 L385 180 L355 180 Z" fill="#d9eef2" opacity=".15"/>
<path d="M269 87 Q450 61 675 130" fill="none" stroke="#ecf8ff" stroke-width="5" opacity=".2"/></g>
<path d="{seams}" fill="none" stroke="#111e28" opacity=".65" stroke-width="3"/>
<path d="M480 169 h30 a3 3 0 0 1 0 7 h-30 z" fill="#15222b"/><path d="M483 170 h25" stroke="#dce8ec" opacity=".48" stroke-width="2"/>
<path d="M646 139 q30 -4 38 12 l-5 10 -35 -3 z" fill="url(#paint)" stroke="#14232b" stroke-width="3"/>
<path d="M650 159 l8 9" stroke="#12212a" stroke-width="4"/>
<path d="M42 210 L77 202 L83 224 L40 232 Z" fill="#731d29"/><path d="M43 210 l29 -4 2 7 -30 5 Z" fill="#ff5f4f"/>
<path d="M896 182 L943 196 L951 213 L903 207 Z" fill="#dbeaf4" stroke="#4b626f" stroke-width="3"/>
<path d="M902 191 l34 9" stroke="#fff9d9" stroke-width="6"/>
<path d="M906 221 L961 229 L959 253 L908 251 Z" fill="#09131d"/>{mesh}
<path d="M32 266 L117 269 M302 282 L704 282 M887 276 L953 266" fill="none" stroke="#101b24" stroke-width="10"/>
<path d="M305 276 L702 276" stroke="#b2bdc5" opacity=".42" stroke-width="2"/>
<path d="M44 255 l-17 4" stroke="url(#chrome)" stroke-width="8"/>
{tinyvents if model == "vanta" else ""}
<path d="M82 145 L129 143 L127 151 L79 153 Z" fill="#172630"/>
<path d="M60 139 L185 135 L188 143 L60 148 Z" fill="#22323c" stroke="#10202a" stroke-width="2"/>
<path d="M94 149 v14" stroke="#12212c" stroke-width="5"/>
</svg>'''
        (ROOT / f"{model}_{index}.svg").write_text(art, encoding="utf-8")

shutter = "".join(f'<path d="M90 {120+i*19} h830" stroke="#33404a" stroke-width="3"/><path d="M90 {123+i*19} h830" stroke="#819194" stroke-width="1" opacity=".15"/>' for i in range(17))
floor = "".join(f'<path d="M500 410 L{i*100-300} 600" stroke="#47545b" opacity=".24"/>' for i in range(18))
brick = "".join(f'<path d="M0 {i*28} H1000" stroke="#0b131b" opacity=".25"/>' for i in range(18))
workshop = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="720" viewBox="0 0 1000 600">
<defs><linearGradient id="wall" x2="0" y2="1"><stop stop-color="#121c26"/><stop offset="1" stop-color="#334046"/></linearGradient><radialGradient id="light"><stop stop-color="#ffcf8d" stop-opacity=".22"/><stop offset="1" stop-color="#ffcf8d" stop-opacity="0"/></radialGradient><linearGradient id="floor" x2="0" y2="1"><stop stop-color="#15212a"/><stop offset="1" stop-color="#27333a"/></linearGradient></defs>
<path fill="url(#wall)" d="M0 0H1000V600H0Z"/>{brick}
<rect x="80" y="95" width="850" height="334" rx="5" fill="#0b151e"/><rect x="90" y="105" width="830" height="315" fill="#24313b"/>{shutter}
<path d="M0 420 H1000V600H0Z" fill="url(#floor)"/>{floor}
<path d="M0 495H1000M0 565H1000" stroke="#5e6a70" opacity=".2"/>
<ellipse cx="500" cy="190" rx="490" ry="330" fill="url(#light)"/>
<path d="M180 22 H820" stroke="#060e17" stroke-width="20"/><path d="M190 30H810" stroke="#fbe6bd" stroke-width="5"/><path d="M190 33H810" stroke="#de9559" stroke-width="3" opacity=".7"/>
<path d="M503 0V29" stroke="#51626d" stroke-width="3"/>
<rect x="21" y="340" width="69" height="96" rx="4" fill="#8a4d38"/><path d="M24 356H87M24 375H87M24 394H87M24 413H87" stroke="#3d2925" stroke-width="3"/>
<path d="M46 348h22M46 368h22M46 388h22M46 408h22" stroke="#acb3ac" stroke-width="3"/>
<rect x="933" y="231" width="48" height="199" fill="#101e29"/><path d="M938 259H976M938 311H976M938 363H976" stroke="#56646b" stroke-width="4"/>
<circle cx="955" cy="395" r="21" fill="#081019"/><circle cx="955" cy="395" r="13" fill="#34434f"/>
<rect x="15" y="198" width="56" height="107" fill="#182832" stroke="#425460"/><path d="M27 217v66M43 214v42M57 222v57" stroke="#9aafb6" stroke-width="4"/>
<path d="M320 441 Q500 466 740 442 L820 544 Q477 579 199 538Z" fill="#9bb3b9" opacity=".035"/>
</svg>'''
(ROOT / "workshop.svg").write_text(workshop, encoding="utf-8")

clouds = "".join(f'<path d="M{x} {y} q50 -24 93 -5 q60 -40 124 -8 q43 -21 98 8 l57 14 q-122 20 -372 3Z" fill="{color}" opacity="{opacity}"/>' for x,y,color,opacity in [(-50,70,"#946d80",.7),(400,120,"#bc8083",.5),(150,185,"#ebaa88",.35),(690,56,"#6b6481",.8),(800,208,"#e5b293",.36)])
sky = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="600" viewBox="0 0 1200 450"><defs><linearGradient id="sky" x2="0" y2="1"><stop stop-color="#202f4c"/><stop offset=".38" stop-color="#625474"/><stop offset=".73" stop-color="#c18b84"/><stop offset="1" stop-color="#eeb288"/></linearGradient><radialGradient id="sun"><stop stop-color="#fff3c7" stop-opacity=".7"/><stop offset="1" stop-color="#ffd39e" stop-opacity="0"/></radialGradient></defs><path d="M0 0H1200V450H0Z" fill="url(#sky)"/><ellipse cx="980" cy="308" rx="260" ry="180" fill="url(#sun)"/><circle cx="980" cy="308" r="48" fill="#ffe5b2" opacity=".8"/>{clouds}<path d="M0 371Q150 321 300 360T600 357T900 367T1200 344V450H0Z" fill="#263140"/></svg>'''
(ROOT / "sky.svg").write_text(sky, encoding="utf-8")
print(f"Generated {len(SHAPES)*len(PAINTS)} vehicle paint textures and two environment textures.")

