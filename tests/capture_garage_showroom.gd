extends "res://tests/test_main_navigation.gd"

func capture(label: String) -> void:
	await create_timer(.35).timeout
	await frame()
	var showroom: TextureRect=game.native_workshop.find_child("GarageEnvironment",true,false)
	var ui: ToolkitVehicleScreen=game.native_workshop.vehicle_template
	var console: Control=ui.controls.vehicle_info
	check(showroom!=null and showroom.position==Vector2.ZERO and showroom.size==game.native_workshop.size,"Showroom does not fill the screen")
	check(showroom.texture!=null and ui.hero.scene_texture!=null,"Garage background did not load")
	var canvas:=Rect2(Vector2.ZERO,game.native_workshop.size)
	var console_rect:=Rect2(game.to_local(console.global_position),console.size)
	check(canvas.encloses(console_rect),"Garage console leaves the screen")
	for target in game.buttons:
		check(canvas.encloses(target.rect),"Garage action leaves the screen: "+target.id)
		if str(target.id).begins_with("tab_"): check(not target.rect.intersects(console_rect),"Console overlaps navigation")
	root.get_texture().get_image().save_png("res://.qa/garage_showroom/%s_%dx%d.png"%[label,root.size.x,root.size.y])

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://.qa/garage_showroom")
	for dimensions in [Vector2i(1200,760),Vector2i(1920,1080),Vector2i(390,844),Vector2i(360,780),Vector2i(844,390),Vector2i(667,375)]:
		root.size=dimensions
		game.profile=DriverProfile.new()
		game.profile.reduced_motion=true
		game.refresh_car()
		game.go_garage()
		await capture("starter")
		for id in ["civic_si","gr86"]:
			game.profile.garage[id]={"paint":2,"wheels":0,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build(id)}
		game.menu_dirty=true
		await capture("collection")
		await tap("hub_owned",dimensions.x<1000)
		check(game.tab=="owned","Change Car does not open the collection")
		await tap("tab_garage",dimensions.x<1000)
		check(game.tab=="garage","Garage navigation does not return home")
	game.profile.effects_quality=0
	game.menu_dirty=true
	await capture("low")
	game.stop_presentation_audio()
	print("FULL GARAGE SHOWROOM: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
