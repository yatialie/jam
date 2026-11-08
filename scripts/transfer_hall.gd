extends Node2D

## 转运仓关卡导演：引导 -> 两次脚本初见杀 -> 正式战斗 -> 机械臂急停 -> 出口门禁。

signal enemy_count_changed(count: int)
signal room_cleared

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_SPECS := [
	{"pos": Vector2(620, 1050), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 40.0, "detect": 280.0, "leash": 340.0},
	{"pos": Vector2(1230, 1120), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"pos": Vector2(1160, 700), "kind": 1, "hp": 2, "speed": 90.0, "patrol": 140.0, "detect": 300.0, "leash": 360.0},
]
const CONSOLE_RANGE := 178.0
const ARM_RANGE := 190.0
const CAMERA_BASE_OFFSET := Vector2(0, -28)
const CAMERA_ALIGN_OFFSET := Vector2(-190, -28)
const CAMERA_ALIGN_LIMIT_LEFT := -320

enum Phase { INTRO, ALIGN, SCRIPTED, COMBAT, DONE }

@onready var projection: Node2D = $Projection
@onready var player = $Projection/Player
@onready var arm = $Projection/Arm
@onready var enemies_root: Node2D = $Projection/Enemies
@onready var art = $Projection/World
@onready var console_point: Marker2D = $Projection/ConsolePoint
@onready var respawn_point: Marker2D = $Projection/RespawnPoint
@onready var exit_door = $Projection/World/ExitDoor
@onready var camera = $CameraRig
@onready var hud = $HUD
@onready var align_ui = $AlignUI
@onready var keypad_ui = $KeypadUI
@onready var pause_overlay: Control = $PauseOverlay/Panel

var _phase := Phase.INTRO
var _enemies_alive := 0
var _arm_offline := false
var _cleared := false
var _awaiting_respawn := false
var _scripted_target := Vector2.ZERO
var _status_timer := 0.0

var _objective_bg: ColorRect
var _objective_label: Label
var _prompt_bg: ColorRect
var _prompt_label: Label
var _pa_bg: ColorRect
var _pa_label: Label
var _pa_tween: Tween


func _ready() -> void:
	pause_overlay.visible = false
	player.set_respawn_point(respawn_point.global_position)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)

	arm.hp_changed.connect(_on_arm_hp_changed)
	arm.fault_started.connect(_on_arm_fault_started)
	arm.fault_ended.connect(_on_arm_fault_ended)
	arm.arm_offline.connect(_on_arm_offline)
	arm.ground_impact.connect(_on_ground_impact)
	arm.scripted_telegraph.connect(_on_arm_telegraph)
	arm.scripted_impact.connect(_on_arm_impact)
	arm.scripted_finished.connect(_on_arm_scripted_finished)

	align_ui.solved.connect(_on_alignment_solved)
	align_ui.closed.connect(_on_alignment_closed)
	keypad_ui.solved.connect(_on_override_solved)
	keypad_ui.closed.connect(_on_keypad_closed)

	exit_door.passed_through.connect(_on_exit_passed)
	exit_door.locked_hint = "LOCKED — CALIBRATION REQUIRED"

	_build_overlay()
	MissionLog.start_chapter("transfer")
	MissionLog.set_task_target("tr_hostiles", ENEMY_SPECS.size())

	_update_status()
	_update_objective("CALIBRATE THE TRANSFER ARM")
	hud.announce("TRANSFER HALL", "CALIBRATE THE TRANSFER ARM", 1.8)
	_say("PA // CARGO TRANSFER ARM AWAITING CALIBRATION. FOLLOW THE RED LIGHTS.", 4.6)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if get_tree().get_first_node_in_group("modal") == null and Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
		return

	_hide_prompt()
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status_timer = 0.12
		_update_status()

	if player.is_dead():
		return

	var modal := get_tree().get_first_node_in_group("modal") != null
	if (_phase == Phase.INTRO or _phase == Phase.ALIGN) and not modal:
		if _near_console():
			_show_prompt("F   CALIBRATE ARM", Color(0.45, 0.95, 1.0))
			if _phase == Phase.INTRO and Input.is_action_just_pressed("interact"):
				_open_alignment()
	elif _phase == Phase.COMBAT and not modal:
		if arm.is_fault() and _near_arm():
			_show_prompt("F   EMERGENCY STOP   //   9-2-5", Color(1.0, 0.72, 0.3))
			if Input.is_action_just_pressed("interact"):
				_open_keypad()


