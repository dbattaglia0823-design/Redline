extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	# Offsets are measured against source image brake-disc/hub centers at
	# 1000x360. They affect rendered wheel sprites, not drivetrain geometry.
	var calibrated := {
		"miata": [[-7,-5],[12,-4]],
		"brz": [[23,-6],[10,-7]],
		"gr86": [[23,0],[36,1]],
		"supra_gr": [[12,0],[19,-1]],
		"turbo_s": [[-9,-14],[23,-20]],
	}
	for id in calibrated:
		var d: Dictionary=VehicleAppearance.definition(id)
		check(int(d.get("art_pipeline_version",0))>=2,id+": expected replacement artwork")
		check(str(d.body).begins_with("res://Replacement Vehicle Models/"),id+": wrong source art")
		for index in 2:
			var physical:=VehicleAppearance.point(d.rear if index==0 else d.front)
			var visual:=VehicleAppearance.visual_wheel_anchor(d,index)
			var expected: Array=calibrated[id][index]
			check(visual.is_equal_approx(physical+Vector2(expected[0],expected[1])),id+": visual wheel center incorrect")
			var spec:=GameCatalog.spec(id)
			check(physical.x==float(spec.wheelbase[index]),id+": physical wheelbase changed")
			var wheel_radii: Array=d.get("wheel_radii",[d.radius,d.radius])
			var radius: float=float(wheel_radii[index])
			check(visual.x>radius and visual.x<1000.0-radius,id+": visible wheel extends past artwork")
			check(visual.y+radius>300.0 and visual.y+radius<400.0,id+": tire contact outside artwork floor")
		check(VehicleAppearance.validate(id).is_empty(),id+": manifest failed validation "+str(VehicleAppearance.validate(id)))
	for id in GameCatalog.CAR_IDS:
		var d: Dictionary=VehicleAppearance.definition(id)
		if not d.has("visual_wheel_offsets"):
			check(VehicleAppearance.visual_wheel_anchor(d,0).is_equal_approx(VehicleAppearance.point(d.rear)),id+": default rear anchor moved")
			check(VehicleAppearance.visual_wheel_anchor(d,1).is_equal_approx(VehicleAppearance.point(d.front)),id+": default front anchor moved")
	# Malformed optional metadata must never crash drawing or shift an axle.
	var malformed: Dictionary=VehicleAppearance.definition("brz").duplicate(true)
	malformed.visual_wheel_offsets=[null,[9]]
	check(VehicleAppearance.visual_wheel_anchor(malformed,0).is_equal_approx(VehicleAppearance.point(malformed.rear)),"Malformed rear offset was applied")
	check(VehicleAppearance.visual_wheel_anchor(malformed,1).is_equal_approx(VehicleAppearance.point(malformed.front)),"Malformed front offset was applied")
	malformed.visual_wheel_offsets=[[0,0],["invalid",0]]
	check(VehicleAppearance.visual_wheel_anchor(malformed,1).is_equal_approx(VehicleAppearance.point(malformed.front)),"Non-numeric wheel offset was applied")
	# Stance is strictly a sprung-body transform and never changes visual hubs.
	var d: Dictionary=VehicleAppearance.definition("brz")
	var front: Vector2=VehicleAppearance.visual_wheel_anchor(d,1)
	for stance in 3:
		check(VehicleAppearance.visual_wheel_anchor(d,1).is_equal_approx(front),"Stance changed the wheel center")
		check(is_finite(VehicleAppearance.body_drop({"stance":stance})),"Invalid body height")
	print("REPLACEMENT WHEEL ALIGNMENT: ","PASS" if failures==0 else "FAIL"," / ",checks," checks")
	quit(0 if failures==0 else 1)
