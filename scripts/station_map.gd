extends Node2D

## Preview scene for the complete station map.
##
## The uploaded illustration is the entire level: it is used directly as the
## background, and the player is scaled down to match the map's own figure
## scale. Collision and interaction will be layered on top in the next pass.

const TILT := 0.72
const MAP_SIZE := Vector2(10557, 5657)
const SPAWN_IMAGE := Vector2(5100, 1950)
const PLAYER_SCALE := 1.25

@onready var pause_overlay: Control = $PauseOverlay/Panel
@onready var player: CharacterBody2D = $Projection/Player


func _ready() -> void:
	pause_overlay.visible = false
	player.position = image_to_world(SPAWN_IMAGE)
	player.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
	_capture_preview()


func image_to_world(point: Vector2) -> Vector2:
	return Vector2(point.x, point.y / TILT)


func _capture_preview() -> void:
	await get_tree().create_timer(1.2).timeout
	_save_preview("user://station_map_preview.png")

	var camera := $CameraRig
	camera.base_zoom = 0.55
	camera.zoom = Vector2(0.55, 0.55)
	await get_tree().create_timer(0.9).timeout
	_save_preview("user://station_map_preview_wide.png")


func _save_preview(path: String) -> void:
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png(path)
		print("STATION_MAP_PREVIEW_SAVED: ", path)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		var now_paused := not get_tree().paused
		get_tree().paused = now_paused
		pause_overlay.visible = now_paused
