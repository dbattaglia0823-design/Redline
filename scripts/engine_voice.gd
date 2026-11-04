class_name EngineVoice
extends RefCounted

# Original continuous synthesis. No recordings or loop restarts.
const RATE := 22050.0
var target_rpm := 950.0
var target_throttle := 0.0
var target_load := 0.0
var target_clutch := 0.0
var target_boost := 0.0
var target_slip := 0.0
var target_gain := 1.0
var target_cut := false
var target_combustion := 1.0
var target_nitrous := false
var target_nitrous_flow := 0.0
var target_supercharger := 0.0
var target_decel := 0.0
var target_engine := 0.0
var target_exhaust := 0.0
var target_turbo := 0.0
var target_transmission := 0.0
var target_wheel_hz := 0.0
var idle_rpm := 950.0
var redline_rpm := 7600.0
var profile_name := "I4 street"
var cylinders := 4
var rpm := 950.0
var throttle := 0.0
var load_value := 0.0
var clutch_value := 0.0
var boost := 0.0
var slip := 0.0
var decel := 0.0
var engine_build := 0.0
var exhaust_build := 0.0
var turbo_build := 0.0
var transmission_build := 0.0
var wheel_hz := 0.0
var nitro_gain := 0.0
var supercharger_blend := 0.0
var gain := 0.0
var cut_gain := 1.0
var phase := 0.0
var crank_phase := 0.0
var turbo_phase := 0.0
var tire_phase := 0.0
var gear_phase := 0.0
var filtered := 0.0
var intake_filter := 0.0
var filtered_noise := 0.0
var pop := 0.0
var pop_gain := 0.0
var blowoff := 0.0
var blowoff_gain := 0.0
var shift_tick := 0.0
var shift_tick_gain := 0.0
var noise_seed := 17743
var last_sample := 0.0
var peak_jump := 0.0
var samples_generated := 0
var last_shift_serial := -1
var _blowoff_armed := false
var _overrun_armed := false
# bass, upper-harmonic balance, firing-pulse modulation, intake resonance
var _character := Vector4(1.0,1.0,0.075,1.0)
var _target_character := Vector4(1.0,1.0,0.075,1.0)
var engine_mix := 1.0
var induction_mix := 1.0
var tire_mix := 1.0
var mechanical_mix := 1.0
var exhaust_fx_mix := 1.0
var nitro_mix := 1.0
var hybrid_power := 0.0
var _induction_type := ""
var _gearbox_kind := ""
var _intake_gain := 1.0
var _hybrid_phase := 0.0
var _compressor_scale := 1.0
var _gear_whine_level := .0015
var _super_ratio := 18.0

static func band_weights(at_rpm: float, idle: float = 950.0, redline: float = 7600.0) -> Vector4:
	var x := clampf((at_rpm-idle)/maxf(1.0,redline-idle),0.0,1.0)
	var a := smoothstep(0.02,0.18,x)
	var b := smoothstep(0.22,0.52,x)
	var c := smoothstep(0.58,0.90,x)
	return Vector4(1.0-a,a*(1.0-b),a*b*(1.0-c),a*b*c)

