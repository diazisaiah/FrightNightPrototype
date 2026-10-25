class_name Veterans
## Tougher versions of the regular monsters, for the deeper tiers of the
## climb: each has a big move (see Boxer specials), more HP and pays more.
## From tier 2 on, a share of each kind comes as its veteran, growing tier by
## tier until nearly all of them do.

const UPGRADES := {
	"zombie": "bruiser", "runner": "sprinter", "hulk": "crusher", "brawler": "pit_fighter",
	"shieldbearer": "bulwark", "mage": "pyromancer", "skeleton": "sniper", "wraith": "banshee",
}
const SCENES := {
	"bruiser": preload("res://bruiser.tscn"), "sprinter": preload("res://sprinter.tscn"),
	"crusher": preload("res://crusher.tscn"), "pit_fighter": preload("res://pit_fighter.tscn"),
	"bulwark": preload("res://bulwark.tscn"), "pyromancer": preload("res://pyromancer.tscn"),
	"sniper": preload("res://sniper.tscn"), "banshee": preload("res://banshee.tscn"),
}
## Share of each kind that comes as its veteran, by tier (1-5); past 5, 80%.
## (2026-10-25: was 25 / 45 / 65 / 85%, which stacked too fast on the tier's
## own scaling.)
const SHARE := [0.0, 0.15, 0.3, 0.45, 0.65]


static func share(tier: int) -> float:
	return SHARE[tier - 1] if tier >= 1 and tier <= SHARE.size() else (0.8 if tier > SHARE.size() else 0.0)


## The veteran scene to spawn instead of kind, or null for the regular one.
static func pick(kind: String, tier: int) -> PackedScene:
	if UPGRADES.has(kind) and randf() < share(tier):
		return SCENES[UPGRADES[kind]]
	return null
