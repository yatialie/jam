extends Control

## Left-edge mission log. A cassette-spine glass panel that lists the live
## objectives of the current chapter and collapses into a slim tape tab.
## All content comes from the MissionLog autoload, so scenes stay art-agnostic.

const FONT_CN: Font = preload("res://ui/fonts/f_ui.tres")
const FONT_CN_BOLD: Font = preload("res://ui/fonts/f_ui_bold.tres")
const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")
const FONT_TRACKED: Font = preload("res://ui/fonts/f_label_tracked.tres")
const PANEL_TEXTURE: Texture2D = preload("res://art_placeholder/scifi_ui/ui_mission_panel_tex.jpg")

const PANEL_X := 18.0
const PANEL_Y := 196.0
const SPINE_W := 22.0
const PANEL_W := 330.0
const TOTAL_W := SPINE_W + PANEL_W
const HEADER_H := 112.0
const ROW_H := 58.0
const FOOTER_H := 36.0
const TAB_W := 56.0
const TAB_H := 208.0

const CYAN := Color(0.32, 0.86, 0.94)
const AMBER := Color(0.98, 0.68, 0.3)
const GREEN := Color(0.42, 1.0, 0.78)

## 关卡载入后是否自动展开。第一关由开场独白结束事件显式调用 expand()。
@export var auto_open := true

var _chapter: Dictionary = {}
var _rows: Array[JamTaskRow] = []
var _rows_by_id: Dictionary = {}

var _expanded: Control
var _spine: SpineStrip
var _frame: JamMissionFrame
var _rows_root: Control
var _tab: CollapsedTab

var _code_label: Label
var _archive_label: Label
var _title_label: Label
var _title_en_label: Label
var _location_label: Label
var _progress_label: Label
var _hint_label: Label
var _rec_label: Label

var _panel_h := 380.0
var _open := 0.0
var _target_open := 0.0
var _time := 0.0
var _fill := 0.0
var _fill_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("task_panel")
	_build()

	MissionLog.chapter_started.connect(_on_chapter_started)
	MissionLog.task_changed.connect(_on_task_changed)
	MissionLog.chapter_completed.connect(_on_chapter_completed)

	_sync()
	_open = 0.0
	_apply_open()

	if auto_open:
		var intro := create_tween()
		intro.tween_interval(0.4)
		intro.tween_callback(func() -> void: _target_open = 1.0)


## 展开任务面板（第一关在开场独白结束后调用）。
func expand() -> void:
	if not _chapter.is_empty():
		_target_open = 1.0


func _process(delta: float) -> void:
	_time += delta
	_open = lerpf(_open, _target_open, 1.0 - exp(-delta * 10.0))
	_fill = lerpf(_fill, _fill_target, 1.0 - exp(-delta * 6.0))
	_apply_open()

	_frame.progress = _fill
	_spine.progress = _fill
	_tab.progress = _fill
	_frame.wipe = maxf(_frame.wipe - delta * 3.0, 0.0)
	_frame.complete_flash = maxf(_frame.complete_flash - delta * 1.5, 0.0)
	_rec_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_TAB:
			_target_open = 0.0 if _target_open > 0.5 else 1.0
			get_viewport().set_input_as_handled()


