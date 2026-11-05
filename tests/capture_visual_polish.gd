extends SceneTree

const OUTPUT := "res://validation/visual_polish"
var game: Node2D
var resolution: Vector2i

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	game.sync_menu_size()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered := root.get_texture().get_image()
	var image := Image.create(resolution.x,resolution.y,false,rendered.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),(resolution-rendered.get_size())/2)
	var filename := "%s/%s_%dx%d.png"%[OUTPUT,label,resolution.x,resolution.y]
	if image.save_png(filename)!=OK: push_error("Could not save "+filename)

func settle() -> void:
	for i in 18:
		game._process(1.0/60)
		await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for dimensions in [Vector2i(1920,1080),Vector2i(390,844),Vector2i(844,390)]:
		resolution=dimensions
		root.size=dimensions
		game.profile=DriverProfile.new()
		game.profile.credits=120000
		game.profile.xp=2500
		game.profile.buy_vehicle("civic_si",false)
		game.refresh_car()
		RosterTest.ready(game)
		game.go_garage()
		await settle()
		await capture("garage")
		game.action("tab_performance")
		await settle()
		await capture("upgrades")
		game.action("hub_category_0")
		await settle()
		await capture("upgrade_detail")
		game.action("tab_dealer")
		game.action("shop_class_E")
		await settle()
		await capture("dealership")
		game.action("tab_style")
		game.action("custom_pick_2")
		await settle()
		await capture("customization")
		game.action("tab_races")
		game.action("open_championships")
		await settle()
		await capture("career")
		game.go_garage()
		game.career_board.active=false
		game.selected_opponent=0
		game.event_index=1 if dimensions==Vector2i(844,390) else 0
		game.profile.hardware=VehicleBench.fixture("legacy6")
		game.refresh_car()
		RosterTest.ready(game)
		game.start_race()
		if game.screen!="race":
			push_error("Race did not start: "+game.toast)
			quit(1)
			return
		for i in 190:
			game._physics_process(1.0/120)
			game._process(1.0/120)
		await capture("staging")
		game.input_override=Vector2(1,-1)
		var launched := false
		var driving := false
		var finished := false
		for i in 10800:
			if game.screen!="race": break
			if game.car.shift_recommended(): game.paddle(1)
			game._physics_process(1.0/120)
			game._process(1.0/120)
			if not launched and game.staging.released[0]:
				launched=true
				await capture("launch")
			if not driving and game.car.speed>25:
				driving=true
				await capture("racing")
			if not finished and game.finish_hold_left>0:
				finished=true
				await capture("finish")
		game.input_override=Vector2(-1,-1)
		if game.screen!="results":
			push_error("Race did not complete")
			quit(1)
			return
		await settle()
		await capture("results")
	await capture_roster()
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	quit()

func capture_roster() -> void:
	resolution=Vector2i(1920,1080)
	root.size=resolution
	game.go_garage()
	await settle()
	game.hide()
	var board := Control.new()
	root.add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("081521")
	board.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns=6
	grid.position=Vector2(14,14)
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",4)
	board.add_child(grid)
	for id in GameCatalog.CAR_IDS:
		var tile := AutomotiveUI.column(grid,0)
		tile.custom_minimum_size.x=188
		var view := VehiclePreview.new()
		tile.add_child(view)
		view.configure(game,id,game.menu.dealer.factory(id),VehicleAppearance.normalize({},2),false,101)
		var label := AutomotiveUI.label(str(GameCatalog.spec(id).name),13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.y = 36
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(label)
	await capture("roster")
	board.queue_free()
