class_name Drivetrain
extends RefCounted

# SI units internally. Keep the existing public interface and default vehicle values.
const RATIOS: Array[float] = [3.10,2.12,1.53,1.17,0.94,0.78]
const FINAL_DRIVE := 3.85
const TIRE_RADIUS := 0.315
const IDLE := 950.0
const REDLINE := 7600.0
const NITROUS_KIT_CAPACITY := 4.0
const NITROUS_TORQUE_SCALE := 0.8
const FIXED_DT := 1.0/240.0
const MPH_PER_MPS := 2.2369362921
const RPM_PER_RAD := 60.0/TAU
const TORQUE_POINTS := [Vector2(0,0.60),Vector2(0.15,0.80),Vector2(0.35,0.95),Vector2(0.55,1.0),Vector2(0.75,0.96),Vector2(0.90,0.90),Vector2(1.0,0.82),Vector2(1.15,0.25)]

var speed := 0.0
var distance := 0.0
var elapsed := 0.0
var rpm := IDLE
var gear := 1 # 0 = neutral; paddles remain sequential.
var throttle := 0.0
var boost := 0.0
var wheelspin := 0.0
var shift_left := 0.0
var shift_duration := 0.16
var limiter := false
var clutch_engagement := 0.0
var nitrous_remaining := 0.0
var nitrous_active := false
var throttle_gamma := 1.0
var traction_slip_target := 0.0
var clutch_rate := 1.0
var boost_rise := 0.0
var boost_by_gear: Array = []
var launch_gear := 1
var pressure_grip := 1.0
var pressure_rolling := 1.0
var running := false
var engine_stage := 0
var turbo_stage := 0
var tire_stage := 0
var weight_stage := 0
var gearbox_stage := 0
var exhaust_stage := 0
var brake_stage := 0
var nitrous_stage := 0
var base_torque := 238.0
var base_mass := 1280.0
var grip_coefficient := 0.57
var shift_message := ""
var shift_serial := 0
var rejected_serial := 0

var gear_ratios: Array[float] = RATIOS.duplicate()
var final_drive := FINAL_DRIVE
var tire_radius := TIRE_RADIUS
var idle_rpm := IDLE
var redline_rpm := REDLINE
var engine_inertia := 0.22
var wheel_inertia := 2.8
var drag_area := 0.68
var rolling_coefficient := 0.014
var base_boost := 0.45
var drivetrain := "RWD"
var cylinders := 4
var engine_layout := "I4"
var engine_label := "2.0L turbo I4"
var throttle_response := 0.055
var queued_shift := 0
var queued_shift_expires := 0.0
var shift_request_serial := 0
var shift_request_status := ""
var last_shift_rpm := 0.0
var last_shift_load := 0.0
var wheel_omega := 0.0
var wheel_angle := 0.0
var rolling_wheel_angle := 0.0
var engine_torque := 0.0
var clutch_torque := 0.0
var engine_load := 0.0
var clutch_slip_rpm := 0.0
var slip_ratio := 0.0
var traction_force := 0.0
var hybrid_energy_j := 0.0
var hybrid_power_w := 0.0
var available_traction := 0.0
var braking_force := 0.0
var drag_force := 0.0
var acceleration := 0.0
var sync_torque := 0.0
var fuel_cut := false
var invalid_inputs := 0
var safety_clamps := 0
var substeps := 0
var _accumulator := 0.0
var _sim_time := 0.0
var _auto_clutch := 0.0
var hardware := VehicleParts.default_build()
var transmission_id := "legacy6"
var transmission_kind := "paddle"
var control_mode := "paddle"
var staging_motion := false
var trans_efficiency := 0.90
var rated_capacity := 750.0
var trans_mass_delta := 0.0
var shift_retention := 0.0
var has_converter := false
var converter_stall := 2800.0
var converter_multiplication := 1.85
var turbine_omega := 0.0
var converter_slip := 0.0
var converter_pump_nm := 0.0
var converter_turbine_nm := 0.0
var converter_input_w := 0.0
var converter_output_w := 0.0
var converter_heat_w := 0.0
var converter_lock := 0.0
var transbrake_active := false
var has_transbrake := false
var launch_rpm := 3900.0
var launch_control := false
var shift_firmness := 1.0
var shift_map: Array = []
var engine_temperature := 88.0
var transmission_temperature := 80.0
var component_wear := 0.0
var overload := 0.0
var clutch_overloaded := false
var transmission_slipping := false
var grind_serial := 0
var shift_direction := 0
var combustion_fraction := 1.0
var extra_grip := 0.0
var extra_mass := 0.0
var load_transfer_scale := 0.18
var tire_grip := 0.0
var tire_launch_bite := 0.0
var tire_slip_loss := 0.0
var tire_sidewall_mark := 0
var suspension_launch_support := 0.0
var hop_damping := 0.0
var wheel_hop := 0.0
var _base_spec: Dictionary = {}
var _torque_points: Array = TORQUE_POINTS
var _torque_factor := 1.0
var _flow := 0.0
var _factory_curve_redline := REDLINE
var _safe_factor := 1.0
var _fuel_factor := 1.0
var _clutch_factor := 1.0
var _supercharger := ""
var _pressure_add := 0.0
var _spool_scale := 1.0
var _gear_cooling := 1.0
var _charge_cooling := 1.0
var _super_pressure := 0.0
var _boost_extra := 0.0
var _boost_onset := -1.0
var _spool_override := -1.0
var _boost_setting := -1.0
var _advanced := false
var _auto_dwell := 0.0
var _manual_clutch := 0.0
var nitrous_delivery := 0.0
var _mechanical_redline := 7600.0

func configure(stages: Array) -> void:
	var normalized := GameCatalog.normalize_stages(stages)
	engine_stage = int(normalized[0])
	turbo_stage = int(normalized[1])
	tire_stage = int(normalized[2])
	weight_stage = int(normalized[3])
	gearbox_stage = int(normalized[4])
	exhaust_stage = int(normalized[5])
	brake_stage = int(normalized[6])
	nitrous_stage = int(normalized[7])
	shift_duration = TransmissionCatalog.duration(transmission_id,gearbox_stage)
	nitrous_remaining = minf(nitrous_remaining,nitrous_capacity())

