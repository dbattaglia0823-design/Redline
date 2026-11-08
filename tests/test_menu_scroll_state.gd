extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(value: bool, description: String) -> void:
	checks+=1
	if not value:
		failures.append(description)
		push_error(description)

func make_scroll(parent: Node,name: String) -> ScrollContainer:
	var scroller:=ScrollContainer.new()
	scroller.name=name
	scroller.size=Vector2(140,90)
	scroller.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroller)
	var content:=Control.new()
	content.custom_minimum_size=Vector2(130,720)
	scroller.add_child(content)
	return scroller

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var host:=Control.new()
	root.add_child(host)
	var state:=MenuScrollState.new()
	var first:=make_scroll(host,"StudioOptions")
	await process_frame
	await process_frame
	first.scroll_vertical=220
	check(first.scroll_vertical==220,"Fixture does not have a functioning scroll range")
	state.remember(host,"style_paint")
	host.remove_child(first)
	first.free()
	var next:=make_scroll(host,"StudioOptions")
	await process_frame
	await process_frame
	state.restore(host,"style_paint")
	check(next.scroll_vertical==220,"Rebuilding the same menu reset the selected item's scroll offset")
	next.scroll_vertical=80
	state.remember(host,"style_finish")
	state.restore(host,"style_paint")
	check(next.scroll_vertical==220,"Stored scroll offsets leaked between categories")
	state.restore(host,"style_finish")
	check(next.scroll_vertical==80,"Returning to another category did not restore its own position")
	next.scroll_vertical=0
	state.clear_scope("style_paint")
	state.restore(host,"style_paint")
	check(next.scroll_vertical==0,"Clear scope failed to release old scroll position")
	host.queue_free()
	await process_frame
	print("MENU SCROLL STATE: ",checks," checks / ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
