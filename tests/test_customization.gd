extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool,msg: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(msg)
func _initialize() -> void:
	for id in GameCatalog.CAR_IDS:
		check(VehicleAppearance.validate(id).is_empty(),id+": "+str(VehicleAppearance.validate(id)))
		for key in VehicleAppearance.definition(id).compatible:
			for index in VehicleAppearance.OPTIONS[key].size(): check(VehicleAppearance.compatible(id,key,index),"Missing compatible rendered option")
	var p := DriverProfile.new(); p.credits = 100000
	p.paint = 5; p.wheels = 2; p.stages[0] = 2; p.save()
	var q := DriverProfile.new(); q.load_profile()
	check(q.appearance.paint == 5 and q.appearance.rim == 2 and q.stages[0] == 2,"Legacy paint/rim/stage migration")
	var money := q.credits
	q.install_appearance("design",2); check(q.credits == money-650,"Purchase cost")
	q.install_appearance("design",2); check(q.credits == money-650,"Duplicate installation charged twice")
	q.restore_appearance(); q.install_appearance("design",2); check(q.credits == money-650,"Restore erased ownership")
	q.install_appearance("finish",1); q.install_appearance("tint",2); q.install_appearance("stance",1)
	var look := q.appearance.duplicate(true); var parts := q.hardware.duplicate(true); var stages := q.stages.duplicate()
	q.buy_vehicle("civic_si"); check(q.appearance.design == VehicleAppearance.DEFAULT_DESIGN,"New car inherited old cosmetics")
	q.install_appearance("caliper",2); q.select_vehicle("miata")
	check(q.appearance == look and q.hardware == parts and q.stages == stages,"Switch lost per-car appearance or mechanical parts")
	q.save(); p.load_profile(); check(p.appearance == look,"Load lost appearance")
	p.select_vehicle("civic_si"); check(p.appearance.caliper == 2 and p.appearance.design == VehicleAppearance.DEFAULT_DESIGN,"Independent owned car appearance")
	p.credits = 0; var before := p.appearance.duplicate(true)
	p.install_appearance("spoiler",2); check(p.appearance == before and p.credits == 0,"Unaffordable purchase mutated state")
	p.install_appearance("missing",1); p.install_appearance("paint",-1); p.install_appearance("finish",99)
	check(p.appearance == before,"Invalid options accepted")
	p.begin_wager(0); p.install_appearance("paint",4); p.restore_appearance(); check(p.appearance == before,"Appearance changed during committed race")
	p.forfeit_wager()
	# Cosmetic changes must leave the exact drivetrain result untouched.
	var a := Drivetrain.new(); a.configure_vehicle(GameCatalog.spec("miata")); a.configure(q.stages); a.configure_build(q.hardware,"miata",false)
	var b := Drivetrain.new(); b.configure_vehicle(GameCatalog.spec("miata")); b.configure(q.stages); b.configure_build(q.hardware,"miata",false)
	for i in 1200:
		a.step(1.0/240,1); b.step(1.0/240,1)
	check(a.telemetry() == b.telemetry(),"Cosmetic save affected simulation")
	check(VehicleAppearance.normalize({"design":99,"tint":-5}).design == VehicleAppearance.OPTIONS.design.size()-1,"Malformed appearance normalization")
	var original := VehicleAppearance.definition("miata").duplicate(true)
	VehicleAppearance._manifest.miata.rear = [1200,274]
	check(not VehicleAppearance.validate("miata").is_empty(),"Invalid anchor was not detected")
	VehicleAppearance._manifest.miata = original.duplicate(true)
	VehicleAppearance._manifest.miata.layers.glass = "res://assets/missing.svg"
	check(not VehicleAppearance.validate("miata").is_empty(),"Missing layer was not detected")
	VehicleAppearance._manifest.miata = original.duplicate(true)
	VehicleAppearance._manifest.miata.compatible.append("unsupported")
	check(not VehicleAppearance.validate("miata").is_empty(),"Unsupported component was not detected")
	VehicleAppearance._manifest.miata = original.duplicate(true)
	VehicleAppearance._manifest.miata.options = {"spoiler":[0,1]}
	check(not VehicleAppearance.compatible("miata","spoiler",2),"Vehicle-specific accessory restriction ignored")
	VehicleAppearance._manifest.miata = original
	# Truly old save without the additive appearance fields.
	var file := FileAccess.open(DriverProfile.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify({"paint":4,"wheels":1,"credits":1234,"stages":[1,0,0,0,0,0,0,0]})); file.close()
	p.load_profile(); check(p.paint == 4 and p.appearance.paint == 4 and p.appearance.rim == 1 and p.credits == 1234 and p.stages[0] == 1,"Original save migration")
	print("CUSTOMIZATION / ASSETS / OWNERSHIP / MIGRATION: ","PASS" if failures == 0 else "FAIL"," / ",checks," checks")
	quit(0 if failures == 0 else 1)
