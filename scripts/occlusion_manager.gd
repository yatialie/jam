extends Node

## 统一的 2.5D 遮挡管理：
## 1) 按脚底 Y 给角色、敌人和可遮挡物件排序，保证前后关系正确；
## 2) 把角色/敌人位置同步给物件材质，让物件在目标所在处开出圆形透明窗。

const REVEAL_SHADER := preload("res://shaders/occluder_reveal.gdshader")
const MAX_REVEALS := 16
const Z_SCALE := 3.0

const PLAYER_CENTER_LIFT := -78.0
const PLAYER_REVEAL_RADIUS := 92.0
const ENEMY_CENTER_LIFT := -16.0
const ENEMY_REVEAL_RADIUS := 38.0
const REVEAL_SOFTNESS := 10.0
const REVEAL_ALPHA := 0.08
const OCCLUDER_GROUP := &"occluders"
const NO_REVEAL_POS := Vector2(-100000.0, -100000.0)


func register_occluder(sprite: Sprite2D, base: Vector2) -> void:
	var base_y := _canvas_y(sprite, base)
	var material := ShaderMaterial.new()
	material.shader = REVEAL_SHADER
	material.set_shader_parameter("reveal_softness", REVEAL_SOFTNESS)
	material.set_shader_parameter("reveal_alpha", REVEAL_ALPHA)
	material.set_shader_parameter("prop_z", base_y)
	material.set_shader_parameter("reveals", _empty_reveals())

	sprite.material = material
	sprite.z_as_relative = false
	sprite.z_index = _z_from_y(base_y)
	sprite.add_to_group(OCCLUDER_GROUP)


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var feet := player.global_position
	_apply_depth(player, feet.y)

	var reveals := _empty_reveals()
	var slot := 0
	reveals[slot] = Vector4(
		feet.x,
		feet.y + PLAYER_CENTER_LIFT,
		feet.y,
		PLAYER_REVEAL_RADIUS
	)
	slot += 1

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node2D
		if enemy == null:
			continue
		var enemy_feet := enemy.global_position
		_apply_depth(enemy, enemy_feet.y)
		if slot >= MAX_REVEALS:
			continue
		reveals[slot] = Vector4(
			enemy_feet.x,
			enemy_feet.y + ENEMY_CENTER_LIFT,
			enemy_feet.y,
			ENEMY_REVEAL_RADIUS
		)
		slot += 1

	for node in get_tree().get_nodes_in_group(OCCLUDER_GROUP):
		var sprite := node as Sprite2D
		if sprite == null:
			continue
		var material := sprite.material as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("reveals", reveals)


func _empty_reveals() -> PackedVector4Array:
	var reveals := PackedVector4Array()
	reveals.resize(MAX_REVEALS)
	reveals.fill(Vector4(NO_REVEAL_POS.x, NO_REVEAL_POS.y, -100000.0, 0.0))
	return reveals


func _apply_depth(item: Node2D, y: float) -> void:
	item.z_as_relative = false
	item.z_index = _z_from_y(y)


func _canvas_y(sprite: Node2D, base: Vector2) -> float:
	var parent := sprite.get_parent() as Node2D
	if parent == null:
		return base.y
	return (parent.get_global_transform() * base).y


func _z_from_y(y: float) -> int:
	return clampi(int(round(y * Z_SCALE)), -4096, 4096)
