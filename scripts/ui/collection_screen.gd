class_name CollectionScreen
extends WorkshopScreen

var scroll_pointer: int=-1
var scroll_start:=Vector2.ZERO
var scroll_offset:=0
var scroll_moved:=false
var touch_scroll: ScrollContainer

func handle_scroll_touch(event: InputEvent) -> bool:
	# Defer option taps until release so a swipe cannot select an option, and
	# consume the event once through the same existing action dispatcher.
	if not visible or game.screen!="garage" or game.tab!="style" or not compact_landscape():
		scroll_pointer=-1; touch_scroll=null; return super.handle_scroll_touch(event)
	if event is InputEventScreenTouch and event.canceled and event.index==scroll_pointer:
		scroll_pointer=-1; touch_scroll=null; return true
	if event is InputEventScreenTouch and event.pressed and not event.canceled and visible and compact_landscape() and game.tab=="style":
		var scroll: ScrollContainer=find_child("LandscapeOptions",true,false)
		if scroll==null or not scroll.get_global_rect().has_point(event.position): return false
		if scroll_pointer>=0: return true
		scroll_pointer=event.index; touch_scroll=scroll; scroll_start=event.position; scroll_offset=scroll.scroll_horizontal; scroll_moved=false
		return true
	if event is InputEventScreenDrag and event.index==scroll_pointer:
		if is_instance_valid(touch_scroll):
			var delta: float=event.position.x-scroll_start.x
			if absf(delta)>12: scroll_moved=true
			if scroll_moved: touch_scroll.scroll_horizontal=scroll_offset-roundi(delta/game.scale.x)
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

func sync() -> void:
	super.sync()
	if visible and game.screen=="garage" and compact_landscape() and (game.tab!="performance" or game.menu.hub.categories):
		game.buttons=game.buttons.filter(func(entry): return not str(entry.id).begins_with("tab_"))
		game.dock.present(Rect2(24,640,size.x-48,104),game.tab)

# Phase 2 composes the established native surface; the existing models own state.
func supports() -> bool:
	if not game.glass.legacy and game.screen=="garage" and not game.menu.hub.dyno_open and game.tab in ["dealer","owned","style"]: return true
	return super.supports()

func state_key() -> String:
	if game.tab not in ["dealer","owned","style"]: return super.state_key()
	var d: DealershipView=game.menu.dealer; var h: GarageHub=game.menu.hub; var custom: CustomizationView=game.menu.customize
	if game.tab=="style" and (custom.vehicle_id!=game.profile.vehicle_id or custom.candidate.is_empty()): custom.open()
	var measurements: Array=[]
	if game.tab=="dealer":
		for letter in PerformanceClasses.ORDER: measurements.append(d.class_ids(letter))
		if not d.class_picker: measurements.append(d.preview_estimate(GameCatalog.CAR_IDS[game.dealer_index]))
	if game.tab=="owned":
		for id in game.profile.garage:
			var entry: Dictionary=game.profile.garage[id]
			measurements.append(PerformanceClasses.request(id,game.profile.stages if id==game.profile.vehicle_id else entry.stages,game.profile.hardware if id==game.profile.vehicle_id else entry.get("hardware",GameCatalog.factory_build(id))))
	return JSON.stringify([size,game.tab,game.profile.vehicle_id,game.profile.garage,game.profile.stages,game.profile.hardware,game.profile.credits,game.profile.xp,game.profile.appearance_for(game.profile.vehicle_id),game.profile.owned_appearance,game.profile.effects_quality,game.profile.muted,d.class_picker,d.class_filter,d.page,d.details,d.equip,game.dealer_index,h.owned_selection,h.owned_page,h.owned_filter,h.owned_sort,custom.category,custom.candidate,custom.compare,measurements])

func build() -> void:
	if game.tab not in ["dealer","owned","style"]: super.build(); return
	if compact_landscape():
		CollectionLandscape.new(self).build(); build_notice(); return
	var body:=container(Rect2(24,20,552,1100) if portrait else Rect2(36,20,1128,638))
	body.add_theme_constant_override("separation",10 if portrait else 12)
	header(body)
	match game.tab:
		"dealer":
			if game.menu.dealer.class_picker: classes(body)
			else: dealer(body)
		"owned": collection(body)
		"style": customize(body)
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

