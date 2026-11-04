extends "res://tests/test_qol_ui.gd"
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.credits=100000; game.profile.xp=20000; game.profile.buy_vehicle("civic_si",false); game.refresh_car()
	var folder: String="res://validation/collection_before" if "--before" in OS.get_cmdline_user_args() else "res://validation/collection_after"
	DirAccess.make_dir_recursive_absolute(folder)
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760)
		for screen in ["classes","dealer","details","owned","style","wheels","finish"]:
			if screen=="classes": game.action("tab_dealer")
			elif screen=="dealer": game.action("shop_class_E")
			elif screen=="details": game.action("shop_details")
			elif screen=="owned": game.action("hub_owned")
			else:
				game.action("tab_style"); game.action("custom_category_"+({"style":"paint","wheels":"design","finish":"finish"}[screen]))
				if screen=="finish": game.action("custom_pick_2")
			game.toast_left=0; await frame()
			root.get_texture().get_image().save_png(folder+"/"+screen+("_phone" if phone else "_desktop")+".png")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; quit()
