extends CanvasLayer

## Four-digit security keypad for the cockpit door.

signal solved

const BLUR_SHADER := preload("res://ui/shaders/modal_blur.gdshader")
const CAPACITY := 4

@export var door_code := "0925"

var _root: Control
var _blur: ColorRect
var _panel: PanelContainer
var _digit_labels: Array[Label] = []
var _key_buttons: Array[Button] = []
var _status: Label
var _dev_button: Button
var _player: CharacterBody2D
var _door: Node
var _buffer := ""
var _solved := false
var _closing := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("keypad_ui")
	add_to_group("puzzle_ui")
	_build()
	_root.visible = false


func _process(_delta: float) -> void:
	if _root.visible:
		_sync_dev_button()


func open() -> void:
	if _root.visible or _closing:
		return
	_root.visible = true
	add_to_group("modal")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_freeze_player()

	_buffer = ""
	_solved = false
	_set_keys_enabled(true)
	_refresh_display()
	_status.text = "AWAITING INPUT"
	_status.add_theme_color_override("font_color", Color(1, 0.78, 0.35))
	_panel.modulate = Color(1, 1, 1, 1)

	_root.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.965, 0.965)
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", 0.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 0.0, 1.0, 0.24)

	_sync_dev_button()


func close() -> void:
	if not _root.visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2(0.975, 0.975), 0.16)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 1.0, 0.0, 0.16)
	tween.finished.connect(_finish_close)


func is_open() -> bool:
	return _root.visible


func debug_solve() -> void:
	if not _root.visible or _solved:
		return
	_success(true)


func _finish_close() -> void:
	_root.visible = false
	_closing = false
	remove_from_group("modal")
	_restore_player()


func _set_blur_fade(value: float) -> void:
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", value)


func _input(event: InputEvent) -> void:
	if not _root.visible or _closing:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var code: int = key.keycode if key.keycode != 0 else key.physical_keycode
		if code == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
			return
		if _solved:
			return
		if code >= KEY_0 and code <= KEY_9:
			get_viewport().set_input_as_handled()
			_push_digit(str(code - KEY_0))
		elif code == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			if not _buffer.is_empty():
				_buffer = _buffer.substr(0, _buffer.length() - 1)
				_refresh_display()
		elif code == KEY_ENTER or code == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_submit()
		elif code == KEY_C:
			get_viewport().set_input_as_handled()
			_buffer = ""
			_refresh_display()


func _push_digit(digit: String) -> void:
	if _solved or _buffer.length() >= CAPACITY:
		return
	_buffer += digit
	_refresh_display()
	if _buffer.length() < CAPACITY:
		_status.text = "AWAITING INPUT"
		_status.add_theme_color_override("font_color", Color(1, 0.78, 0.35))


func _submit() -> void:
	if _buffer.length() < CAPACITY:
		_status.text = "ENTER 4 DIGITS"
		_status.add_theme_color_override("font_color", Color(1, 0.66, 0.26))
		_nudge()
		return
	if _buffer == door_code:
		_success(false)
	else:
		_fail()


func _success(dev: bool) -> void:
	if _solved:
		return
	_solved = true
	_set_keys_enabled(false)
	if _door == null or not is_instance_valid(_door):
		_door = get_tree().get_first_node_in_group("main_door")
	if _door == null:
		_door = get_tree().get_first_node_in_group("access_door")
	if _door and _door.has_method("unlock"):
		_door.call("unlock")
	_status.text = "ACCESS GRANTED // DEV" if dev else "ACCESS GRANTED"
	_status.add_theme_color_override("font_color", Color(0.4, 1, 0.62))
	_panel.modulate = Color(0.82, 1.0, 0.9, 1.0)
	solved.emit()
	await get_tree().create_timer(1.15).timeout
	close()


func _fail() -> void:
	_status.text = "ACCESS DENIED"
	_status.add_theme_color_override("font_color", Color(1, 0.34, 0.28))
	_nudge()
	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(1, 0.62, 0.6, 1), 0.08)
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 1), 0.2)
	await get_tree().create_timer(0.32).timeout
	if not _solved:
		_buffer = ""
		_refresh_display()


func _nudge() -> void:
	_panel.pivot_offset = _panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(_panel, "scale", Vector2(1.012, 1.012), 0.06)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)


func _refresh_display() -> void:
	for i in _digit_labels.size():
		var label := _digit_labels[i]
		if i < _buffer.length():
			label.text = _buffer[i]
			label.add_theme_color_override("font_color", Color(0.72, 0.98, 1.0))
		else:
			label.text = "\u00b7"
			label.add_theme_color_override("font_color", Color(0.28, 0.4, 0.48))


func _set_keys_enabled(enabled: bool) -> void:
	for button in _key_buttons:
		button.disabled = not enabled


func _sync_dev_button() -> void:
	var manager := get_node_or_null("/root/DebugManager")
	var dev_visible := false
	if manager != null:
		dev_visible = bool(manager.get("enabled"))
	if _dev_button.visible != dev_visible:
		_dev_button.visible = dev_visible


func _freeze_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player == null:
		return
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	if _player.has_method("_set_aiming"):
		_player.call("_set_aiming", false)


