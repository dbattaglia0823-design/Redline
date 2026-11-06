class_name WheelVisuals
extends RefCounted

# Read-only presentation of the solver's equivalent driven axle and rolling wheels.
static func motion(car: Drivetrain, driven: bool, quality: int = 2) -> Dictionary:
	var omega := car.wheel_omega if driven else car.speed/car.tire_radius
	var angle := car.wheel_angle if driven else car.rolling_wheel_angle
	return {"omega":omega,"angle":angle,"blur":clampf(absf(omega)/90.0,0,1),"sweep":clampf(absf(omega)/90.0,0,TAU*.85),"spoke_angle":angle}

static func radius_scale(car: Drivetrain, spec: Dictionary) -> float:
	return clampf(car.tire_radius/float(spec.get("tire_radius",.315)),.8,1.18)

# Short neutral metallic reflections, entirely inside the existing rim. The
# simulation accumulates both axle phases, including wheelspin and reverse.
# No tire outline, substitute wheel, whole-image rotation, or wall-clock timer.
static func draw_rim_reflection(g: Node2D,center: Vector2,radius: float,state: Dictionary,quality: int,light: Color) -> void:
	var motion := smoothstep(.5,12.0,absf(float(state.omega)))
	if quality == 0 or motion <= .001: return
	var angle := float(state.angle)
	var blur := clampf(absf(float(state.omega))/150.0,0.0,1.0)
	var width := maxf(.65,radius*.035)
	var intensity := motion*(.14-.04*blur)*light.get_luminance()
	# Sparse, low-opacity concentric sweeps suggest exposure blur while leaving
	# the authored spokes, hub and caliper visible. Never rotate the wheel PNG.
	if quality == 2 and blur > .15:
		for band in 2:
			g.draw_arc(center,radius*(.52+band*.18),angle*.35,angle*.35+TAU*.82,20,Color(.66,.73,.79,blur*.035),maxf(.6,radius*.055),true)
	for index in (2 if quality>1 else 1):
		var phase := angle+index*2.35
		var length := .34+blur*.66
		for feather in 3:
			var arc_color := Color(.83,.87,.90,intensity*(1.0-feather*.27)*(1.0-index*.48))
			g.draw_arc(center,radius*(.87-feather*.014),phase+feather*.045,phase+length-feather*.045,8,arc_color,width,true)

static func draw_compound_mark(g: Node2D,center: Vector2,radius: float,compound: int,state: Dictionary,light: Color) -> void:
	if radius<8: return
	var phase := float(state.angle)-PI*.72
	var ink := Color("d5c6a5") if compound==3 else Color("a8b5ba")
	ink *= light
	ink.a *= .78-float(state.blur)*.53
	g.draw_arc(center,radius*.89,phase,phase+(.55 if compound==1 else .83),10,ink,maxf(1,radius*.036),true)
	if compound>=2:
		g.draw_arc(center,radius*.89,phase+PI,phase+PI+.83,10,ink,maxf(1,radius*.036),true)

