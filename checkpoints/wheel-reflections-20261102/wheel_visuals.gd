class_name WheelVisuals
extends RefCounted

# Read-only presentation of the solver's equivalent driven axle and rolling wheels.
static func motion(car: Drivetrain, driven: bool, quality: int = 2) -> Dictionary:
	var omega := car.wheel_omega if driven else car.speed/car.tire_radius
	var angle := car.wheel_angle if driven else fposmod(car.distance/car.tire_radius,TAU)
	return {"omega":omega,"angle":angle,"blur":clampf(absf(omega)/90.0,0,1),"sweep":clampf(absf(omega)/90.0,0,TAU*.85),"spoke_angle":angle if quality > 0 else 0.0}

static func radius_scale(car: Drivetrain, spec: Dictionary) -> float:
	return clampf(car.tire_radius/float(spec.get("tire_radius",.315)),.8,1.18)

static func draw_wheel(g: Node2D, center: Vector2, radius: float, scale: float, rim: int, state: Dictionary, quality: int, look: Dictionary = {}) -> void:
	var segments: int = [16,24,36][clampi(quality,0,2)]
	var color: Color = [Color("c5cdd2"),Color("b8a077"),Color("6d7b88")][clampi(rim,0,2)]
	g.draw_circle(center,radius,Color("091019"))
	if int(look.get("sidewall",0)) == 1: g.draw_arc(center,radius*.88,0,TAU,segments,Color("c9ccc6"),1.4*scale,true)
	elif int(look.get("sidewall",0)) == 2:
		for n in 8:
			var a: float = float(state.angle)+n*TAU/8
			g.draw_arc(center,radius*.87,a,a+.12,4,Color("d9dace",1-float(state.blur)*.75),1.7*scale,true)
	g.draw_arc(center,radius-scale,PI*1.1,TAU*.97,segments,Color("46505a"),scale,true)
	g.draw_circle(center,radius*.76,Color("1d2731"))
	g.draw_circle(center,radius*.62,Color("71818a"))
	if quality > 0:
		for i in (12 if quality == 2 else 6):
			var a: float = i*TAU/(12 if quality == 2 else 6)+float(state.angle)
			g.draw_circle(center+Vector2(cos(a),sin(a))*radius*.49,.7*scale,Color("263640"))
	# Fixed brake caliper and lighting; rotating spokes are a separate layer.
	var caliper: Color = [Color("cc5430"),Color("e53942"),Color("edc343"),Color("bac5cf")][int(look.get("caliper",0))]
	g.draw_rect(Rect2(center+Vector2(.29,-.32)*radius,Vector2(.23,.55)*radius),caliper)
	g.draw_arc(center,radius*.75,0,TAU,segments,color,1.7*scale,true)
	var spoke_color := Color(color,1.0-float(state.blur)*.78)
	var design := int(look.get("design",0))
	var spoke_count: int = [5,6,12][design]
	for spoke in spoke_count:
		var a: float = spoke*TAU/spoke_count+float(state.spoke_angle)
		for offset in ([-.07,.07] if design == 0 else ([0.0] if design == 1 else [-.12,.12])):
			var direction := Vector2(cos(a+offset),sin(a+offset))
			var inner := Vector2(cos(a),sin(a))*radius*.18
			g.draw_line(center+inner,center+direction*radius*.67,spoke_color,(2.4 if design == 1 else 1.35)*scale,true)
	if float(state.blur) > .01:
		# Bounded arcs approximate a shutter exposure without textures or a blur pass.
		g.draw_arc(center,radius*.58,0,TAU,segments,Color(color,float(state.blur)*.20),radius*.20,true)
		for i in (2 if quality > 0 else 1):
			var a: float = float(state.angle)+i*PI
			g.draw_arc(center,radius*.72,a,a+.22+float(state.sweep),segments,Color(.86,.95,1,float(state.blur)*.52),1.3*scale,true)
	if quality == 2:
		g.draw_arc(center,radius*.78,PI*1.14,PI*1.72,12,Color(1,1,1,.19),.7*scale,true)
	g.draw_circle(center,radius*.16,Color("263340"))
	g.draw_circle(center,radius*.08,Color("dbe3e8"))
