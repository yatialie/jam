extends "res://scripts/levels/level_controller.gd"

## 第三关卫生废物处理仓：击毁右上角红色按钮，底部抛弃口开启并吸入敌人。
## 玩家需要在减压吸力中向反方向移动，撑过抛弃周期。

signal enemy_count_changed(count: int)
signal room_cleared

const ENEMY_SCENES := {
	"grunt": preload("res://scenes/grunt.tscn"),
	"ranged": preload("res://scenes/ranged_monster.tscn"),
}
const ENEMY_SPECS := [
	{"type": "grunt", "pos": Vector2(700, 1050), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "pos": Vector2(1650, 1050), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "pos": Vector2(700, 1750), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "pos": Vector2(1650, 1750), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "pos": Vector2(1000, 850), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "grunt", "pos": Vector2(1400, 1950), "kind": 0, "hp": 3, "speed": 120.0, "patrol": 150.0, "detect": 280.0, "leash": 340.0},
	{"type": "ranged", "pos": Vector2(850, 1250), "kind": 1, "hp": 2, "speed": 90.0, "patrol": 140.0, "detect": 600.0, "leash": 720.0},
	{"type": "ranged", "pos": Vector2(1500, 1650), "kind": 1, "hp": 2, "speed": 90.0, "patrol": 140.0, "detect": 600.0, "leash": 720.0},
]
## 玩家步行速度 250；90 的吸力只要立刻反向输入就能抵消，站着不动才会被拖走。
const PLAYER_PULL_SPEED := 90.0
const ENEMY_PULL_SPEED := 320.0
const PLAYER_KILL_DISTANCE := 120.0
const ENEMY_KILL_DISTANCE := 190.0
const MIN_SUCTION_TIME := 6.0
const MAX_SUCTION_TIME := 14.0

enum Phase { INTRO, SUCTION, DONE }

@onready var player = $Projection/Player
@onready var button = $Projection/WasteButton
@onready var chute = $Projection/WasteChute
@onready var enemies_root: Node2D = $Projection/Enemies
@onready var respawn_point: Marker2D = $Projection/RespawnPoint
@onready var exit_trigger = $Projection/World/ExitTrigger
@onready var hud = $HUD

var _phase := Phase.INTRO
var _enemies_alive := 0
var _suction_active := false
var _suction_time := 0.0
var _consumed_ids := {}
static var _entry_monologue_seen := false

var _objective_bg: ColorRect
var _objective_label: Label
var _pa_bg: ColorRect
var _pa_label: Label
var _pa_tween: Tween
var _suction_bg: ColorRect
var _suction_arrow: Label
var _key_caps := {}


func _ready() -> void:
	super._ready()
	pause_overlay.visible = false
	player.set_respawn_point(respawn_point.global_position)
	player.died.connect(_on_player_died)
	player.respawned.connect(_on_player_respawned)

	button.destroyed.connect(_on_button_destroyed)
	exit_trigger.passed_through.connect(_on_exit_passed)

	_build_overlay()
	MissionLog.start_chapter("waste")
	_spawn_enemies()
	# 入场先看清满仓怪物，再恢复敌人行动，避免独白期间被围殴。
	_set_enemies_active(false)
	await _play_entry_monologue()
	_set_enemies_active(true)

	hud.set_hint("DESTROY THE DISPOSAL BUTTON")
	_update_objective("DESTROY THE DISPOSAL BUTTON — UPPER RIGHT")
	hud.announce("WASTE PROCESSING", "DESTROY THE DISPOSAL BUTTON", 2.0)
	_say("PA // WASTE PROCESSING ONLINE. DISPOSAL CYCLE LOCKED. FIND THE MANUAL RELEASE BUTTON — UPPER RIGHT.", 5.0)


func _process(delta: float) -> void:
	super._process(delta)
	if get_tree().paused:
		return
	if _suction_active:
		_update_suction_hint()