func configure_vehicle(spec: Dictionary) -> void:
	_base_spec = spec.duplicate(true)
	_torque_points = TORQUE_POINTS
	var curve = spec.get("torque_curve",[])
	if curve is Array and curve.size() >= 2:
		_torque_points = []
		for point in curve: _torque_points.append(Vector2(float(point[0]),float(point[1])))
	hardware = VehicleParts.default_build()
	transmission_id = "legacy6"
	transmission_kind = "paddle"
	control_mode = "paddle"
	trans_efficiency = 0.90
	rated_capacity = 750.0
	trans_mass_delta = 0.0
	has_converter = false
	shift_retention = 0.0
	reset_modifiers()
	base_torque = clampf(float(spec.get("torque",238.0)),10.0,2000.0)
	base_mass = clampf(float(spec.get("mass",1280.0)),350.0,5000.0)
	grip_coefficient = clampf(float(spec.get("grip",0.57)),0.05,2.0)
	drivetrain = str(spec.get("drive","RWD"))
	engine_label = str(spec.get("engine","2.0L turbo I4"))
	engine_layout = str(spec.get("layout","V10" if int(spec.get("cylinders",4)) == 10 else "V8")) if int(spec.get("cylinders",4)) >= 8 else "V6" if engine_label.contains("V6") else ("I6" if engine_label.contains("I6") else "I4")
	if spec.has("layout"): engine_layout=str(spec.layout)
	elif engine_label.contains("VR6"): engine_layout="VR6"
	throttle_response = clampf(float(spec.get("throttle_response",0.055)),0.015,0.15)
	cylinders = int(spec.get("cylinders",6 if str(spec.get("engine","")).contains("6") else 4))
	engine_inertia = clampf(float(spec.get("inertia",0.28 if cylinders == 6 else 0.22)),0.08,0.8)
	wheel_inertia = float(spec.get("wheel_inertia",5.6 if drivetrain == "AWD" else 2.8))
	tire_radius = clampf(float(spec.get("tire_radius",TIRE_RADIUS)),0.15,0.6)
	final_drive = clampf(float(spec.get("final_drive",FINAL_DRIVE)),1.0,7.0)
	idle_rpm = clampf(float(spec.get("idle",IDLE)),600.0,1500.0)
	redline_rpm = clampf(float(spec.get("redline",REDLINE)),4500.0,12000.0)
	_factory_curve_redline=redline_rpm
	drag_area = clampf(float(spec.get("drag_area",0.68)),0.2,1.5)
	rolling_coefficient = clampf(float(spec.get("rolling",0.014)),0.005,0.05)
	base_boost = clampf(float(spec.get("base_boost",0.45)),0.0,2.0)
	gear_ratios = RATIOS.duplicate()
	var supplied = spec.get("ratios",[])
	if supplied is Array and supplied.size() >= 2 and supplied.size() <= 10:
		gear_ratios.clear()
		for ratio in supplied: gear_ratios.append(clampf(float(ratio),0.3,6.0))

func mass() -> float:
	return maxf(350.0,base_mass-weight_stage*65.0+trans_mass_delta+extra_mass)

func nitrous_capacity() -> float:
	return NITROUS_KIT_CAPACITY+nitrous_stage*1.5 if has_nitrous() else 0.0

func has_nitrous() -> bool:
	return nitrous_stage>0

func nitrous_torque_gain() -> float:
	return (0.55+nitrous_stage*0.06)*NITROUS_TORQUE_SCALE if has_nitrous() else 0.0

func clutch_capacity() -> float:
	var legacy := base_torque*2.35*(1.0+engine_stage*0.14)*(1.0+exhaust_stage*0.06)*(1.0+gearbox_stage*0.15)
	if transmission_id == "legacy6": return legacy*_clutch_factor
	# Packs approach the gearbox rating; twin and race packs must not both hit
	# the same cap. The gearbox internals remain the upper mechanical limit.
	return minf(input_capacity(),input_capacity()*(0.86+(_clutch_factor-1.0)*0.145))*maxf(0.6,1.0-component_wear*0.25)

func good_shift_min() -> float:
	if _advanced and gear >= 1 and gear <= shift_map.size(): return maxf(idle_rpm+1500.0,float(shift_map[gear-1])-180.0)
	return redline_rpm-850.0

func good_shift_max() -> float:
	if _advanced and gear >= 1 and gear <= shift_map.size(): return minf(redline_rpm-50.0,float(shift_map[gear-1])+180.0)
	return redline_rpm-250.0

func upshift_ready() -> bool:
	return running and gear > 0 and gear < gear_ratios.size() and shift_left <= 0.0 and rpm >= good_shift_min() and wheelspin < 0.10 and absf(clutch_slip_rpm) < 250.0 and clutch_engagement > 0.9

func shift_recommended() -> bool:
	return upshift_ready() and rpm <= good_shift_max()

func ratio_for(for_gear: int) -> float:
	return gear_ratios[for_gear-1]*final_drive if for_gear >= 1 and for_gear <= gear_ratios.size() else 0.0

func wheel_rpm(for_gear: int) -> float:
	# Ideal locked-clutch / no-wheelspin engine RPM at the current road speed.
	return speed/tire_radius*ratio_for(for_gear)*RPM_PER_RAD

func set_road_state(mps: float, for_gear: int, at_rpm: float = -1.0) -> void:
	speed = maxf(0.0,mps)
	gear = clampi(for_gear,0,gear_ratios.size())
	wheel_omega = speed/tire_radius
	rpm = maxf(idle_rpm,wheel_rpm(gear)) if at_rpm < 0.0 else maxf(0.0,at_rpm)
	turbine_omega = wheel_omega*ratio_for(gear)
	_accumulator = 0.0

