class_name ArenaScenery
## The Underworld Arena's deeper divisions (Themes.ARENA): each a 45 m field
## like the graveyard, dressed its own way. No collision (scenery never traps
## anyone); everything beyond the walls is backdrop. build() returns the
## flame lights so the world can flicker them.

const RADIUS := 45.0


static func build(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator) -> Array:
	var lights: Array = []
	Scenery.night_sky(parent, rng)
	match theme.id:
		"ossuary":
			_ossuary(theme, parent, rng, lights)
		"pier":
			_pier(theme, parent, rng, lights)
		"carnival":
			_carnival(theme, parent, rng, lights)
		"colosseum":
			_colosseum(theme, parent, rng, lights)
	var web := Settings.use_web_profile()
	var mist := Scenery.mist(parent, Vector3(0, 0.5, 0), Vector3(RADIUS, 0.3, RADIUS), 35 if web else 90)
	(mist.mesh.material as StandardMaterial3D).albedo_color = Color(theme.mist, 0.09)
	Scenery.wisps(parent, Vector3(0, 1.4, 0), Vector3(RADIUS * 0.8, 1.0, RADIUS * 0.8), theme.wisps, 20 if web else 50)
	return lights


# --- Helpers ---

## A node at spot (x, z). With facing = -angle + PI / 2 for a spot at that
## angle round the middle, its local +Z points outward and -Z at the middle.
static func _at(parent: Node3D, spot: Vector2, facing := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(spot.x, 0, spot.y)
	node.rotation.y = facing
	parent.add_child(node)
	return node


## A spot in the field, at least min_distance from the middle.
static func _spot(rng: RandomNumberGenerator, min_distance: float, max_distance := RADIUS + 2.0) -> Vector2:
	return Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_distance, max_distance)


## A brazier or lantern flame with its light.
static func _fire(parent: Node3D, pos: Vector3, theme: Dictionary, lights: Array, size := 1.4, energy := 2.4) -> void:
	Look.flame(parent, pos, size, true, theme.fire)
	var light := Look.fire_light(Color(theme.fire).lightened(0.25), energy, 11.0)
	light.position = pos + Vector3(0, 0.3, 0)
	parent.add_child(light)
	lights.append(light)


static func _skull(parent: Node3D, pos: Vector3, size: float, bone: Material, dark: Material, rot := 0.0) -> void:
	Scenery.box(parent, Vector3(1.0, 0.85, 0.9) * size, pos, bone, Vector3(0, rot, 0))
	var face := Vector3(sin(rot), 0, cos(rot)) * -0.46 * size
	var side := Vector3(cos(rot), 0, -sin(rot))
	for s in [-1.0, 1.0]:
		Scenery.box(parent, Vector3(0.26, 0.22, 0.05) * size, pos + face + side * 0.22 * s * size + Vector3(0, 0.06, 0) * size, dark, Vector3(0, rot, 0))
	Scenery.box(parent, Vector3(0.12, 0.14, 0.05) * size, pos + face + Vector3(0, -0.16, 0) * size, dark, Vector3(0, rot, 0))


# --- The Ossuary Pit (Bone) ---

