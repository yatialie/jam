extends Node2D

## 从入口流向操作屏的红色导引灯，只做视觉引导，不参与碰撞。

const POINTS := [
	Vector2(430, 1330),
	Vector2(348, 1210),
	Vector2(320, 1100),
	Vector2(410, 1052),
	Vector2(486, 1042),
]

var active := true
var _phase := 0.0


func _process(delta: float) -> void:
	_phase += delta
	if active:
		queue_redraw()


func _draw() -> void:
	if not active:
		return
	for i in 26:
		var t := fmod(_phase * 0.28 + float(i) / 26.0, 1.0)
		var point := _point_on_path(t)
		var pulse := 0.35 + 0.65 * pow(sin(t * PI), 2.0)
		draw_circle(point, 5.0 + pulse * 3.0, Color(1.0, 0.32, 0.22, 0.1 + pulse * 0.55))
		draw_circle(point, 2.0, Color(1.0, 0.75, 0.5, 0.35 + pulse * 0.4))


func _point_on_path(t: float) -> Vector2:
	var total := POINTS.size() - 1
	var scaled := clampf(t, 0.0, 0.9999) * float(total)
	var index := int(scaled)
	var local := scaled - float(index)
	return POINTS[index].lerp(POINTS[index + 1], local)
