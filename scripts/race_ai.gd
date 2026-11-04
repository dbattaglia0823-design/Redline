class_name RaceAI
extends RefCounted
static var cache: Dictionary = {}
static var pending: Array[Dictionary] = []

# Menu estimates share the exact AI driver, but run in bounded slices between rendered frames.
static func request_estimate(contract: Dictionary,distance: float = 402.336) -> Dictionary:
	var key := JSON.stringify([contract,distance])
	if cache.has(key): return cache[key]
	for job in pending:
		if job.key == key: return {}
	if pending.size() >= 12: pending.pop_back()
	pending.push_front({"key":key,"contract":contract.duplicate(true),"distance":distance,"car":null,"stage":0,"ticks":0})
	return {}

static func advance_estimates(budget: int = 360) -> bool:
	var changed := false
	while budget > 0 and not pending.is_empty():
		var job: Dictionary = pending[0]
		if cache.has(job.key): pending.pop_front(); continue
		if job.car == null:
			job.car = Drivetrain.new(); configure(job.car,job.contract)
		var c: Drivetrain = job.car
		var before := c.distance
		var stage_ticks: int=720 if int(job.contract.get("driver_model",1))==2 else 480
		if job.stage < stage_ticks:
			c.step(1.0/240,stage_pedal(c,job.contract),0,1)
			job.stage += 1
			if job.stage == stage_ticks: c.running = true
		else:
			step(c,job.contract,1.0/240)
			job.ticks += 1
			if c.distance >= float(job.distance) or job.ticks >= 21600:
				var finish := 90.0 if c.distance < float(job.distance) else c.elapsed-1.0/240+(float(job.distance)-before)/maxf(.00001,c.distance-before)/240
				if cache.size() >= 128: cache.erase(cache.keys()[0])
				cache[job.key] = {"time":finish,"mph":c.speed*Drivetrain.MPH_PER_MPS,"hp":c.peak_horsepower(),"clamps":c.safety_clamps}
				pending.pop_front(); changed = true
		budget -= 1
	return changed

static func player_contract(profile: DriverProfile) -> Dictionary:
	return {"model":profile.vehicle_id,"stages":profile.stages,"hardware":profile.hardware,"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}

static func recommended_ready(profile: DriverProfile,career: int) -> int:
	var ready := true; var best := INF; var selected := 0
	for i in range(mini(4,int(profile.career_wins[career]))+1):
		var bot := GameCatalog.opponent(career,i,profile)
		var a := request_estimate(bot,float(bot.distance)); var b := request_estimate(player_contract(profile),float(bot.distance))
		if a.is_empty() or b.is_empty(): ready = false; continue
		var gap := absf(float(a.time)-float(b.time))
		if gap < best: best = gap; selected = i
	return selected if ready else -1

static func recommended(profile: DriverProfile,career: int) -> int:
	var driver := {"model":profile.vehicle_id,"stages":profile.stages,"hardware":profile.hardware,"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}
	var best := INF
	var selected := 0
	for i in range(mini(4,int(profile.career_wins[career]))+1):
		var bot := GameCatalog.opponent(career,i,profile)
		var gap := absf(float(estimate(bot,float(bot.distance)).time)-float(estimate(driver,float(bot.distance)).time))
		if gap < best: best = gap; selected = i
	return selected

static func configure(car: Drivetrain,contract: Dictionary) -> void:
	car.configure_vehicle(GameCatalog.spec(str(contract.model)))
	car.configure(contract.stages)
	car.configure_build(contract.get("hardware",GameCatalog.factory_build(str(contract.model))),str(contract.model))
	if car.shift_map.is_empty(): car.rebuild_shift_map()
	car.reset()

static func launch_target(car: Drivetrain) -> float:
	if car.launch_control and car.hardware.tune.has("launch_rpm"): return car.launch_rpm
	return minf(car.redline_rpm*.70,maxf(3200,float(car._base_spec.get("torque_rpm",3900))))
static func launch_clutch(car: Drivetrain) -> float:
	if not car._base_spec.has("id") or car.has_converter or car.gear!=1 or car.elapsed>4: return 0.0
	var target:=launch_target(car)
	if car.wheel_rpm(1)>=target*.9: return 0.0
	var engagement:=clampf(car.full_engine_torque(car.rpm)*.92/maxf(1,car.clutch_capacity())+(car.rpm-target)/3000.0,.05,1)
	return 1.0-engagement

static func stage_pedal(car: Drivetrain,contract: Dictionary) -> float:
	var target: float=float(contract.get("launch_rpm",3900))
	if int(contract.get("driver_model",1))==2:
		target=launch_target(car)
		if contract.get("launch_style","")=="patient": target*=.88
		elif contract.get("launch_style","")=="aggressive": target=minf(car.redline_rpm-350,target*1.1)
	return clampf(.1+(target-car.rpm)/2500,0,1)

static func step(car: Drivetrain,contract: Dictionary,dt: float) -> void:
	var waiting := car.elapsed < float(contract.reaction)
	# Converter cars stage in neutral, then select Drive after driver reaction.
	# An open manual clutch cannot disconnect a hydrodynamic converter.
	if car.has_converter and not car.has_transbrake:
		if waiting: car.gear = 0
		elif car.gear == 0: car.shift(1)
	var clutch := 1.0 if waiting else 0.0
	var pedal := stage_pedal(car,contract) if waiting else float(contract.pedal)
	if not waiting:
		# Skill changes pedal decisions, never chassis forces or road speed.
		if car.wheelspin > .16: pedal = maxf(.42,pedal-(car.wheelspin-.16)*float(contract.get("traction_skill",.5)))
		var imperfect := sin(car.elapsed*2.1+float(contract.get("driver_seed",0))) > .985 and int(contract.get("skill",0)) < 2
		if imperfect: pedal *= .88
		if car.control_mode != "automatic" and car.gear > 0 and car.gear < car.gear_ratios.size():
			var target: float = car.shift_map[car.gear-1]+float(contract.get("shift_error",100))
			if car.rpm >= minf(target,car.redline_rpm-40) and car.wheel_rpm(car.gear) >= target*.90 and car.shift_left <= 0:
				if car.control_mode == "hpattern": car.select_manual_gear(car.gear+1,1.0)
				else: car.request_shift(1)
		if car.control_mode == "hpattern" and car.shift_left > 0: clutch = 1; pedal = 0
		elif car._base_spec.has("id"): clutch=launch_clutch(car)
	var spray: bool=int(contract.get("driver_model",1))==2 and bool(contract.get("nitrous",false)) and not waiting and car.gear>=int(contract.get("nitrous_gear",2)) and car.wheelspin<.12 and car.shift_left<=0
	car.step(dt,pedal,0.0,clutch,spray,waiting and car.has_transbrake)

static func estimate(contract: Dictionary,distance: float = 402.336) -> Dictionary:
	var key := JSON.stringify([contract,distance])
	if cache.has(key): return cache[key]
	var c := Drivetrain.new(); configure(c,contract)
	for i in (720 if int(contract.get("driver_model",1))==2 else 480): c.step(1.0/240.0,stage_pedal(c,contract),0,1)
	c.running = true
	var finish := 90.0
	for i in 21600:
		var before := c.distance
		step(c,contract,1.0/240.0)
		if c.distance >= distance:
			finish = c.elapsed-1.0/240.0+(distance-before)/maxf(.00001,c.distance-before)/240.0
			break
	var result := {"time":finish,"mph":c.speed*Drivetrain.MPH_PER_MPS,"hp":c.peak_horsepower(),"clamps":c.safety_clamps}
	if cache.size() > 128: cache.clear()
	cache[key] = result
	return result
