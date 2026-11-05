class_name GarageView
extends RefCounted

const BG := GlassPalette.BG
const PANEL := GlassPalette.SURFACE
const EDGE := GlassPalette.EDGE
const INK := GlassPalette.INK
const MUTED := GlassPalette.MUTED
const ORANGE := GlassPalette.ORANGE
const GREEN := GlassPalette.GREEN
var g: Node2D
var hub: GarageHub
var dealer: DealershipView
var customize: CustomizationView

func _init(game: Node2D) -> void:
	g = game
	hub = GarageHub.new(game)
	dealer = DealershipView.new(game)
	customize = CustomizationView.new(game)

func t(value: String,x: float,y: float,size: int = 18,color: Color = INK,mono: bool = false) -> void:
	g.text_at(value,x,y,size,color,mono)

func box(rect: Rect2,fill: Color = PANEL,border: Color = EDGE) -> void:
	g.box(rect,fill,border)

func button(id: String,label: String,rect: Rect2,primary: bool = false,selected: bool = false) -> void:
	g.button(id,label,rect,primary,selected)

func draw() -> void:
	if g.tab == "style" and customize.portrait():
		customize.draw_portrait()
		return
	g.draw_header()
	var titles := {"owned":"Your collection", "garage":"Garage", "performance":"Upgrades", "style":"Customize", "dealer":"Dealership", "races":"Race board", "driver":"Driver"}
	var spec := GameCatalog.spec(g.profile.vehicle_id)
	if g.tab != "garage": t(str(titles.get(g.tab,"Garage")),36,128,28)
	var subtitles := {"garage":"%s / %s / %s" % [spec.name,spec.engine,spec.drive], "performance":"%s / %s" % [spec.name,spec.engine], "style":"", "dealer":"Factory builds", "races":"", "driver":""}
	if g.tab != "garage": t(str(subtitles.get(g.tab,"")),38,156,15,MUTED)
	match g.tab:
		"garage": draw_garage()
		"performance": draw_workshop()
		"owned": hub.draw_owned()
		"style": g.draw_style()
		"dealer": draw_dealer()
		"races": draw_race_select()
		"driver": g.draw_driver()
	g.draw_navigation()

	if g.tab == "performance" and not hub.categories: hub.draw_upgrade_window()
	if hub.dyno_open: hub.draw_dyno_overlay()

func draw_garage() -> void:
	hub.draw_garage()

func draw_workshop() -> void:
	hub.draw_upgrades()

func draw_dealer() -> void:
	dealer.draw()

