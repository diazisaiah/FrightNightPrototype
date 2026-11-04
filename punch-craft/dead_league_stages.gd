class_name DeadLeagueStages
## Each Dead League contender's own place round the same ring (2026-11-04,
## the places update): the ring, ropes and spotlight stay; the hall, its
## lighting and its crowd change. The crowd (Crowd) never fights.
## Budget for phones: everything static is batched by PropKit, at most six
## real lights (the rest of the flames only glow), no shadows on the web.
##   bellman: the Crypt hall      headless: the Bone Pit (open sky)
##   southpaw: the Gothic Chapel  plague_doctor: the Plague Tent
##   coffin_king: the Gold Hall (the True Coffin King too)

## The stands start this far out from the ring's middle; the low wall just
## inside them.
const START := 6.6
const WALL_AT := 6.25
const RISE := 0.5
const STAND_DEPTH := 1.2


## A stage for contender id round the ring centred at center: {"lights":
## flames to flicker, "crowd": Crowd, "bell": a swinging bell or null}. Empty
## when the contender has no stage (the arena falls back to the graveyard).
static func build(id: String, arena: Node3D, center: Vector3) -> Dictionary:
	match id:
		"bellman":
			return _bellman(arena, center)
		"headless":
			return _headless(arena, center)
		"southpaw":
			return _southpaw(arena, center)
		"plague_doctor":
			return _plague_doctor(arena, center)
		"coffin_king":
			return _coffin_king(arena, center)
	return {}


# --- Shared ---------------------------------------------------------------------------

## Lights the room as an indoor place: no sky, a flat dark background, the
## moon turned into a faint fill.
static func _indoors(arena: Node3D, ambient: Color, energy: float, fog: Color, fog_density: float) -> void:
	var env: Environment = (arena.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog.darkened(0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy * (1.25 if Settings.use_web_profile() else 1.0)
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.fog_sky_affect = 0.0
	var moon: DirectionalLight3D = arena.get_node("Moon")
	moon.light_color = ambient
	moon.light_energy = 0.22
	moon.shadow_enabled = false


## An open-air place: the night sky stays, tinted ambient and moon.
static func _outdoors(arena: Node3D, ambient: Color, energy: float, fog: Color, fog_density: float, moon_color: Color) -> void:
	var env: Environment = (arena.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = energy * (1.25 if Settings.use_web_profile() else 1.0)
	env.fog_light_color = fog
	env.fog_density = fog_density
	var moon: DirectionalLight3D = arena.get_node("Moon")
	moon.light_color = moon_color
	moon.light_energy = 0.55
	moon.shadow_enabled = false


## A frame on the floor at (x, z) whose -Z looks at target (flat).
static func _facing(pos: Vector3, target: Vector3) -> Transform3D:
	var look := Vector3(target.x - pos.x, 0, target.z - pos.z)
	return Transform3D(Basis.looking_at(look, Vector3.UP), pos)


## A frame at pos turned by angle round Y (its +Z then points along
## (sin angle, 0, cos angle)).
static func _turned(pos: Vector3, angle: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, angle), pos)


static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := Look.fire_light(color, energy, reach, false)
	light.position = pos
	parent.add_child(light)
	return light


## A box room round the ring: four walls (the back one behind the contender),
## an optional ceiling, and pillars down the side walls every 4.5 m.
static func _room(kit: PropKit, c: Vector3, half_w: float, back: float, front: float, height: float, wall: Material, ceiling: Material, pillar := Color.TRANSPARENT) -> void:
	var depth := front - back
	kit.box(Vector3(half_w * 2.0, height, 0.6), Vector3(0, height / 2.0, back), wall)
	kit.box(Vector3(half_w * 2.0, height, 0.6), Vector3(0, height / 2.0, front), wall)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.6, height, depth), Vector3(side * half_w, height / 2.0, (back + front) / 2.0), wall)
	if ceiling:
		kit.box(Vector3(half_w * 2.0, 0.5, depth), Vector3(0, height + 0.25, (back + front) / 2.0), ceiling)
	if pillar.a > 0.0:
		var z := back + 2.5
		while z < front - 1.0:
			for side in [-1.0, 1.0]:
				kit.pillar(Transform3D(Basis.IDENTITY, Vector3(side * (half_w - 0.55), 0, z)), height - 0.5, 0.8, pillar)
			z += 4.5


## Where each bay between the side pillars is: z values (for windows,
## banners, sconces).
static func _bays(back: float, front: float) -> Array[float]:
	var bays: Array[float] = []
	var z := back + 4.75
	while z < front - 2.0:
		bays.append(z)
		z += 4.5
	return bays


