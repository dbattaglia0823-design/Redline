class_name GamepadControls
extends RefCounted

# Godot's mapped joypad layout uses the same physical positions on both families.
const HOLDS := {JOY_BUTTON_LEFT_SHOULDER:"clutch",JOY_BUTTON_RIGHT_SHOULDER:"transbrake",JOY_BUTTON_A:"nitrous"}
var device := -1
var active := false
var playstation := false
var direction := Vector2.ZERO
var repeat_left := 0.0
var focus_control: Control
var held_buttons: Dictionary = {}

func setup(g: Node2D) -> void:
	Input.joy_connection_changed.connect(func(id: int,connected: bool): connection_changed(g,id,connected))

static func is_playstation(name: String) -> bool:
	var label := name.to_lower()
	for token in ["playstation","dualsense","dualshock","sony","ps4","ps5"]:
		if token in label: return true
	return false

func connection_changed(g: Node2D,id: int,connected: bool) -> void:
	if connected:
		g.show_toast("Controller connected · press any button")
	elif device == id:
		g.controls.joy.clear(); held_buttons.clear(); reset_navigation(); device=-1; active=false
		if g.screen=="race": g.set_race_paused(true)
		g.show_toast("Controller disconnected · reconnect or use keyboard / touch")

func reset_navigation() -> void:
	direction=Vector2.ZERO; repeat_left=0
	held_buttons.clear()

func hint(id: String) -> String:
	return {"gas":"R2" if playstation else "RT","brake":"L2" if playstation else "LT","clutch":"L1" if playstation else "LB","transbrake":"R1" if playstation else "RB","nitrous":"Cross" if playstation else "A","up":"Circle" if playstation else "B","down":"Square" if playstation else "X","pause":"Options" if playstation else "Menu"}.get(id,"")

func handle(g: Node2D,event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis not in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT,JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]: return
	var meaningful: bool = event.pressed if event is InputEventJoypadButton else absf(event.axis_value)>.2
	if device!=event.device:
		if not meaningful: return
		# Do not let a second controller take over a held pedal mid-race.
		if device>=0 and g.screen=="race" and not g.paused_race: return
		g.controls.joy.clear(); held_buttons.clear(); reset_navigation(); device=event.device
		playstation=is_playstation(Input.get_joy_name(device)) or int(Input.get_joy_info(device).get("vendor_id",0))==0x054c
	if meaningful and not active:
		active=true
		g.show_toast(("PlayStation" if playstation else "Xbox / gamepad")+" · D-pad / stick: navigate · "+("Cross: select · Circle: back" if playstation else "A: select · B: back"))
	g.menu_dirty=true
	if g.input_override.x>=0: return
	if g.audio_lab!=null and g.audio_lab.visible:
		if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B,JOY_BUTTON_BACK]: g.audio_lab.hide_lab()
		return
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT,JOY_AXIS_TRIGGER_RIGHT]:
			var action := "gas" if event.axis==JOY_AXIS_TRIGGER_RIGHT else "brake"
			g.controls.joy[action]=clampf((event.axis_value-.05)/.95,0,1) if g.screen=="race" and not g.paused_race else 0.0
		elif event.axis in [JOY_AXIS_LEFT_X,JOY_AXIS_LEFT_Y]:
			var next := direction
			var value := signf(event.axis_value) if absf(event.axis_value)>.55 else 0.0
			if event.axis==JOY_AXIS_LEFT_X: next.x=value
			else: next.y=value
			set_direction(g,next)
		return
	var button: int=event.button_index
	var was_held: bool=held_buttons.has(button)
	if event.pressed: held_buttons[button]=true
	else: held_buttons.erase(button)
	if HOLDS.has(button):
		g.controls.joy[HOLDS[button]]=1.0 if event.pressed and g.screen=="race" and not g.paused_race else 0.0
	if button in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:
		var next := Vector2(float(held_buttons.has(JOY_BUTTON_DPAD_RIGHT))-float(held_buttons.has(JOY_BUTTON_DPAD_LEFT)),float(held_buttons.has(JOY_BUTTON_DPAD_DOWN))-float(held_buttons.has(JOY_BUTTON_DPAD_UP)))
		set_direction(g,next); return
	if not event.pressed or was_held: return
	if button==JOY_BUTTON_START:
		if g.screen=="race": g.set_race_paused(not g.paused_race)
		return
	if g.screen=="race" and not g.paused_race:
		if button in [JOY_BUTTON_B,JOY_BUTTON_X]:
			var step := 1 if button==JOY_BUTTON_B else -1
			if g.car.control_mode=="hpattern": g.manual_gear(clampi(g.car.gear+step,0,g.car.gear_ratios.size()))
			else: g.paddle(step)
		elif button==JOY_BUTTON_Y and g.car.control_mode=="hpattern": g.manual_gear(0)
		return
	if button==JOY_BUTTON_A: activate(g)
	elif button==JOY_BUTTON_B or button==JOY_BUTTON_BACK:
		var back := InputEventKey.new(); back.keycode=KEY_ESCAPE; back.pressed=true
		g.handle_key_input(back)

