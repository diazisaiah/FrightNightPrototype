extends Node
## Lightweight balance/input regression checks. Run with:
## Godot --headless --path <project> res://balance_regression.tscn
##
## This deliberately avoids loading the rendered scenes, so it can also run on
## CI machines without a GPU. It does not save or alter player progression.

var _failures: Array[String] = []


func _ready() -> void:
	# Never touch the real save or settings, however this is launched: these
	# checks reset and save GameState (a run on 2026-10-11 wiped a real save).
	GameState.save_path = "user://test_save.json"
	Settings.path = "user://test_settings.cfg"
	call_deferred("_run")


func _run() -> void:
	_test_control_preset()
	_test_progression_webs()
	_test_upgrade_reveal_gates()
	_test_melee_turns()
	_test_balance_constants()
	_test_climb_economy()
	_test_seals_and_gear()
	_test_hats_and_tony()
	_test_web_optimization_structure()
	_test_browser_audio_guard()
	_test_crypt_unlock()
	_test_class_balance()
	_test_emotes_and_hats()
	_test_pad_work_combos()
	if _failures.is_empty():
		print("BALANCE REGRESSION: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("BALANCE REGRESSION: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _pad_buttons(action: String) -> Array:
	var result := []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			result.append(event.button_index)
	return result


func _ui_cancel_pad() -> InputEvent:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	return event


func _keys(action: String) -> Array[Key]:
	var result: Array[Key] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			result.append(event.physical_keycode)
	return result


func _test_control_preset() -> void:
	var old_dodge = Settings.values.dodge_mode
	var old_assist = Settings.values.assist_mode
	var old_bindings = Settings.values.get("bindings", {})
	Settings.values.bindings = {}
	# Weenie Hut Junior Mode: Q / E dodge, so Space jumps and no modifier is held.
	Settings.values.assist_mode = "junior"
	Settings.values.dodge_mode = "space"
	Controls.apply()
	_check(_keys("jump") == [KEY_SPACE], "Weenie Hut Junior Mode jumps with Space")
	_check(_keys("dodge_modifier").is_empty(), "Weenie Hut Junior Mode has no dodge modifier")
	# Bindings: taking another action's key swaps them.
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	Controls.bind("jump", q)
	_check(_keys("jump") == [KEY_Q] and _keys("slip_left") == [KEY_SPACE], "Binding a used key swaps the two actions")
	Settings.values.bindings = {}
	Settings.values.assist_mode = "pro"
	Settings.values.dodge_mode = "keys"
	Controls.apply()
	_check(_keys("roll_left_key") == [KEY_TAB], "Tab must be the dedicated left roll key")
	_check(_keys("roll_right_key") == [KEY_R], "R must be the dedicated right roll key")
	_check(_keys("ultimate") == [KEY_T], "The dedicated roll preset must move ultimate to T")
	_check(_keys("jump") == [KEY_SPACE], "The dedicated roll preset must keep jump on Space")
	_check(_keys("dodge_modifier") == [KEY_CTRL], "The dedicated roll preset must keep Ctrl+S back step")
	_check(Controls.text("map") == "M", "The dedicated roll preset must move the Crypt map to M")
	_check(Controls.summary().contains("T ultimate"), "The HUD summary must show T for ultimate")
	# Controllers: a full layout, PlayStation names, and hints that follow.
	Settings.values.assist_mode = "junior"
	Settings.values.dodge_mode = "space"
	Controls.apply()
	_check(_pad_buttons("jump") == [JOY_BUTTON_A] and _pad_buttons("pause") == [JOY_BUTTON_START], "Controllers jump with A and pause with Start")
	_check(_pad_buttons("roll_left_key").is_empty(), "Weenie Hut Junior Mode leaves rolls to the bumpers on a controller")
	_check(not InputMap.action_has_event("pause", _ui_cancel_pad()), "B / Circle (ui_cancel) must not pause a fight")
	var was_active := Pad.active
	var was_kind := Pad.kind
	Pad.active = true
	Pad.kind = "xbox"
	_check(Controls.text("hook") == "LT" and Controls.text("slip") == "LB or RB", "Controller hints name the triggers and bumpers")
	Pad.kind = "playstation"
	_check(Controls.text("hook") == "L2" and Controls.key_name("jump") == "Cross", "PlayStation controllers get PlayStation names")
	Pad.active = was_active
	Pad.kind = was_kind
	Settings.values.dodge_mode = old_dodge
	Settings.values.assist_mode = old_assist
	Settings.values.bindings = old_bindings
	Controls.apply()


func _node_cost(node: Dictionary) -> int:
	var total := 0
	for level in node.max_level:
		total += roundi(node.cost * pow(node.cost_growth, level))
	return total


func _audit_tree(name: String, nodes: Dictionary) -> void:
	var positions := {}
	for id in nodes:
		var node: Dictionary = nodes[id]
		_check(Icons.NAMES.has(node.icon), "%s node %s has no icon named %s" % [name, id, node.icon])
		for required in node.requires:
			_check(nodes.has(required), "%s node %s requires missing node %s" % [name, id, required])
		var position: Vector2 = node.pos
		_check(not positions.has(position), "%s nodes %s and %s overlap at %s" % [name, positions.get(position, ""), id, position])
		positions[position] = id


func _test_progression_webs() -> void:
	_audit_tree("upgrade", GameState.UPGRADES)
	# Rings: every node has one, never sits inside a ring its parents are behind,
	# and each ring costs more than the one before.
	var ring_totals := {}
	for id in GameState.UPGRADES:
		var node: Dictionary = GameState.UPGRADES[id]
		var ring := int(node.get("ring", 0))
		_check(ring >= 1 and ring <= 6, "Upgrade %s needs a ring 1-6" % id)
		for required in node.requires:
			_check(int(GameState.UPGRADES[required].get("ring", 0)) <= ring,
					"Upgrade %s (ring %d) can't need %s from a later ring" % [id, ring, required])
		ring_totals[ring] = ring_totals.get(ring, 0) + _node_cost(node)
	for ring in range(2, 6):
		_check(ring_totals[ring] > ring_totals[ring - 1], "Ring %d should cost more than ring %d" % [ring, ring - 1])
	print("Ring costs: %s" % ring_totals)
	# Each contender's seal opens its power's Sigil node and a Trophy in the next ring.
	for i in Progression.TIER_COUNT:
		var tier: Dictionary = Progression.TIERS[i]
		if tier.ring_power != "":
			_check(int(GameState.UPGRADES[tier.ring_power].ring) == i + 2, "%s must open with contender %d's seal" % [tier.ring_power, i + 1])
		_check(int(GameState.UPGRADES[tier.trophy].ring) == i + 2, "Trophy %s must sit in ring %d" % [tier.trophy, i + 2])
	_check(GameState.UPGRADE_VERSION == 7 and GameState.V5_PRICES.size() > 50 and GameState.V4_PRICES.size() > 50,
			"The spoke web must refund version-4 and version-5 saves at their old prices")
	# v6 -> v7 (prices tamed): levels are kept and the difference comes back.
	var bought := {"wrapped_knuckles": 1, "dmg_1": 5, "hp_1": 5, "dmg_2": 3}
	var tamed = load("res://game_state.gd").new()
	tamed._reset_fields()
	tamed._load_upgrades(bought)
	tamed._refund_price_drop(bought, GameState.V6_PRICES)
	var expected := 0
	for id in bought:
		for level in bought[id]:
			expected += maxi(0, roundi(GameState.V6_PRICES[id][0] * pow(GameState.V6_PRICES[id][1], level)) - roundi(GameState.UPGRADES[id].cost * pow(GameState.UPGRADES[id].cost_growth, level)))
	_check(tamed.upgrade_levels.get("dmg_1", 0) == 5 and tamed.upgrade_levels.get("dmg_2", 0) == 3, "Taming prices keeps every bought level")
	_check(expected > 0 and tamed.resources.coins == expected, "Taming prices refunds the difference (%d, expected %d)" % [tamed.resources.coins, expected])
	tamed.free()
	_check(GameState.SKILL_VERSION == 2, "Skill web v2 must refund every older skill point")

	# A maxed version-3 web comes back at its old (pre-ring) prices, about 43k,
	# not today's ring prices; its Champion Sigils become Souls.
	var old_max := {}
	for id in GameState.V4_LEVELS:
		if not id in ["bellmans_bell", "headless_helm", "southpaws_rosary", "plague_censer", "coffin_crown"]:
			old_max[id] = GameState.V4_LEVELS[id]
	var migrated = load("res://game_state.gd").new()
	migrated._reset_fields()
	migrated._respec_for_rings(old_max, 2)
	_check(migrated.resources.coins >= 40000 and migrated.resources.coins <= 47000,
			"A maxed v3 web should refund about 43,000 old-price coins, got %d" % migrated.resources.coins)
	_check(migrated.souls == 2 * migrated.SOULS_PER_OLD_SIGIL, "Old Champion Sigils must become Souls")
	migrated.free()

	for class_id in GameState.SKILL_TREES:
		var nodes: Dictionary = GameState.SKILL_TREES[class_id]
		_audit_tree(class_id, nodes)
		var sealed := 0
		for node in nodes.values():
			if int(node.get("ring", 1)) > 1:
				sealed += 1
		_check(sealed == 5, "%s should have three sealed capstones plus Ultimate Surge and Ultimate II" % class_id)
		var points := 0
		for node in nodes.values():
			points += int(node.cost) * int(node.max_level)
			for effect in node.effects:
				_check(effect != "head_bonus", "%s: head shots are too hard to land to build a skill around" % class_id)
		_check(points == int(Progression.SKILL_WEB_POINTS), "%s's web should cost %d points, got %d" % [class_id, Progression.SKILL_WEB_POINTS, points])


func _test_upgrade_reveal_gates() -> void:
	var state = load("res://game_state.gd").new()
	state._reset_fields()
	state.resources.coins = 999999
	_check(state.node_state("upgrade", "gold_1") == "hidden",
			"An upgrade must stay hidden until its parent is maxed")
	state.upgrade_levels.wrapped_knuckles = 1
	_check(state.node_state("upgrade", "gold_1") == "available",
			"Maxing an upgrade must reveal its immediate children")
	state.upgrade_levels.gold_1 = 1
	_check(state.node_state("upgrade", "sparring_partner") == "hidden",
			"One rank in a multi-rank upgrade must not reveal the next node")
	_check(not state.can_buy_node("upgrade", "sparring_partner"),
			"A hidden upgrade must not be buyable through code")
	state.upgrade_levels.gold_1 = GameState.UPGRADES.gold_1.max_level
	_check(state.node_state("upgrade", "sparring_partner") == "available",
			"The next upgrade must appear when its parent reaches max rank")
	_check(state.can_buy_node("upgrade", "sparring_partner"),
			"A revealed upgrade with enough coins must be buyable")
	state.free()


func _test_melee_turns() -> void:
	Enemy._attackers = []
	Enemy.max_attackers = 1
	var first := Enemy.new()
	var second := Enemy.new()
	_check(first.has_turn(), "The first melee enemy should claim the open attack turn")
	_check(not second.has_turn(), "A second melee enemy must wait when the single turn is occupied")
	first.end_turn()
	_check(second.has_turn(), "The waiting melee enemy should rotate in after the attacker finishes")
	Enemy._attackers = []
	Enemy.max_attackers = 2
	var third := Enemy.new()
	var fourth := Enemy.new()
	_check(third.has_turn() and fourth.has_turn(), "Later floors/nights should allow two melee attackers")
	first.free()
	second.free()
	third.free()
	fourth.free()
	Enemy._attackers = []
	Enemy.max_attackers = 1


func _test_balance_constants() -> void:
	var dungeon = load("res://dungeon.gd")
	_check(is_equal_approx(dungeon.CRYPT_COIN_SCALE, 0.6), "Crypt kill coins should use the 0.6 scale")
	_check(is_equal_approx(dungeon.CRYPT_XP_SCALE, 0.6), "Crypt XP should use the 0.6 scale")
	_check(dungeon.VICTORY_COINS == 300, "The first Crypt victory bonus should be 300 coins")
	_check(Player.STRAIGHT_RUN_LIMIT == 4, "Plain straight strings should stop growing the combo after 4 hits")
	_check(is_equal_approx(Powers.CHAIN_DAMAGE, 0.4), "Chain Lightning should start at 40% damage")
	_check(is_equal_approx(Powers.CHAIN_FALLOFF, 0.75), "Chain Lightning jumps should fall off to 75%")
	_check(Ult.DESCRIPTIONS.berserker.findn("press R") == -1, "The fighter picker must not hard-code R for Inferno")
	var player := Player.new()
	player.combo = 100
	_check(player.get_combo_multiplier() <= Player.MAX_COMBO_MULTIPLIER, "Combo damage must respect the hard multiplier cap")
	player.free()


func _test_web_optimization_structure() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var run := Scenery.fence(holder, 10.0)
	_check(run.get_child_count() == 2, "A fence run should be two batched MultiMeshes")
	var instances := 0
	for child in run.get_children():
		_check(child is MultiMeshInstance3D, "Fence children must be MultiMesh batches, not individual meshes")
		if child is MultiMeshInstance3D:
			instances += child.multimesh.instance_count
	_check(instances > 100, "The batched fence must retain all of its visible bars, rails and pillars")
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(preset.contains("html/canvas_resize_policy=1"),
			"The Web canvas must stay at project resolution instead of scaling to Retina size")
	holder.free()
	Look._grain = null


func _test_browser_audio_guard() -> void:
	_check(AudioServer.get_bus_index("Effects") > 0, "The Effects bus must exist")
	_check(AudioServer.get_bus_index("Ambience") > 0, "The Ambience bus must exist")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Effects")) == &"Master",
			"The Effects bus must feed Master")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == &"Master",
			"The Ambience bus must feed Master")
	for sound in Sfx.get("_streams"):
		_check((Sfx.get("_streams") as Dictionary)[sound].can_be_sampled(),
				"Synthesized sound %s must support low-latency Web sample playback" % sound)
	var was_unlocked: bool = Sfx.get("_audio_unlocked")
	Sfx.set("_audio_unlocked", false)
	Sfx.play_ambience("wind", -18.0, 0.8)
	_check(not (Sfx.get("_pending_ambience") as Dictionary).is_empty(),
			"Browser ambience must wait for a user gesture")
	var input := InputEventKey.new()
	input.pressed = true
	input.physical_keycode = KEY_SPACE
	Sfx._input(input)
	_check(Sfx.get("_audio_unlocked"), "A pressed key must unlock browser audio")
	_check((Sfx.get("_pending_ambience") as Dictionary).is_empty(),
			"Queued ambience must start on the unlock gesture")
	_check((Sfx.get("_ambience") as AudioStreamPlayer).playing,
			"The ambience player must be active after browser audio unlocks")
	var ambience_tween: Tween = Sfx.get("_ambience_tween")
	if ambience_tween:
		ambience_tween.kill()
	Sfx.set("_ambience_tween", null)
	var ambience: AudioStreamPlayer = Sfx.get("_ambience")
	ambience.stop()
	ambience.stream = null
	Sfx.set("_audio_unlocked", was_unlocked)


