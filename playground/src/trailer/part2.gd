extends "res://store_visual_capture.gd"
## Trailer part 2 (2026-10-31): the real game's own scenes, one mode per clip,
## each rendered on its own and cut together afterwards:
##   hatpop    an uppercut knocks a propeller beanie off a monster, the hat card,
##             a mouse clicking GIMME THAT
##   shuffle   the Bros. Shuffle in the new cap
##   hatpage   a slow scroll down the hat rack (about a third collected)
##   shop      the Soul Shop
##   reveal    the Bellman falls and the Crypt comes up out of the ground (camp)
## Run:  godot --path playground/project res://playground/trailer/part2.tscn
##       --resolution 1920x1080 --write-movie out.avi --fixed-fps 30 -- --mode=hatpop
## (with FRIGHT_NIGHT_SAVE / FRIGHT_NIGHT_SETTINGS pointing at a scratch save).

const FighterColor := {
	"berserker": Color(1.0, 0.42, 0.1), "counter_master": Color(0.35, 0.7, 1.0),
	"combo_master": Color(0.68, 0.35, 1.0), "free_runner": Color(0.3, 1.0, 0.45),
}
const FxScript := preload("res://playground/trailer/trailer_fx.gd")
var _cursor: Node2D
var _fx_node: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	seed(20261031)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var mode := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
	match mode:
		"hatpop":
			await _m_hatpop()
		"shuffle":
			await _m_shuffle()
		"hatpage":
			await _m_hatpage()
		"shop":
			await _m_shop()
		"reveal":
			await _m_reveal()
		"griddy1":
			await _m_griddy("berserker", 1, 0, 59)
		"griddy2":
			await _m_griddy("combo_master", 2, 1, 60)
		"griddy3":
			await _m_griddy("counter_master", 3, 0, 59)
		"griddy4":
			await _m_griddy4()
		"power1":
			await _m_power("berserker", "sigil_fire", 2, true)
		"power2":
			await _m_power("counter_master", "sigil_storm", 3, false)
		"power3":
			await _m_power("combo_master", "sigil_doom", 4, false)
		"power4":
			await _m_power("free_runner", "sigil_gale", 5, false)
		"upgrades":
			await _m_upgrades()
		"cards":
			await _m_cards()
		"mimic":
			await _m_mimic()
		"chest":
			await _m_chest()
		"colossus":
			await _m_colossus()
		_:
			await super()
	get_tree().quit()


## The custom counter / knockout effects, on a real Player.
func _effects(player: Player, scene: Node, fighter: String) -> void:
	_fx_node = FxScript.new()
	add_child(_fx_node)
	_fx_node.attach(player, scene, FighterColor.get(fighter, Color(0.35, 0.7, 1.0)))


## The useful part of the clip starts here (the assembly trims what's before).
func _mark() -> void:
	print("MARK %d" % Engine.get_frames_drawn())


## A fresh fighter with a bare save (no maxed upgrades, so no trophy hats or
## achievement popups), tips switched off.
func _light_build(fighter: String) -> void:
	GameState._reset_fields()
	GameState.onboarded = true
	GameState.tutorial_done = true
	GameState.player_class = fighter
	for id in ["first_upgrade", "dead_league", "attribute_points", "hat_first", "hat_rack", "hat_rack_tour", "power_select", "crypt_gilding"]:
		GameState.tips_seen[id] = true
	for slot in [Abilities.passives(fighter), Abilities.ultimates(fighter)]:
		for entry in slot:
			GameState.tips_seen["ability_" + entry.id] = true


# --- Mouse cursor (the game hides it in a fight; the hat card needs one) ----------------

func _make_cursor() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_cursor = Node2D.new()
	layer.add_child(_cursor)
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(-2, 30), Vector2(7, 22), Vector2(14, 36), Vector2(20, 33), Vector2(13, 20), Vector2(25, 20)])
	outline.color = Color.BLACK
	_cursor.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(1, 3), Vector2(1, 24), Vector2(8, 18), Vector2(15, 32), Vector2(17, 31), Vector2(10, 17), Vector2(19, 17)])
	fill.color = Color.WHITE
	_cursor.add_child(fill)
	_cursor.position = Vector2(1500, 900)


