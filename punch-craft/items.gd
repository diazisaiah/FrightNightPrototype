class_name Items
## Equipment found in the Crypt. An item fills one of four slots and carries
## a few effects that use the same effect names as upgrades and skills, so
## anything an upgrade can do, an item can too (Fire Fists included). Items
## last for one Crypt run: deeper floors roll stronger ones.
## Some items also carry a special: an effect that changes how you fight
## (triggered by dodges, counters, getting hit, dash jabs...). Risk specials
## (big upside, real downside) can show up on any item. Legendaries are named
## uniques from boss and elite chests, each with a signature effect.

const SLOTS := ["gloves", "wraps", "boots", "charm"]
const SLOT_NAMES := {"gloves": "Gloves", "wraps": "Wraps", "boots": "Boots", "charm": "Charm", "blessing": "Blessing"}
const SLOT_ICONS := {"gloves": "fist", "wraps": "shield", "boots": "boot", "charm": "star"}

## count: how many effects it rolls. power: always rolls one of the slot's
## power effects. strength: multiplies every rolled value.
const RARITIES := {
	"common": {"name": "Common", "color": Color(0.8, 0.8, 0.8), "count": 1, "power": false, "strength": 1.0},
	"uncommon": {"name": "Uncommon", "color": Color(0.35, 0.9, 0.45), "count": 2, "power": false, "strength": 1.15},
	"rare": {"name": "Rare", "color": Color(0.35, 0.65, 1.0), "count": 3, "power": false, "strength": 1.3},
	"epic": {"name": "Epic", "color": Color(0.8, 0.45, 1.0), "count": 3, "power": true, "strength": 1.5},
	"legendary": {"name": "Legendary", "color": Color(1.0, 0.62, 0.12), "count": 2, "power": false, "strength": 1.6},
	"cursed": {"name": "Cursed", "color": Color(0.75, 0.25, 0.95), "count": 3, "power": false, "strength": 1.6},
	"blessed": {"name": "Shrine", "color": Color(0.6, 0.85, 1.0), "count": 0, "power": false, "strength": 1.0},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "epic"]
## Chance weights at floor 1; each floor deeper shifts weight toward rarer.
const RARITY_WEIGHTS := [55.0, 30.0, 12.0, 3.0]
const RARITY_SHIFT_PER_FLOOR := [-8.0, 2.0, 4.0, 2.0]
## Rolled values grow this much per floor deeper.
const FLOOR_GROWTH := 0.3
## Chance a rare item swaps one of its effects for a power.
const RARE_POWER_CHANCE := 0.35
## Chance an item of each rarity gets a special.
const SPECIAL_CHANCE := {"common": 0.0, "uncommon": 0.15, "rare": 0.4, "epic": 1.0}
## Chance any item gets a risk special (on top of the above).
const RISK_CHANCE := 0.06
## Legendaries: only from boss / elite chests, from this floor on.
const LEGENDARY_MIN_FLOOR := 2
const LEGENDARY_CHANCE := {"boss": 0.15, "elite": 0.05}

