extends Node2D

## Command bridge art kit.
##
## The room is a D-shaped command head: a semicircular segmented canopy at the
## top, a navigation dash with two helm seats, and a circular core well at the
## bottom that connects down to the main spine. All shapes are procedural and
## reuse the existing cockpit prop textures; no new external art assets.

const TILT := 0.72
const CORE := "res://art_placeholder/scifi_ship_v2/cockpit/"
const SHIP2 := "res://art_placeholder/scifi_ship_v2/"
const SHIP := "res://art_placeholder/scifi_ship/"

const CALENDAR_SCENE := preload("res://scenes/calendar_prop.tscn")
const KEYPAD_SCENE := preload("res://scenes/keypad_panel.tscn")
const SCREEN_SCRIPT := preload("res://scripts/cockpit_screen.gd")
const STAR_SHADER := preload("res://shaders/starfield_scroll.gdshader")

const CENTER := Vector2(1000.0, 760.0)
const ARC_RADIUS := 640.0
const WELL_CENTER := Vector2(1000.0, 1320.0)
const WELL_RADIUS := 220.0

const VIEWPORT_BASE := Vector2(1000.0, 560.0)
const VIEWPORT_SIZE := Vector2(900.0, 300.0)
const DASHBOARD_BASE := Vector2(1000.0, 700.0)
const DASHBOARD_SIZE := Vector2(1040.0, 260.0)

# Screen apertures in dashboard texture pixels (1536 x 384).
const DASHBOARD_SCREENS := [
	{"center": Vector2(491, 144), "size": Vector2(172, 94), "texture": "screen_radar"},
	{"center": Vector2(764, 138), "size": Vector2(167, 88), "texture": "screen_schematic"},
	{"center": Vector2(1034, 144), "size": Vector2(175, 94), "texture": "screen_waveform"},
	{"center": Vector2(293, 274), "size": Vector2(164, 97), "texture": "screen_status"},
	{"center": Vector2(768, 275), "size": Vector2(173, 132), "texture": "screen_radar"},
	{"center": Vector2(1235, 274), "size": Vector2(169, 96), "texture": "screen_schematic"},
]

var _space_layer: Node2D
var _floor_layer: Node2D
var _wall_layer: Node2D
var _art_layer: Node2D
var _light_layer: Node2D

var _textures := {}
var _region_cache := {}


func _ready() -> void:
	_load_textures()
	_create_layers()
	_build_space()
	_build_floors()
	_build_shell()
	_build_cockpit()
	_build_core_well()
	_build_interactables()
	_build_lights()
	_add_label("COMMAND BRIDGE", Vector2(1000, 1578))
	_add_label("CORE WELL", Vector2(1000, 1512))


func _create_layers() -> void:
	_space_layer = Node2D.new()
	_space_layer.name = "Space"
	_space_layer.z_index = -20
	add_child(_space_layer)

	_floor_layer = Node2D.new()
	_floor_layer.name = "Floors"
	add_child(_floor_layer)

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
	var paths := {
		"floor_corridor": SHIP + "floor_corridor.png",
		"floor_cockpit": CORE + "environment/floor_cockpit.png",
		"wall_straight": SHIP2 + "environment/walls/wall_straight.png",
		"shadow": SHIP2 + "vfx/shadow_prop.png",
		"light_cyan": SHIP2 + "vfx/light_pool_cyan.png",
		"light_amber": SHIP2 + "vfx/light_pool_amber.png",
		"dashboard": CORE + "environment/cockpit_dashboard_base.png",
		"viewport": CORE + "environment/cockpit_viewport_frame.png",
		"starfield": CORE + "environment/cockpit_starfield.png",
		"wall_panel": CORE + "environment/cockpit_wall_panel.png",
		"seat": CORE + "props/cockpit_seat.png",
		"side_console": CORE + "props/cockpit_side_console.png",
		"screen_radar": CORE + "screens/screen_radar.png",
		"screen_schematic": CORE + "screens/screen_schematic.png",
		"screen_waveform": CORE + "screens/screen_waveform.png",
		"screen_status": CORE + "screens/screen_status.png",
	}
	for key in paths:
		_textures[key] = load(paths[key])


