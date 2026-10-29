extends Node
## Headless rules/data regression checks for Dead League.

var _failures: Array[String] = []


func _ready() -> void:
	# Never touch the real save or settings, however this is launched: these
	# checks reset and save GameState (a run on 2026-10-11 wiped a real save).
	GameState.save_path = "user://test_save.json"
	Settings.path = "user://test_settings.cfg"
	call_deferred("_run")


func _run() -> void:
	_test_normalized_build()
	_test_grading()
	_test_boss_profiles()
	await _test_runtime_bosses()
	_test_unlocks_and_rewards()
	_test_scenes()
	await _test_true_king()
	GameState.end_dead_league()
	if _failures.is_empty():
		print("DEAD LEAGUE REGRESSION: PASS")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("DEAD LEAGUE REGRESSION: FAIL (%d)" % _failures.size())
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Bouts use your full build now, and each contender scales to its tier's par.
func _test_normalized_build() -> void:
	GameState._reset_fields()
	GameState.player_class = "berserker"
	GameState.equipped = {"test": {"effects": {"damage": 9.0, "max_knuckles": 40.0}}}
	var powered_damage := GameState.get_damage()
	GameState.begin_dead_league()
	_check(is_equal_approx(GameState.get_damage(), powered_damage), "League bouts must use your real build now")
	GameState.end_dead_league()
	GameState.equipped = {}
	var scene: PackedScene = load("res://dead_league_boss.tscn")
	var previous_hp := 0.0
	for index in DeadLeagueRules.BOSS_COUNT:
		var boss := scene.instantiate() as DeadLeagueBoss
		boss.configure(index, 1)
		var par := Progression.par(index + 1)
		_check(is_equal_approx(boss.max_hp, DeadLeagueRules.boss(index).hp * par.damage / Progression.BASE_DAMAGE),
				"Contender %d's HP must scale with its tier's par damage" % (index + 1))
		_check(boss.max_hp > previous_hp, "Each contender must be tougher than the last")
		previous_hp = boss.max_hp
		boss.free()


func _test_grading() -> void:
	var clean := {"elapsed": 75.0, "damage_taken": 4.0, "perfect_dodges": 9, "counters": 7, "grazes": 0, "variety": 4}
	var sloppy := {"elapsed": 180.0, "damage_taken": 45.0, "perfect_dodges": 0, "counters": 1, "grazes": 8, "variety": 1}
	var clean_score := DeadLeagueRules.score(clean)
	var sloppy_score := DeadLeagueRules.score(sloppy)
	_check(clean_score > sloppy_score, "Defensive reads and varied offense must improve the grade")
	_check(DeadLeagueRules.grade_rank(DeadLeagueRules.grade(clean_score)) > DeadLeagueRules.grade_rank(DeadLeagueRules.grade(sloppy_score)), "Clean play must earn a higher letter grade")
	_check(DeadLeagueRules.grade(1200) == "S+", "S+ threshold changed unexpectedly")
	_check(DeadLeagueRules.grade(900) == "A", "A threshold changed unexpectedly")
	# A win with no style isn't an A, and grades read the same at every tier.
	var passive := {"elapsed": 90.0, "damage_taken": 20.0, "max_knuckles": 60.0, "perfect_dodges": 0, "counters": 0, "grazes": 0, "variety": 1}
	_check(DeadLeagueRules.grade_rank(DeadLeagueRules.grade(DeadLeagueRules.score(passive))) < DeadLeagueRules.grade_rank("A"),
			"A bout won without dodges or counters must not grade A")
	var late := passive.duplicate()
	late.damage_taken = 200.0
	late.max_knuckles = 600.0
	_check(DeadLeagueRules.score(late) == DeadLeagueRules.score(passive), "The same share of health lost must score the same at any tier")
	# Your build against theirs: underdogs earn more, stomps less, capped.
	var even := DeadLeagueRules.score(clean)
	var stomp := clean.duplicate()
	stomp.power_ratio = 3.0
	var underdog := clean.duplicate()
	underdog.power_ratio = 0.6
	_check(DeadLeagueRules.score(stomp) < even and DeadLeagueRules.score(underdog) > even, "Being over-powered must lower the score and under-powered raise it")
	_check(is_equal_approx(DeadLeagueRules.build_factor(10.0), 0.8) and is_equal_approx(DeadLeagueRules.build_factor(0.1), 1.2), "The build factor must stay within 0.8-1.2")


