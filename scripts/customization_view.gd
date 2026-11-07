class_name CustomizationView
extends RefCounted

var g: Node2D
var category := "paint"
var candidate: Dictionary = {}
var vehicle_id := ""
var compare := false
var camera_pose := Vector2(0,1)
var focus_override := -1
var zoom_step := 0
var trim_open := false
const GROUPS := {"paint":["paint","finish","stance","spoiler","headlight","taillight"],"wheels":["design","rim"],"calipers":["caliper"],"tint":["tint"]}
const GROUP_LABELS := {"paint":"Paint","wheels":"Wheels","calipers":"Calipers","tint":"Tint"}
const TRIM := ["stance","spoiler","headlight","taillight"]

func _init(game: Node2D) -> void: g = game
func open() -> void:
	vehicle_id = g.profile.vehicle_id; candidate = g.profile.appearance_for(vehicle_id); compare = false
	var supported: Array = VehicleAppearance.definition(vehicle_id).compatible
	if not supported.has(category): category = str(supported[0]) if not supported.is_empty() else "paint"
	camera_pose=Vector2(0,1); focus_override=-1; zoom_step=0
	trim_open=category in TRIM
	g.tab = "style"
	g.sync_menu_size()

func has_preview() -> bool:
	return not candidate.is_empty() and candidate!=g.profile.appearance_for(g.profile.vehicle_id)

func primary() -> String:
	for key in GROUPS:
		if category in GROUPS[key]: return key
	return "paint"

func camera_target() -> Vector2:
	var wheel := primary() in ["wheels","calipers"] if focus_override<0 else focus_override==1
	return Vector2(1 if wheel else 0,1.0+zoom_step*.16)

func action(id: String) -> bool:
	if id in ["hub_customize","tab_style"]: open()
	elif id=="custom_back":
		g.tab="garage"; candidate.clear(); compare=false; g.sync_menu_size()
	elif id.begins_with("custom_group_"):
		var key:=id.trim_prefix("custom_group_")
		if GROUPS.has(key) and primary()!=key:
			for option in GROUPS[key]:
				if VehicleAppearance.definition(vehicle_id).compatible.has(option):
					category=option
					break
			focus_override=-1
			zoom_step=0
			trim_open=false
	elif id.begins_with("custom_category_"):
		var key:=id.trim_prefix("custom_category_")
		if VehicleAppearance.definition(vehicle_id).compatible.has(key):
			if primary() in ["wheels","calipers"] and key not in ["design","rim","caliper"]: focus_override=-1
			category=key
			trim_open=key in TRIM
			compare=false
	elif id=="custom_trim":
		trim_open=not trim_open
		if not trim_open and category in TRIM: category="paint"
	elif id.begins_with("custom_pick_"):
		var index:=int(id.trim_prefix("custom_pick_"))
		if VehicleAppearance.compatible(vehicle_id,category,index):
			candidate[category]=index
			compare=false
	elif id=="custom_camera":
		focus_override=0 if camera_target().x>0.5 else 1
		zoom_step=0
	elif id=="custom_zoom_in": zoom_step=mini(2,zoom_step+1)
	elif id=="custom_zoom_out": zoom_step=maxi(-1,zoom_step-1)
	elif id=="custom_compare": compare=not compare
	elif id=="custom_discard": candidate=g.profile.appearance_for(vehicle_id); compare=false
	elif id=="custom_install":
		var message: String=g.profile.install_appearance(category,int(candidate[category]))
		g.show_toast(message,message.begins_with("Installed "))
		if message.begins_with("Installed "): candidate[category]=g.profile.appearance_for(vehicle_id)[category]
		compare=false
	elif id=="custom_reset":
		g.profile.restore_appearance()
		candidate=g.profile.appearance_for(vehicle_id)
		compare=false
	else: return false
	g.menu_dirty=true
	return true
