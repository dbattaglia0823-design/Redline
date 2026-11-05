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
		if view.showroom:
			var tex:=LiquidGlass.menu_scene(view.game,view.game.tab if not view.game.glass.legacy else "garage")
			if tex!=null: LiquidGlass.draw_cover(self,tex,Rect2(Vector2.ZERO,area),Color(.75,.79,.85))
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
