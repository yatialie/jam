extends CharacterBody2D

signal attacked(hit_count: int)
signal fired
signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal died
signal respawned

const FIRE_COOLDOWN := 0.16
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const MUZZLE_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/vfx/muzzle_flash.png")
const AIM_RETICLE_SCRIPT := preload("res://scripts/aim_reticle.gd")
const INVULNERABLE_TIME := 1.3
const RESPAWN_INVULNERABLE_TIME := 2.0
const AIM_SPEED_RATIO := 0.55
const AIM_TURN_HOLD := 0.25
const PROJECTION_TILT := 0.72
const MUZZLE_FORWARD := 36.0
const MOUSE_DEADZONE := 8.0
const MUZZLE_OFFSETS := {
	"astronaut": Vector2(0, -70),
	"nova": Vector2(0, -60),
}
const WALK_FPS_SCALES := {
	"astronaut": 1.0,
	"nova": 1.5,
}

@export var muzzle_offset := Vector2(0, -70)
@export var walk_speed := 250.0
@export var run_speed := 430.0
@export var acceleration := 1100.0
@export var deceleration := 2000.0
@export var max_health := 3
@export var respawn_delay := 1.0
@export var knockback_speed := 420.0

@export_group("Collision")
## 单帧最多进行的滑动解算次数，越多越不容易在拐角处停住。
@export var slide_iterations := 6
## 贴墙/凸角被完全挡住时，沿可通行切向补足的最大单帧位移（设计单位）。
@export var corner_assist := 9.0
## 单次辅助位移相对剩余运动量的比例上限。
@export var corner_assist_ratio := 0.65
## 相邻接触法线夹角小于该余弦值时视为同一面，合并法线以抹平拼接接缝。
@export var normal_merge_dot := 0.86
## 连续被挡住多少帧后开始向侧面试探脱困。
@export var stuck_probe_frames := 6
## 脱困试探的单次侧向位移（设计单位）。
@export var stuck_probe_distance := 6.0

@onready var visual: AnimatedSprite2D = $Visual
@onready var hitbox: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $HurtBox

var facing := Vector2.DOWN
var aim_direction := Vector2.RIGHT
var is_sprinting := false
var is_aiming := false
var health := 0
var dead := false
var respawning := false
var respawn_point := Vector2.ZERO
var weapon_disabled := false
## 关卡施加的外部速度（如第三关抛弃口吸力），每帧由关卡导演写入。
var external_pull := Vector2.ZERO

var _reticle
var _mouse_projection := Vector2.ZERO
var _aim_turn_hold := 0.0
var _cooldown := 0.0
var _invulnerable := 0.0
var _blink := 0.0
var _move_dir := Vector2.ZERO
var _stuck_time := 0.0
var _last_normal := Vector2.ZERO


