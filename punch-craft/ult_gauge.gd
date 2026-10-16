class_name UltGauge
extends Control
## The ultimate meter: a slanted, segmented gauge in the fighter's color with
## a flowing shine, a diamond badge holding the percent, and the ultimate's
## name over it. Full, it turns gold, throbs, throws sparks and the badge
## shows the key to press.

const SEGMENTS := 10
const BADGE_RADIUS := 30.0
const BAR_LEFT := 70.0
const BAR_TOP := 30.0
const BAR_HEIGHT := 20.0
const SKEW := 10.0
const READY_COLOR := Color(1.0, 0.78, 0.25)

## 0-100.
var value := 0.0:
	set(v):
		if v > value + 0.5 and value < 100.0:
			_bump = 1.0
		value = clampf(v, 0.0, 100.0)
var full := false
var title := ""
## Replaces the title while the ultimate is running (e.g. "TEMPORAL BREAK").
var status := ""
var key := "T"
var color := Color(0.55, 0.45, 0.85)

var _time := 0.0
var _shown := 0.0
var _bump := 0.0
var _sparks: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(420, 64)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	_shown = move_toward(_shown, value, delta * 120.0)
	_bump = move_toward(_bump, 0.0, delta * 4.0)
	if full and randf() < delta * 14.0:
		var along := randf_range(BAR_LEFT, size.x - SKEW)
		_sparks.append({"pos": Vector2(along, BAR_TOP + randf() * BAR_HEIGHT), "vel": Vector2(randf_range(-20, 20), randf_range(-70, -30)), "life": 0.6})
	for spark in _sparks:
		spark.life -= delta
		spark.pos += spark.vel * delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	queue_redraw()


func _draw() -> void:
	var tint := READY_COLOR if full else color
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var right := size.x - SKEW
	# Glow behind the whole bar when it's ready.
	if full:
		_slant(Rect2(BAR_LEFT - 6, BAR_TOP - 6, right - BAR_LEFT + 12, BAR_HEIGHT + 12), Color(tint, 0.18 + 0.2 * pulse))
	# Backing.
	_slant(Rect2(BAR_LEFT - 3, BAR_TOP - 3, right - BAR_LEFT + 6, BAR_HEIGHT + 6), Color(0.02, 0.015, 0.03, 0.85))
	# Segments: full ones lit, the current one partly, the rest dark.
	var gap := 3.0
	var width := (right - BAR_LEFT - gap * (SEGMENTS - 1)) / SEGMENTS
	var filled := _shown / 100.0 * SEGMENTS
	for i in SEGMENTS:
		var x := BAR_LEFT + i * (width + gap)
		_slant(Rect2(x, BAR_TOP, width, BAR_HEIGHT), Color(tint.darkened(0.75), 0.9))
		var part := clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			var lit := tint.lightened(0.25 * _bump)
			_slant(Rect2(x, BAR_TOP, width * part, BAR_HEIGHT), lit)
			# A brighter top edge.
			_slant(Rect2(x, BAR_TOP, width * part, 4), lit.lightened(0.45))
	# A shine that flows along the lit part.
	var lit_right := BAR_LEFT + (right - BAR_LEFT) * _shown / 100.0
	if lit_right > BAR_LEFT + 8:
		var shine_x := BAR_LEFT + fmod(_time * 260.0, maxf(lit_right - BAR_LEFT, 1.0) + 80.0) - 40.0
		var shine_left := maxf(shine_x - 18.0, BAR_LEFT)
		var shine_right := minf(shine_x + 18.0, lit_right)
		if shine_right > shine_left:
			_slant(Rect2(shine_left, BAR_TOP, shine_right - shine_left, BAR_HEIGHT), Color(1, 1, 1, 0.22))
	for spark in _sparks:
		draw_circle(spark.pos, 1.8, Color(READY_COLOR.lightened(0.4), spark.life / 0.6))
	# Name over the bar.
	var font := UiTheme.display_font()
	var heading := status if status != "" else (title + ("   READY" if full else ""))
	_text(font, Vector2(BAR_LEFT + 4, BAR_TOP - 8), heading, 20, tint.lightened(0.2) if full or status != "" else Color(0.88, 0.86, 0.94))
	# The badge: percent, or the key once it's full.
	var center := Vector2(BADGE_RADIUS + 2, BAR_TOP + BAR_HEIGHT / 2.0)
	var radius := BADGE_RADIUS * (1.0 + 0.08 * _bump + (0.06 * pulse if full else 0.0))
	var diamond := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if full:
		draw_colored_polygon(_grow(diamond, center, 1.25), Color(tint, 0.25 + 0.25 * pulse))
	draw_colored_polygon(diamond, Color(0.04, 0.03, 0.05, 0.95))
	var inner := _grow(diamond, center, 0.82)
	draw_colored_polygon(inner, Color(tint.darkened(0.6), 0.9))
	diamond.append(diamond[0])
	draw_polyline(diamond, tint, 3.0, true)
	var label := key if full else "%d" % roundi(_shown)
	var size_px := 26 if full else (22 if _shown < 99.5 else 18)
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	_text(font, center + Vector2(-text_width / 2.0, size_px * 0.36), label, size_px, Color.WHITE)
	if not full:
		_text(UiTheme.bold_font(), center + Vector2(text_width / 2.0 - 1, size_px * 0.36), "%", 11, Color(1, 1, 1, 0.7))


func _slant(rect: Rect2, fill: Color) -> void:
	var points := PackedVector2Array([
		Vector2(rect.position.x + SKEW, rect.position.y),
		Vector2(rect.end.x + SKEW, rect.position.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x, rect.end.y),
	])
	draw_colored_polygon(points, fill)


func _grow(points: PackedVector2Array, center: Vector2, scale_by: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p - center) * scale_by)
	return out


func _text(font: Font, at: Vector2, text: String, font_size: int, tint: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(0, 0, 0, 0.9))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