func _move_cursor(to: Vector2, frames: int) -> void:
	var from := _cursor.position
	for i in frames:
		var u := float(i + 1) / frames
		u = u * u * (3.0 - 2.0 * u)
		_cursor.position = from.lerp(to, u)
		await get_tree().process_frame


func _click() -> void:
	for i in 4:
		_cursor.scale = Vector2.ONE * (1.0 - 0.18 * float(i + 1) / 4.0)
		await get_tree().process_frame
	for i in 4:
		_cursor.scale = Vector2.ONE * (0.82 + 0.18 * float(i + 1) / 4.0)
		await get_tree().process_frame


# --- The clips ----------------------------------------------------------------------------

func _m_hatpop() -> void:
	_max_build("counter_master")
	GameState.hats.erase("propeller_beanie")
	GameState.worn_hat = ""
	var world := await _arena(1)
	var player: Player = world.get_node("Player")
	_effects(player, world, "counter_master")
	var scaling := Progression.enemy_scaling(0.4)
	scaling.hat = "propeller_beanie"
	var zombie: Enemy = load("res://zombie.tscn").instantiate()
	zombie.setup(player, false, scaling)
	zombie.position = Vector3(0, 0.1, -1.7)
	world.get_node("Enemies").add_child(zombie)
	zombie.set_physics_process(false)
	await _frames(110)
	_hide_center_messages(world)
	player.look_at(Vector3(zombie.global_position.x, player.global_position.y + 0.3, zombie.global_position.z))
	_mark()
	await _frames(24)
	player.call("_punch", "uppercut", "right")
	await _frames(7)
	# The uppercut finishes it: the real knock-off (its hat flies, then the card).
	zombie.set_physics_process(true)
	zombie.finisher = {"type": "uppercut", "hand": "right", "level": 1, "dir": Vector3(0, 0, -1), "player": player}
	zombie.take_hit(zombie.hp * 3.0 + 50.0, zombie.global_position + Vector3(0, 1.3, 0), Vector3(0, 0, -6), true, "UPPERCUT!")
	# The hat flies, then its card opens.
	var popup: Node = null
	for i in 150:
		await get_tree().process_frame
		var found := get_tree().root.find_children("*", "HatPopup", true, false)
		if not found.is_empty():
			popup = found[0]
			break
	if popup == null:
		push_error("The hat card never opened")
		return
	_make_cursor()
	await _frames(45)
	var button: Button = popup.find_children("*", "Button", true, false)[0]
	await _move_cursor(button.get_global_rect().get_center(), 34)
	await _frames(6)
	await _click()
	button.pressed.emit()
	await _frames(14)


func _m_shuffle() -> void:
	_max_build("counter_master")
	GameState.hats["propeller_beanie"] = 1
	GameState.worn_hat = "propeller_beanie"
	var world := await _arena(1)
	var player: Player = world.get_node("Player")
	_effects(player, world, "counter_master")
	await _frames(110)
	_hide_center_messages(world)
	player.start_emote("bros_shuffle")
	player.get("_emote_cam").fov = 50.0
	player.set("_emote_orbit", Vector2(PI, 0.1))
	_mark()
	await _frames(166)


func _m_hatpage() -> void:
	_light_build("counter_master")
	# About a third of the hats, in no particular order.
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	GameState.hats.clear()
	for id in Hats.CATALOG:
		if not _secret_hat(id) and rng.randf() < 0.36:
			GameState.hats[id] = 1
	GameState.worn_hat = "propeller_beanie"
	GameState.hats["propeller_beanie"] = 1
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	await _frames(40)
	camp.call("_show_page", "Cosmetics")
	camp.call("_show_cosmetic", "Hats")
	await _frames(30)
	_mark()
	var scroll: ScrollContainer = null
	for node in camp.find_children("*", "ScrollContainer", true, false):
		if node.is_visible_in_tree() and (node as ScrollContainer).get_v_scroll_bar().max_value > 100.0:
			scroll = node
	if scroll == null:
		await _frames(120)
		return
	var most := scroll.get_v_scroll_bar().max_value - scroll.size.y
	var frames := 66
	for i in frames:
		var u := float(i) / (frames - 1)
		scroll.scroll_vertical = int(most * (u * u * (3.0 - 2.0 * u)))
		await get_tree().process_frame
	await _frames(15)


