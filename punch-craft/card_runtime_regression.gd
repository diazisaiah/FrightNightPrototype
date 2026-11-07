extends Node
## Live smoke test for the card/attribute combat hooks. Run with:
##   FRIGHT_NIGHT_SAVE=user://test_save.json FRIGHT_NIGHT_SETTINGS=user://test_settings.cfg \
##   godot --headless --path . res://card_runtime_regression.tscn
##
## Every fighter gets a max-rank copy of every card and all fifteen attribute
## perks. The test then runs real Player and Enemy nodes through hits, dodges,
## punches, powers and both ultimates. This complements balance_regression.gd,
## which checks the catalog, migration and POWER math without rendering combat.

const PLAYER_SCENE := preload("res://player.tscn")
const DUMMY_SCENE := preload("res://dummy.tscn")
const TEST_LEVEL := 50
const DUMMY_SPOTS := [
	Vector3(0.0, 0.0, -1.8),
	Vector3(-1.2, 0.0, -2.5),
	Vector3(1.2, 0.0, -2.5),
	Vector3(0.0, 0.0, -3.4),
]

var _failures: Array[String] = []


func _ready() -> void:
	# Never read or write real progression when somebody runs the scene without
	# the environment variables from the command above.
	GameState.save_path = "user://test_save.json"
	Settings.path = "user://test_settings.cfg"
	call_deferred("_run")


