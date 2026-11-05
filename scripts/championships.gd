class_name Championships
extends RefCounted

const CLASSES := ["E","D","C","B","A","S"]
const TITLES := ["Dockside Rookies","Apex Syndicate","Boost District","Midnight Works","Velocity Club","Redline Crown"]
const ROUNDS := 10
const TOTAL_RACES := 60
const TROPHY := Color("efc47f")
const BONUSES := [3600,5800,9500,15000,24000,42000]
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
	out.sort_custom(func(a,b): return int(catalog()[a].round)<int(catalog()[b].round))
	return out
static func wins(profile: DriverProfile,letter: String) -> int:
	return clampi(int(profile.championship_wins.get(letter,0)),0,ROUNDS)

static func completed(profile: DriverProfile) -> int:
	var count := 0
	for letter in CLASSES: count += wins(profile,letter)
	return count

static func trophies(profile: DriverProfile) -> int:
	var count := 0
	for letter in CLASSES:
		if wins(profile,letter)==ROUNDS: count += 1
	return count

static func unlock_reason(profile: DriverProfile,letter: String) -> String:
	var rank:=CLASSES.find(letter)
	if rank<=0: return ""
	var previous: String=CLASSES[rank-1]
	if wins(profile,previous)>=ROUNDS or profile.legacy_class_access.has(letter): return ""
	return "Defeat the Class "+previous+" boss"

static func migrated_access(old_wins: Dictionary,street_wins: Array,total_wins: int) -> Array:
	var access: Array = []
	var heritage := 0
	for value in street_wins: heritage += int(value)
	for rank in range(1,CLASSES.size()):
		if int(old_wins.get(CLASSES[rank-1],0))>=5 or maxi(heritage,total_wins)>=rank*3 or int(old_wins.get(CLASSES[rank],0))>0:
			access.append(CLASSES[rank])
	return access

static func sanitize_access(value: Variant) -> Array:
	if not value is Array: return []
	return CLASSES.filter(func(letter): return letter!="E" and value.has(letter))
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
static func sanitize_wins(value: Variant,limit: int = ROUNDS) -> Dictionary:
	var out: Dictionary={}
	for letter in CLASSES:
		var count: Variant=value.get(letter,0) if value is Dictionary else 0
		out[letter]=clampi(int(count),0,limit) if (count is int or count is float) and is_finite(float(count)) else 0
	return out
