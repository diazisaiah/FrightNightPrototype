class_name Gear
## The Crypt's gear (Crypt revamp plan, built 2026-11-04): 5 sets x 4 pieces
## (gloves, wraps, boots, charm), the only Crypt items. An item is
## {gear, set, slot, rarity, level, name, effects, floor} plus the usual uid /
## found / gilded; its effects come from (set, slot, rarity, level) and are
## rebuilt whenever its level changes (refresh).
##
## - Every piece has 5 stats unlocked in order: common 1, uncommon 1-2, rare
##   1-3, epic 1-4, legendary 1-5. Stat 5 is its signature (SIG), which
##   doesn't scale. Rarity never boosts a number.
## - Value = base x growth^(level - 1); past level 30 the growth halves at 31
##   and again at 35, 40, 45 ... (stats top out near 2x their level-30 value).
## - A drop's level is in its floor's range ((floor - 1) x 3 + 1 to floor x 3,
##   both rising 1 a floor past 10).
## - Only the 4-piece set bonus exists, at the lowest rarity of the four.
## - Stats add up across worn pieces, so sets can be mixed for a stat.
## The 3D look of each piece is ItemModels.

const SLOTS := ["gloves", "wraps", "boots", "charm"]
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
## [base, growth per level] (the plan's table; game units: dodge_window is a
## share of the window, counter / combo windows are seconds).
const STATS := {
	"damage": [3.0, 1.15], "damage_percent": [0.06, 1.093], "crit_chance": [0.03, 1.088],
	"heavy_bonus": [0.06, 1.076], "head_bonus": [0.08, 1.091], "counter_bonus": [0.08, 1.078],
	"boss_damage": [0.08, 1.078], "finisher_bonus": [0.08, 1.091], "armor_pierce": [0.04, 1.072],
	"punch_speed": [0.03, 1.068], "max_knuckles": [15.0, 1.13], "defense": [10.0, 1.098],
	"heal_on_kill": [1.0, 1.109], "graze_reduction": [0.04, 1.072], "flinch_reduction": [0.04, 1.072],
	"free_punch_chance": [0.02, 1.072], "move_speed": [0.05, 1.083], "sprint_bonus": [0.05, 1.083],
	"jump_bonus": [0.04, 1.072], "dodge_window": [0.03, 1.04], "counter_window": [0.02, 1.03],
	"combo_window": [0.05, 1.05], "combo_step": [0.01, 1.05], "combo_cap": [0.05, 1.083],
	"coin_bonus": [0.06, 1.091], "xp_bonus": [0.06, 1.091], "ult_gain": [0.03, 1.076],
}
## Each piece's four stats, in the order rarity unlocks them.
const PIECES := {
	"deadweight": {
		"gloves": ["heavy_bonus", "damage", "armor_pierce", "flinch_reduction"],
		"wraps": ["max_knuckles", "defense", "graze_reduction", "flinch_reduction"],
		"boots": ["max_knuckles", "defense", "move_speed", "sprint_bonus"],
		"charm": ["heal_on_kill", "max_knuckles", "defense", "coin_bonus"],
	},
	"drowned": {
		"gloves": ["counter_bonus", "damage", "crit_chance", "head_bonus"],
		"wraps": ["defense", "graze_reduction", "heal_on_kill", "max_knuckles"],
		"boots": ["dodge_window", "counter_window", "move_speed", "sprint_bonus"],
		"charm": ["combo_window", "xp_bonus", "finisher_bonus", "combo_cap"],
	},
	"grandmaster": {
		"gloves": ["punch_speed", "damage_percent", "crit_chance", "combo_cap"],
		"wraps": ["free_punch_chance", "combo_cap", "max_knuckles", "flinch_reduction"],
		"boots": ["move_speed", "sprint_bonus", "dodge_window", "combo_cap"],
		"charm": ["combo_step", "combo_window", "combo_cap", "xp_bonus"],
	},
	"iron_mike": {
		"gloves": ["finisher_bonus", "boss_damage", "damage_percent", "armor_pierce"],
		"wraps": ["max_knuckles", "defense", "boss_damage", "heal_on_kill"],
		"boots": ["move_speed", "counter_window", "jump_bonus", "sprint_bonus"],
		"charm": ["finisher_bonus", "boss_damage", "ult_gain", "xp_bonus"],
	},
	"dead_money": {
		"gloves": ["head_bonus", "crit_chance", "damage", "coin_bonus"],
		"wraps": ["max_knuckles", "heal_on_kill", "coin_bonus", "defense"],
		"boots": ["sprint_bonus", "move_speed", "jump_bonus", "xp_bonus"],
		"charm": ["coin_bonus", "xp_bonus", "combo_window", "ult_gain"],
	},
}
## Legendary only: each piece's signature [effect, value] (fixed).
const SIGS := {
	"deadweight": {"gloves": ["shatter", 0.5], "wraps": ["thorns", 1.5], "boots": ["grit", 0.3], "charm": ["iron_will", 1.0]},
	"drowned": {"gloves": ["champions_hands", 1.0], "wraps": ["slipknot", 0.5], "boots": ["clean_read", 4.0], "charm": ["rhythm", 0.15]},
	"grandmaster": {"gloves": ["lunging_jab", 0.6], "wraps": ["mid_roll", 1.0], "boots": ["double_jab", 1.0], "charm": ["frenzy", 1.0]},
	"iron_mike": {"gloves": ["bone_breaker", 0.5], "wraps": ["long_count", 1.0], "boots": ["gravewalker", 0.25], "charm": ["executioner", 0.25]},
	"dead_money": {"gloves": ["gold_fever", 0.05], "wraps": ["loaded_dice", 3.0], "boots": ["silver_tongue", 0.25], "charm": ["haggler", 0.1]},
}
## The 4-piece bonus: effects, each with a value per rarity (common to
## legendary), at the lowest rarity of the four.
const SET_BONUS := {
	"deadweight": {"set_damage_reduction": [0.03, 0.05, 0.07, 0.10, 0.14]},
	"drowned": {"clean_counter_bonus": [0.05, 0.08, 0.12, 0.16, 0.20]},
	"grandmaster": {"punch_speed": [0.03, 0.05, 0.08, 0.12, 0.16]},
	"iron_mike": {"elite_boss_damage": [0.05, 0.08, 0.12, 0.16, 0.20]},
	"dead_money": {"coin_bonus": [0.10, 0.15, 0.20, 0.30, 0.40], "xp_bonus": [0.10, 0.15, 0.20, 0.30, 0.40]},
}
## Every effect a set bonus can grant (GameState only looks these up).
const BONUS_EFFECTS := ["set_damage_reduction", "clean_counter_bonus", "punch_speed", "elite_boss_damage", "coin_bonus", "xp_bonus"]
## Damage-taken cuts (the set bonus, Grit, Gravewalker ...) share this cap.
const MAX_DAMAGE_REDUCTION := 0.75
## Drop odds by climb tier (two floors a tier; 6 = the endless floors), in
## RARITIES order. Boss and elite chests roll this, then go up one rarity.
const DROP_ODDS := [
	[70, 20, 6, 3, 1], [60, 25, 8, 5, 2], [45, 30, 15, 6, 4],
	[25, 30, 25, 12, 8], [10, 20, 40, 20, 10], [0, 10, 50, 25, 15],
]
## Economy, by rarity (common to legendary).
const SALVAGE_SILVER := [2, 5, 8, 12, 20]
const MERCHANT_SILVER := [10, 25, 40, 60, 100]
const SHOP_SOULS := [5, 13, 20, 30, 50]
## Gilded gear sells outside the Crypt for this x level^3 x rarity^1.5 gold
## (rarity 1-5); past level 30 each level adds 5% of the level-30 price.
const SELL_SCALE := 3.31


