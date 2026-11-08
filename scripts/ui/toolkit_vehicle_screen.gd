class_name ToolkitVehicleScreen
extends "res://vendor/game_dev_toolkit/ui_layout.gd"

# Toolkit action/data contracts adapt into REDLINE's existing controllers.
var owner_screen: WorkshopScreen
var game: Node2D
var screen_type := "garage"
var catalog_items: Array = []
var scroll_pointer := -1
var touch_origin := Vector2.ZERO
var touch_offset := 0
var touch_moved := false
var touch_scroll: ScrollContainer
var catalog_revision := 0
var hero: VehiclePreview
var selected_id := ""

const ACTION_IDS := {
	"garage.previous":"garage_previous","garage.next":"garage_next",
	"nav.upgrades":"garage_upgrades","nav.customize":"garage_customize","garage.change_vehicle":"hub_owned",
	"dealership.filter":"dealer_catalog_filter","nav.dealership_classes":"shop_classes",
	"dealership.previous":"shop_car_prev","dealership.next":"shop_car_next",
	"dealership.details":"shop_details","dealership.equip_on_purchase":"shop_equip",
}

func setup(screen: WorkshopScreen,kind: String,rect: Rect2) -> void:
	owner_screen=screen; game=screen.game; screen_type=kind; name="ToolkitVehicleScreen"
	rect.size.y=minf(rect.size.y,game.navigation_rect().position.y-rect.position.y-14)
	position=rect.position; size=rect.size; theme=AutomotiveUI.theme_resource()
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	action_requested.connect(route_action)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/toolkit/"+kind+".layout.json"))
	apply_layout(responsive_layout(spec,rect.size))
	refresh_data()

func extra(id: String,type: String,role: String,action: String="",binding: String="") -> Dictionary:
	return {"id":id,"type":type,"role":role,"label":"","actionId":action,"bindingKey":binding,"x":0,"y":0,"w":100,"h":50}

