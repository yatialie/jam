extends Node2D

signal hit_registered

const RESPAWN_TIME := 1.0
const OUTER_RADIUS := 28.0

@export var max_hp := 3

var hp := max_hp
var _tween: Tween


func _draw() -> void:
	draw_circle(Vector2(0, 4), OUTER_RADIUS + 4.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, OUTER_RADIUS, Color(0.82, 0.32, 0.2))
	draw_arc(Vector2.ZERO, OUTER_RADIUS, 0, TAU, 32, Color(0.2, 0.09, 0.06), 2.5)
	draw_circle(Vector2.ZERO, 18.0, Color(0.95, 0.72, 0.45))
	draw_arc(Vector2.ZERO, 18.0, 0, TAU, 24, Color(0.2, 0.09, 0.06), 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color(0.82, 0.32, 0.2))
	for i in 4:
		var dir := Vector2.UP.rotated(TAU * float(i) / 4.0)
		draw_line(dir * 20.0, dir * 27.0, Color(0.2, 0.09, 0.06), 2.0)


func hit(_direction: Vector2) -> void:
	hp -= 1
	hit_registered.emit()
	if _tween and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE * 1.3
	modulate = Color(1.8, 1.8, 1.8, 1.0)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.16)
	if hp <= 0:
		hp = max_hp
		visible = false
		get_tree().create_timer(RESPAWN_TIME).timeout.connect(_respawn)


func _respawn() -> void:
	visible = true
