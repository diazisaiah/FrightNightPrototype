class_name PowerRating
## One number for a whole build: POWER. A fresh fighter is 100.
##
##   POWER = 100 x sqrt(OFFENSE x DEFENSE) x (1 + 5% per special)
##
## OFFENSE (1.0 for a fresh fighter) multiplies:
##   damage per punch / 2            (stats, upgrades, gear, class, damage %)
##   punch speed
##   the average combo multiplier over a 6-hit string, vs. a fresh one
##   (1 + weighted conditional damage: heavies, counters, finishers, dash
##      punches, Berserk, Tony's duels, shockwaves... see OFFENSE)
##   powers: (1 + 0.5 fire + 0.4 burn + 0.08 per chain bolt + 0.3 frost
##      + 0.25 ult power + 0.3 ult charge)
## DEFENSE (1.0 fresh) multiplies:
##   effective knuckle HP / 50       (knuckles x (10 + defense) / 10)
##   / (1 + extra damage taken)
##   (1 + weighted defense and sustain: capped dodge/counter windows, graze
##      and flinch cuts, heals, free punches, super armor... see DEFENSE)
## Every special (thorns, venom, The Long Count, Bone Breaker ...) adds 5%.
## Cards (CARDS: offense and defense per unit of each card's effect, EVERY for
## "every Nth" cards) and attribute perks (PERKS) count too.
##
## Dead League contenders are rated with the same formula on the par build
## they're tuned for (Progression.par), so the two numbers compare directly.

