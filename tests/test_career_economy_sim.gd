extends SceneTree
var failures:=0
var trials: Array=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func add_candidate(pool: Array,seen: Dictionary,id: String,levels: Array,build: Dictionary) -> void:
	var key:=JSON.stringify([id,levels,build])
	if seen.has(key): return
	seen[key]=true
	var measured:=VehicleBench.run(GameCatalog.spec(id),levels,build)
	if measured.quarter_s==null or measured.safety_clamps>0: return
	measured["class"]=PerformanceClasses.classify(float(measured.quarter_s))
	PerformanceClasses.cache[PerformanceClasses.signature(id,levels,build)]=measured
	pool.append({"model":id,"stages":levels.duplicate(),"hardware":build.duplicate(true),"class":measured["class"]})
func cost(p: DriverProfile,c: Dictionary) -> int:
	var charge:=0
	var old: Dictionary=p.garage.get(c.model,{})
	if old.is_empty():
		if p.level()<int(GameCatalog.spec(c.model).get("unlock_level",1)): return 999999999
		charge=int(GameCatalog.spec(c.model).price)
	var levels: Array=old.get("stages",GameCatalog.blank_stages())
	var old_build: Dictionary=old.get("hardware",GameCatalog.factory_build(c.model))
	var conversion: bool=str(old_build.transmission)!=str(c.hardware.transmission)
	for i in 8:
		if int(c.stages[i])<int(levels[i]): return 999999999
		var owned_level:=0 if i==4 and conversion else int(levels[i])
		for tier in range(owned_level+1,int(c.stages[i])+1): charge+=GameCatalog.PART_COSTS[i]*tier
	if conversion: charge+=int(TransmissionCatalog.spec(c.hardware.transmission).cost)
	for part in c.hardware.parts.values():
		if conversion or not old_build.get("parts",{}).values().has(part): charge+=int(VehicleParts.PARTS[part].cost)
	return charge
func driver(c: Dictionary,event: Dictionary) -> Dictionary:
	return {"model":c.model,"stages":c.stages,"hardware":c.hardware,"driver_model":2,"reaction":.12,"pedal":1.0,"skill":3,"shift_error":0,"traction_skill":.95,"nitrous":event.get("rule","")!="motor_only" and int(c.stages[7])>0,"nitrous_gear":1,"driver_seed":0}
