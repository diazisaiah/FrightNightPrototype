extends "res://playground/character_lab/key_art.gd"
## The trailer's ending (2026-10-31): the four fighters run in from every side
## and meet, a slight nod, then all turn the same way. The Coffin King, in a
## dramatic intro. One by one they hit their stance, each lighting up with
## their own aura. All four together in their auras, the title up top, a long
## hold, and out.
## Fixed clock, like trailer.gd:
##   godot --path <project> res://playground/trailer/ending.tscn --resolution 1920x1080
##         --write-movie out.avi --fixed-fps 30 -- --to=21

const KingScene := preload("res://dead_league_boss.tscn")
const FPS := 30.0
const VIEW := Vector2i(1920, 1080)
const ORDER := ["berserker", "counter_master", "combo_master", "free_runner"]
const START := {
	"berserker": Vector3(-9, 0, 0), "counter_master": Vector3(0, 0, 9),
	"combo_master": Vector3(9, 0, 0), "free_runner": Vector3(0, 0, -9),
}
const MEET := {
	"berserker": Vector3(-1.3, 0, 0), "counter_master": Vector3(0, 0, 1.3),
	"combo_master": Vector3(1.3, 0, 0), "free_runner": Vector3(0, 0, -1.3),
}
## When each stands in his stance (seconds): the four close-ups, in turn.
## Cut to the song (this clip starts at song time E, set by --start=E): the
## King is in place for the build, the four stances land on its hits
## (129.92, 131.22, 132.52, 133.82), the group on the one before the drop
## (135.12), and the title drops with the drop itself (135.72).
var T_RUN := 3.4
var T_NOD := 4.9
var T_TURN := 6.1
var T_KING := 9.9
var T_STANCE := [9.9, 11.0, 12.1, 13.2]
var T_GROUP := 14.3
var T_TITLE := 15.6

var _clock := 0.0
var _end := 21.0
var _frame := 0
var _bodies := {}
var _auras := {}
var _fade: ColorRect
var _flash_rect: ColorRect
var _king: DeadLeagueBoss
var _king_lights: Array = []
var _grouped := false
var _staged := {}
var _live := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--to="):
			_end = float(arg.substr(5))
		elif arg.begins_with("--start="):
			var e := float(arg.substr(8))
			T_KING = 129.92 - e
			T_STANCE = [T_KING, T_KING + 1.3, T_KING + 2.6, T_KING + 3.9]
			T_GROUP = 135.12 - e
			T_TITLE = 135.72 - e
			T_TURN = T_KING - 3.7
			T_NOD = T_TURN - 1.6
			T_RUN = maxf(T_NOD - 2.7, 2.5)
	_view = SubViewport.new()
	_view.size = VIEW
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	var shown := TextureRect.new()
	shown.texture = _view.get_texture()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(shown)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(_flash_rect)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 1)
	layer.add_child(_fade)
	_world = Node3D.new()
	_view.add_child(_world)
	_build_set()
	_vignette()
	for fighter in ORDER:
		_spawn(fighter)
	_title = _make_title()
	_title.scale = Vector2.ONE * (VIEW.x / float(BANNER.x))
	_title.position = Vector2(0, 8)
	_title.modulate.a = 0.0
	await _make_king()
	print("MARK %d" % Engine.get_frames_drawn())
	_direct(0.0)
	_live = true


func _monsters() -> void:
	pass


func _process(_delta: float) -> void:
	if not _live:
		return
	_clock += 1.0 / FPS
	_frame += 1
	_direct(_clock)
	if _clock >= _end:
		get_tree().quit()


# --- Cast -----------------------------------------------------------------------------

func _spawn(fighter: String) -> void:
	var body = RevampBody.new(fighter, "")
	body.voxel_scale = "large"
	body.build_budget_ms = 100000
	body.position = START[fighter]
	_world.add_child(body)
	body.finish_build()
	body.wear_hat("")
	_bodies[fighter] = body


