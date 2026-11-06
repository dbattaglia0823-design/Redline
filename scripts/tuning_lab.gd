class_name TuningLab
extends RefCounted

var g: Node2D
var page := "setup"
var group := 0
var row_page := 0
var gear := 0
var length := 402.336
var return_tab := "garage"
var slot := "street"
var optimizer: TuneOptimizer
var preview: VehicleBench
var preview_base: VehicleBench
var preview_base_result: Dictionary = {}
var preview_result: Dictionary = {}
var preview_key := ""
var histories: Dictionary = {}
var last: Dictionary = {}
var details := false
var channel := "speed"
var cursor := 0
var drag_pointer := ""
var graph_rect := Rect2()
var name_edit: LineEdit
var gearbox_panel: GearboxTuningPanel
const SLOTS := ["street","eighth","quarter","custom"]
const SLOT_NAMES := ["Street","1/8 Mile","1/4 Mile","Custom"]
const LABELS := {"gear_count":"Forward gears","launch_rpm":"Launch RPM","redline":"Rev limiter","boost":"Maximum boost / bar","boost_gear":"Gear boost cap / bar","firmness":"Shift firmness","final_drive":"Final drive","ratio":"Gear ratio","shift":"Upshift RPM"}

func _init(game: Node2D) -> void: g=game
func text(s: String,x: float,y: float,n: int = 18,c: Color = GlassPalette.INK) -> void: g.text_at(s,x,y,n,c)
func short_layout() -> bool: return g.race_touch_layout() and not g.is_portrait()
func rows_per_page() -> int: return 2 if short_layout() else 4
func button(id: String,s: String,r: Rect2,primary: bool = false,selected: bool = false) -> void:
	if short_layout(): g.race_hud.control(id,s,r,"",primary,selected,g.action_enabled(id))
	else: g.button(id,s,r,primary,selected)
func open(initial_group: int = -1) -> void:
	if initial_group>=0: group=initial_group; row_page=0; gear=0
	return_tab=g.tab if g.tab!="tuning" else return_tab
	last=histories.get(g.profile.vehicle_id+":"+str(length),{}).get("last",{})
	g.tab="tuning"; page="setup"; g.menu_dirty=true
func update() -> void:
	if preview!=null and preview_key!=TuneOptimizer.signature(g.profile)+JSON.stringify(g.profile.tuning_presets().get(slot,{})):
		preview=null; preview_base=null; preview_result.clear(); preview_base_result.clear(); g.menu_dirty=true
	if optimizer!=null and not optimizer.done and not optimizer.cancelled:
		if optimizer.source!=TuneOptimizer.signature(g.profile): optimizer.cancelled=true
		else: optimizer.advance(); g.menu_dirty=true
	if preview_base!=null and not preview_base.done:
		preview_base.step_budget(600); g.menu_dirty=true
		if preview_base.done: preview_base_result=preview_base.result.duplicate(true)
	elif preview!=null and not preview.done:
		preview.step_budget(600); g.menu_dirty=true
		if preview.done: preview_result=preview.result.duplicate(true)

