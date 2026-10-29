class_name PlaygroundFighterAvatar
extends Node3D
## Playground animation adapter for the production PlayerBody.  The semantic
## hierarchy below drives the boxing animation system; all visible character
## geometry is the exact small-voxel body used by the actual game.

signal action_started(action: String, command: Dictionary)
signal action_finished(action: String)
signal effect_marker(marker: String, action: String, command: Dictionary)

const SkinsData = preload("res://skins.gd")
const FistsData = preload("res://fists.gd")
const PlayerBodyScript = preload("res://player_body.gd")
const BODY_LAYER := 1 << 9
const ELLIPSOID_RADIAL := 32
const ELLIPSOID_RINGS := 18
const TAPER_RADIAL := 24
const FIGHTERS := ["berserker", "counter_master", "combo_master", "free_runner", "wise_guy", "elementalist"]
const ACTIONS := [
	"idle", "guard", "walk", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "run",
	"jump", "jump_start", "airborne", "fall", "land", "turn_left", "turn_right", "guard_raise", "guard_lower",
	"jab_left", "cross_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right",
	"block", "slip_left", "slip_right", "roll_left", "roll_right", "back_step", "guard_break",
	"hit_front_light", "hit_front_heavy", "hit_left_light", "hit_left_heavy",
	"hit_right_light", "hit_right_heavy", "hit_back_light", "hit_back_heavy",
	"knockdown_front", "knockdown_back", "knockdown_left", "knockdown_right",
	"grounded_face_up", "grounded_face_down", "get_up", "get_up_face_up", "get_up_face_down",
	"ultimate_1", "ultimate_2", "taunt",
]

const DURATIONS := {
	"idle": 1.0, "guard": 1.0, "walk": 0.8, "walk_forward": 0.8, "walk_backward": 0.9,
	"strafe_left": 0.82, "strafe_right": 0.82, "run": 0.62, "jump": 0.9,
	"jump_start": 0.34, "airborne": 0.8, "fall": 0.8, "land": 0.4,
	"turn_left": 0.55, "turn_right": 0.55, "guard_raise": 0.38, "guard_lower": 0.38,
	"jab_left": 0.28, "cross_right": 0.34, "hook_left": 0.5, "hook_right": 0.5,
	"uppercut_left": 0.62, "uppercut_right": 0.62,
	"block": 0.42, "slip_left": 0.5, "slip_right": 0.5,
	"roll_left": 0.68, "roll_right": 0.68, "back_step": 0.55, "guard_break": 0.75,
	"hit_front_light": 0.42, "hit_front_heavy": 0.72,
	"hit_left_light": 0.42, "hit_left_heavy": 0.72,
	"hit_right_light": 0.42, "hit_right_heavy": 0.72,
	"hit_back_light": 0.46, "hit_back_heavy": 0.76,
	"knockdown_front": 1.05, "knockdown_back": 1.05, "knockdown_left": 1.0,
	"knockdown_right": 1.0, "grounded_face_up": 1.0, "grounded_face_down": 1.0,
	"get_up": 1.15, "get_up_face_up": 1.15, "get_up_face_down": 1.15,
	"ultimate_1": 1.6, "ultimate_2": 1.6, "taunt": 1.4,
}

const LOCOMOTION_ACTIONS := [
	"idle", "guard", "walk", "walk_forward", "walk_backward", "strafe_left", "strafe_right", "run",
	"jump", "jump_start", "airborne", "fall", "land", "turn_left", "turn_right", "guard_raise", "guard_lower",
]

## Dimensions are intentionally bespoke. They control both the rest skeleton
## and the mesh, so fighters are still identifiable with a flat material.
const PROFILES := {
	"berserker": {
		"height": 1.98, "hip": 0.48, "shoulder": 0.98, "torso_w": 0.78, "torso_d": 0.44,
		"torso_h": 0.62, "upper_leg": 0.47, "lower_leg": 0.45, "leg_w": 0.27,
		"upper_arm": 0.39, "forearm": 0.36, "arm_w": 0.28, "glove": 0.35,
		"head": Vector3(0.36, 0.38, 0.34), "foot": Vector3(0.29, 0.16, 0.42),
	},
	"counter_master": {
		"height": 1.84, "hip": 0.42, "shoulder": 0.7, "torso_w": 0.54, "torso_d": 0.32,
		"torso_h": 0.55, "upper_leg": 0.43, "lower_leg": 0.43, "leg_w": 0.25,
		"upper_arm": 0.34, "forearm": 0.32, "arm_w": 0.175, "glove": 0.18,
		"head": Vector3(0.29, 0.33, 0.28), "foot": Vector3(0.24, 0.12, 0.36),
	},
	"combo_master": {
		"height": 1.71, "hip": 0.39, "shoulder": 0.56, "torso_w": 0.4, "torso_d": 0.26,
		"torso_h": 0.47, "upper_leg": 0.4, "lower_leg": 0.4, "leg_w": 0.24,
		"upper_arm": 0.31, "forearm": 0.29, "arm_w": 0.105, "glove": 0.13,
		"head": Vector3(0.29, 0.32, 0.28), "foot": Vector3(0.22, 0.11, 0.35),
	},
	"free_runner": {
		"height": 1.82, "hip": 0.4, "shoulder": 0.66, "torso_w": 0.49, "torso_d": 0.29,
		"torso_h": 0.52, "upper_leg": 0.44, "lower_leg": 0.44, "leg_w": 0.24,
		"upper_arm": 0.35, "forearm": 0.33, "arm_w": 0.145, "glove": 0.16,
		"head": Vector3(0.29, 0.32, 0.28), "foot": Vector3(0.23, 0.12, 0.36),
	},
	"wise_guy": {
		"height": 1.68, "hip": 0.45, "shoulder": 0.72, "torso_w": 0.62, "torso_d": 0.39,
		"torso_h": 0.5, "upper_leg": 0.37, "lower_leg": 0.38, "leg_w": 0.24,
		"upper_arm": 0.31, "forearm": 0.29, "arm_w": 0.18, "glove": 0.16,
		"head": Vector3(0.34, 0.35, 0.32), "foot": Vector3(0.25, 0.13, 0.37),
	},
	"elementalist": {
		"height": 1.92, "hip": 0.46, "shoulder": 0.9, "torso_w": 0.7, "torso_d": 0.42,
		"torso_h": 0.59, "upper_leg": 0.44, "lower_leg": 0.44, "leg_w": 0.23,
		"upper_arm": 0.38, "forearm": 0.36, "arm_w": 0.235, "glove": 0.21,
		"head": Vector3(0.35, 0.36, 0.33), "foot": Vector3(0.26, 0.15, 0.39),
	},
}

const HAIR := {
	"berserker": Color(0.07, 0.055, 0.05), "counter_master": Color(0.025, 0.025, 0.03),
	"combo_master": Color(0.1, 0.075, 0.15), "free_runner": Color(0.19, 0.105, 0.06),
	"wise_guy": Color(0.055, 0.055, 0.06), "elementalist": Color(0.64, 0.63, 0.61),
}

## Full-body reference sheets use warmer, more saturated skin than the legacy
## first-person fists. Hands still keep their production palette; this model
## palette is authored against the canonical third-person character sheets.
const MODEL_SKIN := {
	"berserker": Color(0.76, 0.39, 0.23), "counter_master": Color(0.78, 0.46, 0.28),
	"combo_master": Color(0.84, 0.52, 0.33), "free_runner": Color(0.74, 0.42, 0.25),
	"wise_guy": Color(0.82, 0.53, 0.38), "elementalist": Color(0.78, 0.46, 0.28),
}

var fighter_id := "berserker"
var skin_id := ""
var playback_speed := 1.0
var paused := false
var loop_action := false
var silhouette_only := false
var skeleton_debug_visible := false

var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _boxes: Dictionary = {}
var _profile: Dictionary = {}
var _palette: Dictionary = {}
var _skin_color := Color(0.75, 0.55, 0.42)
var _material: StandardMaterial3D
var _clock := 0.0
var _action := ""
var _action_time := 0.0
var _action_duration := 1.0
var _action_speed := 1.0
var _command: Dictionary = {}
var _emitted_markers: Dictionary = {}
var _move_local := Vector3.ZERO
var _move_amount := 0.0
var _on_floor := true
var _airborne_pose_time := 0.0
var _knocked_down := false
var _knock_direction := "back"
var _glow: OmniLight3D
var _skeleton_debug: MeshInstance3D
var _silhouette_material: StandardMaterial3D
var _production_body = null
var _production_rest: Dictionary = {}


func _init(which := "berserker", skin := "") -> void:
	fighter_id = which
	skin_id = skin


func _ready() -> void:
	rebuild(fighter_id, skin_id)
	set_process(true)


func rebuild(which: String, skin := "") -> void:
	if not which in FIGHTERS:
		which = "berserker"
	fighter_id = which
	skin_id = skin if SkinsData.CATALOG.has(skin) and String(SkinsData.CATALOG[skin].fighter) == which else ""
	_profile = PROFILES[fighter_id]
	_palette = SkinsData.palette(fighter_id, skin_id)
	_skin_color = MODEL_SKIN.get(fighter_id, FistsData.SKIN.get(fighter_id, FistsData.DEFAULT_SKIN))
	for child in get_children():
		child.free()
	_production_body = null
	_production_rest.clear()
	_bones.clear()
	_rest.clear()
	_boxes.clear()
	_build_rig()
	_build_production_body()
	_build_glow()
	_build_skeleton_debug()
	_action = ""
	_action_time = 0.0
	_action_speed = 1.0
	_emitted_markers.clear()
	_knocked_down = false
	_airborne_pose_time = 0.0
	_apply_pose()


func set_skin(id: String) -> void:
	var resolved := id if SkinsData.CATALOG.has(id) and String(SkinsData.CATALOG[id].fighter) == fighter_id else ""
	if resolved == skin_id:
		return
	# Keep the semantic rig, active command and normalized phase intact. Replace
	# only the production PlayerBody so the alternate uses the game's real voxel
	# construction and palette too.
	skin_id = resolved
	_palette = SkinsData.palette(fighter_id, skin_id)
	_build_production_body()
	if _glow:
		_glow.light_color = _color("glow", _color("accent", GameState.CLASSES[fighter_id].color))
	_apply_pose()


func set_motion(world_velocity: Vector3, facing_basis: Basis, grounded: bool) -> void:
	var was_grounded := _on_floor
	_move_local = facing_basis.inverse() * world_velocity
	_move_amount = clampf(Vector2(_move_local.x, _move_local.z).length() / 8.0, 0.0, 1.0)
	_on_floor = grounded
	if was_grounded and not grounded and _move_local.y > 0.0:
		_airborne_pose_time = 0.0
	elif grounded:
		_airborne_pose_time = 0.0


## Network-facing locomotion adapter. A remote presentation can be driven by
## compact local velocity/grounded state without knowing this node's joints.
func apply_locomotion(state: Dictionary) -> void:
	var was_grounded := _on_floor
	var local_velocity: Vector3 = state.get("local_velocity", Vector3.ZERO)
	_move_local = local_velocity
	_move_amount = clampf(float(state.get("amount", Vector2(local_velocity.x, local_velocity.z).length() / 8.0)), 0.0, 1.0)
	_on_floor = bool(state.get("grounded", true))
	if was_grounded and not _on_floor and _move_local.y > 0.0:
		_airborne_pose_time = 0.0
	elif _on_floor:
		_airborne_pose_time = 0.0
	if state.has("facing_yaw"):
		rotation.y = float(state.facing_yaw)


func play_action(command: Dictionary) -> void:
	var requested := String(command.get("action", ""))
	var hand := String(command.get("hand", ""))
	if requested in ["jab", "cross", "hook", "uppercut"]:
		if hand == "":
			hand = "left" if requested == "jab" else "right"
		requested += "_" + hand
	if requested == "hit":
		var hit_direction := String(command.get("direction", "front"))
		requested = "hit_%s_%s" % [hit_direction, "heavy" if float(command.get("severity", 0.0)) >= 0.6 else "light"]
	if requested == "knockdown":
		requested = "knockdown_" + String(command.get("direction", "back"))
	# Backwards-compatible names used by the first implementation.
	if requested in ["hit_left", "hit_right", "hit_back"]:
		requested += "_light"
	if requested not in ACTIONS:
		return
	_command = command.duplicate(true)
	_command["action"] = requested
	_action = requested
	_action_duration = maxf(0.05, float(command.get("duration", DURATIONS.get(requested, 0.8))))
	_action_speed = maxf(0.01, float(command.get("speed", 1.0)))
	var seek_seconds := maxf(0.0, float(command.get("seek", 0.0)))
	if command.has("normalized_phase"):
		seek_seconds = maxf(seek_seconds, clampf(float(command.normalized_phase), 0.0, 1.0) * _action_duration)
	if command.has("started_at"):
		var local_now := float(command.get("received_at", Time.get_ticks_msec() / 1000.0))
		seek_seconds = maxf(seek_seconds, maxf(0.0, local_now - float(command.started_at)) * _action_speed)
	_action_time = minf(seek_seconds, _action_duration * 0.999)
	_emitted_markers.clear()
	_prime_past_markers()
	if requested.begins_with("knockdown_"):
		_knock_direction = requested.trim_prefix("knockdown_")
	elif requested == "grounded_face_up":
		_knock_direction = "back"
		_knocked_down = true
	elif requested == "grounded_face_down":
		_knock_direction = "front"
		_knocked_down = true
	elif requested in ["get_up", "get_up_face_up", "get_up_face_down"]:
		if requested == "get_up_face_up": _knock_direction = "back"
		if requested == "get_up_face_down": _knock_direction = "front"
		_knocked_down = false
	action_started.emit(_action, _command)


func preview(action: String) -> void:
	var hand := "left" if action.ends_with("_left") or action == "jab" else "right"
	play_action({"action": action, "hand": hand})


func restart_action() -> void:
	_action_time = 0.0
	_emitted_markers.clear()


func current_action() -> String:
	return _action if _action != "" else ("knocked_down" if _knocked_down else _locomotion_name())


func normalized_time() -> float:
	return clampf(_action_time / maxf(_action_duration, 0.001), 0.0, 1.0) if _action != "" else fposmod(_clock, 1.0)


func animation_names() -> Array:
	return ACTIONS.duplicate()


