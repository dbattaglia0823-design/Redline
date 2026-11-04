class_name EngineAudioProfile
extends RefCounted

const LAYERS := ["exhaust_on","exhaust_off","intake_on","intake_off","mechanical"]
const ANCHORS := [650.0,800.0,1000.0,1250.0,1560.0,1950.0,2440.0,3050.0,3810.0,4760.0,5950.0,7440.0,9300.0,11625.0]
static var acoustic_designs: Dictionary={}
# Explicit acoustic tuning, never a horsepower or pitch multiplier.
const CHARACTER := {
 "miata":[.95,.85,.80],"civic_si":[1.16,1.14,.88],"gti_vr6":[.82,.98,1.02],"rsx":[1.12,1.12,.90],"brz":[1.01,1.03,.92],
 "integra":[1.20,1.18,.96],"gti":[.88,.94,.83],"s2000":[1.26,1.20,1.03],"gr86":[.96,1.06,.97],"z350":[1.02,1.02,1.10],
 "supra":[.86,1.06,.98],"m3":[1.20,1.13,1.05],"sti":[.82,1.04,1.12],"evo":[1.01,1.14,1.08],"type_r":[1.15,1.14,.98],
 "mustang":[1.10,1.06,1.08],"supra_gr":[.88,.94,.86],"camaro":[.82,.90,1.12],"golf_r":[.94,.99,.87],"z400":[.91,1.10,.95],
 "z06":[1.28,1.20,1.08],"gtr":[.95,1.15,1.05],"r8":[1.22,1.15,.96],"gt500":[1.02,1.06,1.10],"redeye":[.80,.92,1.16],
 "turbo_s":[.89,.98,.91],"mclaren":[1.18,1.17,.98],"sf90":[1.13,1.06,.90],"demon":[.88,1.12,1.22],"chiron":[.76,.92,1.02]}
static func resolve(car: Drivetrain) -> Dictionary:
	var id:=str(car._base_spec.get("id",""))
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

