extends Node3D
## Key art (2026-10-29): the four revamp fighters (fighter_body.gd) in their
## action poses (banner_pose.gd) on a graveyard set built from the game's own
## scenery (stars and moon, gravestones, dead trees, a crypt glowing green,
## torches, mist), each with their energy (the Mauler's embers and a fire
## ring round his punch, the Answer's lightning, the Blur's speed streaks,
## the Stray's swirl), glowing eyes, bloom, a vignette and the title.
## Rendered off screen; run with -- --capture to save the banner (2172x724,
## with and without the title) and each fighter alone (1080x1440), then quit;
## -- --cover saves the itch.io cover (630x500, at 3x: 1890x1500).

const RevampBody = preload("res://fighter_body.gd")
const Banner = preload("res://playground/character_lab/banner_pose.gd")
const OUT := "user://character_lab_captures/"
const BANNER := Vector2i(2172, 724)
const PORTRAIT := Vector2i(1080, 1440)
## Each fighter's energy color (the eyes, the aura, the light on them).
const ENERGY := {
	"berserker": Color(1.0, 0.42, 0.1), "counter_master": Color(0.35, 0.7, 1.0),
	"combo_master": Color(0.68, 0.35, 1.0), "free_runner": Color(0.3, 1.0, 0.45),
	"elementalist": Color(1.0, 0.5, 0.15), "wise_guy": Color(1.0, 0.78, 0.25),
}
## Character select poses (2026-10-30), one signature pose each: [turn, pose].
## The Blur's is his flurry jab (the echo fists ride on it).
const SELECT := {
	"berserker": [0.15, {
		# Gloves knocking together low at his chest, chin down, leaning in.
		"pos": Vector3(0, -0.07, 0), "torso": Vector3(-0.16, 0.1, 0), "head": Vector3(-0.12, -0.1, 0),
		"ls": Vector3(0.6, 0, 0.5), "le": Vector3(1.35, 0, 0), "rs": Vector3(0.6, 0, -0.5), "re": Vector3(1.35, 0, 0),
		"lh": Vector3(0.3, 0, -0.06), "lk": Vector3(-0.1, 0, 0), "rh": Vector3(-0.25, 0, 0.06), "rk": Vector3(0, 0, 0),
		"lf": Vector3(0, 0.05, 0), "rf": Vector3(0, -0.6, 0)}],
	"counter_master": [0.45, {
		# Waiting for you: the lead hand out low, reading; the rear glove high.
		"pos": Vector3(0, -0.05, 0), "torso": Vector3(0.06, 0.3, 0), "head": Vector3(-0.06, -0.32, 0),
		"ls": Vector3(1.3, 0, 0.12), "le": Vector3(0.55, 0, 0), "rs": Vector3(1.0, 0, -0.1), "re": Vector3(2.35, 0, 0),
		"lh": Vector3(0.3, 0, -0.06), "lk": Vector3(-0.1, 0, 0), "rh": Vector3(-0.25, 0, 0.06), "rk": Vector3(0, 0, 0),
		"lf": Vector3(0, 0.0, 0), "rf": Vector3(0, -0.6, 0)}],
	"combo_master": [0.55, {}],
	"free_runner": [0.5, {
		# A low crouch, the lead fist out, the rear at his chin.
		"pos": Vector3(0, -0.22, 0), "torso": Vector3(-0.3, -0.3, 0), "head": Vector3(0.28, 0.32, 0),
		"ls": Vector3(1.35, 0, -0.18), "le": Vector3(0.35, 0, 0), "rs": Vector3(0.7, 0, 0.3), "re": Vector3(2.1, 0, 0),
		"lh": Vector3(0.55, 0, -0.12), "lk": Vector3(-0.25, 0, 0), "rh": Vector3(-0.55, 0, 0.12), "rk": Vector3(0, 0, 0),
		"lf": Vector3(0, 0.12, 0), "rf": Vector3(0, -0.65, 0)}],
	"elementalist": [-0.35, {
		# A fireball in his raised right palm, the left fist at his hip.
		"pos": Vector3(0, -0.05, 0), "torso": Vector3(0.05, -0.18, 0), "head": Vector3(0.05, 0.25, 0),
		"ls": Vector3(0.35, 0, -0.35), "le": Vector3(1.7, 0, 0), "rs": Vector3(1.9, 0, 0.25), "re": Vector3(1.3, 0, 0),
		"lh": Vector3(0.3, 0, -0.06), "lk": Vector3(-0.1, 0, 0), "rh": Vector3(-0.25, 0, 0.06), "rk": Vector3(0, 0, 0),
		"lf": Vector3(0, 0.05, 0), "rf": Vector3(0, -0.6, 0)}],
	"wise_guy": [0.2, {
		# "Come on": one fist up at his chest, the other hand out low, leaning
		# back, head cocked.
		"pos": Vector3(0, -0.04, 0), "torso": Vector3(0.1, 0.22, -0.05), "head": Vector3(0.06, -0.3, 0.1),
		"ls": Vector3(1.05, 0, 0.35), "le": Vector3(2.15, 0, 0), "rs": Vector3(0.75, 0, 0.75), "re": Vector3(0.7, 0, 0),
		"lh": Vector3(0.25, 0, -0.06), "lk": Vector3(-0.08, 0, 0), "rh": Vector3(-0.2, 0, 0.06), "rk": Vector3(0, 0, 0),
		"lf": Vector3(0, 0.0, 0), "rf": Vector3(0, -0.6, 0)}],
}

