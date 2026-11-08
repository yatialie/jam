class_name JamGlassPanel
extends Control

## Beveled frosted-glass panel used by modals and overlays.

@export var accent: Color = Color(0.27, 0.85, 0.92)
@export var fill_color: Color = Color(0.024, 0.058, 0.072, 0.90)
@export var cut: float = 18.0
@export var show_brackets: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var points := _panel_points()
	var colors := _panel_colors(points)
	draw_polygon(points, colors)

	# top sheen
	var sheen_h: float = minf(96.0, size.y * 0.28)
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(cut, 0.0),
				Vector2(size.x - cut, 0.0),
				Vector2(size.x - cut, sheen_h),
				Vector2(cut, sheen_h),
			]
		),
		PackedColorArray(
			[
				Color(1, 1, 1, 0.055),
				Color(1, 1, 1, 0.055),
				Color(1, 1, 1, 0.0),
				Color(1, 1, 1, 0.0),
			]
		)
	)

	# rim
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Color(accent, 0.55), 1.0, true)

	# inner rim
	var inner := PackedVector2Array()
	for p in points:
		inner.append(p.lerp(size * 0.5, 0.004))
	var inner_closed := inner.duplicate()
	inner_closed.append(inner[0])
	draw_polyline(inner_closed, Color(accent, 0.12), 1.0, true)

	if show_brackets:
		_draw_brackets()


func _panel_points() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y
	var c: float = minf(cut, minf(w, h) * 0.25)
	return PackedVector2Array(
		[
			Vector2(c, 0.0),
			Vector2(w - c, 0.0),
			Vector2(w, c),
			Vector2(w, h - c),
			Vector2(w - c, h),
			Vector2(c, h),
			Vector2(0.0, h - c),
			Vector2(0.0, c),
		]
	)


func _panel_colors(points: PackedVector2Array) -> PackedColorArray:
	var top := fill_color.lightened(0.055)
	var bottom := fill_color.darkened(0.05)
	var colors := PackedColorArray()
	for p in points:
		var t: float = clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	return colors


func _draw_brackets() -> void:
	var inset: float = 8.0
	var color := Color(accent, 0.42)
	var c: float = minf(cut, minf(size.x, size.y) * 0.25)
	var positions := [
		[Vector2(inset, c + inset * 2.0), Vector2(inset, inset), Vector2(c + inset * 2.0, inset)],
		[
			Vector2(size.x - inset, c + inset * 2.0),
			Vector2(size.x - inset, inset),
			Vector2(size.x - c - inset * 2.0, inset)
		],
		[
			Vector2(inset, size.y - c - inset * 2.0),
			Vector2(inset, size.y - inset),
			Vector2(c + inset * 2.0, size.y - inset)
		],
		[
			Vector2(size.x - inset, size.y - c - inset * 2.0),
			Vector2(size.x - inset, size.y - inset),
			Vector2(size.x - c - inset * 2.0, size.y - inset)
		],
	]
	for corner in positions:
		var a: Vector2 = corner[0]
		var b: Vector2 = corner[1]
		var d: Vector2 = corner[2]
		draw_line(a, b, color, 1.5, true)
		draw_line(b, d, color, 1.5, true)
