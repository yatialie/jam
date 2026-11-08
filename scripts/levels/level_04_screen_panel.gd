extends CanvasLayer

## 第四关主控终端面板：底图 + 雾化污渍层，玩家按住鼠标左键擦除污渍。
## 打开时冻结玩家操作，按 F / ESC 关闭；边缘做模糊/羽化处理。

signal closed

const BLUR_SHADER := preload("res://ui/shaders/modal_blur.gdshader")
const GLASS_PANEL := preload("res://ui/components/glass_panel.gd")
const UI_FONT := preload("res://ui/fonts/f_ui.tres")
const MONO_FONT := preload("res://ui/fonts/f_mono.tres")
const CONTENT_TEXTURE := preload("res://art/levels/level_04_screen_content.png")
const CONTENT_SHADER := preload("res://shaders/screen_content_edge.gdshader")
const GRIME_SHADER := preload("res://shaders/screen_grime.gdshader")
const GRIME_TEXTURE_PATH := "res://art/levels/level_04_grime.png"

const MASK_SIZE := Vector2i(512, 280)
const BRUSH_SIZE := 128
const BRUSH_RADIUS := 40.0
const ERASE_COMPLETE := 0.68

var content: VBoxContainer

var _root: Control
var _panel: Control
var _player: CharacterBody2D
var _closing := false
var _ignore_input_until := 0
var _time := 0.0

var _screen_view: Control
var _grime_layer: TextureRect
var _grime_material: ShaderMaterial
var _mask_image: Image
var _mask_texture: ImageTexture
var _brush_image: Image
var _last_erase := Vector2(-1.0, -1.0)
var _erasing := false
var _erase_started := false
var _completed := false
var _progress := 0.0
var _progress_timer := 0.0
var _prompt_root: Control
var _prompt_pill: PanelContainer
var _progress_label: Label
var _screen_frame: ScreenFrame


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepare_mask()
	_build()
	_root.visible = false


func _process(delta: float) -> void:
	if not _root.visible:
		return
	_time += delta
	if _prompt_root != null and _prompt_root.visible and not _erase_started:
		_prompt_root.modulate.a = 0.72 + 0.28 * sin(_time * 3.2)
	if _completed or not _erase_started:
		return
	_progress_timer -= delta
	if _progress_timer <= 0.0:
		_progress_timer = 0.2
		_refresh_progress()


func open() -> void:
	if _root.visible or _closing:
		return
	_root.visible = true
	add_to_group("modal")
	_ignore_input_until = Time.get_ticks_msec() + 180
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_freeze_player()

	_prompt_root.visible = not _erase_started and not _completed
	_prompt_root.modulate.a = 1.0
	_progress_label.visible = _erase_started or _completed
	if _completed:
		_progress_label.text = "SIGNAL RESTORED"
		_progress_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
		_set_grime_reveal(1.0)

	_root.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.97, 0.97)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _root.visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_root, "modulate:a", 0.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2(0.98, 0.98), 0.16)
	tween.finished.connect(_finish_close)


func is_open() -> bool:
	return _root.visible


func _finish_close() -> void:
	_root.visible = false
	_closing = false
	remove_from_group("modal")
	_restore_player()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _root.visible or _closing:
		return
	if Time.get_ticks_msec() < _ignore_input_until:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func _prepare_mask() -> void:
	_mask_image = Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	_mask_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_mask_texture = ImageTexture.create_from_image(_mask_image)
	_brush_image = _make_brush(BRUSH_SIZE, BRUSH_RADIUS)


func _make_brush(size: int, radius: float) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var distance := Vector2(float(x) - center, float(y) - center).length()
			var alpha := 1.0 - smoothstep(radius * 0.42, radius, distance)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return image


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var back := BackBufferCopy.new()
	back.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_root.add_child(back)

	var blur := ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BLUR_SHADER
	material.set_shader_parameter("blur_radius", 3.2)
	material.set_shader_parameter("darken", 0.66)
	material.set_shader_parameter("tint", 0.44)
	material.set_shader_parameter("tint_color", Color(0.02, 0.05, 0.065, 1.0))
	material.set_shader_parameter("fade", 1.0)
	blur.material = material
	_root.add_child(blur)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_panel = GLASS_PANEL.new()
	_panel.custom_minimum_size = Vector2(1240, 800)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	column.add_child(_build_header())

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.35, 0.85, 0.95, 0.28)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)

	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(content)

	content.add_child(_build_screen_view())

	column.add_child(_build_footer())


