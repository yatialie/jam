extends Node2D

## 货舱转运机械臂：待机 -> 失控 -> 故障（5 秒窗口）-> 永久停机。
## 所有距离计算都在 Projection 的设计坐标空间内完成，避免纵向缩放影响判定。

signal hp_changed(current: int, maximum: int)
signal fault_started
signal fault_ended
signal arm_offline
signal ground_impact(world_position: Vector2, strength: float)
signal scripted_telegraph(lethal: bool)
signal scripted_impact(lethal: bool)
signal scripted_finished(lethal: bool)

enum State { IDLE, RAMPAGE, TELEGRAPH, SWEEP, RECOVER, FAULT, OFFLINE, SCRIPTED }

const SPARK_TEXTURE := preload("res://art_placeholder/scifi_ship_v2/vfx/impact_spark.png")
const PROJECTION_TILT := 0.72
const BASE_RADIUS := 96.0
const UPPER_LEN := 250.0
const FORE_LEN := 190.0
const TELEGRAPH_TIME := 1.2
const SWEEP_TIME := 0.18
const RECOVER_TIME := 1.4
const FAULT_TIME := 5.0
const SLAM_RADIUS := 150.0
const MANUAL_RADIUS := 150.0
const MANUAL_COOLDOWN := 0.9
const SWEEP_HIT_RADIUS := 105.0
const ENEMY_SWEEP_DAMAGE := 3

@export var reach := 500.0
@export var arc_deg := 150.0
@export var max_hp := 10
@export var fault_time := FAULT_TIME
## 血量归零后直接永久停机，不再进入故障/重启循环（第二关使用）。
@export var permanent_death_on_depleted := false

var hp := 0
var state: State = State.IDLE

var _frozen := false
var _first_sweep := false
var _manual_control := false
var _manual_cd := 0.0
var _phase := 0.0
var _state_time := 0.0
var _fault_timer := 0.0
var _attack_index := 0
var _attack_kind := 0
var _fan_center := -PI * 0.5
var _sweep_from := -PI * 0.5
var _sweep_to := -PI * 0.5
var _sweep_radius := 360.0
var _slam_local := Vector2.ZERO
var _claw_goal_local := Vector2.ZERO
var _claw_visual_local := Vector2.ZERO
var _hit_flash := 0.0
var _slam_flash := 0.0
var _sweep_hit := {}
var _spark_timer := 0.0
var _scripted_lethal := false
var _scripted_phase := 0
var _scripted_time := 0.0
var _scripted_center := 0.0
var _scripted_from := 0.0
var _scripted_to := 0.0
var _scripted_radius := 360.0
var _scripted_telegraph_time := TELEGRAPH_TIME
var _scripted_impact_sent := false

var _hurt_base: Area2D
var _hurt_tip: Area2D
var _hurt_elbow: Area2D
var _body: StaticBody2D
var _sign_bg: ColorRect
var _sign: Label


func _ready() -> void:
	add_to_group("mech_arm")
	hp = max_hp
	_claw_goal_local = Vector2.RIGHT.rotated(-PI * 0.5) * (reach * 0.56)
	_claw_visual_local = _claw_goal_local
	_build_body_collider()
	var start_ik := _ik(_claw_visual_local)
	var start_wrist: Vector2 = start_ik["wrist"]
	var start_elbow: Vector2 = start_ik["elbow"]
	_hurt_base = _make_hurtbox(100.0, Vector2.ZERO)
	_hurt_tip = _make_hurtbox(72.0, start_wrist)
	_hurt_elbow = _make_hurtbox(70.0, start_elbow)
	_build_sign()
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	_slam_flash = maxf(_slam_flash - delta, 0.0)
	_manual_cd = maxf(_manual_cd - delta, 0.0)
	modulate = Color(2.0, 2.0, 2.0) if _hit_flash > 0.0 else Color.WHITE

	if _frozen and state != State.SCRIPTED:
		queue_redraw()
		return

	match state:
		State.IDLE:
			_idle_update()
		State.RAMPAGE:
			_state_time += delta
			if _state_time >= 0.9:
				_begin_telegraph()
		State.TELEGRAPH:
			_telegraph_update(delta)
		State.SWEEP:
			_sweep_update(delta)
		State.RECOVER:
			_state_time += delta
			if _state_time >= RECOVER_TIME:
				state = State.RAMPAGE
				_state_time = 0.0
		State.FAULT:
			_fault_update(delta)
		State.OFFLINE:
			pass
		State.SCRIPTED:
			_scripted_update(delta)

	var rate := 12.0
	if state == State.SWEEP or (state == State.SCRIPTED and _scripted_phase == 2):
		rate = 60.0
	_claw_visual_local = _claw_visual_local.lerp(_claw_goal_local, 1.0 - exp(-rate * delta))
	var ik := _ik(_claw_visual_local)
	if _hurt_tip:
		_hurt_tip.position = ik["wrist"]
	if _hurt_elbow:
		_hurt_elbow.position = ik["elbow"]

	queue_redraw()


