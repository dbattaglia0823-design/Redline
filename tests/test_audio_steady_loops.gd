extends SceneTree
var failures:=0
var game: Node2D
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	game.set_process(false); game.set_physics_process(false)
	game.sound.layers.environment=false
	var recorder:=AudioEffectRecord.new(); AudioServer.add_bus_effect(0,recorder)
	DirAccess.make_dir_recursive_absolute("res://validation/audio_steady")
	for id in ["s2000","sti","supra","m3","mustang","redeye","gtr","r8","turbo_s","chiron"]:
		var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id)); c.configure_build(GameCatalog.factory_build(id),id,false); c.reset()
		# Controlled acoustic fixture, not a simulated performance benchmark.
		c.rpm=3000; c.throttle=.85; c.engine_load=.75; c.clutch_engagement=1
		c.boost=c.boost_target(c.rpm,c.throttle); c.engine_torque=c.full_engine_torque(c.rpm)*.75
		game.sound.update_vehicle(c)
		var until:=Time.get_ticks_msec()+350
		while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
		recorder.set_recording_active(true)
		until=Time.get_ticks_msec()+3200
		while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
		recorder.set_recording_active(false)
		if recorder.get_recording().save_to_wav("res://validation/audio_steady/"+id+".wav")!=OK: failures+=1; push_error("Could not record steady engine")
		if absf(game.sound.loops.rpm-c.rpm)>1: failures+=1; push_error("Steady engine RPM mismatch")
	for i in range(AudioServer.get_bus_effect_count(0)-1,-1,-1):
		if AudioServer.get_bus_effect(0,i)==recorder: AudioServer.remove_bus_effect(0,i)
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("TEN ENGINE IDENTITIES / REPEATED NATIVE LOOP BOUNDARIES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