func _restore_player() -> void:
	if _player and is_instance_valid(_player):
		_player.set_physics_process(true)
	_player = null


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var back := BackBufferCopy.new()
	back.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(back)

	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BLUR_SHADER
	material.set_shader_parameter("blur_radius", 2.6)
	material.set_shader_parameter("darken", 0.62)
	material.set_shader_parameter("tint", 0.34)
	material.set_shader_parameter("tint_color", Color(0.02, 0.05, 0.065, 1.0))
	material.set_shader_parameter("fade", 1.0)
	_blur.material = material
	_root.add_child(_blur)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 764)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.085, 0.985)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.55, 0.62)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel_style.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "SECURITY KEYPAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "CREW ACCESS  //  4-DIGIT CODE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.72, 0.8))
	box.add_child(subtitle)

	var display_center := CenterContainer.new()
	box.add_child(display_center)

	var display := HBoxContainer.new()
	display.add_theme_constant_override("separation", 12)
	display_center.add_child(display)

	for i in CAPACITY:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(76, 96)
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.03, 0.05, 0.07, 0.98)
		slot_style.border_width_left = 1
		slot_style.border_width_top = 1
		slot_style.border_width_right = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.18, 0.4, 0.46)
		slot_style.corner_radius_top_left = 8
		slot_style.corner_radius_top_right = 8
		slot_style.corner_radius_bottom_left = 8
		slot_style.corner_radius_bottom_right = 8
		slot.add_theme_stylebox_override("panel", slot_style)
		display.add_child(slot)

		var digit := Label.new()
		digit.text = "\u00b7"
		digit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		digit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		digit.add_theme_font_size_override("font_size", 42)
		digit.add_theme_color_override("font_color", Color(0.28, 0.4, 0.48))
		slot.add_child(digit)
		_digit_labels.append(digit)

	_status = Label.new()
	_status.text = "AWAITING INPUT"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(1, 0.78, 0.35))
	box.add_child(_status)

	var pad_center := CenterContainer.new()
	box.add_child(pad_center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	pad_center.add_child(grid)

	var labels := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "ENTER"]
	for label_text in labels:
		var button := _make_key_button(label_text)
		button.pressed.connect(_on_key_pressed.bind(label_text))
		grid.add_child(button)
		_key_buttons.append(button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	box.add_child(actions)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(150, 44)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 17)
	_apply_simple_style(close_button, Color(0.2, 0.55, 0.62))
	close_button.pressed.connect(close)
	actions.add_child(close_button)

	var clear_button := Button.new()
	clear_button.text = "CLEAR"
	clear_button.custom_minimum_size = Vector2(150, 44)
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.add_theme_font_size_override("font_size", 17)
	_apply_simple_style(clear_button, Color(0.62, 0.42, 0.18))
	clear_button.pressed.connect(_on_clear)
	actions.add_child(clear_button)

	var dev_style := StyleBoxFlat.new()
	dev_style.bg_color = Color(0.24, 0.12, 0.05, 0.96)
	dev_style.border_width_left = 2
	dev_style.border_width_top = 2
	dev_style.border_width_right = 2
	dev_style.border_width_bottom = 2
	dev_style.border_color = Color(0.95, 0.6, 0.2)
	dev_style.corner_radius_top_left = 8
	dev_style.corner_radius_top_right = 8
	dev_style.corner_radius_bottom_left = 8
	dev_style.corner_radius_bottom_right = 8

	_dev_button = Button.new()
	_dev_button.text = "DEV UNLOCK (G)"
	_dev_button.custom_minimum_size = Vector2(180, 44)
	_dev_button.add_theme_font_size_override("font_size", 15)
	_dev_button.add_theme_stylebox_override("normal", dev_style)
	_dev_button.add_theme_stylebox_override("hover", dev_style)
	_dev_button.add_theme_stylebox_override("pressed", dev_style)
	_dev_button.add_theme_stylebox_override("focus", dev_style)
	_dev_button.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	_dev_button.focus_mode = Control.FOCUS_NONE
	_dev_button.visible = false
	_dev_button.pressed.connect(debug_solve)
	actions.add_child(_dev_button)

	var hint := Label.new()
	hint.text = "TYPE DIGITS OR CLICK  \u00b7  ESC TO CLOSE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.56, 0.64))
	box.add_child(hint)


func _on_key_pressed(label_text: String) -> void:
	if _solved:
		return
	if label_text == "C":
		_on_clear()
	elif label_text == "ENTER":
		_submit()
	else:
		_push_digit(label_text)


func _on_clear() -> void:
	if _solved:
		return
	_buffer = ""
	_refresh_display()
	_status.text = "AWAITING INPUT"
	_status.add_theme_color_override("font_color", Color(1, 0.78, 0.35))


func _make_key_button(label_text: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(140, 72)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26 if label_text.length() == 1 else 18)
	var accent := Color(0.2, 0.55, 0.62)
	if label_text == "C":
		accent = Color(0.62, 0.42, 0.18)
	elif label_text == "ENTER":
		accent = Color(0.25, 0.72, 0.78)
	_apply_simple_style(button, accent)
	return button


func _apply_simple_style(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.08, 0.11, 0.98)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.18, 0.27, 0.33)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.08, 0.15, 0.19, 1.0)
	hover.border_color = accent

	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent.r * 0.45, accent.g * 0.45, accent.b * 0.45, 1.0)
	pressed.border_color = accent

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", normal)
	button.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.32, 0.4, 0.46))
