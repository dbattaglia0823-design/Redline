class_name CustomizationView
extends RefCounted

var g: Node2D
var category := "paint"
var candidate: Dictionary = {}
var vehicle_id := ""
var compare := false

func _init(game: Node2D) -> void: g = game
func open() -> void:
	vehicle_id = g.profile.vehicle_id; candidate = g.profile.appearance_for(vehicle_id); compare = false
	var supported: Array = VehicleAppearance.definition(vehicle_id).compatible
	if not supported.has(category): category = str(supported[0]) if not supported.is_empty() else "paint"
	g.tab = "style"
	g.sync_menu_size()

func portrait() -> bool: return g.get_window().size.x < g.get_window().size.y*.85

func has_preview() -> bool:
	return not candidate.is_empty() and candidate != g.profile.appearance_for(g.profile.vehicle_id)

func large_button(id: String,label: String,r: Rect2,selected: bool = false,primary: bool = false) -> void:
	g.button(id,label,r,primary,selected)

func draw_portrait() -> void:
	if vehicle_id != g.profile.vehicle_id or candidate.is_empty(): open()
	g.text_at("CUSTOMIZE",24,44,28)
	g.text_at("$%d" % g.profile.credits,390,43,22,g.GREEN)
	large_button("custom_back","< GARAGE",Rect2(24,70,200,70))
	large_button("custom_compare","SHOW PREVIEW" if compare else "SHOW INSTALLED",Rect2(236,70,340,70))
	g.draw_workshop(Rect2(24,160,552,240))
	var look: Dictionary = g.profile.appearance_for(vehicle_id) if compare else candidate
	g.draw_car(Vector2(30,173),2.3,g.PAINTS[int(look.paint)],0,int(look.rim),false,vehicle_id,-1,.315,g.car,Vector2.ZERO,0,look)
	g.text_at("INSTALLED" if compare else "PREVIEW",38,190,15,g.GREEN)
	var cats: Array = VehicleAppearance.definition(vehicle_id).compatible
	for i in cats.size():
		var key: String = cats[i]
		large_button("custom_category_"+key,VehicleAppearance.LABELS[VehicleAppearance.CATEGORIES.find(key)].to_upper(),Rect2(24+(i%3)*184,420+int(i/3)*76,172,68),category == key)
	var current: int = g.profile.appearance_for(vehicle_id)[category]
	for i in VehicleAppearance.OPTIONS[category].size():
		if not VehicleAppearance.compatible(vehicle_id,category,i): continue
		var x: float = 24+(i%3)*184; var y: float = 742+int(i/3)*92
		g.button("custom_pick_%d" % i,"",Rect2(x,y,172,84),false,int(candidate[category]) == i)
		swatch(category,i,Vector2(x+16,y+23))
		g.text_at(VehicleAppearance.OPTIONS[category][i],x+32,y+29,18)
		var owned: bool = g.profile.owned_appearance.has(category+":"+str(i)) or int(VehicleAppearance.PRICES[category][i]) == 0
		g.text_at("INSTALLED" if current == i else ("OWNED" if owned else "$%d" % int(VehicleAppearance.PRICES[category][i])),x+16,y+65,18,g.GREEN if owned else g.MUTED)
	var choice := int(candidate[category]); var cost := 0 if g.profile.owned_appearance.has(category+":"+str(choice)) else int(VehicleAppearance.PRICES[category][choice])
	var label := "INSTALLED" if current == choice else ("INSTALL" if cost == 0 else "BUY / $%d" % cost)
	if cost > g.profile.credits: label = g.missing_credits(cost)
	large_button("custom_install",label,Rect2(24,940,552,76),false,true)
	large_button("custom_reset","RESTORE FACTORY",Rect2(24,1032,552,76))
	large_button("custom_discard","DISCARD PREVIEW",Rect2(24,1124,552,68))

