class_name JamHudFrame
extends Control

## Shared cassette-glass chrome for the HUD panels: beveled frosted body,
## scanlines, moving sheen, corner brackets and an optional progress rail.

const CYAN := Color(0.32, 0.86, 0.94)
const GREEN := Color(0.42, 1.0, 0.78)
const AMBER := Color(0.98, 0.68, 0.3)

@export var accent: Color = CYAN
@export var cut: float = 9.0
@export var header_h: float = 112.0
@export var footer_h: float = 36.0
@export var show_header_band: bool = true
@export var show_brackets: bool = true
@export var show_progress: bool = true
@export var show_scanlines: bool = true
@export var show_sheen: bool = true
@export var texture: Texture2D = null
@export var texture_alpha: float = 0.13

var progress: float = 0.0
var segments: int = 1
var complete: bool = false
var wipe: float = 0.0
var complete_flash: float = 0.0
var danger: float = 0.0

var _phase: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var c := minf(cut, minf(w, h) * 0.25)
	var pts := PackedVector2Array(
		[
			Vector2(c, 0.0),
			Vector2(w - c, 0.0),
			Vector2(w, c),
			Vector2(w, h - c),
			Vector2(w - c, h),
			Vector2(c, h),
			Vector2(0.0, h - c),
			Vector2(0.0, c),
		]
	)

	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(3.0, 5.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))

	var top := Color(0.02, 0.044, 0.055, 0.93)
	var bottom := Color(0.006, 0.016, 0.022, 0.95)
	var colors := PackedColorArray()
	for p in pts:
		colors.append(top.lerp(bottom, clampf(p.y / maxf(h, 1.0), 0.0, 1.0)))
	draw_polygon(pts, colors)

	if show_header_band and header_h > 0.0:
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(c, 0.0),
					Vector2(w - c, 0.0),
					Vector2(w, c),
					Vector2(w, maxf(header_h - 8.0, c)),
					Vector2(c, maxf(header_h - 8.0, c)),
					Vector2(0.0, c),
				]
			),
			PackedColorArray(
				[
					Color(0.16, 0.55, 0.62, 0.05),
					Color(0.16, 0.55, 0.62, 0.05),
					Color(0.16, 0.55, 0.62, 0.02),
					Color(0.16, 0.55, 0.62, 0.0),
					Color(0.16, 0.55, 0.62, 0.0),
					Color(0.16, 0.55, 0.62, 0.02),
				]
			)
		)

	if texture:
		draw_texture_rect(
			texture,
			Rect2(9.0, 9.0, w - 18.0, h - 18.0),
			false,
			Color(0.75, 0.95, 1.0, texture_alpha)
		)

	if show_scanlines:
		var line_y := 2.0
		while line_y < h:
			draw_line(Vector2(2.0, line_y), Vector2(w - 2.0, line_y), Color(0, 0, 0, 0.055), 1.0)
			line_y += 3.0

	if show_sheen:
		var sweep_t := fmod(_phase * 0.085, 1.0)
		var band_y := -70.0 + sweep_t * (h + 140.0)
		draw_polygon(
			PackedVector2Array(
				[
					Vector2(2.0, band_y),
					Vector2(w - 2.0, band_y + 22.0),
					Vector2(w - 2.0, band_y + 66.0),
					Vector2(2.0, band_y + 44.0),
				]
			),
			PackedColorArray(
				[
					Color(1, 1, 1, 0.0),
					Color(1, 1, 1, 0.016),
					Color(1, 1, 1, 0.016),
					Color(1, 1, 1, 0.0),
				]
			)
		)

		draw_polygon(
			PackedVector2Array(
				[
					Vector2(c, 0.0),
					Vector2(w - c, 0.0),
					Vector2(w - c, 46.0),
					Vector2(c, 46.0),
				]
			),
			PackedColorArray(
				[
					Color(1, 1, 1, 0.045),
					Color(1, 1, 1, 0.045),
					Color(1, 1, 1, 0.0),
					Color(1, 1, 1, 0.0),
				]
			)
		)

	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(accent, 0.08), 3.0, true)
	draw_polyline(closed, Color(accent, 0.34), 1.0, true)

	if show_brackets:
		_draw_brackets(w, h, c)

	if show_progress:
		_draw_progress_rail(w)

	if footer_h > 0.0:
		draw_line(
			Vector2(16.0, h - footer_h),
			Vector2(w - 16.0, h - footer_h),
			Color(1, 1, 1, 0.07),
			1.0
		)

	if wipe > 0.001:
		var wipe_y := header_h * (1.0 - wipe)
		draw_line(Vector2(4.0, wipe_y), Vector2(w - 4.0, wipe_y), Color(accent, 0.7 * wipe), 2.0)
		draw_rect(Rect2(4.0, wipe_y, w - 8.0, 14.0), Color(accent, 0.05 * wipe))

	if complete_flash > 0.001:
		draw_rect(Rect2(2.0, 2.0, w - 4.0, header_h - 2.0), Color(GREEN, 0.06 * complete_flash))
		var sweep_y := h * (1.0 - complete_flash)
		draw_line(
			Vector2(4.0, sweep_y),
			Vector2(w - 4.0, sweep_y),
			Color(GREEN, 0.55 * complete_flash),
			2.0
		)

	if danger > 0.001:
		draw_colored_polygon(pts, Color(1.0, 0.25, 0.22, 0.05 * danger))
		draw_polyline(closed, Color(1.0, 0.3, 0.26, 0.65 * danger), 2.0, true)


func _draw_brackets(w: float, h: float, c: float) -> void:
	var inset := 6.0
	var arm := 10.0
	var color := Color(accent, 0.45)
	draw_line(Vector2(inset, c + arm), Vector2(inset, c), color, 1.2)
	draw_line(Vector2(inset, c), Vector2(c + arm, c), color, 1.2)
	draw_line(Vector2(w - inset, c + arm), Vector2(w - inset, c), color, 1.2)
	draw_line(Vector2(w - inset, c), Vector2(w - c - arm, c), color, 1.2)
	draw_line(Vector2(inset, h - c - arm), Vector2(inset, h - c), color, 1.2)
	draw_line(Vector2(inset, h - c), Vector2(c + arm, h - c), color, 1.2)
	draw_line(Vector2(w - inset, h - c - arm), Vector2(w - inset, h - c), color, 1.2)
	draw_line(Vector2(w - inset, h - c), Vector2(w - c - arm, h - c), color, 1.2)


func _draw_progress_rail(w: float) -> void:
	var rail_y := header_h - 4.0
	draw_line(Vector2(16.0, rail_y), Vector2(w - 16.0, rail_y), Color(1, 1, 1, 0.09), 3.0)
	var fill_w := (w - 32.0) * clampf(progress, 0.0, 1.0)
	if fill_w > 0.5:
		var rail_color := GREEN if complete else accent
		draw_line(Vector2(16.0, rail_y), Vector2(16.0 + fill_w, rail_y), Color(rail_color, 0.9), 3.0)
		draw_circle(Vector2(16.0 + fill_w, rail_y), 2.6, Color(rail_color, 0.95))
	if segments > 1:
		for i in range(1, segments):
			var tick_x := 16.0 + (w - 32.0) * float(i) / float(segments)
			draw_line(
				Vector2(tick_x, rail_y - 3.0),
				Vector2(tick_x, rail_y + 3.0),
				Color(0.03, 0.06, 0.07, 0.75),
				1.0
			)
