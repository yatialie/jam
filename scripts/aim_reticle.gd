extends Node2D

const CROSSHAIR_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/vfx/crosshair.png")
const TILT := 0.72
const BASE_SCALE := 0.45

var _sprite: Sprite2D
var _line: Line2D
var _phase := 0.0


func _ready() -> void:
	# 瞄准准星属于界面提示，需要始终盖在场景物件之上。
	z_index = 4080

	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.42, 0.95, 1.0, 0.18)
	var line_material := CanvasItemMaterial.new()
	line_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_line.material = line_material
	add_child(_line)

	_sprite = Sprite2D.new()
	_sprite.texture = CROSSHAIR_TEXTURE
	_sprite.modulate = Color(0.7, 1.0, 1.0, 0.95)
	_sprite.scale = Vector2(BASE_SCALE, BASE_SCALE / TILT)
	add_child(_sprite)


func _process(delta: float) -> void:
	if not visible or _sprite == null:
		return
	_phase += delta
	var pulse := 1.0 + sin(_phase * 3.2) * 0.025
	_sprite.rotation = sin(_phase * 2.0) * 0.025
	_sprite.scale = Vector2(BASE_SCALE, BASE_SCALE / TILT) * pulse


func update_aim(mouse_position: Vector2, muzzle_position: Vector2) -> void:
	position = mouse_position
	if _line == null:
		return
	_line.points = PackedVector2Array([muzzle_position - mouse_position, Vector2.ZERO])