func set_from_vehicle(car: Drivetrain, audible: bool = true) -> void:
	target_rpm = car.rpm
	target_throttle = car.throttle
	target_load = car.engine_load
	target_clutch = car.clutch_engagement
	target_boost = car.boost
	target_slip = car.wheelspin
	target_cut = car.fuel_cut
	target_combustion = car.combustion_fraction
	target_nitrous = car.nitrous_active
	target_nitrous_flow = car.nitrous_delivery
	target_supercharger = 1.0 if car._supercharger != "" else 0.0
	_induction_type = car._supercharger
	_gearbox_kind = car.transmission_kind
	_gear_whine_level = .012 if car.transmission_kind in ["sequential","drag"] else .0015
	_super_ratio = 36.0 if car._supercharger=="centrifugal" else 18.0
	_intake_gain = 1.45 if car.hardware.parts.values().has("plenum") else 1.0
	_compressor_scale = .80 if car.hardware.parts.values().has("turbo_race") else (1.12 if car.hardware.parts.values().has("turbo_hybrid") else 1.0)
	hybrid_power = car.hybrid_power_w
	target_decel = clampf(-car.engine_torque/maxf(1.0,car.base_torque),0.0,1.0) if car.throttle < 0.25 and car.clutch_engagement > 0.4 else 0.0
	target_engine = car.engine_stage/3.0
	target_exhaust = car.exhaust_stage/3.0
	if car.hardware.parts.values().has("headers"): target_exhaust += 0.2
	target_turbo = car.turbo_stage/3.0
	target_transmission = car.gearbox_stage/3.0
	target_wheel_hz = car.wheel_omega/TAU*car.ratio_for(car.gear) if car.gear > 0 else 0.0
	target_gain = 1.0 if audible else 0.0
	idle_rpm = car.idle_rpm
	redline_rpm = car.redline_rpm
	cylinders = car.cylinders
	match car.engine_layout:
		"W16":
			profile_name="W16 quad turbo"; _target_character=Vector4(1.4,.68,.035,.78)
		"H4":
			profile_name="Boxer four"; _target_character=Vector4(1.03,.94,.12,1.04)
		"H6":
			profile_name="Boxer six"; _target_character=Vector4(1.12,.83,.045,.94)
		"VR6":
			profile_name="Narrow angle six"; _target_character=Vector4(1.2,.85,.07,.91)
		"V8", "V10":
			profile_name = car.engine_layout+" performance"
			_target_character = Vector4(1.35,.82,.15,.85) if car.cylinders == 8 else Vector4(1.08,1.05,.04,1.1)
		"I6":
			profile_name = "I6 smooth"
			_target_character = Vector4(1.14,0.72,0.025,0.82)
		"V6":
			profile_name = "V6 twin turbo"
			_target_character = Vector4(1.28,0.90,0.12,0.90)
		_:
			profile_name = "I4 compact" if car.base_torque < 225.0 else "I4 street"
			_target_character = Vector4(0.90,1.12,0.09,1.18) if car.base_torque < 225.0 else Vector4(1.0,1.0,0.075,1.0)
	if last_shift_serial < 0: last_shift_serial = car.shift_serial
	elif car.shift_serial != last_shift_serial:
		# A real loaded shift can ignite a small exhaust transient; a neutral tap cannot.
		if car.last_shift_rpm > 2800.0 and car.last_shift_load > 0.25:
			pop = maxf(pop,0.20+target_exhaust*0.35+target_engine*0.10)
		shift_tick = 0.18+target_transmission*0.18
		last_shift_serial = car.shift_serial
	if car.throttle > 0.6 and car.boost > 0.1 and car._supercharger == "": _blowoff_armed = true
	if _blowoff_armed and car.throttle < 0.3:
		blowoff = clampf(car.boost*1.5,0.18,0.7)
		_blowoff_armed = false
	if car.throttle > 0.65 and car.engine_load > 0.4: _overrun_armed = true
	if _overrun_armed and car.throttle < 0.18:
		if car.rpm > 3400.0 and car.exhaust_stage > 0: pop = maxf(pop,target_exhaust*0.24)
		_overrun_armed = false

