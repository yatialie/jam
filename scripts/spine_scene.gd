extends Node2D

## Main spine controller: bridge lift, wing airlocks and the awake chapter
## hand-off to the right wing.

const BRIDGE_SCENE := "res://scenes/cockpit.tscn"
const ASCEND_POINT := Vector2(1500, 620)
const ASCEND_RANGE := 250.0

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var player: CharacterBody2D = $Projection/Player
@onready var right_door = $Projection/World/RightAirlock

var _prompt: Label


func _ready() -> void:
	pause_overlay.visible = false
	right_door.passed_through.connect(_on_right_passed)
	_build_prompt()


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal") != null:
		_prompt.visible = false
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
		return
	if player == null:
		return

	var near := player.position.distance_to(ASCEND_POINT) < ASCEND_RANGE
	_prompt.visible = near
	_prompt.text = "F   ASCEND TO THE COMMAND BRIDGE"

	if near and Input.is_action_just_pressed("interact"):
		SceneFlow.change_scene(BRIDGE_SCENE)


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.size = Vector2(820, 44)
	_prompt.position = Vector2(550, 906)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1.0))
	_prompt.visible = false
	$HUD.add_child(_prompt)


func _on_right_passed() -> void:
	MissionLog.complete_task("berth_right")


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
