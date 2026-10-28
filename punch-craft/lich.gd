class_name Lich
extends Enemy
## Bone Lich (Crypt): a robed skeleton caster. Keeps its distance, raises its
## staff and throws a fan of purple bolts (slip them, or step out of the
## fan), and every so often raises skeletons. The Lich King is the floor 3
## boss version: bigger, wider fans, blinks away when crowded, raises
## Shieldbearers too, and gets faster below half HP.

signal summon_requested(kinds: Array)
signal health_changed(current: float, maximum: float)

const BOLT_SPEED := 12.0
const BOLT_SPREAD := 0.22
const KING_SCALE := 1.6
## The King blinks away if the player stays this close this long.
const CROWD_DISTANCE := 3.2
const CROWD_TIME := 1.2
const BLINK_COOLDOWN := 7.0

@export var is_king := false
@export var bolt_damage := 8.0
@export var bolts := 3
@export var min_range := 6.0
@export var max_range := 13.0
@export var cast_time := 1.1
@export var cast_cooldown := 2.8
@export var summon_interval := 10.0

var _cooldown := 1.5
var _casting := false
var _cast_timer := 0.0
var _flashed := false
var _summon_timer := 6.0
var _crowded := 0.0
var _blink_cooldown := 0.0
var _enraged := false
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _staff_arm: Node3D
var _orb: StandardMaterial3D
## The King's rigged body (BossRig).
var _rig: BossRig



func _init() -> void:
	takes_turns = false  # Fights from range: never waits for a turn.

func _ready() -> void:
	super()
	if is_king:
		_hp_label.position.y = 3.4


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	var dealt := super(raw_damage, hit_point, push * (0.4 if is_king else 1.0), stagger, caption, pierce, crush)
	if is_king:
		health_changed.emit(maxf(hp, 0.0), max_hp)
		if not _enraged and hp > 0.0 and hp <= max_hp * 0.5:
			_enraged = true
			cast_time *= 0.75
			cast_cooldown *= 0.7
			bolts += 2
			DamagePopup.spawn(get_parent(), "ENRAGED", Color(0.8, 0.3, 1.0), 64, global_position + Vector3(0, 3.4, 0))
			summon_requested.emit(["shieldbearer", "skeleton", "skeleton"])
		if _rig and not is_dead() and not _casting and _rig.current_action() == "":
			var x := to_local(hit_point).x
			_rig.play("hit_left_light" if x < -0.25 else ("hit_right_light" if x > 0.25 else "hit_front_light"), 0.32)
	return dealt


func heal(amount: float) -> float:
	var restored := super(amount)
	if is_king:
		health_changed.emit(hp, max_hp)
	return restored


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	var direction := offset.normalized()
	_turn_toward(offset, delta)
	_cooldown -= delta
	_summon_timer -= delta
	_blink_cooldown -= delta
	if _summon_timer <= 0.0:
		_summon_timer = summon_interval
		summon_requested.emit(["shieldbearer", "skeleton"] if is_king else ["skeleton", "skeleton"])
		Sfx.play_at("growl", global_position + Vector3.UP * 2.0, 0.0, 0.5)
	if is_king:
		_crowded = _crowded + delta if distance < CROWD_DISTANCE else 0.0
		if _crowded >= CROWD_TIME and _blink_cooldown <= 0.0 and not _casting:
			_blink()
			return Vector3.ZERO
	if _casting:
		_cast_timer -= delta
		if not _flashed and _cast_timer <= tell_time():
			_flashed = true
			_flash_tell(Boxer.SLIP_COLOR, 1.8)
		if _cast_timer <= 0.0:
			_cast()
		return Vector3.ZERO
	if _cooldown <= 0.0 and distance <= max_range + 4.0:
		_casting = true
		_flashed = false
		_cast_timer = cast_time
		Sfx.play_at("zap", global_position + Vector3.UP * 2.0, -6.0, 0.6)
		return Vector3.ZERO
	if distance > max_range:
		return direction * move_speed
	if distance < min_range:
		return -direction * move_speed * 0.8
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.5)
		_strafe_sign = [-1.0, 1.0].pick_random()
	return direction.cross(Vector3.UP) * _strafe_sign * move_speed * 0.5


func _on_staggered() -> void:
	_casting = false
	_cooldown = maxf(_cooldown, 0.8)


