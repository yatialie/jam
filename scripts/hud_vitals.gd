extends Control

## Top-left hull readout: a compact cassette-glass panel with location, a
## segmented integrity gauge and the control hint. Reads the player's health
## signals, so it works in every gameplay scene.

const FONT_MONO: Font = preload("res://ui/fonts/f_mono.tres")
const FONT_TRACKED: Font = preload("res://ui/fonts/f_label_tracked.tres")
const PANEL_TEXTURE: Texture2D = preload("res://art_placeholder/scifi_ui/ui_mission_panel_tex.jpg")

const PANEL_X := 18.0
const PANEL_Y := 16.0
const SPINE_W := 20.0
const PANEL_W := 400.0
const PANEL_H := 112.0
const TOTAL_W := SPINE_W + PANEL_W

const CYAN := Color(0.32, 0.86, 0.94)
const AMBER := Color(0.98, 0.68, 0.3)
const RED := Color(1.0, 0.34, 0.3)
const GREEN := Color(0.42, 1.0, 0.78)

@export var location_text := "BERTH 07 / SPAWN DECK":
	set(value):
		location_text = value
		if is_instance_valid(_location_label):
			_location_label.text = value

@export var hint_text := "WASD 移动    SHIFT 奔跑    RMB 瞄准    LMB 射击    F 交互    ESC 暂停":
	set(value):
		hint_text = value
		if is_instance_valid(_hint_label):
			_hint_label.text = value

var _expanded: Control
var _spine: VitalSpine
var _frame: JamHudFrame
var _cells: VitalCells
var _location_label: Label
var _status_label: Label
var _hint_label: Label
var _value_label: Label
var _unit_label: Label

var _player: CharacterBody2D
var _health := 3
var _max_health := 3
var _dead := false
var _critical := false

var _death_overlay: Control
var _death_tween: Tween

var _open := 0.0
var _target_open := 0.0
var _time := 0.0
var _shake := 0.0
var _danger := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_build_death_overlay()
	_bind_player()

	var intro := create_tween()
	intro.tween_interval(0.16)
	intro.tween_callback(func() -> void: _target_open = 1.0)


func _process(delta: float) -> void:
	_time += delta
	_open = lerpf(_open, _target_open, 1.0 - exp(-delta * 11.0))
	_shake = maxf(_shake - delta * 3.2, 0.0)
	_danger = maxf(_danger - delta * 1.8, 0.0)
	_apply_open()

	_frame.danger = _danger
	_spine.ratio = float(_health) / maxf(float(_max_health), 1.0)
	_spine.critical = _critical or _dead

	_status_label.add_theme_color_override(
		"font_color", _status_color()
	)
	_value_label.add_theme_color_override(
		"font_color", RED if (_critical or _dead) else CYAN
	)


func _apply_open() -> void:
	var offset := 0.0
	if _shake > 0.001:
		offset = sin(_time * 68.0) * 4.5 * _shake
	_expanded.position = Vector2(lerpf(-TOTAL_W - 30.0, PANEL_X, _open) + offset, PANEL_Y)
	_expanded.modulate.a = clampf(_open * 1.25, 0.0, 1.0)
	_expanded.visible = _expanded.modulate.a > 0.01


