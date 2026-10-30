extends "res://playground/character_lab/key_art.gd"
## Dead League art (2026-10-29), rendered from the game's own bosses
## (DeadLeagueBoss on BossRig) on the key art's graveyard set (key_art.gd):
## - the menu's key art (1672x941): all five contenders posed in a ring,
##   lit and glowing in their colors, monsters crowding round the ring;
## - a silhouette mask of each later contender, for the menu's locked
##   shadows (soften them into art/dead_league/locked_N.png);
## - each contender's portrait (1086x1448), and the True Coffin King's in
##   Insano Style (shown only once he's been beaten);
## - a full-screen loading scene of the four fighters (1920x1080).
## Run with -- --capture; everything lands in the capture folder.

const BOSS_SCENE := preload("res://dead_league_boss.tscn")
const KEY_SIZE := Vector2i(1672, 941)
const LOADING_SIZE := Vector2i(1920, 1080)
## Each contender: where they stand in the lineup (x as seen on screen),
## their turn, and the moment they're frozen in: [action, hand, share of
## the clip]. In League order left to right, the Bellman first, the King
## last, standing braced and grim.
const LINEUP := [
	{"at": Vector3(-3.5, 0, 0.45), "turn": 0.35, "pose": ["uppercut", "right", 0.5]},
	{"at": Vector3(-1.85, 0, 0.2), "turn": 0.2, "pose": ["hook", "left", 0.5]},
	{"at": Vector3(0.0, 0, -0.3), "turn": 0.0, "pose": ["cross", "left", 0.5]},
	{"at": Vector3(1.85, 0, 0.2), "turn": -0.2, "pose": ["toss_load", "right", 0.85]},
	{"at": Vector3(3.5, 0, 0.45), "turn": -0.35, "pose": ["brace", "right", 0.5]},
]

var _ring: Array = []


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = KEY_SIZE
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
	_build_ring()
	_crowd()
	for i in LINEUP.size():
		await _contender(i, LINEUP[i].at * Vector3(-1, 1, 1), LINEUP[i].turn, LINEUP[i].pose)
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 1.9, -9.6)
	_camera.look_at(Vector3(0.0, 1.45, 0.4), Vector3.UP)
	if "--capture" in OS.get_cmdline_user_args():
		await _snap("league_key_art.png")
		for i in range(1, LINEUP.size()):
			await _mask(i)
		await _portraits_league()
		await _loading_fighters()
		get_tree().quit()


# --- The ring and the crowd ---------------------------------------------------------

## A ring on the grass: a dark canvas, corner posts, three red ropes a side.
func _build_ring() -> void:
	var half := Vector2(4.9, 2.4)
	var center := Vector3(0, 0, 0.35)
	var mat := Look.block_material(Color(0.1, 0.1, 0.16))
	var apron := Look.block_material(Color(0.05, 0.05, 0.08))
	var post := Look.block_material(Color(0.16, 0.15, 0.17))
	var rope := Look.block_material(Color(0.45, 0.05, 0.04))
	_ring.append(Scenery.box(_world, Vector3(half.x * 2.0, 0.12, half.y * 2.0), center + Vector3(0, 0.06, 0), mat))
	_ring.append(Scenery.box(_world, Vector3(half.x * 2.0 + 0.3, 0.1, half.y * 2.0 + 0.3), center + Vector3(0, 0.04, 0), apron))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_ring.append(Scenery.box(_world, Vector3(0.24, 1.7, 0.24), center + Vector3(half.x * x, 0.85, half.y * z), post))
	# Ropes at the back and sides only, so none cut across the contenders.
	for height: float in [0.6, 1.0, 1.4]:
		_ring.append(_cube(_world, Vector3(half.x * 2.0, 0.035, 0.035), center + Vector3(0, height, half.y), rope))
		for x in [-1.0, 1.0]:
			_ring.append(_cube(_world, Vector3(0.035, 0.035, half.y * 2.0), center + Vector3(half.x * x, height, 0), rope))
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.85, 0.85, 1.0)
	spot.light_energy = 3.0
	spot.spot_range = 14.0
	spot.spot_angle = 40.0
	spot.position = center + Vector3(0, 9, -1.5)
	spot.rotation_degrees = Vector3(-82, 0, 0)
	spot.shadow_enabled = true
	_world.add_child(spot)
	_ring.append(spot)


