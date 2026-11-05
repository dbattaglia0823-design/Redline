extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func vehicle(id: String) -> Drivetrain:
	var c := Drivetrain.new()
	c.configure_vehicle(GameCatalog.spec(id)); c.configure_build(GameCatalog.factory_build(id),id,false)
	c.reset(); c.running=true
	return c
func settle(f: RaceFeedback,c: Drivetrain,seconds: float,rate: int=120) -> void:
	for i in roundi(seconds*rate): f.update(1.0/rate,c,false,GameCatalog.spec(str(c._base_spec.id)))
func _initialize() -> void:
	for id in ["miata","civic_si","gtr","demon"]:
		var c := vehicle(id)
		var f := RaceFeedback.new(); f.reset(c)
		c.acceleration=7; c.throttle=1
		var snapshot := c.telemetry()
		settle(f,c,.6)
		check(f.body_pitch<0 and f.rear_compression>f.front_compression,id+" launch did not squat rear / lift front")
		check(c.telemetry()==snapshot,id+" feedback changed drivetrain state")
		c.acceleration=-7; c.braking_force=5000; settle(f,c,.6)
		check(f.body_pitch>0 and f.front_compression>f.rear_compression,id+" braking did not transfer weight forward")
		c.acceleration=0; settle(f,c,2)
		check(absf(f.body_pitch)<.0001 and absf(f.body_offset.y)<.2,id+" suspension did not settle")
		for rate in [30,60,120,144]:
			f.reset(c); c.acceleration=8
			settle(f,c,2,rate)
			check(absf(f.body_pitch)<.0061 and f.body_offset.length()<2,id+" unstable suspension at "+str(rate))
		c.wheelspin=1; c.throttle=1; c.wheel_omega=140; c.speed=0
		for quality in 3:
			f.reset(c); f.set_quality(quality); settle(f,c,1)
			check(f.smoke.size()>0 and f.smoke.size()<=int([8,24,48][quality]),id+" smoke budget/emission")
			var d := VehicleAppearance.definition(id)
			var rear: float=210+VehicleAppearance.point(d.rear).x*.3828
			var front: float=210+VehicleAppearance.point(d.front).x*.3828
			var at_front := false; var at_rear := false
			for particle in f.smoke:
				if particle.age<1.0:
					at_front = at_front or absf(particle.position.x-front)<35
					at_rear = at_rear or absf(particle.position.x-rear)<35
			check((at_front if c.drivetrain=="FWD" else (at_front and at_rear if c.drivetrain=="AWD" else at_rear)),id+" smoke on incorrect driven axle")
		c.throttle=0; c.wheelspin=0; settle(f,c,1.5)
		check(f.smoke.is_empty(),id+" smoke did not expire")
		f.reset(c); c.throttle=1; c.rpm=6000; c.last_shift_rpm=6000; c.last_shift_load=.9; c.shift_serial=2
		f.update(.016,c,false,GameCatalog.spec(id))
		check(f.exhaust_glow==0,id+" stock car produced a shift flame")
		c.exhaust_stage=2; c.shift_serial=4
		f.update(.016,c,false,GameCatalog.spec(id))
		check(f.exhaust_glow>.2,id+" hot upgraded shift did not pulse backfire")
		settle(f,c,1); check(f.exhaust_glow<.001,id+" backfire remained latched")
		c.throttle=1; c.rpm=6000; settle(f,c,.8)
		for i in 12:
			c.throttle=maxf(0,1-float(i+1)/12)
			f.update(.016,c,false,GameCatalog.spec(id))
		check(f.exhaust_glow>.1,id+" gradual throttle lift did not trigger eligible backfire")
		settle(f,c,1)
		c.nitrous_active=true; c.nitrous_delivery=.8; settle(f,c,.3)
		check(f.nitrous_glow>.7 and f.exhaust_glow<.001,id+" nitrous invented sustained exhaust flames")
		c.nitrous_active=false; c.boost=.8; settle(f,c,.5)
		check(f.boost_haze>.15 and f.nitrous_glow<.01,id+" boost/nitrous feedback did not follow state")
		var frozen := f.body_pitch; var count := f.smoke.size()
		f.update(.1,c,true,GameCatalog.spec(id)); check(f.body_pitch==frozen and f.smoke.size()==count,id+" paused effects moved")
		f.update(.1,c,false,GameCatalog.spec(id),Vector2.ZERO,true)
		check(f.camera_offset==Vector2.ZERO,id+" Reduced Motion camera shake")
		f.reset(c); check(f.smoke.is_empty() and f.exhaust_glow==0 and f.body_pitch==0,id+" reset leaked state")
	# Same acceleration, installed suspension: drag setup travels further than
	# street, while greater mass changes the transient rather than gravity.
	var c := vehicle("miata"); c.acceleration=7
	c.hardware.parts.suspension="street_susp"; c.load_transfer_scale=.14
	var street := RaceFeedback.new(); street.reset(c); settle(street,c,.4)
	c.hardware.parts.suspension="drag_susp"; c.load_transfer_scale=.25
	var drag := RaceFeedback.new(); drag.reset(c); settle(drag,c,.4)
	check(absf(drag.body_pitch)>absf(street.body_pitch)*1.25,"Suspension packages have identical travel")
	c.hardware.parts.erase("suspension"); c.load_transfer_scale=.18
	var light := RaceFeedback.new(); light.reset(c); settle(light,c,.08)
	c.base_mass=2200
	var heavy := RaceFeedback.new(); heavy.reset(c); settle(heavy,c,.08)
	check(absf(heavy.body_pitch)<absf(light.body_pitch),"Mass did not affect spring response")
	print("MOTION / FOUR CLASSES / AXLE SMOKE / SPRINGS / BACKFIRE / NITROUS / PAUSE: ",checks," checks; ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