func _m_shop() -> void:
	_light_build("counter_master")
	GameState.souls = 46
	GameState.fights_done += 1
	SoulShop.restock()
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	await _frames(40)
	camp.call("_show_page", "Shop")
	await _frames(20)
	_mark()
	await _frames(80)


func _m_reveal() -> void:
	_max_build("counter_master")
	GameState.crypt_unlocked = true
	GameState.crypt_reveal_pending = true
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	_mark()
	for i in 900:
		await get_tree().process_frame
		if not GameState.crypt_reveal_pending:
			break
	await _frames(45)


# --- A bot with real hands ---------------------------------------------------------------

var _bot := {"last": "", "cool": 0.0, "step": 0, "string": [["jab", "left"], ["cross", "right"], ["hook", "left"], ["uppercut", "right"]]}


## One frame of a real fight: face the nearest monster and close in, slip or
## roll each windup at the last moment, counter (an uppercut off a slip, a hook
## off a roll), and string punches in the gaps.
func _bot_step(player: Player) -> void:
	var delta := get_process_delta_time()
	_bot.cool = float(_bot.cool) - delta
	player.set("_idle_for", 0.0)
	player.set("_idle_next", 99.0)
	var foes: Array = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and not node.is_dead():
			foes.append(node)
	if foes.is_empty():
		return
	var target: Enemy = foes[0]
	for foe in foes:
		if foe.global_position.distance_to(player.global_position) < target.global_position.distance_to(player.global_position):
			target = foe
	var eye: Vector3 = player.get("_camera").global_position
	var to := target.global_position + Vector3(0, 1.3 * target.scale.y, 0) - eye
	var camera: Camera3D = player.get("_camera")
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), clampf(delta * 12.0, 0.0, 1.0))
	camera.rotation.x = lerpf(camera.rotation.x, clampf(atan2(to.y, Vector2(to.x, to.z).length()), -0.6, 0.6), clampf(delta * 8.0, 0.0, 1.0))
	var flat := Vector3(to.x, 0, to.z)
	var reach := 1.8 + 0.25 * target.scale.x
	var far: bool = _bot.get("far", false)
	if not far and flat.length() > reach and String(player.get("_defense")) == "":
		player.global_position += flat.normalized() * minf(4.5 * delta, flat.length() - reach)
	var soon := INF
	var move := ""
	for foe in foes:
		var attack: String = foe.incoming_attack()
		if attack == "" or foe.global_position.distance_to(player.global_position) > 4.5:
			continue
		var answers: Array = Player.ANSWERS.get(attack, [])
		var eta: float = foe.attack_eta()
		# (eta is 0 once the punch is already thrown: nothing left to dodge.)
		if not answers.is_empty() and eta > 0.0 and eta < soon:
			soon = eta
			move = answers[0]
	if move != "" and soon <= 0.12 and String(player.get("_defense")) == "" and float(player.get("_defense_cooldown")) <= 0.0:
		_bot.last = move
		player.call("_try_defense", move)
		return
	if player.is_counter_ready() and float(player.get("_cooldown")) <= 0.0 and float(_bot.cool) <= 0.0 and String(player.get("_defense")) == "":
		var side: String = player.get("_counter_side")
		side = "right" if side == "any" else side
		player.call("_punch", "uppercut" if String(_bot.last).begins_with("slip") else "hook", side)
		_bot.cool = 0.3
		return
	if soon > 0.5 and float(player.get("_cooldown")) <= 0.0 and String(player.get("_defense")) == "" and (far or flat.length() < reach + 0.7) and float(_bot.cool) <= 0.0:
		var string: Array = _bot.get("string", [["jab", "left"], ["cross", "right"], ["hook", "left"], ["uppercut", "right"]])
		var step: Array = string[int(_bot.step) % string.size()]
		_bot.step = int(_bot.step) + 1
		player.call("_punch", step[0], step[1])
		_bot.cool = float(_bot.get("gap", 0.05))


