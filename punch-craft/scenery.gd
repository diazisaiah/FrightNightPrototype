class_name Scenery
## Blocky props and atmosphere for the graveyard (gravestones, dead trees,
## iron fences, crypts, rocks, grass), plus the night sky, mist, wisps and
## bats. All built from textured boxes (Look.block_material).

const STONE := Color(0.36, 0.36, 0.4)
const MOSS := Color(0.22, 0.3, 0.2)
const BARK := Color(0.1, 0.085, 0.08)
const IRON := Color(0.07, 0.07, 0.08)
const DIRT := Color(0.15, 0.115, 0.085)
const GRASS := Color(0.12, 0.2, 0.11)


static func box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


## Something you can't walk through: a box (or, with radius, an upright
## cylinder) of collision under parent, on the world layer. Buildings and
## fences get one; small props (graves, rocks, crates) stay walk-through so
## nobody snags on clutter.
static func solid(parent: Node3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO, radius := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	var shape := CollisionShape3D.new()
	if radius > 0.0:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius
		cylinder.height = size.y
		shape.shape = cylinder
	else:
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


## A gravestone with its dirt mound; kind 0-5 picks the shape.
static func gravestone(parent: Node3D, kind: int, rng: RandomNumberGenerator) -> Node3D:
	var grave := Node3D.new()
	parent.add_child(grave)
	var tone := STONE.darkened(rng.randf_range(0.0, 0.35)).lerp(MOSS, rng.randf() * 0.3)
	var stone := Look.block_material(tone)
	var dark := Look.block_material(tone.darkened(0.3))
	match kind:
		0:  # Rounded slab with an engraved panel.
			box(grave, Vector3(0.62, 0.8, 0.16), Vector3(0, 0.4, 0), stone)
			box(grave, Vector3(0.48, 0.12, 0.16), Vector3(0, 0.86, 0), stone)
			box(grave, Vector3(0.3, 0.08, 0.16), Vector3(0, 0.96, 0), stone)
			box(grave, Vector3(0.36, 0.3, 0.02), Vector3(0, 0.52, 0.08), dark)
		1:  # Cross on a plinth.
			box(grave, Vector3(0.4, 0.2, 0.3), Vector3(0, 0.1, 0), stone)
			box(grave, Vector3(0.14, 1.2, 0.14), Vector3(0, 0.8, 0), stone)
			box(grave, Vector3(0.62, 0.14, 0.14), Vector3(0, 1.08, 0), stone)
		2:  # Obelisk.
			box(grave, Vector3(0.55, 0.22, 0.55), Vector3(0, 0.11, 0), dark)
			box(grave, Vector3(0.42, 0.2, 0.42), Vector3(0, 0.32, 0), stone)
			box(grave, Vector3(0.28, 1.4, 0.28), Vector3(0, 1.12, 0), stone)
			box(grave, Vector3(0.18, 0.18, 0.18), Vector3(0, 1.9, 0), stone, Vector3(0, PI / 4, 0))
		3:  # Broken slab, the top fallen in front.
			box(grave, Vector3(0.6, 0.5, 0.15), Vector3(0, 0.25, 0), stone)
			box(grave, Vector3(0.38, 0.28, 0.15), Vector3(-0.1, 0.62, 0), stone, Vector3(0, 0, 0.4))
			box(grave, Vector3(0.4, 0.12, 0.3), Vector3(0.1, 0.06, 0.4), stone, Vector3(0, 0.6, 0.2))
		4:  # Celtic cross with a ring.
			box(grave, Vector3(0.34, 0.24, 0.26), Vector3(0, 0.12, 0), dark)
			box(grave, Vector3(0.12, 1.3, 0.12), Vector3(0, 0.88, 0), stone)
			box(grave, Vector3(0.56, 0.12, 0.12), Vector3(0, 1.18, 0), stone)
			for i in 8:
				var a := TAU * i / 8.0
				box(grave, Vector3(0.08, 0.08, 0.1), Vector3(cos(a) * 0.2, 1.18 + sin(a) * 0.2, 0), stone)
		_:  # Tomb chest.
			box(grave, Vector3(0.7, 0.45, 1.3), Vector3(0, 0.225, 0), stone)
			box(grave, Vector3(0.8, 0.08, 1.4), Vector3(0, 0.49, 0), dark)
			box(grave, Vector3(0.12, 0.05, 0.6), Vector3(0, 0.555, 0), stone)
	if kind != 5:
		box(grave, Vector3(0.75, 0.12, 1.5), Vector3(0, 0.03, 0.9), Look.block_material(DIRT))
	grave.rotation = Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.1, 0.1))
	return grave


