extends Node2D
var model:="miata"
var car:=Drivetrain.new()
var look:=VehicleAppearance.normalize({})
var quality:=2
var night:=false
const ORIGIN:=Vector2(30,60)
const SIZE:=4.6
func _draw() -> void:
	draw_rect(Rect2(0,0,1200,760),Color("101820"))
	VehicleRenderer.draw(self,ORIGIN,SIZE,model,look,car,true,Vector2.ZERO,0,false,quality,night)