func _run() -> void:
	seed(24601)
	Settings.values.slow_motion = 0.0
	for fighter in GameState.CLASSES:
		await _exercise_fighter(fighter)
		for ultimate in Abilities.ultimates(fighter):
			await _exercise_ultimate(fighter, ultimate.id)
	await _test_teleport_walls()
	await _test_head_stomp()
	await _test_dash_punch_cooldowns()
	await _test_combo_setups()
	await _test_shift_rolls()
	await _test_dead_weight()
	await _test_gear_signatures()
	await _test_mimic()
	await _test_tutorial_fights()
	await _test_perch_and_blood()
	await _test_fighter_card_hover()
	await _test_boss_poise()
	await _test_mauler_revamp()
	await _test_cinematic_ult()
	await _test_endless_powers()
	TimeFx.clear()
	GameState._reset_fields()
	# Let the last delayed echo/FX coroutine and status-clear callback release
	# their script references before the process exits. Combat deliberately uses
	# several fire-and-forget timers.
	await get_tree().create_timer(2.0, false, false, true).timeout
	await get_tree().process_frame
	if _failures.is_empty():
		print("CARD RUNTIME REGRESSION: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("CARD RUNTIME REGRESSION: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Maxes the fighter without saving. All four powers are present so Catalyst
## cards can cast and combine them.
func _max_build(fighter: String, ultimate := "") -> void:
	GameState._reset_fields()
	GameState.player_class = fighter
	GameState.tony_unlocked = true
	GameState.fighters_bought.elementalist = true
	GameState.dead_league_clears = {
		"bellman": true, "headless": true, "southpaw": true,
		"plague_doctor": true, "coffin_king": true,
	}
	var progress: Dictionary = GameState._classes[fighter]
	progress.level = TEST_LEVEL
	for attribute in Attributes.LIST:
		progress.attributes[attribute] = Attributes.MAX
	for id in Cards.deck(fighter):
		progress.cards[id] = Cards.copies(Cards.deck(fighter)[id])
	GameState.upgrade_levels = {
		"sigil_fire": 1, "sigil_frost": 1,
		"sigil_storm": 1, "sigil_blood": 1,
		"sigil_quake": 1, "sigil_gale": 1, "sigil_iron": 1, "sigil_doom": 1,
	}
	# Every won hat already owned: their boosts run, and no award popup
	# pauses the test mid-fight.
	for hat in Hats.TROPHIES:
		GameState.hats[hat] = 1
	GameState.power_pick = "sigil_fire"
	GameState.power_pick_2 = "sigil_frost"
	GameState.power_pick_3 = "sigil_storm"
	GameState.loadouts[fighter] = {
		"passive": Abilities.default_passive(fighter),
		"ultimate": ultimate if ultimate != "" else Abilities.default_ultimate(fighter),
	}


## The Endless powers in a real fight, each maxed and selected in turn:
## Quake landings, Gale charges and bursts, Iron plates (and Unbreakable),
## Doom marks running out into a burst.
func _test_endless_powers() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var dummies: Array[Enemy] = rig[2]
	var target := dummies[0]
	for id in GameState.UPGRADES:
		var root := GameState.power_of(id)
		if root in ["sigil_quake", "sigil_gale", "sigil_iron", "sigil_doom"]:
			GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
	for root in ["sigil_quake", "sigil_gale", "sigil_iron", "sigil_doom"]:
		GameState.select_power(root)
		player.powers._forget()
		player.cards._forget()
		player._last_attacker = target
		match root:
			"sigil_quake":
				target._last_damage = 0.0
				_check(player.powers.on_land(1.0), "Quake takes over the landing")
				_check(target._last_damage > 0.0, "Quake's landing shockwave hits")
				player.powers.on_landed()
			"sigil_gale":
				player.powers.gale = 0
				player._on_dodge("slip_left", true)
				_check(player.powers.gale == 3, "A clean dodge with Tailwind gives 3 Gale charges (got %d)" % player.powers.gale)
				player._on_dodge("slip_right", false)
				_check(player.powers.gale == 5, "Deep Lungs holds 5 (got %d)" % player.powers.gale)
				for i in 5:
					player.powers.on_punch_thrown("hook" if i % 2 == 0 else "uppercut", "left", 2.0)
				_check(player.powers.gale == 0, "Every punch spends a charge")
				_check(not holder.find_children("*", "AirBurst", true, false).is_empty() or holder.get_children().any(func(n: Node) -> bool: return n is AirBurst),
						"Punches fire air bursts")
			"sigil_iron":
				player.powers.plates = 0
				for i in 3:
					player._land_punch("jab", "left", false, false, target)
				player._on_dodge("slip_left", true)
				_check(player.powers.plates >= 2, "Punches and a clean dodge forge plates (got %d)" % player.powers.plates)
				player.powers.plates = player.powers.plates_max()
				var cut := player.powers.hit_amount(10.0, target)
				_check(cut < 10.0 and player.powers.plates == player.powers.plates_max() - 1, "Plates cut a hit and one breaks")
				player.powers.plates = player.powers.plates_max()
				player.knuckles = 5.0
				var saved := player.powers.hit_amount(1000.0, target)
				_check(saved <= 4.0, "Unbreakable leaves 1 knuckle HP (got %.1f)" % saved)
			"sigil_doom":
				Powers.doom_mark(target)
				_check(target.is_doomed(), "Doom marks")
				target.take_hit(5.0, target.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false)
				target._last_damage = 0.0
				target._update_statuses(10.0)
				_check(not target.is_doomed() and target._last_damage > 0.0, "The mark runs out in a burst")
	await get_tree().create_timer(0.6, false, false, true).timeout
	await _free_rig(holder)
	print("Card runtime: Endless powers OK")


## Returns [holder, player, dummies]. Dummies are passive and physics is
## paused after their real _ready methods have built the runtime models.
func _make_rig(fighter: String, ultimate := "") -> Array:
	_max_build(fighter, ultimate)
	var holder := Node3D.new()
	holder.name = "CardRuntime_" + fighter
	add_child(holder)
	var player := PLAYER_SCENE.instantiate() as Player
	holder.add_child(player)
	var dummies: Array[Enemy] = []
	for spot in DUMMY_SPOTS:
		var dummy := DUMMY_SCENE.instantiate() as Dummy
		dummy.passive = true
		dummy.setup(player, false)
		dummy.position = spot
		holder.add_child(dummy)
		dummies.append(dummy)
	await get_tree().process_frame
	await get_tree().physics_frame
	player.set_physics_process(false)
	for dummy in dummies:
		dummy.set_physics_process(false)
	return [holder, player, dummies]


func _free_rig(holder: Node) -> void:
	holder.queue_free()
	await get_tree().process_frame
	TimeFx.clear()


## Runs the hooks common to a fighter's whole deck, then repeats the core
## hit/dodge/punch path under each of their three passives.
func _exercise_fighter(fighter: String) -> void:
	var rig := await _make_rig(fighter)
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var dummies: Array[Enemy] = rig[2]
	var target := dummies[0]
	var other := dummies[1]
	_check(player.cards != null and player.ult != null, "%s builds CardPlay and Ult" % fighter)
	for attribute in Attributes.LIST:
		for perk in Attributes.LIST[attribute].perks:
			_check(GameState.perk(perk[0]), "%s has attribute perk %s in the max build" % [fighter, perk[0]])
	for id in Cards.deck(fighter):
		_check(GameState.card_rank(id) == Cards.copies(Cards.deck(fighter)[id]),
				"%s has max rank %s in the runtime build" % [fighter, id])

	# Pure modifiers are still called in combat every frame or punch.
	player.cards.tick(0.1)
	_check(player.cards.speed_mult() > 0.0 and player.cards.move_mult() > 0.0,
			"%s card speed modifiers stay positive" % fighter)
	_check(player.cards.recovery_scale() > 0.0 and player.cards.dash_scale() > 0.0 \
			and player.cards.combo_window_scale() > 0.0 and player.cards.cost_scale() >= 0.0,
			"%s card timing and cost modifiers are valid" % fighter)
	player.cards.on_dash()
	player.cards.dash_contact(target)

	for passive in Abilities.passives(fighter):
		GameState.loadouts[fighter].passive = passive.id
		player.cards._forget()
		player._update_class_timers(0.1)
		# Use the real Player dodge and counter-punch paths.
		player._last_attacker = target
		player._dodged_attack = "arrow"
		player._on_dodge("slip_left", true)
		player._dodged_attack = ""
		player._land_punch("hook", "left", false, false, target)
		# Then a real undefended hit, plus the lower-level card hooks. Tony may
		# wave the real hit off; the direct hooks still cover his hit cards.
		player.receive_attack(2.0, target.global_position, "jab", target)
		player.cards.hit_amount(2.0, target)
		player.cards.on_hit(target)
		player.cards.on_knuckles()

	# Long combo/counter coverage without waiting through punch animations.
	for i in 55:
		player._set_combo(i + 1)
		player._combo_grew = true
		var counter := i % 5 == 0
		var punch_type := "hook" if i % 4 == 3 else "jab"
		var airborne := i % 7 == 0
		var set_up := punch_type == "hook"
		var at := target.global_position + Vector3(0, 1.3, 0)
		var mod: Dictionary = player.cards.punch_mod(target, punch_type, counter, airborne, set_up, at, false)
		_check(mod.has("mult") and mod.has("stagger") and mod.has("push"),
				"%s returns a complete punch modifier" % fighter)
		var dealt := target.take_hit(0.1, at, Vector3.ZERO, bool(mod.stagger))
		player.cards.after_punch(target, punch_type, "left" if i % 2 == 0 else "right",
				0.1, dealt, counter, false, airborne, set_up, false)
		player.ult.on_landed(target, dealt, "left" if i % 2 == 0 else "right")

	# A knockout exercises Follow Through and every fighter's on-kill cards.
	other.taunt(4.0)
	other.hp = 1.0
	var kill_at := other.global_position + Vector3(0, 1.3, 0)
	var kill_mod := player.cards.punch_mod(other, "hook", true, false, true, kill_at, false)
	var kill_damage := 20.0 * float(kill_mod.mult)
	var kill_dealt := other.take_hit(kill_damage, kill_at, Vector3.ZERO, true)
	player.cards.after_punch(other, "hook", "right", kill_damage, kill_dealt, true,
			other.is_dead(), false, true, false)
	_check(other.is_dead(), "%s runtime knockout path completes" % fighter)

	# Power listeners are harmless for non-Catalysts and drive the Catalyst's
	# Ward, Resonance, Twin Cast, Spectrum and Grand Unification cards.
	for i in 20:
		var power_target := dummies[2 if i % 2 == 0 else 3]
		if i % 3 == 0:
			Powers.fire_burst(power_target, 0.2)
		elif i % 3 == 1:
			Powers.frost_burst(power_target, 0.1)
		else:
			Powers.chain_lightning(power_target, 0.2, 2)
	# Flurry and the two-hit Afterimage are deliberately asynchronous; let the
	# longest of them finish before their target rig is freed.
	await get_tree().create_timer(0.8, false, false, true).timeout
	await _free_rig(holder)
	print("Card runtime: %s combat hooks OK" % fighter)


## Fires through Ult.activate so the dispatch and that fighter's epic ultimate
## card run together. Each ultimate gets a fresh rig because several remain in
## a timed stance after activation.
func _exercise_ultimate(fighter: String, ultimate: String) -> void:
	var rig := await _make_rig(fighter, ultimate)
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	player.ult.fill()
	player.ult.activate()
	# Inferno II performs two leap tweens and Highlight Reel visits every live
	# target. Freeing their Player mid-await strands the coroutine, so those two
	# get time to finish; the other ultimates start synchronously.
	var settle := 2.5 if ultimate in ["inferno", "highlight_reel"] else (0.8 if ultimate == "flame_burst" else 0.25)
	await get_tree().create_timer(settle, false, false, true).timeout
	_check(player.ult.meter < Ult.MAX_METER,
			"%s's %s activates and spends meter" % [fighter, ultimate])
	# While it lasts, nothing charges the meter (Brimstone Shield could stay up forever).
	if ultimate in ["bulwark", "hype_train", "unbroken", "riposte", "flow_state", "elemental_fists"]:
		var before: float = player.ult.meter
		player.ult.add(50.0)
		_check(is_equal_approx(player.ult.meter, before), "%s's %s doesn't charge while it's up" % [fighter, ultimate])
	if ultimate == "temporal_break":
		_check_time_stop(player)
	if ultimate == "flame_burst":
		# A boss in the blast is stunned, even holding its poise.
		var boss: Enemy = load("res://dead_league_boss.tscn").instantiate()
		boss.configure(4, 1)
		boss.setup(player, false)
		boss.position = player.global_position + Vector3(0, 0, -3)
		holder.add_child(boss)
		await get_tree().process_frame
		boss._set_poise()
		player.ult._burst_ring()
		_check(boss.is_staggered(), "Flame Burst stuns a boss through its poise")
		boss.queue_free()
	if ultimate == "unbroken":
		# Nothing drops the combo while it lasts: not a real hit, not a
		# slipped punch or a shield (their _set_combo(0)).
		player.invulnerable = false
		player._set_combo(6)
		player.receive_attack(2.0, player.global_position + Vector3(0, 0, -1.5), "jab", null)
		player._set_combo(0)
		_check(player.combo == 6, "Unbroken: the combo doesn't drop (%d, was 6)" % player.combo)
		player.unbroken_time = 0.0
		player._set_combo(0)
		_check(player.combo == 0, "Unbroken: once it ends, the combo can drop")
	if ultimate == "the_family":
		# Stacked on one spot inside a dummy, they step apart and out, and stay
		# that way round it.
		var goons := get_tree().get_nodes_in_group("goons")
		var dummies: Array[Enemy] = rig[2]
		var dummy := dummies[0]
		for goon: Node3D in goons:
			goon.global_position = dummy.global_position + Vector3(0.05, 0, 0)
		await get_tree().create_timer(1.5, false, false, true).timeout
		var inside := 0
		for goon: Node3D in goons:
			for enemy: Enemy in dummies:
				if Vector2(goon.global_position.x - enemy.global_position.x, goon.global_position.z - enemy.global_position.z).length() < enemy.body_radius() + Goon.BODY * 0.8:
					inside += 1
		_check(inside == 0, "The Family's goons stay out of monsters (%d inside)" % inside)
		var closest := INF
		for a in goons:
			for b in goons:
				if a != b:
					closest = minf(closest, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
		_check(goons.size() >= 3 and closest > Goon.SPACING * 0.8, "The Family's goons keep apart (%d goons, closest %.2fm)" % [goons.size(), closest])
	await _free_rig(holder)
	print("Card runtime: %s / %s OK" % [fighter, ultimate])


## Temporal Break holds every punch's damage until time resumes, then lands
## it all at once (a monster that died mid-stop died frozen, and a Dead
## League boss lingered into the next round); the other hand buys time back,
## the same hand doesn't. Diminishing returns: mashing can't keep it running,
## and one soon after the last is shorter.
func _check_time_stop(player: Player) -> void:
	var ult := player.ult
	var full := ult._time_full
	ult._time_left = full - 1.5  # Some time gone, to buy back.
	var target := ult._stop_target()
	_check(target != null, "Temporal Break: a punch finds a frozen monster in reach")
	if target == null:
		return
	# Dummies refill; what they last took shows whether a hit landed.
	target.set("_last_damage", 0.0)
	ult._stop_punch("left", "jab")
	var left := ult._time_left
	ult._punch_wait = 0.0
	ult._stop_punch("left", "jab")
	_check(is_equal_approx(ult._time_left, left), "Temporal Break: the same hand twice buys no time")
	ult._punch_wait = 0.0
	ult._stop_punch("right", "cross")
	_check(ult._time_left > left, "Temporal Break: the other hand buys time back")
	_check(float(target.get("_last_damage")) == 0.0, "Temporal Break: no damage lands while time is stopped")
	ult._time_left = 1.0
	for i in 60:
		ult._punch_wait = 0.0
		ult._stop_punch("left" if i % 2 == 0 else "right", "jab")
	_check(ult._time_left < 2.4, "Temporal Break: endless alternating buys little time (%.2fs left)" % ult._time_left)
	ult._time_left = full
	ult._punch_wait = 0.0
	ult._stop_punch(ult._next_hand(), "jab")
	_check(ult._time_left <= full, "Temporal Break: buying time never passes where the clock started")
	ult._time_left = 0.0
	ult._update_time_stop(0.0)
	_check(ult.mode == "" and float(target.get("_last_damage")) > 0.0, "Temporal Break: the held damage lands when time resumes")
	ult.fill()
	ult._start_time_stop()
	_check(ult.mode == "time_stop" and ult._time_full < full * 0.8, "Temporal Break: one right after the last is shorter (%.1fs, was %.1fs)" % [ult._time_full, full])
	ult._time_left = 0.0
	ult._update_time_stop(0.0)


## Phantom Step and Vault jump behind a monster: never through a wall (the
## training ring's ropes, a Crypt room's walls).
func _test_teleport_walls() -> void:
	var rig := await _make_rig("counter_master")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var dummies: Array[Enemy] = rig[2]
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 3.0, 0.2)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, -4.0)
	holder.add_child(wall)
	player.global_position = Vector3.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	var near_wall := dummies[3]  # 0.6m in front of the wall.
	_check(player.teleport_spot(near_wall, Vector3(0, 0, -4.7)) == Vector3.INF,
			"No room behind a monster against a wall: Phantom Step stays put")
	var roomy := dummies[0]
	var spot := player.teleport_spot(roomy, Vector3(0, 0, -4.7))
	_check(spot != Vector3.INF and spot.z > -4.0, "Phantom Step stops short of a wall (got %s)" % spot)
	var open := player.teleport_spot(roomy, Vector3(0, 0, -3.1))
	_check(open.is_equal_approx(Vector3(0, 0, -3.1)), "With room behind, Phantom Step lands where it means to")
	await _free_rig(holder)
	print("Card runtime: teleports stay inside walls OK")


