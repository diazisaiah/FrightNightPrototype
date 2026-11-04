class_name ItemModels
## The Crypt gear's 3D models (Crypt revamp plan, 2026-11-03): 5 sets x 4
## pieces, built the way hats are (Hats._b blocks in the game's block
## material), so gear and hats look like they belong together. Sizes are in
## units of u (1.0 in a card's preview window).
##
## Each block is painted with one of its set's palette roles (primary,
## secondary, metal, accent, trim). Rarity recolors the same model: common is
## dull and dingy; uncommon muted; rare full color; epic saturated with purple
## sparkles; legendary saturated with gold sparkles (Hats.sparkles).
##
## Origin at the piece's center; its front faces -Z.

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const SPARKLE := {"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.82, 0.3)}

## Palette roles per set.
const SETS := {
	"deadweight": {"name": "Deadweight", "primary": Color(0.62, 0.12, 0.1), "secondary": Color(0.24, 0.17, 0.14),
		"metal": Color(0.44, 0.44, 0.48), "accent": Color(0.9, 0.38, 0.18), "trim": Color(0.7, 0.68, 0.64)},
	"drowned": {"name": "Drowned", "primary": Color(0.14, 0.34, 0.6), "secondary": Color(0.09, 0.17, 0.26),
		"metal": Color(0.45, 0.66, 0.62), "accent": Color(0.32, 0.85, 0.78), "trim": Color(0.88, 0.9, 0.92)},
	"grandmaster": {"name": "Grandmaster's", "primary": Color(0.42, 0.18, 0.62), "secondary": Color(0.14, 0.09, 0.2),
		"metal": Color(0.78, 0.62, 0.28), "accent": Color(0.95, 0.82, 0.48), "trim": Color(0.92, 0.9, 0.84)},
	"iron_mike": {"name": "Iron Mike's", "primary": Color(0.92, 0.7, 0.14), "secondary": Color(0.1, 0.09, 0.09),
		"metal": Color(0.62, 0.62, 0.64), "accent": Color(0.82, 0.14, 0.12), "trim": Color(0.97, 0.95, 0.88)},
	"dead_money": {"name": "Dead Money", "primary": Color(0.16, 0.46, 0.24), "secondary": Color(0.09, 0.15, 0.11),
		"metal": Color(0.88, 0.7, 0.22), "accent": Color(0.7, 0.86, 0.56), "trim": Color(0.95, 0.92, 0.8)},
}
## Each set's piece names by slot (the plan's "(set) (piece)").
const PIECES := {
	"deadweight": {"gloves": "Knuckles", "wraps": "Bindings", "boots": "Treads", "charm": "Anchor"},
	"drowned": {"gloves": "Fists", "wraps": "Wraps", "boots": "Steps", "charm": "Pearl"},
	"grandmaster": {"gloves": "Hands", "wraps": "Wraps", "boots": "Slippers", "charm": "Seal"},
	"iron_mike": {"gloves": "Gloves", "wraps": "Wraps", "boots": "Boots", "charm": "Belt"},
	"dead_money": {"gloves": "Rings", "wraps": "Wraps", "boots": "Loafers", "charm": "Coin"},
}
## What draws an item to a set (until the gear system gives every item its
## set): its stats and specials, from the plan's set tables.
const SET_STATS := {
	"deadweight": ["heavy_bonus", "armor_pierce", "max_knuckles", "knuckles_percent", "defense", "flinch_reduction", "thorns",
		"shatter", "grit", "iron_will", "heal_on_kill"],
	"drowned": ["counter_bonus", "counter_window", "dodge_window", "graze_reduction", "slipknot", "champions_hands",
		"clean_read", "rhythm", "counter_heal"],
	"grandmaster": ["punch_speed", "damage_percent", "combo_step", "combo_window", "combo_cap", "free_punch_chance",
		"lunging_jab", "double_jab", "frenzy", "move_speed"],
	"iron_mike": ["finisher_bonus", "boss_damage", "ult_gain", "bone_breaker", "long_count", "gravewalker",
		"executioner", "jump_bonus", "sprint_bonus"],
	"dead_money": ["coin_bonus", "xp_bonus", "crit_chance", "crit_damage", "head_bonus", "damage", "gold_fever",
		"loaded_dice", "silver_tongue", "haggler", "lantern"],
}



## A piece as a Node3D of blocks (plus sparkles for epic and legendary).
static func build(set_id: String, slot: String, rarity := "rare", u := 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [set_id, slot]
	if not SETS.has(set_id):
		return root
	var p := _palette(set_id, rarity)
	match slot:
		"gloves":
			_gloves(root, u, p, set_id)
	if SPARKLE.has(rarity):
		Hats.sparkles(root, SPARKLE[rarity], 0.55 * u)
	return root


## An item's model: its set (item.set, else the set its stats lean to) and
## its slot, in its rarity.
static func build_for_item(item: Dictionary, u := 1.0) -> Node3D:
	var rarity: String = item.get("rarity", "rare")
	if not rarity in RARITIES:
		rarity = "epic" if rarity == "cursed" else "rare"
	return build(set_for(item), String(item.get("slot", "")), rarity, u)


static func set_for(item: Dictionary) -> String:
	if SETS.has(item.get("set", "")):
		return item.set
	var best := "deadweight"
	var best_score := -1.0
	var effects: Dictionary = item.get("effects", {})
	for set_id in SET_STATS:
		var score := 0.0
		for effect in effects:
			if effect in SET_STATS[set_id]:
				score += 1.0
		# Ties settle by name, so an item always looks the same.
		score += 0.01 * (hash(String(item.get("name", "")) + set_id) % 10) / 10.0
		if score > best_score:
			best_score = score
			best = set_id
	return best


## "Deadweight Knuckles".
static func piece_name(set_id: String, slot: String) -> String:
	return "%s %s" % [SETS[set_id].name, PIECES[set_id].get(slot, "")]



# --- The pieces -----------------------------------------------------------------

## A boxing glove standing on its cuff, fist up and tipped a little toward
## the viewer, thumb on the +X side. Rounded the way hats are: stacked blocks,
## each slice of the fist three crossed blocks so its corners step in. The
## thumb lies against the side of the fist, from the palm by the wrist up to
## its tip at the top front corner (a dark gap in the web between them); a
## dark cuff, a white edge and laces.
static func _gloves(root: Node3D, u: float, p: Dictionary, _set_id: String) -> void:
	var hide: Color = p.primary
	var cuff: Color = p.secondary
	# Built lying down (fingers to -Z, back of the hand up), then stood up.
	var glove := Node3D.new()
	glove.rotation = Vector3(1.25, 0, 0)
	root.add_child(glove)
	# The fist, front to back: [z, depth, width, height].
	for slice in [[-0.68, 0.04, 0.36, 0.34], [-0.63, 0.06, 0.52, 0.5], [-0.55, 0.1, 0.62, 0.58],
			[-0.4, 0.2, 0.68, 0.64], [-0.2, 0.2, 0.66, 0.62], [-0.03, 0.14, 0.62, 0.58],
			[0.09, 0.1, 0.56, 0.52], [0.18, 0.08, 0.5, 0.46]]:
		_rounded(glove, u, slice[0], slice[1], slice[2], slice[3], 0.0, hide)
	# Where the curled fingers tuck under, across the front.
	Hats._b(glove, u, Vector3(0.44, 0.025, 0.02), Vector3(0, -0.12, -0.705), hide.darkened(0.35))
	# The thumb against the +X side: from the palm by the wrist, up and
	# forward to its tip at the top front corner, standing out from the fist.
	Hats._b(glove, u, Vector3(0.18, 0.22, 0.38), Vector3(0.39, -0.1, -0.05), hide, Vector3(0.6, 0, 0))
	Hats._b(glove, u, Vector3(0.2, 0.24, 0.2), Vector3(0.4, 0.13, -0.31), hide, Vector3(0.25, 0, 0))
	# The dark gap in the web between the thumb and the fist.
	Hats._b(glove, u, Vector3(0.04, 0.05, 0.28), Vector3(0.335, 0.08, -0.14), cuff, Vector3(0.6, 0, 0))
	# The cuff: dark, a white edge at the end, white laces on the palm side.
	_rounded(glove, u, 0.32, 0.24, 0.48, 0.46, -0.01, cuff)
	_rounded(glove, u, 0.465, 0.06, 0.52, 0.5, -0.01, p.trim)
	Hats._b(glove, u, Vector3(0.08, 0.03, 0.22), Vector3(0, -0.245, 0.32), p.trim)


## A slice with stepped corners: a wide block, a tall one and one between,
## crossed.
static func _rounded(root: Node3D, u: float, z: float, depth: float, width: float, height: float, y: float, tint: Color) -> void:
	var step := minf(width, height) * 0.2
	# Slightly different depths, so no two blocks share a face (they'd flicker).
	Hats._b(root, u, Vector3(width, height - step, depth), Vector3(0, y, z), tint)
	Hats._b(root, u, Vector3(width - step, height, depth - 0.006), Vector3(0, y, z), tint)
	Hats._b(root, u, Vector3(width - step * 0.45, height - step * 0.45, depth - 0.012), Vector3(0, y, z), tint)


# --- Color ------------------------------------------------------------------------

## The set's roles recolored for a rarity.
static func _palette(set_id: String, rarity: String) -> Dictionary:
	var base: Dictionary = SETS[set_id]
	var out := {}
	for role in ["primary", "secondary", "metal", "accent", "trim"]:
		var c: Color = base[role]
		match rarity:
			"common":
				c = Color.from_hsv(c.h, c.s * 0.45, c.v * 0.72)
			"uncommon":
				c = Color.from_hsv(c.h, c.s * 0.75, c.v * 0.9)
			"epic":
				c = Color.from_hsv(c.h, minf(c.s * 1.25, 1.0), minf(c.v * 1.08, 1.0))
			"legendary":
				c = Color.from_hsv(c.h, minf(c.s * 1.3, 1.0), minf(c.v * 1.12, 1.0))
		out[role] = c
	return out
