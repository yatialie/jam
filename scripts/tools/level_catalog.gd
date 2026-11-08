class_name LevelCatalog
extends RefCounted

## 七个大关卡的登记表。场景建好后填入 path 即可自动出现在切换器里。

const LEVELS := [
	{
		"number": 1,
		"title": "驾驶舱",
		"path": "res://scenes/levels/level_01_cockpit.tscn",
	},
	{
		"number": 2,
		"title": "第二关 · 转运仓",
		"path": "res://scenes/levels/level_02_placeholder.tscn",
	},
	{
		"number": 3,
		"title": "第三关 · 占位",
		"path": "res://scenes/levels/level_03_placeholder.tscn",
	},
	{
		"number": 4,
		"title": "第四关 · 占位",
		"path": "res://scenes/levels/level_04_placeholder.tscn",
	},
	{
		"number": 5,
		"title": "第五关 · 占位",
		"path": "res://scenes/levels/level_05_placeholder.tscn",
	},
	{
		"number": 6,
		"title": "第六关 · 占位",
		"path": "res://scenes/levels/level_06_placeholder.tscn",
	},
	{
		"number": 7,
		"title": "第七关 · 占位",
		"path": "res://scenes/levels/level_07_placeholder.tscn",
	},
]


static func is_available(entry: Dictionary) -> bool:
	var path := str(entry.get("path", ""))
	return not path.is_empty() and ResourceLoader.exists(path)