## The ring's surroundings every stage shares: stands on three sides (the
## back split by an aisle to the entrance) and two tiers behind you, a low
## wall round the floor (in stripes if look.stripe is set) with candles, a
## runner up the aisle, and four corner pieces with their lights (the back
## pair everywhere, the front pair on desktop). Returns the seats:
## {"back", "side", "front"}.
## look: stand, wall, cap, fire (Color), half_w, gate_z (float); optional
## stripe (Color), runner (Color), pews, candles (bool), corner ("brazier",
## "vat", "gold"), corner_light (Color).
static func _ringside(kit: PropKit, decor: Node3D, c: Vector3, look: Dictionary, rng: RandomNumberGenerator, lights: Array) -> Dictionary:
	var web := Settings.use_web_profile()
	var half_w: float = look.half_w
	var pews: bool = look.get("pews", false)
	var back_seats: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var length := half_w - 1.2 - 1.7
		back_seats.append_array(kit.stands(_turned(Vector3(side * (1.7 + length / 2.0), 0, c.z - START), PI), length, 3, STAND_DEPTH, RISE, look.stand, 1.15, pews))
	var side_seats: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		side_seats.append_array(kit.stands(_turned(Vector3(side * START, 0, c.z), side * PI / 2.0), START * 2.0 - 0.6, 3, STAND_DEPTH, RISE, look.stand, 1.15, pews))
	var front_seats: Array[Transform3D] = kit.stands(_turned(Vector3(0, 0, c.z + START), 0.0), START * 2.0 - 0.6, 2, STAND_DEPTH, RISE, look.stand, 1.15, pews)

	# The low wall, in 1 m pieces so it can be striped.
	var wall := kit.stone(look.wall)
	var stripe: Material = kit.stone(look.stripe) if look.has("stripe") else wall
	var cap := kit.stone(look.cap)
	var runs := [
		[Vector3(-WALL_AT, 0, c.z - WALL_AT), Vector3(-1.6, 0, c.z - WALL_AT)],
		[Vector3(1.6, 0, c.z - WALL_AT), Vector3(WALL_AT, 0, c.z - WALL_AT)],
		[Vector3(-WALL_AT, 0, c.z - WALL_AT), Vector3(-WALL_AT, 0, c.z + WALL_AT)],
		[Vector3(WALL_AT, 0, c.z - WALL_AT), Vector3(WALL_AT, 0, c.z + WALL_AT)],
		[Vector3(-WALL_AT, 0, c.z + WALL_AT), Vector3(WALL_AT, 0, c.z + WALL_AT)],
	]
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var length := a.distance_to(b)
		var pieces := maxi(1, roundi(length))
		var along := (b - a) / pieces
		var across_x := absf(along.x) > absf(along.z)
		for i in pieces:
			var mid := a + along * (i + 0.5)
			var size := Vector3(along.length() + 0.01, 0.9, 0.3) if across_x else Vector3(0.3, 0.9, along.length() + 0.01)
			kit.box(size, mid + Vector3(0, 0.45, 0), stripe if i % 2 == 1 else wall)
		var cap_size := Vector3(length, 0.1, 0.4) if across_x else Vector3(0.4, 0.1, length)
		kit.box(cap_size, (a + b) / 2.0 + Vector3(0, 0.95, 0), cap)
		if look.get("candles", true):
			for i in pieces:
				if rng.randf() < 0.5:
					kit.candles(Transform3D(Basis.IDENTITY, a + along * (i + 0.5) + Vector3(0, 1.0, 0)), rng, rng.randi_range(1, 3), look.fire)

	# The aisle runner.
	var aisle_from := c.z - WALL_AT
	var gate_z: float = look.gate_z
	if look.has("runner"):
		kit.box(Vector3(1.5, 0.02, aisle_from - gate_z), Vector3(0, 0.012, (aisle_from + gate_z) / 2.0), kit.stone(look.runner))

	# The corners.
	var corner_light: Color = look.get("corner_light", look.fire)
	for x in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var at := Vector3(x * 5.2, 0, c.z + zs * 5.2)
			var top: Vector3
			match look.get("corner", "brazier"):
				"vat":
					top = kit.vat(Transform3D(Basis.IDENTITY, at), 0.55, look.fire)
				"gold":
					top = kit.brazier(Transform3D(Basis.IDENTITY, at), Color(0.85, 0.64, 0.22))
					Look.flame(decor, top, 1.6, not web, look.fire)
				_:
					top = kit.brazier(Transform3D(Basis.IDENTITY, at))
					Look.flame(decor, top, 1.6, not web, look.fire)
			if zs < 0.0 or not web:
				lights.append(_light(decor, top + Vector3(0, 0.6, 0), corner_light, 2.2, 8.0))
	return {"back": back_seats, "side": side_seats, "front": front_seats}


## The crowd in the seats: the back stands first (they're in view), then the
## sides, then behind you. mix: [[scene, weight, size, big?], ...]; big
## kinds only on the top tier.
static func _crowd(decor: Node3D, c: Vector3, seats: Dictionary, mix: Array, rng: RandomNumberGenerator) -> Crowd:
	var crowd := Crowd.new()
	decor.add_child(crowd)
	var count := 22 if Settings.use_web_profile() else 40
	var picked: Array[Transform3D] = []
	picked.append_array(_spread(seats.back, int(count * 0.45)))
	picked.append_array(_spread(seats.side, int(count * 0.4)))
	picked.append_array(_spread(seats.front, count - picked.size()))
	_seat_crowd(crowd, picked, c, mix, count, rng, RISE * 2.5)
	crowd.finish()
	return crowd


## Fills the seats with the crowd, in order; big kinds only on high seats.
static func _seat_crowd(crowd: Crowd, seats: Array[Transform3D], center: Vector3, mix: Array, count: int, rng: RandomNumberGenerator, big_from := 1.2) -> void:
	var total := 0.0
	for kind in mix:
		total += float(kind[1])
	var taken := 0
	for seat in seats:
		if taken >= count:
			break
		var pick: Array = mix[0]
		var roll := rng.randf() * total
		for kind in mix:
			roll -= float(kind[1])
			if roll <= 0.0:
				pick = kind
				break
		var big: bool = pick.size() > 3 and pick[3]
		if big and seat.origin.y < big_from:
			pick = mix[0]
		var spot := seat.origin + Vector3(rng.randf_range(-0.15, 0.15), 0, 0)
		var frame := _facing(spot, center)
		frame.basis = frame.basis.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25))
		crowd.add(pick[0], frame, float(pick[2]) * rng.randf_range(0.94, 1.06))
		taken += 1


## Seats spread evenly through a list, so a small crowd still fills the stands
## instead of packing one end: keeps count of them, in order.
static func _spread(seats: Array[Transform3D], count: int) -> Array[Transform3D]:
	var picked: Array[Transform3D] = []
	if count <= 0 or seats.is_empty():
		return picked
	var step := maxf(1.0, float(seats.size()) / count)
	var i := 0.0
	while int(i) < seats.size() and picked.size() < count:
		picked.append(seats[int(i)])
		i += step
	return picked


