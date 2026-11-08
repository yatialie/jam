extends Node

## 关卡布局数据层：按场景读写 JSON，并把碰撞体 / 触发区实例化到 World 节点下。
## 没有对应 JSON 的场景不会产生任何节点，现有场景行为完全不变。

const LAYOUT_DIR := "res://level_layouts"
const USER_LAYOUT_DIR := "user://level_layouts"
const ITEM_GROUP := "layout_item"
const VERSION := 1

var items: Array[Dictionary] = []
var world: Node2D
var scene_path := ""
var spawn_point: Variant = null
var last_spawn: Variant = null
var room_rect: Variant = null
var last_room: Variant = null
var doors: Dictionary = {}
var last_doors: Variant = null
var exits: Dictionary = {}
var last_exits: Variant = null

var _spawned: Array[Node] = []
var _scene_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var id := scene.get_instance_id()
	if id == _scene_id:
		return
	_scene_id = id
	_reload_for_scene(scene)


func _reload_for_scene(scene: Node) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scene) or get_tree().current_scene != scene:
		return
	clear_spawned()
	world = find_world(scene)
	scene_path = scene.scene_file_path
	if world == null:
		items = []
		return
	items = load_items(scene_path)
	spawn_point = last_spawn
	room_rect = last_room
	doors = last_doors if last_doors is Dictionary else {}
	exits = last_exits if last_exits is Dictionary else {}
	_spawn_all()


func find_world(scene: Node = null) -> Node2D:
	if scene == null:
		scene = get_tree().current_scene
	if scene == null:
		return null
	var grouped := get_tree().get_first_node_in_group("layout_world")
	if grouped is Node2D:
		return grouped as Node2D
	var node := scene.find_child("World", true, false)
	if node is Node2D:
		return node as Node2D
	if scene is Node2D:
		return scene as Node2D
	return null


func get_items_for(p_scene_path: String) -> Array[Dictionary]:
	if p_scene_path == scene_path:
		return _clone(items)
	return load_items(p_scene_path)