func _build() -> void:
	_expanded = Control.new()
	_expanded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded.position = Vector2(PANEL_X, PANEL_Y)
	_expanded.size = Vector2(TOTAL_W, _panel_h)
	add_child(_expanded)

	_spine = SpineStrip.new()
	_spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spine.position = Vector2.ZERO
	_spine.size = Vector2(SPINE_W, _panel_h)
	_expanded.add_child(_spine)

	_frame = JamMissionFrame.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture = PANEL_TEXTURE
	_frame.header_h = HEADER_H
	_frame.footer_h = FOOTER_H
	_frame.position = Vector2(SPINE_W, 0.0)
	_frame.size = Vector2(PANEL_W, _panel_h)
	_expanded.add_child(_frame)

	_code_label = _make_label(FONT_MONO, 11, AMBER)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_archive_label = _make_label(FONT_MONO, 9, Color(0.5, 0.64, 0.7, 0.8))
	_archive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_archive_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_title_label = _make_label(FONT_CN_BOLD, 28, Color(0.93, 0.97, 0.98, 1.0))
	_title_en_label = _make_label(FONT_TRACKED, 10, Color(0.32, 0.86, 0.94, 0.72))
	_location_label = _make_label(FONT_MONO, 9, Color(0.48, 0.62, 0.68, 0.75))
	_progress_label = _make_label(FONT_MONO, 10, CYAN)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_rows_root = Control.new()
	_rows_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_rows_root)

	_hint_label = _make_label(FONT_MONO, 9, Color(0.55, 0.68, 0.74, 0.6))
	_hint_label.text = "[ TAB ] 收起"
	_rec_label = _make_label(FONT_MONO, 9, Color(0.98, 0.62, 0.25, 0.9))
	_rec_label.text = "● REC"
	_rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_tab = CollapsedTab.new()
	_tab.position = Vector2(PANEL_X, PANEL_Y)
	_tab.size = Vector2(TAB_W, TAB_H)
	_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tab.tooltip_text = "任务日志  //  TAB"
	_tab.gui_input.connect(_on_tab_input)
	add_child(_tab)