## An arched doorway in the back wall at z, its opening glowing (fire, ghost
## light ...), optionally with a raised portcullis.
static func _gate(kit: PropKit, z: float, frame_color: Color, inside: Color, bars := true) -> void:
	kit.box(Vector3(3.4, 4.8, 0.06), Vector3(0, 2.4, z), kit.glow(inside, 0.7))
	var rim := kit.stone(frame_color)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.7, 5.4, 0.9), Vector3(side * 2.05, 2.7, z + 0.2), rim)
	kit.box(Vector3(4.8, 0.9, 0.9), Vector3(0, 5.45, z + 0.2), rim)
	kit.box(Vector3(0.7, 0.9, 0.95), Vector3(0, 5.45, z + 0.22), kit.stone(frame_color.lightened(0.1)))
	if bars:
		var iron := kit.metal(Color(0.09, 0.085, 0.09))
		for i in 9:
			kit.box(Vector3(0.08, 1.8, 0.08), Vector3(-1.6 + i * 0.4, 4.0, z + 0.12), iron)
		kit.box(Vector3(3.4, 0.1, 0.1), Vector3(0, 3.15, z + 0.12), iron)


# --- The Bellman: the Crypt hall ---------------------------------------------------

## Grey stone vaults (the Crypt's first tier), red banners, stands of
## zombies, skeletons and Hulks, a gate glowing with fire behind the Bellman
## and a great bronze bell hanging over it.
static func _bellman(arena: Node3D, c: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var decor: Node3D = arena.get_node("Decorations")
	var kit := PropKit.new()
	var wall := Color(0.25, 0.245, 0.255)
	var red := Color(0.45, 0.07, 0.06)
	var gold := Color(0.62, 0.46, 0.18)
	var fire := Color(1.0, 0.5, 0.2)
	_indoors(arena, Color(0.5, 0.44, 0.47), 0.95, Color(0.07, 0.045, 0.045), 0.016)
	(arena.get_node("Ground/Mesh") as MeshInstance3D).material_override = kit.tiles(Color(0.2, 0.19, 0.2))
	var half_w := 12.0
	var back := c.z - 12.5
	var front := c.z + 11.0
	var height := 9.5
	_room(kit, c, half_w, back, front, height, kit.bricks(wall), kit.stone(wall.darkened(0.45)), wall.lightened(0.04))
	var z := back + 2.5
	while z < front - 1.0:
		kit.box(Vector3(half_w * 2.0, 0.55, 0.55), Vector3(0, height - 0.25, z), kit.stone(wall.darkened(0.2)))
		z += 4.5
	for x in [-8.0, -4.0, 4.0, 8.0]:
		kit.pillar(Transform3D(Basis.IDENTITY, Vector3(x, 0, back + 0.55)), height - 0.5, 0.8, wall.lightened(0.04))
		kit.box(Vector3(0.55, 0.55, front - back), Vector3(x, height - 0.25, (back + front) / 2.0), kit.stone(wall.darkened(0.2)))
	var gate_z := back + 0.32
	_gate(kit, gate_z, wall.lightened(0.06), Color(0.32, 0.08, 0.02))
	var lights: Array = []
	lights.append(_light(decor, Vector3(0, 3.2, gate_z + 2.2), Color(1.0, 0.45, 0.15), 2.8, 10.0))
	for x in [-10.0, -6.0, 6.0, 10.0]:
		kit.banner(Transform3D(Basis.IDENTITY, Vector3(x, height - 1.2, back + 0.36)), 1.2, 3.4, red, gold)
	var iron := kit.metal(Color(0.09, 0.085, 0.09))
	for bay in _bays(back, front):
		for side in [-1.0, 1.0]:
			kit.banner(_turned(Vector3(side * (half_w - 0.34), height - 1.4, bay), -side * PI / 2.0), 1.1, 3.0, red, gold)
	z = back + 2.5
	while z < front - 1.0:
		for side in [-1.0, 1.0]:
			var sconce := Vector3(side * (half_w - 1.05), 3.2, z)
			kit.box(Vector3(0.3, 0.12, 0.3), sconce, iron)
			Look.flame(decor, sconce + Vector3(0, 0.15, 0), 1.0, false)
		z += 4.5
	for x in [-3.0, 3.0]:
		kit.coffin(_turned(Vector3(x, 0, back + 0.55), PI), Color(0.24, 0.15, 0.09))
	var seats := _ringside(kit, decor, c, {
		"stand": wall.darkened(0.15), "wall": wall.darkened(0.05), "cap": wall.lightened(0.1),
		"fire": fire, "half_w": half_w, "gate_z": gate_z, "runner": red.darkened(0.2),
	}, rng, lights)
	z = c.z - WALL_AT - 0.8
	while z > gate_z + 1.0:
		for side in [-1.0, 1.0]:
			kit.candles(Transform3D(Basis.IDENTITY, Vector3(side * 1.25, 0, z)), rng, rng.randi_range(2, 4), fire)
		z -= 1.4
	kit.flush(decor)
	var bell := _bell(decor, Vector3(0, height - 1.4, back + 2.4), kit)
	var crowd := _crowd(decor, c, seats, [
		["res://zombie.tscn", 5.0, 1.0],
		["res://skeleton.tscn", 4.0, 1.0],
		["res://hulk.tscn", 1.6, 0.85, true],
	], rng)
	return {"lights": lights, "crowd": crowd, "bell": bell}


# --- The Headless: the Bone Pit ------------------------------------------------------

## A sunken pit under the night sky in cold blue light: walls of bone brick
## with a frieze of skulls, skull columns burning with blue ghost-fire, rib
## arches over the aisle, the Headless's racks of collected heads, and a
## giant skull over a gate glowing blue. The crowd: every kind of skeleton.
static func _headless(arena: Node3D, c: Vector3) -> Dictionary:
	var web := Settings.use_web_profile()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4402
	var decor: Node3D = arena.get_node("Decorations")
	var kit := PropKit.new()
	var bone := Color(0.66, 0.63, 0.56)
	var bone_dark := Color(0.46, 0.44, 0.4)
	var blue := Color(0.3, 0.7, 1.0)
	_outdoors(arena, Color(0.36, 0.46, 0.72), 0.8, Color(0.04, 0.07, 0.15), 0.02, Color(0.55, 0.72, 1.0))
	Scenery.night_sky(decor, rng, Vector3(18, 30, -70))
	(arena.get_node("Ground/Mesh") as MeshInstance3D).material_override = kit.tiles(Color(0.2, 0.21, 0.25))
	var half_w := 12.0
	var back := c.z - 12.5
	var front := c.z + 11.0
	var height := 6.0
	_room(kit, c, half_w, back, front, height, kit.bricks(bone_dark), null)
	# The skull frieze along the top of every wall, facing in.
	var spacing := 1.25
	for side in [-1.0, 1.0]:
		var z := back + 1.0
		while z < front - 0.5:
			kit.skull(_turned(Vector3(side * (half_w - 0.45), height - 1.0, z), -side * PI / 2.0 + PI), 0.42, bone)
			z += spacing
	for wall_z in [back + 0.45, front - 0.45]:
		var x := -half_w + 1.0
		while x < half_w - 0.5:
			kit.skull(_turned(Vector3(x, height - 1.0, wall_z), 0.0 if wall_z < c.z else PI), 0.42, bone)
			x += spacing
	kit.box(Vector3(half_w * 2.0, 0.3, 0.9), Vector3(0, height + 0.15, back + 0.2), kit.stone(bone))
	kit.box(Vector3(half_w * 2.0, 0.3, 0.9), Vector3(0, height + 0.15, front - 0.2), kit.stone(bone))
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.9, 0.3, front - back), Vector3(side * (half_w - 0.2), height + 0.15, (back + front) / 2.0), kit.stone(bone))
	# Skull columns with blue fire, down the side walls and along the back.
	var columns: Array[Vector3] = []
	for bay in _bays(back, front):
		for side in [-1.0, 1.0]:
			columns.append(Vector3(side * (half_w - 0.9), 0, bay - 2.25))
	for x in [-8.0, 8.0]:
		columns.append(Vector3(x, 0, back + 0.9))
	for at in columns:
		kit.box(Vector3(1.0, 0.6, 1.0), at + Vector3(0, 0.3, 0), kit.stone(bone_dark))
		for k in 6:
			kit.skull(_turned(at + Vector3(0, 0.6 + k * 0.7, 0), k * 0.9), 0.65, bone if k % 2 == 0 else bone_dark)
		kit.box(Vector3(0.9, 0.15, 0.9), at + Vector3(0, 4.85, 0), kit.stone(bone_dark))
		Look.flame(decor, at + Vector3(0, 5.0, 0), 1.8, false, blue)
	# The gate behind the Headless, a giant skull over it with glowing eyes.
	var gate_z := back + 0.32
	_gate(kit, gate_z, bone_dark, Color(0.02, 0.06, 0.17), false)
	var big := _turned(Vector3(0, 6.2, back + 1.0), 0.0)
	kit.skull(big, 3.0, bone)
	for side in [-1.0, 1.0]:
		kit.box_in(big, Vector3(0.6, 0.5, 0.08), Vector3(side * 0.66, 1.35, -1.42), kit.glow(blue, 3.0))
	var lights: Array = []
	lights.append(_light(decor, Vector3(0, 3.2, gate_z + 2.2), blue, 2.6, 10.0))
	# Rib arches over the aisle.
	var bone_m := kit.stone(bone)
	for i in 4:
		var z := c.z - 7.3 - i * 1.25
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.28, 3.4, 0.28), Vector3(side * 1.9, 1.6, z), bone_m, Vector3(0, 0, side * 0.12))
			kit.box(Vector3(0.26, 2.0, 0.26), Vector3(side * 1.2, 3.85, z), bone_m, Vector3(0, 0, side * 0.75))
	kit.box(Vector3(0.4, 0.4, 5.0), Vector3(0, 4.4, c.z - 9.2), bone_m)
	# Racks of collected heads either side of the gate.
	var wood := kit.stone(Color(0.16, 0.12, 0.1))
	for side in [-1.0, 1.0]:
		var x: float = side * 4.0
		for shelf in 3:
			var y := 0.9 + shelf * 1.1
			kit.box(Vector3(2.6, 0.1, 0.6), Vector3(x, y, back + 0.7), wood)
			for k in 5:
				kit.skull(_turned(Vector3(x - 1.0 + k * 0.5, y + 0.05, back + 0.75), rng.randf_range(-0.3, 0.3)), 0.32, bone if rng.randf() < 0.6 else bone_dark)
		for post in [-1.35, 1.35]:
			kit.box(Vector3(0.12, 3.4, 0.12), Vector3(x + post, 1.7, back + 0.7), wood)
	var seats := _ringside(kit, decor, c, {
		"stand": Color(0.36, 0.36, 0.4), "wall": bone_dark, "cap": bone,
		"fire": blue, "half_w": half_w, "gate_z": gate_z, "runner": Color(0.1, 0.12, 0.2),
	}, rng, lights)
	# Bones scattered on the pit floor beyond the wall.
	for i in (30 if web else 60):
		var at := Vector3(rng.randf_range(-half_w + 1.0, half_w - 1.0), 0, rng.randf_range(back + 1.0, front - 1.0))
		if absf(at.x) < START + 3.6 and absf(at.z - c.z) < START + 3.6:
			continue
		kit.box(Vector3(rng.randf_range(0.3, 0.7), 0.07, 0.09), at + Vector3(0, 0.04, 0), bone_m, Vector3(0, rng.randf() * TAU, 0))
	kit.flush(decor)
	Scenery.wisps(decor, c + Vector3(0, 3.0, 0), Vector3(half_w, 2.0, 10.0), blue, 16 if web else 36)
	var crowd := _crowd(decor, c, seats, [
		["res://skeleton.tscn", 5.0, 1.0],
		["res://sniper.tscn", 3.0, 1.0],
		["res://shieldbearer.tscn", 2.5, 1.0],
		["res://bulwark.tscn", 1.2, 0.9, true],
	], rng)
	return {"lights": lights, "crowd": crowd, "bell": null}


