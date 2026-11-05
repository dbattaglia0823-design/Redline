"""Build runtime layers from original artwork, not from game screenshots.

Logical coordinates remain 1000x360; texture resolution is independent. Explicit
source crops/axles are reviewed art data. Existing save appearance IDs stay fixed.
Run --audit first, then --install [model ...]. Every installation is backed up.
"""
from pathlib import Path
import argparse, hashlib, json, zipfile
from collections import deque
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT/'assets/vehicles'
PALETTE = [(243,105,64),(159,189,179),(222,214,186),(104,126,175),(208,168,59),(172,115,158)]
FINISHES = ['gloss','matte','metallic']
LAMP_REGIONS = json.loads((ART/'lamp_regions.json').read_text())

def image_path(path): return ROOT/path.removeprefix('res://')
def save(a,path): Image.fromarray(np.asarray(a,dtype=np.uint8),'RGBA').save(path)
def polygon_mask(size,polygons):
    mask=Image.new('L',size); draw=ImageDraw.Draw(mask)
    for polygon in polygons: draw.polygon([tuple(p) for p in polygon],fill=255)
    return np.asarray(mask)>127

def connected_glass(seed,allowed):
    """Extend existing glazing through contiguous dark glass, never a rectangle."""
    result=seed.copy(); h,w=seed.shape
    queue=deque(zip(*np.where(seed)))
    while queue:
        y,x=queue.popleft()
        for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:
            ny,nx=y+dy,x+dx
            if 0<=ny<h and 0<=nx<w and allowed[ny,nx] and not result[ny,nx]:
                result[ny,nx]=True; queue.append((ny,nx))
    return result

def normalized_source(model,definition,config):
    """Return a source at native resolution plus normalized simulation/effect anchors."""
    if model not in config:
        source=Image.open(ART/model/'source.png').convert('RGBA')
        return source,dict(rear=definition['rear'],front=definition['front'],radius=definition['radius']),None
    entry=config[model]
    original=Image.open(ROOT/entry['source']).convert('RGBA')
    if entry.get('crop'): original=original.crop(tuple(entry['crop']))
    pixels=np.asarray(original); yy,xx=np.where(pixels[:,:,3]>220)
    if not len(xx): raise ValueError(model+': empty source')
    left,right,top,bottom=int(xx.min()),int(xx.max()),int(yy.min()),int(yy.max())
    rear,front=entry['rear'],entry['front']
    if rear[0]>=front[0] or entry['radius']<=0: raise ValueError(model+': invalid axle order or radius')
    if not all(0<=p[0]<original.width and 0<=p[1]<original.height for p in [rear,front]): raise ValueError(model+': wheel outside source crop')
    scale=min(920/(right-left+1),304/(bottom-top+1))
    per_axle=entry.get('wheel_radii')
    ox=40-left*scale; oy=274-(rear[1] if per_axle else (rear[1]+front[1])*.5)*scale
    resolution=entry.get('resolution',2)
    if resolution not in (1,2): raise ValueError(model+': runtime resolution must be 1x or 2x; retain higher resolution originals offline')
    output=original.transform((1000*resolution,360*resolution),Image.Transform.AFFINE,
        (1/(scale*resolution),0,-ox/scale,0,1/(scale*resolution),-oy/scale),Image.Resampling.BICUBIC)
    anchors=dict(rear=[round(ox+rear[0]*scale),274],front=[round(ox+front[0]*scale),274],radius=round(entry['radius']*scale))
    if per_axle:
        anchors['front'][1]=round(oy+front[1]*scale)
        anchors['wheel_radii']=[round(radius*scale) for radius in per_axle]
    # Explicit source-space glass contours; constrain to dark glass pixels, so
    # pale roof reflections and the opaque metal frame are never tinted black.
    polygons=[[[int((ox+x*scale)*resolution),int((oy+y*scale)*resolution)] for x,y in polygon] for polygon in entry.get('glass',[])]
    return output,anchors,polygon_mask(output.size,polygons) if polygons else None

