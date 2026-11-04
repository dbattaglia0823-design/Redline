extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var legacy := {"credits":12345,"xp":675,"wins":3,"races":7,"best":14.21,"paint":4,"wheels":2,"stages":[1,2,3,1,2]}
	var f := FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	var p := DriverProfile.new()
	p.load_profile()
	check(p.credits == 12345 and p.xp == 675 and p.best == 14.21,"Legacy money and records were not preserved")
	check(p.stages == [1,2,3,1,2,0,0,0] and p.paint == 4 and p.wheels == 2,"Legacy car build was not migrated")
	check(p.garage.has("miata"),"Legacy starter car is missing")
	p.credits = 1000
	check(not p.begin_wager(-1) and not p.begin_wager(1001),"Invalid wager was allowed")
	check(p.begin_wager(200) and p.credits == 800,"Stake was not charged on entry")
	check(not p.begin_wager(200) and p.credits == 800,"Stake was charged twice")
	check(p.settle_wager(true) == 400 and p.credits == 1200,"Winning bet did not return both stakes")
	check(p.settle_wager(true) == 0 and p.credits == 1200,"Winning bet could be paid twice")
	p.begin_wager(200)
	p.settle_wager(false)
	check(p.credits == 1000,"Losing bet did not lose exactly the stake")
	p.begin_wager(250)
	p.forfeit_wager()
	check(p.credits == 750 and p.pending_wager.is_empty(),"Aborted race refunded its stake")
	p.begin_wager(100)
	var reloaded := DriverProfile.new()
	reloaded.load_profile()
	check(reloaded.credits == 650 and reloaded.pending_wager.is_empty(),"Reload refunded an interrupted stake")
	p.settle_wager(false)
	p.credits = 0
	check(p.begin_wager(0),"Bankrupt player cannot enter a zero-stake race")
	p.settle_wager(false)
	p.credits = 50000
	var saved_stages := p.stages.duplicate()
	check(p.buy_vehicle("civic_si") and p.credits == 44800,"Dealership charged the wrong price")
	check(p.vehicle_id == "civic_si" and p.stages == GameCatalog.blank_stages(),"Purchased car inherited another car's build")
	check(not p.buy_vehicle("civic_si") and p.credits == 44800,"Duplicate vehicle purchase charged money")
	p.paint = 1
	p.wheels = 1
	check(p.upgrade(1,3) and p.stages[1] == 3 and p.credits == 38800,"Tier-three installation did not charge all required tiers")
	check(not p.upgrade(1,2),"Upgrade allowed a downgrade")
	p.select_vehicle("miata")
	check(p.stages == saved_stages and p.paint == 4 and p.wheels == 2,"Switching cars lost the original build")
	p.select_vehicle("civic_si")
	check(p.stages[1] == 3 and p.paint == 1 and p.wheels == 1,"Purchased car did not keep its own build")
	p.career_wins = [3,1,0]
	p.save()
	reloaded.load_profile()
	check(reloaded.vehicle_id == "civic_si" and reloaded.garage.size() == 2 and reloaded.career_wins == [3,1,0],"Collection or career progress was not saved")
	check(reloaded.stages[1] == 3 and reloaded.paint == 1,"Reload lost purchased-car upgrades")
	var starter := Drivetrain.new()
	var flagship := Drivetrain.new()
	flagship.configure_vehicle(GameCatalog.spec("vanta"))
	check(flagship.peak_horsepower() > starter.peak_horsepower()*1.5 and flagship.grip_coefficient > starter.grip_coefficient,"Dealer vehicles do not have distinct performance")
	var modified := Drivetrain.new()
	modified.configure([0,0,0,0,0,3,3,3])
	check(modified.peak_horsepower() > starter.peak_horsepower() and modified.nitrous_capacity() == 10.5,"New upgrade categories have no effect")
	print("WAGERS + DEALERSHIP + SAVE MIGRATION: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