## The Climb's economy and par curve: each tier's ring costs about as many
## good Arena bouts as the others, par grows every tier, and a build well
## under par (60% of the upgrades) is clearly weaker than the par build.
func _test_climb_economy() -> void:
	var world = load("res://world.gd")
	var previous := Progression.par(0)
	for tier in range(1, Progression.TIER_COUNT + 1):
		var par := Progression.par(tier)
		_check(par.damage > previous.damage and par.ehp > previous.ehp, "Par must grow every tier (tier %d)" % tier)
		previous = par
		var ring_cost := 0
		for id in GameState.UPGRADES:
			if int(GameState.UPGRADES[id].get("ring", 1)) == tier:
				ring_cost += _node_cost(GameState.UPGRADES[id])
		# A B-grade bout, averaged over the division's bouts (each pays 1.5x the
		# last): purse, kills, milestones.
		var per_bout := 0.0
		for bout in range(1, Progression.BOUTS_PER_DIVISION + 1):
			var x := Progression.arena_position(tier, bout)
			per_bout += (world.ARENA_PURSE * 1.3 + world.KILLS_TO_BOSS * 5.0 * 1.25 + 225.0) * Progression.pay(x) / Progression.BOUTS_PER_DIVISION
		var bouts := ring_cost * Progression.PAR_SHARE / per_bout
		print("Tier %d: par %.1f dmg / %.0f ehp, ring %d coins, ~%.1f good bouts to reach par" % [tier, par.damage, par.ehp, ring_cost, bouts])
		# Tier 1 is meant to be quick (the first upgrades must come fast).
		# Tamed 2026-10-17: about 2 good bouts for ring 1, about 3 for the rest.
		_check(bouts >= (1.5 if tier == 1 else 2.2) and bouts <= 4.0, "Tier %d should take about 3 good bouts to reach par, got %.1f" % [tier, bouts])
	# Under par: the same tier's numbers with only 60% of the upgrades.
	var full := Progression.par(3)
	var under := _par_with_share(3, 0.6)
	_check(under.damage < full.damage * 0.9 and under.ehp < full.ehp * 0.9,
			"60%% of the upgrades should be clearly weaker than par (%.1f vs %.1f dmg)" % [under.damage, full.damage])
	print("Tier 3 at 60%% upgrades: %.1f dmg / %.0f ehp (par %.1f / %.0f)" % [under.damage, under.ehp, full.damage, full.ehp])


