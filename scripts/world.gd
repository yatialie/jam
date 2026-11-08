extends Node2D

const WORLD_SIZE := Vector2(2560, 1600)
const VOID_COLOR := Color(0.045, 0.055, 0.075)

const WALL_TOP := Color(0.24, 0.29, 0.36)
const WALL_SIDE := Color(0.12, 0.15, 0.2)
const WALL_SIDE_LIGHT := Color(0.18, 0.22, 0.29)
const WALL_RIM := Color(0.46, 0.56, 0.68)
const WALL_LINE := Color(0.05, 0.07, 0.1)
const WALL_SIDE_DEPTH := 56.0
const BOX_SIDE_DEPTH := 28.0
const CIRCLE_SIDE_DEPTH := 34.0
const TILT := 0.72

var rooms := [
	{"rect": Rect2(240, 460, 560, 660), "color": Color(0.17, 0.29, 0.27), "line": Color(0.22, 0.36, 0.33), "style": "tile", "label": "GARDEN", "label_pos": Vector2(520, 640)},
	{"rect": Rect2(800, 460, 920, 660), "color": Color(0.28, 0.3, 0.32), "line": Color(0.33, 0.35, 0.38), "style": "panel", "label": "HALL", "label_pos": Vector2(960, 640)},
	{"rect": Rect2(1720, 400, 600, 720), "color": Color(0.24, 0.18, 0.14), "line": Color(0.3, 0.22, 0.17), "style": "plank", "label": "ENGINE", "label_pos": Vector2(2020, 540)},
	{"rect": Rect2(940, 180, 680, 280), "color": Color(0.2, 0.24, 0.3), "line": Color(0.25, 0.29, 0.36), "style": "tile", "label": "CORRIDOR", "label_pos": Vector2(1280, 330)},
	{"rect": Rect2(840, 1120, 880, 340), "color": Color(0.26, 0.26, 0.22), "line": Color(0.31, 0.31, 0.26), "style": "panel", "label": "DOCK", "label_pos": Vector2(1280, 1250)},
]

var wall_bands := [
	Rect2(240, 460, 560, 32),
	Rect2(240, 1088, 560, 32),
	Rect2(240, 460, 32, 660),
	Rect2(768, 460, 32, 260),
	Rect2(768, 860, 32, 260),

	Rect2(800, 460, 400, 32),
	Rect2(1340, 460, 380, 32),
	Rect2(800, 1088, 380, 32),
	Rect2(1320, 1088, 400, 32),
	Rect2(800, 460, 32, 260),
	Rect2(800, 860, 32, 260),
	Rect2(1688, 460, 32, 240),
	Rect2(1688, 840, 32, 280),

	Rect2(1720, 400, 32, 300),
	Rect2(1720, 840, 32, 280),
	Rect2(1720, 400, 600, 32),
	Rect2(1720, 1088, 600, 32),
	Rect2(2288, 400, 32, 720),

	Rect2(940, 180, 680, 32),
	Rect2(940, 180, 32, 280),
	Rect2(1588, 180, 32, 280),
	Rect2(940, 428, 260, 32),
	Rect2(1340, 428, 280, 32),

	Rect2(840, 1120, 340, 32),
	Rect2(1320, 1120, 400, 32),
	Rect2(840, 1428, 880, 32),
	Rect2(840, 1120, 32, 340),
	Rect2(1688, 1120, 32, 340),
]

var box_props := [
	{"pos": Vector2(320, 600), "size": Vector2(70, 70), "color": Color(0.33, 0.5, 0.31), "solid": true},
	{"pos": Vector2(320, 1000), "size": Vector2(70, 70), "color": Color(0.33, 0.5, 0.31), "solid": true},
	{"pos": Vector2(880, 560), "size": Vector2(64, 64), "color": Color(0.33, 0.5, 0.31), "solid": true},
	{"pos": Vector2(1640, 560), "size": Vector2(64, 64), "color": Color(0.33, 0.5, 0.31), "solid": true},
	{"pos": Vector2(930, 1000), "size": Vector2(70, 60), "color": Color(0.55, 0.4, 0.25), "solid": true},
	{"pos": Vector2(1520, 1040), "size": Vector2(140, 44), "color": Color(0.45, 0.42, 0.36), "solid": true},
	{"pos": Vector2(1840, 560), "size": Vector2(160, 110), "color": Color(0.35, 0.4, 0.45), "solid": true, "accent": Color(0.35, 0.78, 0.8)},
	{"pos": Vector2(2080, 560), "size": Vector2(140, 110), "color": Color(0.35, 0.4, 0.45), "solid": true, "accent": Color(0.85, 0.5, 0.3)},
	{"pos": Vector2(1800, 980), "size": Vector2(70, 70), "color": Color(0.5, 0.36, 0.22), "solid": true},
	{"pos": Vector2(940, 1320), "size": Vector2(100, 80), "color": Color(0.55, 0.4, 0.25), "solid": true},
	{"pos": Vector2(1020, 1210), "size": Vector2(60, 60), "color": Color(0.5, 0.36, 0.22), "solid": true},
	{"pos": Vector2(1620, 1330), "size": Vector2(90, 70), "color": Color(0.55, 0.4, 0.25), "solid": true},
]

