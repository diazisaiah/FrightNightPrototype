extends Node
## Developer visual smoke helper. Run with `-- --arena` to capture the ring,
## `-- --grade` for results, `-- --loading=N` for a contender loading screen,
## `-- --versus=CLASS,BOSS` for a versus splash, or
## `-- --action=CLASS,BOSS,HAND` for a first-person action shot. Without an option,
## captures the fight-card menu. Output stays in the project.


func _ready() -> void:
	var loading_index := -1
	var versus_class := ""
	var versus_index := 0
	var action_class := ""
	var action_index := 0
	var action_hand := "left"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--loading="):
			loading_index = clampi(int(argument.trim_prefix("--loading=")), 0, DeadLeagueRules.BOSS_COUNT - 1)
		elif argument.begins_with("--versus="):
			var parts := argument.trim_prefix("--versus=").split(",", false, 1)
			versus_class = parts[0]
			if parts.size() > 1:
				versus_index = clampi(int(parts[1]), 0, DeadLeagueRules.BOSS_COUNT - 1)
		elif argument.begins_with("--stage="):
			# A contender's stage with the contender out of the way:
			# --stage=BOSS[,YAW_DEGREES[,PITCH_DEGREES]].
			var parts := argument.trim_prefix("--stage=").split(",")
			await _capture_stage(int(parts[0]), float(parts[1]) if parts.size() > 1 else 0.0, float(parts[2]) if parts.size() > 2 else 0.0)
			return
		elif argument.begins_with("--steer"):
			if argument.begins_with("--steer="):
				_open_division(int(argument.trim_prefix("--steer=")))
			await _steer_test()
			return
		elif argument.begins_with("--world="):
			# The Arena from a free camera: --world=X,Y,Z,YAW,PITCH[,NAME[,DIVISION]].
			var parts := argument.trim_prefix("--world=").split(",")
			if parts.size() > 6:
				_open_division(int(parts[6]))
			await _capture_world(Vector3(float(parts[0]), float(parts[1]), float(parts[2])), float(parts[3]), float(parts[4]), parts[5] if parts.size() > 5 else "view")
			return
		elif argument.begins_with("--action="):
			var parts := argument.trim_prefix("--action=").split(",", false, 2)
			action_class = parts[0]
			if parts.size() > 1:
				action_index = clampi(int(parts[1]), 0, DeadLeagueRules.BOSS_COUNT - 1)
			if parts.size() > 2 and parts[2] in ["left", "right", "windup"]:
				action_hand = parts[2]
	if not versus_class.is_empty():
		if not GameState.CLASSES.has(versus_class):
			push_error("Unknown versus fighter class: " + versus_class)
			get_tree().quit(1)
			return
		GameState.player_class = versus_class
		VsIntro.play(self, versus_index)
		for frame in 32:
			await get_tree().process_frame
		await _capture("res://dead_league_versus_%s_capture.png" % versus_class)
		return
	if loading_index >= 0:
		Loading._build(Loading._boss_card(loading_index))
		await _settle()
		await _capture("res://dead_league_loading_%d_capture.png" % loading_index)
		return
	if not action_class.is_empty():
		if not GameState.CLASSES.has(action_class):
			push_error("Unknown action fighter class: " + action_class)
			get_tree().quit(1)
			return
		GameState.player_class = action_class
		GameState.dead_league_bout = action_index
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var grade := "--grade" in OS.get_cmdline_user_args()
	var arena := "--arena" in OS.get_cmdline_user_args() or grade or not action_class.is_empty()
	var path := "res://dead_league_arena.tscn" if arena else "res://dead_league_menu.tscn"
	var scene: PackedScene = load(path)
	var subject := scene.instantiate()
	add_child(subject)
	if not action_class.is_empty():
		# Let the VS card clear and the contender step into range, then fire a
		# real player input so the screenshot captures the live combat view.
		var player: Player = subject.get_node("Player")
		player.invulnerable = true
		for frame in 280:
			await get_tree().process_frame
		var boss: DeadLeagueBoss = subject.get("_boss")
		if is_instance_valid(boss):
			boss.position = Vector3(0, 0.05, -2.4)
		for frame in 3:
			await get_tree().process_frame
		if action_hand == "windup":
			boss.call("_begin_attack", "left_hook", 1.2)
			for frame in 24:
				await get_tree().process_frame
		else:
			Input.action_press("punch_" + action_hand)
			await get_tree().process_frame
			Input.action_release("punch_" + action_hand)
			await get_tree().process_frame
		await _capture("res://dead_league_action_%s_%d_capture.png" % [action_class, action_index])
		return
	await _settle()
	if grade:
		subject.set("_elapsed", 92.0)
		subject.set("_damage_taken", 11.0)
		subject.set("_perfect_dodges", 9)
		subject.set("_counters", 6)
		subject.set("_grazes", 1)
		subject.set("_punch_types", {"jab": true, "cross": true, "hook": true, "uppercut": true})
		subject.call("_finish_victory")
		for frame in 4:
			await get_tree().process_frame
	var output := "res://dead_league_grade_capture.png" if grade else ("res://dead_league_arena_capture.png" if arena else "res://dead_league_menu_capture.png")
	await _capture(output)