## A leafless tree with a gnarled trunk, branches and twigs, all blocks.
static func dead_tree(parent: Node3D, rng: RandomNumberGenerator, height := 5.0) -> Node3D:
	var tree := Node3D.new()
	parent.add_child(tree)
	var bark := Look.block_material(BARK.lightened(rng.randf() * 0.1))
	var y := 0.0
	var x := 0.0
	var width := 0.34
	# Trunk in stacked, slightly offset segments that narrow toward the top.
	while y < height:
		var segment := rng.randf_range(0.5, 0.9)
		box(tree, Vector3(width, segment, width), Vector3(x, y + segment / 2.0, 0), bark)
		y += segment
		x += rng.randf_range(-0.06, 0.06)
		width *= 0.86
	# Roots.
	for i in 4:
		var a := TAU * i / 4.0 + rng.randf()
		box(tree, Vector3(0.12, 0.12, 0.6), Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), bark, Vector3(0, -a, 0))
	for i in rng.randi_range(5, 8):
		var branch := Node3D.new()
		branch.position = Vector3(x * 0.5, height * rng.randf_range(0.45, 0.95), 0)
		branch.rotation = Vector3(0, rng.randf() * TAU, rng.randf_range(0.6, 1.2))
		tree.add_child(branch)
		var length := rng.randf_range(1.0, 2.4)
		box(branch, Vector3(0.1, length, 0.1), Vector3(0, length / 2.0, 0), bark)
		for t in 2:
			var twig := Node3D.new()
			twig.position.y = length * rng.randf_range(0.5, 0.95)
			twig.rotation = Vector3(0, rng.randf() * TAU, rng.randf_range(-1.0, 1.0))
			branch.add_child(twig)
			var twig_length := length * rng.randf_range(0.3, 0.5)
			box(twig, Vector3(0.05, twig_length, 0.05), Vector3(0, twig_length / 2.0, 0), bark)
	return tree


## A run of iron fence along +X: posts with spear tips and two rails.
static func fence(parent: Node3D, length: float) -> Node3D:
	var run := Node3D.new()
	parent.add_child(run)
	var iron := Look.block_material(IRON, 0.6)
	var stone := Look.block_material(STONE.darkened(0.2))
	var iron_boxes: Array[Transform3D] = []
	var stone_boxes: Array[Transform3D] = []
	var bars := int(length / 0.18)
	for i in bars + 1:
		var x := i * 0.18
		iron_boxes.append(_box_transform(Vector3(0.035, 1.5, 0.035), Vector3(x, 0.75, 0)))
		iron_boxes.append(_box_transform(Vector3(0.06, 0.1, 0.06), Vector3(x, 1.55, 0), Vector3(0, PI / 4, 0)))
	for h in [0.35, 1.3]:
		iron_boxes.append(_box_transform(Vector3(length, 0.05, 0.05), Vector3(length / 2.0, h, 0)))
	# Stone pillars at both ends.
	for x in [0.0, length]:
		stone_boxes.append(_box_transform(Vector3(0.36, 1.8, 0.36), Vector3(x, 0.9, 0)))
		stone_boxes.append(_box_transform(Vector3(0.44, 0.12, 0.44), Vector3(x, 1.86, 0)))
	# A fence side used to be hundreds of individual MeshInstance3D nodes.
	# Batching the identical boxes makes it two draw calls instead, while keeping
	# the exact same silhouette and layout.
	_box_batch(run, iron, iron_boxes)
	_box_batch(run, stone, stone_boxes)
	solid(run, Vector3(length + 0.44, 1.95, 0.4), Vector3(length / 2.0, 0.975, 0))
	return run


static func _box_transform(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(size), pos)


static func _box_batch(parent: Node3D, material: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	if Settings.use_web_profile():
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## A small family crypt: walls, a peaked roof, a dark door and a stone urn
## on the gable (no crosses, by the house rule). Solid.
static func crypt(parent: Node3D, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var stone := Look.block_material(STONE.darkened(rng.randf_range(0.05, 0.25)))
	var dark := Look.block_material(STONE.darkened(0.5))
	box(root, Vector3(3.2, 0.3, 3.8), Vector3(0, 0.15, 0), dark)
	box(root, Vector3(2.8, 2.4, 3.2), Vector3(0, 1.5, 0), stone)
	for x in [-1.25, 1.25]:
		box(root, Vector3(0.36, 2.6, 0.36), Vector3(x, 1.5, 1.7), stone)
	var roof := PrismMesh.new()
	roof.size = Vector3(3.3, 1.1, 3.6)
	roof.material = dark
	var roof_node := MeshInstance3D.new()
	roof_node.mesh = roof
	roof_node.position = Vector3(0, 3.25, 0)
	root.add_child(roof_node)
	box(root, Vector3(1.0, 1.7, 0.06), Vector3(0, 1.15, 1.61), Look.block_material(Color(0.04, 0.035, 0.04)))
	box(root, Vector3(0.3, 0.12, 0.3), Vector3(0, 3.86, 1.4), stone)
	box(root, Vector3(0.22, 0.3, 0.22), Vector3(0, 4.07, 1.4), stone)
	box(root, Vector3(0.12, 0.1, 0.12), Vector3(0, 4.27, 1.4), stone)
	solid(root, Vector3(3.3, 3.8, 3.9), Vector3(0, 1.9, 0.05))
	return root


## Scattered small stones.
static func rocks(parent: Node3D, rng: RandomNumberGenerator, count := 4) -> void:
	var stone := Look.block_material(STONE.darkened(0.3))
	for i in count:
		var s := rng.randf_range(0.12, 0.35)
		box(parent, Vector3(s, s * 0.6, s * rng.randf_range(0.7, 1.3)), Vector3(rng.randf_range(-0.8, 0.8), s * 0.25, rng.randf_range(-0.8, 0.8)), stone, Vector3(0, rng.randf() * TAU, rng.randf_range(-0.2, 0.2)))


## Thousands of grass blades and dirt flecks over a disc, as one MultiMesh.
static func grass(parent: Node3D, radius: float, count: int, rng: RandomNumberGenerator, keep_clear := 0.0) -> void:
	var blade := BoxMesh.new()
	blade.size = Vector3(0.03, 0.28, 0.03)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 1.0
	blade.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade
	multimesh.instance_count = count
	for i in count:
		var spot := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf_range(keep_clear * keep_clear / (radius * radius), 1.0)) * radius
		var scale := Vector3(1, rng.randf_range(0.5, 1.6), 1)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(scale)
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(spot.x, 0.08 * scale.y, spot.y)))
		var shade := GRASS.lerp(Color(0.25, 0.24, 0.12), rng.randf() * 0.6).darkened(rng.randf() * 0.4)
		multimesh.set_instance_color(i, shade)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)


