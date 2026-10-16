class_name IconView
extends Control
## A rounded tile with one of the Icons drawn in it.

var icon := "":
	set(value):
		icon = value
		queue_redraw()
var color := UiTheme.GOLD:
	set(value):
		color = value
		queue_redraw()
var tile_color := UiTheme.PANEL_LIGHT:
	set(value):
		tile_color = value
		queue_redraw()
var border_color := UiTheme.BORDER:
	set(value):
		border_color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(UiTheme.box(tile_color, border_color, 2, 14), rect)
	Icons.draw(self, icon, size / 2.0, minf(size.x, size.y) * 0.55, color, tile_color)