func _open_alignment() -> void:
	if _phase != Phase.INTRO:
		return
	_phase = Phase.ALIGN
	arm.set_frozen(true)
	_set_align_camera(true)
	align_ui.open()
	_say("PA // MANUAL CALIBRATION LINK ESTABLISHED.", 3.0)


func _on_alignment_solved() -> void:
	align_ui.lock()
	art.set_guide_active(false)
	MissionLog.complete_task("tr_align")
	_phase = Phase.SCRIPTED
	_update_objective("CALIBRATION COMPLETE")
	hud.announce("CALIBRATION COMPLETE", "RETURNING ARM TO SERVICE", 1.4)
	_say("PA // CALIBRATION ACCEPTED. RETURNING ARM TO SERVICE.", 2.8)

	await get_tree().create_timer(0.9).timeout
	if _phase != Phase.SCRIPTED:
		return
	_scripted_target = _smash_point()
	arm.play_scripted_sweep(_scripted_target, false)


func _on_alignment_closed() -> void:
	if _phase == Phase.ALIGN:
		_phase = Phase.INTRO
		arm.set_frozen(false)
		_set_align_camera(false)
		_say("PA // CALIBRATION LINK CLOSED. APPROACH THE TERMINAL TO RETRY.", 3.0)


func _on_arm_telegraph(lethal: bool) -> void:
	if lethal:
		align_ui.glitch(1.2)
		camera.add_trauma(0.25)
		_say("PA // CONSOLE LOCK ENGAGED. BRACE.", 2.4)
	else:
		align_ui.glitch(0.6)
		camera.add_trauma(0.18)
		_say("PA // WARNING. ARM ACTUATOR FAULT. CLEAR THE ARC.", 2.8)


func _on_arm_impact(lethal: bool) -> void:
	camera.add_trauma(1.0 if lethal else 0.6)
	if lethal:
		_awaiting_respawn = true
		align_ui.shatter()
		art.destroy_console()
		art.spawn_impact_debris(_scripted_target)
		_say("PA // CRITICAL IMPACT. SUIT SIGNAL LOST.", 3.2)
		player.scripted_kill()
	else:
		align_ui.glitch(1.0)
		art.smash_crate()
		art.spawn_impact_debris(_scripted_target)
		_say("PA // PROXIMITY ALERT. ARM ACTUATOR FAILURE.", 3.0)


func _on_arm_scripted_finished(lethal: bool) -> void:
	if lethal:
		return
	await get_tree().create_timer(1.2).timeout
	if _phase != Phase.SCRIPTED or player.is_dead():
		return
	_scripted_target = player.global_position
	arm.play_scripted_sweep(_scripted_target, true)


func _on_player_died() -> void:
	if _phase == Phase.SCRIPTED:
		_awaiting_respawn = true
		return
	if _phase == Phase.COMBAT:
		if arm.is_fault():
			arm.cancel_fault()
		player.set_weapon_disabled(false)


func _on_player_respawned() -> void:
	player.set_physics_process(true)
	if _phase == Phase.SCRIPTED or _awaiting_respawn:
		_awaiting_respawn = false
		_start_combat()
	else:
		player.set_weapon_disabled(false)
		_update_status()


func _start_combat() -> void:
	_phase = Phase.COMBAT
	_arm_offline = false
	_enemies_alive = 0
	_cleared = false
	_set_align_camera(false)

	for spec in ENEMY_SPECS:
		_spawn_enemy(spec)

	arm.begin_rampage()
	arm.show_sign(true)
	player.set_weapon_disabled(false)
	_emit_enemy_count()
	exit_door.locked_hint = "LOCKED — HOSTILES REMAIN"

	_update_objective("SHOOT THE ARM — FORCE A FAULT")
	_update_status()
	hud.announce("ARM HOSTILE", "FORCE A FAULT — ENTER 9-2-5", 2.2)
	_say("PA // TRANSFER ARM HOSTILE. EMERGENCY STOP CODE NINE-TWO-FIVE.", 5.2)


