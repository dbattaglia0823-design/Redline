class_name VehicleParts
extends RefCounted

const SLOTS := ["internals","displacement","compression","intake","fuel","ecu","induction","boost","clutch","converter","controls","differential","final_drive","wheels","suspension","cooling","transbrake","gearset","exhaust","nitrous"]
const TRANSMISSION_SLOTS := ["clutch","converter","controls","transbrake","gearset"]
const FINAL_DRIVES := [2.73,3.0,3.20,3.55,3.85,4.10,4.30]
# One installed item per slot; previously bought items remain owned per car.
const PARTS := {
	"forged":{"slot":"internals","name":"Forged rotating assembly","cost":2800,"stage":0,"safe":1.30,"inertia":-0.012,"redline":250.0},
	"billet":{"slot":"internals","name":"Billet race assembly","cost":6600,"stage":3,"safe":1.65,"inertia":-0.025,"redline":500.0},
	"stroker":{"slot":"displacement","name":"8% stroker kit","cost":4200,"stage":0,"requires":"forged","torque":1.08,"inertia":0.025,"mass":8.0},
	"compression":{"slot":"compression","name":"High-compression pistons","cost":2500,"stage":0,"requires":"fuel_ethanol","torque":1.045,"safe":0.95},
	"plenum":{"slot":"intake","name":"High-flow intake plenum","cost":1300,"stage":0,"flow":0.065,"mass":-2.0},
	"fuel_street":{"slot":"fuel","name":"High-flow fuel system","cost":1900,"stage":0,"fuel":1.22},
	"fuel_ethanol":{"slot":"fuel","name":"Ethanol-ready race fuel kit","cost":4400,"stage":0,"fuel":1.55,"safe":1.12},
	"ecu":{"slot":"ecu","name":"Programmable ECU","cost":2400,"stage":0,"rpm_tune":true,"launch":true},
	"turbo_hybrid":{"slot":"induction","name":"Hybrid turbo assembly","cost":3200,"stage":0,"boost_add":0.32,"onset":2600.0,"spool":0.36},
	"turbo_race":{"slot":"induction","name":"Large-frame turbo","cost":7000,"stage":3,"requires":"fuel_street","boost_add":0.80,"onset":3500.0,"spool":0.60},
	"roots":{"slot":"induction","name":"Roots supercharger conversion","cost":6300,"stage":0,"super":"roots","pressure":0.62,"mass":22.0},
	"centrifugal":{"slot":"induction","name":"Centrifugal supercharger","cost":7200,"stage":0,"super":"centrifugal","pressure":0.88,"mass":16.0},
	"boost_control":{"slot":"boost","name":"Electronic boost controller","cost":1700,"stage":0,"boost_tune":true},
	"clutch_twin":{"slot":"clutch","name":"Twin-plate clutch pack","cost":2600,"stage":1,"clutch":1.28},
	"clutch_race":{"slot":"clutch","name":"Race clutch / internal packs","cost":4900,"stage":3,"clutch":1.55},
	"converter_street":{"slot":"converter","name":"Adjustable street converter","cost":2600,"stage":1,"stall_min":2200.0,"stall_max":3800.0,"multiplication":1.9},
	"converter_race":{"slot":"converter","name":"Competition converter","cost":5400,"stage":4,"stall_min":3200.0,"stall_max":5800.0,"multiplication":2.15},
	"h_gate":{"slot":"controls","name":"Short-throw H gate","cost":1100,"stage":0,"mode":"hpattern","shift_scale":0.90},
	"selector":{"slot":"controls","name":"Sequential selector + actuator","cost":2900,"stage":2,"mode":"sequential","shift_scale":0.85},
	"paddles":{"slot":"controls","name":"Paddle selector + actuator","cost":3800,"stage":2,"mode":"paddle","shift_scale":0.95},
	"race_controller":{"slot":"controls","name":"Adaptive race shift controller","cost":5800,"stage":4,"mode":"automatic","fine_shift":true},
	"lsd":{"slot":"differential","name":"Limited-slip differential","cost":2100,"stage":0,"grip":0.055,"mass":3.0},
	"spool":{"slot":"differential","name":"Straight-line locked differential","cost":3000,"stage":2,"grip":0.085,"mass":1.0},
	"final_kit":{"slot":"final_drive","name":"Interchangeable final-drive kit","cost":3400,"stage":1,"final_tune":true},
	"light_wheels":{"slot":"wheels","name":"Lightweight road wheel set","cost":1600,"stage":0,"wheel_inertia":-0.5,"mass":-8.0},
	"drag_wheels":{"slot":"wheels","name":"Tall drag wheel / tire package","cost":3300,"stage":2,"radius":0.335,"grip":0.10,"wheel_inertia":0.4,"mass":4.0},
	"street_susp":{"slot":"suspension","name":"Adjustable street suspension","cost":1700,"stage":0,"transfer":0.14,"fwd_transfer":0.12,"mass":-3.0},
	"drag_susp":{"slot":"suspension","name":"Drag weight-transfer package","cost":3700,"stage":2,"transfer":0.25,"fwd_transfer":0.08,"mass":-5.0},
	"radiator":{"slot":"cooling","name":"High-capacity cooling kit","cost":1800,"stage":0,"cooling":1.45,"mass":5.0},
	"race_cooling":{"slot":"cooling","name":"Race engine / transmission coolers","cost":3900,"stage":3,"cooling":2.0,"mass":9.0},
	"transbrake":{"slot":"transbrake","name":"Transbrake valve-body kit","cost":3000,"stage":4,"brake":true},
	"gearset":{"slot":"gearset","name":"Interchangeable ratio cassette kit","cost":6800,"stage":3,"ratio_tune":true},
	"headers":{"slot":"exhaust","name":"Tuned exhaust manifold","cost":2100,"stage":0,"flow":0.045,"mass":-3.0},
	"progressive":{"slot":"nitrous","name":"Progressive nitrous controller","cost":2800,"stage":0,"nitrous_ramp":0.35},
}

