extends Area2D

signal hit_target

const SPEED := 1500.0
const LIFETIME := 1.1
const IMPACT_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/vfx/impact_spark.png")

var direction := Vector2.RIGHT
var _life := 0.0
var _dead := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	_life += delta
	if _life >= LIFETIME:
		queue_free()


func _on_body_entered(_body: Node2D) -> void:
	_impact()


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target and target.has_method("hit"):
		target.hit(direction)
		hit_target.emit()
	_impact()


func _impact() -> void:
	if _dead:
		return
	_dead = true

	var flash := Sprite2D.new()
	flash.texture = IMPACT_TEXTURE
	flash.hframes = 5
	flash.frame = 0
	flash.z_index = 14
	flash.scale = Vector2(0.9, 0.9 / 0.72)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = material
	get_parent().add_child(flash)
	flash.position = position

	var tween := flash.create_tween()
	tween.tween_method(_set_frame.bind(flash), 0.0, 4.0, 0.2)
	tween.tween_callback(flash.queue_free)

	queue_free()


func _set_frame(value: float, flash: Sprite2D) -> void:
	flash.frame = int(value)