func _build_screen_view() -> Control:
	_screen_view = Control.new()
	_screen_view.name = "ScreenView"
	_screen_view.custom_minimum_size = Vector2(0, 520)
	_screen_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_view.clip_contents = true
	_screen_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_view.gui_input.connect(_on_screen_gui_input)

	var base := TextureRect.new()
	base.name = "Base"
	base.texture = CONTENT_TEXTURE
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_material := ShaderMaterial.new()
	base_material.shader = CONTENT_SHADER
	base.material = base_material
	_screen_view.add_child(base)

	_grime_layer = TextureRect.new()
	_grime_layer.name = "Grime"
	_grime_layer.texture = _load_grime_texture()
	_grime_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_grime_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_grime_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_grime_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grime_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grime_material = ShaderMaterial.new()
	_grime_material.shader = GRIME_SHADER
	_grime_material.set_shader_parameter("mask_tex", _mask_texture)
	_grime_material.set_shader_parameter("min_density", 0.94)
	_grime_material.set_shader_parameter("reveal", 0.0)
	_grime_layer.material = _grime_material
	_screen_view.add_child(_grime_layer)

	_screen_frame = ScreenFrame.new()
	_screen_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_view.add_child(_screen_frame)

	_build_progress_label()
	_build_prompt()
	return _screen_view


func _load_grime_texture() -> Texture2D:
	if ResourceLoader.exists(GRIME_TEXTURE_PATH):
		var texture := load(GRIME_TEXTURE_PATH)
		if texture is Texture2D:
			return texture
	return _make_placeholder_grime()


func _make_placeholder_grime() -> Texture2D:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 925
	noise.frequency = 0.018
	noise.fractal_octaves = 4
	for y in 256:
		for x in 256:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var alpha := smoothstep(0.38, 0.78, n) * 0.9
			image.set_pixel(x, y, Color(0.88, 0.93, 0.91, alpha))
	return ImageTexture.create_from_image(image)


func _build_prompt() -> void:
	_prompt_root = CenterContainer.new()
	_prompt_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_view.add_child(_prompt_root)

	_prompt_pill = PanelContainer.new()
	_prompt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.05, 0.86)
	style.border_color = Color(0.45, 0.9, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_prompt_pill.add_theme_stylebox_override("panel", style)
	_prompt_root.add_child(_prompt_pill)

	var label := Label.new()
	label.text = "按住鼠标左键擦除污渍，露出底图"
	label.add_theme_font_override("font", UI_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_pill.add_child(label)


func _build_progress_label() -> void:
	_progress_label = Label.new()
	_progress_label.text = "CLEANED  00%"
	_progress_label.anchor_left = 1.0
	_progress_label.anchor_top = 0.0
	_progress_label.anchor_right = 1.0
	_progress_label.anchor_bottom = 0.0
	_progress_label.offset_left = -280.0
	_progress_label.offset_top = 14.0
	_progress_label.offset_right = -18.0
	_progress_label.offset_bottom = 40.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_label.add_theme_font_override("font", MONO_FONT)
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	_progress_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.03, 0.92))
	_progress_label.add_theme_constant_override("outline_size", 4)
	_progress_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_progress_label.add_theme_constant_override("shadow_offset_x", 2)
	_progress_label.add_theme_constant_override("shadow_offset_y", 2)
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_label.visible = false
	_screen_view.add_child(_progress_label)


func _on_screen_gui_input(event: InputEvent) -> void:
	if _completed:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_erasing = button.pressed
			if button.pressed:
				_erase_at(button.position)
			else:
				_last_erase = Vector2(-1.0, -1.0)
	elif event is InputEventMouseMotion and _erasing:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_erase_at(event.position)


