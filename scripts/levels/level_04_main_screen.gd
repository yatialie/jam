extends Node2D

## 第四关主控屏幕：角色在场时屏幕始终显示白色描边；
## 进入 F4 布局中「用途标记 = 1」的触发区后出现交互提示，按 F 打开终端面板。
## 描线由抠图贴图驱动，只渲染轮廓，屏幕本体仍显示背景原图，不会产生贴图接缝。

signal interacted

const SCREEN_TEXTURE := preload("res://art/levels/level_04_main_screen.png")
const OUTLINE_SHADER := preload("res://shaders/screen_outline.gdshader")
const UI_FONT := preload("res://ui/fonts/f_ui.tres")
const PANEL_SCRIPT := preload("res://scripts/levels/level_04_screen_panel.gd")
const MAP_TEXTURE := preload("res://art/levels/level_04_placeholder_bg.png")
const MAP_TEXTURE_PATH := "res://art/levels/level_04_placeholder_bg.png"
## 屏幕在背景图里的源像素裁剪范围，用来跟随 F4 中地图的位移与缩放。
const SOURCE_RECT := Rect2(886.0, 135.0, 292.0, 160.0)

@export var screen_size := Vector2(472.5, 451.9)
@export var outline_color := Color(1.0, 1.0, 1.0, 1.0)
@export var trigger_purpose := "1"
@export var prompt_text := "F  查看主控屏幕"

var _sprite: Sprite2D
var _material: ShaderMaterial
var _prompt: Label
var _panel
var _player: CharacterBody2D
var _trigger: Area2D
var _in_trigger := false
var _focus := 0.0
var _flash := 0.0
var _ignore_interact_until := 0
var _after_screen_seen := false


func _ready() -> void:
	add_to_group("interactable")
	_build_visual()
	_build_prompt()
	_build_panel()
	_play_entry_monologue.call_deferred()


## 每次进入第四关都提示玩家注意大屏幕。
func _play_entry_monologue() -> void:
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree():
		return
	if Monologue.is_playing():
		await Monologue.finished
	Monologue.play(StoryMonologues.L4_ENTRY, {"speaker": "RIG-7"})


func _process(delta: float) -> void:
	_sync_to_map()
	_flash = move_toward(_flash, 0.0, delta * 3.5)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	var editing := _layout_editing()
	_sprite.visible = not editing
	var has_player := _player != null and is_instance_valid(_player)
	var target := 1.0 if has_player else 0.0
	_focus = move_toward(_focus, target, delta * 4.0)
	_material.set_shader_parameter("glow", _focus)
	_material.set_shader_parameter("flash", _flash)

	if not _trigger_valid():
		_trigger = null
		_in_trigger = false
		_bind_trigger()

	var blocked := _is_blocked()
	_prompt.visible = _in_trigger and not blocked

	if _in_trigger and not blocked and Time.get_ticks_msec() >= _ignore_interact_until:
		if Input.is_action_just_pressed("interact"):
			_open_panel()


## 描边贴图跟随 F4 布局里的地图条目，地图被移动或缩放后屏幕自动贴合。
func _sync_to_map() -> void:
	var map_item: Dictionary = {}
	for item in LayoutStore.items:
		if str(item.get("type", "")) != "map":
			continue
		if str(item.get("texture", "")) != MAP_TEXTURE_PATH:
			continue
		map_item = item
		break
	if map_item.is_empty():
		return
	var texture_size := MAP_TEXTURE.get_size()
	var map_pos: Vector2 = map_item.get("pos", Vector2.ZERO)
	var map_size: Vector2 = map_item.get("size", texture_size)
	var map_scale := Vector2(map_size.x / texture_size.x, map_size.y / texture_size.y)
	position = map_pos + (SOURCE_RECT.get_center() - texture_size * 0.5) * map_scale
	rotation_degrees = float(map_item.get("rotation", 0.0))
	screen_size = SOURCE_RECT.size * map_scale
	_apply_sprite_size()