func draw() -> void:
	var p: bool=g.is_portrait()
	var width := 600 if p else 1200
	g.draw_header() if not p else g.mobile.header("TUNING & TEST TRACK")
	if not p: text("TUNING & TEST TRACK",36,122,26)
	g.fit_text(str(GameCatalog.spec(g.profile.vehicle_id).name),164 if p else 38,116 if p else (145 if short_layout() else 153),412 if p else 900,22 if p else 16,g.MUTED)
	button("tt_back","< Back",Rect2(24,82,126,64) if p else Rect2(952,64,214,90) if short_layout() else Rect2(1010,92,156,48))
	if g.screen=="practice_results": page="results"
	var tabs := ["setup","presets","optimize","results"]
	for i in 4:
		button("tt_page_"+tabs[i],["Tune","Presets","Optimize","Run data"][i],Rect2(24+i*140,166,132,64) if p else Rect2(36+i*285,158,272,90) if short_layout() else Rect2(36+i*285,182,272,48),false,page==tabs[i])
	match page:
		"setup": draw_setup(p)
		"presets": draw_presets(p)
		"optimize": draw_optimizer(p)
		"results": draw_results(p)
	if g.screen!="practice_results":
		var y := 1050 if p else (690 if page=="setup" and TuningSetup.GROUPS.keys()[group]=="Gearbox" and not short_layout() else (650 if short_layout() and page=="results" and details else 612))
		button("tt_distance","1/8 MILE" if length<300 else "1/4 MILE",Rect2(24,y,188,76) if p else Rect2(36,y,174,90 if short_layout() else 52))
		button("tt_drive","DRIVE TEST TRACK",Rect2(224,y,352,76) if p else Rect2(224,y,350,90 if short_layout() else 52),true)
		if not p: text("Practice only / no wagers, rewards or career changes",600,y+33,15,g.MUTED)
		else: text("Practice / no stakes or career changes",24,y+110,20,g.MUTED)
	else:
		button("tt_drive","TEST AGAIN",Rect2(24,1140,264,76) if p else Rect2(36,650,270,90) if short_layout() else Rect2(36,670,270,60),true)
		button("tt_return","BACK TO TUNING",Rect2(312,1140,264,76) if p else Rect2(320,650,270,90) if short_layout() else Rect2(320,670,270,60))
	if name_edit!=null:
		g.draw_rect(Rect2(0,0,width,1300 if p else 760),Color(0,0,0,.85)); g.buttons.clear()
		text("NAME THIS SETUP",24 if p else 350,484 if p else 274,24)
		button("tt_name_save","SAVE NAME",Rect2(24,620,264,76) if p else Rect2(350,410,242,90) if short_layout() else Rect2(350,380,242,60),true)
		button("tt_name_cancel","CANCEL",Rect2(312,620,264,76) if p else Rect2(608,410,242,90) if short_layout() else Rect2(608,380,242,60))

func draw_setup(p: bool) -> void:
	var groups: Array=TuningSetup.GROUPS.keys()
	for i in groups.size():
		button("tt_group_%d"%i,(["Launch","Power","Gears","Clutch","Grip"][i] if short_layout() else str(groups[i])),Rect2(24+(i%3)*188,250+int(i/3)*68,176,60) if p else Rect2(36+(i%2)*102,252+int(i/2)*102,90,90) if short_layout() else Rect2(36,i*54+252,186,46),false,group==i)
	if groups[group]=="Gearbox":
		if gearbox_panel==null:
			gearbox_panel=GearboxTuningPanel.new(); g.add_child(gearbox_panel); gearbox_panel.setup(self)
		gearbox_panel.visible=true; gearbox_panel.sync()
		return
	var keys: Array=TuningSetup.GROUPS[groups[group]]
	row_page=clampi(row_page,0,maxi(0,ceili(keys.size()/float(rows_per_page()))-1))
	gear=clampi(gear,0,g.car.gear_ratios.size()-1); g.workshop.gear_index=gear
	var top := 430 if p else 252
	var x := 24 if p else 250
	g.box(Rect2(x,top,552 if p else 916,590 if p else 336))
	if groups[group] in ["Power","Gearbox"]:
		button("tt_gear_prev","<",Rect2(x+16,top+12,64,60) if p else Rect2(x+530,top+8,90,90) if short_layout() else Rect2(x+530,top+8,64,44))
		button("tt_gear_next","GEAR %d >"%(gear+1),Rect2(x+96,top+12,190,60) if p else Rect2(x+632,top+8,260,90) if short_layout() else Rect2(x+608,top+8,284,44))
	else: text(str(groups[group])+" / installed hardware",x+20,top+35,22 if p else 18,g.MUTED)
	for row in rows_per_page():
		var index:=row_page*rows_per_page()+row
		if index>=keys.size(): break
		var key: String=keys[index]
		var enabled:=reason(key)==""
		var y:=top+(98+row*112 if p else (130+row*110 if short_layout() else 78+row*61))
		var label: String=LABELS.get(key,TuningSetup.EXTRA.get(key,[key])[0])
		text(label,x+20,y,22 if p else 17)
		var shown: String=display_value(key) if enabled else reason(key)
		g.fit_text(shown,x+20,y+30,312 if p else 590,18 if p else 14,g.GREEN if enabled else g.MUTED)
		var plus:=Rect2(x+432,y-18,96,76) if p else Rect2(x+804,y-23,96,90) if short_layout() else Rect2(x+812,y-23,80,48)
		var minus:=Rect2(x+324,y-18,96,76) if p else Rect2(x+696,y-23,96,90) if short_layout() else Rect2(x+720,y-23,80,48)
		button("tt_minus_"+key,"-",minus,false)
		button("tt_plus_"+key,"+",plus,enabled)
		for target in ["tt_minus_"+key,"tt_plus_"+key]:
			g.buttons[-1 if target.begins_with("tt_plus_") else -2].disabled=not g.action_enabled(target)
	if keys.size()>rows_per_page(): button("tt_rows","Settings %d/%d >"%[row_page+1,ceili(keys.size()/float(rows_per_page()))],Rect2(x+20,top+510,280,60) if p else Rect2(x+280,top+8,230,90 if short_layout() else 44))

