class_name VehicleBench
extends RefCounted

var timing := RunTelemetry.new()
var beams := RaceStaging.new()
var car: Drivetrain
var strategy := "optimized"
var fixed_rpm := 7000.0
var finish_mph := 100.0 # Audit runs can continue past the quarter to measure 60–130.
var done := false
var ticks := 0
var result: Dictionary = {}
var samples: Array = []
var shifts: Array = []
var _stage := 0
var _shift_serial := 0
var _cut_time := 0.0
var _shift_time := 0.0
var _spin_time := 0.0
var _clutch_slip_time := 0.0
var _gearbox_slip_time := 0.0
var _rpm_integral := 0.0
var _rpm_min := INF
var _rpm_max := 0.0
var _shift_pending := false
var _shift_before := 0.0
const H := 1.0/240.0

static func fixture(transmission: String, parts: Array = [], tune: Dictionary = {}) -> Dictionary:
	var b := VehicleParts.default_build()
	b.transmission = transmission
	if transmission != "legacy6": b.owned_transmissions.append(transmission)
	for id in parts:
		b.owned_parts.append(id)
		b.parts[VehicleParts.PARTS[id].slot] = id
	b.tune = tune.duplicate(true)
	return b

func begin(spec: Dictionary, stages: Array, build: Dictionary, policy: String = "optimized", fixed: float = 7000.0) -> void:
	car = Drivetrain.new()
	car.configure_vehicle(spec)
	car.configure(stages)
	car.configure_build(build,str(spec.get("id","nori" if str(spec.get("drive","RWD")) == "FWD" else "kaze")))
	if car.shift_map.is_empty(): car.rebuild_shift_map()
	strategy = policy
	fixed_rpm = fixed
	if strategy == "fixed":
		for i in car.shift_map.size(): car.shift_map[i] = minf(fixed_rpm,car.redline_rpm-50.0)
	car.reset()
	ticks = 0
	done = false
	_stage = 0
	result = {"transmission":car.transmission_id,"policy":strategy,"fixed_rpm":fixed_rpm,"zero_60_s":null,"zero_100_s":null,"eighth_s":null,"quarter_s":null,"trap_mph":null,"eighth_mph":null,"mass_kg":car.mass(),"shift_map":car.shift_map.duplicate(),"gears":car.gear_ratios.duplicate(),"efficiency":car.trans_efficiency,"capacity_nm":car.input_capacity()}
	samples.clear()
	result["zero_130_s"]=null
	result["sixty_130_s"]=null
	shifts.clear()
	_cut_time = 0.0
	_shift_time = 0.0
	_spin_time = 0.0
	_clutch_slip_time = 0.0
	_gearbox_slip_time = 0.0
	_rpm_integral = 0.0
	_rpm_min = INF
	_rpm_max = 0.0
	_shift_serial = car.shift_serial
	_shift_pending = false
	for i in 480:
		var launch:=RaceAI.launch_target(car) if spec.has("id") else 3900.0
		car.step(H,clampf(0.10+(launch-car.rpm)/2500.0,0.0,1.0),0.0,1.0)
	car.running = true
	beams.reset(car,car); timing.begin(car)

