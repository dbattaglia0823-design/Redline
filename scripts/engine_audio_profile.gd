class_name EngineAudioProfile
extends RefCounted

const LAYERS := ["exhaust_on","exhaust_off","intake_on","intake_off","mechanical"]
const ANCHORS := [650.0,800.0,1000.0,1250.0,1560.0,1950.0,2440.0,3050.0,3810.0,4760.0,5950.0,7440.0,9300.0,11625.0]
static var acoustic_designs: Dictionary={}
# Acoustic design estimates informed by the manufacturer references in
# tools/ENGINE_AUDIO_PIPELINE.md. Orders are sound-design values, not gear ratios.
const FACTORY_BLOWERS := {
	"gt500":{"name":"GT500 TVS 2.65","order":12.4,"gain":.072,"harmonic":.22,"sub":.07,"roughness":.025,"air":.018,"bypass":.012},
	"redeye":{"name":"Redeye twin-screw 2.7","order":14.8,"gain":.083,"harmonic":.34,"sub":.12,"roughness":.065,"air":.024,"bypass":.018},
	"demon":{"name":"Demon 170 twin-screw 3.0","order":16.2,"gain":.092,"harmonic":.28,"sub":.17,"roughness":.085,"air":.032,"bypass":.020},
}

static func launch_active(car: Drivetrain) -> bool:
	return car.launch_control and car.gear==car.launch_gear and car.throttle>.2 and car.rpm>car.launch_rpm*.80 and (car.transbrake_active or not car.running or (car.speed<1.0 and car._manual_clutch>.8))

static func launch_pulse(phase: float) -> float:
	# Keep the body of the engine audible between ignition-cut pulses.
	return .62+.38*smoothstep(-.35,.35,sin(phase*TAU))

static func supercharger_character(car: Drivetrain) -> Dictionary:
	if car._supercharger=="": return {"name":"None","order":18.0,"gain":0.0,"harmonic":0.0,"sub":0.0,"roughness":0.0,"air":0.0,"bypass":0.0}
	var id:=str(car.hardware.get("engine_id",car._base_spec.get("id","")))
	if id.is_empty(): id=str(car._base_spec.get("id",""))
	if not car.hardware.parts.has("induction") and FACTORY_BLOWERS.has(id): return FACTORY_BLOWERS[id]
	var centrifugal:=car._supercharger=="centrifugal"
	var row: Dictionary={"name":("Centrifugal / " if centrifugal else "Roots / ")+id,"order":35.2 if centrifugal else 11.6,"gain":.054 if centrifugal else .067,"harmonic":.12 if centrifugal else .38,"sub":.025 if centrifugal else .15,"roughness":.012 if centrifugal else .075,"air":.046 if centrifugal else .024,"bypass":.055 if centrifugal else .016}
	var character: Array=CHARACTER.get(id,[1.0,1.0,1.0])
	row.order*=clampf(.92+float(character[1])*.08,.97,1.03)*(1+car._pressure_add*.12)
	row.gain*=float(character[2])
	return row
# Explicit acoustic tuning, never a horsepower or pitch multiplier.
const CHARACTER := {
 "miata":[.95,.85,.80],"civic_si":[1.16,1.14,.88],"gti_vr6":[.82,.98,1.02],"rsx":[1.12,1.12,.90],"brz":[1.01,1.03,.92],
 "integra":[1.20,1.18,.96],"gti":[.88,.94,.83],"s2000":[1.26,1.20,1.03],"gr86":[.96,1.06,.97],"z350":[1.02,1.02,1.10],
 "supra":[.86,1.06,.98],"m3":[1.20,1.13,1.05],"sti":[.82,1.04,1.12],"evo":[1.01,1.14,1.08],"type_r":[1.15,1.14,.98],
 "mustang":[1.10,1.06,1.08],"supra_gr":[.88,.94,.86],"camaro":[.82,.90,1.12],"golf_r":[.94,.99,.87],"z400":[.91,1.10,.95],
 "z06":[1.28,1.20,1.08],"gtr":[.95,1.15,1.05],"r8":[1.22,1.15,.96],"gt500":[1.02,1.06,1.10],"redeye":[.80,.92,1.16],
 "turbo_s":[.89,.98,.91],"mclaren":[1.18,1.17,.98],"sf90":[1.13,1.06,.90],"demon":[.88,1.12,1.22],"chiron":[.76,.92,1.02]}
static func resolve(car: Drivetrain) -> Dictionary:
	var id:=str(car.hardware.get("engine_id",car._base_spec.get("id","")))
	var turbo:=car._supercharger=="" and car.boost_target(car.redline_rpm,1)>.05
	var family: String
	match car.engine_layout:
		"H4": family="h4_turbo" if turbo else "h4_na"
		"H6": family="h6_turbo" if turbo else "h6_na"
		"VR6": family="vr6_na"
		"I6": family="i6_turbo" if turbo else "i6_na"
		"V6": family="v6_tt" if turbo else "v6_na"
		"V8":
			if car._supercharger!="": family="v8_super"
			elif id in ["z06","mclaren","sf90"]: family="v8_flat_tt" if turbo else "v8_flat"
			else: family="v8_cross"
		"V10": family="v10_na"
		"W16": family="w16_tt"
		_: family="i4_turbo" if turbo else ("i4_vtec" if id in ["civic_si","rsx","integra","s2000"] else "i4_na")
	var c: Array=CHARACTER.get(id,[1.0,1.0,1.0])
	if car._base_spec.has("audio_family_override"): family=str(car._base_spec.audio_family_override)
	var parts: Dictionary=car.hardware.get("parts",{})
	var exhaust:=car.exhaust_stage/3.0+(.20 if parts.values().has("headers") else 0.0)
	var intake:=.45 if parts.values().has("plenum") else 0.0
	var resonance_scale:=.96 if parts.values().has("stroker") else 1.0
	if parts.values().has("compression"): resonance_scale*=1.03
	if acoustic_designs.is_empty(): acoustic_designs=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/engine_designs.json")).vehicles
	return {"id":id,"family":family,"brightness":float(c[0])*resonance_scale,"intake":float(c[1])*(1+intake),"mechanical":float(c[2]),
		"exhaust":exhaust,"flow":car.engine_stage/3.0,"turbo":turbo,"supercharger":car._supercharger,
		"hybrid":float(car._base_spec.get("hybrid_kw",0))>0,"lift_rpm":float(acoustic_designs.get(id,{}).get("lift_rpm",0)),"origin":"original offline synthesis"}

static func weights(at_rpm: float, rows: Array) -> Array:
	var out: Array=[]; out.resize(rows.size()); out.fill(0.0)
	if rows.is_empty(): return out
	if at_rpm<=float(rows[0].rpm): out[0]=1.0; return out
	if at_rpm>=float(rows[-1].rpm): out[-1]=1.0; return out
	for i in rows.size()-1:
		if at_rpm>float(rows[i+1].rpm): continue
		var blend:=clampf(log(at_rpm/float(rows[i].rpm))/log(float(rows[i+1].rpm)/float(rows[i].rpm)),0,1)
		out[i]=1.0-blend; out[i+1]=blend; break
	return out