func _erase_at(local_position: Vector2) -> void:
	if _screen_view == null or _screen_view.size.x <= 0.0 or _screen_view.size.y <= 0.0:
		return
	var mask_position := Vector2(
		local_position.x / _screen_view.size.x * float(MASK_SIZE.x),
		local_position.y / _screen_view.size.y * float(MASK_SIZE.y)
	)
	if _last_erase.x >= 0.0:
		var distance := _last_erase.distance_to(mask_position)
		var steps := maxi(int(distance / 5.0), 1)
		for i in range(1, steps + 1):
			_stamp_brush(_last_erase.lerp(mask_position, float(i) / float(steps)))
	else:
		_stamp_brush(mask_position)
	_last_erase = mask_position
	_mask_texture.update(_mask_image)

	if not _erase_started:
		_erase_started = true
		_hide_prompt()
		_progress_label.visible = true
		_progress_timer = 0.05


func _stamp_brush(position: Vector2) -> void:
	var half := BRUSH_SIZE / 2
	var max_origin := Vector2i(MASK_SIZE.x - BRUSH_SIZE, MASK_SIZE.y - BRUSH_SIZE)
	var origin := Vector2i(
		clampi(int(position.x) - half, 0, max_origin.x),
		clampi(int(position.y) - half, 0, max_origin.y)
	)
	_mask_image.blend_rect(
		_brush_image,
		Rect2i(0, 0, BRUSH_SIZE, BRUSH_SIZE),
		origin
	)


func _refresh_progress() -> void:
	var total := 0
	var cleared := 0
	var step_x := maxi(MASK_SIZE.x / 40, 1)
	var step_y := maxi(MASK_SIZE.y / 22, 1)
	for y in range(step_y / 2, MASK_SIZE.y, step_y):
		for x in range(step_x / 2, MASK_SIZE.x, step_x):
			total += 1
			if _mask_image.get_pixel(x, y).r > 0.35:
				cleared += 1
	_progress = float(cleared) / float(maxi(total, 1))
	_progress_label.text = "CLEANED  %02d%%" % int(round(_progress * 100.0))
	if _progress >= ERASE_COMPLETE:
		_complete_erase()


func _complete_erase() -> void:
	if _completed:
		return
	_completed = true
	_erasing = false
	_hide_prompt()
	_progress_label.text = "SIGNAL RESTORED"
	_progress_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.75))
	var tween := create_tween()
	tween.tween_method(_set_grime_reveal, 0.0, 1.0, 0.7)


func _set_grime_reveal(value: float) -> void:
	if _grime_material != null:
		_grime_material.set_shader_parameter("reveal", value)


func _hide_prompt() -> void:
	if _prompt_root == null or not _prompt_root.visible:
		return
	var tween := create_tween()
	tween.tween_property(_prompt_root, "modulate:a", 0.0, 0.24)
	tween.tween_callback(_prompt_root.hide)


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


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.text = "主控终端"
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.88, 0.97, 1.0))
	row.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "MAIN TERMINAL"
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	subtitle.add_theme_font_override("font", UI_FONT)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.78, 0.86, 0.85))
	row.add_child(subtitle)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var status := Label.new()
	status.text = "ONLINE"
	status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	status.add_theme_font_override("font", UI_FONT)
	status.add_theme_font_size_override("font_size", 15)
	status.add_theme_color_override("font_color", Color(0.35, 0.9, 0.75, 0.9))
	row.add_child(status)

	return row


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var hint := Label.new()
	hint.text = "鼠标左键擦除污渍   ·   F / ESC  关闭"
	hint.add_theme_font_override("font", UI_FONT)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.55, 0.8, 0.86, 0.8))
	row.add_child(hint)

	return row


class ScreenFrame extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 1.0 or h <= 1.0:
			return
		draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), Color(0.36, 0.87, 0.95, 0.28), false, 1.0)
		var arm := 18.0
		var bright := Color(0.5, 0.95, 1.0, 0.55)
		draw_line(Vector2(0.0, arm), Vector2(0.0, 0.0), bright, 2.0)
		draw_line(Vector2(0.0, 0.0), Vector2(arm, 0.0), bright, 2.0)
		draw_line(Vector2(w - arm, 0.0), Vector2(w, 0.0), bright, 2.0)
		draw_line(Vector2(w, 0.0), Vector2(w, arm), bright, 2.0)
		draw_line(Vector2(0.0, h - arm), Vector2(0.0, h), bright, 2.0)
		draw_line(Vector2(0.0, h), Vector2(arm, h), bright, 2.0)
		draw_line(Vector2(w - arm, h), Vector2(w, h), bright, 2.0)
		draw_line(Vector2(w, h), Vector2(w, h - arm), bright, 2.0)
