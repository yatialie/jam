extends Control

## Start screen: a gloved hand holds a translucent cassette over a deep-space
## field. The tape's ribbon menu fans out to the right. Layered parallax,
## staggered fade-in, then the existing opening cutscene.

const OPENING_CUTSCENE := "res://scenes/cutscenes/opening_cutscene.tscn"
const CHARACTERS := ["nova", "astronaut"]
const CHARACTER_LABELS := {"nova": "NOVA", "astronaut": "ASTRONAUT"}

@onready var backdrop: Control = $Backdrop
@onready var starfield: TextureRect = $Backdrop/Starfield
@onready var haze: Control = $Backdrop/Haze
@onready var haze_a: TextureRect = $Backdrop/Haze/HazeA
@onready var haze_b: TextureRect = $Backdrop/Haze/HazeB
@onready var haze_c: TextureRect = $Backdrop/Haze/HazeC
@onready var stars: Control = $Stars
@onready var dust: Control = $Dust
@onready var rings: Control = $Rings
@onready var hero_rig: Control = $HeroRig
@onready var hero_inner: Control = $HeroRig/HeroInner
@onready var aura: TextureRect = $HeroRig/HeroInner/Aura
@onready var sheen: TextureRect = $HeroRig/HeroInner/Sheen
@onready var tape_label: Control = $HeroRig/HeroInner/LabelPlate
@onready var menu_glow: TextureRect = $HeroRig/HeroInner/MenuRig/Glow
@onready var start_clip: Control = $HeroRig/HeroInner/MenuRig/StartClip
@onready var options_clip: Control = $HeroRig/HeroInner/MenuRig/OptionsClip
@onready var exit_clip: Control = $HeroRig/HeroInner/MenuRig/ExitClip
@onready var btn_start: TapeRibbonButton = $HeroRig/HeroInner/MenuRig/StartClip/BtnStart
@onready var btn_options: TapeRibbonButton = $HeroRig/HeroInner/MenuRig/OptionsClip/BtnOptions
@onready var btn_exit: TapeRibbonButton = $HeroRig/HeroInner/MenuRig/ExitClip/BtnExit
@onready var session: Control = $Session
@onready var rec_label: Label = $Session/Rec
@onready var timecode: Label = $Session/Timecode
@onready var hint: Label = $Hint
@onready var pilot_button: Button = $PilotButton
@onready var settings_panel: Control = $SettingsPanel
@onready var fade: ColorRect = $Fade
@onready var exit_screen: Control = $ExitScreen

@onready var title_nodes: Array[Control] = [
	$TitleBlock/KickerLine,
	$TitleBlock/Kicker,
	$TitleBlock/TitleJam,
	$TitleBlock/TitleStation,
	$TitleBlock/Rule,
	$TitleBlock/Tagline,
	$TitleBlock/TaglineEn,
]

var _hero_home: Vector2 = Vector2.ZERO
var _backdrop_home: Vector2 = Vector2.ZERO
var _haze_home: Vector2 = Vector2.ZERO
var _haze_homes: Array[Vector2] = []
var _rings_home: Vector2 = Vector2.ZERO
var _dust_home: Vector2 = Vector2.ZERO
var _title_homes: Array[Vector2] = []
var _mouse: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _last_second: int = -1
var _starting: bool = false
var _exiting: bool = false


