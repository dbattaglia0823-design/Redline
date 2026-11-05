extends SceneTree
var game: Node2D
var failures := 0
var rows: Array = []
const OUTPUT := "res://validation/vehicle_motion/"
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func tick(gas: float=1,brake: float=0,spray: bool=false) -> void:
	var c: Drivetrain=game.car
	c.step(1.0/120,gas,brake,0,spray)
	game.feedback.update(1.0/120,c,false,GameCatalog.spec(game.profile.vehicle_id),game.race_origins()[0],game.profile.reduced_motion,6 if game.is_portrait() else 12)
func capture(id: String,phase: String) -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT+id+"_"+phase+".png")==OK,"Capture failed")
	rows.append({"model":id,"phase":phase,"speed_mps":game.car.speed,"pitch":game.feedback.body_pitch,"rear_travel_px":game.feedback.rear_compression,"front_travel_px":game.feedback.front_compression,"smoke":game.feedback.smoke.size(),"backfire":game.feedback.exhaust_glow,"nitrous":game.feedback.nitrous_glow})
func record(id: String) -> void:
	DirAccess.make_dir_recursive_absolute("res://.qa/motion_frames")
	for frame in 60:
		for substep in 4:
			if game.car.upshift_ready(): game.car.shift(1)
			tick(1 if frame<42 else 0,0 if frame<42 else 1)
		game.sync_menu_size(); game.queue_redraw()
		await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.qa/motion_frames/%s_%03d.png"%[id,frame])==OK,"Recording frame failed")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	for id in ["miata","civic_si","gtr","demon"]:
		game.go_garage(); game.profile=DriverProfile.new(); game.profile.credits=10000000; game.profile.xp=100000
		if not game.profile.garage.has(id): game.profile.buy_vehicle(id)
		game.profile.select_vehicle(id); game.event_index=1 if id in ["gtr","demon"] else 0
		game.start_practice(); game.countdown=0; game.car.running=true
		var c: Drivetrain=game.car
		c.gear=1; c.rpm=4000
		for i in 48: tick()
		check(c.speed>0,id+" failed actual launch")
		await capture(id,"launch")
		if "--record" in OS.get_cmdline_user_args(): await record(id)
		# Brake-held burnout on a controlled low-grip surface, same solver.
		var grip: float=c.grip_coefficient
		c.grip_coefficient=.10; c.reset(); c.running=true; c.gear=1; c.rpm=5000
		game.feedback.reset(c)
		for i in 180: tick(1,1)
		check(c.wheelspin>.1 and not game.feedback.smoke.is_empty(),id+" failed actual burnout")
		await capture(id,"burnout")
		game.profile.effects_quality=0; game.feedback.set_quality(0)
		for i in 60: tick(1,1)
		check(game.feedback.smoke.size()<=8,"Low smoke budget")
		await capture(id,"burnout_low")
		game.profile.effects_quality=2; game.feedback.set_quality(2); c.grip_coefficient=grip
		# Controlled fast entry followed by real acceleration and braking steps.
		c.reset(); c.running=true; c.set_road_state(40,4); game.feedback.reset(c)
		for i in 60: tick()
		await capture(id,"high_speed")
		for i in 24: tick(0,1)
		check(game.feedback.body_pitch>0,id+" braking failed to load front")
		await capture(id,"braking")
		# Hot upgraded shift fixture: controlled RPM/load at the shift boundary.
		c.exhaust_stage=2; c.set_road_state(28,3); c.running=true; c.rpm=6000; c.engine_load=.9
		c.last_shift_rpm=6000; c.last_shift_load=.9; c.shift_serial=0
		game.feedback.reset(c); c.shift_serial=2
		game.feedback.update(.016,c,false,GameCatalog.spec(id),game.race_origins()[0])
		check(game.feedback.exhaust_glow>.2,id+" missing hot shift event")
		await capture(id,"upgraded_shift")
		# Nitrous is applied by the actual solver, never an unconditional flame.
		c.set_road_state(28,3); c.rpm=5000; c.running=true; c.shift_left=0; c.clutch_engagement=1
		for i in 360:
			tick(1,0,true)
			if i>24 and c.nitrous_active and game.feedback.nitrous_glow>.65: break
		check(c.nitrous_active and game.feedback.nitrous_glow>.5,id+" nitrous not delivered")
		await capture(id,"nitrous")
		root.size=Vector2i(390,844)
		game.feedback.smoke.clear(); game.feedback.camera_offset=Vector2.ZERO
		await capture(id,"portrait")
		root.size=Vector2i(1200,760)
	var file:=FileAccess.open(OUTPUT+"results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"captures":rows},"\t")); file.close()
	game.stop_presentation_audio(); await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame
	print("FOUR CLASSES / SOLVER LAUNCH + BURNOUT + BRAKING + NITROUS / SHIFT FIXTURE / LOW + PORTRAIT: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
