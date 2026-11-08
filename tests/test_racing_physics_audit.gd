extends SceneTree

const H := Drivetrain.FIXED_DT
var checks := 0
var failures := 0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25: push_error(message)

func car(model: String="mustang",trans: String="",stages: Array=[],parts: Array=[]) -> Drivetrain:
	var c:=Drivetrain.new()
	c.configure_vehicle(GameCatalog.spec(model))
	c.configure(GameCatalog.blank_stages() if stages.is_empty() else stages)
	var b:=GameCatalog.factory_build(model)
	if trans!="": b.transmission=trans; b.owned_transmissions.append(trans)
	for id in parts: b.owned_parts.append(id); b.parts[VehicleParts.PARTS[id].slot]=id
	c.configure_build(b,model,false)
	c.reset()
	return c

func energy(c: Drivetrain) -> float:
	return .5*c.mass()*c.speed*c.speed+.5*c.engine_inertia*pow(c.rpm/Drivetrain.RPM_PER_RAD,2)+.5*c.wheel_inertia*c.wheel_omega*c.wheel_omega

func _initialize() -> void:
	# A light throttle must not leave a road automatic pinned in first gear.
	var auto:=car()
	auto.running=true
	for i in 3600: auto.step(H,.28)
	check(auto.gear>=3 and auto.speed>10,"Part-throttle automatic did not upshift")
	check(not auto.limiter,"Part-throttle automatic reached the limiter")
	check(auto.shift_serial<16,"Automatic hunts repeatedly between adjacent gears")
	auto.set_road_state(30,8); auto.throttle=1; auto.shift_left=0; auto._auto_dwell=0
	auto.step(H,1)
	check(auto.gear==7 and auto.last_shift_rpm<4000,"Loaded automatic did not kick down into a useful lower gear")
	check(auto.wheel_rpm(auto.gear)<auto.redline_rpm,"Kickdown permitted mechanical overrev")
	var drag:=car("mustang","drag3")
	drag.throttle=.25
	check(drag.automatic_shift_target(1)==drag.redline_rpm-100,"Drag automatic adopted an economy shift schedule")

	# Default converter sizing follows the installed engine, rather than the NA
	# base torque. Both stock and built engines should load near rated stall.
	for stages in [GameCatalog.blank_stages(),[3,3,0,0,5,3,0,0]]:
		var c:=car("mustang","auto10",stages)
		c.running=true; c.has_transbrake=true
		for i in 1200: c.step(H,1,0,0,false,true)
		check(absf(c.rpm-c.converter_stall)<c.converter_stall*.20,"Default converter does not load the installed engine near stall")
		check(c.speed==0 and c.distance==0 and c.converter_heat_w>0,"Stalled converter did not hold chassis / dissipate energy")
		check(c.safety_clamps==0,"Converter relied on an RPM safety clamp")

	# Overload is a capacity-limited coupling, not an engine torque governor.
	var weak:=car("mustang","manual3",[3,0,0,0,0,3,0,0])
	weak.running=true; weak.set_road_state(25,2,6000); weak.clutch_engagement=1; weak.throttle=1
	weak.step(H,1)
	check(weak.engine_torque>weak.input_capacity(),"Weak transmission artificially clipped crankshaft torque")
	check(absf(weak.clutch_torque)<=weak.clutch_capacity()+.001,"Overloaded coupling exceeded its torque rating")
	check(weak.clutch_slip_rpm>150 and weak.transmission_slipping,"Overloaded transmission failed to produce actual slip")

	# Turbo free revving differs from loaded boost; Roots responds without
	# exhaust load. No changes to rated full-load torque curves are needed.
	var free:=car("gti")
	free.gear=0
	for i in 720: free.step(H,1)
	var free_pressure:=free.boost
	var loaded:=car("gti")
	loaded.running=true; loaded.set_road_state(40,4); loaded.clutch_engagement=1; loaded.throttle=1
	for i in 240: loaded.step(H,1)
	check(loaded.boost>free_pressure*2,"Turbo boost does not respond to engine load")
	var roots:=car("gt500")
	roots.gear=0
	for i in 720: roots.step(H,1)
	check(roots.boost>.8,"Roots supercharger incorrectly requires exhaust load")
	var launch:=car("gti","",[],["ecu"])
	check(RaceAI.launch_target(launch)==launch.launch_rpm,"AI ignores default ECU launch-control RPM")
	for i in 720: launch.step(H,1,0,1)
	check(absf(launch.rpm-launch.launch_rpm)<200,"Launch control did not hold its RPM band")
	check(launch.boost>free_pressure,"Launch control did not build staging boost")

	# Preserve every gear-count family, finite inertia-driven RPM changes, and
	# traction-limited impulses through all retained transmission configurations.
	var counts: Dictionary={}
	for trans in ["drag2","drag3","auto4","manual5","manual6","seq7","dct8","auto9","auto10"]:
		var c:=car("mustang",trans)
		counts[c.gear_ratios.size()]=true
		c.running=true; c.set_road_state(24,2); c.clutch_engagement=1; c.throttle=.5
		var rpm:=c.rpm; var speed:=c.speed
		if c.control_mode=="hpattern": c.select_manual_gear(3,1)
		elif c.gear_ratios.size()>2: c.shift(1)
		check(c.rpm==rpm and c.speed==speed,"Selecting a gear directly changed engine RPM or vehicle speed: "+trans)
		for i in 240:
			c.step(H,.5)
			check(is_finite(c.rpm) and c.rpm>=0 and is_finite(c.speed) and c.speed>=0,"Invalid drivetrain state: "+trans)
			check(absf(c.traction_force)<=c.available_traction+.01,"Tire impulse exceeded traction: "+trans)
		check(c.safety_clamps==0,"Transmission required RPM clamps: "+trans)
		check(TransmissionCatalog.duration(trans,5)<=TransmissionCatalog.duration(trans,0),"Upgrades did not improve shift time: "+trans)
	for gears in range(2,11): check(counts.has(gears),"Missing supported gear count: "+str(gears))

	# Coasting cannot add kinetic energy through the coupled solver.
	var coast:=car("miata")
	coast.running=true; coast.set_road_state(30,4); coast.clutch_engagement=1
	for i in 240:
		var before:=energy(coast)
		coast.step(H,0)
		check(energy(coast)<=before+.001,"Unpowered coupled drivetrain created kinetic energy")
	coast.set_road_state(.1,1)
	for i in 240: coast.step(H,0,1,1)
	check(coast.speed==0,"Braking near zero failed to stop without reversing")
	var hybrid:=car("sf90")
	hybrid.running=true; hybrid.set_road_state(40,4); hybrid.throttle=1; hybrid.clutch_engagement=1; hybrid.hybrid_energy_j=1
	hybrid.step(H,1)
	check(hybrid.hybrid_power_w*H<=.940001 and hybrid.hybrid_energy_j==0,"Depleted hybrid battery delivered more energy than available")
	# Replay identical wall-clock pedal/brake decisions at multiple render rates.
	var reference: Dictionary={}
	for rate in [30,60,144]:
		var replay:=car()
		replay.running=true
		for frame in rate*12:
			var time: float=float(frame)/rate
			replay.step(1.0/rate,.28 if time<4 else 1.0,.6 if time>=10 else 0.0)
		if reference.is_empty(): reference=replay.telemetry()
		else:
			for field in ["rpm","mph","distance_m","boost_bar"]:
				check(absf(float(replay.telemetry()[field])-float(reference[field]))<.000001,"Part/full throttle and braking diverged with frame rate: "+field)
			check(replay.gear==int(reference.gear),"Automatic gear selection diverged with frame rate")
	print("RACING PHYSICS AUDIT: ",checks," checks / ","PASS" if failures==0 else "FAIL (%d)"%failures)
	quit(0 if failures==0 else 1)
