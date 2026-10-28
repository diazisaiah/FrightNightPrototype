class_name Boss
extends Boxer
## The Grave Champion: a giant armored boxer and the last wave of every night.
## Throws long combos and slams. Below half HP it gets faster and raises zombies.

## Asks the world to raise this many zombies around the boss.
signal summon_requested(count: int)
signal health_changed(current: float, maximum: float)

const SCALE := 1.5
const ENRAGE_FRACTION := 0.5
const ENRAGED_WINDUP_SCALE := 0.8
const SUMMON_COUNT := 3
const COMBOS := [
	["jab", "cross"], ["jab", "cross", "left_hook"], ["jab", "jab", "right_hook", "uppercut"],
	["left_hook", "right_hook", "slam"], ["cross", "left_hook", "cross"], ["slam"],
	["jab", "cross", "left_hook", "right_hook"],
]
const ENRAGED_COMBOS := [
	["jab", "cross", "left_hook", "uppercut"], ["jab", "jab", "cross", "right_hook", "slam"],
	["left_hook", "right_hook", "left_hook", "uppercut"], ["slam", "jab", "cross"],
]

var _enraged := false


func _init() -> void:
	combo_armor = true  # Counters can't break a boss's combo, only punish its end.


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	# Too heavy to be knocked around much.
	var dealt := super(raw_damage, hit_point, push * 0.3, stagger, caption, pierce, crush)
	health_changed.emit(maxf(hp, 0.0), max_hp)
	if not _enraged and hp > 0.0 and hp <= max_hp * ENRAGE_FRACTION:
		_enrage()
	# A flinch away from the hit when it's not busy (staggers have their own).
	if _rig and not is_dead() and _stagger_timer <= 0.0 and _special == "" \
			and _state in [State.IDLE, State.RECOVER] and _rig.current_action() == "":
		var x := to_local(hit_point).x
		_rig.play("hit_left_light" if x < -0.25 else ("hit_right_light" if x > 0.25 else "hit_front_light"), 0.32)
	return dealt


func heal(amount: float) -> float:
	var restored := super(amount)
	health_changed.emit(hp, max_hp)
	return restored


