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
		"wraps":
			_wraps(root, u, p, set_id)
		"boots":
			_boots(root, u, p, set_id)
		"charm":
			_charm(root, u, p, set_id)
	if SPARKLE.has(rarity):
		var bounds := HatPopup._bounds(root, Transform3D.IDENTITY)
		_sparkles(root, u, rarity).position = bounds.get_center()
	return root


## Epic: small purple sparkles. Legendary: more, bigger gold ones. Their own
## particles (Hats.sparkles lightens toward white and glows, which washes the
## color out): unshaded, the rarity's color all the way, fading in and out.
static func _sparkles(root: Node3D, u: float, rarity: String) -> CPUParticles3D:
	var legendary := rarity == "legendary"
	var tint: Color = SPARKLE[rarity]
	var particles := CPUParticles3D.new()
	particles.name = "Sparkles"
	particles.amount = 44 if legendary else 20
	particles.lifetime = 1.5 if legendary else 1.2
	particles.preprocess = 1.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = (0.66 if legendary else 0.58) * u
	particles.gravity = Vector3(0, 0.25, 0)
	particles.initial_velocity_min = 0.03
	particles.initial_velocity_max = 0.25 if legendary else 0.15
	particles.angular_velocity_min = -90.0
	particles.angular_velocity_max = 90.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint, 0.0))
	ramp.add_point(0.25, Color(tint.lightened(0.15), 1.0))
	ramp.add_point(0.6, Color(tint, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint.darkened(0.1), 0.0))
	particles.color_ramp = ramp
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * (0.07 if legendary else 0.045) * u
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	root.add_child(particles)
	return particles


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
## Looks (planned 2026-11-04): each set has its color and one clear signature
## per piece.
##   Deadweight (red, heavy): Knuckles - red glove, riveted iron knuckle plate,
##     iron cuff edge; Bindings - dark red leather roll in iron chain links;
##     Treads - heavy red boot, iron toe cap, thick tread sole, iron strap;
##     Anchor - iron anchor, red rope round the shank.
##   Drowned (blue, water): Fists - blue glove, seafoam wave stripe, barnacles;
##     Wraps - blue roll, seafoam bands, hanging seaweed, a pearl bead; Steps -
##     low blue boot, seafoam cross straps, white sole; Pearl - open clam shell.
##   Grandmaster's (purple, speed): Hands - fingerless glove, ivory fingertips,
##     gold diamond; Wraps - purple silk, gold stripes, gold tassel; Slippers -
##     kung fu slippers, black sole, gold trim; Seal - jade stamp, gold lion.
##   Iron Mike's (yellow, champ): Gloves - yellow, black cuff, red band, white
##     laces; Wraps - white tape, yellow band, red tape end; Boots - tall
##     yellow boxing boots, white laces; Belt - championship belt, red gem.
##   Dead Money (green, greed): Rings - gold four-ring knuckle duster, green
##     gems; Wraps - green roll, paper bill band, gold money clip; Loafers -
##     green loafers, gold penny strap; Coin - big gold coin with a green $.
## Every wrap has its loose end looping up out of the top.

const METAL := 0.6


static func _b(parent: Node3D, u: float, size: Vector3, pos: Vector3, tint: Color, rot := Vector3.ZERO, metal := 0.0) -> MeshInstance3D:
	return Hats._b(parent, u, size, pos, tint, rot, false, metal)


