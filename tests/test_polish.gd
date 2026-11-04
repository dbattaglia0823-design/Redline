extends SceneTree

var failures := 0
var checks := 0
var metrics: Dictionary = {}
const H := 1.0/240.0

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func car_at(gear: int = 3) -> Drivetrain:
	var c := Drivetrain.new()
	c.configure_vehicle(GameCatalog.spec("kaze"))
	c.reset()
	c.running = true
	c.set_road_state(24.0,gear)
	c.clutch_engagement = 1.0
	return c

func throttle_time(spec: Dictionary, tier: int) -> float:
	var c := Drivetrain.new()
	c.configure_vehicle(spec)
	c.configure([tier,0,0,0,0,0,0,0])
	c.reset()
	for i in 120:
		c.step(H,1.0,0.0,1.0)
		if c.throttle >= 0.9: return (i+1)*H
	return 1.0

func rate_intents(rate: int) -> Dictionary:
	var c := car_at()
	var commands := [[0.5,1],[0.53,1],[0.55,-1],[1.5,1],[1.53,1],[2.0,-1],[2.04,-1]]
	var index := 0
	var wall := 0.0
	for frame in rate*5:
		var ending := float(frame+1)/rate
		while index < commands.size() and float(commands[index][0]) <= ending+0.000000001:
			var until := float(commands[index][0])-wall
			if until > 0.000000001: c.step(until,0.6)
			wall = float(commands[index][0])
			c.request_shift(int(commands[index][1]))
			index += 1
		if ending-wall > 0.000000001: c.step(ending-wall,0.6)
		wall = ending
	return c.telemetry()