## Head Stomp: the Stray's jump reaches a monster's head, and coming down by
## it stomps it (a bounce, a stun, damage).
func _test_head_stomp() -> void:
	var rig := await _make_rig("free_runner")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var dummies: Array[Enemy] = rig[2]
	GameState.loadouts.free_runner.passive = "head_stomp"
	var target := dummies[0]
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var peak := pow(Player.JUMP_VELOCITY * player._stomp_jump(), 2.0) / (2.0 * gravity)
	_check(peak >= target.top_height() + Player.STOMP_BAND.x + 0.2,
			"The Stray's jump (%.2fm) reaches a head (%.2fm)" % [peak, target.top_height()])
	player.global_position = target.global_position + Vector3(0.3, target.top_height() + 0.1, 0)
	player.velocity = Vector3(0, -2.0, 0)
	player._stomp_cooldown = 0.0
	player._check_head_stomp()
	# (The training dummy never loses HP: the stun and the bounce show it.)
	_check(target.is_staggered() and player.velocity.y > 0.0, "Coming down by a head stomps it")
	await _free_rig(holder)
	print("Card runtime: head stomp OK")


## The Stray's dash punches: a Spear Jab and a Haymaker each have a cooldown
## (a dash punch on cooldown is a plain punch), and the Spear Jab's reach is
## short enough not to spear from across the yard (2026-10-29).
func _test_dash_punch_cooldowns() -> void:
	var rig := await _make_rig("free_runner")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	GameState.loadouts.free_runner.passive = "dash_punches"
	# (The max build holds Spear Line: 50% farther. It used to double 5m.)
	_check(player._spear_reach() <= 6.0, "Spear Jab reach is short (%.1fm)" % player._spear_reach())
	for type in ["jab", "cross"]:
		player._dash_jab_time = Player.DASH_PUNCH_WINDOW
		var style: String = player._dash_punch_style(type, false)
		var cooldown: float = player._spear_cooldown if type == "jab" else player._haymaker_cooldown
		_check(style != "" and cooldown > 0.0, "A dash %s is a dash punch and starts its cooldown" % type)
		player._dash_jab_time = Player.DASH_PUNCH_WINDOW
		_check(player._dash_punch_style(type, false) == "", "On cooldown, a dash %s is a plain punch" % type)
	_check(player._haymaker_cooldown > player._spear_cooldown, "The Haymaker's cooldown is the longer")
	player._spear_cooldown = 0.0
	player._dash_jab_time = Player.DASH_PUNCH_WINDOW
	_check(player._dash_punch_style("jab", false) == "spear", "Once it's back, a dash jab spears again")
	await _free_rig(holder)
	print("Card runtime: dash punch cooldowns OK")