func _build_space() -> void:
	var stars := Sprite2D.new()
	stars.texture = _textures["starfield"]
	stars.centered = true
	stars.position = Vector2(1000, 300)
	stars.scale = Vector2(2300.0 / stars.texture.get_width(), 820.0 / stars.texture.get_height())
	stars.z_index = -2
	var material := ShaderMaterial.new()
	material.shader = STAR_SHADER
	stars.material = material
	_space_layer.add_child(stars)

	for i in 26:
		var angle := randf() * TAU
		var radius := randf_range(760.0, 1200.0)
		var dot := _circle_poly(randf_range(1.2, 2.6), 6)
		dot.position = CENTER + Vector2(cos(angle), sin(angle)) * radius
		dot.color = Color(0.7, 0.86, 1.0, randf_range(0.2, 0.65))
		dot.z_index = -1
		_space_layer.add_child(dot)


func _build_floors() -> void:
	var base := Polygon2D.new()
	base.polygon = _floor_polygon()
	base.color = Color(0.14, 0.16, 0.195)
	_floor_layer.add_child(base)

	var floor_tex: Texture2D = _textures["floor_cockpit"]
	var floor := Sprite2D.new()
	floor.texture = floor_tex
	floor.position = Vector2(1000, 1180)
	floor.scale = Vector2(1280.0 / floor_tex.get_width(), 840.0 / floor_tex.get_height())
	floor.modulate = Color(0.78, 0.83, 0.88, 1.0)
	_floor_layer.add_child(floor)

	# Radial deck seams on the command head.
	for i in 7:
		var a := PI + PI * float(i + 1) / 8.0
		var outer := CENTER + Vector2(cos(a), sin(a)) * (ARC_RADIUS - 16.0)
		_add_line(_floor_layer, CENTER, outer, Color(0.34, 0.4, 0.46, 0.4), 3.0)
	for radius in [260.0, 430.0, 560.0]:
		_add_ring(CENTER, radius, Color(0.32, 0.38, 0.44, 0.22), 2.0)

	_add_line(_floor_layer, Vector2(1000, 760), Vector2(1000, 1120), Color(0.32, 0.82, 1.0, 0.16), 6.0)
	_add_line(_floor_layer, Vector2(760, 1180), Vector2(1240, 1180), Color(0.32, 0.82, 1.0, 0.1), 4.0)
	_add_ring(WELL_CENTER, WELL_RADIUS + 46.0, Color(0.9, 0.55, 0.2, 0.22), 4.0)

	# Central navigation floor panel between the seats and the well.
	var panel := _rect_outline(Rect2(880, 880, 240, 120), Color(0.32, 0.82, 1.0, 0.24), 3.0)
	_floor_layer.add_child(panel)
	var panel_inner := _rect_outline(Rect2(896, 896, 208, 88), Color(0.32, 0.82, 1.0, 0.1), 2.0)
	_floor_layer.add_child(panel_inner)


