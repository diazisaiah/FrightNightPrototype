class_name IdleAnims
## Hand idles (2026-10-24): what the first-person hands do after a few
## seconds of doing nothing. Purely cosmetic; any action cuts one off. Each
## fighter has their own; more are bought in the Soul Shop and equipped per
## fighter in the Loadout (GameState.idle_picks). The hands are rigged
## (Fists): fingers curl, spread, point and flick, and the hands stop where
## they touch instead of passing through each other.
##
## keys: [seconds, {"r": [pose, shape] or [pos, rot, shape], "l": [...], "sfx": [sound, db,
## pitch], "trail": true, "prop": [hand, anchor, lift, arc], "hide_prop": true}].
## pos / rot: offsets from the rest pose, written for the right arm (the left
## mirrors them). shape: a SHAPES name. A hand left out of a key holds; one
## without a shape keeps its last. The hands go back to rest after the last key.
## prop: where the idle's prop (coin, skull, flame) goes this key: to that
## hand's anchor (palm, top, tip, thumb) plus lift meters, arcing if arc.
## hold: a prop gripped in each fist the whole time (a bone for drumsticks).

## Hand shapes: f = all finger curl (1 = fist), f0-f3 one finger (index to
## pinky), t = thumb curl, tu = thumb up, spread = fingers fanned.
const SHAPES := {
	"fist": {"f": 1.0, "t": 1.0},
	"open": {"f": 0.0, "t": 0.0, "spread": 1.0},
	"wide": {"f": 0.0, "t": 0.0, "spread": 1.8},
	"relax": {"f": 0.4, "t": 0.45, "spread": 0.3},
	"loose": {"f": 0.2, "t": 0.2, "spread": 0.6},
	"cup": {"f": 0.55, "t": 0.5, "spread": 0.15},
	"claw": {"f": 0.7, "t": 0.7, "spread": 0.9},
	"point": {"f": 1.0, "f0": 0.0, "t": 1.0},
	"gun": {"f": 1.0, "f0": 0.0, "t": 0.0},
	"gun_fire": {"f": 1.0, "f0": 0.0, "t": 0.6},
	"pinky_up": {"f": 0.85, "f3": 0.0, "t": 0.8},
	"pinky_wiggle": {"f": 0.85, "f3": 0.4, "t": 0.8},
	"pinch": {"f": 0.8, "f0": 0.5, "t": 0.5},
	"flick_ready": {"f": 1.0, "f0": 0.6, "t": 1.0},
	"flick": {"f": 1.0, "f0": 0.35, "t": 0.0, "tu": 0.8},
	"ripple0": {"f": 0.15, "f0": 0.8, "t": 0.3, "spread": 0.5},
	"ripple1": {"f": 0.15, "f1": 0.8, "t": 0.3, "spread": 0.5},
	"ripple2": {"f": 0.15, "f2": 0.8, "t": 0.3, "spread": 0.5},
	"ripple3": {"f": 0.15, "f3": 0.8, "t": 0.3, "spread": 0.5},
}

const REST := [Vector3.ZERO, Vector3.ZERO, "fist"]