func _physics_process(delta: float) -> void:
	if get_tree().paused or not _suction_active:
		return

	_suction_time += delta
	var chute_local := projection.to_local(chute.global_position)
	var player_local := projection.to_local(player.global_position)
	var to_chute := chute_local - player_local
	var distance := to_chute.length()

	if not player.is_dead() and distance > 1.0:
		player.external_pull = (to_chute / distance) * PLAYER_PULL_SPEED
		if distance < PLAYER_KILL_DISTANCE:
			player.scripted_kill()
	else:
		player.external_pull = Vector2.ZERO

	for enemy in enemies_root.get_children():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if not enemy.has_method("kill"):
			continue
		var enemy_local := projection.to_local(enemy.global_position)
		var enemy_to_chute := chute_local - enemy_local
		var enemy_distance := enemy_to_chute.length()
		if enemy_distance > 1.0:
			enemy.external_pull = (enemy_to_chute / enemy_distance) * ENEMY_PULL_SPEED
		if enemy_distance < ENEMY_KILL_DISTANCE:
			var id := enemy.get_instance_id()
			if not _consumed_ids.has(id):
				_consumed_ids[id] = true
				chute.consume()
				if enemy.has_method("kill"):
					enemy.call("kill")

	if (_suction_time >= MIN_SUCTION_TIME and _enemies_alive <= 0) or _suction_time >= MAX_SUCTION_TIME:
		_end_suction()


## 入场独白：看到外星怪物 → 注意到右上角攻击按钮，两句之间自动推进。
func _play_entry_monologue() -> void:
	if _entry_monologue_seen:
		return
	_entry_monologue_seen = true
	Monologue.play(
		StoryMonologues.L3_ENTRY,
		{
			"speaker": "RIG-7",
			"auto_advance": true,
			"auto_delay": 3.2,
		}
	)
	await Monologue.finished


func _set_enemies_active(active: bool) -> void:
	for enemy in enemies_root.get_children():
		if is_instance_valid(enemy):
			enemy.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _spawn_enemies() -> void:
	for spec in ENEMY_SPECS:
		var enemy_scene: PackedScene = ENEMY_SCENES[String(spec["type"])]
		var enemy := enemy_scene.instantiate()
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
	_emit_enemy_count()


func _on_enemy_died() -> void:
	_enemies_alive = maxi(_enemies_alive - 1, 0)
	_emit_enemy_count()


func _on_button_destroyed() -> void:
	if _suction_active or _phase == Phase.DONE:
		return
	_phase = Phase.SUCTION
	_suction_active = true
	_suction_time = 0.0
	_consumed_ids.clear()
	chute.open()
	_suction_bg.visible = true
	MissionLog.complete_task("waste_button")
	# 抽取机启动的肌肉记忆：战斗中不阻塞操作，自动收尾。
	Monologue.play(
		StoryMonologues.L3_EXTRACTOR,
		{
			"speaker": "RIG-7",
			"block_player": false,
			"auto_advance": true,
			"auto_delay": 2.6,
		}
	)
	hud.set_hint("SURVIVE THE DECOMPRESSION")
	_update_objective("SURVIVE THE DECOMPRESSION — MOVE AGAINST THE PULL")
	hud.announce("DECOMPRESSION", "MOVE AGAINST THE PULL", 2.6)
	_say("PA // DISPOSAL CHUTE OPEN. DECOMPRESSION IN PROGRESS. BRACE AGAINST THE PULL.", 4.2)


func _end_suction() -> void:
	if not _suction_active:
		return
	_suction_active = false
	_phase = Phase.DONE
	_suction_bg.visible = false
	player.external_pull = Vector2.ZERO
	for enemy in enemies_root.get_children():
		if is_instance_valid(enemy) and enemy.has_method("kill"):
			enemy.external_pull = Vector2.ZERO
	chute.close()
	MissionLog.complete_task("waste_survive")
	hud.set_hint("PROCEED TO THE EXIT")
	_update_objective("PROCEED TO THE EXIT")
	room_cleared.emit()
	hud.announce("DECOMPRESSION COMPLETE", "PROCEED TO THE EXIT", 2.4)
	_say("PA // DECOMPRESSION COMPLETE. DISPOSAL CYCLE SEALED. EXIT UNLOCKED.", 4.0)
	if exit_trigger.has_method("set_active"):
		exit_trigger.call("set_active", true)


