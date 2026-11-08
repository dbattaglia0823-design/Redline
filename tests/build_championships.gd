extends SceneTree

# Recalibrate authored builds without replacing event IDs, routes or rival identities.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var output:=Championships.catalog().duplicate(true)
	var report: Array=[]
	for id in output:
		var event: Dictionary=output[id]
		var bench:=VehicleBench.run(GameCatalog.spec(event.model),event.stages,event.hardware)
		if bench.quarter_s==null or bench.safety_clamps>0:
			push_error("Invalid build: "+id)
			quit(1)
			return
		event.potential_s=bench.quarter_s
		event.potential_et=bench.quarter_et_s
		event.preferred_class=GameCatalog.engine_class(event.model,event.hardware)
		var race:=RaceAI.estimate(event,float(event.distance))
		var comparable:=RaceAI.estimate(event,402.336)
		report.append({"id":id,"model":event.model,"class":event.series,"distance":event.distance,
			"potential_s":bench.quarter_s,"race_s":race.time,"quarter_ai_s":comparable.time,
			"trap_mph":race.mph,"clamps":race.clamps})
	DirAccess.make_dir_recursive_absolute("res://.qa")
	var file:=FileAccess.open("res://.qa/championship_balance.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	if "--write" in OS.get_cmdline_user_args():
		file=FileAccess.open("res://assets/data/championships.json",FileAccess.WRITE)
		if file==null:
			push_error("Could not write championship catalog")
			quit(1)
			return
		file.store_string(JSON.stringify(output,"  ")+"\n")
		file.close()
	print("CALIBRATED CAREER BUILDS: ",report.size())
	quit()
