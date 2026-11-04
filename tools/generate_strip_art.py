"""Original small, reusable SVG strip layers; no downloaded/reference artwork."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'assets'/'strip'
root.mkdir(exist_ok=True)
def save(name, width, height, body):
    (root/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">{body}</svg>',encoding='utf-8')
for name,top,bottom in [('day','#4f7897','#e3d7b3'),('night','#0b1429','#495b73')]:
    clouds=''.join(f'<path d="M{x} {y} q40 -20 74 -6 q45 -32 94 -8 q50 -17 81 12 q-128 13 -249 2Z" fill="#e3e7e6" opacity="{.28 if name=="day" else .055}"/>' for x,y in [(20,64),(490,100),(860,41)])
    stars=''.join(f'<circle cx="{(i*131+41)%1200}" cy="{(i*37+17)%160}" r=".8" fill="#c0d2df" opacity=".5"/>' for i in range(40)) if name=='night' else ''
    save('sky_'+name,1200,320,f'<defs><linearGradient id="s" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs><path fill="url(#s)" d="M0 0H1200V320H0Z"/>{clouds}{stars}<circle cx="990" cy="74" r="{16 if name=="night" else 28}" fill="{ "#dfe9e7" if name=="night" else "#f5e8bb"}" opacity=".8"/>')
grain=''.join(f'<path d="M{(i*43)%384} {(i*67)%128}h{2+i%5}" stroke="{ "#788080" if i%3==0 else "#090d11"}" opacity=".12" stroke-width=".8"/>' for i in range(280))
save('asphalt',384,128,'<path fill="#30353b" d="M0 0H384V128H0Z"/>'+grain)
steel=''.join(f'<path d="M0 {24+i*20}H960" stroke="#73808a" stroke-width="3"/><path d="M0 {29+i*20}H960" stroke="#18232e" stroke-width="8"/>' for i in range(6))
fans=''.join(f'<circle cx="{20+i*19}" cy="{20+row*20}" r="2.8" fill="{["#798996","#9c8b79","#536b7a","#aca69b"][i%4]}"/><path d="M{20+i*19} {23+row*20}v6" stroke="#25303c" stroke-width="5"/>' for row in range(5) for i in range(49) if (i+row*7)%4!=0)
supports=''.join(f'<path d="M{x} 140v-123l94 123Z" fill="none" stroke="#273746" stroke-width="5"/>' for x in range(0,960,96))
save('stands',960,160,f'<path d="M0 15H960V142H0Z" fill="#35434f"/>{steel}{fans}{supports}<path d="M0 10H960M0 140H960" stroke="#a4acac" stroke-width="3"/><path d="M0 3H960" stroke="#223443" stroke-width="7"/>')
save('barrier',384,48,'<path fill="#a4aaa9" d="M0 0H384V42H0Z"/><path fill="#c2c7c4" d="M0 0H384V8H0Z"/><path fill="#424e59" d="M0 33H384V48H0Z"/><path d="M96 8v25M288 8v25" stroke="#6c777c"/><path d="M12 14h48M204 14h48" stroke="#303d49" stroke-width="5"/>')
print('Generated five original drag-strip SVG layers')
