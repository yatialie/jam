extends CanvasLayer

## 三环关节对齐小游戏。面板固定在大厅左侧，右半屏保留场景视野，
## 让玩家在解谜时能看见失控机械臂的预警动作。

signal solved
signal closed
signal joint_completed(index: int)

const JOINTS := ["SHOULDER", "ELBOW", "GRIPPER"]
const OFFSETS := [2, 3, 1]

var _root: Control
var _panel: PanelContainer
var _dim: ColorRect
var _flash: ColorRect
var _status: Label
var _code: Label
var _hint: Label
var _confirm: Button
var _abort: Button
var _dials: Array = []
var _arrows: Array = []
var _values: Array = []
var _targets: Array = []
var _joint_done: Array[bool] = [false, false, false]
var _solved := false
var _locked := false
var _closing := false
var _overload := false
var _overload_time := 1.6
var _overload_elapsed := 0.0
var _anytime_exit := false
var _escape_locked := false
var _exit_button: Button
var _danger: Control
var _danger_panel: Control
var _danger_vignette: ColorRect
var _danger_title: Label
var _danger_sub: Label
var _danger_sub_cn: Label
var _danger_tip: Label
var _danger_bar_fill: ColorRect
var _player: CharacterBody2D
var _panel_base := Vector2.ZERO


class RingDial:
	extends Control

	var value := 0
	var target := 0

	func _init() -> void:
		custom_minimum_size = Vector2(110, 110)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.38
		draw_circle(center, radius + 12.0, Color(0.02, 0.04, 0.055, 0.95))
		draw_arc(center, radius, 0.0, TAU, 40, Color(0.16, 0.28, 0.34), 12.0)
		draw_arc(center, radius, -PI * 0.5, PI * 1.5, 40, Color(0.24, 0.45, 0.52, 0.55), 2.0)

		for i in 8:
			var angle := -PI * 0.5 + TAU * float(i) / 8.0
			var inner := center + Vector2.RIGHT.rotated(angle) * (radius - 13.0)
			var outer := center + Vector2.RIGHT.rotated(angle) * (radius + 13.0)
			draw_line(inner, outer, Color(0.34, 0.48, 0.55, 0.8), 2.0)

		var target_angle := -PI * 0.5 + TAU * float(target) / 8.0
		draw_line(
			center + Vector2.RIGHT.rotated(target_angle) * (radius - 8.0),
			center + Vector2.RIGHT.rotated(target_angle) * (radius + 14.0),
			Color(1.0, 0.38, 0.28, 0.95), 5.0)

		var value_angle := -PI * 0.5 + TAU * float(value) / 8.0
		var marker := center + Vector2.RIGHT.rotated(value_angle) * radius
		draw_circle(marker, 8.0, Color(0.4, 0.95, 1.0))
		draw_circle(marker, 3.0, Color(0.95, 1.0, 1.0))

		var aligned := value == target
		var core := Color(0.2, 0.9, 0.6, 0.9) if aligned else Color(0.25, 0.45, 0.52, 0.9)
		draw_arc(center, radius * 0.46, 0.0, TAU, 28, core, 3.0)
		draw_circle(center, 2.5, core)


class DangerTriangle:
	extends Control

	func _init() -> void:
		custom_minimum_size = Vector2(200, 176)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var center := Vector2(w * 0.5, h * 0.62)
		var base := PackedVector2Array([
			Vector2(w * 0.5, 6.0),
			Vector2(w - 6.0, h - 6.0),
			Vector2(6.0, h - 6.0),
		])
		for i in 3:
			var grow := 1.0 + 0.055 * float(3 - i)
			var glow := PackedVector2Array()
			for point in base:
				glow.append(center + (point - center) * grow)
			draw_colored_polygon(glow, Color(1.0, 0.08, 0.05, 0.06 + 0.04 * float(i)))
		draw_colored_polygon(base, Color(0.42, 0.02, 0.02, 0.94))
		var closed := base.duplicate()
		closed.append(base[0])
		draw_polyline(closed, Color(1.0, 0.2, 0.14, 0.95), 6.0, true)
		draw_polyline(closed, Color(1.0, 0.58, 0.42, 0.35), 2.0, true)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("puzzle_ui")
	_build()
	_root.visible = false


