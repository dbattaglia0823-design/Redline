class_name VehicleParts
extends RefCounted

const RETIRED_COOLING_COSTS := {"radiator":1800,"race_cooling":3900}
const RETIRED_CONVERTER_COSTS := {"converter_street":2600,"converter_race":5400}
const TIRE_LADDER := ["","street_tires","uhp_tires","street_radial","competition_radial","drag_slicks"]
const TRANSMISSION_UPGRADES := ["gear_strength","gear_efficiency","gear_cooling","gear_response","gear_pro"]
const INDUCTION_UPGRADES := ["charge_pressure","charge_response","charge_airflow","charge_cooling"]
const INDUCTION_TYPES := ["","turbo_hybrid","roots","centrifugal"]
const TRANSMISSION_TUNE := ["gear_count","ratios","shift_rpms","final_drive","firmness","launch_rpm","launch_gear","clutch_rate","boost_by_gear"]
const TRANSMISSION_SLOTS := ["clutch"]
const SLOTS := ["internals","displacement","compression","intake","fuel","ecu","induction","boost","clutch","differential","wheels","tires","suspension","exhaust","gear_strength","gear_efficiency","gear_cooling","gear_response","gear_pro","charge_pressure","charge_response","charge_airflow","charge_cooling"]
const FINAL_DRIVES := [2.73,3.0,3.20,3.55,3.85,4.10,4.30]
# One installed item per slot; previously bought items remain owned per car.
const PARTS := {
	"gear_strength":{"slot":"gear_strength","name":"Hardened internals","cost":3600,"stage":0,"capacity_scale":1.52,"mass":2.0},
	"gear_efficiency":{"slot":"gear_efficiency","name":"Low-friction bearings","cost":2100,"stage":0,"efficiency_add":0.036},
	"gear_cooling":{"slot":"gear_cooling","name":"Thermal protection","cost":2800,"stage":0,"cooling_scale":2.1},
	"gear_response":{"slot":"gear_response","name":"Shift calibration","cost":3200,"stage":0,"shift_scale":0.73},
	"gear_pro":{"slot":"gear_pro","name":"Billet gearset and case","cost":8200,"stage":0,"capacity_scale":1.35,"cooling_scale":1.15,"mass":3.0},
	"charge_pressure":{"slot":"charge_pressure","name":"Pressure upgrade","cost":3400,"stage":0,"pressure_add":0.22},
	"charge_response":{"slot":"charge_response","name":"Response calibration","cost":2600,"stage":0,"spool_scale":0.72},
	"charge_airflow":{"slot":"charge_airflow","name":"High-flow charge piping","cost":2300,"stage":0,"flow":0.045},
	"charge_cooling":{"slot":"charge_cooling","name":"Charge cooling","cost":3000,"stage":0,"flow":0.03,"safe":1.1,"charge_cooling_scale":1.45},
	"forged":{"slot":"internals","name":"Forged rotating assembly","cost":2800,"stage":0,"safe":1.30,"inertia":-0.012,"redline":250.0},
	"billet":{"slot":"internals","name":"Billet race assembly","cost":6600,"stage":3,"safe":1.65,"inertia":-0.025,"redline":500.0},
	"stroker":{"slot":"displacement","name":"8% stroker kit","cost":4200,"stage":0,"requires":"forged","torque":1.08,"inertia":0.025,"mass":8.0},
	"compression":{"slot":"compression","name":"High-compression pistons","cost":2500,"stage":0,"requires":"fuel_ethanol","torque":1.045,"safe":0.95},
	"intake_street":{"slot":"intake","name":"High-flow air filter","cost":750,"stage":0,"flow":0.028},
	"plenum":{"slot":"intake","name":"High-flow intake plenum","cost":1550,"stage":0,"flow":0.065,"mass":-2.0},
	"intake_velocity":{"slot":"intake","name":"Velocity stack intake","cost":2900,"stage":0,"flow":0.10,"mass":-2.5},
	"intake_race":{"slot":"intake","name":"Race intake manifold","cost":4800,"stage":0,"flow":0.145,"mass":-3.0},
	"fuel_street":{"slot":"fuel","name":"High-flow fuel system","cost":1700,"stage":0,"fuel":1.22},
	"fuel_injectors":{"slot":"fuel","name":"Performance pump and injectors","cost":3100,"stage":0,"fuel":1.38},
	"fuel_ethanol":{"slot":"fuel","name":"Ethanol-ready race fuel kit","cost":5100,"stage":0,"fuel":1.55,"safe":1.12},
	"ecu_street":{"slot":"ecu","name":"Street ECU","cost":950,"stage":0,"launch":true},
	"ecu":{"slot":"ecu","name":"Programmable ECU","cost":2300,"stage":0,"rpm_tune":true,"launch":true},
	"ecu_track":{"slot":"ecu","name":"Track ECU","cost":3800,"stage":0,"torque":1.055,"rpm_tune":true,"launch":true},
	"ecu_race":{"slot":"ecu","name":"Motorsport ECU","cost":5700,"stage":0,"torque":1.08,"rpm_tune":true,"launch":true},
	"turbo_hybrid":{"slot":"induction","name":"Turbocharger","cost":3200,"stage":0,"boost_add":0.32,"onset":2600.0,"spool":0.36},
	"turbo_race":{"slot":"induction","name":"Large-frame turbo","cost":7000,"stage":3,"requires":"fuel_street","boost_add":0.80,"onset":3500.0,"spool":0.60},
	"roots":{"slot":"induction","name":"Roots supercharger","cost":6300,"stage":0,"super":"roots","pressure":0.62,"mass":22.0},
	"centrifugal":{"slot":"induction","name":"Centrifugal supercharger","cost":7200,"stage":0,"super":"centrifugal","pressure":0.88,"mass":16.0},
	"boost_control":{"slot":"boost","name":"Electronic boost controller","cost":1700,"stage":0,"boost_tune":true},
	"clutch_street":{"slot":"clutch","name":"Heavy-duty clutch pack","cost":1450,"stage":0,"clutch":1.2},
	"clutch_twin":{"slot":"clutch","name":"Twin-plate clutch pack","cost":2750,"stage":0,"clutch":1.4},
	"clutch_race":{"slot":"clutch","name":"Race clutch / internal packs","cost":4600,"stage":0,"clutch":1.65},
	"clutch_carbon":{"slot":"clutch","name":"Carbon triple-disc clutch","cost":7800,"stage":0,"clutch":1.95},
	"lsd":{"slot":"differential","name":"Limited-slip differential","cost":2100,"stage":0,"grip":0.055,"mass":3.0},
	"spool":{"slot":"differential","name":"Straight-line locked differential","cost":3000,"stage":2,"grip":0.085,"mass":1.0},
	"light_wheels":{"slot":"wheels","name":"Lightweight road wheel set","cost":1600,"stage":0,"wheel_inertia":-0.5,"mass":-8.0},
	"drag_wheels":{"slot":"wheels","name":"Tall drag wheel set","cost":3300,"stage":2,"radius":0.335,"wheel_inertia":0.4,"mass":4.0},
	"street_tires":{"slot":"tires","name":"Performance street tires","cost":850,"stage":0,"grip":0.12,"rolling":.99,"mass":1.0,"wheel_inertia":.03,"launch_bite":0.025,"slip_loss":0.054,"pressure_peak":32.0},
	"uhp_tires":{"slot":"tires","name":"Ultra-high-performance tires","cost":1750,"stage":0,"grip":0.23,"rolling":1.04,"mass":2.0,"wheel_inertia":.07,"launch_bite":0.037,"slip_loss":0.043,"pressure_peak":30.0},
	"street_radial":{"slot":"tires","name":"Street drag radials","cost":2800,"stage":0,"grip":0.36,"rolling":1.12,"mass":4.0,"wheel_inertia":.14,"launch_bite":0.065,"slip_loss":0.038,"pressure_peak":27.0,"radius_scale":1.012,"sidewall_mark":1},
	"competition_radial":{"slot":"tires","name":"Competition drag radials","cost":4450,"stage":0,"grip":0.45,"rolling":1.18,"mass":6.0,"wheel_inertia":.21,"launch_bite":0.1,"slip_loss":0.031,"pressure_peak":25.0,"radius_scale":1.025,"sidewall_mark":2},
	"drag_slicks":{"slot":"tires","name":"Full drag slicks","cost":6300,"stage":0,"grip":0.54,"rolling":1.25,"mass":7.0,"wheel_inertia":.28,"launch_bite":0.145,"slip_loss":0.032,"pressure_peak":23.0,"radius_scale":1.036,"sidewall_mark":3},
	"pro_drag_radial":{"slot":"tires","name":"Pro drag radials","cost":7900,"stage":0,"grip":.58,"rolling":1.19,"mass":7.0,"wheel_inertia":.25,"launch_bite":.12,"slip_loss":.025,"pressure_peak":24.0,"radius_scale":1.028,"sidewall_mark":2},
	"pro_drag_slicks":{"slot":"tires","name":"Pro soft-compound slicks","cost":9900,"stage":0,"grip":.66,"rolling":1.29,"mass":8.0,"wheel_inertia":.31,"launch_bite":.185,"slip_loss":.020,"pressure_peak":21.0,"radius_scale":1.04,"sidewall_mark":3},
	"street_susp":{"slot":"suspension","name":"Sport suspension","cost":1700,"stage":0,"transfer":0.16,"fwd_transfer":0.1,"mass":-3.0,"frequency":18.0,"hop_damping":0.3,"launch_support":0.023},
	"coilovers":{"slot":"suspension","name":"Adjustable coilovers","cost":2600,"stage":0,"transfer":0.22,"fwd_transfer":0.08,"mass":-4.0,"frequency":16.0,"hop_damping":0.48,"launch_support":0.044,"adjustable":true},
	"drag_susp":{"slot":"suspension","name":"Performance drag suspension","cost":3700,"stage":2,"transfer":0.28,"fwd_transfer":0.065,"mass":-5.0,"frequency":11.0,"hop_damping":0.6,"launch_support":0.069},
	"competition_shocks":{"slot":"suspension","name":"Competition drag shocks and springs","cost":5350,"stage":0,"transfer":0.34,"fwd_transfer":0.042,"mass":-3.0,"frequency":12.0,"hop_damping":0.75,"launch_support":0.1,"adjustable":true},
	"pro_drag_susp":{"slot":"suspension","name":"Professional drag racing suspension","cost":7400,"stage":0,"transfer":0.39,"fwd_transfer":0.024,"mass":1.0,"frequency":13.0,"hop_damping":0.86,"launch_support":0.14,"adjustable":true},
	"active_drag_susp":{"slot":"suspension","name":"Pro four-way drag suspension","cost":10500,"stage":0,"transfer":.43,"fwd_transfer":.016,"mass":1.5,"frequency":14.0,"hop_damping":.93,"launch_support":.18,"adjustable":true},
	"headers":{"slot":"exhaust","name":"Tuned exhaust manifold","cost":2100,"stage":0,"flow":0.045,"mass":-3.0},
}