func set_gear_count(count: int) -> void:
	if g.profile.tune_hardware("gear_count",count): g.refresh_car(); g.menu_dirty=true

func reason(key: String) -> String:
	if TuningSetup.EXTRA.has(key) or key=="boost_gear":
		var b: Dictionary=g.profile.hardware.duplicate(true); b.turbo_stage=g.car.turbo_stage
		return TuningSetup.reason(key,b,g.car.gearbox_stage,g.profile.vehicle_id)
	if key=="gear_count" or (key=="launch_rpm" and g.car.transmission_kind=="drag"): return ""
	return "" if g.workshop.tuning_enabled(key) else {"shift":"Select a gear with an upshift","boost":"Turbocharger required","launch_rpm":"ECU required","redline":"Programmable ECU or higher required","firmness":"Automatic or DCT required"}.get(key,"Compatible hardware required")

func value(key: String) -> Variant:
	var c: Drivetrain=g.car
	var values := {"launch_rpm":c.launch_rpm,"redline":c.redline_rpm,"boost":c.boost_target(c.redline_rpm,1),"firmness":c.shift_firmness,"final_drive":c.final_drive,"ratio":c.gear_ratios[gear],"shift":c.shift_map[gear] if gear<c.shift_map.size() else 0,"boost_gear":c.boost_by_gear[gear] if gear<c.boost_by_gear.size() else c.boost_target(c.redline_rpm,1)}
	if values.has(key): return values[key]
	return g.profile.hardware.tune.get(key,TuningSetup.EXTRA[key][4])

func display_value(key: String) -> String:
	var v:=float(value(key))
	if key=="launch_enabled": return "ON" if v>.5 else "OFF"
	if key=="tc_slip" and v==0: return "OFF"
	if key in ["launch_rpm","redline","shift"]: return "%.0f RPM"%v
	return "%.2f"%v+ (" "+str(TuningSetup.EXTRA[key][5]) if TuningSetup.EXTRA.has(key) else "")