## The finish: one more uppercut, with nothing left in the monster.
## The height of the highest part of a monster (its head).
func _top_of(node: Node3D) -> float:
	var top := node.global_position.y + 1.8
	for geometry in node.find_children("*", "GeometryInstance3D", true, false):
		var box: AABB = (geometry as GeometryInstance3D).global_transform * (geometry as GeometryInstance3D).get_aabb()
		top = maxf(top, box.end.y)
	return top


func _finisher(player: Player, foe: Enemy) -> void:
	foe.hp_floor = 0.0
	foe.hp = minf(foe.hp, 1.0)
	player.call("_punch", "uppercut", "right")


func _fight(player: Player, frames: int) -> void:
	for i in frames:
		_bot_step(player)
		await get_tree().process_frame


# --- The griddy: every fighter, every loop, a new background -------------------------------

func _stage_emote(player: Player, world: Node, id: String) -> void:
	player.set_process(true)
	world.set_process(false)
	world.get_node("HUD").visible = false
	player.start_emote(id)
	player.set("_emote_out", 1.0)
	player.get("_emote_cam").fov = 46.0
	player.set("_emote_orbit", Vector2(PI, 0.1))


## Waits for the dance's second loop (the first blended in from standing) to
## reach a point in it: a half is 1.98 s, so a clip from the start or from the
## middle runs into the next character's half on the very same pose.
func _to_phase(player: Player, half: int) -> void:
	var body: Node = player.get("_body")
	for i in 600:
		await get_tree().process_frame
		if float(body.get("_time")) >= 3.963 + 1.9815 * half:
			break


func _m_griddy(fighter: String, division: int, half: int, frames: int) -> void:
	_max_build(fighter)
	var world := await _arena(division)
	var player: Player = world.get_node("Player")
	await _frames(100)
	_stage_emote(player, world, "griddy")
	await _to_phase(player, half)
	_mark()
	await _frames(frames)


func _m_griddy4() -> void:
	_max_build("free_runner")
	GameState.power_pick = ""
	GameState.power_pick_2 = ""
	GameState.power_pick_3 = ""
	GameState.power_pick_4 = ""
	GameState.dead_league_bout = 0
	var arena: Node = load("res://dead_league_arena.tscn").instantiate()
	add_child(arena)
	for i in 900:
		await get_tree().process_frame
		if arena.get_node("Player").active:
			break
	var player: Player = arena.get_node("Player")
	player.invulnerable = true
	var boss: DeadLeagueBoss = arena.get("_boss")
	boss.set_physics_process(false)
	# Straight to the last round, so his fall is the real K.O.
	arena.set("_round", arena.call("_rounds"))
	boss.hp_floor = boss.max_hp * 0.5
	var walk := boss.move_speed
	boss.move_speed = walk * 0.16
	await _frames(20)
	_hide_center_messages(arena)
	_effects(player, arena, "free_runner")
	_fx_node.set("calm", true)
	player.set_process(true)
	var hud: CanvasLayer = arena.get_node("HUD")
	hud.visible = false
	player.start_emote("griddy")
	player.set("_emote_out", 1.0)
	player.get("_emote_cam").fov = 46.0
	player.set("_emote_orbit", Vector2(PI, 0.1))
	await _to_phase(player, 1)
	_mark()
	# The last loop: the camera swings 180 degrees round him and the Bellman
	# is coming across the ring.
	for i in 119:
		var u := float(i) / 118.0
		u = u * u * (3.0 - 2.0 * u)
		player.set("_emote_orbit", Vector2(lerpf(PI, 0.0, u), lerpf(0.1, 0.16, u)))
		if u > 0.04 and not boss.is_physics_processing():
			boss.set_physics_process(true)
		await get_tree().process_frame
	# First person, in the fight.
	player.call("_stop_emote", true)
	player.set("_emote_out", 0.0)
	hud.visible = true
	boss.move_speed = walk
	boss.hp = boss.max_hp * 0.6
	boss.hp_floor = boss.max_hp * 0.3
	await _fight(player, 105)
	if is_instance_valid(boss) and not boss.is_dead():
		boss.hp_floor = 0.0
		_finisher(player, boss)
	await _frames(75)


# --- The Crypt ----------------------------------------------------------------------------

