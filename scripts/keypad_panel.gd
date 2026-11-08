extends Node2D

## Wall keypad beside the cockpit door. Opens the keypad UI while the door
## is still locked.

const TILT := 0.72
const TEXTURE := preload("res://art_placeholder/scifi_ship_v2/cockpit/props/cockpit_keypad.png")
const GLOW_AMBER := preload("res://art_placeholder/scifi_ship_v2/vfx/light_pool_amber.png")
const GLOW_CYAN := preload("res://art_placeholder/scifi_ship_v2/vfx/light_pool_cyan.png")
const USE_DISTANCE := 170.0
const VISUAL_HEIGHT := 140.0

var _player: CharacterBody2D
var _door: Node
var _prompt: Label
var _glow: Sprite2D
var _time := 0.0
var _unlocked := false


func set_unlocked(value: bool) -> void:
	_unlocked = value


func _ready() -> void:
	add_to_group("keypad_prop")
	add_to_group("interactable")
	_build_visual()
	_build_prompt()


func _process(delta: float) -> void:
	_time += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		if _player == null:
			return
	if _door == null or not is_instance_valid(_door):
		_door = get_tree().get_first_node_in_group("main_door")
		if _door == null:
			_door = get_tree().get_first_node_in_group("access_door")

	var locked := not _unlocked
	if not _unlocked and _door and _door.has_method("is_locked"):
		locked = _door.call("is_locked")

	var modal := get_tree().get_first_node_in_group("modal") != null
	var near := _player.global_position.distance_to(global_position) < USE_DISTANCE
	_prompt.visible = near and locked and not modal
	_update_glow(locked)

	if near and locked and not modal and Input.is_action_just_pressed("interact"):
		var ui := get_tree().get_first_node_in_group("keypad_ui")
		if ui and ui.has_method("open"):
			ui.call("open")


func _update_glow(locked: bool) -> void:
	if _glow == null:
		return
	_glow.texture = GLOW_AMBER if locked else GLOW_CYAN
	var pulse := 0.18 + sin(_time * 2.4) * 0.04
	_glow.modulate = Color(1, 1, 1, pulse if locked else 0.16)


func _build_visual() -> void:
	var local_height := VISUAL_HEIGHT / TILT
	var width := VISUAL_HEIGHT * (float(TEXTURE.get_width()) / float(TEXTURE.get_height()))

	_glow = Sprite2D.new()
	_glow.texture = GLOW_AMBER
	_glow.position = Vector2(0, -local_height * 0.55)
	_glow.scale = Vector2(1.5, 1.5)
	_glow.modulate = Color(1, 1, 1, 0.18)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = material
	_glow.z_index = -1
	add_child(_glow)

	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.centered = true
	sprite.scale = Vector2(width / TEXTURE.get_width(), local_height / TEXTURE.get_height())
	sprite.position = Vector2(0, -local_height / 2.0)
	sprite.z_index = 1
	add_child(sprite)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = Label.new()
	_prompt.text = "F  ENTER ACCESS CODE"
	_prompt.size = Vector2(500, 40)
	_prompt.position = Vector2(710, 980)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1))
	_prompt.visible = false
	layer.add_child(_prompt)
