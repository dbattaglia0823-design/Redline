extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.profile = DriverProfile.new()
	game.profile.credits = 6000; game.profile.install_appearance("finish",2)
	await create_timer(.2).timeout
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(.04).timeout
	var saved := DriverProfile.new(); saved.load_profile()
	if not game.shutting_down or game.sound.playing or game.sound.stream != null or saved.appearance.finish != 2 or saved.credits != 5550:
		push_error("Graceful close failed to stop audio or preserve appearance purchase")
		quit(1)
	else: print("GRACEFUL WINDOW CLOSE / AUDIO DETACH / SAVE: PASS")
