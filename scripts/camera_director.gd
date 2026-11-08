extends Camera2D

@export var target_path: NodePath

@export_group("Follow")
@export var follow_smooth_time := 0.16
@export var deadzone := Vector2(90, 55)
@export var framing_offset := Vector2(0, -28)
@export var look_ahead_max := 70.0
@export var look_ahead_smooth := 0.35
@export var look_ahead_return := 0.22
@export var reference_speed := 430.0

@export_group("Zoom")
@export var base_zoom := 1.4
@export var move_zoom_delta := 0.05
@export var combat_zoom_delta := 0.06
@export var idle_zoom_delta := 0.03
@export var zoom_smooth_time := 0.5
@export var idle_delay := 2.5

@export_group("Combat")
@export var combat_weight := 0.28
@export var combat_hold := 0.55

@export_group("Aim")
@export var aim_lead := 55.0
@export var aim_lead_smooth := 0.3

@export_group("Shake")
@export var shake_max_offset := 14.0
@export var shake_max_roll_deg := 0.35
@export var trauma_decay := 1.4

@export_group("Idle Breath")
@export var idle_breath := 0.5

@export_group("Debug Zoom")
@export var debug_zoom_min := 0.12
@export var debug_zoom_max := 8.0

var debug_zoom_mult := 1.0
var _target: CharacterBody2D
var _projection: Node2D
var _focus := Vector2.ZERO
var _ahead := Vector2.ZERO
var _follow_vel := Vector2.ZERO
var _zoom := 1.4
var _move_blend := 0.0
var _idle_blend := 0.0
var _idle_time := 0.0
var _combat_timer := 0.0
var _combat_point := Vector2.ZERO
var _aim_lead := Vector2.ZERO
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _noise_time := 0.0
var _cinematic := false
var _shot_tween: Tween


func _ready() -> void:
	_target = get_node(target_path) as CharacterBody2D
	if _target:
		_projection = _target.get_parent() as Node2D
		_focus = _target.global_position
		global_position = _focus + framing_offset
		if _target.has_signal("attacked"):
			_target.attacked.connect(_on_target_attacked)
		if _target.has_signal("fired"):
			_target.fired.connect(_on_target_fired)
		if _target.has_signal("damaged"):
			_target.damaged.connect(_on_target_damaged)
		if _target.has_signal("respawned"):
			_target.respawned.connect(snap_to_target)
	_zoom = base_zoom
	zoom = Vector2(_zoom, _zoom)
	_noise.frequency = 0.8
	_noise.seed = 7


func _physics_process(delta: float) -> void:
	if _cinematic or _target == null:
		return

	_update_follow(delta)
	_update_zoom_and_idle(delta)
	_update_shake(delta)


func _update_follow(delta: float) -> void:
	var target_pos := _target.global_position

	# 死区：角色在窗口内时相机保持不动
	var within := Vector2(
		clampf(target_pos.x - _focus.x, -deadzone.x, deadzone.x),
		clampf(target_pos.y - _focus.y, -deadzone.y, deadzone.y))
	_focus = target_pos - within

	# 速度前瞻：朝移动方向预留视野，停下后缓慢回落
	var tilt := 1.0
	if _projection:
		tilt = _projection.scale.y
	var velocity := _target.velocity
	var screen_velocity := Vector2(velocity.x, velocity.y * tilt)
	var speed_ratio := clampf(screen_velocity.length() / maxf(1.0, reference_speed), 0.0, 1.0)
	var direction := screen_velocity.normalized() if screen_velocity.length() > 1.0 else Vector2.ZERO
	var desired_ahead := direction * look_ahead_max * speed_ratio
	if speed_ratio < 0.05:
		# 停下后快速收回前瞻，避免镜头来回晃
		_ahead = _ahead.lerp(Vector2.ZERO, 1.0 - exp(-delta / maxf(0.01, look_ahead_return)))
	else:
		_ahead = _ahead.lerp(desired_ahead, 1.0 - exp(-delta / maxf(0.01, look_ahead_smooth)))

	# 战斗构图：画面重心偏向角色与目标中点
	var combat_offset := Vector2.ZERO
	if _combat_timer > 0.0:
		_combat_timer = maxf(_combat_timer - delta, 0.0)
		combat_offset = (_combat_point - target_pos) * combat_weight
	else:
		_combat_point = target_pos

	# 瞄准构图：画面朝准星方向轻微前移
	var aim_offset := Vector2.ZERO
	if _target.has_method("is_aiming_active") and _target.is_aiming_active():
		var aim: Vector2 = _target.get_aim_direction()
		aim_offset = Vector2(aim.x, aim.y * tilt) * aim_lead
	_aim_lead = _aim_lead.lerp(aim_offset, 1.0 - exp(-delta / maxf(0.01, aim_lead_smooth)))

	var desired := _focus + framing_offset + _ahead + combat_offset + _aim_lead
	global_position = _damp_position(desired, delta)


