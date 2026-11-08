class_name UpgradeStudio
extends RefCounted

# Presentation and pure candidate specifications only. All spending/installation
# continues through DriverProfile and UpgradeWorkshop, never through previews.
const SYSTEMS := ["Engine & Power","Drivetrain","Chassis & Grip"]
const GROUPS := [[0,1,2,3,4,5,6],[7,8,9],[10,11,12,13,14]]
const PACKAGE_NAMES := {0:"Airflow build",2:"Exhaust system",5:"Turbo package",6:"Nitrous kit",7:"Gearbox internals",12:"Brake package",14:"Weight reduction"}
const EXPLAIN := {
 "internals":"Strength and inertia; ECU needed for higher RPM.",
 "displacement":"Longer stroke increases torque, mass and rotating inertia.",
 "compression":"More compression needs the ethanol-ready fuel system.",
 "intake":"Improves high-RPM breathing; does not replace the engine build.",
 "exhaust":"The manifold complements the separate downstream exhaust package.",
 "fuel":"Fuel-flow headroom. No gain below the fuel limit.",
 "ecu":"Street unlocks launch tuning. Programmable and higher add rev-limit tuning. Track and Motorsport improve power.",
 "induction":"Replaces package boost, spool and onset.",
 "boost":"Adjusts pressure within the installed assembly's supported range.",
 "clutch":"More coupling capacity; gearbox internals remain the upper limit.",
 "differential":"Improves driven-axle traction, with a small mass tradeoff.",
 "final_drive":"Unlocks matched gearing sets; shorter gearing trades speed for torque.",
 "wheels":"Changes wheel mass and rotational inertia independently of tire compound.",
 "tires":"Softer compounds put more torque down at launch. Drag rubber adds rolling drag and rotating mass.",
 "suspension":"Transfers load to the driven axle and controls wheel hop. Adjustable setups unlock launch damping.",
}
var g: Node2D
var system := 0
var remembered: Dictionary = {}
var tx_key := ""
var tx_car: Drivetrain
var number_pair:=RegEx.new()

func _init(game: Node2D) -> void:
	g=game; number_pair.compile("(-?[0-9]+(?:\\.[0-9]+)?)\\s*>\\s*(-?[0-9]+(?:\\.[0-9]+)?)")
func t(s: String,x: float,y: float,size: int=16,c: Color=GlassPalette.INK) -> void: g.text_at(s,x,y,size,c)
func button(id: String,s: String,r: Rect2,primary: bool=false,selected: bool=false) -> void: g.button(id,s,r,primary,selected)
func fit(s: String,x: float,y: float,width: float,size: int=18,c: Color=GlassPalette.INK) -> void:
	while size>12 and g.font.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width: size-=1
	t(s,x,y,size,c)
func remember(index: int) -> void:
	var w: UpgradeWorkshop=g.workshop; var data: Dictionary={}
	for key in ["mode","slot_index","parts_page","preview_stage","selected_hardware","selected_trans","filter_index","page","gear_index"]: data[key]=w.get(key)
	remembered[index]=data
func restore(index: int) -> void:
	if index not in GROUPS[system]:
		for i in GROUPS.size():
			if index in GROUPS[i]:
				system=i
				break
	if remembered.has(index):
		for key in remembered[index]: g.workshop.set(key,remembered[index][key])
	# Never reopen a removed per-upgrade tuning page after a hot reload.
	if g.workshop.mode=="tune":
		g.workshop.mode="basic" if index in GarageHub.STAGE_CATEGORIES else "hardware"

func status(index: int) -> String:
	var h: GarageHub=g.menu.hub; var count:=0
	for slot in GarageHub.CATEGORY_SLOTS[index]:
		if g.profile.hardware.parts.has(slot): count+=1
	if index in GarageHub.STAGE_CATEGORIES: return GameCatalog.stage_name(int(GarageHub.CATEGORIES[index][1]),int(g.profile.stages[int(GarageHub.CATEGORIES[index][1])]))+(" / %d parts"%count if count>0 else "")
	if index in [10,11,13]:
		var slot: String=GarageHub.CATEGORY_SLOTS[index][0]
		var part: Dictionary=VehicleParts.PARTS.get(g.profile.hardware.parts.get(slot,""),{})
		return str(part.get("name",VehicleParts.factory_name(slot)))
	return "%d fitted"%count if count>0 else "Factory hardware"