func _process(delta: float) -> void:
	if paused:
		return
	var step := delta * playback_speed
	_clock += step
	if not _on_floor:
		_airborne_pose_time += step
	if _action != "":
		_action_time += step * _action_speed
		_emit_crossed_markers()
		if _action_time >= _action_duration:
			if loop_action:
				_action_time = fposmod(_action_time, _action_duration)
				_emitted_markers.clear()
				_prime_past_markers()
			else:
				var finished := _action
				if finished.begins_with("knockdown_"):
					_knocked_down = true
					_knock_direction = finished.trim_prefix("knockdown_")
				elif finished in ["get_up", "get_up_face_up", "get_up_face_down"]:
					_knocked_down = false
				elif finished in ["grounded_face_up", "grounded_face_down"]:
					_knocked_down = true
				_action = ""
				_action_time = 0.0
				action_finished.emit(finished)
	_apply_pose()


func _marker_times() -> Dictionary:
	if _action in ["jab_left", "cross_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right"]:
		return {"impact": clampf(float(_command.get("impact_fraction", 0.42)), 0.05, 0.95)}
	if _action in ["ultimate_1", "ultimate_2"]:
		return {"charge": 0.16, "release": 0.58, "effect_end": 0.88}
	if _action.begins_with("knockdown_"):
		return {"ground_contact": 0.72}
	if _action in ["get_up", "get_up_face_up", "get_up_face_down"]:
		return {"feet_planted": 0.82}
	return {}


func _prime_past_markers() -> void:
	var phase := normalized_time()
	for marker in _marker_times():
		if phase >= float(_marker_times()[marker]):
			_emitted_markers[marker] = true


func _emit_crossed_markers() -> void:
	var phase := normalized_time()
	var marker_times := _marker_times()
	for marker in marker_times:
		if not _emitted_markers.has(marker) and phase >= float(marker_times[marker]):
			_emitted_markers[marker] = true
			effect_marker.emit(String(marker), _action, _command)


