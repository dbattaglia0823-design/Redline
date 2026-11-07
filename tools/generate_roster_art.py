"""Original side-elevation illustrations, individually authored silhouettes.
No photographs, downloaded sprites or source-game imagery are used.
Coordinate contract: 1000x360; wheels remain independent runtime layers.
"""
from pathlib import Path
import json, hashlib
R=Path(__file__).resolve().parents[1]; data=json.loads((R/'assets/data/roster.json').read_text())
# rear hub, front hub, radius, body upper outline (rear to nose), glazing polygon.
SHAPES={
'miata':(211,785,65,'M38 214 L52 184 L278 178 L363 108 L400 108 L407 177 L706 177 L924 190 L969 221','365,117 391,117 398,176 288,176'),
'civic_si':(202,794,66,'M28 207 L41 169 L247 160 L353 83 L596 81 L731 158 L939 178 L978 218','277,157 365,94 585,93 700,157'),
'gti_vr6':(216,799,69,'M43 208 L54 100 L126 71 L526 71 L667 158 L937 179 L967 218','100,105 138,85 515,85 631,156 96,156'),
'rsx':(210,798,69,'M30 211 L68 159 L228 142 L352 75 L581 73 L741 155 L941 183 L972 221','274,140 360,88 575,87 705,155 280,155'),
'brz':(230,794,70,'M32 217 L78 173 L261 155 L374 87 L556 85 L704 161 L916 184 L970 225','306,155 382,100 552,99 673,161'),
'integra':(208,796,66,'M28 214 L61 168 L262 153 L382 80 L592 82 L737 166 L941 181 L979 214','295,154 391,94 587,95 703,165'),
'gti':(217,796,71,'M43 216 L52 115 L147 67 L538 69 L681 158 L940 180 L970 224','94,122 161,83 530,84 645,156 94,156'),
's2000':(239,785,70,'M34 217 L74 174 L288 169 L398 99 L432 101 L451 171 L714 170 L939 190 L972 220','399,112 421,113 439,170 307,168'),
'gr86':(230,793,71,'M31 220 L76 179 L264 154 L373 83 L559 82 L714 161 L925 187 L973 226','306,154 381,96 553,95 677,160'),
'z350':(238,783,73,'M35 219 L77 166 L266 137 L393 78 L548 82 L703 165 L928 186 L973 225','315,137 400,91 544,96 665,163'),
'supra':(234,798,73,'M26 218 L53 169 L245 156 L367 81 L553 80 L709 161 L926 184 L978 225','291,154 377,96 549,94 668,159'),
'm3':(207,801,72,'M26 210 L47 166 L250 156 L348 78 L578 77 L728 160 L943 179 L976 220','285,154 359,92 572,91 691,157'),
'sti':(201,796,71,'M24 211 L45 170 L199 155 L309 68 L590 66 L727 161 L944 180 L977 223','243,153 321,82 585,80 691,158'),
'evo':(204,799,71,'M22 218 L37 174 L206 154 L304 70 L588 70 L720 156 L938 175 L980 226','245,153 317,83 580,83 682,154'),
'type_r':(221,790,75,'M32 216 L44 160 L230 133 L352 60 L594 64 L754 158 L930 183 L977 230','273,132 364,76 588,80 712,155'),
'mustang':(216,798,75,'M24 215 L46 167 L243 147 L350 83 L554 81 L713 163 L932 178 L978 219','285,145 359,97 548,96 673,160'),
'supra_gr':(229,790,76,'M30 218 L70 171 L258 150 L378 79 L531 74 L704 158 L921 183 L979 229','312,149 386,94 528,91 663,155'),
'camaro':(213,800,76,'M23 216 L42 166 L249 153 L343 86 L565 86 L721 163 L949 178 L978 225','289,152 354,100 560,100 680,160'),
'golf_r':(216,795,73,'M41 218 L53 112 L143 67 L537 68 L683 155 L945 174 L975 222','97,118 158,82 528,83 643,153 96,154'),
'z400':(230,790,73,'M27 219 L63 166 L243 150 L384 81 L549 81 L706 159 L936 184 L975 227','302,147 393,94 543,94 666,157'),
'z06':(246,789,78,'M24 224 L49 176 L240 146 L412 72 L570 69 L709 158 L927 184 L980 235','300,143 418,85 564,83 669,155'),
'gtr':(212,797,77,'M22 216 L45 165 L238 146 L351 71 L570 72 L727 158 L949 180 L978 224','283,144 361,86 563,88 685,155'),
'r8':(238,790,77,'M26 224 L56 170 L254 143 L393 73 L584 75 L730 159 L932 185 L979 233','312,143 404,87 577,89 690,156'),
'gt500':(215,800,77,'M22 220 L44 171 L241 149 L351 82 L553 82 L715 164 L946 182 L979 227','286,148 360,96 548,97 674,161'),
'redeye':(202,798,76,'M20 210 L35 159 L242 150 L353 76 L588 77 L736 159 L953 170 L982 218','282,148 365,90 582,91 696,157'),
'turbo_s':(254,790,77,'M28 225 L67 173 L212 142 L348 74 L522 64 L662 142 L752 172 L936 188 L975 231','260,141 358,87 517,80 625,141'),
'mclaren':(234,790,78,'M24 227 L65 175 L240 151 L400 67 L566 63 L735 160 L927 190 L981 237','302,148 411,81 561,78 694,157'),
'sf90':(232,788,78,'M25 225 L61 178 L244 148 L407 72 L572 69 L726 155 L933 190 L980 235','310,145 417,86 565,84 687,152'),
'demon':(202,798,80,'M20 211 L35 159 L242 151 L355 75 L590 77 L738 159 L955 171 L982 219','284,148 367,89 584,91 698,157'),
'chiron':(235,791,80,'M25 225 L62 173 L244 143 L374 63 L564 59 L735 156 L932 185 L981 232','303,141 385,78 559,75 693,153')}
COLORS=['#f36940','#9fbdb3','#ded6ba','#687eaf','#d0a83b','#ac739e']
manifest=json.loads((R/'assets/vehicles/manifest.json').read_text())
for id,(rear,front,radius,upper,window) in SHAPES.items():
 folder=R/'assets/vehicles'/id; folder.mkdir(parents=True,exist_ok=True)
 # Physically distinct overhangs, rooflines and cabins are explicit authored data.
 body=upper+f' L974 280 L{front+radius+9} 280 A{radius+9} {radius+9} 0 0 0 {front-radius-9} 280 L{rear+radius+9} 280 A{radius+9} {radius+9} 0 0 0 {rear-radius-9} 280 L29 280 Z'
 defs=f'<defs><clipPath id="body"><path d="{body}"/></clipPath><linearGradient id="glass" x2=".3" y2="1"><stop stop-color="#527789"/><stop offset=".55" stop-color="#162b37"/><stop offset="1" stop-color="#07131b"/></linearGradient></defs>'
 def svg(content,extra=''): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="360" viewBox="0 0 1000 360">{defs}{extra}{content}</svg>'
 def write(name,content,extra=''): (folder/name).write_text(svg(content,extra),encoding='utf-8')
 roof=list(map(float,window.split()[1].split(',')))
 glass=f'<polygon points="{window}" fill="url(#glass)" stroke="#070e13" stroke-width="8"/><path d="M{roof[0]+100} {roof[1]} L{roof[0]+104} 165" stroke="#15232d" stroke-width="10"/>'
 glass+=f'<polygon points="{window}" fill="none" stroke="#93b6c2" stroke-width="2"/><g clip-path="url(#body)"><path d="M{roof[0]-70} 150 L{roof[0]+20} 78 H{roof[0]+60} L{roof[0]-30} 150Z" fill="#9cbdca" opacity=".17"/></g>'
 write('glass.svg',glass)
 write('tint.svg',f'<polygon points="{window}" fill="#01070c"/>')
 # Lamp signatures and fascia details are selected by the actual inspiration.
 lamp='M914 190 L959 207 L965 223 L923 215Z'
 if id in ['miata','s2000','z350','supra']: lamp='M908 184 Q941 183 957 204 L936 211 L910 201Z'
 if id in ['gti_vr6','gti','golf_r']: lamp='M911 178 L957 186 L962 209 L910 204Z'
 if id in ['mustang','gt500']: lamp='M916 182 L965 193 L966 210 L918 200Z'
 if id in ['mclaren','sf90','z06']: lamp='M907 188 L970 214 L953 214 L912 200Z'
 write('lamps.svg',f'<path d="{lamp}" fill="#d6eff6" stroke="#3b5967" stroke-width="3"/><path d="M919 195 L955 206" stroke="#fff9d6" stroke-width="4"/><path d="M32 199 L72 192 L78 211 L32 220Z" fill="#9f1722" stroke="#421621" stroke-width="3"/><path d="M36 202 L67 198" stroke="#fa6c66" stroke-width="4"/>')
 wing=id in ['supra','integra','sti','evo','type_r','gtr','mclaren','demon']
 write('spoiler.svg','<path d="M56 158 L61 124 M150 156 L152 123" stroke="#17232a" stroke-width="9"/><path d="M32 118 L189 114 L197 125 L31 130Z" fill="#18262e" stroke="#556a73" stroke-width="2"/>' if wing else '')
 write('paint_mask.svg',f'<path d="{body}" fill="#fff"/>')
 write('stripe.svg','<g clip-path="url(#body)"><path d="M40 236 H969 V246 H40Z" fill="#d7dfdd"/><path d="M40 249 H969 V252 H40Z" fill="#313e46"/></g>')
 write('number.svg','<g clip-path="url(#body)"><rect x="452" y="192" width="65" height="58" rx="6" fill="#dce4df"/><path d="M463 202 H487 L473 240 M497 202 V240" fill="none" stroke="#15222b" stroke-width="7"/></g>')
 details=f'<g clip-path="url(#body)"><path d="M32 223 Q465 203 972 226" fill="none" stroke="#2d1f18" stroke-opacity=".55" stroke-width="3"/><path d="M37 234 Q500 217 963 239" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="3"/><path d="M{rear+125} 163 L{rear+126} 267 M{front-139} 168 L{front-140} 265" stroke="#14212b" stroke-opacity=".65" stroke-width="3"/><path d="M{rear+145} 181 h34" stroke="#19252d" stroke-width="6"/><path d="M920 231 L974 244 L973 267 L921 259Z" fill="#101c24"/><path d="M927 236 L962 247 M925 244 L964 255" stroke="#41545f" stroke-width="2"/><path d="M50 266 H145 M{rear+80} 278 H{front-83}" stroke="#101a22" stroke-width="9"/></g>'
 if id in ['sti','evo','gt500','redeye','demon']:
  details+='<path d="M745 166 L813 148 L856 157 L847 168Z" fill="#17242d" stroke="#57717d" stroke-width="2"/>'
 if id in ['r8','mclaren','sf90','z06','chiron']:
  details+='<path d="M315 180 L389 167 L374 239 L324 253Z" fill="#13212b" stroke="#4d6673" stroke-width="3"/>'
 if id=='chiron': details+='<path d="M392 86 Q228 99 301 248 Q373 275 412 174" fill="none" stroke="#bdcbd1" stroke-width="11"/>'
 if id in ['gti_vr6','gti','golf_r','sti','evo','type_r']:
  details+=f'<path d="M{rear+222} 158 L{rear+221} 266" stroke="#1b2932" stroke-width="3"/>'
 if id=='gtr': details+='<path d="M304 191 L331 188 L325 218 L304 222Z" fill="#1b2931"/>'
 for paint,col in enumerate(COLORS):
  for finish in ['gloss','matte','metallic']:
   high='#a1b6bc' if finish=='metallic' else '#fff0d2'
   stops=f'<stop stop-color="{high}"/><stop offset=".25" stop-color="{col}"/><stop offset=".61" stop-color="{col}"/><stop offset="1" stop-color="#352e2a"/>' if finish!='matte' else f'<stop stop-color="{col}"/><stop offset="1" stop-color="{col}"/>'
   grad=f'<defs><linearGradient id="paint" x1="0" y1="0" x2="0" y2="1">{stops}</linearGradient></defs>'
   write(f'body_{paint}_{finish}.svg',f'<path d="{body}" fill="url(#paint)" stroke="#070e14" stroke-width="6"/>'+details,grad)
 manifest[id]=dict(size=[1000,360],rear=[rear,274],front=[front,274],radius=radius,pivot=[500,274],exhaust=[32,269],spoiler=[100,150],headlight=[[916,195],[959,208]],taillight=[[35,204],[70,198]],body=f'res://assets/vehicles/{id}/body_%d_%s.svg',layers={n:f'res://assets/vehicles/{id}/{n}.svg' for n in ['glass','lamps','spoiler','tint','stripe','number','paint_mask']},compatible=['paint','finish','design','rim','caliper','tint','stance','spoiler','headlight','taillight'],art_status='Original individually authored vector elevation; human likeness/detail review required')
 data[id].update(wheelbase=[rear,front],wheel_radius=radius,wheel_y=274)
(R/'assets/vehicles/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(R/'assets/data/roster.json').write_text(json.dumps(data,indent=2)+'\n')
assert len(set(hashlib.sha256(s[3].encode()).hexdigest() for s in SHAPES.values()))==30
print('30 unique authored silhouettes; modular layers, six paints and three opaque finishes generated')
