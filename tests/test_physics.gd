extends SceneTree

var failures := 0
var checks := 0
var metrics: Dictionary = {}
const H := 1.0/240.0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		if failures < 25: push_error(message)
		failures += 1

func vehicle(spec: Dictionary = {}) -> Drivetrain:
	var c := Drivetrain.new()
	if not spec.is_empty(): c.configure_vehicle(spec)
	c.configure(GameCatalog.blank_stages())
	c.reset()
	c.running = true
	return c

func valid(c: Drivetrain) -> bool:
	for value in [c.rpm,c.speed,c.distance,c.engine_torque,c.clutch_torque,c.wheel_omega,c.slip_ratio,c.boost,c.acceleration]:
		if not is_finite(value): return false
	return c.rpm >= 0.0 and c.speed >= 0.0 and c.nitrous_remaining >= 0.0 and c.gear >= 0 and c.gear <= c.gear_ratios.size()

func quarter(spec: Dictionary, stages: Array) -> Dictionary:
	var c := vehicle(spec)
	c.configure(stages)
	c.reset()
	c.running = true
	c.rpm = 3900.0
	var previous := 0.0
	for tick in 14400:
		if c.rpm >= c.redline_rpm-550.0 and c.wheel_rpm(c.gear) >= c.redline_rpm-1500.0: c.shift(1)
		previous = c.distance
		c.step(H,1.0)
		if c.distance >= 402.336:
			var t := c.elapsed-H+H*(402.336-previous)/(c.distance-previous)
			return {"et":t,"mph":c.speed*Drivetrain.MPH_PER_MPS,"distance":402.336,"clamps":c.safety_clamps}
	return {"et":60.0,"mph":0.0,"distance":c.distance,"clamps":c.safety_clamps}