## Weights: how much of your damage each conditional bonus usually touches
## (about 40% of punches are set-up heavies, 30% of a fight is finishing...).
const OFFENSE := {
	"heavy_bonus": 0.4, "counter_bonus": 0.13,
	"finisher_bonus": 0.3, "boss_damage": 0.3, "armor_pierce": 0.3,
	# Gear (2026-11-04): Iron Mike's set (elites and bosses), the Drowned
	# set (clean counters), and the combo cap (late combos).
	"elite_boss_damage": 0.35, "clean_counter_bonus": 0.05, "combo_cap": 0.15,
	"last_stand": 0.35,
	# Passive power (a point every few levels): each passive turns it into
	# damage and staying power.
	"passive_power": 0.02,
}
const POWERS := {
	"fire_punch": 0.5, "burn": 0.4, "chain_lightning": 0.08, "frost_punch": 0.3,
	# The Endless powers: Quake's shockwaves, Gale's bursts (after dodges),
	# Doom's stored share.
	"quake_power": 0.12, "quake_damage": 0.12, "gale": 0.3, "gale_damage": 0.3, "doom": 0.5,
	"ult_power": 0.25, "ult_gain": 0.3,
	# The Catalyst's Elemental Fists.
	"spell_time": 0.02,
}
## Heals are percent of max knuckle HP (per kill, per milestone, per counter).
const DEFENSE := {
	"dodge_window": 0.6, "counter_window": 0.3, "graze_reduction": 0.3, "move_speed": 0.15,
	"flinch_reduction": 0.1, "free_punch_chance": 0.6, "heal_on_kill": 0.12, "wave_heal": 0.04,
	"counter_heal": 0.06,
	# Iron: about two plates up on average.
	"plate_guard": 2.0,
	"passive_power": 0.025,
}
## Level-up cards (Cards): [offense, defense] for each unit of the effect. How
## often each one comes into play is baked in (Payback touches about one punch
## in seven, Mob Magnet about one and a half monsters...). Flags are worth
## their number once.
const CARDS := {
	# The Mauler.
	"payback": [0.15, 0.0], "hit_guard": [0.0, 1.0], "hit_ult": [0.01, 0.0], "mob_bonus": [1.5, 0.0],
	"no_flinch": [0.0, 0.1], "staggered_bonus": [0.25, 0.0], "cleave": [0.02, 0.0], "shoulder": [0.03, 0.01],
	"second_breath": [0.0, 0.25], "blood_feud": [0.12, 0.0], "strike": [0.05, 0.0], "red_mist": [0.1, 0.0],
	"inferno_ii": [0.04, 0.0], "brimstone_wall": [0.03, 0.03], "crowd_guard": [0.0, 2.0], "juggernaut": [0.0, 0.125],
	"ult_surge": [0.05, 0.03], "avalanche": [0.03, 0.03], "berserk": [0.06, 0.04],
	# The Answer.
	"closing": [0.07, 0.0], "exploit": [0.08, 0.0], "sting_delay": [0.0, 0.15], "counter_ult": [0.08, 0.0],
	"two_answers": [0.06, 0.0], "turnabout": [0.04, 0.05], "read_twice": [0.02, 0.0], "return_sender": [0.01, 0.0],
	"crowd_reader": [0.0, 0.15], "checkmate": [0.1, 0.0], "ghost_walk": [0.03, 0.04], "stored_answers": [0.12, 0.0],
	"riposte_ii": [0.04, 0.03], "untouchable_flow": [0.0, 0.06], "free_flow": [0.06, 0.0], "mirror_match": [0.0, 0.06],
	"last_word": [0.06, 0.0],
	# The Blur.
	"second_gear": [0.7, 0.0], "bounce_back": [0.1, 0.0], "speed_bag": [0.3, 0.0],
	"ricochet": [0.03, 0.0], "afterimage": [0.03, 0.0], "light_hands": [0.0, 0.25], "light_hooks": [0.0, 0.05], "aftershock": [0.08, 0.03],
	"double_echo": [0.08, 0.0], "spear_hands": [0.08, 0.04], "temporal_break_ii": [0.05, 0.0], "unbroken_ii": [0.05, 0.0],
	"flurry": [0.06, 0.0], "perpetual_motion": [0.06, 0.0], "blur": [0.03, 0.08], "fifty": [0.04, 0.04],
	# The Stray.
	"dash_reach": [0.0, 0.1], "cheap_shot": [0.25, 0.0], "hang_time": [0.15, 0.0], "opportunist": [0.3, 0.0],
	"vault": [0.03, 0.02], "blindside": [0.03, 0.0], "ghost_step": [0.0, 0.04], "slick": [0.0, 0.05],
	"spear_line": [0.08, 0.0], "bounce_house": [0.06, 0.0], "full_tilt": [0.1, 0.0], "directors_cut": [0.05, 0.0],
	"express": [0.04, 0.0], "high_ground": [0.15, 0.0], "parkour": [0.03, 0.04], "never_where": [0.0, 0.08],
	"free_running": [0.08, 0.0],
	# Tony.
	# Enraged monsters take double from Tony (and hit him harder).
	"insult_time": [0.02, 0.0], "below_belt": [0.2, 0.0], "first_punch": [0.1, 0.0], "shrug_rage": [0.05, -0.03],
	"bada_bing": [0.03, 0.0], "made_man": [0.0, 0.03], "vinnie_bonus": [0.08, 0.0], "wake_up_call": [0.02, 0.03],
	"fuggedaboudit_ii": [0.0, 0.1], "whole_crew": [0.05, 0.04], "skim": [0.02, 0.0], "big_mouth_ii": [0.06, 0.0],
	"family_reunion": [0.05, 0.0], "last_word_tony": [0.0, 0.05], "untouchable_tony": [0.0, 0.1], "respect": [0.04, 0.0],
	"capo": [0.04, 0.0],
	# The Catalyst.
	"conduit": [0.3, 0.0], "afterglow": [0.3, 0.0], "resonance": [0.04, 0.0], "overflow": [0.06, 0.0],
	"ward": [0.0, 2.0], "focus": [0.4, 0.0], "twin_cast": [0.3, 0.0], "sigil_weave": [0.08, 0.0],
	"deep_attunement": [0.08, 0.0], "spectrum": [0.1, 0.0], "elemental_fists_ii": [0.06, 0.0], "flame_burst_ii": [0.06, 0.0],
	"archmage": [0.2, 0.0], "living_conduit": [0.5, 0.0], "elemental_body": [0.04, 0.03], "grand_unification": [0.06, 0.0],
}
## "Every Nth" cards (the smaller N, the better): [offense, defense] x 1/N.
const EVERY := {
	"thousand_fists": [1.2, 0.0], "rhythm_guard": [0.0, 0.4], "say_it": [1.2, -0.3], "runic_wraps": [0.9, 0.0],
}
## Attribute perks (Attributes): [offense, defense] each. Fortune's are worth
## no fighting power.
const PERKS := {
	"heavy_hands": [0.03, 0.02], "follow_through": [0.04, 0.0], "knockout_blow": [0.12, 0.0],
	"iron_knuckles": [0.0, 0.05], "granite_chin": [0.0, 0.08], "get_up": [0.0, 0.1],
	"quick_feet": [0.0, 0.03], "tempo": [0.08, 0.0], "blur_step": [0.05, 0.02],
	"read_the_tell": [0.0, 0.06], "clean_break": [0.02, 0.04], "precision": [0.06, 0.0],
}
## Effect caps (GameState): only what actually applies counts.
const CAPS := {"dodge_window": 0.25, "counter_window": 0.5, "armor_pierce": 0.75}
const SPECIALS := [
	"venom", "serrated", "shatter", "lunging_jab", "spear_jab", "executioner", "rhythm",
	"glass_jaw", "blood_price", "bone_breaker", "chain_on_counter",
	"jump_bonus", "pyre", "thunderhead", "bloodbath", "ground_pound", "perfect_any_punch", "dive_kick",
	"thorns", "iron_will", "grit", "long_count", "slipknot", "gravewalker",
	"frost_slip", "clean_read", "lantern",
	# Gear signatures (2026-11-04).
	"champions_hands", "mid_roll", "double_jab", "frenzy", "gold_fever", "loaded_dice", "silver_tongue", "haggler",
]
const SPECIAL_WORTH := 0.05
## A fresh fighter's average combo multiplier over 6 hits (0.25 per hit).
const FRESH_COMBO := 1.0 + 2.5 * 0.25

