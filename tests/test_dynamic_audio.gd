extends SceneTree
var game: Node2D
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); game.set_physics_process(false)
	game.profile=DriverProfile.new()
	var record:=AudioEffectRecord.new(); AudioServer.add_bus_effect(0,record)
	for id in RosterData.IDS:
		var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(id)); car.configure_build(GameCatalog.factory_build(id),id,false); car.reset()
		car.rpm=3000; car.throttle=.85; car.engine_load=.75; car.clutch_engagement=1
		game.sound.update_vehicle(car)
		check(game.sound.loops.ready_bank,"Prototype bank unavailable: "+id)
		record.set_recording_active(true)
		var until:=Time.get_ticks_msec()+900
		while Time.get_ticks_msec()<until:
			game.sound.pump(); await process_frame
		check(game.sound.loops.debug_active>0 and game.sound.loops.debug_active<=EngineLoopPlayer.MAX_PLAYERS,"Native loop voices missing or unbounded")
		check(absf(game.sound.loops.rpm-car.rpm)<1,"Native source RPM mismatch")
		var source: String=game.sound.loops.family
		for slot in game.sound.loops.slots:
			if slot.key!="": check(slot.player.pitch_scale>=.70 and slot.player.pitch_scale<=1.42,"Excessive engine pitch shift")
		car.throttle=0; car.engine_load=-.3; game.sound.update_vehicle(car)
		until=Time.get_ticks_msec()+400
		while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
		record.set_recording_active(false)
		record.get_recording().save_to_wav("res://validation/native_engine_"+id+".wav")
		check(game.sound.loops.family==source,"Throttle release substituted the engine family")
		game.sound.enabled=false; game.sound.update_vehicle(car)
		until=Time.get_ticks_msec()+220
		while Time.get_ticks_msec()<until: game.sound.pump(); await process_frame
		check(game.sound.loops.mix_gain<.001,"Mute did not fade the native loops")
		game.sound.enabled=true
	var last:=Drivetrain.new(); last.configure_vehicle(GameCatalog.spec("miata")); last.configure_build(GameCatalog.factory_build("miata"),"miata",false); last.reset()
	game.sound.update_opponent(last,0,true)
	for i in 20: game.sound.opponent.advance(1.0/60)
	check(game.sound.opponent.debug_active>0,"Nearby rival has no native engine voices")
	game.sound.update_opponent(last,250,true)
	for i in 50: game.sound.opponent.advance(1.0/60)
	check(game.sound.opponent.debug_active==0,"Distant opponent voices were not retired")
	var backup:=EngineLoopPlayer.bank.duplicate(true); EngineLoopPlayer.bank.erase("i4_na"); game.sound.loops.family=""
	game.sound.update_vehicle(last)
	check(not game.sound.loops.ready_bank,"Missing bank did not activate synthesis fallback")
	check(game.sound.loops.stream_for("res://assets/audio/missing-test.wav")==null,"Missing recording was not handled safely")
	EngineLoopPlayer.bank=backup; game.sound.loops.family=""; game.sound.update_vehicle(last)
	check(game.sound.loops.ready_bank,"Loop playback did not recover after fallback")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	game.stop_presentation_audio(); await create_timer(.12).timeout; game.queue_free(); await process_frame; await process_frame
	print("ALL 30 NATIVE ENGINE BANKS: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)


