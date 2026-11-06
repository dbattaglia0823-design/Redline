class_name GearboxTuningPanel
extends Control

var lab: TuningLab
var g: Node2D
var scroll: ScrollContainer
var list: VBoxContainer
var ratio_box: VBoxContainer
var heading: Label
var summary: Label
var rows: Dictionary = {}
var count := -1
var panel_group := ""
var build_id := ""
var cached_state := ""
var pointer := -1
var touch_start := Vector2.ZERO
var scroll_start := 0
var touch_slider: HSlider
var touch_button: Button
var sliding := false
var dirty_save := false
var scroll_velocity := 0.0
var previous_touch_y := 0.0
var previous_touch_ms := 0

func setup(tuning: TuningLab) -> void:
	lab=tuning; g=lab.g; name="GearboxTuning"
	theme=LiquidGlass.THEME; mouse_filter=Control.MOUSE_FILTER_STOP
	var background:=PanelContainer.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(background)
	var margin:=MarginContainer.new(); background.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	var column:=VBoxContainer.new(); margin.add_child(column); column.add_theme_constant_override("separation",10)
	heading=Label.new(); heading.add_theme_font_size_override("font_size",21); column.add_child(heading)
	summary=Label.new(); summary.add_theme_font_size_override("font_size",14); summary.modulate=GlassPalette.MUTED; column.add_child(summary)
	scroll=ScrollContainer.new(); scroll.name="GearboxScroll"; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus=false; scroll.scroll_deadzone=10; column.add_child(scroll)
	list=VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",10); scroll.add_child(list)
	add_row(list,"gear_count","Number of Gears",1)
	add_row(list,"final_drive","Final Drive Ratio",.01)
	ratio_box=VBoxContainer.new(); ratio_box.add_theme_constant_override("separation",10); list.add_child(ratio_box)
	visible=false

func _process(_dt: float) -> void:
	var shown: bool=g.screen=="garage" and g.tab=="tuning" and lab.page=="setup"  and lab.name_edit==null
	if not shown:
		if visible: finish_edit()
		scroll_velocity=0
		visible=false; return
	visible=true; sync()
	if pointer<0 and absf(scroll_velocity)>1 and not g.profile.reduced_motion:
		scroll.scroll_vertical+=roundi(scroll_velocity*_dt)
		scroll_velocity*=exp(-_dt*9)

func label(parent: Node,title: String,font_size: int) -> Label:
	var item:=Label.new(); item.text=title; item.mouse_filter=Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size",font_size); parent.add_child(item); return item

func rail_style(color: Color) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new(); style.bg_color=color; style.set_corner_radius_all(4)
	style.content_margin_top=3; style.content_margin_bottom=3
	return style

func add_row(parent: Node,key: String,title: String,step: float) -> void:
	var column:=VBoxContainer.new(); column.name=key; column.add_theme_constant_override("separation",1); parent.add_child(column)
	var title_row:=HBoxContainer.new(); column.add_child(title_row)
	var caption:=label(title_row,title,18); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var number:=label(title_row,"",20); number.add_theme_font_override("font",AutomotiveUI.NUMBERS)
	var controls:=HBoxContainer.new(); controls.add_theme_constant_override("separation",12); column.add_child(controls)
	var minus:=Button.new(); minus.text="−"; minus.custom_minimum_size=Vector2(52,48); controls.add_child(minus)
	var slider:=HSlider.new(); slider.name=key+"Slider"; slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.add_theme_stylebox_override("slider",rail_style(Color("293c4b")))
	slider.add_theme_stylebox_override("grabber_area",rail_style(Color("4ca6c5")))
	slider.add_theme_stylebox_override("grabber_area_highlight",rail_style(GlassPalette.BLUE))
	slider.custom_minimum_size=Vector2(100,48); slider.step=step; slider.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; controls.add_child(slider)
	var plus:=Button.new(); plus.text="+"; plus.custom_minimum_size=Vector2(52,48); controls.add_child(plus)
	var hint:=label(column,"",13); hint.modulate=GlassPalette.MUTED
	rows[key]={"slider":slider,"minus":minus,"plus":plus,"value":number,"hint":hint,"column":column,"caption":caption,"title":title}
	for control in [minus,slider,plus]: control.focus_entered.connect(func(): reveal_row(column))
	minus.pressed.connect(func(): apply(key,current(key)-step,true))
	plus.pressed.connect(func(): apply(key,current(key)+step,true))
	slider.drag_started.connect(func(): sliding=true)
	slider.drag_ended.connect(func(_changed): finish_edit())
	slider.value_changed.connect(func(value): apply(key,value,not sliding))