static func _gem(parent: Node3D, u: float, size: Vector3, pos: Vector3, tint: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return Hats._b(parent, u, size, pos, tint, rot, true)


## A slice facing Z with stepped corners: a wide block, a tall one and one
## between, crossed (slightly different depths so no two share a face).
static func _rounded(root: Node3D, u: float, z: float, depth: float, width: float, height: float, y: float, tint: Color, x := 0.0, metal := 0.0) -> void:
	var step := minf(width, height) * 0.2
	_b(root, u, Vector3(width, height - step, depth), Vector3(x, y, z), tint, Vector3.ZERO, metal)
	_b(root, u, Vector3(width - step, height, depth - 0.006), Vector3(x, y, z), tint, Vector3.ZERO, metal)
	_b(root, u, Vector3(width - step * 0.45, height - step * 0.45, depth - 0.012), Vector3(x, y, z), tint, Vector3.ZERO, metal)


## The same, lying flat (a slice of a roll or a sole): thickness along Y.
static func _disc(root: Node3D, u: float, y: float, thick: float, width: float, depth: float, tint: Color, x := 0.0, z := 0.0, metal := 0.0) -> void:
	var step := minf(width, depth) * 0.2
	_b(root, u, Vector3(width, thick, depth - step), Vector3(x, y, z), tint, Vector3.ZERO, metal)
	_b(root, u, Vector3(width - step, thick - 0.006, depth), Vector3(x, y, z), tint, Vector3.ZERO, metal)
	_b(root, u, Vector3(width - step * 0.45, thick - 0.012, depth - step * 0.45), Vector3(x, y, z), tint, Vector3.ZERO, metal)


## A round plate facing Z: five crossed blocks along a circle's outline.
static func _round_plate(root: Node3D, u: float, z: float, depth: float, diameter: float, tint: Color, metal := 0.0) -> void:
	var i := 0
	for wh in [[1.0, 0.44], [0.92, 0.7], [0.8, 0.84], [0.64, 0.94], [0.44, 1.0]]:
		_b(root, u, Vector3(diameter * wh[0], diameter * wh[1], depth - 0.004 * i), Vector3(0, 0, z), tint, Vector3.ZERO, metal)
		i += 1


# Gloves --------------------------------------------------------------------------

static func _gloves(root: Node3D, u: float, p: Dictionary, set_id: String) -> void:
	match set_id:
		"deadweight":
			var g := _glove_base(root, u, p.primary, p.secondary, p.metal, p.trim, METAL)
			# A riveted iron plate over the knuckles.
			_b(g, u, Vector3(0.5, 0.2, 0.05), Vector3(0, 0.15, -0.69), p.metal, Vector3.ZERO, METAL)
			_b(g, u, Vector3(0.54, 0.05, 0.2), Vector3(0, 0.325, -0.52), p.metal, Vector3.ZERO, METAL)
			for x in [-0.15, 0.0, 0.15]:
				_b(g, u, Vector3(0.05, 0.05, 0.025), Vector3(x, 0.16, -0.725), p.trim, Vector3.ZERO, METAL)
		"drowned":
			var g := _glove_base(root, u, p.primary, p.secondary, p.trim, p.trim)
			# A seafoam wave along the outer side, barnacles on the back.
			for i in 6:
				_b(g, u, Vector3(0.02, 0.06, 0.1), Vector3(-0.345, 0.07 if i % 2 == 0 else 0.0, -0.5 + i * 0.1), p.accent)
			for spot in [[-0.12, -0.3, 0.07], [0.06, -0.14, 0.06], [-0.04, 0.02, 0.05], [0.15, -0.42, 0.05]]:
				_b(g, u, Vector3(spot[2], 0.05, spot[2]), Vector3(spot[0], 0.33, spot[1]), p.trim)
		"grandmaster":
			var g := _glove_base(root, u, p.primary, p.secondary, p.metal, p.trim, METAL)
			# Fingerless: the fingertips curl out under the front.
			for x in [-0.18, -0.06, 0.06, 0.18]:
				_b(g, u, Vector3(0.11, 0.11, 0.08), Vector3(x, -0.17, -0.68), p.trim)
			# A gold diamond on the back, a gold band round the wrist.
			_b(g, u, Vector3(0.13, 0.03, 0.13), Vector3(0, 0.335, -0.3), p.metal, Vector3(0, PI / 4.0, 0), METAL)
			_rounded(g, u, 0.27, 0.05, 0.5, 0.48, -0.01, p.metal, 0.0, METAL)
		"iron_mike":
			var g := _glove_base(root, u, p.primary, p.secondary, p.trim, p.trim)
			# The red band round the black cuff.
			_rounded(g, u, 0.31, 0.06, 0.5, 0.48, -0.01, p.accent)
		"dead_money":
			_knuckle_duster(root, u, p)


## The boxing glove every set's glove starts from, standing on its cuff with
## the fist up and tipped toward the viewer: built lying down (fingers to -Z,
## back of the hand up, thumb on +X), then stood up. Returns the lying frame,
## so a set can add its details in it.
static func _glove_base(root: Node3D, u: float, hide: Color, cuff: Color, edge: Color, lace: Color, edge_metal := 0.0) -> Node3D:
	var glove := Node3D.new()
	glove.rotation = Vector3(1.25, 0, 0)
	root.add_child(glove)
	# The fist, front to back: [z, depth, width, height].
	for slice in [[-0.68, 0.04, 0.36, 0.34], [-0.63, 0.06, 0.52, 0.5], [-0.55, 0.1, 0.62, 0.58],
			[-0.4, 0.2, 0.68, 0.64], [-0.2, 0.2, 0.66, 0.62], [-0.03, 0.14, 0.62, 0.58],
			[0.09, 0.1, 0.56, 0.52], [0.18, 0.08, 0.5, 0.46]]:
		_rounded(glove, u, slice[0], slice[1], slice[2], slice[3], 0.0, hide)
	# Where the curled fingers tuck under, across the front.
	_b(glove, u, Vector3(0.44, 0.025, 0.02), Vector3(0, -0.12, -0.705), hide.darkened(0.35))
	# The thumb against the +X side: from the palm by the wrist, up and
	# forward to its tip at the top front corner, standing out from the fist.
	_b(glove, u, Vector3(0.18, 0.22, 0.38), Vector3(0.39, -0.1, -0.05), hide, Vector3(0.6, 0, 0))
	_b(glove, u, Vector3(0.2, 0.24, 0.2), Vector3(0.4, 0.13, -0.31), hide, Vector3(0.25, 0, 0))
	# The dark gap in the web between the thumb and the fist.
	_b(glove, u, Vector3(0.04, 0.05, 0.28), Vector3(0.335, 0.08, -0.14), cuff.darkened(0.3), Vector3(0.6, 0, 0))
	# The cuff, its edge, and laces on the palm side.
	_rounded(glove, u, 0.32, 0.24, 0.48, 0.46, -0.01, cuff)
	_rounded(glove, u, 0.465, 0.06, 0.52, 0.5, -0.01, edge, 0.0, edge_metal)
	_b(glove, u, Vector3(0.08, 0.03, 0.22), Vector3(0, -0.245, 0.32), lace)
	return glove


## Dead Money's Rings: a gold four-ring knuckle duster, a green gem on each
## ring, a green grip under them.
static func _knuckle_duster(root: Node3D, u: float, p: Dictionary) -> void:
	var gold: Color = p.metal
	for i in 4:
		var x := -0.3 + i * 0.2
		_b(root, u, Vector3(0.2, 0.06, 0.12), Vector3(x, 0.12, 0), gold, Vector3.ZERO, METAL)
		_b(root, u, Vector3(0.19, 0.05, 0.11), Vector3(x, -0.08, 0), gold, Vector3.ZERO, METAL)
		_b(root, u, Vector3(0.05, 0.2, 0.115), Vector3(x - 0.075, 0.02, 0), gold, Vector3.ZERO, METAL)
		_b(root, u, Vector3(0.08, 0.05, 0.08), Vector3(x, 0.17, 0), p.primary.lightened(0.3), Vector3.ZERO, 0.25)
	_b(root, u, Vector3(0.05, 0.2, 0.115), Vector3(0.375, 0.02, 0), gold, Vector3.ZERO, METAL)
	# The grip bar under the rings, its curled ends, a green wrap.
	_b(root, u, Vector3(0.74, 0.12, 0.14), Vector3(0, -0.2, 0), gold, Vector3.ZERO, METAL)
	for side in [-1.0, 1.0]:
		_b(root, u, Vector3(0.1, 0.14, 0.14), Vector3(0.4 * side, -0.15, 0), gold, Vector3(0, 0, -0.5 * side), METAL)
	_b(root, u, Vector3(0.56, 0.05, 0.15), Vector3(0, -0.275, 0), p.primary)


# Wraps ---------------------------------------------------------------------------

## A rolled hand wrap standing up: stacked slices in two shades so the turns
## show, a dark core on top, and the loose end looping up out of the top.
static func _wrap_roll(root: Node3D, u: float, cloth: Color, end_color: Color) -> void:
	var turns := [[-0.3, 0.52], [-0.18, 0.56], [-0.06, 0.58], [0.06, 0.58], [0.18, 0.56], [0.28, 0.5]]
	for i in turns.size():
		var shade := cloth.lightened(0.06) if i % 2 == 0 else cloth.darkened(0.06)
		_disc(root, u, turns[i][0], 0.12 if i < turns.size() - 1 else 0.08, turns[i][1], turns[i][1], shade)
	_disc(root, u, 0.325, 0.02, 0.22, 0.22, cloth.darkened(0.45))
	# The loose end: up out of the top, over and back down (a thin loop).
	_b(root, u, Vector3(0.035, 0.24, 0.16), Vector3(0.22, 0.42, 0.0), end_color, Vector3(0, 0, -0.12))
	_b(root, u, Vector3(0.18, 0.035, 0.16), Vector3(0.13, 0.54, 0.0), end_color, Vector3(0, 0, 0.08))
	_b(root, u, Vector3(0.035, 0.14, 0.16), Vector3(0.04, 0.47, 0.0), end_color, Vector3(0, 0, 0.18))


static func _wraps(root: Node3D, u: float, p: Dictionary, set_id: String) -> void:
	match set_id:
		"deadweight":
			_wrap_roll(root, u, p.primary.darkened(0.25), p.primary)
			# Iron chain links round the middle.
			for i in 8:
				var angle := TAU * i / 8.0
				_b(root, u, Vector3(0.1, 0.07, 0.04), Vector3(sin(angle) * 0.3, 0.0 + (0.02 if i % 2 == 0 else -0.02), cos(angle) * 0.3),
						p.metal, Vector3(0, angle, 0), METAL)
		"drowned":
			_wrap_roll(root, u, p.primary, p.primary.lightened(0.1))
			_disc(root, u, -0.12, 0.04, 0.6, 0.6, p.accent)
			_disc(root, u, 0.12, 0.04, 0.6, 0.6, p.accent)
			# Seaweed hanging off one side, a pearl bead on the band.
			for i in 4:
				_b(root, u, Vector3(0.05, 0.12, 0.03), Vector3(-0.29 - i * 0.025, 0.05 - i * 0.11, -0.12), p.accent.darkened(0.35), Vector3(0, 0, 0.25 * (i % 2 * 2 - 1)))
			_b(root, u, Vector3(0.09, 0.09, 0.09), Vector3(0.0, -0.12, -0.31), p.trim, Vector3.ZERO, 0.3)
		"grandmaster":
			_wrap_roll(root, u, p.primary, p.primary)
			_disc(root, u, -0.15, 0.03, 0.6, 0.6, p.metal, 0.0, 0.0, METAL)
			_disc(root, u, 0.09, 0.03, 0.6, 0.6, p.metal, 0.0, 0.0, METAL)
			# A gold tassel off the loose end.
			_b(root, u, Vector3(0.05, 0.05, 0.05), Vector3(0.03, 0.39, 0.0), p.metal, Vector3.ZERO, METAL)
			_b(root, u, Vector3(0.07, 0.12, 0.07), Vector3(0.03, 0.31, -0.02), p.accent)
		"iron_mike":
			# White fight tape, a yellow band, the red end torn off the roll.
			_wrap_roll(root, u, p.trim, p.accent)
			_disc(root, u, 0.0, 0.08, 0.6, 0.6, p.primary)
		"dead_money":
			_wrap_roll(root, u, p.primary, p.primary.lightened(0.1))
			# A paper bill band and a gold money clip.
			_disc(root, u, 0.0, 0.14, 0.6, 0.6, p.accent)
			_b(root, u, Vector3(0.12, 0.2, 0.04), Vector3(0.0, 0.02, -0.31), p.metal, Vector3.ZERO, METAL)
			_b(root, u, Vector3(0.08, 0.08, 0.02), Vector3(0.0, 0.02, -0.33), p.primary.darkened(0.3))


# Boots ---------------------------------------------------------------------------

## A boot, toe to the front (-Z): a sole, a foot built from slices, and a
## shaft `shaft` tall (0 for a slipper). Returns nothing; sets add on top.
static func _boot_base(root: Node3D, u: float, upper: Color, sole: Color, shaft: float, sole_thick := 0.07) -> void:
	_b(root, u, Vector3(0.36, sole_thick, 0.84), Vector3(0, -0.4 + sole_thick / 2.0 - 0.035, -0.08), sole)
	for slice in [[-0.47, 0.06, 0.26, 0.18, -0.29], [-0.39, 0.12, 0.32, 0.24, -0.26], [-0.21, 0.26, 0.36, 0.3, -0.23],
			[0.05, 0.26, 0.36, 0.34, -0.21], [0.23, 0.1, 0.34, 0.32, -0.21]]:
		_rounded(root, u, slice[0], slice[1], slice[2], slice[3], slice[4], upper)
	if shaft > 0.0:
		var top := -0.06 + shaft
		var y := -0.04
		while y < top - 0.001:
			var h := minf(0.12, top - y)
			_disc(root, u, y + h / 2.0, h, 0.36, 0.36, upper, 0.0, 0.1)
			y += h
		_disc(root, u, top + 0.005, 0.01, 0.26, 0.26, upper.darkened(0.5), 0.0, 0.1)
	else:
		_disc(root, u, -0.06, 0.012, 0.24, 0.3, upper.darkened(0.5), 0.0, 0.1)


static func _boots(root: Node3D, u: float, p: Dictionary, set_id: String) -> void:
	match set_id:
		"deadweight":
			_boot_base(root, u, p.primary, p.secondary, 0.36, 0.11)
			# An iron toe cap, tread under the sole, an iron strap on the shaft.
			_rounded(root, u, -0.44, 0.1, 0.34, 0.26, -0.26, p.metal, 0.0, METAL)
			for i in 4:
				_b(root, u, Vector3(0.3, 0.03, 0.06), Vector3(0, -0.43, -0.4 + i * 0.22), p.secondary.darkened(0.3))
			_disc(root, u, 0.12, 0.05, 0.38, 0.38, p.metal, 0.0, 0.1, METAL)
			_b(root, u, Vector3(0.08, 0.08, 0.03), Vector3(0, 0.12, -0.095), p.trim, Vector3.ZERO, METAL)
		"drowned":
			_boot_base(root, u, p.primary, p.trim, 0.16)
			# Seafoam straps crossing over the foot, a band at the ankle.
			for side in [-1.0, 1.0]:
				_b(root, u, Vector3(0.38, 0.03, 0.05), Vector3(0, -0.07, -0.18), p.accent, Vector3(0, 0.5 * side, 0))
				_b(root, u, Vector3(0.38, 0.03, 0.05), Vector3(0, -0.1, -0.34), p.accent, Vector3(0, 0.5 * side, 0))
			_disc(root, u, 0.04, 0.04, 0.38, 0.38, p.accent, 0.0, 0.1)
		"grandmaster":
			_boot_base(root, u, p.primary, p.secondary, 0.0)
			# Gold trim round the opening, a gold mark on the toe.
			for side in [-1.0, 1.0]:
				_b(root, u, Vector3(0.03, 0.03, 0.34), Vector3(0.135 * side, -0.05, 0.1), p.metal, Vector3.ZERO, METAL)
			_b(root, u, Vector3(0.3, 0.03, 0.03), Vector3(0, -0.05, -0.07), p.metal, Vector3.ZERO, METAL)
			_b(root, u, Vector3(0.08, 0.02, 0.08), Vector3(0, -0.13, -0.36), p.metal, Vector3(0, PI / 4.0, 0), METAL)
		"iron_mike":
			_boot_base(root, u, p.primary, p.secondary, 0.56)
			# White laces up the front, a red stripe at the top, a black heel.
			for i in 5:
				_b(root, u, Vector3(0.14, 0.025, 0.02), Vector3(0, -0.02 + i * 0.1, -0.085), p.trim)
			_disc(root, u, 0.44, 0.05, 0.37, 0.37, p.accent, 0.0, 0.1)
			_rounded(root, u, 0.27, 0.04, 0.35, 0.3, -0.24, p.secondary)
		"dead_money":
			_boot_base(root, u, p.primary, p.secondary.darkened(0.3), 0.0)
			# A gold penny strap across the top with a coin in it.
			_b(root, u, Vector3(0.3, 0.04, 0.07), Vector3(0, -0.07, -0.2), p.metal, Vector3.ZERO, METAL)
			_rounded(root, u, -0.24, 0.02, 0.07, 0.07, -0.06, p.metal.lightened(0.15), 0.0, METAL)


# Charms --------------------------------------------------------------------------

static func _charm(root: Node3D, u: float, p: Dictionary, set_id: String) -> void:
	match set_id:
		"deadweight":
			_anchor(root, u, p)
		"drowned":
			_clam(root, u, p)
		"grandmaster":
			_seal(root, u, p)
		"iron_mike":
			_belt(root, u, p)
		"dead_money":
			_coin(root, u, p)


## An iron anchor: ring, crossbar, shank, curved arms with flukes, and red rope
## wound round the shank.
static func _anchor(root: Node3D, u: float, p: Dictionary) -> void:
	var iron: Color = p.metal
	_b(root, u, Vector3(0.2, 0.05, 0.08), Vector3(0, 0.5, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.05, 0.15, 0.075), Vector3(-0.075, 0.425, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.05, 0.15, 0.075), Vector3(0.075, 0.425, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.16, 0.05, 0.08), Vector3(0, 0.35, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.52, 0.07, 0.08), Vector3(0, 0.27, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.1, 0.7, 0.1), Vector3(0, -0.04, 0), iron, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.16, 0.1, 0.11), Vector3(0, -0.38, 0), iron, Vector3.ZERO, METAL)
	for side in [-1.0, 1.0]:
		_b(root, u, Vector3(0.34, 0.08, 0.09), Vector3(0.16 * side, -0.31, 0), iron, Vector3(0, 0, 0.55 * side), METAL)
		_b(root, u, Vector3(0.12, 0.13, 0.08), Vector3(0.3 * side, -0.18, 0), iron, Vector3(0, 0, 0.8 * side), METAL)
	for y in [0.12, 0.04, -0.04]:
		_b(root, u, Vector3(0.14, 0.05, 0.14), Vector3(0, y, 0), p.primary, Vector3(0, 0.3 if y > 0.0 else -0.2, 0))
	_b(root, u, Vector3(0.04, 0.18, 0.04), Vector3(0.08, -0.12, -0.04), p.primary, Vector3(0, 0, 0.25))


