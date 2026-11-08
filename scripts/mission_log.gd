extends Node

## Single source of truth for the mission chain displayed by the task panel.
## Chapters mirror the actual level flow: berth -> engineering -> combat ->
## sector 03 -> sector 04 -> sector 05.

signal chapter_started(chapter_id: String)
signal task_changed(task_id: String)
signal task_completed(task_id: String)
signal chapter_completed(chapter_id: String)

const CHAPTERS: Array = [
	{
		"id": "berth",
		"code": "00",
		"location": "COMMAND BRIDGE / DECK 00",
		"title_cn": "苏醒",
		"title_en": "AWAKENING",
		"tasks": [
			{"id": "berth_move", "cn": "使用WASD完成移动", "en": "MOVE WITH WASD"},
			{"id": "berth_next", "cn": "前往场景二", "en": "PROCEED TO SECTOR 02"},
		],
		# 重生后（第二条命起）使用的任务变体。
		"revisit": {
			"tasks": [
				{"id": "berth_number", "cn": "探索关卡，寻找神秘数字", "en": "EXPLORE & FIND THE MYSTERIOUS NUMBER"},
				{"id": "berth_next", "cn": "前往第二关", "en": "PROCEED TO LEVEL 02"},
			],
		},
	},
	{
		"id": "engineering",
		"code": "01",
		"location": "ENGINEERING BAY / PROTOTYPE",
		"title_cn": "校准",
		"title_en": "CALIBRATION",
		"tasks": [
			{"id": "eng_targets", "cn": "命中训练靶", "en": "HIT TRAINING TARGETS", "target": 6},
			{"id": "eng_exit", "cn": "进入转运仓", "en": "ENTER TRANSFER HALL"},
		],
	},
	{
		"id": "transfer",
		"code": "02",
		"location": "TRANSFER HALL / SECTOR 02",
		"title_cn": "失控",
		"title_en": "OVERRIDE",
		"tasks": [
			{"id": "tr_inspect", "cn": "去操作台查看机械臂状态", "en": "CHECK ARM STATUS AT THE CONSOLE"},
			{"id": "tr_arm", "cn": "停止或摧毁机械臂", "en": "STOP OR DESTROY THE ARM"},
			{"id": "tr_kill", "cn": "消灭所有敌人", "en": "ELIMINATE ALL HOSTILES", "target": 4},
		],
	},
	{
		"id": "waste",
		"code": "03",
		"location": "WASTE PROCESSING / SECTOR 03",
		"title_cn": "抛弃",
		"title_en": "DISPOSAL",
		"tasks": [
			{"id": "waste_button", "cn": "击毁抛弃口按钮", "en": "DESTROY THE DISPOSAL BUTTON"},
			{"id": "waste_survive", "cn": "抵抗减压吸力", "en": "RESIST THE DECOMPRESSION"},
			{"id": "waste_exit", "cn": "前往第四关", "en": "PROCEED TO LEVEL 04"},
		],
	},
	{
		"id": "combat",
		"code": "07",
		"location": "COMBAT DECK / SECTOR 07",
		"title_cn": "清剿",
		"title_en": "PURGE",
		"tasks": [
			{"id": "combat_hostiles", "cn": "清除敌对单位", "en": "NEUTRALIZE HOSTILES", "target": 6},
			{"id": "combat_override", "cn": "破解出口权限", "en": "SOLVE ACCESS OVERRIDE"},
			{"id": "combat_exit", "cn": "前往撤离区", "en": "PROCEED TO SECTOR 03"},
		],
	},
	{
		"id": "sector03",
		"code": "03",
		"location": "EVACUATION BAY / SECTOR 03",
		"title_cn": "撤离协议",
		"title_en": "EVAC PROTOCOL",
		"tasks": [
			{"id": "s03_nodes", "cn": "摧毁数据节点", "en": "DESTROY DATA NODES", "target": 3},
			{"id": "s03_exit", "cn": "通过撤离舱门", "en": "REACH THE EXIT"},
		],
	},
	{
		"id": "sector04",
		"code": "04",
		"location": "CARGO BAY / SECTOR 04",
		"title_cn": "深层节点",
		"title_en": "DEEP NODES",
		"tasks": [
			{"id": "s04_nodes", "cn": "摧毁数据节点", "en": "DESTROY DATA NODES", "target": 4},
			{"id": "s04_exit", "cn": "前往信号源", "en": "PROCEED TO SECTOR 05"},
		],
	},
	{
		"id": "sector05",
		"code": "05",
		"location": "REACTOR DECK / SECTOR 05",
		"title_cn": "最后信号",
		"title_en": "LAST SIGNAL",
		"tasks": [
			{"id": "s05_nodes", "cn": "摧毁数据节点", "en": "DESTROY DATA NODES", "target": 4},
			{"id": "s05_extract", "cn": "抵达撤离信标", "en": "REACH EXTRACTION BEACON"},
		],
	},
]

