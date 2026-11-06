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
	if g.tab == "style":
		g.draw_style()
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
	g.career_board.draw()

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