## An open blue clam shell with a big pearl in it.
static func _clam(root: Node3D, u: float, p: Dictionary) -> void:
	var shell: Color = p.primary
	_disc(root, u, -0.24, 0.07, 0.66, 0.54, shell)
	_disc(root, u, -0.17, 0.07, 0.6, 0.48, shell.lightened(0.08))
	for x in [-0.2, 0.0, 0.2]:
		_b(root, u, Vector3(0.04, 0.03, 0.5), Vector3(x, -0.13, 0.0), p.accent)
	# The top shell, hinged at the back and lifted open.
	var lid := Node3D.new()
	lid.position = Vector3(0, -0.16, 0.24) * u
	lid.rotation = Vector3(-0.95, 0, 0)
	root.add_child(lid)
	_disc(lid, u, 0.04, 0.07, 0.62, 0.5, shell, 0.0, -0.24)
	_disc(lid, u, 0.1, 0.05, 0.54, 0.42, shell.darkened(0.12), 0.0, -0.24)
	for x in [-0.18, 0.0, 0.18]:
		_b(lid, u, Vector3(0.04, 0.03, 0.46), Vector3(x, 0.13, -0.24), p.accent)
	# The pearl.
	var pearl: Color = p.trim
	_b(root, u, Vector3(0.26, 0.2, 0.2), Vector3(0, 0.0, -0.04), pearl, Vector3.ZERO, 0.3)
	_b(root, u, Vector3(0.2, 0.26, 0.2), Vector3(0, 0.0, -0.04), pearl, Vector3.ZERO, 0.3)
	_b(root, u, Vector3(0.2, 0.2, 0.26), Vector3(0, 0.0, -0.04), pearl, Vector3.ZERO, 0.3)


