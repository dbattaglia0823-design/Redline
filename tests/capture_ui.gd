extends SceneTree

var game: Node2D
func _initialize() -> void: call_deferred("capture")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 4:
		game._process(.2); await process_frame
	await RenderingServer.frame_post_draw
func capture() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.profile = DriverProfile.new(); game.refresh_car()
	var folder := "res://validation/ui_before" if "--before" in OS.get_cmdline_user_args() else "res://validation/ui_after"
	DirAccess.make_dir_recursive_absolute(folder)
	for portrait in [false,true]:
		root.size = Vector2i(390,844) if portrait else Vector2i(1200,760)
		for tab in ["garage","performance","races"]:
			game.tab = tab; game.menu.hub.categories = true
			await frame()
			for i in 90: RaceAI.advance_estimates(1000)
			await frame()
			root.get_texture().get_image().save_png(folder+"/"+tab+("_mobile" if portrait else "_desktop")+".png")
		game.tab = "performance"; await frame(); game.menu.hub.open_upgrade(0); await frame()
		root.get_texture().get_image().save_png(folder+"/upgrade"+("_mobile" if portrait else "_desktop")+".png")
	game.stop_presentation_audio(); await create_timer(.12).timeout
	game.queue_free(); await process_frame; await process_frame
	quit()
