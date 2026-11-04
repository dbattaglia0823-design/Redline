extends SceneTree
var game: Node2D
var failures := 0
func check(ok: bool,msg: String) -> void:
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void: call_deferred("run_checks")
func frame() -> void:
	RosterTest.ready(game)
	if game!=null and game.race_start_pending: game._process(0)
	game.sync_menu_size(); game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void: root.get_texture().get_image().save_png("res://.qa/strip_"+name+".png")
func prepare(index: int = 0) -> void:
	game.go_garage(); game.profile = DriverProfile.new(); game.profile.xp = 20000
	game.event_index=index; game.selected_opponent=0; game.wager=0; game.staging.assisted=true; RosterTest.ready(game); game.start_race()
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://.qa")
	for index in 3:
		prepare(index)
		for remaining in [3.0,1.5,1.0,.5]:
			game.countdown=remaining; await frame(); capture("track%d_amber%.1f" % [index,remaining])
		game.countdown=0; game.car.running=true; game.rival.running=true
		game.car.set_road_state(44,4); game.car.distance=game.active_distance-12; game.rival.distance=game.car.distance-8
		game.feedback.visual_distance=game.car.distance
		var before: Dictionary=game.car.telemetry()
		await frame(); capture("track%d_fast" % index); check(game.car.telemetry()==before,"Facility rendering changed physics")
	prepare(1); game.profile.forfeit_wager(); game.screen="garage"; game.wager=100; RosterTest.ready(game); game.start_race()
	root.size=Vector2i(390,844); await frame(); capture("portrait_tree")
	var position := Vector2.ZERO
	for button in game.buttons:
		if button.id=="staging_assist": position=game.to_global(button.rect.get_center())
	var tap:=InputEventScreenTouch.new(); tap.index=3; tap.position=position; tap.pressed=true; game._input(tap); tap.pressed=false; game._input(tap)
	check(not game.staging.assisted,"Touch staging mode did not change")
	game.controls.hold("test","gas")
	for i in 240:
		game.paused_race=false; game._physics_process(1.0/120)
	check(game.staging.red_light and game.player_reaction<0,"Actual pre-green launch failed to foul")
	await frame(); capture("portrait_red")
	game.controls.hold("brake_test","brake")
	for i in 120: game._physics_process(1.0/120); game.feedback.update(1.0/120,game.car,false,GameCatalog.spec(game.profile.vehicle_id),game.race_origins()[0])
	await frame(); capture("portrait_burnout")
	var old_money: int=game.profile.credits; var old_xp: int=game.profile.xp
	game.controls.release("brake_test")
	for i in 6000:
		game.paused_race=false
		if game.car.upshift_ready(): game.paddle(1)
		game._physics_process(1.0/120)
		if game.screen=="results": break
	check(game.screen=="results" and game.player_finish>0,"Fouled run failed to coast into results")
	await frame(); capture("red_results")
	check(not game.result_win and game.profile.credits==old_money and game.profile.xp==old_xp and game.profile.wins==0 and game.result_bet_return==0,"Red-light pass paid winnings, XP or career progress")
	game.complete_race(); check(game.profile.credits==old_money,"Duplicate foul settlement")
	root.size=Vector2i(1200,760)
	for trans in ["manual5","legacy6","dct6","auto10","drag3"]:
		prepare(1); game.profile.forfeit_wager(); game.screen="garage"; game.profile.hardware=VehicleBench.fixture(trans); game.profile.stages[4]=5
		RosterTest.ready(game); game.start_race(); game.profile.effects_quality=0; await frame(); capture("low_"+trans)
		game.profile.effects_quality=2
	game.car.set_road_state(30,3); game.car.distance=game.active_distance+1; game.feedback.visual_distance=game.car.distance
	game.player_finish=10; game.rival_finish=11; game.rival_trap_speed=91; game.finish_speed=100
	game.staging.reactions.assign([.18,.29]); game.player_reaction=.18; game.staging.released.assign([true,true]); game.complete_race(); await frame(); capture("finish_results")
	check(absf(game.staging.elapsed(game.player_finish)-9.82)<.0001,"Result ET is not beam elapsed time")
	for model in ["civic_si","demon"]:
		prepare(0 if model=="civic_si" else 1); game.go_garage(); game.profile.credits=1000000
		game.profile.buy_vehicle(model)
		if model=="demon":
			for part in 8: game.profile.upgrade(part,GameCatalog.max_stage(part))
		game.refresh_car(); RosterTest.ready(game); game.start_race(); game.countdown=0; game.car.running=true; game.rival.running=true
		game.active_distance=201.168 if model=="civic_si" else 402.336
		game.controls.hold("power_test","gas")
		if model=="demon": game.controls.hold("spray_test","nitrous")
		for i in 360:
			game._physics_process(1.0/120)
			game.feedback.update(1.0/120,game.car,false,GameCatalog.spec(model),game.race_origins()[0])
		await frame(); capture("power_"+model)
		check(game.car.speed>0 and game.car.safety_clamps==0 and game.feedback.smoke.size()<=48,"Power configuration destabilized effects or physics")
		game.profile.effects_quality=0; game.feedback.set_quality(0); await frame(); capture("power_"+model+"_low")
		check(game.feedback.smoke.size()<=8,"Low-quality power launch exceeded smoke budget")
	print("STRIP DAY/NIGHT / TREE / MANUAL START / RED OUTCOME / MOBILE / LIGHTS / RESULTS: ","PASS" if failures==0 else "FAIL")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)
