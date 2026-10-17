class_name Hats
## The hat collection. Now and then an enemy spawns wearing a hat; uppercut
## it off (or finish the enemy with an uppercut) and it's yours, for a small
## permanent boost. Four legendary Yonker caps do nothing on their own; all
## four unlock Tony. Hats are built from blocks, sized to the wearer's head.

## Share of enemies that spawn wearing a hat.
const HAT_CHANCE := 0.02
## Legendary share of hats: starts here and grows with every hat that spawns
## without being one (bad-luck protection), resetting when one does. Always a
## legendary you're missing. ~22 hats per legendary; at a 2% hat rate
## (2026-10-16) about 125 bouts for all four.
const LEGENDARY_BASE := 0.01
const LEGENDARY_STEP := 0.0025
const RARITY_WEIGHTS := {"common": 60.0, "uncommon": 25.0, "rare": 11.0, "epic": 4.0}
## Chance an uppercut pops the hat off (finishing with one always does).
const POP_CHANCE := {"common": 0.6, "uncommon": 0.45, "rare": 0.3, "epic": 0.2, "legendary": 0.12}
## Souls for a hat you already own.
const DUPLICATE_SOULS := {"common": 1, "uncommon": 2, "rare": 3, "epic": 5, "legendary": 10}
## Skeletons love the Fruit Hat: when one rolls a hat, this often it's that.
const SKELETON_FRUIT := 0.25
## Hats are built in head widths, times this (bigger reads better and funnier).
const SIZE := 1.4
const FRUIT_SIZE := 1.3
const LEGENDARIES := ["yonker_brim", "yonker_no_brim", "brim_no_yonker", "no_yonker_no_brim"]

