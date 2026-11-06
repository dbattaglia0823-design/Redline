extends SceneTree
var game: Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
func touch(position: Vector2,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new(); event.index=3; event.position=position; event.pressed=pressed; game._input(event)
func drag(position: Vector2) -> void:
	var event:=InputEventScreenDrag.new(); event.index=3; event.position=position; game._input(event)
func capture(name: String) -> void:
	check(root.get_texture().get_image().save_png("res://validation/gearing_ui/"+name+".png")==OK,"Capture failed")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation/gearing_ui")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.hardware=VehicleBench.fixture("auto10",[]); game.profile.stages[4]=5
	game.refresh_car(); game.tuning.open(); game.tuning.group=TuningSetup.GROUPS.keys().find("Gearbox")
	for view in ["desktop","portrait","landscape_touch"]:
		root.size=Vector2i(390,844) if view=="portrait" else (Vector2i(844,390) if view=="landscape_touch" else Vector2i(1200,760))
		await frame()
		var panel: GearboxTuningPanel=game.tuning.gearbox_panel
		panel.scroll.scroll_vertical=0; await frame()
		check(panel.visible,"Unified panel hidden")
		check(panel.rows.keys()[0]=="gear_count" and panel.rows.keys()[1]=="final_drive" and panel.rows.keys()[2]=="ratio_0","Gearing order wrong")
		for action in game.buttons: check(action.id not in ["tt_gear_prev","tt_gear_next","tt_rows"],"Legacy navigation remained")
		check(panel.rows.has("ratio_9"),"10th gear absent")
		await capture(view+"_top")
		if view=="desktop":
			var mouse_slider: HSlider=panel.rows.final_drive.slider
			var mouse_before: float=game.car.final_drive
			var target:=mouse_slider.get_global_rect().get_center()
			var down:=InputEventMouseButton.new(); down.button_index=MOUSE_BUTTON_LEFT; down.button_mask=MOUSE_BUTTON_MASK_LEFT; down.position=target; down.pressed=true
			Input.parse_input_event(down); await frame()
			var move:=InputEventMouseMotion.new(); move.position=target+Vector2(70,0); move.relative=Vector2(70,0); move.button_mask=MOUSE_BUTTON_MASK_LEFT
			Input.parse_input_event(move); await frame()
			var up:=InputEventMouseButton.new(); up.button_index=MOUSE_BUTTON_LEFT; up.position=move.position; up.pressed=false
			Input.parse_input_event(up); await frame()
			check(absf(game.car.final_drive-mouse_before)>.01 and absf(game.car.final_drive-mouse_slider.value)<.0001,"Mouse slider drag failed")
		# Actual touchscreen buttons and slider drag, through the main input route.
		var plus: Button=panel.rows.final_drive.plus
		var before: float=game.car.final_drive
		touch(plus.get_global_rect().get_center(),true); touch(plus.get_global_rect().get_center(),false); await frame()
		check(absf(game.car.final_drive-before-.01)<.0001,"Touch + failed or double-applied")
		var slider: HSlider=panel.rows.gear_count.slider
		var r:=slider.get_global_rect()
		touch(Vector2(r.position.x+8,r.get_center().y),true)
		drag(Vector2(r.end.x-8,r.get_center().y));
		touch(Vector2(r.end.x-8,r.get_center().y),false); await frame()
		check(game.car.gear_ratios.size()==10 and panel.rows.has("ratio_9"),"Touch count resize failed "+view+" / "+str(game.car.gear_ratios.size()))
		panel.apply("gear_count",3,true); await frame()
		check(game.car.gear_ratios.size()==3 and not panel.rows.has("ratio_3"),"Count decrease left stale rows")
		panel.apply("gear_count",10,true); await frame()
		# Swipe starting on a title, away from horizontal slider capture.
		var start: Vector2=panel.scroll.global_position+Vector2(130,12)*game.scale
		touch(start,true); drag(start-Vector2(0,180)*game.scale); touch(start-Vector2(0,180)*game.scale,false); await frame()
		check(panel.scroll.scroll_vertical>0,"Touch vertical scrolling failed")
		panel.scroll.scroll_vertical=5000; await frame(); await capture(view+"_bottom")
		var last: HSlider=panel.rows.ratio_9.slider
		panel.scroll_velocity=0
		var last_row: VBoxContainer=panel.rows.ratio_9.column
		panel.scroll.scroll_vertical=roundi(last_row.position.y+panel.ratio_box.position.y-panel.scroll.size.y+last_row.size.y+8)
		last.grab_focus(); await frame()
		check(panel.scroll.get_global_rect().intersection(last.get_global_rect()).size.y>=last.get_global_rect().size.y-1,"Last gear cannot be reached visibly: "+view)
		await capture(view+"_gears")
		var old: float=game.car.gear_ratios[9]
		# Native keyboard input is left for the focused HSlider, not global actions.
		last.grab_focus(); var key:=InputEventKey.new(); key.keycode=KEY_RIGHT; key.pressed=true
		Input.parse_input_event(key); await frame()
		var release:=InputEventKey.new(); release.keycode=KEY_RIGHT; release.pressed=false; Input.parse_input_event(release); await frame()
		check(game.car.gear_ratios[9]>old,"Focused slider keyboard adjustment failed")
		var loaded:=DriverProfile.new(); loaded.load_profile()
		check(JSON.stringify(loaded.hardware.tune.ratios)==JSON.stringify(game.profile.hardware.tune.ratios),"UI save/load differs")
		game.tuning.action("tt_page_presets"); await frame(); check(not panel.visible,"Panel leaked onto presets")
		game.tuning.action("tt_page_setup"); await frame()
	# Locked hardware stays visible, with a reason, and cannot mutate physics.
	game.profile.pending_wager={"amount":0}; await frame()
	var panel: GearboxTuningPanel=game.tuning.gearbox_panel
	check(not panel.rows.gear_count.slider.editable and not panel.rows.final_drive.slider.editable,"Active race lock bypassed")
	await capture("active_race_lock")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("UNIFIED GEARBOX UI / ORDER / TOUCH BUTTON + SLIDER / SCROLL / KEYBOARD / RESIZE / SAVE / DESKTOP + MOBILE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