## Progression.par with a different upgrade share (for the under-par check).
func _par_with_share(tier: int, share: float) -> Dictionary:
	var levels := []
	for id in GameState.UPGRADES:
		var node: Dictionary = GameState.UPGRADES[id]
		if int(node.get("ring", 1)) > tier or not Progression._is_power(node):
			continue
		for level in int(node.max_level):
			levels.append([node.cost * pow(node.cost_growth, level), id])
	levels.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var effects := {}
	for i in ceili(levels.size() * share):
		var node_effects: Dictionary = GameState.UPGRADES[levels[i][1]].effects
		for effect in node_effects:
			effects[effect] = effects.get(effect, 0.0) + float(node_effects[effect])
	var par := Progression.par(tier)
	var full_effects := {}
	for i in ceili(levels.size() * Progression.PAR_SHARE):
		var node_effects: Dictionary = GameState.UPGRADES[levels[i][1]].effects
		for effect in node_effects:
			full_effects[effect] = full_effects.get(effect, 0.0) + float(node_effects[effect])
	var skill := 1.0 + Progression.SKILL_PAR * minf(1.0, (int(Progression.PAR_LEVEL[tier]) - 1) / Progression.SKILL_WEB_POINTS)
	var damage: float = (par.damage / skill - full_effects.get("damage", 0.0) + effects.get("damage", 0.0)) * skill
	var knuckles: float = (par.knuckles / skill - full_effects.get("max_knuckles", 0.0) + effects.get("max_knuckles", 0.0)) * skill
	var defense: float = par.defense - full_effects.get("defense", 0.0) + effects.get("defense", 0.0)
	return {"damage": damage, "ehp": knuckles * (10.0 + defense) / 10.0}