func _idle_update() -> void:
	_fan_center = -PI * 0.5 + sin(_phase * 0.55) * 0.7
	var radius := reach * 0.56 + sin(_phase * 0.9) * 22.0
	_claw_goal_local = Vector2.RIGHT.rotated(_fan_center) * radius


func _telegraph_update(delta: float) -> void:
	_state_time += delta
	if _attack_kind == 1:
		var raise := clampf(1.0 - _state_time / TELEGRAPH_TIME, 0.0, 1.0) * 60.0
		_claw_goal_local = _slam_local - position + Vector2(0, -raise)
	else:
		_claw_goal_local = Vector2.RIGHT.rotated(_sweep_from) * _sweep_radius
	if _state_time >= TELEGRAPH_TIME:
		if _attack_kind == 1:
			_do_slam()
		else:
			_begin_sweep()


func _begin_telegraph() -> void:
	var target := _pick_target()
	if target == null:
		state = State.IDLE
		_state_time = 0.0
		return

	var target_local := _to_parent_local(target.global_position)
	_attack_index += 1
	_sweep_hit.clear()

	if _attack_index % 3 == 0:
		_attack_kind = 1
		_slam_local = _clamp_to_reach(target_local, 130.0)
		_claw_goal_local = _slam_local - position + Vector2(0, -60)
	else:
		_attack_kind = 0
		_fan_center = (target_local - position).angle()
		var half := deg_to_rad(arc_deg) * 0.5
		_sweep_from = _fan_center - half
		_sweep_to = _fan_center + half
		_sweep_radius = reach * 0.72
		_claw_goal_local = Vector2.RIGHT.rotated(_sweep_from) * _sweep_radius

	state = State.TELEGRAPH
	_state_time = 0.0


func _begin_sweep() -> void:
	state = State.SWEEP
	_state_time = 0.0
	_sweep_hit.clear()


func _sweep_update(delta: float) -> void:
	_state_time += delta
	var t := clampf(_state_time / SWEEP_TIME, 0.0, 1.0)
	var angle := lerpf(_sweep_from, _sweep_to, t)
	_claw_goal_local = Vector2.RIGHT.rotated(angle) * _sweep_radius
	_sweep_check()
	if t >= 1.0:
		state = State.RECOVER
		_state_time = 0.0


func _sweep_check() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		_try_sweep_hit(node, true)
	for node in get_tree().get_nodes_in_group("enemies"):
		_try_sweep_hit(node, false)