func _apply_sprite_size() -> void:
	var texture_size := SCREEN_TEXTURE.get_size()
	_sprite.scale = Vector2(screen_size.x / texture_size.x, screen_size.y / texture_size.y)


func _layout_editing() -> bool:
	var tool := get_node_or_null("/root/LayoutTool")
	return tool != null and bool(tool.get("active"))


func _trigger_valid() -> bool:
	return _trigger != null and is_instance_valid(_trigger) and _trigger.is_inside_tree()


## 交互范围使用 F4 布局里「用途标记 = 1」的触发区，随布局重新生成时自动重绑。
func _bind_trigger() -> void:
	for node in get_tree().get_nodes_in_group("triggers"):
		if not node is Area2D or not node.is_inside_tree() or node.is_queued_for_deletion():
			continue
		if str(node.get_meta("purpose", "")) != trigger_purpose:
			continue
		_trigger = node as Area2D
		_trigger.body_entered.connect(_on_trigger_body_entered)
		_trigger.body_exited.connect(_on_trigger_body_exited)
		if _player != null and is_instance_valid(_player) and _trigger.overlaps_body(_player):
			_in_trigger = true
		return


func _on_trigger_body_entered(body: Node2D) -> void:
	if body == _player:
		_in_trigger = true


func _on_trigger_body_exited(body: Node2D) -> void:
	if body == _player:
		_in_trigger = false


func _is_blocked() -> bool:
	if get_tree().paused:
		return true
	if get_tree().get_first_node_in_group("modal") != null:
		return true
	return _layout_editing()


func _open_panel() -> void:
	if _panel == null or not is_instance_valid(_panel) or _panel.is_open():
		return
	_flash = 1.0
	interacted.emit()
	_panel.open()


func _on_panel_closed() -> void:
	# 关闭面板的 F 与打开交互的 F 是同一帧输入，加冷却避免立即重开。
	_ignore_interact_until = Time.get_ticks_msec() + 250
	if _after_screen_seen:
		return
	_after_screen_seen = true
	Monologue.play(StoryMonologues.L4_AFTER_SCREEN, {"speaker": "RIG-7"})
	await Monologue.finished
	# 头痛独白结束后 1.5 秒，切入硬控的旧日记忆旁白。
	StoryNarration.play(StoryMonologues.L4_ETERNAL_RECURRENCE, {"delay": 1.5})
	await StoryNarration.finished
	# 旁白结束后，主角回到自己的疑问独白。
	Monologue.play(StoryMonologues.L4_ETERNAL_RECURRENCE_REPLY, {"speaker": "RIG-7"})


func _build_visual() -> void:
	var texture_size := SCREEN_TEXTURE.get_size()
	_sprite = Sprite2D.new()
	_sprite.name = "Outline"
	_sprite.texture = SCREEN_TEXTURE
	_sprite.centered = true
	_sprite.scale = Vector2(screen_size.x / texture_size.x, screen_size.y / texture_size.y)
	_sprite.z_index = 2
	_sprite.visible = false
	_material = ShaderMaterial.new()
	_material.shader = OUTLINE_SHADER
	_material.set_shader_parameter("outline_color", outline_color)
	_material.set_shader_parameter("glow", 0.0)
	_material.set_shader_parameter("flash", 0.0)
	_sprite.material = _material
	add_child(_sprite)


func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_prompt = Label.new()
	_prompt.text = prompt_text
	_prompt.size = Vector2(560, 40)
	_prompt.position = Vector2(680, 936)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_override("font", UI_FONT)
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0, 1.0))
	_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_prompt.add_theme_constant_override("shadow_offset_y", 2)
	_prompt.visible = false
	layer.add_child(_prompt)


func _build_panel() -> void:
	_panel = PANEL_SCRIPT.new()
	_panel.name = "TerminalPanel"
	_panel.closed.connect(_on_panel_closed)
	add_child(_panel)
