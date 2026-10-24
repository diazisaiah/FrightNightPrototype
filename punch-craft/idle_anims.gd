class_name IdleAnims
## Hand idles (2026-10-24): what the first-person hands do after a few
## seconds of doing nothing. Purely cosmetic; any action cuts one off. Each
## fighter has their own; more are bought in the Soul Shop and equipped per
## fighter in the Loadout (GameState.idle_picks).
##
## keys: [seconds, {"r": [pos, rot], "l": [pos, rot], "sfx": [sound, db, pitch],
## "trail": true}]: offsets from the rest pose, written for the right arm (the
## left mirrors them). An arm left out of a key holds where it was. The hands
## return to rest after the last key.
## prop: a little thing in the hands: kind (coin, skull, flame) and path:
## [[key, hand, lift, seconds]]: when that key starts, it flies to that hand's
## fist (where the key leaves it, plus lift meters up) over seconds.

const MEET := [Vector3(-0.13, 0.12, -0.06), Vector3(-0.05, 0.55, 0.0)]
const MEET_TWIST := [Vector3(-0.15, 0.12, -0.06), Vector3(-0.05, 0.6, 0.4)]
const DROP := [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)]
const PALM_UP := [Vector3(-0.08, 0.04, -0.04), Vector3(0.45, 0.3, 2.3)]
const REST := [Vector3.ZERO, Vector3.ZERO]

## Each fighter's own (always owned).
const BASE := {
	"berserker": "knuckle_crack", "counter_master": "tape_check", "combo_master": "shadowbox",
	"free_runner": "shake_out", "wise_guy": "pinky_ring", "elementalist": "palm_flame",
}
## Sold in the Soul Shop; any fighter can wear them.
const SHOP := ["fist_bump", "coin_flip", "juggler", "drum_roll", "windmill", "stretch"]

