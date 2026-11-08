extends Node

const TOGGLE_KEY := KEY_F3
const SKIP_PUZZLE_KEY := KEY_G
const WHEEL_ZOOM_STEP := 1.12
const OVERLAY_SCRIPT := preload("res://scripts/debug_overlay.gd")

var enabled := false

var _overlay: Node2D
var _panel: CanvasLayer
var _label: Label
var _refresh_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == TOGGLE_KEY or key.physical_keycode == TOGGLE_KEY:
				toggle()
				get_viewport().set_input_as_handled()
			elif enabled and (key.keycode == SKIP_PUZZLE_KEY or key.physical_keycode == SKIP_PUZZLE_KEY):
				if _skip_open_puzzle():
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and enabled:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed or _is_layout_mode():
			return
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _adjust_zoom(WHEEL_ZOOM_STEP):
				get_viewport().set_input_as_handled()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _adjust_zoom(1.0 / WHEEL_ZOOM_STEP):
				get_viewport().set_input_as_handled()


func _is_layout_mode() -> bool:
	return LayoutTool.active


func _adjust_zoom(factor: float) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("adjust_debug_zoom"):
		return false
	camera.call("adjust_debug_zoom", factor)
	_update_label()
	return true


func _reset_debug_zoom() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("reset_debug_zoom"):
		camera.call("reset_debug_zoom")


func _skip_open_puzzle() -> bool:
	for node in get_tree().get_nodes_in_group("puzzle_ui"):
		if node.has_method("is_open") and node.is_open() and node.has_method("debug_solve"):
			node.debug_solve()
			return true
	return false


func toggle() -> void:
	set_enabled(not enabled)


func set_enabled(value: bool) -> void:
	enabled = value
	_panel.visible = enabled
	if not enabled:
		_reset_debug_zoom()
		_remove_overlay()
		return
	_ensure_overlay()
	_update_label()


func _process(delta: float) -> void:
	if not enabled:
		return
	_ensure_overlay()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.15
		_update_label()


func _ensure_overlay() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == scene:
		return
	_remove_overlay()
	_overlay = Node2D.new()
	_overlay.name = "DebugCollisionOverlay"
	_overlay.set_script(OVERLAY_SCRIPT)
	scene.add_child(_overlay)


func _remove_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _build_panel() -> void:
	_panel = CanvasLayer.new()
	_panel.layer = 200
	add_child(_panel)

	var background := ColorRect.new()
	background.color = Color(0.02, 0.03, 0.04, 0.78)
	background.position = Vector2(1360, 16)
	background.size = Vector2(540, 224)
	_panel.add_child(background)

	_label = Label.new()
	_label.position = Vector2(1378, 28)
	_label.size = Vector2(510, 200)
	_label.add_theme_font_size_override("font_size", 17)
	_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
	_panel.add_child(_label)

	_panel.visible = false


func _update_label() -> void:
	var shapes := get_tree().root.find_children("*", "CollisionShape2D", true, false)
	var polygons := get_tree().root.find_children("*", "CollisionPolygon2D", true, false)
	var fps := Engine.get_frames_per_second()
	var text := "DEV MODE  [F3]\nFPS: %d\nCollision shapes: %d\nG: skip open puzzle\nWheel: zoom view" % [fps, shapes.size() + polygons.size()]

	var camera := get_viewport().get_camera_2d()
	if camera:
		text += "\nZoom: %.2f" % camera.zoom.x

	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		text += "\nPlayer: %.0f, %.0f" % [player.global_position.x, player.global_position.y]
		text += "\nSpeed: %.0f" % player.velocity.length()

	var arm := get_tree().get_first_node_in_group("mech_arm")
	if arm and arm.has_method("get_state_label"):
		text += "\nArm: %s  HP %d/%d" % [arm.call("get_state_label"), arm.get("hp"), arm.get("max_hp")]

	_label.text = text