func headline(index: int) -> String:
	var c: Drivetrain=g.car
	match index:
		0,1,2: return "%d hp / %.0f lb-ft"%[c.peak_horsepower(),ImperialUnits.torque(GarageHub.peak_torque(c))]
		3: return "Fuel support %.0f lb-ft"%ImperialUnits.torque(c.fuel_torque_capacity())
		4: return "Limiter %.0f rpm"%c.redline_rpm
		5: return "%.1f PSI / belt drive"%PressureUnits.psi(c.boost_target(c.redline_rpm,1)) if c._supercharger!="" else "%.1f PSI / %.0f rpm onset"%[PressureUnits.psi(c.boost_target(c.redline_rpm,1)),c.turbo_onset()]
		6: return "%.1f seconds spray"%c.nitrous_capacity()
		7: return "%d gears / %.0f ms shifts"%[c.gear_ratios.size(),c.shift_duration*1000]
		8: return "%.0f lb-ft clutch capacity"%ImperialUnits.torque(c.clutch_capacity())
		9: return "%.2f final drive"%c.final_drive
		10: return "%.2f grip / %.1f in radius"%[GarageHub.grip(c),ImperialUnits.inches(c.tire_radius)]
		11: return "%.2f launch transfer"%c.load_transfer_scale
		12: return "%.1f m/s2 brake limit"%brake_limit(c)
		13: return "%.1f in radius / %.2f lb·ft²"%[ImperialUnits.inches(c.tire_radius),ImperialUnits.inertia(c.wheel_inertia)]
		14: return "%.0f lb vehicle mass"%ImperialUnits.pounds(c.mass())
	return ""

func overview() -> void:
	var mobile: bool=g.is_portrait()
	if mobile:
		g.mobile.header("UPGRADES")
		fit(str(GameCatalog.spec(g.profile.vehicle_id).name),24,108,340,25)
		t("%d hp / %.0f lb-ft"%[g.car.peak_horsepower(),ImperialUnits.torque(GarageHub.peak_torque(g.car))],24,148,22,g.MUTED)
		button("open_tuning","Tuning",Rect2(214,80,166,68))
		button("hub_dyno","Live Dyno",Rect2(396,80,180,68))
	else:
		button("open_tuning","Tuning",Rect2(634,103,154,48))
		button("hub_test","Test build",Rect2(800,103,156,48))
		button("hub_dyno","Live Dyno",Rect2(968,103,198,48))
	for i in SYSTEMS.size():
		button("upgrade_system_%d"%i,SYSTEMS[i],Rect2(24+i*184,176,176,68) if mobile else Rect2(36+i*380,182,370,48),false,system==i)
	var hero := Rect2(24,258,552,180) if mobile else Rect2(36,246,1130,170)
	g.draw_workshop(hero if mobile else Rect2(36,246,740,170))
	if not mobile: g.glass.surface(g,Rect2(790,246,376,170))
	g.draw_car(Vector2(38,249) if mobile else Vector2(120,235),1.85 if mobile else 2.05,g.PAINTS[g.profile.paint],0,g.profile.wheels,false,g.profile.vehicle_id,-1,.315,g.car)
	if not mobile:
		t("CURRENT BUILD",800,275,12,GlassPalette.BLUE)
		fit(str(GameCatalog.spec(g.profile.vehicle_id).name),800,305,340,23)
		t("%d hp   /   %.0f lb-ft"%[g.car.peak_horsepower(),ImperialUnits.torque(GarageHub.peak_torque(g.car))],800,338,18)
		t("%.0f lb   /   %.2f grip"%[ImperialUnits.pounds(g.car.mass()),GarageHub.grip(g.car)],800,369,15,g.MUTED)
		t(g.menu.hub.configuration_label(),800,397,11,GlassPalette.BLUE)
	for position in GROUPS[system].size():
		var index: int=GROUPS[system][position]
		var r:=Rect2(24+(position%2)*284,454+int(position/2)*116,268,106) if mobile else Rect2(36+(position%4)*285,432+int(position/4)*120,272,108)
		button("hub_category_%d"%index,"",r,false,g.menu.hub.selected==index)
		g.glass.icon(g,str(GarageHub.CATEGORIES[index][0]),r.position+Vector2(17,20),26,g.ORANGE if g.menu.hub.selected==index else g.MUTED)
		fit(GarageHub.SHORT_NAMES[index],r.position.x+56,r.position.y+37,r.size.x-70,21 if mobile else 19)
		fit(status(index),r.position.x+17,r.position.y+64,r.size.x-34,17 if mobile else 13,g.MUTED)
		g.draw_line(r.position+Vector2(17,74),Vector2(r.end.x-17,r.position.y+74),Color(GlassPalette.BLUE,.2),1,true)
		fit(headline(index),r.position.x+17,r.position.y+94,r.size.x-34,16 if mobile else 14,g.INK)
	if mobile: button("hub_test","Test this build",Rect2(24,1022,552,76))

