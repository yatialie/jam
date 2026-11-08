extends "res://scripts/levels/level_controller.gd"

## 第二关转运仓导演：首次校准到任意两个关节后机械臂失控，玩家必死并回到驾驶舱。
## 第二命再次进入时机械臂暴走；玩家可击毁机械臂，或在控制台输入日历密码 925 将其关停。
## 出口触发区要求机械臂停机且清空剩余敌人，激活后玩家走进即换场。

signal enemy_count_changed(count: int)
signal room_cleared

const ENEMY_SCENES := {
	"grunt": preload("res://scenes/grunt.tscn"),
	"ranged": preload("res://scenes/ranged_monster.tscn"),
}
## 相对机械臂基座的位置，保证机械臂始终位于关卡中央时敌人仍围绕它布防。
## 第二关固定配置：三只初始小兵 + 一只远程水晶水母。
const ENEMY_SPECS := [
	{"type": "grunt", "offset": Vector2(-240, 170), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 60.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "offset": Vector2(370, 240), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 225.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "offset": Vector2(-240, -176), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 225.0, "detect": 280.0, "leash": 340.0},
	{"type": "ranged", "offset": Vector2(300, -180), "kind": 1, "hp": 2, "speed": 90.0, "patrol": 140.0, "detect": 600.0, "leash": 720.0},
]
const CONSOLE_RANGE := 178.0
const CAMERA_BASE_OFFSET := Vector2(0, -28)
const CAMERA_ALIGN_OFFSET := Vector2(-190, -28)
const ALIGN_LIMIT_PAD := 320.0
## 机械臂脚本袭击从举爪到命中的固定提前量（0.5s 举爪 + 0.08s 挥击）。
const SCRIPTED_IMPACT_LEAD := 0.58

enum Phase { INTRO, ALIGN, TRAP, COMBAT, DONE }

## 警报出现到机械臂命中的反应窗口，可在检查器调整。
@export var trap_window := 1.6

@onready var player = $Projection/Player
@onready var arm = $Projection/Arm
@onready var enemies_root: Node2D = $Projection/Enemies
@onready var props = $Projection/Props
@onready var console_point: Marker2D = $Projection/ConsolePoint
@onready var respawn_point: Marker2D = $Projection/RespawnPoint
@onready var exit_trigger = $Projection/World/ExitTrigger
@onready var hud = $HUD
@onready var align_ui = $AlignUI
@onready var keypad_ui = $KeypadUI
@onready var camera_rig = $CameraRig
@onready var alarm: AudioStreamPlayer = $Alarm

var _phase := Phase.INTRO
var _enemies_alive := 0
var _arm_offline := false
var _cleared := false
var _scripted_target := Vector2.ZERO
var _status_timer := 0.0
var _aligned_joints := 0
var _trap_triggered := false
var _trap_impact_done := false
var _arm_memory_pending := false
var _arm_memory_seen := false

var _objective_bg: ColorRect
var _objective_label: Label
var _prompt_bg: ColorRect
var _prompt_label: Label
var _pa_bg: ColorRect
var _pa_label: Label
var _pa_tween: Tween


func _ready() -> void:
	super._ready()
	pause_overlay.visible = false
	player.set_respawn_point(respawn_point.global_position)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)

	arm.hp_changed.connect(_on_arm_hp_changed)
	arm.arm_offline.connect(_on_arm_offline)
	arm.ground_impact.connect(_on_ground_impact)
	arm.scripted_telegraph.connect(_on_arm_telegraph)
	arm.scripted_impact.connect(_on_arm_impact)

	align_ui.set_escape_locked(true)
	align_ui.joint_completed.connect(_on_joint_completed)
	align_ui.closed.connect(_on_alignment_closed)
	keypad_ui.solved.connect(_on_password_solved)
	keypad_ui.closed.connect(_on_keypad_closed)

	_build_overlay()
	MissionLog.start_chapter("transfer")
	MissionLog.set_task_target("tr_kill", ENEMY_SPECS.size())

	if MissionLog.arm_trap_seen:
		# 第二次进入：操作台已被摧毁，查看机械臂状态在上一轮已经完成。
		MissionLog.complete_task("tr_inspect")
		props.destroy_console()
		if not MissionLog.level_02_alien_monologue_seen:
			MissionLog.level_02_alien_monologue_seen = true
			await _play_respawn_entry_monologue()
		_start_combat()
	else:
		await _play_first_entry_monologue()
		_update_status()
		_update_objective("CALIBRATE THE TRANSFER ARM")
		hud.announce("TRANSFER HALL", "CALIBRATE THE TRANSFER ARM", 1.8)
		_say("PA // CARGO TRANSFER ARM AWAITING CALIBRATION. APPROACH THE CONSOLE.", 4.6)


