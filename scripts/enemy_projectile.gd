extends Area2D

signal hit_player

const LIFETIME := 2.6

var direction := Vector2.RIGHT
var speed := 380.0
## 弹体与命中闪光的基础色，可由发射者覆盖（默认保持原有品红色）。
var tint := Color(1.0, 0.35, 0.7, 1.0)

var _life := 0.0
var _dead := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()
	var visual := get_node_or_null("Visual")
	if visual is Polygon2D:
		(visual as Polygon2D).color = tint


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life += delta
	if _life >= LIFETIME:
		queue_free()


func _on_body_entered(_body) -> void:
	_impact()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(1, direction)
		hit_player.emit()
	_impact()


func _impact() -> void:
	if _dead:
		return
	_dead = true

	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([Vector2(0, -14), Vector2(9, -9), Vector2(14, 0), Vector2(9, 9), Vector2(0, 14), Vector2(-9, 9), Vector2(-14, 0), Vector2(-9, -9)])
	flash.color = Color(tint.r, tint.g, tint.b, 0.85)
	flash.z_index = 14
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = material
	get_parent().add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.12).timeout.connect(flash.queue_free)

	queue_free()