## Seals and kept gear: a contender's win opens the next ring; Crypt finds
## survive only gilded and carried out; a knockout keeps what you came with.
func _test_seals_and_gear() -> void:
	var saved_clears: Dictionary = GameState.dead_league_clears.duplicate()
	var saved_equipped: Dictionary = GameState.equipped.duplicate()
	var saved_armory: Array = GameState.armory.duplicate()
	var saved_souls := GameState.souls
	GameState.dead_league_clears = {}
	_check(Progression.open_ring() == 1 and Progression.current_tier() == 1, "A fresh climb starts at tier 1 with ring 1 open")
	_check(not GameState.node_open("upgrade", "sigil_fire"), "Fire must be sealed before the Bellman falls")
	GameState.dead_league_clears = {"bellman": true}
	_check(GameState.node_open("upgrade", "sigil_fire") and not GameState.node_open("upgrade", "sigil_frost"),
			"Beating the Bellman opens Fire (ring 2), not Frost")
	# Gear: bring gloves in, find wraps and a charm, gild only the wraps.
	GameState.armory = []
	GameState.equipped = {}
	var gloves := {"slot": "gloves", "rarity": "rare", "name": "Test Gloves", "effects": {"damage": 1.0}, "floor": 1}
	GameState.equip(gloves)
	GameState.armory.append(gloves)
	GameState.begin_crypt_run()
	var wraps := {"slot": "wraps", "rarity": "rare", "name": "Found Wraps", "effects": {"max_knuckles": 5.0}, "floor": 1, "found": true}
	var charm := {"slot": "charm", "rarity": "common", "name": "Found Charm", "effects": {"xp_bonus": 0.1}, "floor": 1, "found": true}
	GameState.equip(wraps)
	GameState.equip(charm)
	GameState.souls = 10
	_check(GameState.gild(wraps), "Gilding with enough Souls must work")
	var kept := GameState.end_crypt_run(true)
	_check(kept.size() == 1 and kept[0].name == "Found Wraps", "Leaving by the stairs keeps only gilded finds")
	_check(GameState.equipped.has("gloves") and GameState.equipped.has("wraps") and not GameState.equipped.has("charm"),
			"After leaving: brought gear and gilded finds are worn, ungilded finds are gone")
	# A knockout: even a gilded find is lost; only what you came in with stays.
	GameState.begin_crypt_run()
	var boots := {"slot": "boots", "rarity": "rare", "name": "Found Boots", "effects": {"move_speed": 0.05}, "floor": 1, "found": true}
	GameState.equip(boots)
	GameState.gild(boots)
	GameState.end_crypt_run(false)
	_check(not GameState.equipped.has("boots") and GameState.armory.size() == 2,
			"A knockout keeps only what you came in with, gilded finds included")
	GameState.dead_league_clears = saved_clears
	GameState.equipped = saved_equipped
	GameState.armory = saved_armory
	GameState.souls = saved_souls


