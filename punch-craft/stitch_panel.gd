class_name StitchPanel
extends PanelContainer
## The new fight HUD's leather piece (2026-11-06): a dark leather plate with a
## thin dashed seam round the inside edge. `fill` (0-1) refills it from the
## left, the way a passive's chip recharges; -1 for none. Also the shared
## stitch drawing (dashed rounded rectangles and circles) the rest of the
## new HUD uses.

var tint := Color(1, 0.4, 0.1)
## 0-1 refill from the left, -1 for none.
var fill := -1.0:
	set(v):
		if not is_equal_approx(v, fill):
			fill = v
			queue_redraw()
var radius := 10.0
var seam := Color(0.92, 0.84, 0.68, 0.5)


## Dyed leather (2026-11-06): see-through, in the fighter's color rather than
## plain brown, with a darker edge of the same dye.
static func leather(corner := 10.0, padding := 8.0, tint_override := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var dye := GameState.fighter_color() if tint_override.a == 0.0 else tint_override
	var body := Color(0.16, 0.1, 0.07).lerp(dye.darkened(0.5), 0.72)
	var style := UiTheme.box(Color(body, 0.62), Color(dye.darkened(0.55), 0.85), 2, int(corner), padding)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	return style


func _init(corner := 10.0) -> void:
	radius = corner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", leather(corner))


func _draw() -> void:
	if fill >= 0.0:
		var width := size.x * clampf(fill, 0.0, 1.0)
		if width > 2.0:
			var style := UiTheme.box(Color(tint, 0.5), Color.TRANSPARENT, 0, int(radius))
			style.corner_radius_top_right = 2
			style.corner_radius_bottom_right = 2
			draw_style_box(style, Rect2(2, 2, width - 4.0, size.y - 4.0))
	StitchPanel.dashed_rect(self, Rect2(Vector2.ZERO, size).grow(-4.0), maxf(radius - 4.0, 2.0), seam)


# --- Stitch drawing ----------------------------------------------------------------

## A dashed rounded rectangle, thin, like a seam.
static func dashed_rect(ci: CanvasItem, rect: Rect2, corner: float, color: Color, width := 1.0, dash := 4.0, gap := 3.5) -> void:
	var r := minf(corner, minf(rect.size.x, rect.size.y) / 2.0)
	var points := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI / 2.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI / 2.0],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for c in corners:
		for i in 7:
			var a: float = c[1] + (PI / 2.0) * i / 6.0
			points.append(c[0] + Vector2(cos(a), sin(a)) * r)
	points.append(points[0])
	dashed_line(ci, points, color, width, dash, gap)


## A dashed circle.
static func dashed_circle(ci: CanvasItem, center: Vector2, radius_px: float, color: Color, width := 1.0, dash := 4.0, gap := 3.5) -> void:
	var points := PackedVector2Array()
	var steps := 48
	for i in steps + 1:
		points.append(center + Vector2.from_angle(TAU * i / steps) * radius_px)
	dashed_line(ci, points, color, width, dash, gap)


static func dashed_line(ci: CanvasItem, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01:
			continue
		var at := 0.0
		while at < length:
			var step := minf(left, length - at)
			if on:
				ci.draw_line(a.lerp(b, at / length), a.lerp(b, (at + step) / length), color, width, true)
			at += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash if on else gap
