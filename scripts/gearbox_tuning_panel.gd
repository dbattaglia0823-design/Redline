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
var sections: Dictionary = {}
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
var save_delay := 0.0
var layout_revision := 0
var pointer_focus := false

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
	if dirty_save and not sliding and pointer<0:
		save_delay-=_dt
		if save_delay<=0: finish_edit()
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
	if PressureUnits.is_pressure_setting(key): step=.5
	var column:=VBoxContainer.new(); column.name=key; column.add_theme_constant_override("separation",1); parent.add_child(column)
	var title_row:=HBoxContainer.new(); column.add_child(title_row)
	var caption:=label(title_row,title,18); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var number:=label(title_row,"",20); number.add_theme_font_override("font",AutomotiveUI.NUMBERS)
	var controls:=HBoxContainer.new(); controls.add_theme_constant_override("separation",12); column.add_child(controls)
	var minus:=Button.new(); minus.text="−"; minus.custom_minimum_size=Vector2(52,48); controls.add_child(minus)
	var slider:=HSlider.new(); slider.name=key+"Slider"; slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	slider.scrollable=false
	slider.set_meta("tuning_key",key)
	slider.add_theme_stylebox_override("slider",rail_style(Color("293c4b")))
	slider.add_theme_stylebox_override("grabber_area",rail_style(Color("4ca6c5")))
	slider.add_theme_stylebox_override("grabber_area_highlight",rail_style(GlassPalette.BLUE))
	slider.custom_minimum_size=Vector2(100,48); slider.step=.1 if PressureUnits.is_pressure_setting(key) else step; slider.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; controls.add_child(slider)
	if key.begins_with("ratio_"): slider.step=.001
	var plus:=Button.new(); plus.text="+"; plus.custom_minimum_size=Vector2(52,48); controls.add_child(plus)
	var hint:=label(column,"",13); hint.modulate=GlassPalette.MUTED
	rows[key]={"slider":slider,"minus":minus,"plus":plus,"value":number,"hint":hint,"column":column,"caption":caption,"title":title}
	for control in [minus,slider,plus]: control.focus_entered.connect(func(): reveal_row(column))
	minus.pressed.connect(func(): apply(key,current(key)-step,true))
	plus.pressed.connect(func(): apply(key,current(key)+step,true))
	slider.drag_started.connect(func(): sliding=true)
	slider.drag_ended.connect(func(_changed):
		if key=="gear_count": apply(key,slider.value,false)
		finish_edit())
	slider.value_changed.connect(func(value):
		if key=="gear_count" and sliding: number.text=str(roundi(value))
		else: apply(key,value,not sliding))

func reveal_row(column: Control) -> void:
	# Reveal complete rows in content coordinates, independently of the
	# game's window/UI transform and the position of sibling controls.
	if not is_instance_valid(column) or not column.is_inside_tree(): return
	if (pointer_focus or pointer>=0) and not g.gamepad.active: return
	scroll_velocity=0
	var top: float=column.position.y+(ratio_box.position.y if column.get_parent()==ratio_box else 0)
	var bottom: float=top+column.size.y
	if top<scroll.scroll_vertical: scroll.scroll_vertical=roundi(top)
	elif bottom>scroll.scroll_vertical+scroll.size.y: scroll.scroll_vertical=roundi(bottom-scroll.size.y)

func rebuild_group(_group: String) -> void:
	rows.clear()
	sections.clear()
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	for group_name in TuningSetup.GROUPS:
		var section:=label(list,group_name.to_upper(),20)
		section.modulate=GlassPalette.BLUE
		sections[group_name]=section
		if group_name=="Gearbox":
			add_row(list,"gear_count","Number of Gears",1)
			add_row(list,"final_drive","Final Drive Ratio",.01)
			ratio_box=VBoxContainer.new()
			ratio_box.add_theme_constant_override("separation",10)
			list.add_child(ratio_box)
			rebuild_ratios()
			continue
		for key in TuningSetup.GROUPS[group_name]:
			if key=="boost_gear":
				for index in g.car.gear_ratios.size(): add_row(list,"boost_slot_%d"%index,"Gear %d boost cap · PSI"%(index+1),.5)
			else: add_row(list,key,lab.LABELS.get(key,TuningSetup.EXTRA.get(key,[key])[0]),float(TuningSetup.EXTRA[key][3]) if TuningSetup.EXTRA.has(key) else (50.0 if key=="launch_rpm" else (100.0 if key=="redline" else .01)))

func rebuild_ratios() -> void:
	for key in rows.keys():
		if key.begins_with("ratio_") or key.begins_with("shift_") or key in ["firmness","launch_gear"]: rows.erase(key)
	for child in ratio_box.get_children(): ratio_box.remove_child(child); child.queue_free()
	for index in g.car.gear_ratios.size():
		var ordinal: String=["1st","2nd","3rd"][index] if index<3 else str(index+1)+"th"
		add_row(ratio_box,"ratio_%d"%index,ordinal+" Gear Ratio",.01)
	# Secondary gearbox controls follow the complete gearing list, never interrupt it.
	for index in g.car.shift_map.size(): add_row(ratio_box,"shift_%d"%index,"Upshift RPM · Gear %d"%(index+1),100)
	if g.car.transmission_kind in ["automatic","drag","dct"]: add_row(ratio_box,"firmness","Shift firmness",.05)
	if g.car.transmission_kind in ["automatic","drag"]: add_row(ratio_box,"launch_gear","Launch gear",1)

