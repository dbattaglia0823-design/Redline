extends SceneTree

var failures := 0
var rows: Array = []
const H := 1.0/240.0

func _initialize() -> void:
	for tier in [0,3]:
		var c := Drivetrain.new()
		c.configure_vehicle(GameCatalog.spec("kaze"))
		c.configure([tier,tier,tier,tier,tier,tier,tier,tier])
		c.reset()
		var voice := EngineVoice.new()
		var pcm := PackedByteArray()
		var sample_balance := 0.0
		var finished_at := 0.0
		var max_jump := 0.0
		var max_amplitude := 0.0
		var ticks := 0
		for tick in 7200:
			ticks = tick
			var wall := tick*H
			var gas := 0.0
			if wall >= 0.7 and wall < 2.2: gas = clampf(0.10+(3900-c.rpm)/2500.0,0.0,1.0)
			if wall >= 2.2 and finished_at == 0.0:
				c.running = true
				gas = 1.0
				if c.rpm >= c.redline_rpm-550.0 and c.wheel_rpm(c.gear) >= c.redline_rpm-1500.0 and c.shift_left == 0.0: c.request_shift(1)
			var previous := c.distance
			c.step(H,gas,0.0,1.0 if not c.running else 0.0)
			if finished_at == 0.0 and c.distance >= 402.336:
				finished_at = wall+H*(402.336-previous)/(c.distance-previous)
			voice.set_from_vehicle(c,finished_at == 0.0 or wall-finished_at < 0.85)
			sample_balance += 22050.0/240.0
			var count := floori(sample_balance)
			sample_balance -= count
			var samples := voice.render(count)
			for sample in samples:
				if not is_finite(sample): failures += 1
				pcm.append(0)
				pcm.append(0)
				pcm.encode_s16(pcm.size()-2,clampi(roundi(sample*32767.0),-32767,32767))
				max_amplitude = maxf(max_amplitude,absf(sample))
			max_jump = maxf(max_jump,voice.peak_jump)
			if finished_at > 0.0 and wall-finished_at > 1.05: break
		if finished_at <= 0.0 or max_jump > 0.4 or max_amplitude >= 0.98 or c.safety_clamps != 0:
			failures += 1
			push_error("Continuous race-audio demo failed validation")
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 22050
		wav.stereo = false
		wav.data = pcm
		var label := "stock" if tier == 0 else "built"
		if wav.save_to_wav("res://validation/race_audio_kaze_%s.wav" % label) != OK: failures += 1
		rows.append({"build":label,"duration_s":(ticks+1)*H,"quarter_total_s":finished_at-2.2,"actual_shifts":c.shift_serial,"peak_pcm":max_amplitude,"peak_sample_jump":max_jump})
	var f := FileAccess.open("res://validation/audio_demo_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures":failures,"runs":rows,"method":"Continuous real physics from idle through staged launch, assisted paddles, quarter-mile and coast. Same input strategy for stock/all-tier3, no nitrous. Raw original DSP before -7 dB game output gain. Different launch staging from the canonical 3900 RPM benchmark; times are not directly interchangeable."},"\t"))
	print("CONTINUOUS STOCK + BUILT RACE AUDIO: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
