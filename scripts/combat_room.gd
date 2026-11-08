extends Node2D

signal enemy_count_changed(count: int)
signal room_cleared

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const SPAWNS := [
	{"pos": Vector2(860, 700), "kind": 0, "hp": 4, "speed": 140.0, "patrol": 150.0, "detect": 300.0, "leash": 380.0},
	{"pos": Vector2(1250, 600), "kind": 0, "hp": 4, "speed": 140.0, "patrol": 150.0, "detect": 300.0, "leash": 380.0},
	{"pos": Vector2(1750, 1150), "kind": 0, "hp": 4, "speed": 140.0, "patrol": 140.0, "detect": 300.0, "leash": 360.0},
	{"pos": Vector2(1520, 800), "kind": 1, "hp": 3, "speed": 100.0, "patrol": 160.0, "detect": 320.0, "leash": 400.0},
	{"pos": Vector2(980, 1300), "kind": 1, "hp": 3, "speed": 100.0, "patrol": 150.0, "detect": 300.0, "leash": 380.0},
	{"pos": Vector2(2000, 950), "kind": 1, "hp": 3, "speed": 100.0, "patrol": 160.0, "detect": 320.0, "leash": 400.0},
]

@onready var player: CharacterBody2D = $Projection/Player
@onready var enemies_root: Node2D = $Projection/Enemies
@onready var respawn_point: Marker2D = $Projection/RespawnPoint
@onready var pause_overlay: Control = $PauseOverlay/Panel

var _alive := 0
var _cleared := false


func _ready() -> void:
	pause_overlay.visible = false
	player.set_respawn_point(respawn_point.global_position)

	for spec in SPAWNS:
		_spawn_enemy(spec)

	enemy_count_changed.emit(_alive)

	MissionLog.start_chapter("combat")
	MissionLog.set_task_target("combat_hostiles", _alive)

	var exit_door := $Projection/World/ExitDoor
	if exit_door.has_signal("passed_through"):
		exit_door.passed_through.connect(_on_exit_passed)

	var puzzle := $PuzzleUI
	if puzzle.has_signal("solved"):
		puzzle.solved.connect(_on_override_solved)


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal"):
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


func alive_count() -> int:
	return _alive


func _spawn_enemy(spec: Dictionary) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.position = spec["pos"]
	enemy.kind = spec["kind"]
	enemy.max_hp = spec["hp"]
	enemy.move_speed = spec["speed"]
	enemy.behavior_mode = 0  # PATROL：在岗位附近巡逻，不跨区追击
	enemy.patrol_radius = spec["patrol"]
	enemy.detection_radius = spec["detect"]
	enemy.leash_radius = spec["leash"]
	enemy.died.connect(_on_enemy_died)
	enemies_root.add_child(enemy)
	_alive += 1


func _on_enemy_died() -> void:
	_alive = maxi(_alive - 1, 0)
	enemy_count_changed.emit(_alive)
	MissionLog.add_task_progress("combat_hostiles")
	if _alive == 0 and not _cleared:
		_cleared = true
		room_cleared.emit()


func _on_override_solved() -> void:
	MissionLog.complete_task("combat_override")


func _on_exit_passed() -> void:
	MissionLog.complete_task("combat_exit")


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