func _enrage() -> void:
	_enraged = true
	windup_scale = ENRAGED_WINDUP_SCALE
	move_speed *= 1.2
	DamagePopup.spawn(get_parent(), "ENRAGED", Color(0.8, 0.3, 1.0), 64, global_position + Vector3(0, 3.2, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.4, 4.0, 0.6)
	summon_requested.emit(SUMMON_COUNT)


func _pick_combo() -> Array:
	return (ENRAGED_COMBOS if _enraged else COMBOS).pick_random()


func _idle_time() -> float:
	return randf_range(0.4, 0.8) if _enraged else randf_range(0.7, 1.3)


func _update_label() -> void:
	pass  # The HUD shows the boss health bar instead.




# --- The rigged body ---------------------------------------------------------------

## The body on a BossRig (the Character Lab's skeleton and clips), with the
## AI's moves played on it: footwork into the walk cycle, every punch a
## load pose held through the windup, then the punch clip started so it
## lands on the strike (PUNCH_LEAD before it, peaking at PUNCH_PEAK), slips,
## flinches, staggers, and each special's steps.
const PUNCH_LEAD := {"jab": 0.15, "cross": 0.17, "hook": 0.26, "uppercut": 0.3, "slam": 0.22, "sweep": 0.3}
const PUNCH_PEAK := {"jab": 0.5, "cross": 0.5, "hook": 0.54, "uppercut": 0.57, "slam": 0.5, "sweep": 0.5}
const EVADE_SLIP := 0.55

var _rig: BossRig
var _rig_state := -1
var _rig_attack := ""
var _rig_punched := false


## Stands the body on a rig of this shape. The AI keeps bare arm pivots for
## its timing; its forearms are the rig's hands, so the tell lights, glove
## glow and gear gloves ride on the fists.
func _rig_body(shape: Dictionary, glove_color: Color) -> BossRig:
	_rig = BossRig.new()
	_rig.name = "Rig"
	_body.add_child(_rig)
	_rig.build(shape)
	for arm in ["left", "right"]:
		var s := "_l" if arm == "left" else "_r"
		var shoulder := _rig.rest_origin("upper_arm" + s)
		_arms[arm] = _pivot(_body, shoulder)
		_arm_rest[arm] = shoulder
		_forearms[arm] = _rig.bone("hand" + s)
		var glove := _material(glove_color)
		glove.emission_enabled = true
		glove.emission_energy_multiplier = 0.0
		_gloves[arm] = glove
		var light := OmniLight3D.new()
		light.omni_range = 1.5
		light.light_energy = 0.0
		light.visible = false
		light.position = Vector3(0, -0.14, 0)
		_forearms[arm].add_child(light)
		_tell_lights[arm] = light
	return _rig


## A part on a rig bone, placed where it sits on the standing body.
func _on(bone_name: String, mesh: PrimitiveMesh, material: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _rig.put(self, bone_name, mesh, material, at, rot)


## A part in a bone's own space (arms: they hang along -Y from the joint).
func _at(bone_name: String, mesh: PrimitiveMesh, material: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _part(_rig.bone(bone_name), mesh, material, at, rot)


func _physics_process(delta: float) -> void:
	super(delta)
	# Down: the rig goes limp while the body crumples or flies.
	if _rig and _dead:
		_rig.advance(delta)


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	if _rig == null:
		return
	# The rig does its own hops, leans and sways (the recoil stays).
	_body.position.x = 0.0
	_body.position.y = 0.0
	_body.rotation = Vector3.ZERO
	_drive_rig()
	_rig.advance(delta)


func _drive_rig() -> void:
	# Posed without physics (the title screen): standing, not falling.
	_rig.set_motion(velocity, global_basis, is_on_floor() or not is_physics_processing())
	if _special != "":
		_rig_state = -1
		return
	if _state == State.WINDUP and (_rig_state != State.WINDUP or _rig_attack != _attack):
		_rig_punched = false
		var clip := _rig_clip(_attack)
		if not clip.is_empty():
			_rig.play(clip.load, maxf(_state_timer - clip.lead, 0.05), clip.hand)
	elif _state == State.EVADE and _rig_state != State.EVADE:
		_rig.play("slip_right" if _evade_side > 0.0 else "slip_left", EVADE_SLIP)
	if _state in [State.WINDUP, State.STRIKE] and not _rig_punched:
		var clip := _rig_clip(_attack)
		if clip.is_empty():
			_rig_punched = true
		elif _state == State.STRIKE or _state_timer <= clip.lead:
			_rig_punched = true
			var early: float = _state_timer if _state == State.WINDUP else 0.0
			_rig.play(clip.action, clip.lead / clip.peak, clip.hand, clip.peak, clip.lead - early)
	_rig_state = _state
	_rig_attack = _attack


## The rig clip for an attack: {action, hand, load (the windup pose), lead,
## peak}, or {} if it has none.
func _rig_clip(attack: String) -> Dictionary:
	var kind := attack
	var hand := "left"
	match attack:
		"cross":
			hand = "right"
		"left_hook":
			kind = "hook"
		"right_hook":
			kind = "hook"
			hand = "right"
		"uppercut", "sweep":
			hand = _power_arm
		"haymaker", "claw":
			kind = "hook"
			hand = _power_arm
		"slam":
			hand = ""
	if not PUNCH_LEAD.has(kind):
		return {}
	var load := "slam_load" if kind == "slam" else "sweep_load" if kind == "sweep" else "load"
	return {"action": kind, "hand": hand, "load": load, "lead": minf(PUNCH_LEAD[kind], _windup_total * 0.8), "peak": PUNCH_PEAK[kind]}


func _on_staggered() -> void:
	super()
	if _rig:
		_rig.play("dazed" if _stagger_timer >= 0.9 else "hit_front_heavy", maxf(_stagger_timer, 0.6))


func _set_step(step: String) -> void:
	super(step)
	if _rig == null:
		return
	match step:
		"crouch":
			_rig.play("jump_start", CROUCH_TIME)
		"air":
			_rig.stop()
		"recover":
			if _special in ["leap_slam", "ground_slam"]:
				_rig.play("land", 0.5)
			else:
				_rig.stop()
		"raise":
			_rig.play("slam", GROUND_SLAM_WINDUP + 0.3, "", GROUND_SLAM_WINDUP / (GROUND_SLAM_WINDUP + 0.3))
		"aim":
			# Held through the dash.
			_rig.play("brace", CHARGE_WINDUP + 1.8)
		"dazed":
			_rig.play("dazed", DAZED_TIME)
		"cast":
			_rig.play("cast", 0.8)
		"howl":
			_rig.play("cast", SCREAM_WINDUP + 0.3)


func _end_special() -> void:
	super()
	if _rig:
		_rig.stop()


func _die(push: Vector3) -> void:
	super(push)
	if _rig and _dead:
		_rig.play("limp", 60.0)


# --- The Grave Champion -----------------------------------------------------------

const CHAMPION := {
	"foot": Vector3(0.22, 0.1, 0.32), "lower_leg": 0.4, "upper_leg": 0.4, "hip": 0.34,
	"torso_h": 0.72, "shoulder": 0.78, "upper_arm": 0.32, "forearm": 0.3,
	"head": Vector3(0.32, 0.3, 0.3), "guard": 0.85, "style": "heavy",
}


## A giant undead prizefighter: grey-violet hide stitched across the chest,
## bone horns and burning purple eyes, fangs, dark purple trunks under a
## gold champion's belt, wrapped ankles and purple gloves.
func _build_body() -> void:
	_body.scale = Vector3.ONE * SCALE
	var skin := _material(Color(0.36, 0.33, 0.4))
	var skin_light := _material(Color(0.45, 0.42, 0.5))
	var skin_dark := _material(Color(0.24, 0.22, 0.28))
	var cloth := _material(Color(0.2, 0.08, 0.26))
	var trim := _material(Color(0.82, 0.8, 0.74))
	var bone := _material(Color(0.86, 0.82, 0.7))
	var gold := _material(Color(0.88, 0.66, 0.22), 0.75)
	var dark := _material(Color(0.05, 0.03, 0.06))
	var stitch := _material(Color(0.12, 0.1, 0.12))
	var eyes := _glow_material(Color(0.75, 0.3, 1.0))
	_rig_body(CHAMPION, Color(0.3, 0.06, 0.36))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.17 * side
		_on("foot" + s, _box(Vector3(0.22, 0.1, 0.32)), skin_dark, Vector3(x, 0.05, -0.04))
		_on("foot" + s, _box(Vector3(0.18, 0.09, 0.18)), trim, Vector3(x, 0.15, 0))
		_on("shin" + s, _box(Vector3(0.18, 0.32, 0.2)), skin, Vector3(x, 0.32, 0))
		_on("shin" + s, _box(Vector3(0.2, 0.1, 0.21)), skin_light, Vector3(x, 0.5, -0.01))
		_on("thigh" + s, _box(Vector3(0.26, 0.32, 0.28)), cloth, Vector3(x, 0.72, 0))
		_on("thigh" + s, _box(Vector3(0.27, 0.04, 0.29)), trim, Vector3(x, 0.58, 0))
	_on("pelvis", _box(Vector3(0.56, 0.2, 0.34)), cloth, Vector3(0, 0.86, 0))
	# The champion's belt: a gold plate with a purple stone, side plates.
	_on("pelvis", _box(Vector3(0.6, 0.12, 0.37)), dark, Vector3(0, 0.96, 0))
	_on("pelvis", _box(Vector3(0.24, 0.17, 0.04)), gold, Vector3(0, 0.96, -0.2))
	_on("pelvis", _box(Vector3(0.06, 0.06, 0.02)), eyes, Vector3(0, 0.96, -0.225))
	for side: float in [-1.0, 1.0]:
		_on("pelvis", _box(Vector3(0.09, 0.09, 0.03)), gold, Vector3(0.21 * side, 0.96, -0.18))
	# Abs and a heavy chest, stitched up the middle and across.
	_on("spine", _box(Vector3(0.5, 0.3, 0.3)), skin, Vector3(0, 1.12, 0))
	for row in 3:
		for side: float in [-1.0, 1.0]:
			_on("spine", _box(Vector3(0.11, 0.06, 0.02)), skin_light, Vector3(0.065 * side, 1.04 + row * 0.08, -0.155))
	_on("chest", _box(Vector3(0.7, 0.34, 0.38)), skin, Vector3(0, 1.44, 0))
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.3, 0.16, 0.08)), skin_light, Vector3(0.16 * side, 1.44, -0.18), Vector3(0, -0.1 * side, 0))
	_on("chest", _box(Vector3(0.02, 0.3, 0.012)), stitch, Vector3(-0.06, 1.42, -0.226), Vector3(0, 0, 0.5))
	for k in 4:
		_on("chest", _box(Vector3(0.06, 0.012, 0.012)), stitch, Vector3(-0.12 + k * 0.04, 1.35 + k * 0.05, -0.228), Vector3(0, 0, 0.5))
	_on("chest", _box(Vector3(0.44, 0.12, 0.26)), skin_dark, Vector3(0, 1.62, 0.04))
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_on("clavicle" + s, _box(Vector3(0.26, 0.22, 0.28)), skin, Vector3(0.4 * side, 1.43, 0))
		_on("clavicle" + s, _box(Vector3(0.05, 0.16, 0.05)), bone, Vector3(0.44 * side, 1.58, 0.02), Vector3(0, 0, -0.5 * side))
	# The head: horns, a heavy brow over burning eyes, fangs.
	_on("neck", _box(Vector3(0.22, 0.12, 0.22)), skin_dark, Vector3(0, 1.66, 0))
	_on("head", _box(Vector3(0.32, 0.28, 0.3)), skin, Vector3(0, 1.82, -0.02))
	_on("head", _box(Vector3(0.34, 0.06, 0.08)), skin_dark, Vector3(0, 1.88, -0.15))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.09, 0.05, 0.02)), dark, Vector3(0.075 * side, 1.83, -0.17))
		_on("head", _box(Vector3(0.06, 0.03, 0.02)), eyes, Vector3(0.075 * side, 1.83, -0.178))
		_on("head", _box(Vector3(0.07, 0.12, 0.07)), bone, Vector3(0.13 * side, 1.98, 0), Vector3(0, 0, -0.45 * side))
		_on("head", _box(Vector3(0.05, 0.12, 0.05)), bone, Vector3(0.19 * side, 2.07, 0.02), Vector3(0, 0, -0.85 * side))
		_on("head", _box(Vector3(0.03, 0.05, 0.02)), bone, Vector3(0.07 * side, 1.73, -0.165))
	_on("head", _box(Vector3(0.28, 0.1, 0.26)), skin_dark, Vector3(0, 1.69, -0.03))
	_on("head", _box(Vector3(0.12, 0.012, 0.012)), stitch, Vector3(0.05, 1.93, -0.18), Vector3(0, 0, -0.3))
	for arm in ["left", "right"]:
		var side := -1.0 if arm == "left" else 1.0
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _box(Vector3(0.17, 0.28, 0.17)), skin, Vector3(0, -0.15, 0))
		_at("upper_arm" + s, _box(Vector3(0.12, 0.12, 0.08)), skin_light, Vector3(0.01 * side, -0.14, -0.08))
		_at("forearm" + s, _box(Vector3(0.13, 0.1, 0.13)), skin_dark, Vector3(0, 0.0, 0))
		_at("forearm" + s, _box(Vector3(0.15, 0.24, 0.15)), skin, Vector3(0, -0.14, 0))
		_at("forearm" + s, _box(Vector3(0.16, 0.07, 0.16)), trim, Vector3(0, -0.26, 0))
		_fist(arm, Vector3(0.22, 0.22, 0.22), trim)