func reveal_row(column: Control) -> void:
	# Reveal complete rows in content coordinates, independently of the
	# game's window/UI transform and the position of sibling controls.
	if not is_instance_valid(column) or not column.is_inside_tree(): return
	scroll_velocity=0
	var top: float=column.position.y+(ratio_box.position.y if column.get_parent()==ratio_box else 0)
	var bottom: float=top+column.size.y
	if top<scroll.scroll_vertical: scroll.scroll_vertical=roundi(top)
	elif bottom>scroll.scroll_vertical+scroll.size.y: scroll.scroll_vertical=roundi(bottom-scroll.size.y)

func rebuild_group(group: String) -> void:
	rows.clear()
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	if group=="Gearbox":
		add_row(list,"gear_count","Number of Gears",1); add_row(list,"final_drive","Final Drive Ratio",.01)
	else:
		for key in TuningSetup.GROUPS[group]:
			if key=="boost_gear":
				for index in g.car.gear_ratios.size(): add_row(list,"boost_slot_%d"%index,"Gear %d boost cap · bar"%(index+1),.01)
			else: add_row(list,key,lab.LABELS.get(key,TuningSetup.EXTRA.get(key,[key])[0]),float(TuningSetup.EXTRA[key][3]) if TuningSetup.EXTRA.has(key) else (50.0 if key=="launch_rpm" else (100.0 if key=="redline" else .01)))
	ratio_box=VBoxContainer.new(); ratio_box.add_theme_constant_override("separation",10); list.add_child(ratio_box)
	if group=="Gearbox": rebuild_ratios()

func rebuild_ratios() -> void:
	for key in rows.keys():
		if key not in ["gear_count","final_drive"]: rows.erase(key)
	for child in ratio_box.get_children(): ratio_box.remove_child(child); child.queue_free()
	for index in g.car.gear_ratios.size():
		var ordinal: String=["1st","2nd","3rd"][index] if index<3 else str(index+1)+"th"
		add_row(ratio_box,"ratio_%d"%index,ordinal+" Gear Ratio",.01)
	# Secondary gearbox controls follow the complete gearing list, never interrupt it.
	for index in g.car.shift_map.size(): add_row(ratio_box,"shift_%d"%index,"Upshift RPM · Gear %d"%(index+1),100)
	if g.car.transmission_kind in ["automatic","drag","dct"]: add_row(ratio_box,"firmness","Shift firmness",.05)
	if g.car.transmission_kind in ["automatic","drag"]: add_row(ratio_box,"launch_gear","Launch gear",1)

func bounds(key: String) -> Vector2:
	if TuningSetup.EXTRA.has(key):
		var row: Array=TuningSetup.EXTRA[key]; return Vector2(float(row[1]),minf(float(row[2]),g.car.gear_ratios.size()) if key=="launch_gear" else float(row[2]))
	if key=="launch_rpm": return Vector2(2200,minf(6000,g.car.redline_rpm-400))
	if key=="redline": return Vector2(minf(6500,g.car._mechanical_redline-500),g.car._mechanical_redline)
	if key=="boost" or key.begins_with("boost_slot_"): return Vector2(0,VehicleParts.boost_control_limit(g.profile.hardware,g.car.base_boost,g.car.turbo_stage))
	if key=="gear_count":
		var limits:=TransmissionCatalog.count_limits(str(g.profile.hardware.transmission)); return Vector2(limits)
	if key=="final_drive": return Vector2(TransmissionCatalog.FINAL_MIN,TransmissionCatalog.FINAL_MAX)
	if key.begins_with("ratio_"):
		var index:=int(key.trim_prefix("ratio_")); var ratios: Array=g.car.gear_ratios
		return TransmissionCatalog.ratio_bounds(ratios,index)
	if key.begins_with("shift_"): return Vector2(maxf(3500,g.car.idle_rpm+1500),g.car.redline_rpm-50)
	if key=="firmness": return Vector2(.5,1+int(g.profile.stages[4])*.1)
	return Vector2(1,mini(2,g.car.gear_ratios.size()))

