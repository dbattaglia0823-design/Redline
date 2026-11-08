class_name GarageHub
extends RefCounted

var g: Node2D
var categories := true
var selected := 0
var owned_selection := ""
var owned_page := 0
var owned_filter := 0
var owned_sort := false
var dyno_open := false
var show_hp := true
var show_torque := true
var _cars: Dictionary = {}
var studio: UpgradeStudio
const CATEGORY_SLOTS := [["internals","displacement","compression"],["intake"],["exhaust"],["fuel"],["ecu"],["induction","charge_pressure","charge_response","charge_airflow","charge_cooling","boost"],[],VehicleParts.TRANSMISSION_UPGRADES,["clutch"],["differential"],["tires"],["suspension"],[],["wheels"],[]]
const STAGE_CATEGORIES := [0,2,5,6,7,12,14]
const CATEGORIES := [["Engine internals",0,0],["Intake",0,3],["Exhaust",5,0],["Fuel system",0,4],["ECU",0,5],["Forced induction",1,0],["Nitrous",7,0],["Transmission",4,-1],["Clutch",4,1],["Differential / gearing",2,1],["Tires",2,0],["Suspension",3,0],["Brakes",6,-1],["Wheels",2,1],["Weight reduction",3,-1]]
const SHORT_NAMES := ["Engine", "Intake", "Exhaust", "Fuel system", "ECU", "Induction", "Nitrous", "Transmission", "Clutch", "Differential", "Tires", "Suspension", "Brakes", "Wheels", "Weight"]
func _init(game: Node2D) -> void:
	g = game; studio=UpgradeStudio.new(game)
func t(s: String,x: float,y: float,size: int = 18,c: Color = Color("f2eee4")) -> void: g.text_at(s,x,y,size,c)
func b(id: String,s: String,r: Rect2,primary: bool = false) -> void: g.button(id,s,r,primary)
func vehicle(id: String) -> Drivetrain:
	var entry: Dictionary = g.profile.garage[id].duplicate(true)
	if id == g.profile.vehicle_id: entry = {"stages":g.profile.stages,"hardware":g.profile.hardware}
	var key := id+JSON.stringify(entry)
	if not _cars.has(key):
		var c := Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id)); c.configure(entry.stages); c.configure_build(entry.get("hardware",{}),id,false)
		_cars[key] = c
	if _cars.size() > 64: var keep = _cars[key]; _cars.clear(); _cars[key] = keep
	return _cars[key]
static func peak_torque(c: Drivetrain) -> float:
	var peak := 0.0
	for rpm in range(int(c.idle_rpm),int(c.redline_rpm)+1,50): peak = maxf(peak,c.full_engine_torque(rpm))
	return peak
static func grip(c: Drivetrain) -> float: return c.effective_grip()
func stats(c: Drivetrain) -> Array:
	return ["%d %sHP" % [c.peak_horsepower(),"ICE " if float(c._base_spec.get("hybrid_kw",0))>0 else ""],"%.0f lb-ft" % ImperialUnits.torque(peak_torque(c)),"%.2f GRIP" % grip(c),"%.0f lb" % ImperialUnits.pounds(c.mass())]
func draw_garage() -> void:
	var spec := GameCatalog.spec(g.profile.vehicle_id)
	t("YOUR GARAGE",36,103,11,g.MUTED)
	t(str(spec.name),36,143,34)
	t(ImperialUnits.engine_label(g.car.engine_label)+"  /  "+str(spec.drive),38,170,15,g.MUTED)
	b("hub_owned","Change car",Rect2(986,116,180,48))
	g.draw_workshop(Rect2(36,192,1130,354))
	t(configuration_label()+" / "+PerformanceClasses.label(g.profile),60,221,13,g.MUTED)
	b("open_tuning","Test track",Rect2(60,242,188,44))
	g.draw_car(Vector2(180,240),3.6,g.PAINTS[g.profile.paint],0,g.profile.wheels,false,g.profile.vehicle_id,-1,.315,g.car)
	draw_stat_strip(Rect2(36,562,786,84))
	draw_race_action(Rect2(846,562,320,84))

