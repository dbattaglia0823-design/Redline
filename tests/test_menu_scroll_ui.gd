extends "res://tests/test_qol_ui.gd"

func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.profile=DriverProfile.new()
	game.profile.credits=1000000
	game.profile.xp=100000
	game.refresh_car()
	root.size=Vector2i(390,844)
	await frame()
	game.action("tab_dealer")
	await frame()
	game.action("shop_class_S")
	await frame()
	check(not game.menu.dealer.class_picker,"Could not enter dealership class")
	var catalogue: ScrollContainer=game.native_workshop.vehicle_template.controls.vehicles
	await process_frame
	var maximum: float=catalogue.get_v_scroll_bar().max_value-catalogue.get_v_scroll_bar().page
	check(maximum>80,"Dealer catalog does not have enough entries to test scrolling")
	if maximum>80:
		catalogue.scroll_vertical=mini(95,int(maximum))
		var expected: int=catalogue.scroll_vertical
		game.action("shop_car_next")
		await frame()
		catalogue=game.native_workshop.vehicle_template.controls.vehicles
		check(absi(catalogue.scroll_vertical-expected)<=2,"Dealer selection sent scroll back to the top")
		# Rebuilding the same list for filters must preserve its offset too.
		expected=catalogue.scroll_vertical
		game.action("dealer_catalog_filter")
		await frame()
		catalogue=game.native_workshop.vehicle_template.controls.vehicles
		var filtered_max: float=catalogue.get_v_scroll_bar().max_value-catalogue.get_v_scroll_bar().page
		check(catalogue.scroll_vertical==mini(expected,maxi(0,roundi(filtered_max))),"Dealer filter reset scroll instead of clamping to available content")
	game.go_garage()
	await frame()
	game.action("garage_customize")
	await frame()
	game.action("custom_group_wheels")
	game.action("custom_category_design")
	await frame()
	var options: ScrollContainer=game.native_workshop.find_child("StudioOptions",true,false)
	check(is_instance_valid(options),"Customization option scroller missing")
	if is_instance_valid(options):
		await process_frame
		var range_limit: float=options.get_v_scroll_bar().max_value-options.get_v_scroll_bar().page
		if range_limit>16:
			options.scroll_vertical=mini(46,int(range_limit))
			var position: int=options.scroll_vertical
			game.action("custom_pick_1")
			await frame()
			options=game.native_workshop.find_child("StudioOptions",true,false)
			check(is_instance_valid(options) and absi(options.scroll_vertical-position)<=2,"Customizing a selected item reset its scroll position")
		else:
			# Keep the test meaningful even if a later design reduces card count.
			check(false,"Customization layout no longer scrolls; update test fixture")
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	print("MENU SCROLL UI: ",checks," checks / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
