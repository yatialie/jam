extends Control

## 布局工具的屏幕空间画布：只负责把绘制转交给 LayoutTool。

var tool: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if tool != null and tool.has_method("draw_editor_canvas"):
		tool.draw_editor_canvas(self)