func change(key: String,dir: float) -> void:
	if reason(key)!="": return
	if key=="gear_count":
		var limits:=TransmissionCatalog.gear_range(g.car.transmission_id)
		set_gear_count(clampi(g.car.gear_ratios.size()+int(dir),limits.x,limits.y))
		return
	if TuningSetup.EXTRA.has(key):
		var row: Array=TuningSetup.EXTRA[key]
		g.profile.tune_hardware(key,float(value(key))+dir*float(row[3]))
	elif key=="boost_gear":
		var caps: Array=[]
		for i in g.car.gear_ratios.size(): caps.append(g.car.boost_by_gear[i] if i<g.car.boost_by_gear.size() else g.car.boost_target(g.car.redline_rpm,1))
		caps[gear]=maxf(0,float(caps[gear])+dir*.1); g.profile.tune_hardware("boost_by_gear",caps)
	else: g.workshop.change_tune(key,dir); return
	g.refresh_car()

func draw_presets(p: bool) -> void:
	var saved: Dictionary=g.profile.tuning_presets()
	for i in 4:
		var y:=254+i*(142 if p else 78)
		var label: String=str(saved.get(SLOTS[i],{}).get("name",SLOT_NAMES[i]))
		button("tt_slot_"+SLOTS[i],label+(" / empty" if not saved.has(SLOTS[i]) else ""),Rect2(24,y,552,70) if p else Rect2(36+(i%2)*204,254+int(i/2)*102,192,90) if short_layout() else Rect2(36,y,400,66),false,slot==SLOTS[i])
		if p and slot==SLOTS[i]: g.fit_text(g.profile.tune_slot_reason(slot),36,y+103,520,19,g.MUTED)
	var y := 850 if p else 266
	button("tt_save","SAVE CURRENT",Rect2(24,y,264,76) if p else Rect2(470,y,220,90 if short_layout() else 52),true)
	button("tt_load","LOAD PRESET",Rect2(312,y,264,76) if p else Rect2(704,y,220,90 if short_layout() else 52))
	button("tt_rename","RENAME",Rect2(24,y+90,264,76) if p else Rect2(470,y+(110 if short_layout() else 70),220,90 if short_layout() else 52))
	button("tt_preview","MEASURE PRESET",Rect2(312,y+90,264,76) if p else Rect2(704,y+(110 if short_layout() else 70),220,90 if short_layout() else 52))
	if not p: g.fit_text(g.profile.tune_slot_reason(slot),470,505 if short_layout() else 423,660,17,g.MUTED)
	if not preview_result.is_empty():
		var metric: String="eighth_et_s" if length<300 else "quarter_et_s"
		g.fit_text("Current "+fmt(preview_base_result.get(metric))+" / saved "+fmt(preview_result.get(metric)),470 if not p else 24,(562 if short_layout() else 478) if not p else 1022,650 if not p else 552,20,g.GREEN)
	elif preview!=null and not preview.done: text("Measuring saved setup...",470 if not p else 24,(562 if short_layout() else 478) if not p else 1022,20,g.MUTED)

func draw_optimizer(p: bool) -> void:
	text("SIMULATION-BASED RECOMMENDATIONS",24 if p else 36,285 if short_layout() else 292,23 if p else 26)
	if not short_layout(): g.fit_text("Competent driver / current hardware / selected distance",24 if p else 36,334,552 if p else 1000,20 if p else 17,g.MUTED)
	button("tt_optimize","FIND SETUP",Rect2(24,375,264,76) if p else Rect2(36,300,270,90) if short_layout() else Rect2(36,375,270,58),true)
	button("tt_opt_apply","APPLY RESULT",Rect2(312,375,264,76) if p else Rect2(322,300,270,90) if short_layout() else Rect2(322,375,270,58))
	button("tt_opt_cancel","CANCEL",Rect2(24,470,264,68) if p else Rect2(608,300,180,90) if short_layout() else Rect2(608,375,180,58))
	button("tt_restore","FACTORY TUNING",Rect2(312,470,264,68) if p else Rect2(802,300,364,90) if short_layout() else Rect2(802,375,364,58))
	if optimizer==null: return
	var y:=600 if p else (445 if short_layout() else 485)
	text("Stopped / build changed" if optimizer.cancelled else ("Search complete" if optimizer.done else "Testing candidate %d"%(optimizer.attempts.size()+1)),24 if p else 36,y,24,g.GREEN)
	if not optimizer.best.is_empty():
		text("Baseline  "+fmt(optimizer.score(optimizer.baseline))+"   Best  "+fmt(optimizer.score(optimizer.best)),24 if p else 36,y+48,22)
		text("%d simulated trials / %.3f s improvement"%[optimizer.attempts.size(),maxf(0,optimizer.score(optimizer.baseline)-optimizer.score(optimizer.best))],24 if p else 36,y+92,18,g.MUTED)
	if p or short_layout(): text("A bounded search, not a universal optimum.",24 if p else 36,y+140,18,g.MUTED)

