extends SceneTree

const OUTPUT := "res://validation/race_controls"
const BUILDS := {"manual5":"manual","seq6":"sequential","auto10":"automatic"}
var game: Node2D
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	game.sync_menu_size()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func check(condition: bool,message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func capture(label: String) -> void:
	await frame()
	var rendered := root.get_texture().get_image()
	var image := Image.create(root.size.x,root.size.y,false,rendered.get_format())
	image.fill(Color.BLACK)
	image.blit_rect(rendered,Rect2i(Vector2i.ZERO,rendered.get_size()),(root.size-rendered.get_size())/2)
	check(image.save_png("%s/%s_%dx%d.png"%[OUTPUT,label,root.size.x,root.size.y])==OK,"Capture failed: "+label)

func prepare(hardware: String) -> void:
	game.go_garage()
	game.profile=DriverProfile.new()
	game.profile.hardware=VehicleBench.fixture(hardware)
	game.profile.stages[4]=5
	game.start_practice()
	game.countdown=0
	game.car.running=true
	game.car.set_road_state(20,2)
	for i in 100: game._physics_process(1.0/120)
	game.feedback.reset(game.car)

func target(id: String) -> Dictionary:
	for button in game.buttons:
		if button.id==id: return button
	return {}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	for dimensions in [Vector2i(1200,760),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		for hardware in BUILDS:
			prepare(hardware)
			await frame()
			var manual: bool=hardware=="manual5"
			var sequential: bool=hardware=="seq6"
			check(target("up").is_empty()!=sequential and target("down").is_empty()!=sequential,"Incorrect paddle visibility")
			check(target("manual_1").is_empty()!=manual,"Incorrect H gate visibility")
			check(not target("gas").is_empty() and not target("brake").is_empty(),"Missing pedals")
			await capture(BUILDS[hardware])

	root.size=Vector2i(390,844)
	prepare("seq6")
	await frame()
	var paddle:=InputEventKey.new()
	paddle.physical_keycode=KEY_E
	paddle.pressed=true
	game.handle_key_input(paddle)
	check(game.glass.states.up.pulse>0,"Keyboard shift did not animate the paddle")
	game.controls.hold("pedal","gas")
	await capture("pressed")
	prepare("auto10")
	var car: Drivetrain=game.car
	car.set_road_state(30,3)
	car.clutch_engagement=1
	game.controls.hold("pedal","gas")
	game.controls.hold("bottle","nitrous")
	var partial := false
	var capacity := car.nitrous_capacity()
	for i in 1800:
		game._physics_process(1.0/120)
		if not partial and car.nitrous_remaining<=capacity*.45 and car.nitrous_active:
			partial=true
			game.feedback.reset(car)
			await capture("nitrous_draining")
		if car.nitrous_remaining<=0: break
	check(partial and car.nitrous_remaining<=0,"Solver did not consume the full charge")
	game.controls.clear()
	game._physics_process(1.0/120)
	game.feedback.reset(car)
	await capture("nitrous_empty")
	check(target("nitrous").get("disabled",false),"Depleted bottle remains enabled")
	game.stop_presentation_audio()
	await create_timer(.12).timeout
	game.queue_free()
	await process_frame
	print("RACE CONTROL ART / LAYOUTS / KEYBOARD PADDLE / NITROUS DRAIN: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
