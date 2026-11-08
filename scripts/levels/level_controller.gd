extends Node2D

## 通用关卡控制器：目前只负责暂停与恢复，后续每关的玩法逻辑可以继承或替换。

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var projection: Node2D = $Projection
@onready var world: Node2D = $Projection/World
@onready var camera: Camera2D = $CameraRig


func _ready() -> void:
	pause_overlay.visible = false
	_sync_camera_limits()


func _sync_camera_limits() -> void:
	var origin = world.get("room_origin")
	if not origin is Vector2:
		origin = Vector2.ZERO
	var size = world.get("room_size")
	if size is Vector2:
		var origin_value: Vector2 = origin
		var size_value: Vector2 = size
		apply_room(origin_value, size_value)


func apply_room(origin: Vector2, size: Vector2) -> void:
	if world:
		world.set("room_origin", origin)
		world.set("room_size", size)
		world.queue_redraw()
	if camera and world:
		var p0: Vector2 = world.to_global(origin)
		var p1: Vector2 = world.to_global(origin + size)
		camera.limit_left = int(minf(p0.x, p1.x))
		camera.limit_top = int(minf(p0.y, p1.y))
		camera.limit_right = int(maxf(p0.x, p1.x))
		camera.limit_bottom = int(maxf(p0.y, p1.y))


func _process(_delta: float) -> void:
	if get_tree().get_first_node_in_group("modal") != null:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	var now_paused := not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