# --- Sister Southpaw: the Gothic Chapel ------------------------------------------------

## A tall chapel in violet gloom: pointed rib vaults, stained-glass windows
## glowing down both sides and a rose window behind her, an altar under
## organ pipes, and pews instead of stands, full of wraiths, banshees,
## priests and liches.
static func _southpaw(arena: Node3D, c: Vector3) -> Dictionary:
	var web := Settings.use_web_profile()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4403
	var decor: Node3D = arena.get_node("Decorations")
	var kit := PropKit.new()
	var wall := Color(0.3, 0.29, 0.34)
	var purple := Color(0.32, 0.1, 0.38)
	var silver := Color(0.7, 0.7, 0.76)
	var candle := Color(0.85, 0.7, 1.0)
	var glass := [Color(0.85, 0.15, 0.2), Color(0.2, 0.35, 1.0), Color(0.55, 0.2, 0.9), Color(1.0, 0.75, 0.25), Color(0.2, 0.75, 0.45)]
	_indoors(arena, Color(0.46, 0.42, 0.6), 0.9, Color(0.05, 0.035, 0.08), 0.013)
	(arena.get_node("Ground/Mesh") as MeshInstance3D).material_override = kit.tiles(Color(0.24, 0.22, 0.27))
	var half_w := 12.0
	var back := c.z - 12.5
	var front := c.z + 11.0
	var height := 15.0
	_room(kit, c, half_w, back, front, height, kit.bricks(wall), kit.stone(wall.darkened(0.55)), wall.lightened(0.05))
	# Pointed ribs across the vault, one per bay.
	var rib := kit.stone(wall.darkened(0.15))
	var z := back + 2.5
	while z < front - 1.0:
		for side in [-1.0, 1.0]:
			kit.box(Vector3(12.4, 0.5, 0.5), Vector3(side * 5.75, 12.6, z), rib, Vector3(0, 0, -side * 0.3))
		z += 4.5
	# Stained glass down both sides.
	for bay in _bays(back, front):
		for side in [-1.0, 1.0]:
			kit.stained_window(_turned(Vector3(side * (half_w - 0.32), 4.6, bay), side * PI / 2.0), 2.0, 5.2, glass, rng)
	# The rose window over the altar.
	var rose := Vector3(0, 10.4, back + 0.33)
	var rim := kit.stone(Color(0.32, 0.3, 0.34))
	for i in 12:
		var a := TAU * i / 12.0
		kit.box(Vector3(0.75, 0.75, 0.04), rose + Vector3(cos(a) * 1.55, sin(a) * 1.55, 0.02), kit.glow(glass[i % glass.size()], 1.4), Vector3(0, 0, a))
		kit.box(Vector3(0.18, 0.9, 0.12), rose + Vector3(cos(a) * 2.25, sin(a) * 2.25, 0), rim, Vector3(0, 0, a))
		kit.box(Vector3(0.1, 1.4, 0.08), rose + Vector3(cos(a + PI / 12.0) * 1.2, sin(a + PI / 12.0) * 1.2, 0.01), rim, Vector3(0, 0, a + PI / 12.0))
	kit.box(Vector3(0.9, 0.9, 0.04), rose + Vector3(0, 0, 0.02), kit.glow(glass[3], 1.6), Vector3(0, 0, PI / 4))
	# The altar on its steps, organ pipes behind.
	var step := kit.stone(wall.lightened(0.08))
	var altar_z := back + 3.0
	kit.box(Vector3(7.0, 0.25, 3.6), Vector3(0, 0.125, altar_z), step)
	kit.box(Vector3(5.6, 0.25, 2.8), Vector3(0, 0.375, altar_z - 0.2), step)
	kit.box(Vector3(3.0, 1.0, 1.1), Vector3(0, 1.0, altar_z - 0.3), kit.stone(Color(0.8, 0.78, 0.74)))
	kit.box(Vector3(3.2, 0.06, 1.3), Vector3(0, 1.53, altar_z - 0.3), kit.stone(purple))
	kit.box(Vector3(1.0, 0.9, 0.04), Vector3(0, 1.05, altar_z + 0.27), kit.stone(purple))
	kit.box(Vector3(0.6, 0.6, 0.08), Vector3(0, 2.2, altar_z - 0.5), kit.metal(Color(0.95, 0.75, 0.3), 0.8), Vector3(0, 0, PI / 4))
	for side in [-1.0, 1.0]:
		kit.candles(Transform3D(Basis.IDENTITY, Vector3(side * 1.1, 1.55, altar_z - 0.3)), rng, 4, candle)
	kit.box(Vector3(8.6, 2.6, 1.2), Vector3(0, 1.3, back + 0.9), kit.stone(Color(0.22, 0.14, 0.09)))
	var pipe := kit.metal(Color(0.72, 0.62, 0.42), 0.8)
	for i in 15:
		var x := -3.9 + i * 0.56
		var h := 4.0 + (1.0 - absf(x) / 4.2) * 5.0
		kit.box(Vector3(0.4, h, 0.4), Vector3(x, 2.6 + h / 2.0, back + 0.9), pipe)
		kit.box(Vector3(0.2, 0.12, 0.05), Vector3(x, 3.2, back + 1.12), kit.stone(Color(0.05, 0.04, 0.05)))
	var lights: Array = []
	lights.append(_light(decor, Vector3(0, 3.0, altar_z + 1.5), candle, 2.6, 11.0))
	if not web:
		lights.append(_light(decor, Vector3(-half_w + 2.0, 7.0, c.z), Color(0.35, 0.45, 1.0), 1.4, 12.0))
		lights.append(_light(decor, Vector3(half_w - 2.0, 7.0, c.z), Color(1.0, 0.35, 0.45), 1.4, 12.0))
	# Banners between the windows' tops.
	for bay in _bays(back, front):
		for side in [-1.0, 1.0]:
			kit.banner(_turned(Vector3(side * (half_w - 0.34), 14.0, bay - 2.25), -side * PI / 2.0), 0.8, 2.6, purple, silver)
	var seats := _ringside(kit, decor, c, {
		"stand": Color(0.25, 0.16, 0.1), "wall": wall, "cap": wall.lightened(0.12),
		"fire": candle, "half_w": half_w, "gate_z": altar_z + 1.8, "runner": purple.darkened(0.2),
		"pews": true,
	}, rng, [])
	kit.flush(decor)
	var crowd := _crowd(decor, c, seats, [
		["res://wraith.tscn", 3.0, 1.0],
		["res://banshee.tscn", 2.0, 1.0],
		["res://priest.tscn", 3.0, 1.0],
		["res://lich.tscn", 2.5, 1.0],
	], rng)
	return {"lights": lights, "crowd": crowd, "bell": null}


