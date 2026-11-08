class_name CollectionScreen
extends WorkshopScreen

var scroll_pointer: int=-1
var scroll_start:=Vector2.ZERO
var scroll_offset:=0
var scroll_moved:=false
var touch_scroll: ScrollContainer

func handle_scroll_touch(event: InputEvent) -> bool:
	if is_instance_valid(vehicle_template) and vehicle_template.is_visible_in_tree() and vehicle_template.handle_scroll_touch(event): return true
	# Defer option taps until release so a swipe cannot select an option, and
	# consume the event once through the same existing action dispatcher.
	if not visible or game.screen!="garage" or game.tab!="style":
		scroll_pointer=-1; touch_scroll=null; return super.handle_scroll_touch(event)
	if event is InputEventScreenTouch and event.canceled and event.index==scroll_pointer:
		scroll_pointer=-1; touch_scroll=null; return true
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		var scroll: ScrollContainer=find_child("StudioOptions",true,false)
		if scroll==null or not scroll.get_global_rect().has_point(event.position): return false
		if scroll_pointer>=0: return true
		scroll_pointer=event.index; touch_scroll=scroll; scroll_start=event.position; scroll_offset=scroll.scroll_vertical; scroll_moved=false
		return true
	if event is InputEventScreenDrag and event.index==scroll_pointer:
		if is_instance_valid(touch_scroll):
			var delta: float=event.position.y-scroll_start.y
			if absf(delta)>8: scroll_moved=true
			if scroll_moved: touch_scroll.scroll_vertical=scroll_offset-roundi(delta/game.scale.y)
		return true
	if event is InputEventScreenTouch and not event.pressed and event.index==scroll_pointer:
		scroll_pointer=-1
		if is_instance_valid(touch_scroll) and not touch_scroll.is_queued_for_deletion() and not scroll_moved and not event.canceled and touch_scroll.get_global_rect().has_point(event.position):
			game.activate_at(game.to_local(event.position),"touch_%d"%event.index)
		touch_scroll=null
		return true
	return false

func compact_landscape() -> bool:
	var workshop_catalog: bool=game.tab=="performance" and not game.menu.hub.dyno_open and (game.menu.hub.categories or game.workshop.mode in ["basic","hardware","transmission"])
	return (workshop_catalog or game.tab in ["garage","dealer","owned","style"]) and not game.is_portrait() and game.get_window().size.y<500

func canvas_size() -> Vector2:
	return Vector2(game.race_view_size()) if compact_landscape() else super.canvas_size()

func button(parent: Node,id: String,text: String,primary: bool=false) -> Button:
	var b:=super.button(parent,id,text,primary)
	if compact_landscape(): b.custom_minimum_size.y=86; b.add_theme_font_size_override("font_size",24)
	return b

# Phase 2 composes the established native surface; the existing models own state.
func supports() -> bool:
	if (not game.glass.legacy or game.tab=="style") and game.screen=="garage" and not game.menu.hub.dyno_open and game.tab in ["dealer","owned","style"]: return true
	return super.supports()

func state_key() -> String:
	if game.tab not in ["dealer","owned","style"]: return super.state_key()
	var d: DealershipView=game.menu.dealer; var h: GarageHub=game.menu.hub; var custom: CustomizationView=game.menu.customize
	if game.tab=="style" and (custom.vehicle_id!=game.profile.vehicle_id or custom.candidate.is_empty()): custom.open()
	var measurements: Array=[]
	if game.tab=="dealer":
		for letter in PerformanceClasses.ORDER: measurements.append(d.class_ids(letter))
		if not d.class_picker: measurements.append(d.preview_estimate(GameCatalog.CAR_IDS[game.dealer_index]))
	if game.tab=="owned" and h.owned_sort: measurements=h.owned_ids()
	return JSON.stringify([size,game.scale,game.get_window().size,game.tab,game.profile.vehicle_id,game.profile.garage,game.profile.stages,game.profile.hardware,game.profile.credits,game.profile.xp,game.profile.appearance_for(game.profile.vehicle_id),game.profile.owned_appearance,game.profile.effects_quality,game.profile.save_blocked,game.profile.muted,d.class_picker,d.vehicle_type,d.class_filter,d.page,d.details,d.equip,game.dealer_index,h.owned_selection,h.owned_page,h.owned_filter,h.owned_sort,custom.category,custom.candidate,custom.compare,custom.focus_override,custom.zoom_step,custom.trim_open,measurements])