func sections() -> Array:
	var h: GarageHub=g.menu.hub; var result: Array=[]
	if h.selected in GarageHub.STAGE_CATEGORIES: result.append({"id":"upgrade_section_basic","label":PACKAGE_NAMES[h.selected],"selected":g.workshop.mode=="basic"})
	if h.selected==7: result.append({"id":"upgrade_section_transmission","label":"Gearbox","selected":g.workshop.mode=="transmission"})
	for i in GarageHub.CATEGORY_SLOTS[h.selected].size():
		var slot: String=GarageHub.CATEGORY_SLOTS[h.selected][i]
		result.append({"id":"hw_slot_%d"%i,"label":UpgradeWorkshop.TITLES[slot],"selected":g.workshop.mode=="hardware" and g.workshop.slot_index==i})
	return result

func detail() -> void:
	var mobile: bool=g.is_portrait(); var h: GarageHub=g.menu.hub; var w: UpgradeWorkshop=g.workshop
	g.buttons.clear(); g.glass.modal(g,Rect2(0,0,600,1300) if mobile else Rect2(0,0,1200,760),g.profile.effects_quality); g.begin_sheet()
	g.box(Rect2(12,12,576,1230) if mobile else Rect2(20,96,1160,620),LiquidGlass.PALETTE.modal_surface,Color(GlassPalette.BLUE,.5))
	if mobile:
		g.mobile.header("Vehicle test" if w.mode=="test" else str(GarageHub.CATEGORIES[h.selected][0]))
		button("hub_back","< Systems",Rect2(24,80,264,68)); button("hub_dyno","Live Dyno",Rect2(312,80,264,68))
	else:
		t("Vehicle test" if w.mode=="test" else str(GarageHub.CATEGORIES[h.selected][0]),42,137,26)
		t("$%d"%g.profile.credits,752,141,20,g.GREEN)
		t(str(GameCatalog.spec(g.profile.vehicle_id).name)+" / "+status(h.selected),43,165,13,g.MUTED)
		button("hub_dyno","Live Dyno",Rect2(912,112,112,48)); button("hub_back","Close  x",Rect2(1036,112,128,48))
	if w.mode!="test":
		var entries:=sections()
		for i in (entries.size() if entries.size()>1 else 0):
			var r:=Rect2(24+(i%3)*184,180+int(i/3)*76,172,68) if mobile else Rect2(36+i*(1130.0/entries.size()),187,1130.0/entries.size()-8,48)
			button(entries[i].id,entries[i].label,r,false,entries[i].selected)
	match w.mode:
		"basic","hardware": options(mobile); comparison(mobile)
		"transmission":
			if mobile: g.mobile.gearboxes()
			else: w.draw_transmissions()
		"test":
			if mobile: g.mobile.vehicle_test()
			else: w.draw_test()
	g.end_sheet()

