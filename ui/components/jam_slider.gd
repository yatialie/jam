class_name JamSlider
extends Control

## Labelled slider with tick marks, animated fill and value readout.

signal value_changed(new_value: float)

const FONT_LABEL: Font = preload("res://ui/fonts/f_label_tracked.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")

@export var title_text: String = "主音量"
@export var hint_text: String = "MASTER VOLUME"
@export var min_value: float = 0.0
@export var max_value: float = 100.0
@export var step: float = 1.0
@export var decimals: int = 0
@export var suffix: String = "%"
@export var accent: Color = Color(0.27, 0.85, 0.92)

var value: float = 80.0

var _display: float = 0.0
var _dragging: bool = false
var _hover: float = 0.0
var _hovered: bool = false
var _pad: float = 10.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, 92.0)
	mouse_entered.connect(func() -> void: _hovered = true)
	mouse_exited.connect(func() -> void: _hovered = false)
	_display = value
	queue_redraw()


func set_value(new_value: float, silent: bool = false) -> void:
	value = clampf(snappedf(new_value, step), min_value, max_value)
	if not silent:
		value_changed.emit(value)
	queue_redraw()


func _process(delta: float) -> void:
	_display = lerpf(_display, value, 1.0 - exp(-delta * 16.0))
	var target: float = 1.0 if (_hovered or has_focus()) else 0.0
	_hover = move_toward(_hover, target, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_font("font")
	var w: float = size.x
	var track_y: float = size.y - 24.0
	var track_rect := Rect2(_pad, track_y - 2.0, w - _pad * 2.0, 4.0)
	var ratio: float = 0.0
	if max_value > min_value:
		ratio = clampf((_display - min_value) / (max_value - min_value), 0.0, 1.0)

	# header
	draw_string(
		font,
		Vector2(0.0, 24.0),
		title_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 160.0,
		20,
		Color(0.88, 0.93, 0.95, 1.0)
	)
	draw_string(
		FONT_LABEL,
		Vector2(1.0, 44.0),
		hint_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		w - 160.0,
		11,
		Color(0.52, 0.72, 0.78, 0.6 + 0.2 * _hover)
	)
	var value_text: String = String.num(value, decimals) + suffix
	draw_string(
		FONT_MONO,
		Vector2(w - 150.0, 28.0),
		value_text,
		HORIZONTAL_ALIGNMENT_RIGHT,
		150.0,
		16,
		Color(0.62, 0.88, 0.93, 0.78 + 0.2 * _hover)
	)

	# track
	draw_rect(track_rect, Color(1, 1, 1, 0.09))
	for i in range(21):
		var tx: float = _pad + (w - _pad * 2.0) * float(i) / 20.0
		var tall: bool = i % 5 == 0
		draw_line(
			Vector2(tx, track_y - 12.0),
			Vector2(tx, track_y - 8.0 if tall else track_y - 10.0),
			Color(1, 1, 1, 0.10 if tall else 0.055),
			1.0
		)

	var fill_w: float = track_rect.size.x * ratio
	draw_rect(Rect2(track_rect.position.x, track_y - 2.0, fill_w, 4.0), Color(accent, 0.72))
	draw_rect(
		Rect2(track_rect.position.x, track_y - 2.0, fill_w, 4.0),
		Color(accent, 0.18 + 0.12 * _hover)
	)

	# knob
	var knob_pos := Vector2(track_rect.position.x + fill_w, track_y)
	draw_circle(knob_pos, 13.0, Color(accent, 0.10 + 0.10 * _hover))
	draw_circle(knob_pos, 7.5, Color(0.03, 0.07, 0.08, 0.9))
	draw_circle(knob_pos, 6.0, Color(0.85, 0.95, 0.97, 1.0))
	draw_circle(knob_pos, 2.4, Color(accent, 1.0))

	if has_focus():
		draw_line(Vector2(0, size.y - 1), Vector2(w, size.y - 1), Color(accent, 0.35), 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			_dragging = true
			_set_from_x(event.position.x)
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventKey and event.pressed:
		if event.is_action("ui_left"):
			set_value(value - step)
			accept_event()
		elif event.is_action("ui_right"):
			set_value(value + step)
			accept_event()


func _set_from_x(x: float) -> void:
	var usable: float = maxf(size.x - _pad * 2.0, 1.0)
	var ratio: float = clampf((x - _pad) / usable, 0.0, 1.0)
	set_value(min_value + (max_value - min_value) * ratio)
