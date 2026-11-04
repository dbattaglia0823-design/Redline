extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(message)
func make_car(id: String) -> Drivetrain:
	var car:=Drivetrain.new(); car.configure_vehicle(GameCatalog.spec(id)); car.configure_build(GameCatalog.factory_build(id),id,false); car.reset(); return car
func _initialize() -> void:
	var bank: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/engines/bank.json")).families
	var profiles: Array=[]
	for id in RosterData.IDS:
		var car:=make_car(id); var p:=EngineAudioProfile.resolve(car)
		check(bank.has(p.family),"No bank for "+id)
		for row in bank[p.family]:
			for path in row.files.values(): check(ResourceLoader.exists(path),"Missing audio source: "+str(path))
		for rpm in range(int(car.idle_rpm),int(car.redline_rpm)+1,25):
			var weights:=EngineAudioProfile.weights(rpm,bank[p.family]); var sum:=0.0; var active:=0
			for i in weights.size():
				sum+=weights[i]
				if weights[i]>.0001:
					active+=1; var pitch:=rpm/float(bank[p.family][i].rpm)
					check(pitch>=1/1.42-.001 and pitch<=1.42+.001,"Audible RPM region has excessive pitch ratio")
			check(absf(sum-1)<.00001 and active<=3,"Crossfade has a gap or too many source regions")
		var hardware:=car.hardware.duplicate(true); hardware.parts["intake"]="plenum"; hardware.parts["exhaust"]="headers"
		hardware.owned_parts.append("plenum"); hardware.owned_parts.append("headers")
		var modified:=make_car(id); modified.configure([0,0,0,0,0,3,0,0]); modified.configure_build(hardware,id,false)
		var q:=EngineAudioProfile.resolve(modified)
		check(q.exhaust>p.exhaust and q.intake>p.intake,"Installed intake/exhaust has no acoustic effect: "+id)
		check(q.family==p.family,"Exhaust upgrade changed engine architecture: "+id)
		var snapshot:=car.telemetry(); EngineAudioProfile.resolve(car); check(car.telemetry()==snapshot,"Audio modified physics")
		profiles.append({"id":id,"family":p.family,"brightness":p.brightness,"intake":p.intake,"mechanical":p.mechanical,"origin":p.origin})
	for item in [["miata","i4_na"],["sti","h4_turbo"],["m3","i6_na"],["z350","v6_na"],["gtr","v6_tt"],["mustang","v8_cross"],["z06","v8_flat"],["gt500","v8_super"],["r8","v10_na"],["turbo_s","h6_turbo"],["sf90","v8_flat_tt"],["chiron","w16_tt"]]:
		check(EngineAudioProfile.resolve(make_car(item[0])).family==item[1],"Wrong engine family: "+item[0])
	var manual:=make_car("miata"); var voice:=EngineVoice.new(); voice.set_from_vehicle(manual)
	check(voice.target_supercharger==0 and voice.hybrid_power==0,"Non-hybrid/NA car has unrelated effects")
	var supercar:=make_car("gt500"); voice.set_from_vehicle(supercar); check(voice.target_supercharger==1,"Factory belt-driven supercharger missing")
	var f:=FileAccess.open("res://validation/dynamic_audio_profiles.json",FileAccess.WRITE); f.store_string(JSON.stringify({"passed":failures==0,"checks":checks,"profiles":profiles},"  "))
	print("30-CAR AUDIO FAMILIES / RPM REGIONS / UPGRADE ACOUSTICS: ",checks," / ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
