extends SceneTree

var failures := 0
var checks := 0
var game: Node2D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fit(profile: DriverProfile, id: String, slot: String) -> String:
	var quote := profile.upgrade_quote(-1,-1,slot,id)
	return profile.commit_upgrade_quote(-1,-1,slot,id,JSON.stringify(quote))

func configured(profile: DriverProfile) -> Drivetrain:
	var car := Drivetrain.new()
	car.configure_vehicle(GameCatalog.spec(profile.vehicle_id))
	car.configure(profile.stages)
	car.configure_build(profile.hardware,profile.vehicle_id)
	return car

func run() -> void:
	var profile := DriverProfile.new()
	profile.credits=100000
	var factory: String=profile.hardware.transmission
	var options := TransmissionCatalog.type_options(profile.hardware)
	check(options.size()==4 and options.has(factory),"Four transmission families must include the factory box")
	var ets := []
	for i in options.size():
		var id: String=options[i]
		var type: String=TransmissionCatalog.TYPES.keys()[i]
		check(TransmissionCatalog.family(id)==type,"Wrong type card: "+type)
		if id!=factory: check(profile.install_transmission(id).begins_with("Installed"),"Cannot buy "+type)
		var limits := TransmissionCatalog.gear_range(id)
		check(not profile.tune_hardware("gear_count",limits.y+1,false),"Accepted out-of-range gear count")
		check(profile.tune_hardware("gear_count",limits.y),"Cannot select maximum gear count")
		var ratios := TransmissionCatalog.default_ratios(id,profile.hardware.tune)
		ratios[0] = float(ratios[0])+0.08
		check(profile.tune_hardware("ratios",ratios),"Could not tune ratios")
		check(profile.tune_hardware("final_drive",3.71+i*0.05),"Could not tune final drive")
		var car := configured(profile)
		check(car.gear_ratios==ratios and car.gear_ratios.size()==limits.y,"Tuned ratios did not reach drivetrain")
		check(is_equal_approx(car.ratio_for(1),float(ratios[0])*car.final_drive),"Tuned final drive did not reach wheel gearing")
		check(car.shift_map.size()==limits.y-1,"Shift map did not follow gear count")
		var result := VehicleBench.run(GameCatalog.spec(profile.vehicle_id),profile.stages,profile.hardware)
		check(result.quarter_et_s!=null and result.safety_clamps==0,"Quarter-mile simulation failed for "+type)
		ets.append(result.quarter_et_s)
	var funds := profile.credits
	profile=DriverProfile.new()
	profile.load_profile()
	for i in options.size():
		var id: String=options[i]
		check(profile.install_transmission(id).begins_with("Installed") and profile.credits==funds,"Owned transmission charged on switch")
		var car := configured(profile)
		var defaults := TransmissionCatalog.default_ratios(id,profile.hardware.tune)
		check(is_equal_approx(car.final_drive,3.71+i*0.05) and is_equal_approx(car.gear_ratios[0],float(defaults[0])+0.08),"Save/re-equip lost gearbox tuning")
	var before := configured(profile)
	for id in VehicleParts.TRANSMISSION_UPGRADES:
		check(fit(profile,id,id).begins_with("Installed"),"Gearbox upgrade purchase failed: "+id)
	var after := configured(profile)
	check(after.input_capacity()>before.input_capacity() and after.trans_efficiency>before.trans_efficiency and after.shift_duration<before.shift_duration and after._gear_cooling>before._gear_cooling,"Gearbox upgrades did not reach physics")
	var curves := {}
	for id in VehicleParts.INDUCTION_TYPES:
		if id!="": check(fit(profile,id,"induction").begins_with("Installed"),"Induction purchase failed: "+id)
		var car := configured(profile)
		curves[id]=[car.boost_target(1600,1),car.boost_target(4200,1),car.boost_target(car.redline_rpm,1)]
		var result := VehicleBench.run(GameCatalog.spec(profile.vehicle_id),profile.stages,profile.hardware)
		check(result.quarter_et_s!=null and result.safety_clamps==0,"Quarter-mile simulation failed for induction "+id)
	check(curves.roots[0]>curves.centrifugal[0] and curves.centrifugal[0]<curves.centrifugal[2] and curves.turbo_hybrid[0]==0 and curves.turbo_hybrid[2]>curves[""][2],"Induction types did not produce distinct boost curves")
	funds=profile.credits
	for id in VehicleParts.INDUCTION_TYPES:
		check(fit(profile,id,"induction").begins_with("Installed") and profile.credits==funds,"Owned induction charged on switch")
	before=configured(profile)
	for id in VehicleParts.INDUCTION_UPGRADES:
		check(fit(profile,id,id).begins_with("Installed"),"Induction upgrade purchase failed: "+id)
	after=configured(profile)
	check(after.boost_target(after.redline_rpm,1)>before.boost_target(before.redline_rpm,1) and after._spool_scale<before._spool_scale and after.peak_horsepower()>before.peak_horsepower(),"Induction upgrades did not change boost, response and power")
	for id in ["gearset","race_controller","transbrake"]:
		check(not VehicleParts.PARTS.has(id),"Retired upgrade still exists: "+id)
	if DisplayServer.get_name()!="headless": await check_ui()
	print("UPGRADE REDESIGN: ",checks," checks. Transmission ETs ",ets,". ", "PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)

func frame() -> void:
	game.sync_menu_size()
	game.menu_dirty=true
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw

func click(id: String) -> void:
	var control: Button=game.native_workshop.targets.get(id)
	check(is_instance_valid(control) and not control.disabled,"Missing or disabled action: "+id)
	if is_instance_valid(control) and not control.disabled:
		var point := control.get_global_rect().get_center()
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.button_index=MOUSE_BUTTON_LEFT
			event.position=point
			event.pressed=pressed
			root.push_input(event,true)
	await frame()

func check_ui() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		game.profile=DriverProfile.new()
		game.profile.credits=100000
		game.go_garage()
		game.refresh_car()
		game.tab="performance"
		game.menu.hub.open_upgrade(7)
		await frame()
		var targets: Dictionary=game.native_workshop.targets
		check(targets.keys().filter(func(id): return id.begins_with("tx_pick_")).size()==4,"Transmission UI did not expose four type cards")
		check(targets.keys().filter(func(id): return id.begins_with("system_pick_")).size()==VehicleParts.TRANSMISSION_UPGRADES.size(),"Transmission UI omitted upgrade cards")
		await click("tx_pick_automatic_type")
		await click("tx_buy")
		check(game.profile.hardware.transmission=="automatic_type","UI did not buy automatic")
		await click("system_pick_gear_strength")
		await click("hw_buy")
		check(game.profile.hardware.parts.has("gear_strength"),"UI did not install gearbox upgrade")
		await click("system_tuning")
		check(game.tab=="tuning" and game.tuning.gear_slider.has_area(),"Tuning did not open on the gearbox slider")
		var point: Vector2=game.to_global(game.tuning.gear_slider.end-Vector2(12,30))
		for pressed in [true,false]:
			var event := InputEventScreenTouch.new()
			event.index=4
			event.position=point
			event.pressed=pressed
			root.push_input(event,true)
		await frame()
		check(game.car.gear_ratios.size()==10,"Touch slider did not update the live gearbox")
		game.tab="performance"
		game.menu.hub.open_upgrade(5)
		await frame()
		await click("hw_pick_roots")
		await click("hw_buy")
		check(game.profile.hardware.parts.get("induction")=="roots","UI did not buy Roots supercharger")
		await click("system_pick_charge_pressure")
		await click("hw_buy")
		check(game.profile.hardware.parts.has("charge_pressure"),"UI did not install induction upgrade")
