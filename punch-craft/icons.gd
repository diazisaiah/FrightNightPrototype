class_name Icons
## Flat two-tone vector icons drawn with CanvasItem calls, so the UI needs no
## image files. Call draw() from inside a CanvasItem's _draw().
## size is the icon's full width; bg is used for cut-outs (eyes, cracks...),
## so pass the color the icon sits on.

const NAMES := [
	# Basics.
	"fist", "burst", "star", "heart", "heart_plus", "shield", "broken_shield", "boot",
	"coin", "bolt", "hammer", "drop", "clock", "swoosh", "target", "skull",
	"flame", "chain", "quake", "sigil",
	# Resources.
	"silver", "xp", "skill_point", "stat_point",
	# Fighting gear and training.
	"wraps", "glove", "crossed_gloves", "brass", "tape", "fast_fist", "double_fist",
	"wing_boot", "footprints", "road", "heavy_bag", "dumbbell", "belt", "medal",
	"tooth", "helmet", "chestplate", "anvil", "anchor", "medkit", "bucket",
	# Loot and luck.
	"bag", "chest", "crown", "shovel", "wanted", "dice", "sun", "moon",
	# Powers.
	"snowflake", "shard", "icicle", "nova", "thermometer", "match", "ripple",
	"fork", "storm", "magnet", "battery", "spark", "fang", "blood_burst",
	# The body and the mind.
	"cracked_skull", "eye", "ghost", "horns", "rage", "heartbeat", "wind",
	"headshot", "gut", "slip", "bones",
	# Movement and tempo.
	"feather", "wing", "mountain", "dive", "stairs", "chevrons", "spiral",
	"wave", "flow", "infinity", "hourglass", "stopwatch", "note",
	# Finishing.
	"counter_arrow", "crosshair", "axe", "slash", "muscle",
	# Sigil capstones.
	"pyre", "thunderhead", "shatter", "bloodbath",
]


## Icon art: res://art/icons/<name>.png (a white glyph) replaces the vector icon of that
## name everywhere (prompts in art/icons/ICON_PROMPTS.md). Missing ones keep
## the vector version.
const ART_DIR := "res://art/icons/"
static var _art := {}


static func art(icon: String) -> Texture2D:
	if not _art.has(icon):
		var path := ART_DIR + icon + ".png"
		_art[icon] = load(path) if ResourceLoader.exists(path) else null
	return _art[icon]


