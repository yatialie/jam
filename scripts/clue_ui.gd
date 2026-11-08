extends CanvasLayer

## Full-screen close-up of the wall calendar. Freezes the player while open.

signal closed

const BLUR_SHADER := preload("res://ui/shaders/modal_blur.gdshader")
const PAPER_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/cockpit/ui/calendar_paper_torn.png")

var _root: Control
var _blur: ColorRect
var _paper_wrap: Control
var _player: CharacterBody2D
var _closing := false
var _ignore_input_until := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("clue_ui")
	_build()
	_root.visible = false


func open() -> void:
	if _root.visible or _closing:
		return
	_root.visible = true
	add_to_group("modal")
	_ignore_input_until = Time.get_ticks_msec() + 180
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_freeze_player()

	_root.modulate.a = 0.0
	_paper_wrap.pivot_offset = _paper_wrap.size * 0.5
	_paper_wrap.scale = Vector2(0.965, 0.965)
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", 0.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_property(_paper_wrap, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 0.0, 1.0, 0.26)


func close() -> void:
	if not _root.visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.16)
	tween.tween_property(_paper_wrap, "scale", Vector2(0.975, 0.975), 0.16)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 1.0, 0.0, 0.16)
	tween.finished.connect(_finish_close)


func is_open() -> bool:
	return _root.visible


func _finish_close() -> void:
	_root.visible = false
	_closing = false
	remove_from_group("modal")
	_restore_player()
	closed.emit()


func _set_blur_fade(value: float) -> void:
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", value)


func _input(event: InputEvent) -> void:
	if not _root.visible or _closing:
		return
	if Time.get_ticks_msec() < _ignore_input_until:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


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
	material.set_shader_parameter("blur_radius", 2.8)
	material.set_shader_parameter("darken", 0.58)
	material.set_shader_parameter("tint", 0.38)
	material.set_shader_parameter("tint_color", Color(0.02, 0.05, 0.065, 1.0))
	material.set_shader_parameter("fade", 1.0)
	_blur.material = material
	_root.add_child(_blur)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	_paper_wrap = Control.new()
	_paper_wrap.custom_minimum_size = Vector2(540, 810)
	column.add_child(_paper_wrap)

	var paper := TextureRect.new()
	paper.texture = PAPER_TEXTURE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper_wrap.add_child(paper)

	var close_button := Button.new()
	close_button.text = "CLOSE  [F]"
	close_button.custom_minimum_size = Vector2(210, 46)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 18)
	_apply_button_style(close_button)
	close_button.pressed.connect(close)
	column.add_child(close_button)

	var hint := Label.new()
	hint.text = "EVIDENCE LOGGED  //  09.25"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.46, 0.86, 0.95))
	column.add_child(hint)


func _apply_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.09, 0.12, 0.96)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.2, 0.55, 0.62)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8

	var hover := normal.duplicate()
	hover.bg_color = Color(0.08, 0.16, 0.2, 0.98)
	hover.border_color = Color(0.45, 0.95, 1.0)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.14, 0.42, 0.48, 0.98)

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, normal if state == "disabled" else (hover if state == "hover" else (pressed if state == "pressed" else normal)))
	button.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
