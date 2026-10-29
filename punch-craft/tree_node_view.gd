class_name TreeNodeView
extends Control
## One node in an upgrade/skill web. Its shape says what it is:
## the root is a large medallion, a Sigil is a round power medallion with a
## turning rune ring, a one-level node is an octagon, and the rest are
## rounded squares with level pips. Colors tell the state: lit in the branch
## color when owned (brighter and gold-rimmed when maxed), a green pulse when
## you can buy it (a pulsing bone-white rim), dim when you can't, purple with a
## lock while a Dead League contender's seal still blocks it.
## Feedback: grows on hover, bursts with sparks when bought, shakes red when
## you can't afford it, and springs into view when it's first revealed.
## Click to select, double-click to buy.

signal selected(id: String)
## Double-clicked: buy it.
signal activated(id: String)
signal hovered(id: String, on: bool)

## Square nodes; the other shapes have their own sizes (see SIZES).
const BOX_SIZE := Vector2(52, 52)
const SIZES := {"root": 78.0, "sigil": 68.0, "keystone": 58.0, "minor": 52.0}

var id := ""
var icon := ""
var title := ""
var level := 0
var max_level := 1
## "maxed", "owned", "available" (or "hidden", in which case it isn't shown).
var state := "available"
var affordable := false
## The contender whose seal blocks this node ("" when open): purple, locked.
var sealed_by := ""
var is_selected := false
## The web's accent (gold for coins, the fighter's color for skills).
var accent := UiTheme.GOLD
## The branch color (a Sigil's power), or the accent.
var tint := UiTheme.GOLD
## "root", "sigil", "keystone" or "minor".
var shape := "minor"
## Revealed but not looked at yet: a small pulsing dot.
var fresh := false

var _hover := false
var _time := 0.0
## 0..1 while the purchase burst plays (-1 when idle).
var _burst := -1.0
var _burst_text := ""
var _flash := 0.0
var _shake := 0.0
var _deny := 0.0
var _scale_tween: Tween
var _sparks: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	refresh()


## Size of this node's shape.
func extent() -> float:
	return SIZES[shape]


func setup_shape(new_shape: String) -> void:
	shape = new_shape
	var side := extent()
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_time += delta
	if _burst >= 0.0:
		_burst += delta / 0.8
		if _burst >= 1.0:
			_burst = -1.0
	_flash = maxf(0.0, _flash - delta * 2.5)
	_deny = maxf(0.0, _deny - delta * 2.2)
	_shake = sin(_time * 70.0) * 6.0 * _deny
	# Only nodes that move redraw on their own (refresh() redraws the rest):
	# anything being interacted with or bursting every frame; idle shimmer
	# (pulses, turning runes, the maxed shine) every frame, or every third,
	# staggered, in the browser.
	var busy := _hover or _burst >= 0.0 or _flash > 0.0 or _deny > 0.0
	if busy or _was_busy:
		queue_redraw()
	elif _animated() and (not Settings.use_web_profile() or (Engine.get_process_frames() + get_instance_id()) % 3 == 0):
		queue_redraw()
	_was_busy = busy


var _was_busy := false


## Something on it moves while idle.
func _animated() -> bool:
	var owned := state == "maxed" or state == "owned"
	if owned:
		return shape in ["root", "sigil"] or state == "maxed" or is_selected or fresh
	return affordable or sealed_by != "" or is_selected or fresh


func refresh() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(id)
		if event.double_click:
			activated.emit(id)
		accept_event()


func _set_hover(on: bool) -> void:
	_hover = on
	if on:
		fresh = false
		Sfx.play("tick", -18.0, 1.0 + randf() * 0.1)
	_tween_scale(1.12 if on else 1.0, 0.12)
	hovered.emit(id, on)


func _tween_scale(target: float, time: float, overshoot := false) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	var step := _scale_tween.tween_property(self, "scale", Vector2.ONE * target, time)
	if overshoot:
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bought: a flash, a ring of sparks and a pop. text floats up ("LV 2", "MAX").
func celebrate(text: String) -> void:
	_burst = 0.0
	_flash = 1.0
	_burst_text = text
	_sparks.clear()
	var count := 18 if shape in ["sigil", "root"] or state == "maxed" else 12
	for i in count:
		_sparks.append([randf() * TAU, randf_range(0.6, 1.2), randf_range(1.5, 3.2)])
	scale = Vector2.ONE * 1.4
	_tween_scale(1.12 if _hover else 1.0, 0.45, true)


## Can't buy it: shake and flash red.
func deny() -> void:
	_deny = 1.0


## Just revealed by buying the node before it: grow in from nothing.
func reveal(delay: float) -> void:
	fresh = true
	scale = Vector2.ZERO
	modulate.a = 0.0
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_interval(delay)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_scale_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.25)


