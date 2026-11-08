extends Node2D

## 白盒锁死门：剧情占位门体，纯代码绘制，不依赖美术资源。
## 节点原点位于门底边中心，尺寸使用关卡设计单位。

const TILT := 0.72
var door_size := Vector2(152.0, 360.0)
const FRAME_COLOR := Color(0.23, 0.27, 0.32)
const PANEL_COLOR := Color(0.09, 0.11, 0.14)
const EDGE_COLOR := Color(0.42, 0.48, 0.55)
const LAMP_IDLE := Color(0.72, 0.2, 0.14)
const LAMP_FLASH := Color(1.0, 0.62, 0.5)
const FONT_LABEL := preload("res://ui/fonts/f_ui_bold.tres")

var _body_root: Node2D
var _lamp: Polygon2D
var _outline_root: Node2D
var _outline: Line2D
var _glow: Line2D
var _highlighted := false
var _pulse: Tween
var _deny: Tween


func _ready() -> void:
	z_index = 3
	_build_body()
	_build_outline()


func set_highlight(on: bool) -> void:
	if _highlighted == on:
		return
	_highlighted = on
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	if on:
		_outline_root.visible = true
		_outline_root.modulate.a = 0.0
		_pulse = create_tween()
		_pulse.tween_property(_outline_root, "modulate:a", 1.0, 0.14)
		_pulse.tween_callback(_start_pulse)
	else:
		_pulse = create_tween()
		_pulse.tween_property(_outline_root, "modulate:a", 0.0, 0.12)
		_pulse.tween_callback(_hide_outline)


func play_denied() -> void:
	if _deny and _deny.is_valid():
		_deny.kill()
	_deny = create_tween()
	for i in 3:
		_deny.tween_property(_lamp, "color", LAMP_FLASH, 0.07)
		_deny.tween_property(_lamp, "color", LAMP_IDLE, 0.11)

	var base := _body_root.position
	var shake := create_tween()
	shake.tween_property(_body_root, "position", base + Vector2(5, 0), 0.04)
	shake.tween_property(_body_root, "position", base + Vector2(-5, 0), 0.06)
	shake.tween_property(_body_root, "position", base + Vector2(3, 0), 0.05)
	shake.tween_property(_body_root, "position", base, 0.05)


func _start_pulse() -> void:
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "modulate:a", 0.55, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.parallel().tween_property(_outline, "modulate:a", 0.72, 0.8)
	_pulse.tween_property(_glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.parallel().tween_property(_outline, "modulate:a", 1.0, 0.8)


func _hide_outline() -> void:
	_outline_root.visible = false


func _build_body() -> void:
	_body_root = Node2D.new()
	_body_root.name = "Body"
	add_child(_body_root)

	var frame := Polygon2D.new()
	frame.polygon = _rect_points(Vector2(0, -door_size.y * 0.5), door_size)
	frame.color = FRAME_COLOR
	_body_root.add_child(frame)

	var panel_size := door_size - Vector2(18, 18)
	var panel := Polygon2D.new()
	panel.polygon = _rect_points(Vector2(0, -door_size.y * 0.5), panel_size)
	panel.color = PANEL_COLOR
	_body_root.add_child(panel)

	var seam := Line2D.new()
	seam.points = PackedVector2Array([Vector2(0, -door_size.y + 26), Vector2(0, -26)])
	seam.width = 2.0
	seam.default_color = EDGE_COLOR
	_body_root.add_child(seam)

	var band := Polygon2D.new()
	band.polygon = _rect_points(Vector2(0, -door_size.y * 0.34), Vector2(panel_size.x, 8))
	band.color = Color(0.7, 0.62, 0.3, 0.5)
	_body_root.add_child(band)

	_lamp = Polygon2D.new()
	_lamp.polygon = _rect_points(Vector2(0, -door_size.y + 22), Vector2(30, 12))
	_lamp.color = LAMP_IDLE
	_body_root.add_child(_lamp)

	var label := Label.new()
	label.text = "SEALED"
	label.position = Vector2(-door_size.x * 0.5, -door_size.y * 0.52)
	label.size = Vector2(door_size.x, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_LABEL)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.62, 0.68, 0.75, 0.85))
	# 抵消 Projection 的 0.72 纵向压缩，避免文字被压扁。
	label.scale = Vector2(1.0, 1.0 / TILT)
	_body_root.add_child(label)


func _build_outline() -> void:
	_outline_root = Node2D.new()
	_outline_root.name = "Highlight"
	# 反向缩放，让描边在 0.72 投影下保持横竖粗细一致。
	_outline_root.scale = Vector2(1.0, 1.0 / TILT)
	_outline_root.visible = false
	add_child(_outline_root)

	var points := _outline_points(6.0)

	_glow = Line2D.new()
	_glow.points = points
	_glow.width = 16.0
	_glow.default_color = Color(1, 1, 1, 0.35)
	_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = blend
	_outline_root.add_child(_glow)

	_outline = Line2D.new()
	_outline.points = points
	_outline.width = 4.0
	_outline.default_color = Color(1, 1, 1, 0.95)
	_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	_outline_root.add_child(_outline)


func _rect_points(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(-half.x, half.y),
		center + Vector2(half.x, half.y),
		center + Vector2(half.x, -half.y),
		center + Vector2(-half.x, -half.y),
	])


func _outline_points(margin: float) -> PackedVector2Array:
	var half_w := door_size.x * 0.5 + margin
	var bottom := margin
	var top := -door_size.y * TILT - margin
	return PackedVector2Array([
		Vector2(-half_w, bottom),
		Vector2(half_w, bottom),
		Vector2(half_w, top),
		Vector2(-half_w, top),
		Vector2(-half_w, bottom),
	])
