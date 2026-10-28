class_name BossRig
extends Node3D
## A boss's skeleton: the playground Character Lab's 29-joint rig and its
## procedural clips (stance, walk / strafe / run cycles, punches, slips,
## hits, jumps), with the boss's own block parts on the bones (put()). The
## boss's AI drives it (Boss, Lich): footwork into the walk cycle, each
## punch as a load pose held through the windup and then the punch clip,
## timed to land on the strike, slips, flinches, staggers and specials.
## Bones hang along -Y at rest; +x pitch swings a limb forward (-Z).
##
## Boss clips on top of the lab's: load (a punch held at full windup), slam
## (two-handed overhead smash), sweep (a huge flat arm swing), brace (the
## shoulder lowered for a charge), cast, staff (a caster's staff raised),
## toss (overhand throw), inject (needle to the neck), dazed, limp (dead).
##
## Profile: lengths in the boss's own units (foot, lower_leg, upper_leg,
## hip, torso_h, shoulder, upper_arm, forearm, head) plus guard (how tight
## the guard is, 1 normal), style (heavy, sway, float, hunch, proud,
## lumber, caster) and southpaw (stance mirrored).

const DURATIONS := {
	"jab_left": 0.28, "jab_right": 0.28, "cross_left": 0.34, "cross_right": 0.34,
	"hook_left": 0.5, "hook_right": 0.5, "uppercut_left": 0.62, "uppercut_right": 0.62,
	"slip_left": 0.5, "slip_right": 0.5, "jump_start": 0.34, "land": 0.4,
	"hit_front_light": 0.42, "hit_left_light": 0.42, "hit_right_light": 0.42, "hit_front_heavy": 0.72,
}

var profile: Dictionary = {}
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _parent: Dictionary = {}
var _clock := 0.0
var _action := ""
var _action_time := 0.0
var _action_duration := 1.0
var _command: Dictionary = {}
var _move_local := Vector3.ZERO
var _move_amount := 0.0
var _on_floor := true
var _airborne_time := 0.0


func build(shape: Dictionary) -> void:
	profile = shape
	var foot_h: float = (profile.foot as Vector3).y
	var torso_h: float = profile.torso_h
	var root := _bone("root", self, Vector3.ZERO)
	var pelvis := _bone("pelvis", root, Vector3(0, foot_h + float(profile.lower_leg) + float(profile.upper_leg), 0))
	var spine := _bone("spine", pelvis, Vector3(0, 0.08, 0))
	var chest := _bone("chest", spine, Vector3(0, torso_h * 0.48, 0))
	var neck := _bone("neck", chest, Vector3(0, torso_h * 0.48, 0))
	_bone("head", neck, Vector3(0, -(profile.head as Vector3).y * 0.2, 0))
	_bone("sash", pelvis, Vector3.ZERO)
	_bone("cape", chest, Vector3(0, torso_h * 0.4, 0))
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var clavicle := _bone("clavicle" + s, chest, Vector3(side * float(profile.shoulder) * 0.5, torso_h * 0.08, 0))
		var upper := _bone("upper_arm" + s, clavicle, Vector3.ZERO)
		var fore := _bone("forearm" + s, upper, Vector3(0, -float(profile.upper_arm), 0))
		var wrist := _bone("wrist" + s, fore, Vector3(0, -float(profile.forearm), 0))
		_bone("hand" + s, wrist, Vector3.ZERO)
		var thigh := _bone("thigh" + s, pelvis, Vector3(side * float(profile.hip) * 0.5, 0, 0))
		var shin := _bone("shin" + s, thigh, Vector3(0, -float(profile.upper_leg), 0))
		var ankle := _bone("ankle" + s, shin, Vector3(0, -float(profile.lower_leg), 0))
		_bone("foot" + s, ankle, Vector3.ZERO)


func bone(bone_name: String) -> Node3D:
	return _bones[bone_name]