## A fan of bolts aimed at the player; the middle one dead on.
func _cast() -> void:
	_on_attacking()
	if _dead:
		return
	_casting = false
	_cooldown = cast_cooldown
	var from := _body.to_global(Vector3(0.0, 1.9, -0.5))
	var target := player.global_position + Vector3(0, 1.3, 0)
	var aim := target - from
	for i in bolts:
		var angle := (i - (bolts - 1) / 2.0) * BOLT_SPREAD
		var bolt := Fireball.new()
		bolt.shooter = self
		bolt.color = Fireball.BOLT_COLOR
		get_parent().add_child(bolt)
		bolt.launch(from, from + aim.rotated(Vector3.UP, angle), BOLT_SPEED, bolt_damage * damage_multiplier)
	Sfx.play_at("zap", from, 0.0, 0.8)


## Vanishes in a burst and reappears across the room.
func _blink() -> void:
	_blink_cooldown = BLINK_COOLDOWN
	_crowded = 0.0
	HitFx.burst(get_parent(), global_position + Vector3(0, 1.5, 0), Vector3.UP, Fireball.BOLT_COLOR, 30, 5.0, true, 0.08)
	Sfx.play_at("zap", global_position, 2.0, 0.5)
	var away := global_position - player.global_position
	away.y = 0.0
	var spot := player.global_position + away.normalized() * (arena_limit * 0.9)
	var offset := spot - arena_center
	offset.y = 0.0
	if offset.length() > arena_limit:
		spot = arena_center + offset.normalized() * arena_limit
	global_position = Vector3(spot.x, global_position.y, spot.z)
	HitFx.burst(get_parent(), global_position + Vector3(0, 1.5, 0), Vector3.UP, Fireball.BOLT_COLOR, 30, 5.0, true, 0.08)


func _animate(delta: float, _speed: float) -> void:
	var charge := 1.0 - clampf(_cast_timer / cast_time, 0.0, 1.0) if _casting else 0.0
	_orb.emission_energy_multiplier = 12.0 if _casting and _flashed else lerpf(1.5, 6.0, charge)
	_body.position.y = 0.08 * sin(Time.get_ticks_msec() * 0.002)
	if _rig:
		# The King's rig: the staff goes up for the cast and holds there.
		_rig.set_motion(velocity, global_basis, true)
		if _casting and _rig.current_action() != "staff":
			_rig.play("staff", cast_time + 1.0)
		elif not _casting and _rig.current_action() == "staff":
			_rig.play("cast", 0.4)
		_rig.advance(delta)
		return
	var blend := minf(1.0, 10.0 * delta)
	_staff_arm.rotation.x = lerpf(_staff_arm.rotation.x, 2.4 if _casting else 0.5, blend)


func _build_body() -> void:
	_body.scale = Vector3.ONE * (KING_SCALE if is_king else 1.0)
	if is_king:
		_build_king()
		return
	var robe := _material(Color(0.12, 0.08, 0.16))
	var bone := _material(Color(0.82, 0.8, 0.72))
	var gold := _material(Color(0.8, 0.62, 0.2), 0.7)
	var eyes := _glow_material(Fireball.BOLT_COLOR)
	_part(_body, _box(Vector3(0.55, 1.0, 0.45)), robe, Vector3(0, 0.5, 0))
	_part(_body, _box(Vector3(0.46, 0.6, 0.32)), robe, Vector3(0, 1.28, 0))
	_part(_body, _box(Vector3(0.28, 0.3, 0.3)), bone, Vector3(0, 1.75, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.05, 0.02)), eyes, Vector3(0.07 * side, 1.77, -0.155))
	if is_king:
		# A crown of bone spikes.
		for i in 5:
			var x := -0.12 + i * 0.06
			_part(_body, _box(Vector3(0.04, 0.16 + 0.06 * (2 - absi(i - 2)), 0.04)), gold, Vector3(x, 1.98, -0.1))
	# The free arm, and the staff arm with a glowing orb.
	var free_arm := _pivot(_body, Vector3(-0.28, 1.5, 0))
	_part(free_arm, _cylinder(0.04, 0.55), bone, Vector3(0, -0.27, 0))
	free_arm.rotation.x = 0.4
	_staff_arm = _pivot(_body, Vector3(0.28, 1.5, 0))
	_part(_staff_arm, _cylinder(0.04, 0.55), bone, Vector3(0, -0.27, 0))
	_part(_staff_arm, _cylinder(0.03, 1.6), _material(Color(0.2, 0.15, 0.1)), Vector3(0, -0.55, -0.1), Vector3(PI / 2, 0, 0))
	_orb = _glow_material(Fireball.BOLT_COLOR)
	_orb.emission_energy_multiplier = 1.5
	_part(_staff_arm, _box(Vector3(0.16, 0.16, 0.16)), _orb, Vector3(0, -0.55, -0.92), Vector3(0.6, 0.6, 0))


