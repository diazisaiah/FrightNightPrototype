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
## Light at a glowing glove, per point of glow.
const TELL_LIGHT := 1.6
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
## Scales how long it's left open after you dodge a whole combo.
var open_scale := 1.0

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
var _tell_lights := {}
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
## Seconds added to every windup (after windup_scale): the later Dead League
## contenders get a little extra to read their bigger swings.
var windup_pad := 0.0
var _armor_shown := false


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	# Specials are armored: hits land, but nothing staggers it (except dazed).
	if _special != "" and _step != "dazed":
		stagger = false
		push = Vector3.ZERO
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
	if _special_think(delta, distance):
		return _special_move
	_turn_toward(offset, delta)
	_state_timer -= delta
	match _state:
		State.IDLE:
			if _state_timer <= 0.0 and has_turn() and distance <= attack_range:
				_start_combo()
		State.WINDUP:
			if not _flashed and _state_timer <= tell_time():
				_flashed = true
				if glow_tells:
					_flash_tell(CUES[_attack].color)
			if _state_timer <= 0.0:
				_strike(distance)
		State.STRIKE:
			if _state_timer <= 0.0:
				if _queue.is_empty():
					_enter(State.RECOVER, _open_time if _open_time > 0.0 else _recover_time())
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


func combo_finished() -> bool:
	return _queue.is_empty()


func _on_staggered() -> void:
	if _special != "":
		_end_special()
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


## Settling after a combo that wasn't dodged (a dodged one leaves it open for
## _open_time instead).
func _recover_time() -> float:
	return randf_range(0.8, 1.4)


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
	_windup_total = maxf(windup * windup_scale, tell_time() + 0.15) + windup_pad
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


func _die(push: Vector3) -> void:
	_clear_specials()
	super(push)


func incoming_attack() -> String:
	if _special != "":
		if _special == "leap_slam" and _step in ["crouch", "air"] or _special == "ground_slam":
			return "quake"
		if _special in ["charge", "dash"] and _step in ["aim", "dash"]:
			return "charge"
		if _special == "scream":
			return "scream"
		return ""
	return _attack if _state in [State.WINDUP, State.STRIKE] else ""


func attack_eta() -> float:
	if _special != "":
		match _step:
			"crouch":
				return CROUCH_TIME - _step_time + LEAP_TIME
			"air":
				return LEAP_TIME - _step_time
			"raise":
				return GROUND_SLAM_WINDUP - _step_time
			"aim":
				return CHARGE_WINDUP - _step_time
			"howl":
				return SCREAM_WINDUP - _step_time
			"dash":
				return 0.0
		return INF
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
		# Exploit (the Answer's card): open longer.
		_open_time = (DODGED_OPEN_TIME + GameState.get_effect("exploit")) * open_scale


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
	if _charging():
		# Head down, both arms out low in front: a tackle coming.
		return [Vector3(-0.35, 0.3 * side, 0), 0.0, Vector3(0.5, 0, 0)]
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
			# Blade drawn back at the chest with its point aimed at you, then
			# driven straight out.
			return [Vector3(0.05, 0.05 * side, 0), -0.55, Vector3.ZERO] if striking \
					else [Vector3(-0.95, -0.1 * side, 0), 0.45, Vector3(0.95, 0.5 * side, 0)]
		"slash":
			# Wound far back, then a wide sweep across.
			return [Vector3(0.2, 1.6 * side, 0), -0.1, Vector3.ZERO] if striking \
					else [Vector3(0.35, -2.0 * side, 0), 0.2, Vector3.ZERO]
		"bash":
			# Shield pulled in tight, then shoved straight out.
			return [Vector3(0.1, 0.15 * side, 0), -0.4, Vector3(0.2, 0, 0)] if striking \
					else [Vector3(-0.3, -0.2 * side, 0), 0.25, Vector3(1.4, 0, 0)]
		"claw":
			# Out wide at shoulder height like a hook, then raked across.
			return [Vector3(0.1, 0.7 * side, 0), -0.1, Vector3(0, 0.6 * side, 0)] if striking \
					else [Vector3(0.2, -1.5 * side, 0), 0.15, Vector3(0, 0.4 * side, 0)]
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
		# A light at the glove, so the tell shows even when the hand is hidden
		# (behind the body, edge-on, under gear).
		var light: OmniLight3D = _tell_lights.get(arm)
		if light:
			var energy: float = glow.get("energy", 0.0) * TELL_LIGHT
			light.light_energy = lerpf(light.light_energy, energy, minf(1.0, 20.0 * delta))
			if not glow.is_empty():
				light.light_color = glow.color
			light.visible = light.light_energy > 0.03
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
	_animate_special(delta)


