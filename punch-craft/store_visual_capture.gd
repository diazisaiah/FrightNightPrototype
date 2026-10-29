extends Node
## Deterministic store-page capture helper. Run with `-- --mode=<mode>`;
## each mode builds a real scene (a fight, camp's pages, an ultimate going off)
## and saves the live game viewport under store_assets/. Modes: arena, crypt
## (2026-10-26); hats, web, cards, group, crypt_boss, lich_king, flame_burst,
## inferno, temporal_break, highlight_reel, league, hat_pop, hat_emote,
## trailer (2026-10-29: itch
## page; trailer plays a scripted sequence for --write-movie). Run it with
## FRIGHT_NIGHT_SAVE / FRIGHT_NIGHT_SETTINGS pointing at a test save. The
## secrets stay out of the store page: no Tony (or his things), no True
## Coffin King, no plumber caps but the Hot Plumber Hat.

const SHOTS := "../store_assets/2026-10-29/"


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
		"hats", "web", "cards":
			await _capture_camp(mode)
		"group":
			await _capture_group()
		"crypt_boss", "lich_king":
			await _capture_crypt_boss(mode)
		"flame_burst", "inferno", "temporal_break", "highlight_reel":
			await _capture_ultimate(mode)
		"league":
			await _capture_league()
		"hat_pop":
			await _capture_hat_pop()
		"hat_emote":
			await _capture_hat_emote()
		"trailer":
			await _trailer()
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


# --- The itch page (2026-10-29) --------------------------------------------------------

## A fighter at the top of the climb: every upgrade (Endless powers too), level
## 51, every card at full rank, every attribute, every contender beaten.
func _max_build(fighter: String, ultimate := "") -> void:
	GameState._reset_fields()
	GameState.onboarded = true
	GameState.tutorial_done = true
	GameState.fighters_bought.elementalist = true
	GameState.player_class = fighter
	for i in DeadLeagueRules.BOSS_COUNT:
		GameState.dead_league_clears[DeadLeagueRules.boss(i).id] = true
	for division in range(1, Progression.TIER_COUNT + 1):
		GameState.arena_bouts[str(division)] = Progression.BOUTS_PER_DIVISION
	for id in GameState.UPGRADES:
		GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
	var info: Dictionary = GameState._classes[fighter]
	info.level = 51
	for attribute in Attributes.LIST:
		info.attributes[attribute] = Attributes.MAX
	for id in Cards.deck(fighter):
		info.cards[id] = Cards.copies(Cards.deck(fighter)[id])
	if ultimate != "":
		GameState.loadouts[fighter] = {"passive": Abilities.default_passive(fighter), "ultimate": ultimate}
	# Every trophy hat owned (the secret plumber caps aside), so none is
	# awarded over the shot.
	for id in Hats.TROPHIES:
		if not _secret_hat(id):
			GameState.hats[id] = 1
	GameState.select_power("sigil_fire")
	for id in Achievements.LIST:
		GameState.achievements[id] = true
	# No tips over the shots.
	for id in ["first_upgrade", "dead_league", "attribute_points", "hat_first", "hat_rack", "hat_rack_tour", "power_select", "crypt_gilding"]:
		GameState.tips_seen[id] = true
	for slot in [Abilities.passives(fighter), Abilities.ultimates(fighter)]:
		for entry in slot:
			GameState.tips_seen["ability_" + entry.id] = true


## The plumber quest's caps, but for the Hot Plumber Hat (Fire's trophy).
static func _secret_hat(id: String) -> bool:
	return id in Hats.PLUMBER_CAPS and id != "fire_cap"


func _capture_camp(mode: String) -> void:
	_max_build("counter_master" if mode == "hats" else "berserker")
	for id in Hats.CATALOG:
		if not _secret_hat(id):
			GameState.hats[id] = 1
	GameState.worn_hat = "fruit_hat"
	if mode == "cards":
		# A fresh fighter mid-climb with level-up draws waiting.
		var info: Dictionary = GameState._classes[GameState.player_class]
		info.cards = {}
		info.level = 24
		info.draws = 3
		info.offer = []
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	await _frames(90)
	match mode:
		"hats":
			camp.call("_show_page", "Cosmetics")
			camp.call("_show_cosmetic", "Hats")
			await _frames(40)
		"web":
			# Zoomed out to the whole web.
			var tree: Control = camp.get("_trees")["upgrade"]
			for i in 4:
				tree.call("_zoom_at", tree.size / 2.0, 1.0 / 1.15)
			await _frames(30)
		"cards":
			await _frames(150)
	await _capture(SHOTS + mode + ".png")


