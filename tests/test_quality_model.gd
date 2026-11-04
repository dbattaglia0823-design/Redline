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
	var losses_to_engine := ceili(700.0/(int(first.purse)*.4))
	check(losses_to_engine == 7,"Recovery race economics unexpectedly changed")
	var progress: Array = []
	for race_index in 8:
		var bot := GameCatalog.opponent(0,mini(race_index,4))
		var win_pay := int(bot.purse); p.credits += win_pay; p.xp += 180
		p.career_wins[0] = mini(5,race_index+1)
		progress.append({"wins":race_index+1,"credits":p.credits,"level":p.level()})
		if race_index == 3: check(p.credits >= int(GameCatalog.spec("mika").price),"Starter collection goal requires excessive wins after the first upgrade")
	check(p.level() >= 3 and p.credits >= int(GameCatalog.spec("civic_si").price),"Eight early wins do not support meaningful progression")
	check(p.buy_vehicle("civic_si") and p.garage.has("miata"),"Earning a new car erased the starter build")
	var output := {"passed":failures==0,"sliced_matches_direct":comparisons,"stock_quarter":stock,"engine_stage1_quarter":upgraded,"early_progression":progress,"losses_from_zero_to_first_engine_upgrade":losses_to_engine,"note":"Assisted-driver estimates and modeled win/finish payouts, not guaranteed human win rates. Prices and purses were retained."}
	var f := FileAccess.open("res://validation/quality_model_results.json",FileAccess.WRITE); f.store_string(JSON.stringify(output)); f.close()
	print("SLICED AI ESTIMATES / EARLY UPGRADE / RECOVERY ECONOMY: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