## Set-ups (2026-10-30): real boxing combos aren't SLOPPY. Each sequence is
## [move, hand] steps ("slip_right", "roll_left" for head movement); every
## hook and uppercut in it must come out set up, and the combo must survive.
func _test_combo_setups() -> void:
	var rig := await _make_rig("counter_master")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = (rig[2] as Array)[0]
	target.max_hp = 1e9
	target.hp = 1e9
	# Each entry is [steps, the combo after them] (2026-11-02, see
	# Player.combo_move): "dodge_x" is a slip or roll that worked, "x" a missed one.
	var combos := [
		[[["jab", "left"], ["hook", "right"], ["uppercut", "left"], ["hook", "right"]], 4],  # mixing kinds grows it
		[[["jab", "left"], ["cross", "right"]], 2],  # jab, cross grows
		[[["jab", "left"], ["cross", "right"], ["jab", "left"]], 2],  # the jab after that holds
		[[["jab", "left"], ["cross", "right"], ["jab", "left"], ["cross", "right"]], 2],  # and keeps holding
		[[["jab", "left"], ["cross", "right"], ["hook", "left"]], 3],  # a new kind grows again
		[[["jab", "left"], ["hook", "right"], ["hook", "left"]], 3],  # left hook, right hook grows
		[[["jab", "left"], ["hook", "right"], ["hook", "left"], ["hook", "right"]], 3],  # the next hook holds
		[[["jab", "left"], ["hook", "right"], ["uppercut", "left"], ["uppercut", "right"], ["uppercut", "left"]], 4],  # same for uppercuts
		[[["jab", "left"], ["jab", "left"]], 2],  # the double jab grows
		[[["jab", "left"], ["jab", "left"], ["jab", "left"]], 2],  # a third jab holds
		[[["jab", "left"], ["jab", "left"], ["jab", "left"], ["jab", "left"]], 1],  # a fourth loses it
		[[["jab", "left"], ["hook", "left"]], 1],  # the same hand again loses it
		[[["jab", "left"], ["uppercut", "right"], ["uppercut", "right"]], 1],  # even a set-up uppercut
		[[["jab", "left"], ["dodge_slip_right", ""], ["hook", "left"]], 2],  # a worked dodge lets the same hand go on
		[[["jab", "left"], ["slip_right", ""], ["hook", "left"]], 1],  # a missed one doesn't
		[[["jab", "left"], ["cross", "right"], ["dodge_slip_left", ""], ["jab", "left"]], 3],  # a counter always grows it (it would hold)
		[[["slip_left", ""], ["hook", "left"]], 1],
	]
	for entry in combos:
		var combo: Array = entry[0]
		player._set_combo(0)
		player._defense_cooldown = 0.0
		player._dodged_at = -10.0
		player._clear_counter()
		for step in combo:
			if step[1] == "":
				player._defense_cooldown = 0.0
				if step[0].begins_with("dodge_"):
					player._on_dodge(step[0].trim_prefix("dodge_"))
				else:
					player._try_defense(step[0])
				continue
			player._land_punch(step[0], step[1], false, false, target)
			if Player.PUNCHES[step[0]].heavy:
				_check(player._last_set_up, "%s %s is set up in %s" % [step[1], step[0], combo])
		_check(player.combo == int(entry[1]), "The combo after %s is %d (was %d)" % [combo, int(entry[1]), player.combo])
	# A new enemy: its first punch holds the combo even with the same hand.
	_check(Player.combo_move("jab", "left", "jab", "left", 1, 1, true, false, false) == "grow", "The first punch on a new enemy grows the combo")
	# A worked dodge also keeps the combo timer going.
	player._set_combo(3)
	player._combo_timer = 0.1
	player._on_dodge("roll_left")
	_check(player._combo_timer >= GameState.get_combo_window() * player.cards.combo_window_scale() - 0.01, "A worked roll refreshes the combo timer")
	# Still SLOPPY: a hook thrown cold, and an uppercut after a cold hook.
	player._set_combo(0)
	player._land_punch("hook", "left", false, false, target)
	_check(not player._last_set_up, "A hook thrown cold isn't set up")
	player._land_punch("uppercut", "right", false, false, target)
	_check(not player._last_set_up, "An uppercut after a cold hook isn't set up")
	await _free_rig(holder)
	print("Card runtime: combo set-ups OK")