var _chapter_id := ""
var _variant := ""
var _chapter_data: Dictionary = {}
var _states: Dictionary = {}

## 第二关首次校准电击剧情是否已经发生（本次运行内有效）。
## 首次进入需要校准并必定被机械臂击杀；再次进入时机械臂直接处于失控状态。
var arm_trap_seen := false

## 首次被机械臂击杀、回到舰桥重生后的懊悔+疑惑独白是否已经播放。
var arm_respawn_monologue_seen := false

## 第二关非第一条命进入时的“又来了！外星怪物！”独白是否已经播放。
var level_02_alien_monologue_seen := false

## 第一关的脏脏小咪是否已被拾取（跨场景保留，重生后不再刷新）。
var mimi_collected := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## variant 用于同一章节的不同任务变体（例如关卡一重生后的任务）。
func start_chapter(chapter_id: String, variant := "") -> void:
	var chapter := get_chapter(chapter_id)
	if chapter.is_empty():
		push_warning("MissionLog: unknown chapter '%s'" % chapter_id)
		return
	if _chapter_id == chapter_id and _variant == variant:
		return

	_chapter_id = chapter_id
	_variant = variant
	_chapter_data = _resolve_chapter(chapter, variant)
	_states.clear()
	for spec in _chapter_data["tasks"]:
		var target := maxi(int(spec.get("target", 1)), 1)
		_states[String(spec["id"])] = {"done": false, "count": 0, "target": target}
	chapter_started.emit(chapter_id)


func _resolve_chapter(chapter: Dictionary, variant: String) -> Dictionary:
	if variant.is_empty() or not chapter.has(variant):
		return chapter
	var resolved := chapter.duplicate()
	resolved.merge(chapter[variant], true)
	return resolved


func get_chapter(chapter_id := "") -> Dictionary:
	var wanted := chapter_id if not chapter_id.is_empty() else _chapter_id
	for chapter in CHAPTERS:
		if String(chapter["id"]) == wanted:
			return chapter
	return {}


func current_chapter() -> Dictionary:
	if not _chapter_data.is_empty():
		return _chapter_data
	return get_chapter(_chapter_id)


func current_chapter_id() -> String:
	return _chapter_id


func has_task(task_id: String) -> bool:
	return _states.has(task_id)


func archive_index() -> int:
	for i in CHAPTERS.size():
		if String(CHAPTERS[i]["id"]) == _chapter_id:
			return i + 1
	return 0


func archive_size() -> int:
	return CHAPTERS.size()


func task_state(task_id: String) -> Dictionary:
	if _states.has(task_id):
		return _states[task_id]
	return {"done": false, "count": 0, "target": 1}


func is_done(task_id: String) -> bool:
	return bool(task_state(task_id)["done"])


func complete_task(task_id: String) -> void:
	if not _states.has(task_id):
		return
	var state: Dictionary = _states[task_id]
	if bool(state["done"]):
		return

	state["done"] = true
	state["count"] = state["target"]
	task_changed.emit(task_id)
	task_completed.emit(task_id)
	_check_chapter_complete()


func set_task_progress(task_id: String, count: int) -> void:
	if not _states.has(task_id):
		return
	var state: Dictionary = _states[task_id]
	if bool(state["done"]):
		return

	var target := int(state["target"])
	state["count"] = clampi(count, 0, target)
	if int(state["count"]) >= target:
		complete_task(task_id)
		return
	task_changed.emit(task_id)


func add_task_progress(task_id: String, amount := 1) -> void:
	if not _states.has(task_id):
		return
	set_task_progress(task_id, int(task_state(task_id)["count"]) + amount)


func set_task_target(task_id: String, target: int) -> void:
	if not _states.has(task_id):
		return
	_states[task_id]["target"] = maxi(target, 1)
	task_changed.emit(task_id)


func progress() -> Vector2i:
	var done := 0
	var total := 0
	for task_id in _states:
		total += 1
		if bool(_states[task_id]["done"]):
			done += 1
	return Vector2i(done, total)


func _check_chapter_complete() -> void:
	for task_id in _states:
		if not bool(_states[task_id]["done"]):
			return
	chapter_completed.emit(_chapter_id)
