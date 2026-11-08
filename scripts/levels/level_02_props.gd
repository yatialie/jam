extends Node2D

## 第二关机械臂小 Boss 的占位道具：操作台、被砸碎的货箱、地面警戒环。
## 全部复用现有占位贴图与程序化绘制，不新增外部美术资产。

const SHIP2_DIR := "res://art_placeholder/scifi_ship_v2/"
const TILT := 0.72

@export var arm_path := NodePath("../Arm")
@export var console_point_path := NodePath("../ConsolePoint")
@export var smash_point_path := NodePath("../SmashPoint")
@export var console_width := 296.0
@export var console_height := 300.0
@export var crate_width := 190.0
@export var crate_height := 160.0

var _textures := {}
var _region_cache := {}
var _art_layer: Node2D
var _fx_layer: Node2D
var _console_sprite: Sprite2D
var _smash_crate: Sprite2D
var _smash_body: StaticBody2D
var _arm_center := Vector2.ZERO
var _console_base := Vector2.ZERO
var _smash_base := Vector2.ZERO

## 电弧起点相对 ConsolePoint 的本地偏移：落在操作台屏幕中央。
const CONSOLE_ARC_OFFSET := Vector2(0.0, -250.0)


## 玩家被电击时：主电弧从操作台屏幕连到玩家胸口，身体区域再叠加纵向/横向电弧覆盖整个人。
class ElectricArc:
	extends Node2D

	## 以胸口锚点为原点的身体覆盖范围（本地坐标）。
	const BODY_TOP := -100.0
	const BODY_BOTTOM := 150.0
	const BODY_HALF_WIDTH := 40.0

	var from_point := Vector2.ZERO
	var to_point := Vector2.ZERO
	var life := 1.0

	func _ready() -> void:
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		self.material = material
		set_process(true)

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(life * 2.0, 0.0, 1.0)
		# 主电弧：操作台 → 玩家胸口。
		for bolt in 3:
			_draw_bolt(from_point, to_point, 9, Vector2(16.0, 12.0), fade)
		# 身体覆盖：数道纵向电弧从头缠绕到脚。
		for bolt in 3:
			var points := PackedVector2Array()
			var segments := 8
			var center_x := to_point.x + randf_range(-BODY_HALF_WIDTH, BODY_HALF_WIDTH) * 0.6
			for s in segments:
				var t := float(s) / float(segments - 1)
				points.append(Vector2(
					center_x + randf_range(-BODY_HALF_WIDTH, BODY_HALF_WIDTH),
					to_point.y + lerpf(BODY_TOP, BODY_BOTTOM, t)))
			_draw_polyline(points, fade)
		# 横向电弧：胸口与腰部各一道，形成包裹感。
		for row in 2:
			var row_y := to_point.y + (-18.0 if row == 0 else 66.0)
			var points := PackedVector2Array()
			var segments := 6
			for s in segments:
				var t := float(s) / float(segments - 1)
				points.append(Vector2(
					to_point.x + lerpf(-BODY_HALF_WIDTH - 18.0, BODY_HALF_WIDTH + 18.0, t),
					row_y + randf_range(-12.0, 12.0)))
			_draw_polyline(points, fade)
		# 两端迸射的短电弧。
		for i in 5:
			var origin := from_point if i < 2 else to_point + Vector2(
				randf_range(-BODY_HALF_WIDTH, BODY_HALF_WIDTH), randf_range(BODY_TOP, BODY_BOTTOM) * 0.5)
			var spark_dir := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(18.0, 48.0)
			draw_line(origin, origin + spark_dir, Color(0.7, 0.96, 1.0, 0.7 * fade), 2.0)

	func _draw_bolt(a: Vector2, b: Vector2, segments: int, jitter: Vector2, fade: float) -> void:
		var points := PackedVector2Array()
		for s in segments:
			var t := float(s) / float(segments - 1)
			var point := a.lerp(b, t)
			if s > 0 and s < segments - 1:
				point += Vector2(randf_range(-jitter.x, jitter.x), randf_range(-jitter.y, jitter.y))
			points.append(point)
		_draw_polyline(points, fade)

	func _draw_polyline(points: PackedVector2Array, fade: float) -> void:
		draw_polyline(points, Color(0.55, 0.95, 1.0, 0.55 * fade), 3.0, true)
		draw_polyline(points, Color(1.0, 1.0, 1.0, 0.5 * fade), 1.2, true)


