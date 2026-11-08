extends Node2D

## 白盒占位关卡背景：只画地面网格、边界、出生点与出口提示。
## 不生成任何碰撞体，墙体/障碍全部由 F4 布局工具摆放。

@export var room_origin := Vector2.ZERO
@export var room_size := Vector2(2400, 1400)
@export var show_room_outline := true
@export var tile := 128.0
@export var title := "LEVEL 01 / COCKPIT"
@export var subtitle := "WHITEBOX / COLLISION PASS"
@export var spawn_marker := Vector2(400, 1000)
@export var show_spawn_marker := true
@export var show_exit_marker := true
@export var show_return_marker := false
@export var exit_marker_y := 700.0
@export var exit_label := "EXIT → LEVEL 02"
@export var return_label := "RETURN → LEVEL 01"

const ACCENT := Color(0.35, 0.85, 0.95)


func _ready() -> void:
	z_index = 0
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var room := Rect2(room_origin, room_size)
	draw_rect(Rect2(room.position - Vector2(400, 400), room_size + Vector2(800, 800)), Color(0.01, 0.014, 0.02))
	draw_rect(room, Color(0.042, 0.056, 0.072))

	var minor := Color(0.3, 0.7, 0.8, 0.09)
	var major := Color(0.3, 0.7, 0.8, 0.2)
	var x := room_origin.x
	while x <= room_origin.x + room_size.x:
		var is_major := int(roundf((x - room_origin.x) / tile)) % 4 == 0
		draw_line(Vector2(x, room_origin.y), Vector2(x, room_origin.y + room_size.y), major if is_major else minor, 1.0)
		x += tile
	var y := room_origin.y
	while y <= room_origin.y + room_size.y:
		var is_major := int(roundf((y - room_origin.y) / tile)) % 4 == 0
		draw_line(Vector2(room_origin.x, y), Vector2(room_origin.x + room_size.x, y), major if is_major else minor, 1.0)
		y += tile

	if show_room_outline:
		draw_rect(room, Color(ACCENT, 0.75), false, 3.0)
	draw_string(font, room_origin + Vector2(48, 160), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.6, 0.95, 1.0, 0.9))
	draw_string(font, room_origin + Vector2(48, 192), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.45, 0.65, 0.7, 0.9))
	draw_string(font, room_origin + Vector2(48, room_size.y - 28), "%d × %d  DESIGN UNITS" % [int(room_size.x), int(room_size.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 0.6, 0.65, 0.8))

	if show_spawn_marker:
		draw_circle(spawn_marker, 18.0, Color(0.3, 1.0, 0.5, 0.12))
		draw_arc(spawn_marker, 18.0, 0.0, TAU, 32, Color(0.3, 1.0, 0.5, 0.8), 2.0, true)
		draw_string(font, spawn_marker + Vector2(26, 6), "SPAWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.3, 1.0, 0.5, 0.8))

	if show_exit_marker:
		var exit_rect := Rect2(Vector2(room_origin.x + room_size.x - 28, exit_marker_y - 140), Vector2(56, 280))
		draw_rect(exit_rect, Color(ACCENT, 0.12))
		draw_rect(exit_rect, Color(ACCENT, 0.75), false, 2.0)
		draw_string(font, Vector2(room_origin.x + room_size.x - 260, exit_marker_y - 160), exit_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.85))

	if show_return_marker:
		var return_rect := Rect2(Vector2(room_origin.x - 28, exit_marker_y - 140), Vector2(56, 280))
		draw_rect(return_rect, Color(ACCENT, 0.12))
		draw_rect(return_rect, Color(ACCENT, 0.75), false, 2.0)
		draw_string(font, Vector2(room_origin.x + 48, exit_marker_y - 160), return_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT, 0.85))
