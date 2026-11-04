class_name GlassDock
extends Control

# Native responsive containers handle dock spacing. Input deliberately stays on
# REDLINE's existing action map, so a touch can never trigger two purchases/actions.
const TABS := [["garage","Garage"],["performance","Upgrades"],["style","Customize"],["dealer","Dealer"],["races","Race"],["driver","Driver"]]
var game: Node2D
var panel := PanelContainer.new()
var row := HBoxContainer.new()
var items: Array[Control] = []
var active := "garage"
var selection := -1.0
var selection_target := 0.0

class DockItem extends Control:
	var dock: GlassDock
	var index := 0
	func _draw() -> void:
		var g: Node2D = dock.game
		var key: String = GlassDock.TABS[index][0]
		var selected := dock.active == key or (dock.active == "owned" and key == "garage")
		var hovered := Rect2(Vector2.ZERO,size).has_point(get_local_mouse_position())
		var shade := Color("49382fd4") if selected else Color("ffffff0b")
		if hovered and not selected: g.glass.surface(self,Rect2(Vector2.ZERO,size),shade,Color("ffffff15"),18,false)
		if g.glass.focused == "tab_"+key: g.glass.surface(self,Rect2(Vector2.ZERO,size),Color.TRANSPARENT,Color(g.ORANGE,.7),18,false)
		var color: Color = LiquidGlass.PALETTE.orange if selected else LiquidGlass.PALETTE.muted
		var compact: bool = g.is_portrait()
		var icon_size := 23.0 if compact else 18.0
		g.glass.icon(self,key,Vector2((size.x-icon_size)*.5,9 if compact else 6),icon_size,color)
		var font_size := 18 if compact else 13
		var text: String = GlassDock.TABS[index][1]
		while font_size > 14 and g.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > size.x-8: font_size -= 1
		var width: float = g.font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(g.font,Vector2((size.x-width)*.5,size.y-10),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func setup(g: Node2D) -> void:
	game = g; mouse_filter = Control.MOUSE_FILTER_IGNORE; theme = LiquidGlass.THEME
	add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := LiquidGlass.THEME.get_stylebox("panel","PanelContainer").duplicate() as StyleBoxFlat
	style.set_corner_radius_all(LiquidGlass.PALETTE.radius); style.corner_detail = 12; style.bg_color = LiquidGlass.PALETTE.surface; style.border_color = GlassPalette.EDGE; style.set_border_width_all(1); style.shadow_size = LiquidGlass.PALETTE.shadow_size+5
	style.content_margin_left = 0; style.content_margin_right = 0; style.content_margin_top = 0; style.content_margin_bottom = 0
	panel.add_theme_stylebox_override("panel",style)
	var margins := MarginContainer.new(); margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+side,8)
	panel.add_child(margins); margins.add_child(row); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",4)
	row.draw.connect(draw_selection)
	for i in TABS.size():
		var item := DockItem.new(); item.dock = self; item.index = i
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE; item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item); items.append(item)

func present(rect: Rect2,section: String) -> void:
	visible = true; position = rect.position; size = rect.size; active = section
	selection_target = 0
	for i in TABS.size():
		if section == TABS[i][0]: selection_target = i
	if selection < 0 or game.glass.reduced_motion: selection = selection_target
	var width := (rect.size.x-16-5*4)/6.0
	for i in items.size():
		game.buttons.append({"id":"tab_"+TABS[i][0],"rect":Rect2(rect.position+Vector2(8+i*(width+4),8),Vector2(width,rect.size.y-16))})
		items[i].queue_redraw()
	row.queue_redraw()

func animate(dt: float) -> bool:
	if not visible or selection == selection_target: return false
	selection = selection_target if game.glass.reduced_motion else move_toward(selection,selection_target,dt*30)
	row.queue_redraw()
	return true

func draw_selection() -> void:
	var width := (row.size.x-5*4)/6.0
	game.glass.surface(row,Rect2(selection*(width+4),0,width,row.size.y),Color("49382f99"),Color("ffb28a20"),18,false)
