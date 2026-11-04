class_name GlassPalette
extends Resource

const BG := Color("030a10")
const SURFACE := Color("091c29f2")
const EDGE := Color("48c5ff66")
const BLUE := Color("48c5ff")
const INK := Color("f3f5f7")
const MUTED := Color("a4afbf")
const ORANGE := Color("ff8755")
const GREEN := Color("91c9ad")
@export var background := BG
@export var surface := SURFACE
@export var raised := Color("123348f5")
@export var edge := EDGE
@export var ink := INK
@export var muted := MUTED
@export var orange := ORANGE
@export var green := GREEN
@export var primary := Color("75351d")
@export var selected := Color("34251bf5")
@export var disabled := Color("171e28cc")
@export var modal_surface := Color("071722fc")
@export var shadow := Color(0,0,0,.22)
@export var shadow_size := 7
@export_range(12,32,1) var radius := 12
@export_range(.06,.24,.01) var motion_seconds := .14
@export_range(1.0,3.0,.25) var backdrop_blur := 2.0
