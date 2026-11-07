extends SceneTree

var failed := false
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failed=true; push_error(message)

func make_car(id: String,induction: String="") -> Drivetrain:
	var c:=Drivetrain.new(); c.configure_vehicle(GameCatalog.spec(id))
	var build:=GameCatalog.factory_build(id)
	build.parts.ecu="ecu_race"; build.owned_parts.append("ecu_race")
	if not induction.is_empty(): build.parts.induction=induction; build.owned_parts.append(induction)
	build.tune.launch_rpm=3900
	c.configure_build(build,id,false); c.reset()
	return c

func save_wav(path: String,samples: PackedFloat32Array) -> void:
	var bytes:=PackedByteArray(); bytes.resize(samples.size()*2)
	for i in samples.size(): bytes.encode_s16(i*2,clampi(roundi(samples[i]*32767),-32767,32767))
	var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=22050; wav.data=bytes
	check(wav.save_to_wav(path)==OK,"Could not export audio example")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.qa/launch-audio")
	EngineLoopPlayer.ensure_buses()
	var loops:=EngineLoopPlayer.new(); root.add_child(loops); loops.set_process(false)
	var identities := {}
	var report := []
	for pair in [["gt500",""],["redeye",""],["demon",""],["mustang","roots"],["mustang","centrifugal"],["mustang",""]]:
		var c:=make_car(pair[0],pair[1])
		# Real physics enters launch control with the clutch held; no telemetry substitution.
		for i in 960: c.step(1.0/240,1,0,1)
		check(EngineAudioProfile.launch_active(c),"Launch fixture did not arm: "+str(pair))
		var snapshot:=c.telemetry()
		loops.set_vehicle(c)
		for i in 30: loops.advance(1.0/120)
		check(loops.ready_bank and loops.debug_active>0,"No native engine during launch control")
		# Exercise the worst sampled ignition cut, even if physics/render cadence aliases it.
		loops.target.combustion=0
		var min_exhaust:=INF
		for i in 60:
			loops.advance(1.0/120)
			var level:=0.0
			for slot in loops.slots:
				if "exhaust_on" in str(slot.key): level+=float(slot.desired)
			min_exhaust=minf(min_exhaust,level)
		check(min_exhaust>.10,"Launch ignition cuts silenced native exhaust: "+str(pair))
		check(c.telemetry()==snapshot,"Audio changed launch physics")
		var voice:=EngineVoice.new(); voice.set_from_vehicle(c)
		check(voice.target_launch,"Synthesis fallback did not detect launch control")
		voice.target_combustion=0; voice.render(6000)
		var launch_samples:=voice.render(11025)
		var energy:=0.0
		for sample in launch_samples: energy+=sample*sample; check(is_finite(sample) and absf(sample)<=1,"Invalid launch sample")
		check(sqrt(energy/launch_samples.size())>.015,"Synthesized engine became inaudible on launch cut")
		# Isolate induction at matching operating conditions to compare actual waveform identity.
		c.rpm=4500; c.throttle=1; c.boost=.9 if c._supercharger!="" else c.boost_target(4500,1); c.engine_load=.8
		voice=EngineVoice.new(); voice.set_from_vehicle(c); voice.mechanical_mix=0; voice.tire_mix=0; voice.exhaust_fx_mix=0; voice.nitro_mix=0
		for i in 6000: voice.next_effect_sample()
		var samples:=PackedFloat32Array(); samples.resize(11025)
		for i in samples.size(): samples[i]=voice.next_effect_sample()
		var name: String=pair[0]+("_"+str(pair[1]) if not str(pair[1]).is_empty() else "")
		if c._supercharger!="":
			var signature:=samples.to_byte_array().hex_encode().sha256_text()
			check(not identities.has(signature),"Two different blower profiles sound identical")
			identities[signature]=true
			check(voice._super_level>0 and voice._super_ratio>0,"Missing fitted supercharger voice")
		else:
			check(voice.target_supercharger==0 and voice._super_level==0,"Stock Mustang acquired supercharger whine")
			var peak:=0.0
			for sample in samples: peak=maxf(peak,absf(sample))
			check(peak<.000001,"Unboosted Mustang acquired induction noise")
		save_wav("res://.qa/launch-audio/"+name+"_whine.wav",samples)
		report.append({"car":name,"profile":voice.supercharger_profile,"order":voice._super_ratio,"minimum_launch_exhaust_gain":min_exhaust,"fallback_launch_rms":sqrt(energy/launch_samples.size())})
		c.running=true; c.speed=10; voice.set_from_vehicle(c); loops.set_vehicle(c)
		check(not voice.target_launch and not loops.target.launch,"Launch audio remained armed after launch")
		loops.set_vehicle(c,false)
		for i in 60: loops.advance(1.0/120)
		check(loops.mix_gain<.001,"Launch fix bypassed mute / pause")
	check(identities.size()==5,"Missing distinct supercharger profiles")
	var centrifugal:=make_car("mustang","centrifugal")
	centrifugal.throttle=1; centrifugal.boost=.8
	var bypass:=EngineVoice.new(); bypass.set_from_vehicle(centrifugal)
	centrifugal.throttle=0; bypass.set_from_vehicle(centrifugal)
	check(bypass.blowoff>0,"Centrifugal bypass air did not respond to throttle release")
	var roots:=make_car("mustang","roots"); roots.throttle=1; roots.boost=.8
	bypass.set_from_vehicle(roots); check(not bypass._blowoff_armed,"Roots blower inherited a turbo bypass trigger")
	roots.throttle=1; roots.rpm=roots.launch_rpm; roots.running=true; roots.speed=0; roots._manual_clutch=1
	check(EngineAudioProfile.launch_active(roots),"Clutch-held launch did not retain engine audio")
	roots._manual_clutch=0; roots.transbrake_active=true
	check(EngineAudioProfile.launch_active(roots),"Transbrake launch did not retain engine audio")
	var swap:=make_car("miata"); var build:=swap.hardware.duplicate(true)
	build.engine_id="gt500"; swap.configure_build(build,"miata",false)
	check(EngineAudioProfile.supercharger_character(swap).name=="GT500 TVS 2.65","Engine swap lost its blower sound")
	var file:=FileAccess.open("res://.qa/launch-audio/results.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	loops.shutdown(); loops.queue_free(); await process_frame
	print("LAUNCH ENGINE AUDIBILITY / MODEL-SPECIFIC SUPERCHARGERS: ",checks," / ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
