class_name TitleWordmark
extends Control
## "FRIGHT NIGHT" in the camp's top-left corner (2026-11-05), subtly alive:
## each letter bobs a pixel or two on a slow wave, the red breathes like a
## candle, and now and then one letter flickers dim. Drawn letter by letter.

const TEXT := "FRIGHT NIGHT"
const BOB := 1.6
const WAVE_SPEED := 1.6
const FLICKER_EVERY := Vector2(3.5, 7.0)

var font_size := 30
var color := Color(0.9, 0.2, 0.18)

var _time := 0.0
var _flicker_at := 4.0
var _flicker_letter := -1
var _flicker_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := UiTheme.display_font()
	var width := font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(width + 8.0, font_size * 1.25)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _flicker_left > 0.0:
		_flicker_left -= delta
		if _flicker_left <= 0.0:
			_flicker_letter = -1
	elif _time >= _flicker_at:
		_flicker_letter = randi() % TEXT.length()
		if TEXT[_flicker_letter] == " ":
			_flicker_letter = -1
		_flicker_left = randf_range(0.12, 0.3)
		_flicker_at = _time + randf_range(FLICKER_EVERY.x, FLICKER_EVERY.y)
	queue_redraw()


func _draw() -> void:
	var font := UiTheme.display_font()
	var breathe := 0.92 + 0.08 * sin(_time * 1.3)
	var x := 2.0
	var base := font_size * 1.0
	for i in TEXT.length():
		var letter := TEXT[i]
		var lift := sin(_time * WAVE_SPEED - i * 0.55) * BOB
		var at := Vector2(x, base + lift)
		var tint := color.lightened(0.1) * Color(breathe, breathe, breathe, 1.0)
		if i == _flicker_letter:
			tint = color.darkened(0.45)
		draw_string_outline(font, at + Vector2(0, 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.6))
		draw_string_outline(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0.02, 0.01, 0.02))
		draw_string(font, at, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
		x += font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
