extends "res://tests/test_qol_ui.gd"
func run_checks() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false); game.profile=DriverProfile.new(); game.refresh_car(); await frame()
	game.profile.credits=1000000
	game.workshop.action("lab_run"); var bench: VehicleBench=game.workshop.lab
	game.workshop.action("lab_run"); check(game.workshop.lab==bench,"Duplicate run restarted test")
	game.profile.stages[3]=1; game.refresh_car()
	check(game.workshop.lab==null and game.workshop.lab_result.is_empty(),"Old build test survived refresh")
	game.menu.hub.show_hp=true; game.menu.hub.show_torque=false
	check(not game.action_enabled("hub_hp") and game.action_enabled("hub_torque"),"Dyno can become blank")
	game.menu.hub.show_torque=true
	game.menu.hub.selected=4
	check(not game.action_enabled("preset_drag"),"Preset active without ECU")
	game.profile.install_hardware("ecu"); game.refresh_car()
	game.profile.tune_hardware("launch_rpm",6000); game.refresh_car()
	check(not game.action_enabled("tune_plus_launch_rpm") and game.action_enabled("tune_minus_launch_rpm"),"Launch tuning bounds wrong")
	game.workshop.gear_index=game.car.gear_ratios.size()-1
	check(not game.action_enabled("tune_plus_shift"),"Top gear offers upshift target")
	check(not game.action_enabled("tune_reset"),"Reset available without custom map")
	game.action("tab_dealer"); game.menu.dealer.details=true; var selected: int=game.dealer_index
	key(KEY_RIGHT); check(game.dealer_index==selected,"Details changed hidden selection")
	game.menu.dealer.details=false
	game.dragging_wager="mouse_1"; game.action("tab_garage"); check(game.dragging_wager=="","Navigation retained hidden slider")
	game.action("tab_style"); game.action("custom_pick_1"); key(KEY_ESCAPE)
	check(game.tab=="garage" and game.menu.customize.candidate.is_empty(),"Escape retained cosmetic preview")
	game.profile.credits=25; game.wager=100; RosterTest.ready(game); game.start_race()
	check(game.active_stake==25 and game.wager==25 and game.screen=="race","Stale wager blocks affordable race")
	game.go_garage()
	var f:=FileAccess.open("res://validation/quality_pass_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures==0,"checks":checks},"  ")); f.close()
	print("QUALITY PASS: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame; call_deferred("quit",0 if failures==0 else 1)