func _try_sweep_hit(node: Node, is_player: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _sweep_hit.has(node.get_instance_id()):
		return
	if not is_player and int(node.get("hp")) <= 0:
		return
	if is_player and node.has_method("is_dead") and node.is_dead():
		return

	var target := node as Node2D
	if target == null:
		return
	var p := _to_parent_local(target.global_position) - position
	var claw := _claw_goal_local
	if p.distance_to(claw) > SWEEP_HIT_RADIUS:
		return

	_sweep_hit[node.get_instance_id()] = true
	var dir := p.normalized() if p.length() > 0.01 else Vector2.DOWN
	if is_player:
		if node.has_method("take_damage"):
			node.call("take_damage", 1, dir)
	else:
		for i in ENEMY_SWEEP_DAMAGE:
			if node.has_method("hit"):
				node.call("hit", dir)
	_spawn_sparks(_to_global(position + claw))


func _do_slam() -> void:
	_slam_flash = 0.32
	_spawn_shockwave(_slam_local - position, Color(1.0, 0.42, 0.2, 0.9))
	_spawn_sparks(_to_global(_slam_local))

	for node in get_tree().get_nodes_in_group("player"):
		_damage_in_slam(node, true)
	for node in get_tree().get_nodes_in_group("enemies"):
		_damage_in_slam(node, false)

	ground_impact.emit(_to_global(_slam_local), 0.6)
	state = State.RECOVER
	_state_time = 0.0


func _damage_in_slam(node: Node, is_player: bool) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not is_player and int(node.get("hp")) <= 0:
		return
	if is_player and node.has_method("is_dead") and node.is_dead():
		return
	var target := node as Node2D
	if target == null:
		return
	var p := _to_parent_local(target.global_position)
	if p.distance_to(_slam_local) > SLAM_RADIUS:
		return
	var dir := (p - _slam_local).normalized() if p.distance_to(_slam_local) > 0.01 else Vector2.DOWN
	if is_player:
		if node.has_method("take_damage"):
			node.call("take_damage", 1, dir)
	else:
		for i in ENEMY_SWEEP_DAMAGE:
			if node.has_method("hit"):
				node.call("hit", dir)


func _fault_update(delta: float) -> void:
	_fault_timer = maxf(_fault_timer - delta, 0.0)
	_spark_timer -= delta
	if _spark_timer <= 0.0:
		_spark_timer = 0.3
		var ik := _ik(_claw_visual_local)
		_spawn_sparks(_to_global(ik["elbow"]))
	if _manual_control:
		_manual_update()
	if _fault_timer <= 0.0:
		reboot()


func _manual_update() -> void:
	if get_tree().get_first_node_in_group("modal") != null:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _manual_cd > 0.0:
		return
	var parent := get_parent() as Node2D
	if parent == null:
		return
	var target_local := parent.to_local(get_global_mouse_position())
	_manual_cd = MANUAL_COOLDOWN
	_slam_local = _clamp_to_reach(target_local, 80.0)
	_claw_goal_local = _slam_local - position
	_slam_flash = 0.3
	_spawn_shockwave(_slam_local - position, Color(0.45, 0.9, 1.0, 0.8))
	_spawn_sparks(_to_global(_slam_local))

	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if int(node.get("hp")) <= 0:
			continue
		var enemy := node as Node2D
		if enemy == null:
			continue
		var p := _to_parent_local(enemy.global_position)
		if p.distance_to(_slam_local) > MANUAL_RADIUS:
			continue
		var dir := (p - _slam_local).normalized() if p.distance_to(_slam_local) > 0.01 else Vector2.DOWN
		for i in ENEMY_SWEEP_DAMAGE:
			if enemy.has_method("hit"):
				enemy.call("hit", dir)
	ground_impact.emit(_to_global(_slam_local), 0.25)


func _scripted_update(delta: float) -> void:
	_scripted_time += delta
	match _scripted_phase:
		0:
			_claw_goal_local = Vector2.RIGHT.rotated(_scripted_from) * _scripted_radius
			if _scripted_time >= 0.5:
				_scripted_phase = 1
				_scripted_time = 0.0
				scripted_telegraph.emit(_scripted_lethal)
		1:
			_claw_goal_local = Vector2.RIGHT.rotated(_scripted_from) * _scripted_radius
			if _scripted_time >= _scripted_telegraph_time:
				_scripted_phase = 2
				_scripted_time = 0.0
		2:
			var t := clampf(_scripted_time / SWEEP_TIME, 0.0, 1.0)
			var angle := lerpf(_scripted_from, _scripted_to, t)
			_claw_goal_local = Vector2.RIGHT.rotated(angle) * _scripted_radius
			if t >= 0.45 and not _scripted_impact_sent:
				_scripted_impact_sent = true
				_spawn_shockwave(_claw_goal_local, Color(1.0, 0.35, 0.2, 0.8))
				_spawn_sparks(_to_global(position + _claw_goal_local))
				scripted_impact.emit(_scripted_lethal)
			if t >= 1.0:
				_scripted_phase = 3
				_scripted_time = 0.0
		3:
			if _scripted_time >= 0.5:
				state = State.IDLE
				_state_time = 0.0
				scripted_finished.emit(_scripted_lethal)


func _pick_target() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_valid := player != null and is_instance_valid(player)
	if player_valid and player.has_method("is_dead") and player.is_dead():
		player_valid = false

	if _first_sweep:
		_first_sweep = false
		var nearest := _nearest_enemy()
		if nearest != null:
			return nearest

	if player_valid and randf() < 0.75:
		return player

	var enemy := _nearest_enemy()
	if enemy != null:
		return enemy
	return player if player_valid else null


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node):
			continue
		if int(node.get("hp")) <= 0:
			continue
		var enemy := node as Node2D
		if enemy == null:
			continue
		var d := _to_parent_local(enemy.global_position).distance_to(position)
		if d < best_distance:
			best_distance = d
			best = enemy
	return best


