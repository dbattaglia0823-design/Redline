extends SceneTree

var failures := 0
var game: Node2D

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func key(code: Key, pressed: bool = true, echo_value: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo_value
	game._input(event)

func mouse(id: String, pressed: bool, mouse_button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = mouse_button
	event.pressed = pressed
	if pressed:
		var found := false
		for button in game.buttons:
			if button.id == id:
				event.position = button.rect.get_center()
				found = true
				break
		check(found, "Missing clickable race control: " + id)
	else:
		# Releasing outside a button must still release the pedal.
		event.position = Vector2(1, 1)
	game._input(event)

func race_rect(id: String) -> Rect2:
	for item in game.buttons:
		if item.id==id: return item.rect
	return Rect2()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.profile = DriverProfile.new(); game.profile.hardware=VehicleBench.fixture("legacy6")
	game.selected_opponent = 0
	game.wager = 0
	game.refresh_car()
	game.set_process(false)
	game.set_physics_process(false)
	RosterTest.ready(game); game.start_race()
	game.countdown = 0.0
	game.car.running = true
	game.rival.running = true
	game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	game.controls.clear()
	game.paused_race = false
	key(KEY_W)
	check(game.gas_input() == 1.0, "W did not press gas")
	key(KEY_SHIFT)
	key(KEY_SPACE)
	check(game.clutch_input() == 1.0 and game.nitrous_input(), "Shift and Space did not work alongside W")
	for tick in 120: game._physics_process(1.0 / 60.0)
	print("Free rev telemetry: speed=",game.car.speed," rpm=",game.car.rpm," limiter=",game.car.redline_rpm)
	check(game.car.speed == 0.0 and game.car.rpm > game.car.redline_rpm * 0.8, "Clutch did not disconnect engine during free rev")
	check(game.car.nitrous_remaining == Drivetrain.NITROUS_CAPACITY, "Nitrous was consumed with clutch held")
	key(KEY_W, false)
	check(game.gas_input() == 0.0 and game.nitrous_input(), "Space incorrectly acts as gas")
	key(KEY_SPACE, false)
	key(KEY_SHIFT, false)
	key(KEY_S)
	check(game.brake_input() == 1.0, "S did not press brake")
	key(KEY_S, false)
	check(game.brake_input() == 0.0 and game.clutch_input() == 0.0 and not game.nitrous_input(), "Keyboard pedals did not release")
	game.car.set_road_state(40.0,4)
	game.car.throttle = 1.0
	game.car.clutch_engagement = 1.0
	key(KEY_W)
	key(KEY_SPACE)
	game._physics_process(0.1)
	check(game.car.nitrous_active and game.car.nitrous_remaining < Drivetrain.NITROUS_CAPACITY, "Space did not activate nitrous in the race simulation")
	key(KEY_SPACE, false)
	key(KEY_W, false)
	game.car.set_road_state(24.0,3)
	key(KEY_E)
	check(game.car.gear == 4, "E did not upshift")
	game.car.shift_left = 0.0
	key(KEY_E, true, true)
	check(game.car.gear == 4, "Keyboard repeat shifted twice")
	key(KEY_E, false)
	key(KEY_Q)
	check(game.car.gear == 3, "Q did not downshift")
	key(KEY_Q, false)
	game.car.shift_left = 0.0
	for pedal in ["gas", "brake", "clutch", "nitrous"]:
		mouse(pedal, true)
		check(game.controls.value(pedal) == 1.0, "Mouse did not hold " + pedal)
		mouse(pedal, false)
		check(game.controls.value(pedal) == 0.0, "Mouse did not release " + pedal)
	mouse("gas", true)
	mouse("nitrous", true, MOUSE_BUTTON_RIGHT)
	game.car.set_road_state(40.0,4)
	game._physics_process(1.0 / 60.0)
	check(game.car.nitrous_active, "Mouse nitrous did not reach the race simulation")
	mouse("nitrous", false, MOUSE_BUTTON_RIGHT)
	game.car.set_road_state(24.0,3)
	mouse("clutch", true, MOUSE_BUTTON_RIGHT)
	check(game.gas_input() == 1.0 and game.clutch_input() == 1.0, "Independent mouse holds failed")
	mouse("clutch", false, MOUSE_BUTTON_RIGHT)
	check(game.gas_input() == 1.0 and game.clutch_input() == 0.0, "Mouse release cleared the wrong pedal")
	mouse("up", true, MOUSE_BUTTON_RIGHT)
	check(game.car.gear == 4 and game.gas_input() == 1.0, "Mouse paddle did not shift while gas was held")
	game.car.shift_left = 0.0
	mouse("down", true, MOUSE_BUTTON_RIGHT)
	check(game.car.gear == 3, "Mouse downshift failed")
	mouse("gas",false)
	game.car.shift_left = 0.0
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.pressed = true
	finger.position = game.to_global(race_rect("gas").get_center())
	game._input(finger)
	finger = InputEventScreenTouch.new()
	finger.index = 1
	finger.pressed = true
	finger.position = game.to_global(race_rect("clutch").get_center())
	game._input(finger)
	check(game.gas_input() == 1.0 and game.clutch_input() == 1.0,"Two-finger gas and clutch did not work")
	finger = InputEventScreenTouch.new()
	finger.index = 2
	finger.pressed = true
	finger.position = game.to_global(race_rect("up").get_center())
	game._input(finger)
	check(game.car.gear == 4 and game.gas_input() == 1.0,"Touch paddle did not shift while gas was held")
	finger.pressed = false
	game._input(finger)
	finger = InputEventScreenTouch.new()
	finger.index = 1
	finger.canceled = true
	finger.pressed = true
	game._input(finger)
	check(game.clutch_input() == 0.0 and game.gas_input() == 1.0,"Cancelled touch did not release the correct pedal")
	finger = InputEventScreenTouch.new()
	finger.index = 0
	finger.pressed = false
	game._input(finger)
	check(game.gas_input() == 0.0,"Touch release left gas held")
	game.set_race_paused(true)
	check(game.gas_input() == 0.0 and game.clutch_input() == 0.0, "Pausing left held controls active")
	game.set_race_paused(false)
	key(KEY_W)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused_race == OS.has_feature("mobile") and game.gas_input() == 0.0, "Focus loss should release gas without pausing desktop races")
	var focus_countdown: float = game.countdown
	game.countdown = 2.0
	game._physics_process(1.0/120)
	check(OS.has_feature("mobile") or game.countdown < 2.0,"Unfocused desktop race countdown stopped")
	game.set_race_paused(true)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.paused_race,"Focus changes unexpectedly resumed a manually paused race")
	game.countdown = focus_countdown
	game.set_race_paused(false)
	key(KEY_F3)
	check(game.debug_physics,"F3 did not enable drivetrain telemetry")
	key(KEY_F4)
	check(not game.show_shift_guide,"Optional shift guide did not toggle")
	game.set_race_paused(false)
	game.car.set_road_state(24.0,3)
	game.car.shift_left = 0.0
	game.car.cancel_shift_request()
	key(KEY_E)
	key(KEY_E,false)
	key(KEY_E)
	key(KEY_E,false)
	check(game.car.gear == 4 and game.car.queued_shift == 1,"Rapid keyboard taps were lost or shifted early")
	key(KEY_Q)
	key(KEY_Q,false)
	check(game.car.queued_shift == 0 and game.car.gear == 4,"Keyboard reversal did not cancel the pending shift")
	key(KEY_E)
	key(KEY_E,false)
	game.set_race_paused(true)
	check(game.car.queued_shift == 0,"Pause left a paddle request queued")
	game.set_race_paused(false)
	key(KEY_E)
	key(KEY_E,false)
	game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.car.queued_shift == 0,"Focus loss left a paddle request queued")
	game.set_race_paused(false)
	game.car.shift_left = 0.0
	game.car.set_road_state(24.0,3)
	var virtual_key := InputEventKey.new()
	virtual_key.physical_keycode = KEY_PAUSE
	virtual_key.keycode = KEY_W
	virtual_key.pressed = true
	game._input(virtual_key)
	check(game.gas_input() == 1.0,"Windows virtual keyboard did not fall back to logical W")
	virtual_key.pressed = false
	game._input(virtual_key)
	check(game.gas_input() == 0.0,"Virtual keyboard release left gas stuck")
	virtual_key.keycode = KEY_E
	virtual_key.pressed = true
	game._input(virtual_key)
	check(game.car.gear == 4,"Windows virtual paddle did not fall back to logical E")
	print("KEYBOARD + MOUSE + MULTITOUCH CONTROLS: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)

