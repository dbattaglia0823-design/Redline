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

class DockItem extends Button:
	var dock: GlassDock
	var index := 0
	var symbol: AutomotiveUI.TechnicalIcon
	var caption: Label
	func prepare() -> void:
		theme=AutomotiveUI.theme_resource(); focus_mode=Control.FOCUS_NONE
		mouse_filter=Control.MOUSE_FILTER_PASS; mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		for state in ["normal","pressed","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
		add_theme_stylebox_override("hover",AutomotiveUI.surface(Color("ffffff08"),Color("ffffff10"),18))
		var content:=AutomotiveUI.column(self,3); content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); content.alignment=BoxContainer.ALIGNMENT_CENTER
		var center:=CenterContainer.new(); center.mouse_filter=Control.MOUSE_FILTER_IGNORE; content.add_child(center)
		symbol=AutomotiveUI.TechnicalIcon.new(); symbol.icon_key=GlassDock.TABS[index][0]; symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE; center.add_child(symbol)
		caption=AutomotiveUI.label(GlassDock.TABS[index][1],13); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; content.add_child(caption)
		pressed.connect(func(): dock.game.action("tab_"+GlassDock.TABS[index][0]))
	func refresh() -> void:
		var g: Node2D=dock.game
		var key: String=GlassDock.TABS[index][0]
		var selected: bool=dock.active==key or (dock.active=="owned" and key=="garage")
		var color: Color=AutomotiveUI.ORANGE if selected else AutomotiveUI.MUTED
		var wide_menu: bool=g.screen=="garage" and g.get_window().content_scale_size.x>1200
		symbol.icon_size=28 if wide_menu else (23 if g.is_portrait() else 18); symbol.custom_minimum_size=Vector2.ONE*(symbol.icon_size+4); symbol.ink=color; symbol.queue_redraw()
		caption.add_theme_font_size_override("font_size",26 if wide_menu else (18 if g.is_portrait() else 13)); caption.add_theme_color_override("font_color",color)
		queue_redraw()
	func _draw() -> void:
		var g: Node2D = dock.game
		var key: String = GlassDock.TABS[index][0]
		if g.glass.focused == "tab_"+key: g.glass.surface(self,Rect2(Vector2.ZERO,size),Color.TRANSPARENT,Color(g.ORANGE,.7),18,false)

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
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item); item.prepare(); items.append(item)

func present(rect: Rect2,section: String) -> void:
	visible = true; position = rect.position; size = rect.size; active = section
	selection_target = 0
	for i in TABS.size():
		if section == TABS[i][0]: selection_target = i
	if selection < 0 or game.glass.reduced_motion: selection = selection_target
	var width := (rect.size.x-16-5*4)/6.0
	for i in items.size():
		game.buttons.append({"id":"tab_"+TABS[i][0],"rect":Rect2(rect.position+Vector2(8+i*(width+4),8),Vector2(width,rect.size.y-16)),"native_control":items[i]})
		items[i].refresh()
	row.queue_redraw()

func animate(dt: float) -> bool:
	if not visible or selection == selection_target: return false
	selection = selection_target if game.glass.reduced_motion else move_toward(selection,selection_target,dt*30)
	row.queue_redraw()
	return true

func draw_selection() -> void:
	var width := (row.size.x-5*4)/6.0
	game.glass.surface(row,Rect2(selection*(width+4),0,width,row.size.y),Color("49382f99"),Color("ffb28a20"),18,false)