func responsive_layout(source: Dictionary,area: Vector2) -> Dictionary:
	var spec:=source.duplicate(true)
	spec.viewport={"width":roundi(area.x),"height":roundi(area.y)}
	var w:=area.x
	var phone: bool=game.is_portrait()
	var compact: bool=not phone and game.get_window().size.y<500
	var rects: Dictionary={}
	if screen_type=="garage":
		spec.nodes.append(extra("currency","label","balance","","garage.balance"))
		spec.nodes.append(extra("vehicle_subtitle","label","vehicle_identity","","garage.selected.subtitle"))
		spec.nodes.append(extra("vehicle_summary","label","performance_summary","","garage.selected.summary"))
		if phone:
			rects={"heading":Rect2(0,0,280,50),"currency":Rect2(288,0,w-288,50),"vehicle_stage":Rect2(0,68,w,370),"vehicle_preview":Rect2(4,80,w-8,286),"previous_vehicle":Rect2(16,354,146,70),"next_vehicle":Rect2(w-162,354,146,70),"vehicle_info":Rect2(0,452,w,408),"vehicle_name":Rect2(20,467,w-40,74),"vehicle_subtitle":Rect2(20,544,w-40,44),"vehicle_stats":Rect2(20,600,w-40,124),"vehicle_summary":Rect2(20,731,w-40,38),"open_upgrades":Rect2(16,782,(w-44)/2,64),"customize_vehicle":Rect2((w+12)/2,782,(w-44)/2,64),"change_vehicle":Rect2(0,894,w,88)}
		else:
			var right:=w*.67
			var info_width:=w-right
			var button_h:=86.0 if compact else 52.0
			rects={"heading":Rect2(0,0,w*.6,50),"currency":Rect2(w*.65,0,w*.35,50),"vehicle_stage":Rect2(0,66,w*.65,430),"vehicle_preview":Rect2(8,84,w*.65-16,332),"previous_vehicle":Rect2(16,500-button_h-16,160,button_h),"next_vehicle":Rect2(w*.65-176,500-button_h-16,160,button_h),"vehicle_info":Rect2(right,66,info_width,536 if compact else 430),"vehicle_name":Rect2(right+18,82,info_width-36,80),"vehicle_subtitle":Rect2(right+18,168,info_width-36,48),"vehicle_stats":Rect2(right+18,226,info_width-36,136),"vehicle_summary":Rect2(16,518,w*.65-32,32),"open_upgrades":Rect2(right+16,388 if compact else 368,info_width-32,button_h),"customize_vehicle":Rect2(right+16,496 if compact else 432,info_width-32,button_h),"change_vehicle":Rect2(w*.16,552 if not compact else 514,w*.33,66 if not compact else 88)}
			if compact: rects.vehicle_summary=Rect2(16,474,w*.65-32,34)
	else:
		spec.nodes.append(extra("vehicle_preview","label","vehicle_preview_placeholder","","dealership.selected.display_name"))
		spec.nodes.append(extra("vehicle_subtitle","label","vehicle_identity","","dealership.selected.subtitle"))
		spec.nodes.append(extra("back_classes","button","back_action","nav.dealership_classes"))
		spec.nodes.append(extra("previous_vehicle","button","previous_item","dealership.previous"))
		spec.nodes.append(extra("next_vehicle","button","next_item","dealership.next"))
		spec.nodes.append(extra("details","button","secondary_action","dealership.details"))
		spec.nodes.append(extra("equip_on_purchase","button","secondary_action","dealership.equip_on_purchase"))
		if phone:
			rects={"heading":Rect2(0,0,310,50),"currency":Rect2(318,0,w-318,50),"search":Rect2(0,62,324,70),"filter":Rect2(336,62,w-336,70),"vehicle_details":Rect2(0,148,w,680),"vehicle_name":Rect2(20,162,w-40,68),"vehicle_preview":Rect2(8,232,w-16,236),"vehicle_subtitle":Rect2(20,474,w-40,46),"vehicle_stats":Rect2(20,534,w-40,124),"vehicle_price":Rect2(20,678,220,54),"purchase":Rect2(252,674,w-272,72),"equip_on_purchase":Rect2(20,754,332,64),"details":Rect2(364,754,w-384,64),"vehicles":Rect2(0,844,w,148),"back_classes":Rect2(0,1010,180,72),"previous_vehicle":Rect2(192,1010,170,72),"next_vehicle":Rect2(374,1010,w-374,72)}
		else:
			var left:=w*.27
			var right:=left+20
			var detail_width:=w-right
			var footer:=520.0 if compact else 576.0
			var bh:=86.0 if compact else 52.0
			rects={"heading":Rect2(0,0,w*.65,50),"currency":Rect2(w*.69,0,w*.31,50),"search":Rect2(0,66,left*.65-6,bh),"filter":Rect2(left*.65+6,66,left*.35-6,bh),"vehicles":Rect2(0,164 if compact else 132,left,338 if compact else 426),"vehicle_details":Rect2(right,66,detail_width,436 if compact else 492),"vehicle_name":Rect2(right+18,82,detail_width-36,58),"vehicle_preview":Rect2(right+8,144,detail_width-16,202 if compact else 250),"vehicle_subtitle":Rect2(right+18,350 if compact else 394,detail_width-36,48 if compact else 30),"vehicle_stats":Rect2(right+18,410 if compact else 432,detail_width*.61-24,90 if compact else 110),"vehicle_price":Rect2(w*.78,400 if compact else 424,w*.22-18,44),"purchase":Rect2(w*.78,456 if compact else 480,w*.22-18,bh),"back_classes":Rect2(0,footer,left,bh),"previous_vehicle":Rect2(right,footer,150,bh),"next_vehicle":Rect2(right+162,footer,150,bh),"details":Rect2(right+324,footer,150,bh),"equip_on_purchase":Rect2(right+486,footer,detail_width-486,bh)}
	if phone:
		for entry in spec.nodes:
			if entry.type in ["button","input"]: rects[entry.id].size.y=maxf(rects[entry.id].size.y,80)
		if screen_type=="dealership":
			rects.purchase.position.y=666
			rects.details.position.y=752; rects.details.size.y=76
			rects.equip_on_purchase.position.y=752; rects.equip_on_purchase.size.y=76
		else:
			rects.open_upgrades.size.y=76; rects.customize_vehicle.size.y=76
	elif compact:
		var pixels_per_unit: float=float(game.get_window().size.y)/game.get_window().content_scale_size.y*game.scale.y
		var touch_h:=maxf(86,ceilf(44/maxf(.1,pixels_per_unit)))
		var footer:=area.y-touch_h-8
		for entry in spec.nodes:
			if entry.type in ["button","input"]: rects[entry.id].size.y=touch_h
		if screen_type=="garage":
			var stage_h:=area.y-touch_h-100
			rects.vehicle_stage.size.y=stage_h
			rects.vehicle_preview.size.y=stage_h-touch_h-30
			rects.previous_vehicle.position.y=66+stage_h-touch_h-12; rects.next_vehicle.position.y=rects.previous_vehicle.position.y
			rects.vehicle_info.size.y=area.y-66
			rects.customize_vehicle.position.y=area.y-touch_h-12
			rects.open_upgrades.position.y=area.y-touch_h*2-24
			rects.change_vehicle.position.y=area.y-touch_h-12
		else:
			var right: float=rects.vehicle_details.position.x
			var preview_h:=minf(202,footer-324)
			rects.vehicle_details.size.y=footer-80
			rects.vehicle_preview.size.y=preview_h
			rects.vehicle_subtitle=Rect2(right+18,150+preview_h,rects.vehicle_stats.size.x,44)
			rects.vehicle_stats.position.y=footer-118; rects.vehicle_stats.size.y=104
			rects.vehicle_price.position.y=footer-touch_h-66
			rects.purchase.position.y=footer-touch_h-16
			rects.vehicles.size.y=footer-rects.vehicles.position.y-16
			for id in ["back_classes","previous_vehicle","next_vehicle","details","equip_on_purchase"]: rects[id].position.y=footer
	elif screen_type=="dealership":
		rects.vehicle_subtitle.size.y=44; rects.vehicle_stats.position.y=442; rects.vehicle_stats.size.y=100
	for entry in spec.nodes:
		var r: Rect2=rects[entry.id]
		entry.x=roundi(r.position.x); entry.y=roundi(r.position.y); entry.w=floori(r.size.x); entry.h=floori(r.size.y)
	return spec

