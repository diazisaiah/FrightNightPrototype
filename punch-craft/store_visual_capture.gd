extends Node
## Deterministic store-page capture helper. Run with `-- --mode=arena` or
## `-- --mode=crypt`; each mode builds a real fight, performs a real punch,
## and saves the live 1280x720 game viewport under store_assets/.


func _ready() -> void:
	seed(20261026)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mode := "arena"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	match mode:
		"arena":
			await _capture_arena()
		"crypt":
			await _capture_crypt()
		_:
			push_error("Unknown store capture mode: " + mode)
			get_tree().quit(1)


func _unlock_tier_four() -> void:
	GameState.dead_league_clears = {
		"bellman": true,
		"headless": true,
		"southpaw": true,
	}


func _capture_arena() -> void:
	_unlock_tier_four()
	GameState.player_class = "berserker"
	GameState.arena_division = 4
	GameState.arena_bouts = {"4": 1}
	GameState.arena_bout_pick = 2
	var arena := preload("res://world.tscn").instantiate()
	add_child(arena)
	await _frames(40)
	var player: Player = arena.get_node("Player")
	player.invulnerable = true
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation = Vector3.ZERO
	# The Plague Division's possessed armor gives the Arena shot a readable
	# silhouette and a dangerous opposing action without using a Contender.
	arena.call("_spawn_enemy", {
		"kind": "armor",
		"armored": false,
	}, Vector3(0, 0.1, -3.1))
	await _frames(8)
	var enemy: Boxer = arena.get_node("Enemies").get_child(-1)
	enemy.call("_begin_attack", "slash", 1.35)
	await _frames(18)
	_hide_center_messages(arena)
	player.call("_punch", "hook", "left")
	await _frames(11)
	await _capture("../store_assets/fright-night-arena-action.png")


func _capture_crypt() -> void:
	_unlock_tier_four()
	GameState.player_class = "free_runner"
	GameState.crypt_tier = 4
	var crypt := preload("res://dungeon.tscn").instantiate()
	add_child(crypt)
	await _frames(50)
	var rooms: Array = crypt.get("_rooms")
	var room: Dictionary = {}
	for candidate in rooms:
		if candidate.type == "fight" and not candidate.elite and candidate.layout == "open":
			room = candidate
			break
	if room.is_empty():
		for candidate in rooms:
			if candidate.type == "fight" and not candidate.elite:
				room = candidate
				break
	if room.is_empty():
		push_error("No Crypt fight room available for store capture")
		get_tree().quit(1)
		return
	var player: Player = crypt.get_node("Player")
	player.invulnerable = true
	var player_spot: Vector3 = room.center + Vector3(0, 0.1, minf(4.0, room.size.y / 2.0 - 2.5))
	player.global_position = player_spot
	player.look_at(room.center + Vector3(0, 1.0, 0))
	crypt.set("_current_room", room)
	crypt.call("_start_fight", room)
	crypt.set("_to_spawn", 0)
	var hazards: Node = crypt.get("_hazards")
	for hazard in hazards.get_children():
		hazard.set_physics_process(false)
	# A Shieldbearer is exclusive to the Crypt. Its overhead strike and the
	# Stray's green glove make the two action shots immediately distinct.
	var enemy_spot: Vector3 = room.center + Vector3(0, 0.1, 0)
	crypt.call("_spawn_enemy", {
		"kind": "shieldbearer",
		"armored": false,
	}, enemy_spot)
	await _frames(8)
	var enemy: Boxer
	for child in crypt.get_node("Enemies").get_children():
		if child is Shieldbearer:
			enemy = child
			break
	if enemy == null:
		push_error("Shieldbearer did not spawn for Crypt store capture")
		get_tree().quit(1)
		return
	enemy.call("_begin_attack", "slam", 1.3)
	await _frames(18)
	_hide_center_messages(crypt)
	var fists: Fists = player.get("_fists")
	fists.play_punch("hook", "right", 0.18, 0.5)
	await _frames(7)
	await _capture("../store_assets/fright-night-crypt-action.png")


func _frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame


func _hide_center_messages(scene: Node) -> void:
	# Preserve the real combat HUD while clearing transient intro copy that
	# otherwise obscures the store screenshot's action.
	var hud: Node = scene.get_node("HUD")
	var announcement := hud.get_node_or_null("%Announcement")
	if announcement:
		announcement.hide()
	var speech: CanvasItem = hud.get("_speech")
	if speech:
		speech.hide()


func _capture(relative_output: String) -> void:
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://" + relative_output)
	var error := image.save_png(output)
	print("STORE VISUAL CAPTURE: %s (%s)" % [output, error_string(error)])
	get_tree().quit(0 if error == OK else 1)
