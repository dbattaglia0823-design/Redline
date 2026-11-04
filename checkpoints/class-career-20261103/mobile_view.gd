class_name MobileView
extends RefCounted

# Responsive presentation only. Purchases, previews, navigation and racing use the existing actions/models.
var g: Node2D
func _init(game: Node2D) -> void: g = game
func t(value: String,x: float,y: float,size: int = 22,color: Color = Color("f2eee4")) -> void: g.text_at(value,x,y,size,color)
func b(id: String,label: String,r: Rect2,primary: bool = false,selected: bool = false) -> void:
	g.button(id,label,r,primary,selected)
func header(title: String) -> void:
	var size := 28
	while size > 17 and g.font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > 350: size -= 1
	t(title,24,43,size); t("$%d" % g.profile.credits,392,43,22,g.GREEN)
func nav() -> void:
	g.draw_navigation()
func preview(id: String,y: float,car: Drivetrain,look: Dictionary = {}) -> void:
	g.draw_workshop(Rect2(24,y,552,230))
	var appearance: Dictionary = g.profile.appearance_for(id) if look.is_empty() else look
	g.draw_car(Vector2(30,y+13),2.3,g.PAINTS[int(appearance.paint)],0,int(appearance.rim),false,id,-1,.315,car,Vector2.ZERO,0,appearance)
func stats(car: Drivetrain,y: float) -> void:
	var values: Array = g.menu.hub.stats(car)
	for i in 4:
		g.box(Rect2(24+(i%2)*284,y+int(i/2)*82,268,70))
		t(values[i],42+(i%2)*284,y+44+int(i/2)*82,26)
func draw() -> void:
	if g.screen == "race": race(); return
	if g.screen == "results": results(); return
	if g.tab == "style": g.menu.customize.draw_portrait(); return
	if g.menu.hub.dyno_open: dyno(); return
	if g.tab == "performance" and not g.menu.hub.categories: upgrade(); return
	match g.tab:
		"garage": garage()
		"owned": owned()
		"performance": upgrades()
		"dealer": dealer()
		"races": races()
		"driver": driver()
	nav()