func classes(body: VBoxContainer) -> void:
	title(body,"Dealership / Class index")
	AutomotiveUI.section_mark(body,"FACTORY INVENTORY  /  USD PRICE CLASS","dealer",AutomotiveUI.BLUE)
	var layout:=grid(body,2 if portrait else 3,14)
	for i in 6:
		var letter: String=PerformanceClasses.ORDER[i]; var ids: Array=game.menu.dealer.class_ids(letter)
		var card:=AutomotiveUI.content_card(layout,236 if portrait else 225)
		AutomotiveUI.class_decal(card,letter,i)
		bind(card,"shop_class_"+letter)
		var content: VBoxContainer=card.get_meta("content")
		content.add_child(AutomotiveUI.label(letter+"  /  "+DealershipView.CLASS_NAMES[i],26,AutomotiveUI.INK))
		if not ids.is_empty():
			var available: Array=ids.filter(func(id): return not game.profile.garage.has(id))
			var offers: Array=ids if available.is_empty() else available
			var cheapest: String=offers[0]
			vehicle(content,cheapest,game.menu.dealer.factory(cheapest),VehicleAppearance.normalize({},2,0),110 if portrait else 104,false)
			content.add_child(AutomotiveUI.label("Collection complete" if available.is_empty() else "Available from $%d"%GameCatalog.spec(cheapest).price,16))
			content.add_child(AutomotiveUI.label("%d cars · %d owned"%[ids.size(),ids.size()-available.size()],14,AutomotiveUI.MUTED))
		else: content.add_child(AutomotiveUI.label("No cars in this price class",16))
		content.add_child(AutomotiveUI.label(GameCatalog.price_band(i),15,AutomotiveUI.MUTED))

