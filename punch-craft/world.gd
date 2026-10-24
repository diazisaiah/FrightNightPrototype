extends Node3D
## A run starts at the next unbeaten night in the graveyard. Enemies keep
## coming out of the fog; every kill fills the night's progress bar, and when
## it's full the Grave Champion rises. Beat it and dawn breaks: choose to
## continue straight into the next, harder and richer night (a fresh start:
## full knuckles) or return to camp. Break your knuckles and the run ends.
## Each enemy is as strong as the bar was full when it spawned, so the night
## gets harder as it goes, and harder again every night.

const ZOMBIE_SCENE := preload("res://zombie.tscn")
const SKELETON_SCENE := preload("res://skeleton.tscn")
const RUNNER_SCENE := preload("res://runner.tscn")
const BRAWLER_SCENE := preload("res://brawler.tscn")
const BOSS_SCENE := preload("res://boss.tscn")
const HULK_SCENE := preload("res://hulk.tscn")
const MAGE_SCENE := preload("res://mage.tscn")
const PRIEST_SCENE := preload("res://priest.tscn")
const ARMOR_SCENE := preload("res://possessed_armor.tscn")
const SCENES := {
	"zombie": ZOMBIE_SCENE, "skeleton": SKELETON_SCENE, "runner": RUNNER_SCENE,
	"brawler": BRAWLER_SCENE, "boss": BOSS_SCENE, "hulk": HULK_SCENE, "mage": MAGE_SCENE,
	"priest": PRIEST_SCENE, "armor": ARMOR_SCENE,
}
## Kills that fill the night's progress bar. When it's full the boss rises.
const KILLS_TO_BOSS := 50
## What can spawn. unlock: how full the bar must be (0-1) before it shows up
## (the first one is sent right away). weight: how often it's picked. max: how
## many can be alive at once, before and after LATE_NIGHT.
const ENEMY_TYPES := {
	"zombie": {"name": "Zombie", "unlock": 0.0, "weight": 3.0, "max": [99, 99]},
	"skeleton": {"name": "Skeleton", "unlock": 0.04, "weight": 1.2, "max": [2, 3]},
	"runner": {"name": "Runner", "unlock": 0.12, "weight": 1.4, "max": [3, 4]},
	"hulk": {"name": "Hulk", "unlock": 0.2, "weight": 0.6, "max": [1, 2]},
	"brawler": {"name": "Ghoul Brawler", "unlock": 0.28, "weight": 1.0, "max": [2, 3]},
	"mage": {"name": "Fire Mage", "unlock": 0.36, "weight": 0.8, "max": [1, 2]},
	"priest": {"name": "Grave Priest", "unlock": 0.45, "weight": 0.6, "max": [1, 1]},
	"armor": {"name": "Possessed Armor", "unlock": 0.55, "weight": 0.7, "max": [1, 2]},
}
## Night 1 is the first chapter and goes easy on a fresh fighter: a shorter
## bar, weaker and fewer enemies (no armor, no mages, priests or possessed
## armor), cheaper punches, healing on every kill and milestone, and a softer
## Champion (no armor, 30% HP, no summons) who faces you with just one
## escort: the rest of the dead crumble when he rises.
const FIRST_NIGHT := {
	"kills": 30, "hp": 0.6, "damage": 0.6, "min_alive": 2, "max_alive": 5, "spawn_slow": 1.4,
	"punch_cost": 0.5, "kill_heal": 2.0, "milestone_heal": 0.08,
	"types": ["zombie", "skeleton", "runner", "hulk", "brawler"],
	"boss_hp": 0.3, "boss_damage": 0.7, "escorts": ["skeleton"],
}
const LATE_NIGHT := 0.75
## Enemies on the field at once, growing as the bar fills.
const MIN_ALIVE := 3
const MAX_ALIVE := 8
## Seconds between spawns, from an empty bar to a full one.
const SPAWN_INTERVAL_START := 2.2
const SPAWN_INTERVAL_END := 1.0
const FIRST_SPAWN_DELAY := 2.0
## Every tenth of the bar is a milestone: a coin bonus (and the heals from
## upgrades like Cornerman).
const MILESTONES := 10
const MILESTONE_COINS := 5
## Enemy strength from an empty bar to a full one, locked in when each spawns.
## In-bout growth on top of the Climb's scaling (Progression).
const HP_GROWTH := 0.5
const DAMAGE_GROWTH := 0.3
const SPEED_GROWTH := 0.24
const REWARD_GROWTH := 0.5
## Armored enemies get more common as the bar fills.
const ARMOR_START := 0.1
const ARMOR_RATE := 0.8
const MAX_ARMOR_CHANCE := 0.6
## Rise with the boss.
const BOSS_ESCORTS := ["skeleton", "mage"]
const BOSS_SPAWN_DISTANCE := 14.0
## The Underworld Arena's purse for winning a bout, before the tier's pay
## and the style grade multiply it.
const ARENA_PURSE := 180.0
## Harder bouts pay more: each bout 1.5x the last (Progression.pay, the pay
## ladder), so replaying an easier bout is the safe, slower way to earn.
## The first win of each bout pays a one-time bonus (x the tier's pay).
const FIRST_WIN_BONUS := [150, 250, 400]
## Knocked out: a share of the purse for how far through the bout you got.
const KNOCKOUT_PURSE := 0.35
## Seconds the crowd roars after the Grave Champion drops, before the results.
const VICTORY_LINGER := 2.8
## Style grades: [minimum score, letter, purse multiplier].
const GRADES := [[1300, "S+", 2.6], [1100, "S", 2.2], [900, "A", 1.7], [700, "B", 1.3], [450, "C", 1.0], [-99999, "D", 0.8]]
const SUMMON_RADIUS := 4.0
const ARENA_RADIUS := 45.0
const SPAWN_DISTANCE_MIN := 20.0
const SPAWN_DISTANCE_MAX := 30.0
const FALL_LIMIT := -20.0
const TORCH_COUNT := 8
const DEAD_TREE_COUNT := 28
const GRAVESTONE_COUNT := 30
const GRAVE_PLOTS := 9
const CRYPT_COUNT := 5

