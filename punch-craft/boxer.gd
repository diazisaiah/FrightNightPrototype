class_name Boxer
extends Enemy
## An enemy that fights like a boxer: throws jab / cross / hooks / uppercuts
## (plus two-handed slams, looping haymakers and weapon attacks) in combos.
## Every attack is telegraphed in three beats: the arm winds up into its pose,
## then once it's wound the glove (or weapon) flashes in the color of the
## defense that beats it (blue = slip, orange = roll, red = back step), then
## the swing lands Enemy.TELL_FLASH_TIME later. In a combo, the next attack's
## arm lights up dimmer in its color as soon as the current attack flashes, and
## stays lit through its own windup until it flashes too, so the whole combo
## can be read ahead. glow_tells turns the colors off.
## Subclasses build the body (calling _build_arms) and pick combos.
## Arms bend at the elbow, and everything above the hips sits on a torso pivot
## that coils during a windup (holding still, fully loaded, for the flash) and
## unwinds through the strike.

enum State { IDLE, WINDUP, STRIKE, RECOVER, EVADE }

const STRIKE_TIME := 0.15
## How long a boxer stays open at the end of a combo the player dodged.
const DODGED_OPEN_TIME := 1.0
const FOLLOW_UP_WINDUP := 0.4
const COUNTER_WINDUP := 0.35
## Glow strength of a combo's next attack, shown ahead of time (the flash is brighter).
const PREVIEW_GLOW := 0.55
const FLASH_GLOW := 1.7
const TOO_CLOSE_DISTANCE := 1.2
const FIRST_WINDUP := {
	"slam": 0.8, "jab": 0.55, "cross": 0.6, "left_hook": 0.65, "right_hook": 0.65, "uppercut": 0.7,
	"haymaker": 0.75, "staff": 0.85, "thrust": 0.8, "slash": 0.9,
	"bash": 0.75, "claw": 0.75, "sweep": 1.0,
}
const SLIP_COLOR := Color(0.3, 0.6, 1.0)
const ROLL_COLOR := Color(1.0, 0.55, 0.1)
const BACK_STEP_COLOR := Color(1.0, 0.15, 0.1)
## Colors per attack. The "hint" text is the old fixed-key wording; what
## players see comes from Controls.cue_hint() (their own controls).
const CUES := {
	"slam": {"hint": "SLAM  -  Ctrl+S back step", "color": BACK_STEP_COLOR},
	"jab": {"hint": "JAB  -  E slip right", "color": SLIP_COLOR},
	"cross": {"hint": "CROSS  -  Q slip left", "color": SLIP_COLOR},
	"left_hook": {"hint": "LEFT HOOK  -  Ctrl+D roll right", "color": ROLL_COLOR},
	"right_hook": {"hint": "RIGHT HOOK  -  Ctrl+A roll left", "color": ROLL_COLOR},
	"uppercut": {"hint": "UPPERCUT  -  Ctrl+S back step", "color": BACK_STEP_COLOR},
	"haymaker": {"hint": "HAYMAKER  -  Ctrl+A / D roll", "color": ROLL_COLOR},
	"staff": {"hint": "STAFF SWING  -  Ctrl+A / D roll", "color": ROLL_COLOR},
	"thrust": {"hint": "THRUST  -  Q / E slip, hook back", "color": SLIP_COLOR},
	"slash": {"hint": "SLASH  -  Ctrl+A / D roll", "color": ROLL_COLOR},
	"bash": {"hint": "SHIELD BASH  -  Q / E slip", "color": SLIP_COLOR},
	"claw": {"hint": "CLAW  -  Ctrl+A / D roll", "color": ROLL_COLOR},
	"sweep": {"hint": "SWEEP  -  Ctrl+A / D roll", "color": ROLL_COLOR},
}
## Weapon attacks are always thrown with the weapon arm.
const WEAPON_ATTACKS := ["staff", "thrust", "slash"]
const COUNTER_ATTACKS := ["jab", "cross", "left_hook", "right_hook", "uppercut"]
const UPPER_ARM_LENGTH := 0.24
## Body parts above this height ride on the torso pivot (it twists at the hips).
const TORSO_PIVOT := 0.95
## Torso motion per attack, for a right-hand attack (mirrored for the left):
## [windup rotation, windup dip, strike rotation, strike dip]. Rotation is
## (lean: + = back, twist: - = right shoulder back, tilt: - = right side down).
const TORSO_POSES := {
	"jab": [Vector3(0.0, -0.14, 0.0), 0.0, Vector3(-0.05, 0.12, 0.0), 0.0],
	"cross": [Vector3(0.04, -0.35, 0.0), 0.0, Vector3(-0.08, 0.28, 0.0), 0.0],
	"left_hook": [Vector3(0.0, -0.44, -0.12), -0.04, Vector3(0.0, 0.35, 0.06), 0.0],
	"right_hook": [Vector3(0.0, -0.44, -0.12), -0.04, Vector3(0.0, 0.35, 0.06), 0.0],
	"uppercut": [Vector3(-0.1, -0.2, -0.12), -0.1, Vector3(0.12, 0.2, 0.05), 0.03],
	"haymaker": [Vector3(0.12, -0.6, -0.05), 0.0, Vector3(-0.1, 0.5, 0.05), 0.0],
	"slam": [Vector3(0.25, 0.0, 0.0), 0.0, Vector3(-0.3, 0.0, 0.0), -0.05],
	"staff": [Vector3(0.05, -0.5, 0.0), 0.0, Vector3(-0.05, 0.45, 0.0), 0.0],
	"thrust": [Vector3(0.0, -0.1, 0.0), 0.0, Vector3(-0.08, 0.1, 0.0), 0.0],
	"slash": [Vector3(0.05, -0.5, 0.0), 0.0, Vector3(-0.05, 0.5, 0.0), 0.0],
	"bash": [Vector3(0.04, -0.25, 0.0), 0.0, Vector3(-0.1, 0.2, 0.0), 0.0],
	"claw": [Vector3(0.1, -0.45, -0.08), 0.0, Vector3(-0.08, 0.4, 0.06), 0.0],
	"sweep": [Vector3(0.08, -0.7, -0.06), -0.05, Vector3(-0.05, 0.6, 0.06), 0.0],
}
## The torso reaches its full coil this far into the windup, then holds.
const COIL_BY := 0.7

