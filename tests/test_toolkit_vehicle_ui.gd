extends "res://tests/test_main_navigation.gd"

func template() -> ToolkitVehicleScreen: return game.native_workshop.vehicle_template

func contract_snapshot(label: String) -> void:
	var file:=FileAccess.open("res://.qa/toolkit-ui/contracts/"+label+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"layout":template().layout,"sampleData":template().bindings},"\t")); file.close()

func bounds_and_nav() -> void:
	check(GlassDock.TABS.map(func(row): return row[0])==["garage","races","dealer","driver"],"Bottom bar is not exactly four ordered destinations")
	var nav: Array=game.buttons.filter(func(item): return item.get("native_control")!=null and item.native_control.get_parent()==game.dock)
	check(nav.size()==4,"Missing or duplicated bottom-bar target")
	var canvas:=Vector2(root.content_scale_size)
	var viewport:=Rect2(Vector2.ZERO,canvas)
	for item in game.buttons:
		check(viewport.encloses(Rect2(game.to_global(item.rect.position),item.rect.size*game.scale)),"UI target outside safe canvas: "+item.id)
		if game.is_portrait() or game.get_window().size.y<500:
			var height: float=item.rect.size.y*game.scale.y*root.size.y/canvas.y
			check(height>=43.5,"Small physical touch target: %s / %.1f"%[item.id,height])
	for i in game.buttons.size():
		for j in range(i+1,game.buttons.size()):
			check(not game.buttons[i].rect.grow(-1).intersects(game.buttons[j].rect.grow(-1)),"Overlapping actions: "+game.buttons[i].id+" / "+game.buttons[j].id)

