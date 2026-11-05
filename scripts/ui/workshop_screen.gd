class_name WorkshopScreen
extends Control

# First migration boundary: Garage, upgrade overview and package/part purchasing.
# Complex gearbox/tuning tools keep their existing implementation for now.
var game: Node2D
var signature: String=""
var scene_key := ""
var scene_fade: Tween
var targets: Dictionary={}
var portrait:=false
var notice: PanelContainer
var notice_label: Label
var notice_skin: StyleBoxFlat
var search: LineEdit
var empty_catalog: Label
var query: String=""
var catalog_filter: int=-1
var catalog_offset: int=0
var option_offset: int=0
var confirm_quote: String=""
var quote_build_key: String=""
var quote_car: Drivetrain
var last_modal_category: int=-1
var upgrade_pointer: int=-1
var upgrade_scroll: ScrollContainer
var upgrade_touch_origin:=Vector2.ZERO
var upgrade_scroll_origin:=0
var upgrade_swipe:=false

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
	if game.tab=="performance": key+=confirm_quote
	if key!=signature:
		signature=key
		for child in get_children():
			if child is CanvasItem: child.hide()
			child.queue_free()
		targets.clear(); build()
	var next_scene := str([game.screen,game.tab,game.menu.hub.categories,game.menu.dealer.class_picker,
		game.menu.dealer.details,game.career_board.active,game.career_board.picker])
	if next_scene != scene_key:
		scene_key = next_scene
		if scene_fade: scene_fade.kill()
		modulate.a = 1.0
		if not game.profile.reduced_motion:
			modulate.a = .74
			scene_fade = create_tween()
			scene_fade.tween_property(self,"modulate:a",1.0,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif game.profile.reduced_motion and scene_fade:
		scene_fade.kill()
		modulate.a = 1.0
	publish_targets()
	if game.screen=="garage" and (game.tab!="performance" or game.menu.hub.categories): game.draw_navigation()

func canvas_size() -> Vector2:
	return Vector2(600,1300) if game.is_portrait() else Vector2(1200,760)

func editing_catalog(event: InputEventKey) -> bool:
	if not is_instance_valid(search) or not search.is_visible_in_tree() or not search.has_focus(): return false
	if event.pressed and RaceControls.key_code(event)==KEY_ESCAPE:
		search.release_focus()
		get_viewport().set_input_as_handled()
	return true

func handle_scroll_touch(event: InputEvent) -> bool:
	if not visible or game.tab!="performance" or game.screen!="garage" or not supports():
		upgrade_pointer=-1
		return false
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if is_instance_valid(search) and search.is_visible_in_tree() and search.get_global_rect().has_point(event.position):
			search.grab_focus()
			search.edit()
			return true
		for name in ["CatalogList","UpgradeOptions","UpgradeDetails"]:
			var scroll: ScrollContainer=find_child(name,true,false)
			if not is_instance_valid(scroll) or scroll.is_queued_for_deletion() or not scroll.get_global_rect().has_point(event.position): continue
			if upgrade_pointer>=0: return true
			upgrade_pointer=event.index
			upgrade_scroll=scroll
			upgrade_touch_origin=event.position
			upgrade_scroll_origin=scroll.scroll_vertical
			upgrade_swipe=false
			return true
	if event is InputEventScreenDrag and event.index==upgrade_pointer:
		if is_instance_valid(upgrade_scroll):
			var delta: float=event.position.y-upgrade_touch_origin.y
			if absf(delta)>12: upgrade_swipe=true
			if upgrade_swipe: upgrade_scroll.scroll_vertical=upgrade_scroll_origin-roundi(delta/game.scale.y)
		return true
	if event is InputEventScreenTouch and not event.pressed and event.index==upgrade_pointer:
		upgrade_pointer=-1
		if is_instance_valid(upgrade_scroll) and not upgrade_scroll.is_queued_for_deletion() and not upgrade_swipe and not event.canceled and upgrade_scroll.get_global_rect().has_point(event.position):
			game.activate_at(game.to_local(event.position),"touch_%d"%event.index)
		return true
	return false

func catalog_action(id: String) -> bool:
	if game.tab!="performance" or not visible or not supports(): return false
	var h: GarageHub=game.menu.hub
	var w: UpgradeWorkshop=game.workshop
	if id.begins_with("upgrade_system_"):
		catalog_filter=int(id.trim_prefix("upgrade_system_"))
		for i in range(-1,4): targets["upgrade_system_%d"%i].set_pressed_no_signal(i==catalog_filter)
		filter_catalog()
		return true
	if id.begins_with("hub_category_"):
		confirm_quote=""
		option_offset=0
		last_modal_category=-1
	if h.categories: return false
	if id=="catalog_gearbox":
		h.open_upgrade(7)
		w.action("work_transmission")
		return true
	if id=="catalog_cancel":
		confirm_quote=""
		return true
	if id.begins_with("stage_pick_"):
		w.mode="basic"
	elif id.begins_with("catalog_factory_") or id.begins_with("hw_pick_"):
		var slot:=id.trim_prefix("catalog_factory_") if id.begins_with("catalog_factory_") else str(VehicleParts.PARTS.get(id.trim_prefix("hw_pick_"),{}).get("slot",w.current_slot()))
		var index:=w.category_slots.find(slot)
		if index>=0:
			w.mode="hardware"
			w.slot_index=index
		if id.begins_with("catalog_factory_"):
			w.selected_hardware=""
			confirm_quote=""
			return true
	if id=="catalog_purchase" or id=="hw_buy" or id.begins_with("install_"):
		var quote:=active_quote()
		if id!=purchase_id(quote) or quote.equipped or quote.reason!="" or quote.cost>game.profile.credits: return true
		var key:=JSON.stringify(quote)
		if quote.items.size()>1 and confirm_quote!=key:
			confirm_quote=key
			return true
		var slot: String=w.current_slot() if w.mode=="hardware" else ""
		var message: String = game.profile.commit_upgrade_quote(game.selected_part,w.preview_stage,slot,w.selected_hardware,key)
		game.show_toast(message,message.begins_with("Installed ") or message=="Build updated")
		game.refresh_car()
		confirm_quote=""
		return true
	confirm_quote=""
	return false

func state_key() -> String:
	var w: UpgradeWorkshop=game.workshop
	var projection: String=""
	if game.tab=="performance" and not game.menu.hub.categories:
		var quote:=active_quote()
		projection=game.menu.hub.studio.race_comparison(quote_preview(quote) if quote.reason=="" else game.car)
	return JSON.stringify([size,game.tab,game.profile.vehicle_id,game.profile.credits,game.profile.xp,game.profile.stages,game.profile.owned_stages,game.profile.hardware,game.profile.appearance_for(game.profile.vehicle_id),game.menu.hub.categories,game.menu.hub.selected,game.menu.hub.studio.system,w.mode,w.slot_index,w.parts_page,w.preview_stage,w.selected_hardware,w.details,game.profile.muted,game.profile.effects_quality,projection,PerformanceClasses.label(game.profile)])

func _process(_delta: float) -> void:
	if not visible: return
	publish_targets()
	if is_instance_valid(notice):
		notice.visible=game.toast_left>0
		notice_label.text=("✓   " if game.toast_confirmed else "")+game.toast
		notice.modulate.a=game.toast_reveal()
		var accent := GlassPalette.GREEN if game.toast_confirmed else AutomotiveUI.BLUE
		notice_skin.border_color=Color(accent,.64)

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
	var h: GarageHub=game.menu.hub
	var modal: bool=game.tab=="performance" and not h.categories
	var short: bool=game.tab=="performance" and short_catalog()
	if not modal:
		var body:=container(Rect2(24,20,552,1100) if portrait else Rect2(36,20,size.x-72,612 if short else 630))
		if not short: header(body)
		if game.tab=="garage": garage(body)
		else: overview(body)
	if modal:
		targets.clear()
		var dim:=ColorRect.new(); dim.color=Color(0,.015,.025,.49); dim.mouse_filter=Control.MOUSE_FILTER_STOP
		add_child(dim); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		modal_content()
	build_notice()

func short_catalog() -> bool:
	return not portrait and game.get_window().size.y<500

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
	notice_skin=AutomotiveUI.surface(Color("15252c"),Color(AutomotiveUI.BLUE,.64),12)
	notice.add_theme_stylebox_override("panel",notice_skin)
	notice_label=AutomotiveUI.label(("✓   " if game.toast_confirmed else "")+game.toast,18,AutomotiveUI.INK); notice.add_child(notice_label)
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

func catalog_scroll(parent: Node, label: String, offset: int) -> ScrollContainer:
	var scroll:=ScrollContainer.new()
	scroll.name=label
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	if offset>0: restore_scroll.call_deferred(scroll,offset)
	return scroll

func restore_scroll(scroll: ScrollContainer,offset: int) -> void:
	if is_instance_valid(scroll) and not scroll.is_queued_for_deletion(): scroll.scroll_vertical=offset

func overview(body: VBoxContainer) -> void:
	var studio: UpgradeStudio=game.menu.hub.studio
	var layout: BoxContainer=AutomotiveUI.column(body,12) if portrait else AutomotiveUI.row(body,22)
	layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var hero:=AutomotiveUI.column(layout,10)
	if not portrait:
		hero.custom_minimum_size.x=326
		hero.size_flags_horizontal=Control.SIZE_FILL
	hero.add_child(AutomotiveUI.label("REDLINE  /  PERFORMANCE",14,AutomotiveUI.BLUE,true))
	hero.add_child(AutomotiveUI.label("Upgrade catalog",33))
	hero.add_child(AutomotiveUI.label(str(GameCatalog.spec(game.profile.vehicle_id).name)+"  /  %.0f hp  /  %.0f Nm"%[game.car.peak_horsepower(),GarageHub.peak_torque(game.car)],17,AutomotiveUI.MUTED))
	preview(hero,148 if portrait else 235)
	var tools:=AutomotiveUI.row(hero,8)
	button(tools,"hub_dyno","Live Dyno")
	button(tools,"hub_test","Test build")
	var catalog:=AutomotiveUI.column(layout,10)
	catalog.size_flags_vertical=Control.SIZE_EXPAND_FILL
	search=LineEdit.new()
	search.name="CatalogSearch"
	search.text=query
	search.placeholder_text="Search parts  •  turbo, tires, exhaust…"
	search.clear_button_enabled=true
	search.custom_minimum_size.y=70 if portrait else 48
	if short_catalog(): search.custom_minimum_size.y=90
	search.add_theme_font_override("font",AutomotiveUI.BODY)
	if short_catalog(): search.add_theme_font_size_override("font_size",24)
	search.add_theme_stylebox_override("normal",AutomotiveUI.glass_material("panel"))
	search.add_theme_stylebox_override("focus",AutomotiveUI.surface(Color.TRANSPARENT,AutomotiveUI.BLUE,10))
	catalog.add_child(search)
	search.text_changed.connect(func(value): query=value; filter_catalog())
	search.text_submitted.connect(func(_value): search.release_focus())
	var filters:=GridContainer.new()
	filters.columns=5
	filters.add_theme_constant_override("h_separation",6)
	filters.add_theme_constant_override("v_separation",6)
	catalog.add_child(filters)
	for i in range(-1,4):
		var control:=button(filters,"upgrade_system_%d"%i,["All","Power","Drivetrain","Chassis","Support"][i+1])
		if portrait: control.add_theme_font_size_override("font_size",15)
		control.theme_type_variation="Navigation"
		control.toggle_mode=true
		control.set_pressed_no_signal(catalog_filter==i)
	var scroll:=catalog_scroll(catalog,"CatalogList",catalog_offset)
	scroll.get_v_scroll_bar().value_changed.connect(func(value): catalog_offset=int(value))
	var list:=AutomotiveUI.column(scroll,8)
	var grid:=GridContainer.new()
	grid.columns=2 if portrait else 3
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	list.add_child(grid)
	for index in GarageHub.CATEGORIES.size():
		var title:=catalog_name(index)
		var stage_index: int=GarageHub.CATEGORIES[index][1]
		var stage: int=game.profile.stages[stage_index]
		var fitted:=studio.status(index)
		if index in GarageHub.STAGE_CATEGORIES and stage>0:
			fitted="Stage %d"%stage if index!=7 else TransmissionCatalog.STAGES[stage]
		var card:=AutomotiveUI.part_card(grid,title,fitted,studio.headline(index),str(GarageHub.CATEGORIES[index][0]),100 if portrait or short_catalog() else 84)
		bind(card,"hub_category_%d"%index)
		var words:=title+" "+str(GarageHub.CATEGORIES[index][0])+" "+studio.status(index)
		for slot in GarageHub.CATEGORY_SLOTS[index]:
			words+=" "+UpgradeWorkshop.TITLES[slot]
			for part in VehicleParts.PARTS.values():
				if part.slot==slot: words+=" "+str(part.name)
		card.set_meta("search_terms",words.to_lower())
	empty_catalog=AutomotiveUI.label("No matching parts. Try All or a different search.",20,AutomotiveUI.MUTED)
	list.add_child(empty_catalog)
	filter_catalog()

func catalog_name(index: int) -> String:
	return "Turbo & boost" if index==5 else ("Weight reduction" if index==14 else GarageHub.SHORT_NAMES[index])

func filter_catalog() -> void:
	var count:=0
	for index in GarageHub.CATEGORIES.size():
		var card: Button=targets["hub_category_%d"%index]
		var matches: bool=catalog_filter<0 or UpgradeStudio.GROUPS[catalog_filter].has(index)
		var terms: String=card.get_meta("search_terms")
		for word in query.to_lower().split(" ",false):
			if not terms.contains(word): matches=false; break
		card.visible=matches
		if matches: count+=1
	empty_catalog.visible=count==0

func active_quote() -> Dictionary:
	var w: UpgradeWorkshop=game.workshop
	if w.mode=="basic":
		if w.preview_stage<0: w.stage_preview()
		return game.profile.upgrade_quote(game.selected_part,w.preview_stage)
	return game.profile.upgrade_quote(-1,-1,w.current_slot(),w.selected_hardware)

func quote_preview(quote: Dictionary) -> Drivetrain:
	var key:=JSON.stringify([game.profile.vehicle_id,quote.build,quote.stages])
	if key!=quote_build_key:
		quote_build_key=key
		quote_car=Drivetrain.new()
		quote_car.configure_vehicle(GameCatalog.spec(game.profile.vehicle_id))
		quote_car.configure(quote.stages)
		quote_car.configure_build(quote.build,game.profile.vehicle_id,false)
	return quote_car

func modal_content() -> void:
	var h: GarageHub=game.menu.hub
	var w: UpgradeWorkshop=game.workshop
	var studio: UpgradeStudio=h.studio
	var quote:=active_quote()
	var quote_key:=JSON.stringify(quote)
	var confirming: bool=confirm_quote==quote_key and not quote.equipped and quote.reason==""
	var p:=PanelContainer.new()
	add_child(p)
	p.position=Vector2(12,42) if portrait else Vector2(58,58)
	p.size=Vector2(576,1206) if portrait else Vector2(size.x-116,644)
	p.add_theme_stylebox_override("panel",AutomotiveUI.glass_material("sheet"))
	if not game.glass.reduced_motion and last_modal_category!=h.selected:
		p.modulate.a=.82
		p.create_tween().tween_property(p,"modulate:a",1.0,.13)
	last_modal_category=h.selected
	var body:=AutomotiveUI.column(p,10)
	var title:=AutomotiveUI.row(body)
	title.add_child(AutomotiveUI.label(catalog_name(h.selected),32))
	var balance:=AutomotiveUI.label("$%d"%game.profile.credits,16,AutomotiveUI.MUTED,true)
	balance.size_flags_horizontal=Control.SIZE_SHRINK_END
	balance.custom_minimum_size.x=108
	balance.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	title.add_child(balance)
	var close:=button(title,"hub_back","Close")
	close.size_flags_horizontal=Control.SIZE_SHRINK_END
	close.custom_minimum_size.x=118
	var middle: BoxContainer=AutomotiveUI.column(body,8) if portrait else AutomotiveUI.row(body,18)
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var option_side:=AutomotiveUI.column(middle,5)
	option_side.size_flags_vertical=Control.SIZE_EXPAND_FILL
	option_side.add_child(AutomotiveUI.label("SELECT AN UPGRADE",14,AutomotiveUI.BLUE,true))
	var options:=catalog_scroll(option_side,"UpgradeOptions",option_offset)
	if portrait:
		options.custom_minimum_size.y=350
		option_side.size_flags_vertical=Control.SIZE_FILL
	options.get_v_scroll_bar().value_changed.connect(func(value): option_offset=int(value))
	var list:=AutomotiveUI.column(options,5)
	if h.selected in GarageHub.STAGE_CATEGORIES and h.selected!=5: stage_options(list)
	for slot in GarageHub.CATEGORY_SLOTS[h.selected]:
		list.add_child(AutomotiveUI.label(UpgradeWorkshop.TITLES[slot].to_upper(),14,AutomotiveUI.BLUE))
		for id in [""]+VehicleParts.PARTS.keys():
			var part: Dictionary=VehicleParts.PARTS.get(id,{})
			if id!="" and part.slot!=slot: continue
			var owned: bool=id=="" or VehicleParts.is_owned(game.profile.hardware,id)
			var fitted: bool=str(game.profile.hardware.parts.get(slot,""))==id
			var option: Dictionary=game.profile.upgrade_quote(-1,-1,slot,id)
			var state: String="Equipped" if fitted else ("Unavailable" if option.reason!="" else ("$%d incl. support"%option.cost if option.items.size()>1 else ("Owned / install free" if owned else "$%d"%part.cost)))
			var name: String="Factory hardware" if id=="" else part.name
			var row:=AutomotiveUI.selection(list,name,state,"",w.mode=="hardware" and w.current_slot()==slot and w.selected_hardware==id,90 if short_catalog() else (70 if portrait else 56),"",GlassPalette.GREEN if fitted else AutomotiveUI.MUTED)
			bind(row,"hw_pick_"+id if id!="" else "catalog_factory_"+slot)
	if h.selected==5: stage_options(list)
	var detail_scroll:=catalog_scroll(middle,"UpgradeDetails",0)
	var details:=AutomotiveUI.column(detail_scroll,8)
	var slot: String=w.current_slot() if w.mode=="hardware" else ""
	var candidate: Drivetrain=quote_preview(quote) if quote.reason=="" else game.car
	var name: String=GameCatalog.stage_name(game.selected_part,w.preview_stage) if w.mode=="basic" else hardware_name(w.selected_hardware)
	var installed_name: String=GameCatalog.stage_name(game.selected_part,int(game.profile.stages[game.selected_part])) if w.mode=="basic" else hardware_name(str(game.profile.hardware.parts.get(slot,"")))
	var heading:=AutomotiveUI.row(details,12)
	heading.add_child(AutomotiveUI.part_emblem(str(GarageHub.CATEGORIES[h.selected][0]),48))
	var labels:=AutomotiveUI.column(heading,3)
	labels.add_child(AutomotiveUI.label(name,25))
	labels.add_child(AutomotiveUI.label("Fitted  /  "+installed_name,16,AutomotiveUI.MUTED))
	if quote.reason!="": wrapped(details,quote.reason,AutomotiveUI.ORANGE)
	elif quote.items.size()>1:
		details.add_child(AutomotiveUI.label("BUILD SHEET",14,AutomotiveUI.BLUE,true))
		for item in quote.items:
			var row:=AutomotiveUI.row(details,8)
			var label:=AutomotiveUI.label(str(item.name),22 if short_catalog() else 18,AutomotiveUI.BLUE if item.support else AutomotiveUI.INK)
			label.tooltip_text="Required supporting upgrade" if item.support else "Selected upgrade"
			row.add_child(label)
			var price:=AutomotiveUI.label(("Unequip" if item.get("removal",false) else ("Equip free" if item.cost==0 else "$%d"%item.cost)),20 if short_catalog() else 16,AutomotiveUI.BLUE,true)
			price.custom_minimum_size.x=112; price.size_flags_horizontal=Control.SIZE_SHRINK_END
			price.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(price)
			if item.get("removal",false): wrapped(details,str(item.reason)+" • stays owned",AutomotiveUI.MUTED)
			elif item.replaces!="": wrapped(details,"Replaces "+str(item.replaces),AutomotiveUI.MUTED)
	if confirming: wrapped(details,"Confirm to fit everything listed in one purchase.",AutomotiveUI.ORANGE)
	details.add_child(HSeparator.new())
	details.add_child(AutomotiveUI.label("PERFORMANCE  /  CURRENT → SELECTED",14,AutomotiveUI.BLUE,true))
	for metric in studio.metrics(game.car,candidate,h.selected,slot):
		details.add_child(AutomotiveUI.label(metric,22 if short_catalog() else 18,studio.metric_color(metric)))
	if quote.reason=="":
		details.add_child(AutomotiveUI.label(studio.race_comparison(candidate),16,AutomotiveUI.MUTED))
	wrapped(details,UpgradeStudio.EXPLAIN.get(slot,studio.package_description(h.selected)),AutomotiveUI.MUTED)
	if UpgradeStudio.engine_changed(game.car,candidate):
		var graph:=DynoPlot.new()
		graph.current=game.car; graph.candidate=candidate; graph.custom_minimum_size.y=126
		details.add_child(graph)
		details.add_child(AutomotiveUI.label("HP orange  /  Nm green  /  RPM ×1000",14,AutomotiveUI.MUTED))
		details.add_child(AutomotiveUI.label("Solid installed  /  dashed preview",14,AutomotiveUI.MUTED))
	if w.details:
		var part: Dictionary=VehicleParts.PARTS.get(w.selected_hardware,{})
		for value in (w.part_details(part) if w.mode=="hardware" else studio.package_details(h.selected)):
			wrapped(details,str(value),AutomotiveUI.MUTED)
	var tools:=AutomotiveUI.row(body,8)
	button(tools,"details_toggle","Less detail" if w.details else "Details")
	button(tools,"hub_dyno","Live Dyno")
	if h.selected==7: button(tools,"upgrade_section_transmission","Gearbox")
	elif quote.reason!="" and VehicleParts.TRANSMISSION_SLOTS.has(slot): button(tools,"catalog_gearbox","Gearbox")
	if GarageHub.TUNE_KEYS.has(h.selected): button(tools,"upgrade_section_tune","Tuning")
	elif h.selected in [0,1,2,8]: button(tools,"sound_preview","Sound")
	var price: int=quote.cost
	var text: String="Purchase & install  /  $%d"%price if price>0 else "Equip Free"
	if quote.items.size()>1: text=("Confirm changes" if confirming else "Equip Free") if price==0 else ("Confirm installation" if confirming else "Purchase & install all")+"  /  $%d"%price
	if quote.equipped: text="Equipped"
	elif quote.reason!="": text="Unavailable"
	elif price>game.profile.credits: text=game.missing_credits(price)
	var footer:=AutomotiveUI.row(body,8)
	if confirming: button(footer,"catalog_cancel","Cancel")
	var purchase:=button(footer,purchase_id(quote),text,true)
	purchase.disabled=quote.equipped or quote.reason!="" or price>game.profile.credits

func stage_options(list: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub
	var w: UpgradeWorkshop=game.workshop
	list.add_child(AutomotiveUI.label(UpgradeStudio.PACKAGE_NAMES[h.selected].to_upper(),14,AutomotiveUI.MUTED))
	var installed: int=game.profile.stages[game.selected_part]
	for tier in GameCatalog.max_stage(game.selected_part)+1:
		var quote: Dictionary=game.profile.upgrade_quote(game.selected_part,tier)
		var state: String="Equipped" if tier==installed else ("Owned" if tier<=game.profile.highest_stage(game.selected_part) else "Purchase / $%d"%quote.cost)
		if quote.items.size()>1: state+=" incl. support"
		var row:=AutomotiveUI.selection(list,GameCatalog.stage_name(game.selected_part,tier),state,"",w.mode=="basic" and w.preview_stage==tier,90 if short_catalog() else (70 if portrait else 56),"",GlassPalette.GREEN if tier==installed else AutomotiveUI.MUTED)
		bind(row,"stage_pick_%d"%tier)

func purchase_id(quote: Dictionary) -> String:
	if quote.items.size()>1: return "catalog_purchase"
	var w: UpgradeWorkshop=game.workshop
	return "install_%d_%d"%[game.selected_part,w.preview_stage] if w.mode=="basic" else "hw_buy"

func wrapped(parent: Node,value: String,color: Color) -> void:
	var line:=AutomotiveUI.label(value,16,color)
	line.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(line)

func hardware_name(id: String) -> String:
	if id!="": return str(VehicleParts.PARTS.get(id,{}).get("name","Hardware"))
	return "Package assembly" if game.workshop.current_slot()=="induction" and game.car.turbo_stage>0 else "Factory hardware"
