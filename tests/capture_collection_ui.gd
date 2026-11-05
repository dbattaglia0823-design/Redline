extends "res://tests/test_qol_ui.gd"
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.credits=100000; game.profile.xp=20000; game.profile.buy_vehicle("civic_si",false); game.refresh_car()
	var folder: String="res://validation/collection_before" if "--before" in OS.get_cmdline_user_args() else "res://validation/collection_after"
	DirAccess.make_dir_recursive_absolute(folder)
	var captures: Array=[]
	for dimensions in [Vector2i(1200,760),Vector2i(1920,1080),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		for screen in ["classes","dealer","details","owned","style","wheels","finish"]:
			if screen=="classes": game.action("tab_dealer")
			elif screen=="dealer": game.action("shop_class_E")
			elif screen=="details": game.action("shop_details")
			elif screen=="owned": game.action("hub_owned")
			else:
				game.action("tab_style"); game.action("custom_category_"+({"style":"paint","wheels":"design","finish":"finish"}[screen]))
				if screen=="finish": game.action("custom_pick_2")
			game.toast_left=0; await frame()
			var image:=root.get_texture().get_image()
			# Viewport textures exclude Godot's native letterbox margins. Restore
			# those black window margins without resampling any rendered pixels.
			var full:=Image.create(dimensions.x,dimensions.y,false,image.get_format()); full.fill(Color.BLACK)
			full.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),(dimensions-image.get_size())/2)
			var filename: String=screen+"_"+str(dimensions.x)+"x"+str(dimensions.y)+".png"
			full.save_png(folder+"/"+filename)
			captures.append({"file":filename,"window":[dimensions.x,dimensions.y],"rendered_viewport":[image.get_width(),image.get_height()],"logical_canvas":[root.content_scale_size.x,root.content_scale_size.y]})
			if dimensions==Vector2i(1200,760) or dimensions==Vector2i(390,844): full.save_png(folder+"/"+screen+("_phone" if dimensions.x==390 else "_desktop")+".png")
	var manifest:=FileAccess.open(folder+"/capture_manifest.json",FileAccess.WRITE); manifest.store_string(JSON.stringify(captures,"  ")); manifest.close()
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; quit()