const CATALOG := {
	"party_hat": {"name": "Party Hat", "rarity": "common", "effects": {"damage_percent": 0.01},
		"desc": "Somebody's birthday. Not anymore."},
	"traffic_cone": {"name": "Traffic Cone", "rarity": "common", "effects": {"knuckles_percent": 0.02},
		"desc": "Stolen from a construction site. In the underworld."},
	"shower_cap": {"name": "Shower Cap", "rarity": "common", "effects": {"dodge_window": 0.02},
		"desc": "Ready for the rain of blows."},
	"propeller_beanie": {"name": "Propeller Beanie", "rarity": "common", "effects": {"move_speed": 0.03},
		"desc": "Doesn't fly. Doesn't help. Spins, though."},
	"lampshade": {"name": "Lampshade", "rarity": "common", "effects": {"coin_bonus": 0.03},
		"desc": "The life of the funeral."},
	"bucket": {"name": "Bucket", "rarity": "common", "effects": {"defense": 0.5},
		"desc": "It's a bucket."},
	"wig_black": {"name": "Strong Guy Wig (Black)", "rarity": "common", "effects": {"damage_percent": 0.015},
		"desc": "Spiky. Suspiciously heroic."},
	"wig_blonde": {"name": "Strong Guy Wig (Blonde)", "rarity": "uncommon", "effects": {"damage_percent": 0.025, "ult_gain": 0.02},
		"desc": "Took three episodes of screaming to put on."},
	"wig_blue": {"name": "Strong Guy Wig (Blue)", "rarity": "rare", "effects": {"damage_percent": 0.035, "ult_gain": 0.03},
		"desc": "Dyed. Don't tell anyone."},
	"wig_white": {"name": "Strong Guy Wig (White)", "rarity": "epic", "effects": {"dodge_window": 0.06, "counter_bonus": 0.08},
		"desc": "It moves on its own. So do you."},
	"bowler": {"name": "Bowler Hat", "rarity": "uncommon", "effects": {"counter_bonus": 0.05},
		"desc": "Very proper. Very dead."},
	"chef_toque": {"name": "Chef's Toque", "rarity": "uncommon", "effects": {"xp_bonus": 0.04},
		"desc": "Kiss the cook. He's undead."},
	"viking_helmet": {"name": "Viking Helmet", "rarity": "uncommon", "effects": {"heavy_bonus": 0.04},
		"desc": "Horns sold separately. Horns included."},
	"pirate_tricorn": {"name": "Pirate Tricorn", "rarity": "uncommon", "effects": {"coin_bonus": 0.05},
		"desc": "Arr. Then death. Then arr again."},
	"top_hat": {"name": "Top Hat", "rarity": "rare", "effects": {"damage_percent": 0.03},
		"desc": "There's a bunny in it. Don't ask about the magician."},
	"tinfoil_hat": {"name": "Tinfoil Hat", "rarity": "rare", "effects": {"dodge_window": 0.04},
		"desc": "They can't read your dodges now."},
	"hard_hat": {"name": "Hard Hat", "rarity": "rare", "effects": {"knuckles_percent": 0.04},
		"desc": "The gravedigger's. He won't be needing it."},
	"paper_crown": {"name": "Paper Crown", "rarity": "epic", "effects": {"xp_bonus": 0.06, "coin_bonus": 0.03},
		"desc": "From a fast-food joint. You are royalty now."},
	"witch_hat": {"name": "Witch's Hat", "rarity": "epic", "effects": {"ult_gain": 0.06},
		"desc": "Still warm. Don't think about it."},
	"reaper_hood": {"name": "Grim Reaper's Hood", "rarity": "epic", "effects": {"damage_percent": 0.04, "defense": 1.0},
		"desc": "He left it at the coat check."},
	"fruit_hat": {"name": "Fruit Hat", "rarity": "epic", "effects": {"knuckles_percent": 0.04, "heal_on_kill": 1.0},
		"desc": "Five servings a day. Too late for this guy."},
	"monkey_mask": {"name": "Big Monkey Mask", "rarity": "epic", "effects": {"damage_percent": 0.03, "dodge_window": 0.03},
		"desc": "Ook. The dead find it deeply unsettling."},
	"yonker_brim": {"name": "Yonker with Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"yonker_no_brim": {"name": "Yonker with No Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"brim_no_yonker": {"name": "Brim with No Yonker", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"no_yonker_no_brim": {"name": "No Yonker with No Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
}


static func info(id: String) -> Dictionary:
	return CATALOG.get(id, {})


static func color(id: String) -> Color:
	return Items.RARITIES[CATALOG[id].rarity].color


## The boost line for the popup and the Hat Rack.
static func boost_text(id: String) -> String:
	var effects: Dictionary = CATALOG[id].effects
	if effects.is_empty():
		return "Collect all four Yonkers..."
	return GameState.effect_text(effects, 1)


## Which hat (if any) a freshly spawned enemy wears. Bumps the bad-luck
## counter for non-legendary hats.
static func roll(skeleton: bool) -> String:
	if randf() >= HAT_CHANCE:
		return ""
	var missing := LEGENDARIES.filter(func(id: String) -> bool: return not GameState.hats.has(id))
	var legendary_chance := LEGENDARY_BASE + LEGENDARY_STEP * GameState.hat_pity
	if not missing.is_empty() and randf() < legendary_chance:
		GameState.hat_pity = 0
		return missing.pick_random()
	GameState.hat_pity += 1
	if skeleton and randf() < SKELETON_FRUIT:
		return "fruit_hat"
	var total := 0.0
	for weight in RARITY_WEIGHTS.values():
		total += weight
	var pick := randf() * total
	var rarity := "common"
	for key in RARITY_WEIGHTS:
		pick -= RARITY_WEIGHTS[key]
		if pick <= 0.0:
			rarity = key
			break
	var pool := CATALOG.keys().filter(func(id: String) -> bool: return CATALOG[id].rarity == rarity)
	return pool.pick_random()


# --- Building them ------------------------------------------------------------------

## A hat as a Node3D: its origin sits on top of the head, u is the head's width.
static func build(id: String, u: float) -> Node3D:
	var hat := Node3D.new()
	hat.name = "Hat"
	match id:
		"party_hat":
			for i in 5:
				var w := 0.62 - i * 0.13
				_b(hat, u, Vector3(w, 0.14, w), Vector3(0, 0.07 + i * 0.14, 0), Color(1.0, 0.3, 0.7) if i % 2 == 0 else Color(1.0, 0.85, 0.2))
			_b(hat, u, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.78, 0), Color(0.95, 0.95, 1.0))
		"traffic_cone":
			_b(hat, u, Vector3(1.0, 0.06, 1.0), Vector3(0, 0.03, 0), Color(1.0, 0.45, 0.05))
			for i in 5:
				var w := 0.72 - i * 0.12
				_b(hat, u, Vector3(w, 0.16, w), Vector3(0, 0.14 + i * 0.16, 0), Color(0.95, 0.95, 0.95) if i == 2 else Color(1.0, 0.45, 0.05))
		"shower_cap":
			_b(hat, u, Vector3(1.12, 0.26, 1.12), Vector3(0, 0.1, 0), Color(0.6, 0.85, 1.0))
			_b(hat, u, Vector3(1.2, 0.08, 1.2), Vector3(0, -0.02, 0), Color(0.85, 0.95, 1.0))
		"propeller_beanie":
			var colors := [Color(0.95, 0.2, 0.2), Color(0.2, 0.45, 1.0), Color(1.0, 0.85, 0.15), Color(0.2, 0.8, 0.3)]
			for i in 4:
				var x := -0.27 if i % 2 == 0 else 0.27
				var z := -0.27 if i < 2 else 0.27
				_b(hat, u, Vector3(0.54, 0.24, 0.54), Vector3(x, 0.1, z), colors[i])
			_b(hat, u, Vector3(0.06, 0.2, 0.06), Vector3(0, 0.32, 0), Color(0.3, 0.3, 0.3))
			var blades := Node3D.new()
			blades.name = "Spin"
			blades.position = Vector3(0, 0.43, 0) * u
			hat.add_child(blades)
			_b(blades, u, Vector3(0.9, 0.03, 0.14), Vector3.ZERO, Color(1.0, 0.85, 0.15))
			_b(blades, u, Vector3(0.14, 0.03, 0.9), Vector3.ZERO, Color(0.95, 0.2, 0.2))
		"lampshade":
			_b(hat, u, Vector3(0.95, 0.22, 0.95), Vector3(0, 0.1, 0), Color(0.95, 0.88, 0.7), Vector3(0, 0, 0.12))
			_b(hat, u, Vector3(0.72, 0.24, 0.72), Vector3(0.03, 0.32, 0), Color(0.95, 0.88, 0.7), Vector3(0, 0, 0.12))
			_b(hat, u, Vector3(0.98, 0.04, 0.98), Vector3(0, 0.0, 0), Color(0.75, 0.45, 0.2), Vector3(0, 0, 0.12))
		"bucket":
			_b(hat, u, Vector3(1.08, 0.62, 1.08), Vector3(0, 0.06, 0), Color(0.62, 0.64, 0.68), Vector3.ZERO, false, 0.35)
			_b(hat, u, Vector3(1.14, 0.06, 1.14), Vector3(0, -0.24, 0), Color(0.48, 0.5, 0.54), Vector3.ZERO, false, 0.35)
			_b(hat, u, Vector3(0.05, 0.05, 1.2), Vector3(0, 0.4, 0), Color(0.35, 0.35, 0.38), Vector3(0, 0, 0.0), false, 0.7)
		"bowler":
			_b(hat, u, Vector3(1.32, 0.05, 1.32), Vector3(0, 0.02, 0), Color(0.08, 0.07, 0.08))
			_b(hat, u, Vector3(0.92, 0.32, 0.92), Vector3(0, 0.2, 0), Color(0.1, 0.09, 0.1))
			_b(hat, u, Vector3(0.94, 0.07, 0.94), Vector3(0, 0.08, 0), Color(0.45, 0.1, 0.1))
		"chef_toque":
			_b(hat, u, Vector3(1.04, 0.18, 1.04), Vector3(0, 0.09, 0), Color(0.96, 0.96, 0.96))
			_b(hat, u, Vector3(1.22, 0.42, 1.22), Vector3(0, 0.42, 0), Color(1.0, 1.0, 1.0))
			_b(hat, u, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.68, 0), Color(1.0, 1.0, 1.0))
		"viking_helmet":
			_b(hat, u, Vector3(1.12, 0.32, 1.12), Vector3(0, 0.12, 0), Color(0.55, 0.56, 0.6), Vector3.ZERO, false, 0.7)
			_b(hat, u, Vector3(0.12, 0.36, 1.14), Vector3(0, 0.14, 0), Color(0.75, 0.6, 0.3))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.16, 0.42, 0.16), Vector3(0.6 * side, 0.32, 0), Color(0.95, 0.9, 0.78), Vector3(0, 0, -0.6 * side))
				_b(hat, u, Vector3(0.1, 0.2, 0.1), Vector3(0.75 * side, 0.55, 0), Color(0.95, 0.9, 0.78), Vector3(0, 0, -0.1 * side))
		"pirate_tricorn":
			_b(hat, u, Vector3(1.45, 0.07, 1.1), Vector3(0, 0.04, 0), Color(0.07, 0.06, 0.07))
			_b(hat, u, Vector3(0.95, 0.3, 0.85), Vector3(0, 0.2, 0), Color(0.08, 0.07, 0.08))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.14, 0.3, 1.0), Vector3(0.7 * side, 0.18, 0), Color(0.07, 0.06, 0.07), Vector3(0, 0, -0.5 * side))
			_b(hat, u, Vector3(0.2, 0.18, 0.04), Vector3(0, 0.22, -0.44), Color(0.95, 0.95, 0.92))
		"top_hat":
			_b(hat, u, Vector3(1.36, 0.05, 1.36), Vector3(0, 0.02, 0), Color(0.06, 0.05, 0.07))
			_b(hat, u, Vector3(0.86, 0.78, 0.86), Vector3(0, 0.43, 0), Color(0.08, 0.07, 0.09))
			_b(hat, u, Vector3(0.88, 0.1, 0.88), Vector3(0, 0.12, 0), Color(0.75, 0.1, 0.12))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.12, 0.42, 0.06), Vector3(0.12 * side, 0.98, 0), Color(0.98, 0.98, 0.98), Vector3(0, 0, -0.18 * side))
				_b(hat, u, Vector3(0.06, 0.3, 0.07), Vector3(0.12 * side, 0.98, -0.01), Color(1.0, 0.65, 0.75), Vector3(0, 0, -0.18 * side))
		"tinfoil_hat":
			for i in 4:
				var w := 1.0 - i * 0.22
				_b(hat, u, Vector3(w, 0.16, w), Vector3(0, 0.08 + i * 0.15, 0), Color(0.86, 0.88, 0.92), Vector3(0.12 * (i % 2), 0.4 * i, 0.08 * ((i + 1) % 2)), false, 0.35)
			_b(hat, u, Vector3(0.14, 0.16, 0.14), Vector3(0.05, 0.68, 0), Color(0.9, 0.92, 0.95), Vector3(0.3, 0, 0.3), false, 0.35)
		"hard_hat":
			_b(hat, u, Vector3(1.1, 0.34, 1.1), Vector3(0, 0.15, 0), Color(1.0, 0.82, 0.1))
			_b(hat, u, Vector3(1.18, 0.05, 1.3), Vector3(0, 0.0, -0.08), Color(1.0, 0.78, 0.08))
			_b(hat, u, Vector3(0.12, 0.12, 0.2), Vector3(0, 0.2, -0.58), Color(1.0, 0.95, 0.7), Vector3.ZERO, true)
		"paper_crown":
			_b(hat, u, Vector3(1.06, 0.2, 1.06), Vector3(0, 0.1, 0), Color(1.0, 0.82, 0.25))
			for i in 8:
				var a := i * TAU / 8.0
				_b(hat, u, Vector3(0.16, 0.22, 0.05), Vector3(sin(a) * 0.5, 0.3, cos(a) * 0.5), Color(1.0, 0.75, 0.15), Vector3(0, a, 0))
			_b(hat, u, Vector3(0.12, 0.1, 0.03), Vector3(0, 0.1, -0.54), Color(0.9, 0.15, 0.15))
		"witch_hat":
			_b(hat, u, Vector3(1.65, 0.05, 1.65), Vector3(0, 0.02, 0), Color(0.2, 0.08, 0.28))
			var lean := 0.0
			for i in 5:
				var w := 0.9 - i * 0.16
				lean += 0.04 * i
				_b(hat, u, Vector3(w, 0.22, w), Vector3(lean, 0.14 + i * 0.21, 0), Color(0.22, 0.09, 0.3))
			_b(hat, u, Vector3(0.92, 0.08, 0.92), Vector3(0, 0.08, 0), Color(0.55, 0.85, 0.3))
			_b(hat, u, Vector3(0.16, 0.12, 0.03), Vector3(0, 0.08, -0.47), Color(1.0, 0.85, 0.3))
		"reaper_hood":
			var cloth := Color(0.05, 0.045, 0.06)
			_b(hat, u, Vector3(1.24, 0.3, 1.2), Vector3(0, 0.08, 0.04), cloth)
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.14, 0.95, 1.2), Vector3(0.62 * side, -0.35, 0.04), cloth)
			_b(hat, u, Vector3(1.24, 0.95, 0.16), Vector3(0, -0.35, 0.6), cloth)
			_b(hat, u, Vector3(0.6, 0.3, 0.5), Vector3(0, 0.25, 0.5), cloth, Vector3(0.4, 0, 0))
		"fruit_hat":
			_fruit_hat(hat, u)
		"monkey_mask":
			_monkey_mask(hat, u)
		"wig_black":
			_strong_wig(hat, u, Color(0.13, 0.13, 0.16), false)
		"wig_blonde":
			_strong_wig(hat, u, Color(1.0, 0.86, 0.28), true)
		"wig_blue":
			_strong_wig(hat, u, Color(0.25, 0.6, 1.0), true)
		"wig_white":
			_strong_wig(hat, u, Color(0.92, 0.94, 1.0), true)
		"yonker_brim", "yonker_no_brim":
			_yonker_cap(hat, u, id == "yonker_brim")
		"brim_no_yonker":
			_b(hat, u, Vector3(0.9, 0.05, 0.62), Vector3(0, 0.2, -0.62), Color(0.08, 0.12, 0.3))
		"no_yonker_no_brim":
			pass  # It's nothing. The legendary sparkle is the only clue.
	return hat


