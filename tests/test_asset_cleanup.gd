extends SceneTree
## Guard the current roster and native audio bank from accidental bulk pruning.

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/manifest.json"))
	check(raw is Dictionary, "Vehicle art manifest cannot be read")
	if raw is Dictionary:
		check(raw.size() == RosterData.IDS.size(), "Retired or missing art entries in vehicle manifest")
		for id in RosterData.IDS:
			check(raw.has(id), "Current vehicle artwork missing: " + id)
			if not raw.has(id): continue
			var definition: Dictionary = raw[id]
			var path := str(definition.get("body", "")) % [0, "gloss"]
			check(ResourceLoader.exists(path), "Current body texture missing: " + path)
			for layer in definition.get("layers", {}).values():
				var layer_path := str(layer)
				if layer_path.begins_with("res://"):
					check(ResourceLoader.exists(layer_path), "Current vehicle layer missing: " + layer_path)
	var retired := RosterData.RETIRED.keys()
	for id in retired:
		check(not raw.has(id), "Retired vehicle artwork remains in manifest: " + str(id))
		check(RosterData.IDS.has(str(RosterData.RETIRED[id])), "Retired vehicle lost save-migration target")
	var audio_path := "res://assets/audio/engines/bank.json"
	check(FileAccess.file_exists(audio_path), "Engine audio bank manifest removed")
	if FileAccess.file_exists(audio_path):
		var bank_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(audio_path))
		if bank_data is Dictionary:
			var banks: Array = []
			for row_set in bank_data.get("families", {}).values(): banks.append(row_set)
			for vehicle in bank_data.get("vehicles", {}).values(): banks.append(vehicle.get("rows", []))
			for rows in banks:
				for row in rows:
					for wave in row.get("files", {}).values():
						check(FileAccess.file_exists(str(wave)), "Engine WAV missing: " + str(wave))
		else:
			check(false, "Engine bank JSON is malformed")
	print("ASSET CLEANUP / ACTIVE ROSTER AND AUDIO:", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