func configuration_label() -> String:
	var names := {"hpattern":"Manual","paddle":"Paddle","sequential":"Sequential","automatic":"Automatic"}
	return "%d-speed %s  /  %s" % [g.car.gear_ratios.size(),names.get(g.car.control_mode,"Paddle"),GameCatalog.stage_name(4,g.profile.stages[4])]

func draw_stat_strip(r: Rect2,columns: int = 4) -> void:
	# Read-only telemetry has one quiet surface, rather than four button-like pills.
	g.glass.surface(g,r,Color("151e29d9"),Color("ffffff0c"),18,false)
	var values := ["%d" % g.car.peak_horsepower(),"%.0f" % ImperialUnits.torque(peak_torque(g.car)),"%.2f" % grip(g.car),"%.0f" % ImperialUnits.pounds(g.car.mass())]
	var labels := ["POWER","TORQUE","GRIP","WEIGHT"]
	if float(g.car._base_spec.get("hybrid_kw",0))>0: labels[0]="ENGINE POWER"
	var units := ["hp","lb-ft","","lb"]
	var rows := ceili(4.0/columns)
	var cell := r.size/Vector2(columns,rows)
	var compact: bool = g.is_portrait()
	for i in 4:
		var origin := r.position+Vector2(i%columns,int(i/columns))*cell
		if i%columns > 0: g.draw_line(origin+Vector2(0,20),origin+Vector2(0,cell.y-20),Color("ffffff12"),1,true)
		if i >= columns: g.draw_line(origin+Vector2(20,0),origin+Vector2(cell.x-20,0),Color("ffffff12"),1,true)
		t(labels[i],origin.x+22,origin.y+26,16 if compact else 11,g.MUTED)
		t(values[i],origin.x+22,origin.y+65,34 if compact else 28)
		var width: float = g.font.get_string_size(values[i],HORIZONTAL_ALIGNMENT_LEFT,-1,34 if compact else 28).x
		t(units[i],origin.x+30+width,origin.y+65,18 if compact else 13,g.MUTED)

func draw_race_action(r: Rect2) -> void:
	g.button("race_menu","",r,true)
	t("Find a race",r.position.x+24,r.position.y+40,25 if g.is_portrait() else 21)
	t("Championships & rivals",r.position.x+24,r.position.y+64,18 if g.is_portrait() else 12,Color("f3f5f7cc"))
	var center := Vector2(r.end.x-36,r.get_center().y)
	g.draw_line(center-Vector2(13,0),center+Vector2(6,0),g.INK,1.7,true)
	g.draw_polyline(PackedVector2Array([center+Vector2(0,-6),center+Vector2(6,0),center+Vector2(0,6)]),g.INK,1.7,true)
func owned_ids() -> Array:
	var ids: Array=[]; var times: Dictionary={}
	for id in GameCatalog.CAR_IDS:
		if not g.profile.garage.has(id): continue
		var entry: Dictionary=g.profile.garage[id]
		var build: Dictionary=g.profile.hardware if id==g.profile.vehicle_id else entry.get("hardware",GameCatalog.factory_build(id))
		if owned_filter>0 and GameCatalog.engine_class(id,build)!=PerformanceClasses.ORDER[owned_filter-1]: continue
		ids.append(id)
		if not owned_sort: continue
		var levels: Array=g.profile.stages if id==g.profile.vehicle_id else entry.stages
		var measured:=PerformanceClasses.request(id,levels,build)
		times[id]=float(measured.get("quarter_s",99))
	if owned_sort: ids.sort_custom(func(a,b): return times[a]<times[b])
	return ids

