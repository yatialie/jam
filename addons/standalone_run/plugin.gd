@tool
extends EditorPlugin

## Adds a toolbar button that launches the project in a standalone window,
## so F5 can stay in embedded mode for debugging while fullscreen play stays available.

const BUTTON_TEXT := "独立运行"
const BUTTON_TOOLTIP := "以独立窗口启动游戏（F11 / Alt+Enter 全屏）"

var _button: Button


func _enter_tree() -> void:
	_button = Button.new()
	_button.text = BUTTON_TEXT
	_button.tooltip_text = BUTTON_TOOLTIP
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_launch_standalone)
	add_control_to_container(CONTAINER_TOOLBAR, _button)


func _exit_tree() -> void:
	if is_instance_valid(_button):
		remove_control_from_container(CONTAINER_TOOLBAR, _button)
		_button.queue_free()
	_button = null


func _launch_standalone() -> void:
	var executable := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var pid := OS.create_process(executable, PackedStringArray(["--path", project_dir]))
	if pid <= 0:
		push_error("独立运行失败：无法启动 %s" % executable)