func reset() -> void:
	hybrid_energy_j=float(_base_spec.get("hybrid_kwh",0))*3600000.0
	hybrid_power_w=0.0
	staging_motion = false
	speed = 0.0
	distance = 0.0
	elapsed = 0.0
	rpm = idle_rpm
	gear = launch_gear
	throttle = 0.0
	boost = 0.0
	wheelspin = 0.0
	wheel_hop = 0.0
	shift_left = 0.0
	running = false
	limiter = false
	fuel_cut = false
	clutch_engagement = 0.0
	nitrous_remaining = nitrous_capacity()
	nitrous_active = false
	shift_message = ""
	cancel_shift_request()
	shift_request_status = ""
	last_shift_rpm = 0.0
	last_shift_load = 0.0
	wheel_omega = 0.0
	wheel_angle = 0.0
	rolling_wheel_angle = 0.0
	engine_torque = 0.0
	clutch_torque = 0.0
	engine_load = 0.0
	clutch_slip_rpm = 0.0
	slip_ratio = 0.0
	traction_force = 0.0
	available_traction = 0.0
	braking_force = 0.0
	acceleration = 0.0
	sync_torque = 0.0
	_accumulator = 0.0
	_sim_time = 0.0
	_auto_clutch = 0.0
	substeps = 0
	invalid_inputs = 0
	safety_clamps = 0
	turbine_omega = 0.0
	converter_lock = 0.0
	converter_slip = 0.0
	converter_pump_nm = 0.0
	converter_turbine_nm = 0.0
	converter_input_w = 0.0
	converter_output_w = 0.0
	transbrake_active = false
	converter_heat_w = 0.0
	engine_temperature = 88.0
	transmission_temperature = 80.0
	component_wear = 0.0
	nitrous_delivery = 0.0
	combustion_fraction = 1.0
	overload = 0.0
	clutch_overloaded = false
	transmission_slipping = false
	grind_serial = 0
	shift_direction = 0
	_auto_dwell = 0.0

func shift(direction: int) -> bool:
	if shift_left > 0.000001 or direction == 0: return false
	var next := clampi(gear+signi(direction),0,gear_ratios.size())
	if next == gear: return false
	# Include driven-wheel speed: spinning tires can overrev a downshift too.
	var proposed := maxf(wheel_rpm(next),wheel_omega*ratio_for(next)*RPM_PER_RAD)
	if next > 0 and proposed > redline_rpm+180.0:
		shift_message = "DOWNSHIFT PROTECTED"
		rejected_serial += 1
		return false
	if next == 0: shift_message = "NEUTRAL"
	elif gear == 0: shift_message = "DRIVE"
	elif direction > 0:
		if wheelspin >= 0.10: shift_message = "TRACTION SHIFT"
		elif rpm < good_shift_min(): shift_message = "EARLY SHIFT"
		elif rpm > good_shift_max(): shift_message = "LATE SHIFT"
		else: shift_message = "PERFECT SHIFT" if shift_recommended() else "CLUTCH SHIFT"
	else: shift_message = "REV MATCH"
	last_shift_rpm = rpm
	last_shift_load = engine_load
	shift_direction = signi(next-gear)
	gear = next
	shift_left = shift_duration
	shift_serial += 1
	return true

func cancel_shift_request() -> void:
	queued_shift = 0
	queued_shift_expires = 0.0

func request_shift(direction: int, clutch_command: float = -1.0) -> String:
	if control_mode == "hpattern": return "CLUTCH + H GATE"
	if control_mode == "automatic": return "AUTOMATIC CONTROLLER"
	# Only explicit player taps use this one-intent latch. AI keeps shift().
	shift_request_serial += 1
	var intent := signi(direction)
	if intent == 0: return "INVALID"
	if queued_shift != 0 and intent != queued_shift:
		cancel_shift_request()
		shift_request_status = "SHIFT CANCELED"
	elif shift_left > 0.000001:
		if gear+intent < 0 or gear+intent > gear_ratios.size():
			shift_request_status = "GEAR LIMIT"
		else:
			queued_shift = intent
			queued_shift_expires = _sim_time+shift_left+0.1
			shift_request_status = "SHIFT QUEUED"
	else:
		cancel_shift_request()
		if gear+intent < 0 or gear+intent > gear_ratios.size(): shift_request_status = "GEAR LIMIT"
		else: shift_request_status = "SHIFT ACCEPTED" if shift(intent) else "DOWNSHIFT PROTECTED"
	return shift_request_status

func torque_at(at_rpm: float) -> float:
	# Net full-throttle naturally-aspirated torque. Boost is applied separately.
	var curve_limit: float=_factory_curve_redline if hardware.parts.has("ecu") else redline_rpm
	var x := clampf((at_rpm-idle_rpm)/(curve_limit-idle_rpm),0.0,1.15)
	var points := _torque_points
	var factor := 0.25
	for i in range(1,points.size()):
		if x <= points[i].x:
			factor = lerpf(points[i-1].y,points[i].y,inverse_lerp(points[i-1].x,points[i].x,x))
			break
	return base_torque*factor*(1.0+engine_stage*0.14)*(1.0+exhaust_stage*0.06)*_torque_factor*(1.0+_flow*smoothstep(0.25,0.90,x))

func turbo_onset() -> float:
	return _boost_onset if _boost_onset >= 0.0 else [2400.0,1700.0,2400.0,3200.0][turbo_stage]

func boost_target(at_rpm: float, opening: float) -> float:
	if _supercharger != "":
		var rated_rpm: float=_factory_curve_redline if hardware.parts.has("ecu") else redline_rpm
		var gain := pow(clampf(at_rpm/rated_rpm,0.0,1.0),2.0) if _supercharger == "centrifugal" else 1.0
		return (_super_pressure+_pressure_add)*gain*opening
	# An assembly replaces the packaged turbo, rather than stacking two compressors.
	var maximum := base_boost+(_boost_extra if hardware.parts.has("induction") else turbo_stage*0.18)
	if maximum<=0: return 0.0
	maximum += _pressure_add
	if _boost_setting >= 0.0: maximum = minf(maximum+0.35,_boost_setting)
	return clampf((at_rpm-turbo_onset())/2700.0,0.0,1.0)*opening*maximum

func peak_horsepower() -> int:
	var peak := 0.0
	for sample_rpm in range(int(idle_rpm),int(redline_rpm)+1,50):
		peak = maxf(peak,full_engine_torque(sample_rpm)*sample_rpm/7127.0)
	return roundi(peak)

func system_horsepower() -> int:
	return peak_horsepower()+roundi(float(_base_spec.get("hybrid_kw",0))/.7457)

func losses(at_omega: float, opening: float) -> float:
	return 8.0+0.02*at_omega+0.000015*at_omega*at_omega+(1.0-opening)*(8.0+0.025*at_omega)