## A Crown Division bout: a crowd of the dead, elites and a champion among
## them, closing in while the Mauler swings.
func _capture_group() -> void:
	_max_build("berserker")
	var world := await _arena(5)
	var player: Player = world.get_node("Player")
	await _crowd(world)
	await _frames(70)
	_hide_center_messages(world)
	player.call("_punch", "cross", "right")
	await _frames(9)
	await _capture(SHOTS + "group.png")


## An Arena bout at division d, the player in the middle facing -z.
func _arena(division: int) -> Node:
	GameState.arena_division = division
	GameState.arena_bout_pick = 2
	var world: Node = preload("res://world.tscn").instantiate()
	add_child(world)
	await _frames(40)
	var player: Player = world.get_node("Player")
	player.invulnerable = true
	player.global_position = Vector3(0, 0.1, 0)
	player.rotation = Vector3.ZERO
	return world


## Seven monsters in an arc ahead, two elites and a champion among them.
func _crowd(world: Node) -> void:
	var kinds := ["brawler", "hulk", "zombie", "armor", "brawler", "runner", "skeleton"]
	var ranks := ["", "champion", "", "elite", "", "elite", ""]
	for i in kinds.size():
		var angle := lerpf(-0.75, 0.75, i / float(kinds.size() - 1))
		var spot := Vector3(sin(angle), 0, -cos(angle)) * (3.2 if i % 2 == 0 else 5.0) + Vector3(0, 0.1, 0)
		world.call("_spawn_enemy", {"kind": kinds[i], "armored": false, "rank": ranks[i]}, spot)
	await _frames(2)


func _capture_crypt_boss(mode: String) -> void:
	_max_build("free_runner")
	GameState.crypt_tier = 2
	var crypt: Node = preload("res://dungeon.tscn").instantiate()
	add_child(crypt)
	await _frames(50)
	crypt.set("_floor", 2 if mode == "crypt_boss" else 3)
	var room: Dictionary = {}
	for candidate in crypt.get("_rooms"):
		if candidate.type == "boss":
			room = candidate
	var player: Player = crypt.get_node("Player")
	player.invulnerable = true
	player.global_position = room.center + Vector3(0, 0.1, minf(5.0, room.size.y / 2.0 - 2.0))
	player.look_at(room.center + Vector3(0, 1.4, 0))
	crypt.set("_current_room", room)
	crypt.call("_start_boss_fight", room)
	await _frames(150)
	_hide_center_messages(crypt)
	for enemy in crypt.get_node("Enemies").get_children():
		if enemy is Enemy and enemy.is_boss:
			player.look_at(Vector3(enemy.global_position.x, player.global_position.y + 0.9, enemy.global_position.z))
	player.call("_punch", "uppercut", "right")
	await _frames(8)
	await _capture(SHOTS + mode + ".png")


func _capture_ultimate(ultimate: String) -> void:
	var fighter: String = {"flame_burst": "elementalist", "inferno": "berserker", "temporal_break": "combo_master", "highlight_reel": "free_runner"}[ultimate]
	_max_build(fighter, ultimate)
	var world := await _arena(3 if ultimate == "flame_burst" else 4)
	var player: Player = world.get_node("Player")
	await _crowd(world)
	await _frames(50)
	_hide_center_messages(world)
	player.ult.fill()
	match ultimate:
		"flame_burst":
			player.ult.activate()
			await _frames(22)
		"inferno":
			player.ult.activate()
			await _frames(62)
		"temporal_break":
			player.ult.activate()
			await _frames(20)
			for i in 8:
				player.call("_punch", "jab" if i % 2 == 0 else "cross", "left" if i % 2 == 0 else "right")
				await _frames(9)
		"highlight_reel":
			player.ult.activate()
			await _frames(9)
	await _capture(SHOTS + ultimate + ".png")


