class_name HitFx
## One-shot particle bursts: blood/bone chips on hits, sparks on armor, coins on kills.


## Bursts (2026-10-29: a maxed build's hits, echoes and powers filled the
## screen with particles and lagged): each throws SHARE of what it asks for,
## and no more than BUDGET particles go out per BUDGET_WINDOW seconds
## (WEB_BUDGET in browsers); past that, bursts shrink or are skipped. Their
## meshes are shared by color, glow and size.
const SHARE := 0.55
const BUDGET := 160
const WEB_BUDGET := 90
const BUDGET_WINDOW := 0.25

static var _spent := 0
static var _window_start := 0
static var _meshes := {}


static func burst(parent: Node, at: Vector3, direction: Vector3, color: Color, amount := 14, speed := 4.0, glow := false, size := 0.05) -> void:
	var now := Time.get_ticks_msec()
	if now - _window_start > BUDGET_WINDOW * 1000.0:
		_window_start = now
		_spent = 0
	amount = maxi(2, roundi(amount * SHARE))
	amount = mini(amount, (WEB_BUDGET if Settings.use_web_profile() else BUDGET) - _spent)
	if amount < 2:
		return
	_spent += amount
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = amount
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.mesh = _mesh(color, glow, size)

	particles.direction = direction.normalized() if direction.length_squared() > 0.0 else Vector3.UP
	particles.spread = 55.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0

	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


## A burst's mote: one per color, glow and size, shared.
static func _mesh(color: Color, glow: bool, size: float) -> BoxMesh:
	var key := "%s|%s|%.3f" % [color.to_html(), glow, size]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	mesh.material = material
	_meshes[key] = mesh
	return mesh


## Coin denominations for kill bursts, biggest first: [copper worth, color,
## size]. Just for show: 367 coins bursts as 3 silver and 67 copper, and the
## HUD still counts +367.
const COINS := [
	[1000000, Color(0.8, 0.95, 1.0), 0.16],  # Platinum
	[10000, Color(1.0, 0.8, 0.2), 0.13],  # Gold
	[100, Color(0.85, 0.88, 0.93), 0.11],  # Silver
	[1, Color(0.7, 0.33, 0.16), 0.09],  # Copper
]


## Coins flying out of a KO, in copper, silver, gold and platinum.
static func coins(parent: Node, at: Vector3, amount: int) -> void:
	var left := amount
	for coin in COINS:
		var count := left / int(coin[0])
		left -= count * int(coin[0])
		if count <= 0:
			continue
		var particles := CPUParticles3D.new()
		particles.one_shot = true
		particles.explosiveness = 0.95
		particles.amount = count
		particles.lifetime = 0.9
		particles.local_coords = false
		var mesh := CylinderMesh.new()
		mesh.top_radius = coin[2] * 0.5
		mesh.bottom_radius = coin[2] * 0.5
		mesh.height = coin[2] * 0.18
		mesh.radial_segments = 10
		mesh.rings = 1
		var material := StandardMaterial3D.new()
		material.albedo_color = coin[1]
		material.metallic = 0.8
		material.roughness = 0.3
		material.emission_enabled = true
		material.emission = coin[1]
		material.emission_energy_multiplier = 0.6 if int(coin[0]) == 1 else 2.5
		mesh.material = material
		particles.mesh = mesh
		particles.direction = Vector3.UP
		particles.spread = 50.0
		particles.initial_velocity_min = 2.5
		particles.initial_velocity_max = 5.5
		particles.gravity = Vector3(0, -9.8, 0)
		particles.angular_velocity_min = -540.0
		particles.angular_velocity_max = 540.0
		particles.particle_flag_rotate_y = true
		parent.add_child(particles)
		particles.global_position = at
		particles.emitting = true
		particles.finished.connect(particles.queue_free)


static var _flash_texture: GradientTexture2D
static var _ring_texture: GradientTexture2D


