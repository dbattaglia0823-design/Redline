extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	check(DriverSkills.NODES.size() == 28, "Skill tree must have 28 nodes")
	var known: Dictionary = {}
	for node in DriverSkills.NODES:
		check(not known.has(node.id), "Duplicate skill id")
		known[node.id] = true
		for required in node.requires:
			check(not DriverSkills.node_for(str(required)).is_empty(), "Unknown prerequisite")
		check((node.category == "Career") == (node.effect in ["money","xp"]), "Non-career economy perk or misplaced racing perk")
	for category in DriverSkills.CATEGORIES:
		check(DriverSkills.NODES.filter(func(n): return n.category == category).size() == 7, "Wrong skill count for " + category)
	var fresh: Dictionary = {}
	check(DriverSkills.available(fresh,1) == 0, "Level 1 has unearned points")
	check(not DriverSkills.can_unlock(fresh,1,"launch_basics"), "Skill unlocked at level 1")
	check(not DriverSkills.can_unlock(fresh,5,"holeshot"), "Prerequisites bypassed")
	fresh = DriverSkills.unlock(fresh,5,"launch_basics")
	check(DriverSkills.can_unlock(fresh,5,"tree_reaction"), "Prerequisite failed")
	check(DriverSkills.available(fresh,5) == 3, "Wrong remaining skill points")
	check(DriverSkills.sanitize({"holeshot":1},4).is_empty(), "Orphaned skill accepted")
	var values := DriverSkills.performance_modifiers(fresh,5)
	check(is_equal_approx(float(values.grip),.02), "Launch Basics should give exactly 2% grip")
	check(is_zero_approx(float(DriverSkills.xp_bonus(fresh,5,true,false,.05,4))), "Racing skill granted XP")
	check(is_zero_approx(float(DriverSkills.money_bonus(fresh,5,true,false))), "Racing skill granted credits")
	var base := Drivetrain.new()
	base.configure_vehicle(GameCatalog.spec("miata"))
	base.configure(GameCatalog.blank_stages())
	base.configure_build(GameCatalog.factory_build("miata"),"miata",false)
	var grip_before: float = base.effective_grip()
	var time_before: float = base.shift_duration
	base.apply_driver_skills(fresh,5)
	check(is_equal_approx(base.effective_grip()/grip_before,1.02), "Physics grip perk not active")
	base.apply_driver_skills(fresh,5)
	check(is_equal_approx(base.effective_grip()/grip_before,1.02), "Grip perk stacked on refresh")
	base.configure_build(GameCatalog.factory_build("miata"),"miata",false)
	check(is_equal_approx(base.effective_grip(),grip_before), "Driver physics perk leaked into baseline car")
	check(is_equal_approx(base.shift_duration,time_before), "Vehicle baseline shift changed")
	var shifting := DriverSkills.unlock({},5,"shift_basics")
	base.apply_driver_skills(shifting,5)
	check(base.shift_duration < time_before, "Shifting skill did not reduce shift delay")
	var economic := DriverSkills.unlock({},15,"street_rookie")
	economic = DriverSkills.unlock(economic,15,"street_veteran")
	economic = DriverSkills.unlock(economic,15,"street_legend")
	economic = DriverSkills.unlock(economic,15,"street_learner")
	economic = DriverSkills.unlock(economic,15,"night_regular")
	check(is_equal_approx(DriverSkills.xp_bonus(economic,15,true,false,.2,0),.38), "Career XP stacking wrong")
	check(is_equal_approx(DriverSkills.money_bonus(economic,15,true,false),.05), "Career money bonus missing")
	check(is_zero_approx(DriverSkills.money_bonus(economic,15,false,false)), "Money on loss")
	check(is_zero_approx(DriverSkills.money_bonus(economic,15,true,true)), "Money on red light")
	var p := DriverProfile.new()
	p.xp = 2400
	check(p.unlock_driver_skill("launch_basics"), "Cannot spend skill point")
	check(p.available_skill_points() == p.level()-2, "Point ledger changed unexpectedly")
	var reloaded := DriverProfile.new()
	reloaded.load_profile()
	check(reloaded.skill_ranks.get("launch_basics",0)==1, "Existing skill save lost")
	for cat in ["E","D","C","B","A","S"]:
		for i in range(10):
			var cap := Championships.bet_cap(cat,i)
			check(cap>=0 and cap<=400000, "Championship cap exceeds $400,000")
	check(Championships.bet_cap("S",9)==400000, "Hardest S race must cap at $400,000")
	check(Championships.bet_cap("A",9)<400000, "A class must remain below S")
	for id in Championships.catalog():
		var record: Dictionary = Championships.event(str(id))
		check(int(record.get("max_bet",0))<=400000, "Race record exceeds wager limit: " + str(id))
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/driver_skill_tree.layout.json"))
	check(layout is Dictionary and layout.get("version") == 2, "Toolkit layout missing")
	print("DRIVER SKILLS / RACE CAPS: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