var circle_props := [
	{"pos": Vector2(620, 560), "radius": 55.0, "color": Color(0.24, 0.45, 0.28), "solid": true, "ring": Color(0.16, 0.32, 0.2)},
	{"pos": Vector2(700, 980), "radius": 36.0, "color": Color(0.3, 0.52, 0.3), "solid": true, "ring": Color(0.18, 0.36, 0.2)},
	{"pos": Vector2(1260, 780), "radius": 90.0, "color": Color(0.42, 0.47, 0.52), "solid": true, "ring": Color(0.24, 0.28, 0.32)},
	{"pos": Vector2(2240, 980), "radius": 36.0, "color": Color(0.55, 0.34, 0.2), "solid": true, "ring": Color(0.33, 0.2, 0.12)},
	{"pos": Vector2(1500, 1200), "radius": 30.0, "color": Color(0.55, 0.34, 0.2), "solid": true, "ring": Color(0.33, 0.2, 0.12)},
]

var light_points := [
	Vector2(1260, 780), Vector2(1000, 600), Vector2(1500, 920), Vector2(2020, 700),
	Vector2(1280, 300), Vector2(1280, 1300), Vector2(500, 800),
]

var _light_texture: GradientTexture2D


func _ready() -> void:
	_light_texture = _make_light_texture()

	var wall_layer := Node2D.new()
	wall_layer.name = "Walls"
	add_child(wall_layer)
	for band in wall_bands:
		_add_wall(wall_layer, band)

	var prop_layer := Node2D.new()
	prop_layer.name = "Props"
	add_child(prop_layer)
	for spec in box_props:
		_add_box_prop(prop_layer, spec)
	for spec in circle_props:
		_add_circle_prop(prop_layer, spec)

	for room in rooms:
		_add_label(room["label"], room["label_pos"])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), VOID_COLOR)

	for room in rooms:
		var rect: Rect2 = room["rect"]
		draw_rect(rect, room["color"])
		_draw_pattern(rect, room["style"], room["line"])
		_draw_room_shadow(rect)

	_draw_decor()


func _draw_pattern(rect: Rect2, style: String, line_color: Color) -> void:
	match style:
		"tile":
			_draw_grid(rect, 64.0, line_color)
		"panel":
			_draw_grid(rect, 120.0, line_color)
		"plank":
			var y := rect.position.y + 24.0
			while y < rect.end.y:
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 2.0)
				y += 28.0


func _draw_room_shadow(rect: Rect2) -> void:
	var shade := Color(0, 0, 0, 0.13)
	var edge := 18.0
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, edge)), shade)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - edge), Vector2(rect.size.x, edge)), shade)
	draw_rect(Rect2(rect.position, Vector2(edge, rect.size.y)), shade)
	draw_rect(Rect2(Vector2(rect.end.x - edge, rect.position.y), Vector2(edge, rect.size.y)), shade)


func _draw_grid(rect: Rect2, step: float, line_color: Color) -> void:
	var x := rect.position.x + step
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), line_color, 1.0)
		x += step
	var y := rect.position.y + step
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), line_color, 1.0)
		y += step


func _draw_decor() -> void:
	for light_pos in light_points:
		draw_texture_rect(_light_texture, Rect2(light_pos - Vector2(220, 220), Vector2(440, 440)), false)

	var pond := _ellipse_points(Vector2(430, 830), Vector2(140, 92), 32)
	draw_colored_polygon(pond, Color(0.14, 0.4, 0.48))
	draw_polyline(_closed(pond), Color(0.2, 0.52, 0.58), 3.0)
	draw_circle(Vector2(388, 818), 15.0, Color(0.3, 0.55, 0.35))
	draw_circle(Vector2(470, 856), 11.0, Color(0.3, 0.55, 0.35))

	draw_circle(Vector2(1260, 780), 122.0, Color(0.32, 0.34, 0.37))
	draw_arc(Vector2(1260, 780), 122.0, 0, TAU, 64, Color(0.38, 0.41, 0.45), 4.0)
	draw_arc(Vector2(1260, 780), 100.0, 0, TAU, 64, Color(0.36, 0.39, 0.43), 2.0)

	draw_line(Vector2(1752, 700), Vector2(2288, 700), Color(0.52, 0.2, 0.17), 12.0)
	draw_line(Vector2(1752, 744), Vector2(2288, 744), Color(0.42, 0.16, 0.14), 6.0)

	var stripe := Color(0.8, 0.66, 0.22, 0.75)
	var x := 840.0
	while x < 1720.0:
		draw_line(Vector2(x, 1160), Vector2(x + 44, 1204), stripe, 8.0)
		x += 88.0
	draw_arc(Vector2(1280, 1290), 84.0, 0, TAU, 48, Color(0.8, 0.66, 0.22, 0.55), 4.0)