func options(mobile: bool) -> void:
	var w: UpgradeWorkshop=g.workshop
	var y:=354 if mobile else 256
	if w.mode=="basic":
		var stage: int=g.profile.stages[g.selected_part]; w.stage_preview()
		for target in range(GameCatalog.max_stage(g.selected_part)+1):
			var r:=Rect2(24,y+target*70,552,64) if mobile else Rect2(36,y+target*52,654,46)
			button("stage_pick_%d"%target,"",r,false,w.preview_stage==target)
			fit(GameCatalog.stage_name(g.selected_part,target),r.position.x+16,r.position.y+(38 if mobile else 29),r.size.x-180,21 if mobile else 18)
			var state: String="Equipped" if target==stage else ("Owned" if target<=g.profile.highest_stage(g.selected_part) else "$%d"%g.profile.upgrade_cost(g.selected_part,target))
			t(state,r.end.x-140,r.position.y+(38 if mobile else 29),18 if mobile else 14,g.GREEN if target<=stage else g.MUTED)
		if mobile and GameCatalog.max_stage(g.selected_part)<5 and engine_changed(g.car,w._preview):
			t("HP",24,654,17,g.ORANGE); t("lb-ft",68,654,17,g.GREEN)
			t("Solid installed / dashed preview",124,654,17,g.MUTED)
			g.menu.hub.draw_graph(Rect2(76,678,470,60),g.car,w._preview,18)
		if not mobile:
			var illustration_y:=576 if GameCatalog.max_stage(g.selected_part)>3 else 502
			g.glass.icon(g,str(GarageHub.CATEGORIES[g.menu.hub.selected][0]),Vector2(54,illustration_y),48,g.MUTED)
			fit(PACKAGE_NAMES.get(g.menu.hub.selected,"Performance package"),125,illustration_y+22,540,18)
			fit("A complete progression package; individual components stay separate.",125,illustration_y+46,540,13,g.MUTED)
	else:
		var ids: Array=[""]; var slot:=w.current_slot()
		for id in VehicleParts.PARTS:
			if VehicleParts.PARTS[id].slot==slot: ids.append(id)
		w.parts_page=clampi(w.parts_page,0,maxi(0,ceili(ids.size()/3.0)-1))
		if not ids.has(w.selected_hardware): w.selected_hardware=""
		for i in mini(3,ids.size()-w.parts_page*3):
			var id: String=ids[w.parts_page*3+i]; var p: Dictionary=VehicleParts.PARTS.get(id,{})
			var r:=Rect2(24,y+i*92,552,84) if mobile else Rect2(36,y+i*92,654,84)
			button("hw_pick_"+id if id!="" else "hw_pick_factory","",r,false,id==w.selected_hardware)
			fit(str(p.get("name","Package assembly" if slot=="induction" and g.car.turbo_stage>0 else VehicleParts.factory_name(slot))),r.position.x+16,r.position.y+31,r.size.x-32,21 if mobile else 19)
			var equipped: bool=str(g.profile.hardware.parts.get(slot,""))==id
			var owned: bool=id=="" or VehicleParts.is_owned(g.profile.hardware,id)
			var reason: String=VehicleParts.compatible(id,g.profile.hardware,int(g.profile.stages[4])) if id!="" else ""
			var state: String="Equipped" if equipped else (reason if reason!="" else ("Owned" if owned else "$%d"%int(p.cost)))
			if not owned and g.profile.hardware.owned_parts.has(id): state="New fitment / $%d"%int(p.cost)
			fit(state,r.position.x+16,r.position.y+62,r.size.x-32,18 if mobile else 14,g.GREEN if equipped or owned else g.MUTED)
			if not mobile: g.glass.icon(g,str(GarageHub.CATEGORIES[g.menu.hub.selected][0]),Vector2(r.end.x-67,r.position.y+19),42,g.ORANGE if w.selected_hardware==id else g.MUTED)
		if ids.size()>3:
			button("hw_prev","<",Rect2(24,646,100,68) if mobile else Rect2(36,552,70,46))
			button("hw_next",">",Rect2(476,646,100,68) if mobile else Rect2(620,552,70,46))
			t("%d / %d"%[w.parts_page+1,maxi(1,ceili(ids.size()/3.0))],260 if mobile else 340,687 if mobile else 582,18 if mobile else 14,g.MUTED)

func candidate() -> Drivetrain:
	if not g.glass.legacy and g.native_workshop!=null:
		var quote: Dictionary=g.native_workshop.active_quote()
		return g.native_workshop.quote_preview(quote) if quote.reason=="" else g.car
	return g.workshop.stage_preview() if g.workshop.mode=="basic" else g.workshop.part_comparison().car