func _build_rig() -> void:
	var root := _bone("root", self, Vector3.ZERO)
	var foot_h: float = (_profile.foot as Vector3).y
	var hip_y: float = foot_h + float(_profile.lower_leg) + float(_profile.upper_leg)
	var pelvis := _bone("pelvis", root, Vector3(0, hip_y, 0))
	var spine := _bone("spine", pelvis, Vector3(0, 0.08, 0))
	var chest := _bone("chest", spine, Vector3(0, float(_profile.torso_h) * 0.48, 0))
	var neck := _bone("neck", chest, Vector3(0, float(_profile.torso_h) * 0.48, 0))
	var head_size: Vector3 = _profile.head
	# Head geometry already contains its own vertical offset. The old adapter
	# added PlayerBody's second offset here and created the giraffe-neck look.
	# Sink the head into the shoulder line so the rig has the compact fighter
	# necks shown in the reference sheets instead of a mannequin-like gap.
	var head := _bone("head", neck, Vector3(0, -head_size.y * 0.2, 0))
	_bone("hair", head, Vector3.ZERO)
	_bone("beard", head, Vector3.ZERO)
	_bone("sash", pelvis, Vector3.ZERO)
	_bone("headband_tail_l", head, Vector3.ZERO)
	_bone("headband_tail_r", head, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var suffix := "_l" if side < 0.0 else "_r"
		var clavicle := _bone("clavicle" + suffix, chest, Vector3(side * float(_profile.shoulder) * 0.5, float(_profile.torso_h) * 0.08, 0))
		var upper := _bone("upper_arm" + suffix, clavicle, Vector3.ZERO)
		var fore := _bone("forearm" + suffix, upper, Vector3(0, -float(_profile.upper_arm), 0))
		var wrist := _bone("wrist" + suffix, fore, Vector3(0, -float(_profile.forearm), 0))
		_bone("hand" + suffix, wrist, Vector3.ZERO)
		var thigh := _bone("thigh" + suffix, pelvis, Vector3(side * float(_profile.hip) * 0.5, 0, 0))
		var shin := _bone("shin" + suffix, thigh, Vector3(0, -float(_profile.upper_leg), 0))
		var ankle := _bone("ankle" + suffix, shin, Vector3(0, -float(_profile.lower_leg), 0))
		_bone("foot" + suffix, ankle, Vector3.ZERO)


func _bone(name: String, parent: Node, at: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = name.to_pascal_case()
	joint.position = at
	parent.add_child(joint)
	_bones[name] = joint
	_rest[name] = joint.transform
	_boxes[name] = []
	return joint


func _build_production_body() -> void:
	if _production_body != null and is_instance_valid(_production_body):
		_production_body.free()
	_production_body = PlayerBodyScript.new(fighter_id, skin_id)
	_production_body.name = "DetailedVoxelBody"
	# Character Lab review must never show a half-painted fighter. PlayerBody's
	# normal game path spreads this work over frames; here we finish the same
	# operations immediately and then reuse PlayerBody's own baked cache.
	_production_body.build_budget_ms = 100000
	add_child(_production_body)
	if not _production_body._ops.is_empty():
		_production_body._build_step()
	_production_body.set_process(false)
	_capture_production_rest()
	_apply_silhouette_material()


func _capture_production_rest() -> void:
	_production_rest.clear()
	_production_rest["body_position"] = _production_body.position
	_production_rest["body_rotation"] = _production_body.rotation
	_production_rest["body_scale"] = _production_body.scale
	for joint_name in ["hips", "torso", "head", "ls", "le", "rs", "re", "lh", "lk", "rh", "rk"]:
		if _production_body._joints.has(joint_name):
			_production_rest[joint_name] = (_production_body._joints[joint_name] as Node3D).transform


func _sync_production_body() -> void:
	if _production_body == null or not is_instance_valid(_production_body) or _production_rest.is_empty():
		return
	var root: Node3D = _bones.root
	var root_rest: Transform3D = _rest.root
	_production_body.position = (_production_rest.body_position as Vector3) + root.position - root_rest.origin
	_production_body.rotation = (_production_rest.body_rotation as Vector3) + root.rotation - root_rest.basis.get_euler()
	_production_body.scale = _production_rest.body_scale

	_sync_production_joint("hips", ["pelvis"], "pelvis")
	_sync_production_joint("torso", ["spine", "chest"])
	_sync_production_joint("head", ["neck", "head"], "head")
	_sync_production_joint("ls", ["clavicle_l", "upper_arm_l"])
	_sync_production_joint("le", ["forearm_l", "wrist_l", "hand_l"])
	_sync_production_joint("rs", ["clavicle_r", "upper_arm_r"])
	_sync_production_joint("re", ["forearm_r", "wrist_r", "hand_r"])
	_sync_production_joint("lh", ["thigh_l"])
	_sync_production_joint("lk", ["shin_l", "ankle_l", "foot_l"])
	_sync_production_joint("rh", ["thigh_r"])
	_sync_production_joint("rk", ["shin_r", "ankle_r", "foot_r"])


func _sync_production_joint(production_name: String, semantic_chain: Array, position_source := "") -> void:
	if not _production_rest.has(production_name) or not _production_body._joints.has(production_name):
		return
	var joint: Node3D = _production_body._joints[production_name]
	var production_rest: Transform3D = _production_rest[production_name]
	var delta_basis := Basis.IDENTITY
	for semantic_name in semantic_chain:
		var semantic: Node3D = _bones[semantic_name]
		var semantic_rest: Transform3D = _rest[semantic_name]
		delta_basis *= semantic_rest.basis.inverse() * semantic.transform.basis
	joint.transform = Transform3D(production_rest.basis * delta_basis, production_rest.origin)
	if position_source != "":
		var semantic_position: Node3D = _bones[position_source]
		var semantic_position_rest: Transform3D = _rest[position_source]
		joint.position += semantic_position.position - semantic_position_rest.origin


func _build_geometry() -> void:
	var p := _profile
	var skin := _skin_color
	var dark := Color(0.06, 0.06, 0.075)
	var pants := _color("pants", _color("trunks", _color("cloth", dark)))
	var shoe := _color("shoes", dark)
	var sole := _color("sole", Color(0.82, 0.82, 0.8))
	var top := _color("top", _color("jacket", _color("robe", _color("gi", _color("cloth", dark)))))
	var accent := _color("accent", GameState.CLASSES[fighter_id].color)
	var glove := _color("glove", _color("tape", _color("hand_tape", skin)))
	var upper_leg: float = p.upper_leg
	var lower_leg: float = p.lower_leg
	var leg_w: float = p.leg_w
	var upper_arm: float = p.upper_arm
	var forearm: float = p.forearm
	var arm_w: float = p.arm_w
	var glove_size: float = p.glove
	var foot: Vector3 = p.foot

	# The visible model is built here, not borrowed from production PlayerBody.
	# Anatomy uses intentionally faceted polygon forms; fighter-specific clothing
	# and identity details are layered on the same semantic joints.
	var torso_base := skin if fighter_id in ["berserker", "elementalist"] else top
	var sleeve := top if fighter_id == "wise_guy" else skin
	var thigh_color := skin if fighter_id in ["berserker", "elementalist"] else pants
	var shin_color := skin if fighter_id == "elementalist" else pants.darkened(0.035)
	_add_taper("pelvis", Vector3(0, 0.1, 0), Vector3(0, -0.12, 0), Vector2(float(p.hip) * 0.62 + 0.07, float(p.torso_d) * 0.48), Vector2(float(p.hip) * 0.54 + 0.06, float(p.torso_d) * 0.42), pants)
	for side_name in ["l", "r"]:
		var thigh_bulk := 1.3 if fighter_id == "combo_master" else (1.16 if fighter_id in ["berserker", "wise_guy"] else 1.05)
		_add_taper("thigh_" + side_name, Vector3(0, -0.015, 0), Vector3(0, -upper_leg * 0.96, 0), Vector2(leg_w * 0.62 * thigh_bulk, leg_w * 0.58 * thigh_bulk), Vector2(leg_w * 0.48 * thigh_bulk, leg_w * 0.47 * thigh_bulk), thigh_color)
		_add_taper("shin_" + side_name, Vector3(0, -0.01, 0), Vector3(0, -lower_leg * 0.96, 0), Vector2(leg_w * 0.48, leg_w * 0.47), Vector2(leg_w * 0.38, leg_w * 0.4), shin_color)
		_add_box("foot_" + side_name, Vector3(0, foot.y * 0.48, -foot.z * 0.2), foot, shoe)
		_add_box("foot_" + side_name, Vector3(0, foot.y * 0.52, -foot.z * 0.62), Vector3(foot.x * 0.94, foot.y * 0.74, foot.z * 0.42), shoe.lightened(0.025))
		_add_box("foot_" + side_name, Vector3(0, 0.018, -foot.z * 0.2), Vector3(foot.x * 1.06, 0.035, foot.z * 1.05), sole)
		_add_taper("upper_arm_" + side_name, Vector3(0, -0.01, 0), Vector3(0, -upper_arm * 0.95, 0), Vector2(arm_w * 0.58, arm_w * 0.55), Vector2(arm_w * 0.47, arm_w * 0.46), sleeve)
		_add_taper("forearm_" + side_name, Vector3(0, -0.01, 0), Vector3(0, -forearm * 0.95, 0), Vector2(arm_w * 0.5, arm_w * 0.49), Vector2(arm_w * 0.4, arm_w * 0.4), skin)
		_add_ellipsoid("hand_" + side_name, Vector3(0, -glove_size * 0.34, -glove_size * 0.09), Vector3(glove_size * 0.54, glove_size * 0.42, glove_size * 0.48), glove)
		_add_box("hand_" + side_name, Vector3((-0.48 if side_name == "l" else 0.48) * glove_size, -glove_size * 0.27, -glove_size * 0.12), Vector3(glove_size * 0.24, glove_size * 0.42, glove_size * 0.3), glove.darkened(0.035), Vector3(0, 0, (-0.24 if side_name == "l" else 0.24)))

	# Head and face planes remain readable at gameplay range.
	var head_size: Vector3 = p.head
	_add_taper("neck", Vector3(0, 0.065, 0), Vector3(0, -0.1, 0), Vector2(head_size.x * 0.22, head_size.z * 0.21), Vector2(head_size.x * 0.29, head_size.z * 0.27), skin.darkened(0.025))
	# Two-piece faceted head: rounded cranium plus a tapered jaw. The old
	# single ellipsoid made every fighter look like the same toy mannequin.
	_add_ellipsoid("head", Vector3(0, head_size.y * 0.62, 0.018), Vector3(head_size.x * 0.49, head_size.y * 0.34, head_size.z * 0.49), skin)
	_add_taper("head", Vector3(0, head_size.y * 0.65, -0.005), Vector3(0, head_size.y * 0.08, -0.012), Vector2(head_size.x * 0.47, head_size.z * 0.47), Vector2(head_size.x * 0.34, head_size.z * 0.38), skin)
	var face_z := -head_size.z * 0.515
	for side in [-1.0, 1.0]:
		_add_ellipsoid("head", Vector3(side * head_size.x * 0.5, head_size.y * 0.47, 0), Vector3(0.034, 0.058, 0.034), skin.darkened(0.03))
	for side in [-1.0, 1.0]:
		_add_box("head", Vector3(side * head_size.x * 0.19, head_size.y * 0.5, face_z), Vector3(0.05, 0.026, 0.014), Color(0.94, 0.93, 0.89), Vector3(0, 0, side * -0.045))
		_add_box("head", Vector3(side * head_size.x * 0.19, head_size.y * 0.5, face_z - 0.01), Vector3(0.016, 0.021, 0.012), _eye_color())
		_add_box("head", Vector3(side * head_size.x * 0.19, head_size.y * 0.61, face_z - 0.008), Vector3(0.072, 0.022, 0.018), HAIR[fighter_id].darkened(0.18), Vector3(0, 0, side * 0.14))
	_add_taper("head", Vector3(0, head_size.y * 0.48, face_z - 0.01), Vector3(0, head_size.y * 0.3, face_z - 0.035), Vector2(0.035, 0.025), Vector2(0.025, 0.021), skin.lightened(0.035))
	_add_box("head", Vector3(0, head_size.y * 0.17, face_z - 0.012), Vector3(0.09, 0.018, 0.014), skin.darkened(0.48))

	# Torso is authored fighter-by-fighter below. The slight taper comes from
	# overlapping chest and waist cuboids rather than deforming either one.
	_add_taper("spine", Vector3(0, 0.0, 0), Vector3(0, float(p.torso_h) * 0.47, 0), Vector2(float(p.torso_w) * 0.34, float(p.torso_d) * 0.43), Vector2(float(p.torso_w) * 0.43, float(p.torso_d) * 0.5), torso_base)
	_add_taper("chest", Vector3(0, float(p.torso_h) * 0.45, 0), Vector3(0, -float(p.torso_h) * 0.38, 0), Vector2(float(p.torso_w) * 0.32, float(p.torso_d) * 0.38), Vector2(float(p.torso_w) * 0.36, float(p.torso_d) * 0.43), torso_base)
	_add_ellipsoid("chest", Vector3(0, float(p.torso_h) * 0.03, 0), Vector3(float(p.torso_w) * 0.51, float(p.torso_h) * 0.28, float(p.torso_d) * 0.52), torso_base)

	match fighter_id:
		"berserker":
			_build_mauler(p, skin, accent)
		"counter_master":
			_build_answer(p, skin, accent)
		"combo_master":
			_build_blur(p, skin, accent)
		"free_runner":
			_build_stray(p, skin, accent)
		"wise_guy":
			_build_tony(p, skin, accent)
		"elementalist":
			_build_catalyst(p, skin, accent)


func _build_mauler(p: Dictionary, skin: Color, accent: Color) -> void:
	var vest := _color("vest", Color(0.08, 0.08, 0.09))
	var trim := _color("trim", Color(0.82, 0.8, 0.74))
	var sash := _color("sash", accent)
	# Open vest panels leave the chest visible and make the shoulders even wider.
	for side in [-1.0, 1.0]:
		_add_ellipsoid("chest", Vector3(side * float(p.torso_w) * 0.16, -0.055, -float(p.torso_d) * 0.4), Vector3(float(p.torso_w) * 0.22, 0.095, float(p.torso_d) * 0.12), skin.lightened(0.015))
		var arm := "l" if side < 0.0 else "r"
		_add_ellipsoid("upper_arm_" + arm, Vector3(0, -0.045, 0), Vector3(0.175, 0.15, 0.165), skin.lightened(0.025))
		_add_ellipsoid("upper_arm_" + arm, Vector3(0, -0.2, -0.015), Vector3(0.145, 0.18, 0.14), skin)
		_add_ellipsoid("forearm_" + arm, Vector3(0, -0.16, -0.01), Vector3(0.132, 0.17, 0.13), skin.darkened(0.015))
	for side in [-1.0, 1.0]:
		_add_box("chest", Vector3(side * float(p.torso_w) * 0.39, -0.08, -0.01), Vector3(float(p.torso_w) * 0.25, float(p.torso_h) * 0.56, float(p.torso_d) * 1.06), vest)
		_add_box("chest", Vector3(side * float(p.torso_w) * 0.24, -0.08, -float(p.torso_d) * 0.51), Vector3(0.045, float(p.torso_h) * 0.55, 0.035), trim, Vector3(0, 0, side * 0.12))
		var arm_name := "l" if side < 0.0 else "r"
		_add_ellipsoid("clavicle_" + arm_name, Vector3(0, -0.035, 0.025), Vector3(0.18, 0.12, 0.21), vest)
		_add_box("clavicle_" + arm_name, Vector3(0, -0.025, -0.195), Vector3(0.25, 0.04, 0.035), trim, Vector3(0, 0, side * 0.14))
		_add_box("upper_arm_" + ("l" if side < 0.0 else "r"), Vector3(side * -0.015, -0.15, -float(p.arm_w) * 0.54), Vector3(0.032, 0.14, 0.02), _color("blood", accent.darkened(0.2)), Vector3(0.05, 0, side * 0.22))
	# Separate abdominal planes and scars keep the huge exposed torso from
	# reading as one smooth primitive.
	for row in 3:
		for side in [-1.0, 1.0]:
			_add_ellipsoid("chest", Vector3(side * 0.07, -0.15 - row * 0.075, -float(p.torso_d) * 0.47), Vector3(0.066, 0.05, 0.035), skin.darkened(0.025 * row))
	_add_box("chest", Vector3(0.13, -0.12, -float(p.torso_d) * 0.54), Vector3(0.022, 0.13, 0.018), _color("blood", Color(0.5, 0.05, 0.05)), Vector3(0, 0, -0.46))
	_add_box("chest", Vector3(-0.08, -0.27, -float(p.torso_d) * 0.53), Vector3(0.016, 0.09, 0.018), _color("blood", Color(0.5, 0.05, 0.05)), Vector3(0, 0, 0.38))
	_add_box("sash", Vector3(0, 0.04, -0.03), Vector3(float(p.hip) + 0.18, 0.12, float(p.torso_d)), sash, Vector3(0, 0, -0.07))
	_add_box("sash", Vector3(-0.06, -0.2, -0.02), Vector3(0.07, 0.38, 0.045), sash, Vector3(0.14, 0, -0.12))
	_add_box("sash", Vector3(0.07, -0.16, 0.0), Vector3(0.065, 0.31, 0.04), sash.darkened(0.05), Vector3(-0.1, 0, 0.14))
	for side_name in ["l", "r"]:
		_add_box("wrist_" + side_name, Vector3(0, -0.035, 0), Vector3(float(p.glove) * 0.78, 0.11, float(p.glove) * 0.7), _color("tape", trim))
		_add_taper("wrist_" + side_name, Vector3(0, 0.035, 0), Vector3(0, -0.07, 0), Vector2(float(p.glove) * 0.44, float(p.glove) * 0.4), Vector2(float(p.glove) * 0.39, float(p.glove) * 0.36), _color("tape", trim))
		for knuckle in 4:
			_add_box("hand_" + side_name, Vector3((knuckle - 1.5) * float(p.glove) * 0.2, -float(p.glove) * 0.43, -float(p.glove) * 0.48), Vector3(float(p.glove) * 0.16, 0.045, 0.035), _color("glove", accent).lightened(0.035))
		_add_box("thigh_" + side_name, Vector3(0, -0.11, 0), Vector3(float(p.leg_w) * 1.18, 0.23, float(p.leg_w) * 1.08), _color("trunks", vest))
		_add_box("thigh_" + side_name, Vector3(0, -0.225, -float(p.leg_w) * 0.54), Vector3(float(p.leg_w) * 1.22, 0.035, 0.026), trim)
		_add_box("thigh_" + side_name, Vector3((-0.07 if side_name == "l" else 0.07), -0.205, -float(p.leg_w) * 0.58), Vector3(0.075, 0.07, 0.025), sash.darkened(0.08), Vector3(0, 0, -0.2 if side_name == "l" else 0.2))
		_add_box("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.25, 0), Vector3(float(p.leg_w), float(p.lower_leg) * 0.48, float(p.leg_w)), _color("shoes", Color(0.06, 0.06, 0.07)))
		_add_box("shin_" + side_name, Vector3(0, -0.04, -float(p.leg_w) * 0.48), Vector3(float(p.leg_w) * 1.04, 0.075, 0.035), trim)
		_add_box("shin_" + side_name, Vector3(0, -0.11, -float(p.leg_w) * 0.51), Vector3(float(p.leg_w) * 0.68, 0.055, 0.03), sash)
		_add_box("foot_" + side_name, Vector3(0, 0.07, -float(p.foot.z) * 0.62), Vector3(float(p.foot.x) * 0.92, 0.065, 0.09), _color("sole", sash))
		for lace in 3:
			_add_box("foot_" + side_name, Vector3(0, 0.085, -0.12 - lace * 0.045), Vector3(float(p.foot.x) * 0.62, 0.018, 0.018), _color("laces", trim))
	# Compact squared flat-top: one faceted crown with a clipped horizontal top,
	# then a few broad fringe planes. It stays smaller than Mauler's shoulders.
	_add_taper("hair", Vector3(0, 0.405, 0.015), Vector3(0, 0.245, 0.012), Vector2(0.16, 0.145), Vector2(0.15, 0.135), HAIR[fighter_id])
	_add_box("hair", Vector3(0, 0.395, 0.015), Vector3(0.33, 0.035, 0.29), HAIR[fighter_id].lightened(0.025))
	_add_box("hair", Vector3(0, 0.245, -0.145), Vector3(0.3, 0.065, 0.045), HAIR[fighter_id].lightened(0.03))
	for strip in 5:
		_add_box("hair", Vector3(-0.12 + strip * 0.06, 0.412, -0.005), Vector3(0.05, 0.018, 0.27), HAIR[fighter_id].lightened(0.018 * (strip % 2)))
	# Low continuous brow and downturned mouth make the face read as Mauler even
	# in an untextured silhouette review.
	_add_box("head", Vector3(0, 0.225, -0.174), Vector3(0.255, 0.034, 0.022), HAIR[fighter_id], Vector3(0, 0, -0.025))
	_add_box("head", Vector3(0, 0.055, -0.177), Vector3(0.12, 0.018, 0.014), skin.darkened(0.55), Vector3(0, 0, -0.03))


func _build_answer(p: Dictionary, _skin: Color, _accent: Color) -> void:
	var cloth := _color("cloth", Color(0.055, 0.055, 0.07))
	var pipe := _color("piping", Color(0.86, 0.86, 0.9))
	var wrap := _color("wrap", Color(0.12, 0.34, 0.86))
	_add_box("chest", Vector3(0, -0.08, -float(p.torso_d) * 0.5), Vector3(float(p.torso_w) * 0.82, float(p.torso_h) * 0.5, 0.045), cloth.lightened(0.03))
	_add_box("chest", Vector3(0, -0.07, -float(p.torso_d) * 0.55), Vector3(0.018, float(p.torso_h) * 0.47, 0.018), cloth.lightened(0.12))
	for side in [-1.0, 1.0]:
		_add_box("chest", Vector3(side * float(p.torso_w) * 0.38, -0.08, -float(p.torso_d) * 0.52), Vector3(0.025, float(p.torso_h) * 0.52, 0.04), pipe)
		var shoulder_name := "l" if side < 0.0 else "r"
		_add_taper("clavicle_" + shoulder_name, Vector3(0, 0.035, 0), Vector3(0, -0.1, 0), Vector2(0.125, 0.14), Vector2(0.1, 0.12), cloth)
		_add_box("clavicle_" + shoulder_name, Vector3(0, -0.03, -0.13), Vector3(0.2, 0.035, 0.028), pipe, Vector3(0, 0, side * 0.16))
	_add_box("sash", Vector3(0, 0.015, -0.01), Vector3(float(p.hip) + 0.14, 0.08, float(p.torso_d)), _color("belt", pipe))
	_add_box("sash", Vector3(-0.1, -0.18, -0.03), Vector3(0.055, 0.34, 0.035), pipe, Vector3(0.08, 0, -0.1))
	_add_box("sash", Vector3(0.1, -0.15, -0.02), Vector3(0.05, 0.28, 0.035), cloth.lightened(0.06), Vector3(-0.06, 0, 0.1))
	for side in [-1.0, 1.0]:
		_add_taper("sash", Vector3(side * 0.13, -0.03, -0.01), Vector3(side * 0.16, -0.38, 0.0), Vector2(0.105, float(p.torso_d) * 0.45), Vector2(0.13, float(p.torso_d) * 0.5), cloth)
		_add_box("sash", Vector3(side * 0.095, -0.21, -float(p.torso_d) * 0.5), Vector3(0.035, 0.35, 0.025), pipe, Vector3(0, 0, side * 0.08))
	# Thick hood sits behind the skull while a low split collar frames the jaw.
	# Keeping the front open avoids the old featureless black neck column.
	_add_ellipsoid("head", Vector3(0, 0.17, 0.095), Vector3(float(p.head.x) * 0.68, 0.17, 0.17), cloth)
	_add_box("neck", Vector3(-0.085, -0.055, -0.07), Vector3(0.13, 0.11, 0.075), cloth.lightened(0.025), Vector3(0, 0, -0.32))
	_add_box("neck", Vector3(0.085, -0.055, -0.07), Vector3(0.13, 0.11, 0.075), cloth.lightened(0.025), Vector3(0, 0, 0.32))
	for side_name in ["l", "r"]:
		_add_ellipsoid("upper_arm_" + side_name, Vector3(0, -0.17, -0.01), Vector3(0.09, 0.17, 0.09), _skin_color)
		_add_ellipsoid("forearm_" + side_name, Vector3(0, -0.15, 0), Vector3(0.085, 0.15, 0.085), _skin_color.darkened(0.015))
		for i in 3:
			var ring_color := _color("wrap_light", pipe) if i == 1 else wrap.lightened(i * 0.025)
			_add_taper("forearm_" + side_name, Vector3(0, -0.07 - i * 0.073, 0), Vector3(0, -0.115 - i * 0.073, 0), Vector2(float(p.arm_w) * 0.62, float(p.arm_w) * 0.61), Vector2(float(p.arm_w) * 0.61, float(p.arm_w) * 0.6), ring_color)
		for finger in 4:
			_add_box("hand_" + side_name, Vector3((finger - 1.5) * 0.028, -0.075, -0.075), Vector3(0.024, 0.075, 0.03), _color("glove", cloth))
		_add_box("ankle_" + side_name, Vector3(0, 0.035, 0), Vector3(float(p.leg_w), 0.09, float(p.leg_w)), _color("ankle", pipe))
		_add_box("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.46, -float(p.leg_w) * 0.55), Vector3(float(p.leg_w) * 0.72, 0.045, 0.025), pipe)
		_add_ellipsoid("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.46, 0.025), Vector3(float(p.leg_w) * 0.66, float(p.upper_leg) * 0.45, float(p.leg_w) * 0.63), cloth)
		_add_ellipsoid("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.42, 0.02), Vector3(float(p.leg_w) * 0.52, float(p.lower_leg) * 0.39, float(p.leg_w) * 0.5), cloth.darkened(0.025))
		_add_box("thigh_" + side_name, Vector3((-0.1 if side_name == "l" else 0.1), -0.16, -float(p.leg_w) * 0.61), Vector3(0.055, 0.25, 0.022), pipe, Vector3(0, 0, -0.12 if side_name == "l" else 0.12))
		_add_box("shin_" + side_name, Vector3((-0.085 if side_name == "l" else 0.085), -0.23, -float(p.leg_w) * 0.47), Vector3(0.04, 0.25, 0.022), pipe)
		_add_box("foot_" + side_name, Vector3(0, 0.075, -float(p.foot.z) * 0.55), Vector3(float(p.foot.x) * 0.68, 0.025, 0.07), pipe)
	# Deliberately compact layered crop: faceted cap, squared fringe, no spikes.
	_add_ellipsoid("hair", Vector3(0, 0.29, 0.02), Vector3(0.16, 0.105, 0.145), HAIR[fighter_id])
	_add_box("hair", Vector3(-0.07, 0.225, -0.14), Vector3(0.15, 0.075, 0.055), HAIR[fighter_id])
	_add_box("hair", Vector3(0.085, 0.245, -0.14), Vector3(0.11, 0.065, 0.052), HAIR[fighter_id].lightened(0.04))
	for strip in 4:
		_add_box("hair", Vector3(-0.105 + strip * 0.07, 0.365 - absf(1.5 - strip) * 0.012, -0.015), Vector3(0.06, 0.035, 0.25), HAIR[fighter_id].lightened(0.012 * (strip % 2)), Vector3(0, 0, (strip - 1.5) * 0.035))


func _build_blur(p: Dictionary, skin: Color, _accent: Color) -> void:
	var top := _color("top", Color(0.08, 0.07, 0.11))
	var trim := _color("trim", Color(0.55, 0.3, 0.95))
	var pants := _color("pants", Color(0.07, 0.065, 0.1))
	# Cropped top and visible midriff.
	_add_box("spine", Vector3(0, 0.06, -float(p.torso_d) * 0.48), Vector3(float(p.torso_w) * 0.74, 0.14, 0.045), skin)
	_add_box("chest", Vector3(0, -0.04, -float(p.torso_d) * 0.51), Vector3(float(p.torso_w) * 0.92, 0.22, 0.04), top)
	_add_box("chest", Vector3(0, 0.07, -float(p.torso_d) * 0.54), Vector3(float(p.torso_w) * 0.94, 0.035, 0.045), trim)
	_add_box("chest", Vector3(-0.13, -0.015, -float(p.torso_d) * 0.55), Vector3(0.11, 0.035, 0.025), top.lightened(0.09), Vector3(0, 0, -0.28))
	_add_box("chest", Vector3(0.13, -0.015, -float(p.torso_d) * 0.55), Vector3(0.11, 0.035, 0.025), top.lightened(0.09), Vector3(0, 0, 0.28))
	_add_box("sash", Vector3(0, 0.025, 0), Vector3(float(p.hip) + 0.16, 0.095, float(p.torso_d)), _color("sash", trim.darkened(0.16)))
	_add_box("sash", Vector3(-0.11, -0.17, 0.02), Vector3(0.065, 0.35, 0.045), _color("sash", trim.darkened(0.16)), Vector3(0.18, 0, -0.2))
	_add_box("sash", Vector3(0.08, -0.14, 0.03), Vector3(0.055, 0.29, 0.04), _color("sash", trim.darkened(0.16)), Vector3(-0.12, 0, 0.16))
	for side in [-1.0, 1.0]:
		_add_box("sash", Vector3(side * 0.12, -0.16, -float(p.torso_d) * 0.45), Vector3(0.16, 0.29, 0.035), pants.lightened(0.02), Vector3(0, 0, side * 0.06))
		_add_box("sash", Vector3(side * 0.12, -0.305, -float(p.torso_d) * 0.47), Vector3(0.17, 0.035, 0.03), trim.darkened(0.08), Vector3(0, 0, side * 0.06))
	for side_name in ["l", "r"]:
		_add_ellipsoid("upper_arm_" + side_name, Vector3(0, -0.16, 0), Vector3(0.067, 0.15, 0.068), skin)
		_add_ellipsoid("forearm_" + side_name, Vector3(0, -0.14, 0), Vector3(0.062, 0.135, 0.063), skin.darkened(0.012))
		_add_ellipsoid("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.45, 0.025), Vector3(float(p.leg_w) * 0.82, float(p.upper_leg) * 0.44, float(p.leg_w) * 0.72), pants)
		_add_taper("shin_" + side_name, Vector3(0, -0.025, 0), Vector3(0, -float(p.lower_leg) * 0.9, 0), Vector2(float(p.leg_w) * 0.62, float(p.leg_w) * 0.58), Vector2(float(p.leg_w) * 0.39, float(p.leg_w) * 0.4), pants.darkened(0.025))
		_add_box("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.43, -float(p.leg_w) * 0.68), Vector3(float(p.leg_w) * 1.0, 0.09, 0.025), _color("patch", Color(0.78, 0.77, 0.82)))
		_add_box("thigh_" + side_name, Vector3((0.07 if side_name == "l" else -0.07), -0.18, -float(p.leg_w) * 0.7), Vector3(0.06, 0.14, 0.022), _color("patch_mid", Color(0.38, 0.36, 0.44)), Vector3(0, 0, 0.18 if side_name == "l" else -0.18))
		_add_taper("forearm_" + side_name, Vector3(0, -0.1, 0), Vector3(0, -0.29, 0), Vector2(float(p.arm_w) * 0.57, float(p.arm_w) * 0.56), Vector2(float(p.arm_w) * 0.51, float(p.arm_w) * 0.5), _color("hand_wrap", trim))
		for band in 2:
			_add_box("forearm_" + side_name, Vector3(0, -0.14 - band * 0.09, -float(p.arm_w) * 0.55), Vector3(float(p.arm_w) * 1.12, 0.028, 0.024), _color("band_b", Color(0.9, 0.88, 0.92)))
		for finger in 4:
			_add_box("hand_" + side_name, Vector3((finger - 1.5) * 0.023, -0.065, -0.065), Vector3(0.02, 0.065, 0.025), _color("glove", top))
		_add_box("ankle_" + side_name, Vector3(0, 0.035, -float(p.leg_w) * 0.45), Vector3(float(p.leg_w) * 0.9, 0.055, 0.028), trim)
		_add_box("foot_" + side_name, Vector3(0, 0.075, -float(p.foot.z) * 0.58), Vector3(float(p.foot.x) * 0.64, 0.025, 0.065), trim)
	# Angular layered hair mass, made from rotated slabs instead of curls.
	_add_box("hair", Vector3(0, 0.28, 0.025), Vector3(0.34, 0.16, 0.3), HAIR[fighter_id])
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		_add_box("hair", Vector3(side * (0.1 + row * 0.018), 0.3 + (i % 3) * 0.045, -0.04 + row * 0.035), Vector3(0.1, 0.23 - row * 0.02, 0.08), HAIR[fighter_id].lightened(0.025 * (i % 3)), Vector3(0.12 * row, 0, side * (0.48 + row * 0.12)))
	# Large violet eyes and a narrow jaw are central to Blur's reference face.
	for side in [-1.0, 1.0]:
		_add_box("head", Vector3(side * 0.06, 0.16, -0.137), Vector3(0.055, 0.04, 0.018), Color(0.83, 0.79, 0.94))
		_add_box("head", Vector3(side * 0.06, 0.16, -0.149), Vector3(0.02, 0.032, 0.012), _eye_color())


func _build_stray(p: Dictionary, _skin: Color, _accent: Color) -> void:
	var gi := _color("gi", Color(0.12, 0.1, 0.11))
	var band := _color("band", Color(0.7, 0.06, 0.06))
	var tape := _color("tape", Color(0.84, 0.82, 0.76))
	_add_box("chest", Vector3(0, -0.09, -float(p.torso_d) * 0.5), Vector3(float(p.torso_w) * 0.88, float(p.torso_h) * 0.54, 0.04), gi.lightened(0.025), Vector3(0, 0, -0.04))
	_add_box("chest", Vector3(-0.09, 0.01, -float(p.torso_d) * 0.55), Vector3(0.16, 0.05, 0.025), gi.lightened(0.09), Vector3(0, 0, -0.46))
	_add_box("chest", Vector3(0.09, 0.01, -float(p.torso_d) * 0.55), Vector3(0.16, 0.05, 0.025), gi.lightened(0.09), Vector3(0, 0, 0.46))
	for side in [-1.0, 1.0]:
		_add_box("chest", Vector3(side * 0.095, -0.06, -float(p.torso_d) * 0.55), Vector3(0.085, float(p.torso_h) * 0.5, 0.035), tape, Vector3(0, 0, side * 0.42))
		_add_ellipsoid("upper_arm_" + ("l" if side < 0.0 else "r"), Vector3(0, -0.17, -0.01), Vector3(0.09, 0.175, 0.088), _skin_color)
		_add_ellipsoid("forearm_" + ("l" if side < 0.0 else "r"), Vector3(0, -0.15, 0), Vector3(0.082, 0.15, 0.08), _skin_color.darkened(0.012))
		var shoulder_name := "l" if side < 0.0 else "r"
		_add_taper("clavicle_" + shoulder_name, Vector3(0, 0.025, 0), Vector3(0, -0.095, 0), Vector2(0.13, 0.145), Vector2(0.095, 0.115), gi)
		_add_box("clavicle_" + shoulder_name, Vector3(0, -0.035, -0.13), Vector3(0.2, 0.035, 0.03), tape, Vector3(0, 0, side * 0.14))
	_add_box("neck", Vector3(0, -0.055, -0.105), Vector3(0.28, 0.08, 0.055), band, Vector3(0.08, 0, 0))
	_add_box("sash", Vector3(0, 0.025, -0.025), Vector3(float(p.hip) + 0.15, 0.1, float(p.torso_d)), band, Vector3(0, 0, 0.12))
	_add_box("sash", Vector3(-0.08, -0.17, -0.02), Vector3(0.055, 0.34, 0.04), band, Vector3(0.16, 0, -0.18))
	_add_box("sash", Vector3(0.09, -0.14, 0), Vector3(0.05, 0.28, 0.04), tape, Vector3(-0.12, 0, 0.18))
	for side in [-1.0, 1.0]:
		_add_taper("sash", Vector3(side * 0.13, -0.02, 0), Vector3(side * 0.16, -0.4, 0.02), Vector2(0.115, float(p.torso_d) * 0.44), Vector2(0.14, float(p.torso_d) * 0.5), gi)
		_add_box("sash", Vector3(side * 0.102, -0.21, -float(p.torso_d) * 0.5), Vector3(0.035, 0.37, 0.026), tape, Vector3(0, 0, side * 0.08))
		_add_box("sash", Vector3(side * 0.15, -0.4, -float(p.torso_d) * 0.44), Vector3(0.2, 0.04, 0.03), gi.lightened(0.12), Vector3(0, 0, side * 0.08))
	for side_name in ["l", "r"]:
		_add_taper("forearm_" + side_name, Vector3(0, -0.085, 0), Vector3(0, -0.29, 0), Vector2(float(p.arm_w) * 0.62, float(p.arm_w) * 0.61), Vector2(float(p.arm_w) * 0.53, float(p.arm_w) * 0.52), tape)
		for wrap_index in 3:
			_add_box("forearm_" + side_name, Vector3(0, -0.11 - wrap_index * 0.07, -float(p.arm_w) * 0.56), Vector3(float(p.arm_w) * 1.1, 0.024, 0.022), tape.lightened(0.035 * (wrap_index % 2)))
		for finger in 4:
			_add_box("hand_" + side_name, Vector3((finger - 1.5) * 0.026, -0.07, -0.075), Vector3(0.023, 0.07, 0.028), _color("glove", Color(0.16, 0.45, 0.22)))
		_add_box("ankle_" + side_name, Vector3(0, 0.035, 0), Vector3(float(p.leg_w) * 1.03, 0.1, float(p.leg_w)), tape)
		_add_ellipsoid("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.45, 0.02), Vector3(float(p.leg_w) * 0.72, float(p.upper_leg) * 0.44, float(p.leg_w) * 0.66), gi)
		_add_ellipsoid("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.42, 0.02), Vector3(float(p.leg_w) * 0.58, float(p.lower_leg) * 0.4, float(p.leg_w) * 0.54), gi.darkened(0.02))
		_add_box("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.9, 0), Vector3(float(p.leg_w) * 1.18, 0.055, float(p.leg_w)), _color("hem", gi.lightened(0.1)))
		_add_box("thigh_" + side_name, Vector3((-0.09 if side_name == "l" else 0.09), -0.18, -float(p.leg_w) * 0.66), Vector3(0.065, 0.12, 0.022), tape, Vector3(0, 0, -0.16 if side_name == "l" else 0.16))
		_add_box("ankle_" + side_name, Vector3(0, 0.0, -float(p.leg_w) * 0.48), Vector3(float(p.leg_w) * 0.92, 0.055, 0.025), band)
		_add_box("foot_" + side_name, Vector3(0, 0.075, -float(p.foot.z) * 0.57), Vector3(float(p.foot.x) * 0.65, 0.028, 0.07), band)
	_add_box("hair", Vector3(0, 0.27, 0.03), Vector3(0.3, 0.12, 0.27), HAIR[fighter_id])
	for i in 9:
		var angle := -1.2 + i * 0.3
		_add_box("hair", Vector3(sin(angle) * 0.16, 0.27 + (i % 2) * 0.045, cos(angle) * 0.09), Vector3(0.055, 0.26 + (i % 3) * 0.035, 0.055), HAIR[fighter_id].lightened(0.018 * (i % 3)), Vector3(cos(angle) * 0.48, 0, -sin(angle) * 0.48))
	for lock in 10:
		var angle := TAU * lock / 10.0
		var start := Vector3(sin(angle) * 0.08, 0.34, cos(angle) * 0.07)
		var finish := Vector3(sin(angle) * (0.18 + 0.025 * (lock % 3)), 0.18 + 0.035 * (lock % 2), cos(angle) * (0.13 + 0.02 * (lock % 2)))
		_add_taper("hair", start, finish, Vector2(0.035, 0.035), Vector2(0.022, 0.022), HAIR[fighter_id].lightened(0.012 * (lock % 3)))
	_add_box("head", Vector3(0, 0.27, -0.16), Vector3(0.34, 0.045, 0.04), band)
	for knot in 3:
		_add_box("head", Vector3(-0.11 + knot * 0.11, 0.27, -0.184), Vector3(0.07, 0.052, 0.022), band.lightened(0.035 * (knot % 2)))
	# Exactly two readable trailing headband tails on optional bones.
	_add_box("headband_tail_l", Vector3(-0.08, 0.18, 0.16), Vector3(0.045, 0.34, 0.035), band, Vector3(0.25, 0, -0.18))
	_add_box("headband_tail_r", Vector3(0.08, 0.2, 0.16), Vector3(0.045, 0.3, 0.035), band, Vector3(-0.2, 0, 0.18))


func _build_tony(p: Dictionary, _skin: Color, _accent: Color) -> void:
	var jacket := _color("jacket", Color(0.065, 0.065, 0.075))
	var stripe := _color("stripe", Color(0.9, 0.9, 0.87))
	var tee := _color("tee", Color(0.9, 0.9, 0.88))
	_add_ellipsoid("spine", Vector3(0, 0.18, 0.015), Vector3(float(p.torso_w) * 0.46, 0.27, float(p.torso_d) * 0.52), jacket)
	_add_box("chest", Vector3(0, -0.08, -float(p.torso_d) * 0.52), Vector3(float(p.torso_w) * 0.93, float(p.torso_h) * 0.52, 0.045), jacket)
	_add_box("chest", Vector3(0, -0.11, -float(p.torso_d) * 0.55), Vector3(0.16, float(p.torso_h) * 0.42, 0.04), tee)
	_add_box("chest", Vector3(0, -0.08, -float(p.torso_d) * 0.58), Vector3(0.018, float(p.torso_h) * 0.48, 0.025), _color("zip", stripe))
	_add_box("chest", Vector3(-float(p.torso_w) * 0.23, 0.14, -float(p.torso_d) * 0.48), Vector3(0.18, 0.08, 0.08), jacket.lightened(0.035), Vector3(0, 0, -0.35))
	_add_box("chest", Vector3(float(p.torso_w) * 0.23, 0.14, -float(p.torso_d) * 0.48), Vector3(0.18, 0.08, 0.08), jacket.lightened(0.035), Vector3(0, 0, 0.35))
	for side in [-1.0, 1.0]:
		_add_box("spine", Vector3(side * 0.16, 0.07, -float(p.torso_d) * 0.52), Vector3(0.17, 0.03, 0.025), jacket.lightened(0.05), Vector3(0, 0, side * 0.18))
	# Chunky gold chain and jacket collar are essential to Tony's portrait.
	for link in 7:
		var angle := -1.15 + link * 0.38
		_add_box("chest", Vector3(sin(angle) * 0.13, 0.08 - cos(angle) * 0.06, -float(p.torso_d) * 0.58), Vector3(0.035, 0.035, 0.025), Color(0.95, 0.66, 0.08), Vector3(0, 0, -angle))
	for side_name in ["l", "r"]:
		_add_ellipsoid("upper_arm_" + side_name, Vector3(0, -0.16, 0.015), Vector3(0.105, 0.17, 0.105), jacket)
		_add_box("upper_arm_" + side_name, Vector3(0, -float(p.upper_arm) * 0.48, -float(p.arm_w) * 0.52), Vector3(0.04, float(p.upper_arm) * 0.92, 0.025), stripe)
		_add_ellipsoid("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.45, 0.025), Vector3(float(p.leg_w) * 0.72, float(p.upper_leg) * 0.46, float(p.leg_w) * 0.68), jacket.darkened(0.01))
		_add_ellipsoid("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.4, 0.025), Vector3(float(p.leg_w) * 0.62, float(p.lower_leg) * 0.39, float(p.leg_w) * 0.58), jacket.darkened(0.025))
		_add_box("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.48, -float(p.leg_w) * 0.52), Vector3(0.035, float(p.upper_leg) * 0.94, 0.025), stripe)
		_add_box("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.48, -float(p.leg_w) * 0.44), Vector3(0.035, float(p.lower_leg) * 0.94, 0.025), stripe)
		_add_taper("wrist_" + side_name, Vector3(0, 0.055, 0), Vector3(0, -0.11, 0), Vector2(float(p.arm_w) * 0.62, float(p.arm_w) * 0.6), Vector2(float(p.arm_w) * 0.56, float(p.arm_w) * 0.54), _color("tape", stripe))
		for wrap_index in 3:
			_add_taper("wrist_" + side_name, Vector3(0, 0.035 - wrap_index * 0.048, 0), Vector3(0, 0.005 - wrap_index * 0.048, 0), Vector2(float(p.arm_w) * 0.66, float(p.arm_w) * 0.63), Vector2(float(p.arm_w) * 0.64, float(p.arm_w) * 0.61), stripe.lightened(0.02 * (wrap_index % 2)))
		for finger in 4:
			_add_box("hand_" + side_name, Vector3((finger - 1.5) * 0.027, -0.07, -0.07), Vector3(0.024, 0.07, 0.028), _skin_color)
		_add_box("ankle_" + side_name, Vector3(0, 0.04, 0), Vector3(float(p.leg_w) * 1.02, 0.09, float(p.leg_w) * 0.94), jacket)
		for lace in 3:
			_add_box("foot_" + side_name, Vector3(0, 0.075, -0.12 - lace * 0.045), Vector3(float(p.foot.x) * 0.56, 0.018, 0.018), stripe)
	# Knit cap with distinct crown and brim; stubble and heavy nose are face blocks.
	_add_ellipsoid("hair", Vector3(0, 0.28, 0.025), Vector3(0.18, 0.105, 0.165), _color("beanie_a", HAIR[fighter_id]))
	_add_box("hair", Vector3(0, 0.2, -0.15), Vector3(0.35, 0.055, 0.06), _color("brim", HAIR[fighter_id].lightened(0.04)))
	for rib in 5:
		_add_box("hair", Vector3(-0.12 + rib * 0.06, 0.29, -0.14), Vector3(0.025, 0.13, 0.025), _color("beanie_b", HAIR[fighter_id].darkened(0.04)), Vector3(0, 0, (rib - 2) * 0.04))
	_add_taper("head", Vector3(0, 0.15, -0.158), Vector3(0, 0.035, -0.15), Vector2(0.125, 0.018), Vector2(0.105, 0.016), Color(0.38, 0.35, 0.33))
	_add_box("head", Vector3(0, 0.18, -0.18), Vector3(0.075, 0.095, 0.075), _skin_color.lightened(0.03))
	for side in [-1.0, 1.0]:
		_add_box("head", Vector3(side * 0.065, 0.205, -0.17), Vector3(0.12, 0.032, 0.026), HAIR[fighter_id], Vector3(0, 0, side * -0.18))
		_add_box("head", Vector3(side * 0.1, 0.105, -0.177), Vector3(0.055, 0.072, 0.022), Color(0.38, 0.35, 0.33), Vector3(0, 0, side * 0.15))
	_add_box("head", Vector3(0.04, 0.075, -0.17), Vector3(0.13, 0.022, 0.02), _skin_color.darkened(0.38), Vector3(0, 0, -0.14))


func _build_catalyst(p: Dictionary, skin: Color, _accent: Color) -> void:
	var robe := _color("robe", Color(0.09, 0.08, 0.1))
	var trim := _color("trim", Color(0.86, 0.84, 0.78))
	var sash := _color("sash", Color(0.14, 0.13, 0.16))
	var tape_a := _color("tape_a", Color(0.92, 0.9, 0.86))
	var tape_b := _color("tape_b", Color(0.84, 0.82, 0.78))
	# Broad, bare barrel torso. Separate pectoral and abdominal facets preserve
	# the exaggerated strongman anatomy from the reference at gameplay range.
	_add_ellipsoid("chest", Vector3(-0.15, 0.045, -float(p.torso_d) * 0.43), Vector3(0.17, 0.12, 0.09), skin.lightened(0.025))
	_add_ellipsoid("chest", Vector3(0.15, 0.045, -float(p.torso_d) * 0.43), Vector3(0.17, 0.12, 0.09), skin.lightened(0.025))
	for row in 3:
		for side in [-1.0, 1.0]:
			_add_ellipsoid("chest", Vector3(side * 0.074, -0.105 - row * 0.078, -float(p.torso_d) * 0.47), Vector3(0.068, 0.052, 0.036), skin.darkened(0.018 * row))
	_add_box("chest", Vector3(0, -0.09, -float(p.torso_d) * 0.49), Vector3(0.018, 0.38, 0.018), skin.darkened(0.13))
	# The robe hangs from the shoulders and frames the chest instead of covering
	# it. Layered tabs make the hem visibly torn without cube noise.
	for side in [-1.0, 1.0]:
		var side_name := "l" if side < 0.0 else "r"
		_add_box("chest", Vector3(side * float(p.torso_w) * 0.38, -0.055, 0.005), Vector3(float(p.torso_w) * 0.24, float(p.torso_h) * 0.62, float(p.torso_d) * 1.04), robe, Vector3(0, 0, side * 0.045))
		_add_box("chest", Vector3(side * float(p.torso_w) * 0.225, -0.04, -float(p.torso_d) * 0.52), Vector3(0.045, float(p.torso_h) * 0.61, 0.035), trim, Vector3(0, 0, side * 0.23))
		_add_ellipsoid("clavicle_" + side_name, Vector3(side * 0.015, -0.08, 0.02), Vector3(0.17, 0.15, 0.2), robe)
		_add_taper("upper_arm_" + side_name, Vector3(0, -0.015, 0), Vector3(0, -0.22, 0), Vector2(0.15, 0.17), Vector2(0.125, 0.14), robe)
		_add_box("upper_arm_" + side_name, Vector3(side * 0.105, -0.25, 0), Vector3(0.08, 0.18, 0.22), robe.darkened(0.035), Vector3(0.0, 0.0, side * 0.16))
		_add_box("upper_arm_" + side_name, Vector3(-side * 0.04, -0.285, 0.015), Vector3(0.065, 0.13, 0.2), robe.lightened(0.025), Vector3(0.0, 0.0, -side * 0.12))
		_add_box("upper_arm_" + side_name, Vector3(0, -0.31, -0.105), Vector3(0.24, 0.035, 0.035), trim)
		# Muscle volumes remain visible below the short ragged sleeves.
		_add_ellipsoid("upper_arm_" + side_name, Vector3(0, -0.23, -0.01), Vector3(0.14, 0.18, 0.135), skin)
		_add_ellipsoid("forearm_" + side_name, Vector3(0, -0.14, 0), Vector3(0.13, 0.17, 0.125), skin.darkened(0.012))
		# Split skirt panels with pale piping and staggered torn tabs.
		_add_box("sash", Vector3(side * 0.135, -0.185, -0.01), Vector3(0.23, 0.39, float(p.torso_d) * 0.95), robe, Vector3(0, 0, side * 0.075))
		_add_box("sash", Vector3(side * 0.102, -0.19, -float(p.torso_d) * 0.5), Vector3(0.035, 0.38, 0.03), trim, Vector3(0, 0, side * 0.08))
		_add_box("sash", Vector3(side * 0.25, -0.34, 0.015), Vector3(0.1, 0.17, float(p.torso_d) * 0.86), robe.darkened(0.035), Vector3(0, 0, side * 0.18))
		_add_box("sash", Vector3(side * 0.14, -0.405, -float(p.torso_d) * 0.46), Vector3(0.23, 0.035, 0.035), trim, Vector3(0, 0, side * 0.08))
	_add_box("sash", Vector3(0, 0.03, 0), Vector3(float(p.hip) + 0.17, 0.11, float(p.torso_d)), sash)
	_add_box("sash", Vector3(0, 0.085, -float(p.torso_d) * 0.5), Vector3(float(p.hip) + 0.18, 0.032, 0.03), trim)
	_add_box("sash", Vector3(0.02, -0.18, -float(p.torso_d) * 0.54), Vector3(0.055, 0.34, 0.035), trim, Vector3(0.1, 0, -0.04))
	# Oversized wrapped gauntlets are one of Catalyst's clearest identifiers.
	# The colored rune bands stay asymmetric exactly like the sheet.
	for side_name in ["l", "r"]:
		_add_taper("forearm_" + side_name, Vector3(0, -0.035, 0), Vector3(0, -0.345, 0), Vector2(0.145, 0.14), Vector2(0.122, 0.12), tape_a)
		for i in 5:
			var wrap_color := tape_a if i % 2 == 0 else tape_b
			_add_taper("forearm_" + side_name, Vector3(0, -0.045 - i * 0.061, 0), Vector3(0, -0.08 - i * 0.061, 0), Vector2(0.151, 0.146), Vector2(0.147, 0.142), wrap_color)
		var rune_color := _color("ink_left", Color(1.0, 0.45, 0.1)) if side_name == "l" else _color("ink_right", Color(0.55, 0.3, 1.0))
		for rune_row in 2:
			_add_box("forearm_" + side_name, Vector3(0, -0.145 - rune_row * 0.122, -0.149), Vector3(0.21, 0.032, 0.018), rune_color)
			_add_box("forearm_" + side_name, Vector3((-0.075 if rune_row == 0 else 0.075), -0.145 - rune_row * 0.122, -0.16), Vector3(0.028, 0.066, 0.018), rune_color)
		for finger in 4:
			_add_box("hand_" + side_name, Vector3((finger - 1.5) * 0.035, -0.075, -0.085), Vector3(0.03, 0.09, 0.035), skin)
		# Bare knees and tall dark boots with pale cuffs and straps.
		_add_ellipsoid("thigh_" + side_name, Vector3(0, -float(p.upper_leg) * 0.48, 0), Vector3(0.135, float(p.upper_leg) * 0.46, 0.13), skin)
		_add_box("shin_" + side_name, Vector3(0, -float(p.lower_leg) * 0.55, 0), Vector3(float(p.leg_w) * 0.92, float(p.lower_leg) * 0.76, float(p.leg_w) * 0.9), robe.darkened(0.01))
		_add_box("shin_" + side_name, Vector3(0, -0.085, 0), Vector3(float(p.leg_w) * 1.0, 0.08, float(p.leg_w) * 0.94), trim)
		for strap in 2:
			_add_box("shin_" + side_name, Vector3(0, -0.21 - strap * 0.1, -float(p.leg_w) * 0.48), Vector3(float(p.leg_w) * 0.96, 0.038, 0.025), sash.lightened(0.06))
	var white := Color(0.84, 0.83, 0.8)
	# Huge swept mane: a rear mass plus long tapered locks framing, but never
	# covering, the face. This is intentionally much wider than the skull.
	_add_ellipsoid("hair", Vector3(0, 0.28, 0.13), Vector3(0.19, 0.145, 0.19), white.darkened(0.025))
	_add_ellipsoid("hair", Vector3(-0.16, 0.23, 0.11), Vector3(0.13, 0.16, 0.16), white)
	_add_ellipsoid("hair", Vector3(0.16, 0.23, 0.11), Vector3(0.13, 0.16, 0.16), white.lightened(0.02))
	for crown_lock in 7:
		var crown_x := -0.2 + crown_lock * 0.065
		_add_taper("hair", Vector3(crown_x * 0.55, 0.36, 0.04), Vector3(crown_x, 0.5 - absf(crown_lock - 3) * 0.018, 0.1 + absf(crown_lock - 3) * 0.018), Vector2(0.07, 0.065), Vector2(0.025, 0.025), white.lightened(0.025 * (crown_lock % 2)))
	for side in [-1.0, 1.0]:
		for lock in 4:
			var start := Vector3(side * (0.13 + lock * 0.018), 0.32 - lock * 0.045, 0.04 + lock * 0.025)
			var finish := Vector3(side * (0.28 + lock * 0.035), 0.12 - lock * 0.105, 0.11 + lock * 0.035)
			_add_taper("hair", start, finish, Vector2(0.065, 0.06), Vector2(0.03, 0.028), white.darkened(0.018 * lock))
		_add_taper("hair", Vector3(side * 0.18, 0.24, 0.1), Vector3(side * 0.24, -0.24, 0.14), Vector2(0.075, 0.07), Vector2(0.035, 0.032), white.darkened(0.04))
	# Heavy white eyebrows, separated moustache, and five layered beard locks
	# reproduce the face without turning the beard into a mask.
	var beard_white := Color(0.96, 0.94, 0.9)
	for side in [-1.0, 1.0]:
		_add_box("head", Vector3(side * 0.065, 0.205, -0.171), Vector3(0.11, 0.035, 0.025), beard_white, Vector3(0, 0, side * -0.2))
		_add_taper("beard", Vector3(side * 0.052, 0.085, -0.195), Vector3(side * 0.105, -0.12, -0.175), Vector2(0.07, 0.038), Vector2(0.035, 0.025), beard_white.darkened(0.015))
		_add_box("beard", Vector3(side * 0.062, 0.085, -0.208), Vector3(0.115, 0.032, 0.035), beard_white, Vector3(0, 0, side * 0.3))
	_add_taper("beard", Vector3(0, 0.055, -0.19), Vector3(0, -0.35, -0.135), Vector2(0.075, 0.048), Vector2(0.03, 0.022), beard_white)
	_add_taper("beard", Vector3(-0.07, 0.045, -0.185), Vector3(-0.105, -0.29, -0.14), Vector2(0.065, 0.04), Vector2(0.024, 0.02), beard_white.darkened(0.025))
	_add_taper("beard", Vector3(0.07, 0.045, -0.185), Vector3(0.105, -0.29, -0.14), Vector2(0.065, 0.04), Vector2(0.024, 0.02), beard_white.lightened(0.018))
	_add_taper("beard", Vector3(-0.115, 0.06, -0.17), Vector3(-0.145, -0.18, -0.135), Vector2(0.045, 0.032), Vector2(0.02, 0.018), beard_white.darkened(0.04))
	_add_taper("beard", Vector3(0.115, 0.06, -0.17), Vector3(0.145, -0.18, -0.135), Vector2(0.045, 0.032), Vector2(0.02, 0.018), beard_white.darkened(0.012))
	# Small rune marks on the wrapped fists echo the forearm bands.
	_add_box("hand_l", Vector3(0, -float(p.glove) * 0.33, -float(p.glove) * 0.5), Vector3(float(p.glove) * 0.62, float(p.glove) * 0.38, 0.025), _color("ink_left", Color(1.0, 0.45, 0.1)))
	_add_box("hand_r", Vector3(0, -float(p.glove) * 0.33, -float(p.glove) * 0.5), Vector3(float(p.glove) * 0.62, float(p.glove) * 0.38, 0.025), _color("ink_right", Color(0.55, 0.3, 1.0)))


func _add_box(bone: String, center: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	if not _boxes.has(bone):
		return
	_boxes[bone].append({
		"type": "box", "center": center, "size": size.max(Vector3.ONE * 0.008),
		"color": color, "rotation": rotation,
	})


func _add_ellipsoid(bone: String, center: Vector3, radii: Vector3, color: Color, rotation := Vector3.ZERO) -> void:
	if not _boxes.has(bone):
		return
	_boxes[bone].append({
		"type": "ellipsoid", "center": center,
		"radii": radii.max(Vector3.ONE * 0.008), "color": color,
		"rotation": rotation, "radial": ELLIPSOID_RADIAL, "rings": ELLIPSOID_RINGS,
	})


func _add_taper(bone: String, top: Vector3, bottom: Vector3, top_radius: Vector2, bottom_radius: Vector2, color: Color) -> void:
	if not _boxes.has(bone):
		return
	_boxes[bone].append({
		"type": "taper", "top": top, "bottom": bottom,
		"top_radius": top_radius.max(Vector2.ONE * 0.008),
		"bottom_radius": bottom_radius.max(Vector2.ONE * 0.008),
		"color": color, "radial": TAPER_RADIAL,
	})


func _bake_geometry() -> void:
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.76
	_material.metallic = 0.0
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for bone_name in _boxes:
		var specs: Array = _boxes[bone_name]
		if specs.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for spec in specs:
			match String(spec.type):
				"box": _emit_box(surface, spec)
				"ellipsoid": _emit_ellipsoid(surface, spec)
				"taper": _emit_taper(surface, spec)
		var mesh := surface.commit()
		if mesh == null:
			continue
		mesh.surface_set_material(0, _material)
		var instance := MeshInstance3D.new()
		instance.name = "CharacterGeometry"
		instance.mesh = mesh
		instance.layers = BODY_LAYER
		instance.material_override = _silhouette_material if silhouette_only else null
		(_bones[bone_name] as Node3D).add_child(instance)


func _emit_box(surface: SurfaceTool, spec: Dictionary) -> void:
	var half: Vector3 = (spec.size as Vector3) * 0.5
	var basis := Basis.from_euler(spec.rotation)
	var center: Vector3 = spec.center
	# Every authored slab is a chamfered 26-point solid: six inset faces,
	# twelve edge faces, and eight corner facets. This keeps clothing, shoes,
	# hair planes, and facial details polygonal without reading as raw cubes.
	var bevel := minf(half.x, minf(half.y, half.z)) * 0.34
	var inner := half - Vector3.ONE * bevel
	var color: Color = spec.color
	for sign_value in [-1.0, 1.0]:
		_emit_box_quad(surface, basis, center,
			Vector3(sign_value * half.x, -inner.y, -inner.z), Vector3(sign_value * half.x, inner.y, -inner.z),
			Vector3(sign_value * half.x, inner.y, inner.z), Vector3(sign_value * half.x, -inner.y, inner.z), color)
		_emit_box_quad(surface, basis, center,
			Vector3(-inner.x, sign_value * half.y, -inner.z), Vector3(inner.x, sign_value * half.y, -inner.z),
			Vector3(inner.x, sign_value * half.y, inner.z), Vector3(-inner.x, sign_value * half.y, inner.z), color)
		_emit_box_quad(surface, basis, center,
			Vector3(-inner.x, -inner.y, sign_value * half.z), Vector3(inner.x, -inner.y, sign_value * half.z),
			Vector3(inner.x, inner.y, sign_value * half.z), Vector3(-inner.x, inner.y, sign_value * half.z), color)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			_emit_box_quad(surface, basis, center,
				Vector3(sx * half.x, sy * inner.y, -inner.z), Vector3(sx * inner.x, sy * half.y, -inner.z),
				Vector3(sx * inner.x, sy * half.y, inner.z), Vector3(sx * half.x, sy * inner.y, inner.z), color)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_emit_box_quad(surface, basis, center,
				Vector3(sx * half.x, -inner.y, sz * inner.z), Vector3(sx * inner.x, -inner.y, sz * half.z),
				Vector3(sx * inner.x, inner.y, sz * half.z), Vector3(sx * half.x, inner.y, sz * inner.z), color)
	for sy in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_emit_box_quad(surface, basis, center,
				Vector3(-inner.x, sy * half.y, sz * inner.z), Vector3(-inner.x, sy * inner.y, sz * half.z),
				Vector3(inner.x, sy * inner.y, sz * half.z), Vector3(inner.x, sy * half.y, sz * inner.z), color)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_emit_triangle(surface,
					center + basis * Vector3(sx * half.x, sy * inner.y, sz * inner.z),
					center + basis * Vector3(sx * inner.x, sy * half.y, sz * inner.z),
					center + basis * Vector3(sx * inner.x, sy * inner.y, sz * half.z), color, center)


func _emit_box_quad(surface: SurfaceTool, basis: Basis, center: Vector3, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	var world_a := center + basis * a
	var world_b := center + basis * b
	var world_c := center + basis * c
	var world_d := center + basis * d
	_emit_triangle(surface, world_a, world_b, world_c, color, center)
	_emit_triangle(surface, world_a, world_c, world_d, color, center)


func _emit_ellipsoid(surface: SurfaceTool, spec: Dictionary) -> void:
	var radial: int = spec.radial
	var rings: int = spec.rings
	var radii: Vector3 = spec.radii
	var center: Vector3 = spec.center
	var basis := Basis.from_euler(spec.rotation)
	for ring in rings:
		var phi_0 := -PI * 0.5 + PI * ring / rings
		var phi_1 := -PI * 0.5 + PI * (ring + 1) / rings
		for segment in radial:
			var theta_0 := TAU * segment / radial
			var theta_1 := TAU * (segment + 1) / radial
			var facet_color := _facet_color(spec.color, ring * 37 + segment * 17)
			var a := center + basis * _ellipsoid_point(phi_0, theta_0, radii)
			var b := center + basis * _ellipsoid_point(phi_0, theta_1, radii)
			var c := center + basis * _ellipsoid_point(phi_1, theta_1, radii)
			var d := center + basis * _ellipsoid_point(phi_1, theta_0, radii)
			if ring > 0:
				_emit_triangle(surface, a, d, b, facet_color, center)
			if ring < rings - 1:
				_emit_triangle(surface, b, d, c, facet_color, center)


func _ellipsoid_point(phi: float, theta: float, radii: Vector3) -> Vector3:
	var ring := cos(phi)
	return Vector3(sin(theta) * ring * radii.x, sin(phi) * radii.y, cos(theta) * ring * radii.z)


func _emit_taper(surface: SurfaceTool, spec: Dictionary) -> void:
	var radial: int = spec.radial
	var top: Vector3 = spec.top
	var bottom: Vector3 = spec.bottom
	var center := (top + bottom) * 0.5
	var top_radius: Vector2 = spec.top_radius
	var bottom_radius: Vector2 = spec.bottom_radius
	for segment in radial:
		var a0 := TAU * segment / radial
		var a1 := TAU * (segment + 1) / radial
		var facet_color := _facet_color(spec.color, segment * 19)
		var top_0 := top + Vector3(sin(a0) * top_radius.x, 0, cos(a0) * top_radius.y)
		var top_1 := top + Vector3(sin(a1) * top_radius.x, 0, cos(a1) * top_radius.y)
		var bottom_0 := bottom + Vector3(sin(a0) * bottom_radius.x, 0, cos(a0) * bottom_radius.y)
		var bottom_1 := bottom + Vector3(sin(a1) * bottom_radius.x, 0, cos(a1) * bottom_radius.y)
		_emit_triangle(surface, top_0, bottom_0, top_1, facet_color, center)
		_emit_triangle(surface, top_1, bottom_0, bottom_1, facet_color, center)
		_emit_triangle(surface, top, top_1, top_0, facet_color, center)
		_emit_triangle(surface, bottom, bottom_0, bottom_1, facet_color, center)


func _facet_color(base: Color, seed_value: int) -> Color:
	var step := (seed_value * 11 + 3) % 7 - 3
	if step > 0:
		return base.lightened(float(step) * 0.009)
	if step < 0:
		return base.darkened(float(-step) * 0.009)
	return base


func _emit_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, outward_origin: Variant = null) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if outward_origin != null and normal.dot((a + b + c) / 3.0 - (outward_origin as Vector3)) < 0.0:
		normal = -normal
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.add_vertex(point)


func _build_glow() -> void:
	_glow = OmniLight3D.new()
	_glow.name = "ActionGlow"
	_glow.light_color = _color("glow", _color("accent", GameState.CLASSES[fighter_id].color))
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	_glow.position = Vector3(0, float(_profile.torso_h) * 0.45, -0.25)
	_glow.light_cull_mask = BODY_LAYER
	(_bones.chest as Node3D).add_child(_glow)


func _production_geometry() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if _production_body == null or not is_instance_valid(_production_body):
		return result
	for node in _production_body.find_children("*", "GeometryInstance3D", true, false):
		result.append(node as GeometryInstance3D)
	return result


func _apply_silhouette_material() -> void:
	if silhouette_only and _silhouette_material == null:
		_silhouette_material = StandardMaterial3D.new()
		_silhouette_material.albedo_color = Color(0.48, 0.49, 0.52)
		_silhouette_material.roughness = 1.0
	for node in _production_geometry():
		node.material_override = _silhouette_material if silhouette_only else null


func set_silhouette(enabled: bool) -> void:
	silhouette_only = enabled
	if _silhouette_material == null:
		_silhouette_material = StandardMaterial3D.new()
		_silhouette_material.albedo_color = Color(0.48, 0.49, 0.52)
		_silhouette_material.roughness = 1.0
	_apply_silhouette_material()


func set_skeleton_debug(enabled: bool) -> void:
	skeleton_debug_visible = enabled
	if _skeleton_debug:
		_skeleton_debug.visible = enabled
	if enabled:
		_update_skeleton_debug()


func approximate_triangle_count() -> int:
	var total := 0
	for node in _production_geometry():
		if not node.visible:
			continue
		if node is MultiMeshInstance3D:
			var multi_instance := node as MultiMeshInstance3D
			if multi_instance.multimesh == null or multi_instance.multimesh.mesh == null:
				continue
			var visible_count := multi_instance.multimesh.visible_instance_count
			if visible_count < 0:
				visible_count = multi_instance.multimesh.instance_count
			total += _mesh_triangle_count(multi_instance.multimesh.mesh) * visible_count
		elif node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				total += _mesh_triangle_count(mesh_instance.mesh)
	return total


func _mesh_triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface_index in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or (indices as PackedInt32Array).is_empty():
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += vertices.size() / 3
		else:
			total += (indices as PackedInt32Array).size() / 3
	return total


func _build_skeleton_debug() -> void:
	_skeleton_debug = MeshInstance3D.new()
	_skeleton_debug.name = "SkeletonDebug"
	_skeleton_debug.top_level = true
	_skeleton_debug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_skeleton_debug.layers = BODY_LAYER
	_skeleton_debug.visible = skeleton_debug_visible
	add_child(_skeleton_debug)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 0.95, 1.0)
	material.no_depth_test = true
	_skeleton_debug.material_override = material


func _update_skeleton_debug() -> void:
	if not skeleton_debug_visible or _skeleton_debug == null:
		return
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for bone_name in _bones:
		var joint: Node3D = _bones[bone_name]
		var point := joint.global_position
		var parent := joint.get_parent() as Node3D
		if parent and parent != self and parent != joint:
			lines.surface_add_vertex(parent.global_position)
			lines.surface_add_vertex(point)
		var marker_size := 0.018
		lines.surface_add_vertex(point - Vector3.RIGHT * marker_size)
		lines.surface_add_vertex(point + Vector3.RIGHT * marker_size)
		lines.surface_add_vertex(point - Vector3.UP * marker_size)
		lines.surface_add_vertex(point + Vector3.UP * marker_size)
	lines.surface_end()
	_skeleton_debug.mesh = lines


func _color(key: String, fallback: Color) -> Color:
	var value: Color = _palette.get(key, fallback)
	# The source palettes were tuned for emissive first-person gloves. Lift only
	# near-black cloth enough that seams and layers remain readable in neutral
	# full-body review lighting.
	return value.lightened(0.075) if value.get_luminance() < 0.19 else value


func _eye_color() -> Color:
	return {
		"berserker": Color(1.0, 0.35, 0.08), "counter_master": Color(0.25, 0.72, 1.0),
		"combo_master": Color(0.67, 0.38, 1.0), "free_runner": Color(0.25, 1.0, 0.4),
		"wise_guy": Color(0.18, 0.11, 0.07), "elementalist": Color(0.24, 0.15, 0.09),
	}.get(fighter_id, Color(0.2, 0.14, 0.1))


func _apply_pose() -> void:
	if _bones.is_empty():
		return
	for name in _bones:
		(_bones[name] as Node3D).transform = _rest[name]
	var u := normalized_time()
	if _knocked_down and _action == "":
		_pose_grounded(_knock_direction, 1.0)
	else:
		_pose_locomotion()
		_pose_boxing_stance()
		_pose_guard()
		_pose_style()
		if _action != "":
			_pose_action(_action, u)
	_pose_secondary()
	_sync_production_body()
	_update_skeleton_debug()
	if _glow:
		_glow.light_energy = 1.5 * sin(u * PI) if _action in ["ultimate_1", "ultimate_2"] else 0.0


func _pose_locomotion() -> void:
	var moving := _move_amount
	var pace := lerpf(5.5, 10.0, moving)
	var forward_weight := absf(_move_local.z) / maxf(absf(_move_local.x) + absf(_move_local.z), 0.001)
	var travel_sign := -signf(_move_local.z) if absf(_move_local.z) > 0.05 else 1.0
	var stride := sin(_clock * pace) * moving * travel_sign
	var lift := maxf(0.0, sin(_clock * pace * 2.0)) * moving
	if not _on_floor:
		var rising := _move_local.y > 0.0
		if rising:
			var takeoff_phase := clampf(_airborne_pose_time / 0.34, 0.0, 1.0)
			var crouch := _phase_pulse(takeoff_phase, 0.0, 0.2, 0.56)
			var extension := smoothstep(0.24, 0.9, takeoff_phase)
			_add_pos("pelvis", Vector3(0, -0.05 * crouch, 0))
			_add_rot("chest", Vector3(-0.1 * crouch + 0.04 * extension, 0, 0))
			for leg in ["thigh_l", "thigh_r"]:
				_add_rot(leg, Vector3(0.46 * crouch, 0, 0))
				_set_rot(leg, Vector3(-0.1, 0, 0), extension)
			for leg in ["shin_l", "shin_r"]:
				_add_rot(leg, Vector3(-0.86 * crouch, 0, 0))
				_set_rot(leg, Vector3(0.06, 0, 0), extension)
		else:
			_add_rot("thigh_l", Vector3(0.35, 0, 0))
			_add_rot("thigh_r", Vector3(-0.2, 0, 0))
			_add_rot("shin_l", Vector3(0.55, 0, 0))
			_add_rot("shin_r", Vector3(0.3, 0, 0))
		return
	_add_rot("thigh_l", Vector3(stride * 0.65, 0, 0))
	_add_rot("thigh_r", Vector3(-stride * 0.65, 0, 0))
	_add_rot("shin_l", Vector3(maxf(0.0, -stride) * 0.72, 0, 0))
	_add_rot("shin_r", Vector3(maxf(0.0, stride) * 0.72, 0, 0))
	var strafe := clampf(_move_local.x / 8.0, -1.0, 1.0) * (1.0 - forward_weight)
	_add_pos("pelvis", Vector3(strafe * sin(_clock * pace) * 0.03, lift * 0.025 + absf(sin(_clock * 2.0)) * 0.003, 0))
	_add_rot("chest", Vector3(0, stride * 0.08, -stride * 0.025 - strafe * 0.08))


func _pose_boxing_stance() -> void:
	if not _on_floor:
		return
	# Orthodox neutral: left lead foot and right rear foot, both set slightly
	# outside the center line. The root and pelvis height never change here.
	var weight := lerpf(1.0, 0.22, _move_amount)
	_add_rot("pelvis", Vector3(0.0, -0.14 * weight, 0.0))
	_add_rot("chest", Vector3(0.0, 0.08 * weight, -0.025 * weight))
	_add_rot("thigh_l", Vector3(0.14, -0.035, -0.055) * weight)
	_add_rot("shin_l", Vector3(-0.16, 0.0, 0.025) * weight)
	_add_rot("ankle_l", Vector3(0.04, -0.12, 0.0) * weight)
	_add_rot("foot_l", Vector3(0.0, -0.12, 0.0) * weight)
	_add_rot("thigh_r", Vector3(-0.085, 0.045, 0.06) * weight)
	_add_rot("shin_r", Vector3(-0.11, 0.0, -0.025) * weight)
	_add_rot("ankle_r", Vector3(0.035, 0.18, 0.0) * weight)
	_add_rot("foot_r", Vector3(0.0, 0.18, 0.0) * weight)


func _pose_guard() -> void:
	var tight := 1.0
	match fighter_id:
		"berserker": tight = 0.78
		"counter_master": tight = 1.18
		"combo_master": tight = 1.08
		"free_runner": tight = 0.92
		"wise_guy": tight = 0.82
		"elementalist": tight = 0.9
	for side in [-1.0, 1.0]:
		var suffix := "_l" if side < 0.0 else "_r"
		var upper_pitch := 0.62 + (tight - 1.0) * 0.18
		var forearm_pitch := 2.05 + (tight - 1.0) * 0.45
		_add_rot("clavicle" + suffix, Vector3(0, 0, -side * 0.08 * tight))
		_add_rot("upper_arm" + suffix, Vector3(upper_pitch, -side * 0.12, side * 0.18 * tight))
		_add_rot("forearm" + suffix, Vector3(forearm_pitch, side * 0.08, -side * 0.12))
		_add_rot("wrist" + suffix, Vector3(-0.12, 0, side * 0.08))


func _pose_style() -> void:
	var breathe := sin(_clock * 2.1)
	match fighter_id:
		"berserker":
			_add_rot("chest", Vector3(-0.08 + breathe * 0.012, 0, 0))
			_add_rot("pelvis", Vector3(0.04, 0, 0))
		"counter_master":
			_add_rot("chest", Vector3(0, sin(_clock * 0.9) * 0.018, 0))
		"combo_master":
			_add_pos("pelvis", Vector3(0, absf(sin(_clock * 3.1)) * 0.018, 0))
			_add_rot("chest", Vector3(0.04, sin(_clock * 2.2) * 0.04, 0))
		"free_runner":
			_add_rot("pelvis", Vector3(0.09, 0.08, -0.035))
			_add_rot("chest", Vector3(-0.07, -0.08, 0.04))
		"wise_guy":
			_add_rot("chest", Vector3(0.12, 0.04, -0.045))
			_add_rot("head", Vector3(-0.04, -0.08, 0.03))
		"elementalist":
			_add_rot("chest", Vector3(-0.035 + breathe * 0.018, 0, 0))


func _pose_action(action: String, u: float) -> void:
	if action in LOCOMOTION_ACTIONS:
		_pose_locomotion_preview(action, u)
	elif action.begins_with("jab_") or action.begins_with("cross_"):
		_pose_straight(action, u)
	elif action.begins_with("hook_"):
		_pose_hook(action, u)
	elif action.begins_with("uppercut_"):
		_pose_uppercut(action, u)
	elif action in ["slip_left", "slip_right", "roll_left", "roll_right", "back_step", "block", "guard_break"]:
		_pose_defense(action, u)
	elif action.begins_with("hit_"):
		_pose_hit(action, u)
	elif action.begins_with("knockdown_"):
		_pose_grounded(action.trim_prefix("knockdown_"), _smooth(u))
	elif action == "grounded_face_up":
		_pose_grounded("back", 1.0)
	elif action == "grounded_face_down":
		_pose_grounded("front", 1.0)
	elif action in ["get_up", "get_up_face_up", "get_up_face_down"]:
		_pose_grounded(_knock_direction, 1.0 - _smooth(u))
	elif action in ["ultimate_1", "ultimate_2"]:
		_pose_ultimate(action, u)
	elif action == "taunt":
		_pose_taunt(u)


func _pose_locomotion_preview(action: String, u: float) -> void:
	var cycle := sin(u * TAU)
	var double_cycle := maxf(0.0, sin(u * TAU * 2.0))
	match action:
		"idle":
			# Neutral remains a boxing stance; breathing relaxes the torso without
			# dropping either hand away from the face.
			_add_rot("chest", Vector3(sin(u * TAU) * 0.018, 0.0, 0.0))
		"guard":
			pass
		"walk", "walk_forward":
			_preview_stride(cycle, double_cycle, 0.62, -1.0)
		"walk_backward":
			_preview_stride(-cycle, double_cycle, 0.48, 1.0)
		"strafe_left", "strafe_right":
			var side := -1.0 if action == "strafe_left" else 1.0
			_preview_stride(cycle, double_cycle, 0.42, 0.0)
			_add_pos("pelvis", Vector3(side * cycle * 0.045, double_cycle * 0.016, 0))
			_add_rot("chest", Vector3(0, -side * cycle * 0.06, -side * 0.07))
		"run":
			_preview_stride(cycle, double_cycle, 0.92, -1.0)
			_add_rot("chest", Vector3(-0.16, cycle * 0.09, 0))
		"jump", "jump_start":
			# Load through both knees first, then straighten the legs into takeoff.
			# The root never moves down: the crouch comes from the knees and abs.
			var crouch := _phase_pulse(u, 0.0, 0.18, 0.42)
			var extension := smoothstep(0.2, 0.62, u)
			var launch_phase := clampf((u - 0.2) / 0.8, 0.0, 1.0)
			var lift := sin(launch_phase * PI) if action == "jump" else extension
			_add_pos("pelvis", Vector3(0, lift * 0.16 - crouch * 0.055, -lift * 0.04))
			_add_rot("chest", Vector3(-0.11 * crouch + 0.05 * extension, 0, 0))
			for leg in ["thigh_l", "thigh_r"]:
				_add_rot(leg, Vector3(0.48 * crouch, 0, 0))
				_set_rot(leg, Vector3(-0.1, 0, 0), extension)
			for leg in ["shin_l", "shin_r"]:
				_add_rot(leg, Vector3(-0.88 * crouch, 0, 0))
				_set_rot(leg, Vector3(0.06, 0, 0), extension)
		"airborne", "fall":
			var float_amount := 0.82 if action == "airborne" else 1.0
			_add_pos("pelvis", Vector3(0, 0.08 + sin(u * TAU) * 0.025, 0))
			_add_rot("thigh_l", Vector3(0.48 * float_amount, 0, 0))
			_add_rot("thigh_r", Vector3(-0.28 * float_amount, 0, 0))
			_add_rot("shin_l", Vector3(-0.75, 0, 0))
			_add_rot("chest", Vector3(0.1 if action == "fall" else -0.08, 0, 0))
		"land":
			var compression := sin(u * PI)
			_add_pos("pelvis", Vector3(0, 0.0, 0.05 * compression))
			_add_rot("thigh_l", Vector3(0.62 * compression, 0, 0))
			_add_rot("thigh_r", Vector3(0.62 * compression, 0, 0))
			_add_rot("shin_l", Vector3(-1.0 * compression, 0, 0))
			_add_rot("shin_r", Vector3(-1.0 * compression, 0, 0))
		"turn_left", "turn_right":
			var turn_side := -1.0 if action == "turn_left" else 1.0
			_add_rot("pelvis", Vector3(0, turn_side * sin(u * PI) * 0.34, 0))
			_add_rot("chest", Vector3(0, turn_side * sin(u * PI) * 0.28, 0))
			_add_rot("head", Vector3(0, turn_side * sin(u * PI) * 0.2, 0))
		"guard_raise", "guard_lower":
			var lower_weight := (1.0 - _smooth(u)) if action == "guard_raise" else _smooth(u)
			for side in [-1.0, 1.0]:
				var suffix := "_l" if side < 0.0 else "_r"
				_set_rot("upper_arm" + suffix, Vector3(0.12, 0, side * 0.04), lower_weight)
				_set_rot("forearm" + suffix, Vector3(0.2, 0, 0), lower_weight)


func _preview_stride(cycle: float, lift: float, amplitude: float, forward_sign: float) -> void:
	_add_rot("thigh_l", Vector3(cycle * amplitude, 0, 0))
	_add_rot("thigh_r", Vector3(-cycle * amplitude, 0, 0))
	_add_rot("shin_l", Vector3(-maxf(0.0, -cycle) * amplitude, 0, 0))
	_add_rot("shin_r", Vector3(-maxf(0.0, cycle) * amplitude, 0, 0))
	_add_pos("pelvis", Vector3(0, lift * 0.028, forward_sign * absf(cycle) * 0.018))
	_add_rot("chest", Vector3(0, cycle * 0.08, -cycle * 0.025))


func _pose_straight(action: String, u: float) -> void:
	var left := action.ends_with("left")
	var suffix := "_l" if left else "_r"
	var side := -1.0 if left else 1.0
	var impact := float(_command.get("impact_fraction", 0.4))
	var strike := _attack_curve(u, impact)
	var wind := _windup_curve(u, impact)
	_set_rot("upper_arm" + suffix, Vector3(1.47, -side * 0.04, side * 0.08), strike)
	_set_rot("forearm" + suffix, Vector3(0.08, side * 0.02, 0), strike)
	_add_rot("upper_arm" + suffix, Vector3(-0.18, side * 0.13, side * 0.12) * wind)
	_add_rot("chest", Vector3(0, -side * (0.22 if action.begins_with("cross") else 0.1) * strike, side * 0.04 * strike))
	_add_rot("pelvis", Vector3(0, side * 0.08 * strike, 0))
	_add_pos("pelvis", Vector3(0.0, 0.0, 0.025 * wind - 0.035 * strike))


func _pose_hook(action: String, u: float) -> void:
	var left := action.ends_with("left")
	var suffix := "_l" if left else "_r"
	var side := -1.0 if left else 1.0
	var wind := _phase_pulse(u, 0.0, 0.18, 0.36)
	var open := _phase_pulse(u, 0.18, 0.31, 0.48)
	var strike := _delayed_attack_curve(u, 0.31, 0.54)
	# Keep the fist at the cheek during the load. The elbow then opens to the
	# punching side before the forearm wraps inward toward the center line.
	_add_rot("upper_arm" + suffix, Vector3(-0.10, side * 0.20, -side * 0.08) * wind)
	_add_rot("forearm" + suffix, Vector3(0.08, -side * 0.06, side * 0.05) * wind)
	_set_rot("upper_arm" + suffix, Vector3(0.96, -side * 0.22, side * 0.62), open)
	_set_rot("forearm" + suffix, Vector3(1.34, side * 0.06, side * 0.06), open)
	_set_rot("upper_arm" + suffix, Vector3(1.12, -side * 0.28, -side * 0.55), strike)
	_set_rot("forearm" + suffix, Vector3(1.10, side * 0.12, -side * 0.36), strike)
	_add_rot("wrist" + suffix, Vector3(0.0, -side * 0.12 * strike, -side * 0.08 * strike))
	# Turn only slightly toward the hooking side; the arm supplies the arc.
	_add_rot("chest", Vector3(-0.04 * strike, side * 0.16 * wind - side * 0.34 * strike, side * 0.08 * strike))
	_add_rot("pelvis", Vector3(0.0, side * 0.10 * wind - side * 0.18 * strike, 0.0))
	_add_pos("pelvis", Vector3(side * 0.025 * strike, 0.0, 0.035 * wind - 0.05 * strike))


func _pose_uppercut(action: String, u: float) -> void:
	var left := action.ends_with("left")
	var suffix := "_l" if left else "_r"
	var side := -1.0 if left else 1.0
	var wind := _phase_pulse(u, 0.0, 0.20, 0.42)
	var strike := _delayed_attack_curve(u, 0.27, 0.57)
	# Cave toward the punching side while the elbow drops under the fist. Legs,
	# hips and trunk then unwind upward into the shot without sinking the pelvis.
	_add_rot("upper_arm" + suffix, Vector3(-0.24, side * 0.10, -side * 0.13) * wind)
	_add_rot("forearm" + suffix, Vector3(-0.30, 0.0, side * 0.08) * wind)
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
	# Keep the finish narrow and vertical.  The shoulder drives under the glove
	# instead of throwing the arm wide like a rising hook.
	_set_rot("upper_arm" + suffix, Vector3(1.52, -side * 0.10, side * 0.08), strike)
	_set_rot("forearm" + suffix, Vector3(0.26, 0.0, -side * 0.12), strike)
	_add_rot("wrist" + suffix, Vector3(0.16 * strike, 0.0, -side * 0.08 * strike))


func _pose_defense(action: String, u: float) -> void:
	var pulse := sin(u * PI)
	var side := -1.0 if action.ends_with("left") else 1.0
	match action:
		"slip_left", "slip_right":
			# Lead with the head and thoracic spine: forward/down, then turn the
			# same-side shoulder through the slip while hips stay underneath.
			_add_pos("head", Vector3(side * 0.085, -0.045, -0.065) * pulse)
			_add_pos("pelvis", Vector3(side * 0.035, 0.0, -0.015) * pulse)
			_add_rot("spine", Vector3(-0.08, side * 0.16, side * 0.08) * pulse)
			_add_rot("chest", Vector3(-0.12, side * 0.30, side * 0.19) * pulse)
			_add_rot("head", Vector3(-0.06, -side * 0.13, -side * 0.12) * pulse)
			_add_rot("clavicle_l" if side < 0.0 else "clavicle_r", Vector3(0.05, side * 0.08, -side * 0.09) * pulse)
		"roll_left", "roll_right":
			_pose_roll(side, u)
		"back_step":
			_add_pos("pelvis", Vector3(0, 0.0, 0.22 * pulse))
			_add_rot("chest", Vector3(-0.18 * pulse, 0, 0))
		"block":
			for suffix in ["_l", "_r"]:
				_set_rot("upper_arm" + suffix, Vector3(0.85, 0, 0), pulse)
				_set_rot("forearm" + suffix, Vector3(1.75, 0, 0), pulse)
			_add_rot("chest", Vector3(0.2 * pulse, 0, 0))
		"guard_break":
			_add_rot("chest", Vector3(0.42 * pulse, 0, 0.18 * pulse))
			_add_rot("upper_arm_l", Vector3(-0.5 * pulse, 0, -0.45 * pulse))
			_add_rot("upper_arm_r", Vector3(-0.5 * pulse, 0, 0.45 * pulse))


func _pose_roll(start_side: float, u: float) -> void:
	# Full ellipse: head moves to the starting side, compresses through the
	# knees and abs, crosses to the far side, then rises back into guard.
	var theta := clampf(u, 0.0, 1.0) * TAU
	var lateral := start_side * sin(theta)
	var compression := (1.0 - cos(theta)) * 0.5
	_add_pos("head", Vector3(lateral * 0.12, -compression * 0.07, -compression * 0.075))
	_add_pos("pelvis", Vector3(lateral * 0.055, 0.0, -compression * 0.025))
	_add_rot("spine", Vector3(-0.28 * compression, lateral * 0.12, -lateral * 0.16))
	_add_rot("chest", Vector3(-0.52 * compression, lateral * 0.22, -lateral * 0.34))
	_add_rot("head", Vector3(0.18 * compression, -lateral * 0.12, lateral * 0.12))
	for leg in ["thigh_l", "thigh_r"]:
		_add_rot(leg, Vector3(0.52 * compression, 0.0, 0.0))
	for leg in ["shin_l", "shin_r"]:
		_add_rot(leg, Vector3(-0.88 * compression, 0.0, 0.0))


func _pose_hit(action: String, u: float) -> void:
	var pulse := sin(u * PI)
	var heavy := 1.55 if action.ends_with("_heavy") else 1.0
	var side := 0.0
	if action.begins_with("hit_left"): side = -1.0
	elif action.begins_with("hit_right"): side = 1.0
	var back := -1.0 if action.begins_with("hit_back") else 1.0
	_add_pos("pelvis", Vector3(-side * 0.11, 0, 0.12 * back) * pulse * heavy)
	_add_rot("chest", Vector3(0.34 * back, -side * 0.48, side * 0.22) * pulse * heavy)
	_add_rot("head", Vector3(0.22 * back, -side * 0.36, side * 0.28) * pulse * heavy)
	_add_rot("upper_arm_l", Vector3(-0.28, 0, -0.28) * pulse * heavy)
	_add_rot("upper_arm_r", Vector3(-0.28, 0, 0.28) * pulse * heavy)


func _pose_grounded(direction: String, amount: float) -> void:
	var side := -1.0 if direction == "left" else (1.0 if direction == "right" else 1.0)
	var forward := direction == "front"
	var root: Node3D = _bones.root
	var roll := (1.45 * side) if direction in ["left", "right"] else (Vector3(1.0, 0, 0) * (1.45 if forward else -1.45)).x
	if direction in ["front", "back"]:
		root.rotation.x += roll * amount
	else:
		root.rotation.z += roll * amount
	root.position += Vector3(0.18 * side if direction in ["left", "right"] else 0, 0.16 * amount, 0.28 * amount if forward else -0.12 * amount)
	_add_rot("thigh_l", Vector3(0.55 * amount, 0, 0.18 * amount))
	_add_rot("shin_l", Vector3(-0.82 * amount, 0, 0))
	_add_rot("thigh_r", Vector3(0.28 * amount, 0, -0.2 * amount))
	_add_rot("shin_r", Vector3(-0.5 * amount, 0, 0))


func _pose_ultimate(action: String, u: float) -> void:
	var charge := smoothstep(0.0, 0.6, minf(u / 0.5, 1.0))
	var release := smoothstep(0.0, 1.0, clampf((u - 0.45) / 0.25, 0.0, 1.0))
	var second := action == "ultimate_2"
	match fighter_id:
		"berserker":
			if second:
				_pose_defense("block", u)
			else:
				_pose_uppercut("uppercut_right", clampf((u - 0.25) / 0.6, 0.0, 1.0))
			_add_pos("pelvis", Vector3(0, 0.0, 0.08 * charge - 0.16 * release))
		"counter_master":
			if second:
				# Flow State: loose, continuous evasive weave with both hands ready.
				_pose_defense("roll_left" if int(u * 6.0) % 2 == 0 else "roll_right", fposmod(u * 3.0, 1.0))
				_add_rot("chest", Vector3(-0.08, sin(u * TAU) * 0.16, 0))
			else:
				# Riposte: one tight slip feeding directly into the counter hook.
				_pose_defense("slip_left", clampf(u * 2.2, 0.0, 1.0))
				_pose_hook("hook_right", clampf((u - 0.35) / 0.6, 0.0, 1.0))
		"combo_master":
			if second:
				# Unbroken: coiled stance with an accelerating full-body bounce.
				_add_pos("pelvis", Vector3(0, absf(sin(u * TAU * 3.0)) * 0.1, 0))
				_add_rot("chest", Vector3(-0.1, sin(u * TAU * 2.0) * 0.18, 0))
			else:
				# Temporal Break: impossible alternating punches while everyone stops.
				_add_pos("pelvis", Vector3(0, sin(u * PI) * 0.12, 0))
				_pose_straight("jab_left" if int(u * 12.0) % 2 == 0 else "cross_right", fposmod(u * 6.0, 1.0))
		"free_runner":
			if second:
				# Hype Train: unmistakable forward sprint/bowl posture.
				_add_rot("chest", Vector3(-0.48 * charge, 0, 0))
				_add_rot("thigh_l", Vector3(sin(u * TAU * 3.0) * 0.75, 0, 0))
				_add_rot("thigh_r", Vector3(-sin(u * TAU * 3.0) * 0.75, 0, 0))
			else:
				# Highlight Reel: spin through the final airborne haymaker.
				_add_rot("chest", Vector3(-0.2 * charge, -release * 0.8, 0))
				_pose_hook("hook_right", clampf((u - 0.35) / 0.6, 0.0, 1.0))
		"wise_guy":
			if second:
				# The Family: arms spread as if welcoming the goons into the ring.
				_set_rot("upper_arm_l", Vector3(1.0, 0.55, -0.75), charge)
				_set_rot("forearm_l", Vector3(0.45, 0, 0.15), charge)
				_set_rot("upper_arm_r", Vector3(1.0, -0.55, 0.75), charge)
				_set_rot("forearm_r", Vector3(0.45, 0, -0.15), charge)
				_add_rot("head", Vector3(0, sin(u * TAU) * 0.18, 0))
			else:
				# Big Mouth: point and jaw at the target.
				_pose_taunt(u)
		"elementalist":
			if second:
				# Flame Burst: gather low, then throw both rune fists wide.
				_add_pos("pelvis", Vector3(0, 0.0, 0.07 * charge - 0.04 * release))
				_set_rot("upper_arm_l", Vector3(0.65, 0.6, -0.85), release)
				_set_rot("forearm_l", Vector3(0.35, 0, 0.2), release)
				_set_rot("upper_arm_r", Vector3(0.65, -0.6, 0.85), release)
				_set_rot("forearm_r", Vector3(0.35, 0, -0.2), release)
			else:
				# Elemental Fists: present both independently glowing hands.
				for suffix in ["_l", "_r"]:
					_set_rot("upper_arm" + suffix, Vector3(1.2, 0, 0), charge)
					_set_rot("forearm" + suffix, Vector3(0.45, 0, 0), charge)
				_add_rot("chest", Vector3(-0.18 * charge, release * TAU * 0.12, 0))


func _pose_taunt(u: float) -> void:
	var pulse := sin(u * PI)
	match fighter_id:
		"wise_guy":
			_set_rot("upper_arm_r", Vector3(0.95, -0.55, 0.42), pulse)
			_set_rot("forearm_r", Vector3(0.5, 0, -0.25), pulse)
			_add_rot("head", Vector3(0, -0.16 * pulse, 0.08 * pulse))
		"berserker":
			_add_rot("chest", Vector3(-0.22 * pulse, 0, 0))
			_add_rot("upper_arm_l", Vector3(-0.4 * pulse, 0, -0.5 * pulse))
			_add_rot("upper_arm_r", Vector3(-0.4 * pulse, 0, 0.5 * pulse))
		_:
			_set_rot("upper_arm_l", Vector3(1.0, 0.35, -0.45), pulse)
			_set_rot("forearm_l", Vector3(0.55, 0, 0.2), pulse)
			_add_rot("head", Vector3(0, 0.18 * pulse, -0.08 * pulse))


func _pose_secondary() -> void:
	var sway := sin(_clock * 3.0) * (0.03 + _move_amount * 0.08)
	_add_rot("sash", Vector3(sway, 0, sway * 0.35))
	_add_rot("hair", Vector3(-sway * 0.3, 0, 0))
	_add_rot("beard", Vector3(-sway * 0.45, 0, 0))
	_add_rot("headband_tail_l", Vector3(sway * 1.2, 0, -sway * 0.4))
	_add_rot("headband_tail_r", Vector3(sway * 0.9, 0, sway * 0.35))


func _locomotion_name() -> String:
	if not _on_floor:
		return "jump" if _move_local.y > 0.0 else "fall"
	if _move_amount > 0.72:
		return "run"
	if _move_amount > 0.06:
		if absf(_move_local.x) > absf(_move_local.z) * 1.15:
			return "strafe_right" if _move_local.x > 0.0 else "strafe_left"
		return "walk_backward" if _move_local.z > 0.0 else "walk_forward"
	return "guard"


func _set_rot(name: String, target: Vector3, weight: float) -> void:
	if not _bones.has(name):
		return
	var node: Node3D = _bones[name]
	var rest_rot: Vector3 = (_rest[name] as Transform3D).basis.get_euler()
	node.rotation = node.rotation.lerp(rest_rot + target, clampf(weight, 0.0, 1.0))


func _add_rot(name: String, amount: Vector3) -> void:
	if _bones.has(name):
		(_bones[name] as Node3D).rotation += amount


func _add_pos(name: String, amount: Vector3) -> void:
	if _bones.has(name):
		(_bones[name] as Node3D).position += amount


func _smooth(value: float) -> float:
	return smoothstep(0.0, 1.0, clampf(value, 0.0, 1.0))


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
