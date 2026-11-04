class_name RaceAtmosphere
extends RefCounted

# Quiet original synthesis. No reference recordings, samples or loop restarts.
const RATE := 22050.0
var target_gain := 0.0
var gain := 0.0
var speed := 0.0
var cue := 0.0
var cue_gain := 0.0
var cue_hz := 880.0
var phase := 0.0
var crowd_phase := 0.0
var filtered := 0.0
var seed := 53117
var last_lamp := -1
var last_finish := false
var last_red := false
var cue_serial := 0
var cheer := 0.0

func set_state(staging: RaceStaging,countdown: float,active: bool,paused: bool,audible: bool,car_speed: float,finished: bool,won: bool = true) -> void:
	target_gain = 1.0 if active and not paused and audible else 0.0
	speed = car_speed
	var lamp := RaceStaging.lamp(countdown)
	if not active:
		last_lamp = -1; last_finish = false; last_red = false
		return
	if not paused:
		if staging.red_light and not last_red: trigger(220,.07)
		elif not staging.red_light and lamp != last_lamp and lamp >= 0: trigger(1320 if lamp==3 else 880,.065 if lamp==3 else .04)
		if finished and not last_finish: trigger(660 if won else 440,.09 if won else .055); cheer = 1.0 if won else .15
	last_lamp = lamp; last_finish = finished; last_red = staging.red_light

func trigger(hz: float,level: float) -> void:
	cue_hz = hz; cue = level; cue_serial += 1

func next_sample() -> float:
	gain += (target_gain-gain)*.0025
	cue *= .9987; cue_gain += (cue-cue_gain)*.035
	cheer *= .99992
	if gain < .00001 and target_gain == 0: return 0.0
	seed = (seed*1664525+1013904223)&0x7fffffff
	var noise := float(seed)/1073741824.0-1.0
	filtered += (noise-filtered)*.055
	crowd_phase = fposmod(crowd_phase+TAU*173/RATE,TAU)
	var ambience := filtered*(.026+clampf(speed/65,0,1)*.032+cheer*.05)
	ambience += sin(crowd_phase)*filtered*.018
	phase = fposmod(phase+TAU*cue_hz/RATE,TAU)
	return (ambience+sin(phase)*cue_gain)*gain
