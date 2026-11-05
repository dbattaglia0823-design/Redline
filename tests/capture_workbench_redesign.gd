extends SceneTree

const OUTPUT := "res://validation/workbench_redesign"
var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	for i in 12:
		PerformanceClasses.advance()
		RaceAI.advance_estimates(1200)
		game._process(.025)
		await process_frame
	game.sync_menu_size()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var rendered:=root.get_texture().get_image()
	var image:=Image.create(root.size.x,root.size.y,false,rendered.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),(root.size-rendered.get_size())/2)
	var filename:="%s/%s_%dx%d.png"%[OUTPUT,label,root.size.x,root.size.y]
	if image.save_png(filename)!=OK: push_error("Could not save "+filename)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		game.profile=DriverProfile.new()
		game.profile.credits=42000
		game.profile.xp=1600
		game.profile.championship_wins={"E":9}
		game.refresh_car()
		RosterTest.ready(game)
		game.go_garage()
		await capture("garage")
		game.action("tab_performance")
		game.native_workshop.catalog_filter=-1
		await capture("parts_index")
		game.action("hub_category_0")
		game.action("stage_pick_2")
		await capture("engine_comparison")
		game.action("hub_back")
		game.action("hub_category_10")
		game.action("hw_pick_street_radial")
		await capture("tire_comparison")
		game.action("tab_dealer")
		game.action("shop_class_E")
		await capture("dealership")
		game.action("tab_style")
		game.action("custom_pick_3")
		await capture("customization")
		game.action("tab_races")
		game.career_board.active=false
		await capture("race_selection")
		game.action("open_championships")
		await capture("career")
		game.action("cb_class_E")
		await capture("boss_ladder")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	quit()