var _night_kills := 0
var _milestone := 0
var _boss_spawned := false
var _night_won := false
## Enemy types that have shown up this night.
var _seen_types := {}
var _alive_by_kind := {}
var _spawn_timer := FIRST_SPAWN_DELAY
var _alive := 0
var _kills := 0
var _run_coins := 0
var _run_xp := 0
var _run_over := false
var _torches: Array[OmniLight3D] = []
var _torch_time := 0.0
## The bout within the division (the old "night"; bout 1 of the first
## division keeps the gentle first-night rules).
var _night := 1
## The Underworld Arena division (= tier of the Climb).
var _division := 1
## This division's place (Themes.ARENA).
var _theme := {}
## Style tally for the current bout (the purse's grade).
var _style := {}
var _run_souls := 0
## Run tallies when this bout started, so the results show just this bout.
var _bout_start := [0, 0, 0]
var _nights_cleared_this_run := 0

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD
@onready var _enemies: Node3D = $Enemies
@onready var _decorations: Node3D = $Decorations


func _ready() -> void:
	# Your kept gear comes with you (GameState.equipped).
	_division = clampi(GameState.arena_division, 1, Progression.current_tier())
	_theme = Themes.arena(_division)
	Sfx.play_music(_theme.music)
	_night = clampi(int(GameState.arena_bouts.get(str(_division), 0)) + 1, 1, Progression.BOUTS_PER_DIVISION)
	# A bout picked in camp: any you've won, or the next one.
	if GameState.arena_bout_pick > 0:
		_night = clampi(GameState.arena_bout_pick, 1, _night)
		GameState.arena_bout_pick = 0
	Enemy.max_attackers = 1 if _division <= 2 else 2
	_reset_style()
	$Moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	Themes.apply_environment($WorldEnvironment.environment, _theme, $Moon)
	Look.tune_environment($WorldEnvironment.environment, "night")
	Voxel.prewarm(self, SCENES.values() + (Veterans.SCENES.values() if _division > 1 else []))
	_build_decorations()
	Look.batch_meshes(_decorations, true)

	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	Sfx.play_ambience("wind", -16.0)
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.class_event.connect(_hud.show_class_event)
	_player.knuckles_broken.connect(_on_knocked_out)
	GameState.leveled_up.connect(_on_leveled_up)
	_hud.end_run_requested.connect(_end_run.bind("FLED"))
	_hud.back_to_camp_requested.connect(_go_to_camp)
	_hud.continue_requested.connect(_continue_to_next_night)
	_hud.crypt_requested.connect(_descend_into_crypt)

	_player.dodged.connect(_on_style_dodge)
	_player.punch_connected.connect(_on_style_punch)
	_player.attacked.connect(func(_from: Vector3) -> void: _style.hits += 1)
	_player.grazed.connect(func() -> void: _style.grazes += 1)

	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)
	_apply_first_night()
	_update_night_hud()
	_hud.announce(_bout_title())
	_hud.say("", Progression.announcer_line(), Color(1.0, 0.8, 0.45))


