extends SceneTree

const H := 1.0/240.0
var observations: Dictionary
var reference_spec: Dictionary

func legacy_script(spec: Dictionary) -> GDScript:
	var code := FileAccess.get_file_as_string("res://validation/baseline_drivetrain.gd.txt")
	code = code.replace("class_name Drivetrain\n","")
	code = code.replace("const RATIOS: Array[float] = [3.10, 2.12, 1.53, 1.17, 0.94, 0.78]","const RATIOS: Array[float] = "+JSON.stringify(spec.ratios))
	code = code.replace("const FINAL_DRIVE := 3.85","const FINAL_DRIVE := "+str(spec.final_drive))
	code = code.replace("const TIRE_RADIUS := 0.315","const TIRE_RADIUS := "+str(spec.tire_radius))
	code = code.replace("const IDLE := 950.0","const IDLE := "+str(spec.idle))
	code = code.replace("const REDLINE := 7600.0","const REDLINE := "+str(spec.redline))
	code = code.replace("0.45 + turbo_stage",str(spec.base_boost)+" + turbo_stage")
	var script := GDScript.new()
	script.source_code = code
	var error := script.reload()
	assert(error == OK)
	return script

func replay(spec: Dictionary, use_legacy: bool = false, write_files: bool = false) -> Dictionary:
	var car = legacy_script(spec).new() if use_legacy else Drivetrain.new()
	car.configure_vehicle(spec)
	car.configure(GameCatalog.blank_stages())
	car.reset()
	car.running = true
	car.rpm = 3900.0
	var sample_index := 3 # clocked samples begin at 0.517 s; staging samples are separate.
	var rows: Array = []
	var differences: Array = []
	var crossing := 0.0
	var crossing_mph := 0.0
	var sixty := 0.0
	var eighth := 0.0
	var did_first := false
	var did_second := false
	var total_square := 0.0
	var rpm_square := 0.0
	var count := 0
	var rpm_count := 0
	var max_launch_rpm_error := 0.0
	var launch_square := 0.0
	var launch_count := 0
	var dt := H
	for tick in 5520:
		var t: float = car.elapsed
		var gas := float(spec.get("first_throttle",1.0)) if t < 4.94 else 1.0
		var clutch := 0.0
		if t < 0.908:
			clutch = 1.0
			gas = 0.55
		elif t < 1.4:
			gas = float(spec.get("launch_pedal",1.0))
		if (t >= 4.94 and t < 5.20) or (t >= 10.58 and t < 11.12) or (t >= 14.50 and t < 16.05):
			clutch = 1.0
			gas = 0.0
		if t >= 5.20 and t < 5.38: gas = 0.0
		if not did_first and t+0.00001 >= 5.10:
			car.shift(1)
			did_first = true
		if not did_second and t+0.00001 >= 10.80:
			car.shift(1)
			did_second = true
		var previous: float = car.distance
		car.step(dt,gas,0.0,clutch)
		if sixty == 0.0 and car.distance >= 18.288: sixty = car.elapsed-dt+dt*(18.288-previous)/(car.distance-previous)
		if eighth == 0.0 and car.distance >= 201.168: eighth = car.elapsed-dt+dt*(201.168-previous)/(car.distance-previous)
		if crossing == 0.0 and car.distance >= 402.336:
			crossing = car.elapsed-dt+dt*(402.336-previous)/(car.distance-previous)
			crossing_mph = car.speed*Drivetrain.MPH_PER_MPS
		if tick % 12 == 0: rows.append([car.elapsed,car.gear,car.rpm,car.speed*Drivetrain.MPH_PER_MPS,car.distance,car.wheelspin,car.boost,clutch,gas])
		if sample_index < observations.samples.size():
			var sample: Array = observations.samples[sample_index]
			if car.elapsed+0.00001 >= float(sample[1]):
				var mph_error: float = car.speed*Drivetrain.MPH_PER_MPS-float(sample[4])
				var rpm_error: float = car.rpm-float(sample[3])
				differences.append({"clock_s":sample[1],"gear_observed":sample[2],"gear_simulated":car.gear,"reference_rpm":sample[3],"simulated_rpm":car.rpm,"reference_mph":sample[4],"simulated_mph":car.speed*Drivetrain.MPH_PER_MPS,"mph_error":mph_error,"rpm_error":rpm_error})
				# Use pre-finish samples, not extra acceleration while the bot finishes.
				if float(sample[1]) <= 19.517:
					total_square += mph_error*mph_error
					count += 1
					if int(sample[2]) >= 2 and absf(float(sample[1])-15.517) > 0.01:
						rpm_square += rpm_error*rpm_error
						rpm_count += 1
					if int(sample[2]) == 1:
						max_launch_rpm_error = maxf(max_launch_rpm_error,absf(rpm_error))
						launch_square += rpm_error*rpm_error
						launch_count += 1
				sample_index += 1
	var et := crossing-0.908
	var launch_rmse := sqrt(launch_square/maxi(1,launch_count))
	var score := sqrt(total_square/maxi(1,count))+absf(et-18.415)*2.0+launch_rmse/1200.0+sqrt(rpm_square/maxi(1,rpm_count))/2000.0
	var result := {"et_s":et,"total_s":crossing,"trap_mph":crossing_mph,"sixty_ft_et_s":sixty-0.908,"eighth_et_s":eighth-0.908,"speed_rmse_mph":sqrt(total_square/maxi(1,count)),"loaded_rpm_rmse":sqrt(rpm_square/maxi(1,rpm_count)),"launch_rpm_rmse":launch_rmse,"launch_max_rpm_error":max_launch_rpm_error,"score":score,"differences":differences,"spec":spec}
	if write_files:
		var name := "before_reference" if use_legacy else "after_reference"
		var file := FileAccess.open("res://validation/"+name+".csv",FileAccess.WRITE)
		file.store_csv_line(["clock_s","gear","rpm","mph","distance_m","wheelspin","boost_bar","clutch_command","gas_command"])
		for row in rows:
			var fields := PackedStringArray()
			for value in row: fields.append(str(value))
			file.store_csv_line(fields)
	return result

