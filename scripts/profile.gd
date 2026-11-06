class_name DriverProfile
extends RefCounted

const SAVE_PATH := "user://driver_v1.json"
const BACKUP_PATH := SAVE_PATH+".bak"
const SAVE_FORMAT := 1
var credits := 2400
var xp := 0
var wins := 0
var races := 0
var best := 0.0
var paint := 0
var wheels := 0
var appearance: Dictionary = VehicleAppearance.normalize({})
var owned_appearance: Array = VehicleAppearance.owned_defaults(appearance)
var stages: Array = GameCatalog.blank_stages()
var owned_stages: Array = GameCatalog.blank_stages()
var muted := false
var effects_quality := 2
var reduced_motion := false
var metric_speed := false
var save_error := ""
var save_blocked := false
var recovery_available := false
var vehicle_id := "miata"
var garage: Dictionary = {"miata":{"paint":0,"wheels":0,"stages":[0,0,0,0,0,0,0,0],"hardware":{"transmission":"oem_miata","owned_transmissions":["oem_miata"]}}}
var career_wins: Array = [0,0,0]
var championship_wins: Dictionary = {}
var legacy_class_access: Array = []
var career_claims: Array = []
var event_records: Dictionary = {}
var career_serial := 0
var pending_wager: Dictionary = {}
var hardware := GameCatalog.factory_build("miata")
var retired_garage: Dictionary = {}

func level() -> int:
	return 1 + int(sqrt(float(xp) / 150.0))

func next_level_xp() -> int:
	return level() * level() * 150

func snapshot_vehicle() -> void:
	hardware.performance_stages[hardware.transmission] = int(stages[4])
	for index in stages.size(): owned_stages[index]=highest_stage(index)
	hardware.get_or_add("owned_performance_stages",{})[hardware.transmission]=owned_stages[4]
	var entry: Dictionary = garage.get(vehicle_id,{}).duplicate(true)
	appearance.paint = paint; appearance.rim = wheels
	entry.merge({"paint":paint,"wheels":wheels,"appearance":appearance.duplicate(true),"owned_appearance":owned_appearance.duplicate(),"stages":GameCatalog.normalize_stages(stages),"owned_stages":owned_stages.duplicate(),"hardware":hardware.duplicate(true)},true)
	garage[vehicle_id] = entry

