extends SceneTree

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation")
	var legacy := GDScript.new()
	legacy.source_code = FileAccess.get_file_as_string("res://validation/baseline_drivetrain.gd.txt").replace("class_name Drivetrain\n","")
	assert(legacy.reload() == OK)
	var result := {}
	for id in ["kaze","nori","aster","vanta"]:
		var car = legacy.new()
		car.configure_vehicle(GameCatalog.spec(id))
		car.configure(GameCatalog.blank_stages())
		car.reset()
		car.running = true
		car.rpm = 3900.0
		var rows: Array = []
		var quarter := 0.0
		for tick in 14400:
			if car.rpm >= 7050.0 and car.wheel_rpm(car.gear) >= 6900.0: car.shift(1)
			car.step(1.0/240.0,1.0)
			if tick % 12 == 0: rows.append([car.elapsed,car.gear,car.rpm,car.speed*2.236936,car.distance,car.wheelspin,car.boost])
			if quarter == 0.0 and car.distance >= 402.336:
				quarter = car.elapsed
				result[id] = {"quarter_seconds":quarter,"trap_mph":car.speed*2.236936,"peak_hp":car.peak_horsepower()}
			if car.elapsed >= 30.0: break
		var file := FileAccess.open("res://validation/before_%s.csv" % id,FileAccess.WRITE)
		file.store_csv_line(["seconds","gear","rpm","mph","distance_m","wheelspin_indicator","boost_bar"])
		for row in rows:
			var fields := PackedStringArray()
			for value in row: fields.append(str(value))
			file.store_csv_line(fields)
	var neutral = legacy.new()
	neutral.gear = 0
	neutral.running = true
	for tick in 480: neutral.step(1.0/240.0,1.0)
	result["neutral_requested"] = {"speed_mps":neutral.speed,"rpm":neutral.rpm}
	var f := FileAccess.open("res://validation/baseline_metrics.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit()
