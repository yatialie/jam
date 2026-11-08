extends Control

## 开场过场：从开始界面切入第一关之前的一段黑场档案手记。
## 表现克制：只有黑场、颗粒、一行题记与一条细线，结束后经 SceneFlow 淡入驾驶舱。

const GAME_SCENE := "res://scenes/levels/level_01_cockpit.tscn"

@onready var film: ColorRect = $Film
@onready var content: Control = $Content
@onready var kicker: Label = $Content/Kicker
@onready var quote: Label = $Content/Quote
@onready var rule: ColorRect = $Content/Rule
@onready var curtain: ColorRect = $Curtain

var _film_material: ShaderMaterial
var _content_home: Vector2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_film_material = film.material as ShaderMaterial
	_film_material.set_shader_parameter("intensity", 0.0)
	_content_home = content.position
	_reset_state()
	_play()


func _reset_state() -> void:
	content.position = _content_home + Vector2(0.0, 12.0)
	kicker.modulate.a = 0.0
	quote.modulate.a = 0.0
	rule.modulate.a = 0.0
	rule.scale.x = 0.001
	curtain.color.a = 1.0


func _play() -> void:
	var timeline := create_tween()
	timeline.set_parallel(true)

	timeline.tween_property(curtain, "color:a", 0.0, 0.9).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	timeline.tween_method(_set_film_intensity, 0.0, 1.0, 1.4).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	timeline.tween_property(content, "position:y", _content_home.y, 2.0).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)
	timeline.tween_property(kicker, "modulate:a", 0.4, 0.8).set_delay(0.35)
	timeline.tween_property(quote, "modulate:a", 1.0, 1.2).set_delay(0.6)
	timeline.tween_property(rule, "modulate:a", 1.0, 0.7).set_delay(0.95)
	timeline.tween_property(rule, "scale:x", 1.0, 1.5).set_delay(0.95).set_trans(
		Tween.TRANS_QUINT
	).set_ease(Tween.EASE_OUT)

	timeline.tween_property(kicker, "modulate:a", 0.0, 0.7).set_delay(3.0)
	timeline.tween_property(quote, "modulate:a", 0.0, 0.85).set_delay(3.0).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	timeline.tween_property(rule, "modulate:a", 0.0, 0.7).set_delay(3.0)
	timeline.tween_property(content, "position:y", _content_home.y - 7.0, 1.3).set_delay(
		2.95
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await timeline.finished
	await get_tree().create_timer(0.08).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SceneFlow.change_scene(GAME_SCENE)


func _set_film_intensity(value: float) -> void:
	_film_material.set_shader_parameter("intensity", value)
