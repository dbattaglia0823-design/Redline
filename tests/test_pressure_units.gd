extends "res://tests/test_main_navigation.gd"

func close(a: float,b: float,message: String) -> void:
	check(absf(a-b)<.0001,message)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.profile=DriverProfile.new()
	game.profile.vehicle_id="supra"
	game.profile.garage["supra"]={"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build("supra")}
	game.profile.stages=[3,2,3,1,5,1,0,0]
	game.profile.hardware=VehicleBench.fixture("automatic_type",["ecu","billet","fuel_ethanol","turbo_race","boost_control","drag_wheels"],{"gear_count":3,"boost":.6,"boost_rise":.5,"boost_by_gear":[.3,.7,1.1]})
	game.profile.reduced_motion=true
	game.profile.save()
	var loaded:=DriverProfile.new()
	loaded.load_profile()
	close(loaded.hardware.tune.boost,.6,"Existing saved pressure changed")
	game.profile=loaded
	game.refresh_car()
	close(PressureUnits.psi(1),14.503773773,"Incorrect PSI conversion")
	for dimensions in [Vector2i(1200,760),Vector2i(390,844)]:
		root.size=dimensions
		game.go_garage()
		game.tuning.open(1)
		await frame()
		var panel: GearboxTuningPanel=game.tuning.gearbox_panel
		check(panel.rows.boost.value.text.contains("PSI"),"Tuning pressure label missing PSI")
		close(panel.current("boost"),PressureUnits.psi(game.profile.hardware.tune.boost),"Saved pressure displayed in the wrong units")
		panel.rows.boost.slider.value=12.5
		await frame()
		close(game.profile.hardware.tune.boost,PressureUnits.from_psi(12.5),"PSI slider stored an incorrect pressure")
		close(PressureUnits.psi(game.car.boost_target(game.car.redline_rpm,1)),12.5,"PSI tuning did not reach physics")
		panel.rows.boost.plus.pressed.emit()
		await frame()
		close(PressureUnits.psi(game.profile.hardware.tune.boost),13.0,"Plus control did not add 0.5 PSI")
		panel.rows.boost_slot_1.slider.value=8.0
		panel.rows.boost_rise.slider.value=7.5
		await frame()
		close(game.profile.hardware.tune.boost_by_gear[1],PressureUnits.from_psi(8.0),"Gear boost cap converted incorrectly")
		close(game.car.boost_rise,PressureUnits.from_psi(7.5),"PSI/s converted incorrectly")
		close(game.profile.hardware.tune.boost_by_gear[0],.3,"Changing a gear cap altered another gear")
		root.get_texture().get_image().save_png("res://.qa/pressure-psi/tuning_%d.png"%dimensions.x)
		game.tuning.open(4)
		await frame()
		panel.rows.tire_pressure.slider.value=28
		await frame()
		close(game.profile.hardware.tune.tire_pressure,28,"Tire PSI was converted twice")
		check(panel.rows.tire_pressure.value.text=="28 PSI","Tire PSI label is incorrect")
	loaded.load_profile()
	close(PressureUnits.psi(loaded.hardware.tune.boost),13.0,"Saved PSI tuning did not reload correctly")
	check(UpgradeStudio.metric("Boost",1,2,"bar",2).contains("14.5 > 29.0 PSI"),"Upgrade preview uses incorrect PSI")
	var results:=TestResultsPanel.new()
	check(results.setup_changes({"boost":1.0},{"boost":.5}).contains("7.25 → 14.50"),"Time slip compares wrong pressure values")
	results.free()
	game.stop_presentation_audio()
	print("PSI / OLD SAVES / SLIDERS / GEAR CAPS / RISE RATE / PHYSICS: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