func _test_boss_profiles() -> void:
	var ids := {}
	var scene: PackedScene = load("res://dead_league_boss.tscn")
	for index in DeadLeagueRules.BOSS_COUNT:
		var profile := DeadLeagueRules.boss(index)
		_check(not ids.has(profile.id), "Every League boss needs a unique id")
		ids[profile.id] = true
		var round_one := scene.instantiate() as DeadLeagueBoss
		round_one.configure(index, 1)
		var round_three := scene.instantiate() as DeadLeagueBoss
		round_three.configure(index, 3)
		_check(round_one.display_name == profile.name, "Boss %s must use its fight-card name" % profile.id)
		_check(round_three.max_hp > round_one.max_hp, "Boss %s round 3 must have more HP than round 1" % profile.id)
		_check(round_three.attack_damage > round_one.attack_damage, "Boss %s round 3 must hit harder than round 1" % profile.id)
		_check(round_one.coin_reward == 0 and round_one.xp_reward == 0, "League fights must not pay grindable coin/XP rewards")
		round_one.free()
		round_three.free()


func _test_runtime_bosses() -> void:
	GameState._reset_fields()
	GameState.begin_dead_league()
	var player := load("res://player.tscn").instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	player.active = false
	var scene: PackedScene = load("res://dead_league_boss.tscn")
	for index in DeadLeagueRules.BOSS_COUNT:
		var opponent := scene.instantiate() as DeadLeagueBoss
		opponent.configure(index, 1)
		opponent.setup(player, false)
		add_child(opponent)
		await get_tree().process_frame
		_check(opponent._body != null and opponent._meshes.size() >= 10,
				"Boss %s must build a complete runtime model" % DeadLeagueRules.boss(index).id)
		_check((opponent.feint_chance > 0.0) == (index > 0), "Every contender but the Bellman feints (%s)" % DeadLeagueRules.boss(index).id)
		if index > 0:
			# A sure feint: wound up dark and silent, then the other punch
			# lights up and is what gets thrown.
			opponent.feint_chance = 1.0
			opponent._begin_attack("jab", 0.6)
			var real: String = opponent._feint
			_check(real in Boxer.FEINTS.jab and opponent._arm_glow("left").is_empty() and opponent._arm_glow("right").is_empty(),
					"A feint winds up with no glove lit")
			opponent._previewed = true
			_check(opponent._arm_glow("left").is_empty(), "A feint's glove stays dark even as a combo follow-up")
			opponent._state_timer = Enemy.tell_time()
			opponent._think(0.0)
			_check(opponent._attack == real and opponent._feint == "" and not opponent._flashed, "Where its tell would flash, the feint drops for %s" % real)
			_check(opponent._state_timer > Enemy.tell_time(), "The real punch winds up before it lights")
			for i in 60:
				opponent._think(1.0 / 60.0)
				if opponent._flashed:
					break
			_check(opponent._flashed and opponent._attack == real, "Then the real punch lights up")
		remove_child(opponent)
		opponent.free()
	remove_child(player)
	player.free()
	GameState.end_dead_league()


func _test_unlocks_and_rewards() -> void:
	GameState._reset_fields()
	_check(GameState.dead_league_unlocked(0), "The Bellman must be unlocked from the start")
	_check(not GameState.dead_league_unlocked(1), "The Headless must initially be locked")
	var first := GameState.record_dead_league_result("bellman", "A", 950)
	_check(first and Progression.seals_broken() == 1, "A first boss clear must break exactly one seal")
	_check(GameState.dead_league_unlocked(1), "Clearing the Bellman must unlock The Headless")
	var repeat := GameState.record_dead_league_result("bellman", "B", 700)
	_check(not repeat and Progression.seals_broken() == 1, "Repeating a clear must not break more seals")
	_check(int(GameState.dead_league_best.bellman.score) == 950, "A worse repeat must not replace the personal best")
	GameState.record_dead_league_result("bellman", "S", 1100)
	_check(int(GameState.dead_league_best.bellman.score) == 1100, "A better result must replace the personal best")


