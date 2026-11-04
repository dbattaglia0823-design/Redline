extends SceneTree
var failures := 0
func check(ok: bool,msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void:
	var profile := DriverProfile.new()
	check(RaceAI.recommended(profile,0) == 0,"Matchmaker selected locked rival")
	var driver := {"model":"kaze","stages":[0,0,0,0,0,0,0,0],"hardware":VehicleParts.default_build(),"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}
	var stock := RaceAI.estimate(driver)
	driver.stages = [3,3,3,3,3,3,3,0]
	var built := RaceAI.estimate(driver)
	check(built.time < stock.time and built.hp > stock.hp,"AI/matchmaking ignores installed upgrades")
	check(RaceAI.estimate(driver) == built,"Repeatable simulation estimate diverged")
	var final := RaceAI.estimate(GameCatalog.opponent(2,4))
	var first := RaceAI.estimate(GameCatalog.opponent(2,0))
	check(final.time < first.time,"Final-tier progression not faster through physics")
	profile.credits = 1000; profile.xp = 1400; profile.wins = 5; profile.career_wins = [5,2,0]; profile.save()
	check(profile.save_error == "","Atomic save failed")
	var loaded := DriverProfile.new(); loaded.load_profile()
	check(loaded.credits == 1000 and loaded.xp == 1400 and loaded.wins == 5 and loaded.career_wins == [5,2,0],"Career/milestone save lost progress")
	check(profile.begin_wager(0),"Recovery race unavailable")
	check(not profile.begin_wager(0),"Duplicate race entry accepted")
	print("MATCHMAKING / AI BUILDS / CAREER / ATOMIC SAVE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
