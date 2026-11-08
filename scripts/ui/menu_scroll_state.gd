class_name MenuScrollState
extends RefCounted

# The native menus rebuild Control trees whenever selection/state changes.
# Save positions by logical view and named scroll, never by Control instance.
var positions: Dictionary = {}

func _scrolls(root: Node) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	if root is ScrollContainer:
		found.append(root)
	for child in root.get_children():
		found.append_array(_scrolls(child))
	return found

func remember(root: Node, scope: String) -> void:
	if scope.is_empty() or not is_instance_valid(root): return
	var seen: Dictionary = {}
	for scroll in _scrolls(root):
		if scroll.is_queued_for_deletion(): continue
		var name: String = str(scroll.name)
		var number: int = int(seen.get(name,0))
		seen[name] = number+1
		positions[scope+"|"+name+"|"+str(number)] = Vector2i(scroll.scroll_horizontal,scroll.scroll_vertical)

func restore(root: Node, scope: String) -> void:
	if scope.is_empty() or not is_instance_valid(root): return
	var seen: Dictionary = {}
	for scroll in _scrolls(root):
		if scroll.is_queued_for_deletion(): continue
		var name: String = str(scroll.name)
		var number: int = int(seen.get(name,0))
		seen[name] = number+1
		var key: String=scope+"|"+name+"|"+str(number)
		if not positions.has(key): continue
		var value: Vector2i=positions[key]
		scroll.scroll_horizontal=value.x
		scroll.scroll_vertical=value.y

func clear_scope(scope: String) -> void:
	for key in positions.keys():
		if str(key).begins_with(scope+"|"): positions.erase(key)
