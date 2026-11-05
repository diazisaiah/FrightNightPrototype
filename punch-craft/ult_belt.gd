class_name UltBelt
extends UltGauge
## The new HUD's ultimate (2026-11-06): a leather belt with a thin stitch, eight
## segments filling in the fighter's darker color, and, when it's full, an
## animated aura of its own for each fighter:
##   Mauler    intense embers climbing off the bar
##   Answer    lightning streaks cracking across it
##   Blur      a glow that swells and pulses
##   Stray     two thin neon green lines swirling over it, a sine and a cosine
##   Tony      a gold shine sweeping along it
##   Catalyst  pink glowing runes floating up
## Same interface as UltGauge (the HUD and the touch tap don't know the
## difference).

const SEGS := 8
const AURA_COLORS := {
	"berserker": Color(1.0, 0.5, 0.12), "counter_master": Color(0.45, 0.85, 1.0), "combo_master": Color(0.62, 0.42, 1.0),
	"free_runner": Color(0.25, 1.0, 0.42), "wise_guy": Color(1.0, 0.8, 0.28), "elementalist": Color(1.0, 0.4, 0.72),
}
## Six rune shapes as line segments in a unit box.
const RUNES := [
	[[0.5, 0.0, 0.5, 1.0], [0.5, 0.3, 0.9, 0.0], [0.5, 0.55, 0.9, 0.25]],
	[[0.1, 0.0, 0.1, 1.0], [0.1, 0.0, 0.8, 0.35], [0.8, 0.35, 0.1, 0.7]],
	[[0.0, 0.0, 1.0, 1.0], [1.0, 0.0, 0.0, 1.0], [0.5, 0.0, 0.5, 1.0]],
	[[0.5, 0.0, 0.9, 0.5], [0.9, 0.5, 0.5, 1.0], [0.5, 1.0, 0.1, 0.5], [0.1, 0.5, 0.5, 0.0]],
	[[0.15, 0.0, 0.15, 1.0], [0.85, 0.0, 0.85, 1.0], [0.15, 0.5, 0.85, 0.5]],
	[[0.0, 0.2, 0.5, 0.0], [0.5, 0.0, 1.0, 0.2], [0.5, 0.0, 0.5, 1.0], [0.2, 0.7, 0.8, 0.7]],
]

var _fx: Array = []
var _bolts: Array = []
var _bolt_timer := 0.0


func _init() -> void:
	super._init()
	custom_minimum_size = Vector2(420, 64)


func _process(delta: float) -> void:
	super._process(delta)
	var aura_ready := full and visible
	var kind := GameState.player_class
	if aura_ready:
		var belt := _belt()
		match kind:
			"berserker":
				if randf() < delta * 70.0:
					_fx.append({"pos": Vector2(randf_range(belt.position.x + 6, belt.end.x - 6), belt.position.y + randf_range(8, belt.size.y)),
						"vel": Vector2(randf_range(-26, 26), randf_range(-190, -90)), "life": randf_range(0.55, 1.1), "max": 1.1, "size": randf_range(1.5, 3.6)})
			"elementalist":
				if randf() < delta * 7.0:
					_fx.append({"pos": Vector2(randf_range(belt.position.x + 14, belt.end.x - 14), belt.position.y + 8),
						"vel": Vector2(randf_range(-6, 6), randf_range(-58, -36)), "life": 1.9, "max": 1.9, "size": randf_range(24, 34),
						"rune": randi() % RUNES.size(), "sway": randf() * TAU})
			"counter_master":
				_bolt_timer -= delta
				if _bolt_timer <= 0.0:
					_bolt_timer = randf_range(0.05, 0.12)
					_make_bolts(belt)
	for p in _fx:
		p.life -= delta
		p.pos += p.vel * delta
	_fx = _fx.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	if not aura_ready:
		_bolts.clear()


func _belt() -> Rect2:
	return Rect2(0, 12, size.x, size.y - 14.0)


func _bar() -> Rect2:
	var belt := _belt()
	return Rect2(belt.position.x + 14, belt.position.y + belt.size.y * 0.5, belt.size.x - 28.0, 15.0)


