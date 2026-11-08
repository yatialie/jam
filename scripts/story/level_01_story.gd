extends Node

## 第一关剧情总控：读取 F4 布局里的编号触发区并派发剧情事件。
## 3 号为值班日历，9 号为打不开的左舷门。

signal story_event(event_id: String)

const BINDINGS := [
	{"id": "3", "type": "calendar"},
	{"id": "9", "type": "sealed"},
]
const CALENDAR_SCENE := preload("res://scenes/calendar_prop.tscn")
const MIMI_SCENE := preload("res://scenes/mimi_prop.tscn")
const PROMPT_SCRIPT := preload("res://ui/components/interact_prompt.gd")
## 脏脏小咪相对日历交互点的摆放偏移，放在墙前地面上。
const MIMI_OFFSET := Vector2(320.0, 160.0)

var _prompt
var _triggers := {}
var _calendar: Node2D
var _mimi: Node2D
var _inside := {}
var _bound := false
var _last_active := ""
var _move_base := Vector2.ZERO

static var _intro_played := false
static var _calendar_date_seen := false


func _ready() -> void:
	var first_life := not _intro_played
	MissionLog.start_chapter("berth", "" if first_life else "revisit")
	_prompt = PROMPT_SCRIPT.new()
	add_child(_prompt)
	set_process(true)
	_bind_exit_door.call_deferred()

	if MissionLog.arm_trap_seen and not MissionLog.arm_respawn_monologue_seen:
		MissionLog.arm_respawn_monologue_seen = true
		_intro_played = true
		Monologue.finished.connect(_expand_task_panel, CONNECT_ONE_SHOT)
		_play_monologue(StoryMonologues.L1_RESPAWN)
	elif not _intro_played:
		_intro_played = true
		Monologue.finished.connect(_on_intro_monologue_finished, CONNECT_ONE_SHOT)
		# 开局屏幕旁白：不冻结角色，文字读完后自动收尾。
		Monologue.play(
			StoryMonologues.L1_OPENING,
			{
				"speaker": "RIG-7",
				"block_player": false,
				"auto_advance": true,
				"auto_delay": 3.8,
			}
		)
	else:
		_expand_task_panel.call_deferred()


func _on_intro_monologue_finished() -> void:
	_expand_task_panel()


func _expand_task_panel() -> void:
	var panel := get_tree().get_first_node_in_group("task_panel")
	if panel != null and panel.has_method("expand"):
		panel.call("expand")


func _play_monologue(lines: Array) -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p):
		p.set_physics_process(true)
	Monologue.finished.connect(_unlock_player, CONNECT_ONE_SHOT)
	Monologue.play(lines, {"speaker": "RIG-7"})


func _unlock_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and is_instance_valid(p):
		p.set_physics_process(true)


func _process(_delta: float) -> void:
	_update_move_task()
	if not _bound or not _all_alive():
		if _bound:
			_clear()
		_try_bind()
		return

	var editing := LayoutTool.active
	if is_instance_valid(_calendar):
		_calendar.visible = not editing

	if editing or get_tree().paused or get_tree().get_first_node_in_group("modal") != null:
		_apply_state("")
		return

	var active := _active_id()
	_apply_state(active)

	if not active.is_empty() and Input.is_action_just_pressed("interact"):
		_interact(active)


func _try_bind() -> void:
	var found: Array[Dictionary] = []
	for binding in BINDINGS:
		var id := str(binding.get("id", ""))
		var trigger := _find_trigger_node(id)
		if trigger == null:
			return
		var data := _find_item(str(trigger.get_meta("layout_id", "")))
		if data.is_empty():
			return
		found.append({
			"id": id,
			"type": str(binding.get("type", "door")),
			"layout": str(binding.get("layout", "vertical")),
			"trigger": trigger,
			"data": data,
		})

	for entry in found:
		var id: String = entry["id"]
		var trigger: Area2D = entry["trigger"]
		var data: Dictionary = entry["data"]
		var pos: Vector2 = data.get("pos", Vector2.ZERO)
		_triggers[id] = trigger
		_inside[id] = false

		if str(entry["type"]) == "calendar":
			var calendar := CALENDAR_SCENE.instantiate() as Node2D
			calendar.name = "StoryCalendar" + id
			calendar.set("managed", true)
			calendar.position = pos
			calendar.z_index = 3
			trigger.get_parent().add_child(calendar)
			calendar.connect("clue_read", Callable(self, "_on_calendar_read"))
			_calendar = calendar
			if not MissionLog.mimi_collected:
				var mimi := MIMI_SCENE.instantiate() as Node2D
				mimi.name = "StoryMimi"
				mimi.position = pos + MIMI_OFFSET
				mimi.z_index = 3
				trigger.get_parent().add_child(mimi)
				_mimi = mimi

		var enter := _on_body_entered.bind(id)
		var exit := _on_body_exited.bind(id)
		if not trigger.body_entered.is_connected(enter):
			trigger.body_entered.connect(enter)
		if not trigger.body_exited.is_connected(exit):
			trigger.body_exited.connect(exit)

		for body in trigger.get_overlapping_bodies():
			if body.is_in_group("player"):
				_inside[id] = true

	_bound = true