func _arm_glow(arm: String) -> Dictionary:
	if not glow_tells:
		return {}
	if _charging():
		var ramp := 1.0 if _step == "dash" else clampf(_step_time / CHARGE_WINDUP, 0.0, 1.0)
		return {"color": Telegraphs.DANGER, "energy": lerpf(0.5, FLASH_GLOW, ramp)}
	var winding := _state == State.WINDUP
	if winding and _uses_arm(arm) and (_flashed or _previewed):
		return {"color": CUES[_attack].color, "energy": FLASH_GLOW if _flashed else PREVIEW_GLOW}
	var next_shown := (winding and _flashed) or _state == State.STRIKE
	if next_shown and not _queue.is_empty() and _attack_uses_arm(_queue[0], arm, _next_power_arm):
		return {"color": CUES[_queue[0]].color, "energy": PREVIEW_GLOW}
	return {}


## Winding up or running a charge / dash (special).
func _charging() -> bool:
	return _special in ["charge", "dash"] and _step in ["aim", "dash"]


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


## Gear over a hand, or a reskinned weapon (EnemyGear): lights up with that
## arm's tells like the glove it covers.
func add_glow_part(part: Node, material: StandardMaterial3D) -> void:
	for arm in _forearms:
		if (_forearms[arm] as Node).is_ancestor_of(part):
			if not _weapon_glows.has(arm):
				_weapon_glows[arm] = []
			_weapon_glows[arm].append(material)
			return


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
		var light := OmniLight3D.new()
		light.omni_range = 1.5
		light.light_energy = 0.0
		light.visible = false
		light.position = arm_to_hand(Vector3(0, 0, -0.48))
		elbow.add_child(light)
		_tell_lights[arm] = light
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


# --- Specials -----------------------------------------------------------------------

## Big moves on top of the boxing, for any boxer with a special_kit (the Dead
## League contenders and the tougher monsters of the deeper tiers). Each is
## marked on the floor (Telegraphs), armored while it happens (hits land but
## don't stagger, except dazed), and leaves an opening after.
##   leap_slam   - crouches, leaps onto where you stand (a red ring follows
##                 you until it jumps), lands in a shockwave: get out or jump.
##   ground_slam - raises both fists, a ring around it, then a shockwave.
##   charge      - a lane lights toward you (it tracks you, then locks), then
##                 a shoulder charge to the ropes / walls. It ends dazed.
##   dash        - a short charge (a few meters), no daze.
##   zones       - leaps to the far edge and calls down burning circles.
##   miasma      - leaps to the far edge and lobs vials that leave poison.
##   scream      - a wide cone in front of it lights up, then a shriek that
##                 hits everything in it: back step out (or leave the cone).
const SPECIAL_NAMES := {"leap_slam": "DEATH FROM ABOVE", "charge": "GHOST CHARGE", "zones": "JUDGMENT",
		"miasma": "MIASMA", "ground_slam": "GROUND SLAM", "dash": "BULL RUSH", "scream": "SHRIEK"}
