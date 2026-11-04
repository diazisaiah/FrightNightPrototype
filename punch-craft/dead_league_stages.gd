class_name DeadLeagueStages
## Each Dead League contender's own place round the same ring (2026-11-04,
## the places update): the ring, ropes and spotlight stay; the hall, its
## lighting and its crowd change. The crowd (Crowd) never fights.
## Budget for phones: everything static is batched by PropKit, at most six
## real lights (the rest of the flames only glow), no shadows on the web.

## A stage for contender id round the ring centred at center: {"lights":
## flames to flicker, "crowd": Crowd, "bell": a swinging bell or null}. Empty
## when the contender has no stage yet (the arena falls back to the graveyard).
static func build(id: String, arena: Node3D, center: Vector3) -> Dictionary:
	match id:
		"bellman":
			return _bellman(arena, center)
	return {}


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


## Fills the seats with the crowd: the first seats first (put the ones in view
## first), mix is [[scene, weight, size], ...], big kinds only on high seats.
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
			big = false
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


# --- The Bellman: the Crypt hall ---------------------------------------------------

## Grey stone vaults (the Crypt's first tier), red banners, stepped stands of
## zombies, skeletons and Hulks on three sides, a gate glowing with fire
## behind the Bellman's corner and a great bronze bell hanging over it.
static func _bellman(arena: Node3D, c: Vector3) -> Dictionary:
	var web := Settings.use_web_profile()
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

	# The hall: 24 m wide, the back wall behind the Bellman, a vaulted ceiling.
	var half_w := 12.0
	var back := c.z - 12.5
	var front := c.z + 11.0
	var height := 9.5
	var depth := front - back
	var walls := kit.bricks(wall)
	var dark := kit.stone(wall.darkened(0.45))
	kit.box(Vector3(half_w * 2.0, height, 0.6), Vector3(0, height / 2.0, back), walls)
	kit.box(Vector3(half_w * 2.0, height, 0.6), Vector3(0, height / 2.0, front), walls)
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.6, height, depth), Vector3(side * half_w, height / 2.0, (back + front) / 2.0), walls)
	kit.box(Vector3(half_w * 2.0, 0.5, depth), Vector3(0, height + 0.25, (back + front) / 2.0), dark)
	# Ribs across the vault and pillars under them along both side walls.
	var z := back + 2.5
	while z < front - 1.0:
		kit.box(Vector3(half_w * 2.0, 0.55, 0.55), Vector3(0, height - 0.25, z), kit.stone(wall.darkened(0.2)))
		for side in [-1.0, 1.0]:
			kit.pillar(Transform3D(Basis.IDENTITY, Vector3(side * (half_w - 0.55), 0, z)), height - 0.5, 0.8, wall.lightened(0.04))
		z += 4.5
	for x in [-8.0, -4.0, 4.0, 8.0]:
		kit.pillar(Transform3D(Basis.IDENTITY, Vector3(x, 0, back + 0.55)), height - 0.5, 0.8, wall.lightened(0.04))
		kit.box(Vector3(0.55, 0.55, depth), Vector3(x, height - 0.25, (back + front) / 2.0), kit.stone(wall.darkened(0.2)))

	# The gate behind the Bellman's corner: a dark arch with fire beyond and
	# the portcullis drawn up.
	var gate_z := back + 0.32
	kit.box(Vector3(3.4, 4.8, 0.06), Vector3(0, 2.4, gate_z), kit.glow(Color(0.32, 0.08, 0.02), 0.7))
	for side in [-1.0, 1.0]:
		kit.box(Vector3(0.7, 5.4, 0.9), Vector3(side * 2.05, 2.7, gate_z + 0.2), kit.stone(wall.lightened(0.06)))
	kit.box(Vector3(4.8, 0.9, 0.9), Vector3(0, 5.45, gate_z + 0.2), kit.stone(wall.lightened(0.06)))
	kit.box(Vector3(0.7, 0.9, 0.95), Vector3(0, 5.45, gate_z + 0.22), kit.stone(wall.lightened(0.15)))
	var iron := kit.metal(Color(0.09, 0.085, 0.09))
	for i in 9:
		kit.box(Vector3(0.08, 1.8, 0.08), Vector3(-1.6 + i * 0.4, 4.0, gate_z + 0.12), iron)
	kit.box(Vector3(3.4, 0.1, 0.1), Vector3(0, 3.15, gate_z + 0.12), iron)
	var lights: Array = []
	lights.append(_light(decor, Vector3(0, 3.2, gate_z + 2.2), Color(1.0, 0.45, 0.15), 2.8, 10.0))

	# Banners between the pillars, coffins standing by the gate.
	for x in [-10.0, -6.0, 6.0, 10.0]:
		kit.banner(Transform3D(Basis.IDENTITY, Vector3(x, height - 1.2, back + 0.36)), 1.2, 3.4, red, gold)
	z = back + 4.75
	while z < front - 2.0:
		for side in [-1.0, 1.0]:
			kit.banner(_turned(Vector3(side * (half_w - 0.34), height - 1.4, z), -side * PI / 2.0), 1.1, 3.0, red, gold)
		z += 4.5
	for x in [-3.0, 3.0]:
		kit.coffin(_turned(Vector3(x, 0, back + 0.55), PI), Color(0.24, 0.15, 0.09))

	# Stands on three sides (the back split by an aisle to the gate) and a
	# shorter run behind you; a low wall with candles round the floor.
	var tiers := 3
	var rise := 0.5
	var stand_depth := 1.2
	var start := 6.6
	var back_seats: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var length := half_w - 1.2 - 1.7
		back_seats.append_array(kit.stands(_turned(Vector3(side * (1.7 + length / 2.0), 0, c.z - start), PI), length, tiers, stand_depth, rise, wall.darkened(0.15)))
	var side_seats: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		side_seats.append_array(kit.stands(_turned(Vector3(side * start, 0, c.z), side * PI / 2.0), start * 2.0 - 0.6, tiers, stand_depth, rise, wall.darkened(0.15)))
	var front_seats: Array[Transform3D] = kit.stands(_turned(Vector3(0, 0, c.z + start), 0.0), start * 2.0 - 0.6, 2, stand_depth, rise, wall.darkened(0.15))
	var barrier := kit.stone(wall.darkened(0.05))
	var cap := kit.stone(wall.lightened(0.1))
	var wall_at := start - 0.35
	for side in [-1.0, 1.0]:
		# The back wall in two pieces either side of the aisle.
		var length := wall_at - 1.6
		kit.box(Vector3(length, 0.9, 0.3), Vector3(side * (1.6 + length / 2.0), 0.45, c.z - wall_at), barrier)
		kit.box(Vector3(length, 0.1, 0.4), Vector3(side * (1.6 + length / 2.0), 0.95, c.z - wall_at), cap)
		kit.box(Vector3(0.3, 0.9, wall_at * 2.0), Vector3(side * wall_at, 0.45, c.z), barrier)
		kit.box(Vector3(0.4, 0.1, wall_at * 2.0), Vector3(side * wall_at, 0.95, c.z), cap)
	kit.box(Vector3(wall_at * 2.0, 0.9, 0.3), Vector3(0, 0.45, c.z + wall_at), barrier)
	kit.box(Vector3(wall_at * 2.0, 0.1, 0.4), Vector3(0, 0.95, c.z + wall_at), cap)
	for i in 10:
		var along := -wall_at + 0.8 + i * (wall_at * 2.0 - 1.6) / 9.0
		for spot in [Vector3(along, 1.0, c.z + wall_at), Vector3(-wall_at, 1.0, c.z + along), Vector3(wall_at, 1.0, c.z + along)]:
			if rng.randf() < 0.55:
				kit.candles(Transform3D(Basis.IDENTITY, spot), rng, rng.randi_range(1, 3), fire)
	# The aisle: a red runner from the gap to the gate, candles along it.
	var aisle_from := c.z - wall_at
	kit.box(Vector3(1.5, 0.02, aisle_from - gate_z), Vector3(0, 0.012, (aisle_from + gate_z) / 2.0), kit.stone(red.darkened(0.2)))
	z = aisle_from - 0.8
	while z > gate_z + 1.0:
		for side in [-1.0, 1.0]:
			kit.candles(Transform3D(Basis.IDENTITY, Vector3(side * 1.25, 0, z)), rng, rng.randi_range(2, 4), fire)
		z -= 1.4

	# Braziers on the floor's corners (the back pair lit everywhere, the front
	# pair only on desktop) and glowing sconces on the pillars.
	for x in [-1.0, 1.0]:
		for zs in [-1.0, 1.0]:
			var at := Vector3(x * 5.2, 0, c.z + zs * 5.2)
			var top := kit.brazier(Transform3D(Basis.IDENTITY, at))
			Look.flame(decor, top, 1.6, not web)
			if zs < 0.0 or not web:
				lights.append(_light(decor, top + Vector3(0, 0.6, 0), fire, 2.2, 8.0))
	z = back + 2.5
	while z < front - 1.0:
		for side in [-1.0, 1.0]:
			var sconce := Vector3(side * (half_w - 1.05), 3.2, z)
			kit.box(Vector3(0.3, 0.12, 0.3), sconce, iron)
			Look.flame(decor, sconce + Vector3(0, 0.15, 0), 1.0, false)
		z += 4.5

	kit.flush(decor)

	# The great bell over the gate (it swings when a round starts).
	var bell := _bell(decor, Vector3(0, height - 1.4, back + 2.4), kit)

	# The crowd: the back stands first (they're in view), then the sides, then
	# behind you.
	var crowd := Crowd.new()
	decor.add_child(crowd)
	var count := 22 if web else 40
	var seats: Array[Transform3D] = []
	seats.append_array(_spread(back_seats, int(count * 0.45)))
	seats.append_array(_spread(side_seats, int(count * 0.4)))
	seats.append_array(_spread(front_seats, count - seats.size()))
	var mix := [
		["res://zombie.tscn", 5.0, 1.0],
		["res://skeleton.tscn", 4.0, 1.0],
		["res://hulk.tscn", 1.6, 0.85, true],
	]
	_seat_crowd(crowd, seats, c, mix, count, rng, rise * 2.5)
	crowd.finish()
	return {"lights": lights, "crowd": crowd, "bell": bell}


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
