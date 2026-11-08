class_name GameCatalog
extends RefCounted

const CAR_IDS: Array[String] = RosterData.IDS
const CARS := {
	"kaze": {"name":"Kaze S2", "year":"1996", "description":"The original late-night project.", "engine":"2.0L turbo I4", "drive":"RWD", "throttle_response":0.032, "torque":238.0, "mass":1280.0, "price":0, "grip":0.57, "wheelbase":[215,790], "wheel_y":274, "wheel_radius":73},
	"nori": {"name":"Nori Club RS", "year":"1991", "description":"Lightweight. Short wheelbase. Big personality.", "engine":"1.8L turbo I4", "drive":"FWD", "throttle_response":0.028, "torque":210.0, "mass":1030.0, "price":5200, "grip":0.61, "wheelbase":[208,786], "wheel_y":274, "wheel_radius":70},
	"aster": {"name":"Aster GT", "year":"2004", "description":"A straight-six built for the long run.", "engine":"3.0L turbo I6", "drive":"RWD", "throttle_response":0.038, "torque":335.0, "mass":1390.0, "price":12500, "grip":0.66, "wheelbase":[212,794], "wheel_y":274, "wheel_radius":76},
	"vanta": {"name":"Vanta RX", "year":"2024", "description":"All-wheel traction. Relentless acceleration.", "engine":"3.8L twin-turbo V6", "drive":"AWD", "throttle_response":0.030, "torque":460.0, "mass":1490.0, "price":32000, "grip":0.82, "wheelbase":[209,799], "wheel_y":274, "wheel_radius":78},
	"mika":{"name": "Vale Mika", "brand": "Vale", "year": "1989", "engine": "1.6L NA I4", "drive": "FWD", "torque": 118, "mass": 890, "grip": 0.58, "price": 2800, "factory_trans": "manual5", "unlock_level": 0, "performance_class": "Street", "redline": 6800, "cylinders": 4, "base_boost": 0.0, "inertia": 0.16, "tire_radius": 0.29, "final_drive": 4.1, "torque_curve": [[0, 0.42], [0.15, 0.64], [0.35, 0.85], [0.55, 0.95], [0.75, 1], [0.9, 0.98], [1, 0.87], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional street build."},
	"brindle":{"name": "Brimstone Rook", "brand": "Brimstone", "year": "1971", "engine": "5.0L NA V8", "drive": "RWD", "torque": 410, "mass": 1650, "grip": 0.62, "price": 9000, "factory_trans": "manual4", "unlock_level": 0, "performance_class": "Muscle", "redline": 6200, "cylinders": 8, "base_boost": 0.0, "inertia": 0.38, "tire_radius": 0.34, "final_drive": 3.55, "torque_curve": [[0, 0.72], [0.15, 0.9], [0.35, 1], [0.55, 0.98], [0.75, 0.88], [0.9, 0.76], [1, 0.65], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional muscle build."},
	"comet":{"name": "Brimstone Comet", "brand": "Brimstone", "year": "2023", "engine": "6.2L NA V8", "drive": "RWD", "torque": 620, "mass": 1760, "grip": 0.8, "price": 29000, "factory_trans": "auto10", "unlock_level": 2, "performance_class": "Muscle", "redline": 7100, "cylinders": 8, "base_boost": 0.0, "inertia": 0.33, "tire_radius": 0.34, "final_drive": 3.2, "torque_curve": [[0, 0.72], [0.15, 0.9], [0.35, 1], [0.55, 0.98], [0.75, 0.88], [0.9, 0.76], [1, 0.65], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional muscle build."},
	"rikka":{"name": "Kaze Rikka", "brand": "Kaze", "year": "2002", "engine": "2.0L turbo I4", "drive": "AWD", "torque": 320, "mass": 1350, "grip": 0.79, "price": 16000, "factory_trans": "manual6", "unlock_level": 1, "performance_class": "Sport", "redline": 7900, "cylinders": 4, "base_boost": 0.55, "inertia": 0.24, "tire_radius": 0.315, "final_drive": 4.1, "torque_curve": [[0, 0.42], [0.15, 0.64], [0.35, 0.85], [0.55, 0.95], [0.75, 1], [0.9, 0.98], [1, 0.87], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional sport build."},
	"velora":{"name": "Velora Sable", "brand": "Velora", "year": "2018", "engine": "3.0L turbo I6", "drive": "RWD", "torque": 380, "mass": 1460, "grip": 0.76, "price": 24500, "factory_trans": "dct7", "unlock_level": 2, "performance_class": "GT", "redline": 7500, "cylinders": 6, "base_boost": 0.65, "inertia": 0.28, "tire_radius": 0.33, "final_drive": 3.55, "torque_curve": [[0, 0.42], [0.15, 0.64], [0.35, 0.85], [0.55, 0.95], [0.75, 1], [0.9, 0.98], [1, 0.87], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional gt build."},
	"solenne":{"name": "Solenne Veloce", "brand": "Solenne", "year": "2015", "engine": "4.5L NA V8", "drive": "RWD", "torque": 500, "mass": 1420, "grip": 0.9, "price": 68000, "factory_trans": "dct7", "unlock_level": 5, "performance_class": "Exotic", "redline": 8800, "cylinders": 8, "base_boost": 0.0, "inertia": 0.2, "tire_radius": 0.33, "final_drive": 3.85, "torque_curve": [[0, 0.42], [0.15, 0.64], [0.35, 0.85], [0.55, 0.95], [0.75, 1], [0.9, 0.98], [1, 0.87], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional exotic build."},
	"aurora":{"name": "Solenne Aurora", "brand": "Solenne", "year": "2025", "engine": "5.2L NA V10", "drive": "AWD", "torque": 570, "mass": 1500, "grip": 1.0, "price": 92000, "factory_trans": "dct8", "unlock_level": 5, "performance_class": "Exotic", "redline": 9000, "cylinders": 10, "base_boost": 0.0, "inertia": 0.25, "tire_radius": 0.34, "final_drive": 3.55, "torque_curve": [[0, 0.42], [0.15, 0.64], [0.35, 0.85], [0.55, 0.95], [0.75, 1], [0.9, 0.98], [1, 0.87], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional exotic build."},
	"hammer":{"name": "Brimstone Hammer", "brand": "Brimstone", "year": "1994", "engine": "7.0L boosted V8", "drive": "RWD", "torque": 750, "mass": 1250, "grip": 1.1, "price": 58000, "factory_trans": "drag3", "unlock_level": 5, "performance_class": "Drag", "redline": 7600, "cylinders": 8, "base_boost": 0.7, "inertia": 0.35, "tire_radius": 0.355, "final_drive": 3.0, "torque_curve": [[0, 0.72], [0.15, 0.9], [0.35, 1], [0.55, 0.98], [0.75, 0.88], [0.9, 0.76], [1, 0.65], [1.15, 0.2]], "wheelbase": [215, 790], "wheel_y": 274, "wheel_radius": 73, "description": "Original fictional drag build."},
}
const PART_NAMES: Array[String] = ["Engine", "Turbo", "Tires", "Weight", "Gearbox", "Exhaust", "Brakes", "Nitrous"]
const PART_COSTS: Array[int] = [700,1000,600,800,900,450,400,650]
const STAGE_PRICE_MULTIPLIERS := [0,1,3,8,18,36]
const CHAMPIONSHIP_BET_BASE := [500,1000,2000,3500,7000,16000]
const CHAMPIONSHIP_BET_SCALE := [1.0,1.5,2.2,3.2,4.6,6.5,9.0,12.5,17.0,25.0]

static func championship_bet_cap(letter: String,round_index: int) -> int:
	var rank: int=["E","D","C","B","A","S"].find(letter)
	if rank<0: return 0
	return roundi(float(CHAMPIONSHIP_BET_BASE[rank])*float(CHAMPIONSHIP_BET_SCALE[clampi(round_index,0,9)])/100)*100

static func stage_cost(category: int,tier: int) -> int:
	if category<0 or category>=PART_COSTS.size() or tier<1 or tier>max_stage(category): return 0
	return PART_COSTS[category]*STAGE_PRICE_MULTIPLIERS[tier]
const PART_TIERS := [
	["Street airflow build", "Performance airflow build", "Race airflow build"],
	["Quick-spool turbo", "Street hybrid", "Big-frame turbo"],
	["Sport compound", "Drag radial", "Competition slick"],
	["Lightweight panels", "Interior strip", "Carbon package"],
	["Paddle calibration", "Quick-shift clutch", "Race transmission"],
	["Sport cat-back", "High-flow downpipe", "Titanium system"],
	["Performance pads", "Four-piston kit", "Carbon race kit"],
	["Street bottle", "Extended bottle", "Competition spray"],
]
const PART_EFFECTS: Array[String] = ["+14% engine torque per tier", "+2.6 PSI peak boost per tier", "+0.095 traction coefficient per tier", "-143 lb per tier", "-35 ms shift time per tier", "+6% engine torque per tier", "Stronger, lighter brake packages", "+1.5 s spray / +6% power per tier"]
const CAREER_NAMES: Array[String] = ["DOCKSIDE RUN", "MIDNIGHT CLUB", "CITY FINALS"]
const CAREER_LEVELS: Array[int] = [1,3,5]
# Fixed engine tiers preserve the established factory race classes.
const ENGINE_CLASSES := {
	"miata":"E", "civic_si":"E", "gti_vr6":"E",
	"brz":"D", "gti":"D", "integra":"D", "rsx":"D",
	"evo":"C", "gr86":"C", "s2000":"C", "sti":"C", "type_r":"C", "z350":"C",
	"golf_r":"B", "m3":"B", "supra":"B", "supra_gr":"B",
	"camaro":"A", "gtr":"A", "mustang":"A", "r8":"A", "redeye":"A", "z400":"A",
	"chiron":"S", "demon":"S", "gt500":"S", "mclaren":"S", "sf90":"S", "turbo_s":"S", "z06":"S",
}
const ENGINE_FIELDS := ["engine","layout","cylinders","torque","torque_curve","torque_rpm","idle","redline",
	"throttle_response","inertia","base_boost","factory_super","hybrid_kw","hybrid_kwh"]
const BOT_NAMES := [
	["Dockhand Dex", "Neon Nia", "Spanner Sol", "Late-shift Leo", "Harbor Quinn"],
	["Vinyl Vera", "Boost Benji", "Night Owl", "Slick Sora", "Midnight Mara"],
	["Axle Ace", "Circuit Cora", "Redline Remy", "Ghost Gia", "King of the Cut"],
]

static func spec(id: String) -> Dictionary:
	if RosterData.rows().has(id):
		var item: Dictionary=RosterData.rows()[id].duplicate(true)
		item.name=item.get("display_name",item.name)
		item.throttle_response=item.get("throttle_response",.028 if int(item.cylinders)==4 else .034 if int(item.cylinders)<=6 else .038)
		return item
	var data: Dictionary = CARS.get(id, CARS["kaze"]).duplicate(true)
	if data.has("factory_trans") and not data.has("throttle_response"): data["throttle_response"] = .032 if int(data.get("cylinders",4)) == 4 else .038
	if not data.has("brand"): data["brand"] = {"kaze":"Kaze","nori":"Nori","aster":"Aster","vanta":"Vanta"}.get(id,"Kaze")
	if not data.has("performance_class"): data["performance_class"] = {"kaze":"Sport","nori":"Street","aster":"GT","vanta":"GT"}.get(id,"Sport")
	return data

static func engine_class(vehicle: String, build: Dictionary = {}) -> String:
	var engine := str(build.get("engine_id",""))
	if ENGINE_CLASSES.has(engine): return ENGINE_CLASSES[engine]
	return ENGINE_CLASSES.get(RosterData.RETIRED.get(vehicle,vehicle),"E")

static func installed_spec(vehicle: String, build: Dictionary) -> Dictionary:
	return with_engine(spec(vehicle),str(build.get("engine_id","")))

static func with_engine(chassis: Dictionary, engine: String) -> Dictionary:
	if not ENGINE_CLASSES.has(engine) or chassis.get("id")==engine: return chassis
	var donor := spec(engine)
	var combined := chassis.duplicate(true)
	for field in ENGINE_FIELDS:
		combined.erase(field)
		if donor.has(field): combined[field]=donor[field]
	return combined

static func blank_stages() -> Array:
	return [0,0,0,0,0,0,0,0]

static func part_effect(index: int, tier: int) -> String:
	match index:
		0: return "+%d%% engine torque" % (tier*14)
		1: return "%.1f PSI peak boost" % PressureUnits.psi(0.45+tier*0.18)
		2: return "+%.3f traction coefficient" % (tier*0.095)
		3: return "-%.0f lb curb weight" % ImperialUnits.pounds(tier*65)
		4: return "%d MS original paddle cut" % roundi(TransmissionCatalog.duration("legacy6",tier)*1000.0)
		5: return "+%d%% engine torque" % (tier*6)
		6: return "+%d%% braking force / -%.0f lb" % [tier*18,ImperialUnits.pounds([0.0,4.0,9.0,15.0][clampi(tier,0,3)])]
		7: return "%.1f S spray / +%d%% power" % [6.0+tier*1.5,55+tier*6]
	return ""

static func normalize_stages(value: Variant) -> Array:
	var stages := blank_stages()
	if value is Array:
		for i in mini(value.size(), stages.size()):
			if (value[i] is int or value[i] is float) and is_finite(float(value[i])): stages[i] = clampi(int(value[i]), 0, max_stage(i))
	return stages

# Fixed career builds: upgrading the player's car never upgrades an already-known rival.
# Rows are model, engine, induction, tires, weight, gearbox stage, exhaust, gearbox swap.
const CAREER_BUILDS := [
	[["miata",0,0,0,0,0,0,""],["miata",1,0,0,0,0,0,""],["civic_si",1,0,1,0,1,1,""],["gti_vr6",1,0,1,0,1,1,""],["rsx",1,0,1,1,2,1,""]],
	[["brz",2,0,1,1,2,1,""],["gti",2,1,1,1,2,1,""],["supra",1,1,1,1,2,1,""],["evo",2,1,2,1,3,1,""],["supra",2,1,2,1,4,1,"seq6"]],
	[["mustang",1,0,2,1,3,1,""],["camaro",2,0,2,1,4,2,"drag3"],["gtr",2,1,2,1,4,1,""],["mclaren",1,1,2,1,4,1,""],["chiron",2,1,3,2,5,2,""]]
]
static func opponent(career: int, index: int, _profile: DriverProfile = null) -> Dictionary:
	career = clampi(career,0,2); index = clampi(index,0,4)
	var row: Array = CAREER_BUILDS[career][index]
	var model := str(row[0])
	var stages: Array = [row[1],row[2],row[3],row[4],row[5],row[6],0,0]
	var hardware := factory_build(model)
	if str(row[7]) != "":
		hardware.transmission = str(row[7]); hardware.owned_transmissions.append(str(row[7]))
	return {"hardware":hardware,"skill":career,"traction_skill":.35+career*.25,"shift_error":260.0-career*90-index*20,
		"launch_rpm":3900.0,"driver_seed":career*5+index,"name":BOT_NAMES[career][index],"model":model,"stages":stages,
		"distance":402.336,"purse":0,
		"max_bet":championship_bet_cap(engine_class(model,hardware),mini(9,index*2)),"reaction":.65-index*.06 if career==0 else .30-career*.06-index*.012,
		"pedal":.80+index*.04 if career==0 else .94+index*.015,"shift_rpm":6800.0+career*80,"shift_delay":.17-career*.035,
		"race_class":engine_class(model,hardware),"build_label":"Stock" if index==0 and career==0 else "Tuned"}

static func max_stage(index: int) -> int:
	return 5 if index == 4 else 3

static func stage_name(index: int, stage: int) -> String:
	if index == 4: return TransmissionCatalog.STAGES[clampi(stage,0,5)]
	return "Stock" if stage == 0 else str(PART_TIERS[index][clampi(stage-1,0,2)])

static func factory_build(id: String) -> Dictionary:
	var build := VehicleParts.default_build()
	var gearbox: String = str(spec(id).get("factory_trans","legacy6"))
	build.transmission = gearbox
	build.owned_transmissions = [gearbox]
	return build


