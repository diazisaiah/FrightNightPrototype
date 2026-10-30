extends Node
## Exports a clean 3:4 reference of the actual production PlayerBody used by
## the playable third-person fighter.  The Character Lab adapter supplies the
## pose, but all visible geometry and paint come from production PlayerBody.

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")
const CAPTURE_SIZE := Vector2i(768, 1024)


func _ready() -> void:
	var fighter := "counter_master"
	var action := "guard"
	var phase := 0.25
	var yaw := -18.0
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--fighter" and index + 1 < args.size():
			fighter = args[index + 1]
		elif args[index] == "--action" and index + 1 < args.size():
			action = args[index + 1]
		elif args[index] == "--phase" and index + 1 < args.size():
			phase = clampf(float(args[index + 1]), 0.0, 0.999)
		elif args[index] == "--yaw" and index + 1 < args.size():
			yaw = float(args[index + 1])
	if fighter not in PlaygroundFighterAvatar.FIGHTERS:
		push_error("Unknown runtime card-art fighter id: %s" % fighter)
		get_tree().quit(2)
		return
	if action not in PlaygroundFighterAvatar.ACTIONS:
		push_error("Unknown runtime card-art action: %s" % action)
		get_tree().quit(2)
		return

	var viewport := SubViewport.new()
	viewport.name = "RuntimeCardArtViewport"
	viewport.size = CAPTURE_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var stage := Node3D.new()
	viewport.add_child(stage)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.012, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.47, 0.52, 0.62)
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color(1.0, 0.84, 0.7)
	key.light_energy = 1.65
	key.shadow_enabled = true
	stage.add_child(key)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.35, 1.35, -2.4)
	fill.light_color = Color(0.53, 0.72, 1.0)
	fill.light_energy = 2.25
	fill.omni_range = 6.0
	stage.add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-18, 150, 0)
	rim.light_color = Color(0.18, 0.66, 1.0)
	rim.light_energy = 1.05
	stage.add_child(rim)

	var avatar: PlaygroundFighterAvatar = AvatarScript.new(fighter, "")
	stage.add_child(avatar)
	# Card references show the canonical fighter, not the cosmetic currently
	# equipped in the playground save.
	avatar._production_body.wear_hat("")
	avatar.rotation_degrees.y = yaw
	avatar.preview(action)
	avatar.paused = true
	avatar._action_time = avatar._action_duration * phase
	avatar._apply_pose()

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.15, -4.0)
	camera.fov = 35.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.12, 0.0), Vector3.UP)
	camera.make_current()

	for unused in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("user://character_lab_captures")
	DirAccess.make_dir_recursive_absolute(folder)
	var output := folder.path_join("runtime_card_%s_%s_%03d.png" % [fighter, action, int(phase * 100.0)])
	var error := image.save_png(output)
	print("RUNTIME_CARD_ART_CAPTURE=", output, " error=", error,
			" size=", image.get_width(), "x", image.get_height(),
			" triangles=", avatar.approximate_triangle_count())
	get_tree().quit(0 if error == OK else 1)