## Patches of bare dirt and darker earth breaking up the ground.
static func ground_patches(parent: Node3D, radius: float, count: int, rng: RandomNumberGenerator) -> void:
	var dirt := Look.block_material(DIRT)
	var dark := Look.block_material(GRASS.darkened(0.45))
	for i in count:
		var spot := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, radius)
		var size := Vector3(rng.randf_range(1.0, 4.0), 0.03, rng.randf_range(1.0, 4.0))
		box(parent, size, Vector3(spot.x, 0.015 + rng.randf() * 0.01, spot.y), dirt if rng.randf() < 0.6 else dark, Vector3(0, rng.randf() * TAU, 0))


## A sky full of stars on a big dome, plus the moon with its halo.
static func night_sky(parent: Node3D, rng: RandomNumberGenerator, moon_at := Vector3(34, 26, -80)) -> void:
	var star := BoxMesh.new()
	star.size = Vector3.ONE * 0.22
	var star_material := StandardMaterial3D.new()
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_material.vertex_color_use_as_albedo = true
	star_material.set("disable_fog", true)
	star.material = star_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = star
	multimesh.instance_count = 600
	for i in 600:
		var direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.12, 1.0), rng.randf_range(-1, 1)).normalized()
		var size := rng.randf_range(0.4, 1.6) if rng.randf() < 0.9 else 2.2
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), direction * 95.0))
		var b := rng.randf_range(0.5, 1.0)
		multimesh.set_instance_color(i, Color(b, b, b * rng.randf_range(0.95, 1.15)))
	var stars := MultiMeshInstance3D.new()
	stars.multimesh = multimesh
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(stars)
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 5.0
	sphere.height = 10.0
	var moon_material := StandardMaterial3D.new()
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.albedo_color = Color(0.95, 0.93, 0.82)
	moon_material.albedo_texture = Look.grain()
	moon_material.emission_enabled = true
	moon_material.emission = Color(0.95, 0.93, 0.82)
	moon_material.emission_energy_multiplier = 2.0
	moon_material.set("disable_fog", true)
	sphere.material = moon_material
	moon.mesh = sphere
	moon.position = moon_at
	parent.add_child(moon)
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(38, 38)
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.set("disable_fog", true)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.55, 0.62, 0.9, 0.5))
	gradient.set_color(1, Color(0.55, 0.62, 0.9, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	halo_material.albedo_texture = texture
	quad.material = halo_material
	halo.mesh = quad
	halo.position = moon_at + Vector3(0, 0, -2)
	parent.add_child(halo)


## Low banks of mist drifting over an area.
static func mist(parent: Node3D, center: Vector3, extents: Vector3, amount := 50) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 16.0
	particles.preprocess = 16.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = extents
	particles.position = center
	particles.direction = Vector3(1, 0, 0.2)
	particles.spread = 20.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 0.2
	particles.initial_velocity_max = 0.6
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	particles.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(8, 2.6)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.55, 0.6, 0.75, 0.09)
	# Fades out near the camera so a bank never sits across the view.
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	material.distance_fade_min_distance = 2.0
	material.distance_fade_max_distance = 9.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	material.albedo_texture = texture
	quad.material = material
	particles.mesh = quad
	parent.add_child(particles)
	return particles


## Will-o'-the-wisps floating over an area.
static func wisps(parent: Node3D, center: Vector3, extents: Vector3, color := Color(0.45, 1.0, 0.75), amount := 30) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = extents
	particles.position = center
	particles.gravity = Vector3(0, 0.08, 0)
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	particles.color_ramp = ramp
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.07
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.material = material
	particles.mesh = mote
	parent.add_child(particles)