func comparison(mobile: bool) -> void:
	var w: UpgradeWorkshop=g.workshop; var h: GarageHub=g.menu.hub
	var c:=candidate(); var index: int=h.selected; var slot:=w.current_slot() if w.mode=="hardware" else ""
	var part: Dictionary=VehicleParts.PARTS.get(w.selected_hardware,{}) if w.mode=="hardware" else {}
	var name: String=GameCatalog.stage_name(g.selected_part,w.preview_stage) if w.mode=="basic" else str(part.get("name",VehicleParts.factory_name(slot)))
	var current_name: String=GameCatalog.stage_name(g.selected_part,int(g.profile.stages[g.selected_part])) if w.mode=="basic" else str(VehicleParts.PARTS.get(str(g.profile.hardware.parts.get(slot,"")),{}).get("name",VehicleParts.factory_name(slot)))
	var x:=24.0 if mobile else 744.0; var top:=790.0 if mobile else 247.0
	if mobile:
		if w.mode=="basic" and not (GameCatalog.max_stage(g.selected_part)<5 and engine_changed(g.car,c)):
			top=354+(GameCatalog.max_stage(g.selected_part)+1)*70+24
		elif w.mode=="hardware":
			var count:=1
			for definition in VehicleParts.PARTS.values():
				if definition.slot==slot: count+=1
			top=746 if count>3 else 354+mini(3,count)*92+24
	if not mobile: g.box(Rect2(722,247,444,382))
	fit(name,x+(0 if mobile else 0),top+30,552 if mobile else 400,23 if mobile else 22)
	fit("Installed: "+current_name,x,top+59,552 if mobile else 400,17 if mobile else 13,g.MUTED)
	var graph: bool=not mobile and engine_changed(g.car,c) and index in [0,1,2,4,5]
	var reason: String=w.part_comparison().reason if w.mode=="hardware" else ""
	if w.mode=="basic": reason=g.profile.upgrade_reason(g.selected_part)
	var rows: Array=w.part_details(part) if reason!="" else metrics(g.car,c,index,slot)
	if not w.details:
		for i in mini(3 if mobile else (2 if graph else 4),rows.size()):
			fit(rows[i],x,top+103+i*(33 if mobile else 39),552 if mobile else 400,20 if mobile else 18,metric_color(rows[i]))
		if graph:
			if slot in ["induction","boost"]: fit("%.1f > %.1f PSI / onset %.0f > %.0f rpm"%[PressureUnits.psi(g.car.boost_target(g.car.redline_rpm,1)),PressureUnits.psi(c.boost_target(c.redline_rpm,1)),boost_onset(g.car),boost_onset(c)],744,421,400,13,g.MUTED)
			h.draw_graph(Rect2(787,438,329,102),g.car,c)
		elif not mobile:
			var estimates: String="Supporting hardware needed for a race projection." if reason!="" else race_comparison(c)
			t(estimates,744,571,14,g.MUTED)
	else:
		var details: Array=w.part_details(part) if w.mode=="hardware" else package_details(index)
		for i in mini(4,details.size()): fit(str(details[i]),x,top+103+i*(30 if mobile else 39),552 if mobile else 400,18 if mobile else 14,g.MUTED)
	var description: String=str(EXPLAIN.get(slot,package_description(index))) if w.mode=="hardware" else package_description(index)
	if w.mode=="basic" and w.preview_stage<int(g.profile.stages[g.selected_part]): description="This tier is owned and can be equipped free."
	if mobile and slot in ["induction","boost"]: description="Onset %.0f > %.0f rpm / response %.2f > %.2f s"%[boost_onset(g.car),boost_onset(c),spool(g.car),spool(c)]
	if w.mode=="hardware" and g.profile.hardware.owned_parts.has(w.selected_hardware) and not VehicleParts.is_owned(g.profile.hardware,w.selected_hardware): description="Owned for another gearbox; this one needs a new fitment."
	if w.mode=="hardware" and w.selected_hardware=="": description="Restores this slot's factory or packaged specification."
	if mobile:
		# Details remain optional; the dedicated dyno is always in the fixed header.
		var audition: bool=index in [0,1,2,4,5,6,7,8]
		button("details_toggle","Less" if w.details else "Details",Rect2(24,1120,264 if audition else 552,68))
		if audition: button("sound_preview","Sound preview",Rect2(312,1120,264,68))
		fit(reason if reason!="" else description,24,1008,552,17,g.ORANGE if reason!="" else g.MUTED)
		purchase(Rect2(24,1030,552,76))
	else:
		fit(reason if reason!="" else description,744,612,400,12,g.ORANGE if reason!="" else g.MUTED)
		button("details_toggle","Less" if w.details else "Details",Rect2(36,640,180,52))
		if index in [0,1,2,4,5,6,7,8]: button("sound_preview","Sound preview",Rect2(232,640,200,52))
		purchase(Rect2(742,640,402,52))

func purchase(r: Rect2) -> void:
	var w: UpgradeWorkshop=g.workshop; var label: String; var id: String; var price:=0; var primary:=true
	if w.mode=="basic":
		var current: int=g.profile.stages[g.selected_part]
		id="install_%d_%d"%[g.selected_part,w.preview_stage]; price=g.profile.upgrade_cost(g.selected_part,w.preview_stage)
		label="Equipped" if w.preview_stage==current else ("Equip Free" if price==0 else "Purchase / $%d"%price)
		primary=w.preview_stage!=current
		if g.profile.upgrade_quote(g.selected_part,w.preview_stage).reason!="" and primary: label="Hardware required"; primary=false
	else:
		id="hw_buy"; var data:=w.part_comparison(); var slot:=w.current_slot()
		var owned: bool=w.selected_hardware=="" or VehicleParts.is_owned(g.profile.hardware,w.selected_hardware)
		price=0 if owned else int(data.part.get("cost",0))
		var equipped: bool=str(g.profile.hardware.parts.get(slot,""))==w.selected_hardware
		label="Equipped" if equipped else ("Locked" if data.reason!="" else ("Install owned" if owned else "Purchase / $%d"%price))
		primary=not equipped and data.reason==""
	if primary and price>g.profile.credits: label=g.missing_credits(price)
	button(id,label,r,primary)