const KING := {
	"foot": Vector3(0.1, 0.06, 0.18), "lower_leg": 0.36, "upper_leg": 0.36, "hip": 0.28,
	"torso_h": 0.66, "shoulder": 0.58, "upper_arm": 0.3, "forearm": 0.28,
	"head": Vector3(0.28, 0.3, 0.28), "style": "caster",
}


## The Lich King on a rig: a robed skeleton in deep violet with gold trim, a
## high collar and a long cape, ribs showing through a torn front, a violet
## amulet, a crowned skull with burning eyes, bony hands in wide sleeves, and
## a tall staff topped with the glowing orb, held up for every cast.
func _build_king() -> void:
	var robe := _material(Color(0.14, 0.09, 0.19))
	var robe_dark := _material(Color(0.07, 0.04, 0.1))
	var bone := _material(Color(0.84, 0.82, 0.74))
	var gold := _material(Color(0.82, 0.64, 0.22), 0.7)
	var wood := _material(Color(0.22, 0.16, 0.11))
	var dark := _material(Color(0.04, 0.03, 0.05))
	var eyes := _glow_material(Fireball.BOLT_COLOR)
	_rig = BossRig.new()
	_rig.name = "Rig"
	_body.add_child(_rig)
	_rig.build(KING)

	# The robe falls to the floor: a panel on each leg (it parts as he
	# walks), the hem in tatters, bone feet under it.
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_on("foot" + s, _box(Vector3(0.1, 0.05, 0.18)), bone, Vector3(0.14 * side, 0.03, -0.06))
		_on("thigh" + s, _box(Vector3(0.28, 0.66, 0.4)), robe, Vector3(0.12 * side, 0.46, 0))
		_on("thigh" + s, _box(Vector3(0.29, 0.05, 0.41)), gold, Vector3(0.12 * side, 0.15, 0))
		for k in 3:
			_on("thigh" + s, _box(Vector3(0.09, 0.14, 0.04)), robe_dark, Vector3((0.04 + k * 0.08) * side, 0.08, -0.2 + k * 0.01))
	_on("pelvis", _box(Vector3(0.5, 0.26, 0.4)), robe, Vector3(0, 0.78, 0))
	_on("pelvis", _box(Vector3(0.52, 0.07, 0.42)), gold, Vector3(0, 0.88, 0))
	_on("sash", _box(Vector3(0.14, 0.56, 0.03)), robe_dark, Vector3(0, 0.56, -0.22))
	_on("sash", _box(Vector3(0.15, 0.04, 0.035)), gold, Vector3(0, 0.3, -0.22))
	# The chest: robe torn open over the ribs, a violet amulet, the collar.
	_on("spine", _box(Vector3(0.44, 0.3, 0.32)), robe, Vector3(0, 1.04, 0))
	_on("chest", _box(Vector3(0.48, 0.34, 0.32)), robe, Vector3(0, 1.32, 0))
	_on("chest", _box(Vector3(0.2, 0.26, 0.03)), dark, Vector3(0, 1.3, -0.16))
	for i in 4:
		_on("chest", _box(Vector3(0.18 - i * 0.015, 0.03, 0.03)), bone, Vector3(0, 1.21 + i * 0.065, -0.17))
	_on("chest", _box(Vector3(0.04, 0.24, 0.03)), bone, Vector3(0, 1.3, -0.175))
	_on("chest", _box(Vector3(0.08, 0.08, 0.03)), gold, Vector3(0, 1.45, -0.18))
	_on("chest", _box(Vector3(0.05, 0.05, 0.02)), eyes, Vector3(0, 1.45, -0.195))
	_on("chest", _box(Vector3(0.56, 0.2, 0.12)), robe_dark, Vector3(0, 1.58, 0.14))
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.1, 0.22, 0.3)), robe_dark, Vector3(0.24 * side, 1.56, 0.02), Vector3(0, 0, -0.2 * side))
		_on("chest", _box(Vector3(0.105, 0.03, 0.31)), gold, Vector3(0.25 * side, 1.66, 0.02), Vector3(0, 0, -0.2 * side))
		var s := "_l" if side < 0.0 else "_r"
		_on("clavicle" + s, _box(Vector3(0.2, 0.12, 0.3)), robe_dark, Vector3(0.3 * side, 1.3, 0))
		for k in 2:
			_on("clavicle" + s, _box(Vector3(0.04, 0.12, 0.04)), bone, Vector3((0.28 + k * 0.08) * side, 1.41, 0.02), Vector3(0, 0, -0.4 * side))
	# The long cape.
	_on("cape", _box(Vector3(0.62, 1.2, 0.05)), robe_dark, Vector3(0, 0.86, 0.2))
	_on("cape", _box(Vector3(0.63, 0.05, 0.055)), gold, Vector3(0, 0.28, 0.2))
	# The crowned skull.
	_on("neck", _box(Vector3(0.08, 0.1, 0.08)), bone, Vector3(0, 1.52, 0))
	_on("head", _box(Vector3(0.26, 0.22, 0.26)), bone, Vector3(0, 1.68, -0.02))
	_on("head", _box(Vector3(0.28, 0.05, 0.08)), bone, Vector3(0, 1.71, -0.13))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.08, 0.06, 0.02)), dark, Vector3(0.065 * side, 1.66, -0.15))
		_on("head", _box(Vector3(0.05, 0.035, 0.02)), eyes, Vector3(0.065 * side, 1.66, -0.158))
	_on("head", _box(Vector3(0.22, 0.07, 0.22)), bone, Vector3(0, 1.55, -0.03))
	_on("head", _box(Vector3(0.16, 0.02, 0.02)), dark, Vector3(0, 1.575, -0.145))
	_on("head", _box(Vector3(0.28, 0.05, 0.28)), gold, Vector3(0, 1.8, -0.02))
	for i in 5:
		var x := -0.11 + i * 0.055
		_on("head", _box(Vector3(0.035, 0.12 + 0.05 * (2 - absi(i - 2)), 0.035)), gold, Vector3(x, 1.88 + 0.02 * (2 - absi(i - 2)), -0.14))
	# Arms in wide sleeves, bony hands; the staff in the right.
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_part(_rig.bone("upper_arm" + s), _box(Vector3(0.15, 0.28, 0.15)), robe, Vector3(0, -0.15, 0))
		_part(_rig.bone("forearm" + s), _box(Vector3(0.2, 0.18, 0.2)), robe, Vector3(0, -0.1, 0))
		_part(_rig.bone("forearm" + s), _box(Vector3(0.21, 0.04, 0.21)), gold, Vector3(0, -0.19, 0))
		_part(_rig.bone("forearm" + s), _box(Vector3(0.05, 0.12, 0.05)), bone, Vector3(0, -0.24, 0))
		_part(_rig.bone("hand" + s), _box(Vector3(0.09, 0.08, 0.06)), bone, Vector3(0, -0.05, 0))
		for k in 3:
			_part(_rig.bone("hand" + s), _box(Vector3(0.02, 0.07, 0.02)), bone, Vector3((k - 1) * 0.03, -0.12, -0.01))
	var hand := _rig.bone("hand_r")
	_part(hand, _cylinder(0.025, 1.7), wood, Vector3(0, -0.06, -0.3), Vector3(PI / 2, 0, 0))
	for k in 3:
		_part(hand, _box(Vector3(0.03, 0.03, 0.14)), bone, Vector3(cos(k * TAU / 3.0) * 0.08, -0.06 + sin(k * TAU / 3.0) * 0.08, -1.12), Vector3(0, 0, k * TAU / 3.0))
	_orb = _glow_material(Fireball.BOLT_COLOR)
	_orb.emission_energy_multiplier = 1.5
	_part(hand, _box(Vector3(0.16, 0.16, 0.16)), _orb, Vector3(0, -0.06, -1.24), Vector3(0.6, 0.6, 0))


## A part on a rig bone, placed where it sits on the standing body.
func _on(bone_name: String, mesh: PrimitiveMesh, material: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return _rig.put(self, bone_name, mesh, material, at, rot)


func _update_label() -> void:
	if not is_king:
		super()


func _build_armor() -> void:
	pass


## Casters wear their gear as tier-colored robes with trim.
func _gear_style() -> String:
	return "robe"
