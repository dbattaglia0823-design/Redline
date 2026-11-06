class_name TuneOptimizer
extends RefCounted

# Bounded coordinate search with an unchanged baseline, using the production solver.
var model := ""
var stages: Array = []
var build: Dictionary = {}
var source := ""
var distance := 402.336
var best_tune: Dictionary = {}
var baseline: Dictionary = {}
var best: Dictionary = {}
var attempts: Array = []
var parameters: Array = []
var candidates: Array = []
var parameter := -1
var bench: VehicleBench
var pending_tune: Dictionary = {}
var done := false
var cancelled := false

static func signature(profile: DriverProfile) -> String:
	return JSON.stringify([profile.vehicle_id,profile.stages,profile.hardware])

func begin(profile: DriverProfile,length: float) -> void:
	model=profile.vehicle_id; stages=profile.stages.duplicate(); build=profile.hardware.duplicate(true)
	source=signature(profile); distance=length; best_tune=build.tune.duplicate(true)
	baseline.clear(); best.clear(); attempts.clear(); parameters.clear(); candidates.clear(); parameter=-1; done=false; cancelled=false
	var fitted: Array=build.parts.values()
	if build.parts.has("ecu"): parameters.append(["launch_rpm",[2600,3400,4200,5000,5800]])
	parameters.append(["final_drive",VehicleParts.FINAL_DRIVES.duplicate()])
	parameters.append(["ratios",[.97,1.03]])
	parameters.append(["shift_rpms",[-250,250]])
	if fitted.has("boost_control"):
		var limit:=VehicleParts.boost_control_limit(build,float(GameCatalog.installed_spec(model,build).get("base_boost",0)),int(stages[1]))
		if limit>0: parameters.append(["boost",[limit*.65,limit*.85,limit]])
	start_trial(best_tune)

func start_trial(tune: Dictionary) -> void:
	pending_tune=tune.duplicate(true)
	var candidate:=build.duplicate(true); candidate.tune=pending_tune.duplicate(true)
	bench=VehicleBench.new(); bench.begin(GameCatalog.spec(model),stages,candidate)

func score(result: Dictionary) -> float:
	var value: Variant=result.get("eighth_et_s" if distance<300 else "quarter_et_s")
	return float(value) if value!=null and is_finite(float(value)) and int(result.get("safety_clamps",1))==0 else INF

func next_parameter() -> void:
	parameter+=1
	if parameter>=parameters.size(): done=true; return
	var key: String=parameters[parameter][0]
	candidates.clear()
	for value in parameters[parameter][1]:
		var draft:=best_tune.duplicate(true)
		var requested: Variant=value
		if key=="ratios":
			requested=best.get("gears",TransmissionCatalog.spec(str(build.transmission)).ratios).duplicate()
			for i in requested.size(): requested[i]=float(requested[i])*float(value)
		elif key=="shift_rpms":
			requested=best.get("shift_map",[]).duplicate()
			for i in requested.size(): requested[i]=float(requested[i])+float(value)
		var copy:=DriverProfile.new(); copy.vehicle_id=model; copy.stages=stages.duplicate(); copy.hardware=build.duplicate(true); copy.hardware.tune=draft
		if copy.tune_hardware(key,requested,false): candidates.append(copy.hardware.tune.duplicate(true))
	if candidates.is_empty(): next_parameter()

func advance(budget: int = 600) -> void:
	if done or cancelled: return
	bench.step_budget(budget)
	if not bench.done: return
	var measured: Dictionary=bench.result.duplicate(true)
	attempts.append({"tune":pending_tune.duplicate(true),"et":score(measured),"spin":measured.get("wheelspin_s",0)})
	if baseline.is_empty(): baseline=measured.duplicate(true); best=measured.duplicate(true)
	elif score(measured)+.001<score(best): best=measured.duplicate(true); best_tune=pending_tune.duplicate(true)
	if candidates.is_empty(): next_parameter()
	if not done: start_trial(candidates.pop_front())

func apply(profile: DriverProfile) -> bool:
	if not done or cancelled or not profile.pending_wager.is_empty() or signature(profile)!=source or not is_finite(score(best)): return false
	profile.hardware.tune=best_tune.duplicate(true); profile.save(); return true
