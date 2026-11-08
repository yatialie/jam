extends Node2D

const EXTRACT_RADIUS := 110.0

@onready var player: CharacterBody2D = $Projection/Player
@onready var extraction_point: Marker2D = $Projection/World/ExtractionPoint
@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var banner: Label = $HUD/Banner
@onready var banner_sub: Label = $HUD/BannerSub

var _total := 0
var _destroyed := 0
var _objectives_done := false
var _complete := false
var _banner_tween: Tween


func _ready() -> void:
	pause_overlay.visible = false
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0

	MissionLog.start_chapter("sector05")

	var objectives := get_tree().get_nodes_in_group("objectives")
	_total = objectives.size()
	MissionLog.set_task_target("s05_nodes", _total)
	for objective in objectives:
		objective.destroyed.connect(_on_objective_destroyed)


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal"):
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
	if _complete or not _objectives_done:
		return
	if player.global_position.distance_to(extraction_point.global_position) <= EXTRACT_RADIUS:
		_complete = true
		MissionLog.complete_task("s05_extract")
		_show_complete_banner()


func _on_objective_destroyed() -> void:
	_destroyed += 1
	MissionLog.add_task_progress("s05_nodes")
	if _destroyed < _total or _objectives_done:
		return

	_objectives_done = true
	_show_unlock_banner()


func _show_unlock_banner() -> void:
	_kill_banner_tween()
	banner.text = "EXTRACTION ONLINE"
	banner_sub.text = "REACH THE BEACON"
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.5)
	_banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.7)
	_banner_tween.set_parallel(false)
	_banner_tween.tween_interval(2.0)
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_property(banner_sub, "modulate:a", 0.0, 0.5)


func _show_complete_banner() -> void:
	_kill_banner_tween()
	banner.text = "SECTOR 05 CLEARED"
	banner_sub.text = "MISSION COMPLETE"
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.7)
	_banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.9)


func _kill_banner_tween() -> void:
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