## More of the game's monsters packed round the ring's sides, watching.
func _crowd() -> void:
	var row := [
		["zombie", Vector3(-6.4, 0, 1.0)], ["skeleton", Vector3(-6.9, 0, -0.6)], ["brawler", Vector3(6.5, 0, 0.8)],
		["zombie", Vector3(6.9, 0, -0.8)], ["wraith", Vector3(-5.6, 0, 3.4)], ["skeleton", Vector3(5.7, 0, 3.2)],
	]
	for i in row.size():
		var monster: Enemy = load("res://%s.tscn" % row[i][0]).instantiate()
		monster.setup(null, false, {"hat": ""})
		monster.position = row[i][1]
		monster.rotation.y = -PI * 0.5 * signf(row[i][1].x) + (0.3 if i % 2 == 0 else -0.2)
		monster.scale = Vector3.ONE * 1.1
		_world.add_child(monster)
		monster.set_physics_process(false)
		monster.set_process(false)
		_ring.append(monster)


# --- The contenders ------------------------------------------------------------------

## A contender posed, glowing in their color: a light behind and at their
## feet, embers rising. true_king: the Coffin King as the True Coffin King,
## in Insano Style, a burning floor round him.
func _contender(index: int, at: Vector3, turn: float, pose: Array, true_king := false) -> Node3D:
	var boss := BOSS_SCENE.instantiate() as DeadLeagueBoss
	boss.configure(index, 3)
	if true_king:
		boss.empower(5)
	boss.setup(null, false)
	boss.position = at + Vector3(0, 0.12, 0)
	boss.rotation.y = turn
	_world.add_child(boss)
	if true_king:
		boss.go_insano()
	_cast.append(boss)
	for i in 8:
		await get_tree().process_frame
	boss.set_physics_process(false)
	boss.set_process(false)
	var rig: BossRig = boss._rig
	rig.set_motion(Vector3.ZERO, boss.global_basis, true)
	rig.play(pose[0], 1.0, pose[1], 0.5, float(pose[2]))
	rig.advance(0.0)
	# Standing on the floor whatever the pose does to the legs (a deep
	# crouch sank the Bellman into the canvas).
	var low := INF
	for geometry in boss.find_children("*", "GeometryInstance3D", true, false):
		var box: AABB = (geometry as GeometryInstance3D).global_transform * (geometry as GeometryInstance3D).get_aabb()
		low = minf(low, box.position.y)
	if low < INF:
		boss.position.y += (at.y + (0.12 if not _ring.is_empty() and _ring[0].visible else 0.0)) - low
	var color: Color = DeadLeagueBoss.INSANO_COLOR if true_king else DeadLeagueRules.boss(index).accent
	var size: float = DeadLeagueBoss.BODY_SCALE[index]
	for spot: Vector3 in [Vector3(0.8 * signf(at.x + 0.01), 2.2, 1.2), Vector3(0, 0.4, -0.6), Vector3(-0.9 * signf(at.x + 0.01), 1.4, 0.9)]:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 2.6
		light.omni_range = 3.0 * size
		light.position = at + spot * size
		_world.add_child(light)
		_cast.append(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 31 + (7 if true_king else 0)
	# A few embers in their color drifting up round them (more on the King).
	for i in (60 if true_king else 22):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.5, 1.1) * size
		var y := rng.randf_range(0.6, 2.4) * size
		var tone := color.lerp(Color(1.0, 0.85, 0.4), rng.randf() * 0.5) if true_king else color.lightened(rng.randf() * 0.25)
		_cast.append(_cube(_world, Vector3.ONE * rng.randf_range(0.02, 0.045), at + Vector3(cos(a) * r, y, sin(a) * r * 0.6), _glow(tone, 4.0), Vector3(rng.randf(), rng.randf(), rng.randf())))
	if true_king:
		# The Insano ring burning under him.
		for i in 40:
			var a := i * TAU / 40.0
			var r := 1.5 * size + (i % 3) * 0.12
			var hot := Color(1.0, 0.3, 0.08) if i % 2 == 0 else Color(0.95, 0.15, 0.35)
			_cast.append(_cube(_world, Vector3(0.18, rng.randf_range(0.1, 0.45), 0.18), at + Vector3(cos(a) * r, 0.15, sin(a) * r), _glow(hot, 6.0), Vector3(0, a, 0)))
	return boss