var _view: SubViewport
var _world: Node3D
var _camera: Camera3D
var _title: Control
## What a fighter put in the scene (cleared between portraits).
var _cast: Array = []


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = BANNER
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	var shown := TextureRect.new()
	shown.texture = _view.get_texture()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(shown)
	_world = Node3D.new()
	_view.add_child(_world)
	_build_set()
	_vignette()
	_title = _make_title()
	for fighter in Banner.CAST:
		var spec: Dictionary = Banner.CAST[fighter]
		# (Spread a little wider than the pose reference.)
		_fighter(fighter, spec.at * Vector3(-1.15, 1, 1), spec.turn, spec.pose)
	# The fighters in the lower two thirds, the title above them.
	_camera.position = Vector3(0.0, 1.35, -6.9)
	_camera.look_at(Vector3(0.0, 1.62, 0.2), Vector3.UP)
	if "--capture" in OS.get_cmdline_user_args():
		_title.visible = false
		await _snap("key_art_banner.png")
		_title.visible = true
		await _snap("key_art_banner_title.png")
		await _portraits()
		get_tree().quit()
	elif "--cover" in OS.get_cmdline_user_args():
		await _cover()
		get_tree().quit()
	elif "--select" in OS.get_cmdline_user_args():
		_title.visible = false
		await _select()
		get_tree().quit()


## The itch.io cover (2026-10-30): the four closer together, framed for
## 630x500 (rendered at 3x), with and without the title over them.
const COVER := Vector2i(1890, 1500)
const COVER_SPREAD := 0.95


func _cover() -> void:
	_view.size = COVER
	for node in _cast:
		node.queue_free()
	_cast.clear()
	for fighter in Banner.CAST:
		var spec: Dictionary = Banner.CAST[fighter]
		_fighter(fighter, spec.at * Vector3(-COVER_SPREAD, 1, 1), spec.turn, spec.pose)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = 39.0
	_camera.position = Vector3(0.0, 1.5, -7.3)
	_camera.look_at(Vector3(0.0, 1.5, 0.2), Vector3.UP)
	_title.scale = Vector2.ONE * 1.45
	_title.position = Vector2((COVER.x - BANNER.x * 1.45) * 0.5, 10)
	_title.visible = false
	await _snap("cover.png")
	_title.visible = true
	await _snap("cover_title.png")


## The character select art: each fighter alone in their signature pose,
## head to toe, 3:4 (1086x1448, the versus and loading size too).
func _select() -> void:
	_view.size = Vector2i(1086, 1448)
	# A neutral fill from the front, so their own colors read under the glow.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 170, 0)
	fill.light_color = Color(1.0, 0.96, 0.9)
	fill.light_energy = 0.9
	_world.add_child(fill)
	for fighter in SELECT:
		for node in _cast:
			node.queue_free()
		_cast.clear()
		var pose: Dictionary = SELECT[fighter][1]
		if pose.is_empty():
			pose = Banner.CAST[fighter].pose
		_fighter(fighter, Vector3.ZERO, SELECT[fighter][0], pose)
		var tall: float = _cast[0].scale.y / 0.92
		_camera.fov = 30.0
		_camera.position = Vector3(0.2, 1.05 * tall, -4.6 * tall)
		_camera.look_at(Vector3(0, 0.98 * tall, 0), Vector3.UP)
		await _snap("select_%s.png" % fighter)