func fmt(v: Variant) -> String: return "--" if v==null or not is_finite(float(v)) else "%.3f s"%float(v)

func draw_results(p: bool) -> void:
	if last.is_empty(): text("Complete a test-track run to review data.",24 if p else 36,294,23,g.MUTED); return
	var m: Dictionary=last.metrics
	text("RED LIGHT / not ranked" if m.red_light else "TEST RUN / BEAM ELAPSED TIMES",24 if p else 36,273,21,g.ORANGE if m.red_light else g.GREEN)
	var pairs := [["REACTION",fmt(m.reaction_s)],["60 FT",fmt(m.sixty_ft_s)],["1/8 ET",fmt(m.eighth_s)],["1/8 TRAP","--" if m.eighth_mph==null else "%.1f mph"%float(m.eighth_mph)],["1/4 ET",fmt(m.quarter_s)],["1/4 TRAP","--" if m.trap_mph==null else "%.1f mph"%float(m.trap_mph)],["0-60 / FROM BEAM",fmt(m.zero_60_s)],["GREEN TOTAL",fmt(m.total_s)]]
	for i in (0 if details else pairs.size()):
		var x:=24+(i%2)*284 if p else 36+(i%4)*285
		var y:=314+int(i/2)*70 if p else 316+int(i/4)*72
		text(pairs[i][0],x,y,16 if p else 12,g.MUTED); text(pairs[i][1],x,y+28,25 if p else 24)
	var record: Dictionary=histories.get(str(last.get("key","")),{})
	var marker: String="eighth_s" if float(m.distance)<300 else "quarter_s"
	var previous: Variant=record.get("previous",{}).get("metrics",{}).get(marker)
	var best: Variant=record.get("best",{}).get("metrics",{}).get(marker)
	if not details: text("Previous "+fmt(previous)+" / Session best "+fmt(best),24 if p else 36,610 if p else 455,19,g.MUTED)
	button("tt_details","HIDE TELEMETRY" if details else "TELEMETRY DETAILS",Rect2(24,650 if not details else 828,552,68) if p else Rect2(820,426 if not details else 254,346,90 if short_layout() else 48),false,details)
	if details: draw_graph(p)