## Readiness by your POWER over the contender's: [below this ratio, word, color].
const VERDICTS := [
	[0.7, "OUTMATCHED"], [0.88, "UNDERPOWERED"], [0.97, "CLOSE"], [1.15, "READY"], [INF, "OVERPOWERED"],
]


## build: {damage, knuckles, defense, punch_speed, combo_step, effects: {effect: total}}.
static func rate(build: Dictionary) -> int:
	var worth := split(build)
	var specials := 0
	for key in SPECIALS:
		if float(build.effects.get(key, 0.0)) > 0.0:
			specials += 1
	return roundi(100.0 * sqrt(maxf(worth.x, 0.01) * maxf(worth.y, 0.01)) * (1.0 + SPECIAL_WORTH * specials))


## A build's (offense, defense): how fast it kills and how much it takes.
static func split(build: Dictionary) -> Vector2:
	var fx: Dictionary = build.effects
	var offense: float = build.damage / 2.0 * build.punch_speed * (1.0 + 2.5 * build.combo_step) / FRESH_COMBO
	offense *= 1.0 + _weighted(fx, OFFENSE)
	# Crits: the chance (capped) times the extra they deal (x1.5 + crit damage).
	offense *= 1.0 + minf(fx.get("crit_chance", 0.0), 0.5) * (0.5 + fx.get("crit_damage", 0.0))
	offense *= 1.0 + _weighted(fx, POWERS)
	var defense: float = Progression.effective_hp(build.knuckles, build.defense) / 50.0 / (1.0 + maxf(fx.get("damage_taken", 0.0), -0.5))
	# The Mauler's perk: the last cut on every hit, past the caps.
	defense /= float(build.get("final_damage", 1.0))
	# Deadweight's set bonus cuts every hit.
	defense /= 1.0 - minf(fx.get("set_damage_reduction", 0.0), Gear.MAX_DAMAGE_REDUCTION)
	defense *= 1.0 + _weighted(fx, DEFENSE)
	var cards := _card_worth(fx, build.get("perks", []))
	return Vector2(offense * (1.0 + cards.x), defense * (1.0 + cards.y))