func rate_run(rate: int) -> Dictionary:
	var c := vehicle()
	c.rpm = 3900.0
	var commands := [2.5,5.5,9.5]
	var command := 0
	var wall := 0.0
	for frame in rate*20:
		var ending := float(frame+1)/rate
		while command < commands.size() and float(commands[command]) <= ending+0.000000001:
			c.step(float(commands[command])-wall,1.0)
			wall = commands[command]
			c.shift(1)
			command += 1
		if ending-wall > 0.000000001: c.step(ending-wall,1.0)
		wall = ending
	return c.telemetry()

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation")
	var c := vehicle()
	c.gear = 0
	for tick in 720: c.step(H,1.0)
	check(c.speed == 0.0 and c.distance == 0.0,"Neutral revving moved the vehicle")
	check(c.rpm > c.redline_rpm-300,"Neutral throttle did not rev the engine")
	var revved := c.rpm
	for tick in 1440: c.step(H,0.0)
	check(c.rpm < revved-1000 and absf(c.rpm-c.idle_rpm) < 30,"Throttle release did not settle to idle")
	for tick in 4800: c.step(H,0.0)
	check(absf(c.rpm-c.idle_rpm) < 5 and c.safety_clamps == 0,"Idle is unstable or uses a safety clamp")
	metrics.idle_rpm = c.rpm
	var light := vehicle({"inertia":0.12})
	var heavy := vehicle({"inertia":0.40})
	light.gear = 0
	heavy.gear = 0
	for tick in 48:
		light.step(H,1.0)
		heavy.step(H,1.0)
	check(light.rpm-heavy.rpm > 500,"Engine inertia does not influence RPM rise")
	c = vehicle()
	for tick in 480: c.step(H,1.0,0.0,1.0)
	check(c.speed == 0.0 and c.rpm > 6500,"Open clutch did not allow stationary revving")
	for tick in 240: c.step(H,1.0)
	check(c.speed > 1.0 and c.clutch_torque > 0.0,"Clutch re-engagement did not transfer torque")
	for g in range(1,7):
		c = vehicle()
		var v := 5000.0/(60.0/TAU)/(Drivetrain.RATIOS[g-1]*Drivetrain.FINAL_DRIVE)*Drivetrain.TIRE_RADIUS
		c.set_road_state(v,g,5000)
		c.clutch_engagement = 1.0
		for tick in 240: c.step(H,0.25)
		check(absf(c.rpm-c.wheel_rpm(g)) < 2.0,"RPM-to-road relationship wrong in gear %d" % g)
		check(absf(c.wheel_omega*c.tire_radius-c.speed) < 0.001,"No-slip wheel speed wrong in gear %d" % g)
	c = vehicle()
	c.set_road_state(28.0,3)
	c.clutch_engagement = 1.0
	var initial_rpm := c.rpm
	var initial_speed := c.speed
	check(c.shift(1),"Upshift rejected")
	c.step(H,0.3)
	check(c.gear == 4 and c.fuel_cut and absf(c.clutch_torque) < 0.001,"Upshift did not interrupt torque")
	check(absf(c.speed-initial_speed) < 0.1,"Upshift created a speed discontinuity")
	for tick in 180: c.step(H,0.3)
	check(c.rpm < initial_rpm-500 and absf(c.rpm-c.wheel_rpm(4)) < 5,"Upshift RPM did not settle to the new ratio")
	var low_rpm := c.rpm
	check(c.shift(-1),"Safe downshift rejected")
	for tick in 180: c.step(H,0.3)
	check(c.rpm > low_rpm+500 and absf(c.rpm-c.wheel_rpm(3)) < 5,"Downshift rev match did not settle")
	var transitions: Array = []
	for from_gear in range(1,6):
		c = vehicle({"grip":1.8})
		c.set_road_state(5000.0/Drivetrain.RPM_PER_RAD/c.ratio_for(from_gear)*c.tire_radius,from_gear,5000.0)
		c.clutch_engagement = 1.0
		c.shift(1)
		for tick in 180: c.step(H,0.25)
		var up_error := c.rpm-c.wheel_rpm(from_gear+1)
		check(absf(up_error) < 5.0,"Upshift did not lock to ratio for gear %d" % (from_gear+1))
		var up_rpm := c.rpm
		c.shift(-1)
		for tick in 180: c.step(H,0.25)
		var down_error := c.rpm-c.wheel_rpm(from_gear)
		check(c.rpm > up_rpm and absf(down_error) < 5.0,"Downshift did not lock to ratio for gear %d" % from_gear)
		transitions.append({"from_gear":from_gear,"up_locked_error_rpm":up_error,"down_locked_error_rpm":down_error})
	metrics.paddle_transitions = transitions
	c.shift_left = 0.0
	c.set_road_state(65.0,3)
	check(not c.shift(-1) and c.gear == 3,"Unsafe downshift was not protected")
	c = vehicle()
	c.running = false
	check(c.shift(-1) and c.gear == 0,"Paddles cannot select neutral during staging")
	c = vehicle({"grip":1.8})
	var taller := vehicle({"grip":1.8})
	c.set_road_state(5000/(60.0/TAU)/c.ratio_for(1)*c.tire_radius,1,5000)
	taller.set_road_state(5000/(60.0/TAU)/taller.ratio_for(4)*taller.tire_radius,4,5000)
	c.clutch_engagement = 1.0
	taller.clutch_engagement = 1.0
	c.throttle = 1.0
	taller.throttle = 1.0
	for tick in 24:
		c.step(H,1.0)
		taller.step(H,1.0)
	check(c.traction_force > taller.traction_force*1.5,"Lower gear does not multiply wheel torque")
	var slippery := vehicle({"grip":0.1})
	var sticky := vehicle({"grip":1.1})
	slippery.rpm = 3900.0
	sticky.rpm = 3900.0
	for tick in 240:
		slippery.step(H,1.0)
		sticky.step(H,1.0)
		check(absf(slippery.traction_force) <= slippery.available_traction+0.01,"Tire exceeded the friction limit")
	check(slippery.wheel_omega*slippery.tire_radius > slippery.speed+1.0 and slippery.wheelspin > sticky.wheelspin,"Insufficient grip does not produce real wheelspin")
	c = vehicle()
	c.gear = 0
	var maximum_rpm := 0.0
	var minimum_after_limit := INF
	var cut_count := 0
	for tick in 4800:
		c.step(H,1.0)
		maximum_rpm = maxf(maximum_rpm,c.rpm)
		if tick > 1000:
			minimum_after_limit = minf(minimum_after_limit,c.rpm)
			if c.fuel_cut: cut_count += 1
	check(maximum_rpm < c.redline_rpm+150 and minimum_after_limit > c.redline_rpm-250 and cut_count > 0,"Limiter does not hold a stable fuel-cut band")
	check(c.safety_clamps == 0,"Limiter relies on a hard RPM safety clamp")
	metrics.limiter_band = [minimum_after_limit,maximum_rpm]
	var engaged := vehicle()
	var coasting := vehicle()
	engaged.set_road_state(30.0,3)
	coasting.set_road_state(30.0,3)
	engaged.clutch_engagement = 1.0
	coasting.clutch_engagement = 1.0
	for tick in 480:
		engaged.step(H,0.0)
		coasting.step(H,0.0,0.0,1.0)
	check(engaged.speed < coasting.speed-0.5,"Closed-clutch engine braking is missing")
	c = vehicle()
	c.set_road_state(30.0,3)
	for tick in 1200: c.step(H,0.0,1.0,1.0)
	check(c.speed < 0.05 and c.speed >= 0.0,"Braking did not stop the car without reversing")
	var boosted := vehicle()
	var baseline := vehicle()
	for item in [boosted,baseline]:
		item.set_road_state(40.0,4)
		item.clutch_engagement = 1.0
		item.throttle = 1.0
	for tick in 240:
		boosted.step(H,1.0,0.0,0.0,true)
		baseline.step(H,1.0)
	check(boosted.speed > baseline.speed+0.3 and boosted.nitrous_remaining < 5.1,"Nitrous does not add physical torque")
	var remaining := boosted.nitrous_remaining
	boosted.step(0.1,1.0,0.0,1.0,true)
	check(boosted.nitrous_remaining == remaining and not boosted.nitrous_active,"Nitrous sprays with clutch disengaged")
	c = vehicle()
	c.gear = 0
	for tick in 360: c.step(H,1.0)
	var loaded_boost := c.boost
	for tick in 120: c.step(H,0.0)
	check(loaded_boost > 0.3 and c.boost < loaded_boost*0.2,"Boost spool/decay is disconnected from throttle")
	var stock := quarter(GameCatalog.spec("kaze"),GameCatalog.blank_stages())
	var built := quarter(GameCatalog.spec("kaze"),[3,3,3,3,3,3,3,3])
	metrics.stock_quarter = stock
	metrics.upgraded_quarter = built
	check(stock.et > 10 and stock.et < 20 and built.et < stock.et-0.7,"Quarter-mile/upgrade performance is invalid")
	check(stock.clamps == 0 and built.clamps == 0,"Quarter-mile required a safety clamp")
	var base_rate := rate_run(60)
	var maximum_distance_error := 0.0
	for rate in [30,60,120,144]:
		var result := rate_run(rate)
		maximum_distance_error = maxf(maximum_distance_error,absf(result.distance_m-base_rate.distance_m))
		check(absf(result.distance_m-base_rate.distance_m) < 0.0001 and absf(result.rpm-base_rate.rpm) < 0.001,"Results depend on caller frame rate %d" % rate)
	metrics.frame_rate_max_distance_error_m = maximum_distance_error
	var rng := RandomNumberGenerator.new()
	rng.seed = 62891
	for id in GameCatalog.CAR_IDS:
		for tier in [0,3]:
			c = vehicle(GameCatalog.spec(id))
			c.configure([tier,tier,tier,tier,tier,tier,tier,tier])
			c.reset()
			c.running = true
			var gas := 0.0
			var brake := 0.0
			var clutch := 0.0
			for tick in 2400:
				if tick % 24 == 0:
					gas = rng.randf()
					brake = 1.0 if rng.randf() < 0.12 else 0.0
					clutch = 1.0 if rng.randf() < 0.15 else 0.0
					if rng.randf() < 0.25: c.shift(1 if rng.randf() > 0.3 else -1)
				c.step(H,gas,brake,clutch,true)
				check(valid(c),"Invalid physics state in "+id)
			check(c.safety_clamps == 0,"Catalog stress run required a safety clamp: "+id)
	var frozen := c.telemetry()
	c.step(NAN,1.0)
	c.step(0.1,NAN)
	check(c.invalid_inputs == 2 and c.telemetry() == frozen,"Invalid inputs corrupted the simulation")
	metrics.checks = checks
	metrics.failures = failures
	var f := FileAccess.open("res://validation/physics_test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics,"\t"))
	print("COUPLED PHYSICS: ",checks," checks / ",failures," failures")
	print(JSON.stringify(metrics))
	quit(0 if failures == 0 else 1)

