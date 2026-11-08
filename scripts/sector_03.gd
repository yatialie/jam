extends Node2D

@export var next_sector_label := "PROCEED TO SECTOR 04"
@export var mission_chapter := "sector03"
@export var nodes_task := "s03_nodes"
@export var exit_task := "s03_exit"

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var banner: Label = $HUD/Banner
@onready var banner_sub: Label = $HUD/BannerSub
@onready var exit_door: Node = $Projection/World/ExitDoor

var _total := 0
var _destroyed := 0
var _unlocked := false


func _ready() -> void:
	pause_overlay.visible = false
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	banner.text = "EXIT UNLOCKED"
	banner_sub.text = next_sector_label

	MissionLog.start_chapter(mission_chapter)

	var objectives := get_tree().get_nodes_in_group("objectives")
	_total = objectives.size()
	MissionLog.set_task_target(nodes_task, _total)
	for objective in objectives:
		objective.destroyed.connect(_on_objective_destroyed)

	if exit_door and exit_door.has_signal("passed_through"):
		exit_door.passed_through.connect(_on_exit_passed)


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal"):
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


func _on_objective_destroyed() -> void:
	_destroyed += 1
	MissionLog.add_task_progress(nodes_task)
	if _destroyed < _total or _unlocked:
		return

	_unlocked = true
	if exit_door and exit_door.has_method("unlock"):
		exit_door.call("unlock")
	_show_banner()


func _on_exit_passed() -> void:
	MissionLog.complete_task(exit_task)


func _show_banner() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.6)
	tw.tween_property(banner_sub, "modulate:a", 1.0, 0.8)
	tw.set_parallel(false)
	tw.tween_interval(2.4)
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)
	tw.tween_property(banner_sub, "modulate:a", 0.0, 0.6)


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
