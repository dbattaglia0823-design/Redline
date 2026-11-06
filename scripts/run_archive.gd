class_name RunArchive
extends RefCounted

# Keep the archive comfortably below the profile's 4 MiB read limit. Full
# recent traces are bounded globally; compact PB summaries survive eviction.
const PER_VEHICLE := 3
const GLOBAL_RUNS := 192
const SAMPLE_LIMIT := 180
const SAMPLE_KEYS := ["time","rpm","speed","gear","throttle","clutch","wheelspin","boost","distance","acceleration","clutch_slip"]
const METRIC_KEYS := ["distance","reaction_s","sixty_ft_s","sixty_ft_mph","eighth_s","eighth_mph","quarter_s","trap_mph","zero_60_s","total_s","launch_rpm","peak_acceleration","peak_wheelspin","peak_clutch_slip","traction_s","clutch_slip_s","limiter_s","low_rpm_s"]
static func key(vehicle: String,length: float) -> String: return vehicle+":"+str(201.168 if length<300 else 402.336)
static func metric(run: Dictionary) -> String: return "eighth_s" if float(run.get("metrics",{}).get("distance",402.336))<300 else "quarter_s"
static func finite(value: Variant) -> bool: return (value is int or value is float) and is_finite(float(value))
static func clean_run(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not raw.get("metrics") is Dictionary: return {}
	var m: Dictionary={}
	for name in METRIC_KEYS:
		var value: Variant=raw.metrics.get(name)
		m[name]=float(value) if finite(value) and absf(float(value))<1000000 else null
	if m.distance==null or m.total_s==null or float(m.total_s)<=0: return {}
	m.red_light=raw.metrics.get("red_light",false)==true
	if absf(float(m.distance)-201.168)>.01 and absf(float(m.distance)-402.336)>.01: return {}
	var primary: Variant=m.eighth_s if float(m.distance)<300 else m.quarter_s
	if not finite(primary) or float(primary)<=0: return {}
	for name in ["sixty_ft_s","eighth_s","quarter_s","zero_60_s"]:
		if m[name]!=null and float(m[name])<0: return {}
	var run: Dictionary={"id":clampi(int(raw.get("id",0)),0,1000000000) if finite(raw.get("id",0)) else 0,"metrics":m,"samples":[],"shifts":[],"setup":{}}
	var source: Variant=raw.get("samples",[])
	if source is Array:
		var previous := -1.0
		for i in mini(SAMPLE_LIMIT,source.size()):
			var index:=roundi(float(i)*(source.size()-1)/maxi(1,mini(SAMPLE_LIMIT,source.size())-1))
			if not source[index] is Dictionary: continue
			var row: Dictionary={}
			for name in SAMPLE_KEYS:
				var value: Variant=source[index].get(name,0)
				if finite(value) and absf(float(value))<1000000:
					var step:=1.0 if name in ["rpm","gear","clutch_slip"] else (.001 if name in ["time","throttle","clutch","wheelspin","boost"] else .01)
					row[name]=snappedf(float(value),step)
			if row.size()!=SAMPLE_KEYS.size() or row.time<previous: continue
			previous=row.time; run.samples.append(row)
	var shifts: Variant=raw.get("shifts",[])
	if shifts is Array:
		for row in shifts.slice(0,64):
			if not row is Dictionary: continue
			var clean: Dictionary={}
			for name in ["time","rpm","gear","duration"]:
				if finite(row.get(name)) and absf(float(row[name]))<1000000: clean[name]=float(row[name])
			if clean.size()==4: run.shifts.append(clean)
	var setup: Variant=raw.get("setup",{})
	if setup is Dictionary:
		var trans: Variant=setup.get("transmission","")
		if trans is String and trans.length()<64: run.setup.transmission=trans
		for name in ["final_drive","launch_rpm","redline","tire_pressure","diff_lock","tc_slip","throttle_gamma","clutch_rate","boost","launch_damping"]:
			if finite(setup.get(name)): run.setup[name]=float(setup[name])
		var ratios: Variant=setup.get("ratios",[])
		if ratios is Array and ratios.size()<=10 and ratios.all(func(n): return finite(n) and float(n)>0 and float(n)<=6): run.setup.ratios=ratios.duplicate()
	return run

static func pack(archive: Dictionary) -> String:
	return "gz:"+Marshalls.raw_to_base64(JSON.stringify(archive).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))