## A Dead League bout: the Coffin King, round 3, under the spotlight.
func _capture_league() -> void:
	_max_build("combo_master")
	GameState.dead_league_bout = DeadLeagueRules.BOSS_COUNT - 1
	var arena: Node = load("res://dead_league_arena.tscn").instantiate()
	add_child(arena)
	for i in 600:
		await get_tree().process_frame
		if arena.get_node("Player").active:
			break
	var player: Player = arena.get_node("Player")
	player.invulnerable = true
	await _frames(40)
	_hide_center_messages(arena)
	var king: Node3D = arena.get("_boss")
	player.look_at(Vector3(king.global_position.x, player.global_position.y + 0.8, king.global_position.z))
	player.call("_punch", "jab", "left")
	await _frames(8)
	await _capture(SHOTS + "league.png")


## A hat knocked off with an uppercut: the hat flying with HAT!, then its card.
func _capture_hat_pop() -> void:
	_max_build("berserker")
	GameState.hats.erase("witch_hat")
	var world := await _arena(1)
	var player: Player = world.get_node("Player")
	var scaling := Progression.enemy_scaling(0.4)
	scaling.hat = "witch_hat"
	var zombie: Enemy = load("res://zombie.tscn").instantiate()
	zombie.setup(player, false, scaling)
	zombie.position = Vector3(0, 0.1, -2.2)
	world.get_node("Enemies").add_child(zombie)
	zombie.set_physics_process(false)
	await _frames(40)
	_hide_center_messages(world)
	player.look_at(Vector3(0, player.global_position.y + 0.3, -2.2))
	player.call("_punch", "uppercut", "right")
	await _frames(9)
	zombie.finisher = {"type": "uppercut"}
	zombie.call("_pop_hat")
	await _frames(5)
	await _snap(SHOTS + "hat_pop_1.png")
	await _frames(50)
	await _capture(SHOTS + "hat_pop_2.png")


## Wearing it: a dance in third person, the dead watching.
func _capture_hat_emote() -> void:
	_max_build("berserker")
	GameState.worn_hat = "witch_hat"
	var world := await _arena(1)
	var player: Player = world.get_node("Player")
	await _frames(30)
	_hide_center_messages(world)
	player.start_emote("bros_shuffle")
	await _frames(20)
	# From the front.
	player.set("_emote_orbit", Vector2(PI, 0.15))
	await _frames(90)
	await _capture(SHOTS + "hat_emote.png")


## A scripted run for a trailer (record it with --write-movie): the crowd
## closing in and punches flying, a Temporal Break, Flame Burst's blast.
func _trailer() -> void:
	_max_build("combo_master", "temporal_break")
	var world := await _arena(4)
	var player: Player = world.get_node("Player")
	await _crowd(world)
	await _frames(30)
	_hide_center_messages(world)
	var punches := ["jab", "cross", "left_hook", "right_hook", "jab", "cross", "uppercut", "cross"]
	for round in 3:
		for i in punches.size():
			_face_nearest(player, world)
			player.call("_punch", punches[i] if punches[i] != "left_hook" and punches[i] != "right_hook" else "hook", "left" if i % 2 == 0 else "right")
			await _frames(12)
		await _frames(20)
	player.ult.fill()
	player.ult.activate()
	await _frames(20)
	for i in 14:
		_face_nearest(player, world)
		player.call("_punch", "jab" if i % 2 == 0 else "cross", "left" if i % 2 == 0 else "right")
		await _frames(8)
	await _frames(150)
	get_tree().quit(0)


func _face_nearest(player: Player, scene: Node) -> void:
	var best: Node3D = null
	for enemy in scene.get_node("Enemies").get_children():
		if enemy is Enemy and not enemy.is_dead() and (best == null or enemy.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = enemy
	if best:
		player.look_at(Vector3(best.global_position.x, player.global_position.y, best.global_position.z))


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
	var error := await _snap(relative_output)
	# Recording a clip (--write-movie): let the moment play out first.
	var linger := OS.get_environment("STORE_LINGER")
	if linger != "":
		await _frames(int(linger))
	get_tree().quit(0 if error == OK else 1)


## Saves the viewport (and keeps going).
func _snap(relative_output: String) -> Error:
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var output := ProjectSettings.globalize_path("res://" + relative_output)
	var error := image.save_png(output)
	print("STORE VISUAL CAPTURE: %s (%s)" % [output, error_string(error)])
	return error
