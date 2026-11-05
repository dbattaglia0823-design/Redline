class_name VehiclePreview
extends Control

# One opaque renderer for showroom heroes, collection cards and cosmetic previews.
var game: Node2D
var model: String
var car: Drivetrain
var look: Dictionary
var showroom:=true
var scene_texture: Texture2D
var scene_tint:=Color(.86,.85,.84)
var road_preview:=false
var art: PreviewArt

class PreviewArt extends Node2D:
	var view: VehiclePreview
	var offset := Vector2.ZERO:
		set(value):
			offset = value
			queue_redraw()
	var reveal := 1.0:
		set(value):
			reveal = value
			queue_redraw()
	func _draw() -> void:
		var area: Vector2=view.size
		if area.x<1 or area.y<1: return
		if view.showroom:
			if view.scene_texture!=null:
				LiquidGlass.draw_cover(self,view.scene_texture,Rect2(Vector2.ZERO,area),view.scene_tint)
			if view.road_preview:
				var surface:=TrackPresentation.surface("race_surface")
				draw_texture_rect(surface,Rect2(0,area.y*.76,area.x,area.y*.24),false,Color(.62,.61,.60))
			var shade:=Color(.025,.021,.026,.68)
			draw_polygon(PackedVector2Array([Vector2(0,area.y*.52),area*Vector2(1,.52),area,Vector2(0,area.y)]),
				PackedColorArray([Color.TRANSPARENT,Color.TRANSPARENT,shade,shade]))
			draw_rect(Rect2(0,area.y-2,area.x,2),Color("2c292c"))
			draw_rect(Rect2(0,area.y-2,minf(area.x*.21,112),2),AutomotiveUI.ORANGE)
		var s: float=minf(area.x/255.0,maxf(1,area.y-10)/84.0)
		var origin:=Vector2((area.x-s*232)*.5,(area.y-s*83.5)*.5)
		if view.showroom:
			# Width-limited portrait heroes sit lower in the bay, on the floor.
			origin.y += maxf(0,area.y-s*105.0)*.14
			VehicleRenderer.showroom_light(self,Rect2(Vector2.ZERO,area),view.game.profile.effects_quality)
		VehicleRenderer.draw(self,origin+offset,s,view.model,view.look,view.car,false,Vector2.ZERO,0,false,view.game.profile.effects_quality,false,false,null,reveal)

func configure(g: Node2D,id: String,vehicle: Drivetrain,appearance: Dictionary,background: bool=true,height: float=200,animated: bool=true) -> void:
	game=g; model=id; car=vehicle; look=appearance.duplicate(true); showroom=background
	if background:
		if game.tab=="races" or game.screen=="results":
			var contract: Dictionary=game.active_contract if game.screen=="results" else game.current_contract()
			road_preview=true
			var track:=TrackPresentation.spec(int(contract.get("track_index",game.event_index)))
			scene_texture=load("res://assets/strip/"+str(track.art)+"_panorama.png")
			scene_tint=Color(.56,.59,.62)
		else:
			scene_texture=game.showroom_texture
			if game.tab=="performance": scene_tint=Color(.68,.64,.62)
			elif game.tab=="dealer": scene_tint=Color(.92,.93,.91)
	clip_contents=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y=height; size_flags_horizontal=Control.SIZE_EXPAND_FILL
	art=PreviewArt.new(); art.view=self; add_child(art)
	resized.connect(func(): art.queue_redraw())
	if background and animated and not game.glass.reduced_motion:
		art.offset=Vector2(12,3)
		art.reveal=.75
		var tween:=create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(art,"offset",Vector2.ZERO,.24)
		tween.tween_property(art,"reveal",1.0,.24)
