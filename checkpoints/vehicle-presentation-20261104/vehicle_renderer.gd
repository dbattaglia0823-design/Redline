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
	g.draw_set_transform(body+pivot,pitch)
	var light := Color(.72,.80,.94) if night else Color.WHITE
	layer(g,str(d.body) % [int(look.paint),["gloss","matte","metallic"][int(look.finish)]],pivot,s,light)
	if int(look.decal) > 0: layer(g,str(d.layers[["stripe","number"][int(look.decal)-1]]),pivot,s,light)
	layer(g,d.layers.glass,pivot,s,light)
	if int(look.tint) > 0: layer(g,d.layers.tint,pivot,s,Color(1,1,1,[0.0,.32,.65][int(look.tint)]))
	layer(g,d.layers.lamps,pivot,s)
	# Lamps are part of the authored body; do not draw generic light bars over them.
	if int(look.spoiler) == 0: layer(g,d.layers.spoiler,pivot,s)
	elif int(look.spoiler) == 2:
		var p := VehicleAppearance.point(d.spoiler)*s-pivot
		g.draw_line(p+Vector2(-18,-14)*s,p+Vector2(64,-14)*s,Color("101e2a"),9*s,true)
		for x in [0,43]: g.draw_line(p+Vector2(x,-14)*s,p+Vector2(x,8)*s,Color("364858"),4*s,true)
	if flame:
		var p := VehicleAppearance.point(d.exhaust)*s-pivot
		var pulse := .85+.15*sin(car._sim_time*TAU*car.rpm/120) if car != null else 1.0
		g.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-5)*s,p+Vector2(-110*pulse,-10)*s,p+Vector2(-65*pulse,5)*s,p+Vector2(-120*pulse,12)*s,p+Vector2(0,8)*s]),Color("ff693d"))
		g.draw_line(p,p+Vector2(-52*pulse,0)*s,Color("ffe5b5"),4*s,true)
	g.draw_set_transform(Vector2.ZERO)
	var spec := GameCatalog.spec(model)
	for index in 2:
		var driven: bool = spec.drive == "AWD" or (spec.drive == "RWD" and index == 0) or (spec.drive == "FWD" and index == 1)
		var state := WheelVisuals.motion(car,driven,quality) if car != null and animate else {"omega":0.0,"angle":0.0,"spoke_angle":0.0,"blur":0.0,"sweep":0.0}
		var center:=base+VehicleAppearance.point(d.rear if index == 0 else d.front)*s
		var radius:=float(d.radius)*s*radius_factor
		if d.has("stock_wheels") and int(look.design)==0 and int(look.rim)==0 and int(look.caliper)==0 and int(look.sidewall)==0:
			var texture:=VehicleAppearance.texture(str(d.stock_wheels[index]))
			if texture:
				g.draw_set_transform(center,float(state.angle))
				g.draw_texture_rect(texture,Rect2(Vector2.ONE*(-radius),Vector2.ONE*radius*2),false)
				g.draw_set_transform(Vector2.ZERO)
		else: WheelVisuals.draw_wheel(g,center,radius,size,int(look.rim),state,quality,look)