static func engine_changed(a: Drivetrain,b: Drivetrain) -> bool:
	if a.redline_rpm!=b.redline_rpm: return true
	# A single high-RPM comparison misses low/mid-range changes from induction
	# hardware. Use the same 50 RPM resolution as the expanded live dyno.
	for rpm in range(int(minf(a.idle_rpm,b.idle_rpm)),int(a.redline_rpm)+1,50):
		if absf(a.full_engine_torque(rpm)-b.full_engine_torque(rpm))>.01: return true
	return false
static func brake_limit(c: Drivetrain) -> float: return minf(8*(1+c.brake_stage*.18),9.81*c.brake_grip())
static func boost_onset(c: Drivetrain) -> float: return c.idle_rpm if c._supercharger!="" else c.turbo_onset()
static func spool(c: Drivetrain) -> float: return .045 if c._supercharger!="" else (c._spool_override if c._spool_override>0 else [.32,.24,.38,.55][c.turbo_stage])
static func metric(label: String,a: float,b: float,unit: String,precision: int=0) -> String:
	if unit=="bar":
		a=PressureUnits.psi(a); b=PressureUnits.psi(b); unit="PSI"; precision=1
	a=ImperialUnits.value(a,unit); b=ImperialUnits.value(b,unit); unit=ImperialUnits.unit(unit)
	var format: String="%."+str(precision)+"f"
	return label+"  "+(format%a)+" > "+(format%b)+(" "+unit if unit!="" else "")
func metrics(a: Drivetrain,b: Drivetrain,index: int,slot: String) -> Array[String]:
	var rows: Array[String]=[]
	if engine_changed(a,b):
		rows.append(metric("Power",a.peak_horsepower(),b.peak_horsepower(),"hp")); rows.append(metric("Torque",GarageHub.peak_torque(a),GarageHub.peak_torque(b),"Nm"))
	match slot:
		"internals": rows.append(metric("Engine support",a.mechanical_torque_capacity(),b.mechanical_torque_capacity(),"Nm")); rows.append(metric("RPM headroom",a._mechanical_redline,b._mechanical_redline,"rpm")); rows.append(metric("Usable torque",a.supported_engine_torque(),b.supported_engine_torque(),"Nm"))
		"fuel": rows.append(metric("Fuel support",a.fuel_torque_capacity(),b.fuel_torque_capacity(),"Nm")); rows.append(metric("Usable torque limit",a.supported_engine_torque(),b.supported_engine_torque(),"Nm"))
		"ecu": rows.append(metric("Rev limiter",a.redline_rpm,b.redline_rpm,"rpm")); rows.append("Launch tuning: "+("Unlocked" if b.hardware.parts.has("ecu") else "Factory")); rows.append("Rev-limit tuning: "+("Unlocked" if VehicleParts.can_tune_rpm(b.hardware) else "Factory"))
		"induction","boost": rows.append(metric("Boost",a.boost_target(a.redline_rpm,1),b.boost_target(b.redline_rpm,1),"bar",2)); rows.append(metric("Boost onset",boost_onset(a),boost_onset(b),"rpm"))
		"clutch": rows.append(metric("Clutch capacity",a.clutch_capacity(),b.clutch_capacity(),"Nm")); rows.append(metric("Gearbox rating",a.input_capacity(),b.input_capacity(),"Nm"))
		"differential": rows.append(metric("Grip",GarageHub.grip(a),GarageHub.grip(b),"",2)); rows.append(metric("Mass",a.mass(),b.mass(),"kg"))
		"tires":
			rows.append(metric("Road grip",a.effective_grip(),b.effective_grip(),"",2))
			rows.append(metric("Launch grip",a.traction_grip(4,1,0),b.traction_grip(4,1,0),"",2))
			rows.append(metric("Rolling resistance",a.rolling_coefficient*a.pressure_rolling*100,b.rolling_coefficient*b.pressure_rolling*100,"%",2))
			rows.append(metric("Mass",a.mass(),b.mass(),"kg",1))
		"suspension":
			rows.append(metric("Launch grip",a.traction_grip(4,1,0),b.traction_grip(4,1,0),"",2))
			rows.append(metric("Wheel hop damping",a.hop_damping*100,b.hop_damping*100,"%"))
			rows.append(metric("Driven axle transfer",a.load_transfer_scale,b.load_transfer_scale,"",2))
			rows.append(metric("Mass",a.mass(),b.mass(),"kg",1))
		"wheels":
			rows.append(metric("Mass",a.mass(),b.mass(),"kg"))
		"final_drive": rows.append(metric("Final drive",a.final_drive,b.final_drive,"",2)); rows.append("Matched ratio tuning: "+("Unlocked" if b.hardware.parts.has("final_drive") else "Factory"))
	if slot=="":
		match index:
			5:
				rows.append(metric("Boost",a.boost_target(a.redline_rpm,1),b.boost_target(b.redline_rpm,1),"bar",2))
				rows.append(metric("Boost onset",boost_onset(a),boost_onset(b),"rpm"))
				rows.append(metric("Spool response",spool(a),spool(b),"s",2))
				if b.hardware.parts.has("induction"): rows.append("Fitted assembly controls the boost curve")
			6: rows.append(metric("Spray capacity",a.nitrous_capacity(),b.nitrous_capacity(),"s",1)); rows.append(metric("Nozzle request",a.nitrous_torque_gain()*100,b.nitrous_torque_gain()*100,"%",1)); rows.append(metric("Torque ceiling",a.supported_engine_torque(),b.supported_engine_torque(),"Nm"))
			7: rows.append(metric("Shift time",a.shift_duration*1000,b.shift_duration*1000,"ms")); rows.append(metric("Input rating",a.input_capacity(),b.input_capacity(),"Nm")); rows.append(metric("Clutch capacity",a.clutch_capacity(),b.clutch_capacity(),"Nm"))
			10: rows.append(metric("Grip",GarageHub.grip(a),GarageHub.grip(b),"",2))
			12: rows.append(metric("Brake limit",brake_limit(a),brake_limit(b),"m/s2",2)); rows.append(metric("Vehicle mass",a.mass(),b.mass(),"kg"))
			14: rows.append(metric("Vehicle mass",a.mass(),b.mass(),"kg"))
	if rows.is_empty():
		rows.append(metric("Power",a.peak_horsepower(),b.peak_horsepower(),"hp"))
		rows.append(metric("Torque",GarageHub.peak_torque(a),GarageHub.peak_torque(b),"Nm"))
	if slot=="wheels": rows.append(metric("Rolling radius",a.tire_radius*1000,b.tire_radius*1000,"mm")); rows.append(metric("Wheel inertia",a.wheel_inertia,b.wheel_inertia,"kg m2",2))
	return rows

