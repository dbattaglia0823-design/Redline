extends SceneTree
var failures := 0
var rows: Array = []
var game: Node2D
func check(ok: bool,msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile = DriverProfile.new(); game.profile.credits = 10000000; game.profile.xp = 10000; game.refresh_car()
	var p: DriverProfile = game.profile
	var showroom: DealershipView = game.menu.dealer
	check(GameCatalog.CAR_IDS.size() == 30,"Roster incomplete")
	for id in GameCatalog.CAR_IDS:
		var s := GameCatalog.spec(id)
		var c := showroom.factory(id)
		var b := GameCatalog.factory_build(id)
		check(c.transmission_id == b.transmission and c.drivetrain == s.drive,"Factory hardware or drive mismatch: "+id)
		var measured := VehicleBench.run(s,GameCatalog.blank_stages(),b)
		check(measured.quarter_s != null and measured.safety_clamps == 0,"Invalid factory performance: "+id)
		var ai := showroom.estimate(id)
		check(float(ai.time) < 40.0 and int(ai.clamps) == 0 and int(ai.hp) == c.peak_horsepower(),"Factory AI or displayed horsepower mismatch: "+id)
		var modified := Drivetrain.new(); modified.configure_vehicle(s); modified.configure([1,0,0,0,0,0,0,0]); modified.configure_build(b,id,false)
		check(modified.peak_horsepower() > c.peak_horsepower(),"Engine upgrade disconnected: "+id)
		rows.append({"name":s.name,"brand":s.brand,"unlock_level":s.get("unlock_level",1),"ai_quarter_s":ai.time,"vehicle":id,"price":s.price,"hp":c.peak_horsepower(),"torque_nm":GarageHub.peak_torque(c),"mass":c.mass(),"transmission":c.transmission_id,"quarter_s":measured.quarter_s,"mph":measured.trap_mph})
		if id != "miata":
			var cash: int = p.credits; var active: String = p.vehicle_id
			check(p.buy_vehicle(id,false) and p.credits == cash-int(s.price) and p.vehicle_id == active,"Unequipped purchase failed: "+id)
			check(not p.buy_vehicle(id,false) and p.credits == cash-int(s.price),"Duplicate purchase charged: "+id)
		check(p.select_vehicle(id),"Cannot equip owned car: "+id)
		p.install_hardware("ecu"); p.tune_hardware("redline",float(s.get("redline",7600)))
		game.refresh_car()
		check(game.car.redline_rpm == float(s.get("redline",7600)),"ECU changed factory limiter unexpectedly: "+id)
	var restored := DriverProfile.new(); restored.load_profile()
	check(restored.garage.size() == 30 and restored.credits == p.credits,"Collection save lost ownership or money")
	for id in GameCatalog.CAR_IDS:
		restored.select_vehicle(id)
		check(restored.hardware.parts.get("ecu") == "ecu","Per-car parts lost: "+id)
	var locked := DriverProfile.new(); locked.credits = 4000000
	check(not locked.buy_vehicle("chiron") and locked.credits == 4000000,"Progression lock bypassed")
	check(GameCatalog.engine_class("supra_gr")=="B" and GameCatalog.engine_class("mustang")=="A" and GameCatalog.engine_class("camaro")=="A","Dealer must group cars by engine tier regardless of price")
	check(GameCatalog.spec("supra_gr").price==49990 and GameCatalog.spec("mustang").price==42495 and GameCatalog.spec("camaro").price==37295,"Reference trim prices changed")
	var seen: Array=[]
	for letter in PerformanceClasses.ORDER:
		showroom.enter_class(letter)
		check(not showroom.filtered().is_empty(),"Empty class: "+letter)
		check(showroom.filtered().all(func(id): return GameCatalog.engine_class(id)==letter),"Wrong cars in class: "+letter)
		seen.append_array(showroom.filtered())
	check(seen.size()==30,"Class selection omitted cars")
	var competitive := VehicleBench.run(GameCatalog.spec("gr86"),[3,3,3,3,3,3,3,0],GameCatalog.factory_build("gr86"))
	var exotic := VehicleBench.run(GameCatalog.spec("r8"),GameCatalog.blank_stages(),GameCatalog.factory_build("r8"))
	check(float(competitive.quarter_s) < float(exotic.quarter_s),"Affordable upgraded car cannot compete with stock premium car")
	showroom.enter_class("E"); showroom.select_edge(false); showroom.navigate(1)
	check(GameCatalog.CAR_IDS[game.dealer_index]==showroom.filtered()[1],"Keyboard-style browsing failed")
	showroom.enter_class("D"); game.tab = "dealer"; game.dealer_index = GameCatalog.CAR_IDS.find("gr86"); showroom.page = 0
	await frame(); DirAccess.make_dir_recursive_absolute("res://.qa"); root.get_texture().get_image().save_png("res://.qa/dealership_redesign.png")
	showroom.details = true; await frame(); root.get_texture().get_image().save_png("res://.qa/dealership_details.png")
	var key := InputEventKey.new(); key.physical_keycode = KEY_ESCAPE; key.pressed = true; game._input(key)
	check(not showroom.details,"Escape did not close factory details")
	key.physical_keycode = KEY_RIGHT; game._input(key)
	check(game.dealer_index == GameCatalog.CAR_IDS.find(showroom.filtered()[posmod(showroom.filtered().find("gr86")+1,showroom.filtered().size())]),"Keyboard right did not browse dealer vehicles")
	showroom.details = false; game.tab = "owned"; game.menu.hub.owned_page = 2
	await frame()
	check(game.buttons.filter(func(v): return str(v.id).begins_with("hub_pick_")).size() == 4,"Owned collection pagination broken")
	var file := FileAccess.open("res://validation/dealership_metrics.json",FileAccess.WRITE); file.store_string(JSON.stringify({"failures":failures,"vehicles":rows,"budget_built_quarter_s":competitive.quarter_s,"flagship_stock_quarter_s":exotic.quarter_s},"\t")); file.close()
	print("DEALERSHIP / 30 FACTORY BUILDS / FILTERS / PURCHASES / SAVES: ","PASS" if failures == 0 else "FAIL")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures == 0 else 1)


