extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var dealer: DealershipView=game.menu.dealer
	var selected_car: String=game.profile.vehicle_id
	var credits: int=game.profile.credits
	var initial_ids: Array[String]=dealer.class_ids("E").duplicate()
	check(dealer.vehicle_type=="cars","Dealer should default to Cars")
	check(dealer.VEHICLE_TYPES==["cars","bikes","watercraft"],"Vehicle type tabs missing")
	for letter in PerformanceClasses.ORDER:
		check(dealer.BIKE_IMAGES.has(letter) and ResourceLoader.exists(dealer.BIKE_IMAGES[letter]),"Missing bike class preview "+letter)
		check(dealer.WATERCRAFT_LABELS.has(letter),"Missing watercraft class preview "+letter)
	game.action("tab_dealer")
	check(dealer.class_picker and dealer.vehicle_type=="cars","Opening dealership must show Cars index")
	game.action("dealer_type_bikes")
	check(dealer.vehicle_type=="bikes" and dealer.class_picker,"Bikes tab must show class cards")
	game.action("shop_class_S")
	check(dealer.class_picker and dealer.vehicle_type=="bikes","Preview-only bike class must not enter car dealership")
	game.action("dealer_type_watercraft")
	check(dealer.vehicle_type=="watercraft" and dealer.class_picker,"Watercraft tab must show class cards")
	game.action("shop_class_E")
	check(dealer.class_picker,"Preview-only watercraft class must not enter car dealership")
	check(game.profile.vehicle_id==selected_car and game.profile.credits==credits,"Preview tabs changed car selection or wallet")
	check(dealer.class_ids("E")==initial_ids,"Future vehicle categories modified existing car catalog")
	game.action("dealer_type_cars")
	check(dealer.vehicle_type=="cars","Cars tab not restored")
	game.action("shop_class_E")
	check(not dealer.class_picker and dealer.CLASSES[dealer.class_filter]=="E","Cars class navigation stopped working")
	game.action("shop_classes")
	check(dealer.class_picker,"Back to Cars index failed")
	game.action("dealer_type_bikes")
	game.action("tab_garage")
	game.action("tab_dealer")
	check(dealer.vehicle_type=="cars" and dealer.class_picker,"Reopen dealership must start in Cars")
	if failures.is_empty():
		print("DEALERSHIP VEHICLE TYPE TABS PASS")
	else:
		print("DEALERSHIP VEHICLE TYPE TABS FAIL: ",failures)
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
