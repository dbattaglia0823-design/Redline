extends SceneTree
var game: Node2D
var failed:=false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failed=true; push_error(message)
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
func tap(id: String, touch: bool) -> void:
	if id=="tab_performance":
		game.go_garage(); await frame(); id="garage_upgrades"
	elif id=="tab_style" and game.tab=="garage": id="garage_customize"
	for b in game.buttons:
		if b.id!=id: continue
		var point: Vector2=game.to_global(b.rect.get_center())
		for pressed in [true,false]:
			var event: InputEvent=InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
			event.position=point; event.pressed=pressed
			if not touch: event.button_index=MOUSE_BUTTON_LEFT
			root.push_input(event,true)
		await frame()
		return
	check(false,"Missing "+id)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://.qa/navigation")
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390),Vector2i(667,375)]:
		root.size=dimensions
		game.go_garage()
		await create_timer(.33).timeout
		await frame()
		var nav: Array=game.buttons.filter(func(b): return str(b.id).begins_with("tab_"))
		check(nav.map(func(b): return b.id)==["tab_garage","tab_races","tab_dealer","tab_driver"],"Dock order or hit targets changed")
		if nav.size()==4: check(nav[1].rect.get_center().x<nav[2].rect.get_center().x,"Dealer is not to the right of Race")
		for id in ["garage_upgrades","garage_customize","hub_owned"]:
			check(game.native_workshop.targets.has(id),"Missing parent-screen Garage action "+id)
		root.get_texture().get_image().save_png("res://.qa/navigation/garage_%d.png"%dimensions.x)
		await tap("hub_owned",dimensions.x<1000)
		check(game.tab=="owned","Change Car did not open collection")
		await tap("tab_style",dimensions.x<1000)
		check(game.tab=="style","Customize route was lost")
		await tap("tab_performance",dimensions.x<1000)
		check(game.tab=="performance","Upgrade did not open")
		await tap("tab_races",dimensions.x<1000)
		check(game.tab=="races" and game.career_board.picker,"Race did not open Championships")
		await create_timer(.33).timeout
		await frame()
		root.get_texture().get_image().save_png("res://.qa/navigation/race_%d.png"%dimensions.x)
		await tap("tab_dealer",dimensions.x<1000)
		check(game.tab=="dealer","Dealership did not open")
		await tap("tab_driver",dimensions.x<1000)
		check(game.tab=="driver","Profile did not open")
	game.stop_presentation_audio()
	print("MAIN NAVIGATION: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
