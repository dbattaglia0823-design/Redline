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
var last_grind_serial := -1
var grind_left := 0.0
var grind_phase := 0.0
var _blowoff_armed := false
var _overrun_armed := false
# Transient compressor relief belongs to the current engine and is driven by
# its live pressure, not by arbitrary shift or button-press sound cues.
var _blowoff_pressure := 0.0
var _blowoff_cooldown := 0.0
var _blowoff_decay := 0.9996
var _blowoff_flutter := 0.0
var _blowoff_noise_low := 0.0
var _blowoff_noise_high := 0.0
var _blowoff_phase := 0.0
var _blowoff_flutter_phase := 0.0
var _turbo_air_low := 0.0
var _turbo_air_high := 0.0
var _turbo_active := false
var _turbo_spool := 0.0
var _turbo_whistle := 0.0
var blowoff_events := 0
var last_blowoff_reason := ""
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
var supercharger_profile := "None"
var _super_level := 0.0
var _super_harmonic := 0.0
var _super_sub := 0.0
var _super_roughness := 0.0
var _super_air := 0.0
var _super_bypass := 0.0
var _super_sub_phase := 0.0
var _super_mod_phase := 0.0
var _launch_phase := 0.0
var target_launch := false
var target_motor_hz:=0.0

static func band_weights(at_rpm: float, idle: float = 950.0, redline: float = 7600.0) -> Vector4:
	var x := clampf((at_rpm-idle)/maxf(1.0,redline-idle),0.0,1.0)
	var a := smoothstep(0.02,0.18,x)
	var b := smoothstep(0.22,0.52,x)
	var c := smoothstep(0.58,0.90,x)
	return Vector4(1.0-a,a*(1.0-b),a*b*(1.0-c),a*b*c)

func set_from_vehicle(car: Drivetrain, audible: bool = true) -> void:
	if last_grind_serial>=0 and car.grind_serial>last_grind_serial and audible:
		grind_left=.19
		grind_phase=0.0
	last_grind_serial=car.grind_serial
	if not audible: grind_left=0.0
	target_rpm = car.rpm
	target_throttle = car.throttle
	target_load = car.engine_load
	target_clutch = car.clutch_engagement
	target_boost = car.boost
	target_slip = car.wheelspin
	target_cut = car.fuel_cut
	target_combustion = car.combustion_fraction
	target_launch = EngineAudioProfile.launch_active(car)
	target_nitrous = car.nitrous_active
	target_nitrous_flow = car.nitrous_delivery
	target_supercharger = 1.0 if car._supercharger != "" else 0.0
	_induction_type = car._supercharger
	_turbo_active = car._supercharger == "" and car.boost_target(car.redline_rpm, 1.0) > 0.05
	_gearbox_kind = car.transmission_kind
	_gear_whine_level = {"sequential":.012,"drag":.007,"dct":.0027,"automatic":.0018}.get(car.transmission_kind,.0015)
	var blower:=EngineAudioProfile.supercharger_character(car)
	supercharger_profile=blower.name
	_super_ratio=float(blower.order); _super_level=float(blower.gain)
	_super_harmonic=float(blower.harmonic); _super_sub=float(blower.sub)
	_super_roughness=float(blower.roughness); _super_air=float(blower.air); _super_bypass=float(blower.bypass)
	_intake_gain = 1.45 if car.hardware.parts.values().has("plenum") else 1.0
	_compressor_scale = .80 if car.hardware.parts.values().has("turbo_race") else (1.12 if car.hardware.parts.values().has("turbo_hybrid") else 1.0)
	hybrid_power = car.hybrid_power_w
	# Aggregate motor acoustic order estimate (9:1 reduction x 6 pole pairs).
	# Road motion, rather than ICE RPM, determines the electric tone's frequency.
	target_motor_hz=clampf(absf(car.speed)/maxf(.1,car.tire_radius)/TAU*54,0,8000)
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
	var can_relieve: bool = _turbo_active or car._supercharger == "centrifugal"
	if not audible or not can_relieve:
		_blowoff_armed = false
		_blowoff_pressure = 0.0
	var charged: bool = audible and can_relieve and car.throttle > 0.58 and car.boost > 0.09
	if charged:
		_blowoff_armed = true
		_blowoff_pressure = maxf(_blowoff_pressure, car.boost)
	if last_shift_serial < 0: last_shift_serial = car.shift_serial
	elif car.shift_serial != last_shift_serial:
		# A loaded upshift vents even when auto/DCT torque cut keeps the gas down.
		if car.last_shift_rpm > 2800.0 and car.last_shift_load > 0.25 and car.exhaust_stage > 0:
			pop = maxf(pop, 0.20 + target_exhaust * 0.35 + target_engine * 0.10)
		shift_tick = float({"manual":.11,"sequential":.20,"dct":.08,"automatic":.12,"drag":.19}.get(car.transmission_kind,.12)) * (.5 + clampf(car.last_shift_load,0,1))
		if audible and can_relieve and car.shift_direction >= 0 and car.last_shift_load > 0.22 and car.last_shift_rpm > 2400.0:
			trigger_blowoff(maxf(car.boost, _blowoff_pressure), "shift", car._supercharger == "centrifugal")
			_blowoff_armed = false
			_blowoff_pressure = 0.0
		last_shift_serial = car.shift_serial
	if audible and can_relieve and _blowoff_armed and car.throttle < 0.30:
		trigger_blowoff(maxf(car.boost, _blowoff_pressure), "lift", car._supercharger == "centrifugal")
		_blowoff_armed = false
		_blowoff_pressure = 0.0
	if car.throttle > 0.65 and car.engine_load > 0.4: _overrun_armed = true
	if _overrun_armed and car.throttle < 0.18:
		if car.rpm > 3400.0 and car.exhaust_stage > 0: pop = maxf(pop,target_exhaust*0.24)
		_overrun_armed = false