## 第一次进入：看到培养舱里的外星怪物，并回忆起攻击操作。
func _play_first_entry_monologue() -> void:
	if is_instance_valid(player):
		player.set_physics_process(true)
	Monologue.finished.connect(_unlock_after_monologue, CONNECT_ONE_SHOT)
	Monologue.play(StoryMonologues.L2_FIRST_ENTRY, {"speaker": "RIG-7"})
	await Monologue.finished


## 被机械臂击杀后第二次进入：保留「又来了！外星怪物！」名句，接机械臂狂暴与反击线索。
func _play_respawn_entry_monologue() -> void:
	if is_instance_valid(player):
		player.set_physics_process(true)
	Monologue.finished.connect(_unlock_after_monologue, CONNECT_ONE_SHOT)
	Monologue.play(StoryMonologues.L2_RESPAWN_ENTRY, {"speaker": "RIG-7"})
	await Monologue.finished


func _unlock_after_monologue() -> void:
	if is_instance_valid(player):
		player.set_physics_process(true)


func _process(delta: float) -> void:
	super._process(delta)
	if get_tree().paused:
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
				MissionLog.complete_task("tr_inspect")
				_open_alignment()
	elif _phase == Phase.COMBAT and not modal:
		if not arm.is_offline() and not keypad_ui.is_open() and _near_console():
			_show_prompt("F   EMERGENCY OVERRIDE", Color(1.0, 0.72, 0.3))
			if Input.is_action_just_pressed("interact"):
				_open_keypad()


func _open_alignment() -> void:
	if _phase != Phase.INTRO:
		return
	_phase = Phase.ALIGN
	_aligned_joints = 0
	_trap_triggered = false
	_trap_impact_done = false
	arm.set_frozen(true)
	_set_align_camera(true)
	align_ui.open()
	_say("PA // MANUAL CALIBRATION LINK ESTABLISHED.", 3.0)


func _on_joint_completed(_index: int) -> void:
	if _phase != Phase.ALIGN or _trap_triggered:
		return
	_aligned_joints += 1
	if _aligned_joints < 2:
		return
	_begin_trap()


func _begin_trap() -> void:
	_trap_triggered = true
	_phase = Phase.TRAP
	_trap_impact_done = false
	_scripted_target = player.global_position + Vector2(0, -24)

	alarm.play()
	props.play_electrocution(player.global_position + Vector2(0, -90), trap_window + 0.6)
	align_ui.begin_overload(trap_window)
	camera_rig.add_trauma(0.6)
	_update_objective("CONSOLE LOCKED")
	_say("PA // CONSOLE LOCKED. ELECTRICAL SURGE DETECTED. CANNOT DISENGAGE.", 3.0)

	var telegraph := maxf(trap_window - SCRIPTED_IMPACT_LEAD, 0.25)
	arm.play_scripted_sweep(_scripted_target, false, telegraph)


func _on_alignment_closed() -> void:
	if _phase == Phase.TRAP:
		return
	if _phase == Phase.ALIGN:
		_phase = Phase.INTRO
		_aligned_joints = 0
		arm.set_frozen(false)
		_set_align_camera(false)
		_say("PA // CALIBRATION LINK CLOSED. APPROACH THE TERMINAL TO RETRY.", 3.0)


