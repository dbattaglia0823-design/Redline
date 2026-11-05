class_name TuningSetup
extends RefCounted

# Settings describe actuators/contact-patch approximations, never a power rating.
const EXTRA := {
	"launch_enabled":["Launch control",0,1,1,1,"on/off"],
	"throttle_gamma":["Pedal curve",0.65,1.6,0.1,1.0,"exponent"],
	"tc_slip":["Traction slip target",0,0.25,0.025,0.0,"0 = off"],
	"boost_rise":["Boost rise limit",0,4.0,0.25,0,"bar/s / 0 = mechanical"],
	"nitrous_auto":["Automatic spray",0,1,1,0,"on/off"],
	"nitrous_min_rpm":["Spray minimum RPM",2500,7000,250,3000,"rpm"],
	"nitrous_min_gear":["Spray minimum gear",1,10,1,1,"gear"],
	"nitrous_throttle":["Spray pedal threshold",0.85,1.0,0.025,0.85,"opening"],
	"clutch_rate":["Clutch engagement rate",0.5,1.5,0.1,1.0,"relative"],
	"converter_lock":["Converter lock speed ratio",0.75,0.95,0.025,0.85,"turbine/pump"],
	"launch_gear":["Launch gear",1,2,1,1,"gear"],
	"tire_pressure":["Tire pressure",18,40,1,32,"psi"],
	"diff_lock":["Differential preload",0.25,1.0,0.1,1.0,"fraction"],
	"launch_damping":["Launch damping",.65,1.35,.05,1.0,"relative"]
}
const GROUPS := {
	"Launch":["launch_rpm","launch_enabled","tc_slip","throttle_gamma"],
	"Power":["boost","boost_gear","boost_rise","redline"],
	"Nitrous":["nitrous_auto","nitrous_min_rpm","nitrous_min_gear","nitrous_throttle","nitrous_ramp"],
	"Gearbox":["ratio","shift","final_drive","firmness","launch_gear"],
	"Coupling":["stall","clutch_rate","converter_lock"],
	"Grip":["tire_pressure","launch_damping","diff_lock"]
}
static func reason(key: String,b: Dictionary,stage: int,vehicle: String) -> String:
	var fitted: Array=b.parts.values()
	var kind: String=TransmissionCatalog.spec(str(b.transmission)).kind
	if key in ["launch_enabled","throttle_gamma","tc_slip"]:
		return "Programmable ECU required" if not fitted.has("ecu") else ""
	if key in ["boost_rise","boost_gear","boost_by_gear"]:
		if not fitted.has("boost_control"): return "Electronic boost controller required"
		return VehicleParts.boost_control_reason(b,float(GameCatalog.spec(vehicle).get("base_boost",0)),0 if not b.has("turbo_stage") else int(b.turbo_stage))
	if key.begins_with("nitrous_") and key!="nitrous_ramp": return "Progressive nitrous controller required" if not fitted.has("progressive") else ""
	if key=="clutch_rate": return "Adjustable clutch pack required" if not b.parts.has("clutch") or kind in ["drag","automatic"] else ""
	if key=="converter_lock": return "Adjustable conventional automatic converter required" if not b.parts.has("converter") or kind!="automatic" else ""
	if key=="launch_gear":
		if kind not in ["automatic","drag"] or not fitted.has("race_controller"): return "Automatic race controller required"
		if fitted.has("transbrake"): return "Transbrake launches require first gear"
	if key=="tire_pressure": return "Upgrade tires to tune pressure" if not b.parts.has("tires") and not fitted.has("drag_wheels") else ""
	if key=="launch_damping":
		var suspension: Dictionary=VehicleParts.PARTS.get(b.parts.get("suspension",""),{})
		return "" if suspension.get("adjustable",false) else "Adjustable suspension required"
	if key=="diff_lock": return "Adjustable limited-slip differential required" if not fitted.has("lsd") else ""
	return ""

static func clean(key: String,value: Variant,b: Dictionary,stage: int,vehicle: String,turbo_stage: int = 0) -> Variant:
	var context:=b.duplicate(true); context.turbo_stage=turbo_stage
	if reason(key,context,stage,vehicle)!="": return null
	if key=="boost_by_gear":
		if not value is Array or value.size()!=TransmissionCatalog.spec(str(b.transmission)).ratios.size(): return null
		var out: Array=[]
		var limit:=VehicleParts.boost_control_limit(b,float(GameCatalog.spec(vehicle).get("base_boost",0)),turbo_stage)
		for number in value:
			if not (number is int or number is float) or not is_finite(float(number)): return null
			out.append(clampf(float(number),0,limit))
		return out
	if not EXTRA.has(key) or not (value is int or value is float) or not is_finite(float(value)): return null
	var row: Array=EXTRA[key]
	var upper: float=float(row[2])
	if key in ["launch_gear","nitrous_min_gear"]: upper=minf(upper,TransmissionCatalog.spec(str(b.transmission)).ratios.size())
	return clampf(float(value),float(row[1]),upper)
