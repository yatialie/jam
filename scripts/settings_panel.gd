extends Control

## Settings modal: frosted backdrop + glass panel with display / audio / control options.

signal close_requested

@onready var _blur: ColorRect = $Blur
@onready var _panel: JamGlassPanel = $Center/Panel
@onready var _close_button: Button = $Center/Panel/Margin/Content/Header/CloseButton
@onready var _toggle_fullscreen: JamToggle = $Center/Panel/Margin/Content/ToggleFullscreen
@onready var _toggle_vsync: JamToggle = $Center/Panel/Margin/Content/ToggleVsync
@onready var _slider_volume: JamSlider = $Center/Panel/Margin/Content/SliderVolume
@onready var _slider_sensitivity: JamSlider = $Center/Panel/Margin/Content/SliderSensitivity

var _closing: bool = false
var _opened_at: int = 0


func _ready() -> void:
	visible = false
	_closing = false

	_close_button.pressed.connect(close)
	_blur.gui_input.connect(_on_blur_input)

	_toggle_fullscreen.button_pressed = UserSettings.fullscreen
	_toggle_vsync.button_pressed = UserSettings.vsync
	_slider_volume.set_value(UserSettings.master_volume * 100.0, true)
	_slider_sensitivity.set_value(UserSettings.mouse_sensitivity, true)

	_toggle_fullscreen.toggled.connect(_on_fullscreen_toggled)
	_toggle_vsync.toggled.connect(_on_vsync_toggled)
	_slider_volume.value_changed.connect(_on_volume_changed)
	_slider_sensitivity.value_changed.connect(_on_sensitivity_changed)
	UserSettings.display_changed.connect(_sync_display_toggles)


func _sync_display_toggles() -> void:
	_toggle_fullscreen.set_pressed_no_signal(UserSettings.fullscreen)
	_toggle_vsync.set_pressed_no_signal(UserSettings.vsync)


func open() -> void:
	if visible:
		return
	_sync_display_toggles()
	visible = true
	_closing = false
	_opened_at = Time.get_ticks_msec()
	modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.965, 0.965)
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", 0.0)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.20)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 0.0, 1.0, 0.26)

	_close_button.grab_focus()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	UserSettings.save_settings()

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.16)
	tween.tween_property(_panel, "scale", Vector2(0.975, 0.975), 0.18)
	if _blur.material is ShaderMaterial:
		tween.tween_method(_set_blur_fade, 1.0, 0.0, 0.16)
	tween.finished.connect(_finish_close)


func _finish_close() -> void:
	visible = false
	_closing = false
	close_requested.emit()


func _set_blur_fade(value: float) -> void:
	if _blur.material is ShaderMaterial:
		_blur.material.set_shader_parameter("fade", value)


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _on_blur_input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _opened_at < 320:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _on_fullscreen_toggled(pressed: bool) -> void:
	UserSettings.fullscreen = pressed
	UserSettings.apply_video()


func _on_vsync_toggled(pressed: bool) -> void:
	UserSettings.vsync = pressed
	UserSettings.apply_video()


func _on_volume_changed(value: float) -> void:
	UserSettings.master_volume = value / 100.0
	UserSettings.apply_audio()


func _on_sensitivity_changed(value: float) -> void:
	UserSettings.mouse_sensitivity = value
