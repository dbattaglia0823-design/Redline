extends "res://tests/test_native_workshop.gd"

func press_key(code: Key) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true
	root.push_input(event,true); event=event.duplicate(); event.pressed=false; root.push_input(event,true)
	await frame()

func keyboard_action(id: String) -> void:
	game.glass.focused=id; await frame(); await press_key(KEY_ENTER)

func click(id: String,touch: bool=false) -> void:
	if not game.buttons.any(func(entry): return entry.id==id) and game.native_workshop.targets.has(id):
		var control: Control=game.native_workshop.targets[id]
		var ancestor: Node=control.get_parent()
		while ancestor!=null and ancestor!=game.native_workshop:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(control)
			ancestor=ancestor.get_parent()
		await frame()
	await super.click(id,touch)

func audit() -> void:
	var canvas:=Rect2(Vector2.ZERO,game.native_workshop.size)
	for i in game.buttons.size():
		var a: Dictionary=game.buttons[i]
		check(canvas.encloses(a.rect),"Phase 2 target outside canvas: "+a.id)
		check(a.get("native_control") is Button,"Phase 2 action is not native: "+a.id)
		if game.is_portrait(): check(a.rect.size.y>=68,"Small phone target: "+a.id)
		if game.native_workshop.compact_landscape(): check(a.rect.size.y>=86,"Small landscape touch target: "+a.id)
		for j in range(i+1,game.buttons.size()): check(not a.rect.intersects(game.buttons[j].rect),"Phase 2 targets overlap: "+a.id+" / "+game.buttons[j].id)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	DirAccess.make_dir_recursive_absolute("res://validation/collection_flow")
	for dimensions in [Vector2i(1200,760),Vector2i(1920,1080),Vector2i(390,844),Vector2i(360,780),Vector2i(844,390)]:
		root.size=dimensions
		game.profile=DriverProfile.new(); game.profile.credits=1000000; game.profile.xp=100000; game.profile.buy_vehicle("civic_si",false); game.refresh_car(); await frame()
		game.menu.hub.owned_filter=0; game.menu.hub.owned_sort=false
		var touch: bool=game.is_portrait() or dimensions.y<500
		await click("tab_dealer",touch); audit()
		check(game.menu.dealer.class_picker,"Dealer bypasses class overview")
		for letter in PerformanceClasses.ORDER:
			await click("shop_class_"+letter,touch); audit()
			check(game.menu.dealer.filtered().all(func(id): return PerformanceClasses.factory_class(id)==letter),"Native class inventory is incorrect")
			if game.menu.dealer.filtered().size()>4:
				await click("shop_next",touch); check(game.menu.dealer.page==1,"Dealer next page failed")
				await click("shop_prev",touch); check(game.menu.dealer.page==0,"Dealer previous page failed")
			var selected_index: int=game.dealer_index
			await press_key(KEY_RIGHT); await press_key(KEY_LEFT)
			check(game.dealer_index==selected_index,"Keyboard vehicle browsing did not preserve selected class/order")
			await keyboard_action("shop_details"); check(game.menu.dealer.details,"Keyboard activated Details twice or failed to open it"); audit()
			var detail: ScrollContainer=game.native_workshop.find_child("MechanicalDetails",true,false)
			check(detail!=null,"Vehicle specifications missing")
			if detail!=null:
				for line in detail.get_child(0).get_children(): check(line.size.y>=24 and line.size.x>100,"Specification label has unusable layout")
			await press_key(KEY_ESCAPE); check(not game.menu.dealer.details and not game.menu.dealer.class_picker,"Keyboard back skipped the inventory")
			await click("shop_classes",touch)
		await click("shop_class_E",touch)
		var car_id: String=game.menu.dealer.filtered().filter(func(id): return not game.profile.garage.has(id))[0]
		await click("dealer_%d"%GameCatalog.CAR_IDS.find(car_id),touch)
		game.menu.dealer.equip=true; await frame(); await click("shop_equip",touch)
		var money: int=game.profile.credits; var active: String=game.profile.vehicle_id
		if dimensions.x==1920: await keyboard_action("buy_car")
		else: await click("buy_car",touch)
		check(game.profile.garage.has(car_id) and game.profile.credits==money-int(GameCatalog.spec(car_id).price),"Native dealer did not purchase exactly once")
		check(game.profile.vehicle_id==active,"Equip-on-purchase No changed the active car")
		await click("drive_car",touch); check(game.profile.vehicle_id==car_id,"Owned dealer car cannot equip")
		await click("tab_garage",touch); await click("hub_owned",touch); audit()
		await click("hub_pick_miata",touch); await click("hub_equip",touch)
		check(game.profile.vehicle_id=="miata","Collection equip failed")
		await click("owned_sort",touch); audit(); await click("owned_filter",touch); audit()
		await click("tab_style",touch); audit()
		if game.native_workshop.compact_landscape():
			await click("custom_category_paint",true)
			var scroll: ScrollContainer=game.native_workshop.find_child("LandscapeOptions",true,false)
			var candidate_before: Dictionary=game.menu.customize.candidate.duplicate(true)
			var funds_before: int=game.profile.credits
			var start: Vector2=game.to_global(target("custom_pick_0").rect.get_center())
			var press:=InputEventScreenTouch.new(); press.index=12; press.position=start; press.pressed=true; root.push_input(press,true)
			var drag:=InputEventScreenDrag.new(); drag.index=12; drag.position=start-Vector2(160,0); drag.relative=Vector2(-160,0); root.push_input(drag,true)
			press=press.duplicate(); press.pressed=false; press.position=drag.position; root.push_input(press,true); await frame()
			check(scroll.scroll_horizontal>0,"Landscape touch swipe did not scroll options")
			check(game.menu.customize.candidate==candidate_before and game.profile.credits==funds_before,"Scrolling selected or purchased a cosmetic option")
		var baseline: String=JSON.stringify([game.profile.appearance_for("miata"),game.profile.credits,game.car.telemetry()])
		var saved: String=FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)
		await click("custom_category_finish",touch); await click("custom_pick_2",touch)
		check(JSON.stringify([game.profile.appearance_for("miata"),game.profile.credits,game.car.telemetry()])==baseline and FileAccess.get_file_as_string(DriverProfile.SAVE_PATH)==saved,"Native preview mutated physics, funds or save")
		await click("custom_compare",touch); check(game.menu.customize.compare,"Installed comparison unavailable")
		money=game.profile.credits; await click("custom_install",touch)
		check(game.profile.appearance.finish==2 and game.profile.credits==money-450,"Finish purchase incorrect")
		await click("custom_install",touch); check(game.profile.credits==money-450,"Disabled cosmetic purchase charged again")
		await click("custom_reset",touch); await click("custom_category_finish",touch); await click("custom_pick_2",touch); await click("custom_install",touch)
		check(game.profile.credits==money-450 and game.profile.appearance.finish==2,"Owned cosmetics charged on reinstall")
		await click("custom_category_paint",touch); await click("custom_pick_3",touch); await click("custom_discard",touch)
		check(not game.menu.customize.has_preview(),"Discard left a preview behind")
		for category in VehicleAppearance.CATEGORIES:
			var visible: bool=game.buttons.any(func(item): return item.id=="custom_category_"+category)
			check(visible==VehicleAppearance.definition("miata").compatible.has(category),"Unsupported cosmetic category exposed")
		var loaded:=DriverProfile.new(); loaded.load_profile()
		check(loaded.appearance.finish==2 and loaded.garage.has(car_id),"Phase 2 changes did not persist")
		game.toast_left=0; await frame(); root.get_texture().get_image().save_png("res://validation/collection_flow/custom_"+str(dimensions.x)+"x"+str(dimensions.y)+".png")
		await click("custom_back",touch); await click("hub_owned",touch)
		game.menu.hub.owned_filter=0
		game.profile.upgrade(0,2)
		game.profile.install_hardware("ecu")
		check(game.profile.tune_hardware("launch_rpm",3300),"Cannot prepare supported tuning preservation fixture")
		check(game.profile.save_tune_slot("quarter","UI preservation"),"Cannot prepare vehicle tuning preset")
		game.refresh_car(); await frame()
		var build_before: Array=[game.profile.stages.duplicate(true),game.profile.hardware.duplicate(true),game.profile.appearance_for("miata")]
		var presets_before: Dictionary=game.profile.tuning_presets().duplicate(true)
		await click("hub_pick_civic_si",touch); await click("hub_equip",touch)
		check(game.profile.vehicle_id=="civic_si" and game.profile.appearance.finish==0,"Another vehicle inherited the cosmetic build")
		await click("hub_pick_miata",touch); await click("hub_equip",touch)
		check(game.profile.appearance.finish==2,"Collection switching lost the purchased vehicle appearance")
		check([game.profile.stages,game.profile.hardware,game.profile.appearance_for("miata")]==build_before,"Vehicle switching changed saved upgrades, transmission or tuning")
		check(game.profile.tuning_presets()==presets_before,"Vehicle switching changed saved tuning presets")
		for extra in GameCatalog.CAR_IDS:
			if game.profile.garage.size()>=5: break
			if not game.profile.garage.has(extra): game.profile.buy_vehicle(extra,false)
		game.menu.hub.owned_filter=0; game.menu.hub.owned_sort=false
		await click("tab_garage",touch); await click("hub_owned",touch); await click("hub_owned_next",touch)
		check(game.menu.hub.owned_page==1,"Collection next page failed")
		var last: String=game.menu.hub.owned_ids()[4]
		await click("hub_pick_"+last,touch); await click("hub_equip",touch)
		check(game.profile.vehicle_id==last,"Paged collection vehicle did not equip")
		await click("hub_owned_prev",touch); await click("hub_pick_miata",touch); await click("hub_equip",touch)
		check(game.profile.appearance.finish==2,"Paged vehicle switching lost customization")
		game.profile.credits=0; game.profile.xp=0; await click("tab_dealer",touch); await click("shop_class_S",touch)
		check(target("buy_car").get("native_control").disabled,"Locked vehicle purchase is enabled")
		var ownership: String=JSON.stringify(game.profile.garage)
		await click("buy_car",touch)
		check(JSON.stringify(game.profile.garage)==ownership and game.profile.credits==0,"Locked purchase changed ownership or currency")
		game.profile.xp=100000; await frame()
		check(target("buy_car").get("native_control").disabled,"Unaffordable vehicle purchase is enabled")
	var report:=FileAccess.open("res://validation/collection_flow/results.json",FileAccess.WRITE); report.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"viewport_mouse_touch":true},"  ")); report.close()
	print("NATIVE COLLECTION / DEALER / COSMETICS: ",checks," / ","PASS" if failures==0 else "FAIL")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; quit(0 if failures==0 else 1)
