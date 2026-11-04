class_name CareerBoard
extends RefCounted
var g: Node2D
var active := false
var picker := true
var series := "E"
var selected := "class_E_0"

func _init(game: Node2D) -> void: g=game
func contract() -> Dictionary: return Championships.event(selected)
func open() -> void: active=true; picker=true; g.menu_dirty=true
func text(value: String,x: float,y: float,size: int=18,c: Color=GlassPalette.INK) -> void: g.text_at(value,x,y,size,c)
func button(id: String,label: String,r: Rect2,primary: bool=false,chosen: bool=false) -> void:
	if g.race_touch_layout() and not g.is_portrait(): g.race_hud.control(id,label,r,"",primary,chosen,g.action_enabled(id))
	else: g.button(id,label,r,primary,chosen)
func select_series(letter: String) -> void:
	series=letter; picker=false
	var options:=Championships.ids(letter)
	if not options.is_empty(): selected=str(options[mini(4,Championships.wins(g.profile,letter)) if letter!="OPEN" else 0])
	g.wager=0; g.menu_dirty=true
func draw() -> void:
	var p: bool=g.is_portrait()
	if p: g.mobile.header("CLASS CAREER")
	else: g.draw_header(); text("Class championships",36,127,28)
	button("cb_back","Street series" if picker else "< Championships",Rect2(24,80,264,68) if p else Rect2(952,92,214,90) if g.race_touch_layout() else Rect2(952,103,214,48))
	var current:=PerformanceClasses.request(g.profile.vehicle_id,g.profile.stages,g.profile.hardware)
	g.fit_text("Factory %s / Current %s"%[PerformanceClasses.factory_class(g.profile.vehicle_id),current.get("class","...")],312 if p else 38,121 if p else 157,264 if p else 870,19 if p else 15,g.MUTED)
	if picker: draw_classes(p)
	else: draw_rival(p)
	g.draw_navigation()
func draw_classes(p: bool) -> void:
	for i in 6:
		var letter: String=Championships.CLASSES[i]
		var r:=Rect2(24+(i%2)*284,182+int(i/2)*218,268,200) if p else Rect2(36+(i%3)*380,182+int(i/3)*196,368,180)
		var locked:=Championships.unlock_reason(g.profile,letter)
		button("cb_class_"+letter,"",r,false,letter==series)
		text(letter,r.position.x+18,r.position.y+55,42,GlassPalette.BLUE if locked=="" else g.MUTED)
		text(Championships.TITLES[i],r.position.x+18,r.position.y+88,22 if p else 21)
		text("%d / 5 wins"%Championships.wins(g.profile,letter),r.position.x+18,r.position.y+120,20 if p else 15,g.GREEN)
		g.fit_text(("CHAMPION / BONUS EARNED" if Championships.wins(g.profile,letter)==5 else "Final bonus $%d"%Championships.BONUSES[i]) if locked=="" else "Clear %s / %d race wins"%[Championships.CLASSES[maxi(0,i-1)],i*3],r.position.x+18,r.position.y+151,r.size.x-36,18 if p else 14,g.MUTED)
	button("cb_open","OPEN CLASS / RECOVERY & RIVAL CHALLENGES",Rect2(24,876,552,88) if p else Rect2(36,562,1130,90) if g.race_touch_layout() else Rect2(36,600,1130,54),true)
