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
	"archmage": [0.2, 0.0], "living_conduit": [0.1, 0.0], "elemental_body": [0.04, 0.03], "grand_unification": [0.06, 0.0],
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
	var fx: Dictionary = build.effects
	var offense: float = build.damage / 2.0 * build.punch_speed * (1.0 + 2.5 * build.combo_step) / FRESH_COMBO
	offense *= 1.0 + _weighted(fx, OFFENSE)
	# Crits: the chance (capped) times the extra they deal (x1.5 + crit damage).
	offense *= 1.0 + minf(fx.get("crit_chance", 0.0), 0.5) * (0.5 + fx.get("crit_damage", 0.0))
	offense *= 1.0 + _weighted(fx, POWERS)
	var defense: float = build.knuckles * (10.0 + build.defense) / 10.0 / 50.0 / (1.0 + maxf(fx.get("damage_taken", 0.0), -0.5))
	defense *= 1.0 + _weighted(fx, DEFENSE)
	var cards := _card_worth(fx, build.get("perks", []))
	offense *= 1.0 + cards.x
	defense *= 1.0 + cards.y
	var specials := 0
	for key in SPECIALS:
		if float(fx.get(key, 0.0)) > 0.0:
			specials += 1
	return roundi(100.0 * sqrt(maxf(offense, 0.01) * maxf(defense, 0.01)) * (1.0 + SPECIAL_WORTH * specials))


## The current fighter: every upgrade, card, attribute, worn item and blessing.
static func player() -> int:
	var fx := {}
	for key in _all_keys():
		var value := GameState.get_effect(key)
		if value != 0.0:
			fx[key] = value
	var passive_power := GameState.passive_power()
	if passive_power > 0.0:
		fx["passive_power"] = passive_power
	return rate({
		"damage": GameState.get_damage(), "knuckles": GameState.get_max_knuckles(),
		"defense": GameState.get_defense(), "punch_speed": GameState.get_punch_speed(),
		"combo_step": GameState.get_combo_step(), "effects": fx, "perks": PERKS.keys().filter(GameState.perk),
	})


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
static func contender(index: int) -> int:
	var par := Progression.par(index + 1)
	var fx: Dictionary = par.get("effects", {}).duplicate()
	var mods: Dictionary = GameState.CLASSES[GameState.player_class].get("mods", {})
	if mods.has("dodge_window"):
		fx["dodge_window"] = fx.get("dodge_window", 0.0) + mods.dodge_window - 1.0
	return rate({
		"damage": par.damage * mods.get("damage", 1.0), "knuckles": par.knuckles * mods.get("knuckles", 1.0),
		"defense": par.defense + mods.get("defense", 0.0),
		"punch_speed": (1.0 + fx.get("punch_speed", 0.0)) * mods.get("punch_speed", 1.0),
		"combo_step": (0.25 + fx.get("combo_step", 0.0)) * mods.get("combo_step", 1.0),
		"effects": fx,
	})


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