const CROUCH_TIME := 0.45
const LEAP_TIME := 0.95
const SLAM_RADIUS := 1.9
const SLAM_DAMAGE := 1.6
const GROUND_SLAM_WINDUP := 0.9
const GROUND_SLAM_RADIUS := 3.3
const CHARGE_WINDUP := 1.15
## The lane stops tracking you this long before the dash.
const CHARGE_LOCK := 0.4
const CHARGE_SPEED := 13.0
const CHARGE_WIDTH := 1.3
const CHARGE_DAMAGE := 1.9
const DASH_REACH := 7.0
const SCREAM_WINDUP := 1.0
const SCREAM_REACH := 5.5
const SCREAM_WIDTH := 3.0
const SCREAM_DAMAGE := 1.4
const DAZED_TIME := 1.5
const ZONE_FUSE := 1.4
const ZONE_DAMAGE := 1.3
const MIASMA_LINGER := 3.5
## Poison cloud damage (x attack damage) every half second you stand in one.
const MIASMA_TICK := 0.22
const SPECIAL_RECOVER := 0.9

## The moves this boxer may use ("" kinds above); empty: none.
var special_kit: Array = []
## Seconds between specials (and before the first).
var special_every := 9.0
var special_first := 5.0
## Shown over its head when it starts one (contenders also tell the HUD).
var special_names := true
var _special := ""
var _last_special := ""
var _step := ""
var _step_time := 0.0
var _special_cooldown := 0.0
var _special_primed := false
var _repeats := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _charge_dir := Vector3.FORWARD
var _charge_end := Vector3.ZERO
var _charge_hit := false
var _locked := false
var _marks: Telegraphs


## Called from _think: runs a special, or starts one when it's time.
## Returns true (with the movement in _special_move) while one is running.
var _special_move := Vector3.ZERO


func _special_think(delta: float, distance: float) -> bool:
	if special_kit.is_empty():
		return false
	if _special != "":
		_special_move = _run_special(delta)
		return true
	if not _special_primed:
		_special_primed = true
		_special_cooldown = special_first
	_special_cooldown -= delta
	if _special_cooldown > 0.0 or _state != State.IDLE or not has_turn():
		return false
	var kit: Array = special_kit.filter(func(kind: String) -> bool: return _special_in_range(kind, distance))
	if kit.size() > 1:
		kit = kit.filter(func(kind: String) -> bool: return kind != _last_special)
	if kit.is_empty():
		return false
	_start_special(kit.pick_random())
	_special_move = Vector3.ZERO
	return true


## Whether a move makes sense from here.
func _special_in_range(kind: String, distance: float) -> bool:
	match kind:
		"ground_slam":
			return distance < GROUND_SLAM_RADIUS - 0.3
		"dash":
			return distance > 2.5 and distance < DASH_REACH + 1.0
		"charge":
			return distance > 2.5
		"leap_slam":
			return distance < 14.0
		"scream":
			return distance < SCREAM_REACH - 0.5
	return true


# Hooks the Dead League contenders override.

func _special_tint() -> Color:
	return hit_color


func _special_repeats(_kind: String) -> int:
	return 0


func _special_delay() -> float:
	return special_every * randf_range(0.85, 1.15)


func _zone_count() -> int:
	return 3


func _announce_special(kind: String) -> void:
	if special_names:
		DamagePopup.spawn(get_parent(), SPECIAL_NAMES[kind], _special_tint(), 36, global_position + Vector3(0, 2.6 * _body.scale.y, 0))


func _start_special(kind: String) -> void:
	if _marks == null:
		_marks = Telegraphs.new(self)
		add_child(_marks)
	_special = kind
	_last_special = kind
	_queue.clear()
	_cue_label.visible = false
	_enter(State.IDLE, 0.0)
	_repeats = _special_repeats(kind)
	_announce_special(kind)
	Sfx.play_at("growl", global_position + Vector3.UP * 2.0, 1.0, 0.9)
	match kind:
		"leap_slam":
			_begin_leap(_clamp_to_arena(player.global_position))
		"charge", "dash":
			_begin_charge()
		"ground_slam":
			_marks.show_ring(global_position, GROUND_SLAM_RADIUS)
			_set_step("raise")
		"scream":
			_locked = false
			_aim_scream()
			_set_step("howl")
		"zones", "miasma":
			_begin_leap(_far_edge())