func _spawn_enemy(spec: Dictionary) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = spec["pos"]
	enemy.kind = spec["kind"]
	enemy.max_hp = spec["hp"]
	enemy.move_speed = spec["speed"]
	enemy.behavior_mode = 0
	enemy.patrol_radius = spec["patrol"]
	enemy.detection_radius = spec["detect"]
	enemy.leash_radius = spec["leash"]
	enemy.died.connect(_on_enemy_died)
	enemies_root.add_child(enemy)
	_enemies_alive += 1


func _on_enemy_died() -> void:
	_enemies_alive = maxi(_enemies_alive - 1, 0)
	MissionLog.add_task_progress("tr_hostiles")
	_emit_enemy_count()
	_check_gate()


func _on_ground_impact(_world_position: Vector2, strength: float) -> void:
	camera.add_trauma(strength)


func _on_arm_hp_changed(_current: int, _maximum: int) -> void:
	_update_status()


func _on_arm_fault_started() -> void:
	player.set_weapon_disabled(true)
	arm.set_manual_control(true)
	_update_objective("LMB SLAM  ·  E AT BASE  9-2-5")
	_update_status()
	hud.announce("ARM FAULT", "5 SECONDS — ENTER 9-2-5", 1.8)
	_say("PA // ARM FAULT. FIVE SECONDS. MANUAL OVERRIDE AT THE BASE.", 3.8)


func _on_arm_fault_ended() -> void:
	player.set_weapon_disabled(false)
	arm.set_manual_control(false)
	if keypad_ui.is_open():
		keypad_ui.close()
	_update_objective("SHOOT THE ARM — FORCE A FAULT")
	_update_status()
	hud.announce("ARM REBOOTED", "OVERRIDE WINDOW LOST", 1.6)
	_say("PA // OVERRIDE WINDOW LOST. ARM REBOOTING.", 3.0)


func _on_arm_offline() -> void:
	_arm_offline = true
	player.set_weapon_disabled(false)
	arm.set_manual_control(false)
	MissionLog.complete_task("tr_stop")
	_emit_enemy_count()
	_update_status()
	_update_objective("CLEAR REMAINING HOSTILES")
	hud.announce("ARM OFFLINE", "CLEAR REMAINING HOSTILES", 2.0)
	_say("PA // TRANSFER ARM OFFLINE. CLEAR REMAINING HOSTILES.", 3.4)
	_check_gate()


func _on_override_solved() -> void:
	arm.shutdown_arm()


func _on_keypad_closed() -> void:
	if arm.is_fault():
		arm.set_manual_control(true)


func _open_keypad() -> void:
	if keypad_ui.is_open():
		return
	arm.set_manual_control(false)
	keypad_ui.open(arm)
	_say("PA // MANUAL OVERRIDE LINK OPEN. ENTER 9-2-5.", 2.6)


func _check_gate() -> void:
	if _cleared:
		return
	if _enemies_alive > 0:
		exit_door.locked_hint = "LOCKED — HOSTILES REMAIN"
		return
	if not _arm_offline:
		exit_door.locked_hint = "LOCKED — ARM STILL ACTIVE"
		return
	_cleared = true
	_phase = Phase.DONE
	if exit_door.has_method("unlock"):
		exit_door.call("unlock")
	_update_objective("PROCEED TO THE EXIT")
	hud.announce("EXIT UNLOCKED", "PROCEED TO COMBAT DECK", 2.4)
	_say("PA // EXIT UNLOCKED. PROCEED TO THE COMBAT DECK.", 4.0)


func _on_exit_passed() -> void:
	MissionLog.complete_task("tr_exit")


func _emit_enemy_count() -> void:
	var total := _enemies_alive + (0 if _arm_offline else 1)
	enemy_count_changed.emit(total)


func _update_status() -> void:
	if hud == null or not hud.has_method("set_status"):
		return
	var label := "STANDBY"
	if arm.has_method("get_state_label"):
		label = String(arm.call("get_state_label"))
	if label == "OFFLINE":
		hud.set_status("ARM  OFFLINE", Color(0.45, 1.0, 0.65))
	elif label == "FAULT":
		hud.set_status("ARM  FAULT  %.1fs" % arm.get_fault_remaining(), Color(1.0, 0.45, 0.3))
	elif label == "OVERLOAD":
		hud.set_status("ARM  OVERLOAD", Color(1.0, 0.3, 0.25))
	elif _phase == Phase.COMBAT:
		hud.set_status("ARM  HOSTILE  %d/%d" % [arm.hp, arm.max_hp], Color(1.0, 0.58, 0.35))
	else:
		hud.set_status("ARM  STANDBY", Color(0.4, 0.9, 1.0))


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = "OBJECTIVE   //   " + text