func _weighted_kind(types: Dictionary, progress: float) -> String:
	var total := 0.0
	for info in types.values():
		if progress >= info.unlock:
			total += info.weight
	var roll := randf() * total
	for kind in types:
		var info: Dictionary = types[kind]
		if progress < info.unlock:
			continue
		roll -= info.weight
		if roll <= 0.0:
			return kind
	return "zombie"


func _elite_kind(types: Dictionary, progress: float) -> String:
	var choices: Array[String] = []
	for kind in types:
		if progress >= types[kind].unlock and not kind in ["priest", "skeleton", "mage", "lich"]:
			choices.append(kind)
	return choices.pick_random()


func _crypt_reward(base: Vector2i, armored: bool, progress: float, floor_number: int,
		elite: bool, dungeon: GDScript) -> Vector2i:
	var coins := base.x * (2 if armored else 1)
	var xp := roundi(base.y * (1.5 if armored else 1.0))
	var reward_scale: float = 1.0 + dungeon.FLOOR_REWARD_GROWTH * (floor_number - 1)
	if progress >= 0.0:  # Bosses use floor scaling only.
		reward_scale *= 1.0 + dungeon.REWARD_GROWTH * progress
	coins = roundi(coins * reward_scale)
	xp = roundi(xp * reward_scale)
	if elite:
		coins *= Enemy.ELITE_REWARD
		xp *= Enemy.ELITE_REWARD
	return Vector2i(roundi(coins * dungeon.CRYPT_COIN_SCALE), roundi(xp * dungeon.CRYPT_XP_SCALE))


