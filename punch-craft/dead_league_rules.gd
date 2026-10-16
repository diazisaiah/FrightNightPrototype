class_name DeadLeagueRules
extends RefCounted
## Shared data and scoring for Dead League's upgrade-free, three-round bouts.

const ROUND_COUNT := 3
const BOSS_COUNT := 5

const BOSSES := [
	{
		"id": "bellman", "number": 1, "name": "THE BELLMAN",
		"tagline": "Every toll is a warning.",
		"bio": "A patient power fighter. Read the bell, dodge the finish, punish the silence.",
		"pattern": "Heavy straights, hooks and delayed slams",
		"accent": Color(0.95, 0.22, 0.12), "hp": 52.0, "damage": 4.6,
		"speed": 0.95, "windup": 1.08,
	},
	{
		"id": "headless", "number": 2, "name": "THE HEADLESS",
		"tagline": "No eyes. No tells. Watch the flame.",
		"bio": "A relentless knight whose ghost-flame shoulders reveal which side is coming.",
		"pattern": "Fast alternating straights and sudden hooks",
		"accent": Color(0.25, 0.72, 1.0), "hp": 58.0, "damage": 4.3,
		"speed": 1.08, "windup": 0.96,
	},
	{
		"id": "southpaw", "number": 3, "name": "SISTER SOUTHPAW",
		"tagline": "Confession comes from the left.",
		"bio": "A tempo fighter who changes rhythm mid-combination and lives on the outside angle.",
		"pattern": "Left-hand pressure, hooks and long mix-ups",
		"accent": Color(0.68, 0.35, 1.0), "hp": 62.0, "damage": 4.4,
		"speed": 1.12, "windup": 0.93,
	},
	{
		"id": "plague_doctor", "number": 4, "name": "THE PLAGUE DOCTOR",
		"tagline": "The cure is a counterpunch.",
		"bio": "A clinical trap-setter. Short combinations bait an early dodge before the real dose.",
		"pattern": "Stuttered attacks, uppercuts and punish strings",
		"accent": Color(0.35, 0.95, 0.48), "hp": 68.0, "damage": 4.9,
		"speed": 1.02, "windup": 1.0,
	},
	{
		"id": "coffin_king", "number": 5, "name": "THE COFFIN KING",
		"tagline": "Three rounds. One throne.",
		"bio": "The champion combines every lesson in the League and becomes merciless when hurt.",
		"pattern": "Long championship strings and crushing slams",
		"accent": Color(1.0, 0.7, 0.18), "hp": 78.0, "damage": 5.4,
		"speed": 1.05, "windup": 0.96,
	},
]


## Pulpy trash talk: a line before each round, and one when they go down.
const TAUNTS := {
	"bellman": [
		"Ding ding, meat. That's the sound of your funeral.",
		"Every bell I ring is somebody's last round.",
		"I've been tolling since before your grandpa had knuckles.",
	],
	"headless": [
		"...",
		"(The Headless points at you. Then at the floor. Then at you again.)",
		"(The flames over its neck flicker. You get the feeling it's grinning.)",
	],
	"southpaw": [
		"Forgive me, child. My left hook won't.",
		"Confess now. It hurts less than my jab.",
		"I took a vow of silence. Not a vow of mercy.",
	],
	"plague_doctor": [
		"Hold still. This won't hurt a bit. That's a lie.",
		"My diagnosis: severe face. The cure: my fist.",
		"Take two uppercuts and don't call me in the morning.",
	],
	"coffin_king": [
		"Another soul for the collection. Kneel, and I'll make it quick.",
		"I've buried a thousand champions. You'll fit nicely between two of them.",
		"Every coffin in this graveyard was built for someone like you.",
	],
}
const DEFEAT_LINES := {
	"bellman": "The bell cracks. For the first time in a hundred years, it's quiet.",
	"headless": "The skull tumbles out of its flames, and somehow it looks impressed.",
	"southpaw": "\"Go with God,\" she wheezes. \"He's got a better left than me.\"",
	"plague_doctor": "\"Remarkable,\" he coughs through the beak. \"Terminal, but remarkable.\"",
	"coffin_king": "The crown rolls to your feet. A thousand souls sigh at once, and one of them is yours.",
}


static func taunt(index: int) -> String:
	return TAUNTS[boss(index).id].pick_random()


static func boss(index: int) -> Dictionary:
	return BOSSES[clampi(index, 0, BOSSES.size() - 1)]


## Grade is intentionally driven by defensive reads and varied offense, not
## raw damage. The same fighter and boss always use the same normalized stats.
## Style points for a won bout. Damage counts as a share of your max knuckle
## HP, so grades mean the same at every tier; then the total is scaled by
## build_factor(): beating a contender while under-powered earns more,
## stomping one with a far stronger build earns less.
static func score(stats: Dictionary) -> int:
	var health := maxf(float(stats.get("max_knuckles", 50.0)), 1.0)
	var lost := float(stats.get("damage_taken", 0.0)) / health
	var raw := (
		800.0
		+ float(stats.get("perfect_dodges", 0)) * 40.0
		+ float(stats.get("counters", 0)) * 30.0
		+ float(stats.get("variety", 0)) * 50.0
		- lost * 500.0
		- float(stats.get("grazes", 0)) * 15.0
		- float(stats.get("elapsed", 0.0)) * 2.0
	)
	return maxi(0, roundi(raw * build_factor(float(stats.get("power_ratio", 1.0)))))


## power_ratio = your POWER / the contender's. Even fights score 1.0; up to
## +20% as the underdog, down to -20% when overpowered.
static func build_factor(power_ratio: float) -> float:
	return clampf(sqrt(1.0 / maxf(power_ratio, 0.01)), 0.8, 1.2)


static func grade(points: int) -> String:
	if points >= 1200:
		return "S+"
	if points >= 1050:
		return "S"
	if points >= 900:
		return "A"
	if points >= 700:
		return "B"
	if points >= 500:
		return "C"
	return "D"


static func grade_rank(value: String) -> int:
	return ["D", "C", "B", "A", "S", "S+"].find(value)