## A glove on a rig hand, in the AI's glove material (it lights up with the
## tells): a cuff, the mitt, knuckle rolls and the thumb, and laces if given.
func _fist(arm: String, size: Vector3, laces: Material = null) -> void:
	var side := -1.0 if arm == "left" else 1.0
	var hand := "hand_l" if arm == "left" else "hand_r"
	var glove: StandardMaterial3D = _gloves[arm]
	_at(hand, _box(Vector3(size.x * 0.9, size.y * 0.3, size.z * 0.9)), glove, Vector3(0, -size.y * 0.1, 0))
	_at(hand, _box(size), glove, Vector3(0, -size.y * 0.55, 0))
	for k in 4:
		_at(hand, _box(Vector3(size.x * 0.22, size.y * 0.2, size.z * 0.25)), glove, Vector3((k - 1.5) * size.x * 0.24, -size.y * 1.05, -size.z * 0.22))
	_at(hand, _box(Vector3(size.x * 0.3, size.y * 0.5, size.z * 0.3)), glove, Vector3(-side * size.x * 0.55, -size.y * 0.42, -size.z * 0.25))
	if laces:
		_at(hand, _box(Vector3(size.x * 0.12, size.y * 0.35, 0.012)), laces, Vector3(0, -size.y * 0.15, size.z * 0.46))


