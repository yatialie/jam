class_name JamStoryNarration
extends CanvasLayer

## 上方旁白对话框：屏幕中央偏上，右侧黑色人物剪影，面板样式沿用内心独白。
## 播放期间硬控玩家，按空格/回车/左键逐句推进，最后一句关闭后解除控制。

signal line_started(index: int, text: String)
signal finished()

const MONOLOGUE_SCRIPT := preload("res://scripts/monologue_overlay.gd")
const FONT_CN: Font = preload("res://ui/fonts/f_ui.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")

const PANEL_W := 1120.0
const PANEL_H := 300.0
const PANEL_TOP := 110.0
const TEXT_X := 58.0
const TEXT_W := 700.0
const BODY_Y := 92.0
const BODY_H := 140.0
const TYPING_CPS := 26.0

const CYAN := Color(0.36, 0.87, 0.95)
const BODY_COLOR := Color(0.87, 0.93, 0.95)

var _root: Control
var _scrim: Scrim
var _panel: Control
var _frame
var _silhouette: Silhouette
var _tag_label: Label
var _body: RichTextLabel
var _hint: Label
var _counter: Label

var _lines: Array = []
var _index := -1
var _text := ""
var _active := false
var _closing := false
var _started := false
var _typing := false
var _shown := 0
var _total := 0
var _typing_progress := 0.0
var _char_pause := 0.0
var _time := 0.0
var _run_id := 0
var _player_states: Array = []
var _anim: Tween


func _ready() -> void:
	layer = 79
	visible = false
	_build()


func is_playing() -> bool:
	return _active


func is_typing() -> bool:
	return _typing


## options.delay：先硬控玩家，等待指定秒数后再显示对话框。
func play(lines: Array, options: Dictionary = {}) -> void:
	var cleaned: Array = []
	for entry in lines:
		if entry is Dictionary:
			if not str(entry.get("text", "")).is_empty():
				cleaned.append(entry)
		elif not str(entry).is_empty():
			cleaned.append(str(entry))
	if cleaned.is_empty():
		return

	var run_id := _run_id + 1
	_run_id = run_id
	_lines = cleaned
	_active = true
	_closing = false
	_started = false
	_typing = false
	_index = -1
	_time = 0.0
	visible = true
	add_to_group("modal")
	_set_player_frozen(true)
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_anim()

	var delay := maxf(float(options.get("delay", 0.0)), 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if run_id != _run_id or not _active:
			return

	_root.visible = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.modulate.a = 0.0
	_panel.position = _rest_position() + Vector2(0.0, -18.0)
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_root, "modulate:a", 1.0, 0.26)
	_anim.tween_property(_panel, "position", _rest_position(), 0.38).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	_anim.set_parallel(false)
	_anim.tween_callback(_begin_lines)


func advance() -> void:
	if not _active or _closing or not _started:
		return
	if _typing:
		_typing = false
		_char_pause = 0.0
		_body.text = _text
		_body.visible_characters = -1
		_show_continue_hint()
		return
	if _index + 1 < _lines.size():
		_show_line(_index + 1)
	else:
		close()


func close() -> void:
	if not _active or _closing:
		return
	_closing = true
	_typing = false
	_kill_anim()
	_anim = create_tween()
	_anim.tween_property(_root, "modulate:a", 0.0, 0.24)
	await _anim.finished
	_finish_state()


func hide_now() -> void:
	if not _active:
		return
	_kill_anim()
	_finish_state()


func _finish_state() -> void:
	var was_active := _active
	_active = false
	_closing = false
	_started = false
	_typing = false
	_index = -1
	visible = false
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 1.0
	remove_from_group("modal")
	_set_player_frozen(false)
	if was_active:
		finished.emit()


func _begin_lines() -> void:
	_started = true
	_frame.target_progress = 0.0
	_frame.progress = 0.0
	_show_line(0)


func _input(event: InputEvent) -> void:
	if not _active or not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			advance()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or not _root.visible:
		return
	_time += delta
	_hint.modulate.a = 0.55 + 0.35 * sin(_time * 3.4)
	if not _typing:
		return
	if _char_pause > 0.0:
		_char_pause -= delta
		return

	_typing_progress += delta * TYPING_CPS
	var target := mini(int(_typing_progress), _total)
	if target > _shown:
		var ch := _text.substr(target - 1, 1)
		if "，、；：".contains(ch):
			_char_pause = 0.09
		elif "。！？…".contains(ch):
			_char_pause = 0.22
		_shown = target
		_body.visible_characters = _shown

	if _shown >= _total:
		_finish_typing()


func _finish_typing() -> void:
	_typing = false
	_body.text = _text
	_body.visible_characters = -1
	_show_continue_hint()


func _show_continue_hint() -> void:
	_hint.text = "▸  空格 / 左键  继续"
	_hint.visible = true


func _show_line(index: int) -> void:
	_index = index
	var entry: Variant = _lines[index]
	_text = str(entry.get("text", "")) if entry is Dictionary else str(entry)
	_body.text = _text
	_body.visible_characters = 0
	_shown = 0
	_total = _text.length()
	_typing_progress = 0.0
	_char_pause = 0.0
	_typing = _total > 0
	_hint.text = "记录中…"
	_hint.visible = true
	_counter.text = "%02d / %02d" % [index + 1, _lines.size()]
	_frame.target_progress = float(index + 1) / float(_lines.size())
	line_started.emit(index, _text)
	if not _typing:
		_finish_typing()