func _first_night() -> bool:
	return _division == 1 and _night == 1


## "GRAVEDIGGER DIVISION  ·  BOUT 2"
func _bout_title() -> String:
	return "%s DIVISION  ·  BOUT %d" % [Progression.TIERS[_division - 1].division.to_upper(), _night]


func _position(bout := -1) -> float:
	return Progression.arena_position(_division, _night if bout < 0 else bout)


# --- Style grade ---------------------------------------------------------------

## Lit when you fought with style: clean dodges, counters, every punch, no hits.
func _medals(clean: int, counters: int, types: int, hits: int) -> Array:
	return [
		["CLEAN  x%d" % clean, clean >= 3],
		["COUNTERS  x%d" % counters, counters >= 3],
		["FULL ARSENAL", types >= 4],
		["UNTOUCHED", hits == 0],
	]


func _reset_style() -> void:
	_bout_start = [_run_coins, _run_xp, _run_souls]
	_style = {"clean": 0, "counters": 0, "types": {}, "hits": 0, "grazes": 0}


func _on_style_dodge(move: String) -> void:
	if move.begins_with("clean_"):
		_style.clean += 1


func _on_style_punch(type: String, kind: String) -> void:
	if kind in ["blocked", "evaded"]:
		return
	_style.types[type] = true
	if kind == "counter":
		_style.counters += 1


## [score, letter, purse multiplier] for the bout so far: clean dodges,
## counters and punch variety raise it; getting hit and grazed lower it.
func _grade() -> Array:
	var score: int = 600 + 20 * _style.clean + 12 * _style.counters + 50 * _style.types.size() \
			- 30 * _style.hits - 10 * _style.grazes
	for grade in GRADES:
		if score >= grade[0]:
			return [score, grade[1], grade[2]]
	return [score, "D", 0.8]


func _apply_first_night() -> void:
	_player.punch_cost_scale = FIRST_NIGHT.punch_cost if _first_night() else 1.0


func _kills_needed() -> int:
	return FIRST_NIGHT.kills if _first_night() else KILLS_TO_BOSS


func _process(delta: float) -> void:
	_flicker_torches(delta)
	if _run_over or _boss_spawned:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _alive < _max_alive():
		_spawn_timer = lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_END, _progress()) * (FIRST_NIGHT.spawn_slow if _first_night() else 1.0)
		var kind := _pick_kind()
		_spawn_enemy({"kind": kind, "armored": randf() < _armor_chance()})


func _exit_tree() -> void:
	TimeFx.clear()


func _physics_process(_delta: float) -> void:
	if _player.global_position.y < FALL_LIMIT:
		_player.global_position = Vector3(0, 1, 0)
		_player.velocity = Vector3.ZERO