# --- The Plague Doctor: the Plague Tent ---------------------------------------------

## Inside a rotting big top in the Carnival's sick green and purple: striped
## canvas walls and roof, rigging from the peak, green lanterns, pennants,
## bubbling vats at the corners and a curtain behind the Doctor. The crowd:
## ghouls and the bigger zombies.
static func _plague_doctor(arena: Node3D, c: Vector3) -> Dictionary:
	var web := Settings.use_web_profile()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4404
	var decor: Node3D = arena.get_node("Decorations")
	var kit := PropKit.new()
	var green := Color(0.28, 0.38, 0.13)
	var purple := Color(0.3, 0.13, 0.3)
	var cream := Color(0.62, 0.6, 0.45)
	var sludge := Color(0.55, 1.0, 0.2)
	_indoors(arena, Color(0.44, 0.52, 0.34), 0.95, Color(0.06, 0.08, 0.03), 0.016)
	(arena.get_node("Ground/Mesh") as MeshInstance3D).material_override = kit.stone(Color(0.3, 0.25, 0.15))
	var radius := 15.8
	var wall_h := 6.0
	var peak := 15.0
	var sides := 20
	var stripes := [kit.stone(green), kit.stone(purple)]
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var at := c + Vector3(cos(a), 0, sin(a)) * radius
		var frame := _facing(at, c)
		var width := TAU * radius / sides + 0.25
		kit.box_in(frame, Vector3(width, wall_h, 0.2), Vector3(0, wall_h / 2.0, 0), stripes[i % 2])
		kit.box_in(frame, Vector3(width, 0.25, 0.3), Vector3(0, wall_h, 0), kit.stone(cream.darkened(0.3)))
		if rng.randf() < 0.4:
			kit.box_in(frame, Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.5, 1.2), 0.05), Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(1.5, 4.5), -0.12), kit.stone(Color(0.12, 0.1, 0.06)))
		# Pennants along the wall top.
		for k in 5:
			var x := -width / 2.0 + (k + 0.5) * width / 5.0
			kit.box_in(frame, Vector3(0.32, 0.32, 0.03), Vector3(x, wall_h - 0.45, -0.3), stripes[(k + i) % 2] if k % 2 == 0 else kit.stone(cream), Vector3(0, 0, PI / 4))
	# The roof: a cone of canvas, seen from inside, with stripes up to the peak.
	var roof := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.4
	cone.bottom_radius = radius + 0.4
	cone.height = peak - wall_h
	cone.radial_segments = sides
	cone.rings = 1
	var canvas := Look.block_material(purple.darkened(0.25))
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material = canvas
	roof.mesh = cone
	roof.position = c + Vector3(0, (peak + wall_h) / 2.0, 0)
	decor.add_child(roof)
	var slant := Vector2(radius, peak - wall_h).length()
	var pitch := atan2(peak - wall_h, radius)
	for i in 10:
		var a := TAU * i / 10.0
		var dir := Vector3(cos(a), 0, sin(a))
		var mid := radius * 0.5
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.z)) * Basis(Vector3.RIGHT, pitch)
		kit.box_in(Transform3D(basis, c + dir * mid + Vector3(0, wall_h + (peak - wall_h) * 0.5 - 0.25, 0)), Vector3(1.2, 0.08, slant), Vector3.ZERO, kit.stone(green.darkened(0.1)))
	# Rigging from the peak to the corners and a trapeze bar.
	var rope := kit.stone(Color(0.45, 0.38, 0.26))
	for x in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var low := c + Vector3(x * 10.5, wall_h, zs * 10.5)
			var high := c + Vector3(0, peak - 0.6, 0)
			var mid := (low + high) / 2.0
			var frame := Transform3D(Basis.looking_at(high - low, Vector3.UP), mid)
			kit.box_in(frame, Vector3(0.06, 0.06, low.distance_to(high)), Vector3.ZERO, rope)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.04, 3.0, 0.04), c + Vector3(side * 0.8, peak - 3.0, 0), rope)
	kit.box(Vector3(1.8, 0.08, 0.08), c + Vector3(0, peak - 4.5, 0), kit.metal(Color(0.6, 0.55, 0.4)))
	# Green lanterns hanging round the rim.
	for i in 8:
		var a := TAU * (i + 0.25) / 8.0
		var at := c + Vector3(cos(a), 0, sin(a)) * 11.0
		kit.box(Vector3(0.04, 2.2, 0.04), at + Vector3(0, 8.6, 0), rope)
		kit.box(Vector3(0.36, 0.5, 0.36), at + Vector3(0, 7.3, 0), kit.glow(sludge, 3.0))
		kit.box(Vector3(0.44, 0.08, 0.44), at + Vector3(0, 7.6, 0), kit.metal(Color(0.2, 0.2, 0.18)))
	# The performers' curtain behind the Doctor, glowing green between.
	var gate_z := c.z - radius + 0.5
	kit.box(Vector3(2.6, 4.6, 0.06), Vector3(0, 2.3, gate_z - 0.1), kit.glow(Color(0.07, 0.17, 0.02), 0.8))
	for side in [-1.0, 1.0]:
		for fold in 4:
			kit.box(Vector3(0.45, 5.0, 0.25), Vector3(side * (1.5 + fold * 0.42), 2.5, gate_z + 0.1 + (fold % 2) * 0.12), kit.stone(Color(0.4, 0.08, 0.1)))
	kit.box(Vector3(5.5, 0.6, 0.4), Vector3(0, 5.1, gate_z + 0.2), kit.stone(cream.darkened(0.2)))
	var lights: Array = []
	lights.append(_light(decor, Vector3(0, 3.0, gate_z + 2.5), sludge, 2.2, 10.0))
	var seats := _ringside(kit, decor, c, {
		"stand": Color(0.3, 0.22, 0.13), "wall": Color(0.5, 0.12, 0.12), "stripe": cream, "cap": Color(0.3, 0.22, 0.13),
		"fire": sludge, "half_w": 12.0, "gate_z": gate_z, "runner": Color(0.3, 0.12, 0.12),
		"corner": "vat", "candles": false, "corner_light": Color(0.5, 1.0, 0.25),
	}, rng, lights)
	kit.flush(decor)
	var crowd := _crowd(decor, c, seats, [
		["res://brawler.tscn", 3.0, 1.0],
		["res://runner.tscn", 3.0, 1.0],
		["res://sprinter.tscn", 2.0, 1.0],
		["res://pit_fighter.tscn", 1.5, 1.0],
		["res://bruiser.tscn", 1.6, 0.85, true],
		["res://hulk.tscn", 0.8, 0.85, true],
	], rng)
	return {"lights": lights, "crowd": crowd, "bell": null}


