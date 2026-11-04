extends SceneTree
var game: Node2D
var failures := 0
func check(ok: bool,msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	if game!=null and game.race_start_pending: game._process(0)
	game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	root.get_texture().get_image().save_png("res://.qa/effects_"+name+".png")
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile = DriverProfile.new(); game.profile.hardware = VehicleBench.fixture("legacy6",["drag_wheels"])
	game.selected_opponent = 0; game.wager = 0; RosterTest.ready(game); game.start_race(); game.countdown = 0
	game.active_distance = 402.336; game.car.running = true; game.rival.running = true
	game.car.grip_coefficient = .10
	game.controls.hold("test_gas","gas"); game.controls.hold("test_brake","brake")
	for i in 480: game.car.step(1.0/240,1,1)
	game.feedback.set_quality(2)
	for i in 60: game.feedback.update(1.0/120,game.car,false,GameCatalog.spec("kaze"))
	var before: Dictionary = game.car.telemetry()
	DirAccess.make_dir_recursive_absolute("res://.qa")
	await frame(); capture("burnout_high")
	check(game.car.telemetry() == before,"Rendering modified drivetrain state")
	game.set_race_paused(true); await frame()
	var position := Vector2(-1,-1)
	for item in game.buttons:
		if item.id == "effects_quality": position = item.rect.get_center()
	check(position.x >= 0,"Quality control missing from pause menu")
	var click := InputEventMouseButton.new(); click.position = position; click.pressed = true; click.button_index = MOUSE_BUTTON_LEFT
	game._input(click); click.pressed = false; game._input(click)
	check(game.profile.effects_quality == 0 and game.feedback.smoke.size() <= 8,"Quality button failed to change or trim effects")
	game.set_race_paused(false)
	await frame(); capture("burnout_low")
	check(game.car.telemetry() == before,"Quality selection altered physical state")
	var restored := DriverProfile.new(); restored.load_profile()
	check(restored.effects_quality == 0 and restored.hardware.parts.get("wheels") == "drag_wheels","Quality save lost customization")
	game.profile.effects_quality = 2; game.feedback.set_quality(2)
	game.car.set_road_state(35,4); game.car.clutch_engagement = 1
	for i in 60:
		game.car.step(1.0/240,0,1)
		game.feedback.update(1.0/240,game.car,false,GameCatalog.spec("kaze"))
	await frame(); capture("braking")
	check(game.feedback.body_pitch > 0 and game.feedback.body_offset.y < .1,"Braking feedback did not follow deceleration")
	print("STATIC BODY / WHEEL LAYERS / QUALITY INPUT / RENDER ISOLATION: ","PASS" if failures == 0 else "FAIL")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures == 0 else 1)
