extends SceneTree

var failures := 0
var metrics: Dictionary = {}
var pcm := PackedByteArray()
var trace: Array = []

func check(condition: bool,message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func save_wav(path: String, samples: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*2)
	for i in samples.size(): bytes.encode_s16(i*2,clampi(roundi(samples[i]*32767.0),-32767,32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.stereo = false
	wav.data = bytes
	check(wav.save_to_wav(path) == OK,"Could not save original audio validation clip")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation")
	var a := EngineVoice.new()
	var b := EngineVoice.new()
	for voice in [a,b]:
		voice.target_rpm = 3000.0
		voice.target_throttle = 0.8
		voice.target_load = 0.7
		voice.target_clutch = 1.0
	var continuous := a.render(22050)
	var chunked := PackedFloat32Array()
	for count in [123,1000,5000,15927]: chunked.append_array(b.render(count))
	check(continuous == chunked,"DSP output changes with audio chunk size")
	for cylinder_count in [4,6]:
		var voice := EngineVoice.new()
		voice.cylinders = cylinder_count
		voice.target_rpm = 3000.0
		voice.target_throttle = 0.8
		voice.target_load = 0.7
		voice.target_clutch = 1.0
		voice.render(22050)
		var tone := voice.render(44100)
		save_wav("res://validation/audio_%dcyl_3000.wav" % cylinder_count,tone)
		check(absf(voice.rpm-3000) < 0.01,"Audible engine RPM does not settle to physics RPM")
	var car := Drivetrain.new()
	car.configure_vehicle(GameCatalog.spec("kaze"))
	car.configure([0,0,0,0,0,3,0,0]) # Performance exhaust permits the tested shift transient.
	car.reset()
	car.running = true
	car.gear = 0
	var voice := EngineVoice.new()
	var full := PackedFloat32Array()
	var sample_balance := 0.0
	var max_tracking_error := 0.0
	var max_real_tracking_error := 0.0
	var aligned := true
	var observed_blowoff := false
	var observed_shift_pop := false
	for tick in 2880:
		var time := float(tick)/240.0
		var gas := 0.0 if time < 1.0 else (1.0 if time < 3.0 else (0.0 if time < 4.0 else 1.0))
		if tick == 960:
			car.set_road_state(26.0,3)
			car.clutch_engagement = 1.0
		if tick == 1440: car.shift(1)
		var clutch := 1.0 if time > 8.0 and time < 9.0 else 0.0
		var nitrous := time > 7.0 and time < 8.0
		car.step(1.0/240.0,gas,0.0,clutch,nitrous)
		voice.set_from_vehicle(car,time < 10.5)
		aligned = aligned and voice.target_rpm == car.rpm and voice.target_load == car.engine_load and voice.target_clutch == car.clutch_engagement and voice.target_cut == car.fuel_cut and voice.target_boost == car.boost and voice.target_throttle == car.throttle and voice.target_nitrous == car.nitrous_active and voice.target_slip == car.wheelspin
		observed_blowoff = observed_blowoff or voice.blowoff > 0.1
		if tick == 1440: observed_shift_pop = voice.pop > 0.1
		sample_balance += 22050.0/240.0
		var frames := floori(sample_balance)
		sample_balance -= frames
		full.append_array(voice.render(frames))
		max_tracking_error = maxf(max_tracking_error,absf(voice.rpm-car.rpm))
		if tick < 960 or tick > 1008: max_real_tracking_error = maxf(max_real_tracking_error,absf(voice.rpm-car.rpm))
		if tick % 12 == 0: trace.append([time,car.rpm,voice.rpm,car.engine_load,car.clutch_engagement,car.fuel_cut,car.boost,voice.gain])
	check(aligned,"Audio targets are disconnected from physics telemetry")
	check(observed_blowoff,"Gradual throttle release did not trigger boost-release audio")
	check(observed_shift_pop,"Actual paddle shift did not trigger its audio transient")
	check(voice.gain < 0.001,"Pausing/muting does not fade audio to silence")
	var finite := true
	var peak := 0.0
	for sample in full:
		if not is_finite(sample): finite = false
		peak = maxf(peak,absf(sample))
	check(finite and peak < 0.99,"Audio contains invalid or clipped samples")
	check(voice.peak_jump < 0.4,"Audio has a large sample discontinuity")
	check(max_real_tracking_error < 250.0,"Audio pitch lags the evolving physics excessively")
	var profiles := check_profiles()
	save_wav("res://validation/engine_audio_validation.wav",full)
	var file := FileAccess.open("res://validation/audio_tracking.csv",FileAccess.WRITE)
	file.store_csv_line(["seconds","physics_rpm","audio_rpm","load","clutch","fuel_cut","boost","gain"])
	for row in trace:
		var values := PackedStringArray()
		for value in row: values.append(str(value))
		file.store_csv_line(values)
	metrics = {"failures":failures,"chunk_invariant":continuous == chunked,"targets_equal_telemetry":aligned,"max_adjacent_sample_jump":voice.peak_jump,"max_pcm_amplitude":peak,"max_pitch_ramp_tracking_error_rpm":max_tracking_error,"max_real_pitch_tracking_error_rpm":max_real_tracking_error,"queued_buffer_ms":EngineAudio.BUFFER_SECONDS*1000.0,"sample_rate":22050,"samples_generated":full.size(),"note":"Ramp tracking error includes sudden test-fixture road-state changes; steady-state frequency is tested separately. Hardware output latency is not measured."}
	metrics.profiles = profiles
	file = FileAccess.open("res://validation/audio_test_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	print("ORIGINAL ENGINE DSP: ", "PASS" if failures == 0 else "FAIL")
	print(JSON.stringify(metrics))
	quit(0 if failures == 0 else 1)

func check_profiles() -> Array:
	var previous := EngineVoice.band_weights(950)
	for at_rpm in range(950,8000,25):
		var weights := EngineVoice.band_weights(at_rpm)
		check(absf(weights.x+weights.y+weights.z+weights.w-1.0) < 0.00001,"RPM bands do not form a unity crossfade")
		check(weights.x >= 0 and weights.y >= 0 and weights.z >= 0 and weights.w >= 0,"RPM band has negative gain")
		check((weights-previous).length() < 0.07,"RPM layer transition has a gain step")
		previous = weights
	var rows: Array = []
	var signatures: Array[float] = []
	for id in GameCatalog.CAR_IDS:
		var stock_samples := PackedFloat32Array()
		for tier in [0,3]:
			var c := Drivetrain.new()
			c.configure_vehicle(GameCatalog.spec(id))
			c.configure([tier,tier,tier,0,tier,tier,0,tier])
			c.reset()
			c.set_road_state(3500.0/Drivetrain.RPM_PER_RAD/c.ratio_for(3)*c.tire_radius,3,3500.0)
			# Controlled acoustic snapshot: same RPM/load/boost isolates timbre.
			c.throttle = 0.8
			c.engine_load = 0.7
			c.clutch_engagement = 1.0
			c.boost = 0.5
			var voice := EngineVoice.new()
			voice.set_from_vehicle(c)
			voice.render(22050)
			var samples := voice.render(22050)
			save_wav("res://validation/profile_%s_%d.wav" % [id,tier],samples)
			var energy := 0.0
			var difference := 0.0
			var finite := true
			for index in samples.size():
				energy += samples[index]*samples[index]
				finite = finite and is_finite(samples[index]) and absf(samples[index]) < 0.98
				if tier == 3: difference += pow(samples[index]-stock_samples[index],2)
			var rms := sqrt(energy/samples.size())
			var delta := sqrt(difference/samples.size())
			check(finite and voice.peak_jump < 0.4,"Profile has clipping, invalid PCM, or a large discontinuity: "+id)
			if tier == 0:
				stock_samples = samples
				signatures.append(rms)
			else: check(delta > 0.015,"Upgrades have no meaningful acoustic effect: "+id)
			rows.append({"vehicle":id,"tier":tier,"profile":voice.profile_name,"rms":rms,"stock_difference_rms":delta,"peak_sample_jump":voice.peak_jump})
	check(absf(signatures[GameCatalog.CAR_IDS.find("supra")]-signatures[GameCatalog.CAR_IDS.find("gtr")]) > 0.005,"I6 and V6 sound profiles are indistinguishable")
	return rows

