extends Node2D

## Wall-mounted calendar. The node itself sits at the interaction point in
## front of the wall; the art is lifted up so it reads as wall-mounted.

signal clue_read

const TILT := 0.72
const TEXTURE := preload("res://art_placeholder/scifi_ship_v2/cockpit/props/calendar_wall.png")
const LIGHT := preload("res://art_placeholder/scifi_ship_v2/vfx/light_pool_amber.png")
const USE_DISTANCE := 190.0
const VISUAL_HEIGHT := 150.0
const WALL_LIFT := 260.0

@export var managed := false

var _player: CharacterBody2D
var _prompt: Label
var _glow: Sprite2D
var _sprite: Sprite2D
var _read := false
var _highlighted := false


func _ready() -> void:
	add_to_group("calendar_prop")
	add_to_group("interactable")
	_build_visual()
	if managed:
		set_process(false)
	else:
		_build_prompt()


func set_highlight(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	if _sprite:
		_sprite.modulate = Color(1.0, 0.98, 0.92, 1.0) if on else Color(0.82, 0.8, 0.74, 1.0)
	if _glow:
		_glow.modulate.a = 0.42 if on else 0.20


func open_calendar() -> void:
	_open()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player == null:
			return

	var modal := get_tree().get_first_node_in_group("modal") != null
	var near := _player.global_position.distance_to(global_position) < USE_DISTANCE
	_prompt.visible = near and not modal
	_prompt.text = "F  RE-READ CALENDAR" if _read else "F  CHECK CALENDAR"

	if near and not modal and Input.is_action_just_pressed("interact"):
		_open()


func _open() -> void:
	var ui := get_tree().get_first_node_in_group("clue_ui")
	if ui and ui.has_method("open"):
		ui.call("open")
	if not _read:
		_read = true
		clue_read.emit()


func _build_visual() -> void:
	var local_height := VISUAL_HEIGHT / TILT
	var width := VISUAL_HEIGHT * (float(TEXTURE.get_width()) / float(TEXTURE.get_height()))

	_glow = Sprite2D.new()
	_glow.texture = LIGHT
	_glow.position = Vector2(0, -WALL_LIFT - local_height * 0.52)
	_glow.scale = Vector2(2.1, 2.1)
	_glow.modulate = Color(1, 1, 1, 0.20)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = material
	_glow.z_index = -1
	add_child(_glow)

	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.centered = true
	_sprite.scale = Vector2(width / TEXTURE.get_width(), local_height / TEXTURE.get_height())
	_sprite.position = Vector2(0, -WALL_LIFT - local_height / 2.0)
	_sprite.modulate = Color(0.82, 0.8, 0.74, 1.0)
	_sprite.z_index = 1
	add_child(_sprite)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = Label.new()
	_prompt.size = Vector2(500, 40)
	_prompt.position = Vector2(710, 940)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 0.82, 0.35, 1))
	_prompt.visible = false
	layer.add_child(_prompt)
