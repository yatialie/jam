extends "res://scripts/enemy.gd"

## 幽浮宇航员：16 帧远程攻击序列 + 26 帧悬浮移动循环。
## 前两帧为起手，第 3 帧星光爆闪时发射金色弹丸，随后 13 帧收招漂移。

const TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/ufo_astronaut/ufo_astronaut_attack.png"
const MOVE_TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/ufo_astronaut/ufo_astronaut_move.png"
const CELL := 512
const FRAME_COUNT := 16
const MOVE_FRAME_COUNT := 26
const MOVE_FPS := 20.0
## 低于该速度视为悬停待机，避免减速收尾时反复闪切移动帧。
const MOVE_THRESHOLD := 8.0
const WORLD_HEIGHT := 112.0
const TILT := 0.72
## 站立时头部中心与尾迹底端，取自素材实测值。
const PIVOT_X := 264.0
const PIVOT_Y := 387.0
## 待机帧主体高度，用于把美术像素换算成世界高度。
const REFERENCE_HEIGHT := 254.0
## 尾迹底端离地高度，保持悬浮感。
const HOVER_LIFT := 30.0
const BOB_HEIGHT := 4.5
const BOB_SPEED := 1.7
const SWAY_WIDTH := 3.5
const SWAY_SPEED := 0.9
## 收招后的悬浮姿态。
const IDLE_FRAME := 1
## 星光爆闪帧，弹丸在此生成。
const RELEASE_FRAME := 2
const ATTACK_FPS := 24.0
## 弹丸出生点（投影层局部坐标），对应头盔中心。
const MUZZLE_LOCAL := Vector2(0, -172)
const BOLT_TINT := Color(1.0, 0.82, 0.32, 1.0)

@onready var sprite: AnimatedSprite2D = $Visual

var _frame_scale := 1.0
var _attack_playing := false
var _shot_fired := false
var _float_time := 0.0


func _ready() -> void:
	use_sprite_visual = true
	kind = Kind.RANGED
	super._ready()
	_frame_scale = WORLD_HEIGHT / REFERENCE_HEIGHT
	_build_visual()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)


## 全身受击体：竖向胶囊覆盖头盔、躯干与尾迹。
func _configure_hurtbox() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 32.0
	shape.height = 160.0
	$HurtBox.position = Vector2(0, -95.0)
	$HurtBox.rotation = 0.0
	$HurtBox.get_node("CollisionShape2D").shape = shape


func _build_visual() -> void:
	var texture: Texture2D = load(TEXTURE_PATH)
	var move_texture: Texture2D = load(MOVE_TEXTURE_PATH)
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", false)
	frames.add_frame("idle", _atlas_frame(texture, IDLE_FRAME))

	frames.add_animation("move")
	frames.set_animation_speed("move", MOVE_FPS)
	frames.set_animation_loop("move", true)
	for i in MOVE_FRAME_COUNT:
		frames.add_frame("move", _atlas_frame(move_texture, i))

	frames.add_animation("attack")
	frames.set_animation_speed("attack", ATTACK_FPS)
	frames.set_animation_loop("attack", false)
	for i in FRAME_COUNT:
		frames.add_frame("attack", _atlas_frame(texture, i))

	sprite.sprite_frames = frames
	sprite.play("idle")
	_layout()


func _atlas_frame(texture: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(index * CELL, 0, CELL, CELL)
	return atlas


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if sprite == null:
		return
	_float_time += delta
	_layout()
	if _dead:
		return
	_refresh_locomotion()


## 按当前速度在悬停待机与悬浮移动之间切换；攻击序列播放期间不被覆盖。
func _refresh_locomotion() -> void:
	if _attack_playing:
		return
	if velocity.length() > MOVE_THRESHOLD:
		if sprite.animation != &"move":
			sprite.play("move")
	elif sprite.animation != &"idle":
		sprite.play("idle")


func _layout() -> void:
	var s := _frame_scale * visual_scale
	var bob := sin(_float_time * BOB_SPEED) * BOB_HEIGHT
	var sway := sin(_float_time * SWAY_SPEED) * SWAY_WIDTH
	sprite.scale = Vector2(s, s / TILT)
	sprite.position = Vector2(-PIVOT_X * s + sway, -(PIVOT_Y * s + HOVER_LIFT + bob) / TILT)


func _fire(_direction: Vector2) -> void:
	if _attack_playing:
		return
	_attack_cd = fire_interval
	_attack_playing = true
	_shot_fired = false
	sprite.play("attack")


func _on_frame_changed() -> void:
	if not _attack_playing or _shot_fired:
		return
	if sprite.frame >= RELEASE_FRAME:
		_shot_fired = true
		_release_shot()


func _release_shot() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# 在投影空间内计算弹道，避免父节点纵向缩放导致偏移。
	var space := get_parent() as Node2D
	var target_local := space.to_local(_player.global_position)
	var spawn_local := space.to_local(global_position) + MUZZLE_LOCAL
	var aim := (target_local - spawn_local).normalized()

	var bullet := ENEMY_PROJECTILE.instantiate()
	bullet.direction = aim
	bullet.speed = projectile_speed
	bullet.tint = BOLT_TINT
	space.add_child(bullet)
	bullet.position = spawn_local


func _on_animation_finished() -> void:
	if not _attack_playing:
		return
	_attack_playing = false
	_refresh_locomotion()


func _draw() -> void:
	# 悬浮阴影落在地面，警戒感叹号移动到头盔上方。
	_ellipse(Vector2(0, 4), Vector2(22, 8), Color(0, 0, 0, 0.22))
	if _alert_flash > 0.0 or _state == State.ALERT:
		var alpha := clampf(_alert_flash / 0.6, 0.0, 1.0)
		var color := Color(1.0, 0.62, 0.22, alpha)
		draw_rect(Rect2(Vector2(-3.0, -225.0), Vector2(6.0, 16.0)), color)
		draw_circle(Vector2(0.0, -201.0), 4.0, color)