func _end_special() -> void:
	_special = ""
	_step = ""
	if _marks:
		_marks.hide_mark()
	collision_mask |= 2
	_special_cooldown = _special_delay()
	_enter(State.IDLE, _idle_time() * 0.5)


func _set_step(step: String) -> void:
	_step = step
	_step_time = 0.0


func _run_special(delta: float) -> Vector3:
	_step_time += delta
	match _step:
		"crouch":
			_turn_toward(_leap_to - global_position, delta)
			if _special == "leap_slam":
				# It follows you until it jumps.
				_leap_to = _clamp_to_arena(player.global_position)
				_marks.show_ring(_leap_to, SLAM_RADIUS)
			if _step_time >= CROUCH_TIME:
				_leap_from = global_position
				velocity.y = _gravity * LEAP_TIME * 0.5
				collision_mask &= ~2  # Over you, not into you.
				Sfx.play_at("whoosh", global_position, 2.0, 0.6)
				_set_step("air")
			return Vector3.ZERO
		"air":
			if _special == "leap_slam":
				_marks.pulse(_step_time / LEAP_TIME)
			if (_step_time >= LEAP_TIME * 0.6 and is_on_floor()) or _step_time >= LEAP_TIME + 0.5:
				_land()
				return Vector3.ZERO
			var flat := _leap_to - _leap_from
			flat.y = 0.0
			return flat / LEAP_TIME
		"raise":
			_turn_toward(player.global_position - global_position, delta)
			_marks.show_ring(global_position, GROUND_SLAM_RADIUS)
			_marks.pulse(_step_time / GROUND_SLAM_WINDUP)
			if not _locked and _step_time >= GROUND_SLAM_WINDUP - tell_time():
				_locked = true
				_flash_tell(Telegraphs.DANGER, 2.2)
			if _step_time >= GROUND_SLAM_WINDUP:
				_locked = false
				_marks.hide_mark()
				_slam_at(global_position, GROUND_SLAM_RADIUS)
				_set_step("recover")
			return Vector3.ZERO
		"howl":
			if _step_time < SCREAM_WINDUP - CHARGE_LOCK:
				_aim_scream()
			elif not _locked:
				_locked = true
				_flash_tell(Telegraphs.DANGER, 1.9)
			_turn_toward(_charge_dir, delta * 3.0)
			_marks.pulse(_step_time / SCREAM_WINDUP)
			if _step_time >= SCREAM_WINDUP:
				_locked = false
				_marks.hide_mark()
				_shriek()
				_set_step("recover")
			return Vector3.ZERO
		"aim":
			if _step_time < CHARGE_WINDUP - CHARGE_LOCK:
				_aim_charge()
			elif not _locked:
				_locked = true
				_flash_tell(Telegraphs.DANGER, 2.4)
			_turn_toward(_charge_dir, delta * 3.0)
			_marks.pulse(_step_time / CHARGE_WINDUP)
			if _step_time >= CHARGE_WINDUP:
				_charge_hit = false
				collision_mask &= ~2
				_marks.hide_mark()
				Sfx.play_at("whoosh", global_position, 4.0, 0.5)
				_set_step("dash")
			return Vector3.ZERO
		"dash":
			_check_charge_hit()
			var past := (global_position - _charge_end).dot(_charge_dir) >= 0.0
			if past or _step_time > 1.6:
				collision_mask |= 2
				if _special == "dash":
					_set_step("recover")
					return Vector3.ZERO
				Sfx.play_at("block", global_position, 2.0, 0.6)
				player.shake(0.05)
				if _repeats > 0:
					_repeats -= 1
					_begin_charge(0.75)
				else:
					DamagePopup.spawn(get_parent(), "DAZED", Color(1.0, 0.9, 0.5), 40, global_position + Vector3(0, 2.4 * _body.scale.y, 0))
					_set_step("dazed")
				return Vector3.ZERO
			return _charge_dir * CHARGE_SPEED
		"cast":
			_turn_toward(player.global_position - global_position, delta)
			if _step_time >= 0.7:
				_set_step("recover")
			return Vector3.ZERO
		"dazed":
			if _step_time >= DAZED_TIME:
				_end_special()
			return Vector3.ZERO
		"recover":
			_turn_toward(player.global_position - global_position, delta)
			if _step_time >= SPECIAL_RECOVER:
				if _repeats > 0 and _special == "leap_slam":
					_repeats -= 1
					_begin_leap(_clamp_to_arena(player.global_position))
				else:
					_end_special()
			return Vector3.ZERO
	_end_special()
	return Vector3.ZERO


