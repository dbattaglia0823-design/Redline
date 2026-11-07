extends "res://tests/test_main_navigation.gd"

func run() -> void:
	var vehicle:=Drivetrain.new()
	vehicle.configure_vehicle(GameCatalog.spec("miata"))
	vehicle.configure(GameCatalog.blank_stages())
	vehicle.configure_build(GameCatalog.factory_build("miata"),"miata",false)
	var previous:=vehicle.mass()
	for tier in range(1,4):
		var levels:=GameCatalog.blank_stages()
		levels[6]=tier
		vehicle.configure(levels)
		vehicle.configure_build(GameCatalog.factory_build("miata"),"miata",false)
		check(vehicle.mass()<previous,"A brake tier did not reduce vehicle weight")
		var mass:=vehicle.mass()
		vehicle.configure_build(vehicle.hardware,"miata",false)
		check(is_equal_approx(vehicle.mass(),mass),"Brake weight stacked on refresh")
		previous=mass
	check(absf(ImperialUnits.pounds(1000)-2204.6226)<.001,"Weight conversion is incorrect")
	check(absf(ImperialUnits.torque(100)-73.7562)<.001,"Torque conversion is incorrect")
	check(roundi(ImperialUnits.feet(402.336))==1320,"Quarter-mile feet conversion is incorrect")
	check(ImperialUnits.engine_label("2.0L turbo I4")=="122 cu in turbo I4","Displacement conversion is incorrect")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.profile=DriverProfile.new()
	game.profile.reduced_motion=true
	game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/controls-imperial")
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		game.go_garage()
		await frame()
		root.get_texture().get_image().save_png("res://.qa/controls-imperial/garage_%d.png"%dimensions.x)
		await tap("tab_performance",dimensions.x<1000)
		check(game.native_workshop.targets.has("hub_test") and game.native_workshop.targets.has("open_tuning"),"Upgrade menu lacks Test build and Tuning")
		root.get_texture().get_image().save_png("res://.qa/controls-imperial/upgrades_%d.png"%dimensions.x)
		await tap("open_tuning",dimensions.x<1000)
		check(game.tab=="tuning","Upgrade menu Tuning does not open")
		var panel: GearboxTuningPanel=game.tuning.gearbox_panel
		for key in TuningSetup.EXTRA:
			if key=="launch_gear": continue
			check(panel.rows.has(key),"Unified tuning omits "+key)
		check(panel.sections.size()==TuningSetup.GROUPS.size(),"Unified tuning lacks a section")
		for index in game.car.gear_ratios.size(): check(panel.rows.has("ratio_%d"%index),"Unified tuning omits a gear ratio")
		for group in TuningSetup.GROUPS.size():
			game.tuning.group=group
			game.menu_dirty=true
			await frame()
			check(panel.sections.size()==5 and panel.rows.has("boost") and panel.rows.has("clutch_rate"),"Category shortcut removed other tuning settings")
		game.tuning.group=0
		game.menu_dirty=true
		await frame()
		root.get_texture().get_image().save_png("res://.qa/controls-imperial/tuning_%d.png"%dimensions.x)
	game.stop_presentation_audio()
	print("HUB TUNING / ALL SETTINGS / IMPERIAL / BRAKE WEIGHT: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
