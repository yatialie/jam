extends Node2D


func _ready() -> void:
	z_index = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var shapes := get_tree().root.find_children("*", "CollisionShape2D", true, false)
	for node in shapes:
		var collider := node as CollisionShape2D
		if collider == null or collider.shape == null or collider.disabled:
			continue
		_draw_shape(collider.shape, collider.global_transform, _color_for(collider.get_parent()))

	var polygons := get_tree().root.find_children("*", "CollisionPolygon2D", true, false)
	for node in polygons:
		var polygon := node as CollisionPolygon2D
		if polygon == null or polygon.polygon.size() < 2:
			continue
		var points := PackedVector2Array()
		for point in polygon.polygon:
			points.append(polygon.global_transform * point)
		_outline(points, _color_for(polygon.get_parent()))

	_draw_patrol_zones()
	_draw_arm_zones()


func _draw_arm_zones() -> void:
	for node in get_tree().get_nodes_in_group("mech_arm"):
		if not node.has_method("get_arm_debug"):
			continue
		var reference := node as Node2D
		if reference == null:
			continue
		var data: Dictionary = node.call("get_arm_debug")
		var base: Vector2 = data["base"]
		var radius: float = data["claw_radius"]
		_ring(reference, base, data["reach"], Color(0.3, 0.9, 1.0, 0.65))
		_ring(reference, base, radius, Color(1.0, 0.82, 0.25, 0.7))
		_ring(reference, base, radius + 105.0, Color(1.0, 0.55, 0.2, 0.4))
		_ring(reference, base, radius - 105.0, Color(1.0, 0.55, 0.2, 0.4))
		_draw_arc_band(reference, base, radius, data["yaw"], deg_to_rad(data["arc_deg"]), Color(1.0, 0.35, 0.25, 0.85))
		var slam: Vector2 = data["slam_point"]
		_ring(reference, slam, data["slam_radius"], Color(1.0, 0.3, 0.22, 0.8))
		draw_circle(base, 7.0, Color(0.35, 1.0, 0.45, 0.95))
		draw_circle(slam, 5.0, Color(1.0, 0.4, 0.3, 0.95))


func _draw_arc_band(reference: Node2D, center_global: Vector2, radius: float, yaw: float, arc: float, color: Color) -> void:
	var parent := reference.get_parent() as Node2D
	if parent == null:
		return
	var center_local := parent.to_local(center_global)
	var points := PackedVector2Array()
	var half := arc * 0.5
	for i in 33:
		var t := float(i) / 32.0
		var angle := yaw - half + arc * t
		points.append(parent.to_global(center_local + Vector2(cos(angle), sin(angle)) * radius))
	_outline(points, color)


func _draw_patrol_zones() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not node.has_method("get_patrol_debug"):
			continue
		var data: Dictionary = node.call("get_patrol_debug")
		if not data.get("enabled", false):
			continue

		var reference := node as Node2D
		if reference == null:
			continue
		var anchor: Vector2 = data["anchor"]
		var target: Vector2 = data["target"]
		_ring(reference, anchor, data["patrol_radius"], Color(0.35, 1.0, 0.45, 0.8))
		_ring(reference, anchor, data["detection_radius"], Color(1.0, 0.85, 0.25, 0.55))
		_ring(reference, anchor, data["leash_radius"], Color(1.0, 0.35, 0.3, 0.5))
		draw_circle(anchor, 6.0, Color(0.35, 1.0, 0.45, 0.9))
		draw_circle(target, 4.0, Color(1.0, 0.85, 0.25, 0.9))


func _ring(reference: Node2D, center_global: Vector2, radius: float, color: Color) -> void:
	var parent := reference.get_parent() as Node2D
	var points := PackedVector2Array()
	if parent:
		var center_local := parent.to_local(center_global)
		for i in 40:
			var angle := TAU * float(i) / 40.0
			points.append(parent.to_global(center_local + Vector2(cos(angle), sin(angle)) * radius))
	else:
		for i in 40:
			var angle := TAU * float(i) / 40.0
			points.append(center_global + Vector2(cos(angle), sin(angle)) * radius)
	_outline(points, color)


func _color_for(parent: Node) -> Color:
	if parent is Area2D:
		return Color(0.35, 1.0, 0.45, 0.95)
	if parent is CharacterBody2D:
		return Color(0.2, 0.9, 1.0, 0.95)
	if parent is StaticBody2D:
		return Color(1.0, 0.65, 0.2, 0.95)
	return Color(1.0, 0.4, 1.0, 0.95)


func _draw_shape(shape: Shape2D, xform: Transform2D, color: Color) -> void:
	if shape is RectangleShape2D:
		var rect := shape as RectangleShape2D
		var half := rect.size / 2.0
		_outline(PackedVector2Array([
			xform * Vector2(-half.x, -half.y),
			xform * Vector2(half.x, -half.y),
			xform * Vector2(half.x, half.y),
			xform * Vector2(-half.x, half.y),
		]), color)
	elif shape is CircleShape2D:
		var circle := shape as CircleShape2D
		_circle(xform, circle.radius, color)
	elif shape is CapsuleShape2D:
		var capsule := shape as CapsuleShape2D
		var radius: float = capsule.radius
		var half_height: float = maxf(0.0, capsule.height / 2.0 - radius)
		var points := PackedVector2Array()
		# 上半圆
		for i in 13:
			var angle := PI + PI * float(i) / 12.0
			points.append(xform * (Vector2(0, -half_height) + Vector2(cos(angle), sin(angle)) * radius))
		# 下半圆
		for i in 13:
			var angle := PI * float(i) / 12.0
			points.append(xform * (Vector2(0, half_height) + Vector2(cos(angle), sin(angle)) * radius))
		_outline(points, color)
	elif shape is ConvexPolygonShape2D:
		var convex := shape as ConvexPolygonShape2D
		var points := PackedVector2Array()
		for point in convex.points:
			points.append(xform * point)
		_outline(points, color)
	elif shape is SegmentShape2D:
		var segment := shape as SegmentShape2D
		draw_line(xform * segment.a, xform * segment.b, color, 2.0)
	elif shape is ConcavePolygonShape2D:
		var concave := shape as ConcavePolygonShape2D
		var segments: PackedVector2Array = concave.segments
		var index := 0
		while index + 1 < segments.size():
			draw_line(xform * segments[index], xform * segments[index + 1], color, 2.0)
			index += 2
	else:
		draw_circle(xform.origin, 6.0, color)


func _circle(xform: Transform2D, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		points.append(xform * Vector2(cos(angle), sin(angle)) * radius)
	_outline(points, color)


func _outline(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 2:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, 2.0)