func spec_summary(parent: Node,id: String,c: Drivetrain) -> void:
	var layout:=grid(parent,2,6)
	for value in [["ENGINE POWER" if float(GameCatalog.spec(id).get("hybrid_kw",0))>0 else "POWER","%.0f hp"%c.peak_horsepower()],["TORQUE","%.0f Nm"%GarageHub.peak_torque(c)],["WEIGHT","%.0f kg"%c.mass()],["GRIP","%.2f"%GarageHub.grip(c)]]:
		var cell:=AutomotiveUI.column(layout,1); cell.add_child(AutomotiveUI.label(value[0],12,AutomotiveUI.MUTED)); cell.add_child(AutomotiveUI.label(value[1],22))
	if float(GameCatalog.spec(id).get("hybrid_kw",0))>0: parent.add_child(AutomotiveUI.label("Combustion output + %.0f kW electric assist"%GameCatalog.spec(id).hybrid_kw,14,AutomotiveUI.MUTED))

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
	var d: DealershipView=game.menu.dealer; var ids:=d.filtered()
	if ids.is_empty(): d.show_classes(); classes(body); return
	d.page=clampi(d.page,0,maxi(0,ceili(ids.size()/4.0)-1))
	var id: String=GameCatalog.CAR_IDS[game.dealer_index]
	if not ids.has(id): id=ids[d.page*4]; game.dealer_index=GameCatalog.CAR_IDS.find(id)
	d.page=int(ids.find(id)/4)
	var s:=GameCatalog.spec(id); var c:=d.factory(id)
	var top:=AutomotiveUI.row(body)
	var class_back:=button(top,"shop_classes","‹ Class "+GameCatalog.price_class(id)); class_back.custom_minimum_size.x=120; class_back.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	top.add_child(AutomotiveUI.label(str(s.name),26))
	var detail_button:=button(top,"shop_details","Showroom" if d.details else "Details"); detail_button.custom_minimum_size.x=114; detail_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	var main: BoxContainer=VBoxContainer.new() if portrait else HBoxContainer.new(); main.add_theme_constant_override("separation",16); main.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(main)
	var left:=AutomotiveUI.column(main,10); left.size_flags_stretch_ratio=2.1
	if portrait: left.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var hero:=vehicle(left,id,c,VehicleAppearance.normalize({},2,0),190 if portrait else 245); hero.size_flags_vertical=Control.SIZE_EXPAND_FILL
	if portrait:
		left.add_child(AutomotiveUI.label("%s · %s · %s"%[s.year,s.engine,s.drive],18,AutomotiveUI.MUTED))
		left.add_child(AutomotiveUI.label("%.0f %shp / %.0f Nm / %.0f kg / %.2f grip"%[c.peak_horsepower(),"ICE " if float(s.get("hybrid_kw",0))>0 else "",GarageHub.peak_torque(c),c.mass(),GarageHub.grip(c)],20))
		if float(s.get("hybrid_kw",0))>0: left.add_child(AutomotiveUI.label("Electric assist: %.0f kW"%s.hybrid_kw,17,AutomotiveUI.MUTED))
		left.add_child(AutomotiveUI.label("Factory · %d-speed %s"%[c.gear_ratios.size(),c.transmission_kind],17,AutomotiveUI.MUTED))
		var et:=d.preview_estimate(id)
		left.add_child(AutomotiveUI.label("1/4 est · %.2f s / %.1f mph"%[et.time,et.mph] if not et.is_empty() else "Measuring factory performance…",18,AutomotiveUI.BLUE))
	var browse:=grid(left,2 if portrait else 4,8)
	browse.visible=not portrait or not d.details
	for i in mini(4,ids.size()-d.page*4):
		var entry: String=ids[d.page*4+i]
		var state: String="Equipped" if entry==game.profile.vehicle_id else ("Owned" if game.profile.garage.has(entry) else ("Level %d"%GameCatalog.spec(entry).unlock_level if game.profile.level()<int(GameCatalog.spec(entry).unlock_level) else "$%d"%GameCatalog.spec(entry).price))
		var card:=AutomotiveUI.vehicle_card(browse,game,entry,d.factory(entry),VehicleAppearance.normalize({},2,0),state,entry==id,108 if portrait else 115)
		bind(card,"dealer_%d"%GameCatalog.CAR_IDS.find(entry))
	if not portrait or not d.details: page_controls(left)
	var right: VBoxContainer=left if portrait else AutomotiveUI.panel(main)
	if not portrait and not d.details:
		right.add_child(AutomotiveUI.label(str(s.brand)+"  /  "+str(s.year),17,AutomotiveUI.BLUE))
		right.add_child(AutomotiveUI.label("Factory specification · Price class "+GameCatalog.price_class(id),15,AutomotiveUI.MUTED))
		spec_summary(right,id,c)
		right.add_child(AutomotiveUI.label(str(s.drive)+" / %d-speed %s"%[c.gear_ratios.size(),c.transmission_kind],16,AutomotiveUI.MUTED))
		var et:=d.preview_estimate(id)
		right.add_child(AutomotiveUI.label("1/4 est  %.2f s / %.1f mph"%[et.time,et.mph] if not et.is_empty() else "Measuring…",18,AutomotiveUI.BLUE))
		right.add_child(AutomotiveUI.label("VERSUS ACTIVE BUILD",12,AutomotiveUI.MUTED))
		AutomotiveUI.comparison(right,"Power",game.car.peak_horsepower(),c.peak_horsepower(),"hp")
		AutomotiveUI.comparison(right,"Weight",game.car.mass(),c.mass(),"kg",true)
	elif portrait:
		right.add_child(AutomotiveUI.label("Vs active  %+.0f hp / %+.0f Nm / %+.0f kg"%[c.peak_horsepower()-game.car.peak_horsepower(),GarageHub.peak_torque(c)-GarageHub.peak_torque(game.car),c.mass()-game.car.mass()],16,AutomotiveUI.MUTED))
	if d.details: mechanical_details(right,c)
	var owned: bool=game.profile.garage.has(id)
	var reason: String=""
	if not owned and game.profile.level()<int(s.unlock_level): reason="Unlocks at driver level %d"%s.unlock_level
	elif not owned and game.profile.credits<int(s.price): reason=game.missing_credits(int(s.price))
	right.add_child(AutomotiveUI.label("Currently equipped" if id==game.profile.vehicle_id else ("Owned · ready to drive" if owned else "$%d"%s.price),26,AutomotiveUI.ORANGE))
	if reason!="": right.add_child(AutomotiveUI.label(reason,16,AutomotiveUI.MUTED))
	var buy:=AutomotiveUI.row(right)
	button(buy,"drive_car" if owned else "buy_car","Equipped" if id==game.profile.vehicle_id else ("Drive this car" if owned else "Purchase"),true)
	if not owned: button(buy,"shop_equip","Equip: "+("Yes" if d.equip else "No"))

