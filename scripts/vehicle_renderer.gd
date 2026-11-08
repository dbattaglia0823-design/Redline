class_name VehicleRenderer
extends RefCounted

static func retain_texture(canvas: Node2D,texture: Texture2D) -> void:
	# CanvasItem retains RIDs, not Texture2D resources. Static thumbnails can keep
	# drawing long after the shared LRU evicts their artwork. Own every texture
	# used by this canvas until its next redraw (or until the canvas is freed).
	# Accumulate across cars/reflections drawn on the same canvas in one frame.
	var frame := Engine.get_process_frames()
	if int(canvas.get_meta("vehicle_texture_frame",-1))!=frame:
		canvas.set_meta("vehicle_texture_frame",frame)
		canvas.set_meta("vehicle_draw_textures",{})
	var retained: Dictionary=canvas.get_meta("vehicle_draw_textures")
	retained[texture.get_instance_id()]=texture

static func layer(g: Node2D,path: String,pivot: Vector2,scale: float,modulate: Color = Color.WHITE) -> void:
	var tex := VehicleAppearance.texture(path)
	if tex:
		retain_texture(g,tex)
		g.draw_texture_rect(tex,Rect2(-pivot,Vector2(1000,360)*scale),false,modulate)

static func draw(g: Node2D,origin: Vector2,size: float,model: String,look: Dictionary,car: Drivetrain,animate: bool,offset: Vector2,pitch: float,flame: bool,quality: int,night: bool = false,braking: bool = false,effects: RaceFeedback = null,reveal: float = 1.0,studio: bool = false,light_phase: float = 0.0) -> void:
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
	if studio:
		VehicleLighting.apply(g,model,look,quality,light_phase)
		light=Color(.80,.81,.82) if night else Color(1.0,.98,.95)
	if night and animate and car != null and quality > 0:
		# Soft variation under the facility's light banks; no realtime lights.
		var pool := .97+.055*sin(car.distance*.065)
		light *= Color(pool,pool,pool,1)
	elif animate and g.has_method("race_track_index") and g.race_track_index()==2:
		light = Color(1,.97,.91)
	light.a = reveal
	# Tires are unsprung. Draw the authored wheels behind the sprung body so
	# stance, launch squat and pitch cannot drag a wheel across its fender.
	contact_shadow(g,base,d,s,radius_factor,quality)
	draw_wheels(g,base,size,s,model,d,look,car,animate,quality,light,false,studio,false)
	g.draw_set_transform(body+pivot,pitch)
	layer(g,VehicleAppearance.body_variant_path(d,int(look.paint),["gloss","matte","metallic"][int(look.finish)]),pivot,s,light)
	var baked_layers := int(d.get("art_pipeline_version",0))>=2
	if not baked_layers: layer(g,d.layers.glass,pivot,s,light)
	if int(look.tint) > 0 and not baked_layers: layer(g,d.layers.tint,pivot,s,Color(1,1,1,VehicleAppearance.TINT_OPACITY[int(look.tint)]))
	if not baked_layers: layer(g,d.layers.lamps,pivot,s)
	# Lamps are part of the authored body; do not draw generic light bars over them.
	if int(look.spoiler) == 0 and not baked_layers: layer(g,d.layers.spoiler,pivot,s)
	elif int(look.spoiler) == 2 and VehicleAppearance.compatible(model,"spoiler",2):
		var p := VehicleAppearance.point(d.spoiler)*s-pivot
		g.draw_line(p+Vector2(-18,-14)*s,p+Vector2(64,-14)*s,Color("101e2a"),9*s,true)
		for x in [0,43]: g.draw_line(p+Vector2(x,-14)*s,p+Vector2(x,8)*s,Color("364858"),4*s,true)
	if animate and car != null:
		var tail := VehicleAppearance.point(d.exhaust)*s-pivot
		var pulse := effects.exhaust_pulse if effects != null else .2
		var boost := effects.boost_haze if effects != null else 0.0
		var spray := effects.nitrous_glow if effects != null else 0.0
		var flash := effects.exhaust_glow if effects != null else (0.4 if flame and RaceFeedback.backfire_capable(car) else 0.0)
		if quality > 0 and (car.running or car.staging_motion):
			# A faint pulsing hot plume at the authored outlet, not a flame on
			# every shift. Boost increases shimmer; nitrous subtly cools its tint.
			var spread := 4.0+clampf(car.speed*.12,0,9)+boost*10
			var length := 16.0+pulse*12.0+car.exhaust_stage*2
			TrackPresentation.glow(g,Rect2(tail+Vector2(-length,-spread*.5),Vector2(length,spread)),Color(.68-spray*.13,.73,.8+spray*.12,(.035+pulse*.045+boost*.04)))
		if flash > .08 and RaceFeedback.backfire_capable(car):
			var length := (28.0+car.exhaust_stage*7.0)*flash*s/.3828
			if quality > 0: TrackPresentation.glow(g,Rect2(tail-Vector2(length,10),Vector2(length+8,20)),Color(1,.38,.12,flash*.45))
			g.draw_colored_polygon(PackedVector2Array([tail+Vector2(0,-2),tail+Vector2(-length,-1),tail+Vector2(-length*.5,3),tail+Vector2(0,2)]),Color(1,.45,.18,flash))
			g.draw_line(tail,tail-Vector2(length*.45,0),Color(.7,.85,1,flash),1.5,true)
	g.draw_set_transform(Vector2.ZERO)
	# For new body artwork, draw the rim faces over the baked brake hardware.
	if baked_layers: draw_wheels(g,base,size,s,model,d,look,car,animate,quality,light,false,studio,true)
	draw_wheels(g,base,size,s,model,d,look,car,animate,quality,light,true,studio,false)