@export var attack_damage := 4.0
@export var attack_range := 2.3
## Moves between attacks: closes in, backs off when crowded, circles.
@export var footwork := true
@export var preferred_distance := 1.8

## Show the key that beats each attack above the boxer (training).
var show_hints := false
## Light the attacking glove in its defense color during the windup.
var glow_tells := true
## Multiplies windup times (lower = less warning).
var windup_scale := 1.0

var _state := State.IDLE
var _state_timer := 1.0
var _queue: Array[String] = []
var _attack := ""
## Arm used by one-armed attacks that can come from either side (uppercut, haymaker).
var _power_arm := "right"
## Arm the combo's next uppercut/haymaker will use: the one opposite the
## current punch, like a real combo (so its preview glow can show right away).
var _next_power_arm := "right"
var _open_time := 0.0
var _evade_side := 1.0
var _arms := {}
var _arm_rest := {}
var _gloves := {}
var _weapon_glows := {}
## Elbow pivots: the forearm and glove (and any weapon) hang off these.
var _forearms := {}
var _torso: Node3D
var _windup_total := 1.0
var _cue_label: Label3D
var _circle_sign := 1.0
var _circle_timer := 0.0
var _hop_time := 0.0
## True once the current windup has flashed.
var _flashed := false
## True when the current attack was already shown as the combo's next attack.
var _previewed := false
## What the last strike did to the player ("dodged", "hit", ... or "" if it missed).
var _last_result := ""


## Bosses: while more punches are queued in a combo, hits still land but
## can't stagger or interrupt it. Dodge the whole combo, then punish the end.
var combo_armor := false
var _armor_shown := false


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	if combo_armor and _combo_armored():
		if stagger and not _armor_shown and not is_dead():
			_armor_shown = true
			DamagePopup.spawn(get_parent(), "SUPER ARMOR", Color(1.0, 0.82, 0.35), 46, global_position + Vector3(0, 2.6 * _body.scale.y, 0))
			HitFx.ring(get_parent(), hit_point, Color(1.0, 0.82, 0.35, 0.7), 0.9)
			Sfx.play_at("block", hit_point, -2.0, 0.8)
		stagger = false
		push *= 0.2
	return super(raw_damage, hit_point, push, stagger, caption, pierce, crush)


