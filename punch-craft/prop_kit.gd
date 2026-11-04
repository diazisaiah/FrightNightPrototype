class_name PropKit
extends RefCounted
## Batched set dressing (2026-11-04, the places update): every box added is
## kept as a transform under its material, and flush() draws each material as
## one MultiMesh, so a whole hall of stone, candles and banners costs a few
## draw calls on a phone. Materials are shared by color, so pieces built in
## different places still batch together.
##   var kit := PropKit.new()
##   kit.box(size, pos, kit.stone(color)); kit.pillar(...); kit.flush(parent)

var _boxes := {}  # Material -> Array[Transform3D]
var _materials := {}


func box(size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	if not _boxes.has(material):
		var list: Array[Transform3D] = []
		_boxes[material] = list
	(_boxes[material] as Array[Transform3D]).append(Scenery._box_transform(size, pos, rot))


## A box placed in a frame (a node-free transform), for props built in local space.
func box_in(frame: Transform3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	if not _boxes.has(material):
		var list: Array[Transform3D] = []
		_boxes[material] = list
	(_boxes[material] as Array[Transform3D]).append(frame * Scenery._box_transform(size, pos, rot))


func flush(parent: Node3D) -> void:
	for material in _boxes:
		Scenery._box_batch(parent, material, _boxes[material])
	_boxes.clear()


# --- Shared materials ---------------------------------------------------------------

func stone(color: Color) -> Material:
	return _shared("stone %s" % color, func() -> Material: return Look.block_material(color))


func bricks(color: Color) -> Material:
	return _shared("bricks %s" % color, func() -> Material: return Look.patterned_material(color, Look.bricks()))


func tiles(color: Color) -> Material:
	return _shared("tiles %s" % color, func() -> Material: return Look.patterned_material(color, Look.tiles()))


func metal(color: Color, metallic := 0.7) -> Material:
	return _shared("metal %s %s" % [color, metallic], func() -> Material: return Look.block_material(color, metallic))


func glow(color: Color, energy := 4.0) -> Material:
	return _shared("glow %s %s" % [color, energy], func() -> Material:
		var material := Enemy._glow_material(color)
		material.emission_energy_multiplier = energy
		return material)


func _shared(key: String, make: Callable) -> Material:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]


# --- Pieces -------------------------------------------------------------------------
# Each takes a frame: its origin on the floor, -Z facing the room's middle.

## A square stone pillar with a base and a capital.
func pillar(frame: Transform3D, height: float, width: float, color: Color) -> void:
	var body := bricks(color)
	var trim := stone(color.darkened(0.25))
	box_in(frame, Vector3(width + 0.3, 0.4, width + 0.3), Vector3(0, 0.2, 0), trim)
	box_in(frame, Vector3(width, height - 0.8, width), Vector3(0, height / 2.0, 0), body)
	box_in(frame, Vector3(width + 0.3, 0.4, width + 0.3), Vector3(0, height - 0.2, 0), trim)


## A hanging banner on a wooden pole, its cloth in color with a darker hem
## and a sigil band in trim.
func banner(frame: Transform3D, width: float, length: float, color: Color, trim: Color) -> void:
	var cloth := stone(color)
	box_in(frame, Vector3(width + 0.3, 0.09, 0.09), Vector3(0, 0, 0), stone(Color(0.16, 0.1, 0.06)))
	box_in(frame, Vector3(width, length, 0.04), Vector3(0, -length / 2.0, 0), cloth)
	box_in(frame, Vector3(width * 0.6, 0.25, 0.04), Vector3(0, -length - 0.12, 0), cloth)
	box_in(frame, Vector3(width, 0.08, 0.05), Vector3(0, -length * 0.3, 0), stone(trim))
	box_in(frame, Vector3(0.18, 0.18, 0.05), Vector3(0, -length * 0.55, 0), stone(trim), Vector3(0, 0, PI / 4))


## A few candles of different heights on the floor or a ledge (glowing tips,
## no light: lights are budgeted separately).
func candles(frame: Transform3D, rng: RandomNumberGenerator, count: int, flame: Color) -> void:
	var wax := stone(Color(0.82, 0.78, 0.66))
	var tip := glow(flame.lightened(0.3), 5.0)
	for i in count:
		var spot := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.2, 0.2))
		var h := rng.randf_range(0.12, 0.42)
		box_in(frame, Vector3(0.07, h, 0.07), spot + Vector3(0, h / 2.0, 0), wax)
		box_in(frame, Vector3(0.035, 0.07, 0.035), spot + Vector3(0, h + 0.04, 0), tip)


