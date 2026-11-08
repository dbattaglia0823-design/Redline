extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var label := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var rows: Array=[]
	var failures := 0
	var fixtures: Array=[]
	for model in ["miata","civic_si","gti","mustang","gtr","gt500","demon","sf90","chiron"]:
		fixtures.append({"model":model,"level":"stock","stages":GameCatalog.blank_stages(),"build":GameCatalog.factory_build(model)})
	for model in ["civic_si","mustang","gtr"]:
		var stages: Array=[3,3,0,2,5,3,3,3]
		var build:=GameCatalog.factory_build(model)
		for part in ["billet","fuel_ethanol","ecu_race","turbo_hybrid","intake_race","pro_drag_slicks","active_drag_susp","clutch_carbon","gear_strength","gear_pro","gear_response"]:
			build.owned_parts.append(part)
			build.parts[VehicleParts.PARTS[part].slot]=part
		build.tune={"tire_pressure":VehicleParts.PARTS.pro_drag_slicks.pressure_peak,"launch_damping":1.2}
		fixtures.append({"model":model,"level":"built","stages":stages,"build":build})
	for trans in ["manual6","seq7","dct8","auto10","drag2","drag4"]:
		var build:=GameCatalog.factory_build("mustang")
		build.transmission=trans; build.owned_transmissions.append(trans)
		fixtures.append({"model":"mustang","level":trans,"stages":[1,0,0,0,3,1,0,0],"build":build})
	for fixture in fixtures:
		var bench:=VehicleBench.new()
		bench.finish_mph=130.0
		bench.begin(GameCatalog.spec(fixture.model),fixture.stages,fixture.build)
		while not bench.done: bench.step_budget(960)
		var result:=bench.result.duplicate(true)
		if result.quarter_s==null or result.safety_clamps!=0:
			failures+=1
			push_error("Unfinished or unstable audit fixture: "+fixture.model+" / "+fixture.level)
		result.merge({"model":fixture.model,"level":fixture.level,"drive":bench.car.drivetrain,"engine_class":GameCatalog.engine_class(fixture.model,fixture.build),"hp":bench.car.peak_horsepower(),"build":fixture.build,"stages":fixture.stages})
		var spin:=0.0; var peak_spin:=0.0; var recovery: Variant=null
		var samples: Array=[]
		for sample in bench.samples:
			if result.quarter_s!=null and float(sample.time)>float(result.quarter_s): break
			if float(sample.wheelspin)>.10: spin+=.05
			peak_spin=maxf(peak_spin,float(sample.wheelspin))
			if float(sample.time)<5 and float(sample.wheelspin)>.10: recovery=null
			elif recovery==null and float(sample.time)<5: recovery=float(sample.time)
			if samples.is_empty() or float(sample.time)-float(samples[-1].time)>=.24: samples.append(sample)
		result["quarter_wheelspin_s"]=spin; result["peak_wheelspin"]=peak_spin; result["launch_recovery_s"]=recovery
		result["samples"]=samples
		rows.append(result)
		print(fixture.model," / ",fixture.level,": 60=",result.zero_60_s," 60-130=",result.sixty_130_s," quarter=",result.quarter_s," @ ",result.trap_mph," spin=",spin)
	DirAccess.make_dir_recursive_absolute("res://validation/physics_audit")
	var file:=FileAccess.open("res://validation/physics_audit/"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixed_hz":240,"timeout_s":40,"timing":"standing start, no rollout; instantaneous speed at distance markers","rows":rows},"\t"))
	file.close()
	print("PHYSICS AUDIT ",label,": ",rows.size()," configurations")
	quit(0 if failures==0 else 1)
