extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(game: Node2D, filename: String) -> void:
	game.sync_menu_size()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/race_hud/"+filename+".png")

func run() -> void:
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://validation/race_hud")
	for window in [Vector2i(1200,760),Vector2i(844,390),Vector2i(390,844)]:
		root.size=window
		game.go_garage()
		game.profile=DriverProfile.new()
		game.profile.hardware=VehicleBench.fixture("legacy6")
		game.profile.stages[7]=1
		game.refresh_car()
		RosterTest.ready(game)
		game.start_race()
		var suffix: String={1200:"desktop",844:"landscape",390:"phone"}[window.x]
		for i in 260: game._physics_process(1.0/120)
		await capture(game,"staging_"+suffix)
		var press:=InputEventKey.new()
		press.physical_keycode=KEY_W
		press.pressed=true
		game._input(press)
		for i in 720:
			if game.car.shift_recommended(): game.paddle(1)
			game._physics_process(1.0/120)
			game.feedback.update(1.0/120,game.car,false,GameCatalog.spec(game.profile.vehicle_id),game.race_origins()[0])
		await capture(game,"after_"+suffix)
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	quit()
