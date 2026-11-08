extends Node2D

## 第三关右上角的红色抛弃按钮。
## 视觉直接使用背景图上的红按钮，这里只保留受击判定、血量和破碎时的瞬时碎屑反馈。

signal destroyed

@export var max_hp := 8
@export var hurt_radius := 46.0

var hp := 0
var _broken := false
var _hurtbox: Area2D


func _ready() -> void:
	hp = max_hp
	add_to_group("waste_button")
	_build_hurtbox()


func _build_hurtbox() -> void:
	_hurtbox = Area2D.new()
	_hurtbox.name = "HurtBox"
	_hurtbox.collision_layer = 2
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = false
	_hurtbox.monitorable = true

	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = hurt_radius
	collider.shape = shape
	_hurtbox.add_child(collider)
	add_child(_hurtbox)


func hit(_direction: Vector2) -> void:
	if _broken:
		return
	hp = maxi(hp - 1, 0)
	if hp <= 0:
		_break()


func is_broken() -> bool:
	return _broken


func _break() -> void:
	if _broken:
		return
	_broken = true
	if _hurtbox:
		_hurtbox.set_deferred("monitorable", false)
		for child in _hurtbox.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	_spawn_debris()
	destroyed.emit()


## 破碎时只给一圈短命碎屑，不留下常驻模型，背景图上的红按钮保持原样。
func _spawn_debris() -> void:
	var parent := get_parent()
	if parent == null:
		return

	for i in 10:
		var shard := Polygon2D.new()
		var size := randf_range(4.0, 11.0)
		shard.polygon = PackedVector2Array([
			Vector2(-size, -size * 0.5),
			Vector2(size * 0.6, -size),
			Vector2(size, size * 0.4),
			Vector2(-size * 0.4, size),
		])
		var color := Color(0.85, 0.2, 0.14)
		if i % 3 == 1:
			color = Color(0.95, 0.7, 0.18)
		elif i % 3 == 2:
			color = Color(0.2, 0.16, 0.12)
		shard.color = color
		shard.position = position + Vector2(randf_range(-22.0, 22.0), randf_range(-22.0, 22.0))
		shard.rotation = randf() * TAU
		shard.z_index = 13
		parent.add_child(shard)

		var velocity := Vector2(randf_range(-120.0, 120.0), randf_range(-160.0, -40.0))
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position", shard.position + velocity * 0.5 + Vector2(0, 90), 0.5)
		tween.tween_property(shard, "rotation", shard.rotation + randf_range(-5.0, 5.0), 0.5)
		tween.tween_property(shard, "modulate:a", 0.0, 0.5).set_delay(0.12)
		tween.chain().tween_callback(shard.queue_free)