func metric_color(value: String) -> Color:
	var pair:=number_pair.search(value)
	if pair==null: return g.MUTED
	var before:=float(pair.get_string(1)); var after:=float(pair.get_string(2))
	if is_equal_approx(before,after): return g.MUTED
	for neutral in ["radius","inertia","transfer","Final drive","Nozzle","Stall","Multiplication","Forward gears"]:
		if value.contains(neutral): return g.INK
	var less_good:=value.contains("Mass") or value.contains("mass") or value.contains("Shift") or value.contains("ramp") or value.contains("onset") or value.contains("Spool") or value.contains("1/4 est") or value.begins_with("Rolling resistance") or value.begins_with("60-foot ET") or value.begins_with("0–60 mph") or value.begins_with("1/4-mile ET") or value.begins_with("Time in wheelspin") or value.begins_with("Clutch slip time") or value.begins_with("Gearbox slip time")
	return g.GREEN if (after<before if less_good else after>before) else Color("eea29b")

func package_description(index: int) -> String:
	match index:
		0: return "Base airflow calibration; internals and ECU are separate."
		2: return "Downstream exhaust system; the manifold is a separate component."
		5: return "Base turbo package. A fitted assembly replaces its boost curve."
		6: return "Bottle and nozzle packages add manually activated spray."
		7: return "Internal strength and shift execution; the gearbox is bought separately."
		10: return "Rubber compound; wheel mass and dimensions are separate."
		12: return "Braking hardware, capped by tire-road grip."
		14: return "Removes chassis mass; engine output unchanged."
	return "Changes apply only after purchase or installation."
func package_details(index: int) -> Array:
	var c:=candidate()
	return [package_description(index),"Purchased tiers and all lower levels can be equipped free.","Parts remain individually owned and reinstallable.","Engine limiter %.0f rpm / mass %.0f lb"%[c.redline_rpm,ImperialUnits.pounds(c.mass())]]

func build_runs(c: Drivetrain) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for car in [g.car,c]:
		var stages := [car.engine_stage,car.turbo_stage,car.tire_stage,car.weight_stage,car.gearbox_stage,car.exhaust_stage,car.brake_stage,car.nitrous_stage]
		results.append(PerformanceClasses.request(g.profile.vehicle_id,stages,car.hardware))
	return results

