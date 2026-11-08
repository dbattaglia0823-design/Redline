extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func make_car(id: String) -> Drivetrain:
	var car := Drivetrain.new()
	car.configure_vehicle(GameCatalog.spec(id))
	car.configure_build(GameCatalog.factory_build(id), id, false)
	car.reset()
	car.rpm = 4600.0
	car.throttle = 0.94
	car.engine_load = 0.80
	car.clutch_engagement = 1.0
	car.boost = 0.82
	return car

func _initialize() -> void:
	var turbo := make_car("supra")
	var shift_voice := EngineVoice.new()
	shift_voice.set_from_vehicle(turbo)
	check(shift_voice._turbo_active, "Factory turbo was not detected")
	check(shift_voice._blowoff_armed, "Loaded turbo did not arm relief")
	# An automatic/paddle upshift may retain high pedal demand.
	turbo.last_shift_rpm = 4600
	turbo.last_shift_load = 0.80
	turbo.shift_direction = 1
	turbo.shift_serial += 1
	shift_voice.set_from_vehicle(turbo)
	check(shift_voice.blowoff > 0.25, "Loaded upshift did not vent pressure")
	check(shift_voice.last_blowoff_reason == "shift", "Shift did not select crisp valve transient")
	check(shift_voice.blowoff_events == 1, "One upshift triggered multiple vents")
	# Cut immediately after the upshift must not produce a second BOV.
	turbo.throttle = 0.04
	shift_voice.set_from_vehicle(turbo)
	check(shift_voice.blowoff_events == 1, "Shift plus throttle cut double triggered valve")
	var has_energy := false
	var finite := true
	for i in 7000:
		var sample := shift_voice.next_effect_sample()
		if absf(sample) > .001: has_energy = true
		if not is_finite(sample) or absf(sample) >= 1.0: finite = false
	check(has_energy and finite, "Shift relief DSP was silent, clipped or invalid")
	check(shift_voice._blowoff_cooldown == 0.0, "Blowoff cooldown never expired")
	# Lift generates a distinct, longer sound and remembers pre-lift boost.
	turbo.throttle = 0.93
	turbo.boost = 0.80
	shift_voice.set_from_vehicle(turbo)
	turbo.throttle = 0.03
	turbo.boost = 0.20
	shift_voice.set_from_vehicle(turbo)
	check(shift_voice.blowoff_events == 2 and shift_voice.last_blowoff_reason == "lift", "Throttle lift failed to trigger a fresh relief event")
	check(shift_voice.blowoff > 0.3, "Lift did not use stored boost pressure")
	var low := make_car("supra")
	low.boost = 0.15
	var low_voice := EngineVoice.new()
	low_voice.set_from_vehicle(low)
	low.last_shift_rpm = 4600
	low.last_shift_load = 0.80
	low.shift_direction = 1
	low.shift_serial += 1
	low_voice.set_from_vehicle(low)
	check(shift_voice.blowoff > low_voice.blowoff, "Blowoff intensity ignored boost pressure")
	var stock := make_car("mustang")
	var stock_voice := EngineVoice.new()
	stock_voice.set_from_vehicle(stock)
	stock.shift_serial += 1
	stock.last_shift_rpm = 4600
	stock.last_shift_load = 0.8
	stock.shift_direction = 1
	stock_voice.set_from_vehicle(stock)
	stock.throttle = 0.01
	stock_voice.set_from_vehicle(stock)
	check(stock_voice.blowoff_events == 0 and not stock_voice._turbo_active, "Naturally aspirated engine made turbo sounds")
	var roots := make_car("mustang")
	var build := GameCatalog.factory_build("mustang")
	build.parts.induction = "roots"
	build.owned_parts.append("roots")
	roots.configure_build(build, "mustang", false)
	roots.boost = 0.85
	var roots_voice := EngineVoice.new()
	roots_voice.set_from_vehicle(roots)
	roots.shift_serial += 1
	roots.last_shift_rpm = 4600
	roots.last_shift_load = 0.8
	roots.shift_direction = 1
	roots_voice.set_from_vehicle(roots)
	check(roots_voice.blowoff_events == 0, "Roots supercharger inherited a turbo valve")
	# A source change must discard tails; the induction layer owns the effect.
	var coordinator := EngineAudio.new()
	root.add_child(coordinator)
	coordinator.update_vehicle(turbo)
	turbo.throttle = .90
	coordinator.update_vehicle(turbo)
	turbo.throttle = .03
	coordinator.update_vehicle(turbo)
	check(coordinator.voice.blowoff > 0.0, "Audio coordinator did not play throttle relief")
	coordinator.update_vehicle(stock)
	check(coordinator.voice.blowoff == 0.0 and coordinator.voice._blowoff_cooldown == 0.0, "Vehicle swap inherited BOV tail")
	coordinator.shutdown()
	coordinator.queue_free()
	print("TURBO SPOOL / SHIFT AND LIFT BLOWOFF / AUDIO GATING: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