func _build_shell() -> void:
	# Curved hull band behind the canopy.
	var hull := Polygon2D.new()
	hull.polygon = _band_polygon(CENTER, ARC_RADIUS + 8.0, ARC_RADIUS + 190.0, PI, TAU, 26)
	hull.color = Color(0.09, 0.11, 0.145)
	_wall_layer.add_child(hull)

	var hull_rim := Line2D.new()
	hull_rim.points = _arc_points(CENTER, ARC_RADIUS + 190.0, PI, TAU, 26)
	hull_rim.width = 4.0
	hull_rim.default_color = Color(0.1, 0.13, 0.17)
	_wall_layer.add_child(hull_rim)

	# Segmented canopy panes.
	var panes := 9
	var span := PI - 0.18
	var step := span / float(panes)
	for i in panes:
		var a0 := PI + 0.09 + step * float(i)
		var a1 := a0 + step * 0.84
		_build_canopy_pane(a0, a1, i)

	var rim := Line2D.new()
	rim.points = _arc_points(CENTER, ARC_RADIUS + 6.0, PI, TAU, 26)
	rim.width = 4.0
	rim.default_color = Color(0.32, 0.82, 1.0, 0.5)
	_wall_layer.add_child(rim)

	# Side walls.
	_add_wall_block(Rect2(340, 760, 32, 840))
	_add_wall_block(Rect2(1628, 760, 32, 840))
	_add_line(_wall_layer, Vector2(372, 760), Vector2(372, 1600), Color(0.32, 0.72, 0.8, 0.45), 3.0)
	_add_line(_wall_layer, Vector2(1628, 760), Vector2(1628, 1600), Color(0.32, 0.72, 0.8, 0.45), 3.0)

	# Bottom wall and recessed panel behind the core well.
	_add_wall_block(Rect2(340, 1600, 1300, 52))
	_add_rect_poly(Rect2(820, 1600, 360, 52), Color(0.1, 0.12, 0.15))
	_add_line(_wall_layer, Vector2(820, 1600), Vector2(1180, 1600), Color(0.4, 0.85, 1.0, 0.25), 3.0)

	# Angled side bulkheads (future wing access, sealed for now).
	_build_bulkhead(Rect2(372, 1180, 250, 340), false)
	_build_bulkhead(Rect2(1378, 1180, 250, 340), true)

	# Collision.
	_add_arc_collider(ARC_RADIUS + 6.0, ARC_RADIUS + 190.0)
	_add_collider(Rect2(340, 760, 32, 840))
	_add_collider(Rect2(1628, 760, 32, 840))
	_add_collider(Rect2(340, 1600, 1300, 52))
	_add_collider(Rect2(372, 1180, 250, 340))
	_add_collider(Rect2(1378, 1180, 250, 340))

	_add_hazard_stripes(420.0, 800.0, 1580.0)
	_add_hazard_stripes(1200.0, 1580.0, 1580.0)


func _build_bulkhead(rect: Rect2, mirror: bool) -> void:
	var inset := 34.0
	var points := PackedVector2Array([
		Vector2(rect.position.x + inset if not mirror else rect.end.x - inset, rect.position.y),
		Vector2(rect.end.x - inset if not mirror else rect.position.x + inset, rect.position.y),
		Vector2(rect.end.x if not mirror else rect.position.x, rect.end.y),
		Vector2(rect.position.x if not mirror else rect.end.x, rect.end.y),
	])
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = Color(0.1, 0.12, 0.155)
	_wall_layer.add_child(poly)

	var outline := Line2D.new()
	var closed := points.duplicate()
	closed.append(points[0])
	outline.points = closed
	outline.width = 3.0
	outline.default_color = Color(0.05, 0.07, 0.095)
	_wall_layer.add_child(outline)

	var lamp := _circle_poly(8.0, 10)
	lamp.position = (points[0] + points[1]) * 0.5 + Vector2(0, 22)
	lamp.color = Color(0.95, 0.62, 0.22, 0.9)
	_wall_layer.add_child(lamp)

	var label := Label.new()
	label.text = "SEALED"
	label.position = Vector2(rect.get_center().x - 60.0, rect.get_center().y - 12.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(120, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.16))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _build_cockpit() -> void:
	_build_viewport()

	var dashboard := _add_upright(_textures["dashboard"], DASHBOARD_BASE, DASHBOARD_SIZE.x, DASHBOARD_SIZE.y, 4, false)
	_add_dashboard_screens(dashboard)

	_add_wall_panel(_textures["wall_panel"], Vector2(430, 820), 210, 105, 2)
	_add_wall_panel(_textures["wall_panel"], Vector2(1570, 820), 210, 105, 2)

	var left_console := _add_upright(_textures["side_console"], Vector2(500, 1080), 216, 180, 4, true)
	_add_prop_shadow(Vector2(500, 1080), 250.0)
	_add_collider(Rect2(400, 1010, 200, 70))
	_add_console_screen(left_console, _textures["screen_status"], Vector2(-52, 18), Vector2(104, 86))

	var right_console := _add_upright(_textures["side_console"], Vector2(1500, 1080), 216, 180, 4, true)
	_add_prop_shadow(Vector2(1500, 1080), 250.0)
	_add_collider(Rect2(1400, 1010, 200, 70))
	_add_console_screen(right_console, _textures["screen_waveform"], Vector2(-52, 18), Vector2(104, 86))

	_add_prop_shadow(Vector2(860, 1010), 210.0)
	_add_upright(_textures["seat"], Vector2(860, 1010), 165, 220, 5, true)
	_add_collider(Rect2(790, 950, 140, 60))

	_add_prop_shadow(Vector2(1140, 1010), 210.0)
	var right_seat := _add_upright(_textures["seat"], Vector2(1140, 1010), 165, 220, 5, true)
	right_seat.scale.x = -right_seat.scale.x
	_add_collider(Rect2(1070, 950, 140, 60))

	_add_collider(Rect2(480, 640, 1040, 60))
	_add_line(_floor_layer, Vector2(620, 1120), Vector2(1380, 1120), Color(0.32, 0.82, 1.0, 0.14), 4.0)


