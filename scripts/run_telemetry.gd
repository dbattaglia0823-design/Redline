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
var setup: Dictionary = {}
var archived := false

func begin(car: Drivetrain,length: float = 402.336) -> void:
	distance=length; frozen=false; archived=false; serial=car.shift_serial; next_sample=0; samples.clear(); shifts.clear()
	result={"reaction_s":null,"sixty_ft_s":null,"sixty_ft_mph":null,"launch_rpm":null,"peak_acceleration":0.0,"peak_wheelspin":0.0,"peak_clutch_slip":0.0,"traction_s":0.0,"clutch_slip_s":0.0,"limiter_s":0.0,"low_rpm_s":0.0,"eighth_s":null,"eighth_mph":null,"quarter_s":null,"trap_mph":null,"zero_60_s":null,"total_s":null,"red_light":false,"distance":length}

	setup={"transmission":car.transmission_id,"ratios":car.gear_ratios.duplicate(),"final_drive":car.final_drive,"launch_rpm":car.launch_rpm,"redline":car.redline_rpm,"tire_pressure":car.hardware.tune.get("tire_pressure",32),"diff_lock":car.hardware.tune.get("diff_lock",1),"tc_slip":car.traction_slip_target,"throttle_gamma":car.throttle_gamma,"clutch_rate":car.clutch_rate,"boost":car.boost_target(car.redline_rpm,1),"launch_damping":car.hardware.tune.get("launch_damping",1)}

func observe(car: Drivetrain,before_d: float,before_v: float,before_t: float,dt: float,stage: RaceStaging,lane: int = 0,before_rpm: float = -1.0) -> void:
	if frozen: return
	if stage.released[lane]: result.reaction_s=stage.reactions[lane]
	result.red_light=lane==0 and stage.red_light
	var reaction: float=maxf(0,float(result.reaction_s)) if result.reaction_s!=null else 0.0
	var finish_fraction:=clampf((distance-before_d)/maxf(.0000001,car.distance-before_d),0,1) if car.distance>=distance else 1.0
	var ending:=before_t+dt*finish_fraction
	var active_dt:=maxf(0,ending-maxf(before_t,reaction)) if stage.released[lane] else 0.0
	if stage.released[lane] and result.launch_rpm==null:
		var fraction:=clampf((reaction-before_t)/maxf(.000001,dt),0,1)
		result.launch_rpm=lerpf(before_rpm,car.rpm,fraction) if before_rpm>=0 else car.rpm
	if active_dt>0:
		result.peak_acceleration=maxf(result.peak_acceleration,car.acceleration)
		result.peak_wheelspin=maxf(result.peak_wheelspin,car.wheelspin)
		result.peak_clutch_slip=maxf(result.peak_clutch_slip,absf(car.clutch_slip_rpm))
		if car.wheelspin>.15 and car.throttle>.5: result.traction_s+=active_dt
		if absf(car.clutch_slip_rpm)>600 and car.clutch_engagement>.8 and car.throttle>.5 and car.shift_left<=0 and not car.has_converter: result.clutch_slip_s+=active_dt
		if car.limiter and car.throttle>.8 and car.shift_left<=0: result.limiter_s+=active_dt
		if car.rpm<car.redline_rpm*.45 and car.throttle>.8 and car.gear>1 and car.speed>5: result.low_rpm_s+=active_dt
	for marker in [18.288,201.168,402.336]:
		if marker>distance+.00001: continue
		var key: String="sixty_ft_s" if marker<20 else ("eighth_s" if marker<300 else "quarter_s")
		if result[key]==null and before_d<marker and car.distance>=marker:
			var f:=clampf((marker-before_d)/maxf(.0000001,car.distance-before_d),0,1)
			result[key]=maxf(0,before_t+dt*f-reaction)
			if marker>0: result["sixty_ft_mph" if marker<20 else ("eighth_mph" if marker<300 else "trap_mph")]=lerpf(before_v,car.speed,f)*Drivetrain.MPH_PER_MPS
	var sixty:=60/Drivetrain.MPH_PER_MPS
	if result.zero_60_s==null and before_v<sixty and car.speed>=sixty:
		var fraction:=clampf((sixty-before_v)/maxf(.000001,car.speed-before_v),0,1)
		if fraction<=finish_fraction: result.zero_60_s=maxf(0,before_t+dt*fraction-reaction)
	if lane==0 and car.shift_serial!=serial:
		serial=car.shift_serial
		shifts.append({"time":car.elapsed,"rpm":car.last_shift_rpm,"gear":car.gear,"duration":car.shift_duration})
	if lane==0 and (car.elapsed>=next_sample or car.distance>=distance):
		next_sample=car.elapsed+.05
		if samples.size()<2000: samples.append({"time":ending,"rpm":lerpf(before_rpm,car.rpm,finish_fraction) if before_rpm>=0 else car.rpm,"speed":lerpf(before_v,car.speed,finish_fraction)*Drivetrain.MPH_PER_MPS,"gear":car.gear,"throttle":car.throttle,"clutch":car.clutch_engagement,"wheelspin":car.wheelspin,"boost":car.boost,"distance":minf(car.distance,distance),"acceleration":car.acceleration,"clutch_slip":car.clutch_slip_rpm})
	if car.distance>=distance:
		result.total_s=before_t+dt*clampf((distance-before_d)/maxf(.0000001,car.distance-before_d),0,1)
		frozen=true

func snapshot() -> Dictionary:
	return {"metrics":result.duplicate(true),"samples":samples.duplicate(true),"shifts":shifts.duplicate(true),"setup":setup.duplicate(true)}