func catalog_car(id: String,touch: bool) -> void:
	var target: Button=game.native_workshop.targets["dealer_%d"%GameCatalog.CAR_IDS.find(id)]
	var scroll: ScrollContainer=template().controls.vehicles
	scroll.ensure_control_visible(target); await frame()
	await tap("dealer_%d"%GameCatalog.CAR_IDS.find(id),touch)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://.qa/toolkit-ui/screens")
	DirAccess.make_dir_recursive_absolute("res://.qa/toolkit-ui/contracts")
	var initial_prices:=JSON.stringify(RosterData.rows())
	for dimensions in [Vector2i(1200,760),Vector2i(393,852),Vector2i(430,932),Vector2i(844,390),Vector2i(932,430)]:
		root.size=dimensions
		game.safe_insets=Vector4(0,72,0,54) if dimensions.x<dimensions.y else (Vector4(70,0,70,38) if dimensions.y<500 else Vector4.ZERO)
		game.profile=DriverProfile.new(); game.profile.credits=1000000; game.profile.xp=100000
		game.profile.appearance=VehicleAppearance.normalize({"paint":3,"design":6,"rim":3,"tint":4}); game.profile.paint=3; game.profile.wheels=3; game.profile.stages[0]=1; game.profile.save()
		game.profile.buy_vehicle("mustang",false); game.refresh_car(); game.go_garage(); game.toast_left=0
		await frame()
		var touch: bool=dimensions.x<1000
		check(template().screen_type=="garage" and template().hero.model=="miata","Garage template did not bind equipped car")
		check(template().hero.look==game.profile.appearance,"Garage lost customized wheels / paint")
		bounds_and_nav()
		contract_snapshot("garage_%d"%dimensions.x)
		root.get_texture().get_image().save_png("res://.qa/toolkit-ui/screens/garage_%d.png"%dimensions.x)
		var original:=JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.appearance])
		await tap("garage_next",touch); check(game.profile.vehicle_id=="mustang","Garage next did not equip owned vehicle")
		await tap("garage_previous",touch); check(game.profile.vehicle_id=="miata","Garage previous did not return to owned vehicle")
		check(original==JSON.stringify([game.profile.hardware,game.profile.stages,game.profile.appearance]),"Vehicle switching lost build or appearance")
		await tap("garage_upgrades",touch); check(game.tab=="performance","Garage upgrades action is disconnected")
		game.go_garage(); await frame(); await tap("garage_customize",touch); check(game.tab=="style","Garage customization action is disconnected")
		game.go_garage(); await frame(); await tap("hub_owned",touch); check(game.tab=="owned","Change Car action is disconnected")
		await tap("tab_dealer",touch)
		check(game.menu.dealer.class_picker,"Dealer nav skipped class selection")
		check(game.buttons.filter(func(item): return str(item.id).begins_with("shop_class_")).size()==6,"Class cards / unlock flow were removed")
		root.get_texture().get_image().save_png("res://.qa/toolkit-ui/screens/classes_%d.png"%dimensions.x)
		await tap("shop_class_E",touch)
		check(template().screen_type=="dealership" and template().hero.model==GameCatalog.CAR_IDS[game.dealer_index],"Dealership template did not bind selected class vehicle")
		bounds_and_nav()
		contract_snapshot("dealership_%d"%dimensions.x)
		for i in 5:
			await tap("shop_car_next",touch)
			check(GameCatalog.engine_class(GameCatalog.CAR_IDS[game.dealer_index])=="E","Next vehicle escaped selected engine class")
		await catalog_car("civic_si",touch)
		var money: int=game.profile.credits
		await tap("buy_car",touch)
		check(game.profile.garage.has("civic_si") and game.profile.vehicle_id=="civic_si","Purchase / auto-equip did not reach existing game systems")
		check(game.profile.credits==money-int(GameCatalog.spec("civic_si").price),"Purchase charged an incorrect amount")
		check(template().controls.purchase.disabled and template().controls.purchase.text=="Equipped","Equipped state is incorrect")
		money=game.profile.credits; game.action("buy_car"); await frame()
		check(game.profile.credits==money,"Duplicate purchase charged twice")
		game.toast_left=0; await frame()
		root.get_texture().get_image().save_png("res://.qa/toolkit-ui/screens/dealer_%d.png"%dimensions.x)
		# Search and ownership filtering affect only this class's presentation.
		template().controls.search.text="Mazda"; template().controls.search.text_changed.emit("Mazda"); await frame()
		check(template().catalog_items.size()==1 and template().catalog_items[0].id=="miata","Class search is not wired")
		check(game.native_workshop.targets.has("dealer_catalog_filter"),"Searching removed the filter action")
		await tap("dealer_catalog_filter",touch)
		check(template().catalog_items.size()==1,"Owned filter changed class inventory")
		await tap("dealer_catalog_filter",touch)
		check(template().catalog_items.is_empty(),"Unowned filter included owned cars")
		bounds_and_nav()
		await tap("dealer_catalog_filter",touch)
		template().controls.search.text=""; template().controls.search.text_changed.emit("")
		await tap("shop_classes",touch)
		check(game.menu.dealer.class_picker,"Back did not return to class selection")
		await tap("shop_class_D",touch)
		var buy_id: String=GameCatalog.CAR_IDS[game.dealer_index]
		await tap("shop_equip",touch); check(not game.menu.dealer.equip,"Equip-on-purchase setting did not toggle")
		await tap("buy_car",touch)
		check(game.profile.garage.has(buy_id) and game.profile.vehicle_id=="civic_si","Buying without equipping changed the active car")
		check(template().controls.purchase.text=="Equip vehicle","Owned vehicle state is incorrect")
		await tap("drive_car",touch); check(game.profile.vehicle_id==buy_id,"Owned vehicle could not be equipped")
		await tap("shop_details",touch); check(game.menu.dealer.details,"Details action disconnected")
		check(template().bindings.dealership.selected.stats.any(func(row): return row.label=="GEAR 1 RATIO"),"Mechanical transmission details were lost")
		await tap("shop_details",touch)
		game.action("tab_garage"); await frame(); await tap("tab_dealer",touch)
		check(game.menu.dealer.class_picker,"Reopening Dealer did not begin with classes")
		game.menu.dealer.equip=true
	# Locked and insufficient-funds vehicles retain the existing game rules.
	game.profile.xp=0; game.profile.credits=0
	game.action("shop_class_S"); await frame()
	check(template().controls.purchase.disabled and "Locked" in template().controls.purchase.text,"Locked vehicle appears purchasable")
	var before:=JSON.stringify(game.profile.garage); game.action("buy_car"); await frame()
	check(JSON.stringify(game.profile.garage)==before,"Locked purchase mutated ownership")
	game.profile.save(); var loaded:=DriverProfile.new(); loaded.load_profile()
	check(loaded.garage.size()==game.profile.garage.size(),"Save/load lost owned vehicles")
	check(JSON.stringify(RosterData.rows())==initial_prices,"UI integration changed vehicle data / economy")
	game.stop_presentation_audio()
	print("TOOLKIT GARAGE / CLASS DEALER / FOUR-TAB NAV / SAFE AREAS / PURCHASE / SAVE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
