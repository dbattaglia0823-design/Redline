class_name CosmeticSwatch
extends Control

var game: Node2D
var key: String
var choice: int

class SwatchArt extends Node2D:
	var view: CosmeticSwatch

	func _draw() -> void:
		var g:=view.game
		var key:=view.key
		var index:=view.choice
		var area:=view.size
		var look: Dictionary=g.menu.customize.candidate.duplicate(true)
		look[key]=index
		if key in ["design","rim"]:
			draw_wheel_sample(look,area)
		elif key=="tint":
			draw_tint_sample(area,index)
		else:
			draw_paint_sample(area,g.PAINTS[int(look.paint)],int(look.finish))

	func draw_wheel_sample(look: Dictionary,area: Vector2) -> void:
		var g:=view.game
		var d:=VehicleAppearance.definition(g.profile.vehicle_id)
		var radius:=minf(area.y*.49,area.x*.34)
		var center:=area*.5
		WheelVisuals.draw_vehicle_wheel(self,center,radius,{"omega":0.0,"angle":0.0,"spoke_angle":0.0,"blur":0.0},2,look,d,1)

	func draw_paint_sample(area: Vector2,base: Color,finish: int) -> void:
		var bounds:=Rect2(Vector2(2,2),Vector2(area.x-4,area.y-4))
		for row in 24:
			var y:=row/23.0
			var broad:=sin(y*PI)*.21
			var specular:=exp(-pow((y-.31)/(0.19 if finish==1 else 0.075),2))
			var shine: float=broad+specular*[.58,.11,.39][finish]
			var color:=base.darkened(.42*y).lightened(shine)
			draw_rect(Rect2(bounds.position+Vector2(0,row*bounds.size.y/24.0),Vector2(bounds.size.x,bounds.size.y/24.0+.4)),color)
		draw_rect(bounds,Color("aabfcb"),false,1)
		if finish==2:
			for fleck in 27:
				var point:=bounds.position+bounds.size*Vector2(fposmod(fleck*.617+.07,1),fposmod(fleck*.437+.18,1))
				draw_circle(point,.65,Color(1,.97,.87,.27))

	func draw_tint_sample(area: Vector2,index: int) -> void:
		var points:=PackedVector2Array([area*Vector2(.04,.84),area*Vector2(.22,.16),area*Vector2(.82,.16),area*Vector2(.96,.84)])
		draw_colored_polygon(points,[Color("a1bac9"),Color("53667b"),Color("253448"),Color("121d2b"),Color("080f19")][index])
		draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color("b1c2cb"),1,true)
		draw_line(area*Vector2(.29,.22),area*Vector2(.14,.77),Color(1,1,1,maxf(.12,.36-index*.06)),3,true)
		draw_line(area*Vector2(.68,.22),area*Vector2(.52,.77),Color(1,1,1,maxf(.08,.24-index*.04)),1,true)

func configure(g: Node2D,category: String,index: int) -> void:
	game=g
	key=category
	choice=index
	custom_minimum_size.y=44
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var art:=SwatchArt.new()
	art.view=self
	add_child(art)
	resized.connect(art.queue_redraw)