## The navy Yonker cap: a dome with a stitched white Y, brim optional.
static func _yonker_cap(hat: Node3D, u: float, brim: bool) -> void:
	var navy := Color(0.08, 0.12, 0.3)
	_b(hat, u, Vector3(1.1, 0.3, 1.1), Vector3(0, 0.12, 0), navy)
	_b(hat, u, Vector3(0.82, 0.12, 0.82), Vector3(0, 0.32, 0), navy)
	_b(hat, u, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.4, 0), navy)
	if brim:
		_b(hat, u, Vector3(0.9, 0.05, 0.62), Vector3(0, 0.0, -0.78), navy)
	# The Y.
	var white := Color(0.97, 0.97, 0.97)
	_b(hat, u, Vector3(0.05, 0.12, 0.03), Vector3(0, 0.08, -0.56), white)
	_b(hat, u, Vector3(0.05, 0.1, 0.03), Vector3(-0.05, 0.18, -0.56), white, Vector3(0, 0, 0.6))
	_b(hat, u, Vector3(0.05, 0.1, 0.03), Vector3(0.05, 0.18, -0.56), white, Vector3(0, 0, -0.6))


## The strong guy's hair: a cap down the back of the head, bangs over the
## brow and big blocky spikes. The base (black) look fans out every way; the
## powered-up colors stand straight up and taller.
static func _strong_wig(hat: Node3D, u: float, tint: Color, powered: bool) -> void:
	var shade := tint.darkened(0.25)
	_b(hat, u, Vector3(1.08, 0.24, 1.08), Vector3(0, 0.02, 0.02), tint)
	_b(hat, u, Vector3(1.08, 0.62, 0.22), Vector3(0, -0.26, 0.46), shade)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.14, 0.42, 0.7), Vector3(0.5 * side, -0.14, 0.12), shade)
	# Bangs: three points hanging over the brow.
	for i in 3:
		var x := (i - 1) * 0.26
		_spike(hat, u, Vector3(x, -0.02, -0.5), Vector3(PI - 0.25, 0, x * 0.9), 0.32, 0.2, tint)
	# The spikes: [base, tilt (x back, z out), length].
	var spikes := [
		[Vector3(0, 0.12, 0.0), Vector3(0.35, 0, 0), 0.7],
		[Vector3(-0.3, 0.1, 0.05), Vector3(0.2, 0, 0.75), 0.62],
		[Vector3(0.3, 0.1, 0.05), Vector3(0.2, 0, -0.75), 0.62],
		[Vector3(-0.42, 0.0, 0.2), Vector3(0.5, 0, 1.25), 0.55],
		[Vector3(0.42, 0.0, 0.2), Vector3(0.5, 0, -1.25), 0.55],
		[Vector3(-0.18, 0.08, 0.35), Vector3(1.0, 0, 0.45), 0.58],
		[Vector3(0.18, 0.08, 0.35), Vector3(1.0, 0, -0.45), 0.58],
		[Vector3(0, 0.0, 0.48), Vector3(1.35, 0, 0), 0.52],
		[Vector3(-0.2, 0.1, -0.25), Vector3(-0.35, 0, 0.4), 0.45],
		[Vector3(0.2, 0.1, -0.25), Vector3(-0.35, 0, -0.4), 0.45],
	]
	for i in spikes.size():
		var spike: Array = spikes[i]
		var tilt: Vector3 = spike[1]
		var length: float = spike[2]
		tilt *= 0.45 if powered else 0.8
		length *= 1.45 if powered else 1.15
		_spike(hat, u, spike[0], tilt, length, 0.4, tint if i % 2 == 0 else tint.lightened(0.08))