## An upright coffin leaning on a wall, lid on.
func coffin(frame: Transform3D, wood: Color) -> void:
	var dark := stone(wood.darkened(0.35))
	var lid := stone(wood)
	box_in(frame, Vector3(0.72, 1.9, 0.38), Vector3(0, 1.0, 0), dark, Vector3(-0.08, 0, 0))
	box_in(frame, Vector3(0.62, 1.8, 0.06), Vector3(0, 1.0, -0.21), lid, Vector3(-0.08, 0, 0))
	box_in(frame, Vector3(0.82, 0.06, 0.06), Vector3(0, 1.45, -0.26), stone(Color(0.5, 0.4, 0.22)), Vector3(-0.08, 0, 0))


## Stepped stone stands running along frame's X, length long: tiers rising
## away from the room (along +Z), each depth deep and rise high. Returns the
## spots (frames, facing -Z) where spectators stand, spacing apart.
## With pews, each tier gets a wooden backrest (the chapel).
func stands(frame: Transform3D, length: float, tiers: int, depth: float, rise: float, color: Color, spacing := 1.15, pews := false) -> Array[Transform3D]:
	var seats: Array[Transform3D] = []
	var step := stone(color)
	var lip := stone(color.darkened(0.3))
	for tier in tiers:
		var h := rise * (tier + 1)
		var z := depth * (tier + 0.5)
		box_in(frame, Vector3(length, h, depth), Vector3(0, h / 2.0, z), step)
		box_in(frame, Vector3(length, 0.08, 0.12), Vector3(0, h + 0.04, z - depth / 2.0 + 0.06), lip)
		if pews:
			box_in(frame, Vector3(length, 0.7, 0.08), Vector3(0, h + 0.35, z + depth / 2.0 - 0.1), lip)
			box_in(frame, Vector3(length, 0.06, 0.16), Vector3(0, h + 0.72, z + depth / 2.0 - 0.1), step)
		var count := int(length / spacing)
		for i in count:
			var x := -length / 2.0 + spacing * (i + 0.5)
			seats.append(frame * Transform3D(Basis.IDENTITY, Vector3(x, h, z + 0.1)))
	return seats


## A fire bowl on a short iron stand (the flame itself is Look.flame).
func brazier(frame: Transform3D, iron_color := Color(0.1, 0.09, 0.1)) -> Vector3:
	var iron := metal(iron_color)
	box_in(frame, Vector3(0.14, 1.0, 0.14), Vector3(0, 0.5, 0), iron)
	box_in(frame, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), iron)
	box_in(frame, Vector3(0.7, 0.2, 0.7), Vector3(0, 1.1, 0), iron)
	box_in(frame, Vector3(0.5, 0.06, 0.5), Vector3(0, 1.22, 0), stone(Color(0.15, 0.06, 0.03)))
	return frame * Vector3(0, 1.32, 0)


# --- Graveyard pieces (the Gravedigger Division) ------------------------------------

## Three shared gravestone tones, so a whole graveyard batches into a few
## draw calls (Scenery.gravestone makes a material per stone).
func grave_tone(index: int) -> Material:
	return stone([Scenery.STONE.darkened(0.08), Scenery.STONE.darkened(0.25).lerp(Scenery.MOSS, 0.2), Scenery.STONE.darkened(0.4)][index % 3])