func _build() -> void:
	_expanded = Control.new()
	_expanded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expanded.position = Vector2(PANEL_X, PANEL_Y)
	_expanded.size = Vector2(TOTAL_W, PANEL_H)
	add_child(_expanded)

	_spine = VitalSpine.new()
	_spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spine.position = Vector2.ZERO
	_spine.size = Vector2(SPINE_W, PANEL_H)
	_expanded.add_child(_spine)

	_frame = JamHudFrame.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture = PANEL_TEXTURE
	_frame.header_h = 30.0
	_frame.footer_h = 32.0
	_frame.show_progress = false
	_frame.position = Vector2(SPINE_W, 0.0)
	_frame.size = Vector2(PANEL_W, PANEL_H)
	_expanded.add_child(_frame)

	var tick := ColorRect.new()
	tick.color = Color(0.98, 0.68, 0.3, 0.9)
	tick.position = Vector2(14.0, 8.0)
	tick.size = Vector2(3.0, 14.0)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(tick)

	_location_label = _make_label(FONT_MONO, 10, Color(0.88, 0.94, 0.96, 0.95))
	_location_label.text = location_text
	_location_label.position = Vector2(24.0, 6.0)
	_location_label.size = Vector2(240.0, 16.0)
	_location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_status_label = _make_label(FONT_MONO, 9, CYAN)
	_status_label.position = Vector2(PANEL_W - 144.0, 6.0)
	_status_label.size = Vector2(130.0, 16.0)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.text = "HULL ONLINE"

	_cells = VitalCells.new()
	_cells.position = Vector2(14.0, 33.0)
	_cells.size = Vector2(PANEL_W - 88.0, 28.0)
	_cells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_cells)

	_value_label = _make_label(FONT_MONO, 16, CYAN)
	_value_label.position = Vector2(PANEL_W - 74.0, 28.0)
	_value_label.size = Vector2(60.0, 22.0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.text = "3 / 3"

	_unit_label = _make_label(FONT_MONO, 7, Color(0.45, 0.6, 0.66, 0.8))
	_unit_label.position = Vector2(PANEL_W - 74.0, 50.0)
	_unit_label.size = Vector2(60.0, 12.0)
	_unit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_unit_label.text = "SHELL"

	_hint_label = _make_label(FONT_MONO, 10, Color(0.56, 0.69, 0.74, 0.74))
	_hint_label.text = hint_text
	_hint_label.position = Vector2(14.0, 84.0)
	_hint_label.size = Vector2(PANEL_W - 28.0, 16.0)
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_death_overlay() -> void:
	_death_overlay = Control.new()
	_death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.modulate.a = 0.0
	_death_overlay.visible = false
	add_child(_death_overlay)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray(
		[
			Color(0.01, 0.02, 0.03, 0.58),
			Color(0.01, 0.02, 0.03, 0.26),
			Color(0.01, 0.02, 0.03, 0.0),
		]
	)
	var pool_texture := GradientTexture2D.new()
	pool_texture.gradient = gradient
	pool_texture.width = 512
	pool_texture.height = 256
	pool_texture.fill = GradientTexture2D.FILL_RADIAL
	pool_texture.fill_from = Vector2(0.5, 0.5)
	pool_texture.fill_to = Vector2(1.0, 0.5)

	var pool := TextureRect.new()
	pool.texture = pool_texture
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.anchor_left = 0.5
	pool.anchor_top = 0.5
	pool.anchor_right = 0.5
	pool.anchor_bottom = 0.5
	pool.offset_left = -560.0
	pool.offset_top = -120.0
	pool.offset_right = 560.0
	pool.offset_bottom = 120.0
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.add_child(pool)

	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_top = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -420.0
	box.offset_top = -64.0
	box.offset_right = 420.0
	box.offset_bottom = 64.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay.add_child(box)

	var title := Label.new()
	title.text = "SIGNAL LOST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_TRACKED)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.34, 0.3, 0.95))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(360.0, 1.0)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	line.color = Color(1.0, 0.34, 0.3, 0.35)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var sub := Label.new()
	sub.text = "VITAL LINK SEVERED  //  REBOOTING TAPE"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", FONT_MONO)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.72, 0.5, 0.5, 0.75))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)


func _show_death_overlay(shown: bool) -> void:
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	if shown:
		_death_overlay.visible = true
		_death_overlay.modulate.a = 0.0
		_death_tween = create_tween()
		_death_tween.tween_property(_death_overlay, "modulate:a", 1.0, 0.25)
	else:
		_death_tween = create_tween()
		_death_tween.tween_property(_death_overlay, "modulate:a", 0.0, 0.15)
		_death_tween.tween_callback(func() -> void: _death_overlay.visible = false)


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


func _bind_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		_apply_health()
		return
	_max_health = int(_player.max_health)
	_health = int(_player.health)
	_player.health_changed.connect(_on_health_changed)
	_player.damaged.connect(_on_damaged)
	_player.died.connect(_on_died)
	_player.respawned.connect(_on_respawned)
	_apply_health()


func _on_health_changed(current: int, maximum: int) -> void:
	var recovered := current > _health
	_health = current
	_max_health = maximum
	if recovered:
		_cells.sweep = 1.0
	_apply_health()


func _on_damaged(_amount: int) -> void:
	_shake = 1.0
	_danger = 1.0
	_cells.flash = 1.0


func _on_died() -> void:
	_dead = true
	_apply_health()
	_show_death_overlay(true)


func _on_respawned() -> void:
	_dead = false
	_health = int(_player.max_health)
	_max_health = int(_player.max_health)
	_cells.sweep = 1.0
	_show_death_overlay(false)
	_apply_health()


func _apply_health() -> void:
	_critical = _health > 0 and _health <= 1
	_cells.maximum = float(maxi(_max_health, 1))
	_cells.health = float(clampi(_health, 0, _max_health))
	_cells.critical = _critical or _dead
	_value_label.text = "%d / %d" % [_health, _max_health]
	_update_status()


func _update_status() -> void:
	if _dead:
		_status_label.text = "SIGNAL LOST"
		return
	if _critical:
		_status_label.text = "HULL CRITICAL"
		return
	_status_label.text = "HULL ONLINE"


func _status_color() -> Color:
	if _dead:
		return Color(RED, 0.9)
	if _critical:
		return Color(RED, 0.55 + 0.45 * (0.5 + 0.5 * sin(_time * 7.0)))
	return Color(CYAN, 0.8)


class VitalCells extends Control:
	const CYAN := Color(0.32, 0.86, 0.94)
	const RED := Color(1.0, 0.34, 0.3)

	var maximum := 3.0
	var health := 3.0
	var display := 3.0
	var critical := false
	var flash := 0.0
	var sweep := 0.0
	var _phase := 0.0


	func _ready() -> void:
		display = health
		mouse_filter = Control.MOUSE_FILTER_IGNORE


	func _process(delta: float) -> void:
		_phase += delta
		display = lerpf(display, health, 1.0 - exp(-delta * 8.0))
		if absf(display - health) < 0.01:
			display = health
		flash = maxf(flash - delta * 2.4, 0.0)
		sweep = maxf(sweep - delta * 1.8, 0.0)
		queue_redraw()


	func _draw() -> void:
		var count := int(maximum)
		if count <= 0:
			return
		var gap := 8.0
		var cell_w := (size.x - gap * float(count - 1)) / float(count)
		var col := RED if critical else CYAN
		var pulse := 0.5 + 0.5 * sin(_phase * 6.0)

		for i in count:
			var x := float(i) * (cell_w + gap)
			var level := clampf(display - float(i), 0.0, 1.0)
			var pts := _chamfer(x, 0.0, cell_w, size.y, 4.0)
			draw_colored_polygon(pts, Color(0.014, 0.036, 0.044, 0.94))

			# dead-cell texture
			if level < 0.999:
				var hx := x + 4.0
				while hx < x + cell_w - 4.0:
					draw_line(
						Vector2(hx, 4.0),
						Vector2(hx, size.y - 4.0),
						Color(1.0, 0.3, 0.28, 0.045),
						1.0
					)
					hx += 7.0

			if level > 0.001:
				var fill_alpha := level * (0.82 + 0.12 * pulse if critical else 0.94)
				var colors := PackedColorArray()
				for p in pts:
					var t := clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)
					colors.append(
						Color(col.r, col.g, col.b, (0.9 - 0.48 * t) * fill_alpha)
					)
				draw_polygon(pts, colors)
				draw_line(
					Vector2(x + 5.0, 2.0),
					Vector2(x + cell_w - 5.0, 2.0),
					Color(1, 1, 1, 0.32 * level),
					1.0
				)
				draw_line(
					Vector2(x + 5.0, size.y - 6.0),
					Vector2(x + cell_w - 5.0, size.y - 6.0),
					Color(0, 0, 0, 0.18 * level),
					2.0
				)
				if level < 0.999:
					var edge_x := x + 2.0 + (cell_w - 4.0) * level
					draw_line(
						Vector2(edge_x, 3.0),
						Vector2(edge_x, size.y - 3.0),
						Color(1, 1, 1, 0.6),
						2.0
					)

			var closed := pts.duplicate()
			closed.append(pts[0])
			var rim := Color(col, 0.55) if level > 0.15 else Color(1.0, 0.3, 0.28, 0.22)
			draw_polyline(closed, rim, 1.0, true)

			if level > 0.001 and critical:
				draw_rect(Rect2(x + 2.0, size.y - 3.0, (cell_w - 4.0) * level, 2.0), Color(RED, 0.8))

		if flash > 0.001:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.35, 0.3, 0.18 * flash))

		if sweep > 0.001:
			var sx := size.x * (1.0 - sweep)
			draw_line(Vector2(sx, 1.0), Vector2(sx, size.y - 1.0), Color(0.42, 1.0, 0.78, 0.6 * sweep), 2.0)


	func _chamfer(x: float, y: float, w: float, h: float, c: float) -> PackedVector2Array:
		return PackedVector2Array(
			[
				Vector2(x + c, y),
				Vector2(x + w - c, y),
				Vector2(x + w, y + c),
				Vector2(x + w, y + h - c),
				Vector2(x + w - c, y + h),
				Vector2(x + c, y + h),
				Vector2(x, y + h - c),
				Vector2(x, y + c),
			]
		)


