extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sound:=EngineAudio.new(); root.add_child(sound)
	sound.layers.environment=false
	var recorder:=AudioEffectRecord.new(); recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder)
	DirAccess.make_dir_recursive_absolute("res://.qa/launch-audio")
	for pair in [["gt500",""],["redeye",""],["demon",""],["mustang","roots"],["mustang","centrifugal"],["mustang",""]]:
		var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(pair[0]))
		var build:=GameCatalog.factory_build(pair[0]); build.parts.ecu="ecu_race"; build.owned_parts.append("ecu_race")
		if pair[1]!="": build.parts.induction=pair[1]; build.owned_parts.append(pair[1])
		build.tune.launch_rpm=3900; car.configure_build(build,pair[0],false); car.reset()
		for i in 960: car.step(1.0/240,1,0,1)
		sound.update_vehicle(car)
		var warm:=Time.get_ticks_msec()+180
		while Time.get_ticks_msec()<warm: sound.pump(); await process_frame
		recorder.set_recording_active(true)
		var start:=Time.get_ticks_usec()
		var simulated:=0.0
		var launch_heard:=false
		while Time.get_ticks_usec()-start<4500000:
			var elapsed: float=(Time.get_ticks_usec()-start)/1000000.0
			while simulated<elapsed:
				car.running=simulated>=2.0
				car.step(1.0/240,1,0,0 if car.running else 1)
				simulated+=1.0/240
			sound.update_vehicle(car,elapsed>=4.0)
			launch_heard=launch_heard or (elapsed<1.8 and sound.loops.debug_active>0 and sound.loops.target.launch)
			sound.pump(); await process_frame
		recorder.set_recording_active(false)
		var wav:=recorder.get_recording()
		var name: String=pair[0]+("_"+str(pair[1]) if pair[1]!="" else "")
		if not launch_heard or wav.data.size()<10000 or wav.save_to_wav("res://.qa/launch-audio/"+name+"_launch.wav")!=OK:
			failures+=1; push_error("Native launch playback failed: "+name)
		print("Recorded launch / acceleration / pause: ",name)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	sound.shutdown(); await create_timer(.12).timeout; sound.queue_free(); await process_frame
	print("NATIVE ENGINE LAUNCH PLAYBACK / SIX CONFIGURATIONS: ","PASS" if failures==0 else "FAIL")
	quit(1 if failures>0 else 0)