func _process(delta: float) -> void:
	if not _overload:
		return
	_overload_elapsed += delta
	var remaining := clampf(1.0 - _overload_elapsed / maxf(_overload_time, 0.001), 0.0, 1.0)
	if _danger_bar_fill:
		_danger_bar_fill.scale.x = remaining
	var pulse := 0.5 + 0.5 * sin(_overload_elapsed * 15.0)
	if _danger_panel:
		_danger_panel.scale = Vector2.ONE * (1.0 + 0.035 * pulse)
	if _danger_vignette:
		_danger_vignette.color.a = 0.10 + 0.10 * pulse
	if _danger_title:
		_danger_title.modulate.a = 0.72 + 0.28 * pulse


func open() -> void:
	if _root.visible or _closing:
		return
	_root.visible = true
	add_to_group("modal")
	_solved = false
	_locked = false
	_closing = false
	_joint_done = [false, false, false]
	_reset_danger()
	_exit_button.visible = _anytime_exit
	_status.text = "AWAITING ALIGNMENT"
	_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	_code.visible = false
	_hint.text = "CLICK  <  >  TO ROTATE   ·   ESC TO ABORT"
	_confirm.disabled = true
	_abort.disabled = false
	if _escape_locked:
		_abort.disabled = true
		_abort.text = "LINK SEALED"
		_hint.text = "CONSOLE LINK SEALED — NO ESCAPE"
	_panel.modulate = Color.WHITE
	_panel.position = _panel_base
	_panel.scale = Vector2(0.97, 0.97)

	_randomize()
	_set_arrows_enabled(true)
	_refresh_dials()
	_freeze_player()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_root.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if _escape_locked:
		return
	if not _root.visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.14)
	tween.tween_property(_panel, "scale", Vector2(0.98, 0.98), 0.14)
	tween.finished.connect(_finish_close)


func is_open() -> bool:
	return _root.visible


func lock() -> void:
	_locked = true
	_abort.disabled = true
	_hint.text = "CONSOLE LOCK ENGAGED"


## 第二关专用：允许玩家在校准过程中随时退出。
func set_anytime_exit(value: bool) -> void:
	_anytime_exit = value
	if _exit_button:
		_exit_button.visible = value and _root.visible
	if _abort and not _overload:
		_abort.text = "EXIT CALIBRATION" if value else "ABORT"


## 第二关首次进入专用：校准一旦开始就锁死，无法通过 ESC 或按钮退出。
func set_escape_locked(value: bool) -> void:
	_escape_locked = value
	if _abort and not _overload:
		_abort.disabled = value
		_abort.text = "LINK SEALED" if value else ("EXIT CALIBRATION" if _anytime_exit else "ABORT")
	if _hint and not _overload:
		_hint.text = "CONSOLE LINK SEALED — NO ESCAPE" if value else "CLICK  <  >  TO ROTATE   ·   ESC TO ABORT"
	if _exit_button:
		_exit_button.visible = _anytime_exit and not value and _root.visible


## 第二关专用：第二关节对齐后机械臂失控，显示中央红色警报并开始反应倒计时。
func begin_overload(window: float) -> void:
	if _overload:
		return
	_overload = true
	_overload_time = maxf(window, 0.2)
	_overload_elapsed = 0.0
	_set_arrows_enabled(false)
	_confirm.disabled = true
	_abort.disabled = _escape_locked
	_abort.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
	if _escape_locked:
		_abort.text = "CONSOLE LOCKED"
		_hint.text = "CONSOLE LOCKED — NO ESCAPE"
		_status.text = "ELECTROCUTION — CANNOT DISENGAGE"
		_status.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
		if _danger_title:
			_danger_title.text = "CONSOLE LOCKED"
		if _danger_sub:
			_danger_sub.text = "ELECTROCUTION — CANNOT ESCAPE"
		if _danger_sub_cn:
			_danger_sub_cn.text = "操作台漏电，无法脱身"
		if _danger_tip:
			_danger_tip.text = "NO ESCAPE"
	else:
		_abort.text = "EMERGENCY EXIT"
		_hint.text = "ESC / EMERGENCY EXIT — LEAVE THE CONSOLE"
		_status.text = "ARM OVERLOAD — CONTROLS LOCKED"
		_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
		if _danger_title:
			_danger_title.text = "ARM OVERLOAD"
		if _danger_sub:
			_danger_sub.text = "LEAVE YOUR POSITION"
		if _danger_sub_cn:
			_danger_sub_cn.text = "立即离开操作台"
		if _danger_tip:
			_danger_tip.text = "ESC  /  EMERGENCY EXIT"
	_code.visible = false
	if _danger:
		_danger.visible = true
	if _danger_bar_fill:
		_danger_bar_fill.scale.x = 1.0
	if _exit_button and _anytime_exit and not _escape_locked:
		_exit_button.visible = true


