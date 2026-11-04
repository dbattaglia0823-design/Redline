class_name Championships
extends RefCounted

const CLASSES := ["E","D","C","B","A","S"]
const TITLES := ["Street","Sport","Tuner","Performance","Elite","Hyper / Drag"]
const BONUSES := [2200,3800,6500,11000,18000,32000]
const PAY := [650,1000,1600,2500,4000,6500]
static var data: Dictionary = {}

static func catalog() -> Dictionary:
	if data.is_empty() and FileAccess.file_exists("res://assets/data/championships.json"):
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/championships.json"))
		if parsed is Dictionary: data=parsed
	return data
static func event(id: String) -> Dictionary: return catalog().get(id,{}).duplicate(true)
static func ids(letter: String) -> Array:
	var out: Array=[]
	for id in catalog():
		if str(catalog()[id].series)==letter: out.append(id)
	return out
static func wins(profile: DriverProfile,letter: String) -> int:
	return clampi(int(profile.championship_wins.get(letter,0)),0,5)
static func unlock_reason(profile: DriverProfile,letter: String) -> String:
	var rank:=CLASSES.find(letter)
	if rank<=0: return ""
	var previous: String=CLASSES[rank-1]
	var heritage:=0
	for value in profile.career_wins: heritage+=int(value)
	if wins(profile,previous)>=5 or maxi(heritage,profile.wins)>=rank*3: return ""
	return "Win Class "+previous+" championship or earn %d race wins"%(rank*3)
static func eligibility(profile: DriverProfile,contract: Dictionary) -> String:
	if contract.is_empty(): return "Event unavailable"
	var series: String=contract.series
	if series!="OPEN":
		var reason:=unlock_reason(profile,series)
		if reason!="": return reason
		if int(contract.round)>wins(profile,series): return "Beat the previous rival first"
		var measured:=PerformanceClasses.request(profile.vehicle_id,profile.stages,profile.hardware)
		if measured.is_empty(): return "Measuring current build..."
		if str(measured.get("class","?"))!=series: return "Class %s build required / current %s"%[series,measured.get("class","?")]
	if str(contract.get("vehicle_rule",""))!="" and profile.vehicle_id!=str(contract.vehicle_rule): return GameCatalog.spec(str(contract.vehicle_rule)).name+" required"
	return ""
static func sanitize_wins(value: Variant) -> Dictionary:
	var out: Dictionary={}
	for letter in CLASSES:
		var count: Variant=value.get(letter,0) if value is Dictionary else 0
		out[letter]=clampi(int(count),0,5) if (count is int or count is float) and is_finite(float(count)) else 0
	return out
