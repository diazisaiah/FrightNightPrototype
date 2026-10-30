class_name DeadLeagueRules
extends RefCounted
## Shared data and scoring for Dead League's upgrade-free, three-round bouts.

const ROUND_COUNT := 3
const BOSS_COUNT := 5

## Each contender is a clear step up from the last (2026-10-25: the gap was
## too small, so later ones fell to an under-par build): more HP and harder
## hits on top of the tier's par build, quicker tells (windup), shorter
## pauses between combos (idle), slipping more of your punches (evade), and
## less time open after you dodge a whole combo (open).

const BOSSES := [
	{
		"id": "bellman", "number": 1, "name": "THE BELLMAN",
		"tagline": "Rings his bell before the big one.",
		"bio": "Slow and heavy. He rings the bell before his big punch: wait for it, dodge it, then hit him while he's open.",
		"pattern": "Heavy straights, hooks, delayed slams. Leaps on you from above",
		"accent": Color(0.95, 0.22, 0.12), "hp": 52.0, "damage": 4.6,
		"speed": 0.95, "windup": 1.08, "idle": 0.6, "evade": 0.12, "open": 1.0,
	},
	{
		"id": "headless", "number": 2, "name": "THE HEADLESS",
		"tagline": "No face to read. Watch the shoulders.",
		"bio": "A knight that never lets up. The ghost-fire on its shoulders flares on the side the punch is coming from.",
		"pattern": "Fast straights, sudden hooks, ghost charges. Throws its skull: punch it down",
		"accent": Color(0.25, 0.72, 1.0), "hp": 64.0, "damage": 5.2,
		"speed": 1.08, "windup": 0.94, "idle": 0.46, "evade": 0.2, "open": 0.9,
	},
	{
		"id": "southpaw", "number": 3, "name": "SISTER SOUTHPAW",
		"tagline": "Leads with the left.",
		"bio": "Changes rhythm in the middle of a combo and keeps circling to your outside. Don't dodge early.",
		"pattern": "Slips and snaps back a right jab. Pivots behind you mid-combo. Judgment circles",
		"accent": Color(0.68, 0.35, 1.0), "hp": 80.0, "damage": 5.9,
		"speed": 1.12, "windup": 0.84, "idle": 0.36, "evade": 0.4, "open": 0.8,
	},
	{
		"id": "plague_doctor", "number": 4, "name": "THE PLAGUE DOCTOR",
		"tagline": "Fakes it, then means it.",
		"bio": "Throws short combos to bait an early dodge, then the real one. Be patient.",
		"pattern": "Long stuttered strings that heal him. Adrenaline sends him on a rampage",
		"accent": Color(0.35, 0.95, 0.48), "hp": 104.0, "damage": 6.9,
		"speed": 1.1, "windup": 0.72, "idle": 0.26, "evade": 0.36, "open": 0.7,
	},
	{
		"id": "coffin_king", "number": 5, "name": "THE COFFIN KING",
		"tagline": "Runs the League.",
		"bio": "Does a bit of everything the other four do, and gets faster the more you hurt him.",
		"pattern": "Long strings, crushing slams, every special. Faster the more he's hurt",
		"accent": Color(1.0, 0.7, 0.18), "hp": 134.0, "damage": 8.1,
		"speed": 1.18, "windup": 0.64, "idle": 0.2, "evade": 0.45, "open": 0.6,
	},
]


## Trash talk: a line before each round, and one when they go down.
const TAUNTS := {
	"bellman": [
		"Hear that bell? That one's for you.",
		"A hundred years I've been ringing this thing. Nobody's made me stop.",
		"Stand still. This'll only take one.",
	],
	"headless": [
		"...",
		"(The Headless points at you. Then at the floor. Then at you again.)",
		"(The flames over its neck flicker. You get the feeling it's grinning.)",
	],
	"southpaw": [
		"I'll pray for you after.",
		"Lead with your right. Go on.",
		"The nuns taught me this left hook. Hold still.",
	],
	"plague_doctor": [
		"Open wide.",
		"You look terrible. I can make it worse.",
		"Take two uppercuts and don't call me in the morning.",
	],
	"coffin_king": [
		"Kneel and I'll make it quick.",
		"Every coffin out there has a name on it. I picked one for you.",
		"I've buried better fighters than you this week.",
	],
}
const DEFEAT_LINES := {
	"bellman": "The bell cracks down the middle. It's finally quiet.",
	"headless": "The skull tumbles out of its flames, and somehow it looks impressed.",
	"southpaw": "\"Fine,\" she says from the canvas. \"You can have that one.\"",
	"plague_doctor": "\"Remarkable,\" he coughs through the beak. \"Terminal, but remarkable.\"",
	"coffin_king": "The crown rolls off his skull and stops at your feet.",
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