static func contact_shadow(g: Node2D,base: Vector2,d: Dictionary,s: float,radius_factor: float,quality: int) -> void:
	var rear := VehicleAppearance.point(d.rear)
	var front := VehicleAppearance.point(d.front)
	var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
	var y := maxf(rear.y+float(radii[0])*radius_factor,front.y+float(radii[1])*radius_factor)
	var center := base+Vector2((rear.x+front.x)*.5,y)*s
	# A soft pooled texture avoids rebuilding three 25-point shadow polygons.
	# Even Low retains tire contact so the car never appears to float.
	var extent := Vector2((front.x-rear.x)*.62+float(d.radius),15.0 if quality>0 else 9.0)*s
	TrackPresentation.glow(g,Rect2(center-extent,extent*2),Color(.005,.009,.015,.78))
	for anchor in [rear,front]:
		var index:=0 if anchor==rear else 1
		var contact := base+Vector2(anchor.x,anchor.y+float(radii[index])*radius_factor)*s
		TrackPresentation.glow(g,Rect2(contact-Vector2(20,3)*s,Vector2(40,6)*s),Color(0,0,0,.85))

static func showroom_light(g: Node2D,bounds: Rect2,quality: int) -> void:
	if quality == 0: return
	var area := bounds.size
	AutomotiveUI.glow(g,Rect2(bounds.position+area*Vector2(.04,.13),area*Vector2(.92,.88)),Color(.24,.49,.74,.22))
	AutomotiveUI.glow(g,Rect2(bounds.position+area*Vector2(.09,.60),area*Vector2(.82,.34)),Color(.36,.65,.86,.19))

static func draw_wheels(g: Node2D,base: Vector2,size: float,s: float,model: String,d: Dictionary,look: Dictionary,car: Drivetrain,animate: bool,quality: int,light: Color,reflections_only: bool,studio: bool = false,rims_only: bool = false) -> void:
	var spec := GameCatalog.spec(model)
	var radius_factor := WheelVisuals.radius_scale(car,spec) if car != null else 1.0
	var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
	for index in 2:
		var driven: bool = spec.drive == "AWD" or (spec.drive == "RWD" and index == 0) or (spec.drive == "FWD" and index == 1)
		var state := WheelVisuals.motion(car,driven,quality) if car != null and animate else {"omega":0.0,"angle":0.0,"spoke_angle":0.0,"blur":0.0,"sweep":0.0}
		var center:=base+VehicleAppearance.point(d.rear if index == 0 else d.front)*s
		var radius:=float(radii[index])*s*radius_factor
		var rim_radius: float = float(d.get("rim_radius",[float(d.radius)*.70,float(d.radius)*.70])[index])*s*radius_factor
		if not reflections_only:
			WheelVisuals.draw_vehicle_wheel(g,center,radius,state,quality,look,d,index,light,rims_only,not rims_only and int(d.get("art_pipeline_version",0))>=2)
		else:
			if studio and quality>0: WheelVisuals.draw_studio_reflection(g,center,rim_radius,light)

		if not reflections_only and not rims_only and car!=null and car.tire_sidewall_mark>0:
			WheelVisuals.draw_compound_mark(g,center,radius,car.tire_sidewall_mark,state,light)



