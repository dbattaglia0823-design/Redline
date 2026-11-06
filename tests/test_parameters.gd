extends SceneTree

var failures := 0
var metrics: Dictionary = {}

func check(condition: bool,message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func accelerate(spec: Dictionary, stages: Array, duration: float = 8.0) -> Drivetrain:
	var c := Drivetrain.new()
	c.configure_vehicle(spec)
	c.configure(stages)
	c.reset()
	c.running = true
	c.rpm = 3900
	for tick in roundi(duration*240.0):
		if c.rpm >= c.redline_rpm-550.0 and c.wheel_rpm(c.gear) > c.redline_rpm-1500.0: c.shift(1)
		c.step(1.0/240.0,1.0)
	return c

func top_speed(stages: Array) -> float:
	var c := accelerate(GameCatalog.spec("kaze"),stages,120.0)
	return c.speed*Drivetrain.MPH_PER_MPS

func _initialize() -> void:
	var standard := GameCatalog.spec("kaze").duplicate(true)
	var baseline := accelerate(standard,GameCatalog.blank_stages())
	var heavier := standard.duplicate(true)
	heavier.mass = 1700
	var heavy := accelerate(heavier,GameCatalog.blank_stages())
	check(heavy.speed < baseline.speed-1.0,"Vehicle mass does not affect acceleration")
	var high_drag := standard.duplicate(true)
	high_drag.drag_area = 1.3
	var draggy := accelerate(high_drag,GameCatalog.blank_stages(),25.0)
	var normal_long := accelerate(standard,GameCatalog.blank_stages(),25.0)
	check(draggy.speed < normal_long.speed-2.0,"Drag does not affect high-speed performance")
	var gearing := standard.duplicate(true)
	gearing.final_drive = 4.8
	var changed := Drivetrain.new()
	changed.configure_vehicle(gearing)
	changed.set_road_state(25,3)
	var stock := Drivetrain.new()
	stock.set_road_state(25,3)
	check(changed.rpm > stock.rpm*1.2,"Final drive does not affect engine-to-road speed")
	var radius := standard.duplicate(true)
	radius.tire_radius = 0.38
	var large_tires := Drivetrain.new()
	large_tires.configure_vehicle(radius)
	large_tires.set_road_state(25,3)
	check(large_tires.rpm < stock.rpm*0.85,"Tire radius does not affect engine-to-road speed")
	var changes: Dictionary = {}
	for category in [0,1,3,5]:
		var stages := GameCatalog.blank_stages()
		stages[category] = 3
		var upgraded := accelerate(standard,stages)
		changes[GameCatalog.PART_NAMES[category]] = upgraded.speed-baseline.speed
		check(upgraded.speed > baseline.speed+0.3,"Upgrade does not improve acceleration: "+GameCatalog.PART_NAMES[category])
	var grip := Drivetrain.new()
	grip.configure([0,0,3,0,0,0,0,0])
	var tire_stock := accelerate(standard,[3,3,0,0,3,3,0,0],1.0)
	var tire_built := accelerate(standard,[3,3,3,0,3,3,0,0],1.0)
	check(tire_built.available_traction > tire_stock.available_traction+1000.0 and tire_built.speed > tire_stock.speed+0.2,"Tire upgrade does not improve the physical launch")
	var brakes := Drivetrain.new()
	brakes.configure([0,0,0,0,0,0,3,0])
	brakes.reset()
	brakes.running = true
	brakes.set_road_state(30,3)
	stock.reset()
	stock.running = true
	stock.set_road_state(30,3)
	for tick in 240:
		brakes.step(1.0/240,0,0.8,1)
		stock.step(1.0/240,0,0.8,1)
	check(brakes.speed < stock.speed-1.0,"Brake upgrade does not improve stopping")
	var gearbox := Drivetrain.new()
	gearbox.configure([0,0,0,0,3,0,0,0])
	check(absf(gearbox.shift_duration-0.055) < 0.00001,"Gearbox upgrade did not shorten torque interruption")
	var stock_bottle := Drivetrain.new()
	check(stock_bottle.nitrous_capacity()==0.0 and stock_bottle.nitrous_torque_gain()==0.0,"Stock car has a nitrous kit")
	for tier in range(1,GameCatalog.max_stage(7)+1):
		var kit := Drivetrain.new()
		kit.configure([0,0,0,0,0,0,0,tier])
		kit.reset()
		check(is_equal_approx(kit.nitrous_remaining,4.0+1.5*tier),"Incorrect nitrous duration for tier %d"%tier)
		check(is_equal_approx(kit.nitrous_torque_gain(),(0.55+0.06*tier)*0.8),"Incorrect nitrous torque for tier %d"%tier)
	var bottle := Drivetrain.new()
	bottle.configure([0,0,0,0,0,0,0,3])
	bottle.reset()
	check(bottle.nitrous_capacity() == 8.5 and bottle.nitrous_remaining == 8.5,"Nitrous upgrade capacity was not reset correctly")
	var small_bottle := Drivetrain.new()
	for c in [bottle,small_bottle]:
		c.running = true
		c.set_road_state(40.0,4)
		c.clutch_engagement = 1.0
		c.throttle = 1.0
	for tick in 240:
		bottle.step(1.0/240.0,1.0,0.0,0.0,true)
		small_bottle.step(1.0/240.0,1.0,0.0,0.0,true)
	check(bottle.speed > small_bottle.speed+0.15,"Nitrous upgrade does not increase delivered power")
	var stock_top := top_speed(GameCatalog.blank_stages())
	var power := GameCatalog.blank_stages()
	power[0] = 3
	power[1] = 3
	power[5] = 3
	var built_top := top_speed(power)
	check(built_top > stock_top+3.0,"Power upgrades do not improve measured top speed")
	metrics = {"failures":failures,"stock_8s_mph":baseline.speed*Drivetrain.MPH_PER_MPS,"heavy_8s_mph":heavy.speed*Drivetrain.MPH_PER_MPS,"acceleration_upgrade_deltas_mps":changes,"tire_launch_gain_mps":tire_built.speed-tire_stock.speed,"nitrous_tier3_gain_mps":bottle.speed-small_bottle.speed,"stock_top_mph":stock_top,"power_upgraded_top_mph":built_top}
	var f := FileAccess.open("res://validation/parameter_test_results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(metrics,"\t"))
	print("MASS + DRAG + GEARING + ALL UPGRADES: ", "PASS" if failures == 0 else "FAIL")
	print(JSON.stringify(metrics))
	quit(0 if failures == 0 else 1)

