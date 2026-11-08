extends Node2D

const CROSSHAIR_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/vfx/crosshair.png")
const TILT := 0.72
const BASE_SCALE := 0.45
const RING_RADIUS := 30.0
const RING_SEGMENTS := 48

var _sprite: Sprite2D
var _line: Line2D
var _phase := 0.0
var _charge := 0.0


func _ready() -> void:
	# 瞄准准星属于界面提示，需要始终盖在场景物件之上。
	z_index = 4080

	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(0.42, 0.95, 1.0, 0.18)
	var line_material := CanvasItemMaterial.new()
	line_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_line.material = line_material
	add_child(_line)

	_sprite = Sprite2D.new()
	_sprite.texture = CROSSHAIR_TEXTURE
	_sprite.modulate = Color(0.7, 1.0, 1.0, 0.95)
	_sprite.scale = Vector2(BASE_SCALE, BASE_SCALE / TILT)
	add_child(_sprite)


func _process(delta: float) -> void:
	if not visible or _sprite == null:
		return
	_phase += delta
	var pulse := 1.0 + sin(_phase * 3.2) * 0.025
	_sprite.rotation = sin(_phase * 2.0) * 0.025
	_sprite.scale = Vector2(BASE_SCALE, BASE_SCALE / TILT) * pulse
	if _charge > 0.0:
		queue_redraw()


func update_aim(mouse_position: Vector2, muzzle_position: Vector2, charge_ratio := 0.0) -> void:
	position = mouse_position
	var previous := _charge
	_charge = clampf(charge_ratio, 0.0, 1.0)
	if _line != null:
		_line.points = PackedVector2Array([muzzle_position - mouse_position, Vector2.ZERO])
	# 蓄力结束时补一次重绘，清掉残留的进度环
	if _charge <= 0.0 and previous > 0.0:
		queue_redraw()


## 蓄力进度环：沿准星外圈顺时针填充，蓄满后整环高亮并脉动。
func _draw() -> void:
	if _charge <= 0.0:
		return

	var start := -PI * 0.5
	draw_polyline(_ring_points(RING_RADIUS, 0.0, TAU), Color(0.3, 0.75, 0.9, 0.14), 1.5, true)
	if _charge >= 1.0:
		var pulse := 0.5 + 0.5 * sin(_phase * 9.0)
		draw_polyline(
			_ring_points(RING_RADIUS + 4.0 + pulse * 2.0, 0.0, TAU),
			Color(0.55, 1.0, 1.0, 0.18 + 0.16 * pulse),
			2.0,
			true
		)
		draw_polyline(_ring_points(RING_RADIUS, 0.0, TAU), Color(0.85, 1.0, 1.0, 0.95), 3.0, true)
	else:
		var color := Color(0.45, 0.95, 1.0, 0.5 + 0.45 * _charge)
		draw_polyline(_ring_points(RING_RADIUS, start, start + TAU * _charge), color, 3.0, true)


## 生成贴合地面投影的椭圆环点列，避免纵向 0.72 缩放把圆环压扁。
func _ring_points(radius: float, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := maxi(int(ceil(float(RING_SEGMENTS) * absf(to - from) / TAU)), 2)
	for i in count + 1:
		var angle := lerpf(from, to, float(i) / float(count))
		points.append(Vector2(cos(angle), sin(angle) / TILT) * radius)
	return points