## One blocky spike of hair: three blocks narrowing to a point along its +Y.
static func _spike(hat: Node3D, u: float, base: Vector3, tilt: Vector3, length: float, width: float, tint: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = base * u
	pivot.rotation = tilt
	hat.add_child(pivot)
	for k in 3:
		var w := width * (1.0 - k * 0.32)
		var h := length / 3.0
		_b(pivot, u, Vector3(w, h * 1.05, w), Vector3(0, h * (k + 0.5), 0), tint)


## A big rubber monkey head pulled over the whole head: brown fur, a tan face
## with a heavy brow, wide eyes, a big grinning muzzle and round ears.
static func _monkey_mask(hat: Node3D, u: float) -> void:
	var fur := Color(0.36, 0.22, 0.12)
	var fur_dark := Color(0.26, 0.15, 0.08)
	var face := Color(0.86, 0.68, 0.5)
	var dark := Color(0.08, 0.05, 0.04)
	# The head: bigger than the wearer's, down over the face.
	_b(hat, u, Vector3(1.04, 1.0, 1.0), Vector3(0, -0.3, 0.02), fur)
	_b(hat, u, Vector3(0.3, 0.16, 0.3), Vector3(0, 0.24, 0.05), fur_dark)  # A tuft on top.
	_b(hat, u, Vector3(0.16, 0.12, 0.16), Vector3(0.06, 0.34, 0.02), fur_dark)
	# The face plate, brow and eyes.
	_b(hat, u, Vector3(0.8, 0.66, 0.08), Vector3(0, -0.36, -0.5), face)
	_b(hat, u, Vector3(0.84, 0.12, 0.14), Vector3(0, -0.06, -0.52), fur_dark)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.18, 0.16, 0.04), Vector3(0.18 * side, -0.2, -0.55), Color(0.97, 0.95, 0.9))
		_b(hat, u, Vector3(0.09, 0.11, 0.04), Vector3(0.16 * side, -0.21, -0.57), dark)
		_b(hat, u, Vector3(0.03, 0.03, 0.02), Vector3(0.14 * side, -0.18, -0.59), Color(1, 1, 1))
	# The muzzle: a big snout with nostrils and a toothy grin.
	_b(hat, u, Vector3(0.6, 0.34, 0.24), Vector3(0, -0.56, -0.6), face.darkened(0.06))
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.07, 0.05, 0.03), Vector3(0.08 * side, -0.46, -0.73), dark)
	_b(hat, u, Vector3(0.44, 0.09, 0.03), Vector3(0, -0.62, -0.72), dark)
	_b(hat, u, Vector3(0.36, 0.05, 0.03), Vector3(0, -0.6, -0.735), Color(0.97, 0.95, 0.9))
	# Big round ears, tan inside.
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.2, 0.44, 0.4), Vector3(0.62 * side, -0.24, 0.02), fur)
		_b(hat, u, Vector3(0.06, 0.3, 0.26), Vector3(0.73 * side, -0.24, 0.0), face.darkened(0.1))