func trigger_blowoff(pressure: float, reason: String, centrifugal: bool = false) -> void:
	if _blowoff_cooldown > 0.0 or pressure < 0.09: return
	# Pressure controls intensity and length. Shift vents are short/bright;
	# throttle lifts have a longer, airy tail and light compressor flutter.
	var strength := clampf((pressure - 0.06) / 0.95, 0.0, 1.0)
	blowoff = maxf(blowoff, (0.18 + 0.68 * sqrt(strength)) * (0.55 if centrifugal else 1.0))
	_blowoff_decay = 0.99934 if reason == "shift" else 0.99964
	_blowoff_flutter = (0.22 if reason == "shift" else 0.60) * strength
	_blowoff_cooldown = 0.13 if reason == "shift" else 0.16
	blowoff_events += 1
	last_blowoff_reason = reason

func blowoff_sample(noise: float) -> float:
	_blowoff_cooldown = maxf(0.0, _blowoff_cooldown - 1.0 / RATE)
	if blowoff < 0.00005: return 0.0
	# A bright band-limited pressure hiss layered with a descending chirp.
	# The short, gated pulse adds a flutter only to high-pressure relief.
	_blowoff_noise_low += (noise - _blowoff_noise_low) * 0.075
	_blowoff_noise_high += (noise - _blowoff_noise_high) * 0.34
	var air := _blowoff_noise_high - _blowoff_noise_low
	_blowoff_phase = fposmod(_blowoff_phase + (420.0 + 1300.0 * blowoff) / RATE, 1.0)
	_blowoff_flutter_phase = fposmod(_blowoff_flutter_phase + (24.0 + 19.0 * blowoff) / RATE, 1.0)
	var flutter := 1.0 - _blowoff_flutter * 0.46 * (0.5 + 0.5 * sin(_blowoff_flutter_phase * TAU))
	var chirp := sin(_blowoff_phase * TAU) * (0.055 + _blowoff_flutter * 0.040)
	var sample := (air * 0.37 + chirp) * blowoff * flutter
	blowoff *= _blowoff_decay
	return sample

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
	_launch_phase=fposmod(_launch_phase+23.0/RATE,1.0)
	var combustion_gain:=.12+.88*target_combustion
	if target_launch: combustion_gain=maxf(combustion_gain,EngineAudioProfile.launch_pulse(_launch_phase))
	cut_gain += (combustion_gain-cut_gain)*0.008
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
	tire_phase = fposmod(tire_phase+(1050.0+slip*600.0)/RATE,1.0)
	gear_phase = fposmod(gear_phase+clampf(wheel_hz*5.0,0.0,4500.0)/RATE,1.0)
	var induction := induction_sample()
	var tire := (sin(tire_phase*TAU)*0.015+filtered_noise*0.065)*slip
	var gear_whine := sin(gear_phase*TAU)*(0.010 if _gearbox_kind in ["sequential","drag"] else 0.002)*clutch_value*load_value
	pop_gain += (pop-pop_gain)*0.018
	blowoff_gain += (blowoff-blowoff_gain)*0.008
	shift_tick_gain += (shift_tick-shift_tick_gain)*0.025
	var bov := blowoff_sample(noise) * induction_mix
	var transient := filtered_noise * pop_gain * 0.21 * exhaust_fx_mix + noise * shift_tick_gain * 0.025 * mechanical_mix + bov
	var nitro := intake_filter*0.07*nitro_gain*nitro_mix
	pop *= 0.9990
	shift_tick *= 0.9965
	var sample := tanh(((filtered*amplitude+overrun)*engine_mix+induction*induction_mix+tire*tire_mix+gear_whine*mechanical_mix+transient+nitro+grind_sample())*gain)
	peak_jump = maxf(peak_jump,absf(sample-last_sample))
	last_sample = sample
	samples_generated += 1
	return sample