func mechanical_details(parent: Node,c: Drivetrain) -> void:
	var scroll:=ScrollContainer.new(); scroll.name="MechanicalDetails"; scroll.custom_minimum_size.y=180 if portrait else 300; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(scroll)
	var content:=AutomotiveUI.column(scroll,4)
	if not game.glass.reduced_motion:
		scroll.modulate.a=.8; scroll.create_tween().tween_property(scroll,"modulate:a",1.0,.12)
	for line in ["Idle %.0f / limiter %.0f rpm"%[c.idle_rpm,c.redline_rpm],"Final drive %.3f / tire radius %.3f m"%[c.final_drive,c.tire_radius],"%.0f ms shift / %.0f Nm input rating"%[c.shift_duration*1000,c.input_capacity()],"Ratios: "+str(c.gear_ratios),"Efficiency %.1f%% / boost %.2f bar"%[c.trans_efficiency*100,c.boost_target(c.redline_rpm,1)]]:
		var line_label:=AutomotiveUI.label(line,15,AutomotiveUI.MUTED); line_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		line_label.custom_minimum_size.y=72 if line.begins_with("Ratios:") else 30
		content.add_child(line_label)

func collection(body: VBoxContainer) -> void:
	var h: GarageHub=game.menu.hub; var ids:=h.owned_ids()
	title(body,"Your collection","hub_back")
	var filters:=AutomotiveUI.row(body)
	button(filters,"owned_filter","Price class: "+("All" if h.owned_filter==0 else GameCatalog.PRICE_CLASSES[h.owned_filter-1]))
	button(filters,"owned_sort","Quickest first" if h.owned_sort else "Collection order")
	if ids.is_empty(): body.add_child(AutomotiveUI.label("No owned cars in this price class",22)); return
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
	var entry: Dictionary=game.profile.garage[selected]
	var measured:=PerformanceClasses.request(selected,game.profile.stages if selected==game.profile.vehicle_id else entry.stages,game.profile.hardware if selected==game.profile.vehicle_id else entry.get("hardware",GameCatalog.factory_build(selected)))
	var controls: Dictionary={"hpattern":"manual","paddle":"paddle","sequential":"sequential","automatic":"automatic"}
	detail.add_child(AutomotiveUI.label("Price %s / Race %s / %d-speed %s"%[GameCatalog.price_class(selected),measured.get("class","…"),c.gear_ratios.size(),controls.get(c.control_mode,c.control_mode)],16,AutomotiveUI.BLUE))
	detail.add_child(AutomotiveUI.label("Vs active  %+.0f hp / %+.0f Nm / %+.0f kg"%[c.peak_horsepower()-game.car.peak_horsepower(),GarageHub.peak_torque(c)-GarageHub.peak_torque(game.car),c.mass()-game.car.mass()],17,AutomotiveUI.MUTED))
	if portrait: list=AutomotiveUI.column(main,8)
	var cards:=grid(list,2 if portrait else 1,8)
	for i in mini(4,ids.size()-h.owned_page*4):
		var id: String=ids[h.owned_page*4+i]; var owned_car:=h.vehicle(id)
		var card:=AutomotiveUI.vehicle_card(cards,game,id,owned_car,game.profile.appearance_for(id),("Equipped · Price " if id==game.profile.vehicle_id else "Owned · Price ")+GameCatalog.price_class(id),id==selected,108 if portrait else 94)
		bind(card,"hub_pick_"+id)
	page_controls(list,true)
	button(body,"hub_equip","Currently equipped" if selected==game.profile.vehicle_id else "Drive this car",true)