func _clamp_to_reach(parent_local: Vector2, min_radius: float) -> Vector2:
	var offset := parent_local - position
	var length := clampf(offset.length(), min_radius, reach)
	var dir := offset.normalized() if offset.length() > 0.01 else Vector2.DOWN
	return position + dir * length


func _to_parent_local(world_point: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(world_point) if parent else world_point


func _to_global(parent_local: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_global(parent_local) if parent else parent_local


func _ik(target_local: Vector2) -> Dictionary:
	var distance := clampf(target_local.length(), 80.0, UPPER_LEN + FORE_LEN - 12.0)
	var base_angle := target_local.angle()
	var cos_a := (UPPER_LEN * UPPER_LEN + distance * distance - FORE_LEN * FORE_LEN) / (2.0 * UPPER_LEN * distance)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var upper_angle := base_angle - a
	var elbow := Vector2.RIGHT.rotated(upper_angle) * UPPER_LEN
	var wrist := Vector2.RIGHT.rotated(base_angle) * distance
	return {
		"elbow": elbow,
		"wrist": wrist,
		"upper_angle": upper_angle,
		"fore_angle": (wrist - elbow).angle(),
		"distance": distance,
	}


func begin_rampage() -> void:
	_frozen = false
	_manual_control = false
	_first_sweep = true
	_attack_index = 0
	_state_time = 0.0
	_fault_timer = 0.0
	hp = max_hp
	state = State.RAMPAGE
	hp_changed.emit(hp, max_hp)
	queue_redraw()


func set_frozen(value: bool) -> void:
	_frozen = value
	if value:
		state = State.IDLE
		_state_time = 0.0


func play_scripted_sweep(target_global: Vector2, lethal: bool, telegraph_time := TELEGRAPH_TIME) -> void:
	var target_local := _to_parent_local(target_global)
	var offset := target_local - position
	_scripted_lethal = lethal
	_scripted_telegraph_time = maxf(telegraph_time, 0.2)
	_scripted_radius = clampf(offset.length(), 140.0, reach * 0.95)
	_scripted_center = offset.angle()
	var half := deg_to_rad(arc_deg) * 0.5
	_scripted_from = _scripted_center - half
	_scripted_to = _scripted_center + half
	_scripted_phase = 0
	_scripted_time = 0.0
	_scripted_impact_sent = false
	_fan_center = _scripted_center
	_claw_goal_local = Vector2.RIGHT.rotated(_scripted_from) * _scripted_radius
	_frozen = false
	state = State.SCRIPTED


func hit(_direction: Vector2, amount: int = 1) -> void:
	if state == State.IDLE or state == State.SCRIPTED or state == State.FAULT or state == State.OFFLINE:
		_spawn_sparks(_to_global(_claw_visual_local))
		return
	hp = maxi(hp - maxi(amount, 1), 0)
	_hit_flash = 0.1
	hp_changed.emit(hp, max_hp)
	_spawn_sparks(_to_global(_claw_visual_local))
	if hp <= 0:
		if permanent_death_on_depleted:
			_destroy_arm()
		else:
			_enter_fault()


func _destroy_arm() -> void:
	_slam_flash = 0.45
	_spawn_shockwave(position + _claw_visual_local, Color(1.0, 0.5, 0.2, 0.9))
	_spawn_sparks(_to_global(position + _claw_visual_local))
	ground_impact.emit(_to_global(position), 0.8)
	shutdown_arm()
	_destroy_colliders()


## 彻底死亡后移除基座碰撞与受击区域，尸体不再阻挡玩家或吸收子弹。
func _destroy_colliders() -> void:
	if _body:
		_body.queue_free()
		_body = null
	for area in [_hurt_base, _hurt_tip, _hurt_elbow]:
		if area:
			area.queue_free()
	_hurt_base = null
	_hurt_tip = null
	_hurt_elbow = null


func _enter_fault() -> void:
	if state == State.FAULT or state == State.OFFLINE:
		return
	state = State.FAULT
	_state_time = 0.0
	_fault_timer = fault_time
	_manual_cd = 0.0
	_spark_timer = 0.0
	_manual_control = false
	fault_started.emit()
	queue_redraw()


func reboot() -> void:
	if state == State.OFFLINE:
		return
	state = State.RAMPAGE
	_state_time = 0.0
	_fault_timer = 0.0
	_manual_control = false
	hp = maxi(int(ceil(float(max_hp) * 0.5)), 1)
	hp_changed.emit(hp, max_hp)
	fault_ended.emit()
	queue_redraw()


func cancel_fault() -> void:
	if state == State.FAULT:
		reboot()


func shutdown_arm() -> void:
	if state == State.OFFLINE:
		return
	state = State.OFFLINE
	_manual_control = false
	hp = 0
	hp_changed.emit(hp, max_hp)
	arm_offline.emit()
	queue_redraw()


func set_manual_control(value: bool) -> void:
	_manual_control = value
	if value:
		_manual_cd = 0.0


func is_fault() -> bool:
	return state == State.FAULT


func is_offline() -> bool:
	return state == State.OFFLINE


func get_fault_remaining() -> float:
	return _fault_timer if state == State.FAULT else 0.0


func get_state_label() -> String:
	match state:
		State.IDLE:
			return "STANDBY"
		State.RAMPAGE, State.TELEGRAPH, State.SWEEP, State.RECOVER:
			return "HOSTILE"
		State.FAULT:
			return "FAULT"
		State.OFFLINE:
			return "OFFLINE"
		State.SCRIPTED:
			return "OVERLOAD"
	return "UNKNOWN"


func show_sign(value: bool) -> void:
	if _sign:
		_sign.visible = value
	if _sign_bg:
		_sign_bg.visible = value


func set_sign_text(text: String) -> void:
	if _sign:
		_sign.text = text


func get_arm_debug() -> Dictionary:
	return {
		"enabled": true,
		"base": _to_global(position),
		"reach": reach,
		"arc_deg": arc_deg,
		"yaw": _fan_center,
		"claw_radius": _sweep_radius,
		"slam_point": _to_global(_slam_local),
		"slam_radius": SLAM_RADIUS,
		"state": get_state_label(),
	}


func _build_body_collider() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BASE_RADIUS
	shape.shape = circle
	_body.add_child(shape)
	add_child(_body)


func _make_hurtbox(radius: float, offset: Vector2) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.position = offset
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	return area


func _build_sign() -> void:
	_sign_bg = ColorRect.new()
	_sign_bg.color = Color(0.03, 0.05, 0.06, 0.88)
	_sign_bg.position = Vector2(-94, 56)
	_sign_bg.size = Vector2(188, 56)
	_sign_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign_bg.scale = Vector2(1, 1.0 / PROJECTION_TILT)
	add_child(_sign_bg)

	_sign = Label.new()
	_sign.text = "EMERGENCY STOP\nCODE 9-2-5"
	_sign.position = Vector2(-94, 58)
	_sign.size = Vector2(188, 52)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sign.add_theme_font_size_override("font_size", 15)
	_sign.add_theme_color_override("font_color", Color(1.0, 0.74, 0.32, 1.0))
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.scale = Vector2(1, 1.0 / PROJECTION_TILT)
	add_child(_sign)
	show_sign(false)


func _spawn_sparks(global_point: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var flash := Sprite2D.new()
	flash.texture = SPARK_TEXTURE
	flash.hframes = 5
	flash.frame = 0
	flash.position = _to_parent_local(global_point)
	flash.z_index = 14
	flash.scale = Vector2(0.7, 0.7 / PROJECTION_TILT)
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.material = material
	parent.add_child(flash)

	var tween := flash.create_tween()
	tween.tween_method(_set_spark_frame.bind(flash), 0.0, 4.0, 0.2)
	tween.tween_callback(flash.queue_free)


func _set_spark_frame(value: float, flash: Sprite2D) -> void:
	flash.frame = int(value)


func _spawn_shockwave(parent_local: Vector2, color: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for i in 40:
		var angle := TAU * float(i) / 40.0
		points.append(Vector2(cos(angle), sin(angle)))
	points.append(points[0])
	ring.points = points
	ring.width = 6.0
	ring.default_color = color
	ring.position = parent_local
	ring.scale = Vector2(30.0, 30.0)
	ring.z_index = 3
	parent.add_child(ring)

	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(220.0, 220.0), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)


func _draw() -> void:
	# 地面阴影与基座
	draw_circle(Vector2(0, 10), 116.0, Color(0, 0, 0, 0.24))
	draw_circle(Vector2.ZERO, 102.0, Color(0.09, 0.11, 0.14))
	draw_arc(Vector2.ZERO, 102.0, 0.0, TAU, 48, Color(0.16, 0.2, 0.24), 8.0)
	draw_arc(Vector2.ZERO, 96.0, 0.0, TAU, 48, Color(0.95, 0.62, 0.2, 0.7), 3.0)

	for i in 20:
		var angle := TAU * float(i) / 20.0
		var a := Vector2.RIGHT.rotated(angle) * 84.0
		var b := Vector2.RIGHT.rotated(angle) * 100.0
		draw_line(a, b, Color(0.86, 0.55, 0.18, 0.55), 4.0)

	if state == State.TELEGRAPH or state == State.SWEEP:
		_draw_attack_zone()
	elif state == State.SCRIPTED:
		_draw_scripted_zone()

	var ik := _ik(_claw_visual_local)
	var elbow: Vector2 = ik["elbow"]
	var wrist: Vector2 = ik["wrist"]
	var fore_angle: float = ik["fore_angle"]

	# 上臂 / 前臂 / 关节
	draw_line(Vector2.ZERO, elbow, Color(0.05, 0.06, 0.08), 58.0)
	draw_line(Vector2.ZERO, elbow, Color(0.42, 0.47, 0.53), 42.0)
	draw_line(Vector2.ZERO, elbow, Color(0.62, 0.68, 0.74, 0.55), 10.0)
	draw_circle(Vector2.ZERO, 34.0, Color(0.16, 0.2, 0.24))
	draw_circle(Vector2.ZERO, 24.0, Color(0.55, 0.6, 0.66))
	draw_circle(elbow, 27.0, Color(0.08, 0.1, 0.12))
	draw_circle(elbow, 19.0, Color(0.5, 0.56, 0.62))

	draw_line(elbow, wrist, Color(0.05, 0.06, 0.08), 46.0)
	draw_line(elbow, wrist, Color(0.36, 0.41, 0.47), 32.0)
	draw_line(elbow, wrist, Color(0.6, 0.72, 0.78, 0.5), 8.0)
	draw_circle(wrist, 20.0, Color(0.1, 0.12, 0.15))
	draw_circle(wrist, 13.0, Color(0.55, 0.6, 0.66))

	# 爪
	var claw_dir := Vector2.RIGHT.rotated(fore_angle)
	var claw_side := claw_dir.orthogonal()
	for sign_side in [-1.0, 1.0]:
		var root: Vector2 = wrist + claw_side * 12.0 * float(sign_side)
		var tip: Vector2 = wrist + claw_dir * 44.0 + claw_side * 22.0 * float(sign_side)
		draw_line(root, tip, Color(0.08, 0.1, 0.12), 15.0)
		draw_line(root, tip, Color(0.68, 0.72, 0.76), 8.0)

	# 待机时搬运的货箱
	if state == State.IDLE and not _frozen:
		var box_center := wrist + claw_dir * 34.0
		var box := PackedVector2Array([
			box_center + Vector2(-20, -16),
			box_center + Vector2(20, -16),
			box_center + Vector2(20, 16),
			box_center + Vector2(-20, 16),
		])
		draw_colored_polygon(box, Color(0.45, 0.33, 0.2))
		draw_polyline(_closed(box), Color(0.24, 0.16, 0.09), 2.5)
		draw_line(box_center + Vector2(-14, -16), box_center + Vector2(-14, 16), Color(0.86, 0.62, 0.28, 0.6), 3.0)

	# 状态灯
	var light_color := Color(1.0, 0.65, 0.2, 0.9)
	var pulse := 0.55 + 0.45 * sin(_phase * 3.0)
	if state == State.OFFLINE:
		light_color = Color(0.35, 1.0, 0.55, 0.95)
		pulse = 1.0
	elif state == State.FAULT:
		light_color = Color(1.0, 0.55, 0.15, 0.9)
		pulse = 0.35 + 0.65 * absf(sin(_phase * 8.0))
	elif state == State.TELEGRAPH or state == State.SWEEP or state == State.SCRIPTED:
		light_color = Color(1.0, 0.24, 0.18, 0.95)
		pulse = 0.65 + 0.35 * sin(_phase * 12.0)
	draw_circle(elbow + Vector2(0, -22), 15.0, Color(light_color.r, light_color.g, light_color.b, light_color.a * pulse))
	draw_circle(elbow + Vector2(0, -22), 6.0, Color(1, 0.95, 0.85, pulse))

	if state == State.RAMPAGE or state == State.TELEGRAPH or state == State.SWEEP or state == State.RECOVER or state == State.FAULT:
		_draw_hp_bar()

	if _slam_flash > 0.0:
		var strength := _slam_flash / 0.32
		var slam_local := _slam_local - position
		draw_arc(slam_local, SLAM_RADIUS * (1.0 + (1.0 - strength) * 0.25), 0.0, TAU, 40, Color(1.0, 0.45, 0.2, strength), 6.0)


func _draw_attack_zone() -> void:
	var pulse := 0.5 + 0.5 * sin(_phase * 10.0)
	var half := deg_to_rad(arc_deg) * 0.5
	var alpha := 0.10 + pulse * 0.08
	if state == State.SWEEP:
		alpha = 0.06
	draw_arc(Vector2.ZERO, _sweep_radius, _fan_center - half, _fan_center + half, 44, Color(1.0, 0.24, 0.18, alpha), SWEEP_HIT_RADIUS * 2.0)
	draw_arc(Vector2.ZERO, _sweep_radius, _fan_center - half, _fan_center + half, 44, Color(1.0, 0.4, 0.25, 0.72), 3.0)

	if _attack_kind == 1 and state == State.TELEGRAPH:
		var slam_local := _slam_local - position
		var fill := 0.12 + pulse * 0.10
		draw_circle(slam_local, SLAM_RADIUS, Color(1.0, 0.22, 0.16, fill))
		draw_arc(slam_local, SLAM_RADIUS, 0.0, TAU, 40, Color(1.0, 0.4, 0.25, 0.8), 4.0)
		draw_arc(slam_local, SLAM_RADIUS * clampf(_state_time / TELEGRAPH_TIME, 0.0, 1.0), 0.0, TAU, 40, Color(1.0, 0.75, 0.35, 0.9), 3.0)


func _draw_scripted_zone() -> void:
	var pulse := 0.5 + 0.5 * sin(_phase * 10.0)
	var half := deg_to_rad(arc_deg) * 0.5
	var alpha := 0.1 + pulse * 0.09
	draw_arc(Vector2.ZERO, _scripted_radius, _scripted_center - half, _scripted_center + half, 44, Color(1.0, 0.2, 0.15, alpha), SWEEP_HIT_RADIUS * 1.9)
	draw_arc(Vector2.ZERO, _scripted_radius, _scripted_center - half, _scripted_center + half, 44, Color(1.0, 0.36, 0.22, 0.8), 3.5)


func _draw_hp_bar() -> void:
	var width := 150.0
	var height := 10.0
	var origin := Vector2(-width * 0.5, -176.0)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.02, 0.03, 0.04, 0.9))
	var ratio := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var fill := Color(0.35, 0.9, 1.0)
	if ratio < 0.35:
		fill = Color(1.0, 0.35, 0.25)
	elif ratio < 0.7:
		fill = Color(1.0, 0.72, 0.25)
	draw_rect(Rect2(origin + Vector2(2, 2), Vector2((width - 4) * ratio, height - 4)), fill)
	draw_rect(Rect2(origin, Vector2(width, height)), Color(0.35, 0.5, 0.58, 0.8), false, 2.0)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
