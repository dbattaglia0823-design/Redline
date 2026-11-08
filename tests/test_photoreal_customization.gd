extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var integrated := 0
	for id in GameCatalog.CAR_IDS:
		var definition: Dictionary = VehicleAppearance.definition(id)
		if int(definition.get("art_pipeline_version", 0)) < 2:
			continue
		integrated += 1
		check(not definition.get("compatible", []).has("caliper"), id + ": caliper color is still selectable")
		check(not VehicleAppearance.compatible(id, "caliper", 1), id + ": retired caliper purchase is still accepted")
		check(VehicleAppearance.validate(id).is_empty(), id + ": invalid photoreal asset " + str(VehicleAppearance.validate(id)))
		check(definition.has("stock_wheels") and definition.stock_wheels.size() == 2, id + ": missing independent wheel textures")
		for finish in ["gloss", "matte", "metallic"]:
			for paint in 6:
				var path: String = VehicleAppearance.body_variant_path(definition, paint, finish)
				check(ResourceLoader.exists(path), id + ": missing " + path)
				if id != "integra" or paint < 4:
					check(path.begins_with("res://Replacement Vehicle Models/"), id + ": replacement source was not selected")
	check(integrated == 30, "Expected 30 photoreal REDLINE vehicle definitions, got " + str(integrated))
	# Old saves retain their caliper field, but the option cannot be bought or rendered
	# as a separate procedural overlay on a photorealistic car.
	var restored := VehicleAppearance.normalize({"caliper": 3, "design": 4, "paint": 2})
	check(restored.caliper == 3 and restored.design == 4 and restored.paint == 2, "Legacy appearance indices were lost")
	print("PHOTOREAL CUSTOMIZATION: ", "PASS" if failures == 0 else "FAIL", " / ", checks, " checks / ", integrated, " cars")
	quit(0 if failures == 0 else 1)