## Mid-combo with more punches still to come.
func _combo_armored() -> bool:
	return _state in [State.WINDUP, State.STRIKE] and not _queue.is_empty()


func _ready() -> void:
	super()
	_build_torso()
	_cue_label = Label3D.new()
	_cue_label.position.y = 2.55 * _body.scale.y
	_cue_label.fixed_size = true
	_cue_label.pixel_size = 0.0012
	_cue_label.font_size = 40
	_cue_label.outline_size = 10
	_cue_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cue_label.no_depth_test = true
	_cue_label.visible = false
	add_child(_cue_label)


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	_turn_toward(offset, delta)
	_state_timer -= delta
	match _state:
		State.IDLE:
			if _state_timer <= 0.0 and has_turn() and distance <= attack_range:
				_start_combo()
		State.WINDUP:
			if not _flashed and _state_timer <= TELL_FLASH_TIME:
				_flashed = true
				if glow_tells:
					_flash_tell(CUES[_attack].color)
			if _state_timer <= 0.0:
				_strike(distance)
		State.STRIKE:
			if _state_timer <= 0.0:
				if _queue.is_empty():
					_enter(State.RECOVER, _open_time if _open_time > 0.0 else randf_range(0.8, 1.4))
					_open_time = 0.0
					end_turn()
				else:
					_power_arm = _next_power_arm
					_begin_attack(_queue.pop_front(), FOLLOW_UP_WINDUP)
					_previewed = true
		State.RECOVER:
			if _state_timer <= 0.0:
				_enter(State.IDLE, _idle_time())
		State.EVADE:
			if _state_timer <= 0.0:
				_begin_attack(COUNTER_ATTACKS.pick_random(), COUNTER_WINDUP)
	if footwork and (_state in [State.IDLE, State.RECOVER]):
		if not in_turn():
			return _wait_move(offset, delta, move_speed)
		return _footwork(offset, delta)
	return Vector3.ZERO


func _on_staggered() -> void:
	_queue.clear()
	_cue_label.visible = false
	_enter(State.RECOVER, 0.6)


# --- Overridden by subclasses -------------------------------------------------

## The next combo to throw, as a list of attack names.
func _pick_combo() -> Array:
	return ["jab"]


## Pause between combos.
func _idle_time() -> float:
	return randf_range(0.3, 0.9)


# --- Fighting -------------------------------------------------------------------

func _start_combo() -> void:
	_armor_shown = false
	_queue.assign(_pick_combo())
	_power_arm = ["left", "right"].pick_random()
	var first: String = _queue.pop_front()
	_begin_attack(first, FIRST_WINDUP[first])


func _begin_attack(attack: String, windup: float) -> void:
	_attack = attack
	_flashed = false
	_previewed = false
	_windup_total = maxf(windup * windup_scale, TELL_FLASH_TIME + 0.15)
	var left := _attack_uses_arm(attack, "left")
	var right := _attack_uses_arm(attack, "right")
	if left != right:
		_next_power_arm = "right" if left else "left"
	else:
		_next_power_arm = ["left", "right"].pick_random()
	# Always long enough to wind up and then flash.
	_enter(State.WINDUP, _windup_total)
	_cue_label.text = Controls.cue_hint(attack)
	_cue_label.modulate = CUES[attack].color
	_cue_label.visible = show_hints
	var mouth := global_position + Vector3.UP * 1.6 * _body.scale.y
	if attack == "slam":
		Sfx.play_at("growl", mouth, -6.0, 1.2 / _body.scale.y)
	else:
		Sfx.play_at("draw", mouth, -4.0, 1.6 / _body.scale.y)


func incoming_attack() -> String:
	return _attack if _state in [State.WINDUP, State.STRIKE] else ""


func attack_eta() -> float:
	return _state_timer if _state == State.WINDUP else 0.0


func _strike(distance: float) -> void:
	_last_result = ""
	_enter(State.STRIKE, STRIKE_TIME)
	_cue_label.visible = false
	Sfx.play_at("whoosh", global_position + Vector3.UP * 1.5, -4.0, 0.9)
	if distance > attack_range + 0.5 and not player.is_back_stepping():
		return
	_on_attacking()
	if _dead:
		return
	var result := player.receive_attack(attack_damage * damage_multiplier, global_position, _attack, self)
	_last_result = result
	if result == "dodged":
		# Keep throwing the rest of the combo so dodges can be chained; it's
		# left open at the end. A counter mid-combo staggers it and cuts it short.
		_open_time = DODGED_OPEN_TIME