## Where a bone sits at rest, from the rig.
func rest_origin(bone_name: String) -> Vector3:
	var at := Vector3.ZERO
	var at_bone := bone_name
	while at_bone != "":
		at += (_rest[at_bone] as Transform3D).origin
		at_bone = _parent[at_bone]
	return at


## A part on a bone, placed where it sits on the standing body.
func put(enemy: Enemy, bone_name: String, mesh: PrimitiveMesh, material: Material, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return enemy._part(_bones[bone_name], mesh, material, at - rest_origin(bone_name), rot)


## Moving at this world velocity, facing this way: walk, strafe, run, air.
func set_motion(world_velocity: Vector3, facing_basis: Basis, grounded: bool) -> void:
	_move_local = facing_basis.inverse() * world_velocity
	_move_amount = clampf(Vector2(_move_local.x, _move_local.z).length() / 8.0, 0.0, 1.0)
	_on_floor = grounded
	if grounded:
		_airborne_time = 0.0


## Plays a clip over the stance: punches by name and hand (jab, cross,
## hook, uppercut; landing at impact, a share of the clip), the boss clips,
## and the lab's slips, hits, jump_start and land. seek starts it partway.
func play(action: String, duration := 0.0, hand := "", impact := 0.5, seek := 0.0) -> void:
	if action in ["jab", "cross", "hook", "uppercut"]:
		action += "_" + (hand if hand != "" else ("left" if action == "jab" else "right"))
	_action = action
	_command = {"hand": hand, "impact": impact}
	_action_duration = maxf(0.05, duration if duration > 0.0 else float(DURATIONS.get(action, 0.6)))
	_action_time = clampf(seek, 0.0, _action_duration * 0.999)


func stop() -> void:
	_action = ""


func current_action() -> String:
	return _action


func advance(delta: float) -> void:
	_clock += delta
	if not _on_floor:
		_airborne_time += delta
	if _action != "":
		_action_time += delta
		if _action_time >= _action_duration:
			_action = ""
	_apply_pose()


func _bone(bone_name: String, parent: Node, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = bone_name.to_pascal_case()
	joint.position = at
	parent.add_child(joint)
	_bones[bone_name] = joint
	_rest[bone_name] = joint.transform
	_parent[bone_name] ="" if parent == self else String(_bones.find_key(parent))
	return joint


func _apply_pose() -> void:
	for bone_name in _bones:
		(_bones[bone_name] as Node3D).transform = _rest[bone_name]
	var u := clampf(_action_time / maxf(_action_duration, 0.001), 0.0, 1.0)
	_pose_locomotion()
	if profile.get("style", "") == "caster":
		_pose_caster()
	else:
		_pose_boxing_stance()
		_pose_guard()
	_pose_style()
	if _action != "":
		_pose_action(_action, u)
	_pose_secondary()


# --- The Character Lab's clips ------------------------------------------------------

func _pose_locomotion() -> void:
	var moving := _move_amount
	var pace := lerpf(5.5, 10.0, moving) * float(profile.get("pace", 1.0))
	var forward_weight := absf(_move_local.z) / maxf(absf(_move_local.x) + absf(_move_local.z), 0.001)
	var travel_sign := -signf(_move_local.z) if absf(_move_local.z) > 0.05 else 1.0
	var stride := sin(_clock * pace) * moving * travel_sign
	var lift := maxf(0.0, sin(_clock * pace * 2.0)) * moving
	if not _on_floor:
		if _move_local.y > 0.0:
			var takeoff := clampf(_airborne_time / 0.34, 0.0, 1.0)
			var extension := smoothstep(0.24, 0.9, takeoff)
			for leg in ["thigh_l", "thigh_r"]:
				_set_rot(leg, Vector3(-0.1, 0, 0), extension)
			for leg in ["shin_l", "shin_r"]:
				_set_rot(leg, Vector3(0.06, 0, 0), extension)
		else:
			# Tucked for the drop.
			_add_rot("thigh_l", Vector3(0.55, 0, 0))
			_add_rot("thigh_r", Vector3(0.2, 0, 0))
			_add_rot("shin_l", Vector3(-0.75, 0, 0))
			_add_rot("shin_r", Vector3(-0.4, 0, 0))
		return
	_add_rot("thigh_l", Vector3(stride * 0.65, 0, 0))
	_add_rot("thigh_r", Vector3(-stride * 0.65, 0, 0))
	_add_rot("shin_l", Vector3(-maxf(0.0, -stride) * 0.72, 0, 0))
	_add_rot("shin_r", Vector3(-maxf(0.0, stride) * 0.72, 0, 0))
	var strafe := clampf(_move_local.x / 8.0, -1.0, 1.0) * (1.0 - forward_weight)
	_add_pos("pelvis", Vector3(strafe * sin(_clock * pace) * 0.03, lift * 0.025 + absf(sin(_clock * 2.0)) * 0.003, 0))
	_add_rot("chest", Vector3(0, stride * 0.08, -stride * 0.025 - strafe * 0.08))


func _pose_boxing_stance() -> void:
	if not _on_floor:
		return
	# Orthodox: left foot leads (a southpaw mirrors it).
	var weight := lerpf(1.0, 0.22, _move_amount)
	var m := -1.0 if profile.get("southpaw", false) else 1.0
	var lead := "_r" if m < 0.0 else "_l"
	var rear := "_l" if m < 0.0 else "_r"
	_add_rot("pelvis", Vector3(0.0, -0.14 * m, 0.0) * weight)
	_add_rot("chest", Vector3(0.0, 0.08 * m, -0.025 * m) * weight)
	_add_rot("thigh" + lead, Vector3(0.14, -0.035 * m, -0.055 * m) * weight)
	_add_rot("shin" + lead, Vector3(-0.16, 0.0, 0.025 * m) * weight)
	_add_rot("foot" + lead, Vector3(0.0, -0.12 * m, 0.0) * weight)
	_add_rot("thigh" + rear, Vector3(-0.085, 0.045 * m, 0.06 * m) * weight)
	_add_rot("shin" + rear, Vector3(-0.11, 0.0, -0.025 * m) * weight)
	_add_rot("foot" + rear, Vector3(0.0, 0.18 * m, 0.0) * weight)


func _pose_guard() -> void:
	var tight: float = profile.get("guard", 1.0)
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_add_rot("clavicle" + s, Vector3(0, 0, -side * 0.08 * tight))
		_add_rot("upper_arm" + s, Vector3(0.62 + (tight - 1.0) * 0.18, -side * 0.12, side * 0.18 * tight))
		_add_rot("forearm" + s, Vector3(2.05 + (tight - 1.0) * 0.45, side * 0.08, -side * 0.12))
		_add_rot("wrist" + s, Vector3(-0.12, 0, side * 0.08))


## Not a boxer: the staff hand forward, the other open at the side.
func _pose_caster() -> void:
	_add_rot("upper_arm_r", Vector3(0.45, 0.1, 0.12))
	_add_rot("forearm_r", Vector3(0.9, 0, 0))
	_add_rot("upper_arm_l", Vector3(0.3, 0.1, -0.25))
	_add_rot("forearm_l", Vector3(0.5, 0, 0))


func _pose_style() -> void:
	var breathe := sin(_clock * 2.1)
	match profile.get("style", ""):
		"heavy":
			_add_rot("chest", Vector3(-0.08 + breathe * 0.015, 0, 0))
			_add_rot("pelvis", Vector3(0.04, 0, 0))
		"lumber":
			_add_rot("chest", Vector3(-0.14 + breathe * 0.02, 0, 0))
			_add_rot("head", Vector3(0.1, 0, 0))
			_add_rot("pelvis", Vector3(0.06, 0, 0))
		"sway":
			_add_rot("chest", Vector3(0, sin(_clock * 0.9) * 0.03, 0))
			_add_rot("head", Vector3(0, 0, sin(_clock * 1.8) * 0.03))
		"float":
			_add_pos("pelvis", Vector3(0, sin(_clock * 2.2) * 0.02, 0))
			_add_rot("chest", Vector3(0.04, sin(_clock * 1.3) * 0.04, sin(_clock * 1.1) * 0.03))
		"hunch":
			_add_rot("chest", Vector3(-0.16, 0.04, -0.045))
			_add_rot("head", Vector3(0.08, -0.08, 0.03))
		"proud":
			_add_rot("chest", Vector3(0.06 + breathe * 0.012, 0, 0))
			_add_rot("head", Vector3(0.1, 0, 0))
		"caster":
			_add_rot("chest", Vector3(-0.06 + breathe * 0.012, 0, 0))
			_add_rot("head", Vector3(0.05, 0, 0))


func _pose_action(action: String, u: float) -> void:
	if action.begins_with("jab_") or action.begins_with("cross_"):
		_pose_straight(action, u)
	elif action.begins_with("hook_"):
		_pose_hook(action, u)
	elif action.begins_with("uppercut_"):
		_pose_uppercut(action, u)
	elif action.begins_with("slip_"):
		_pose_slip(-1.0 if action.ends_with("left") else 1.0, sin(u * PI))
	elif action.begins_with("hit_"):
		_pose_hit(action, u)
	else:
		_pose_boss(action, u)


func _pose_straight(action: String, u: float) -> void:
	var side := -1.0 if action.ends_with("left") else 1.0
	var s := "_l" if side < 0.0 else "_r"
	var impact := float(_command.get("impact", 0.4))
	var strike := _attack_curve(u, impact)
	var wind := _windup_curve(u, impact)
	_set_rot("upper_arm" + s, Vector3(1.47, -side * 0.04, side * 0.08), strike)
	_set_rot("forearm" + s, Vector3(0.08, side * 0.02, 0), strike)
	_add_rot("upper_arm" + s, Vector3(-0.18, side * 0.13, side * 0.12) * wind)
	_add_rot("chest", Vector3(0, -side * (0.22 if action.begins_with("cross") else 0.1) * strike, side * 0.04 * strike))
	_add_rot("pelvis", Vector3(0, side * 0.08 * strike, 0))
	_add_pos("pelvis", Vector3(0.0, 0.0, 0.025 * wind - 0.035 * strike))


func _pose_hook(action: String, u: float) -> void:
	var side := -1.0 if action.ends_with("left") else 1.0
	var s := "_l" if side < 0.0 else "_r"
	var wind := _phase_pulse(u, 0.0, 0.18, 0.36)
	var open := _phase_pulse(u, 0.18, 0.31, 0.48)
	var strike := _delayed_attack_curve(u, 0.31, 0.54)
	_add_rot("upper_arm" + s, Vector3(-0.10, side * 0.20, -side * 0.08) * wind)
	_add_rot("forearm" + s, Vector3(0.08, -side * 0.06, side * 0.05) * wind)
	_set_rot("upper_arm" + s, Vector3(0.96, -side * 0.22, side * 0.62), open)
	_set_rot("forearm" + s, Vector3(1.34, side * 0.06, side * 0.06), open)
	_set_rot("upper_arm" + s, Vector3(1.12, -side * 0.28, -side * 0.55), strike)
	_set_rot("forearm" + s, Vector3(1.10, side * 0.12, -side * 0.36), strike)
	_add_rot("wrist" + s, Vector3(0.0, -side * 0.12 * strike, -side * 0.08 * strike))
	_add_rot("chest", Vector3(-0.04 * strike, side * 0.16 * wind - side * 0.34 * strike, side * 0.08 * strike))
	_add_rot("pelvis", Vector3(0.0, side * 0.10 * wind - side * 0.18 * strike, 0.0))
	_add_pos("pelvis", Vector3(side * 0.025 * strike, 0.0, 0.035 * wind - 0.05 * strike))


func _pose_uppercut(action: String, u: float) -> void:
	var side := -1.0 if action.ends_with("left") else 1.0
	var s := "_l" if side < 0.0 else "_r"
	var wind := _phase_pulse(u, 0.0, 0.20, 0.42)
	var strike := _delayed_attack_curve(u, 0.27, 0.57)
	_add_rot("upper_arm" + s, Vector3(-0.24, side * 0.10, -side * 0.13) * wind)
	_add_rot("forearm" + s, Vector3(-0.30, 0.0, side * 0.08) * wind)
	_add_pos("head", Vector3(side * 0.06, -0.05, -0.025) * wind)
	_add_rot("head", Vector3(-0.06 * wind, -side * 0.05 * wind, -side * 0.12 * wind))
	_add_rot("chest", Vector3(-0.20 * wind + 0.12 * strike, -side * 0.16 * wind - side * 0.20 * strike, -side * 0.25 * wind + side * 0.08 * strike))
	_add_rot("spine", Vector3(-0.14 * wind + 0.10 * strike, 0.0, -side * 0.12 * wind))
	_add_rot("pelvis", Vector3(0.0, -side * 0.14 * wind + side * 0.22 * strike, -side * 0.05 * wind))
	_add_pos("pelvis", Vector3(side * 0.03 * wind, 0.0, 0.04 * wind - 0.045 * strike))
	for leg in ["thigh_l", "thigh_r"]:
		_add_rot(leg, Vector3(0.18 * wind - 0.08 * strike, 0.0, 0.0))
	for leg in ["shin_l", "shin_r"]:
		_add_rot(leg, Vector3(-0.30 * wind + 0.12 * strike, 0.0, 0.0))
	_set_rot("upper_arm" + s, Vector3(1.52, -side * 0.10, side * 0.08), strike)
	_set_rot("forearm" + s, Vector3(0.26, 0.0, -side * 0.12), strike)
	_add_rot("wrist" + s, Vector3(0.16 * strike, 0.0, -side * 0.08 * strike))


## Head and upper back lead forward and down, the same-side shoulder turns
## through, the hips stay underneath.
func _pose_slip(side: float, pulse: float) -> void:
	_add_pos("head", Vector3(side * 0.085, -0.045, -0.065) * pulse)
	_add_pos("pelvis", Vector3(side * 0.035, 0.0, -0.015) * pulse)
	_add_rot("spine", Vector3(-0.08, side * 0.16, side * 0.08) * pulse)
	_add_rot("chest", Vector3(-0.12, side * 0.30, side * 0.19) * pulse)
	_add_rot("head", Vector3(-0.06, -side * 0.13, -side * 0.12) * pulse)
	_add_rot("clavicle_l" if side < 0.0 else "clavicle_r", Vector3(0.05, side * 0.08, -side * 0.09) * pulse)


func _pose_hit(action: String, u: float) -> void:
	var pulse := sin(u * PI)
	var heavy := 1.55 if action.ends_with("_heavy") else 1.0
	var side := -1.0 if action.begins_with("hit_left") else (1.0 if action.begins_with("hit_right") else 0.0)
	_add_pos("pelvis", Vector3(-side * 0.11, 0, 0.12) * pulse * heavy)
	_add_rot("chest", Vector3(0.34, -side * 0.48, side * 0.22) * pulse * heavy)
	_add_rot("head", Vector3(0.22, -side * 0.36, side * 0.28) * pulse * heavy)
	_add_rot("upper_arm_l", Vector3(-0.28, 0, -0.28) * pulse * heavy)
	_add_rot("upper_arm_r", Vector3(-0.28, 0, 0.28) * pulse * heavy)


# --- Boss clips ---------------------------------------------------------------------

func _pose_boss(action: String, u: float) -> void:
	var side := -1.0 if String(_command.get("hand", "")) == "left" else 1.0
	match action:
		"jump_start":
			# Down through both knees, then straightening into the takeoff.
			var crouch := _phase_pulse(u, 0.0, 0.5, 1.2)
			_add_pos("pelvis", Vector3(0, -0.08 * crouch, 0))
			_add_rot("chest", Vector3(-0.2 * crouch, 0, 0))
			for s in ["_l", "_r"]:
				_add_rot("thigh" + s, Vector3(0.6 * crouch, 0, 0))
				_add_rot("shin" + s, Vector3(-1.05 * crouch, 0, 0))
				_add_rot("upper_arm" + s, Vector3(-0.5 * crouch, 0, 0))
		"land":
			var give := sin(u * PI)
			_add_pos("pelvis", Vector3(0, -0.06 * give, 0.05 * give))
			_add_rot("chest", Vector3(-0.25 * give, 0, 0))
			for s in ["_l", "_r"]:
				_add_rot("thigh" + s, Vector3(0.62 * give, 0, 0))
				_add_rot("shin" + s, Vector3(-1.0 * give, 0, 0))
		"load":
			_pose_load(side, smoothstep(0.0, 0.6, u))
		"slam_load":
			_pose_slam(smoothstep(0.0, 0.7, u), 0.0)
		"slam":
			var impact := float(_command.get("impact", 0.5))
			_pose_slam(1.0 - smoothstep(0.0, impact, u), smoothstep(0.0, impact, u) * (1.0 - smoothstep(impact, 1.0, u) * 0.6))
		"sweep_load":
			_pose_sweep(side, smoothstep(0.0, 0.6, u), 0.0)
		"sweep":
			var impact := float(_command.get("impact", 0.5))
			var swing := smoothstep(0.0, impact, u)
			_pose_sweep(side, 1.0 - swing, swing * (1.0 - smoothstep(impact, 1.0, u) * 0.7))
		"brace":
			# Shoulder down, head tucked, fists low in front: a charge.
			var w := smoothstep(0.0, 0.35, u)
			_add_rot("spine", Vector3(-0.22 * w, 0, 0))
			_add_rot("chest", Vector3(-0.28 * w, 0.3 * w, 0))
			_add_rot("head", Vector3(0.2 * w, 0, 0))
			_add_pos("pelvis", Vector3(0, -0.05 * w, 0))
			for s in ["_l", "_r"]:
				_add_rot("thigh" + s, Vector3(0.35 * w, 0, 0))
				_add_rot("shin" + s, Vector3(-0.55 * w, 0, 0))
				_set_rot("upper_arm" + s, Vector3(0.7, 0, 0), w)
				_set_rot("forearm" + s, Vector3(1.0, 0, 0), w)
		"cast":
			var w := sin(u * PI)
			for s2: float in [-1.0, 1.0]:
				var s := "_l" if s2 < 0.0 else "_r"
				_set_rot("upper_arm" + s, Vector3(2.6, 0, s2 * 0.35), w)
				_set_rot("forearm" + s, Vector3(0.3, 0, 0), w)
			_add_rot("chest", Vector3(0.18 * w, 0, 0))
			_add_rot("head", Vector3(0.25 * w, 0, 0))
		"staff":
			# The staff raised high, the free hand thrust out: held till cast.
			var w := smoothstep(0.0, 0.3, u)
			_set_rot("upper_arm_r", Vector3(2.5, 0.1, 0.25), w)
			_set_rot("forearm_r", Vector3(0.4, 0, 0), w)
			# The wrist turns back, so the staff stays upright.
			_set_rot("wrist_r", Vector3(-1.5, 0, 0), w)
			_set_rot("upper_arm_l", Vector3(1.45, -0.15, -0.1), w)
			_set_rot("forearm_l", Vector3(0.1, 0, 0), w)
			_add_rot("chest", Vector3(0.12 * w, -0.15 * w, 0))
			_add_rot("head", Vector3(0.1 * w, 0, 0))
		"toss_load":
			# Reaching up and back with the throwing hand, leaning away.
			var w := smoothstep(0.0, 0.5, u)
			_set_rot("upper_arm_r", Vector3(2.7, 0.0, 0.3), w)
			_set_rot("forearm_r", Vector3(1.2, 0, 0), w)
			_add_rot("chest", Vector3(0.22 * w, -0.35 * w, 0))
			_add_rot("spine", Vector3(0.1 * w, 0, 0))
			_set_rot("upper_arm_l", Vector3(1.2, 0.2, -0.1), w)
		"toss":
			var w := 1.0 - smoothstep(0.0, 0.4, u)
			var throw := _attack_curve(u, 0.3)
			_set_rot("upper_arm_r", Vector3(2.7, 0.0, 0.3), w)
			_set_rot("forearm_r", Vector3(1.2, 0, 0), w)
			_set_rot("upper_arm_r", Vector3(1.3, 0.25, 0.1), throw)
			_set_rot("forearm_r", Vector3(0.1, 0, 0), throw)
			_add_rot("chest", Vector3(-0.2 * throw, 0.3 * throw, 0))
		"inject":
			# Head back, the needle into the neck, the other arm flung out.
			var w := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.85, 1.0, u))
			_set_rot("upper_arm_r", Vector3(1.4, 0.55, -0.25), w)
			_set_rot("forearm_r", Vector3(2.3, 0, 0), w)
			_set_rot("upper_arm_l", Vector3(0.5, -0.4, -0.9), w)
			_set_rot("forearm_l", Vector3(0.3, 0, 0), w)
			_add_rot("chest", Vector3(0.2 * w, 0, 0))
			_add_rot("head", Vector3(0.45 * w, 0, -0.25 * w))
		"dazed":
			var sway := sin(u * TAU * 2.0)
			_add_rot("chest", Vector3(0.3, sway * 0.12, sway * 0.18))
			_add_rot("head", Vector3(0.25, -sway * 0.2, sway * 0.15))
			_add_rot("upper_arm_l", Vector3(-0.55, 0, -0.35))
			_add_rot("upper_arm_r", Vector3(-0.55, 0, 0.35))
			_add_rot("forearm_l", Vector3(-1.2, 0, 0))
			_add_rot("forearm_r", Vector3(-1.2, 0, 0))
			for s in ["_l", "_r"]:
				_add_rot("thigh" + s, Vector3(0.2, 0, 0))
				_add_rot("shin" + s, Vector3(-0.35, 0, 0))
		"limp":
			var w := smoothstep(0.0, 0.08, u)
			for s2: float in [-1.0, 1.0]:
				var s := "_l" if s2 < 0.0 else "_r"
				_set_rot("upper_arm" + s, Vector3(-0.3, 0, s2 * 0.5), w)
				_set_rot("forearm" + s, Vector3(0.2, 0, 0), w)
			_add_rot("head", Vector3(0.5 * w, 0, 0))
			_add_rot("chest", Vector3(0.2 * w, 0, 0))


