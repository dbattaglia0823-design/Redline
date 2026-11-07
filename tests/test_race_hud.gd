extends SceneTree
var game: Node2D
var failures := 0
var checks := 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
func target(id: String) -> Dictionary:
	for item in game.buttons:
		if item.id==id: return item
	return {}
func touch(id: String,index: int,down: bool = true) -> void:
	var item := target(id)
	check(not item.is_empty(),"Missing HUD target: "+id)
	if item.is_empty(): return
	var e := InputEventScreenTouch.new(); e.index=index; e.pressed=down
	e.position=game.to_global(item.rect.get_center()); root.push_input(e,true)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://validation/race_hud")
	for window in [Vector2i(1200,760),Vector2i(1920,1080),Vector2i(844,390),Vector2i(667,375),Vector2i(390,844)]:
		root.size=window
		for hardware in ["manual5","manual6","seq6","legacy6","dct8","auto10","drag3","drag4"]:
			game.go_garage(); game.profile=DriverProfile.new(); game.profile.hardware=VehicleBench.fixture(hardware)
			game.profile.stages[4]=5; game.refresh_car(); game.career_board.select_series("OPEN"); RosterTest.ready(game); game.start_race()
			await frame()
			var limit := Rect2(Vector2.ZERO,Vector2(game.race_view_size()))
			for i in game.buttons.size():
				var a: Dictionary=game.buttons[i]
				check(limit.encloses(a.rect),"Off-screen HUD control: "+str(a.id)+" / "+str(window)+" / "+hardware)
				if game.is_portrait() or game.race_touch_layout():
					var factor: float=minf(float(window.x)/limit.size.x,float(window.y)/limit.size.y)
					check(minf(a.rect.size.x,a.rect.size.y)*factor>=44.0,"Small touch target: "+str(a.id)+" / "+str(window))
				for j in range(i+1,game.buttons.size()):
					check(not a.rect.intersects(game.buttons[j].rect),"Overlapping HUD targets: "+str(a.id)+" / "+str(game.buttons[j].id)+" / "+str(window)+" / "+hardware)
			var manual: bool=game.car.control_mode=="hpattern"
			var auto: bool=game.car.control_mode=="automatic"
			check(target("up").is_empty()==(manual or auto),"Wrong paddle hardware layout")
			check(target("manual_1").is_empty()!=manual,"H gate does not match installed transmission")
			check(target("clutch").is_empty()==(game.car.has_converter or game.car.transmission_kind=="dct"),"Wrong clutch hardware layout")
			check(target("transbrake").is_empty()!=game.car.has_transbrake,"Wrong transbrake layout")
			check(game.race_hud.elapsed_text.text=="0.000 s","Staging showed a running timer")
			if window==Vector2i(1200,760) and hardware=="manual5":
				var mouse:=InputEventMouseButton.new()
				mouse.button_index=MOUSE_BUTTON_LEFT
				mouse.position=game.to_global(target("gas").rect.get_center())
				mouse.pressed=true; root.push_input(mouse,true)
				check(game.gas_input()==1,"Mouse throttle press missed")
				mouse=mouse.duplicate(); mouse.pressed=false; root.push_input(mouse,true)
				check(game.gas_input()==0,"Mouse throttle stayed held")
			game.countdown=0; game.car.running=true; game.rival.running=true
			game.controls.clear(); touch("gas",0); touch("brake",1)
			check(game.gas_input()==1 and game.brake_input()==1,"Simultaneous thumb pedals failed")
			touch("brake",1,false); check(game.gas_input()==1 and game.brake_input()==0,"Brake release cancelled throttle")
			touch("gas",0,false)
			if manual:
				touch("clutch",1); touch("manual_2",2); check(game.car.gear==2,"Direct H gate selection failed"); touch("clutch",1,false)
			elif not auto:
				game.car.shift_left=0; touch("up",2); check(game.car.gear==2,"Touch paddle input missed")
			game.car.nitrous_remaining=0; await frame()
			check(target("nitrous").get("disabled",false),"Empty nitrous button is active")
			touch("nitrous",3); check(not game.nitrous_input(),"Disabled nitrous accepted a touch")
			game.car.rpm=game.car.redline_rpm-20; game.car.boost=.42; game.car.set_road_state(30,2,game.car.rpm)
			game.feedback.visual_mph=30*Drivetrain.MPH_PER_MPS
			game.feedback.visual_rpm=game.car.rpm
			var before: Dictionary=game.car.telemetry()
			await frame()
			check(game.car.telemetry()==before,"HUD mutated simulation")
			check(game.race_hud.readings.rpm==game.car.rpm and game.race_hud.readings.boost==game.car.boost,"HUD values diverged from solver")
			if hardware=="dct8":
				game.staging.released[0]=true; game.staging.reactions[0]=.2
				game.car.elapsed=3.7; game.car.distance=100; game.rival.distance=102
				await frame()
				check(game.race_hud.elapsed_text.text=="3.500 s","Live ET included reaction time")
				check(game.race_hud.gap_text.text=="-6.6 ft","Deficit readout diverged from lane positions")
				check(is_equal_approx(game.race_hud.progress.value,100.0),"Progress did not match measured distance")
				game.player_finish=14.75; game.finish_hold_left=.4
				await frame()
				check(game.race_hud.elapsed_text.text=="14.550 s","Finish timer did not freeze at measured ET")
				game.player_finish=0; game.finish_hold_left=0
			var first: float=game.race_hud.readings.speed
			touch("race_units",4); await frame()
			check(absf(game.race_hud.readings.speed-first)<.001,"Imperial speed changed unexpectedly")
			game.profile.save(); var restored:=DriverProfile.new(); restored.load_profile()
			check(not restored.metric_speed,"Saved units are not imperial")
			game.action("race_units")
			await frame()
			if hardware in ["manual5","dct8","drag3"]:
				root.get_texture().get_image().save_png("res://validation/race_hud/%dx%d_%s.png"%[window.x,window.y,hardware])
			game.set_race_paused(true); await frame()
			check(target("gas").is_empty() and not target("resume").is_empty() and not game.race_hud.status.visible,"Pause overlay leaked HUD content")
			touch("resume",5); check(not game.paused_race,"Resume touch failed")
			game.profile.forfeit_wager()
	# Needle/shift lights must derive from each build, not from a universal threshold.
	game.car.shift_map.assign([4300.0,5100.0]); game.car.gear=1
	check(game.race_hud.sample().target==4300,"First-gear shift target ignored installed map")
	game.car.gear=2; check(game.race_hud.sample().target==5100,"Gear-specific shift map ignored")
	game.car.gear=0; check(game.race_hud.sample().gear=="N","Neutral label missing")
	game.car.gear=-1; check(game.race_hud.sample().gear=="R","Reverse display fallback missing")
	game.car.gear=1
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame
	print("ADAPTIVE RACE HUD / 5 SIZES / 8 TRANSMISSIONS / TOUCH / UNITS / SAVE / PREVIEW ISOLATION: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