func _capture_stage(index: int, yaw: float, pitch: float) -> void:
	GameState.dead_league_bout = clampi(index, 0, DeadLeagueRules.BOSS_COUNT - 1)
	var subject: Node = (load("res://dead_league_arena.tscn") as PackedScene).instantiate()
	add_child(subject)
	var player: Player = subject.get_node("Player")
	player.invulnerable = true
	for frame in 280:
		await get_tree().process_frame
	var boss: Node3D = subject.get("_boss")
	if is_instance_valid(boss):
		boss.visible = false
		boss.process_mode = Node.PROCESS_MODE_DISABLED
	player.rotation.y = deg_to_rad(yaw)
	var camera := get_viewport().get_camera_3d()
	if camera:
		camera.rotation.x = deg_to_rad(pitch)
	for frame in 6:
		await get_tree().process_frame
	print("STAGE %d: %d draw calls, %d objects, %d primitives" % [index,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	await _capture("res://dead_league_stage_%d_%d_capture.png" % [index, int(yaw)])


## Monsters get round the Arena's solid props: for each statue / obelisk /
## oak, a zombie stands right behind it with you right in front, and must
## reach you within 6 s. Prints PASS / FAIL per prop and quits 1 on a fail.
func _steer_test() -> void:
	var subject: Node = (load("res://world.tscn") as PackedScene).instantiate()
	add_child(subject)
	for frame in 30:
		await get_tree().process_frame
	var player: Player = subject.get_node("Player")
	player.invulnerable = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	subject.set("_spawn_timer", 9999.0)
	subject.set_process(false)
	var solids: Array = subject.get("_solids")
	var failed := 0
	var tested := 0
	for solid in solids:
		if Vector2(solid.x, solid.y).length() > 35.0:
			continue
		var center := Vector3(solid.x, 0.1, solid.y)
		var out := center.normalized()
		player.global_position = center - out * (solid.z + 2.5)
		player.velocity = Vector3.ZERO
		var zombie: Enemy = (load("res://zombie.tscn") as PackedScene).instantiate()
		zombie.setup(player, false)
		subject.get_node("Enemies").add_child(zombie)
		zombie.global_position = center + out * (solid.z + 1.0)
		var reached := false
		var closest := INF
		var inside := false
		var time := 0.0
		var limit: float = 6.0 + solid.z * 1.5
		var trace := OS.get_environment("STEER_TRACE") == str(tested + 1)
		while time < limit:
			await get_tree().physics_frame
			time += get_physics_process_delta_time()
			var probe := PhysicsPointQueryParameters3D.new()
			probe.position = zombie.global_position + Vector3(0, 0.9, 0)
			probe.collision_mask = Scenery.PROP_LAYER
			if not zombie.get_world_3d().direct_space_state.intersect_point(probe, 1).is_empty():
				inside = true
			if trace and fmod(time, 0.5) < get_physics_process_delta_time():
				print("  t %.1f zombie (%.2f, %.2f) avoid %s detour %.2f" % [time, zombie.global_position.x, zombie.global_position.z, zombie.get("_avoid"), zombie.get("_detour_time")])
			player.global_position = center - out * (solid.z + 2.5)
			closest = minf(closest, Vector2(zombie.global_position.x - center.x, zombie.global_position.z - center.z).length())
			var past := Vector3(zombie.global_position.x - center.x, 0, zombie.global_position.z - center.z).dot(out) < 0.0
			if past and zombie.global_position.distance_to(player.global_position) < 2.8:
				reached = true
				break
		tested += 1
		if inside:
			reached = false  # Walked through it.
		if not reached:
			failed += 1
		print("STEER %s at (%.1f, %.1f) r %.1f: %s in %.1f s, closest %.2f" % ["PASS" if reached else "FAIL", solid.x, solid.y, solid.z, "reached" if reached else "stuck", time, closest])
		zombie.queue_free()
		await get_tree().physics_frame
	print("STEER RESULT (division %d)" % int(subject.get("_division")))
	print("STEER RESULT: %d / %d props passed" % [tested - failed, tested])
	get_tree().quit(1 if failed > 0 else 0)


## Every seal broken (test save only), so the Arena opens on division.
func _open_division(division: int) -> void:
	for tier in Progression.TIERS:
		GameState.dead_league_clears[tier.contender] = true
	GameState.arena_division = division


func _capture_world(at: Vector3, yaw: float, pitch: float, name: String) -> void:
	var subject: Node = (load("res://world.tscn") as PackedScene).instantiate()
	add_child(subject)
	for frame in 90:
		await get_tree().process_frame
	var player: Player = subject.get_node("Player")
	player.invulnerable = true
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	for node in subject.get_children():
		if node is CanvasLayer:
			node.visible = false
	if pitch < -30.0:
		# Overhead: no fog, so the whole layout shows.
		for node in subject.find_children("*", "WorldEnvironment", true, false):
			(node as WorldEnvironment).environment.fog_enabled = false
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.far = 400.0
	subject.add_child(camera)
	camera.global_position = at
	camera.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
	camera.make_current()
	for frame in 8:
		await get_tree().process_frame
	print("WORLD %s: %d draw calls, %d objects, %d primitives" % [name,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	await _capture("res://world_%s_capture.png" % name)


func _settle() -> void:
	for frame in 20:
		await get_tree().process_frame


func _capture(output: String) -> void:
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(ProjectSettings.globalize_path(output))
	print("DEAD LEAGUE VISUAL CAPTURE: %s (%s)" % [output, error_string(error)])
	get_tree().quit(0 if error == OK else 1)