func _crypt_room(power: String) -> Array:
	GameState.crypt_tier = 3
	GameState.select_power(power)
	var crypt: Node = preload("res://dungeon.tscn").instantiate()
	add_child(crypt)
	await _frames(60)
	var room: Dictionary = {}
	for candidate in crypt.get("_rooms"):
		if candidate.type == "fight" and not candidate.elite and candidate.layout == "open":
			room = candidate
			break
	if room.is_empty():
		for candidate in crypt.get("_rooms"):
			if candidate.type == "fight" and not candidate.elite:
				room = candidate
				break
	var player: Player = crypt.get_node("Player")
	player.invulnerable = true
	crypt.set("_current_room", room)
	for hazard in crypt.get("_hazards").get_children():
		hazard.set_physics_process(false)
	return [crypt, room, player]


## A room of the Crypt by type ("chest": a side room with nothing in it).
func _find_room(crypt: Node, type: String, nth := 0) -> Dictionary:
	var found := 0
	for candidate in crypt.get("_rooms"):
		if candidate.type == type:
			if found == nth:
				return candidate
			found += 1
	return {}


## The chests the level put in a room, put away (so ours is the only one).
func _clear_chests(crypt: Node) -> void:
	for thing in crypt.get("_interactables"):
		if thing.kind == "chest" and not thing.used:
			thing.used = true
			(thing.node as Node3D).visible = false
			for body in (thing.node as Node3D).find_children("*", "CollisionObject3D", true, false):
				body.collision_layer = 0


func _walk_to(player: Player, target: Vector3, stop: float) -> void:
	Input.action_press("move_forward")
	for i in 240:
		var to := target - player.global_position
		to.y = 0.0
		if to.length() <= stop:
			break
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), 0.25)
		await get_tree().process_frame
	Input.action_release("move_forward")


func _m_mimic() -> void:
	_max_build("berserker")
	var made := await _crypt_room("sigil_fire")
	var crypt: Node = made[0]
	var player: Player = made[2]
	var room := _find_room(crypt, "chest", 0)
	_clear_chests(crypt)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var chest_at: Vector3 = room.center + Vector3(0, 0, -1.0)
	player.global_position = room.center + Vector3(0, 0.1, 3.2)
	player.look_at(chest_at + Vector3(0, 0.6, 0))
	crypt.set("_current_room", room)
	_effects(player, crypt, "berserker")
	await _frames(70)
	_hide_center_messages(crypt)
	crypt.call("_place_chest", chest_at, "", 1.0)
	var thing: Dictionary = (crypt.get("_interactables") as Array).back()
	thing.mimic = true
	await _frames(10)
	var banner: CanvasItem = crypt.get_node("HUD").get_node_or_null("%Announcement")
	if banner:
		banner.show()
	_mark()
	# Walks up to the chest...
	await _walk_to(player, chest_at, 2.5)
	await _frames(10)
	# ...and it's a MIMIC (the real announcement and growl).
	if not thing.used:
		crypt.call("_wake_mimic", thing)
	await _frames(16)
	for foe in get_tree().get_nodes_in_group("enemies"):
		if foe is Enemy:
			foe.hp = foe.max_hp * 0.7
			foe.hp_floor = foe.max_hp * 0.25
	await _fight(player, 120)
	for foe in get_tree().get_nodes_in_group("enemies"):
		if foe is Enemy and not foe.is_dead():
			foe.hp_floor = 0.0
			_finisher(player, foe)
	await _frames(60)