func garage() -> void:
	t("R /",24,45,27,g.ORANGE); t("REDLINE",84,43,24)
	t("$%d" % g.profile.credits,392,43,22,g.GREEN)
	var spec := GameCatalog.spec(g.profile.vehicle_id)
	t("YOUR GARAGE",24,103,16,g.MUTED)
	var size := 34
	while size > 22 and g.font.get_string_size(str(spec.name),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > 340: size -= 1
	g.fit_text(str(spec.name),24,150,340,size)
	b("hub_owned","Change car",Rect2(390,108,186,68))
	t(str(spec.engine)+"  /  "+str(spec.drive),24,193,21,g.MUTED)
	g.draw_workshop(Rect2(24,222,552,386))
	t(PerformanceClasses.label(g.profile),42,259,18,g.MUTED)
	g.draw_car(Vector2(30,370),2.3,g.PAINTS[g.profile.paint],0,g.profile.wheels,false,g.profile.vehicle_id,-1,.315,g.car)
	g.menu.hub.draw_stat_strip(Rect2(24,634,552,202),2)
	g.menu.hub.draw_race_action(Rect2(24,870,552,94))
	b("open_tuning","TUNING / TEST TRACK",Rect2(24,994,552,76))
	b("hub_upgrades","Upgrades",Rect2(24,990,264,68))
	b("hub_customize","Customize",Rect2(312,990,264,68))
func owned() -> void:
	var h: GarageHub = g.menu.hub
	if not g.profile.garage.has(h.owned_selection): h.owned_selection = g.profile.vehicle_id
	header("CHANGE CAR")
	b("hub_back","< Garage",Rect2(24,76,172,68))
	b("owned_filter","Class "+("All" if h.owned_filter==0 else PerformanceClasses.ORDER[h.owned_filter-1]),Rect2(208,76,172,68))
	b("owned_sort","Quickest" if h.owned_sort else "Order",Rect2(392,76,184,68))
	var ids: Array=h.owned_ids()
	if ids.is_empty(): t("No measured builds in class",24,230,23); return
	if not ids.has(h.owned_selection): h.owned_selection=str(ids[0])
	h.owned_page = clampi(h.owned_page,0,maxi(0,ceili(ids.size()/4.0)-1))
	preview(h.owned_selection,162,h.vehicle(h.owned_selection))
	var c := h.vehicle(h.owned_selection)
	t(str(GameCatalog.spec(h.owned_selection).name),24,434,26)
	t("VS ACTIVE  %+.0f HP / %+.0f NM / %+.0f KG" % [c.peak_horsepower()-g.car.peak_horsepower(),GarageHub.peak_torque(c)-GarageHub.peak_torque(g.car),c.mass()-g.car.mass()],24,473,17,g.MUTED)
	for i in mini(4,ids.size()-h.owned_page*4):
		var id: String = ids[h.owned_page*4+i]; var y := 498+i*94
		b("hub_pick_"+id,"",Rect2(24,y,552,84),false,h.owned_selection == id)
		g.draw_car(Vector2(27,y+9),.72,g.PAINTS[0],0,0,false,id,-1,.315,h.vehicle(id),Vector2.ZERO,0,g.profile.appearance_for(id))
		g.fit_text(str(GameCatalog.spec(id).name)+(" / ACTIVE" if id == g.profile.vehicle_id else ""),202,y+31,350,20)
		var v: Array = h.stats(h.vehicle(id)); t(v[0]+" / "+v[1],202,y+57,18,g.GREEN); t(v[2]+" / "+v[3],202,y+78,16,g.MUTED)
	b("hub_owned_prev","<",Rect2(24,888,136,68)); b("hub_owned_next",">",Rect2(440,888,136,68))
	t("%d / %d" % [h.owned_page+1,ceili(ids.size()/4.0)],266,930,22)
	b("hub_equip","ACTIVE CAR" if h.owned_selection == g.profile.vehicle_id else "DRIVE THIS CAR",Rect2(24,982,552,76),true)
func upgrades() -> void:
	g.menu.hub.studio.overview()

func dyno() -> void:
	g.glass.modal(g,Rect2(0,0,600,1300),g.profile.effects_quality)
	g.begin_sheet()
	g.box(Rect2(12,12,576,1230),Color("151e2bf5"),Color("ffffff29"))
	header("LIVE DYNO")
	b("hub_dyno_close","< RETURN",Rect2(24,80,552,72))
	b("hub_hp","HP "+("ON" if g.menu.hub.show_hp else "OFF"),Rect2(24,180,264,68),false,g.menu.hub.show_hp)
	b("hub_torque","NM "+("ON" if g.menu.hub.show_torque else "OFF"),Rect2(312,180,264,68),false,g.menu.hub.show_torque)
	var c: Drivetrain = g.menu.hub.preview()
	g.menu.hub.draw_graph(Rect2(82,332,460,360),g.car,c,20)
	t("HP",24,300,24,g.ORANGE); t("NM",100,300,24,g.GREEN)
	t("Solid: installed / Dashed: preview",24,790,21,g.MUTED)
	t("PEAK POWER  %d > %d HP" % [g.car.peak_horsepower(),c.peak_horsepower()],24,864,26,g.ORANGE)
	t("PEAK TORQUE  %.0f > %.0f NM" % [GarageHub.peak_torque(g.car),GarageHub.peak_torque(c)],24,922,25,g.GREEN)
	t("Crankshaft / full throttle / no nitrous",24,1000,21,g.MUTED)
	g.end_sheet()
func upgrade() -> void:
	g.menu.hub.studio.detail()

func stage_parts() -> void:
	g.menu.hub.studio.options(true); g.menu.hub.studio.comparison(true)
func hardware_parts() -> void:
	g.menu.hub.studio.options(true); g.menu.hub.studio.comparison(true)
func gearboxes() -> void:
	var w: UpgradeWorkshop = g.workshop
	for i in 4: b("tx_filter_%d" % i,["H MANUAL","PADDLE / SEQ","AUTOMATIC","DRAG AUTO"][i],Rect2(24+(i%2)*284,354+int(i/2)*76,268,68),false,w.filter_index == i)
	var ids := w.available_transmissions()
	w.page = clampi(w.page,0,maxi(0,ceili(ids.size()/4.0)-1))
	for i in mini(4,ids.size()-w.page*4):
		var id: String = ids[w.page*4+i]; var s := TransmissionCatalog.spec(id); var y := 514+i*82
		b("tx_pick_"+id,"",Rect2(24,y,552,74),false,w.selected_trans == id)
		t(str(s.name),40,y+30,22)
		var status := "INSTALLED" if id == str(g.profile.hardware.transmission) else ("OWNED" if g.profile.hardware.owned_transmissions.has(id) else "$%d" % int(s.cost))
		if not TransmissionCatalog.compatible(id,g.profile.vehicle_id): status = "INCOMPATIBLE"
		elif not g.profile.hardware.owned_transmissions.has(id) and g.profile.transmission_unlock_stage() < int(s.stage): status = TransmissionCatalog.STAGES[int(s.stage)]+" REQUIRED"
		t("%d GEARS / %s" % [s.ratios.size(),status],40,y+59,18,g.GREEN)
	b("tx_prev","<",Rect2(24,850,120,68)); b("tx_next",">",Rect2(456,850,120,68))
	b("details_toggle","Less" if w.details else "Details",Rect2(168,850,264,68))
	var s := TransmissionCatalog.spec(w.selected_trans)
	var stage := int(g.profile.stages[4]) if w.selected_trans == str(g.profile.hardware.transmission) else int(g.profile.hardware.performance_stages.get(w.selected_trans,0))
	var candidate: Drivetrain=g.menu.hub.studio.transmission_candidate()
	if not w.details:
		g.menu.hub.studio.fit(UpgradeStudio.metric("Shifts",g.car.shift_duration*1000,candidate.shift_duration*1000,"ms"),24,957,552,23,g.GREEN)
		g.menu.hub.studio.fit(UpgradeStudio.metric("Input rating",g.car.input_capacity(),candidate.input_capacity(),"Nm"),24,995,552,21,g.MUTED)
	else:
		var ratios: String=""
		for i in candidate.gear_ratios.size():
			ratios+="%d:%.2f  "%[i+1,candidate.gear_ratios[i]]
			if i==4: g.menu.hub.studio.fit(ratios,24,957,552,20,g.MUTED); ratios=""
		g.menu.hub.studio.fit(ratios,24,995 if candidate.gear_ratios.size()>5 else 957,552,20,g.MUTED)
	var owned: bool = g.profile.hardware.owned_transmissions.has(w.selected_trans)
	var blocked: bool = not TransmissionCatalog.compatible(w.selected_trans,g.profile.vehicle_id) or g.profile.transmission_unlock_stage() < int(s.stage)
	b("tx_buy","LOCKED" if blocked else ("INSTALL OWNED" if owned else ("BUY / $%d" % int(s.cost) if int(s.cost) <= g.profile.credits else g.missing_credits(int(s.cost)))),Rect2(24,1030,552,76),not blocked and (owned or int(s.cost) <= g.profile.credits))
func tuning() -> void:
	var w: UpgradeWorkshop = g.workshop; var keys: Array = GarageHub.TUNE_KEYS.get(g.menu.hub.selected,[])
	w.gear_index = clampi(w.gear_index,0,g.car.gear_ratios.size()-1)
	if g.menu.hub.selected == 7:
		b("tune_gear_prev","< GEAR",Rect2(24,354,264,68)); b("tune_gear_next","GEAR %d >" % (w.gear_index+1),Rect2(312,354,264,68))
	var values := {"launch_rpm":g.car.launch_rpm,"redline":g.car.redline_rpm,"boost":g.car.boost_target(g.car.redline_rpm,1),"nitrous_ramp":g.car._nitrous_ramp,"firmness":g.car.shift_firmness,"stall":g.car.converter_stall,"final_drive":g.car.final_drive,"ratio":g.car.gear_ratios[w.gear_index],"shift":g.car.shift_map[w.gear_index] if w.gear_index < g.car.shift_map.size() else 0}
	var labels := {"launch_rpm":"Launch RPM","redline":"Rev limiter","boost":"Boost / bar","nitrous_ramp":"Nitrous ramp / sec","firmness":"Shift firmness","stall":"Converter stall RPM","final_drive":"Final drive","ratio":"Gear ratio","shift":"Upshift RPM"}
	for i in keys.size():
		var key: String = keys[i]; var y := 454+i*124
		var enabled := w.tuning_enabled(key)
		var needs := {"launch_rpm":"Requires ECU","redline":"Requires ECU","boost":"Boost controller","nitrous_ramp":"Progressive kit","stall":"Converter kit","final_drive":"Final-drive kit","ratio":"Ratio cassette kit","shift":"Race controller","firmness":"Auto / DCT only"}
		if key=="boost" and g.profile.hardware.parts.values().has("boost_control") and not enabled: needs.boost="Inactive for belt drive" if g.car._supercharger!="" else "Turbo source required"
		t(str(labels[key]),24,y+24,23); t(w.tune_value(key,float(values[key])) if enabled else str(needs.get(key,"Hardware required")),24,y+64,20,g.GREEN if enabled else g.MUTED)
		b("tune_minus_"+key,"-",Rect2(312,y,120,76)); b("tune_plus_"+key,"+",Rect2(456,y,120,76))
	b("open_tuning","SAVED SETUPS / TEST TRACK",Rect2(24,830,552,70))
	for i in 3: b("preset_"+["street","drag","safe"][i],["STREET","DRAG","SAFE"][i],Rect2(24+i*184,930,172,68))
	if g.menu.hub.selected == 7: b("tune_reset","RESET SHIFT MAP",Rect2(24,1030,552,76))
func vehicle_test() -> void:
	var w: UpgradeWorkshop = g.workshop
	b("lab_run","RUN VEHICLE TEST",Rect2(24,218,552,76),true)
	if w.lab != null and not w.lab.done: t("TESTING...",24,370,28,g.GREEN); return
	if w.lab_result.is_empty(): t("0-60 / eighth / quarter / shifts",24,376,24,g.MUTED); return
	var rows := [["0-60 MPH",w.lab_result.zero_60_s],["0-100 MPH",w.lab_result.zero_100_s],["1/8 ET",w.lab_result.get("eighth_et_s",w.lab_result.eighth_s)],["1/4 ET",w.lab_result.get("quarter_et_s",w.lab_result.quarter_s)],["TRAP MPH",w.lab_result.trap_mph],["REACTION / ROLLOUT",w.lab_result.get("reaction_s",0)]]
	for i in rows.size():
		t(rows[i][0],24,390+i*90,23,g.MUTED); t("--" if rows[i][1] == null else "%.2f" % float(rows[i][1]),375,390+i*90,28,g.GREEN)
func dealer() -> void:
	var d: DealershipView = g.menu.dealer
	header("DEALERSHIP")
	if d.class_picker: d.draw_classes(true); return
	b("shop_classes","< Car classes",Rect2(24,80,552,68))
	t("CLASS "+d.CLASSES[d.class_filter]+" / "+d.CLASS_NAMES[d.class_filter-1],24,200,23,g.MUTED)
	var ids:=d.filtered()
	if ids.is_empty(): d.show_classes(); return
	var id: String = GameCatalog.CAR_IDS[g.dealer_index]
	if not ids.has(id): id = ids[0]; g.dealer_index = GameCatalog.CAR_IDS.find(id)
	d.page = int(ids.find(id)/4)
	var s := GameCatalog.spec(id); var c := d.factory(id)
	preview(id,246,c,VehicleAppearance.normalize({},2,0))
	g.fit_text(str(s.name),24,515,552,28); g.fit_text("CLASS "+PerformanceClasses.factory_class(id)+" / "+str(s.year)+" / "+str(s.engine),24,551,552,21,g.MUTED)
	stats(c,576)
	b("shop_car_prev","<",Rect2(24,756,120,68)); b("shop_car_next",">",Rect2(456,756,120,68))
	b("shop_details","LESS" if d.details else "DETAILS",Rect2(168,756,264,68))
	if d.details:
		t("%s / %d-SPEED %s" % [s.drive,c.gear_ratios.size(),c.transmission_kind.to_upper()],24,860,23,g.GREEN)
		t("%.0f kW ELECTRIC ASSIST / %.1f kWh" % [s.hybrid_kw,s.hybrid_kwh] if float(s.get("hybrid_kw",0))>0 else "%.0f MS SHIFT / %.0f NM RATING" % [c.shift_duration*1000,c.input_capacity()],24,901,21,g.MUTED)
	else:
		t("VS ACTIVE %+.0f HP / %+.0f KG" % [c.peak_horsepower()-g.car.peak_horsepower(),c.mass()-g.car.mass()],24,860,23,g.GREEN)
		var et := d.preview_estimate(id); t("1/4 EST %.2f S / %.1f MPH" % [et.time,et.mph] if not et.is_empty() else "MEASURING...",24,901,22,g.MUTED)
	var owned: bool = g.profile.garage.has(id); var locked: bool = not owned and g.profile.level() < int(s.get("unlock_level",1))
	var label: String = "LEVEL %d REQUIRED" % int(s.get("unlock_level",1)) if locked else ("DRIVING" if id == g.profile.vehicle_id else ("DRIVE THIS CAR" if owned else ("BUY / $%d" % int(s.price) if g.profile.credits >= int(s.price) else g.missing_credits(int(s.price)))))
	b("drive_car" if owned else "buy_car",label,Rect2(24,936,552,76),not locked and (owned or g.profile.credits >= int(s.price)))
	if not owned: b("shop_equip","EQUIP ON PURCHASE: "+("YES" if d.equip else "NO"),Rect2(24,1030,552,68))
func races() -> void:
	header("RACE BOARD")
	for i in 3:
		var x := 24+i*184
		var locked: bool = g.profile.level() < GameCatalog.CAREER_LEVELS[i]
		b("event_%d" % i,"",Rect2(x,80,172,80),false,g.event_index == i)
		t(["DOCKSIDE","MIDNIGHT","FINALS"][i],x+12,109,18,g.MUTED if locked else g.INK)
		t("LEVEL %d" % GameCatalog.CAREER_LEVELS[i] if locked else "%d / 5 WINS" % g.profile.career_wins[i],x+12,141,16,g.MUTED)
	var bot := GameCatalog.opponent(g.event_index,g.selected_opponent,g.profile)
	preview(str(bot.model),176,null,VehicleAppearance.normalize({},(g.event_index+g.selected_opponent+3)%6,2))
	t(str(bot.name),24,451,30)
	t(str(GameCatalog.spec(str(bot.model)).name),24,487,23,g.MUTED)
	var measured := RaceAI.request_estimate(bot)
	t("%d HP / 1/4 %.2f S" % [measured.hp,measured.time] if not measured.is_empty() else "MEASURING...",24,530,25,g.GREEN)
	g.fit_text(str(bot.get("race_class","OPEN"))+" / "+g.distance_label(float(bot.distance))+" / WIN $%d / FINISH $%d" % [bot.purse,int(float(bot.purse)*.4)],24,570,552,21)
	for i in 5: b("bot_%d" % i,str(i+1) if i <= mini(4,int(g.profile.career_wins[g.event_index])) else "-",Rect2(24+i*112,600,104,68),false,i == g.selected_opponent)
	b("recommend_rival","FINDING..." if g.recommend_pending else "FIND MATCH",Rect2(24,692,552,68))
	t("WAGER  $%d" % g.wager,24,812,30)
	b("bet_less","-",Rect2(312,774,120,68)); b("bet_more","+",Rect2(456,774,120,68))
	var maximum := mini(g.profile.credits,int(bot.max_bet))
	var fraction := float(g.wager)/maxf(1,maximum)
	g.draw_rect(Rect2(38,897,524,4),g.EDGE); g.draw_rect(Rect2(38,897,524*fraction,4),g.ORANGE)
	g.draw_circle(Vector2(38+524*fraction,899),11,g.INK)
	g.buttons.append({"id":"bet_slider","rect":Rect2(24,852,552,64),"range":Vector2(38,562)})
	t("WIN +$%d" % g.wager,24,941,21,g.GREEN)
	t("LOSE -$%d" % g.wager,24,976,21,g.MUTED)
	b("bet_clear","No wager",Rect2(312,928,264,64))
	var locked: bool = g.profile.level() < GameCatalog.CAREER_LEVELS[g.event_index]
	b("race","LEVEL %d REQUIRED" % GameCatalog.CAREER_LEVELS[g.event_index] if locked else "Race  >",Rect2(24,1000,552,88),not locked)
func driver() -> void:
	header("DRIVER")
	t("LEVEL %02d" % g.profile.level(),24,177,46,g.GREEN)
	t("%d XP TO NEXT LEVEL" % (g.profile.next_level_xp()-g.profile.xp),24,233,24,g.MUTED)
	t("%d WINS / %d RACES" % [g.profile.wins,g.profile.races],24,341,29)
	t("BEST 1/4 TOTAL  "+("--" if g.profile.best <= 0 else "%.3f S" % g.profile.best),24,410,28)
	for i in 3: t(GameCatalog.CAREER_NAMES[i]+"  %d / 5" % g.profile.career_wins[i],24,515+i*74,24,g.GREEN if g.profile.level() >= GameCatalog.CAREER_LEVELS[i] else g.MUTED)
	b("effects_quality","EFFECTS: "+["LOW","MEDIUM","HIGH"][g.profile.effects_quality],Rect2(24,832,552,76))
	b("sound","SOUND OFF" if g.profile.muted else "SOUND ON",Rect2(24,934,552,76))
	b("reduced_motion","MOTION: REDUCED" if g.profile.reduced_motion else "MOTION: FULL",Rect2(24,1032,552,76))
func results() -> void:
	header("RED LIGHT" if g.staging.red_light else ("VICTORY" if g.result_win else "RACE COMPLETE"))
	t(g.distance_label(g.active_distance),24,112,24,g.GREEN)
	preview(g.profile.vehicle_id,146,g.car)
	var net: int = g.result_reward-g.active_stake
	var rt := ("RED " if g.staging.red_light else "")+"%.3f S" % g.player_reaction if g.staging.released[0] else "--"
	var pairs := [["ELAPSED / ET","%.3f S" % g.staging.elapsed(g.player_finish)],["REACTION",rt],["TRAP SPEED","%.1f MPH" % g.finish_speed],["RIVAL / ET","%.3f S" % g.staging.elapsed(g.rival_finish,1)],["RIVAL TRAP","%.1f MPH" % g.rival_trap_speed],["RACE PAY","+$%d" % g.result_base_pay],["BET RETURN","$%d" % g.result_bet_return],["NET CASH",("+$" if net>=0 else "-$")+str(absi(net))],["XP","+%d" % g.result_xp]]
	for i in pairs.size(): t(pairs[i][0],24,430+i*44,22,g.MUTED); t(pairs[i][1],360,430+i*44,23,g.GREEN)
	b("results_upgrades","UPGRADES",Rect2(24,838,264,76)); b("garage","GARAGE",Rect2(312,838,264,76))
	b("retry","REMATCH",Rect2(24,936,552,76))
	b("next_rival","NEXT RACE",Rect2(24,1032,552,88),true)
func race() -> void:
	g.race_hud.draw(true)
