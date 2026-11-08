class_name TuningSetup
extends RefCounted

# Settings describe actuators/contact-patch approximations, never a power rating.
const EXTRA := {
	"launch_enabled":["Launch control",0,1,1,1,"on/off"],
	"throttle_gamma":["Pedal curve",0.65,1.6,0.1,1.0,"exponent"],
	"tc_slip":["Traction slip target",0,0.25,0.025,0.0,"0 = off"],
	"boost_rise":["Boost rise limit",0,4.0,0.25,0,"PSI/s / 0 = mechanical"],
	"clutch_rate":["Clutch engagement rate",0.5,1.5,0.1,1.0,"relative"],
	"launch_gear":["Launch gear",1,2,1,1,"gear"],
	"tire_pressure":["Tire pressure",18,40,1,32,"PSI"],
	"diff_lock":["Differential preload",0.25,1.0,0.1,1.0,"fraction"],
	"launch_damping":["Launch damping",.65,1.35,.05,1.0,"relative"]
}
const GROUPS := {
	"Launch":["launch_rpm","launch_enabled","tc_slip","throttle_gamma"],
	"Power":["boost","boost_gear","boost_rise","redline"],
	"Gearbox":["gear_count","ratio","final_drive","shift","firmness","launch_gear"],
	"Clutch":["clutch_rate"],
	"Grip":["tire_pressure","launch_damping","diff_lock"]
}
static func reason(key: String,b: Dictionary,stage: int,vehicle: String) -> String:
	var fitted: Array=b.parts.values()
	var kind: String=TransmissionCatalog.spec(str(b.transmission)).kind
	if key=="launch_enabled": return "ECU required" if not b.parts.has("ecu") else ""
	if key in ["throttle_gamma","tc_slip"]:
		return "Programmable ECU or higher required" if not VehicleParts.can_tune_rpm(b) else ""
	if key in ["boost_rise","boost_gear","boost_by_gear"]:
		if not fitted.has("boost_control"): return "Electronic boost controller required"
		return VehicleParts.boost_control_reason(b,float(GameCatalog.installed_spec(vehicle,b).get("base_boost",0)),0 if not b.has("turbo_stage") else int(b.turbo_stage))
	if key=="clutch_rate": return "Adjustable clutch pack required" if not b.parts.has("clutch") or kind in ["drag","automatic"] else ""
	if key=="launch_gear":
		if kind != "automatic": return "Conventional automatic required"
	# Tire pressure is adjustable on factory tires as well as upgraded sets.
	# The old upgraded-tires requirement belonged to the removed per-part tuning UI.
	if key=="tire_pressure": return ""
	if key=="launch_damping":
		var suspension: Dictionary=VehicleParts.PARTS.get(b.parts.get("suspension",""),{})
		return "" if suspension.get("adjustable",false) else "Adjustable suspension required"
	if key=="diff_lock": return "Adjustable limited-slip differential required" if not fitted.has("lsd") else ""
	return ""

static func clean(key: String,value: Variant,b: Dictionary,stage: int,vehicle: String,turbo_stage: int = 0) -> Variant:
	var context:=b.duplicate(true); context.turbo_stage=turbo_stage
	if reason(key,context,stage,vehicle)!="": return null
	if key=="boost_by_gear":
		if not value is Array or value.size()!=TransmissionCatalog.default_ratios(b.transmission,b.tune).size(): return null
		var out: Array=[]
		var limit:=VehicleParts.boost_control_limit(b,float(GameCatalog.installed_spec(vehicle,b).get("base_boost",0)),turbo_stage)
		for number in value:
			if not (number is int or number is float) or not is_finite(float(number)): return null
			out.append(clampf(float(number),0,limit))
		return out
	if not EXTRA.has(key) or not (value is int or value is float) or not is_finite(float(value)): return null
	var row: Array=EXTRA[key]
	var upper: float=float(row[2])
	if key=="launch_gear": upper=minf(upper,TransmissionCatalog.default_ratios(b.transmission,b.tune).size())
	return clampf(float(value),float(row[1]),upper)
