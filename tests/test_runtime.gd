extends SceneTree

var failures := 0
var game: Node2D
var rows: Array = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.profile = DriverProfile.new()
	game.wager = 0
	game.selected_opponent = 0
	for rate in [30,60,120,144]:
		Engine.max_fps = rate
		RosterTest.ready(game); game.start_race()
		game.active_distance = 402.336
		game.countdown = 0.0
		game.car.running = true
		game.rival.running = true
		game.car.set_road_state(20.0,3)
		game.input_override = Vector2(0.8,0.0)
		game.debug_physics = true
		await create_timer(1.0).timeout
		var initial_skips: int = game.sound.underruns
		await create_timer(3.0).timeout
		var skips: int = game.sound.underruns-initial_skips
		var connected: bool = game.sound.voice.target_rpm == game.car.rpm and game.sound.voice.target_load == game.car.engine_load
		if skips > 0 or not connected or game.car.safety_clamps != 0:
			push_error("Runtime audio/physics failure at %d FPS: %d underruns / aligned %s" % [rate,skips,connected])
			failures += 1
		rows.append({"render_cap":rate,"startup_or_prior_underruns":initial_skips,"steady_audio_underruns":skips,"targets_equal_telemetry":connected,"physics_substeps":game.car.substeps,"safety_clamps":game.car.safety_clamps})
		if rate == 60:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.qa")
			root.get_texture().get_image().save_png("res://.qa/telemetry.png")
		game.go_garage()
	var f := FileAccess.open("res://validation/runtime_test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures":failures,"runs":rows,"note":"Windows graphical Godot run, 1 s warmup + 3 s sample per cap. Cap is a maximum, not a guarantee of achieved FPS. Output-device latency and subjective timbre are not tested."},"\t"))
	print("LIVE AUDIO + PHYSICS AT FOUR RENDER CAPS: ","PASS" if failures == 0 else "FAIL")
	print(JSON.stringify(rows))
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)
