class_name GarageShowroom
extends Control

const SCENE_PATH := "res://assets/ui/night_garage.svg"

class StageArt extends Node2D:
	var stage: GarageShowroom

	func _draw() -> void:
		var area := stage.size
		if area.x<10 or area.y<10: return
		draw_texture_rect(stage.scene,Rect2(Vector2.ZERO,area),false)
		var tall := area.x/area.y<1.3
		var sign := Vector2(area.x*.5,area.y*.394)
		draw_string(AutomotiveUI.DISPLAY,sign-Vector2(92,0),"R E D L I N E",HORIZONTAL_ALIGNMENT_CENTER,184,18,Color("d0ecf5"))
		if stage.quality>0:
			var pool := Rect2(area*Vector2(.12,.55),area*Vector2(.76,.38))
			AutomotiveUI.glow(self,pool,Color(.45,.69,.82,.19))
		for index in 2:
			var center := .20 if index==0 else .80
			var position := Vector2(area.x*center,area.y*(.632 if tall else .615))
			var width := minf(area.x*(.37 if tall else .31),area.y*.91)
			var caption: String="%02d / OPEN"%(index+2)
			if index<stage.parked.size():
				var entry: Dictionary=stage.parked[index]
				draw_car(entry,position,width,false)
				caption="%02d / PARKED"%(index+2)
			draw_bay_caption(Vector2(position.x,area.y*.29),caption,area.x)
		var foreground := Vector2(area.x*.5,area.y*(.847 if tall else .85))
		var hero_width := minf(area.x*(.82 if tall else .55),area.y*1.55)
		draw_car(stage.active,foreground,hero_width,true)
		draw_rect(Rect2(Vector2.ZERO,area),Color("547789"),false,1)
		draw_line(Vector2(0,area.y-1),Vector2(area.x*.22,area.y-1),Color("eb756a"),2,true)

	func draw_bay_caption(position: Vector2,caption: String,stage_width: float) -> void:
		var width:=minf(114,stage_width*.19)
		var badge:=Rect2(position-Vector2(width*.5,0),Vector2(width,20))
		draw_rect(badge,Color(.036,.077,.108,.86))
		draw_line(badge.position,badge.position+Vector2(width,0),Color(.42,.69,.75,.66),1)
		draw_string(AutomotiveUI.NUMBERS,badge.position+Vector2(0,14),caption,HORIZONTAL_ALIGNMENT_CENTER,width,12,AutomotiveUI.BLUE)

	func draw_car(entry: Dictionary,position: Vector2,width: float,hero: bool) -> void:
		var data := VehicleAppearance.definition(entry.id)
		if data.is_empty(): return
		var scale_factor := width/1000.0
		var left := position.x-width*.5
		var car: Drivetrain=entry.car
		var radius_scale := WheelVisuals.radius_scale(car,GameCatalog.spec(entry.id))
		var rear := VehicleAppearance.point(data.rear)
		var front := VehicleAppearance.point(data.front)
		var radii: Array=data.get("wheel_radii",[data.radius,data.radius])
		var ground := maxf(rear.y+float(radii[0])*radius_scale,front.y+float(radii[1])*radius_scale)
		var lift := float(data.radius)*(radius_scale-1.0)
		var origin := Vector2(left,position.y-(ground-lift)*scale_factor)
		if stage.quality>0:
			var reflection_offset := (ground-VehicleAppearance.body_drop(entry.look))*scale_factor*.31
			draw_set_transform(Vector2(left,position.y+reflection_offset),0.0,Vector2(1,-.31))
			VehicleRenderer.layer(self,str(data.body)%[int(entry.look.paint),["gloss","matte","metallic"][int(entry.look.finish)]],Vector2.ZERO,scale_factor,Color(.54,.76,.89,.20 if hero else .11))
			draw_set_transform(Vector2.ZERO)
		VehicleRenderer.draw(self,origin,width/232.0,entry.id,entry.look,car,false,Vector2.ZERO,0,false,stage.quality,not hero)

class FloorLight extends Node2D:
	var drift := 0.0:
		set(value):
			drift=value
			queue_redraw()

	func _draw() -> void:
		var area: Vector2=get_parent().size
		var bounds:=Rect2(area*Vector2(.12+drift,.85),area*Vector2(.58,.14))
		AutomotiveUI.glow(self,bounds,Color(.36,.71,.82,.19))

var scene: Texture2D
var active: Dictionary
var parked: Array[Dictionary]=[]
var quality: int

func setup(game: Node2D,minimum_height: float) -> void:
	scene=load(SCENE_PATH)
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
	resized.connect(art.queue_redraw)
	if quality>0 and not game.profile.reduced_motion:
		var sweep:=FloorLight.new()
		add_child(sweep)
		var lighting:=create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		lighting.tween_property(sweep,"drift",.20,6.0).from(-.08)
		lighting.tween_property(sweep,"drift",-.08,6.0)
