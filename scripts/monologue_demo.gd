extends Node

## 内心旁白样板：直接在第一关场景上叠加自动循环演示，按 R 可立即重播。
## 正式接入时删掉自动推进逻辑，改由剧情事件调用 Monologue.play()。

const LINES := [
	"……又是这个梦。",
	{"text": "日历停在同一天，反应堆却还在呼吸。像是有人在等我醒来。", "emotion": "question"},
	{"text": "等等——核心井的读数在动。它不该还活着。", "emotion": "exclaim"},
	{"text": "又一次。他们每次都把答案锁在最深的地方。", "emotion": "anger"},
]
const IDLE_BEFORE_ADVANCE := 3.0

@onready var _hint: Label = $HintLayer/Hint

var _run_id := 0


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	_start_demo()

	var fade := create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(_hint, "modulate:a", 0.0, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).physical_keycode == KEY_R:
			_start_demo()


func _start_demo() -> void:
	_run_id += 1
	var run := _run_id
	Monologue.play(LINES, {"speaker": "RIG-7"})
	_watch(run)


func _watch(run: int) -> void:
	var idle := 0.0
	while run == _run_id:
		await get_tree().create_timer(0.2).timeout
		if run != _run_id:
			return
		if not Monologue.is_playing():
			await get_tree().create_timer(1.5).timeout
			if run == _run_id:
				_start_demo()
			return
		if Monologue.is_typing():
			idle = 0.0
			continue
		idle += 0.2
		if idle >= IDLE_BEFORE_ADVANCE:
			idle = 0.0
			Monologue.advance()
