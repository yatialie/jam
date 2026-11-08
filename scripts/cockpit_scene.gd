extends Node2D

## Root controller for the command bridge: awakening, clue/keypad wiring and
## the core well that descends to the main spine.

const SPINE_SCENE := "res://scenes/spine.tscn"
const CORE_WELL := Vector2(1000, 1320)
const WELL_RANGE := 280.0
const SPAWN_FIRST := Vector2(1000, 1180)
const SPAWN_RETURN := Vector2(1000, 1160)

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var clue_label: Label = $HUD/ClueLabel
@onready var player: CharacterBody2D = $Projection/Player

var _prompt: Label
var _deny_timer := 0.0


func _ready() -> void:
	pause_overlay.visible = false
	clue_label.visible = false
	MissionLog.start_chapter("berth")

	if MissionLog.is_done("berth_spine"):
		player.position = SPAWN_RETURN
	else:
		player.position = SPAWN_FIRST

	var calendar := get_tree().get_first_node_in_group("calendar_prop")
	if calendar:
		calendar.connect("clue_read", Callable(self, "_on_clue_read"))

	var keypad := get_tree().get_first_node_in_group("keypad_ui")
	if keypad:
		keypad.connect("solved", Callable(self, "_on_code_solved"))

	var keypad_panel := get_tree().get_first_node_in_group("keypad_prop")
	if keypad_panel and keypad_panel.has_method("set_unlocked"):
		keypad_panel.call("set_unlocked", MissionLog.is_done("berth_code"))

	_build_prompt()


func _process(delta: float) -> void:
	if _deny_timer > 0.0:
		_deny_timer = maxf(_deny_timer - delta, 0.0)

	if get_tree().get_first_node_in_group("modal") != null:
		_prompt.visible = false
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
		return
	if player == null:
		return

	var near := player.position.distance_to(CORE_WELL) < WELL_RANGE
	_prompt.visible = near

	var unlocked := MissionLog.is_done("berth_code")
	if _deny_timer > 0.0:
		_prompt.text = "ACCESS DENIED   //   KEYPAD ON THE STARBOARD WALL"
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.42, 0.28, 1.0))
	elif unlocked:
		_prompt.text = "F   DESCEND TO THE MAIN SPINE"
		_prompt.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1.0))
	else:
		_prompt.text = "CORE WELL LOCKED   //   ENTER ACCESS CODE"
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3, 1.0))

	if near and Input.is_action_just_pressed("interact"):
		if unlocked:
			_descend()
		else:
			_deny_timer = 1.2


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.size = Vector2(820, 44)
	_prompt.position = Vector2(550, 906)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3, 1.0))
	_prompt.visible = false
	$HUD.add_child(_prompt)


func _descend() -> void:
	MissionLog.complete_task("berth_spine")
	SceneFlow.change_scene(SPINE_SCENE)


func _on_clue_read() -> void:
	clue_label.visible = true
	MissionLog.complete_task("berth_calendar")


func _on_code_solved() -> void:
	MissionLog.complete_task("berth_code")
	var keypad_panel := get_tree().get_first_node_in_group("keypad_prop")
	if keypad_panel and keypad_panel.has_method("set_unlocked"):
		keypad_panel.call("set_unlocked", true)


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