func is_overload() -> bool:
	return _overload


## 玩家已按下退出、正在关闭面板时返回 true（关闭动画期间也算已离开）。
func is_exiting() -> bool:
	return _closing


func _reset_danger() -> void:
	_overload = false
	_overload_elapsed = 0.0
	if _danger:
		_danger.visible = false
	if _danger_bar_fill:
		_danger_bar_fill.scale.x = 1.0
	if _danger_panel:
		_danger_panel.scale = Vector2.ONE
	if _danger_title:
		_danger_title.text = "ARM OVERLOAD"
	if _danger_sub:
		_danger_sub.text = "LEAVE YOUR POSITION"
	if _danger_sub_cn:
		_danger_sub_cn.text = "立即离开操作台"
	if _danger_tip:
		_danger_tip.text = "ESC  /  EMERGENCY EXIT"
	if _abort:
		_abort.disabled = _escape_locked
		_abort.text = "LINK SEALED" if _escape_locked else ("EXIT CALIBRATION" if _anytime_exit else "ABORT")
		_abort.add_theme_color_override("font_color", Color(0.8, 0.92, 1.0))


func debug_solve() -> void:
	if not _root.visible or _solved:
		return
	for i in _values.size():
		_values[i] = _targets[i]
	_refresh_dials()
	_success(true)


func glitch(strength: float) -> void:
	if not _root.visible:
		return
	_panel.modulate = Color(1.0, 0.55, 0.48, 1.0)
	var tween := create_tween()
	for i in 4:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 10.0 * strength
		tween.tween_property(_panel, "position", _panel_base + offset, 0.04)
	tween.tween_property(_panel, "position", _panel_base, 0.06)
	tween.parallel().tween_property(_panel, "modulate", Color.WHITE, 0.18)


func shatter() -> void:
	if not _root.visible:
		return
	_locked = true
	_flash.visible = true
	_flash.color = Color(1.0, 0.25, 0.18, 0.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash, "color:a", 0.45, 0.05)
	flash_tween.tween_property(_flash, "color:a", 0.0, 0.32)

	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(1.0, 0.4, 0.32, 1.0), 0.06)
	tween.tween_property(_panel, "scale", Vector2(1.04, 0.96), 0.08)
	tween.tween_property(_panel, "scale", Vector2(0.9, 0.9), 0.2)
	tween.parallel().tween_property(_root, "modulate:a", 0.0, 0.2)
	tween.tween_callback(_finish_close)


func _finish_close() -> void:
	_root.visible = false
	_flash.visible = false
	_closing = false
	_reset_danger()
	remove_from_group("modal")
	_restore_player()
	closed.emit()


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
			if not _escape_locked and (_overload or _anytime_exit or (not _locked and not _solved)):
				close()
			return
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			if not _solved:
				get_viewport().set_input_as_handled()
				_submit()


func _randomize() -> void:
	_values.clear()
	_targets.clear()
	for i in JOINTS.size():
		var target := randi() % 8
		_targets.append(target)
		_values.append((target + int(OFFSETS[i])) % 8)


func _refresh_dials() -> void:
	for i in _dials.size():
		var dial = _dials[i]
		dial.value = _values[i]
		dial.target = _targets[i]
		dial.queue_redraw()
	_refresh_confirm()
	_check_joint_completion()


func _check_joint_completion() -> void:
	for i in _values.size():
		if _overload:
			return
		if _joint_done[i]:
			continue
		if _values[i] == _targets[i]:
			_joint_done[i] = true
			joint_completed.emit(i)


