class_name Goon
extends Node3D
## Tony's ghostly family: translucent green ghoul brawlers (the Ghoul
## Brawler's build: trunks, title belt, wrapped fists) in fedoras.
##   hold:  Cousin Vinnie (The Muscle) appears behind a monster, pins its arms
##          for a moment, then fades.
##   brawl: The Family (ultimate): walks up to the nearest monster and punches
##          it until its time's up, then fades.
## Light on the browser (2026-10-29: The Family lagged there): every goon
## shares its materials and meshes, has no light of its own in the browser,
## looks for a new target a few times a second rather than every frame, and
## its punches add no effects of their own beyond the hit's.
## Brawling goons keep SPACING apart and out of monsters (they used to pile
## into one spot, through each other and their target), and their hits show
## plain numbers. They fight like Ghoul Brawlers, only faster: the same
## combos (jabs, crosses, hooks, uppercuts), arm poses and torso twist, a
## punch every PUNCH_EVERY on average.

const COLOR := Color(0.45, 1.0, 0.6)
const SPEED := 5.5
const REACH := 1.4
## Seconds per punch, on average, rests between combos included.
const PUNCH_EVERY := 0.55
const WINDUP := 0.16
const STRIKE := 0.12
## Between punches in a combo.
const GAP := 0.04
## Elbows tucked, gloves up by the chin (the Boxer guard): [shoulder rotation,
## shoulder push, elbow rotation], y mirrored by side.
const GUARD := [Vector3(-0.9, 0.35, 0), 0.0, Vector3(2.4, 0, 0)]
## [windup pose, strike pose] per attack, as GUARD (Boxer._arm_pose).
const POSES := {
	"jab": [[Vector3(-0.6, 0.2, 0), 0.1, Vector3(2.0, 0, 0)], [Vector3(0.1, 0.12, 0), -0.3, Vector3.ZERO]],
	"cross": [[Vector3(-0.6, 0.2, 0), 0.16, Vector3(2.0, 0, 0)], [Vector3(0.1, 0.12, 0), -0.3, Vector3.ZERO]],
	"left_hook": [[Vector3(0.15, -1.2, 0), 0.05, Vector3(0, 1.6, 0)], [Vector3(0.15, 0.3, 0), -0.05, Vector3(0, 1.3, 0)]],
	"right_hook": [[Vector3(0.15, -1.2, 0), 0.05, Vector3(0, 1.6, 0)], [Vector3(0.15, 0.3, 0), -0.05, Vector3(0, 1.3, 0)]],
	"uppercut": [[Vector3(-1.2, 0.15, 0), 0.05, Vector3(1.0, 0, 0)], [Vector3(-0.2, 0.25, 0), -0.1, Vector3(1.6, 0, 0)]],
}
## Vinnie's arms, out and holding on.
const HOLD := [Vector3(0.0, 0.15, 0), -0.1, Vector3(0.3, 0, 0)]
## How close two brawling goons' centers get.
const SPACING := 0.9
## How wide a goon is, against a monster's body_radius().
const BODY := 0.35

var mode := "hold"
var target: Enemy
var life := 2.0
var damage := 2.0
## The combo being thrown, the punch in it, and its phase ("windup",
## "strike", or "" between punches).
var _combo: Array = []
var _combo_size := 0
var _attack := ""
var _phase := ""
var _phase_timer := 0.0
var _rest := 0.0
## Left then right: shoulder pivots and elbow pivots.
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _body: Node3D
var _torso: Node3D
var _time := 0.0
var _search := 0.0
## Built only to compile its look (FxWarmup): no sound, no burst, no moves.
var warm := false

## Shared by every goon: {"ghost", "suit", "eye"} materials, and box meshes
## by size and material.
static var _materials := {}
static var _meshes := {}


static func make(on: Enemy, hold: float) -> Goon:
	var goon := Goon.new()
	goon.mode = "hold"
	goon.target = on
	goon.life = hold
	var away := on.global_position - on.player.global_position if is_instance_valid(on.player) else Vector3.FORWARD
	away.y = 0.0
	goon.position = on.global_position + away.normalized() * 0.6
	return goon


static func brawler(at: Vector3, seconds: float, punch: float) -> Goon:
	var goon := Goon.new()
	goon.mode = "brawl"
	goon.life = seconds
	goon.damage = punch
	goon.position = at
	return goon


func _ready() -> void:
	_build()
	if warm:
		set_physics_process(false)
		return
	if mode == "brawl":
		add_to_group("goons")
	scale = Vector3.ONE * 0.05
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, COLOR, 18, 3.0, true, 0.05)
	Sfx.play_at("slip", global_position, 0.0, 0.7)