static func is_gear(item: Dictionary) -> bool:
	return item.has("gear") and PIECES.has(item.get("set", ""))


static func rarity_index(rarity: String) -> int:
	return maxi(0, RARITIES.find(rarity))


# --- Numbers ----------------------------------------------------------------------

## A stat's value at a level.
static func value(stat: String, level: int) -> float:
	var spec: Array = STATS[stat]
	var base: float = spec[0]
	var growth: float = spec[1]
	var top := mini(level, 30)
	var v := base * pow(growth, top - 1)
	# Past 30 the growth portion halves at 31, and again at 35, 40, 45 ...
	for n in range(31, level + 1):
		var halvings := 1 + floori((n - 30) / 5.0)
		v *= 1.0 + (growth - 1.0) * pow(0.5, halvings)
	return v


## The piece's effects at its rarity and level: its unlocked stats, and its
## signature on a legendary.
static func effects(set_id: String, slot: String, rarity: String, level: int) -> Dictionary:
	var out := {}
	var unlocked := rarity_index(rarity) + 1
	var stats: Array = PIECES[set_id][slot]
	for i in mini(unlocked, stats.size()):
		var stat: String = stats[i]
		out[stat] = float(out.get(stat, 0.0)) + _snap(stat, value(stat, level))
	if unlocked >= 5:
		var sig: Array = SIGS[set_id][slot]
		out[sig[0]] = sig[1]
	return out


static func _snap(stat: String, v: float) -> float:
	if stat in ["damage", "max_knuckles", "defense", "heal_on_kill"]:
		return snappedf(v, 0.1)
	return snappedf(v, 0.001)


## A floor's drop levels [low, high].
static func level_range(floor_number: int) -> Vector2i:
	if floor_number <= 10:
		return Vector2i((floor_number - 1) * 3 + 1, floor_number * 3)
	return Vector2i(28 + floor_number - 10, 30 + floor_number - 10)


## The climb tier a floor's drops use (1-6; 6 is the endless floors).
static func tier(floor_number: int) -> int:
	return clampi(ceili(floor_number / 2.0), 1, DROP_ODDS.size())