# --- The set -------------------------------------------------------------------------

func _build_set() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.38, 0.6)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.09, 0.09, 0.2)
	env.fog_density = 0.025
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	environment.environment = env
	_view.add_child(environment)
	# Moonlight from behind and to the right (a cold rim), a faint fill.
	var moon_light := DirectionalLight3D.new()
	moon_light.rotation_degrees = Vector3(-30, 200, 0)
	moon_light.light_color = Color(0.6, 0.7, 1.0)
	moon_light.light_energy = 0.9
	moon_light.shadow_enabled = true
	_world.add_child(moon_light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 170, 0)
	fill.light_color = Color(0.7, 0.72, 0.9)
	fill.light_energy = 0.35
	_world.add_child(fill)
	_camera = Camera3D.new()
	_camera.fov = 26.0
	_world.add_child(_camera)
	_camera.make_current()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	# The camera looks down +Z: the screen's right is -X.
	Scenery.night_sky(_world, rng, Vector3(-30, 24, 80))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	plane.material = Look.block_material(Color(0.09, 0.085, 0.1))
	ground.mesh = plane
	_world.add_child(ground)
	Scenery.ground_patches(_world, 14.0, 30, rng)
	Scenery.grass(_world, 14.0, 220, rng, 3.5)
	# The crypt at the back, its doorway glowing green.
	var crypt := Scenery.crypt(_world, rng)
	crypt.position = Vector3(0, 0, 11)
	crypt.rotation.y = PI
	crypt.scale = Vector3.ONE * 1.6
	var door := OmniLight3D.new()
	door.light_color = Color(0.3, 1.0, 0.5)
	door.light_energy = 6.0
	door.omni_range = 6.0
	door.position = Vector3(0, 1.4, 8.0)
	_world.add_child(door)
	# Rows of graves, the middle kept clear for the crypt.
	for row in 4:
		var z := 3.5 + row * 2.3
		for i in 9:
			var x := -9.0 + i * 2.25 + rng.randf_range(-0.5, 0.5)
			if absf(x) < 3.0 and z > 6.0:
				continue
			# Slabs, obelisks and broken slabs only: no crosses (house rule).
			var grave := Scenery.gravestone(_world, [0, 2, 3, 5][rng.randi_range(0, 3)], rng)
			grave.position = Vector3(x, 0, z + rng.randf_range(-0.4, 0.4))
			grave.rotation.y = PI + rng.randf_range(-0.25, 0.25)
	for spot: Vector3 in [Vector3(-8.5, 0, 9), Vector3(9.5, 0, 8)]:
		Scenery.dead_tree(_world, rng, 6.5).position = spot
	for spot: Vector3 in [Vector3(-3.4, 0, 2.6), Vector3(3.4, 0, 2.6), Vector3(-6.2, 0, 5.5), Vector3(6.2, 0, 5.5)]:
		_torch(spot)
	_monsters()
	var back := OmniLight3D.new()
	back.light_color = Color(0.45, 0.55, 1.0)
	back.light_energy = 3.0
	back.omni_range = 12.0
	back.position = Vector3(0, 3.5, 9.5)
	_world.add_child(back)
	var mist := Scenery.mist(_world, Vector3(0, 0.3, 4.0), Vector3(11, 0.35, 7), 70)
	mist.preprocess = 16.0
	Scenery.wisps(_world, Vector3(0, 1.5, 8.5), Vector3(5, 1.0, 2.0))