## A punch held at full windup: the shoulder coils on that side, the fist
## draws back, the weight sits back.
func _pose_load(side: float, w: float) -> void:
	var s := "_l" if side < 0.0 else "_r"
	_add_rot("chest", Vector3(0.04, side * 0.3, 0) * w)
	_add_rot("pelvis", Vector3(0, side * 0.12, 0) * w)
	_add_rot("upper_arm" + s, Vector3(-0.3, side * 0.18, side * 0.2) * w)
	_add_rot("forearm" + s, Vector3(0.25, 0, 0) * w)
	_add_pos("pelvis", Vector3(0, 0, 0.04) * w)


## Two-handed overhead smash: raise (1 = both fists high over the head),
## then smash (1 = fists down in front, bent at the waist).
func _pose_slam(raise: float, smash: float) -> void:
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_set_rot("upper_arm" + s, Vector3(2.9, side * 0.1, side * 0.25), raise)
		_set_rot("forearm" + s, Vector3(0.6, 0, 0), raise)
		_set_rot("upper_arm" + s, Vector3(1.1, -side * 0.1, side * 0.1), smash)
		_set_rot("forearm" + s, Vector3(0.2, 0, 0), smash)
	_add_rot("chest", Vector3(0.22 * raise - 0.45 * smash, 0, 0))
	_add_rot("spine", Vector3(0.08 * raise - 0.2 * smash, 0, 0))
	_add_pos("pelvis", Vector3(0, -0.06 * smash, -0.04 * smash))
	for s in ["_l", "_r"]:
		_add_rot("thigh" + s, Vector3(0.4 * smash, 0, 0))
		_add_rot("shin" + s, Vector3(-0.6 * smash, 0, 0))