func _draw() -> void:
	var side := extent()
	var center := Vector2(side, side) / 2.0 + Vector2(_shake, 0)
	var owned := state == "maxed" or state == "owned"
	var color := tint
	# Face, rim and icon colors for the state.
	var face := Color(0.07, 0.065, 0.085)
	var rim := Color(0.32, 0.3, 0.36)
	var icon_color := Color(0.55, 0.53, 0.6)
	if owned:
		face = color.darkened(0.72)
		rim = color.lightened(0.15) if state == "maxed" else color.darkened(0.1)
		icon_color = color.lightened(0.25)
	elif sealed_by != "":
		face = UiTheme.SIGIL.darkened(0.82)
		rim = UiTheme.SIGIL.darkened(0.1)
		icon_color = UiTheme.SIGIL.lightened(0.15)
	elif affordable:
		face = Color(0.12, 0.13, 0.13)
		rim = UiTheme.READY
		icon_color = UiTheme.TEXT
	if _hover:
		face = face.lightened(0.07)
		icon_color = icon_color.lightened(0.15)
	if _flash > 0.0:
		face = face.lerp(Color.WHITE, _flash * 0.6)
		icon_color = icon_color.lerp(Color.WHITE, _flash)
	if _deny > 0.0:
		rim = rim.lerp(UiTheme.BAD, _deny)
		face = face.lerp(UiTheme.BAD.darkened(0.5), _deny * 0.6)

	# Halo: steady in the branch color when owned, a slow green pulse when
	# you can buy it, a purple throb while it's sealed.
	var halo := Color.TRANSPARENT
	if owned:
		halo = Color(color, 0.4 if state == "maxed" else 0.24)
	elif affordable and sealed_by == "":
		halo = Color(UiTheme.READY, 0.12 + 0.16 * (0.5 + 0.5 * sin(_time * 3.2 + position.x * 0.05)))
	elif sealed_by != "":
		halo = Color(UiTheme.SIGIL, 0.1 + 0.1 * (0.5 + 0.5 * sin(_time * 2.0)))
	if halo.a > 0.0:
		# One soft glow (four stacked circles cost a draw each, per node).
		var reach := side * 0.82
		draw_texture_rect(_halo_texture(), Rect2(center - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), false, Color(halo, halo.a * 0.85))

	# The purchase burst behind the node: two expanding rings.
	if _burst >= 0.0:
		var t := _burst
		for ring in 2:
			var rt := clampf(t * 1.3 - ring * 0.18, 0.0, 1.0)
			if rt > 0.0 and rt < 1.0:
				draw_arc(center, side * (0.5 + rt * 0.9), 0.0, TAU, 40, Color(color.lightened(0.4), (1.0 - rt) * 0.8), 3.0 - ring, true)

	# Drop shadow, then the face in this node's shape.
	_draw_shape(center + Vector2(0, 3), side, Color(0, 0, 0, 0.45), Color.TRANSPARENT, 0.0)
	_draw_shape(center, side, face, rim, 2.5 if owned or affordable or sealed_by != "" else 1.5)
	if shape in ["root", "sigil"]:
		_rune_ring(center, side, rim, owned)
	if state == "maxed":
		_shine(center, side)

	var icon_size := side * (0.46 if shape == "minor" else 0.44)
	var icon_center := center - Vector2(0, 3 if max_level > 1 and shape != "sigil" else 0)
	Icons.draw(self, icon, icon_center, icon_size, icon_color, face)
	_draw_levels(center, side, color)

	# A lock badge while it's sealed.
	if sealed_by != "" and not owned:
		var badge := center + Vector2(side * 0.36, -side * 0.36)
		draw_circle(badge, 9.0, UiTheme.SIGIL.darkened(0.5))
		draw_arc(badge, 9.0, 0.0, TAU, 20, UiTheme.SIGIL.lightened(0.2), 1.5, true)
		draw_rect(Rect2(badge + Vector2(-4, -1), Vector2(8, 6)), UiTheme.SIGIL.lightened(0.4))
		draw_arc(badge + Vector2(0, -1), 3.0, PI, TAU, 8, UiTheme.SIGIL.lightened(0.4), 1.6)
	if fresh:
		var dot := center + Vector2(side * 0.4, -side * 0.4)
		draw_circle(dot, 4.5 + sin(_time * 6.0), UiTheme.GOLD)
		draw_circle(dot, 2.2, Color.WHITE)

	# Selection: a turning dashed ring.
	if is_selected:
		var radius := side * 0.5 * (1.38 if shape == "minor" else 1.18) + 4.0
		for i in 16:
			var a := _time * 0.8 + TAU * i / 16.0
			draw_arc(center, radius, a, a + TAU / 32.0, 4, Color(1, 1, 1, 0.85), 2.0, true)

	# Sparks and the floating text over everything.
	if _burst >= 0.0:
		var t := _burst
		for spark in _sparks:
			var dir := Vector2.from_angle(spark[0])
			var distance: float = side * 0.45 + side * spark[1] * (1.0 - pow(1.0 - t, 3.0))
			var p := center + dir * distance + Vector2(0, t * t * 14.0)
			draw_line(p, p - dir * spark[2] * 3.0 * (1.0 - t), Color(1.0, 0.95, 0.75, 1.0 - t), spark[2], true)
		if _burst_text != "":
			var font := UiTheme.display_font()
			var text_size := font.get_string_size(_burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			var at := center + Vector2(-text_size.x / 2.0, -side * 0.62 - t * 26.0)
			var alpha := clampf((1.0 - t) * 2.0, 0.0, 1.0)
			draw_string_outline(font, at, _burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, alpha))
			draw_string(font, at, _burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(color.lightened(0.5), alpha))