## The game's own monsters lurking among the graves, frozen, eyes glowing.
func _monsters() -> void:
	# Most out to the sides (the middle is the fighters'), a few in the gaps.
	var lurkers := [
		["zombie", Vector3(-7.4, 0, 5.2)], ["skeleton", Vector3(-5.6, 0, 4.0)], ["bruiser", Vector3(-4.0, 0, 5.6)],
		["wraith", Vector3(-1.4, 0, 6.6)], ["zombie", Vector3(1.4, 0, 6.2)],
		["brawler", Vector3(3.9, 0, 4.4)], ["mage", Vector3(5.4, 0, 5.8)], ["zombie", Vector3(7.2, 0, 4.2)],
		["skeleton", Vector3(-8.8, 0, 7.6)], ["skeleton", Vector3(8.8, 0, 7.2)], ["zombie", Vector3(-2.9, 0, 4.4)],
		["skeleton", Vector3(2.9, 0, 4.6)],
	]

	for i in lurkers.size():
		var monster: Enemy = load("res://%s.tscn" % lurkers[i][0]).instantiate()
		monster.setup(null, false, {"hat": ""})
		monster.position = lurkers[i][1]
		monster.rotation.y = (0.25 if i % 2 == 0 else -0.25) * (1.0 + (i % 3) * 0.3)
		monster.scale = Vector3.ONE * 1.1
		_world.add_child(monster)
		monster.set_physics_process(false)
		monster.set_process(false)


func _torch(at: Vector3) -> void:
	var stone := Look.block_material(Color(0.2, 0.19, 0.21))
	Scenery.box(_world, Vector3(0.2, 1.5, 0.2), at + Vector3(0, 0.75, 0), stone)
	Scenery.box(_world, Vector3(0.4, 0.14, 0.4), at + Vector3(0, 1.55, 0), stone)
	_cube(_world, Vector3(0.26, 0.22, 0.26), at + Vector3(0, 1.72, 0), _glow(Color(1.0, 0.45, 0.1), 5.0))
	_cube(_world, Vector3(0.14, 0.2, 0.14), at + Vector3(0.02, 1.9, 0), _glow(Color(1.0, 0.8, 0.3), 6.0))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position = at + Vector3(0, 1.95, 0)
	_world.add_child(light)


# --- The fighters --------------------------------------------------------------------

func _fighter(fighter: String, at: Vector3, turn: float, pose: Dictionary) -> void:
	var body = RevampBody.new(fighter, "")
	body.voxel_scale = "large"
	body.build_budget_ms = 100000
	body.position = at
	body.rotation.y = turn
	_world.add_child(body)
	_cast.append(body)
	body.finish_build()
	body.wear_hat("")
	body._apply(pose)
	for ankle in ["lf", "rf"]:
		if body._joints.has(ankle) and pose.has(ankle):
			(body._joints[ankle] as Node3D).rotation = pose[ankle]
	var color: Color = ENERGY[fighter]
	var tall: float = body.scale.y / 0.92
	_eyes(body, color)
	# Their color on them from behind and at their feet.
	for spot: Vector3 in [Vector3(0.7 * signf(at.x + 0.01), 1.7, 1.0), Vector3(0, 0.3, -0.4)]:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 5.0
		light.omni_range = 3.0 * tall
		light.position = at + spot * tall
		_world.add_child(light)
		_cast.append(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fighter)
	match fighter:
		"berserker":
			_embers(at, tall, rng)
			# The ring of fire only round a punch.
			if (pose.get("re", Vector3.ZERO) as Vector3).x < 0.5:
				_fire_ring(body)
		"counter_master":
			_lightning(at, tall, color, rng)
		"combo_master":
			_echo_fists(body, color)
		"free_runner":
			_swirl(at, tall, color)
		"elementalist":
			_fireball(body)
			_embers(at, tall, rng)
		"wise_guy":
			_glints(at, tall, color, rng)


## Eyes glowing in the fighter's color, over the eye cubes.
func _eyes(body: Node3D, color: Color) -> void:
	var v: float = body._v
	var front := ceilf(-0.15 / v) * v - 0.004
	for side in [-1.0, 1.0]:
		var eye := _cube(body._joints.head, Vector3(2.0 * v, v, 0.008), Vector3(2.0 * v * side, 5.5 * v, front), _glow(color, 6.0))
		_cast.append(eye)


## Embers rising round the Mauler.
func _embers(at: Vector3, tall: float, rng: RandomNumberGenerator) -> void:
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.35, 1.0) * tall
		var y := rng.randf_range(0.0, 2.3) * tall
		var hot := Color(1.0, 0.45, 0.08).lerp(Color(1.0, 0.85, 0.3), rng.randf())
		var size := rng.randf_range(0.025, 0.06)
		_cast.append(_cube(_world, Vector3.ONE * size, at + Vector3(cos(a) * r, y, sin(a) * r * 0.6), _glow(hot, 5.0), Vector3(rng.randf(), rng.randf(), rng.randf())))


