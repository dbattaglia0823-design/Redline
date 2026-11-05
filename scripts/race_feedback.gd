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
var _shock := 0.0

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

func update(dt: float, car: Drivetrain, paused: bool, spec: Dictionary, origin: Vector2 = Vector2(210,410)) -> void:
	if paused: return
	dt = clampf(dt,0.0,0.1)
	visual_rpm = lerpf(visual_rpm,car.rpm,1.0-exp(-dt/0.022))
	visual_mph = lerpf(visual_mph,car.speed*Drivetrain.MPH_PER_MPS,1.0-exp(-dt/0.035))
	visual_distance = lerpf(visual_distance,car.distance,1.0-exp(-dt/0.024))
	if car.shift_serial != _last_shift:
		_last_shift = car.shift_serial
		shift_pulse = 1.0
		var loaded := clampf(car.last_shift_load,0.0,1.0)
		_shock = maxf(_shock,loaded*clampf(car.base_torque/car.mass()*3.0,0.15,1.0))
		if car.last_shift_rpm > 2800.0: exhaust_glow = loaded*(0.3+car.exhaust_stage*0.16)
	shift_pulse *= exp(-dt/0.10)
	exhaust_glow *= exp(-dt/0.075)
	start_flash *= exp(-dt/0.22)
	finish_flash *= exp(-dt/0.25)
	_shock *= exp(-dt/0.13)
	var launch := car.wheelspin*clampf(car.acceleration/7.0,0.0,1.0) if car.speed < 12.0 else 0.0
	var magnitude := minf(2.5,_shock*2.0+launch*0.65)
	var shake := Vector2(sin(car.elapsed*137.0)*0.5,sin(car.elapsed*173.0))*magnitude
	var follow := Vector2(clampf(-car.acceleration*0.32,-2.5,2.5),0.0)
	camera_offset = camera_offset.lerp((follow+shake)*([.25,.65,1.0][clampi(quality,0,2)]),1-exp(-dt/.045))
	body_pitch = lerpf(body_pitch,clampf(-car.acceleration*.0015+_shock*.006,-.006,.006),1.0-exp(-dt/0.08))
	_vibration_phase = fposmod(_vibration_phase+dt*car.rpm/60.0*TAU,TAU)
	var idle_vibration := sin(_vibration_phase)*.16*clampf(1.0-car.speed/8.0,0,1)*clampf((2200-car.rpm)/1200,0,1) if quality > 0 else 0.0
	var compression := clampf(car.acceleration*.20,-.85,1.55)
	body_offset = body_offset.lerp(Vector2(-_shock*.3,compression+idle_vibration+_shock*.35),1-exp(-dt/.055))
	for i in range(smoke.size()-1,-1,-1):
		var p := smoke[i]
		p.age += dt
		p.position += p.velocity*dt
		p.velocity.x *= exp(-dt*.65)
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
		var art := VehicleAppearance.definition(str(spec.get("id","kaze")))
		if art.is_empty(): break
		var anchor := VehicleAppearance.point(art.rear if wheel_index == 0 else art.front)
		var radii: Array = art.get("wheel_radii",[art.radius,art.radius])
		var tire_scale := WheelVisuals.radius_scale(car,spec)
		anchor.y += float(radii[wheel_index])*tire_scale-float(art.radius)*(tire_scale-1)
		var contact := origin+anchor*.232*1.65
		_particle_serial += 1
		var spread := sin(_particle_serial*2.399)
		smoke.append({"position":contact,"velocity":Vector2(-minf(190.0,25.0+car.speed*7.0)+spread*9.0,-18.0-spread*9.0),"age":0.0,"life":0.70+spread*0.14,"strength":car.wheelspin})
