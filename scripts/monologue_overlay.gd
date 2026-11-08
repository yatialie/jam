class_name JamMonologueOverlay
extends CanvasLayer

## 主角内心旁白浮层：屏幕下方居中的玻璃面板，左侧立绘、右侧逐字文本。
## 只负责表现与输入；调用入口在 Monologue 单例，立绘与台词均可外部替换。

signal line_started(index: int, text: String)
signal finished()

const FONT_CN: Font = preload("res://ui/fonts/f_ui.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")
const FONT_TRACKED: Font = preload("res://ui/fonts/f_label_tracked.tres")
const PORTRAIT_SHADER: Shader = preload("res://ui/shaders/monologue_portrait.gdshader")
const DEFAULT_PORTRAIT: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_neutral.png")
const PORTRAIT_CONFUSED: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_confused.png")
const PORTRAIT_SURPRISED: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_surprised.png")
const PORTRAIT_ANGRY: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_angry.png")
const PORTRAIT_REMORSE: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_remorse.png")
const PORTRAIT_CONFUSED_RESPAWN: Texture2D = preload("res://art_placeholder/scifi_ship_v2/characters/nova/portraits/rig7_confused_respawn.png")
const EMOTION_PORTRAITS := {
	"question": PORTRAIT_CONFUSED,
	"exclaim": PORTRAIT_SURPRISED,
	"anger": PORTRAIT_ANGRY,
	"remorse": PORTRAIT_REMORSE,
	"question_respawn": PORTRAIT_CONFUSED_RESPAWN,
}

const PANEL_W := 1240.0
const PANEL_H := 300.0
const BOTTOM_MARGIN := 54.0
const TEXT_X := 288.0
const TEXT_W := 906.0
const PORTRAIT_RECT := Rect2(-70.0, -150.0, 340.0, 480.0)
const EMOTION_PORTRAIT_RECT := Rect2(-70.0, -282.0, 340.0, 612.0)
const HEADER_RULE_Y := 70.0
const FOOTER_RULE_Y := 244.0
const BODY_Y := 86.0
const BODY_H := 146.0
const TYPING_CPS := 30.0

const CYAN := Color(0.36, 0.87, 0.95)
const BODY_COLOR := Color(0.87, 0.93, 0.95)

var _root: Control
var _scrim: Scrim
var _panel: Control
var _frame: PanelArt
var _portrait: TextureRect
var _portrait_mat: ShaderMaterial
var _base_portrait: Texture2D = DEFAULT_PORTRAIT
var _name_label: Label
var _tag_label: Label
var _body: RichTextLabel
var _hint: Label
var _counter: Label

var _lines: Array = []
var _speaker := "RIG-7"
var _default_emotion := ""
var _index := -1
var _text := ""
var _active := false
var _closing := false
var _typing := false
var _shown := 0
var _total := 0
var _typing_progress := 0.0
var _char_pause := 0.0
var _time := 0.0
var _auto_advance := false
var _auto_delay := 2.4
var _auto_timer := 0.0

var _block_player := true
var _player_states: Array = []
var _anim: Tween


func _ready() -> void:
	layer = 80
	visible = false
	_build()


func is_playing() -> bool:
	return _active


func is_typing() -> bool:
	return _typing


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

	var was_active := _active
	_lines = cleaned
	_speaker = str(options.get("speaker", "RIG-7"))
	_block_player = bool(options.get("block_player", true))
	_default_emotion = str(options.get("emotion", ""))
	_auto_advance = bool(options.get("auto_advance", false))
	_auto_delay = maxf(float(options.get("auto_delay", 2.4)), 0.4)
	_base_portrait = DEFAULT_PORTRAIT
	if options.has("portrait") and options["portrait"] is Texture2D:
		_base_portrait = options["portrait"]

	_active = true
	_closing = false
	_time = 0.0
	visible = true
	# 非阻塞独白不拦截鼠标，也不进入 modal 组，玩家可以继续移动、交互和射击。
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if _block_player else Control.MOUSE_FILTER_IGNORE
	if _block_player:
		add_to_group("modal")
	else:
		remove_from_group("modal")
	if not was_active:
		_set_player_frozen(_block_player)
		_animate_in()
	else:
		# 注意不要在已冻结时重复记录状态，否则会把“已冻结”当成原始状态，结束后无法解锁。
		if not _block_player:
			_set_player_frozen(false)
		elif _player_states.is_empty():
			_set_player_frozen(true)
		_root.modulate.a = 1.0
		_panel.position = _rest_position()
		_set_portrait_reveal(1.0)

	_frame.target_progress = 0.0
	_frame.progress = 0.0
	_show_line(0)


