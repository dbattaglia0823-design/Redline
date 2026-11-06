extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)

func car(id: String) -> Drivetrain:
	var result := Drivetrain.new()
	result.configure_build(VehicleBench.fixture(id))
	result.reset()
	result.running=true
	return result

func _initialize() -> void:
	var manual := car("manual_type")
	var feedback := RaceFeedback.new()
	var audio := EngineVoice.new()
	feedback.reset(manual)
	audio.set_from_vehicle(manual)
	manual.set_road_state(20,2,(manual.good_shift_min()+manual.good_shift_max())*.5)
	check(manual.select_manual_gear(3,0)=="HOLD CLUTCH" and manual.gear==2,"Bad shift changed gear")
	feedback.update_driving_cues(.02,manual)
	audio.set_from_vehicle(manual)
	check(feedback.grind_notice>0 and audio.grind_left>0,"Missed grind warning or sound")
	var peak := 0.0
	for i in 480: peak=maxf(peak,absf(audio.grind_sample()))
	check(peak>.05,"Gear grind audio is inaudible")
	check(manual.select_manual_gear(3,1)=="SHIFT ACCEPTED" and manual.shift_direction==1 and manual.shift_message=="PERFECT SHIFT","Correctly timed shift did not register")
	manual.shift_left=0
	check(manual.select_manual_gear(2,1)=="SHIFT ACCEPTED" and manual.shift_direction==-1,"Downshift direction did not register")

	var clutch := car("manual_type")
	clutch.set_road_state(20,2,6500)
	clutch.clutch_engagement=1
	clutch.throttle=1
	clutch.step(1.0/240,1)
	check(clutch.clutch_overloaded and not clutch.transmission_slipping,"Clutch saturation was not distinguished from gearbox overload")
	clutch.step(1.0/240,1,0,1)
	check(not clutch.clutch_overloaded and not clutch.transmission_slipping,"Intentional clutch input triggered a warning")

	var gearbox := car("manual_type")
	gearbox.rated_capacity=100
	gearbox.set_road_state(20,2)
	gearbox.clutch_engagement=1
	gearbox.throttle=1
	gearbox.step(1.0/240,1)
	check(gearbox.transmission_slipping and gearbox.overload>0 and gearbox.engine_torque<=gearbox.input_capacity(),"Overload did not flag and limit transmitted torque")

	var automatic := car("automatic_type")
	automatic.throttle=.65
	for tick in 48: automatic.step(1.0/240,.65)
	check(automatic.converter_slip>.15 and not automatic.clutch_overloaded and not automatic.transmission_slipping,"Normal converter slip triggered a warning")

	feedback.reset(manual)
	manual.throttle=.9
	manual.wheelspin=.30
	feedback.update_driving_cues(.02,manual)
	check(feedback.traction_lost and feedback.traction_recovered==0.0,"Wheelspin state missed")
	manual.wheelspin=.10
	feedback.update_driving_cues(.02,manual)
	check(feedback.traction_lost,"Wheelspin state flickered during recovery")
	manual.wheelspin=.05
	feedback.update_driving_cues(.02,manual)
	check(not feedback.traction_lost and feedback.traction_recovered>0.0,"Traction recovery cue missed")
	feedback.update_driving_cues(.7,manual)
	check(feedback.traction_recovered==0.0,"Traction recovery cue did not expire")
	print("DRIVING FEEDBACK: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
