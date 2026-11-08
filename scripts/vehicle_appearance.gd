class_name VehicleAppearance
extends RefCounted

# Appearance indices are stable save IDs. New choices must be appended.
const CATEGORIES := ["paint","finish","design","rim","caliper","tint","stance","spoiler","headlight","taillight"]
const LABELS := ["Paint","Finish","Wheel design","Wheel color","Calipers","Window tint","Ride height","Spoiler","Headlights","Taillights"]
const DEFAULT_DESIGN := 1 # Six spoke; saved design IDs remain unchanged.
const OPTIONS := {
	"paint":["Ember","Seafoam","Bone","Indigo","Saffron","Orchid"],
	"finish":["Gloss","Matte","Metallic"],
	"design":["Split five","Six spoke","Mesh","Forged ten","Deep dish","Turbine","Concave seven","Cross-lace","Track six","Y-spoke","Aero disc","Classic eight"],
	"rim":["Silver","Bronze","Graphite","Polished chrome","Satin black","Gloss black","Brushed titanium","Champagne","Pearl white"],
	"caliper":["Copper","Red","Yellow","Silver"],
	"tint":["Factory","Smoke","Deep","Limo 10%","Privacy 5%"],
	"stance":["Factory","Street low","Raised"],"spoiler":["Factory","Clean deck","Track wing"],
	"headlight":["Factory","Ice","Amber"],"taillight":["Factory","Ruby","Smoked"]}
const PRICES := {
	"paint":[0,0,0,0,0,0],"finish":[0,250,450],
	"design":[0,0,650,850,1100,950,900,1250,1000,1150,1400,750],
	"rim":[0,0,0,220,160,190,250,180,170],"caliper":[0,120,120,120],
	"tint":[0,120,180,260,350],"stance":[0,200,200],"spoiler":[0,100,550],
	"headlight":[0,140,140],"taillight":[0,140,140]}
const TINT_OPACITY := [0.0,.32,.65,.90,.95]
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}
static var _frame_textures: Dictionary = {}
static var _texture_frame := -1
const CACHE_BYTES := 32*1024*1024
const MOBILE_CACHE_BYTES := 20*1024*1024

static func texture_bytes(tex: Texture2D) -> int:
	return tex.get_width()*tex.get_height()*4

static func cached_bytes() -> int:
	var total := 0
	for tex in _textures.values(): total += texture_bytes(tex)
	return total

static func definition(id: String) -> Dictionary:
	if _manifest.is_empty(): _manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/manifest.json"))
	return _manifest.get(id,{})

static func compatible(id: String,key: String,index: int) -> bool:
	if not OPTIONS.has(key) or index < 0 or index >= OPTIONS[key].size(): return false
	var d := definition(id)
	return d.get("compatible",[]).has(key) and d.get("options",{}).get(key,range(OPTIONS[key].size())).has(index)

static func normalize(raw: Variant, paint: int = 0, rim: int = 0, legacy_wheels: bool = false) -> Dictionary:
	var clean: Dictionary = {}
	for key in CATEGORIES: clean[key] = 0
	clean.design=DEFAULT_DESIGN
	clean.paint = clampi(paint,0,5); clean.rim = clampi(rim,0,OPTIONS.rim.size()-1)
	if raw is Dictionary:
		for key in CATEGORIES:
			if (raw.get(key) is int or raw.get(key) is float) and is_finite(float(raw[key])): clean[key] = clampi(int(raw[key]),0,OPTIONS[key].size()-1)
	if legacy_wheels and clean.design==0: clean.design=DEFAULT_DESIGN
	return clean

static func owned_defaults(look: Dictionary) -> Array:
	var owned: Array = []
	for key in CATEGORIES:
		owned.append(key+":"+str(look[key]))
		owned.append(key+":0")
	if not owned.has("design:"+str(DEFAULT_DESIGN)): owned.append("design:"+str(DEFAULT_DESIGN))
	return owned

static func texture(path: String) -> Texture2D:
	# Canvas draw commands hold texture RIDs. Keep their resources alive until this
	# frame has rendered, even when a multi-car view exceeds the persistent cache.
	var frame := Engine.get_process_frames()
	if frame!=_texture_frame: _frame_textures.clear(); _texture_frame=frame
	if _frame_textures.has(path): return _frame_textures[path]
	if not _textures.has(path):
		if not ResourceLoader.exists(path): return null
		var tex: Texture2D = load(path)
		var bytes := texture_bytes(tex)
		var retained := cached_bytes()
		var limit := MOBILE_CACHE_BYTES if OS.has_feature("mobile") else CACHE_BYTES
		while not _textures.is_empty() and (_textures.size()>=32 or retained+bytes>limit):
			var oldest: String = _textures.keys()[0]
			retained -= texture_bytes(_textures[oldest]); _textures.erase(oldest)
		_textures[path] = tex
	else:
		# A real LRU: frequent garage/race layers survive a long preview session.
		var tex: Texture2D = _textures[path]
		_textures.erase(path); _textures[path] = tex
	_frame_textures[path]=_textures[path]
	return _textures[path]

