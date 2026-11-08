extends Sprite2D

## Animated MFD overlay: gentle flicker plus a travelling scan bar.

@export var flicker_speed := 7.0
@export var flicker_amount := 0.05
@export var scan_speed := 26.0
@export var scan_alpha := 0.10

var _scan: Polygon2D
var _time := 0.0
var _base_alpha := 1.0


func _ready() -> void:
	_base_alpha = modulate.a
	_time = randf() * 10.0
	if not region_enabled:
		return
	var area := region_rect.size
	if area.y <= 1.0:
		return
	_scan = Polygon2D.new()
	_scan.polygon = PackedVector2Array([
		Vector2(-area.x / 2.0, 0),
		Vector2(area.x / 2.0, 0),
		Vector2(area.x / 2.0, 14.0),
		Vector2(-area.x / 2.0, 14.0),
	])
	_scan.color = Color(0.45, 0.95, 1.0, scan_alpha)
	_scan.z_index = 1
	add_child(_scan)


func _process(delta: float) -> void:
	_time += delta
	var flicker := 1.0 + sin(_time * flicker_speed) * flicker_amount
	flicker += sin(_time * 23.7) * flicker_amount * 0.35
	modulate.a = _base_alpha * flicker

	if _scan:
		var area := region_rect.size
		_scan.position.y = -area.y / 2.0 + fmod(_time * scan_speed, area.y)