static func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func read_save(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>4*1024*1024: return {}
	var parser:=JSON.new()
	if parser.parse(file.get_as_text())!=OK: return {}
	var data: Variant=parser.data
	if not data is Dictionary or not valid_number(data.get("credits")) or float(data.credits)<0: return {}
	if data.has("save_format"):
		if data.save_format!=SAVE_FORMAT or not data.get("integrity") is String: return {}
		var digest: String=data.integrity
		data.erase("integrity")
		if JSON.stringify(data,"",true,true).sha256_text()!=digest: return {}
	elif data.has("integrity") or (not data.get("garage") is Dictionary and not data.get("stages") is Array): return {}
	for key in ["xp","wins","races","best","paint","wheels","career_version","roster_version","traction_version","effects_quality"]:
		if data.has(key) and not valid_number(data[key]): return {}
	for key in ["garage","retired_garage"]:
		if data.has(key) and not data[key] is Dictionary: return {}
	for entry in data.get("garage",{}).values():
		if not entry is Dictionary or not entry.get("stages",[]) is Array or not entry.get("hardware",{}) is Dictionary: return {}
	return data

func lock_save() -> void:
	save_blocked=true
	recovery_available=not read_save(BACKUP_PATH).is_empty()
	save_error="Progress file is unreadable. Saving is paused."

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH) or DirAccess.dir_exists_absolute(SAVE_PATH): lock_save()
		return
	var data := read_save(SAVE_PATH)
	if data.is_empty(): lock_save(); return
	save_blocked=false
	recovery_available=false
	save_error=""
	if int(data.get("roster_version",0))<2 and not FileAccess.file_exists(SAVE_PATH+".pre_roster_v2"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_roster_v2"))
	if int(data.get("career_version",0))<1 and not FileAccess.file_exists(SAVE_PATH+".pre_championships"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_championships"))
	var career_version := int(data.get("career_version",0))
	if career_version==1 and not FileAccess.file_exists(SAVE_PATH+".pre_career_v2"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_career_v2"))
	championship_wins=Championships.sanitize_wins(data.get("championship_wins",{}),5 if career_version<2 else Championships.ROUNDS)
	legacy_class_access=Championships.sanitize_access(data.get("legacy_class_access",[]))
	career_claims=[]
	var claimed: Variant=data.get("career_claims",[])
	if claimed is Array:
		for id in claimed:
			if id is String and id.length()<64 and not career_claims.has(id) and career_claims.size()<64: career_claims.append(id)
	var saved_serial: Variant=data.get("career_serial",0)
	career_serial=maxi(0,int(saved_serial)) if (saved_serial is int or saved_serial is float) and is_finite(float(saved_serial)) else 0
	event_records={}
	var records: Variant=data.get("event_records",{})
	if records is Dictionary:
		for id in records:
			if not id is String or id.length()>64 or not records[id] is Dictionary or event_records.size()>=128: continue
			var row: Dictionary={}
			for key in ["wins","finishes","best_et","last_et","last_rt","trap_mph"]:
				var number: Variant=records[id].get(key)
				if (number is int or number is float) and is_finite(float(number)): row[key]=maxf(0,float(number)) if key!="last_rt" else float(number)
			event_records[id]=row
	data = migrate_roster(data)
	if int(data.get("traction_version",0))<1:
		if not FileAccess.file_exists(SAVE_PATH+".pre_traction"):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_traction"))
		migrate_traction(data)
	migrate_retired_parts(data)
	retired_garage = data.get("retired_garage",{}).duplicate(true)
	credits = maxi(0, int(data.get("credits", 2400)))
	xp = maxi(0, int(data.get("xp", 0)))
	wins = maxi(0, int(data.get("wins", 0)))
	races = maxi(wins, int(data.get("races", 0)))
	best = maxf(0.0, float(data.get("best", 0.0)))
	paint = clampi(int(data.get("paint", 0)), 0, 5)
	wheels = clampi(int(data.get("wheels", 0)), 0, 2)
	stages = GameCatalog.normalize_stages(data.get("stages", []))
	muted = bool(data.get("muted", false))
	effects_quality = clampi(int(data.get("effects_quality",2)),0,2)
	reduced_motion = bool(data.get("reduced_motion",false))
	metric_speed = bool(data.get("metric_speed",false))
	# Migrate original saves without removing their car, paint, money, or upgrades.
	garage = {"miata":{"paint":paint,"wheels":wheels,"stages":stages.duplicate(),"owned_stages":data.get("owned_stages",[]),"hardware":GameCatalog.factory_build("miata")}}
	var saved_garage = data.get("garage", {})
	if saved_garage is Dictionary:
		for id in GameCatalog.CAR_IDS:
			var entry = saved_garage.get(id)
			if entry is Dictionary:
				garage[id] = {"paint":clampi(int(entry.get("paint",0)),0,5),"wheels":clampi(int(entry.get("wheels",0)),0,2),"stages":GameCatalog.normalize_stages(entry.get("stages",[])),"hardware":VehicleParts.normalize(entry.get("hardware",{}),id)}
				garage[id].owned_stages = GameCatalog.normalize_stages(entry.get("owned_stages",[]))
				garage[id].tuning_presets = normalize_tune_presets(entry.get("tuning_presets",{}))
				garage[id].appearance = VehicleAppearance.normalize(entry.get("appearance",{}),int(garage[id].paint),int(garage[id].wheels))
				garage[id].owned_appearance = normalize_cosmetic_ownership(entry.get("owned_appearance",[]),garage[id].appearance)
	vehicle_id = str(data.get("vehicle_id", "miata"))
	if not garage.has(vehicle_id): vehicle_id = "miata"
	apply_vehicle(vehicle_id)
	var progress = data.get("career_wins", [0,0,0])
	if progress is Array and progress.size() == 3:
		for i in 3: career_wins[i] = clampi(int(progress[i]),0,5)
	if career_version<2:
		legacy_class_access=Championships.migrated_access(championship_wins,career_wins,wins)
	# Interrupted runs forfeit the already-charged stake, never refund it on reload.
	pending_wager = {}

static func migrate_roster(raw: Dictionary) -> Dictionary:
	var data:=raw.duplicate(true)
	if int(data.get("roster_version",0))>=2: return data
	var entries: Dictionary=data.get("garage",{}).duplicate(true)
	var archive: Dictionary=data.get("retired_garage",{}).duplicate(true)
	var active:=str(data.get("vehicle_id","kaze"))
	if entries.is_empty(): entries[active]={"paint":data.get("paint",0),"wheels":data.get("wheels",0),"stages":data.get("stages",[]),"hardware":data.get("hardware",{})}
	for old in entries.keys():
		if RosterData.IDS.has(old): continue
		archive[old]=entries[old].duplicate(true)
		var replacement:=str(RosterData.RETIRED.get(old,"miata"))
		if not entries.has(replacement): entries[replacement]=entries[old].duplicate(true)
		else:
			var levels:=GameCatalog.normalize_stages(entries[old].get("stages",[])); var refund:=int(GameCatalog.CARS.get(old,{}).get("price",0))
			for i in levels.size(): refund+=GameCatalog.PART_COSTS[i]*int(levels[i])*(int(levels[i])+1)/2
			var build: Dictionary=entries[old].get("hardware",{})
			for part in build.get("owned_parts",[]):
				refund+=int(VehicleParts.PARTS.get(part,{}).get("cost",VehicleParts.RETIRED_COOLING_COSTS.get(part,0)))
			for trans in build.get("owned_transmissions",[]): refund+=int(TransmissionCatalog.spec(str(trans)).cost) if trans!="legacy6" else 0
			data.credits=int(data.get("credits",0))+refund
		entries.erase(old)
	data.garage=entries; data.vehicle_id=RosterData.RETIRED.get(active,active if RosterData.IDS.has(active) else "miata")
	data.retired_garage=archive; data.roster_version=2
	return data

static func migrate_traction(data: Dictionary) -> void:
	var entries: Variant = data.get("garage",{})
	if not entries is Dictionary: return
	for id in entries:
		var entry: Variant = entries[id]
		if not entry is Dictionary: continue
		var levels := GameCatalog.normalize_stages(entry.get("stages",[]))
		var owned_levels := GameCatalog.normalize_stages(entry.get("owned_stages",[]))
		var build: Variant = entry.get("hardware",{})
		if not build is Dictionary: build = {}
		var owned: Variant = build.get("owned_parts",[])
		if not owned is Array: owned = []
		var parts: Variant = build.get("parts",{})
		if not parts is Dictionary: parts = {}
		for retired in VehicleParts.RETIRED_COOLING_COSTS:
			if owned.has(retired):
				data.credits = int(data.get("credits",2400))+int(VehicleParts.RETIRED_COOLING_COSTS[retired])
		var installed_tier := int(levels[2])+(1 if parts.get("wheels")=="drag_wheels" else 0)
		var owned_tier := maxi(int(owned_levels[2]),int(levels[2]))+(1 if owned.has("drag_wheels") or parts.get("wheels")=="drag_wheels" else 0)
		for tier in range(1,owned_tier+1):
			var tire: String = VehicleParts.TIRE_LADDER[tier]
			if not owned.has(tire): owned.append(tire)
		if installed_tier>0 and not parts.has("tires"): parts.tires = VehicleParts.TIRE_LADDER[installed_tier]
		build.parts=parts; build.owned_parts=owned; entry.hardware=build
		levels[2]=0; owned_levels[2]=0
		entry.stages=levels; entry.owned_stages=owned_levels

static func migrate_retired_parts(data: Dictionary) -> void:
	var entries: Variant = data.get("garage",{})
	if not entries is Dictionary: return
	for entry in entries.values():
		if not entry is Dictionary or not entry.get("hardware") is Dictionary: continue
		var build: Dictionary=entry.hardware
		var owned: Variant=build.get("owned_parts",[])
		var fitted: Variant=build.get("parts",{})
		if owned is Array:
			var fitments: Variant=build.get("fitments",{})
			for id in VehicleParts.RETIRED_CONVERTER_COSTS:
				if not owned.has(id): continue
				var recorded: Variant=fitments.get(id,[]) if fitments is Dictionary else []
				var gearbox_count:=1
				if recorded is Array:
					var unique := {}
					var owned_gearboxes: Variant=build.get("owned_transmissions",[])
					for gearbox in recorded:
						if owned_gearboxes is Array and owned_gearboxes.has(gearbox): unique[gearbox]=true
					gearbox_count=maxi(gearbox_count,unique.size())
				data.credits=int(data.get("credits",2400))+gearbox_count*int(VehicleParts.RETIRED_CONVERTER_COSTS[id])
		var had_controller: bool=fitted is Dictionary and fitted.get("nitrous")=="progressive"
		if had_controller or (owned is Array and owned.has("progressive")):
			var levels:=GameCatalog.normalize_stages(entry.get("stages",[]))
			var purchased:=GameCatalog.normalize_stages(entry.get("owned_stages",[]))
			if had_controller: levels[7]=maxi(1,int(levels[7]))
			purchased[7]=maxi(1,int(purchased[7]))
			entry.stages=levels
			entry.owned_stages=purchased

func apply_vehicle(id: String) -> void:
	vehicle_id = id
	var entry: Dictionary = garage[id]
	paint = int(entry.paint)
	wheels = int(entry.wheels)
	appearance = VehicleAppearance.normalize(entry.get("appearance",{}),paint,wheels)
	paint = int(appearance.paint); wheels = int(appearance.rim)
	owned_appearance = normalize_cosmetic_ownership(entry.get("owned_appearance",[]),appearance)
	stages = GameCatalog.normalize_stages(entry.stages)
	hardware = VehicleParts.normalize(entry.get("hardware",{}),id,int(stages[4]))
	owned_stages = GameCatalog.normalize_stages(entry.get("owned_stages",[]))
	for index in stages.size(): owned_stages[index]=maxi(owned_stages[index],stages[index])
	hardware.owned_performance_stages[hardware.transmission]=maxi(int(hardware.get("owned_performance_stages",{}).get(hardware.transmission,0)),owned_stages[4])

func select_vehicle(id: String) -> bool:
	if not garage.has(id) or not pending_wager.is_empty(): return false
	snapshot_vehicle()
	apply_vehicle(id)
	save()
	return true

static func normalize_cosmetic_ownership(raw: Variant, look: Dictionary) -> Array:
	var clean := VehicleAppearance.owned_defaults(look)
	if raw is Array:
		for item in raw:
			if not item is String: continue
			var parts := str(item).split(":")
			if parts.size() == 2 and VehicleAppearance.OPTIONS.has(parts[0]) and parts[1].is_valid_int():
				var index := int(parts[1])
				if index >= 0 and index < VehicleAppearance.OPTIONS[parts[0]].size() and not clean.has(item): clean.append(item)
	return clean

func install_appearance(key: String,index: int) -> String:
	if save_blocked: return save_error
	if not pending_wager.is_empty(): return "Finish your race first"
	if not VehicleAppearance.compatible(vehicle_id,key,index): return "Unavailable for this car"
	var part := key+":"+str(index)
	var owned:=owned_appearance.has(part)
	var cost := 0 if owned else int(VehicleAppearance.PRICES[key][index])
	if credits < cost: return "Not enough credits"
	var previous:=appearance_for(vehicle_id)
	var entry: Dictionary=garage.get(vehicle_id,{}).duplicate(true)
	credits -= cost
	if not owned: owned_appearance.append(part)
	appearance[key] = index; paint = int(appearance.paint); wheels = int(appearance.rim)
	save()
	if save_error!="":
		credits+=cost
		if not owned: owned_appearance.erase(part)
		appearance=previous
		paint=int(previous.paint); wheels=int(previous.rim)
		garage[vehicle_id]=entry
		return save_error
	return "Installed "+str(VehicleAppearance.OPTIONS[key][index])

func restore_appearance() -> void:
	if save_blocked or not pending_wager.is_empty(): return
	var previous:=appearance_for(vehicle_id)
	var entry: Dictionary=garage.get(vehicle_id,{}).duplicate(true)
	appearance = VehicleAppearance.normalize({}); paint = 0; wheels = 0
	save()
	if save_error!="":
		appearance=previous
		paint=int(previous.paint); wheels=int(previous.rim)
		garage[vehicle_id]=entry

func appearance_for(id: String) -> Dictionary:
	if id == vehicle_id:
		var look := appearance.duplicate(true); look.paint = paint; look.rim = wheels
		return look
	var entry: Dictionary = garage.get(id,{})
	return VehicleAppearance.normalize(entry.get("appearance",{}),int(entry.get("paint",0)),int(entry.get("wheels",0)))

func buy_vehicle(id: String, equip: bool = true) -> bool:
	if not GameCatalog.CAR_IDS.has(id) or garage.has(id) or not pending_wager.is_empty(): return false
	if level() < int(GameCatalog.spec(id).get("unlock_level",1)): return false
	var cost := int(GameCatalog.spec(id).price)
	if credits < cost: return false
	snapshot_vehicle()
	credits -= cost
	garage[id] = {"paint":0,"wheels":0,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build(id)}
	if equip: apply_vehicle(id)
	save()
	return true

func publish_copy(source: String,destination: String) -> bool:
	var temporary:=destination+".copy"
	if DirAccess.copy_absolute(source,temporary)!=OK: return false
	if read_save(temporary).is_empty(): return false
	return DirAccess.rename_absolute(temporary,destination)==OK

func recover_backup() -> bool:
	if not save_blocked or read_save(BACKUP_PATH).is_empty(): return false
	if FileAccess.file_exists(SAVE_PATH):
		var archive:=SAVE_PATH+".corrupt."+str(Time.get_ticks_usec())
		if DirAccess.copy_absolute(SAVE_PATH,archive)!=OK: return false
	if not publish_copy(BACKUP_PATH,SAVE_PATH): return false
	load_profile()
	return not save_blocked

func save() -> void:
	if save_blocked: return
	var primary_exists:=FileAccess.file_exists(SAVE_PATH)
	if primary_exists and read_save(SAVE_PATH).is_empty():
		lock_save()
		return
	if not primary_exists and (FileAccess.file_exists(BACKUP_PATH) or DirAccess.dir_exists_absolute(SAVE_PATH)):
		lock_save()
		return
	snapshot_vehicle()
	var temporary:=SAVE_PATH+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		save_error="Could not save progress"
		return
	var payload: Dictionary={"career_version":3,"legacy_class_access":legacy_class_access,"championship_wins":championship_wins,"career_claims":career_claims,"career_serial":career_serial,"event_records":event_records,"roster_version":2,"traction_version":1,"retired_garage":retired_garage,"credits":credits,"xp":xp,"wins":wins,"races":races,"best":best,"paint":paint,"wheels":wheels,"stages":stages,"owned_stages":owned_stages,"muted":muted,"effects_quality":effects_quality,"reduced_motion":reduced_motion,"metric_speed":metric_speed,"vehicle_id":vehicle_id,"garage":garage,"career_wins":career_wins,"pending_wager":pending_wager}
	payload.save_format=SAVE_FORMAT
	# Canonicalize JSON numbers before hashing so the reader hashes the same values.
	payload=JSON.parse_string(JSON.stringify(payload,"",true,true))
	payload.integrity=JSON.stringify(payload,"",true,true).sha256_text()
	file.store_string(JSON.stringify(payload,"",true,true))
	file.flush()
	file.close()
	if read_save(temporary).is_empty() or not publish_copy(SAVE_PATH if primary_exists else temporary,BACKUP_PATH):
		save_error="Could not validate progress or update its backup"
		return
	if DirAccess.rename_absolute(temporary,SAVE_PATH)!=OK:
		save_error="Could not commit progress"
		return
	save_error=""

func highest_stage(index: int) -> int:
	if index==4: return maxi(int(stages[4]),int(hardware.get("owned_performance_stages",{}).get(hardware.transmission,0)))
	return maxi(int(stages[index]),int(owned_stages[index]))

func upgrade_cost(index: int, target: int = -1) -> int:
	if index < 0 or index >= GameCatalog.PART_NAMES.size(): return 0
	var current := int(stages[index])
	if target < 0: target = current + 1
	var cost := 0
	for tier in range(highest_stage(index) + 1, mini(target, GameCatalog.max_stage(index)) + 1): cost += GameCatalog.PART_COSTS[index] * tier
	return cost

func upgrade_reason(_index: int) -> String:

	return ""

# The quote owns copies of the build. Only commit_upgrade_quote writes the profile.
func upgrade_quote(index: int, tier: int, slot: String="", id: String="") -> Dictionary:
	var quote := {"build":hardware.duplicate(true),"stages":stages.duplicate(),"owned":owned_stages.duplicate(),"items":[],"cost":0,"reason":"","equipped":false}
	if slot=="":
		if index<0 or index>=stages.size() or tier<0 or tier>GameCatalog.max_stage(index):
			quote.reason="Unknown package"
			return quote
		if tier==int(stages[index]):
			quote.equipped=true
			return quote
		quote_stage(quote,index,tier,false)
	else:
		if not VehicleParts.SLOTS.has(slot) or (id!="" and VehicleParts.PARTS.get(id,{}).get("slot")!=slot):
			quote.reason="Unknown component"
			return quote
		if str(hardware.parts.get(slot,""))==id:
			quote.equipped=true
			return quote
		if id in ["charge_pressure","charge_response"] and not has_forced_induction():
			quote.reason="Forced induction required"
			return quote
		if id=="":
			quote.build.parts.erase(slot)
			quote.items.append({"name":VehicleParts.factory_name(slot),"cost":0,"support":false,"replaces":VehicleParts.PARTS[hardware.parts[slot]].name})
		else:
			quote_part(quote,id,false,[])
	# A downgrade can invalidate an installed dependent. Keep its ownership
	# and include the removal in the quote. Repeat for chained dependencies.
	var selected: String=id
	var removed:=true
	while removed:
		removed=false
		for fitted_slot in quote.build.parts.keys():
			var installed: String=quote.build.parts[fitted_slot]
			var reason:=VehicleParts.compatible(installed,quote.build,int(quote.stages[4]))
			if reason=="" and installed=="boost_control":
				reason=VehicleParts.boost_control_reason(quote.build,float(GameCatalog.spec(vehicle_id).get("base_boost",.45)),int(quote.stages[1]))
			if reason=="": continue
			if installed==selected:
				quote.reason=reason
				break
			quote.build.parts.erase(fitted_slot)
			quote.items.append({"name":VehicleParts.PARTS[installed].name,"cost":0,"support":true,"replaces":"","removal":true,"reason":reason})
			removed=true
	if not pending_wager.is_empty(): quote.reason="Finish your race first"
	return quote

func quote_stage(quote: Dictionary,index: int,tier: int,support: bool) -> void:
	if tier==int(quote.stages[index]) or (support and tier<int(quote.stages[index])): return
	var cost:=upgrade_cost(index,tier)
	quote.stages[index]=tier
	quote.owned[index]=maxi(highest_stage(index),tier)
	if index==4:
		quote.build.performance_stages[quote.build.transmission]=tier
		quote.build.get_or_add("owned_performance_stages",{})[quote.build.transmission]=quote.owned[index]
	quote.cost+=cost
	var name:=GameCatalog.stage_name(index,tier)
	if support and index==4: name+=" gearbox upgrade"
	quote.items.append({"name":name,"cost":cost,"support":support,"replaces":""})

func quote_part(quote: Dictionary,id: String,support: bool,chain: Array) -> void:
	if chain.has(id):
		quote.reason="Circular component requirement"
		return
	var build: Dictionary=quote.build
	var part: Dictionary=VehicleParts.PARTS[id]
	if str(build.parts.get(part.slot,""))==id: return
	var path:=chain+[id]
	var required:=VehicleParts.missing_requirement(id,build)
	if required!="": quote_part(quote,required,true,path)
	if id=="boost_control" and VehicleParts.boost_control_reason(build,float(GameCatalog.spec(vehicle_id).get("base_boost",.45)),int(quote.stages[1]))!="":
		quote_part(quote,"turbo_hybrid",true,path)
	if VehicleParts.TRANSMISSION_SLOTS.has(part.slot): quote_stage(quote,4,int(part.stage),true)
	var previous:=str(build.parts.get(part.slot,""))
	var cost:=0 if VehicleParts.is_owned(build,id) else int(part.cost)
	build.parts[part.slot]=id
	if not build.owned_parts.has(id): build.owned_parts.append(id)
	if not build.fitments.has(id): build.fitments[id]=[]
	if not build.fitments[id].has(build.transmission): build.fitments[id].append(build.transmission)
	quote.cost+=cost
	quote.items.append({"name":part.name,"cost":cost,"support":support,"replaces":str(VehicleParts.PARTS.get(previous,{}).get("name",""))})

func commit_upgrade_quote(index: int,tier: int,slot: String,id: String,expected: String) -> String:
	var quote:=upgrade_quote(index,tier,slot,id)
	if quote.reason!="": return quote.reason
	if quote.equipped or quote.items.is_empty(): return "Already installed"
	if JSON.stringify(quote)!=expected: return "Build changed. Review the new quote."
	if credits<int(quote.cost): return "Not enough credits"
	var before_build:=hardware
	var before_stages:=stages
	var before_owned:=owned_stages
	var before_garage:=garage.duplicate(true)
	hardware=quote.build
	stages=quote.stages
	owned_stages=quote.owned
	credits-=int(quote.cost)
	save()
	if save_error!="":
		hardware=before_build
		stages=before_stages
		owned_stages=before_owned
		garage=before_garage
		credits+=int(quote.cost)
		return save_error
	for item in quote.items:
		if not item.support: return "Installed "+str(item.name)
	return "Build updated"

func upgrade(index: int, target: int = -1) -> bool:
	if index < 0 or index >= stages.size() or not pending_wager.is_empty(): return false
	if target < 0: target = int(stages[index])+1
	var quote:=upgrade_quote(index,target)
	return commit_upgrade_quote(index,target,"","",JSON.stringify(quote)).begins_with("Installed ")

func begin_wager(amount: int,contract: Dictionary = {}) -> bool:
	if save_blocked or amount < 0 or amount > credits or not pending_wager.is_empty(): return false
	var bound:=contract.duplicate(true)
	if contract.has("id"):
		bound=Championships.event(str(contract.id))
		if bound.is_empty() or Championships.eligibility(self,bound)!="" or amount>int(bound.max_bet): return false
	credits -= amount; career_serial+=1
	pending_wager = {"amount":amount,"contract":bound,"serial":career_serial}
	save()
	if save_error!="":
		credits+=amount
		career_serial-=1
		pending_wager.clear()
		return false
	return true

func settle_wager(won: bool) -> int:
	if pending_wager.is_empty(): return 0
	var returned := int(pending_wager.amount) * 2 if won else 0
	credits += returned
	pending_wager.clear()
	return returned

func forfeit_wager() -> void:
	if pending_wager.is_empty(): return
	settle_wager(false)
	save()

func install_transmission(id: String) -> String:
	if not pending_wager.is_empty(): return "Finish your race first"
	if not TransmissionCatalog.compatible(id,vehicle_id): return "Not compatible with this drivetrain"
	var spec := TransmissionCatalog.spec(id)
	if not hardware.owned_transmissions.has(id) and transmission_unlock_stage() < int(spec.stage): return TransmissionCatalog.STAGES[int(spec.stage)]+" build required"
	var cost := 0 if hardware.owned_transmissions.has(id) else int(spec.cost)
	if credits < cost: return "Not enough credits"
	var candidate := hardware.duplicate(true)
	candidate.performance_stages[candidate.transmission] = int(stages[4])
	candidate.get_or_add("owned_performance_stages",{})[candidate.transmission]=highest_stage(4)
	VehicleParts.switch_transmission(candidate,id)
	var before_build := hardware
	var before_stages := stages.duplicate()
	var before_owned := owned_stages.duplicate()
	var before_garage := garage.duplicate(true)
	credits -= cost
	stages[4] = int(candidate.performance_stages.get(id,0))
	owned_stages[4] = maxi(int(stages[4]),int(candidate.owned_performance_stages.get(id,0)))
	hardware = candidate
	save()
	if save_error!="":
		hardware=before_build
		stages=before_stages
		owned_stages=before_owned
		garage=before_garage
		credits+=cost
		return save_error
	return "Installed "+str(spec.name)

func has_forced_induction() -> bool:
	var spec := GameCatalog.spec(vehicle_id)
	return hardware.parts.has("induction") or int(stages[1])>0 or float(spec.get("base_boost",0))>0 or float(spec.get("factory_super",0))>0

func install_hardware(id: String) -> String:
	if not pending_wager.is_empty(): return "Finish your race first"
	if not VehicleParts.PARTS.has(id): return "Unknown part"
	if id in ["charge_pressure","charge_response"] and not has_forced_induction(): return "Forced induction required"
	var candidate := hardware.duplicate(true)
	var part: Dictionary = VehicleParts.PARTS[id]
	candidate.parts[part.slot] = id
	if id=="boost_control":
		var reason:=VehicleParts.boost_control_reason(candidate,float(GameCatalog.spec(vehicle_id).get("base_boost",.45)),int(stages[1]))
		if reason!="": return reason
	for installed in candidate.parts.values():
		var reason := VehicleParts.compatible(str(installed),candidate,int(stages[4]))
		if reason != "": return reason
	var cost := 0 if VehicleParts.is_owned(hardware,id) else int(part.cost)
	if credits < cost: return "Not enough credits"
	credits -= cost
	if not candidate.owned_parts.has(id): candidate.owned_parts.append(id)
	if not candidate.fitments.has(id): candidate.fitments[id] = []
	if not candidate.fitments[id].has(candidate.transmission): candidate.fitments[id].append(candidate.transmission)
	hardware = candidate
	save()
	return "Installed "+str(part.name)

func transmission_unlock_stage() -> int:
	var highest := int(stages[4])
	for rank in hardware.get("owned_performance_stages",{}).values(): highest = maxi(highest,int(rank))
	for rank in hardware.performance_stages.values(): highest = maxi(highest,int(rank))
	return highest

func remove_hardware(slot: String) -> String:
	if not pending_wager.is_empty(): return "Finish your race first"
	var candidate := hardware.duplicate(true)
	candidate.parts.erase(slot)
	for installed in candidate.parts.values():
		var reason := VehicleParts.compatible(str(installed),candidate,int(stages[4]))
		if reason != "": return reason
	hardware = candidate
	save()
	return "Factory hardware installed"

func tune_hardware(key: String, value: Variant, persist: bool = true) -> bool:
	if not pending_wager.is_empty(): return false
	if key not in ["ratios","shift_rpms","boost_by_gear"] and not (value is float or value is int): return false
	var fitted: Array = hardware.parts.values()
	var number := float(value) if value is float or value is int else 0.0
	if not is_finite(number): return false
	if TuningSetup.EXTRA.has(key) or key=="boost_by_gear":
		var clean: Variant=TuningSetup.clean(key,value,hardware,int(stages[4]),vehicle_id,int(stages[1]))
		if clean==null: return false
		hardware.tune[key]=clean
		if persist: save()
		return true
	match key:
		"launch_rpm":
			if not hardware.parts.has("ecu") and TransmissionCatalog.spec(str(hardware.transmission)).kind!="drag": return false
			hardware.tune[key] = clampf(number,2200.0,minf(6000,float(GameCatalog.spec(vehicle_id).get("redline",7600))-400))
		"redline":
			if not VehicleParts.can_tune_rpm(hardware): return false
			var factory_limit := float(GameCatalog.spec(vehicle_id).get("redline",7600.0))
			var headroom:=0.0
			for id in fitted: headroom+=float(VehicleParts.PARTS[id].get("redline",0))
			var mechanical_limit:=factory_limit+headroom
			hardware.tune[key] = clampf(number,minf(6500.0,mechanical_limit-500.0),mechanical_limit)
		"boost":
			var spec := GameCatalog.spec(vehicle_id)
			if float(spec.get("factory_super",0))>0 and not hardware.parts.has("induction"): return false
			var base:=float(spec.get("base_boost",.45))
			if VehicleParts.boost_control_reason(hardware,base,int(stages[1]))!="": return false
			hardware.tune[key] = clampf(number,0.0,VehicleParts.boost_control_limit(hardware,base,int(stages[1])))
		"final_drive":
			if number<2.0 or number>5.5: return false
			hardware.tune[key] = number
		"firmness":
			if str(TransmissionCatalog.spec(str(hardware.transmission)).kind) not in ["drag","automatic","dct"]: return false
			hardware.tune[key] = clampf(number,0.5,1.0+int(stages[4])*0.1)
		"shift_rpms":
			if not value is Array: return false
			var count: int = TransmissionCatalog.default_ratios(hardware.transmission,hardware.tune).size()-1
			if value.size() != count: return false
			var clean: Array = []
			for rpm in value:
				if not (rpm is int or rpm is float) or not is_finite(float(rpm)): return false
				var factory_limit:=float(GameCatalog.spec(vehicle_id).get("redline",7600))
				var ceiling:=factory_limit
				for id in fitted: ceiling+=float(VehicleParts.PARTS[id].get("redline",0))
				if VehicleParts.can_tune_rpm(hardware): ceiling=clampf(float(hardware.tune.get("redline",factory_limit)),minf(6500,ceiling-500),ceiling)
				clean.append(clampf(float(rpm),maxf(3500,float(GameCatalog.spec(vehicle_id).get("idle",950))+1500),ceiling-50))
			hardware.tune[key] = clean
		"gear_count":
			var limits := TransmissionCatalog.count_limits(str(hardware.transmission))
			if number!=roundf(number) or number<limits.x or number>limits.y: return false
			var current: Array = hardware.tune.get("ratios",TransmissionCatalog.default_ratios(str(hardware.transmission),hardware.tune))
			if not TransmissionCatalog.valid_ratios(str(hardware.transmission),current,TransmissionCatalog.gear_count(hardware)): current=TransmissionCatalog.spec(str(hardware.transmission)).ratios
			hardware.tune.ratios = TransmissionCatalog.resized_ratios(current,int(number))
			hardware.tune.gear_count = int(number)
			for dependent in ["launch_gear"]:
				if hardware.tune.has(dependent): hardware.tune[dependent]=mini(int(hardware.tune[dependent]),int(number))
			for per_gear in ["shift_rpms","boost_by_gear"]:
				if not hardware.tune.has(per_gear): continue
				var count := int(number)-(1 if per_gear=="shift_rpms" else 0)
				var resized: Array = hardware.tune[per_gear].slice(0,count)
				while resized.size()<count: resized.append(resized[-1] if not resized.is_empty() else (float(GameCatalog.spec(vehicle_id).get("redline",7600))-500 if per_gear=="shift_rpms" else 1.0))
				hardware.tune[per_gear]=resized
		"ratios":
			if not TransmissionCatalog.valid_ratios(value,TransmissionCatalog.default_ratios(hardware.transmission,hardware.tune)): return false
			hardware.tune[key] = value.duplicate()
		_: return false
	if persist: save()
	return true

func apply_tuning_preset(name: String, keys: Array = []) -> void:
	if not pending_wager.is_empty(): return
	var presets := {
		"street":{"launch_rpm":3000.0,"redline":7400.0,"boost":0.65,"firmness":0.85,"final_drive":3.55},
		"drag":{"launch_rpm":4200.0,"redline":8000.0,"boost":1.5,"firmness":1.35,"final_drive":4.10},
		"safe":{"launch_rpm":2800.0,"redline":7000.0,"boost":0.45,"firmness":0.75,"final_drive":3.85}}
	if not presets.has(name): return
	for key in presets[name]:
		if keys.is_empty() or keys.has(key): tune_hardware(key,presets[name][key],false)
	if keys.is_empty() or keys.has("shift"): hardware.tune.erase("shift_rpms")
	save()

func tuning_presets() -> Dictionary:
	var entry: Dictionary=garage.get(vehicle_id,{})
	var saved: Variant=entry.get("tuning_presets",{})
	return saved.duplicate(true) if saved is Dictionary else {}

func save_tune_slot(slot: String,label: String) -> bool:
	if not pending_wager.is_empty() or slot not in ["street","eighth","quarter","custom"]: return false
	var presets:=tuning_presets()
	presets[slot]={"name":label.strip_edges().left(28) if label.strip_edges()!="" else slot.capitalize(),"transmission":hardware.transmission,"tune":hardware.tune.duplicate(true)}
	garage[vehicle_id]["tuning_presets"]=presets
	save(); return true

func tune_slot_reason(slot: String) -> String:
	var preset: Dictionary=tuning_presets().get(slot,{})
	if preset.is_empty(): return "Empty slot"
	if str(preset.get("transmission",""))!=str(hardware.transmission): return "Requires saved gearbox configuration"
	if not preset.get("tune") is Dictionary: return "Invalid preset"
	var copy:=DriverProfile.new(); copy.vehicle_id=vehicle_id; copy.stages=stages.duplicate(); copy.hardware=hardware.duplicate(true)
	copy.hardware.tune.clear()
	if preset.tune.has("gear_count") and not copy.tune_hardware("gear_count",preset.tune.gear_count,false): return "Invalid gear count"
	for key in preset.tune:
		if key=="gear_count": continue
		if not copy.tune_hardware(str(key),preset.tune[key],false): return "Missing compatible hardware for "+str(key).replace("_"," ")
	return ""

func load_tune_slot(slot: String) -> bool:
	if not pending_wager.is_empty() or tune_slot_reason(slot)!="": return false
	hardware.tune=tuning_presets()[slot].tune.duplicate(true)
	save(); return true

func rename_tune_slot(slot: String,label: String) -> bool:
	if not pending_wager.is_empty(): return false
	var presets:=tuning_presets()
	if not presets.has(slot) or label.strip_edges()=="": return false
	presets[slot].name=label.strip_edges().left(28); garage[vehicle_id]["tuning_presets"]=presets; save(); return true

static func normalize_tune_presets(value: Variant) -> Dictionary:
	var out: Dictionary={}
	if not value is Dictionary: return out
	for slot in ["street","eighth","quarter","custom"]:
		var row: Variant=value.get(slot)
		if not row is Dictionary or not row.get("tune") is Dictionary: continue
		var tune: Dictionary={}
		for key in row.tune:
			if key not in ["gear_count","launch_rpm","redline","boost","final_drive","firmness","ratios","shift_rpms","boost_by_gear"]+TuningSetup.EXTRA.keys(): continue
			var v: Variant=row.tune[key]
			if (v is int or v is float) and is_finite(float(v)): tune[key]=v
			elif v is Array and v.size()<=10:
				var ok:=true
				for x in v:
					if not (x is int or x is float) or not is_finite(float(x)): ok=false
				if ok: tune[key]=v.duplicate()
		out[slot]={"name":str(row.get("name",slot)).left(28),"transmission":str(row.get("transmission","")),"tune":tune}
	return out

func award_race(contract: Dictionary,won: bool,red: bool,et: float,reaction: float,trap: float,legacy_career: int,legacy_rival: int) -> Dictionary:
	if pending_wager.is_empty() or not is_finite(et) or et<=0: return {}
	var c: Dictionary=pending_wager.get("contract",{}).duplicate(true)
	if c.is_empty(): c=contract.duplicate(true)
	won=won and not red
	var base:=0 if red else (int(c.get("purse",0)) if won else int(float(c.get("purse",0))*.4))
	var xp_award:=0
	if not red:
		if c.has("id"): xp_award=int(float(c.xp)*(1.0 if won else .45))
		else: xp_award=180+legacy_career*80 if won else 100+legacy_career*40
	var bonus:=0
	if c.has("id"):
		var id: String=c.id; var series: String=c.series
		if won:
			if series!="OPEN":
				var current:=Championships.wins(self,series)
				if int(c.round)==current: championship_wins[series]=mini(Championships.ROUNDS,current+1)
			if int(c.get("completion_bonus",0))>0 and not career_claims.has(id) and (series=="OPEN" or (bool(c.get("boss",false)) and Championships.wins(self,series)==Championships.ROUNDS)):
				bonus=int(c.completion_bonus); career_claims.append(id)
		var record: Dictionary=event_records.get(id,{})
		record.finishes=int(record.get("finishes",0))+1
		record.wins=int(record.get("wins",0))+(1 if won else 0)
		if not red: record.last_et=et
		record.last_rt=reaction; record.trap_mph=trap
		if not red and (not record.has("best_et") or et<float(record.best_et)): record.best_et=et
		event_records[id]=record
	elif won and legacy_career>=0 and legacy_career<3 and legacy_rival==int(career_wins[legacy_career]):
		career_wins[legacy_career]=mini(5,legacy_rival+1)
	var bet_return:=settle_wager(won)
	credits+=maxi(0,base)+maxi(0,bonus); xp+=maxi(0,xp_award); races+=1
	if won: wins+=1
	save()
	return {"base":base+bonus,"bonus":bonus,"xp":xp_award,"bet_return":bet_return,"reward":base+bonus+bet_return}
