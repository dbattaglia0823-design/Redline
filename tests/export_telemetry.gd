extends SceneTree

func _initialize() -> void:
	var summary := {}
	for id in GameCatalog.CAR_IDS:
		if GameCatalog.spec(id).has("factory_trans"):
			export_factory(id,summary)
			continue
		var c := Drivetrain.new()
		c.configure_vehicle(GameCatalog.spec(id))
		c.configure(GameCatalog.blank_stages())
		c.reset()
		c.running = true
		c.rpm = 3900.0
		var f := FileAccess.open("res://validation/after_%s.csv" % id,FileAccess.WRITE)
		var columns := ["time","gear","rpm","mph","distance_m","engine_nm","clutch_nm","load","clutch","clutch_slip_rpm","wheel_rad_s","slip_ratio","tire_force_n","traction_limit_n","acceleration_mps2","boost_bar","nitrous_s","fuel_cut"]
		var headings := PackedStringArray()
		for col in columns: headings.append(col)
		f.store_csv_line(headings)
		var quarter := 0.0
		for tick in 7200:
			if c.rpm >= c.redline_rpm-550.0 and c.wheel_rpm(c.gear) >= c.redline_rpm-1500.0: c.shift(1)
			var previous := c.distance
			c.step(1.0/240.0,1.0)
			if tick%12 == 0:
				var values := PackedStringArray()
				var state := c.telemetry()
				for col in columns: values.append(str(state[col]))
				f.store_csv_line(values)
			if quarter == 0.0 and c.distance >= 402.336:
				quarter = c.elapsed-1.0/240.0+(1.0/240.0)*(402.336-previous)/(c.distance-previous)
				summary[id] = {"quarter_s":quarter,"trap_mph":c.speed*Drivetrain.MPH_PER_MPS,"peak_hp":c.peak_horsepower(),"safety_clamps":c.safety_clamps}
	var file := FileAccess.open("res://validation/current_vehicle_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	print("CURRENT VEHICLE TELEMETRY ",JSON.stringify(summary))
	quit()

func export_factory(id: String,summary: Dictionary) -> void:
	var bench := VehicleBench.new()
	bench.begin(GameCatalog.spec(id),GameCatalog.blank_stages(),GameCatalog.factory_build(id))
	for i in 64:
		if bench.done: break
		bench.step_budget(960)
	var columns := PackedStringArray(["time","gear","rpm","mph","distance_m","engine_nm","clutch_nm","load","clutch","clutch_slip_rpm","wheel_rad_s","slip_ratio","tire_force_n","traction_limit_n","acceleration_mps2","boost_bar","nitrous_s","fuel_cut"])
	var file := FileAccess.open("res://validation/after_%s.csv" % id,FileAccess.WRITE)
	file.store_csv_line(columns)
	for state in bench.samples:
		var row := PackedStringArray()
		for column in columns: row.append(str(state[column]))
		file.store_csv_line(row)
	summary[id] = {"quarter_s":bench.result.quarter_s,"trap_mph":bench.result.trap_mph,"peak_hp":bench.car.peak_horsepower(),"safety_clamps":bench.car.safety_clamps,"transmission":bench.car.transmission_id,"driver":"VehicleBench factory hardware"}