## A sunken pit walled with stacked bones and skulls, skull pillars topped
## with blue ghost-fire, giant ribcages and bone piles across the floor.
static func _ossuary(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator, lights: Array) -> void:
	var web := Settings.use_web_profile()
	var bone := Look.block_material(Color(0.78, 0.74, 0.64))
	var bone_dark := Look.block_material(Color(0.62, 0.58, 0.5))
	var dark := Look.block_material(Color(0.05, 0.05, 0.07))
	# The bone wall around the pit, skulls set in rows along its face.
	var sides := 28
	var wall_radius := RADIUS + 5.0
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var spot := Vector2.from_angle(a) * wall_radius
		var node := _at(parent, spot, -a + PI / 2.0)
		var width := TAU * wall_radius / sides + 0.4
		Scenery.box(node, Vector3(width, 4.2, 1.6), Vector3(0, 2.1, 0), bone_dark)
		Scenery.box(node, Vector3(width, 0.35, 1.9), Vector3(0, 4.3, 0), bone)
		for row in (1 if web else 2):
			for k in 5:
				_skull(node, Vector3(-width / 2.0 + (k + 0.5) * width / 5.0, 1.2 + row * 1.5, -0.82), 0.5, bone, dark)
		# Ghost-fire along the top lights the skulls.
		if i % 4 == 0:
			_fire(node, Vector3(0, 4.7, 0), theme, lights, 2.0, 3.0)
	# Skull pillars with blue braziers.
	for i in 8:
		var spot := Vector2.from_angle(TAU * i / 8.0 + 0.2) * rng.randf_range(18.0, 34.0)
		var node := _at(parent, spot, rng.randf() * TAU)
		for k in 6:
			_skull(node, Vector3(0, 0.3 + k * 0.62, 0), 0.7, bone if k % 2 == 0 else bone_dark, dark, k * 0.7)
		Scenery.box(node, Vector3(0.9, 0.2, 0.9), Vector3(0, 4.05, 0), bone_dark)
		_fire(node, Vector3(0, 4.3, 0), theme, lights, 2.2, 2.6)
	# Giant ribcages, half sunk in the ash.
	for i in 3:
		var spot := Vector2.from_angle(TAU * i / 3.0 + 1.0) * rng.randf_range(30.0, 40.0)
		var node := _at(parent, spot, rng.randf() * TAU)
		Scenery.box(node, Vector3(0.6, 0.6, 9.0), Vector3(0, 0.6, 0), bone)
		for r in 6:
			var z := -3.6 + r * 1.45
			for s in [-1.0, 1.0]:
				Scenery.box(node, Vector3(0.35, 2.4, 0.35), Vector3(1.1 * s, 1.6, z), bone, Vector3(0, 0, -0.5 * s))
				Scenery.box(node, Vector3(0.32, 2.0, 0.32), Vector3(2.0 * s, 3.4, z), bone, Vector3(0, 0, 0.35 * s))
		_skull(node, Vector3(0, 1.2, 5.2), 2.2, bone, dark)
	# Bone piles.
	for i in (14 if web else 26):
		var node := _at(parent, _spot(rng, 7.0), rng.randf() * TAU)
		for b in rng.randi_range(4, 8):
			Scenery.box(node, Vector3(rng.randf_range(0.4, 0.9), 0.09, 0.1), Vector3(rng.randf_range(-0.5, 0.5), 0.05 + b * 0.02, rng.randf_range(-0.5, 0.5)), bone, Vector3(0, rng.randf() * TAU, 0))
		if rng.randf() < 0.6:
			_skull(node, Vector3(0, 0.2, 0), 0.4, bone, dark, rng.randf() * TAU)


# --- The Drowned Pier (Ghost) ---