func advance() -> void:
	if not _active or _closing:
		return
	if _typing:
		_typing = false
		_char_pause = 0.0
		_auto_timer = 0.0
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
	_anim.tween_property(_root, "modulate:a", 0.0, 0.26)
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
	_typing = false
	_auto_advance = false
	_auto_timer = 0.0
	visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.modulate.a = 1.0
	remove_from_group("modal")
	_set_player_frozen(false)
	if was_active:
		finished.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		# 非阻塞独白不吞 E 键，避免玩家在旁白播放期间无法用 E 推进/交互。
		if not _block_player and key.physical_keycode == KEY_E:
			return
		if key.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			advance()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	_hint.modulate.a = 0.55 + 0.35 * sin(_time * 3.4)
	if not _typing:
		if _auto_advance and not _closing:
			_auto_timer += delta
			if _auto_timer >= _auto_delay:
				_auto_timer = 0.0
				advance()
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
	_auto_timer = 0.0
	_body.text = _text
	_body.visible_characters = -1
	_show_continue_hint()


func _show_continue_hint() -> void:
	_hint.text = "▸  自动继续" if _auto_advance else "▸  空格 / 左键  继续"
	_hint.visible = true


func _show_line(index: int) -> void:
	_index = index
	var entry: Variant = _lines[index]
	var emotion := _default_emotion
	if entry is Dictionary:
		_text = str(entry.get("text", ""))
		_name_label.text = str(entry.get("speaker", _speaker))
		emotion = str(entry.get("emotion", _default_emotion))
	else:
		_text = str(entry)
		_name_label.text = _speaker
	_apply_portrait(emotion)

	_body.text = _text
	_body.visible_characters = 0
	_shown = 0
	_total = _text.length()
	_typing_progress = 0.0
	_char_pause = 0.0
	_auto_timer = 0.0
	_typing = _total > 0
	_hint.text = "记录中…"
	_hint.visible = true
	_counter.text = "%02d / %02d" % [index + 1, _lines.size()]
	_frame.target_progress = float(index + 1) / float(_lines.size())
	line_started.emit(index, _text)
	if not _typing:
		_finish_typing()


func _apply_portrait(emotion: String) -> void:
	var tex := EMOTION_PORTRAITS.get(emotion, _base_portrait) as Texture2D
	_portrait.texture = tex
	if EMOTION_PORTRAITS.has(emotion):
		_portrait.position = EMOTION_PORTRAIT_RECT.position
		_portrait.size = EMOTION_PORTRAIT_RECT.size
	else:
		_portrait.position = PORTRAIT_RECT.position
		_portrait.size = PORTRAIT_RECT.size


