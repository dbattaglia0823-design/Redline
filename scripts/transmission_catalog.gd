class_name TransmissionCatalog
extends RefCounted

const STAGES := ["Stock","Stage 1","Stage 2","Stage 3","Race","Pro Race"]
# Ratios are sourced/inspired; all masses, costs, limits and fitments are game estimates.
# name, type, ratios, kg, efficiency, seconds, Nm, cost, required stage, layout
# Legacy rows remain addressable for existing saves and simulations. Only type_options populates the shop.
const ROWS := {
	"manual_type":["Manual","manual",[3.10,1.95,1.34,1.0,0.76],45.0,0.95,0.34,650.0,2600,0,"ALL"],
	"sequential_type":["Sequential / Paddle","sequential",[3.10,2.20,1.66,1.32,1.09,0.90],48.0,0.96,0.13,850.0,6200,0,"ALL"],
	"automatic_type":["Automatic","automatic",[4.17,2.34,1.52,1.14,0.87,0.69],82.0,0.92,0.19,800.0,4600,0,"ALL"],
	"drag_type":["Drag Automatic","drag",[2.10,1.40,1.0],54.0,0.96,0.085,1500.0,9500,0,"LONG"],
	"legacy6":["Original 6P","paddle",[3.10,2.12,1.53,1.17,0.94,0.78],50.0,0.90,0.16,750.0,2400,0,"ALL"],
	"manual3":["Classic 3M","manual",[2.85,1.68,1.0],38.0,0.94,0.42,420.0,1400,0,"ALL"],
	"manual4":["Sport 4M","manual",[2.52,1.88,1.46,1.0],43.0,0.95,0.36,550.0,2200,0,"ALL"],
	"manual5":["Touring 5M","manual",[2.87,1.89,1.28,1.0,0.81],45.0,0.95,0.34,650.0,3100,0,"ALL"],
	"manual6":["Close-ratio 6M","manual",[2.66,1.78,1.30,1.0,0.80,0.63],58.0,0.95,0.30,800.0,4400,1,"ALL"],
	"auto3":["Street 3A","automatic",[2.48,1.48,1.0],67.0,0.88,0.25,650.0,2800,0,"LONG"],
	"auto4":["Overdrive 4A","automatic",[2.48,1.48,1.0,0.75],82.0,0.89,0.23,750.0,4000,1,"ALL"],
	"seq5":["Dogbox 5S","sequential",[2.69,2.01,1.59,1.31,1.0],40.0,0.96,0.14,700.0,5200,1,"ALL"],
	"seq6":["Dogbox 6S","sequential",[2.80,2.15,1.71,1.40,1.18,1.0],44.0,0.96,0.12,850.0,6800,2,"ALL"],
	"seq7":["Endurance 7S","sequential",[3.00,2.31,1.85,1.52,1.28,1.10,0.96],49.0,0.95,0.11,1000.0,8800,3,"ALL"],
	"dct6":["Twin-clutch 6D","dct",[3.46,2.15,1.46,1.08,0.86,0.69],83.0,0.94,0.105,650.0,7200,2,"ALL"],
	"dct7":["Twin-clutch 7D","dct",[3.91,2.43,1.75,1.31,1.0,0.82,0.68],88.0,0.95,0.095,850.0,9400,2,"ALL"],
	"dct8":["Twin-clutch 8D","dct",[4.08,2.73,1.96,1.52,1.22,1.0,0.84,0.68],94.0,0.95,0.085,1050.0,12800,3,"LONG"],
	"auto6":["Modern 6A","automatic",[4.17,2.34,1.52,1.14,0.87,0.69],85.0,0.92,0.19,800.0,6300,1,"ALL"],
	"auto7":["Modern 7A","automatic",[4.38,2.86,1.92,1.37,1.0,0.82,0.73],91.0,0.92,0.18,900.0,8200,2,"LONG"],
	"auto8":["Modern 8A","automatic",[4.71,3.14,2.11,1.67,1.29,1.0,0.84,0.67],95.0,0.94,0.16,1000.0,10500,2,"ALL"],
	"auto9":["Modern 9A","automatic",[5.35,3.24,2.25,1.64,1.21,1.0,0.86,0.72,0.60],100.0,0.93,0.17,1050.0,13000,3,"LONG"],
	"auto10":["10R-inspired 10A","automatic",[4.696,2.985,2.146,1.769,1.520,1.275,1.0,0.854,0.689,0.636],104.0,0.94,0.17,1100.0,16000,3,"LONG"],
	"drag2":["Glide-inspired 2D","drag",[1.80,1.0],42.0,0.97,0.085,1500.0,11500,4,"LONG"],
	"drag3":["Competition 3D","drag",[2.10,1.40,1.0],54.0,0.96,0.075,1700.0,15500,4,"LONG"],
	"drag4":["Competition 4D","drag",[2.48,1.48,1.0,0.75],71.0,0.95,0.080,1900.0,19500,5,"LONG"],
}

static func spec(id: String) -> Dictionary:
	if id.begins_with("oem_"):
		var factory:=RosterData.factory_transmission(id)
		if not factory.is_empty(): return factory
	var r: Array = ROWS.get(id,ROWS.legacy6)
	return {"id":id if ROWS.has(id) else "legacy6","name":r[0],"kind":r[1],"ratios":r[2].duplicate(),"mass":r[3],"efficiency":r[4],"shift":r[5],"capacity":r[6],"cost":r[7],"stage":r[8],"layout":r[9]}