func draw_graph(p: bool) -> void:
	var channels:= ["speed","rpm","wheelspin","throttle","boost"]
	for i in channels.size(): button("tt_channel_"+channels[i],channels[i].capitalize(),Rect2(24+i*112,330,104,62) if p else Rect2(36+i*144,312,134,90 if short_layout() else 42),false,channel==channels[i])
	graph_rect=Rect2(24,420,552,380) if p else Rect2(36,424,1130,140) if short_layout() else Rect2(36,376,1130,180)
	var data: Array=last.samples
	if data.is_empty(): return
	g.box(graph_rect)
	for i in range(1,4): g.draw_line(graph_rect.position+Vector2(0,graph_rect.size.y*i/4),Vector2(graph_rect.end.x,graph_rect.position.y+graph_rect.size.y*i/4),Color(GlassPalette.BLUE,.12),1,true)
	var maximum:=1.0
	for row in data: maximum=maxf(maximum,float(row[channel]))
	text("%.1f"%maximum,graph_rect.position.x+8,graph_rect.position.y+20,18 if p else 13,g.MUTED)
	var points:=PackedVector2Array()
	var duration: float=maxf(.001,float(data[-1].time))
	for row in data: points.append(graph_rect.position+Vector2(float(row.time)/duration*graph_rect.size.x,graph_rect.size.y*(1-float(row[channel])/maximum)))
	if points.size()>1: g.draw_polyline(points,g.ORANGE,2,true)
	for shift in last.shifts:
		var sx:=graph_rect.position.x+float(shift.time)/duration*graph_rect.size.x
		g.draw_line(Vector2(sx,graph_rect.position.y+26),Vector2(sx,graph_rect.end.y),Color(g.GREEN,.17),1,true)
		text(str(shift.gear),sx+3,graph_rect.position.y+40,16 if p else 12,g.GREEN)
	text("0 s",graph_rect.position.x+8,graph_rect.end.y-7,16 if p else 12,g.MUTED)
	text("%.1f s"%duration,graph_rect.end.x-60,graph_rect.end.y-7,16 if p else 12,g.MUTED)
	cursor=clampi(cursor,0,data.size()-1)
	var chosen: Dictionary=data[cursor]
	var x:=graph_rect.position.x+float(chosen.time)/duration*graph_rect.size.x
	g.draw_line(Vector2(x,graph_rect.position.y),Vector2(x,graph_rect.end.y),GlassPalette.BLUE,1,true)
	g.buttons.append({"id":"tt_seek","rect":graph_rect})
	if p:
		text("%.2fs / %.0f rpm / %.1f mph / gear %d"%[chosen.time,chosen.rpm,chosen.speed,chosen.gear],24,930,20)
		text("Pedal %.2f / clutch %.2f / slip %.2f"%[chosen.throttle,chosen.clutch,chosen.wheelspin],24,962,20,g.MUTED)
		text("Boost %.2f bar / distance %.1f m"%[chosen.boost,chosen.distance],24,994,20,g.MUTED)
		text("Acceleration %.2f m/s2 / green-clock time"%chosen.acceleration,24,1026,19,g.MUTED)
	elif short_layout():
		text("%.2fs / %.0f rpm / %.1f mph / gear %d / %.1f m"%[chosen.time,chosen.rpm,chosen.speed,chosen.gear,chosen.distance],36,600,24)
		text("Pedal %.2f / clutch %.2f / slip %.2f / boost %.2f bar / accel %.1f m/s2"%[chosen.throttle,chosen.clutch,chosen.wheelspin,chosen.boost,chosen.acceleration],36,632,22,g.MUTED)
	else: g.fit_text("%.2fs / %.0f rpm / %.1f mph / gear %d / pedal %.2f / clutch %.2f / slip %.2f / boost %.2f / %.1fm / %.1fm/s2"%[chosen.time,chosen.rpm,chosen.speed,chosen.gear,chosen.throttle,chosen.clutch,chosen.wheelspin,chosen.boost,chosen.distance,chosen.acceleration],36,590,1130,14,g.MUTED)

func receive_run(recorder: RunTelemetry) -> void:
	last=recorder.snapshot(); last.key=g.profile.vehicle_id+":"+str(recorder.distance)
	last.build=TuneOptimizer.signature(g.profile)
	var key: String=last.key
	var old: Dictionary=histories.get(key,{})
	var best: Dictionary=old.get("best",{})
	var metric: String="eighth_s" if recorder.distance<300 else "quarter_s"
	if not last.metrics.red_light and last.metrics[metric]!=null and (best.is_empty() or float(last.metrics[metric])<float(best.metrics[metric])): best=last.duplicate(true)
	histories[key]={"last":last.duplicate(true),"previous":old.get("last",{}),"best":best}
	if histories.size()>12: histories.erase(histories.keys()[0])
	page="results"; details=false; cursor=0

