class_name JamMenuButton
extends Button

## A wide "tape label" menu row: index, bilingual label and animated accents.

const FONT_LABEL: Font = preload("res://ui/fonts/f_label_tracked.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")

@export var index_text: String = "01":
	set(value):
		index_text = value
		if is_instance_valid(_index):
			_index.text = value

@export var label_cn: String = "开始":
	set(value):
		label_cn = value
		if is_instance_valid(_main):
			_main.text = value

@export var label_en: String = "START SESSION":
	set(value):
		label_en = value
		if is_instance_valid(_sub):
			_sub.text = value

var _hover: float = 0.0
var _press: float = 0.0
var _hovered: bool = false

var _index: Label
var _main: Label
var _sub: Label


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

	_build_labels()
	resized.connect(_layout)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)
	_layout()
	_apply_colors()


func _process(delta: float) -> void:
	var target: float = 1.0 if (_hovered or has_focus()) else 0.0
	_hover = move_toward(_hover, target, delta * 7.0)
	_press = move_toward(_press, 0.0, delta * 9.0)
	_apply_colors()
	_layout()
	queue_redraw()


func _build_labels() -> void:
	_index = _make_label(FONT_MONO, 15, Color(0.06, 0.2, 0.24, 0.95))
	_index.text = index_text
	_index.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	_main = _make_label(null, 46, Color(0.035, 0.10, 0.125, 1.0))
	_main.text = label_cn

	_sub = _make_label(FONT_LABEL, 16, Color(0.05, 0.2, 0.24, 1.0))
	_sub.text = label_en


func _make_label(font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.85, 0.96, 1, 0.18))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	return label


func _layout() -> void:
	if not is_instance_valid(_main):
		return
	var h: float = size.y
	var shift: float = 7.0 * _hover - 2.0 * _press
	_index.position = Vector2(28.0, 0.0)
	_index.size = Vector2(40.0, h)
	_main.position = Vector2(94.0 + shift, h * 0.5 - 37.0)
	_main.size = Vector2(size.x - 320.0, 54.0)
	_sub.position = Vector2(96.0 + shift, h * 0.5 + 14.0)
	_sub.size = Vector2(size.x - 320.0, 24.0)


func _apply_colors() -> void:
	if not is_instance_valid(_main):
		return
	var ink := Color(0.035, 0.10, 0.125, 1.0)
	var ink_hover := Color(0.015, 0.055, 0.07, 1.0)
	_index.add_theme_color_override(
		"font_color", Color(0.06, 0.2, 0.24, 0.95).lerp(Color(0.04, 0.3, 0.36, 1.0), _hover)
	)
	_main.add_theme_color_override("font_color", ink.lerp(ink_hover, _hover))
	_sub.add_theme_color_override(
		"font_color", Color(0.05, 0.2, 0.24, 1.0).lerp(Color(0.04, 0.3, 0.36, 1.0), _hover)
	)


func _on_button_down() -> void:
	_press = 1.0


func _on_button_up() -> void:
	_press = 0.0


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y

	# cyan wash sweeping in from the left
	if _hover > 0.001:
		var a: float = 0.16 * _hover
		var points := PackedVector2Array(
			[Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]
		)
		var colors := PackedColorArray(
			[
				Color(0.85, 1.0, 1.0, a),
				Color(0.85, 1.0, 1.0, a * 0.18),
				Color(0.85, 1.0, 1.0, a * 0.18),
				Color(0.85, 1.0, 1.0, a)
			]
		)
		draw_polygon(points, colors)

	if _press > 0.001:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.3, 0.34, 0.10 * _press))

	# active marker on the left edge
	var bar_h: float = lerpf(h * 0.28, h * 0.68, _hover)
	var bar_y: float = (h - bar_h) * 0.5
	draw_rect(
		Rect2(2.0, bar_y, 3.0, bar_h),
		Color(0.05, 0.32, 0.38, 0.45 + 0.45 * _hover)
	)

	# hairline separators
	draw_line(
		Vector2(74.0, h * 0.24),
		Vector2(74.0, h * 0.76),
		Color(0.05, 0.2, 0.24, 0.22 + 0.1 * _hover),
		1.0
	)
	draw_line(Vector2(20.0, h - 1.0), Vector2(w - 20.0, h - 1.0), Color(0.05, 0.2, 0.24, 0.14), 1.0)

	# chevron
	var cx: float = w - 40.0 + 8.0 * _hover
	var cy: float = h * 0.5
	var chevron_color := Color(0.05, 0.30, 0.36, 0.55 + 0.45 * _hover)
	draw_line(Vector2(cx - 5.0, cy - 7.0), Vector2(cx + 1.0, cy), chevron_color, 2.0, true)
	draw_line(Vector2(cx + 1.0, cy), Vector2(cx - 5.0, cy + 7.0), chevron_color, 2.0, true)

	# focus brackets
	if has_focus():
		var arm: float = 12.0
		var focus_color := Color(0.04, 0.4, 0.48, 0.85)
		draw_line(Vector2(1, 1), Vector2(1 + arm, 1), focus_color, 1.5)
		draw_line(Vector2(1, 1), Vector2(1, 1 + arm), focus_color, 1.5)
		draw_line(Vector2(w - 1, h - 1), Vector2(w - 1 - arm, h - 1), focus_color, 1.5)
		draw_line(Vector2(w - 1, h - 1), Vector2(w - 1, h - 1 - arm), focus_color, 1.5)
