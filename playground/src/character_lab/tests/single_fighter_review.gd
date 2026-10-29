extends Node3D
## Dense visual QA capture that loads one fighter at a time. Keeping only one
## high-resolution avatar resident mirrors the Character Lab and avoids making
## the six-up smoke test responsible for art-review renders.

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")


func _ready() -> void:
	var fighter := "berserker"
	var action := "idle"
	var phase := 0.25
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--fighter" and index + 1 < args.size():
			fighter = args[index + 1]
		elif args[index] == "--action" and index + 1 < args.size():
			action = args[index + 1]
		elif args[index] == "--phase" and index + 1 < args.size():
			phase = clampf(float(args[index + 1]), 0.0, 0.999)
	if fighter not in PlaygroundFighterAvatar.FIGHTERS:
		push_error("Unknown fighter review id: %s" % fighter)
		get_tree().quit(2)
		return
	if action not in PlaygroundFighterAvatar.ACTIONS:
		push_error("Unknown animation review action: %s" % action)
		get_tree().quit(2)
		return

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.014, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.61, 0.68)
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -18, 0)
	key.light_color = Color(1.0, 0.86, 0.72)
	key.light_energy = 1.45
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.4, 1.7, -2.5)
	fill.light_color = Color(0.78, 0.88, 1.0)
	fill.light_energy = 2.1
	fill.omni_range = 7.0
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 155, 0)
	rim.light_color = Color(0.4, 0.58, 1.0)
	rim.light_energy = 0.5
	add_child(rim)

	var avatar: PlaygroundFighterAvatar = AvatarScript.new(fighter, "")
	add_child(avatar)
	avatar.preview(action)
	avatar.paused = true
	avatar._action_time = avatar._action_duration * phase
	avatar._apply_pose()

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(4.2, 0.08, 3.2)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.065, 0.07, 0.085)
	floor_material.roughness = 0.95
	floor_box.material = floor_material
	floor_mesh.mesh = floor_box
	floor_mesh.position.y = -0.06
	add_child(floor_mesh)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.3, -3.55)
	camera.fov = 40.0
	add_child(camera)
	camera.look_at(Vector3(0, 1.02, 0), Vector3.UP)
	camera.make_current()

	for unused in 5:
		await get_tree().process_frame
	var folder := ProjectSettings.globalize_path("user://character_lab_captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var review_path := folder.path_join("single_review_%s_%s_%03d.png" % [fighter, action, int(phase * 100.0)])
	var error := get_viewport().get_texture().get_image().save_png(review_path)
	print("CHARACTER_LAB_SINGLE_REVIEW=", review_path, " error=", error,
			" triangles=", avatar.approximate_triangle_count(),
			" fps=", int(Performance.get_monitor(Performance.TIME_FPS)))
	get_tree().quit(0 if error == OK else 1)

