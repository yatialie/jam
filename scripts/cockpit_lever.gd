extends Node2D

## Idle sway for a throttle lever. The node sits on the lever pivot (base).

@export var sway_degrees := 2.4
@export var sway_speed := 1.1
@export var phase_offset := 0.0

var _time := 0.0


func _ready() -> void:
	_time = phase_offset


func _process(delta: float) -> void:
	_time += delta
	rotation = deg_to_rad(sin(_time * sway_speed) * sway_degrees)
