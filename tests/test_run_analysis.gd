extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func simulated(id: String,trans: String,final_drive: float,launch: float,grip: float=1,length: float=402.336,ratios: Array=[]) -> Dictionary:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id)); c.configure_build(VehicleBench.fixture(trans,["ecu"],{"final_drive":final_drive,"launch_rpm":launch,"ratios":ratios} if not ratios.is_empty() else {"final_drive":final_drive,"launch_rpm":launch}),id)
	c.reset(); c.running=true; c.gear=1; c.rpm=launch; c.grip_coefficient*=grip
	var rival:=Drivetrain.new(); var stage:=RaceStaging.new(); stage.reset(c,rival)
	var recorder:=RunTelemetry.new(); recorder.begin(c,length)
	for tick in 18000:
		if c.upshift_ready(): c.shift(1)
		var d:=c.distance; var v:=c.speed; var t:=c.elapsed; var rpm:=c.rpm
		c.step(1.0/240,1)
		stage.observe(0,d,c.distance,t,1.0/240)
		recorder.observe(c,d,v,t,1.0/240,stage,0,rpm)
		if recorder.frozen: break
	check(recorder.frozen,id+" test pass failed to finish")
	var run:=recorder.snapshot()
	check(run.metrics.sixty_ft_s!=null and run.metrics.eighth_s!=null and (run.metrics.quarter_s!=null if length>300 else run.metrics.quarter_s==null),id+" missing splits")
	check(absf(float(run.metrics.total_s)-float(run.metrics.reaction_s)-float(run.metrics[RunArchive.metric(run)]))<.00001,id+" RT / ET mismatch")
	check(run.metrics.launch_rpm>0 and run.metrics.sixty_ft_mph>0 and not run.shifts.is_empty(),id+" measured launch / shift / trap absent")
	check(run.setup.final_drive==final_drive and run.setup.transmission==trans,id+" setup snapshot wrong")
	return run
