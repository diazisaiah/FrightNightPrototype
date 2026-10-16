class_name Progression
## The Climb (see GAME_DESIGN.md, "Progression v2"): five tiers, one per Dead
## League contender. In tier t you earn in the Underworld Arena's division t,
## loot Crypt floors 2t-1 and 2t, buy upgrade ring t, then beat contender t to
## break the next seal (ring t+1 and its power).
##
## Everything scales to a "par build": what a player has when facing contender
## t with about 85% of the unsealed upgrades, the expected fighter level and
## decent gear from that tier's floors. Enemies anywhere on the climb scale to
## the par build at their position, so you get way stronger and so do they;
## being under par makes everything harder, over par easier.

const TIER_COUNT := 5
const FLOORS_PER_TIER := 2
## Arena bouts per division before it tops out at the tier's full strength.
const BOUTS_PER_DIVISION := 3
## Share of the unsealed upgrade levels the par build owns.
const PAR_SHARE := 0.85
## Fighter level the par build has after finishing each tier (index = tiers
## done): about what ~5 good bouts a tier earn, since XP pay grows with the tier.
const PAR_LEVEL := [1, 9, 14, 19, 24, 29]
## Only upgrades with raw power count toward par: the par build skips
## utility (sprint, coins, XP...), so buying those never puts you under par.
const POWER_EFFECTS := ["damage", "max_knuckles", "defense", "damage_percent", "knuckles_percent"]
## A fighter's skill web, fully owned, is worth about this much extra damage
## and knuckle HP: about x1.7 POWER (every class is tuned to the same budget). Par owns
## the share of the web its level's skill points buy.
const SKILL_PAR := 0.6
const SKILL_WEB_POINTS := 33.0
## What a fresh fighter starts with (no upgrades, level 1, no gear).
const BASE_DAMAGE := 2.0
const BASE_KNUCKLES := 50.0
## Upgrade prices multiply by their ring (pay grows by tier to match).
const RING_COST := {1: 1.0, 2: 1.25, 3: 1.6, 4: 3.0, 5: 7.0, 6: 15.0}
## XP pay by content tier (1-5); beyond tier 5 it keeps growing. (Coins use
## the pay ladder below; XP stays on this gentler curve so levels don't run
## away: PAR_LEVEL assumes it.)
const PAY := [1.5, 2.85, 4.9, 7.3, 11.2]
## The coin pay ladder (2026-10-16): each Arena bout pays PAY_STEP times the
## one before, and each new division jumps two steps past the last bout of
## the one before (division d, bout b: step 4(d - 1) + b - 1, so Division 3
## bout 3 is 1.5^10). The Crypt sits on the same ladder by climb position.
const PAY_STEP := 1.5
const PAY_STEPS_PER_TIER := 4.0
const PAY_BASE := 1.5
const PAY_PAST_TOP := 1.35

const TIERS := [
	{"contender": "bellman", "division": "Gravedigger", "power": "FIRE", "ring_power": "sigil_fire", "trophy": "bellmans_bell"},
	{"contender": "headless", "division": "Bone", "power": "FROST", "ring_power": "sigil_frost", "trophy": "headless_helm"},
	{"contender": "southpaw", "division": "Ghost", "power": "STORM", "ring_power": "sigil_storm", "trophy": "southpaws_rosary"},
	{"contender": "plague_doctor", "division": "Plague", "power": "BLOOD", "ring_power": "sigil_blood", "trophy": "plague_censer"},
	{"contender": "coffin_king", "division": "Crown", "power": "", "ring_power": "", "trophy": "coffin_crown"},
]

## The Underworld Arena's announcer, calling each bout.
const ANNOUNCER := [
	"Ladies, gentlemen and gentle corpses: put your hands together, if you still have them!",
	"In this corner: a fighter with a pulse. Disgusting. Let's fix that.",
	"Tonight's undercard has been dead for centuries and they're STILL hungry!",
	"Remember, folks: no biting below the belt. Above the belt is fine.",
	"The crowd's dying to see this. Most of them already did!",
	"Somebody tell the gravedigger to stay late. He's gonna be busy!",
	"Odds are fifty to one against the living. The house always wins, and the house is a crypt!",
	"Keep your gloves up and your coffin closed!",
]


static func announcer_line() -> String:
	return ANNOUNCER.pick_random()


