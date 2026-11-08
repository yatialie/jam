extends Node2D

signal destroyed

const OUTER_RADIUS := 32.0
const HEX_RADIUS := 22.0

@export var max_hp := 3

var hp := 0

var _phase := 0.0
var _flash := 0.0
var _dead := false


func _ready() -> void:
	hp = max_hp
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func hit(direction: Vector2, amount: int = 1) -> void:
	if _dead:
		return
	hp -= maxi(amount, 1)
	_flash = 0.12
	if hp <= 0:
		_destroy()
		return
	if direction.length() > 0.01:
		position += direction.normalized() * 4.0


func _destroy() -> void:
	if _dead:
		return
	_dead = true
	destroyed.emit()

	var hurtbox := $HurtBox as Area2D
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE * 1.8, 0.3)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_phase * 2.2)
	var lift := sin(_phase * 1.7) * 2.0

	draw_circle(Vector2(0, 4), OUTER_RADIUS + 6.0, Color(0, 0, 0, 0.2))
	draw_arc(Vector2(0, lift), OUTER_RADIUS + 4.0, _phase * 0.9, _phase * 0.9 + TAU * 0.7, 24, Color(0.3, 0.9, 1.0, 0.25 + pulse * 0.2), 2.5)
	draw_arc(Vector2(0, lift), OUTER_RADIUS - 2.0, -_phase * 1.3, -_phase * 1.3 + TAU * 0.45, 20, Color(0.45, 1.0, 0.85, 0.2 + pulse * 0.15), 2.0)

	var hex := PackedVector2Array()
	for i in 6:
		var angle := TAU * float(i) / 6.0 + PI / 6.0
		hex.append(Vector2(cos(angle), sin(angle)) * HEX_RADIUS + Vector2(0, lift))

	var body_color := Color(0.16, 0.45, 0.55)
	var core_color := Color(0.6, 1.0, 0.95)
	if _flash > 0.0:
		body_color = body_color.lerp(Color.WHITE, 0.75)
		core_color = Color.WHITE
	draw_colored_polygon(hex, body_color)
	var closed := hex.duplicate()
	closed.append(hex[0])
	draw_polyline(closed, Color(0.5, 0.95, 1.0, 0.8), 2.0)
	draw_circle(Vector2(0, lift), 8.0, core_color)
	draw_circle(Vector2(0, lift), 3.5, Color.WHITE)

	for i in max_hp:
		var filled := i < hp
		var pips := Color(0.4, 1.0, 0.75, 0.95) if filled else Color(0.18, 0.3, 0.32, 0.85)
		draw_rect(Rect2(Vector2(-25.0 + i * 17.0, -52.0), Vector2(13.0, 4.0)), pips)
