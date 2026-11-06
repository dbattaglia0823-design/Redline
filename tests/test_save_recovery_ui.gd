extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var seeded:=DriverProfile.new()
	seeded.credits=6000
	seeded.save()
	seeded.credits=7000
	seeded.save()
	var file:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	file.store_string("{ unreadable")
	file.close()
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.size=Vector2i(390,844)
	root.add_child(game)
	for frame in 3: await process_frame
	var dialog: ConfirmationDialog
	for child in game.get_children():
		if child is ConfirmationDialog: dialog=child; break
	var offered:=is_instance_valid(dialog) and dialog.visible and dialog.ok_button_text=="Restore backup"
	if offered: dialog.confirmed.emit()
	await process_frame
	var restored: bool=not game.profile.save_blocked and game.profile.credits==6000
	if not offered or not restored: push_error("Automatic recovery prompt or restore failed")
	game.stop_presentation_audio()
	game.queue_free()
	await process_frame
	print("AUTOMATIC SAVE RECOVERY PROMPT: ","PASS" if offered and restored else "FAIL")
	quit(0 if offered and restored else 1)