static func factory_name(slot: String) -> String:
	match slot:
		"induction": return "Factory / Stock"
		"tires": return "Factory tires"
		"suspension": return "Factory suspension"
		"wheels": return "Factory wheels"
	return "Factory hardware"

static func default_build() -> Dictionary:
	return {"transmission":"legacy6","owned_transmissions":["legacy6"],"parts":{},"owned_parts":[],"tune":{},"transmission_tunes":{},"transmission_parts":{},"fitments":{},"performance_stages":{},"owned_performance_stages":{}}

static func normalize(value: Variant, vehicle: String, stage: int = 5) -> Dictionary:
	var b := default_build()
	if not value is Dictionary: return b
	var engine := str(value.get("engine_id",""))
	if GameCatalog.ENGINE_CLASSES.has(engine): b.engine_id=engine
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
	var purchased = value.get("owned_performance_stages",{})
	for trans in b.owned_transmissions:
		b.owned_performance_stages[trans]=maxi(int(b.performance_stages.get(trans,0)),clampi(int(purchased.get(trans,0)),0,5) if purchased is Dictionary else 0)
	var installed = value.get("parts",{})
	if installed is Dictionary:
		for slot in SLOTS:
			var id := str(installed.get(slot,""))
			if is_owned(b,id) and str(PARTS[id].slot) == slot: b.parts[slot] = id
	var saved_tunes: Variant = value.get("transmission_tunes",{})
	if saved_tunes is Dictionary:
		for id in b.owned_transmissions:
			if saved_tunes.get(id) is Dictionary:
				b.transmission_tunes[id] = clean_tune(saved_tunes[id])
	var saved_parts: Variant = value.get("transmission_parts",{})
	if saved_parts is Dictionary:
		for id in b.owned_transmissions:
			if not saved_parts.get(id) is Dictionary: continue
			var slots := {}
			for slot in TRANSMISSION_SLOTS:
				var part: String = str(saved_parts[id].get(slot,""))
				if b.fitments.get(part,[]).has(id) and PARTS[part].slot==slot: slots[slot]=part
			b.transmission_parts[id]=slots
	b.tune = clean_tune(value.get("tune",{}))
	for pass_index in 3:
		for slot in b.parts.keys():
			if compatible(str(b.parts[slot]),b,stage) != "": b.parts.erase(slot)
	return b

