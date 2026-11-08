extends CharacterBody2D

signal died

enum Kind { MELEE, RANGED }
enum Behavior { PATROL, HUNTER }
enum State { PATROL, ALERT, CHASE, SEARCH, RETURN }

const ENEMY_PROJECTILE := preload("res://scenes/enemy_projectile.tscn")
const ARRIVE_DISTANCE := 18.0
const STUCK_LIMIT := 0.8
const ALERT_TIME := 0.22

@export var kind: Kind = Kind.MELEE
@export var use_sprite_visual := false
@export var max_hp := 4
@export var move_speed := 140.0
@export var contact_range := 56.0
@export var melee_cooldown := 1.15
@export var preferred_range := 300.0
@export var fire_interval := 2.0
@export var projectile_speed := 380.0

@export_group("Patrol")
@export var behavior_mode: Behavior = Behavior.PATROL
@export var patrol_radius := 170.0
@export var detection_radius := 280.0
@export var leash_radius := 340.0
@export var patrol_speed_ratio := 0.45
@export var patrol_wait_time := 0.9
@export var lose_sight_time := 1.6
@export var search_time := 1.2
@export var require_line_of_sight := true
## 相对锚点的巡逻点偏移；留空则在巡逻半径内随机取点
@export var patrol_points := PackedVector2Array()

var hp := 0
var visual_scale := 0.55
## 关卡施加的外部速度（如第三关抛弃口吸力），每帧由关卡导演写入。
var external_pull := Vector2.ZERO

var _phase := 0.0
var _attack_cd := 0.0
var _spawning := true
var _dead := false
var _player
var _hurtbox: Area2D
var _facing := Vector2.DOWN
var _flash := 0.0
var _attack_flash := 0.0

var _anchor := Vector2.ZERO
var _state: State = State.PATROL
var _state_timer := 0.0
var _lose_timer := 0.0
var _wait_timer := 0.0
var _stuck_timer := 0.0
var _last_pos := Vector2.ZERO
var _patrol_target := Vector2.ZERO
var _patrol_index := -1
var _last_known := Vector2.ZERO
var _alert_flash := 0.0


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	_player = get_tree().get_first_node_in_group("player")
	_hurtbox = $HurtBox
	_configure_hurtbox()
	_attack_cd = randf_range(0.4, 1.1)

	_anchor = global_position
	_last_pos = global_position
	_last_known = global_position
	_patrol_target = global_position
	_wait_timer = randf_range(0.2, patrol_wait_time)
	_pick_patrol_point()

	modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.28)
	tw.tween_property(self, "visual_scale", 1.0, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void: _spawning = false)


## 全身受击体：近战甲壳用横向胶囊覆盖爪与躯干，远程浮游体用纵向胶囊覆盖外壳与悬挂腿
func _configure_hurtbox() -> void:
	var shape := CapsuleShape2D.new()
	if kind == Kind.RANGED:
		shape.radius = 42.0
		shape.height = 92.0
		_hurtbox.position = Vector2(0, -48.0)
		_hurtbox.rotation = 0.0
	else:
		shape.radius = 38.0
		shape.height = 104.0
		_hurtbox.position = Vector2(0, -32.0)
		_hurtbox.rotation = PI * 0.5
	_hurtbox.get_node("CollisionShape2D").shape = shape


func _physics_process(delta: float) -> void:
	_phase += delta
	_flash = maxf(_flash - delta, 0.0)
	_attack_flash = maxf(_attack_flash - delta, 0.0)
	_alert_flash = maxf(_alert_flash - delta, 0.0)

	if not _dead:
		var tint := 2.0 if _flash > 0.0 else 1.0
		modulate = Color(tint, tint, tint, modulate.a)

	queue_redraw()

	if _dead or _spawning:
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		return

	_attack_cd = maxf(_attack_cd - delta, 0.0)

	if _player_is_dead():
		if behavior_mode == Behavior.HUNTER:
			velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		else:
			if _state != State.PATROL and _state != State.RETURN:
				_set_state(State.RETURN)
			_return_update(delta)
		_move_with_pull(delta)
		return

	if behavior_mode == Behavior.HUNTER:
		_hunter_update(delta)
		_move_with_pull(delta)
		return

	match _state:
		State.PATROL:
			_patrol_update(delta)
		State.ALERT:
			_alert_update(delta)
		State.CHASE:
			_chase_update(delta)
		State.SEARCH:
			_search_update(delta)
		State.RETURN:
			_return_update(delta)

	_move_with_pull(delta)


