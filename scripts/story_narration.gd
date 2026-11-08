extends Node

## 上方旁白全局入口：
##   StoryNarration.play(["第一句", "第二句"], {"delay": 0.5})
## 播放期间硬控玩家，面板在任意场景自动可用。

signal line_started(index: int, text: String)
signal finished()

const OVERLAY_SCENE: PackedScene = preload("res://scenes/story_narration_overlay.tscn")

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
