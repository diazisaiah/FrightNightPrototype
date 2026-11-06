class_name StarRating
extends Control
## Five stars for a fighter's star stat (GameState.CLASSES stars, 1-5): the
## filled ones in the fighter's color, the empty ones stitched like a seam.
## pop() lets them land one by one.

const STARS := 5
const SIZE := 26.0
const GAP := 4.0

var count := 3:
	set(value):
		count = clampi(value, 0, STARS)
		queue_redraw()
var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var seam := Color(0.92, 0.84, 0.68, 0.5)
## How many stars have landed so far (pop() runs it from 0 to count).
var shown := float(STARS):
	set(value):
		shown = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(STARS * SIZE + (STARS - 1) * GAP, SIZE)


## The filled stars pop in one after another, after delay seconds.
func pop(delay := 0.0) -> void:
	shown = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "shown", float(count), 0.12 * count + 0.2)


func _draw() -> void:
	var half := SIZE / 2.0
	for k in STARS:
		var center := Vector2(half + k * (SIZE + GAP), size.y / 2.0)
		if k < count:
			var t := clampf(shown - k, 0.0, 1.0)
			if t <= 0.0:
				_empty(center, half)
				continue
			# A little overshoot as it lands.
			var grow := t * (1.0 + 0.25 * sin(t * PI))
			draw_colored_polygon(_points(center, half * 1.25 * grow), Color(color, 0.22 * t))
			var points := _points(center, half * grow)
			draw_colored_polygon(points, color)
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color(0.09, 0.05, 0.02), 2.0, true)
		else:
			_empty(center, half)


func _empty(center: Vector2, radius: float) -> void:
	var points := _points(center, radius)
	draw_colored_polygon(points, Color(0, 0, 0, 0.28))
	var outline := points.duplicate()
	outline.append(points[0])
	StitchPanel.dashed_line(self, outline, seam, 1.2, 3.2, 2.6)


## A five-point star, point up.
static func _points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points