func _make_control(entry: Dictionary) -> Control:
	var role:=str(entry.get("role",""))
	var ui: Control
	if role=="vehicle_preview_placeholder":
		ui=Control.new(); ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	elif str(entry.type)=="button":
		var button:=AutomotiveUI.GlassButton.new()
		button.pressed.connect(_dispatch_click.bind(str(entry.get("actionId","")),str(entry.id)))
		ui=button
	elif role in ["stats_list","specs_list"]:
		var scroll:=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		var cells:=GridContainer.new(); cells.name="Entries"; cells.columns=2; cells.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		cells.add_theme_constant_override("h_separation",12); cells.add_theme_constant_override("v_separation",8); scroll.add_child(cells)
		ui=scroll
	else: ui=super._make_control(entry)
	if ui==null: return null
	ui.name=str(entry.id); ui.set_meta("ui_type",str(entry.type)); ui.set_meta("ui_role",role)
	if ui is Panel:
		ui.add_theme_stylebox_override("panel",AutomotiveUI.surface(Color(.025,.038,.050,.90),Color("51616b88"),18))
		ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	elif ui is Button:
		ui.theme_type_variation="Primary" if role=="primary_action" or str(entry.id)=="change_vehicle" else "Secondary"
		ui.add_theme_font_size_override("font_size",24 if owner_screen.short_catalog() else (19 if game.is_portrait() else 18))
		ui.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; ui.focus_mode=Control.FOCUS_ALL
	elif ui is Label:
		ui.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		ui.add_theme_font_size_override("font_size",32 if role=="screen_title" else (28 if role in ["detail_title","price"] else 17))
		if role in ["screen_title","detail_title"]: ui.add_theme_font_override("font",AutomotiveUI.DISPLAY)
		ui.add_theme_color_override("font_color",AutomotiveUI.ORANGE if role=="price" else (AutomotiveUI.MUTED if role in ["balance","vehicle_identity","performance_summary"] else AutomotiveUI.INK))
		ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if role in ["detail_title","vehicle_identity"]: ui.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ui.max_lines_visible=2
		if role=="balance": ui.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		if role=="balance" and game.is_portrait(): ui.add_theme_font_size_override("font_size",20)
	elif ui is LineEdit:
		ui.add_theme_font_size_override("font_size",20 if game.is_portrait() else 18)
		ui.placeholder_text="Search this class"; ui.text_changed.connect(func(value): route_action("dealership.search",{"value":value}))
		owner_screen.search=ui
	if ui is ScrollContainer: ui.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	return ui