## The Shift + Q / E scheme (2026-10-30): Shift + Q / E are the roll actions
## (and still the slip keys under them, so the player must roll, not slip),
## Q alone only slips, S double-tapped back steps.
func _test_shift_rolls() -> void:
	var old_assist = Settings.values.assist_mode
	var old_dodge = Settings.values.dodge_mode
	var old_bindings = Settings.values.get("bindings", {})
	# (Your own key bindings would replace the scheme's keys.)
	Settings.values.bindings = {}
	Settings.values.assist_mode = "pro"
	Settings.values.dodge_mode = "shift_qe"
	Controls.apply()
	_check(InputMap.event_is_action(_key(KEY_Q, true), "roll_left_key") and InputMap.event_is_action(_key(KEY_E, true), "roll_right_key"),
			"Shift + Q / E are the roll keys")
	_check(not InputMap.event_is_action(_key(KEY_Q, false), "roll_left_key") and InputMap.event_is_action(_key(KEY_Q, false), "slip_left"),
			"Q alone only slips")
	var rig := await _make_rig("counter_master")
	var player: Player = rig[1]
	var was_pad := Pad.active
	# (Input only counts with the mouse captured or a controller in use.)
	Pad.active = true
	# What each press sets off: Shift + Q is both slip_left and roll_left_key.
	# Shift + S (2026-11-02) is both move_back and back_step_key.
	for case in [[["slip_left", "roll_left_key"], "roll_left"], [["slip_right", "roll_right_key"], "roll_right"],
			[["slip_left"], "slip_left"], [["move_back"], ""], [["move_back"], "back_step"],
			[["move_back", "back_step_key"], "back_step"]]:
		if case[1] != "":
			player._defense = ""
			player._defense_cooldown = 0.0
		for action: String in case[0]:
			Input.action_press(action)
		await get_tree().process_frame
		if "back_step_key" in case[0]:
			_check(player._suppressed_move == "move_back", "Shift + S doesn't walk you back (%s)" % player._suppressed_move)
		for action: String in case[0]:
			Input.action_release(action)
		await get_tree().process_frame
		if case[1] != "":
			_check(player._defense == case[1], "%s does %s (did %s)" % [case[0], case[1], player._defense])
	# Controller heavies: hold LT / RT with jab or cross picks the hand.
	for case in [[[], "left", "jab"], [["punch_hook"], "left", "hook"], [["punch_hook"], "right", "hook"],
			[["punch_uppercut"], "right", "uppercut"], [["sprint"], "left", "jab"]]:
		for action: String in case[0]:
			Input.action_press(action)
		_check(player._punch_type_for(case[1]) == case[2], "Controller: %s + %s is a %s (was %s)" % [case[0], case[1], case[2], player._punch_type_for(case[1])])
		for action: String in case[0]:
			Input.action_release(action)
	# Mashing both hands alternates: with both buffered, the other hand from
	# the last punch goes first.
	player._last_punch_hand = "left"
	player._buffered = {"left": ["jab", 0.2], "right": ["cross", 0.2]}
	player._cooldown = 0.0
	player._flinch_timer = 0.0
	await get_tree().process_frame
	_check(player._last_punch_hand == "right" and player._buffered.has("left"), "Both hands buffered: the cross goes after a jab (last %s)" % player._last_punch_hand)
	player._buffered.clear()
	Pad.active = was_pad
	Settings.values.assist_mode = old_assist
	Settings.values.dodge_mode = old_dodge
	Settings.values.bindings = old_bindings
	Controls.apply()
	await _free_rig(rig[0])
	print("Card runtime: Shift + Q / E rolls OK")


func _key(key: Key, shift: bool) -> InputEventKey:
	# (As the OS sends it: the key's letter and its physical place.)
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.shift_pressed = shift
	event.pressed = true
	return event


## Dead Weight (2026-10-29): a Doom-marked monster deals 25 / 30 / 35% less
## and glows faint purple; it isn't chilled (that froze bosses white).
func _test_dead_weight() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = rig[2][0]
	_check(is_zero_approx(Powers.dead_weight()), "No Dead Weight, no softening")
	GameState.upgrade_levels.dead_weight = 2
	GameState.select_power("sigil_doom")
	# No Granite Chin halving the second hit.
	for attribute in Attributes.LIST:
		GameState._classes.berserker.attributes[attribute] = 0
	_check(is_equal_approx(Powers.dead_weight(), 0.3), "Dead Weight level 2: 30% less")
	player.invulnerable = false
	player.active = true
	var hits := []
	for marked in [false, true]:
		if marked:
			target.doom(3.0)
		player.knuckles = player.max_knuckles
		player.receive_attack(10.0, target.global_position, "jab", target)
		hits.append(player.max_knuckles - player.knuckles)
	_check(hits[0] > 0.0 and hits[1] < hits[0] * 0.85, "A marked monster hits softer (%.2f vs %.2f)" % [hits[1], hits[0]])
	_check(target._chill_time <= 0.0, "Dead Weight doesn't chill")
	target._flashing = false
	target._refresh_overlay()
	_check(target._meshes[0].material_overlay == Enemy._weakened_overlay, "A weakened monster glows faint purple")
	target._clear_doom()
	_check(target._meshes[0].material_overlay != Enemy._weakened_overlay, "The glow goes with the mark")
	await _free_rig(holder)
	print("Card runtime: Dead Weight OK")