func step_budget(count: int = 480) -> void:
	if done: return
	if car == null: done = true; result["error"] = "Simulation unavailable"; return
	for step in count:
		var before_v := car.speed
		var before_d := car.distance
		var before_t := car.elapsed
		var before_rpm := car.rpm
		var manual_clutch := 0.0
		if car.control_mode != "automatic" and car.gear > 0 and car.gear < car.gear_ratios.size() and car.shift_left == 0.0:
			var target: float = car.shift_map[car.gear-1]
			if car.rpm >= target and car.wheel_rpm(car.gear) >= target*0.90:
				if car.control_mode == "hpattern": car.select_manual_gear(car.gear+1,1.0)
				else: car.shift(1)
		if car.control_mode == "hpattern" and car.shift_left > 0.0: manual_clutch = 1.0
		var shifting_manual:=manual_clutch>0
		if not shifting_manual and car._base_spec.has("id"): manual_clutch=RaceAI.launch_clutch(car)
		car.step(H,0.0 if shifting_manual else 1.0,0.0,manual_clutch,car.has_nitrous())
		beams.observe(0,before_d,car.distance,before_t,H)
		timing.observe(car,before_d,before_v,before_t,H,beams)
		if car.shift_serial != _shift_serial:
			_shift_serial = car.shift_serial
			shifts.append({"at_s":before_t,"from_rpm":before_rpm,"to_gear":car.gear,"cut_s":car.shift_duration,"settled_rpm":null})
			_shift_pending = true
		if _shift_pending and car.shift_left == 0.0 and car.clutch_engagement > 0.9:
			shifts[-1].settled_rpm = car.rpm
			_shift_pending = false
		if car.shift_left > 0.0:
			_cut_time += H*(1.0-car.shift_retention)
			_shift_time += H
		if car.wheelspin > 0.10: _spin_time += H
		if car.clutch_overloaded: _clutch_slip_time += H
		if car.transmission_slipping: _gearbox_slip_time += H
		_rpm_integral += car.rpm*H
		_rpm_min = minf(_rpm_min,car.rpm)
		_rpm_max = maxf(_rpm_max,car.rpm)
		for threshold in [60.0,100.0,130.0]:
			var key := "zero_60_s" if threshold == 60.0 else ("zero_100_s" if threshold == 100.0 else "zero_130_s")
			var mps: float = threshold/Drivetrain.MPH_PER_MPS
			if result[key] == null and car.speed >= mps and before_v < mps: result[key] = before_t+H*(mps-before_v)/maxf(0.00001,car.speed-before_v)
		if result.zero_130_s!=null and result.zero_60_s!=null: result.sixty_130_s=float(result.zero_130_s)-float(result.zero_60_s)
		for distance in [201.168,402.336]:
			var key := "eighth_s" if distance < 300.0 else "quarter_s"
			if result[key] == null and car.distance >= distance:
				var fraction: float = (distance-before_d)/maxf(0.00001,car.distance-before_d)
				result[key] = before_t+H*fraction
				result["eighth_mph" if distance < 300 else "trap_mph"] = lerpf(before_v,car.speed,fraction)*Drivetrain.MPH_PER_MPS
		if ticks%12 == 0:
			var sample := car.telemetry()
			sample["wheelspin"] = car.wheelspin
			samples.append(sample)
		ticks += 1
		if (result.quarter_s != null and car.speed*Drivetrain.MPH_PER_MPS >= finish_mph) or car.elapsed >= 40.0:
			done = true
			result.merge({"reaction_s":timing.result.reaction_s,"quarter_et_s":timing.result.quarter_s,"eighth_et_s":timing.result.eighth_s,"sixty_ft_s":timing.result.sixty_ft_s})
			result.merge({"shift_count":shifts.size(),"shifts":shifts.duplicate(true),"shift_time_s":_shift_time,"effective_shift_loss_s":_cut_time,"wheelspin_s":_spin_time,"clutch_slip_s":_clutch_slip_time,"gearbox_slip_s":_gearbox_slip_time,"rpm_min":_rpm_min,"rpm_max":_rpm_max,"rpm_mean":_rpm_integral/car.elapsed,"engine_c":car.engine_temperature,"transmission_c":car.transmission_temperature,"wear":car.component_wear,"safety_clamps":car.safety_clamps})
			break

static func run(spec: Dictionary, stages: Array, build: Dictionary, policy: String = "optimized", fixed: float = 7000.0) -> Dictionary:
	var bench := VehicleBench.new()
	bench.begin(spec,stages,build,policy,fixed)
	for iteration in 64:
		if bench.done: break
		bench.step_budget(960)
	return bench.result
