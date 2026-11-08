extends Node2D

## 第一关可拾取的「脏脏小咪」。视觉使用正式小咪立绘。

const PROMPT_SCRIPT := preload("res://ui/components/interact_prompt.gd")
const USE_DISTANCE := 132.0

@onready var visual: Node2D = $Visual

var _prompt
var _player: Node2D
var _collected := false
var _hinted := false
var _bob_time := 0.0
var _base_scale := Vector2.ONE


func _ready() -> void:
	z_index = 3
	add_to_group("interactable")
	_prompt = PROMPT_SCRIPT.new()
	add_child(_prompt)
	_base_scale = visual.scale
	_bob_time = randf() * TAU


func _process(delta: float) -> void:
	_bob_time += delta * 2.2
	visual.position.y = -5.0 + sin(_bob_time) * 3.0

	if _collected:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var modal := get_tree().get_first_node_in_group("modal") != null
	var near := _player.global_position.distance_to(global_position) < USE_DISTANCE
	_prompt.call("set_prompt_visible", near and not modal)
	if near and not modal and not _hinted:
		_hinted = true
		_prompt.call("flash_hint", "拾取 · 脏脏小咪")
	if near and not modal and Input.is_action_just_pressed("interact"):
		_collect()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	MissionLog.mimi_collected = true
	_prompt.call("set_prompt_visible", false)

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("grant_shield"):
		player.call("grant_shield", 1)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", _base_scale * 1.28, 0.24)
	tween.tween_property(visual, "modulate:a", 0.0, 0.32)
	await tween.finished

	Monologue.play(StoryMonologues.L1_MIMI, {"speaker": "RIG-7"})
	queue_free()


func _draw() -> void:
	var shadow := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		shadow.append(Vector2(cos(angle) * 42.0, sin(angle) * 11.0 + 3.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.2))