func _refresh_confirm() -> void:
	if _overload:
		return
	var aligned := true
	for i in _values.size():
		if _values[i] != _targets[i]:
			aligned = false
			break
	if not _solved:
		_confirm.disabled = not aligned
		_status.text = "ALL JOINTS ALIGNED" if aligned else "AWAITING ALIGNMENT"
		_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.72) if aligned else Color(1.0, 0.78, 0.35))


func _rotate(index: int, delta: int) -> void:
	if _solved or _locked or _overload:
		return
	_values[index] = (_values[index] + delta + 8) % 8
	_refresh_dials()


func _submit() -> void:
	if _solved:
		return
	var aligned := true
	for i in _values.size():
		if _values[i] != _targets[i]:
			aligned = false
			break
	if not aligned:
		_status.text = "ALIGNMENT INCOMPLETE"
		_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		var tween := create_tween()
		tween.tween_property(_panel, "position", _panel_base + Vector2(0, 8), 0.06)
		tween.tween_property(_panel, "position", _panel_base, 0.12)
		return
	_success(false)


func _success(dev: bool) -> void:
	if _solved:
		return
	_solved = true
	_set_arrows_enabled(false)
	_confirm.disabled = true
	_abort.disabled = true
	_locked = true
	_status.text = "ACCESS GRANTED // DEV" if dev else "CALIBRATION ACCEPTED"
	_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.62))
	_code.visible = true
	_code.text = "ARM SHUTDOWN CONFIRMED"
	_hint.text = "CONSOLE LOCK ENGAGED"
	solved.emit()


func _set_arrows_enabled(enabled: bool) -> void:
	for button in _arrows:
		button.disabled = not enabled


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

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.01, 0.015, 0.022, 0.34)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_panel = PanelContainer.new()
	_panel.position = Vector2(44, 150)
	_panel.size = Vector2(610, 760)
	_panel.pivot_offset = _panel.size * 0.5
	_panel_base = _panel.position
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.985)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.55, 0.62)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 26
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ARM JOINT ALIGNMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.84, 0.96, 1.0))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ROTATE EACH JOINT UNTIL IT MATCHES THE RED NOTCH"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.72, 0.8))
	box.add_child(subtitle)

	for i in JOINTS.size():
		box.add_child(_build_joint_row(i))

	_status = Label.new()
	_status.text = "AWAITING ALIGNMENT"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	box.add_child(_status)

	_code = Label.new()
	_code.text = ""
	_code.visible = false
	_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_size_override("font_size", 19)
	_code.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3))
	box.add_child(_code)

	_confirm = Button.new()
	_confirm.text = "CONFIRM ALIGNMENT"
	_confirm.custom_minimum_size = Vector2(0, 50)
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.add_theme_font_size_override("font_size", 18)
	_apply_simple_style(_confirm, Color(0.25, 0.72, 0.78))
	_confirm.disabled = true
	_confirm.pressed.connect(_submit)
	box.add_child(_confirm)

	_abort = Button.new()
	_abort.text = "ABORT"
	_abort.custom_minimum_size = Vector2(0, 42)
	_abort.focus_mode = Control.FOCUS_NONE
	_abort.add_theme_font_size_override("font_size", 15)
	_apply_simple_style(_abort, Color(0.62, 0.42, 0.18))
	_abort.pressed.connect(close)
	box.add_child(_abort)

	_hint = Label.new()
	_hint.text = "CLICK  <  >  TO ROTATE   ·   ESC TO ABORT"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.45, 0.58, 0.66))
	box.add_child(_hint)

	_build_exit_button()
	_build_danger()

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.25, 0.18, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	_root.add_child(_flash)


func _build_exit_button() -> void:
	_exit_button = Button.new()
	_exit_button.text = "✕  EXIT"
	_exit_button.focus_mode = Control.FOCUS_NONE
	_exit_button.position = _panel_base + Vector2(_panel.size.x - 132.0, 10.0)
	_exit_button.size = Vector2(120.0, 34.0)
	_exit_button.add_theme_font_size_override("font_size", 14)
	_exit_button.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62))
	_apply_simple_style(_exit_button, Color(0.85, 0.32, 0.24))
	_exit_button.pressed.connect(close)
	_exit_button.visible = false
	_root.add_child(_exit_button)