static func body_variant_path(definition: Dictionary, paint: int, finish: String) -> String:
	var proposed: String = str(definition.body) % [paint, finish]
	if ResourceLoader.exists(proposed): return proposed
	var backup: String = str(definition.get("fallback_body", ""))
	if backup != "":
		var legacy: String = backup % [paint, finish]
		if ResourceLoader.exists(legacy): return legacy
	return proposed

static func point(value: Array) -> Vector2: return Vector2(float(value[0]),float(value[1]))
# Artwork-only offsets align rim/tire sprites to hubs baked into replacement PNGs.
# Drivetrain wheelbase and tire physics retain canonical anchors; graphical smoke
# follows the calibrated visible tire centers.
static func visual_wheel_anchor(d: Dictionary,index: int) -> Vector2:
	var original: Array=d.rear if index==0 else d.front
	var offsets: Variant=d.get("visual_wheel_offsets",[])
	if not offsets is Array or offsets.size()!=2: return point(original)
	var value: Variant=offsets[index]
	if not value is Array or value.size()!=2: return point(original)
	if not (value[0] is int or value[0] is float) or not (value[1] is int or value[1] is float): return point(original)
	if not is_finite(float(value[0])) or not is_finite(float(value[1])): return point(original)
	return point(original)+point(value)

static func body_drop(look: Dictionary) -> float: return [0.0,7.0,-4.0][int(look.stance)]

static func validate(id: String) -> Array[String]:
	var errors: Array[String] = []
	var d := definition(id)
	if d.is_empty(): return ["Missing vehicle definition: "+id]
	for key in ["rear","front","pivot","exhaust","spoiler"]:
		var p: Array = d.get(key,[])
		if p.size() != 2 or float(p[0]) < 0 or float(p[0]) > 1000 or float(p[1]) < 0 or float(p[1]) > 360: errors.append("Invalid anchor "+key)
	if float(d.get("radius",0)) < 20 or float(d.get("radius",0)) > 100: errors.append("Invalid tire radius")
	if d.has("visual_wheel_offsets"):
		var offsets: Variant=d.visual_wheel_offsets
		if not offsets is Array or offsets.size()!=2:
			errors.append("Invalid visual wheel offset count")
		else:
			for i in 2:
				if not offsets[i] is Array or offsets[i].size()!=2:
					errors.append("Invalid visual wheel offset pair")
				elif not (offsets[i][0] is int or offsets[i][0] is float) or not (offsets[i][1] is int or offsets[i][1] is float):
					errors.append("Invalid visual wheel offset values")
				elif not is_finite(float(offsets[i][0])) or not is_finite(float(offsets[i][1])):
					errors.append("Non-finite visual wheel offset")
				else:
					var adjusted:=visual_wheel_anchor(d,i)
					if adjusted.x<0 or adjusted.x>1000 or adjusted.y<0 or adjusted.y>360:
						errors.append("Visual wheel hub outside artwork")
	for path in d.get("stock_wheels",[]):
		if not ResourceLoader.exists(str(path)): errors.append("Missing authored wheel texture")
	if d.has("stock_wheels") and d.stock_wheels.size()!=2: errors.append("Expected front and rear wheel textures")
	if int(d.get("art_pipeline_version",0))>=2:
		var dimensions: Array=d.get("texture_size",[])
		if dimensions.size()!=2: errors.append("Missing texture dimensions")
		elif int(dimensions[0])>2048 or int(dimensions[1])>1024 or absf(float(dimensions[0])/float(dimensions[1])-1000.0/360.0)>.01: errors.append("Invalid art resolution/aspect")
		if not ResourceLoader.exists(str(d.get("master",""))): errors.append("Missing original normalized master")
	for key in ["headlight","taillight"]:
		var segment: Array = d.get(key,[])
		if segment.size() != 2: errors.append("Missing lamp anchors "+key); continue
		for p in segment:
			if not p is Array or p.size() != 2: errors.append("Invalid lamp anchor "+key)
			elif float(p[0]) < 0 or float(p[0]) > 1000 or float(p[1]) < 0 or float(p[1]) > 360: errors.append("Lamp outside artwork "+key)
	for key in d.get("compatible",[]):
		if not OPTIONS.has(key): errors.append("Unsupported option "+str(key))
	var layers: Dictionary = d.get("layers",{})
	for name in ["glass","lamps","spoiler","tint","paint_mask"]:
		if not ResourceLoader.exists(str(layers.get(name,""))): errors.append("Missing texture "+name)
	for paint in 6:
		for finish in ["gloss","matte","metallic"]:
			if not ResourceLoader.exists(body_variant_path(d,paint,finish)): errors.append("Missing body variant")
			if d.has("race_body") and not ResourceLoader.exists(str(d.race_body) % [paint,finish]): errors.append("Missing integrated-wheel race body")
	if d.has("race_body"):
		for rim in d.get("rim_radius",[]):
			if float(rim)<=0 or float(rim)>float(d.radius)*.85: errors.append("Rim highlight outside wheel")
		if d.get("rim_radius",[]).size()!=2: errors.append("Missing rim highlight radii")
	# The renderer and physical smoke origin must share the same wheel anchors.
	var spec := GameCatalog.spec(id)
	if d.rear[0] != spec.wheelbase[0] or d.front[0] != spec.wheelbase[1] or d.rear[1] != spec.wheel_y or d.radius != spec.wheel_radius: errors.append("Wheel anchors disagree with effects")
	return errors
