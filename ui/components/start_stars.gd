extends Control

## Twinkling parallax star layer drawn on top of the starfield texture.

@export var amount: int = 190
@export var rng_seed: int = 20261108

var parallax_offset: Vector2 = Vector2.ZERO

var _stars: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in range(amount):
		var depth := rng.randf_range(0.15, 1.0)
		var warm := rng.randf() > 0.86
		_stars.append(
			{
				"pos": Vector2(rng.randf(), rng.randf()),
				"radius": rng.randf_range(0.4, 1.6),
				"alpha": rng.randf_range(0.18, 0.72),
				"depth": depth,
				"phase": rng.randf_range(0.0, TAU),
				"speed": rng.randf_range(0.35, 1.4),
				"glint": rng.randf() > 0.88,
				"color": Color(1.0, 0.82, 0.62) if warm else Color(0.86, 0.94, 1.0),
			}
		)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for star in _stars:
		var base_pos: Vector2 = star["pos"]
		var pos: Vector2 = base_pos * size + parallax_offset * float(star["depth"])
		var pulse: float = 0.5 + 0.5 * sin(_time * float(star["speed"]) + float(star["phase"]))
		var alpha: float = clampf(float(star["alpha"]) * (0.5 + pulse * 0.62), 0.0, 1.0)
		var radius: float = float(star["radius"])
		var base_color: Color = star["color"]
		draw_circle(pos, radius, Color(base_color, alpha))
		if star["glint"] and alpha > 0.34:
			var length: float = radius * (5.0 + pulse * 3.0)
			var glint_color := Color(0.84, 0.93, 1.0, alpha * 0.30)
			draw_line(pos - Vector2(length, 0), pos + Vector2(length, 0), glint_color, 0.7, true)
			draw_line(pos - Vector2(0, length), pos + Vector2(0, length), glint_color, 0.7, true)