func _build_danger() -> void:
	_danger = Control.new()
	_danger.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.visible = false
	_root.add_child(_danger)

	_danger_vignette = ColorRect.new()
	_danger_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_danger_vignette.color = Color(0.55, 0.02, 0.02, 0.16)
	_danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.add_child(_danger_vignette)

	_danger_panel = Control.new()
	_danger_panel.anchor_left = 0.5
	_danger_panel.anchor_right = 0.5
	_danger_panel.anchor_top = 0.5
	_danger_panel.anchor_bottom = 0.5
	_danger_panel.offset_left = -320.0
	_danger_panel.offset_right = 320.0
	_danger_panel.offset_top = -230.0
	_danger_panel.offset_bottom = 230.0
	_danger_panel.pivot_offset = Vector2(320.0, 230.0)
	_danger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger.add_child(_danger_panel)

	var triangle := DangerTriangle.new()
	triangle.position = Vector2(220.0, 0.0)
	triangle.size = Vector2(200.0, 176.0)
	_danger_panel.add_child(triangle)

	var mark := Label.new()
	mark.text = "!"
	mark.position = Vector2(220.0, 26.0)
	mark.size = Vector2(200.0, 136.0)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", 96)
	mark.add_theme_color_override("font_color", Color(1.0, 0.92, 0.88))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(mark)

	_danger_title = Label.new()
	_danger_title.text = "ARM OVERLOAD"
	_danger_title.position = Vector2(0.0, 186.0)
	_danger_title.size = Vector2(640.0, 54.0)
	_danger_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_danger_title.add_theme_font_size_override("font_size", 46)
	_danger_title.add_theme_color_override("font_color", Color(1.0, 0.28, 0.2))
	_danger_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(_danger_title)

	var subtitle := Label.new()
	subtitle.text = "LEAVE YOUR POSITION"
	subtitle.position = Vector2(0.0, 244.0)
	subtitle.size = Vector2(640.0, 40.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.72, 0.6))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(subtitle)
	_danger_sub = subtitle

	var subtitle_cn := Label.new()
	subtitle_cn.text = "立即离开操作台"
	subtitle_cn.position = Vector2(0.0, 286.0)
	subtitle_cn.size = Vector2(640.0, 32.0)
	subtitle_cn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_cn.add_theme_font_size_override("font_size", 20)
	subtitle_cn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	subtitle_cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(subtitle_cn)
	_danger_sub_cn = subtitle_cn

	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(140.0, 334.0)
	bar_bg.size = Vector2(360.0, 10.0)
	bar_bg.color = Color(0.25, 0.02, 0.02, 0.85)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(bar_bg)

	_danger_bar_fill = ColorRect.new()
	_danger_bar_fill.position = Vector2(140.0, 334.0)
	_danger_bar_fill.size = Vector2(360.0, 10.0)
	_danger_bar_fill.pivot_offset = Vector2(0.0, 5.0)
	_danger_bar_fill.color = Color(1.0, 0.22, 0.16, 0.95)
	_danger_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(_danger_bar_fill)

	var tip := Label.new()
	tip.text = "ESC  /  EMERGENCY EXIT"
	tip.position = Vector2(0.0, 356.0)
	tip.size = Vector2(640.0, 30.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_danger_panel.add_child(tip)
	_danger_tip = tip


func _build_joint_row(index: int) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 124)
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var dial := RingDial.new()
	_dials.append(dial)
	row.add_child(dial)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(180, 0)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = JOINTS[index]
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.9))
	info.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "NOTCH %d" % (index + 1)
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_color_override("font_color", Color(0.48, 0.6, 0.68))
	info.add_child(value_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	info.add_child(buttons)

	var left := _make_arrow("<")
	left.pressed.connect(_rotate.bind(index, -1))
	buttons.add_child(left)
	_arrows.append(left)

	var right := _make_arrow(">")
	right.pressed.connect(_rotate.bind(index, 1))
	buttons.add_child(right)
	_arrows.append(right)

	return row


func _make_arrow(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(64, 38)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	_apply_simple_style(button, Color(0.2, 0.55, 0.62))
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