func build() -> void:
	if game.tab not in ["dealer","owned","style"]: super.build(); return
	if game.tab=="dealer" and not game.menu.dealer.class_picker:
		dealer(null); build_notice(); return
	if compact_landscape() and game.tab!="style" and not (game.tab=="dealer" and not game.menu.dealer.class_picker):
		CollectionLandscape.new(self).build(); build_notice(); return
	var body:=container(Rect2(24,20,552,1116) if portrait else (Rect2(24,14,size.x-48,612) if compact_landscape() else Rect2(36,20,1128,638)))
	body.add_theme_constant_override("separation",10 if portrait else 12)
	if game.tab!="style": header(body)
	match game.tab:
		"dealer":
			if game.menu.dealer.class_picker: classes(body)
			else: dealer(body)
		"owned": collection(body)
		"style":
			var stage:=customize(body)
			build_notice()
			notice.reparent(stage,false)
			notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			notice.offset_left=12
			notice.offset_right=-12
			notice.offset_top=-56
			notice.offset_bottom=-12
			return
	build_notice()

func grid(parent: Node,columns: int,gap: int=10) -> GridContainer:
	var layout:=GridContainer.new(); layout.columns=columns; layout.add_theme_constant_override("h_separation",gap); layout.add_theme_constant_override("v_separation",gap)
	layout.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(layout); return layout

func title(parent: Node,name: String,back_id: String="",back_label: String="Garage") -> void:
	var row:=AutomotiveUI.row(parent)
	row.add_child(AutomotiveUI.label(name,33))
	if back_id!="":
		var back:=button(row,back_id,back_label); back.custom_minimum_size.x=158; back.size_flags_horizontal=Control.SIZE_SHRINK_END

func vehicle(parent: Node,id: String,c: Drivetrain,look: Dictionary,height: float,background: bool=true) -> VehiclePreview:
	var view:=VehiclePreview.new(); parent.add_child(view); view.configure(game,id,c,look,background,height)
	return view

func vehicle_type_tabs(body: VBoxContainer) -> void:
	var dealer: DealershipView = game.menu.dealer
	var tabs := AutomotiveUI.row(body, 8)
	tabs.name = "DealershipVehicleTabs"
	for i in dealer.VEHICLE_TYPES.size():
		var kind: String = dealer.VEHICLE_TYPES[i]
		var tab_button := button(tabs, "dealer_type_" + kind, dealer.VEHICLE_TYPE_LABELS[i])
		tab_button.toggle_mode = true
		tab_button.set_pressed_no_signal(dealer.vehicle_type == kind)
		tab_button.theme_type_variation = "Navigation"
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.custom_minimum_size.y = 76 if portrait or compact_landscape() else 48
		tab_button.add_theme_font_size_override("font_size", 16 if portrait else 18)

