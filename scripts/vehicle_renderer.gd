class_name VehicleRenderer
extends RefCounted

static func layer(g: Node2D,path: String,pivot: Vector2,scale: float,modulate: Color = Color.WHITE) -> void:
	var tex := VehicleAppearance.texture(path)
	if tex: g.draw_texture_rect(tex,Rect2(-pivot,Vector2(1000,360)*scale),false,modulate)

static func draw(g: Node2D,origin: Vector2,size: float,model: String,look: Dictionary,car: Drivetrain,animate: bool,offset: Vector2,pitch: float,flame: bool,quality: int,night: bool = false,braking: bool = false) -> void:
	var d := VehicleAppearance.definition(model)
	if d.is_empty(): return
	var s := size*.232
	var pivot := VehicleAppearance.point(d.pivot)*s
	var radius_factor := WheelVisuals.radius_scale(car,GameCatalog.spec(model)) if car != null else 1.0
	# Larger performance tires remain on the ground; only the sprung body follows stance.
	var lift := float(d.radius)*(radius_factor-1)*s
	var base := origin-Vector2(0,lift)
	var body := base+offset+Vector2(0,VehicleAppearance.body_drop(look)*s)
	var light := Color(.72,.80,.94) if night else Color.WHITE
	# Tires are unsprung. Draw the authored wheels behind the sprung body so
	# stance, launch squat and pitch cannot drag a wheel across its fender.
	contact_shadow(g,base,d,s,radius_factor,quality)
	draw_wheels(g,base,size,s,model,d,look,car,animate,quality,light,false)
	g.draw_set_transform(body+pivot,pitch)
	layer(g,str(d.body) % [int(look.paint),["gloss","matte","metallic"][int(look.finish)]],pivot,s,light)
	if int(look.decal) > 0: layer(g,str(d.layers[["stripe","number"][int(look.decal)-1]]),pivot,s,light)
	var baked_layers := int(d.get("art_pipeline_version",0))>=2
	if not baked_layers: layer(g,d.layers.glass,pivot,s,light)
	if int(look.tint) > 0: layer(g,d.layers.tint,pivot,s,Color(1,1,1,[0.0,.32,.65][int(look.tint)]))
	if not baked_layers: layer(g,d.layers.lamps,pivot,s)
	# Lamps are part of the authored body; do not draw generic light bars over them.
	if int(look.spoiler) == 0 and not baked_layers: layer(g,d.layers.spoiler,pivot,s)
	elif int(look.spoiler) == 2 and VehicleAppearance.compatible(model,"spoiler",2):
		var p := VehicleAppearance.point(d.spoiler)*s-pivot
		g.draw_line(p+Vector2(-18,-14)*s,p+Vector2(64,-14)*s,Color("101e2a"),9*s,true)
		for x in [0,43]: g.draw_line(p+Vector2(x,-14)*s,p+Vector2(x,8)*s,Color("364858"),4*s,true)
	if flame:
		var p := VehicleAppearance.point(d.exhaust)*s-pivot
		var pulse := .85+.15*sin(car._sim_time*TAU*car.rpm/120) if car != null else 1.0
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-5)*s,p+Vector2(-110*pulse,-10)*s,p+Vector2(-65*pulse,5)*s,p+Vector2(-120*pulse,12)*s,p+Vector2(0,8)*s]),Color("ff693d"))
		g.draw_line(p,p+Vector2(-52*pulse,0)*s,Color("ffe5b5"),4*s,true)
	g.draw_set_transform(Vector2.ZERO)
	draw_wheels(g,base,size,s,model,d,look,car,animate,quality,light,true)

static func contact_shadow(g: Node2D,base: Vector2,d: Dictionary,s: float,radius_factor: float,quality: int) -> void:
	if quality == 0: return
	var rear := VehicleAppearance.point(d.rear)
	var front := VehicleAppearance.point(d.front)
	var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
	var y := maxf(rear.y+float(radii[0])*radius_factor,front.y+float(radii[1])*radius_factor)
	var center := base+Vector2((rear.x+front.x)*.5,y)*s
	for band in 3:
		var points := PackedVector2Array()
		var extent := Vector2((front.x-rear.x)*.62+float(d.radius),6.0+band*3.0)*s
		for n in 25: points.append(center+Vector2(cos(n*TAU/24.0),sin(n*TAU/24.0))*extent)
		g.draw_colored_polygon(points,Color(0.005,0.009,0.015,.08 if band>0 else .20))

static func draw_wheels(g: Node2D,base: Vector2,size: float,s: float,model: String,d: Dictionary,look: Dictionary,car: Drivetrain,animate: bool,quality: int,light: Color,reflections_only: bool) -> void:
	var spec := GameCatalog.spec(model)
	var radius_factor := WheelVisuals.radius_scale(car,spec) if car != null else 1.0
	var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
	for index in 2:
		var driven: bool = spec.drive == "AWD" or (spec.drive == "RWD" and index == 0) or (spec.drive == "FWD" and index == 1)
		var state := WheelVisuals.motion(car,driven,quality) if car != null and animate else {"omega":0.0,"angle":0.0,"spoke_angle":0.0,"blur":0.0,"sweep":0.0}
		var center:=base+VehicleAppearance.point(d.rear if index == 0 else d.front)*s
		var radius:=float(radii[index])*s*radius_factor
		if d.has("stock_wheels") and int(look.design)==0 and int(look.rim)==0 and int(look.caliper)==0 and int(look.sidewall)==0:
			if reflections_only:
				var rim_radius: float = float(d.get("rim_radius",[float(d.radius)*.70,float(d.radius)*.70])[index])*s*radius_factor
				WheelVisuals.draw_rim_reflection(g,center,rim_radius,state,quality,light)
				continue
			var texture:=VehicleAppearance.texture(str(d.stock_wheels[index]))
			if texture:
				# Texture includes a two-pixel transparent gutter. Do not shrink the
				# original tire into the cutout, and never rotate its baked lighting.
				var extent := radius+2*s*radius_factor
				g.draw_texture_rect(texture,Rect2(center-Vector2.ONE*extent,Vector2.ONE*extent*2),false,light)
		elif not reflections_only: WheelVisuals.draw_wheel(g,center,radius,size,int(look.rim),state,quality,look)



