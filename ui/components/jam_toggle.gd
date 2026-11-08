class_name JamToggle
extends Button

## A labelled switch row with an animated pill.

const FONT_LABEL: Font = preload("res://ui/fonts/f_label_tracked.tres")

@export var title_text: String = "全屏显示"
@export var hint_text: String = "FULLSCREEN"
@export var accent: Color = Color(0.27, 0.85, 0.92)

var _t: float = 0.0
var _hover: float = 0.0
var _hovered: bool = false


func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(0.0, 74.0)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_t = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)


func _process(delta: float) -> void:
	var target: float = 1.0 if button_pressed else 0.0
	var changed: bool = false
	if absf(_t - target) > 0.0005:
		_t = move_toward(_t, target, delta * 6.5)
		changed = true
	var hover_target: float = 1.0 if (_hovered or has_focus()) else 0.0
	if absf(_hover - hover_target) > 0.0005:
		_hover = move_toward(_hover, hover_target, delta * 7.0)
		changed = true
	if changed:
		queue_redraw()


func _on_toggled(_pressed: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_font("font")
	var w: float = size.x
	var h: float = size.y

	draw_string(
		font,
		Vector2(0.0, h * 0.5 - 6.0),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 120.0,
		20,
		Color(0.88, 0.93, 0.95, 1.0)
	)
	draw_string(
		FONT_LABEL,
		Vector2(1.0, h * 0.5 + 18.0),
		hint_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 120.0,
		11,
		Color(0.52, 0.72, 0.78, 0.6 + 0.2 * _hover)
	)

	# pill
	var pw: float = 56.0
	var ph: float = 28.0
	var px: float = w - pw - 4.0
	var py: float = (h - ph) * 0.5
	var r: float = ph * 0.5
	var off_color := Color(1, 1, 1, 0.10)
	var on_color := Color(accent, 0.30)
	var track: Color = off_color.lerp(on_color, _t)
	_pill(Rect2(px, py, pw, ph), r, track)
	draw_arc(
		Vector2(px + r, py + r),
		r - 0.5,
		PI * 0.5,
		PI * 1.5,
		24,
		Color(1, 1, 1, 0.06 + 0.12 * _hover),
		1.0,
		true
	)
	draw_arc(
		Vector2(px + pw - r, py + r),
		r - 0.5,
		-PI * 0.5,
		PI * 0.5,
		24,
		Color(1, 1, 1, 0.06 + 0.12 * _hover),
		1.0,
		true
	)

	var knob_x: float = px + r + (pw - ph) * _t
	var knob_color: Color = Color(0.56, 0.63, 0.67, 1.0).lerp(accent, _t)
	draw_circle(Vector2(knob_x, py + r), 10.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2(knob_x, py + r), 9.0, knob_color)
	draw_circle(Vector2(knob_x, py + r), 3.5, Color(0.04, 0.07, 0.08, 0.85))
	if _t > 0.01:
		draw_circle(Vector2(knob_x, py + r), 14.0, Color(accent, 0.10 * _t))

	draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color(1, 1, 1, 0.055), 1.0)

	if has_focus():
		var arm: float = 10.0
		var fc := Color(accent, 0.55)
		draw_line(Vector2(0, 0), Vector2(arm, 0), fc, 1.0)
		draw_line(Vector2(w, h), Vector2(w - arm, h), fc, 1.0)


func _pill(rect: Rect2, radius: float, color: Color) -> void:
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_rect(
		Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y),
		color
	)