## Specials each slot can roll: effect -> value (several effects for one
## special are listed together).
const SPECIALS := {
	"gloves": {
		"shatter": {"shatter": 0.5}, "venom": {"venom": 0.25}, "serrated": {"serrated": 1.0},
		"lunging_jab": {"lunging_jab": 0.6},
	},
	"wraps": {"thorns": {"thorns": 1.0}, "iron_will": {"iron_will": 1.0}, "grit": {"grit": 0.3}},
	"boots": {"frost_slip": {"frost_slip": 0.3}, "spear_jab": {"spear_jab": 1.0}, "clean_read": {"clean_read": 2.0}},
	"charm": {"rhythm": {"rhythm": 0.15}, "executioner": {"executioner": 0.25}},
}
## Big upside, real downside. Any slot.
const RISK_SPECIALS := {
	"glass_jaw": {"glass_jaw": 0.5, "damage_taken": 0.3},
	"last_stand": {"last_stand": 0.6},
	"blood_price": {"blood_price": 0.4, "blood_cost": 1.0},
}
## Cursed chests: the same risks, turned up.
const CURSED_SPECIALS := {
	"glass_jaw": {"glass_jaw": 1.0, "damage_taken": 0.6},
	"last_stand": {"last_stand": 1.2, "knuckles_percent": -0.25},
	"blood_price": {"blood_price": 0.8, "blood_cost": 2.0},
}
## Shrine blessings: [name, effects]. Plus any special (as "Blessing of ...").
const BLESSINGS := [
	["Blessing of Might", {"damage_percent": 0.2}],
	["Blessing of Stone", {"knuckles_percent": 0.2, "defense": 2.0}],
	["Blessing of the Slip", {"dodge_window": 0.15, "counter_bonus": 0.3}],
	["Blessing of Plenty", {"coin_bonus": 0.3, "xp_bonus": 0.2}],
	["Blessing of Fury", {"combo_step": 0.08, "punch_speed": 0.08}],
]
const BLESSING_SPECIAL_CHANCE := 0.4
## Every effect that counts as a special (shown in gold on item cards).
const SPECIAL_EFFECTS := [
	"shatter", "venom", "serrated", "lunging_jab", "thorns", "iron_will", "grit", "frost_slip", "spear_jab",
	"clean_read", "rhythm", "executioner", "glass_jaw", "damage_taken", "last_stand", "blood_price", "blood_cost",
	"bone_breaker", "long_count", "champions_hands", "slipknot", "gravewalker", "lantern",
]
## Named uniques: a fixed name and slot, a signature effect, plus rolled stats.
const LEGENDARIES := {
	"bone_breaker": {"name": "Bone Breaker", "slot": "gloves", "effects": {"bone_breaker": 1.0}},
	"long_count": {"name": "The Long Count", "slot": "charm", "effects": {"long_count": 1.0}},
	"champions_hands": {"name": "Champion's Hands", "slot": "gloves", "effects": {"champions_hands": 1.0}},
	"slipknot": {"name": "Slipknot Wraps", "slot": "wraps", "effects": {"slipknot": 5.0, "dodge_window": 0.15}},
	"gravewalker": {"name": "Gravewalker Boots", "slot": "boots", "effects": {"gravewalker": 1.0}},
	"lantern": {"name": "Lantern of the Dead", "slot": "charm", "effects": {"lantern": 1.0}},
}

## Per slot: effect -> [base value, rounding step]. "powers" are the special
## ones (only on epics, or sometimes rares).
const AFFIXES := {
	"gloves": {
		"normal": {
			"damage": [2.0, 0.5], "heavy_bonus": [0.15, 0.05], "armor_pierce": [0.1, 0.03],
			"head_bonus": [0.15, 0.05], "counter_bonus": [0.4, 0.1], "punch_speed": [0.08, 0.01],
			"boss_damage": [0.15, 0.05], "finisher_bonus": [0.2, 0.05],
		},
		"powers": {"fire_punch": [0.3, 0.05]},
	},
	"wraps": {
		"normal": {
			"max_knuckles": [12.0, 1.0], "defense": [1.5, 0.5], "heal_on_kill": [1.0, 0.5],
			"free_punch_chance": [0.08, 0.01], "graze_reduction": [0.15, 0.05], "flinch_reduction": [0.12, 0.01],
		},
		"powers": {"knuckles_percent": [0.2, 0.05]},
	},
	"boots": {
		"normal": {
			"move_speed": [0.06, 0.01], "sprint_bonus": [0.1, 0.01], "dodge_window": [0.08, 0.01],
			"jump_bonus": [0.1, 0.01], "counter_window": [0.25, 0.05],
		},
		"powers": {"ground_pound": [1.5, 0.1]},
	},
	"charm": {
		"normal": {
			"coin_bonus": [0.15, 0.05], "xp_bonus": [0.15, 0.05], "combo_step": [0.05, 0.01],
			"combo_window": [0.3, 0.05], "finisher_bonus": [0.2, 0.05],
		},
		"powers": {"chain_lightning": [2.0, 1.0]},
	},
}
## Words for item names, keyed by the effect that leads the item.
const NAME_WORDS := {
	"damage": "Heavy", "heavy_bonus": "Brutal", "armor_pierce": "Piercing", "head_bonus": "Skullcracker",
	"counter_bonus": "Counterpuncher's", "punch_speed": "Quick", "boss_damage": "Champion's", "finisher_bonus": "Executioner's",
	"fire_punch": "Burning", "max_knuckles": "Thick", "defense": "Iron", "heal_on_kill": "Bloodsoaked",
	"free_punch_chance": "Lucky", "graze_reduction": "Padded", "flinch_reduction": "Steady", "knuckles_percent": "Titan's",
	"move_speed": "Light", "sprint_bonus": "Sprinter's", "dodge_window": "Shifty", "jump_bonus": "Springy",
	"counter_window": "Patient", "ground_pound": "Quaking", "coin_bonus": "Gilded", "xp_bonus": "Scholar's",
	"combo_step": "Rhythmic", "combo_window": "Flowing", "chain_lightning": "Storm",
}
const SPECIAL_WORDS := {
	"shatter": "Shattering", "venom": "Venomous", "serrated": "Serrated", "lunging_jab": "Lunging",
	"thorns": "Thorned", "iron_will": "Stalwart", "grit": "Gritty", "frost_slip": "Frostbitten",
	"spear_jab": "Spearing", "clean_read": "Clean", "rhythm": "Rhythmic", "executioner": "Headsman's",
	"glass_jaw": "Glass", "last_stand": "Desperate", "blood_price": "Bloodsworn",
}
const SLOT_WORDS := {
	"gloves": ["Gloves", "Knuckles", "Mitts"], "wraps": ["Wraps", "Tape", "Bandages"],
	"boots": ["Boots", "Shoes", "Treads"], "charm": ["Charm", "Talisman", "Locket"],
}


