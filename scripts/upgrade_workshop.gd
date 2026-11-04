class_name UpgradeWorkshop
extends RefCounted

var g: Node2D
var mode := "basic"
var details := false
var filter_index := 0
var page := 0
var parts_page := 0
var selected_trans := "legacy6"
var slot_index := 0
var category_slots: Array = []
var preview_stage := -1
var selected_hardware := ""
var _part_preview_key := ""
var _part_preview: Drivetrain
var tune_page := 0
var gear_index := 0
var lab: VehicleBench
var lab_result: Dictionary = {}
var lab_build := ""
var _preview: Drivetrain
var _preview_key := ""
const GROUPS := [["internals","displacement","compression","intake","fuel","ecu"],["induction","boost"],["wheels","differential"],["suspension","cooling"],["controls","clutch","converter","transbrake","gearset","final_drive"],["exhaust","intake"],["suspension","cooling"],["nitrous","fuel"]]
const TITLES := {"internals":"Internals","displacement":"Displacement","compression":"Compression","intake":"Intake","fuel":"Fuel delivery","ecu":"ECU","induction":"Turbo / supercharger","boost":"Boost control","clutch":"Clutch packs","converter":"Converter","controls":"Shift hardware","differential":"Differential","final_drive":"Final drive","wheels":"Wheels / tires","suspension":"Suspension","cooling":"Cooling","transbrake":"Transbrake","gearset":"Ratio cassettes","exhaust":"Exhaust","nitrous":"Nitrous control"}

func _init(game: Node2D) -> void: g = game
func t(value: String,x: float,y: float,size: int = 16,color: Color = Color("f2eee4")) -> void: g.text_at(value,x,y,size,color)
func b(id: String,label: String,rect: Rect2,primary: bool = false,selected: bool = false) -> void: g.button(id,label,rect,primary,selected)
func box(rect: Rect2) -> void: g.box(rect)

func draw() -> void:
	match mode:
		"basic": draw_basic()
		"hardware": draw_parts()
		"transmission": draw_transmissions()
		"tune": draw_scoped_tuning()
		"test": draw_test()

func draw_basic() -> void:
	g.menu.hub.studio.options(false); g.menu.hub.studio.comparison(false)

func draw_transmissions() -> void:
	var filters := ["H MANUAL","PADDLE / SEQ","AUTOMATIC","DRAG AUTO"]
	for i in 4: b("tx_filter_%d" % i,filters[i],Rect2(36+i*167,247,157,48),false,filter_index == i)
	var ids := available_transmissions()
	page = clampi(page,0,maxi(0,ceili(ids.size()/4.0)-1))
	for i in 4:
		var n := page*4+i
		if n >= ids.size(): break
		var id: String = ids[n]
		var spec := TransmissionCatalog.spec(id)
		var owned: bool = g.profile.hardware.owned_transmissions.has(id)
		var compatible := TransmissionCatalog.compatible(id,g.profile.vehicle_id)
		var y := 307+i*75
		b("tx_pick_"+id,"",Rect2(36,y,654,65),false,selected_trans == id)
		t(str(spec.name),53,y+26,21,g.INK if compatible else g.MUTED)
		t("%d gears / %s" % [spec.ratios.size(),str(spec.kind).to_upper()],53,y+50,13,g.MUTED)
		t("INSTALLED" if id == str(g.profile.hardware.transmission) else ("OWNED" if owned else "$%d" % int(spec.cost)),526,y+27,18,g.GREEN if owned else g.INK)
		t("FWD unavailable" if not compatible else TransmissionCatalog.STAGES[int(spec.stage)],517,y+51,12,g.MUTED)
	b("tx_prev","<",Rect2(36,611,65,44))
	t("%d / %d" % [page+1,maxi(1,ceili(ids.size()/4.0))],125,641,16,g.MUTED)
	b("tx_next",">",Rect2(219,611,65,44))
	draw_trans_summary()

func draw_trans_summary() -> void:
	g.menu.hub.studio.transmission_summary()

func current_slot() -> String:
	var group: Array = category_slots if not category_slots.is_empty() else GROUPS[g.selected_part]
	slot_index = clampi(slot_index,0,group.size()-1)
	return str(group[slot_index])

