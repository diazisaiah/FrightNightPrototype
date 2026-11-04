class_name GraveyardScenery
## The Gravedigger Division (Arena tier 1) laid out as a real cemetery
## (2026-11-04, the places update), in three rings:
##   - a clear plaza in the middle, ringed by a flagstone path;
##   - four flagstone paths out to the fence (the north-east one ends at the
##     gate), lantern posts along them;
##   - between the paths, a quadrant each: a weeping angel near the plaza,
##     two family plots, two big dead oaks and an obelisk, then a mausoleum;
##   - the outer edge: lone graves, smaller oaks and the iron fence.
## Angels, obelisks, oaks and mausoleums are solid to you AND monsters
## (Scenery.PROP_LAYER; monsters steer round them); graves, plots and paths
## are walk-through. Everything static is batched by PropKit.

const RADIUS := 45.0
const PLAZA := 9.5
## The paths run out at these angles (degrees); the quadrants sit between.
const PATHS := [45.0, 135.0, 225.0, 315.0]
const GATE_PATH := 0


## Builds it under parent. Returns {"lights": the lanterns' lights (they
## flicker like torches), "solids": Vector3(x, z, radius) per solid prop, to
## keep spawns out of them}.
static func build(parent: Node3D, rng: RandomNumberGenerator) -> Dictionary:
	var web := Settings.use_web_profile()
	var kit := PropKit.new()
	var lights: Array = []
	var solids: Array = []
	Scenery.night_sky(parent, rng)
	Scenery.grass(parent, RADIUS + 8.0, 5000 if web else 14000, rng, PLAZA * 0.5, _paved.bind(web))
	# Bare earth and dark patches, and stones in the grass.
	var dirt := kit.stone(Scenery.DIRT)
	var dark_grass := kit.stone(Scenery.GRASS.darkened(0.45))
	for i in (30 if web else 60):
		var spot := _polar(rng.randf_range(0.0, RADIUS), rng.randf() * 360.0)
		kit.box(Vector3(rng.randf_range(1.0, 4.0), 0.03, rng.randf_range(1.0, 4.0)), spot + Vector3(0, 0.015 + rng.randf() * 0.01, 0), dirt if rng.randf() < 0.6 else dark_grass, Vector3(0, rng.randf() * TAU, 0))
	var pebble := kit.stone(Scenery.STONE.darkened(0.3))
	for i in (40 if web else 90):
		var spot := _polar(rng.randf_range(PLAZA, RADIUS + 3.0), rng.randf() * 360.0)
		if _paved(Vector2(spot.x, spot.z), web):
			continue
		var size := rng.randf_range(0.12, 0.35)
		kit.box(Vector3(size, size * 0.6, size * rng.randf_range(0.7, 1.3)), spot + Vector3(0, size * 0.25, 0), pebble, Vector3(0, rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))

	# The plaza's ring path and the four paths out.
	var segments := 28
	for i in segments:
		kit.path(_polar(PLAZA + 0.8, 360.0 * i / segments), _polar(PLAZA + 0.8, 360.0 * (i + 1) / segments), 1.6, rng)
	for angle in PATHS:
		kit.path(_polar(PLAZA + 1.6, angle), _polar(RADIUS + 4.0, angle), 2.2, rng)
	# Lanterns along the paths, on alternate sides; the inner ring is lit
	# everywhere, two outer ones only on desktop (phones: four lights).
	var glass := Color(1.0, 0.68, 0.32)
	for p in PATHS.size():
		var angle: float = PATHS[p]
		for step in 4:
			var r := 14.0 + step * 10.0
			var side := 1.0 if (step + p) % 2 == 0 else -1.0
			var at := _polar(r, angle) + _polar(1.7, angle + 90.0) * side
			var lamp := kit.lantern_post(_facing_out(at), glass)
			if step == 0 or (step == 2 and p % 2 == 0 and not web):
				var light := Look.fire_light(Color(1.0, 0.62, 0.28), 2.0, 13.0, false)
				light.position = lamp
				parent.add_child(light)
				lights.append(light)

	# Rows of graves lining the paths, facing them.
	for angle in PATHS:
		var across := _polar(1.0, angle + 90.0)
		var r := 12.5
		while r < 36.0:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.2:
					continue
				var at: Vector3 = _polar(r, angle) + across * 3.0 * side
				var frame := Transform3D(Basis.looking_at(across * side, Vector3.UP), at)
				frame.basis = frame.basis.rotated(Vector3.UP, rng.randf_range(-0.12, 0.12))
				kit.grave(frame, rng.randi_range(0, 4), rng.randi_range(0, 2))
			r += 2.6

	# The quadrants.
	var plots: Array[Vector3] = []
	for q in 4:
		var mid := 90.0 * q
		_solid(parent, solids, kit_angel(kit, _polar(16.0, mid), q), 0.8)
		for side in [-1.0, 1.0]:
			kit.grave(_facing_in(_polar(15.0, mid + side * 11.0)), rng.randi_range(0, 4), rng.randi_range(0, 2))
			kit.plot(_facing_in(_polar(22.5, mid + side * 15.0)), 5.6, 5.0, rng)
			plots.append(_polar(22.5, mid + side * 15.0))
			var oak_at := _polar(29.5, mid + side * 17.0)
			kit.oak(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), oak_at), rng, rng.randf_range(5.5, 7.0))
			_solid(parent, solids, oak_at, 0.5)
		var obelisk_at := _polar(31.0, mid)
		kit.obelisk(_facing_middle(obelisk_at), q % 3)
		_solid(parent, solids, obelisk_at, 0.8)
		# A mausoleum in each quadrant (two on phones), a plot where it isn't.
		if not web or q % 2 == 0:
			var crypt_at := _polar(38.5, mid)
			var crypt := Node3D.new()
			crypt.transform = _facing_in(crypt_at)  # Its door (+Z) toward the middle.
			parent.add_child(crypt)
			Scenery.crypt(crypt, rng, true)
			solids.append(Vector3(crypt_at.x, crypt_at.z, 2.4))
		else:
			kit.plot(_facing_in(_polar(38.5, mid)), 6.8, 5.0, rng)
		# The outer edge: smaller oaks and lone graves.
		for i in (2 if web else 3):
			var tree_at := _polar(rng.randf_range(41.0, 46.0), mid + rng.randf_range(-32.0, 32.0))
			kit.oak(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), tree_at), rng, rng.randf_range(4.0, 5.5))
			_solid(parent, solids, tree_at, 0.45)
	# Lone graves through the middle ring, clear of the paths, plots and props.
	var placed := 0
	var tries := 0
	while placed < (18 if web else 36) and tries < 300:
		tries += 1
		var r := rng.randf_range(12.0, 34.0)
		var angle := rng.randf() * 360.0
		if _near_path(angle, rad_to_deg(4.5 / r)):
			continue
		var at := _polar(r, angle)
		if plots.any(func(p: Vector3) -> bool: return p.distance_to(at) < 4.6):
			continue
		if solids.any(func(o: Vector3) -> bool: return Vector2(o.x, o.y).distance_to(Vector2(at.x, at.z)) < o.z + 1.4):
			continue
		var frame := _facing_in(at)
		frame.basis = frame.basis.rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		kit.grave(frame, rng.randi_range(0, 5), rng.randi_range(0, 2))
		placed += 1
	for i in (14 if web else 30):
		var angle := rng.randf() * 360.0
		if _near_path(angle, 5.0):
			continue
		var at := _polar(rng.randf_range(34.0, RADIUS + 2.0), angle)
		var frame := _facing_in(at)
		frame.basis = frame.basis.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4))
		kit.grave(frame, rng.randi_range(0, 5), rng.randi_range(0, 2))

	_fence_and_gate(parent, kit)
	kit.flush(parent)
	Scenery.mist(parent, Vector3(0, 0.5, 0), Vector3(RADIUS, 0.3, RADIUS), 35 if web else 90)
	Scenery.wisps(parent, Vector3(0, 1.4, 0), Vector3(RADIUS * 0.8, 1.0, RADIUS * 0.8), Color(0.45, 1.0, 0.75), 20 if web else 50)
	return {"lights": lights, "solids": solids}