# --- The night ---------------------------------------------------------------

## How full the night's progress bar is, 0-1.
func _progress() -> float:
	return clampf(float(_night_kills) / _kills_needed(), 0.0, 1.0)


func _max_alive() -> int:
	if _first_night():
		return FIRST_NIGHT.min_alive + roundi((FIRST_NIGHT.max_alive - FIRST_NIGHT.min_alive) * _progress())
	return MIN_ALIVE + roundi((MAX_ALIVE - MIN_ALIVE) * _progress())


func _armor_chance() -> float:
	if _first_night():
		return 0.0
	return clampf((_progress() - ARMOR_START) * ARMOR_RATE, 0.0, MAX_ARMOR_CHANCE)


## The next enemy to send: a type that just unlocked goes first (so every new
## enemy gets introduced), otherwise a weighted pick of what's unlocked and
## not already at its limit.
func _pick_kind() -> String:
	var progress := _progress()
	var choices := {}
	var total := 0.0
	for kind in ENEMY_TYPES:
		var info: Dictionary = ENEMY_TYPES[kind]
		if progress < info.unlock or (_first_night() and not kind in FIRST_NIGHT.types):
			continue
		if not _seen_types.has(kind):
			_seen_types[kind] = true
			if _night_kills > 0:
				_hud.add_feed("A %s joins the night..." % info.name, Color(0.8, 0.55, 1.0))
			return kind
		var limit: int = info.max[1] if progress >= LATE_NIGHT else info.max[0]
		if _alive_by_kind.get(kind, 0) < limit:
			choices[kind] = info.weight
			total += info.weight
	var roll := randf() * total
	for kind in choices:
		roll -= choices[kind]
		if roll <= 0.0:
			return kind
	return "zombie"


## How strong (and rewarding) an enemy spawning right now is: grows with the
## progress bar and the night.
func _spawn_scaling() -> Dictionary:
	var progress := _progress()
	var night := _night_scaling()
	if _first_night():
		night.hp *= FIRST_NIGHT.hp
		night.damage *= FIRST_NIGHT.damage
	return {
		"hp": (1.0 + HP_GROWTH * progress) * night.hp,
		"damage": (1.0 + DAMAGE_GROWTH * progress) * night.damage,
		"speed": 1.0 + SPEED_GROWTH * progress,
		"reward": (1.0 + REWARD_GROWTH * progress) * night.reward,
		"xp": (1.0 + REWARD_GROWTH * progress) * night.xp,
		"position": night.position,
	}


## Night-only scaling (used for the boss, whose base stats already fit a full
## bar). night defaults to the current one.
## The Climb's scaling at this bout of the division (Progression): bout by
## bout it climbs from the last contender's par build toward this one's, a
## fifth of a tier a bout (Progression.arena_difficulty); pay climbs faster.
func _night_scaling(night := -1) -> Dictionary:
	return Progression.enemy_scaling(_position(night), Progression.arena_difficulty(_division, _night if night < 0 else night))


func _boss_scaling() -> Dictionary:
	var scaling := _night_scaling()
	if _first_night():
		scaling.hp *= FIRST_NIGHT.boss_hp
		scaling.damage *= FIRST_NIGHT.boss_damage
	return scaling


## at: where to spawn; by default a point out in the fog.
func _spawn_enemy(entry: Dictionary, at := Vector3.INF) -> void:
	var kind: String = entry.kind
	# Deeper divisions send veterans (tougher versions with a big move).
	var veteran := Veterans.pick(kind, _division) if kind != "boss" and not _first_night() else null
	var enemy: Enemy = (veteran if veteran else SCENES[kind]).instantiate()
	if veteran:
		enemy.set_meta("veteran", true)
	enemy.setup(_player, entry.armored, _boss_scaling() if kind == "boss" else _spawn_scaling())
	enemy.set_meta("kind", kind)
	# Position before entering the tree so it never overlaps the player at the origin.
	enemy.position = _spawn_point() if at == Vector3.INF else at
	_enemies.add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	if enemy is Boss:
		enemy.summon_requested.connect(_on_boss_summon.bind(enemy))
		enemy.health_changed.connect(_hud.set_boss_health)
		_hud.show_boss(enemy.display_name, enemy.hp, enemy.max_hp)
	_alive += 1
	_alive_by_kind[kind] = _alive_by_kind.get(kind, 0) + 1
	_update_night_hud()