## Bosses wear no armor: armored or geared, they get the stats but nothing
## shows over their bodies (the Colossus and contenders too).
func _build_armor() -> void:
	pass


func _gear_style() -> String:
	return "bare"


# --- Building blocks ---------------------------------------------------------------

## Gold (or iron) links from a to b, every other link turned a quarter.
func _chain(parent: Node3D, a: Vector3, b: Vector3, links: int, material: Material) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var basis := Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.95 else Vector3.FORWARD)
	for i in links:
		var link := _part(parent, _box(Vector3(0.05, 0.03, length / links * 1.15)), material, a.lerp(b, (i + 0.5) / links))
		link.basis = basis * Basis(Vector3.FORWARD, PI / 2.0 if i % 2 == 1 else 0.0)


## A chain between two points on the standing body, on a bone.
func _chain_on(bone_name: String, a: Vector3, b: Vector3, links: int, material: Material) -> void:
	var origin := _rig.rest_origin(bone_name)
	_chain(_rig.bone(bone_name), a - origin, b - origin, links, material)


## A ragged skirt or hem on a bone: strips of cloth hanging from top (on the
## standing body) around it. On "legs", each side's strips ride that thigh
## (they swing with the stride) and the front and back ones the hips.
func _tatters(bone_name: String, top: float, radius_x: float, radius_z: float, materials: Array, count: int, lengths: Vector2, seed_value := 404) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var angle := TAU * i / count
		var length := rng.randf_range(lengths.x, lengths.y)
		var width := TAU * maxf(radius_x, radius_z) / count * 1.15
		var at := Vector3(cos(angle) * radius_x, top - length / 2.0, sin(angle) * radius_z)
		var on := bone_name
		if bone_name == "legs":
			on = "pelvis" if absf(at.x) < radius_x * 0.3 else ("thigh_l" if at.x < 0.0 else "thigh_r")
		_on(on, _box(Vector3(width, length, 0.04)), materials[i % materials.size()], at, Vector3(rng.randf_range(-0.08, 0.08), -angle + PI / 2.0, 0))


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	return mesh


static func _cylinder_tapered(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := _cylinder(top, height)
	mesh.bottom_radius = bottom
	mesh.radial_segments = 10
	return mesh
