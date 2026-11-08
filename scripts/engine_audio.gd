class_name EngineAudio
extends AudioStreamPlayer

var playback: AudioStreamGeneratorPlayback
var voice:=EngineVoice.new()
var atmosphere:=RaceAtmosphere.new()
var enabled:=true
var underruns:=0
var ambient_underruns:=0
var loops: EngineLoopPlayer
var opponent: EngineLoopPlayer
var environment: AudioStreamPlayer
var environment_playback: AudioStreamGeneratorPlayback
var preview_car: Drivetrain
var preview_active:=false
var _last_vehicle:=""
var _last_source_id:=0
var _closed:=false
var layers: Dictionary={"exhaust":true,"intake":true,"mechanical":true,"induction":true,"tires":true,"nitrous":true,"environment":true}
const RATE:=22050.0
const BUFFER_SECONDS:=0.055

func generator() -> AudioStreamGenerator:
	var value:=AudioStreamGenerator.new(); value.mix_rate=RATE; value.buffer_length=BUFFER_SECONDS; return value
func _ready() -> void:
	EngineLoopPlayer.ensure_buses()
	loops=EngineLoopPlayer.new(); loops.role="Player"; add_child(loops)
	opponent=EngineLoopPlayer.new(); opponent.role="Rival"; add_child(opponent)
	bus="REDLINE Mechanical"; stream=generator(); volume_db=-7
	environment=AudioStreamPlayer.new(); environment.bus="REDLINE Environment"; environment.stream=generator(); environment.volume_db=-10; add_child(environment)

func start_output() -> void:
	if _closed or playback!=null or not is_inside_tree(): return
	# Prime from a configured vehicle, after synchronous scene/bank setup. Do not
	# run an empty generator or queue the default I4 during initial asset loading.
	play(); playback=get_stream_playback()
	environment.play(); environment_playback=environment.get_stream_playback()
	pump()

func update_vehicle(car: Drivetrain,paused: bool=false) -> void:
	if _closed: return
	var source:=preview_car if preview_active and preview_car!=null else car
	var id:=str(source.hardware.get("engine_id",source._base_spec.get("id",source.engine_layout)))
	if id!=_last_vehicle or source.get_instance_id()!=_last_source_id:
		voice.last_shift_serial=source.shift_serial
		voice.last_grind_serial=source.grind_serial; voice.grind_left=0.0
		voice._blowoff_armed=false; voice._overrun_armed=false
		voice.pop=0; voice.blowoff=0; voice.shift_tick=0
		# Never carry a vent tail, cooldown, or boost spool across car/engine swaps.
		voice._blowoff_pressure=0; voice._blowoff_cooldown=0
		voice._blowoff_flutter=0; voice._blowoff_phase=0
		voice._blowoff_noise_low=0; voice._blowoff_noise_high=0
		voice._turbo_air_low=0; voice._turbo_air_high=0
		voice._turbo_spool=0; voice.blowoff_gain=0
		voice.last_blowoff_reason=""
		_last_vehicle=id
		_last_source_id=source.get_instance_id()
	voice.set_from_vehicle(source,enabled and not paused)
	if loops!=null:
		loops.layers=layers; loops.set_vehicle(source,enabled and not paused)
	voice.induction_mix=1 if layers.induction else 0
	voice.engine_mix=1 if layers.exhaust else 0
	voice.tire_mix=1 if layers.tires else 0
	voice.mechanical_mix=1 if layers.mechanical else 0
	voice.exhaust_fx_mix=1 if layers.exhaust else 0
	voice.nitro_mix=1 if layers.nitrous else 0
	start_output()

func update_opponent(car: Drivetrain,distance_gap: float,active: bool,paused: bool=false,quality: int=2) -> void:
	if opponent==null or _closed: return
	opponent.quality=quality
	var distance:=absf(distance_gap)
	var attenuation:=.28/(1+pow(distance/16,2))
	# No distant loop sampling or generator work; fade out and retire native voices.
	opponent.set_vehicle(car,enabled and active and not paused and not preview_active and distance<100,attenuation)

func pump() -> void:
	if playback==null or environment_playback==null: return
	var count:=mini(mini(playback.get_frames_available(),environment_playback.get_frames_available()),2048)
	var hybrid:=loops!=null and loops.ready_bank
	for i in count:
		var sample:=voice.next_effect_sample() if hybrid else voice.next_sample()
		playback.push_frame(Vector2(sample,sample*.97))
		var ambient:=atmosphere.next_sample()*(1.0 if layers.environment and not preview_active else 0.0)
		environment_playback.push_frame(Vector2(ambient,ambient*.96))
	underruns=maxi(playback.get_skips(),environment_playback.get_skips())
	ambient_underruns=environment_playback.get_skips()

func shutdown() -> void:
	_closed=true
	preview_active=false; preview_car=null
	if loops!=null: loops.shutdown()
	if opponent!=null: opponent.shutdown()
	if environment!=null: environment.stop()
	environment_playback=null
	stop(); playback=null; stream=null
