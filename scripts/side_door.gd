extends Node2D

## 侧舱门：靠近按 F 开门，门板向上移动的同时淡出；玩家离开后自动关门。
## 节点原点位于门板底边中心（贴地位置）。

const TILT := 0.72
const OPEN_DISTANCE := 230.0
const LEAVE_DISTANCE := 300.0
const AUTO_CLOSE_DELAY := 2.5
const OPEN_TIME := 0.6
const CLOSE_TIME := 0.5
const FADE_TIME := 0.45

@export var door_texture: Texture2D
## 门板在设计单位下的尺寸（已含关卡投影的纵向拉伸）。
@export var door_size := Vector2(240.0, 640.0)
## 关闭交互后，这扇门不会显示 F 提示，也不会被玩家打开。
@export var interactive := true

var _panel: Sprite2D
var _prompt: InteractPrompt
var _tween: Tween
var _opened := false
var _busy := false
var _close_timer := AUTO_CLOSE_DELAY


func _ready() -> void:
	z_index = 2
	_panel = Sprite2D.new()
	_panel.texture = door_texture
	_panel.centered = true
	if door_texture != null:
		_panel.scale = door_size / door_texture.get_size()
	var rest_y := -door_size.y * 0.5
	_panel.position = Vector2(0.0, rest_y)
	add_child(_panel)

	_prompt = InteractPrompt.new()
	add_child(_prompt)


func _process(delta: float) -> void:
	if not interactive:
		_prompt.call("set_prompt_visible", false)
		return

	var player := get_tree().get_first_node_in_group("player") as Node2D
	var distance := _distance_to(player)

	if _busy:
		_prompt.call("set_prompt_visible", false)
		return

	if _opened:
		_prompt.call("set_prompt_visible", false)
		if distance > LEAVE_DISTANCE:
			_close_timer -= delta
			if _close_timer <= 0.0:
				_close()
		else:
			_close_timer = AUTO_CLOSE_DELAY
		return

	if LayoutTool.active or get_tree().paused or get_tree().get_first_node_in_group("modal") != null:
		_prompt.call("set_prompt_visible", false)
		return

	var near := distance < OPEN_DISTANCE
	_prompt.call("set_prompt_visible", near)
	if near and Input.is_action_just_pressed("interact"):
		open()


## 设计单位下的平面距离（抵消 Projection 的纵向压缩）。
func _distance_to(player: Node2D) -> float:
	var parent := get_parent() as Node2D
	if parent == null or player == null:
		return INF
	return parent.to_local(player.global_position).distance_to(position)


func open() -> void:
	_opened = true
	_busy = true
	_prompt.call("set_prompt_visible", false)
	_kill_tween()

	var rest_y := -door_size.y * 0.5
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "position:y", rest_y - door_size.y, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.set_parallel(false)
	_tween.tween_callback(_on_opened)


func _close() -> void:
	_busy = true
	_kill_tween()

	var rest_y := -door_size.y * 0.5
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "position:y", rest_y, CLOSE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, CLOSE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(_on_closed)


func _on_opened() -> void:
	_busy = false


func _on_closed() -> void:
	_opened = false
	_busy = false
	_close_timer = AUTO_CLOSE_DELAY


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
