extends Node2D

## 转运仓占位场景：地面、墙体、货架、操作屏与导引灯。
## 全部使用现有占位贴图与程序化绘制，不新增外部美术资产。

const GUIDE_SCRIPT := preload("res://scripts/guide_lights.gd")
const SHIP_DIR := "res://art_placeholder/scifi_ship/"
const SHIP2_DIR := "res://art_placeholder/scifi_ship_v2/"
const TILT := 0.72
const TILE := 384.0
const WALL_BASE := 440.0
const ROOM := Rect2(0, 440, 1536, 1120)
const CONSOLE_BASE := Vector2(360, 980)
const SMASH_BASE := Vector2(560, 1000)

var _floor_layer: Node2D
var _trim_layer: Node2D
var _art_layer: Node2D
var _light_layer: Node2D
var _fx_layer: Node2D
var _guide: Node2D

var _textures := {}
var _region_cache := {}

var _console_sprite: Sprite2D
var _smash_crate: Sprite2D
var _smash_body: StaticBody2D


func _ready() -> void:
	_load_textures()

	_floor_layer = Node2D.new()
	_floor_layer.name = "Floors"
	add_child(_floor_layer)

	_trim_layer = Node2D.new()
	_trim_layer.name = "Trim"
	add_child(_trim_layer)

	_guide = Node2D.new()
	_guide.name = "GuideLights"
	_guide.set_script(GUIDE_SCRIPT)
	add_child(_guide)

	_light_layer = Node2D.new()
	_light_layer.name = "Lights"
	add_child(_light_layer)

	_art_layer = Node2D.new()
	_art_layer.name = "Art"
	add_child(_art_layer)

	_fx_layer = Node2D.new()
	_fx_layer.name = "FX"
	add_child(_fx_layer)

	_build_floors()
	_build_trim()
	_build_walls_and_collision()
	_build_props()
	_build_lights()
	_add_label("TRANSFER HALL", Vector2(768, 560))


func set_guide_active(value: bool) -> void:
	if _guide:
		_guide.active = value
		_guide.queue_redraw()


func get_smash_point() -> Vector2:
	return to_global(SMASH_BASE)


func smash_crate() -> void:
	if _smash_crate == null:
		return
	_smash_crate.visible = false
	if _smash_body:
		for child in _smash_body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	_spawn_debris(to_local(_smash_crate.global_position + Vector2(0, -20)), Color(0.5, 0.37, 0.23), 12)


func destroy_console() -> void:
	if _console_sprite:
		_console_sprite.modulate = Color(0.36, 0.24, 0.24, 1.0)
	_spawn_debris(CONSOLE_BASE + Vector2(0, -70), Color(0.34, 0.42, 0.46), 9)
	_spawn_debris(CONSOLE_BASE + Vector2(20, -120), Color(1.0, 0.55, 0.2), 6)


func spawn_impact_debris(world_point: Vector2) -> void:
	_spawn_debris(to_local(world_point), Color(0.55, 0.4, 0.24), 10)


func _load_textures() -> void:
	for key in ["floor_corridor", "floor_engineering", "console_terminal", "cargo_crate", "pipe_bundle", "reactor_core"]:
		_textures[key] = load(SHIP_DIR + key + ".png")
	_textures["wall_straight"] = load(SHIP2_DIR + "environment/walls/wall_straight.png")
	_textures["door_frame"] = load(SHIP2_DIR + "environment/walls/door_frame.png")
	_textures["console_v2"] = load(SHIP2_DIR + "props/console_terminal_01.png")
	_textures["crate_v2"] = load(SHIP2_DIR + "props/cargo_crate_large.png")
	_textures["shadow_prop"] = load(SHIP2_DIR + "vfx/shadow_prop.png")
	_textures["light_cyan"] = load(SHIP2_DIR + "vfx/light_pool_cyan.png")
	_textures["light_amber"] = load(SHIP2_DIR + "vfx/light_pool_amber.png")


func _build_floors() -> void:
	for row in 3:
		for col in 4:
			var edge := col == 0 or col == 3
			var tex: Texture2D = _textures["floor_corridor"] if edge else _textures["floor_engineering"]
			var center := Vector2(col * TILE + TILE / 2.0, ROOM.position.y + row * TILE + TILE / 2.0)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = center
			sprite.scale = Vector2(TILE / tex.get_width(), TILE / tex.get_height())
			_floor_layer.add_child(sprite)

	var corridor_tex: Texture2D = _textures["floor_corridor"]
	var corridor := Sprite2D.new()
	corridor.texture = corridor_tex
	corridor.position = Vector2(1664, 1100)
	corridor.scale = Vector2(256.0 / corridor_tex.get_width(), 280.0 / corridor_tex.get_height())
	_floor_layer.add_child(corridor)