## A small walk-through gravestone, kind 0-5 like Scenery.gravestone, with its
## dirt mound in front (+Z).
func grave(frame: Transform3D, kind: int, tone: int) -> void:
	var rock := grave_tone(tone)
	var dark := grave_tone(tone + 2)
	match kind:
		0:
			box_in(frame, Vector3(0.62, 0.8, 0.16), Vector3(0, 0.4, 0), rock)
			box_in(frame, Vector3(0.48, 0.12, 0.16), Vector3(0, 0.86, 0), rock)
			box_in(frame, Vector3(0.3, 0.08, 0.16), Vector3(0, 0.96, 0), rock)
			box_in(frame, Vector3(0.36, 0.3, 0.02), Vector3(0, 0.52, 0.08), dark)
		1:
			box_in(frame, Vector3(0.4, 0.2, 0.3), Vector3(0, 0.1, 0), rock)
			box_in(frame, Vector3(0.14, 1.2, 0.14), Vector3(0, 0.8, 0), rock)
			box_in(frame, Vector3(0.62, 0.14, 0.14), Vector3(0, 1.08, 0), rock)
		2:
			box_in(frame, Vector3(0.55, 0.22, 0.55), Vector3(0, 0.11, 0), dark)
			box_in(frame, Vector3(0.28, 1.2, 0.28), Vector3(0, 0.8, 0), rock)
			box_in(frame, Vector3(0.18, 0.18, 0.18), Vector3(0, 1.48, 0), rock, Vector3(0, PI / 4, 0))
		3:
			box_in(frame, Vector3(0.6, 0.5, 0.15), Vector3(0, 0.25, 0), rock)
			box_in(frame, Vector3(0.38, 0.28, 0.15), Vector3(-0.1, 0.62, 0), rock, Vector3(0, 0, 0.4))
			box_in(frame, Vector3(0.4, 0.12, 0.3), Vector3(0.1, 0.06, 0.4), rock, Vector3(0, 0.6, 0.2))
		4:
			box_in(frame, Vector3(0.34, 0.24, 0.26), Vector3(0, 0.12, 0), dark)
			box_in(frame, Vector3(0.12, 1.3, 0.12), Vector3(0, 0.88, 0), rock)
			box_in(frame, Vector3(0.56, 0.12, 0.12), Vector3(0, 1.18, 0), rock)
			for i in 8:
				var a := TAU * i / 8.0
				box_in(frame, Vector3(0.08, 0.08, 0.1), Vector3(cos(a) * 0.2, 1.18 + sin(a) * 0.2, 0), rock)
		_:
			box_in(frame, Vector3(0.7, 0.45, 1.3), Vector3(0, 0.225, 0.5), rock)
			box_in(frame, Vector3(0.8, 0.08, 1.4), Vector3(0, 0.49, 0.5), dark)
	if kind != 5:
		box_in(frame, Vector3(0.75, 0.12, 1.4), Vector3(0, 0.03, 0.85), stone(Scenery.DIRT))


## A family plot: a low stone curb round w x d (walk-through), dirt inside,
## and rows of graves facing +Z.
func plot(frame: Transform3D, w: float, d: float, rng: RandomNumberGenerator) -> void:
	var curb := grave_tone(1)
	box_in(frame, Vector3(w, 0.06, d), Vector3(0, 0.02, 0), stone(Scenery.DIRT.lightened(0.08)))
	for side in [-1.0, 1.0]:
		box_in(frame, Vector3(w + 0.3, 0.3, 0.3), Vector3(0, 0.15, side * d / 2.0), curb)
		box_in(frame, Vector3(0.3, 0.3, d), Vector3(side * w / 2.0, 0.15, 0), curb)
		box_in(frame, Vector3(0.45, 0.6, 0.45), Vector3(side * w / 2.0, 0.3, -d / 2.0), curb)
		box_in(frame, Vector3(0.3, 0.2, 0.3), Vector3(side * w / 2.0, 0.7, -d / 2.0), grave_tone(0))
	var columns := maxi(1, int(w / 1.4))
	var rows := maxi(1, int(d / 2.4))
	for row in rows:
		for column in columns:
			if rng.randf() < 0.15:
				continue
			var x := -w / 2.0 + w * (column + 0.5) / columns
			var z := -d / 2.0 + 0.5 + row * 2.4
			var tilt := Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.08, 0.08))
			grave(frame * Transform3D(Basis.from_euler(tilt), Vector3(x, 0, z)), rng.randi_range(0, 4), rng.randi_range(0, 2))


