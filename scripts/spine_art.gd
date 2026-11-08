extends Node2D

## Main spine: the horizontal transit corridor that links the command bridge
## to both wing airlocks. Procedural art only, reusing existing ship assets.

const TILT := 0.72
const SHIP_DIR := "res://art_placeholder/scifi_ship/"
const SHIP2_DIR := "res://art_placeholder/scifi_ship_v2/"
const TILE := 384.0
const FLOOR_Y := 250.0
const CORRIDOR_END := 1018.0
const JUNCTION := Vector2(1500, 620)
const HATCH_RADIUS := 200.0

var _floor_layer: Node2D
var _trim_layer: Node2D
var _wall_layer: Node2D
var _art_layer: Node2D
var _light_layer: Node2D

var _textures := {}
var _region_cache := {}


func _ready() -> void:
	_load_textures()
	_create_layers()
	_build_floors()
	_build_trim()
	_build_walls()
	_build_junction()
	_build_airlocks()
	_build_props()
	_build_lights()
	_add_label("MAIN SPINE", Vector2(1500, 800))
	_add_label("RIGHT WING // ENGINEERING", Vector2(2520, 470))
	_add_label("LEFT WING // HABITAT", Vector2(480, 470))


func _create_layers() -> void:
	_floor_layer = Node2D.new()
	_floor_layer.name = "Floors"
	add_child(_floor_layer)

	_trim_layer = Node2D.new()
	_trim_layer.name = "Trim"
	add_child(_trim_layer)

	_wall_layer = Node2D.new()
	_wall_layer.name = "Walls"
	add_child(_wall_layer)

	_art_layer = Node2D.new()
	_art_layer.name = "Art"
	add_child(_art_layer)

	_light_layer = Node2D.new()
	_light_layer.name = "Lights"
	_light_layer.z_index = 6
	add_child(_light_layer)


func _load_textures() -> void:
	for key in ["floor_corridor", "floor_engineering", "console_terminal", "cargo_crate", "pipe_bundle", "reactor_core"]:
		_textures[key] = load(SHIP_DIR + key + ".png")
	_textures["wall_straight"] = load(SHIP2_DIR + "environment/walls/wall_straight.png")
	_textures["console_v2"] = load(SHIP2_DIR + "props/console_terminal_01.png")
	_textures["crate_v2"] = load(SHIP2_DIR + "props/cargo_crate_large.png")
	_textures["shadow_prop"] = load(SHIP2_DIR + "vfx/shadow_prop.png")
	_textures["light_cyan"] = load(SHIP2_DIR + "vfx/light_pool_cyan.png")
	_textures["light_amber"] = load(SHIP2_DIR + "vfx/light_pool_amber.png")


func _build_floors() -> void:
	for row in 2:
		for col in 8:
			var edge := col < 2 or col > 5
			var tex: Texture2D = _textures["floor_corridor"] if edge else _textures["floor_engineering"]
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = Vector2(col * TILE + TILE / 2.0, FLOOR_Y + row * TILE + TILE / 2.0)
			sprite.scale = Vector2(TILE / tex.get_width(), TILE / tex.get_height())
			sprite.modulate = Color(0.9, 0.94, 0.98, 1.0)
			_floor_layer.add_child(sprite)

	var junction_floor := Polygon2D.new()
	junction_floor.polygon = _circle_points(340.0, 56)
	junction_floor.position = JUNCTION
	junction_floor.color = Color(0.2, 0.22, 0.26)
	_floor_layer.add_child(junction_floor)

	for radius in [220.0, 300.0, 340.0]:
		_floor_layer.add_child(_ring_line(JUNCTION, radius, Color(0.34, 0.8, 0.9, 0.28), 3.0))

	# Center guide strip.
	var guide := Line2D.new()
	guide.points = PackedVector2Array([Vector2(80, 700), Vector2(2920, 700)])
	guide.width = 5.0
	guide.default_color = Color(0.32, 0.82, 1.0, 0.16)
	_floor_layer.add_child(guide)