## The current fighter: every upgrade, card, attribute, worn item and blessing.
static func player() -> int:
	return rate(player_build())


static func player_build() -> Dictionary:
	var fx := {}
	for key in _all_keys():
		var value := GameState.get_effect(key)
		if value != 0.0:
			fx[key] = value
	var passive_power := GameState.passive_power()
	if passive_power > 0.0:
		fx["passive_power"] = passive_power
	_add_class_fx(fx, GameState.class_mods(GameState.player_class))
	return {
		"damage": GameState.get_damage(), "knuckles": GameState.get_max_knuckles(),
		"defense": GameState.get_defense(), "punch_speed": GameState.get_punch_speed(),
		"combo_step": GameState.get_combo_step(), "effects": fx, "perks": PERKS.keys().filter(GameState.perk),
		"final_damage": GameState.get_class_mod("final_damage"),
	}


## The star and perk numbers that live outside damage, knuckles, defense and
## punch speed, as effects POWER weighs: dodge window, move speed, and the
## counter scale (as counter bonus on the base x2 counter).
static func _add_class_fx(fx: Dictionary, mods: Dictionary) -> void:
	if mods.has("dodge_window"):
		fx["dodge_window"] = fx.get("dodge_window", 0.0) + float(mods.dodge_window) - 1.0
	if mods.has("move"):
		fx["move_speed"] = fx.get("move_speed", 0.0) + float(mods.move) - 1.0
	if mods.has("counter_scale"):
		fx["counter_bonus"] = fx.get("counter_bonus", 0.0) + Player.COUNTER_MULTIPLIER * (float(mods.counter_scale) - 1.0)


## A maxed fighter's (offense, defense) over what the True Coffin King's
## base numbers are built for (Progression.true_par). The playground measures
## DeadLeagueBoss.TRUE_MAXED with it; balance_regression keeps them in step.
static func maxed_over_true_par() -> Vector2:
	var mine := split(player_build())
	var theirs := split(_par_as_player(Progression.true_par()))
	return Vector2(mine.x / maxf(theirs.x, 0.01), mine.y / maxf(theirs.y, 0.01))


## What cards and perks add: (offense, defense) shares.
static func _card_worth(fx: Dictionary, perks: Array) -> Vector2:
	var worth := Vector2.ZERO
	for key in CARDS:
		var value := float(fx.get(key, 0.0))
		if value != 0.0:
			worth += Vector2(CARDS[key][0], CARDS[key][1]) * value
	for key in EVERY:
		var every := float(fx.get(key, 0.0))
		if every > 0.0:
			worth += Vector2(EVERY[key][0], EVERY[key][1]) / every
	for perk in perks:
		if PERKS.has(perk):
			worth += Vector2(PERKS[perk][0], PERKS[perk][1])
	return worth


## Contender index i (0-4): the par build for its tier, as your class (its
## built-in bonuses and drawbacks count on both sides, so the comparison is
## about your build, not which fighter you picked).
## (2026-11-03: shows its POWER target exactly, the same class-neutral scale
## as the Arena and Crypt recommendations.)
static func contender(index: int) -> int:
	return CONTENDER_POWER[clampi(index, 0, CONTENDER_POWER.size() - 1)]


## Contender i before the power shift, rated as your class: its par build.
static func contender_unshifted(index: int) -> int:
	return rate(_par_as_player(Progression.par(index + 1)))


