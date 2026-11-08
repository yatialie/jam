extends Area2D

## 关卡换场触发区：玩家走进矩形区域即传送，不再需要开门交互。
## 触发区位置 / 尺寸 / 旋转由 F4 布局工具编辑，数据保存在关卡布局 JSON 的 exits 段。

signal passed_through

@export_enum("entrance", "exit") var exit_role := "exit"
@export var exit_scene_path := ""
@export var trigger_size := Vector2(200.0, 280.0)
## 出口可先锁定，等关卡通关条件满足后再激活。
@export var start_active := true

var _active := true
var _transitioning := false
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("level_exit")
	collision_layer = 0
	collision_mask = 4
	monitoring = true
	monitorable = false
	_active = start_active
	_build_shape()
	body_entered.connect(_on_body_entered)


func _build_shape() -> void:
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = trigger_size
	_shape.shape = rect
	add_child(_shape)


## F4 与布局数据在运行时更新触发区（center 为 World 坐标下的矩形中心）。
func apply_trigger(center: Vector2, size: Vector2, rotation_deg: float) -> void:
	position = center
	rotation_degrees = rotation_deg
	trigger_size = size
	if _shape != null and _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = size


func set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	if _active:
		_check_overlap()


func is_active() -> bool:
	return _active


## 激活瞬间玩家可能已经站在触发区里，此时 body_entered 不会再触发，需要补一次检测。
func _check_overlap() -> void:
	if _transitioning:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)
			return


func _on_body_entered(body: Node2D) -> void:
	if not _active or _transitioning or exit_scene_path.is_empty():
		return
	if not body.is_in_group("player"):
		return
	_transitioning = true
	passed_through.emit()
	SceneFlow.change_scene(exit_scene_path)
