class_name WorkshopScreen
extends Control

# First migration boundary: Garage, upgrade overview and package/part purchasing.
# Complex gearbox/tuning tools keep their existing implementation for now.
var game: Node2D
var signature: String=""
var targets: Dictionary={}
var portrait:=false
var notice: PanelContainer
var notice_label: Label

class DynoPlot extends Control:
	var current: Drivetrain
	var candidate: Drivetrain
	func _draw() -> void:
		var bounds:=Rect2(36,12,size.x-46,size.y-40)
		if bounds.size.x<10: return
		var maximum: float=maxf(1,maxf(current.peak_horsepower(),candidate.peak_horsepower()))
		maximum=maxf(maximum,maxf(GarageHub.peak_torque(current),GarageHub.peak_torque(candidate)))*1.1
		for i in 4:
			var y: float=bounds.end.y-bounds.size.y*i/3
			draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color("ffffff10"),1)
			draw_string(AutomotiveUI.NUMBERS,Vector2(0,y+4),"%.0f"%(maximum*i/3),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
		var limit: float=maxf(current.redline_rpm,candidate.redline_rpm)
		for build in [current,candidate]:
			for torque in [false,true]:
				var points:=PackedVector2Array()
				for i in range(65):
					var rpm: float=lerpf(build.idle_rpm,build.redline_rpm,float(i)/64)
					var value: float=build.full_engine_torque(rpm)
					if not torque: value=value*rpm/7127.0
					points.append(Vector2(bounds.position.x+bounds.size.x*rpm/limit,bounds.end.y-bounds.size.y*value/maximum))
				var color:=Color("91c9ad") if torque else AutomotiveUI.ORANGE
				if build==current:
					color.a=.35; draw_polyline(points,color,1.5,true)
				else:
					for i in range(0,64,2): draw_line(points[i],points[i+1],color,2,true)
		for i in 4:
			var x: float=bounds.position.x+bounds.size.x*i/3
			draw_string(AutomotiveUI.NUMBERS,Vector2(x-12,size.y-7),"%.1fk"%(limit*i/3000),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)

func setup(g: Node2D) -> void:
	game=g; mouse_filter=Control.MOUSE_FILTER_IGNORE; theme=AutomotiveUI.theme_resource()

func supports() -> bool:
	if game.glass.legacy: return false # Existing development-only F6 comparison.
	if game.screen!="garage" or game.menu.hub.dyno_open: return false
	if game.tab=="garage": return true
	if game.tab!="performance": return false
	return game.menu.hub.categories or game.workshop.mode in ["basic","hardware"]

func bind(b: Button,id: String) -> void:
	b.name=id; b.disabled=not game.action_enabled(id)
	b.focus_mode=Control.FOCUS_ALL
	b.focus_entered.connect(func(): game.glass.focused=id)
	b.pressed.connect(func(): game.action(id))
	targets[id]=b

func button(parent: Node,id: String,title: String,primary: bool=false) -> Button:
	var b:=AutomotiveUI.button(parent,title,"Primary" if primary else "Secondary",70 if portrait else 46)
	bind(b,id); return b

func sync() -> void:
	visible=supports()
	if not visible: return
	portrait=game.is_portrait(); size=canvas_size()
	var key:=state_key()
	if key!=signature:
		signature=key
		for child in get_children():
			if child is CanvasItem: child.hide()
			child.queue_free()
		targets.clear(); build()
	publish_targets()
	if game.screen=="garage" and (game.tab!="performance" or game.menu.hub.categories): game.draw_navigation()

func canvas_size() -> Vector2:
	return Vector2(600,1300) if game.is_portrait() else Vector2(1200,760)

func handle_scroll_touch(_event: InputEvent) -> bool:
	return false

func state_key() -> String:
	var w: UpgradeWorkshop=game.workshop
	var projection: String=""
	if game.tab=="performance" and not game.menu.hub.categories and game.menu.hub.selected>=7:
		projection=game.menu.hub.studio.race_comparison(game.menu.hub.studio.candidate())
	return JSON.stringify([size,game.tab,game.profile.vehicle_id,game.profile.credits,game.profile.xp,game.profile.stages,game.profile.hardware,game.profile.appearance_for(game.profile.vehicle_id),game.menu.hub.categories,game.menu.hub.selected,game.menu.hub.studio.system,w.mode,w.slot_index,w.parts_page,w.preview_stage,w.selected_hardware,w.details,game.profile.muted,game.profile.effects_quality,projection,PerformanceClasses.label(game.profile)])

func _process(_delta: float) -> void:
	if not visible: return
	publish_targets()
	if is_instance_valid(notice):
		notice.visible=game.toast_left>0
		notice_label.text=game.toast

func publish_targets() -> void:
	# Container layout is deferred by Godot. Refresh after layout as well as draw,
	# so pointer targets always match the rendered controls, including resizes.
	game.buttons=game.buttons.filter(func(entry): return entry.get("native_owner")!=self)
	for id in targets:
		var b: Button=targets[id]
		if not b.is_visible_in_tree(): continue
		var r:=Rect2(game.to_local(b.global_position),b.size)
		var ancestor: Node=b.get_parent()
		while ancestor!=self and ancestor!=null:
			if ancestor is ScrollContainer:
				r=r.intersection(Rect2(game.to_local(ancestor.global_position),ancestor.size))
			ancestor=ancestor.get_parent()
		if not r.has_area() or r.size.y<minf(b.size.y,70 if portrait else 40): continue
		game.buttons.append({"id":id,"rect":r,"disabled":b.disabled,"native_control":b,"native_owner":self})
		if game.glass.focused==id and not b.disabled and not b.has_focus(): b.grab_focus()

func container(rect: Rect2) -> VBoxContainer:
	var margin:=MarginContainer.new(); add_child(margin); margin.position=rect.position; margin.size=rect.size
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return AutomotiveUI.column(margin,18 if portrait else 14)

func build() -> void:
	var body:=container(Rect2(24,20,552,1100) if portrait else Rect2(36,20,1128,630))
	header(body)
	var h: GarageHub=game.menu.hub
	var modal: bool=game.tab=="performance" and not h.categories
	if game.tab=="garage": garage(body)
	else: overview(body)
	if modal:
		targets.clear()
		var dim:=ColorRect.new(); dim.color=Color(0,.015,.025,.86); dim.mouse_filter=Control.MOUSE_FILTER_STOP
		add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal_content()
	build_notice()

func header(body: VBoxContainer) -> void:
	var header:=AutomotiveUI.row(body)
	header.custom_minimum_size.y=44
	var logo:=AutomotiveUI.row(header,8)
	var mark:=AutomotiveUI.label("R /",26,AutomotiveUI.ORANGE); mark.custom_minimum_size.x=42; mark.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; logo.add_child(mark)
	logo.add_child(AutomotiveUI.label("REDLINE",26))
	var wallet:=AutomotiveUI.label("LV %02d  /  $%s"%[game.profile.level(),game.profile.credits],18,AutomotiveUI.MUTED,true)
	wallet.custom_minimum_size.x=240 if portrait else 260
	wallet.size_flags_horizontal=Control.SIZE_SHRINK_END; header.add_child(wallet)
	if not portrait:
		var sound:=button(header,"sound","Muted" if game.profile.muted else "Sound on"); sound.custom_minimum_size.x=108; sound.size_flags_horizontal=Control.SIZE_SHRINK_END

func build_notice() -> void:
	notice=PanelContainer.new(); add_child(notice); notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
	notice.position=Vector2(24,74) if portrait else Vector2(350,66)
	notice.size=Vector2(552,62) if portrait else Vector2(500,48)
	notice.add_theme_stylebox_override("panel",AutomotiveUI.surface(Color("152b2b"),Color("91c9ad"),12))
	notice_label=AutomotiveUI.label(game.toast,18,Color("d0e8dc")); notice.add_child(notice_label)
	notice.visible=game.toast_left>0

func preview(parent: Node,height: float) -> void:
	var view:=VehiclePreview.new(); parent.add_child(view)
	view.configure(game,game.profile.vehicle_id,game.car,game.profile.appearance_for(game.profile.vehicle_id),true,height)
	view.size_flags_vertical=Control.SIZE_EXPAND_FILL

func garage(body: VBoxContainer) -> void:
	var spec:=GameCatalog.spec(game.profile.vehicle_id)
	var title:=AutomotiveUI.row(body)
	var text:=AutomotiveUI.column(title,4)
	text.add_child(AutomotiveUI.label("YOUR GARAGE",12,AutomotiveUI.BLUE))
	text.add_child(AutomotiveUI.label(str(spec.name),32 if portrait else 36))
	text.add_child(AutomotiveUI.label(str(spec.engine)+"  /  "+str(spec.drive),18,AutomotiveUI.MUTED))
	if not portrait:
		var change:=button(title,"hub_owned","Change car"); change.custom_minimum_size.x=170; change.size_flags_horizontal=Control.SIZE_SHRINK_END; change.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	preview(body,390 if portrait else 290)
	body.add_child(AutomotiveUI.label(game.menu.hub.configuration_label()+"  /  "+PerformanceClasses.label(game.profile),16,AutomotiveUI.MUTED))
	var stats:=AutomotiveUI.panel(body)
	var grid:=GridContainer.new(); grid.columns=2 if portrait else 4; grid.add_theme_constant_override("h_separation",28); grid.add_theme_constant_override("v_separation",14); stats.add_child(grid)
	AutomotiveUI.stat(grid,"ENGINE POWER" if float(game.car._base_spec.get("hybrid_kw",0))>0 else "POWER","%.0f"%game.car.peak_horsepower(),"hp")
	AutomotiveUI.stat(grid,"TORQUE","%.0f"%GarageHub.peak_torque(game.car),"Nm")
	AutomotiveUI.stat(grid,"GRIP","%.2f"%GarageHub.grip(game.car),"")
	AutomotiveUI.stat(grid,"WEIGHT","%.0f"%game.car.mass(),"kg")
	var actions:=AutomotiveUI.row(body)
	button(actions,"race_menu","Find a race   →",true)
	var track:=button(actions,"open_tuning","Test track"); track.size_flags_stretch_ratio=.6
	if portrait: button(body,"hub_owned","Change car")

func overview(body: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub; var studio: UpgradeStudio=h.studio
	var title:=AutomotiveUI.row(body)
	title.add_child(AutomotiveUI.label("Build your advantage",30))
	var dyno:=button(title,"hub_dyno","Live Dyno"); dyno.custom_minimum_size.x=150; dyno.size_flags_horizontal=Control.SIZE_SHRINK_END
	body.add_child(AutomotiveUI.label(str(GameCatalog.spec(game.profile.vehicle_id).name)+"  /  %.0f hp  /  %.0f Nm"%[game.car.peak_horsepower(),GarageHub.peak_torque(game.car)],18,AutomotiveUI.MUTED))
	preview(body,190 if portrait else 150)
	var tabs:=GridContainer.new(); tabs.columns=2 if portrait else 4; tabs.add_theme_constant_override("h_separation",10); tabs.add_theme_constant_override("v_separation",10); body.add_child(tabs)
	for i in 4:
		var b:=button(tabs,"upgrade_system_%d"%i,UpgradeStudio.SYSTEMS[i]); b.theme_type_variation="Navigation"; b.toggle_mode=true; b.set_pressed_no_signal(studio.system==i)
	var grid:=GridContainer.new(); grid.columns=2 if portrait else 4; grid.add_theme_constant_override("h_separation",12); grid.add_theme_constant_override("v_separation",12); body.add_child(grid)
	for index in UpgradeStudio.GROUPS[studio.system]:
		var b:=AutomotiveUI.selection(grid,GarageHub.SHORT_NAMES[index],studio.status(index),studio.headline(index),h.selected==index,108 if portrait else 98,str(GarageHub.CATEGORIES[index][0]))
		bind(b,"hub_category_%d"%index)
	button(body,"hub_test","Test this build")

func modal_content() -> void:
	var h: GarageHub=game.menu.hub; var w: UpgradeWorkshop=game.workshop; var studio: UpgradeStudio=h.studio
	var p:=PanelContainer.new(); add_child(p)
	p.position=Vector2(12,50) if portrait else Vector2(58,76)
	p.size=Vector2(576,1180) if portrait else Vector2(1084,620)
	var modal_style:=AutomotiveUI.surface(Color("0b1b28"),Color("426476"),22)
	modal_style.shadow_size=24; modal_style.shadow_color=Color(0,0,0,.4); modal_style.shadow_offset=Vector2(0,8)
	p.add_theme_stylebox_override("panel",modal_style)
	if not game.glass.reduced_motion:
		p.modulate.a=.85
		p.create_tween().tween_property(p,"modulate:a",1.0,.12)
	var body:=AutomotiveUI.column(p,14)
	var title:=AutomotiveUI.row(body)
	title.add_child(AutomotiveUI.label(str(GarageHub.CATEGORIES[h.selected][0]),26))
	var close:=button(title,"hub_back","Close  ×"); close.size_flags_horizontal=Control.SIZE_SHRINK_END; close.custom_minimum_size.x=128
	var installed_name: String=GameCatalog.stage_name(game.selected_part,int(game.profile.stages[game.selected_part])) if w.mode=="basic" else hardware_name(str(game.profile.hardware.parts.get(w.current_slot(),"")))
	var installed_row:=AutomotiveUI.row(body)
	var installed_label:=AutomotiveUI.label("INSTALLED  /  "+installed_name,15,AutomotiveUI.BLUE); installed_label.tooltip_text=installed_name; installed_row.add_child(installed_label)
	var balance:=AutomotiveUI.label("$%s available"%game.profile.credits,16,AutomotiveUI.MUTED,true); balance.custom_minimum_size.x=210; balance.size_flags_horizontal=Control.SIZE_SHRINK_END; balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; installed_row.add_child(balance)
	var sections:=GridContainer.new(); sections.columns=2 if portrait else mini(5,maxi(1,studio.sections().size())); sections.add_theme_constant_override("h_separation",8); sections.add_theme_constant_override("v_separation",8); body.add_child(sections)
	for entry in studio.sections():
		var b:=button(sections,entry.id,entry.label); b.theme_type_variation="Navigation"; b.toggle_mode=true; b.set_pressed_no_signal(entry.selected)
	var scroll:=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(scroll)
	var middle: BoxContainer=VBoxContainer.new() if portrait else HBoxContainer.new(); middle.add_theme_constant_override("separation",20); middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(middle)
	var options:=AutomotiveUI.column(middle,8); options.size_flags_stretch_ratio=1.1
	options.add_child(AutomotiveUI.label("AVAILABLE CONFIGURATIONS",12,AutomotiveUI.MUTED))
	var list:=AutomotiveUI.column(options,7)
	if w.mode=="basic":
		w.stage_preview()
		var installed: int=game.profile.stages[game.selected_part]
		for level in GameCatalog.max_stage(game.selected_part)+1:
			var state: String="Equipped" if level==installed else ("Included in build" if level<installed else "$%s"%game.profile.upgrade_cost(game.selected_part,level))
			var b:=AutomotiveUI.selection(list,GameCatalog.stage_name(game.selected_part,level),state,"",w.preview_stage==level,70 if portrait else 60,"",GlassPalette.GREEN if level==installed else AutomotiveUI.MUTED)
			bind(b,"stage_pick_%d"%level)
	else:
		var ids: Array[String]=[""]
		for id in VehicleParts.PARTS:
			if VehicleParts.PARTS[id].slot==w.current_slot(): ids.append(id)
		w.parts_page=clampi(w.parts_page,0,maxi(0,ceili(ids.size()/3.0)-1))
		for i in mini(3,ids.size()-w.parts_page*3):
			var id: String=ids[w.parts_page*3+i]; var part: Dictionary=VehicleParts.PARTS.get(id,{})
			var installed: bool=str(game.profile.hardware.parts.get(w.current_slot(),""))==id
			var owned: bool=id=="" or VehicleParts.is_owned(game.profile.hardware,id)
			var reason: String="" if id=="" else VehicleParts.compatible(id,game.profile.hardware,int(game.profile.stages[4]))
			var state: String="Equipped" if installed else (reason if reason!="" else ("Owned · install free" if owned else "$%s"%part.cost))
			if not owned and game.profile.hardware.owned_parts.has(id): state="New fitment · $%s"%part.cost
			var color:=GlassPalette.GREEN if installed else (Color("eea29b") if reason!="" else (AutomotiveUI.BLUE if owned else AutomotiveUI.MUTED))
			var b:=AutomotiveUI.selection(list,hardware_name(id),state,"",w.selected_hardware==id,86 if portrait else 78,"",color)
			bind(b,"hw_pick_"+id if id!="" else "hw_pick_factory")
	var details:=AutomotiveUI.panel(middle)
	details.add_theme_constant_override("separation",8)
	var c:=studio.candidate()
	var part: Dictionary=VehicleParts.PARTS.get(w.selected_hardware,{}) if w.mode=="hardware" else {}
	var name: String=GameCatalog.stage_name(game.selected_part,w.preview_stage) if w.mode=="basic" else hardware_name(w.selected_hardware)
	details.add_child(AutomotiveUI.label(name,24))
	var slot: String=w.current_slot() if w.mode=="hardware" else ""
	for metric in studio.metrics(game.car,c,h.selected,slot): details.add_child(AutomotiveUI.label(metric,19 if portrait else 17,studio.metric_color(metric)))
	if h.selected>=7 and (not portrait or h.selected==7):
		details.add_child(AutomotiveUI.label(studio.race_comparison(c),17,AutomotiveUI.MUTED))
	var reason: String=w.part_comparison().reason if w.mode=="hardware" else game.profile.upgrade_reason(game.selected_part)
	var note:=AutomotiveUI.label(reason if reason!="" else (UpgradeStudio.EXPLAIN.get(slot,studio.package_description(h.selected))),16,AutomotiveUI.ORANGE if reason!="" else AutomotiveUI.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; note.custom_minimum_size.y=42; details.add_child(note)
	if UpgradeStudio.engine_changed(game.car,c):
		var graph:=DynoPlot.new(); graph.current=game.car; graph.candidate=c; graph.custom_minimum_size.y=120; details.add_child(graph)
		details.add_child(AutomotiveUI.label("HP orange · Nm green / RPM ×1000",13,AutomotiveUI.MUTED))
		details.add_child(AutomotiveUI.label("Solid installed · dashed preview",13,AutomotiveUI.MUTED))
	if w.details:
		for value in (w.part_details(part) if w.mode=="hardware" else studio.package_details(h.selected)):
			var line:=AutomotiveUI.label(str(value),14,AutomotiveUI.MUTED); line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; details.add_child(line)
	var tools:=AutomotiveUI.row(body)
	if w.mode=="hardware":
		var count:=1
		for definition in VehicleParts.PARTS.values():
			if definition.slot==w.current_slot(): count+=1
		if count>3:
			for page in [["hw_prev","←"],["hw_next","→"]]:
				var page_button:=button(tools,page[0],page[1]); page_button.custom_minimum_size.x=70 if portrait else 52; page_button.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
				page_button.tooltip_text="Previous components" if page[0]=="hw_prev" else "Next components"
	button(tools,"details_toggle","Less detail" if w.details else "Details")
	button(tools,"hub_dyno","Live Dyno")
	if h.selected in [0,1,2,4,5,6,7,8]: button(tools,"sound_preview","Sound")
	# Purchase labels, compatibility and exact prices stay with the existing model.
	var current: int=game.profile.stages[game.selected_part]
	var id: String="hw_buy"; var price:=0; var text: String=""
	if w.mode=="basic":
		id="install_%d_%d"%[game.selected_part,w.preview_stage]
		price=game.profile.upgrade_cost(game.selected_part,w.preview_stage)
		text="Equipped" if current==w.preview_stage else ("Included in build" if current>w.preview_stage else "Purchase + install  /  $%s"%price)
	else:
		var owned: bool=w.selected_hardware=="" or VehicleParts.is_owned(game.profile.hardware,w.selected_hardware)
		price=0 if owned else int(part.get("cost",0))
		text="Equipped" if str(game.profile.hardware.parts.get(slot,""))==w.selected_hardware else ("Install owned part" if owned else "Purchase + install  /  $%s"%price)
	if reason!="": text="Supporting hardware required"
	elif price>game.profile.credits: text=game.missing_credits(price)
	button(body,id,text,true)
	# Short non-engine comparisons should not leave a full-height empty sheet.
	# Keep the footer fixed while long configurations use the bounded scroller.
	middle.minimum_size_changed.connect(func(): fit_sheet.call_deferred(p,middle,scroll))
	fit_sheet.call_deferred(p,middle,scroll)

func fit_sheet(p: PanelContainer,middle: BoxContainer,scroll: ScrollContainer) -> void:
	if not is_instance_valid(p) or p.is_queued_for_deletion(): return
	var fixed: float=p.get_combined_minimum_size().y-scroll.get_combined_minimum_size().y
	var desired: float=clampf(fixed+middle.get_combined_minimum_size().y+2,680 if portrait else 480,1180 if portrait else 620)
	p.size.y=desired
	p.position.y=(size.y-desired)*.5

func hardware_name(id: String) -> String:
	if id!="": return str(VehicleParts.PARTS.get(id,{}).get("name","Hardware"))
	return "Package assembly" if game.workshop.current_slot()=="induction" and game.car.turbo_stage>0 else "Factory hardware"