func _clear() -> void:
	if is_instance_valid(_calendar):
		_calendar.queue_free()
	if is_instance_valid(_mimi):
		_mimi.queue_free()
	_triggers.clear()
	_inside.clear()
	_calendar = null
	_mimi = null
	_bound = false
	_last_active = ""


func _all_alive() -> bool:
	if _triggers.size() != BINDINGS.size():
		return false
	for id in _triggers.keys():
		var trigger = _triggers[id]
		if not is_instance_valid(trigger) or not trigger.is_inside_tree() or trigger.is_queued_for_deletion():
			return false
	for binding in BINDINGS:
		if str(binding.get("type", "")) == "calendar" and not is_instance_valid(_calendar):
			return false
	return true


func _active_id() -> String:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var best_id := ""
	var best_dist := 1e20
	for id in _inside.keys():
		if not bool(_inside[id]):
			continue
		var trigger = _triggers.get(id)
		if player and trigger is Node2D:
			var distance := player.global_position.distance_to((trigger as Node2D).global_position)
			if distance < best_dist:
				best_dist = distance
				best_id = str(id)
		elif best_id.is_empty():
			best_id = str(id)
	return best_id


func _apply_state(active_id: String) -> void:
	if active_id != _last_active:
		_prompt.call("clear_hint")
		_last_active = active_id
	_prompt.call("set_prompt_visible", not active_id.is_empty())
	if is_instance_valid(_calendar):
		_calendar.call("set_highlight", active_id == "3")


func _interact(id: String) -> void:
	if id == "3" and is_instance_valid(_calendar):
		_prompt.call("set_prompt_visible", false)
		_calendar.call("open_calendar")
		story_event.emit("trigger_3_calendar")
	elif id == "9":
		# 左舷门：只给交互提示，打不开，触发独白。
		_prompt.call("set_prompt_visible", false)
		_play_monologue(StoryMonologues.L1_LEFT_DOOR)
		story_event.emit("trigger_9_sealed")


## 阅读值班日历后完成「探索关卡，寻找神秘数字」。
func _on_calendar_read() -> void:
	MissionLog.complete_task("berth_number")
	story_event.emit("trigger_3_calendar_read")
	if MissionLog.arm_trap_seen and not _calendar_date_seen:
		_calendar_date_seen = true
		var ui := get_tree().get_first_node_in_group("clue_ui")
		if ui != null and ui.has_signal("closed"):
			ui.closed.connect(_play_calendar_date_monologue, CONNECT_ONE_SHOT)
		else:
			_play_calendar_date_monologue()


func _play_calendar_date_monologue() -> void:
	_play_monologue(StoryMonologues.L1_CALENDAR_DATE)


## 使用 WASD 真正走动一段距离后完成移动教学任务（仅第一条命）。
func _update_move_task() -> void:
	if not MissionLog.has_task("berth_move") or MissionLog.is_done("berth_move"):
		return
	if get_tree().paused or Monologue.is_playing():
		return
	if get_tree().get_first_node_in_group("modal") != null:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if not _wasd_pressed():
		_move_base = p.global_position
		return
	if p.global_position.distance_to(_move_base) >= 24.0:
		MissionLog.complete_task("berth_move")


func _wasd_pressed() -> bool:
	return (
		Input.is_physical_key_pressed(KEY_W)
		or Input.is_physical_key_pressed(KEY_A)
		or Input.is_physical_key_pressed(KEY_S)
		or Input.is_physical_key_pressed(KEY_D)
	)


func _bind_exit_door() -> void:
	for node in get_tree().get_nodes_in_group("level_door"):
		if str(node.get("door_role")) != "exit":
			continue
		if not node.is_connected("passed_through", _on_exit_passed):
			node.connect("passed_through", _on_exit_passed)
		return


func _on_exit_passed() -> void:
	MissionLog.complete_task("berth_next")


func _on_body_entered(body: Node2D, id: String) -> void:
	if body.is_in_group("player"):
		_inside[id] = true


func _on_body_exited(body: Node2D, id: String) -> void:
	if body.is_in_group("player"):
		_inside[id] = false


func _find_trigger_node(id: String) -> Area2D:
	for node in get_tree().get_nodes_in_group("triggers"):
		if node is Area2D and node.is_inside_tree() and not node.is_queued_for_deletion():
			if str(node.get_meta("purpose", "")) == id:
				return node
	return null


func _find_item(layout_id: String) -> Dictionary:
	if layout_id.is_empty():
		return {}
	for item in LayoutStore.items:
		if str(item.get("id", "")) == layout_id:
			return item
	return {}
