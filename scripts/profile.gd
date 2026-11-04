class_name DriverProfile
extends RefCounted

const SAVE_PATH := "user://driver_v1.json"
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
var muted := false
var effects_quality := 2
var reduced_motion := false
var metric_speed := false
var save_error := ""
var vehicle_id := "miata"
var garage: Dictionary = {"miata":{"paint":0,"wheels":0,"stages":[0,0,0,0,0,0,0,0],"hardware":{"transmission":"oem_miata","owned_transmissions":["oem_miata"]}}}
var career_wins: Array = [0,0,0]
var championship_wins: Dictionary = {}
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
	var entry: Dictionary = garage.get(vehicle_id,{}).duplicate(true)
	appearance.paint = paint; appearance.rim = wheels
	entry.merge({"paint":paint,"wheels":wheels,"appearance":appearance.duplicate(true),"owned_appearance":owned_appearance.duplicate(),"stages":GameCatalog.normalize_stages(stages),"hardware":hardware.duplicate(true)},true)
	garage[vehicle_id] = entry

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary: return
	if int(data.get("roster_version",0))<2 and not FileAccess.file_exists(SAVE_PATH+".pre_roster_v2"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_roster_v2"))
	if int(data.get("career_version",0))<1 and not FileAccess.file_exists(SAVE_PATH+".pre_championships"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH+".pre_championships"))
	championship_wins=Championships.sanitize_wins(data.get("championship_wins",{}))
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
			if not id is String or id.length()>64 or not records[id] is Dictionary or event_records.size()>=64: continue
			var row: Dictionary={}
			for key in ["wins","finishes","best_et","last_et","last_rt","trap_mph"]:
				var number: Variant=records[id].get(key)
				if (number is int or number is float) and is_finite(float(number)): row[key]=maxf(0,float(number)) if key!="last_rt" else float(number)
			event_records[id]=row
	data = migrate_roster(data)
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
	garage = {"miata":{"paint":paint,"wheels":wheels,"stages":stages.duplicate(),"hardware":GameCatalog.factory_build("miata")}}
	var saved_garage = data.get("garage", {})
	if saved_garage is Dictionary:
		for id in GameCatalog.CAR_IDS:
			var entry = saved_garage.get(id)
			if entry is Dictionary:
				garage[id] = {"paint":clampi(int(entry.get("paint",0)),0,5),"wheels":clampi(int(entry.get("wheels",0)),0,2),"stages":GameCatalog.normalize_stages(entry.get("stages",[])),"hardware":VehicleParts.normalize(entry.get("hardware",{}),id)}
				garage[id].tuning_presets = normalize_tune_presets(entry.get("tuning_presets",{}))
				garage[id].appearance = VehicleAppearance.normalize(entry.get("appearance",{}),int(garage[id].paint),int(garage[id].wheels))
				garage[id].owned_appearance = normalize_cosmetic_ownership(entry.get("owned_appearance",[]),garage[id].appearance)
	vehicle_id = str(data.get("vehicle_id", "miata"))
	if not garage.has(vehicle_id): vehicle_id = "miata"
	apply_vehicle(vehicle_id)
	var progress = data.get("career_wins", [0,0,0])
	if progress is Array and progress.size() == 3:
		for i in 3: career_wins[i] = clampi(int(progress[i]),0,5)
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
			for part in build.get("owned_parts",[]): refund+=int(VehicleParts.PARTS.get(part,{}).get("cost",0))
			for trans in build.get("owned_transmissions",[]): refund+=int(TransmissionCatalog.spec(str(trans)).cost) if trans!="legacy6" else 0
			data.credits=int(data.get("credits",0))+refund
		entries.erase(old)
	data.garage=entries; data.vehicle_id=RosterData.RETIRED.get(active,active if RosterData.IDS.has(active) else "miata")
	data.retired_garage=archive; data.roster_version=2
	return data

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
	if not pending_wager.is_empty(): return "Finish your race first"
	if not VehicleAppearance.compatible(vehicle_id,key,index): return "Unavailable for this car"
	var part := key+":"+str(index)
	var cost := 0 if owned_appearance.has(part) else int(VehicleAppearance.PRICES[key][index])
	if credits < cost: return "Not enough credits"
	credits -= cost
	if not owned_appearance.has(part): owned_appearance.append(part)
	appearance[key] = index; paint = int(appearance.paint); wheels = int(appearance.rim)
	save()
	return "Installed "+str(VehicleAppearance.OPTIONS[key][index])

func restore_appearance() -> void:
	if not pending_wager.is_empty(): return
	appearance = VehicleAppearance.normalize({}); paint = 0; wheels = 0
	save()

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