func seek(x: float) -> void:
	if last.is_empty() or last.samples.is_empty(): return
	cursor=roundi(clampf((x-graph_rect.position.x)/maxf(1,graph_rect.size.x),0,1)*(last.samples.size()-1)); g.menu_dirty=true

func handle_input(event: InputEvent) -> bool:
	if gearbox_panel!=null and gearbox_panel.route_input(event): return true
	if name_edit!=null and name_edit.has_focus() and event is InputEventKey:
		if event.pressed and event.keycode==KEY_ESCAPE: name_edit.queue_free(); name_edit=null; g.menu_dirty=true
		return true
	if drag_pointer=="": return false
	if event is InputEventScreenDrag and drag_pointer=="touch_%d"%event.index: seek(g.to_local(event.position).x); return true
	if event is InputEventMouseMotion and drag_pointer.begins_with("mouse_"): seek(g.to_local(event.position).x); return true
	if event is InputEventScreenTouch and drag_pointer=="touch_%d"%event.index and (not event.pressed or event.canceled): drag_pointer=""; return true
	if event is InputEventMouseButton and not event.pressed: drag_pointer=""; return true
	return false

func action(id: String) -> void:
	if id=="tt_back" or id=="tt_return":
		if name_edit!=null: name_edit.queue_free(); name_edit=null
		if g.screen=="practice_results": g.screen="garage"; g.practice_mode=false; g.tab="tuning"; page="setup"
		elif page!="setup": page="setup"
		else: g.tab=return_tab
	elif id=="tt_drive": g.start_practice(length)
	elif id=="tt_distance":
		length=201.168 if length>300 else 402.336; preview=null; preview_base=null; preview_result.clear(); optimizer=null
		last=histories.get(g.profile.vehicle_id+":"+str(length),{}).get("last",{})
	elif id.begins_with("tt_page_"):
		if g.screen=="practice_results": g.screen="garage"; g.practice_mode=false; g.tab="tuning"
		page=id.trim_prefix("tt_page_")
	elif id.begins_with("tt_group_"): group=int(id.trim_prefix("tt_group_")); row_page=0
	elif id=="tt_rows": row_page=(row_page+1)%ceili(TuningSetup.GROUPS[TuningSetup.GROUPS.keys()[group]].size()/float(rows_per_page()))
	elif id=="tt_gear_prev": gear=maxi(0,gear-1)
	elif id=="tt_gear_next": gear=mini(g.car.gear_ratios.size()-1,gear+1)
	elif id.begins_with("tt_plus_"): change(id.trim_prefix("tt_plus_"),1)
	elif id.begins_with("tt_minus_"): change(id.trim_prefix("tt_minus_"),-1)
	elif id.begins_with("tt_slot_"): slot=id.trim_prefix("tt_slot_"); preview=null; preview_result.clear()
	elif id=="tt_save": g.profile.save_tune_slot(slot,SLOT_NAMES[SLOTS.find(slot)]); g.show_toast("Tune saved for this vehicle")
	elif id=="tt_load":
		if g.profile.load_tune_slot(slot): g.refresh_car(); g.show_toast("Tune installed")
		else: g.show_toast(g.profile.tune_slot_reason(slot))
	elif id=="tt_rename":
		if not g.profile.tuning_presets().has(slot): g.show_toast("Save this slot first"); return
		if name_edit!=null: name_edit.queue_free()
		name_edit=LineEdit.new(); g.add_child(name_edit); name_edit.position=Vector2(24,530) if g.is_portrait() else Vector2(350,300); name_edit.size=Vector2(552,68) if g.is_portrait() else Vector2(500,90 if short_layout() else 56)
		name_edit.theme=LiquidGlass.THEME; name_edit.add_theme_font_size_override("font_size",24); name_edit.max_length=28; name_edit.text=str(g.profile.tuning_presets()[slot].name); name_edit.grab_focus(); name_edit.select_all()
		name_edit.text_submitted.connect(func(label: String): g.profile.rename_tune_slot(slot,label); name_edit.queue_free(); name_edit=null; g.menu_dirty=true)
	elif id=="tt_name_save" and name_edit!=null:
		g.profile.rename_tune_slot(slot,name_edit.text); name_edit.queue_free(); name_edit=null
	elif id=="tt_name_cancel" and name_edit!=null: name_edit.queue_free(); name_edit=null
	elif id=="tt_preview":
		if g.profile.tune_slot_reason(slot)!="": g.show_toast(g.profile.tune_slot_reason(slot)); return
		var b: Dictionary=g.profile.hardware.duplicate(true); b.tune=g.profile.tuning_presets()[slot].tune.duplicate(true)
		preview_key=TuneOptimizer.signature(g.profile)+JSON.stringify(g.profile.tuning_presets().get(slot,{}))
		preview_base=VehicleBench.new(); preview_base.begin(GameCatalog.spec(g.profile.vehicle_id),g.profile.stages,g.profile.hardware); preview_base_result.clear()
		preview=VehicleBench.new(); preview.begin(GameCatalog.spec(g.profile.vehicle_id),g.profile.stages,b); preview_result.clear()
	elif id=="tt_optimize": optimizer=TuneOptimizer.new(); optimizer.begin(g.profile,length)
	elif id=="tt_opt_cancel" and optimizer!=null: optimizer.cancelled=true
	elif id=="tt_opt_apply" and optimizer!=null:
		if optimizer.apply(g.profile): g.refresh_car(); g.show_toast("Measured recommendation applied")
		else: g.show_toast("Complete a search on the current build first")
	elif id=="tt_restore": g.profile.hardware.tune.clear(); g.profile.save(); g.refresh_car(); g.show_toast("Installed hardware / factory tuning restored")
	elif id=="tt_details": details=not details
	elif id.begins_with("tt_channel_"): channel=id.trim_prefix("tt_channel_")
	g.menu_dirty=true