## A huge flat swing of one arm: wound (1 = straight out wide and back, the
## chest turned away), then swung (1 = across the front, chest turned in).
func _pose_sweep(side: float, wound: float, swung: float) -> void:
	var s := "_l" if side < 0.0 else "_r"
	_set_rot("upper_arm" + s, Vector3(0.9, 0, side * 1.35), wound)
	_set_rot("forearm" + s, Vector3(0.15, 0, 0), wound)
	_set_rot("upper_arm" + s, Vector3(1.45, side * 0.9, 0), swung)
	_set_rot("forearm" + s, Vector3(0.2, 0, 0), swung)
	_add_rot("chest", Vector3(0, -side * 0.4 * wound + side * 0.45 * swung, 0))
	_add_rot("pelvis", Vector3(0, -side * 0.15 * wound + side * 0.2 * swung, 0))
	_add_pos("pelvis", Vector3(0, -0.04 * swung, 0))


func _pose_secondary() -> void:
	var sway := sin(_clock * 3.0) * (0.03 + _move_amount * 0.1)
	_add_rot("sash", Vector3(sway, 0, sway * 0.35))
	_add_rot("cape", Vector3(-absf(sway) * 0.6 - _move_amount * 0.25, 0, sway * 0.3))


func _set_rot(bone_name: String, target: Vector3, weight: float) -> void:
	var node: Node3D = _bones[bone_name]
	var rest_rot: Vector3 = (_rest[bone_name] as Transform3D).basis.get_euler()
	node.rotation = node.rotation.lerp(rest_rot + target, clampf(weight, 0.0, 1.0))


