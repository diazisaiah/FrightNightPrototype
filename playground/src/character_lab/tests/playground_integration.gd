extends Node
## Exercises the real playground scene, camera handoff and inspection freeze.

const PlaygroundScene = preload("res://playground/playground.tscn")
var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var arena := PlaygroundScene.instantiate()
	add_child(arena)
	for unused in 5:
		await get_tree().process_frame
	var player: Player = arena._player
	var lab: PlaygroundCharacterLab = arena._lab
	_check(lab != null and lab.avatar != null, "Character Lab failed to initialize")

	lab.set_mode("third_person")
	await get_tree().process_frame
	_check(lab.mode == "third_person", "Third-person mode did not activate")
	_check(lab.avatar.visible, "Third-person avatar is hidden")
	_check(not player._fists.visible and not player._body.visible, "First-person or emote geometry overlaps third-person body")
	_check(lab._camera.current, "Third-person camera is not current")
	var camera_blocker := StaticBody3D.new()
	camera_blocker.collision_layer = 1
	var blocker_shape := CollisionShape3D.new()
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(1.1, 1.1, 0.35)
	blocker_shape.shape = blocker_box
	camera_blocker.add_child(blocker_shape)
	arena.add_child(camera_blocker)
	var camera_focus := player.global_position + Vector3.UP * 1.12
	camera_blocker.global_position = camera_focus + player.global_basis.z * 1.45 + Vector3.UP * 0.22
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._update_camera(1.0)
	_check(lab._camera.global_position.distance_to(camera_focus) < lab.camera_distance - 0.45, "Third-person camera did not pull inward for collision")
	camera_blocker.queue_free()
	player._punch("hook", "left")
	lab._poll_player_actions()
	_check(lab.avatar.current_action() == "hook_left", "Authoritative punch start did not drive the matching third-person windup")

	lab.play_preview("hook_right")
	await get_tree().process_frame
	_check(lab.avatar.current_action() == "hook_right", "Preview action did not reach the avatar")
	lab.spawn_remote(3)
	await get_tree().process_frame
	_check(lab._remotes.size() == 3, "Simulated remote avatars did not spawn")
	_check(lab._remotes[0].fighter_id != lab.avatar.fighter_id, "Remote command test did not create a distinct fighter")

	lab.set_mode("inspect")
	await get_tree().process_frame
	_check(not player.is_processing() and not player.is_physics_processing(), "Inspect mode did not freeze local combat")
	lab.set_view_preset("side")
	lab.set_skin("")
	await get_tree().process_frame
	lab.set_reference("alternate_voxel")
	_check(lab._reference_panel.visible, "Alternate reference did not resolve while the default skin was equipped")
	lab.set_reference("default_voxel")
	_check(lab._reference_panel.visible, "Reference panel did not load the default voxel")
	var root_id := (lab.avatar._bones.root as Node3D).get_instance_id()
	lab.avatar.preview("hook_right")
	lab.avatar._process(0.1)
	var phase_before := lab.avatar.normalized_time()
	var approved_skins: Array = Skins.of(lab.avatar.fighter_id)
	lab.set_skin(String(approved_skins[0]))
	await get_tree().process_frame
	_check((lab.avatar._bones.root as Node3D).get_instance_id() == root_id, "Live skin switching rebuilt the rig")
	var phase_after := lab.avatar.normalized_time()
	_check(lab.avatar.current_action() == "hook_right" and phase_after >= phase_before and phase_after - phase_before < 0.15, "Live skin switching reset the animation")
	_check(player._fists.skin_id == String(approved_skins[0]), "First-person hands did not receive the selected skin")
	lab.toggle_skin_comparison()
	await get_tree().process_frame
	_check(lab._comparison_avatar != null and lab._comparison_avatar.visible, "Default/alternate live comparison did not appear")
	_check(lab._comparison_avatar.skin_id != lab.avatar.skin_id, "Comparison avatar did not use the opposite skin")
	lab.next_preview()
	_check(lab.avatar.current_action() != "", "Next-animation control did not advance")
	lab.toggle_skin_comparison()
	lab.set_hud_hidden(true)
	_check(not arena._hud.visible, "HUD hide control did not hide the gameplay HUD")
	lab.set_hud_hidden(false)
	_check(arena._hud.visible, "HUD hide control did not restore the gameplay HUD")
	lab.avatar.set_skeleton_debug(true)
	lab.avatar._apply_pose()
	_check(lab.avatar._skeleton_debug.visible, "Skeleton visualization did not activate")
	var before_zoom := lab.camera_distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_check(lab.handle_input(wheel) and lab.camera_distance < before_zoom, "Mouse-wheel zoom did not work in inspect mode")

	lab.set_mode("first_person")
	await get_tree().process_frame
	_check(player.is_processing() and player.is_physics_processing(), "Leaving inspect did not restore local combat")
	_check(player._camera.current and player._fists.visible and not lab.avatar.visible, "First-person presentation did not restore cleanly")
	lab.preview_hands("open")
	_check(float(player._fists._shape.left.f) < 0.1 and float(player._fists._shape.right.f) < 0.1, "Open-hand first-person review pose did not apply")
	lab.finish_hand_preview()
	_check(float(player._fists._shape.left.f) > 0.9 and float(player._fists._shape.right.f) > 0.9, "Hand review did not restore combat fists")
	lab.clear_remotes()
	await get_tree().process_frame

	if _failures.is_empty():
		print("CHARACTER_LAB_INTEGRATION=PASS modes=3 remotes=3 reference=default_voxel")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("CHARACTER_LAB_INTEGRATION=FAIL count=", _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