static func normalize(raw: Variant) -> Dictionary:
	var archive: Dictionary={"serial":0,"vehicles":{}}
	if raw is String:
		if raw.length()>3*1024*1024: return archive
		if raw.begins_with("gz:"):
			var bytes:=Marshalls.base64_to_raw(raw.substr(3)).decompress_dynamic(16*1024*1024,FileAccess.COMPRESSION_GZIP)
			if bytes.is_empty(): return archive
			raw=JSON.parse_string(bytes.get_string_from_utf8())
		else: raw=JSON.parse_string(raw)
	if not raw is Dictionary or not raw.get("vehicles") is Dictionary: return archive
	for vehicle in GameCatalog.CAR_IDS:
		for length in [201.168,402.336]:
			var id:=key(vehicle,length)
			var record: Variant=raw.vehicles.get(id)
			if not record is Dictionary: continue
			var runs: Array=[]
			var source: Variant=record.get("runs",[])
			if source is Array:
				for entry in source.slice(0,PER_VEHICLE):
					var run:=clean_run(entry)
					if run.is_empty() or absf(float(run.metrics.distance)-length)>.01: continue
					runs.append(run); archive.serial=maxi(int(archive.serial),int(run.id))
			var best:=clean_run(record.get("best",{}))
			if not best.is_empty():
				if best.metrics.red_light or best.metrics[metric(best)]==null or absf(float(best.metrics.distance)-length)>.01: best={}
				else: best.samples=[]; best.shifts=[]; archive.serial=maxi(int(archive.serial),int(best.id))
			archive.vehicles[id]={"runs":runs,"best":best}
	trim(archive)
	return archive

static func trim(archive: Dictionary) -> void:
	var all: Array=[]
	for id in archive.vehicles:
		for run in archive.vehicles[id].runs: all.append({"key":id,"id":int(run.id)})
	all.sort_custom(func(a,b): return a.id>b.id)
	for item in all.slice(GLOBAL_RUNS):
		archive.vehicles[item.key].runs=archive.vehicles[item.key].runs.filter(func(run): return int(run.id)!=item.id)

static func add(archive: Dictionary,vehicle: String,raw: Dictionary) -> Dictionary:
	var run:=clean_run(raw)
	if run.is_empty(): return {}
	archive.serial=int(archive.get("serial",0))+1; run.id=archive.serial
	var id:=key(vehicle,float(run.metrics.distance))
	if not archive.vehicles.has(id): archive.vehicles[id]={"runs":[],"best":{}}
	var record: Dictionary=archive.vehicles[id]
	record.runs.push_front(run); record.runs.resize(mini(PER_VEHICLE,record.runs.size()))
	var marker:=metric(run)
	if not run.metrics.red_light and run.metrics[marker]!=null and (record.best.is_empty() or float(run.metrics[marker])<float(record.best.metrics[marker])-.000001):
		record.best=run.duplicate(true); record.best.samples=[]; record.best.shifts=[]
	trim(archive)
	return run

static func history(archive: Dictionary,vehicle: String,length: float) -> Dictionary:
	return archive.get("vehicles",{}).get(key(vehicle,length),{"runs":[],"best":{}})
static func elapsed(run: Dictionary,row: Dictionary) -> float:
	var reaction: Variant=run.metrics.get("reaction_s")
	return maxf(0,float(row.time)-maxf(0,float(reaction) if finite(reaction) else 0))
static func delta(a: Dictionary,b: Dictionary,name: String) -> Variant:
	var x: Variant=a.get("metrics",{}).get(name); var y: Variant=b.get("metrics",{}).get(name)
	return float(x)-float(y) if finite(x) and finite(y) else null