func _on_arm_telegraph(lethal: bool) -> void:
	if _phase == Phase.TRAP:
		camera_rig.add_trauma(0.4 if lethal else 0.25)
		return
	if lethal:
		align_ui.glitch(1.2)
		camera_rig.add_trauma(0.25)
	else:
		align_ui.glitch(0.6)
		camera_rig.add_trauma(0.18)


func _on_arm_impact(lethal: bool) -> void:
	if _phase == Phase.TRAP:
		_resolve_trap_impact()
		return
	camera_rig.add_trauma(1.0 if lethal else 0.6)


func _resolve_trap_impact() -> void:
	if _trap_impact_done:
		return
	_trap_impact_done = true
	camera_rig.add_trauma(1.0)
	props.destroy_console()
	props.spawn_impact_debris(_scripted_target)
	align_ui.shatter()
	_say("PA // FATAL IMPACT. SUIT SIGNAL LOST.", 3.2)

	# 首次进入必定阵亡，并重生回第一关；再次进入时机械臂直接失控。
	MissionLog.arm_trap_seen = true
	player.respawn_delay = 999.0
	player.scripted_kill()
	await get_tree().create_timer(1.25).timeout
	SceneFlow.change_scene("res://scenes/levels/level_01_cockpit.tscn")


func _on_player_died() -> void:
	if _phase == Phase.TRAP:
		return
	if _phase == Phase.COMBAT:
		if align_ui.is_open():
			align_ui.close()
		_set_align_camera(false)
		player.set_weapon_disabled(false)


func _on_player_respawned() -> void:
	player.set_physics_process(true)
	player.set_weapon_disabled(false)
	_update_status()


func _start_combat() -> void:
	if _phase == Phase.COMBAT:
		return
	_phase = Phase.COMBAT
	_arm_offline = false
	_enemies_alive = 0
	_cleared = false
	_set_align_camera(false)
	align_ui.set_escape_locked(false)
	align_ui.set_anytime_exit(true)
	if align_ui.is_open():
		align_ui.close()
	if arm.has_method("set_sign_text"):
		arm.call("set_sign_text", "OVERRIDE\nAT CONSOLE")

	for spec in ENEMY_SPECS:
		_spawn_enemy(spec)

	arm.begin_rampage()
	arm.show_sign(true)
	player.set_weapon_disabled(false)
	_emit_enemy_count()

	_update_objective("DESTROY OR OVERRIDE THE ARM")
	_update_status()
	hud.announce("ARM HOSTILE", "DESTROY OR OVERRIDE THE ARM", 2.2)
	_say("PA // CALIBRATION INTERRUPTED. TRANSFER ARM HOSTILE. DESTROY IT, OR USE THE DAMAGED CONSOLE TO ENTER AN EMERGENCY OVERRIDE CODE.", 5.2)


func _spawn_enemy(spec: Dictionary) -> void:
	# 按 type 选择怪物场景：初始小兵 / 远程水晶水母。
	var enemy_scene: PackedScene = ENEMY_SCENES[String(spec["type"])]
	var enemy := enemy_scene.instantiate()
	enemy.position = arm.position + Vector2(spec["offset"])
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
	MissionLog.add_task_progress("tr_kill")
	_emit_enemy_count()
	_check_gate()


func _on_ground_impact(_world_position: Vector2, strength: float) -> void:
	camera_rig.add_trauma(strength)


func _on_arm_hp_changed(_current: int, _maximum: int) -> void:
	_update_status()


func _on_arm_offline() -> void:
	_arm_offline = true
	player.set_weapon_disabled(false)
	_emit_enemy_count()
	_update_status()
	var remain := "CLEAR REMAINING HOSTILES" if _enemies_alive > 0 else "EXIT IS OPEN"
	_update_objective(remain)
	hud.announce("ARM OFFLINE", remain, 2.0)
	_say("PA // TRANSFER ARM OFFLINE. " + remain + ".", 3.4)
	_check_gate()