static func clean_tune(value: Variant) -> Dictionary:
	var tune := {}
	if value is Dictionary:
		for key in ["gear_count","launch_rpm","redline","boost","final_drive","firmness"]+TuningSetup.EXTRA.keys():
			var number = value.get(key)
			if (number is float or number is int) and is_finite(float(number)): tune[key] = float(number)
		for key in ["ratios","shift_rpms","boost_by_gear"]:
			var numbers = value.get(key)
			if numbers is Array and numbers.size()<=10:
				var valid := true
				for number in numbers:
					if not (number is float or number is int) or not is_finite(float(number)): valid = false
				if valid: tune[key] = numbers.duplicate()
	return tune

static func is_owned(build: Dictionary, id: String) -> bool:
	if not PARTS.has(id) or not build.owned_parts.has(id): return false
	if PARTS[id].slot not in TRANSMISSION_SLOTS: return true
	return build.get("fitments",{}).get(id,[]).has(build.transmission)

static func compatible(id: String, b: Dictionary, stage: int) -> String:
	if not PARTS.has(id): return "Unknown part"
	var p: Dictionary = PARTS[id]
	if p.slot in TRANSMISSION_SLOTS and stage < int(p.stage): return TransmissionCatalog.STAGES[int(p.stage)]+" gearbox required"
	var requirement := missing_requirement(id,b)
	if requirement!="": return str(PARTS[requirement].name)+" required"
	return ""