func _build_viewport() -> void:
	var aperture := _viewport_aperture()

	var stars := Sprite2D.new()
	stars.texture = _textures["starfield"]
	stars.centered = true
	stars.position = aperture.get_center()
	stars.scale = Vector2(aperture.size.x / stars.texture.get_width(), aperture.size.y / stars.texture.get_height())
	stars.z_index = 1
	var material := ShaderMaterial.new()
	material.shader = STAR_SHADER
	stars.material = material
	_art_layer.add_child(stars)

	var sheen := Polygon2D.new()
	sheen.polygon = PackedVector2Array([
		Vector2(aperture.position.x, aperture.position.y + aperture.size.y * 0.18),
		Vector2(aperture.position.x + aperture.size.x * 0.45, aperture.position.y),
		Vector2(aperture.position.x + aperture.size.x * 0.68, aperture.position.y),
		Vector2(aperture.position.x, aperture.position.y + aperture.size.y * 0.52),
	])
	sheen.color = Color(0.45, 0.8, 1.0, 0.045)
	_art_layer.add_child(sheen)

	_add_upright(_textures["viewport"], VIEWPORT_BASE, VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, 2, false)


func _viewport_aperture() -> Rect2:
	var left := VIEWPORT_BASE.x - VIEWPORT_SIZE.x / 2.0
	var top := VIEWPORT_BASE.y - VIEWPORT_SIZE.y
	return Rect2(
		left + VIEWPORT_SIZE.x * 0.1725,
		top + VIEWPORT_SIZE.y * 0.1777,
		VIEWPORT_SIZE.x * (0.8236 - 0.1725),
		VIEWPORT_SIZE.y * (0.8438 - 0.1777)
	)