## 外部吸力作为独立的碰撞位移施加，不写进 AI 的速度状态，避免逐帧累积。
func _move_with_pull(delta: float) -> void:
	move_and_slide()
	if external_pull.length_squared() > 0.01:
		move_and_collide(external_pull * delta)


func _hunter_update(delta: float) -> void:
	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if distance > 0.01 else Vector2.DOWN
	_facing = dir

	if kind == Kind.MELEE:
		_update_melee(dir, distance, delta)
	else:
		_update_ranged(dir, distance, delta)


func _patrol_update(delta: float) -> void:
	if _can_see_player():
		_enter_alert()
		return

	if _wait_timer > 0.0:
		_wait_timer = maxf(_wait_timer - delta, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		_facing = Vector2.UP.rotated(_phase * 0.8)
		if _wait_timer <= 0.0:
			_pick_patrol_point()
		return

	var distance := _distance_design(_patrol_target)
	if distance <= ARRIVE_DISTANCE:
		_wait_timer = randf_range(patrol_wait_time * 0.6, patrol_wait_time * 1.4)
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		return

	_move_to(_patrol_target, move_speed * patrol_speed_ratio, 520.0, delta)

	var moved := global_position.distance_to(_last_pos)
	if moved < 2.0:
		_stuck_timer += delta
		if _stuck_timer >= STUCK_LIMIT:
			_stuck_timer = 0.0
			_pick_patrol_point()
	else:
		_stuck_timer = 0.0
	_last_pos = global_position


func _alert_update(delta: float) -> void:
	_state_timer += delta
	velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	var player_pos := _player_pos()
	var dir := _direction_to(player_pos)
	if dir != Vector2.ZERO:
		_facing = dir
	if _state_timer >= ALERT_TIME:
		_set_state(State.CHASE)
		_last_known = player_pos


func _chase_update(delta: float) -> void:
	var player_pos := _player_pos()
	var distance := _distance_design(player_pos)
	var dir := _direction_to(player_pos)
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	_facing = dir

	if _distance_design(_anchor) > leash_radius:
		_set_state(State.RETURN)
		return

	var visible := _can_see_player()
	if visible:
		_lose_timer = 0.0
		_last_known = _player.global_position
	else:
		_lose_timer += delta
		if _lose_timer >= lose_sight_time:
			_set_state(State.SEARCH)
			return

	if visible:
		if kind == Kind.MELEE:
			_update_melee(dir, distance, delta)
		else:
			_update_ranged(dir, distance, delta)
	else:
		_move_to(_last_known, move_speed * 0.8, 720.0, delta)


func _search_update(delta: float) -> void:
	if _can_see_player():
		_enter_chase()
		return

	if _distance_design(_last_known) > ARRIVE_DISTANCE:
		_move_to(_last_known, move_speed * 0.75, 700.0, delta)
		if _distance_design(_anchor) > leash_radius:
			_set_state(State.RETURN)
		return

	_state_timer += delta
	velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
	_facing = Vector2.UP.rotated(_phase * 2.0)
	if _state_timer >= search_time:
		_set_state(State.RETURN)


func _return_update(delta: float) -> void:
	var anchor_distance := _distance_design(_anchor)
	if anchor_distance <= ARRIVE_DISTANCE:
		_set_state(State.PATROL)
		_wait_timer = patrol_wait_time * 0.6
		return

	_move_to(_anchor, move_speed * 0.8, 650.0, delta)

	if anchor_distance <= patrol_radius and _can_see_player():
		_enter_alert()


func _enter_alert() -> void:
	_set_state(State.ALERT)
	_alert_flash = 0.6
	_last_known = _player_pos()


func _enter_chase() -> void:
	_set_state(State.CHASE)
	_alert_flash = 0.6
	_last_known = _player_pos()


func _set_state(new_state: State) -> void:
	_state = new_state
	_state_timer = 0.0
	_stuck_timer = 0.0
	_last_pos = global_position
	if new_state == State.CHASE:
		_lose_timer = 0.0


func _pick_patrol_point() -> void:
	var anchor_local := _local_pos(_anchor)
	if patrol_points.size() > 0:
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
		_patrol_target = _global_pos(anchor_local + patrol_points[_patrol_index])
		return
	var angle := randf() * TAU
	var distance := sqrt(randf()) * maxf(patrol_radius, 24.0)
	_patrol_target = _global_pos(anchor_local + Vector2(cos(angle), sin(angle)) * distance)


func _move_to(target: Vector2, speed: float, accel: float, delta: float) -> void:
	var dir := _direction_to(target)
	if dir == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, accel * delta)
		return
	_facing = dir
	velocity = velocity.move_toward(dir * speed, accel * delta)


