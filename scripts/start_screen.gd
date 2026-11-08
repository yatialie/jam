extends Control

## Start screen: a gloved hand holding a cassette whose glass label is the menu.

const OPENING_CUTSCENE := "res://scenes/cutscenes/opening_cutscene.tscn"
const CHARACTERS := ["nova", "astronaut"]
const CHARACTER_LABELS := {"nova": "NOVA", "astronaut": "ASTRONAUT"}

@onready var hero_rig: Control = $HeroRig
@onready var character_button: Button = $Chrome/CharacterSelect
@onready var title_kicker: Label = $Title/Kicker
@onready var title_jam: Label = $Title/TitleJam
@onready var title_station: Label = $Title/TitleStation
@onready var title_rule: ColorRect = $Title/Rule
@onready var title_tagline: Label = $Title/Tagline
@onready var title_tagline_en: Label = $Title/TaglineEn
@onready var btn_start: JamMenuButton = $HeroRig/Menu/BtnStart
@onready var btn_settings: JamMenuButton = $HeroRig/Menu/BtnSettings
@onready var settings_panel: Control = $SettingsPanel
@onready var fade: ColorRect = $Fade
@onready var rec_label: Label = $Chrome/Rec
@onready var timecode_label: Label = $Chrome/Timecode

var _time: float = 0.0
var _hero_home: Vector2 = Vector2.ZERO
var _mouse_offset: Vector2 = Vector2.ZERO
var _starting: bool = false


func _ready() -> void:
	_hero_home = hero_rig.position
	_time = 0.0

	btn_start.pressed.connect(_on_start_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	character_button.pressed.connect(_cycle_character)
	settings_panel.close_requested.connect(_on_settings_closed)
	_update_character_label()

	btn_start.focus_neighbor_top = btn_start.get_path_to(btn_settings)
	btn_start.focus_neighbor_bottom = btn_start.get_path_to(btn_settings)
	btn_settings.focus_neighbor_top = btn_settings.get_path_to(btn_start)
	btn_settings.focus_neighbor_bottom = btn_settings.get_path_to(btn_start)

	_play_intro()
	btn_start.grab_focus()


func _process(delta: float) -> void:
	_time += delta

	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse: Vector2 = get_viewport().get_mouse_position() / viewport_size * 2.0 - Vector2.ONE
	mouse = mouse.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	var parallax_target := Vector2(-mouse.x * 8.0, -mouse.y * 6.0)
	_mouse_offset = _mouse_offset.lerp(parallax_target, 1.0 - exp(-delta * 2.2))
	hero_rig.position = _hero_home + _mouse_offset + Vector2(0.0, sin(_time * 0.6) * 3.5)

	rec_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))
	var seconds: int = int(_time)
	timecode_label.text = "00:%02d:%02d" % [(seconds / 60) % 60, seconds % 60]


func _play_intro() -> void:
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "color:a", 0.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)

	hero_rig.modulate.a = 0.0
	var hero_tween := create_tween().set_parallel(true)
	hero_tween.tween_property(hero_rig, "modulate:a", 1.0, 0.9).set_delay(0.1)
	hero_tween.tween_method(
		_set_hero_home_x, _hero_home.x + 48.0, _hero_home.x, 1.2
	).set_delay(0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var title_items: Array[Control] = [
		title_kicker,
		title_jam,
		title_station,
		title_rule,
		title_tagline,
		title_tagline_en,
	]
	for i in range(title_items.size()):
		var item: Control = title_items[i]
		var home: Vector2 = item.position
		item.modulate.a = 0.0
		item.position = home + Vector2(0.0, 16.0)
		var delay: float = 0.32 + float(i) * 0.075
		var tween := create_tween().set_parallel(true)
		tween.tween_property(item, "modulate:a", 1.0, 0.55).set_delay(delay)
		tween.tween_property(item, "position", home, 0.75).set_delay(delay).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)

	var menu_buttons: Array[JamMenuButton] = [btn_start, btn_settings]
	for i in range(menu_buttons.size()):
		var button: JamMenuButton = menu_buttons[i]
		var home: Vector2 = button.position
		button.modulate.a = 0.0
		button.position = home + Vector2(-18.0, 0.0)
		var delay: float = 0.62 + float(i) * 0.09
		var tween := create_tween().set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.5).set_delay(delay)
		tween.tween_property(button, "position", home, 0.65).set_delay(delay).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)


func _set_hero_home_x(x: float) -> void:
	_hero_home.x = x


func _unhandled_input(event: InputEvent) -> void:
	if _starting or settings_panel.visible:
		return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		_cycle_character()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_settings_pressed()
		get_viewport().set_input_as_handled()


func _cycle_character() -> void:
	var index := CHARACTERS.find(UserSettings.character)
	UserSettings.character = CHARACTERS[(index + 1) % CHARACTERS.size()]
	UserSettings.save_settings()
	_update_character_label()
	btn_start.grab_focus()


func _update_character_label() -> void:
	var display_name := str(CHARACTER_LABELS.get(UserSettings.character, "NOVA"))
	character_button.text = "PILOT // %s    [C] SWITCH" % display_name


func _on_settings_pressed() -> void:
	if _starting:
		return
	settings_panel.open()


func _on_settings_closed() -> void:
	btn_start.grab_focus()


func _on_start_pressed() -> void:
	if _starting:
		return
	_starting = true
	btn_start.disabled = true
	btn_settings.disabled = true
	btn_start.release_focus()

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	tween.tween_callback(_enter_game)


func _enter_game() -> void:
	get_tree().change_scene_to_file(OPENING_CUTSCENE)