func reason(key: String) -> String:
	if not g.profile.pending_wager.is_empty(): return "Finish the active race first"
	if key=="gear_count" or key.begins_with("ratio_"): return lab.reason("ratio")
	if key.begins_with("shift_"):
		return ""
	if key.begins_with("boost_slot_"): return lab.reason("boost_gear")
	return lab.reason(key)

func current(key: String) -> float:
	if key=="gear_count": return g.car.gear_ratios.size()
	if key.begins_with("boost_slot_"):
		var index:=int(key.trim_prefix("boost_slot_")); return g.car.boost_by_gear[index] if index<g.car.boost_by_gear.size() else g.car.boost_target(g.car.redline_rpm,1)
	if key.begins_with("ratio_"): return g.car.gear_ratios[int(key.trim_prefix("ratio_"))]
	if key.begins_with("shift_"): return g.car.shift_map[int(key.trim_prefix("shift_"))]
	return float(lab.value(key))

func sync() -> void:
	var p: bool=g.is_portrait(); var short: bool=lab.short_layout()
	var group: String=TuningSetup.GROUPS.keys()[lab.group]
	var state:=JSON.stringify([group,p,short,g.profile.vehicle_id,g.profile.hardware,g.profile.stages,g.profile.pending_wager,g.profile.metric_speed,g.car.shift_map])
	if state==cached_state: return
	cached_state=state
	position=Vector2(24,430) if p else Vector2(250,252)
	size=Vector2(552,590) if p else Vector2(916,336 if short else 414)
	var identity: String=g.profile.vehicle_id+":"+str(g.profile.hardware.transmission)
	if identity!=build_id: finish_edit(); scroll.scroll_vertical=0; build_id=identity
	if group!=panel_group:
		finish_edit(); panel_group=group; rebuild_group(group); scroll.scroll_vertical=0
		count=g.car.gear_ratios.size()
	elif count!=g.car.gear_ratios.size():
		count=g.car.gear_ratios.size()
		if group=="Gearbox": rebuild_ratios()
		else: rebuild_group(group)
	heading.text=TransmissionCatalog.spec(str(g.profile.hardware.transmission)).name+" · Gearing" if group=="Gearbox" else group+" · Installed setup"
	summary.text="Live speeds at %.0f RPM · scroll for all gears"%g.car.redline_rpm if group=="Gearbox" else "Live settings · saved on release"
	for key in rows:
		var row: Dictionary=rows[key]; var limits:=bounds(key); var value:=current(key)
		var lock:=reason(key)
		row.slider.set_block_signals(true)
		row.slider.min_value=ceilf(limits.x*100-.00001)/100; row.slider.max_value=floorf(limits.y*100+.00001)/100
		row.slider.set_value_no_signal(value); row.slider.set_block_signals(false); row.slider.editable=lock==""
		row.minus.disabled=lock!="" or value<=limits.x+.0001
		row.plus.disabled=lock!="" or value>=limits.y-.0001
		row.value.text=str(roundi(value)) if key in ["gear_count","launch_rpm","redline"] or key.begins_with("shift_") else ("ON" if value>.5 else "OFF") if key=="launch_enabled" else "%.3f"%value
		row.minus.custom_minimum_size=Vector2(90,90) if short else (Vector2(68,68) if p else Vector2(52,44))
		row.plus.custom_minimum_size=row.minus.custom_minimum_size
		row.slider.custom_minimum_size.y=90 if short else (68 if p else 44)
		row.caption.text=row.title
		row.hint.text=lock
		if lock=="" and key.begins_with("ratio_"):
			var speed: float=g.car.redline_rpm/Drivetrain.RPM_PER_RAD*g.car.tire_radius/(value*g.car.final_drive)
			row.caption.text=row.title+" · %.0f %s"%[speed*(3.6 if g.profile.metric_speed else Drivetrain.MPH_PER_MPS),"km/h" if g.profile.metric_speed else "mph"]
			row.column.tooltip_text="%.0f km/h at redline · %.0f mph"%[speed*3.6,speed*Drivetrain.MPH_PER_MPS]
		elif lock=="" and key=="gear_count": row.caption.text=row.title+" · %d–%d"%[int(limits.x),int(limits.y)]
		elif lock=="" and key=="final_drive": row.column.tooltip_text="Lower: taller gearing · Higher: quicker acceleration"
		row.hint.visible=lock!=""