func draw_owned() -> void:
	if owned_selection == "" or not g.profile.garage.has(owned_selection): owned_selection = g.profile.vehicle_id
	var ids:=owned_ids()
	b("owned_filter","Engine class: "+("All" if owned_filter==0 else PerformanceClasses.ORDER[owned_filter-1]),Rect2(36,112,236,48))
	b("owned_sort","Quickest first" if owned_sort else "Collection order",Rect2(284,112,236,48))
	if ids.is_empty(): t("No owned cars in this engine class",36,230,22); b("hub_back","< GARAGE",Rect2(962,103,204,48)); return
	if not ids.has(owned_selection): owned_selection=str(ids[0])
	owned_page = clampi(owned_page,0,maxi(0,ceili(ids.size()/4.0)-1))
	for i in mini(4,ids.size()-owned_page*4):
		var id: String = ids[i+owned_page*4]; var entry: Dictionary = g.profile.garage[id]; var c := vehicle(id); var y := 182+i*110
		g.button("hub_pick_"+id,"",Rect2(36,y,534,100),false,id == owned_selection)
		g.draw_car(Vector2(44,y+19),0.65,g.PAINTS[int(entry.paint)],0,int(entry.wheels),false,id,-1,.315,c)
		g.fit_text(str(GameCatalog.spec(id).name)+(" / ACTIVE" if id == g.profile.vehicle_id else ""),204,y+28,350,20)
		var v := stats(c); t(v[0]+" / "+v[1],204,y+59,16,g.GREEN); t(v[2]+" / "+v[3],204,y+86,15,g.MUTED)
	b("hub_owned_prev","<",Rect2(36,622,90,44))
	b("hub_owned_next",">",Rect2(140,622,90,44))
	t("%d / %d" % [owned_page+1,maxi(1,ceili(ids.size()/4.0))],255,652,16,g.MUTED)
	g.draw_workshop(Rect2(594,182,572,284))
	var e: Dictionary = g.profile.garage[owned_selection]
	g.draw_car(Vector2(616,266),2.1,g.PAINTS[int(e.paint)],0,int(e.wheels),false,owned_selection,-1,.315,vehicle(owned_selection))
	t(str(GameCatalog.spec(owned_selection).name),616,218,26)
	var c := vehicle(owned_selection)
	var values := stats(c)
	for i in 4: t(values[i],615+(i%2)*270,502+int(i/2)*42,22)
	t("VS ACTIVE   %+.0f HP / %+.0f lb-ft / %+.0f lb" % [c.peak_horsepower()-g.car.peak_horsepower(),ImperialUnits.torque(peak_torque(c))-ImperialUnits.torque(peak_torque(g.car)),ImperialUnits.pounds(c.mass())-ImperialUnits.pounds(g.car.mass())],615,590,14,g.MUTED)
	b("hub_equip","ACTIVE CAR" if owned_selection == g.profile.vehicle_id else "DRIVE THIS CAR",Rect2(614,608,532,50),true)
	b("hub_back","< GARAGE",Rect2(962,103,204,48))

func browse_owned(direction: int) -> void:
	var ids:=owned_ids()
	if ids.is_empty(): return
	owned_selection = str(ids[posmod(ids.find(owned_selection)+direction,ids.size())])
	owned_page = int(ids.find(owned_selection)/4)
func draw_upgrades() -> void:
	studio.overview()

func preview() -> Drivetrain:
	if categories: return g.car
	if not g.glass.legacy and g.workshop.mode in ["basic","hardware"]: return studio.candidate()
	if g.workshop.mode == "hardware" and g.workshop._part_preview != null: return g.workshop._part_preview
	if g.workshop.mode == "basic": return g.workshop.stage_preview()
	return g.car
