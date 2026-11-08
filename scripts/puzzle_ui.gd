extends CanvasLayer

signal solved

const GRID_SIZE := 3

var _root: Control
var _grid: GridContainer
var _status: Label
var _buttons: Array = []
var _states: Array = []
var _initial: Array = []
var _solved := false
var _player: CharacterBody2D
var _debug_button: Button
var _debug_hint: Label

var _on_style: StyleBoxFlat
var _off_style: StyleBoxFlat


func _ready() -> void:
	layer = 20
	add_to_group("puzzle_ui")
	_build()
	_root.visible = false


func _process(_delta: float) -> void:
	if _root.visible:
		_sync_debug_button()


func open() -> void:
	if _root.visible:
		return
	_root.visible = true
	add_to_group("modal")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_sync_debug_button()

	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_player.set_physics_process(false)
		_player.velocity = Vector2.ZERO

	_scramble()


func close() -> void:
	_root.visible = false
	remove_from_group("modal")
	if _player:
		_player.set_physics_process(true)
		_player = null


func is_open() -> bool:
	return _root.visible


func debug_solve() -> void:
	if not _root.visible or _solved or not _debug_enabled():
		return
	for i in _states.size():
		_states[i] = true
	_refresh()
	_win()
	_status.text = "ACCESS GRANTED  //  DEV SKIP"


func _debug_enabled() -> bool:
	var manager := get_node_or_null("/root/DebugManager")
	return manager != null and manager.enabled


func _sync_debug_button() -> void:
	var show := _debug_enabled()
	if _debug_button.visible != show:
		_debug_button.visible = show
		_debug_hint.visible = show


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 560)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.1, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.2, 0.55, 0.62)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ACCESS OVERRIDE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Toggle tiles until all nodes are online"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.72, 0.8))
	box.add_child(subtitle)

	_on_style = StyleBoxFlat.new()
	_on_style.bg_color = Color(0.1, 0.5, 0.56)
	_on_style.border_width_left = 2
	_on_style.border_width_top = 2
	_on_style.border_width_right = 2
	_on_style.border_width_bottom = 2
	_on_style.border_color = Color(0.45, 0.95, 1.0)
	_on_style.corner_radius_top_left = 8
	_on_style.corner_radius_top_right = 8
	_on_style.corner_radius_bottom_left = 8
	_on_style.corner_radius_bottom_right = 8

	_off_style = StyleBoxFlat.new()
	_off_style.bg_color = Color(0.08, 0.1, 0.14)
	_off_style.border_width_left = 2
	_off_style.border_width_top = 2
	_off_style.border_width_right = 2
	_off_style.border_width_bottom = 2
	_off_style.border_color = Color(0.22, 0.28, 0.34)
	_off_style.corner_radius_top_left = 8
	_off_style.corner_radius_top_right = 8
	_off_style.corner_radius_bottom_left = 8
	_off_style.corner_radius_bottom_right = 8

	var grid_center := CenterContainer.new()
	box.add_child(grid_center)

	_grid = GridContainer.new()
	_grid.columns = GRID_SIZE
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	grid_center.add_child(_grid)

	for i in 9:
		var button := Button.new()
		button.name = "Cell%d" % i
		button.custom_minimum_size = Vector2(100, 100)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_cell_pressed.bind(i))
		_grid.add_child(button)
		_buttons.append(button)
		_states.append(false)

	_status = Label.new()
	_status.text = "TURN ALL NODES ONLINE"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	box.add_child(_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	box.add_child(actions)

	var reset_button := Button.new()
	reset_button.text = "RESET"
	reset_button.custom_minimum_size = Vector2(140, 44)
	reset_button.add_theme_font_size_override("font_size", 18)
	reset_button.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(140, 44)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(close)
	actions.add_child(close_button)

	var dev_style := StyleBoxFlat.new()
	dev_style.bg_color = Color(0.24, 0.12, 0.05)
	dev_style.border_width_left = 2
	dev_style.border_width_top = 2
	dev_style.border_width_right = 2
	dev_style.border_width_bottom = 2
	dev_style.border_color = Color(0.95, 0.6, 0.2)
	dev_style.corner_radius_top_left = 8
	dev_style.corner_radius_top_right = 8
	dev_style.corner_radius_bottom_left = 8
	dev_style.corner_radius_bottom_right = 8

	_debug_button = Button.new()
	_debug_button.text = "DEV SKIP (G)"
	_debug_button.custom_minimum_size = Vector2(170, 44)
	_debug_button.add_theme_font_size_override("font_size", 16)
	_debug_button.add_theme_stylebox_override("normal", dev_style)
	_debug_button.add_theme_stylebox_override("hover", dev_style)
	_debug_button.add_theme_stylebox_override("pressed", dev_style)
	_debug_button.add_theme_stylebox_override("focus", dev_style)
	_debug_button.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35))
	_debug_button.focus_mode = Control.FOCUS_NONE
	_debug_button.tooltip_text = "Developer mode only: complete this puzzle instantly"
	_debug_button.visible = false
	_debug_button.pressed.connect(debug_solve)
	actions.add_child(_debug_button)

	_debug_hint = Label.new()
	_debug_hint.text = "DEV MODE   ·   PRESS G OR DEV SKIP TO COMPLETE"
	_debug_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_hint.add_theme_font_size_override("font_size", 13)
	_debug_hint.add_theme_color_override("font_color", Color(1.0, 0.68, 0.3))
	_debug_hint.visible = false
	box.add_child(_debug_hint)

	var hint := Label.new()
	hint.text = "Solve the circuit to unlock the door"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.56, 0.64))
	box.add_child(hint)