# Souls: dropped by Grave Champions and Crypt floor bosses; spent on gear.
const SOULS_PER_TIER := 1
const SOULS_FIRST_CLEAR := 3
## Gilding (keeping) a Crypt find costs Souls and silver by rarity.
const GILD_SOULS := {"common": 1, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 5, "cursed": 3}
const GILD_SILVER := {"common": 10, "uncommon": 15, "rare": 25, "epic": 40, "legendary": 60, "cursed": 40}
## Reforging a kept item: its numbers grow and it counts as two floors deeper.
const REFORGE_GROWTH := 1.25
const REFORGE_FLOORS := 2

static var _par_cache := {}


# --- Seals ------------------------------------------------------------------------

## Contenders beaten in order = seals broken (0-5).
static func seals_broken() -> int:
	var count := 0
	for tier in TIERS:
		if not bool(GameState.dead_league_clears.get(tier.contender, false)):
			break
		count += 1
	return count


## The tier you're climbing (1-5): the next contender to beat. 5 once all are.
static func current_tier() -> int:
	return mini(seals_broken() + 1, TIER_COUNT)


## Upgrade rings open so far: ring 1 at the start, one more per seal, and the
## capstone ring (6) after the Coffin King.
static func open_ring() -> int:
	return seals_broken() + 1


## The contender holding the seal over a ring, e.g. "THE BELLMAN".
static func seal_holder(ring: int) -> String:
	if ring <= 1 or ring - 2 >= TIERS.size():
		return ""
	return DeadLeagueRules.boss(ring - 2).name


# --- The par build ----------------------------------------------------------------

## The expected build when facing contender t (t = 0: a fresh fighter):
## {damage, knuckles, defense, ehp}. Counts power upgrades, stats, gear and an
## average skill web for its level; class bonuses aren't counted.
static func par(tier: int) -> Dictionary:
	tier = clampi(tier, 0, TIER_COUNT)
	if _par_cache.has(tier):
		return _par_cache[tier]
	var effects := {}
	if tier > 0:
		# The cheapest PAR_SHARE of every power level in the open rings.
		var levels := []
		for id in GameState.UPGRADES:
			var node: Dictionary = GameState.UPGRADES[id]
			if int(node.get("ring", 1)) > tier or not _is_power(node):
				continue
			for level in int(node.max_level):
				levels.append([node.cost * pow(node.cost_growth, level), id])
		levels.sort_custom(func(a, b) -> bool: return a[0] < b[0])
		var take := ceili(levels.size() * PAR_SHARE)
		for i in take:
			var node_effects: Dictionary = GameState.UPGRADES[levels[i][1]].effects
			for effect in node_effects:
				effects[effect] = effects.get(effect, 0.0) + float(node_effects[effect])
	# Stat points from levels, spread evenly over damage, durability and defense.
	var points: int = GameState.STAT_POINTS_PER_LEVEL * (int(PAR_LEVEL[tier]) - 1)
	var per_stat: float = points / 3.0
	# Decent gear from the tier's deepest floor: gloves with damage, wraps with
	# knuckles and defense (expected values of rare-ish rolls).
	var gear := _par_gear(tier)
	var damage: float = (BASE_DAMAGE + per_stat * GameState.DAMAGE_PER_POINT + effects.get("damage", 0.0) + gear.damage) \
			* (1.0 + effects.get("damage_percent", 0.0))
	var knuckles: float = (BASE_KNUCKLES + per_stat * GameState.KNUCKLES_PER_POINT + effects.get("max_knuckles", 0.0) + gear.knuckles) \
			* (1.0 + effects.get("knuckles_percent", 0.0))
	var defense: float = per_stat + effects.get("defense", 0.0) + gear.defense
	# The skill web its level affords.
	var skill := 1.0 + SKILL_PAR * minf(1.0, (int(PAR_LEVEL[tier]) - 1) * GameState.SKILL_POINTS_PER_LEVEL / SKILL_WEB_POINTS)
	damage *= skill
	knuckles *= skill
	var result := {"damage": damage, "knuckles": knuckles, "defense": defense, "ehp": knuckles * (10.0 + defense) / 10.0, "effects": effects}
	_par_cache[tier] = result
	return result


static func _is_power(node: Dictionary) -> bool:
	for effect in node.effects:
		if effect in POWER_EFFECTS:
			return true
	return false