## The bar is full: the Grave Champion rises (closer than usual) with escorts.
func _start_boss() -> void:
	_boss_spawned = true
	Sfx.play("wave", -2.0)
	if _first_night():
		for node in _enemies.get_children():
			var enemy := node as Enemy
			if enemy and not enemy.is_dead():
				enemy._die(Vector3.ZERO)
	_hud.announce("The Grave Champion rises")
	var forward := -_player.global_basis.z
	forward.y = 0.0
	var spot := _player.global_position + forward.normalized() * BOSS_SPAWN_DISTANCE
	spot = Vector3(spot.x, 0.1, spot.z).limit_length(ARENA_RADIUS)
	_spawn_enemy({"kind": "boss", "armored": not _first_night()}, Vector3(spot.x, 0.1, spot.z))
	var escorts: Array = FIRST_NIGHT.escorts if _first_night() else BOSS_ESCORTS
	for i in escorts.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var offset := forward.normalized().cross(Vector3.UP) * side * 4.0
		_spawn_enemy({"kind": escorts[i], "armored": false}, Vector3(spot.x + offset.x, 0.1, spot.z + offset.z))
	_update_night_hud()


func _on_boss_summon(count: int, boss: Boss) -> void:
	if _first_night():
		return
	_hud.announce_small("The dead answer his call!", Color(0.8, 0.3, 1.0))
	for i in count:
		var offset := Vector2.from_angle(TAU * i / count) * SUMMON_RADIUS
		_spawn_enemy({"kind": "zombie", "armored": false}, boss.global_position + Vector3(offset.x, 0.1, offset.y))


## A point out in the fog, 20-30m from the player and inside the arena.
func _spawn_point() -> Vector3:
	var player_pos := Vector2(_player.global_position.x, _player.global_position.z)
	for attempt in 20:
		var point := player_pos + Vector2.from_angle(randf() * TAU) * randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
		if point.length() <= ARENA_RADIUS:
			return Vector3(point.x, 0.1, point.y)
	var edge := Vector2.from_angle(randf() * TAU) * ARENA_RADIUS
	return Vector3(edge.x, 0.1, edge.y)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	var kind: String = enemy.get_meta("kind", "")
	_alive_by_kind[kind] = maxi(0, _alive_by_kind.get(kind, 0) - 1)
	_kills += 1
	var coins := GameState.roll_coins(enemy.coin_reward)
	_run_coins += coins
	GameState.add_resource("coins", coins)
	var xp := roundi(enemy.xp_reward * (1.0 + GameState.get_effect("xp_bonus")))
	_run_xp += xp
	GameState.add_xp(xp)
	_player.heal(GameState.heal_amount("heal_on_kill", _player.max_knuckles) + (FIRST_NIGHT.kill_heal if _first_night() else 0.0))
	if _run_over or _night_won:
		return
	if enemy is Boss:
		_hud.hide_boss()
		_win_night()
		return
	if not _boss_spawned:
		_night_kills += 1
		while _milestone < MILESTONES - 1 and _progress() >= float(_milestone + 1) / MILESTONES:
			_milestone += 1
			_on_milestone(_milestone)
		if _progress() >= 1.0:
			_start_boss()
	_update_night_hud()