func step(dt: float, pedal: float, brake: float = 0.0, clutch: float = 0.0, nitrous: bool = false, transbrake: bool = false) -> void:
	if not is_finite(dt) or dt <= 0.0 or dt > 1.0 or not is_finite(pedal) or not is_finite(brake) or not is_finite(clutch):
		invalid_inputs += 1
		return
	_accumulator += dt
	# A single fixed solver is shared by gameplay, AI, calibration, and tests.
	while _accumulator+0.000000001 >= FIXED_DT:
		_substep(FIXED_DT,clampf(pedal,0,1),clampf(brake,0,1),clampf(clutch,0,1),nitrous,transbrake)
		_accumulator -= FIXED_DT
	_accumulator = maxf(0.0,_accumulator)

func _substep(dt: float, pedal: float, brake: float, clutch: float, nitrous: bool, transbrake: bool) -> void:
	substeps += 1
	_sim_time += dt
	if running: elapsed += dt
	_manual_clutch = clutch
	transbrake_active = transbrake and has_transbrake and speed < 0.5 and gear == 1
	_auto_dwell = maxf(0.0,_auto_dwell-dt)
	if control_mode == "automatic" and running and not transbrake_active and throttle > 0.45 and shift_left <= 0.0 and _auto_dwell == 0.0 and gear > 0 and gear < gear_ratios.size():
		var target := float(shift_map[gear-1]) if shift_map.size() >= gear else redline_rpm-100.0
		if rpm >= target and wheel_rpm(gear) >= target*(0.84 if has_converter else 0.90):
			shift(1)
			_auto_dwell = shift_duration+0.12
	if control_mode == "automatic" and running and not transbrake_active and throttle > 0.65 and shift_left <= 0.0 and _auto_dwell == 0.0 and gear > 1 and wheel_rpm(gear) < idle_rpm+1300.0:
		if shift(-1): _auto_dwell = shift_duration+0.35
	pedal=pow(pedal,throttle_gamma)
	if traction_slip_target>0 and wheelspin>traction_slip_target and speed>1.0 and not transbrake_active:
		pedal*=clampf(1.0-(wheelspin-traction_slip_target)*2.5,.12,1.0)
	var response := throttle_response/(1.0+engine_stage*0.08)
	throttle = lerpf(throttle,pedal,1.0-exp(-dt/response))
	shift_left = maxf(0.0,shift_left-dt)
	if queued_shift != 0 and shift_left <= 0.000001:
		var intent := queued_shift
		var expired := _sim_time > queued_shift_expires
		cancel_shift_request()
		if not expired:
			shift_request_status = "SHIFT ACCEPTED" if shift(intent) else "SHIFT PROTECTED"
			shift_request_serial += 1
	var shifting := shift_left > 0.0
	var total_ratio := ratio_for(gear)
	var old_speed := speed
	var omega := maxf(0.0,rpm/RPM_PER_RAD)
	var old_engine_omega := omega
	var idle_omega := idle_rpm/RPM_PER_RAD
	if limiter and rpm < redline_rpm-160.0: limiter = false
	if rpm >= redline_rpm: limiter = true
	var launch_cut := launch_control and gear == launch_gear and (transbrake_active or not running or (speed<1.0 and clutch>.8)) and rpm >= launch_rpm
	var traditional_manual: bool = control_mode == "hpattern" and not hardware.parts.has("ecu")
	fuel_cut = limiter or (shifting and not traditional_manual) or launch_cut
	combustion_fraction = 0.0 if limiter or launch_cut else (shift_retention if shifting and not traditional_manual else 1.0)
	var target_boost := boost_target(rpm,throttle)
	if gear>0 and gear<=boost_by_gear.size(): target_boost=minf(target_boost,float(boost_by_gear[gear-1]))
	var boost_tau: float = [0.32,0.24,0.38,0.55][turbo_stage] if target_boost > boost else 0.09
	if _spool_override > 0.0 and target_boost > boost: boost_tau = _spool_override
	if _supercharger != "": boost_tau = 0.045
	var developed := lerpf(boost,target_boost,1.0-exp(-dt/(boost_tau*_spool_scale)))
	boost = minf(developed,boost+boost_rise*dt) if boost_rise>0 and developed>boost else developed
	# Automatic launch/anti-stall assistance operates a finite-capacity clutch.
	var target_clutch := 1.0-clutch
	if (not running and not staging_motion) or gear == 0:
		target_clutch = 0.0
	elif shifting: target_clutch = shift_retention
	elif has_converter: target_clutch = 1.0
	elif speed < 8.0:
		target_clutch = minf(target_clutch,clampf(maxf((rpm-idle_rpm)/4200.0,wheel_rpm(gear)/3000.0),0.0,1.0))
	elif wheel_rpm(gear) < idle_rpm:
		target_clutch *= clampf((wheel_rpm(gear)-idle_rpm*0.5)/(idle_rpm*0.5),0,1)
	clutch_engagement = 0.0 if (clutch > 0.99 and not has_converter) or target_clutch == 0.0 else move_toward(clutch_engagement,target_clutch,dt*(8.0+gearbox_stage*2.0)*shift_firmness*clutch_rate)
	var full_torque := power_torque(rpm,boost)
	var friction := losses(omega,throttle)
	var combustion := (full_torque+losses(omega,1.0))*throttle*combustion_fraction
	var governor := maxf(0.0,losses(idle_omega,0.0)+(idle_omega-omega)*1.8)*clampf(1.0-throttle*4.0,0,1)
	if omega > idle_omega*1.1: governor = 0.0
	engine_torque = combustion+governor-friction
	sync_torque = 0.0
	if shifting and not has_converter and control_mode != "hpattern" and clutch < 0.5 and total_ratio > 0.0 and running:
		var sync_target := maxf(idle_omega,wheel_omega*total_ratio)
		# Bounded paddle controller: compression/synchronizer drag and throttle blip.
		sync_torque = clampf((sync_target-omega)*engine_inertia/0.045,-240.0,full_torque)
		engine_torque += sync_torque
	nitrous_active = nitrous and nitrous_remaining > 0.0 and throttle > 0.85 and clutch_engagement > 0.9 and speed > 5.0 and not fuel_cut and gear > 0 and running and brake < 0.1
	if nitrous_active:
		nitrous_delivery = 1.0
		var used := minf(dt*nitrous_delivery,nitrous_remaining)
		nitrous_remaining = maxf(0.0,nitrous_remaining-used)
		engine_torque += full_torque*nitrous_torque_gain()*(used/dt)
	else: nitrous_delivery = 0.0
	if engine_torque > 0.0: engine_torque = minf(engine_torque,supported_engine_torque())
	var loaded := running and not shifting and gear>0 and clutch_engagement>.94 and throttle>.35 and not transbrake_active
	var capacity := input_capacity()
	overload = maxf(0.0,engine_torque/maxf(1.0,capacity)-1.0) if loaded else 0.0
	# Only load above the rating is shed. The converter can still multiply
	# torque normally, and the coupling solver limits its output separately.
	if overload>0.0: engine_torque = capacity
	clutch_overloaded = false
	transmission_slipping = loaded and overload>.025
	engine_temperature += (maxf(0.0,engine_torque)*omega*0.000006-(engine_temperature-85.0)*0.08*_charge_cooling)*dt
	component_wear = minf(0.8,component_wear+dt*(overload*0.001+maxf(0.0,transmission_temperature-115.0)*0.00001))
	if engine_torque > 0.0: engine_torque *= clampf(1.0-maxf(0.0,engine_temperature-110.0)/100.0-component_wear*0.2,0.55,1.0)
	# Lump gearbox/bearing efficiency into a power loss, without altering kinematic ratios.
	if engine_torque > 0.0 and clutch_engagement > 0.0: engine_torque *= 1.0-(1.0-trans_efficiency)*clutch_engagement
	omega += engine_torque/engine_inertia*dt
	var pump_omega := omega
	var coupling_inertia := engine_inertia
	var locked_coupling := false
	if has_converter:
		pump_omega = converter_step(dt,omega,gear > 0 and (running or staging_motion or transbrake_active),shifting)
		omega = turbine_omega
		coupling_inertia = 0.12
		locked_coupling = converter_lock >= 0.999 and not shifting and absf(pump_omega-turbine_omega) < 1.0 and absf(engine_torque) < clutch_capacity()
		if locked_coupling:
			omega = (engine_inertia*pump_omega+0.12*turbine_omega)/(engine_inertia+0.12)
			coupling_inertia = engine_inertia+0.12
	clutch_torque = 0.0
	traction_force = 0.0
	braking_force = 0.0
	if not running and not staging_motion:
		# Staging holds the chassis; engine dynamics continue in neutral/open clutch.
		speed = 0.0
		wheel_omega = 0.0
	else:
		var m := mass()
		drag_force = 0.5*1.225*drag_area*speed*speed
		var rolling := m*9.81*rolling_coefficient*pressure_rolling if speed > 0.001 else 0.0
		braking_force = minf(brake*m*8.0*(1.0+brake_stage*0.18),m*9.81*brake_grip())
		var free_v := speed-(drag_force+rolling+braking_force)/m*dt
		var launch_window := 1.0-smoothstep(3.0,21.0,speed)
		if tire_slip_loss>0 or suspension_launch_support>0:
			var hop_target := .10*wheelspin*launch_window*(1.0-hop_damping)
			wheel_hop = lerpf(wheel_hop,hop_target,1.0-exp(-dt*lerpf(14.0,30.0,hop_damping)))
		var hop_unload := wheel_hop*maxf(0.0,sin(_sim_time*TAU*10.0))
		available_traction = m*9.81*maxf(.05,traction_grip(acceleration,launch_window,wheelspin)-hop_unload)
		var tire_limit := available_traction*dt
		# Battery-limited electric axle torque joins the wheel/road impulse solve.
		# It does not raise combustion torque or bypass tire traction.
		hybrid_power_w=0.0
		if float(_base_spec.get("hybrid_kw",0))>0 and hybrid_energy_j>0 and gear>0 and throttle>0 and brake<.05:
			var force:=minf(6000.0,float(_base_spec.hybrid_kw)*1000.0/maxf(5.0,speed))*throttle
			hybrid_power_w=minf(force*maxf(5.0,speed),hybrid_energy_j/dt)
			force=hybrid_power_w/maxf(5.0,speed)
			wheel_omega+=force*tire_radius/wheel_inertia*dt
			hybrid_energy_j=maxf(0,hybrid_energy_j-hybrid_power_w/.94*dt)
		var pack_capacity := clutch_capacity()
		var clutch_limit := pack_capacity*clutch_engagement*dt
		# Two coupled impulses solve engine-clutch-wheel and tire-road constraints.
		# Saturation produces real clutch slip and driven-wheel spin.
		var a11 := 1.0/coupling_inertia+total_ratio*total_ratio/wheel_inertia
		var a12 := -total_ratio*tire_radius/wheel_inertia
		var a22 := tire_radius*tire_radius/wheel_inertia+1.0/m
		var c1 := omega-total_ratio*wheel_omega
		var c2 := wheel_omega*tire_radius-free_v
		var determinant := maxf(0.0000001,a11*a22-a12*a12)
		var jc := (a22*c1-a12*c2)/determinant
		var jt := (a11*c2-a12*c1)/determinant
		for solve in 4:
			jc = clampf(jc,-clutch_limit,clutch_limit)
			jt = clampf((c2-a12*jc)/a22,-tire_limit,tire_limit)
			jc = clampf((c1-a12*jt)/a11,-clutch_limit,clutch_limit)
		omega -= jc/coupling_inertia
		wheel_omega += (total_ratio*jc-tire_radius*jt)/wheel_inertia
		speed = maxf(0.0,free_v+jt/m)
		clutch_torque = jc/dt
		var coupling_slip := (omega-total_ratio*wheel_omega)*RPM_PER_RAD
		var pack_saturated := loaded and coupling_slip>150.0 and jc>=clutch_limit*.99
		if has_converter:
			transmission_slipping = transmission_slipping or (pack_saturated and speed>8.0)
		else:
			clutch_overloaded = pack_saturated and speed>3.0
		traction_force = jt/dt
		acceleration = (speed-old_speed)/dt
		if transbrake_active:
			speed = 0.0
			wheel_omega = 0.0
			omega = 0.0 if has_converter else omega
			traction_force = 0.0
			acceleration = 0.0
		distance += (old_speed+speed)*0.5*dt
	if has_converter:
		turbine_omega = maxf(0.0,omega) if running or staging_motion else 0.0
		if locked_coupling: pump_omega = turbine_omega
		omega = pump_omega
		converter_slip = (omega-turbine_omega)/maxf(1.0,omega)
		if transbrake_active: turbine_omega = 0.0
		if transbrake_active: converter_heat_w = maxf(converter_heat_w,converter_input_w)
		transmission_temperature += converter_heat_w/120000.0*dt
	var safe_omega := clampf(omega,0.0,redline_rpm*1.25/RPM_PER_RAD)
	if not is_equal_approx(safe_omega,omega): safety_clamps += 1
	rpm = safe_omega*RPM_PER_RAD
	wheel_omega = maxf(0.0,wheel_omega)
	wheel_angle = fposmod(wheel_angle+wheel_omega*dt,TAU)
	# Read-only visual phase for the non-driven axle; keep continuity as tire radius changes.
	rolling_wheel_angle = fposmod(rolling_wheel_angle+(old_speed+speed)*0.5/tire_radius*dt,TAU)
	clutch_slip_rpm = (turbine_omega*RPM_PER_RAD if has_converter else rpm)-wheel_omega*total_ratio*RPM_PER_RAD
	transmission_temperature += (absf(clutch_torque*clutch_slip_rpm/RPM_PER_RAD)/80000.0-(transmission_temperature-80.0)*0.06*_gear_cooling)*dt
	slip_ratio = (wheel_omega*tire_radius-speed)/maxf(3.0,speed)
	wheelspin = clampf(maxf(0.0,slip_ratio),0.0,1.0)
	var delivered := engine_torque-engine_inertia*(safe_omega-old_engine_omega)/dt if has_converter else clutch_torque
	if has_converter: converter_pump_nm = delivered
	if locked_coupling: converter_turbine_nm = delivered
	if has_converter:
		converter_input_w = maxf(0.0,delivered*(old_engine_omega+safe_omega)*0.5)
		converter_output_w = minf(converter_input_w,maxf(0.0,converter_turbine_nm*turbine_omega))
	engine_load = clampf(maxf(0.0,delivered)/maxf(1.0,full_torque),0.0,1.5)

