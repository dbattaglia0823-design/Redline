extends "res://tests/test_main_navigation.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car()
	game.tuning.open(2); await frame()
	var panel: GearboxTuningPanel=game.tuning.gearbox_panel
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions; await frame()
		panel.scroll.ensure_control_visible(panel.rows.ratio_1.slider); await frame()
		var scroll_before:=panel.scroll.scroll_vertical
		var ratios: Array=game.car.gear_ratios.duplicate()
		var shifts: Array=game.car.shift_map.duplicate()
		var handles := {}
		for key in panel.rows:
			if key.begins_with("ratio_"): handles[key]=[panel.rows[key].slider.value,panel.rows[key].slider.min_value,panel.rows[key].slider.max_value,panel.rows[key].slider.get_instance_id()]
		var plans_before:=ShiftPlanner.cache.size()
		var start:=Time.get_ticks_usec()
		for i in 24: panel.apply("ratio_1",float(ratios[1])+(.01 if i%2==0 else .02),true)
		var edit_ms: float=(Time.get_ticks_usec()-start)/1000.0/24
		await frame()
		check(panel.scroll.scroll_vertical==scroll_before,"Ratio edit reset scroll")
		check(game.car.shift_map==shifts,"Ratio edit moved other shift settings")
		check(ShiftPlanner.cache.size()==plans_before,"Ratio edit reran expensive shift optimization")
		for i in ratios.size():
			if i==1: continue
			var slider: HSlider=panel.rows["ratio_%d"%i].slider
			check(is_equal_approx(game.car.gear_ratios[i],ratios[i]),"Ratio edit changed another physical gear")
			check([slider.value,slider.min_value,slider.max_value,slider.get_instance_id()]==handles["ratio_%d"%i],"Another gear slider moved or rebuilt")
		panel.finish_edit(); await frame()
		check(panel.scroll.scroll_vertical==scroll_before,"Saving reset scroll")
		var loaded:=DriverProfile.new(); loaded.load_profile()
		check(loaded.hardware.tune.ratios.size()==game.profile.hardware.tune.ratios.size(),"Save lost gear count")
		for i in loaded.hardware.tune.ratios.size(): check(is_equal_approx(float(loaded.hardware.tune.ratios[i]),float(game.profile.hardware.tune.ratios[i])),"Save lost edited ratio")
		var limits:=TransmissionCatalog.count_limits(game.car.transmission_id)
		var old_count: int=game.car.gear_ratios.size()
		var new_count:=old_count+1 if old_count<limits.y else old_count-1
		panel.apply("gear_count",new_count,true); await frame()
		check(game.car.gear_ratios.size()==new_count,"Gear count did not rebuild rows")
		check(abs(panel.scroll.scroll_vertical-scroll_before)<=1,"Gear-count rebuild reset scroll")
		panel.apply("gear_count",old_count,true); await frame()
		panel.finish_edit()
		print("TUNING ",dimensions," · average ratio edit ",snappedf(edit_ms,.01)," ms")
	# Drag updates immediately, defers disk writes, and keeps neighboring handles fixed.
	root.size=Vector2i(1200,760); await frame()
	var slider: HSlider=panel.rows.ratio_0.slider
	panel.scroll.ensure_control_visible(slider); await frame()
	var other: float=panel.rows.ratio_1.slider.value
	var saved_before:=FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)
	slider.drag_started.emit(); slider.value+=.05
	check(panel.dirty_save and FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)==saved_before,"Drag performed an immediate disk write")
	check(is_equal_approx(game.car.gear_ratios[0],slider.value),"Drag did not update physics immediately")
	slider.drag_ended.emit(true); await frame()
	check(not panel.dirty_save and panel.rows.ratio_1.slider.value==other,"Drag completion moved another slider")
	# Neighbor order constrains only the edited gear; the other gear remains untouched.
	panel.apply("ratio_0",.3,true); await frame()
	check(panel.rows.ratio_1.slider.value==other and game.car.gear_ratios[0]>game.car.gear_ratios[1],"Gear-order validation adjusted other gears")
	for touch in [false,true]:
		slider=panel.rows.ratio_0.slider
		panel.scroll.ensure_control_visible(slider); await frame()
		var scroll_before:=panel.scroll.scroll_vertical
		var before: float=game.car.gear_ratios[0]
		var rect:=slider.get_global_rect()
		var fraction: float=(slider.value-slider.min_value)/(slider.max_value-slider.min_value)
		var point:=Vector2(rect.position.x+8+fraction*(rect.size.x-16),rect.get_center().y)
		var down: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		down.position=point; down.pressed=true
		if touch: down.index=4
		else: down.button_index=MOUSE_BUTTON_LEFT
		root.push_input(down,true)
		var motion: InputEvent=InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
		motion.position=point+Vector2(30,0)
		if touch: motion.index=4
		else: motion.button_mask=MOUSE_BUTTON_MASK_LEFT; motion.relative=Vector2(30,0)
		root.push_input(motion,true)
		var up: InputEvent=down.duplicate(); up.pressed=false; up.position=motion.position
		root.push_input(up,true); await frame()
		check(game.car.gear_ratios[0]>before,"Mouse / touch drag did not update selected ratio")
		check(panel.rows.ratio_1.slider.value==other,"Mouse / touch drag moved another gear")
		check(panel.scroll.scroll_vertical==scroll_before,"Drag reset scroll (%s): %d -> %d"%["touch" if touch else "mouse",scroll_before,panel.scroll.scroll_vertical])
		check(not panel.dirty_save,"Mouse / touch release failed to save")
	for row in panel.rows.values(): check(not row.slider.scrollable,"Tuning wheel changes slider")
	var count_slider: HSlider=panel.rows.gear_count.slider
	var count_before: int=game.car.gear_ratios.size()
	var target_count: int=count_before-1 if count_before==int(count_slider.max_value) else count_before+1
	count_slider.drag_started.emit(); count_slider.value=target_count
	check(game.car.gear_ratios.size()==count_before and panel.rows.gear_count.slider==count_slider,"Gear-count drag rebuilt its own control before release")
	count_slider.drag_ended.emit(true); await frame()
	check(game.car.gear_ratios.size()==target_count and not panel.dirty_save,"Gear-count release did not apply and save")
	game.tuning.action("tt_back")
	check(not panel.dirty_save,"Leaving tuning did not flush pending save")
	game.stop_presentation_audio()
	print("TUNING RESPONSIVENESS / FIXED SLIDERS / SCROLL / SAVE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