## The power shift (2026-11-03, the Rebalance plan's boss power targets):
## contenders sit at CONTENDER_POWER (x2.3 a tier) instead of their par's own
## rating, and Crypt floor bosses at crypt_boss_power. A boss's HP and damage both take the shift, so its POWER
## (sqrt of offense x defense) moves by exactly that much.
## 2026-11-03 (second pass): the Bellman 850 -> 500 and Crypt floors 1-2
## 1,105 -> 650; the first pass was too steep.
## 2026-11-03 (defense rework): POWER's scale moved with the armor formula
## (par's effective HP is 1.4-1.6x its knuckles, not up to 5x), so the
## targets are the plan's x2.3 a tier again, from the Bellman's 500.
const CONTENDER_POWER := [500, 1150, 2645, 6084, 13993]
## Floor 10's boss: one more x2.3 step over the Coffin King (the endless floors
## grow from it).
const FINAL_BOSS_OVER_KING := 2.3
## Crypt floor bosses (2026-11-03, defense rework): as strong as the
## contender who opened their floors (CRYPT_BOSS_OVER_CONTENDER x); a floor
## recommends its rooms on top (floors 1-2 about 600 after the Bellman's 500).
const CRYPT_BOSS_OVER_CONTENDER := 1.0
## A Grave Champion's share of its bout's recommendation (from the Bone
## Division on); the bout's monsters get the rest.
const CHAMPION_SHARE := 0.5
static var _neutral_cache := {}
## Boss base stats on the contenders' scale (2026-11-03): [HP, damage] a boss
## kind is built from before scaling (a contender's profile is 52-134 HP and
## 4.6-8.1 damage). The scenes' own numbers (500-650 HP) made Grave
## Champions and Crypt floor bosses take 300-700 punches.
const ARENA_CHAMPION_UNIT := [40.0, 4.6]
const CRYPT_BOSS_UNITS := {"boss": [60.0, 5.0], "colossus": [75.0, 6.0], "lich_king": [65.0, 5.0]}


## Scaling multipliers that put a boss's scene stats on its unit: {hp, damage}.
static func boss_unit_scale(enemy: Enemy, unit: Array) -> Dictionary:
	var base_damage: float = enemy.get("attack_damage") if enemy.get("attack_damage") != null else float(enemy.get("bolt_damage"))
	return {"hp": unit[0] / maxf(enemy.max_hp, 1.0), "damage": unit[1] / maxf(base_damage, 0.01)}


## Contender i's HP and damage multiplier.
static func contender_shift(index: int) -> float:
	index = clampi(index, 0, CONTENDER_POWER.size() - 1)
	return CONTENDER_POWER[index] / maxf(neutral_par_power(index + 1), 1.0)


## A Crypt floor boss's HP and damage multiplier: its tier's target over what
## the monsters it's built from (Progression.par_at(difficulty)) are worth.
static func crypt_boss_shift(floor_number: int, difficulty: float) -> float:
	var unshifted := climb_power(minf(difficulty, Progression.TIER_COUNT))
	return crypt_floor_boss_power(floor_number) / maxf(unshifted, 1.0)


## A floor's boss POWER: its tier's, or floor 10's finale (and the endless
## floors after it) FINAL_BOSS_OVER_KING x the Coffin King.
static func crypt_floor_boss_power(floor_number: int) -> float:
	if floor_number >= Progression.crypt_last_floor():
		return FINAL_BOSS_OVER_KING * CONTENDER_POWER[-1]
	return crypt_boss_power(_crypt_tier(floor_number))


## A Crypt tier's floor boss POWER: the contender who opened its floors.
static func crypt_boss_power(tier: int) -> float:
	return CRYPT_BOSS_OVER_CONTENDER * CONTENDER_POWER[clampi(tier, 1, CONTENDER_POWER.size()) - 1]


static func _crypt_tier(floor_number: int) -> int:
	return clampi(ceili(clampi(floor_number, 1, Progression.crypt_last_floor()) / float(Progression.FLOORS_PER_TIER)), 1, CONTENDER_POWER.size())


