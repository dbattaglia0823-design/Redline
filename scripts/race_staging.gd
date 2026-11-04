class_name RaceStaging
extends RefCounted

# Distance zero is shallow-staged. Beam height and spacing are explicit game approximations.
var assisted := true
var red_light := false
var reactions: Array[float] = [-1.0,-1.0]
var released: Array[bool] = [false,false]
var rollouts: Array[float] = [.246,.246]
var distances: Array[float] = [0.0,0.0]

func reset(player: Drivetrain,opponent: Drivetrain) -> void:
	red_light = false; reactions = [-1.0,-1.0]; released = [false,false]; distances = [0.0,0.0]
	for i in 2:
		var radius: float = player.tire_radius if i == 0 else opponent.tire_radius
		rollouts[i] = 2*sqrt(maxf(0.0,2*radius*.025-.025*.025))

func beam(lane: int,prestage: bool = false) -> bool:
	var position := distances[lane]+(.18 if prestage else 0.0)
	return position >= -.000001 and position <= rollouts[lane]

func observe(lane: int,before: float,after: float,before_time: float,dt: float) -> void:
	distances[lane] = after
	if released[lane] or after <= rollouts[lane]: return
	var fraction := clampf((rollouts[lane]-before)/maxf(.00000001,after-before),0,1)
	reactions[lane] = before_time+fraction*dt
	released[lane] = true
	if lane == 0 and reactions[0] < -0.000001: red_light = true

static func lamp(countdown: float) -> int:
	# Staged hold, then three .5 s amber intervals, then green at exactly zero.
	if countdown > 1.5: return -1
	if countdown > 1.0: return 0
	if countdown > .5: return 1
	if countdown > 0: return 2
	return 3

func elapsed(total: float,lane: int = 0) -> float:
	return maxf(0,total-maxf(0,reactions[lane]))
