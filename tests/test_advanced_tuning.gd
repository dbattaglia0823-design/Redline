extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func configured(p: DriverProfile) -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(p.vehicle_id)); c.configure(p.stages); c.configure_build(p.hardware,p.vehicle_id); c.reset(); return c
func equipped() -> DriverProfile:
	var p:=DriverProfile.new(); p.vehicle_id="supra"; p.garage["supra"]={"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build("supra")}
	p.stages=[3,2,3,1,5,1,1,1]
	p.hardware=VehicleBench.fixture("automatic_type",["ecu","billet","fuel_ethanol","turbo_race","boost_control","drag_wheels","lsd"],{"gear_count":3})
	return p
func _initialize() -> void:
	var stock:=DriverProfile.new()
	for key in TuningSetup.EXTRA:
		if key in ["launch_gear","tire_pressure"]: continue
		check(not stock.tune_hardware(key,TuningSetup.EXTRA[key][4],false),"Stock build accepted gated tuning: "+key)
	check(stock.tune_hardware("tire_pressure",30.0,false),"Factory tire pressure incorrectly requires an upgrade")
	check(is_equal_approx(float(stock.hardware.tune.get("tire_pressure",0)),30.0),"Factory tire pressure tune did not persist in build")
	var p:=equipped()
	check(p.tune_hardware("launch_rpm",4600,false),"ECU launch target rejected")
	check(p.tune_hardware("tc_slip",.08,false),"ECU traction controller rejected")
	check(p.tune_hardware("throttle_gamma",1.4,false),"Pedal mapping rejected")
	check(p.tune_hardware("boost_by_gear",[.3,.7,1.1],false),"Gear boost caps rejected")
	check(not p.tune_hardware("boost_by_gear",[.3,NAN,1.1],false),"Invalid boost array accepted")
	check(not p.tune_hardware("launch_rpm",NAN,false),"Invalid scalar accepted")
	check(p.tune_hardware("launch_gear",2,false),"Compatible second-gear launch rejected")
	var c:=configured(p)
	check(c.gear==2 and c.launch_gear==2,"Launch gear not used by reset")
	check(c.launch_rpm==4600 and absf(c.traction_slip_target-.08)<.0001,"Engine launch/TC settings disconnected")
	check(c.boost_by_gear==[.3,.7,1.1] and c.throttle_gamma==1.4,"Boost/pedal settings disconnected")
	p.hardware.tune.erase("launch_gear")
	check(not p.tune_hardware("nitrous_auto",1,false),"Retired nitrous setting was accepted")
	c=configured(p); c.running=true; c.set_road_state(35,2,5000)
	for i in 100: c.step(1.0/240,1)
	check(not c.nitrous_active and c.nitrous_remaining==c.nitrous_capacity(),"Nitrous sprayed without driver input")
	for i in 150: c.step(1.0/240,1,0,0,true)
	check(c.nitrous_remaining<c.nitrous_capacity(),"Manual nitrous input did not deliver")
	var original_money:=p.credits
	p.save_tune_slot("quarter","Quarter baseline"); check(p.tuning_presets().has("quarter"),"Tune not stored")
	p.tune_hardware("launch_rpm",2800,false); check(p.load_tune_slot("quarter") and p.hardware.tune.launch_rpm==4600,"Tune restore failed")
	p.rename_tune_slot("quarter","Drag setup"); p.save()
	var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.tuning_presets().quarter.name=="Drag setup" and restored.hardware.tune.boost_by_gear==[.3,.7,1.1],"Preset or tuning lost on reload")
	restored.select_vehicle("miata"); check(restored.tuning_presets().is_empty(),"Tune library leaked to another vehicle")
	restored.select_vehicle("supra"); check(restored.tuning_presets().quarter.name=="Drag setup","Vehicle switching lost saved tuning")
	p.hardware.parts.erase("ecu")
	var before:=JSON.stringify(p.hardware)
	check(p.tune_slot_reason("quarter")!="" and not p.load_tune_slot("quarter") and JSON.stringify(p.hardware)==before,"Incompatible preset installed parts or partly applied")
	check(p.credits==original_money,"Preset action charged currency")
	var manual:=equipped(); manual.hardware=VehicleBench.fixture("manual5",["ecu","billet"])
	manual.tune_hardware("launch_rpm",4200,false)
	c=configured(manual); c.running=true
	for i in 720: c.step(1.0/240,1,0,1)
	check(c.speed==0 and c.rpm<4500 and c.rpm>3900,"Launch controller did not hold while clutch was depressed after green")
	manual.tune_hardware("launch_enabled",0,false); c=configured(manual); c.running=true
	for i in 720: c.step(1.0/240,1,0,1)
	check(c.rpm>6000,"Disabled launch control still limited free revving")
	p=equipped(); p.hardware.tune={"tire_pressure":26.0,"boost_rise":.5}
	c=configured(p); check(c.pressure_grip>1 and c.pressure_rolling>1,"Pressure tradeoff disconnected")
	c.running=true; c.set_road_state(25,2,5000); var last_boost:=c.boost
	for i in 200:
		c.step(1.0/240,1); check(c.boost-last_boost<=.5/240+.00001,"Boost slew exceeded controller setting"); last_boost=c.boost
	var runs: Array=[]
	for rpm in [2800,4200,5800]:
		p=equipped(); p.tune_hardware("launch_rpm",rpm,false)
		var bench:=VehicleBench.run(GameCatalog.spec(p.vehicle_id),p.stages,p.hardware)
		check(bench.quarter_et_s!=null and bench.reaction_s!=null and absf(float(bench.quarter_s)-float(bench.reaction_s)-float(bench.quarter_et_s))<.0001,"Bench RT / ET inconsistent")
		check(bench.safety_clamps==0,"Tuned launch required numerical safety clamp")
		runs.append({"rpm":rpm,"et":bench.quarter_et_s,"spin":bench.wheelspin_s})
	check(absf(float(runs[0].et)-float(runs[-1].et))>.001,"Launch tuning has no measurable effect")
	var states: Array=[]
	for rate in [30,60,120,144]:
		p=equipped(); p.hardware.tune={"tc_slip":.08,"throttle_gamma":1.3,"boost_by_gear":[.3,.7,1.1],"boost_rise":.5}
		c=configured(p); c.running=true; c.set_road_state(15,2)
		for i in rate*8: c.step(1.0/rate,.8)
		states.append({"distance":c.distance,"rpm":c.rpm})
		check(c.safety_clamps==0,"Tuned configuration produced invalid solver state")
	for state in states: check(absf(float(state.distance)-float(states[0].distance))<.000001 and absf(float(state.rpm)-float(states[0].rpm))<.0001,"Tuning depends on outer frame rate")
	p=equipped(); var snapshot:=JSON.stringify([p.hardware,p.stages,p.credits,p.races,p.xp])
	var optimizer:=TuneOptimizer.new(); optimizer.begin(p,402.336)
	for i in 1200:
		if optimizer.done: break
		optimizer.advance(9600)
	check(optimizer.done and optimizer.attempts.size()>5,"Optimization did not run candidate simulations")
	check(optimizer.score(optimizer.best)<=optimizer.score(optimizer.baseline)+.0001,"Optimizer returned a slower setup")
	check(snapshot==JSON.stringify([p.hardware,p.stages,p.credits,p.races,p.xp]),"Optimization mutated live build")
	check(optimizer.apply(p),"Completed recommendation could not apply")
	var benchmark:=VehicleBench.run(GameCatalog.spec(p.vehicle_id),p.stages,p.hardware)
	check(absf(float(benchmark.quarter_et_s)-optimizer.score(optimizer.best))<.00001,"Optimizer result not repeatable")
	var stale:=TuneOptimizer.new(); stale.begin(p,201.168); p.tune_hardware("launch_rpm",3000,false); stale.done=true
	check(not stale.apply(p),"Stale recommendation applied to another build")
	DirAccess.make_dir_recursive_absolute("res://validation/tuning")
	var report:={"passed":failures==0,"checks":checks,"launch_runs":runs,"optimizer_trials":optimizer.attempts.size(),"baseline_et":optimizer.score(optimizer.baseline),"best_et":optimizer.score(optimizer.best)}
	var file:=FileAccess.open("res://validation/tuning/model.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("HARDWARE TUNING / PRESETS / LAUNCH / NITROUS / OPTIMIZER: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