## How high gear can be leveled in the store: the highest floor beaten x 3,
## +1 a floor past 10.
static func level_cap() -> int:
	var cleared := GameState.crypt_floors_cleared
	return mini(cleared, 10) * 3 + maxi(0, cleared - 10)


## Souls to take a piece up one level: half its level, rounded up (at least 1).
static func level_up_cost(item: Dictionary) -> int:
	return maxi(1, ceili(int(item.get("level", 1)) / 2.0))


static func salvage_silver(item: Dictionary) -> int:
	return SALVAGE_SILVER[rarity_index(item.get("rarity", "common"))]


static func merchant_price(item: Dictionary) -> int:
	return MERCHANT_SILVER[rarity_index(item.get("rarity", "common"))]


static func shop_price(rarity: String) -> int:
	return SHOP_SOULS[rarity_index(rarity)]


## What a gilded piece sells for outside the Crypt, in gold.
static func sell_price(item: Dictionary) -> int:
	var level := int(item.get("level", 1))
	var r := float(rarity_index(item.get("rarity", "common")) + 1)
	var at := func(l: int) -> float: return SELL_SCALE * pow(l, 3) * pow(r, 1.5)
	if level <= 30:
		return maxi(1, roundi(at.call(level)))
	return roundi(at.call(30) * (1.0 + 0.05 * (level - 30)))


# --- Making pieces ----------------------------------------------------------------

static func make(set_id: String, slot: String, rarity: String, level: int) -> Dictionary:
	var item := {"gear": 1, "set": set_id, "slot": slot, "rarity": rarity, "level": maxi(1, level)}
	refresh(item)
	return item


## Rebuilds a piece's name, effects and floor from its set, slot, rarity and
## level (after leveling up, or on load).
static func refresh(item: Dictionary) -> void:
	item.name = ItemModels.piece_name(item.set, item.slot)
	item.effects = effects(item.set, item.slot, item.rarity, int(item.level))
	item.floor = clampi(ceili(int(item.level) / 3.0), 1, 99)


## A random piece for a floor: rarity by its tier's odds (one up for boss and
## elite chests), level in its range (the top of it with max_level).
static func roll(floor_number: int, slot := "", bump := false, max_level := false) -> Dictionary:
	if slot == "":
		slot = SLOTS.pick_random()
	var set_id: String = PIECES.keys().pick_random()
	var levels := level_range(floor_number)
	var level := levels.y if max_level else randi_range(levels.x, levels.y)
	return make(set_id, slot, roll_rarity(floor_number, bump), level)


static func roll_rarity(floor_number: int, bump := false) -> String:
	var odds: Array = DROP_ODDS[tier(floor_number) - 1]
	var total := 0.0
	for w in odds:
		total += float(w)
	var pick := randf() * total
	var index := 0
	for i in odds.size():
		pick -= float(odds[i])
		if pick <= 0.0:
			index = i
			break
	if bump:
		index = mini(index + 1, RARITIES.size() - 1)
	return RARITIES[index]


# --- Sets -------------------------------------------------------------------------

## How many pieces of a set are worn.
static func set_count(set_id: String, worn: Dictionary) -> int:
	var count := 0
	for slot in worn:
		if worn[slot].get("set", "") == set_id and is_gear(worn[slot]):
			count += 1
	return count


## The active 4-piece bonuses' effects: {effect: value}.
static func set_bonus(worn: Dictionary) -> Dictionary:
	var out := {}
	for set_id in SET_BONUS:
		if set_count(set_id, worn) < SLOTS.size():
			continue
		var lowest := RARITIES.size() - 1
		for slot in worn:
			lowest = mini(lowest, rarity_index(worn[slot].get("rarity", "common")))
		for effect in SET_BONUS[set_id]:
			out[effect] = float(out.get(effect, 0.0)) + float(SET_BONUS[set_id][effect][lowest])
	return out


## The bonus at a rarity, as text ("Take 7% less damage").
static func bonus_text(set_id: String, rarity: String) -> String:
	var parts: Array[String] = []
	for effect in SET_BONUS[set_id]:
		parts.append(GameState.effect_text({effect: SET_BONUS[set_id][effect][rarity_index(rarity)]}, 1))
	return ", ".join(parts)


# --- Old saves ----------------------------------------------------------------------

## Turns an item from before the gear system into the nearest set piece: its
## slot, the set its stats lean to (ItemModels.set_for), its rarity (cursed
## becomes epic), and a level from how deep it was found or reforged.
static func migrate(item: Dictionary) -> void:
	if is_gear(item) or not SLOTS.has(item.get("slot", "")):
		return
	var rarity: String = item.get("rarity", "common")
	if not rarity in RARITIES:
		rarity = "epic" if rarity == "cursed" else "rare"
	item.set = ItemModels.set_for(item)
	item.rarity = rarity
	item.level = clampi(int(item.get("floor", 1)) * 3 - 1, 1, 60)
	item.gear = 1
	for old in ["reforged", "rerolls", "legendary"]:
		item.erase(old)
	refresh(item)
