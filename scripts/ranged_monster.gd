extends "res://scripts/enemy.gd"

## 远程原创怪：40 帧水晶水母攻击序列 + 24 帧游动序列。
## 静止/警戒时保持首帧悬浮呼吸，实际位移时播放游动动画，开火时完整播放一次攻击动画并在爆发帧释放弹丸。

const TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/ranged/ranged_attack.png"
const MOVE_TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/ranged/ranged_move.png"
const CELL := 512
const COLUMNS := 8
const TOTAL_FRAMES := 40
const MOVE_TOTAL_FRAMES := 24
const MOVE_FPS := 24.0
## 低于该速度视为悬浮静止，避免减速收尾时反复闪切游动帧
const MOVE_THRESHOLD := 8.0
const WORLD_HEIGHT := 120.0
const TILT := 0.72
## 水晶头部中心的水平位置与触须底边基线，取自素材实测值，保证悬浮时不左右漂移。
const PIVOT_X := 241.0
const PIVOT_Y := 344.0
## 首帧主体高度，用于把美术像素换算成世界高度。
const REFERENCE_HEIGHT := 176.0
## 触须底边离地高度，营造悬浮感。
const HOVER_LIFT := 28.0
const BOB_HEIGHT := 4.0
const BOB_SPEED := 1.6
const ATTACK_FPS := 30.0
## 第 21 帧触手完全张开，视为能量释放帧。
const RELEASE_FRAME := 20
## 弹丸出生点（投影层局部坐标），约等于水晶头部中心的高度。
const MUZZLE_LOCAL := Vector2(0, -176)

@onready var sprite: AnimatedSprite2D = $Visual

var _frame_scale := 1.0
var _attack_playing := false
var _shot_fired := false
var _bob_time := 0.0


func _ready() -> void:
	use_sprite_visual = true
	kind = Kind.RANGED
	super._ready()
	_frame_scale = WORLD_HEIGHT / REFERENCE_HEIGHT
	_build_visual()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)


## 全身受击体：覆盖水晶头部与整片触须
func _configure_hurtbox() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 52.0
	shape.height = 178.0
	$HurtBox.position = Vector2(4.5, -123.0)
	$HurtBox.rotation = 0.0
	$HurtBox.get_node("CollisionShape2D").shape = shape


func _build_visual() -> void:
	var texture: Texture2D = load(TEXTURE_PATH)
	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", false)
	frames.add_frame("idle", _atlas_frame(texture, 0))

	var move_texture: Texture2D = load(MOVE_TEXTURE_PATH)
	frames.add_animation("move")
	frames.set_animation_speed("move", MOVE_FPS)
	frames.set_animation_loop("move", true)
	for i in MOVE_TOTAL_FRAMES:
		frames.add_frame("move", _atlas_frame(move_texture, i))

	frames.add_animation("attack")
	frames.set_animation_speed("attack", ATTACK_FPS)
	frames.set_animation_loop("attack", false)
	for i in TOTAL_FRAMES:
		frames.add_frame("attack", _atlas_frame(texture, i))

	sprite.sprite_frames = frames
	sprite.play("idle")
	_layout()


func _atlas_frame(texture: Texture2D, index: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL)
	return atlas


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if sprite == null:
		return
	_bob_time += delta
	_refresh_locomotion()
	_layout()


## 按当前速度在悬浮静止与游动之间切换；攻击期间保持攻击序列不被打断
func _refresh_locomotion() -> void:
	if _attack_playing:
		return
	var speed := velocity.length()
	if speed > MOVE_THRESHOLD:
		if sprite.animation != &"move":
			sprite.play("move")
		sprite.speed_scale = clampf(speed / move_speed, 0.75, 1.5)
	elif sprite.animation != &"idle":
		sprite.speed_scale = 1.0
		sprite.play("idle")


func _layout() -> void:
	var s := _frame_scale * visual_scale
	var bob := sin(_bob_time * BOB_SPEED) * BOB_HEIGHT
	sprite.scale = Vector2(s, s / TILT)
	sprite.position = Vector2(-PIVOT_X * s, -(PIVOT_Y * s + HOVER_LIFT + bob) / TILT)


func _fire(_direction: Vector2) -> void:
	if _attack_playing:
		return
	_attack_cd = fire_interval
	_attack_playing = true
	_shot_fired = false
	sprite.speed_scale = 1.0
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
	# 与基础远程怪一致：在投影空间内计算弹道，避免父节点纵向缩放导致偏移。
	var space := get_parent() as Node2D
	var target_local := space.to_local(_player.global_position)
	var spawn_local := space.to_local(global_position) + MUZZLE_LOCAL
	var aim := (target_local - spawn_local).normalized()

	var bullet := ENEMY_PROJECTILE.instantiate()
	bullet.direction = aim
	bullet.speed = projectile_speed
	space.add_child(bullet)
	bullet.position = spawn_local


func _on_animation_finished() -> void:
	if not _attack_playing:
		return
	_attack_playing = false
	_refresh_locomotion()


func _draw() -> void:
	# 悬浮怪的阴影落在地面，警戒感叹号上移到水晶头顶，避免被精灵遮挡。
	_ellipse(Vector2(0, 4), Vector2(25, 10), Color(0, 0, 0, 0.24))
	if _alert_flash > 0.0 or _state == State.ALERT:
		var alpha := clampf(_alert_flash / 0.6, 0.0, 1.0)
		var color := Color(1.0, 0.62, 0.22, alpha)
		draw_rect(Rect2(Vector2(-3.0, -226.0), Vector2(6.0, 16.0)), color)
		draw_circle(Vector2(0.0, -202.0), 4.0, color)