func _on_player_died() -> void:
	if _suction_active:
		player.external_pull = Vector2.ZERO
		hud.announce("SUIT SIGNAL LOST", "THE PULL CONTINUES", 1.6)
		_say("PA // SUIT SIGNAL LOST. EMERGENCY RECOVERY.", 2.2)


func _on_player_respawned() -> void:
	player.set_physics_process(true)
	player.external_pull = Vector2.ZERO


func _on_exit_passed() -> void:
	MissionLog.complete_task("waste_exit")


func _emit_enemy_count() -> void:
	enemy_count_changed.emit(_enemies_alive)


func _update_suction_hint() -> void:
	var chute_local := projection.to_local(chute.global_position)
	var player_local := projection.to_local(player.global_position)
	var to_chute := chute_local - player_local
	if to_chute.length() < 1.0:
		return
	var resist := -to_chute.normalized()
	_set_key_active("W", resist.y < -0.35)
	_set_key_active("S", resist.y > 0.35)
	_set_key_active("A", resist.x < -0.35)
	_set_key_active("D", resist.x > 0.35)
	if _suction_arrow:
		_suction_arrow.rotation = resist.angle() + PI * 0.5


func _set_key_active(key: String, active: bool) -> void:
	var cap = _key_caps.get(key)
	if cap == null:
		return
	cap.modulate = Color(1.0, 0.88, 0.45, 1.0) if active else Color(0.42, 0.48, 0.52, 0.72)


func _update_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = "OBJECTIVE   //   " + text


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
	_objective_bg.offset_left = -370.0
	_objective_bg.offset_right = 370.0
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

	_build_suction_hint(layer)


func _build_suction_hint(layer: CanvasLayer) -> void:
	_suction_bg = ColorRect.new()
	_suction_bg.anchor_left = 0.5
	_suction_bg.anchor_right = 0.5
	_suction_bg.anchor_top = 1.0
	_suction_bg.anchor_bottom = 1.0
	_suction_bg.offset_left = -340.0
	_suction_bg.offset_right = 340.0
	_suction_bg.offset_top = -430.0
	_suction_bg.offset_bottom = -268.0
	_suction_bg.color = Color(0.07, 0.03, 0.025, 0.88)
	_suction_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.visible = false
	layer.add_child(_suction_bg)

	var accent := ColorRect.new()
	accent.position = Vector2.ZERO
	accent.size = Vector2(4, 162)
	accent.color = Color(1.0, 0.42, 0.16, 0.9)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(accent)

	var title := Label.new()
	title.text = "DECOMPRESSION"
	title.position = Vector2(0, 8)
	title.size = Vector2(680, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(title)

	var sub := Label.new()
	sub.text = "MOVE AGAINST THE PULL"
	sub.position = Vector2(0, 38)
	sub.size = Vector2(680, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(sub)

	var keys := HBoxContainer.new()
	keys.position = Vector2(171, 72)
	keys.size = Vector2(262, 54)
	keys.add_theme_constant_override("separation", 10)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(keys)

	for key_text in ["W", "A", "S", "D"]:
		var cap := PanelContainer.new()
		cap.custom_minimum_size = Vector2(58, 54)
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.09, 0.12, 0.96)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.32, 0.5, 0.55, 0.8)
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_bottom_right = 6
		cap.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = key_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.add_child(label)
		keys.add_child(cap)
		_key_caps[key_text] = cap
		cap.modulate = Color(0.42, 0.48, 0.52, 0.72)

	_suction_arrow = Label.new()
	_suction_arrow.text = "▲"
	_suction_arrow.position = Vector2(453, 72)
	_suction_arrow.size = Vector2(56, 54)
	_suction_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_suction_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_suction_arrow.add_theme_font_size_override("font_size", 30)
	_suction_arrow.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25))
	_suction_arrow.pivot_offset = Vector2(28, 27)
	_suction_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(_suction_arrow)

	var hint := Label.new()
	hint.text = "HOLD THE OPPOSITE DIRECTION — DON'T GET PULLED INTO THE CHUTE"
	hint.position = Vector2(0, 132)
	hint.size = Vector2(680, 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.68))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suction_bg.add_child(hint)
