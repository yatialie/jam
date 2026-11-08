extends Control

## Sparse drifting dust motes for depth.

@export var amount: int = 42
@export var mote_color: Color = Color(0.72, 0.9, 0.95)

var _motes: Array = []
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107
	for i in range(amount):
		_motes.append(
			{
				"pos": Vector2(rng.randf(), rng.randf()),
				"speed": rng.randf_range(0.004, 0.018),
				"drift": rng.randf_range(-0.004, 0.004),
				"radius": rng.randf_range(0.6, 1.9),
				"alpha": rng.randf_range(0.05, 0.22),
				"phase": rng.randf_range(0.0, TAU),
			}
		)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for mote in _motes:
		var pos: Vector2 = mote["pos"]
		pos.y -= mote["speed"] * 0.06
		pos.x += (mote["drift"] + sin(_time * 0.4 + mote["phase"]) * 0.0006) * 0.06
		if pos.y < -0.02:
			pos.y = 1.02
		if pos.x < -0.02:
			pos.x = 1.02
		elif pos.x > 1.02:
			pos.x = -0.02
		mote["pos"] = pos

		var flicker: float = 0.65 + 0.35 * sin(_time * 1.1 + mote["phase"])
		var alpha: float = mote["alpha"] * flicker
		draw_circle(pos * size, mote["radius"], Color(mote_color, alpha))