func open_upgrade(index: int) -> void:
	if not categories: studio.remember(selected)
	selected = clampi(index,0,CATEGORIES.size()-1)
	categories = false
	g.workshop.details = false
	g.selected_part = int(CATEGORIES[selected][1])
	g.workshop.category_slots = CATEGORY_SLOTS[selected].duplicate()
	g.workshop.slot_index = 0; g.workshop.parts_page = 0; g.workshop.preview_stage = -1
	g.workshop._preview = null; g.workshop._preview_key = ""; g.workshop._part_preview = null; g.workshop._part_preview_key = ""
	g.workshop.mode = "basic" if selected in STAGE_CATEGORIES else "hardware"
	g.workshop.selected_trans = str(g.profile.hardware.transmission)
	g.workshop.selected_hardware = str(g.profile.hardware.parts.get(g.workshop.current_slot(),"")) if not g.workshop.category_slots.is_empty() else ""
	studio.restore(selected)
	if selected in [5,7]:
		g.workshop.mode = "hardware" if selected==5 else "transmission"
		g.workshop.slot_index = 0
		g.workshop.selected_trans = str(g.profile.hardware.transmission)
		g.workshop.selected_hardware = str(g.profile.hardware.parts.get("induction","")) if selected==5 else ""
	if g.native_workshop!=null and g.native_workshop.supports():
		# The native sheet uses a tint, not a screen-copy blur. Avoid GPU readback.
		g.glass.backdrop=null; g.glass.sheet_age=1.0
	else: g.glass.capture_backdrop(g)
func draw_upgrade_window() -> void:
	studio.detail()

static func curve(c: Drivetrain) -> Array:
	var out: Array = []
	for rpm in range(int(c.idle_rpm),int(c.redline_rpm)+1,50):
		var torque := c.full_engine_torque(rpm)
		out.append(Vector3(rpm,torque*rpm/7127.0,torque))
	return out
func draw_graph(r: Rect2,current: Drivetrain,candidate: Drivetrain,label_size: int = 12) -> void:
	var cars := [current] if candidate == null else [current,candidate]
	var fade: float = g.glass.curve_alpha(r,str(current.get_instance_id())+":"+str(current.peak_horsepower())+":"+str(candidate.get_instance_id() if candidate != null else 0))
	var xmax := current.redline_rpm; var ymax := 1.0
	for c in cars:
		xmax = maxf(xmax,c.redline_rpm)
		for p in curve(c): ymax = maxf(ymax,maxf(p.y,ImperialUnits.torque(p.z)))
	ymax = ceil(ymax/100.0)*100.0
	for i in 5:
		var y := r.end.y-r.size.y*i/4.0
		g.draw_line(Vector2(r.position.x,y),Vector2(r.end.x,y),Color(GlassPalette.BLUE,.14),1,true)
		t("%.0f" % (ymax*i/4.0),r.position.x-58 if label_size > 12 else r.position.x-38,y+4,label_size,g.MUTED)
	for i in 5: t("%.1f" % (xmax*i/4000.0),r.position.x+r.size.x*i/4.0-6,r.end.y+24,label_size,g.MUTED)
	t("RPM x1000",r.position.x+r.size.x*.34,r.end.y+52,label_size,g.MUTED)
	for n in cars.size():
		var points := curve(cars[n])
		for line in 2:
			if (line == 0 and not show_hp) or (line == 1 and not show_torque): continue
			var projected := PackedVector2Array()
			for point in points:
				var value: float = point.y if line == 0 else ImperialUnits.torque(point.z)
				projected.append(Vector2(r.position.x+point.x/xmax*r.size.x,r.end.y-value/ymax*r.size.y))
			var color: Color = LiquidGlass.PALETTE.orange if line == 0 else LiquidGlass.PALETTE.green
			var width := 1.6 if r.size.y < 120 else 2.2
			if n == 0: g.draw_polyline(projected,Color(color,fade if cars.size() == 1 else .48),width,true)
			else:
				for start in range(0,projected.size()-1,5):
					g.draw_polyline(projected.slice(start,mini(start+3,projected.size())),Color(color,fade),width,true)