## Hats: about 1% of enemies, legendaries never duplicates and on bad-luck
## protection (~22 hats each), duplicates turn into Souls, the four Yonkers
## do nothing on their own and unlock Tony once.
func _test_hats_and_tony() -> void:
	GameState._reset_fields()
	seed(1234)
	var hatted := 0
	for i in 100000:
		if Hats.roll(false) != "":
			hatted += 1
	var expected := Hats.HAT_CHANCE * 100000.0
	_check(absf(hatted - expected) < expected * 0.2, "About %d%% of enemies should wear a hat (got %d in 100k)" % [roundi(Hats.HAT_CHANCE * 100), hatted])
	# Hats per legendary, from a fresh collection.
	GameState._reset_fields()
	var hats := 0
	var legendaries := 0
	while legendaries < 4 and hats < 2000:
		var id := ""
		while id == "":
			id = Hats.roll(false)
		hats += 1
		if Hats.CATALOG[id].rarity == "legendary":
			_check(not GameState.hats.has(id), "A legendary must always be one you're missing")
			legendaries += 1
		GameState.hats[id] = 1
	_check(legendaries == 4, "All four Yonkers must turn up")
	_check(hats > 30 and hats < 200, "All four Yonkers should take roughly 88 hats (took %d)" % hats)
	# Duplicates, the do-nothing legendaries, and Tony.
	GameState._reset_fields()
	_check(GameState.add_hat("party_hat") == "new", "A new hat is collected")
	_check(is_equal_approx(GameState.get_effect("damage_percent"), 0.01), "A hat's boost counts")
	var souls := GameState.souls
	_check(GameState.add_hat("party_hat") == "duplicate" and GameState.souls == souls + Hats.DUPLICATE_SOULS.common, "A duplicate hat turns into Souls")
	var before := PowerRating.player()
	for id in ["yonker_brim", "yonker_no_brim", "brim_no_yonker"]:
		_check(GameState.add_hat(id) == "new", "A Yonker is collected")
	_check(PowerRating.player() == before and not GameState.tony_unlocked, "Three Yonkers do nothing")
	_check(not "wise_guy" in GameState.class_ids(), "Tony stays hidden until all four Yonkers")
	_check(GameState.add_hat("no_yonker_no_brim") == "tony" and GameState.tony_unlocked, "The fourth Yonker unlocks Tony")
	_check("wise_guy" in GameState.class_ids(), "Tony shows in the class picker once unlocked")
	_check(GameState.add_hat("no_yonker_no_brim") == "duplicate", "Tony only unlocks once")
	_check(GameState.SKILL_TREES.has("wise_guy") and GameState.SKILL_TREES.wise_guy.size() == GameState.SKILL_TREES.berserker.size(), "Tony has a full skill web")
	GameState._reset_fields()


