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
func click(id: String,touch: bool = false) -> void:
	var p := Vector2(-1,-1)
	for b in game.buttons:
		if b.id == id: p = b.rect.get_center()
	check(p.x >= 0,"Missing control: "+id)
	if touch:
		var e := InputEventScreenTouch.new(); e.index = 3; e.position = p; e.pressed = true; game._input(e); e.pressed = false; game._input(e)
	else:
		var e := InputEventMouseButton.new(); e.position = p; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true; game._input(e); e.pressed = false; game._input(e)
	await frame()
func capture(name: String) -> void: root.get_texture().get_image().save_png("res://.qa/custom_"+name+".png")
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.profile = DriverProfile.new(); game.profile.credits = 1000000; game.profile.xp = 20000; game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa")
	await frame(); await click("tab_style",true)
	check(game.tab == "style","Garage Customize entry")
	var money: int = game.profile.credits; var saved := FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)
	await click("custom_category_finish"); await click("custom_pick_2",true)
	check(game.profile.appearance.finish == 0 and game.profile.credits == money and FileAccess.get_file_as_string(DriverProfile.SAVE_PATH) == saved,"Preview writes currency/car/save")
	capture("preview")
	await click("custom_compare"); check(game.menu.customize.compare,"Compare installed")
	await click("custom_install"); check(game.profile.appearance.finish == 2 and game.profile.credits == money-450,"Buy/install preview")
	for key in VehicleAppearance.definition(game.profile.vehicle_id).compatible:
		await click("custom_category_"+key); await click("custom_pick_1"); await click("custom_install")
	capture("build")
	for i in game.buttons.size():
		var a: Rect2 = game.buttons[i].rect
		check(Rect2(0,0,1200,760).encloses(a),"Control outside canvas")
		for j in range(i+1,game.buttons.size()): check(not a.intersects(game.buttons[j].rect),"Overlapping controls")
	var look: Dictionary = game.profile.appearance.duplicate(true)
	await click("custom_back"); await click("tab_style")
	check(game.menu.customize.candidate == look,"Reopen lost installed look")
	# Each model uses the same renderer, UI and compatible catalog.
	for id in GameCatalog.CAR_IDS:
		if not game.profile.garage.has(id): game.profile.buy_vehicle(id)
		else: game.profile.select_vehicle(id)
		game.refresh_car(); game.menu.customize.open()
		game.menu.customize.candidate = look.duplicate(true)
		await frame(); capture(id)
		for key in ["finish","design","sidewall","tint","spoiler","headlight","taillight","decal"]: game.menu.customize.candidate[key] = 2
		await frame(); capture(id+"_extreme")
	check(VehicleAppearance._textures.size() <= 32,"Unbounded layer cache")
	root.size = Vector2i(844,534); await frame(); capture("mobile_landscape")
	await click("custom_category_design",true); await click("custom_pick_2",true); await click("custom_install",true)
	check(game.profile.appearance.design == 2,"Touch install at landscape window size")
	root.size = Vector2i(390,844); await frame(); capture("portrait")
	check(root.content_scale_size == Vector2i(600,1300),"Portrait did not reflow")
	for item in game.buttons:
		check(Rect2(0,0,600,1300).encloses(item.rect),"Portrait control out of bounds")
		check(item.rect.size.y >= 68,"Portrait touch target too short")
	await click("custom_category_paint",true); await click("custom_pick_4",true)
	check(game.profile.paint == 0,"Portrait preview changed installed paint")
	await click("custom_install",true); check(game.profile.paint == 4,"Portrait touch installation")
	await click("custom_compare",true); check(game.menu.customize.compare,"Portrait compare")
	root.size = Vector2i(1200,760)
	game.profile.select_vehicle("kaze"); game.refresh_car(); game.tab = "garage"; await frame(); capture("garage")
	game.wager = 0; RosterTest.ready(game); game.start_race(); game.countdown = 0
	game.car.running = true; game.car.grip_coefficient = .1
	for i in 480: game.car.step(1.0/240,1,1)
	for i in 60: game.feedback.update(1.0/120,game.car,false,GameCatalog.spec("kaze"))
	var telemetry: Dictionary = game.car.telemetry(); await frame(); capture("race")
	check(game.car.telemetry() == telemetry,"Layer rendering writes physics")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame
	check(VehicleAppearance._textures.is_empty(),"Presentation textures retained after scene shutdown")
	print("CUSTOMIZE PREVIEW / MOUSE / TOUCH / ALL VEHICLES / SCALING / RACE: ","PASS" if failures == 0 else "FAIL")
	call_deferred("quit",0 if failures == 0 else 1)