## Arm poses by name: [pos, rot] offsets from rest for the right arm, worked
## out from where the fist should sit in view and which way the forearm and
## palm face (so the fingers are actually seen). A key can name one:
## [pose, shape] or [pose, shape, nudge].
const POSES := {
	"palm_face": [Vector3(-0.14, -0.052, -0.146), Vector3(0.85, -0.18, -2.64)],
	"back_face": [Vector3(-0.14, -0.052, -0.146), Vector3(0.85, -0.18, 0.5)],
	"palm_up": [Vector3(-0.032, 0.153, -0.014), Vector3(-0.45, 0.27, -2.64)],
	"palm_up_lift": [Vector3(-0.034, 0.169, -0.017), Vector3(-0.35, 0.27, -2.64)],
	"gun": [Vector3(-0.007, 0.093, -0.007), Vector3(-0.15, 0.02, -1.07)],
	"gun_kick": [Vector3(-0.021, 0.008, -0.066), Vector3(0.25, 0.02, -1.07)],
	"ring_turn": [Vector3(-0.194, -0.057, -0.109), Vector3(0.7, -0.38, 0.25)],
	"nose_in": [Vector3(-0.227, -0.049, -0.141), Vector3(1.5, -0.13, -1.07)],
	"nose_near": [Vector3(-0.201, -0.12, -0.11), Vector3(1.1, -0.1, -1.07)],
	"nose_out": [Vector3(-0.143, -0.1, -0.082), Vector3(0.65, -0.06, -1.07)],
	"meet": [Vector3(0.008, 0.113, -0.046), Vector3(-0.15, 0.57, 0.3)],
	"apart": [Vector3(0.037, 0.103, 0.002), Vector3(-0.15, 0.37, 0.3)],
	"side_in": [Vector3(0.049, 0.14, -0.032), Vector3(-0.2, 0.52, -1.07)],
	"low": [Vector3(0.011, 0.073, 0.106), Vector3(-0.45, -0.03, -0.3)],
	"shake_low": [Vector3(-0.036, 0.094, 0.127), Vector3(-0.6, -0.08, -0.7)],
	"push_out": [Vector3(-0.109, -0.003, -0.263), Vector3(0.75, -0.08, 0.5)],
	"fist_up": [Vector3(-0.102, -0.023, -0.051), Vector3(0.6, 0.07, 1.1)],
	"ring_show": [Vector3(-0.194, -0.057, -0.109), Vector3(0.7, -0.38, 0.8)],
	"ring_rub": [Vector3(-0.044, -0.016, -0.099), Vector3(0.4, 0.72, -1.07)],
	"tug": [Vector3(-0.064, 0.008, -0.048), Vector3(0.1, 0.82, -1.07)],
}
const UP := Vector3(0, 0.02, 0)

## Each fighter's own (always owned).
const BASE := {
	"berserker": "glove_tap", "counter_master": "tape_check", "combo_master": "shadowbox",
	"free_runner": "shake_out", "wise_guy": "pinky_ring", "elementalist": "palm_flame",
}
## Sold in the Soul Shop; any fighter can wear them.
const SHOP := ["fist_bump", "coin_flip", "juggler", "drum_roll", "windmill", "stretch", "finger_guns", "nose_pick"]