func _build_core_well() -> void:
	var shadow := Sprite2D.new()
	shadow.texture = _textures["shadow"]
	shadow.position = WELL_CENTER
	shadow.scale = Vector2(3.1, 2.5)
	shadow.modulate = Color(0.1, 0.14, 0.18, 0.65)
	_art_layer.add_child(shadow)

	var glass := _circle_poly(WELL_RADIUS, 64)
	glass.position = WELL_CENTER
	glass.color = Color(0.025, 0.045, 0.08)
	_art_layer.add_child(glass)

	var inner_ring := _ring_poly(WELL_RADIUS - 10.0, WELL_RADIUS - 4.0, 64)
	inner_ring.position = WELL_CENTER
	inner_ring.color = Color(0.28, 0.58, 0.68, 0.55)
	_art_layer.add_child(inner_ring)

	# Diagonal reflection across the glass.
	var highlight := Polygon2D.new()
	highlight.polygon = PackedVector2Array([
		WELL_CENTER + Vector2(-124, 96),
		WELL_CENTER + Vector2(-84, 126),
		WELL_CENTER + Vector2(126, -84),
		WELL_CENTER + Vector2(86, -114),
	])
	highlight.color = Color(0.62, 0.86, 1.0, 0.16)
	_art_layer.add_child(highlight)

	var highlight_thin := Line2D.new()
	highlight_thin.points = PackedVector2Array([
		WELL_CENTER + Vector2(-96, 84),
		WELL_CENTER + Vector2(96, -84),
	])
	highlight_thin.width = 2.0
	highlight_thin.default_color = Color(0.7, 0.92, 1.0, 0.3)
	_art_layer.add_child(highlight_thin)

	for i in 8:
		var a := TAU * float(i) / 8.0
		_add_line(_art_layer, WELL_CENTER + Vector2(cos(a), sin(a)) * 62.0, WELL_CENTER + Vector2(cos(a), sin(a)) * (WELL_RADIUS - 14.0), Color(0.22, 0.34, 0.44, 0.4), 2.0)

	for i in 12:
		var a := TAU * float(i) / 12.0 + 0.3
		var dot := _circle_poly(randf_range(1.2, 2.4), 6)
		dot.position = WELL_CENTER + Vector2(cos(a), sin(a)) * randf_range(60.0, WELL_RADIUS - 40.0)
		dot.color = Color(0.75, 0.9, 1.0, randf_range(0.25, 0.7))
		_art_layer.add_child(dot)

	# Octagonal outer frame.
	for i in 8:
		var a0 := TAU * float(i) / 8.0
		var a1 := TAU * float(i + 1) / 8.0
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([
			WELL_CENTER + Vector2(cos(a0), sin(a0)) * WELL_RADIUS,
			WELL_CENTER + Vector2(cos(a1), sin(a1)) * WELL_RADIUS,
			WELL_CENTER + Vector2(cos(a1), sin(a1)) * (WELL_RADIUS + 54.0),
			WELL_CENTER + Vector2(cos(a0), sin(a0)) * (WELL_RADIUS + 54.0),
		])
		quad.color = Color(0.2, 0.23, 0.27)
		_art_layer.add_child(quad)

		var seam := Line2D.new()
		seam.points = PackedVector2Array([
			WELL_CENTER + Vector2(cos(a0), sin(a0)) * WELL_RADIUS,
			WELL_CENTER + Vector2(cos(a0), sin(a0)) * (WELL_RADIUS + 54.0),
		])
		seam.width = 2.0
		seam.default_color = Color(0.06, 0.08, 0.1)
		_art_layer.add_child(seam)

		var bolt := _circle_poly(4.0, 8)
		bolt.position = WELL_CENTER + Vector2(cos(a0), sin(a0)) * (WELL_RADIUS + 27.0)
		bolt.color = Color(0.55, 0.42, 0.2)
		_art_layer.add_child(bolt)

	var hub := _circle_poly(46.0, 24)
	hub.position = WELL_CENTER
	hub.color = Color(0.16, 0.19, 0.23)
	_art_layer.add_child(hub)

	var hub_core := _circle_poly(28.0, 20)
	hub_core.position = WELL_CENTER
	hub_core.color = Color(0.04, 0.09, 0.13)
	_art_layer.add_child(hub_core)

	var hub_light := _circle_poly(9.0, 12)
	hub_light.position = WELL_CENTER
	hub_light.color = Color(0.35, 0.9, 1.0, 0.85)
	_art_layer.add_child(hub_light)

	# Red hazard band at the bottom edge of the well.
	_add_rect_poly(Rect2(810, 1548, 380, 26), Color(0.24, 0.08, 0.06))
	var x := 822.0
	while x < 1176.0:
		var stripe := Line2D.new()
		stripe.points = PackedVector2Array([Vector2(x, 1572), Vector2(x + 14, 1550)])
		stripe.width = 7.0
		stripe.default_color = Color(0.92, 0.55, 0.18, 0.8)
		_wall_layer.add_child(stripe)
		x += 32.0


func _build_interactables() -> void:
	var calendar := CALENDAR_SCENE.instantiate()
	calendar.position = Vector2(1530, 760)
	calendar.z_index = 3
	add_child(calendar)

	var keypad := KEYPAD_SCENE.instantiate()
	keypad.position = Vector2(1560, 1080)
	keypad.z_index = 3
	add_child(keypad)


func _build_lights() -> void:
	_add_light(Vector2(1000, 540), 980.0, Color(0.35, 0.8, 1.0, 0.16))
	_add_light(WELL_CENTER, 760.0, Color(0.4, 0.85, 1.0, 0.14))
	_add_light(Vector2(500, 1080), 420.0, Color(0.35, 0.85, 1.0, 0.08))
	_add_light(Vector2(1500, 1080), 420.0, Color(0.35, 0.85, 1.0, 0.08))
	_add_light(Vector2(430, 860), 360.0, Color(1.0, 0.68, 0.32, 0.1))
	_add_light(Vector2(450, 1360), 460.0, Color(1.0, 0.55, 0.25, 0.08))
	_add_light(Vector2(1550, 1360), 460.0, Color(1.0, 0.55, 0.25, 0.08))