func _scramble() -> void:
	_states = []
	for i in 9:
		_states.append(true)

	for i in 6:
		_apply_toggle(randi() % 9)

	if _all_on():
		_apply_toggle(4)

	_initial = _states.duplicate()
	_solved = false
	_set_buttons_enabled(true)
	_status.text = "TURN ALL NODES ONLINE"
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_refresh()


func _apply_toggle(index: int) -> void:
	_states[index] = not _states[index]
	var x := index % GRID_SIZE
	var y := index / GRID_SIZE
	if x > 0:
		_states[index - 1] = not _states[index - 1]
	if x < GRID_SIZE - 1:
		_states[index + 1] = not _states[index + 1]
	if y > 0:
		_states[index - GRID_SIZE] = not _states[index - GRID_SIZE]
	if y < GRID_SIZE - 1:
		_states[index + GRID_SIZE] = not _states[index + GRID_SIZE]


func _refresh() -> void:
	for i in _buttons.size():
		var button: Button = _buttons[i]
		var on: bool = _states[i]
		var style := _on_style if on else _off_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("disabled", style)
		button.text = "ON" if on else ""
		button.add_theme_color_override("font_color", Color(0.9, 1, 1) if on else Color(0.35, 0.4, 0.45))


func _all_on() -> bool:
	for state in _states:
		if not state:
			return false
	return true


func _on_cell_pressed(index: int) -> void:
	if _solved:
		return
	_apply_toggle(index)
	_refresh()
	if _all_on():
		_win()


func _win() -> void:
	if _solved:
		return
	_solved = true
	solved.emit()
	_status.text = "ACCESS GRANTED"
	_status.add_theme_color_override("font_color", Color(0.4, 1, 0.6))
	_set_buttons_enabled(false)

	var door := get_tree().get_first_node_in_group("access_door")
	if door and door.has_method("unlock"):
		door.unlock()

	await get_tree().create_timer(1.2).timeout
	close()


func _on_reset_pressed() -> void:
	if _solved:
		return
	_states = _initial.duplicate()
	_refresh()


func _set_buttons_enabled(enabled: bool) -> void:
	for button in _buttons:
		button.disabled = not enabled
