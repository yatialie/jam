extends Node2D

## 第三关底部的黑色垃圾抛弃口。open() 打开双门，close() 关闭，consume() 播放吸入闪光。

signal opened

var _open_amount := 0.0
var _phase := 0.0
var _consume_flash := 0.0
var _tween: Tween


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	_consume_flash = maxf(_consume_flash - delta, 0.0)
	if _open_amount > 0.001 or _consume_flash > 0.001:
		queue_redraw()


func open() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_open, _open_amount, 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opened.emit()


func close() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_open, _open_amount, 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func consume() -> void:
	_consume_flash = 0.28
	queue_redraw()


func is_open() -> bool:
	return _open_amount > 0.05


func _set_open(value: float) -> void:
	_open_amount = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	# 地面阴影与凹陷
	_ellipse(Vector2(0, 6), Vector2(216, 34), Color(0, 0, 0, 0.3))
	var recess := PackedVector2Array([
		Vector2(-190, 0),
		Vector2(190, 0),
		Vector2(150, -170),
		Vector2(-150, -170),
	])
	draw_colored_polygon(recess, Color(0.012, 0.014, 0.018))
	draw_polyline(_closed(recess), Color(0.16, 0.12, 0.09), 4.0)

	# 顶部危险条纹
	for i in 7:
		var x := -150.0 + i * 48.0
		draw_line(Vector2(x, -170), Vector2(x + 22, -152), Color(0.9, 0.68, 0.14, 0.75), 4.0)
	draw_line(Vector2(-190, 0), Vector2(190, 0), Color(0.3, 0.24, 0.12), 5.0)

	# 双门
	var slide := _open_amount * 124.0
	var lift := _open_amount * 12.0
	var left_door := PackedVector2Array([
		Vector2(-190, 0),
		Vector2(0, 0),
		Vector2(-12, -170),
		Vector2(-150, -170),
	])
	var right_door := PackedVector2Array([
		Vector2(190, 0),
		Vector2(0, 0),
		Vector2(12, -170),
		Vector2(150, -170),
	])
	var left := _offset_points(left_door, Vector2(-slide, -lift))
	var right := _offset_points(right_door, Vector2(slide, -lift))
	draw_colored_polygon(left, Color(0.2, 0.22, 0.25))
	draw_polyline(_closed(left), Color(0.07, 0.08, 0.09), 3.0)
	draw_colored_polygon(right, Color(0.2, 0.22, 0.25))
	draw_polyline(_closed(right), Color(0.07, 0.08, 0.09), 3.0)

	# 门上的黄色斜纹
	for i in 3:
		var left_x := -150.0 + i * 48.0 - slide
		draw_line(Vector2(left_x, -6), Vector2(left_x + 18, -30), Color(0.95, 0.7, 0.16, 0.7), 3.0)
		var right_x := 48.0 + i * 48.0 + slide
		draw_line(Vector2(right_x, -6), Vector2(right_x + 18, -30), Color(0.95, 0.7, 0.16, 0.7), 3.0)

	# 红色警示灯
	var pulse := 0.5 + 0.5 * sin(_phase * 4.2)
	var warning := Color(1.0, 0.25, 0.12, 0.45 + 0.45 * pulse) if _open_amount > 0.05 else Color(0.45, 0.12, 0.08, 0.55)
	draw_circle(Vector2(0, -196), 11.0, warning)
	draw_arc(Vector2(0, -196), 20.0, 0.0, TAU, 24, Color(warning.r, warning.g, warning.b, warning.a * 0.45), 2.0)

	# 吸入闪光与气流
	if _consume_flash > 0.0:
		var alpha := clampf(_consume_flash / 0.28, 0.0, 1.0)
		draw_circle(Vector2(0, -76), 96.0 * (0.75 + 0.25 * alpha), Color(1.0, 0.42, 0.12, 0.4 * alpha))
	if _open_amount > 0.05:
		for i in 3:
			var y := -120.0 - i * 46.0
			var alpha := 0.12 + 0.08 * sin(_phase * 3.0 + i)
			draw_line(Vector2(-140.0 + i * 52.0, y), Vector2(0, -36), Color(0.95, 0.5, 0.18, alpha), 2.0)
			draw_line(Vector2(140.0 - i * 52.0, y), Vector2(0, -36), Color(0.95, 0.5, 0.18, alpha), 2.0)


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