## A towering fruit basket on a ruffled hot-pink brim, ribbons trailing.
static func _fruit_hat(hat: Node3D, u: float) -> void:
	var pink := Color(1.0, 0.2, 0.6)
	var yellow := Color(1.0, 0.92, 0.35)
	_b(hat, u, Vector3(1.5, 0.07, 1.5), Vector3(0, 0.02, 0), pink)
	for i in 10:
		var a := i * TAU / 10.0
		_b(hat, u, Vector3(0.36, 0.14, 0.12), Vector3(sin(a) * 0.72, 0.06 + (i % 2) * 0.04, cos(a) * 0.72), pink if i % 2 == 0 else yellow, Vector3(0, a, 0.3))
	# Ribbons down one side.
	_b(hat, u, Vector3(0.14, 0.9, 0.08), Vector3(0.62, -0.42, 0.1), pink, Vector3(0, 0, 0.12))
	_b(hat, u, Vector3(0.12, 0.6, 0.08), Vector3(-0.66, -0.28, 0.05), yellow, Vector3(0, 0, -0.1))
	# The basket.
	_b(hat, u, Vector3(1.0, 0.34, 1.0), Vector3(0, 0.24, 0), Color(0.72, 0.5, 0.25))
	_b(hat, u, Vector3(1.06, 0.06, 1.06), Vector3(0, 0.4, 0), Color(0.6, 0.4, 0.18))
	# The fruit, piled up.
	_b(hat, u, Vector3(0.32, 0.32, 0.32), Vector3(-0.2, 0.58, -0.15), Color(1.0, 0.55, 0.1))  # Orange.
	_b(hat, u, Vector3(0.3, 0.3, 0.3), Vector3(0.22, 0.6, -0.12), Color(1.0, 0.62, 0.15))  # Orange.
	_b(hat, u, Vector3(0.26, 0.36, 0.26), Vector3(0.0, 0.72, 0.15), Color(0.95, 0.82, 0.3))  # Pear.
	_b(hat, u, Vector3(0.5, 0.12, 0.14), Vector3(0.05, 0.52, -0.4), Color(1.0, 0.9, 0.2), Vector3(0, 0.3, 0.2))  # Banana.
	for g in [Vector3(0.32, 0.5, 0.25), Vector3(0.4, 0.5, 0.15), Vector3(0.36, 0.42, 0.3), Vector3(0.44, 0.4, 0.22)]:
		_b(hat, u, Vector3(0.11, 0.11, 0.11), g, Color(0.4, 0.15, 0.45))  # Grapes.
	for g in [Vector3(-0.38, 0.48, 0.2), Vector3(-0.3, 0.42, 0.3), Vector3(-0.42, 0.4, 0.3)]:
		_b(hat, u, Vector3(0.11, 0.11, 0.11), g, Color(0.6, 0.85, 0.45))  # Green grapes.
	for c in [Vector3(-0.08, 0.6, -0.42), Vector3(0.0, 0.62, -0.46)]:
		_b(hat, u, Vector3(0.09, 0.09, 0.09), c, Color(0.85, 0.05, 0.1))  # Cherries.
	_b(hat, u, Vector3(0.2, 0.2, 0.16), Vector3(0.18, 0.46, -0.42), Color(0.85, 0.1, 0.15))  # Strawberry.
	# Pineapple leaves fanning out of the top.
	var leaf := Color(0.18, 0.55, 0.2)
	for i in 6:
		var a := i * TAU / 6.0
		_b(hat, u, Vector3(0.08, 0.42, 0.06), Vector3(sin(a) * 0.12, 1.0, cos(a) * 0.12), leaf, Vector3(cos(a) * 0.55, 0, -sin(a) * 0.55))
	_b(hat, u, Vector3(0.08, 0.5, 0.06), Vector3(0, 1.08, 0), leaf)


## One block of a hat: size and position in head widths.
static func _b(parent: Node3D, u: float, size: Vector3, pos: Vector3, tint: Color, rot := Vector3.ZERO, glow := false, metal := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size * u
	mesh.material = Enemy._glow_material(tint) if glow else Look.block_material(tint, metal)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos * u
	part.rotation = rot
	parent.add_child(part)
	return part


## A sparkle cloud in the hat's rarity color (legendaries on enemies, the popup).
static func sparkles(parent: Node3D, tint: Color, radius := 0.35) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.gravity = Vector3(0, 0.3, 0)
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.2
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.lightened(0.5), 0.0))
	ramp.add_point(0.3, Color(tint.lightened(0.3), 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	particles.color_ramp = ramp
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.035
	var material := Enemy._glow_material(tint)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	parent.add_child(particles)
	return particles