func draw_rival(p: bool) -> void:
	var c:=contract()
	if c.is_empty(): return
	var estimate:=RaceAI.request_estimate(c,float(c.distance))
	var options:=Championships.ids(series)
	for i in options.size():
		var item:=Championships.event(str(options[i]))
		var r:=Rect2(24+i*112,570,104,68) if p else Rect2(36,182+i*94,310,90) if g.race_touch_layout() else Rect2(36,182+i*88,310,78)
		button("cb_rival_"+str(item.id),str(i+1) if p else "",r,false,selected==item.id)
		if not p:
			text(str(item.name),r.position.x+16,r.position.y+29,20)
			text("FINAL" if series!="OPEN" and i==4 else ("RIVAL CHALLENGE" if i==3 else str(item.event_name).split(" / ")[0]),r.position.x+16,r.position.y+55,12,g.MUTED)
	if p:
		text(str(c.name),24,202,30); text(str(c.nickname),24,238,21,GlassPalette.BLUE)
		g.draw_workshop(Rect2(24,258,552,220))
		g.draw_car(Vector2(30,248),2.3,g.PAINTS[int(c.get("paint_index",c.round))%6],0,0,false,str(c.model))
		g.fit_text(str(GameCatalog.spec(str(c.model)).name),24,514,552,23)
		g.fit_text(("%d HP / "%int(estimate.hp) if not estimate.is_empty() else "Measuring / ")+str(c.build_label)+" / "+str(c.get("preferred_class",c.race_class)),24,548,552,20,g.MUTED)
	else:
		g.box(Rect2(368,182,798,473))
		text(str(c.name),390,220,27); text(str(c.nickname),390,250,16,GlassPalette.BLUE)
		g.draw_car(Vector2(674,230),2.0,g.PAINTS[int(c.get("paint_index",c.round))%6],0,0,false,str(c.model))
		g.fit_text(str(GameCatalog.spec(str(c.model)).name),390,282,390,17,g.MUTED)
		g.fit_text(str(c.identity),390,316,400,15,g.MUTED)
		g.fit_text(("%d HP / "%int(estimate.hp) if not estimate.is_empty() else "Measuring / ")+str(c.build_label),390,354,280,15,g.MUTED)
	var player:=RaceAI.player_contract(g.profile)
	player.driver_model=2; player.nitrous=g.profile.stages[7]>0
	var expected:=RaceAI.request_estimate(player,float(c.distance))
	var comparison := "Measuring race potential..."
	if not estimate.is_empty() and not expected.is_empty():
		var gap: float=float(estimate.time)-float(expected.time)
		comparison=("Favorable" if gap>.7 else "Close match" if gap>-.7 else "Challenging")+" / rival %.2fs / you %.2fs"%[estimate.time,expected.time]
	var x:=24 if p else 390
	var y:=682 if p else 402
	g.fit_text(comparison,x,y,552 if p else 744,21 if p else 17,g.GREEN)
	g.fit_text(str(c.tradeoff),x,y+38,552 if p else 744,19 if p else 14,g.MUTED)
	text(("OPEN" if series=="OPEN" else "CLASS "+series)+" / "+g.distance_label(float(c.distance)),x,y+75,23 if p else 16,GlassPalette.BLUE)
	text("WIN $%d / FINISH $%d"%[c.purse,int(float(c.purse)*.4)],x,832 if p else 514,23 if p else 17)
	if int(c.completion_bonus)>0 and (p or not g.race_touch_layout()): text("Bonus earned" if g.profile.career_claims.has(str(c.id)) else "First win bonus $%d"%int(c.completion_bonus),x,872 if p else 546,21 if p else 15,g.GREEN)
	var short: bool=g.race_touch_layout() and not p
	var by:=918 if p else (560 if short else 568)
	button("bet_less","-",Rect2(x,by,80 if p else (90 if short else 48),68 if p else (90 if short else 44)))
	text("Wager $%d / risk $%d"%[g.wager,g.wager],x+96 if p else (x+110 if short else x+65),by+42 if p else by+30,21 if p else 16,g.MUTED)
	button("bet_more","+",Rect2(496,by,80,68) if p else Rect2(704,by,90,90) if short else Rect2(746,by,48,44))
	button("bet_clear","No wager",Rect2(24,1006,180,68) if p else Rect2(808,by,138,90) if short else Rect2(810,by,134,44))
	var reason:=Championships.eligibility(g.profile,c)
	g.fit_text(reason if reason!="" else "Installed nitrous kit required for spray",224 if p else 390,1045 if p else (548 if short else 641),352 if p else 550,18 if p else 13,g.ORANGE if reason!="" else g.MUTED)
	button("race","RACE" if reason=="" else ("MEASURING" if reason.begins_with("Measuring") else "LOCKED"),Rect2(24,1086,552,68) if p else Rect2(960,560,184,90) if short else Rect2(962,568,184,48),reason=="")
func action(id: String) -> void:
	g.race_start_pending=false; g.recommend_pending=false
	if id=="cb_back":
		if picker: active=false
		else: picker=true
	elif id=="cb_open": select_series("OPEN")
	elif id.begins_with("cb_class_"): select_series(id.trim_prefix("cb_class_"))
	elif id.begins_with("cb_rival_"): selected=id.trim_prefix("cb_rival_"); g.wager=0
	g.menu_dirty=true

