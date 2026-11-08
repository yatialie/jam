extends Node

## 场景摆放工具：F4 进入关卡布局模式，可视化创建/调整碰撞体与触发区。
## 数据写入 res://level_layouts/<场景名>.json，由 LayoutStore 在运行时自动实例化。

const THEME := preload("res://ui/theme/jam_theme.tres")
const CANVAS_SCRIPT := preload("res://scripts/tools/layout_canvas.gd")

const SNAP := 16.0
const DEFAULT_COLLIDER_SIZE := Vector2(384, 60)
const DEFAULT_TRIGGER_SIZE := Vector2(240, 160)
const HANDLE_SIZE := 9.0
const HANDLE_HIT := 11.0
const ROTATE_HANDLE_DIST := 30.0
const ROTATE_HANDLE_RADIUS := 6.0
const ROTATE_SNAP := 15.0
const MAX_UNDO := 64
const MIN_SIZE := 8.0
const ROOM_MIN_SIZE := Vector2(640, 480)
const DOOR_WIDTH := 32.0
const DOOR_TILT := 0.72
const DOOR_LOCAL_HEIGHT := 280.0 / DOOR_TILT
const DOOR_MIN_SCALE := 0.25
const DOOR_MAX_SCALE := 4.0
const DOOR_WIDTH_SNAP := 8.0
const DOOR_HEIGHT_SNAP := 16.0
const DOOR_TRIGGER_MIN := 32.0
const DOOR_TRIGGER_SNAP := 8.0
const COL_DOOR_TRIGGER := Color(0.72, 0.55, 1.0)

const COL_COLLIDER := Color(1.0, 0.66, 0.24)
const COL_TRIGGER := Color(0.36, 1.0, 0.55)
const COL_SCENE := Color(0.98, 0.86, 0.35)
const COL_SELECT := Color(1, 1, 1, 0.95)

var active := false
var items: Array[Dictionary] = []
var selected_id := ""
var selected_ids: Array[String] = []
var _drag_group_origins: Dictionary = {}
var _marquee_start := Vector2.ZERO
var _marquee_current := Vector2.ZERO

var _scene: Node
var _world: Node2D
var _edit_camera: Camera2D
var _spawn_pos := Vector2.ZERO
var _spawn_origin := Vector2.ZERO
var _room_rect := Rect2(0, 0, 4000, 2400)
var _room_origin_rect := Rect2()
var _room_handle := -1
var _doors: Dictionary = {}
var _door_positions: Dictionary = {}
var _door_scales: Dictionary = {}
var _door_rotations: Dictionary = {}
var _selected_door := ""
var _door_drag_role := ""
var _door_drag_origin := Vector2.ZERO
var _door_resize_handle := -1
var _door_origin_scale := Vector2.ONE
var _door_triggers: Dictionary = {}
var _door_trigger_handle := -1
var _door_trigger_origin := Vector2.ZERO
var _door_trigger_origin_size := Vector2.ZERO
var _door_trigger_start_local := Vector2.ZERO
var _exits: Dictionary = {}
var _exit_rects: Dictionary = {}
var _selected_exit := ""
var _exit_drag_role := ""
var _exit_drag_origin := Vector2.ZERO
var _exit_resize_handle := -1
var _exit_origin_size := Vector2.ZERO
var _exit_origin_rotation := 0.0
var _prev_camera: Camera2D
var _hud_layers := {}
var _prev_paused := false

var _canvas_layer: CanvasLayer
var _root: Control
var _canvas: Control
var _props: Control
var _status: Label
var _toast: Label
var _help: Label

var _prop_title: Label
var _name_edit: LineEdit
var _pos_label: Label
var _size_label: Label
var _map_width_row: Control
var _map_width_spin: SpinBox
var _map_height_row: Control
var _map_height_spin: SpinBox
var _map_layer_row: Control
var _map_layer_option: OptionButton
var _rotation_row: Control
var _rotation_spin: SpinBox
var _radius_x_row: Control
var _radius_x_spin: SpinBox
var _radius_y_row: Control
var _radius_y_spin: SpinBox
var _thickness_row: Control
var _thickness_spin: SpinBox
var _start_row: Control
var _start_spin: SpinBox
var _end_row: Control
var _end_spin: SpinBox
var _arc_rotation_row: Control
var _arc_rotation_spin: SpinBox
var _clockwise_row: Control
var _clockwise_check: CheckBox
var _segments_row: Control
var _segments_spin: SpinBox
var _layer_row: Control
var _layer_option: OptionButton
var _mask_row: Control
var _mask_option: OptionButton
var _group_row: Control
var _group_edit: LineEdit
var _purpose_row: Control
var _purpose_edit: LineEdit
var _scene_enabled_row: Control
var _scene_enabled_check: CheckBox
var _snap_btn: Button
var _mode_buttons := {}
var _mode_group := ButtonGroup.new()
var _mode := "select"
var _syncing := false
var _dirty := false
var _snap_enabled := true

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _pending_snapshot := {}
var _change_started := false

var _drag := ""
var _drag_handle := -1
var _bezier_point_index := -1
var _polygon_point_index := -1
var _drag_start_world := Vector2.ZERO
var _drag_origin_pos := Vector2.ZERO
var _drag_origin_rect := Rect2()
var _drag_rotation := 0.0
var _rotate_start_world := Vector2.ZERO
var _rotate_origin_angle := 0.0
var _create_type := ""
var _create_anchor := Vector2.ZERO
var _create_current := Vector2.ZERO
var _creating := false
var _panning := false

var _toast_time := 0.0
var _font: Font = ThemeDB.fallback_font
var _map_textures: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = THEME.default_font if THEME.default_font else ThemeDB.fallback_font
	_build_ui()
	set_process(true)


func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time = maxf(_toast_time - delta, 0.0)
		_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	if active:
		_canvas.queue_redraw()
		_update_status()


func _input(event: InputEvent) -> void:
	if get_tree().get_first_node_in_group("modal") != null:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_F4 or key.physical_keycode == KEY_F4:
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if get_tree().get_first_node_in_group("modal") != null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventKey:
		_handle_key(event)


func toggle() -> void:
	if active:
		exit_tool()
	else:
		enter_tool()


func enter_tool() -> void:
	if active:
		return
	if get_tree().paused:
		push_warning("[LayoutTool] 请先恢复游戏再进入布局模式")
		return
	if get_tree().get_first_node_in_group("modal") != null:
		push_warning("[LayoutTool] 请先关闭当前界面")
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.scene_file_path.is_empty():
		push_warning("[LayoutTool] 当前场景尚未保存为 .tscn，无法记录布局")
		return
	var world := LayoutStore.find_world(scene)
	if world == null:
		push_warning("[LayoutTool] 当前场景找不到 World 节点")
		return

	_scene = scene
	_world = world
	items = LayoutStore.get_items_for(scene.scene_file_path)
	var scene_collider_count := _collect_scene_colliders()
	_spawn_pos = _resolve_spawn_pos()
	_room_rect = _resolve_room_rect()
	_collect_doors()
	_collect_exits()
	_set_whitebox_spawn_marker_visible(false)
	_set_whitebox_room_outline(false)
	selected_id = ""
	selected_ids.clear()
	_selected_door = ""
	_selected_exit = ""
	_undo.clear()
	_redo.clear()
	_dirty = false
	_mode = "select"
	_snap_enabled = true
	_drag = ""
	_creating = false

	LayoutStore.set_preview_hidden(true)

	_prev_camera = get_viewport().get_camera_2d()
	_edit_camera = Camera2D.new()
	_edit_camera.name = "LayoutEditCamera"
	_edit_camera.process_mode = Node.PROCESS_MODE_ALWAYS
	var zoom_level := 1.2
	if _prev_camera:
		_edit_camera.position = _prev_camera.get_screen_center_position()
		zoom_level = _prev_camera.zoom.x
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		_edit_camera.position = player.global_position if player else world.global_position
	_edit_camera.zoom = Vector2(zoom_level, zoom_level)
	_scene.add_child(_edit_camera)
	_edit_camera.make_current()
	_edit_camera.force_update_scroll()

	_prev_paused = get_tree().paused
	get_tree().paused = true

	_hud_layers.clear()
	for node in _scene.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		if layer:
			_hud_layers[layer] = layer.visible
			layer.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	active = true
	_root.visible = true
	_snap_btn.set_pressed_no_signal(true)
	_set_mode("select")
	_sync_panel()
	_update_status()
	_canvas.queue_redraw()
	if scene_collider_count > 0:
		_toast_msg("已纳入 %d 个场景碰撞体（黄色虚线，可直接编辑多边形）" % scene_collider_count)


func exit_tool() -> void:
	if not active:
		return
	if _dirty and _save(false).is_empty():
		_toast_msg("保存失败，请检查文件权限")
		return
	active = false
	_root.visible = false

	if _edit_camera and is_instance_valid(_edit_camera):
		if _edit_camera.get_parent():
			_edit_camera.get_parent().remove_child(_edit_camera)
		_edit_camera.queue_free()
	_edit_camera = null
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.make_current()
	_prev_camera = null

	for key in _hud_layers.keys():
		var layer := key as CanvasLayer
		if is_instance_valid(layer):
			layer.visible = bool(_hud_layers[key])
	_hud_layers.clear()

	LayoutStore.apply_items(items, _spawn_pos, _room_rect, _door_data(), _exit_data())
	LayoutStore.set_preview_hidden(false)
	get_tree().paused = false

	items = []
	selected_id = ""
	selected_ids.clear()
	_drag = ""
	_creating = false
	_dirty = false


func save_and_exit() -> bool:
	if not active:
		return true
	if _dirty and _save(false).is_empty():
		_toast_msg("保存失败，无法切换关卡")
		return false
	exit_tool()
	return true