func run() -> void:
	var pool: Array=[]; var seen: Dictionary={}
	for id in Championships.catalog():
		var c:=Championships.event(id)
		if c.series=="OPEN": continue
		add_candidate(pool,seen,c.model,c.stages,c.hardware)
		if c.series!="E":
			var sprayed: Array=c.stages.duplicate(); sprayed[7]=1
			add_candidate(pool,seen,c.model,sprayed,c.hardware)
	for engine in 4:
		for weight in 4:
			for exhaust in 3:
				for tire in 2: add_candidate(pool,seen,"miata",[engine,0,tire,weight,0,exhaust,0,0],GameCatalog.factory_build("miata"))
	for id in ["civic_si","gti_vr6"]:
		for engine in [1,2,3]:
			for exhaust in [0,1]:
				for weight in [0,2]: add_candidate(pool,seen,id,[engine,0,3,weight,2,exhaust,0,1],GameCatalog.factory_build(id))
	for id in ["supra","camaro","gtr"]:
		for turbo in [1,2,3]:
			for spray in [1,3]: add_candidate(pool,seen,id,[3,turbo,3,3,5,3,0,spray],GameCatalog.factory_build(id))
	for id in ["supra","camaro"]:
		var drag:=VehicleBench.fixture("drag3",["billet","fuel_ethanol","turbo_race","converter_race","race_controller","transbrake","ecu","drag_wheels"],{"launch_rpm":4800,"stall":4600})
		add_candidate(pool,seen,id,[3,3,3,3,5,3,0,3],drag)
	# A player-owned Demon can beat the Crown without buying its Chiron.
	for spray in [0,1,3]:
		add_candidate(pool,seen,"demon",[3,2,3,1,5,3,0,spray],GameCatalog.factory_build("demon"))
	var tuned:=DriverProfile.new(); tuned.vehicle_id="camaro"; tuned.stages=[3,3,3,3,5,3,0,3]
	tuned.hardware=VehicleBench.fixture("drag3",["billet","fuel_ethanol","turbo_race","converter_race","race_controller","transbrake","ecu","drag_wheels","gearset","final_kit","boost_control"],{"launch_rpm":4800,"stall":4600})
	var search:=TuneOptimizer.new(); search.begin(tuned,402.336)
	for trial in 1200:
		if search.done: break
		search.advance(9600)
	tuned.hardware.tune=search.best_tune.duplicate(true)
	add_candidate(pool,seen,"camaro",tuned.stages,tuned.hardware)
	var p:=DriverProfile.new(); var extra_runs:=0
	for letter in Championships.CLASSES:
		for id in Championships.ids(letter):
			var event:=Championships.event(id)
			var bot:=RaceAI.estimate(event,float(event.distance))
			var chosen: Dictionary={}; var estimate: Dictionary={}; var price:=999999999
			var offers: Array=[]
			for index in pool.size():
				var candidate: Dictionary=pool[index]
				if candidate["class"]!=letter: continue
				var required:=cost(p,candidate)
				if required<999999999: offers.append({"cost":required,"index":index})
			offers.sort_custom(func(a,b): return a.index<b.index if a.cost==b.cost else a.cost<b.cost)
			for offer in offers:
				var candidate: Dictionary=pool[offer.index]
				var actual:=RaceAI.estimate(driver(candidate,event),float(event.distance))
				if actual.time<float(bot.time):
					chosen=candidate; estimate=actual; price=offer.cost
					break
			check(not chosen.is_empty(),"No competitive authored build for "+id)
			if chosen.is_empty(): break
			while p.credits<price and extra_runs<30:
				var current:={"model":p.vehicle_id,"stages":p.stages,"hardware":p.hardware}
				var recovery: Dictionary={}; var a: Dictionary={}; var b: Dictionary={}; var pay:=0
				for candidate_id in Championships.catalog():
					var available:=Championships.event(candidate_id)
					if Championships.eligibility(p,available)!="" or int(available.purse)<=pay: continue
					var player:=RaceAI.estimate(driver(current,available),float(available.distance)); var opponent:=RaceAI.estimate(available,float(available.distance))
					if player.time<opponent.time: recovery=available; a=player; b=opponent; pay=int(available.purse)
				check(not recovery.is_empty(),"No suitable recovery race")
				if recovery.is_empty(): break
				check(a.time<b.time,"Recovery race is not winnable")
				check(p.begin_wager(0,recovery),"Recovery race entry failed")
				p.award_race(recovery,true,false,float(a.time),.18,float(a.mph),0,0); extra_runs+=1
			check(p.credits>=price,"Excessive grind before "+id)
			if p.credits<price: break
			p.snapshot_vehicle(); p.credits-=price
			p.vehicle_id=chosen.model; p.stages=chosen.stages.duplicate(); p.hardware=chosen.hardware.duplicate(true)
			p.garage[p.vehicle_id]={"stages":p.stages.duplicate(),"hardware":p.hardware.duplicate(true)}
			check(p.begin_wager(0,event),"Progression eligibility failed for "+id)
			p.award_race(event,true,false,float(estimate.time),.18,float(estimate.mph),0,0)
			trials.append({"event":id,"model":p.vehicle_id,"purchase_and_upgrade_cost":price,"player_s":estimate.time,"rival_s":bot.time,"credits_after":p.credits,"recovery_runs_so_far":extra_runs})
	check(trials.size()==Championships.TOTAL_RACES,"Economy simulation could not finish all championships")
	check(extra_runs<=12,"More than twelve extra recovery races needed")
	var f:=FileAccess.open("res://.qa/career_economy_progression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures==0,"recovery_runs":extra_runs,"events":trials,"note":"Competent simulated controls, zero wagers, exact part-stage costs, retained per-car upgrades; this measures an attainable route, not human win probability."},"  ")); f.close()
	print("SIMULATED CAREER ECONOMY / ",trials.size()," championships heats / ",extra_runs," recovery races: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
