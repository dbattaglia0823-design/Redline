extends SceneTree

var failures := 0
var rows: Array = []
var game: Node2D
const H := 1.0/120.0

func check(condition: bool,message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for event in 3:
		for opponent in 5:
			game.active_contract = GameCatalog.opponent(event,opponent)
			game.active_distance = float(game.active_contract.distance)
			RaceAI.configure(game.rival,game.active_contract)
			game.rival_shift_delay = 0.0
			for tick in 360: game.rival.step(H,game.stage_pedal(game.rival),0.0,1.0)
			check(game.rival.speed == 0.0 and game.rival.rpm > 3000.0 and game.rival.rpm < 4500.0,"Bot staging did not hold the chassis and control engine RPM")
			game.rival.running = true
			var early_motion := false
			var reaction := float(game.active_contract.reaction)
			while game.rival.elapsed < reaction:
				game.step_rival(H)
				early_motion = early_motion or game.rival.distance > 0.0
			check(not early_motion,"Bot moved before its reaction delay")
			game.rival_finish = 0.0
			game.finish_rival_simulation()
			check(game.rival_finish > reaction and game.rival_finish < 90.0,"Bot failed to finish with the shared drivetrain")
			check(game.rival.safety_clamps == 0,"Bot relied on an emergency RPM clamp")
			var measured := RaceAI.estimate(game.active_contract)
			check(measured.time < 30 and measured.clamps == 0,"Quarter-mile AI calibration invalid")
			rows.append({"quarter_s":measured.time,"quarter_mph":measured.mph,"transmission":game.rival.transmission_id,"hp":measured.hp,"event":event,"opponent":opponent,"finish_s":game.rival_finish,"early_motion":early_motion,"safety_clamps":game.rival.safety_clamps})
	var f := FileAccess.open("res://validation/rival_test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures":failures,"runs":rows},"\t"))
	print("ALL 15 BOTS: STAGING + REACTION + SAME FINISH MODEL: ","PASS" if failures == 0 else "FAIL")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit",0 if failures == 0 else 1)
