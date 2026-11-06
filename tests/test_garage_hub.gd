extends SceneTree
var game: Node2D
var failures := 0
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
	game.profile = DriverProfile.new(); game.profile.credits = 100000; game.refresh_car()
	var h: GarageHub = game.menu.hub
	await frame()
	h.action("hub_owned"); await frame()
	check(game.buttons.filter(func(v): return str(v.id).begins_with("hub_pick_")).size() == 1,"Unowned cars shown")
	game.profile.buy_vehicle("aster"); game.profile.upgrade(0,2); game.refresh_car(); h.action("hub_owned"); await frame()
	var hp: int = game.car.peak_horsepower(); h.action("hub_pick_kaze"); h.action("hub_equip"); h.action("hub_pick_aster"); h.action("hub_equip")
	check(game.car.peak_horsepower() == hp and game.profile.stages[0] == 2,"Owned build changed on switch")
	h.action("hub_upgrades"); await frame()
	var found: Dictionary = {}
	for system in UpgradeStudio.GROUPS.size():
		h.action("upgrade_system_%d" % system); await frame()
		for item in game.buttons:
			if str(item.id).begins_with("hub_category_"): found[item.id] = true
	check(h.categories and found.size() == 15,"Grouped systems omit existing categories")
	var money: int = game.profile.credits; var snapshot := JSON.stringify(game.profile.hardware)
	for i in 15:
		h.open_upgrade(i); await frame()
		check(game.workshop.category_slots == GarageHub.CATEGORY_SLOTS[i],"Category exposes unrelated components")
		check(game.buttons.filter(func(v): return str(v.id).begins_with("tab_") or str(v.id).begins_with("work_") or str(v.id).begins_with("hub_category_")).is_empty(),"Background or duplicate menus remain interactive")
		h.back(); await frame()
		check(h.categories and game.profile.credits == money and JSON.stringify(game.profile.hardware) == snapshot,"Closing category changed data or lost overview")
	h.action("hub_category_0"); h.action("upgrade_section_hardware"); game.workshop.action("hw_pick_forged"); await frame()
	check(game.profile.credits == money and JSON.stringify(game.profile.hardware) == snapshot,"Preview mutated build")
	h.action("hub_category_2"); h.action("upgrade_section_hardware"); game.workshop.action("hw_pick_headers"); await frame()
	check(h.preview().peak_horsepower() > game.car.peak_horsepower(),"Flow upgrade did not change dyno")
	h.action("hub_dyno"); await frame()
	for point in GarageHub.curve(h.preview()):
		check(absf(point.y-point.z*point.x/7127.0) < 0.001,"Dyno HP calculation mismatch")
	DirAccess.make_dir_recursive_absolute("res://.qa")
	root.get_texture().get_image().save_png("res://.qa/garage_dyno.png")
	h.back(); h.back(); check(h.categories and h.selected == 2,"Back lost category")
	h.back(); await frame(); root.get_texture().get_image().save_png("res://.qa/garage_redesign.png")
	print("GARAGE / OWNED BUILDS / DYNO / PREVIEW / BACK: ","PASS" if failures == 0 else "FAIL")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)
