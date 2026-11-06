extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func configured(profile: DriverProfile) -> Drivetrain:
	var car := Drivetrain.new()
	car.configure_vehicle(GameCatalog.spec(profile.vehicle_id))
	car.configure(profile.stages)
	car.configure_build(profile.hardware,profile.vehicle_id)
	return car

func _initialize() -> void:
	var profile := DriverProfile.new()
	profile.credits=100000
	var ladders := {
		"intake":["intake_street","plenum","intake_velocity","intake_race"],
		"fuel":["fuel_street","fuel_injectors","fuel_ethanol"],
		"ecu":["ecu_street","ecu","ecu_track","ecu_race"],
		"clutch":["clutch_street","clutch_twin","clutch_race"]
	}
	for slot in ladders:
		var previous_price := 0
		var previous := configured(profile)
		for id in ladders[slot]:
			var quote := profile.upgrade_quote(-1,-1,slot,id)
			var funds := profile.credits
			check(quote.reason=="" and quote.cost>previous_price and quote.items.size()==1,"Invalid upgrade ladder quote for "+id)
			check(profile.commit_upgrade_quote(-1,-1,slot,id,JSON.stringify(quote)).begins_with("Installed") and profile.credits==funds-int(quote.cost),"Purchase failed for "+id)
			var car := configured(profile)
			match slot:
				"intake": check(car.peak_horsepower()>previous.peak_horsepower(),"Engine output did not increase for "+id)
				"ecu":
					var performance_map: bool=id in ["ecu_track","ecu_race"]
					check((car.peak_horsepower()>previous.peak_horsepower())==performance_map,"Incorrect ECU power calibration for "+id)
					check(car.launch_control and profile.tune_hardware("launch_rpm",4000,false),"ECU launch tuning did not unlock for "+id)
					check(profile.tune_hardware("redline",car.redline_rpm,false)==(id!="ecu_street"),"Incorrect rev-limit access for "+id)
				"fuel": check(car.fuel_torque_capacity()>previous.fuel_torque_capacity(),"Fuel capacity did not increase for "+id)
				"clutch": check(car.clutch_capacity()>previous.clutch_capacity(),"Clutch capacity did not increase for "+id)
			previous=car
			previous_price=int(quote.cost)
		var first: String=ladders[slot][0]
		check(profile.upgrade_quote(-1,-1,slot,first).cost==0,"Owned part is not free to re-equip: "+first)
	var old := FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	var legacy := GameCatalog.factory_build("miata")
	legacy.owned_transmissions.append("drag_type")
	legacy.transmission="drag_type"
	legacy.parts={"nitrous":"progressive","converter":"converter_race","ecu":"ecu"}
	legacy.owned_parts=["progressive","converter_race","ecu"]
	legacy.tune={"stall":5600,"nitrous_auto":1,"nitrous_ramp":0.4,"launch_rpm":4300}
	old.store_string(JSON.stringify({"roster_version":2,"career_version":2,"traction_version":1,"credits":1200,"vehicle_id":"miata","garage":{"miata":{"stages":GameCatalog.blank_stages(),"hardware":legacy}}}))
	old.close()
	profile=DriverProfile.new()
	profile.load_profile()
	var migrated := configured(profile)
	migrated.reset()
	check(profile.credits==6600 and profile.stages[7]==1 and profile.highest_stage(7)==1,"Retired parts did not migrate to credits and a kit")
	check(profile.hardware.parts=={"ecu":"ecu"} and profile.hardware.tune=={"launch_rpm":4300.0},"Removed hardware or tuning survived migration")
	check(migrated.has_converter and migrated.converter_stall==4600 and migrated.launch_rpm==4300,"Drag automatic did not receive its default converter")
	check(migrated.nitrous_remaining==5.5 and not profile.tune_hardware("nitrous_auto",1,false),"Migrated kit or manual-only spray is incorrect")
	profile.save()
	var loaded := DriverProfile.new()
	loaded.load_profile()
	check(loaded.credits==6600 and loaded.stages[7]==1,"Repeated load changed the migration")
	print("PARTS LINEUP: ",checks," checks / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
