class_name ArenaScenery
## The Underworld Arena's deeper divisions (Themes.ARENA), laid out like the
## Gravedigger Division (2026-11-04, the places update): a clear plaza in
## the middle, paths out, planned clusters of solid cover in the middle ring
## (solid to you AND monsters: Scenery.PROP_LAYER; monsters steer round
## them), walk-through clutter and the division's wall at the edge. Everything static is
## batched by PropKit; four lights on phones, six on desktop.
## build() returns {"lights": flames to flicker, "solids": Vector3(x, z,
## radius) per solid prop, to keep spawns and hazards out of them}.

const RADIUS := 45.0
const PLAZA := 9.5


static func build(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var lights: Array = []
	var solids: Array = []
	var kit := PropKit.new()
	Scenery.night_sky(parent, rng)
	match theme.id:
		"ossuary":
			_ossuary(theme, kit, parent, rng, lights, solids)
		"pier":
			_pier(theme, kit, parent, rng, lights, solids)
		"carnival":
			_carnival(theme, kit, parent, rng, lights, solids)
		"colosseum":
			_colosseum(theme, kit, parent, rng, lights, solids)
	kit.flush(parent)
	var web := Settings.use_web_profile()
	var mist := Scenery.mist(parent, Vector3(0, 0.5, 0), Vector3(RADIUS, 0.3, RADIUS), 35 if web else 90)
	(mist.mesh.material as StandardMaterial3D).albedo_color = Color(theme.mist, 0.09)
	Scenery.wisps(parent, Vector3(0, 1.4, 0), Vector3(RADIUS * 0.8, 1.0, RADIUS * 0.8), theme.wisps, 20 if web else 50)
	return {"lights": lights, "solids": solids}


# --- Helpers -----------------------------------------------------------------------

## A skull of separate boxes (the Crypt's skull niches use it; the arenas use
## PropKit.skull).
static func _skull(parent: Node3D, pos: Vector3, size: float, bone: Material, dark: Material, rot := 0.0) -> void:
	Scenery.box(parent, Vector3(1.0, 0.85, 0.9) * size, pos, bone, Vector3(0, rot, 0))
	var face := Vector3(sin(rot), 0, cos(rot)) * -0.46 * size
	var side := Vector3(cos(rot), 0, -sin(rot))
	for s in [-1.0, 1.0]:
		Scenery.box(parent, Vector3(0.26, 0.22, 0.05) * size, pos + face + side * 0.22 * s * size + Vector3(0, 0.06, 0) * size, dark, Vector3(0, rot, 0))
	Scenery.box(parent, Vector3(0.12, 0.14, 0.05) * size, pos + face + Vector3(0, -0.16, 0) * size, dark, Vector3(0, rot, 0))


static func _polar(r: float, degrees: float) -> Vector3:
	return GraveyardScenery._polar(r, degrees)


## +Z toward the middle.
static func _facing_in(at: Vector3) -> Transform3D:
	return GraveyardScenery._facing_in(at)


## -Z (the front) toward the middle.
static func _facing_middle(at: Vector3) -> Transform3D:
	return GraveyardScenery._facing_middle(at)


## A solid round prop (an upright cylinder of collision).
static func _solid(parent: Node3D, solids: Array, at: Vector3, radius: float) -> void:
	GraveyardScenery._solid(parent, solids, at, radius)


## A solid box prop in frame (its centre at frame's origin + size.y / 2).
static func _solid_box(parent: Node3D, solids: Array, frame: Transform3D, size: Vector3) -> void:
	var body := Scenery.solid(parent, size, frame.origin + Vector3(0, size.y / 2.0, 0), frame.basis.get_euler(), 0.0, true)
	body.transform.basis = frame.basis
	solids.append(Vector3(frame.origin.x, frame.origin.z, Vector2(size.x, size.z).length() / 2.0))


## A real light at pos (flickered by the world), on phones only if web_too.
static func _lamp(parent: Node3D, pos: Vector3, color: Color, lights: Array, web_too: bool, energy := 2.0) -> void:
	if not web_too and Settings.use_web_profile():
		return
	var light := Look.fire_light(color, energy, 13.0, false)
	light.position = pos
	parent.add_child(light)
	lights.append(light)


## Flat ring path round the plaza and straight paths out at angles.
static func _paths(kit: PropKit, rng: RandomNumberGenerator, angles: Array, colors: Array, width := 2.2) -> void:
	var segments := 28
	for i in segments:
		kit.path(_polar(PLAZA + 0.8, 360.0 * i / segments), _polar(PLAZA + 0.8, 360.0 * (i + 1) / segments), 1.6, rng, colors)
	for angle in angles:
		kit.path(_polar(PLAZA + 1.6, angle), _polar(RADIUS + 3.0, angle), width, rng, colors)


static func _near_angles(degrees: float, angles: Array, margin: float) -> bool:
	for angle in angles:
		if absf(wrapf(degrees - float(angle), -180.0, 180.0)) < margin:
			return true
	return false


## A spot in the middle ring clear of the paths (angles) and solids.
static func _free_spot(rng: RandomNumberGenerator, angles: Array, solids: Array, from: float, to: float) -> Vector3:
	for attempt in 30:
		var r := rng.randf_range(from, to)
		var angle := rng.randf() * 360.0
		if _near_angles(angle, angles, rad_to_deg(2.6 / r)):
			continue
		var at := _polar(r, angle)
		if solids.any(func(o: Vector3) -> bool: return Vector2(o.x, o.y).distance_to(Vector2(at.x, at.z)) < o.z + 1.2):
			continue
		return at
	return Vector3.INF


## A wall of segments round the edge at radius; build(frame, width, i) dresses
## each one (frame: -Z toward the middle).
static func _ring_wall(radius: float, sides: int, build: Callable) -> void:
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var at := Vector3(cos(a) * radius, 0, sin(a) * radius)
		build.call(Transform3D(Basis(Vector3.UP, -a + PI / 2.0), at), TAU * radius / sides + 0.3, i)


# --- The Ossuary Pit (Bone) ---------------------------------------------------------

## A sunken pit in blue ghost-light: six bone-paved causeways from the
## plaza, skull pillars with blue fire round it, walls of stacked skulls and
## giant ribcages as cover, bone heaps between, and the bone wall at the edge.
static func _ossuary(theme: Dictionary, kit: PropKit, parent: Node3D, rng: RandomNumberGenerator, lights: Array, solids: Array) -> void:
	var web := Settings.use_web_profile()
	var bone := Color(0.78, 0.74, 0.64)
	var bone_dark := Color(0.62, 0.58, 0.5)
	var blue: Color = theme.fire
	var paths := [30.0, 90.0, 150.0, 210.0, 270.0, 330.0]
	_paths(kit, rng, paths, [Color(0.6, 0.57, 0.5), Color(0.5, 0.47, 0.42)])
	var bone_m := kit.stone(bone)
	var dark_m := kit.stone(bone_dark)
	# The bone wall, skulls set in its face, ghost-fire on top.
	_ring_wall(RADIUS + 5.0, 28, func(frame: Transform3D, width: float, i: int) -> void:
		kit.box_in(frame, Vector3(width, 4.2, 1.6), Vector3(0, 2.1, 0), kit.bricks(bone_dark))
		kit.box_in(frame, Vector3(width, 0.35, 1.9), Vector3(0, 4.3, 0), bone_m)
		for row in (1 if web else 2):
			for k in 5:
				kit.skull(frame * Transform3D(Basis.IDENTITY, Vector3(-width / 2.0 + (k + 0.5) * width / 5.0, 1.0 + row * 1.5, -0.85)), 0.5, bone)
		if i % 4 == 0:
			Look.flame(parent, frame * Vector3(0, 4.6, 0), 2.0, false, blue)
		Scenery.solid(parent, Vector3(width, 4.2, 1.6), frame * Vector3(0, 2.1, 0), Vector3(0, frame.basis.get_euler().y, 0)))
	# Skull pillars with blue fire round the plaza (between the causeways).
	for k in 6:
		var at := _polar(17.0, 60.0 * k)
		kit.box(Vector3(1.1, 0.4, 1.1), at + Vector3(0, 0.2, 0), dark_m)
		for level in 6:
			kit.skull(Transform3D(Basis(Vector3.UP, level * 0.9 + k), at + Vector3(0, 0.4 + level * 0.62, 0)), 0.7, bone if level % 2 == 0 else bone_dark)
		kit.box(Vector3(0.9, 0.2, 0.9), at + Vector3(0, 4.2, 0), dark_m)
		Look.flame(parent, at + Vector3(0, 4.4, 0), 2.2, not web, blue)
		_lamp(parent, at + Vector3(0, 4.7, 0), Color(blue).lightened(0.25), lights, k % 3 != 2, 2.4)
		_solid(parent, solids, at, 0.65)
	# Ossuary walls: stacked skulls in a frame, facing the middle.
	for k in 6:
		var at := _polar(27.0, 60.0 * k)
		var frame := _facing_middle(at)
		kit.box_in(frame, Vector3(4.6, 0.4, 1.3), Vector3(0, 0.2, 0), dark_m)
		kit.box_in(frame, Vector3(4.6, 3.2, 0.8), Vector3(0, 1.8, 0.15), kit.bricks(bone_dark))
		for row in 4:
			for col in 6:
				kit.skull(frame * Transform3D(Basis.IDENTITY, Vector3(-1.9 + col * 0.76, 0.55 + row * 0.75, -0.3)), 0.36, bone if (row + col) % 3 else bone_dark)
		kit.box_in(frame, Vector3(5.0, 0.3, 1.4), Vector3(0, 3.5, 0), bone_m)
		for side in [-1.0, 1.0]:
			kit.box_in(frame, Vector3(0.7, 3.8, 1.3), Vector3(side * 2.6, 1.9, 0), dark_m)
		_solid_box(parent, solids, frame, Vector3(5.6, 3.8, 1.4))
	# Giant ribcages half sunk in the ash, between every other causeway.
	for k in 3:
		var at := _polar(37.0, 60.0 + 120.0 * k)
		var frame := Transform3D(Basis(Vector3.UP, deg_to_rad(-60.0 - 120.0 * k)), at)
		kit.box_in(frame, Vector3(0.6, 0.6, 9.0), Vector3(0, 0.6, 0), bone_m)
		for r in 6:
			var z := -3.6 + r * 1.45
			for s in [-1.0, 1.0]:
				kit.box_in(frame, Vector3(0.35, 2.4, 0.35), Vector3(1.1 * s, 1.6, z), bone_m, Vector3(0, 0, -0.5 * s))
				kit.box_in(frame, Vector3(0.32, 2.0, 0.32), Vector3(2.0 * s, 3.4, z), bone_m, Vector3(0, 0, 0.35 * s))
		kit.skull(frame * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.2, 5.4)), 2.2, bone)
		_solid_box(parent, solids, frame, Vector3(4.6, 4.2, 11.0))
	# Bone heaps and loose skulls (walk-through).
	for i in (18 if web else 34):
		var at := _free_spot(rng, paths, solids, 12.0, RADIUS)
		if at == Vector3.INF:
			continue
		for b in rng.randi_range(4, 8):
			kit.box(Vector3(rng.randf_range(0.4, 0.9), 0.09, 0.1), at + Vector3(rng.randf_range(-0.5, 0.5), 0.05 + b * 0.02, rng.randf_range(-0.5, 0.5)), bone_m, Vector3(0, rng.randf() * TAU, 0))
		if rng.randf() < 0.6:
			kit.skull(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + Vector3(0, 0.15, 0)), 0.4, bone)