static func kit_angel(kit: PropKit, at: Vector3, tone: int) -> Vector3:
	kit.angel(_facing_middle(at), tone)
	return at


## The iron fence round the edge, with a gap and two gate pillars where the
## gate path meets it.
static func _fence_and_gate(parent: Node3D, kit: PropKit) -> void:
	var fence_radius := RADIUS + 4.0
	var gate_angle := deg_to_rad(PATHS[GATE_PATH])
	var sides := 12
	var half_gap := 2.0
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		var from := Vector2.from_angle(a) * fence_radius
		var to := Vector2.from_angle(b) * fence_radius
		var runs := [[from, to]]
		if gate_angle > a and gate_angle < b:
			var mid := Vector2.from_angle(gate_angle) * fence_radius
			var along := (to - from).normalized()
			runs = [[from, mid - along * half_gap], [mid + along * half_gap, to]]
		for pair in runs:
			var start: Vector2 = pair[0]
			var end: Vector2 = pair[1]
			var run := Scenery.fence(parent, start.distance_to(end))
			run.position = Vector3(start.x, 0, start.y)
			run.rotation.y = -atan2(end.y - start.y, end.x - start.x)
	var pillar := kit.grave_tone(0)
	var cap := kit.grave_tone(2)
	for side in [-1.0, 1.0]:
		var at: Vector3 = _polar(fence_radius, PATHS[GATE_PATH]) + _polar(half_gap + 0.4, PATHS[GATE_PATH] + 90.0) * side
		kit.box(Vector3(0.9, 3.2, 0.9), at + Vector3(0, 1.6, 0), pillar)
		kit.box(Vector3(1.1, 0.2, 1.1), at + Vector3(0, 3.3, 0), cap)
		kit.box(Vector3(0.5, 0.5, 0.5), at + Vector3(0, 3.65, 0), pillar, Vector3(0, PI / 4, 0))
		Scenery.solid(parent, Vector3(0.9, 3.2, 0.9), at + Vector3(0, 1.6, 0))


