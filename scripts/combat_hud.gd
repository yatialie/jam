extends CanvasLayer

## Combat extras: hostile counter and room-clear banner. The hull readout and
## damage feedback live in the shared HudVitals panel.

var _director
var _hostile_label: Label
var _hostile_sub: Label
var _banner: Label
var _banner_sub: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 5
	_build()

	_director = get_tree().get_first_node_in_group("combat_director")
	if _director:
		_director.enemy_count_changed.connect(_on_enemy_count)
		_director.room_cleared.connect(_on_room_cleared)


func _on_enemy_count(count: int) -> void:
	_hostile_label.text = "HOSTILES  %d" % count
	_hostile_label.add_theme_color_override(
		"font_color", Color(1.0, 0.55, 0.4) if count > 0 else Color(0.5, 1.0, 0.8)
	)


## 由关卡导演更新右上角提示文案。
func set_hint(text: String) -> void:
	_hostile_sub.text = text


func _on_room_cleared() -> void:
	_banner.text = "SECTOR CLEARED"
	_banner_sub.text = "ALL HOSTILES NEUTRALIZED"
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.7)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 1.0, 0.9)


## Level directors show a transient headline here, e.g. "ARM HOSTILE".
func announce(title: String, subtitle: String, duration := 2.0) -> void:
	_banner.text = title
	_banner_sub.text = subtitle
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.3)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 1.0, 0.45)
	_banner_tween.set_parallel(false)
	_banner_tween.tween_interval(maxf(duration, 0.5))
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_property(_banner_sub, "modulate:a", 0.0, 0.6)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hostile_label = Label.new()
	_hostile_label.anchor_left = 1.0
	_hostile_label.anchor_right = 1.0
	_hostile_label.offset_left = -440.0
	_hostile_label.offset_right = -32.0
	_hostile_label.offset_top = 22.0
	_hostile_label.offset_bottom = 62.0
	_hostile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hostile_label.add_theme_font_size_override("font_size", 26)
	_hostile_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.4))
	_hostile_label.text = "HOSTILES  --"
	root.add_child(_hostile_label)

	_hostile_sub = Label.new()
	_hostile_sub.anchor_left = 1.0
	_hostile_sub.anchor_right = 1.0
	_hostile_sub.offset_left = -440.0
	_hostile_sub.offset_right = -32.0
	_hostile_sub.offset_top = 64.0
	_hostile_sub.offset_bottom = 90.0
	_hostile_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hostile_sub.add_theme_font_size_override("font_size", 13)
	_hostile_sub.add_theme_color_override("font_color", Color(0.55, 0.66, 0.74))
	_hostile_sub.text = "SOLVE ACCESS OVERRIDE TO EXIT"
	root.add_child(_hostile_sub)

	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -620.0
	_banner.offset_right = 620.0
	_banner.offset_top = -120.0
	_banner.offset_bottom = -30.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 58)
	_banner.add_theme_color_override("font_color", Color(0.55, 1.0, 0.85))
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_banner_sub = Label.new()
	_banner_sub.anchor_left = 0.5
	_banner_sub.anchor_right = 0.5
	_banner_sub.anchor_top = 0.5
	_banner_sub.anchor_bottom = 0.5
	_banner_sub.offset_left = -620.0
	_banner_sub.offset_right = 620.0
	_banner_sub.offset_top = -20.0
	_banner_sub.offset_bottom = 20.0
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 20)
	_banner_sub.add_theme_color_override("font_color", Color(0.66, 0.84, 0.9))
	_banner_sub.modulate.a = 0.0
	root.add_child(_banner_sub)
