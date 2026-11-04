class_name VehiclePreview
extends Control

# One opaque renderer for showroom heroes, collection cards and cosmetic previews.
var game: Node2D
var model: String
var car: Drivetrain
var look: Dictionary
var showroom:=true
var art: PreviewArt

class PreviewArt extends Node2D:
	var view: VehiclePreview
	func _draw() -> void:
		var area: Vector2=view.size
		if area.x<1 or area.y<1: return
		if view.showroom and view.game.showroom_texture:
			var tex: Texture2D=view.game.showroom_texture
			var scale: float=maxf(area.x/tex.get_width(),area.y/tex.get_height())
			var region: Vector2=area/scale
			draw_texture_rect_region(tex,Rect2(Vector2.ZERO,area),Rect2((tex.get_size()-region)*.5,region),Color(.68,.77,.88))
		var s: float=minf(area.x/255.0,maxf(1,area.y-10)/84.0)
		var origin:=Vector2((area.x-s*232)*.5,(area.y-s*83.5)*.5)
		VehicleRenderer.draw(self,origin,s,view.model,view.look,view.car,false,Vector2.ZERO,0,false,view.game.profile.effects_quality)

func configure(g: Node2D,id: String,vehicle: Drivetrain,appearance: Dictionary,background: bool=true,height: float=200) -> void:
	game=g; model=id; car=vehicle; look=appearance.duplicate(true); showroom=background
	clip_contents=true; mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y=height; size_flags_horizontal=Control.SIZE_EXPAND_FILL
	art=PreviewArt.new(); art.view=self; add_child(art)
	resized.connect(func(): art.queue_redraw())
	if background and not game.glass.reduced_motion:
		art.position.x=8
		create_tween().tween_property(art,"position:x",0.0,.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