func _ready() -> void:
	_hero_home = hero_rig.position
	_backdrop_home = backdrop.position
	_haze_home = haze.position
	_haze_homes = [haze_a.position, haze_b.position, haze_c.position]
	_rings_home = rings.position
	_dust_home = dust.position
	for item in title_nodes:
		_title_homes.append(item.position)

	hero_rig.pivot_offset = hero_rig.size * 0.5
	aura.pivot_offset = aura.size * 0.5

	btn_start.pressed.connect(_on_start_pressed)
	btn_options.pressed.connect(_on_settings_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	pilot_button.pressed.connect(_cycle_character)
	settings_panel.close_requested.connect(_on_settings_closed)
	_update_pilot_label()

	btn_start.focus_neighbor_top = btn_start.get_path_to(btn_exit)
	btn_start.focus_neighbor_bottom = btn_start.get_path_to(btn_options)
	btn_options.focus_neighbor_top = btn_options.get_path_to(btn_start)
	btn_options.focus_neighbor_bottom = btn_options.get_path_to(btn_exit)
	btn_exit.focus_neighbor_top = btn_exit.get_path_to(btn_options)
	btn_exit.focus_neighbor_bottom = btn_exit.get_path_to(btn_start)

	_play_intro()
	btn_start.grab_focus()


func _process(delta: float) -> void:
	_time += delta

	var viewport_size: Vector2 = get_viewport_rect().size
	var raw: Vector2 = get_viewport().get_mouse_position() / viewport_size * 2.0 - Vector2.ONE
	raw = raw.clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	_mouse = _mouse.lerp(raw, 1.0 - exp(-delta * 3.2))

	backdrop.position = _backdrop_home + Vector2(-_mouse.x * 12.0, -_mouse.y * 8.0)
	haze.position = _haze_home + Vector2(-_mouse.x * 20.0, -_mouse.y * 13.0)
	stars.parallax_offset = Vector2(-_mouse.x * 16.0, -_mouse.y * 11.0)
	dust.position = _dust_home + Vector2(-_mouse.x * 30.0, -_mouse.y * 20.0)
	rings.position = _rings_home + Vector2(-_mouse.x * 10.0, -_mouse.y * 7.0)

	haze_a.position = (
		_haze_homes[0] + Vector2(sin(_time * 0.08) * 16.0, cos(_time * 0.07) * 10.0)
	)
	haze_b.position = (
		_haze_homes[1] + Vector2(cos(_time * 0.06) * 20.0, sin(_time * 0.05) * 12.0)
	)
	haze_c.position = (
		_haze_homes[2] + Vector2(sin(_time * 0.05 + 1.7) * 14.0, cos(_time * 0.06) * 9.0)
	)

	var bob: float = sin(_time * 0.62) * 5.5
	hero_rig.position = _hero_home + Vector2(-_mouse.x * 26.0, -_mouse.y * 17.0 + bob)
	hero_rig.rotation = deg_to_rad(_mouse.x * 0.5)
	aura.scale = Vector2.ONE * (1.0 + 0.035 * sin(_time * 0.8))

	rec_label.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 3.0))
	var second: int = int(_time)
	if second != _last_second:
		_last_second = second
		timecode.text = "00:%02d:%02d" % [(second / 60) % 60, second % 60]


