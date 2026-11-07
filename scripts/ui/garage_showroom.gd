class_name GarageShowroom
extends Control

const SCENE_PATH := "res://assets/ui/private_showroom_landscape.webp"
const PORTRAIT_PATH := "res://assets/ui/private_showroom_portrait.webp"

class StageArt extends Node2D:
	var stage: GarageShowroom

	func _draw() -> void:
		var area := stage.size
		if area.x<10 or area.y<10: return
		LiquidGlass.draw_cover(self,stage.scene,Rect2(Vector2.ZERO,area))
		# Protect the overlays locally while leaving the interior sharp.
		shade_band(Rect2(0,0,area.x,area.y*.24),Color(.018,.025,.032,.82),Color.TRANSPARENT)
		shade_band(Rect2(0,area.y*.65,area.x,area.y*.35),Color.TRANSPARENT,Color(.012,.018,.025,.93))

	func shade_band(rect: Rect2,top: Color,bottom: Color) -> void:
		draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),PackedColorArray([top,top,bottom,bottom]))

class DisplayedCar extends Node2D:
	var entry: Dictionary
	var width: float
	var quality: int
	var hero: bool
	var light_phase := 0.0:
		set(value):
			light_phase=value
			queue_redraw()

	func _draw() -> void:
		var data := VehicleAppearance.definition(entry.id)
		if data.is_empty(): return
		var car: Drivetrain=entry.car
		var factor := width/1000.0
		var radius_scale := WheelVisuals.radius_scale(car,GameCatalog.spec(entry.id))
		var rear := VehicleAppearance.point(data.rear)
		var front := VehicleAppearance.point(data.front)
		var radii: Array=data.get("wheel_radii",[data.radius,data.radius])
		var ground := maxf(rear.y+float(radii[0])*radius_scale,front.y+float(radii[1])*radius_scale)
		var lift := float(data.radius)*(radius_scale-1.0)
		var origin := Vector2(-width*.5,-(ground-lift)*factor)
		VehicleRenderer.draw(self,origin,width/232.0,entry.id,entry.look,car,false,Vector2.ZERO,0,false,quality,not hero,false,null,1.0,true,light_phase)

class FloorLight extends Node2D:
	var drift := 0.0:
		set(value):
			drift=value
			queue_redraw()

	func _draw() -> void:
		var area: Vector2=get_parent().size
		var bounds:=Rect2(area*Vector2(.12+drift,.70),area*Vector2(.58,.10))
		AutomotiveUI.glow(self,bounds,Color(.93,.72,.49,.07))

var scene: Texture2D
var active: Dictionary
var parked: Array[Dictionary]=[]
var quality: int
var portrait := false
var compact := false
var displays: Array[DisplayedCar]=[]
var reflections: Array[DisplayedCar]=[]

func setup(game: Node2D,minimum_height: float) -> void:
	portrait=game.is_portrait()
	compact=not portrait and game.get_window().size.y<500
	scene=load(PORTRAIT_PATH if portrait else SCENE_PATH)
	quality=game.profile.effects_quality
	active={"id":game.profile.vehicle_id,"car":game.car,"look":game.profile.appearance_for(game.profile.vehicle_id)}
	for id in game.profile.garage:
		if id==active.id: continue
		parked.append({"id":id,"car":game.menu.hub.vehicle(id),"look":game.profile.appearance_for(id)})
		if parked.size()==2: break
	custom_minimum_size.y=minimum_height
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var art:=StageArt.new()
	art.stage=self
	add_child(art)
	var cars: Array[Dictionary]=parked.duplicate()
	cars.append(active)
	for index in cars.size():
		if quality>0:
			var reflection:=DisplayedCar.new()
			reflection.entry=cars[index]
			reflection.hero=index==cars.size()-1
			reflection.quality=0
			reflection.scale=Vector2(1,-.26)
			reflection.modulate=Color(.78,.81,.85,.14 if reflection.hero else .07)
			add_child(reflection)
			reflections.append(reflection)
		var display:=DisplayedCar.new()
		display.entry=cars[index]
		display.hero=index==cars.size()-1
		display.quality=quality
		add_child(display)
		displays.append(display)
		if not game.profile.reduced_motion:
			display.light_phase=-.025
			display.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(display,"light_phase",0.0,.38)
			if display.hero:
				display.modulate.a=.82
				display.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).tween_property(display,"modulate:a",1.0,.24)
	resized.connect(art.queue_redraw)
	resized.connect(layout_cars)
	layout_cars()
	if quality>0 and not game.profile.reduced_motion:
		var sweep:=FloorLight.new()
		add_child(sweep)
		var lighting:=create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lighting.tween_property(sweep,"drift",.20,6.0).from(-.08)
		lighting.tween_property(sweep,"drift",-.08,6.0)

func layout_cars() -> void:
	for index in displays.size():
		var display:=displays[index]
		var center := (.30 if index==0 else .70) if portrait else (.20 if index==0 else .80)
		if compact: center=.12 if index==0 else .54
		display.position=Vector2(size.x*center,size.y*(.555 if portrait else .57))
		display.width=size.x*(.35 if portrait else (.20 if compact else .28))
		if display.hero:
			display.position=Vector2(size.x*(.32 if compact else .5),size.y*(.65 if portrait else .695))
			display.width=minf(size.x*(.86 if portrait else (.53 if compact else .60)),size.y*1.17)
		display.queue_redraw()
		if not reflections.is_empty():
			reflections[index].position=display.position
			reflections[index].width=display.width
			reflections[index].queue_redraw()
