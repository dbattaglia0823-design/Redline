class_name CollectionLandscape
extends RefCounted

# Small landscape windows use the existing wide canvas convention from racing.
# Only presentation changes: every action is bound to the existing controller.
var ui: CollectionScreen
var g: Node2D
func _init(screen: CollectionScreen) -> void: ui=screen; g=screen.game
func text(parent: Node,value: String,points: int=24,color: Color=AutomotiveUI.INK) -> Label:
	var label:=AutomotiveUI.label(value,points,color); parent.add_child(label); return label
func build() -> void:
	var body:=ui.container(Rect2(24,14,ui.size.x-48,614)); body.add_theme_constant_override("separation",12)
	if g.tab=="dealer" and g.menu.dealer.class_picker:
		var heading:=AutomotiveUI.row(body); text(heading,"REDLINE / Choose a price class",32); text(heading,"$%d"%g.profile.credits,26,AutomotiveUI.MUTED)
		# Reuse the existing class-card builder, dropping its repeated heading.
		ui.classes(body)
		body.get_child(1).hide(); body.get_child(2).hide()
		for card in body.get_child(3).get_children():
			card.custom_minimum_size.y=240
			for child in card.get_meta("content").get_children():
				if child is Label: child.add_theme_font_size_override("font_size",22)
		return
	var top:=AutomotiveUI.row(body); top.custom_minimum_size.y=86
	text(top,{"dealer":"Showroom","owned":"Your collection"}[g.tab],32)
	text(top,"$%d"%g.profile.credits,26,AutomotiveUI.MUTED)
	if g.tab=="dealer":
		ui.button(top,"shop_classes","Classes"); ui.button(top,"shop_details","Showroom" if g.menu.dealer.details else "Details")
	elif g.tab=="owned":
		ui.button(top,"owned_filter","Price class: "+("All" if g.menu.hub.owned_filter==0 else GameCatalog.PRICE_CLASSES[g.menu.hub.owned_filter-1]))
		ui.button(top,"owned_sort","Quickest" if g.menu.hub.owned_sort else "Collection order"); ui.button(top,"hub_back","Garage")
	var main:=AutomotiveUI.row(body,24); main.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var left:=AutomotiveUI.column(main,8); left.size_flags_stretch_ratio=1.15
	var right:=AutomotiveUI.column(main,8)
	var footer:=AutomotiveUI.row(body)
	match g.tab:
		"dealer": dealer(left,right,footer)
		"owned": owned(left,right,footer)
func hero(parent: Node,id: String,c: Drivetrain,look: Dictionary) -> void:
	text(parent,str(GameCatalog.spec(id).name),30)
	var view:=ui.vehicle(parent,id,c,look,220); view.size_flags_vertical=Control.SIZE_EXPAND_FILL
	var assist: float=GameCatalog.spec(id).get("hybrid_kw",0)
	text(parent,"%.0f %shp / %.0f Nm / %.0f kg / %.2f grip"%[c.peak_horsepower(),"ICE " if assist>0 else "",GarageHub.peak_torque(c),c.mass(),GarageHub.grip(c)],24)
	if assist>0: text(parent,"Electric assist %.0f kW"%assist,24,AutomotiveUI.BLUE)
func dealer(left: Node,right: Node,footer: Node) -> void:
	var d: DealershipView=g.menu.dealer; var ids:=d.filtered()
	if ids.is_empty(): return
	var id: String=GameCatalog.CAR_IDS[g.dealer_index]
	if not ids.has(id): id=ids[0]; g.dealer_index=GameCatalog.CAR_IDS.find(id)
	d.page=int(ids.find(id)/4)
	var car:=d.factory(id); var spec:=GameCatalog.spec(id)
	hero(left,id,car,VehicleAppearance.normalize({},2,0))
	if d.details: ui.mechanical_details(right,car)
	else:
		var cards:=ui.grid(right,2,8)
		for i in mini(4,ids.size()-d.page*4):
			var item: String=ids[d.page*4+i]
			var state: String="Equipped" if item==g.profile.vehicle_id else ("Owned" if g.profile.garage.has(item) else "$%d"%GameCatalog.spec(item).price)
			var b:=AutomotiveUI.vehicle_card(cards,g,item,d.factory(item),VehicleAppearance.normalize({},2,0),state,item==id,148); ui.bind(b,"dealer_%d"%GameCatalog.CAR_IDS.find(item))
		var et:=d.preview_estimate(id)
		text(right,"Price class %s / %s / %d-speed %s"%[GameCatalog.price_class(id),spec.drive,car.gear_ratios.size(),car.transmission_kind],24,AutomotiveUI.BLUE)
		text(right,"1/4 est %.2f s / %.1f mph"%[et.time,et.mph] if not et.is_empty() else "Measuring…",24)
	var owned: bool=g.profile.garage.has(id)
	text(footer,"Owned" if owned else "$%d"%spec.price,30,AutomotiveUI.ORANGE)
	ui.button(footer,"shop_car_prev","‹ Car"); ui.button(footer,"shop_car_next","Car ›")
	var label: String="Equipped" if id==g.profile.vehicle_id else ("Drive this car" if owned else "Purchase")
	if not owned and g.profile.level()<int(spec.unlock_level): label="Level %d required"%spec.unlock_level
	elif not owned and g.profile.credits<int(spec.price): label=g.missing_credits(int(spec.price))
	ui.button(footer,"drive_car" if owned else "buy_car",label,true)
	if not owned: ui.button(footer,"shop_equip","Equip: "+("Yes" if d.equip else "No"))
	if ids.size()>4:
		ui.button(footer,"shop_prev","‹ Page"); ui.button(footer,"shop_next","Page ›")
func owned(left: Node,right: Node,footer: Node) -> void:
	var h: GarageHub=g.menu.hub; var ids:=h.owned_ids()
	if ids.is_empty(): text(left,"No owned cars in this price class",26); return
	if not ids.has(h.owned_selection): h.owned_selection=ids[0]
	h.owned_page=clampi(h.owned_page,0,maxi(0,ceili(ids.size()/4.0)-1))
	var id: String=h.owned_selection; var c:=h.vehicle(id)
	hero(left,id,c,g.profile.appearance_for(id))
	var engine_class:=GameCatalog.engine_class(id,c.hardware)
	var controls: Dictionary={"hpattern":"manual","paddle":"paddle","sequential":"sequential","automatic":"automatic"}
	text(left,"Price %s / Engine %s / %d-speed %s"%[GameCatalog.price_class(id),engine_class,c.gear_ratios.size(),controls.get(c.control_mode,c.control_mode)],24,AutomotiveUI.BLUE)
	var cards:=ui.grid(right,2,8)
	for i in mini(4,ids.size()-h.owned_page*4):
		var item: String=ids[h.owned_page*4+i]
		var b:=AutomotiveUI.vehicle_card(cards,g,item,h.vehicle(item),g.profile.appearance_for(item),"Equipped" if item==g.profile.vehicle_id else "Owned",id==item,156); ui.bind(b,"hub_pick_"+item)
	text(footer,"Vs active %+.0f hp / %+.0f kg"%[c.peak_horsepower()-g.car.peak_horsepower(),c.mass()-g.car.mass()],24,AutomotiveUI.MUTED)
	if ids.size()>4: ui.button(footer,"hub_owned_prev","‹ Page"); ui.button(footer,"hub_owned_next","Page ›")
	ui.button(footer,"tab_style","Customize"); ui.button(footer,"open_tuning","Test track")
	ui.button(footer,"hub_equip","Equipped" if id==g.profile.vehicle_id else "Drive this car",true)