func _build_canopy_pane(a0: float, a1: float, index: int) -> void:
	var inner := ARC_RADIUS + 18.0
	var outer := ARC_RADIUS + 176.0
	var quad := Polygon2D.new()
	quad.polygon = PackedVector2Array([
		CENTER + Vector2(cos(a0), sin(a0)) * inner,
		CENTER + Vector2(cos(a1), sin(a1)) * inner,
		CENTER + Vector2(cos(a1), sin(a1)) * outer,
		CENTER + Vector2(cos(a0), sin(a0)) * outer,
	])
	var tint := 0.9 + 0.1 * sin(float(index) * 1.7)
	quad.color = Color(0.055 * tint, 0.1 * tint, 0.19 * tint, 1.0)
	quad.z_index = 1
	_wall_layer.add_child(quad)

	var frame := Line2D.new()
	frame.points = PackedVector2Array([
		CENTER + Vector2(cos(a0), sin(a0)) * inner,
		CENTER + Vector2(cos(a0), sin(a0)) * outer,
		CENTER + Vector2(cos(a1), sin(a1)) * outer,
		CENTER + Vector2(cos(a1), sin(a1)) * inner,
		CENTER + Vector2(cos(a0), sin(a0)) * inner,
	])
	frame.width = 3.0
	frame.default_color = Color(0.08, 0.11, 0.15)
	frame.z_index = 2
	_wall_layer.add_child(frame)

	var glass_line := Line2D.new()
	var am := (a0 + a1) * 0.5
	glass_line.points = PackedVector2Array([
		CENTER + Vector2(cos(a0 + 0.02), sin(a0 + 0.02)) * (inner + 26.0),
		CENTER + Vector2(cos(am), sin(am)) * (outer - 40.0),
	])
	glass_line.width = 2.0
	glass_line.default_color = Color(0.4, 0.72, 1.0, 0.18)
	glass_line.z_index = 3
	_wall_layer.add_child(glass_line)

	for i in 3:
		var a := lerpf(a0, a1, randf_range(0.2, 0.8))
		var r := randf_range(inner + 24.0, outer - 24.0)
		var dot := _circle_poly(randf_range(1.0, 2.2), 6)
		dot.position = CENTER + Vector2(cos(a), sin(a)) * r
		dot.color = Color(0.72, 0.88, 1.0, randf_range(0.25, 0.7))
		dot.z_index = 3
		_wall_layer.add_child(dot)


func _add_dashboard_screens(dashboard: Sprite2D) -> void:
	for spec in DASHBOARD_SCREENS:
		var tex := _textures[spec["texture"]] as Texture2D
		var area := (spec["size"] as Vector2) - Vector2(8, 8)
		var center := (spec["center"] as Vector2) - Vector2(768, 192)
		_add_screen_child(dashboard, tex, center, area, 0.0)


func _add_console_screen(console: Sprite2D, tex: Texture2D, local_center: Vector2, area: Vector2) -> void:
	_add_screen_child(console, tex, local_center, area, 0.0)


func _add_screen_child(parent: Sprite2D, tex: Texture2D, local_center: Vector2, area: Vector2, z: int) -> void:
	var screen := Sprite2D.new()
	screen.texture = tex
	screen.centered = true
	screen.region_enabled = true
	var region_h := clampf(tex.get_height() * (area.y / area.x), 1.0, float(tex.get_height()))
	var region_w := tex.get_width()
	screen.region_rect = Rect2(0, (tex.get_height() - region_h) / 2.0, region_w, region_h)
	screen.scale = Vector2(area.x / region_w, area.y / region_h)
	screen.position = local_center
	screen.z_index = z
	screen.set_script(SCREEN_SCRIPT)
	screen.set("flicker_speed", 5.0 + randf() * 4.0)
	screen.set("scan_speed", 18.0 + randf() * 16.0)
	parent.add_child(screen)


func _add_wall_panel(tex: Texture2D, base: Vector2, width: float, height: float, z: int) -> void:
	_add_upright(tex, base, width, height, z, false)


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