## Every tenth of the bar: a coin bonus that grows through the night, plus
## upgrade heals.
func _on_milestone(milestone: int) -> void:
	var bonus := roundi(milestone * MILESTONE_COINS * Progression.pay(_position()) * GameState.get_wave_bonus_multiplier())
	_run_coins += bonus
	GameState.add_resource("coins", bonus)
	_hud.announce_small("%d%% through the night   +%d {coins}" % [milestone * 100 / MILESTONES, bonus], Color(1, 0.85, 0.4))
	_player.heal(GameState.heal_amount("wave_heal", _player.max_knuckles) + (_player.max_knuckles * FIRST_NIGHT.milestone_heal if _first_night() else 0.0))
	Sfx.play("clear", -8.0)


func _update_night_hud() -> void:
	_hud.set_night_progress(_bout_title(), _night_kills, _kills_needed(), _spawn_scaling().hp, _boss_spawned)


## The boss is down: the bell rings, the rest of the dead crumble and the
## crowd roars for a few seconds before the results. The player then picks
## whether to push on into the next bout or go back to camp.
func _win_night() -> void:
	_night_won = true
	_player.invulnerable = true
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy and not enemy.is_dead():
			enemy._die(Vector3.ZERO)
	Sfx.play("bell")
	_hud.announce("K.O.!")
	await get_tree().create_timer(VICTORY_LINGER).timeout
	if not is_inside_tree() or _run_over:
		return
	_player.invulnerable = false
	# The purse: the tier's pay times your style grade.
	var grade := _grade()
	var bonus := roundi(ARENA_PURSE * Progression.pay(_position()) * grade[2] * (1.0 + GameState.get_effect("dawn_bonus")))
	var first_time := GameState.clear_arena_bout(_division, _night)  # Also saves.
	var first_bonus := 0
	if first_time:
		first_bonus = roundi(FIRST_WIN_BONUS[_night - 1] * Progression.pay(_position()))
		bonus += first_bonus
	_run_coins += bonus
	GameState.add_resource("coins", bonus)
	var souls := Progression.boss_souls(_position(), first_time)
	_run_souls += souls
	GameState.add_souls(souls)
	_nights_cleared_this_run += 1
	Sfx.play("clear")
	var top := _night >= Progression.BOUTS_PER_DIVISION
	var notes: Array[String] = []
	if first_bonus > 0:
		notes.append("FIRST WIN BONUS  +%d COINS" % first_bonus)
	if top and not bool(GameState.dead_league_clears.get(Progression.TIERS[_division - 1].contender, false)):
		notes.append("%s AWAITS IN THE DEAD LEAGUE" % DeadLeagueRules.boss(_division - 1).name)
	_hud.show_results({
		"title": "BOUT %d WON" % _night,
		"subtitle": "%s DIVISION" % Progression.TIERS[_division - 1].division.to_upper(),
		"grade": grade[1],
		"medals": _medals(_style.clean, _style.counters, _style.types.size(), _style.hits),
		"rewards": {"coins": _run_coins - _bout_start[0], "xp": _run_xp - _bout_start[1], "souls": _run_souls - _bout_start[2]},
		"note": "\n".join(notes),
		"note_color": UiTheme.GOLD,
	}, "Fight on" if top else "Next bout", GameState.crypt_unlocked)


func _continue_to_next_night() -> void:
	_night = mini(_night + 1, Progression.BOUTS_PER_DIVISION)
	_reset_style()
	_night_kills = 0
	_milestone = 0
	_boss_spawned = false
	_night_won = false
	_seen_types.clear()
	_spawn_timer = FIRST_SPAWN_DELAY
	_apply_first_night()
	_player.start_fresh()
	_hud.resume_after_summary()
	_hud.announce(_bout_title())
	_hud.say("", Progression.announcer_line(), Color(1.0, 0.8, 0.45))
	_update_night_hud()


# --- Run end ----------------------------------------------------------------

func _on_leveled_up(new_level: int) -> void:
	_hud.announce_small("LEVEL UP!", Color(0.5, 0.9, 1))


## Knuckles broke: fall to the canvas, then the results.
func _on_knocked_out() -> void:
	if _run_over:
		return
	_hud.knockout_fade()
	_player.knock_out()
	await get_tree().create_timer(Player.KNOCKOUT_TIME).timeout
	if is_inside_tree():
		_end_run("KNOCKED OUT", false)