static func compatible(id: String, vehicle: String) -> bool:
	if id.begins_with("oem_"): return id=="oem_"+vehicle and RosterData.rows().has(vehicle)
	if vehicle=="sf90": return id in ["dct8","sequential_type"] # Hybrid motor/gearbox integration; no unsupported manual/drag swap.
	return ROWS.has(id) and (spec(id).layout == "ALL" or str(GameCatalog.spec(vehicle).drive) != "FWD")

static func duration(id: String, stage: int) -> float:
	if id == "legacy6": return maxf(0.035,0.16-stage*0.035)
	var s := spec(id)
	var scale: float = [1.0,0.86,0.73,0.62,0.52,0.43][clampi(stage,0,5)]
	var minimum := 0.14 if s.kind == "manual" else (0.035 if s.kind in ["drag","dct"] else 0.055)
	return maxf(minimum,float(s.shift)*scale)

static func strength(stage: int) -> float:
	# Upper tiers must cover a fully built engine's boosted + nitrous torque,
	# even on the lower-rated manual conversions. Optional internals add reserve.
	return [1.0,1.25,1.65,2.40,3.80,5.60][clampi(stage,0,5)]
static func family(id: String) -> String:
	var kind: String = spec(id).kind
	return kind if kind in ["manual","automatic","drag"] else "sequential"

const TYPES := {
	"manual":"Manual",
	"sequential":"Sequential / Paddle",
	"automatic":"Automatic",
	"drag":"Drag Automatic"
}
const CONVERSIONS := {"manual":"manual_type","sequential":"sequential_type","automatic":"automatic_type","drag":"drag_type"}
const GEAR_RANGES := {"manual":Vector2i(3,6),"sequential":Vector2i(5,7),"automatic":Vector2i(3,10),"drag":Vector2i(2,4)}

static func type_options(build: Dictionary) -> Array:
	var ids := CONVERSIONS.duplicate()
	for id in build.owned_transmissions:
		ids[family(id)] = id
	ids[family(build.transmission)] = build.transmission
	return TYPES.keys().map(func(kind): return ids[kind])

static func gear_range(id: String) -> Vector2i:
	var limits: Vector2i = GEAR_RANGES[family(id)]
	return Vector2i(limits.x,maxi(limits.y,spec(id).ratios.size()))

static func default_ratios(id: String, tune: Dictionary) -> Array:
	var original: Array = spec(id).ratios
	if not tune.has("gear_count"): return original
	var limits := gear_range(id)
	var count := clampi(int(tune.gear_count),limits.x,limits.y)
	if count == original.size(): return original
	var ratios := []
	for i in count:
		ratios.append(snappedf(float(original.front())*pow(float(original.back())/float(original.front()),float(i)/(count-1)),0.001))
	return ratios

const MIN_RATIO := .30
const MAX_RATIO := 6.0
const GEAR_GAP := .03
const FINAL_MIN := 2.0
const FINAL_MAX := 5.5

static func count_limits(id: String) -> Vector2i: return gear_range(id)
static func gear_count(build: Dictionary) -> int: return default_ratios(str(build.transmission),build.tune).size()

# Accept the existing (ratios, defaults) API and the explicit catalog/count API.
static func valid_ratios(first: Variant,second: Variant,count: int = -1) -> bool:
	var ratios: Variant=second if count>=0 else first
	var expected: int=count if count>=0 else (second.size() if second is Array else 0)
	var defaults: Array=spec(str(first)).ratios if count>=0 else (second if second is Array else [])
	if count>=0:
		var limits:=count_limits(str(first))
		if count<limits.x or count>limits.y: return false
	if not ratios is Array or ratios.size()!=expected: return false
	for i in ratios.size():
		if not (ratios[i] is float or ratios[i] is int) or not is_finite(float(ratios[i])): return false
		if float(ratios[i])<MIN_RATIO or float(ratios[i])>MAX_RATIO: return false
		if i>0:
			if float(ratios[i-1])<=float(ratios[i]): return false
			var tight: bool=float(ratios[i-1])-float(ratios[i])<GEAR_GAP-.000001 or float(ratios[i-1])<float(ratios[i])*1.025-.000001
			# Preserve authored close factory pairs when tuning another gear.
			# Once this pair is edited, normal cassette spacing applies.
			if tight and not (i<defaults.size() and absf(float(ratios[i-1])-float(defaults[i-1]))<.000001 and absf(float(ratios[i])-float(defaults[i]))<.000001): return false
	return true

static func resized_ratios(current: Array,count: int) -> Array:
	var out := current.slice(0,mini(count,current.size()))
	while out.size()<count:
		var previous: float = float(out[-1]) if not out.is_empty() else 3.1
		out.append(maxf(MIN_RATIO,previous*.80))
	# Reserve space below each retained gear. Only very tightly packed low
	# ratios need to move when new overdrive gears are appended.
	for i in range(count-1,-1,-1):
		out[i]=clampf(float(out[i]),MIN_RATIO+(count-1-i)*GEAR_GAP,MAX_RATIO-i*GEAR_GAP)
		if i<count-1: out[i]=maxf(float(out[i]),maxf(float(out[i+1])+GEAR_GAP,float(out[i+1])*1.025))
	return out

static func ratio_bounds(ratios: Array,index: int) -> Vector2:
	var lower := MIN_RATIO if index==ratios.size()-1 else maxf(float(ratios[index+1])+GEAR_GAP,float(ratios[index+1])*1.025)
	var upper := MAX_RATIO if index==0 else minf(float(ratios[index-1])-GEAR_GAP,float(ratios[index-1])/1.025)
	return Vector2(lower,upper)