## The True Coffin King (2026-10-29): an overkill hit can't skip his tag-in,
## he can't be hurt out of the ring (a burn used to kill him mid-hop, so the
## round ended and the tag-in became a second Coffin King), the right
## contender comes in, and the Insano round goes into a fury at half HP.
func _test_true_king() -> void:
	GameState._reset_fields()
	GameState.dead_league_bout = DeadLeagueRules.BOSS_COUNT - 1
	GameState.true_king_bout = true
	var arena: Node = load("res://dead_league_arena.tscn").instantiate()
	add_child(arena)
	for i in 600:
		await get_tree().process_frame
		if arena._player.active:
			break
	var king: DeadLeagueBoss = arena._boss
	king.take_hit(king.max_hp * 10.0, king.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false)
	_check(not king.is_dead() and arena._tagged, "An overkill hit sends the True Coffin King out to tag, not down")
	var hp: float = king.hp
	king.ignite(king.max_hp, 5.0)
	king._status_damage(king.max_hp, Color.RED)
	await get_tree().create_timer(1.2).timeout
	_check(not king.is_dead() and is_equal_approx(king.hp, hp), "Out of the ring, nothing hurts the True Coffin King")
	_check(arena._round == 1, "His round doesn't end while he's out (round %d)" % arena._round)
	var partner: DeadLeagueBoss = arena._partner
	_check(partner != null and partner.profile_index == 0, "Round 1 tags in the Bellman")
	# The Insano round: a fresh King, a burning floor, a fury at half HP.
	if is_instance_valid(partner):
		partner.queue_free()
	arena._round = arena.TRUE_ROUNDS
	arena._spawn_boss()
	var insano: DeadLeagueBoss = arena._boss
	_check(insano.insano and insano.hp_floor == 0.0, "Round 5: Insano, and he can go down")
	var windup: float = insano.windup_scale
	insano.take_hit(insano.max_hp * 0.55, insano.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false)
	_check(arena._floor.fury and insano._base_windup < windup, "Below half HP the Insano King goes into a fury")
	arena.queue_free()
	await get_tree().process_frame
	GameState.true_king_bout = false


func _test_scenes() -> void:
	for path in ["res://dead_league_menu.tscn", "res://dead_league_arena.tscn", "res://art/dead_league/dead_league_key_art.png"]:
		_check(ResourceLoader.exists(path), "Missing Dead League resource: " + path)
	for class_id in GameState.CLASSES:
		var fighter_path := "res://art/versus/fighter_%s.png" % class_id
		_check(ResourceLoader.exists(fighter_path), "Missing versus fighter portrait: " + fighter_path)
		var fighter_portrait := load(fighter_path) as Texture2D
		_check(fighter_portrait != null, "Versus fighter portrait failed to load: " + fighter_path)
		if fighter_portrait:
			_check(fighter_portrait.get_width() * 4 == fighter_portrait.get_height() * 3,
					"Versus fighter portrait must use a 3:4 aspect ratio: " + fighter_path)
	for index in DeadLeagueRules.BOSS_COUNT:
		var portrait_path := "res://art/dead_league/portrait_%d.png" % index
		_check(ResourceLoader.exists(portrait_path), "Missing Dead League portrait: " + portrait_path)
		var portrait := load(portrait_path) as Texture2D
		_check(portrait != null, "Dead League portrait failed to load: " + portrait_path)
		if portrait:
			_check(portrait.get_width() * 4 == portrait.get_height() * 3,
					"Dead League portrait must use a 3:4 aspect ratio: " + portrait_path)