func _enter(state: State, time: float) -> void:
	_state = state
	_state_timer = time


## Movement between attacks: close in, back off, or circle.
func _footwork(offset: Vector3, delta: float) -> Vector3:
	var distance := offset.length()
	var direction := offset.normalized()
	if distance > preferred_distance + 0.3:
		return direction * move_speed
	if distance < TOO_CLOSE_DISTANCE:
		return -direction * move_speed
	_circle_timer -= delta
	if _circle_timer <= 0.0:
		_circle_timer = randf_range(0.8, 2.0)
		_circle_sign = [-1.0, 1.0].pick_random()
	return direction.cross(Vector3.UP) * _circle_sign * move_speed * 0.5


# --- Animation ------------------------------------------------------------------

func _uses_arm(arm: String) -> bool:
	return _attack_uses_arm(_attack, arm)


func _attack_uses_arm(attack: String, arm: String, power_arm := _power_arm) -> bool:
	match attack:
		"jab", "left_hook":
			return arm == "left"
		"cross", "right_hook":
			return arm == "right"
		"uppercut", "haymaker":
			return arm == power_arm
		"staff", "thrust", "slash":
			return arm == "right"
		"bash":
			return arm == "left"  # The shield arm.
		"claw", "sweep":
			return arm == power_arm
	return true  # Slam uses both.


## [shoulder rotation, forward reach, elbow rotation] for an arm right now.
## Arms point along -Z from the shoulder; positive pitch raises them, positive
## yaw times side swings them inward. The elbow's rotation bends the forearm
## the same way, relative to the upper arm.
func _arm_pose(arm: String) -> Array:
	var side := -1.0 if arm == "left" else 1.0
	# Elbows tucked, gloves up by the chin.
	var guard := [Vector3(-0.9, 0.35 * side, 0), 0.0, Vector3(2.4, 0, 0)]
	if not (_state in [State.WINDUP, State.STRIKE]) or not _uses_arm(arm):
		return guard
	var striking := _state == State.STRIKE
	match _attack:
		"jab", "cross":
			# Loaded with the elbow bent, then snapped out straight.
			var loaded := 0.1 if _attack == "jab" else 0.16
			return [Vector3(0.1, 0.12 * side, 0), -0.3, Vector3.ZERO] if striking \
					else [Vector3(-0.6, 0.2 * side, 0), loaded, Vector3(2.0, 0, 0)]
		"left_hook", "right_hook":
			# Elbow out wide and level, forearm bent at ~90 degrees; swings across.
			return [Vector3(0.15, 0.3 * side, 0), -0.05, Vector3(0, 1.3 * side, 0)] if striking \
					else [Vector3(0.15, -1.2 * side, 0), 0.05, Vector3(0, 1.6 * side, 0)]
		"uppercut":
			# Elbow drops low with the fist down by the waist, then drives up.
			return [Vector3(-0.2, 0.25 * side, 0), -0.1, Vector3(1.6, 0, 0)] if striking \
					else [Vector3(-1.2, 0.15 * side, 0), 0.05, Vector3(1.0, 0, 0)]
		"slam":
			return [Vector3(0.2, 0.1 * side, 0), -0.2, Vector3(0.1, 0, 0)] if striking \
					else [Vector3(2.4, 0.1 * side, 0), 0.1, Vector3(-0.5, 0, 0)]
		"haymaker":
			# Wound way back and out, then a wide loop across.
			return [Vector3(0.15, 0.9 * side, 0), -0.1, Vector3(0, 0.6 * side, 0)] if striking \
					else [Vector3(0.35, -1.5 * side, 0), 0.2, Vector3(0, 0.5 * side, 0)]
		"staff":
			# Staff cocked back over the shoulder, then a flat swing at head height.
			return [Vector3(0.2, 1.5 * side, 0), -0.1, Vector3.ZERO] if striking \
					else [Vector3(1.2, -1.6 * side, 0), 0.3, Vector3.ZERO]
		"thrust":
			# Blade drawn back at the hip, then driven straight out.
			return [Vector3(0.05, 0.1 * side, 0), -0.5, Vector3.ZERO] if striking \
					else [Vector3(0.15, -0.25 * side, 0), 0.35, Vector3.ZERO]
		"slash":
			# Wound far back, then a wide sweep across.
			return [Vector3(0.2, 1.6 * side, 0), -0.1, Vector3.ZERO] if striking \
					else [Vector3(0.35, -2.0 * side, 0), 0.2, Vector3.ZERO]
		"bash":
			# Shield pulled in tight, then shoved straight out.
			return [Vector3(0.1, 0.15 * side, 0), -0.4, Vector3(0.2, 0, 0)] if striking \
					else [Vector3(-0.3, -0.2 * side, 0), 0.25, Vector3(1.4, 0, 0)]
		"claw":
			# Raised high and wide, then raked down across.
			return [Vector3(-0.2, 0.8 * side, 0), -0.1, Vector3(0.2, 0, 0)] if striking \
					else [Vector3(1.3, -1.0 * side, 0), 0.15, Vector3(0.3, 0, 0)]
		"sweep":
			# Arm straight out wide and low, then a huge flat sweep.
			return [Vector3(0.0, 1.2 * side, 0), -0.1, Vector3.ZERO] if striking \
					else [Vector3(0.0, -1.7 * side, 0), 0.25, Vector3.ZERO]
	return guard