func _begin_leap(to: Vector3) -> void:
	_leap_to = to
	if _special == "leap_slam":
		_marks.show_ring(_leap_to, SLAM_RADIUS)
	_set_step("crouch")


func _land() -> void:
	collision_mask |= 2
	velocity.y = 0.0
	Sfx.play_at("quake", global_position, 3.0 if _special == "leap_slam" else -2.0, 0.8)
	HitFx.burst(get_parent(), global_position + Vector3.UP * 0.2, Vector3.UP, Color(0.35, 0.3, 0.25), 30, 5.0, false, 0.1)
	if _special == "leap_slam":
		_marks.hide_mark()
		_slam_at(global_position, SLAM_RADIUS)
		_set_step("recover")
	else:
		_cast_zones()
		_set_step("cast")


## A shockwave here: jump it or be out of it.
func _slam_at(at: Vector3, radius: float) -> void:
	Sfx.play_at("quake", at, 4.0, 0.8)
	_marks.shockwave(at, radius)
	HitFx.burst(get_parent(), at + Vector3.UP * 0.2, Vector3.UP, Color(0.35, 0.3, 0.25), 30, 5.0, false, 0.1)
	var flat := player.global_position - at
	flat.y = 0.0
	player.shake(0.12 if flat.length() < radius * 2.0 else 0.04)
	if flat.length() <= radius:
		player.receive_attack(attack_damage * SLAM_DAMAGE * damage_multiplier, at, "quake", self)


## The edge point of its arena farthest from you (where it casts from).
func _far_edge() -> Vector3:
	var best := arena_center
	var best_distance := -1.0
	var reach := minf(arena_limit, 9.0)
	for i in 8:
		var a := i * TAU / 8.0
		var spot := arena_center + Vector3(clampf(cos(a) * 1.5, -1.0, 1.0), 0, clampf(sin(a) * 1.5, -1.0, 1.0)) * reach
		var distance := spot.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best = spot
	best.y = global_position.y
	return best


func _clamp_to_arena(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena_center.x - arena_limit, arena_center.x + arena_limit), global_position.y,
			clampf(point.z, arena_center.z - arena_limit, arena_center.z + arena_limit))


func _begin_charge(windup_scale_now := 1.0) -> void:
	_set_step("aim")
	_locked = false
	_step_time = CHARGE_WINDUP * (1.0 - windup_scale_now)
	_aim_charge()


## Points the lane at you, to the edge of its arena (or DASH_REACH for a dash).
func _aim_charge() -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_charge_dir = to_player.normalized()
	var reach := DASH_REACH if _special == "dash" else INF
	for axis in [0, 2]:
		var d: float = _charge_dir[axis]
		if absf(d) < 0.001:
			continue
		var wall: float = arena_center[axis] + arena_limit * signf(d)
		reach = minf(reach, (wall - global_position[axis]) / d)
	reach = maxf(reach, 1.0)
	_charge_end = global_position + _charge_dir * reach
	_marks.show_lane(global_position, _charge_end, CHARGE_WIDTH)


