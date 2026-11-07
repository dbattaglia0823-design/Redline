extends SceneTree

const POWER_PARTS := ["billet","stroker","compression","intake_race","fuel_ethanol","ecu_race","turbo_race","boost_control","charge_pressure","charge_airflow","charge_cooling","headers","pro_drag_slicks","active_drag_susp"]
const GEAR_PARTS := ["gear_strength","gear_pro","gear_cooling","gear_efficiency","gear_response","clutch_carbon"]
var failures := 0
var checks := 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)

func peak_input(c: Drivetrain) -> float:
	var torque := 0.0
	for rpm in range(1000,roundi(c.redline_rpm)+1,25):
		torque=maxf(torque,minf(c.supported_engine_torque(),c.full_engine_torque(rpm)*(1.0+c.nitrous_torque_gain())))
	return torque

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var report := []
	for transmission in ["oem_mustang","manual_type","sequential_type","automatic_type","drag_type"]:
		for with_parts in [false,true]:
			var parts := POWER_PARTS+(GEAR_PARTS if with_parts else [])
			var build := VehicleBench.fixture(transmission,parts,{"boost":1.5,"tire_pressure":21.0})
			var bench := VehicleBench.new()
			bench.begin(GameCatalog.spec("mustang"),[3,3,0,3,5,3,3,3],build)
			var c := bench.car
			var torque := peak_input(c)
			check(c.peak_horsepower()>2000,"Fixture does not exercise a max-power Mustang")
			check(c.input_capacity()>torque*1.1,"Pro Race gearbox lacks torque reserve: "+transmission)
			check(c.clutch_capacity()>torque*1.1,"Pro Race coupling lacks torque reserve: "+transmission)
			while not bench.done: bench.step_budget(960)
			check(bench.result.quarter_s!=null and bench.result.safety_clamps==0,"Invalid quarter-mile: "+transmission)
			check(bench.result.gearbox_slip_s<.05 and bench.result.clutch_slip_s<.05,"Sustained slipping with max gearbox: "+transmission)
			check(c.component_wear<.00001,"Overload wear with max gearbox: "+transmission)
			report.append({"transmission":transmission,"support_parts":with_parts,"hp":c.peak_horsepower(),"engine_lbft":ImperialUnits.torque(torque),"gearbox_lbft":ImperialUnits.torque(c.input_capacity()),"clutch_lbft":ImperialUnits.torque(c.clutch_capacity()),"quarter_et_s":bench.result.quarter_et_s,"gearbox_slip_s":bench.result.gearbox_slip_s,"clutch_slip_s":bench.result.clutch_slip_s})
	var weak := VehicleBench.new()
	weak.begin(GameCatalog.spec("mustang"),[3,3,0,3,0,3,3,3],VehicleBench.fixture("oem_mustang",POWER_PARTS,{"boost":1.5}))
	while not weak.done: weak.step_budget(960)
	check(weak.result.gearbox_slip_s>1 and weak.car.component_wear>0,"Underbuilt gearbox no longer overloads")
	for stage in range(1,6): check(TransmissionCatalog.strength(stage)>TransmissionCatalog.strength(stage-1),"Non-progressive gearbox upgrade")
	# Already purchased tiers pick up the stronger ratings on reload, without a new purchase.
	var p := DriverProfile.new()
	p.vehicle_id="mustang"; p.hardware=GameCatalog.factory_build("mustang")
	p.stages=[3,3,0,3,5,3,3,3]; p.owned_stages=p.stages.duplicate(); p.credits=12345
	p.save()
	var restored := DriverProfile.new(); restored.load_profile()
	var c := Drivetrain.new(); c.configure_vehicle(GameCatalog.spec("mustang")); c.configure(restored.stages); c.configure_build(restored.hardware,"mustang")
	check(restored.credits==12345 and restored.stages[4]==5 and c.input_capacity()>5000,"Existing max-tier ownership did not retain improved rating")
	DirAccess.make_dir_recursive_absolute("res://.qa/gearbox")
	var file := FileAccess.open("res://.qa/gearbox/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MAX-POWER MUSTANG / FIVE GEARBOXES / NITROUS / EXISTING SAVES: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(1 if failures>0 else 0)