func draw_editor_canvas(c: Control) -> void:
	if not active or _world == null:
		return
	var view := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(view, Color(0.01, 0.02, 0.03, 0.16))
	var map_item := _map_item()
	for map in _map_items():
		_draw_map_preview(c, map)
	_draw_grid(c, view)
	_draw_room_overlay(c)
	for item in items:
		if str(item.get("type", "")) == "map":
			continue
		var id := str(item.get("id", ""))
		_draw_item(c, item, selected_ids.has(id), id == selected_id)
	if _mode == "map" and not map_item.is_empty():
		var map_points := _rect_screen_points(map_item.get("pos", Vector2.ZERO), map_item.get("size", Vector2.ZERO), float(map_item.get("rotation", 0.0)))
		_close_polyline(c, map_points, Color(0.55, 0.95, 1.0, 0.95), 2.0)
	if _creating:
		var rect := _rect_from_points(_create_anchor, _create_current)
		var color := COL_COLLIDER if _create_type == "collider" else COL_TRIGGER
		var pts := _rect_screen_points(rect.get_center(), rect.size)
		c.draw_colored_polygon(pts, Color(color, 0.18))
		_close_polyline(c, pts, Color(color, 0.95), 1.5)
	if _drag == "marquee":
		var marquee := _rect_from_points(_marquee_start, _marquee_current)
		c.draw_rect(marquee, Color(0.35, 0.85, 1.0, 0.08))
		c.draw_rect(marquee, Color(0.35, 0.85, 1.0, 0.85), false, 1.5)
	if selected_ids.size() > 1:
		var bounds := _selection_bounds()
		var a := _world_to_screen(bounds.position)
		var b := _world_to_screen(bounds.end)
		c.draw_rect(Rect2(a, b - a).abs(), Color(0.55, 0.95, 1.0, 0.55), false, 1.0)
	elif selected_ids.size() == 1:
		var selected := _selected_item()
		if not selected.is_empty():
			_draw_handles(c, selected)
	_draw_room_handles(c)
	_draw_doors(c)
	_draw_exits(c)

	var spawn_screen := _world_to_screen(_spawn_pos)
	var spawn_color := Color(0.3, 1.0, 0.6, 1.0)
	c.draw_circle(spawn_screen, 15.0, Color(spawn_color, 0.12))
	c.draw_arc(spawn_screen, 15.0, 0.0, TAU, 32, spawn_color, 2.4 if _drag == "spawn" else 1.8, true)
	c.draw_line(spawn_screen - Vector2(22, 0), spawn_screen + Vector2(22, 0), Color(spawn_color, 0.55), 1.0)
	c.draw_line(spawn_screen - Vector2(0, 22), spawn_screen + Vector2(0, 22), Color(spawn_color, 0.55), 1.0)
	c.draw_circle(spawn_screen, 3.0, spawn_color)
	c.draw_string(_font, spawn_screen + Vector2(20, -10), "SPAWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(spawn_color, 0.95))


func _room_screen_rect() -> Rect2:
	var a := _world_to_screen(_room_rect.position)
	var b := _world_to_screen(_room_rect.end)
	return Rect2(a, b - a).abs()


func _room_handle_points() -> Array[Vector2]:
	var rect := _room_screen_rect()
	var center := rect.get_center()
	return [
		rect.position,
		Vector2(center.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x, center.y),
		rect.end,
		Vector2(center.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.position.x, center.y),
	]


func _room_handle_at(screen: Vector2) -> int:
	var points := _room_handle_points()
	for i in points.size():
		if screen.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _draw_room_overlay(c: Control) -> void:
	var rect := _room_screen_rect()
	var fill_alpha := 0.10 if _mode == "room" else 0.03
	c.draw_rect(rect, Color(0.25, 0.7, 1.0, fill_alpha))
	c.draw_rect(rect, Color(0.35, 0.8, 1.0, 0.8), false, 2.0)
	if _mode == "room":
		var label := "ROOM  %d × %d   @ %d, %d" % [roundi(_room_rect.size.x), roundi(_room_rect.size.y), roundi(_room_rect.position.x), roundi(_room_rect.position.y)]
		c.draw_string(_font, rect.position + Vector2(10, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.9, 1.0, 0.95))


func _draw_room_handles(c: Control) -> void:
	if _mode != "room":
		return
	var points := _room_handle_points()
	for i in points.size():
		var point := points[i]
		var active := _drag == "room_resize" and _room_handle == i
		var fill := Color(0.12, 0.3, 0.4, 0.95)
		var border := Color(0.55, 0.9, 1.0, 0.95)
		if active:
			fill = Color(0.4, 0.85, 1.0, 0.95)
		var handle_rect := Rect2(point - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(handle_rect, fill)
		c.draw_rect(handle_rect, border, false, 1.0)


func _door_screen_point(role: String, local: Vector2) -> Vector2:
	var node = _doors.get(role)
	if node is Node2D and _world != null:
		return _world_to_screen(_world.to_local((node as Node2D).to_global(local)))
	var pos: Vector2 = _door_positions.get(role, Vector2.ZERO)
	return _world_to_screen(pos + local)


func _door_screen_corners(role: String) -> Array[Vector2]:
	var half := DOOR_WIDTH * 0.5
	return [
		_door_screen_point(role, Vector2(-half, -DOOR_LOCAL_HEIGHT)),
		_door_screen_point(role, Vector2(half, -DOOR_LOCAL_HEIGHT)),
		_door_screen_point(role, Vector2(half, 0)),
		_door_screen_point(role, Vector2(-half, 0)),
	]


func _door_screen_rect(role: String) -> Rect2:
	var corners := _door_screen_corners(role)
	var rect := Rect2(corners[0], Vector2.ZERO)
	for i in range(1, corners.size()):
		rect = rect.expand(corners[i])
	return rect.grow(6.0)


func _door_handle_points(role: String) -> Array[Vector2]:
	return [
		_door_screen_point(role, Vector2(-DOOR_WIDTH * 0.5, -DOOR_LOCAL_HEIGHT * 0.5)),
		_door_screen_point(role, Vector2(DOOR_WIDTH * 0.5, -DOOR_LOCAL_HEIGHT * 0.5)),
		_door_screen_point(role, Vector2(0, -DOOR_LOCAL_HEIGHT)),
	]


func _door_rotate_point(role: String) -> Vector2:
	var top := _door_screen_point(role, Vector2(0, -DOOR_LOCAL_HEIGHT))
	var center := _door_screen_point(role, Vector2(0, -DOOR_LOCAL_HEIGHT * 0.5))
	var dir := (top - center).normalized()
	if dir.length_squared() < 0.0001:
		dir = Vector2(0, -1)
	return top + dir * ROTATE_HANDLE_DIST


func _door_handle_at(screen: Vector2) -> int:
	if _selected_door.is_empty():
		return -1
	var points := _door_handle_points(_selected_door)
	for i in points.size():
		if screen.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _door_rotate_at(screen: Vector2) -> bool:
	if _selected_door.is_empty():
		return false
	return screen.distance_to(_door_rotate_point(_selected_door)) <= HANDLE_HIT


func _door_at(screen: Vector2) -> String:
	for role in _door_positions.keys():
		if _door_screen_rect(role).has_point(screen):
			return role
	return ""


func _draw_doors(c: Control) -> void:
	for role in _door_positions.keys():
		var color := Color(0.35, 1.0, 0.75) if role == "entrance" else Color(1.0, 0.75, 0.3)
		var corners := _door_screen_corners(role)
		var pts := PackedVector2Array(corners)
		c.draw_colored_polygon(pts, Color(color, 0.06))
		_close_polyline(c, pts, Color(color, 0.45), 1.0)
		var base := _world_to_screen(_door_positions[role])
		c.draw_circle(base, 4.0, color)
		var label := "IN" if role == "entrance" else "OUT"
		c.draw_string(_font, base + Vector2(10, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		if _mode == "select" and role == _selected_door:
			_draw_door_trigger(c, role)
			_draw_door_handles(c, role, color)


func _draw_door_handles(c: Control, role: String, color: Color) -> void:
	var points := _door_handle_points(role)
	for i in points.size():
		var active := _drag == "door_resize" and _door_resize_handle == i
		var fill := Color(0.15, 0.35, 0.4, 0.95)
		var border := Color(color.r, color.g, color.b, 0.95)
		if active:
			fill = Color(0.55, 0.95, 1.0, 0.95)
		var handle_rect := Rect2(points[i] - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(handle_rect, fill)
		c.draw_rect(handle_rect, border, false, 1.0)
	var top: Vector2 = points[2]
	var rotate_point := _door_rotate_point(role)
	c.draw_line(top, rotate_point, Color(color.r, color.g, color.b, 0.7), 1.0)
	c.draw_circle(rotate_point, ROTATE_HANDLE_RADIUS, Color(0.15, 0.35, 0.4, 0.95))
	c.draw_arc(rotate_point, ROTATE_HANDLE_RADIUS, 0.0, TAU, 20, color, 1.4, true)


func _door_trigger(role: String) -> Dictionary:
	var data = _door_triggers.get(role)
	if data is Dictionary:
		return data
	return {"pos": Vector2(150.0, -140.0), "size": Vector2(200.0, 280.0)}


func _door_trigger_corners(role: String) -> Array[Vector2]:
	var data := _door_trigger(role)
	var pos: Vector2 = data.get("pos", Vector2(150.0, -140.0))
	var raw_size: Vector2 = data.get("size", Vector2(200.0, 280.0))
	var half: Vector2 = raw_size * 0.5
	return [
		_door_screen_point(role, pos + Vector2(-half.x, -half.y)),
		_door_screen_point(role, pos + Vector2(half.x, -half.y)),
		_door_screen_point(role, pos + Vector2(half.x, half.y)),
		_door_screen_point(role, pos + Vector2(-half.x, half.y)),
	]


func _door_trigger_handle_points(role: String) -> Array[Vector2]:
	var data := _door_trigger(role)
	var pos: Vector2 = data.get("pos", Vector2(150.0, -140.0))
	var raw_size: Vector2 = data.get("size", Vector2(200.0, 280.0))
	var half: Vector2 = raw_size * 0.5
	return [
		_door_screen_point(role, pos + Vector2(-half.x, -half.y)),
		_door_screen_point(role, pos + Vector2(0, -half.y)),
		_door_screen_point(role, pos + Vector2(half.x, -half.y)),
		_door_screen_point(role, pos + Vector2(half.x, 0)),
		_door_screen_point(role, pos + Vector2(half.x, half.y)),
		_door_screen_point(role, pos + Vector2(0, half.y)),
		_door_screen_point(role, pos + Vector2(-half.x, half.y)),
		_door_screen_point(role, pos + Vector2(-half.x, 0)),
	]


func _door_trigger_handle_at(screen: Vector2) -> int:
	if _selected_door.is_empty():
		return -1
	var points := _door_trigger_handle_points(_selected_door)
	for i in points.size():
		if screen.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _door_trigger_contains(role: String, screen: Vector2) -> bool:
	var corners := _door_trigger_corners(role)
	if corners.size() < 4:
		return false
	return Geometry2D.is_point_in_polygon(screen, PackedVector2Array(corners))


func _draw_door_trigger(c: Control, role: String) -> void:
	var corners := _door_trigger_corners(role)
	if corners.size() < 4:
		return
	c.draw_colored_polygon(PackedVector2Array(corners), Color(COL_DOOR_TRIGGER, 0.10))
	for i in 4:
		c.draw_line(corners[i], corners[(i + 1) % 4], Color(COL_DOOR_TRIGGER, 0.85), 1.4, true)

	var data := _door_trigger(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2.ZERO)
	var label_anchor := _door_screen_point(role, pos + Vector2(-size.x * 0.5, -size.y * 0.5))
	c.draw_string(_font, label_anchor + Vector2(4, -6), "EXIT ZONE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(COL_DOOR_TRIGGER, 0.95))

	var handles := _door_trigger_handle_points(role)
	for i in handles.size():
		var active := _drag == "door_trigger_resize" and _door_trigger_handle == i
		var fill := Color(0.22, 0.16, 0.34, 0.95)
		if active:
			fill = Color(0.85, 0.72, 1.0, 0.95)
		var handle_rect := Rect2(handles[i] - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(handle_rect, fill)
		c.draw_rect(handle_rect, Color(COL_DOOR_TRIGGER, 0.95), false, 1.0)


func _apply_door_trigger(role: String) -> void:
	var node = _doors.get(role)
	if not node is Node2D:
		return
	var data := _door_trigger(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2.ZERO)
	if node.has_method("apply_exit_area"):
		node.apply_exit_area(pos, size)


func _move_door_trigger_to(world: Vector2) -> void:
	if _door_drag_role.is_empty():
		return
	var node = _doors.get(_door_drag_role)
	if not node is Node2D:
		return
	var door := node as Node2D
	var local := door.to_local(_world.to_global(world))
	var data := _door_trigger(_door_drag_role)
	var new_pos: Vector2 = _door_trigger_origin + (local - _door_trigger_start_local)
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		new_pos = Vector2(
			roundf(new_pos.x / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP,
			roundf(new_pos.y / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP
		)
	_begin_change()
	data["pos"] = new_pos
	_door_triggers[_door_drag_role] = data
	_apply_door_trigger(_door_drag_role)
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


func _resize_door_trigger_to(world: Vector2) -> void:
	if _door_drag_role.is_empty():
		return
	var node = _doors.get(_door_drag_role)
	if not node is Node2D:
		return
	var door := node as Node2D
	var local := door.to_local(_world.to_global(world))
	var rect := Rect2(_door_trigger_origin - _door_trigger_origin_size * 0.5, _door_trigger_origin_size)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	match _door_trigger_handle:
		0:
			x0 = local.x
			y0 = local.y
		1:
			y0 = local.y
		2:
			x1 = local.x
			y0 = local.y
		3:
			x1 = local.x
		4:
			x1 = local.x
			y1 = local.y
		5:
			y1 = local.y
		6:
			x0 = local.x
			y1 = local.y
		7:
			x0 = local.x
	if x0 > x1:
		var swap_x := x0
		x0 = x1
		x1 = swap_x
	if y0 > y1:
		var swap_y := y0
		y0 = y1
		y1 = swap_y
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		x0 = roundf(x0 / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP
		y0 = roundf(y0 / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP
		x1 = roundf(x1 / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP
		y1 = roundf(y1 / DOOR_TRIGGER_SNAP) * DOOR_TRIGGER_SNAP
	x1 = maxf(x1, x0 + DOOR_TRIGGER_MIN)
	y1 = maxf(y1, y0 + DOOR_TRIGGER_MIN)

	var data := _door_trigger(_door_drag_role)
	data["pos"] = Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)
	data["size"] = Vector2(x1 - x0, y1 - y0)
	_door_triggers[_door_drag_role] = data
	_begin_change()
	_apply_door_trigger(_door_drag_role)
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


# ---------------------------------------------------------------- 换场触发区

func _exit_rect(role: String) -> Dictionary:
	var data = _exit_rects.get(role)
	if data is Dictionary:
		return data
	return {"pos": Vector2.ZERO, "size": Vector2(200, 280), "rotation": 0.0}


func _exit_corners(role: String) -> Array[Vector2]:
	var data := _exit_rect(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(200, 280))
	var rad := deg_to_rad(float(data.get("rotation", 0.0)))
	var half := size * 0.5
	return [
		_world_to_screen(pos + Vector2(-half.x, -half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(half.x, -half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(half.x, half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(-half.x, half.y).rotated(rad)),
	]


func _exit_handle_points(role: String) -> Array[Vector2]:
	var data := _exit_rect(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(200, 280))
	var rad := deg_to_rad(float(data.get("rotation", 0.0)))
	var half := size * 0.5
	var offsets := [
		Vector2(-half.x, -half.y), Vector2(0, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, 0), Vector2(half.x, half.y), Vector2(0, half.y),
		Vector2(-half.x, half.y), Vector2(-half.x, 0),
	]
	var points: Array[Vector2] = []
	for offset in offsets:
		points.append(_world_to_screen(pos + offset.rotated(rad)))
	return points


func _exit_rotate_point(role: String) -> Vector2:
	var points := _exit_handle_points(role)
	var center := _world_to_screen(_exit_rect(role).get("pos", Vector2.ZERO))
	var direction := points[1] - center
	if direction.length() < 0.5:
		direction = Vector2.UP
	direction = direction.normalized()
	return points[1] + direction * ROTATE_HANDLE_DIST


func _exit_handle_at(screen: Vector2) -> int:
	if _selected_exit.is_empty():
		return -1
	var points := _exit_handle_points(_selected_exit)
	for i in points.size():
		if screen.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _exit_rotate_at(screen: Vector2) -> bool:
	if _selected_exit.is_empty():
		return false
	return screen.distance_to(_exit_rotate_point(_selected_exit)) <= HANDLE_HIT


func _exit_contains(role: String, screen: Vector2) -> bool:
	var data := _exit_rect(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(200, 280))
	var rad := deg_to_rad(float(data.get("rotation", 0.0)))
	var local := (_screen_to_world(screen) - pos).rotated(-rad)
	return Rect2(-size * 0.5, size).has_point(local)


func _exit_at(screen: Vector2) -> String:
	for role in _exit_rects.keys():
		if _exit_contains(role, screen):
			return role
	return ""


func _draw_exits(c: Control) -> void:
	for role in _exit_rects.keys():
		var color := Color(0.35, 1.0, 0.75) if role == "entrance" else Color(1.0, 0.66, 0.32)
		var corners := _exit_corners(role)
		var pts := PackedVector2Array(corners)
		c.draw_colored_polygon(pts, Color(color, 0.08))
		_close_polyline(c, pts, Color(color, 0.75), 1.4)
		var data := _exit_rect(role)
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		var size: Vector2 = data.get("size", Vector2.ZERO)
		var rad := deg_to_rad(float(data.get("rotation", 0.0)))
		var label_anchor := _world_to_screen(pos + Vector2(-size.x * 0.5, -size.y * 0.5).rotated(rad))
		var label := "IN ZONE" if role == "entrance" else "EXIT ZONE"
		c.draw_string(_font, label_anchor + Vector2(4, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.95))
		if _mode == "select" and role == _selected_exit:
			var handles := _exit_handle_points(role)
			for i in handles.size():
				var active := _drag == "exit_resize" and _exit_resize_handle == i
				var fill := Color(0.16, 0.24, 0.3, 0.95)
				if active:
					fill = Color(0.55, 0.95, 1.0, 0.95)
				var handle_rect := Rect2(handles[i] - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
				c.draw_rect(handle_rect, fill)
				c.draw_rect(handle_rect, Color(color, 0.95), false, 1.0)
			var top: Vector2 = handles[1]
			var rotate_point := _exit_rotate_point(role)
			c.draw_line(top, rotate_point, Color(color.r, color.g, color.b, 0.7), 1.0)
			c.draw_circle(rotate_point, ROTATE_HANDLE_RADIUS, Color(0.16, 0.24, 0.3, 0.95))
			c.draw_arc(rotate_point, ROTATE_HANDLE_RADIUS, 0.0, TAU, 20, color, 1.4, true)


func _apply_exit(role: String) -> void:
	var node = _exits.get(role)
	if not node is Node2D or not (node as Node2D).has_method("apply_trigger"):
		return
	var data := _exit_rect(role)
	var pos: Vector2 = data.get("pos", Vector2.ZERO)
	var size: Vector2 = data.get("size", Vector2(200, 280))
	(node as Node2D).call("apply_trigger", pos, size, float(data.get("rotation", 0.0)))


func _move_exit_to(world: Vector2) -> void:
	if _exit_drag_role.is_empty():
		return
	var new_pos := _exit_drag_origin + (world - _drag_start_world)
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		new_pos = Vector2(roundf(new_pos.x / SNAP) * SNAP, roundf(new_pos.y / SNAP) * SNAP)
	_begin_change()
	var data := _exit_rect(_exit_drag_role)
	data["pos"] = new_pos
	_exit_rects[_exit_drag_role] = data
	_apply_exit(_exit_drag_role)
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


func _resize_exit_to(world: Vector2) -> void:
	if _exit_drag_role.is_empty():
		return
	var data := _exit_rect(_exit_drag_role)
	var origin: Vector2 = data.get("pos", Vector2.ZERO)
	var rect := Rect2(-_exit_origin_size * 0.5, _exit_origin_size)
	var local := (world - origin).rotated(-deg_to_rad(_exit_origin_rotation))
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		local = Vector2(roundf(local.x / SNAP) * SNAP, roundf(local.y / SNAP) * SNAP)
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	match _exit_resize_handle:
		0:
			left = local.x
			top = local.y
		1:
			top = local.y
		2:
			right = local.x
			top = local.y
		3:
			right = local.x
		4:
			right = local.x
			bottom = local.y
		5:
			bottom = local.y
		6:
			left = local.x
			bottom = local.y
		7:
			left = local.x
	var resized := Rect2(
		Vector2(minf(left, right), minf(top, bottom)),
		Vector2(absf(right - left), absf(bottom - top))
	)
	resized.size = resized.size.max(Vector2(DOOR_TRIGGER_MIN, DOOR_TRIGGER_MIN))
	_begin_change()
	data["pos"] = origin + resized.get_center().rotated(deg_to_rad(_exit_origin_rotation))
	data["size"] = resized.size
	_exit_rects[_exit_drag_role] = data
	_apply_exit(_exit_drag_role)
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


func _rotate_exit_to(world: Vector2) -> void:
	if _exit_drag_role.is_empty():
		return
	var data := _exit_rect(_exit_drag_role)
	var origin: Vector2 = data.get("pos", Vector2.ZERO)
	var dir := world - origin
	if dir.length_squared() < 1.0:
		return
	var angle := rad_to_deg(dir.angle()) + 90.0
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		angle = roundf(angle / ROTATE_SNAP) * ROTATE_SNAP
	_begin_change()
	data["rotation"] = _normalize_angle(angle)
	_exit_rects[_exit_drag_role] = data
	_apply_exit(_exit_drag_role)
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "LayoutToolLayer"
	_canvas_layer.layer = 150
	add_child(_canvas_layer)

	_root = Control.new()
	_root.name = "LayoutToolRoot"
	_root.theme = THEME
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_canvas = CANVAS_SCRIPT.new()
	_canvas.name = "Canvas"
	_canvas.set("tool", self)
	_root.add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR

	_build_toolbar()
	_build_props()
	_build_overlay_text()
	_root.visible = false


func _build_toolbar() -> void:
	var panel := JamGlassPanel.new()
	panel.name = "Toolbar"
	panel.cut = 14
	panel.position = Vector2(24, 24)
	panel.size = Vector2(1440, 68)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	row.add_child(_make_mode_button("选择  [1]", "select", "ModeSelect"))
	row.add_child(_make_mode_button("碰撞体  [2]", "collider", "ModeCollider"))
	row.add_child(_make_mode_button("触发区  [3]", "trigger", "ModeTrigger"))
	row.add_child(_make_mode_button("范围  [4]", "room", "ModeRoom"))
	row.add_child(_make_mode_button("地图  [5]", "map", "ModeMap"))
	row.add_child(VSeparator.new())

	var add_collider := Button.new()
	add_collider.name = "AddCollider"
	add_collider.text = "+ 碰撞体"
	add_collider.pressed.connect(_create_collider_at_center)
	row.add_child(add_collider)

	var add_trigger := Button.new()
	add_trigger.name = "AddTrigger"
	add_trigger.text = "+ 触发区"
	add_trigger.pressed.connect(_create_trigger_at_center)
	row.add_child(add_trigger)

	var add_slope := Button.new()
	add_slope.name = "AddSlope"
	add_slope.text = "+ 斜面"
	add_slope.pressed.connect(_create_slope_at_center)
	row.add_child(add_slope)

	var add_arc := Button.new()
	add_arc.name = "AddArc"
	add_arc.text = "+ 曲面"
	add_arc.pressed.connect(_create_arc_at_center)
	row.add_child(add_arc)

	var add_bezier := Button.new()
	add_bezier.name = "AddBezier"
	add_bezier.text = "+ 贝塞尔"
	add_bezier.pressed.connect(_create_bezier_at_center)
	row.add_child(add_bezier)

	var add_polygon := Button.new()
	add_polygon.name = "AddPolygon"
	add_polygon.text = "+ 多边形"
	add_polygon.pressed.connect(_create_polygon_at_center)
	row.add_child(add_polygon)

	row.add_child(VSeparator.new())

	_snap_btn = Button.new()
	_snap_btn.name = "Snap"
	_snap_btn.text = "吸附 16"
	_snap_btn.toggle_mode = true
	_snap_btn.button_pressed = true
	_snap_btn.toggled.connect(_on_snap_toggled)
	row.add_child(_snap_btn)

	var save_btn := Button.new()
	save_btn.name = "Save"
	save_btn.text = "保存"
	save_btn.pressed.connect(_on_save_pressed)
	row.add_child(save_btn)


func _make_mode_button(text: String, mode: String, node_name: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.toggle_mode = true
	btn.button_group = _mode_group
	btn.pressed.connect(func() -> void: _set_mode(mode))
	_mode_buttons[mode] = btn
	return btn


func _build_props() -> void:
	var panel := JamGlassPanel.new()
	panel.name = "Properties"
	panel.cut = 14
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -340
	panel.offset_top = 24
	panel.offset_right = -24
	panel.offset_bottom = 760
	_root.add_child(panel)
	_props = panel

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_prop_title = Label.new()
	_prop_title.text = "碰撞体"
	_prop_title.add_theme_font_size_override("font_size", 20)
	_prop_title.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	box.add_child(_prop_title)

	box.add_child(_field_label("名称"))
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.text_changed.connect(_on_name_changed)
	box.add_child(_name_edit)

	_pos_label = _info_label()
	_size_label = _info_label()
	box.add_child(_pos_label)
	box.add_child(_size_label)

	_map_width_spin = SpinBox.new()
	_map_width_spin.name = "MapWidthSpin"
	_map_width_spin.min_value = 16
	_map_width_spin.max_value = 20000
	_map_width_spin.step = 1
	_map_width_spin.value_changed.connect(_on_map_size_changed)
	_map_width_row = _field_row("地图宽", _map_width_spin)
	box.add_child(_map_width_row)

	_map_height_spin = SpinBox.new()
	_map_height_spin.name = "MapHeightSpin"
	_map_height_spin.min_value = 16
	_map_height_spin.max_value = 20000
	_map_height_spin.step = 1
	_map_height_spin.value_changed.connect(_on_map_size_changed)
	_map_height_row = _field_row("地图高", _map_height_spin)
	box.add_child(_map_height_row)

	_map_layer_option = OptionButton.new()
	_map_layer_option.name = "MapLayerOption"
	_map_layer_option.item_selected.connect(_on_map_layer_selected)
	_map_layer_row = _field_row("地图层", _map_layer_option)
	box.add_child(_map_layer_row)

	_rotation_spin = SpinBox.new()
	_rotation_spin.name = "RotationSpin"
	_rotation_spin.min_value = -180
	_rotation_spin.max_value = 180
	_rotation_spin.step = 1
	_rotation_spin.suffix = "°"
	_rotation_spin.value_changed.connect(_on_rotation_changed)
	_rotation_row = _field_row("角度", _rotation_spin)
	box.add_child(_rotation_row)

	_radius_x_spin = SpinBox.new()
	_radius_x_spin.name = "RadiusXSpin"
	_radius_x_spin.min_value = 8
	_radius_x_spin.max_value = 8192
	_radius_x_spin.step = 1
	_radius_x_spin.value = 240
	_radius_x_spin.value_changed.connect(_on_arc_value_changed)
	_radius_x_row = _field_row("半径 X", _radius_x_spin)
	box.add_child(_radius_x_row)

	_radius_y_spin = SpinBox.new()
	_radius_y_spin.name = "RadiusYSpin"
	_radius_y_spin.min_value = 8
	_radius_y_spin.max_value = 8192
	_radius_y_spin.step = 1
	_radius_y_spin.value = 240
	_radius_y_spin.value_changed.connect(_on_arc_value_changed)
	_radius_y_row = _field_row("半径 Y", _radius_y_spin)
	box.add_child(_radius_y_row)

	_thickness_spin = SpinBox.new()
	_thickness_spin.name = "ThicknessSpin"
	_thickness_spin.min_value = 4
	_thickness_spin.max_value = 2048
	_thickness_spin.step = 1
	_thickness_spin.value = 48
	_thickness_spin.value_changed.connect(_on_arc_value_changed)
	_thickness_row = _field_row("厚度", _thickness_spin)
	box.add_child(_thickness_row)

	_start_spin = SpinBox.new()
	_start_spin.name = "StartSpin"
	_start_spin.min_value = 0
	_start_spin.max_value = 360
	_start_spin.step = 1
	_start_spin.suffix = "°"
	_start_spin.value_changed.connect(_on_arc_value_changed)
	_start_row = _field_row("起始角", _start_spin)
	box.add_child(_start_row)

	_end_spin = SpinBox.new()
	_end_spin.name = "EndSpin"
	_end_spin.min_value = 0
	_end_spin.max_value = 360
	_end_spin.step = 1
	_end_spin.suffix = "°"
	_end_spin.value = 90
	_end_spin.value_changed.connect(_on_arc_value_changed)
	_end_row = _field_row("结束角", _end_spin)
	box.add_child(_end_row)

	_arc_rotation_spin = SpinBox.new()
	_arc_rotation_spin.name = "ArcRotationSpin"
	_arc_rotation_spin.min_value = -180
	_arc_rotation_spin.max_value = 180
	_arc_rotation_spin.step = 1
	_arc_rotation_spin.suffix = "°"
	_arc_rotation_spin.value_changed.connect(_on_arc_value_changed)
	_arc_rotation_row = _field_row("整体旋转", _arc_rotation_spin)
	box.add_child(_arc_rotation_row)

	_clockwise_check = CheckBox.new()
	_clockwise_check.name = "ClockwiseCheck"
	_clockwise_check.text = "顺时针"
	_clockwise_check.button_pressed = true
	_clockwise_check.toggled.connect(func(_on: bool) -> void: _on_arc_value_changed(0.0))
	_clockwise_row = _field_row("方向", _clockwise_check)
	box.add_child(_clockwise_row)

	_segments_spin = SpinBox.new()
	_segments_spin.name = "SegmentsSpin"
	_segments_spin.min_value = 0
	_segments_spin.max_value = 128
	_segments_spin.step = 1
	_segments_spin.tooltip_text = "0 = 自动（曲面按角度 / 贝塞尔按长度）"
	_segments_spin.value_changed.connect(_on_arc_value_changed)
	_segments_row = _field_row("分段数", _segments_spin)
	box.add_child(_segments_row)

	_layer_option = OptionButton.new()
	_layer_option.name = "LayerOption"
	_layer_option.add_item("墙体 (1)")
	_layer_option.set_item_metadata(0, 1)
	_layer_option.add_item("受击 (2)")
	_layer_option.set_item_metadata(1, 2)
	_layer_option.add_item("玩家 (4)")
	_layer_option.set_item_metadata(2, 4)
	_layer_option.add_item("敌人 (8)")
	_layer_option.set_item_metadata(3, 8)
	_layer_option.item_selected.connect(_on_layer_selected)
	_layer_row = _field_row("碰撞层", _layer_option)
	box.add_child(_layer_row)

	_mask_option = OptionButton.new()
	_mask_option.name = "MaskOption"
	_mask_option.add_item("玩家 (4)")
	_mask_option.set_item_metadata(0, 4)
	_mask_option.add_item("敌人 (8)")
	_mask_option.set_item_metadata(1, 8)
	_mask_option.add_item("投射物 (3)")
	_mask_option.set_item_metadata(2, 3)
	_mask_option.add_item("全部 (-1)")
	_mask_option.set_item_metadata(3, -1)
	_mask_option.item_selected.connect(_on_mask_selected)
	_mask_row = _field_row("进入掩码", _mask_option)
	box.add_child(_mask_row)

	_group_edit = LineEdit.new()
	_group_edit.name = "GroupEdit"
	_group_edit.text_changed.connect(_on_group_changed)
	_group_row = _field_row("分组", _group_edit)
	box.add_child(_group_row)

	_purpose_edit = LineEdit.new()
	_purpose_edit.name = "PurposeEdit"
	_purpose_edit.text_changed.connect(_on_purpose_changed)
	_purpose_row = _field_row("用途标记", _purpose_edit)
	box.add_child(_purpose_row)

	_scene_enabled_check = CheckBox.new()
	_scene_enabled_check.name = "SceneEnabledCheck"
	_scene_enabled_check.text = "启用碰撞"
	_scene_enabled_check.button_pressed = true
	_scene_enabled_check.toggled.connect(_on_scene_enabled_toggled)
	_scene_enabled_row = _field_row("场景碰撞", _scene_enabled_check)
	box.add_child(_scene_enabled_row)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var dup_btn := Button.new()
	dup_btn.name = "Duplicate"
	dup_btn.text = "复制"
	dup_btn.pressed.connect(_duplicate_selected)
	actions.add_child(dup_btn)
	var del_btn := Button.new()
	del_btn.name = "Delete"
	del_btn.text = "删除"
	del_btn.pressed.connect(_delete_selected)
	actions.add_child(del_btn)
	box.add_child(actions)

	_props.visible = false


func _build_overlay_text() -> void:
	_status = Label.new()
	_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status.offset_left = -740
	_status.offset_right = -380
	_status.offset_top = 32
	_status.offset_bottom = 58
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0, 0.9))
	_root.add_child(_status)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -380
	_toast.offset_right = 380
	_toast.offset_top = 100
	_toast.offset_bottom = 130
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_toast.modulate.a = 0.0
	_root.add_child(_toast)

	_help = Label.new()
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 24
	_help.offset_top = -44
	_help.offset_right = 1600
	_help.offset_bottom = -18
	_help.text = "左键拖拽创建/移动 · 4 改关卡范围 · 5 选中地图背景改尺寸 · 拖 IN/OUT 门移动（选中后可改宽高/旋转） · 拖紫色 EXIT ZONE 框或手柄改换场触发区 · 贝塞尔拖 4 个控制点 · 多边形拖顶点，Ctrl+点边加点 / Ctrl+点顶点删点 · 黄色虚线为场景自带碰撞体，同样可拖顶点编辑 · 拖 SPAWN 改出生点 · Shift/Ctrl 加选 · 空白框选 · 中键/右键平移 · 滚轮缩放 · Delete 删除 · Ctrl+Z 撤销 · Ctrl+S 保存 · F7 关卡 · F4/Esc 退出"
	_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help.add_theme_font_size_override("font_size", 15)
	_help.add_theme_color_override("font_color", Color(0.55, 0.72, 0.78, 0.85))
	_root.add_child(_help)


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.6, 0.72, 0.78))
	return label


func _info_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.92))
	return label


func _field_row(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _field_label(text)
	label.custom_minimum_size = Vector2(74, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _set_mode(mode: String) -> void:
	_mode = mode
	if _mode_buttons.has(mode):
		var btn: Button = _mode_buttons[mode]
		btn.set_pressed_no_signal(true)
	if mode == "room":
		selected_ids.clear()
		selected_id = ""
		_sync_panel()
	if mode == "map":
		selected_ids.clear()
		selected_id = ""
		var map_item := _map_item()
		if not map_item.is_empty():
			_select_single(str(map_item.get("id", "")))
		elif active:
			_toast_msg("当前关卡没有地图背景条目")
		_sync_panel()
	if mode != "select":
		_selected_door = ""
	_drag = ""
	_creating = false
	_update_status()
	_canvas.queue_redraw()


func _on_snap_toggled(on: bool) -> void:
	_snap_enabled = on


func _on_save_pressed() -> void:
	_save(true)


# ---------------------------------------------------------------- 输入

func _handle_key(event: InputEventKey) -> void:
	if _text_focus():
		return
	var ctrl := event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_ESCAPE:
			exit_tool()
			get_viewport().set_input_as_handled()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_1:
			_set_mode("select")
		KEY_2:
			_set_mode("collider")
		KEY_3:
			_set_mode("trigger")
		KEY_4:
			_set_mode("room")
		KEY_5:
			_set_mode("map")
		KEY_S:
			if ctrl:
				_save(true)
		KEY_Z:
			if ctrl:
				if event.shift_pressed:
					_redo_last()
				else:
					_undo_last()
		KEY_Y:
			if ctrl:
				_redo_last()
		KEY_D:
			if ctrl:
				_duplicate_selected()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			_nudge(event.keycode)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var index := event.button_index
	if index == MOUSE_BUTTON_MIDDLE or index == MOUSE_BUTTON_RIGHT:
		_panning = event.pressed
		return
	if index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.12)
		return
	if index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 1.0 / 1.12)
		return
	if index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		_left_down(event.position)
	else:
		_left_up()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		var zoom_level := _edit_camera.zoom.x
		_edit_camera.position -= event.relative / zoom_level
		_edit_camera.force_update_scroll()
		return
	if _drag.is_empty():
		return
	var world := _screen_to_world(event.position)
	match _drag:
		"move":
			_move_to(world)
		"resize":
			_resize_to(world)
		"rotate":
			_rotate_to(world)
		"arc_start":
			_arc_drag_angle(world, true)
		"arc_end":
			_arc_drag_angle(world, false)
		"arc_x_radius":
			_arc_drag_radius_axis(world, "x")
		"arc_y_radius":
			_arc_drag_radius_axis(world, "y")
		"bezier_point":
			_bezier_drag_point(world)
		"polygon_point":
			_polygon_drag_point(world)
		"create":
			_create_current = _snap_point(world)
		"spawn":
			var new_pos := _spawn_origin + (world - _drag_start_world)
			if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
				new_pos = Vector2(roundf(new_pos.x / SNAP) * SNAP, roundf(new_pos.y / SNAP) * SNAP)
			_begin_change()
			_spawn_pos = new_pos
			_dirty = true
			_canvas.queue_redraw()
		"door":
			var door_pos := _door_drag_origin + (world - _drag_start_world)
			if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
				door_pos = Vector2(roundf(door_pos.x / SNAP) * SNAP, roundf(door_pos.y / SNAP) * SNAP)
			_begin_change()
			_door_positions[_door_drag_role] = door_pos
			if _doors.has(_door_drag_role):
				var door_node = _doors[_door_drag_role]
				if is_instance_valid(door_node):
					(door_node as Node2D).position = door_pos
			_dirty = true
			_canvas.queue_redraw()
		"door_resize":
			_resize_door_to(world)
		"door_rotate":
			_rotate_door_to(world)
		"door_trigger_move":
			_move_door_trigger_to(world)
		"door_trigger_resize":
			_resize_door_trigger_to(world)
		"exit_move":
			_move_exit_to(world)
		"exit_resize":
			_resize_exit_to(world)
		"exit_rotate":
			_rotate_exit_to(world)
		"room_move":
			var moved_rect := _room_origin_rect
			moved_rect.position = _room_origin_rect.position + (world - _drag_start_world)
			if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
				moved_rect.position = Vector2(roundf(moved_rect.position.x / SNAP) * SNAP, roundf(moved_rect.position.y / SNAP) * SNAP)
			_begin_change()
			_room_rect = moved_rect
			_dirty = true
			_update_status()
			_canvas.queue_redraw()
		"room_resize":
			var rect := _room_origin_rect
			var left := rect.position.x
			var top := rect.position.y
			var right := rect.end.x
			var bottom := rect.end.y
			match _room_handle:
				0:
					left = world.x
					top = world.y
				1:
					top = world.y
				2:
					right = world.x
					top = world.y
				3:
					right = world.x
				4:
					right = world.x
					bottom = world.y
				5:
					bottom = world.y
				6:
					left = world.x
					bottom = world.y
				7:
					left = world.x
			if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
				left = roundf(left / SNAP) * SNAP
				top = roundf(top / SNAP) * SNAP
				right = roundf(right / SNAP) * SNAP
				bottom = roundf(bottom / SNAP) * SNAP
			var resized := Rect2(
				Vector2(minf(left, right), minf(top, bottom)),
				Vector2(absf(right - left), absf(bottom - top))
			)
			resized.size = resized.size.max(ROOM_MIN_SIZE)
			_begin_change()
			_room_rect = resized
			_dirty = true
			_update_status()
			_canvas.queue_redraw()
		"marquee":
			_marquee_current = _world_to_screen(world)
			_canvas.queue_redraw()


func _left_down(screen: Vector2) -> void:
	var start_world := _screen_to_world(screen)
	_pending_snapshot = _snapshot()
	_change_started = false

	if _mode == "collider" or _mode == "trigger":
		_create_type = _mode
		_creating = true
		_drag = "create"
		_create_anchor = _snap_point(start_world)
		_create_current = _create_anchor
		_canvas.queue_redraw()
		return

	if _mode == "room":
		var room_handle := _room_handle_at(screen)
		if room_handle >= 0:
			_drag = "room_resize"
			_room_handle = room_handle
			_room_origin_rect = _room_rect
			return
		if _room_screen_rect().has_point(screen):
			_drag = "room_move"
			_room_origin_rect = _room_rect
			_drag_start_world = start_world
		return

	if _mode == "map":
		var map_item := _map_item()
		if map_item.is_empty():
			return
		_select_single(str(map_item.get("id", "")))
		_sync_panel()
		var map_pos: Vector2 = map_item.get("pos", Vector2.ZERO)
		var map_size: Vector2 = map_item.get("size", Vector2.ZERO)
		var map_rotation := deg_to_rad(float(map_item.get("rotation", 0.0)))
		if _rotation_handle_at(screen, map_item):
			_drag = "rotate"
			_rotate_start_world = start_world
			_rotate_origin_angle = float(map_item.get("rotation", 0.0))
			return
		var map_handle := _handle_at(screen, map_item)
		if map_handle >= 0:
			_drag = "resize"
			_drag_handle = map_handle
			_drag_origin_pos = map_pos
			_drag_rotation = map_rotation
			_drag_origin_rect = Rect2(-map_size * 0.5, map_size)
			return
		var map_local := (start_world - map_pos).rotated(-map_rotation)
		if Rect2(-map_size * 0.5, map_size).has_point(map_local):
			_begin_group_move(start_world)
		_canvas.queue_redraw()
		return

	if _mode == "select" and not _selected_exit.is_empty():
		var exit_handle := _exit_handle_at(screen)
		if exit_handle >= 0:
			_drag = "exit_resize"
			_exit_resize_handle = exit_handle
			_exit_drag_role = _selected_exit
			var exit_data := _exit_rect(_selected_exit)
			_exit_origin_size = exit_data.get("size", Vector2(200, 280))
			_exit_origin_rotation = float(exit_data.get("rotation", 0.0))
			return
		if _exit_rotate_at(screen):
			_drag = "exit_rotate"
			_exit_drag_role = _selected_exit
			_exit_origin_rotation = float(_exit_rect(_selected_exit).get("rotation", 0.0))
			_drag_start_world = start_world
			return

	if _mode == "select" and not _selected_door.is_empty():
		var trigger_handle := _door_trigger_handle_at(screen)
		if trigger_handle >= 0:
			_drag = "door_trigger_resize"
			_door_trigger_handle = trigger_handle
			_door_drag_role = _selected_door
			var trig := _door_trigger(_selected_door)
			_door_trigger_origin = trig.get("pos", Vector2.ZERO)
			_door_trigger_origin_size = trig.get("size", Vector2(200.0, 280.0))
			return
		if _door_trigger_contains(_selected_door, screen) and not _door_screen_rect(_selected_door).has_point(screen):
			var door_node = _doors.get(_selected_door)
			if door_node is Node2D:
				_drag = "door_trigger_move"
				_door_drag_role = _selected_door
				_door_trigger_origin = _door_trigger(_selected_door).get("pos", Vector2.ZERO)
				_door_trigger_start_local = (door_node as Node2D).to_local(_world.to_global(start_world))
				return
		if _door_rotate_at(screen):
			_drag = "door_rotate"
			_door_drag_role = _selected_door
			_drag_start_world = start_world
			return
		var door_handle := _door_handle_at(screen)
		if door_handle >= 0:
			_drag = "door_resize"
			_door_resize_handle = door_handle
			_door_drag_role = _selected_door
			_door_origin_scale = _door_scales.get(_selected_door, Vector2.ONE)
			return

	if _mode == "select":
		var exit_role := _exit_at(screen)
		if not exit_role.is_empty():
			_selected_exit = exit_role
			_selected_door = ""
			selected_id = ""
			selected_ids.clear()
			_exit_drag_role = exit_role
			_exit_drag_origin = _exit_rect(exit_role).get("pos", Vector2.ZERO)
			_drag_start_world = start_world
			_drag = "exit_move"
			_sync_panel()
			_canvas.queue_redraw()
			return

	if _mode == "select":
		var door_role := _door_at(screen)
		if not door_role.is_empty():
			_selected_door = door_role
			_selected_exit = ""
			selected_id = ""
			selected_ids.clear()
			_sync_panel()
			_drag = "door"
			_door_drag_role = door_role
			_door_drag_origin = _door_positions[door_role]
			_drag_start_world = start_world
			_canvas.queue_redraw()
			return

	if _mode == "select" and _world_to_screen(_spawn_pos).distance_to(screen) <= 18.0:
		_selected_door = ""
		_selected_exit = ""
		_drag = "spawn"
		_spawn_origin = _spawn_pos
		_drag_start_world = start_world
		_canvas.queue_redraw()
		return

	var selected := _selected_item()
	if selected_ids.size() == 1 and not selected.is_empty():
		var selected_shape := str(selected.get("shape", "rect"))
		if selected_shape == "arc":
			var arc_handle := _arc_handle_at(screen, selected)
			if not arc_handle.is_empty():
				_drag = "arc_" + arc_handle
				return
			var arc_points := _arc_handle_points(selected)
			if screen.distance_to(arc_points["center"]) <= HANDLE_HIT:
				_begin_group_move(start_world)
				return
		elif selected_shape == "bezier":
			var bezier_handle := _bezier_handle_at(screen, selected)
			if bezier_handle >= 0:
				_drag = "bezier_point"
				_bezier_point_index = bezier_handle
				return
		elif selected_shape == "polygon":
			var polygon_handle := _polygon_handle_at(screen, selected)
			if polygon_handle >= 0:
				if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
					_remove_polygon_point(selected, polygon_handle)
				else:
					_drag = "polygon_point"
					_polygon_point_index = polygon_handle
				return
			if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
				var edge_index := _polygon_edge_at(screen, selected)
				if edge_index >= 0:
					_insert_polygon_point(selected, edge_index, start_world)
					return
		else:
			if _rotation_handle_at(screen, selected):
				_drag = "rotate"
				_rotate_start_world = start_world
				_rotate_origin_angle = float(selected.get("rotation", 0.0))
				return
			var handle := _handle_at(screen, selected)
			if handle >= 0:
				_drag = "resize"
				_drag_handle = handle
				var pos: Vector2 = selected.get("pos", Vector2.ZERO)
				var size: Vector2 = selected.get("size", Vector2.ZERO)
				_drag_origin_pos = pos
				_drag_rotation = deg_to_rad(float(selected.get("rotation", 0.0)))
				_drag_origin_rect = Rect2(-size * 0.5, size)
				return
	var hit := _item_at(start_world)
	if not hit.is_empty():
		var hit_id := str(hit.get("id", ""))
		var additive := Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)
		_selected_door = ""
		_selected_exit = ""
		if additive:
			_toggle_selection(hit_id)
			_canvas.queue_redraw()
			return
		if not selected_ids.has(hit_id):
			_select_single(hit_id)
		else:
			selected_id = hit_id
		_begin_group_move(start_world)
		_sync_panel()
		_canvas.queue_redraw()
		return
	if not (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL)):
		selected_ids.clear()
		selected_id = ""
		_selected_door = ""
		_selected_exit = ""
		_sync_panel()
	_drag = "marquee"
	_marquee_start = screen
	_marquee_current = screen
	_canvas.queue_redraw()


func _left_up() -> void:
	if _drag == "marquee":
		_finish_marquee()
		_drag = ""
		_canvas.queue_redraw()
		return
	if _drag == "create":
		_finish_create()
		_drag = ""
		_creating = false
		_drag_handle = -1
		_change_started = false
		return
	_drag = ""
	_drag_handle = -1
	_bezier_point_index = -1
	_polygon_point_index = -1
	_door_resize_handle = -1
	_door_trigger_handle = -1
	_door_drag_role = ""
	_exit_resize_handle = -1
	_exit_drag_role = ""
	_change_started = false


# ---------------------------------------------------------------- 操作

func _create_collider_at_center() -> void:
	_create_default("collider")


func _create_trigger_at_center() -> void:
	_create_default("trigger")


func _create_slope_at_center() -> void:
	_create_default("collider", 45.0, "Slope")


func _create_arc_at_center() -> void:
	if not active:
		return
	var center := _screen_to_world(get_viewport().get_visible_rect().size * 0.5)
	_push_snapshot()
	var item := _new_item("collider", _snap_point(center), Vector2.ZERO, "arc")
	item["name"] = "Curve"
	items.append(item)
	_select_single(str(item.get("id", "")))
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已创建曲面碰撞体，拖动端点/半径圆点调整")


func _create_bezier_at_center() -> void:
	if not active:
		return
	var center := _screen_to_world(get_viewport().get_visible_rect().size * 0.5)
	_push_snapshot()
	var item := _new_item("collider", _snap_point(center), Vector2.ZERO, "bezier")
	item["name"] = "Bezier"
	item["points"] = [
		Vector2(-256, 96), Vector2(-96, -128), Vector2(96, -128), Vector2(256, 96)
	]
	item["thickness"] = 48.0
	item["segments"] = 0
	items.append(item)
	_select_single(str(item.get("id", "")))
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已创建贝塞尔碰撞体，拖动 4 个控制点调整曲线")


func _create_polygon_at_center() -> void:
	if not active:
		return
	var center := _screen_to_world(get_viewport().get_visible_rect().size * 0.5)
	_push_snapshot()
	var item := _new_item("collider", _snap_point(center), Vector2.ZERO, "polygon")
	item["name"] = "Polygon"
	item["points"] = _default_polygon_points()
	items.append(item)
	_select_single(str(item.get("id", "")))
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已创建多边形，拖顶点调整；Ctrl+点边加点，Ctrl+点顶点删点")


func _create_default(type: String, rotation_deg := 0.0, custom_name := "") -> void:
	if not active:
		return
	var center := _screen_to_world(get_viewport().get_visible_rect().size * 0.5)
	var default_size := DEFAULT_COLLIDER_SIZE if type == "collider" else DEFAULT_TRIGGER_SIZE
	_push_snapshot()
	var item := _new_item(type, _snap_point(center), default_size)
	item["rotation"] = rotation_deg
	if not custom_name.is_empty():
		item["name"] = custom_name
	items.append(item)
	_select_single(str(item.get("id", "")))
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已创建%s，拖动手柄调整大小，拖圆点旋转" % ("斜面" if rotation_deg != 0.0 else ("碰撞体" if type == "collider" else "触发区")))


func _finish_create() -> void:
	var rect := _rect_from_points(_create_anchor, _create_current)
	if rect.size.x < MIN_SIZE or rect.size.y < MIN_SIZE:
		var default_size := DEFAULT_COLLIDER_SIZE if _create_type == "collider" else DEFAULT_TRIGGER_SIZE
		rect = Rect2(_create_anchor - default_size * 0.5, default_size)
	_push_snapshot()
	var item := _new_item(_create_type, rect.get_center(), rect.size)
	items.append(item)
	_select_single(str(item.get("id", "")))
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()


func _move_to(world: Vector2) -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var delta := world - _drag_start_world
	var new_pos: Vector2 = _drag_origin_pos + delta
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		if absf(float(item.get("rotation", 0.0))) > 0.01:
			new_pos = Vector2(roundf(new_pos.x / SNAP) * SNAP, roundf(new_pos.y / SNAP) * SNAP)
		else:
			var half: Vector2 = item.get("size", Vector2.ZERO) * 0.5
			var corner := new_pos - half
			corner = Vector2(roundf(corner.x / SNAP) * SNAP, roundf(corner.y / SNAP) * SNAP)
			new_pos = corner + half
	var snapped_delta := new_pos - _drag_origin_pos
	_begin_change()
	if _drag_group_origins.is_empty():
		item["pos"] = new_pos
		_apply_scene_geometry(item)
	else:
		for group_item in items:
			var id := str(group_item.get("id", ""))
			if _drag_group_origins.has(id):
				var origin: Vector2 = _drag_group_origins[id]
				group_item["pos"] = origin + snapped_delta
				_apply_scene_geometry(group_item)
	_sync_panel()


func _resize_to(world: Vector2) -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var r := _drag_origin_rect
	var m := (world - _drag_origin_pos).rotated(-_drag_rotation)
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		m = Vector2(roundf(m.x / SNAP) * SNAP, roundf(m.y / SNAP) * SNAP)
	var left := r.position.x
	var right := r.end.x
	var top := r.position.y
	var bottom := r.end.y
	match _drag_handle:
		0:
			left = m.x
			top = m.y
		1:
			top = m.y
		2:
			right = m.x
			top = m.y
		3:
			right = m.x
		4:
			right = m.x
			bottom = m.y
		5:
			bottom = m.y
		6:
			left = m.x
			bottom = m.y
		7:
			left = m.x
	var rect := Rect2(
		Vector2(minf(left, right), minf(top, bottom)),
		Vector2(absf(right - left), absf(bottom - top))
	)
	rect.size = rect.size.max(Vector2(MIN_SIZE, MIN_SIZE))
	_begin_change()
	item["pos"] = _drag_origin_pos + rect.get_center().rotated(_drag_rotation)
	item["size"] = rect.size
	_sync_panel()


func _rotate_to(world: Vector2) -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var delta := rad_to_deg((world - pos).angle() - (_rotate_start_world - pos).angle())
	var angle := _rotate_origin_angle + delta
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		angle = roundf(angle / ROTATE_SNAP) * ROTATE_SNAP
	_begin_change()
	item["rotation"] = _normalize_angle(angle)
	_sync_panel()


func _arc_drag_angle(world: Vector2, is_start: bool) -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var angle := fposmod(rad_to_deg((world - pos).angle()), 360.0)
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		angle = fposmod(roundf(angle / ROTATE_SNAP) * ROTATE_SNAP, 360.0)
	_begin_change()
	var key := "start_angle" if is_start else "end_angle"
	item[key] = angle
	_sync_panel()


func _arc_drag_radius_axis(world: Vector2, axis: String) -> void:
	var item := _selected_item()
	if item.is_empty():
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var local := (world - pos).rotated(-_arc_rotation_radians(item))
	var thickness := float(item.get("thickness", 48.0))
	var value := 0.0
	if axis == "x":
		value = absf(local.x) - thickness * 0.5
	else:
		value = absf(local.y) - thickness * 0.5
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		value = roundf(value / SNAP) * SNAP
	_begin_change()
	var key := "radius_x" if axis == "x" else "radius_y"
	item[key] = clampf(value, 8.0, 8192.0)
	_sync_panel()


func _delete_selected() -> void:
	if selected_ids.is_empty():
		return
	_push_snapshot()
	var ids := selected_ids.duplicate()
	for i in range(items.size() - 1, -1, -1):
		if not ids.has(str(items[i].get("id", ""))):
			continue
		var item: Dictionary = items[i]
		if str(item.get("type", "")) == "scene":
			var meta = item.get("meta", {})
			if meta is Dictionary:
				meta["disabled"] = true
				item["meta"] = meta
			LayoutStore.apply_scene_item(item)
		else:
			items.remove_at(i)
	selected_ids.clear()
	selected_id = ""
	_sync_panel()
	_canvas.queue_redraw()


func _duplicate_selected() -> void:
	if selected_ids.is_empty():
		return
	var originals: Array[Dictionary] = []
	for item in items:
		if selected_ids.has(str(item.get("id", ""))) and str(item.get("type", "")) != "map":
			originals.append(item)
	if originals.is_empty():
		return
	_push_snapshot()
	var new_ids: Array[String] = []
	for item in originals:
		var copy: Dictionary = item.duplicate(true)
		var type := str(copy.get("type", "collider"))
		if type == "scene":
			# 场景碰撞体复制后变成普通布局碰撞体，避免与原节点重复绑定
			copy["type"] = "collider"
			copy["name"] = str(copy.get("name", "")) + " 副本"
			copy["meta"] = {}
			type = "collider"
		var shape := str(copy.get("shape", "rect"))
		var prefix := "a" if shape == "arc" else ("b" if shape == "bezier" else ("p" if shape == "polygon" else ("c" if type == "collider" else "t")))
		copy["id"] = _next_id(prefix)
		copy["pos"] = Vector2(copy.get("pos", Vector2.ZERO)) + Vector2(SNAP, SNAP)
		items.append(copy)
		new_ids.append(str(copy.get("id", "")))
	selected_ids = new_ids
	selected_id = selected_ids.back() if not selected_ids.is_empty() else ""
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()


func _nudge(keycode: int) -> void:
	if selected_ids.is_empty():
		return
	var delta := Vector2.ZERO
	match keycode:
		KEY_LEFT:
			delta = Vector2(-SNAP, 0)
		KEY_RIGHT:
			delta = Vector2(SNAP, 0)
		KEY_UP:
			delta = Vector2(0, -SNAP)
		KEY_DOWN:
			delta = Vector2(0, SNAP)
	if delta == Vector2.ZERO:
		return
	_push_snapshot()
	for item in items:
		if selected_ids.has(str(item.get("id", ""))):
			item["pos"] = Vector2(item.get("pos", Vector2.ZERO)) + delta
			_apply_scene_geometry(item)
	_sync_panel()
	_canvas.queue_redraw()


func _save(notify: bool) -> String:
	if _scene == null:
		return ""
	var path := LayoutStore.save_items(_scene.scene_file_path, items, _spawn_pos, _room_rect, _door_data(), _exit_data())
	if path.is_empty():
		if notify:
			_toast_msg("保存失败")
		return ""
	_dirty = false
	_update_status()
	if notify:
		_toast_msg("已保存  " + path)
	return path


# ---------------------------------------------------------------- 撤销

func _snapshot() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"selected": selected_id,
		"selected_ids": selected_ids.duplicate(),
		"selected_door": _selected_door,
		"spawn": _spawn_pos,
		"room": _room_rect,
		"doors": _door_positions.duplicate(),
		"door_scales": _door_scales.duplicate(),
		"door_rotations": _door_rotations.duplicate(),
		"door_triggers": _door_triggers.duplicate(true),
		"exits": _exit_rects.duplicate(true),
		"selected_exit": _selected_exit,
	}


func _push_snapshot() -> void:
	_undo.append(_snapshot())
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()
	_dirty = true


func _begin_change() -> void:
	if _change_started:
		return
	_change_started = true
	_undo.append(_pending_snapshot)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()
	_dirty = true


func _undo_last() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	var state: Dictionary = _undo.pop_back()
	items = _clone_items(state.get("items", []))
	_restore_selection(state)
	_apply_all_scene_geometry()
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()


func _redo_last() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	var state: Dictionary = _redo.pop_back()
	items = _clone_items(state.get("items", []))
	_restore_selection(state)
	_apply_all_scene_geometry()
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()


func _restore_selection(state: Dictionary) -> void:
	if state.get("spawn") is Vector2:
		var saved_spawn: Vector2 = state["spawn"]
		_spawn_pos = saved_spawn
	if state.get("room") is Rect2:
		var saved_room: Rect2 = state["room"]
		_room_rect = saved_room
	if state.get("doors") is Dictionary:
		_door_positions = state["doors"].duplicate()
		if state.get("door_scales") is Dictionary:
			_door_scales = state["door_scales"].duplicate()
		if state.get("door_rotations") is Dictionary:
			_door_rotations = state["door_rotations"].duplicate()
		if state.get("door_triggers") is Dictionary:
			_door_triggers = state["door_triggers"].duplicate(true)
		_selected_door = str(state.get("selected_door", ""))
		for role in _door_positions.keys():
			if _doors.has(role) and is_instance_valid(_doors[role]):
				var door := _doors[role] as Node2D
				door.position = _door_positions[role]
				door.scale = _door_scales.get(role, door.scale)
				door.rotation_degrees = float(_door_rotations.get(role, door.rotation_degrees))
				if _door_triggers.has(role):
					_apply_door_trigger(role)
	if state.get("exits") is Dictionary:
		_exit_rects = state["exits"].duplicate(true)
		_selected_exit = str(state.get("selected_exit", ""))
		for role in _exit_rects.keys():
			_apply_exit(role)
	selected_id = str(state.get("selected", ""))
	selected_ids.clear()
	var ids = state.get("selected_ids", [])
	if ids is Array:
		for value in ids:
			if value is String:
				selected_ids.append(value)
	if selected_ids.is_empty() and not selected_id.is_empty():
		selected_ids.append(selected_id)
	if not selected_ids.has(selected_id):
		selected_id = selected_ids.back() if not selected_ids.is_empty() else ""


# ---------------------------------------------------------------- 面板同步

func _sync_panel() -> void:
	var item := _selected_item()
	_props.visible = active and not item.is_empty()
	if item.is_empty():
		return
	_syncing = true
	var is_trigger := str(item.get("type", "collider")) == "trigger"
	var is_map := str(item.get("type", "collider")) == "map"
	var is_scene := str(item.get("type", "collider")) == "scene"
	var is_arc := str(item.get("shape", "rect")) == "arc"
	var is_bezier := str(item.get("shape", "rect")) == "bezier"
	var is_polygon := str(item.get("shape", "rect")) == "polygon"
	var title := "场景碰撞体（多边形）" if is_scene else ("多边形碰撞体" if is_polygon else ("贝塞尔碰撞体" if is_bezier else ("曲面碰撞体" if is_arc else ("触发区" if is_trigger else ("地图背景" if is_map else "碰撞体")))))
	if selected_ids.size() > 1:
		title += " · 已选 %d" % selected_ids.size()
	_prop_title.text = title
	_name_edit.text = str(item.get("name", ""))
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var size: Vector2 = item.get("size", Vector2.ZERO)
	_pos_label.text = "位置   %d, %d" % [roundi(pos.x), roundi(pos.y)]
	if is_polygon:
		_size_label.text = "顶点   %d" % _polygon_item_points(item).size()
		_size_label.visible = true
	else:
		_size_label.text = "尺寸   %d × %d" % [roundi(size.x), roundi(size.y)]
		_size_label.visible = not is_arc and not is_bezier
	_map_width_row.visible = is_map
	_map_height_row.visible = is_map
	_map_layer_row.visible = is_map
	if is_map:
		_map_width_spin.set_value_no_signal(maxf(size.x, 16.0))
		_map_height_spin.set_value_no_signal(maxf(size.y, 16.0))
		_sync_map_layers(item)
	_rotation_row.visible = not is_arc and not is_bezier and not is_polygon
	_radius_x_row.visible = is_arc
	_radius_y_row.visible = is_arc
	_thickness_row.visible = is_arc or is_bezier
	_start_row.visible = is_arc
	_end_row.visible = is_arc
	_arc_rotation_row.visible = is_arc
	_clockwise_row.visible = is_arc
	_segments_row.visible = is_arc or is_bezier
	if is_arc:
		var radii := _arc_radii(item)
		_radius_x_spin.set_value_no_signal(radii.x)
		_radius_y_spin.set_value_no_signal(radii.y)
		_thickness_spin.set_value_no_signal(float(item.get("thickness", 48.0)))
		_start_spin.set_value_no_signal(float(item.get("start_angle", 0.0)))
		_end_spin.set_value_no_signal(float(item.get("end_angle", 90.0)))
		_arc_rotation_spin.set_value_no_signal(_normalize_angle(float(item.get("arc_rotation", 0.0))))
		_clockwise_check.set_pressed_no_signal(bool(item.get("clockwise", true)))
		_segments_spin.set_value_no_signal(float(item.get("segments", 0)))
	elif is_bezier:
		_thickness_spin.set_value_no_signal(_bezier_thickness(item))
		_segments_spin.set_value_no_signal(float(item.get("segments", 0)))
	else:
		_rotation_spin.set_value_no_signal(float(item.get("rotation", 0.0)))
	_layer_row.visible = not is_trigger and not is_map and not is_scene
	_mask_row.visible = is_trigger
	_group_row.visible = is_trigger
	_purpose_row.visible = is_trigger
	_scene_enabled_row.visible = is_scene
	if is_scene:
		_scene_enabled_check.set_pressed_no_signal(not _scene_item_disabled(item))
	if is_trigger:
		var mask := int(item.get("mask", 4))
		for i in _mask_option.item_count:
			if int(_mask_option.get_item_metadata(i)) == mask:
				_mask_option.select(i)
				break
		_group_edit.text = str(item.get("group", ""))
		_purpose_edit.text = str(item.get("purpose", ""))
	else:
		var layer := int(item.get("layer", 1))
		for i in _layer_option.item_count:
			if int(_layer_option.get_item_metadata(i)) == layer:
				_layer_option.select(i)
				break
	_syncing = false


func _on_name_changed(text: String) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	item["name"] = text
	_dirty = true
	_canvas.queue_redraw()


func _on_layer_selected(index: int) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_push_snapshot()
	item["layer"] = int(_layer_option.get_item_metadata(index))
	_canvas.queue_redraw()


func _on_rotation_changed(value: float) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	item["rotation"] = _normalize_angle(value)
	_dirty = true
	_canvas.queue_redraw()


func _on_map_size_changed(_value: float) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty() or str(item.get("type", "")) != "map":
		return
	var size := Vector2(maxf(_map_width_spin.value, 16.0), maxf(_map_height_spin.value, 16.0))
	item["size"] = size
	_size_label.text = "尺寸   %d × %d" % [roundi(size.x), roundi(size.y)]
	_dirty = true
	_canvas.queue_redraw()


func _sync_map_layers(current: Dictionary) -> void:
	_map_layer_option.clear()
	var maps := _map_items()
	maps.reverse()
	var current_id := str(current.get("id", ""))
	for i in maps.size():
		var map: Dictionary = maps[i]
		var label := "%s  z%d" % [str(map.get("name", "")), int(map.get("z", 0))]
		if bool(map.get("repeat", false)):
			label += "  平铺"
		_map_layer_option.add_item(label)
		_map_layer_option.set_item_metadata(i, str(map.get("id", "")))
		if str(map.get("id", "")) == current_id:
			_map_layer_option.select(i)


func _on_map_layer_selected(index: int) -> void:
	if _syncing:
		return
	var map_id := str(_map_layer_option.get_item_metadata(index))
	if map_id.is_empty():
		return
	_select_single(map_id)
	_sync_panel()
	_canvas.queue_redraw()


func _on_arc_value_changed(_value: float) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	if str(item.get("shape", "rect")) == "bezier":
		item["thickness"] = clampf(_thickness_spin.value, 4.0, 4096.0)
		item["segments"] = int(_segments_spin.value)
		_dirty = true
		_canvas.queue_redraw()
		return
	item["radius_x"] = clampf(_radius_x_spin.value, 8.0, 8192.0)
	item["radius_y"] = clampf(_radius_y_spin.value, 8.0, 8192.0)
	item["thickness"] = clampf(_thickness_spin.value, 4.0, 4096.0)
	item["start_angle"] = fposmod(_start_spin.value, 360.0)
	item["end_angle"] = fposmod(_end_spin.value, 360.0)
	item["arc_rotation"] = _normalize_angle(_arc_rotation_spin.value)
	item["clockwise"] = _clockwise_check.button_pressed
	item["segments"] = int(_segments_spin.value)
	_dirty = true
	_canvas.queue_redraw()


func _on_mask_selected(index: int) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	_push_snapshot()
	item["mask"] = int(_mask_option.get_item_metadata(index))
	_canvas.queue_redraw()


func _on_group_changed(text: String) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	item["group"] = text.strip_edges()
	_dirty = true


func _on_purpose_changed(text: String) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty():
		return
	item["purpose"] = text.strip_edges()
	_dirty = true


func _on_scene_enabled_toggled(on: bool) -> void:
	if _syncing:
		return
	var item := _selected_item()
	if item.is_empty() or str(item.get("type", "")) != "scene":
		return
	var meta = item.get("meta", {})
	if meta is Dictionary:
		meta["disabled"] = not on
		item["meta"] = meta
	LayoutStore.apply_scene_item(item)
	_dirty = true
	_canvas.queue_redraw()


# ---------------------------------------------------------------- 绘制

func _draw_grid(c: Control, view: Rect2) -> void:
	var step := SNAP
	var inv_canvas := get_viewport().get_canvas_transform().affine_inverse()
	var inv_world := _world.get_global_transform().affine_inverse()
	var corners := [
		view.position,
		Vector2(view.end.x, view.position.y),
		view.end,
		Vector2(view.position.x, view.end.y),
	]
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for corner in corners:
		var w: Vector2 = inv_world * (inv_canvas * corner)
		minp = Vector2(minf(minp.x, w.x), minf(minp.y, w.y))
		maxp = Vector2(maxf(maxp.x, w.x), maxf(maxp.y, w.y))
	while (maxp.x - minp.x) / step > 220.0:
		step *= 2.0

	var x := floorf(minp.x / step) * step
	while x <= maxp.x:
		var major := int(roundf(x / step)) % 8 == 0
		var color := Color(0.35, 0.8, 0.9, 0.13 if major else 0.045)
		c.draw_line(_world_to_screen(Vector2(x, minp.y)), _world_to_screen(Vector2(x, maxp.y)), color, 1.0)
		x += step

	var y := floorf(minp.y / step) * step
	while y <= maxp.y:
		var major := int(roundf(y / step)) % 8 == 0
		var color := Color(0.35, 0.8, 0.9, 0.13 if major else 0.045)
		c.draw_line(_world_to_screen(Vector2(minp.x, y)), _world_to_screen(Vector2(maxp.x, y)), color, 1.0)
		y += step


func _draw_item(c: Control, item: Dictionary, selected: bool, primary := false) -> void:
	if str(item.get("shape", "rect")) == "arc":
		_draw_arc_item(c, item, selected, primary)
		return
	if str(item.get("shape", "rect")) == "bezier":
		_draw_bezier_item(c, item, selected, primary)
		return
	if str(item.get("shape", "rect")) == "polygon":
		_draw_polygon_item(c, item, selected, primary)
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var size: Vector2 = item.get("size", Vector2.ZERO)
	var angle := float(item.get("rotation", 0.0))
	var is_trigger := str(item.get("type", "collider")) == "trigger"
	var color := COL_TRIGGER if is_trigger else COL_COLLIDER
	var pts := _rect_screen_points(pos, size, angle)
	c.draw_colored_polygon(pts, Color(color, 0.22 if selected else 0.14))
	var line_color := COL_SELECT if selected else Color(color, 0.9)
	var line_width := 2.5 if primary else (2.0 if selected else 1.5)
	_close_polyline(c, pts, line_color, line_width)
	var label := "%s  %d×%d" % [str(item.get("name", "")), roundi(size.x), roundi(size.y)]
	if absf(angle) > 0.01:
		label += "  %d°" % roundi(angle)
	c.draw_string(_font, pts[0] + Vector2(4, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.95))


func _draw_handles(c: Control, item: Dictionary) -> void:
	if str(item.get("shape", "rect")) == "arc":
		_draw_arc_handles(c, item)
		return
	if str(item.get("shape", "rect")) == "bezier":
		_draw_bezier_handles(c, item)
		return
	if str(item.get("shape", "rect")) == "polygon":
		_draw_polygon_handles(c, item)
		return
	var points := _handle_points(item)
	for point in points:
		var rect := Rect2(point - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(rect, Color(0.05, 0.08, 0.1, 0.92))
		c.draw_rect(rect, COL_SELECT, false, 1.0)
	var center := _world_to_screen(item.get("pos", Vector2.ZERO))
	var top := points[1]
	var direction := top - center
	if direction.length() < 0.5:
		direction = Vector2.UP
	direction = direction.normalized()
	var knob := top + direction * ROTATE_HANDLE_DIST
	c.draw_line(top, knob, Color(1, 1, 1, 0.6), 1.2, true)
	c.draw_circle(knob, ROTATE_HANDLE_RADIUS, Color(0.05, 0.08, 0.1, 0.95))
	c.draw_arc(knob, ROTATE_HANDLE_RADIUS, 0.0, TAU, 24, COL_SELECT, 1.5, true)


func _draw_map_preview(c: Control, item: Dictionary) -> void:
	var texture := _map_texture(item)
	if texture == null:
		return
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var size: Vector2 = item.get("size", texture_size)
	var half := size * 0.5
	if bool(item.get("repeat", false)):
		var a := _world_to_screen(pos - half)
		var b := _world_to_screen(pos + half)
		c.draw_texture_rect(texture, Rect2(a, b - a).abs(), true)
		return
	var rad := deg_to_rad(float(item.get("rotation", 0.0)))
	var origin := _world_to_screen(pos + Vector2(-half.x, -half.y).rotated(rad))
	var x_axis := (_world_to_screen(pos + Vector2(half.x, -half.y).rotated(rad)) - origin) / texture_size.x
	var y_axis := (_world_to_screen(pos + Vector2(-half.x, half.y).rotated(rad)) - origin) / texture_size.y
	c.draw_set_transform_matrix(Transform2D(x_axis, y_axis, origin))
	c.draw_texture(texture, Vector2.ZERO)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## 所有地图条目，按 z 从低到高排序，便于预览按层叠顺序绘制。
func _map_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if str(item.get("type", "")) == "map":
			result.append(item)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z", 0)) < int(b.get("z", 0))
	)
	return result


## 当前选中的地图条目；未选中地图时回退到最上层地图。
func _map_item() -> Dictionary:
	var selected := _selected_item()
	if not selected.is_empty() and str(selected.get("type", "")) == "map":
		return selected
	var maps := _map_items()
	return maps.back() if not maps.is_empty() else {}


func _map_texture(item: Dictionary) -> Texture2D:
	var path := str(item.get("texture", ""))
	if path.is_empty():
		return null
	if _map_textures.has(path):
		return _map_textures[path]
	var texture: Texture2D = load(path)
	if texture != null:
		_map_textures[path] = texture
	return texture


func _draw_arc_item(c: Control, item: Dictionary, selected: bool, primary := false) -> void:
	var radii := _arc_radii(item)
	var thickness := float(item.get("thickness", 48.0))
	var inner_rx := maxf(radii.x - thickness * 0.5, 1.0)
	var inner_ry := maxf(radii.y - thickness * 0.5, 1.0)
	var outer_rx := radii.x + thickness * 0.5
	var outer_ry := radii.y + thickness * 0.5
	var start := float(item.get("start_angle", 0.0))
	var span := _arc_span_degrees(item)
	var direction := _arc_direction(item)
	var segments := _arc_segments(item, span)
	var is_trigger := str(item.get("type", "collider")) == "trigger"
	var color := COL_TRIGGER if is_trigger else COL_COLLIDER
	var outline := COL_SELECT if selected else Color(color, 0.9)
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	for i in segments + 1:
		var angle := start + direction * span * float(i) / float(segments)
		outer_points.append(_world_to_screen(_arc_world_point(item, angle, outer_rx, outer_ry)))
		inner_points.append(_world_to_screen(_arc_world_point(item, angle, inner_rx, inner_ry)))
	for i in segments:
		var quad := PackedVector2Array([
			outer_points[i], outer_points[i + 1], inner_points[i + 1], inner_points[i]
		])
		c.draw_colored_polygon(quad, Color(color, 0.22 if selected else 0.14))
	var width := 2.5 if primary else (2.0 if selected else 1.5)
	c.draw_polyline(outer_points, outline, width, true)
	c.draw_polyline(inner_points, outline, width, true)
	c.draw_line(outer_points[0], inner_points[0], outline, width, true)
	c.draw_line(outer_points[segments], inner_points[segments], outline, width, true)
	var mid_angle := start + direction * span * 0.5
	var label_pos := _world_to_screen(_arc_world_point(item, mid_angle, outer_rx, outer_ry))
	var radius_text := "R%d" % roundi(radii.x) if is_equal_approx(radii.x, radii.y) else "RX%d RY%d" % [roundi(radii.x), roundi(radii.y)]
	var label := "%s  %s T%d" % [str(item.get("name", "")), radius_text, roundi(thickness)]
	if span < 359.9:
		label += "  %d°" % roundi(span)
	c.draw_string(_font, label_pos + Vector2(4, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.95))


func _draw_arc_handles(c: Control, item: Dictionary) -> void:
	var handles := _arc_handle_points(item)
	var start_point: Vector2 = handles["start"]
	var end_point: Vector2 = handles["end"]
	var x_point: Vector2 = handles["x_radius"]
	var y_point: Vector2 = handles["y_radius"]
	var center_point: Vector2 = handles["center"]
	c.draw_line(center_point - Vector2(7, 0), center_point + Vector2(7, 0), Color(1, 1, 1, 0.55), 1.0)
	c.draw_line(center_point - Vector2(0, 7), center_point + Vector2(0, 7), Color(1, 1, 1, 0.55), 1.0)
	c.draw_circle(center_point, 3.0, Color(1, 1, 1, 0.6))
	for point in [start_point, end_point]:
		var rect := Rect2(point - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(rect, Color(0.05, 0.08, 0.1, 0.92))
		c.draw_rect(rect, COL_SELECT, false, 1.0)
	for point in [x_point, y_point]:
		c.draw_circle(point, ROTATE_HANDLE_RADIUS, Color(0.05, 0.08, 0.1, 0.95))
		c.draw_arc(point, ROTATE_HANDLE_RADIUS, 0.0, TAU, 24, COL_SELECT, 1.5, true)


func _draw_bezier_item(c: Control, item: Dictionary, selected: bool, primary := false) -> void:
	var points := _bezier_item_points(item)
	var thickness := _bezier_thickness(item)
	var segments := _bezier_segments(item)
	var is_trigger := str(item.get("type", "collider")) == "trigger"
	var color := COL_TRIGGER if is_trigger else COL_COLLIDER
	var outline := COL_SELECT if selected else Color(color, 0.9)
	var outer_screen := PackedVector2Array()
	var inner_screen := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var point := _bezier_sample(points, t)
		var tangent := _bezier_tangent(points, t)
		if tangent.length_squared() < 0.0001:
			tangent = Vector2.RIGHT
		var normal := Vector2(-tangent.y, tangent.x).normalized() * thickness * 0.5
		outer_screen.append(_world_to_screen(point + normal))
		inner_screen.append(_world_to_screen(point - normal))
	for i in segments:
		var quad := PackedVector2Array([
			outer_screen[i], outer_screen[i + 1], inner_screen[i + 1], inner_screen[i]
		])
		c.draw_colored_polygon(quad, Color(color, 0.22 if selected else 0.14))
	var width := 2.5 if primary else (2.0 if selected else 1.5)
	c.draw_polyline(outer_screen, outline, width, true)
	c.draw_polyline(inner_screen, outline, width, true)
	c.draw_line(outer_screen[0], inner_screen[0], outline, width, true)
	c.draw_line(outer_screen[segments], inner_screen[segments], outline, width, true)
	var label_pos := _world_to_screen(_bezier_sample(points, 0.5))
	var label := "%s  T%d" % [str(item.get("name", "")), roundi(thickness)]
	c.draw_string(_font, label_pos + Vector2(6, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.95))


func _draw_bezier_handles(c: Control, item: Dictionary) -> void:
	var points := _bezier_item_points(item)
	var screen_points: Array[Vector2] = []
	for point in points:
		screen_points.append(_world_to_screen(point))
	c.draw_dashed_line(screen_points[0], screen_points[1], Color(1, 1, 1, 0.4), 1.0)
	c.draw_dashed_line(screen_points[2], screen_points[3], Color(1, 1, 1, 0.4), 1.0)
	for i in screen_points.size():
		var point := screen_points[i]
		var active := _drag == "bezier_point" and _bezier_point_index == i
		if i == 0 or i == 3:
			var rect := Rect2(point - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
			c.draw_rect(rect, Color(0.55, 0.95, 1.0, 0.95) if active else Color(0.05, 0.08, 0.1, 0.92))
			c.draw_rect(rect, COL_SELECT, false, 1.0)
		else:
			c.draw_circle(point, ROTATE_HANDLE_RADIUS, Color(0.55, 0.95, 1.0, 0.95) if active else Color(0.05, 0.08, 0.1, 0.95))
			c.draw_arc(point, ROTATE_HANDLE_RADIUS, 0.0, TAU, 24, COL_SELECT, 1.5, true)


func _bezier_item_points(item: Dictionary) -> Array[Vector2]:
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var result: Array[Vector2] = []
	var raw = item.get("points", [])
	if raw is Array:
		for entry in raw:
			if entry is Vector2:
				var point: Vector2 = entry
				result.append(pos + point)
			elif entry is Array and entry.size() >= 2:
				result.append(pos + Vector2(float(entry[0]), float(entry[1])))
	if result.is_empty():
		result = [
			pos + Vector2(-256, 96), pos + Vector2(-96, -128), pos + Vector2(96, -128), pos + Vector2(256, 96)
		]
	while result.size() < 4:
		result.append(result.back())
	if result.size() > 4:
		result.resize(4)
	return result


func _bezier_thickness(item: Dictionary) -> float:
	return clampf(float(item.get("thickness", 48.0)), 4.0, 4096.0)


func _bezier_segments(item: Dictionary) -> int:
	var user_segments := int(item.get("segments", 0))
	if user_segments > 0:
		return clampi(user_segments, 8, 128)
	var points := _bezier_item_points(item)
	var approx := points[0].distance_to(points[1]) + points[1].distance_to(points[2]) + points[2].distance_to(points[3])
	return clampi(int(ceil(approx / 24.0)), 8, 96)


func _bezier_sample(points: Array[Vector2], t: float) -> Vector2:
	var u := 1.0 - t
	return points[0] * (u * u * u) + points[1] * (3.0 * u * u * t) + points[2] * (3.0 * u * t * t) + points[3] * (t * t * t)


func _bezier_tangent(points: Array[Vector2], t: float) -> Vector2:
	var u := 1.0 - t
	return (points[1] - points[0]) * (3.0 * u * u) + (points[2] - points[1]) * (6.0 * u * t) + (points[3] - points[2]) * (3.0 * t * t)


func _bezier_handle_at(screen: Vector2, item: Dictionary) -> int:
	var points := _bezier_item_points(item)
	for i in points.size():
		if screen.distance_to(_world_to_screen(points[i])) <= HANDLE_HIT + 2.0:
			return i
	return -1


func _bezier_hit(world: Vector2, item: Dictionary) -> bool:
	var points := _bezier_item_points(item)
	var thickness := _bezier_thickness(item)
	var segments := _bezier_segments(item)
	for i in segments:
		var a := _bezier_sample(points, float(i) / float(segments))
		var b := _bezier_sample(points, float(i + 1) / float(segments))
		var closest := Geometry2D.get_closest_point_to_segment(world, a, b)
		if world.distance_to(closest) <= thickness * 0.5 + 6.0:
			return true
	return false


func _bezier_drag_point(world: Vector2) -> void:
	var item := _selected_item()
	if item.is_empty() or _bezier_point_index < 0:
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var target := _snap_point(world) - pos
	var points: Array = item.get("points", [])
	if _bezier_point_index >= points.size():
		return
	_begin_change()
	points[_bezier_point_index] = target
	item["points"] = points
	_dirty = true
	_sync_panel()
	_canvas.queue_redraw()


func _draw_polygon_item(c: Control, item: Dictionary, selected: bool, primary := false) -> void:
	var points := _polygon_item_points(item)
	if points.size() < 3:
		return
	var screen_points := PackedVector2Array()
	for point in points:
		screen_points.append(_world_to_screen(point))
	var item_type := str(item.get("type", "collider"))
	var is_scene := item_type == "scene"
	var is_disabled := is_scene and _scene_item_disabled(item)
	var color := COL_SCENE if is_scene else (COL_TRIGGER if item_type == "trigger" else COL_COLLIDER)
	if is_disabled:
		color = Color(0.55, 0.58, 0.62)
	var outline := COL_SELECT if selected else Color(color, 0.9)
	c.draw_colored_polygon(screen_points, Color(color, 0.22 if selected else 0.12))
	var width := 2.5 if primary else (2.0 if selected else 1.5)
	var closed := screen_points.duplicate()
	closed.append(screen_points[0])
	if (is_scene and not selected) or is_disabled:
		for i in screen_points.size():
			c.draw_dashed_line(screen_points[i], screen_points[(i + 1) % screen_points.size()], outline, width, 6.0, true, true)
	else:
		c.draw_polyline(closed, outline, width, true)
	var centroid := Vector2.ZERO
	for point in screen_points:
		centroid += point
	centroid /= float(screen_points.size())
	var label := "%s  %d 边" % [str(item.get("name", "")), points.size()]
	if is_disabled:
		label += "  已禁用"
	elif is_scene:
		label += "  场景"
	c.draw_string(_font, centroid + Vector2(6, -6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, 0.95))


func _draw_polygon_handles(c: Control, item: Dictionary) -> void:
	var points := _polygon_item_points(item)
	for i in points.size():
		var point := _world_to_screen(points[i])
		var active := _drag == "polygon_point" and _polygon_point_index == i
		var rect := Rect2(point - Vector2(HANDLE_SIZE, HANDLE_SIZE) * 0.5, Vector2(HANDLE_SIZE, HANDLE_SIZE))
		c.draw_rect(rect, Color(0.55, 0.95, 1.0, 0.95) if active else Color(0.05, 0.08, 0.1, 0.92))
		c.draw_rect(rect, COL_SELECT, false, 1.0)


func _default_polygon_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		result.append(Vector2(cos(angle), sin(angle)) * 180.0)
	return result


func _polygon_item_points(item: Dictionary) -> Array[Vector2]:
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var result: Array[Vector2] = []
	var raw = item.get("points", [])
	if raw is Array:
		for entry in raw:
			if entry is Vector2:
				var point: Vector2 = entry
				result.append(pos + point)
			elif entry is Array and entry.size() >= 2:
				result.append(pos + Vector2(float(entry[0]), float(entry[1])))
	if result.size() < 3:
		for point in _default_polygon_points():
			result.append(pos + point)
	return result


func _polygon_handle_at(screen: Vector2, item: Dictionary) -> int:
	var points := _polygon_item_points(item)
	for i in points.size():
		if screen.distance_to(_world_to_screen(points[i])) <= HANDLE_HIT + 2.0:
			return i
	return -1


func _polygon_edge_at(screen: Vector2, item: Dictionary) -> int:
	var points := _polygon_item_points(item)
	if points.size() < 3:
		return -1
	var best := -1
	var best_dist := HANDLE_HIT + 3.0
	for i in points.size():
		var a := _world_to_screen(points[i])
		var b := _world_to_screen(points[(i + 1) % points.size()])
		var closest := Geometry2D.get_closest_point_to_segment(screen, a, b)
		var distance := screen.distance_to(closest)
		if distance < best_dist:
			best_dist = distance
			best = i
	return best


func _polygon_hit(world: Vector2, item: Dictionary) -> bool:
	var points := _polygon_item_points(item)
	if points.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(world, PackedVector2Array(points)):
		return true
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var closest := Geometry2D.get_closest_point_to_segment(world, a, b)
		if world.distance_to(closest) <= 6.0:
			return true
	return false


func _polygon_drag_point(world: Vector2) -> void:
	var item := _selected_item()
	if item.is_empty() or _polygon_point_index < 0:
		return
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var target := _snap_point(world) - pos
	var points: Array = item.get("points", [])
	if _polygon_point_index >= points.size():
		return
	_begin_change()
	points[_polygon_point_index] = target
	item["points"] = points
	_dirty = true
	_apply_scene_geometry(item)
	_sync_panel()
	_canvas.queue_redraw()


func _insert_polygon_point(item: Dictionary, edge_index: int, world: Vector2) -> void:
	var points := _polygon_item_points(item)
	if points.size() < 3:
		return
	var a := points[edge_index]
	var b := points[(edge_index + 1) % points.size()]
	var target := _snap_point(Geometry2D.get_closest_point_to_segment(world, a, b))
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	_push_snapshot()
	var local_points: Array = item.get("points", [])
	local_points.insert(edge_index + 1, target - pos)
	item["points"] = local_points
	_dirty = true
	_apply_scene_geometry(item)
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已添加顶点（共 %d 个）" % local_points.size())


func _remove_polygon_point(item: Dictionary, index: int) -> void:
	var local_points: Array = item.get("points", [])
	if local_points.size() <= 3:
		_toast_msg("多边形至少保留 3 个顶点")
		return
	_push_snapshot()
	local_points.remove_at(index)
	item["points"] = local_points
	_polygon_point_index = -1
	_dirty = true
	_apply_scene_geometry(item)
	_sync_panel()
	_canvas.queue_redraw()
	_toast_msg("已删除顶点（剩余 %d 个）" % local_points.size())


func _arc_radii(item: Dictionary) -> Vector2:
	var legacy := float(item.get("radius", 240.0))
	return Vector2(
		maxf(float(item.get("radius_x", legacy)), 8.0),
		maxf(float(item.get("radius_y", legacy)), 8.0)
	)


func _arc_rotation_radians(item: Dictionary) -> float:
	return deg_to_rad(float(item.get("arc_rotation", 0.0)))


func _arc_span_degrees(item: Dictionary) -> float:
	var start := float(item.get("start_angle", 0.0))
	var end := float(item.get("end_angle", 90.0))
	var span := 0.0
	if bool(item.get("clockwise", true)):
		span = fposmod(end - start, 360.0)
	else:
		span = fposmod(start - end, 360.0)
	if span <= 0.001:
		span = 360.0
	return span


func _arc_direction(item: Dictionary) -> float:
	return 1.0 if bool(item.get("clockwise", true)) else -1.0


func _arc_segments(item: Dictionary, span_deg: float) -> int:
	var user_segments := int(item.get("segments", 0))
	if user_segments > 0:
		return clampi(user_segments, 4, 128)
	return clampi(int(ceil(span_deg / 12.0)), 4, 64)


func _arc_world_point(item: Dictionary, angle_deg: float, radius_x: float, radius_y: float) -> Vector2:
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var rad := deg_to_rad(angle_deg)
	var local := Vector2(cos(rad) * radius_x, sin(rad) * radius_y)
	return pos + local.rotated(_arc_rotation_radians(item))


func _arc_handle_points(item: Dictionary) -> Dictionary:
	var start := float(item.get("start_angle", 0.0))
	var end := float(item.get("end_angle", 90.0))
	var radii := _arc_radii(item)
	var thickness := float(item.get("thickness", 48.0))
	var center := _world_to_screen(item.get("pos", Vector2.ZERO))
	var outer_rx := radii.x + thickness * 0.5
	var outer_ry := radii.y + thickness * 0.5
	var x_point := _world_to_screen(_arc_world_point(item, 0.0, outer_rx, outer_ry))
	var y_point := _world_to_screen(_arc_world_point(item, 90.0, outer_rx, outer_ry))
	var x_dir := x_point - center
	var y_dir := y_point - center
	if x_dir.length() < 0.5:
		x_dir = Vector2.RIGHT
	if y_dir.length() < 0.5:
		y_dir = Vector2.DOWN
	return {
		"start": _world_to_screen(_arc_world_point(item, start, radii.x, radii.y)),
		"end": _world_to_screen(_arc_world_point(item, end, radii.x, radii.y)),
		"x_radius": x_point + x_dir.normalized() * ROTATE_HANDLE_DIST,
		"y_radius": y_point + y_dir.normalized() * ROTATE_HANDLE_DIST,
		"center": center,
	}


func _arc_handle_at(screen: Vector2, item: Dictionary) -> String:
	var handles := _arc_handle_points(item)
	if screen.distance_to(handles["start"]) <= HANDLE_HIT:
		return "start"
	if screen.distance_to(handles["end"]) <= HANDLE_HIT:
		return "end"
	if screen.distance_to(handles["x_radius"]) <= HANDLE_HIT:
		return "x_radius"
	if screen.distance_to(handles["y_radius"]) <= HANDLE_HIT:
		return "y_radius"
	return ""


func _arc_hit(world: Vector2, item: Dictionary) -> bool:
	var radii := _arc_radii(item)
	var thickness := float(item.get("thickness", 48.0))
	var inner_rx := maxf(radii.x - thickness * 0.5, 1.0)
	var inner_ry := maxf(radii.y - thickness * 0.5, 1.0)
	var outer_rx := radii.x + thickness * 0.5
	var outer_ry := radii.y + thickness * 0.5
	var start := float(item.get("start_angle", 0.0))
	var span := _arc_span_degrees(item)
	var direction := _arc_direction(item)
	var segments := _arc_segments(item, span)
	for i in segments:
		var a0 := start + direction * span * float(i) / float(segments)
		var a1 := start + direction * span * float(i + 1) / float(segments)
		var o0 := _arc_world_point(item, a0, outer_rx, outer_ry)
		var o1 := _arc_world_point(item, a1, outer_rx, outer_ry)
		var i1 := _arc_world_point(item, a1, inner_rx, inner_ry)
		var i0 := _arc_world_point(item, a0, inner_rx, inner_ry)
		if Geometry2D.is_point_in_polygon(world, PackedVector2Array([o0, o1, i1, i0])):
			return true
	return false


func _rect_screen_points(pos: Vector2, size: Vector2, angle := 0.0) -> PackedVector2Array:
	var half := size * 0.5
	var rad := deg_to_rad(angle)
	return PackedVector2Array([
		_world_to_screen(pos + Vector2(-half.x, -half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(half.x, -half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(half.x, half.y).rotated(rad)),
		_world_to_screen(pos + Vector2(-half.x, half.y).rotated(rad)),
	])


func _close_polyline(c: Control, points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	c.draw_polyline(closed, color, width, true)


func _handle_points(item: Dictionary) -> Array[Vector2]:
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var size: Vector2 = item.get("size", Vector2.ZERO)
	var rad := deg_to_rad(float(item.get("rotation", 0.0)))
	var h := size * 0.5
	var offsets := [
		Vector2(-h.x, -h.y), Vector2(0, -h.y), Vector2(h.x, -h.y),
		Vector2(h.x, 0), Vector2(h.x, h.y), Vector2(0, h.y),
		Vector2(-h.x, h.y), Vector2(-h.x, 0),
	]
	var points: Array[Vector2] = []
	for offset in offsets:
		points.append(_world_to_screen(pos + offset.rotated(rad)))
	return points


# ---------------------------------------------------------------- 命中与坐标

func _handle_at(screen: Vector2, item: Dictionary) -> int:
	var points := _handle_points(item)
	for i in points.size():
		if screen.distance_to(points[i]) <= HANDLE_HIT:
			return i
	return -1


func _rotation_handle_at(screen: Vector2, item: Dictionary) -> bool:
	var points := _handle_points(item)
	var center := _world_to_screen(item.get("pos", Vector2.ZERO))
	var direction := points[1] - center
	if direction.length() < 0.5:
		direction = Vector2.UP
	direction = direction.normalized()
	return screen.distance_to(points[1] + direction * ROTATE_HANDLE_DIST) <= HANDLE_HIT


func _item_at(world: Vector2) -> Dictionary:
	for i in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		if str(item.get("type", "")) == "map":
			continue
		if str(item.get("shape", "rect")) == "arc":
			if _arc_hit(world, item):
				return item
			continue
		if str(item.get("shape", "rect")) == "bezier":
			if _bezier_hit(world, item):
				return item
			continue
		if str(item.get("shape", "rect")) == "polygon":
			if _polygon_hit(world, item):
				return item
			continue
		var pos: Vector2 = item.get("pos", Vector2.ZERO)
		var size: Vector2 = item.get("size", Vector2.ZERO)
		var rad := deg_to_rad(float(item.get("rotation", 0.0)))
		var local := (world - pos).rotated(-rad)
		if Rect2(-size * 0.5, size).has_point(local):
			return item
	return {}


func _is_selected(item: Dictionary) -> bool:
	return selected_ids.has(str(item.get("id", "")))


func _select_single(id: String) -> void:
	selected_ids.clear()
	if not id.is_empty():
		selected_ids.append(id)
	selected_id = id
	_selected_exit = ""


func _toggle_selection(id: String) -> void:
	if selected_ids.has(id):
		selected_ids.erase(id)
		if selected_id == id:
			selected_id = selected_ids.back() if not selected_ids.is_empty() else ""
	else:
		selected_ids.append(id)
		selected_id = id
	_sync_panel()
	_canvas.queue_redraw()


func _begin_group_move(start_world: Vector2) -> void:
	var primary := _selected_item()
	if primary.is_empty():
		return
	_drag = "move"
	_drag_start_world = start_world
	_drag_origin_pos = primary.get("pos", Vector2.ZERO)
	_drag_group_origins.clear()
	for item in items:
		if _is_selected(item):
			_drag_group_origins[str(item.get("id", ""))] = item.get("pos", Vector2.ZERO)


func _finish_marquee() -> void:
	var start_world := _screen_to_world(_marquee_start)
	var end_world := _screen_to_world(_marquee_current)
	var rect := Rect2(
		Vector2(minf(start_world.x, end_world.x), minf(start_world.y, end_world.y)),
		Vector2(absf(end_world.x - start_world.x), absf(end_world.y - start_world.y))
	)
	if rect.size.x < 2.0 and rect.size.y < 2.0:
		return
	var picked: Array[String] = []
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		picked.assign(selected_ids)
	for item in items:
		if str(item.get("type", "")) == "map":
			continue
		if _item_bounds(item).intersects(rect):
			var id := str(item.get("id", ""))
			if not picked.has(id):
				picked.append(id)
	selected_ids = picked
	selected_id = selected_ids.back() if not selected_ids.is_empty() else ""
	_sync_panel()
	_canvas.queue_redraw()


func _selection_bounds() -> Rect2:
	var result := Rect2()
	var first := true
	for item in items:
		if not _is_selected(item):
			continue
		var bounds := _item_bounds(item)
		if first:
			result = bounds
			first = false
		else:
			result = result.merge(bounds)
	return result


func _item_bounds(item: Dictionary) -> Rect2:
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	if str(item.get("shape", "rect")) == "arc":
		var radii := _arc_radii(item)
		var thickness := float(item.get("thickness", 48.0))
		var rx := radii.x + thickness * 0.5
		var ry := radii.y + thickness * 0.5
		var rot := _arc_rotation_radians(item)
		var extent_x := sqrt(pow(rx * cos(rot), 2.0) + pow(ry * sin(rot), 2.0))
		var extent_y := sqrt(pow(rx * sin(rot), 2.0) + pow(ry * cos(rot), 2.0))
		return Rect2(pos - Vector2(extent_x, extent_y), Vector2(extent_x, extent_y) * 2.0)
	if str(item.get("shape", "rect")) == "bezier":
		var points := _bezier_item_points(item)
		var pad := _bezier_thickness(item) * 0.5
		var min_point: Vector2 = points[0]
		var max_point: Vector2 = points[0]
		for point in points:
			min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
			max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
		return Rect2(min_point - Vector2(pad, pad), max_point - min_point + Vector2(pad, pad) * 2.0)
	if str(item.get("shape", "rect")) == "polygon":
		var points := _polygon_item_points(item)
		var min_point: Vector2 = points[0]
		var max_point: Vector2 = points[0]
		for point in points:
			min_point = Vector2(minf(min_point.x, point.x), minf(min_point.y, point.y))
			max_point = Vector2(maxf(max_point.x, point.x), maxf(max_point.y, point.y))
		return Rect2(min_point, max_point - min_point)
	var size: Vector2 = item.get("size", Vector2.ZERO)
	var half := size * 0.5
	var rad := deg_to_rad(float(item.get("rotation", 0.0)))
	var corners := [
		pos + Vector2(-half.x, -half.y).rotated(rad),
		pos + Vector2(half.x, -half.y).rotated(rad),
		pos + Vector2(half.x, half.y).rotated(rad),
		pos + Vector2(-half.x, half.y).rotated(rad),
	]
	var min_point: Vector2 = corners[0]
	var max_point: Vector2 = corners[0]
	for corner in corners:
		min_point = Vector2(minf(min_point.x, corner.x), minf(min_point.y, corner.y))
		max_point = Vector2(maxf(max_point.x, corner.x), maxf(max_point.y, corner.y))
	return Rect2(min_point, max_point - min_point)


func _selected_item() -> Dictionary:
	if selected_id.is_empty() and not selected_ids.is_empty():
		selected_id = selected_ids.back()
	for item in items:
		if str(item.get("id", "")) == selected_id:
			return item
	return {}


func _world_to_screen(local: Vector2) -> Vector2:
	if _world == null:
		return local
	var global := _world.to_global(local)
	return get_viewport().get_canvas_transform() * global


func _screen_to_world(screen: Vector2) -> Vector2:
	if _world == null:
		return screen
	var global := get_viewport().get_canvas_transform().affine_inverse() * screen
	return _world.to_local(global)


func _resolve_spawn_pos() -> Vector2:
	if LayoutStore.last_spawn is Vector2:
		var saved: Vector2 = LayoutStore.last_spawn
		return saved
	if _world:
		var marker = _world.get("spawn_marker")
		if marker is Vector2:
			var marker_pos: Vector2 = marker
			return marker_pos
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and _world:
		return _world.to_local((player as Node2D).global_position)
	return _screen_to_world(get_viewport().get_visible_rect().size * 0.5)


func _set_whitebox_spawn_marker_visible(visible: bool) -> void:
	if _world == null:
		return
	var current = _world.get("show_spawn_marker")
	if current is bool:
		_world.set("show_spawn_marker", visible)


func _set_whitebox_room_outline(visible: bool) -> void:
	if _world == null:
		return
	var current = _world.get("show_room_outline")
	if current is bool:
		_world.set("show_room_outline", visible)


func _resolve_room_rect() -> Rect2:
	if LayoutStore.last_room is Rect2:
		var saved: Rect2 = LayoutStore.last_room
		return saved
	if _world:
		var origin = _world.get("room_origin")
		var size = _world.get("room_size")
		if size is Vector2:
			var o := Vector2.ZERO
			if origin is Vector2:
				o = origin
			var s: Vector2 = size
			return Rect2(o, s)
	return Rect2(Vector2.ZERO, Vector2(4000, 2400))


func _collect_doors() -> void:
	_doors.clear()
	_door_positions.clear()
	_door_scales.clear()
	_door_rotations.clear()
	_door_triggers.clear()
	_selected_door = ""
	for node in get_tree().get_nodes_in_group("level_door"):
		if not node is Node2D:
			continue
		var role := str(node.get("door_role"))
		if role.is_empty():
			continue
		var door := node as Node2D
		_doors[role] = door
		var pos: Vector2 = door.position
		var door_scale: Vector2 = door.scale
		var door_rotation := door.rotation_degrees
		var trig_pos := Vector2(150.0, -140.0)
		var trig_size := Vector2(200.0, 280.0)
		var current_offset = door.get("exit_area_offset")
		if current_offset is Vector2:
			trig_pos = current_offset
		var current_size = door.get("exit_area_size")
		if current_size is Vector2:
			trig_size = current_size
		if LayoutStore.last_doors is Dictionary:
			var saved = LayoutStore.last_doors.get(role)
			if saved is Dictionary:
				if saved.get("pos") is Vector2:
					var saved_pos: Vector2 = saved["pos"]
					pos = saved_pos
				if saved.get("scale") is Vector2:
					var saved_scale: Vector2 = saved["scale"]
					door_scale = saved_scale
				if saved.has("rotation"):
					door_rotation = float(saved["rotation"])
				if saved.get("trigger_pos") is Vector2:
					var saved_trig_pos: Vector2 = saved["trigger_pos"]
					trig_pos = saved_trig_pos
				if saved.get("trigger_size") is Vector2:
					var saved_trig_size: Vector2 = saved["trigger_size"]
					trig_size = saved_trig_size
			elif saved is Vector2:
				pos = saved
		door.position = pos
		door.scale = door_scale
		door.rotation_degrees = door_rotation
		if door.has_method("apply_exit_area"):
			door.apply_exit_area(trig_pos, trig_size)
		_door_positions[role] = pos
		_door_scales[role] = door_scale
		_door_rotations[role] = door_rotation
		_door_triggers[role] = {"pos": trig_pos, "size": trig_size}


func _door_data() -> Dictionary:
	var result := {}
	for role in _door_positions.keys():
		var trig := _door_trigger(role)
		result[role] = {
			"pos": _door_positions[role],
			"scale": _door_scales.get(role, Vector2.ONE),
			"rotation": float(_door_rotations.get(role, 0.0)),
			"trigger_pos": trig.get("pos", Vector2(150.0, -140.0)),
			"trigger_size": trig.get("size", Vector2(200.0, 280.0)),
		}
	return result


func _collect_exits() -> void:
	_exits.clear()
	_exit_rects.clear()
	_selected_exit = ""
	for node in get_tree().get_nodes_in_group("level_exit"):
		if not node is Node2D:
			continue
		var role := str(node.get("exit_role"))
		if role.is_empty():
			continue
		var trigger := node as Node2D
		var pos := trigger.position
		var size := Vector2(200, 280)
		var rotation := trigger.rotation_degrees
		var current_size = trigger.get("trigger_size")
		if current_size is Vector2:
			size = current_size
		if LayoutStore.last_exits is Dictionary:
			var saved = LayoutStore.last_exits.get(role)
			if saved is Dictionary:
				if saved.get("pos") is Vector2:
					pos = saved["pos"]
				if saved.get("size") is Vector2:
					size = saved["size"]
				if saved.has("rotation"):
					rotation = float(saved["rotation"])
		_exits[role] = trigger
		_exit_rects[role] = {"pos": pos, "size": size, "rotation": rotation}
		_apply_exit(role)


func _exit_data() -> Dictionary:
	return _exit_rects.duplicate(true)


func _resize_door_to(world: Vector2) -> void:
	if _door_drag_role.is_empty():
		return
	var node = _doors.get(_door_drag_role)
	if not node is Node2D:
		return
	var door := node as Node2D
	var local := door.to_local(_world.to_global(world))
	var new_scale := _door_origin_scale
	if _door_resize_handle == 0 or _door_resize_handle == 1:
		var handle_x := -DOOR_WIDTH * 0.5 if _door_resize_handle == 0 else DOOR_WIDTH * 0.5
		var sign_x := signf(_door_origin_scale.x)
		var ratio := local.x / handle_x
		var scale_x := clampf(ratio, DOOR_MIN_SCALE, DOOR_MAX_SCALE)
		if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
			var width := roundf(DOOR_WIDTH * scale_x / DOOR_WIDTH_SNAP) * DOOR_WIDTH_SNAP
			scale_x = clampf(width / DOOR_WIDTH, DOOR_MIN_SCALE, DOOR_MAX_SCALE)
		new_scale.x = sign_x * scale_x
	else:
		var sign_y := signf(_door_origin_scale.y)
		if sign_y == 0.0:
			sign_y = 1.0
		var ratio := local.y / -DOOR_LOCAL_HEIGHT
		var scale_y := clampf(ratio, DOOR_MIN_SCALE, DOOR_MAX_SCALE)
		if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
			var height := roundf(DOOR_LOCAL_HEIGHT * scale_y / DOOR_HEIGHT_SNAP) * DOOR_HEIGHT_SNAP
			scale_y = clampf(height / DOOR_LOCAL_HEIGHT, DOOR_MIN_SCALE, DOOR_MAX_SCALE)
		new_scale.y = sign_y * scale_y
	_begin_change()
	_door_scales[_door_drag_role] = new_scale
	door.scale = new_scale
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


func _rotate_door_to(world: Vector2) -> void:
	if _door_drag_role.is_empty():
		return
	var node = _doors.get(_door_drag_role)
	if not node is Node2D:
		return
	var door := node as Node2D
	var dir := _world.to_global(world) - door.global_position
	if dir.length_squared() < 1.0:
		return
	var angle := rad_to_deg(atan2(dir.y, dir.x)) + 90.0
	if _snap_enabled and not Input.is_key_pressed(KEY_ALT):
		angle = roundf(angle / ROTATE_SNAP) * ROTATE_SNAP
	angle = wrapf(angle, -180.0, 180.0)
	_begin_change()
	_door_rotations[_door_drag_role] = angle
	door.rotation_degrees = angle
	_dirty = true
	_update_status()
	_canvas.queue_redraw()


func _zoom_at(screen: Vector2, factor: float) -> void:
	if _edit_camera == null:
		return
	var before := get_viewport().get_canvas_transform().affine_inverse() * screen
	var zoom_level := clampf(_edit_camera.zoom.x * factor, 0.35, 3.0)
	_edit_camera.zoom = Vector2(zoom_level, zoom_level)
	_edit_camera.force_update_scroll()
	var after := get_viewport().get_canvas_transform().affine_inverse() * screen
	_edit_camera.position += before - after
	_edit_camera.force_update_scroll()


# ---------------------------------------------------------------- 场景碰撞体扫描

## 把场景里已有的静态碰撞体转换成 F4 的多边形条目，避免重复建一份碰撞。
func _collect_scene_colliders() -> int:
	if _scene == null or _world == null:
		return 0
	var existing := {}
	for item in items:
		if str(item.get("type", "")) != "scene":
			continue
		var meta = item.get("meta", {})
		if meta is Dictionary:
			existing[_scene_key_from_meta(meta)] = item
	var nodes: Array[Node] = []
	nodes.append_array(_scene.find_children("*", "CollisionShape2D", true, false))
	nodes.append_array(_scene.find_children("*", "CollisionPolygon2D", true, false))
	var collected: Array[Dictionary] = []
	for node in nodes:
		if not _is_editable_scene_collision(node):
			continue
		var key := _scene_key(node)
		if existing.has(key):
			var saved: Dictionary = existing[key]
			if _scene_item_disabled(saved):
				LayoutStore.apply_scene_item(saved)
			continue
		var item := _scene_collider_item(node, key)
		if not item.is_empty():
			collected.append(item)
	if collected.is_empty():
		return 0
	var used := {}
	for item in items:
		used[str(item.get("id", ""))] = true
	var counter := 1
	for item in collected:
		while used.has("s_%d" % counter):
			counter += 1
		item["id"] = "s_%d" % counter
		used[item["id"]] = true
		counter += 1
	var merged: Array[Dictionary] = []
	merged.append_array(collected)
	merged.append_array(items)
	items = merged
	return collected.size()


func _is_editable_scene_collision(node: Node) -> bool:
	var body := node.get_parent()
	if not body is StaticBody2D:
		return false
	if body.has_meta("layout_id"):
		return false
	if _ancestor_in_group(node, ["layout_item", "level_door", "level_exit", "player", "enemies"]):
		return false
	if body is CollisionObject2D and (body as CollisionObject2D).collision_layer == 0:
		return false
	if node is CollisionShape2D:
		var collider := node as CollisionShape2D
		return not collider.disabled and collider.shape != null
	if node is CollisionPolygon2D:
		var polygon := node as CollisionPolygon2D
		return not polygon.disabled and polygon.polygon.size() >= 3
	return false


func _ancestor_in_group(node: Node, groups: Array) -> bool:
	var current := node
	while current != null:
		for group in groups:
			if current.is_in_group(str(group)):
				return true
		if current == _scene:
			break
		current = current.get_parent()
	return false


func _scene_collider_item(node: Node, key: String) -> Dictionary:
	var world_points := _scene_collision_points(node)
	if world_points.size() < 3:
		return {}
	var bounds := Rect2(world_points[0], Vector2.ZERO)
	for point in world_points:
		bounds = bounds.expand(point)
	var center := bounds.get_center()
	var local_points: Array[Vector2] = []
	for point in world_points:
		local_points.append(point - center)
	var body := node.get_parent()
	var item := _new_item("scene", center, bounds.size, "polygon")
	item["name"] = _scene_collider_name(body)
	item["points"] = local_points
	item["group"] = ""
	item["mask"] = 0
	item["purpose"] = ""
	if body is CollisionObject2D:
		item["layer"] = int((body as CollisionObject2D).collision_layer)
	item["meta"] = {
		"scene_idx": _scene_indices(node),
		"scene_key": key,
		"disabled": false,
	}
	return item


func _scene_collider_name(body: Node) -> String:
	var raw := str(body.name)
	if raw.is_empty() or raw.begins_with("@"):
		var parent := body.get_parent()
		raw = str(parent.name) if parent != null else "Scene"
	return "场景 %s #%d" % [raw, body.get_index()]


func _scene_indices(node: Node) -> Array[int]:
	var indices: Array[int] = []
	var current := node
	while current != null and current != _scene:
		indices.push_front(current.get_index())
		current = current.get_parent()
	return indices


func _scene_key(node: Node) -> String:
	var parts: Array[String] = []
	for index in _scene_indices(node):
		parts.append(str(index))
	return "/".join(parts)


func _scene_key_from_meta(meta: Dictionary) -> String:
	var raw = meta.get("scene_idx", [])
	if not raw is Array:
		return ""
	var parts: Array[String] = []
	for value in raw:
		parts.append(str(int(value)))
	return "/".join(parts)


func _scene_collision_points(node: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var xform := (node as Node2D).global_transform
	if node is CollisionPolygon2D:
		for point in (node as CollisionPolygon2D).polygon:
			result.append(_global_to_world_point(xform * point))
		return result
	var shape := (node as CollisionShape2D).shape
	if shape is RectangleShape2D:
		var half := (shape as RectangleShape2D).size * 0.5
		for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
			result.append(_global_to_world_point(xform * corner))
	elif shape is CircleShape2D:
		var radius := (shape as CircleShape2D).radius
		for i in 24:
			var angle := TAU * float(i) / 24.0
			result.append(_global_to_world_point(xform * (Vector2(cos(angle), sin(angle)) * radius)))
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var half_height := maxf(0.0, capsule.height * 0.5 - capsule.radius)
		for i in 9:
			var angle := PI + PI * float(i) / 8.0
			result.append(_global_to_world_point(xform * (Vector2(0, -half_height) + Vector2(cos(angle), sin(angle)) * capsule.radius)))
		for i in 9:
			var angle := PI * float(i) / 8.0
			result.append(_global_to_world_point(xform * (Vector2(0, half_height) + Vector2(cos(angle), sin(angle)) * capsule.radius)))
	elif shape is ConvexPolygonShape2D:
		for point in (shape as ConvexPolygonShape2D).points:
			result.append(_global_to_world_point(xform * point))
	elif shape is ConcavePolygonShape2D:
		var segments: PackedVector2Array = (shape as ConcavePolygonShape2D).segments
		var raw: Array[Vector2] = []
		for point in segments:
			raw.append(xform * point)
		if raw.size() >= 3:
			var hull := Geometry2D.convex_hull(PackedVector2Array(raw))
			for point in hull:
				result.append(_global_to_world_point(point))
			if result.size() > 1 and result[0].distance_to(result[result.size() - 1]) < 0.01:
				result.remove_at(result.size() - 1)
	return result


func _global_to_world_point(global_point: Vector2) -> Vector2:
	if _world == null:
		return global_point
	return _world.to_local(global_point)


func _scene_item_disabled(item: Dictionary) -> bool:
	if str(item.get("type", "")) != "scene":
		return false
	var meta = item.get("meta", {})
	return meta is Dictionary and bool(meta.get("disabled", false))


func _apply_scene_geometry(item: Dictionary) -> void:
	if str(item.get("type", "")) == "scene":
		LayoutStore.apply_scene_item(item)


func _apply_all_scene_geometry() -> void:
	for item in items:
		if str(item.get("type", "")) == "scene":
			LayoutStore.apply_scene_item(item)


# ---------------------------------------------------------------- 杂项

func _new_item(type: String, pos: Vector2, size: Vector2, shape := "rect") -> Dictionary:
	var prefix := "c"
	if shape == "arc":
		prefix = "a"
	elif shape == "bezier":
		prefix = "b"
	elif shape == "polygon":
		prefix = "p"
	return {
		"id": _next_id(prefix),
		"type": type,
		"shape": shape,
		"name": "Wall" if type == "collider" else "Trigger",
		"pos": pos,
		"size": size,
		"points": [
			Vector2(-256, 96), Vector2(-96, -128), Vector2(96, -128), Vector2(256, 96)
		],
		"layer": 1 if type == "collider" else 0,
		"mask": 0 if type == "collider" else 4,
		"rotation": 0.0,
		"radius_x": 240.0,
		"radius_y": 240.0,
		"thickness": 48.0,
		"start_angle": 0.0,
		"end_angle": 90.0,
		"arc_rotation": 0.0,
		"clockwise": true,
		"segments": 0,
		"one_way": false,
		"group": "" if type == "collider" else "triggers",
		"purpose": "" if type == "collider" else "generic",
		"meta": {},
	}


func _next_id(prefix: String) -> String:
	var best := 1
	for item in items:
		var id := str(item.get("id", ""))
		if id.begins_with(prefix + "_"):
			best = maxi(best, int(id.substr(prefix.length() + 1)) + 1)
	return "%s_%d" % [prefix, best]


func _clone_items(source: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in source:
		if entry is Dictionary:
			out.append((entry as Dictionary).duplicate(true))
	return out


func _rect_from_points(a: Vector2, b: Vector2) -> Rect2:
	var top_left := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var bottom_right := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return Rect2(top_left, bottom_right - top_left)


func _snap_point(value: Vector2) -> Vector2:
	if not _snap_enabled or Input.is_key_pressed(KEY_ALT):
		return value
	return Vector2(roundf(value.x / SNAP) * SNAP, roundf(value.y / SNAP) * SNAP)


func _normalize_angle(value: float) -> float:
	return fposmod(value + 180.0, 360.0) - 180.0


func _text_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit or focused is SpinBox


func _update_status() -> void:
	if not active:
		return
	var scene_name := ""
	if _scene:
		scene_name = _scene.scene_file_path.get_file().get_basename()
	var text := "LAYOUT MODE   %s%s" % [scene_name.to_upper(), "   ● 未保存" if _dirty else ""]
	if _mode == "room":
		text += "   ROOM %d × %d" % [roundi(_room_rect.size.x), roundi(_room_rect.size.y)]
	elif _mode == "map":
		var map_item := _map_item()
		if not map_item.is_empty():
			var map_size: Vector2 = map_item.get("size", Vector2.ZERO)
			text += "   MAP %d × %d" % [roundi(map_size.x), roundi(map_size.y)]
	elif _mode == "select" and not _selected_exit.is_empty():
		var exit_data := _exit_rect(_selected_exit)
		var exit_size: Vector2 = exit_data.get("size", Vector2.ZERO)
		var exit_label := "IN" if _selected_exit == "entrance" else "OUT"
		text += "   %s ZONE  %d × %d  %d°" % [
			exit_label,
			roundi(exit_size.x),
			roundi(exit_size.y),
			roundi(float(exit_data.get("rotation", 0.0))),
		]
	elif _mode == "select" and not _selected_door.is_empty():
		var door_scale: Vector2 = _door_scales.get(_selected_door, Vector2.ONE)
		var door_label := "IN" if _selected_door == "entrance" else "OUT"
		text += "   DOOR %s  %d%% × %d%%  %d°" % [
			door_label,
			roundi(absf(door_scale.x) * 100.0),
			roundi(absf(door_scale.y) * 100.0),
			roundi(float(_door_rotations.get(_selected_door, 0.0))),
		]
		var trig := _door_trigger(_selected_door)
		var trig_size: Vector2 = trig.get("size", Vector2.ZERO)
		text += "   TRIG %d × %d" % [roundi(trig_size.x), roundi(trig_size.y)]
	_status.text = text


func _toast_msg(text: String) -> void:
	if not active:
		return
	_toast.text = text
	_toast_time = 2.2
	_toast.modulate.a = 1.0
