extends SceneTree

var failures := 0
var game: Node2D
var output_path := "res://.qa/"

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run_flow")

func capture(file_name: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_path + file_name + ".png")

func run_flow() -> void:
	DirAccess.make_dir_recursive_absolute(output_path)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.profile = DriverProfile.new()
	game.selected_opponent = 0
	game.event_index = 0
	game.refresh_car()
	game.input_override = Vector2(1.0, 0.0)
	game.profile.credits = 2400
	game.profile.xp = 0
	game.profile.races = 0
	game.profile.wins = 0
	game.profile.best = 0.0
	game.profile.stages = GameCatalog.blank_stages()
	await capture("garage")
	game.tab = "performance"
	game.selected_part = 1
	await capture("performance")
	game.tab = "dealer"
	game.dealer_index = 3
	await capture("dealership")
	game.tab = "races"
	await capture("race_selection")
	game.tab = "style"
	game.action("paint_1")
	game.action("wheel_1")
	await capture("appearance")
	game.tab = "driver"
	await capture("driver")
	check(game.profile.paint == 1 and game.profile.wheels == 1, "Appearance selection failed")
	RosterTest.ready(game); game.start_race()
	var got_race_image := false
	var crossing_speed := 0.0
	var crossing_time := 0.0
	for frame in 2400:
		await physics_frame
		game.paused_race = false
		if game.car.rpm >= 7050.0 and game.car.wheel_rpm(game.car.gear) >= 6900.0:
			if game.car.control_mode == "hpattern": game.car.select_manual_gear(game.car.gear+1,1.0)
			else: game.paddle(1)
		if crossing_speed == 0.0 and game.finish_hold_left > 0.0:
			crossing_speed = game.finish_speed
			crossing_time = game.player_finish
		if not got_race_image and game.car.elapsed > 3.0:
			game.paused_race = true
			# Render the race HUD while preventing time from moving during capture.
			game.paused_race = false
			await capture("race")
			got_race_image = true
		if game.screen == "results": break
	check(game.screen == "results", "Race did not reach results")
	check(crossing_speed > 0.0 and absf(game.finish_speed-crossing_speed) < 0.00001 and game.player_finish == crossing_time,"Coasting changed the recorded finish values")
	check(game.car.distance > game.active_distance and game.car.elapsed-game.player_finish > 0.54,"Finish did not coast with ongoing physics before the slip")
	print("Race finish: ", game.player_finish, " rival: ", game.rival_finish, " won: ", game.result_win)
	await capture("results")
	check(game.active_distance == 402.336 and game.player_finish > 10.0 and game.player_finish < 35.0, "Invalid quarter-mile finish time")
	check(game.profile.races == 1, "Race was not recorded exactly once")
	check(game.profile.credits == 2400 - game.active_stake + game.result_reward and game.profile.xp > 0, "Finish did not award the correct wager and race pay")
	check(game.sound.playback != null, "Engine audio did not initialize")
	var reward_credits: int = game.profile.credits
	game.go_garage()
	game.action("upgrade_0")
	check(game.profile.stages[0] == 1, "Upgrade was not installed")
	check(game.profile.credits == reward_credits - 700, "Upgrade cost incorrect")
	var restored = load("res://scripts/profile.gd").new()
	restored.load_profile()
	check(restored.credits == game.profile.credits and restored.stages == game.profile.stages, "Save/load did not preserve upgrades")
	check(restored.xp == game.profile.xp and absf(restored.best - game.profile.best) < 0.000001, "Save/load did not preserve race progress")
	check(restored.paint == 1 and restored.wheels == 1, "Save/load did not preserve appearance")
	game.profile.credits = 0
	var unchanged: Array = game.profile.stages.duplicate()
	check(not game.profile.upgrade(0) and game.profile.stages == unchanged, "Insufficient funds changed upgrades")
	game.profile.credits = 100000
	for i in 5: game.profile.upgrade(0)
	check(game.profile.stages[0] == 3, "Upgrade limit exceeded")
	game.event_index = 2
	RosterTest.ready(game); game.start_race()
	check(game.screen == "garage", "Locked event was allowed")
	print("RACE + PROGRESSION + SAVE FLOW: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)