# --- The Coffin King: the Gold Hall --------------------------------------------------

## His castle's throne room: deep red walls with gold pillars and trim,
## marble floor with gold inlay, chandeliers, moonlit windows with red
## curtains, an empty throne on a dais behind his corner between gilded
## coffins, and treasure heaped everywhere. The crowd: Grave Champions and
## Bone Crushers.
static func _coffin_king(arena: Node3D, c: Vector3) -> Dictionary:
	var web := Settings.use_web_profile()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4405
	var decor: Node3D = arena.get_node("Decorations")
	var kit := PropKit.new()
	var red := Color(0.36, 0.1, 0.08)
	var crimson := Color(0.55, 0.05, 0.07)
	var gold_color := Color(0.95, 0.72, 0.25)
	var gold := kit.metal(gold_color, 0.85)
	var fire := Look.FIRE
	_indoors(arena, Color(0.62, 0.5, 0.42), 0.95, Color(0.08, 0.035, 0.025), 0.011)
	(arena.get_node("Ground/Mesh") as MeshInstance3D).material_override = kit.tiles(Color(0.6, 0.56, 0.5))
	var half_w := 13.0
	var back := c.z - 13.0
	var front := c.z + 11.0
	var height := 12.0
	_room(kit, c, half_w, back, front, height, kit.bricks(red), kit.stone(red.darkened(0.55)))
	# Gold pillars, trim bands and ceiling beams.
	var z := back + 2.5
	while z < front - 1.0:
		for side in [-1.0, 1.0]:
			var at := Vector3(side * (half_w - 0.55), 0, z)
			kit.box(Vector3(1.2, 0.5, 1.2), at + Vector3(0, 0.25, 0), gold)
			kit.box(Vector3(0.8, height - 1.0, 0.8), at + Vector3(0, height / 2.0, 0), gold)
			kit.box(Vector3(1.2, 0.5, 1.2), at + Vector3(0, height - 0.5, 0), gold)
		kit.box(Vector3(half_w * 2.0, 0.5, 0.5), Vector3(0, height - 0.25, z), gold)
		z += 4.5
	for y in [3.0, height - 1.3]:
		kit.box(Vector3(half_w * 2.0, 0.2, 0.1), Vector3(0, y, back + 0.33), gold)
		for side in [-1.0, 1.0]:
			kit.box(Vector3(0.1, 0.2, front - back), Vector3(side * (half_w - 0.33), y, (back + front) / 2.0), gold)
	# Gold inlay in the marble beyond the low wall.
	var inlay := kit.metal(gold_color.darkened(0.15), 0.8)
	for i in range(-4, 5):
		var x := float(i) * 3.0
		if absf(x) > START:
			kit.box(Vector3(0.08, 0.01, front - back), Vector3(x, 0.006, (back + front) / 2.0), inlay)
	# Moonlit windows down both sides with red curtains.
	var moonlight := [Color(0.55, 0.65, 1.0), Color(0.45, 0.55, 0.95), Color(0.7, 0.78, 1.0)]
	for bay in _bays(back, front):
		for side in [-1.0, 1.0]:
			var frame := _turned(Vector3(side * (half_w - 0.32), 4.0, bay), side * PI / 2.0)
			kit.stained_window(frame, 1.8, 4.6, moonlight, rng, 1.0)
			for k in [-1.0, 1.0]:
				kit.box_in(frame, Vector3(0.5, 6.0, 0.15), Vector3(k * 1.35, 2.6, -0.25), kit.stone(crimson))
			kit.box_in(frame, Vector3(3.2, 0.4, 0.2), Vector3(0, 5.8, -0.3), gold)
	# The dais and the empty throne behind his corner.
	var dais_z := back + 3.2
	var step := kit.stone(Color(0.62, 0.58, 0.52))
	for k in 3:
		kit.box(Vector3(8.0 - k * 1.5, 0.3, 5.0 - k * 1.0), Vector3(0, 0.15 + k * 0.3, dais_z - k * 0.4), step)
		kit.box(Vector3(8.0 - k * 1.5 + 0.05, 0.06, 0.06), Vector3(0, 0.3 + k * 0.3, dais_z - k * 0.4 + (5.0 - k * 1.0) / 2.0), gold)
	var throne := Vector3(0, 0.9, dais_z - 1.0)
	kit.box(Vector3(1.8, 0.7, 1.4), throne + Vector3(0, 0.35, 0), gold)
	kit.box(Vector3(1.5, 0.2, 1.1), throne + Vector3(0, 0.8, 0.05), kit.stone(crimson))
	kit.box(Vector3(1.9, 3.4, 0.35), throne + Vector3(0, 1.9, -0.6), gold)
	kit.box(Vector3(1.4, 2.6, 0.08), throne + Vector3(0, 1.8, -0.4), kit.stone(crimson))
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.3, 0.6, 1.3), throne + Vector3(side * 0.95, 0.95, 0.05), gold)
	for k in 5:
		kit.box(Vector3(0.22, 0.6 if k % 2 == 0 else 0.4, 0.22), throne + Vector3(-0.8 + k * 0.4, 3.85 if k % 2 == 0 else 3.75, -0.6), gold)
	kit.box(Vector3(0.3, 0.3, 0.1), throne + Vector3(0, 3.2, -0.38), kit.glow(Color(0.9, 0.1, 0.15), 3.0), Vector3(0, 0, PI / 4))
	# A great banner behind the throne with a gold crown.
	var banner := Vector3(0, 10.0, back + 0.36)
	kit.box(Vector3(4.0, 7.0, 0.06), banner + Vector3(0, -3.5, 0), kit.stone(crimson))
	kit.box(Vector3(4.4, 0.25, 0.25), banner, gold)
	kit.box(Vector3(2.0, 0.6, 0.08), banner + Vector3(0, -3.0, 0.05), gold)
	for k in 3:
		kit.box(Vector3(0.4, 0.7, 0.08), banner + Vector3(-0.75 + k * 0.75, -2.4, 0.05), gold)
	for side in [-1.0, 1.0]:
		kit.coffin(_turned(Vector3(side * 3.0, 0.6, dais_z - 1.6), PI), Color(0.85, 0.64, 0.2))
	# Treasure heaped round the dais and in the corners.
	var heaps := [Vector3(-4.6, 0, dais_z), Vector3(4.6, 0, dais_z), Vector3(-half_w + 2.2, 0, back + 2.2), Vector3(half_w - 2.2, 0, back + 2.2)]
	if not web:
		heaps.append_array([Vector3(-half_w + 2.2, 0, front - 2.2), Vector3(half_w - 2.2, 0, front - 2.2), Vector3(-7.5, 0, back + 1.4), Vector3(7.5, 0, back + 1.4)])
	for at in heaps:
		kit.treasure(Transform3D(Basis.IDENTITY, at), rng.randf_range(0.9, 1.4), rng)
	# Chandeliers.
	for at in [Vector3(0, 0, c.z - 9.0), Vector3(-9.0, 0, c.z), Vector3(9.0, 0, c.z)]:
		kit.chandelier(Transform3D(Basis.IDENTITY, at), height, 3.5, 1.4)
	var lights: Array = []
	lights.append(_light(decor, throne + Vector3(0, 2.5, 3.0), Color(1.0, 0.75, 0.4), 2.4, 11.0))
	var seats := _ringside(kit, decor, c, {
		"stand": Color(0.5, 0.46, 0.42), "wall": red.lightened(0.05), "cap": gold_color,
		"fire": fire, "half_w": half_w, "gate_z": dais_z + 2.5, "runner": crimson,
		"corner": "gold",
	}, rng, lights)
	kit.flush(decor)
	var crowd := _crowd(decor, c, seats, [
		["res://boss.tscn", 1.0, 0.55],
		["res://crusher.tscn", 1.2, 0.62],
	], rng)
	return {"lights": lights, "crowd": crowd, "bell": null}