func enabled(id: String) -> bool:
	if id.begins_with("tt_plus_") or id.begins_with("tt_minus_"):
		var key:=id.trim_prefix("tt_plus_").trim_prefix("tt_minus_")
		if reason(key)!="": return false
		if key=="gear_count":
			var limits:=TransmissionCatalog.gear_range(g.car.transmission_id)
			return g.car.gear_ratios.size()<limits.y if id.begins_with("tt_plus_") else g.car.gear_ratios.size()>limits.x
		if TuningSetup.EXTRA.has(key):
			var row: Array=TuningSetup.EXTRA[key]
			return float(value(key))<float(row[2])-.0001 if id.begins_with("tt_plus_") else float(value(key))>float(row[1])+.0001
		if key=="boost_gear": return float(value(key))<VehicleParts.boost_control_limit(g.profile.hardware,g.car.base_boost,g.car.turbo_stage)-.0001 if id.begins_with("tt_plus_") else float(value(key))>.0001
		return g.action_enabled(id.replace("tt_plus_","tune_plus_").replace("tt_minus_","tune_minus_"))
	if id=="tt_gear_prev": return gear>0
	if id=="tt_gear_next": return gear<g.car.gear_ratios.size()-1
	if id in ["tt_load","tt_preview"]: return g.profile.tune_slot_reason(slot)==""
	if id=="tt_rename": return g.profile.tuning_presets().has(slot)
	if id=="tt_restore": return not g.profile.hardware.tune.is_empty()
	if id=="tt_optimize": return optimizer==null or optimizer.done or optimizer.cancelled
	if id=="tt_opt_cancel": return optimizer!=null and not optimizer.done and not optimizer.cancelled
	if id=="tt_opt_apply": return optimizer!=null and optimizer.done and not optimizer.cancelled and optimizer.source==TuneOptimizer.signature(g.profile) and is_finite(optimizer.score(optimizer.best))
	return true
