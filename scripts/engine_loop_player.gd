class_name EngineLoopPlayer
extends Node

const MAX_PLAYERS:=16
static var bank: Dictionary={}
static var vehicle_banks: Dictionary={}
var slots: Array=[]
var streams: Dictionary={}
var target: Dictionary={}
var profile: Dictionary={}
var family:=""
var role:="Player"
var output_gain:=1.0
var rpm:=850.0
var opening:=0.0
var load_value:=0.0
var mix_gain:=0.0
var layers: Dictionary={"exhaust":true,"intake":true,"mechanical":true}
var quality:=2
var filter: AudioEffectLowPassFilter
var last_shift:=0.0
var ready_bank:=false
var debug_active:=0
var simulated_rpm:=850.0
var cycle_phase:=0.0
var voice_id:=""
var rows: Array=[]
var equalizer: AudioEffectEQ6
var debug_skipped:=0

static func ensure_buses() -> void:
	var master_protected:=false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0,i) is AudioEffectHardLimiter: master_protected=true
	if not master_protected:
		var safety:=AudioEffectHardLimiter.new(); safety.ceiling_db=-1.0; AudioServer.add_bus_effect(0,safety)
	for name in ["REDLINE Player","REDLINE Rival","REDLINE Mechanical","REDLINE Environment"]:
		if AudioServer.get_bus_index(name)>=0: continue
		AudioServer.add_bus(); var i:=AudioServer.bus_count-1; AudioServer.set_bus_name(i,name); AudioServer.set_bus_send(i,"Master")
		var limiter:=AudioEffectHardLimiter.new(); limiter.ceiling_db=-1.5; AudioServer.add_bus_effect(i,limiter)

func _ready() -> void:
	ensure_buses()
	for i in (8 if role=="Rival" else MAX_PLAYERS):
		var p:=AudioStreamPlayer.new(); p.bus="REDLINE "+role; p.volume_db=-80; add_child(p)
		slots.append({"player":p,"key":"","gain":0.0,"desired":0.0,"pitch":1.0})
	filter=AudioEffectLowPassFilter.new(); filter.cutoff_hz=4500; filter.resonance=.45
	# One dedicated bus per source, rather than one filter/material per loop.
	AudioServer.add_bus_effect(AudioServer.get_bus_index("REDLINE "+role),filter,0)
	equalizer=AudioEffectEQ6.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("REDLINE "+role),equalizer,1)

func _exit_tree() -> void:
	var i:=AudioServer.get_bus_index("REDLINE "+role)
	if i>=0 and filter!=null:
		for effect in range(AudioServer.get_bus_effect_count(i)-1,-1,-1):
			if AudioServer.get_bus_effect(i,effect)==filter or AudioServer.get_bus_effect(i,effect)==equalizer: AudioServer.remove_bus_effect(i,effect)

func set_vehicle(car: Drivetrain, audible: bool=true, gain_value: float=1) -> void:
	var p:=EngineAudioProfile.resolve(car)
	if bank.is_empty() and FileAccess.file_exists("res://assets/audio/engines/bank.json"):
		var raw=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/engines/bank.json"))
		if raw is Dictionary: bank=raw.get("families",{}); vehicle_banks=raw.get("vehicles",{})
	var selected_id: String=str(p.id) if not OS.has_feature("mobile") and not car._base_spec.has("audio_family_override") else ""
	if family!=p.family or voice_id!=selected_id:
		family=p.family; voice_id=selected_id; streams.clear()
		ready_bank=bank.has(family)
		rows=vehicle_banks[selected_id].rows if vehicle_banks.has(selected_id) else bank.get(family,[])
		if ready_bank:
			for row in rows:
				for path in row.files.values():
					if not ResourceLoader.exists(str(path)): ready_bank=false; break
	profile=p
	target={"rpm":car.rpm,"throttle":car.throttle,"load":car.engine_load,"combustion":car.combustion_fraction,
		"shift":car.shift_left,"clutch":car.clutch_engagement,"audible":audible,"gain":gain_value,"idle":car.idle_rpm,"redline":car.redline_rpm,
		"decel":clampf(-car.engine_torque/maxf(1,car.base_torque),0,1) if car.throttle<.2 and car.clutch_engagement>.4 else 0.0}
	simulated_rpm=car.rpm

func stream_for(path: String) -> AudioStreamWAV:
	if streams.has(path): return streams[path]
	if not ResourceLoader.exists(path): return null
	var wav=load(path)
	if not wav is AudioStreamWAV: return null
	# Resource duplicates are local; imported source assets remain untouched.
	wav=wav.duplicate(); wav.loop_begin=0; wav.loop_end=roundi(wav.get_length()*wav.mix_rate); wav.loop_mode=AudioStreamWAV.LOOP_FORWARD
	streams[path]=wav
	return wav