func _make_king() -> void:
	_king = KingScene.instantiate() as DeadLeagueBoss
	_king.configure(4, 3)
	_king.setup(null, false)
	_king.position = Vector3(0, 0.12, 4.4)
	# Nothing between the camera and him: the graves round his feet go.
	for node in _world.get_children():
		if node is Node3D and not node is Camera3D and node.position.y < 0.5 and not node is Light3D and Vector2(node.position.x, node.position.z - 4.4).length() < 3.4 and node != _king:
			node.visible = false
	_king.rotation.y = 0.0
	_world.add_child(_king)
	for i in 8:
		await get_tree().process_frame
	_king.set_physics_process(false)
	_king.set_process(false)
	var rig: BossRig = _king._rig
	rig.set_motion(Vector3.ZERO, _king.global_basis, true)
	rig.play("brace", 1.0, "right", 0.5, 0.5)
	rig.advance(0.0)
	var low := INF
	for geometry in _king.find_children("*", "GeometryInstance3D", true, false):
		var box: AABB = (geometry as GeometryInstance3D).global_transform * (geometry as GeometryInstance3D).get_aabb()
		low = minf(low, box.position.y)
	if low < INF:
		_king.position.y += 0.12 - low
	var color: Color = DeadLeagueRules.boss(4).accent
	var size: float = DeadLeagueBoss.BODY_SCALE[4]
	for spot: Vector3 in [Vector3(1.0, 2.6, -1.4), Vector3(0, 0.5, -1.0), Vector3(-1.1, 1.6, -1.2), Vector3(0, 3.6, 0.4)]:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 0.0
		light.omni_range = 5.0 * size
		light.position = _king.position + spot * size
		_world.add_child(light)
		_king_lights.append(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.6, 1.5) * size
		var y := rng.randf_range(0.4, 3.6) * size
		_cube(_world, Vector3.ONE * rng.randf_range(0.02, 0.05), _king.position + Vector3(cos(a) * r, y, sin(a) * r * 0.6),
				_glow(color.lerp(Color(1.0, 0.85, 0.4), rng.randf() * 0.5), 4.0), Vector3(rng.randf(), rng.randf(), rng.randf()))
	_king.visible = false


## A fighter's own aura, built where he stands in his stance right now.
func _light_up(fighter: String, pose: Dictionary) -> void:
	for node in _auras.get(fighter, []):
		if is_instance_valid(node):
			node.queue_free()
	var before := _cast.size()
	var body: Node3D = _bodies[fighter]
	var at := body.position
	var color: Color = ENERGY[fighter]
	_eyes(body, color)
	for spot: Vector3 in [Vector3(0.7 * signf(at.x + 0.01), 1.7, 1.0), Vector3(0, 0.3, -0.4)]:
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 8.0
		light.omni_range = 3.4
		light.position = at + spot
		_world.add_child(light)
		_cast.append(light)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(fighter)
	match fighter:
		"berserker":
			_embers(at, 1.0, rng)
			if (pose.get("re", Vector3.ZERO) as Vector3).x < 0.5:
				_fire_ring(body)
		"counter_master":
			_lightning(at, 1.0, color, rng)
		"combo_master":
			_echo_fists(body, color)
		"free_runner":
			_swirl(at, 1.0, color)
	# Lightning is the Answer's alone; the others burn as bright with their
	# own effects (flames, a violet echo and swirl, a green double swirl).
	match fighter:
		"berserker":
			_embers(at, 1.0, rng)
			_embers(at, 1.2, rng)
			# Flames licking up round him.
			for i in 46:
				var angle := rng.randf() * TAU
				var radius := rng.randf_range(0.35, 0.8)
				var height := rng.randf_range(0.4, 1.9)
				var hot := Color(1.0, 0.45, 0.08).lerp(Color(1.0, 0.85, 0.3), rng.randf())
				_cast.append(_cube(_world, Vector3(0.09, height * 0.5, 0.09), at + Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius), _glow(hot, 7.0), Vector3(0, angle, 0)))
		"combo_master":
			_swirl(at, 1.1, color)
		"free_runner":
			_swirl(at, 1.3, color.lightened(0.2))
	_auras[fighter] = _cast.slice(before)


func _flash(color: Color, strength: float) -> void:
	_flash_rect.color = Color(color, strength)


## Ease-out bounce: lands, hops back up a little, and settles.
func _bounce(x: float) -> float:
	if x < 1.0 / 2.75:
		return 7.5625 * x * x
	elif x < 2.0 / 2.75:
		x -= 1.5 / 2.75
		return 7.5625 * x * x + 0.75
	elif x < 2.5 / 2.75:
		x -= 2.25 / 2.75
		return 7.5625 * x * x + 0.9375
	x -= 2.625 / 2.75
	return 7.5625 * x * x + 0.984375


func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


# --- The cut ---------------------------------------------------------------------------

func _cam(pos: Vector3, target: Vector3, fov := 45.0, roll := 0.0) -> void:
	_camera.fov = fov
	_camera.position = pos
	_camera.look_at(target, Vector3.UP)
	if roll != 0.0:
		_camera.rotate_object_local(Vector3(0, 0, 1), roll)