## A big, simple block-man statue on a stepped plinth, standing straight
## with fists at his sides; about 4.6 m. All square blocks, no fiddly angles
## (the weeping angels read as a mess at night, 2026-11-04).
func block_man(frame: Transform3D, tone := 0) -> void:
	var rock := grave_tone(tone)
	var dark := grave_tone(tone + 2)
	box_in(frame, Vector3(1.9, 0.3, 1.9), Vector3(0, 0.15, 0), dark)
	box_in(frame, Vector3(1.5, 0.8, 1.5), Vector3(0, 0.7, 0), rock)
	box_in(frame, Vector3(1.7, 0.15, 1.7), Vector3(0, 1.17, 0), dark)
	box_in(frame, Vector3(0.8, 0.3, 0.04), Vector3(0, 0.75, -0.76), dark)
	var base := 1.25
	for side in [-1.0, 1.0]:
		box_in(frame, Vector3(0.42, 0.18, 0.62), Vector3(side * 0.27, base + 0.09, -0.06), rock)
		box_in(frame, Vector3(0.38, 1.2, 0.42), Vector3(side * 0.27, base + 0.78, 0), rock)
	box_in(frame, Vector3(0.96, 0.35, 0.5), Vector3(0, base + 1.5, 0), dark)
	box_in(frame, Vector3(1.1, 1.05, 0.58), Vector3(0, base + 2.2, 0), rock)
	box_in(frame, Vector3(1.4, 0.32, 0.6), Vector3(0, base + 2.6, 0), rock)
	for side in [-1.0, 1.0]:
		box_in(frame, Vector3(0.32, 1.1, 0.36), Vector3(side * 0.74, base + 1.95, 0), rock)
		box_in(frame, Vector3(0.38, 0.36, 0.42), Vector3(side * 0.74, base + 1.25, 0), dark)
	box_in(frame, Vector3(0.3, 0.2, 0.3), Vector3(0, base + 2.85, 0), rock)
	box_in(frame, Vector3(0.62, 0.66, 0.6), Vector3(0, base + 3.27, 0), rock)
	box_in(frame, Vector3(0.66, 0.1, 0.64), Vector3(0, base + 3.25, 0), dark)


## A tall obelisk on a stepped base; about 5 m.
func obelisk(frame: Transform3D, tone := 0) -> void:
	var rock := grave_tone(tone)
	var dark := grave_tone(tone + 2)
	box_in(frame, Vector3(1.6, 0.3, 1.6), Vector3(0, 0.15, 0), dark)
	box_in(frame, Vector3(1.2, 0.5, 1.2), Vector3(0, 0.55, 0), rock)
	box_in(frame, Vector3(0.7, 3.6, 0.7), Vector3(0, 2.6, 0), rock)
	box_in(frame, Vector3(0.52, 0.52, 0.52), Vector3(0, 4.55, 0), rock, Vector3(PI / 4, 0, PI / 4))
	box_in(frame, Vector3(0.8, 0.12, 0.8), Vector3(0, 0.86, 0), dark)
	box_in(frame, Vector3(0.4, 0.5, 0.02), Vector3(0, 1.6, -0.36), dark)


## A big dead oak: a thick trunk, roots, and heavy crooked boughs.
func oak(frame: Transform3D, rng: RandomNumberGenerator, height := 6.0) -> void:
	var bark := stone(Scenery.BARK.lightened(0.06))
	var dark := stone(Scenery.BARK)
	var y := 0.0
	var x := 0.0
	var width := 0.75
	var band := 0
	while y < height * 0.6:
		var segment := rng.randf_range(0.6, 1.0)
		box_in(frame, Vector3(width, segment, width), Vector3(x, y + segment / 2.0, 0), bark if band % 2 == 0 else dark, Vector3(0, rng.randf() * 0.5, 0))
		y += segment
		x += rng.randf_range(-0.08, 0.08)
		width *= 0.9
		band += 1
	for i in 5:
		var a := TAU * i / 5.0 + rng.randf() * 0.5
		box_in(frame, Vector3(0.24, 0.24, 1.1), Vector3(cos(a) * 0.5, 0.1, sin(a) * 0.5), dark, Vector3(0.15, -a + PI / 2.0, 0))
	for i in rng.randi_range(4, 6):
		var yaw := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		var lean := rng.randf_range(0.55, 1.05)
		var length := rng.randf_range(1.8, 3.2)
		var base := Vector3(x, y * rng.randf_range(0.7, 1.0), 0)
		var bough := Transform3D(Basis.from_euler(Vector3(0, yaw, lean)), base)
		box_in(frame * bough, Vector3(0.22, length, 0.22), Vector3(0, length / 2.0, 0), bark)
		for t in 2:
			var twig := Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, rng.randf_range(-0.9, 0.9))), Vector3(0, length * rng.randf_range(0.55, 0.95), 0))
			var twig_length := length * rng.randf_range(0.35, 0.55)
			box_in(frame * bough * twig, Vector3(0.09, twig_length, 0.09), Vector3(0, twig_length / 2.0, 0), dark)