func _make_label(font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_frame.add_child(label)
	return label


func _apply_open() -> void:
	_expanded.position = Vector2(lerpf(-TOTAL_W - 30.0, PANEL_X, _open), PANEL_Y)
	_expanded.modulate.a = clampf(_open * 1.25, 0.0, 1.0)
	_expanded.visible = _expanded.modulate.a > 0.01

	_tab.position = Vector2(lerpf(PANEL_X, -TAB_W - 30.0, _open), PANEL_Y)
	_tab.modulate.a = clampf(1.0 - _open * 1.25, 0.0, 1.0)
	_tab.visible = _tab.modulate.a > 0.01


func _on_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_target_open = 1.0
			accept_event()


func _sync() -> void:
	_chapter = MissionLog.current_chapter()
	if _chapter.is_empty():
		visible = false
		return
	visible = true
	_rebuild()
	_update_header()


func _rebuild() -> void:
	for row in _rows:
		row.queue_free()
	_rows.clear()
	_rows_by_id.clear()

	var tasks: Array = _chapter.get("tasks", [])
	_panel_h = HEADER_H + ROW_H * float(tasks.size()) + FOOTER_H
	_expanded.size = Vector2(TOTAL_W, _panel_h)
	_spine.size = Vector2(SPINE_W, _panel_h)
	_frame.size = Vector2(PANEL_W, _panel_h)

	_rows_root.position = Vector2(16.0, HEADER_H)
	_rows_root.size = Vector2(PANEL_W - 32.0, ROW_H * float(tasks.size()))
	_frame.segments = tasks.size()

	for i in tasks.size():
		var spec: Dictionary = tasks[i]
		var row := JamTaskRow.new()
		row.task_id = String(spec["id"])
		row.position = Vector2(0.0, ROW_H * float(i))
		row.size = Vector2(PANEL_W - 32.0, ROW_H)
		row.setup(i + 1, String(spec["cn"]), String(spec["en"]), int(spec.get("target", 1)))
		_rows_root.add_child(row)
		row.play_reveal(0.05 * float(i))
		_rows.append(row)
		_rows_by_id[row.task_id] = row

	_layout()
	_refresh_rows()


func _layout() -> void:
	_code_label.position = Vector2(16.0, 14.0)
	_code_label.size = Vector2(54.0, 20.0)
	_archive_label.position = Vector2(PANEL_W - 136.0, 12.0)
	_archive_label.size = Vector2(120.0, 16.0)
	_title_label.position = Vector2(15.0, 30.0)
	_title_label.size = Vector2(PANEL_W - 30.0, 36.0)
	_title_en_label.position = Vector2(17.0, 66.0)
	_title_en_label.size = Vector2(PANEL_W - 34.0, 14.0)
	_location_label.position = Vector2(17.0, 82.0)
	_location_label.size = Vector2(PANEL_W - 100.0, 14.0)
	_progress_label.position = Vector2(PANEL_W - 96.0, 80.0)
	_progress_label.size = Vector2(80.0, 16.0)
	_hint_label.position = Vector2(16.0, _panel_h - 26.0)
	_hint_label.size = Vector2(170.0, 16.0)
	_rec_label.position = Vector2(PANEL_W - 86.0, _panel_h - 26.0)
	_rec_label.size = Vector2(70.0, 16.0)


func _update_header() -> void:
	_code_label.text = "CH " + String(_chapter["code"])
	_archive_label.text = "ARCHIVE %02d / %02d" % [MissionLog.archive_index(), MissionLog.archive_size()]
	_title_label.text = String(_chapter["title_cn"])
	_title_en_label.text = String(_chapter["title_en"])
	_location_label.text = String(_chapter["location"])
	_progress_label.add_theme_color_override("font_color", CYAN)
	_frame.complete = false
	_spine.complete = false
	_tab.complete = false
	_tab.chapter_code = String(_chapter["code"])
	_frame.wipe = 1.0
	_update_progress()


func _update_progress() -> void:
	var counts := MissionLog.progress()
	_fill_target = float(counts.x) / maxf(float(counts.y), 1.0)
	_progress_label.text = "%d / %d" % [counts.x, counts.y]


func _refresh_rows() -> void:
	var active_assigned := false
	for row in _rows:
		var state := MissionLog.task_state(row.task_id)
		var done := bool(state["done"])
		var active := false
		if not done and not active_assigned:
			active = true
			active_assigned = true
		row.apply_state(done, int(state["count"]), int(state["target"]), active)
	_tab.attention = 1.0


func _on_chapter_started(_chapter_id: String) -> void:
	_sync()


func _on_task_changed(task_id: String) -> void:
	_refresh_rows()
	_update_progress()
	if _rows_by_id.has(task_id):
		var row: JamTaskRow = _rows_by_id[task_id]
		_tab.attention = maxf(_tab.attention, 0.6)


func _on_chapter_completed(_chapter_id: String) -> void:
	_frame.complete = true
	_spine.complete = true
	_tab.complete = true
	_frame.complete_flash = 1.0
	_progress_label.text = "COMPLETE"
	_progress_label.add_theme_color_override("font_color", GREEN)
	_tab.attention = 1.0


class PanelFrame extends Control:
	const CYAN := Color(0.32, 0.86, 0.94)
	const GREEN := Color(0.42, 1.0, 0.78)

	var header_h := 112.0
	var footer_h := 36.0
	var progress := 0.0
	var segments := 1
	var complete := false
	var wipe := 0.0
	var complete_flash := 0.0
	var texture: Texture2D = null
	var _phase := 0.0


	func _process(delta: float) -> void:
		_phase += delta
		queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cut := 9.0
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
			shadow.append(p + Vector2(3.0, 5.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))

		var top := Color(0.02, 0.044, 0.055, 0.93)
		var bottom := Color(0.006, 0.016, 0.022, 0.95)
		var colors := PackedColorArray()
		for p in pts:
			colors.append(top.lerp(bottom, clampf(p.y / maxf(h, 1.0), 0.0, 1.0)))
		draw_polygon(pts, colors)

		# header band sits slightly above the body to create hierarchy
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(cut, 0.0),
					Vector2(w - cut, 0.0),
					Vector2(w, cut),
					Vector2(w, header_h - 8.0),
					Vector2(cut, header_h - 8.0),
					Vector2(0.0, cut),
				]
			),
			PackedColorArray(
				[
					Color(0.16, 0.55, 0.62, 0.05),
					Color(0.16, 0.55, 0.62, 0.05),
					Color(0.16, 0.55, 0.62, 0.02),
					Color(0.16, 0.55, 0.62, 0.0),
					Color(0.16, 0.55, 0.62, 0.0),
					Color(0.16, 0.55, 0.62, 0.02),
				]
			)
		)

		if texture:
			draw_texture_rect(
				texture,
				Rect2(9.0, 9.0, w - 18.0, h - 18.0),
				false,
				Color(0.75, 0.95, 1.0, 0.13)
			)

		var line_y := 2.0
		while line_y < h:
			draw_line(Vector2(2.0, line_y), Vector2(w - 2.0, line_y), Color(0, 0, 0, 0.055), 1.0)
			line_y += 3.0

		var sweep_t := fmod(_phase * 0.085, 1.0)
		var band_y := -70.0 + sweep_t * (h + 140.0)
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(2.0, band_y),
					Vector2(w - 2.0, band_y + 22.0),
					Vector2(w - 2.0, band_y + 66.0),
					Vector2(2.0, band_y + 44.0),
				]
			),
			PackedColorArray(
				[
					Color(1, 1, 1, 0.0),
					Color(1, 1, 1, 0.016),
					Color(1, 1, 1, 0.016),
					Color(1, 1, 1, 0.0),
				]
			)
		)

		draw_polygon(
			PackedVector2Array(
				[
					Vector2(cut, 0.0),
					Vector2(w - cut, 0.0),
					Vector2(w - cut, 46.0),
					Vector2(cut, 46.0),
				]
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

		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(CYAN, 0.08), 3.0, true)
		draw_polyline(closed, Color(CYAN, 0.34), 1.0, true)

		var inset := 6.0
		var arm := 10.0
		var bracket := Color(CYAN, 0.45)
		draw_line(Vector2(inset, cut + arm), Vector2(inset, cut), bracket, 1.2)
		draw_line(Vector2(inset, cut), Vector2(cut + arm, cut), bracket, 1.2)
		draw_line(Vector2(w - inset, cut + arm), Vector2(w - inset, cut), bracket, 1.2)
		draw_line(Vector2(w - inset, cut), Vector2(w - cut - arm, cut), bracket, 1.2)
		draw_line(Vector2(inset, h - cut - arm), Vector2(inset, h - cut), bracket, 1.2)
		draw_line(Vector2(inset, h - cut), Vector2(cut + arm, h - cut), bracket, 1.2)
		draw_line(Vector2(w - inset, h - cut - arm), Vector2(w - inset, h - cut), bracket, 1.2)
		draw_line(Vector2(w - inset, h - cut), Vector2(w - cut - arm, h - cut), bracket, 1.2)

		draw_rect(Rect2(16.0, 14.0, 54.0, 20.0), Color(CYAN, 0.06))
		draw_rect(Rect2(16.0, 14.0, 54.0, 20.0), Color(CYAN, 0.35), false, 1.0)
		draw_rect(Rect2(16.0, 14.0, 3.0, 20.0), Color(0.98, 0.68, 0.3, 0.9))

		_draw_reel_window(w)

		var rail_y := header_h - 4.0
		draw_line(Vector2(16.0, rail_y), Vector2(w - 16.0, rail_y), Color(1, 1, 1, 0.09), 3.0)
		var fill_w := (w - 32.0) * clampf(progress, 0.0, 1.0)
		if fill_w > 0.5:
			var rail_color := GREEN if complete else CYAN
			draw_line(Vector2(16.0, rail_y), Vector2(16.0 + fill_w, rail_y), Color(rail_color, 0.9), 3.0)
			draw_circle(Vector2(16.0 + fill_w, rail_y), 2.6, Color(rail_color, 0.95))
		if segments > 1:
			for i in range(1, segments):
				var tick_x := 16.0 + (w - 32.0) * float(i) / float(segments)
				draw_line(
					Vector2(tick_x, rail_y - 3.0),
					Vector2(tick_x, rail_y + 3.0),
					Color(0.03, 0.06, 0.07, 0.75),
					1.0
				)

		draw_line(
			Vector2(16.0, h - footer_h),
			Vector2(w - 16.0, h - footer_h),
			Color(1, 1, 1, 0.07),
			1.0
		)

		if wipe > 0.001:
			var wipe_y := header_h * (1.0 - wipe)
			draw_line(Vector2(4.0, wipe_y), Vector2(w - 4.0, wipe_y), Color(CYAN, 0.7 * wipe), 2.0)
			draw_rect(Rect2(4.0, wipe_y, w - 8.0, 14.0), Color(CYAN, 0.05 * wipe))

		if complete_flash > 0.001:
			draw_rect(Rect2(2.0, 2.0, w - 4.0, header_h - 2.0), Color(GREEN, 0.06 * complete_flash))
			var sweep_y := h * (1.0 - complete_flash)
			draw_line(
				Vector2(4.0, sweep_y),
				Vector2(w - 4.0, sweep_y),
				Color(GREEN, 0.55 * complete_flash),
				2.0
			)


	func _draw_reel_window(w: float) -> void:
		var size_x := 104.0
		var size_y := 44.0
		var x0 := w - 16.0 - size_x
		var y0 := 32.0
		var chamfer := 5.0
		var frame := PackedVector2Array(
			[
				Vector2(x0 + chamfer, y0),
				Vector2(x0 + size_x - chamfer, y0),
				Vector2(x0 + size_x, y0 + chamfer),
				Vector2(x0 + size_x, y0 + size_y - chamfer),
				Vector2(x0 + size_x - chamfer, y0 + size_y),
				Vector2(x0 + chamfer, y0 + size_y),
				Vector2(x0, y0 + size_y - chamfer),
				Vector2(x0, y0 + chamfer),
			]
		)
		var closed := frame.duplicate()
		closed.append(frame[0])
		draw_polyline(closed, Color(CYAN, 0.22), 1.0, true)

		for reel_index in 2:
			var center := Vector2(x0 + 30.0 + float(reel_index) * 44.0, y0 + size_y * 0.5)
			var spin := _phase * (0.55 if reel_index == 0 else -0.38)
			draw_arc(center, 15.5, 0.0, TAU, 36, Color(CYAN, 0.22), 1.0, true)
			for i in 8:
				var angle := TAU * float(i) / 8.0 + spin
				var dir := Vector2(cos(angle), sin(angle))
				draw_line(center + dir * 12.0, center + dir * 15.0, Color(CYAN, 0.18), 1.0)
			draw_circle(center, 4.6, Color(CYAN, 0.09))
			draw_arc(center, 4.6, 0.0, TAU, 20, Color(CYAN, 0.24), 1.0, true)
			draw_circle(center, 1.4, Color(0.98, 0.68, 0.3, 0.45))


class SpineStrip extends Control:
	const FONT: Font = preload("res://ui/fonts/f_label_tracked.tres")
	const CYAN := Color(0.32, 0.86, 0.94)
	const GREEN := Color(0.42, 1.0, 0.78)

	var progress := 0.0
	var complete := false


	func _process(_delta: float) -> void:
		queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.02, 0.027, 0.94))
		draw_line(Vector2(0.0, 4.0), Vector2(0.0, h - 4.0), Color(0, 0, 0, 0.5), 2.0)
		draw_line(Vector2(w - 0.5, 8.0), Vector2(w - 0.5, h - 8.0), Color(CYAN, 0.35), 1.0)

		var y := 16.0
		var index := 0
		while y < h - 16.0:
			var long := index % 5 == 0
			draw_line(
				Vector2(w - (10.0 if long else 6.0), y),
				Vector2(w - 2.0, y),
				Color(1, 1, 1, 0.1),
				1.0
			)
			y += 7.0
			index += 1

		var bar_top := h - 78.0
		var bar_bottom := h - 16.0
		draw_rect(Rect2(9.0, bar_top, 3.0, bar_bottom - bar_top), Color(1, 1, 1, 0.08))
		var bar_h := (bar_bottom - bar_top) * clampf(progress, 0.0, 1.0)
		if bar_h > 0.5:
			var color := GREEN if complete else CYAN
			draw_rect(Rect2(9.0, bar_bottom - bar_h, 3.0, bar_h), Color(color, 0.85))

		draw_set_transform(Vector2(15.0, h - 86.0), -PI / 2.0, Vector2.ONE)
		draw_string(
			FONT,
			Vector2.ZERO,
			"MISSION LOG // SIDE A",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			Color(0.78, 0.9, 0.94, 0.55)
		)