func apply(key: String,requested: float,persist: bool) -> void:
	if reason(key)!="": return
	var limits:=bounds(key)
	var value:=clampf(snappedf(requested,1 if key=="gear_count" else .001),limits.x,limits.y)
	var tuning_key:=key
	var setting: Variant=value
	if key.begins_with("ratio_"):
		tuning_key="ratios"; setting=g.car.gear_ratios.duplicate(); setting[int(key.trim_prefix("ratio_"))]=value
	elif key.begins_with("boost_slot_"):
		tuning_key="boost_by_gear"; setting=[]
		for i in g.car.gear_ratios.size(): setting.append(g.car.boost_by_gear[i] if i<g.car.boost_by_gear.size() else g.car.boost_target(g.car.redline_rpm,1))
		setting[int(key.trim_prefix("boost_slot_"))]=value
	elif key.begins_with("shift_"):
		tuning_key="shift_rpms"; setting=g.car.shift_map.duplicate(); setting[int(key.trim_prefix("shift_"))]=value
	if g.profile.tune_hardware(tuning_key,setting,persist):
		dirty_save=not persist; g.refresh_car(persist); g.menu_dirty=true
		if not persist:
			# Ratios and final drive reach the solver immediately. Expensive
			# shift optimization runs once on release, not for every drag pixel.
			var saved: Array=g.profile.hardware.tune.get("shift_rpms",[])
			g.car.shift_map.resize(g.car.gear_ratios.size()-1)
			for i in g.car.shift_map.size():
				if i<saved.size(): g.car.shift_map[i]=float(saved[i])
				elif g.car.shift_map[i]==null or float(g.car.shift_map[i])<=0: g.car.shift_map[i]=g.car.redline_rpm-500
		lab.gear=clampi(lab.gear,0,g.car.gear_ratios.size()-1); g.workshop.gear_index=lab.gear
		sync()

func finish_edit() -> void:
	if dirty_save: g.profile.save(); g.refresh_car(); dirty_save=false
	sliding=false; pointer=-1; touch_slider=null; touch_button=null

func route_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey:
		scroll_velocity=0
		var focus:=get_viewport().gui_get_focus_owner()
		return focus!=null and is_ancestor_of(focus) and RaceControls.key_code(event)!=KEY_ESCAPE
	if event is InputEventScreenTouch and event.pressed and get_global_rect().has_point(event.position):
		if pointer>=0: return true
		pointer=event.index; touch_start=event.position; scroll_start=scroll.scroll_vertical
		scroll_velocity=0; previous_touch_y=event.position.y; previous_touch_ms=Time.get_ticks_msec()
		for row in rows.values():
			var clip:=scroll.get_global_rect()
			if not clip.has_point(event.position): continue
			if row.slider.get_global_rect().has_point(event.position) and row.slider.editable:
				touch_slider=row.slider; sliding=true; touch_value(event.position.x)
				get_viewport().set_input_as_handled(); return true
			for button in [row.minus,row.plus]:
				if button.get_global_rect().has_point(event.position): touch_button=button
		get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenDrag and event.index==pointer:
		if touch_slider!=null: touch_value(event.position.x)
		else:
			scroll.scroll_vertical=scroll_start-roundi((event.position.y-touch_start.y)/g.scale.y)
			var now:=Time.get_ticks_msec()
			scroll_velocity=clampf(-(event.position.y-previous_touch_y)/g.scale.y/maxf(.016,(now-previous_touch_ms)/1000.0),-1600,1600)
			previous_touch_y=event.position.y; previous_touch_ms=now
		get_viewport().set_input_as_handled(); return true
	if event is InputEventScreenTouch and not event.pressed and event.index==pointer:
		if not event.canceled and touch_button!=null and not touch_button.disabled and event.position.distance_to(touch_start)<12 and touch_button.get_global_rect().has_point(event.position): touch_button.pressed.emit()
		finish_edit(); get_viewport().set_input_as_handled(); return true
	if event is InputEventMouse and get_global_rect().has_point(event.position):
		if event is InputEventMouseButton and event.pressed: scroll_velocity=0
		return true
	return false

func touch_value(x: float) -> void:
	if touch_slider==null: return
	var r:=touch_slider.get_global_rect()
	var amount:=clampf((x-r.position.x-8)/maxf(1,r.size.x-16),0,1)
	touch_slider.value=lerpf(touch_slider.min_value,touch_slider.max_value,amount)