func _accent() -> Color:
	return AURA_COLORS.get(GameState.player_class, color.lightened(0.4))


func _make_bolts(belt: Rect2) -> void:
	_bolts.clear()
	for k in 4:
		var from := Vector2(randf_range(belt.position.x + 20, belt.end.x - 20), belt.position.y - randf_range(0, 6))
		var to := Vector2(from.x + randf_range(-70, 70), belt.end.y + randf_range(-4, 6))
		var points := PackedVector2Array([from])
		var segs := 7
		for i in range(1, segs):
			var t := float(i) / segs
			points.append(from.lerp(to, t) + Vector2(randf_range(-9, 9), randf_range(-3, 3)))
		points.append(to)
		_bolts.append(points)


func _draw() -> void:
	var belt := _belt()
	var bar := _bar()
	var accent := _accent()
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	# Glow behind (the Blur's swelling pulse, the others' rim).
	if full:
		_aura_back(belt, accent, pulse)
	# The leather and its seam.
	draw_style_box(StitchPanel.leather(10.0, 0.0), belt)
	StitchPanel.dashed_rect(self, belt.grow(-4.0), 6.0, Color(0.92, 0.84, 0.68, 0.5))
	# Name, left; percent or the key, right.
	var font := UiTheme.display_font()
	var heading := status if status != "" else title
	var head_color := accent.lightened(0.2) if full or status != "" else Color(0.9, 0.87, 0.82)
	_text(font, Vector2(belt.position.x + 16, belt.position.y + 24), heading, 17, head_color)
	var right_text := ("TAP!" if tap else key) if full else "%d%%" % roundi(_shown)
	var right_width := font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	_text(font, Vector2(belt.end.x - 16 - right_width, belt.position.y + 24), right_text, 17, Color(1.0, 0.86, 0.4) if full else Color(0.78, 0.74, 0.7))
	# The segments.
	draw_rect(bar.grow(2.0), Color(0.04, 0.025, 0.02, 0.95))
	var gap := 3.0
	var width := (bar.size.x - gap * (SEGS - 1)) / SEGS
	var filled := _shown / 100.0 * SEGS
	for i in SEGS:
		var x := bar.position.x + i * (width + gap)
		draw_rect(Rect2(x, bar.position.y, width, bar.size.y), Color(color.darkened(0.7), 0.95))
		var part := clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			var lit := color.lightened(0.12 * _bump) if not full else color.lerp(accent, 0.55 + 0.25 * pulse)
			draw_rect(Rect2(x, bar.position.y, width * part, bar.size.y), lit)
			draw_rect(Rect2(x, bar.position.y, width * part, 3), lit.lightened(0.4))
	if full:
		_aura_front(belt, bar, accent, pulse)


## Behind the leather: a glow in the fighter's color. The Blur's is the show:
## it swells and fades, over and over.
func _aura_back(belt: Rect2, accent: Color, pulse: float) -> void:
	var strength := 0.2 + 0.1 * pulse
	var layers := 5
	if GameState.player_class == "combo_master":
		var swell := 0.5 + 0.5 * sin(_time * 3.2)
		layers = 7
		strength = 0.3 + 0.3 * swell
		for i in layers:
			var grow := 4.0 + i * 5.0 + swell * 10.0
			draw_style_box(UiTheme.box(Color(accent, strength * (1.0 - float(i) / layers) * 0.55), Color.TRANSPARENT, 0, int(12 + grow)), belt.grow(grow))
		return
	if GameState.player_class == "berserker":
		strength = 0.26 + 0.16 * sin(_time * 31.0) * sin(_time * 17.0)
	for i in layers:
		var grow := 3.0 + i * 4.0
		draw_style_box(UiTheme.box(Color(accent, strength * (1.0 - float(i) / layers) * 0.5), Color.TRANSPARENT, 0, int(12 + grow)), belt.grow(grow))