func _play_intro() -> void:
	fade.color = Color(0.0, 0.0, 0.0, 1.0)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := create_tween()
	veil.tween_property(fade, "color:a", 0.0, 1.5).set_delay(0.1).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	veil.tween_callback(func() -> void: fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)

	starfield.pivot_offset = starfield.size * 0.5
	starfield.scale = Vector2(1.14, 1.14)
	starfield.modulate.a = 0.0
	var bg_tween := create_tween().set_parallel(true)
	bg_tween.tween_property(starfield, "scale", Vector2(1.02, 1.02), 2.8).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	bg_tween.tween_property(starfield, "modulate:a", 1.0, 2.0)

	haze.modulate.a = 0.0
	stars.modulate.a = 0.0
	dust.modulate.a = 0.0
	rings.modulate.a = 0.0
	var ambience := create_tween().set_parallel(true)
	ambience.tween_property(haze, "modulate:a", 1.0, 3.4).set_delay(0.6)
	ambience.tween_property(stars, "modulate:a", 1.0, 2.0).set_delay(0.5)
	ambience.tween_property(dust, "modulate:a", 0.9, 2.4).set_delay(0.9)
	ambience.tween_property(rings, "modulate:a", 0.55, 2.4).set_delay(1.1)

	hero_inner.modulate.a = 0.0
	hero_inner.position = Vector2(0.0, 38.0)
	hero_inner.scale = Vector2(0.972, 0.972)
	hero_inner.pivot_offset = hero_inner.size * 0.5
	var hero_tween := create_tween().set_parallel(true)
	hero_tween.tween_property(hero_inner, "modulate:a", 1.0, 1.2).set_delay(0.42)
	hero_tween.tween_property(hero_inner, "position:y", 0.0, 1.45).set_delay(0.42).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	hero_tween.tween_property(hero_inner, "scale", Vector2.ONE, 1.45).set_delay(0.42).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)

	var sheen_mat := sheen.material as ShaderMaterial
	if sheen_mat != null:
		sheen_mat.set_shader_parameter("progress", 1.25)
		var sweep := create_tween()
		sweep.tween_method(_set_sheen_progress, 1.25, -0.35, 1.5).set_delay(1.1).set_trans(
			Tween.TRANS_CUBIC
		)

	tape_label.modulate.a = 0.0
	create_tween().tween_property(tape_label, "modulate:a", 1.0, 1.0).set_delay(1.5)

	var clips: Array[Control] = [start_clip, options_clip, exit_clip]
	for i in range(clips.size()):
		var clip: Control = clips[i]
		clip.size = Vector2(0.0, 80.0)
		clip.modulate.a = 0.0
		var delay: float = 1.18 + float(i) * 0.14
		var tween := create_tween().set_parallel(true)
		tween.tween_property(clip, "size:x", 1000.0, 1.0).set_delay(delay).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)
		tween.tween_property(clip, "modulate:a", 1.0, 0.28).set_delay(delay)

	for i in range(title_nodes.size()):
		var item: Control = title_nodes[i]
		var home: Vector2 = _title_homes[i]
		item.modulate.a = 0.0
		item.position = home + Vector2(0.0, 14.0)
		var delay: float = 1.75 + float(i) * 0.07
		var tween := create_tween().set_parallel(true)
		tween.tween_property(item, "modulate:a", 1.0, 0.85).set_delay(delay)
		tween.tween_property(item, "position", home, 1.0).set_delay(delay).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)

	session.modulate.a = 0.0
	hint.modulate.a = 0.0
	pilot_button.modulate.a = 0.0
	var chrome := create_tween().set_parallel(true)
	chrome.tween_property(session, "modulate:a", 1.0, 1.0).set_delay(2.0)
	chrome.tween_property(hint, "modulate:a", 1.0, 1.0).set_delay(2.2)
	chrome.tween_property(pilot_button, "modulate:a", 1.0, 1.0).set_delay(2.3)


func _set_sheen_progress(value: float) -> void:
	if sheen.material is ShaderMaterial:
		(sheen.material as ShaderMaterial).set_shader_parameter("progress", value)


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _exiting or settings_panel.visible:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		if key.physical_keycode == KEY_C:
			_cycle_character()
			get_viewport().set_input_as_handled()
		elif key.is_action_pressed("ui_cancel"):
			_on_settings_pressed()
			get_viewport().set_input_as_handled()


func _cycle_character() -> void:
	var index: int = CHARACTERS.find(UserSettings.character)
	UserSettings.character = CHARACTERS[(index + 1) % CHARACTERS.size()]
	UserSettings.save_settings()
	_update_pilot_label()
	btn_start.grab_focus()


func _update_pilot_label() -> void:
	var display_name := str(CHARACTER_LABELS.get(UserSettings.character, "NOVA"))
	pilot_button.text = "PILOT // %s    [C] SWITCH" % display_name


func _on_settings_pressed() -> void:
	if _starting or _exiting:
		return
	settings_panel.open()


func _on_settings_closed() -> void:
	btn_start.grab_focus()


func _on_start_pressed() -> void:
	if _starting or _exiting:
		return
	_starting = true
	_set_menu_enabled(false)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	tween.tween_callback(_enter_game)


func _enter_game() -> void:
	get_tree().change_scene_to_file(OPENING_CUTSCENE)


func _on_exit_pressed() -> void:
	if _starting or _exiting:
		return
	_exiting = true
	_set_menu_enabled(false)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	await tween.finished

	exit_screen.visible = true
	var reveal := create_tween()
	reveal.tween_property(exit_screen, "modulate:a", 1.0, 0.6)
	await reveal.finished
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _set_menu_enabled(enabled: bool) -> void:
	for button in [btn_start, btn_options, btn_exit]:
		(button as Button).disabled = not enabled
		if not enabled:
			(button as Button).release_focus()
