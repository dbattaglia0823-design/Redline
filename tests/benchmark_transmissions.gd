extends SceneTree

func _initialize() -> void:
	var results: Array = []
	var failures := 0
	for setup in ["street","drag"]:
		var spec := GameCatalog.spec("kaze").duplicate(true)
		var stages := [0,0,0,0,5,0,0,0]
		if setup == "drag":
			spec.torque = 540.0
			spec.mass = 1350.0
			spec.grip = 1.05
			spec.engine = "3.0L turbo I6"
			stages = [3,3,3,3,5,3,3,0]
		for id in TransmissionCatalog.ROWS:
			var build := VehicleBench.fixture(id,["final_kit","radiator"],{"final_drive":3.2})
			for fixed in [0,6500,7000,7400]:
				var bench := VehicleBench.new()
				bench.begin(spec,stages,build,"optimized" if fixed == 0 else "fixed",float(fixed))
				for iteration in 64:
					if bench.done: break
					bench.step_budget(960)
				var row := bench.result.duplicate(true)
				row["setup"] = setup
				if not bench.done or row.get("quarter_s") == null or int(row.get("safety_clamps",-1)) != 0:
					push_error("Invalid benchmark: %s / %s / %d" % [setup,id,fixed]); failures += 1
				results.append(row)
				if fixed == 0:
					var csv := FileAccess.open("res://validation/transmission_%s_%s.csv" % [setup,id],FileAccess.WRITE)
					csv.store_line("seconds,rpm,gear,mph,distance_m,torque_nm,clutch,wheelspin,boost_bar,engine_load")
					for sample in bench.samples:
						csv.store_csv_line(PackedStringArray([str(sample.time),str(sample.rpm),str(sample.gear),str(sample.mph),str(sample.distance_m),str(sample.engine_nm),str(sample.clutch),str(sample.wheelspin),str(sample.boost_bar),str(sample.load)]))
					csv.close()
			print(setup," / ",id," complete")
	var output := FileAccess.open("res://validation/transmission_benchmark.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"runs":results,"passed":failures == 0,"conditions":{"fixed_step_hz":240,"staging_s":2,"staging_target_rpm":3900,"final_drive":3.2,"road":"level; no wind; same tires/engine/stages within each setup","duration_s":40,"shift_loss":"duration weighted by nominal torque interruption; not causal ET loss"}},"\t"))
	output.close()
	print("TRANSMISSION BENCHMARK: ",results.size()," runs; ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