class VitalSpine extends Control:
	const FONT: Font = preload("res://ui/fonts/f_label_tracked.tres")
	const CYAN := Color(0.32, 0.86, 0.94)
	const RED := Color(1.0, 0.34, 0.3)

	var ratio := 1.0
	var critical := false
	var _phase := 0.0


	func _process(delta: float) -> void:
		_phase += delta
		queue_redraw()


	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.008, 0.02, 0.027, 0.94))
		draw_line(Vector2(0.0, 4.0), Vector2(0.0, h - 4.0), Color(0, 0, 0, 0.5), 2.0)
		draw_line(Vector2(w - 0.5, 6.0), Vector2(w - 0.5, h - 6.0), Color(CYAN, 0.35), 1.0)

		var y := 12.0
		var index := 0
		while y < h - 8.0:
			var long := index % 4 == 0
			draw_line(
				Vector2(w - (9.0 if long else 5.0), y),
				Vector2(w - 2.0, y),
				Color(1, 1, 1, 0.1),
				1.0
			)
			y += 7.0
			index += 1

		var bar_top := 26.0
		var bar_bottom := h - 30.0
		draw_rect(Rect2(7.0, bar_top, 4.0, bar_bottom - bar_top), Color(1, 1, 1, 0.08))
		var filled := (bar_bottom - bar_top) * clampf(ratio, 0.0, 1.0)
		var color := CYAN
		var alpha := 0.85
		if critical:
			color = RED
			alpha = 0.55 + 0.4 * (0.5 + 0.5 * sin(_phase * 7.0))
		if filled > 0.5:
			draw_rect(Rect2(7.0, bar_bottom - filled, 4.0, filled), Color(color, alpha))

		draw_set_transform(Vector2(14.0, h - 8.0), -PI / 2.0, Vector2.ONE)
		draw_string(
			FONT,
			Vector2.ZERO,
			"VITAL TAPE // SIDE B",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			7,
			Color(0.78, 0.9, 0.94, 0.5)
		)
