class_name JamTaskRow
extends Control

## One objective row inside the mission log panel: status glyph, bilingual
## label and optional counter pips.

const FONT_CN: Font = preload("res://ui/fonts/f_ui.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")
const FONT_TRACKED: Font = preload("res://ui/fonts/f_label_tracked.tres")

const CYAN := Color(0.32, 0.86, 0.94)
const AMBER := Color(0.98, 0.68, 0.30)
const GREEN := Color(0.42, 1.0, 0.78)
const INK := Color(0.9, 0.95, 0.97, 0.97)
const DIM := Color(0.44, 0.57, 0.63, 0.9)

var task_id := ""

var _index_text := "01"
var _title := ""
var _subtitle := ""
var _state := "pending"
var _count := 0
var _target := 1

var _home_x := 0.0
var _reveal := 0.0
var _reveal_delay := 0.0
var _flash := 0.0
var _phase := 0.0

var _index_label: Label
var _title_label: Label
var _sub_label: Label
var _count_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_x = position.x
	_build_labels()
	resized.connect(_layout)
	_layout()


func setup(index: int, title: String, subtitle: String, target: int) -> void:
	_index_text = "%02d" % index
	_title = title
	_subtitle = subtitle
	_target = maxi(target, 1)
	if is_instance_valid(_index_label):
		_apply_text()


func apply_state(done: bool, count: int, target: int, active: bool) -> void:
	if done and _state != "done":
		_flash = 1.0
	_state = "done" if done else ("active" if active else "pending")
	_count = count
	_target = maxi(target, 1)
	_apply_style()


func play_reveal(delay: float) -> void:
	_reveal = 0.0
	_reveal_delay = delay


func _process(delta: float) -> void:
	_phase += delta
	if _reveal_delay > 0.0:
		_reveal_delay -= delta
	elif _reveal < 1.0:
		_reveal = minf(_reveal + delta * 3.4, 1.0)
	_flash = maxf(_flash - delta * 1.4, 0.0)

	modulate.a = _reveal
	position.x = _home_x - 12.0 * (1.0 - _reveal)
	queue_redraw()


func _build_labels() -> void:
	_index_label = _make_label(FONT_MONO, 9, DIM)
	_title_label = _make_label(FONT_CN, 18, INK)
	_sub_label = _make_label(FONT_TRACKED, 9, CYAN)
	_count_label = _make_label(FONT_MONO, 11, AMBER)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_text()
	_apply_style()


