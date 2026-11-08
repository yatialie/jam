extends CanvasLayer

## 全局关卡切换器：任意场景按 F7 打开，1-7 选择关卡。
## 如果当前处于 F4 布局模式，会先保存布局，切换后自动重新进入 F4。

const Catalog = preload("res://scripts/tools/level_catalog.gd")

const ACCENT := Color(0.32, 0.85, 0.93)
const TEXT := Color(0.78, 0.88, 0.9)
const MUTED := Color(0.42, 0.52, 0.55)

var _root: Control
var _panel: JamGlassPanel
var _rows: Array[Button] = []
var _message: Label
var _open := false
var _busy := false
var _prev_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_build_ui()
	_root.visible = false


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F7 or key.physical_keycode == KEY_F7:
		if _busy:
			return
		if _open:
			_close_panel()
		else:
			_open_panel()
		get_viewport().set_input_as_handled()
		return
	if not _open or _busy:
		return
	if key.keycode == KEY_ESCAPE:
		_close_panel()
		get_viewport().set_input_as_handled()
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_7:
		_select_index(key.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "LevelSwitcherRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.01, 0.018, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_panel = JamGlassPanel.new()
	_panel.name = "Panel"
	_panel.accent = ACCENT
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -310
	_panel.offset_bottom = 310
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var title := Label.new()
	title.text = "LEVEL SELECT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "7 SECTORS // 切换前自动保存当前布局"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", MUTED)
	box.add_child(sub)

	box.add_child(HSeparator.new())

	for i in Catalog.LEVELS.size():
		var row := Button.new()
		row.name = "LevelRow%d" % (i + 1)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0, 52)
		row.focus_mode = Control.FOCUS_NONE
		row.add_theme_font_size_override("font_size", 18)
		_style_row(row)
		row.pressed.connect(_on_level_pressed.bind(i))
		box.add_child(row)
		_rows.append(row)

	box.add_child(HSeparator.new())

	_message = Label.new()
	_message.custom_minimum_size = Vector2(0, 22)
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	box.add_child(_message)

	var hint := Label.new()
	hint.text = "数字键 1-7 选择  ·  F7 / Esc 关闭"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)


func _style_row(row: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.09, 0.55)
	normal.border_color = Color(0.2, 0.5, 0.56, 0.35)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.16, 0.2, 0.75)
	hover.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.65)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.2, 0.24, 0.9)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.02, 0.035, 0.045, 0.35)
	disabled.border_color = Color(0.16, 0.22, 0.24, 0.25)

	row.add_theme_stylebox_override("normal", normal)
	row.add_theme_stylebox_override("hover", hover)
	row.add_theme_stylebox_override("pressed", pressed)
	row.add_theme_stylebox_override("disabled", disabled)
	row.add_theme_color_override("font_color", TEXT)
	row.add_theme_color_override("font_hover_color", ACCENT)
	row.add_theme_color_override("font_pressed_color", ACCENT)
	row.add_theme_color_override("font_disabled_color", Color(0.32, 0.4, 0.42))


func _open_panel() -> void:
	_open = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_to_group("modal")
	_message.text = ""
	_refresh_rows()
	_root.visible = true


func _close_panel() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	remove_from_group("modal")
	Input.mouse_mode = _prev_mouse_mode


func _refresh_rows() -> void:
	var current_path := ""
	var scene := get_tree().current_scene
	if scene != null:
		current_path = scene.scene_file_path
	for i in Catalog.LEVELS.size():
		var entry: Dictionary = Catalog.LEVELS[i]
		var available := Catalog.is_available(entry)
		var is_current := available and str(entry.get("path", "")) == current_path
		var status := ""
		if is_current:
			status = "  · 当前"
		elif not available:
			status = "  · 未创建"
		var row := _rows[i]
		row.text = "%02d    %s%s" % [int(entry.get("number", i + 1)), str(entry.get("title", "")), status]
		row.disabled = not available
		row.add_theme_color_override("font_color", ACCENT if is_current else TEXT)


func _on_level_pressed(index: int) -> void:
	_select_index(index)


func _select_index(index: int) -> void:
	if index < 0 or index >= Catalog.LEVELS.size():
		return
	var entry: Dictionary = Catalog.LEVELS[index]
	if not Catalog.is_available(entry):
		_message.text = "该关卡尚未创建"
		return
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == str(entry.get("path", "")):
		_close_panel()
		return
	_switch_to(entry)


func _switch_to(entry: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_message.text = "正在切换..."
	var was_editing := LayoutTool.active
	if was_editing and not LayoutTool.save_and_exit():
		_message.text = "保存当前布局失败，已取消切换"
		_busy = false
		return
	_close_panel()
	await SceneFlow.change_scene(str(entry.get("path", "")))
	if was_editing:
		await get_tree().process_frame
		LayoutTool.enter_tool()
	_busy = false
