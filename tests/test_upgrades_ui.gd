extends SceneTree

var game: Node2D
var failures := 0
var checks := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_checks")
func refresh() -> void:
	game.queue_redraw()
	for i in 2: await process_frame
	await RenderingServer.frame_post_draw
	for item in game.buttons:
		if str(item.id).begins_with("tx_") or str(item.id).begins_with("hw_") or str(item.id).begins_with("tune_"):
			check(item.rect.size.x >= 44.0 and item.rect.size.y >= 44.0,"Upgrade target smaller than 44 logical pixels")
			check(Rect2(0,0,1200,760).encloses(item.rect),"Upgrade control outside viewport")
func center(id: String) -> Vector2:
	for item in game.buttons:
		if item.id == id: return item.rect.get_center()
	check(false,"Missing upgrade/control button: "+id)
	return Vector2(-1,-1)
func click(id: String) -> void:
	if id=="tab_performance":
		game.go_garage(); await refresh(); id="garage_upgrades"
	var control: Control=game.native_workshop.targets.get(id)
	if is_instance_valid(control):
		var ancestor:=control.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await refresh()
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.position = center(id); e.pressed = true
	game._input(e); e.pressed = false; game._input(e)
	await refresh()
func key(code: Key,pressed: bool = true) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.pressed = pressed; game._input(e)
func touch(id: String,index: int,pressed: bool) -> void:
	var e := InputEventScreenTouch.new(); e.position = center(id) if pressed else Vector2(1,1); e.index = index; e.pressed = pressed; game._input(e)
func capture(name: String) -> void:
	root.get_texture().get_image().save_png("res://.qa/upgrade_"+name+".png")
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.menu.hub.categories = true
	game.set_process(false); game.set_physics_process(false)
	game.profile = DriverProfile.new(); game.profile.credits = 2000000; game.refresh_car()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.qa"))
	await refresh(); await click("tab_performance"); await click("upgrade_system_1"); await click("hub_category_7"); capture("basic")
	check(game.workshop.mode == "transmission","Transmission types missing from the default view")
	var found: Array = game.buttons.filter(func(item): return str(item.id).begins_with("tx_pick_"))
	check(found.size()==4,"Transmission shop did not show all four types")
	await click("tx_pick_"+str(game.profile.hardware.transmission)); capture("gearboxes")
	await click("system_pick_gear_strength"); await click("hw_buy")
	check(game.profile.hardware.parts.has("gear_strength"),"Gearbox upgrade did not install")
	await click("system_tuning")
	var ratio: float = game.car.gear_ratios[0]
	await click("tt_plus_ratio")
	check(game.car.gear_ratios[0]>ratio,"Ratio tuning did not change physics")
	capture("tuning")
	game.selected_opponent = 0; game.wager = 0; RosterTest.ready(game); game.start_race(); game.countdown = 0.0; game.car.running = true
	await refresh(); capture("h_gate")
	key(KEY_2); check(game.car.gear == 1,"Keyboard H gate bypassed clutch")
	key(KEY_2,false); key(KEY_SHIFT); key(KEY_2)
	check(game.car.gear == 2,"Keyboard clutch + H gate failed")
	key(KEY_2,false); key(KEY_SHIFT,false)
	game.car.shift_left = 0.0
	touch("gas",0,true); touch("clutch",1,true); touch("manual_3",2,true)
	check(game.car.gear == 3 and game.gas_input() == 1.0,"Multitouch H gear + pedals failed")
	for i in 3: touch("gas",i,false)
	check(game.gas_input() == 0.0 and game.clutch_input() == 0.0,"Touch release left held pedals")
	game.profile.forfeit_wager(); game.screen = "garage"; game.profile.install_transmission("drag3"); game.profile.upgrade(4,5); game.refresh_car()
	RosterTest.ready(game); game.start_race(); game.countdown = 0.0; game.car.running = true
	await refresh(); capture("drag_race")
	key(KEY_W)
	check(not game.car.has_transbrake,"Retired transbrake was equipped")
	for tick in 120: game._physics_process(1.0/120.0)
	check(game.car.speed > 1.0,"Drag automatic did not launch")
	key(KEY_W,false); game.controls.clear()
	game.profile.forfeit_wager(); game.screen = "garage"; game.tab = "performance"; game.menu.hub.action("hub_test")
	await refresh(); var money: int = game.profile.credits; var races: int = game.profile.races
	await click("lab_run")
	for i in 64:
		if game.workshop.lab.done: break
		game.workshop.update()
	check(game.workshop.lab.done and game.workshop.lab_result.get("quarter_s") != null,"Independent vehicle test did not finish")
	check(game.profile.credits == money and game.profile.races == races,"Vehicle test changed race progression")
	await refresh(); capture("lab")
	print("UPGRADE UI + HARDWARE CONTROLS: ",checks," checks; ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)

