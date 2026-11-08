class_name TapeRibbonButton
extends Button

## A cassette-tape ribbon menu row: gradient strip, dark extrusion edge,
## bilingual label, index and a pulsing spark. Drawn entirely in code.

enum RibbonStyle { PRIMARY, SECONDARY, DARK }

const FONT_CN: Font = preload("res://ui/fonts/f_ribbon_cn.tres")
const FONT_EN: Font = preload("res://ui/fonts/f_label_tracked.tres")
const FONT_NUM: Font = preload("res://ui/fonts/f_mono.tres")

@export var ribbon_style: RibbonStyle = RibbonStyle.PRIMARY:
	set(value):
		ribbon_style = value
		queue_redraw()

@export var index_text: String = "01":
	set(value):
		index_text = value
		queue_redraw()

@export var label_cn: String = "开始游戏":
	set(value):
		label_cn = value
		queue_redraw()

@export var label_en: String = "START SESSION":
	set(value):
		label_en = value
		queue_redraw()

var _hover: float = 0.0
var _press: float = 0.0
var _hovered: bool = false
var _spark_time: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)
	button_down.connect(func() -> void: _press = 1.0)
	button_up.connect(func() -> void: _press = 0.0)
	queue_redraw()


func _process(delta: float) -> void:
	var target: float = 1.0 if (_hovered or has_focus()) else 0.0
	_hover = move_toward(_hover, target, delta * 7.0)
	_press = move_toward(_press, 0.0, delta * 9.0)
	_spark_time += delta
	queue_redraw()


func _palette() -> Dictionary:
	match ribbon_style:
		RibbonStyle.SECONDARY:
			return {
				"top": Color(0.706, 0.851, 0.965),
				"bottom": Color(0.365, 0.612, 0.812),
				"ink": Color(0.024, 0.129, 0.247),
				"sub": Color(0.024, 0.129, 0.247, 0.58),
				"num": Color(0.024, 0.129, 0.247, 0.5),
				"lip": Color(0.043, 0.196, 0.333, 0.30),
				"border": Color(0.027, 0.106, 0.196, 0.95),
				"spark": Color(0.024, 0.129, 0.247, 0.85),
			}
		RibbonStyle.DARK:
			return {
				"top": Color(0.114, 0.259, 0.435),
				"bottom": Color(0.035, 0.122, 0.255),
				"ink": Color(0.796, 0.906, 1.0),
				"sub": Color(0.588, 0.776, 0.941, 0.55),
				"num": Color(0.627, 0.808, 0.965, 0.55),
				"lip": Color(0.0, 0.0, 0.0, 0.32),
				"border": Color(0.027, 0.106, 0.196, 0.95),
				"spark": Color(0.75, 0.9, 1.0, 0.8),
			}
		_:
			return {
				"top": Color(0.796, 0.914, 1.0),
				"bottom": Color(0.361, 0.624, 0.831),
				"ink": Color(0.024, 0.145, 0.278),
				"sub": Color(0.024, 0.145, 0.278, 0.62),
				"num": Color(0.024, 0.145, 0.278, 0.55),
				"lip": Color(0.063, 0.227, 0.4, 0.28),
				"border": Color(0.027, 0.106, 0.196, 0.95),
				"spark": Color(0.024, 0.145, 0.278, 0.85),
			}


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var pal := _palette()
	var top_color: Color = pal["top"]
	var bottom_color: Color = pal["bottom"]
	var ink_color: Color = pal["ink"]
	var sub_color: Color = pal["sub"]
	var num_color: Color = pal["num"]
	var lip_color: Color = pal["lip"]
	var border_color: Color = pal["border"]
	var spark_color: Color = pal["spark"]
	var text_shift: float = 7.0 * _hover - 2.0 * _press

	var body := PackedVector2Array(
		[Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
	)
	var colors := PackedColorArray(
		[top_color, top_color, bottom_color, bottom_color]
	)
	draw_polygon(body, colors)

	# extruded lower edge
	draw_rect(Rect2(0, h - 10.0, w, 10.0), lip_color)

	# hover wash
	if _hover > 0.001:
		draw_rect(Rect2(0, 0, w, h), Color(0.86, 0.96, 1.0, 0.07 * _hover))

	# top specular line
	draw_line(
		Vector2(3, 2.6),
		Vector2(w - 3, 2.6),
		Color(1, 1, 1, 0.5 if ribbon_style != RibbonStyle.DARK else 0.18),
		1.4,
		true
	)

	# outline
	var outline := PackedVector2Array(
		[Vector2(1.5, 1.5), Vector2(w - 1.5, 1.5), Vector2(w - 1.5, h - 1.5), Vector2(1.5, h - 1.5), Vector2(1.5, 1.5)]
	)
	draw_polyline(outline, border_color, 3.0, true)

	# index
	draw_string(
		FONT_NUM,
		Vector2(44 + text_shift * 0.4, h * 0.5 + 4.0),
		index_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		num_color
	)

	# bilingual label
	draw_string(
		FONT_CN,
		Vector2(84 + text_shift, h * 0.5 + 4.0),
		label_cn,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		34,
		ink_color
	)
	draw_string(
		FONT_EN,
		Vector2(86 + text_shift, h * 0.5 + 25.0),
		label_en.to_upper(),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		9,
		sub_color
	)

	# spark
	var pulse: float = 0.86 + 0.14 * sin(_spark_time * 1.8)
	var spark_r: float = (13.0 if ribbon_style != RibbonStyle.DARK else 12.0) * pulse
	var sc := Vector2(390.0 + text_shift, h * 0.5)
	draw_circle(sc, spark_r * 2.2, Color(spark_color, 0.05))
	var star := PackedVector2Array()
	for i in range(8):
		var angle: float = -PI * 0.5 + float(i) * PI * 0.25
		var radius: float = spark_r if i % 2 == 0 else spark_r * 0.24
		star.append(sc + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(star, spark_color)

	# focus brackets
	if has_focus():
		var arm: float = 14.0
		var fc := Color(0.78, 0.95, 1.0, 0.85)
		draw_line(Vector2(5, 5), Vector2(5 + arm, 5), fc, 1.5, true)
		draw_line(Vector2(5, 5), Vector2(5, 5 + arm), fc, 1.5, true)
		draw_line(Vector2(w - 5, h - 5), Vector2(w - 5 - arm, h - 5), fc, 1.5, true)
		draw_line(Vector2(w - 5, h - 5), Vector2(w - 5, h - 5 - arm), fc, 1.5, true)