## A ring of old dock planks over black water, ghost lanterns on poles,
## pilings and ropes round the edge, crates and barrels, and a sunken ship's
## masts rising from the fog beyond.
static func _pier(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator, lights: Array) -> void:
	var web := Settings.use_web_profile()
	var wood := Look.block_material(Color(0.22, 0.16, 0.11))
	var wood_dark := Look.block_material(Color(0.12, 0.09, 0.07))
	var rope := Look.block_material(Color(0.45, 0.38, 0.26))
	var cloth := Look.block_material(Color(0.62, 0.66, 0.6))
	var iron := Look.block_material(Color(0.12, 0.13, 0.13), 0.6)
	# Black water out to the horizon.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.02, 0.06, 0.07)
	water.metallic = 0.4
	water.roughness = 0.08
	Scenery.box(parent, Vector3(500, 0.1, 500), Vector3(0, -0.35, 0), water)
	# Plank seams across the deck.
	for i in (40 if web else 90):
		var x := -RADIUS + i * (RADIUS * 2.0 / (40 if web else 90))
		var length := sqrt(maxf(RADIUS * RADIUS - x * x, 0.0)) * 2.0 + 10.0
		Scenery.box(parent, Vector3(0.05, 0.01, length), Vector3(x, 0.005, 0), wood_dark)
	# Pilings and ropes round the edge.
	var posts := 36
	var post_radius := RADIUS + 3.5
	for i in posts:
		var a := TAU * i / posts
		var spot := Vector2.from_angle(a) * post_radius
		var node := _at(parent, spot)
		Scenery.box(node, Vector3(0.5, 3.4, 0.5), Vector3(0, 1.2, 0), wood)
		Scenery.box(node, Vector3(0.55, 0.12, 0.55), Vector3(0, 2.95, 0), rope)
		var next := Vector2.from_angle(TAU * (i + 1) / posts) * post_radius
		var mid := (spot + next) / 2.0 - spot
		var rope_node := _at(parent, spot + mid, -(next - spot).angle())
		Scenery.box(rope_node, Vector3((next - spot).length(), 0.07, 0.07), Vector3(0, 2.2, 0), rope)
	# Ghost lanterns on poles.
	for i in 10:
		var spot := Vector2.from_angle(TAU * i / 10.0) * rng.randf_range(14.0, 34.0)
		var node := _at(parent, spot, rng.randf() * TAU)
		Scenery.box(node, Vector3(0.16, 3.4, 0.16), Vector3(0, 1.7, 0), wood_dark)
		Scenery.box(node, Vector3(0.9, 0.12, 0.12), Vector3(0.38, 3.35, 0), wood_dark)
		Scenery.box(node, Vector3(0.34, 0.06, 0.34), Vector3(0.75, 2.95, 0), iron)
		Scenery.box(node, Vector3(0.34, 0.06, 0.34), Vector3(0.75, 2.55, 0), iron)
		_fire(node, Vector3(0.75, 2.68, 0), theme, lights, 1.6, 2.2)
	# Crates, barrels and coils of rope.
	for i in (14 if web else 24):
		var node := _at(parent, _spot(rng, 8.0), rng.randf() * TAU)
		match rng.randi_range(0, 2):
			0:
				Scenery.box(node, Vector3(1.0, 1.0, 1.0), Vector3(0, 0.5, 0), wood)
				if rng.randf() < 0.5:
					Scenery.box(node, Vector3(0.7, 0.7, 0.7), Vector3(0.1, 1.35, 0.05), wood, Vector3(0, 0.4, 0))
			1:
				Scenery.box(node, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0), wood_dark)
				Scenery.box(node, Vector3(0.74, 0.08, 0.74), Vector3(0, 0.2, 0), iron)
				Scenery.box(node, Vector3(0.74, 0.08, 0.74), Vector3(0, 0.8, 0), iron)
			2:
				for k in 3:
					Scenery.box(node, Vector3(0.9 - k * 0.15, 0.12, 0.9 - k * 0.15), Vector3(0, 0.06 + k * 0.12, 0), rope, Vector3(0, k * 0.5, 0))
	# The sunken ship: a tilted hull and two masts with rotten sails.
	for ship in [[Vector2(0, -78), 0.25], [Vector2(62, 46), -0.9]]:
		var node := _at(parent, ship[0], ship[1])
		node.rotation.z = 0.18
		Scenery.box(node, Vector3(7.0, 4.0, 22.0), Vector3(0, 0.0, 0), wood_dark)
		Scenery.box(node, Vector3(6.0, 1.0, 20.0), Vector3(0, 2.4, 0), wood)
		for m in 2:
			var z := -5.0 + m * 9.0
			Scenery.box(node, Vector3(0.6, 20.0, 0.6), Vector3(0, 11.0, z), wood_dark)
			Scenery.box(node, Vector3(9.0, 0.4, 0.4), Vector3(0, 17.0 - m * 2.0, z), wood_dark)
			Scenery.box(node, Vector3(7.5, 6.0, 0.1), Vector3(0.6, 13.5 - m * 2.0, z + 0.3), cloth, Vector3(0, 0, 0.08))


# --- The Plague Carnival (Plague) ---

