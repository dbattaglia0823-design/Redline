class_name VehicleAppearance
extends RefCounted

# Appearance indices are stable save IDs. New choices must be appended.
const CATEGORIES := ["paint","finish","design","rim","sidewall","caliper","tint","stance","spoiler","headlight","taillight","decal"]
const LABELS := ["Paint","Finish","Wheel design","Wheel color","Sidewalls","Calipers","Window tint","Ride height","Spoiler","Headlights","Taillights","Livery"]
const OPTIONS := {
	"paint":["Ember","Seafoam","Bone","Indigo","Saffron","Orchid"],
	"finish":["Gloss","Matte","Metallic"],"design":["Split five","Six spoke","Mesh"],
	"rim":["Silver","Bronze","Graphite"],"sidewall":["Blackwall","White ring","Track marks"],
	"caliper":["Copper","Red","Yellow","Silver"],"tint":["Factory","Smoke","Deep"],
	"stance":["Factory","Street low","Raised"],"spoiler":["Factory","Clean deck","Track wing"],
	"headlight":["Factory","Ice","Amber"],"taillight":["Factory","Ruby","Smoked"],"decal":["Clean","Side stripes","Number 71"]}
const PRICES := {"paint":[0,0,0,0,0,0],"finish":[0,250,450],"design":[0,400,650],"rim":[0,0,0],"sidewall":[0,100,150],"caliper":[0,120,120,120],"tint":[0,120,180],"stance":[0,200,200],"spoiler":[0,100,550],"headlight":[0,140,140],"taillight":[0,140,140],"decal":[0,200,300]}
static var _manifest: Dictionary = {}
static var _textures: Dictionary = {}
static var _frame_textures: Dictionary = {}
static var _texture_frame := -1

static func definition(id: String) -> Dictionary:
	if _manifest.is_empty(): _manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/manifest.json"))
	return _manifest.get(id,{})

static func compatible(id: String,key: String,index: int) -> bool:
	if not OPTIONS.has(key) or index < 0 or index >= OPTIONS[key].size(): return false
	var d := definition(id)
	return d.get("compatible",[]).has(key) and d.get("options",{}).get(key,range(OPTIONS[key].size())).has(index)

static func normalize(raw: Variant, paint: int = 0, rim: int = 0) -> Dictionary:
	var clean: Dictionary = {}
	for key in CATEGORIES: clean[key] = 0
	clean.paint = clampi(paint,0,5); clean.rim = clampi(rim,0,2)
	if raw is Dictionary:
		for key in CATEGORIES:
			if (raw.get(key) is int or raw.get(key) is float) and is_finite(float(raw[key])): clean[key] = clampi(int(raw[key]),0,OPTIONS[key].size()-1)
	return clean

static func owned_defaults(look: Dictionary) -> Array:
	var owned: Array = []
	for key in CATEGORIES:
		owned.append(key+":"+str(look[key]))
		owned.append(key+":0")
	return owned

static func texture(path: String) -> Texture2D:
	# Canvas draw commands hold texture RIDs. Keep their resources alive until this
	# frame has rendered, even when a multi-car view exceeds the persistent cache.
	var frame := Engine.get_process_frames()
	if frame!=_texture_frame: _frame_textures.clear(); _texture_frame=frame
	if _frame_textures.has(path): return _frame_textures[path]
	if not _textures.has(path):
		if not ResourceLoader.exists(path): return null
		if _textures.size() >= 32: _textures.erase(_textures.keys()[0])
		_textures[path] = load(path)
	_frame_textures[path]=_textures[path]
	return _textures[path]

static func point(value: Array) -> Vector2: return Vector2(float(value[0]),float(value[1]))
static func body_drop(look: Dictionary) -> float: return [0.0,7.0,-4.0][int(look.stance)]

static func validate(id: String) -> Array[String]:
	var errors: Array[String] = []
	var d := definition(id)
	if d.is_empty(): return ["Missing vehicle definition: "+id]
	for key in ["rear","front","pivot","exhaust","spoiler"]:
		var p: Array = d.get(key,[])
		if p.size() != 2 or float(p[0]) < 0 or float(p[0]) > 1000 or float(p[1]) < 0 or float(p[1]) > 360: errors.append("Invalid anchor "+key)
	if float(d.get("radius",0)) < 20 or float(d.get("radius",0)) > 100: errors.append("Invalid tire radius")
	for key in ["headlight","taillight"]:
		var segment: Array = d.get(key,[])
		if segment.size() != 2: errors.append("Missing lamp anchors "+key); continue
		for p in segment:
			if not p is Array or p.size() != 2: errors.append("Invalid lamp anchor "+key)
			elif float(p[0]) < 0 or float(p[0]) > 1000 or float(p[1]) < 0 or float(p[1]) > 360: errors.append("Lamp outside artwork "+key)
	for key in d.get("compatible",[]):
		if not OPTIONS.has(key): errors.append("Unsupported option "+str(key))
	var layers: Dictionary = d.get("layers",{})
	for name in ["glass","lamps","spoiler","tint","stripe","number","paint_mask"]:
		if not ResourceLoader.exists(str(layers.get(name,""))): errors.append("Missing texture "+name)
	for paint in 6:
		for finish in ["gloss","matte","metallic"]:
			if not ResourceLoader.exists(str(d.body) % [paint,finish]): errors.append("Missing body variant")
			if d.has("race_body") and not ResourceLoader.exists(str(d.race_body) % [paint,finish]): errors.append("Missing integrated-wheel race body")
	if d.has("race_body"):
		for rim in d.get("rim_radius",[]):
			if float(rim)<=0 or float(rim)>float(d.radius)*.85: errors.append("Rim highlight outside wheel")
		if d.get("rim_radius",[]).size()!=2: errors.append("Missing rim highlight radii")
	# The renderer and physical smoke origin must share the same wheel anchors.
	var spec := GameCatalog.spec(id)
	if d.rear[0] != spec.wheelbase[0] or d.front[0] != spec.wheelbase[1] or d.rear[1] != spec.wheel_y or d.radius != spec.wheel_radius: errors.append("Wheel anchors disagree with effects")
	return errors