## Recommended POWER for an Arena bout or Crypt floor (2026-11-03): you
## fight every monster in a row, in groups, then the boss. So it's the POWER
## of every spawn added up (GROUP_SIZE of them count as one fight) plus the
## boss's. A spawn is worth what it's built from (climb_power) times its
## weight against a plain zombie: its kind's HP and damage (veterans by the
## tier's share), growth, armor, elites and champions.
const GROUP_SIZE := 35.0
## [HP, damage] of each monster and its veteran (mirrors the scenes; the
## zombie is the 1.0 reference).
const MONSTERS := {
	"zombie": [20.0, 6.0], "skeleton": [14.0, 5.0], "runner": [18.0, 7.0], "hulk": [60.0, 12.0],
	"brawler": [40.0, 6.0], "mage": [16.0, 6.0], "priest": [22.0, 6.0], "armor": [45.0, 11.0],
	"shieldbearer": [50.0, 9.0], "wraith": [34.0, 8.0], "lich": [70.0, 8.0],
}
const VETERAN_MONSTERS := {
	"zombie": [55.0, 8.0], "skeleton": [22.0, 6.0], "runner": [26.0, 8.0], "hulk": [110.0, 10.0],
	"brawler": [62.0, 7.5], "mage": [26.0, 8.5], "shieldbearer": [75.0, 10.5], "wraith": [50.0, 9.5],
}
## Weight of an armored spawn (about double the HP to chew through), an elite
## (x2 HP and a trait) and a champion (x3.5 HP and two traits).
const ARMORED_WEIGHT := 1.4
const ELITE_WEIGHT := 1.6
const CHAMPION_WEIGHT := 2.3
static var _arena_cache := {}


## Arena divisions build up to their contender (2026-11-03): from the Bone
## Division on, bout 1 recommends the contender you just beat and bout 3 this
## division's, geometric between. The Gravedigger keeps its own climb (to
## about the Bellman). arena_shift scales the bout's monsters and Grave
## Champion (HP and damage) to get there.
static func arena_power(division: int, bout: int) -> int:
	if division <= 1:
		return roundi(arena_power_unshifted(division, bout))
	return roundi(arena_target(division, bout))


## A bout's target from the Bone Division on.
static func arena_target(division: int, bout: int) -> float:
	var low := float(CONTENDER_POWER[clampi(division - 2, 0, CONTENDER_POWER.size() - 1)])
	var high := float(CONTENDER_POWER[clampi(division - 1, 0, CONTENDER_POWER.size() - 1)])
	var steps := float(Progression.BOUTS_PER_DIVISION - 1)
	return low * pow(high / low, clampf((bout - 1) / steps, 0.0, 1.0))


## The bout's monsters' HP and damage multiplier: they fill what the Grave
## Champion (CHAMPION_SHARE) leaves of the target.
static func arena_shift(division: int, bout: int) -> float:
	if division <= 1:
		return 1.0
	arena_power_unshifted(division, bout)
	return (1.0 - CHAMPION_SHARE) * arena_target(division, bout) / maxf(_arena_cache["mobs%d_%d" % [division, bout]], 1.0)


## The Grave Champion's HP and damage multiplier: CHAMPION_SHARE of the target.
static func arena_champion_shift(division: int, bout: int) -> float:
	if division <= 1:
		return 1.0
	arena_power_unshifted(division, bout)
	return CHAMPION_SHARE * arena_target(division, bout) / maxf(_arena_cache["champ%d_%d" % [division, bout]], 1.0)


## A bout's recommendation from its monsters as they're built (no shift).
static func arena_power_unshifted(division: int, bout: int) -> float:
	var key := "raw%d_%d" % [division, bout]
	if _arena_cache.has(key):
		return _arena_cache[key]
	var world: GDScript = load("res://world.gd")
	var base := climb_power(Progression.arena_difficulty(division, bout))
	var first_night := division == 1 and bout == 1
	var types: Dictionary = world.ENEMY_TYPES
	if first_night:
		types = {}
		for kind in world.FIRST_NIGHT.types:
			types[kind] = world.ENEMY_TYPES[kind]
	var kills: int = world.FIRST_NIGHT.kills if first_night else world.KILLS_TO_BOSS
	var total := 0.0
	for i in kills:
		var progress := (i + 0.5) / kills
		var spawn := _kind_weight(types, progress, 0.0 if first_night else Veterans.share(division))
		spawn *= sqrt((1.0 + world.HP_GROWTH * progress) * (1.0 + world.DAMAGE_GROWTH * progress))
		if first_night:
			spawn *= sqrt(world.FIRST_NIGHT.hp * world.FIRST_NIGHT.damage)
		else:
			spawn *= lerpf(1.0, ARMORED_WEIGHT, clampf((progress - world.ARMOR_START) * world.ARMOR_RATE, 0.0, world.MAX_ARMOR_CHANCE))
			spawn *= 1.0 + world.ELITE_CHANCE[division - 1] * (ELITE_WEIGHT - 1.0) + world.CHAMPION_CHANCE[division - 1] * (CHAMPION_WEIGHT - 1.0)
		total += spawn
	var boss := base * (sqrt(world.FIRST_NIGHT.boss_hp * world.FIRST_NIGHT.boss_damage) if first_night else 1.0)
	_arena_cache["mobs%d_%d" % [division, bout]] = base * total / GROUP_SIZE
	_arena_cache["champ%d_%d" % [division, bout]] = boss
	_arena_cache[key] = base * total / GROUP_SIZE + boss
	return _arena_cache[key]


