extends Node2D

signal passed_through

const DOOR_WIDTH := 32.0
const DOOR_HEIGHT := 280.0
const OPEN_DISTANCE := 200.0
const DOORWAY_RADIUS := 170.0
const AUTO_CLOSE_DELAY := 3.0

@export var exit_scene_path := "res://scenes/combat_room.tscn"
@export var locked_hint := "LOCKED - USE ACCESS PANEL"
@export var start_locked := true
@export_enum("entrance", "exit") var door_role := "exit"
## 换场触发区在门本地坐标下的偏移与尺寸（F4 可调）
@export var exit_area_offset := Vector2(150.0, -140.0)
@export var exit_area_size := Vector2(200.0, 280.0)

var _player: CharacterBody2D
var _collider: StaticBody2D
var _prompt: Label
var _exit_area: Area2D
var _opened := false
var _locked := true
var _close_timer := AUTO_CLOSE_DELAY
var _transitioning := false


func _ready() -> void:
	add_to_group("access_door")
	add_to_group("level_door")
	_locked = start_locked
	_player = get_tree().get_first_node_in_group("player")
	_build_collider()
	_build_exit_area()
	_build_prompt()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	var doorway_center := to_global(Vector2(0, -DOOR_HEIGHT / 2.0))
	var near := _player.global_position.distance_to(doorway_center) < OPEN_DISTANCE

	if _opened:
		_prompt.visible = false
		if _player.global_position.distance_to(doorway_center) > DOORWAY_RADIUS:
			_close_timer = maxf(_close_timer - delta, 0.0)
			if _close_timer <= 0.0:
				_close()
		else:
			_close_timer = AUTO_CLOSE_DELAY
		return

	_prompt.visible = near
	_prompt.text = locked_hint if _locked else "F  OPEN DOOR"
	_prompt.add_theme_color_override("font_color", Color(1, 0.45, 0.35) if _locked else Color(1, 0.85, 0.35))

	if near and not _locked and Input.is_action_just_pressed("interact"):
		_open()


func is_locked() -> bool:
	return _locked


func unlock() -> void:
	_locked = false


func _open() -> void:
	_opened = true
	_close_timer = AUTO_CLOSE_DELAY
	_prompt.visible = false
	_disable_collision()
	_exit_area.set_deferred("monitoring", true)


func _close() -> void:
	_opened = false
	_prompt.visible = false
	_exit_area.set_deferred("monitoring", false)
	_enable_collision()


func _disable_collision() -> void:
	_collider.collision_layer = 0
	for child in _collider.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)


func _enable_collision() -> void:
	_collider.collision_layer = 1
	for child in _collider.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", false)


func _build_collider() -> void:
	_collider = StaticBody2D.new()
	_collider.position = Vector2(0, -DOOR_HEIGHT / 2.0)
	_collider.collision_layer = 1
	_collider.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	_collider.add_child(collider)
	add_child(_collider)


func _build_exit_area() -> void:
	_exit_area = Area2D.new()
	_exit_area.position = exit_area_offset
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 4
	_exit_area.monitoring = false
	_exit_area.monitorable = false

	var shape := RectangleShape2D.new()
	shape.size = exit_area_size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	_exit_area.add_child(collider)
	add_child(_exit_area)

	_exit_area.body_entered.connect(_on_exit_body_entered)


## 供 F4 与布局数据在运行时更新换场触发区。
func apply_exit_area(offset: Vector2, size: Vector2) -> void:
	exit_area_offset = offset
	exit_area_size = size
	if _exit_area == null:
		return
	_exit_area.position = offset
	for child in _exit_area.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			(child.shape as RectangleShape2D).size = size


func _on_exit_body_entered(body: Node2D) -> void:
	if _transitioning or not _opened or exit_scene_path.is_empty():
		return
	if not body.is_in_group("player"):
		return
	_transitioning = true
	passed_through.emit()
	SceneFlow.change_scene(exit_scene_path)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = Label.new()
	_prompt.size = Vector2(460, 40)
	_prompt.position = Vector2(730, 940)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(1, 0.85, 0.35, 1))
	_prompt.visible = false
	layer.add_child(_prompt)