## The halo's soft round glow, shared by every node.
static var _halo: GradientTexture2D


static func _halo_texture() -> GradientTexture2D:
	if _halo == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.55))
		gradient.set_color(1, Color(1, 1, 1, 0.0))
		gradient.add_point(0.6, Color(1, 1, 1, 0.3))
		_halo = GradientTexture2D.new()
		_halo.gradient = gradient
		_halo.fill = GradientTexture2D.FILL_RADIAL
		_halo.fill_from = Vector2(0.5, 0.5)
		_halo.fill_to = Vector2(1.0, 0.5)
		_halo.width = 64
		_halo.height = 64
	return _halo


func _draw_shape(center: Vector2, side: float, fill: Color, border: Color, width: float) -> void:
	var half := side / 2.0
	match shape:
		"root", "sigil":
			draw_circle(center, half, fill)
			if width > 0.0:
				draw_arc(center, half - width / 2.0, 0.0, TAU, 48, border, width, true)
		"keystone":
			var points := PackedVector2Array()
			for i in 8:
				points.append(center + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * half * 1.06)
			draw_colored_polygon(points, fill)
			if width > 0.0:
				points.append(points[0])
				draw_polyline(points, border, width, true)
		_:
			var style := UiTheme.box(fill, border, int(width), 8)
			if width > 0.0:
				style.border_width_bottom = int(width) + 2
			draw_style_box(style, Rect2(center - Vector2(half, half), Vector2(side, side)))


## The medallions' outer ring of rune ticks, turning slowly once owned.
func _rune_ring(center: Vector2, side: float, rim: Color, owned: bool) -> void:
	var radius := side / 2.0 - 6.0
	draw_arc(center, radius, 0.0, TAU, 40, Color(rim, 0.5), 1.0, true)
	var turn := _time * (0.4 if owned else 0.0)
	var marks := 12 if shape == "sigil" else 16
	for i in marks:
		var a := turn + TAU * i / marks
		var dir := Vector2.from_angle(a)
		var length := 4.0 if i % 3 == 0 else 2.0
		draw_line(center + dir * (radius - length), center + dir * radius, Color(rim, 0.8), 1.5, true)
	if shape == "root":
		draw_arc(center, side / 2.0 + 5.0, turn * -0.5, turn * -0.5 + TAU * 0.3, 16, Color(rim, 0.6), 2.0, true)
		draw_arc(center, side / 2.0 + 5.0, turn * -0.5 + PI, turn * -0.5 + PI + TAU * 0.3, 16, Color(rim, 0.6), 2.0, true)


## A bright band sweeping across maxed nodes every few seconds.
func _shine(center: Vector2, side: float) -> void:
	var cycle := fposmod(_time * 0.35 + position.x * 0.003, 1.0)
	if cycle > 0.3:
		return
	var x := lerpf(-side * 0.6, side * 0.6, cycle / 0.3)
	var half := side * 0.4
	var band := PackedVector2Array([
		center + Vector2(x - 4, -half), center + Vector2(x + 6, -half),
		center + Vector2(x - 2, half), center + Vector2(x - 12, half),
	])
	draw_colored_polygon(band, Color(1, 1, 1, 0.16))


## Levels: pips along the bottom of a square, or arcs round a medallion.
func _draw_levels(center: Vector2, side: float, color: Color) -> void:
	if max_level <= 1:
		return
	if shape == "minor" or shape == "keystone":
		var spacing := 7.0
		var start_x := center.x - spacing * (max_level - 1) / 2.0
		for i in max_level:
			var p := Vector2(start_x + i * spacing, center.y + side / 2.0 - 8.0)
			if i < level:
				draw_circle(p, 3.0, color.lightened(0.3))
				draw_circle(p, 1.4, Color(1, 1, 1, 0.8))
			else:
				draw_circle(p, 2.4, Color(0.3, 0.29, 0.34))
		return
	var radius := side / 2.0 + 3.0
	var gap := 0.12
	var span := (PI * 0.8) / max_level
	for i in max_level:
		# Filled left to right along the bottom of the ring.
		var a := PI * 0.9 - (i + 1) * span
		draw_arc(center, radius, a + gap / 2.0, a + span - gap / 2.0, 6, color.lightened(0.3) if i < level else Color(0.3, 0.29, 0.34), 3.0, true)
