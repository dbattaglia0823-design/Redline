class_name TestResultsPanel
extends Control
var lab: TuningLab
var g: Node2D
var scroll: ScrollContainer
var content: VBoxContainer
var targets: Dictionary={}
var plots: Array[TelemetryPlot]=[]
var sample_label: Label
var a: Dictionary={}
var b: Dictionary={}
var pool: Array=[]
var index_a := 0
var index_b := 1
var selection_key := ""
var cached_state := ""
var pointer := -1
var touch_start := Vector2.ZERO
var scroll_start := 0
var touch_button: Button
var active_plot: TelemetryPlot
var cursor_time := 0.0
var plot_group: Container

func setup(tuning: TuningLab) -> void:
	lab=tuning; g=lab.g; name="TestResults"; theme=LiquidGlass.THEME
	mouse_filter=Control.MOUSE_FILTER_STOP
	scroll=ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; add_child(scroll)
	content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",12); scroll.add_child(content)
	visible=false
func _process(_dt: float) -> void:
	visible=lab.page=="results" and lab.name_edit==null and (g.screen=="practice_results" or (g.screen=="garage" and g.tab=="tuning"))
	if not visible: pointer=-1; return
	sync(); publish_targets()
func label(parent: Node,text: String,font_size: int=17,color: Color=AutomotiveUI.INK) -> Label:
	var node:=Label.new(); node.text=text; node.add_theme_font_size_override("font_size",font_size); node.modulate=color
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node); return node
func button(parent: Node,id: String,title: String,callback: Callable) -> Button:
	var node:=Button.new(); node.text=title; node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.custom_minimum_size.y=90 if lab.short_layout() else (68 if g.is_portrait() else 46)
	parent.add_child(node); targets[id]=node; node.pressed.connect(callback); return node
func primary(run: Dictionary) -> Variant: return run.get("metrics",{}).get(RunArchive.metric(run))
func fmt(run: Dictionary,key: String) -> String:
	var value: Variant=run.get("metrics",{}).get(key)
	if not RunArchive.finite(value): return "—"
	if key.ends_with("mph"): return "%.1f"%float(value)
	if key=="launch_rpm": return "%.0f"%float(value)
	return "%.3f"%float(value)
func sync() -> void:
	position=Vector2(24,250) if g.is_portrait() else Vector2(36,252)
	size=Vector2(552,780) if g.is_portrait() else Vector2(1130,348 if lab.short_layout() else 410)
	var id:=RunArchive.key(g.profile.vehicle_id,lab.length)
	var revision:=str(g.profile.test_runs.get("serial",0))
	var identity:=id+":"+revision+":"+str(g.profile.get_instance_id())
	if selection_key!=identity:
		selection_key=identity; index_a=0; index_b=1; cached_state=""; scroll.scroll_vertical=0
	pool=RunArchive.history(g.profile.test_runs,g.profile.vehicle_id,lab.length).runs
	if pool.is_empty() and not lab.last.is_empty() and lab.last.get("key",id)==id: pool=[lab.last]
	index_a=clampi(index_a,0,maxi(0,pool.size()-1)); index_b=clampi(index_b,0,maxi(0,pool.size()-1))
	a=pool[index_a] if not pool.is_empty() else {}; b=pool[index_b] if pool.size()>1 else {}
	var state:=JSON.stringify([selection_key,index_a,index_b,g.is_portrait(),lab.short_layout(),lab.details])
	if state==cached_state: return
	cached_state=state; build()