func draw() -> void:
	if vehicle_id != g.profile.vehicle_id or candidate.is_empty(): open()
	g.button("custom_back","< GARAGE",Rect2(962,103,204,48))
	g.draw_workshop(Rect2(36,182,1130,244))
	var look: Dictionary = g.profile.appearance_for(vehicle_id) if compare else candidate
	g.draw_car(Vector2(240,184),2.9,g.PAINTS[int(look.paint)],0,int(look.rim),false,vehicle_id,-1,.315,g.car,Vector2.ZERO,0,look)
	g.text_at("INSTALLED" if compare else "PREVIEW",58,211,13,g.GREEN)
	g.button("custom_compare","SHOW PREVIEW" if compare else "SHOW INSTALLED",Rect2(950,198,196,46))
	var cats: Array = VehicleAppearance.definition(vehicle_id).compatible
	for i in cats.size():
		var key: String = cats[i]; var label: String = VehicleAppearance.LABELS[VehicleAppearance.CATEGORIES.find(key)]
		g.button("custom_category_"+key,label.to_upper(),Rect2(36+(i%6)*190,440+int(i/6)*52,178,46),false,category == key)
	var current: int = g.profile.appearance_for(vehicle_id)[category]
	for i in VehicleAppearance.OPTIONS[category].size():
		if not VehicleAppearance.compatible(vehicle_id,category,i): continue
		var x: float = 36+i*190
		var owned: bool = g.profile.owned_appearance.has(category+":"+str(i)) or int(VehicleAppearance.PRICES[category][i]) == 0
		g.button("custom_pick_%d" % i,"",Rect2(x,551,178,64),false,int(candidate[category]) == i)
		swatch(category,i,Vector2(x+17,572))
		g.text_at(str(VehicleAppearance.OPTIONS[category][i]),x+38,576,14)
		g.text_at("INSTALLED" if current == i else ("OWNED" if owned else "$%d" % int(VehicleAppearance.PRICES[category][i])),x+38,602,12,g.GREEN if owned else g.MUTED)
	var choice := int(candidate[category]); var part := category+":"+str(choice)
	var cost := 0 if g.profile.owned_appearance.has(part) else int(VehicleAppearance.PRICES[category][choice])
	var label := "INSTALLED" if current == choice else ("INSTALL" if cost == 0 else "BUY / $%d" % cost)
	if cost > g.profile.credits: label = g.missing_credits(cost)
	g.button("custom_install",label,Rect2(800,630,366,46),true)
	g.button("custom_reset","RESTORE FACTORY",Rect2(36,630,250,46))
	g.button("custom_discard","Discard preview",Rect2(306,630,250,46))

func swatch(key: String,index: int,p: Vector2) -> void:
	var color := Color("9aacbf")
	if key == "paint": color = g.PAINTS[index]
	elif key == "rim": color = [Color("c5cdd2"),Color("b8a077"),Color("6d7b88")][index]
	elif key == "caliper": color = [Color("cc5430"),Color("e53942"),Color("edc343"),Color("bac5cf")][index]
	elif key == "headlight": color = [Color("fff9d9"),Color("b1eaff"),Color("ffcc6c")][index]
	elif key == "taillight": color = [Color("ff5f4f"),Color("ff223f"),Color("542230")][index]
	if key in ["design","sidewall"]:
		var look := VehicleAppearance.normalize({}); look[key] = index
		WheelVisuals.draw_wheel(g,p,12,.6,0,{"angle":0.0,"spoke_angle":0.0,"blur":0.0},1,look)
	else:
		g.draw_circle(p,10,color)
		if key == "finish" and index > 0: g.draw_line(p+Vector2(-6,3),p+Vector2(5,-4),Color.WHITE,1 if index == 1 else 3)

func action(id: String) -> bool:
	if id == "hub_customize" or id == "tab_style": open()
	elif id == "custom_back": g.tab = "garage"; candidate.clear(); compare = false; g.sync_menu_size()
	elif id.begins_with("custom_category_"):
		var key := id.trim_prefix("custom_category_")
		if not VehicleAppearance.definition(g.profile.vehicle_id).compatible.has(key): return true
		category = key; candidate = g.profile.appearance_for(g.profile.vehicle_id); compare = false
	elif id.begins_with("custom_pick_"):
		var index := int(id.trim_prefix("custom_pick_"))
		if VehicleAppearance.compatible(g.profile.vehicle_id,category,index): candidate[category] = index; compare = false
	elif id == "custom_compare": compare = not compare
	elif id == "custom_discard": candidate = g.profile.appearance_for(g.profile.vehicle_id); compare = false
	elif id == "custom_install":
		var message: String = g.profile.install_appearance(category,int(candidate[category]))
		g.show_toast(message,message.begins_with("Installed "))
		candidate = g.profile.appearance_for(g.profile.vehicle_id); compare = false
	elif id == "custom_reset": g.profile.restore_appearance(); candidate = g.profile.appearance_for(g.profile.vehicle_id); compare = false
	else: return false
	return true
