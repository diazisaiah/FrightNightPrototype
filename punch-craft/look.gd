class_name Look
## The game's shared visual style: block materials with a pixel grain (so
## every surface reads as textured voxels, not flat plastic), the color grade
## and glow each scene's environment uses, and light setup.

## World-space size of one texture repeat, in meters. The grain texture is
## GRAIN_SIZE pixels across it, so one "voxel pixel" is about 1.6 cm.
const GRAIN_REPEAT := 1.0
const GRAIN_SIZE := 64

static var _grain: ImageTexture


## Pixel-noise texture (light, with darker pits and cracks), shared by every
## block material. Values stay near white so it only shades the base color.
static func grain() -> ImageTexture:
	if _grain:
		return _grain
	var image := Image.create(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for y in GRAIN_SIZE:
		for x in GRAIN_SIZE:
			# 2x2 clumps plus single-pixel variation.
			var clump := _hash(x / 2, y / 2)
			var value := 0.8 + clump * 0.14 + rng.randf() * 0.06
			if clump < 0.05:
				value = 0.62  # A pit.
			image.set_pixel(x, y, Color(value, value, value))
	# A few hairline cracks.
	for crack in 5:
		var x := rng.randi_range(0, GRAIN_SIZE - 1)
		var y := rng.randi_range(0, GRAIN_SIZE - 1)
		for step in rng.randi_range(6, 14):
			image.set_pixel(posmod(x, GRAIN_SIZE), posmod(y, GRAIN_SIZE), Color(0.58, 0.58, 0.58))
			x += rng.randi_range(-1, 1)
			y += 1
	image.generate_mipmaps()
	_grain = ImageTexture.create_from_image(image)
	return _grain


static func _hash(x: int, y: int) -> float:
	var h := sin(x * 127.1 + y * 311.7) * 43758.5453
	return h - floorf(h)


## A textured block material: the grain mapped in world space, so it lines up
## across boxes of any size and never stretches.
static func block_material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_texture = grain()
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / GRAIN_REPEAT
	material.uv1_triplanar_sharpness = 4.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.metallic = metallic
	material.roughness = 0.45 if metallic > 0.0 else 0.88
	material.metallic_specular = 0.35
	return material


## Applies the game's grade to a scene's environment. kind: "night"
## (graveyard), "crypt", "ring" (training) or "menu".
static func tune_environment(env: Environment, kind := "night") -> void:
	var web := Settings.use_web_profile()
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15 if kind != "crypt" else 1.35
	env.tonemap_white = 5.0
	# Glow and SSAO are expensive or unsupported in WebGL. The browser build
	# keeps the color grade but drops those passes so combat timing stays crisp.
	env.glow_enabled = not web
	env.glow_normalized = false
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT if kind == "menu" else Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in 7:
		env.set_glow_level(level, 1.0 if level in [1, 2, 3, 4] else 0.0)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	# The browser drops glow, which darkens everything; lift it back.
	env.adjustment_brightness = 1.16 if web else 1.0
	if web:
		env.ambient_light_energy *= 1.25
	# Ambient occlusion where the renderer supports it (desktop).
	env.ssao_enabled = not web and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4


## A flickering fire light with soft shadows that fades out with distance
## (so many torches don't all cost shadows at once).
static func fire_light(color := Color(1.0, 0.6, 0.28), energy := 2.2, light_range := 9.0, shadows := true) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadows and Settings.get_value("shadows") and not Settings.use_web_profile()
	light.shadow_blur = 1.5
	light.shadow_bias = 0.08
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_shadow = 14.0
	light.distance_fade_length = 6.0
	return light


## A torch flame at pos: a hot core and an outer flame of glowing cubes,
## with embers and a wisp of smoke rising off it. tint recolors it (blue
## ghost-fire, green plague-fire...); the default is a warm orange fire.
const FIRE := Color(1.0, 0.42, 0.08)


static func flame(parent: Node3D, pos: Vector3, size := 1.0, particles := true, tint := FIRE) -> Node3D:
	var warm := tint == FIRE
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var outer := MeshInstance3D.new()
	outer.mesh = _glow_box(Vector3(0.15, 0.13, 0.15) * size, tint, 3.0)
	outer.position.y = -0.02 * size
	root.add_child(outer)
	var core := MeshInstance3D.new()
	core.mesh = _glow_box(Vector3(0.09, 0.16, 0.09) * size, Color(1.0, 0.82, 0.35) if warm else tint.lightened(0.55), 5.0)
	core.position.y = 0.03 * size
	root.add_child(core)
	var tip := MeshInstance3D.new()
	tip.mesh = _glow_box(Vector3(0.05, 0.07, 0.05) * size, Color(1.0, 0.65, 0.2) if warm else tint.lightened(0.3), 4.0)
	tip.position.y = 0.13 * size
	root.add_child(tip)
	# The glowing cubes carry the read of the flame. On Web, skipping the two
	# CPU particle emitters per torch saves a surprising amount of frame time.
	particles = particles and not Settings.use_web_profile()
	if not particles:
		return root
	var embers := CPUParticles3D.new()
	embers.amount = 8
	embers.lifetime = 1.1
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.06 * size
	embers.direction = Vector3.UP
	embers.spread = 25.0
	embers.gravity = Vector3(0, 0.5, 0)
	embers.initial_velocity_min = 0.2
	embers.initial_velocity_max = 0.6
	embers.mesh = _glow_box(Vector3.ONE * 0.018 * size, Color(1.0, 0.55, 0.15) if warm else tint.lightened(0.15), 4.0)
	embers.position.y = 0.1 * size
	root.add_child(embers)
	var smoke := CPUParticles3D.new()
	smoke.amount = 6
	smoke.lifetime = 1.8
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.gravity = Vector3(0.05, 0.25, 0)
	smoke.initial_velocity_min = 0.25
	smoke.initial_velocity_max = 0.4
	var puff := BoxMesh.new()
	puff.size = Vector3.ONE * 0.06 * size
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.vertex_color_use_as_albedo = true
	puff.material = smoke_material
	smoke.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(0.12, 0.11, 0.1, 0.35))
	fade.set_color(1, Color(0.12, 0.11, 0.1, 0.0))
	smoke.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 2.2))
	smoke.scale_amount_curve = grow
	smoke.position.y = 0.2 * size
	root.add_child(smoke)
	return root


