extends "res://tests/test_main_navigation.gd"

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.profile.credits=10000000; game.profile.xp=100000
	check(game.profile.buy_vehicle("chiron"),"High-stakes fixture could not purchase legal S car")
	game.profile.legacy_class_access=["S"]; game.profile.championship_wins={"S":9}; game.profile.reduced_motion=true; game.refresh_car()
	DirAccess.make_dir_recursive_absolute("res://.qa/championship-economy/screens")
	for dimensions in [Vector2i(1200,760),Vector2i(393,852),Vector2i(844,390)]:
		root.size=dimensions
		game.profile.credits=2000000; game.go_garage(); game.tab="races"; game.career_board.open(); game.career_board.select_series("S"); game.career_board.selected="class_S_9"
		await frame()
		check(game.current_contract().max_bet==400000,"S boss does not expose the new $400,000 cap")
		await tap("bet_more",dimensions.x<1000)
		check(game.wager==4000 and game.profile.credits==2000000,"High-stakes button uses an unsuitable step or spends before entry")
		await tap("bet_slider",dimensions.x<1000)
		check(abs(game.wager-200000)<=4000,"Large wager slider midpoint is incorrect")
		var slider: Dictionary={}
		for item in game.buttons:
			if item.id=="bet_slider": slider=item; break
		check(not slider.is_empty(),"Missing actual betting slider")
		if slider.is_empty(): continue
		var point:=game.to_global(Vector2(slider.rect.end.x-9,slider.rect.get_center().y))
		for pressed in [true,false]:
			var event: InputEvent=InputEventScreenTouch.new() if dimensions.x<1000 else InputEventMouseButton.new()
			event.position=point; event.pressed=pressed
			if event is InputEventMouseButton: event.button_index=MOUSE_BUTTON_LEFT
			root.push_input(event,true)
		await frame()
		check(game.wager==400000,"Pointer input cannot select the exact $400,000 cap")
		root.get_texture().get_image().save_png("res://.qa/championship-economy/screens/high_stakes_%d.png"%dimensions.x)
		await tap("race",dimensions.x<1000)
		check(game.screen=="race" and game.active_stake==400000 and game.profile.credits==1600000,"High stake was not charged exactly once on entry")
		game.profile.forfeit_wager(); game.go_garage(); game.tab="races"; game.career_board.select_series("S"); game.career_board.selected="class_S_9"
		game.profile.credits=0; game.wager=0
		await frame()
		check(not game.action_enabled("bet_more") and game.action_enabled("race"),"Bankruptcy blocked free races or enabled unfunded bets")
	game.stop_presentation_audio(); game.queue_free(); await process_frame
	print("CAPPED $400K WAGERS / DESKTOP / PHONE / TOUCH / FREE RACING: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
