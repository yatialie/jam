extends CanvasLayer
class_name InteractPrompt

## 屏幕底部居中的通用交互提示：键帽 + 文案 + 锁定反馈副标题。

const FONT_UI := preload("res://ui/fonts/f_ui.tres")
const FONT_BOLD := preload("res://ui/fonts/f_ui_bold.tres")

var _root: Control
var _hint_label: Label
var _fade: Tween
var _hint_tween: Tween
var _shown := false


func _ready() -> void:
	layer = 6
	_build()
	_root.visible = false
	_root.modulate.a = 0.0


func set_prompt_visible(on: bool) -> void:
	if _shown == on:
		return
	_shown = on
	if _fade and _fade.is_valid():
		_fade.kill()
	if on:
		_root.visible = true
		_root.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 1.0, 0.14)
	else:
		_hint_label.modulate.a = 0.0
		if _hint_tween and _hint_tween.is_valid():
			_hint_tween.kill()
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 0.0, 0.12)
		_fade.tween_callback(_hide_root)


func flash_hint(text: String, duration := 1.4) -> void:
	_hint_label.text = text
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.1)
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.25)


func clear_hint() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.text = ""
	_hint_label.modulate.a = 0.0


func _hide_root() -> void:
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.name = "PromptRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.anchor_left = 0.5
	_root.anchor_top = 1.0
	_root.anchor_right = 0.5
	_root.anchor_bottom = 1.0
	_root.offset_left = -240.0
	_root.offset_top = -210.0
	_root.offset_right = 240.0
	_root.offset_bottom = -80.0
	add_child(_root)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(column)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)

	var pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0.03, 0.05, 0.07, 0.86)
	pill_style.border_color = Color(0.78, 0.92, 1.0, 0.24)
	pill_style.set_border_width_all(1)
	pill_style.set_corner_radius_all(8)
	pill_style.content_margin_left = 16.0
	pill_style.content_margin_right = 18.0
	pill_style.content_margin_top = 9.0
	pill_style.content_margin_bottom = 9.0
	pill.add_theme_stylebox_override("panel", pill_style)
	center.add_child(pill)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)

	var lead := Label.new()
	lead.text = "按"
	lead.add_theme_font_override("font", FONT_UI)
	lead.add_theme_font_size_override("font_size", 18)
	lead.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 0.9))
	row.add_child(lead)

	var keycap := PanelContainer.new()
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.96, 0.98, 1.0, 0.95)
	key_style.set_corner_radius_all(5)
	key_style.content_margin_left = 9.0
	key_style.content_margin_right = 9.0
	key_style.content_margin_top = 1.0
	key_style.content_margin_bottom = 1.0
	keycap.add_theme_stylebox_override("panel", key_style)
	row.add_child(keycap)

	var key_label := Label.new()
	key_label.text = "F"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_override("font", FONT_BOLD)
	key_label.add_theme_font_size_override("font_size", 20)
	key_label.add_theme_color_override("font_color", Color(0.04, 0.07, 0.09))
	keycap.add_child(key_label)

	var action := Label.new()
	action.text = "交互"
	action.add_theme_font_override("font", FONT_BOLD)
	action.add_theme_font_size_override("font_size", 20)
	action.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 0.95))
	row.add_child(action)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_override("font", FONT_UI)
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 1.0))
	_hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04, 0.9))
	_hint_label.add_theme_constant_override("outline_size", 4)
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_top = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_bottom = 0.0
	_hint_label.offset_left = 0.0
	_hint_label.offset_top = 56.0
	_hint_label.offset_right = 0.0
	_hint_label.offset_bottom = 80.0
	_hint_label.modulate.a = 0.0
	_root.add_child(_hint_label)