func classes(body: VBoxContainer) -> void:
	title(body, "Dealership / Class index")
	AutomotiveUI.section_mark(body, "FACTORY INVENTORY  /  ENGINE CLASS", "dealer", AutomotiveUI.BLUE)
	vehicle_type_tabs(body)
	var d: DealershipView = game.menu.dealer
	var cards := grid(body, 2 if portrait else 3, 14)
	cards.name = "DealershipClassGrid"
	for i in 6:
		var letter: String = PerformanceClasses.ORDER[i]
		var ids: Array = d.class_ids(letter) if d.vehicle_type == "cars" else []
		var card := AutomotiveUI.content_card(cards, 236 if portrait else 205)
		AutomotiveUI.class_decal(card, letter, i)
		bind(card, "shop_class_" + letter)
		var content: VBoxContainer = card.get_meta("content")
		content.add_child(AutomotiveUI.label("CLASS " + letter, 26, AutomotiveUI.INK))
		if d.vehicle_type == "cars":
			if not ids.is_empty():
				var available: Array = ids.filter(func(id): return not game.profile.garage.has(id))
				var offers: Array = ids if available.is_empty() else available
				var cheapest: String = offers[0]
				vehicle(content, cheapest, d.factory(cheapest), VehicleAppearance.normalize({}, 2, 0), 110 if portrait else 88, false)
				content.add_child(AutomotiveUI.label("Collection complete" if available.is_empty() else "Available from $%d" % GameCatalog.spec(cheapest).price, 16))
				content.add_child(AutomotiveUI.label("%d cars · %d owned" % [ids.size(), ids.size() - available.size()], 14, AutomotiveUI.MUTED))
			else:
				content.add_child(AutomotiveUI.label("No engines in this class", 16))
			content.add_child(AutomotiveUI.label("Factory engine classification", 15, AutomotiveUI.MUTED))
		elif d.vehicle_type == "bikes":
			var path: String = str(d.BIKE_IMAGES.get(letter, ""))
			var image := TextureRect.new()
			image.name = "MotorcyclePreview_" + letter
			image.texture = d._preview_texture(path)
			image.custom_minimum_size.y = 118 if portrait else (78 if compact_landscape() else 90)
			image.size_flags_vertical = Control.SIZE_EXPAND_FILL
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(image)
			content.add_child(AutomotiveUI.label("Motorcycles", 16, AutomotiveUI.BLUE))
			content.add_child(AutomotiveUI.label("Coming soon", 14, AutomotiveUI.MUTED))
		else:
			var preview := preload("res://scripts/ui/watercraft_class_preview.gd").new()
			preview.name = "WatercraftPreview_" + letter
			preview.craft_class = letter
			preview.custom_minimum_size.y = 118 if portrait else (78 if compact_landscape() else 90)
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(preview)
			content.add_child(AutomotiveUI.label(str(d.WATERCRAFT_LABELS.get(letter, "Watercraft")), 16, AutomotiveUI.BLUE))
			content.add_child(AutomotiveUI.label("Coming soon", 14, AutomotiveUI.MUTED))

func spec_summary(parent: Node,id: String,c: Drivetrain) -> void:
	var layout:=grid(parent,2,6)
	for value in [["ENGINE POWER" if float(GameCatalog.spec(id).get("hybrid_kw",0))>0 else "POWER","%.0f hp"%c.peak_horsepower()],["TORQUE","%.0f lb-ft"%ImperialUnits.torque(GarageHub.peak_torque(c))],["WEIGHT","%.0f lb"%ImperialUnits.pounds(c.mass())],["GRIP","%.2f"%GarageHub.grip(c)]]:
		var cell:=AutomotiveUI.column(layout,1); cell.add_child(AutomotiveUI.label(value[0],12,AutomotiveUI.MUTED)); cell.add_child(AutomotiveUI.label(value[1],22))
	if float(GameCatalog.spec(id).get("hybrid_kw",0))>0: parent.add_child(AutomotiveUI.label("Combustion output + %.0f hp electric assist"%(GameCatalog.spec(id).hybrid_kw/.7457),14,AutomotiveUI.MUTED))

func page_controls(parent: Node,owned: bool=false) -> void:
	var count: int=game.menu.hub.owned_ids().size() if owned else game.menu.dealer.filtered().size()
	if owned and count<=4: return
	var r:=AutomotiveUI.row(parent)
	if count>4:
		button(r,"hub_owned_prev" if owned else "shop_prev","Previous page")
		button(r,"hub_owned_next" if owned else "shop_next","Next page")
	if not owned:
		button(r,"shop_car_prev","‹ Car"); button(r,"shop_car_next","Car ›")

func dealer(body: VBoxContainer) -> void:
	if dealer_ui_class!=game.menu.dealer.class_filter:
		dealer_ui_class=game.menu.dealer.class_filter; dealer_query=""; dealer_filter=0
	vehicle_template=ToolkitVehicleScreen.new(); add_child(vehicle_template)
	vehicle_template.setup(self,"dealership",Rect2(24 if portrait or compact_landscape() else 36,18,size.x-(48 if portrait or compact_landscape() else 72),1100 if portrait else 614 if compact_landscape() else 630))
	return

