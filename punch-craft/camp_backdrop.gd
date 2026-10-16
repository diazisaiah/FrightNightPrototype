class_name CampBackdrop
extends SubViewportContainer
## The live scene behind the camp menus: a campfire in a clearing at the edge
## of the graveyard, with a tent, log seats, crates and a lantern, the
## training dummy, graves and dead trees in the fog, and the stars. The camera
## drifts slowly around the fire.

const FIRE := Vector3(0, 0, 0)
const CAMERA_HOME := Vector3(4.6, 2.3, 6.2)

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _fire_light: OmniLight3D
var _time := 0.0
var _skip := false


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_DISABLED if Settings.use_web_profile() else Viewport.MSAA_2X
	_viewport.scaling_3d_scale = Settings.render_scale()
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_build()
	Look.batch_meshes(_world, true)


func _process(delta: float) -> void:
	_time += delta
	if Settings.use_web_profile():
		# The backdrop drifts slowly: half the frames are plenty in the browser.
		_skip = not _skip
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _skip else SubViewport.UPDATE_ALWAYS
	_fire_light.light_energy = 3.2 + sin(_time * 9.0) * 0.35 + sin(_time * 23.0) * 0.2
	var angle := sin(_time * 0.05) * 0.35
	_camera.position = FIRE + CAMERA_HOME.rotated(Vector3.UP, angle) + Vector3(0, sin(_time * 0.2) * 0.1, 0)
	_camera.look_at(FIRE + Vector3(-1.2, 1.0, 0))


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.34, 0.5)
	env.ambient_light_energy = 0.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.05
	env.fog_sky_affect = 0.2
	Look.tune_environment(env, "night")
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_world.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.35
	moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	moon.rotation = Vector3(deg_to_rad(-35), deg_to_rad(140), 0)
	_world.add_child(moon)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_world.add_child(_camera)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	plane.material = Look.block_material(Color(0.13, 0.16, 0.11))
	ground.mesh = plane
	_world.add_child(ground)
	Scenery.ground_patches(_world, 14.0, 18, rng)
	Scenery.grass(_world, 24.0, 4000, rng, 2.2)
	Scenery.night_sky(_world, rng, Vector3(-30, 24, -60))

	# The fire: a ring of stones, crossed logs, flames, sparks and its light.
	var stone := Look.block_material(Color(0.32, 0.31, 0.34))
	var log_wood := Look.block_material(Color(0.24, 0.15, 0.08))
	var char_wood := Look.block_material(Color(0.08, 0.06, 0.05))
	for i in 10:
		var a := TAU * i / 10.0
		Scenery.box(_world, Vector3(0.32, 0.2, 0.26), FIRE + Vector3(cos(a) * 0.75, 0.1, sin(a) * 0.75), stone, Vector3(0, -a, 0))
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		Scenery.box(_world, Vector3(0.14, 0.14, 0.9), FIRE + Vector3(cos(a) * 0.15, 0.16, sin(a) * 0.15), char_wood if i % 2 == 0 else log_wood, Vector3(0.35, -a, 0))
	Look.flame(_world, FIRE + Vector3(0, 0.35, 0), 2.6)
	_fire_light = Look.fire_light(Color(1.0, 0.55, 0.22), 3.2, 14.0)
	_fire_light.position = FIRE + Vector3(0, 1.1, 0)
	_world.add_child(_fire_light)
	var sparks := CPUParticles3D.new()
	sparks.amount = 30
	sparks.lifetime = 2.2
	sparks.position = FIRE + Vector3(0, 0.6, 0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.25
	sparks.direction = Vector3.UP
	sparks.spread = 20.0
	sparks.gravity = Vector3(0.15, 0.6, 0)
	sparks.initial_velocity_min = 0.6
	sparks.initial_velocity_max = 1.6
	var spark := BoxMesh.new()
	spark.size = Vector3.ONE * 0.03
	var spark_material := StandardMaterial3D.new()
	spark_material.albedo_color = Color(1.0, 0.6, 0.2)
	spark_material.emission_enabled = true
	spark_material.emission = Color(1.0, 0.55, 0.15)
	spark_material.emission_energy_multiplier = 5.0
	spark.material = spark_material
	sparks.mesh = spark
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	sparks.scale_amount_curve = shrink
	_world.add_child(sparks)

	# Log seats.
	for spot in [Vector3(-1.9, 0, 1.0), Vector3(1.4, 0, -1.8)]:
		var seat := Scenery.box(_world, Vector3(1.8, 0.36, 0.38), spot + Vector3(0, 0.18, 0), log_wood)
		seat.rotation.y = atan2(spot.x, spot.z) + PI / 2.0
	# The tent.
	var canvas := Look.block_material(Color(0.42, 0.36, 0.26))
	var tent := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(2.6, 1.9, 3.0)
	prism.material = canvas
	tent.mesh = prism
	tent.position = Vector3(-3.6, 0.95, -2.4)
	tent.rotation.y = 0.5
	_world.add_child(tent)
	var opening := MeshInstance3D.new()
	var dark := PrismMesh.new()
	dark.size = Vector3(1.0, 1.2, 0.04)
	dark.material = Look.block_material(Color(0.03, 0.025, 0.02))
	opening.mesh = dark
	opening.position = Vector3(-3.6, 0.6, -2.4) + Vector3(sin(0.5), 0, cos(0.5)) * 1.52
	opening.rotation.y = 0.5
	_world.add_child(opening)
	# Crates, a barrel and a lantern.
	var crate := Look.block_material(Color(0.3, 0.2, 0.11))
	Scenery.box(_world, Vector3(0.8, 0.8, 0.8), Vector3(2.8, 0.4, -2.6), crate, Vector3(0, 0.3, 0))
	Scenery.box(_world, Vector3(0.6, 0.6, 0.6), Vector3(2.75, 1.1, -2.55), crate, Vector3(0, 0.7, 0))
	Scenery.box(_world, Vector3(0.7, 0.9, 0.7), Vector3(3.8, 0.45, -1.6), Look.block_material(Color(0.22, 0.14, 0.08)))
	Scenery.box(_world, Vector3(0.74, 0.06, 0.74), Vector3(3.8, 0.75, -1.6), Look.block_material(Color(0.1, 0.1, 0.11), 0.6))
	Scenery.box(_world, Vector3(0.18, 0.26, 0.18), Vector3(2.75, 1.53, -2.55), Look.block_material(Color(0.1, 0.1, 0.11), 0.6))
	Look.flame(_world, Vector3(2.75, 1.52, -2.55), 0.5)
	var lantern := Look.fire_light(Color(1.0, 0.7, 0.35), 1.2, 5.0, false)
	lantern.position = Vector3(2.75, 1.6, -2.55)
	_world.add_child(lantern)
	# The training dummy, waiting.
	var dummy: Node3D = load("res://dummy.tscn").instantiate()
	dummy.position = Vector3(-0.6, 0.0, -4.2)
	dummy.rotation.y = 0.3
	_world.add_child(dummy)
	dummy.process_mode = Node.PROCESS_MODE_DISABLED
	dummy._hp_label.visible = false
	# Graves, trees and fence in the fog beyond.
	for i in 14:
		var a := rng.randf_range(-2.4, 1.0)
		var node := Node3D.new()
		node.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(9.0, 16.0)
		node.rotation.y = rng.randf() * TAU
		_world.add_child(node)
		Scenery.gravestone(node, rng.randi_range(0, 5), rng)
	for i in 9:
		var a := rng.randf() * TAU
		var node := Node3D.new()
		node.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(8.0, 18.0)
		_world.add_child(node)
		Scenery.dead_tree(node, rng, rng.randf_range(4.0, 7.0))
	var run := Scenery.fence(_world, 12.0)
	run.position = Vector3(-8.0, 0, -9.0)
	run.rotation.y = 0.2
	Scenery.mist(_world, Vector3(0, 0.4, -4.0), Vector3(16, 0.3, 12), 28)
	Scenery.wisps(_world, Vector3(0, 1.5, -6.0), Vector3(12, 1.0, 8), Color(0.45, 1.0, 0.75), 16)