## The Crypt opens with the Bellman's seal (not by wandering the Arena), and
## the Bellman is tuned to a fighter with no gear, since gear comes from it.
func _test_crypt_unlock() -> void:
	var state = load("res://game_state.gd").new()
	state._reset_fields()
	state.save_path = "user://test_save_crypt.json"
	_check(not state.crypt_unlocked, "A fresh save starts with the Crypt sealed")
	state.record_dead_league_result("headless", "B", 1000)
	_check(not state.crypt_unlocked, "Only the Bellman's seal opens the Crypt")
	state.record_dead_league_result("bellman", "B", 1000)
	_check(state.crypt_unlocked and state.crypt_reveal_pending and state.crypt_new, "Beating the Bellman opens the Crypt and queues the camp reveal")
	state.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_crypt.json"))
	var gear: Dictionary = Progression._par_gear(1)
	_check(gear.damage == 0.0 and gear.knuckles == 0.0, "The Bellman's par has no gear: the Crypt isn't open yet")
	_check(not FileAccess.file_exists("res://world.gd") or FileAccess.get_file_as_string("res://world.gd").find("_raise_crypt_entrance") == -1,
			"The Arena no longer raises a crypt mid-bout")


## Every class at par (its level's skills, par upgrades and gear) should rate
## about even with the contender it faces, and every full skill web should be
## worth about the same. Runs last: it rewrites the build in GameState.
func _test_class_balance() -> void:
	var report = load("res://balance_report.gd")
	var saved_class := GameState.player_class
	for tier in range(1, Progression.TIER_COUNT + 1):
		for class_id in GameState.CLASSES:
			report.set_build(GameState, Progression, class_id, tier)
			var ratio := float(PowerRating.player()) / float(PowerRating.contender(tier - 1))
			_check(ratio > 0.88 and ratio < 1.2, "%s at par for tier %d should rate about even with the contender, got %.2f" % [class_id, tier, ratio])
	var uplifts := []
	for class_id in GameState.CLASSES:
		report.set_build(GameState, Progression, class_id, 5, 0)
		var without := float(PowerRating.player())
		report.set_build(GameState, Progression, class_id, 5, 999)
		uplifts.append(float(PowerRating.player()) / without)
	_check(uplifts.max() - uplifts.min() < 0.2, "Full skill webs should be worth about the same for every class: %s" % [uplifts])
	print("Full skill web POWER: %s" % [uplifts.map(func(u: float) -> String: return "x%.2f" % u)])
	GameState.player_class = saved_class