static func _solid(parent: Node3D, solids: Array, at: Vector3, radius: float) -> void:
	Scenery.solid(parent, Vector3(radius * 2.0, 3.0, radius * 2.0), Vector3(at.x, 1.5, at.z), Vector3.ZERO, radius, true)
	solids.append(Vector3(at.x, at.z, radius))


## A point on the floor r out at angle degrees (0 = +X, 90 = +Z).
static func _polar(r: float, degrees: float) -> Vector3:
	var a := deg_to_rad(degrees)
	return Vector3(cos(a) * r, 0, sin(a) * r)


## A frame at at whose +Z faces the middle (graves face the paths' hub).
static func _facing_in(at: Vector3) -> Transform3D:
	var inward := Vector3(-at.x, 0, -at.z)
	if inward.length_squared() < 0.001:
		return Transform3D(Basis.IDENTITY, at)
	return Transform3D(Basis.looking_at(-inward, Vector3.UP), at)


## A frame at at whose front (-Z) faces the middle (statues, plaques).
static func _facing_middle(at: Vector3) -> Transform3D:
	var frame := _facing_in(at)
	frame.basis = frame.basis.rotated(Vector3.UP, PI)
	return frame


## A frame at at whose +X points away from the middle (lantern arms).
static func _facing_out(at: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -atan2(at.z, at.x)), at)


## On the flagstones or inside a family plot (no grass or pebbles there).
static func _paved(spot: Vector2, web: bool) -> bool:
	var r := spot.length()
	if absf(r - (PLAZA + 0.8)) < 1.05:
		return true
	if r > PLAZA:
		for angle in PATHS:
			var along := Vector2.from_angle(deg_to_rad(angle))
			if along.dot(spot) > 0.0 and absf(along.cross(spot)) < 1.35:
				return true
	for q in 4:
		var plots := [_polar(22.5, 90.0 * q - 15.0), _polar(22.5, 90.0 * q + 15.0)]
		if web and q % 2 == 1:
			plots.append(_polar(38.5, 90.0 * q))
		for plot in plots:
			if spot.distance_to(Vector2(plot.x, plot.z)) < 3.1:
				return true
	return false


static func _near_path(degrees: float, margin: float) -> bool:
	for angle in PATHS:
		if absf(wrapf(degrees - angle, -180.0, 180.0)) < margin:
			return true
	return false
