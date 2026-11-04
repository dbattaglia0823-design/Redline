class_name DealershipView
extends RefCounted

var g: Node2D
var age := 1.0
var page := 0
var class_filter := 0
var class_picker := true
var remembered: Dictionary = {}
var equip := true
var details := false
var _factory: Dictionary = {}
const CLASSES := ["All classes","E","D","C","B","A","S"]
func _init(game: Node2D) -> void: g = game
func t(s: String,x: float,y: float,size: int = 16,c: Color = Color("f2eee4")) -> void: g.text_at(s,x,y,size,c)
func b(id: String,s: String,r: Rect2,primary: bool = false) -> void: g.button(id,s,r,primary)
func factory(id: String) -> Drivetrain:
	if not _factory.has(id):
		var c := Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id)); c.configure(GameCatalog.blank_stages()); c.configure_build(GameCatalog.factory_build(id),id,false)
		_factory[id] = c
	return _factory[id]
func class_ids(letter: String) -> Array[String]:
	var ids: Array[String]=[]
	for id in GameCatalog.CAR_IDS:
		if PerformanceClasses.factory_class(id)==letter: ids.append(id)
	return ids
func filtered() -> Array[String]:
	return class_ids(CLASSES[class_filter]) if class_filter>0 else GameCatalog.CAR_IDS.duplicate()
func open() -> void:
	show_classes()
func show_classes() -> void:
	if not class_picker and class_filter>0: remembered[CLASSES[class_filter]]=GameCatalog.CAR_IDS[g.dealer_index]
	class_picker=true; details=false; age=0
func enter_class(letter: String) -> void:
	var ids:=class_ids(letter)
	if ids.is_empty(): return
	class_filter=CLASSES.find(letter); class_picker=false; details=false
	var selected: String=remembered.get(letter,ids[0])
	if not ids.has(selected): selected=ids[0]
	g.dealer_index=GameCatalog.CAR_IDS.find(selected); page=int(ids.find(selected)/4); age=0
const CLASS_NAMES := ["Street","Sport","Tuner","Performance","Elite","Hyper / Drag"]
const CLASS_TIMES := ["15.0s+","14.0–15.0s","13.0–14.0s","12.0–13.0s","10.5–12.0s","Under 10.5s"]
func draw_classes(mobile: bool=false) -> void:
	for i in 6:
		var letter: String=CLASSES[i+1]; var ids:=class_ids(letter)
		var r:=Rect2(24+(i%2)*284,100+int(i/2)*280,268,268) if mobile else Rect2(36+(i%3)*384,196+int(i/3)*230,362,212)
		g.button("shop_class_"+letter,"",r,false,false)
		t(letter,r.position.x+20,r.position.y+54,44,GlassPalette.BLUE)
		g.fit_text(CLASS_NAMES[i],r.position.x+78,r.position.y+42,r.size.x-98,22 if mobile else 24)
		t("%d cars"%ids.size(),r.position.x+80,r.position.y+65,17 if mobile else 13,g.MUTED)
		if ids.is_empty(): continue
		var cheapest: String=ids[0]
		for id in ids:
			if int(GameCatalog.spec(id).price)<int(GameCatalog.spec(cheapest).price): cheapest=id
		g.draw_car(r.position+Vector2(12,78 if mobile else 65),1.05 if mobile else 1.4,g.PAINTS[2],0,0,false,cheapest)
		t("From $%d"%int(GameCatalog.spec(cheapest).price),r.position.x+20,r.end.y-47 if mobile else r.end.y-20,20 if mobile else 15)
		t(CLASS_TIMES[i]+"  /  1/4 mile",r.position.x+20,r.end.y-20,16,g.MUTED) if mobile else t(CLASS_TIMES[i],r.end.x-122,r.end.y-20,14,g.MUTED)
