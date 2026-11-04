from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import subprocess
import sys

root=Path(__file__).resolve().parents[1]
out=root/"reference"/"analysis"/"calibration"
out.mkdir(exist_ok=True)
ff=r"C:\Program Files (x86)\MOZA Pit House\bin\ffmpeg.exe"
src=root/"reference"/"LCXM2683.MP4"
def grab(t):
    dst=out/f"lcxm_{t:05.2f}.png"
    subprocess.run([ff,"-hide_banner","-loglevel","error","-y","-ss",str(t),"-i",str(src),"-frames:v","1","-vf","transpose=2,scale=1311:603","-update","1",str(dst)],check=True)
    return t,dst
times=list(range(0,28))
if "--shifts" in sys.argv:
    times=[round(8.2+i*0.1,2) for i in range(10)]+[round(14.1+i*0.1,2) for i in range(10)]
with ThreadPoolExecutor(max_workers=4) as pool: frames=list(pool.map(grab,times))
for batch in range(3):
    selected=frames[batch*10:(batch+1)*10]
    if not selected: continue
    canvas=Image.new("RGB",(1000,((len(selected)+1)//2)*210),(13,18,26))
    d=ImageDraw.Draw(canvas)
    for i,(t,p) in enumerate(selected):
        im=Image.open(p)
        crop=im.crop((490,112,825,256)).resize((469,202))
        x=(i%2)*500;y=(i//2)*210
        canvas.paste(crop,(x,y))
        d.text((x+8,y+8),f"Video {t:.2f}s",fill="white")
        clock=im.crop((1110,0,1280,38)).resize((170,38))
        canvas.paste(clock,(x+320,y+1))
    canvas.save(out/f"{'shifts' if '--shifts' in sys.argv else 'measurements'}_{batch}.png")
print("Extracted precise requested video timestamps, with visible in-game clock.")