func _add_wall_block(rect: Rect2) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	poly.color = Color(0.13, 0.155, 0.195)
	_wall_layer.add_child(poly)

	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
		rect.position,
	])
	outline.width = 2.0
	outline.default_color = Color(0.05, 0.065, 0.085)
	_wall_layer.add_child(outline)

	var edge := Line2D.new()
	edge.points = PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0)])
	edge.width = 3.0
	edge.default_color = Color(0.3, 0.72, 0.8, 0.55)
	_wall_layer.add_child(edge)


func _add_rect_poly(rect: Rect2, color: Color) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
	])
	poly.color = color
	_wall_layer.add_child(poly)


func _rect_outline(rect: Rect2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.end,
		rect.position + Vector2(0, rect.size.y),
		rect.position,
	])
	line.width = width
	line.default_color = color
	return line


func _add_hazard_stripes(x0: float, x1: float, y: float) -> void:
	var x := x0
	var color := Color(0.78, 0.6, 0.18, 0.5)
	while x < x1:
		var line := Line2D.new()
		line.points = PackedVector2Array([Vector2(x, y), Vector2(x + 46, y + 40)])
		line.width = 8.0
		line.default_color = color
		_wall_layer.add_child(line)
		x += 94.0


func _add_line(layer: Node2D, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = width
	line.default_color = color
	layer.add_child(line)


func _add_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	var ring := Line2D.new()
	ring.points = _closed(_arc_points(Vector2.ZERO, radius, 0.0, TAU, 64))
	ring.position = center
	ring.width = width
	ring.default_color = color
	_floor_layer.add_child(ring)


func _add_prop_shadow(base: Vector2, width: float) -> void:
	var shadow := Sprite2D.new()
	shadow.texture = _textures["shadow"]
	shadow.position = base
	var s := width * 1.15 / 256.0
	shadow.scale = Vector2(s, s)
	shadow.z_index = 0
	_art_layer.add_child(shadow)


func _add_light(center: Vector2, diameter: float, color: Color) -> void:
	var tex: Texture2D = _textures["light_cyan"] if color.b >= color.r else _textures["light_amber"]
	var sprite := Sprite2D.new()
	sprite.texture = tex
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


func _add_arc_collider(inner_radius: float, outer_radius: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var poly := CollisionPolygon2D.new()
	poly.polygon = _band_polygon(CENTER, inner_radius, outer_radius, PI, TAU, 26)
	body.add_child(poly)
	add_child(body)


func _add_label(text: String, center: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(center.x - 220.0, center.y - 18.0 / TILT)
	label.scale = Vector2(1.0, 1.0 / TILT)
	label.size = Vector2(440, 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.16))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


func _used_rect(tex: Texture2D) -> Rect2i:
	var key := tex.resource_path
	if not _region_cache.has(key):
		var image := tex.get_image()
		if image:
			_region_cache[key] = image.get_used_rect()
		else:
			_region_cache[key] = Rect2i(0, 0, tex.get_width(), tex.get_height())
	return _region_cache[key]


func _floor_polygon() -> PackedVector2Array:
	var pts := _arc_points(CENTER, ARC_RADIUS, PI, TAU, 26)
	pts.append(Vector2(1640, 1600))
	pts.append(Vector2(360, 1600))
	return pts


func _arc_points(center: Vector2, radius: float, start: float, end: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var a := lerpf(start, end, t)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


func _band_polygon(center: Vector2, inner: float, outer: float, start: float, end: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var t := float(i) / float(segments)
		var a := lerpf(start, end, t)
		pts.append(center + Vector2(cos(a), sin(a)) * outer)
	for i in range(segments, -1, -1):
		var t := float(i) / float(segments)
		var a := lerpf(start, end, t)
		pts.append(center + Vector2(cos(a), sin(a)) * inner)
	return pts


func _circle_poly(radius: float, segments: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = _arc_points(Vector2.ZERO, radius, 0.0, TAU, segments)
	return poly


func _ring_poly(inner: float, outer: float, segments: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = _band_polygon(Vector2.ZERO, inner, outer, 0.0, TAU, segments)
	return poly


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _draw() -> void:
	draw_rect(Rect2(-800, -600, 3600, 3000), Color(0.012, 0.016, 0.024))