func draw_race_select() -> void:
	button("open_championships","CLASS CHAMPIONSHIPS",Rect2(644,103,304,48),true)
	button("recommend_rival","FINDING..." if g.recommend_pending else "FIND MATCH",Rect2(962,103,204,48))
	for career in 3:
		var y := 182+career*158
		var locked: bool = g.profile.level() < GameCatalog.CAREER_LEVELS[career]
		button("event_%d" % career,"",Rect2(36,y,350,144),false,g.event_index == career)
		t("LEVEL %d" % GameCatalog.CAREER_LEVELS[career] if locked else "CAREER",56,y+27,11,MUTED,true)
		t(GameCatalog.CAREER_NAMES[career],56,y+61,22,MUTED if locked else INK)
		var progress := int(g.profile.career_wins[career])
		var next := GameCatalog.opponent(career,mini(4,progress))
		t("Unlock at level %d" % GameCatalog.CAREER_LEVELS[career] if locked else str(next.name)+" / "+g.distance_label(float(next.distance)),56,y+91,13,MUTED)
		t("%d / 5" % progress,319,y+27,12,GREEN,true)
		t("$%d race pay" % int(next.purse),56,y+113,11,MUTED)
		for stage in 5:
			g.draw_rect(Rect2(56+stage*63,y+126,54,3),GREEN if stage < progress else EDGE)
	box(Rect2(410,182,756,473))
	var bot := GameCatalog.opponent(g.event_index,g.selected_opponent,g.profile)
	t("CLASS %s / RIVAL %d OF 5" % [str(bot.get("race_class","OPEN")),g.selected_opponent+1],434,215,11,ORANGE,true)
	t(str(bot.name),434,252,29)
	t(str(GameCatalog.spec(str(bot.model)).name),434,280,15,MUTED)
	g.draw_car(Vector2(720,230),1.65,g.PAINTS[(g.event_index+g.selected_opponent+3)%6],0.0,2,false,str(bot.model))
	var measured := RaceAI.request_estimate(bot)
	var player := {"model":g.profile.vehicle_id,"stages":g.profile.stages,"hardware":g.profile.hardware,"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}
	var expected := RaceAI.request_estimate(player,float(bot.distance))
	var event_estimate := RaceAI.request_estimate(bot,float(bot.distance))
	var ready := not event_estimate.is_empty() and not expected.is_empty()
	var gap: float = float(event_estimate.time)-float(expected.time) if ready else 0
	t("%d HP / 1/4 %.2f s" % [measured.hp,measured.time] if not measured.is_empty() else "Measuring...",434,316,15,GREEN)
	t("MEASURING..." if not ready else ("RECOMMENDED" if absf(gap) < .8 else ("FAVORABLE" if gap > 0 else "CHALLENGING")),434,345,12,ORANGE)
	for i in 5:
		button("bot_%d" % i,str(i+1) if i <= mini(4,int(g.profile.career_wins[g.event_index])) else "-",Rect2(434+i*76,372,64,44),false,i == g.selected_opponent)
	t("Cash wager",434,460,14,MUTED)
	t("$%d" % g.wager,704,460,23,INK,true)
	button("bet_less","-",Rect2(434,480,44,44))
	button("bet_more","+",Rect2(758,480,44,44))
	g.draw_rect(Rect2(496,499,242,4),EDGE)
	var max_bet := mini(g.profile.credits,int(bot.max_bet))
	var fraction := float(g.wager)/maxf(1.0,float(max_bet))
	g.draw_rect(Rect2(496,499,242*clampf(fraction,0,1),4),ORANGE)
	g.draw_circle(Vector2(496+242*clampf(fraction,0,1),501),8,INK)
	g.buttons.append({"id":"bet_slider","rect":Rect2(488,479,258,46),"range":Vector2(496,738)})
	t("Win +$%d  /  Lose -$%d" % [g.wager,g.wager],434,556,14,GREEN)
	t("Race pay  $%d win / $%d finish" % [int(bot.purse),int(float(bot.purse)*0.4)],434,587,13,MUTED)
	button("bet_clear","No wager",Rect2(434,604,150,44))
	t(g.distance_label(float(bot.distance)),920,460,18)
	t("WIN REWARD",920,498,11,MUTED,true)
	t("$%d" % int(bot.purse),920,534,28,GREEN)
	var locked: bool = g.profile.level() < GameCatalog.CAREER_LEVELS[g.event_index]
	button("race","LEVEL %d REQUIRED" % GameCatalog.CAREER_LEVELS[g.event_index] if locked else "Race  >",Rect2(884,578,258,56),not locked)

func draw_results() -> void:
	g.draw_header()
	t("%s / %s" % [("CLASS "+str(g.active_contract.series) if g.active_contract.has("id") else GameCatalog.CAREER_NAMES[g.event_index]),str(g.active_contract.get("name","RIVAL")).to_upper()],36,130,14,ORANGE,true)
	t("RED LIGHT / DISQUALIFIED" if g.staging.red_light else ("YOU TOOK THE STRIP." if g.result_win else "BUILD. TUNE. RUN IT BACK."),36,184,42)
	g.draw_workshop(Rect2(36,219,615,380))
	g.draw_car(Vector2(77,332),2.28,g.PAINTS[g.profile.paint],0.0,g.profile.wheels,false,g.profile.vehicle_id,-1,.315,g.car)
	t(GameCatalog.spec(g.profile.vehicle_id).name.to_upper(),61,567,23)
	if g.result_record:
		g.glass.surface(g,Rect2(423,235,207,37),Color("173335"),Color(GREEN,.54),12)
		t("NEW PERSONAL BEST",439,259,15,GREEN,true)
	g.draw_rect(Rect2(679,219,487,380),Color("e9e2d0"))
	for i in 27:
		g.draw_circle(Vector2(688+i*18,219),4,BG)
		g.draw_circle(Vector2(688+i*18,599),4,BG)
	var paper_ink := Color("343a3d")
	t("REDLINE / TIME SLIP",702,252,19,paper_ink,true)
	t(g.distance_label(g.active_distance),1037,251,13,paper_ink,true)
	g.draw_line(Vector2(702,267),Vector2(1141,267),Color("aba796"))
	t("YOU",904,291,12,paper_ink,true)
	t("RIVAL",1057,291,12,paper_ink,true)
	t("ELAPSED / ET",702,323,14,paper_ink,true)
	t("%.3f s" % g.staging.elapsed(g.player_finish),881,323,20,paper_ink,true)
	t("%.3f" % g.staging.elapsed(g.rival_finish,1) if g.rival_finish > 0 else "BEHIND",1042,323,16,paper_ink,true)
	t("REACTION",702,354,14,paper_ink,true)
	t(("RED " if g.staging.red_light else "")+"%.3f s" % g.player_reaction if g.staging.released[0] else "--",881,354,16,paper_ink,true)
	t("%.3f" % g.staging.reactions[1] if g.staging.released[1] else "--",1042,354,16,paper_ink,true)
	t("TRAP SPEED",702,385,14,paper_ink,true)
	t("%.1f MPH" % g.finish_speed,881,385,16,paper_ink,true)
	t("%.1f" % g.rival_trap_speed,1042,385,16,paper_ink,true)
	t("TOTAL / PERFECT SHIFTS",702,416,12,paper_ink,true)
	t("%.3f S / %d" % [g.player_finish,g.perfect_shifts],927,416,16,paper_ink,true)
	g.draw_line(Vector2(702,435),Vector2(1141,435),Color("aba796"))
	t("RACE PAY",702,466,14,paper_ink,true)
	t("+$%d" % g.result_base_pay,1041,466,18,paper_ink,true)
	t("BET RETURN (STAKE INCLUDED)",702,496,12,paper_ink,true)
	t("$%d" % g.result_bet_return,1041,496,18,paper_ink,true)
	var net: int = g.result_reward-g.active_stake
	t("NET RUN",702,550,17,paper_ink,true)
	t(("+$" if net >= 0 else "-$")+str(absi(net)),1003,550,27,Color("32704d") if net >= 0 else Color("9e493b"),true)
	t("+%d XP / DRIVER %02d" % [g.result_xp,g.profile.level()],39,641,23,GREEN)
	t("COMPLETION BONUS +$%d"%g.result_bonus if g.result_bonus>0 else ("LEVEL UP" if g.profile.level() > g.previous_level else "%d XP TO NEXT LEVEL" % (g.profile.next_level_xp()-g.profile.xp)),730,641,16,GREEN if g.result_bonus>0 else MUTED,true)
	button("garage","GARAGE",Rect2(36,687,145,47))
	button("results_upgrades","UPGRADES",Rect2(197,687,190,47))
	button("retry","REMATCH [R]",Rect2(635,687,240,47))
	button("next_rival","RACE BOARD / NEXT RIVAL",Rect2(892,687,274,47),true)