## Running: arms and legs swinging, a bob, leaning forward.
func _run_pose(t: float, phase_shift: float) -> Dictionary:
	var p := t * 10.0 + phase_shift
	var s := sin(p)
	return {
		"pos": Vector3(0, -0.05 + 0.05 * absf(sin(p)), 0), "torso": Vector3(-0.28, 0.0, 0.0), "head": Vector3(0.2, 0, 0),
		"ls": Vector3(-0.9 * s, 0, 0.1), "le": Vector3(1.5, 0, 0), "rs": Vector3(0.9 * s, 0, -0.1), "re": Vector3(1.5, 0, 0),
		"lh": Vector3(0.95 * s, 0, 0), "lk": Vector3(-0.2 - 1.0 * maxf(0.0, -s), 0, 0),
		"rh": Vector3(-0.95 * s, 0, 0), "rk": Vector3(-0.2 - 1.0 * maxf(0.0, s), 0, 0),
	}


func _stand_pose(nod := 0.0) -> Dictionary:
	return {
		"pos": Vector3(0, -0.02, 0), "torso": Vector3(0.02, 0, 0), "head": Vector3(nod, 0, 0),
		"ls": Vector3(0.1, 0, 0.1), "le": Vector3(0.25, 0, 0), "rs": Vector3(0.1, 0, -0.1), "re": Vector3(0.25, 0, 0),
		"lh": Vector3(0.0, 0, 0), "lk": Vector3(-0.05, 0, 0), "rh": Vector3(0.0, 0, 0), "rk": Vector3(-0.05, 0, 0),
	}


func _stance_of(fighter: String) -> Dictionary:
	var pose: Dictionary = SELECT[fighter][1]
	if pose.is_empty():
		pose = Banner.CAST[fighter].pose
	return pose


func _facing(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _direct(t: float) -> void:
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - 0.1)
	# Black at both ends (and out of the Colossus, in the cut).
	var fade := 1.0 - _ease(t / 0.6)
	if t > _end - 2.0:
		fade = _ease((t - (_end - 2.0)) / 2.0)
	_fade.color.a = fade
	_king.visible = t >= T_TURN and t < T_STANCE[0]
	if t < T_STANCE[0] or t >= T_GROUP:
		for f in ORDER:
			_bodies[f].visible = t < T_TURN or t >= T_GROUP
	# The title drops in from above and bounces to rest (no fade).
	var drop := clampf((t - T_TITLE) / 0.55, 0.0, 1.0)
	_title.modulate.a = 1.0 if t >= T_TITLE else 0.0
	_title.position = Vector2(0, lerpf(-360.0, 8.0, _bounce(drop)))
	if t >= T_TITLE and not _staged.has("title") and drop >= 0.4:
		_staged["title"] = true
		_flash(Color(1.0, 0.7, 0.4), 0.35)
	for light in _king_lights:
		light.light_energy = (3.0 + 0.8 * sin(t * 9.0)) * clampf((t - T_TURN) / 0.6, 0.0, 1.0)
	if t < T_RUN:
		_run(t)
	elif t < T_NOD:
		_nod(t)
	elif t < T_TURN:
		_turn(t)
	elif t < T_STANCE[0]:
		_king_intro(t)
	elif t < T_GROUP:
		_stances(t)
	else:
		_group(t)


## They run in from every side.
func _run(t: float) -> void:
	var u := _ease(t / T_RUN)
	var i := 0
	for fighter in ORDER:
		var body: Node3D = _bodies[fighter]
		var from: Vector3 = START[fighter] * (T_RUN / 3.4 * 0.8 + 0.2)
		var to: Vector3 = MEET[fighter]
		body.position = from.lerp(to, minf(t / T_RUN * 1.0, 1.0) * 1.0)
		body.rotation.y = _facing(to - from)
		body._apply(_run_pose(t, i * 0.9) if t < T_RUN - 0.25 else _run_pose(t, i * 0.9).merged(_stand_pose(), true))
		i += 1
	_cam(Vector3(lerpf(7.5, 5.5, u), lerpf(5.2, 3.6, u), lerpf(-8.0, -5.5, u)), Vector3(0, 1.0, 0), 46.0)


## A slight nod to each other.
func _nod(t: float) -> void:
	var k := 0
	for fighter in ORDER:
		var body: Node3D = _bodies[fighter]
		body.position = MEET[fighter]
		body.rotation.y = _facing(-MEET[fighter])
		var at := T_RUN + 0.35 + 0.55 * k
		var nod := sin(clampf((t - at) / 0.55, 0.0, 1.0) * PI) * 0.45
		body._apply(_stand_pose(nod))
		k += 1
	var u := (t - T_RUN) / (T_NOD - T_RUN)
	_cam(Vector3(lerpf(2.6, -1.2, u), 1.9, lerpf(-4.6, -4.2, u)), Vector3(0, 1.35, 0), 40.0)