func traction_projection(c: Drivetrain) -> Array[String]:
	var results:=build_runs(c)
	var rows: Array[String] = []
	if results[0].is_empty() or results[1].is_empty():
		rows.append("Measuring launches and quarter-mile runs…")
		return rows
	for row in [["60-foot ET","sixty_ft_s"],["0–60 mph","zero_60_s"],["1/4-mile ET","quarter_et_s"],["Time in wheelspin","wheelspin_s"],["Clutch slip time","clutch_slip_s"],["Gearbox slip time","gearbox_slip_s"]]:
		var before: Variant=results[0].get(row[1])
		var after: Variant=results[1].get(row[1])
		if before!=null and after!=null: rows.append(metric(row[0],float(before),float(after),"s",2))
	return rows

func race_comparison(c: Drivetrain) -> String:
	var contracts: Array=[]
	for car in [g.car,c]:
		contracts.append({"model":g.profile.vehicle_id,"stages":[car.engine_stage,car.turbo_stage,car.tire_stage,car.weight_stage,car.gearbox_stage,car.exhaust_stage,car.brake_stage,car.nitrous_stage],"hardware":car.hardware,"reaction":0.0,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8})
	var a:=RaceAI.request_estimate(contracts[0]); var b:=RaceAI.request_estimate(contracts[1])
	return "1/4 mile: measuring both builds..." if a.is_empty() or b.is_empty() else "1/4 est  %.2f > %.2f s / no NOS"%[a.time,b.time]

func transmission_candidate() -> Drivetrain:
	var w: UpgradeWorkshop=g.workshop
	var key:=JSON.stringify([g.profile.vehicle_id,g.profile.stages,g.profile.hardware,w.selected_trans])
	if key==tx_key and tx_car!=null: return tx_car
	tx_key=key
	var build: Dictionary=g.profile.hardware.duplicate(true); var levels: Array=g.profile.stages.duplicate()
	build.performance_stages[build.transmission]=int(levels[4])
	VehicleParts.switch_transmission(build,w.selected_trans)
	levels[4]=int(build.performance_stages.get(w.selected_trans,0))
	tx_car=Drivetrain.new(); tx_car.configure_vehicle(GameCatalog.spec(g.profile.vehicle_id)); tx_car.configure(levels); tx_car.configure_build(build,g.profile.vehicle_id,false)
	return tx_car

func transmission_summary() -> void:
	var w: UpgradeWorkshop=g.workshop; var c:=transmission_candidate(); var s:=TransmissionCatalog.spec(w.selected_trans)
	g.box(Rect2(722,247,444,382))
	fit(str(s.name),744,282,400,23)
	fit("Installed: "+str(TransmissionCatalog.spec(g.car.transmission_id).name),744,311,400,13,g.MUTED)
	var rows: Array=[]
	if not w.details:
		rows=[metric("Forward gears",g.car.gear_ratios.size(),c.gear_ratios.size(),""),metric("Shift time",g.car.shift_duration*1000,c.shift_duration*1000,"ms"),metric("Input rating",g.car.input_capacity(),c.input_capacity(),"Nm"),metric("Vehicle mass",g.car.mass(),c.mass(),"kg")]
	else:
		rows=[metric("Efficiency",g.car.trans_efficiency*100,c.trans_efficiency*100,"%",1),"Controls: "+g.car.control_mode+" > "+c.control_mode]
		var ratios: String=""
		for i in c.gear_ratios.size():
			ratios+="%d:%.2f  "%[i+1,c.gear_ratios[i]]
			if i==4: rows.append(ratios); ratios=""
		if ratios!="": rows.append(ratios)
	for i in mini(4,rows.size()): fit(str(rows[i]),744,353+i*36,400,17,metric_color(str(rows[i])) if not w.details else g.MUTED)
	var reason: String=""
	if not TransmissionCatalog.compatible(w.selected_trans,g.profile.vehicle_id): reason="Incompatible drivetrain layout"
	elif g.profile.transmission_unlock_stage()<int(s.stage): reason=TransmissionCatalog.STAGES[int(s.stage)]+" gearbox build required"
	fit(reason if reason!="" else race_comparison(c),744,520,400,14,g.ORANGE if reason!="" else g.MUTED)
	fit("Conversion replaces gearbox-specific internals and their tuning.",744,553,400,12,g.MUTED)
	button("details_toggle","Less" if w.details else "Details",Rect2(744,580,400,46))
	var owned: bool=g.profile.hardware.owned_transmissions.has(w.selected_trans)
	var label: String="Equipped" if w.selected_trans==g.car.transmission_id else ("Locked" if reason!="" else ("Install owned" if owned else "Purchase / $%d"%int(s.cost)))
	if reason=="" and not owned and int(s.cost)>g.profile.credits: label=g.missing_credits(int(s.cost))
	button("tx_buy",label,Rect2(742,640,402,52),reason=="" and w.selected_trans!=g.car.transmission_id)