func _direction_to(target_global: Vector2) -> Vector2:
	var local_delta := _local_pos(target_global) - _local_pos(global_position)
	if local_delta.length() > 0.01:
		return local_delta.normalized()
	return Vector2.ZERO


func _local_pos(global_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(global_point) if parent else global_point


func _global_pos(local_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_global(local_point) if parent else local_point


func _distance_design(target_global: Vector2) -> float:
	return _local_pos(target_global).distance_to(_local_pos(global_position))


func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player) or _player_is_dead():
		return false
	var player_pos := _player_pos()
	if _distance_design(player_pos) > detection_radius:
		return false
	if not require_line_of_sight:
		return true

	var space := get_world_2d().direct_space_state
	var from := global_position + Vector2(0, -26)
	var to := player_pos + Vector2(0, -24)
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space.intersect_ray(query).is_empty()


func _player_pos() -> Vector2:
	var node := _player as Node2D
	return node.global_position if node != null else Vector2.ZERO


func _player_is_dead() -> bool:
	return _player.has_method("is_dead") and _player.is_dead()


func get_patrol_debug() -> Dictionary:
	return {
		"enabled": behavior_mode == Behavior.PATROL,
		"anchor": _anchor,
		"target": _patrol_target,
		"patrol_radius": patrol_radius,
		"detection_radius": detection_radius,
		"leash_radius": leash_radius,
		"state": _state,
	}


func hit(direction: Vector2) -> void:
	if _dead:
		return
	hp -= 1
	_flash = 0.12
	if direction.length() > 0.01:
		velocity += direction.normalized() * 190.0
	if hp <= 0:
		_die()
		return
	_provoke()


## 脚本击杀（如被抛弃口吸入），跳过血量判定直接死亡。
func kill() -> void:
	if _dead:
		return
	hp = 0
	_die()


func _provoke() -> void:
	if behavior_mode != Behavior.PATROL or _player == null or not is_instance_valid(_player):
		return
	if _player_is_dead():
		return
	if _state != State.PATROL and _state != State.RETURN and _state != State.SEARCH:
		return
	if _distance_design(_player_pos()) > detection_radius * 1.6:
		return
	_enter_alert()


func _update_melee(dir: Vector2, distance: float, delta: float) -> void:
	if _attack_flash > 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return
	if distance > contact_range:
		velocity = velocity.move_toward(dir * move_speed, 900.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		if _attack_cd <= 0.0:
			_melee_attack(dir)


func _update_ranged(dir: Vector2, distance: float, delta: float) -> void:
	var desired := Vector2.ZERO
	if distance > preferred_range + 50.0:
		desired = dir * move_speed
	elif distance < preferred_range - 70.0:
		desired = -dir * move_speed
	else:
		desired = dir.orthogonal() * sin(_phase * 0.9) * move_speed * 0.45
	velocity = velocity.move_toward(desired, 520.0 * delta)

	var fire_range := 640.0 if behavior_mode == Behavior.HUNTER else detection_radius
	if distance < fire_range and _attack_cd <= 0.0:
		_fire(dir)


func _melee_attack(dir: Vector2) -> void:
	_attack_cd = melee_cooldown
	_attack_flash = 0.2
	velocity = dir * 300.0
	if _player.has_method("take_damage"):
		_player.take_damage(1, dir)
	_spawn_slash(dir)


func _fire(_dir: Vector2) -> void:
	_attack_cd = fire_interval
	_attack_flash = 0.14

	# 在投影空间内计算弹道，避免父节点纵向缩放导致弹道偏移
	var space := get_parent() as Node2D
	var target_local := space.to_local(_player.global_position)
	var spawn_local := space.to_local(global_position) + Vector2(0, -30.0)
	var aim := (target_local - spawn_local).normalized()

	var bullet := ENEMY_PROJECTILE.instantiate()
	bullet.direction = aim
	bullet.speed = projectile_speed
	space.add_child(bullet)
	bullet.position = spawn_local


func _die() -> void:
	if _dead:
		return
	_dead = true
	$CollisionShape2D.set_deferred("disabled", true)
	_hurtbox.set_deferred("monitoring", false)
	_hurtbox.set_deferred("monitorable", false)
	_spawn_death_burst()
	died.emit()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_property(self, "visual_scale", 1.7, 0.28)
	tw.chain().tween_callback(queue_free)


func _spawn_slash(dir: Vector2) -> void:
	var slash := Polygon2D.new()
	slash.polygon = PackedVector2Array([Vector2(18, -10), Vector2(62, -26), Vector2(74, 0), Vector2(62, 26), Vector2(18, 10)])
	slash.color = Color(1.0, 0.5, 0.2, 0.75)
	slash.position = position + dir * 20.0
	slash.rotation = dir.angle()
	slash.z_index = 8
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	slash.material = material
	get_parent().add_child(slash)
	get_tree().create_timer(0.12).timeout.connect(slash.queue_free)


func _spawn_death_burst() -> void:
	var burst := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var radius := 34.0 if i % 2 == 0 else 14.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	burst.polygon = points
	burst.color = Color(1.0, 0.55, 0.25, 0.85) if kind == Kind.MELEE else Color(0.55, 0.6, 1.0, 0.85)
	burst.position = position + Vector2(0, -34)
	burst.z_index = 9
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	burst.material = material
	get_parent().add_child(burst)

	var tw := burst.create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst, "scale", Vector2.ONE * 1.9, 0.28)
	tw.tween_property(burst, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(burst.queue_free)


func _draw() -> void:
	_ellipse(Vector2(0, 4), Vector2(25, 10), Color(0, 0, 0, 0.24))

	var lift := 0.0
	var tilt := 0.0
	if not use_sprite_visual:
		if kind == Kind.RANGED:
			lift = sin(_phase * 2.2) * 4.0
			tilt = sin(_phase * 1.4) * 0.05
		draw_set_transform(Vector2(0, lift), tilt, Vector2(visual_scale, visual_scale))

		if kind == Kind.MELEE:
			_draw_husk()
		else:
			_draw_drone()

	if _attack_flash > 0.0:
		var strength := _attack_flash / 0.2
		draw_arc(Vector2(0, -40), 48.0, _facing.angle() - 0.65, _facing.angle() + 0.65, 16, Color(1.0, 0.6, 0.25, strength), 6.0)

	if _alert_flash > 0.0 or _state == State.ALERT:
		var alpha := clampf(_alert_flash / 0.6, 0.0, 1.0)
		var icon_y := -104.0 if kind == Kind.RANGED else -82.0
		var color := Color(1.0, 0.62, 0.22, alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(Vector2(-3.0, icon_y), Vector2(6.0, 16.0)), color)
		draw_circle(Vector2(0.0, icon_y + 24.0), 4.0, color)


func _draw_husk() -> void:
	var dark := Color(0.12, 0.06, 0.07)
	var body := Color(0.58, 0.2, 0.18)
	var plate := Color(0.34, 0.11, 0.1)
	var claw := Color(0.8, 0.32, 0.2)

	# 触足
	draw_line(Vector2(-12, -18), Vector2(-20, -2), dark, 8.0)
	draw_line(Vector2(12, -18), Vector2(20, -2), dark, 8.0)
	draw_line(Vector2(-6, -14), Vector2(-8, 0), dark, 6.0)
	draw_line(Vector2(6, -14), Vector2(8, 0), dark, 6.0)

	# 爪
	var left_claw := PackedVector2Array([Vector2(-24, -48), Vector2(-48, -40), Vector2(-34, -28), Vector2(-52, -18), Vector2(-26, -22)])
	var right_claw := PackedVector2Array([Vector2(24, -48), Vector2(48, -40), Vector2(34, -28), Vector2(52, -18), Vector2(26, -22)])
	draw_colored_polygon(left_claw, claw)
	draw_colored_polygon(right_claw, claw)

	# 躯干
	_ellipse(Vector2(0, -38), Vector2(25, 29), body)
	_ellipse(Vector2(0, -36), Vector2(15, 18), plate)

	# 甲片
	draw_line(Vector2(-20, -46), Vector2(20, -46), dark, 3.0)
	draw_line(Vector2(-18, -32), Vector2(18, -32), dark, 3.0)

	# 面甲
	var visor := PackedVector2Array([Vector2(-11, -54), Vector2(11, -54), Vector2(7, -44), Vector2(-7, -44)])
	draw_colored_polygon(visor, Color(1.0, 0.55, 0.2))
	draw_circle(Vector2(0, -49), 3.2, Color(1.0, 0.95, 0.8))


func _draw_drone() -> void:
	var dark := Color(0.1, 0.08, 0.16)
	var shell := Color(0.34, 0.28, 0.52)
	var glow := Color(0.55, 0.95, 1.0)

	# 悬挂腿
	draw_line(Vector2(-12, -44), Vector2(-20, -10), dark, 5.0)
	draw_line(Vector2(0, -40), Vector2(0, -6), dark, 5.0)
	draw_line(Vector2(12, -44), Vector2(20, -10), dark, 5.0)

	# 外壳
	var hull := PackedVector2Array()
	for i in 6:
		var angle := TAU * float(i) / 6.0 + PI / 6.0
		hull.append(Vector2(cos(angle) * 25.0, sin(angle) * 25.0) + Vector2(0, -64))
	draw_colored_polygon(hull, shell)
	draw_polyline(_closed(hull), dark, 3.0)

	# 旋转能量环
	draw_arc(Vector2(0, -64), 17.0, _phase * 2.4, _phase * 2.4 + TAU * 0.62, 20, glow, 3.0)
	draw_arc(Vector2(0, -64), 17.0, _phase * 2.4 + PI, _phase * 2.4 + PI + TAU * 0.35, 14, Color(0.85, 0.6, 1.0), 2.5)

	# 核心
	draw_circle(Vector2(0, -64), 9.0, Color(0.85, 0.5, 1.0))
	draw_circle(Vector2(0, -64), 4.5, Color(1.0, 0.98, 1.0))

	# 侧翼
	var left_fin := PackedVector2Array([Vector2(-24, -64), Vector2(-38, -76), Vector2(-30, -56)])
	var right_fin := PackedVector2Array([Vector2(24, -64), Vector2(38, -76), Vector2(30, -56)])
	draw_colored_polygon(left_fin, shell)
	draw_colored_polygon(right_fin, shell)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
	draw_polyline(_closed(points), Color(0.1, 0.06, 0.08), 2.5)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
