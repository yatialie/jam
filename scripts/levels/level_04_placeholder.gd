extends "res://scripts/levels/level_controller.gd"

## 第四关货运舱导演：先查看主控大屏上的字，再前往第五关。
## 出口在读到屏幕内容前保持锁定，任务进度由 MissionLog 跟踪。

@onready var main_screen: Node = $Projection/World/MainScreen
@onready var exit_trigger: Node = $Projection/World/ExitTrigger


func _ready() -> void:
	super._ready()
	MissionLog.start_chapter("sector04")
	if main_screen.has_signal("interacted"):
		main_screen.connect("interacted", _on_screen_read)
	if exit_trigger.has_signal("passed_through"):
		exit_trigger.connect("passed_through", _on_exit_passed)
	_set_exit_open(MissionLog.is_done("s04_screen"))


func _on_screen_read() -> void:
	MissionLog.complete_task("s04_screen")
	_set_exit_open(true)


func _on_exit_passed() -> void:
	MissionLog.complete_task("s04_exit")
	# 导出版本以前四关为完整流程，通关第四关后返回主菜单；编辑器内保留 4→5 的调试链路。
	if not OS.has_feature("editor") and exit_trigger != null:
		exit_trigger.set("exit_scene_path", "res://scenes/start_screen.tscn")


func _set_exit_open(value: bool) -> void:
	if exit_trigger != null and exit_trigger.has_method("set_active"):
		exit_trigger.call("set_active", value)