const ANIMS := {
	"knuckle_crack": {"name": "Knuckle Crack", "keys": [
		[0.35, {"r": MEET, "l": MEET}],
		[0.1, {"r": MEET_TWIST, "l": MEET_TWIST, "sfx": ["hit", -16.0, 2.2]}],
		[0.12, {"r": MEET, "l": MEET}],
		[0.1, {"r": MEET_TWIST, "l": MEET_TWIST, "sfx": ["hit", -16.0, 2.5]}],
		[0.2, {"r": MEET, "l": MEET}],
		[0.35, {"r": REST, "l": REST}],
	]},
	"tape_check": {"name": "Tape Check", "keys": [
		[0.4, {"r": [Vector3(-0.08, 0.1, -0.02), Vector3(0.3, 0.45, 0.6)], "l": [Vector3(-0.05, 0.05, 0.0), Vector3(0.1, 0.3, 0.0)]}],
		[0.25, {"r": [Vector3(-0.08, 0.1, -0.02), Vector3(0.3, 0.45, 1.1)], "l": [Vector3(-0.08, 0.08, -0.03), Vector3(0.1, 0.35, 0.0)], "sfx": ["draw", -18.0, 2.0]}],
		[0.25, {"l": [Vector3(-0.02, 0.03, 0.02), Vector3(0.05, 0.2, 0.0)]}],
		[0.3, {"r": [Vector3(-0.08, 0.1, -0.02), Vector3(0.3, 0.45, 0.4)]}],
		[0.12, {"r": [Vector3(0.05, -0.04, 0.0), Vector3(-0.2, -0.1, -0.3)], "l": [Vector3(0.05, -0.04, 0.0), Vector3(-0.2, -0.1, -0.3)], "sfx": ["whoosh", -16.0, 1.5]}],
		[0.12, {"r": [Vector3(0.0, 0.02, 0.0), Vector3(0.1, 0.05, 0.2)], "l": [Vector3(0.0, 0.02, 0.0), Vector3(0.1, 0.05, 0.2)]}],
	]},
	"shadowbox": {"name": "Shadowbox", "keys": [
		[0.08, {"l": [Vector3(-0.05, 0.08, -0.12), Vector3(-0.2, 0.08, 0.25)], "trail": true}],
		[0.08, {"l": REST}],
		[0.08, {"r": [Vector3(-0.07, 0.08, -0.14), Vector3(-0.2, 0.12, 0.25)], "trail": true}],
		[0.08, {"r": REST}],
		[0.08, {"l": [Vector3(-0.05, 0.08, -0.12), Vector3(-0.2, 0.08, 0.25)], "trail": true}],
		[0.08, {"l": REST}],
		[0.08, {"l": [Vector3(-0.05, 0.08, -0.12), Vector3(-0.2, 0.08, 0.25)], "trail": true}],
		[0.08, {"l": REST}],
		[0.1, {"r": [Vector3(0.02, 0.1, -0.1), Vector3(-0.3, 0.7, 0.0)], "trail": true}],
		[0.25, {"r": REST}],
	]},
	"shake_out": {"name": "Shake Out", "keys": [
		[0.3, {"r": DROP, "l": DROP}],
		[0.07, {"r": [Vector3(0.02, -0.09, 0.05), Vector3(0.4, 0.0, 0.25)], "l": [Vector3(0.02, -0.14, 0.05), Vector3(0.4, 0.0, -0.25)]}],
		[0.07, {"r": [Vector3(0.02, -0.14, 0.05), Vector3(0.4, 0.0, -0.25)], "l": [Vector3(0.02, -0.09, 0.05), Vector3(0.4, 0.0, 0.25)]}],
		[0.07, {"r": [Vector3(0.02, -0.09, 0.05), Vector3(0.4, 0.0, 0.25)], "l": [Vector3(0.02, -0.14, 0.05), Vector3(0.4, 0.0, -0.25)]}],
		[0.07, {"r": [Vector3(0.02, -0.14, 0.05), Vector3(0.4, 0.0, -0.25)], "l": [Vector3(0.02, -0.09, 0.05), Vector3(0.4, 0.0, 0.25)]}],
		[0.07, {"r": [Vector3(0.02, -0.09, 0.05), Vector3(0.4, 0.0, 0.25)], "l": [Vector3(0.02, -0.14, 0.05), Vector3(0.4, 0.0, -0.25)]}],
		[0.25, {"r": [Vector3(0.0, 0.03, 0.0), Vector3(-0.1, 0.0, 0.0)], "l": [Vector3(0.0, 0.03, 0.0), Vector3(-0.1, 0.0, 0.0)]}],
	]},
	"pinky_ring": {"name": "Pinky Ring", "keys": [
		[0.4, {"l": [Vector3(-0.08, 0.06, -0.06), Vector3(0.2, 0.4, 1.0)], "r": [Vector3(-0.06, 0.04, 0.0), Vector3(0.1, 0.3, 0.0)]}],
		[0.12, {"r": [Vector3(-0.1, 0.08, 0.0), Vector3(0.1, 0.4, 0.0)]}],
		[0.12, {"r": [Vector3(-0.08, 0.1, 0.01), Vector3(0.1, 0.4, 0.0)]}],
		[0.12, {"r": [Vector3(-0.1, 0.08, 0.0), Vector3(0.1, 0.4, 0.0)]}],
		[0.12, {"r": [Vector3(-0.08, 0.1, 0.01), Vector3(0.1, 0.4, 0.0)], "sfx": ["coin", -16.0, 1.6]}],
		[0.4, {"r": REST}],
		[0.35, {"l": REST}],
	]},
	"palm_flame": {"name": "Palm Flame", "keys": [
		[0.4, {"r": PALM_UP}],
		[0.6, {"sfx": ["fire", -14.0, 1.4]}],
		[0.4, {"l": PALM_UP, "r": [Vector3(-0.04, 0.02, -0.02), Vector3(0.3, 0.2, 1.4)]}],
		[0.5, {"r": REST}],
		[0.35, {"l": REST, "sfx": ["whoosh", -18.0, 0.8]}],
	], "prop": {"kind": "flame", "path": [[1, "r", 0.08, 0.2], [2, "l", 0.08, 0.4]]}},
	"fist_bump": {"name": "Fist Bump", "keys": [
		[0.3, {"r": [Vector3(-0.1, 0.05, -0.12), Vector3(-0.2, 0.55, 0.0)], "l": [Vector3(-0.1, 0.05, -0.12), Vector3(-0.2, 0.55, 0.0)]}],
		[0.08, {"r": [Vector3(-0.14, 0.05, -0.12), Vector3(-0.2, 0.6, 0.0)], "l": [Vector3(-0.14, 0.05, -0.12), Vector3(-0.2, 0.6, 0.0)], "sfx": ["hit", -14.0, 1.4]}],
		[0.15, {"r": [Vector3(-0.06, 0.05, -0.1), Vector3(-0.2, 0.5, 0.0)], "l": [Vector3(-0.06, 0.05, -0.1), Vector3(-0.2, 0.5, 0.0)]}],
		[0.08, {"r": [Vector3(-0.14, 0.05, -0.12), Vector3(-0.2, 0.6, 0.0)], "l": [Vector3(-0.14, 0.05, -0.12), Vector3(-0.2, 0.6, 0.0)], "sfx": ["hit", -14.0, 1.6]}],
		[0.35, {"r": REST, "l": REST}],
	]},
	"coin_flip": {"name": "Coin Flip", "keys": [
		[0.3, {"r": [Vector3(-0.05, 0.04, -0.05), Vector3(0.2, 0.25, 0.3)]}],
		[0.1, {"r": [Vector3(-0.05, 0.09, -0.06), Vector3(-0.1, 0.25, 0.3)], "sfx": ["coin", -12.0, 1.0]}],
		[0.45, {"r": [Vector3(-0.05, 0.04, -0.05), Vector3(0.2, 0.25, 0.3)]}],
		[0.45, {"sfx": ["coin", -14.0, 1.3]}],
		[0.35, {"r": REST}],
	], "prop": {"kind": "coin", "path": [[0, "r", 0.03, 0.3], [2, "r", 0.32, 0.45], [3, "r", 0.03, 0.45]]}},
	"juggler": {"name": "Juggler", "keys": [
		[0.3, {"r": [Vector3(-0.06, 0.02, -0.04), Vector3(0.3, 0.3, 0.6)], "l": [Vector3(-0.06, 0.02, -0.04), Vector3(0.3, 0.3, 0.6)]}],
		[0.1, {"r": [Vector3(-0.06, 0.07, -0.04), Vector3(0.1, 0.3, 0.6)]}],
		[0.45, {"r": [Vector3(-0.06, 0.02, -0.04), Vector3(0.3, 0.3, 0.6)]}],
		[0.1, {"l": [Vector3(-0.06, 0.07, -0.04), Vector3(0.1, 0.3, 0.6)]}],
		[0.45, {"l": [Vector3(-0.06, 0.02, -0.04), Vector3(0.3, 0.3, 0.6)]}],
		[0.1, {"r": [Vector3(-0.06, 0.07, -0.04), Vector3(0.1, 0.3, 0.6)]}],
		[0.45, {"r": [Vector3(-0.06, 0.02, -0.04), Vector3(0.3, 0.3, 0.6)]}],
		[0.35, {"r": REST, "l": REST}],
	], "prop": {"kind": "skull", "path": [[0, "r", 0.05, 0.3], [2, "l", 0.05, 0.45], [4, "r", 0.05, 0.45], [6, "l", 0.05, 0.45]]}},
	"drum_roll": {"name": "Drum Roll", "keys": [
		[0.2, {"r": DROP, "l": DROP}],
		[0.06, {"r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": DROP, "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": DROP, "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": DROP, "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": DROP, "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": DROP, "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": DROP, "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.2, {"r": [Vector3(0.0, 0.06, 0.0), Vector3(-0.3, 0.0, 0.0)], "l": [Vector3(0.0, 0.06, 0.0), Vector3(-0.3, 0.0, 0.0)]}],
		[0.08, {"r": [Vector3(0.02, -0.14, 0.04), Vector3(0.5, 0.0, 0.0)], "l": [Vector3(0.02, -0.14, 0.04), Vector3(0.5, 0.0, 0.0)], "sfx": ["heavy", -14.0, 1.3]}],
		[0.35, {"r": REST, "l": REST}],
	]},
	"windmill": {"name": "Windmill", "keys": [
		[0.2, {"r": [Vector3(0.05, 0.15, 0.1), Vector3(1.4, -0.4, 0.0)]}],
		[0.15, {"r": [Vector3(0.1, 0.02, 0.1), Vector3(0.2, -1.0, 0.0)], "trail": true}],
		[0.15, {"r": [Vector3(0.03, -0.15, 0.02), Vector3(-0.8, 0.0, 0.0)]}],
		[0.15, {"r": [Vector3(0.05, 0.15, 0.1), Vector3(1.4, -0.4, 0.0)], "sfx": ["whoosh", -12.0, 0.9]}],
		[0.15, {"r": [Vector3(0.1, 0.02, 0.1), Vector3(0.2, -1.0, 0.0)], "trail": true}],
		[0.15, {"r": [Vector3(0.03, -0.15, 0.02), Vector3(-0.8, 0.0, 0.0)]}],
		[0.15, {"r": [Vector3(-0.08, 0.08, -0.16), Vector3(-0.3, 0.3, 0.4)], "sfx": ["whoosh", -10.0, 1.2]}],
		[0.35, {"r": REST}],
	]},
	"stretch": {"name": "Stretch", "keys": [
		[0.6, {"r": [Vector3(-0.04, 0.12, -0.2), Vector3(-0.4, 0.3, 0.6)], "l": [Vector3(-0.04, 0.12, -0.2), Vector3(-0.4, 0.3, 0.6)], "sfx": ["draw", -16.0, 0.7]}],
		[0.25, {"r": [Vector3(-0.04, 0.13, -0.21), Vector3(-0.4, 0.3, 0.7)], "l": [Vector3(-0.04, 0.13, -0.21), Vector3(-0.4, 0.3, 0.7)]}],
		[0.25, {"r": [Vector3(-0.04, 0.12, -0.2), Vector3(-0.4, 0.3, 0.6)], "l": [Vector3(-0.04, 0.12, -0.2), Vector3(-0.4, 0.3, 0.6)]}],
		[0.5, {"r": REST, "l": REST}],
	]},
}


static func name_of(id: String) -> String:
	return ANIMS.get(id, {}).get("name", id.capitalize())


## The fighter's own idle.
static func base_for(class_id: String) -> String:
	return BASE.get(class_id, "knuckle_crack")


## Total seconds an idle runs.
static func length(id: String) -> float:
	var total := 0.0
	for key in ANIMS.get(id, {}).get("keys", []):
		total += float(key[0])
	return total


## What the fighter can pick: their own, then every bought one.
static func choices(class_id: String) -> Array:
	return [base_for(class_id)] + SHOP.filter(func(id: String) -> bool: return GameState.idles_bought.has(id))