func _build_trim() -> void:
	var trim := Color(0.14, 0.16, 0.2)
	_add_rect_poly(Rect2(0, 200, 3000, 26), trim)
	_add_rect_poly(Rect2(0, 1018, 3000, 26), trim)
	_add_rect_poly(Rect2(0, 200, 26, 820), trim)
	_add_rect_poly(Rect2(2974, 200, 26, 820), trim)

	_add_rect_poly(Rect2(0, 226, 3000, 6), Color(0.32, 0.72, 0.8, 0.35))
	_add_rect_poly(Rect2(0, 1012, 3000, 6), Color(0.32, 0.72, 0.8, 0.35))

	_hazard_stripes(120.0, 340.0, 976.0)
	_hazard_stripes(2660.0, 2880.0, 976.0)


func _build_walls() -> void:
	for i in 8:
		_add_upright(_textures["wall_straight"], Vector2(192.0 + i * 384.0, 250.0), 384.0, 280.0, 1)
	_add_wall_block(Rect2(0, 1018, 3000, 44))
	_add_wall_block(Rect2(0, 200, 80, 820))
	_add_wall_block(Rect2(2920, 200, 80, 820))

	_add_collider(Rect2(0, 200, 3000, 50))
	_add_collider(Rect2(0, 1018, 3000, 44))
	_add_collider(Rect2(0, 200, 80, 820))
	_add_collider(Rect2(2920, 200, 80, 820))


func _build_junction() -> void:
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([
		Vector2(1420, 620), Vector2(1580, 620),
		Vector2(1660, 250), Vector2(1340, 250),
	])
	beam.color = Color(0.35, 0.85, 1.0, 0.05)
	beam.z_index = -1
	_art_layer.add_child(beam)

	var hatch := Polygon2D.new()
	hatch.polygon = _circle_points(HATCH_RADIUS, 48)
	hatch.position = JUNCTION
	hatch.color = Color(0.035, 0.06, 0.095)
	_art_layer.add_child(hatch)

	var hatch_rim := Polygon2D.new()
	hatch_rim.polygon = _band_polygon(Vector2.ZERO, HATCH_RADIUS, HATCH_RADIUS + 34.0, 48)
	hatch_rim.position = JUNCTION
	hatch_rim.color = Color(0.2, 0.23, 0.27)
	_art_layer.add_child(hatch_rim)

	_art_layer.add_child(_ring_line(JUNCTION, HATCH_RADIUS + 2.0, Color(0.4, 0.9, 1.0, 0.6), 4.0))
	_art_layer.add_child(_ring_line(JUNCTION, HATCH_RADIUS - 16.0, Color(0.3, 0.7, 0.8, 0.25), 2.0))

	for i in 8:
		var a := TAU * float(i) / 8.0
		var line := Line2D.new()
		line.points = PackedVector2Array([
			JUNCTION + Vector2(cos(a), sin(a)) * 44.0,
			JUNCTION + Vector2(cos(a), sin(a)) * (HATCH_RADIUS - 22.0),
		])
		line.width = 2.0
		line.default_color = Color(0.24, 0.36, 0.46, 0.4)
		_art_layer.add_child(line)

	var center := Polygon2D.new()
	center.polygon = _circle_points(42.0, 24)
	center.position = JUNCTION
	center.color = Color(0.12, 0.16, 0.2)
	_art_layer.add_child(center)

	var center_light := Polygon2D.new()
	center_light.polygon = _circle_points(10.0, 12)
	center_light.position = JUNCTION
	center_light.color = Color(0.4, 0.95, 1.0, 0.95)
	_art_layer.add_child(center_light)

	# Wall consoles flanking the junction.
	_add_prop_shadow(Vector2(1120, 900), 240.0)
	_add_upright(_textures["console_v2"], Vector2(1120, 900), 220.0, 230.0, 4, true)
	_add_collider(Rect2(1020, 830, 200, 70))

	_add_prop_shadow(Vector2(1880, 900), 240.0)
	_add_upright(_textures["console_v2"], Vector2(1880, 900), 220.0, 230.0, 4, true)
	_add_collider(Rect2(1780, 830, 200, 70))


func _build_airlocks() -> void:
	_build_airlock(240.0, true)
	_build_airlock(2760.0, false)


