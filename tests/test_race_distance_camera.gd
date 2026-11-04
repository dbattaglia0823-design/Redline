extends SceneTree
var game: Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car(); game.wager=0; game.selected_opponent=0
	for career in 3:
		for index in 5: check(GameCatalog.opponent(career,index).distance==402.336,"Short career race")
	RosterTest.ready(game); game.start_race()
	check(game.active_distance==402.336 and game.active_contract.distance==402.336,"Actual race does not use quarter mile")
	game.countdown=0; game.car.running=true; game.rival.running=true
	DirAccess.make_dir_recursive_absolute("res://validation/race_camera")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.car.distance=250; game.rival.distance=250
		await frame()
		var together: Array=game.race_origins()
		check(together[0].x==together[1].x,"Cars misaligned with equal distance")
		var scale:=6 if phone else 12
		game.rival.distance=245
		var nearby: Array=game.race_origins()
		check(nearby[1].x==together[0].x-5*scale,"Small gap not proportional")
		game.rival.distance=0
		var behind: Array=game.race_origins()
		check(behind[1].x+420<0,"Slow rival stuck to left edge")
		await frame(); root.get_texture().get_image().save_png("res://validation/race_camera/behind_"+("phone" if phone else "desktop")+".png")
		game.rival.distance=500
		var ahead: Array=game.race_origins()
		check(ahead[1].x>(600 if phone else 1200),"Fast rival stuck to right edge")
		check(ahead[0]==behind[0],"Rival gap moves player camera")
		game.rival.distance=250
		check(game.race_origins()[1].x==together[1].x,"Rival failed to re-enter view")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("QUARTER-MILE CONTRACTS / UNCLAMPED CAMERA / DESKTOP + PHONE: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