## The side (1 = right, -1 = left) an attack is thrown from, for mirroring.
func _attack_side(attack: String) -> float:
	if _attack_uses_arm(attack, "left") and not _attack_uses_arm(attack, "right"):
		return -1.0
	return 1.0


## [rotation, dip] the torso should be at right now.
func _torso_pose() -> Array:
	if not (_state in [State.WINDUP, State.STRIKE]) or not TORSO_POSES.has(_attack):
		return [Vector3.ZERO, 0.0]
	var pose: Array = TORSO_POSES[_attack]
	var side := _attack_side(_attack)
	var mirror := Vector3(1.0, side, side)
	if _state == State.STRIKE:
		return [pose[2] * mirror, pose[3]]
	# Coil through the first part of the windup, then hold, fully loaded.
	var progress := 1.0 - clampf(_state_timer / _windup_total, 0.0, 1.0)
	var coil := smoothstep(0.0, COIL_BY, progress)
	return [pose[0] * mirror * coil, pose[1] * coil]


func _animate(delta: float, speed: float) -> void:
	var blend := minf(1.0, (30.0 if _state == State.STRIKE else 12.0) * delta)
	for arm in _arms:
		var pose := _arm_pose(arm)
		var pivot: Node3D = _arms[arm]
		pivot.rotation = pivot.rotation.lerp(pose[0], blend)
		pivot.position = pivot.position.lerp(_arm_rest[arm] + Vector3(0, 0, pose[1]), blend)
		var elbow: Node3D = _forearms[arm]
		elbow.rotation = elbow.rotation.lerp(pose[2], blend)
		var glow := _arm_glow(arm)
		for glove: StandardMaterial3D in _glow_parts(arm):
			if not glove.has_meta("base_color"):
				glove.set_meta("base_color", glove.albedo_color)
			if glow.is_empty():
				glove.emission_energy_multiplier = lerpf(glove.emission_energy_multiplier, 0.0, minf(1.0, 15.0 * delta))
				glove.albedo_color = glove.albedo_color.lerp(glove.get_meta("base_color"), minf(1.0, 15.0 * delta))
			else:
				# Tint the glove itself too, so its own color doesn't wash out the hue.
				glove.emission = glow.color
				glove.emission_energy_multiplier = glow.energy
				glove.albedo_color = glow.color.darkened(0.4)
	# Torso: coils with the windup, snaps through on the strike, then settles.
	if _torso:
		var torso := _torso_pose()
		var torso_blend := minf(1.0, (30.0 if _state == State.STRIKE else 10.0 if _state == State.WINDUP else 8.0) * delta)
		_torso.rotation = _torso.rotation.lerp(torso[0], torso_blend)
		_torso.position.y = lerpf(_torso.position.y, TORSO_PIVOT + torso[1], torso_blend)
	# Little hops while moving, like footwork.
	_hop_time += delta * 12.0
	var hop := absf(sin(_hop_time)) * 0.05 * minf(speed, 1.0)
	_body.position.y = lerpf(_body.position.y, hop, minf(1.0, 20.0 * delta))
	var lean := 0.35 * _evade_side if _state == State.EVADE else 0.0
	_body.position.x = lerpf(_body.position.x, lean, minf(1.0, 20.0 * delta))
	_body.rotation.z = lerpf(_body.rotation.z, -lean * 0.6, minf(1.0, 20.0 * delta))


