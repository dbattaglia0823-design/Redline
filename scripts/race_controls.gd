class_name RaceControls
extends RefCounted

const HOLD_ACTIONS: Array[String] = ["gas", "brake", "clutch", "nitrous", "transbrake"]
const KEY_ACTIONS := {
	KEY_W: "gas", KEY_UP: "gas",
	KEY_S: "brake", KEY_DOWN: "brake",
	KEY_SHIFT: "clutch", KEY_SPACE: "nitrous", KEY_B: "transbrake",
}
var keys: Dictionary = {}
var pointers: Dictionary = {}
var joy: Dictionary = {}

static func key_code(event: InputEventKey) -> Key:
	# Virtual/remote Windows keyboards may report an unrelated scan code.
	var physical := event.physical_keycode
	if (physical >= KEY_0 and physical <= KEY_9) or physical == KEY_N or KEY_ACTIONS.has(physical) or physical in [KEY_Q,KEY_E,KEY_LEFT,KEY_RIGHT,KEY_P,KEY_ESCAPE,KEY_R,KEY_ENTER,KEY_M,KEY_F3,KEY_F4,KEY_F6,KEY_F7,KEY_TAB]:
		return physical
	return event.keycode

func handle_key(event: InputEventKey) -> void:
	var code := key_code(event)
	if event.pressed:
		keys[code] = true
	else:
		keys.erase(code)

func hold(pointer: String, action: String) -> void:
	if HOLD_ACTIONS.has(action): pointers[pointer] = action

func release(pointer: String) -> void:
	pointers.erase(pointer)

func value(action: String) -> float:
	if pointers.values().has(action): return 1.0
	for code in keys:
		if KEY_ACTIONS.get(code, "") == action: return 1.0
	return float(joy.get(action,0.0))

func clear() -> void:
	keys.clear()
	pointers.clear()
	joy.clear()