func save() -> void:
	snapshot_vehicle()
	var file := FileAccess.open(SAVE_PATH+".tmp", FileAccess.WRITE)
	if file == null:
		save_error = "Could not save progress"
		return
	file.store_string(JSON.stringify({"career_version":1,"championship_wins":championship_wins,"career_claims":career_claims,"career_serial":career_serial,"event_records":event_records,"roster_version":2,"retired_garage":retired_garage,"credits":credits,"xp":xp,"wins":wins,"races":races,"best":best,"paint":paint,"wheels":wheels,"stages":stages,"muted":muted,"effects_quality":effects_quality,"reduced_motion":reduced_motion,"metric_speed":metric_speed,"vehicle_id":vehicle_id,"garage":garage,"career_wins":career_wins,"pending_wager":pending_wager}))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH+".tmp"),ProjectSettings.globalize_path(SAVE_PATH)) != OK:
		save_error = "Could not commit progress"
		return
	save_error = ""

func upgrade_cost(index: int, target: int = -1) -> int:
	if index < 0 or index >= GameCatalog.PART_NAMES.size(): return 0
	var current := int(stages[index])
	if target < 0: target = current + 1
	var cost := 0
	for tier in range(current + 1, mini(target, GameCatalog.max_stage(index)) + 1): cost += GameCatalog.PART_COSTS[index] * tier
	return cost

func upgrade_reason(index: int) -> String:
	if index==1 and float(GameCatalog.spec(vehicle_id).get("factory_super",0))>0 and str(hardware.parts.get("induction","")) not in ["turbo_hybrid","turbo_race"]: return "Fit a turbo assembly before buying turbo packages"
	return ""

func upgrade(index: int, target: int = -1) -> bool:
	if index < 0 or index >= stages.size() or not pending_wager.is_empty(): return false
	if upgrade_reason(index)!="": return false
	var current := int(stages[index])
	if target < 0: target = current + 1
	if target <= current or target > GameCatalog.max_stage(index): return false
	var cost := upgrade_cost(index, target)
	if credits < cost: return false
	credits -= cost
	stages[index] = target
	save()
	return true

func begin_wager(amount: int,contract: Dictionary = {}) -> bool:
	if amount < 0 or amount > credits or not pending_wager.is_empty(): return false
	var bound:=contract.duplicate(true)
	if contract.has("id"):
		bound=Championships.event(str(contract.id))
		if bound.is_empty() or Championships.eligibility(self,bound)!="" or amount>int(bound.max_bet): return false
	credits -= amount; career_serial+=1
	pending_wager = {"amount":amount,"contract":bound,"serial":career_serial}
	save()
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
	if transmission_unlock_stage() < int(spec.stage): return TransmissionCatalog.STAGES[int(spec.stage)]+" build required"
	var cost := 0 if hardware.owned_transmissions.has(id) else int(spec.cost)
	if credits < cost: return "Not enough credits"
	var candidate := hardware.duplicate(true)
	candidate.performance_stages[candidate.transmission] = int(stages[4])
	candidate.transmission = id
	# Different gearbox families cannot retain physically incompatible internals.
	if id != str(hardware.transmission):
		for slot in VehicleParts.TRANSMISSION_SLOTS: candidate.parts.erase(slot)
		for key in ["ratios","shift_rpms","stall","firmness"]: candidate.tune.erase(key)
	credits -= cost
	if not candidate.owned_transmissions.has(id): candidate.owned_transmissions.append(id)
	stages[4] = int(candidate.performance_stages.get(id,0))
	hardware = candidate
	save()
	return "Installed "+str(spec.name)

