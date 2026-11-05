extends SceneTree
# Deterministic visual fixtures. Speeds/distances are controlled for matched art
# review; existing staging/physics tests cover actual driving and timing.
var game: Node2D
var failures := 0
const OUTPUT := "res://validation/track_environments/"
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUTPUT+name+".png")==OK,"Screenshot failed: "+name)
func prepare(index: int) -> void:
	game.go_garage(); game.profile = DriverProfile.new(); game.profile.xp = 20000
	game.event_index = index; game.selected_opponent = 0; game.wager = 0
	RosterTest.ready(game); game.start_race()
	if game.race_start_pending: game._process(0)
	game.feedback.reset(game.car); game.rival_feedback.reset(game.rival)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	for track in 3:
		prepare(track)
		for phase in ["staging","acceleration","high_speed"]:
			var speed: float = {"staging":0.0,"acceleration":14.0,"high_speed":48.0}[phase]
			var distance: float = {"staging":0.0,"acceleration":24.0,"high_speed":280.0}[phase]
			game.countdown = 1.5 if phase == "staging" else 0.0
			game.car.set_road_state(speed,1 if speed<20 else 5)
			game.rival.set_road_state(speed,1 if speed<20 else 5)
			game.car.distance = distance; game.rival.distance = distance-3 if distance>0 else 0
			game.feedback.visual_distance = distance
			game.feedback.visual_mph = speed*Drivetrain.MPH_PER_MPS
			game.car.throttle = .9 if speed>0 else 0.0
			var before: Dictionary = game.car.telemetry()
			await capture(str(TrackPresentation.spec(track).art)+"_"+phase)
			check(game.car.telemetry()==before,"Rendering mutated drivetrain")
			game.paused_race = true
			game.feedback.update(.1,game.car,true,GameCatalog.spec(game.profile.vehicle_id))
			check(game.feedback.visual_distance==distance,"Paused background drifted")
			game.paused_race = false
		game.car.distance = game.active_distance-10; game.feedback.visual_distance=game.car.distance
		await capture(str(TrackPresentation.spec(track).art)+"_finish")
		game.profile.effects_quality=0; game.feedback.set_quality(0)
		await capture(str(TrackPresentation.spec(track).art)+"_low")
		root.size=Vector2i(390,844)
		await capture(str(TrackPresentation.spec(track).art)+"_portrait")
		root.size=Vector2i(1200,760)
	game.feedback.camera_offset = Vector2(2,2)
	game.feedback.update(.016,game.car,false,GameCatalog.spec(game.profile.vehicle_id),game.race_origins()[0],true)
	check(game.feedback.camera_offset==Vector2.ZERO,"Reduced Motion retained camera shake")
	game.stop_presentation_audio(); await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame
	print("THREE LOCATIONS / STAGING + ACCELERATION + HIGH SPEED / FINISH / LOW / PORTRAIT / IMMUTABLE PHYSICS: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