def prepare(model,definition,config):
    master,anchors,glass_shape=normalized_source(model,definition,config)
    original=np.asarray(master).copy(); h,w=original.shape[:2]; factor=w/1000
    a=original[:,:,3].astype(np.float32)
    # Preserve antialias coverage, but interiors must be fully opaque. Earlier
    # importer discarded every pixel below alpha240, giving hard jagged edges.
    a=np.where(a>=220,255,np.where(a<12,0,a))
    original[:,:,3]=a.astype(np.uint8)
    yy,xx=np.mgrid[:h,:w]; wheel=np.zeros((h,w),bool)
    radii=anchors.get('wheel_radii',[anchors['radius']]*2)
    for center,radius in zip([anchors['rear'],anchors['front']],radii):
        wheel|=(xx-center[0]*factor)**2+(yy-center[1]*factor)**2<((radius+1)*factor)**2
    rgb=original[:,:,:3].astype(np.float32); maximum=rgb.max(2); minimum=rgb.min(2)
    if glass_shape is None:
        # Rebuild from the immutable silver master, never a previously generated
        # mask. Limit growth above the beltline: dark door reflections are paint.
        glass_shape=(xx>220*factor)&(xx<730*factor)&(yy>35*factor)&(yy<160*factor)&(maximum<105)&(a>=220)&~wheel
        allowed=(xx>100*factor)&(xx<850*factor)&(yy>20*factor)&(yy<160*factor)&(maximum<145)&(a>=220)&~wheel
        glass_shape=connected_glass(glass_shape,allowed)
    else: glass_shape &= maximum<config.get(model,{}).get('glass_luminance_max',155)
    glass_shape &= (a>=220)&~wheel
    if config.get(model,{}).get('source','').endswith('_studio.png'):
        # Magenta can show through generated cabin glazing as a dark purple
        # reflection. Neutralize it inside the glazing, leaving colored lamps.
        reflection=glass_shape&(rgb[:,:,0]>rgb[:,:,1]+9)&(rgb[:,:,2]>rgb[:,:,1]+9)
        original[:,:,:3][reflection]=np.stack([rgb[:,:,1]*.92,rgb[:,:,1],rgb[:,:,1]*1.12],axis=2)[reflection].astype(np.uint8)
    # Colored lamp lenses, amber markers and dark trim keep their authored
    # color. A paint mask is never inferred merely from a rectangular HUD zone.
    regions=config.get(model,{}).get('lamps',LAMP_REGIONS.get(model,[]))
    lamp_shape=polygon_mask((w,h),[[[x*factor,y*factor] for x,y in p] for p in regions])
    lamps=((maximum-minimum>42)|lamp_shape)&(a>=220)&~wheel
    paint=(maximum>25)&(maximum-minimum<42)&(a>=220)&~wheel&~glass_shape&~lamps
    black_trim=polygon_mask((w,h),[[[x*factor,y*factor] for x,y in p] for p in config.get(model,{}).get('trim',[])])
    paint &= ~black_trim
    body=original.copy(); body[wheel]=0
    mask=np.zeros_like(original); mask[paint]=[255,255,255,255]
    glass=np.zeros_like(original); glass[glass_shape]=original[glass_shape]
    lamp_layer=np.zeros_like(original); lamp_layer[lamps]=original[lamps]
    tint=np.zeros_like(original); tint[glass_shape]=[7,12,18,255]
    stripe=np.zeros_like(original); stripe[paint&(yy>224*factor)&(yy<236*factor)]=[225,233,235,255]
    return original,body,mask,glass,lamp_layer,tint,stripe,anchors

def backup(ids):
    target=ROOT/'checkpoints/vehicle-presentation-20261104/installed_art.zip'
    if target.exists(): return
    with zipfile.ZipFile(target,'w',compression=zipfile.ZIP_STORED) as archive:
        for model in ids:
            for p in (ART/model).glob('*.png'): archive.write(p,p.relative_to(ROOT))
        for p in [ART/'manifest.json',ROOT/'assets/data/roster.json']: archive.write(p,p.relative_to(ROOT))

