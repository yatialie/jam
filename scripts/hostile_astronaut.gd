extends "res://scripts/enemy.gd"

## 敌对宇航员：24 帧近战攻击序列（已剔除白底冲击帧与静止定格）+ 20 帧正面行走循环。
## 站立时播放收招站姿，移动时切换行走序列；挥拳动画播放到命中帧时才结算伤害。

const TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/hostile_astronaut/hostile_astronaut_attack.png"
const MOVE_TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/hostile_astronaut/hostile_astronaut_move.png"
const CELL := 512
const FRAME_COUNT := 24
const MOVE_FRAME_COUNT := 20
const MOVE_FPS := 18.0
## 低于该速度视为站立，避免减速收尾时反复闪切行走帧。
const MOVE_THRESHOLD := 8.0
const WORLD_HEIGHT := 128.0
const TILT := 0.72
## 站立时头部中心与脚底基线，取自素材实测值。
const PIVOT_X := 259.0
const PIVOT_Y := 384.0
## 首帧主体高度，用于把美术像素换算成世界高度。
const REFERENCE_HEIGHT := 253.0
## 收招后的自然站姿。
const IDLE_FRAME := 23
## 出拳完全伸出的那一帧，伤害在此结算。
const IMPACT_FRAME := 14
const ATTACK_FPS := 26.0
## 命中时允许的额外距离容差，玩家及时后撤可以躲开。
const CONTACT_MARGIN := 1.25

@onready var sprite: AnimatedSprite2D = $Visual

var _frame_scale := 1.0
var _attack_playing := false
var _damage_pending := false
var _attack_dir := Vector2.LEFT


func _ready() -> void:
	use_sprite_visual = true
	kind = Kind.MELEE
	super._ready()
	_frame_scale = WORLD_HEIGHT / REFERENCE_HEIGHT
	_build_visual()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)


## 全身受击体：竖向胶囊覆盖头盔、躯干与双腿。
func _configure_hurtbox() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 30.0
	shape.height = 150.0
	$HurtBox.position = Vector2(0, -89.0)
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
	_layout()
	if _dead:
		return
	var facing_x := _attack_dir.x if _attack_playing else _facing.x
	sprite.flip_h = facing_x > 0.1
	_refresh_locomotion()


## 按当前速度在站立与行走之间切换；攻击期间保持攻击序列不被打断。
func _refresh_locomotion() -> void:
	if _attack_playing:
		return
	if velocity.length() > MOVE_THRESHOLD:
		if sprite.animation != &"move":
			sprite.play("move")
		sprite.speed_scale = clampf(velocity.length() / move_speed, 0.75, 1.5)
	elif sprite.animation != &"idle":
		sprite.speed_scale = 1.0
		sprite.play("idle")


func _layout() -> void:
	var s := _frame_scale * visual_scale
	var pivot_x := CELL - PIVOT_X if sprite.flip_h else PIVOT_X
	sprite.scale = Vector2(s, s / TILT)
	sprite.position = Vector2(-pivot_x * s, -PIVOT_Y * s / TILT)


func _update_melee(dir: Vector2, distance: float, delta: float) -> void:
	if _attack_playing:
		velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
		return
	super._update_melee(dir, distance, delta)


func _melee_attack(dir: Vector2) -> void:
	if _attack_playing:
		return
	_attack_cd = melee_cooldown
	_attack_playing = true
	_damage_pending = true
	_attack_dir = dir
	velocity = dir * 220.0
	sprite.speed_scale = 1.0
	sprite.play("attack")


func _on_frame_changed() -> void:
	if not _attack_playing or not _damage_pending:
		return
	if sprite.frame >= IMPACT_FRAME:
		_damage_pending = false
		_strike()


func _strike() -> void:
	_spawn_slash(_attack_dir)
	if _player == null or not is_instance_valid(_player) or _player_is_dead():
		return
	if _distance_design(_player.global_position) > contact_range * CONTACT_MARGIN:
		return
	if _player.has_method("take_damage"):
		_player.take_damage(1, _attack_dir)


func _on_animation_finished() -> void:
	if not _attack_playing:
		return
	_attack_playing = false
	_damage_pending = false
	sprite.speed_scale = 1.0
	_refresh_locomotion()


func _draw() -> void:
	# 与基础 AI 一致保留脚下阴影，警戒感叹号移动到头盔上方。
	_ellipse(Vector2(0, 4), Vector2(25, 10), Color(0, 0, 0, 0.24))
	if _alert_flash > 0.0 or _state == State.ALERT:
		var alpha := clampf(_alert_flash / 0.6, 0.0, 1.0)
		var color := Color(1.0, 0.62, 0.22, alpha)
		draw_rect(Rect2(Vector2(-3.0, -210.0), Vector2(6.0, 16.0)), color)
		draw_circle(Vector2(0.0, -186.0), 4.0, color)