## Over the bar: the fighter's own effect.
func _aura_front(belt: Rect2, bar: Rect2, accent: Color, pulse: float) -> void:
	match GameState.player_class:
		"berserker":
			for p in _fx:
				var t: float = p.life / p.max
				var flick := 0.6 + 0.4 * sin(_time * 40.0 + p.pos.x)
				var tint := Color(1.0, 0.35 + 0.55 * t, 0.08).lerp(Color(1.0, 0.92, 0.5), 1.0 - t)
				draw_rect(Rect2(p.pos - Vector2(p.size, p.size) * 0.5, Vector2(p.size, p.size)), Color(tint, minf(1.0, t * 1.6) * flick))
		"counter_master":
			for bolt in _bolts:
				draw_polyline(bolt, Color(accent, 0.32), 7.0, true)
				draw_polyline(bolt, Color(0.9, 0.98, 1.0, 1.0), 2.0, true)
		"combo_master":
			var swell := 0.5 + 0.5 * sin(_time * 3.2)
			draw_rect(bar, Color(0.85, 0.75, 1.0, 0.12 + 0.2 * swell))
		"free_runner":
			var mid := bar.position.y + bar.size.y * 0.5
			var amp := bar.size.y * 1.15
			for pass_index in 2:
				var points_a := PackedVector2Array()
				var points_b := PackedVector2Array()
				var x := bar.position.x
				while x <= bar.end.x:
					var phase := (x - bar.position.x) * 0.052 + _time * 5.0
					points_a.append(Vector2(x, mid + sin(phase) * amp))
					points_b.append(Vector2(x, mid + cos(phase) * amp))
					x += 3.0
				if pass_index == 0:
					draw_polyline(points_a, Color(accent, 0.28), 5.0, true)
					draw_polyline(points_b, Color(accent, 0.28), 5.0, true)
				else:
					draw_polyline(points_a, Color(0.75, 1.0, 0.82, 0.95), 1.4, true)
					draw_polyline(points_b, Color(0.75, 1.0, 0.82, 0.95), 1.4, true)
		"wise_guy":
			# A diagonal band of shine crossing the belt, then a pause.
			var cycle := fmod(_time, 1.7) / 1.0
			if cycle <= 1.0:
				var x := lerpf(belt.position.x - 60.0, belt.end.x + 60.0, cycle)
				var band := PackedVector2Array([
					Vector2(x - 22, belt.position.y), Vector2(x + 8, belt.position.y),
					Vector2(x - 12, belt.end.y), Vector2(x - 42, belt.end.y)])
				draw_colored_polygon(_clip_x(band, belt), Color(1.0, 0.96, 0.75, 0.55))
				var core := PackedVector2Array([
					Vector2(x - 12, belt.position.y), Vector2(x - 2, belt.position.y),
					Vector2(x - 22, belt.end.y), Vector2(x - 32, belt.end.y)])
				draw_colored_polygon(_clip_x(core, belt), Color(1, 1, 1, 0.5))
			StitchPanel.dashed_rect(self, belt.grow(-4.0), 6.0, Color(accent.lightened(0.3), 0.85), 1.2)
		"elementalist":
			for p in _fx:
				var t: float = p.life / p.max
				var at: Vector2 = p.pos + Vector2(sin(_time * 2.2 + p.sway) * 5.0, 0.0)
				var alpha := minf(1.0, t * 2.2) * minf(1.0, (1.0 - t) * 6.0 + 0.2)
				var s: float = p.size
				for stroke in RUNES[p.rune]:
					var a := at + Vector2((stroke[0] - 0.5) * s * 0.7, (stroke[1] - 0.5) * s)
					var b := at + Vector2((stroke[2] - 0.5) * s * 0.7, (stroke[3] - 0.5) * s)
					draw_line(a, b, Color(accent, 0.38 * alpha), 6.0, true)
					draw_line(a, b, Color(1.0, 0.84, 0.94, alpha), 2.0, true)


## A polygon trimmed to the belt's left and right edges.
func _clip_x(poly: PackedVector2Array, belt: Rect2) -> PackedVector2Array:
	var out := Geometry2D.intersect_polygons(poly, PackedVector2Array([
		belt.position, Vector2(belt.end.x, belt.position.y), belt.end, Vector2(belt.position.x, belt.end.y)]))
	return out[0] if not out.is_empty() else PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
