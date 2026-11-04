extends SceneTree
var game: Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func frame() -> void:
	game.sync_menu_size(); game.queue_redraw(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new(); game.refresh_car(); game.tab="performance"; game.menu.hub.open_upgrade(2)
	var shortcut:=InputEventKey.new(); shortcut.physical_keycode=KEY_F7; shortcut.pressed=true; game._input(shortcut)
	check(game.audio_lab.visible,"F7 did not open the development audio lab")
	game.audio_lab.hide_lab()
	var before:=JSON.stringify([game.profile.credits,game.profile.stages,game.profile.hardware,game.car.telemetry()])
	game.workshop.preview_stage=3
	for phone in [false,true]:
		root.size=Vector2i(390,844) if phone else Vector2i(1200,760); await frame()
		check(game.buttons.any(func(b):return b.id=="sound_preview"),"No optional sound-preview control")
		game.action("sound_preview"); await frame()
		check(game.audio_lab.visible and game.sound.preview_active,"Preview did not open")
		check(game.audio_lab.preview!=game.car and game.audio_lab.preview.exhaust_stage==3,"Preview uses installed car rather than candidate copy")
		game.audio_lab.build_picker.selected=1; game.audio_lab.rebuild(); await frame()
		check(game.audio_lab.preview.exhaust_stage==0,"Installed/preview comparison not isolated")
		var e:=InputEventMouseButton.new(); e.pressed=true; e.button_index=MOUSE_BUTTON_LEFT
		for b in game.buttons:
			if str(b.id).begins_with("install_"): e.position=game.to_global(b.rect.get_center())
		game._input(e)
		check(JSON.stringify([game.profile.credits,game.profile.stages,game.profile.hardware,game.car.telemetry()])==before,"Sound preview mutated live build or spent money")
		game.get_viewport().get_texture().get_image().save_png("res://validation/audio_preview_"+("phone" if phone else "desktop")+".png")
		game.audio_lab.hide_lab(); check(not game.sound.preview_active,"Close left preview playing")
	game.audio_lab.open_lab(); await frame(); check(game.audio_lab.advanced.visible,"Development controls missing")
	for size in [Vector2i(1200,760),Vector2i(390,844)]:
		game.get_window().size=size; await frame()
		check(game.audio_lab.panel.size.x<=game.get_viewport().get_visible_rect().size.x,"Full audio lab expanded beyond phone width")
		root.get_texture().get_image().save_png("res://validation/audio_lab_%dx%d.png"%[size.x,size.y])
	for i in RosterData.IDS.size():
		game.audio_lab.vehicle_picker.selected=i; game.audio_lab.build_picker.selected=0; game.audio_lab.rebuild()
		check(game.audio_lab.preview._base_spec.id==RosterData.IDS[i],"Audio lab vehicle selection mismatch")
	game.audio_lab.mode_picker.selected=0; game.audio_lab.values.RPM.value=4000; game.audio_lab.values.Throttle.value=.9
	game.audio_lab._process(.016); check(game.sound.voice.target_rpm==4000,"Manual audio test RPM not connected")
	game.audio_lab.mode_picker.selected=2; game.audio_lab.rebuild()
	for i in 240: game.audio_lab._process(1.0/120)
	check(game.audio_lab.preview.elapsed>1.9 and game.profile.races==0,"Physical audio pull bypassed test simulation or changed progression")
	game.audio_lab.set_process(false)
	game.audio_lab.playing=false; game.audio_lab.utilities.get_child(0).emit_signal("pressed")
	check(game.audio_lab.playing and game.audio_lab.time==0,"Restart did not restart a paused audition")
	game.audio_lab.mode_picker.selected=2; game.audio_lab.preview.distance=403; game.audio_lab.set_playing(true)
	check(game.audio_lab.preview.distance==0,"Completed acceleration audition cannot replay")
	var runs: Array=[]
	for fps in [30,60,120]:
		game.audio_lab.mode_picker.selected=3; game.audio_lab.rebuild()
		for i in fps*4: game.audio_lab._process(1.0/fps)
		runs.append([game.audio_lab.preview.rpm,game.audio_lab.preview.elapsed])
		check(game.audio_lab.preview.speed==0,"Neutral audio lab test accelerated car")
	check(absf(runs[0][0]-runs[1][0])<.001 and absf(runs[1][0]-runs[2][0])<.001,"Audio lab physics depends on render frame rate")
	game.audio_lab.set_process(true)
	game.audio_lab.toggle_recording(); await create_timer(.25).timeout; game.audio_lab.finish_recording()
	check(FileAccess.file_exists(game.audio_lab.last_recording),"Development WAV record/save failed")
	check(game.audio_lab.recorder==null,"Recording effect leaked after save")
	game.audio_lab.flags.Nitrous.button_pressed=true; game.audio_lab.flags.Shifting.button_pressed=true
	var transmission_preview:=AudioLab.copy_car(game.car); transmission_preview.configure([0,0,0,0,3,0,0,0])
	transmission_preview.configure_build(game.car.hardware,game.profile.vehicle_id,false)
	game.audio_lab.open_lab(transmission_preview,true)
	check(not game.audio_lab.flags.Nitrous.button_pressed and not game.audio_lab.flags.Shifting.button_pressed,"Hidden developer flags leaked into upgrade audition")
	check(game.audio_lab.mode_picker.selected==2,"Transmission preview did not use real launch/shift simulation")
	game.audio_lab.hide_lab(); game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("AUDIO LAB / STOCK-PREVIEW / MODAL INPUT / PHONE / ALL VEHICLES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