## An iron lantern post; returns where its glass is.
func lantern_post(frame: Transform3D, glass: Color) -> Vector3:
	var iron := metal(Scenery.IRON, 0.6)
	box_in(frame, Vector3(0.3, 0.3, 0.3), Vector3(0, 0.15, 0), grave_tone(2))
	box_in(frame, Vector3(0.1, 2.5, 0.1), Vector3(0, 1.45, 0), iron)
	box_in(frame, Vector3(0.6, 0.07, 0.07), Vector3(0.25, 2.62, 0), iron)
	var at := Vector3(0.5, 2.3, 0)
	box_in(frame, Vector3(0.28, 0.06, 0.28), at + Vector3(0, 0.22, 0), iron)
	box_in(frame, Vector3(0.24, 0.05, 0.24), at + Vector3(0, -0.2, 0), iron)
	box_in(frame, Vector3(0.17, 0.32, 0.17), at, glow(glass, 3.0))
	return frame * at


## A strip of flagstones from a to b (world space on the floor), width wide.
func path(a: Vector3, b: Vector3, width: float, rng: RandomNumberGenerator, colors := [Color(0.3, 0.29, 0.3), Color(0.24, 0.23, 0.24)]) -> void:
	var tones := [stone(colors[0]), stone(colors[1])]
	var along := b - a
	var length := along.length()
	var dir := along / length
	var across := dir.cross(Vector3.UP)
	var yaw := atan2(dir.x, dir.z)
	var t := 0.0
	while t < length:
		var lane := -width / 2.0 + 0.4
		while lane < width / 2.0:
			if rng.randf() < 0.88:
				var size := Vector3(rng.randf_range(0.55, 0.75), 0.05, rng.randf_range(0.55, 0.75))
				var spot := a + dir * (t + rng.randf_range(-0.05, 0.05)) + across * (lane + rng.randf_range(-0.06, 0.06))
				box(size, Vector3(spot.x, 0.02, spot.z), tones[rng.randi() % 2], Vector3(0, yaw + rng.randf_range(-0.12, 0.12), 0))
			lane += 0.8
		t += 0.8



# --- Stage and arena pieces ---------------------------------------------------------

## A skull facing -Z: cranium, jaw, two dark sockets and a nose.
func skull(frame: Transform3D, size: float, bone: Color, socket := Color(0.04, 0.04, 0.06)) -> void:
	var b := stone(bone)
	var d := stone(socket)
	box_in(frame, Vector3(1.0, 0.8, 0.9) * size, Vector3(0, 0.4, 0) * size, b)
	box_in(frame, Vector3(0.7, 0.25, 0.6) * size, Vector3(0, -0.08, -0.1) * size, b)
	for side in [-1.0, 1.0]:
		box_in(frame, Vector3(0.26, 0.22, 0.05) * size, Vector3(side * 0.22, 0.45, -0.46) * size, d)
	box_in(frame, Vector3(0.12, 0.14, 0.05) * size, Vector3(0, 0.22, -0.46) * size, d)


## A stained-glass window (facing -Z) w x h: a stone frame, a pointed top,
## a grid of glowing panes in colors, lead bars between them.
func stained_window(frame: Transform3D, w: float, h: float, colors: Array, rng: RandomNumberGenerator, energy := 1.3) -> void:
	var rim := stone(Color(0.32, 0.3, 0.34))
	var lead := stone(Color(0.05, 0.05, 0.06))
	box_in(frame, Vector3(w + 0.5, 0.35, 0.3), Vector3(0, -0.15, 0), rim)
	for side in [-1.0, 1.0]:
		box_in(frame, Vector3(0.25, h, 0.3), Vector3(side * (w / 2.0 + 0.12), h / 2.0, 0), rim)
		box_in(frame, Vector3(0.25, w * 0.75, 0.3), Vector3(side * w * 0.25, h + w * 0.25, 0), rim, Vector3(0, 0, side * 0.75))
	var columns := 3
	var rows := maxi(2, int(h / 0.9))
	var pw := w / columns
	var ph := h / rows
	for row in rows:
		for column in columns:
			var color: Color = colors[rng.randi() % colors.size()]
			box_in(frame, Vector3(pw - 0.06, ph - 0.06, 0.04), Vector3(-w / 2.0 + pw * (column + 0.5), ph * (row + 0.5), 0.02), glow(color, energy))
	for column in columns + 1:
		box_in(frame, Vector3(0.05, h, 0.06), Vector3(-w / 2.0 + pw * column, h / 2.0, -0.01), lead)
	for row in rows + 1:
		box_in(frame, Vector3(w, 0.05, 0.06), Vector3(0, ph * row, -0.01), lead)
	# The pointed head: one pane in the arch.
	box_in(frame, Vector3(w * 0.5, w * 0.35, 0.04), Vector3(0, h + w * 0.18, 0.02), glow(colors[0], energy))


