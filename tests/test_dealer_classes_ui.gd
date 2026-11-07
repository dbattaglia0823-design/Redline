extends "res://tests/test_qol_ui.gd"
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.credits=10000000; game.profile.xp=100000; game.refresh_car()
	var dealer: DealershipView=game.menu.dealer
	var price: int=RosterData.rows().miata.price
	var entry_ids:=dealer.class_ids("E")
	RosterData.rows().miata.price=10000000
	check(dealer.class_ids("E").has("miata") and GameCatalog.engine_class("miata")=="E","Changing a price changed the engine class")
	RosterData.rows().miata.price=price
	check(dealer.class_ids("E")==entry_ids,"Price fixture did not restore inventory ordering")
	game.profile.hardware.engine_id="supra"
	game.profile.legacy_class_access=["B"]
	game.menu.hub.owned_filter=PerformanceClasses.ORDER.find("B")+1
	check(game.menu.hub.owned_ids().has("miata"),"Collection filter ignored the installed engine")
	check(Championships.eligibility(game.profile,Championships.event("class_B_0"))=="","Installed B engine could not enter B")
	check(Championships.eligibility(game.profile,Championships.event("class_E_0"))!="","Installed B engine entered E")
	check(PerformanceClasses.label(game.profile)=="ENGINE CLASS B","Garage badge disagrees with race class")
	game.profile.hardware.erase("engine_id")
	game.menu.hub.owned_filter=0
	DirAccess.make_dir_recursive_absolute("res://validation/dealer_classes")
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760); game.toast_left=0; await frame(); game.action("tab_dealer"); await frame()
		check(game.menu.dealer.class_picker,"Dealer did not open with class cards")
		check(game.buttons.filter(func(b):return str(b.id).begins_with("shop_class_")).size()==6,"Missing E-S cards")
		var image:=root.get_texture().get_image()
		var probe: Vector2=(Vector2(44,190) if phone else Vector2(56,276))*Vector2(image.get_size())/Vector2(root.content_scale_size)
		var background:=image.get_pixelv(Vector2i(probe))
		check(maxf(background.r,maxf(background.g,background.b))<.5,"Texture cache eviction produced a white preview rectangle")
		root.get_texture().get_image().save_png("res://validation/dealer_classes/overview_"+("phone" if phone else "desktop")+".png")
		for letter in PerformanceClasses.ORDER:
			await click("shop_class_"+letter)
			var d: DealershipView=game.menu.dealer
			check(not d.class_picker and d.filtered().all(func(id): return GameCatalog.engine_class(id)==letter),"Wrong class inventory")
			check(not game.buttons.any(func(b):return str(b.id).begins_with("shop_filter_")),"Legacy filter controls remain")
			var size:=Vector2(600,1300) if phone else Vector2(1200,760)
			for b in game.buttons: check(Rect2(Vector2.ZERO,size).encloses(b.rect),"Class dealer control clipped: "+b.id)
			key(KEY_RIGHT); await frame(); var id: String=GameCatalog.CAR_IDS[game.dealer_index]
			check(GameCatalog.engine_class(id)==letter,"Keyboard browsing escaped selected class")
			await click("shop_classes"); await click("shop_class_"+letter)
			check(GameCatalog.CAR_IDS[game.dealer_index]==id,"Class did not remember selected car")
			await click("shop_details"); key(KEY_ESCAPE); await frame()
			check(not d.details and not d.class_picker,"Details back skipped class inventory")
			key(KEY_ESCAPE); await frame(); check(d.class_picker,"Back did not return to class cards")
		await click("shop_class_"+GameCatalog.engine_class("civic_si"))
		if phone:
			for i in 3:
				if game.dealer_index==1: break
				await click("shop_car_next")
		else: await click("dealer_1")
		var money: int=game.profile.credits
		if not game.profile.garage.has("civic_si"):
			await click("buy_car")
			check(game.profile.garage.has("civic_si") and game.profile.credits==money-int(GameCatalog.spec("civic_si").price),"Class inventory purchase failed")
		root.get_texture().get_image().save_png("res://validation/dealer_classes/inventory_"+("phone" if phone else "desktop")+".png")
		game.action("tab_garage"); game.action("tab_dealer"); await frame()
		check(game.menu.dealer.class_picker,"Dealer nav bypassed the class screen")
	var saved:=DriverProfile.new(); saved.load_profile(); check(saved.garage.has("civic_si"),"Purchase from class inventory did not persist")
	print("DEALER CLASS CARDS / TOUCH / KEYBOARD / ALL CLASSES / BACK / PURCHASE: ",checks," / ","PASS" if failures==0 else "FAIL")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; quit(0 if failures==0 else 1)