## Recommended POWER for a Crypt floor, starting a run on start_floor (the
## floor itself when not given): its four fight rooms (3 + depth + a monster
## a floor each, one elite) as a group, plus its boss (crypt_boss_power). The
## endless floors grow both like the monsters do.
static func crypt_power(floor_number: int, start_floor := -1) -> int:
	if start_floor < 0:
		start_floor = floor_number
	var boss: float = crypt_floor_boss_power(floor_number) * Progression.crypt_endless_growth(floor_number, 1.0)
	return roundi(_crypt_rooms(floor_number, start_floor) + boss)


## A Crypt floor's rooms as one group's POWER.
static func _crypt_rooms(floor_number: int, start_floor: int) -> float:
	var dungeon: GDScript = load("res://dungeon.gd")
	var world: GDScript = load("res://world.gd")
	var types: Dictionary = world.ENEMY_TYPES.duplicate()
	types.merge(dungeon.CRYPT_ENEMY_TYPES)
	var veteran_share := Veterans.share(ceili(floor_number / float(Progression.FLOORS_PER_TIER)))
	var total := 0.0
	for depth in range(1, dungeon.MAIN_ROOMS - 1):
		var along := float(depth - 1) / maxf(1.0, dungeon.MAIN_ROOMS - 3)
		var progress := clampf(along * dungeon.FLOOR_PROGRESS_SPAN + dungeon.FLOOR_PROGRESS_STEP * (floor_number - 1), 0.0, 1.0)
		var base := climb_power(Progression.crypt_difficulty(floor_number, start_floor, progress)) * Progression.crypt_endless_growth(floor_number, progress)
		var spawn := _kind_weight(types, progress, veteran_share)
		spawn *= lerpf(1.0, ARMORED_WEIGHT, clampf((progress - 0.1) * 0.8, 0.0, 0.6))
		var count := mini(dungeon.ROOM_ENEMIES_BASE + depth + dungeon.ROOM_ENEMIES_PER_FLOOR * (floor_number - 1), dungeon.ROOM_ENEMIES_MAX)
		total += base * spawn * count
		if depth == dungeon.ELITE_MIN_DEPTH:
			total += base * spawn * (ELITE_WEIGHT - 1.0)  # The floor's elite.
	return total / GROUP_SIZE


## The average weight of a spawn from these types at this progress (by their
## spawn weights), veterans mixed in by their share.
static func _kind_weight(types: Dictionary, progress: float, veteran_share: float) -> float:
	var kind_total := 0.0
	var weight_total := 0.0
	for kind in types:
		var entry: Dictionary = types[kind]
		if float(entry.unlock) > progress or not MONSTERS.has(kind):
			continue
		var weight := _monster_weight(MONSTERS[kind])
		if VETERAN_MONSTERS.has(kind):
			weight = lerpf(weight, _monster_weight(VETERAN_MONSTERS[kind]), veteran_share)
		kind_total += float(entry.weight) * weight
		weight_total += float(entry.weight)
	return kind_total / maxf(weight_total, 0.001)


static func _monster_weight(stats: Array) -> float:
	return sqrt(stats[0] / MONSTERS.zombie[0] * stats[1] / MONSTERS.zombie[1])