## Gear signatures (2026-11-04, the gear system): Slipknot turns a graze into
## a plain dodge, Gravewalker cuts damage after a dodge (inside the 75% cap),
## Bone Breaker's hook counters ignore half the armor, Rhythm shows apart on
## the combo line and The Long Count comes back every Arena bout.
func _test_gear_signatures() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = (rig[2] as Array)[0]
	# A plain fighter: no cards or attributes slipping, blocking or halving hits.
	var info: Dictionary = GameState._classes.berserker
	info.cards = {}
	for attribute in Attributes.LIST:
		info.attributes[attribute] = 0
	player.invulnerable = false
	player.active = true
	var wear := func(effects: Dictionary) -> void:
		GameState.equipped = {"charm": {"slot": "charm", "rarity": "legendary", "name": "Test Charm", "effects": effects, "uid": 9001}}
	var defend := func(move: String) -> void:
		player._defense_cooldown = 0.0
		player._defense = move
		player._defense_window = 0.3
		player._defense_timer = 0.3
	# Slipknot: a wrong slip grazes, unless the wraps turn it into a plain dodge.
	wear.call({})
	player.knuckles = player.max_knuckles
	defend.call("slip_left")
	_check(player.receive_attack(10.0, target.global_position, "jab", target) == "grazed", "A wrong slip grazes")
	wear.call({"slipknot": 1.0, "gravewalker": 0.25, "rhythm": 0.15})
	player._clear_counter()
	player._rhythm = 0.0
	player._gravewalk_time = 0.0
	player.knuckles = player.max_knuckles
	defend.call("slip_left")
	_check(player.receive_attack(10.0, target.global_position, "jab", target) == "dodged" and player.knuckles == player.max_knuckles
			and player.is_counter_ready(), "Slipknot: the graze counts as a dodge, with a counter")
	_check(player._rhythm == 0.0 and player._gravewalk_time <= 0.0, "A Slipknot dodge gives no Rhythm or Gravewalker")
	# Gravewalker: a real dodge cuts the next hits.
	wear.call({"gravewalker": 0.25})
	player._gravewalk_time = 0.0
	player.knuckles = player.max_knuckles
	player.hurt_knuckles(40.0)
	var plain := player.max_knuckles - player.knuckles
	defend.call("slip_right")
	_check(player.receive_attack(10.0, target.global_position, "jab", target) == "dodged" and player._gravewalk_time > 0.0,
			"Gravewalker: a dodge starts the cut")
	player.knuckles = player.max_knuckles
	player.hurt_knuckles(40.0)
	var walked := player.max_knuckles - player.knuckles
	_check(walked > 0.0 and walked < plain * 0.8, "Gravewalker: 25%% less right after a dodge (%.2f vs %.2f)" % [walked, plain])
	wear.call({"gravewalker": 0.5, "set_damage_reduction": 0.5})
	player.knuckles = player.max_knuckles
	player.hurt_knuckles(40.0)
	# The Mauler's perk (x0.9) comes after the cap.
	_check(is_equal_approx(player.max_knuckles - player.knuckles, maxf(1.0, GameState.mitigate(40.0) * 0.25 * GameState.get_class_mod("final_damage"))),
			"Damage cuts stop at 75%%, after armor, then the Mauler's 10%% (%.2f taken)" % (player.max_knuckles - player.knuckles))
	player._gravewalk_time = 0.0
	# Bone Breaker: hook counters ignore half the armor; other hooks don't.
	wear.call({})
	target.max_hp = 1e9
	target.armor = 0.0
	# (The dummy keeps its HP and remembers the last hit.)
	var hook := func(counter: bool) -> float:
		(target as Dummy)._last_damage = 0.0
		player._set_combo(0)
		player._clear_counter()
		if counter:
			player._ready_counter("any")
		player._land_punch("hook", "left", false, false, target)
		return (target as Dummy)._last_damage
	var raw: float = hook.call(true)
	target.armor = raw * 0.8
	var blocked: float = hook.call(true)
	wear.call({"bone_breaker": 0.5})
	var broken: float = hook.call(true)
	var cold: float = hook.call(false)
	_check(raw > 0.0 and broken > blocked * 2.0, "Bone Breaker: a hook counter ignores half the armor (%.1f vs %.1f)" % [broken, blocked])
	_check(cold < broken * 0.6, "Bone Breaker: a hook that isn't a counter doesn't (%.1f)" % cold)
	target.armor = 0.0
	# Rhythm: its share of the multiplier, shown apart, under the cap.
	player._set_combo(3)
	player._rhythm = 0.3
	_check(is_equal_approx(player.rhythm_part(), 0.3) and is_equal_approx(player.get_combo_multiplier(), player._base_combo_multiplier() + 0.3),
			"Rhythm adds its share on top of the combo")
	player._set_combo(400)
	_check(is_zero_approx(player.rhythm_part()), "Rhythm adds nothing at the combo cap")
	player._set_combo(0)
	player._rhythm = 0.0
	# The Long Count: ready again for every Arena bout.
	player._long_count_ready = false
	player.start_fresh()
	_check(player._long_count_ready, "The Long Count is ready again each Arena bout")
	GameState.equipped = {}
	await _free_rig(holder)
	print("Card runtime: gear signatures OK")


## Mimics (Crypt revamp, 2026-11-04): shut, nothing gets through; its
## tongue throws a boxer's punches with the same tells; open, it can be hit;
## an elite one (a cursed chest you challenged) is a champion.
func _test_mimic() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var mimic := (load("res://mimic.tscn") as PackedScene).instantiate() as Mimic
	mimic.setup(player, false)
	mimic.position = Vector3(0, 0, -2.0)
	holder.add_child(mimic)
	await get_tree().process_frame
	mimic.set_physics_process(false)
	_check(mimic.is_shut() and mimic.blocks_punch("cross", false) and mimic.block_caption() == "SHUT TIGHT", "A shut mimic blocks punches")
	_check(mimic.take_hit(50.0, mimic.global_position + Vector3.UP, Vector3.ZERO, false) == 0.0, "Nothing gets through a shut mimic")
	mimic._begin_attack("left_hook", Boxer.FIRST_WINDUP["left_hook"])
	_check(not mimic.is_shut() and mimic.incoming_attack() == "left_hook" and mimic.attack_eta() > Enemy.tell_time(),
			"An open mimic throws a boxer's punch, with time to read it")
	var before := mimic.hp
	mimic.take_hit(30.0, mimic.global_position + Vector3.UP, Vector3.ZERO, false)
	_check(mimic.hp < before, "An open mimic can be hit")
	mimic.make_elite_mimic()
	_check(mimic.elite and mimic.has_meta("elite_mimic") and mimic.has_meta("champion"), "An elite mimic is a champion")
	await _free_rig(holder)
	print("Card runtime: mimic OK")