func telemetry() -> Dictionary:
	return {"time":elapsed,"rpm":rpm,"gear":gear,"mph":speed*MPH_PER_MPS,"distance_m":distance,"engine_nm":engine_torque,"clutch_nm":clutch_torque,"load":engine_load,"clutch":clutch_engagement,"clutch_slip_rpm":clutch_slip_rpm,"wheel_rad_s":wheel_omega,"slip_ratio":slip_ratio,"tire_force_n":traction_force,"traction_limit_n":available_traction,"acceleration_mps2":acceleration,"boost_bar":boost,"nitrous_s":nitrous_remaining,"fuel_cut":fuel_cut,"limiter":limiter,"shift_s":shift_left,"sync_nm":sync_torque,"converter_slip":converter_slip,"converter_pump_nm":converter_pump_nm,"converter_turbine_nm":converter_turbine_nm,"converter_input_w":converter_input_w,"converter_output_w":converter_output_w,"converter_lock":converter_lock,"transbrake":transbrake_active,"engine_c":engine_temperature,"transmission_c":transmission_temperature,"wear":component_wear,"overload":overload,"clutch_overloaded":clutch_overloaded,"transmission_slipping":transmission_slipping,"transmission":transmission_id,"control_mode":control_mode}

func effective_grip() -> float:
	return (grip_coefficient*1.16+extra_grip+(tire_grip if tire_grip>0 else tire_stage*.115))*pressure_grip

