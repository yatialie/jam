extends Node2D

const TILT := 0.72
const USE_DISTANCE := 170.0

var _player: CharacterBody2D
var _door: Node
var _screen: Polygon2D
var _prompt: Label
var _opened_by_puzzle := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_build_visual()
	_build_collider()
	_build_prompt()


func _process(_delta: float) -> void:
	if _player == null:
		return
	if _door == null:
		_door = get_tree().get_first_node_in_group("access_door")
	var locked := false
	if _door != null and _door.has_method("is_locked"):
		locked = _door.call("is_locked")
	var modal := get_tree().get_first_node_in_group("modal") != null
	var near := _player.global_position.distance_to(global_position) < USE_DISTANCE

	_prompt.visible = near and locked and not modal
	if _screen:
		_screen.color = Color(0.3, 0.9, 1.0) if locked else Color(0.35, 0.95, 0.55)

	if near and locked and not modal and Input.is_action_just_pressed("interact"):
		var puzzle := get_tree().get_first_node_in_group("puzzle_ui")
		if puzzle and puzzle.has_method("open"):
			puzzle.open()


func _build_visual() -> void:
	var height := 240.0 / TILT
	var width := 160.0

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-width / 2.0, 0),
		Vector2(width / 2.0, 0),
		Vector2(width / 2.0, -height),
		Vector2(-width / 2.0, -height),
	])
	body.color = Color(0.16, 0.19, 0.24)
	add_child(body)

	var outline := Line2D.new()
	outline.points = PackedVector2Array([
		Vector2(-width / 2.0, 0),
		Vector2(width / 2.0, 0),
		Vector2(width / 2.0, -height),
		Vector2(-width / 2.0, -height),
		Vector2(-width / 2.0, 0),
	])
	outline.width = 2.0
	outline.default_color = Color(0.05, 0.07, 0.1)
	add_child(outline)

	_screen = Polygon2D.new()
	_screen.polygon = PackedVector2Array([
		Vector2(-width / 2.0 + 18.0, -height + 24.0),
		Vector2(width / 2.0 - 18.0, -height + 24.0),
		Vector2(width / 2.0 - 18.0, -height + 24.0 + 90.0 / TILT),
		Vector2(-width / 2.0 + 18.0, -height + 24.0 + 90.0 / TILT),
	])
	_screen.color = Color(0.3, 0.9, 1.0)
	add_child(_screen)

	var lamp := Polygon2D.new()
	lamp.polygon = PackedVector2Array([
		Vector2(-10, -24),
		Vector2(10, -24),
		Vector2(10, -12),
		Vector2(-10, -12),
	])
	lamp.color = Color(0.95, 0.65, 0.2)
	add_child(lamp)


func _build_collider() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, -20)
	body.collision_layer = 1
	body.collision_mask = 0

	var shape := RectangleShape2D.new()
	shape.size = Vector2(140, 50)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = Label.new()
	_prompt.text = "F  USE ACCESS PANEL"
	_prompt.size = Vector2(440, 40)
	_prompt.position = Vector2(740, 940)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1))
	_prompt.visible = false
	layer.add_child(_prompt)
