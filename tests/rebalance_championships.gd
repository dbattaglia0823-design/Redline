extends SceneTree

# Offline authoring only: choose real builds and driver inputs, never modify
# racing forces or add hidden opponent acceleration multipliers.
const FRACTIONS := [0.0,.16,.29,.40,.51,.62,.72,.81,.90,1.0]
const BUILD_LABELS := ["Factory","Stage 1 street build","Stage 1 performance build","Stage 2 track build","Stage 2 competition build","Stage 3 race build","Stage 3 pro build","Stage 3 prepared build","Stage 3 nitrous race build","Stage 3 maximum-effort build"]
var report: Array=[]
var old: Dictionary={}

static func driver(model: String,stages: Array,build: Dictionary) -> Dictionary:
	return {"model":model,"stages":stages,"hardware":build,"driver_model":2,"reaction":.18,"pedal":1.0,"skill":3,"shift_error":0,"traction_skill":.95,"driver_seed":0,"launch_style":"balanced","nitrous":int(stages[7])>0,"nitrous_gear":2}

static func fixture(model: String,level: int) -> Dictionary:
	var stages: Array=[
		[0,0,0,0,0,0,0,0],[1,0,0,0,1,0,0,0],
		[1,1,0,0,1,1,0,0],[2,1,0,1,2,1,0,0],
		[2,2,0,1,3,2,0,0],[3,2,0,2,4,2,0,0],
		[3,3,0,2,5,3,0,0],[3,3,0,3,5,3,0,0],[3,3,0,3,5,3,0,2],[3,3,0,3,5,3,3,3]][level]
	var parts: Array=[[],["street_tires"],
		["uhp_tires","street_susp","clutch_twin"],
		["street_radial","coilovers","clutch_twin","ecu"],
		["competition_radial","drag_susp","clutch_race","forged","fuel_street","ecu"],
		["drag_slicks","pro_drag_susp","clutch_race","forged","fuel_injectors","intake_velocity","ecu_track"],
		["pro_drag_radial","pro_drag_susp","clutch_carbon","billet","fuel_ethanol","ecu_race","turbo_hybrid","gear_strength"],
		["pro_drag_slicks","active_drag_susp","clutch_carbon","billet","fuel_ethanol","ecu_race","turbo_hybrid","intake_race","headers","charge_airflow","gear_strength","gear_pro"],
		["pro_drag_slicks","active_drag_susp","clutch_carbon","billet","fuel_ethanol","ecu_race","turbo_hybrid","gear_strength","gear_pro"],
		["pro_drag_slicks","active_drag_susp","clutch_carbon","billet","fuel_ethanol","ecu_race","turbo_race","intake_race","charge_pressure","charge_airflow","charge_cooling","gear_strength","gear_pro","gear_response"]][level]
	var build:=GameCatalog.factory_build(model)
	for part in parts:
		build.owned_parts.append(part); build.parts[VehicleParts.PARTS[part].slot]=part
	if level>=4: build.tune={"tire_pressure":VehicleParts.PARTS[build.parts.tires].pressure_peak,"launch_damping":1.15}
	return driver(model,stages,build)

