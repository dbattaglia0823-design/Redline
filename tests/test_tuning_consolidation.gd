extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.profile = DriverProfile.new()
	game.profile.credits = 100000
	game.refresh_car()
	game.tab = "performance"
	game.menu.hub.categories = true
	for index in GarageHub.CATEGORIES.size():
		game.menu.hub.selected = index
		for section in game.menu.hub.studio.sections():
			check(section.id != "upgrade_section_tune", "Upgrade %d still has a separate tuning section" % index)
	check(TuningSetup.GROUPS.has("Launch") and TuningSetup.GROUPS.has("Power") and TuningSetup.GROUPS.has("Gearbox") and TuningSetup.GROUPS.has("Clutch") and TuningSetup.GROUPS.has("Grip"), "Main Tuning lost a category")
	check(TuningSetup.reason("tire_pressure", game.profile.hardware, int(game.profile.stages[4]), game.profile.vehicle_id) == "", "Factory tires still require retired upgrade menu")
	check(game.profile.tune_hardware("tire_pressure", 30.0, false), "Factory tire pressure cannot be tuned")
	check(TuningSetup.reason("launch_damping", game.profile.hardware, int(game.profile.stages[4]), game.profile.vehicle_id) != "", "Adjustable suspension requirement incorrectly removed")
	check(TuningSetup.reason("boost_by_gear", game.profile.hardware, int(game.profile.stages[4]), game.profile.vehicle_id) != "", "Hardware-dependent gear boost incorrectly unlocked")
	var money: int = game.profile.credits
	game.tuning.open()
	check(game.tab == "tuning", "Main Tuning tab failed to open from Upgrades")
	for preset in ["street", "drag", "safe"]:
		check(game.tuning.enabled("tt_quick_" + preset), "Quick tune unavailable: " + preset)
		game.tuning.action("tt_quick_" + preset)
		check(not game.profile.hardware.tune.is_empty(), "Quick tune did not update current build: " + preset)
	check(is_equal_approx(float(game.profile.hardware.tune.get("final_drive", 0)), 3.85), "Safe quick tune did not set final-drive ratio")
	var shifts: Array = game.car.shift_map.duplicate()
	check(game.profile.tune_hardware("shift_rpms", shifts, false), "Could not establish manual shift map")
	check(game.tuning.enabled("tt_reset_shift"), "Main Tuning automatic shift reset unavailable")
	game.tuning.action("tt_reset_shift")
	check(not game.profile.hardware.tune.has("shift_rpms"), "Shift reset did not restore automatic points")
	check(not game.tuning.enabled("tt_reset_shift"), "Shift reset should be disabled when already automatic")
	check(game.profile.credits == money, "Tuning charged credits")
	game.tuning.action("tt_back")
	check(game.tab == "performance", "Tuning did not return to Upgrades")
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	print("UNIFIED TUNING: ", checks, " checks / ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