func mechanical_details(parent: Node,c: Drivetrain) -> void:
	var scroll:=ScrollContainer.new(); scroll.name="MechanicalDetails"; scroll.custom_minimum_size.y=180 if portrait else 300; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(scroll)
	var content:=AutomotiveUI.column(scroll,4)
	if not game.glass.reduced_motion:
		scroll.modulate.a=.8; scroll.create_tween().tween_property(scroll,"modulate:a",1.0,.12)
	for line in ["Idle %.0f / limiter %.0f rpm"%[c.idle_rpm,c.redline_rpm],"Final drive %.3f / tire radius %.1f in"%[c.final_drive,ImperialUnits.inches(c.tire_radius)],"%.0f ms shift / %.0f lb-ft input rating"%[c.shift_duration*1000,ImperialUnits.torque(c.input_capacity())],"Ratios: "+str(c.gear_ratios),"Efficiency %.1f%% / boost %.1f PSI"%[c.trans_efficiency*100,PressureUnits.psi(c.boost_target(c.redline_rpm,1))]]:
		var line_label:=AutomotiveUI.label(line,15,AutomotiveUI.MUTED); line_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line_label.custom_minimum_size.y=72 if line.begins_with("Ratios:") else 30
		content.add_child(line_label)

func collection(body: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub; var ids:=h.owned_ids()
	title(body,"Your collection","hub_back")
	var filters:=AutomotiveUI.row(body)
	button(filters,"owned_filter","Engine class: "+("All" if h.owned_filter==0 else PerformanceClasses.ORDER[h.owned_filter-1]))
	button(filters,"owned_sort","Quickest first" if h.owned_sort else "Collection order")
	if ids.is_empty(): body.add_child(AutomotiveUI.label("No owned cars in this engine class",22)); return
	if not ids.has(h.owned_selection): h.owned_selection=ids[0]
	h.owned_page=clampi(h.owned_page,0,maxi(0,ceili(ids.size()/4.0)-1))
	var selected: String=h.owned_selection; var c:=h.vehicle(selected)
	var main: BoxContainer=VBoxContainer.new() if portrait else HBoxContainer.new(); main.add_theme_constant_override("separation",16); main.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(main)
	var list: VBoxContainer
	var detail: VBoxContainer
	if portrait:
		detail=AutomotiveUI.column(main,8); detail.size_flags_vertical=Control.SIZE_EXPAND_FILL
	else:
		list=AutomotiveUI.column(main,8); list.custom_minimum_size.x=300; list.size_flags_horizontal=Control.SIZE_FILL
		detail=AutomotiveUI.column(main,8)
	detail.add_child(AutomotiveUI.label(str(GameCatalog.spec(selected).name),26))
	var hero:=vehicle(detail,selected,c,game.profile.appearance_for(selected),175 if portrait else 180)
	if portrait: hero.size_flags_vertical=Control.SIZE_EXPAND_FILL
	spec_summary(detail,selected,c)
	var engine_class:=GameCatalog.engine_class(selected,c.hardware)
	var controls: Dictionary={"hpattern":"manual","paddle":"paddle","sequential":"sequential","automatic":"automatic"}
	detail.add_child(AutomotiveUI.label("Engine class %s / %d-speed %s"%[engine_class,c.gear_ratios.size(),controls.get(c.control_mode,c.control_mode)],16,AutomotiveUI.BLUE))
	detail.add_child(AutomotiveUI.label("Vs active  %+.0f hp / %+.0f lb-ft / %+.0f lb"%[c.peak_horsepower()-game.car.peak_horsepower(),ImperialUnits.torque(GarageHub.peak_torque(c))-ImperialUnits.torque(GarageHub.peak_torque(game.car)),ImperialUnits.pounds(c.mass())-ImperialUnits.pounds(game.car.mass())],17,AutomotiveUI.MUTED))
	if portrait: list=AutomotiveUI.column(main,8)
	var cards:=grid(list,2 if portrait else 1,8)
	for i in mini(4,ids.size()-h.owned_page*4):
		var id: String=ids[h.owned_page*4+i]; var owned_car:=h.vehicle(id)
		var card:=AutomotiveUI.vehicle_card(cards,game,id,owned_car,game.profile.appearance_for(id),("Equipped · Class " if id==game.profile.vehicle_id else "Owned · Class ")+GameCatalog.engine_class(id,owned_car.hardware),id==selected,108 if portrait else 94)
		bind(card,"hub_pick_"+id)
	page_controls(list,true)
	var actions:=AutomotiveUI.row(body,8)
	button(actions,"tab_style","Customize active car")
	button(actions,"open_tuning","Test track")
	button(actions,"hub_equip","Equipped" if selected==game.profile.vehicle_id else "Drive this car",true)

func studio_button(parent: Node,id: String,label: String,selected: bool=false,primary: bool=false) -> Button:
	var control:=button(parent,id,label,primary)
	control.custom_minimum_size.y=86 if compact_landscape() else (68 if portrait else 43)
	control.add_theme_font_size_override("font_size",20 if compact_landscape() else (18 if portrait else 16))
	if id.begins_with("custom_group_") or id.begins_with("custom_category_") or id=="custom_trim":
		control.theme_type_variation="Navigation"
		control.toggle_mode=true
		control.set_pressed_no_signal(selected)
	return control

func customize(body: VBoxContainer) -> CustomizationStage:
	var custom: CustomizationView=game.menu.customize
	var id: String=game.profile.vehicle_id
	var header_row:=AutomotiveUI.row(body,12)
	var identity:=AutomotiveUI.column(header_row,2)
	identity.add_child(AutomotiveUI.label("REDLINE  /  DESIGN STUDIO",14,AutomotiveUI.ORANGE,true))
	identity.add_child(AutomotiveUI.label(str(GameCatalog.spec(id).name),32 if not compact_landscape() else 30))
	var wallet:=AutomotiveUI.label("$%d"%game.profile.credits,18,AutomotiveUI.MUTED,true)
	wallet.custom_minimum_size.x=100
	wallet.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	wallet.size_flags_horizontal=Control.SIZE_SHRINK_END
	wallet.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	header_row.add_child(wallet)
	var back:=studio_button(header_row,"custom_back","Garage")
	back.size_flags_horizontal=Control.SIZE_SHRINK_END
	back.custom_minimum_size.x=114
	var middle: BoxContainer=AutomotiveUI.column(body,10) if portrait else AutomotiveUI.row(body,18)
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var bay:=AutomotiveUI.column(middle,6)
	bay.size_flags_vertical=Control.SIZE_EXPAND_FILL
	bay.size_flags_stretch_ratio=1.70 if not portrait else 1.0
	var installed: Dictionary=game.profile.appearance_for(id)
	var stage:=CustomizationStage.new()
	bay.add_child(stage)
	stage.configure(game,installed if custom.compare else custom.candidate,350 if portrait else (290 if compact_landscape() else 360))
	studio_badge(stage,"WHEEL DETAIL" if custom.camera_target().x>.5 else "FULL CAR",false)
	studio_badge(stage,"INSTALLED" if custom.compare or not custom.has_preview() else "LIVE PREVIEW",true)
	var camera:=AutomotiveUI.row(bay,6)
	studio_button(camera,"custom_camera","Full car" if custom.camera_target().x>.5 else "Wheel view")
	for action in ["out","in"]:
		var zoom:=studio_button(camera,"custom_zoom_"+action,"−" if action=="out" else "+")
		zoom.tooltip_text="Zoom out" if action=="out" else "Zoom in"
		zoom.size_flags_horizontal=Control.SIZE_FILL
		zoom.custom_minimum_size.x=68 if portrait or compact_landscape() else 44
	studio_button(camera,"custom_compare","Show preview" if custom.compare else "Show installed")
	var controls:=AutomotiveUI.column(middle,7)
	if not portrait: controls.custom_minimum_size.x=440 if not compact_landscape() else 520
	var categories:=AutomotiveUI.row(controls,6)
	for group in CustomizationView.GROUPS:
		studio_button(categories,"custom_group_"+group,CustomizationView.GROUP_LABELS[group],custom.primary()==group)
	studio_subcategories(controls,custom,id)
	studio_options(controls,custom,id,installed)
	var footer:=AutomotiveUI.row(body,8)
	studio_button(footer,"custom_reset","Factory")
	studio_button(footer,"custom_discard","Discard")
	var choice: int=custom.candidate[custom.category]
	var cost:=studio_price(custom.category,choice)
	var equipped: bool=int(installed[custom.category])==choice
	var label: String = "Equipped" if equipped else (game.missing_credits(cost) if cost>game.profile.credits else ("Equip free" if cost==0 else "Buy / $%d"%cost))
	var purchase:=studio_button(footer,"custom_install",label,false,true)
	purchase.size_flags_stretch_ratio=1.7
	return stage

func studio_badge(stage: Control,value: String,right: bool) -> void:
	var badge:=PanelContainer.new()
	var skin:=AutomotiveUI.surface(Color(.04,.075,.11,.86),Color(.51,.66,.76,.5),6)
	skin.content_margin_left=8
	skin.content_margin_right=8
	skin.content_margin_top=5
	skin.content_margin_bottom=5
	badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel",skin)
	var label:=AutomotiveUI.label(value,13,AutomotiveUI.ORANGE if right else AutomotiveUI.BLUE,true)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	stage.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	badge.offset_left=-144 if right else 12
	badge.offset_right=-12 if right else 144
	badge.offset_top=12

func studio_subcategories(parent: Node,custom: CustomizationView,id: String) -> void:
	var group:=custom.primary()
	if group not in ["paint","wheels"]: return
	var sections:=AutomotiveUI.row(parent,5)
	var labels := {"paint":"Color","finish":"Finish","design":"Design","rim":"Finish"}
	for key in (["paint","finish"] if group=="paint" else CustomizationView.GROUPS.wheels):
		if VehicleAppearance.definition(id).compatible.has(key):
			studio_button(sections,"custom_category_"+key,labels[key],custom.category==key)
	if group!="paint": return
	var trim:=CustomizationView.TRIM.filter(func(key): return VehicleAppearance.definition(id).compatible.has(key))
	if trim.is_empty(): return
	studio_button(sections,"custom_trim","Trim",custom.trim_open)
	if custom.trim_open:
		var extra:=grid(parent,3 if portrait else trim.size(),5)
		var trim_labels:={"stance":"Height","spoiler":"Spoiler","headlight":"Lamps","taillight":"Tail lamps"}
		for key in trim:
			studio_button(extra,"custom_category_"+key,trim_labels[key],custom.category==key)

func studio_price(key: String,choice: int) -> int:
	return 0 if game.profile.owned_appearance.has(key+":"+str(choice)) else int(VehicleAppearance.PRICES[key][choice])

func studio_options(parent: Node,custom: CustomizationView,id: String,installed: Dictionary) -> void:
	var scroll:=catalog_scroll(parent,"StudioOptions",0)
	scroll.follow_focus=true
	scroll.custom_minimum_size.y=(130 if custom.trim_open else 246) if portrait else (136 if compact_landscape() else 246)
	var options:=grid(scroll,3,7)
	var key:=custom.category
	for choice in VehicleAppearance.OPTIONS[key].size():
		if not VehicleAppearance.compatible(id,key,choice): continue
		var card:=AutomotiveUI.content_card(options,120 if not compact_landscape() else 108,int(custom.candidate[key])==choice)
		bind(card,"custom_pick_%d"%choice)
		var content: VBoxContainer=card.get_meta("content")
		if key in CustomizationView.TRIM:
			var sample: Dictionary=custom.candidate.duplicate(true)
			sample[key]=choice
			vehicle(content,id,game.car,sample,45,false)
		else:
			var swatch:=CosmeticSwatch.new()
			content.add_child(swatch)
			swatch.configure(game,key,choice)
			swatch.custom_minimum_size.y=42 if compact_landscape() else 56
		var cost:=studio_price(key,choice)
		var equipped: bool=int(installed[key])==choice
		var status:="Equipped" if equipped else ("Owned" if cost==0 else "$%d"%cost)
		var title_text:=cosmetic_name(key,choice,custom.candidate)
		content.add_child(AutomotiveUI.label(title_text,(15 if compact_landscape() else 14) if title_text.length()>14 else (17 if compact_landscape() else 16)))
		content.add_child(AutomotiveUI.label(status,15,GlassPalette.GREEN if equipped else AutomotiveUI.MUTED,true))
		card.tooltip_text=title_text+" / "+status

func cosmetic_name(key: String,index: int,look: Dictionary) -> String:
	return str(VehicleAppearance.OPTIONS[key][index])
