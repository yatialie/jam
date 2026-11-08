extends Node

## Persists player-facing options and applies them to the engine.

signal display_changed

const CONFIG_PATH := "user://jam_settings.cfg"
const BASE_SIZE := Vector2i(1920, 1080)
const MIN_WINDOW_SIZE := Vector2i(1024, 576)
const WINDOW_SCREEN_FRACTION := 0.82

var master_volume: float = 0.8
var fullscreen: bool = false
var vsync: bool = true
var mouse_sensitivity: float = 1.0
var character: String = "nova"
var window_size: Vector2i = Vector2i.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_setup_window()
	apply_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	master_volume = clampf(
		float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0
	)
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
	vsync = bool(config.get_value("video", "vsync", vsync))
	var saved_width := int(config.get_value("video", "window_width", 0))
	var saved_height := int(config.get_value("video", "window_height", 0))
	if saved_width > 0 and saved_height > 0:
		window_size = Vector2i(saved_width, saved_height)
	mouse_sensitivity = clampf(
		float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.2, 2.5
	)
	var saved_character := str(config.get_value("game", "character", character))
	if saved_character in ["nova", "astronaut"]:
		character = saved_character


func save_settings() -> void:
	_capture_windowed_size()
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "window_width", window_size.x)
	config.set_value("video", "window_height", window_size.y)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("game", "character", character)
	config.save(CONFIG_PATH)


func apply_all() -> void:
	apply_audio()
	apply_video()


func apply_audio() -> void:
	var bus: int = AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(bus, master_volume <= 0.001)


func apply_video() -> void:
	var mode: int = DisplayServer.window_get_mode()
	var is_fullscreen: bool = (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)
	if fullscreen and not is_fullscreen:
		window_size = get_window().size
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_restore_windowed_size()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	display_changed.emit()


func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply_video()
	save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		var is_toggle := (
			key.physical_keycode == KEY_F11
			or (
				key.alt_pressed
				and (key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER)
			)
		)
		if is_toggle:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func _setup_window() -> void:
	var window := get_window()
	window.min_size = MIN_WINDOW_SIZE
	if fullscreen:
		return
	window.size = _fit_to_screen(window_size if window_size != Vector2i.ZERO else _default_size())
	window.position = _centered_position(window.size, window.current_screen)
	window_size = window.size


func _default_size() -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return BASE_SIZE
	var fit := minf(
		float(usable.size.x) * WINDOW_SCREEN_FRACTION / float(BASE_SIZE.x),
		float(usable.size.y) * WINDOW_SCREEN_FRACTION / float(BASE_SIZE.y)
	)
	var target := Vector2i(int(BASE_SIZE.x * fit), int(BASE_SIZE.y * fit))
	return _fit_to_screen(target)


func _fit_to_screen(target: Vector2i) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return target
	return Vector2i(
		clampi(target.x, MIN_WINDOW_SIZE.x, maxi(MIN_WINDOW_SIZE.x, usable.size.x)),
		clampi(target.y, MIN_WINDOW_SIZE.y, maxi(MIN_WINDOW_SIZE.y, usable.size.y))
	)


func _centered_position(size: Vector2i, screen: int) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(screen)
	return usable.position + (usable.size - size) / 2


func _restore_windowed_size() -> void:
	var window := get_window()
	if window_size == Vector2i.ZERO:
		window_size = _default_size()
	window.size = _fit_to_screen(window_size)
	window.position = _centered_position(window.size, window.current_screen)


func _capture_windowed_size() -> void:
	var mode: int = DisplayServer.window_get_mode()
	if (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	):
		return
	window_size = get_window().size