func _ready() -> void:
	_load_textures()

	_art_layer = Node2D.new()
	_art_layer.name = "Art"
	add_child(_art_layer)

	_fx_layer = Node2D.new()
	_fx_layer.name = "FX"
	add_child(_fx_layer)

	_resolve_points()
	_build_console()
	_build_crate()
	_build_lights()


## 首次校准剧情：操作台漏电，电弧从操作台屏幕连到玩家胸口，并覆盖玩家全身。
func play_electrocution(target_global: Vector2, duration: float) -> void:
	if _fx_layer == null:
		return
	var arc := ElectricArc.new()
	# _console_base 已经是本节点（Projection 投影）的局部坐标，不能再做一次 to_local 转换。
	arc.from_point = _console_base + CONSOLE_ARC_OFFSET
	arc.to_point = _fx_layer.to_local(target_global)
	arc.life = maxf(duration, 0.4)
	arc.z_index = 13
	_fx_layer.add_child(arc)
	if _console_sprite:
		_console_sprite.modulate = Color(0.75, 1.5, 1.8, 1.0)


func get_smash_point() -> Vector2:
	return to_global(_smash_base)


func smash_crate() -> void:
	if _smash_crate == null:
		return
	_smash_crate.visible = false
	if _smash_body:
		for child in _smash_body.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", true)
	_spawn_debris(_smash_base + Vector2(0, -20), Color(0.5, 0.37, 0.23), 12)


func destroy_console() -> void:
	if _console_sprite:
		_console_sprite.modulate = Color(0.36, 0.24, 0.24, 1.0)
	_spawn_debris(_console_base + Vector2(0, -70), Color(0.34, 0.42, 0.46), 9)
	_spawn_debris(_console_base + Vector2(20, -120), Color(1.0, 0.55, 0.2), 6)


func spawn_impact_debris(world_point: Vector2) -> void:
	_spawn_debris(to_local(world_point), Color(0.55, 0.4, 0.24), 10)


func _resolve_points() -> void:
	var arm := get_node_or_null(arm_path) as Node2D
	var console := get_node_or_null(console_point_path) as Node2D
	var smash := get_node_or_null(smash_point_path) as Node2D
	_arm_center = arm.position if arm else Vector2(1480, 1376)
	_console_base = console.position if console else Vector2(960, 1536)
	_smash_base = smash.position if smash else Vector2(1180, 1496)


func _build_console() -> void:
	_add_prop_shadow(_console_base, 320.0)
	_console_sprite = _add_upright(_textures["console_v2"], _console_base, console_width, console_height)
	_add_collider(Rect2(_console_base.x - 100.0, _console_base.y - 110.0, 200, 110))


func _build_crate() -> void:
	_add_prop_shadow(_smash_base, 220.0)
	_smash_crate = _add_upright(_textures["crate_v2"], _smash_base, crate_width, crate_height)
	_smash_body = _add_collider(Rect2(_smash_base.x - 72.0, _smash_base.y - 80.0, 144, 80))


func _build_lights() -> void:
	_add_light(_arm_center, 760.0, Color(1.0, 0.55, 0.25, 0.12))
	_add_light(_console_base, 620.0, Color(1.0, 0.68, 0.32, 0.14))
	_add_light(Vector2(_console_base.x - 300.0, _console_base.y + 120.0), 460.0, Color(0.4, 0.9, 1.0, 0.1))


func _draw() -> void:
	# 中央机械臂作业区的地面标线
	draw_arc(_arm_center, 520.0, 0.0, TAU, 64, Color(0.9, 0.55, 0.18, 0.16), 3.0)
	draw_arc(_arm_center, 360.0, 0.0, TAU, 48, Color(0.9, 0.55, 0.18, 0.2), 2.0)


func _load_textures() -> void:
	_textures["console_v2"] = load(SHIP2_DIR + "props/console_terminal_01.png")
	_textures["crate_v2"] = load(SHIP2_DIR + "props/cargo_crate_large.png")
	_textures["shadow_prop"] = load(SHIP2_DIR + "vfx/shadow_prop.png")
	_textures["light_cyan"] = load(SHIP2_DIR + "vfx/light_pool_cyan.png")
	_textures["light_amber"] = load(SHIP2_DIR + "vfx/light_pool_amber.png")


func _add_upright(tex: Texture2D, base: Vector2, width: float, height: float, z: int = 1) -> Sprite2D:
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
	sprite.z_index = 0
	_art_layer.add_child(sprite)


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