func stat_rows(c: Drivetrain,details: bool=false) -> Array:
	var out: Array=[{"label":"ENGINE POWER" if float(c._base_spec.get("hybrid_kw",0))>0 else "POWER","value":"%.0f hp"%c.peak_horsepower()},{"label":"TORQUE","value":"%.0f lb-ft"%ImperialUnits.torque(GarageHub.peak_torque(c))},{"label":"GRIP","value":"%.2f"%c.effective_grip()},{"label":"WEIGHT","value":"%.0f lb"%ImperialUnits.pounds(c.mass())}]
	if details:
		out.append_array([{"label":"SHIFT TIME","value":"%.0f ms"%(c.shift_duration*1000)},{"label":"TORQUE CAPACITY","value":"%.0f lb-ft"%ImperialUnits.torque(c.input_capacity())},{"label":"FINAL DRIVE","value":"%.2f"%c.final_drive},{"label":"REV LIMIT","value":"%.0f RPM"%c.redline_rpm}])
		out.append_array([{"label":"ENGINE","value":ImperialUnits.engine_label(c.engine_label)},{"label":"BOOST","value":"%.1f PSI"%PressureUnits.psi(c.boost_target(c.redline_rpm,1))},{"label":"EFFICIENCY","value":"%.1f%%"%(c.trans_efficiency*100)},{"label":"TIRE RADIUS","value":"%.1f in"%ImperialUnits.inches(c.tire_radius)}])
		for i in c.gear_ratios.size(): out.append({"label":"GEAR %d RATIO"%(i+1),"value":"%.3f"%c.gear_ratios[i]})
		if float(c._base_spec.get("hybrid_kw",0))>0: out.append({"label":"ELECTRIC ASSIST","value":"%.0f hp"%(float(c._base_spec.hybrid_kw)/.7457)})
	return out

func refresh_data() -> void:
	selected_id=game.profile.vehicle_id if screen_type=="garage" else GameCatalog.CAR_IDS[game.dealer_index]
	var c: Drivetrain=game.car if screen_type=="garage" else game.menu.dealer.factory(selected_id)
	var s:=GameCatalog.spec(selected_id)
	var drive_text: String="%s / %d-speed %s"%[s.drive,c.gear_ratios.size(),c.transmission_kind.capitalize()]
	var identity: String="%s %s · Engine class %s"%[s.year,s.brand,GameCatalog.engine_class(selected_id,game.profile.hardware if screen_type=="garage" else {})]
	var selected: Dictionary={"name":s.name,"display_name":s.name,"subtitle":identity,"summary":drive_text,"stats":stat_rows(c)}
	var wallet: String="LV %02d  /  $%d"%[game.profile.level(),game.profile.credits]
	if screen_type=="garage":
		set_data({"garage":{"balance":wallet,"selected":selected}})
		controls.heading.text="REDLINE / GARAGE" if not game.is_portrait() else "REDLINE"
	else:
		var d: DealershipView=game.menu.dealer
		selected.subtitle=identity+"\n"+drive_text
		selected.stats=stat_rows(c,d.details)
		var owned: bool=game.profile.garage.has(selected_id)
		selected.price="Equipped" if selected_id==game.profile.vehicle_id else ("Owned" if owned else "$%d"%s.price)
		if not owned and game.profile.level()<int(s.unlock_level): selected.price="Locked · LV %d"%s.unlock_level
		set_data({"dealership":{"balance":wallet,"search":owner_screen.dealer_query,"vehicles":visible_inventory(),"selected":selected}})
		controls.heading.text="DEALERSHIP / "+DealershipView.CLASSES[d.class_filter]
		controls.purchase.text="Equipped" if selected_id==game.profile.vehicle_id else ("Equip vehicle" if owned else ("Locked" if game.profile.level()<int(s.unlock_level) else ("Need $%d"%(int(s.price)-game.profile.credits) if game.profile.credits<int(s.price) else "Purchase")))
		controls.purchase.disabled=not game.action_enabled("drive_car" if owned else "buy_car") or game.profile.save_blocked
		controls.equip_on_purchase.visible=not owned
		controls.equip_on_purchase.text="Equip on purchase: "+("Yes" if d.equip else "No")
		controls.details.text="Overview" if d.details else "Details"
	for entry in layout.nodes:
		var action:=str(entry.get("actionId",""))
		var ui: Control=controls[entry.id]
		if ui is Button:
			var alias: String=ACTION_IDS.get(action,"")
			if action=="dealership.purchase_request": alias="drive_car" if game.profile.garage.has(selected_id) else "buy_car"
			if alias!="": register_target(ui,alias)
	controls.previous_vehicle.text="‹ Previous"; controls.next_vehicle.text="Next ›"
	if screen_type=="garage":
		controls.open_upgrades.text="Upgrades"; controls.customize_vehicle.text="Customize"; controls.change_vehicle.text="Change Car"
		if owner_screen.short_catalog(): controls.vehicle_summary.hide()
		for pair in [["open_upgrades","performance"],["customize_vehicle","style"],["change_vehicle","dealer"]]:
			controls[pair[0]].icon=AutomotiveUI.action_icon(pair[1],Color("24191b") if pair[0]=="change_vehicle" else AutomotiveUI.BLUE)
			controls[pair[0]].add_theme_constant_override("icon_max_width",24)
		controls.previous_vehicle.disabled=game.profile.garage.size()<2; controls.next_vehicle.disabled=game.profile.garage.size()<2
	else: controls.back_classes.text="‹ Classes"
	var holder: Control=controls.vehicle_preview
	hero=VehiclePreview.new(); holder.add_child(hero); hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.configure(game,selected_id,c,game.profile.appearance_for(selected_id) if screen_type=="garage" else VehicleAppearance.normalize({},2,0),true,0)
	hero.scene_texture=load(GarageShowroom.PORTRAIT_PATH if game.is_portrait() else GarageShowroom.SCENE_PATH)
	hero.scene_tint=Color(.82,.85,.88)

