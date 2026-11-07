extends "res://tests/test_main_navigation.gd"

func button(code: int,pressed: bool=true,device: int=0) -> void:
	var event := InputEventJoypadButton.new()
	event.device=device; event.button_index=code; event.pressed=pressed
	root.push_input(event,true)

func press(code: int) -> void:
	button(code); button(code,false)

func axis(code: int,value: float,device: int=0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device=device; event.axis=code; event.axis_value=value
	root.push_input(event,true)

func select(id: String) -> void:
	game.glass.focused=id; press(JOY_BUTTON_A)
	await frame()

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car()
	await frame()
	check(GamepadControls.is_playstation("Sony DualSense Wireless Controller"),"DualSense detection")
	check(GamepadControls.is_playstation("PS4 Controller"),"PS4 detection")
	check(not GamepadControls.is_playstation("Xbox Series X Controller"),"Xbox detection")
	axis(JOY_AXIS_LEFT_X,.15)
	check(not game.gamepad.active,"Stick drift activated navigation")
	press(JOY_BUTTON_DPAD_DOWN)
	check(game.gamepad.active and game.glass.focused!="","Controller did not establish menu focus")
	game.glass.focused="tab_performance"
	press(JOY_BUTTON_A)
	await frame()
	check(game.tab=="performance","Controller confirm did not activate Upgrade")
	game.profile.credits=100000
	await select("upgrade_system_0")
	await select("hub_category_0")
	await select("stage_pick_2")
	button(JOY_BUTTON_A,false)
	game.glass.focused="install_0_2"
	button(JOY_BUTTON_A); button(JOY_BUTTON_A); button(JOY_BUTTON_A,false)
	await frame()
	check(game.profile.stages[0]==2 and game.profile.credits==97900,"Controller purchase was missing or charged more than once")
	press(JOY_BUTTON_B); await frame()
	game.action("tab_performance"); await frame()
	game.glass.focused="open_tuning"; press(JOY_BUTTON_A)
	await frame()
	check(game.tab=="tuning","Controller cannot open tuning")
	var panel: GearboxTuningPanel=game.tuning.gearbox_panel
	var slider: HSlider=panel.rows.final_drive.slider
	var options: Array[Dictionary] = game.gamepad.targets(game)
	for item in options:
		if item.get("native_control")==slider:
			game.glass.focused=item.id; game.gamepad.focus_control=slider
	var before:=slider.value
	axis(JOY_AXIS_LEFT_X,1); axis(JOY_AXIS_LEFT_X,0)
	check(slider.value>before,"Controller cannot adjust native tuning slider")
	press(JOY_BUTTON_B); await frame()
	check(game.tab!="tuning","Controller Back trapped in tuning")
	game.start_practice(game.FINISH); await frame()
	axis(JOY_AXIS_TRIGGER_RIGHT,.525)
	check(absf(game.gas_input()-.5)<.001,"Analog throttle is not proportional")
	axis(JOY_AXIS_TRIGGER_LEFT,.24)
	check(absf(game.brake_input()-.2)<.001,"Analog brake is not proportional")
	axis(JOY_AXIS_TRIGGER_RIGHT,.04)
	check(game.gas_input()==0,"Trigger deadzone")
	axis(JOY_AXIS_TRIGGER_RIGHT,1,1)
	check(game.gamepad.device==0 and game.gas_input()==0,"Second pad stole active race input")
	button(JOY_BUTTON_LEFT_SHOULDER)
	check(game.clutch_input()==1,"Controller clutch")
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	check(game.clutch_input()==0,"Clutch stuck on release")
	game.countdown=0; game.car.running=true; game.car.gear=1
	axis(JOY_AXIS_TRIGGER_LEFT,0); axis(JOY_AXIS_TRIGGER_RIGHT,1)
	for i in 240: game._physics_process(1.0/120)
	check(game.car.distance>0 and game.car.speed>0,"Controller throttle did not accelerate actual vehicle physics")
	axis(JOY_AXIS_TRIGGER_RIGHT,0)
	game.car.control_mode="hpattern"; game.car.gear=0
	press(JOY_BUTTON_B)
	check(game.car.gear==0,"Controller manual shift bypasses clutch requirement")
	button(JOY_BUTTON_LEFT_SHOULDER); press(JOY_BUTTON_B)
	check(game.car.gear==1 or game.car.shift_left>0,"Manual controller shift did not use clutch physics")
	button(JOY_BUTTON_LEFT_SHOULDER,false)
	press(JOY_BUTTON_START); await frame()
	check(game.paused_race and game.gas_input()==0,"Menu button does not safely pause")
	game.glass.focused="resume"; press(JOY_BUTTON_A)
	check(not game.paused_race and game.controls.value("nitrous")==0,"Menu confirmation leaked nitrous into race")
	press(JOY_BUTTON_START); await frame()
	game.gamepad.playstation=true
	check(game.gamepad.hint("up")=="Circle" and game.gamepad.hint("gas")=="R2","PlayStation prompts")
	DirAccess.make_dir_recursive_absolute("res://.qa/controller/screens")
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions; game.toast_left=0
		await frame()
		root.get_texture().get_image().save_png("res://.qa/controller/screens/pause_%d.png"%dimensions.x)
	press(JOY_BUTTON_START)
	axis(JOY_AXIS_TRIGGER_RIGHT,1)
	game.gamepad.connection_changed(game,0,false)
	check(game.paused_race and game.controls.joy.is_empty(),"Disconnect failed to pause / clear controller")
	press(JOY_BUTTON_START)
	check(not game.paused_race and game.gamepad.device==0,"Reconnection cannot resume")
	axis(JOY_AXIS_TRIGGER_RIGHT,1)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.gas_input()==0,"Focus loss left throttle held")
	game.stop_presentation_audio()
	print("PLAYSTATION / XBOX CONTROLLER: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