func _build_trim() -> void:
	var bounds := Rect2(0, 440, 1536, 1120)
	var trim := Color(0.14, 0.16, 0.2)
	var b := 26.0
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.position.y - b), Vector2(bounds.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.end.y), Vector2(bounds.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.position.y), Vector2(b, bounds.size.y), trim)
	_add_rect_poly(Vector2(bounds.end.x, bounds.position.y), Vector2(b, bounds.size.y), trim)

	var hazard := Color(0.78, 0.6, 0.18, 0.5)
	var x := bounds.position.x + 40.0
	while x < bounds.end.x - 40.0:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 1508), Vector2(x + 48, 1552)])
		line.width = 9.0
		line.default_color = hazard
		_trim_layer.add_child(line)
		x += 96.0

	_add_rect_poly(Vector2(1536, 960), Vector2(256, 6), Color(0.32, 0.7, 0.78, 0.55))
	_add_rect_poly(Vector2(1536, 1234), Vector2(256, 6), Color(0.32, 0.7, 0.78, 0.55))

	# 中央机械臂作业区的地面标线
	_add_ring(Vector2(860, 880), 520.0, Color(0.9, 0.55, 0.18, 0.16), 3.0)
	_add_ring(Vector2(860, 880), 360.0, Color(0.9, 0.55, 0.18, 0.2), 2.0)


func _build_walls_and_collision() -> void:
	for i in 4:
		_add_upright(_textures["wall_straight"], Vector2(192.0 + i * 384.0, WALL_BASE), 384.0, 280.0)
	_add_upright(_textures["door_frame"], Vector2(768.0, WALL_BASE), 380.0, 320.0, 3)

	_add_collider(Rect2(0, 380, 1536, 60))
	_add_collider(Rect2(0, 440, 32, 1120))
	_add_collider(Rect2(0, 1536, 1536, 56))

	# 东侧出口门洞
	_add_collider(Rect2(1504, 440, 32, 520))
	_add_collider(Rect2(1504, 1240, 32, 320))
	_add_collider(Rect2(1536, 900, 288, 60))
	_add_collider(Rect2(1536, 1240, 288, 60))
	_add_wall_block(Rect2(1504, 440, 32, 520))
	_add_wall_block(Rect2(1504, 1240, 32, 320))

	_add_wall_block(Rect2(0, 440, 32, 1120))
	_add_wall_block(Rect2(0, 1536, 1536, 56))


func _build_props() -> void:
	# 操作屏
	_add_prop_shadow(CONSOLE_BASE, 320.0)
	_console_sprite = _add_upright(_textures["console_v2"], CONSOLE_BASE, 296.0, 300.0, 1, true)
	_add_collider(Rect2(CONSOLE_BASE.x - 100.0, CONSOLE_BASE.y - 110.0, 200, 110))

	# 第一次擦身时被砸碎的货箱
	_add_prop_shadow(SMASH_BASE, 220.0)
	_smash_crate = _add_upright(_textures["crate_v2"], SMASH_BASE, 190.0, 160.0, 1, true)
	_smash_body = _add_collider(Rect2(SMASH_BASE.x - 72.0, SMASH_BASE.y - 80.0, 144, 80))

	# 仓储货架
	_add_prop_shadow(Vector2(200, 700), 210.0)
	_add_upright(_textures["crate_v2"], Vector2(200, 700), 194.0, 163.0, 1, true)
	_add_collider(Rect2(127, 620, 146, 80))

	_add_prop_shadow(Vector2(1240, 760), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(1240, 760), 202.0, 170.0, 1, true)
	_add_collider(Rect2(1164, 680, 152, 80))

	_add_prop_shadow(Vector2(1330, 1310), 210.0)
	_add_upright(_textures["crate_v2"], Vector2(1330, 1310), 194.0, 163.0, 1, true)
	_add_collider(Rect2(1257, 1230, 146, 80))

	_add_prop_shadow(Vector2(980, 1440), 210.0)
	_add_upright(_textures["crate_v2"], Vector2(980, 1440), 194.0, 163.0, 1, true)
	_add_collider(Rect2(907, 1360, 146, 80))

	_add_upright(_textures["reactor_core"], Vector2(120, 1210), 230.0, 330.0, 1, true)
	_add_collider(Rect2(45, 1110, 150, 100))

	_add_upright(_textures["pipe_bundle"], Vector2(1120, 1490), 260.0, 190.0, 1, true)
	_add_upright(_textures["pipe_bundle"], Vector2(680, 520), 240.0, 170.0, 1, true)

	# 高位货架色块
	_add_block(Vector2(420, 560), 360.0, 170.0, Color(0.2, 0.23, 0.27), Color(0.3, 0.72, 0.82), false)
	_add_block(Vector2(1000, 540), 360.0, 170.0, Color(0.2, 0.23, 0.27), Color(0.3, 0.72, 0.82), false)