def install(model,d,config):
    original,body,mask,glass,lamps,tint,stripe,anchors=prepare(model,d,config)
    folder=ART/model; folder.mkdir(exist_ok=True)
    factor=body.shape[1]/1000; radius=anchors['radius']
    save(original,folder/'master.png')
    for name,array in [('paint_mask',mask),('glass',glass),('lamps',lamps),('tint',tint),('stripe',stripe),('spoiler',np.zeros_like(body))]: save(array,folder/(name+'.png'))
    number=Image.new('RGBA',(body.shape[1],body.shape[0]))
    draw=ImageDraw.Draw(number)
    font=ImageFont.truetype('C:/Windows/Fonts/bahnschrift.ttf',round(46*factor))
    center=(anchors['rear'][0]+anchors['front'][0])*.5
    draw.text((round((center-27)*factor),round(204*factor)),'71',font=font,fill=(232,235,232,255),stroke_width=max(1,round(2*factor)),stroke_fill=(18,27,34,255))
    digits=np.asarray(number).copy(); digits[:,:,3]=np.minimum(digits[:,:,3],mask[:,:,3]); save(digits,folder/'number.png')
    radii=anchors.get('wheel_radii',[radius]*2)
    for name,center,wheel_radius in zip(['rear','front'],[anchors['rear'],anchors['front']],radii):
        extent=(wheel_radius+2)*factor
        crop=Image.fromarray(original).crop((round(center[0]*factor-extent),round(center[1]*factor-extent),round(center[0]*factor+extent),round(center[1]*factor+extent)))
        pixels=np.asarray(crop).copy(); yy,xx=np.mgrid[:pixels.shape[0],:pixels.shape[1]]
        distance=np.sqrt((xx-(pixels.shape[1]-1)/2)**2+(yy-(pixels.shape[0]-1)/2)**2)
        coverage=np.clip((wheel_radius+.65)*factor-distance,0,1)
        pixels[:,:,3]=(pixels[:,:,3]*coverage).astype(np.uint8)
        save(pixels,folder/(name+'_wheel.png'))
    rgb=body[:,:,:3].astype(np.float32)/255
    luma=(rgb*np.array([.2126,.7152,.0722])).sum(2)
    selected=mask[:,:,3]>0
    yy,xx=np.mgrid[:body.shape[0],:body.shape[1]]
    # Deterministic baked microtexture, no runtime noise shader or new timers.
    fleck=np.sin(xx*2.399+yy*1.653)*np.sin(xx*.723-yy*2.131)
    for paint,color in enumerate(PALETTE):
        target=np.array(color)/255
        for finish in FINISHES:
            if finish=='matte':
                luminance=.09+np.power(luma,.95)*.76; specular=np.maximum(luma-.88,0)*.65
            elif finish=='metallic':
                luminance=luma*(.985+fleck*.026); specular=np.maximum(luma-.68,0)*1.18
            else:
                luminance=luma; specular=np.maximum(luma-.74,0)*1.65
            colored=np.clip(luminance[:,:,None]*target/.72+specular[:,:,None]*(1-target),0,1)*255
            variant=body.copy(); variant[:,:,:3][selected]=colored[selected].astype(np.uint8)
            save(variant,folder/f'body_{paint}_{finish}.png')
            # Integrated artwork remains available for import QA/future skins.
            integrated=variant.copy(); wheels=original[:,:,3]>0
            wheels &= body[:,:,3]==0
            integrated[wheels]=original[wheels]
            save(integrated,folder/f'race_body_{paint}_{finish}.png')
    d.pop('wheel_radii',None)
    d.update(anchors)
    d['rim_radius']=[round(wheel_radius*.69,2) for wheel_radius in radii]
    d['art_pipeline_version']=2
    d['texture_size']=[body.shape[1],body.shape[0]]
    d['master']=f'res://assets/vehicles/{model}/master.png'
    d['layers']['number']=f'res://assets/vehicles/{model}/number.png'
    d['art_status']='New original reference illustration; model/trim artistic review required' if model in config else 'Retained distinct illustration; rebuilt paint, finish, alpha and wheel layers; model accuracy review required'
    # New source positioning must also move exhaust/smoke/body anchors together.
    opaque=np.argwhere(original[:,:,3]>220); lower=opaque[(opaque[:,0]>250*factor)&(opaque[:,1]<anchors['rear'][0]*factor)]
    if len(lower): d['exhaust']=[int(np.percentile(lower[:,1],8)/factor),int(np.percentile(lower[:,0],60)/factor)]
    return {'id':model,'resolution':d['texture_size'],'new_source':model in config,'paint_pixels':int(selected.sum()),'source_sha256':hashlib.sha256(original.tobytes()).hexdigest(),'visual_approval':'REVIEW REQUIRED'}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--audit',action='store_true',help='Validate proposed inputs without installing (also the default)')
    parser.add_argument('--install',nargs='*',help='No model arguments means all 30; default is audit only')
    args=parser.parse_args()
    if args.audit and args.install is not None: parser.error('--audit and --install are mutually exclusive')
    manifest=json.loads((ART/'manifest.json').read_text())
    roster=json.loads((ROOT/'assets/data/roster.json').read_text())
    config=json.loads((ART/'source_premium/authoring.json').read_text())
    ids=list(roster) if args.install is None or not args.install else args.install
    if args.install is not None: backup(list(roster))
    report=[]
    for model in ids:
        if model not in roster: raise ValueError('Unknown model '+model)
        if args.install is None:
            arrays=prepare(model,manifest[model],config)
            report.append({'id':model,'size':list(arrays[0].shape[:2]),'anchors':arrays[-1],'mode':'dry run'})
        else:
            row=install(model,manifest[model],config); report.append(row)
            d=manifest[model]; roster[model].update(wheelbase=[d['rear'][0],d['front'][0]],wheel_y=274,wheel_radius=d['radius'])
        print(model,'audited' if args.install is None else 'installed')
    if args.install is not None:
        (ART/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (ROOT/'assets/data/roster.json').write_text(json.dumps(roster,indent=2)+'\n')
    target=ROOT/'validation'/('vehicle_art_import.json' if args.install is not None else 'vehicle_art_dryrun.json'); target.write_text(json.dumps(report,indent=2)+'\n')
    print('Visual approval requires native screenshots; numerical validation does not certify likeness.')

if __name__=='__main__': main()
