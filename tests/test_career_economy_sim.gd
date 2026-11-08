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
	pool.append({"model":id,"stages":levels.duplicate(),"hardware":build.duplicate(true),"class":GameCatalog.engine_class(id,build)})
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
		var owned_level:=0 if i==4 and conversion else int(old.get("owned_stages",levels)[i])
		for tier in range(owned_level+1,int(c.stages[i])+1): charge+=GameCatalog.stage_cost(i,tier)
	if conversion: charge+=int(TransmissionCatalog.spec(c.hardware.transmission).cost)
	for part in c.hardware.parts.values():
		if conversion or not old_build.get("owned_parts",[]).has(part): charge+=int(VehicleParts.PARTS[part].cost)
	return charge
func driver(c: Dictionary,event: Dictionary) -> Dictionary:
	return {"model":c.model,"stages":c.stages,"hardware":c.hardware,"driver_model":2,"reaction":.12,"pedal":1.0,"skill":3,"shift_error":0,"traction_skill":.95,"nitrous":event.get("rule","")!="motor_only" and int(c.stages[7])>0,"nitrous_gear":1,"driver_seed":0}
func run() -> void:
	var replay:=DriverProfile.new()
	replay.credits=1000
	var rival:=Championships.event("open_0")
	for attempt in 2:
		check(replay.begin_wager(100,rival),"Rival wager was locked")
		var payout:=replay.award_race(rival,attempt==1,false,17.0,.24,88.0,0,0)
		check(not payout.is_empty() and payout.base==0 and payout.bonus==0 and payout.reward==(200 if attempt==1 else 0) and Championships.completed(replay)==0,"Rival replay did not earn cash independently")
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
		var drag:=VehicleBench.fixture("drag3",["billet","fuel_ethanol","turbo_race","ecu","drag_wheels"],{"launch_rpm":4800})
		add_candidate(pool,seen,id,[3,3,3,3,5,3,0,3],drag)
	for id in GameCatalog.CAR_IDS:
		for levels in [GameCatalog.blank_stages(),[1,0,1,0,1,1,0,0],[2,1,2,1,3,2,0,1],[3,2,3,2,5,3,0,3]]:
			add_candidate(pool,seen,id,levels,GameCatalog.factory_build(id))
	# A player-owned Demon can beat the Crown without buying its Chiron.
	for spray in [0,1,3]:
		add_candidate(pool,seen,"demon",[3,2,3,1,5,3,0,spray],GameCatalog.factory_build("demon"))
	var tuned:=DriverProfile.new(); tuned.vehicle_id="camaro"; tuned.stages=[3,3,3,3,5,3,0,3]
	tuned.hardware=VehicleBench.fixture("drag3",["billet","fuel_ethanol","turbo_race","ecu","drag_wheels","boost_control"],{"launch_rpm":4800})
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
				if actual.clamps==0 and actual.time<float(bot.time):
					chosen=candidate; estimate=actual; price=offer.cost
					break
			check(not chosen.is_empty(),"No competitive authored build for "+id)
			if chosen.is_empty(): break
			# Keep a betting bankroll after purchasing: $0 is intentionally not a
			# source of recovery cash. Replays use the safest already-beatable rival.
			while p.credits<price+1000 and extra_runs<150:
				var current:={"model":p.vehicle_id,"stages":p.stages,"hardware":p.hardware}
				var recovery: Dictionary={}; var a: Dictionary={}; var pay:=0
				var available_ids: Array=Championships.ids("OPEN")+Championships.ids(GameCatalog.engine_class(p.vehicle_id,p.hardware))
				for candidate_id in available_ids:
					var available:=Championships.event(candidate_id)
					if Championships.eligibility(p,available)!="": continue
					var stake:=mini(int(available.max_bet),maxi(1,p.credits/3))
					if stake<=pay: continue
					var player:=RaceAI.estimate(driver(current,available),float(available.distance)); var opponent:=RaceAI.estimate(available,float(available.distance))
					if player.time<float(opponent.time)-.05: recovery=available; a=player; pay=stake
				check(not recovery.is_empty(),"No beatable betting replay for "+id)
				if recovery.is_empty(): break
				var before_cash:=p.credits
				check(p.begin_wager(pay,recovery),"Betting replay entry failed")
				var before_progress:=Championships.completed(p)
				p.award_race(recovery,true,false,float(a.time),.12,float(a.mph),0,0); extra_runs+=1
				check(p.credits==before_cash+pay,"Replay profit came from something other than the bet")
				check(Championships.completed(p)==before_progress,"Replay advanced championship progress")
			check(p.credits>=price+1000,"Cannot fund build and preserve a bankroll before "+id)
			if p.credits<price+1000: break
			var before_purchase:=p.credits
			if not p.garage.has(chosen.model): check(p.buy_vehicle(chosen.model),"Vehicle purchase failed for "+id)
			else: check(p.select_vehicle(chosen.model),"Owned car selection failed")
			for category in 8:
				if int(p.stages[category])!=int(chosen.stages[category]): check(p.upgrade(category,int(chosen.stages[category])),"Upgrade purchase failed for "+id)
			for slot in p.hardware.parts.keys():
				if not chosen.hardware.parts.has(slot): p.remove_hardware(slot)
			for part in chosen.hardware.parts.values():
				check(p.install_hardware(part).begins_with("Installed"),"Part purchase failed for "+id+" / "+part)
			p.hardware.tune=chosen.hardware.tune.duplicate(true); p.save()
			check(p.credits==before_purchase-price,"Quoted build cost differed from actual purchases for "+id)
			var live:={"model":p.vehicle_id,"stages":p.stages,"hardware":p.hardware}
			estimate=RaceAI.estimate(driver(live,event),float(event.distance))
			check(estimate.time<float(bot.time),"Purchased build cannot win "+id)
			var stake:=mini(int(event.max_bet),maxi(1,p.credits/3))
			var before_cash:=p.credits
			check(p.begin_wager(stake,event),"Progression eligibility failed for "+id)
			p.award_race(event,true,false,float(estimate.time),.12,float(estimate.mph),0,0)
			check(p.credits==before_cash+stake,"Championship paid income beyond betting for "+id)
			trials.append({"event":id,"model":p.vehicle_id,"purchase_and_upgrade_cost":price,"player_s":estimate.time,"rival_s":bot.time,"credits_after":p.credits,"recovery_runs_so_far":extra_runs})
	check(trials.size()==Championships.TOTAL_RACES,"Economy simulation could not finish all championships")
	check(extra_runs<150,"Betting progression needed excessive repeat races")
	var f:=FileAccess.open("res://.qa/career_economy_progression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures==0,"recovery_runs":extra_runs,"events":trials,"note":"Competent simulated controls, one-third-bankroll bets, zero race payouts, real purchase APIs and retained per-car upgrades; this measures an attainable route, not human win probability."},"  ")); f.close()
	print("SIMULATED CAREER ECONOMY / ",trials.size()," championships heats / ",extra_runs," recovery races: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
