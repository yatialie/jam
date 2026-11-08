extends CanvasLayer

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	_fade = ColorRect.new()
	_fade.color = Color(0.012, 0.017, 0.026)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_fade.visible = false
	add_child(_fade)


func change_scene(path: String) -> void:
	if _busy or path.is_empty():
		return
	_busy = true

	_fade.visible = true
	_fade.modulate.a = 0.0
	var out := create_tween()
	out.tween_property(_fade, "modulate:a", 1.0, 0.3)
	await out.finished

	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame

	var back := create_tween()
	back.tween_property(_fade, "modulate:a", 0.0, 0.45)
	await back.finished
	_fade.visible = false
	_busy = false