# --- The Drowned Pier (Ghost) -------------------------------------------------------

## A round dock over black water: a compass rose in the plaza, four
## boardwalks out with ghost lanterns, fishing shacks, stacked crates and
## overturned boats as cover, pilings and rope round the edge, sunken ships
## beyond.
static func _pier(theme: Dictionary, kit: PropKit, parent: Node3D, rng: RandomNumberGenerator, lights: Array, solids: Array) -> void:
	var web := Settings.use_web_profile()
	var ghost: Color = theme.fire
	var wood := Color(0.22, 0.16, 0.11)
	var wood_dark := Color(0.12, 0.09, 0.07)
	var wood_m := kit.stone(wood)
	var dark_m := kit.stone(wood_dark)
	var rope := kit.stone(Color(0.45, 0.38, 0.26))
	var iron := kit.metal(Color(0.12, 0.13, 0.13), 0.6)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.02, 0.06, 0.07)
	water.metallic = 0.4
	water.roughness = 0.08
	Scenery.box(parent, Vector3(500, 0.1, 500), Vector3(0, -0.35, 0), water)
	var strips := 40 if web else 90
	for i in strips:
		var x := -RADIUS + i * (RADIUS * 2.0 / strips)
		var length := sqrt(maxf(RADIUS * RADIUS - x * x, 0.0)) * 2.0 + 10.0
		kit.box(Vector3(0.05, 0.01, length), Vector3(x, 0.005, 0), dark_m)
	# The compass rose in the plaza.
	var paint := kit.stone(Color(0.55, 0.6, 0.55))
	for k in 8:
		var a := 45.0 * k
		var length := 6.5 if k % 2 == 0 else 4.0
		kit.box_in(Transform3D(Basis(Vector3.UP, deg_to_rad(-a)), Vector3.ZERO), Vector3(length, 0.02, 0.5), Vector3(length / 2.0, 0.012, 0), paint if k % 2 == 0 else kit.stone(Color(0.3, 0.45, 0.42)), Vector3(0, PI / 4, 0))
	kit.box(Vector3(1.0, 0.025, 1.0), Vector3(0, 0.014, 0), kit.glow(ghost, 1.5), Vector3(0, PI / 4, 0))
	# Boardwalks: lighter planks laid across, out at the diagonals.
	var lanes := [45.0, 135.0, 225.0, 315.0]
	var plank := [kit.stone(wood.lightened(0.15)), kit.stone(wood.lightened(0.05))]
	for angle in lanes:
		var dir := _polar(1.0, angle)
		var t := PLAZA + 1.0
		while t < RADIUS + 3.0:
			kit.box(Vector3(2.6, 0.06, 0.42), dir * t + Vector3(0, 0.03, 0), plank[int(t * 2.0) % 2], Vector3(0, -deg_to_rad(angle) - PI / 2.0 + rng.randf_range(-0.03, 0.03), 0))
			t += 0.48
		for step in 4:
			var side := 1.0 if step % 2 == 0 else -1.0
			var at := dir * (14.0 + step * 10.0) + _polar(1.8, angle + 90.0) * side
			kit.box(Vector3(0.16, 3.4, 0.16), at + Vector3(0, 1.7, 0), dark_m)
			kit.box(Vector3(0.9, 0.12, 0.12), at + Vector3(0, 3.35, 0), dark_m)
			kit.box(Vector3(0.34, 0.06, 0.34), at + Vector3(0, 2.95, 0), iron)
			kit.box(Vector3(0.28, 0.36, 0.28), at + Vector3(0, 2.75, 0), kit.glow(ghost, 3.0))
			if step == 0:
				_lamp(parent, at + Vector3(0, 2.8, 0), ghost.lightened(0.2), lights, true)
	for q in 4:
		var mid := 90.0 * q
		# Bollards near the plaza.
		for side in [-1.0, 1.0]:
			var at := _polar(14.0, mid + side * 12.0)
			kit.box(Vector3(0.45, 0.7, 0.45), at + Vector3(0, 0.35, 0), iron)
			kit.box(Vector3(0.6, 0.12, 0.6), at + Vector3(0, 0.72, 0), iron)
		# Crate stacks.
		for side in [-1.0, 1.0]:
			var at := _polar(22.0, mid + side * 15.0)
			var frame := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
			kit.box_in(frame, Vector3(1.2, 1.2, 1.2), Vector3(-0.65, 0.6, 0), wood_m)
			kit.box_in(frame, Vector3(1.1, 1.1, 1.1), Vector3(0.6, 0.55, 0.1), wood_m, Vector3(0, 0.2, 0))
			kit.box_in(frame, Vector3(1.0, 1.0, 1.0), Vector3(-0.3, 1.7, 0.05), dark_m, Vector3(0, 0.5, 0))
			kit.box_in(frame, Vector3(0.7, 1.0, 0.7), Vector3(0.4, 0.5, 1.1), dark_m)
			kit.box_in(frame, Vector3(0.74, 0.08, 0.74), Vector3(0.4, 0.8, 1.1), iron)
			_solid(parent, solids, at, 1.4)
		# A fishing shack with a ghost-lit window.
		var shack_at := _polar(31.0, mid)
		var shack := _facing_middle(shack_at)
		kit.box_in(shack, Vector3(4.0, 3.0, 3.4), Vector3(0, 1.5, 0), wood_m)
		kit.box_in(shack, Vector3(4.6, 0.25, 4.0), Vector3(0, 3.25, 0), dark_m, Vector3(0.18, 0, 0))
		kit.box_in(shack, Vector3(1.0, 1.9, 0.06), Vector3(-0.9, 0.95, -1.72), dark_m)
		kit.box_in(shack, Vector3(0.9, 0.7, 0.06), Vector3(0.9, 1.7, -1.72), kit.glow(ghost, 2.0))
		kit.box_in(shack, Vector3(1.6, 0.06, 1.0), Vector3(0.9, 0.35, -2.3), rope)
		_solid_box(parent, solids, shack, Vector3(4.2, 3.2, 3.6))
		if q % 2 == 0:
			_lamp(parent, shack * Vector3(0.9, 1.8, -2.4), ghost, lights, false, 1.6)
		# An overturned rowboat and a net rack.
		var boat_at := _polar(31.0, mid + 20.0)
		var boat := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), boat_at)
		kit.box_in(boat, Vector3(1.5, 0.6, 3.8), Vector3(0, 0.3, 0), dark_m)
		kit.box_in(boat, Vector3(1.2, 0.2, 3.4), Vector3(0, 0.65, 0), wood_m)
		kit.box_in(boat, Vector3(1.0, 0.5, 0.8), Vector3(0, 0.3, 2.1), dark_m, Vector3(0.5, 0, 0))
		_solid(parent, solids, boat_at, 1.6)
		var rack := _facing_middle(_polar(31.0, mid - 20.0))
		for side in [-1.0, 1.0]:
			kit.box_in(rack, Vector3(0.14, 2.2, 0.14), Vector3(side * 1.4, 1.1, 0), dark_m)
		kit.box_in(rack, Vector3(3.0, 0.1, 0.1), Vector3(0, 2.1, 0), dark_m)
		kit.box_in(rack, Vector3(2.6, 1.6, 0.04), Vector3(0, 1.25, 0), kit.stone(Color(0.32, 0.36, 0.3)))
		# Mast stumps out near the edge.
		var stump_at := _polar(40.0, mid + rng.randf_range(-25.0, 25.0))
		kit.box(Vector3(0.6, 4.5, 0.6), stump_at + Vector3(0, 2.25, 0), dark_m, Vector3(0.08, 0, 0.06))
		kit.box(Vector3(2.6, 0.25, 0.25), stump_at + Vector3(0, 3.8, 0), dark_m)
		_solid(parent, solids, stump_at, 0.4)
	# Barrels and rope coils about (walk-through).
	for i in (14 if web else 26):
		var at := _free_spot(rng, lanes, solids, 12.0, RADIUS)
		if at == Vector3.INF:
			continue
		if rng.randf() < 0.5:
			kit.box(Vector3(0.7, 1.0, 0.7), at + Vector3(0, 0.5, 0), dark_m)
			kit.box(Vector3(0.74, 0.08, 0.74), at + Vector3(0, 0.25, 0), iron)
			kit.box(Vector3(0.74, 0.08, 0.74), at + Vector3(0, 0.78, 0), iron)
		else:
			for k in 3:
				kit.box(Vector3(0.9 - k * 0.15, 0.12, 0.9 - k * 0.15), at + Vector3(0, 0.06 + k * 0.12, 0), rope, Vector3(0, k * 0.5, 0))
	# Pilings and rope round the edge.
	var posts := 36
	var post_radius := RADIUS + 3.5
	for i in posts:
		var a := TAU * i / posts
		var at := Vector3(cos(a), 0, sin(a)) * post_radius
		var next := Vector3(cos(TAU * (i + 1) / posts), 0, sin(TAU * (i + 1) / posts)) * post_radius
		kit.box(Vector3(0.5, 3.4, 0.5), at + Vector3(0, 1.2, 0), wood_m)
		kit.box(Vector3(0.55, 0.12, 0.55), at + Vector3(0, 2.95, 0), rope)
		kit.box_in(Transform3D(Basis.looking_at(next - at, Vector3.UP), (at + next) / 2.0), Vector3(0.07, 0.07, at.distance_to(next)), Vector3(0, 2.2, 0), rope)
	# The sunken ships beyond.
	var cloth := kit.stone(Color(0.62, 0.66, 0.6))
	for ship in [[Vector3(0, 0, -78), 0.25], [Vector3(62, 0, 46), -0.9]]:
		var frame := Transform3D(Basis(Vector3.UP, ship[1]) * Basis(Vector3.BACK, 0.18), ship[0])
		kit.box_in(frame, Vector3(7.0, 4.0, 22.0), Vector3.ZERO, dark_m)
		kit.box_in(frame, Vector3(6.0, 1.0, 20.0), Vector3(0, 2.4, 0), wood_m)
		for m in 2:
			var z := -5.0 + m * 9.0
			kit.box_in(frame, Vector3(0.6, 20.0, 0.6), Vector3(0, 11.0, z), dark_m)
			kit.box_in(frame, Vector3(9.0, 0.4, 0.4), Vector3(0, 17.0 - m * 2.0, z), dark_m)
			kit.box_in(frame, Vector3(7.5, 6.0, 0.1), Vector3(0.6, 13.5 - m * 2.0, z + 0.3), cloth, Vector3(0, 0, 0.08))