func register_target(button: Button,id: String) -> void:
	button.name=id; owner_screen.targets[id]=button
	button.focus_entered.connect(func(): game.glass.focused=id)

func visible_inventory() -> Array:
	var out: Array=[]
	var query: String=owner_screen.dealer_query.strip_edges().to_lower()
	for id in game.menu.dealer.filtered():
		var s:=GameCatalog.spec(id)
		var owned: bool=game.profile.garage.has(id)
		if query!="" and query not in (str(s.name)+" "+str(s.year)+" "+str(s.drive)).to_lower(): continue
		if owner_screen.dealer_filter==1 and not owned: continue
		if owner_screen.dealer_filter==2 and owned: continue
		out.append({"id":id,"name":s.name,"state":"Equipped" if id==game.profile.vehicle_id else ("Owned" if owned else ("Locked · LV %d"%s.unlock_level if game.profile.level()<int(s.unlock_level) else "$%d"%s.price))})
	return out

func set_data(data: Dictionary) -> void:
	bindings=data
	for entry in layout.get("nodes",[]):
		if not controls.has(entry.id): continue
		var ui: Control=controls[entry.id]
		var value: Variant=_lookup(str(entry.get("bindingKey","")))
		var role:=str(entry.get("role",""))
		if role=="vehicle_catalog":
			catalog_items=value if value is Array else []; rebuild_catalog()
		elif role in ["stats_list","specs_list"]:
			var grid: GridContainer=ui.get_node("Entries")
			for child in grid.get_children(): grid.remove_child(child); child.queue_free()
			if value is Array:
				for stat in value:
					var box:=AutomotiveUI.column(grid,1)
					box.add_child(AutomotiveUI.label(str(stat.label),15 if owner_screen.short_catalog() else 12,AutomotiveUI.MUTED))
					var value_label:=AutomotiveUI.label(str(stat.value),24 if owner_screen.short_catalog() else 23)
					if stat.label=="ENGINE": value_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; value_label.max_lines_visible=3
					box.add_child(value_label)
		elif ui is Label and value!=null: ui.text=_display(value)
		elif ui is LineEdit and not ui.has_focus(): ui.text=_display(value)

func _restore_catalog_scroll(scroll: ScrollContainer,offset: int,revision: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll) or scroll.is_queued_for_deletion() or revision!=catalog_revision: return
	scroll.scroll_vertical=offset

