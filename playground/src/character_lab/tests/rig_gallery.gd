extends Node3D
## Visual smoke-test scene for the six playground rigs. Run directly with:
## godot --path playground/project res://playground/character_lab/tests/rig_gallery.tscn
## It writes default and alternate galleries to user://character_lab_captures/.

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")


func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.018, 0.022, 0.032)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.5, 0.62)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color(1.0, 0.85, 0.72)
	key.light_energy = 1.25
	key.shadow_enabled = true
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 0)
	rim.light_color = Color(0.42, 0.62, 1.0)
	rim.light_energy = 0.55
	add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.5, -4.0)
	fill.light_color = Color(1.0, 0.88, 0.78)
	fill.light_energy = 3.0
	fill.omni_range = 11.0
	add_child(fill)

	var actions := ["guard", "jab_left", "hook_right", "roll_left", "taunt", "ultimate_1"]
	var lab_avatars: Array[PlaygroundFighterAvatar] = []
	for i in PlaygroundFighterAvatar.FIGHTERS.size():
		var avatar: PlaygroundFighterAvatar = AvatarScript.new(PlaygroundFighterAvatar.FIGHTERS[i], "")
		avatar.position = Vector3((i % 3 - 1) * 2.0 + (0.28 if i >= 3 else 0.0), 0, (i / 3) * 2.1 - 0.55)
		add_child(avatar)
		lab_avatars.append(avatar)
		if actions[i] != "guard":
			avatar.preview(actions[i])
			avatar.paused = true
			avatar._action_time = avatar._action_duration * 0.48
			avatar._apply_pose()

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(7.0, 0.08, 6.2)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.075, 0.085, 0.11)
	floor_material.roughness = 0.95
	floor_box.material = floor_material
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.06
	add_child(floor_mesh)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.05, -6.6)
	camera.fov = 44.0
	add_child(camera)
	camera.look_at(Vector3(0, 0.92, 0.55), Vector3.UP)
	camera.make_current()

	for unused in 8:
		await get_tree().process_frame
	var folder := ProjectSettings.globalize_path("user://character_lab_captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var default_path := folder.path_join("rig_gallery_default.png")
	var error := get_viewport().get_texture().get_image().save_png(default_path)
	print("CHARACTER_LAB_GALLERY_DEFAULT=", default_path, " error=", error,
			" fps=", int(Performance.get_monitor(Performance.TIME_FPS)),
			" draws=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			" primitives=", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	# Stable close front views make geometry regressions visible instead of
	# relying only on the six-character overview.
	for focus in lab_avatars:
		focus.rebuild(focus.fighter_id, focus.skin_id)
		focus.preview("idle")
		focus._action_time = focus._action_duration * 0.25
		focus.paused = true
		focus._apply_pose()
		for candidate in lab_avatars:
			candidate.visible = candidate == focus
		camera.position = focus.position + Vector3(0, 1.3, -3.15)
		camera.look_at(focus.position + Vector3(0, 1.05, 0), Vector3.UP)
		for unused in 4:
			await get_tree().process_frame
		var review_path := folder.path_join("rig_review_%s_default.png" % focus.fighter_id)
		get_viewport().get_texture().get_image().save_png(review_path)
	for avatar in lab_avatars:
		avatar.visible = true
	camera.position = Vector3(0, 3.05, -6.6)
	camera.look_at(Vector3(0, 0.92, 0.55), Vector3.UP)
	for avatar in lab_avatars:
		var skins: Array = Skins.of(avatar.fighter_id)
		if not skins.is_empty():
			avatar.rebuild(avatar.fighter_id, String(skins[0]))
	for unused in 8:
		await get_tree().process_frame
	var alternate_path := folder.path_join("rig_gallery_alternate.png")
	var alternate_error := get_viewport().get_texture().get_image().save_png(alternate_path)
	print("CHARACTER_LAB_GALLERY_ALTERNATE=", alternate_path, " error=", alternate_error,
			" fps=", int(Performance.get_monitor(Performance.TIME_FPS)),
			" draws=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			" primitives=", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	get_tree().quit(0 if error == OK and alternate_error == OK else 1)