func _damp_position(target: Vector2, delta: float) -> Vector2:
	var omega := 2.0 / maxf(0.0001, follow_smooth_time)
	var x := omega * delta
	var expo := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := global_position - target
	var temp := (_follow_vel + omega * change) * delta
	_follow_vel = (_follow_vel - omega * temp) * expo
	return target + (change + temp) * expo


func _update_zoom_and_idle(delta: float) -> void:
	var speed := _target.velocity.length()
	var speed_ratio := clampf(speed / maxf(1.0, reference_speed), 0.0, 1.0)
	var moving := speed > 8.0
	_move_blend = lerpf(_move_blend, speed_ratio, 1.0 - exp(-delta / 0.35))

	if moving:
		_idle_time = 0.0
	else:
		_idle_time += delta
	var idle_target := clampf((_idle_time - idle_delay) / 1.5, 0.0, 1.0)
	_idle_blend = lerpf(_idle_blend, idle_target, 1.0 - exp(-delta / 0.8))

	var combat := 1.0 if _combat_timer > 0.0 else 0.0
	var desired := base_zoom - move_zoom_delta * _move_blend + combat_zoom_delta * combat + idle_zoom_delta * _idle_blend
	_zoom = lerpf(_zoom, desired, 1.0 - exp(-delta / maxf(0.01, zoom_smooth_time)))
	zoom = Vector2(_zoom, _zoom) * debug_zoom_mult


func adjust_debug_zoom(factor: float) -> void:
	debug_zoom_mult = clampf(debug_zoom_mult * factor, debug_zoom_min, debug_zoom_max)
	zoom = Vector2(_zoom, _zoom) * debug_zoom_mult


func reset_debug_zoom() -> void:
	debug_zoom_mult = 1.0
	zoom = Vector2(_zoom, _zoom)


func _update_shake(delta: float) -> void:
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	_noise_time += delta

	var amount := _trauma * _trauma
	var shake := Vector2(
		_noise.get_noise_2d(_noise_time * 60.0, 0.0),
		_noise.get_noise_2d(0.0, _noise_time * 60.0)) * shake_max_offset * amount
	var breath := Vector2(0.0, sin(_noise_time * 1.6) * idle_breath * _idle_blend)
	offset = shake + breath
	rotation = deg_to_rad(shake_max_roll_deg) * amount * _noise.get_noise_2d(_noise_time * 40.0, 120.0)


func _on_target_fired() -> void:
	add_trauma(0.1)


func _on_target_attacked(hit_count: int) -> void:
	if hit_count <= 0:
		return
	_combat_timer = combat_hold
	var nearest: Node2D = null
	var best := 300.0
	for node in get_tree().get_nodes_in_group("targets"):
		var target := node as Node2D
		if target == null:
			continue
		var distance := target.global_position.distance_to(_target.global_position)
		if distance < best:
			best = distance
			nearest = target
	if nearest:
		_combat_point = (nearest.global_position + _target.global_position) * 0.5
	add_trauma(0.4)


func _on_target_damaged(_amount: int) -> void:
	add_trauma(0.55)


func snap_to_target() -> void:
	if _target == null:
		return
	_focus = _target.global_position
	global_position = _focus + framing_offset
	_follow_vel = Vector2.ZERO
	_ahead = Vector2.ZERO
	_aim_lead = Vector2.ZERO


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func play_shot(focus: Vector2, duration: float, shot_zoom := -1.0, hold := 0.0) -> void:
	_cinematic = true
	_idle_time = 0.0
	if _shot_tween and _shot_tween.is_valid():
		_shot_tween.kill()
	_shot_tween = create_tween()
	_shot_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_shot_tween.set_parallel(true)
	_shot_tween.tween_property(self, "global_position", focus, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if shot_zoom > 0.0:
		_shot_tween.tween_property(self, "zoom", Vector2(shot_zoom, shot_zoom) * debug_zoom_mult, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shot_tween.set_parallel(false)
	_shot_tween.tween_interval(hold)
	_shot_tween.tween_callback(_end_shot)


func _end_shot() -> void:
	_cinematic = false
	_zoom = zoom.x / maxf(0.01, debug_zoom_mult)
	_follow_vel = Vector2.ZERO
	_focus = global_position