## A purple jade stamp: a gold base plate, a gold lion on top, a gold glyph.
static func _seal(root: Node3D, u: float, p: Dictionary) -> void:
	var gold: Color = p.metal
	_disc(root, u, -0.34, 0.06, 0.48, 0.48, gold, 0.0, 0.0, METAL)
	var y := -0.3
	for i in 3:
		_disc(root, u, y + 0.07, 0.14, 0.42, 0.42, p.primary.lightened(0.05 * (i % 2)))
		y += 0.14
	_disc(root, u, 0.15, 0.04, 0.44, 0.44, gold, 0.0, 0.0, METAL)
	# The lion: body, head, ears and a little mane.
	_b(root, u, Vector3(0.24, 0.14, 0.3), Vector3(0, 0.24, 0.02), gold, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.18, 0.16, 0.14), Vector3(0, 0.36, -0.1), gold, Vector3.ZERO, METAL)
	for side in [-1.0, 1.0]:
		_b(root, u, Vector3(0.05, 0.06, 0.04), Vector3(0.07 * side, 0.46, -0.1), gold, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.22, 0.2, 0.05), Vector3(0, 0.35, -0.04), gold.darkened(0.2), Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.12, 0.05, 0.03), Vector3(0, 0.34, -0.18), p.secondary)
	# A glyph on the front.
	_b(root, u, Vector3(0.04, 0.24, 0.02), Vector3(0, -0.1, -0.22), gold, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.2, 0.04, 0.02), Vector3(0, -0.02, -0.22), gold, Vector3.ZERO, METAL)
	_b(root, u, Vector3(0.14, 0.04, 0.02), Vector3(0, -0.16, -0.22), gold, Vector3.ZERO, METAL)