static func draw_wheel(g: Node2D, center: Vector2, radius: float, scale: float, rim: int, state: Dictionary, quality: int, look: Dictionary = {}, studio: bool = false) -> void:
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
	if studio:
		g.draw_circle(center,radius*.69,Color("101821"))
		g.draw_circle(center,radius*.60,Color("788893"))
		for band in 8:
			var ring:=radius*(.34+band*.032)
			var strength:=.12+.09*sin(band*1.8)
			g.draw_arc(center,ring,0,TAU,segments,Color(.84,.89,.92,strength),radius*.013,true)
		g.draw_arc(center,radius*.64,3.29,5.97,segments,Color("52606d"),radius*.028,true)
		g.draw_arc(center,radius*.57,0,TAU,segments,Color("b7c1c5"),radius*.018,true)
		g.draw_arc(center,radius*.53,0,TAU,segments,Color("475762"),radius*.016,true)
		g.draw_circle(center,radius*.32,Color("2c3a47"))
		g.draw_arc(center,radius*.92,3.55,5.83,segments,Color("5b6870"),radius*.017,true)
	if quality > 0:
		for i in (12 if quality == 2 else 6):
			var a: float = i*TAU/(12 if quality == 2 else 6)+float(state.angle)
			g.draw_circle(center+Vector2(cos(a),sin(a))*radius*.49,.7*scale,Color("263640"))
	# Fixed brake caliper and lighting; rotating spokes are a separate layer.
	var caliper: Color = [Color("cc5430"),Color("e53942"),Color("edc343"),Color("bac5cf")][int(look.get("caliper",0))]
	if studio:
		var shape:=PackedVector2Array()
		for point in [Vector2(.31,-.31),Vector2(.47,-.35),Vector2(.57,-.23),Vector2(.57,.22),Vector2(.46,.32),Vector2(.31,.25)]:
			shape.append(center+point*radius)
		g.draw_colored_polygon(shape,caliper.darkened(.22))
		g.draw_line(shape[0],shape[1],caliper.lightened(.5),radius*.035,true)
		for height in [-.17,.17]:
			var fastener:=center+Vector2(.50,height)*radius
			g.draw_circle(fastener,radius*.021,caliper.darkened(.52))
			g.draw_circle(fastener-Vector2(1,1)*radius*.007,radius*.009,Color("d1ccd1"))
		g.draw_line(center+Vector2(.39,-.22)*radius,center+Vector2(.39,.17)*radius,caliper,radius*.10,true)
	else: g.draw_rect(Rect2(center+Vector2(.29,-.32)*radius,Vector2(.23,.55)*radius),caliper)
	g.draw_arc(center,radius*.75,0,TAU,segments,color,1.7*scale,true)
	var spoke_color := Color(color,1.0-float(state.blur)*.78)
	var design := int(look.get("design",0))
	var spoke_count: int = [5,6,12,10,5][design]
	if studio and design==4:
		g.draw_arc(center,radius*.70,0,TAU,segments,color.darkened(.38),radius*.065,true)
		g.draw_arc(center,radius*.73,3.25,5.8,segments,color.lightened(.42),radius*.021,true)
	for spoke in spoke_count:
		var a: float = spoke*TAU/spoke_count+float(state.spoke_angle)
		for offset in ([-.07,.07] if design == 0 else ([-.12,.12] if design==2 else [0.0])):
			var direction := Vector2(cos(a+offset),sin(a+offset))
			var inner := Vector2(cos(a),sin(a))*radius*.18
			var tip:=center+direction*radius*.67
			var foot:=center+inner
			var width: float=float([1.35,2.4,1.35,1.75,3.1][design])*scale
			if studio:
				width=radius*float([.055,.10,.055,.075,.13][design])
				g.draw_line(foot+Vector2(0,1)*radius*.025,tip+Vector2(0,1)*radius*.025,spoke_color.darkened(.55),width*1.2,true)
			g.draw_line(foot,tip,spoke_color,width,true)
			if studio:
				var glint:=Vector2(-.008,-.014)*radius
				g.draw_line(foot+glint,tip+glint,spoke_color.lightened(.40),width*.18,true)
				g.draw_line(foot.lerp(tip,.64),tip,Color(.95,.97,1,.30),width*.13,true)
	g.draw_circle(center,radius*.16,Color("263340"))
	g.draw_circle(center,radius*.08,Color("dbe3e8"))
	if studio:
		g.draw_arc(center,radius*.76,3.22,5.62,segments,color.lightened(.52),radius*.028,true)
		g.draw_arc(center,radius*.75,.27,2.64,segments,color.darkened(.38),radius*.026,true)
		for i in 5:
			var lug:=center+Vector2.from_angle(i*TAU/5)*radius*.125
			g.draw_circle(lug,radius*.027,Color("111b24"))
			g.draw_circle(lug-Vector2(0,1)*radius*.01,radius*.015,color.lightened(.3))

