extends Control
## Read-only placeholder art for unreleased boats and jet skis.

var craft_class := "E"

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 20 or h < 20: return
	var length := minf(w * 0.7, 216.0)
	var x := (w - length) * 0.5
	var y := h * 0.55
	var hull := Color("7593a9")
	var cabin := Color("d6e5e7")
	var outline := Color("9bc8d3")
	draw_line(Vector2(x, y + 30), Vector2(x + length, y + 30), Color("5bacc7", 0.6), 3.0)
	if craft_class in ["E", "D", "C"]:
		draw_colored_polygon(PackedVector2Array([Vector2(x,y + 4),Vector2(x + length * 0.82,y + 4),Vector2(x + length,y - 8),Vector2(x + length * 0.81,y + 24),Vector2(x + length * 0.17,y + 24)]), hull)
		draw_colored_polygon(PackedVector2Array([Vector2(x + length * 0.31,y + 4),Vector2(x + length * 0.49,y - 22),Vector2(x + length * 0.65,y - 22),Vector2(x + length * 0.77,y + 4)]), cabin)
		draw_line(Vector2(x + length * 0.49,y - 20),Vector2(x + length * 0.38,y - 33), outline, 3.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(x,y + 4),Vector2(x + length,y + 4),Vector2(x + length * 0.85,y + 30),Vector2(x + length * 0.19,y + 30)]), hull)
		draw_colored_polygon(PackedVector2Array([Vector2(x + length * 0.35,y + 4),Vector2(x + length * 0.5,y - 24),Vector2(x + length * 0.72,y - 24),Vector2(x + length * 0.83,y + 4)]), cabin)
		draw_line(Vector2(x + length * 0.49,y - 22),Vector2(x + length * 0.49,y - 35), outline, 3.0)
