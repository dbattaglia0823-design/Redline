extends SceneTree
var game: Node2D
var failures := 0
var checks := 0
func check(ok: bool,msg: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	if game!=null and game.race_start_pending: game._process(0)
	game.sync_menu_size(); game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void: root.get_texture().get_image().save_png("res://.qa/quality_"+name+".png")
func click(id: String,touch: bool = true) -> void:
	var point := Vector2(-1,-1)
	for button in game.buttons:
		if button.id == id: point = game.to_global(button.rect.get_center())
	check(point.x >= 0,"Missing action "+id)
	if touch:
		var e := InputEventScreenTouch.new(); e.index = 7; e.position = point; e.pressed = true; game._input(e); e.pressed = false; game._input(e)
	else:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.position = point; e.pressed = true; game._input(e); e.pressed = false; game._input(e)
	await frame()
func key(code: Key,pressed: bool = true) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.pressed = pressed; game._input(e)
func bounds(label: String) -> void:
	var canvas := Rect2(0,0,600,1300) if game.is_portrait() else Rect2(0,0,1200,760)
	for i in game.buttons.size():
		var a: Rect2 = game.buttons[i].rect
		check(canvas.encloses(a),label+": control outside canvas "+game.buttons[i].id)
		if game.is_portrait(): check(a.size.y >= 64,label+": small touch target "+game.buttons[i].id)
		for j in range(i+1,game.buttons.size()): check(not a.intersects(game.buttons[j].rect),label+": overlapping "+game.buttons[i].id+" and "+game.buttons[j].id)
func run_race(start_action: String) -> void:
	await click(start_action); key(KEY_W)
	for tick in 7500:
		game.paused_race = false
		if game.car.control_mode != "automatic" and game.car.upshift_ready():
			if game.car.control_mode=="hpattern":
				key(KEY_SHIFT); key(KEY_0+game.car.gear+1); key(KEY_SHIFT,false)
			else: key(KEY_E); key(KEY_E,false)
		game._physics_process(1.0/120)
		if tick%120 == 0: game._process(1.0/120)
		if game.screen == "results": break
	key(KEY_W,false)
	check(game.screen == "results" and game.player_finish > 0,"Keyboard-driven new-player race did not finish")
	await frame()
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.profile = DriverProfile.new(); game.refresh_car(); game.selected_opponent = 0
	DirAccess.make_dir_recursive_absolute("res://.qa")
	root.size = Vector2i(390,844); await frame(); capture("fresh_garage"); bounds("garage")
	check(game.wager == 0 and game.profile.credits == 2400,"Fresh game needs setup or starts with a risky wager")
	await click("race_menu"); await click("race"); game.complete_race()
	check(game.screen == "race" and game.profile.xp == 0,"Unfinished race paid a reward")
	game.go_garage(); await frame(); check(game.tab == "garage","Garage returned to a stale tab")
	await click("race_menu"); await run_race("race"); bounds("results"); capture("first_results")
	check(game.profile.races == 1 and game.profile.credits >= 2500 and game.profile.xp > 0,"Fresh race failed to pay/save progress")
	var paid: int = game.profile.credits; game.complete_race(); check(game.profile.credits == paid,"Duplicate result paid twice")
	await click("results_upgrades"); await click("hub_category_0")
	var old_hp: int = game.car.peak_horsepower(); var old_money: int = game.profile.credits
	check(game.workshop._preview.peak_horsepower() > old_hp,"Upgrade preview has no visible benefit")
	await click("hub_dyno"); bounds("dyno"); capture("upgrade_dyno"); await click("hub_dyno_close")
	await click("install_0_1"); check(game.car.peak_horsepower() > old_hp and game.profile.credits == old_money-700,"Upgrade is disconnected from racing or costs the wrong amount")
	await click("install_0_1"); check(game.profile.credits == old_money-700,"Repeated upgrade click charged twice")
	await click("hub_back"); await click("tab_garage"); check(game.tab == "garage","Upgrade navigation lost garage")
	await click("race_menu"); await click("bot_0")
	var repeat_count := 0
	var next_car: String=game.menu.dealer.class_ids("E").filter(func(id): return not game.profile.garage.has(id))[0]
	var purchase_price := int(GameCatalog.spec(next_car).price)
	while game.profile.credits < purchase_price and repeat_count < 28:
		await run_race("race" if repeat_count == 0 else "retry"); repeat_count += 1
	check(game.profile.credits >= purchase_price,"Recovery races cannot fund another car")
	await click("garage"); await click("tab_dealer"); await click("shop_class_E")
	game.dealer_index = GameCatalog.CAR_IDS.find(next_car); await frame(); bounds("dealer"); capture("dealer")
	await click("buy_car"); check(game.profile.garage.has(next_car) and game.profile.vehicle_id == next_car,"Earned purchase not in collection")
	await click("tab_garage"); await click("hub_owned"); bounds("owned"); capture("owned")
	await click("hub_pick_miata"); await click("hub_equip"); check(game.profile.stages[0] == 1,"Switching cars lost purchased upgrade")
	var restored := DriverProfile.new(); restored.load_profile()
	check(restored.garage.has(next_car) and restored.vehicle_id == "miata" and restored.stages[0] == 1,"Fresh gameplay loop did not persist")
	game.wager = 10000; game.profile.credits = 37; game.tab = "races"; await frame(); check(game.wager == 37,"Visible wager exceeds current funds")
	game.profile.credits = 100000; game.profile.xp = 20000; game.wager = 0
	game.action("recommend_rival"); game.action("bot_0"); game._process(1.0/60)
	check(not game.recommend_pending and game.selected_opponent == 0,"Late match estimate overrode a manual opponent choice")
	for tab in ["garage","performance","owned","dealer","races","driver","style"]:
		game.tab = tab; await frame(); bounds(tab); capture(tab)
	game.tab = "performance"
	for category in 15:
		game.menu.hub.open_upgrade(category); await frame(); bounds("category %d" % category)
		if not GarageHub.CATEGORY_SLOTS[category].is_empty():
			game.menu.hub.action("upgrade_section_hardware"); await frame(); bounds("components %d" % category)
		if GarageHub.TUNE_KEYS.has(category): game.menu.hub.action("upgrade_section_tune"); await frame(); bounds("tune %d" % category)
	game.menu.hub.open_upgrade(7); game.menu.hub.action("upgrade_section_transmission"); await frame(); bounds("gearboxes"); capture("gearboxes")
	game.menu.hub.action("hub_back"); game.menu.hub.action("hub_test"); await frame(); bounds("test build")
	game.menu.hub.categories = true; game.tab = "garage"
	game.safe_insets = Vector4(18,48,12,32); await frame(); await click("tab_performance"); check(game.tab == "performance","Safe-area touch mapping broken")
	capture("safe_area"); game.safe_insets = Vector4.ZERO
	for trans in ["manual5","seq5","dct6","auto10","drag3"]:
		game.profile.hardware = VehicleBench.fixture(trans); game.profile.stages[4] = 5; game.refresh_car(); game.screen = "garage"
		RosterTest.ready(game); game.start_race(); await frame(); bounds("race "+trans); capture("race_"+trans)
		var state: Dictionary = game.car.telemetry()
		await click("pause"); await click("telemetry"); await click("resume")
		check(game.debug_physics and game.car.telemetry() == state,"Portrait telemetry changed drivetrain state")
		await click("pause"); await click("telemetry"); await click("resume")
		await click("pause"); bounds("pause"); await click("resume")
		var point := Vector2.ZERO
		for control in game.buttons:
			if control.id == "gas": point = game.to_global(control.rect.get_center())
		var e := InputEventScreenTouch.new(); e.index=4; e.position=point; e.pressed=true; game._input(e)
		check(game.gas_input()==1,"Portrait gas touch failed")
		e.pressed=false; e.position=Vector2(1,1); game._input(e); check(game.gas_input()==0,"Touch release outside pedal stuck")
		if game.car.control_mode == "hpattern":
			for control in game.buttons:
				if control.id == "clutch": e.position = game.to_global(control.rect.get_center())
			e.pressed=true; game._input(e); await click("manual_2")
			check(game.car.gear == 2,"Portrait clutch + H gate multitouch failed")
			e.pressed=false; e.position=Vector2(1,1); game._input(e)
		elif game.car.control_mode != "automatic":
			var serial: int = game.car.shift_request_serial
			await click("up",false); check(game.car.shift_request_serial > serial,"Portrait paddle click missed shift input")
		else: check(game.buttons.filter(func(v): return v.id in ["up","down"]).is_empty(),"Automatic has unsupported paddles")
		game.go_garage()
	root.size=Vector2i(844,534); game.tab="garage"; await frame(); bounds("landscape"); capture("landscape")
	root.size=Vector2i(1200,760); await frame(); bounds("desktop"); capture("desktop")
	# Exercise the real menu processing path, not only the estimate worker in isolation.
	RaceAI.cache.clear(); RaceAI.pending.clear(); game.tab="races"; game.set_process(true)
	var measured: Dictionary = {}
	for i in 120:
		await process_frame
		measured = RaceAI.cache.get(JSON.stringify([GameCatalog.opponent(game.event_index,game.selected_opponent,game.profile),402.336]),{})
		if not measured.is_empty(): break
	game.set_process(false)
	check(not measured.is_empty(),"Live race-board estimate remained stuck on Measuring")
	await frame(); capture("live_estimates")
	print("FRESH SAVE / RACE / EARN / UPGRADE / BUY / SWITCH / PORTRAIT / SAFE AREA: ","PASS" if failures==0 else "FAIL"," / ",checks," checks / ",repeat_count," recovery races")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)