func next_sample() -> float:
	rpm += (target_rpm-rpm)*0.00565 # ~8 ms; never reset firing phase on a shift.
	throttle += (target_throttle-throttle)*0.003
	load_value += (clampf(target_load,0.0,1.0)-load_value)*0.003
	clutch_value += (target_clutch-clutch_value)*0.004
	boost += (target_boost-boost)*0.002
	slip += (target_slip-slip)*0.003
	decel += (target_decel-decel)*0.0025
	engine_build += (target_engine-engine_build)*0.0015
	exhaust_build += (target_exhaust-exhaust_build)*0.0015
	turbo_build += (target_turbo-turbo_build)*0.0015
	transmission_build += (target_transmission-transmission_build)*0.0015
	wheel_hz += (target_wheel_hz-wheel_hz)*0.003
	nitro_gain += (target_nitrous_flow-nitro_gain)*0.003
	supercharger_blend += (target_supercharger-supercharger_blend)*0.0015
	_character = _character.lerp(_target_character,0.0015)
	gain += (target_gain-gain)*0.0032
	cut_gain += ((0.12+0.88*target_combustion)-cut_gain)*0.008
	var firing_hz := rpm/60.0*float(cylinders)*0.5
	phase = fposmod(phase+firing_hz/RATE,1.0)
	crank_phase = fposmod(crank_phase+rpm/60.0/RATE,1.0)
	var p := phase*TAU
	var crank := crank_phase*TAU
	var bands := band_weights(rpm,idle_rpm,redline_rpm)
	var h1 := bands.dot(Vector4(0.65,0.55,0.44,0.27))*_character.x
	var h2 := bands.dot(Vector4(0.14,0.23,0.28,0.40))
	var h3 := bands.dot(Vector4(0.04,0.085,0.15,0.21))*_character.y
	var brightness := (bands.z*0.065+bands.w*0.12)*(1.0+engine_build*0.35+exhaust_build*0.6)*_character.y
	var pulse := sin(p)*h1+sin(p*2.0+0.18)*h2+sin(p*3.0+0.12)*h3
	for harmonic in range(4,9):
		var audible := 1.0-smoothstep(RATE*0.36,RATE*0.45,firing_hz*harmonic)
		pulse += sin(p*harmonic+0.075*harmonic)*brightness*(4.0/float(harmonic))*audible
	var idle_lope := (1.0+sin(crank*0.5)*_character.z*(bands.x+0.25))
	var block := sin(crank)*(0.06+bands.x*0.025)+sin(crank*0.5)*0.025*_character.x
	noise_seed = (noise_seed*1664525+1013904223)&0xffffffff
	var noise := float(noise_seed)/2147483648.0-1.0
	filtered_noise += (noise-filtered_noise)*0.20
	var body := tanh((pulse*idle_lope+block)*(1.05+load_value*0.7+exhaust_build*0.3))
	var cutoff := 900.0+rpm*0.14+load_value*1900.0+exhaust_build*1000.0-decel*900.0
	filtered += (body-filtered)*(1.0-exp(-TAU*maxf(400.0,cutoff)/RATE))
	intake_filter += (noise-intake_filter)*(0.08+load_value*0.12)
	var amplitude := (0.10+throttle*0.16+load_value*0.22)*(0.75+0.25*clutch_value)*(1.0+exhaust_build*0.12)*cut_gain
	var overrun := sin(p)*decel*0.055*(1.0+exhaust_build*0.3)
	var induction_hz := lerpf(900.0+boost*(1600.0+turbo_build*650.0)+rpm*0.025,300.0+rpm*0.22,supercharger_blend)
	turbo_phase = fposmod(turbo_phase+induction_hz/RATE,1.0)
	tire_phase = fposmod(tire_phase+(1050.0+slip*600.0)/RATE,1.0)
	gear_phase = fposmod(gear_phase+clampf(wheel_hz*5.0,0.0,4500.0)/RATE,1.0)
	var induction := (intake_filter*0.045*_character.w*throttle+sin(turbo_phase*TAU)*(0.013+turbo_build*0.007))*boost
	var tire := (sin(tire_phase*TAU)*0.015+filtered_noise*0.065)*slip
	var gear_whine := sin(gear_phase*TAU)*(0.010 if _gearbox_kind in ["sequential","drag"] else 0.002)*clutch_value*load_value
	pop_gain += (pop-pop_gain)*0.018
	blowoff_gain += (blowoff-blowoff_gain)*0.008
	shift_tick_gain += (shift_tick-shift_tick_gain)*0.025
	var transient := filtered_noise*(pop_gain*0.21*exhaust_fx_mix+blowoff_gain*0.24*induction_mix)+noise*shift_tick_gain*0.025*mechanical_mix
	var nitro := intake_filter*0.07*nitro_gain*nitro_mix
	pop *= 0.9990
	blowoff *= 0.9996
	shift_tick *= 0.9965
	var sample := tanh(((filtered*amplitude+overrun)*engine_mix+induction*induction_mix+tire*tire_mix+gear_whine*mechanical_mix+transient+nitro)*gain)
	peak_jump = maxf(peak_jump,absf(sample-last_sample))
	last_sample = sample
	samples_generated += 1
	return sample