func set_direction(g: Node2D,next: Vector2) -> void:
	if next==direction: return
	direction=next; repeat_left=.38
	if direction!=Vector2.ZERO: navigate(g,direction)

func tick(g: Node2D,dt: float) -> void:
	if not active or direction==Vector2.ZERO: return
	repeat_left-=dt
	if repeat_left<=0:
		repeat_left=.13; navigate(g,direction)

func collect_controls(node: Node,result: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control and not child.is_visible_in_tree(): continue
		if child is Button and not child.disabled and child.focus_mode!=Control.FOCUS_NONE: result.append(child)
		elif child is HSlider and child.editable: result.append(child)
		collect_controls(child,result)

func targets(g: Node2D) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for item in g.buttons:
		if item.get("disabled",false): continue
		var button: Control=item.get("native_control")
		if is_instance_valid(button) and button is Button and button.disabled: continue
		result.append(item)
	var native: Array[Control]=[]
	collect_controls(g,native)
	for control in native:
		if result.any(func(item): return item.get("native_control")==control): continue
		var rect := Rect2(g.to_local(control.global_position),control.size)
		result.append({"id":"joy_"+str(control.get_instance_id()),"rect":rect,"native_control":control})
	return result

func navigate(g: Node2D,axis: Vector2) -> void:
	if g.screen=="race" and not g.paused_race: return
	var items := targets(g)
	if items.is_empty(): return
	var index := -1
	for i in items.size():
		if items[i].id==g.glass.focused: index=i; break
	if index>=0 and items[index].get("native_control") is HSlider and axis.x!=0:
		var slider := items[index].native_control as HSlider
		if slider.editable: slider.value+=axis.x*slider.step
		return
	var best := 0 if index<0 else index
	if index>=0:
		var origin: Vector2=items[index].rect.get_center()
		var score := INF
		var heading := Vector2(signf(axis.x),0) if axis.x!=0 else Vector2(0,signf(axis.y))
		for i in items.size():
			var offset: Vector2=items[i].rect.get_center()-origin
			var forward := offset.dot(heading)
			if forward<1: continue
			var sideways := absf(offset.cross(heading))
			var cost := forward+sideways*3.0
			if cost<score: score=cost; best=i
	var item: Dictionary=items[best]
	focus_item(g,item)

func focus_item(g: Node2D,item: Dictionary) -> void:
	g.glass.focused=item.id; focus_control=item.get("native_control")
	if is_instance_valid(focus_control):
		if focus_control.focus_mode!=Control.FOCUS_NONE: focus_control.grab_focus()
		var ancestor := focus_control.get_parent()
		while ancestor!=null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(focus_control)
			ancestor=ancestor.get_parent()
	g.menu_dirty=true

func activate(g: Node2D) -> void:
	var items := targets(g)
	if items.is_empty(): return
	for item in items:
		if item.id!=g.glass.focused: continue
		g.glass.press(item.id)
		var control: Control=item.get("native_control")
		if control is Button: control.pressed.emit()
		elif control is HSlider: return
		else: g.action(item.id)
		return
	# First press establishes visible focus, preventing accidental purchases.
	focus_item(g,items[0])
