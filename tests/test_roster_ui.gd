extends "res://tests/test_qol_ui.gd"
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false); await frame()
	game.profile=DriverProfile.new(); game.profile.credits=10000000; game.profile.xp=100000
	DirAccess.make_dir_recursive_absolute("res://validation/roster_art")
	for id in RosterData.IDS:
		if not game.profile.garage.has(id): check(game.profile.buy_vehicle(id,false),"Purchase "+id)
		game.profile.select_vehicle(id); game.refresh_car(); game.go_garage(); await frame()
		check(game.car.transmission_id=="oem_"+id,"Factory configuration "+id)
		game.action("tab_dealer"); game.menu.dealer.enter_class(GameCatalog.price_class(id)); game.dealer_index=RosterData.IDS.find(id); await frame()
		root.get_texture().get_image().save_png("res://validation/roster_art/"+id+".png")
		for item in game.buttons: check(Rect2(0,0,1200,760).encloses(item.rect),"Dealer control clipped "+id)
	for phone in [false,true]:
		game.get_window().size=Vector2i(390,844) if phone else Vector2i(1200,760)
		game.go_garage(); await frame(); await click("hub_owned"); await click("owned_sort")
		check(game.tab=="owned","Collection navigation")
		game.action("owned_filter"); await frame(); game.action("owned_filter"); await frame()
		game.go_garage(); game.action("tab_style"); await frame(); await click("custom_category_paint"); await click("custom_pick_1"); await click("custom_install")
		check(game.profile.paint==1,"Cosmetic installation")
		game.go_garage(); game.action("tab_performance"); await frame(); await click("hub_category_0"); await click("stage_pick_1")
		var money: int=game.profile.credits; await click("install_0_1")
		check(game.profile.stages[0]==1 and game.profile.credits==money-700,"Engine package purchase")
		game.profile.stages[0]=0; game.refresh_car()
		game.go_garage(); game.action("race_menu"); await frame()
		var bot:=GameCatalog.opponent(0,0,game.profile)
		check(RosterData.IDS.has(bot.model),"Retired AI model")
		var ready: Dictionary={}
		for i in 300:
			PerformanceClasses.advance(); ready=PerformanceClasses.request(game.profile.vehicle_id,game.profile.stages,game.profile.hardware)
			if not ready.is_empty(): break
		check(not ready.is_empty() and bot.model=="miata" and bot.stages==GameCatalog.blank_stages(),"Opening career rival changed with player's build")
		game.start_race(); check(game.screen=="race","Playable race entry")
		game.go_garage()
	var f:=FileAccess.open("res://validation/roster_ui_results.json",FileAccess.WRITE); f.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"vehicles":30},"  ")); f.close()
	print("ROSTER UI: ",checks," / ","PASS" if failures==0 else "FAIL")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)

