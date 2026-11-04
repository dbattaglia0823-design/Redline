extends SceneTree
const NAMES := [
	["Dex Rowan","Nia Reyes","Milo Knox","Iris Vale","Sora Imani"],
	["Jules Park","Bea Holt","Rio Vega","Cass Morrow","Theo Flint"],
	["Vera Cruz","Benji Lane","Ada Kestrel","Quinn Sato","Mara Voss"],
	["Ellis Stone","Lex Byrne","Cora Wynn","Jett Hale","Remy Sol"],
	["Rhea North","Dante Moss","Mika Frost","Gia Ash","Axel Ward"],
	["Nova Reed","Leon Hart","Skye Mercer","Rex Wren","Morgan Black"]]
const ARCHETYPES := [
	["The Apprentice","Patient launch; hesitant shifts","Reliable staging / slow gear changes"],
	["The Mechanic","Strong setup; conservative pedal","Good grip / cautious on the bottle"],
	["The Sprinter","Aggressive launch; impatient shifts","Fast reaction / wheelspin risk"],
	["The Specialist","Smooth clutch and near-optimal shifts","Consistent launch / little margin on gearing"],
	["The Champion","Precise launch, shifts and spray timing","Complete build / must be beaten on execution"]]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pools: Dictionary={}; var output: Dictionary={}; var report: Array=[]
	for letter in Championships.CLASSES: pools[letter]=[]
	for id in GameCatalog.CAR_IDS:
		for variant in 4:
			var levels:=GameCatalog.blank_stages()
			if variant>0: levels=[mini(2,variant),0,mini(2,variant),0,mini(2,variant),1 if variant>1 else 0,0,0]
			var build:=GameCatalog.factory_build(id)
			var measured:=VehicleBench.run(GameCatalog.spec(id),levels,build)
			if measured.quarter_s==null or measured.safety_clamps>0: push_error("Invalid championship candidate: "+id); quit(1); return
			var letter:=PerformanceClasses.classify(float(measured.quarter_s))
			pools[letter].append({"model":id,"stages":levels,"hardware":build,"potential_s":measured.quarter_s,"potential_et":measured.quarter_et_s,"variant":variant})
	for rank in 6:
		var letter: String=Championships.CLASSES[rank]
		var pool: Array=pools[letter]
		pool.sort_custom(func(a,b): return float(a.potential_s)>float(b.potential_s))
		if pool.size()<5: push_error("Not enough calibrated builds in class "+letter); quit(1); return
		var used: Array=[]
		for round in 5:
			var index:=roundi((pool.size()-1)*round/4.0)
			var candidate: Dictionary=pool[index].duplicate(true)
			# Prefer another model near the target, while retaining measured class fit.
			for delta in range(0,mini(4,pool.size())):
				var probe: Dictionary=pool[clampi(index+delta,0,pool.size()-1)]
				if not used.has(probe.model): candidate=probe.duplicate(true); break
			used.append(candidate.model)
			var contract:=make_event(candidate,letter,round,rank)
			output[contract.id]=contract
			var actual:=RaceAI.estimate(contract,float(contract.distance))
			report.append({"id":contract.id,"model":contract.model,"class":letter,"potential_s":candidate.potential_s,"race_s":actual.time,"trap_mph":actual.mph,"clamps":actual.clamps})
	var open_rows := [["miata",0,"Dockside Recovery",""],["supra",1,"Tuner Showcase",""],["gtr",2,"All-Wheel Duel",""],["camaro",3,"Bottle & Converter",""],["miata",1,"Roadster Cup","miata"]]
	for i in open_rows.size():
		var row: Array=open_rows[i]
		var levels:=GameCatalog.blank_stages()
		if i>0: levels=[row[1],1 if i==3 else 0,mini(3,int(row[1])),1,5 if i==3 else 2,1,0,1 if i==3 else 0]
		var b:=GameCatalog.factory_build(row[0])
		if i==3: b=VehicleBench.fixture("drag3",["converter_race","race_controller","transbrake","progressive","ecu"],{"launch_rpm":4200,"stall":4400})
		var potential:=VehicleBench.run(GameCatalog.spec(row[0]),levels,b)
		var c:=make_event({"model":row[0],"stages":levels,"hardware":b,"potential_s":potential.quarter_s,"potential_et":potential.quarter_et_s,"variant":1},"OPEN",i,mini(5,i))
		c.id="open_%d"%i; c.event_name=row[2]; c.vehicle_rule=row[3]; c.purse=350+i*450; c.max_bet=500+i*750
		c.distance=804.672 if i==3 else 402.336; c.nitrous=i==3; c.completion_bonus=700+i*600; c.xp=100+i*60
		output[c.id]=c
	var f:=FileAccess.open("res://assets/data/championships.json",FileAccess.WRITE); f.store_string(JSON.stringify(output,"  ")); f.close()
	f=FileAccess.open("res://validation/championship_balance.json",FileAccess.WRITE); f.store_string(JSON.stringify(report,"  ")); f.close()
	print("CHAMPIONSHIP BUILDS: ",output.size()," / ",report.size()," measured class rivals")
	quit()
func make_event(candidate: Dictionary,letter: String,round: int,rank: int) -> Dictionary:
	var c:=candidate.duplicate(true)
	c.id="class_%s_%d"%[letter,round]; c.series=letter; c.round=round
	c.name=NAMES[rank][round]; c.nickname=ARCHETYPES[round][0]; c.identity=ARCHETYPES[round][1]; c.tradeoff=ARCHETYPES[round][2]
	c.event_name=("Final / " if round==4 else "Rival challenge / " if round==3 else "Heat / ")+c.name
	c.driver_model=2; c.skill=mini(3,round); c.traction_skill=.4+round*.14; c.shift_error=220-round*45
	c.reaction=maxf(.12,.64-round*.105-rank*.025); c.pedal=.83+round*.035
	c.launch_style=["patient","balanced","aggressive","balanced","precise"][round]
	c.driver_seed=rank*17+round*3; c.nitrous=false
	c.distance=201.168 if round in [1,3] else 402.336
	c.purse=Championships.PAY[rank]+round*int(Championships.PAY[rank]*.22)
	c.max_bet=500+rank*1200+round*250; c.xp=130+rank*60+round*25
	c.completion_bonus=Championships.BONUSES[rank] if round==4 else 0
	c.race_class=letter; c.build_label="Factory" if candidate.variant==0 else "Mechanical build %d"%candidate.variant
	c.preferred_class=PerformanceClasses.classify(float(candidate.potential_s))
	c.paint_index=(rank*2+round)%6; c.track_index=mini(2,int(rank/2))
	c.vehicle_rule=""; return c