static func missing_requirement(id: String,b: Dictionary) -> String:
	var required := str(PARTS[id].get("requires",""))
	if required=="" or b.parts.values().has(required): return ""
	if required=="forged" and b.parts.values().has("billet"): return ""
	if required=="fuel_street" and b.parts.get("fuel","") in ["fuel_injectors","fuel_ethanol"]: return ""
	return required

static func control_mode(b: Dictionary) -> String:
	var t := TransmissionCatalog.spec(str(b.transmission))
	return "hpattern" if t.kind == "manual" else ("automatic" if t.kind in ["automatic","drag"] else str(t.kind if t.kind == "sequential" else "paddle"))

static func boost_control_reason(b: Dictionary,base_boost: float,turbo_stage: int) -> String:
	var induction: String=str(b.parts.get("induction",""))
	if induction in ["roots","centrifugal"]: return "Turbo control is inactive on a belt-driven supercharger"
	if base_boost<=0 and turbo_stage==0 and induction not in ["turbo_hybrid","turbo_race"]: return "A turbo or turbo package is required"
	return ""

static func boost_control_limit(b: Dictionary,base_boost: float,turbo_stage: int) -> float:
	if boost_control_reason(b,base_boost,turbo_stage)!="": return 0.0
	var part: Dictionary=PARTS.get(str(b.parts.get("induction","")),{})
	return minf(1.5,base_boost+float(part.get("boost_add",turbo_stage*.18))+.35+float(PARTS.get(b.parts.get("charge_pressure",""),{}).get("pressure_add",0)))

static func switch_transmission(build: Dictionary, id: String) -> void:
	if id == build.transmission: return
	var saved := {}
	for key in TRANSMISSION_TUNE:
		if build.tune.has(key):
			saved[key] = build.tune[key]
			build.tune.erase(key)
	build.transmission_tunes[build.transmission] = saved
	build.tune.merge(build.transmission_tunes.get(id,{}).duplicate(true),true)
	var fitted := {}
	for slot in TRANSMISSION_SLOTS:
		if build.parts.has(slot):
			fitted[slot] = build.parts[slot]
			build.parts.erase(slot)
	build.transmission_parts[build.transmission] = fitted
	build.parts.merge(build.transmission_parts.get(id,{}),true)
	# The most recently fitted legacy gearbox represents its family in the shop.
	build.owned_transmissions.erase(build.transmission)
	build.owned_transmissions.append(build.transmission)
	build.transmission = id
	if not build.owned_transmissions.has(id): build.owned_transmissions.append(id)

static func induction_options(build: Dictionary) -> Array:
	var ids := INDUCTION_TYPES.duplicate()
	if build.parts.get("induction","") == "turbo_race" or (not build.owned_parts.has("turbo_hybrid") and build.owned_parts.has("turbo_race")):
		ids[1] = "turbo_race"
	return ids

static func can_tune_rpm(build: Dictionary) -> bool:
	return PARTS.get(build.parts.get("ecu",""),{}).get("rpm_tune",false)