func rebuild_catalog() -> void:
	if not controls.has("vehicles"): return
	var scroll: ScrollContainer=controls.vehicles
	var previous_position: int=scroll.scroll_vertical
	catalog_revision+=1
	var grid: GridContainer=scroll.get_node("Entries")
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("v_separation",8)
	for id in owner_screen.targets.keys():
		if str(id).begins_with("dealer_") and str(id).trim_prefix("dealer_").is_valid_int(): owner_screen.targets.erase(id)
	for child in grid.get_children(): grid.remove_child(child); child.queue_free()
	for i in catalog_items.size():
		var item: Dictionary=catalog_items[i]
		var card:=AutomotiveUI.button(grid,"","Selection",116 if owner_screen.short_catalog() else 92)
		card.focus_mode=Control.FOCUS_ALL
		if item.id==selected_id: card.add_theme_stylebox_override("normal",AutomotiveUI.surface(Color("342927"),AutomotiveUI.ORANGE,12))
		var margin:=MarginContainer.new(); card.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
		var line:=AutomotiveUI.row(margin,8)
		var preview:=VehiclePreview.new(); line.add_child(preview); preview.custom_minimum_size.x=96 if not game.is_portrait() else 130; preview.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		preview.configure(game,item.id,game.menu.dealer.factory(item.id),VehicleAppearance.normalize({},2,0),false,60,false)
		var text:=AutomotiveUI.column(line,4)
		var title:=AutomotiveUI.label(str(item.name),21 if owner_screen.short_catalog() else 17); title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; title.max_lines_visible=2; text.add_child(title)
		text.add_child(AutomotiveUI.label(str(item.state),18 if owner_screen.short_catalog() else 15,AutomotiveUI.ORANGE if item.id==selected_id else AutomotiveUI.MUTED))
		card.pressed.connect(_dispatch_item.bind("dealership.select","vehicles",i,item))
		register_target(card,"dealer_%d"%GameCatalog.CAR_IDS.find(item.id))
	if catalog_items.is_empty(): grid.add_child(AutomotiveUI.label("No matching cars in this class",18,AutomotiveUI.MUTED))
	if controls.has("filter"): controls.filter.text=["All","Owned","Unowned"][owner_screen.dealer_filter]
	for id in ["previous_vehicle","next_vehicle"]:
		if controls.has(id): controls[id].disabled=catalog_items.size()<2
	_restore_catalog_scroll(scroll,previous_position,catalog_revision)
	owner_screen.publish_targets.call_deferred()

func route_action(action_id: String,payload: Dictionary={}) -> void:
	if action_id=="dealership.search":
		owner_screen.dealer_query=str(payload.get("value","")); catalog_items=visible_inventory(); rebuild_catalog(); return
	if action_id=="dealership.select":
		var id: String=payload.get("item",{}).get("id","")
		if game.menu.dealer.filtered().has(id): game.action("dealer_%d"%GameCatalog.CAR_IDS.find(id))
		return
	if action_id=="dealership.purchase_request": game.action("drive_car" if game.profile.garage.has(selected_id) else "buy_car"); return
	if ACTION_IDS.has(action_id): game.action(ACTION_IDS[action_id])

func handle_scroll_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and event.canceled and event.index==scroll_pointer:
		scroll_pointer=-1; touch_scroll=null; return true
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		for id in ["vehicles","vehicle_stats"]:
			var ui: Control=controls.get(id)
			if not ui is ScrollContainer or not ui.get_global_rect().has_point(event.position): continue
			if scroll_pointer>=0: return true
			scroll_pointer=event.index; touch_scroll=ui; touch_origin=event.position; touch_offset=ui.scroll_vertical; touch_moved=false; return true
	if event is InputEventScreenDrag and event.index==scroll_pointer:
		if is_instance_valid(touch_scroll):
			var delta: float=event.position.y-touch_origin.y
			if absf(delta)>8: touch_moved=true
			if touch_moved: touch_scroll.scroll_vertical=touch_offset-roundi(delta/game.scale.y)
		return true
	if event is InputEventScreenTouch and not event.pressed and event.index==scroll_pointer:
		scroll_pointer=-1
		if not touch_moved and not event.canceled: game.activate_at(game.to_local(event.position),"touch_%d"%event.index)
		touch_scroll=null; return true
	return false
