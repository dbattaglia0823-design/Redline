extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func measure(p: DriverProfile) -> Dictionary:
	for i in 5000:
		var d:=PerformanceClasses.request(p.vehicle_id,p.stages,p.hardware)
		if not d.is_empty(): return d
		PerformanceClasses.advance()
	return {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(Championships.catalog().size()==65,"Incomplete championship catalog")
	var names: Dictionary={}
	var builds: Dictionary={}
	for letter in Championships.CLASSES:
		var ids:=Championships.ids(letter); check(ids.size()==Championships.ROUNDS,"Missing class rounds")
		var previous:=INF
		var boss_count:=0
		var distance_times: Dictionary={}
		for id in ids:
			var c:=Championships.event(id)
			var bench:=VehicleBench.run(GameCatalog.spec(c.model),c.stages,c.hardware)
			check(bench.quarter_s!=null and PerformanceClasses.classify(float(bench.quarter_s))==letter,"Rival build outside class: "+id)
			check(bench.safety_clamps==0,"Rival numerical instability: "+id)
			var actual:=RaceAI.estimate(c,float(c.distance)); var quarter:=RaceAI.estimate(c,402.336)
			check(actual.clamps==0 and actual.time<90 and actual.mph>0,"AI failed to finish: "+id)
			check(float(quarter.time)<previous-.035,"Quarter-mile normalized ladder regressed: "+id)
			check(float(actual.time)<float(distance_times.get(c.distance,INF)),"Same-distance ladder regressed: "+id)
			distance_times[c.distance]=actual.time
			check(not names.has(c.name),"Duplicate rival name: "+id)
			names[c.name]=true
			var build_key:=JSON.stringify([c.model,c.stages,c.hardware])
			check(not builds.has(build_key),"Duplicate rival car build: "+id)
			builds[build_key]=true
			if bool(c.get("boss",false)):
				boss_count+=1
				check(int(c.round)==Championships.ROUNDS-1 and float(quarter.time)<previous-.14,"Boss is not a distinct difficulty step: "+id)
				check(float(bench.quarter_s)+.035<float(actual.time),"Boss exceeds a tuned legal player's benchmark: "+id)
				check(not str(c.intro).is_empty() and not str(c.victory).is_empty(),"Missing boss presentation: "+id)
			previous=float(quarter.time)
		check(boss_count==1,"Expected exactly one boss in "+letter)
	var p:=DriverProfile.new(); p.career_wins=[5,2,1]; p.credits=2400
	var first_event:=Championships.event("class_E_0")
	check(Championships.eligibility(p,first_event)=="","Starter cannot enter first championship")
	check(not p.begin_wager(-1,first_event),"Negative championship wager accepted")
	check(p.begin_wager(0,first_event),"Zero-stake recovery entry failed")
	var falsified:=first_event.duplicate(true); falsified.purse=99999999
	var result:=p.award_race(falsified,true,false,16,.25,80,0,0)
	check(result.base==int(first_event.purse) and p.championship_wins.E==1,"Reward did not use bound entry contract")
	var money:=p.credits
	check(p.award_race(first_event,true,false,16,.25,80,0,0).is_empty() and p.credits==money,"Duplicate championship payout")
	check(not p.begin_wager(0,Championships.event("class_E_9")),"Skipped directly to locked final")
	for letter in Championships.CLASSES:
		if letter!="E": check(Championships.unlock_reason(p,letter)=="","Boss did not unlock the next class")
		var legal: String=GameCatalog.CAR_IDS.filter(func(id): return GameCatalog.engine_class(id)==letter)[0]
		p.vehicle_id=legal; p.hardware=GameCatalog.factory_build(legal); p.stages=GameCatalog.blank_stages()
		p.garage[p.vehicle_id]={"stages":p.stages,"hardware":p.hardware}
		for round in range(1 if letter=="E" else 0,Championships.ROUNDS):
			var c:=Championships.event("class_%s_%d"%[letter,round])
			if c.get("rule","")=="motor_only":
				check(not p.begin_wager(1,c),"Motor-only accepted a wager")
			check(p.begin_wager(0,c),"Sequential heat locked unexpectedly: "+str(c.id))
			result=p.award_race(c,true,false,15,.2,85,0,0)
			check(result.get("bonus",-1)==int(c.completion_bonus),"Incorrect first-clear bonus: "+str(c.id))
		var last:=Championships.event("class_%s_9"%letter)
		check(p.begin_wager(0,last),"Completed boss cannot be replayed")
		result=p.award_race(last,true,false,15,.2,85,0,0)
		check(result.bonus==0,"Completion bonus farmed on replay")
	check(Championships.completed(p)==60 and Championships.trophies(p)==6,"Full career did not award six trophies")
	for id in Championships.ids("OPEN"):
		var c:=Championships.event(id)
		if c.vehicle_rule!="":
			p.vehicle_id=c.vehicle_rule; p.hardware=GameCatalog.factory_build(p.vehicle_id); p.stages=GameCatalog.blank_stages()
		check(p.begin_wager(0,c),"Open recovery unavailable")
		p.award_race(c,true,false,16,.2,85,0,0)
	var claims:=p.career_claims.duplicate()
	p.save(); var restored:=DriverProfile.new(); restored.load_profile()
	check(Championships.completed(restored)==60 and restored.career_claims==claims and restored.credits==p.credits,"Championship save lost rewards or progress")
	check(restored.event_records.size()==65,"Expanded save dropped event records")
	check(restored.career_wins==[5,2,1],"Legacy series progress overwritten")
	for letter in Championships.CLASSES:
		var class_pay:=0
		for id in Championships.ids(letter): class_pay+=int(Championships.event(id).purse)
		check(class_pay>=Championships.PAY[Championships.CLASSES.find(letter)]*Championships.ROUNDS,"Invalid championship economy")
	p=DriverProfile.new(); p.stages=[3,2,3,2,3,2,0,1]
	var measured:=measure(p)
	check(measured.get("class","")=="E","Upgrades changed the starter engine class")
	var original:=measured.duplicate(true)
	var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(p.vehicle_id)); car.reset(); car.running=true
	for i in 240: car.step(1.0/240,0,1)
	check(PerformanceClasses.request(p.vehicle_id,p.stages,p.hardware)==original,"Bad player driving changed competitive class")
	check(Championships.eligibility(p,first_event)=="","Upgraded E engine blocked from E")
	p.hardware.engine_id="supra"
	p.legacy_class_access=["B"]
	check(Championships.eligibility(p,first_event)!="","Class B engine admitted to E")
	check(Championships.eligibility(p,Championships.event("class_B_0"))=="","Class B engine blocked from B")
	check(measure(p).get("class","")=="B","Engine swap reused the old benchmark class")
	car.configure(p.stages)
	car.configure_build(p.hardware,p.vehicle_id,false)
	check(car.base_torque==float(GameCatalog.spec("supra").torque) and car.base_mass==float(GameCatalog.spec("miata").mass),"Installed engine did not supply its torque independently of chassis mass")
	p.save()
	restored.load_profile()
	check(restored.hardware.get("engine_id","")=="supra","Save lost installed engine")
	p.hardware.erase("engine_id")
	car.configure_build(p.hardware,p.vehicle_id,false)
	check(car.base_torque==float(GameCatalog.spec("miata").torque),"Factory engine stats did not restore")
	check(Championships.eligibility(p,Championships.event("open_0"))=="","Upgraded car blocked from open recovery race")
	p.vehicle_id="civic_si"; p.hardware=GameCatalog.factory_build("civic_si")
	check(Championships.eligibility(p,Championships.event("open_4"))!="","Vehicle-specific challenge ignored car rule")
	print("CLASS CAREER / 60 RIVALS / REAL AI / REWARDS / ELIGIBILITY: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