# --- The Plague Carnival (Plague) ---------------------------------------------------

## A rotting fairground: four trampled midways from the plaza, lined with
## striped game booths under strings of sick green bulbs; a high striker by
## the plaza, a tent in each quarter (the broken carousel in one), oil-drum
## fires, hay and barrels about, the wooden fence and the dead Ferris wheel.
static func _carnival(theme: Dictionary, kit: PropKit, parent: Node3D, rng: RandomNumberGenerator, lights: Array, solids: Array) -> void:
	var web := Settings.use_web_profile()
	var green_c := Color(0.32, 0.45, 0.14)
	var purple_c := Color(0.32, 0.12, 0.38)
	var green := kit.stone(green_c)
	var purple := kit.stone(purple_c)
	var wood := kit.stone(Color(0.24, 0.17, 0.11))
	var iron := kit.metal(Color(0.18, 0.18, 0.2), 0.6)
	var paint := kit.stone(Color(0.82, 0.78, 0.62))
	var bulb := kit.glow(Color(0.7, 1.0, 0.3), 3.0)
	var fire: Color = theme.fire
	var lanes := [45.0, 135.0, 225.0, 315.0]
	# Trampled midways.
	var dirt := [Color(0.22, 0.18, 0.11), Color(0.19, 0.16, 0.1)]
	for i in 28:
		kit.path(_polar(PLAZA + 0.8, 360.0 * i / 28.0), _polar(PLAZA + 0.8, 360.0 * (i + 1) / 28.0), 1.8, rng, dirt)
	for angle in lanes:
		kit.path(_polar(PLAZA + 1.6, angle), _polar(RADIUS + 3.0, angle), 3.4, rng, dirt)
	# Bulb strings along each midway, poles both sides.
	for angle in lanes:
		for side in [-1.0, 1.0]:
			var poles: Array[Vector3] = []
			for k in 5:
				poles.append(_polar(13.0 + k * 7.5, angle) + _polar(2.6, angle + 90.0) * side)
			for k in poles.size():
				kit.box(Vector3(0.18, 5.0, 0.18), poles[k] + Vector3(0, 2.5, 0), wood)
				if k + 1 < poles.size():
					var bulbs := 4 if web else 7
					for b in bulbs:
						var t := (b + 0.5) / bulbs
						var at := poles[k].lerp(poles[k + 1], t)
						kit.box(Vector3.ONE * 0.16, at + Vector3(0, 4.8 - sin(t * PI) * 1.0, 0), bulb)
	# Game booths lining the midways.
	for angle in lanes:
		for side in [-1.0, 1.0]:
			for r in ([18.0] if web else [18.0, 29.0]):
				var at := _polar(r, angle + side * rad_to_deg(5.2 / r))
				var frame := Transform3D(Basis.looking_at(-_polar(1.0, angle + 90.0) * side, Vector3.UP), at)
				kit.box_in(frame, Vector3(2.6, 1.0, 1.2), Vector3(0, 0.5, 0), wood)
				kit.box_in(frame, Vector3(2.8, 0.1, 1.4), Vector3(0, 1.05, 0), paint)
				for px in [-1.25, 1.25]:
					for pz in [-0.55, 0.55]:
						kit.box_in(frame, Vector3(0.1, 2.4, 0.1), Vector3(px, 1.2, pz), wood)
				for k in 6:
					kit.box_in(frame, Vector3(0.47, 0.08, 1.7), Vector3(-1.2 + k * 0.48, 2.45, -0.15), green if k % 2 == 0 else purple, Vector3(0.25, 0, 0))
				kit.box_in(frame, Vector3(2.4, 1.0, 0.1), Vector3(0, 1.6, 0.6), purple)
				for k in 3:
					kit.box_in(frame, Vector3(0.22, 0.28, 0.22), Vector3(-0.7 + k * 0.7, 1.25, 0.1), kit.glow([Color(1.0, 0.3, 0.6), Color(0.3, 0.8, 1.0), Color(1.0, 0.85, 0.2)][k], 2.0))
				_solid_box(parent, solids, frame, Vector3(2.8, 2.4, 1.4))
	# The high striker at the plaza's edge.
	var striker := _polar(12.5, 0.0)
	kit.box(Vector3(0.3, 6.0, 0.3), striker + Vector3(0, 3.0, 0), paint)
	for k in 6:
		kit.box(Vector3(0.34, 0.12, 0.34), striker + Vector3(0, 0.8 + k * 0.9, 0), purple if k % 2 else green)
	kit.box(Vector3(0.6, 0.6, 0.3), striker + Vector3(0, 6.2, 0), kit.glow(Color(1.0, 0.8, 0.3), 2.5))
	kit.box(Vector3(1.4, 0.3, 1.0), striker + Vector3(0, 0.15, 0.6), iron)
	_solid(parent, solids, striker, 0.4)
	# A tent in each quarter (the broken carousel in the first).
	for q in 4:
		var at := _polar(32.0, 90.0 * q)
		if q == 0:
			_carousel(kit, parent, at, green, purple, paint, iron)
			_solid(parent, solids, at, 5.2)
			continue
		var size := rng.randf_range(4.5, 6.0)
		var frame := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
		for k in 6:
			var w := size * (1.0 - k * 0.15)
			kit.box_in(frame, Vector3(w, 0.7, w), Vector3(0, 0.35 + k * 0.7, 0), green if k % 2 == 0 else purple)
		kit.box_in(frame, Vector3(0.08, 1.2, 0.08), Vector3(0, 4.7, 0), wood)
		kit.box_in(frame, Vector3(0.6, 0.35, 0.03), Vector3(0.3, 5.1, 0), purple)
		_solid(parent, solids, at, size * 0.6)
	# Oil-drum fires.
	for q in 4:
		for side in [-1.0, 1.0]:
			var at := _polar(22.0, 90.0 * q + side * 18.0)
			kit.box(Vector3(0.7, 1.0, 0.7), at + Vector3(0, 0.5, 0), iron)
			Look.flame(parent, at + Vector3(0, 1.15, 0), 2.0, not web, fire)
			if side > 0.0:
				_lamp(parent, at + Vector3(0, 1.6, 0), Color(fire).lightened(0.25), lights, true, 2.2)
			_solid(parent, solids, at, 0.45)
	# Hay bales and barrels (walk-through).
	var hay := kit.stone(Color(0.5, 0.42, 0.2))
	for i in (14 if web else 26):
		var at := _free_spot(rng, lanes, solids, 12.0, RADIUS)
		if at == Vector3.INF:
			continue
		if rng.randf() < 0.5:
			kit.box(Vector3(1.1, 0.5, 0.6), at + Vector3(0, 0.25, 0), hay, Vector3(0, rng.randf() * TAU, 0))
		else:
			kit.box(Vector3(0.6, 0.9, 0.6), at + Vector3(0, 0.45, 0), wood)
			kit.box(Vector3(0.5, 0.04, 0.5), at + Vector3(0, 0.91, 0), kit.glow(Color(0.5, 1.0, 0.2), 1.5))
	# The dead Ferris wheel beyond the fence.
	var wheel := Transform3D(Basis(Vector3.UP, 0.2), Vector3(10, 0, -80))
	kit.box_in(wheel, Vector3(1.0, 18.0, 1.0), Vector3(-5, 9.0, 0), iron, Vector3(0, 0, 0.28))
	kit.box_in(wheel, Vector3(1.0, 18.0, 1.0), Vector3(5, 9.0, 0), iron, Vector3(0, 0, -0.28))
	for k in 24:
		var a := k * TAU / 24.0
		kit.box_in(wheel, Vector3(0.4, 3.0, 0.4), Vector3(cos(a) * 14.0, 18.0 + sin(a) * 14.0, 0), iron, Vector3(0, 0, a))
		if k % 3 == 0:
			kit.box_in(wheel, Vector3(0.2, 14.0, 0.2), Vector3(cos(a) * 7.0, 18.0 + sin(a) * 7.0, 0), iron, Vector3(0, 0, a + PI / 2.0))
			kit.box_in(wheel, Vector3(1.6, 1.2, 1.4), Vector3(cos(a) * 14.0, 16.8 + sin(a) * 14.0, 0), purple if k % 2 else green)
		if k % 2 == 0:
			kit.box_in(wheel, Vector3.ONE * 0.3, Vector3(cos(a) * 14.6, 18.0 + sin(a) * 14.6, 0), bulb)
	# The fence round the fairground.
	for i in 12:
		var a := TAU * i / 12
		var b := TAU * (i + 1) / 12
		var from := Vector2.from_angle(a) * (RADIUS + 4.0)
		var to := Vector2.from_angle(b) * (RADIUS + 4.0)
		var run := Scenery.fence(parent, from.distance_to(to))
		run.position = Vector3(from.x, 0, from.y)
		run.rotation.y = -atan2(to.y - from.y, to.x - from.x)


