class_name CosmeticSwatch
extends Control

# Use the same wheel renderer / authored factory wheel as the vehicle preview.
var game: Node2D
var key: String
var choice: int
var art: SwatchArt
class SwatchArt extends Node2D:
	var view: CosmeticSwatch
	func _draw() -> void:
		var g: Node2D=view.game; var key: String=view.key; var choice: int=view.choice
		var center:=view.size*.5; var radius:=minf(view.size.y*.43,23)
		var look: Dictionary=g.menu.customize.candidate.duplicate(true); look[key]=choice
		if key in ["design","sidewall"]:
			var d:=VehicleAppearance.definition(g.profile.vehicle_id)
			if d.has("stock_wheels") and int(look.design)==0 and int(look.rim)==0 and int(look.caliper)==0 and int(look.sidewall)==0:
				var tex:=VehicleAppearance.texture(str(d.stock_wheels[0]))
				if tex: draw_texture_rect(tex,Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2),false)
			else: WheelVisuals.draw_wheel(self,center,radius,1,int(look.rim),{"angle":0.0,"spoke_angle":0.0,"blur":0.0},1,look)
			return
		var color:=Color("8aa1b5")
		if key=="paint": color=g.PAINTS[choice]
		elif key=="rim": color=[Color("c5cdd2"),Color("b8a077"),Color("6d7b88")][choice]
		elif key=="caliper": color=[Color("cc5430"),Color("e53942"),Color("edc343"),Color("bac5cf")][choice]
		elif key=="headlight": color=[Color("fff9d9"),Color("b1eaff"),Color("ffcc6c")][choice]
		elif key=="taillight": color=[Color("ff5f4f"),Color("ff223f"),Color("542230")][choice]
		elif key=="finish": color=g.PAINTS[int(look.paint)]
		draw_circle(center,radius,color,true,-1,true)
		draw_arc(center,radius,0,TAU,40,Color("ffffff55"),1,true)
		if key=="finish" and choice!=1:
			draw_arc(center+Vector2(0,4),radius*.8,3.5,5.5,20,Color(1,1,1,.5 if choice==0 else .7),3,true)
			if choice==2:
				for i in 9: draw_circle(center+Vector2(sin(i*7.1),cos(i*3.8))*radius*.65,.7,Color("ffffff99"))

func configure(g: Node2D,category: String,index: int) -> void:
	game=g; key=category; choice=index; custom_minimum_size.y=48; mouse_filter=Control.MOUSE_FILTER_IGNORE
	art=SwatchArt.new(); art.view=self; add_child(art); resized.connect(func(): art.queue_redraw())
