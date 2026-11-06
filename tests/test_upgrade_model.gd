extends SceneTree
var failures:=0
var checks:=0
var audit: Array=[]
func parameters(c: Drivetrain) -> Dictionary:
	return {"hp":c.peak_horsepower(),"peak_nm":GarageHub.peak_torque(c),"mass_kg":c.mass(),"shift_ms":c.shift_duration*1000,"input_nm":c.input_capacity(),"clutch_nm":c.clutch_capacity(),"fuel_nm":c.fuel_torque_capacity(),"engine_nm":c.mechanical_torque_capacity(),"redline_rpm":c.redline_rpm,"mechanical_rpm":c._mechanical_redline,"inertia":c.engine_inertia,"boost_bar":c.boost_target(c.redline_rpm,1),"boost_onset_rpm":UpgradeStudio.boost_onset(c),"spool_s":UpgradeStudio.spool(c),"grip":GarageHub.grip(c),"radius_m":c.tire_radius,"wheel_inertia":c.wheel_inertia,"launch_transfer":c.load_transfer_scale,"rolling_resistance":c.rolling_coefficient,"hop_damping":c.hop_damping,"nitrous_s":c.nitrous_capacity(),"controls":c.control_mode,"launch_control":c.launch_control,"stall_rpm":c.converter_stall,"converter_multiplier":c.converter_multiplication}
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func car(trans: String="legacy6",parts: Array=[],levels: Array=[0,0,0,0,5,0,0,0],tune: Dictionary={}) -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec("kaze")); c.configure(levels); c.configure_build(VehicleBench.fixture(trans,parts,tune),"kaze",false); return c
func _initialize() -> void:
	var stock:=car()
	for stage in 4:
		var hybrid:=car("legacy6",["turbo_hybrid"],[0,stage,0,0,5,0,0,0])
		check(absf(hybrid.boost_target(hybrid.redline_rpm,1)-(.45+.32))<.00001,"Assembly stacks package boost")
		check(hybrid.turbo_onset()==2600 and hybrid._spool_override==.36,"Installed turbo does not own its spool curve")
	var large:=car("legacy6",["fuel_street","turbo_race"])
	var small:=car("legacy6",["turbo_hybrid"])
	check(large.boost_target(large.redline_rpm,1)>small.boost_target(small.redline_rpm,1) and large.turbo_onset()>small.turbo_onset() and large._spool_override>small._spool_override,"Turbo peak/lag tradeoff missing")
	var twin:=car("manual5",["clutch_twin"]); var race:=car("manual5",["clutch_race"])
	check(race.clutch_capacity()>twin.clutch_capacity() and race.clutch_capacity()<=race.input_capacity(),"Race and twin clutch packs share a saturated capacity")
	var fuel:=car("legacy6",["fuel_street"])
	check(fuel.fuel_torque_capacity()>stock.fuel_torque_capacity() and fuel.peak_horsepower()==stock.peak_horsepower(),"Fuel support is being sold as unconditional horsepower")
	var ecu:=car("legacy6",["ecu"])
	check(ecu.launch_control and ecu.peak_horsepower()==stock.peak_horsepower(),"Programmable ECU changed factory power calibration")
	var forged:=car("legacy6",["forged"])
	check(forged._mechanical_redline>stock._mechanical_redline and forged.redline_rpm==stock.redline_rpm and forged.engine_inertia<stock.engine_inertia,"Forged headroom and programmable limiter are conflated")
	var tuned:=car("legacy6",["forged","ecu"],[0,0,0,0,5,0,0,0],{"redline":9000})
	check(tuned.redline_rpm==tuned._mechanical_redline,"ECU exceeds actual mechanical RPM headroom")
	var limited:=car(); limited.base_torque=1000; limited._fuel_factor=.12
	check(limited.power_torque(6500,1.5)<=limited.fuel_torque_capacity()+.001,"Legacy builds bypass fuel support")
	var boosted:=car("legacy6",[],[0,3,0,0,5,0,0,0])
	check(boosted.mechanical_torque_capacity()==stock.mechanical_torque_capacity(),"Boost tuning silently strengthens engine internals")
	var na:=Drivetrain.new(); na.configure_vehicle(GameCatalog.spec("mika")); na.configure([0,0,0,0,0,0,0,0]); na.configure_build(VehicleBench.fixture("manual5",["boost_control"],{"boost":1.5}),"mika",false)
	check(na.boost_target(6500,1)==0,"Boost controller creates a turbo on a naturally aspirated engine")
	check(VehicleParts.boost_control_reason(VehicleBench.fixture("legacy6",["roots","boost_control"]),.45,0)!="","Turbo controller falsely supports a belt-driven supercharger")
	var control_profile:=DriverProfile.new(); control_profile.credits=100000; control_profile.buy_vehicle("civic_si")
	var balance: int=control_profile.credits; control_profile.install_hardware("boost_control")
	check(control_profile.credits==balance and not control_profile.hardware.parts.has("boost"),"Incompatible controller was sold")
	control_profile.select_vehicle("miata"); control_profile.install_hardware("ecu"); control_profile.install_hardware("forged"); control_profile.tune_hardware("redline",9000)
	check(control_profile.hardware.tune.redline==7450,"Stored ECU limit exceeds the actual mechanical limit")
	var standard_ecu:=car("legacy6",["forged","ecu"], [0,0,0,0,5,0,0,0],{"redline":7600})
	check(absf(standard_ecu.torque_at(6000)-tuned.torque_at(6000))<.0001,"A limiter-only change stretches the engine torque curve")
	var super_a:=car("legacy6",["forged","ecu","centrifugal"],[0,0,0,0,5,0,0,0],{"redline":7600})
	var super_b:=car("legacy6",["forged","ecu","centrifugal"],[0,0,0,0,5,0,0,0],{"redline":7850})
	check(absf(super_a.boost_target(6000,1)-super_b.boost_target(6000,1))<.0001,"ECU limiter changes centrifugal pulley behavior")
	var front:=Drivetrain.new(); front.configure_vehicle(GameCatalog.spec("nori")); front.configure([0,0,0,0,5,0,0,0]); front.configure_build(VehicleBench.fixture("legacy6",["drag_susp"]),"nori",false)
	check(front.load_transfer_scale==float(VehicleParts.PARTS.drag_susp.fwd_transfer),"Front-drive drag suspension still unloads the front axle excessively")
	for id in VehicleParts.PARTS:
		var parts: Array=[id]; var trans: String="legacy6"; var slot: String=VehicleParts.PARTS[id].slot
		if id=="stroker": parts.append("forged")
		if id=="compression": parts.append("fuel_ethanol")
		if id=="turbo_race": parts.append("fuel_street")
		if slot in ["converter","transbrake"]: trans="drag3"
		if id=="h_gate": trans="manual5"
		if id=="selector": trans="seq5"
		if id=="race_controller": trans="auto10"
		var c:=car(trans,parts)
		var supporting:=parts.duplicate(); supporting.erase(id)
		audit.append({"id":id,"kind":"component","slot":slot,"cost":VehicleParts.PARTS[id].cost,"requires":VehicleParts.PARTS[id].get("requires",""),"before":parameters(car(trans,supporting)),"after":parameters(c)})
		if slot in ["controls","clutch","converter","differential","final_drive","wheels","tires","suspension","transbrake","gearset","nitrous"]:
			check(c.peak_horsepower()==car(trans,supporting).peak_horsepower(),"Non-engine part fabricates crank horsepower: "+id)
		check(c.hardware.parts.get(slot,"")==id,"Existing part is unreachable: "+id)
		check(c.mass()>0 and c.tire_radius>0 and c.clutch_capacity()>0 and c.supported_engine_torque()>0,"Invalid configured part: "+id)
		for point in GarageHub.curve(c): check(is_finite(point.y) and absf(point.y-point.x*point.z/7127)<.001,"Invalid dyno for "+id)
	for category in 8:
		for stage in range(1,GameCatalog.max_stage(category)+1):
			var before: Array=GameCatalog.blank_stages(); before[category]=stage-1
			var after:=before.duplicate(); after[category]=stage
			audit.append({"id":"package_%d_%d"%[category,stage],"kind":"package","name":GameCatalog.stage_name(category,stage),"cost_increment":GameCatalog.PART_COSTS[category]*stage,"before":parameters(car("legacy6",[],before)),"after":parameters(car("legacy6",[],after))})
	var b:=VehicleBench.fixture("legacy6",["forged","stroker"])
	b.parts.erase("internals")
	check(VehicleParts.compatible("stroker",b,5)!="","Dependency removal is not blocked")
	var p:=DriverProfile.new(); p.credits=100000; p.xp=2400
	check(p.upgrade(0,2),"Existing engine package cannot be bought")
	var stage_price: int=p.credits
	check(not p.upgrade(0,2) and p.credits==stage_price,"Package double charge")
	p.install_hardware("forged"); var purchased: int=p.credits; p.remove_hardware("internals"); p.install_hardware("forged")
	check(p.credits==purchased,"Owned internals charged twice")
	var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.stages[0]==2 and restored.hardware.parts.get("internals","")=="forged" and restored.credits==p.credits and restored.xp==2400,"Save migration lost legitimate packages/parts")
	var file:=FileAccess.open("res://validation/upgrade_model_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"passed":failures==0},"  ")); file.close()
	file=FileAccess.open("res://validation/upgrade_parameter_audit.json",FileAccess.WRITE); file.store_string(JSON.stringify(audit,"  ")); file.close()
	print("UPGRADE MODEL: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	quit(0 if failures==0 else 1)
