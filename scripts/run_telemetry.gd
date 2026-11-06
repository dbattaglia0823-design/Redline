class_name RunTelemetry
extends RefCounted

# Shared timing convention: green-clock total, beam reaction, and ET from rollout.
var result: Dictionary = {}
var samples: Array = []
var shifts: Array = []
var serial := 0
var next_sample := 0.0
var distance := 402.336
var frozen := false

func begin(car: Drivetrain,length: float = 402.336) -> void:
	distance=length; frozen=false; serial=car.shift_serial; next_sample=0; samples.clear(); shifts.clear()
	result={"reaction_s":null,"sixty_ft_s":null,"eighth_s":null,"eighth_mph":null,"quarter_s":null,"trap_mph":null,"zero_60_s":null,"total_s":null,"red_light":false,"distance":length}

func observe(car: Drivetrain,before_d: float,before_v: float,before_t: float,dt: float,stage: RaceStaging,lane: int = 0) -> void:
	if frozen: return
	if stage.released[lane]: result.reaction_s=stage.reactions[lane]
	result.red_light=lane==0 and stage.red_light
	var reaction: float=maxf(0,float(result.reaction_s)) if result.reaction_s!=null else 0.0
	for marker in [18.288,201.168,402.336]:
		var key: String="sixty_ft_s" if marker<20 else ("eighth_s" if marker<300 else "quarter_s")
		if result[key]==null and before_d<marker and car.distance>=marker:
			var f:=clampf((marker-before_d)/maxf(.0000001,car.distance-before_d),0,1)
			result[key]=maxf(0,before_t+dt*f-reaction)
			if marker>200: result["eighth_mph" if marker<300 else "trap_mph"]=lerpf(before_v,car.speed,f)*Drivetrain.MPH_PER_MPS
	var sixty:=60/Drivetrain.MPH_PER_MPS
	if result.zero_60_s==null and before_v<sixty and car.speed>=sixty:
		result.zero_60_s=maxf(0,before_t+dt*(sixty-before_v)/maxf(.000001,car.speed-before_v)-reaction)
	if lane==0 and car.shift_serial!=serial:
		serial=car.shift_serial
		shifts.append({"time":car.elapsed,"rpm":car.last_shift_rpm,"gear":car.gear,"duration":car.shift_duration})
	if lane==0 and car.elapsed>=next_sample:
		next_sample=car.elapsed+.05
		if samples.size()<2000: samples.append({"time":car.elapsed,"rpm":car.rpm,"speed":car.speed*Drivetrain.MPH_PER_MPS,"gear":car.gear,"throttle":car.throttle,"clutch":car.clutch_engagement,"wheelspin":car.wheelspin,"boost":car.boost,"distance":car.distance,"acceleration":car.acceleration})
	if car.distance>=distance:
		result.total_s=before_t+dt*clampf((distance-before_d)/maxf(.0000001,car.distance-before_d),0,1)
		frozen=true

func snapshot() -> Dictionary:
	return {"metrics":result.duplicate(true),"samples":samples.duplicate(true),"shifts":shifts.duplicate(true)}
