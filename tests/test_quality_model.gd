extends SceneTree
var failures := 0
func check(ok: bool,msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void:
	var comparisons: Array = []
	for pair in [[0,0],[0,1],[1,2],[1,3],[2,3]]:
		var bot := GameCatalog.opponent(pair[0],pair[1]); var distance: float = bot.distance
		RaceAI.cache.clear(); RaceAI.pending.clear()
		check(RaceAI.request_estimate(bot,distance).is_empty(),"Uncomputed estimate fabricated a result")
		RaceAI.advance_estimates(100)
		check(RaceAI.pending.size() == 1 and RaceAI.pending[0].car.substeps == 100,"Estimate exceeded its physics work budget")
		var result: Dictionary = {}
		for i in 200:
			RaceAI.advance_estimates(360); result = RaceAI.request_estimate(bot,distance)
			if not result.is_empty(): break
		check(not result.is_empty(),"Sliced estimate failed to finish")
		RaceAI.cache.clear()
		var direct := RaceAI.estimate(bot,distance)
		check(absf(float(result.time)-float(direct.time)) < 1e-9 and absf(float(result.mph)-float(direct.mph)) < 1e-9,"Menu estimate differs from the real AI simulation")
		comparisons.append({"gearbox":bot.hardware.transmission,"distance":distance,"time":result.time,"mph":result.mph})
	var p := DriverProfile.new()
	var a := Drivetrain.new(); var b := Drivetrain.new()
	a.configure([0,0,0,0,0,0,2,0]); b.configure([0,0,0,0,0,0,3,0])
	check(UpgradeWorkshop.comparison_rows(a,b).has("Braking force +0%"),"Brake preview invented a gain above tire traction limits")
	var stock := RaceAI.estimate(RaceAI.player_contract(p))
	p.upgrade(0,1)
	var upgraded := RaceAI.estimate(RaceAI.player_contract(p))
	check(float(upgraded.time) < float(stock.time)-.15,"Affordable engine stage has no meaningful quarter-mile improvement")
	var first := GameCatalog.opponent(0,0)
	var cash_before:=p.credits
	check(p.begin_wager(0,first),"Free entry rejected")
	p.award_race(first,false,false,18,.25,80,0,0)
	check(p.credits==cash_before,"Free loss granted race income")
	var progress: Array = []
	var next_car: String=DealershipView.new(null).class_ids("E").filter(func(id): return not p.garage.has(id))[0]
	for race_index in 12:
		var bot := GameCatalog.opponent(0,mini(race_index,4))
		var stake:=mini(int(bot.max_bet),maxi(1,p.credits/3))
		var before_cash:=p.credits
		check(p.begin_wager(stake,bot),"Funded bet rejected")
		p.award_race(bot,true,false,16,.2,90,0,mini(race_index,4))
		check(p.credits==before_cash+stake,"Race profit differs from wager")
		p.career_wins[0] = mini(5,race_index+1)
		progress.append({"wins":race_index+1,"credits":p.credits,"level":p.level()})
	check(p.level() >= 3 and p.credits >= int(GameCatalog.spec(next_car).price),"Twelve early wins cannot fund the cheapest available car")
	check(p.buy_vehicle(next_car) and p.garage.has("miata"),"Earning a new car erased the starter build")
	var output := {"passed":failures==0,"sliced_matches_direct":comparisons,"stock_quarter":stock,"engine_stage1_quarter":upgraded,"early_progression":progress,"free_loss_cash":0,"note":"Assisted-driver estimates and wager-only profits with stage-scaled upgrade prices."}
	var f := FileAccess.open("res://validation/quality_model_results.json",FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("SLICED AI ESTIMATES / EARLY UPGRADE / RECOVERY ECONOMY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
