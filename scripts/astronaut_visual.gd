extends AnimatedSprite2D

const CHARACTER_ROOT := "res://art_placeholder/scifi_ship_v2/characters/"
const TILT := 0.72
const CELL := 384
const IDLE_FPS := 24.0
const DEATH_FPS := 24.0
const RESPAWN_FPS := 30.0
const DIR_NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const DIR_FALLBACK := {
	"ne": "n",
	"nw": "n",
	"e": "s",
	"se": "e",
	"sw": "w",
	"w": "s",
}

@export var character_id := "astronaut"
@export var world_height := 150.0
@export var walk_fps_scale := 1.0

var facing := Vector2.DOWN
var shoot_time := 0.0

var _frame_scale := 1.0
var _has_death := false
var _death_playing := false
var _has_respawn := false
var _respawn_playing := false


func _ready() -> void:
	centered = false
	_build_animations()
	_apply_layout()
	play("idle_s")


func _process(delta: float) -> void:
	if _death_playing or _respawn_playing:
		return

	shoot_time = maxf(shoot_time - delta, 0.0)

	var body := get_parent() as CharacterBody2D
	var speed := body.velocity.length() if body else 0.0
	var direction := _direction_name()

	var anim := "idle_" + direction
	if shoot_time > 0.0:
		anim = "shoot_" + direction
	elif speed > 8.0:
		anim = "walk_" + direction

	if animation != anim:
		play(anim)

	speed_scale = clampf(speed / 250.0, 0.75, 1.8) if anim.begins_with("walk") else 1.0


func trigger_shoot() -> void:
	shoot_time = 0.3


func set_character(id: String) -> void:
	character_id = id
	_death_playing = false
	_respawn_playing = false
	_build_animations()
	_apply_layout()
	play("idle_s")


## 播放死亡序列；返回 false 表示该角色没有死亡素材。
func play_death() -> bool:
	if not _has_death:
		return false
	_death_playing = true
	speed_scale = 1.0
	play("death")
	return true


## 复活后解除死亡锁定并回到待机。
func clear_death() -> void:
	_death_playing = false
	speed_scale = 1.0
	play("idle_s")


func get_death_duration() -> float:
	if not _has_death:
		return 0.0
	return float(sprite_frames.get_frame_count("death")) / DEATH_FPS


## 播放重生序列；返回 false 表示该角色没有重生素材。
func play_respawn() -> bool:
	if not _has_respawn:
		return false
	_respawn_playing = true
	speed_scale = 1.0
	play("respawn")
	return true


## 重生动画结束后解除锁定并回到待机。
func clear_respawn() -> void:
	_respawn_playing = false
	speed_scale = 1.0
	play("idle_s")


func get_respawn_duration() -> float:
	if not _has_respawn:
		return 0.0
	return float(sprite_frames.get_frame_count("respawn")) / RESPAWN_FPS


func _direction_name() -> String:
	var index := int(round(facing.angle() / (PI / 4.0))) % 8
	if index < 0:
		index += 8
	return DIR_NAMES[index]


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	for direction in DIR_NAMES:
		var idle := _load_texture("idle", direction)
		var walk := _load_texture("walk", direction)
		var shoot := _load_texture("shoot", direction)

		var walk_count := maxi(1, walk.get_width() / CELL)
		_add_frames(frames, "idle_" + direction, idle, IDLE_FPS, true)
		_add_frames(frames, "walk_" + direction, walk, float(walk_count) * walk_fps_scale, true)
		_add_frames(frames, "shoot_" + direction, shoot, 14.0, true)

	# 死亡序列只有正面一套，存在时才注册；缺少素材的角色继续使用旧淡出流程。
	var death_texture := _load_death_texture()
	_has_death = death_texture != null
	if _has_death:
		_add_frames(frames, "death", death_texture, DEATH_FPS, false)

	# 重生序列同样只有正面一套。
	var respawn_texture := _load_respawn_texture()
	_has_respawn = respawn_texture != null
	if _has_respawn:
		_add_frames(frames, "respawn", respawn_texture, RESPAWN_FPS, false)

	sprite_frames = frames


func _load_texture(action: String, direction: String) -> Texture2D:
	var base := CHARACTER_ROOT + character_id + "/" + character_id
	var direct := base + "_" + action + "_" + direction + ".png"
	if ResourceLoader.exists(direct):
		return load(direct)

	if direction != "s":
		var alt := str(DIR_FALLBACK.get(direction, "s"))
		if alt != direction:
			var alt_path := base + "_" + action + "_" + alt + ".png"
			if ResourceLoader.exists(alt_path):
				return load(alt_path)

		var fallback := base + "_" + action + "_s.png"
		if ResourceLoader.exists(fallback):
			return load(fallback)

	var idle := base + "_idle_" + direction + ".png"
	if ResourceLoader.exists(idle):
		return load(idle)
	return load(base + "_idle_s.png")


func _load_death_texture() -> Texture2D:
	var path := CHARACTER_ROOT + character_id + "/" + character_id + "_death.png"
	return load(path) if ResourceLoader.exists(path) else null


func _load_respawn_texture() -> Texture2D:
	var path := CHARACTER_ROOT + character_id + "/" + character_id + "_respawn.png"
	return load(path) if ResourceLoader.exists(path) else null


func _add_frames(frames: SpriteFrames, anim: String, texture: Texture2D, fps: float, loop: bool) -> void:
	var count := maxi(1, texture.get_width() / CELL)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(anim, atlas)


func _apply_layout() -> void:
	var idle: Texture2D = load(CHARACTER_ROOT + character_id + "/" + character_id + "_idle_s.png")
	# idle 可能是整段序列帧，只取第一帧作为身高和脚底基准
	var image := idle.get_image()
	var frame := image.get_region(Rect2i(0, 0, mini(CELL, image.get_width()), mini(CELL, image.get_height())))
	var used := _solid_bounds(frame)
	_frame_scale = world_height / float(used.size.y)

	scale = Vector2(_frame_scale, _frame_scale / TILT)
	position = Vector2(
		-(used.position.x + used.size.x / 2.0) * _frame_scale,
		-used.end.y * _frame_scale / TILT
	)


## 逐列/逐行剔除水印残点等零散像素，避免 used_rect 被拉宽导致角色偏离原点
func _solid_bounds(image: Image) -> Rect2i:
	var used := image.get_used_rect()
	var left := used.position.x
	var right := used.end.x - 1
	var top := used.position.y
	var bottom := used.end.y - 1
	while left < right and _column_coverage(image, left, top, bottom) < 4:
		left += 1
	while right > left and _column_coverage(image, right, top, bottom) < 4:
		right -= 1
	while top < bottom and _row_coverage(image, top, left, right) < 4:
		top += 1
	while bottom > top and _row_coverage(image, bottom, left, right) < 4:
		bottom -= 1
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


func _column_coverage(image: Image, x: int, from_y: int, to_y: int) -> int:
	var count := 0
	for y in range(from_y, to_y + 1):
		if image.get_pixel(x, y).a > 0.16:
			count += 1
	return count


func _row_coverage(image: Image, y: int, from_x: int, to_x: int) -> int:
	var count := 0
	for x in range(from_x, to_x + 1):
		if image.get_pixel(x, y).a > 0.16:
			count += 1
	return count
