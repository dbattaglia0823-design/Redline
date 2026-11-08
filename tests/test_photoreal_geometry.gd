extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var ids := 0
	for id in GameCatalog.CAR_IDS:
		var d: Dictionary=VehicleAppearance.definition(id)
		if int(d.get("art_pipeline_version",0))<2: continue
		ids+=1
		var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
		var rear:=VehicleAppearance.visual_wheel_anchor(d,0)
		var front:=VehicleAppearance.visual_wheel_anchor(d,1)
		var ground:=maxf(rear.y+float(radii[0]),front.y+float(radii[1]))
		check(ground>300.0 and ground<400.0,id+": floor contact outside expected game art space")
		check(VehicleAppearance.body_drop({"stance":0}) == 0.0,id+": stock stance changed")
		check(VehicleAppearance.body_drop({"stance":1}) > 0.0,id+": lowered stance not down")
		check(VehicleAppearance.body_drop({"stance":2}) < 0.0,id+": raised stance not up")
		for paint in 6:
			for finish in ["gloss","matte","metallic"]:
				check(ResourceLoader.exists(VehicleAppearance.body_variant_path(d,paint,finish)),id+": body variant unavailable")
	check(ids==30,"Expected all 30 replacement car bodies")
	print("PHOTO VEHICLE GEOMETRY / STANCE: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	quit(0 if failures==0 else 1)
