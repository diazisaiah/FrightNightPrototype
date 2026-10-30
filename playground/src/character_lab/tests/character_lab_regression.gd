extends Node
## Headless structural regression for the shared rig and command surface.

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")
const PlayerBodyScript = preload("res://fighter_body.gd")
const REQUIRED_BONES := [
	"root", "pelvis", "spine", "chest", "neck", "head",
	"clavicle_l", "upper_arm_l", "forearm_l", "wrist_l", "hand_l",
	"clavicle_r", "upper_arm_r", "forearm_r", "wrist_r", "hand_r",
	"thigh_l", "shin_l", "ankle_l", "foot_l",
	"thigh_r", "shin_r", "ankle_r", "foot_r",
	"hair", "beard", "sash", "headband_tail_l", "headband_tail_r",
]
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	for reference_map in [PlaygroundCharacterLab.DEFAULT_VOXEL, PlaygroundCharacterLab.DEFAULT_ART, PlaygroundCharacterLab.ALT_VOXEL, PlaygroundCharacterLab.ALT_ART]:
		for path in reference_map.values():
			_check(ResourceLoader.exists(String(path)), "Missing canonical Character Lab reference: %s" % path)
	for fighter in PlaygroundFighterAvatar.FIGHTERS:
		var avatar: PlaygroundFighterAvatar = AvatarScript.new(fighter, "")
		add_child(avatar)
		await get_tree().process_frame
		_check(avatar.fighter_id == fighter, "%s configured as itself" % fighter)
		var production_body := avatar.get_node_or_null("DetailedVoxelBody")
		_check(production_body != null and production_body.get_script() == PlayerBodyScript, "%s did not instantiate the actual production PlayerBody" % fighter)
		_check(avatar.find_children("CharacterGeometry", "MeshInstance3D", true, false).is_empty(), "%s still instantiated the rejected faceted Character Lab geometry" % fighter)
		_check(not avatar._production_geometry().is_empty(), "%s production PlayerBody did not finish baking" % fighter)
		_check(avatar.approximate_triangle_count() > 8000, "%s production voxel body fell below the expected geometry floor" % fighter)
		for bone in REQUIRED_BONES:
			_check(avatar._bones.has(bone), "%s missing shared joint %s" % [fighter, bone])
		for action in PlaygroundFighterAvatar.ACTIONS:
			avatar.preview(action)
			avatar._process(0.016)
			_check(avatar.current_action() != "", "%s rejected animation %s" % [fighter, action])
		var skins: Array = Skins.of(fighter)
		_check(skins.size() == 1, "%s should have exactly one approved alternate skin" % fighter)
		if not skins.is_empty():
			avatar.preview("hook_right")
			avatar._process(0.12)
			var root_id := (avatar._bones.root as Node3D).get_instance_id()
			var phase_before := avatar.normalized_time()
			avatar.set_skin(String(skins[0]))
			_check(avatar.skin_id == String(skins[0]), "%s alternate skin did not bind" % fighter)
			_check((avatar._bones.root as Node3D).get_instance_id() == root_id, "%s skin switch rebuilt the semantic rig" % fighter)
			_check(avatar.current_action() == "hook_right" and is_equal_approx(avatar.normalized_time(), phase_before), "%s skin switch reset animation phase" % fighter)
		avatar.apply_locomotion({"local_velocity": Vector3(3.0, 0, 0), "grounded": true})
		avatar._action = ""
		_check(avatar.current_action() == "strafe_right", "%s compact locomotion state was not applied" % fighter)
		var now := Time.get_ticks_msec() / 1000.0
		var markers: Array[String] = []
		avatar.effect_marker.connect(func(marker: String, _action: String, _command: Dictionary) -> void: markers.append(marker))
		avatar.play_action({"action": "ultimate_1", "duration": 2.0, "started_at": now - 0.75, "received_at": now})
		_check(absf(avatar.normalized_time() - 0.375) < 0.02, "%s late action did not seek from its timestamp" % fighter)
		avatar._process(0.5)
		_check("release" in markers and not "charge" in markers, "%s late action marker replayed stale events or missed release" % fighter)
		avatar.set_silhouette(true)
		var visible_geometry := avatar._production_geometry()
		_check(avatar.silhouette_only and not visible_geometry.is_empty() and visible_geometry[0].material_override != null, "%s silhouette view failed" % fighter)
		avatar.set_silhouette(false)
		_check(not avatar.silhouette_only and visible_geometry[0].material_override == null, "%s color view failed" % fighter)
		avatar.set_skeleton_debug(true)
		avatar._apply_pose()
		_check(avatar._skeleton_debug.visible and avatar._skeleton_debug.mesh != null, "%s skeleton debug view failed" % fighter)
		avatar.queue_free()
		await get_tree().process_frame
	await _check_boxing_motion_contract()
	if _failures.is_empty():
		print("CHARACTER_LAB_REGRESSION=PASS fighters=6 bones=29 actions=", PlaygroundFighterAvatar.ACTIONS.size())
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("CHARACTER_LAB_REGRESSION=FAIL count=", _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _check_boxing_motion_contract() -> void:
	var avatar: PlaygroundFighterAvatar = AvatarScript.new("berserker", "")
	add_child(avatar)
	await get_tree().process_frame
	var pelvis_rest: Transform3D = avatar._rest["pelvis"]
	var root_rest: Transform3D = avatar._rest["root"]
	var head_rest: Transform3D = avatar._rest["head"]

	avatar._action = ""
	avatar.apply_locomotion({"local_velocity": Vector3.ZERO, "grounded": true})
	avatar._apply_pose()
	var thigh_l := avatar._bones["thigh_l"] as Node3D
	var thigh_r := avatar._bones["thigh_r"] as Node3D
	var foot_l := avatar._bones["foot_l"] as Node3D
	var foot_r := avatar._bones["foot_r"] as Node3D
	_check(thigh_l.rotation.x > thigh_r.rotation.x, "Boxing stance did not stagger lead and rear legs")
	# 2026-10-29: the lead (left) foot points straight ahead, the rear foot
	# turns out 30-45 degrees (toe toward +X); measured with every turn above
	# the feet (pelvis, thighs, ankles) included.
	var toe_yaw := func(foot: Node3D) -> float:
		var toe := (avatar.global_basis.inverse() * foot.global_basis) * Vector3.FORWARD
		return atan2(-toe.x, -toe.z)
	var lead: float = toe_yaw.call(foot_l)
	var rear: float = toe_yaw.call(foot_r)
	_check(absf(lead) < deg_to_rad(8.0), "Boxing stance lead foot is not straight (%.0f degrees)" % rad_to_deg(lead))
	_check(rear < -deg_to_rad(30.0) and rear > -deg_to_rad(45.0), "Boxing stance rear foot is not turned out 30-45 degrees (%.0f)" % rad_to_deg(rear))
	_check((avatar._bones["pelvis"] as Node3D).position.y >= pelvis_rest.origin.y - 0.0001, "Boxing stance moved the pelvis downward")

	_set_phase(avatar, "roll_left", 0.25)
	var roll_left_x := (avatar._bones["head"] as Node3D).position.x - head_rest.origin.x
	_set_phase(avatar, "roll_left", 0.5)
	var compressed_chest_x := (avatar._bones["chest"] as Node3D).rotation.x
	var compressed_pelvis_y := (avatar._bones["pelvis"] as Node3D).position.y
	_set_phase(avatar, "roll_left", 0.75)
	var roll_right_x := (avatar._bones["head"] as Node3D).position.x - head_rest.origin.x
	_check(roll_left_x < -0.05 and roll_right_x > 0.05, "Roll did not travel left, under, then right")
	_check(compressed_chest_x < -0.35, "Roll did not bend forward through the abs")
	_check(compressed_pelvis_y >= pelvis_rest.origin.y - 0.0001, "Roll moved the pelvis downward instead of bending knees and abs")

	_set_phase(avatar, "slip_left", 0.5)
	var slip_head := (avatar._bones["head"] as Node3D).position - head_rest.origin
	var slip_chest := avatar._bones["chest"] as Node3D
	_check(slip_head.x < -0.04 and slip_head.y < -0.02 and slip_head.z < -0.03, "Left slip did not send the head left, forward, and down")
	_check(slip_chest.rotation.y < -0.08, "Left slip did not rotate through the thoracic spine")

	_set_phase(avatar, "hook_left", 0.18)
	var hook_load_z := (avatar._bones["pelvis"] as Node3D).position.z - pelvis_rest.origin.z
	_set_phase(avatar, "hook_left", 0.31)
	var hook_open_arm_z := (avatar._bones["upper_arm_l"] as Node3D).rotation.z
	_set_phase(avatar, "hook_left", 0.54)
	var hook_center_arm_z := (avatar._bones["upper_arm_l"] as Node3D).rotation.z
	var hook_turn_y := (avatar._bones["chest"] as Node3D).rotation.y
	var hook_drive_z := (avatar._bones["pelvis"] as Node3D).position.z - pelvis_rest.origin.z
	_check(hook_load_z > 0.01 and hook_drive_z < -0.02, "Hook hips did not load backward then drive forward")
	_check(hook_open_arm_z < -0.45 and hook_center_arm_z > 0.4, "Left hook did not open outside then arc back toward center")
	_check(hook_turn_y > 0.2, "Left hook did not turn the torso slightly toward the hooking side")

	_set_phase(avatar, "uppercut_left", 0.20)
	var uppercut_left_head := (avatar._bones["head"] as Node3D).position - head_rest.origin
	var uppercut_left_chest := avatar._bones["chest"] as Node3D
	var uppercut_left_pelvis := avatar._bones["pelvis"] as Node3D
	_check(uppercut_left_head.x < -0.04 and uppercut_left_head.y < -0.03, "Left uppercut did not lower the head down and left")
	_check(uppercut_left_chest.rotation.z > 0.08, "Left uppercut caved toward the wrong side")
	_check(uppercut_left_pelvis.position.y >= pelvis_rest.origin.y - 0.0001, "Left uppercut windup moved the pelvis downward")
	_set_phase(avatar, "uppercut_right", 0.20)
	var uppercut_right_head := (avatar._bones["head"] as Node3D).position - head_rest.origin
	var uppercut_right_chest := avatar._bones["chest"] as Node3D
	_check(uppercut_right_head.x > 0.04 and uppercut_right_head.y < -0.03, "Right uppercut did not lower the head down and right")
	_check(uppercut_right_chest.rotation.z < -0.08, "Right uppercut caved toward the wrong side")

	_set_phase(avatar, "jump", 0.18)
	var jump_crouch_thigh := (avatar._bones["thigh_l"] as Node3D).rotation.x
	var jump_crouch_shin := (avatar._bones["shin_l"] as Node3D).rotation.x
	var jump_crouch_pelvis_y := (avatar._bones["pelvis"] as Node3D).position.y
	var jump_crouch_root_y := (avatar._bones["root"] as Node3D).position.y
	_set_phase(avatar, "jump", 0.62)
	var jump_extended_thigh := (avatar._bones["thigh_l"] as Node3D).rotation.x
	var jump_extended_shin := (avatar._bones["shin_l"] as Node3D).rotation.x
	var jump_lift_y := (avatar._bones["pelvis"] as Node3D).position.y - pelvis_rest.origin.y
	_check(jump_crouch_thigh > 0.4 and jump_crouch_shin < -0.75, "Jump anticipation did not bend deeply through the knees")
	_check(jump_crouch_pelvis_y < pelvis_rest.origin.y - 0.04 and jump_crouch_pelvis_y > pelvis_rest.origin.y - 0.07, "Jump anticipation did not use a small controlled hip drop")
	_check(jump_crouch_root_y >= root_rest.origin.y - 0.0001, "Jump anticipation moved the character root downward")
	_check(jump_extended_thigh < 0.0 and jump_extended_shin > 0.0 and jump_lift_y > 0.12, "Jump did not extend the legs into takeoff")

	for action in ["slip_left", "roll_left", "hook_left", "uppercut_left", "uppercut_right", "jump", "land", "back_step"]:
		_set_phase(avatar, action, 0.5)
		_check((avatar._bones["root"] as Node3D).position.y >= root_rest.origin.y - 0.0001, "%s moved the character root downward" % action)
		_check((avatar._bones["pelvis"] as Node3D).position.y >= pelvis_rest.origin.y - 0.0001, "%s moved the pelvis downward" % action)

	avatar.queue_free()
	await get_tree().process_frame


func _set_phase(avatar: PlaygroundFighterAvatar, action: String, phase: float) -> void:
	avatar.preview(action)
	avatar._action_time = avatar._action_duration * clampf(phase, 0.0, 0.999)
	avatar._apply_pose()
