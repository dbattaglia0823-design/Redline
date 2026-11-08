extends Control
## Driver skill overlay: imports a v2 layout from Game-Dev-Toolkit.
const LayoutRenderer = preload("res://scripts/ui/toolkit_skill_layout.gd")
const TEMPLATE = "res://data/driver_skill_tree.layout.json"
const ACCENT = Color("f39a55")
const INK = Color("f2eee4")
const MUTED = Color("aab5c4")

var profile: DriverProfile
var renderer
var backdrop: ColorRect
var close_button: Button
var category := "Launch"
var selected := "launch_basics"

func setup(p: DriverProfile) -> void:
	profile = p
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	size = get_viewport_rect().size
	visible = false
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.043, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	renderer = LayoutRenderer.new()
	add_child(renderer)
	if not renderer.load_from_file(TEMPLATE):
		push_error("Driver skill layout could not be loaded")
		return
	# Keep the header visible above the node grid while retaining the wireframe regions.
	var grid: ScrollContainer = renderer.controls.get("node_1") as ScrollContainer
	if grid != null:
		grid.position.y = 85
		grid.size.y = 385
	var title: Label = renderer.controls.get("node_2") as Label
	if title != null:
		title.add_theme_color_override("font_color", ACCENT)
		title.add_theme_font_size_override("font_size", 27)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in ["node_4", "node_6", "node_10", "node_12"]:
		var label: Label = renderer.controls.get(id) as Label
		if label == null: continue
		label.add_theme_color_override("font_color", INK if id == "node_4" else MUTED)
		label.add_theme_font_size_override("font_size", 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for id in ["node_3", "node_9"]:
		var panel: Panel = renderer.controls.get(id) as Panel
		if panel == null: continue
		var style := StyleBoxFlat.new()
		style.bg_color = Color("162333")
		style.border_color = Color("38485a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(14)
		panel.add_theme_stylebox_override("panel", style)
	# Keep remaining points visible while browsing and after spending them.
	var points_label: Label = renderer.controls.get("node_12") as Label
	if points_label != null:
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		points_label.add_theme_color_override("font_color", ACCENT)
		points_label.add_theme_font_size_override("font_size", 17)
		var points_style := StyleBoxFlat.new()
		points_style.bg_color = Color("2a241c")
		points_style.border_color = ACCENT
		points_style.set_border_width_all(1)
		points_style.set_corner_radius_all(10)
		points_style.content_margin_left = 6.0
		points_style.content_margin_right = 6.0
		points_label.add_theme_stylebox_override("normal", points_style)
		points_label.z_index = 3
	var detail: Label = renderer.controls.get("node_6") as Label
	if detail != null: detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	close_button = Button.new()
	close_button.text = "CLOSE  X"
	close_button.position = Vector2(692, 3)
	close_button.size = Vector2(96, 34)
	close_button.pressed.connect(close)
	renderer.add_child(close_button)
	renderer.action_requested.connect(_on_action)
	get_viewport().size_changed.connect(_resize_layout)
	_resize_layout()
	refresh()

func _resize_layout() -> void:
	if renderer == null: return
	size = get_viewport_rect().size
	var available := get_viewport_rect().size - Vector2(24, 24)
	var factor: float = minf(available.x / 800.0, available.y / 500.0)
	renderer.scale = Vector2.ONE * minf(factor, 1.5)
	renderer.position = (get_viewport_rect().size - Vector2(800, 500) * renderer.scale) * 0.5

func show_tree() -> void:
	if profile == null or renderer == null: return
	category = "Launch"
	selected = "launch_basics"
	visible = true
	refresh()

func close() -> void:
	visible = false

func _on_action(action: String, payload: Dictionary) -> void:
	var item: Variant = payload.get("item", {})
	if action == "skills.select_category":
		category = str(item.get("name", category)) if item is Dictionary else str(item)
		for node in DriverSkills.NODES:
			if node.category == category:
				selected = str(node.id)
				break
	elif action == "skills.select_node":
		if item is Dictionary: selected = str(item.get("id", selected))
	elif action == "skills.unlock":
		if profile.unlock_driver_skill(selected): pass
	refresh()

func refresh() -> void:
	if profile == null or renderer == null: return
	var nodes: Array = []
	for node in DriverSkills.NODES:
		if str(node.category) != category: continue
		var rank := int(profile.skill_ranks.get(str(node.id), 0))
		var lock_text := "ACTIVE" if rank > 0 else ("READY" if DriverSkills.can_unlock(profile.skill_ranks, profile.level(), str(node.id)) else "LOCKED")
		nodes.append({"id":node.id,"name":str(node.name) + "\n" + lock_text})
	var selected_node: Dictionary = DriverSkills.node_for(selected)
	if selected_node.is_empty(): return
	var rank := int(profile.skill_ranks.get(selected, 0))
	var prereqs: PackedStringArray = PackedStringArray()
	for required in selected_node.requires:
		var other := DriverSkills.node_for(str(required))
		prereqs.append(str(other.get("name", required)))
	var status := "Unlocked" if rank > 0 else "Locked"
	var description := str(selected_node.description) + "\n\n" + status
	if not prereqs.is_empty(): description += "\nRequires: " + ", ".join(prereqs)
	if rank == 0 and profile.available_skill_points() == 0: description += "\nEarn XP to gain points."
	var base := (profile.level() - 1) * (profile.level() - 1) * 150
	var needed := maxi(1, profile.next_level_xp() - base)
	var percent := clampf(float(profile.xp - base) * 100.0 / float(needed), 0.0, 100.0)
	renderer.set_data({"skills":{
		"nodes":nodes,
		"categories":DriverSkills.CATEGORIES.map(func(value): return {"name":value}),
		"selected_name":str(selected_node.name),
		"selected_description":description,
		"level":"LEVEL %d" % profile.level(),
		"xp_progress":percent,
		"points":"%d AVAILABLE" % profile.available_skill_points()
	}})
	var unlock: Button = renderer.controls.get("node_8") as Button
	if unlock != null:
		unlock.disabled = not profile.can_unlock_driver_skill(selected)
		unlock.text = "UNLOCK  /  1 PT" if not unlock.disabled else ("UNLOCKED" if rank > 0 else "LOCKED")
	var grid: ScrollContainer = renderer.controls.get("node_1") as ScrollContainer
	if grid != null:
		var entries: GridContainer = grid.get_node("Entries") as GridContainer
		if entries != null:
			entries.add_theme_constant_override("h_separation", 5)
			entries.add_theme_constant_override("v_separation", 10)
			for child in entries.get_children():
				if child is Button:
					child.custom_minimum_size = Vector2(108, 72)
					child.add_theme_font_size_override("font_size", 12)
	var categories: ScrollContainer = renderer.controls.get("node_7") as ScrollContainer
	if categories != null:
		var list: GridContainer = categories.get_node("Entries") as GridContainer
		if list != null:
			for child in list.get_children():
				if child is Button:
					child.custom_minimum_size = Vector2(104, 44)
					child.add_theme_font_size_override("font_size", 13)
					child.modulate = ACCENT if child.text == category else INK
