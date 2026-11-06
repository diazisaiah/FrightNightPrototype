class_name FightSkin
extends Control
## The new fight HUD's top row (2026-11-06): a leather HP strap on the left (the
## fighter's name in their color, HP as numbers, the damage trail, ten-HP
## ticks, level and a slim XP bar) and the bout card in the middle (the
## division, and the count toward the Grave Champion). It draws from the
## HUD's own bars, so it needs no feeding; the HUD fades the old nodes out.

const STRAP := Vector2(20, 14)
const STRAP_SIZE := Vector2(304, 72)
const CARD_WIDTH := 300.0

var hud: Hud
var _time := 0.0
## What was drawn last (2026-11-06): it redraws only when that changes or the
## low-HP pulse runs, instead of every frame.
var _drawn: Array = []


func _init(owner_hud: Hud) -> void:
	hud = owner_hud
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	var state := _state()
	var hp_max := maxf(hud._knuckle_bar.max_value, 1.0)
	if state != _drawn or hud._knuckle_bar.value / hp_max < 0.25:
		_drawn = state
		queue_redraw()


## Everything the strap and the bout card show.
func _state() -> Array:
	return [
		size, GameState.fighter_color(), GameState.fighter_name(),
		hud._knuckle_bar.value, hud._knuckle_bar.max_value,
		hud._knuckle_ghost.value if hud._knuckle_ghost else -1.0,
		hud._level_label.visible, hud._level_label.text, hud._xp_bar.value, hud._xp_bar.max_value,
		hud._boss_bar.visible, hud._wave_label.text, hud._night_bar.visible, hud._night_bar.value, hud._night_bar.max_value,
	]


func _draw() -> void:
	_strap()
	_bout_card()


func _strap() -> void:
	var tint := GameState.fighter_color()
	var hp_max := maxf(hud._knuckle_bar.max_value, 1.0)
	var hp := hud._knuckle_bar.value
	var show_level: bool = hud._level_label.visible
	var rect := Rect2(STRAP, Vector2(STRAP_SIZE.x, STRAP_SIZE.y if show_level else 54.0))
	draw_style_box(StitchPanel.leather(10.0, 0.0), rect)
	StitchPanel.dashed_rect(self, rect.grow(-4.0), 6.0, Color(0.92, 0.84, 0.68, 0.5))
	var font := UiTheme.display_font()
	var bold := UiTheme.bold_font()
	_text(font, rect.position + Vector2(14, 25), GameState.fighter_name().to_upper(), 19, tint.lightened(0.05))
	var numbers := "%d / %d" % [ceili(hp), roundi(hp_max)]
	var width := bold.get_string_size(numbers, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_text(bold, rect.position + Vector2(rect.size.x - 14 - width, 24), numbers, 15, Color(0.95, 0.92, 0.88))
	# The bar: a trail of pale where you just lost it, red where you have it.
	var bar := Rect2(rect.position + Vector2(14, 32), Vector2(rect.size.x - 28, 15))
	draw_rect(bar.grow(2.0), Color(0.03, 0.02, 0.015, 0.95))
	var ghost := clampf(hud._knuckle_ghost.value / hp_max, 0.0, 1.0) if hud._knuckle_ghost else hp / hp_max
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ghost, bar.size.y)), Color(1.0, 0.86, 0.78, 0.7))
	var ratio := clampf(hp / hp_max, 0.0, 1.0)
	var low := 0.75 + 0.25 * sin(_time * 9.0) if ratio < 0.25 else 1.0
	var fill_color := Color(0.78, 0.12, 0.1) * Color(low, low, low, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), fill_color)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, 3.0)), fill_color.lightened(0.4))
	var steps := int(hp_max / 10.0)
	for i in range(1, steps):
		var x := bar.position.x + bar.size.x * (i * 10.0) / hp_max
		draw_line(Vector2(x, bar.position.y + 2), Vector2(x, bar.end.y - 1), Color(0, 0, 0, 0.4), 1.0)
	if show_level:
		_text(bold, rect.position + Vector2(14, 66), hud._level_label.text, 13, Color(0.82, 0.78, 0.74))
		var xp := Rect2(rect.position + Vector2(62, 58), Vector2(rect.size.x - 76, 5))
		draw_rect(xp, Color(0.04, 0.03, 0.02, 0.9))
		var xp_ratio := clampf(hud._xp_bar.value / maxf(hud._xp_bar.max_value, 1.0), 0.0, 1.0)
		draw_rect(Rect2(xp.position, Vector2(xp.size.x * xp_ratio, xp.size.y)), tint.darkened(0.15))


func _bout_card() -> void:
	if hud._boss_bar.visible:
		return
	var title: String = hud._wave_label.text
	if title == "":
		return
	var counting: bool = hud._night_bar.visible
	var rect := Rect2(Vector2((size.x - CARD_WIDTH) / 2.0, 14), Vector2(CARD_WIDTH, 66 if counting else 42))
	draw_style_box(StitchPanel.leather(10.0, 0.0), rect)
	StitchPanel.dashed_rect(self, rect.grow(-4.0), 6.0, Color(0.92, 0.84, 0.68, 0.5))
	var font := UiTheme.display_font()
	var tint := GameState.fighter_color()
	if counting:
		_centered(font, rect, 24.0, title, 14, Color(0.78, 0.74, 0.7))
		var count := "%d / %d" % [roundi(hud._night_bar.value), roundi(hud._night_bar.max_value)]
		_centered(font, rect, 55.0, count, 30, Color(1.0, 0.94, 0.86))
		var ratio := clampf(hud._night_bar.value / maxf(hud._night_bar.max_value, 1.0), 0.0, 1.0)
		var track := Rect2(rect.position + Vector2(18, 59), Vector2(rect.size.x - 36, 3))
		draw_rect(track, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), tint.darkened(0.1))
	else:
		_centered(font, rect, 28.0, title, 20, Color(1.0, 0.94, 0.86))


func _centered(font: Font, rect: Rect2, baseline: float, text: String, font_size: int, tint: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(font, Vector2(rect.position.x + (rect.size.x - width) / 2.0, rect.position.y + baseline), text, font_size, tint)


func _text(font: Font, at: Vector2, text: String, font_size: int, tint: Color) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
