extends SceneTree
func _initialize() -> void:
	var failed:=false
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec("miata")); c.reset()
	for quality in 3:
		c.wheel_angle=1.2; c.rolling_wheel_angle=2.1
		if WheelVisuals.motion(c,true,quality).spoke_angle!=1.2 or WheelVisuals.motion(c,false,quality).angle!=2.1:
			failed=true; push_error("Wheel quality preset discarded physical rotation")
	print("PHYSICAL WHEEL PHASE / ALL QUALITY PRESETS: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