const ANIMS := {
	"glove_tap": {"name": "Glove Tap", "keys": [
		[0.3, {"r": ["meet", "fist"], "l": ["meet", "fist"], "sfx": ["hit", -16.0, 0.9]}],
		[0.14, {"r": ["apart", "fist"], "l": ["apart", "fist"]}],
		[0.12, {"r": ["meet", "fist"], "l": ["meet", "fist"], "sfx": ["hit", -14.0, 0.85]}],
		[0.3, {"l": ["side_in", "open"], "r": ["apart", "fist"]}],
		[0.12, {"r": ["meet", "fist"], "sfx": ["heavy", -12.0, 0.9]}],
		[0.3, {"l": ["side_in", "cup"]}],
	]},
	"tape_check": {"name": "Tape Check", "keys": [
		[0.4, {"r": ["back_face", "open"], "l": ["low", "relax"]}],
		[0.18, {"r": ["back_face", "fist"]}],
		[0.18, {"r": ["back_face", "wide"]}],
		[0.18, {"r": ["back_face", "fist"]}],
		[0.3, {"r": ["palm_face", "open"]}],
		[0.3, {"r": ["fist_up", "fist"], "l": ["tug", "pinch"], "sfx": ["draw", -18.0, 2.0]}],
		[0.25, {"l": ["tug", "pinch", Vector3(0.02, -0.03, 0.02)]}],
		[0.14, {"r": ["low", "loose"], "l": ["low", "loose"], "sfx": ["whoosh", -16.0, 1.5]}],
		[0.14, {"r": ["low", "relax", UP], "l": ["low", "relax", UP]}],
	]},
	"shadowbox": {"name": "Shadowbox", "keys": [
		[0.2, {"r": ["low", "loose"], "l": ["low", "loose"]}],
		[0.07, {"r": ["low", "loose", Vector3(0, 0.02, 0)], "l": ["low", "loose", Vector3(0, -0.015, 0)]}],
		[0.07, {"r": ["low", "loose", Vector3(0, -0.015, 0)], "l": ["low", "loose", Vector3(0, 0.02, 0)]}],
		[0.07, {"r": ["low", "loose", Vector3(0, 0.02, 0)], "l": ["low", "loose", Vector3(0, -0.015, 0)]}],
		[0.07, {"r": ["low", "loose", Vector3(0, -0.015, 0)], "l": ["low", "loose", Vector3(0, 0.02, 0)]}],
		[0.12, {"r": REST, "l": REST, "sfx": ["hit", -18.0, 1.7]}],
		[0.08, {"l": [Vector3(-0.05, 0.08, -0.12), Vector3(-0.2, 0.08, 0.25), "fist"], "trail": true}],
		[0.08, {"l": REST}],
		[0.08, {"r": [Vector3(-0.07, 0.08, -0.14), Vector3(-0.2, 0.12, 0.25), "fist"], "trail": true}],
		[0.08, {"r": REST}],
		[0.1, {"r": [Vector3(0.02, 0.1, -0.1), Vector3(-0.3, 0.7, 0.0), "fist"], "trail": true, "sfx": ["whoosh", -14.0, 1.4]}],
	]},
	"shake_out": {"name": "Shake Out", "keys": [
		[0.3, {"r": ["shake_low", "loose"], "l": ["shake_low", "loose"]}],
		[0.07, {"r": ["shake_low", "open", Vector3(0, 0.025, 0)], "l": ["shake_low", "relax", Vector3(0, -0.02, 0)]}],
		[0.07, {"r": ["shake_low", "relax", Vector3(0, -0.02, 0)], "l": ["shake_low", "open", Vector3(0, 0.025, 0)]}],
		[0.07, {"r": ["shake_low", "open", Vector3(0, 0.025, 0)], "l": ["shake_low", "relax", Vector3(0, -0.02, 0)]}],
		[0.07, {"r": ["shake_low", "relax", Vector3(0, -0.02, 0)], "l": ["shake_low", "open", Vector3(0, 0.025, 0)]}],
		[0.07, {"r": ["shake_low", "open", Vector3(0, 0.025, 0)], "l": ["shake_low", "relax", Vector3(0, -0.02, 0)]}],
		[0.07, {"r": ["shake_low", "relax", Vector3(0, -0.02, 0)], "l": ["shake_low", "open", Vector3(0, 0.025, 0)]}],
		[0.25, {"r": REST, "l": REST, "sfx": ["hit", -18.0, 1.6]}],
	]},
	"pinky_ring": {"name": "Pinky Ring", "keys": [
		[0.4, {"l": ["ring_show", "open"], "r": ["low", "relax"]}],
		[0.25, {"l": ["ring_show", "pinky_up"]}],
		[0.3, {"l": ["ring_turn", "pinky_up"]}],
		[0.3, {"l": ["ring_show", "pinky_up"], "sfx": ["coin", -16.0, 1.6]}],
		[0.1, {"l": ["ring_show", "pinky_wiggle"]}],
		[0.1, {"l": ["ring_show", "pinky_up"]}],
		[0.1, {"l": ["ring_show", "pinky_wiggle"]}],
		[0.1, {"l": ["ring_show", "pinky_up"], "sfx": ["coin", -18.0, 1.9]}],
		[0.3, {"l": ["ring_show", "relax"]}],
	]},
	"palm_flame": {"name": "Palm Flame", "keys": [
		[0.4, {"r": ["palm_up", "open"]}],
		[0.5, {"r": ["palm_up", "claw", UP], "prop": ["r", "palm", 0.02], "sfx": ["fire", -14.0, 1.4]}],
		[0.3, {"r": ["palm_up", "cup"], "l": ["palm_up", "cup"]}],
		[0.45, {"prop": ["l", "palm", 0.02, true], "r": ["palm_up_lift", "open"]}],
		[0.4, {"l": ["palm_up", "claw", UP], "r": REST}],
		[0.15, {"l": ["palm_up", "fist"], "hide_prop": true, "sfx": ["whoosh", -16.0, 0.7]}],
	], "prop": "flame"},
	"fist_bump": {"name": "Fist Bump", "keys": [
		[0.3, {"r": ["meet", "fist"], "l": ["meet", "fist"], "sfx": ["hit", -14.0, 1.3]}],
		[0.15, {"r": ["apart", "fist"], "l": ["apart", "fist"]}],
		[0.1, {"r": ["meet", "fist"], "l": ["meet", "fist"], "sfx": ["hit", -14.0, 1.5]}],
		[0.25, {"r": ["back_face", "wide"], "l": ["back_face", "wide"], "sfx": ["whoosh", -12.0, 1.1]}],
		[0.3, {"r": ["back_face", "loose", Vector3(0.02, -0.03, 0.0)], "l": ["back_face", "loose", Vector3(0.02, -0.03, 0.0)]}],
	]},
	"coin_flip": {"name": "Coin Flip", "keys": [
		[0.3, {"r": ["side_in", "flick_ready"], "prop": ["r", "thumb", 0.0]}],
		[0.1, {"r": ["side_in", "flick", UP], "sfx": ["coin", -12.0, 1.0], "prop": ["r", "thumb", 0.3]}],
		[0.45, {"r": ["palm_up", "cup"], "prop": ["r", "palm", 0.3]}],
		[0.4, {"prop": ["r", "palm", 0.01], "sfx": ["coin", -14.0, 1.3]}],
		[0.25, {"r": ["palm_up", "fist"]}],
	], "prop": "coin"},
	"juggler": {"name": "Juggler", "keys": [
		[0.3, {"r": ["palm_up", "cup"], "l": ["palm_up", "cup"], "prop": ["r", "palm", 0.03]}],
		[0.1, {"r": ["palm_up_lift", "open"]}],
		[0.45, {"r": ["palm_up", "cup"], "prop": ["l", "palm", 0.03, true]}],
		[0.1, {"l": ["palm_up_lift", "open"]}],
		[0.45, {"l": ["palm_up", "cup"], "prop": ["r", "palm", 0.03, true]}],
		[0.1, {"r": ["palm_up_lift", "open"]}],
		[0.45, {"r": ["palm_up", "claw"], "prop": ["l", "palm", 0.03, true]}],
		[0.2, {"l": ["palm_up", "claw"]}],
	], "prop": "skull"},
	"drum_roll": {"name": "Drum Roll", "hold": "bone", "keys": [
		[0.2, {"r": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0), "fist"], "l": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0), "fist"]}],
		[0.06, {"r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.06, {"r": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "l": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.55]}],
		[0.06, {"l": [Vector3(0.02, -0.12, 0.05), Vector3(0.4, 0.0, 0.0)], "r": [Vector3(0.02, -0.06, 0.04), Vector3(0.1, 0.0, 0.0)], "sfx": ["tick", -10.0, 0.6]}],
		[0.2, {"r": [Vector3(0.0, 0.06, 0.0), Vector3(-0.3, 0.0, 0.0)], "l": [Vector3(0.0, 0.06, 0.0), Vector3(-0.3, 0.0, 0.0)]}],
		[0.08, {"r": [Vector3(0.02, -0.14, 0.04), Vector3(0.5, 0.0, 0.0)], "l": [Vector3(0.02, -0.14, 0.04), Vector3(0.5, 0.0, 0.0)], "sfx": ["heavy", -14.0, 1.3]}],
	]},
	"windmill": {"name": "Windmill", "keys": [
		[0.2, {"r": [Vector3(0.05, 0.15, 0.1), Vector3(1.4, -0.4, 0.0), "open"]}],
		[0.15, {"r": [Vector3(0.1, 0.02, 0.1), Vector3(0.2, -1.0, 0.0), "open"], "trail": true}],
		[0.15, {"r": [Vector3(0.03, -0.15, 0.02), Vector3(-0.8, 0.0, 0.0), "fist"]}],
		[0.15, {"r": [Vector3(0.05, 0.15, 0.1), Vector3(1.4, -0.4, 0.0), "open"], "sfx": ["whoosh", -12.0, 0.9]}],
		[0.15, {"r": [Vector3(0.1, 0.02, 0.1), Vector3(0.2, -1.0, 0.0), "open"], "trail": true}],
		[0.15, {"r": [Vector3(0.03, -0.15, 0.02), Vector3(-0.8, 0.0, 0.0), "fist"]}],
		[0.15, {"r": [Vector3(-0.08, 0.08, -0.16), Vector3(-0.3, 0.3, 0.4), "fist"], "sfx": ["whoosh", -10.0, 1.2]}],
	]},
	"stretch": {"name": "Stretch", "keys": [
		[0.6, {"r": ["push_out", "wide"], "l": ["push_out", "wide"], "sfx": ["draw", -16.0, 0.7]}],
		[0.2, {"r": ["push_out", "open", Vector3(0, 0, -0.02)], "l": ["push_out", "open", Vector3(0, 0, -0.02)]}],
		[0.15, {"r": ["push_out", "ripple0"], "l": ["push_out", "ripple3"]}],
		[0.15, {"r": ["push_out", "ripple2"], "l": ["push_out", "ripple1"]}],
		[0.15, {"r": ["push_out", "wide"], "l": ["push_out", "wide"]}],
		[0.4, {"r": ["low", "loose"], "l": ["low", "loose"]}],
	]},
	"nose_pick": {"name": "Nose Pick", "keys": [
		[0.35, {"r": ["nose_near", "point"]}],
		[0.25, {"r": ["nose_in", "point"], "sfx": ["draw", -20.0, 1.8]}],
		[0.12, {"r": ["nose_in", "point", Vector3(0.005, 0.008, 0)]}],
		[0.12, {"r": ["nose_in", "point"]}],
		[0.3, {"r": ["nose_out", "point"], "prop": ["r", "index", 0.0]}],
		[0.25, {"r": ["nose_out", "flick_ready"], "prop": ["r", "index", 0.0]}],
		[0.1, {"r": ["nose_out", "flick"], "prop": ["r", "fling", 0.0, true], "sfx": ["whoosh", -16.0, 1.8]}],
		[0.35, {"r": ["nose_out", "relax"], "hide_prop": true}],
	], "prop": "booger"},
	"finger_guns": {"name": "Finger Guns", "keys": [
		[0.3, {"r": ["gun", "gun"]}],
		[0.08, {"r": ["gun_kick", "gun_fire"], "sfx": ["twang", -12.0, 1.6]}],
		[0.2, {"r": ["gun", "gun"]}],
		[0.25, {"l": ["gun", "gun"]}],
		[0.08, {"l": ["gun_kick", "gun_fire"], "sfx": ["twang", -12.0, 1.4]}],
		[0.2, {"l": ["gun", "gun"]}],
		[0.3, {"r": ["gun_kick", "point"], "l": ["gun_kick", "point"], "sfx": ["whoosh", -18.0, 0.8]}],
	]},
}