func _m_chest() -> void:
	_max_build("berserker")
	var made := await _crypt_room("sigil_fire")
	var crypt: Node = made[0]
	var player: Player = made[2]
	var room := _find_room(crypt, "chest", 1)
	if room.is_empty():
		room = _find_room(crypt, "chest", 0)
	_clear_chests(crypt)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	var chest_at: Vector3 = room.center + Vector3(0.5, 0, -1.0)
	crypt.set("_current_room", room)
	await _frames(40)
	crypt.call("_place_chest", chest_at, "elite", 0.0)
	var thing: Dictionary = (crypt.get("_interactables") as Array).back()
	# Standing over it, looking down at it.
	player.global_position = chest_at + Vector3(0, 0.1, 1.45)
	player.rotation = Vector3(0, 0, 0)
	player.get("_camera").rotation.x = deg_to_rad(-48.0)
	await _frames(60)
	_hide_center_messages(crypt)
	_mark()
	await _frames(24)
	# The lid swings up, glowing, then the find.
	var lid: Node3D = thing.lid
	var tween := lid.create_tween()
	tween.tween_property(lid, "rotation:x", -1.9, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	(thing.glow as OmniLight3D).light_energy = 4.0
	await _frames(22)
	crypt.call("_open_chest", thing)
	await _frames(50)
	_make_cursor()
	var hud: Node = crypt.get_node("HUD")
	var equip: Button = null
	for button in hud.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and not button.disabled:
			equip = button
			break
	if equip != null:
		await _move_cursor(equip.get_global_rect().get_center(), 28)
		await _frames(5)
		await _click()
		equip.pressed.emit()
	await _frames(18)


func _m_colossus() -> void:
	_max_build("combo_master", "temporal_break")
	var made := await _crypt_room("sigil_fire")
	var crypt: Node = made[0]
	var player: Player = made[2]
	GameState.select_power("sigil_fire")
	crypt.set("_floor", 2)
	var room := _find_room(crypt, "boss")
	player.global_position = room.center + Vector3(0, 0.1, minf(5.5, room.size.y / 2.0 - 2.0))
	player.look_at(room.center + Vector3(0, 1.4, 0))
	crypt.set("_current_room", room)
	_effects(player, crypt, "combo_master")
	crypt.call("_start_boss_fight", room)
	for i in 150:
		for enemy in crypt.get_node("Enemies").get_children():
			if enemy is Enemy and not enemy.is_boss:
				enemy.queue_free()
		await get_tree().process_frame
	_hide_center_messages(crypt)
	var boss: Enemy = null
	for enemy in crypt.get_node("Enemies").get_children():
		if enemy is Enemy and enemy.is_boss:
			boss = enemy
	boss.hp = boss.max_hp * 0.8
	boss.hp_floor = boss.max_hp * 0.25
	_bot.string = [["jab", "left"], ["cross", "right"], ["hook", "left"], ["uppercut", "right"], ["jab", "left"], ["hook", "right"], ["cross", "right"], ["uppercut", "left"]]
	_mark()
	# The fire power catches (it is set ablaze), then the fists.
	boss.ignite(120.0, 6.0)
	await _fight(player, 34)
	# Back off from his feet (he's huge), eyes rising to his face...
	var away := player.global_position - boss.global_position
	away.y = 0.0
	away = away.normalized()
	var camera: Camera3D = player.get("_camera")
	camera.fov = 92.0
	for i in 14:
		player.global_position += away * 0.13
		var face := Vector3(boss.global_position.x, _top_of(boss) - 0.9, boss.global_position.z)
		var to := face - camera.global_position
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), 0.3)
		camera.rotation.x = lerpf(camera.rotation.x, clampf(atan2(to.y, Vector2(to.x, to.z).length()) - 0.3, -0.2, 1.2), 0.2)
		await get_tree().process_frame
	# ...Temporal Break: time stops and the punches pile up, then land together.
	player.ult.fill()
	player.ult.activate()
	await _frames(14)
	# In stopped time, quick: jab, cross, hook, uppercut and round again, the
	# eyes up on his face. The circle runs down, and when it is black he falls.
	player.ult.set("_time_full", 3.0)
	player.ult.set("_time_left", 3.0)
	player.ult.set("_refund", 0.0)
	var types := ["jab", "cross", "hook", "uppercut"]
	var armed := false
	for i in 220:
		if player.ult.mode != "time_stop":
			break
		if i % 4 == 0:
			player.ult.answer_direct(types[(i / 4) % 4])
			boss.ignite(120.0, 6.0)
		var face := Vector3(boss.global_position.x, _top_of(boss) - 0.9, boss.global_position.z)
		var to := face - camera.global_position
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-to.x, -to.z), 0.3)
		camera.rotation.x = lerpf(camera.rotation.x, clampf(atan2(to.y, Vector2(to.x, to.z).length()) - 0.3, -0.2, 1.2), 0.25)
		if not armed and float(player.ult.get("_time_left")) < 0.6:
			# The held punches add up to the end of him.
			armed = true
			boss.hp_floor = 0.0
			boss.hp = boss.max_hp * 0.1
		await get_tree().process_frame
	await _frames(100)
	if is_instance_valid(boss) and not boss.is_dead():
		boss.hp_floor = 0.0
		_finisher(player, boss)
	await _frames(30)


