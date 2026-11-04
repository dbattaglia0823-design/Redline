extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func vehicle(id: String, parts: Array = [], tune: Dictionary = {}, stage: int = 5) -> Drivetrain:
	var c := Drivetrain.new()
	c.configure_vehicle(GameCatalog.spec("kaze"))
	c.configure([0,0,0,0,stage,0,0,0])
	c.configure_build(VehicleBench.fixture(id,parts,tune))
	c.reset()
	return c

func _initialize() -> void:
	var counts: Dictionary = {}
	for id in TransmissionCatalog.ROWS:
		var c := vehicle(id)
		counts[c.gear_ratios.size()] = true
		check(c.gear_ratios.size() >= 2 and c.gear_ratios.size() <= 10,"Gear count invalid "+id)
		check(c.mass() > 1200 and c.trans_efficiency > 0.80 and c.trans_efficiency <= 0.98,"Physical specifications invalid "+id)
		check(c.shift_map.size() == c.gear_ratios.size()-1 or id == "legacy6","Missing shift map "+id)
		check(TransmissionCatalog.duration(id,5) <= TransmissionCatalog.duration(id,0),"Stage does not improve shift duration "+id)
		check(TransmissionCatalog.strength(5) > TransmissionCatalog.strength(0),"Stage strength did not improve")
		for gear in range(1,c.gear_ratios.size()+1):
			if gear > 1: check(c.gear_ratios[gear-2] > c.gear_ratios[gear-1],"Ratios not descending "+id)
			c.set_road_state(20.0,gear)
			check(absf(c.wheel_rpm(gear)-20.0/c.tire_radius*c.gear_ratios[gear-1]*c.final_drive*60.0/TAU) < 0.001,"Ratio/speed relation "+id)
	for count in range(2,11): check(counts.has(count),"Missing %d-speed configuration" % count)
	check(not TransmissionCatalog.compatible("drag3","nori") and not TransmissionCatalog.compatible("auto10","nori"),"Longitudinal conversions offered for FWD")
	check(TransmissionCatalog.compatible("manual5","nori"),"Platform-specific manual missing")
	var manual := vehicle("manual5")
	manual.set_road_state(20.0,2)
	check(manual.control_mode == "hpattern" and manual.select_manual_gear(3,0.0) == "HOLD CLUTCH","Manual shift bypassed clutch")
	check(manual.select_manual_gear(3,1.0) == "SHIFT ACCEPTED" and manual.gear == 3,"Manual H gate did not engage")
	manual.shift_left = 0.0; manual.set_road_state(70.0,5)
	check(manual.select_manual_gear(1,1.0) == "DOWNSHIFT PROTECTED","H gate allowed overrev")
	check(vehicle("manual5",["paddles"]).control_mode == "paddle","Paid paddle conversion not applied")
	check(vehicle("manual5",["selector"]).control_mode == "sequential","Sequential actuator not applied")
	var automatic := vehicle("auto10")
	check(automatic.request_shift(1) == "AUTOMATIC CONTROLLER" and automatic.gear == 1,"Factory automatic accepted paddle input")
	check(vehicle("auto10",["paddles"]).control_mode == "paddle","Paid automatic paddle controller missing")
	var drag := vehicle("drag3",["transbrake","converter_race"],{"stall":4600.0})
	drag.running = true
	for tick in 720: drag.step(1.0/240.0,1.0,0.0,0.0,false,true)
	check(drag.speed < 0.001 and drag.distance < 0.001 and drag.transbrake_active,"Transbrake did not hold vehicle")
	check(drag.rpm > 3000.0 and drag.converter_turbine_nm > drag.converter_pump_nm,"Converter launch multiplication missing")
	for tick in 720: drag.step(1.0/240.0,1.0)
	check(drag.speed > 10.0 and not drag.transbrake_active,"Transbrake release did not launch")
	check(drag.safety_clamps == 0,"Converter launch hit safety RPM clamp")
	var foot := vehicle("auto8")
	foot.running = true
	for tick in 480: foot.step(1.0/240.0,0.5,1.0)
	check(foot.speed < 0.01,"Foot brake cannot hold converter creep")
	# Passive converter energy bound tested independently of engine and road forces.
	var fluid := vehicle("drag3")
	for pump in [70.0,300.0,700.0]:
		for sr in [0.0,0.15,0.45,0.8,1.0,1.1]:
			fluid.turbine_omega = pump*sr; fluid.converter_lock = 0.0
			var before: float = 0.5*fluid.engine_inertia*pump*pump+0.5*0.12*fluid.turbine_omega*fluid.turbine_omega
			var after_pump := fluid.converter_step(1.0/240.0,pump,true,false)
			var after: float = 0.5*fluid.engine_inertia*after_pump*after_pump+0.5*0.12*fluid.turbine_omega*fluid.turbine_omega
			check(after <= before+0.00001,"Passive fluid created energy")
			check(fluid.converter_input_w+0.0001 >= fluid.converter_output_w,"Converter output power exceeds input")
	var reference: Dictionary = {}
	for rate in [30,60,120,144]:
		var c := vehicle("auto10"); c.running = true
		for tick in rate*12: c.step(1.0/rate,1.0)
		if reference.is_empty(): reference = c.telemetry()
		else:
			check(absf(c.speed*Drivetrain.MPH_PER_MPS-float(reference.mph)) < 0.0001 and absf(c.rpm-float(reference.rpm)) < 0.0001,"Automatic frame-rate divergence")
		check(c.gear > 3 and c.safety_clamps == 0,"Automatic schedule did not execute cleanly")
		check(c.converter_lock > 0.99 and absf(c.rpm-c.wheel_rpm(c.gear)) < 15.0,"Lockup converter not linked to road RPM")
	var stock := vehicle("legacy6")
	var forged := vehicle("legacy6",["forged","stroker","plenum","headers","light_wheels","ecu"],{"redline":7900.0})
	check(forged.peak_horsepower() > stock.peak_horsepower() and forged.engine_inertia != stock.engine_inertia,"Engine parts have no mechanical effect")
	check(forged.redline_rpm == 7850.0 and vehicle("legacy6",["forged"]).redline_rpm == 7600.0,"ECU/mechanical RPM limits disconnected")
	var roots := vehicle("legacy6",["roots"])
	var centrifugal := vehicle("legacy6",["centrifugal"])
	check(roots.boost_target(1500.0,1.0) > centrifugal.boost_target(1500.0,1.0),"Supercharger curves do not differ")
	var tires := vehicle("legacy6",["drag_wheels","lsd","drag_susp"])
	check(tires.tire_radius > stock.tire_radius and tires.extra_grip > 0.1 and tires.load_transfer_scale > stock.load_transfer_scale,"Chassis parts disconnected")
	var hot := vehicle("drag3"); var cool := vehicle("drag3",["race_cooling"])
	for tick in 14400:
		hot.step(1.0/240.0,1.0,0.0,1.0)
		cool.step(1.0/240.0,1.0,0.0,1.0)
	check(cool.engine_temperature < hot.engine_temperature,"Cooling does not reduce engine temperature")
	var strained := vehicle("manual3",["paddles"],{},0)
	strained.base_torque = 1000.0; strained.base_boost = 1.5; strained.running = true
	for tick in 2400: strained.step(1.0/240.0,1.0)
	check(strained.component_wear > 0.0 and absf(strained.clutch_torque) <= strained.clutch_capacity()+0.01,"Weak gearbox limits / overload wear disconnected")
	var voice := EngineVoice.new()
	for id in ["drag3","dct7","auto10","manual5"]:
		var c := vehicle(id,["roots","progressive"])
		c.running = true; c.set_road_state(25.0,2); c.clutch_engagement = 1.0; c.throttle = 1.0
		c.shift(1)
		for tick in 120:
			c.step(1.0/240.0,1.0,0.0,0.0,true)
			voice.set_from_vehicle(c,true)
			check(voice.target_rpm == c.rpm and voice.target_combustion == c.combustion_fraction and voice.target_nitrous_flow == c.nitrous_delivery,"New drivetrain audio state disconnected")
			for sample in voice.render(92): check(is_finite(sample) and absf(sample) <= 1.0,"New drivetrain audio invalid/clipped")
		check(voice.target_supercharger == 1.0 and not voice._blowoff_armed,"Supercharger audio retained turbo blowoff")
	test_purchases()
	print("TRANSMISSION + PARTS: ",checks," checks; ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

func test_purchases() -> void:
	var p := DriverProfile.new(); p.credits = 2000000
	check(p.upgrade(4,5) and p.stages[4] == 5,"Pro Race progression blocked")
	var money := p.credits
	check(p.install_transmission("manual5").begins_with("Installed") and p.credits == money-3100 and p.stages[4] == 0,"New gearbox inherits free stage upgrades")
	check(p.install_hardware("paddles").contains("Stage 2"),"Actuator stage requirement bypassed")
	p.upgrade(4,2)
	check(p.install_hardware("paddles").begins_with("Installed"),"Paddle hardware purchase failed")
	money = p.credits; p.install_hardware("paddles")
	check(p.credits == money,"Owned installed part charged twice")
	p.install_transmission("oem_miata")
	check(p.stages[4] == 5 and not p.hardware.parts.has("controls"),"Stage ownership / fitment not restored on gearbox swap")
	p.install_hardware("paddles")
	check(p.credits == money-3800,"Different gearbox fitment was free")
	p.install_transmission("manual5"); money = p.credits; p.install_hardware("paddles")
	check(p.credits == money and p.stages[4] == 2,"Previously bought gearbox/part not retained")
	money = p.credits
	check(not p.install_hardware("stroker").begins_with("Installed") and p.credits == money,"Dependency rejection charged money")
	p.install_hardware("forged"); p.install_hardware("stroker")
	check(not p.remove_hardware("internals").begins_with("Factory"),"Dependency removed under installed stroker")
	check(not p.tune_hardware("redline",8000.0) and not p.tune_hardware("boost",1.5),"Tuning bypassed hardware")
	p.install_hardware("ecu")
	check(p.tune_hardware("redline",9000.0) and p.hardware.tune.redline == 7450.0,"Stored ECU tuning does not match actual forged-engine RPM headroom")
	check(not p.tune_hardware("redline",NAN) and not p.tune_hardware("stall",INF),"Nonfinite tune accepted")
	p.install_transmission("drag3"); p.upgrade(4,5)
	p.install_hardware("converter_race"); p.install_hardware("transbrake"); p.install_hardware("race_controller"); p.install_hardware("gearset")
	check(p.tune_hardware("stall",10000.0) and p.hardware.tune.stall == 5800.0,"Converter adjustment outside range")
	check(not p.tune_hardware("ratios",[1.0,2.0,3.0]) and p.tune_hardware("ratios",[2.12,1.42,1.02]),"Invalid ratio cassette allowed / valid blocked")
	check(p.tune_hardware("shift_rpms",[6500,6800]),"Individual controller shift points blocked")
	p.save()
	var loaded := DriverProfile.new(); loaded.load_profile()
	check(loaded.hardware == p.hardware and loaded.stages == p.stages and loaded.credits == p.credits,"Transmission/parts/tune save round trip lost data")
	p.apply_tuning_preset("safe")
	check(p.hardware.tune.stall == 3200.0 and not p.hardware.tune.has("shift_rpms"),"Preset bypassed converter limit or retained manual map")
	p.buy_vehicle("civic_si"); money = p.credits
	check(not p.install_transmission("drag3").begins_with("Installed") and p.credits == money,"Incompatible gearbox charged money")
	p.select_vehicle("miata")
	check(p.hardware.transmission == "drag3" and p.stages[4] == 5,"Per-car build not preserved")

