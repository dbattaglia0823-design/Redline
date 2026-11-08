extends SceneTree
var game: Node2D
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	game.sync_menu_size(); game.queue_redraw()
	for i in 4: game._process(.2); await process_frame
	await RenderingServer.frame_post_draw
func click(id: String) -> void:
	if id=="tab_performance":
		game.go_garage(); await frame(); id="garage_upgrades"
	var control: Control=game.native_workshop.targets.get(id)
	if is_instance_valid(control):
		var ancestor:=control.get_parent()
		while ancestor!=null and not ancestor is ScrollContainer: ancestor=ancestor.get_parent()
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
			await frame()
	var point:=Vector2(-1,-1)
	for b in game.buttons:
		if b.id==id: point=game.to_global(b.rect.get_center())
	check(point.x>=0,"Missing studio control: "+id)
	var e:=InputEventScreenTouch.new(); e.index=7; e.position=point; e.pressed=true; game._input(e); e.pressed=false; game._input(e)
	await frame()
func capture(name: String) -> void:
	for i in 50: RaceAI.advance_estimates(1000)
	await frame()
	root.get_texture().get_image().save_png("res://.qa/traction_studio/"+name+("_phone" if game.is_portrait() else "_desktop")+".png")
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.credits=1000000; game.profile.xp=20000; game.profile.stages[4]=5; game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/traction_studio")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.go_garage(); await frame(); await click("tab_performance")
		var found: Dictionary={}
		for system in UpgradeStudio.GROUPS.size():
			await click("upgrade_system_%d"%system)
			for id in game.native_workshop.targets:
				if id.begins_with("hub_category_") and game.native_workshop.targets[id].visible: found[id]=true
			await capture("systems_%d"%system)
		check(found.size()==15,"Grouped menu hides a category")
		await click("upgrade_system_0"); await click("hub_category_0"); await click("stage_pick_2")
		var money: int=game.profile.credits; var build:=JSON.stringify(game.profile.hardware); var stages: Array=game.profile.stages.duplicate()
		check(game.menu.hub.preview().peak_horsepower()>game.car.peak_horsepower(),"Selected package preview missing")
		await capture("airflow_preview")
		await click("hub_dyno"); await capture("dyno_preview"); await click("hub_dyno_close")
		check(game.profile.credits==money and JSON.stringify(game.profile.hardware)==build and game.profile.stages==stages,"Preview changed money or vehicle")
		await click("hw_pick_forged"); await capture("internals")
		var preview: Drivetrain=game.menu.hub.studio.candidate()
		var predicted:=JSON.stringify([preview.mass(),preview.peak_horsepower(),preview.mechanical_torque_capacity(),preview.engine_inertia])
		await click("hw_buy")
		check(JSON.stringify([game.car.mass(),game.car.peak_horsepower(),game.car.mechanical_torque_capacity(),game.car.engine_inertia])==predicted,"Installed part differs from preview")
		check(game.profile.credits==money-(0 if build.contains('"forged"') else 2800),"Part purchase cost incorrect")
		await click("hub_back"); await click("hub_category_0")
		check(game.workshop.mode=="hardware" and game.workshop.selected_hardware=="forged","Back lost selected component")
		await click("hub_back"); await click("upgrade_system_1"); await click("hub_category_7")
		await click("tx_pick_sequential_type")
		var candidate: Drivetrain=game.menu.hub.studio.transmission_candidate()
		predicted=JSON.stringify([candidate.mass(),candidate.shift_duration,candidate.input_capacity(),candidate.gear_ratios])
		await capture("gearbox_comparison"); await click("tx_buy")
		check(JSON.stringify([game.car.mass(),game.car.shift_duration,game.car.input_capacity(),game.car.gear_ratios])==predicted,"Gearbox preview does not match actual conversion")
		var factory: String=GameCatalog.factory_build(game.profile.vehicle_id).transmission
		await click("tx_pick_"+factory)
		money=game.profile.credits
		await click("tx_buy")
		check(game.car.transmission_id==factory and game.profile.credits==money,"Factory gearbox was not available for a free reinstall")
		await click("hub_back"); await click("upgrade_system_2"); await click("hub_category_14"); await click("stage_pick_1")
		check(game.menu.hub.preview().mass()<game.car.mass() and game.menu.hub.preview().peak_horsepower()==game.car.peak_horsepower(),"Weight preview fabricates engine power")
		await capture("weight_comparison")
		await click("hub_back"); await click("upgrade_system_2"); await click("hub_category_10")
		var tire_id: String="street_radial" if phone else "drag_slicks"
		await click("hw_pick_"+tire_id)
		var tire_preview: Drivetrain=game.menu.hub.preview()
		var fitted_wheel: String=game.profile.hardware.parts.get("wheels","")
		check(tire_preview.hardware.parts.get("tires")==tire_id and not is_equal_approx(tire_preview.effective_grip(),game.car.effective_grip()),"Slick preview missed grip")
		for step in 80: PerformanceClasses.advance()
		await capture("tire_comparison")
		await click("hw_buy")
		check(game.profile.hardware.parts.get("tires")==tire_id and game.profile.hardware.parts.get("wheels","")==fitted_wheel,"Tire purchase changed wheel equipment")
		await click("hub_back"); await click("hub_category_11")
		if game.workshop.mode!="hardware": await click("hw_slot_0")
		await click("hw_pick_competition_shocks" if phone else "hw_pick_pro_drag_susp")
		for step in 80: PerformanceClasses.advance()
		await capture("suspension_comparison")
		await click("hw_buy")
		await click("hub_back")
		await click("open_tuning")
		check(game.tab=="tuning","Upgrades did not expose central Tuning")
		game.tuning.gearbox_panel.rows["launch_damping"].plus.pressed.emit()
		await frame()
		check(float(game.profile.hardware.tune.get("launch_damping",0))>1,"Main Tuning damping control did not adjust fitted suspension")
		await click("tt_back")
		await click("hub_category_13"); await click("hw_pick_light_wheels")
		await capture("wheel_comparison"); await click("hw_buy")
		check(game.profile.hardware.parts.get("tires")==tire_id and game.profile.hardware.parts.get("wheels")=="light_wheels","Wheel purchase replaced the selected tire")
		await click("hub_back")
	var file:=FileAccess.open("res://.qa/traction_studio_ui_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"note":"All 15 grouped categories, native phone/desktop captures, real touch navigation, preview isolation, installed-versus-preview parity, owned parts, saved selection, gearbox conversions, non-engine comparisons"},"  ")); file.close()
	print("UPGRADE STUDIO UI: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)
