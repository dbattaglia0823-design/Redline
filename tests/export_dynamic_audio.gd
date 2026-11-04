extends SceneTree
var game: Node2D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	var recorder:=AudioEffectRecord.new(); AudioServer.add_bus_effect(0,recorder)
	DirAccess.make_dir_recursive_absolute("res://validation/audio_demo")
	for id in ["mustang","evo"]:
		for upgraded in [false,true]:
			var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(id)); car.configure([1 if upgraded else 0,0,0,0,0,3 if upgraded else 0,0,0])
			var build:=GameCatalog.factory_build(id)
			if upgraded: build.parts={"intake":"plenum","exhaust":"headers"}; build.owned_parts=["plenum","headers"]
			car.configure_build(build,id,false); car.reset(); car.running=true
			game.audio_lab.open_lab(car,true)
			var until:=Time.get_ticks_msec()+300
			while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
			recorder.set_recording_active(true)
			game.audio_lab.time=0
			until=Time.get_ticks_msec()+12000
			while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
			recorder.set_recording_active(false)
			var path: String="res://validation/audio_demo/"+id+("_upgraded" if upgraded else "_stock")+".wav"
			if recorder.get_recording().save_to_wav(path)!=OK: push_error("Could not export native audio audition"); quit(1); return
			game.audio_lab.hide_lab()
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("NATIVE STOCK/UPGRADED RPM SWEEP + LIFT CLIPS: PASS"); quit()