func _open_keypad() -> void:
	if keypad_ui.is_open():
		return
	# 战斗中输入密码时暂停世界，避免玩家被机械臂或小怪打断。
	keypad_ui.open(arm, {"pause_world": true})


func _on_password_solved() -> void:
	arm.shutdown_arm()
	_arm_memory_pending = true


## 密码盘关闭后再播独白，避免台词被暂停中的密码界面挡住。
func _on_keypad_closed() -> void:
	if not _arm_memory_pending or _arm_memory_seen:
		return
	_arm_memory_pending = false
	_arm_memory_seen = true
	Monologue.play(
		StoryMonologues.L2_ARM_MEMORY,
		{
			"speaker": "RIG-7",
			"block_player": false,
			"auto_advance": true,
			"auto_delay": 2.8,
		}
	)


func _check_gate() -> void:
	if _cleared:
		return
	if not _arm_offline:
		return
	if _enemies_alive > 0:
		return
	_cleared = true
	_phase = Phase.DONE
	if exit_trigger.has_method("set_active"):
		exit_trigger.call("set_active", true)
	room_cleared.emit()
	_update_objective("PROCEED TO THE EXIT")
	hud.announce("EXIT UNLOCKED", "PROCEED TO LEVEL 03", 2.4)
	_say("PA // EXIT UNLOCKED. PROCEED TO LEVEL 03.", 4.0)


func _emit_enemy_count() -> void:
	enemy_count_changed.emit(_enemies_alive)


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


func _set_align_camera(enabled: bool) -> void:
	if camera_rig == null:
		return
	camera_rig.framing_offset = CAMERA_ALIGN_OFFSET if enabled else CAMERA_BASE_OFFSET
	if enabled:
		camera_rig.limit_left = int(camera_rig.limit_left - ALIGN_LIMIT_PAD)
	else:
		_sync_camera_limits()


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


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Overlay"
	layer.layer = 6
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_objective_bg = ColorRect.new()
	_objective_bg.anchor_left = 0.5
	_objective_bg.anchor_right = 0.5
	_objective_bg.offset_left = -350.0
	_objective_bg.offset_right = 350.0
	_objective_bg.offset_top = 112.0
	_objective_bg.offset_bottom = 158.0
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
	_objective_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_objective_label.offset_left = 14.0
	_objective_label.offset_top = 4.0
	_objective_label.offset_right = -14.0
	_objective_label.offset_bottom = -4.0
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_bg.add_child(_objective_label)

	_prompt_bg = ColorRect.new()
	_prompt_bg.anchor_left = 0.5
	_prompt_bg.anchor_right = 0.5
	_prompt_bg.anchor_top = 1.0
	_prompt_bg.anchor_bottom = 1.0
	_prompt_bg.offset_left = -300.0
	_prompt_bg.offset_right = 300.0
	_prompt_bg.offset_top = -298.0
	_prompt_bg.offset_bottom = -252.0
	_prompt_bg.color = Color(0.02, 0.04, 0.06, 0.82)
	_prompt_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_bg.visible = false
	layer.add_child(_prompt_bg)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt_label.offset_left = 0.0
	_prompt_label.offset_top = 4.0
	_prompt_label.offset_right = 0.0
	_prompt_label.offset_bottom = -4.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.visible = false
	_prompt_bg.add_child(_prompt_label)

	_pa_bg = ColorRect.new()
	_pa_bg.anchor_left = 0.5
	_pa_bg.anchor_right = 0.5
	_pa_bg.anchor_top = 1.0
	_pa_bg.anchor_bottom = 1.0
	_pa_bg.offset_left = -500.0
	_pa_bg.offset_right = 500.0
	_pa_bg.offset_top = -236.0
	_pa_bg.offset_bottom = -182.0
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
	_pa_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pa_label.offset_left = 16.0
	_pa_label.offset_top = 4.0
	_pa_label.offset_right = -16.0
	_pa_label.offset_bottom = -4.0
	_pa_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pa_label.add_theme_font_size_override("font_size", 18)
	_pa_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.42))
	_pa_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pa_label.visible = false
	_pa_bg.add_child(_pa_label)