## The shriek's cone (drawn as a wide lane) toward you.
func _aim_scream() -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_charge_dir = to_player.normalized()
	_charge_end = global_position + _charge_dir * SCREAM_REACH
	_marks.show_lane(global_position, _charge_end, SCREAM_WIDTH, Color(0.6, 0.85, 1.0))


func _shriek() -> void:
	Sfx.play_at("growl", global_position + Vector3.UP * 1.6, 6.0, 1.8)
	HitFx.burst(get_parent(), global_position + Vector3.UP * 1.6 + _charge_dir, _charge_dir, Color(0.7, 0.9, 1.0), 30, 9.0, true, 0.06)
	var offset := player.global_position - global_position
	offset.y = 0.0
	var along := offset.dot(_charge_dir)
	var across := absf(offset.cross(_charge_dir).y)
	player.shake(0.06)
	if along >= -0.3 and along <= SCREAM_REACH and across <= SCREAM_WIDTH * 0.5 + 0.2:
		player.receive_attack(attack_damage * SCREAM_DAMAGE * damage_multiplier, global_position, "scream", self)


func _check_charge_hit() -> void:
	if _charge_hit:
		return
	var flat := player.global_position - global_position
	flat.y = 0.0
	if flat.length() < 0.6 + CHARGE_WIDTH * 0.5:
		_charge_hit = true
		var result := player.receive_attack(attack_damage * CHARGE_DAMAGE * damage_multiplier, global_position, "charge", self)
		if result == "hit":
			player.shake(0.15)


func _cast_zones() -> void:
	_flash_tell(_special_tint(), 2.6)
	var poison := _special == "miasma"
	Sfx.play_at("draw" if poison else "fire", global_position, 2.0, 0.8 if poison else 1.1)
	var spots: Array[Vector3] = [_clamp_to_arena(player.global_position)]
	var count := 3 if poison else _zone_count()
	var tries := 0
	while spots.size() < count and tries < 60:
		tries += 1
		var spot: Vector3
		if poison:
			# Vials land around you, boxing you in.
			var a := randf() * TAU
			spot = _clamp_to_arena(player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 2.6))
		else:
			var reach := minf(arena_limit, 9.0)
			spot = arena_center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * reach
			spot.y = global_position.y
		var clear := true
		for other in spots:
			if other.distance_to(spot) < Telegraphs.ZONE_RADIUS * 1.6:
				clear = false
		if clear:
			spots.append(spot)
	var damage := attack_damage * damage_multiplier
	for i in spots.size():
		# The one under you goes off last, so there's time to read it.
		var fuse := ZONE_FUSE + (0.25 if i == 0 else 0.0) + (0.15 * i if not poison else 0.0)
		if poison:
			_marks.spawn_zone(spots[i], fuse, damage * ZONE_DAMAGE * 0.7, Telegraphs.POISON, Telegraphs.ZONE_RADIUS, MIASMA_LINGER, damage * MIASMA_TICK)
		else:
			_marks.spawn_zone(spots[i], fuse, damage * ZONE_DAMAGE)


func _clear_specials() -> void:
	if _marks:
		_marks.clear()
	_special = ""
	_step = ""


## Leans into the special's moves (call after the normal animation).
func _animate_special(delta: float) -> void:
	var lean := 0.0
	match _step:
		"howl":
			lean = -0.25
		"crouch", "raise":
			lean = 0.25 if _step == "crouch" else -0.2
		"air", "cast":
			lean = -0.15
		"aim":
			lean = 0.3
		"dash":
			lean = 0.45
		"dazed":
			lean = -0.12
			_body.rotation.z = sin(Time.get_ticks_msec() * 0.009) * 0.14
	_body.rotation.x = lerpf(_body.rotation.x, lean, minf(1.0, 12.0 * delta))