## A cursed item: three strong stats plus a turned-up risk special.
static func roll_cursed(floor_number: int) -> Dictionary:
	var item := _roll_with(floor_number, SLOTS.pick_random(), "cursed")
	var pick: String = CURSED_SPECIALS.keys().pick_random()
	_add_special(item, CURSED_SPECIALS[pick], pick)
	item.name = "Cursed " + item.name
	return item


## A shrine blessing: lasts the run, takes no slot.
static func roll_blessing(_floor_number: int) -> Dictionary:
	var blessing := {"slot": "blessing", "rarity": "blessed", "effects": {}, "floor": _floor_number}
	if randf() < BLESSING_SPECIAL_CHANCE:
		var all := {}
		for slot in SPECIALS:
			all.merge(SPECIALS[slot])
		var pick: String = all.keys().pick_random()
		blessing.name = "Blessing: %s" % SPECIAL_WORDS.get(pick, pick).trim_suffix("'s")
		blessing.effects = all[pick].duplicate()
	else:
		var pick: Array = BLESSINGS.pick_random()
		blessing.name = pick[0]
		blessing.effects = pick[1].duplicate()
	return blessing


## A named unique with its signature effect and two rolled stats.
static func roll_legendary(floor_number: int, id := "") -> Dictionary:
	if id == "":
		id = LEGENDARIES.keys().pick_random()
	var info: Dictionary = LEGENDARIES[id]
	var item := _roll_with(floor_number, info.slot, "legendary")
	item.name = info.name
	item.legendary = id
	for effect in info.effects:
		item.effects[effect] = info.effects[effect]
	return item


## Rolls a chest's item. quality "boss" / "elite" can give a legendary deep
## enough, and are rare+ / uncommon+.
static func roll_for_chest(floor_number: int, quality: String) -> Dictionary:
	if floor_number >= LEGENDARY_MIN_FLOOR and randf() < LEGENDARY_CHANCE.get(quality, 0.0):
		return roll_legendary(floor_number)
	var too_plain: Array = ["common", "uncommon"] if quality == "boss" else ["common"] if quality in ["elite", "starter"] else []
	var item := roll(floor_number)
	while item.rarity in too_plain:
		item = roll(floor_number)
	return item


## A new random item for this floor. slot defaults to a random one.
static func roll(floor_number: int, slot := "") -> Dictionary:
	if slot == "":
		slot = SLOTS.pick_random()
	var item := _roll_with(floor_number, slot, _roll_rarity(floor_number))
	# Specials: a chance by rarity, plus a small chance of a risk special.
	if randf() < SPECIAL_CHANCE[item.rarity]:
		var specials: Dictionary = SPECIALS[slot]
		var pick: String = specials.keys().pick_random()
		_add_special(item, specials[pick], pick)
	if randf() < RISK_CHANCE:
		var pick: String = RISK_SPECIALS.keys().pick_random()
		_add_special(item, RISK_SPECIALS[pick], pick)
	return item