func _ready() -> void:
	health = max_health
	respawn_point = global_position
	visual.walk_fps_scale = WALK_FPS_SCALES.get(UserSettings.character, 1.0)
	visual.set_character(UserSettings.character)
	muzzle_offset = MUZZLE_OFFSETS.get(UserSettings.character, muzzle_offset)
	_update_visual_facing()
	_build_reticle()
	# 进入关卡出生在重生点时同样播放一次显形动画。
	_play_respawn_effect()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_aiming(false)
	elif what == NOTIFICATION_EXIT_TREE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed:
			_set_aiming(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_aim_turn_hold = maxf(_aim_turn_hold - delta, 0.0)

	if dead:
		_move_dir = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_move_with_scene(delta, false)
		return

	# 重生显形期间锁移动与射击，但继续消耗复活无敌时间（不闪烁）。
	if respawning:
		_move_dir = Vector2.ZERO
		_invulnerable = maxf(_invulnerable - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
		_move_with_scene(delta, false)
		modulate.a = 1.0
		return

	_update_invulnerability(delta)
	_update_mouse_aim()
	_set_aiming(_aim_pressed())

	if is_aiming:
		_aim_turn_hold = AIM_TURN_HOLD

	var move_dir := _read_move_input()
	_move_dir = move_dir
	var has_input := move_dir.length() > 0.1
	is_sprinting = has_input and not is_aiming and _sprint_pressed()

	if is_aiming or _aim_turn_hold > 0.0:
		facing = aim_direction
	elif has_input:
		facing = move_dir
	_update_visual_facing()

	var target_speed := run_speed if is_sprinting else walk_speed
	if is_aiming:
		target_speed *= AIM_SPEED_RATIO
	var target_velocity := move_dir * target_speed
	var rate := acceleration if has_input else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	_move_with_scene(delta, has_input, external_pull)

	if _fire_pressed() and _cooldown <= 0.0 and not weapon_disabled:
		_fire()

	if is_aiming:
		_update_reticle()


func take_damage(amount: int, from_direction: Vector2 = Vector2.ZERO) -> void:
	if dead or _invulnerable > 0.0:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	damaged.emit(amount)

	if from_direction.length() > 0.01:
		velocity = from_direction.normalized() * knockback_speed

	if health <= 0:
		_die()
		return

	_invulnerable = INVULNERABLE_TIME
	_blink = 0.0


func set_respawn_point(point: Vector2) -> void:
	respawn_point = point


func set_weapon_disabled(value: bool) -> void:
	weapon_disabled = value


func scripted_kill() -> void:
	if dead:
		return
	health = 0
	health_changed.emit(health, max_health)
	damaged.emit(max_health)
	_die()


func is_dead() -> bool:
	return dead


func is_invulnerable() -> bool:
	return _invulnerable > 0.0


func is_aiming_active() -> bool:
	return is_aiming


func get_aim_direction() -> Vector2:
	return aim_direction


func _update_mouse_aim() -> void:
	var local_mouse := get_local_mouse_position()
	_mouse_projection = position + local_mouse
	if local_mouse.length() > MOUSE_DEADZONE:
		aim_direction = local_mouse.normalized()


func _build_reticle() -> void:
	_reticle = Node2D.new()
	_reticle.name = "AimReticle"
	_reticle.set_script(AIM_RETICLE_SCRIPT)
	_reticle.visible = false
	get_parent().add_child.call_deferred(_reticle)


func _update_reticle() -> void:
	if _reticle == null:
		return
	_reticle.call("update_aim", _mouse_projection, _muzzle_position())


func _set_aiming(value: bool) -> void:
	if is_aiming == value:
		return
	is_aiming = value
	if _reticle:
		_reticle.visible = value
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE)


func _muzzle_position() -> Vector2:
	return position + muzzle_offset + aim_direction * MUZZLE_FORWARD


func _update_invulnerability(delta: float) -> void:
	if _invulnerable <= 0.0:
		modulate.a = 1.0
		return

	_invulnerable = maxf(_invulnerable - delta, 0.0)
	_blink += delta
	if _invulnerable > 0.0:
		modulate.a = 0.35 if fmod(_blink, 0.14) < 0.07 else 1.0
	else:
		modulate.a = 1.0


func _die() -> void:
	dead = true
	respawning = false
	_invulnerable = 0.0
	velocity = Vector2.ZERO
	hitbox.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)
	_set_aiming(false)
	modulate.a = 1.0
	died.emit()

	# 取消可能仍在播放的重生显形，避免其结束回调覆盖死亡动画。
	if visual.has_method("clear_respawn"):
		visual.clear_respawn()

	# 有死亡序列帧的角色播放倒地动画并保持最终姿势，其余角色沿用淡出。
	var death_played := false
	if visual.has_method("play_death"):
		death_played = bool(visual.play_death())
	if death_played:
		await get_tree().create_timer(float(visual.get_death_duration()) + 0.05).timeout
	else:
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.4)
		await fade.finished

	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	global_position = respawn_point
	velocity = Vector2.ZERO
	health = max_health
	health_changed.emit(health, max_health)
	modulate.a = 1.0
	if visual.has_method("clear_death"):
		visual.clear_death()
	hitbox.set_deferred("disabled", false)
	hurtbox.set_deferred("monitorable", true)
	dead = false
	facing = Vector2.DOWN
	_update_visual_facing()
	_invulnerable = RESPAWN_INVULNERABLE_TIME
	_blink = 0.0
	_aim_turn_hold = 0.0
	respawned.emit()

	_play_respawn_effect()


## 播放重生显形动画：期间保持无敌并锁定操作，结束后回到待机。
func _play_respawn_effect() -> void:
	if not visual.has_method("play_respawn") or not bool(visual.play_respawn()):
		return
	respawning = true
	velocity = Vector2.ZERO
	modulate.a = 1.0
	var duration := float(visual.get_respawn_duration())
	_invulnerable = maxf(_invulnerable, duration + 0.25)
	await get_tree().create_timer(duration).timeout
	if dead:
		return
	respawning = false
	if visual.has_method("clear_respawn"):
		visual.clear_respawn()


func _update_visual_facing() -> void:
	visual.facing = facing