func _physics_process(delta: float) -> void:
	_time += delta
	life -= delta
	if life <= 0.0:
		_fade()
		return
	_body.position.y = sin(_time * 3.0) * 0.05
	_animate(delta)
	if mode == "hold":
		if is_instance_valid(target) and not target.is_dead():
			global_position = global_position.lerp(target.global_position + (global_position - target.global_position).normalized() * 0.6, minf(1.0, 10.0 * delta))
			look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
		return
	_brawl(delta)
	_keep_apart()


## Finds someone and hits them.
func _brawl(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead():
		target = null
		_search -= delta
		if _search > 0.0:
			return
		_search = 0.25
		target = _nearest()
		if target == null:
			return
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > 0.1:
		look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	# Reach counts from a big monster's edge.
	var reach := REACH + maxf(target.body_radius() - 0.4, 0.0)
	if _phase != "":
		_throw(delta, to, reach)
		return
	if to.length() > reach:
		global_position += to.normalized() * minf(SPEED * delta, to.length() - reach * 0.8)
		return
	_rest -= delta
	if _rest > 0.0:
		return
	if _combo.is_empty():
		_combo = (Brawler.COMBOS.pick_random() as Array).duplicate()
		_combo_size = _combo.size()
	_attack = _combo.pop_front()
	_phase = "windup"
	_phase_timer = WINDUP


## A punch in progress: wound up, then it lands as the strike starts.
func _throw(delta: float, to: Vector3, reach: float) -> void:
	_phase_timer -= delta
	if _phase_timer > 0.0:
		return
	if _phase == "windup":
		_phase = "strike"
		_phase_timer = STRIKE
		if to.length() <= reach + 0.4:
			target.take_hit(damage, target.global_position + Vector3(0, 1.3, 0), to.normalized() * 2.0, false)
		return
	_phase = ""
	_attack = ""
	# A breather after a combo, so its punches come every PUNCH_EVERY.
	_rest = GAP if not _combo.is_empty() else _combo_size * (PUNCH_EVERY - WINDUP - STRIKE) - (_combo_size - 1) * GAP


## Which arm throws it: 0 left, 1 right.
static func _arm_of(attack: String) -> int:
	return 0 if attack in ["jab", "left_hook"] else 1


## Arms and torso ease toward this moment's pose (Boxer._animate, lighter).
func _animate(delta: float) -> void:
	var striking := _phase == "strike"
	var blend := minf(1.0, (30.0 if striking else 12.0) * delta)
	for i in _arms.size():
		var side := -1.0 if i == 0 else 1.0
		var pose: Array = GUARD
		if mode == "hold":
			pose = HOLD
		elif _phase != "" and _arm_of(_attack) == i:
			pose = POSES[_attack][1 if striking else 0]
		var mirror := Vector3(1.0, side, 1.0)
		_arms[i].rotation = _arms[i].rotation.lerp(pose[0] * mirror, blend)
		_arms[i].position.z = lerpf(_arms[i].position.z, pose[1], blend)
		_elbows[i].rotation = _elbows[i].rotation.lerp(pose[2] * mirror, blend)
	var twist := Vector3.ZERO
	var dip := 0.0
	if _phase != "" and Boxer.TORSO_POSES.has(_attack):
		var torso: Array = Boxer.TORSO_POSES[_attack]
		var side := -1.0 if _arm_of(_attack) == 0 else 1.0
		twist = torso[2 if striking else 0] * Vector3(1.0, side, side)
		dip = torso[3 if striking else 1]
	_torso.rotation = _torso.rotation.lerp(twist, blend)
	_torso.position.y = lerpf(_torso.position.y, Boxer.TORSO_PIVOT + dip, blend)


## Steps out of any other brawling goon it's overlapping (each takes half),
## and all the way out of any monster.
func _keep_apart() -> void:
	for node in get_tree().get_nodes_in_group("goons"):
		if node == self:
			continue
		var away: Vector3 = global_position - (node as Node3D).global_position
		away.y = 0.0
		var distance := away.length()
		if distance >= SPACING:
			continue
		if distance < 0.01:
			away = Vector3.RIGHT.rotated(Vector3.UP, get_instance_id() % 628 / 100.0)
			distance = 0.0
		global_position += away.normalized() * (SPACING - distance) * 0.5
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var out := global_position - enemy.global_position
		out.y = 0.0
		var room := enemy.body_radius() + BODY
		if out.length_squared() >= room * room:
			continue
		var gap := out.length()
		if gap < 0.01:
			out = Vector3.RIGHT.rotated(Vector3.UP, get_instance_id() % 628 / 100.0)
			gap = 0.0
		global_position += out.normalized() * (room - gap)


func _nearest() -> Enemy:
	var best: Enemy
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var distance := enemy.global_position.distance_squared_to(global_position)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _fade() -> void:
	set_physics_process(false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.3)
	tween.tween_callback(queue_free)


func _build() -> void:
	if _materials.is_empty():
		var ghost_material := StandardMaterial3D.new()
		ghost_material.albedo_color = Color(COLOR, 0.45)
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.emission_enabled = true
		ghost_material.emission = COLOR
		ghost_material.emission_energy_multiplier = 0.8
		var suit_material := StandardMaterial3D.new()
		suit_material.albedo_color = Color(0.08, 0.2, 0.12, 0.6)
		suit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		suit_material.emission_enabled = true
		suit_material.emission = Color(0.1, 0.4, 0.2)
		var trim_material := ghost_material.duplicate() as StandardMaterial3D
		trim_material.albedo_color = Color(COLOR.lightened(0.4), 0.7)
		trim_material.emission_energy_multiplier = 1.6
		_materials = {"ghost": ghost_material, "suit": suit_material, "trim": trim_material, "eye": Enemy._glow_material(Color(0.8, 1.0, 0.8))}
	var ghost: Material = _materials.ghost
	var suit: Material = _materials.suit
	var trim: Material = _materials.trim
	_body = Node3D.new()
	add_child(_body)
	# The Ghoul Brawler's build: legs, trunks, title belt, torso, head.
	for side in [-1.0, 1.0]:
		_box(_body, Vector3(0.17, 0.55, 0.19), Vector3(0.13 * side, 0.28, 0), ghost)
		_box(_body, Vector3(0.19, 0.36, 0.21), Vector3(0.13 * side, 0.73, 0), suit)
	_box(_body, Vector3(0.5, 0.08, 0.3), Vector3(0, 0.93, 0), trim)
	# Above the hips rides a torso pivot, to twist into punches.
	_torso = Node3D.new()
	_torso.position.y = Boxer.TORSO_PIVOT
	_body.add_child(_torso)
	var up := Vector3(0, -Boxer.TORSO_PIVOT, 0)
	_box(_torso, Vector3(0.52, 0.55, 0.3), up + Vector3(0, 1.24, 0), ghost)
	_box(_torso, Vector3(0.28, 0.3, 0.28), up + Vector3(0, 1.72, 0), ghost)
	# The fedora.
	_box(_torso, Vector3(0.46, 0.04, 0.46), up + Vector3(0, 1.89, 0), suit)
	_box(_torso, Vector3(0.3, 0.16, 0.3), up + Vector3(0, 1.98, 0), suit)
	_box(_torso, Vector3(0.31, 0.04, 0.31), up + Vector3(0, 1.93, 0), trim)
	for side in [-1.0, 1.0]:
		var eye: Material = _materials.eye
		_box(_torso, Vector3(0.06, 0.04, 0.02), up + Vector3(0.07 * side, 1.76, -0.145), eye)
		# A boxer's arm (Boxer._build_arms): upper arm, elbow, forearm,
		# wrapped fist.
		var arm := Node3D.new()
		arm.position = up + Vector3(0.3 * side, 1.45, 0)
		_torso.add_child(arm)
		_box(arm, Vector3(0.11, 0.11, Boxer.UPPER_ARM_LENGTH), Vector3(0, 0, -Boxer.UPPER_ARM_LENGTH / 2.0), ghost)
		var elbow := Node3D.new()
		elbow.position.z = -Boxer.UPPER_ARM_LENGTH
		arm.add_child(elbow)
		_box(elbow, Vector3(0.1, 0.1, 0.2), Vector3(0, 0, -0.1), ghost)
		_box(elbow, Vector3(0.16, 0.16, 0.2), Vector3(0, 0, -0.24), trim)
		var guard: Array = GUARD
		arm.rotation = guard[0] * Vector3(1.0, side, 1.0)
		elbow.rotation = guard[2]
		_arms.append(arm)
		_elbows.append(elbow)
	if Settings.use_web_profile():
		return
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 1.4
	add_child(light)


func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var key := [size, material.get_instance_id()]
	if not _meshes.has(key):
		var box := BoxMesh.new()
		box.size = size
		box.material = material
		_meshes[key] = box
	var mesh: BoxMesh = _meshes[key]
	var part := MeshInstance3D.new()
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.mesh = mesh
	part.position = pos
	parent.add_child(part)