static func _add_special(item: Dictionary, effects: Dictionary, id: String) -> void:
	for effect in effects:
		item.effects[effect] = effects[effect]
	item.name = "%s %s" % [SPECIAL_WORDS.get(id, "Strange"), item.name.get_slice(" ", item.name.get_slice_count(" ") - 1)]


static func _roll_with(floor_number: int, slot: String, rarity: String) -> Dictionary:
	var info: Dictionary = RARITIES[rarity]
	var pool: Dictionary = AFFIXES[slot]
	var normal: Array = pool.normal.keys()
	normal.shuffle()
	var picks: Array = normal.slice(0, mini(info.count, normal.size()))
	var has_power: bool = info.power or (rarity == "rare" and randf() < RARE_POWER_CHANCE)
	if has_power:
		picks[0] = pool.powers.keys().pick_random()
	var effects := {}
	var growth := 1.0 + FLOOR_GROWTH * (floor_number - 1)
	for effect in picks:
		var spec: Array = pool.powers[effect] if pool.powers.has(effect) else pool.normal[effect]
		var value: float = spec[0] * info.strength * growth * randf_range(0.85, 1.15)
		effects[effect] = maxf(spec[1], snappedf(value, spec[1]))
	return {
		"slot": slot,
		"rarity": rarity,
		"name": "%s %s" % [NAME_WORDS.get(picks[0], "Old"), SLOT_WORDS[slot].pick_random()],
		"effects": effects,
		"floor": floor_number,
	}


static func _roll_rarity(floor_number: int) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for i in RARITY_ORDER.size():
		var weight := maxf(1.0, RARITY_WEIGHTS[i] + RARITY_SHIFT_PER_FLOOR[i] * (floor_number - 1))
		weights.append(weight)
		total += weight
	var roll_value := randf() * total
	for i in weights.size():
		roll_value -= weights[i]
		if roll_value <= 0.0:
			return RARITY_ORDER[i]
	return "common"


static func rarity_color(item: Dictionary) -> Color:
	return RARITIES[item.rarity].color


static func is_special(effect: String) -> bool:
	return effect in SPECIAL_EFFECTS


## "Rare Gloves" etc.
static func kind_text(item: Dictionary) -> String:
	return "%s %s" % [RARITIES[item.rarity].name, SLOT_NAMES[item.slot]]


## The stats a reroll can change: the slot's regular stats, not powers or
## specials.
static func rerollable(item: Dictionary) -> Array:
	var normal: Dictionary = AFFIXES[item.slot].normal
	return item.effects.keys().filter(func(effect: String) -> bool: return normal.has(effect))


## Swaps one regular stat for another the item doesn't have yet, at the same
## strength relative to its own range (so a strong roll stays strong).
## Returns the new effect, or "" if there's nothing to swap to.
static func reroll_effect(item: Dictionary, effect: String) -> String:
	var normal: Dictionary = AFFIXES[item.slot].normal
	if not normal.has(effect):
		return ""
	var choices: Array = normal.keys().filter(func(other: String) -> bool: return not item.effects.has(other))
	if choices.is_empty():
		return ""
	var picked: String = choices.pick_random()
	var old_spec: Array = normal[effect]
	var new_spec: Array = normal[picked]
	var quality: float = float(item.effects[effect]) / old_spec[0]
	var value: float = new_spec[0] * quality * randf_range(0.92, 1.1)
	var effects := {}
	for key in item.effects:
		if key == effect:
			effects[picked] = maxf(new_spec[1], snappedf(value, new_spec[1]))
		else:
			effects[key] = item.effects[key]
	item.effects = effects
	return picked


## One line per effect, like the upgrade web's text.
static func effect_lines(item: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for effect in item.effects:
		lines.append(GameState.effect_text({effect: item.effects[effect]}, 1))
	return lines


## [text, effect] per line, specials last.
static func effect_entries(item: Dictionary) -> Array:
	var normal := []
	var special := []
	for effect in item.effects:
		var entry := [GameState.effect_text({effect: item.effects[effect]}, 1), effect]
		(special if is_special(effect) else normal).append(entry)
	return normal + special