## All of them turn and look the same way: down the graveyard, at the crypt.
func _turn(t: float) -> void:
	var u := _ease((t - T_NOD - 0.15) / 0.55)
	for fighter in ORDER:
		var body: Node3D = _bodies[fighter]
		body.position = MEET[fighter]
		var from := _facing(-MEET[fighter])
		body.rotation.y = lerp_angle(from, PI, u)
		body._apply(_stand_pose())
	_cam(Vector3(0, 2.0, -6.0 + 0.6 * (t - T_NOD)), Vector3(0, 2.0, 9.0), 38.0)


## The Coffin King: slow, low, and big.
func _king_intro(t: float) -> void:
	var rig: BossRig = _king._rig
	rig.set_motion(Vector3.ZERO, _king.global_basis, true)
	rig.play("brace", 1.0, "right", 0.5, 0.5)
	rig.advance(1.0 / FPS)
	var local := t - T_TURN
	if absf(local) < 0.05 or absf(local - 1.7) < 0.05 or absf(local - 2.9) < 0.05:
		_flash(Color(0.95, 0.4, 0.3), 0.3)
	var kz := _king.position.z
	if local < 1.8:
		var u := local / 1.8
		_cam(Vector3(0.0, lerpf(0.35, 0.9, u), kz - lerpf(3.6, 2.6, u)), _king.position + Vector3(0, lerpf(1.2, 2.2, u), 0), 56.0, -0.06)
	elif local < 3.0:
		var u := (local - 1.8) / 1.2
		_cam(Vector3(lerpf(1.6, 0.6, u), 2.0, kz - lerpf(3.4, 2.6, u)), _king.position + Vector3(0, 2.3, 0), 38.0, 0.05)
	else:
		var u := (local - 3.0) / 0.8
		_cam(Vector3(0.0, 2.2, kz - lerpf(3.0, 2.4, u)), _king.position + Vector3(0, 2.55, 0), 30.0)


## Each in his stance, in turn: the moment he lands it, his own aura lights.
func _stances(t: float) -> void:
	var which := 0
	for i in T_STANCE.size():
		if t >= T_STANCE[i]:
			which = i
	var fighter: String = ORDER[which]
	var at: float = T_STANCE[which]
	for i in ORDER.size():
		var f: String = ORDER[i]
		var body: Node3D = _bodies[f]
		body.visible = f == fighter
		body.position = MEET[f]
		if i <= which:
			# Already in the stance (the ones before him are lit behind the cut).
			if i < which or t >= at + 0.3:
				body.rotation.y = lerp_angle(PI, PI + 0.5 * (-1.0 if i % 2 == 0 else 1.0), 0.5)
				body._apply(_stance_of(f))
			else:
				body.rotation.y = PI
				body._apply(_stand_pose())
		else:
			body.rotation.y = PI
			body._apply(_stand_pose())
	if not _staged.has(fighter) and t >= at + 0.3:
		_staged[fighter] = true
		_bodies[fighter].rotation.y = PI + 0.5 * (-1.0 if which % 2 == 0 else 1.0) * 0.5
		_light_up(fighter, _stance_of(fighter))
		_flash(ENERGY[fighter], 0.3)
	# Only his own aura in his shot (the others are lit, just out of frame).
	for f in ORDER:
		for node in _auras.get(f, []):
			if is_instance_valid(node):
				node.visible = f == fighter
	var pos: Vector3 = MEET[fighter]
	var u := (t - at) / 1.1
	_cam(pos + Vector3(lerpf(0.9, 0.5, u), 1.25, lerpf(3.3, 2.7, u)), pos + Vector3(0, 1.05, 0), 32.0, 0.04 * (1.0 if which % 2 == 0 else -1.0))


## All four together, the title above, and a long hold.
func _group(t: float) -> void:
	if not _grouped:
		_grouped = true
		_flash(Color(1, 1, 1), 0.4)
		for f in ORDER:
			var spec: Dictionary = Banner.CAST[f]
			var body: Node3D = _bodies[f]
			body.position = spec.at * Vector3(-1.15, 1, 1)
			body.rotation.y = spec.turn
			body._apply(spec.pose)
			for key in ["lf", "rf"]:
				if body._joints.has(key) and spec.pose.has(key):
					(body._joints[key] as Node3D).rotation = spec.pose[key]
			_light_up(f, spec.pose)
		_king.visible = false
	_cam(Vector3(0.0, 1.45, -8.0 + minf(0.1 * (t - T_GROUP), 1.4)), Vector3(0.0, 1.62, 0.2), 33.0)