static func _carousel(kit: PropKit, parent: Node3D, at: Vector3, green: Material, purple: Material, paint: Material, iron: Material) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = 0.3
	parent.add_child(root)
	var base := CylinderMesh.new()
	base.top_radius = 5.0
	base.bottom_radius = 5.2
	base.height = 0.5
	base.radial_segments = 16
	base.material = paint
	var base_node := MeshInstance3D.new()
	base_node.mesh = base
	base_node.position.y = 0.25
	root.add_child(base_node)
	for k in 3:
		var canopy := CylinderMesh.new()
		canopy.top_radius = 5.2 - k * 1.7
		canopy.bottom_radius = 5.4 - k * 1.7
		canopy.height = 0.5
		canopy.radial_segments = 16
		canopy.material = green if k % 2 == 0 else purple
		var canopy_node := MeshInstance3D.new()
		canopy_node.mesh = canopy
		canopy_node.position.y = 5.0 + k * 0.5
		canopy_node.rotation.z = 0.12  # It's slumped.
		root.add_child(canopy_node)
	var frame := Transform3D(Basis(Vector3.UP, 0.3), at)
	kit.box_in(frame, Vector3(0.5, 5.0, 0.5), Vector3(0, 2.7, 0), iron)
	for h in 6:
		var a := h * TAU / 6.0
		var spot := Vector3(cos(a) * 3.6, 0, sin(a) * 3.6)
		kit.box_in(frame, Vector3(0.08, 4.5, 0.08), spot + Vector3(0, 2.6, 0), iron)
		var horse := frame * Transform3D(Basis.from_euler(Vector3(0, -a, 0 if h % 3 else 1.2)), spot + Vector3(0, 1.6 if h % 3 else 0.6, 0))
		kit.box_in(horse, Vector3(0.4, 0.5, 1.2), Vector3.ZERO, paint)
		kit.box_in(horse, Vector3(0.3, 0.6, 0.35), Vector3(0, 0.45, -0.6), paint, Vector3(0.4, 0, 0))
		for l in 4:
			kit.box_in(horse, Vector3(0.1, 0.6, 0.1), Vector3(0.15 * (1 if l % 2 else -1), -0.5, 0.45 * (1 if l < 2 else -1)), paint)


