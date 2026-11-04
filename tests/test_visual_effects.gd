extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool,msg: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void:
	var c := Drivetrain.new(); c.configure_vehicle(GameCatalog.spec("kaze")); c.reset(); c.running = true
	c.gear = 0
	for i in 480: c.step(1.0/240.0,1,0,1)
	check(WheelVisuals.motion(c,true).omega == 0 and c.rpm > 6000,"Engine RPM animated stationary wheels")
	c.set_road_state(20,2); var before := WheelVisuals.motion(c,true)
	check(before.angle == c.wheel_angle and before.omega == c.wheel_omega,"Driven wheel state is disconnected")
	check(c.shift(1) and WheelVisuals.motion(c,true).omega == before.omega and WheelVisuals.motion(c,true).angle == before.angle,"Gear selection invented a wheel-speed or phase jump")
	check(absf(float(WheelVisuals.motion(c,false).omega)-c.speed/c.tire_radius) < .0001,"Free-wheel rolling speed incorrect")
	c.wheel_omega = 160; c.speed = 0
	check(float(WheelVisuals.motion(c,true).blur) > .99 and WheelVisuals.motion(c,false).blur == 0,"Burnout effects use road speed instead of driven axle")
	check(WheelVisuals.motion(c,true,0).spoke_angle == c.wheel_angle and WheelVisuals.motion(c,true,0).angle == c.wheel_angle,"Low-quality wheels lost physical rotation")
	c.reset(); c.running = true; c.set_road_state(35,4); c.clutch_engagement = 1
	var start_speed := float(WheelVisuals.motion(c,true).omega)
	for i in 1440: c.step(1.0/240.0,0,1)
	check(float(WheelVisuals.motion(c,true).omega) < start_speed*.1,"Brake did not slow wheel effects")
	var slippery := GameCatalog.spec("kaze").duplicate(true); slippery.grip = .10
	c.configure_vehicle(slippery); c.reset(); c.running = true
	for i in 480: c.step(1.0/240.0,1,1)
	check(c.wheel_omega > c.speed/c.tire_radius+30 and c.speed < .05,"Burnout fixture did not produce physical driven-wheel slip")
	check(float(WheelVisuals.motion(c,true).blur) > .2 and float(WheelVisuals.motion(c,false).blur) < .01,"Physical burnout visualization disconnected")
	var reference: Dictionary = {}
	for rate in [30,60,120,144]:
		c.configure_vehicle(GameCatalog.spec("kaze")); c.reset(); c.running = true
		for i in rate*4: c.step(1.0/rate,1)
		var state := WheelVisuals.motion(c,true)
		if reference.is_empty(): reference = state
		else: check(absf(float(state.angle)-float(reference.angle)) < .00001 and absf(float(state.omega)-float(reference.omega)) < .00001,"Wheel effects differ across frame rates")
	var visual := RaceFeedback.new()
	for id in GameCatalog.CAR_IDS:
		c.configure_vehicle(GameCatalog.spec(id)); c.configure_build(VehicleBench.fixture("legacy6",["drag_wheels"]),id,false)
		var expected := c.tire_radius/float(GameCatalog.spec(id).get("tire_radius",.315))
		check(absf(WheelVisuals.radius_scale(c,GameCatalog.spec(id))-expected) < .0001,"Installed tire visual size incorrect: "+id)
		for quality in 3:
			c.reset(); c.running = true; c.wheelspin = 1; c.throttle = 1
			visual.reset(c); visual.set_quality(quality)
			for i in 240: visual.update(1.0/120,c,false,GameCatalog.spec(id))
			check(visual.smoke.size() <= int([8,24,48][quality]),"Smoke allocation exceeded preset")
			check(visual.body_offset.length() < 2 and absf(visual.body_pitch) <= .0061,"Body effects exaggerated")
			var snapshot := c.telemetry(); var frozen := visual.body_offset
			visual.update(.1,c,true,GameCatalog.spec(id))
			check(visual.body_offset == frozen and c.telemetry() == snapshot,"Paused visual state or physics changed")
	# Quality selection survives existing saves; default old saves use High.
	var p := DriverProfile.new(); p.effects_quality = 0; p.save()
	var restored := DriverProfile.new(); restored.load_profile()
	check(restored.effects_quality == 0,"Effects preference did not persist")
	print("WHEEL MOTION / BURNOUT / BRAKING / TIRE SIZES / QUALITY: ",checks," checks; ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

