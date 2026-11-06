extends "res://tests/test_run_analysis.gd"
var game: Node2D
func _initialize() -> void: call_deferred("run_ui")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
func snapshot(name: String) -> void:
	check(root.get_texture().get_image().save_png("res://validation/test_analysis/"+name+".png")==OK,"Capture failed")
func touch(position: Vector2,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new(); event.index=4; event.position=position; event.pressed=pressed; game._input(event)
func drag(position: Vector2) -> void:
	var event:=InputEventScreenDrag.new(); event.index=4; event.position=position; game._input(event)
func run_ui() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation/test_analysis")
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.hardware=VehicleBench.fixture("manual5",["ecu","turbo_hybrid","boost_control","lsd","clutch_twin"]); game.profile.stages[4]=5; game.refresh_car()
	RunArchive.add(game.profile.test_runs,"miata",simulated("miata","manual5",3.55,3000))
	RunArchive.add(game.profile.test_runs,"miata",simulated("miata","manual5",4.10,5000,.55))
	game.profile.save(); game.tuning.open(); game.tuning.page="results"
	for view in ["desktop","portrait","landscape"]:
		root.size=Vector2i(390,844) if view=="portrait" else (Vector2i(844,390) if view=="landscape" else Vector2i(1200,760))
		game.tuning.details=false; await frame()
		var panel: TestResultsPanel=game.tuning.results_panel
		check(panel.visible and not panel.b.is_empty(),"A/B results missing")
		check(panel.content.size.x<=panel.size.x+1,"Results overflow horizontally: "+view)
		await snapshot(view+"_slip")
		var old: int=panel.b.id; var button: Button=panel.targets.tt_run_b
		touch(button.get_global_rect().get_center(),true); touch(button.get_global_rect().get_center(),false); await frame()
		check(panel.b.id!=old,"Touch run selection failed")
		panel.index_b=1; panel.cached_state=""; await frame()
		var analysis: Button=panel.targets.tt_details
		touch(analysis.get_global_rect().get_center(),true); touch(analysis.get_global_rect().get_center(),false); await frame()
		check(game.tuning.details and panel.plots.size()==2,"Analysis graphs unavailable")
		var plot: TelemetryPlot=panel.plots[0]
		var point:=plot.get_global_rect().get_center()
		touch(point,true); drag(point+Vector2(plot.size.x*.2,0)*game.scale); touch(point+Vector2(plot.size.x*.2,0)*game.scale,false); await frame()
		check(panel.cursor_time>0 and game.tuning.cursor>0,"Graph touch scrub failed")
		await snapshot(view+"_graphs")
		panel.scroll.scroll_vertical=100000; await frame(); await snapshot(view+"_shift_data")
		# Every numeric tuning group shares the same native slider interaction.
		game.tuning.page="setup"
		for group in TuningSetup.GROUPS.size():
			game.tuning.group=group; await frame()
			var controls: GearboxTuningPanel=game.tuning.gearbox_panel
			check(controls.visible and not panel.visible,"Tuning/results visibility wrong")
			check(not controls.rows.is_empty(),"Empty numeric group")
			if TuningSetup.GROUPS.keys()[group]=="Launch":
				var row: Dictionary=controls.rows.launch_rpm; var before: float=game.car.launch_rpm
				touch(row.plus.get_global_rect().get_center(),true); touch(row.plus.get_global_rect().get_center(),false); await frame()
				check(game.car.launch_rpm>before,"Launch slider button did not reach physics")
				await snapshot(view+"_launch_controls")
			for key in controls.rows.keys():
				if not controls.rows.has(key) or controls.reason(key)!="": continue
				var before_value: float=controls.current(key)
				var limits:=controls.bounds(key); var step: float=controls.rows[key].slider.step
				var requested:=before_value-step if before_value>limits.x+step*.5 else before_value+step
				controls.apply(key,requested,true); await frame()
				check(absf(controls.current(key)-before_value)>.00001,"Numeric control ignored: "+key)
		game.tuning.page="results"; game.tuning.details=false
	var saved:=DriverProfile.new(); saved.load_profile()
	check(RunArchive.history(saved.test_runs,"miata",402.336).runs.size()==2,"Comparison reload lost runs")
	game.profile=saved; game.tuning.open(); game.tuning.page="results"; await frame()
	check(game.tuning.last.metrics.quarter_s!=null,"Reload lost displayed results")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("RUN ANALYSIS UI / A+B / TOUCH SCRUB / SLIDERS / DESKTOP + MOBILE / RELOAD: ",checks," checks; ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