func customize(body: VBoxContainer) -> void:
	var custom: CustomizationView=game.menu.customize; var id: String=game.profile.vehicle_id
	var top:=AutomotiveUI.row(body); top.add_child(AutomotiveUI.label("Paint & trim",30)); button(top,"custom_compare","Show preview" if custom.compare else "Show installed"); button(top,"custom_back","Garage")
	var look: Dictionary=game.profile.appearance_for(id) if custom.compare else custom.candidate
	var hero:=vehicle(body,id,game.car,look,160 if portrait else 210)
	hero.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var viewing:=AutomotiveUI.label("Installed view" if custom.compare else ("Preview" if custom.has_preview() else "Installed"),14,AutomotiveUI.BLUE)
	hero.add_child(viewing); viewing.position=Vector2(16,12); viewing.size=Vector2(170,22)
	var cats:=grid(body,3 if portrait else 6,8)
	for key in VehicleAppearance.definition(id).compatible:
		var b:=button(cats,"custom_category_"+key,VehicleAppearance.LABELS[VehicleAppearance.CATEGORIES.find(key)])
		b.theme_type_variation="Navigation"; b.toggle_mode=true; b.set_pressed_no_signal(custom.category==key)
	var options:=grid(body,3 if portrait else 6,8)
	var installed: Dictionary=game.profile.appearance_for(id); var current: int=installed[custom.category]
	for i in VehicleAppearance.OPTIONS[custom.category].size():
		if not VehicleAppearance.compatible(id,custom.category,i): continue
		var owned: bool=game.profile.owned_appearance.has(custom.category+":"+str(i)) or int(VehicleAppearance.PRICES[custom.category][i])==0
		var b:=AutomotiveUI.content_card(options,112,int(custom.candidate[custom.category])==i); bind(b,"custom_pick_%d"%i)
		var content: VBoxContainer=b.get_meta("content")
		if custom.category in ["tint","stance","spoiler","decal"]:
			var sample: Dictionary=custom.candidate.duplicate(true); sample[custom.category]=i
			vehicle(content,id,game.car,sample,42,false)
		else:
			var swatch:=CosmeticSwatch.new(); content.add_child(swatch); swatch.configure(game,custom.category,i)
		var name: String=cosmetic_name(custom.category,i,custom.candidate)
		content.add_child(AutomotiveUI.label(name,16))
		content.add_child(AutomotiveUI.label("Installed" if current==i else ("Owned" if owned else "$%s"%VehicleAppearance.PRICES[custom.category][i]),14,GlassPalette.GREEN if current==i else AutomotiveUI.MUTED))
	var choice: int=custom.candidate[custom.category]
	var cost: int=0 if game.profile.owned_appearance.has(custom.category+":"+str(choice)) else VehicleAppearance.PRICES[custom.category][choice]
	var status:=AutomotiveUI.row(body)
	status.add_child(AutomotiveUI.label("Preview: "+cosmetic_name(custom.category,choice,custom.candidate) if custom.has_preview() else "Installed appearance",17,AutomotiveUI.BLUE))
	status.add_child(AutomotiveUI.label("Installed: "+cosmetic_name(custom.category,current,installed),16,AutomotiveUI.MUTED))
	var footer:=AutomotiveUI.row(body)
	button(footer,"custom_reset","Restore factory")
	button(footer,"custom_discard","Discard preview")
	button(footer,"custom_install","Installed" if current==choice else (game.missing_credits(cost) if cost>game.profile.credits else ("Install owned" if cost==0 else "Purchase / $%s"%cost)),true)

func cosmetic_name(key: String,index: int,look: Dictionary) -> String:
	if key=="design" and index==0 and int(look.rim)==0 and int(look.caliper)==0 and int(look.sidewall)==0 and VehicleAppearance.definition(game.profile.vehicle_id).has("stock_wheels"): return "Factory wheel"
	return str(VehicleAppearance.OPTIONS[key][index])
