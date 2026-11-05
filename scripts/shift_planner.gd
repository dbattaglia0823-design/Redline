class_name ShiftPlanner
extends RefCounted

# Quasi-static acceleration integrals seed the map; repeatable full simulation
# comparisons validate it. This is a finite-horizon racing heuristic, not an OEM TCU.
static var cache: Dictionary = {}

static func force(car, v: float, g: int) -> float:
	var road_rpm: float = v/car.tire_radius*car.ratio_for(g)*60.0/TAU
	var predicted: float = road_rpm/(0.96 if car.has_converter else 1.0)
	var mult := 1.0
	if car.has_converter:
		predicted = maxf(predicted,car.converter_stall*0.88)
		var sr := clampf(road_rpm/maxf(predicted,1.0),0.0,1.0)
		mult = minf(1.0+(car.converter_multiplication-1.0)*pow(1.0-sr,1.5),0.98/maxf(sr,0.01))
	var tq: float = car.full_engine_torque(predicted)
	if predicted >= car.redline_rpm: tq *= maxf(0.0,1.0-(predicted-car.redline_rpm)/400.0)
	tq = minf(tq,car.input_capacity())
	var raw: float = tq*mult*car.ratio_for(g)*car.trans_efficiency/car.tire_radius
	var grip: float = car.mass()*9.81*car.effective_grip()
	return minf(raw,grip)-0.5*1.225*car.drag_area*v*v-car.mass()*9.81*car.rolling_coefficient

static func acceleration_time(car, start: float, ending: float, g: int) -> float:
	if ending <= start: return 0.0
	var t := 0.0
	var dv: float = (ending-start)/32.0
	for i in 32:
		var available := force(car,start+(i+0.5)*dv,g)
		if available <= 1.0: return INF
		t += dv*car.mass()/available
	return t

static func build(car) -> Array:
	var key := JSON.stringify([car._base_spec,car.engine_stage,car.turbo_stage,car.exhaust_stage,car.tire_stage,car.weight_stage,car.gearbox_stage,car.brake_stage,car.nitrous_stage,car.hardware.transmission,car.hardware.parts,car.hardware.tune])
	if cache.has(key): return cache[key].duplicate()
	var result: Array = []
	for g in range(1,car.gear_ratios.size()):
		var min_rpm: float = car.idle_rpm+(car.redline_rpm-car.idle_rpm)*0.48
		var start: float = min_rpm/(60.0/TAU)/car.ratio_for(g)*car.tire_radius
		var finish: float = minf(car.redline_rpm/(60.0/TAU)/car.ratio_for(g)*car.tire_radius*1.12,car.redline_rpm/(60.0/TAU)/car.ratio_for(g+1)*car.tire_radius*0.97)
		if force(car,finish,g+1) < 100.0:
			var lo := start
			var hi := finish
			for iteration in 16:
				var mid := (lo+hi)*0.5
				if force(car,mid,g+1) >= 100.0: lo = mid
				else: hi = mid
			finish = lo
		var best_rpm: float = car.redline_rpm-80.0
		var best := INF
		for candidate in range(int(min_rpm),int(car.redline_rpm)-35,100):
			var v: float = candidate/(60.0/TAU)/car.ratio_for(g)*car.tire_radius
			if v >= finish: continue
			var shift_gain: float = force(car,v,g+1)/car.mass()*car.shift_duration*car.shift_retention
			var time: float = acceleration_time(car,start,v,g)+car.shift_duration+acceleration_time(car,v+shift_gain,finish,g+1)
			# RPM matching costs depend on the ratio step, rotational inertia and actuator.
			time += (1.0-car.gear_ratios[g]/car.gear_ratios[g-1])*car.engine_inertia*0.12*(candidate/car.redline_rpm)
			if time < best:
				best = time
				best_rpm = candidate
		result.append(clampf(best_rpm,car.idle_rpm+1500.0,car.redline_rpm-50.0))
	# Validate the analytic seed against the real coupled solver. A traction-limited
	# static force estimate cannot account for stored wheel energy or converter load.
	# Candidates scale with this engine's usable band, never a universal shift RPM.
	var best_map := result.duplicate()
	var best_et := trial_time(car,best_map)
	for blend in [0.5,1.0,-0.15]:
		var candidate_map: Array = []
		for target in result:
			candidate_map.append(clampf(lerpf(float(target),car.redline_rpm-100.0,float(blend)),car.idle_rpm+1500.0,car.redline_rpm-50.0))
		var et := trial_time(car,candidate_map)
		if et < best_et: best_et = et; best_map = candidate_map
	result = best_map
	if cache.size() >= 128: cache.clear()
	cache[key] = result.duplicate()
	return result

static func trial_time(source, targets: Array) -> float:
	var car = source.get_script().new()
	car.configure_vehicle(source._base_spec)
	car.configure([source.engine_stage,source.turbo_stage,source.tire_stage,source.weight_stage,source.gearbox_stage,source.exhaust_stage,source.brake_stage,source.nitrous_stage])
	car.configure_build(source.hardware,str(source._base_spec.get("id","nori" if source.drivetrain == "FWD" else "kaze")),false)
	car.shift_map = targets.duplicate()
	car.reset()
	var h := 1.0/240.0
	for tick in 480: car.step(h,clampf(0.10+(3900.0-car.rpm)/2500.0,0.0,1.0),0.0,1.0)
	car.running = true
	for tick in 9600:
		if car.control_mode != "automatic" and car.gear > 0 and car.gear < car.gear_ratios.size() and car.shift_left == 0.0:
			var target: float = targets[car.gear-1]
			if car.rpm >= target and car.wheel_rpm(car.gear) >= target*0.90:
				if car.control_mode == "hpattern": car.select_manual_gear(car.gear+1,1.0)
				else: car.shift(1)
		var clutch: float = 1.0 if car.control_mode == "hpattern" and car.shift_left > 0.0 else 0.0
		var previous: float = car.distance
		car.step(h,0.0 if clutch > 0.0 else 1.0,0.0,clutch)
		if car.distance >= 402.336:
			return car.elapsed-h+h*(402.336-previous)/maxf(0.00001,car.distance-previous)
	return INF
