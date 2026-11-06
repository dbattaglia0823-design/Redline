extends SceneTree

var failures := 0
var game: Node2D

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func refresh() -> void:
	RosterTest.ready(game)
	game.queue_redraw()
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw

func click(id: String) -> void:
	var position := Vector2(-1,-1)
	for button in game.buttons:
		if button.id == id: position = button.rect.get_center()
	check(position.x >= 0,"Missing menu button: "+id)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	game._input(event)
	event.pressed = false
	game._input(event)
	await refresh()

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.menu.hub.categories = true
	game.set_process(false)
	game.set_physics_process(false)
	game.profile = DriverProfile.new()
	game.profile.credits = 20000
	game.selected_opponent = 0
	game.refresh_car()
	await refresh()
	await click("tab_dealer"); await click("shop_class_"+GameCatalog.price_class("civic_si"))
	await click("dealer_1")
	await click("buy_car")
	var after_purchase:=20000-int(GameCatalog.spec("civic_si").price)
	check(game.profile.credits == after_purchase and game.profile.vehicle_id == "civic_si","Dealer button did not purchase and equip the selected car")
	check(game.car.base_mass == float(GameCatalog.spec("civic_si").mass),"Purchased car was not applied to racing physics")
	await click("tab_style")
	await click("custom_pick_5")
	await click("custom_install")
	await click("custom_category_rim")
	await click("custom_pick_2")
	await click("custom_install")
	await click("tab_performance")
	await click("hub_category_6")
	await click("install_7_1")
	check(game.profile.stages[7] == 1 and game.profile.credits == after_purchase-650,"Workshop tier installation failed")
	await click("hub_back")
	await click("tab_dealer"); await click("shop_class_E")
	await click("dealer_0")
	await click("drive_car")
	check(game.profile.vehicle_id == "miata" and game.profile.stages[7] == 0,"Dealer did not switch to independent starter-car build")
	await click("shop_classes"); await click("shop_class_"+GameCatalog.price_class("civic_si"))
	await click("dealer_1")
	await click("drive_car")
	check(game.profile.paint == 5 and game.profile.wheels == 2 and game.profile.stages[7] == 1,"Switching back lost car customization")
	await click("tab_races")
	await click("bet_more")
	await click("bet_more")
	check(game.wager == 100,"Two $50 wager increments from the safe $0 default failed")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var slider: Dictionary = {}
	for control in game.buttons:
		if control.id == "bet_slider": slider = control
	event.position = game.to_global(slider.rect.get_center())
	game._input(event)
	var drag := InputEventMouseMotion.new()
	drag.position = game.to_global(Vector2(slider.range.y,slider.rect.get_center().y))
	game._input(drag)
	event.pressed = false
	event.position = Vector2(1,1)
	game._input(event)
	check(game.wager == 500 and game.dragging_wager == "","Wager slider did not drag or release correctly")
	await refresh()
	await click("race")
	var charged: int = game.profile.credits
	check(charged == after_purchase-650-500 and game.screen == "race","Race start did not charge the displayed wager")
	RosterTest.ready(game); game.start_race()
	check(game.profile.credits == charged,"Double-start charged the wager again")
	await click("pause")
	await click("garage")
	check(game.profile.credits == charged and game.profile.pending_wager.is_empty(),"Forfeiting refunded the wager")
	await click("tab_races")
	game.wager = 0
	await refresh()
	await click("race")
	game.player_finish = 6.0
	game.rival_finish = 7.0
	game.car.speed = 30.0
	game.complete_race()
	var paid: int = game.profile.credits
	game.complete_race()
	check(game.profile.credits == paid and game.profile.career_wins[0] == 1,"Race payout or career progress was applied twice")
	await refresh()
	await click("next_rival")
	check(game.tab == "races" and game.selected_opponent == 1,"Next rival did not advance to the unlocked opponent")
	await click("bot_4")
	check(game.selected_opponent == 1,"Locked opponent could be selected")
	await click("event_2")
	await click("race")
	check(game.screen == "garage" and game.profile.credits == paid,"Locked career charged money or started a race")
	print("WORKSHOP + DEALER + WAGER MENU INTERACTIONS: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)