## A bronze bell on a chain from the vault: a pivot at the chain's top (swing
## it round X), a yoke, the flared body, a lip and a clapper.
static func _bell(parent: Node3D, top: Vector3, kit: PropKit) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = top
	parent.add_child(pivot)
	var bronze := kit.metal(Color(0.72, 0.52, 0.24), 0.6)
	var iron := kit.metal(Color(0.09, 0.085, 0.09))
	for i in 5:
		_piece(pivot, Enemy._box(Vector3(0.12, 0.3, 0.06) if i % 2 == 0 else Vector3(0.06, 0.3, 0.12)), iron, Vector3(0, -0.15 - i * 0.28, 0))
	_piece(pivot, Enemy._box(Vector3(1.0, 0.25, 0.3)), kit.stone(Color(0.2, 0.12, 0.07)), Vector3(0, -1.5, 0))
	_piece(pivot, _cone(0.42, 0.62, 0.55), bronze, Vector3(0, -1.9, 0))
	_piece(pivot, _cone(0.62, 0.98, 0.9), bronze, Vector3(0, -2.6, 0))
	_piece(pivot, _cone(0.98, 1.08, 0.18), bronze, Vector3(0, -3.14, 0))
	_piece(pivot, _cone(0.7, 0.7, 0.08), kit.metal(Color(0.62, 0.46, 0.18), 0.9), Vector3(0, -2.3, 0))
	_piece(pivot, Enemy._box(Vector3(0.22, 0.22, 0.22)), iron, Vector3(0, -3.3, 0))
	return pivot


static func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = h
	mesh.radial_segments = 12
	mesh.rings = 1
	return mesh


static func _piece(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3) -> void:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