class CollapsedTab extends Control:
	const FONT_CN: Font = preload("res://ui/fonts/f_ui_bold.tres")
	const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")
	const CYAN := Color(0.32, 0.86, 0.94)
	const AMBER := Color(0.98, 0.68, 0.3)
	const GREEN := Color(0.42, 1.0, 0.78)

	var chapter_code := "00"
	var progress := 0.0
	var complete := false
	var pulse := 0.0
	var attention := 0.0


	func _process(delta: float) -> void:
		pulse += delta
		attention = maxf(attention - delta * 1.3, 0.0)
		queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		var cut := 8.0
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
			shadow.append(p + Vector2(3.0, 4.0))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))

		var top := Color(0.022, 0.048, 0.058, 0.94)
		var bottom := Color(0.007, 0.018, 0.024, 0.96)
		var colors := PackedColorArray()
		for p in pts:
			colors.append(top.lerp(bottom, clampf(p.y / maxf(h, 1.0), 0.0, 1.0)))
		draw_polygon(pts, colors)

		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(CYAN, 0.34), 1.0, true)
		draw_rect(Rect2(0.0, 10.0, 2.0, h - 20.0), Color(0.98, 0.68, 0.3, 0.55))

		var lamp := Vector2(w * 0.5, 18.0)
		var glow := 0.5 + 0.5 * sin(pulse * 3.0)
		draw_circle(lamp, 4.0 + glow * 2.0, Color(AMBER, 0.1 + glow * 0.08))
		draw_circle(lamp, 2.0, Color(AMBER, 0.85))
		if attention > 0.01:
			draw_arc(
				lamp,
				6.0 + (1.0 - attention) * 16.0,
				0.0,
				TAU,
				28,
				Color(AMBER, attention * 0.55),
				1.5
			)

		var chars := ["任", "务", "日", "志"]
		for i in chars.size():
			draw_string(
				FONT_CN,
				Vector2(0.0, 42.0 + float(i) * 23.0),
				chars[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				w,
				15,
				Color(0.9, 0.95, 0.97, 0.92)
			)

		var bar_x := w - 5.0
		var bar_top := 34.0
		var bar_bottom := h - 30.0
		draw_rect(Rect2(bar_x, bar_top, 2.0, bar_bottom - bar_top), Color(1, 1, 1, 0.1))
		var filled := (bar_bottom - bar_top) * clampf(progress, 0.0, 1.0)
		if filled > 0.5:
			var color := GREEN if complete else CYAN
			draw_rect(Rect2(bar_x, bar_bottom - filled, 2.0, filled), Color(color, 0.9))

		draw_string(
			FONT_MONO,
			Vector2(0.0, h - 14.0),
			chapter_code,
			HORIZONTAL_ALIGNMENT_CENTER,
			w,
			9,
			Color(0.55, 0.7, 0.76, 0.9)
		)
