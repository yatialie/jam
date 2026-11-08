extends Node2D

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var player: CharacterBody2D = $Projection/Player


func _ready() -> void:
	pause_overlay.visible = false
	MissionLog.start_chapter("engineering")
	_connect_targets()
	_connect_exit_door()


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal"):
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


func _connect_targets() -> void:
	for target in $Projection/World/Targets.get_children():
		if target.has_signal("hit_registered"):
			target.hit_registered.connect(_on_target_hit)


func _connect_exit_door() -> void:
	for door in get_tree().get_nodes_in_group("access_door"):
		if String(door.exit_scene_path).is_empty():
			continue
		if door.has_signal("passed_through"):
			door.passed_through.connect(_on_exit_passed)


func _on_target_hit() -> void:
	MissionLog.add_task_progress("eng_targets")


func _on_exit_passed() -> void:
	MissionLog.complete_task("eng_exit")


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
