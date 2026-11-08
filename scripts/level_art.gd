extends Node2D

const SHIP_DIR := "res://art_placeholder/scifi_ship/"
const SHIP2_DIR := "res://art_placeholder/scifi_ship_v2/"
const TILT := 0.72
const TILE := 384.0
const ROOM := Rect2(0, 440, 2304, 1152)
const HANGAR := Rect2(2304, 440, 1152, 1152)
const WALL_BASE := 440.0
const DOOR_X := 2304.0
const DOOR_BOTTOM := 1040.0

@export var exit_scene_path := "res://scenes/transfer_hall.tscn"

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
	_add_label("HANGAR", Vector2(2880, 760))


func _load_textures() -> void:
	for key in ["floor_corridor", "floor_engineering", "wall_segment", "door_airlock", "console_terminal", "cargo_crate", "pipe_bundle", "reactor_core"]:
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
		for col in 6:
			var tex: Texture2D = _textures["floor_engineering"] if col >= 4 else _textures["floor_corridor"]
			var center := Vector2(col * TILE + TILE / 2.0, ROOM.position.y + row * TILE + TILE / 2.0)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = center
			sprite.scale = Vector2(TILE / tex.get_width(), TILE / tex.get_height())
			_floor_layer.add_child(sprite)

	for row in 3:
		for col in 3:
			var tex: Texture2D = _textures["floor_corridor"]
			var center := Vector2(HANGAR.position.x + col * TILE + TILE / 2.0, HANGAR.position.y + row * TILE + TILE / 2.0)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = center
			sprite.scale = Vector2(TILE / tex.get_width(), TILE / tex.get_height())
			_floor_layer.add_child(sprite)


func _build_walls_and_collision() -> void:
	for i in 9:
		_add_upright(_textures["wall_straight"], Vector2(192.0 + i * 384.0, WALL_BASE), 384.0, 280.0)
	_add_upright(_textures["door_airlock"], Vector2(1152.0, WALL_BASE), 300.0, 300.0, 2)
	_add_upright(_textures["door_frame"], Vector2(1152.0, WALL_BASE), 380.0, 320.0, 3)

	# 空气墙：外圈 + 两房间之间的公共墙（门洞留空）
	_add_collider(Rect2(0, 380, 3456, 60))
	_add_collider(Rect2(0, 440, 32, 1152))
	_add_collider(Rect2(2272, 440, 32, 320))
	_add_collider(Rect2(2272, 1040, 32, 552))
	_add_collider(Rect2(2304, 440, 32, 320))
	_add_collider(Rect2(2304, 1040, 32, 552))
	_add_collider(Rect2(3424, 440, 32, 1152))
	_add_collider(Rect2(0, 1560, 3456, 32))

	# 缺失的侧墙/端墙先用色块占位
	_add_wall_block(Rect2(2288, 440, 32, 320))
	_add_wall_block(Rect2(2288, 1040, 32, 552))
	_add_wall_block(Rect2(3424, 440, 32, 1152))
	_add_wall_block(Rect2(2304, 1560, 1152, 32))

	var door := preload("res://scenes/door.tscn").instantiate()
	door.position = Vector2(DOOR_X, DOOR_BOTTOM)
	door.z_index = 4
	door.exit_scene_path = exit_scene_path
	add_child(door)