static func _glow_box(size: Vector3, color: Color, energy: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	mesh.material = material
	return mesh


static var _bricks: ImageTexture
static var _tiles: ImageTexture
static var _web: ImageTexture


## Brick walls: 25 x 12.5 cm bricks in offset rows, each its own shade, with
## mortar lines, chips and the odd mossy or cracked brick. 128 px per meter.
static func bricks() -> ImageTexture:
	if _bricks:
		return _bricks
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var shades := {}
	for y in size:
		var row := y / 16
		for x in size:
			var shifted := x + (16 if row % 2 == 1 else 0)
			var column := (shifted / 32) % 4
			var key := Vector2i(column, row)
			if not shades.has(key):
				shades[key] = [rng.randf_range(0.72, 1.0), rng.randf() < 0.08, rng.randf() < 0.06]
			var info: Array = shades[key]
			var value: float = info[0] * (0.9 + _hash(x, y) * 0.12)
			var tint := Color(value, value, value)
			if info[1]:
				tint = Color(value * 0.75, value * 0.9, value * 0.7)  # Moss.
			if info[2] and absf(float(shifted % 32) - 16.0 + float(y % 16) - 8.0) < 1.0:
				tint = tint.darkened(0.4)  # Crack.
			if y % 16 == 0 or shifted % 32 == 0:
				tint = Color(0.38, 0.37, 0.36)  # Mortar.
			elif y % 16 == 1 or shifted % 32 == 1:
				tint = tint.darkened(0.15)  # Shadowed edge.
			image.set_pixel(x, y, tint)
	image.generate_mipmaps()
	_bricks = ImageTexture.create_from_image(image)
	return _bricks


## Flagstone floors: 50 cm stones with thick joints, shade variation and cracks.
static func tiles() -> ImageTexture:
	if _tiles:
		return _tiles
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var shades := {}
	for y in size:
		for x in size:
			var key := Vector2i(x / 64, y / 64)
			if not shades.has(key):
				shades[key] = [rng.randf_range(0.75, 1.0), rng.randi_range(0, 63), rng.randf() < 0.5]
			var info: Array = shades[key]
			var value: float = info[0] * (0.88 + _hash(x / 2, y / 2) * 0.14)
			var tint := Color(value, value * 0.98, value * 0.96)
			# A crack running across some stones.
			if info[2] and absf(float(x % 64) - float(info[1]) - float(y % 64) * 0.35) < 0.8:
				tint = tint.darkened(0.45)
			if x % 64 < 2 or y % 64 < 2:
				tint = Color(0.32, 0.31, 0.3)
			image.set_pixel(x, y, tint)
	image.generate_mipmaps()
	_tiles = ImageTexture.create_from_image(image)
	return _tiles


## A cobweb: spokes and rings from one corner, with transparency.
static func web() -> ImageTexture:
	if _web:
		return _web
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	for spoke in 7:
		var angle := spoke * (PI / 2.0) / 6.0
		for r in size:
			var p := Vector2(cos(angle), sin(angle)) * r
			if p.x < size and p.y < size:
				image.set_pixel(int(p.x), int(p.y), Color(0.9, 0.9, 0.92, 0.55))
	for ring: int in [12, 22, 33, 45, 58]:
		for step in 60:
			var angle := step / 59.0 * PI / 2.0
			var p := Vector2(cos(angle), sin(angle)) * (ring + sin(step * 0.7) * 1.5)
			if p.x >= 0 and p.y >= 0 and p.x < size and p.y < size:
				image.set_pixel(int(p.x), int(p.y), Color(0.9, 0.9, 0.92, 0.45))
	image.generate_mipmaps()
	_web = ImageTexture.create_from_image(image)
	return _web


## A block material using a patterned texture (bricks or tiles) in world space.
static func patterned_material(color: Color, texture: Texture2D) -> StandardMaterial3D:
	var material := block_material(color)
	material.albedo_texture = texture
	return material


## Merges identical static scenery meshes under root into MultiMeshes, so the
## renderer draws each kind once instead of hundreds of times (WebGL is slow at
## many small draws). Only opaque, non-glowing primitive meshes with no script
## and no children are merged, in cell-sized areas. recurse also looks inside plain Node3D groups
## (never inside scripted nodes or bodies); leave it off when containers move
## later (the Crypt's gates). Returns how many meshes were merged.
static func batch_meshes(root: Node3D, recurse := false, min_group := 3, cell := 16.0) -> int:
	var groups := {}
	var stack: Array[Node] = [root]
	var inverse := root.global_transform.affine_inverse()
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is MeshInstance3D:
				var key := _batch_key(child)
				if key != "":
					# Batches stay local (one per area), so off-screen ones are
					# culled and only nearby lights touch them.
					var at: Vector3 = (child as MeshInstance3D).global_position
					key += "|%d,%d" % [floori(at.x / cell), floori(at.z / cell)]
					if not groups.has(key):
						groups[key] = []
					groups[key].append(child)
			elif recurse and child.get_class() == "Node3D" and child.get_script() == null:
				stack.append(child)
	var merged := 0
	for key in groups:
		var parts: Array = groups[key]
		if parts.size() < min_group:
			continue
		var first: MeshInstance3D = parts[0]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first.mesh
		multimesh.instance_count = parts.size()
		for i in parts.size():
			multimesh.set_instance_transform(i, inverse * (parts[i] as MeshInstance3D).global_transform)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multimesh
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		root.add_child(batch)
		for part in parts:
			part.queue_free()
		merged += parts.size()
	return merged


static func _batch_key(mesh_instance: MeshInstance3D) -> String:
	if mesh_instance.get_script() != null or mesh_instance.get_child_count() > 0 or not mesh_instance.visible:
		return ""
	var mesh := mesh_instance.mesh as PrimitiveMesh
	if mesh == null:
		return ""
	var material: Material = mesh_instance.material_override if mesh_instance.material_override else mesh.material
	var standard := material as StandardMaterial3D
	if material == null or (standard and (standard.emission_enabled or standard.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)):
		return ""
	var shape := ""
	if mesh is BoxMesh:
		shape = "box %s" % (mesh as BoxMesh).size
	elif mesh is CylinderMesh:
		var c := mesh as CylinderMesh
		shape = "cyl %s %s %s %d" % [c.top_radius, c.bottom_radius, c.height, c.radial_segments]
	elif mesh is SphereMesh:
		shape = "sphere %s %s" % [(mesh as SphereMesh).radius, (mesh as SphereMesh).height]
	elif mesh is PrismMesh:
		shape = "prism %s %s" % [(mesh as PrismMesh).size, (mesh as PrismMesh).left_to_right]
	else:
		return ""
	return "%s|%d|%d|%d" % [shape, material.get_instance_id(), mesh.material.get_instance_id() if mesh.material else 0, mesh_instance.cast_shadow]
