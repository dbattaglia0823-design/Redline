class_name GlassDock
extends Control

const TABS := [["garage","Garage"],["performance","Upgrade"],["races","Race"],["dealer","Dealership"],["driver","Profile"]]
const RACE := 2
var game: Node2D
var items: Array[DockItem] = []
var active := "garage"
var selection := Rect2()
var selection_target := Rect2()
var frame_skin := AutomotiveUI.surface(Color("101820"),Color("526576"),22)
var recess := AutomotiveUI.surface(Color("1b2530"),Color("2e3c49"),15)
var race_skin := AutomotiveUI.surface(Color("3c2427"),Color("c07961"),17)
var selected_skin := AutomotiveUI.surface(Color("253a48"),Color("76a7b6"),15)
var race_selected := AutomotiveUI.surface(Color("773b30"),Color("ffad7f"),17)
var shadow := AutomotiveUI.surface(Color(.014,.02,.03,.72),Color.TRANSPARENT,24)

class DockItem extends Button:
	var dock: GlassDock
	var index: int
	var symbol: AutomotiveUI.TechnicalIcon
	var caption: Label
	var press_pulse := 0.0

	func prepare() -> void:
		focus_mode=Control.FOCUS_NONE
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","pressed","focus","hover","hover_pressed"]:
			add_theme_stylebox_override(state,StyleBoxEmpty.new())
		var content:=AutomotiveUI.column(self,3)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.alignment=BoxContainer.ALIGNMENT_CENTER
		var center:=CenterContainer.new()
		center.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(center)
		symbol=AutomotiveUI.TechnicalIcon.new()
		symbol.icon_key=GlassDock.TABS[index][0]
		center.add_child(symbol)
		caption=AutomotiveUI.label(GlassDock.TABS[index][1],15)
		caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(caption)
		pressed.connect(func():
			press_pulse=1.0
			queue_redraw()
			dock.game.action("tab_"+GlassDock.TABS[index][0]))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func refresh() -> void:
		var large:=size.y>=76
		var race:=index==GlassDock.RACE
		var selected: bool=dock.active==GlassDock.TABS[index][0]
		var ink:=Color("ffd4ba") if race else (AutomotiveUI.INK if selected else AutomotiveUI.MUTED)
		symbol.icon_size=(26 if large else 22)+(5 if race else 0)
		symbol.custom_minimum_size=Vector2.ONE*(symbol.icon_size+2)
		symbol.ink=AutomotiveUI.ORANGE if race else (AutomotiveUI.BLUE if selected else ink)
		symbol.queue_redraw()
		var font_size: int=(20 if large else 16)+(2 if race else 0)
		var font:=caption.get_theme_font("font")
		while font_size>10 and font.get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>size.x-8:
			font_size-=1
		caption.add_theme_font_size_override("font_size",font_size)
		caption.add_theme_color_override("font_color",ink)
		queue_redraw()

	func _draw() -> void:
		var key: String=GlassDock.TABS[index][0]
		var rect:=Rect2(Vector2.ZERO,size)
		if is_hovered():
			dock.hover_skin.draw(get_canvas_item(),rect)
		if button_pressed or press_pulse>.05:
			var intensity:=1.0 if button_pressed else press_pulse
			draw_line(Vector2(15,size.y-4),Vector2(size.x-15,size.y-4),Color(AutomotiveUI.ORANGE,intensity),2,true)
		if dock.game.glass.focused=="tab_"+key:
			dock.focus_skin.draw(get_canvas_item(),rect)

var hover_skin:=AutomotiveUI.surface(Color(1,1,1,.055),Color(1,1,1,.17),15)
var focus_skin:=AutomotiveUI.surface(Color.TRANSPARENT,AutomotiveUI.ORANGE,15)

func setup(g: Node2D) -> void:
	game=g
	z_index=10
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	for i in TABS.size():
		var item:=DockItem.new()
		item.dock=self
		item.index=i
		add_child(item)
		item.prepare()
		items.append(item)

func present(rect: Rect2,section: String) -> void:
	visible=true
	position=rect.position
	var resized:=size!=rect.size
	size=rect.size
	active="garage" if section in ["owned","style"] else ("performance" if section=="tuning" else section)
	var unit:=(size.x-32.0)/5.5
	var x:=8.0
	selection_target=Rect2()
	for i in items.size():
		var width:=unit*(1.5 if i==RACE else 1.0)
		var inset:=5.0 if i==RACE else 9.0
		var cell:=Rect2(x,inset,width,size.y-inset*2)
		items[i].position=cell.position
		items[i].size=cell.size
		items[i].refresh()
		var key: String=TABS[i][0]
		if key==active: selection_target=cell
		game.buttons.append({"id":"tab_"+key,"rect":Rect2(position+cell.position,cell.size),"native_control":items[i]})
		x+=width+4
	if not selection.has_area() or game.glass.reduced_motion or resized:
		selection=selection_target
	queue_redraw()

func animate(dt: float) -> bool:
	if not visible: return false
	for item in items:
		if item.press_pulse>0.0:
			item.press_pulse=move_toward(item.press_pulse,0.0,dt*4.0)
			item.queue_redraw()
	if not selection.is_equal_approx(selection_target):
		var weight:=1.0 if game.glass.reduced_motion else 1.0-exp(-dt*18.0)
		selection=Rect2(selection.position.lerp(selection_target.position,weight),selection.size.lerp(selection_target.size,weight))
		if selection.position.distance_to(selection_target.position)<.2: selection=selection_target
	queue_redraw()
	return false

func _draw() -> void:
	if items.size()!=TABS.size(): return
	var canvas:=get_canvas_item()
	shadow.draw(canvas,Rect2(Vector2(-3,4),size+Vector2(6,3)))
	frame_skin.draw(canvas,Rect2(Vector2.ZERO,size))
	draw_line(Vector2(24,3),Vector2(size.x-24,3),Color(.63,.78,.86,.30),1,true)
	for i in items.size():
		var cell:=Rect2(items[i].position,items[i].size)
		if i==RACE:
			AutomotiveUI.glow(self,cell.grow(14),Color(1,.29,.12,.33 if active=="races" else .18))
			race_skin.draw(canvas,cell)
		else:
			recess.draw(canvas,cell)
	if selection.has_area():
		(race_selected if active=="races" else selected_skin).draw(canvas,selection)
		var y:=selection.end.y-4
		draw_line(Vector2(selection.get_center().x-19,y),Vector2(selection.get_center().x+19,y),AutomotiveUI.ORANGE if active=="races" else AutomotiveUI.BLUE,2,true)