## One monster's POWER, as the Fancy Bluetooth Headpiece reads it (Scouter):
## how its HP and hit compare with a fresh zombie's (20 HP, 6 a hit: a fresh
## fighter's POWER), square-rooted like POWER is. Bosses that carry their own
## ("power": contenders, Crypt floor bosses) read that.
static func monster_power(enemy: Enemy) -> int:
	if enemy.has_meta("power"):
		return roundi(float(enemy.get_meta("power")))
	var hit := float(MONSTERS.zombie[1])
	var base = enemy.get("attack_damage")
	if base != null:
		hit = float(base)
	hit *= enemy.damage_multiplier
	var tough := sqrt(maxf(enemy.max_hp, 1.0) / MONSTERS.zombie[0] * maxf(hit, 0.1) / MONSTERS.zombie[1])
	return roundi(neutral_par_power(0) * tough)


## Par's POWER at tier t with no class (0 = a fresh fighter).
static func neutral_par_power(tier: int) -> float:
	if not _neutral_cache.has(tier):
		var par: Dictionary = Progression.par(tier)
		var fx: Dictionary = par.get("effects", {})
		_neutral_cache[tier] = float(rate({"damage": par.damage, "knuckles": par.knuckles, "defense": par.defense,
			"punch_speed": 1.0 + fx.get("punch_speed", 0.0), "combo_step": 0.25 + fx.get("combo_step", 0.0), "effects": fx}))
	return _neutral_cache[tier]


## Par's POWER at climb position x (0-5), geometric between tiers.
static func climb_power(x: float) -> float:
	x = clampf(x, 0.0, Progression.TIER_COUNT)
	var low := floori(x)
	var high := mini(low + 1, Progression.TIER_COUNT)
	var a := neutral_par_power(low)
	var b := neutral_par_power(high)
	return a * pow(b / maxf(a, 1.0), x - low)


## A par build (Progression.par) as the current fighter would have it.
static func _par_as_player(par: Dictionary) -> Dictionary:
	var fx: Dictionary = par.get("effects", {}).duplicate()
	var mods: Dictionary = GameState.class_mods(GameState.player_class)
	_add_class_fx(fx, mods)
	# The Catalyst's perk on his power numbers (the player's own effects
	# already carry it, through GameState.get_effect).
	for key in GameState.POWER_DAMAGE:
		if fx.has(key):
			fx[key] = float(fx[key]) * float(mods.get("power_damage", 1.0))
	return {
		"damage": par.damage * mods.get("damage", 1.0), "knuckles": par.knuckles * mods.get("knuckles", 1.0),
		"defense": (par.defense + mods.get("defense", 0.0)) * mods.get("defense_scale", 1.0),
		"punch_speed": (1.0 + fx.get("punch_speed", 0.0)) * mods.get("punch_speed", 1.0),
		"combo_step": (0.25 + fx.get("combo_step", 0.0)) * mods.get("combo_step", 1.0),
		"effects": fx, "final_damage": mods.get("final_damage", 1.0),
	}


## [word, ratio] for your POWER against a contender's.
static func verdict(mine: int, theirs: int) -> Array:
	var ratio := float(mine) / maxf(theirs, 1.0)
	for entry in VERDICTS:
		if ratio < entry[0]:
			return [entry[1], ratio]
	return [VERDICTS[-1][1], ratio]


static func _weighted(fx: Dictionary, weights: Dictionary) -> float:
	var total := 0.0
	for key in weights:
		total += minf(float(fx.get(key, 0.0)), CAPS.get(key, INF)) * weights[key]
	return total


static func _all_keys() -> Array:
	var keys := {}
	for table in [OFFENSE, POWERS, DEFENSE]:
		for key in table:
			keys[key] = true
	for key in SPECIALS:
		keys[key] = true
	for table in [CARDS, EVERY]:
		for key in table:
			keys[key] = true
	keys["damage_taken"] = true
	keys["crit_chance"] = true
	keys["crit_damage"] = true
	return keys.keys()
