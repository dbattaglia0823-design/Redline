extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func configured(p: DriverProfile) -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(p.vehicle_id)); c.configure(p.stages); c.configure_build(p.hardware,p.vehicle_id,false); return c
func equivalent(a: Variant,b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b))<.000001
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	return a==b
func _initialize() -> void:
	var ids: Array=TransmissionCatalog.ROWS.keys()
	for vehicle in RosterData.IDS: ids.append("oem_"+vehicle)
	for id in ids:
		var p:=DriverProfile.new()
		p.vehicle_id=str(id).trim_prefix("oem_") if str(id).begins_with("oem_") else "miata"
		p.hardware=VehicleBench.fixture(str(id),["ecu"])
		p.stages[4]=5
		var limits:=TransmissionCatalog.count_limits(str(id))
		var original: Array=TransmissionCatalog.spec(str(id)).ratios
		check(TransmissionCatalog.valid_ratios(str(id),original,original.size()),str(id)+" authored factory gearing rejected")
		for count in range(limits.x,limits.y+1):
			check(p.tune_hardware("gear_count",count,false),str(id)+" rejected valid count")
			var c:=configured(p)
			c.rebuild_shift_map()
			check(c.shift_map.size()==count-1,str(id)+" shift plan did not resize")
			c.set_road_state(20,count); c.running=true
			for tick in 12: c.step(1.0/120,.6)
			check(is_finite(c.speed) and c.safety_clamps==0,str(id)+" tuned solver became unstable")
			check(c.gear_ratios.size()==count,str(id)+" physics ignored count")
			check(TransmissionCatalog.valid_ratios(str(id),p.hardware.tune.ratios,count),str(id)+" invalid generated ratios")
			for gear in count:
				var ratios: Array=c.gear_ratios.duplicate()
				var lo: float=TransmissionCatalog.MIN_RATIO if gear==count-1 else ratios[gear+1]+.03
				var hi: float=TransmissionCatalog.MAX_RATIO if gear==0 else ratios[gear-1]-.03
				ratios[gear]=clampf(float(ratios[gear])+.01,lo,hi)
				check(p.tune_hardware("ratios",ratios,false),str(id)+" individual ratio rejected")
				c=configured(p); check(absf(c.gear_ratios[gear]-ratios[gear])<.00001,str(id)+" ratio did not reach physics")
			var snapshot: Array=c.gear_ratios.duplicate()
			if count>limits.x:
				p.tune_hardware("gear_count",count-1,false)
				check(p.hardware.tune.ratios==snapshot.slice(0,count-1),str(id)+" reduction lost retained ratios")
				p.tune_hardware("gear_count",count,false)
		check(not p.tune_hardware("gear_count",limits.x-1,false) and not p.tune_hardware("gear_count",limits.y+1,false),str(id)+" count limits ignored")
		check(not p.tune_hardware("gear_count",4.5,false),"Fractional count accepted")
		check(p.tune_hardware("final_drive",3.67,false),"Fine final drive rejected")
		check(absf(configured(p).final_drive-3.67)<.00001,"Final drive ignored by solver")
		check(not p.tune_hardware("final_drive",INF,false) and not p.tune_hardware("ratios",[NAN],false),"Nonfinite gearing accepted")
		var saved: Dictionary=p.hardware.tune.duplicate(true)
		p.credits=10000000; p.save()
		var loaded:=DriverProfile.new(); loaded.load_profile()
		check(loaded.vehicle_id==p.vehicle_id and equivalent(loaded.hardware.tune,saved),str(id)+" save/load lost gearing")
		check(loaded.save_tune_slot("custom","Gearing"),"Preset save failed")
		loaded.tune_hardware("gear_count",limits.x,false)
		check(loaded.load_tune_slot("custom") and equivalent(loaded.hardware.tune,saved),str(id)+" preset lost count/ratios")
	var aux:=DriverProfile.new(); aux.stages=[3,3,3,3,5,3,3,3]
	aux.hardware=VehicleBench.fixture("drag3",["turbo_hybrid","boost_control"])
	check(aux.tune_hardware("shift_rpms",[6000,6200],false),"Shift map setup rejected")
	check(aux.tune_hardware("boost_by_gear",[.2,.3,.4],false),"Boost map setup rejected")
	aux.tune_hardware("gear_count",4,false)
	check(aux.hardware.tune.shift_rpms==[6000.0,6200.0,6200.0] and aux.hardware.tune.boost_by_gear==[.2,.3,.4,.4],"Added gear did not retain shift/boost settings")
	aux.tune_hardware("gear_count",2,false)
	check(aux.hardware.tune.shift_rpms.size()==1 and aux.hardware.tune.boost_by_gear.size()==2,"Removed gears left invalid dependent settings")
	var p:=DriverProfile.new(); p.hardware=VehicleBench.fixture("manual5",[]); p.stages[4]=5; p.credits=10000000
	p.tune_hardware("gear_count",6); p.tune_hardware("final_drive",3.67)
	var saved: Dictionary=p.hardware.tune.duplicate(true)
	p.install_transmission("auto10"); p.install_transmission("manual5")
	check(equivalent(p.hardware.tune,saved),"Swapping transmissions lost saved gearing")
	p.save(); var loaded:=DriverProfile.new(); loaded.load_profile()
	check(loaded.hardware.get("transmission_tunes",{}).has("manual5"),"Gearbox tuning history not persisted")
	p.pending_wager={"amount":0}
	check(not p.tune_hardware("gear_count",6,false) and not p.tune_hardware("final_drive",3.67,false),"Active race allowed tuning")
	print("UNIFIED GEARING / ALL CATALOG + OEM TRANSMISSIONS / COUNT / RATIOS / PHYSICS / SAVES: ",checks," checks; ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