func _make_label(font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _apply_text() -> void:
	_index_label.text = _index_text
	_title_label.text = _title
	_sub_label.text = _subtitle


func _layout() -> void:
	if not is_instance_valid(_title_label):
		return
	var w := size.x
	var h := size.y
	_index_label.position = Vector2(38.0, 8.0)
	_index_label.size = Vector2(24.0, 14.0)
	_title_label.position = Vector2(64.0, 6.0)
	_title_label.size = Vector2(maxf(w - 64.0 - 62.0, 40.0), 26.0)
	_sub_label.position = Vector2(65.0, 32.0)
	_sub_label.size = Vector2(maxf(w - 64.0 - 62.0, 40.0), 14.0)
	_count_label.position = Vector2(w - 60.0, 14.0)
	_count_label.size = Vector2(44.0, 14.0)


func _apply_style() -> void:
	if not is_instance_valid(_title_label):
		return
	_count_label.text = "%d/%d" % [_count, _target] if _target > 1 else ""
	match _state:
		"done":
			_title_label.add_theme_color_override("font_color", Color(0.58, 0.72, 0.76, 0.72))
			_sub_label.add_theme_color_override("font_color", Color(0.42, 0.68, 0.64, 0.5))
			_index_label.add_theme_color_override("font_color", Color(0.4, 0.55, 0.58, 0.6))
			_count_label.add_theme_color_override("font_color", Color(0.42, 1.0, 0.78, 0.8))
		"active":
			_title_label.add_theme_color_override("font_color", INK)
			_sub_label.add_theme_color_override("font_color", Color(0.32, 0.86, 0.94, 0.6))
			_index_label.add_theme_color_override("font_color", Color(0.98, 0.68, 0.30, 0.9))
			_count_label.add_theme_color_override("font_color", AMBER)
		_:
			_title_label.add_theme_color_override("font_color", Color(0.68, 0.77, 0.81, 0.7))
			_sub_label.add_theme_color_override("font_color", Color(0.34, 0.5, 0.56, 0.45))
			_index_label.add_theme_color_override("font_color", Color(0.4, 0.52, 0.56, 0.5))
			_count_label.add_theme_color_override("font_color", Color(0.45, 0.58, 0.62, 0.5))


func _draw() -> void:
	var w := size.x
	var h := size.y
	var center_y := h * 0.5

	if _state == "active":
		var wash := 0.055 + 0.02 * sin(_phase * 2.4)
		draw_polygon(
			PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray(
				[
					Color(0.98, 0.68, 0.3, wash),
					Color(0.98, 0.68, 0.3, 0.0),
					Color(0.98, 0.68, 0.3, 0.0),
					Color(0.98, 0.68, 0.3, wash),
				]
			)
		)
		draw_rect(Rect2(0.0, 11.0, 2.0, h - 22.0), Color(0.98, 0.68, 0.3, 0.85))

	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 1.0, 0.78, 0.10 * _flash))
		var sweep_x := w * (1.0 - _flash)
		draw_line(Vector2(sweep_x, 2.0), Vector2(sweep_x, h - 2.0), Color(0.42, 1.0, 0.78, 0.65 * _flash), 2.0)

	_draw_glyph(Vector2(22.0, center_y))
	_draw_pips(w)

	draw_line(Vector2(12.0, h - 0.5), Vector2(w - 12.0, h - 0.5), Color(1, 1, 1, 0.055), 1.0)


func _draw_glyph(center: Vector2) -> void:
	var radius := 8.5
	var hex := PackedVector2Array()
	for i in 6:
		var angle := TAU * float(i) / 6.0 - PI / 2.0
		hex.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var closed := hex.duplicate()
	closed.append(hex[0])

	match _state:
		"done":
			draw_colored_polygon(hex, Color(0.42, 1.0, 0.78, 0.16))
			draw_polyline(closed, Color(0.42, 1.0, 0.78, 0.85), 1.3, true)
			var grow := 1.0 - _flash
			var check := PackedVector2Array(
				[
					center + Vector2(-3.6, 0.2),
					center + Vector2(-0.9, 2.9),
					center + Vector2(4.0, -3.2),
				]
			)
			if grow > 0.0:
				for i in range(1, check.size()):
					draw_line(
						check[i - 1],
						check[i - 1].lerp(check[i], clampf(grow * 2.0 - float(i - 1), 0.0, 1.0)),
						Color(0.42, 1.0, 0.78, 0.95),
						1.8,
						true
					)
		"active":
			var pulse := 0.5 + 0.5 * sin(_phase * 3.0)
			draw_circle(center, radius + 4.0, Color(0.98, 0.68, 0.3, 0.06 + pulse * 0.05))
			draw_polyline(closed, Color(0.98, 0.68, 0.3, 0.9), 1.4, true)
			draw_circle(center, 2.4 + pulse * 0.8, Color(0.98, 0.72, 0.36, 0.75 + pulse * 0.25))
		_:
			draw_polyline(closed, Color(0.5, 0.65, 0.7, 0.28), 1.2, true)


func _draw_pips(w: float) -> void:
	if _target <= 1 or _target > 10:
		return
	var count := mini(_target, 10)
	var total_w := float(count) * 9.0 - 3.0
	var start_x := w - 16.0 - total_w
	var y := 34.0
	for i in count:
		var filled := i < _count
		var color := Color(0.42, 1.0, 0.78, 0.85) if filled else Color(1, 1, 1, 0.12)
		if _state == "active" and not filled:
			color = Color(0.98, 0.68, 0.3, 0.35)
		draw_rect(Rect2(Vector2(start_x + i * 9.0, y), Vector2(6.0, 3.0)), color)
