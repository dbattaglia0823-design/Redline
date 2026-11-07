extends SceneTree
var canvas: Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> Image:
	canvas.queue_redraw()
	await process_frame; await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size=Vector2i(1200,760)
	canvas=load("res://tests/rim_preview_canvas.gd").new(); root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute("res://validation/rim_motion")
	for id in RosterData.IDS:
		canvas.model=id; canvas.car.configure_vehicle(GameCatalog.spec(id)); canvas.car.configure_build(GameCatalog.factory_build(id),id,false); canvas.car.reset()
		var snapshot: Dictionary=canvas.car.telemetry()
		var still:=await frame()
		var other:=await frame()
		check(still.get_data()==other.get_data(),"Wheel art rotates while stopped: "+id)
		canvas.car.wheel_angle=1.1; canvas.car.rolling_wheel_angle=.7
		var rotated:=await frame()
		check(still.get_data()!=rotated.get_data(),"Physical axle phase did not rotate default rim: "+id)
		canvas.car.wheel_omega=100; canvas.car.speed=20; canvas.car.wheel_angle=.4; canvas.car.rolling_wheel_angle=1.1
		var moving:=await frame(); moving.save_png("res://validation/rim_motion/"+id+".png")
		var d:=VehicleAppearance.definition(id); var scale: float=canvas.SIZE*.232
		var changed:=0; var escaped:=0
		for y in range(760):
			for x in range(1200):
				if still.get_pixel(x,y)==moving.get_pixel(x,y): continue
				changed+=1; var inside:=false
				for index in 2:
					var center: Vector2=canvas.ORIGIN+VehicleAppearance.point(d.rear if index==0 else d.front)*scale
					var r: float=float(d.radius)*scale
					var dist:=Vector2(x,y).distance_to(center)
					if dist<r+3: inside=true
				if not inside: escaped+=1
		check(changed>0 and escaped==0,"Wheel rotation escaped wheel anchors: "+id+" / "+str(escaped))
		canvas.car.wheel_omega=0; canvas.car.speed=0; canvas.car.wheel_angle=0; canvas.car.rolling_wheel_angle=0
		canvas.look.design=2; canvas.look.rim=2; canvas.look.caliper=2
		var custom:=await frame()
		check(custom.get_data()!=still.get_data(),"Installed custom wheels are not visible: "+id)
		canvas.look=VehicleAppearance.normalize({})
		canvas.car.wheel_angle=0; canvas.car.rolling_wheel_angle=0
		check(canvas.car.telemetry()==snapshot,"Rendering mutated drivetrain state: "+id)
	canvas.model="miata"; canvas.car.configure_vehicle(GameCatalog.spec("miata")); canvas.car.configure_build(GameCatalog.factory_build("miata"),"miata",false); canvas.car.reset(); canvas.car.running=true
	canvas.car.grip_coefficient=.10
	for i in 240: canvas.car.step(1.0/240,1,1)
	for i in 24:
		for tick in 4: canvas.car.step(1.0/240,1,1)
		var im:=await frame(); im.save_png("res://validation/rim_motion/frame_%02d.png"%i)
	print("ROTATING WHEEL ART / ANCHORS / STATIONARY / CUSTOM WHEELS: ","PASS" if failures==0 else "FAIL")
	canvas.queue_free(); await process_frame; quit(0 if failures==0 else 1)


