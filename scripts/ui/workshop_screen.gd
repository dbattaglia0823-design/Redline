class_name WorkshopScreen
extends Control

# The workbench uses the same purchase quotes and action dispatch as the garage.
var game: Node2D
var signature: String=""
var scene_key := ""
var scene_fade: Tween
var targets: Dictionary={}
var saved_scrolls := MenuScrollState.new()
var scroll_scope := ""
var scroll_revision := 0
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
var detail_offset: int=0
var confirm_quote: String=""
var vehicle_template: ToolkitVehicleScreen
var dealer_query := ""
var dealer_filter := 0
var dealer_ui_class := -1

func template_action(id: String) -> bool:
	if not is_instance_valid(vehicle_template) or not vehicle_template.is_visible_in_tree() or vehicle_template.screen_type!="dealership": return false
	if id in ["shop_car_prev","shop_car_next"]:
		var ids: Array=vehicle_template.visible_inventory().map(func(item): return item.id)
		if not ids.is_empty():
			var current: int=ids.find(GameCatalog.CAR_IDS[game.dealer_index])
			var next: int=(0 if id=="shop_car_next" else ids.size()-1) if current<0 else posmod(current+(-1 if id=="shop_car_prev" else 1),ids.size())
			game.action("dealer_%d"%GameCatalog.CAR_IDS.find(ids[next]))
		return true
	if id!="dealer_catalog_filter": return false
	dealer_filter=(dealer_filter+1)%3
	vehicle_template.catalog_items=vehicle_template.visible_inventory()
	vehicle_template.rebuild_catalog()
	return true
var quote_build_key: String=""
var quote_car: Drivetrain
var upgrade_pointer: int=-1
var upgrade_scroll: ScrollContainer
var upgrade_touch_origin:=Vector2.ZERO
var upgrade_scroll_origin:=0
var upgrade_swipe:=false
var install_flash_pending:=false

const PART_FAMILIES := ["engine","intake","exhaust","fuel","ecu","turbo","bottle","gearbox","clutch","differential","tire","suspension","brake","wheel","carbon"]
const PART_ACCENTS := ["78b7dc","95c8ac","bfa5e7","e8b876","73c3d2","f0ad72","65cdea","8fabe6","b7a7d1","93c8c6","d5bd7e","9cbea8","df958f","aabed7","83c2b5"]
const PART_ART := {"fuel_injectors":"fuel_rail","fuel_ethanol":"fuel_rail","clutch_carbon":"carbon_clutch","gear_pro":"gearset_billet","ecu_track":"ecu_track","ecu_race":"ecu_track","internals":"rotating","displacement":"rotating","compression":"rotating","boost":"ecu","roots":"roots","street_radial":"radial","competition_radial":"radial","drag_slicks":"slick","pro_drag_slicks":"slick","pro_drag_radial":"radial"}

class PartPlate extends Control:
	var texture: Texture2D
	var tint: Color

	func _draw() -> void:
		if size.x<=0 or size.y<=0: return
		draw_rect(Rect2(Vector2.ZERO,size),Color("101a22"))
		for fraction in [.25,.5,.75]:
			draw_line(Vector2(size.x*fraction,0),Vector2(size.x*fraction,size.y),Color(tint,.10))
			draw_line(Vector2(0,size.y*fraction),Vector2(size.x,size.y*fraction),Color(tint,.10))
		AutomotiveUI.glow(self,Rect2(Vector2.ZERO,size),Color(tint,.40))
		var scale_factor:=minf(size.x/texture.get_width(),size.y/texture.get_height())
		var image_size:=texture.get_size()*scale_factor
		draw_texture_rect(texture,Rect2((size-image_size)*.5,image_size),false)
		draw_line(Vector2(0,size.y-1),Vector2(size.x*.34,size.y-1),tint,1.5)

class CompareRails extends Control:
	var installed: float
	var proposed: float
	var ink: Color

	func _draw() -> void:
		var scale_factor:=size.x/maxf(maxf(installed,proposed)*1.12,.01)
		draw_rect(Rect2(0,0,size.x,3),Color("2c3a43"))
		draw_rect(Rect2(0,4,size.x,4),Color("2c3a43"))
		draw_rect(Rect2(0,0,installed*scale_factor,3),Color("8094a1"))
		draw_rect(Rect2(0,4,proposed*scale_factor,4),ink)

class InstallSweep extends Control:
	var phase := 0.0:
		set(value):
			phase=value
			queue_redraw()

	func _draw() -> void:
		var x:=lerpf(-size.x*.22,size.x*1.22,phase)
		var alpha:=sin(phase*PI)
		AutomotiveUI.glow(self,Rect2(x-size.x*.19,0,size.x*.38,size.y),Color(.37,.95,.77,.48*alpha))
		draw_line(Vector2(x+size.y*.18,0),Vector2(x,size.y),Color(.63,1,.84,.60*alpha),2,true)
		draw_rect(Rect2(Vector2.ZERO,size),Color(.47,.94,.78,.52*alpha),false,2)

