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

static func draw_studio_reflection(g: Node2D,center: Vector2,radius: float,light: Color) -> void:
	# Broad glints stay inside the metal, leaving the tire and caliper intact.
	for band in 3:
		var ring:=radius*(.76+band*.065)
		g.draw_arc(center,ring,PI*1.12,PI*1.80,18,Color(.96,.91,.81,.06*light.get_luminance()),maxf(.6,radius*.075),true)
		g.draw_arc(center,ring,PI*.12,PI*.80,18,Color(.02,.03,.04,.10),maxf(.6,radius*.08),true)

static func draw_vehicle_wheel(g: Node2D,center: Vector2,radius: float,state: Dictionary,quality: int,look: Dictionary,definition: Dictionary,index: int,light: Color=Color.WHITE,rim_only: bool=false,tire_only: bool=false) -> void:
	var radii: Array=definition.get("wheel_radii",[definition.radius,definition.radius])
	var metal_radii: Array=definition.get("rim_radius",[float(definition.radius)*.70,float(definition.radius)*.70])
	var rim_fraction:=float(metal_radii[index])/float(radii[index])
	var metal_radius:=radius*rim_fraction
	if not rim_only:
		var authored: Texture2D
		if definition.has("stock_wheels"): authored=VehicleAppearance.texture(str(definition.stock_wheels[index]))
		if authored!=null:
			var tire:=RimArt.tire_only(authored,rim_fraction,float(radii[index]))
			VehicleRenderer.retain_texture(g,tire)
			var extent:=radius*(1.0+2.0/float(radii[index]))
			g.draw_texture_rect(tire,Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2),false,light)
		else:
			g.draw_circle(center,radius,Color("10151b")*light,true,-1,true)
			g.draw_arc(center,radius*.94,PI*1.10,PI*1.88,48,Color("3b4145")*light,maxf(1,radius*.025),true)
		# Tire-only passes must not draw the procedural brake disc: replacement
		# body PNGs already contain the stationary rotor and caliper.
		if tire_only: return
		g.draw_circle(center,metal_radius,Color("0a1016")*light,true,-1,true)
		g.draw_circle(center,metal_radius*.86,Color("34414b")*light,true,-1,true)
		for ring in (12 if quality==2 else 6):
			var r:=metal_radius*(.36+ring*.037)
			g.draw_arc(center,r,0,TAU,64,Color(.63,.68,.70,.12)*light,maxf(.4,metal_radius*.008),true)
		if quality>0:
			for hole in 16:
				var p:=center+Vector2.from_angle(hole*TAU/16+float(state.angle))*metal_radius*.72
				g.draw_circle(p,maxf(.5,metal_radius*.019),Color("17212a")*light,true,-1,true)
		# Photorealistic bodies already contain stationary brake rotors and calipers.
		# Keep the procedural caliper only for legacy SVG vehicles; otherwise it
		# duplicates the fixed hardware and appears to move with rim changes.
		if int(definition.get("art_pipeline_version",0)) < 2:
			var caliper: Color=[Color("cc5430"),Color("e53942"),Color("edc343"),Color("bac5cf")][int(look.caliper)]*light
			var shape:=PackedVector2Array()
			for point in [Vector2(.37,-.39),Vector2(.64,-.40),Vector2(.75,-.27),Vector2(.75,.26),Vector2(.61,.39),Vector2(.37,.31)]: shape.append(center+point*metal_radius)
			g.draw_colored_polygon(shape,caliper.darkened(.24))
			g.draw_line(shape[0],shape[1],caliper.lightened(.3),maxf(.8,metal_radius*.035),true)
			for y in [-.22,.22]:
				var p:=center+Vector2(.64,y)*metal_radius
				g.draw_circle(p,metal_radius*.026,Color("202930")*light,true,-1,true)
				g.draw_circle(p-Vector2.ONE*metal_radius*.008,metal_radius*.012,Color("9ba5ab")*light,true,-1,true)
	var pixels:=512 if metal_radius>80 and quality>0 else 192
	var face:=RimArt.face(int(look.design),int(look.rim),pixels)
	VehicleRenderer.retain_texture(g,face)
	g.draw_set_transform(center,float(state.spoke_angle))
	var extent:=metal_radius*256.0/233.0
	g.draw_texture_rect(face,Rect2(-Vector2.ONE*extent,Vector2.ONE*extent*2),false,Color(light,light.a*(1.0-float(state.blur)*.28)))
	g.draw_set_transform(Vector2.ZERO)
	if quality>0: draw_rim_reflection(g,center,metal_radius,state,quality,light)