# --- Captures -------------------------------------------------------------------------

## Contender index alone, black on clear: the menu's locked shadow (the
## soft shadow is made from this outside the game, PIL blur).
func _mask(index: int) -> void:
	var env: Environment = (_view.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
	var fog := env.fog_enabled
	var glow := env.glow_enabled
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.fog_enabled = false
	env.glow_enabled = false
	_view.transparent_bg = true
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	var shown := {}
	for node in _world.get_children():
		shown[node] = node.visible
		node.visible = node == _cast[_boss_slot(index)] or node is Camera3D
	for overlay in _view.get_children():
		if overlay is CanvasItem:
			shown[overlay] = overlay.visible
			overlay.visible = false
	var boss: Node3D = _cast[_boss_slot(index)]
	for geometry in boss.find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).material_override = black
	await _snap("league_mask_%d.png" % index)
	for geometry in boss.find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).material_override = null
	for node in shown:
		node.visible = shown[node]
	env.background_mode = Environment.BG_COLOR
	env.fog_enabled = fog
	env.glow_enabled = glow
	_view.transparent_bg = false


## Where contender index's boss sits in _cast (each adds itself, 3 lights
## and its embers; the lineup is built in order).
func _boss_slot(index: int) -> int:
	var slot := 0
	for node in _cast:
		if node is DeadLeagueBoss and (node as DeadLeagueBoss).profile_index == index:
			return slot
		slot += 1
	return 0


## Each contender alone, from low down, the set soft behind them; then the
## True Coffin King.
func _portraits_league() -> void:
	_view.size = PORTRAIT
	for node in _ring:
		node.visible = false
	var blur := CameraAttributesPractical.new()
	blur.dof_blur_far_enabled = true
	blur.dof_blur_far_distance = 5.5
	blur.dof_blur_far_transition = 6.0
	blur.dof_blur_amount = 0.12
	_camera.attributes = blur
	for index in LINEUP.size() + 1:
		var true_king := index == LINEUP.size()
		var who := LINEUP.size() - 1 if true_king else index
		for node in _cast:
			node.queue_free()
		_cast.clear()
		await _contender(who, Vector3.ZERO, 0.25 if not true_king else 0.15, LINEUP[who].pose, true_king)
		var size: float = DeadLeagueBoss.BODY_SCALE[who]
		_camera.fov = 34.0
		if true_king:
			# Back and low enough for the burning ring round his feet, a red
			# glow swelling behind him.
			_camera.position = Vector3(0.35 * size, 0.45 * size, -4.4 * size)
			_camera.look_at(Vector3(0, 1.15 * size, 0), Vector3.UP)
			var flare := OmniLight3D.new()
			flare.light_color = Color(1.0, 0.25, 0.1)
			flare.light_energy = 8.0
			flare.omni_range = 5.0 * size
			flare.position = Vector3(0, 1.6 * size, 1.4 * size)
			_world.add_child(flare)
			_cast.append(flare)
		elif who == 3:
			# The Plague Doctor from above, looming up at you under the beak.
			_camera.position = Vector3(0.5 * size, 2.9 * size, -3.0 * size)
			_camera.look_at(Vector3(0, 1.05 * size, 0), Vector3.UP)
		else:
			_camera.position = Vector3(0.35 * size, 0.55 * size, -3.9 * size)
			_camera.look_at(Vector3(0, 1.2 * size, 0), Vector3.UP)
		await _snap("league_portrait_%s.png" % ("true" if true_king else str(index)))
	_camera.attributes = null


## The four fighters on the graveyard set at 16:9, for a loading screen.
func _loading_fighters() -> void:
	for node in _cast:
		node.queue_free()
	_cast.clear()
	_view.size = LOADING_SIZE
	for fighter in Banner.CAST:
		var spec: Dictionary = Banner.CAST[fighter]
		_fighter(fighter, spec.at * Vector3(-1.1, 1, 1), spec.turn, spec.pose)
	_camera.fov = 30.0
	_camera.position = Vector3(0.0, 1.3, -7.6)
	_camera.look_at(Vector3(0.0, 1.35, 0.2), Vector3.UP)
	await _snap("loading_fighters.png")
