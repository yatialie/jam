extends Control

## Discreet corner brackets that frame the screen like a monitor bezel overlay.

@export var inset: float = 30.0
@export var arm: float = 46.0
@export var accent: Color = Color(0.32, 0.82, 0.88)
@export var alpha: float = 0.28


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var color := Color(accent, alpha)
	var thin := Color(accent, alpha * 0.4)

	# corners
	draw_line(Vector2(inset, inset + arm), Vector2(inset, inset), color, 1.5, true)
	draw_line(Vector2(inset, inset), Vector2(inset + arm, inset), color, 1.5, true)

	draw_line(Vector2(w - inset, inset + arm), Vector2(w - inset, inset), color, 1.5, true)
	draw_line(Vector2(w - inset, inset), Vector2(w - inset - arm, inset), color, 1.5, true)

	draw_line(Vector2(inset, h - inset - arm), Vector2(inset, h - inset), color, 1.5, true)
	draw_line(Vector2(inset, h - inset), Vector2(inset + arm, h - inset), color, 1.5, true)

	draw_line(Vector2(w - inset, h - inset - arm), Vector2(w - inset, h - inset), color, 1.5, true)
	draw_line(Vector2(w - inset, h - inset), Vector2(w - inset - arm, h - inset), color, 1.5, true)

	# small tick marks along the middle of the edge
	var tick: float = 8.0
	draw_line(Vector2(w * 0.5, inset - 3.0), Vector2(w * 0.5, inset + tick), thin, 1.0, true)
	draw_line(Vector2(w * 0.5, h - inset + 3.0), Vector2(w * 0.5, h - inset - tick), thin, 1.0, true)
	draw_line(Vector2(inset - 3.0, h * 0.5), Vector2(inset + tick, h * 0.5), thin, 1.0, true)
	draw_line(Vector2(w - inset + 3.0, h * 0.5), Vector2(w - inset - tick, h * 0.5), thin, 1.0, true)