## 角色与场景的移动碰撞解算：扫掠移动 + 多次滑动 + 接缝法线合并 + 拐角辅助。
## 只处理墙体/道具（碰撞层 1），伤害判定 HurtBox 完全不参与。
## extra_velocity 是关卡施加的外力（如第三关吸力），只参与本帧位移，不污染速度状态。
func _move_with_scene(delta: float, allow_assist: bool, extra_velocity := Vector2.ZERO) -> void:
	var motion := (velocity + extra_velocity) * delta
	if motion.length_squared() < 0.000001:
		_stuck_time = 0.0
		return

	var desired := motion.normalized()
	var remaining := motion
	var normals: Array[Vector2] = []
	var assists := 2
	var start_position := global_position

	for i in slide_iterations:
		if remaining.length_squared() < 0.000001:
			break
		var collision := move_and_collide(remaining, false, safe_margin, false)
		if collision == null:
			break

		var normal := collision.get_normal()
		# 合并相近法线：拼接碰撞体的接缝不会再产生突变，圆脚可以平顺滑过去
		for previous in normals:
			if previous.dot(normal) >= normal_merge_dot:
				normal = (previous + normal).normalized()
				break
		normals.append(normal)
		_last_normal = normal

		remaining = collision.get_remainder().slide(normal)
		# 只抵消撞入墙面的速度分量，保留沿墙滑行的动量
		velocity = velocity.slide(normal)

		# 被完全挡住时，沿输入的切向补一小段，避免在凸角/接缝处硬停
		if remaining.length_squared() < 0.0004:
			if allow_assist and assists > 0:
				remaining = _corner_assist_motion(motion, desired, normal)
				assists -= 1
			if remaining.length_squared() < 0.0004:
				break

	_update_stuck_recovery(delta, motion, start_position, allow_assist)


## 拐角辅助只补输入本身的切向分量：正撞墙面时保持站定，不会自动侧滑。
func _corner_assist_motion(motion: Vector2, desired: Vector2, normal: Vector2) -> Vector2:
	if corner_assist <= 0.0:
		return Vector2.ZERO
	var tangent := desired.slide(normal)
	if tangent.length() < 0.16:
		return Vector2.ZERO
	# 按输入的切向比例缩放，浅角度擦墙时不会被额外推着走
	var distance := minf(corner_assist, motion.length() * corner_assist_ratio) * tangent.length()
	if distance <= 0.0:
		return Vector2.ZERO
	var candidate := tangent.normalized() * distance
	if test_move(global_transform, candidate):
		return Vector2.ZERO
	return candidate


## 连续多帧原地不动时，沿输入切向试探一次小位移，从碰撞体夹缝里脱出。
func _update_stuck_recovery(delta: float, motion: Vector2, start_position: Vector2, allow_assist: bool) -> void:
	if not allow_assist or _move_dir.length_squared() < 0.01:
		_stuck_time = 0.0
		return
	if global_position.distance_to(start_position) >= motion.length() * 0.06:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time * 60.0 < float(stuck_probe_frames):
		return
	_stuck_time = 0.0
	if _last_normal == Vector2.ZERO:
		return
	# 只沿输入自身的切向脱困：正撞墙面或夹在凹角里时保持原地，不产生反向漂移
	var tangent := _move_dir.slide(_last_normal)
	if tangent.length() < 0.2:
		return
	var offset := tangent.normalized() * maxf(2.0, stuck_probe_distance)
	if test_move(global_transform, offset):
		return
	move_and_collide(offset, false, safe_margin, false)


func _read_move_input() -> Vector2:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var wasd := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if wasd.length() > 0.1:
		dir = wasd
	return dir.normalized() if dir.length() > 1.0 else dir


func _sprint_pressed() -> bool:
	if InputMap.has_action("sprint"):
		return Input.is_action_pressed("sprint")
	return Input.is_physical_key_pressed(KEY_SHIFT)


func _fire_pressed() -> bool:
	return _action_pressed(&"fire")


func _aim_pressed() -> bool:
	return _action_pressed(&"aim")


func _action_pressed(action: StringName) -> bool:
	if InputMap.has_action(action):
		return Input.is_action_pressed(action)
	if action == &"fire":
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if action == &"aim":
		return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	return false


func _fire() -> void:
	_cooldown = FIRE_COOLDOWN
	_aim_turn_hold = AIM_TURN_HOLD
	facing = aim_direction
	_update_visual_facing()

	var muzzle := _muzzle_position()
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.position = muzzle
	projectile.direction = aim_direction
	projectile.hit_target.connect(_on_projectile_hit)
	get_parent().add_child(projectile)

	if visual.has_method("trigger_shoot"):
		visual.trigger_shoot()
	_spawn_muzzle_flash(muzzle)
	fired.emit()


func _spawn_muzzle_flash(at: Vector2) -> void:
	var flash := Sprite2D.new()
	flash.texture = MUZZLE_TEXTURE
	flash.hframes = 6
	flash.frame = 0
	flash.position = at
	flash.rotation = aim_direction.angle()
	flash.scale = Vector2(0.6, 0.6 / PROJECTION_TILT)
	flash.z_index = 14
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = material
	get_parent().add_child(flash)

	var tween := flash.create_tween()
	tween.tween_method(_set_flash_frame.bind(flash), 0.0, 5.0, 0.12)
	tween.tween_callback(flash.queue_free)


func _set_flash_frame(value: float, flash: Sprite2D) -> void:
	flash.frame = int(value)


func _on_projectile_hit() -> void:
	attacked.emit(1)
