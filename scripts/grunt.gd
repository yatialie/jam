extends "res://scripts/enemy.gd"

## 初始小兵：用美术给的 17 帧移动序列替换程序化躯干。

const TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/grunt/grunt_walk.png"
const ATTACK_TEXTURE_PATH := "res://art_placeholder/scifi_ship_v2/enemies/grunt/grunt_attack.png"
const CELL := 384
const ATTACK_CELL := 640
const WORLD_HEIGHT := 85.0
const TILT := 0.72
const BODY_CENTER_X := 192.0
const ATTACK_CENTER_X := 320.0
const ATTACK_BASELINE := 560.0

@onready var sprite: AnimatedSprite2D = $Visual
@onready var attack_sprite: AnimatedSprite2D = $AttackVisual

var _move_scale := 1.0
var _attack_scale := 1.0
var _used_end_y := 363.0
var _attack_playing := false
var _was_attacking := false


func _ready() -> void:
	set("use_sprite_visual", true)
	kind = Kind.MELEE
	super._ready()
	_build_visual()
	_build_attack_visual()
	attack_sprite.visible = false
	attack_sprite.animation_finished.connect(_on_attack_finished)


## 全身受击体：覆盖帽子、身体与双脚
func _configure_hurtbox() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 25.0
	shape.height = 114.0
	$HurtBox.position = Vector2(3.0, -56.5)
	$HurtBox.rotation = 0.0
	$HurtBox.get_node("CollisionShape2D").shape = shape


func _build_visual() -> void:
	var texture: Texture2D = load(TEXTURE_PATH)
	var frames := SpriteFrames.new()
	frames.add_animation("move")
	frames.set_animation_speed("move", 12.0)
	frames.set_animation_loop("move", true)

	var count := maxi(1, texture.get_width() / CELL)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame("move", atlas)

	sprite.sprite_frames = frames
	var used := texture.get_image().get_used_rect()
	var base_scale := WORLD_HEIGHT / float(used.size.y)
	# 移动序列原画的角色比攻击序列小，按两者首帧主体高度换算，保证切换状态时体型一致
	var move_ref := _frame_height(texture, CELL, 0)
	var attack_ref := _frame_height(load(ATTACK_TEXTURE_PATH), ATTACK_CELL, 0)
	_move_scale = base_scale * (attack_ref / move_ref)
	_attack_scale = base_scale
	_used_end_y = float(used.end.y)
	sprite.play("move")
	_layout()


func _build_attack_visual() -> void:
	var texture: Texture2D = load(ATTACK_TEXTURE_PATH)
	var frames := SpriteFrames.new()
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 24.0)
	frames.set_animation_loop("attack", false)

	var count := maxi(1, texture.get_width() / ATTACK_CELL)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(i * ATTACK_CELL, 0, ATTACK_CELL, ATTACK_CELL)
		frames.add_frame("attack", atlas)

	attack_sprite.sprite_frames = frames


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if sprite == null:
		return

	_layout()
	if _dead:
		return

	var attacking := _attack_flash > 0.0
	if attacking and not _was_attacking and not _attack_playing:
		_start_attack()
	_was_attacking = attacking

	attack_sprite.flip_h = _facing.x < -0.1
	if _attack_playing:
		return

	sprite.flip_h = _facing.x < -0.1
	var speed := velocity.length()
	if speed > 6.0:
		if not sprite.is_playing():
			sprite.play("move")
		sprite.speed_scale = clampf(speed / 100.0, 0.8, 1.6)
	else:
		sprite.pause()
		sprite.frame = 0


func _start_attack() -> void:
	_attack_playing = true
	sprite.visible = false
	attack_sprite.visible = true
	attack_sprite.frame = 0
	attack_sprite.play("attack")


func _on_attack_finished() -> void:
	_attack_playing = false
	attack_sprite.visible = false
	sprite.visible = true
	sprite.play("move")


func _layout() -> void:
	var move_scale := _move_scale * visual_scale
	sprite.scale = Vector2(move_scale, move_scale / TILT)
	sprite.position = Vector2(-BODY_CENTER_X * move_scale, -_used_end_y * move_scale / TILT)
	if attack_sprite != null:
		var attack_scale := _attack_scale * visual_scale
		attack_sprite.scale = Vector2(attack_scale, attack_scale / TILT)
		attack_sprite.position = Vector2(-ATTACK_CENTER_X * attack_scale, -ATTACK_BASELINE * attack_scale / TILT)


## 取指定帧的实际像素高度，用于不同图集之间的比例换算
func _frame_height(texture: Texture2D, cell: int, index: int) -> float:
	var region := texture.get_image().get_region(Rect2i(index * cell, 0, cell, cell))
	return float(region.get_used_rect().size.y)
