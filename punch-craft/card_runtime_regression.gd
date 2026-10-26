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
	}
	GameState.power_pick = "sigil_fire"
	GameState.power_pick_2 = "sigil_frost"
	GameState.power_pick_3 = "sigil_storm"
	GameState.loadouts[fighter] = {
		"passive": Abilities.default_passive(fighter),
		"ultimate": ultimate if ultimate != "" else Abilities.default_ultimate(fighter),
	}


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
	await _free_rig(holder)
	print("Card runtime: %s / %s OK" % [fighter, ultimate])


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