static func draw(ci: CanvasItem, icon: String, center: Vector2, size: float, color: Color, bg: Color) -> void:
	var texture := art(icon)
	if texture:
		# Icon art is a plain white glyph: tinted with the node's color, so it
		# takes the branch color and dims when locked, like the vector icons.
		var side := size * 1.1
		ci.draw_texture_rect(texture, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, color)
		return
	var u := size / 2.0
	var dark := color.darkened(0.32)
	var light := color.lightened(0.3)
	match icon:
		"fist":
			_fist(ci, center, u, color, bg)
		"burst":
			ci.draw_colored_polygon(_star(center, u * 0.95, u * 0.45, 8, PI / 8), color)
			ci.draw_colored_polygon(_star(center, u * 0.42, u * 0.2, 8, 0.0), light)
		"star":
			ci.draw_colored_polygon(_star(center, u * 0.95, u * 0.42, 5, -PI / 2), color)
			ci.draw_colored_polygon(_star(center + Vector2(0, 0.05) * u, u * 0.42, u * 0.19, 5, -PI / 2), light)
		"heart":
			_heart(ci, center, u, color)
			ci.draw_circle(center + Vector2(-0.38, -0.3) * u, 0.13 * u, light)
		"heart_plus":
			_heart(ci, center + Vector2(-0.12, -0.08) * u, u * 0.85, color)
			ci.draw_circle(center + Vector2(0.55, 0.55) * u, 0.38 * u, bg)
			ci.draw_line(center + Vector2(0.55, 0.32) * u, center + Vector2(0.55, 0.78) * u, color, 0.14 * u)
			ci.draw_line(center + Vector2(0.32, 0.55) * u, center + Vector2(0.78, 0.55) * u, color, 0.14 * u)
		"shield":
			_shield(ci, center, u, color)
		"broken_shield":
			_shield(ci, center, u, color)
			ci.draw_polyline(_points(center, u, [Vector2(0.08, -0.85), Vector2(-0.16, -0.3), Vector2(0.14, 0.02), Vector2(-0.1, 0.42), Vector2(0.04, 0.9)]), bg, 0.13 * u)
		"boot":
			_boot(ci, center, u, color, bg)
		"coin":
			ci.draw_circle(center, 0.82 * u, color)
			ci.draw_circle(center, 0.62 * u, dark)
			ci.draw_colored_polygon(_star(center, 0.34 * u, 0.15 * u, 4, -PI / 2), color)
		"bolt":
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.2, -0.95), Vector2(-0.55, 0.12), Vector2(-0.05, 0.12), Vector2(-0.22, 0.95), Vector2(0.55, -0.18), Vector2(0.05, -0.18)]), color)
		"hammer":
			ci.draw_rect(Rect2(center + Vector2(-0.12, -0.35) * u, Vector2(0.24, 1.25) * u), dark)
			ci.draw_rect(Rect2(center + Vector2(-0.75, -0.8) * u, Vector2(1.5, 0.5) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.75, -0.8) * u, Vector2(1.5, 0.14) * u), light)
		"drop":
			ci.draw_circle(center + Vector2(0, 0.28) * u, 0.52 * u, color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.49, 0.12), Vector2(0.49, 0.12), Vector2(0, -0.9)]), color)
			ci.draw_circle(center + Vector2(-0.2, 0.32) * u, 0.13 * u, light)
		"clock":
			ci.draw_arc(center, 0.74 * u, 0.0, TAU, 40, color, 0.16 * u, true)
			ci.draw_line(center, center + Vector2(0, -0.5) * u, color, 0.14 * u)
			ci.draw_line(center, center + Vector2(0.36, 0.12) * u, color, 0.14 * u)
			ci.draw_circle(center, 0.1 * u, color)
		"swoosh":
			for i in 3:
				var y := (i - 1) * 0.5
				var length: float = [1.4, 1.0, 1.25][i]
				var start := center + Vector2(-0.8, y) * u
				ci.draw_line(start, start + Vector2(length, 0) * u, color, 0.18 * u)
				ci.draw_circle(start + Vector2(length, 0) * u, 0.09 * u, color)
				ci.draw_circle(start, 0.09 * u, color)
		"target":
			ci.draw_arc(center, 0.78 * u, 0.0, TAU, 40, color, 0.13 * u, true)
			ci.draw_arc(center, 0.44 * u, 0.0, TAU, 32, color, 0.13 * u, true)
			ci.draw_circle(center, 0.14 * u, color)
		"skull":
			_skull(ci, center, u, color, bg)
		"flame":
			var outer := [Vector2(0, -0.95), Vector2(0.32, -0.45), Vector2(0.62, 0.05), Vector2(0.58, 0.52), Vector2(0.28, 0.85), Vector2(-0.28, 0.85), Vector2(-0.58, 0.52), Vector2(-0.62, 0.05), Vector2(-0.3, -0.28), Vector2(-0.08, 0.02)]
			ci.draw_colored_polygon(_points(center, u, outer), color)
			var inner: Array = outer.map(func(p: Vector2) -> Vector2: return p * 0.45 + Vector2(0, 0.38))
			ci.draw_colored_polygon(_points(center, u, inner), light)
		"chain":
			var zigzag := [Vector2(-0.75, 0.7), Vector2(-0.2, 0.15), Vector2(-0.4, -0.05), Vector2(0.2, -0.3), Vector2(0.0, -0.45), Vector2(0.75, -0.7)]
			ci.draw_polyline(_points(center, u, zigzag), color, 0.16 * u)
			ci.draw_circle(center + Vector2(-0.75, 0.7) * u, 0.22 * u, color)
			ci.draw_circle(center + Vector2(0.75, -0.7) * u, 0.22 * u, color)
		"quake":
			ci.draw_rect(Rect2(center + Vector2(-0.12, -0.95) * u, Vector2(0.24, 0.7) * u), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.42, -0.3), Vector2(0.42, -0.3), Vector2(0, 0.2)]), color)
			ci.draw_line(center + Vector2(-0.9, 0.62) * u, center + Vector2(0.9, 0.62) * u, color, 0.14 * u)
			for side in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(0.45 * side, 0.45) * u, center + Vector2(0.85 * side, 0.1) * u, color, 0.11 * u)
		"sigil":
			ci.draw_colored_polygon(_star(center, 0.95 * u, 0.62 * u, 4, -PI / 2), color)
			ci.draw_colored_polygon(_star(center, 0.48 * u, 0.48 * u, 4, -PI / 2), bg)
			ci.draw_circle(center, 0.16 * u, color)

		# --- Resources ---------------------------------------------------------
		"silver":
			# A short stack of coins.
			for i in 3:
				var at := center + Vector2(-0.08 + i * 0.08, 0.5 - i * 0.36) * u
				ci.draw_colored_polygon(_ellipse(at + Vector2(0, 0.12) * u, 0.7 * u, 0.26 * u), dark)
				ci.draw_rect(Rect2(at + Vector2(-0.7, 0) * u, Vector2(1.4, 0.12) * u), dark)
				ci.draw_colored_polygon(_ellipse(at, 0.7 * u, 0.26 * u), color)
				ci.draw_colored_polygon(_ellipse(at, 0.42 * u, 0.13 * u), light)
		"xp":
			# A cut gem.
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.92), Vector2(0.72, -0.22), Vector2(0, 0.92), Vector2(-0.72, -0.22)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.92), Vector2(0.72, -0.22), Vector2(-0.72, -0.22)]), light)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.22), Vector2(0.72, -0.22), Vector2(0, 0.92)]), dark)
			ci.draw_line(center + Vector2(-0.3, -0.5) * u, center + Vector2(-0.12, -0.65) * u, Color(1, 1, 1, 0.8), 0.09 * u)
		"skill_point":
			ci.draw_colored_polygon(_star(center + Vector2(-0.12, 0.1) * u, 0.85 * u, 0.2 * u, 4, -PI / 2), color)
			ci.draw_colored_polygon(_star(center + Vector2(0.58, -0.56) * u, 0.34 * u, 0.09 * u, 4, -PI / 2), light)
			ci.draw_circle(center + Vector2(0.6, 0.6) * u, 0.09 * u, light)
		"stat_point":
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.9), Vector2(0.62, -0.15), Vector2(0.25, -0.15), Vector2(0.25, 0.85), Vector2(-0.25, 0.85), Vector2(-0.25, -0.15), Vector2(-0.62, -0.15)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.9), Vector2(0.62, -0.15), Vector2(0, -0.15)]), light)

		# --- Gear and training -------------------------------------------------
		"wraps":
			_fist(ci, center, u, color, bg)
			for i in 3:
				var y := -0.3 + i * 0.32
				ci.draw_line(center + Vector2(-0.82, y + 0.12) * u, center + Vector2(0.82, y - 0.12) * u, light, 0.09 * u)
			ci.draw_line(center + Vector2(-0.5, 0.75) * u, center + Vector2(0.5, 0.75) * u, bg, 0.07 * u)
		"glove":
			_glove(ci, center, u, 0.0, color, bg)
		"crossed_gloves":
			_glove(ci, center + Vector2(-0.28, 0.05) * u, u * 0.66, -0.5, dark, bg)
			_glove(ci, center + Vector2(0.28, 0.05) * u, u * 0.66, 0.5, color, bg)
		"brass":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.82, 0.02), Vector2(0.82, 0.02), Vector2(0.55, 0.62), Vector2(-0.55, 0.62)]), dark)
			for x in [-0.6, -0.2, 0.2, 0.6]:
				ci.draw_circle(center + Vector2(x, -0.3) * u, 0.25 * u, color)
			for x in [-0.6, -0.2, 0.2, 0.6]:
				ci.draw_circle(center + Vector2(x, -0.3) * u, 0.12 * u, bg)
			ci.draw_line(center + Vector2(-0.75, -0.55) * u, center + Vector2(0.75, -0.55) * u, light, 0.06 * u)
		"tape":
			ci.draw_rect(Rect2(center + Vector2(0.22, -0.1) * u, Vector2(0.38, 0.9) * u), dark)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.22, 0.8), Vector2(0.6, 0.8), Vector2(0.5, 0.95), Vector2(0.4, 0.82), Vector2(0.3, 0.95)]), dark)
			ci.draw_circle(center + Vector2(-0.15, -0.1) * u, 0.7 * u, color)
			ci.draw_arc(center + Vector2(-0.15, -0.1) * u, 0.5 * u, 0.0, TAU, 28, dark, 0.06 * u, true)
			ci.draw_circle(center + Vector2(-0.15, -0.1) * u, 0.3 * u, bg)
		"fast_fist":
			_fist(ci, center + Vector2(0.2, 0) * u, u * 0.78, color, bg)
			for y in [-0.42, 0.0, 0.42]:
				ci.draw_line(center + Vector2(-0.95, y) * u, center + Vector2(-0.5, y) * u, light, 0.1 * u)
		"double_fist":
			_fist(ci, center + Vector2(-0.32, 0.25) * u, u * 0.6, dark, bg)
			_fist(ci, center + Vector2(0.28, -0.22) * u, u * 0.62, color, bg)
		"wing_boot":
			_boot(ci, center + Vector2(0.18, 0.05) * u, u * 0.82, color, bg)
			for i in 3:
				var from := center + Vector2(-0.22, -0.55 + i * 0.24) * u
				ci.draw_line(from, from + Vector2(-0.7 + i * 0.12, -0.3 + i * 0.05) * u, light, (0.13 - i * 0.02) * u)
		"footprints":
			_foot(ci, center + Vector2(-0.4, 0.28) * u, u * 1.45, color)
			_foot(ci, center + Vector2(0.4, -0.3) * u, u * 1.45, dark)
		"road":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.25, -0.9), Vector2(0.25, -0.9), Vector2(0.92, 0.9), Vector2(-0.92, 0.9)]), dark)
			for dash in [[-0.78, 0.18, 0.05], [-0.38, 0.28, 0.07], [0.12, 0.42, 0.1]]:
				ci.draw_rect(Rect2(center + Vector2(-dash[2], dash[0]) * u, Vector2(dash[2] * 2.0, dash[1]) * u), light)
			ci.draw_line(center + Vector2(-0.25, -0.9) * u, center + Vector2(-0.92, 0.9) * u, color, 0.09 * u)
			ci.draw_line(center + Vector2(0.25, -0.9) * u, center + Vector2(0.92, 0.9) * u, color, 0.09 * u)
		"heavy_bag":
			ci.draw_line(center + Vector2(0, -0.98) * u, center + Vector2(0, -0.7) * u, dark, 0.09 * u)
			ci.draw_circle(center + Vector2(0, -0.42) * u, 0.42 * u, color)
			ci.draw_rect(Rect2(center + Vector2(-0.42, -0.42) * u, Vector2(0.84, 0.92) * u), color)
			ci.draw_circle(center + Vector2(0, 0.5) * u, 0.42 * u, color)
			for y in [-0.3, 0.42]:
				ci.draw_line(center + Vector2(-0.42, y) * u, center + Vector2(0.42, y) * u, bg, 0.08 * u)
			ci.draw_rect(Rect2(center + Vector2(-0.3, -0.62) * u, Vector2(0.12, 0.9) * u), light)
		"dumbbell":
			ci.draw_line(center + Vector2(-0.7, 0) * u, center + Vector2(0.7, 0) * u, dark, 0.16 * u)
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(center + Vector2(0.55 * side - 0.13, -0.55) * u, Vector2(0.26, 1.1) * u), color)
				ci.draw_rect(Rect2(center + Vector2(0.88 * side - 0.08, -0.35) * u, Vector2(0.16, 0.7) * u), dark)
				ci.draw_rect(Rect2(center + Vector2(0.55 * side - 0.13, -0.55) * u, Vector2(0.26, 0.1) * u), light)
		"belt":
			ci.draw_rect(Rect2(center + Vector2(-0.98, -0.24) * u, Vector2(1.96, 0.48) * u), dark)
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(center + Vector2(0.72 * side - 0.14, -0.3) * u, Vector2(0.28, 0.6) * u), color)
			ci.draw_circle(center, 0.6 * u, color)
			ci.draw_arc(center, 0.48 * u, 0.0, TAU, 28, dark, 0.06 * u, true)
			ci.draw_colored_polygon(_star(center, 0.3 * u, 0.13 * u, 5, -PI / 2), light)
		"medal":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.52, -0.95), Vector2(-0.18, -0.95), Vector2(0.14, -0.2), Vector2(-0.2, -0.2)]), dark)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.52, -0.95), Vector2(0.18, -0.95), Vector2(-0.14, -0.2), Vector2(0.2, -0.2)]), dark.darkened(0.2))
			ci.draw_circle(center + Vector2(0, 0.32) * u, 0.58 * u, color)
			ci.draw_colored_polygon(_star(center + Vector2(0, 0.34) * u, 0.32 * u, 0.13 * u, 5, -PI / 2), light)
		"tooth":
			ci.draw_circle(center + Vector2(-0.32, -0.38) * u, 0.42 * u, color)
			ci.draw_circle(center + Vector2(0.32, -0.38) * u, 0.42 * u, color)
			ci.draw_rect(Rect2(center + Vector2(-0.74, -0.4) * u, Vector2(1.48, 0.42) * u), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.74, 0.0), Vector2(-0.06, 0.0), Vector2(-0.28, 0.92), Vector2(-0.56, 0.86)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.74, 0.0), Vector2(0.06, 0.0), Vector2(0.28, 0.92), Vector2(0.56, 0.86)]), color)
			ci.draw_circle(center + Vector2(0, -0.82) * u, 0.16 * u, bg)
			ci.draw_circle(center + Vector2(-0.4, -0.45) * u, 0.12 * u, light)
		"helmet":
			ci.draw_circle(center + Vector2(0, -0.08) * u, 0.8 * u, color)
			ci.draw_circle(center + Vector2(0, -0.12) * u, 0.42 * u, bg)
			ci.draw_rect(Rect2(center + Vector2(-0.42, -0.12) * u, Vector2(0.84, 0.5) * u), bg)
			ci.draw_rect(Rect2(center + Vector2(-0.34, 0.6) * u, Vector2(0.68, 0.28) * u), dark)
			ci.draw_arc(center + Vector2(0, -0.08) * u, 0.68 * u, PI * 1.1, PI * 1.45, 10, light, 0.1 * u)
		"chestplate":
			var plate := [Vector2(-0.88, -0.78), Vector2(-0.3, -0.88), Vector2(0, -0.62), Vector2(0.3, -0.88), Vector2(0.88, -0.78), Vector2(0.7, 0.2), Vector2(0.4, 0.88), Vector2(-0.4, 0.88), Vector2(-0.7, 0.2)]
			ci.draw_colored_polygon(_points(center, u, plate), color)
			ci.draw_line(center + Vector2(0, -0.55) * u, center + Vector2(0, 0.85) * u, bg, 0.07 * u)
			ci.draw_arc(center + Vector2(-0.32, -0.25) * u, 0.3 * u, 0.2, PI - 0.2, 10, dark, 0.08 * u)
			ci.draw_arc(center + Vector2(0.32, -0.25) * u, 0.3 * u, 0.2, PI - 0.2, 10, dark, 0.08 * u)
		"anvil":
			ci.draw_rect(Rect2(center + Vector2(-0.55, -0.55) * u, Vector2(1.4, 0.36) * u), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.55, -0.55), Vector2(-0.55, -0.19), Vector2(-0.98, -0.5)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.25, -0.19), Vector2(0.55, -0.19), Vector2(0.32, 0.3), Vector2(-0.05, 0.3)]), dark)
			ci.draw_rect(Rect2(center + Vector2(-0.5, 0.3) * u, Vector2(1.18, 0.42) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.55, -0.55) * u, Vector2(1.4, 0.1) * u), light)
		"anchor":
			ci.draw_arc(center + Vector2(0, -0.72) * u, 0.18 * u, 0.0, TAU, 16, color, 0.11 * u, true)
			ci.draw_rect(Rect2(center + Vector2(-0.08, -0.55) * u, Vector2(0.16, 1.35) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.42, -0.38) * u, Vector2(0.84, 0.14) * u), dark)
			ci.draw_arc(center + Vector2(0, 0.12) * u, 0.68 * u, 0.2, PI - 0.2, 20, color, 0.16 * u)
			for side in [-1.0, 1.0]:
				var tip := center + Vector2(0.66 * side, 0.26) * u
				ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -0.32) * u, tip + Vector2(0.16 * side, 0.08) * u, tip + Vector2(-0.18 * side, 0.08) * u]), color)
		"medkit":
			ci.draw_arc(center + Vector2(0, -0.48) * u, 0.3 * u, PI, TAU, 12, dark, 0.14 * u)
			ci.draw_rect(Rect2(center + Vector2(-0.88, -0.5) * u, Vector2(1.76, 1.28) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.13, -0.28) * u, Vector2(0.26, 0.84) * u), bg)
			ci.draw_rect(Rect2(center + Vector2(-0.42, 0.01) * u, Vector2(0.84, 0.26) * u), bg)
			ci.draw_rect(Rect2(center + Vector2(-0.88, -0.5) * u, Vector2(1.76, 0.1) * u), light)
		"bucket":
			ci.draw_arc(center + Vector2(0, -0.35) * u, 0.62 * u, PI, TAU, 16, dark, 0.09 * u)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.75, -0.35), Vector2(0.75, -0.35), Vector2(0.55, 0.88), Vector2(-0.55, 0.88)]), color)
			ci.draw_colored_polygon(_ellipse(center + Vector2(0, -0.35) * u, 0.75 * u, 0.17 * u), light)
			for y in [0.05, 0.55]:
				ci.draw_line(center + Vector2(-0.68 + y * 0.16, y) * u, center + Vector2(0.68 - y * 0.16, y) * u, dark, 0.08 * u)

		# --- Loot and luck -----------------------------------------------------
		"bag":
			ci.draw_circle(center + Vector2(0, 0.28) * u, 0.64 * u, color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.28, -0.3), Vector2(0.28, -0.3), Vector2(0.13, -0.52), Vector2(-0.13, -0.52)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.42, -0.9), Vector2(0.42, -0.9), Vector2(0.15, -0.52), Vector2(-0.15, -0.52)]), dark)
			ci.draw_line(center + Vector2(-0.3, -0.42) * u, center + Vector2(0.3, -0.42) * u, dark, 0.1 * u)
			ci.draw_colored_polygon(_star(center + Vector2(0, 0.3) * u, 0.3 * u, 0.12 * u, 4, -PI / 2), bg)
		"chest":
			var lid := [Vector2(-0.88, -0.15), Vector2(-0.88, -0.45), Vector2(-0.6, -0.72), Vector2(0.6, -0.72), Vector2(0.88, -0.45), Vector2(0.88, -0.15)]
			ci.draw_colored_polygon(_points(center, u, lid), light)
			ci.draw_rect(Rect2(center + Vector2(-0.88, -0.15) * u, Vector2(1.76, 0.95) * u), color)
			for x in [-0.62, 0.47]:
				ci.draw_rect(Rect2(center + Vector2(x, -0.72) * u, Vector2(0.15, 1.52) * u), dark)
			ci.draw_rect(Rect2(center + Vector2(-0.16, -0.28) * u, Vector2(0.32, 0.36) * u), dark)
			ci.draw_circle(center + Vector2(0, -0.1) * u, 0.07 * u, bg)
		"crown":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.85, 0.45), Vector2(-0.85, -0.55), Vector2(-0.42, -0.05), Vector2(0, -0.75), Vector2(0.42, -0.05), Vector2(0.85, -0.55), Vector2(0.85, 0.45)]), color)
			ci.draw_rect(Rect2(center + Vector2(-0.85, 0.42) * u, Vector2(1.7, 0.36) * u), dark)
			for tip in [Vector2(-0.85, -0.6), Vector2(0, -0.8), Vector2(0.85, -0.6)]:
				ci.draw_circle(center + tip * u, 0.13 * u, light)
			for x in [-0.45, 0.0, 0.45]:
				ci.draw_circle(center + Vector2(x, 0.6) * u, 0.09 * u, bg)
		"shovel":
			u *= 1.15
			var angle := -PI / 4.0
			_line_r(ci, center, u, Vector2(0, -0.9), Vector2(0, 0.1), angle, dark, 0.14)
			_line_r(ci, center, u, Vector2(-0.24, -0.92), Vector2(0.24, -0.92), angle, dark, 0.14)
			_poly_r(ci, center, u, [Vector2(-0.34, 0.05), Vector2(0.34, 0.05), Vector2(0.34, 0.55), Vector2(0, 0.95), Vector2(-0.34, 0.55)], angle, color)
			_line_r(ci, center, u, Vector2(-0.18, 0.15), Vector2(-0.18, 0.55), angle, light, 0.07)
		"wanted":
			ci.draw_rect(Rect2(center + Vector2(-0.72, -0.92) * u, Vector2(1.44, 1.84) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.52, -0.78) * u, Vector2(1.04, 0.14) * u), bg)
			_skull(ci, center + Vector2(0, 0.0) * u, u * 0.45, bg, color)
			for y in [0.5, 0.68]:
				ci.draw_line(center + Vector2(-0.5, y) * u, center + Vector2(0.5, y) * u, dark, 0.07 * u)
		"dice":
			var tilt := 0.22
			_poly_r(ci, center, u, [Vector2(-0.72, -0.72), Vector2(0.72, -0.72), Vector2(0.72, 0.72), Vector2(-0.72, 0.72)], tilt, color)
			_poly_r(ci, center, u, [Vector2(-0.72, -0.72), Vector2(0.72, -0.72), Vector2(0.72, -0.58), Vector2(-0.72, -0.58)], tilt, light)
			for pip in [Vector2(-0.38, -0.38), Vector2(0.38, -0.38), Vector2(0, 0), Vector2(-0.38, 0.38), Vector2(0.38, 0.38)]:
				ci.draw_circle(center + pip.rotated(tilt) * u, 0.14 * u, bg)
		"sun":
			for i in 8:
				var dir := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(center + dir * 0.6 * u, center + dir * 0.94 * u, dark if i % 2 else color, 0.14 * u)
			ci.draw_circle(center, 0.45 * u, color)
			ci.draw_circle(center + Vector2(-0.12, -0.12) * u, 0.2 * u, light)
		"moon":
			ci.draw_circle(center, 0.8 * u, color)
			ci.draw_circle(center + Vector2(0.38, -0.26) * u, 0.64 * u, bg)
			ci.draw_circle(center + Vector2(-0.38, 0.3) * u, 0.1 * u, dark)
			ci.draw_circle(center + Vector2(-0.12, 0.55) * u, 0.07 * u, dark)
			ci.draw_colored_polygon(_star(center + Vector2(0.55, 0.45) * u, 0.2 * u, 0.06 * u, 4, -PI / 2), light)

		# --- Powers ------------------------------------------------------------
		"snowflake":
			_snowflake(ci, center, u, color)
		"shard":
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.95), Vector2(0.48, -0.32), Vector2(0.3, 0.88), Vector2(-0.3, 0.88), Vector2(-0.48, -0.32)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0, -0.95), Vector2(0.48, -0.32), Vector2(0.02, -0.1)]), light)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.02, -0.1), Vector2(0.48, -0.32), Vector2(0.3, 0.88)]), dark)
			ci.draw_polyline(_points(center, u, [Vector2(-0.12, -0.45), Vector2(0.06, 0.02), Vector2(-0.1, 0.42), Vector2(0.0, 0.7)]), bg, 0.07 * u)
		"icicle":
			ci.draw_rect(Rect2(center + Vector2(-0.92, -0.92) * u, Vector2(1.84, 0.28) * u), light)
			for spike in [[-0.88, -0.48, 0.42], [-0.42, 0.04, 0.92], [0.08, 0.46, 0.25], [0.5, 0.9, 0.62]]:
				ci.draw_colored_polygon(_points(center, u, [Vector2(spike[0], -0.64), Vector2(spike[1], -0.64), Vector2((spike[0] + spike[1]) / 2.0, spike[2])]), color)
				ci.draw_line(center + Vector2(spike[0] + 0.1, -0.6) * u, center + Vector2((spike[0] + spike[1]) / 2.0 - 0.03, spike[2] - 0.35) * u, light, 0.06 * u)
		"nova":
			ci.draw_arc(center, 0.85 * u, 0.0, TAU, 40, dark, 0.09 * u, true)
			for i in 8:
				ci.draw_circle(center + Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * 0.85 * u, 0.09 * u, color)
			_snowflake(ci, center, u * 0.6, color)
		"thermometer":
			ci.draw_circle(center + Vector2(-0.1, 0.55) * u, 0.34 * u, color)
			ci.draw_rect(Rect2(center + Vector2(-0.27, -0.85) * u, Vector2(0.34, 1.3) * u), color)
			ci.draw_circle(center + Vector2(-0.1, -0.85) * u, 0.17 * u, color)
			ci.draw_rect(Rect2(center + Vector2(-0.17, -0.85) * u, Vector2(0.14, 1.0) * u), bg)
			ci.draw_rect(Rect2(center + Vector2(-0.17, -0.25) * u, Vector2(0.14, 0.7) * u), light)
			ci.draw_circle(center + Vector2(-0.1, 0.55) * u, 0.18 * u, light)
			for y in [-0.6, -0.35, -0.1]:
				ci.draw_line(center + Vector2(0.18, y) * u, center + Vector2(0.45, y) * u, dark, 0.08 * u)
		"match":
			ci.draw_line(center + Vector2(-0.7, 0.85) * u, center + Vector2(0.12, -0.05) * u, dark, 0.15 * u)
			ci.draw_circle(center + Vector2(0.17, -0.1) * u, 0.18 * u, Color(0.85, 0.2, 0.15) if color.r > 0.5 else light)
			draw(ci, "flame", center + Vector2(0.35, -0.52) * u, size * 0.5, color, bg)
		"ripple":
			ci.draw_circle(center, 0.2 * u, color)
			for ring in [[0.5, 0.0, color], [0.85, PI / 4.0, dark]]:
				for k in 4:
					var start: float = ring[1] + k * PI / 2.0 + 0.22
					ci.draw_arc(center, ring[0] * u, start, start + PI / 2.0 - 0.44, 10, ring[2], 0.13 * u)
		"fork":
			var trunk := [Vector2(0.15, -0.95), Vector2(-0.3, -0.25), Vector2(0.08, -0.2), Vector2(-0.15, 0.25)]
			ci.draw_polyline(_points(center, u, trunk), color, 0.17 * u)
			ci.draw_polyline(_points(center, u, [Vector2(-0.15, 0.25), Vector2(-0.62, 0.88)]), color, 0.15 * u)
			ci.draw_polyline(_points(center, u, [Vector2(-0.15, 0.25), Vector2(0.2, 0.2), Vector2(0.55, 0.85)]), light, 0.13 * u)
			for end in [Vector2(-0.62, 0.88), Vector2(0.55, 0.85)]:
				ci.draw_circle(center + end * u, 0.12 * u, light)
		"storm":
			for blob in [[Vector2(-0.4, -0.3), 0.34], [Vector2(0.05, -0.5), 0.42], [Vector2(0.48, -0.25), 0.3]]:
				ci.draw_circle(center + blob[0] * u, blob[1] * u, dark)
			ci.draw_rect(Rect2(center + Vector2(-0.74, -0.3) * u, Vector2(1.52, 0.32) * u), dark)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.12, 0.0), Vector2(-0.3, 0.52), Vector2(-0.02, 0.52), Vector2(-0.2, 0.98), Vector2(0.32, 0.36), Vector2(0.04, 0.36), Vector2(0.24, 0.0)]), color)
		"magnet":
			ci.draw_arc(center + Vector2(0, 0.0) * u, 0.52 * u, 0.0, PI, 20, color, 0.38 * u)
			for side in [-1.0, 1.0]:
				ci.draw_rect(Rect2(center + Vector2(0.52 * side - 0.19, -0.7) * u, Vector2(0.38, 0.72) * u), color)
				ci.draw_rect(Rect2(center + Vector2(0.52 * side - 0.19, -0.9) * u, Vector2(0.38, 0.26) * u), light)
			ci.draw_line(center + Vector2(-0.2, -0.85) * u, center + Vector2(0.2, -0.6) * u, light, 0.06 * u)
		"battery":
			ci.draw_rect(Rect2(center + Vector2(-0.88, -0.45) * u, Vector2(1.6, 0.9) * u), color)
			ci.draw_rect(Rect2(center + Vector2(0.72, -0.2) * u, Vector2(0.18, 0.4) * u), color)
			ci.draw_rect(Rect2(center + Vector2(-0.76, -0.33) * u, Vector2(1.36, 0.66) * u), bg)
			for i in 3:
				ci.draw_rect(Rect2(center + Vector2(-0.7 + i * 0.44, -0.27) * u, Vector2(0.36, 0.54) * u), light if i == 2 else color)
		"spark":
			ci.draw_colored_polygon(_star(center + Vector2(-0.1, 0.1) * u, 0.88 * u, 0.18 * u, 4, -PI / 2), color)
			ci.draw_colored_polygon(_star(center + Vector2(-0.1, 0.1) * u, 0.4 * u, 0.1 * u, 4, -PI / 4), light)
			ci.draw_colored_polygon(_star(center + Vector2(0.6, -0.6) * u, 0.3 * u, 0.08 * u, 4, -PI / 2), light)
		"fang":
			ci.draw_rect(Rect2(center + Vector2(-0.88, -0.9) * u, Vector2(1.76, 0.4) * u), dark)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.72, -0.52), Vector2(-0.18, -0.52), Vector2(-0.42, 0.88)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.72, -0.52), Vector2(0.18, -0.52), Vector2(0.42, 0.88)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.16, -0.52), Vector2(0.16, -0.52), Vector2(0, -0.1)]), light)
			ci.draw_circle(center + Vector2(0.42, 0.88) * u, 0.1 * u, Color(0.9, 0.15, 0.15))
		"blood_burst":
			ci.draw_colored_polygon(_star(center, u * 0.95, u * 0.55, 10, 0.0), color)
			ci.draw_circle(center + Vector2(0, 0.2) * u, 0.3 * u, bg)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.28, 0.1), Vector2(0.28, 0.1), Vector2(0, -0.5)]), bg)

		# --- The body and the mind ---------------------------------------------
		"cracked_skull":
			_skull(ci, center, u, color, bg)
			ci.draw_polyline(_points(center, u, [Vector2(0.05, -0.8), Vector2(-0.08, -0.55), Vector2(0.12, -0.42), Vector2(-0.02, -0.28)]), bg, 0.08 * u)
		"eye":
			var almond := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				almond.append(center + Vector2(-0.95 + 1.9 * t, -0.58 * sin(PI * t)) * u)
			for i in range(11, 0, -1):
				var t := i / 12.0
				almond.append(center + Vector2(-0.95 + 1.9 * t, 0.58 * sin(PI * t)) * u)
			ci.draw_colored_polygon(almond, color)
			ci.draw_circle(center, 0.4 * u, bg)
			ci.draw_circle(center, 0.27 * u, dark)
			ci.draw_circle(center, 0.13 * u, bg)
			ci.draw_circle(center + Vector2(-0.12, -0.12) * u, 0.07 * u, light)
		"ghost":
			ci.draw_circle(center + Vector2(0, -0.22) * u, 0.64 * u, color)
			ci.draw_rect(Rect2(center + Vector2(-0.64, -0.22) * u, Vector2(1.28, 0.9) * u), color)
			for x in [-0.43, 0.0, 0.43]:
				ci.draw_circle(center + Vector2(x, 0.72) * u, 0.2 * u, bg)
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(_ellipse(center + Vector2(0.24 * side, -0.25) * u, 0.12 * u, 0.18 * u), bg)
			ci.draw_circle(center + Vector2(0, 0.15) * u, 0.1 * u, bg)
		"horns":
			for side in [-1.0, 1.0]:
				ci.draw_colored_polygon(_points(center, u, [Vector2(0.55 * side, -0.05), Vector2(0.15 * side, -0.32), Vector2(0.9 * side, -0.98)]), light)
			ci.draw_circle(center + Vector2(0, 0.22) * u, 0.62 * u, color)
			for side in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(0.42 * side, 0.05) * u, center + Vector2(0.1 * side, 0.22) * u, bg, 0.12 * u)
			ci.draw_line(center + Vector2(-0.25, 0.55) * u, center + Vector2(0.25, 0.55) * u, bg, 0.1 * u)
		"rage":
			ci.draw_circle(center, 0.85 * u, color)
			for side in [-1.0, 1.0]:
				ci.draw_line(center + Vector2(0.58 * side, -0.42) * u, center + Vector2(0.1 * side, -0.18) * u, bg, 0.14 * u)
				ci.draw_circle(center + Vector2(0.3 * side, 0.0) * u, 0.11 * u, bg)
			ci.draw_rect(Rect2(center + Vector2(-0.42, 0.3) * u, Vector2(0.84, 0.26) * u), bg)
			ci.draw_line(center + Vector2(-0.42, 0.43) * u, center + Vector2(0.42, 0.43) * u, color, 0.05 * u)
			ci.draw_colored_polygon(_star(center + Vector2(0.62, -0.68) * u, 0.26 * u, 0.1 * u, 4, PI / 4), dark)
		"heartbeat":
			_heart(ci, center, u, color)
			ci.draw_polyline(_points(center, u, [Vector2(-0.98, -0.05), Vector2(-0.42, -0.05), Vector2(-0.26, -0.42), Vector2(-0.04, 0.32), Vector2(0.14, -0.18), Vector2(0.26, -0.05), Vector2(0.98, -0.05)]), bg, 0.11 * u)
		"wind":
			for line in [[-0.48, 0.45, 0.16], [0.0, 0.62, 0.2], [0.48, 0.2, 0.14]]:
				var end := center + Vector2(line[1], line[0]) * u
				ci.draw_line(center + Vector2(-0.92, line[0]) * u, end, color, 0.13 * u)
				ci.draw_arc(end + Vector2(0, -line[2]) * u, line[2] * u, -PI * 0.9, PI / 2.0, 10, color, 0.13 * u)
		"headshot":
			ci.draw_circle(center + Vector2(0, -0.3) * u, 0.44 * u, color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.85, 0.92), Vector2(-0.7, 0.38), Vector2(-0.35, 0.22), Vector2(0.35, 0.22), Vector2(0.7, 0.38), Vector2(0.85, 0.92)]), dark)
			ci.draw_arc(center + Vector2(0, -0.3) * u, 0.24 * u, 0.0, TAU, 20, bg, 0.07 * u, true)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(center + Vector2(0, -0.3) * u + dir * 0.1 * u, center + Vector2(0, -0.3) * u + dir * 0.36 * u, bg, 0.06 * u)
		"gut":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.7, -0.92), Vector2(0.7, -0.92), Vector2(0.58, 0.92), Vector2(-0.58, 0.92)]), color)
			ci.draw_line(center + Vector2(0, -0.75) * u, center + Vector2(0, 0.8) * u, bg, 0.08 * u)
			for y in [-0.42, 0.05, 0.5]:
				ci.draw_line(center + Vector2(-0.5, y) * u, center + Vector2(0.5, y) * u, bg, 0.07 * u)
			ci.draw_colored_polygon(_star(center + Vector2(0.55, 0.25) * u, 0.38 * u, 0.16 * u, 6, 0.0), light)
		"slip":
			ci.draw_circle(center + Vector2(-0.38, -0.12) * u, 0.42 * u, Color(color, color.a * 0.35))
			ci.draw_circle(center + Vector2(0.28, -0.2) * u, 0.44 * u, color)
			ci.draw_arc(center + Vector2(-0.05, -0.1) * u, 0.8 * u, PI * 0.2, PI * 0.8, 14, dark, 0.12 * u)
			ci.draw_circle(center + Vector2(0.42, -0.28) * u, 0.08 * u, bg)
		"bones":
			for line in [[Vector2(-0.62, -0.62), Vector2(0.62, 0.62)], [Vector2(0.62, -0.62), Vector2(-0.62, 0.62)]]:
				ci.draw_line(center + line[0] * u, center + line[1] * u, color, 0.22 * u)
				for end in line:
					var dir: Vector2 = (end as Vector2).normalized()
					var side := Vector2(-dir.y, dir.x)
					for s in [-1.0, 1.0]:
						ci.draw_circle(center + (end + side * 0.14 * s + dir * 0.06) * u, 0.15 * u, color)
			ci.draw_line(center + Vector2(-0.45, -0.52) * u, center + Vector2(0.3, 0.22) * u, light, 0.06 * u)

		# --- Movement and tempo ------------------------------------------------
		"feather":
			var vane := [Vector2(0, -0.95), Vector2(0.32, -0.6), Vector2(0.4, -0.1), Vector2(0.26, 0.4), Vector2(0, 0.62), Vector2(-0.26, 0.4), Vector2(-0.4, -0.1), Vector2(-0.32, -0.6)]
			_poly_r(ci, center, u, vane, PI / 5.0, color)
			_line_r(ci, center, u, Vector2(0, -0.75), Vector2(0, 0.6), PI / 5.0, bg, 0.07)
			_line_r(ci, center, u, Vector2(0, 0.55), Vector2(0, 0.98), PI / 5.0, dark, 0.09)
			for y in [-0.35, 0.05]:
				_line_r(ci, center, u, Vector2(0.4, y), Vector2(0.12, y + 0.15), PI / 5.0, bg, 0.05)
		"wing":
			var wing := [Vector2(-0.92, -0.62), Vector2(0.9, -0.9), Vector2(0.72, -0.48), Vector2(0.82, -0.46), Vector2(0.52, -0.06), Vector2(0.62, -0.04), Vector2(0.24, 0.36), Vector2(0.3, 0.38), Vector2(-0.22, 0.78), Vector2(-0.92, 0.2)]
			ci.draw_colored_polygon(_points(center, u, wing), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.92, -0.62), Vector2(0.9, -0.9), Vector2(0.72, -0.48), Vector2(-0.6, -0.3)]), light)
		"mountain":
			ci.draw_colored_polygon(_points(center, u, [Vector2(0.15, 0.78), Vector2(0.58, 0.0), Vector2(0.98, 0.78)]), dark)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.95, 0.78), Vector2(-0.12, -0.72), Vector2(0.72, 0.78)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.12, -0.72), Vector2(-0.36, -0.28), Vector2(-0.18, -0.36), Vector2(-0.04, -0.24), Vector2(0.12, -0.28)]), light)
			ci.draw_line(center + Vector2(-0.12, -0.72) * u, center + Vector2(-0.12, -0.98) * u, light, 0.06 * u)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.12, -0.98), Vector2(0.18, -0.9), Vector2(-0.12, -0.82)]), light)
		"dive":
			_poly_r(ci, center, u, [Vector2(-0.2, -0.85), Vector2(0.2, -0.85), Vector2(0.2, 0.2), Vector2(0.52, 0.2), Vector2(0, 0.9), Vector2(-0.52, 0.2), Vector2(-0.2, 0.2)], -0.55, color)
			for offset in [-0.55, -0.2]:
				_line_r(ci, center, u, Vector2(offset * 1.2, -0.95), Vector2(offset * 1.2, -0.35), -0.55, light, 0.08)
		"stairs":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.92, 0.85), Vector2(-0.92, 0.35), Vector2(-0.35, 0.35), Vector2(-0.35, -0.15), Vector2(0.22, -0.15), Vector2(0.22, -0.65), Vector2(0.92, -0.65), Vector2(0.92, 0.85)]), color)
			for step in [Vector2(-0.92, 0.35), Vector2(-0.35, -0.15), Vector2(0.22, -0.65)]:
				ci.draw_rect(Rect2(center + step * u, Vector2(0.57, 0.1) * u), light)
			ci.draw_circle(center + Vector2(-0.62, -0.25) * u, 0.15 * u, dark)
		"chevrons":
			for i in 3:
				var x := -0.55 + i * 0.5
				var shade := color if i == 2 else (dark if i == 0 else color.darkened(0.15))
				ci.draw_polyline(_points(center, u, [Vector2(x - 0.22, -0.6), Vector2(x + 0.22, 0.0), Vector2(x - 0.22, 0.6)]), shade, 0.2 * u)
		"spiral":
			var curl := PackedVector2Array()
			for i in 41:
				var t := i / 40.0
				curl.append(center + Vector2.from_angle(t * PI * 3.6) * (0.08 + 0.84 * t) * u)
			ci.draw_polyline(curl, color, 0.15 * u)
			ci.draw_circle(curl[curl.size() - 1], 0.1 * u, light)
		"wave":
			for row in [[-0.2, color, 0.17], [0.32, dark, 0.12]]:
				var line := PackedVector2Array()
				for i in 25:
					var t := i / 24.0
					line.append(center + Vector2(-0.92 + 1.84 * t, row[0] + sin(t * TAU * 1.5) * 0.32) * u)
				ci.draw_polyline(line, row[1], row[2] * u)
		"flow":
			for k in 3:
				var line := PackedVector2Array()
				for i in 21:
					var t := i / 20.0
					line.append(center + Vector2(-0.9 + 1.8 * t, -0.5 + k * 0.5 + sin(t * TAU + k * 0.8) * 0.16) * u)
				ci.draw_polyline(line, [light, color, dark][k], 0.13 * u)
		"infinity":
			var loop := PackedVector2Array()
			for i in 49:
				var t := TAU * i / 48.0
				var d := 1.0 + sin(t) * sin(t)
				loop.append(center + Vector2(0.9 * cos(t) / d, 0.9 * sin(t) * cos(t) / d * 1.3) * u)
			ci.draw_polyline(loop, color, 0.18 * u)
		"hourglass":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.52, -0.72), Vector2(0.52, -0.72), Vector2(0.06, 0.0), Vector2(0.52, 0.72), Vector2(-0.52, 0.72), Vector2(-0.06, 0.0)]), Color(dark, 0.6))
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.3, -0.42), Vector2(0.3, -0.42), Vector2(0, -0.02)]), color)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.44, 0.72), Vector2(0.44, 0.72), Vector2(0, 0.34)]), color)
			ci.draw_line(center, center + Vector2(0, 0.4) * u, color, 0.06 * u)
			ci.draw_rect(Rect2(center + Vector2(-0.68, -0.92) * u, Vector2(1.36, 0.2) * u), light)
			ci.draw_rect(Rect2(center + Vector2(-0.68, 0.72) * u, Vector2(1.36, 0.2) * u), light)
		"stopwatch":
			ci.draw_rect(Rect2(center + Vector2(-0.12, -0.92) * u, Vector2(0.24, 0.2) * u), dark)
			ci.draw_line(center + Vector2(0.5, -0.55) * u, center + Vector2(0.66, -0.71) * u, dark, 0.14 * u)
			ci.draw_circle(center + Vector2(0, 0.12) * u, 0.72 * u, color)
			ci.draw_circle(center + Vector2(0, 0.12) * u, 0.54 * u, bg)
			ci.draw_colored_polygon(PackedVector2Array([center + Vector2(0, 0.12) * u, center + Vector2(0, -0.42) * u, center + Vector2(0.38, -0.26) * u]), Color(light, 0.5))
			ci.draw_line(center + Vector2(0, 0.12) * u, center + Vector2(0.3, -0.24) * u, color, 0.1 * u)
			ci.draw_circle(center + Vector2(0, 0.12) * u, 0.09 * u, color)
		"note":
			for head in [Vector2(-0.45, 0.58), Vector2(0.45, 0.42)]:
				ci.draw_colored_polygon(_ellipse(center + head * u, 0.28 * u, 0.21 * u), color)
			ci.draw_line(center + Vector2(-0.2, 0.55) * u, center + Vector2(-0.2, -0.62) * u, color, 0.1 * u)
			ci.draw_line(center + Vector2(0.7, 0.4) * u, center + Vector2(0.7, -0.78) * u, color, 0.1 * u)
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.25, -0.68), Vector2(0.75, -0.84), Vector2(0.75, -0.56), Vector2(-0.25, -0.4)]), light)

		# --- Finishing ---------------------------------------------------------
		"counter_arrow":
			ci.draw_arc(center, 0.62 * u, -PI * 0.85, PI * 0.55, 24, color, 0.18 * u)
			var tip_angle := PI * 0.55
			var tip := center + Vector2.from_angle(tip_angle) * 0.62 * u
			var forward := Vector2.from_angle(tip_angle + PI / 2.0)
			var side := Vector2.from_angle(tip_angle)
			ci.draw_colored_polygon(PackedVector2Array([tip + forward * 0.38 * u, tip + side * 0.3 * u, tip - side * 0.3 * u]), color)
			ci.draw_colored_polygon(_star(center, 0.3 * u, 0.13 * u, 6, 0.0), light)
		"crosshair":
			ci.draw_arc(center, 0.6 * u, 0.0, TAU, 36, color, 0.11 * u, true)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(center + dir * 0.3 * u, center + dir * 0.95 * u, color, 0.12 * u)
			ci.draw_circle(center, 0.1 * u, light)
		"axe":
			var tilt := -0.35
			_line_r(ci, center, u, Vector2(0, -0.95), Vector2(0, 0.98), tilt, dark, 0.15)
			for side in [-1.0, 1.0]:
				_poly_r(ci, center, u, [Vector2(0.08 * side, -0.7), Vector2(0.55 * side, -0.95), Vector2(0.9 * side, -0.5), Vector2(0.55 * side, -0.05), Vector2(0.08 * side, -0.3)], tilt, color if side > 0 else color.darkened(0.12))
			_line_r(ci, center, u, Vector2(0.62, -0.88), Vector2(0.86, -0.5), tilt, light, 0.08)
			_line_r(ci, center, u, Vector2(-0.62, -0.88), Vector2(-0.86, -0.5), tilt, light, 0.08)
		"slash":
			for k in 3:
				var x := -0.5 + k * 0.45
				var a := Vector2(x + 0.32, -0.9)
				var b := Vector2(x - 0.32, 0.9)
				var dir := (b - a).normalized()
				var side := Vector2(-dir.y, dir.x)
				var mid := (a + b) / 2.0
				ci.draw_colored_polygon(_points(center, u, [a, mid + side * 0.12, b, mid - side * 0.12]), color if k != 1 else light)
		"muscle":
			ci.draw_colored_polygon(_points(center, u, [Vector2(-0.95, 0.85), Vector2(-0.95, 0.25), Vector2(-0.25, 0.05), Vector2(0.15, -0.5), Vector2(0.55, -0.4), Vector2(0.4, 0.1), Vector2(0.1, 0.55), Vector2(-0.3, 0.85)]), color)
			ci.draw_circle(center + Vector2(-0.3, 0.32) * u, 0.4 * u, color)
			ci.draw_circle(center + Vector2(0.38, -0.66) * u, 0.3 * u, light)
			ci.draw_arc(center + Vector2(-0.3, 0.32) * u, 0.26 * u, PI * 1.1, PI * 1.6, 8, light, 0.08 * u)

		# --- Sigil capstones ---------------------------------------------------
		"pyre":
			draw(ci, "flame", center + Vector2(0, -0.32) * u, size * 0.62, light, bg)
			_skull(ci, center + Vector2(0, 0.38) * u, u * 0.56, color, bg)
		"thunderhead":
			for blob in [[Vector2(-0.42, -0.42), 0.32], [Vector2(0.02, -0.6), 0.38], [Vector2(0.45, -0.38), 0.3]]:
				ci.draw_circle(center + blob[0] * u, blob[1] * u, dark)
			ci.draw_rect(Rect2(center + Vector2(-0.74, -0.42) * u, Vector2(1.5, 0.3) * u), dark)
			for x in [-0.38, 0.3]:
				ci.draw_colored_polygon(_points(center + Vector2(x, 0) * u, u, [Vector2(0.1, -0.12), Vector2(-0.22, 0.4), Vector2(0.0, 0.4), Vector2(-0.14, 0.95), Vector2(0.26, 0.28), Vector2(0.04, 0.28), Vector2(0.2, -0.12)]), color)
		"shatter":
			for piece in [[Vector2(-0.5, -0.45), 0.6, -0.5], [Vector2(0.5, -0.4), 0.5, 0.6], [Vector2(-0.35, 0.5), 0.45, -2.4], [Vector2(0.45, 0.5), 0.55, 2.3]]:
				_poly_r(ci, center + piece[0] * u, u * piece[1], [Vector2(0, -0.8), Vector2(0.35, 0.4), Vector2(-0.35, 0.4)], piece[2], color)
			_snowflake(ci, center, u * 0.38, light)
		"bloodbath":
			for drop in [[Vector2(-0.45, -0.25), 0.55], [Vector2(0.42, -0.35), 0.5], [Vector2(0.0, 0.35), 0.7]]:
				draw(ci, "drop", center + drop[0] * u, size * drop[1], color, bg)
		_:
			ci.draw_circle(center, 0.6 * u, color)