func estimate(id: String) -> Dictionary:
	return RaceAI.estimate({"model":id,"stages":GameCatalog.blank_stages(),"hardware":GameCatalog.factory_build(id),"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8})
func navigate(direction: int) -> void:
	if class_picker: return
	var ids := filtered()
	if ids.is_empty(): return
	var position := posmod(ids.find(GameCatalog.CAR_IDS[g.dealer_index])+direction,ids.size())
	page = int(position/4)
	g.dealer_index = GameCatalog.CAR_IDS.find(ids[position])
	age = 0

func select_edge(last: bool) -> void:
	if class_picker: return
	var ids := filtered()
	if ids.is_empty(): return
	g.dealer_index = GameCatalog.CAR_IDS.find(ids[-1] if last else ids[0])
	page = int((ids.size()-1)/4) if last else 0
	age = 0
func draw() -> void:
	if class_picker: draw_classes(); return
	b("shop_classes","< Classes",Rect2(36,182,180,48))
	t("CLASS "+CLASSES[class_filter]+" / "+CLASS_NAMES[class_filter-1],238,213,18,g.MUTED)
	b("shop_details","DETAILS" if not details else "CLOSE DETAILS",Rect2(962,103,204,48))
	var ids:=filtered()
	if ids.is_empty(): show_classes(); return
	page = clampi(page,0,maxi(0,ceili(ids.size()/4.0)-1))
	var id: String = GameCatalog.CAR_IDS[clampi(g.dealer_index,0,GameCatalog.CAR_IDS.size()-1)]
	if not ids.has(id): id = ids[page*4]; g.dealer_index = GameCatalog.CAR_IDS.find(id)
	page=int(ids.find(id)/4)
	var s := GameCatalog.spec(id); var c := factory(id)
	g.draw_workshop(Rect2(36,246,726,270))
	t(str(s.brand)+" / "+str(s.year),58,277,18,g.MUTED)
	g.draw_car(Vector2(72+pow(1-age,2)*18,290),2.65,g.PAINTS[2],0,0,false,id)
	for i in mini(4,ids.size()-page*4):
		var item: String = ids[page*4+i]; var x := 36+i*184
		g.button("dealer_%d" % GameCatalog.CAR_IDS.find(item),"",Rect2(x,530,173,92),false,item == id)
		g.draw_car(Vector2(x+8,532),.60,g.PAINTS[2],0,0,false,item)
		t(str(GameCatalog.spec(item).name),x+9,610,14)
	b("shop_prev","<",Rect2(36,630,90,44)); b("shop_next",">",Rect2(140,630,90,44))
	t("%d / %d   /   %d CARS" % [page+1,ceili(ids.size()/4.0),ids.size()],255,660,16,g.MUTED)
	g.box(Rect2(786,246,380,428))
	g.fit_text(str(s.name),807,281,337,27)
	t("CLASS "+PerformanceClasses.factory_class(id)+" / "+str(s.engine),808,309,13,g.MUTED)
	t("%d %sHP / %.0f NM" % [c.peak_horsepower(),"ICE " if float(s.get("hybrid_kw",0))>0 else "",GarageHub.peak_torque(c)],808,347,23,g.GREEN)
	t("%.0f KG / %.2f GRIP" % [c.mass(),GarageHub.grip(c)],808,378,19)
	t("%s / %d-SPEED %s" % [s.drive,c.gear_ratios.size(),c.transmission_kind.to_upper()],808,411,15,g.MUTED)
	var et := preview_estimate(id)
	var active := {"model":g.profile.vehicle_id,"stages":g.profile.stages,"hardware":g.profile.hardware,"reaction":.25,"pedal":1.0,"skill":2,"shift_error":0,"traction_skill":.8}
	var current := RaceAI.request_estimate(active)
	t("1/4 EST %.2f S / %.1f MPH" % [et.time,et.mph] if not et.is_empty() else "MEASURING...",808,447,17,g.GREEN)
	t("VS ACTIVE %+.0f HP / %+.0f NM" % [c.peak_horsepower()-g.car.peak_horsepower(),GarageHub.peak_torque(c)-GarageHub.peak_torque(g.car)],808,478,14)
	t("%+.0f KG / %+.2f GRIP" % [c.mass()-g.car.mass(),GarageHub.grip(c)-GarageHub.grip(g.car)],808,503,14,g.MUTED)
	var owned: bool = g.profile.garage.has(id)
	var locked: bool = g.profile.level() < int(s.get("unlock_level",1)) and not owned
	t("OWNED" if owned else "$%d" % int(s.price),808,544,29,g.GREEN if owned else g.INK)
	var label: String = "LEVEL %d REQUIRED" % int(s.get("unlock_level",1)) if locked else ("DRIVING" if id == g.profile.vehicle_id else ("DRIVE THIS CAR" if owned else ("PURCHASE" if g.profile.credits >= int(s.price) else g.missing_credits(int(s.price)))))
	b("drive_car" if owned else "buy_car",label,Rect2(808,562,336,50),not locked and (owned or g.profile.credits >= int(s.price)))
	if not owned: b("shop_equip","EQUIP ON PURCHASE: "+("YES" if equip else "NO"),Rect2(808,623,336,44))
	if details: draw_details(s,c)
func draw_details(s: Dictionary,c: Drivetrain) -> void:
	g.buttons.clear(); g.draw_rect(Rect2(36,176,1130,499),g.BG)
	b("shop_details","< RETURN",Rect2(962,182,204,48))
	t(str(s.name)+" / FACTORY DETAILS",55,218,28)
	var ratios := ""
	for ratio in c.gear_ratios: ratios += "%.3f  " % ratio
	var lines := [str(s.engine)+" / "+str(s.drive),"Idle %.0f / limiter %.0f RPM" % [c.idle_rpm,c.redline_rpm],"Mass %.0f kg / inertia %.3f kg m2" % [c.mass(),c.engine_inertia],"Tire radius %.3f m / final drive %.2f" % [c.tire_radius,c.final_drive],"%s / %.0f ms / %.0f Nm rating" % [c.transmission_kind,c.shift_duration*1000,c.input_capacity()],"Gear ratios: "+ratios,"Efficiency %.1f%% / peak boost %.2f bar" % [c.trans_efficiency*100,c.boost_target(c.redline_rpm,1.0)],"Original illustrations / configurable display names","Class benchmark: competent driver, zero reaction / no nitrous.","Compared with your active installed build; factory figures exclude upgrades."]
	if float(s.get("hybrid_kw",0))>0: lines[7]="Electric assist: %.0f kW / %.1f kWh; dyno shows combustion engine." % [s.hybrid_kw,s.hybrid_kwh]
	for i in lines.size(): t(lines[i],56,263+i*38,17,g.MUTED if i >= 7 else g.INK)
func action(id: String) -> bool:
	if id.begins_with("shop_class_"): enter_class(id.trim_prefix("shop_class_"))
	elif id=="shop_classes": show_classes()
	elif id == "shop_car_prev" or id == "shop_car_next": navigate(-1 if id == "shop_car_prev" else 1)
	elif id == "shop_prev" or id == "shop_next":
		var ids := filtered(); page = clampi(page+(-1 if id == "shop_prev" else 1),0,maxi(0,ceili(ids.size()/4.0)-1))
		if not ids.is_empty(): g.dealer_index = GameCatalog.CAR_IDS.find(ids[page*4])
		age = 0
	elif id == "shop_equip": equip = not equip
	elif id == "shop_details": details = not details
	elif id.begins_with("dealer_") and id.trim_prefix("dealer_").is_valid_int(): g.dealer_index = clampi(int(id.trim_prefix("dealer_")),0,GameCatalog.CAR_IDS.size()-1); age = 0
	elif id == "buy_car":
		if g.profile.buy_vehicle(GameCatalog.CAR_IDS[g.dealer_index],equip): g.refresh_car(); g.show_toast("Added to your collection")
		else: g.show_toast("Locked, owned, or insufficient credits")
	else: return false
	return true

func preview_estimate(id: String) -> Dictionary:
	var measured:=PerformanceClasses.factory(id)
	if measured.is_empty(): return {}
	return {"time":measured.quarter_s,"mph":measured.trap_mph}





