extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var results: Dictionary={}; var csv:="id,name,hp,torque_nm,kg,eighth_s,quarter_s,trap_mph,factory_class,requested_class,reference_target_s,delta_s\n"
	for id in RosterData.IDS:
		var spec:=GameCatalog.spec(id); var bench:=VehicleBench.new()
		bench.begin(spec,GameCatalog.blank_stages(),GameCatalog.factory_build(id))
		while not bench.done: bench.step_budget(10000)
		var d:=bench.result.duplicate(true)
		d["signature"]=PerformanceClasses.signature(id,GameCatalog.blank_stages(),GameCatalog.factory_build(id))
		if d.quarter_s==null: push_error("Unfinished benchmark: "+id); quit(1); return
		d["class"]=GameCatalog.engine_class(id); results[id]=d
		csv+="%s,%s,%s,%s,%s,%.4f,%.4f,%.2f,%s,%s,%s,%.4f\n"%[id,spec.name,spec.factory_hp,spec.peak_torque_nm,spec.mass,float(d.eighth_s),float(d.quarter_s),float(d.trap_mph),d["class"],spec.requested_class,spec.reference_quarter_s,float(d.quarter_s)-float(spec.reference_quarter_s)]
		print(id," ",d.quarter_s," @ ",d.trap_mph," / ",d["class"])
	var f:=FileAccess.open("res://assets/data/factory_benchmarks.json",FileAccess.WRITE); f.store_string(JSON.stringify(results,"  ")); f.close()
	f=FileAccess.open("res://validation/roster_benchmarks.csv",FileAccess.WRITE); f.store_string(csv); f.close()
	quit()
