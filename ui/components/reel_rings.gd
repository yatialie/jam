extends Control

## Slow rotating reel rings, a faint nod to the cassette spools.

@export var ring_color: Color = Color(0.35, 0.85, 0.92)
@export var base_radius: float = 300.0
@export var tick_count: int = 56

var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5

	# outer tick ring
	for i in range(tick_count):
		var angle: float = TAU * float(i) / float(tick_count) + _time * 0.035
		var inner: float = base_radius + 34.0
		var length: float = 10.0 if i % 4 == 0 else 5.0
		var color := Color(ring_color, 0.20 if i % 4 == 0 else 0.10)
		draw_line(
			center + Vector2(cos(angle), sin(angle)) * inner,
			center + Vector2(cos(angle), sin(angle)) * (inner + length),
			color,
			1.0,
			true
		)

	# inner tick ring, counter rotating
	for i in range(tick_count):
		var angle: float = -TAU * float(i) / float(tick_count) - _time * 0.028
		var inner: float = base_radius - 26.0
		var color := Color(ring_color, 0.12 if i % 6 == 0 else 0.06)
		draw_line(
			center + Vector2(cos(angle), sin(angle)) * inner,
			center + Vector2(cos(angle), sin(angle)) * (inner + 7.0),
			color,
			1.0,
			true
		)

	# thin guide circles
	draw_arc(center, base_radius, 0.0, TAU, 96, Color(ring_color, 0.07), 1.0, true)
	draw_arc(center, base_radius + 52.0, 0.0, TAU, 96, Color(ring_color, 0.04), 1.0, true)