func _near_console() -> bool:
	var local := projection.to_local(player.global_position)
	return local.distance_to(console_point.position) < CONSOLE_RANGE


func _near_arm() -> bool:
	var local := projection.to_local(player.global_position)
	return local.distance_to(arm.position) < ARM_RANGE


func _set_align_camera(enabled: bool) -> void:
	if camera == null:
		return
	camera.framing_offset = CAMERA_ALIGN_OFFSET if enabled else CAMERA_BASE_OFFSET
	camera.limit_left = CAMERA_ALIGN_LIMIT_LEFT if enabled else 0


func _smash_point() -> Vector2:
	if art.has_method("get_smash_point"):
		return art.call("get_smash_point")
	return player.global_position + Vector2(70, -70)


func _show_prompt(text: String, color: Color) -> void:
	_prompt_label.text = text
	_prompt_label.add_theme_color_override("font_color", color)
	_prompt_label.visible = true
	_prompt_bg.visible = true


func _hide_prompt() -> void:
	_prompt_label.visible = false
	_prompt_bg.visible = false


func _say(text: String, duration: float) -> void:
	if _pa_tween and _pa_tween.is_valid():
		_pa_tween.kill()
	_pa_label.text = text
	_pa_bg.visible = true
	_pa_label.visible = true
	_pa_bg.modulate.a = 0.0
	_pa_label.modulate.a = 0.0
	_pa_tween = create_tween()
	_pa_tween.set_parallel(true)
	_pa_tween.tween_property(_pa_bg, "modulate:a", 1.0, 0.18)
	_pa_tween.tween_property(_pa_label, "modulate:a", 1.0, 0.18)
	_pa_tween.set_parallel(false)
	_pa_tween.tween_interval(maxf(duration, 0.5))
	_pa_tween.set_parallel(true)
	_pa_tween.tween_property(_pa_bg, "modulate:a", 0.0, 0.4)
	_pa_tween.tween_property(_pa_label, "modulate:a", 0.0, 0.4)


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 6
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_objective_bg = ColorRect.new()
	_objective_bg.position = Vector2(744, 112)
	_objective_bg.size = Vector2(700, 46)
	_objective_bg.color = Color(0.03, 0.05, 0.07, 0.78)
	_objective_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_objective_bg)

	var accent := ColorRect.new()
	accent.position = Vector2.ZERO
	accent.size = Vector2(4, 46)
	accent.color = Color(0.3, 0.85, 0.95, 0.8)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_bg.add_child(accent)

	_objective_label = Label.new()
	_objective_label.position = Vector2(14, 4)
	_objective_label.size = Vector2(672, 38)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_bg.add_child(_objective_label)

	_prompt_bg = ColorRect.new()
	_prompt_bg.position = Vector2(660, 782)
	_prompt_bg.size = Vector2(600, 46)
	_prompt_bg.color = Color(0.02, 0.04, 0.06, 0.82)
	_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bg.visible = false
	layer.add_child(_prompt_bg)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(660, 786)
	_prompt_label.size = Vector2(600, 38)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.visible = false
	layer.add_child(_prompt_label)

	_pa_bg = ColorRect.new()
	_pa_bg.position = Vector2(460, 844)
	_pa_bg.size = Vector2(1000, 54)
	_pa_bg.color = Color(0.03, 0.04, 0.05, 0.8)
	_pa_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pa_bg.visible = false
	layer.add_child(_pa_bg)

	var pa_accent := ColorRect.new()
	pa_accent.position = Vector2.ZERO
	pa_accent.size = Vector2(4, 54)
	pa_accent.color = Color(0.95, 0.6, 0.2, 0.85)
	pa_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pa_bg.add_child(pa_accent)

	_pa_label = Label.new()
	_pa_label.position = Vector2(16, 4)
	_pa_label.size = Vector2(968, 46)
	_pa_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pa_label.add_theme_font_size_override("font_size", 18)
	_pa_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42))
	_pa_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pa_label.visible = false
	_pa_bg.add_child(_pa_label)