## The tutorial (2026-10-29): your mode's dodge steps, and its last three
## steps are real fights where monsters go down in 6 punches (a counter
## counts 1.5) and you in 6 of their hits.
func _test_tutorial_fights() -> void:
	GameState._reset_fields()
	GameState.player_class = "berserker"
	GameState.tutorial_done = false
	var mode: String = Settings.get_value("assist_mode")
	for junior in [true, false]:
		Settings.values["assist_mode"] = "junior" if junior else "pro"
		var titles: Array = Training.plan().map(func(step: Dictionary) -> String: return step.title)
		_check(("DODGE" in titles) == junior and ("ROLL" in titles) != junior, "The tutorial teaches dodging the %s way" % ("junior" if junior else "pro"))
	Settings.values["assist_mode"] = mode
	var training: Training = load("res://training.tscn").instantiate()
	add_child(training)
	await get_tree().process_frame
	var plan: Array = training._plan
	var first_fight := -1
	for i in plan.size():
		if plan[i].has("fight") and first_fight < 0:
			first_fight = i
	_check(first_fight >= 0 and plan.size() - first_fight == 3, "The tutorial ends in three fights")
	training._start_step(first_fight)
	await get_tree().process_frame
	_check(training._fighters.size() == 2 and training._fighters.all(func(enemy: Enemy) -> bool: return enemy is Zombie), "Fight 1: two zombies")
	_check(not training._dummy.visible and not training._ring.visible, "The dummy and the ring step out for the fights")
	var zombie: Enemy = training._fighters[0]
	for i in Training.FIGHT_HITS - 1:
		zombie.take_hit(0.01, zombie.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false)
	_check(not zombie.is_dead(), "Five punches don't drop it")
	zombie.take_hit(0.01, zombie.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false)
	_check(zombie.is_dead(), "The sixth does, whatever it hit for")
	var other: Enemy = training._fighters[1]
	for i in 3:
		other.take_hit(0.01, other.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false, "COUNTER!")
	_check(not other.is_dead(), "Three counters (4.5 punches) don't")
	other.take_hit(0.01, other.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false, "COUNTER!")
	_check(other.is_dead(), "Four counters (6 punches) do")
	var player: Player = training._player
	_check(is_equal_approx(player.fixed_hit, player.max_knuckles / Training.FIGHT_HITS), "You go down in six hits")
	training._start_step(first_fight + 1)
	await get_tree().process_frame
	_check(training._fighters.size() == 1 and training._fighters[0] is Skeleton, "Fight 2: a skeleton")
	# Rolling under an arrow counts as a slip for this step (2026-11-02).
	var pro_mode: String = Settings.get_value("assist_mode")
	training._player._dodged_attack = "arrow"
	training._on_dodged("roll_left")
	training._player._dodged_attack = ""
	_check(training._progress.get("slip", 0.0) == 1.0, "A roll under an arrow counts as a slip (%s)" % str(training._progress.get("slip", 0.0)))
	# Knocking the skeleton out before the slips doesn't strand the step: another one comes in.
	var skeleton: Enemy = training._fighters[0]
	for i in Training.FIGHT_HITS:
		skeleton.take_hit(0.01, skeleton.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false)
	_check(skeleton.is_dead() and not training._step_done, "The skeleton falls before the second slip: the step isn't done")
	await get_tree().create_timer(1.4, false).timeout
	_check(training._fighters.size() == 1 and not training._fighters[0].is_dead() and training._fighters[0] != skeleton,
			"Another skeleton comes in so the slips can be finished")
	Settings.values["assist_mode"] = pro_mode
	_check(Player.PUNCHES.jab.impact == Player.PUNCHES.cross.impact and Player.PUNCHES.jab.cooldown == Player.PUNCHES.cross.cooldown,
			"Jab and cross have the same windup and cooldown")
	training._start_step(first_fight + 2)
	await get_tree().process_frame
	_check(training._fighters.size() == 1 and training._fighters[0] is Brawler, "Fight 3: a brawler")
	# Finishing it pays nothing (2026-11-05: camp spares the change after your
	# first Arena fight instead).
	var coins: int = GameState.resources.get("coins", 0)
	training._complete_step()
	await get_tree().create_timer(Training.STEP_PAUSE + 0.3, false).timeout
	_check(GameState.tutorial_done and GameState.resources.get("coins", 0) == coins, "Finishing the tutorial pays nothing")
	_check(training._fighters.is_empty() and training._dummy.visible and training._ring.visible and player.fixed_hit == 0.0, "Leaving the fights brings the dummy and the ring back")
	training._start_step(training._plan.size() - 1)
	training._complete_step()
	await get_tree().create_timer(Training.STEP_PAUSE + 0.3, false).timeout
	_check(GameState.resources.get("coins", 0) == coins, "Finishing it again pays nothing")
	training.queue_free()
	await get_tree().process_frame
	print("Card runtime: tutorial fights OK")


## 2026-10-29: standing on a prop gets you shoved off after Player.PERCH_TIME;
## kill heals only come from monsters your punch put down; Fire and Blood
## proc at most every 3s / 4s.
func _test_perch_and_blood() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = rig[2][0]
	# A crate with the player standing on it (real physics for once).
	var ground := StaticBody3D.new()
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(ground_shape)
	holder.add_child(ground)
	var crate := StaticBody3D.new()
	crate.set_meta("prop", true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.9, 1.2)
	shape.shape = box
	shape.position = Vector3(0, 0.45, 0)
	crate.add_child(shape)
	crate.position = Vector3(6, 0, 6)
	holder.add_child(crate)
	player.global_position = Vector3(6, 1.0, 6)
	player.velocity = Vector3.ZERO
	player.active = true
	player.set_physics_process(true)
	var on_top := false
	for i in 30:
		await get_tree().physics_frame
		on_top = on_top or (player.is_on_floor() and player.global_position.y > 0.8)
	_check(on_top, "The test stands the player on the crate (y %.2f)" % player.global_position.y)
	for i in roundi((Player.PERCH_TIME + 1.0) * 60.0):
		await get_tree().physics_frame
	var off := Vector2(player.global_position.x - 6.0, player.global_position.z - 6.0).length() > 0.6 or player.global_position.y < 0.5
	_check(off, "A player perched on a prop is shoved off (at %s)" % str(player.global_position))
	player.set_physics_process(false)
	# Kill heals: only for your own punch's knockouts.
	GameState.upgrade_levels.sigil_blood = 1
	GameState.select_power("sigil_blood")
	_check(is_zero_approx(player.kill_heal(target)), "A monster a power put down heals nothing")
	target.set_meta("punched_out", true)
	_check(player.kill_heal(target) > 0.0, "One your punch put down heals")
	_check(PowerPlay.COOLDOWNS.sigil_fire >= 3.0 and PowerPlay.COOLDOWNS.sigil_blood >= 4.0, "Fire and Blood proc at most every 3s / 4s")
	await _free_rig(holder)
	print("Card runtime: perch and blood OK")