## A championship belt standing up: a big gold center plate with a red gem,
## the black strap curving back on each side with smaller gold plates and white
## stitching.
static func _belt(root: Node3D, u: float, p: Dictionary) -> void:
	var gold: Color = p.primary.lightened(0.1)
	var strap: Color = p.secondary.lightened(0.12)
	_rounded(root, u, 0.0, 0.07, 0.54, 0.46, 0.0, gold, 0.0, METAL)
	_rounded(root, u, -0.04, 0.03, 0.4, 0.33, 0.0, gold.lightened(0.15), 0.0, METAL)
	_gem(root, u, Vector3(0.13, 0.13, 0.04), Vector3(0, 0, -0.065), p.accent)
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.26 * side, 0, 0.02) * u
		arm.rotation = Vector3(0, -0.45 * side, 0)
		root.add_child(arm)
		_b(arm, u, Vector3(0.44, 0.28, 0.05), Vector3(0.22 * side, 0, 0), strap)
		for y in [0.11, -0.11]:
			_b(arm, u, Vector3(0.4, 0.018, 0.01), Vector3(0.22 * side, y, -0.03), p.trim)
		_rounded(arm, u, -0.035, 0.04, 0.16, 0.2, 0.0, gold, 0.24 * side, METAL)


## A big gold coin on its edge with a raised green $.
static func _coin(root: Node3D, u: float, p: Dictionary) -> void:
	var gold: Color = p.metal
	_round_plate(root, u, 0.0, 0.09, 0.76, gold.darkened(0.1), METAL)
	_round_plate(root, u, -0.048, 0.02, 0.62, gold.lightened(0.1), METAL)
	_round_plate(root, u, 0.048, 0.02, 0.62, gold.lightened(0.1), METAL)
	# The $ on both faces: an S of blocks with a bar through it.
	var ink: Color = p.primary
	for z in [-0.065, 0.065]:
		var out := signf(z) * 0.004
		for part in [[Vector3(0.2, 0.05, 0.02), Vector3(0.0, 0.15, z)], [Vector3(0.05, 0.1, 0.02), Vector3(-0.08, 0.1, z)],
				[Vector3(0.2, 0.05, 0.02), Vector3(0.0, 0.03, z)], [Vector3(0.05, 0.1, 0.02), Vector3(0.08, -0.03, z)],
				[Vector3(0.2, 0.05, 0.02), Vector3(0.0, -0.09, z)], [Vector3(0.04, 0.36, 0.015), Vector3(0.0, 0.03, z + out)]]:
			_b(root, u, part[0], part[1], ink)


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