func _build_props() -> void:
	_add_prop_shadow(Vector2(620, 930), 320.0)
	_add_upright(_textures["console_v2"], Vector2(620, 930), 296.0, 300.0, 1, true)
	_add_collider(Rect2(520, 820, 200, 110))
	_add_prop_shadow(Vector2(560, 1290), 320.0)
	_add_upright(_textures["console_v2"], Vector2(560, 1290), 296.0, 300.0, 1, true)
	_add_collider(Rect2(460, 1180, 200, 110))

	_add_prop_shadow(Vector2(1180, 1430), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(1180, 1430), 202.0, 170.0, 1, true)
	_add_collider(Rect2(1105, 1350, 150, 80))
	_add_prop_shadow(Vector2(1430, 1320), 210.0)
	_add_upright(_textures["crate_v2"], Vector2(1430, 1320), 194.0, 163.0, 1, true)
	_add_collider(Rect2(1357, 1240, 146, 80))

	_add_upright(_textures["reactor_core"], Vector2(1760, 1180), 263.0, 380.0, 1, true)
	_add_collider(Rect2(1670, 1060, 180, 120))

	_add_upright(_textures["pipe_bundle"], Vector2(1540, 1500), 240.0, 180.0, 1, true)

	# HANGAR 占位色块（缺资产）
	_add_block(Vector2(2680, 1120), 260.0, 300.0, Color(0.22, 0.25, 0.3), Color(0.3, 0.8, 0.9), true)
	_add_block(Vector2(3040, 980), 180.0, 220.0, Color(0.24, 0.22, 0.2), Color(0.9, 0.6, 0.25), true)
	_add_block(Vector2(3220, 1460), 160.0, 150.0, Color(0.5, 0.36, 0.22), Color(0.3, 0.2, 0.12), true)
	_add_block(Vector2(2470, 1450), 140.0, 140.0, Color(0.5, 0.36, 0.22), Color(0.3, 0.2, 0.12), true)

	var access_panel := preload("res://scenes/access_panel.tscn").instantiate()
	access_panel.position = Vector2(2100, 1150)
	access_panel.z_index = 3
	add_child(access_panel)


func _build_trim() -> void:
	var bounds := Rect2(0, 440, 3456, 1152)
	var trim := Color(0.14, 0.16, 0.2)
	var b := 26.0
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.position.y - b), Vector2(bounds.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.end.y), Vector2(bounds.size.x + b * 2.0, b), trim)
	_add_rect_poly(Vector2(bounds.position.x - b, bounds.position.y), Vector2(b, bounds.size.y), trim)
	_add_rect_poly(Vector2(bounds.end.x, bounds.position.y), Vector2(b, bounds.size.y), trim)

	# HANGAR 地面占位区域
	_add_rect_poly(Vector2(2500, 1240), Vector2(800, 260), Color(0.1, 0.12, 0.15))

	var hazard := Color(0.78, 0.6, 0.18, 0.55)
	var x := bounds.position.x + 40.0
	while x < bounds.end.x - 40.0:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, 1532), Vector2(x + 52, 1576)])
		line.width = 10.0
		line.default_color = hazard
		_trim_layer.add_child(line)
		x += 104.0

	var hx := 2520.0
	while hx < 3280.0:
		var pad_line := Line2D.new()
		pad_line.points = PackedVector2Array([Vector2(hx, 1252), Vector2(hx + 46, 1488)])
		pad_line.width = 8.0
		pad_line.default_color = Color(0.78, 0.6, 0.18, 0.4)
		_trim_layer.add_child(pad_line)
		hx += 84.0


func _add_wall_block(rect: Rect2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)])
	poly.color = Color(0.16, 0.19, 0.24)
	_art_layer.add_child(poly)

	var line := Line2D.new()
	line.points = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y), rect.position])
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


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 140.0, center.y - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(280, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _build_lights() -> void:
	_add_light(Vector2(520, 980), 640.0, Color(1.0, 0.7, 0.35, 0.16))
	_add_light(Vector2(1150, 1360), 620.0, Color(0.55, 0.75, 1.0, 0.10))
	_add_light(Vector2(1760, 1180), 720.0, Color(0.35, 0.85, 1.0, 0.22))
	_add_light(Vector2(2880, 1000), 760.0, Color(0.4, 0.85, 1.0, 0.16))
	_add_light(Vector2(2650, 1450), 620.0, Color(1.0, 0.7, 0.35, 0.12))


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


func _draw() -> void:
	draw_rect(Rect2(-600, -400, 4600, 2800), Color(0.017, 0.02, 0.028))
