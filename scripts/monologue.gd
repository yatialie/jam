extends Node

## 内心旁白全局入口：
##   Monologue.say("……又是这个梦。")
##   Monologue.play(["第一句", "第二句"], {"speaker": "RIG-7"})
## 面板在任意场景自动可用，无需往关卡里挂节点。

signal line_started(index: int, text: String)
signal finished()

const OVERLAY_SCENE: PackedScene = preload("res://scenes/monologue_overlay.tscn")

var _overlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = OVERLAY_SCENE.instantiate()
	add_child(_overlay)
	_overlay.line_started.connect(_on_line_started)
	_overlay.finished.connect(_on_finished)


func play(lines: Array, options: Dictionary = {}) -> void:
	if _overlay != null:
		_overlay.play(lines, options)


func say(text: String, options: Dictionary = {}) -> void:
	play([text], options)


func advance() -> void:
	if _overlay != null:
		_overlay.advance()


func hide_now() -> void:
	if _overlay != null:
		_overlay.hide_now()


func is_playing() -> bool:
	return _overlay != null and _overlay.is_playing()


func is_typing() -> bool:
	return _overlay != null and _overlay.is_typing()


func _on_line_started(index: int, text: String) -> void:
	line_started.emit(index, text)


func _on_finished() -> void:
	finished.emit()