func _process(dt: float) -> void: advance(dt)
func advance(dt: float) -> void:
	if target.is_empty(): return
	var a:=1-exp(-dt/.010)
	rpm=lerpf(rpm,float(target.rpm),a); opening=lerpf(opening,float(target.throttle),1-exp(-dt/.018)); load_value=lerpf(load_value,clampf(float(target.load),0,1),1-exp(-dt/.018))
	cycle_phase=fposmod(cycle_phase+rpm/120.0*dt,1.0)
	mix_gain=lerpf(mix_gain,(1.0 if target.audible and target.rpm>100 else 0.0)*float(target.gain)*output_gain,1-exp(-dt/.025))
	for slot in slots: slot.desired=0.0
	if ready_bank and mix_gain>.0001:
		var weights:=EngineAudioProfile.weights(rpm,rows)
		var loaded:=clampf(opening*.20+load_value*.80,0,1)
		var rpm_band:=clampf((rpm-float(target.idle))/maxf(1,float(target.redline)-float(target.idle)),0,1)
		var cut:=.04+.96*float(target.combustion)
		var exhaust: float=profile.exhaust
		filter.cutoff_hz=clampf((1550+loaded*3000+exhaust*1250+float(profile.flow)*450)*float(profile.brightness),900,8500)
		if profile.turbo: filter.cutoff_hz*=.87
		equalizer.set_band_gain_db(1,-1.5+exhaust*.6)
		equalizer.set_band_gain_db(2,-.5+exhaust*1.1)
		equalizer.set_band_gain_db(3,exhaust*1.5)
		equalizer.set_band_gain_db(4,-2.0+exhaust*2.0)
		# Allocate the important exhaust regions first; auxiliary retiring layers
		# must not consume slots needed by a quick shift's new RPM region.
		debug_skipped=0
		for layer in EngineAudioProfile.LAYERS:
			for i in rows.size():
				if weights[i]<.0001: continue
				var group: String="exhaust" if layer.begins_with("exhaust") else ("intake" if layer.begins_with("intake") else "mechanical")
				if not layers.get(group,true): continue
				if role=="Rival" and group!="exhaust": continue
				if quality==0 and (group=="mechanical" or layer=="intake_off"): continue
				var gain_value: float=sqrt(weights[i])*mix_gain
				match layer:
					"exhaust_on": gain_value*=sqrt(loaded)*(.38+exhaust*.045)*cut
					"exhaust_off": gain_value*=sqrt(1-loaded)*lerpf(.16,.32,rpm_band)*cut*(1+float(target.decel)*.25)
					"intake_on": gain_value*=opening*(.35+.65*load_value)*.28*float(profile.intake)*cut
					"intake_off": gain_value*=(1-loaded)*opening*.12*float(profile.intake)
					"mechanical": gain_value*=.22*float(profile.mechanical)*clampf(rpm/3000,.25,1)
				if layer=="intake_on" and float(profile.lift_rpm)>0:
					gain_value*=1+.24*smoothstep(float(profile.lift_rpm)-300,float(profile.lift_rpm)+300,rpm)
				if gain_value<.00005: continue
				var path: String=rows[i].files[layer]
				assign(path,gain_value,clampf(rpm/float(rows[i].rpm),.70,1.26),float(rows[i].rpm))
	debug_active=0
	for slot in slots:
		slot.gain=lerpf(float(slot.gain),float(slot.desired),1-exp(-dt/.009))
		var p: AudioStreamPlayer=slot.player
		p.volume_db=linear_to_db(maxf(.00001,float(slot.gain)))
		if slot.gain<.00006 and slot.desired==0:
			p.stop(); slot.key=""
		elif p.playing: debug_active+=1
	if streams.size()>100: streams.clear()

func assign(path: String,gain_value: float,pitch_value: float,source_rpm: float) -> void:
	var chosen: Dictionary={}
	for slot in slots:
		if slot.key==path: chosen=slot; break
	if chosen.is_empty():
		for slot in slots:
			if slot.key=="": chosen=slot; break
	if chosen.is_empty(): debug_skipped+=1; return # Only low-priority tails can exhaust the bounded pool.
	if chosen.key!=path:
		var wav:=stream_for(path)
		if wav==null: return
		chosen.key=path; chosen.gain=0.0
		var p: AudioStreamPlayer=chosen.player
		p.stream=wav; p.pitch_scale=pitch_value; p.volume_db=-80; p.play(cycle_phase*120.0/source_rpm)
	chosen.desired=gain_value
	chosen.player.pitch_scale=pitch_value

func shutdown() -> void:
	target.clear(); mix_gain=0
	for slot in slots: slot.player.stop(); slot.gain=0.0; slot.desired=0.0; slot.key=""

