extends Node2D
## REDLINE motorcycle sprite prototype — uses a shared body canvas and anchor profile.
## Attach to Node2D. Place the PNG files and anchors.json in the same folder.
@export_enum("clean_generated_body", "original_reference_body") var anchor_profile: String = "clean_generated_body"
@export var speed_mps: float = 0.0
@export var rear_wheelspin_ratio: float = 1.0
@export var wheel_radius_m: float = 0.30
@export var show_wheels: bool = true

const ASSET_ROOT := "res://assets/vehicles/motorcycle_template/"
var _body: Texture2D
var _rear: Texture2D
var _front: Texture2D
var _rear_center := Vector2.ZERO
var _front_center := Vector2.ZERO
var _rear_radius := 97.5
var _front_radius := 97.5
var rear_angle: float = 0.0
var front_angle: float = 0.0

func _ready() -> void:
    var config = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + "anchors.json"))
    if not config is Dictionary: push_error("Invalid motorcycle anchors.json"); return
    var profiles: Dictionary = config.get("profiles", {})
    if not profiles.has(anchor_profile): push_error("Unknown motorcycle anchor profile: " + anchor_profile); return
    var data: Dictionary = profiles[anchor_profile]
    _body = load(ASSET_ROOT + str(data.body))
    _rear = load(ASSET_ROOT + str(data.rear.sprite))
    _front = load(ASSET_ROOT + str(data.front.sprite))
    _rear_center = Vector2(float(data.rear.center[0]), float(data.rear.center[1]))
    _front_center = Vector2(float(data.front.center[0]), float(data.front.center[1]))
    _rear_radius = float(data.rear.nominal_radius_px)
    _front_radius = float(data.front.nominal_radius_px)
    queue_redraw()

func _process(delta: float) -> void:
    var omega := speed_mps / maxf(wheel_radius_m, 0.01)
    front_angle = wrapf(front_angle + omega * delta, -PI, PI)
    rear_angle = wrapf(rear_angle + omega * rear_wheelspin_ratio * delta, -PI, PI)
    queue_redraw()

func _draw() -> void:
    # Render any customized tires/rims first, then the stationary body hardware.
    if show_wheels:
        draw_custom_wheel(_rear, _rear_center, _rear_radius, rear_angle)
        draw_custom_wheel(_front, _front_center, _front_radius, front_angle)
    if _body != null: draw_texture(_body, Vector2.ZERO)

func draw_custom_wheel(texture: Texture2D, center: Vector2, radius_px: float, angle: float) -> void:
    if texture == null: return
    var diameter := radius_px * 2.0
    draw_set_transform(center, angle)
    draw_texture_rect(texture, Rect2(Vector2(-radius_px, -radius_px), Vector2(diameter, diameter)), false)
    draw_set_transform(Vector2.ZERO)