func draw_parts() -> void:
	g.menu.hub.studio.options(false); g.menu.hub.studio.comparison(false)

func part_details(part: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	var labels := {"torque":"Displacement / torque factor","flow":"High-RPM flow gain","safe":"Engine torque support","inertia":"Rotating inertia change","redline":"Mechanical RPM headroom","clutch":"Clutch capacity factor","cooling":"Cooling capacity factor","mass":"Mass change, kg","grip":"Effective tire grip gain","radius":"Rolling radius, m","wheel_inertia":"Wheel inertia change","onset":"Turbo onset, RPM","spool":"Spool constant, sec","boost_add":"Extra boost capacity, bar","fuel":"Fuel-flow support factor","pressure":"Supercharger boost, bar","multiplication":"Stall torque multiplication","nitrous_ramp":"Progressive spray, sec","transfer":"Weight-transfer response","shift_scale":"Actuator time factor"}
	for key in labels:
		if not part.has(key): continue
		var value:=float(part[key])
		if key in ["torque","safe","clutch","cooling","fuel","shift_scale"]: rows.append("%s: %.2fx"%[labels[key],value])
		elif key=="flow": rows.append("High-RPM flow potential: +%.1f%%"%(value*100))
		elif key=="onset": rows.append("Boost onset: %.0f RPM"%value)
		elif key=="redline": rows.append("Mechanical RPM headroom: +%.0f RPM"%value)
		else: rows.append("%s: %+.3f"%[labels[key],value])
	if part.has("stall_min"): rows.append("Stall range %.0f - %.0f RPM" % [part.stall_min,part.stall_max])
	if part.has("super"): rows.append("Belt drive / replaces turbo assembly")
	if part.has("launch"): rows.append("Programmable launch / rev limiter")
	if part.has("boost_tune"): rows.append("Adjust pressure within turbo limits")
	if part.has("fine_shift"): rows.append("Individual build-based shift overrides")
	if part.has("ratio_tune"): rows.append("Replaceable ratios within +/-12%")
	if part.has("final_tune"): rows.append("Seven matched sets / 2.73 through 4.30")
	if part.has("brake"): rows.append("Locks output in first, while stationary")
	if rows.is_empty(): rows.append("Factory matched mechanical hardware")
	return rows

func tune_row(label: String, value: String, key: String, y: float, enabled: bool) -> void:
	t(label,57,y+20,15,g.MUTED)
	var needs := {"stall":"Converter kit","launch_rpm":"Programmable ECU","redline":"Programmable ECU","boost":"Boost controller","ratio":"Ratio cassette kit","shift":"Race controller","final_drive":"Final-drive kit","nitrous_ramp":"Progressive kit","firmness":"Auto / DCT hardware"}
	if key=="boost" and g.profile.hardware.parts.values().has("boost_control") and not enabled: needs.boost="Inactive for belt drive" if g.car._supercharger!="" else "Turbo source required"
	t(value if enabled else str(needs.get(key,"Hardware required")),270,y+22,16,g.INK if enabled else g.MUTED)
	b("tune_minus_"+key,"-",Rect2(495,y-8,77,46),false)
	b("tune_plus_"+key,"+",Rect2(584,y-8,77,46),enabled)

func draw_test() -> void:
	box(Rect2(36,247,1130,408))
	t("SAME CAR. SAME ROAD. REAL PHYSICS.",58,283,23)
	b("lab_run","RUN VEHICLE TEST",Rect2(861,264,282,52),true)
	if lab != null and not lab.done:
		t("TESTING / %.1f SIMULATED SECONDS" % lab.car.elapsed,58,345,21,g.GREEN)
		return
	if lab_result.is_empty():
		t("0-60 / 0-100 / eighth / quarter / shifts / traction",58,354,21,g.MUTED)
		t("Runs an assisted test driver; your race progress is unchanged.",58,398,16,g.MUTED)
		return
	var pairs := [["0-60 MPH",lab_result.zero_60_s],["0-100 MPH",lab_result.zero_100_s],["1/8 ET",lab_result.get("eighth_et_s",lab_result.eighth_s)],["1/4 ET",lab_result.get("quarter_et_s",lab_result.quarter_s)]]
	for i in 4:
		var x := 58+i*276
		t(str(pairs[i][0]),x,362,15,g.MUTED)
		t("--" if pairs[i][1] == null else "%.3f S" % float(pairs[i][1]),x,407,30,g.GREEN)
	t("REACTION / ROLLOUT %.3f S" % float(lab_result.get("reaction_s",0)),58,442,16,g.MUTED)
	t("TRAP %.1f MPH / %d SHIFTS / %.3f S SHIFTING" % [float(lab_result.get("trap_mph",0)),int(lab_result.shift_count),float(lab_result.shift_time_s)],58,473,20)
	t("SPIN %.2f S / RPM %.0f-%.0f / TRANS %.0f C" % [lab_result.wheelspin_s,lab_result.rpm_min,lab_result.rpm_max,lab_result.transmission_c],58,518,18,g.MUTED)
	t("Tires recommended for launch slip" if float(lab_result.wheelspin_s) > 1.5 else "Launch grip is working well",58,569,18,g.GREEN)
	t("Tested: "+str(TransmissionCatalog.spec(lab_result.transmission).name),58,621,15,g.MUTED)

func update() -> void:
	if lab != null and not lab.done:
		lab.step_budget(240)
		if lab.done: lab_result = lab.result.duplicate(true)

func invalidate_test() -> void:
	var key := JSON.stringify([g.profile.vehicle_id,g.profile.stages,g.profile.hardware])
	if lab_build != "" and key != lab_build:
		lab = null; lab_result.clear(); lab_build = ""

func draw_scoped_tuning() -> void:
	box(Rect2(36,247,1130,408))
	var keys: Array = GarageHub.TUNE_KEYS.get(g.menu.hub.selected,[])
	var fitted: Array = g.profile.hardware.parts.values()
	var labels := {"launch_rpm":"Launch RPM","redline":"Rev limiter","boost":"Boost target / bar","nitrous_ramp":"Nitrous ramp / sec","firmness":"Shift firmness","stall":"Converter stall RPM","final_drive":"Final drive","ratio":"Gear ratio","shift":"Upshift RPM"}
	var enabled := {"launch_rpm":fitted.has("ecu"),"redline":fitted.has("ecu"),"boost":fitted.has("boost_control"),"nitrous_ramp":fitted.has("progressive"),"firmness":g.car.transmission_kind in ["drag","automatic","dct"],"stall":g.car.hardware.parts.has("converter"),"final_drive":fitted.has("final_kit"),"ratio":fitted.has("gearset"),"shift":fitted.has("race_controller")}
	gear_index = clampi(gear_index,0,g.car.gear_ratios.size()-1)
	if g.menu.hub.selected == 7:
		b("tune_gear_prev","< GEAR",Rect2(741,273,170,48)); b("tune_gear_next","GEAR >",Rect2(971,273,174,48))
		t("GEAR %d" % (gear_index+1),745,356,24)
	for i in keys.size():
		var key: String = keys[i]
		var values := {"launch_rpm":g.car.launch_rpm,"redline":g.car.redline_rpm,"boost":g.car.boost_target(g.car.redline_rpm,1),"nitrous_ramp":g.car._nitrous_ramp,"firmness":g.car.shift_firmness,"stall":g.car.converter_stall,"final_drive":g.car.final_drive,"ratio":g.car.gear_ratios[gear_index],"shift":g.car.shift_map[gear_index] if gear_index < g.car.shift_map.size() else 0}
		tune_row(str(labels[key]),tune_value(key,float(values[key])),key,300+i*85,tuning_enabled(key))
	t("Applies to installed hardware",744,470,16,g.MUTED)
	b("open_tuning","Saved setups / test track",Rect2(743,479,402,44))
	for i in 3: b("preset_"+["street","drag","safe"][i],["STREET","DRAG","SAFE"][i],Rect2(743+i*136,533,128,48))
	if g.menu.hub.selected == 7: b("tune_reset","RESET AUTOMATIC SHIFT MAP",Rect2(743,596,402,48))

func tune_value(key: String,value: float) -> String:
	if key=="shift" and gear_index>=g.car.gear_ratios.size()-1: return "Top gear / no upshift"
	if key in ["launch_rpm","redline","stall","shift"]: return "%.0f RPM"%value
	if key=="boost": return "%.2f bar"%value
	if key=="nitrous_ramp": return "%.2f s"%value
	return "%.3f"%value if key=="ratio" else "%.2f"%value

func action(id: String) -> bool:
	if id == "details_toggle": details = not details; return true
	if id.begins_with("stage_pick_"): preview_stage = int(id.trim_prefix("stage_pick_")); return true
	if id.begins_with("work_"):
		mode = id.trim_prefix("work_")
		if mode == "hardware": selected_hardware = str(g.profile.hardware.parts.get(current_slot(),""))
		if mode == "tune" and g.car.shift_map.is_empty(): g.car.rebuild_shift_map()
		if mode == "transmission":
			var kind: String = TransmissionCatalog.spec(selected_trans).kind
			filter_index = 0 if kind == "manual" else (3 if kind == "drag" else (2 if kind == "automatic" else 1))
			page = maxi(0,int(available_transmissions().find(selected_trans)/4))
		return true
	if id.begins_with("tx_filter_"): filter_index = int(id.trim_prefix("tx_filter_")); page = 0; selected_trans = str(available_transmissions()[0])
	elif id.begins_with("tx_pick_"): selected_trans = id.trim_prefix("tx_pick_")
	elif id == "tx_prev": page = maxi(0,page-1)
	elif id == "tx_next": page += 1
	elif id == "tx_buy": g.show_toast(g.profile.install_transmission(selected_trans)); g.refresh_car()
	elif id.begins_with("hw_slot_"): slot_index = int(id.trim_prefix("hw_slot_")); parts_page = 0; selected_hardware = str(g.profile.hardware.parts.get(current_slot(),""))
	elif id == "hw_pick_factory": selected_hardware = ""
	elif id.begins_with("hw_pick_"): selected_hardware = id.trim_prefix("hw_pick_")
	elif id == "hw_buy": g.show_toast(g.profile.install_hardware(selected_hardware) if selected_hardware != "" else g.profile.remove_hardware(current_slot())); g.refresh_car()
	elif id.begins_with("preset_"):
		var before := JSON.stringify(g.profile.hardware.tune)
		g.profile.apply_tuning_preset(id.trim_prefix("preset_"),GarageHub.TUNE_KEYS.get(g.menu.hub.selected,[])); g.refresh_car()
		g.show_toast("Tuning updated" if before != JSON.stringify(g.profile.hardware.tune) else "No tuning changes / check fitted hardware")
	elif id == "hw_prev": parts_page = maxi(0,parts_page-1)
	elif id == "hw_next": parts_page += 1
	elif id.begins_with("hw_install_"): g.show_toast(g.profile.install_hardware(id.trim_prefix("hw_install_"))); g.refresh_car()
	elif id == "hw_factory": g.show_toast(g.profile.remove_hardware(current_slot())); g.refresh_car()
	elif id.begins_with("tune_page_"): tune_page = int(id.trim_prefix("tune_page_"))
	elif id == "tune_gear_prev": gear_index = maxi(0,gear_index-1)
	elif id == "tune_gear_next": gear_index = mini(g.car.gear_ratios.size()-1,gear_index+1)
	elif id == "tune_reset": g.profile.hardware.tune.erase("shift_rpms"); g.profile.save(); g.refresh_car()
	elif id.begins_with("tune_plus_") or id.begins_with("tune_minus_"):
		var direction := 1.0 if id.begins_with("tune_plus_") else -1.0
		change_tune(id.trim_prefix("tune_plus_").trim_prefix("tune_minus_"),direction)
	elif id == "lab_run":
		if lab != null and not lab.done: return true
		lab_build = JSON.stringify([g.profile.vehicle_id,g.profile.stages,g.profile.hardware])
		lab_result.clear(); lab = VehicleBench.new(); lab.begin(GameCatalog.spec(g.profile.vehicle_id),g.profile.stages,g.profile.hardware)
	elif id == "restore_turbo": g.show_toast(g.profile.remove_hardware("induction")); g.refresh_car()
	else: return false
	return true

func change_tune(key: String, direction: float) -> void:
	var value: Variant
	var tune: Dictionary = g.profile.hardware.tune
	match key:
		"stall": value = g.car.converter_stall+direction*200.0
		"launch_rpm": value = g.car.launch_rpm+direction*200.0
		"redline": value = g.car.redline_rpm+direction*100.0
		"boost": value = g.car.boost_target(g.car.redline_rpm,1.0)+direction*0.10
		"firmness": value = g.car.shift_firmness+direction*0.1
		"nitrous_ramp": value = g.car._nitrous_ramp+direction*0.1
		"ratio": value = g.car.gear_ratios.duplicate(); value[gear_index] += direction*0.025; key = "ratios"
		"shift":
			if gear_index >= g.car.shift_map.size(): return
			value = g.car.shift_map.duplicate(); value[gear_index] += direction*100.0; key = "shift_rpms"
		"final_drive":
			var options := VehicleParts.FINAL_DRIVES
			value = g.car.final_drive
			if direction>0:
				for candidate in options:
					if float(candidate)>g.car.final_drive+.0001: value=candidate; break
			else:
				for i in range(options.size()-1,-1,-1):
					if float(options[i])<g.car.final_drive-.0001: value=options[i]; break
		_: return
	if not g.profile.tune_hardware(key,value): g.show_toast("Outside hardware limits / check gear order")
	g.refresh_car()

func stage_preview() -> Drivetrain:
	var index: int = g.selected_part
	var stage: int = g.profile.stages[index]
	if preview_stage < 0 or preview_stage > GameCatalog.max_stage(index): preview_stage = mini(GameCatalog.max_stage(index),stage+1)
	var key := JSON.stringify([g.profile.vehicle_id,g.profile.stages,g.profile.hardware,index,preview_stage])
	if key != _preview_key:
		_preview_key = key; _preview = Drivetrain.new(); _preview.configure_vehicle(GameCatalog.spec(g.profile.vehicle_id))
		var levels: Array = g.profile.stages.duplicate(); levels[index] = maxi(stage,preview_stage)
		_preview.configure(levels); _preview.configure_build(g.profile.hardware,g.profile.vehicle_id,false)
	return _preview

func part_comparison() -> Dictionary:
	var slot := current_slot()
	var candidate: Dictionary = g.profile.hardware.duplicate(true)
	var part: Dictionary = VehicleParts.PARTS.get(selected_hardware,{})
	if selected_hardware == "": candidate.parts.erase(slot)
	else:
		candidate.parts[slot] = selected_hardware
		if not candidate.owned_parts.has(selected_hardware): candidate.owned_parts.append(selected_hardware)
		if not candidate.fitments.has(selected_hardware): candidate.fitments[selected_hardware] = []
		if not candidate.fitments[selected_hardware].has(candidate.transmission): candidate.fitments[selected_hardware].append(candidate.transmission)
	var reason := ""
	for id in candidate.parts.values():
		var problem := VehicleParts.compatible(str(id),candidate,int(g.profile.stages[4]))
		if problem != "": reason = problem
	if selected_hardware=="boost_control":
		var problem:=VehicleParts.boost_control_reason(candidate,g.car.base_boost,g.car.turbo_stage)
		if problem!="": reason=problem
	var key := JSON.stringify([g.profile.vehicle_id,g.profile.stages,candidate])
	if key != _part_preview_key:
		_part_preview_key = key
		_part_preview = Drivetrain.new()
		_part_preview.configure_vehicle(GameCatalog.spec(g.profile.vehicle_id))
		_part_preview.configure(g.profile.stages)
		_part_preview.configure_build(candidate if reason == "" else g.profile.hardware,g.profile.vehicle_id,false)
	return {"part":part,"reason":reason,"car":_part_preview}

static func comparison_rows(a: Drivetrain,b: Drivetrain) -> Array[String]:
	var rows: Array[String] = []
	if a.peak_horsepower() != b.peak_horsepower(): rows.append("Power %d > %d HP" % [a.peak_horsepower(),b.peak_horsepower()])
	if absf(a.mass()-b.mass()) > .1: rows.append("Weight %.0f > %.0f kg" % [a.mass(),b.mass()])
	if absf(GarageHub.grip(a)-GarageHub.grip(b)) > .001: rows.append("Grip %.2f > %.2f" % [GarageHub.grip(a),GarageHub.grip(b)])
	if absf(a.shift_duration-b.shift_duration) > .001: rows.append("Shifts %.0f > %.0f ms" % [a.shift_duration*1000,b.shift_duration*1000])
	if absf(a.tire_radius-b.tire_radius) > .001: rows.append("Tire radius %.3f > %.3f m" % [a.tire_radius,b.tire_radius])
	if absf(a.final_drive-b.final_drive) > .001: rows.append("Final drive %.2f > %.2f" % [a.final_drive,b.final_drive])
	if absf(a.clutch_capacity()-b.clutch_capacity()) > 1: rows.append("Clutch %.0f > %.0f Nm" % [a.clutch_capacity(),b.clutch_capacity()])
	if a.brake_stage != b.brake_stage:
		var before := minf(8*(1+a.brake_stage*.18),9.81*(1.05+a.tire_stage*.06))
		var after := minf(8*(1+b.brake_stage*.18),9.81*(1.05+b.tire_stage*.06))
		rows.append("Braking force %+.0f%%" % ((after/before-1)*100))
	if absf(a._cooling-b._cooling) > .001: rows.append("Cooling capacity %+.0f%%" % ((b._cooling/a._cooling-1)*100))
	if absf(a.load_transfer_scale-b.load_transfer_scale) > .001: rows.append("Launch transfer %.2f > %.2f" % [a.load_transfer_scale,b.load_transfer_scale])
	if absf(a.supported_engine_torque()-b.supported_engine_torque()) > 1: rows.append("Torque support %.0f > %.0f Nm" % [a.supported_engine_torque(),b.supported_engine_torque()])
	if absf(a.engine_inertia-b.engine_inertia) > .001: rows.append("Rev inertia %.3f > %.3f" % [a.engine_inertia,b.engine_inertia])
	if a.launch_control != b.launch_control: rows.append("Launch RPM control enabled" if b.launch_control else "Factory launch control")
	if a.has_transbrake != b.has_transbrake: rows.append("Transbrake launch enabled" if b.has_transbrake else "Factory launch hardware")
	if absf(a._nitrous_ramp-b._nitrous_ramp) > .001: rows.append("Nitrous ramp %.2f > %.2f sec" % [a._nitrous_ramp,b._nitrous_ramp])
	if absf(a.converter_multiplication-b.converter_multiplication) > .001: rows.append("Launch multiplier %.2f > %.2f" % [a.converter_multiplication,b.converter_multiplication])
	for entry in [["boost","Boost tuning"],["gearset","Gear ratio tuning"],["final_drive","Final-drive tuning"]]:
		if a.hardware.parts.has(entry[0]) != b.hardware.parts.has(entry[0]): rows.append(entry[1]+(" unlocked" if b.hardware.parts.has(entry[0]) else " removed"))
	if rows.is_empty(): rows.append("Engine output unchanged / see details")
	return rows

func available_transmissions() -> Array:
	var ids: Array = []
	for id in TransmissionCatalog.ROWS:
		var kind: String = TransmissionCatalog.spec(id).kind
		if (filter_index == 0 and kind == "manual") or (filter_index == 1 and kind in ["paddle","sequential","dct"]) or (filter_index == 2 and kind == "automatic") or (filter_index == 3 and kind == "drag"): ids.append(id)
	return ids

func tuning_enabled(key: String) -> bool:
	if key=="boost" and VehicleParts.boost_control_reason(g.profile.hardware,g.car.base_boost,g.car.turbo_stage)!="": return false
	var fitted: Array = g.profile.hardware.parts.values()
	var enabled := {"launch_rpm":fitted.has("ecu"),"redline":fitted.has("ecu"),"boost":fitted.has("boost_control"),"nitrous_ramp":fitted.has("progressive"),"firmness":g.car.transmission_kind in ["drag","automatic","dct"],"stall":g.car.hardware.parts.has("converter"),"final_drive":fitted.has("final_kit"),"ratio":fitted.has("gearset"),"shift":fitted.has("race_controller") and gear_index < g.car.shift_map.size()}
	return bool(enabled.get(key,false))
