extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool,msg: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void:
	var a := Drivetrain.new(); var b := Drivetrain.new(); var stage := RaceStaging.new()
	stage.reset(a,b)
	check(stage.beam(0) and stage.beam(0,true),"Initial shallow stage must break both beams")
	stage.observe(0,0,.1,-2,.1)
	check(stage.beam(0) and not stage.beam(0,true),"Pre-stage and stage beams are not spatially separate")
	stage.reset(a,b); stage.observe(0,0,.4,-.2,.1)
	check(stage.red_light and stage.reactions[0] < 0 and not stage.beam(0),"Early physical rollout did not latch red")
	var rt := stage.reactions[0]; stage.observe(0,.4,1,1,.1); check(stage.reactions[0] == rt,"Reaction recorded twice")
	stage.reset(a,b); stage.observe(0,0,.4,.2,.1)
	check(not stage.red_light and stage.reactions[0]>.2 and stage.reactions[0]<.3,"Green reaction was not interpolated from beam position")
	check(absf(stage.elapsed(10)+stage.reactions[0]-10)<.000001,"ET and reaction do not sum to green-to-finish time")
	for pair in [[3,-1],[1.501,-1],[1.5,0],[1,1],[.5,2],[0,3]]: check(RaceStaging.lamp(pair[0])==pair[1],"Incorrect .5 second lamp phase")
	for trans in ["manual5","legacy6","dct6","auto10","drag3"]:
		a = Drivetrain.new(); a.configure_build(VehicleBench.fixture(trans),"kaze",false); a.reset(); a.staging_motion = true
		for i in 240: a.step(1.0/240,1,0,1 if not a.has_converter else 0)
		check(a.elapsed==0,"Staging advanced the official race clock")
		if a.has_converter: check(a.distance>.01 and a.turbine_omega>0,"Manual staging disconnected the automatic's converter")
		if not a.has_converter and a.transmission_kind != "dct": check(a.distance<.00001,"Open clutch moved the staged car")
		a.reset(); check(not a.staging_motion,"Reset leaked manual staging into normal racing")
	a = Drivetrain.new(); a.staging_motion=true; a.grip_coefficient=.1
	for i in 600: a.step(1.0/240,1,1)
	check(a.elapsed==0 and a.distance<.01 and a.wheel_omega>20 and a.wheelspin>.2,"Physical pre-start burnout did not slip the driven wheels under brakes")
	var feedback := RaceFeedback.new(); feedback.reset(a)
	for i in 90: feedback.update(1.0/120,a,false,GameCatalog.spec("kaze"))
	check(not feedback.smoke.is_empty() and feedback.smoke.size()<=48,"Pre-start smoke ignores actual wheelspin")
	var ambience := RaceAtmosphere.new(); stage.reset(a,b)
	ambience.set_state(stage,3,true,false,true,0,false)
	check(ambience.cue_serial==0,"Staged hold invented a start sound")
	ambience.set_state(stage,1.5,true,false,true,0,false)
	var serial := ambience.cue_serial; ambience.set_state(stage,1.5,true,false,true,0,false)
	check(serial==1 and ambience.cue_serial==serial,"Steady amber repeated its cue")
	var peak := 0.0; var jump := 0.0; var previous := 0.0
	for i in 22050:
		if i==6000: ambience.set_state(stage,0,true,false,true,45,false)
		if i==12000: ambience.set_state(stage,0,true,false,true,45,true)
		if i==18000: ambience.set_state(stage,0,true,true,true,45,true)
		var value := ambience.next_sample(); check(is_finite(value),"Invalid ambience sample")
		peak=maxf(peak,absf(value)); jump=maxf(jump,absf(value-previous)); previous=value
	check(peak<.15 and peak>.01 and jump<.05,"Track mix overpowered engine or introduced a sharp discontinuity")
	ambience.set_state(stage,3,false,false,false,0,false)
	for i in 6000: ambience.next_sample()
	check(absf(ambience.next_sample())<.00001 and ambience.cue_gain<.00001,"Muted/inactive cue stayed latched")
	var foul := RaceAtmosphere.new(); stage.red_light=true
	foul.set_state(stage,1,true,false,true,0,false)
	serial=foul.cue_serial; foul.set_state(stage,0,true,false,true,0,false)
	check(foul.cue_serial==serial,"Red lane played a green-start cue")
	foul.set_state(stage,0,true,false,true,30,true,false)
	check(foul.cue_hz==440 and foul.cheer<.2,"Foul or losing run played victory feedback")
	print("STAGING BEAMS / CLOCK / RED LIGHT / PHYSICAL BURNOUT / ORIGINAL AMBIENCE: ","PASS" if failures==0 else "FAIL"," / ",checks," checks / peak ",peak," jump ",jump)
	quit(0 if failures==0 else 1)