func build() -> void:
	targets.clear(); plots.clear()
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	if a.is_empty():
		var saved_best: Dictionary=RunArchive.history(g.profile.test_runs,g.profile.vehicle_id,lab.length).best
		label(content,"No recent test traces" if not saved_best.is_empty() else "No test runs yet",25)
		if not saved_best.is_empty(): label(content,"PERSONAL BEST  "+fmt(saved_best,RunArchive.metric(saved_best))+" s",20,AutomotiveUI.BLUE)
		label(content,"Drive Test Track to record a run.",17,AutomotiveUI.MUTED); return
	lab.last=a; lab.last.key=RunArchive.key(g.profile.vehicle_id,lab.length)
	var history:=RunArchive.history(g.profile.test_runs,g.profile.vehicle_id,lab.length)
	var pb: Dictionary=history.best
	label(content,("RED LIGHT · UNRANKED" if a.metrics.red_light else "TEST TRACK · TIME SLIP")+("   /   PB "+fmt(pb,RunArchive.metric(a))+" s" if not pb.is_empty() else ""),20,AutomotiveUI.ORANGE if a.metrics.red_light else AutomotiveUI.BLUE)
	var selectors:=HBoxContainer.new(); selectors.add_theme_constant_override("separation",12); content.add_child(selectors)
	button(selectors,"tt_run_a","A · RUN %03d%s ↻"%[int(a.get("id",1))," ★" if not pb.is_empty() and a.get("id")==pb.get("id") else ""],func(): index_a=(index_a+1)%pool.size(); cached_state=""; g.menu_dirty=true)
	var second:=button(selectors,"tt_run_b","B · RUN %03d%s ↻"%[int(b.get("id",0))," ★" if not pb.is_empty() and b.get("id")==pb.get("id") else ""] if not b.is_empty() else "B · NO PREVIOUS RUN",func(): index_b=(index_b+1)%pool.size(); cached_state=""; g.menu_dirty=true)
	second.disabled=pool.size()<2
	button(selectors,"tt_details","TIME SLIP" if lab.details else "ANALYSIS",func(): lab.action("tt_details"))
	var grid:=GridContainer.new(); grid.columns=4; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",9); content.add_child(grid)
	for title in ["SPLIT / SPEED","A","B","Δ A − B"]:
		var cell:=label(grid,title,15,AutomotiveUI.MUTED); cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for pair in [["60 FT · s","sixty_ft_s"],["60 FT · mph","sixty_ft_mph"],["1/8 ET · s","eighth_s"],["1/8 TRAP · mph","eighth_mph"],["1/4 ET · s","quarter_s"],["1/4 TRAP · mph","trap_mph"],["REACTION · s","reaction_s"],["0–60 · s","zero_60_s"],["GREEN · s","total_s"],["LAUNCH · RPM","launch_rpm"]]:
		label(grid,pair[0],15); label(grid,fmt(a,pair[1]),18,TelemetryPlot.A); label(grid,fmt(b,pair[1]),18,TelemetryPlot.B)
		var difference: Variant=RunArchive.delta(a,b,pair[1])
		var improvement: bool=float(difference)>0 if difference!=null and str(pair[1]).ends_with("mph") else (difference!=null and float(difference)<0)
		label(grid,("%+.0f" if pair[1]=="launch_rpm" else "%+.3f")%float(difference) if difference!=null else "—",17,AutomotiveUI.MUTED if pair[1]=="launch_rpm" or a.metrics.red_light or b.get("metrics",{}).get("red_light",false) else (g.GREEN if improvement else (g.ORANGE if difference!=null and absf(float(difference))>.00001 else AutomotiveUI.MUTED)))
	var setup_a: Dictionary=a.get("setup",{}); var setup_b: Dictionary=b.get("setup",{})
	label(content,"A  "+setup_text(setup_a),15,TelemetryPlot.A).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not b.is_empty(): label(content,"B  "+setup_text(setup_b),15,TelemetryPlot.B).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var changes:=setup_changes(setup_a,setup_b)
	if changes!="": label(content,changes,15,AutomotiveUI.MUTED).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label(content,diagnostics(a),16,diagnostic_color(a)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if not b.is_empty(): label(content,"B · "+diagnostics(b),15,diagnostic_color(b)).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var plot_box: Container=VBoxContainer.new() if g.is_portrait() or lab.short_layout() else HBoxContainer.new()
	content.add_child(plot_box); plot_group=plot_box
	for field in ["speed","rpm"]:
		var plot:=TelemetryPlot.new(); plot.custom_minimum_size=Vector2(220,205 if g.is_portrait() else 180); plot.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		plot_box.add_child(plot); plot.configure(a,b,field); plot.cursor_time=cursor_time; plot.scrubbed.connect(seek_time); plots.append(plot)
	sample_label=label(content,"",15); sample_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; seek_time(cursor_time)
	if lab.details: call_deferred("show_plots")
	else: scroll.scroll_vertical=0
	if lab.details:
		for run in [a,b]:
			if run.is_empty(): continue
			var rows: Array=[]
			for shift in run.get("shifts",[]): rows.append("G%d  %.0f RPM"%[int(shift.gear),float(shift.rpm)])
			label(content,("A · " if run==a else "B · ")+"   /   ".join(rows),15,TelemetryPlot.A if run==a else TelemetryPlot.B).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func show_plots() -> void:
	if is_instance_valid(plot_group): scroll.scroll_vertical=roundi(plot_group.position.y)

func setup_text(setup: Dictionary) -> String:
	var ratios: Array=[]
	for ratio in setup.get("ratios",[]): ratios.append("%.2f"%float(ratio))
	return "%s  ·  FD %.2f  ·  Launch set %.0f RPM  ·  %s"%[str(setup.get("transmission","—")),float(setup.get("final_drive",0)),float(setup.get("launch_rpm",0))," / ".join(ratios)]
func setup_changes(first: Dictionary,second: Dictionary) -> String:
	var changes: Array=[]
	for pair in [["tire_pressure","Tire PSI"],["diff_lock","Diff"],["tc_slip","TC slip"],["redline","Limiter RPM"],["throttle_gamma","Pedal"],["clutch_rate","Clutch rate"],["boost","Boost PSI"],["launch_damping","Damping"]]:
		var x: Variant=first.get(pair[0]); var y: Variant=second.get(pair[0])
		if pair[0]=="boost" and RunArchive.finite(x) and RunArchive.finite(y):
			x=PressureUnits.psi(float(x)); y=PressureUnits.psi(float(y))
		if RunArchive.finite(x) and RunArchive.finite(y) and absf(float(x)-float(y))>.00001: changes.append("%s %.2f → %.2f"%[pair[1],float(y),float(x)])
	return "B → A   ·   "+"   /   ".join(changes) if not changes.is_empty() else ""
func diagnostic_color(run: Dictionary) -> Color:
	for key in ["traction_s","clutch_slip_s","limiter_s","low_rpm_s"]:
		if RunArchive.finite(run.metrics.get(key)) and float(run.metrics[key])>.05: return g.ORANGE
	return AutomotiveUI.MUTED
func diagnostics(run: Dictionary) -> String:
	var m: Dictionary=run.metrics; var notes: Array=[]
	for item in [["traction_s","Wheelspin"],["clutch_slip_s","Clutch slip"],["limiter_s","Limiter"],["low_rpm_s","Low RPM / load"]]:
		if RunArchive.finite(m.get(item[0])) and float(m[item[0]])>.05: notes.append("%s %.2f s"%[item[1],float(m[item[0]])])
	var peak: Variant=m.get("peak_acceleration")
	notes.append("Peak %.1f ft/s²"%ImperialUnits.feet(float(peak) if RunArchive.finite(peak) else 0))
	return "   ·   ".join(notes)
func nearest(run: Dictionary,time: float) -> Dictionary:
	var found: Dictionary={}; var best:=INF
	for row in run.get("samples",[]):
		var error:=absf(RunArchive.elapsed(run,row)-time)
		if error<best: found=row; best=error
	return found
func seek_time(time: float) -> void:
	cursor_time=time
	for plot in plots: plot.cursor_time=time; plot.queue_redraw()
	var sample:=nearest(a,time)
	if sample.is_empty(): return
	lab.cursor=a.samples.find(sample)
	var second:=nearest(b,time)
	sample_label.text="%.2f s  ·  A %.0f RPM / %.1f mph / spin %.0f%% / clutch %.0f RPM / %.1f ft/s²"%[time,sample.rpm,sample.speed,sample.wheelspin*100,sample.get("clutch_slip",0),ImperialUnits.feet(sample.acceleration)]
	if not second.is_empty(): sample_label.text+="\nB %.0f RPM / %.1f mph / spin %.0f%% / clutch %.0f RPM / %.1f ft/s²"%[second.rpm,second.speed,second.wheelspin*100,second.get("clutch_slip",0),ImperialUnits.feet(second.acceleration)]
func seek_fraction(fraction: float) -> void:
	if plots.is_empty(): return
	seek_time(clampf(fraction,0,1)*plots[0].duration)
func publish_targets() -> void:
	g.buttons=g.buttons.filter(func(entry): return entry.get("native_owner")!=self)
	for id in targets:
		var control: Button=targets[id]
		var rect:=control.get_global_rect().intersection(scroll.get_global_rect())
		if rect.size.y<control.size.y-1: continue
		g.buttons.append({"id":id,"rect":Rect2(g.to_local(rect.position),rect.size/g.scale),"native_control":control,"native_owner":self,"disabled":control.disabled})
	if not plots.is_empty():
		lab.graph_rect=Rect2(g.to_local(plots[0].global_position),plots[0].size)
		var clipped:=plots[0].get_global_rect().intersection(scroll.get_global_rect())
		if clipped.has_area(): g.buttons.append({"id":"tt_seek","rect":Rect2(g.to_local(clipped.position),clipped.size/g.scale),"native_owner":self})
func route_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey:
		var focus:=get_viewport().gui_get_focus_owner()
		return focus!=null and is_ancestor_of(focus) and RaceControls.key_code(event)!=KEY_ESCAPE
	if event is InputEventScreenTouch and event.pressed and get_global_rect().has_point(event.position):
		if pointer>=0: return true
		pointer=event.index; touch_start=event.position; scroll_start=scroll.scroll_vertical; touch_button=null; active_plot=null
		for control in targets.values():
			if control.get_global_rect().has_point(event.position) and scroll.get_global_rect().has_point(event.position): touch_button=control
		for plot in plots:
			if plot.get_global_rect().has_point(event.position) and scroll.get_global_rect().has_point(event.position): active_plot=plot; plot.seek_x((plot.get_global_transform().affine_inverse()*event.position).x)
		get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenDrag and event.index==pointer:
		if active_plot!=null: active_plot.seek_x((active_plot.get_global_transform().affine_inverse()*event.position).x)
		else: scroll.scroll_vertical=scroll_start-roundi((event.position.y-touch_start.y)/g.scale.y)
		get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenTouch and not event.pressed and event.index==pointer:
		if not event.canceled and touch_button!=null and not touch_button.disabled and event.position.distance_to(touch_start)<12: touch_button.pressed.emit()
		pointer=-1; touch_button=null; active_plot=null; get_viewport().set_input_as_handled(); return true
	return event is InputEventMouse and get_global_rect().has_point(event.position)
