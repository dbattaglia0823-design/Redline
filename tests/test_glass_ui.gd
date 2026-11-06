extends SceneTree

var game: Node2D
var failures := 0
var checks := 0
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	game.sync_menu_size(); game.queue_redraw()
	for i in 4:
		game._process(.2); await process_frame
	await RenderingServer.frame_post_draw
func click(id: String,touch: bool = false) -> void:
	var found := false
	for item in game.buttons:
		if item.id != id: continue
		var point: Vector2 = game.to_global(item.rect.get_center())
		if touch:
			var e := InputEventScreenTouch.new(); e.index=3; e.position=point; e.pressed=true; game._input(e); e.pressed=false; game._input(e)
		else:
			var e := InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_LEFT; e.position=point; e.pressed=true; game._input(e); e.pressed=false; game._input(e)
		found=true; break
	check(found,"Missing action "+id); await frame()
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode=code; e.pressed=true; game._input(e)
func audit(label: String) -> void:
	var canvas := Rect2(Vector2.ZERO,Vector2(game.get_window().content_scale_size))
	var ids: Dictionary = {}
	for i in game.buttons.size():
		var a: Dictionary = game.buttons[i]
		check(canvas.encloses(a.rect),label+": out of bounds "+a.id)
		check(not ids.has(a.id),label+": duplicate target "+a.id); ids[a.id]=true
		if game.is_portrait(): check(a.rect.size.y >= 64,label+": small touch target "+a.id)
		for j in range(i+1,game.buttons.size()): check(not a.rect.intersects(game.buttons[j].rect),label+": targets overlap "+a.id+" / "+game.buttons[j].id)
	if game.dock.visible:
		check(game.dock.row is HBoxContainer,"Floating navigation lost its responsive container")
		for i in game.dock.items.size():
			var item: Control = game.dock.items[i]
			for entry in game.buttons:
				if entry.id == "tab_"+GlassDock.TABS[i][0]:
					check(item.get_global_rect().has_point(game.to_global(entry.rect.get_center())),"Native dock and hit target disagree")
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car()
	var ink := LiquidGlass.PALETTE.ink.srgb_to_linear()
	var primary := LiquidGlass.PALETTE.primary.srgb_to_linear()
	var light := ink.r*.2126+ink.g*.7152+ink.b*.0722
	var dark := primary.r*.2126+primary.g*.7152+primary.b*.0722
	check((light+.05)/(dark+.05)>=4.5,"Primary label contrast is below 4.5:1")
	for dimensions in [Vector2i(1200,760),Vector2i(1440,900),Vector2i(390,844),Vector2i(360,780),Vector2i(844,390)]:
		root.size=dimensions
		for tab in ["garage","performance","owned","races","dealer","driver","style"]:
			game.tab=tab; game.menu.hub.categories=true; await frame(); audit(str(dimensions)+tab)
			if tab == "garage":
				check(game.buttons.filter(func(v): return v.id in ["hub_upgrades","hub_customize"]).is_empty(),"Garage duplicated navigation actions")
				check(game.buttons.filter(func(v): return v.id in ["hub_owned","race_menu"]).size()==2,"Garage lost car selection or race entry")
				await click("tab_performance",game.is_portrait()); check(game.tab=="performance","Dock upgrades entry failed")
				await click("tab_style",game.is_portrait()); check(game.tab=="style","Dock customization entry failed")
				game.tab="garage"; await frame()
		game.tab="performance"
		for category in 15:
			game.menu.hub.open_upgrade(category); await frame(); audit("sheet %d" % category)
			check(not game.dock.visible,"Dock remains over the modal")
			check(game.buttons.filter(func(v): return str(v.id).begins_with("tab_")).is_empty(),"Modal lets background navigation receive touches")
			if not GarageHub.CATEGORY_SLOTS[category].is_empty():
				game.action("upgrade_section_hardware"); await frame(); audit("parts %d" % category)
			if GarageHub.TUNE_KEYS.has(category):
				game.action("upgrade_section_tune"); await frame(); audit("tuning %d" % category)
			game.action("hub_back"); await frame()
		game.menu.hub.open_upgrade(7); game.action("upgrade_section_transmission"); await frame()
		for filter in 4:
			game.action("tx_filter_%d" % filter); await frame(); audit("gearbox family")
		game.action("hub_dyno"); await frame(); audit("dyno")
		check(not game.dock.visible,"Dock covers expanded graph")
		game.action("hub_dyno_close"); game.action("hub_back")
	# A disabled purchase cannot charge or install through the real pointer path.
	root.size=Vector2i(390,844); game.profile.credits=0; game.tab="performance"; game.menu.hub.open_upgrade(0); game.action("upgrade_section_basic"); await frame()
	var original: Array = game.profile.stages.duplicate()
	await click("install_0_1",true)
	check(game.profile.credits==0 and game.profile.stages==original,"Disabled purchase changed save")
	game.profile.credits=100000; await frame()
	var hardware := JSON.stringify(game.profile.hardware); var hp: int=game.car.peak_horsepower()
	await click("stage_pick_2",true)
	check(game.profile.stages==original and JSON.stringify(game.profile.hardware)==hardware and game.car.peak_horsepower()==hp,"Preview mutated the installed vehicle")
	await click("hub_dyno",true)
	check(game.menu.hub.preview().peak_horsepower()>hp,"Dyno preview disconnected")
	for point in GarageHub.curve(game.menu.hub.preview()): check(absf(point.y-point.x*point.z/7127.0)<.001,"Dyno fabricated a power sample")
	await click("hub_dyno_close",true); await click("install_0_2",true)
	check(game.profile.stages[0]==2 and game.profile.credits==97900,"Touch purchase did not charge exactly once")
	game.action("hub_back"); game.tab="driver"; await frame(); await click("reduced_motion",true)
	var restored := DriverProfile.new(); restored.load_profile()
	check(restored.reduced_motion and restored.stages[0]==2,"Motion preference broke save compatibility")
	check(game.glass.reduced_motion,"Reduced motion not applied")
	game.tab="races"; game.wager=0; await frame(); audit("mobile wager")
	for entry in game.buttons:
		if entry.id != "bet_slider": continue
		var e := InputEventScreenTouch.new(); e.index=2; e.position=game.to_global(entry.rect.get_center()); e.pressed=true; game._input(e)
		var drag := InputEventScreenDrag.new(); drag.index=2; drag.position=game.to_global(Vector2(entry.range.y,entry.rect.get_center().y)); game._input(drag)
		e.pressed=false; e.position=Vector2.ZERO; game._input(e)
	check(game.wager==500 and game.dragging_wager=="","Phone wager slider failed to drag/release")
	game.wager=0; game.tab="garage"; await frame(); key(KEY_TAB)
	var focused: String=game.glass.focused
	check(focused!="","Tab failed to focus an action"); key(KEY_ENTER); await frame()
	check(game.glass.focused=="","Keyboard selection failed to activate")
	key(KEY_F6); await frame(); check(game.glass.legacy,"Development comparison failed")
	key(KEY_F6); await frame(); check(not game.glass.legacy,"Could not restore glass theme")
	game.tab="garage"; game.safe_insets=Vector4(18,48,12,32); await frame(); audit("safe area")
	await click("tab_performance",true); check(game.tab=="performance","Safe-area action mapping failed")
	game.profile.effects_quality=0; game.menu.hub.open_upgrade(0); await frame()
	check(game.glass.backdrop==null,"Low quality still allocates blur")
	var style_count: int=game.glass.styles.size()
	for i in 60: await frame()
	check(game.glass.styles.size()==style_count,"Idle UI grows its style cache")
	var result := {"passed":failures==0,"checks":checks,"window_sizes":5,"categories":15,"coverage":"unique nonoverlapping actions, native dock mapping, modal isolation, all parts/tuning families, mouse/touch purchase, preview isolation, actual dyno samples, mobile slider, keyboard focus, save migration, reduced motion, comparison toggle, safe area, low-cost fallback, bounded styles"}
	var file := FileAccess.open("res://validation/glass_ui_results.json",FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	print("LIQUID GLASS UI: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	call_deferred("quit",0 if failures==0 else 1)
