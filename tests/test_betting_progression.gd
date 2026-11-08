extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://validation/championship_economy/before_contracts.json"))
	for letter in Championships.CLASSES:
		var prior:=0
		for id in Championships.ids(letter):
			var event:=Championships.event(id)
			check(event.purse==0 and event.completion_bonus==0,"Cash payout remains in "+id)
			check(event.max_bet==Championships.bet_cap(letter,int(event.round)) and event.max_bet>prior,"Bet cap does not scale with round: "+id)
			prior=int(event.max_bet)
			if int(event.round)>0:
				check(float(RaceAI.estimate(event,402.336).time)<float(RaceAI.estimate(baseline[id],402.336).time)-.08,"Follow-up match did not get harder: "+id)
				check(float(RaceAI.estimate(event,float(event.distance)).time)<float(RaceAI.estimate(baseline[id],float(event.distance)).time)-.03,"Follow-up match is easier over its actual distance: "+id)
		var first:=Championships.event("class_%s_0"%letter)
		var rival:=RaceAI.estimate(first,float(first.distance))
		for model in RosterData.IDS:
			if GameCatalog.engine_class(model)!=letter: continue
			var stock: Dictionary={"model":model,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build(model),"driver_model":2,"reaction":.25,"pedal":1.0,"skill":3,"shift_error":0,"traction_skill":.95,"driver_seed":0}
			var player:=RaceAI.estimate(stock,float(first.distance))
			check(player.time<rival.time-.10,"Stock "+model+" cannot beat its class opener")
			var boss:=Championships.event("class_%s_9"%letter)
			check(RaceAI.estimate(stock,402.336).time>RaceAI.estimate(boss,402.336).time+.7,"Stock "+model+" can beat its class boss")
	for id in Championships.ids("OPEN"):
		var event:=Championships.event(id)
		check(event.purse==0 and event.completion_bonus==0 and event.max_bet>0,"Open challenge pays non-betting cash")
	var event:=Championships.event("class_E_0")
	var p:=DriverProfile.new(); p.credits=5000
	check(p.begin_wager(500,event) and p.credits==4500,"Stake was not charged once")
	var result:=p.award_race(event,true,false,16,.25,85,0,0)
	check(p.credits==5500 and result.reward==1000 and result.base==0 and result.bonus==0,"Winning wager did not produce exactly the stake in net profit")
	check(p.award_race(event,true,false,16,.25,85,0,0).is_empty() and p.credits==5500,"Duplicate result paid twice")
	check(p.begin_wager(500,event),"Replay bet failed")
	result=p.award_race(event,false,false,18,.25,80,0,0)
	check(p.credits==5000 and result.reward==0 and result.xp>0,"Losing race granted cash or lost XP")
	check(p.begin_wager(500,event),"Red-light entry failed")
	result=p.award_race(event,true,true,16,-.02,85,0,0)
	check(p.credits==4500 and result.reward==0 and result.xp==0,"Red light paid cash or XP")
	# Old in-flight contracts cannot restore removed cash awards.
	check(p.begin_wager(0,event),"Free entry failed")
	p.pending_wager.contract.purse=99999999
	p.pending_wager.contract.completion_bonus=99999999
	result=p.award_race(event,true,false,16,.25,85,0,0)
	check(p.credits==4500 and result.reward==0,"Old bound contract paid obsolete race income")
	p.credits=0
	var xp_before:=p.xp; var rounds:=Championships.completed(p)
	check(p.begin_wager(0,Championships.event("class_E_1")),"Bankrupt player cannot race for XP and progress")
	result=p.award_race(Championships.event("class_E_1"),true,false,10,.25,100,0,0)
	check(p.credits==0 and p.xp>xp_before and Championships.completed(p)==rounds+1,"Free race changed money or failed to grant progress")
	check(not p.begin_wager(1,event),"Bankrupt player was given a betting loan")
	p=DriverProfile.new(); p.credits=2000000
	for category in 8:
		var previous:=0
		for tier in range(1,GameCatalog.max_stage(category)+1):
			var cost:=GameCatalog.stage_cost(category,tier)
			check(cost>=previous*2 and cost>0,"Stage prices do not have meaningful gaps")
			previous=cost
	check(p.upgrade_cost(0,3)==8400,"Package skips did not sum stage prices")
	check(p.upgrade(0,3),"Tier-three purchase failed")
	var cash:=p.credits
	check(p.upgrade(0,0) and p.upgrade(0,3) and p.credits==cash,"Purchased stage was charged again after switching")
	p.save(); var loaded:=DriverProfile.new(); loaded.load_profile()
	check(loaded.credits==p.credits and loaded.stages==p.stages,"New prices changed saved ownership")
	print("STOCK OPENERS / UPGRADED BOSSES / BETTING-ONLY CASH / STAGED PRICES: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