func grind_sample() -> float:
	if grind_left<=0.0: return 0.0
	var age := .19-grind_left
	var envelope := minf(age/.012,1.0)*pow(grind_left/.19,1.4)
	grind_left=maxf(0.0,grind_left-1.0/RATE)
	grind_phase=fposmod(grind_phase+(720.0+grind_left*2000.0)/RATE,1.0)
	return envelope*(.24*filtered_noise+.10*sin(grind_phase*TAU)+.045*sin(grind_phase*TAU*2.0))*mechanical_mix

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
	tire_phase=fposmod(tire_phase+(1050+slip*600)/RATE,1)
	gear_phase=fposmod(gear_phase+clampf(wheel_hz*5,0,4500)/RATE,1)
	_hybrid_phase=fposmod(_hybrid_phase+target_motor_hz/RATE,1)
	pop_gain+=(pop-pop_gain)*.018; blowoff_gain+=(blowoff-blowoff_gain)*.008; shift_tick_gain+=(shift_tick-shift_tick_gain)*.025
	var induction := induction_sample()*induction_mix
	var tire: float=(sin(tire_phase*TAU)*.014+filtered_noise*.07)*slip*tire_mix if slip*tire_mix>.00001 else 0.0
	var whine:=sin(gear_phase*TAU)*_gear_whine_level*target_clutch*load_value if target_clutch*load_value*mechanical_mix>.00001 else 0.0
	var bov := blowoff_sample(noise) * induction_mix
	var transients := filtered_noise * pop_gain * .21 * exhaust_fx_mix + noise * shift_tick_gain * .025 * mechanical_mix + bov
	var electric:=sin(_hybrid_phase*TAU)*clampf(hybrid_power/162000,0,1)*.009*mechanical_mix if hybrid_power>1 else 0.0
	pop*=.9990; shift_tick*=.9965
	var value:=tanh((induction+tire+whine*mechanical_mix+transients+intake_filter*.07*nitro_gain*nitro_mix+electric+grind_sample())*gain)
	peak_jump=maxf(peak_jump,absf(value-last_sample)); last_sample=value; samples_generated+=1
	return value

func induction_sample() -> float:
	var pressure:=lerpf(maxf(0,boost),maxf(boost,throttle*.22)+_super_bypass,supercharger_blend)
	if pressure<.00001 or induction_mix<=0: return 0.0
	# Turbo spool follows physical pressure, pedal demand, and RPM.
	# Leave the existing model-specific supercharger sound on its own path.
	var spool_target := clampf(boost * (0.40 + 0.60 * throttle) / 1.1, 0.0, 1.0)
	_turbo_spool = lerpf(_turbo_spool, spool_target, 0.0022)
	var turbo_hz: float = (760.0 + rpm * 0.10 + _turbo_spool * (2100.0 + target_turbo * 760.0)) * _compressor_scale
	var hz := clampf(lerpf(turbo_hz, rpm / 60.0 * _super_ratio, supercharger_blend), 100.0, 8000.0)
	turbo_phase = fposmod(turbo_phase + hz / RATE, 1.0)
	_super_sub_phase = fposmod(_super_sub_phase + hz * 0.5 / RATE, 1.0)
	_super_mod_phase = fposmod(_super_mod_phase + rpm / 60.0 * 2.0 / RATE, 1.0)
	var p := turbo_phase * TAU
	var alias_guard := 1.0 - smoothstep(8000.0, 10000.0, hz * 2.0)
	if _turbo_active and _induction_type == "":
		# Rising compressor whistle above a soft, band-limited intake rush.
		_turbo_air_high += (filtered_noise - _turbo_air_high) * 0.36
		_turbo_air_low += (filtered_noise - _turbo_air_low) * 0.060
		var rush := _turbo_air_high - _turbo_air_low
		var whistle := sin(p) + sin(p * 2.0 + 0.32) * 0.25 * alias_guard
		whistle += sin(p * 3.0 + 0.73) * 0.08 * (1.0 - smoothstep(5500.0, 8000.0, hz * 3.0))
		var whistle_level := (0.015 + target_turbo * 0.007) * (0.60 + 0.55 * _turbo_spool)
		var rush_level := (0.028 + target_turbo * 0.008) * (0.45 + 0.55 * load_value)
		return (whistle * whistle_level + rush * rush_level) * pressure * _intake_gain
	var harmonics := lerpf(0.20, _super_harmonic, supercharger_blend) * alias_guard
	var tone := sin(p) + sin(p * 2.0) * harmonics + sin(_super_sub_phase * TAU) * _super_sub * supercharger_blend
	tone *= 1.0 + sin(_super_mod_phase * TAU) * _super_roughness * supercharger_blend
	var level := lerpf(0.010 + target_turbo * 0.006, _super_level, supercharger_blend)
	var air := lerpf(0.025 * _intake_gain, _super_air * _intake_gain, supercharger_blend)
	return (tone * level + intake_filter * air) * pressure

func render(count: int) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(count)
	for i in count: result[i] = next_sample()
	return result
