extends Control

## Static scanline veil drawn once over the start screen.

@export var spacing: float = 3.0
@export var line_alpha: float = 0.016


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var y: float = 0.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, line_alpha), 1.0)
		y += spacing