class BoostPlot extends Control:
	var current: Drivetrain
	var candidate: Drivetrain

	func _draw() -> void:
		var area:=Rect2(30,7,size.x-42,size.y-27)
		if not area.has_area(): return
		var rpm_max:=maxf(current.redline_rpm,candidate.redline_rpm)
		var pressure_max:=maxf(.25,maxf(current.boost_target(rpm_max,1),candidate.boost_target(rpm_max,1)))*1.1
		for line in 3:
			var y:=area.end.y-area.size.y*line/2.0
			draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("344657"))
			draw_string(AutomotiveUI.NUMBERS,Vector2(0,y+4),"%.1f"%PressureUnits.psi(pressure_max*line/2.0),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
		draw_string(AutomotiveUI.NUMBERS,Vector2(area.position.x,area.end.y+16),"0 RPM",HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
		draw_string(AutomotiveUI.NUMBERS,Vector2(area.end.x-62,area.end.y+16),"%d RPM"%int(rpm_max),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
		for car in [current,candidate]:
			var points:=PackedVector2Array()
			for sample in 49:
				var fraction:=sample/48.0
				var pressure: float=car.boost_target(rpm_max*fraction,1)
				points.append(Vector2(area.position.x+area.size.x*fraction,area.end.y-area.size.y*pressure/pressure_max))
			draw_polyline(points,AutomotiveUI.ORANGE if car==candidate else AutomotiveUI.BLUE,2.0,true)

class DynoPlot extends Control:
	var current: Drivetrain
	var candidate: Drivetrain
	func _draw() -> void:
		var bounds:=Rect2(36,12,size.x-46,size.y-40)
		if bounds.size.x<10: return
		var maximum: float=maxf(1,maxf(current.peak_horsepower(),candidate.peak_horsepower()))
		maximum=maxf(maximum,maxf(ImperialUnits.torque(GarageHub.peak_torque(current)),ImperialUnits.torque(GarageHub.peak_torque(candidate))))*1.1
		for i in 4:
			var y: float=bounds.end.y-bounds.size.y*i/3
			draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color("ffffff10"),1)
			draw_string(AutomotiveUI.NUMBERS,Vector2(0,y+4),"%.0f"%(maximum*i/3),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
		var limit: float=maxf(current.redline_rpm,candidate.redline_rpm)
		for pass_index in 2:
			var build:=current if pass_index==0 else candidate
			for torque in [false,true]:
				var points:=PackedVector2Array()
				for i in range(65):
					var rpm: float=lerpf(build.idle_rpm,build.redline_rpm,float(i)/64)
					var value: float=build.full_engine_torque(rpm)
					if not torque: value=value*rpm/7127.0
					else: value=ImperialUnits.torque(value)
					points.append(Vector2(bounds.position.x+bounds.size.x*rpm/limit,bounds.end.y-bounds.size.y*value/maximum))
				var color:=Color("a9ced5") if torque else AutomotiveUI.ORANGE
				if pass_index==0:
					color.a=.45
					for i in range(0,64,3): draw_line(points[i],points[i+1],color,1.5,true)
				else: draw_polyline(points,color,2.2,true)
		for i in 4:
			var x: float=bounds.position.x+bounds.size.x*i/3
			draw_string(AutomotiveUI.NUMBERS,Vector2(x-12,size.y-7),"%.1fk"%(limit*i/3000),HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)

func setup(g: Node2D) -> void:
	game=g; mouse_filter=Control.MOUSE_FILTER_IGNORE; theme=AutomotiveUI.theme_resource()

func supports() -> bool:
	if game.glass.legacy and game.tab!="garage" and not (game.tab=="performance" and not game.menu.hub.categories and game.menu.hub.selected in [5,7]): return false
	if game.screen!="garage" or game.menu.hub.dyno_open: return false
	if game.tab=="garage": return true
	if game.tab!="performance": return false
	return game.menu.hub.categories or game.workshop.mode in ["basic","hardware","transmission"]

func bind(b: Button,id: String) -> void:
	b.name=id; b.disabled=not game.action_enabled(id)
	b.focus_mode=Control.FOCUS_ALL
	b.focus_entered.connect(func(): game.glass.focused=id)
	b.pressed.connect(func(): game.action(id))
	targets[id]=b

func button(parent: Node,id: String,title: String,primary: bool=false) -> Button:
	var b:=AutomotiveUI.button(parent,title,"Primary" if primary else "Secondary",70 if portrait else 46)
	bind(b,id); return b

func _scroll_context() -> String:
	if game.screen=="results": return "results"
	if game.screen!="garage": return game.screen
	# Stable across item selection, purchases, search/filter, and subpage redraws.
	# Distinct scopes prevent a scrollbar from one menu being imposed on another.
	if game.tab=="performance":
		return "performance_overview" if game.menu.hub.categories else "performance_detail_"+str(game.menu.hub.selected)+"_"+str(game.workshop.mode)
	if game.tab=="dealer":
		return "dealer_classes_"+game.menu.dealer.vehicle_type if game.menu.dealer.class_picker else "dealer_inventory_"+game.menu.dealer.vehicle_type+"_"+str(game.menu.dealer.class_filter)
	if game.tab=="style": return "style_"+game.menu.customize.category
	return game.tab

func _restore_menu_scrolls(context: String, revision: int) -> void:
	# Containers need one layout frame to determine their scroll ranges.
	await get_tree().process_frame
	if not is_inside_tree() or revision!=scroll_revision or not visible or _scroll_context()!=context: return
	saved_scrolls.restore(self,context)

func sync() -> void:
	visible=supports()
	if not visible: return
	portrait=game.is_portrait(); size=canvas_size()
	var key:=state_key()
	if game.tab=="performance": key+=confirm_quote
	if key!=signature:
		if scroll_scope!="": saved_scrolls.remember(self,scroll_scope)
		var next_scope:=_scroll_context()
		scroll_scope=next_scope
		scroll_revision+=1
		signature=key
		for child in get_children():
			if child is CanvasItem: child.hide()
			remove_child(child)
			child.queue_free()
		targets.clear(); build()
		_restore_menu_scrolls(next_scope,scroll_revision)
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
	var results: bool=game.screen=="results"
	if not visible or (not results and (game.tab!="performance" or game.screen!="garage")) or not supports():
		upgrade_pointer=-1
		return false
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		if is_instance_valid(search) and search.is_visible_in_tree() and search.get_global_rect().has_point(event.position):
			search.grab_focus()
			search.edit()
			return true
		for name in (["TimeSlip"] if results else ["CatalogList","UpgradeOptions","UpgradeDetails"]):
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
			if absf(delta)>8: upgrade_swipe=true
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
		catalog_filter=clampi(int(id.trim_prefix("upgrade_system_")),-1,UpgradeStudio.GROUPS.size()-1)
		for i in range(-1,UpgradeStudio.GROUPS.size()): targets["upgrade_system_%d"%i].set_pressed_no_signal(i==catalog_filter)
		filter_catalog()
		return true
	if id.begins_with("hub_category_"):
		confirm_quote=""
		option_offset=0
		detail_offset=0
	if h.categories: return false
	if id=="catalog_gearbox":
		h.open_upgrade(7)
		w.action("work_transmission")
		return true
	if id=="catalog_cancel":
		confirm_quote=""
		return true
	if id.begins_with("tx_pick_"):
		w.mode="transmission"
		w.selected_trans=id.trim_prefix("tx_pick_")
		detail_offset=0
		return true
	if w.mode=="transmission" and id=="tx_buy":
		if game.action_enabled(id):
			var message: String=game.profile.install_transmission(w.selected_trans)
			install_flash_pending=message.begins_with("Installed ")
			game.show_toast(message,install_flash_pending)
			game.refresh_car()
		return true
	if id=="system_tuning":
		game.tuning.open(TuningSetup.GROUPS.keys().find("Gearbox" if h.selected==7 else "Power"))
		return true
	if id.begins_with("system_pick_"):
		var slot:=id.trim_prefix("system_pick_")
		w.mode="hardware"
		w.slot_index=w.category_slots.find(slot)
		w.selected_hardware="" if game.profile.hardware.parts.has(slot) else slot
		detail_offset=0
		confirm_quote=""
		return true
	if id.begins_with("stage_pick_"):
		w.mode="basic"
		detail_offset=0
	elif id.begins_with("catalog_factory_") or id.begins_with("hw_pick_"):
		detail_offset=0
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
		install_flash_pending=message.begins_with("Installed ") or message=="Build updated"
		game.show_toast(message,install_flash_pending)
		game.refresh_car()
		confirm_quote=""
		return true
	confirm_quote=""
	return false

func state_key() -> String:
	var w: UpgradeWorkshop=game.workshop
	var projection: String=""
	if game.tab=="performance" and not game.menu.hub.categories:
		var studio: UpgradeStudio=game.menu.hub.studio
		var candidate: Drivetrain
		if w.mode=="transmission":
			candidate=studio.transmission_candidate() if transmission_lock(w.selected_trans)=="" else game.car
		else:
			var quote:=active_quote()
			candidate=quote_preview(quote) if quote.reason=="" else game.car
		projection=str(studio.build_runs(candidate).map(func(run): return [run.get("zero_60_s"),run.get("quarter_et_s",run.get("quarter_s")),run.get("sixty_ft_s"),run.get("wheelspin_s")]))
	return JSON.stringify([size,game.scale,game.get_window().size,game.tab,game.profile.vehicle_id,game.profile.credits,game.profile.xp,game.profile.stages,game.profile.owned_stages,game.profile.hardware,game.profile.appearance_for(game.profile.vehicle_id),game.menu.hub.categories,game.menu.hub.selected,game.menu.hub.studio.system,w.mode,w.slot_index,w.parts_page,w.preview_stage,w.selected_hardware,w.selected_trans,w.filter_index,w.page,w.details,game.profile.muted,game.profile.effects_quality,game.profile.reduced_motion,game.profile.garage if game.tab=="garage" else {},projection,PerformanceClasses.label(game.profile)])

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
		var target_height:=86 if game.tab=="style" and short_catalog() else (70 if portrait else 40)
		if not r.has_area() or r.size.y<minf(b.size.y,target_height): continue
		game.buttons.append({"id":id,"rect":r,"disabled":b.disabled,"native_control":b,"native_owner":self})
		if game.glass.focused==id and not b.disabled and not b.has_focus(): b.grab_focus()

func container(rect: Rect2) -> VBoxContainer:
	var margin:=MarginContainer.new(); add_child(margin); margin.position=rect.position; margin.size=rect.size
	margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return AutomotiveUI.column(margin,18 if portrait else 14)

func build() -> void:
	var browse: bool=game.menu.hub.categories
	var workbench: bool=game.tab=="performance"
	if not workbench:
		var background:=TextureRect.new(); add_child(background)
		background.name="GarageEnvironment"
		background.texture=load(GarageShowroom.PORTRAIT_PATH if portrait else GarageShowroom.SCENE_PATH)
		background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.size=size; background.modulate=Color(.45,.48,.52); background.mouse_filter=Control.MOUSE_FILTER_IGNORE
		vehicle_template=ToolkitVehicleScreen.new(); add_child(vehicle_template)
		vehicle_template.setup(self,"garage",Rect2(24 if portrait or short_catalog() else 36,18,size.x-(48 if portrait or short_catalog() else 72),1100 if portrait else 614 if short_catalog() else 630))
		build_notice(); return
	var height:=1110.0 if portrait else (612.0 if short_catalog() else 630.0)
	if workbench and not browse: height=1244.0 if portrait else 716.0
	var body:=container(Rect2(24,18,size.x-48,height) if portrait or short_catalog() else Rect2(36,20,size.x-72,height))
	if workbench:
		body.add_theme_constant_override("separation",10)
		if browse: overview(body)
		elif game.menu.hub.selected in [5,7]: system_shop(body,game.menu.hub.selected==7)
		else: detail_workspace(body)
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
	var system_detail: bool=game.tab=="performance" and not game.menu.hub.categories and game.menu.hub.selected in [5,7]
	var notice_y := (1116 if portrait else (590 if short_catalog() else 622)) if system_detail else (74 if portrait else 66)
	notice.position=Vector2(24 if portrait else 350,notice_y)
	notice.size=Vector2(552,62) if portrait else Vector2(500,48)
	if is_instance_valid(vehicle_template) and vehicle_template.is_inside_tree() and vehicle_template.controls.has("vehicle_preview"):
		var preview: Control=vehicle_template.controls.vehicle_preview
		notice.position=vehicle_template.position+preview.position+Vector2(12,10)
		notice.size=Vector2(minf(500,preview.size.x-24),62 if portrait else 48)
	notice_skin=AutomotiveUI.surface(Color("15252c"),Color(AutomotiveUI.BLUE,.64),12)
	notice.add_theme_stylebox_override("panel",notice_skin)
	notice_label=AutomotiveUI.label(("✓   " if game.toast_confirmed else "")+game.toast,18,AutomotiveUI.INK); notice.add_child(notice_label)
	notice_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice_label.max_lines_visible=2
	notice.visible=game.toast_left>0

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

func workshop_heading(body: VBoxContainer,section: String,back: bool) -> void:
	var row:=AutomotiveUI.row(body,10)
	var title:=AutomotiveUI.column(row,2)
	if short_catalog() and not back:
		title.add_child(AutomotiveUI.label("PARTS SHOP  /  "+section,32))
	else:
		AutomotiveUI.section_mark(title,"REDLINE PARTS SHOP","performance",AutomotiveUI.BLUE)
		title.add_child(AutomotiveUI.label(section,34 if not short_catalog() else 39))
	var wallet:=AutomotiveUI.label("$%d"%game.profile.credits,18,AutomotiveUI.INK,true)
	wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	wallet.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	wallet.custom_minimum_size.x=100
	wallet.size_flags_horizontal=Control.SIZE_SHRINK_END
	row.add_child(wallet)
	if back:
		var close:=button(row,"hub_back","‹ Parts")
		close.size_flags_horizontal=Control.SIZE_SHRINK_END
		close.custom_minimum_size.x=115

func workshop_hero(parent: Node,candidate: Drivetrain,minimum_width: float,height: float,caption: String) -> VBoxContainer:
	var hero:=AutomotiveUI.column(parent,6)
	if not portrait:
		hero.custom_minimum_size.x=minimum_width
		hero.size_flags_horizontal=Control.SIZE_FILL
	hero.add_child(AutomotiveUI.label(caption,13,AutomotiveUI.ORANGE,true))
	hero.add_child(AutomotiveUI.label(str(GameCatalog.spec(game.profile.vehicle_id).name),30 if not short_catalog() else 35))
	var view:=VehiclePreview.new()
	hero.add_child(view)
	view.configure(game,game.profile.vehicle_id,candidate,game.profile.appearance_for(game.profile.vehicle_id),true,height,false)
	view.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if install_flash_pending:
		install_flash_pending=false
		if not game.profile.reduced_motion and game.profile.effects_quality>0:
			var sweep:=InstallSweep.new()
			sweep.mouse_filter=Control.MOUSE_FILTER_IGNORE
			view.add_child(sweep)
			sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var animation:=sweep.create_tween()
			animation.tween_property(sweep,"phase",1.0,.58).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			animation.tween_callback(sweep.queue_free)
	hero.add_child(AutomotiveUI.label("%.0f HP / %.0f lb-ft / %.2f GRIP"%[candidate.peak_horsepower(),ImperialUnits.torque(GarageHub.peak_torque(candidate)),GarageHub.grip(candidate)],17,AutomotiveUI.INK,true))
	return hero

func overview(body: VBoxContainer) -> void:
	var studio: UpgradeStudio=game.menu.hub.studio
	workshop_heading(body,"Shop by system",false)
	var layout: BoxContainer=AutomotiveUI.column(body,10) if portrait else AutomotiveUI.row(body,24)
	layout.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var hero:=workshop_hero(layout,game.car,400 if not short_catalog() else 500,144 if portrait else 230,"01  /  INSTALLED BUILD")
	var tools:=AutomotiveUI.row(hero,8)
	button(tools,"hub_dyno","Live Dyno")
	button(tools,"hub_test","Test build")
	button(tools,"open_tuning","Tuning")
	var catalog:=AutomotiveUI.column(layout,5 if short_catalog() else 10)
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
	search.add_theme_stylebox_override("normal",AutomotiveUI.surface(Color("15161b"),Color("35343a"),4))
	search.add_theme_stylebox_override("focus",AutomotiveUI.surface(Color.TRANSPARENT,AutomotiveUI.BLUE,10))
	catalog.add_child(search)
	search.focus_entered.connect(func(): game.glass.focused="")
	search.text_changed.connect(func(value): query=value; filter_catalog())
	search.text_submitted.connect(func(_value): search.release_focus())
	var filters:=GridContainer.new()
	filters.columns=UpgradeStudio.GROUPS.size()+1
	filters.add_theme_constant_override("h_separation",6)
	filters.add_theme_constant_override("v_separation",6)
	catalog.add_child(filters)
	for i in range(-1,UpgradeStudio.GROUPS.size()):
		var control:=button(filters,"upgrade_system_%d"%i,["All","Power","Drivetrain","Chassis"][i+1])
		if portrait: control.add_theme_font_size_override("font_size",15)
		control.theme_type_variation="Navigation"
		control.toggle_mode=true
		control.set_pressed_no_signal(catalog_filter==i)
	var scroll:=catalog_scroll(catalog,"CatalogList",catalog_offset)
	scroll.get_v_scroll_bar().value_changed.connect(func(value): catalog_offset=int(value))
	var list:=AutomotiveUI.column(scroll,8)
	var grid:=GridContainer.new()
	grid.columns=4 if short_catalog() else (2 if portrait else 3)
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",4)
	list.add_child(grid)
	for index in GarageHub.CATEGORIES.size():
		var title:=catalog_name(index)
		var stage_index: int=GarageHub.CATEGORIES[index][1]
		var stage: int=game.profile.stages[stage_index]
		var fitted:=studio.status(index)
		if index in GarageHub.STAGE_CATEGORIES and stage>0:
			fitted="Stage %d"%stage if index!=7 else TransmissionCatalog.STAGES[stage]
		var card:=part_card(grid,{8:"Clutch / conv.",14:"Weight"}.get(index,title),fitted,index,"","",false,AutomotiveUI.MUTED,true)
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

func detail_workspace(body: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub
	var w: UpgradeWorkshop=game.workshop
	var studio: UpgradeStudio=h.studio
	var quote:=active_quote()
	var quote_key:=JSON.stringify(quote)
	var confirming: bool=confirm_quote==quote_key and not quote.equipped and quote.reason==""
	var candidate: Drivetrain=quote_preview(quote) if quote.reason=="" else game.car
	var show_dyno: bool=h.selected in [0,1,2,3,4,5] and quote.reason==""
	workshop_heading(body,catalog_name(h.selected),true)
	var middle: BoxContainer=AutomotiveUI.column(body,8) if portrait else AutomotiveUI.row(body,17)
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var hero:=workshop_hero(middle,candidate,354 if not short_catalog() else 475,154 if portrait else 140,"02  /  "+("INSTALLED BUILD" if quote.equipped or quote.reason!="" else "BUILD PREVIEW"))
	if not portrait and show_dyno: dyno_preview(hero,candidate)
	var option_side:=AutomotiveUI.column(middle,5)
	option_side.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if not portrait:
		option_side.custom_minimum_size.x=295 if not short_catalog() else 420
		option_side.size_flags_horizontal=Control.SIZE_FILL
	option_side.add_child(AutomotiveUI.label("PARTS  /  SELECT TO COMPARE",14,AutomotiveUI.ORANGE,true))
	var options:=catalog_scroll(option_side,"UpgradeOptions",option_offset)
	if portrait:
		options.custom_minimum_size.y=266
		option_side.size_flags_vertical=Control.SIZE_FILL
	options.get_v_scroll_bar().value_changed.connect(func(value): option_offset=int(value))
	var list:=AutomotiveUI.column(options,4)
	if h.selected in GarageHub.STAGE_CATEGORIES and h.selected!=5: stage_options(list)
	for slot in GarageHub.CATEGORY_SLOTS[h.selected]:
		list.add_child(AutomotiveUI.label(UpgradeWorkshop.TITLES[slot].to_upper(),13,AutomotiveUI.MUTED,true))
		var choices: Container=option_grid(list)
		for id in [""]+VehicleParts.PARTS.keys():
			var part: Dictionary=VehicleParts.PARTS.get(id,{})
			if id!="" and part.slot!=slot: continue
			var owned: bool=id=="" or VehicleParts.is_owned(game.profile.hardware,id)
			var fitted: bool=str(game.profile.hardware.parts.get(slot,""))==id
			var option: Dictionary=game.profile.upgrade_quote(-1,-1,slot,id)
			var state: String="Equipped" if fitted else ("Locked" if option.reason!="" else ("Owned / equip free" if owned and option.cost==0 else "%s / $%d"%["Owned" if owned else "Available",option.cost]))
			var name: String=VehicleParts.factory_name(slot) if id=="" else part.name
			var selected: bool=w.mode=="hardware" and w.current_slot()==slot and w.selected_hardware==id
			var ink:=GlassPalette.GREEN if fitted else (Color("e9a39a") if option.reason!="" else (AutomotiveUI.BLUE if owned else AutomotiveUI.INK))
			var row:=part_card(choices,name,state,h.selected,slot,id,selected,ink)
			if option.reason!="": row.tooltip_text=option.reason
			bind(row,"hw_pick_"+id if id!="" else "catalog_factory_"+slot)
	if h.selected==5: stage_options(list)
	var details:=detail_panel(middle)
	var slot: String=w.current_slot() if w.mode=="hardware" else ""
	var name: String=GameCatalog.stage_name(game.selected_part,w.preview_stage) if w.mode=="basic" else hardware_name(w.selected_hardware)
	var installed_name: String=GameCatalog.stage_name(game.selected_part,int(game.profile.stages[game.selected_part])) if w.mode=="basic" else hardware_name(str(game.profile.hardware.parts.get(slot,"")))
	var heading:=AutomotiveUI.row(details,12)
	heading.add_child(component_art(h.selected,slot,w.selected_hardware if w.mode=="hardware" else "",Vector2(118,72) if portrait else Vector2(139,82)))
	var labels:=AutomotiveUI.column(heading,3)
	labels.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var part_name:=AutomotiveUI.label(name,25)
	part_name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	part_name.max_lines_visible=2
	part_name.custom_minimum_size.y=42
	labels.add_child(part_name)
	labels.add_child(AutomotiveUI.label("Fitted  /  "+installed_name,16,AutomotiveUI.MUTED))
	if quote.reason!="": wrapped(details,quote.reason,AutomotiveUI.ORANGE)
	elif quote.items.size()>1:
		details.add_child(AutomotiveUI.label("BUILD SHEET",14,AutomotiveUI.BLUE,true))
		for item in quote.items:
			var row:=AutomotiveUI.row(details,8)
			var label:=AutomotiveUI.label(("Required / " if item.support else "")+str(item.name),22 if short_catalog() else 18,AutomotiveUI.BLUE if item.support else AutomotiveUI.INK)
			label.tooltip_text="Required supporting upgrade" if item.support else "Selected upgrade"
			row.add_child(label)
			var price:=AutomotiveUI.label(("Unequip" if item.get("removal",false) else ("Equip free" if item.cost==0 else "$%d"%item.cost)),20 if short_catalog() else 16,AutomotiveUI.BLUE,true)
			price.custom_minimum_size.x=112; price.size_flags_horizontal=Control.SIZE_SHRINK_END
			price.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(price)
			if item.get("removal",false): wrapped(details,str(item.reason)+" • stays owned",AutomotiveUI.MUTED)
			elif item.replaces!="": wrapped(details,"Replaces "+str(item.replaces),AutomotiveUI.MUTED)
	if confirming: wrapped(details,"Confirm to fit everything listed in one purchase.",AutomotiveUI.ORANGE)
	if quote.reason=="":
		details.add_child(HSeparator.new())
		details.add_child(AutomotiveUI.label("PERFORMANCE  /  INSTALLED → PREVIEW",14,AutomotiveUI.BLUE,true))
		performance_rails(details,candidate)
		if portrait and show_dyno: dyno_preview(details,candidate)
		var specs:=studio.metrics(game.car,candidate,h.selected,slot)
		for metric in specs:
			if metric.begins_with("Power  ") or metric.begins_with("Torque  ") or metric.begins_with("Mass  ") or metric.begins_with("Vehicle mass  ") or metric.begins_with("Grip  ") or metric.begins_with("Road grip  "): continue
			AutomotiveUI.metric_row(details,metric,studio.metric_color(metric))
		if slot in ["tires","suspension","wheels","clutch"]:
			for row in studio.traction_projection(candidate):
				if slot=="clutch" and not row.begins_with("Clutch slip time"): continue
				if slot!="clutch" and not row.begins_with("60-foot ET") and not row.begins_with("Time in wheelspin"): continue
				AutomotiveUI.metric_row(details,row,studio.metric_color(row))
	wrapped(details,UpgradeStudio.EXPLAIN.get(slot,studio.package_description(h.selected)),AutomotiveUI.MUTED)
	if w.details:
		var part: Dictionary=VehicleParts.PARTS.get(w.selected_hardware,{})
		for value in (w.part_details(part) if w.mode=="hardware" else studio.package_details(h.selected)):
			wrapped(details,str(value),AutomotiveUI.MUTED)
	var actions: BoxContainer=AutomotiveUI.column(body,6) if portrait else AutomotiveUI.row(body,12)
	var tools:=AutomotiveUI.row(actions,6)
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
	elif quote.reason!="": text="Locked"
	elif price>game.profile.credits: text=game.missing_credits(price)
	var footer:=AutomotiveUI.row(actions,8)
	if not portrait: footer.size_flags_stretch_ratio=.82
	if confirming: button(footer,"catalog_cancel","Cancel")
	var purchase:=button(footer,purchase_id(quote),text,true)
	purchase.disabled=quote.equipped or quote.reason!="" or price>game.profile.credits

func transmission_lock(id: String) -> String:
	if not game.profile.pending_wager.is_empty(): return "Finish your race first"
	if not TransmissionCatalog.compatible(id,game.profile.vehicle_id): return "Incompatible drivetrain layout"
	var required:=int(TransmissionCatalog.spec(id).stage)
	if not game.profile.hardware.owned_transmissions.has(id) and game.profile.transmission_unlock_stage()<required: return TransmissionCatalog.STAGES[required]+" gearbox build required"
	return ""

func system_shop(body: VBoxContainer, transmission: bool) -> void:
	var w: UpgradeWorkshop=game.workshop
	var profile: DriverProfile=game.profile
	var category:=7 if transmission else 5
	var gearbox_selected:=transmission and w.mode=="transmission"
	var studio: UpgradeStudio=game.menu.hub.studio
	var quote:=active_quote() if not gearbox_selected else {}
	var reason:=transmission_lock(w.selected_trans) if gearbox_selected else str(quote.reason)
	var candidate: Drivetrain=game.car
	if reason=="":
		candidate=studio.transmission_candidate() if gearbox_selected else quote_preview(quote)
	workshop_heading(body,"Transmission" if transmission else "Forced induction",true)
	var types:=system_grid(body,2 if portrait else 4)
	if transmission:
		for id in TransmissionCatalog.type_options(profile.hardware):
			var spec:=TransmissionCatalog.spec(id)
			var equipped: bool=id==profile.hardware.transmission
			var owned: bool=profile.hardware.owned_transmissions.has(id)
			var state: String=card_status(equipped,owned,int(spec.cost),transmission_lock(id))
			bind(system_card(types,TransmissionCatalog.TYPES[TransmissionCatalog.family(id)],state,category,"",id,gearbox_selected and id==w.selected_trans,equipped,true),"tx_pick_"+id)
	else:
		for id in VehicleParts.induction_options(profile.hardware):
			var option:=profile.upgrade_quote(-1,-1,"induction",id)
			var equipped: bool=option.equipped
			var name: String="Turbocharger" if id=="turbo_race" else (VehicleParts.factory_name("induction") if id=="" else VehicleParts.PARTS[id].name)
			var state:=card_status(equipped,id=="" or VehicleParts.is_owned(profile.hardware,id),int(option.cost),str(option.reason))
			bind(system_card(types,name,state,category,"induction",id,w.current_slot()=="induction" and id==w.selected_hardware,equipped,true),"catalog_factory_induction" if id=="" else "hw_pick_"+id)
	var middle: BoxContainer=AutomotiveUI.column(body,8) if portrait else AutomotiveUI.row(body,14)
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var inventory:=AutomotiveUI.column(middle,6)
	if not portrait: inventory.custom_minimum_size.x=430
	inventory.add_child(AutomotiveUI.label("PERFORMANCE UPGRADES",14,AutomotiveUI.ORANGE,true))
	var upgrades:=system_grid(inventory,2)
	var descriptions := ["Torque capacity","Drivetrain efficiency","Durability under load","Faster shifts","Extreme torque capacity"] if transmission else ["Higher boost","Faster boost response","Improved airflow","Power and thermal headroom"]
	for id in (VehicleParts.TRANSMISSION_UPGRADES if transmission else VehicleParts.INDUCTION_UPGRADES):
		var part: Dictionary=VehicleParts.PARTS[id]
		var equipped: bool=profile.hardware.parts.get(id,"")==id
		var option:=profile.upgrade_quote(-1,-1,id,id)
		var state:=card_status(equipped,VehicleParts.is_owned(profile.hardware,id),int(part.cost),str(option.reason))
		var card:=system_card(upgrades,part.name,state,category,id,id,not gearbox_selected and w.current_slot()==id,equipped)
		var label := AutomotiveUI.label(descriptions.pop_front(),13,AutomotiveUI.MUTED)
		card.get_meta("content").add_child(label)
		bind(card,"system_pick_"+id)
	var details:=detail_panel(middle)
	var title: String=TransmissionCatalog.TYPES[TransmissionCatalog.family(w.selected_trans)] if gearbox_selected else hardware_name(w.selected_hardware)
	if not gearbox_selected and w.selected_hardware=="": title=VehicleParts.factory_name("induction") if w.current_slot()=="induction" else "Remove "+str(VehicleParts.PARTS[w.current_slot()].name)
	if w.selected_hardware=="turbo_race" and not gearbox_selected: title="Turbocharger"
	details.add_child(AutomotiveUI.label(title,24))
	if reason!="": wrapped(details,reason,AutomotiveUI.ORANGE)
	details.add_child(AutomotiveUI.label("PERFORMANCE  /  INSTALLED → PREVIEW",14,AutomotiveUI.BLUE,true))
	performance_rails(details,candidate,true)
	var installed: Drivetrain=game.car
	var metrics: Array[String]=[
		UpgradeStudio.metric("Shift time",installed.shift_duration*1000,candidate.shift_duration*1000,"ms"),
		UpgradeStudio.metric("Peak boost",installed.boost_target(installed.redline_rpm,1),candidate.boost_target(candidate.redline_rpm,1),"bar",2)]
	if transmission:
		metrics.append(UpgradeStudio.metric("Torque capacity",installed.input_capacity(),candidate.input_capacity(),"Nm"))
		metrics.append(UpgradeStudio.metric("Clutch capacity",installed.clutch_capacity(),candidate.clutch_capacity(),"Nm"))
		metrics.append(UpgradeStudio.metric("Efficiency",installed.trans_efficiency*100,candidate.trans_efficiency*100,"%",1))
		metrics.append(UpgradeStudio.metric("Cooling rate",installed._gear_cooling,candidate._gear_cooling,"×",2))
	elif installed.boost_target(installed.redline_rpm,1)>0 and candidate.boost_target(candidate.redline_rpm,1)>0:
		metrics.append(UpgradeStudio.metric("Boost response",candidate_spool(installed),candidate_spool(candidate),"s",2))
	for metric in metrics: AutomotiveUI.metric_row(details,metric,studio.metric_color(metric))
	if not transmission:
		details.add_child(AutomotiveUI.label("BOOST CURVE  /  INSTALLED + PREVIEW  /  PSI",12,AutomotiveUI.BLUE,true))
		var boost_graph:=BoostPlot.new()
		boost_graph.current=installed
		boost_graph.candidate=candidate
		boost_graph.custom_minimum_size.y=94
		boost_graph.mouse_filter=Control.MOUSE_FILTER_IGNORE
		boost_graph.resized.connect(boost_graph.queue_redraw)
		details.add_child(boost_graph)
	if confirm_quote!="" and not quote.is_empty():
		for item in quote.items:
			wrapped(details,("Remove " if item.get("removal",false) else "Install ")+str(item.name),AutomotiveUI.MUTED)
	var preview_parent: VBoxContainer=body if portrait else inventory
	var preview_height := 228 if portrait else (95 if short_catalog() else 124)
	var preview := workshop_hero(preview_parent,candidate,0,preview_height,"CURRENT CAR" if candidate==installed or (gearbox_selected and w.selected_trans==installed.transmission_id) or quote.get("equipped",false) else "BUILD PREVIEW")
	if not portrait: preview.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var actions:=AutomotiveUI.row(body,8)
	button(actions,"system_tuning","Tuning")
	var equipped: bool=w.selected_trans==profile.hardware.transmission if gearbox_selected else quote.equipped
	var owned: bool=profile.hardware.owned_transmissions.has(w.selected_trans)
	var cost: int=(0 if owned else TransmissionCatalog.spec(w.selected_trans).cost) if gearbox_selected else quote.cost
	var label: String="Buy & Equip  /  $%d"%cost if cost>0 else "Equip Free"
	if not gearbox_selected and w.selected_hardware=="" and w.current_slot()!="induction": label="Remove Upgrade"
	if confirm_quote!="" and not quote.is_empty():
		label="Confirm changes"
		button(actions,"catalog_cancel","Cancel")
	if equipped: label="Equipped"
	elif reason!="": label="Locked"
	elif cost>profile.credits: label=game.missing_credits(cost)
	var purchase:=button(actions,"tx_buy" if gearbox_selected else purchase_id(quote),label,true)
	purchase.size_flags_stretch_ratio=2.0
	purchase.disabled=equipped or reason!="" or cost>profile.credits

func candidate_spool(car: Drivetrain) -> float:
	return UpgradeStudio.spool(car)*car._spool_scale

func card_status(equipped: bool,owned: bool,cost: int,reason: String) -> String:
	if equipped: return "Equipped  /  $0"
	if reason!="": return "Locked  /  $%d"%cost
	if owned: return "Owned  /  $0"
	return "Buy  /  $%d"%cost

func system_grid(parent: Node,columns: int) -> GridContainer:
	var grid:=GridContainer.new()
	grid.columns=columns
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",6)
	parent.add_child(grid)
	return grid

func system_card(parent: Node,title: String,state: String,category: int,slot: String,id: String,selected: bool,equipped: bool,large: bool=false) -> Button:
	var card:=AutomotiveUI.content_card(parent,104 if large else 76,selected)
	card.custom_minimum_size.x=0
	var content: VBoxContainer=card.get_meta("content")
	var row:=AutomotiveUI.row(content,6)
	row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if large or id=="gear_pro": row.add_child(component_art(category,slot,id,Vector2(58,48)))
	var labels:=AutomotiveUI.column(row,3)
	labels.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var display_name:=title.replace(" / Paddle"," /\nPaddle").replace(" supercharger","\nsupercharger") if large else title
	var name:=AutomotiveUI.label(display_name,22 if short_catalog() else 19)
	labels.add_child(name)
	labels.add_child(AutomotiveUI.label(state,14,GlassPalette.GREEN if equipped else AutomotiveUI.BLUE,true))
	card.tooltip_text=title+" / "+state
	return card

func option_grid(parent: Node) -> Container:
	if not portrait: return AutomotiveUI.column(parent,4)
	var choices:=GridContainer.new()
	choices.columns=2
	choices.add_theme_constant_override("h_separation",5)
	choices.add_theme_constant_override("v_separation",4)
	choices.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(choices)
	return choices

func detail_panel(parent: Node) -> VBoxContainer:
	var scroll:=catalog_scroll(parent,"UpgradeDetails",detail_offset)
	scroll.get_v_scroll_bar().value_changed.connect(func(value): detail_offset=int(value))
	var surface:=PanelContainer.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style:=AutomotiveUI.surface(Color(.045,.078,.105,.83),Color("2c414c"),4)
	style.content_margin_left=12; style.content_margin_right=12
	style.content_margin_top=9; style.content_margin_bottom=9
	surface.add_theme_stylebox_override("panel",style)
	scroll.add_child(surface)
	return AutomotiveUI.column(surface,6)

func component_art(category: int,slot: String,id: String,dimensions: Vector2) -> PartPlate:
	var family: String=PART_ART.get(id,PART_ART.get(slot,PART_FAMILIES[category]))
	var art:=PartPlate.new()
	art.texture=load("res://assets/ui/components/"+family+".svg")
	art.tint=Color(PART_ACCENTS[category])
	art.custom_minimum_size=dimensions
	art.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.resized.connect(art.queue_redraw)
	return art

func part_card(parent: Node,title: String,state: String,category: int,slot: String,id: String,selected: bool,ink: Color,category_card: bool=false) -> Button:
	var height:=90 if short_catalog() else (86 if portrait else 74)
	var card:=AutomotiveUI.content_card(parent,height,selected)
	var tint:=Color(PART_ACCENTS[category])
	var fill:=AutomotiveUI.surface(Color("192b35") if selected else Color("101b25"),Color(tint,.58 if selected else .27),4)
	fill.set_border_width(SIDE_LEFT,3 if selected else 1)
	card.add_theme_stylebox_override("pressed",fill)
	if not selected:
		card.add_theme_stylebox_override("normal",fill)
		card.add_theme_stylebox_override("hover",AutomotiveUI.surface(Color("20323d"),Color(tint,.74),4))
	var content: VBoxContainer=card.get_meta("content")
	var line:=AutomotiveUI.row(content,8)
	line.size_flags_vertical=Control.SIZE_EXPAND_FILL
	line.add_child(component_art(category,slot,id,Vector2(87,56) if short_catalog() else (Vector2(69,49) if category_card or portrait else Vector2(63,43))))
	var labels:=AutomotiveUI.column(line,2)
	labels.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var name:=AutomotiveUI.label(title,20 if short_catalog() else 17)
	if not category_card:
		name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		name.max_lines_visible=2
		name.custom_minimum_size.y=42
	labels.add_child(name)
	labels.add_child(AutomotiveUI.label(state,16 if short_catalog() else 13,ink))
	card.tooltip_text=title+" / "+state
	return card

func performance_rails(parent: Node,candidate: Drivetrain,compact: bool=false) -> void:
	var studio: UpgradeStudio=game.menu.hub.studio
	var runs:=studio.build_runs(candidate)
	var waiting:=runs[0].is_empty() or runs[1].is_empty()
	var installed: Drivetrain=game.car
	var grid:=GridContainer.new()
	grid.columns=2
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",9)
	parent.add_child(grid)
	comparison_rail(grid,"Horsepower",installed.peak_horsepower(),candidate.peak_horsepower()," hp")
	comparison_rail(grid,"Torque",GarageHub.peak_torque(installed),GarageHub.peak_torque(candidate)," Nm")
	if not compact: comparison_rail(grid,"Grip",GarageHub.grip(installed),GarageHub.grip(candidate),"",2)
	comparison_rail(grid,"Weight",installed.mass(),candidate.mass()," kg",0,true)
	if not compact: comparison_rail(grid,"0–60 mph",runs[0].get("zero_60_s"),runs[1].get("zero_60_s")," s",2,true,waiting)
	comparison_rail(grid,"1/4 est",runs[0].get("quarter_et_s",runs[0].get("quarter_s")),runs[1].get("quarter_et_s",runs[1].get("quarter_s"))," s",2,true,waiting)

func comparison_rail(parent: Node,title: String,before: Variant,after: Variant,unit: String,precision: int=0,lower_better: bool=false,waiting: bool=false) -> void:
	var cell:=AutomotiveUI.column(parent,2)
	var header:=AutomotiveUI.row(cell,4)
	header.add_child(AutomotiveUI.label(title,19 if short_catalog() else 16,AutomotiveUI.INK))
	if before==null or after==null:
		cell.add_child(AutomotiveUI.label("Measuring…" if waiting else "No result",14,AutomotiveUI.MUTED))
		return
	before=ImperialUnits.value(float(before),unit); after=ImperialUnits.value(float(after),unit); unit=" "+ImperialUnits.unit(unit) if unit!="" else ""
	var format: String="%."+str(precision)+"f"
	var delta: float=float(after)-float(before)
	var ink:=AutomotiveUI.BLUE
	if absf(delta)>=pow(10,-precision)*.5:
		ink=GlassPalette.GREEN if (delta<0 if lower_better else delta>0) else Color("ffa29b")
		var change:=AutomotiveUI.label(("+" if delta>0 else "")+(format%delta),17 if short_catalog() else 14,ink,true)
		change.custom_minimum_size.x=58
		change.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		change.size_flags_horizontal=Control.SIZE_SHRINK_END
		header.add_child(change)
	cell.add_child(AutomotiveUI.label((format%before)+" → "+(format%after)+unit,17 if short_catalog() else 14,AutomotiveUI.MUTED,true))
	var rail:=CompareRails.new()
	rail.installed=float(before); rail.proposed=float(after); rail.ink=ink
	rail.custom_minimum_size.y=8
	rail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	rail.resized.connect(rail.queue_redraw)
	cell.add_child(rail)

func dyno_preview(parent: Node,candidate: Drivetrain) -> void:
	var legend:=AutomotiveUI.row(parent,8)
	legend.add_child(AutomotiveUI.label("DYNO / HP",13,AutomotiveUI.ORANGE,true))
	legend.add_child(AutomotiveUI.label("TORQUE / lb-ft",13,AutomotiveUI.BLUE,true))
	var graph:=DynoPlot.new()
	graph.current=game.car
	graph.candidate=candidate
	graph.custom_minimum_size.y=113 if portrait else 142
	graph.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(graph)
	parent.add_child(AutomotiveUI.label("Solid preview  /  dashed installed",13,AutomotiveUI.MUTED))

func stage_options(list: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub
	var w: UpgradeWorkshop=game.workshop
	list.add_child(AutomotiveUI.label(UpgradeStudio.PACKAGE_NAMES[h.selected].to_upper(),13,AutomotiveUI.MUTED,true))
	var choices:=option_grid(list)
	var installed: int=game.profile.stages[game.selected_part]
	for tier in GameCatalog.max_stage(game.selected_part)+1:
		var quote: Dictionary=game.profile.upgrade_quote(game.selected_part,tier)
		var state: String="Equipped" if tier==installed else ("Locked" if quote.reason!="" else ("Owned / equip free" if tier<=game.profile.highest_stage(game.selected_part) else "Available / $%d"%quote.cost))
		if quote.items.size()>1: state+=" incl. support"
		var row:=part_card(choices,GameCatalog.stage_name(game.selected_part,tier),state,h.selected,"","",w.mode=="basic" and w.preview_stage==tier,GlassPalette.GREEN if tier==installed else AutomotiveUI.BLUE)
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
	return "Package assembly" if game.workshop.current_slot()=="induction" and game.car.turbo_stage>0 else VehicleParts.factory_name(game.workshop.current_slot())
