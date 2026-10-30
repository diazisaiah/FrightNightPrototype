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
	_test_gentler_ramp()
	_test_one_power()
	_test_endless_powers()
	_test_endless_falloff()
	_test_true_king_maxed()
	_test_number_stacks()
	_test_skins()
	if _failures.is_empty():
		print("BALANCE REGRESSION: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("BALANCE REGRESSION: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


## Damage numbers stack (2026-10-29): every number on the same spot adds up in
## one label, a repeated callout goes up once, far spots pop on their own.
func _test_number_stacks() -> void:
	var holder := Node3D.new()
	add_child(holder)
	DamagePopup.reset()
	DamagePopup.spawn(holder, "10.0", Color.WHITE, 40, Vector3.ZERO)
	DamagePopup.spawn(holder, "2.5", Color.WHITE, 40, Vector3(0.3, 0, 0))
	DamagePopup.spawn(holder, "ECHO\n1.0", Color.WHITE, 40, Vector3.ZERO)
	DamagePopup.spawn(holder, "ECHO\n1.0", Color.WHITE, 40, Vector3.ZERO)
	DamagePopup.spawn(holder, "5.0", Color.WHITE, 40, Vector3(5, 0, 0))
	DamagePopup.spawn(holder, "+12", Color.GREEN, 40, Vector3.ZERO)
	DamagePopup.spawn(holder, "+12", Color.GREEN, 40, Vector3.ZERO)
	var texts := holder.get_children().map(func(label: Node) -> String: return (label as Label3D).text)
	_check(texts.size() == 4 and "14.5" in texts and "ECHO" in texts and "5.0" in texts and "+12" in texts,
			"Damage numbers stack on the same spot (%s)" % str(texts))
	holder.free()


## The True Coffin King's maxed-build tuning (DeadLeagueBoss.TRUE_MAXED) still
## matches a maxed fighter of each class, within 15%.
func _test_true_king_maxed() -> void:
	for fighter in GameState.CLASSES:
		GameState._reset_fields()
		GameState.player_class = fighter
		GameState.tony_unlocked = true
		GameState.fighters_bought.elementalist = true
		for i in DeadLeagueRules.BOSS_COUNT:
			GameState.dead_league_clears[DeadLeagueRules.boss(i).id] = true
		for id in GameState.UPGRADES:
			GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
		var info: Dictionary = GameState._classes[fighter]
		info.level = 51
		for attribute in Attributes.LIST:
			info.attributes[attribute] = Attributes.MAX
		for id in Cards.deck(fighter):
			info.cards[id] = Cards.copies(Cards.deck(fighter)[id])
		GameState.select_power("sigil_fire")
		var now := PowerRating.maxed_over_true_par()
		var tuned: Vector2 = DeadLeagueBoss.TRUE_MAXED[fighter]
		print("%s maxed over true par: offense x%.2f defense x%.2f (tuned %.2f, %.2f)" % [fighter, now.x, now.y, tuned.x, tuned.y])
		_check(absf(now.x / tuned.x - 1.0) < 0.15 and absf(now.y / tuned.y - 1.0) < 0.15,
				"True Coffin King tuning for %s is stale: maxed is x%.2f / x%.2f, tuned x%.2f / x%.2f" % [fighter, now.x, now.y, tuned.x, tuned.y])
	GameState._reset_fields()


## Endless bouts and floors (2026-10-29): pay stays flat however deep you go;
## monsters grow 7% a wave / floor, 2% more every 5 waves / 2 floors.
func _test_endless_falloff() -> void:
	_check(is_equal_approx(Progression.endless_growth(1, 5), 1.07), "Endless wave 1 to 2: +7%")
	var five_to_six := Progression.endless_growth(5, 5) / Progression.endless_growth(4, 5)
	_check(is_equal_approx(five_to_six, 1.09), "Endless wave 5 to 6: +9%% (%.3f)" % five_to_six)
	var twelve_to_thirteen := Progression.crypt_endless_growth(13) / Progression.crypt_endless_growth(12)
	_check(is_equal_approx(twelve_to_thirteen, 1.09), "Endless floor 12 to 13: +9%% (%.3f)" % twelve_to_thirteen)
	_check(is_equal_approx(Progression.crypt_endless_growth(11, 0.0), 1.0), "Floor 11 starts at floor 10's monsters")
	var world: Node3D = load("res://world.gd").new()
	world._endless = true
	for division in [1, Progression.TIER_COUNT]:
		world._division = division
		world._wave = 0
		var first: Dictionary = world._night_scaling()
		world._wave = 20
		var later: Dictionary = world._night_scaling()
		_check(later.hp >= first.hp * 5.0, "Division %d endless: wave 21 monsters are far tougher (x%.1f HP)" % [division, later.hp / first.hp])
		_check(is_equal_approx(later.reward, first.reward) and is_equal_approx(later.xp, first.xp), "Division %d endless: pay doesn't climb with waves" % division)
	world.free()


## Skins: each belongs to a real fighter, only recolors parts that fighter
## has, is worn only when owned and on its own fighter, saves, and sells in
## the Soul Shop only for fighters you have.
func _test_skins() -> void:
	for id in Skins.CATALOG:
		var fighter: String = Skins.CATALOG[id].fighter
		_check(GameState.CLASSES.has(fighter), "Skin %s belongs to a real fighter" % id)
		for part in Skins.LOOKS.get(id, {}):
			_check(part in ["glow"] or Skins.BASE[fighter].has(part), "Skin %s only changes parts %s has (not %s)" % [id, fighter, part])
	for fighter in Skins.BASE:
		_check(Skins.BASE[fighter].has("shoes") and Skins.BASE[fighter].has("sole") and Skins.BASE[fighter].has("accent"), "%s's palette has shoes" % fighter)
	GameState._reset_fields()
	GameState.player_class = "berserker"
	_check(GameState.skin() == "", "Fighters start in their own look")
	_check(not GameState.equip_skin("berserker", "obsidian_furnace"), "You can't wear a skin you don't own")
	GameState.skins_owned["obsidian_furnace"] = true
	_check(not GameState.equip_skin("counter_master", "obsidian_furnace"), "A skin only goes on its own fighter")
	_check(GameState.equip_skin("berserker", "obsidian_furnace") and GameState.skin() == "obsidian_furnace", "You can wear a skin you own")
	_check(Skins.palette("berserker", "obsidian_furnace").glove != Skins.palette("berserker", "").glove, "A skin changes the palette")
	GameState.save_game()
	GameState.skins_owned = {}
	GameState.skin_picks = {}
	GameState.load_game()
	_check(GameState.skins_owned.has("obsidian_furnace") and GameState.skin("berserker") == "obsidian_furnace", "Skins save")
	SoulShop.restock()
	for offer in GameState.shop_stock:
		if offer.kind == "skin":
			_check(not GameState.skins_owned.has(offer.id), "The shop doesn't sell skins you own")
			_check(Skins.CATALOG[offer.id].fighter in GameState.class_ids(), "The shop only sells skins for fighters you have")
	GameState._reset_fields()


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
		total += GameState.price_at(node, level)
	return total


func _audit_tree(name: String, nodes: Dictionary) -> void:
	var positions := {}
	for id in nodes:
		var node: Dictionary = nodes[id]
		_check(Icons.NAMES.has(node.icon), "%s node %s has no icon named %s" % [name, id, node.icon])
		for required in node.requires:
			_check(nodes.has(required), "%s node %s requires missing node %s" % [name, id, required])
		var position: Vector2 = node.pos
		if node.get("center", false):
			continue  # The Trophies show through the center node.
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
	_check(GameState.UPGRADE_VERSION == 8 and GameState.V7_PRICES.size() > 100 and GameState.V5_PRICES.size() > 50 and GameState.V4_PRICES.size() > 50,
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
			expected += maxi(0, roundi(GameState.V6_PRICES[id][0] * pow(GameState.V6_PRICES[id][1], level)) - GameState.price_at(GameState.UPGRADES[id], level))
	_check(tamed.upgrade_levels.get("dmg_1", 0) == 5 and tamed.upgrade_levels.get("dmg_2", 0) == 3, "Taming prices keeps every bought level")
	_check(expected > 0 and tamed.resources.coins == expected, "Taming prices refunds the difference (%d, expected %d)" % [tamed.resources.coins, expected])
	tamed.free()
	# The center node stands for the Trophies: each seal raises its cap.
	GameState._reset_fields()
	_check(GameState.center_stage() == "wrapped_knuckles" and GameState.center_levels() == Vector2i(0, 1), "The center starts as Taped Up, one level")
	GameState.upgrade_levels["wrapped_knuckles"] = 1
	GameState.dead_league_clears = {"bellman": true}
	_check(GameState.center_stage() == "bellmans_bell" and GameState.center_levels() == Vector2i(1, 4), "Beating the Bellman raises the center's cap (got %s)" % GameState.center_levels())
	_check(GameState.shown_node("upgrade", "wrapped_knuckles") == "bellmans_bell" and GameState.node_state("upgrade", "bellmans_bell") == "available", "The center buys the Bellman's Bell next")
	GameState._reset_fields()
	# Seal rings (v8): round prices; Dirty Shot folds into Lucky Shot.
	for id in GameState.UPGRADES:
		var price := GameState.price_at(GameState.UPGRADES[id], 0)
		_check(price == GameState.nice_price(price), "%s costs a round number (%d)" % [id, price])
	_check(GameState.nice_price(102.0) == 100 and GameState.nice_price(153.0) == 150 and GameState.nice_price(18753.0) == 19000, "Prices round to two figures")
	var merged = load("res://game_state.gd").new()
	merged._reset_fields()
	merged._load_upgrades({"lucky_shot": 3, "dirty_shot": 2})
	_check(merged.upgrade_levels.get("lucky_shot", 0) == 5 and not merged.upgrade_levels.has("dirty_shot"), "Dirty Shot's levels join Lucky Shot")
	merged.free()
	_check(GameState.SKILL_VERSION == 3, "Level-up v3 must turn old levels into card draws and attributes")
	_test_card_migration()

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

	_test_decks()


## Every fighter's deck: 20 cards, 40 copies (5 commons x4, 5 rares x2, 5
## epics, 5 legendaries), an epic for each passive and ultimate, a legendary
## for each seal, effects for every rank, real icons and tags.
func _test_decks() -> void:
	for fighter in GameState.CLASSES:
		var deck := Cards.deck(fighter)
		_check(deck.size() == 20 and Cards.deck_size(fighter) == 40, "%s's deck has 20 cards, 40 copies" % fighter)
		var by_rarity := {}
		var upgrades := []
		var seals := []
		for id in deck:
			var card: Dictionary = deck[id]
			by_rarity[card.rarity] = int(by_rarity.get(card.rarity, 0)) + 1
			_check(Icons.NAMES.has(card.icon), "%s card %s has no icon %s" % [fighter, id, card.icon])
			for tag in card.tags:
				_check(Cards.TAG_COLORS.has(tag), "%s card %s has an unknown tag %s" % [fighter, id, tag])
			var copies := Cards.copies(card)
			for effect in card.effects:
				_check(card.effects[effect].size() == copies, "%s card %s needs a value per rank for %s" % [fighter, id, effect])
				_check(PowerRating.CARDS.has(effect) or PowerRating.EVERY.has(effect) or effect in PowerRating.SPECIALS or effect in ["damage_percent", "knuckles_percent", "move_speed", "spell_time", "crit_chance", "crit_damage"],
						"POWER must rate %s card %s's %s" % [fighter, id, effect])
			if card.text is Array:
				_check(card.text.size() == copies, "%s card %s needs a line per rank" % [fighter, id])
			else:
				_check(card.values.size() == copies, "%s card %s needs a value per rank" % [fighter, id])
			if card.has("upgrades"):
				upgrades.append(card.upgrades)
				_check(not Abilities.info(fighter, card.upgrades).is_empty(), "%s card %s upgrades a real passive or ultimate" % [fighter, id])
			if card.rarity == "legendary":
				seals.append(card.seal)
		_check(by_rarity == {"common": 5, "rare": 5, "epic": 5, "legendary": 5}, "%s's deck has 5 of each rarity: %s" % [fighter, by_rarity])
		_check(upgrades.size() == 5 and Abilities.passives(fighter).size() + Abilities.ultimates(fighter).size() == 5, "%s has an epic for each passive and ultimate" % fighter)
		seals.sort()
		var all := Cards.SEALS.duplicate()
		all.sort()
		_check(seals == all, "%s has a legendary for each seal" % fighter)
		var hand := Cards.typical_hand(fighter, 28, 4)
		var kept := 0
		for id in hand:
			kept += int(hand[id])
			_check(int(hand[id]) <= Cards.copies(deck[id]), "A typical hand never holds more copies than a card has")
		_check(kept == 28, "A typical hand holds every pick (%d)" % kept)


## Old saves: every level gained is a card draw, every stat point an attribute point.
func _test_card_migration() -> void:
	var path := "user://test_save_cards.json"
	var old := {"version": GameState.SAVE_VERSION, "skill_version": 2, "class": "berserker",
		"classes": {"berserker": {"level": 12, "xp": 5, "stat_points": 4, "skill_points": 2,
			"stats": {"damage": 20, "defense": 9, "durability": 0, "looting": 0}, "skills": {"payback": 1}}}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var state = load("res://game_state.gd").new()
	state.save_path = path
	state._reset_fields()
	state.load_game()
	var progress: Dictionary = state._classes.berserker
	_check(progress.level == 12 and progress.draws == 11 and progress.attribute_points == 33,
			"An old level 12 gets 11 draws and 33 attribute points (got %d / %d)" % [progress.draws, progress.attribute_points])
	_check(progress.cards.is_empty() and not progress.has("skills") and not progress.has("stats"), "Old skills and stats are gone")
	_check(state.upgrade_notice.contains("card draws"), "Camp explains the change once")
	var offer: Array = state.card_offer()
	_check(offer.size() == 3, "A waiting draw offers three cards")
	_check(state.take_card(offer[0]) and progress.draws == 10 and state.card_rank(offer[0]) == 1, "Taking a card spends a draw")
	_check(state.spend_attribute("power") and progress.attributes.power == 1 and progress.attribute_points == 32, "Attribute points spend")
	state.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	var visuals := run.get_children().filter(func(child: Node) -> bool: return not child is StaticBody3D)
	_check(visuals.size() == 2, "A fence run should be two batched MultiMeshes")
	_check(run.get_children().any(func(child: Node) -> bool: return child is StaticBody3D), "Fences are solid")
	# Scenery stops you but not monsters, and is too tall to stand on.
	var wall: StaticBody3D = run.get_children().filter(func(child: Node) -> bool: return child is StaticBody3D)[0]
	var player_node: Node = load("res://player.tscn").instantiate()
	var zombie_node: Node = load("res://zombie.tscn").instantiate()
	var player_mask: int = player_node.get("collision_mask")
	var zombie_mask: int = zombie_node.get("collision_mask")
	player_node.free()
	zombie_node.free()
	_check(wall.collision_layer == Scenery.LAYER and player_mask & Scenery.LAYER != 0 and zombie_mask & Scenery.LAYER == 0,
			"Scenery blocks the player, not monsters")
	_check((wall.get_child(0).shape as BoxShape3D).size.y >= Scenery.WALL_HEIGHT, "Scenery walls are too tall to stand on")
	var instances := 0
	for child in visuals:
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
		# The ring's spend, less the Endless powers (optional; par ignores them).
		var ring_cost := 0
		for id in GameState.UPGRADES:
			var root := GameState.power_of(id)
			if root != "" and GameState.UPGRADES[root].has("endless"):
				continue
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
			levels.append([GameState.price_at(node, level), id])
	levels.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var effects := {}
	for i in ceili(levels.size() * share):
		var node_effects: Dictionary = GameState.UPGRADES[levels[i][1]].effects
		for effect in node_effects:
			effects[effect] = effects.get(effect, 0.0) + float(node_effects[effect])
	return Progression.par_build(tier, share)


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
	# A knockout (2026-10-17): gilded finds are kept too; ungilded ones are lost.
	GameState.begin_crypt_run()
	var boots := {"slot": "boots", "rarity": "rare", "name": "Found Boots", "effects": {"move_speed": 0.05}, "floor": 1, "found": true}
	var ring := {"slot": "charm", "rarity": "common", "name": "Found Ring", "effects": {"xp_bonus": 0.1}, "floor": 1, "found": true}
	GameState.equip(boots)
	GameState.equip(ring)
	GameState.gild(boots)
	var saved := GameState.end_crypt_run(false)
	_check(saved.size() == 1 and GameState.equipped.has("boots") and not GameState.equipped.has("charm") and GameState.armory.size() == 3,
			"A knockout keeps gilded finds and loses the rest")
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
	_check(Cards.deck("wise_guy").size() == Cards.deck("berserker").size(), "Tony has a full deck")
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


## Every class at par (its level's attributes and typical cards, par upgrades
## and gear) should rate about even with the contender it faces, and every
## fighter's typical hand should be worth about the same. Runs last: it
## rewrites the build in GameState.
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
		report.set_build(GameState, Progression, class_id, 5, false)
		var without := float(PowerRating.player())
		report.set_build(GameState, Progression, class_id, 5)
		uplifts.append(float(PowerRating.player()) / without)
	_check(uplifts.max() - uplifts.min() < 0.15, "Every fighter's typical hand should be worth about the same: %s" % [uplifts])
	print("Typical hand POWER: %s" % [uplifts.map(func(u: float) -> String: return "x%.2f" % u)])
	GameState.player_class = saved_class


## Emotes: every dance only moves real joints; the emote key is G / View
## (the controller's map tap rides on it); a worn hat must be owned and saves.
func _test_emotes_and_hats() -> void:
	for id in Emotes.ORDER + ["_swing", "_uppercut"]:
		var data := Emotes.raw(id)
		_check(not data.is_empty() and data.has("name"), "%s has its dance file (emotes/%s.json)" % [id, id])
		var keys: Array = data.get("keys", [])
		_check(keys.size() >= 2 or id.begins_with("_"), "%s has a loop of poses" % id)
		for key: Dictionary in keys:
			_check(float(key.t) >= 0.0 and float(key.t) < float(data.length), "%s keys sit inside the dance" % id)
			_check(String(key.get("ease", "smooth")) in Emotes.EASES, "%s eases are real" % id)
			for joint in key.pose:
				_check(joint == "pos" or joint in Emotes.JOINTS or joint in Emotes.HANDS, "%s moves a real joint (not %s)" % [id, joint])
				_check(key.pose[joint].size() == (4 if joint in Emotes.HANDS else 3), "%s %s is x, y, z (and a hand's weight)" % [id, joint])
	# A loop comes back round to its start, and the smooth curve never swings
	# past its keys.
	var floss := Emotes.clip("floss")
	var start: Vector3 = Emotes.sample(floss, 0.0).ls
	_check(start.is_equal_approx(Emotes.sample(floss, floss.length).ls), "A dance loops back to its first pose")
	var top := -INF
	for key: Dictionary in Emotes.raw("floss")["keys"]:
		top = maxf(top, deg_to_rad(float(key.pose.ls[0])))
	var highest := -INF
	for i in 60:
		highest = maxf(highest, Emotes.sample(floss, floss.length * i / 60.0).ls.x)
	_check(highest <= top + 0.001, "The smooth curve stays between its keys")
	var intro := Emotes.parse({"length": 2.0, "loop_start": 1.0, "keys": [{"t": 0, "pose": {"head": [10, 0, 0]}},
			{"t": 1.0, "pose": {"head": [20, 0, 0]}}, {"t": 1.5, "pose": {"head": [40, 0, 0]}}]})
	_check(is_equal_approx(rad_to_deg(Emotes.sample(intro, 3.0).head.x), 20.0), "An intro plays once, then the loop repeats")
	var flipped := Emotes.mirror({"ls": Vector3(1, 0.2, 0.3), "pos": Vector3(0.1, 0, 0)})
	_check(flipped.has("rs") and flipped.rs == Vector3(1, -0.2, -0.3) and flipped.pos == Vector3(-0.1, 0, 0), "mirror() swaps sides")
	var old_bindings = Settings.values.get("bindings", {})
	var old_pad = Settings.values.get("pad_bindings", {})
	Settings.values.bindings = {}
	Settings.values.pad_bindings = {}
	Controls.apply()
	_check(_keys("emote") == [KEY_G], "G emotes")
	_check(_keys("pause") == [KEY_P, KEY_ESCAPE], "P pauses (hints show it), and so does Esc")
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


## Arena bouts and Crypt floors get tougher slower than they pay (2026-10-17),
## and bosses shake off a freeze in half a second.
func _test_gentler_ramp() -> void:
	for division in range(1, Progression.TIER_COUNT + 1):
		_check(is_equal_approx(Progression.arena_difficulty(division, 1), Progression.arena_position(division, 1)), "Bout 1 starts at the last contender's par")
		_check(Progression.arena_difficulty(division, 3) < Progression.arena_position(division, 3) - 0.2, "Bout 3 monsters trail its pay")
	# A run from bracket 1 reaches the Bellman's par only at the end of floor 4
	# (it used to be most of the way to the Headless's by then).
	_check(is_equal_approx(Progression.crypt_difficulty(4, 1), 1.0) and Progression.crypt_difficulty(4, 1) < Progression.crypt_position(4) - 0.5, "Crypt floors climb a quarter tier each")
	_check(is_equal_approx(Progression.crypt_difficulty(3, 3, 0.0), 1.0), "A bracket-2 run starts at the Bellman's par")
	# The endless floors (2026-10-29): pay stops climbing; the monsters build
	# on the top bracket's floor 10 whatever the start, and keep growing.
	var last := Progression.crypt_last_floor()
	_check(is_equal_approx(Progression.crypt_position(last + 10), Progression.crypt_position(last)), "Endless Crypt floors don't pay more than floor 10")
	_check(Progression.crypt_difficulty(last + 1, 1, 0.0) >= Progression.crypt_difficulty(last, Progression.crypt_start_floor(Progression.TIER_COUNT)) - 0.001, "A floor-1 run's endless floors are as tough as a top-bracket run's")
	var floors := Progression.crypt_endless_growth(last + 10) / Progression.crypt_endless_growth(last + 1)
	_check(floors >= 2.5, "Endless Crypt monsters toughen fast (x%.1f floor 11 to 20)" % floors)
	var boss := Enemy.new()
	boss.is_boss = true
	_check(boss.chill_length(5.0) <= Enemy.BOSS_CHILL_TIME, "Bosses shake off a freeze in half a second")
	boss.is_boss = false
	_check(boss.chill_length(5.0) == 5.0, "Other monsters stay frozen as long as Frost says")
	boss.free()


## The Endless powers (2026-10-28): each Sigil opens with its division's
## endless bout, not a Dead League seal; Prism runs four of the eight.
func _test_endless_powers() -> void:
	GameState._reset_fields()
	GameState.dead_league_clears = {"bellman": true, "headless": true, "southpaw": true, "plague_doctor": true, "coffin_king": true}
	for n in 4:
		var root: String = GameState.POWER_ROOTS[4 + n]
		_check(SkillTreeView.BRANCHES.has(root) and GameState.power_of(root) == root, "%s is a power" % root)
		_check(not GameState.node_open("upgrade", root), "%s stays sealed until the endless bout" % root)
		_check(GameState.node_seal_text("upgrade", root).contains("ENDLESS"), "%s says which endless bout" % root)
		GameState.arena_bouts[str(n + 1)] = 3
		_check(GameState.node_open("upgrade", root), "%s opens with division %d's endless bout" % [root, n + 1])
	GameState.player_class = "elementalist"
	GameState.fighters_bought.elementalist = true
	GameState.loadouts["elementalist"] = {"passive": "prism", "ultimate": "elemental_fists"}
	GameState._classes["elementalist"].level = 20
	for root in GameState.POWER_ROOTS:
		GameState.upgrade_levels[root] = 1
	_check(GameState.prism_picks().size() == 4, "Prism runs four powers")
	GameState.select_power("sigil_doom")
	_check("sigil_doom" in GameState.prism_picks() and GameState.prism_picks().size() == 4, "Prism picks a power in, one drops out")
	_check(GameState.power_active("sigil_doom") and not GameState.power_active("dread"), "Prism: base node only")
	GameState._reset_fields()


## Powers work one at a time (2026-10-23): only the selected power's line
## counts, older saves keep their first power, and Select needs it owned.
func _test_one_power() -> void:
	GameState._reset_fields()
	_check(GameState.power_of("sigil_fire") == "sigil_fire" and GameState.power_of("hotter_flames") == "sigil_fire", "Fire's line belongs to Fire")
	_check(GameState.power_of("dmg_1") == "", "Spoke upgrades belong to no power")
	_check(not GameState.select_power("sigil_fire"), "A power you don't own can't be selected")
	GameState.upgrade_levels = {"sigil_fire": 1, "hotter_flames": 3, "sigil_frost": 1, "deep_freeze": 3}
	var fire_only := 0.0
	var frost_only := 0.0
	GameState.select_power("sigil_fire")
	fire_only = GameState.get_effect("burn_damage") + GameState.get_effect("frost_punch")
	_check(GameState.get_effect("frost_punch") == 0.0, "An unselected power does nothing")
	GameState.select_power("sigil_frost")
	frost_only = GameState.get_effect("frost_punch")
	_check(frost_only > 0.0 and GameState.power_active("deep_freeze") and not GameState.power_active("hotter_flames"), "Selecting Frost turns Frost on and Fire off")
	# An old save with two powers and no pick keeps its first one working.
	GameState.save_game()
	var raw := FileAccess.get_file_as_string(GameState.save_path)
	var data: Dictionary = JSON.parse_string(raw)
	data.erase("power_pick")
	var file := FileAccess.open(GameState.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	GameState.load_game()
	_check(GameState.power_pick == "sigil_fire", "Older saves keep their first power selected (got %s)" % GameState.power_pick)
	GameState._reset_fields()
	_check(not Tutorial.seen("hat_first"), "Tips start unseen")
	GameState.mark_tip("hat_first")
	_check(Tutorial.seen("hat_first"), "A tip shows once")
	GameState._reset_fields()
	# Emotes: The Default is free, the rest come from achievements.
	_check(Achievements.emotes() == ["default"], "Only The Default to start (got %s)" % [Achievements.emotes()])
	GameState.add_hat("party_hat")
	_check(Achievements.has("first_hat") and "dab" in Achievements.emotes(), "Your first hat earns Hat Trick and the Dab")
	var taught := {}
	for id in Achievements.LIST:
		var emote: String = Achievements.LIST[id].emote
		if emote == "":
			continue  # True Ending? teaches no dance.
		_check(emote in Emotes.ORDER and not taught.has(emote), "Each achievement teaches its own real dance (%s)" % id)
		taught[emote] = true
	_check(taught.size() + Achievements.FREE_EMOTES.size() == Emotes.ORDER.size(), "Every dance can be earned")
	GameState._reset_fields()
	# The plumber quest: all five plumber caps give Tony's overalls and the jump.
	for cap in Hats.PLUMBER_CAPS.slice(0, 4):
		GameState.add_hat(cap)
	_check(not GameState.skins_owned.has("plumber_overalls"), "Four plumber caps aren't enough")
	GameState.add_hat(Hats.PLUMBER_CAPS[4])
	_check(GameState.skins_owned.has("plumber_overalls") and "plumber_jump" in Achievements.emotes(), "All five plumber caps give the overalls and the Plumber Jump")
	_check(Hats.PLUMBER_CAPS.all(func(cap: String) -> bool: return cap in Hats.TROPHIES), "Plumber caps never drop at random")
	var top := Progression.par(Progression.TIER_COUNT)
	var true_mark := Progression.true_par()
	print("True Coffin King mark: damage %.1f ehp %.0f (Coffin King par: %.1f, %.0f)" % [true_mark.damage, true_mark.ehp, top.damage, top.ehp])
	_check(true_mark.damage > top.damage * 1.2 and true_mark.ehp > top.ehp * 1.2, "The True Coffin King wants far more than the Coffin King's par")
	# No stun-locks, from anything: hammered every frame for 30s with each
	# kind of hold (and all of them mixed), a monster is still free about
	# half the time; a boss's poise keeps it free most of the time.
	for kind in ["stun", "knockdown", "delay", "punch", "mixed"]:
		var held := _held_share("res://zombie.tscn", kind)
		print("held share %s: %.2f" % [kind, held])
		_check(held <= 0.56, "No stun-lock from %s: a monster held %d%% of the time" % [kind, roundi(held * 100.0)])
	var boss_held := _held_share("res://dead_league_boss.tscn", "mixed")
	print("held share boss: %.2f" % boss_held)
	_check(boss_held <= 0.5, "No stun-lock on a boss: held %d%% of the time" % roundi(boss_held * 100.0))
	# Powers have a cooldown on top of their chance.
	var play := PowerPlay.new()
	_check(play.ready("sigil_fire"), "Powers start ready")
	play.spend("sigil_fire")
	play.tick(PowerPlay.COOLDOWNS.sigil_fire - 0.1)
	_check(not play.ready("sigil_fire") and play.ready("sigil_doom"), "A power that went off waits out its own cooldown")
	play.tick(0.2)
	_check(play.ready("sigil_fire"), "Then it's ready again")
	play.free()
	GameState._reset_fields()


## Share of 30 seconds a monster spends held when every frame it's hit with
## kind ("stun", "knockdown", "delay", "punch" or "mixed": all of them).
func _held_share(scene: String, kind: String) -> float:
	var enemy: Enemy = load(scene).instantiate()
	if enemy is DeadLeagueBoss:
		enemy.configure(4, 1)
	add_child(enemy)
	enemy.set_physics_process(false)
	var step := 1.0 / 60.0
	var held := 0.0
	for i in 1800:
		var pick: String = kind if kind != "mixed" else ["stun", "knockdown", "delay", "punch"][i % 4]
		match pick:
			"stun":
				enemy.stun(1.5)
			"knockdown":
				enemy.knock_down(1.3, Vector3.FORWARD)
			"delay":
				enemy.delay(2.0)
			"punch":
				enemy.hp = enemy.max_hp
				enemy.take_hit(0.01, enemy.global_position + Vector3.UP, Vector3.ZERO, true)
		# What _physics_process does each frame.
		enemy._track_control(step)
		if enemy._stagger_timer > 0.0 or enemy._hold_time > 0.0:
			held += step
		enemy._stagger_timer -= step
		enemy._hold_time -= step
		enemy._poise_time -= step
	enemy.queue_free()
	return held / 30.0