func measured(contract: Dictionary,length: float=402.336) -> float:
	var run:=RaceAI.estimate(contract,length)
	if run.clamps!=0 or run.time>=90: push_error("Invalid authoring candidate: "+str(contract.model)); return INF
	return float(run.time)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output:=Championships.catalog().duplicate(true)
	old=output.duplicate(true)
	var baseline_path:="res://validation/championship_economy/before_contracts.json"
	if FileAccess.file_exists(baseline_path): old=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	for letter in Championships.CLASSES:
		var models: Array=RosterData.IDS.filter(func(id): return GameCatalog.engine_class(id)==letter)
		var stock: Dictionary={}; var pool: Array=[]
		var slowest: String=models[0]
		var fastest:=INF
		for model in models:
			for level in 10:
				var c:=fixture(model,level)
				var time:=measured(c)
				var motor:=time
				if int(c.stages[7])>0:
					var no_spray:=c.duplicate(true); no_spray.rule="motor_only"; motor=measured(no_spray)
				pool.append({"contract":c,"time":time,"motor":motor,"level":level,"key":JSON.stringify([model,c.stages,c.hardware])})
				if level==0:
					stock[model]=time; fastest=minf(fastest,time)
					if time>float(stock.get(slowest,0)): slowest=model
		var opening:=float(stock[slowest])+.40
		var boss:=minf(fastest*.75,float(stock[slowest])*.68)
		var used: Dictionary={}
		var prior:=INF
		for round_index in 10:
			var id: String="class_%s_%d"%[letter,round_index]
			var event: Dictionary=output[id]
			var target:=lerpf(opening,boss,float(FRACTIONS[round_index]))
			var motor_only: bool=event.get("rule","")=="motor_only"
			var chosen: Dictionary={}; var best:=-INF
			for entry in pool:
				var pace: float=entry.motor if motor_only else entry.time
				if used.has(entry.key) or pace>target: continue
				if round_index==0 and (entry.level!=0 or entry.contract.model!=slowest): continue
				if pace>best: chosen=entry; best=pace
			if chosen.is_empty(): push_error("No real build for target "+id); quit(1); return
			used[chosen.key]=true
			var selected: Dictionary=chosen.contract
			for key in selected: event[key]=selected[key]
			event.reaction=.18+maxf(0.0,target-best)
			# Slight reaction variation, rather than scaling physical acceleration.
			if event.reaction>.95: push_error("Candidate spacing too wide: "+id); quit(1); return
			event.reaction_spread=.012
			event.purse=0; event.completion_bonus=0
			event.max_bet=Championships.bet_cap(letter,round_index)
			event.race_class=letter; event.preferred_class=letter
			event.build_label=BUILD_LABELS[int(chosen.level)]
			event.identity="Stock-class opener" if round_index==0 else ("Fully prepared championship boss" if round_index==9 else "Progressive race build")
			var actual:=measured(event)
			var distance_time:=measured(event,float(event.distance))
			if actual>=prior-.04: push_error("Difficulty did not increase: "+id); quit(1); return
			if round_index==0 and (actual<float(stock[slowest])+.20 or actual>float(stock[slowest])+.65): push_error("Opening margin invalid: "+id); quit(1); return
			prior=actual
			event.potential_s=best; event.potential_et=best-.18
			event.calibrated_quarter_s=actual
			report.append({"id":id,"model":event.model,"class":letter,"stock_times":stock if round_index==0 else {},"recipe":chosen.level,"target_s":target,"quarter_ai_s":actual,"race_s":distance_time,"reaction_s":event.reaction,"bet_cap":event.max_bet,"old_quarter_ai_s":measured(old[id]),"stages":event.stages,"hardware":event.hardware})
			print(id," ",event.model," / level ",chosen.level," / ",actual," / cap ",event.max_bet)
	# An easy stock opener must not inadvertently soften the next rounds in a
	# broad class. Tighten driver reaction where the new curve overlaps an old
	# rival; never manufacture faster physical acceleration.
	for row in report:
		var event: Dictionary=output[row.id]
		if int(event.round)==0 or row.quarter_ai_s<float(row.old_quarter_ai_s)-.10: continue
		event.reaction=maxf(.08,float(event.reaction)-(float(row.quarter_ai_s)-float(row.old_quarter_ai_s)+.12))
		row.quarter_ai_s=measured(event)
		row.race_s=measured(event,float(event.distance))
		row.reaction_s=event.reaction
		row.target_s=minf(float(row.target_s),float(row.old_quarter_ai_s)-.12)
		event.calibrated_quarter_s=row.quarter_ai_s
		if row.quarter_ai_s>=float(row.old_quarter_ai_s)-.08: push_error("Follow-up still too easy: "+str(row.id)); quit(1); return
	for row in report:
		var event: Dictionary=output[row.id]
		row.old_race_s=measured(old[row.id],float(event.distance))
		if int(event.round)>0 and float(row.race_s)>=float(row.old_race_s)-.03:
			push_error("Follow-up too easy over actual race distance: "+str(row.id)); quit(1); return
	var opens: Array=[]
	for id in output:
		var event: Dictionary=output[id]
		if event.series!="OPEN": continue
		event.purse=0; event.completion_bonus=0
		opens.append({"id":id,"time":measured(event)})
	opens.sort_custom(func(a,b): return a.time>b.time)
	for index in opens.size(): output[opens[index].id].max_bet=[2500,12000,35000,90000,180000][index]
	DirAccess.make_dir_recursive_absolute("res://validation/championship_economy")
	var file:=FileAccess.open("res://validation/championship_economy/difficulty.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixed_hz":240,"player_reaction_s":.18,"opening_margin_s":.40,"round_fractions":FRACTIONS,"races":report,"open_rivals":opens},"\t")); file.close()
	if "--write" in OS.get_cmdline_user_args():
		file=FileAccess.open("res://assets/data/championships.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(output,"  ")+"\n"); file.close()
	print("CHAMPIONSHIP DIFFICULTY / STOCK OPENERS / BETTING-ONLY CAPS: 60 races calibrated")
	quit()
