class_name RaceFeedback
extends RefCounted

# Presentation only: this class never writes drivetrain state or input.
var visual_rpm := 950.0
var visual_mph := 0.0
var visual_distance := 0.0
var camera_offset := Vector2.ZERO
var body_pitch := 0.0
var body_offset := Vector2.ZERO
var quality := 2
var _vibration_phase := 0.0
var shift_pulse := 0.0
var exhaust_glow := 0.0
var start_flash := 0.0
var finish_flash := 0.0
var smoke: Array[Dictionary] = []
var _emission := 0.0
var _particle_serial := 0
var _last_shift := 0
var _last_grind := 0
var grind_notice := 0.0
var traction_recovered := 0.0
var traction_lost := false
var clutch_warning := 0.0
var gearbox_warning := 0.0
var _shock := 0.0
var _pitch_velocity := 0.0
var _heave := 0.0
var _heave_velocity := 0.0
var _last_slip := 0.0
var _lift_armed := false
var _backfire_cooldown := 0.0
var _combustion_phase := 0.0
var exhaust_pulse := 0.0
var boost_haze := 0.0
var nitrous_glow := 0.0
var rear_compression := 0.0
var front_compression := 0.0

static func backfire_capable(car: Drivetrain) -> bool:
	return car.exhaust_stage > 0 or car.hardware.parts.has("exhaust") or car.hardware.parts.has("ecu")

# A presentation spring, not a new force in the drivetrain solver. Small fixed
# integration steps keep recovery stable across render rates and long frames.
func suspension(dt: float, car: Drivetrain) -> void:
	var package: String = str(car.hardware.parts.get("suspension",""))
	var stiffness := float(VehicleParts.PARTS.get(package,{}).get("frequency",14.0))
	var frequency := stiffness*sqrt(1280.0/car.mass())
	var compliance := clampf(car.load_transfer_scale/.18,.45,1.45)
	var drive_factor := .82 if car.drivetrain=="FWD" else (.92 if car.drivetrain=="AWD" else 1.0)
	var target := clampf(-car.acceleration*.00067*compliance*drive_factor,-.0054,.0054)
	var heave_target := clampf(absf(car.acceleration)*.035+_shock*.22+car.wheel_hop*sin(car._sim_time*TAU*10.0),0,.65)
	var remaining := dt
	while remaining > .000001:
		var h := minf(remaining,1.0/120.0)
		_pitch_velocity += ((target-body_pitch)*frequency*frequency-1.5*frequency*_pitch_velocity)*h
		body_pitch = clampf(body_pitch+_pitch_velocity*h,-.006,.006)
		_heave_velocity += ((heave_target-_heave)*frequency*frequency-1.7*frequency*_heave_velocity)*h
		_heave = clampf(_heave+_heave_velocity*h,-.4,.8)
		remaining -= h
	# Approximate sprung travel at each axle in screen pixels. Tire centers stay
	# fixed on the road; the renderer rotates only the body around its pivot.
	var axles: Array = car._base_spec.get("wheelbase",[215,790])
	var span := (float(axles[1])-float(axles[0]))*.232*1.65*.5
	rear_compression = clampf(_heave-body_pitch*span,-1.5,1.5)
	front_compression = clampf(_heave+body_pitch*span,-1.5,1.5)

func set_quality(value: int) -> void:
	quality = clampi(value,0,2)
	smoke.resize(mini(smoke.size(),int([8,24,48][quality])))

func reset(car: Drivetrain) -> void:
	visual_rpm = car.rpm
	visual_mph = car.speed*Drivetrain.MPH_PER_MPS
	visual_distance = car.distance
	camera_offset = Vector2.ZERO
	body_pitch = 0.0
	body_offset = Vector2.ZERO
	_vibration_phase = 0.0
	shift_pulse = 0.0
	exhaust_glow = 0.0
	start_flash = 0.0
	finish_flash = 0.0
	smoke.clear()
	_emission = 0.0
	_particle_serial = 0
	_shock = 0.0
	_last_shift = car.shift_serial
	_last_grind = car.grind_serial
	grind_notice = 0.0
	traction_recovered = 0.0
	traction_lost = false
	clutch_warning = 0.0
	gearbox_warning = 0.0
	_pitch_velocity = 0; _heave = 0; _heave_velocity = 0
	_last_slip = car.wheelspin; _lift_armed = car.throttle>.7
	_backfire_cooldown = 0; _combustion_phase = 0
	exhaust_pulse = 0; boost_haze = 0; nitrous_glow = 0
	rear_compression = 0; front_compression = 0

func update_driving_cues(dt: float, car: Drivetrain) -> void:
	grind_notice = maxf(0.0,grind_notice-dt)
	traction_recovered = maxf(0.0,traction_recovered-dt)
	if car.grind_serial>_last_grind: grind_notice = 0.8
	_last_grind = car.grind_serial
	clutch_warning = clampf(clutch_warning+(dt if car.clutch_overloaded else -dt*1.5),0.0,.25)
	gearbox_warning = clampf(gearbox_warning+(dt if car.transmission_slipping else -dt*1.5),0.0,.25)
	if car.running and car.wheelspin>.14 and car.throttle>.25:
		traction_lost = true
		traction_recovered = 0.0
	elif traction_lost and (car.wheelspin<.07 or not car.running):
		traction_lost = false
		if car.running and car.speed>2.0: traction_recovered = .65

