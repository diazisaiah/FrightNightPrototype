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