func brake_grip() -> float:
	return 1.05+(tire_grip*.60 if tire_grip>0 else tire_stage*.06)

func traction_grip(at_acceleration: float,launch_window: float,spin: float) -> float:
	var transfer := load_transfer_scale*clampf(at_acceleration,-8.0,8.0)/9.81
	if drivetrain=="FWD": transfer = -transfer
	elif drivetrain=="AWD": transfer = 0.0
	return effective_grip()+transfer+(tire_launch_bite+suspension_launch_support*(1.0-.22*spin))*launch_window-tire_slip_loss*smoothstep(.12,1.0,spin)

func reset_modifiers() -> void:
	_torque_factor = 1.0
	_flow = 0.0
	_safe_factor = 1.0
	_fuel_factor = 1.0
	_clutch_factor = 1.0
	_supercharger = ""
	_pressure_add = 0.0
	_spool_scale = 1.0
	_gear_cooling = 1.0
	_charge_cooling = 1.0
	_super_pressure = 0.0
	_boost_extra = 0.0
	_boost_onset = -1.0
	_spool_override = -1.0
	_boost_setting = -1.0
	extra_mass = 0.0
	extra_grip = 0.0
	load_transfer_scale = 0.18
	tire_grip = 0.0
	tire_launch_bite = 0.0
	tire_slip_loss = 0.0
	tire_sidewall_mark = 0
	suspension_launch_support = 0.0
	hop_damping = 0.0
	wheel_hop = 0.0
	has_transbrake = false
	launch_control = false
	shift_firmness = 1.0
	_advanced = false
	shift_map.clear()