static func default_build() -> Dictionary:
	return {"transmission":"legacy6","owned_transmissions":["legacy6"],"parts":{},"owned_parts":[],"tune":{},"fitments":{},"performance_stages":{}}

static func normalize(value: Variant, vehicle: String, stage: int = 5) -> Dictionary:
	var b := default_build()
	if not value is Dictionary: return b
	var owned = value.get("owned_transmissions",[])
	if not owned is Array: owned = []
	if not owned.is_empty() and not owned.has("legacy6"): b.owned_transmissions.clear()
	for id in owned:
		if TransmissionCatalog.compatible(str(id),vehicle) and not b.owned_transmissions.has(id): b.owned_transmissions.append(id)
	var selected := str(value.get("transmission","legacy6"))
	if b.owned_transmissions.has(selected): b.transmission = selected
	owned = value.get("owned_parts",[])
	if not owned is Array: owned = []
	for id in owned:
		if PARTS.has(id) and not b.owned_parts.has(id): b.owned_parts.append(id)
	for id in b.owned_parts:
		var fits: Array = []
		var saved = value.get("fitments",{})
		var recorded = saved.get(id,[]) if saved is Dictionary else []
		if recorded is Array:
			for trans in recorded:
				if b.owned_transmissions.has(trans): fits.append(trans)
		if fits.is_empty(): fits.append(b.transmission)
		b.fitments[id] = fits
	var ranks = value.get("performance_stages",{})
	if ranks is Dictionary:
		for trans in b.owned_transmissions:
			if ranks.has(trans): b.performance_stages[trans] = clampi(int(ranks[trans]),0,5)
	var installed = value.get("parts",{})
	if installed is Dictionary:
		for slot in SLOTS:
			var id := str(installed.get(slot,""))
			if is_owned(b,id) and str(PARTS[id].slot) == slot: b.parts[slot] = id
	if value.get("tune") is Dictionary:
		for key in ["stall","launch_rpm","redline","boost","final_drive","firmness","nitrous_ramp"]:
			var number = value.tune.get(key)
			if (number is float or number is int) and is_finite(float(number)): b.tune[key] = float(number)
		for key in ["ratios","shift_rpms"]:
			var numbers = value.tune.get(key)
			if numbers is Array:
				var valid := true
				for number in numbers:
					if not (number is float or number is int) or not is_finite(float(number)): valid = false
				if valid: b.tune[key] = numbers.duplicate()
	for pass_index in 3:
		for slot in b.parts.keys():
			if compatible(str(b.parts[slot]),b,stage) != "": b.parts.erase(slot)
	return b

static func is_owned(build: Dictionary, id: String) -> bool:
	if not PARTS.has(id) or not build.owned_parts.has(id): return false
	if PARTS[id].slot not in TRANSMISSION_SLOTS: return true
	return build.get("fitments",{}).get(id,[]).has(build.transmission)

static func compatible(id: String, b: Dictionary, stage: int) -> String:
	if not PARTS.has(id): return "Unknown part"
	var p: Dictionary = PARTS[id]
	if p.slot in ["clutch","converter","controls","transbrake","gearset"] and stage < int(p.stage): return TransmissionCatalog.STAGES[int(p.stage)]+" gearbox required"
	var trans := TransmissionCatalog.spec(str(b.transmission))
	var kind: String = trans.kind
	var slot: String = p.slot
	if slot == "converter" and kind not in ["automatic","drag"]: return "Converter automatic required"
	if slot == "transbrake" and kind != "drag": return "Drag automatic required"
	if slot == "controls":
		if id == "h_gate" and kind != "manual": return "Manual gearbox required"
		if kind == "drag" and id != "race_controller": return "Drag controller required"
		if id == "selector" and kind not in ["manual","sequential"]: return "Manual or sequential required"
		if id == "race_controller" and kind not in ["automatic","dct","drag"]: return "Automatic or DCT required"
	var requirement := str(p.get("requires",""))
	if requirement != "" and not b.parts.values().has(requirement):
		var equivalent: bool = (requirement == "forged" and b.parts.values().has("billet")) or (requirement == "fuel_street" and b.parts.values().has("fuel_ethanol"))
		if not equivalent: return str(PARTS[requirement].name)+" required"
	return ""

static func control_mode(b: Dictionary) -> String:
	var t := TransmissionCatalog.spec(str(b.transmission))
	var kit := str(b.parts.get("controls",""))
	if PARTS.has(kit) and compatible(kit,b,5) == "": return str(PARTS[kit].mode)
	return "hpattern" if t.kind == "manual" else ("automatic" if t.kind in ["automatic","drag"] else str(t.kind if t.kind == "sequential" else "paddle"))

static func boost_control_reason(b: Dictionary,base_boost: float,turbo_stage: int) -> String:
	var induction: String=str(b.parts.get("induction",""))
	if induction in ["roots","centrifugal"]: return "Turbo control is inactive on a belt-driven supercharger"
	if base_boost<=0 and turbo_stage==0 and induction not in ["turbo_hybrid","turbo_race"]: return "A turbo or turbo package is required"
	return ""

static func boost_control_limit(b: Dictionary,base_boost: float,turbo_stage: int) -> float:
	if boost_control_reason(b,base_boost,turbo_stage)!="": return 0.0
	var part: Dictionary=PARTS.get(str(b.parts.get("induction","")),{})
	return minf(1.5,base_boost+float(part.get("boost_add",turbo_stage*.18))+.35)