func _build_airlock(x: float, left: bool) -> void:
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([
		Vector2(x - 10.0, 430), Vector2(x + 10.0, 430),
		Vector2(x + 10.0, 830), Vector2(x - 10.0, 830),
	])
	bar.color = Color(0.4, 0.95, 1.0, 0.85)
	_wall_layer.add_child(bar)

	var glow := Sprite2D.new()
	glow.texture = _textures["light_cyan"]
	glow.position = Vector2(x, 620)
	glow.scale = Vector2(0.75, 1.1)
	glow.modulate = Color(1, 1, 1, 0.22)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	_light_layer.add_child(glow)

	var frame := Line2D.new()
	frame.points = PackedVector2Array([
		Vector2(x - 60.0, 520), Vector2(x - 60.0, 940),
		Vector2(x + 60.0, 940), Vector2(x + 60.0, 520),
	])
	frame.width = 8.0
	frame.default_color = Color(0.09, 0.11, 0.15)
	_wall_layer.add_child(frame)

	var lip := Line2D.new()
	lip.points = PackedVector2Array([
		Vector2(x - 54.0, 930), Vector2(x + 54.0, 930),
	])
	lip.width = 10.0
	lip.default_color = Color(0.9, 0.62, 0.24, 0.45)
	_wall_layer.add_child(lip)

	var label := Label.new()
	label.text = "LEFT WING" if left else "RIGHT WING"
	label.position = Vector2(x - 110.0, 470.0 - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(220, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 0.5))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _build_props() -> void:
	_add_prop_shadow(Vector2(560, 900), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(560, 900), 190.0, 160.0, 2, true)
	_add_collider(Rect2(488, 830, 144, 70))

	_add_prop_shadow(Vector2(2420, 900), 220.0)
	_add_upright(_textures["crate_v2"], Vector2(2420, 900), 190.0, 160.0, 2, true)
	_add_collider(Rect2(2348, 830, 144, 70))

	_add_upright(_textures["pipe_bundle"], Vector2(880, 300), 240.0, 170.0, 2, false)
	_add_upright(_textures["pipe_bundle"], Vector2(2080, 300), 240.0, 170.0, 2, false)

	_add_prop_shadow(Vector2(720, 320), 200.0)
	_add_wall_panel(Vector2(720, 320), 200.0, 90.0)
	_add_prop_shadow(Vector2(2280, 320), 200.0)
	_add_wall_panel(Vector2(2280, 320), 200.0, 90.0)


func _build_lights() -> void:
	_add_light(JUNCTION, 900.0, Color(0.35, 0.85, 1.0, 0.18))
	_add_light(Vector2(240, 620), 640.0, Color(0.4, 0.95, 1.0, 0.2))
	_add_light(Vector2(2760, 620), 640.0, Color(0.4, 0.95, 1.0, 0.2))
	_add_light(Vector2(1120, 900), 420.0, Color(1.0, 0.68, 0.32, 0.1))
	_add_light(Vector2(1880, 900), 420.0, Color(1.0, 0.68, 0.32, 0.1))

	for i in 5:
		_add_light(Vector2(500.0 + i * 500.0, 320.0), 380.0, Color(0.35, 0.85, 1.0, 0.08))


func _hazard_stripes(x0: float, x1: float, y: float) -> void:
	var x := x0
	while x < x1:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, y), Vector2(x + 42, y + 34)])
		line.width = 8.0
		line.default_color = Color(0.82, 0.62, 0.2, 0.5)
		_trim_layer.add_child(line)
		x += 84.0


func _add_rect_poly(rect: Rect2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
	])
	poly.color = color
	_trim_layer.add_child(poly)


func _add_wall_block(rect: Rect2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
	])
	poly.color = Color(0.16, 0.19, 0.24)
	_wall_layer.add_child(poly)

	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
		rect.position,
	])
	outline.width = 2.0
	outline.default_color = Color(0.06, 0.08, 0.1)
	_wall_layer.add_child(outline)


func _add_wall_panel(base: Vector2, width: float, height: float) -> void:
	var tex: Texture2D = _textures["console_v2"]
	_add_upright(tex, base, width, height, 3, false)


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


func _ring_line(center: Vector2, radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	var pts := _circle_points(radius, 56)
	pts.append(pts[0])
	line.points = pts
	line.position = center
	line.width = width
	line.default_color = color
	return line


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 240.0, center.y - 16.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(480, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.14))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _band_polygon(center: Vector2, inner: float, outer: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * outer)
	for i in range(segments, -1, -1):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * inner)
	return pts


func _draw() -> void:
	draw_rect(Rect2(-700, -500, 4400, 2400), Color(0.012, 0.016, 0.024))
