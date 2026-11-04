extends SceneTree
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var profile:=DriverProfile.new(); var rows: Array=[]
	var previous:=INF
	for career in 3:
		for index in 5:
			var bot:=GameCatalog.opponent(career,index,profile)
			check(bot.distance==402.336,"Career race is shorter than a quarter mile")
			var result:=RaceAI.estimate(bot)
			check(float(result.time)<previous,"Career pace went backwards at %d/%d"%[career,index])
			check(result.clamps==0,"AI required a physics safety clamp")
			previous=float(result.time)
			rows.append({"career":career,"rival":index,"model":bot.model,"stages":bot.stages,"quarter_s":result.time,"hp":result.hp,"reaction":bot.reaction})
			print(career,"/",index," ",bot.model," ",result.hp," HP / ",result.time," s")
	var first:=GameCatalog.opponent(0,0,profile)
	check(first.model=="miata" and first.stages==GameCatalog.blank_stages(),"First rival is not a stock starter car")
	for i in 3:
		var bot:=GameCatalog.opponent(0,i,profile)
		check(PerformanceClasses.factory_class(bot.model)=="E","Opening rivals are not entry-level cars")
	profile.vehicle_id="chiron"; profile.stages=[3,3,3,3,5,3,3,3]
	check(GameCatalog.opponent(0,0,profile)==first,"Player upgrades caused career rubber-banding")
	check(GameCatalog.opponent(0,0)==first,"Menu and race contracts disagree")
	var beginner:=RaceAI.player_contract(DriverProfile.new())
	beginner.reaction=.35; beginner.skill=0; beginner.shift_error=350.0
	var player:=Drivetrain.new(); RaceAI.configure(player,beginner); player.running=true
	while player.distance<100 and player.elapsed<30: RaceAI.step(player,beginner,1.0/240)
	var rival:=RaceAI.estimate(first,100)
	check(player.distance>=100 and player.elapsed+.35<float(rival.time),"Starter cannot beat first rival with an idle launch and ordinary shifts")
	print("BEGINNER 100m: ",player.elapsed," / FIRST RIVAL: ",rival.time)
	var f:=FileAccess.open("res://validation/ai_progression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures==0,"rows":rows,"beginner_100m_s":player.elapsed,"first_rival_100m_s":rival.time},"  "))
	print("CAREER DIFFICULTY LADDER: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