## A bright burst of light at a hit: a billboard that pops out and fades.
static func flash(parent: Node, at: Vector3, color: Color, size := 0.5) -> void:
	if _flash_texture == null:
		_flash_texture = _radial([[0.0, Color(1, 1, 1, 1)], [0.25, Color(1, 1, 1, 0.8)], [1.0, Color(1, 1, 1, 0)]])
	var sprite := _billboard(_flash_texture, color, size)
	parent.add_child(sprite)
	sprite.global_position = at
	sprite.scale = Vector3.ONE * 0.4
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite.material_override, "albedo_color:a", 0.0, 0.14)
	tween.chain().tween_callback(sprite.queue_free)


## An expanding ring for heavy hits and counters.
static func ring(parent: Node, at: Vector3, color: Color, size := 1.4) -> void:
	if _ring_texture == null:
		_ring_texture = _radial([[0.0, Color(1, 1, 1, 0)], [0.62, Color(1, 1, 1, 0)], [0.78, Color(1, 1, 1, 1)], [1.0, Color(1, 1, 1, 0)]])
	var sprite := _billboard(_ring_texture, color, size)
	parent.add_child(sprite)
	sprite.global_position = at
	sprite.scale = Vector3.ONE * 0.2
	var tween := sprite.create_tween().set_parallel()
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite.material_override, "albedo_color:a", 0.0, 0.25).set_delay(0.05)
	tween.chain().tween_callback(sprite.queue_free)


## Breaks a dead enemy's body into tumbling cubes, each part in its own color,
## with a ghostly wisp rising out of it.
static func shatter(parent: Node, parts: Array, push: Vector3, soul_color: Color) -> void:
	var center := Vector3.ZERO
	var count := 0
	for part in parts:
		var mesh := part as MeshInstance3D
		if mesh == null or not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var material := mesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mesh.has_meta("base_material"):
			material = mesh.get_meta("base_material")
		if material == null:
			continue
		var at := mesh.global_position
		center += at
		count += 1
		var size := clampf(mesh.get_aabb().size.length() * 0.18, 0.04, 0.12)
		var cubes := CPUParticles3D.new()
		cubes.one_shot = true
		cubes.explosiveness = 1.0
		cubes.amount = 5
		cubes.lifetime = 1.1
		cubes.local_coords = false
		var box := BoxMesh.new()
		box.size = Vector3.ONE * size
		box.material = material
		cubes.mesh = box
		cubes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cubes.emission_sphere_radius = 0.12
		cubes.direction = (push.normalized() + Vector3.UP).normalized() if push.length_squared() > 0.01 else Vector3.UP
		cubes.spread = 70.0
		cubes.initial_velocity_min = 1.5
		cubes.initial_velocity_max = 4.0
		cubes.gravity = Vector3(0, -12.0, 0)
		cubes.angular_velocity_min = -540.0
		cubes.angular_velocity_max = 540.0
		var shrink := Curve.new()
		shrink.add_point(Vector2(0, 1))
		shrink.add_point(Vector2(0.7, 1))
		shrink.add_point(Vector2(1, 0))
		cubes.scale_amount_curve = shrink
		parent.add_child(cubes)
		cubes.global_position = at
		cubes.emitting = true
		cubes.finished.connect(cubes.queue_free)
	if count == 0:
		return
	# The soul leaves.
	center /= count
	var soul := CPUParticles3D.new()
	soul.one_shot = true
	soul.explosiveness = 0.6
	soul.amount = 14
	soul.lifetime = 1.4
	soul.local_coords = false
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.05
	var glow := StandardMaterial3D.new()
	glow.albedo_color = soul_color
	glow.emission_enabled = true
	glow.emission = soul_color
	glow.emission_energy_multiplier = 3.0
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.vertex_color_use_as_albedo = true
	mote.material = glow
	soul.mesh = mote
	soul.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	soul.emission_sphere_radius = 0.25
	soul.direction = Vector3.UP
	soul.spread = 15.0
	soul.gravity = Vector3(0, 1.2, 0)
	soul.initial_velocity_min = 0.6
	soul.initial_velocity_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	soul.color_ramp = fade
	parent.add_child(soul)
	soul.global_position = center
	soul.emitting = true
	soul.finished.connect(soul.queue_free)


static func _billboard(texture: Texture2D, color: Color, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_texture = texture
	material.albedo_color = color
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	sprite.material_override = material
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


static func _radial(stops: Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	gradient.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
