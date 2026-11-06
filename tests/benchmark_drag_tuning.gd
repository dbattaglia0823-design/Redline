extends SceneTree

func _initialize() -> void:
	var rows: Array = []
	var wins := 0
	var losses := 0
	for setup in ["street","built"]:
		var spec := GameCatalog.spec("kaze").duplicate(true)
		var stages := [0,0,0,0,5,0,0,0]
		if setup == "built": spec.grip = 0.9; stages = [3,3,3,3,5,3,3,0]
		for final_drive in [2.73,3.0,3.85]:
			var pair: Array = []
			for id in ["drag3","auto10"]:
				var b := VehicleBench.fixture(id,[],{"final_drive":final_drive})
				var row := VehicleBench.run(spec,stages,b)
				row["final_drive"] = final_drive; row["setup"] = setup
				rows.append(row); pair.append(row)
			if float(pair[0].quarter_s) < float(pair[1].quarter_s): wins += 1
			else: losses += 1
	var file := FileAccess.open("res://validation/drag_tuning_benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":rows,"drag3_wins":wins,"auto10_wins":losses,"conditions":"Kaze-based stock street fixture or all-tier-3 built fixture (effective base grip .9); Pro Race gearbox; identical final drive per pair with factory converter settings."},"\t")); file.close()
	print("PAIRED DRAG TUNING: ",rows.size()," runs; 3D wins ",wins," / 10A wins ",losses)
	if wins == 0 or losses == 0: push_error("Tuning sweep did not demonstrate conditional performance tradeoffs")
	quit(0 if wins > 0 and losses > 0 else 1)