func _initialize() -> void:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec("miata")); c.reset(); c.running=true
	var stage:=RaceStaging.new(); stage.released.assign([true,true]); stage.reactions.assign([.2,.2])
	var recorder:=RunTelemetry.new(); recorder.begin(c)
	c.distance=18.5; c.speed=20; c.elapsed=1.1
	recorder.observe(c,18,10,1,.1,stage,0,3000)
	check(absf(recorder.result.sixty_ft_s-.8576)<.000001,"60-foot interpolation wrong")
	check(absf(recorder.result.sixty_ft_mph-15.76*Drivetrain.MPH_PER_MPS)<.000001,"60-foot trap interpolation wrong")
	recorder.begin(c,201.168); c.distance=210; c.speed=33; c.elapsed=6; c.throttle=1; c.wheelspin=.5; c.clutch_slip_rpm=1000; c.clutch_engagement=1; c.has_converter=false; c.shift_left=0; c.limiter=true; c.acceleration=8; c.rpm=2000; c.gear=2
	recorder.observe(c,180,30,5,1,stage,0,3000)
	check(recorder.result.quarter_s==null and recorder.result.trap_mph==null,"Eighth pass fabricated quarter data")
	check(absf(recorder.result.traction_s-.7056)<.000001 and absf(recorder.result.clutch_slip_s-.7056)<.000001,"Exposure includes post-finish time")
	check(absf(recorder.samples[-1].time-5.7056)<.000001 and recorder.samples[-1].distance==201.168,"Trace extends beyond finish")
	var frozen:=JSON.stringify(recorder.snapshot()); recorder.observe(c,0,0,0,10,stage)
	check(JSON.stringify(recorder.snapshot())==frozen,"Frozen telemetry changed")
	recorder.begin(c,201.168); c.distance=210; c.speed=26.9; c.elapsed=6
	recorder.observe(c,180,25,5,1,stage,0,3000)
	check(recorder.result.zero_60_s==null,"Post-finish 0–60 crossing was recorded")
	var archive: Dictionary=RunArchive.normalize({})
	var first:=simulated("miata","manual5",3.55,3000)
	var second:=simulated("miata","manual5",4.10,5000,.55)
	check(second.metrics.traction_s>first.metrics.traction_s,"Traction change absent from diagnostics")
	var a:=RunArchive.add(archive,"miata",first); var b:=RunArchive.add(archive,"miata",second)
	check(absf(float(RunArchive.delta(a,b,"quarter_s"))-(float(first.metrics.quarter_s)-float(second.metrics.quarter_s)))<.000001,"Comparison delta wrong")
	check(a.samples.size()<=RunArchive.SAMPLE_LIMIT and b.samples.size()<=RunArchive.SAMPLE_LIMIT,"Unbounded retained samples")
	var eighth:=simulated("miata","manual5",3.85,4200,1,201.168,[2.6,1.89,1.28,1,.81])
	RunArchive.add(archive,"miata",eighth)
	check(eighth.setup.ratios[0]==2.6 and eighth.metrics.quarter_s==null,"Tuned gearing / eighth run mismatch")
	var best_id: int=RunArchive.history(archive,"miata",402.336).best.id
	var foul:=first.duplicate(true); foul.metrics.red_light=true; foul.metrics.quarter_s=.1
	RunArchive.add(archive,"miata",foul)
	check(RunArchive.history(archive,"miata",402.336).best.id==best_id,"Red light replaced personal best")
	for combo in [["civic_si","manual5"],["gtr","dct6"],["demon","drag3"]]:
		var run:=simulated(combo[0],combo[1],3.67,4000)
		RunArchive.add(archive,combo[0],run)
	for i in 30:
		var run:=second.duplicate(true); run.metrics.quarter_s+=i+1; RunArchive.add(archive,"miata",run)
	check(RunArchive.history(archive,"miata",402.336).runs.size()==RunArchive.PER_VEHICLE,"Recent history bound wrong")
	check(RunArchive.history(archive,"miata",402.336).best.id==best_id,"Trace eviction lost PB summary")
	var bad: Dictionary=first.duplicate(true); bad.samples=[{"time":NAN}]
	check(RunArchive.clean_run(bad).samples.is_empty(),"Nonfinite trace accepted")
	for vehicle in GameCatalog.CAR_IDS:
		for length in [201.168,402.336]:
			for recent in RunArchive.PER_VEHICLE:
				RunArchive.add(archive,vehicle,eighth if length<300 else first)
	for vehicle in GameCatalog.CAR_IDS:
		check(RunArchive.history(archive,vehicle,402.336).runs.size()==RunArchive.PER_VEHICLE,"Another vehicle evicted recent runs")
	var retained:=0
	for entry in archive.vehicles.values(): retained+=entry.runs.size()
	check(retained<=RunArchive.GLOBAL_RUNS,"Global trace storage cap exceeded")
	var normalized:=RunArchive.normalize(archive)
	var p:=DriverProfile.new(); p.test_runs=normalized; p.save()
	var loaded:=DriverProfile.new(); loaded.load_profile()
	check(not loaded.save_blocked and loaded.test_runs.vehicles.size()==normalized.vehicles.size(),"Archive save/load failed")
	check(RunArchive.history(loaded.test_runs,"miata",402.336).best.get("id",-1)==best_id,"PB did not survive reload")
	check(absf(float(RunArchive.history(loaded.test_runs,"gtr",201.168).runs[0].metrics.distance)-201.168)<.00001 and not RunArchive.history(loaded.test_runs,"miata",201.168).best.is_empty(),"Mixed vehicle/distance comparisons")
	var file:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.READ)
	check(file.get_length()<2*1024*1024,"Telemetry exceeded profile storage budget")
	print("RUN ANALYSIS / PHYSICS SPLITS / DIAGNOSTICS / FOUR CLASSES / DELTAS / ARCHIVE / PB / SAVE: ",checks," checks; ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
