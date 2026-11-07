class_name RimArt
extends RefCounted

const COLORS := [Color("c5cdd2"),Color("b8a077"),Color("6d7b88"),Color("dbe3e8"),Color("252b30"),Color("161d24"),Color("85888a"),Color("c5af83"),Color("e3e1d8")]
const COUNTS := [5,6,12,10,5,16,7,10,6,5,5,8]
# Rim faces contain real openings. Rotor and caliper layers sit underneath.
const SPOKES := [
	"M-8-40 L-17-131 L-58-202 L-37-211 L-2-155 L3-41 Z M8-40 L17-131 L58-202 L37-211 L2-155 L-3-41 Z",
	"M-17-39 C-23-102-13-158-31-211 L31-211 C13-158 23-102 17-39 Z",
	"M-6-40 L-64-207 L-52-211 L7-40 Z M6-40 L64-207 L52-211 L-7-40 Z",
	"M-10-42 L-17-153 L-12-211 L12-211 L17-153 L10-42 Z",
	"M-20-40 C-25-90-52-149-57-193 L-20-207 C-17-136 9-86 20-40 Z",
	"M-5-41 C-5-110-52-175-61-202 L-35-211 C-22-162 18-106 9-41 Z",
	"M-15-40 L-12-130 L-35-205 L-2-214 L17-136 L15-40 Z",
	"M-7-40 L-68-204 L-51-211 L8-40 Z M7-40 L68-204 L51-211 L-8-40 Z",
	"M-22-39 L-27-208 L27-208 L22-39 Z M-10-50 L-12-196 L-5-196 L-4-50 Z",
	"M-10-40 L-17-115 L-56-202 L-33-211 L0-146 L33-211 L56-202 L17-115 L10-40 Z",
	"M-30-35 C-46-88-74-158-94-188 L-30-213 C-19-158 20-88 30-35 Z",
	"M-15-40 C-15-99-34-160-29-209 L29-209 C34-160 15-99 15-40 Z"]
static var cache: Dictionary={}
static var frame_cache: Dictionary={}
static var texture_frame := -1
const CACHE_BYTES := 8*1024*1024

static func keep_for_frame(key: String,texture: Texture2D) -> void:
	var frame:=Engine.get_process_frames()
	if frame!=texture_frame: frame_cache.clear(); texture_frame=frame
	frame_cache[key]=texture

static func retain(key: String,texture: ImageTexture) -> Texture2D:
	var bytes:=0
	for item in cache.values(): bytes+=VehicleAppearance.texture_bytes(item)
	while not cache.is_empty() and bytes+VehicleAppearance.texture_bytes(texture)>CACHE_BYTES:
		var oldest: String=cache.keys()[0]
		bytes-=VehicleAppearance.texture_bytes(cache[oldest])
		cache.erase(oldest)
	cache[key]=texture
	keep_for_frame(key,texture)
	return texture

static func cached(key: String) -> Texture2D:
	if not cache.has(key): return null
	var texture: Texture2D=cache[key]
	cache.erase(key)
	cache[key]=texture
	keep_for_frame(key,texture)
	return texture

static func tire_only(source: Texture2D,rim_fraction: float,wheel_radius: float) -> Texture2D:
	var key:="tire:"+source.resource_path+":"+str(rim_fraction)+":"+str(wheel_radius)
	var existing:=cached(key)
	if existing!=null: return existing
	var image:=source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var dimensions:=image.get_size()
	var center:=Vector2(dimensions)*.5
	# Authored crops include two reference pixels of padding around each tire.
	var outer:=minf(center.x,center.y)*wheel_radius/(wheel_radius+2.0)
	var inner:=outer*rim_fraction
	var data:=image.get_data()
	for y in dimensions.y:
		for x in dimensions.x:
			var offset:=(y*dimensions.x+x)*4+3
			if data[offset]==0: continue
			var distance:=Vector2(x+.5,y+.5).distance_to(center)
			var alpha:=smoothstep(inner-1.0,inner+.5,distance)*(1.0-smoothstep(outer-.5,outer+.5,distance))
			data[offset]=roundi(data[offset]*alpha)
	image=Image.create_from_data(dimensions.x,dimensions.y,false,Image.FORMAT_RGBA8,data)
	return retain(key,ImageTexture.create_from_image(image))

static func face(design: int,finish: int,pixels: int) -> Texture2D:
	var key:="face:%d:%d:%d"%[design,finish,pixels]
	var existing:=cached(key)
	if existing!=null: return existing
	var color: Color=COLORS[finish]
	var sheen:=.13 if finish==4 else (.46 if finish in [3,5] else .28)
	var dark:=color.darkened(.68).to_html(false)
	var mid:=color.to_html(false)
	var bright:=color.lightened(sheen).to_html(false)
	var svg:='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="-256 -256 512 512">'%[pixels,pixels]
	svg+='<defs><linearGradient id="metal" x1="0" y1="0" x2=".75" y2="1"><stop stop-color="#%s"/><stop offset=".23" stop-color="#%s"/><stop offset=".48" stop-color="#%s"/><stop offset=".70" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient><radialGradient id="lip"><stop offset=".84" stop-color="#%s"/><stop offset=".89" stop-color="#%s"/><stop offset=".93" stop-color="#%s"/><stop offset=".97" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></radialGradient></defs>'%[bright,mid,dark,mid,bright,dark,bright,dark,bright,mid]
	svg+='<circle r="221" fill="none" stroke="url(#lip)" stroke-width="23"/><circle r="207" fill="none" stroke="#%s" stroke-width="3"/>'%dark
	for index in COUNTS[design]:
		var angle: float=360.0*index/int(COUNTS[design])
		svg+='<g transform="rotate(%.3f)"><path d="%s" transform="translate(2 4)" fill="#060a0d" stroke="#060a0d" stroke-width="6"/><path d="%s" fill="url(#metal)" stroke="#%s" stroke-width="2"/><path d="%s" fill="none" stroke="#%s" stroke-opacity=".37" stroke-width="1"/></g>'%[angle,SPOKES[design],SPOKES[design],dark,SPOKES[design],bright]
	if design==4: svg+='<circle r="196" fill="none" stroke="url(#lip)" stroke-width="10"/>'
	svg+='<circle r="49" fill="url(#metal)" stroke="#%s" stroke-width="4"/><circle r="24" fill="#29333a" stroke="#%s" stroke-width="2"/><circle r="17" fill="url(#metal)"/>'%[dark,bright]
	for index in 5:
		var point:=Vector2.from_angle(index*TAU/5)*34
		svg+='<circle cx="%.2f" cy="%.2f" r="7" fill="#080e13"/><circle cx="%.2f" cy="%.2f" r="4" fill="#a5afb5"/>'%[point.x,point.y,point.x-1,point.y-1]
	if design in [4,7]:
		for index in 32:
			var point:=Vector2.from_angle(index*TAU/32)*214
			svg+='<circle cx="%.2f" cy="%.2f" r="2" fill="#%s"/>'%[point.x,point.y,bright]
	svg+='</svg>'
	var image:=Image.new()
	image.load_svg_from_string(svg)
	return retain(key,ImageTexture.create_from_image(image))