func update(dt: float, car: Drivetrain, paused: bool, spec: Dictionary, origin: Vector2 = Vector2(210,410), reduced_motion: bool = false, pixels_per_meter: float = 12.0) -> void:
	if paused: return
	dt = clampf(dt,0.0,0.1)
	update_driving_cues(dt,car)
	visual_rpm = lerpf(visual_rpm,car.rpm,1.0-exp(-dt/0.022))
	visual_mph = lerpf(visual_mph,car.speed*Drivetrain.MPH_PER_MPS,1.0-exp(-dt/0.035))
	visual_distance = lerpf(visual_distance,car.distance,1.0-exp(-dt/0.024))
	_backfire_cooldown = maxf(0,_backfire_cooldown-dt)
	var lifted := _lift_armed and car.throttle < .25
	var shifted := car.shift_serial != _last_shift
	var hot := car.last_shift_rpm > 4500 and car.last_shift_load > .35 if shifted else car.rpm > 4500 and lifted
	if car.running and backfire_capable(car) and hot and _backfire_cooldown<=0 and (lifted or (shifted and car.shift_serial%2==0)):
		exhaust_glow = clampf(.3+car.exhaust_stage*.15+car.boost*.12,.3,.85)
		_backfire_cooldown = .65
	if car.throttle>.7: _lift_armed = true
	elif lifted: _lift_armed = false
	_combustion_phase = fposmod(_combustion_phase+dt*car.rpm/120.0*car.cylinders*TAU,TAU)
	exhaust_pulse = (.45+.55*pow(.5+.5*sin(_combustion_phase),2))*(.2+.8*car.throttle) if car.running or car.staging_motion else 0.0
	boost_haze = lerpf(boost_haze,clampf(car.boost*.25,0,.3) if car.running or car.staging_motion else 0.0,1-exp(-dt/.12))
	nitrous_glow = lerpf(nitrous_glow,car.nitrous_delivery if car.nitrous_active else 0.0,1-exp(-dt/.07))
	if shifted:
		_last_shift = car.shift_serial
		shift_pulse = 1.0
		var loaded := clampf(car.last_shift_load,0.0,1.0)
		_shock = maxf(_shock,loaded*clampf(car.base_torque/car.mass()*3.0,0.15,1.0))
		_pitch_velocity += loaded*.009
	shift_pulse *= exp(-dt/0.10)
	exhaust_glow *= exp(-dt/0.075)
	start_flash *= exp(-dt/0.22)
	finish_flash *= exp(-dt/0.25)
	_shock *= exp(-dt/0.13)
	var launch := (.2+.5*car.wheelspin)*clampf(car.acceleration/8.0,0.0,1.0) if car.speed < 15.0 else 0.0
	var magnitude := minf(2.5,_shock*2.0+launch*0.65)
	var shake := Vector2(sin(car.elapsed*137.0)*0.5,sin(car.elapsed*173.0))*magnitude
	var follow := Vector2(clampf(-car.acceleration*0.32,-2.5,2.5),0.0)
	camera_offset = Vector2.ZERO if reduced_motion else camera_offset.lerp((follow+shake)*([.25,.65,1.0][clampi(quality,0,2)]),1-exp(-dt/.045))
	if _last_slip-car.wheelspin > .15 and car.acceleration > 0:
		_pitch_velocity -= minf(_last_slip-car.wheelspin,.5)*.006
	_last_slip = car.wheelspin
	suspension(dt,car)
	_vibration_phase = fposmod(_vibration_phase+dt*car.rpm/60.0*TAU,TAU)
	var idle_vibration := sin(_vibration_phase)*.16*clampf(1.0-car.speed/8.0,0,1)*clampf((2200-car.rpm)/1200,0,1) if quality > 0 else 0.0
	body_offset = Vector2(-_shock*.3,_heave+idle_vibration)
	for i in range(smoke.size()-1,-1,-1):
		var p := smoke[i]
		p.age += dt
		p.velocity.x = lerpf(float(p.velocity.x),-car.speed*pixels_per_meter,1-exp(-dt*.9))
		p.velocity.y -= dt*10.0
		p.position += p.velocity*dt
		if p.age >= p.life: smoke.remove_at(i)
	if (not car.running and not car.staging_motion) or car.wheelspin < 0.08 or car.throttle < 0.35:
		_emission = 0.0
		return
	_emission += dt*float([12,20,32][clampi(quality,0,2)])*car.wheelspin
	var count := mini(floori(_emission),4)
	_emission -= count
	for index in count:
		if smoke.size() >= int([8,24,48][clampi(quality,0,2)]): break
		var wheel_index := 1 if car.drivetrain == "FWD" else 0
		if car.drivetrain == "AWD": wheel_index = _particle_serial%2
		var definition := VehicleAppearance.definition(str(spec.get("id","")))
		var anchor := VehicleAppearance.point(definition.rear if wheel_index==0 else definition.front) if not definition.is_empty() else Vector2(float(spec.wheelbase[wheel_index]),float(spec.wheel_y))
		var stock_radius: float = float(definition.get("wheel_radii",[spec.wheel_radius,spec.wheel_radius])[wheel_index])
		var lift := float(definition.get("radius",spec.wheel_radius))*(WheelVisuals.radius_scale(car,spec)-1)
		var x := origin.x+anchor.x*0.232*1.65
		var y := origin.y+(anchor.y-lift+stock_radius*WheelVisuals.radius_scale(car,spec)*.96)*0.232*1.65
		_particle_serial += 1
		var spread := sin(_particle_serial*2.399)
		smoke.append({"position":Vector2(x,y),"velocity":Vector2(-minf(260.0,40.0+car.speed*12.0)+spread*9.0,-18.0-spread*9.0),"age":0.0,"life":1.05+spread*.18,"strength":car.wheelspin*clampf(absf(car.wheel_omega*car.tire_radius-car.speed)/8.0,.15,1.0),"seed":spread})
