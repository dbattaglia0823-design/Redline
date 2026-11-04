extends SceneTree
var game: Node2D
var failures:=0
func key(code: Key,pressed: bool=true) -> void:
	var e:=InputEventKey.new(); e.physical_keycode=code; e.pressed=pressed; game._input(e)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car(); game.wager=0; game.selected_opponent=0
	RosterTest.ready(game); game.start_race()
	# No throttle before green; start with an idle engine, then use ordinary shift guidance.
	for i in 361: game._physics_process(1.0/120)
	key(KEY_W)
	for i in 6000:
		if game.car.upshift_ready():
			key(KEY_SHIFT); key(KEY_0+game.car.gear+1); key(KEY_SHIFT,false)
		game._physics_process(1.0/120)
		if i%120==0: game._process(1.0/120)
		if game.screen=="results": break
	key(KEY_W,false)
	if game.screen!="results" or not game.result_win or game.staging.red_light:
		failures+=1; push_error("Fresh starter did not win the opening race using keyboard controls")
	if game.profile.credits!=2650 or game.profile.career_wins[0]!=1:
		failures+=1; push_error("Opening victory did not award expected cash and career progress")
	print("FRESH KEYBOARD RACE: player ",game.player_finish," / rival ",game.rival_finish," / win ",game.result_win)
	game.queue_redraw(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/first_race_result.png")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	quit(0 if failures==0 else 1)
