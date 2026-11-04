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
	check(Championships.catalog().size()==35,"Incomplete championship catalog")
	var report: Array=[]
	for letter in Championships.CLASSES:
		var ids:=Championships.ids(letter); check(ids.size()==5,"Missing class rounds")
		var first:=0.0; var final:=0.0
		for id in ids:
			var c:=Championships.event(id)
			var bench:=VehicleBench.run(GameCatalog.spec(c.model),c.stages,c.hardware)
			check(bench.quarter_s!=null and PerformanceClasses.classify(float(bench.quarter_s))==letter,"Rival build outside class: "+id)
			check(bench.safety_clamps==0,"Rival numerical instability: "+id)
			var actual:=RaceAI.estimate(c,float(c.distance)); var quarter:=RaceAI.estimate(c,402.336)
			check(actual.clamps==0 and actual.time<90 and actual.mph>0,"AI failed to finish: "+id)
			if c.round==0: first=float(quarter.time)
			if c.round==4: final=float(quarter.time)
			report.append({"id":id,"model":c.model,"class":letter,"distance":c.distance,"potential_s":bench.quarter_s,"race_s":actual.time,"quarter_ai_s":quarter.time,"trap_mph":actual.mph})
		check(final<first,"Final rival not harder under equal quarter-mile conditions: "+letter)
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
	check(not p.begin_wager(0,Championships.event("class_E_4")),"Skipped directly to locked final")
	for round in range(1,5):
		var c:=Championships.event("class_E_%d"%round)
		check(p.begin_wager(0,c),"Sequential heat locked unexpectedly")
		p.award_race(c,true,false,15,.2,85,0,0)
	check(p.championship_wins.E==5 and Championships.unlock_reason(p,"D")=="","Class completion failed to unlock next class")
	var last:=Championships.event("class_E_4")
	check(p.begin_wager(0,last),"Completed event cannot be replayed")
	result=p.award_race(last,true,false,15,.2,85,0,0)
	check(result.bonus==0,"Completion bonus farmed on replay")
	var claims:=p.career_claims.duplicate()
	p.save(); var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.championship_wins.E==5 and restored.career_claims==claims and restored.credits==p.credits,"Championship save lost rewards or progress")
	check(restored.career_wins==[5,2,1],"Legacy series progress overwritten")
	var balance:=0
	for letter in Championships.CLASSES:
		var class_pay:=0
		for id in Championships.ids(letter): class_pay+=int(Championships.event(id).purse)
		balance+=class_pay+Championships.BONUSES[Championships.CLASSES.find(letter)]
		check(class_pay>=Championships.PAY[Championships.CLASSES.find(letter)]*5,"Invalid championship economy")
	p=DriverProfile.new(); p.stages=[3,2,3,2,3,2,0,1]
	var measured:=measure(p)
	check(not measured.is_empty() and measured.get("class","E")!="E","Upgraded starter did not change class")
	var original:=measured.duplicate(true)
	var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(p.vehicle_id)); car.reset(); car.running=true
	for i in 240: car.step(1.0/240,0,1)
	check(PerformanceClasses.request(p.vehicle_id,p.stages,p.hardware)==original,"Bad player driving changed competitive class")
	check(Championships.eligibility(p,first_event)!="","Over-class build admitted to E")
	check(Championships.eligibility(p,Championships.event("open_0"))=="","Upgraded car blocked from open recovery race")
	p.vehicle_id="civic_si"; p.hardware=GameCatalog.factory_build("civic_si")
	check(Championships.eligibility(p,Championships.event("open_4"))!="","Vehicle-specific challenge ignored car rule")
	var f:=FileAccess.open("res://validation/championship_balance.json",FileAccess.WRITE); f.store_string(JSON.stringify(report,"  ")); f.close()
	f=FileAccess.open("res://validation/championship_summary.json",FileAccess.WRITE); f.store_string(JSON.stringify({"checks":checks,"passed":failures==0,"championships":6,"rivals":30,"open_events":5,"first_clear_rewards":balance},"  ")); f.close()
	print("CLASS CAREER / 30 RIVALS / REAL AI / REWARDS / MIGRATION / ELIGIBILITY: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
