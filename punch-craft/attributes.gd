class_name Attributes
## The five attributes (2026-10-25; replace the four stats): 3 points a level,
## 30 at most in each. Every point gives a small steady bonus, and 10, 20 and
## 30 points each unlock a perk (GameState.perk). Resetting costs coins.

const POINTS_PER_LEVEL := 3
const MAX := 30
const PERK_AT := [10, 20, 30]

## per_point: effects each point adds (GameState.get_effect).
## perks: [id, name, text] at 10, 20 and 30 points.
const LIST := {
	"power": {"name": "Power", "icon": "fist", "color": Color(1.0, 0.45, 0.25),
		"text": "+1% damage", "per_point": {"damage_percent": 0.01},
		"perks": [
			["heavy_hands", "Heavy Hands", "Staggers you cause last 30% longer"],
			["follow_through", "Follow Through", "A knockout punch carries half its leftover damage to the nearest monster within 3m"],
			["knockout_blow", "Knockout Blow", "Every 6th punch you land in a combo hits double and staggers"],
		]},
	"grit": {"name": "Grit", "icon": "heart_plus", "color": Color(1.0, 0.35, 0.4),
		"text": "+1.5% max knuckle HP", "per_point": {"knuckles_percent": 0.015},
		"perks": [
			["iron_knuckles", "Iron Knuckles", "Punches cost 20% less knuckle HP"],
			["granite_chin", "Granite Chin", "After a hit, the next hit within 2s deals half"],
			["get_up", "Get Up", "Once a bout, a knockout leaves you at 15% knuckle HP, untouchable for 2s"],
		]},
	"speed": {"name": "Speed", "icon": "wind", "color": Color(0.35, 0.95, 0.5),
		"text": "+0.6% punch speed, +0.4% move speed", "per_point": {"punch_speed": 0.006, "move_speed": 0.004},
		"perks": [
			["quick_feet", "Quick Feet", "Dodges and dashes recover 20% faster"],
			["tempo", "Tempo", "Each punch landed in a combo makes the next 2% faster, up to +20%"],
			["blur_step", "Blur Step", "A clean dodge makes you 30% faster for 2s"],
		]},
	"technique": {"name": "Technique", "icon": "eye", "color": Color(0.35, 0.85, 1.0),
		"text": "+0.4% dodge window, +0.005s counter window", "per_point": {"dodge_window": 0.004, "counter_window": 0.005},
		"perks": [
			["read_the_tell", "Read the Tell", "Attack tells flash 0.08s earlier"],
			["clean_break", "Clean Break", "A clean dodge makes the attacker stumble for 0.5s"],
			["precision", "Precision", "A counter within 0.5s of a clean dodge deals double"],
		]},
	"fortune": {"name": "Fortune", "icon": "coin", "color": Color(1.0, 0.82, 0.3),
		"text": "+2% coins, +1% XP", "per_point": {"coin_bonus": 0.02, "xp_bonus": 0.01},
		"perks": [
			["pickpocket", "Pickpocket", "Elites and champions drop 3x coins"],
			["soul_collector", "Soul Collector", "Bosses drop +1 Soul"],
			["hat_trick", "Hat Trick", "Monsters wear hats twice as often"],
		]},
}

## Perk id -> [attribute, points needed].
static var _perks := {}


static func perk_needs(id: String) -> Array:
	if _perks.is_empty():
		for attribute in LIST:
			var perks: Array = LIST[attribute].perks
			for i in perks.size():
				_perks[perks[i][0]] = [attribute, PERK_AT[i]]
	return _perks.get(id, ["", 999])


## Coins to reset attributes: a little per point spent, on the pay ladder
## where this fighter's level fights (no further than you've climbed), so a
## new fighter in a late save doesn't pay late prices.
static func reset_cost() -> int:
	var spent := 0
	for attribute in GameState.attributes:
		spent += int(GameState.attributes[attribute])
	var x := minf(Progression.level_position(GameState.class_level(GameState.player_class)), GameState.climb_position())
	return maxi(25, roundi(1.5 * spent * Progression.pay(x)))