# --- Shared shapes -------------------------------------------------------------

static func _fist(ci: CanvasItem, c: Vector2, u: float, color: Color, bg: Color) -> void:
	# Wrist, the back of the hand, a row of knuckles, and the thumb across the front.
	ci.draw_rect(Rect2(c + Vector2(-0.5, 0.55) * u, Vector2(1.0, 0.4) * u), color.darkened(0.3))
	ci.draw_rect(Rect2(c + Vector2(-0.82, -0.45) * u, Vector2(1.64, 1.05) * u), color)
	for x in [-0.6, -0.2, 0.2, 0.6]:
		ci.draw_circle(c + Vector2(x, -0.5) * u, 0.24 * u, color)
	for x in [-0.4, 0.0, 0.4]:
		ci.draw_line(c + Vector2(x, -0.55) * u, c + Vector2(x, -0.05) * u, bg, 0.09 * u)
	ci.draw_line(c + Vector2(-0.72, 0.22) * u, c + Vector2(0.2, 0.22) * u, bg, 0.12 * u)


static func _heart(ci: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	ci.draw_circle(c + Vector2(-0.32, -0.22) * u, 0.38 * u, color)
	ci.draw_circle(c + Vector2(0.32, -0.22) * u, 0.38 * u, color)
	ci.draw_colored_polygon(_points(c, u, [Vector2(-0.68, -0.1), Vector2(0.68, -0.1), Vector2(0, 0.82)]), color)


static func _shield(ci: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	var outline := [Vector2(-0.72, -0.8), Vector2(0.72, -0.8), Vector2(0.72, 0.0), Vector2(0, 0.88), Vector2(-0.72, 0.0)]
	ci.draw_colored_polygon(_points(c, u, outline), color)
	var inner: Array = outline.map(func(p: Vector2) -> Vector2: return p * 0.55)
	ci.draw_colored_polygon(_points(c, u, inner), color.darkened(0.3))


static func _boot(ci: CanvasItem, c: Vector2, u: float, color: Color, bg: Color) -> void:
	ci.draw_colored_polygon(_points(c, u, [Vector2(-0.4, -0.85), Vector2(0.08, -0.85), Vector2(0.08, 0.15), Vector2(0.72, 0.3), Vector2(0.82, 0.78), Vector2(-0.4, 0.78)]), color)
	ci.draw_line(c + Vector2(-0.4, 0.52) * u, c + Vector2(0.8, 0.52) * u, bg, 0.1 * u)


static func _skull(ci: CanvasItem, c: Vector2, u: float, color: Color, bg: Color) -> void:
	ci.draw_circle(c + Vector2(0, -0.15) * u, 0.64 * u, color)
	ci.draw_rect(Rect2(c + Vector2(-0.36, 0.2) * u, Vector2(0.72, 0.55) * u), color)
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(0.25 * side, -0.12) * u, 0.17 * u, bg)
	for x in [-0.16, 0.0, 0.16]:
		ci.draw_line(c + Vector2(x, 0.48) * u, c + Vector2(x, 0.75) * u, bg, 0.07 * u)


## A boxing glove, turned by angle (radians).
static func _glove(ci: CanvasItem, c: Vector2, u: float, angle: float, color: Color, bg: Color) -> void:
	var body := [Vector2(-0.62, -0.15), Vector2(0.62, -0.15), Vector2(0.62, 0.45), Vector2(-0.62, 0.45)]
	_poly_r(ci, c, u, body, angle, color)
	ci.draw_circle(c + Vector2(0.02, -0.15).rotated(angle) * u, 0.62 * u, color)
	ci.draw_circle(c + Vector2(-0.62, 0.12).rotated(angle) * u, 0.26 * u, color.darkened(0.12))
	_poly_r(ci, c, u, [Vector2(-0.48, 0.45), Vector2(0.48, 0.45), Vector2(0.44, 0.9), Vector2(-0.44, 0.9)], angle, color.darkened(0.35))
	_line_r(ci, c, u, Vector2(-0.46, 0.55), Vector2(0.46, 0.55), angle, bg, 0.07)
	ci.draw_circle(c + Vector2(0.2, -0.42).rotated(angle) * u, 0.17 * u, color.lightened(0.3))


static func _foot(ci: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	ci.draw_colored_polygon(_ellipse(c + Vector2(0, 0.08) * u, 0.24 * u, 0.4 * u), color)
	for toe in [Vector2(-0.16, -0.42), Vector2(0.0, -0.48), Vector2(0.15, -0.42)]:
		ci.draw_circle(c + toe * u, 0.08 * u, color)


static func _snowflake(ci: CanvasItem, c: Vector2, u: float, color: Color) -> void:
	for i in 6:
		var dir := Vector2.from_angle(TAU * i / 6.0 - PI / 2.0)
		ci.draw_line(c, c + dir * 0.9 * u, color, 0.13 * u)
		var branch := c + dir * 0.52 * u
		for turn in [-0.75, 0.75]:
			ci.draw_line(branch, branch + dir.rotated(turn) * 0.3 * u, color, 0.1 * u)
	ci.draw_circle(c, 0.16 * u, color.lightened(0.3))


# --- Helpers -------------------------------------------------------------------

static func _points(c: Vector2, u: float, points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(c + p * u)
	return result


static func _poly_r(ci: CanvasItem, c: Vector2, u: float, points: Array, angle: float, color: Color) -> void:
	var result := PackedVector2Array()
	for p: Vector2 in points:
		result.append(c + p.rotated(angle) * u)
	ci.draw_colored_polygon(result, color)


static func _line_r(ci: CanvasItem, c: Vector2, u: float, a: Vector2, b: Vector2, angle: float, color: Color, width: float) -> void:
	ci.draw_line(c + a.rotated(angle) * u, c + b.rotated(angle) * u, color, width * u)


static func _ellipse(c: Vector2, rx: float, ry: float, steps := 20) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		result.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return result


static func _star(c: Vector2, outer: float, inner: float, tips: int, rotation: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in tips * 2:
		var radius := outer if i % 2 == 0 else inner
		result.append(c + Vector2.from_angle(rotation + PI * i / tips) * radius)
	return result