## A ring of fire round the Mauler's punching glove, a trail behind it.
func _fire_ring(body: Node3D) -> void:
	var elbow: Node3D = body._joints.re
	var glove: Vector3 = elbow.global_transform * Vector3(0, RevampBody.WRIST - 0.14, 0)
	var back: Vector3 = (elbow.global_transform.origin - glove).normalized()
	var across := back.cross(Vector3.UP).normalized()
	var up := across.cross(back).normalized()
	for i in 22:
		var a := i * TAU / 22.0
		var at := glove + back * 0.05 + (across * cos(a) + up * sin(a)) * 0.24
		var hot := Color(1.0, 0.4, 0.06) if i % 2 == 0 else Color(1.0, 0.75, 0.2)
		_cast.append(_cube(_world, Vector3.ONE * 0.07, at, _glow(hot, 6.0), Vector3(a, a * 0.5, 0)))
	for i in 18:
		var t := (i + 1) / 18.0
		var at := glove + back * (0.15 + t * 0.9) + (across * sin(t * 9.0) + up * cos(t * 7.0)) * 0.12 * (1.0 - t)
		_cast.append(_cube(_world, Vector3.ONE * lerpf(0.09, 0.03, t), at, _glow(Color(1.0, 0.55, 0.12), 5.0)))


## Jagged bolts crackling off the Answer.
func _lightning(at: Vector3, tall: float, color: Color, rng: RandomNumberGenerator) -> void:
	var bright := color.lerp(Color.WHITE, 0.45)
	for bolt in 6:
		var a := bolt * TAU / 6.0 + rng.randf_range(-0.3, 0.3)
		var point := at + Vector3(cos(a) * 0.3, rng.randf_range(0.9, 1.6), sin(a) * 0.25) * tall
		var heading := Vector3(cos(a), rng.randf_range(-0.2, 0.7), sin(a) * 0.6).normalized()
		for step in 6:
			var turn := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5), rng.randf_range(-0.6, 0.6))
			var next := point + (heading + turn).normalized() * rng.randf_range(0.12, 0.22) * tall
			_cast.append(_segment(point, next, 0.025, bright, 7.0))
			point = next


## The Blur's echo fists: see-through purple afterimages of his punching
## fist trailing back along the jab and fanned a little (hand speed, not
## foot speed), fading as they go.
func _echo_fists(body: Node3D, color: Color) -> void:
	var elbow: Node3D = body._joints.le
	var glove: Vector3 = elbow.global_transform * Vector3(0, RevampBody.WRIST - 0.075, 0)
	var back: Vector3 = (elbow.global_transform.origin - glove).normalized()
	var side := back.cross(Vector3.UP).normalized()
	var up := side.cross(back).normalized()
	var fist: Vector3 = Vector3(0.13, 0.15, 0.13) * body.scale.x * 1.05
	# Fanned round the punch like a flurry (straight behind, they hid in his arm).
	for i in 6:
		var t := (i + 1) / 6.0
		var turn := i * TAU / 6.0 + 0.4
		var at := glove + back * (0.06 + t * 0.3) + (side * cos(turn) + up * sin(turn)) * (0.2 + 0.08 * (i % 2)) * body.scale.x
		var ghost := StandardMaterial3D.new()
		ghost.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost.albedo_color = Color(color.lightened(0.2), 0.75 * (1.0 - t * 0.6))
		ghost.emission_enabled = true
		ghost.emission = color
		ghost.emission_energy_multiplier = 4.0 * (1.0 - t * 0.5)
		var echo := _cube(_world, fist * (1.0 - t * 0.25), at, ghost)
		echo.global_basis = elbow.global_basis
		_cast.append(echo)
	# A bright flash where the punch lands.
	_cast.append(_cube(_world, fist * 1.15, glove - back * 0.02, _glow(color.lerp(Color.WHITE, 0.4), 4.0)))


