class_name PerformanceClasses
extends RefCounted
const ORDER := ["E","D","C","B","A","S"]
const BENCH_VERSION := "competent-launch-v4-traction-balance"
static var cache: Dictionary = {}
static var jobs: Array = []
static var factories: Dictionary = {}
static func signature(id: String,stages: Array,hardware: Dictionary) -> String:
	var s:=GameCatalog.spec(id); var physical: Array=[]
	for field in ["torque","torque_curve","mass","drive","grip","drag_area","redline","idle","base_boost","factory_super","inertia","throttle_response","tire_radius","final_drive","gear_ratios","hybrid_kw","hybrid_kwh"]: physical.append(s.get(field))
	var inputs := [BENCH_VERSION,id,physical,stages,hardware.get("transmission"),hardware.get("parts",{}),hardware.get("tune",{})]
	var engine := str(hardware.get("engine_id",""))
	if GameCatalog.ENGINE_CLASSES.has(engine):
		var donor := GameCatalog.spec(engine)
		inputs.append(engine)
		for field in GameCatalog.ENGINE_FIELDS: inputs.append(donor.get(field))
	return JSON.stringify(inputs).sha256_text()
static func classify(seconds: float) -> String:
	if seconds<10.5: return "S"
	if seconds<12: return "A"
	if seconds<13: return "B"
	if seconds<14: return "C"
	if seconds<15: return "D"
	return "E"
static func factory(id: String) -> Dictionary:
	if factories.is_empty() and FileAccess.file_exists("res://assets/data/factory_benchmarks.json"):
		factories=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/factory_benchmarks.json"))
	var result: Dictionary=factories.get(id,{})
	if result.get("signature","")!=signature(id,GameCatalog.blank_stages(),GameCatalog.factory_build(id)): return {}
	return result
static func factory_class(id: String) -> String:
	return GameCatalog.engine_class(id)
static func request(id: String,stages: Array,hardware: Dictionary) -> Dictionary:
	var key:=signature(id,stages,hardware)
	if cache.has(key): return cache[key]
	if key==signature(id,GameCatalog.blank_stages(),GameCatalog.factory_build(id)):
		var stock:=factory(id)
		if not stock.is_empty(): cache[key]=stock; return stock
	for job in jobs:
		if job.key==key: return {}
	if jobs.size()>=64: return {}
	jobs.append({"key":key,"id":id,"stages":stages.duplicate(),"hardware":hardware.duplicate(true),"bench":null})
	return {}
static func advance() -> bool:
	if jobs.is_empty(): return false
	var job: Dictionary=jobs[0]
	if job.bench==null:
		job.bench=VehicleBench.new(); job.bench.begin(GameCatalog.spec(job.id),job.stages,job.hardware)
	job.bench.step_budget(360)
	if not job.bench.done: return false
	var d: Dictionary=job.bench.result.duplicate(true)
	d["class"]=GameCatalog.engine_class(job.id,job.hardware)
	if cache.size()>128: cache.erase(cache.keys()[0])
	cache[job.key]=d; jobs.pop_front(); return true
static func label(profile: DriverProfile) -> String:
	return "PRICE %s / ENGINE %s"%[GameCatalog.price_class(profile.vehicle_id),GameCatalog.engine_class(profile.vehicle_id,profile.hardware)]