func _animate_in() -> void:
	_kill_anim()
	var rest := _rest_position()
	_root.modulate.a = 0.0
	_panel.position = rest + Vector2(0.0, 26.0)
	_set_portrait_reveal(0.0)
	_anim = create_tween()
	_anim.set_parallel(true)
	_anim.tween_property(_root, "modulate:a", 1.0, 0.3)
	_anim.tween_property(_panel, "position", rest, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_method(_set_portrait_reveal, 0.0, 1.0, 0.68)


func _kill_anim() -> void:
	if _anim != null and _anim.is_valid():
		_anim.kill()
	_anim = null


func _set_portrait_reveal(value: float) -> void:
	if _portrait_mat != null:
		_portrait_mat.set_shader_parameter("reveal", value)


func _set_player_frozen(frozen: bool) -> void:
	if frozen:
		_player_states.clear()
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

	_frame = PanelArt.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.text_x = TEXT_X
	_frame.header_y = HEADER_RULE_Y
	_frame.footer_y = FOOTER_RULE_Y
	_panel.add_child(_frame)

	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.texture = DEFAULT_PORTRAIT
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.position = PORTRAIT_RECT.position
	_portrait.size = PORTRAIT_RECT.size
	_portrait_mat = ShaderMaterial.new()
	_portrait_mat.shader = PORTRAIT_SHADER
	_portrait_mat.set_shader_parameter("reveal", 0.0)
	_portrait.material = _portrait_mat
	_panel.add_child(_portrait)

	_name_label = _make_label(FONT_TRACKED, 16, Color(0.8, 0.97, 1.0), "RIG-7")
	_name_label.position = Vector2(TEXT_X + 14.0, 11.0)
	_name_label.size = Vector2(220.0, 28.0)
	_panel.add_child(_name_label)

	_tag_label = _make_label(FONT_CN, 12, Color(CYAN, 0.62), "内心独白  /  INNER MONOLOGUE")
	_tag_label.position = Vector2(TEXT_X + 14.0, 38.0)
	_tag_label.size = Vector2(380.0, 18.0)
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

	_hint = _make_label(FONT_CN, 13, Color(CYAN, 0.75), "▸  空格 / 左键  继续")
	_hint.position = Vector2(TEXT_X, 253.0)
	_hint.size = Vector2(420.0, 20.0)
	_hint.visible = false
	_panel.add_child(_hint)

	_counter = _make_label(FONT_MONO, 12, Color(CYAN, 0.5), "01 / 01")
	_counter.position = Vector2(PANEL_W - 44.0 - 180.0, 253.0)
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
	return Vector2(roundf((vp.x - PANEL_W) * 0.5), roundf(vp.y - PANEL_H - BOTTOM_MARGIN))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			advance()
			_root.accept_event()


class Scrim extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top := h * 0.52
		draw_polygon(
			PackedVector2Array(
				[Vector2(0.0, top), Vector2(w, top), Vector2(w, h), Vector2(0.0, h)]
			),
			PackedColorArray(
				[
					Color(0.004, 0.012, 0.016, 0.0),
					Color(0.004, 0.012, 0.016, 0.0),
					Color(0.004, 0.012, 0.016, 0.6),
					Color(0.004, 0.012, 0.016, 0.6),
				]
			)
		)
		draw_polygon(
			PackedVector2Array([Vector2(0.0, 0.0), Vector2(180.0, 0.0), Vector2(180.0, h), Vector2(0.0, h)]),
			PackedColorArray(
				[
					Color(0.004, 0.01, 0.014, 0.22),
					Color(0.004, 0.01, 0.014, 0.0),
					Color(0.004, 0.01, 0.014, 0.0),
					Color(0.004, 0.01, 0.014, 0.22),
				]
			)
		)
		draw_polygon(
			PackedVector2Array(
				[Vector2(w - 180.0, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(w - 180.0, h)]
			),
			PackedColorArray(
				[
					Color(0.004, 0.01, 0.014, 0.0),
					Color(0.004, 0.01, 0.014, 0.22),
					Color(0.004, 0.01, 0.014, 0.22),
					Color(0.004, 0.01, 0.014, 0.0),
				]
			)
		)


class PanelArt extends Control:
	const CYAN := Color(0.36, 0.87, 0.95)
	const AMBER := Color(0.98, 0.68, 0.3)

	var text_x := 288.0
	var header_y := 70.0
	var footer_y := 244.0
	var target_progress := 0.0
	var progress := 0.0
	var phase := 0.0


	func _process(delta: float) -> void:
		phase += delta
		progress = lerpf(progress, target_progress, 1.0 - exp(-delta * 6.0))
		queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cut := 16.0
		var pts := PackedVector2Array(
			[
				Vector2(cut, 0.0),
				Vector2(w - cut, 0.0),
				Vector2(w, cut),
				Vector2(w, h - cut),
				Vector2(w - cut, h),
				Vector2(cut, h),
				Vector2(0.0, h - cut),
				Vector2(0.0, cut),
			]
		)

		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(0.0, 7.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.34))

		var colors := PackedColorArray()
		for p in pts:
			var t: float = clampf(p.y / maxf(h, 1.0), 0.0, 1.0)
			colors.append(Color(0.018, 0.042, 0.052, 0.93).lerp(Color(0.004, 0.012, 0.018, 0.95), t))
		draw_polygon(pts, colors)

		draw_polygon(
			PackedVector2Array(
				[Vector2(cut, 0.0), Vector2(w - cut, 0.0), Vector2(w - cut, 44.0), Vector2(cut, 44.0)]
			),
			PackedColorArray(
				[
					Color(1, 1, 1, 0.045),
					Color(1, 1, 1, 0.045),
					Color(1, 1, 1, 0.0),
					Color(1, 1, 1, 0.0),
				]
			)
		)

		var line_y := 2.0
		while line_y < h:
			draw_line(Vector2(2.0, line_y), Vector2(w - 2.0, line_y), Color(0, 0, 0, 0.05), 1.0)
			line_y += 3.0

		# 标题与底部分隔线
		draw_line(Vector2(text_x, header_y), Vector2(w - 44.0, header_y), Color(CYAN, 0.16), 1.0)
		draw_line(Vector2(text_x, header_y), Vector2(text_x + 168.0, header_y), Color(CYAN, 0.5), 1.0)
		draw_line(Vector2(text_x, footer_y), Vector2(w - 44.0, footer_y), Color(CYAN, 0.12), 1.0)

		# 左侧竖向强调条
		draw_polygon(
			PackedVector2Array(
				[Vector2(0.0, 20.0), Vector2(2.0, 20.0), Vector2(2.0, h - 20.0), Vector2(0.0, h - 20.0)]
			),
			PackedColorArray(
				[
					Color(CYAN, 0.62),
					Color(CYAN, 0.62),
					Color(CYAN, 0.06),
					Color(CYAN, 0.06),
				]
			)
		)

		for i in 3:
			var tick_y := 96.0 + float(i) * 26.0
			draw_line(Vector2(5.0, tick_y), Vector2(11.0, tick_y), Color(CYAN, 0.22), 1.0)

		# 标题呼吸灯
		draw_circle(Vector2(text_x + 4.0, 31.0), 8.0, Color(AMBER, 0.07))
		draw_circle(Vector2(text_x + 4.0, 31.0), 3.0, Color(AMBER, 0.9))

		# 四角括号
		var inset := 6.0
		var arm := 10.0
		var bracket := Color(CYAN, 0.42)
		draw_line(Vector2(inset, cut + arm), Vector2(inset, cut), bracket, 1.2)
		draw_line(Vector2(inset, cut), Vector2(cut + arm, cut), bracket, 1.2)
		draw_line(Vector2(w - inset, cut + arm), Vector2(w - inset, cut), bracket, 1.2)
		draw_line(Vector2(w - inset, cut), Vector2(w - cut - arm, cut), bracket, 1.2)
		draw_line(Vector2(inset, h - cut - arm), Vector2(inset, h - cut), bracket, 1.2)
		draw_line(Vector2(inset, h - cut), Vector2(cut + arm, h - cut), bracket, 1.2)
		draw_line(Vector2(w - inset, h - cut - arm), Vector2(w - inset, h - cut), bracket, 1.2)
		draw_line(Vector2(w - inset, h - cut), Vector2(w - cut - arm, h - cut), bracket, 1.2)

		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(CYAN, 0.1), 3.0, true)
		draw_polyline(closed, Color(CYAN, 0.34), 1.0, true)

		# 底部进度条
		var bar_w := w - text_x - 44.0
		draw_rect(Rect2(text_x, h - 10.0, bar_w, 2.0), Color(CYAN, 0.1))
		draw_rect(
			Rect2(text_x, h - 10.0, bar_w * clampf(progress, 0.0, 1.0), 2.0), Color(CYAN, 0.5)
		)