func next_effect_sample() -> float:
	# Lightweight runtime effects when native loop voices provide the main engine.
	rpm+=(target_rpm-rpm)*.00565
	throttle+=(target_throttle-throttle)*.003
	load_value+=(clampf(target_load,0,1)-load_value)*.003
	boost+=(target_boost-boost)*.002
	slip+=(target_slip-slip)*.003
	gain+=(target_gain-gain)*.0032
	nitro_gain+=(target_nitrous_flow-nitro_gain)*.003
	supercharger_blend+=(target_supercharger-supercharger_blend)*.0015
	wheel_hz+=(target_wheel_hz-wheel_hz)*.003
	noise_seed=(noise_seed*1664525+1013904223)&0xffffffff
	var noise:=float(noise_seed)/2147483648.0-1.0
	filtered_noise+=(noise-filtered_noise)*.20
	intake_filter+=(noise-intake_filter)*.10
	var hz:=clampf(lerpf((950+boost*(1700+target_turbo*600))*_compressor_scale,rpm/60*_super_ratio,supercharger_blend),100,8000)
	turbo_phase=fposmod(turbo_phase+hz/RATE,1)
	tire_phase=fposmod(tire_phase+(1050+slip*600)/RATE,1)
	gear_phase=fposmod(gear_phase+clampf(wheel_hz*5,0,4500)/RATE,1)
	_hybrid_phase=fposmod(_hybrid_phase+(300+rpm*.08)/RATE,1)
	pop_gain+=(pop-pop_gain)*.018; blowoff_gain+=(blowoff-blowoff_gain)*.008; shift_tick_gain+=(shift_tick-shift_tick_gain)*.025
	var pressure:=maxf(boost,throttle*.20*supercharger_blend)
	var induction: float=(sin(turbo_phase*TAU)*(.010+target_turbo*.006)+intake_filter*.025*_intake_gain)*pressure*induction_mix if pressure*induction_mix>.00001 else 0.0
	var tire: float=(sin(tire_phase*TAU)*.014+filtered_noise*.07)*slip*tire_mix if slip*tire_mix>.00001 else 0.0
	var whine:=sin(gear_phase*TAU)*_gear_whine_level*target_clutch*load_value if target_clutch*load_value>.00001 else 0.0
	var transients:=filtered_noise*(pop_gain*.21*exhaust_fx_mix+blowoff_gain*.24*induction_mix)+noise*shift_tick_gain*.025*mechanical_mix
	var electric:=sin(_hybrid_phase*TAU)*clampf(hybrid_power/162000,0,1)*.009*mechanical_mix if hybrid_power>1 else 0.0
	pop*=.9990; blowoff*=.9996; shift_tick*=.9965
	var value:=tanh((induction+tire+whine*mechanical_mix+transients+intake_filter*.07*nitro_gain*nitro_mix+electric)*gain)
	peak_jump=maxf(peak_jump,absf(value-last_sample)); last_sample=value; samples_generated+=1
	return value

func render(count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(count)
	for i in count: result[i] = next_sample()
	return result