func _end_run(title: String, slow := true) -> void:
	if _run_over:
		return
	_run_over = true
	_player.active = false
	TimeFx.clear()
	if slow:
		TimeFx.slowmo(0.3, 0.8)
	# Knocked out mid-bout: a share of the purse for how far you got.
	if title == "KNOCKED OUT" and not _night_won:
		var consolation := roundi(ARENA_PURSE * Progression.pay(_position()) * KNOCKOUT_PURSE * _progress())
		_run_coins += consolation
		GameState.add_resource("coins", consolation)
	GameState.save_game()
	_hud.show_results({
		"title": "KNOCKED OUT" if title == "KNOCKED OUT" else "BACK TO CAMP",
		"title_color": UiTheme.BAD if title == "KNOCKED OUT" else UiTheme.GOLD,
		"subtitle": _bout_title(),
		"rewards": {"coins": _run_coins, "xp": _run_xp, "souls": _run_souls},
	}, "", false, "Back to camp")


# --- Leaving -----------------------------------------------------------------------

## The bout-end screen's "Descend into the Crypt" (once the Crypt is open).
func _descend_into_crypt() -> void:
	GameState.save_game()
	get_tree().paused = false
	Loading.go("res://dungeon.tscn")


func _go_to_camp() -> void:
	get_tree().paused = false
	Loading.go("res://camp.tscn")


# --- Scenery ----------------------------------------------------------------

## Dead trees, gravestones and torches. Scenery has no collision so it never
## traps the player or enemies.
func _build_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6661 + _night
	if _theme.id != "graveyard":
		# The deeper divisions have their own places (ArenaScenery).
		($Ground/Mesh as MeshInstance3D).material_override = Look.block_material(_theme.ground)
		_torches.append_array(ArenaScenery.build(_theme, _decorations, rng))
		_place_hazards(rng)
		return
	var web := Settings.use_web_profile()
	var grave_plots := 5 if web else GRAVE_PLOTS
	var lone_graves := 14 if web else GRAVESTONE_COUNT
	var dead_trees := 12 if web else DEAD_TREE_COUNT
	var crypts := 3 if web else CRYPT_COUNT
	var rock_clusters := 14 if web else 30
	var torches := 4 if web else TORCH_COUNT
	var wood := Enemy._material(Color(0.25, 0.17, 0.1))
	($Ground/Mesh as MeshInstance3D).material_override = Look.block_material(Color(0.14, 0.17, 0.12))
	Scenery.night_sky(_decorations, rng)
	Scenery.ground_patches(_decorations, ARENA_RADIUS, 36 if web else 70, rng)
	Scenery.grass(_decorations, ARENA_RADIUS + 8.0, 6000 if web else 14000, rng)

	# Plots of graves in rows, around a clear middle.
	for plot in grave_plots:
		var center := Vector2.from_angle(TAU * plot / grave_plots + rng.randf_range(-0.2, 0.2)) * rng.randf_range(11.0, ARENA_RADIUS - 4.0)
		var facing := rng.randf() * TAU
		var rows := rng.randi_range(2, 3)
		var columns := rng.randi_range(3, 5)
		for row in rows:
			for column in columns:
				if rng.randf() < 0.18:
					continue
				var offset := Vector2((column - columns / 2.0) * 1.5, row * 2.4).rotated(facing)
				var node := _decoration_at(center + offset)
				node.rotation.y = -facing
				Scenery.gravestone(node, rng.randi_range(0, 5), rng)
	# Lone graves scattered about.
	for i in lone_graves:
		var node := _decoration_at(_random_scenery_spot(7.0))
		Scenery.gravestone(node, rng.randi_range(0, 5), rng)

	for i in dead_trees:
		var node := _decoration_at(_random_scenery_spot(9.0))
		Scenery.dead_tree(node, rng, rng.randf_range(3.5, 7.0))
	for i in crypts:
		var spot := Vector2.from_angle(TAU * i / crypts + rng.randf_range(-0.3, 0.3)) * rng.randf_range(ARENA_RADIUS - 10.0, ARENA_RADIUS + 2.0)
		var node := _decoration_at(spot)
		node.rotation.y = atan2(-spot.x, -spot.y) + PI
		Scenery.crypt(node, rng)
	for i in rock_clusters:
		Scenery.rocks(_decoration_at(_random_scenery_spot(5.0)), rng, rng.randi_range(2, 5))
	# An iron fence ringing the graveyard.
	var sides := 12
	var fence_radius := ARENA_RADIUS + 4.0
	for i in sides:
		var a := TAU * i / sides
		var b := TAU * (i + 1) / sides
		var from := Vector2.from_angle(a) * fence_radius
		var to := Vector2.from_angle(b) * fence_radius
		var run := Scenery.fence(_decorations, from.distance_to(to))
		run.position = Vector3(from.x, 0, from.y)
		run.rotation.y = -atan2(to.y - from.y, to.x - from.x)

	# Ground mist, wisps and the torches.
	Scenery.mist(_decorations, Vector3(0, 0.5, 0), Vector3(ARENA_RADIUS, 0.3, ARENA_RADIUS), 35 if web else 90)
	Scenery.wisps(_decorations, Vector3(0, 1.4, 0), Vector3(ARENA_RADIUS * 0.8, 1.0, ARENA_RADIUS * 0.8), Color(0.45, 1.0, 0.75), 20 if web else 50)
	for i in torches:
		var spot := Vector2.from_angle(TAU * i / torches) * randf_range(10.0, 30.0)
		var torch := _decoration_at(spot)
		torch.add_child(_mesh(Enemy._box(Vector3(0.1, 1.6, 0.1)), wood, Vector3(0, 0.8, 0)))
		torch.add_child(_mesh(Enemy._box(Vector3(0.2, 0.06, 0.2)), wood, Vector3(0, 1.58, 0)))
		Look.flame(torch, Vector3(0, 1.7, 0))
		var light := Look.fire_light(Color(1.0, 0.6, 0.25), 2.2, 10.0)
		light.position.y = 1.95
		torch.add_child(light)
		_torches.append(light)


