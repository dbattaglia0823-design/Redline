extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	check(DriverSkills.NODES.size() == 12, "Missing driver skill nodes")
	check(DriverSkills.CATEGORIES.size() == 4, "Missing skill categories")
	var fresh: Dictionary = {}
	check(DriverSkills.available(fresh, 1) == 0, "Level one should have no unearned points")
	check(not DriverSkills.can_unlock(fresh, 1, "launch_basics"), "Level one unlocked without XP")
	check(DriverSkills.can_unlock(fresh, 5, "launch_basics"), "Base skill unavailable")
	check(not DriverSkills.can_unlock(fresh, 5, "tree_reaction"), "Prerequisite bypassed")
	fresh = DriverSkills.unlock(fresh, 5, "launch_basics")
	check(DriverSkills.can_unlock(fresh, 5, "tree_reaction"), "Prerequisite not recognized")
	fresh = DriverSkills.unlock(fresh, 5, "tree_reaction")
	check(DriverSkills.available(fresh, 5) == 2, "Point spending not persistent")
	check(not DriverSkills.can_unlock(fresh, 5, "tree_reaction"), "Max rank exceeded")
	check(is_equal_approx(DriverSkills.xp_bonus(fresh, 5, true, false, 0.15, 0), 0.15), "Launch bonus incorrect")
	check(is_equal_approx(DriverSkills.xp_bonus(fresh, 5, true, true, -0.03, 0), 0.05), "Red light bonus incorrect")
	var invalid := {"holeshot":1, "unknown":4, "launch_basics":10}
	check(DriverSkills.sanitize(invalid, 3) == {"launch_basics":1}, "Invalid skills not sanitized")
	check(DriverSkills.sanitize({"launch_basics":1,"tree_reaction":1}, 1).is_empty(), "Unearned ranks survive a level reduction")
	var profile := DriverProfile.new()
	profile.xp = 2400
	check(profile.level() >= 5 and profile.available_skill_points() >= 4, "Existing XP not recognized")
	check(profile.unlock_driver_skill("launch_basics"), "Unlock failed")
	check(profile.available_skill_points() == profile.level() - 2, "Skill point not deducted")
	var loaded := DriverProfile.new()
	loaded.load_profile()
	check(loaded.skill_ranks.get("launch_basics",0) == 1, "Skill unlock not saved")
	check(loaded.available_skill_points() == profile.available_skill_points(), "Skill points changed on reload")
	var layout := JSON.parse_string(FileAccess.get_file_as_string("res://data/driver_skill_tree.layout.json"))
	check(layout is Dictionary and layout.get("version") == 2, "Layout not importable")
	print("DRIVER SKILLS: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