## A rotting fairground: striped tents, a broken carousel, strings of sickly
## bulbs, and a dead Ferris wheel looming over the fence.
static func _carnival(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator, lights: Array) -> void:
	var web := Settings.use_web_profile()
	var green := Look.block_material(Color(0.32, 0.45, 0.14))
	var purple := Look.block_material(Color(0.32, 0.12, 0.38))
	var wood := Look.block_material(Color(0.24, 0.17, 0.11))
	var iron := Look.block_material(Color(0.18, 0.18, 0.2), 0.6)
	var paint := Look.block_material(Color(0.82, 0.78, 0.62))
	var bulb := Enemy._glow_material(Color(0.7, 1.0, 0.3))
	bulb.emission_energy_multiplier = 3.0
	# Striped tents.
	for i in 6:
		var spot := Vector2.from_angle(TAU * i / 6.0 + 0.4) * rng.randf_range(30.0, 40.0)
		var node := _at(parent, spot, rng.randf() * TAU)
		var size := rng.randf_range(4.0, 6.0)
		for k in 6:
			var w := size * (1.0 - k * 0.15)
			Scenery.box(node, Vector3(w, 0.7, w), Vector3(0, 0.35 + k * 0.7, 0), green if k % 2 == 0 else purple)
		Scenery.box(node, Vector3(0.08, 1.2, 0.08), Vector3(0, 4.7, 0), wood)
		Scenery.box(node, Vector3(0.6, 0.35, 0.03), Vector3(0.3, 5.1, 0), purple)
	# The broken carousel.
	var carousel := _at(parent, Vector2(-24, 14), 0.3)
	var base := CylinderMesh.new()
	base.top_radius = 5.0
	base.bottom_radius = 5.2
	base.height = 0.5
	base.radial_segments = 16
	base.material = paint
	var base_node := MeshInstance3D.new()
	base_node.mesh = base
	base_node.position.y = 0.25
	carousel.add_child(base_node)
	Scenery.box(carousel, Vector3(0.5, 5.0, 0.5), Vector3(0, 2.7, 0), iron)
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
		carousel.add_child(canopy_node)
	for h in 6:
		var a := h * TAU / 6.0
		var at := Vector3(cos(a) * 3.6, 0, sin(a) * 3.6)
		Scenery.box(carousel, Vector3(0.08, 4.5, 0.08), at + Vector3(0, 2.6, 0), iron)
		var horse := Node3D.new()
		horse.position = at + Vector3(0, 1.6 if h % 3 else 0.6, 0)
		horse.rotation = Vector3(0, -a, 0 if h % 3 else 1.2)  # One has fallen over.
		carousel.add_child(horse)
		Scenery.box(horse, Vector3(0.4, 0.5, 1.2), Vector3.ZERO, paint)
		Scenery.box(horse, Vector3(0.3, 0.6, 0.35), Vector3(0, 0.45, -0.6), paint, Vector3(0.4, 0, 0))
		for l in 4:
			Scenery.box(horse, Vector3(0.1, 0.6, 0.1), Vector3(0.15 * (1 if l % 2 else -1), -0.5, 0.45 * (1 if l < 2 else -1)), paint)
	# Strings of sickly bulbs between poles.
	var poles: Array[Vector2] = []
	for i in 10:
		poles.append(Vector2.from_angle(TAU * i / 10.0) * 22.0)
	for i in poles.size():
		var node := _at(parent, poles[i])
		Scenery.box(node, Vector3(0.2, 5.0, 0.2), Vector3(0, 2.5, 0), wood)
		var next := poles[(i + 1) % poles.size()]
		var bulbs := 6 if web else 10
		for b in bulbs:
			var t := (b + 0.5) / bulbs
			var at := poles[i].lerp(next, t)
			var sag := 4.8 - sin(t * PI) * 1.2
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3.ONE * 0.16
			box.material = bulb
			mesh.mesh = box
			mesh.position = Vector3(at.x, sag, at.y)
			parent.add_child(mesh)
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.light_color = Color(0.7, 1.0, 0.35)
			light.light_energy = 1.4
			light.omni_range = 9.0
			light.position = Vector3(poles[i].x, 4.0, poles[i].y)
			parent.add_child(light)
	# Torches as green fire in old oil drums.
	for i in 6:
		var node := _at(parent, Vector2.from_angle(TAU * i / 6.0) * rng.randf_range(12.0, 30.0))
		Scenery.box(node, Vector3(0.7, 1.0, 0.7), Vector3(0, 0.5, 0), iron)
		_fire(node, Vector3(0, 1.15, 0), theme, lights, 2.0, 2.2)
	# The dead Ferris wheel beyond the fence.
	var wheel := _at(parent, Vector2(10, -80), 0.2)
	Scenery.box(wheel, Vector3(1.0, 18.0, 1.0), Vector3(-5, 9.0, 0), iron, Vector3(0, 0, 0.28))
	Scenery.box(wheel, Vector3(1.0, 18.0, 1.0), Vector3(5, 9.0, 0), iron, Vector3(0, 0, -0.28))
	for k in 24:
		var a := k * TAU / 24.0
		Scenery.box(wheel, Vector3(0.4, 3.0, 0.4), Vector3(cos(a) * 14.0, 18.0 + sin(a) * 14.0, 0), iron, Vector3(0, 0, a))
		if k % 3 == 0:
			Scenery.box(wheel, Vector3(0.2, 14.0, 0.2), Vector3(cos(a) * 7.0, 18.0 + sin(a) * 7.0, 0), iron, Vector3(0, 0, a + PI / 2.0))
			Scenery.box(wheel, Vector3(1.6, 1.2, 1.4), Vector3(cos(a) * 14.0, 16.8 + sin(a) * 14.0, 0), purple if k % 2 else green)
		if k % 2 == 0:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3.ONE * 0.3
			box.material = bulb
			mesh.mesh = box
			mesh.position = Vector3(cos(a) * 14.6, 18.0 + sin(a) * 14.6, 0)
			wheel.add_child(mesh)
	# A wooden fence round the fairground.
	var sides := 12
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		var from := Vector2.from_angle(a) * (RADIUS + 4.0)
		var to := Vector2.from_angle(b) * (RADIUS + 4.0)
		var run := Scenery.fence(parent, from.distance_to(to))
		run.position = Vector3(from.x, 0, from.y)
		run.rotation.y = -atan2(to.y - from.y, to.x - from.x)


# --- The Coffin King's Colosseum (Crown) ---