## A heap of gold coins with a cup or two and a gem, about radius wide.
func treasure(frame: Transform3D, radius: float, rng: RandomNumberGenerator) -> void:
	var coin := metal(Color(0.95, 0.72, 0.25), 0.85)
	var dull := metal(Color(0.75, 0.55, 0.18), 0.8)
	var layers := 4
	for layer in layers:
		var r := radius * (1.0 - float(layer) / layers)
		var n := int(6 + r * 10)
		for i in n:
			var spot := Vector2.from_angle(rng.randf() * TAU) * r * sqrt(rng.randf())
			box_in(frame, Vector3(0.22, 0.06, 0.22), Vector3(spot.x, 0.04 + layer * 0.12, spot.y), coin if rng.randf() < 0.7 else dull, Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, 0))
	box_in(frame, Vector3(radius * 1.4, 0.3, radius * 1.4), Vector3(0, 0.12, 0), dull, Vector3(0, PI / 4, 0))
	for i in 2:
		var spot := Vector2.from_angle(rng.randf() * TAU) * radius * 0.5
		box_in(frame, Vector3(0.1, 0.25, 0.1), Vector3(spot.x, 0.55, spot.y), coin)
		box_in(frame, Vector3(0.22, 0.18, 0.22), Vector3(spot.x, 0.75, spot.y), coin)
	box_in(frame, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.6, 0), glow([Color(0.9, 0.1, 0.15), Color(0.2, 0.5, 1.0), Color(0.2, 0.9, 0.4)][rng.randi() % 3], 3.0), Vector3(PI / 4, PI / 4, 0))


## A gold chandelier hung from y top: a chain, two rings of candle arms with
## glowing tips (no light; budgeted separately).
func chandelier(frame: Transform3D, top: float, drop: float, radius: float) -> void:
	var gold := metal(Color(0.95, 0.72, 0.25), 0.85)
	var flame_tip := glow(Color(1.0, 0.75, 0.4), 5.0)
	box_in(frame, Vector3(0.06, drop, 0.06), Vector3(0, top - drop / 2.0, 0), metal(Color(0.15, 0.12, 0.08)))
	var y := top - drop
	box_in(frame, Vector3(0.3, 0.5, 0.3), Vector3(0, y, 0), gold)
	for ring in 2:
		var r := radius * (1.0 - ring * 0.45)
		var at: float = y - 0.2 + ring * 0.5
		var arms := 10 - ring * 4
		for i in arms:
			var a := TAU * i / arms
			box_in(frame, Vector3(0.12, 0.08, r), Vector3(cos(a) * r / 2.0, at, sin(a) * r / 2.0), gold, Vector3(0, -a + PI / 2.0, 0))
			box_in(frame, Vector3(0.1, 0.22, 0.1), Vector3(cos(a) * r, at + 0.1, sin(a) * r), stone(Color(0.85, 0.82, 0.72)))
			box_in(frame, Vector3(0.05, 0.08, 0.05), Vector3(cos(a) * r, at + 0.26, sin(a) * r), flame_tip)


## A rusted vat of glowing green sludge; returns its surface's centre.
func vat(frame: Transform3D, radius: float, sludge: Color) -> Vector3:
	var iron := metal(Color(0.2, 0.18, 0.14), 0.5)
	var band := metal(Color(0.32, 0.22, 0.12), 0.6)
	box_in(frame, Vector3(radius * 2.0, 1.1, radius * 2.0), Vector3(0, 0.55, 0), iron)
	box_in(frame, Vector3(radius * 2.0 + 0.08, 0.1, radius * 2.0 + 0.08), Vector3(0, 0.3, 0), band)
	box_in(frame, Vector3(radius * 2.0 + 0.08, 0.1, radius * 2.0 + 0.08), Vector3(0, 0.95, 0), band)
	box_in(frame, Vector3(radius * 1.8, 0.05, radius * 1.8), Vector3(0, 1.08, 0), glow(sludge, 2.5))
	box_in(frame, Vector3(0.18, 0.18, 0.18), Vector3(radius * 0.3, 1.14, -radius * 0.2), glow(sludge.lightened(0.3), 3.0))
	box_in(frame, Vector3(0.12, 0.12, 0.12), Vector3(-radius * 0.35, 1.12, radius * 0.25), glow(sludge.lightened(0.3), 3.0))
	return frame * Vector3(0, 1.1, 0)