func bounds(key: String) -> Vector2:
	var limits:=stored_bounds(key)
	return limits*PressureUnits.PSI_PER_BAR if PressureUnits.is_pressure_setting(key) else limits

func stored_bounds(key: String) -> Vector2:
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
	var value:=stored_value(key)
	return PressureUnits.psi(value) if PressureUnits.is_pressure_setting(key) else value

func stored_value(key: String) -> float:
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
	if identity!=build_id or count!=g.car.gear_ratios.size() or sections.is_empty():
		if identity!=build_id: finish_edit()
		var keep_scroll: bool=identity==build_id and not sections.is_empty()
		var previous_scroll:=scroll.scroll_vertical
		build_id=identity
		count=g.car.gear_ratios.size()
		rebuild_group(group)
		layout_revision+=1
		if keep_scroll: restore_scroll.call_deferred(previous_scroll,layout_revision)
		else: panel_group=""
	if group!=panel_group:
		panel_group=group
		jump_to_section.call_deferred(group)
	heading.text="Complete vehicle tuning"
	summary.text="All installed settings · category buttons jump to a section"
	for key in rows:
		var row: Dictionary=rows[key]; var limits:=bounds(key); var value:=current(key)
		var lock:=reason(key)
		row.slider.set_block_signals(true)
		var display_limits:=Vector2(TransmissionCatalog.MIN_RATIO,TransmissionCatalog.MAX_RATIO) if key.begins_with("ratio_") else limits
		row.slider.min_value=display_limits.x; row.slider.max_value=display_limits.y
		row.slider.set_value_no_signal(value); row.slider.set_block_signals(false); row.slider.editable=lock==""
		row.minus.disabled=lock!="" or value<=limits.x+.0001
		row.plus.disabled=lock!="" or value>=limits.y-.0001
		row.value.text=str(roundi(value)) if key in ["gear_count","launch_rpm","redline"] or key.begins_with("shift_") else ("ON" if value>.5 else "OFF") if key=="launch_enabled" else "%.3f"%value
		if PressureUnits.is_pressure_setting(key): row.value.text="%.1f PSI%s"%[value,"/s" if key=="boost_rise" else ""]
		elif key=="tire_pressure": row.value.text="%.0f PSI"%value
		row.minus.custom_minimum_size=Vector2(90,90) if short else (Vector2(68,68) if p else Vector2(52,44))
		row.plus.custom_minimum_size=row.minus.custom_minimum_size
		row.slider.custom_minimum_size.y=90 if short else (68 if p else 44)
		row.caption.text=row.title
		row.hint.text=lock
		if lock=="" and key.begins_with("ratio_"):
			var speed: float=g.car.redline_rpm/Drivetrain.RPM_PER_RAD*g.car.tire_radius/(value*g.car.final_drive)
			row.caption.text=row.title+" · %.0f %s"%[speed*Drivetrain.MPH_PER_MPS,"mph"]
			row.column.tooltip_text="%.0f mph at redline"%(speed*Drivetrain.MPH_PER_MPS)
		elif lock=="" and key=="gear_count": row.caption.text=row.title+" · %d–%d"%[int(limits.x),int(limits.y)]
		elif lock=="" and key=="final_drive": row.column.tooltip_text="Lower: taller gearing · Higher: quicker acceleration"
		row.hint.visible=lock!=""

func jump_to_section(group: String) -> void:
	await get_tree().process_frame
	if group==panel_group and sections.has(group): scroll.scroll_vertical=roundi(sections[group].position.y)

func restore_scroll(value: int,revision: int) -> void:
	await get_tree().process_frame
	if revision==layout_revision: scroll.scroll_vertical=value

func apply(key: String,requested: float,_persist: bool) -> void:
	if reason(key)!="": return
	var limits:=bounds(key)
	var value:=clampf(snappedf(requested,1 if key=="gear_count" else .001),limits.x,limits.y)
	if PressureUnits.is_pressure_setting(key): value=PressureUnits.from_psi(value)
	if is_equal_approx(value,stored_value(key)):
		rows[key].slider.set_value_no_signal(current(key))
		return
	var previous_shifts: Array=g.car.shift_map.duplicate()
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
	if g.profile.tune_hardware(tuning_key,setting,false):
		# Once the player tunes a build, keep its displayed shift settings fixed.
		# Only new gears need new entries; resetting tuning restores automatic planning.
		if not g.profile.hardware.tune.has("shift_rpms"):
			var shift_count:=TransmissionCatalog.gear_count(g.profile.hardware)-1
			previous_shifts.resize(shift_count)
			for i in shift_count:
				if previous_shifts[i]==null: previous_shifts[i]=g.car.redline_rpm-500
			g.profile.tune_hardware("shift_rpms",previous_shifts,false)
		dirty_save=true; save_delay=.25
		g.refresh_car(false); g.car.rebuild_shift_map(); g.menu_dirty=true
		lab.gear=clampi(lab.gear,0,g.car.gear_ratios.size()-1); g.workshop.gear_index=lab.gear
		sync()

func finish_edit() -> void:
	if dirty_save: g.profile.save(); dirty_save=false
	sliding=false; pointer=-1; touch_slider=null; touch_button=null

func route_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: pointer_focus=event.pressed
	if event is InputEventKey:
		pointer_focus=false
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
		if is_instance_valid(touch_slider) and touch_slider.get_meta("tuning_key","")=="gear_count":
			if not event.canceled: apply("gear_count",touch_slider.value,false)
			else:
				touch_slider.set_value_no_signal(current("gear_count"))
				rows.gear_count.value.text=str(roundi(current("gear_count")))
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
