class_name AutomotiveUI
extends RefCounted

# Shared native Control vocabulary. Vehicle art and charts remain CanvasItems.
const BODY = preload("res://assets/ui/fonts/Ubuntu-Regular.ttf")
const DISPLAY = preload("res://assets/ui/fonts/Ubuntu-Medium.ttf")
const NUMBERS = preload("res://assets/ui/fonts/SourceCodePro-Regular.ttf")
const INK = Color("edf3fa")
const MUTED = Color("91a6b9")
const BLUE = Color("62cafa")
const ORANGE = Color("ff9966")
static var shared_theme: Theme

class TechnicalIcon extends Control:
	var icon_key: String
	var ink:=AutomotiveUI.BLUE
	var icon_size:=28.0
	func _draw() -> void:
		LiquidGlass.new().icon(self,icon_key,Vector2(2,2),icon_size,ink)

static func surface(fill: Color,edge: Color=Color("294353"),radius: int=14) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=fill; s.border_color=edge; s.set_border_width_all(1)
	s.set_corner_radius_all(radius); s.corner_detail=10
	s.content_margin_left=18; s.content_margin_right=18
	s.content_margin_top=12; s.content_margin_bottom=12
	return s

static func theme_resource() -> Theme:
	if shared_theme!=null: return shared_theme
	var t:=Theme.new(); t.default_font=BODY; t.default_font_size=18
	t.set_color("font_color","Label",INK)
	for variant in ["Secondary","Primary","Selection","Navigation"]:
		t.set_type_variation(variant,"Button")
		var fill:=Color("102331") if variant!="Primary" else Color("74391f")
		if variant=="Navigation": fill=Color("081620")
		var edge:=Color("315064") if variant!="Primary" else Color("c57548")
		var radius:=10 if variant=="Selection" else 18
		t.set_stylebox("normal",variant,surface(fill,edge,radius))
		t.set_stylebox("hover",variant,surface(fill.lightened(.09),BLUE,radius))
		t.set_stylebox("pressed",variant,surface(Color("392b25") if variant!="Primary" else Color("9c4924"),ORANGE,radius))
		t.set_stylebox("disabled",variant,surface(Color("101c25"),Color("23313d"),radius))
		t.set_stylebox("focus",variant,surface(Color.TRANSPARENT,ORANGE,radius))
		for state in ["font_color","font_hover_color","font_pressed_color"]: t.set_color(state,variant,INK)
		t.set_color("font_disabled_color",variant,Color("677d8f"))
		t.set_font("font",variant,DISPLAY)
	var panel_style:=surface(Color("0c1c28ef"))
	panel_style.shadow_size=10; panel_style.shadow_color=Color(0,0,0,.2); panel_style.shadow_offset=Vector2(0,4)
	t.set_stylebox("panel","PanelContainer",panel_style)
	t.set_constant("separation","VBoxContainer",12); t.set_constant("separation","HBoxContainer",14)
	shared_theme=t
	return t

static func label(value: String,points: int=18,color: Color=INK,numeric: bool=false) -> Label:
	var l:=Label.new(); l.text=value
	l.add_theme_font_override("font",NUMBERS if numeric else (DISPLAY if points>=24 else BODY))
	l.add_theme_font_size_override("font_size",points); l.add_theme_color_override("font_color",color)
	l.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

static func column(parent: Node,gap: int=12) -> VBoxContainer:
	var c:=VBoxContainer.new(); c.add_theme_constant_override("separation",gap); parent.add_child(c)
	c.size_flags_horizontal=Control.SIZE_EXPAND_FILL; c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return c

static func row(parent: Node,gap: int=14) -> HBoxContainer:
	var c:=HBoxContainer.new(); c.add_theme_constant_override("separation",gap); parent.add_child(c)
	c.size_flags_horizontal=Control.SIZE_EXPAND_FILL; c.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return c

static func panel(parent: Node) -> VBoxContainer:
	var p:=PanelContainer.new(); parent.add_child(p); p.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return column(p)

static func stat(parent: Node,title: String,value: String,unit: String) -> void:
	var c:=column(parent,3); c.add_child(label(title,12,MUTED))
	var r:=row(c,6)
	var number:=label(value,30,INK,true); number.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	number.custom_minimum_size.x=NUMBERS.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x; r.add_child(number)
	var u:=label(unit,14,MUTED); u.custom_minimum_size.x=26; u.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; u.size_flags_vertical=Control.SIZE_SHRINK_CENTER; r.add_child(u)

static func button(parent: Node,title: String,variant: String="Secondary",height: float=48) -> Button:
	var b:=Button.new(); b.text=title; b.theme_type_variation=variant
	b.custom_minimum_size.y=height; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	# Pointer routing uses the existing single action dispatcher. Native focus and
	# signals are retained, with no second GUI handler charging the player twice.
	b.focus_mode=Control.FOCUS_NONE; b.mouse_filter=Control.MOUSE_FILTER_PASS
	parent.add_child(b); return b

static func selection(parent: Node,title: String,state: String,detail: String,selected: bool,height: float,icon_key: String="",state_color: Color=MUTED) -> Button:
	var b:=button(parent,"","Selection",height); b.toggle_mode=true; b.set_pressed_no_signal(selected)
	var m:=MarginContainer.new(); m.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.add_child(m); m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: m.add_theme_constant_override("margin_"+side,18)
	for side in ["top","bottom"]: m.add_theme_constant_override("margin_"+side,10)
	var c:=column(m,3)
	var heading:=row(c,8)
	if icon_key!="":
		var icon:=TechnicalIcon.new(); icon.icon_key=icon_key; icon.custom_minimum_size=Vector2(32,32); icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; heading.add_child(icon)
	heading.add_child(label(title,21))
	c.add_child(label(state,15,state_color if state_color!=MUTED else (ORANGE if selected else MUTED)))
	if detail!="": c.add_child(label(detail,15,INK))
	return b
