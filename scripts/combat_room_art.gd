extends Node2D

const SHIP_DIR := "res://art_placeholder/scifi_ship/"
const SHIP2_DIR := "res://art_placeholder/scifi_ship_v2/"
const TILT := 0.72
const TILE := 384.0
const WALL_BASE := 440.0
const ROOM := Rect2(0, 440, 2304, 1120)

var _floor_layer: Node2D
var _trim_layer: Node2D
var _art_layer: Node2D
var _light_layer: Node2D

var _textures := {}
var _region_cache := {}


func _ready() -> void:
	_load_textures()

	_floor_layer = Node2D.new()
	_floor_layer.name = "Floors"
	add_child(_floor_layer)

	_trim_layer = Node2D.new()
	_trim_layer.name = "Trim"
	add_child(_trim_layer)

	_light_layer = Node2D.new()
	_light_layer.name = "Lights"
	add_child(_light_layer)

	_art_layer = Node2D.new()
	_art_layer.name = "Art"
	add_child(_art_layer)

	_build_floors()
	_build_trim()
	_build_walls_and_collision()
	_build_props()
	_build_lights()
	_add_label("COMBAT DECK", Vector2(1152, 700))


func _load_textures() -> void:
	for key in ["floor_corridor", "floor_engineering"]:
		_textures[key] = load(SHIP_DIR + key + ".png")
	_textures["wall_straight"] = load(SHIP2_DIR + "environment/walls/wall_straight.png")
	_textures["console_v2"] = load(SHIP2_DIR + "props/console_terminal_01.png")
	_textures["crate_v2"] = load(SHIP2_DIR + "props/cargo_crate_large.png")
	_textures["reactor_core"] = load(SHIP_DIR + "reactor_core.png")
	_textures["pipe_bundle"] = load(SHIP_DIR + "pipe_bundle.png")
	_textures["shadow_prop"] = load(SHIP2_DIR + "vfx/shadow_prop.png")
	_textures["light_cyan"] = load(SHIP2_DIR + "vfx/light_pool_cyan.png")
	_textures["light_amber"] = load(SHIP2_DIR + "vfx/light_pool_amber.png")


func _build_floors() -> void:
	for row in 3:
		for col in 6:
			var edge := col == 0 or col == 5
			var tex: Texture2D = _textures["floor_corridor"] if edge else _textures["floor_engineering"]
			var center := Vector2(col * TILE + TILE / 2.0, ROOM.position.y + row * TILE + TILE / 2.0)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = center
			sprite.scale = Vector2(TILE / tex.get_width(), TILE / tex.get_height())
			_floor_layer.add_child(sprite)

	# 出口走廊
	var corridor_tex: Texture2D = _textures["floor_corridor"]
	var corridor := Sprite2D.new()
	corridor.texture = corridor_tex
	corridor.position = Vector2(2432, 1100)
	corridor.scale = Vector2(256.0 / corridor_tex.get_width(), 280.0 / corridor_tex.get_height())
	_floor_layer.add_child(corridor)


func _build_walls_and_collision() -> void:
	for i in 6:
		_add_upright(_textures["wall_straight"], Vector2(192.0 + i * 384.0, WALL_BASE), 384.0, 280.0)

	_add_collider(Rect2(0, 380, 2304, 60))
	_add_collider(Rect2(0, 440, 32, 1120))
	# 右侧墙在 y=960..1240 留出出口门洞
	_add_collider(Rect2(2272, 440, 32, 520))
	_add_collider(Rect2(2272, 1240, 32, 320))
	_add_collider(Rect2(0, 1536, 2304, 56))
	# 出口走廊上下边界
	_add_collider(Rect2(2304, 900, 288, 60))
	_add_collider(Rect2(2304, 1240, 288, 60))

	_add_wall_block(Rect2(0, 440, 32, 1120))
	_add_wall_block(Rect2(2272, 440, 32, 520))
	_add_wall_block(Rect2(2272, 1240, 32, 320))
	_add_wall_block(Rect2(0, 1536, 2304, 56))


func _build_props() -> void:
	_add_prop_shadow(Vector2(420, 880), 320.0)
	_add_upright(_textures["console_v2"], Vector2(420, 880), 296.0, 300.0, 1, true)
	_add_collider(Rect2(320, 770, 200, 110))

	_add_prop_shadow(Vector2(1900, 1420), 320.0)
	_add_upright(_textures["console_v2"], Vector2(1900, 1420), 296.0, 300.0, 1, true)
	_add_collider(Rect2(1800, 1310, 200, 110))

	_add_prop_shadow(Vector2(860, 1240), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(860, 1240), 202.0, 170.0, 1, true)
	_add_collider(Rect2(785, 1160, 150, 80))

	_add_prop_shadow(Vector2(1480, 1240), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(1480, 1240), 202.0, 170.0, 1, true)
	_add_collider(Rect2(1405, 1160, 150, 80))

	_add_prop_shadow(Vector2(1250, 900), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(1250, 900), 202.0, 170.0, 1, true)
	_add_collider(Rect2(1175, 820, 150, 80))

	_add_upright(_textures["reactor_core"], Vector2(2020, 640), 263.0, 380.0, 1, true)
	_add_collider(Rect2(1930, 520, 180, 120))

	_add_upright(_textures["pipe_bundle"], Vector2(1700, 1500), 240.0, 180.0, 1, true)


