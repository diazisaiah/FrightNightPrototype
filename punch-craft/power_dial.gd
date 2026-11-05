class_name PowerDial
extends Control
## One power on the new HUD (2026-11-06): a round stitched dial with the
## power's icon. Timed powers (Fire, Frost, Storm, Blood, Doom, Quake) grey out
## when they go off, a clock-style sweep counting the cooldown down. Gale and
## Iron fill from the bottom by charges over the most you can hold, and grey
## out at zero.

const SIZE := 52.0

var color := Color.WHITE
var icon := "star"
## 1 = ready, 0 = just used. For charge powers: have / max.
var is_lit := true
## 0-1 of the cooldown still to go (timed powers).
var cooldown := 0.0
## [have, max] for charge powers, empty for timed ones.
var charges: Array = []
## Seconds left while it recharges ("3s"), drawn over the sweep.
var label := ""

var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var r := SIZE / 2.0 - 2.0
	var lit := is_lit
	var tint := color if lit else Color(0.5, 0.49, 0.54)
	if lit:
		var beat := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(center, r + 4.0 + 2.0 * beat, Color(color, 0.14 + 0.1 * beat))
	draw_circle(center, r, Color(0.1, 0.06, 0.045, 0.94))
	# Charges fill the dial from the bottom.
	if not charges.is_empty() and int(charges[1]) > 0:
		var level := clampf(float(charges[0]) / float(charges[1]), 0.0, 1.0)
		if level > 0.0:
			var y := center.y + r - 2.0 * r * level
			var disc := PackedVector2Array()
			for i in 40:
				disc.append(center + Vector2.from_angle(TAU * i / 40.0) * (r - 2.0))
			var below := PackedVector2Array([Vector2(0, y), Vector2(size.x, y), Vector2(size.x, size.y), Vector2(0, size.y)])
			for piece in Geometry2D.intersect_polygons(disc, below):
				draw_colored_polygon(piece, Color(color, 0.5))
	Icons.draw(self, icon, center, SIZE * 0.5, tint, Color(0.1, 0.06, 0.045))
	# The clock sweep: what's left of the cooldown, dark over the icon.
	if cooldown > 0.0:
		var sweep := PackedVector2Array([center])
		var steps := maxi(int(48.0 * cooldown), 2)
		for i in steps + 1:
			sweep.append(center + Vector2.from_angle(-PI / 2.0 + TAU * cooldown * i / steps) * (r - 1.0))
		draw_colored_polygon(sweep, Color(0, 0, 0, 0.62))
	var bold := UiTheme.bold_font()
	if label != "" and cooldown > 0.0:
		var width := bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(bold, center + Vector2(-width / 2.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.9))
		draw_string(bold, center + Vector2(-width / 2.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.9, 0.95))
	if not charges.is_empty():
		var count := "%d/%d" % [charges[0], charges[1]]
		var cw := bold.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var badge := Rect2(Vector2((size.x - cw - 8.0) / 2.0, size.y - 11.0), Vector2(cw + 8.0, 16.0))
		draw_style_box(UiTheme.box(Color(0.06, 0.04, 0.03, 0.92), Color(color, 0.7) if lit else Color(0.3, 0.3, 0.32), 1, 7), badge)
		draw_string(bold, badge.position + Vector2(4.0, 12.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.93, 0.9) if lit else Color(0.6, 0.58, 0.62))
	StitchPanel.dashed_circle(self, center, r - 3.0, Color(0.92, 0.84, 0.68, 0.55 if lit else 0.3), 1.0, 3.5, 3.0)
	draw_arc(center, r, 0.0, TAU, 40, Color(color, 0.9) if lit else Color(0.22, 0.2, 0.22), 2.0, true)