func _initialize() -> void:
	var c := car_at()
	check(c.request_shift(1) == "SHIFT ACCEPTED" and c.gear == 4,"First tap was not recognized immediately")
	check(c.request_shift(1) == "SHIFT QUEUED" and c.gear == 4,"Busy tap was not latched exactly once")
	for tap in 8: c.request_shift(1)
	for tick in 240: c.step(H,0.5)
	check(c.gear == 5 and c.queued_shift == 0 and c.shift_serial == 2,"Burst taps created extra shifts or lost the one pending intent")
	c = car_at()
	c.request_shift(1)
	c.request_shift(1)
	check(c.request_shift(-1) == "SHIFT CANCELED" and c.queued_shift == 0,"Opposite tap did not cancel the pending shift")
	for tick in 240: c.step(H,0.5)
	check(c.gear == 4,"Canceling produced an unexpected opposite shift")
	c.request_shift(1)
	c.request_shift(1)
	c.cancel_shift_request()
	for tick in 240: c.step(H,0.5)
	check(c.gear == 5,"Cleared intent executed after cancellation")
	c = car_at(1)
	c.set_road_state(0.0,0)
	check(c.request_shift(-1) == "GEAR LIMIT" and c.gear == 0,"Neutral underflow changed gear")
	c.set_road_state(30.0,6)
	check(c.request_shift(1) == "GEAR LIMIT" and c.gear == 6,"Top-gear overflow changed gear")
	c.set_road_state(65.0,3)
	check(c.request_shift(-1) == "DOWNSHIFT PROTECTED" and c.gear == 3,"Immediate tap bypassed over-rev protection")
	# Recheck protection at execution, even if wheel speed changed after queuing.
	c = car_at(4)
	c.request_shift(-1)
	c.request_shift(-1)
	c.set_road_state(65.0,3)
	for tick in 48: c.step(H,1.0,0.0,1.0)
	check(c.gear == 3 and c.queued_shift == 0 and c.shift_request_status == "SHIFT PROTECTED","Queued downshift bypassed current wheel-speed protection")
	var response_rows: Array = []
	for id in GameCatalog.CAR_IDS:
		var stock_t := throttle_time(GameCatalog.spec(id),0)
		var built_t := throttle_time(GameCatalog.spec(id),3)
		check(stock_t <= 0.09 and built_t < stock_t,"Dealer throttle response is delayed or ignores engine upgrade: "+id)
		response_rows.append({"vehicle":id,"stock_t90_s":stock_t,"engine3_t90_s":built_t})
	metrics.throttle_response = response_rows
	var transmission_rows: Array = []
	for tier in range(4):
		c = car_at()
		c.configure([0,0,0,0,tier,0,0,0])
		c.request_shift(1)
		var cut_time := 0.0
		var recovery := 0.0
		for tick in 240:
			c.step(H,0.7)
			if c.fuel_cut: cut_time += H
			if recovery == 0.0 and c.clutch_engagement >= 0.9: recovery = (tick+1)*H
		check(absf(cut_time-c.shift_duration) <= H*1.1,"Transmission torque-cut duration is wrong")
		transmission_rows.append({"tier":tier,"cut_s":cut_time,"clutch_90_s":recovery})
	check(transmission_rows[3].clutch_90_s < transmission_rows[0].clutch_90_s-0.1,"Race transmission clutch did not recover faster")
	metrics.transmissions = transmission_rows
	c = car_at()
	c.set_road_state(7050.0/Drivetrain.RPM_PER_RAD/c.ratio_for(3)*c.tire_radius,3,7050.0)
	check(c.shift_recommended(),"Settled in-band gear did not receive a shift cue")
	c.rpm = c.redline_rpm-30.0
	check(c.upshift_ready() and not c.shift_recommended(),"Late shift reminder disappeared above the perfect window")
	c.wheelspin = 0.5
	check(not c.shift_recommended(),"Shift guide encouraged changing gear during wheelspin")
	c.wheelspin = 0.0
	c.clutch_engagement = 0.0
	check(not c.shift_recommended(),"Shift guide ignored the open clutch")
	c.set_road_state(7050.0/Drivetrain.RPM_PER_RAD/c.ratio_for(3)*c.tire_radius,3,7050.0)
	c.request_shift(1)
	check(c.shift_message == "CLUTCH SHIFT","In-band manual clutch shift was mislabeled as late")
	# Visual sampling, camera shake and smoke must never feed back into the solver.
	var untouched := car_at(1)
	c = car_at(1)
	var visual := RaceFeedback.new()
	visual.reset(c)
	var greatest_camera := 0.0
	for tick in 1440:
		c.step(H,1.0)
		untouched.step(H,1.0)
		visual.update(H,c,false,GameCatalog.spec("kaze"))
		greatest_camera = maxf(greatest_camera,visual.camera_offset.length())
		check(visual.smoke.size() <= 48,"Smoke allocation is unbounded")
	check(c.telemetry() == untouched.telemetry(),"Presentation modified the physical result")
	check(greatest_camera < 5.1,"Camera motion is excessive")
	var frozen_visual := visual.visual_rpm
	visual.update(0.2,c,true,GameCatalog.spec("kaze"))
	check(visual.visual_rpm == frozen_visual,"Paused gauges continued moving")
	metrics.camera_max_pixels = greatest_camera
	# Smoke follows the actual driven axle and fades after traction recovery.
	var smoke_origins: Dictionary = {}
	for id in GameCatalog.CAR_IDS:
		c = Drivetrain.new()
		c.configure_vehicle(GameCatalog.spec(id))
		c.reset()
		c.running = true
		c.wheelspin = 1.0
		c.throttle = 1.0
		visual.reset(c)
		visual.update(1.0/30.0,c,false,GameCatalog.spec(id))
		check(visual.smoke.size() > 0,"Wheelspin produced no smoke")
		var x: float = visual.smoke[0].position.x
		check((x > 450.0) if c.drivetrain == "FWD" else (x < 350.0),"Smoke came from the wrong driven axle")
		smoke_origins[id] = x
		c.wheelspin = 0.0
		for frame in 90: visual.update(1.0/60.0,c,false,GameCatalog.spec(id))
		check(visual.smoke.is_empty(),"Smoke did not clear after traction recovered")
	metrics.smoke_origin_x = smoke_origins
	var rate_reference := rate_intents(60)
	for rate in [30,60,120,144]:
		check(rate_intents(rate) == rate_reference,"Paddle latch behavior depends on caller frame rate")
	c = Drivetrain.new()
	c.configure_vehicle({"ratios":[3.6,2.1,1.4,1.0],"final_drive":4.2,"redline":8000,"tire_radius":0.29})
	c.reset()
	c.running = true
	c.set_road_state(5000.0/Drivetrain.RPM_PER_RAD/c.ratio_for(3)*c.tire_radius,3,5000.0)
	c.clutch_engagement = 1.0
	c.request_shift(1)
	for tick in 240: c.step(H,0.35)
	check(c.gear == 4 and absf(c.rpm-c.wheel_rpm(4)) < 5.0 and c.safety_clamps == 0,"Custom four-speed gearing regressed")
	metrics.checks = checks
	metrics.failures = failures
	var f := FileAccess.open("res://validation/polish_test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics,"\t"))
	print("PADDLE INTENTS + RESPONSE + PRESENTATION ISOLATION: ",checks," checks / ",failures," failures")
	quit(0 if failures == 0 else 1)
