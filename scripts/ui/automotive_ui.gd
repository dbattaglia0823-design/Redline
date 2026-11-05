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

class PartEmblem extends TechnicalIcon:
	func _draw() -> void:
		var mid:=size*.5
		var radius:=minf(size.x,size.y)*.46
		var corners:=PackedVector2Array()
		for i in 6: corners.append(mid+Vector2.from_angle(TAU*i/6)*radius)
		draw_colored_polygon(corners,Color("102d3d"))
		corners.append(corners[0])
		draw_polyline(corners,Color("376379"),1,true)
		draw_arc(mid,radius*.74,PI*.15,PI*.85,12,Color("51727e"),1,true)
		LiquidGlass.new().icon(self,icon_key,mid-Vector2.ONE*icon_size*.5,icon_size,ink)

static func part_emblem(key: String,extent: float) -> Control:
	var icon:=PartEmblem.new()
	icon.icon_key=key
	icon.icon_size=extent*.58
	icon.custom_minimum_size=Vector2.ONE*extent
	icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return icon

static func part_card(parent: Node,title: String,fitted: String,metric: String,key: String,height: float) -> Button:
	var card:=content_card(parent,height)
	var content: VBoxContainer=card.get_meta("content")
	var line:=row(content,8)
	line.add_child(part_emblem(key,42))
	var names:=column(line,2)
	names.add_child(label(title,22 if height>=100 else 19))
	names.add_child(label(fitted,16 if height>=100 else 14,BLUE))
	content.add_child(label(metric,16 if height>=100 else 14,MUTED))
	card.tooltip_text=title+" / "+fitted+" / "+metric
	return card

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
		var radius:=9 if variant=="Selection" else (16 if variant=="Navigation" else 13)
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

static func content_card(parent: Node,height: float,selected: bool=false) -> Button:
	var b:=button(parent,"","Selection",height); b.toggle_mode=true; b.set_pressed_no_signal(selected)
	var margin:=MarginContainer.new(); b.add_child(margin); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,14)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	var content:=column(margin,3); b.set_meta("content",content)
	return b

static func comparison(parent: Node,title: String,before: float,after: float,unit: String,less_better: bool=false,precision: int=0) -> void:
	var r:=row(parent,8)
	r.add_child(label(title,15,MUTED))
	var format: String="%."+str(precision)+"f"
	var delta:=after-before
	var color:=MUTED if absf(delta)<.001 else (Color("91c9ad") if (delta<0 if less_better else delta>0) else Color("eea29b"))
	var result:=label((format%before)+" → "+(format%after)+" "+unit,17,color,true)
	result.custom_minimum_size.x=230; result.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; r.add_child(result)

static func vehicle_card(parent: Node,g: Node2D,id: String,car: Drivetrain,look: Dictionary,state: String,selected: bool,height: float=110) -> Button:
	var b:=content_card(parent,height,selected)
	var content: VBoxContainer=b.get_meta("content")
	var wide_menu: bool=g.get_window().size.y<500 and g.get_window().content_scale_size.x>1200
	var thumb:=VehiclePreview.new(); content.add_child(thumb); thumb.configure(g,id,car,look,false,height-(77 if wide_menu else 59))
	content.add_child(label(str(GameCatalog.spec(id).name),24 if wide_menu else 17))
	var state_color: Color=Color("91c9ad") if state.begins_with("Equipped") else (BLUE if state.begins_with("Owned") else (Color("eea29b") if state.begins_with("Level") else MUTED))
	content.add_child(label(state,20 if wide_menu else 14,state_color))
	b.tooltip_text=str(GameCatalog.spec(id).name)+" / "+state
	return b

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