## No gear before the Bellman: the Crypt (where gear comes from) only opens
## with his seal, so he and Division 1 are tuned to an empty-handed fighter.
static func _par_gear(tier: int) -> Dictionary:
	if tier <= 1:
		return {"damage": 0.0, "knuckles": 0.0, "defense": 0.0}
	var floor_number := tier * FLOORS_PER_TIER
	var growth := 1.0 + Items.FLOOR_GROWTH * (floor_number - 1)
	var strength: float = Items.RARITIES.rare.strength * 0.7
	return {
		"damage": Items.AFFIXES.gloves.normal.damage[0] * strength * growth,
		"knuckles": Items.AFFIXES.wraps.normal.max_knuckles[0] * strength * growth,
		"defense": Items.AFFIXES.wraps.normal.defense[0] * strength * growth,
	}


## Par at a position on the climb: x = 0 fresh, 1 = facing the Bellman, ...
## Past 5 (endless) it keeps growing 25% per step.
static func par_at(x: float) -> Dictionary:
	x = maxf(x, 0.0)
	if x >= TIER_COUNT:
		var top := par(TIER_COUNT)
		var grow := pow(1.25, x - TIER_COUNT)
		return {"damage": top.damage * grow, "ehp": top.ehp * grow}
	var low := par(floori(x))
	var high := par(ceili(x))
	var t := x - floori(x)
	return {"damage": lerpf(low.damage, high.damage, t), "ehp": lerpf(low.ehp, high.ehp, t)}


## Enemy scaling at a position on the climb: HP grows with par damage (fights
## take as many punches) and damage with par knuckle HP (hits hurt as much).
static func enemy_scaling(x: float) -> Dictionary:
	var at := par_at(x)
	return {"hp": at.damage / BASE_DAMAGE, "damage": at.ehp / BASE_KNUCKLES, "speed": 1.0, "reward": pay(x), "xp": xp_pay(x), "position": x}


## Coin multiplier for content at climb position x.
## Coin multiplier at climb position x (Arena bouts sit at d - 1 + (b - 1) / 3).
static func pay(x: float) -> float:
	x = maxf(x, 0.0)
	var whole := floorf(x)
	var steps := PAY_STEPS_PER_TIER * whole + BOUTS_PER_DIVISION * (x - whole)
	return PAY_BASE * pow(PAY_STEP, steps)


## XP multiplier at climb position x (the old, gentler pay curve).
static func xp_pay(x: float) -> float:
	var tier := clampi(ceili(maxf(x, 0.01)), 1, 99)
	var base: float = PAY[mini(tier, TIER_COUNT) - 1]
	if tier > TIER_COUNT:
		base *= pow(PAY_PAST_TOP, tier - TIER_COUNT)
	# A little ramp inside the tier.
	var fraction := x - (tier - 1)
	return base * (0.85 + 0.15 * clampf(fraction, 0.0, 1.0))


## Arena division d, bout b (1-based): bout 1 is at the last contender's par
## (a fresh fighter's on the first division), and each bout climbs a third
## of the way toward this division's contender, topping out at two thirds.
## You farm below par and face the contender at it.
static func arena_position(division: int, bout: int) -> float:
	return (division - 1) + clampf(float(bout - 1) / BOUTS_PER_DIVISION, 0.0, float(BOUTS_PER_DIVISION - 1) / BOUTS_PER_DIVISION)


## Crypt: a tier's first floor climbs to 40% of the way to its contender's
## par and the second to 80%. progress is 0-1 through the floor. Past floor
## 10 it keeps going.
const CRYPT_FLOOR_SPAN := 0.4


static func crypt_position(floor_number: int, progress := 1.0) -> float:
	var tier := ceili(floor_number / float(FLOORS_PER_TIER))
	var within := floor_number - (tier - 1) * FLOORS_PER_TIER - 1
	return (tier - 1) + (within + clampf(progress, 0.0, 1.0)) * CRYPT_FLOOR_SPAN


## Floor a Crypt run starts on when entering at tier bracket t.
static func crypt_start_floor(tier: int) -> int:
	return (tier - 1) * FLOORS_PER_TIER + 1


# --- Souls ------------------------------------------------------------------------

## Souls for a Grave Champion or Crypt floor boss at climb position x.
static func boss_souls(x: float, first_clear: bool) -> int:
	return SOULS_PER_TIER * (1 + ceili(maxf(x, 0.01))) + (SOULS_FIRST_CLEAR if first_clear else 0)


## Souls to reroll one stat on a kept item; each reroll on it costs one more.
static func reroll_cost(item: Dictionary) -> int:
	return 2 + int(item.get("rerolls", 0)) + ceili(int(item.get("floor", 1)) / 3.0)


static func reforge_cost(item: Dictionary) -> int:
	return 3 + 2 * int(item.get("reforged", 0)) + ceili(int(item.get("floor", 1)) / 2.0)