func _m_upgrades() -> void:
	_light_build("counter_master")
	GameState.add_resource("coins", 9000)
	# Already played a little: a dozen of the first upgrades bought.
	for i in 12:
		for id in GameState.tree("upgrade"):
			if GameState.can_buy_node("upgrade", id):
				GameState.buy_node("upgrade", id)
				break
	GameState.add_resource("coins", 2500)
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	await _frames(60)
	camp.call("_show_page", "Upgrades")
	var tree: SkillTreeView = camp.get("_trees")["upgrade"]
	await _frames(20)
	tree.call("_zoom_at", tree.size / 2.0, 1.45)
	tree.call("_zoom_at", tree.size / 2.0, 1.45)
	await _frames(20)
	_make_cursor()
	_cursor.position = Vector2(1400, 700)
	_mark()
	var bought := 0
	var tried := {}
	for round in 10:
		if bought >= 5:
			break
		var pick := ""
		var best := INF
		var views: Dictionary = tree.get("_views")
		for id in views:
			if tried.has(id) or not GameState.can_buy_node("upgrade", id):
				continue
			var view: Control = views[id]
			if not view.is_visible_in_tree():
				continue
			var center := view.get_global_rect().get_center()
			var screen := get_viewport().get_visible_rect()
			if not screen.grow(-80.0).has_point(center):
				continue
			var d := center.distance_to(_cursor.position)
			if d < best:
				best = d
				pick = id
		if pick == "":
			break
		tried[pick] = true
		var node_view: Control = (tree.get("_views") as Dictionary)[pick]
		await _move_cursor(node_view.get_global_rect().get_center(), 11)
		# A double click on the node buys it.
		await _click()
		tree.select(pick)
		await _click()
		tree.node_activated.emit(pick)
		bought += 1
		await _frames(9)
	await _frames(12)


## The level-up draw: three cards flip over and one is picked.
func _m_cards() -> void:
	_light_build("counter_master")
	var info: Dictionary = GameState._classes[GameState.player_class]
	info.cards = {}
	info.level = 14
	info.draws = 1
	info.offer = []
	var camp: Node = load("res://camp.tscn").instantiate()
	add_child(camp)
	var draw: Node = null
	for i in 400:
		await get_tree().process_frame
		var found := get_tree().root.find_children("*", "CardDraw", true, false)
		if not found.is_empty():
			draw = found[0]
			break
	if draw == null:
		push_error("The draw never opened")
		return
	_make_cursor()
	_cursor.position = Vector2(1500, 900)
	_mark()
	# Wait for the three cards to flip face up.
	var faces: Array = []
	for i in 200:
		await get_tree().process_frame
		faces = draw.find_children("*", "CardTile", true, false).filter(func(tile: Node) -> bool: return tile.is_visible_in_tree() and not tile.disabled)
		if faces.size() >= 3 and i > 24:
			break
	await _frames(18)
	var pick: Control = faces[1] if faces.size() > 1 else faces[0]
	await _move_cursor(pick.get_global_rect().get_center(), 20)
	await _frames(4)
	await _click()
	pick.pressed.emit()
	# Through the pick animation, and out the moment it closes.
	for i in 120:
		await get_tree().process_frame
		if not is_instance_valid(draw) or draw.is_queued_for_deletion():
			break
	await _frames(3)


# --- The powers --------------------------------------------------------------------------