## A blood-red colosseum: arched walls with gold trim, tiers of stands packed
## with a skeleton crowd, crown banners, fire braziers and glowing cracks of
## lava across the sand.
static func _colosseum(theme: Dictionary, parent: Node3D, rng: RandomNumberGenerator, lights: Array) -> void:
	var web := Settings.use_web_profile()
	var stone := Look.block_material(Color(0.36, 0.12, 0.1))
	var stone_dark := Look.block_material(Color(0.2, 0.07, 0.06))
	var gold := Look.block_material(Color(0.95, 0.72, 0.25), 0.8)
	var crimson := Look.block_material(Color(0.55, 0.05, 0.07))
	var bone := Look.block_material(Color(0.82, 0.78, 0.68))
	var dark := Look.block_material(Color(0.04, 0.03, 0.03))
	var lava := Enemy._glow_material(Color(1.0, 0.4, 0.05))
	lava.emission_energy_multiplier = 2.5
	var sides := 30
	var wall_radius := RADIUS + 5.0
	for i in sides:
		var a := TAU * (i + 0.5) / sides
		var node := _at(parent, Vector2.from_angle(a) * wall_radius, -a + PI / 2.0)
		var width := TAU * wall_radius / sides + 0.3
		# The arcade: pillars, an arch lintel and a gold band.
		Scenery.box(node, Vector3(width * 0.25, 5.5, 1.6), Vector3(-width * 0.38, 2.75, 0), stone)
		Scenery.box(node, Vector3(width * 0.25, 5.5, 1.6), Vector3(width * 0.38, 2.75, 0), stone)
		Scenery.box(node, Vector3(width, 1.3, 1.6), Vector3(0, 4.85, 0), stone)
		Scenery.box(node, Vector3(width * 0.5, 4.2, 0.2), Vector3(0, 2.1, -0.7), stone_dark)
		Scenery.box(node, Vector3(width + 0.05, 0.25, 1.7), Vector3(0, 5.55, 0), gold)
		# The stands rising behind, packed with the dead.
		for tier in 3:
			var back := 1.8 + tier * 2.0
			Scenery.box(node, Vector3(width, 1.6, 2.0), Vector3(0, 5.8 + tier * 1.6, back), stone_dark)
			if web and tier > 1:
				continue
			for seat in 4:
				if rng.randf() < 0.25:
					continue
				var fan := Vector3(-width / 2.0 + (seat + 0.5) * width / 4.0, 6.6 + tier * 1.6, back - 0.3)
				_skull(node, fan + Vector3(0, 0.55, 0), 0.32, bone, dark)
				Scenery.box(node, Vector3(0.38, 0.5, 0.22), fan, bone)
				if rng.randf() < 0.4:  # Cheering.
					Scenery.box(node, Vector3(0.08, 0.5, 0.08), fan + Vector3(0.24, 0.55, 0), bone, Vector3(0, 0, -0.3))
	# Crown banners on tall poles.
	for i in 8:
		var a := TAU * i / 8.0
		var node := _at(parent, Vector2.from_angle(a) * (RADIUS - 2.0), -a + PI / 2.0)
		Scenery.box(node, Vector3(0.25, 9.0, 0.25), Vector3(0, 4.5, 0), gold)
		Scenery.box(node, Vector3(2.4, 4.2, 0.08), Vector3(0, 6.2, -0.2), crimson)
		Scenery.box(node, Vector3(1.4, 0.35, 0.1), Vector3(0, 6.6, -0.26), gold)
		for p in 3:
			Scenery.box(node, Vector3(0.24, 0.4, 0.1), Vector3(-0.5 + p * 0.5, 7.0, -0.26), gold)
	# Fire braziers on stone plinths.
	for i in 8:
		var node := _at(parent, Vector2.from_angle(TAU * (i + 0.5) / 8.0) * rng.randf_range(24.0, 36.0))
		Scenery.box(node, Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0), stone)
		Scenery.box(node, Vector3(1.4, 0.3, 1.4), Vector3(0, 1.75, 0), gold)
		_fire(node, Vector3(0, 2.0, 0), theme, lights, 2.6, 2.8)
	# Lava cracks across the sand.
	for i in (14 if web else 26):
		var node := _at(parent, _spot(rng, 9.0, RADIUS - 2.0), rng.randf() * TAU)
		var length := rng.randf_range(2.0, 5.0)
		Scenery.box(node, Vector3(0.12, 0.02, length), Vector3(0, 0.01, 0), lava)
		Scenery.box(node, Vector3(0.08, 0.02, length * 0.5), Vector3(0.3, 0.01, length * 0.4), lava, Vector3(0, 0.6, 0))