func _build_trim() -> void:
	var b := 26.0
	var trim := Color(0.14, 0.16, 0.2)
	_add_rect_poly(Vector2(ROOM.position.x - b, ROOM.position.y - b), Vector2(ROOM.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(ROOM.position.x - b, ROOM.end.y), Vector2(ROOM.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(ROOM.position.x - b, ROOM.position.y), Vector2(b, ROOM.size.y), trim)
	_add_rect_poly(Vector2(ROOM.end.x, ROOM.position.y), Vector2(b, ROOM.size.y), trim)

	var hazard := Color(0.78, 0.6, 0.18, 0.5)
	var x := 40.0
	while x < ROOM.size.x - 40.0:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 1508), Vector2(x + 48, 1552)])
		line.width = 9.0
		line.default_color = hazard
		_trim_layer.add_child(line)
		x += 96.0

	# 中央全息标记
	var ring := Line2D.new()
	ring.points = _closed(_circle_points(330.0, 64))
	ring.position = Vector2(1152, 980)
	ring.width = 3.0
	ring.default_color = Color(0.3, 0.8, 0.95, 0.16)
	_trim_layer.add_child(ring)

	var inner := Line2D.new()
	inner.points = _closed(_circle_points(240.0, 56))
	inner.position = Vector2(1152, 980)
	inner.width = 2.0
	inner.default_color = Color(0.3, 0.8, 0.95, 0.1)
	_trim_layer.add_child(inner)

	# 入口着陆区
	var pad := Line2D.new()
	pad.points = _closed(_rect_points(Rect2(90, 1320, 300, 200)))
	pad.width = 3.0
	pad.default_color = Color(0.4, 0.9, 1.0, 0.22)
	_trim_layer.add_child(pad)

	# 出口走廊边框
	_add_rect_poly(Vector2(2304, 960), Vector2(256, 6), Color(0.32, 0.7, 0.78, 0.55))
	_add_rect_poly(Vector2(2304, 1234), Vector2(256, 6), Color(0.32, 0.7, 0.78, 0.55))


func _build_lights() -> void:
	_add_light(Vector2(1152, 980), 900.0, Color(0.4, 0.8, 1.0, 0.12))
	_add_light(Vector2(420, 880), 620.0, Color(1.0, 0.7, 0.35, 0.14))
	_add_light(Vector2(2020, 640), 760.0, Color(0.35, 0.85, 1.0, 0.2))
	_add_light(Vector2(1700, 1450), 640.0, Color(1.0, 0.7, 0.35, 0.1))
	_add_light(Vector2(220, 1430), 560.0, Color(0.45, 1.0, 0.8, 0.12))
	_add_light(Vector2(2432, 1100), 460.0, Color(0.4, 0.9, 1.0, 0.18))


func _add_wall_block(rect: Rect2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)])
	poly.color = Color(0.16, 0.19, 0.24)
	_art_layer.add_child(poly)

	var line := Line2D.new()
	line.points = _closed(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)]))
	line.width = 2.0
	line.default_color = Color(0.06, 0.08, 0.1)
	_art_layer.add_child(line)

	var edge := Line2D.new()
	edge.points = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0)])
	edge.width = 3.0
	edge.default_color = Color(0.32, 0.7, 0.78, 0.6)
	_art_layer.add_child(edge)


func _add_rect_poly(pos: Vector2, size: Vector2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y)])
	poly.color = color
	_trim_layer.add_child(poly)


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 160.0, center.y - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(320, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.22))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _add_upright(tex: Texture2D, base: Vector2, width: float, height: float, z: int = 0, occluder := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	var used := _used_rect(tex)
	sprite.region_enabled = true
	sprite.region_rect = Rect2(used)
	var local_height := height / TILT
	sprite.scale = Vector2(width / used.size.x, local_height / used.size.y)
	sprite.position = Vector2(base.x, base.y - local_height / 2.0)
	sprite.z_index = z
	_art_layer.add_child(sprite)
	if occluder:
		Occlusion.register_occluder(sprite, base)
	return sprite


func _used_rect(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if not _region_cache.has(key):
		var image := tex.get_image()
		if image:
			_region_cache[key] = image.get_used_rect()
		else:
			_region_cache[key] = Rect2i(0, 0, tex.get_width(), tex.get_height())
	return _region_cache[key]


func _add_prop_shadow(base: Vector2, width: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _textures["shadow_prop"]
	sprite.position = base
	var s := width * 1.15 / 256.0
	sprite.scale = Vector2(s, s)
	sprite.z_index = 0
	_art_layer.add_child(sprite)


func _add_light(center: Vector2, diameter: float, color: Color) -> void:
	var texture: Texture2D = _textures["light_cyan"] if color.b >= color.r else _textures["light_amber"]
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = center
	sprite.scale = Vector2(diameter / 512.0, diameter / 512.0)
	sprite.modulate = Color(1, 1, 1, clampf(color.a * 1.6, 0.05, 0.5))
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = material
	_light_layer.add_child(sprite)


func _add_collider(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, Vector2(rect.position.x, rect.end.y)])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _draw() -> void:
	draw_rect(Rect2(-400, -200, 3200, 2200), Color(0.017, 0.02, 0.028))