## One fighter and one power, into a crowd. The power is made to go off all
## through the clip (cooldowns cleared, Gale charged, and each one called at
## the moments you'd see it), so every effect is on screen.
func _m_power(fighter: String, power: String, division: int, power_up: bool) -> void:
	_max_build(fighter)
	GameState.select_power(power)
	GameState.power_pick_2 = ""
	GameState.power_pick_3 = ""
	GameState.power_pick_4 = ""
	var world := await _arena(division)
	var player: Player = world.get_node("Player")
	_effects(player, world, fighter)
	_fx_node.set("calm", power in ["sigil_fire", "sigil_gale"])
	await _frames(110)
	_hide_center_messages(world)
	var hud: CanvasLayer = world.get_node("HUD")
	if power_up:
		# The Mauler powers up (Intense Yelling) before the fight.
		hud.visible = false
		player.start_emote("intense_yelling")
		# Straight to the good part: the rocks tearing up and the lightning
		# (they come in at 3 s and 6 s of a held yell).
		player.get("_emote_fx").set("_time", 7.0)
		player.get("_emote_cam").fov = 54.0
		player.set("_emote_orbit", Vector2(PI, 0.06))
		_mark()
		player.set("_emote_out", 1.0)
		var yell: Node = player.get("_emote_fx")
		yell.set("_time", 8.5)
		for i in 78:
			# A bolt comes down every so often, so the lightning is always there.
			if i in [8, 30, 52, 70]:
				yell.call("_strike")
			await get_tree().process_frame
		player.call("_stop_emote", true)
		player.set("_emote_out", 0.0)
		hud.visible = true
		await _frames(4)
	else:
		_mark()
	_bot.string = [["jab", "left"], ["cross", "right"], ["hook", "left"], ["uppercut", "right"], ["jab", "left"], ["cross", "right"], ["hook", "right"], ["uppercut", "left"]]
	_bot.gap = 0.45 if power in ["sigil_fire", "sigil_gale"] else 0.3
	_bot.far = power == "sigil_gale"
	await _spawn_for(world, power)
	for frame in 118:
		# Keep some of the crowd standing so there is always something to hit.
		if frame % 20 == 0:
			var alive := 0
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy is Enemy and not enemy.is_dead():
					alive += 1
					enemy.hp_floor = enemy.max_hp * 0.15
			if alive < 4:
				await _spawn_for(world, power)
		_power_moment(player, power, frame)
		_bot_step(player)
		await get_tree().process_frame


## The crowd closing in, or (for Gale) a row of monsters far down the ring:
## the air blasts are for the ones out of reach.
func _spawn_for(world: Node, power: String) -> void:
	if power != "sigil_gale":
		await _crowd(world)
		return
	var kinds := ["zombie", "brawler", "skeleton", "zombie"]
	for i in kinds.size():
		var x := lerpf(-3.0, 3.0, i / float(kinds.size() - 1))
		var z := -6.2 - (i % 3) * 1.5
		world.call("_spawn_enemy", {"kind": kinds[i], "armored": false}, Vector3(x, 0.1, z))
	await _frames(2)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy:
			enemy.move_speed *= 0.25


func _foes_near(player: Player, count: int) -> Array:
	var foes: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and not enemy.is_dead():
			foes.append(enemy)
	foes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	return foes.slice(0, count)


func _power_moment(player: Player, power: String, frame: int) -> void:
	var powers: Node = player.get("powers")
	if frame % 24 == 3:
		(powers.get("_cooldown") as Dictionary).clear()
	var near := _foes_near(player, 3)
	if near.is_empty():
		return
	var target: Enemy = near[0]
	var damage := GameState.get_damage()
	match power:
		"sigil_fire":
			if frame in [20, 78]:
				Powers.fire_burst(target, damage * maxf(GameState.get_effect("fire_punch"), 2.0))
				for foe in near.slice(0, 2):
					(foe as Enemy).ignite(160.0, 5.0)
		"sigil_storm":
			if frame in [12, 40, 66, 92]:
				Powers.chain_lightning(target, damage * 3.0, maxi(int(GameState.get_effect("chain_lightning")), 4))
		"sigil_doom":
			if frame in [10, 34, 60, 86]:
				for foe in near:
					Powers.doom_mark(foe)
			if frame in [28, 54, 80, 108]:
				for foe in near:
					if (foe as Enemy).is_doomed():
						(foe as Enemy).detonate_doom()
		"sigil_gale":
			if frame % 14 == 2:
				powers.set("gale", 3)
