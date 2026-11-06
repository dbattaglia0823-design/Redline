extends SceneTree

var checks:=0
var failures:=0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func benchmark(model: String,stages: Array,parts: Array,tune: Dictionary={}) -> Dictionary:
	var bench:=VehicleBench.new()
	var transmission:=str(GameCatalog.factory_build(model).transmission)
	bench.begin(GameCatalog.spec(model),stages,VehicleBench.fixture(transmission,parts,tune))
	while not bench.done: bench.step_budget(960)
	var total:=0.0
	var count:=0
	for sample in bench.samples:
		if float(sample.distance_m)>18.288: break
		total+=float(sample.wheelspin)
		count+=1
	check(bench.result.safety_clamps==0 and bench.result.quarter_s!=null,"Unstable run for "+model)
	var measured:=bench.result
	measured["launch_spin"]=total/maxi(1,count)
	return measured

func equip(p: DriverProfile,slot: String,id: String) -> String:
	var quote:=p.upgrade_quote(-1,-1,slot,id)
	return p.commit_upgrade_quote(-1,-1,slot,id,JSON.stringify(quote))

func run() -> void:
	check(not VehicleParts.SLOTS.has("cooling") and not VehicleParts.PARTS.has("radiator"),"Cooling is still offered")
	var counts: Dictionary={"tires":1,"suspension":1}
	for part in VehicleParts.PARTS.values():
		if counts.has(part.slot): counts[part.slot]+=1
	check(counts.tires==8 and counts.suspension==7,"Missing tire or suspension options")
	var stock:=GameCatalog.blank_stages()
	var civic:=benchmark("civic_si",stock,[])
	var civic_street:=benchmark("civic_si",stock,["street_tires","street_susp"])
	var civic_slick:=benchmark("civic_si",stock,["drag_slicks","pro_drag_susp"])
	check(civic_street.wheelspin_s<civic.wheelspin_s*.5,"Street tires did not reduce wheelspin on a low-power FWD car")
	check(civic_slick.quarter_s>civic_street.quarter_s,"Heavy slick setup has no low-power tradeoff")
	var stages:=[3,3,0,0,5,3,0,0]
	var demon:=benchmark("demon",stages,[])
	var demon_slick:=benchmark("demon",stages,["drag_slicks"])
	var demon_drag:=benchmark("demon",stages,["drag_slicks","pro_drag_susp"])
	check(demon_slick.sixty_ft_s<demon.sixty_ft_s-.10 and demon_slick.wheelspin_s<demon.wheelspin_s,"Slicks did not improve the high-power RWD launch")
	check(demon_drag.sixty_ft_s<demon_slick.sixty_ft_s-.02 and demon_drag.quarter_s<demon_slick.quarter_s,"Suspension did not improve a slick-equipped launch")
	var gtr:=benchmark("gtr",stages,[])
	var gtr_tuned:=benchmark("gtr",stages,["drag_slicks","pro_drag_susp","ecu"],{"tire_pressure":23,"launch_damping":1.15,"launch_rpm":3200,"tc_slip":.08})
	check(gtr_tuned.launch_spin<.10 and gtr_tuned.wheelspin_s<gtr.wheelspin_s*.2 and gtr_tuned.quarter_s<gtr.quarter_s,"Tuned AWD setup cannot launch with minimal spin")
	print("Civic wheelspin seconds ",civic.wheelspin_s," -> ",civic_street.wheelspin_s)
	print("Demon 60-foot ET ",demon.sixty_ft_s," -> ",demon_drag.sixty_ft_s)
	print("GT-R mean launch wheelspin ",gtr.launch_spin," -> ",gtr_tuned.launch_spin)

	var p:=DriverProfile.new()
	p.credits=20000
	var legacy:=VehicleBench.fixture("oem_miata",["drag_wheels","street_susp"])
	legacy.parts.cooling="race_cooling"
	legacy.owned_parts.append_array(["radiator","race_cooling"])
	p.hardware=legacy
	p.stages=[0,0,2,0,0,0,0,0]
	p.owned_stages=[0,0,3,0,0,0,0,0]
	p.save()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DriverProfile.SAVE_PATH))
	saved.erase("traction_version"); saved.erase("save_format"); saved.erase("integrity")
	var file:=FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(saved)); file.close()
	p=DriverProfile.new(); p.load_profile()
	check(p.credits==25700 and not p.hardware.parts.has("cooling"),"Cooling refund or removal failed")
	check(p.stages[2]==0 and p.owned_stages[2]==0 and p.hardware.parts.get("tires")=="street_radial","Legacy tire tier did not migrate")
	check(VehicleParts.is_owned(p.hardware,"competition_radial") and p.hardware.parts.get("wheels")=="drag_wheels","Migration lost owned grip or wheels")
	check(p.hardware.parts.get("suspension")=="street_susp","Migration lost installed suspension")
	check(equip(p,"tires","competition_radial").begins_with("Installed") and p.credits==25700,"Owned tires charged again")
	check(equip(p,"tires","").begins_with("Installed") and p.credits==25700 and p.hardware.parts.has("wheels"),"Factory tire switch changed wheels or charged")
	check(equip(p,"tires","competition_radial").begins_with("Installed") and p.credits==25700,"Reinstalling owned tires charged")
	check(equip(p,"wheels","light_wheels").begins_with("Installed") and p.credits==24100 and p.hardware.parts.get("tires")=="competition_radial","Wheel installation changed the tire")
	check(equip(p,"suspension","coilovers").begins_with("Installed"),"Coilovers cannot be bought")
	check(p.tune_hardware("launch_damping",1.2) and p.tune_hardware("tire_pressure",25),"Traction tuning rejected independent hardware")
	var balance:=p.credits
	check(equip(p,"suspension","street_susp").begins_with("Installed") and p.credits==balance,"Owned suspension charged again")
	check(equip(p,"suspension","coilovers").begins_with("Installed") and p.credits==balance,"Coilovers charged again")
	var loaded:=DriverProfile.new(); loaded.load_profile()
	check(loaded.credits==balance and loaded.hardware.parts==p.hardware.parts and loaded.hardware.tune==p.hardware.tune,"Reload lost traction setup or repeated the refund")
	print("TRACTION PARTS / LAUNCH PHYSICS / OWNERSHIP / MIGRATION: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
