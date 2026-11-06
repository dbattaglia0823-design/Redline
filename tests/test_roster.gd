extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(RosterData.IDS.size()==30,"Roster count")
	for pair in [[15,"E"],[14.999,"D"],[14,"D"],[13.999,"C"],[13,"C"],[12.999,"B"],[12,"B"],[11.999,"A"],[10.5,"A"],[10.499,"S"]]: check(PerformanceClasses.classify(pair[0])==pair[1],"Class boundary")
	var silhouettes: Dictionary={}; var rows: Dictionary={}
	for id in RosterData.IDS:
		var s:=GameCatalog.spec(id); var build:=GameCatalog.factory_build(id); var car:=Drivetrain.new()
		car.configure_vehicle(s); car.configure(GameCatalog.blank_stages()); car.configure_build(build,id)
		check(car.gear_ratios.size()==s.gear_ratios.size(),id+" factory ratios lost")
		check(car.gear_ratios==s.gear_ratios,id+" factory ratios mismatch")
		check(absf(car.mass()-float(s.mass))<.01,id+" curb mass mismatch")
		check(absf(car.peak_horsepower()-float(s.ice_hp))/float(s.ice_hp)<.04,id+" engine output differs from rating")
		check(VehicleAppearance.validate(id).is_empty(),id+" art manifest invalid")
		var definition:=VehicleAppearance.definition(id)
		var mask: Texture2D=load(definition.layers.paint_mask); var body: Texture2D=load(str(definition.body)%[0,"gloss"])
		var a:=mask.get_image(); var b:=body.get_image(); var opaque:=true
		for y in range(0,a.get_height(),5):
			for x in range(0,a.get_width(),5):
				if a.get_pixel(x,y).a>.99 and b.get_pixel(x,y).a<.99: opaque=false
		check(opaque,id+" transparent body interior")
		var hash:=FileAccess.get_sha256(definition.layers.paint_mask)
		check(not silhouettes.has(hash),id+" repeated silhouette"); silhouettes[hash]=true
		var factory:=PerformanceClasses.factory(id)
		check(not factory.is_empty() and float(factory.quarter_s)>0,id+" missing benchmark")
		var levels: Array=[3,3,3,3,0,3,0,0]
		var improved:=VehicleBench.run(s,levels,build)
		check(improved.quarter_s!=null and float(improved.quarter_s)<float(factory.quarter_s),id+" upgrades did not improve actual acceleration")
		check(GameCatalog.ENGINE_CLASSES.has(id) and PerformanceClasses.factory_class(id)==factory["class"],id+" factory engine tier mismatch")
		rows[id]={"engine_class":GameCatalog.engine_class(id,build),"quarter_s":improved.quarter_s}
		car.reset(); car.running=true
		for i in 480: car.step(1.0/240,1,0,0)
		if id=="sf90": check(car.hybrid_energy_j<7.9*3600000 and car.hybrid_power_w>0,"Hybrid assist not delivering energy")
		else: check(car.hybrid_power_w==0,"Non-hybrid electric assistance")
	var old: Dictionary={"credits":3210,"xp":880,"career_wins":[3,2,0],"vehicle_id":"kaze","garage":{"kaze":{"paint":3,"wheels":1,"stages":[1,2,3,1,2,0,0,0],"hardware":VehicleParts.default_build()}}}
	var migrated:=DriverProfile.migrate_roster(old)
	check(migrated.credits==3210 and migrated.xp==880 and migrated.career_wins==old.career_wins,"Migration changed progress")
	check(migrated.vehicle_id=="miata" and migrated.garage.miata.stages==old.garage.kaze.stages,"Migration lost build")
	check(DriverProfile.migrate_roster(migrated)==migrated,"Migration not idempotent")
	check(migrated.retired_garage.kaze==old.garage.kaze,"Legacy archive lost")
	var p:=DriverProfile.new(); p.credits=10000000; p.xp=100000
	for id in RosterData.IDS:
		if not p.garage.has(id): check(p.buy_vehicle(id,false),id+" purchase failed")
		check(p.select_vehicle(id),id+" equip failed")
		check(p.hardware.transmission=="oem_"+id,id+" factory hardware lost")
	p.save(); var restored:=DriverProfile.new(); restored.load_profile()
	check(restored.garage.size()==30 and restored.vehicle_id==p.vehicle_id and restored.credits==p.credits,"Save round trip lost collection")
	var f:=FileAccess.open("res://validation/roster_results.json",FileAccess.WRITE); f.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"builds":rows},"  ")); f.close()
	print("ROSTER: ",checks," checks / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