func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		if not _player_states.is_empty():
			return
		for node in get_tree().get_nodes_in_group("player"):
			if node == null:
				continue
			_player_states.append({"node": node, "physics": node.is_physics_processing()})
			node.set_physics_process(false)
			if node is CharacterBody2D:
				node.velocity = Vector2.ZERO
	else:
		for state in _player_states:
			var node: Variant = state.get("node")
			if is_instance_valid(node):
				node.set_physics_process(bool(state.get("physics", true)))
		_player_states.clear()


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.resized.connect(_layout)
	_root.gui_input.connect(_on_gui_input)

	_scrim = Scrim.new()
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_scrim)

	_panel = Control.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)

	_frame = MONOLOGUE_SCRIPT.PanelArt.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.text_x = TEXT_X
	_frame.header_y = 64.0
	_frame.footer_y = 238.0
	_panel.add_child(_frame)

	_tag_label = _make_label(FONT_CN, 12, Color(CYAN, 0.7), "旁白  /  NARRATION")
	_tag_label.position = Vector2(TEXT_X + 14.0, 30.0)
	_tag_label.size = Vector2(420.0, 20.0)
	_panel.add_child(_tag_label)

	_body = RichTextLabel.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.bbcode_enabled = false
	_body.fit_content = false
	_body.scroll_active = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.position = Vector2(TEXT_X, BODY_Y)
	_body.size = Vector2(TEXT_W, BODY_H)
	_body.add_theme_font_override("normal_font", FONT_CN)
	_body.add_theme_font_size_override("normal_font_size", 26)
	_body.add_theme_constant_override("line_separation", 12)
	_body.add_theme_color_override("default_color", BODY_COLOR)
	_panel.add_child(_body)

	_silhouette = Silhouette.new()
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_silhouette.position = Vector2(PANEL_W - 306.0, -20.0)
	_silhouette.size = Vector2(306.0, 320.0)
	_panel.add_child(_silhouette)

	_hint = _make_label(FONT_CN, 13, Color(CYAN, 0.75), "▸  空格 / 左键  继续")
	_hint.position = Vector2(TEXT_X, 247.0)
	_hint.size = Vector2(420.0, 20.0)
	_hint.visible = false
	_panel.add_child(_hint)

	_counter = _make_label(FONT_MONO, 12, Color(CYAN, 0.5), "01 / 04")
	_counter.position = Vector2(PANEL_W - 44.0 - 180.0, 247.0)
	_counter.size = Vector2(180.0, 20.0)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_counter)

	_layout()


func _make_label(font: Font, font_size: int, color: Color, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _layout() -> void:
	if _panel == null:
		return
	_panel.position = _rest_position()
	_panel.size = Vector2(PANEL_W, PANEL_H)


func _rest_position() -> Vector2:
	var vp := _root.size
	return Vector2(roundf((vp.x - PANEL_W) * 0.5), PANEL_TOP)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			advance()
			_root.accept_event()


func _kill_anim() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = null


class Scrim extends Control:
	func _draw() -> void:
		var w := size.x
		var bottom := size.y * 0.58
		draw_polygon(
			PackedVector2Array(
				[Vector2(0, 0), Vector2(w, 0), Vector2(w, bottom), Vector2(0, bottom)]
			),
			PackedColorArray(
				[
					Color(0.004, 0.012, 0.016, 0.42),
					Color(0.004, 0.012, 0.016, 0.42),
					Color(0.004, 0.012, 0.016, 0.0),
					Color(0.004, 0.012, 0.016, 0.0),
				]
			)
		)


## 右侧黑色人物剪影：纯代码绘制的占位，后续可替换为正式角色剪影图。
class Silhouette extends Control:
	var _phase := 0.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_phase += delta
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var bob := sin(_phase * 0.9) * 2.5
		var cx := w * 0.5
		var head_y := 118.0 + bob

		# 背后微光，避免纯黑剪影与深色面板糊在一起
		draw_circle(Vector2(cx, head_y + 84.0), 118.0, Color(0.36, 0.87, 0.95, 0.05))
		draw_circle(Vector2(cx, head_y + 84.0), 82.0, Color(0.36, 0.87, 0.95, 0.055))

		var black := Color(0.008, 0.012, 0.016, 0.98)
		var rim := Color(0.34, 0.72, 0.78, 0.22)

		draw_circle(Vector2(cx, head_y), 60.0, black)
		draw_arc(Vector2(cx, head_y), 60.0, -2.35, -0.5, 26, rim, 2.0)

		draw_rect(Rect2(cx - 21.0, head_y + 42.0, 42.0, 46.0), black)

		var shoulders := PackedVector2Array([
			Vector2(cx - 126.0, h),
			Vector2(cx - 104.0, head_y + 102.0),
			Vector2(cx - 56.0, head_y + 70.0),
			Vector2(cx + 56.0, head_y + 70.0),
			Vector2(cx + 104.0, head_y + 102.0),
			Vector2(cx + 126.0, h),
		])
		draw_colored_polygon(shoulders, black)
		draw_polyline(
			PackedVector2Array(
				[
					Vector2(cx - 104.0, head_y + 102.0),
					Vector2(cx - 56.0, head_y + 70.0),
					Vector2(cx + 56.0, head_y + 70.0),
					Vector2(cx + 104.0, head_y + 102.0),
				]
			),
			rim,
			2.0
		)
		draw_arc(
			Vector2(cx, head_y + 82.0),
			32.0,
			0.2,
			PI - 0.2,
			18,
			Color(0.5, 0.9, 0.95, 0.16),
			2.0
		)
