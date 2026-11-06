extends SceneTree

const OUTPUT := "res://validation/workbench_redesign"
var game: Node2D
var output:=OUTPUT

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 12:
		PerformanceClasses.advance()
		RaceAI.advance_estimates(1200)
		game._process(.025)
		await process_frame
	game.sync_menu_size()
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	var rendered:=root.get_texture().get_image()
	var image:=Image.create(root.size.x,root.size.y,false,rendered.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),(root.size-rendered.get_size())/2)
	var filename:="%s/%s_%dx%d.png"%[output,label,root.size.x,root.size.y]
	if image.save_png(filename)!=OK: push_error("Could not save "+filename)

func check_showroom_navigation() -> void:
	var actions: Dictionary={"garage_upgrades":"performance","garage_customize":"style","hub_owned":"owned","open_tuning":"tuning","race_menu":"races"}
	for id in actions:
		game.go_garage()
		await settle()
		var target: Dictionary={}
		for entry in game.buttons:
			if entry.id==id: target=entry; break
		assert(not target.is_empty(),"Missing garage action "+id)
		for entry in game.buttons:
			if str(entry.id).begins_with("tab_"):
				assert(not target.rect.intersects(entry.rect),"Garage action overlaps the dock: "+id)
		var point: Vector2=game.to_global(target.rect.get_center())
		var input: InputEvent
		if root.size.y>root.size.x or root.size.y<500:
			var touch:=InputEventScreenTouch.new()
			touch.index=3; touch.position=point; touch.pressed=true
			input=touch
		else:
			var mouse:=InputEventMouseButton.new()
			mouse.position=point; mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true
			input=mouse
		root.push_input(input,true)
		assert(game.tab==actions[id],"Garage action did not open "+actions[id])
	game.go_garage()

func run() -> void:
	var showroom: bool=OS.get_cmdline_user_args().has("--showroom")
	var parts_shop: bool=OS.get_cmdline_user_args().has("--parts-shop")
	if showroom: output="res://validation/showroom_redesign"
	if parts_shop: output="res://validation/parts_shop"
	DirAccess.make_dir_recursive_absolute(output)
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
		if showroom:
			await capture("starter_garage")
			var starter: GarageShowroom=game.native_workshop.find_child("GarageShowroom",true,false)
			assert(starter.parked.is_empty())
			var paints: Dictionary={"civic_si":2,"gr86":4}
			for id in paints:
				game.profile.garage[id]={"paint":paints[id],"wheels":0,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build(id)}
		if not parts_shop: await capture("garage")
		if showroom:
			var garage: GarageShowroom=game.native_workshop.find_child("GarageShowroom",true,false)
			assert(garage.active.id=="miata" and garage.parked.size()==2)
			await check_showroom_navigation()
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
		if parts_shop:
			game.action("hub_back")
			game.action("hub_category_5")
			game.action("hw_pick_turbo_race")
			game.action("catalog_purchase")
			await capture("turbo_bundle")
			game.action("hub_back")
			game.profile.stages[4]=2
			game.refresh_car()
			game.action("hub_category_7")
			game.action("upgrade_section_transmission")
			game.action("tx_filter_1")
			game.action("tx_next")
			game.action("tx_pick_dct7")
			await capture("gearbox_comparison")
			continue
		game.action("tab_dealer")
		if showroom: await capture("dealer_classes")
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