func _build_lights() -> void:
	_add_light(CONSOLE_BASE, 620.0, Color(1.0, 0.68, 0.32, 0.14))
	_add_light(Vector2(860, 880), 760.0, Color(1.0, 0.55, 0.25, 0.12))
	_add_light(Vector2(768, 1480), 620.0, Color(0.4, 0.85, 1.0, 0.1))
	_add_light(Vector2(1664, 1100), 460.0, Color(0.4, 0.9, 1.0, 0.18))


func _draw() -> void:
	draw_rect(Rect2(-600, -400, 2800, 2400), Color(0.017, 0.02, 0.028))


func _spawn_debris(at: Vector2, color: Color, count: int) -> void:
	for i in count:
		var shard := Polygon2D.new()
		var size := randf_range(5.0, 13.0)
		shard.polygon = PackedVector2Array([
			Vector2(-size, -size * 0.5),
			Vector2(size * 0.6, -size),
			Vector2(size, size * 0.4),
			Vector2(-size * 0.4, size),
		])
		shard.color = color.darkened(randf_range(0.0, 0.28))
		shard.position = at + Vector2(randf_range(-24, 24), randf_range(-18, 18))
		shard.rotation = randf() * TAU
		shard.z_index = 12
		_fx_layer.add_child(shard)

		var velocity := Vector2(randf_range(-90, 90), randf_range(-140, -40))
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position", shard.position + velocity * 0.45 + Vector2(0, 70), 0.45)
		tween.tween_property(shard, "rotation", shard.rotation + randf_range(-4.0, 4.0), 0.45)
		tween.tween_property(shard, "modulate:a", 0.0, 0.45).set_delay(0.12)
		tween.chain().tween_callback(shard.queue_free)


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


func _add_block(base: Vector2, width: float, height: float, color: Color, accent: Color, solid: bool) -> void:
	var holder := Node2D.new()
	holder.position = base
	holder.z_index = 2
	_art_layer.add_child(holder)

	var local_height := height / TILT
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(width / 2.0, 0), Vector2(width / 2.0, -local_height), Vector2(-width / 2.0, -local_height)])
	poly.color = color
	holder.add_child(poly)

	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(-width / 2.0, 0), Vector2(width / 2.0, 0), Vector2(width / 2.0, -local_height), Vector2(-width / 2.0, -local_height), Vector2(-width / 2.0, 0)])
	line.width = 2.0
	line.default_color = Color(0.06, 0.08, 0.1)
	holder.add_child(line)

	var strip := Polygon2D.new()
	strip.polygon = PackedVector2Array([
		Vector2(-width / 2.0 + 10.0, -local_height + 10.0),
		Vector2(width / 2.0 - 10.0, -local_height + 10.0),
		Vector2(width / 2.0 - 10.0, -local_height + 22.0),
		Vector2(-width / 2.0 + 10.0, -local_height + 22.0),
	])
	strip.color = accent
	holder.add_child(strip)

	if solid:
		_add_collider(Rect2(base.x - width * 0.35, base.y - 60.0, width * 0.7, 60.0))


func _add_rect_poly(pos: Vector2, size: Vector2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([pos, pos + Vector2(size.x, 0), pos + size, pos + Vector2(0, size.y)])
	poly.color = color
	_trim_layer.add_child(poly)


func _add_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var ring := Line2D.new()
	ring.points = _closed(_circle_points(radius, 56))
	ring.position = center
	ring.width = width
	ring.default_color = color
	_trim_layer.add_child(ring)


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 180.0, center.y - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(360, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
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


func _add_collider(rect: Rect2) -> StaticBody2D:
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
	return body


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
