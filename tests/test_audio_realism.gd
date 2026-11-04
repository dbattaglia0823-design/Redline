extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func car_for(id: String) -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id)); c.configure_build(GameCatalog.factory_build(id),id,false); c.reset(); return c
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/engines/bank.json"))
	var hashes: Dictionary={}
	var player:=EngineLoopPlayer.new(); root.add_child(player)
	for id in RosterData.IDS:
		check(raw.vehicles.has(id),"Missing vehicle-specific acoustic bank "+id)
		var rows: Array=raw.vehicles[id].rows
		var path: String=rows[5].files.exhaust_on
		var fingerprint:=FileAccess.get_sha256(path)
		check(not hashes.has(fingerprint),"Duplicated same-pitch vehicle source "+id); hashes[fingerprint]=true
		var c:=car_for(id); var before:=c.telemetry()
		player.set_vehicle(c); check(player.voice_id==id and player.rows==rows,"Wrong source bank "+id)
		check(c.telemetry()==before,"Audio altered engine state")
		for rpm in range(int(c.idle_rpm),int(c.redline_rpm)+1,73):
			var weights:=EngineAudioProfile.weights(rpm,rows); var count:=0; var total:=0.0
			for i in weights.size():
				var weight: float=weights[i]; total+=weight
				if weight>.0001:
					count+=1; var pitch:=rpm/float(rows[i].rpm)
					check(pitch>=.79 and pitch<=1.26,"Wide pitch shift "+id)
			check(count<=2 and absf(total-1)<.00001,"Crossfade gap/extra region "+id)
		c.rpm=3000; c.throttle=1; c.engine_load=0; player.set_vehicle(c)
		for i in 30: player.advance(1.0/120)
		var unloaded: float=player.load_value
		c.engine_load=1; player.set_vehicle(c)
		for i in 30: player.advance(1.0/120)
		check(player.load_value>unloaded+.9,"Neutral and loaded state disconnected")
		for i in 120:
			c.rpm=lerpf(c.idle_rpm,c.redline_rpm,i/119.0); player.set_vehicle(c); player.advance(1.0/120)
			# Check allocation at the audio envelope's current RPM; the fixture's
			# initial 3000 -> idle jump is intentionally smoothed over 10 ms.
			var expected:=EngineAudioProfile.weights(player.rpm,player.rows)
			for region in expected.size():
				if float(expected[region])<.05: continue
				var covered:=false
				for slot in player.slots:
					if slot.key==str(player.rows[region].files.exhaust_on) and slot.desired>0: covered=true
				check(covered,"Exhaust region omitted during rapid RPM sweep "+id)
		check(player.debug_active<=EngineLoopPlayer.MAX_PLAYERS,"Unbounded source count")
		player.shutdown()
	var street:=car_for("miata"); var v:=EngineVoice.new(); v.set_from_vehicle(street)
	street.shift_serial+=1; street.last_shift_rpm=4500; street.last_shift_load=.8; v.set_from_vehicle(street)
	check(v.pop==0 and v.shift_tick>0,"Stock street shift produced unburnt-exhaust pop")
	street.exhaust_stage=3; street.shift_serial+=1; v.set_from_vehicle(street)
	check(v.pop>.1,"Performance exhaust missing loaded-shift transient")
	var converted:=car_for("brz"); converted.configure([0,1,0,0,0,0,0,0]); converted.configure_build(GameCatalog.factory_build("brz"),"brz",false)
	player.set_vehicle(converted)
	check(player.family=="h4_turbo" and player.voice_id=="brz" and player.rows==raw.vehicles.brz.rows,"Turbo conversion replaced FA-series headers with EJ unequal-header sound")
	var hybrid:=car_for("sf90"); hybrid.speed=20; v.set_from_vehicle(hybrid); var motor_hz:=v.target_motor_hz
	hybrid.rpm=6000; v.set_from_vehicle(hybrid); check(v.target_motor_hz==motor_hz,"Electric motor pitch follows ICE RPM")
	hybrid.speed=40; v.set_from_vehicle(hybrid); check(absf(v.target_motor_hz-motor_hz*2)<.01,"Electric motor pitch not connected to road speed")
	player.shutdown(); player.queue_free(); await process_frame
	var coordinator:=EngineAudio.new(); root.add_child(coordinator)
	check(coordinator.playback==null and not coordinator.playing,"Unconfigured default engine queued during startup")
	var original:=car_for("miata"); original.shift_serial=12; original.last_shift_rpm=4500; original.last_shift_load=.8
	coordinator.update_vehicle(original); original.shift_serial+=1; coordinator.update_vehicle(original)
	check(coordinator.voice.shift_tick>0,"Real source shift not recognized")
	var copy:=AudioLab.copy_car(original); coordinator.update_vehicle(copy)
	check(coordinator.voice.shift_tick==0 and coordinator.voice.pop==0,"Preview copy produced false shift event")
	coordinator.shutdown(); coordinator.update_vehicle(original)
	check(not coordinator.playing and coordinator.playback==null,"Stopped audio restarted on a late physics callback")
	coordinator.queue_free(); await process_frame
	var file:=FileAccess.open("res://validation/audio_realism_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"vehicle_banks":30,"maximum_pitch":1.26,"subjective_realism_verified":false},"  "));file.close()
	print("ENGINE IDENTITY / LOAD / PITCH / SHIFT GATING: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