## How this arm should glow right now: {color, energy}, or {} for dark.
## Its own attack flashes bright once wound up; a combo's next attack shows
## dimmer from the moment the current one flashes until it flashes itself.
func _arm_glow(arm: String) -> Dictionary:
	if not glow_tells:
		return {}
	var winding := _state == State.WINDUP
	if winding and _uses_arm(arm) and (_flashed or _previewed):
		return {"color": CUES[_attack].color, "energy": FLASH_GLOW if _flashed else PREVIEW_GLOW}
	var next_shown := (winding and _flashed) or _state == State.STRIKE
	if next_shown and not _queue.is_empty() and _attack_uses_arm(_queue[0], arm, _next_power_arm):
		return {"color": CUES[_queue[0]].color, "energy": PREVIEW_GLOW}
	return {}


## Materials that light up when this arm's attack flashes (glove plus any weapon).
func _glow_parts(arm: String) -> Array:
	return [_gloves[arm]] + _weapon_glows.get(arm, [])


## Held weapon parts (EnemyGear recolors them to its tier).
var _weapons: Array = []


func _hand_nodes() -> Array:
	return _forearms.values()


func _weapon_parts() -> Array:
	return _weapons


## The forearm (elbow pivot) of an arm: things held in the hand go here.
## Positions on it are from the elbow; arm_to_hand converts a position
## measured from the shoulder along a straight arm.
func _hand(arm: String) -> Node3D:
	return _forearms[arm]


static func arm_to_hand(pos: Vector3) -> Vector3:
	return pos + Vector3(0, 0, UPPER_ARM_LENGTH)


## Adds a weapon (staff, sword) to an arm. pos is measured from the shoulder
## along the arm. Its glow material lights up with the attack's tell flash.
func _hold_weapon(arm: String, mesh: PrimitiveMesh, color: Color, pos: Vector3, rot := Vector3.ZERO) -> void:
	var material := _material(color, 0.5)
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.0
	_weapons.append(_part(_hand(arm), mesh, material, arm_to_hand(pos), rot))
	if not _weapon_glows.has(arm):
		_weapon_glows[arm] = []
	_weapon_glows[arm].append(material)


## Two arms pivoting at the shoulders and bending at the elbows, each ending
## in a glove that can glow.
func _build_arms(arm_material: Material, glove_color: Color, shoulder_height := 1.45, shoulder_width := 0.3) -> void:
	for arm in ["left", "right"]:
		var side := -1.0 if arm == "left" else 1.0
		var shoulder := Vector3(shoulder_width * side, shoulder_height, 0)
		var pivot := _pivot(_body, shoulder)
		# Arm cylinders are turned to lie along -Z.
		_part(pivot, _cylinder(0.055, UPPER_ARM_LENGTH), arm_material, Vector3(0, 0, -UPPER_ARM_LENGTH / 2), Vector3(-PI / 2, 0, 0))
		var elbow := _pivot(pivot, Vector3(0, 0, -UPPER_ARM_LENGTH))
		_part(elbow, _cylinder(0.05, 0.2), arm_material, Vector3(0, 0, -0.1), Vector3(-PI / 2, 0, 0))
		var glove := _material(glove_color)
		glove.emission_enabled = true
		glove.emission_energy_multiplier = 0.0
		_part(elbow, _box(Vector3(0.16, 0.16, 0.2)), glove, arm_to_hand(Vector3(0, 0, -0.48)))
		_arms[arm] = pivot
		_forearms[arm] = elbow
		_arm_rest[arm] = shoulder
		_gloves[arm] = glove


## Moves everything above the hips onto a torso pivot so the upper body can
## twist and lean into attacks while the legs stay planted.
func _build_torso() -> void:
	_torso = Node3D.new()
	_torso.position = Vector3(0, TORSO_PIVOT, 0)
	var upper: Array[Node3D] = []
	for child in _body.get_children():
		if child is Node3D and child.position.y > TORSO_PIVOT - 0.02:
			upper.append(child)
	_body.add_child(_torso)
	for part in upper:
		var pos := part.position - _torso.position
		_body.remove_child(part)
		_torso.add_child(part)
		part.position = pos
	for arm in _arm_rest:
		_arm_rest[arm] -= _torso.position