func configure_build(build: Dictionary, vehicle: String = "kaze", plan: bool = true) -> void:
	# Always begin from the immutable vehicle data; repeated menu refreshes cannot stack parts.
	var original := _base_spec.duplicate(true)
	configure_vehicle(original)
	hardware = VehicleParts.normalize(build,vehicle,gearbox_stage)
	transmission_id = str(hardware.transmission)
	var trans := TransmissionCatalog.spec(transmission_id)
	transmission_kind = str(trans.kind)
	control_mode = VehicleParts.control_mode(hardware)
	has_converter = transmission_kind in ["automatic","drag"]
	trans_mass_delta = float(trans.mass)-float(TransmissionCatalog.spec(str(_base_spec.get("factory_trans","legacy6"))).mass)
	trans_efficiency = 0.90 if transmission_id == "legacy6" else minf(0.98,float(trans.efficiency)+gearbox_stage*0.003)
	rated_capacity = float(trans.capacity)
	shift_duration = TransmissionCatalog.duration(transmission_id,gearbox_stage)
	shift_retention = 0.60 if transmission_kind == "drag" else (0.35 if transmission_kind == "dct" else (0.25 if has_converter else 0.0))
	if transmission_id != "legacy6" or hardware.tune.has("gear_count"):
		gear_ratios.assign(TransmissionCatalog.default_ratios(transmission_id,hardware.tune))
	converter_stall = 4600.0 if transmission_kind == "drag" else 2700.0
	converter_multiplication = 1.95 if transmission_kind == "drag" else 1.82
	_advanced = transmission_id != "legacy6" or not hardware.parts.is_empty() or not hardware.tune.is_empty()
	if float(_base_spec.get("factory_super",0))>0 and not hardware.parts.has("induction"):
		_supercharger="roots"; _super_pressure=float(_base_spec.factory_super)
	if _base_spec.has("id"): _boost_onset=1200.0
	_mechanical_redline = redline_rpm
	for id in hardware.parts.values():
		if VehicleParts.compatible(str(id),hardware,gearbox_stage) != "": continue
		var part: Dictionary = VehicleParts.PARTS[id]
		_torque_factor *= float(part.get("torque",1.0))
		_flow += float(part.get("flow",0.0))
		_safe_factor *= float(part.get("safe",1.0))
		_fuel_factor *= float(part.get("fuel",1.0))
		_clutch_factor *= float(part.get("clutch",1.0))
		extra_mass += float(part.get("mass",0.0))
		if part.slot!="tires": extra_grip += float(part.get("grip",0.0))/(1.0+tire_stage*0.12)
		engine_inertia = maxf(0.08,engine_inertia+float(part.get("inertia",0.0)))
		_mechanical_redline += float(part.get("redline",0.0))
		if part.has("shift_scale"): shift_duration = maxf(0.14 if transmission_kind == "manual" else 0.035,shift_duration*float(part.shift_scale))
		wheel_inertia = maxf(0.5,wheel_inertia+float(part.get("wheel_inertia",0.0)))
		if part.has("radius"): tire_radius = float(part.radius)
		if part.has("transfer"): load_transfer_scale = float(part.get("fwd_transfer",0.10)) if drivetrain == "FWD" else float(part.transfer)
		if part.has("onset"): _boost_onset = float(part.onset)
		if part.has("spool"): _spool_override = float(part.spool)
		_boost_extra += float(part.get("boost_add",0.0))
		if part.has("super"):
			_supercharger = str(part.super)
			_super_pressure = float(part.pressure)
		rated_capacity *= float(part.get("capacity_scale",1.0))
		trans_efficiency = minf(0.995,trans_efficiency+float(part.get("efficiency_add",0.0)))
		_gear_cooling *= float(part.get("cooling_scale",1.0))
		_charge_cooling *= float(part.get("charge_cooling_scale",1.0))
		_pressure_add += float(part.get("pressure_add",0.0))
		_spool_scale *= float(part.get("spool_scale",1.0))
		if part.has("launch"): launch_control = true
	var tire: Dictionary = VehicleParts.PARTS.get(hardware.parts.get("tires",""),{})
	var suspension: Dictionary = VehicleParts.PARTS.get(hardware.parts.get("suspension",""),{})
	tire_grip = float(tire.get("grip",0.0))
	tire_launch_bite = float(tire.get("launch_bite",0.0))
	tire_slip_loss = float(tire.get("slip_loss",0.0))
	tire_sidewall_mark = int(tire.get("sidewall_mark",0))
	tire_radius *= float(tire.get("radius_scale",1.0))
	rolling_coefficient *= float(tire.get("rolling",1.0))
	suspension_launch_support = float(suspension.get("launch_support",0.0))
	hop_damping = float(suspension.get("hop_damping",0.0))
	var fitted: Array = hardware.parts.values()
	if VehicleParts.can_tune_rpm(hardware):
		redline_rpm = clampf(float(hardware.tune.get("redline",redline_rpm)),minf(6500.0,_mechanical_redline-500.0),_mechanical_redline)
	if hardware.parts.has("ecu"):
		launch_rpm = clampf(float(hardware.tune.get("launch_rpm",3900.0)),2200.0,redline_rpm-400.0)
	if _supercharger=="" and hardware.tune.has("boost"):
		var installed_boost := base_boost+(_boost_extra if hardware.parts.has("induction") else turbo_stage*0.18)+_pressure_add
		_boost_setting = clampf(float(hardware.tune.get("boost",installed_boost)),0.0,1.5)
	final_drive = clampf(float(hardware.tune.get("final_drive",final_drive)),2.0,5.5)
	var ratios = hardware.tune.get("ratios",[])
	if TransmissionCatalog.valid_ratios(ratios,Array(gear_ratios)): gear_ratios.assign(ratios)
	shift_firmness = clampf(float(hardware.tune.get("firmness",1.0)),0.5,1.0+gearbox_stage*0.1) if transmission_kind in ["drag","automatic","dct"] else 1.0
	if transmission_kind == "drag": launch_control = true; launch_rpm = clampf(float(hardware.tune.get("launch_rpm",launch_rpm)),2200,redline_rpm-400.0)
	throttle_gamma=1; traction_slip_target=0; clutch_rate=1; boost_rise=0; boost_by_gear=[]
	launch_gear=1; pressure_grip=1; pressure_rolling=1
	for key in hardware.tune:
		if not TuningSetup.EXTRA.has(key) and key!="boost_by_gear": continue
		var setting: Variant=TuningSetup.clean(key,hardware.tune[key],hardware,gearbox_stage,vehicle,turbo_stage)
		if setting==null: continue
		match key:
			"launch_enabled": launch_control=launch_control and float(setting)>.5
			"throttle_gamma": throttle_gamma=float(setting)
			"tc_slip": traction_slip_target=float(setting)
			"clutch_rate": clutch_rate=float(setting)
			"boost_rise": boost_rise=float(setting)
			"boost_by_gear": boost_by_gear=setting
			"launch_gear": launch_gear=int(setting)
			"diff_lock": extra_grip-=.055*(1.0-float(setting))/(1.0+tire_stage*.12)
			"tire_pressure":
				# Compound-specific straight-line pressure response; nominal setup is 32 psi.
				var peak := float(tire.get("pressure_peak",26.0))
				var nominal := 1.0-.0018*pow(32.0-peak,2)
				pressure_grip=clampf((1.0-.0018*pow(float(setting)-peak,2))/nominal,.68,1.06 if tire.is_empty() else 1.20)
				pressure_rolling=1.0+maxf(0,32-float(setting))*.018
			"launch_damping":
				hop_damping=clampf(hop_damping*float(setting),0,.95)
				suspension_launch_support *= 1.0+.32*(float(setting)-1.0)
	gear = clampi(gear,0,gear_ratios.size())
	if _advanced and plan: rebuild_shift_map()

