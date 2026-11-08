class_name JamMissionFrame
extends JamHudFrame

## Mission-log variant of the shared chrome: adds the chapter code chip and
## the twin cassette-reel window in the header.


func _draw() -> void:
	super._draw()
	_draw_code_chip()
	_draw_reel_window(size.x)


func _draw_code_chip() -> void:
	draw_rect(Rect2(16.0, 14.0, 54.0, 20.0), Color(accent, 0.06))
	draw_rect(Rect2(16.0, 14.0, 54.0, 20.0), Color(accent, 0.35), false, 1.0)
	draw_rect(Rect2(16.0, 14.0, 3.0, 20.0), Color(0.98, 0.68, 0.3, 0.9))


func _draw_reel_window(w: float) -> void:
	var size_x := 104.0
	var size_y := 44.0
	var x0 := w - 16.0 - size_x
	var y0 := 32.0
	var chamfer := 5.0
	var frame := PackedVector2Array(
		[
			Vector2(x0 + chamfer, y0),
			Vector2(x0 + size_x - chamfer, y0),
			Vector2(x0 + size_x, y0 + chamfer),
			Vector2(x0 + size_x, y0 + size_y - chamfer),
			Vector2(x0 + size_x - chamfer, y0 + size_y),
			Vector2(x0 + chamfer, y0 + size_y),
			Vector2(x0, y0 + size_y - chamfer),
			Vector2(x0, y0 + chamfer),
		]
	)
	var closed := frame.duplicate()
	closed.append(frame[0])
	draw_polyline(closed, Color(accent, 0.22), 1.0, true)

	for reel_index in 2:
		var center := Vector2(x0 + 30.0 + float(reel_index) * 44.0, y0 + size_y * 0.5)
		var spin := _phase * (0.55 if reel_index == 0 else -0.38)
		draw_arc(center, 15.5, 0.0, TAU, 36, Color(accent, 0.22), 1.0, true)
		for i in 8:
			var angle := TAU * float(i) / 8.0 + spin
			var dir := Vector2(cos(angle), sin(angle))
			draw_line(center + dir * 12.0, center + dir * 15.0, Color(accent, 0.18), 1.0)
		draw_circle(center, 4.6, Color(accent, 0.09))
		draw_arc(center, 4.6, 0.0, TAU, 20, Color(accent, 0.24), 1.0, true)
		draw_circle(center, 1.4, Color(0.98, 0.68, 0.3, 0.45))
