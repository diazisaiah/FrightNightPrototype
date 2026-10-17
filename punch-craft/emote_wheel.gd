class_name EmoteWheel
extends Control
## The emote wheel: a ring of dances (Emotes.ORDER) around the middle of the
## screen. The player steers it (mouse or stick) and lets go of the emote key
## to dance. Drawn, not built from controls, so it never takes the mouse.

const RADIUS := 170.0
const INNER := 62.0
## How far the pointer has to lean to pick a slice.
const DEAD_ZONE := 36.0

## The highlighted dance, or -1.
var selected := -1
## Where the pointer leans (pixels from the center, up to RADIUS).
var pointer := Vector2.ZERO
var hint := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Leans the pointer and picks the slice under it.
func steer(lean: Vector2) -> void:
	pointer = lean.limit_length(RADIUS)
	if pointer.length() < DEAD_ZONE:
		selected = -1
	else:
		var count := Emotes.ORDER.size()
		var angle := fposmod(atan2(pointer.x, -pointer.y) + PI / count, TAU)
		selected = int(angle / TAU * count) % count
	queue_redraw()


func picked() -> String:
	return Emotes.ORDER[selected] if selected >= 0 else ""


func _draw() -> void:
	var center := size * 0.5
	var count := Emotes.ORDER.size()
	var font := UiTheme.bold_font()
	draw_circle(center, RADIUS + 16.0, Color(0, 0, 0, 0.7))
	for i in count:
		var mid := i * TAU / count
		var from := mid - PI / count + 0.02
		var to := mid + PI / count - 0.02
		var lit := i == selected
		var points := PackedVector2Array()
		for step in 13:
			var a := lerpf(from, to, step / 12.0)
			points.append(center + Vector2(sin(a), -cos(a)) * RADIUS)
		for step in 13:
			var a := lerpf(to, from, step / 12.0)
			points.append(center + Vector2(sin(a), -cos(a)) * INNER)
		draw_colored_polygon(points, Color(UiTheme.GOLD, 0.95) if lit else Color(UiTheme.PANEL_LIGHT, 0.95))
		var label := Emotes.name_of(Emotes.ORDER[i])
		var spot := center + Vector2(sin(mid), -cos(mid)) * (INNER + RADIUS) * 0.5
		var font_size := 15
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, spot + Vector2(-width * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				UiTheme.BG if lit else UiTheme.TEXT)
	draw_circle(center, INNER - 6.0, Color(UiTheme.BG, 0.9))
	if pointer.length() > 4.0:
		draw_line(center, center + pointer.limit_length(INNER - 10.0), UiTheme.GOLD, 3.0)
	var title := "DANCE" if selected < 0 else "LET GO"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, center + Vector2(-title_width * 0.5, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.MUTED)
	if hint != "":
		var hint_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, center + Vector2(-hint_width * 0.5, RADIUS + 44.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiTheme.MUTED)