func draw_dyno_overlay() -> void:
	g.buttons.clear(); g.glass.modal(g,Rect2(0,0,1200,760),g.profile.effects_quality)
	g.begin_sheet()
	g.box(Rect2(20,86,1160,638),Color("151e2bf5"),Color(GlassPalette.BLUE,.5))
	t("LIVE DYNO / "+str(GameCatalog.spec(g.profile.vehicle_id).name),42,127,28)
	b("hub_dyno_close","< RETURN",Rect2(966,100,198,48))
	g.button("hub_hp","HP "+("ON" if show_hp else "OFF"),Rect2(42,160,230,48),false,show_hp)
	g.button("hub_torque","TORQUE lb-ft "+("ON" if show_torque else "OFF"),Rect2(286,160,230,48),false,show_torque)
	t("Solid: installed / Dashed: compatible preview",550,191,17,g.MUTED)
	var c := preview()
	draw_graph(Rect2(100,250,1010,300),g.car,c)
	t("HP",48,240,16,g.ORANGE); t("lb-ft",94,240,16,g.GREEN)
	t("PEAK POWER  %d > %d HP" % [g.car.peak_horsepower(),c.peak_horsepower()],60,640,24,g.ORANGE)
	t("PEAK TORQUE  %.0f > %.0f lb-ft" % [ImperialUnits.torque(peak_torque(g.car)),ImperialUnits.torque(peak_torque(c))],620,640,24,g.GREEN)
	t("Steady full throttle / no nitrous / drivetrain and chassis effects shown in parts",60,696,16,g.MUTED)
	g.end_sheet()
func back() -> bool:
	if dyno_open: dyno_open = false; return true
	if g.tab == "style": g.menu.customize.action("custom_back"); return true
	if g.tab == "owned": g.tab = "garage"; return true
	if g.tab == "performance":
		if not categories: studio.remember(selected); categories = true
		else: g.tab = "garage"
		return true
	return false
func action(id: String) -> bool:
	if id=="owned_filter": owned_filter=(owned_filter+1)%7; owned_page=0; return true
	if id=="owned_sort": owned_sort=not owned_sort; owned_page=0; return true
	if id.begins_with("upgrade_system_"): studio.system=clampi(int(id.trim_prefix("upgrade_system_")),0,UpgradeStudio.GROUPS.size()-1); categories=true; return true
	if id.begins_with("hw_slot_") and not categories: g.workshop.mode="hardware"
	if id == "hub_owned_prev": owned_page = maxi(0,owned_page-1)
	elif id == "hub_owned_next": owned_page += 1
	elif id == "cycle_car" or id == "hub_owned":
		owned_selection = g.profile.vehicle_id; g.tab = "owned"
		var ids: Array = []
		for car_id in GameCatalog.CAR_IDS:
			if g.profile.garage.has(car_id): ids.append(car_id)
		owned_page = int(maxi(0,ids.find(owned_selection))/4)
	elif id == "hub_upgrades": g.tab = "performance"; categories = true
	elif id == "hub_back": back()
	elif id.begins_with("hub_pick_"): owned_selection = id.trim_prefix("hub_pick_")
	elif id == "hub_equip": g.profile.select_vehicle(owned_selection); g.refresh_car()
	elif id == "hub_dyno": g.glass.capture_backdrop(g); dyno_open = true
	elif id == "hub_dyno_close": dyno_open = false
	elif id == "hub_hp": show_hp = not show_hp
	elif id == "hub_torque": show_torque = not show_torque
	elif id == "hub_test": categories = false; g.workshop.mode = "test"
	elif id.begins_with("upgrade_section_"):
		g.workshop.action("work_"+id.trim_prefix("upgrade_section_"))
	elif id.begins_with("hub_category_"): open_upgrade(int(id.trim_prefix("hub_category_")))
	elif id.begins_with("part_"):
		var mapping := [0,5,10,14,7,2,12,6]
		open_upgrade(mapping[clampi(int(id.trim_prefix("part_")),0,7)])
	elif id.begins_with("work_"): categories = false; return false
	else: return false
	return true