## Emotes: every dance only moves real joints; the emote key is G / View
## (the controller's map tap rides on it); a worn hat must be owned and saves.
func _test_emotes_and_hats() -> void:
	_check(Emotes.ORDER.size() == Emotes.NAMES.size(), "Every dance is on the wheel")
	for id in Emotes.ORDER:
		var keys := Emotes.keys(id)
		_check(keys.size() >= 2, "%s has a loop of poses" % id)
		for key in keys:
			_check(float(key[0]) > 0.0, "%s keys take time" % id)
			for joint in key[1]:
				_check(joint == "pos" or joint in Emotes.JOINTS, "%s moves a real joint (not %s)" % [id, joint])
	var flipped := Emotes.mirror({"ls": Vector3(1, 0.2, 0.3), "pos": Vector3(0.1, 0, 0)})
	_check(flipped.has("rs") and flipped.rs == Vector3(1, -0.2, -0.3) and flipped.pos == Vector3(-0.1, 0, 0), "mirror() swaps sides")
	var old_bindings = Settings.values.get("bindings", {})
	var old_pad = Settings.values.get("pad_bindings", {})
	Settings.values.bindings = {}
	Settings.values.pad_bindings = {}
	Controls.apply()
	_check(_keys("emote") == [KEY_G], "G emotes")
	var old_assist = Settings.values.assist_mode
	Settings.values.assist_mode = "pro"
	Controls.apply()
	_check(_pad_buttons("emote") == [JOY_BUTTON_BACK], "View / Create holds for the emote wheel")
	_check(_pad_buttons("back_step_key") == [JOY_BUTTON_DPAD_DOWN], "Pro Gamer Mode keeps D-pad down for the back step")
	Settings.values.assist_mode = "junior"
	Controls.apply()
	_check(_pad_buttons("emote") == [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_BACK], "Weenie Hut Junior Mode emotes on D-pad down too")
	_check(Controls.pad_name("emote") == Pad.input_name(Controls._primary_pad("emote")) and Controls._primary_pad("emote").button_index == JOY_BUTTON_DPAD_DOWN, "Junior hints show D-pad down for emote")
	Settings.values.assist_mode = old_assist
	Controls.apply()
	_check(_pad_buttons("map").is_empty(), "The map has no button of its own on a controller (a tap of emote opens it)")
	_check(Controls.pad_name("map") == Controls.pad_name("emote"), "The controller map hint shows the emote button")
	Settings.values.bindings = old_bindings
	Settings.values.pad_bindings = old_pad
	Controls.apply()
	GameState._reset_fields()
	GameState.wear_hat("top_hat")
	_check(GameState.worn_hat == "", "You can't wear a hat you don't own")
	GameState.add_hat("top_hat")
	GameState.wear_hat("top_hat")
	_check(GameState.worn_hat == "top_hat", "You can wear a hat you own")
	GameState.save_game()
	GameState.worn_hat = ""
	GameState.load_game()
	_check(GameState.worn_hat == "top_hat", "The worn hat is saved")
	GameState.wear_hat("top_hat")
	_check(GameState.worn_hat == "", "Clicking the worn hat takes it off")
	GameState._reset_fields()


## Pad Work only calls combos you can throw clean: hands alternate (one
## double jab), and every hook or uppercut is set up, by the player's rules.
func _test_pad_work_combos() -> void:
	var drill = load("res://drills.gd").new()
	seed(99)
	for level in [1, 3, 6, 10, 16, 25]:
		drill._level = level
		for n in 300:
			var combo: Array = drill._make_combo()
			var last_hand := ""
			var last_type := ""
			var last_set_up := false
			var jab_run := 0
			for i in combo.size():
				var type: String = combo[i]
				var hand := "left" if type == "jab" else ("right" if type == "cross" else ("right" if last_hand == "left" else "left"))
				_check(hand == drill._pad_hands[i], "Pad Work knows which hand throws each punch")
				var jab_repeat := type == "jab" and last_type == "jab" and hand == last_hand
				jab_run = jab_run + 1 if jab_repeat else (1 if type == "jab" else 0)
				if i > 0 and hand == last_hand and not (jab_repeat and jab_run <= 2):
					_check(false, "Pad Work called the same hand twice: %s" % [combo])
				var heavy: bool = Player.PUNCHES[type].heavy
				var set_up := heavy and i > 0 and hand != last_hand \
						and (last_type in ["jab", "cross"] or (type == "uppercut" and last_type == "hook" and last_set_up))
				if heavy and not set_up:
					_check(false, "Pad Work called an unset-up %s: %s" % [type, combo])
				last_hand = hand
				last_type = type
				last_set_up = set_up
	drill.free()
