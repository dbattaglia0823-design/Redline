extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func settle(game: Node2D) -> void:
	game.sync_menu_size()
	game.menu_dirty=true
	game.queue_redraw()
	for i in 5: await process_frame

func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.profile.credits=100000000
	for id in GameCatalog.CAR_IDS.slice(0,12):
		if not game.profile.garage.has(id): game.profile.buy_vehicle(id,false)
	game.go_garage()
	game.action("hub_owned")
	root.size=Vector2i(1200,760)
	await settle(game)
	check(game.tab=="owned","Collection page did not open")
	check(not game.dock.visible,"Floating dock overlaps collection screen")
	var native: Control=game.native_workshop
	check(is_instance_valid(native.find_child("OwnedVehicleScroll",true,false)),"No scrollable car list")
	var picker: OptionButton=native.find_child("OwnedEngineClassDropdown",true,false)
	check(picker!=null,"Engine class dropdown missing")
	if picker!=null:
		check(picker.item_count==PerformanceClasses.ORDER.size()+1,"Dropdown is missing an engine class")
		picker.select(1)
		picker.item_selected.emit(1)
		await settle(game)
		check(game.menu.hub.owned_filter==1,"Class dropdown failed to select class")
		check(game.menu.hub.owned_ids().all(func(id): return GameCatalog.engine_class(id,game.menu.hub.vehicle(id).hardware)==PerformanceClasses.ORDER[0]),"Class filter returned another class")
		picker=native.find_child("OwnedEngineClassDropdown",true,false)
		picker.select(0)
		picker.item_selected.emit(0)
		await settle(game)
		check(game.menu.hub.owned_filter==0,"All classes failed to restore")
	for dims in [Vector2i(844,390),Vector2i(390,844)]:
		root.size=dims
		await settle(game)
		check(not game.dock.visible,"Floating dock visible in collection at "+str(dims))
		check(native.find_child("OwnedVehicleScroll",true,false)!=null,"Scrollable list missing at "+str(dims))
		check(native.find_child("OwnedEngineClassDropdown",true,false)!=null,"Class dropdown missing at "+str(dims))
	game.stop_presentation_audio()
	print("COLLECTION NAVIGATION / SCROLL / FILTER: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
