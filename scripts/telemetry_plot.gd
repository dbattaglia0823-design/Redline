class_name TelemetryPlot
extends Control
signal scrubbed(time: float)
var a: Dictionary={}
var b: Dictionary={}
var channel := "speed"
var cursor_time := 0.0
var duration := 1.0
var maximum := 1.0
const A := Color("ffad78")
const B := Color("64cafa")
func configure(first: Dictionary,second: Dictionary,field: String) -> void:
	a=first; b=second; channel=field; queue_redraw()
func graph_area() -> Rect2: return Rect2(42,30,maxf(20,size.x-54),maxf(30,size.y-58))
func _draw() -> void:
	var font:=AutomotiveUI.NUMBERS
	draw_style_box(AutomotiveUI.surface(Color("101c29"),Color("304454"),12),Rect2(Vector2.ZERO,size))
	var area:=graph_area(); maximum=1; duration=1
	for run in [a,b]:
		for row in run.get("samples",[]):
			maximum=maxf(maximum,float(row.get(channel,0))); duration=maxf(duration,RunArchive.elapsed(run,row))
	draw_string(font,Vector2(12,20),"RPM" if channel=="rpm" else "SPEED · MPH",HORIZONTAL_ALIGNMENT_LEFT,-1,13,AutomotiveUI.MUTED)
	for i in 4:
		var y:=area.position.y+area.size.y*i/3.0
		draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color(.4,.6,.7,.13),1)
		draw_string(font,Vector2(3,y+4),"%.0f"%(maximum*(1-i/3.0)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,AutomotiveUI.MUTED)
	for index in 2:
		var run: Dictionary=a if index==0 else b; var points:=PackedVector2Array()
		for row in run.get("samples",[]):
			var t:=RunArchive.elapsed(run,row)
			points.append(area.position+Vector2(t/duration*area.size.x,(1-clampf(float(row.get(channel,0))/maximum,0,1))*area.size.y))
		if points.size()>1: draw_polyline(points,A if index==0 else B,2,true)
	for index in 2:
		var run: Dictionary=a if index==0 else b
		var reaction: Variant=run.get("metrics",{}).get("reaction_s",0)
		for shift in run.get("shifts",[]).slice(0,16):
			var t:=maxf(0,float(shift.time)-(float(reaction) if RunArchive.finite(reaction) else 0))
			var sx:=area.position.x+t/duration*area.size.x
			draw_line(Vector2(sx,area.end.y-5-index*5),Vector2(sx,area.end.y-index*5),A if index==0 else B,1)
	var x:=area.position.x+clampf(cursor_time/duration,0,1)*area.size.x
	draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color("dee7ec"),1)
	draw_string(font,Vector2(area.position.x,size.y-9),"0 s",HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
	draw_string(font,Vector2(area.end.x-62,size.y-9),"%.2f s"%duration,HORIZONTAL_ALIGNMENT_LEFT,-1,11,AutomotiveUI.MUTED)
func seek_x(x: float) -> void:
	var area:=graph_area()
	scrubbed.emit(clampf((x-area.position.x)/maxf(1,area.size.x),0,1)*duration)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed: seek_x(event.position.x); accept_event()
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT: seek_x(event.position.x); accept_event()