func _add_rot(bone_name: String, amount: Vector3) -> void:
	(_bones[bone_name] as Node3D).rotation += amount


func _add_pos(bone_name: String, amount: Vector3) -> void:
	(_bones[bone_name] as Node3D).position += amount


func _attack_curve(u: float, impact: float) -> float:
	if u <= impact:
		return smoothstep(0.0, 1.0, u / maxf(impact, 0.01))
	return 1.0 - smoothstep(0.0, 1.0, (u - impact) / maxf(1.0 - impact, 0.01))


func _delayed_attack_curve(u: float, start: float, impact: float) -> float:
	if u <= start:
		return 0.0
	if u <= impact:
		return smoothstep(0.0, 1.0, (u - start) / maxf(impact - start, 0.001))
	return 1.0 - smoothstep(0.0, 1.0, (u - impact) / maxf(1.0 - impact, 0.001))


func _windup_curve(u: float, impact: float) -> float:
	var end := impact * 0.42
	if u <= end:
		return smoothstep(0.0, 1.0, u / maxf(end, 0.01))
	if u <= impact:
		return 1.0 - smoothstep(0.0, 1.0, (u - end) / maxf(impact - end, 0.01))
	return 0.0


func _phase_pulse(u: float, start: float, peak: float, finish: float) -> float:
	if u <= start or u >= finish:
		return 0.0
	if u <= peak:
		return smoothstep(0.0, 1.0, (u - start) / maxf(peak - start, 0.001))
	return 1.0 - smoothstep(0.0, 1.0, (u - peak) / maxf(finish - peak, 0.001))