## A shape with every value filled in (f0-f3, f the average, t, tu, spread).
static func shape(id: String) -> Dictionary:
	var base: Dictionary = SHAPES.get(id, SHAPES.fist)
	var full := {"t": float(base.get("t", 1.0)), "tu": float(base.get("tu", 0.0)), "spread": float(base.get("spread", 0.0))}
	var total := 0.0
	for i in 4:
		full["f%d" % i] = float(base.get("f%d" % i, base.get("f", 1.0)))
		total += full["f%d" % i]
	full["f"] = total / 4.0
	return full


## Between two full shapes.
static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var out := {}
	for key in b:
		out[key] = lerpf(float(a.get(key, b[key])), float(b[key]), u)
	return out


static func name_of(id: String) -> String:
	return ANIMS.get(id, {}).get("name", id.capitalize())


## The fighter's own idle.
static func base_for(class_id: String) -> String:
	return BASE.get(class_id, "glove_tap")


## Total seconds an idle runs.
static func length(id: String) -> float:
	var total := 0.0
	for key in ANIMS.get(id, {}).get("keys", []):
		total += float(key[0])
	return total + 0.3


## What the fighter can pick: their own, then every bought one.
static func choices(class_id: String) -> Array:
	return [base_for(class_id)] + SHOP.filter(func(id: String) -> bool: return GameState.idles_bought.has(id))
