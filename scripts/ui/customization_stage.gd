class_name CustomizationStage
extends Control

const STUDIO := preload("res://assets/ui/customization_studio.svg")
var game: Node2D
var custom: CustomizationView
var look: Dictionary
var art: StageArt
var pose := Vector2(0,1):
	set(value):
		pose=value
		custom.camera_pose=value
		art.queue_redraw()

class StageArt extends Node2D:
	var stage: CustomizationStage

	func _draw() -> void:
		var area:=stage.size
		if area.x<10 or area.y<10: return
		var g:=stage.game
		var d:=VehicleAppearance.definition(g.profile.vehicle_id)
		var quality: int=g.profile.effects_quality
		var focus:=stage.pose.x
		var zoom:=stage.pose.y
		var background:=Rect2(Vector2.ZERO,area)
		LiquidGlass.draw_cover(self,CustomizationStage.STUDIO,background,Color(.90,.94,1.0))
		if quality>0:
			AutomotiveUI.glow(self,Rect2(area*Vector2(.06,.38),area*Vector2(.88,.50)),Color(.38,.58,.76,.22))
		var radius_factor:=WheelVisuals.radius_scale(g.car,GameCatalog.spec(g.profile.vehicle_id))
		var rear:=VehicleAppearance.point(d.rear)
		var front:=VehicleAppearance.point(d.front)
		var radii: Array=d.get("wheel_radii",[d.radius,d.radius])
		var ground:=maxf(rear.y+float(radii[0])*radius_factor,front.y+float(radii[1])*radius_factor)
		var lift:=float(d.radius)*(radius_factor-1.0)
		var full:=minf(area.x*.97/1000.0,area.y*.72/360.0)*zoom
		var detail:=minf(area.x*.69,area.y*.67)/(float(radii[1])*radius_factor*2.0)*zoom
		var scale_factor:=lerpf(full,detail,focus)
		var full_origin:=Vector2(area.x*.5-500*full,area.y*.73-(ground-lift)*full)
		var detail_origin:=area*Vector2(.57,.49)-(front-Vector2(0,lift))*detail
		var origin:=full_origin.lerp(detail_origin,focus)
		var ground_y:=origin.y+(ground-lift)*scale_factor
		if quality>0:
			var reflection_strength:=lerpf(.17,.07,focus)
			var drop:=VehicleAppearance.body_drop(stage.look)
			var mirror_origin:=Vector2(origin.x,ground_y+(ground-drop)*scale_factor*.26)
			var finish: String=["gloss","matte","metallic"][int(stage.look.finish)]
			var body_path:=str(d.body)%[int(stage.look.paint),finish]
			for displacement in [-2.0,2.0,0.0]:
				draw_set_transform(mirror_origin+Vector2(displacement,absf(displacement)*.6),0.0,Vector2(1,-.26))
				VehicleRenderer.layer(self,body_path,Vector2.ZERO,scale_factor,Color(.68,.81,.94,reflection_strength*(1.0 if displacement==0.0 else .24)))
			draw_set_transform(Vector2.ZERO)
		VehicleRenderer.draw(self,origin,scale_factor/.232,g.profile.vehicle_id,stage.look,g.car,false,Vector2.ZERO,0,false,quality,false,false,null,1.0,true)
		draw_rect(background,Color("3a5367"),false)
		draw_line(Vector2(0,area.y-1),Vector2(area.x*.24,area.y-1),Color("cf906a"),2)

func configure(g: Node2D,appearance: Dictionary,minimum_height: float) -> void:
	game=g
	custom=g.menu.customize
	look=appearance.duplicate(true)
	custom_minimum_size.y=minimum_height
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	clip_contents=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	art=StageArt.new()
	art.stage=self
	add_child(art)
	resized.connect(art.queue_redraw)
	pose=custom.camera_pose
	var target:=custom.camera_target()
	if game.profile.reduced_motion or pose.is_equal_approx(target):
		pose=target
	else:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).tween_property(self,"pose",target,.42)
