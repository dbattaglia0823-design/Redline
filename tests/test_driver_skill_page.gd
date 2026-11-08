extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	check(game.tab == "garage", "Game did not open at Garage")
	check(not game.skill_tree.visible, "Skill page starts visible")
	game.action("tab_driver")
	game.action("driver_skills")
	check(game.tab == "skills", "Skill tree did not navigate to separate page")
	check(game.skill_tree.visible, "Skill page is hidden")
	check(not game.native_workshop.supports(), "Native workshop covers Skills page")
	check(game.skill_tree.find_child("CLOSE  X", true, false) == null, "Modal close control remained")
	check(game.skill_tree.get_node_or_null("ColorRect") == null, "Skill tree retained opaque modal backdrop")
	game.skill_tree.refresh()
	check(game.skill_tree.renderer.controls.has("node_12"), "Available points missing from skill page")
	var points: Label = game.skill_tree.renderer.controls.get("node_12") as Label
	check(points != null and points.text.contains("AVAILABLE"), "Available points not visible")
	game.action("tab_dealer")
	check(not game.skill_tree.visible and game.tab == "dealer", "Page navigation left skill page as overlay")
	game.action("driver_skills")
	game.skill_tree._back_to_driver()
	check(game.tab == "driver" and not game.skill_tree.visible, "Back did not return to Driver page")
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	print("DRIVER SKILLS PAGE: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
