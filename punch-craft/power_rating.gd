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
##
## Dead League contenders are rated with the same formula on the par build
## they're tuned for (Progression.par), so the two numbers compare directly.

## Weights: how much of your damage each conditional bonus usually touches
## (about 40% of punches are set-up heavies, 30% of a fight is finishing...).
const OFFENSE := {
	"heavy_bonus": 0.4, "counter_bonus": 0.13, "body_bonus": 0.15,
	"finisher_bonus": 0.3, "boss_damage": 0.3, "armor_pierce": 0.3,
	"last_stand": 0.35, "retaliation_bonus": 0.1, "opener_bonus": 0.13, "wise_up": 0.4,
	"shockwave_damage": 0.1, "boss_ko_bonus": 0.8,
	# Skill points feeding the equipped passive (Abilities): each passive
	# turns them into damage and staying power.
	"passive_power": 0.02,
}
const POWERS := {
	"fire_punch": 0.5, "burn": 0.4, "chain_lightning": 0.08, "frost_punch": 0.3,
	"ult_power": 0.25, "ult_gain": 0.3,
}
## Heals are percent of max knuckle HP (per kill, per milestone, per counter).
const DEFENSE := {
	"dodge_window": 0.6, "counter_window": 0.3, "graze_reduction": 0.3, "move_speed": 0.15,
	"flinch_reduction": 0.1, "free_punch_chance": 0.6, "heal_on_kill": 0.12, "wave_heal": 0.04,
	"counter_heal": 0.06, "fugget_heal": 0.6, "fugget_cut": 0.03, "counter_free_bonus": 0.2,
	"armor_charges": 0.08, "armor_recharge_cut": 0.02, "armor_absorb_reduction": 0.15,
	"passive_power": 0.025,
}
## Effect caps (GameState): only what actually applies counts.
const CAPS := {"dodge_window": 0.25, "counter_window": 0.5, "armor_pierce": 0.75}
const SPECIALS := [
	"venom", "serrated", "shatter", "lunging_jab", "spear_jab", "executioner", "rhythm",
	"glass_jaw", "blood_price", "bone_breaker", "chain_on_counter", "double_jab", "liver_shot",
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
	var specials := 0
	for key in SPECIALS:
		if float(fx.get(key, 0.0)) > 0.0:
			specials += 1
	return roundi(100.0 * sqrt(maxf(offense, 0.01) * maxf(defense, 0.01)) * (1.0 + SPECIAL_WORTH * specials))


## The current fighter: every stat, upgrade, skill, worn item and blessing.
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
		"combo_step": GameState.get_combo_step(), "effects": fx,
	})


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
	keys["damage_taken"] = true
	keys["crit_chance"] = true
	keys["crit_damage"] = true
	return keys.keys()