# --- The Coffin King's Colosseum (Crown) ---------------------------------------------

## A blood-red colosseum: the King's crown inlaid in the sand, a ring of
## columns (some broken) round the plaza, statues of the King, gold braziers,
## weapon racks and lava cracks, inside the arcade walls and stands full of
## the dead.
static func _colosseum(theme: Dictionary, kit: PropKit, parent: Node3D, rng: RandomNumberGenerator, lights: Array, solids: Array) -> void:
	var web := Settings.use_web_profile()
	var stone_c := Color(0.36, 0.12, 0.1)
	var stone := kit.stone(stone_c)
	var stone_dark := kit.stone(Color(0.2, 0.07, 0.06))
	var gold := kit.metal(Color(0.95, 0.72, 0.25), 0.8)
	var crimson := kit.stone(Color(0.55, 0.05, 0.07))
	var bone := Color(0.82, 0.78, 0.68)
	var marble := kit.stone(Color(0.58, 0.52, 0.48))
	var lava := kit.glow(Color(1.0, 0.4, 0.05), 2.5)
	var fire: Color = theme.fire
	# The crown in the sand and a red ring round the plaza.
	var sand_red := kit.stone(Color(0.5, 0.22, 0.12))
	for i in 40:
		var a := TAU * i / 40.0
		kit.box(Vector3(1.6, 0.02, 0.5), Vector3(cos(a), 0, sin(a)) * (PLAZA + 0.6) + Vector3(0, 0.01, 0), sand_red, Vector3(0, -a + PI / 2.0, 0))
	kit.box(Vector3(4.0, 0.02, 0.8), Vector3(0, 0.012, 0.8), gold)
	for k in 5:
		kit.box(Vector3(0.5, 0.02, 1.2 if k % 2 == 0 else 0.8), Vector3(-1.6 + k * 0.8, 0.012, -0.2 - (0.2 if k % 2 == 0 else 0.0)), gold)
	# Columns round the plaza.
	for k in 8:
		var at := _polar(19.0, 22.5 + 45.0 * k)
		var broken := k % 3 == 1
		var h := 2.2 if broken else 6.0
		kit.box(Vector3(1.4, 0.4, 1.4), at + Vector3(0, 0.2, 0), marble)
		kit.box(Vector3(0.9, h, 0.9), at + Vector3(0, 0.4 + h / 2.0, 0), marble, Vector3(0, k * 0.4, 0))
		if broken:
			for d in 2:
				var piece := at + _polar(1.4 + d * 1.1, rng.randf() * 360.0)
				kit.box(Vector3(0.85, 0.85, 1.0), piece + Vector3(0, 0.42, 0), marble, Vector3(0, rng.randf() * TAU, PI / 2.0))
		else:
			kit.box(Vector3(1.3, 0.5, 1.3), at + Vector3(0, 6.6, 0), marble)
			kit.box(Vector3(1.32, 0.12, 1.32), at + Vector3(0, 6.9, 0), gold)
		_solid(parent, solids, at, 0.65)
	# Statues of the King facing the middle.
	for q in 4:
		var at := _polar(30.0, 90.0 * q)
		var frame := _facing_middle(at)
		kit.box_in(frame, Vector3(2.2, 1.6, 2.2), Vector3(0, 0.8, 0), stone)
		kit.box_in(frame, Vector3(2.4, 0.2, 2.4), Vector3(0, 1.7, 0), gold)
		kit.box_in(frame, Vector3(1.3, 1.6, 0.8), Vector3(0, 2.6, 0), marble)
		kit.box_in(frame, Vector3(1.6, 1.4, 0.9), Vector3(0, 4.1, 0), marble)
		kit.box_in(frame, Vector3(0.7, 0.75, 0.7), Vector3(0, 5.2, 0), marble)
		for k in 5:
			kit.box_in(frame, Vector3(0.14, 0.35 if k % 2 == 0 else 0.22, 0.14), Vector3(-0.3 + k * 0.15, 5.75, 0), gold)
		for side in [-1.0, 1.0]:
			kit.box_in(frame, Vector3(0.4, 1.4, 0.45), Vector3(side * 0.95, 4.3, -0.1), marble, Vector3(-0.3, 0, side * 0.15))
		kit.box_in(frame, Vector3(0.12, 2.6, 0.12), Vector3(0.95, 4.4, -0.6), gold)
		kit.box_in(frame, Vector3(1.8, 1.0, 0.06), Vector3(0, 0.8, -1.12), crimson)
		_solid(parent, solids, at, 1.3)
	# Gold braziers on plinths.
	for q in 4:
		var at := _polar(26.0, 45.0 + 90.0 * q)
		kit.box(Vector3(1.0, 1.6, 1.0), at + Vector3(0, 0.8, 0), stone)
		kit.box(Vector3(1.4, 0.3, 1.4), at + Vector3(0, 1.75, 0), gold)
		Look.flame(parent, at + Vector3(0, 2.0, 0), 2.6, not web, fire)
		_lamp(parent, at + Vector3(0, 2.4, 0), Color(fire).lightened(0.25), lights, true, 2.6)
		_solid(parent, solids, at, 0.75)
	# Weapon racks and lava cracks (walk-through).
	var wood := kit.stone(Color(0.25, 0.15, 0.08))
	var steel := kit.metal(Color(0.55, 0.55, 0.6), 0.8)
	for q in 4:
		var rack := _facing_middle(_polar(36.0, 90.0 * q + 20.0))
		for side in [-1.0, 1.0]:
			kit.box_in(rack, Vector3(0.14, 1.8, 0.14), Vector3(side * 1.2, 0.9, 0), wood)
		kit.box_in(rack, Vector3(2.6, 0.12, 0.14), Vector3(0, 1.6, 0), wood)
		for k in 4:
			kit.box_in(rack, Vector3(0.08, 1.5, 0.04), Vector3(-0.8 + k * 0.53, 0.95, -0.12), steel, Vector3(0, 0, 0.12))
	for i in (14 if web else 26):
		var at := _free_spot(rng, [], solids, 10.0, RADIUS - 2.0)
		if at == Vector3.INF:
			continue
		var frame := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at)
		var length := rng.randf_range(2.0, 5.0)
		kit.box_in(frame, Vector3(0.12, 0.02, length), Vector3(0, 0.01, 0), lava)
		kit.box_in(frame, Vector3(0.08, 0.02, length * 0.5), Vector3(0.3, 0.01, length * 0.4), lava, Vector3(0, 0.6, 0))
	# Crown banners on tall poles.
	for i in 8:
		var a := 360.0 * i / 8.0
		var frame := _facing_middle(_polar(RADIUS - 2.0, a))
		kit.box_in(frame, Vector3(0.25, 9.0, 0.25), Vector3(0, 4.5, 0), gold)
		kit.box_in(frame, Vector3(2.4, 4.2, 0.08), Vector3(0, 6.2, -0.2), crimson)
		kit.box_in(frame, Vector3(1.4, 0.35, 0.1), Vector3(0, 6.6, -0.26), gold)
		for p in 3:
			kit.box_in(frame, Vector3(0.24, 0.4, 0.1), Vector3(-0.5 + p * 0.5, 7.0, -0.26), gold)
	# The arcade wall and the stands full of the dead.
	var dark := Color(0.04, 0.03, 0.03)
	_ring_wall(RADIUS + 5.0, 30, func(frame: Transform3D, width: float, i: int) -> void:
		kit.box_in(frame, Vector3(width * 0.25, 5.5, 1.6), Vector3(-width * 0.38, 2.75, 0), stone)
		kit.box_in(frame, Vector3(width * 0.25, 5.5, 1.6), Vector3(width * 0.38, 2.75, 0), stone)
		kit.box_in(frame, Vector3(width, 1.3, 1.6), Vector3(0, 4.85, 0), stone)
		kit.box_in(frame, Vector3(width * 0.5, 4.2, 0.2), Vector3(0, 2.1, -0.7), stone_dark)
		kit.box_in(frame, Vector3(width + 0.05, 0.25, 1.7), Vector3(0, 5.55, 0), gold)
		for tier in 3:
			var back := 1.8 + tier * 2.0
			kit.box_in(frame, Vector3(width, 1.6, 2.0), Vector3(0, 5.8 + tier * 1.6, back), stone_dark)
			if web and tier > 1:
				continue
			for seat in 4:
				if rng.randf() < 0.25:
					continue
				var fan := Vector3(-width / 2.0 + (seat + 0.5) * width / 4.0, 6.6 + tier * 1.6, back - 0.3)
				kit.skull(frame * Transform3D(Basis.IDENTITY, fan + Vector3(0, 0.4, 0)), 0.32, bone, dark)
				kit.box_in(frame, Vector3(0.38, 0.5, 0.22), fan, kit.stone(bone))
				if rng.randf() < 0.4:
					kit.box_in(frame, Vector3(0.08, 0.5, 0.08), fan + Vector3(0.24, 0.55, 0), kit.stone(bone), Vector3(0, 0, -0.3))
		Scenery.solid(parent, Vector3(width, 5.5, 1.6), frame * Vector3(0, 2.75, 0), Vector3(0, frame.basis.get_euler().y, 0)))