func _initialize() -> void:
	observations = JSON.parse_string(FileAccess.get_file_as_string("res://validation/reference_observations.json"))
	reference_spec = JSON.parse_string(FileAccess.get_file_as_string("res://validation/reference_profile.json"))
	if OS.get_cmdline_user_args().has("--fine"):
		var best_score := INF
		var best_spec: Dictionary
		var results: Array = []
		for tq in [120.0,121.0,122.0,123.0,124.0]:
			var spec := reference_spec.duplicate(true)
			spec.torque = tq
			var row := replay(spec)
			results.append({"torque":tq,"score":row.score,"et_s":row.et_s,"speed_rmse_mph":row.speed_rmse_mph,"loaded_rpm_rmse":row.loaded_rpm_rmse,"launch_rpm_rmse":row.launch_rpm_rmse})
			if row.score < best_score:
				best_score = row.score
				best_spec = spec.duplicate(true)
		var f := FileAccess.open("res://validation/final_calibration_sweep.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(results,"\t"))
		f = FileAccess.open("res://validation/reference_profile.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(best_spec,"\t"))
		reference_spec = best_spec
	elif OS.get_cmdline_user_args().has("--launch-sweep"):
		var best_score := INF
		var best_spec: Dictionary
		var results: Array = []
		for tq in [110.0,115.0,120.0]:
			for grip in [0.52,0.60,0.68]:
				for inertia in [0.10,0.14,0.18]:
					for opening in [0.2,0.35,0.5,0.65]:
						for first in [0.85,1.0]:
							var spec := reference_spec.duplicate(true)
							spec.torque = tq
							spec.grip = grip
							spec.inertia = inertia
							spec.launch_pedal = opening
							spec.first_throttle = first
							var row := replay(spec)
							results.append({"torque":tq,"grip":grip,"inertia":inertia,"launch_pedal":opening,"first_throttle":first,"score":row.score,"et_s":row.et_s,"speed_rmse_mph":row.speed_rmse_mph,"loaded_rpm_rmse":row.loaded_rpm_rmse,"launch_rpm_rmse":row.launch_rpm_rmse})
							if row.score < best_score:
								best_score = row.score
								best_spec = spec.duplicate(true)
		var f := FileAccess.open("res://validation/launch_calibration_sweep.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(results,"\t"))
		f = FileAccess.open("res://validation/reference_profile.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(best_spec,"\t"))
		reference_spec = best_spec
	elif OS.get_cmdline_user_args().has("--sweep"):
		var best_score := INF
		var best_spec: Dictionary
		var results: Array = []
		for tq in [105.0,115.0,125.0,135.0]:
			for grip in [0.42,0.52,0.62]:
				for inertia in [0.14,0.22]:
					for opening in [0.75,1.0]:
						var spec := reference_spec.duplicate(true)
						spec.torque = tq
						spec.grip = grip
						spec.inertia = inertia
						spec.first_throttle = opening
						var row := replay(spec)
						results.append({"torque":tq,"grip":grip,"inertia":inertia,"first_throttle":opening,"score":row.score,"et_s":row.et_s,"speed_rmse_mph":row.speed_rmse_mph,"loaded_rpm_rmse":row.loaded_rpm_rmse})
						if row.score < best_score:
							best_score = row.score
							best_spec = spec.duplicate(true)
		var f := FileAccess.open("res://validation/calibration_sweep.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(results,"\t"))
		f = FileAccess.open("res://validation/reference_profile.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(best_spec,"\t"))
		reference_spec = best_spec
	var after := replay(reference_spec,false,true)
	var before := replay(reference_spec,true,true)
	var f := FileAccess.open("res://validation/reference_comparison.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"before":before,"after":after,"observed_slip":observations.slip},"\t"))
	print("REFERENCE BEFORE ",before.et_s," s / ",before.trap_mph," mph / speed RMSE ",before.speed_rmse_mph)
	print("REFERENCE AFTER ",after.et_s," s / ",after.trap_mph," mph / speed RMSE ",after.speed_rmse_mph," / RPM RMSE ",after.loaded_rpm_rmse)
	print("FITTED PARAMETERS ",reference_spec)
	quit()