## The Mauler's revamp (2026-11-06): the Berserker passive's zone and kill
## heal, Masochist, Berserk's second wind, I Eat Those, Shoulder Charge and
## Inferno II's flame shockwave.
func _test_mauler_revamp() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = rig[2][0]
	var other: Enemy = rig[2][1]
	GameState.loadouts.berserker.passive = "berserker"
	player.cards._forget()
	player.refresh_max_knuckles()
	player.active = true
	# Masochist: x1.5 max HP, healing stops at 60%.
	var with_masochist := GameState.get_max_knuckles()
	GameState._classes.berserker.cards.erase("juggernaut")
	var without := GameState.get_max_knuckles()
	GameState._classes.berserker.cards["juggernaut"] = 1
	_check(is_equal_approx(with_masochist / without, 1.5), "Masochist: max knuckle HP x1.5 (%.2f)" % (with_masochist / without))
	_check(is_equal_approx(player.heal_cap(), player.max_knuckles * 0.6), "Masochist: healing stops at 60%")
	player.knuckles = 1.0
	player.heal(player.max_knuckles * 5.0)
	_check(is_equal_approx(player.knuckles, player.heal_cap()), "Masochist: a big heal stops at the cap")
	# The Berserker zone: +40% below half, nothing above.
	player.knuckles = player.max_knuckles * 0.4
	_check(player._berserker_mult() >= 1.4, "Berserker: +40%% below half (x%.2f)" % player._berserker_mult())
	player.knuckles = player.max_knuckles * 0.6
	_check(is_equal_approx(player._berserker_mult(), 1.0), "Berserker: nothing above half")
	# Kill heal: 1% of max, but only up to the half-way line.
	target.set_meta("punched_out", true)
	player.knuckles = player.max_knuckles * 0.6
	var base_heal := player.kill_heal(target)
	player.knuckles = player.max_knuckles * 0.3
	_check(is_equal_approx(player.kill_heal(target) - base_heal, player.max_knuckles * 0.01), "Berserker: a knockout heals 1% below half")
	player.knuckles = player.max_knuckles * 0.499
	_check(player.kill_heal(target) - base_heal < player.max_knuckles * 0.0015, "Berserker: the kill heal stops at half")
	# I Eat Those (rank 2: 50%): a landed hit sometimes opens a counter.
	var opened := 0
	for i in 60:
		player._clear_counter()
		player.cards.on_hit(target)
		if player._counter_side != "":
			opened += 1
	player._clear_counter()
	_check(opened >= 15 and opened <= 45, "I Eat Those opens a counter about half the time (%d of 60)" % opened)
	# Shoulder Charge: dash then uppercut launches a monster once.
	var at := target.global_position + Vector3(0, 1.3, 0)
	player._dash_jab_time = 0.5
	var mod: Dictionary = player.cards.punch_mod(target, "uppercut", false, false, true, at, false)
	_check(target.has_meta("shouldered") and String(mod.caption).contains("LAUNCHED"), "Shoulder Charge: a dash then an uppercut launches")
	player.cards.after_punch(target, "uppercut", "right", 1.0, 1.0, false, false, false, true, false)
	var again: Dictionary = player.cards.punch_mod(target, "uppercut", false, false, true, at, false)
	_check(not String(again.caption).contains("LAUNCHED"), "Shoulder Charge: once a monster")
	player._dash_jab_time = 0.0
	var plain: Dictionary = player.cards.punch_mod(other, "uppercut", false, false, true, other.global_position + Vector3(0, 1.3, 0), false)
	_check(not String(plain.caption).contains("LAUNCHED"), "Shoulder Charge: needs the dash")
	# Inferno II: the shockwave knocks down and ignites what is close.
	other.global_position = target.global_position + Vector3(2.5, 0, 0)
	player.ult._inferno_shockwave(target.global_position, target)
	_check(other._burn_time > 0.0 and other.is_staggered(), "Inferno II: the shockwave ignites and knocks down (burn %.1f)" % other._burn_time)
	# Berserk: a knockout leaves 1 HP, untouchable, once a bout.
	player.cards.untouchable = 0.0
	player.knuckles = 5.0
	player._lose_knuckles(50.0)
	_check(is_equal_approx(player.knuckles, 1.0) and player.cards.untouchable >= 7.9 and player.cards._berserk > 0.0,
			"Berserk: a knockout leaves 1 HP, untouchable (%.1f HP, %.1fs)" % [player.knuckles, player.cards.untouchable])
	var result := player.receive_attack(30.0, target.global_position, "jab", target)
	_check(result == "dodged" and is_equal_approx(player.knuckles, 1.0), "Berserk: nothing touches you meanwhile (%s)" % result)
	await _free_rig(holder)
	print("Card runtime: Mauler revamp OK")


## Third-person ultimates (2026-11-06): the camera is out and nothing touches
## you during the shot or for half a second after, then the camera is back.
func _test_cinematic_ult() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var player: Player = rig[1]
	var target: Enemy = rig[2][0]
	player.active = true
	player.knuckles = player.max_knuckles
	player.start_cinematic(Emotes.parse(Ult.INFERNO_CLIP), player.global_position + Vector3.UP, Vector2(0.6, 0.3), 3.6)
	_check(player.cinematic and player._emote_cam.current and not player._fists.visible, "The shot pulls the camera out")
	var before := player.knuckles
	var result := player.receive_attack(25.0, target.global_position, "jab", target)
	player.hurt_knuckles(25.0)
	_check(result == "dodged" and is_equal_approx(player.knuckles, before), "Untouchable during the shot (%s, %.1f of %.1f)" % [result, player.knuckles, before])
	player.end_cinematic()
	_check(player.is_cinematic_immune() and is_equal_approx(player._immune_after, Player.CINEMATIC_AFTER), "Half a second of immunity after")
	result = player.receive_attack(25.0, target.global_position, "jab", target)
	_check(result == "dodged", "Still untouchable just after the shot (%s)" % result)
	player._update_emote(Player.CINEMATIC_AFTER + 0.05)
	_check(not player.is_cinematic_immune(), "Then it is over")
	for i in 20:
		player._update_emote(0.05)
	_check(player._camera.current and player._fists.visible and not player._body.visible, "The camera is back in first person")
	await _free_rig(holder)
	print("Card runtime: third-person ultimate OK")


## The fighter picker (2026-10-29): hovering a card and leaving puts it back
## where it was, two rows or one (the pivot moving on a shrunk card shifted it).
func _test_fighter_card_hover() -> void:
	GameState._reset_fields()
	GameState.tony_unlocked = true
	GameState.fighters_bought.elementalist = true
	var title: Node = load("res://title.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	title._open_classes()
	await get_tree().process_frame
	for id in title._cards:
		var card: Control = title._cards[id].panel
		var home: Vector2 = title._cards[id].home
		card.mouse_entered.emit()
		await get_tree().create_timer(0.2).timeout
		card.mouse_exited.emit()
		await get_tree().create_timer(0.2).timeout
		_check(card.pivot_offset == Vector2.ZERO and card.position.is_equal_approx(home) and card.scale.is_equal_approx(Vector2.ONE * title._card_scale),
				"Hovering %s's card leaves it in place" % id)
	title.queue_free()
	await get_tree().process_frame
	print("Card runtime: fighter cards OK")


## Boss poise: a staggered boss can't be staggered or stunned again (or have
## its stagger stretched) until it has held its poise a while: no hook-spam lock.
func _test_boss_poise() -> void:
	var rig := await _make_rig("berserker")
	var holder: Node3D = rig[0]
	var dummies: Array[Enemy] = rig[2]
	var boss := dummies[1]
	boss.is_boss = true
	var at := boss.global_position + Vector3(0, 1.2, 0)
	boss.take_hit(1.0, at, Vector3.ZERO, true)
	_check(boss.is_staggered(), "The first set-up hook staggers a boss")
	boss._stagger_timer = 0.05
	boss.take_hit(1.0, at, Vector3.ZERO, true)
	boss.stun(2.0)
	_check(boss._stagger_timer <= 0.05, "A boss holding its poise isn't re-staggered or stunned")
	boss._stagger_timer = 0.0
	boss._poise_time = 0.0
	boss.take_hit(1.0, at, Vector3.ZERO, true)
	_check(boss.is_staggered(), "Once its poise runs out, a boss staggers again")
	var regular := dummies[2]
	regular.take_hit(1.0, regular.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, true)
	regular._stagger_timer = 0.05
	regular.take_hit(1.0, regular.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, true)
	_check(regular._stagger_timer > 0.05, "Regular monsters have no poise")
	await _free_rig(holder)
	print("Card runtime: boss poise OK")
