extends Node2D

const CREAM := Color(0.96, 0.94, 0.87)
const CREAM_SHADE := Color(0.85, 0.82, 0.72)
const OUTLINE := Color(0.13, 0.16, 0.2)
const BEAK := Color(0.98, 0.65, 0.2)
const BEAK_DARK := Color(0.8, 0.46, 0.12)

var facing := Vector2.DOWN
var _phase := 0.0


func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody2D
	var speed := body.velocity.length() if body else 0.0
	var speed_ratio := clampf(speed / 430.0, 0.0, 1.0)
	_phase += delta * (6.0 + 8.0 * speed_ratio)
	var target_sign := -1.0 if facing.x < -0.1 else 1.0
	if signf(scale.x) != target_sign:
		scale.x = absf(scale.x) * target_sign
	queue_redraw()


func _draw() -> void:
	var body := get_parent() as CharacterBody2D
	var speed := body.velocity.length() if body else 0.0
	var speed_ratio := clampf(speed / 430.0, 0.0, 1.0)
	var moving := speed > 1.0
	var phase := sin(_phase)
	var bob := absf(phase) * (2.0 + 2.0 * speed_ratio) if moving else 0.0
	var step := phase * (3.0 + 2.0 * speed_ratio) if moving else 0.0
	var back := facing.y < -0.6

	# 腿与脚（脚掌踩在地面点上）
	draw_line(Vector2(-12 + step, -20), Vector2(-13 + step, -5), BEAK, 7.0)
	draw_line(Vector2(12 - step, -20), Vector2(13 - step, -5), BEAK, 7.0)
	_ellipse(Vector2(-13 + step, -3), Vector2(9, 5), BEAK_DARK)
	_ellipse(Vector2(13 - step, -3), Vector2(9, 5), BEAK_DARK)

	# 尾羽（背面时从身体下缘露出）
	if back:
		var tail := PackedVector2Array([Vector2(-14, -34 - bob), Vector2(14, -34 - bob), Vector2(0, -8 - bob)])
		draw_colored_polygon(tail, CREAM_SHADE)
		draw_polyline(_closed(tail), OUTLINE, 2.5)

	# 身体
	_ellipse(Vector2(0, -46 - bob), Vector2(28, 32), CREAM)

	# 翅膀
	_ellipse(Vector2(-26, -52 - bob), Vector2(9, 17), CREAM_SHADE)
	_ellipse(Vector2(26, -52 - bob), Vector2(9, 17), CREAM_SHADE)

	# 头部
	draw_circle(Vector2(0, -86 - bob), 22.0, CREAM)
	draw_arc(Vector2(0, -86 - bob), 22.0, 0, TAU, 32, OUTLINE, 2.5)

	if back:
		draw_arc(Vector2(0, -86 - bob), 12.0, PI * 0.15, PI * 1.85, 18, CREAM_SHADE, 2.0)
	else:
		draw_circle(Vector2(-8, -92 - bob), 4.0, OUTLINE)
		draw_circle(Vector2(8, -92 - bob), 4.0, OUTLINE)
		draw_circle(Vector2(-9, -93 - bob), 1.4, Color.WHITE)
		draw_circle(Vector2(7, -93 - bob), 1.4, Color.WHITE)

		var beak := PackedVector2Array([Vector2(-8, -82 - bob), Vector2(8, -82 - bob), Vector2(0, -67 - bob)])
		draw_colored_polygon(beak, BEAK)
		draw_polyline(_closed(beak), OUTLINE, 2.5)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
	draw_polyline(_closed(pts), OUTLINE, 2.5)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