func _add_wall(parent: Node2D, band: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = band.position + band.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = band.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)

	var hw := band.size.x / 2.0
	var hh := band.size.y / 2.0
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	top.color = WALL_TOP
	body.add_child(top)

	var side := Polygon2D.new()
	side.polygon = PackedVector2Array([Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, hh + WALL_SIDE_DEPTH), Vector2(-hw, hh + WALL_SIDE_DEPTH)])
	side.color = WALL_SIDE
	body.add_child(side)

	var side_light := Polygon2D.new()
	side_light.polygon = PackedVector2Array([Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, hh + WALL_SIDE_DEPTH * 0.4), Vector2(-hw, hh + WALL_SIDE_DEPTH * 0.4)])
	side_light.color = WALL_SIDE_LIGHT
	body.add_child(side_light)

	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, -hh + 5), Vector2(-hw, -hh + 5)])
	rim.color = WALL_RIM
	body.add_child(rim)

	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)])
	line.width = 2.0
	line.default_color = WALL_LINE
	body.add_child(line)


func _add_box_prop(parent: Node2D, spec: Dictionary) -> void:
	var pos: Vector2 = spec["pos"]
	var size: Vector2 = spec["size"]
	var holder: Node2D

	if spec["solid"]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := RectangleShape2D.new()
		shape.size = size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		holder = body
	else:
		holder = Node2D.new()

	holder.position = pos
	parent.add_child(holder)

	var hw := size.x / 2.0
	var hh := size.y / 2.0

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-hw + 4, -hh + 14), Vector2(hw + 4, -hh + 14), Vector2(hw + 4, hh + BOX_SIDE_DEPTH + 20), Vector2(-hw + 4, hh + BOX_SIDE_DEPTH + 20)])
	shadow.color = Color(0, 0, 0, 0.22)
	holder.add_child(shadow)

	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	top.color = spec["color"]
	holder.add_child(top)

	var side := Polygon2D.new()
	side.polygon = PackedVector2Array([Vector2(-hw, hh), Vector2(hw, hh), Vector2(hw, hh + BOX_SIDE_DEPTH), Vector2(-hw, hh + BOX_SIDE_DEPTH)])
	side.color = (spec["color"] as Color).darkened(0.35)
	holder.add_child(side)

	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh)])
	line.width = 2.0
	line.default_color = Color(0.07, 0.09, 0.11, 0.85)
	holder.add_child(line)

	if spec.has("accent"):
		var accent := Polygon2D.new()
		accent.polygon = PackedVector2Array([Vector2(-hw + 12, -hh + 12), Vector2(hw - 12, -hh + 12), Vector2(hw - 12, -hh + 24), Vector2(-hw + 12, -hh + 24)])
		accent.color = spec["accent"]
		holder.add_child(accent)


func _add_circle_prop(parent: Node2D, spec: Dictionary) -> void:
	var pos: Vector2 = spec["pos"]
	var radius: float = spec["radius"]
	var holder: Node2D

	if spec["solid"]:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CircleShape2D.new()
		shape.radius = radius * 0.85
		var collider := CollisionShape2D.new()
		collider.shape = shape
		body.add_child(collider)
		holder = body
	else:
		holder = Node2D.new()

	holder.position = pos
	parent.add_child(holder)

	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(Vector2(4, CIRCLE_SIDE_DEPTH + 14), Vector2(radius + 5.0, radius * 0.72), 24)
	shadow.color = Color(0, 0, 0, 0.22)
	holder.add_child(shadow)

	var side := Polygon2D.new()
	side.polygon = _ellipse_points(Vector2(0, CIRCLE_SIDE_DEPTH), Vector2(radius, radius * 0.98), 28)
	side.color = (spec["color"] as Color).darkened(0.4)
	holder.add_child(side)

	var top := Polygon2D.new()
	top.polygon = _circle_points(radius, 28)
	top.color = spec["color"]
	holder.add_child(top)

	var line := Line2D.new()
	line.points = _closed(_circle_points(radius, 28))
	line.width = 2.0
	line.default_color = Color(0.07, 0.09, 0.11, 0.85)
	holder.add_child(line)

	if spec.has("ring"):
		var ring := Line2D.new()
		ring.points = _closed(_circle_points(radius * 0.62, 24))
		ring.width = 2.0
		ring.default_color = spec["ring"]
		holder.add_child(ring)


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 140.0, center.y - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(280, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _make_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.94, 0.76, 0.16))
	gradient.set_color(1, Color(1, 0.94, 0.76, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _ellipse_points(center: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