## The deeper divisions' hazards (Themes): toxic puddles or fire vents across
## the field, away from the middle and each other. Not decorations: they
## live in the world so batching never touches them.
func _place_hazards(rng: RandomNumberGenerator) -> void:
	if _theme.hazard == "":
		return
	var hit: float = 6.0 * _night_scaling().damage
	var spots: Array[Vector2] = []
	var tries := 0
	while spots.size() < (10 if _theme.hazard == "toxic" else 9) and tries < 200:
		tries += 1
		var spot := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, ARENA_RADIUS - 6.0)
		if spots.any(func(other: Vector2) -> bool: return other.distance_to(spot) < 7.0):
			continue
		spots.append(spot)
	for spot in spots:
		var toxic: bool = _theme.hazard == "toxic"
		var hazard := Hazard.make(_theme.hazard, Vector3(spot.x, 0, spot.y), rng.randf_range(1.6, 2.4) if toxic else 1.5,
				hit * (0.16 if toxic else 1.3), _player)
		add_child(hazard)


func _decoration_at(spot: Vector2) -> Node3D:
	var node := Node3D.new()
	node.position = Vector3(spot.x, 0, spot.y)
	node.rotation.y = randf() * TAU
	_decorations.add_child(node)
	return node


func _random_scenery_spot(min_distance: float) -> Vector2:
	return Vector2.from_angle(randf() * TAU) * randf_range(min_distance, ARENA_RADIUS + 3.0)


func _mesh(mesh: PrimitiveMesh, material: Material, pos: Vector3) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	return instance


func _flicker_torches(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.0 + sin(_torch_time * 11.0 + i * 1.7) * 0.25 + sin(_torch_time * 23.0 + i) * 0.15