func input_capacity() -> float:
	return rated_capacity*1.23*TransmissionCatalog.strength(gearbox_stage)

func power_torque(at_rpm: float, pressure: float) -> float:
	var value := torque_at(at_rpm)*(1.0+pressure*0.8)
	if _supercharger != "": value -= torque_at(at_rpm)*pressure*0.12
	value = minf(value,supported_engine_torque())
	return maxf(0.0,value)

func supported_engine_torque() -> float:
	return minf(fuel_torque_capacity(),mechanical_torque_capacity())

func fuel_torque_capacity() -> float:
	var legacy_peak := base_torque*(1.0+engine_stage*0.14)*(1.0+exhaust_stage*0.06)
	return legacy_peak*2.9*_fuel_factor

func mechanical_torque_capacity() -> float:
	var legacy_peak := base_torque*(1.0+engine_stage*0.14)*(1.0+exhaust_stage*0.06)
	# Raising boost must not manufacture stronger rods/pistons. Engine capacity
	# follows the factory rating and fitted strength parts, not requested pressure.
	return legacy_peak*(1.0+base_boost*0.8)*1.9*_safe_factor

func full_engine_torque(at_rpm: float) -> float:
	return power_torque(at_rpm,boost_target(at_rpm,1.0))

func rebuild_shift_map() -> void:
	shift_map = ShiftPlanner.build(self)
	var chosen = hardware.tune.get("shift_rpms",[])
	if chosen is Array and chosen.size() == shift_map.size():
		for i in chosen.size():
			if (chosen[i] is float or chosen[i] is int) and is_finite(float(chosen[i])): shift_map[i] = clampf(float(chosen[i]),idle_rpm+1500.0,redline_rpm-50.0)

func select_manual_gear(target: int, clutch_command: float) -> String:
	if control_mode != "hpattern": return "H GATE NOT INSTALLED"
	if clutch_command < 0.8:
		if target!=gear and target>=0 and target<=gear_ratios.size() and running:
			grind_serial += 1
		return "HOLD CLUTCH"
	if shift_left > 0.0: return "GEAR ENGAGING"
	if target < 0 or target > gear_ratios.size(): return "GEAR LIMIT"
	if target == gear: return "ALREADY SELECTED"
	var proposed := maxf(wheel_rpm(target),wheel_omega*ratio_for(target)*RPM_PER_RAD)
	if target > 0 and proposed > redline_rpm+180.0: rejected_serial += 1; return "DOWNSHIFT PROTECTED"
	last_shift_rpm = rpm
	last_shift_load = engine_load
	var perfect := gear>0 and target==gear+1 and rpm>=good_shift_min() and rpm<=good_shift_max() and wheelspin<0.10
	shift_direction = signi(target-gear)
	shift_message = "NEUTRAL" if target==0 else ("PERFECT SHIFT" if perfect else "MANUAL SHIFT")
	gear = target
	shift_left = shift_duration
	shift_serial += 1
	cancel_shift_request()
	return "SHIFT ACCEPTED"

func converter_step(dt: float, pump: float, coupled: bool, shifting: bool) -> float:
	converter_pump_nm = 0.0
	converter_turbine_nm = 0.0
	converter_input_w = 0.0
	converter_output_w = 0.0
	converter_heat_w = 0.0
	if not coupled:
		turbine_omega = 0.0
		converter_lock = 0.0
		return pump
	var sr := clampf(turbine_omega/maxf(pump,1.0),0.0,1.2)
	var before_energy := 0.5*engine_inertia*pump*pump+0.5*0.12*turbine_omega*turbine_omega
	var should_lock := transmission_kind != "drag" and gear >= 2 and speed > 12.0 and sr > 0.85 and not shifting
	converter_lock = move_toward(converter_lock,1.0 if should_lock else 0.0,dt*5.0)
	var capacity := base_torque*1.10/pow(converter_stall/RPM_PER_RAD,2.0)
	var slip := clampf((pump-turbine_omega)/maxf(1.0,pump),-1.0,1.0)
	var tp := capacity*pump*pump*clampf(slip/0.08,-0.25,1.0)*(1.0-converter_lock)
	tp = clampf(tp,-clutch_capacity(),minf(clutch_capacity(),maxf(0.0,pump)*engine_inertia/dt))
	var multiplication := minf(1.0+(converter_multiplication-1.0)*pow(maxf(0.0,1.0-sr),1.5),0.98/maxf(sr,0.01)) if tp > 0.0 else 1.0
	# Bound the discrete fluid impulse so the passive converter cannot create energy.
	var passive_bound := 2.0*absf(pump-multiplication*turbine_omega)/(1.0/engine_inertia+multiplication*multiplication/0.12)
	tp = signf(tp)*minf(absf(tp),passive_bound/dt)
	var tt := tp*multiplication
	var old_pump := pump
	var old_turbine := turbine_omega
	converter_pump_nm = tp
	converter_turbine_nm = tt
	pump -= tp/engine_inertia*dt
	turbine_omega += tt/0.12*dt
	converter_input_w = maxf(0.0,tp*(old_pump+pump)*0.5)
	converter_output_w = maxf(0.0,tt*(old_turbine+turbine_omega)*0.5)
	var lock_impulse := (pump-turbine_omega)/(1.0/engine_inertia+1.0/0.12)
	lock_impulse = clampf(lock_impulse,-clutch_capacity()*converter_lock*dt,clutch_capacity()*converter_lock*dt)
	pump -= lock_impulse/engine_inertia
	turbine_omega += lock_impulse/0.12
	converter_pump_nm += lock_impulse/dt
	converter_turbine_nm += lock_impulse/dt
	converter_heat_w = maxf(0.0,(before_energy-0.5*engine_inertia*pump*pump-0.5*0.12*turbine_omega*turbine_omega)/dt)
	return maxf(0.0,pump)
