extends Control

## Painted page over the scanned calendar paper. All dates and the red
## circle are drawn at runtime so the clue is always crisp and readable.

const GRID_X0 := 0.0166
const GRID_X1 := 0.9980
const GRID_Y0 := 0.2315
const GRID_Y1 := 0.8700
const DAYS := 30

const INK := Color(0.16, 0.18, 0.2)
const INK_SOFT := Color(0.3, 0.32, 0.34)
const RED_INK := Color(0.62, 0.13, 0.1)

var _hand: SystemFont


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand = SystemFont.new()
	_hand.font_names = PackedStringArray(["Segoe Print", "Bradley Hand", "Comic Sans MS"])
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	var font := ThemeDB.fallback_font
	var gx0 := w * GRID_X0
	var gx1 := w * GRID_X1
	var gy0 := h * GRID_Y0
	var gy1 := h * GRID_Y1
	var cell_w := (gx1 - gx0) / 7.0
	var cell_h := (gy1 - gy0) / 5.0

	draw_string(font, Vector2(0, h * 0.078), "CREW CALENDAR", HORIZONTAL_ALIGNMENT_CENTER, w, 18, INK_SOFT)
	draw_string(font, Vector2(0, h * 0.176), "SEP", HORIZONTAL_ALIGNMENT_CENTER, w, 64, INK)

	var names := ["M", "T", "W", "T", "F", "S", "S"]
	for i in 7:
		draw_string(font, Vector2(gx0 + i * cell_w, gy0 - 8.0), names[i], HORIZONTAL_ALIGNMENT_CENTER, cell_w, 14, INK_SOFT)

	var day := 1
	for row in 5:
		for col in 7:
			if day > DAYS:
				break
			var cell_x := gx0 + col * cell_w
			var cell_y := gy0 + row * cell_h
			draw_string(font, Vector2(cell_x, cell_y + cell_h * 0.62), str(day), HORIZONTAL_ALIGNMENT_CENTER, cell_w, 20, INK)
			if day == 25:
				_draw_circle(Vector2(cell_x + cell_w * 0.5, cell_y + cell_h * 0.44), cell_w * 0.37)
			day += 1

	# Handwritten note in the blank lower margin.
	var note_pos := Vector2(w * 0.30, h * 0.947)
	draw_line(Vector2(w * 0.24, h * 0.952), Vector2(w * 0.285, h * 0.947), RED_INK, 2.0, true)
	draw_string(_hand, note_pos, "9.25", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, RED_INK)
	draw_string(_hand, Vector2(w * 0.30, h * 0.982), "airlock cycle", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, RED_INK)


func _draw_circle(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, 48, RED_INK, 2.2, true)
	draw_arc(center + Vector2(2.0, -1.5), radius * 0.94, 0.15, TAU - 0.32, 48, Color(0.62, 0.13, 0.1, 0.72), 1.3, true)