## A fireball over the Catalyst's raised right fist: a hot core in layers,
## sparks of his two inks round it.
func _fireball(body: Node3D) -> void:
	var elbow: Node3D = body._joints.re
	var palm: Vector3 = elbow.global_transform * Vector3(0, RevampBody.WRIST - 0.08, 0) + Vector3.UP * 0.17
	for layer: Array in [[0.2, Color(1.0, 0.35, 0.06), 4.0], [0.14, Color(1.0, 0.6, 0.15), 5.0], [0.08, Color(1.0, 0.92, 0.6), 7.0]]:
		_cast.append(_cube(_world, Vector3.ONE * layer[0], palm, _glow(layer[1], layer[2]), Vector3(0.6, 0.7, 0.3)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 6.0
	light.omni_range = 3.0
	light.position = palm
	_world.add_child(light)
	_cast.append(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 26:
		var a := rng.randf() * TAU
		var spot := palm + Vector3(cos(a), rng.randf_range(-0.3, 1.0), sin(a)) * rng.randf_range(0.22, 0.45)
		var ink := _p_ink(i)
		_cast.append(_cube(_world, Vector3.ONE * rng.randf_range(0.03, 0.06), spot, _glow(ink, 5.0), Vector3(a, a, 0)))


func _p_ink(i: int) -> Color:
	return Color(1.0, 0.5, 0.12) if i % 2 == 0 else Color(0.6, 0.3, 1.0)


## Gold glints round Tony (the chain, the ring, the money).
func _glints(at: Vector3, tall: float, color: Color, rng: RandomNumberGenerator) -> void:
	for i in 12:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.55, 1.0) * tall
		var spot := at + Vector3(cos(a) * r, rng.randf_range(0.5, 2.0) * tall, sin(a) * r * 0.6)
		var size := rng.randf_range(0.015, 0.03)
		_cast.append(_cube(_world, Vector3(size, size * 2.2, size * 0.4), spot, _glow(color.lightened(rng.randf() * 0.3), 5.0), Vector3(0, 0, PI * 0.25)))
		_cast.append(_cube(_world, Vector3(size * 2.2, size, size * 0.4), spot, _glow(color.lightened(0.2), 5.0), Vector3(0, 0, PI * 0.25)))


## Speed streaks trailing the Blur's dash (unused: he's hand speed).
func _streaks(at: Vector3, turn: float, tall: float, color: Color, rng: RandomNumberGenerator) -> void:
	var ahead := Vector3(-sin(turn), 0, -cos(turn))
	var side := ahead.cross(Vector3.UP)
	for i in 16:
		var start := at + side * rng.randf_range(-0.45, 0.45) * tall + Vector3.UP * rng.randf_range(0.2, 1.8) * tall - ahead * rng.randf_range(0.2, 0.5)
		var length := rng.randf_range(0.6, 1.6)
		_cast.append(_segment(start, start - ahead * length, rng.randf_range(0.015, 0.04), color.lerp(Color.WHITE, rng.randf() * 0.3), 5.0))


## A double swirl of light round the Stray.
func _swirl(at: Vector3, tall: float, color: Color) -> void:
	for strand in 2:
		for i in 60:
			var t := i / 60.0
			var a := t * TAU * 1.7 + strand * PI
			var r := (0.5 + 0.18 * sin(t * PI)) * tall
			var spot := at + Vector3(cos(a) * r, (0.1 + t * 1.9) * tall, sin(a) * r * 0.8)
			_cast.append(_cube(_world, Vector3.ONE * lerpf(0.075, 0.025, t), spot, _glow(color.lerp(Color.WHITE, 0.25 * (1.0 - t)), 5.0), Vector3(a, 0, a)))


# --- Pieces ---------------------------------------------------------------------------

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _cube(parent: Node3D, size: Vector3, at: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var cube := MeshInstance3D.new()
	cube.mesh = mesh
	cube.position = at
	cube.rotation = rot
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(cube)
	return cube


## A glowing bar from a to b.
func _segment(a: Vector3, b: Vector3, thick: float, color: Color, energy: float) -> MeshInstance3D:
	var bar := _cube(_world, Vector3(thick, thick, a.distance_to(b)), (a + b) * 0.5, _glow(color, energy))
	bar.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	return bar


# --- Overlay --------------------------------------------------------------------------

func _vignette() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.25, 1.0);
	COLOR = vec4(0.0, 0.0, 0.02, smoothstep(0.3, 0.75, length(d)) * 0.8);
}"""
	material.shader = shader
	shade.material = material
	_view.add_child(shade)


## The title across the top: Anton drawn off screen, then made spooky by
## TITLE_SHADER: bone white fading to fire down each letter, pitted and
## cracked, blocky blood drips hanging off the bottoms, a red glow behind.
func _make_title() -> Control:
	var page := SubViewport.new()
	page.size = Vector2i(BANNER.x, 330)
	page.transparent_bg = true
	page.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(page)
	var label := Label.new()
	label.text = "FRIGHT NIGHT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://fonts/Anton-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 160)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 14)
	label.position = Vector2(0, 10)
	label.size = Vector2(BANNER.x, 240)
	page.add_child(label)
	var title := TextureRect.new()
	title.texture = page.get_texture()
	title.position = Vector2(0, -14)
	title.size = Vector2(page.size)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = TITLE_SHADER
	material.shader = shader
	title.material = material
	_view.add_child(title)
	return title


## (The page: white letters, a black outline, on clear.)
const TITLE_SHADER := """shader_type canvas_item;
const float CELL = 7.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 at = UV / px;
	vec4 page = texture(TEXTURE, UV);
	float face = page.a * page.r;
	float edge = page.a * (1.0 - page.r);
	// Pitted and worn: patches eaten out of the letters and their edge.
	float wear = noise(at / 10.0) * 0.65 + noise(at / 3.0) * 0.35;
	float pit = step(wear, 0.22);
	face *= 1.0 - pit;
	edge *= 1.0 - pit * 0.6;
	// Cracks: thin dark lines along the ridges of a broad noise.
	float crack = step(abs(noise(at / 22.0 + 7.0) - 0.5), 0.022) * face;
	// Bone white at the top, fire at the bottom of the letters.
	float down = clamp((at.y - 40.0) / 190.0, 0.0, 1.0);
	vec3 fill = mix(vec3(1.0, 0.94, 0.8), vec3(1.0, 0.42, 0.08), smoothstep(0.35, 0.95, down));
	fill = mix(fill, vec3(0.35, 0.03, 0.02), crack);
	// Blood drips in blocky cells: a column of cells hangs down from a
	// letter's bottom, each column its own length (most short, a few long).
	vec2 cell = floor(at / CELL);
	float length = floor(pow(hash(vec2(cell.x, 3.0)), 2.6) * 11.0);
	float drip = 0.0;
	if (page.a < 0.5 && length > 0.0) {
		for (int k = 1; k <= 11; k++) {
			if (float(k) > length) break;
			vec2 above = (vec2(cell.x, cell.y - float(k)) + 0.5) * CELL * px;
			if (texture(TEXTURE, above).a > 0.6) {
				// Narrower toward the tip.
				float width = mix(0.5, 0.22, float(k) / length);
				drip = step(abs(fract(at.x / CELL) - 0.5), width);
				break;
			}
		}
	}
	// A red glow round it all.
	float glow = 0.0;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		glow += texture(TEXTURE, UV + vec2(cos(a), sin(a)) * 16.0 * px).a;
	}
	glow = glow / 12.0 * 0.75;
	vec4 color = vec4(0.9, 0.18, 0.04, glow);
	color = mix(color, vec4(0.48, 0.03, 0.02, 1.0), drip);
	color = mix(color, vec4(0.25, 0.02, 0.01, 1.0), edge);
	color = mix(color, vec4(fill, 1.0), face);
	COLOR = color;
}
"""


# --- Captures -------------------------------------------------------------------------

## Each fighter alone, the same pose and set, 3:4.
func _portraits() -> void:
	_title.visible = false
	_view.size = PORTRAIT
	for fighter in Banner.CAST:
		for node in _cast:
			node.queue_free()
		_cast.clear()
		var pose: Dictionary = Banner.CAST[fighter].pose
		_fighter(fighter, Vector3.ZERO, Banner.SINGLES[fighter].turn, pose)
		var tall: float = _cast[0].scale.y / 0.92
		var air: float = maxf((pose.pos as Vector3).y, 0.0) * tall
		_camera.fov = 32.0
		_camera.position = Vector3(0.25, 1.05 * tall + air, -4.3 * tall)
		_camera.look_at(Vector3(0, 1.0 * tall + air, 0), Vector3.UP)
		await _snap("key_art_%s.png" % fighter)


func _snap(file: String) -> void:
	for i in 6:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + file)
	_view.get_texture().get_image().save_png(path)
	print("KEY_ART ", path)