func install_hardware(id: String) -> String:
	if not pending_wager.is_empty(): return "Finish your race first"
	if not VehicleParts.PARTS.has(id): return "Unknown part"
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
		"stall":
			var id := str(hardware.parts.get("converter",""))
			if not VehicleParts.PARTS.has(id): return false
			var part: Dictionary = VehicleParts.PARTS[id]
			hardware.tune[key] = clampf(number,float(part.stall_min),float(part.stall_max))
		"launch_rpm":
			if not fitted.has("ecu") and not (fitted.has("race_controller") and TransmissionCatalog.spec(str(hardware.transmission)).kind=="drag"): return false
			hardware.tune[key] = clampf(number,2200.0,minf(6000,float(GameCatalog.spec(vehicle_id).get("redline",7600))-400))
		"redline":
			if not fitted.has("ecu"): return false
			var factory_limit := float(GameCatalog.spec(vehicle_id).get("redline",7600.0))
			var headroom:=0.0
			for id in fitted: headroom+=float(VehicleParts.PARTS[id].get("redline",0))
			var mechanical_limit:=factory_limit+headroom
			hardware.tune[key] = clampf(number,minf(6500.0,mechanical_limit-500.0),mechanical_limit)
		"boost":
			if not fitted.has("boost_control"): return false
			var base:=float(GameCatalog.spec(vehicle_id).get("base_boost",.45))
			if VehicleParts.boost_control_reason(hardware,base,int(stages[1]))!="": return false
			hardware.tune[key] = clampf(number,0.0,VehicleParts.boost_control_limit(hardware,base,int(stages[1])))
		"final_drive":
			if not fitted.has("final_kit") or number not in VehicleParts.FINAL_DRIVES: return false
			hardware.tune[key] = number
		"firmness":
			if str(TransmissionCatalog.spec(str(hardware.transmission)).kind) not in ["drag","automatic","dct"]: return false
			hardware.tune[key] = clampf(number,0.5,1.0+int(stages[4])*0.1)
		"nitrous_ramp":
			if not fitted.has("progressive"): return false
			hardware.tune[key] = clampf(number,0.15,1.0)
		"shift_rpms":
			if not fitted.has("race_controller") or not value is Array: return false
			var count: int = TransmissionCatalog.spec(str(hardware.transmission)).ratios.size()-1
			if value.size() != count: return false
			var clean: Array = []
			for rpm in value:
				if not (rpm is int or rpm is float) or not is_finite(float(rpm)): return false
				var factory_limit:=float(GameCatalog.spec(vehicle_id).get("redline",7600))
				var ceiling:=factory_limit
				for id in fitted: ceiling+=float(VehicleParts.PARTS[id].get("redline",0))
				if fitted.has("ecu"): ceiling=clampf(float(hardware.tune.get("redline",factory_limit)),minf(6500,ceiling-500),ceiling)
				clean.append(clampf(float(rpm),maxf(3500,float(GameCatalog.spec(vehicle_id).get("idle",950))+1500),ceiling-50))
			hardware.tune[key] = clean
		"ratios":
			if not fitted.has("gearset") or not value is Array: return false
			var original: Array = TransmissionCatalog.spec(str(hardware.transmission)).ratios
			if value.size() != original.size(): return false
			for i in value.size():
				if not (value[i] is int or value[i] is float) or not is_finite(float(value[i])): return false
				if float(value[i]) < float(original[i])*0.88 or float(value[i]) > float(original[i])*1.12: return false
				if i > 0 and float(value[i-1]) <= float(value[i])*1.025: return false
			hardware.tune[key] = value.duplicate()
		_: return false
	if persist: save()
	return true

func apply_tuning_preset(name: String, keys: Array = []) -> void:
	if not pending_wager.is_empty(): return
	var presets := {
		"street":{"launch_rpm":3000.0,"stall":2800.0,"redline":7400.0,"boost":0.65,"firmness":0.85,"final_drive":3.55,"nitrous_ramp":0.7},
		"drag":{"launch_rpm":4200.0,"stall":4400.0,"redline":8000.0,"boost":1.5,"firmness":1.35,"final_drive":4.10,"nitrous_ramp":0.35},
		"safe":{"launch_rpm":2800.0,"stall":2600.0,"redline":7000.0,"boost":0.45,"firmness":0.75,"final_drive":3.85,"nitrous_ramp":1.0}}
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
	for key in preset.tune:
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
			if key not in ["stall","launch_rpm","redline","boost","final_drive","firmness","nitrous_ramp","ratios","shift_rpms","boost_by_gear"]+TuningSetup.EXTRA.keys(): continue
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
				if int(c.round)==current: championship_wins[series]=mini(5,current+1)
			if int(c.get("completion_bonus",0))>0 and not career_claims.has(id) and (series=="OPEN" or Championships.wins(self,series)==5):
				bonus=int(c.completion_bonus); career_claims.append(id)
		var record: Dictionary=event_records.get(id,{})
		record.finishes=int(record.get("finishes",0))+1
		record.wins=int(record.get("wins",0))+(1 if won else 0)
		record.last_et=et; record.last_rt=reaction; record.trap_mph=trap
		if not red and (not record.has("best_et") or et<float(record.best_et)): record.best_et=et
		event_records[id]=record
	elif won and legacy_career>=0 and legacy_career<3 and legacy_rival==int(career_wins[legacy_career]):
		career_wins[legacy_career]=mini(5,legacy_rival+1)
	var bet_return:=settle_wager(won)
	credits+=maxi(0,base)+maxi(0,bonus); xp+=maxi(0,xp_award); races+=1
	if won: wins+=1
	save()
	return {"base":base+bonus,"bonus":bonus,"xp":xp_award,"bet_return":bet_return,"reward":base+bonus+bet_return}