func load_items(p_scene_path: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	last_spawn = null
	last_room = null
	last_doors = null
	last_exits = null
	if p_scene_path.is_empty():
		return result
	for dir in [LAYOUT_DIR, USER_LAYOUT_DIR]:
		var file := _layout_file(dir, p_scene_path)
		if not FileAccess.file_exists(file):
			continue
		var f := FileAccess.open(file, FileAccess.READ)
		if f == null:
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if not parsed is Dictionary:
			continue
		var data: Dictionary = parsed
		var stored_scene := str(data.get("scene", ""))
		if not stored_scene.is_empty() and stored_scene != p_scene_path:
			continue
		last_spawn = _vec_or_null(data.get("spawn"))
		last_room = _rect_or_null(data.get("room"))
		last_doors = _doors_or_null(data.get("doors"))
		last_exits = _exits_or_null(data.get("exits"))
		var raw = data.get("items", [])
		if raw is Array:
			for entry in raw:
				if entry is Dictionary:
					result.append(_normalize_item(entry))
		return result
	return result


## 返回实际写入的文件路径，失败返回空字符串。
func save_items(p_scene_path: String, p_items: Array[Dictionary], p_spawn: Variant = null, p_room: Variant = null, p_doors: Variant = null, p_exits: Variant = null) -> String:
	if p_scene_path.is_empty():
		return ""
	var payload := {
		"version": VERSION,
		"scene": p_scene_path,
		"world_path": _world_path(),
		"items": _serialize(p_items),
	}
	if p_spawn is Vector2:
		var spawn: Vector2 = p_spawn
		payload["spawn"] = [spawn.x, spawn.y]
	if p_room is Rect2:
		var room: Rect2 = p_room
		payload["room"] = [room.position.x, room.position.y, room.size.x, room.size.y]
	if p_doors is Dictionary:
		var door_data := _serialize_doors(p_doors)
		if not door_data.is_empty():
			payload["doors"] = door_data
	if p_exits is Dictionary:
		var exit_data := _serialize_exits(p_exits)
		if not exit_data.is_empty():
			payload["exits"] = exit_data
	var text := JSON.stringify(payload, "\t", false)
	for dir in [LAYOUT_DIR, USER_LAYOUT_DIR]:
		if not _ensure_dir(dir):
			continue
		var file := _layout_file(dir, p_scene_path)
		var f := FileAccess.open(file, FileAccess.WRITE)
		if f == null:
			continue
		f.store_string(text)
		f.close()
		items = _clone(p_items)
		if p_spawn is Vector2:
			spawn_point = p_spawn
		if p_room is Rect2:
			room_rect = p_room
		if p_doors is Dictionary:
			doors = p_doors.duplicate(true)
		if p_exits is Dictionary:
			exits = p_exits.duplicate(true)
		last_spawn = spawn_point
		last_room = room_rect
		last_doors = doors.duplicate(true) if not doors.is_empty() else null
		last_exits = exits.duplicate(true) if not exits.is_empty() else null
		return file
	return ""


func apply_items(p_items: Array[Dictionary], p_spawn: Variant = null, p_room: Variant = null, p_doors: Variant = null, p_exits: Variant = null) -> void:
	if p_spawn is Vector2:
		spawn_point = p_spawn
	if p_room is Rect2:
		room_rect = p_room
	if p_doors is Dictionary:
		doors = p_doors.duplicate(true)
		last_doors = doors.duplicate(true)
	if p_exits is Dictionary:
		exits = p_exits.duplicate(true)
		last_exits = exits.duplicate(true)
	items = _clone(p_items)
	clear_spawned()
	_spawn_all()


func set_preview_hidden(hidden: bool) -> void:
	for node in _spawned:
		if is_instance_valid(node) and node is CanvasItem:
			(node as CanvasItem).visible = not hidden


func clear_spawned() -> void:
	for node in _spawned:
		if not is_instance_valid(node):
			continue
		var parent := node.get_parent()
		if parent:
			parent.remove_child(node)
		node.queue_free()
	_spawned.clear()


func _spawn_all() -> void:
	if world == null:
		return
	for item in items:
		_spawn_item(item)
	_apply_scene_items()
	_apply_room()
	_apply_doors()
	_apply_exits()
	_apply_spawn()


## 场景自带碰撞体的编辑覆盖：F4 里改过的多边形重新写回原节点。
func _apply_scene_items() -> void:
	for item in items:
		if str(item.get("type", "")) == "scene":
			apply_scene_item(item)


## 把一条场景碰撞体数据应用到对应节点，成功返回 true。
func apply_scene_item(item: Dictionary) -> bool:
	if str(item.get("type", "")) != "scene":
		return false
	var meta = item.get("meta", {})
	if not meta is Dictionary:
		return false
	var node := _resolve_scene_collision(meta)
	if node == null:
		return false
	var disabled := bool(meta.get("disabled", false))
	if node is CollisionShape2D:
		var collider := node as CollisionShape2D
		collider.set_deferred("disabled", disabled)
		if disabled:
			return true
		var points := _scene_item_local_points(item, collider)
		if points.size() < 3:
			return false
		var shape := ConvexPolygonShape2D.new()
		shape.points = PackedVector2Array(points)
		collider.shape = shape
		return true
	if node is CollisionPolygon2D:
		var polygon := node as CollisionPolygon2D
		polygon.set_deferred("disabled", disabled)
		if disabled:
			return true
		var points := _scene_item_local_points(item, polygon)
		if points.size() < 3:
			return false
		polygon.polygon = PackedVector2Array(points)
		return true
	return false


## 通过子节点索引链定位碰撞节点，避免运行时自动命名导致的路径不稳定。
func _resolve_scene_collision(meta: Dictionary) -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var indices = meta.get("scene_idx", [])
	if not indices is Array:
		return null
	var node: Node = scene
	for value in indices:
		var index := int(value)
		if index < 0 or index >= node.get_child_count():
			return null
		node = node.get_child(index)
	return node


func _scene_item_local_points(item: Dictionary, node: Node2D) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if world == null:
		return result
	var pos: Vector2 = item.get("pos", Vector2.ZERO)
	var raw = item.get("points", [])
	if not raw is Array:
		return result
	for entry in raw:
		var offset := _vec(entry, Vector2.ZERO)
		var global_point := world.to_global(pos + offset)
		result.append(node.to_local(global_point))
	return result


func _apply_room() -> void:
	if room_rect is Rect2:
		var rect: Rect2 = room_rect
		var level := get_tree().current_scene
		if level != null and level.has_method("apply_room"):
			level.apply_room(rect.position, rect.size)
		elif world != null:
			world.set("room_origin", rect.position)
			world.set("room_size", rect.size)
			world.queue_redraw()
	if world != null:
		var show := true
		var tool = get_node_or_null("/root/LayoutTool")
		if tool != null and bool(tool.get("active")):
			show = false
		var outline_visible = world.get("show_room_outline")
		if outline_visible is bool:
			world.set("show_room_outline", show)


func _apply_doors() -> void:
	if doors.is_empty():
		return
	for node in get_tree().get_nodes_in_group("level_door"):
		if not node is Node2D:
			continue
		var role := str(node.get("door_role"))
		if not doors.has(role):
			continue
		var door := node as Node2D
		var entry = doors[role]
		if entry is Dictionary:
			var data: Dictionary = entry
			if data.get("pos") is Vector2:
				var door_pos: Vector2 = data["pos"]
				door.position = door_pos
			if data.get("scale") is Vector2:
				var door_scale: Vector2 = data["scale"]
				door.scale = door_scale
			if data.has("rotation"):
				door.rotation_degrees = float(data["rotation"])
			var trigger_pos = data.get("trigger_pos")
			var trigger_size = data.get("trigger_size")
			if trigger_pos is Vector2 and trigger_size is Vector2 and door.has_method("apply_exit_area"):
				door.apply_exit_area(trigger_pos, trigger_size)
		elif entry is Vector2:
			door.position = entry


## 换场触发区：把 F4 保存的位置 / 尺寸 / 旋转写回场景里的 Area2D。
func _apply_exits() -> void:
	if exits.is_empty():
		return
	for node in get_tree().get_nodes_in_group("level_exit"):
		if not node is Node2D:
			continue
		var role := str(node.get("exit_role"))
		if not exits.has(role):
			continue
		var entry = exits[role]
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var center = data.get("pos")
		var size = data.get("size")
		var rotation := float(data.get("rotation", 0.0))
		if center is Vector2 and size is Vector2 and node.has_method("apply_trigger"):
			node.call("apply_trigger", center, size, rotation)


func _apply_spawn() -> void:
	if world == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	var has_spawn := spawn_point is Vector2
	if has_spawn:
		var spawn: Vector2 = spawn_point
		if player is Node2D:
			(player as Node2D).global_position = world.to_global(spawn)
		var marker = world.get("spawn_marker")
		if marker is Vector2:
			world.set("spawn_marker", spawn)
	var should_show := not has_spawn
	var tool = get_node_or_null("/root/LayoutTool")
	if tool != null and bool(tool.get("active")):
		should_show = false
	var marker_visible = world.get("show_spawn_marker")
	if marker_visible is bool:
		world.set("show_spawn_marker", should_show)


func _spawn_item(item: Dictionary) -> void:
	var type := str(item.get("type", "collider"))
	if type == "spawn" or type == "scene":
		return
	if type == "map":
		_spawn_map(item)
		return
	var body: CollisionObject2D
	if type == "trigger":
		body = Area2D.new()
	else:
		body = StaticBody2D.new()
	body.name = _node_name(item)
	body.position = _vec(item.get("pos"), Vector2.ZERO)
	body.collision_layer = int(item.get("layer", 1))
	body.collision_mask = int(item.get("mask", 0))

	if body is Area2D:
		var area := body as Area2D
		area.monitoring = true
		area.monitorable = true
		var group := str(item.get("group", ""))
		if not group.is_empty():
			area.add_to_group(group)
		area.set_meta("purpose", str(item.get("purpose", "generic")))

	var meta: Dictionary = item.get("meta", {})
	for key in meta.keys():
		body.set_meta(str(key), meta[key])

	var shape_kind := str(item.get("shape", "rect"))
	if shape_kind == "arc":
		_build_arc_shapes(body, item)
	elif shape_kind == "bezier":
		_build_bezier_shapes(body, item)
	elif shape_kind == "polygon":
		_build_polygon_shapes(body, item)
	else:
		var size := _vec(item.get("size"), Vector2(384, 60))
		var angle := float(item.get("rotation", 0.0))
		var collider := CollisionShape2D.new()
		collider.name = "Shape"
		if absf(angle) > 0.001:
			# 斜面用多边形表示，避免旋转节点在非等比投影下产生变换误差
			var half := size * 0.5
			var rad := deg_to_rad(angle)
			var polygon := ConvexPolygonShape2D.new()
			polygon.points = PackedVector2Array([
				Vector2(-half.x, -half.y).rotated(rad),
				Vector2(half.x, -half.y).rotated(rad),
				Vector2(half.x, half.y).rotated(rad),
				Vector2(-half.x, half.y).rotated(rad),
			])
			collider.shape = polygon
		else:
			var shape := RectangleShape2D.new()
			shape.size = size
			collider.shape = shape
		collider.one_way_collision = bool(item.get("one_way", false))
		body.add_child(collider)

	body.add_to_group(ITEM_GROUP)
	body.set_meta("layout_id", str(item.get("id", "")))
	body.set_meta("layout_type", type)
	world.add_child(body)
	_spawned.append(body)


## 地图背景：按布局数据实例化一张可缩放的贴图，绘制在白盒地面之上、门与角色之下。
func _spawn_map(item: Dictionary) -> void:
	var texture_path := str(item.get("texture", ""))
	if texture_path.is_empty():
		return
	var texture: Texture2D = load(texture_path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = _node_name(item)
	sprite.texture = texture
	sprite.position = _vec(item.get("pos"), Vector2.ZERO)
	sprite.rotation_degrees = float(item.get("rotation", 0.0))
	var texture_size := texture.get_size()
	var size := _vec(item.get("size"), texture_size)
	if bool(item.get("repeat", false)):
		# 平铺模式：按世界尺寸重复采样，适合星空等可延展底图
		sprite.centered = true
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, size)
		sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	elif texture_size.x > 0.0 and texture_size.y > 0.0:
		sprite.scale = Vector2(size.x / texture_size.x, size.y / texture_size.y)
	sprite.z_index = int(item.get("z", 1))
	sprite.add_to_group(ITEM_GROUP)
	sprite.set_meta("layout_id", str(item.get("id", "")))
	sprite.set_meta("layout_type", "map")
	world.add_child(sprite)
	_spawned.append(sprite)


func _build_arc_shapes(body: CollisionObject2D, item: Dictionary) -> void:
	var legacy := clampf(float(item.get("radius", 240.0)), 8.0, 8192.0)
	var radius_x := clampf(float(item.get("radius_x", legacy)), 8.0, 8192.0)
	var radius_y := clampf(float(item.get("radius_y", legacy)), 8.0, 8192.0)
	var thickness := clampf(float(item.get("thickness", 48.0)), 4.0, 4096.0)
	var inner_x := maxf(radius_x - thickness * 0.5, 1.0)
	var inner_y := maxf(radius_y - thickness * 0.5, 1.0)
	var outer_x := radius_x + thickness * 0.5
	var outer_y := radius_y + thickness * 0.5
	var start_deg := float(item.get("start_angle", 0.0))
	var clockwise := bool(item.get("clockwise", true))
	var span_deg := _arc_span_degrees(start_deg, float(item.get("end_angle", 90.0)), clockwise)
	var direction := 1.0 if clockwise else -1.0
	var rotation := deg_to_rad(float(item.get("arc_rotation", 0.0)))
	var segments := int(item.get("segments", 0))
	if segments <= 0:
		segments = clampi(int(ceil(span_deg / 12.0)), 4, 64)
	else:
		segments = clampi(segments, 4, 128)
	for i in segments:
		var a0 := deg_to_rad(start_deg + direction * span_deg * float(i) / float(segments))
		var a1 := deg_to_rad(start_deg + direction * span_deg * float(i + 1) / float(segments))
		var o0 := Vector2(cos(a0) * outer_x, sin(a0) * outer_y).rotated(rotation)
		var o1 := Vector2(cos(a1) * outer_x, sin(a1) * outer_y).rotated(rotation)
		var i1 := Vector2(cos(a1) * inner_x, sin(a1) * inner_y).rotated(rotation)
		var i0 := Vector2(cos(a0) * inner_x, sin(a0) * inner_y).rotated(rotation)
		var polygon := ConvexPolygonShape2D.new()
		polygon.points = PackedVector2Array([o0, o1, i1, i0])
		var collider := CollisionShape2D.new()
		collider.name = "Arc%d" % i
		collider.shape = polygon
		body.add_child(collider)


func _arc_span_degrees(start_deg: float, end_deg: float, clockwise: bool) -> float:
	var span := fposmod(end_deg - start_deg, 360.0) if clockwise else fposmod(start_deg - end_deg, 360.0)
	if span <= 0.001:
		span = 360.0
	return span


func _build_bezier_shapes(body: CollisionObject2D, item: Dictionary) -> void:
	var points := _bezier_points(item)
	var thickness := clampf(float(item.get("thickness", 48.0)), 4.0, 4096.0)
	var segments := _bezier_segments(item, points)
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var point := _bezier_sample(points, t)
		var tangent := _bezier_tangent(points, t)
		if tangent.length_squared() < 0.0001:
			tangent = Vector2.RIGHT
		var normal := Vector2(-tangent.y, tangent.x).normalized() * thickness * 0.5
		outer.append(point + normal)
		inner.append(point - normal)
	for i in segments:
		var polygon := ConvexPolygonShape2D.new()
		polygon.points = PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
		var collider := CollisionShape2D.new()
		collider.name = "Bezier%d" % i
		collider.shape = polygon
		body.add_child(collider)


func _bezier_points(item: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var raw = item.get("points", [])
	if raw is Array:
		for entry in raw:
			result.append(_vec(entry, Vector2.ZERO))
	if result.is_empty():
		result = [
			Vector2(-256, 96), Vector2(-96, -128), Vector2(96, -128), Vector2(256, 96)
		]
	while result.size() < 4:
		result.append(result.back())
	if result.size() > 4:
		result.resize(4)
	return result


func _bezier_segments(item: Dictionary, points: Array[Vector2]) -> int:
	var user_segments := int(item.get("segments", 0))
	if user_segments > 0:
		return clampi(user_segments, 8, 128)
	var approx := points[0].distance_to(points[1]) + points[1].distance_to(points[2]) + points[2].distance_to(points[3])
	return clampi(int(ceil(approx / 24.0)), 8, 96)


func _bezier_sample(points: Array[Vector2], t: float) -> Vector2:
	var u := 1.0 - t
	return points[0] * (u * u * u) + points[1] * (3.0 * u * u * t) + points[2] * (3.0 * u * t * t) + points[3] * (t * t * t)


func _bezier_tangent(points: Array[Vector2], t: float) -> Vector2:
	var u := 1.0 - t
	return (points[1] - points[0]) * (3.0 * u * u) + (points[2] - points[1]) * (6.0 * u * t) + (points[3] - points[2]) * (3.0 * t * t)


func _build_polygon_shapes(body: CollisionObject2D, item: Dictionary) -> void:
	var points := _polygon_points(item)
	var polygon := CollisionPolygon2D.new()
	polygon.name = "Polygon"
	polygon.polygon = PackedVector2Array(points)
	polygon.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	body.add_child(polygon)


func _polygon_points(item: Dictionary) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var raw = item.get("points", [])
	if raw is Array:
		for entry in raw:
			result.append(_vec(entry, Vector2.ZERO))
	if result.size() < 3:
		result = _default_polygon_points()
	return result


func _default_polygon_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in 6:
		var angle := -PI * 0.5 + TAU * float(i) / 6.0
		result.append(Vector2(cos(angle), sin(angle)) * 180.0)
	return result


func _normalize_item(entry: Dictionary) -> Dictionary:
	var type := str(entry.get("type", "collider"))
	var default_size := Vector2(384, 60) if type == "collider" else Vector2(240, 160)
	var raw_meta = entry.get("meta", {})
	var legacy_radius := float(entry.get("radius", 240.0))
	var default_name := "Wall" if type == "collider" else ("Trigger" if type == "trigger" else ("SceneCollider" if type == "scene" else "Map"))
	var shape_value := str(entry.get("shape", "rect"))
	var points: Array[Vector2] = []
	var raw_points = entry.get("points", [])
	if raw_points is Array:
		for point in raw_points:
			points.append(_vec(point, Vector2.ZERO))
	if shape_value == "bezier":
		if points.is_empty():
			points = [
				Vector2(-256, 96), Vector2(-96, -128), Vector2(96, -128), Vector2(256, 96)
			]
		while points.size() < 4:
			points.append(points.back())
		if points.size() > 4:
			points.resize(4)
	elif shape_value == "polygon" and points.size() < 3:
		points = _default_polygon_points()
	return {
		"id": str(entry.get("id", "")),
		"type": type,
		"shape": shape_value,
		"name": str(entry.get("name", default_name)),
		"texture": str(entry.get("texture", "")),
		"z": int(entry.get("z", 1)),
		"repeat": bool(entry.get("repeat", false)),
		"pos": _vec(entry.get("pos"), Vector2.ZERO),
		"size": _vec(entry.get("size"), default_size),
		"points": points,
		"layer": int(entry.get("layer", 1 if type == "collider" else 0)),
		"mask": int(entry.get("mask", 0 if type == "collider" else 4)),
		"rotation": float(entry.get("rotation", 0.0)),
		"radius_x": float(entry.get("radius_x", legacy_radius)),
		"radius_y": float(entry.get("radius_y", legacy_radius)),
		"thickness": float(entry.get("thickness", 48.0)),
		"start_angle": float(entry.get("start_angle", 0.0)),
		"end_angle": float(entry.get("end_angle", 90.0)),
		"arc_rotation": float(entry.get("arc_rotation", 0.0)),
		"clockwise": bool(entry.get("clockwise", true)),
		"segments": int(entry.get("segments", 0)),
		"one_way": bool(entry.get("one_way", false)),
		"group": str(entry.get("group", "" if type == "collider" else "triggers")),
		"purpose": str(entry.get("purpose", "" if type == "collider" else "generic")),
		"meta": raw_meta if raw_meta is Dictionary else {},
	}


func _serialize(p_items: Array[Dictionary]) -> Array:
	var out: Array = []
	for item in p_items:
		var pos: Vector2 = item.get("pos", Vector2.ZERO)
		var size: Vector2 = item.get("size", Vector2.ONE)
		var shape := str(item.get("shape", "rect"))
		var type := str(item.get("type", "collider"))
		var data := {
			"id": str(item.get("id", "")),
			"type": type,
			"shape": shape,
			"name": str(item.get("name", "")),
			"pos": [pos.x, pos.y],
			"size": [size.x, size.y],
			"layer": int(item.get("layer", 1)),
			"mask": int(item.get("mask", 0)),
			"rotation": float(item.get("rotation", 0.0)),
			"one_way": bool(item.get("one_way", false)),
			"group": str(item.get("group", "")),
			"purpose": str(item.get("purpose", "")),
			"meta": item.get("meta", {}),
		}
		if type == "map":
			data["texture"] = str(item.get("texture", ""))
			data["z"] = int(item.get("z", 1))
			data["repeat"] = bool(item.get("repeat", false))
		if shape == "arc":
			data["radius_x"] = float(item.get("radius_x", item.get("radius", 240.0)))
			data["radius_y"] = float(item.get("radius_y", item.get("radius", 240.0)))
			data["thickness"] = float(item.get("thickness", 48.0))
			data["start_angle"] = float(item.get("start_angle", 0.0))
			data["end_angle"] = float(item.get("end_angle", 90.0))
			data["arc_rotation"] = float(item.get("arc_rotation", 0.0))
			data["clockwise"] = bool(item.get("clockwise", true))
			data["segments"] = int(item.get("segments", 0))
		elif shape == "bezier":
			data["thickness"] = float(item.get("thickness", 48.0))
			data["segments"] = int(item.get("segments", 0))
			var point_data: Array = []
			for point in _bezier_points(item):
				point_data.append([point.x, point.y])
			data["points"] = point_data
		elif shape == "polygon":
			var point_data: Array = []
			for point in _polygon_points(item):
				point_data.append([point.x, point.y])
			data["points"] = point_data
		out.append(data)
	return out


func _clone(p_items: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in p_items:
		out.append(item.duplicate(true))
	return out


func _vec(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _vec_or_null(value) -> Variant:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return null


func _rect_or_null(value) -> Variant:
	if value is Array and value.size() >= 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))
	return null


func _doors_or_null(value) -> Variant:
	if not value is Dictionary:
		return null
	var result := {}
	for role in ["entrance", "exit"]:
		var entry = value.get(role)
		if entry is Array and entry.size() >= 2:
			result[role] = {"pos": Vector2(float(entry[0]), float(entry[1]))}
		elif entry is Dictionary:
			var data := {}
			var pos = _vec_or_null(entry.get("pos"))
			if pos is Vector2:
				data["pos"] = pos
			var scl = _vec_or_null(entry.get("scale"))
			if scl is Vector2:
				data["scale"] = scl
			if entry.has("rotation"):
				data["rotation"] = float(entry["rotation"])
			var trig_pos = _vec_or_null(entry.get("trigger_pos"))
			if trig_pos is Vector2:
				data["trigger_pos"] = trig_pos
			var trig_size = _vec_or_null(entry.get("trigger_size"))
			if trig_size is Vector2:
				data["trigger_size"] = trig_size
			if not data.is_empty():
				result[role] = data
	return result if not result.is_empty() else null


func _serialize_doors(p_doors: Dictionary) -> Dictionary:
	var result := {}
	for role in ["entrance", "exit"]:
		if not p_doors.has(role):
			continue
		var entry = p_doors[role]
		if entry is Dictionary:
			var data: Dictionary = entry
			var out := {}
			if data.get("pos") is Vector2:
				var pos: Vector2 = data["pos"]
				out["pos"] = [pos.x, pos.y]
			if data.get("scale") is Vector2:
				var scl: Vector2 = data["scale"]
				out["scale"] = [scl.x, scl.y]
			if data.has("rotation"):
				out["rotation"] = float(data["rotation"])
			if data.get("trigger_pos") is Vector2:
				var trig_pos: Vector2 = data["trigger_pos"]
				out["trigger_pos"] = [trig_pos.x, trig_pos.y]
			if data.get("trigger_size") is Vector2:
				var trig_size: Vector2 = data["trigger_size"]
				out["trigger_size"] = [trig_size.x, trig_size.y]
			if not out.is_empty():
				result[role] = out
		elif entry is Vector2:
			var pos: Vector2 = entry
			result[role] = [pos.x, pos.y]
	return result


func _exits_or_null(value) -> Variant:
	if not value is Dictionary:
		return null
	var result := {}
	for role in ["entrance", "exit"]:
		var entry = value.get(role)
		if not entry is Dictionary:
			continue
		var data := {}
		var pos = _vec_or_null(entry.get("pos"))
		if pos is Vector2:
			data["pos"] = pos
		var size = _vec_or_null(entry.get("size"))
		if size is Vector2:
			data["size"] = size
		if entry.has("rotation"):
			data["rotation"] = float(entry["rotation"])
		if data.has("pos") and data.has("size"):
			result[role] = data
	return result if not result.is_empty() else null


func _serialize_exits(p_exits: Dictionary) -> Dictionary:
	var result := {}
	for role in ["entrance", "exit"]:
		if not p_exits.has(role):
			continue
		var entry = p_exits[role]
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var out := {}
		if data.get("pos") is Vector2:
			var pos: Vector2 = data["pos"]
			out["pos"] = [pos.x, pos.y]
		if data.get("size") is Vector2:
			var size: Vector2 = data["size"]
			out["size"] = [size.x, size.y]
		if data.has("rotation"):
			out["rotation"] = float(data["rotation"])
		if not out.is_empty():
			result[role] = out
	return result


func _layout_file(dir: String, p_scene_path: String) -> String:
	var key := p_scene_path.get_file().get_basename()
	if key.is_empty():
		key = "untitled"
	return "%s/%s.json" % [dir, key]


func _world_path() -> String:
	var scene := get_tree().current_scene
	if scene and world and scene.is_ancestor_of(world):
		return str(scene.get_path_to(world))
	return ""


func _ensure_dir(dir: String) -> bool:
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		return true
	return DirAccess.make_dir_recursive_absolute(abs) == OK


func _node_name(item: Dictionary) -> String:
	var raw := str(item.get("name", "")).strip_edges()
	if raw.is_empty():
		var item_type := str(item.get("type", ""))
		raw = "Collider" if item_type == "collider" else ("Trigger" if item_type == "trigger" else "Map")
	for ch in [".", ":", "@", "/", "\"", "%"]:
		raw = raw.replace(ch, "_")
	return raw
