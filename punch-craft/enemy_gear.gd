class_name EnemyGear
## Tiered armor and weapons for enemies, so you can see you're fighting
## stronger dead as you climb. Five pieces (helmet, chest, legs, boots, and
## gloves or a held weapon) in five tiers: Rusted, Iron, Steel, Blackiron and
## Grave-gold. The tier follows the Climb position the enemy spawns at, and
## how many pieces it wears grows through each tier.
##
## Pieces are shaped from the enemy's own head, torso, legs and hands, so they
## fit every body. Styles: "plate" (shells over the body), "robe" (casters:
## their robes recolored to the tier, with trim, a circlet and bracers),
## "suit" (Possessed Armor: its own metal reskinned), "none" (Dead League
## contenders, the training dummy, the mimic).
##
## What it does: chest, legs and boots block a share of every body punch
## (flat, scaled to the punch strength expected where the enemy spawns); the
## helmet blocks extra on head shots; gloves or a weapon hit harder. Each
## piece adds a little HP and reward.

const PIECES := ["chest", "helmet", "legs", "boots", "gloves"]
## How often each piece shows up, relative to the base chance.
const PIECE_WEIGHT := {"chest": 1.0, "helmet": 0.9, "legs": 0.75, "boots": 0.65, "gloves": 0.7}
const TIERS := [
	{"name": "Rusted", "metal": Color(0.47, 0.31, 0.2), "trim": Color(0.3, 0.2, 0.13), "shine": 0.3, "glow": false, "power": 1.0,
		"cloth": Color(0.32, 0.24, 0.18), "spark": Color(1.0, 0.6, 0.35)},
	{"name": "Iron", "metal": Color(0.46, 0.47, 0.52), "trim": Color(0.24, 0.24, 0.27), "shine": 0.4, "glow": false, "power": 1.25,
		"cloth": Color(0.24, 0.27, 0.36), "spark": Color(1.0, 0.9, 0.7)},
	{"name": "Steel", "metal": Color(0.76, 0.78, 0.82), "trim": Color(0.78, 0.62, 0.3), "shine": 0.45, "glow": false, "power": 1.55,
		"cloth": Color(0.42, 0.12, 0.12), "spark": Color(1.0, 0.95, 0.85)},
	{"name": "Blackiron", "metal": Color(0.13, 0.12, 0.15), "trim": Color(1.0, 0.28, 0.1), "shine": 0.4, "glow": true, "power": 1.9,
		"cloth": Color(0.1, 0.08, 0.12), "spark": Color(1.0, 0.4, 0.2)},
	{"name": "Grave-gold", "metal": Color(0.9, 0.68, 0.25), "trim": Color(0.45, 1.0, 0.85), "shine": 0.5, "glow": true, "power": 2.3,
		"cloth": Color(0.95, 0.85, 0.6), "spark": Color(1.0, 0.85, 0.4)},
]
## Flat damage each body piece blocks, as a share of the punch unit (par
## damage where the enemy spawns), times the tier's power.
const BODY_ARMOR := {"chest": 0.12, "legs": 0.06, "boots": 0.04}
## The helmet only counts on head shots.
const HELMET_ARMOR := 0.16
const WEAPON_DAMAGE := 0.06
const HP_PER_PIECE := 0.04
const REWARD_PER_PIECE := 0.12


## Rolls gear for an enemy at Climb position x. forced: at least a helmet and
## chest plate (the old "armored" spawns); full: every piece (bosses).
static func roll(position: float, forced := false, full := false) -> Dictionary:
	if position < 0.0:
		return {}
	var tier := clampi(floori(position) + 1, 1, TIERS.size())
	if tier > 1 and randf() < 0.25:
		tier -= 1
	var within := position - floorf(position)
	var chance := clampf(0.12 + 0.18 * position + 0.25 * within, 0.12, 0.95)
	var pieces: Array = []
	for piece in PIECES:
		if full or randf() < chance * PIECE_WEIGHT[piece]:
			pieces.append(piece)
	if forced:
		for piece in ["chest", "helmet"]:
			if not pieces.has(piece):
				pieces.append(piece)
	if pieces.is_empty():
		return {}
	return {"tier": tier, "pieces": pieces}


static func tier_info(gear: Dictionary) -> Dictionary:
	return TIERS[clampi(int(gear.get("tier", 1)), 1, TIERS.size()) - 1]


## Defense, damage, HP and rewards from the gear. unit: the punch strength
## expected where it spawns. Call after the enemy's own scaling.
static func apply_stats(enemy: Enemy, gear: Dictionary, unit: float) -> void:
	var info := tier_info(gear)
	var pieces: Array = gear.pieces
	for piece in BODY_ARMOR:
		if pieces.has(piece):
			enemy.armor += unit * BODY_ARMOR[piece] * info.power
	if pieces.has("helmet"):
		enemy.head_armor += unit * HELMET_ARMOR * info.power
	if pieces.has("gloves"):
		enemy.damage_multiplier *= 1.0 + WEAPON_DAMAGE * info.power
	enemy.max_hp *= 1.0 + HP_PER_PIECE * pieces.size()
	enemy.coin_reward = roundi(enemy.coin_reward * (1.0 + REWARD_PER_PIECE * pieces.size()))
	enemy.xp_reward = roundi(enemy.xp_reward * (1.0 + REWARD_PER_PIECE * pieces.size()))


# --- The look -----------------------------------------------------------------------

## Builds the gear onto the enemy's body. Call right after its body is built
## (before its parts become voxels).
static func dress(enemy: Enemy, gear: Dictionary, style: String) -> void:
	var info := tier_info(gear)
	var tier := int(gear.tier)
	var metal := Look.block_material(info.metal, info.shine)
	var trim: StandardMaterial3D = Enemy._glow_material(info.trim) if info.glow else Look.block_material(info.trim, 0.6)
	if info.glow:
		trim.emission_energy_multiplier = 2.2
	var body := _body_map(enemy)
	var pieces: Array = gear.pieces
	match style:
		"suit":
			_reskin_suit(enemy, info, metal, trim)
			return
		"robe":
			_robe(enemy, body, pieces, info, tier, metal, trim)
			return
	if pieces.has("helmet") and body.has("head"):
		_helmet(enemy, body.head, tier, metal, trim)
	if pieces.has("chest") and body.has("torso"):
		_chest(enemy, body.torso, tier, metal, trim)
	for leg in body.get("legs", []):
		if pieces.has("legs"):
			_shell(enemy, leg, Vector3(1.18, 0.42, 1.18), Vector3(0, -0.05, 0), metal, Vector3.ZERO, LEG_FIT)
			_shell(enemy, leg, Vector3(1.26, 0.1, 1.26), Vector3(0, 0.17, 0), trim, Vector3.ZERO, LEG_FIT)
		if pieces.has("boots"):
			_shell(enemy, leg, Vector3(1.3, 0.22, 1.5), Vector3(0, -0.4, -0.15), metal, Vector3.ZERO, LEG_FIT)
	if pieces.has("gloves"):
		_arm(enemy, body, tier, metal, trim)


## Finds the body's head, torso, legs and hands from its box parts, in the
## body's own space: the head is the biggest box high up near the middle, the
## torso the biggest box in the middle band, the legs the tall boxes low down
## (one each side), the hands the farthest boxes on the arm nodes.
static func _body_map(enemy: Enemy) -> Dictionary:
	var to_body := enemy._body.global_transform.affine_inverse()
	var parts := []
	var height := 0.0
	for part in enemy._meshes:
		if not is_instance_valid(part) or not (part.mesh is BoxMesh):
			continue
		var size: Vector3 = (part.mesh as BoxMesh).size * part.scale
		var center := to_body * part.global_transform.origin
		height = maxf(height, center.y + size.y / 2.0)
		parts.append({"part": part, "size": size, "center": center, "volume": size.x * size.y * size.z})
	var map := {}
	if parts.is_empty() or height <= 0.0:
		return map
	var best_head := 0.0
	var best_torso := 0.0
	var legs := {}
	for entry in parts:
		var c: Vector3 = entry.center
		var s: Vector3 = entry.size
		if c.y > height * 0.72 and absf(c.x) < 0.12 and s.x > 0.12 and entry.volume > best_head:
			best_head = entry.volume
			map.head = entry
		elif c.y > height * 0.42 and c.y <= height * 0.8 and absf(c.x) < 0.12:
			# Weighted toward the chest, so a wide pelvis doesn't win.
			var score: float = entry.volume * pow(c.y / height, 3.0)
			if score > best_torso:
				best_torso = score
				map.torso = entry
		elif c.y < height * 0.45 and absf(c.x) > 0.03 and s.y >= s.x * 0.8:
			var side := "left" if c.x < 0.0 else "right"
			if not legs.has(side) or entry.volume > legs[side].volume:
				legs[side] = entry
	map.legs = legs.values()
	var hands := []
	for node in enemy._hand_nodes():
		var far: Dictionary = {}
		var reach := -1.0
		for entry in parts:
			var part: MeshInstance3D = entry.part
			if part.get_parent() == node and part.position.length() > reach:
				reach = part.position.length()
				far = entry
		if not far.is_empty():
			hands.append(far)
	map.hands = hands
	return map


## A box around a body part: same parent and placement, sized by `grow` of the
## part, nudged by `offset` (as a share of the part's size, in its own frame).
## fit: treat the part as at least this big (bony enemies' thin parts still
## get a proper breastplate or greave).
static func _shell(enemy: Enemy, entry: Dictionary, grow: Vector3, offset: Vector3, material: Material, rot := Vector3.ZERO, fit := Vector3.ZERO) -> MeshInstance3D:
	var part: MeshInstance3D = entry.part
	var size: Vector3 = (part.mesh as BoxMesh).size.max(fit)
	var shell := enemy._part(part.get_parent(), Enemy._box(size * grow), material, Vector3.ZERO)
	shell.transform = part.transform * Transform3D(Basis.from_euler(rot), size * offset)
	return shell


static func _set_material(part: MeshInstance3D, material: Material) -> void:
	if part.mesh is PrimitiveMesh:
		(part.mesh as PrimitiveMesh).material = material


const HEAD_FIT := Vector3(0.28, 0.28, 0.28)
const CHEST_FIT := Vector3(0.42, 0.48, 0.26)
const LEG_FIT := Vector3(0.15, 0.0, 0.15)
const HAND_FIT := Vector3(0.14, 0.14, 0.16)


static func _helmet(enemy: Enemy, head: Dictionary, tier: int, metal: Material, trim: Material) -> void:
	# A cap over the top and sides, cheek guards, the face left open.
	_shell(enemy, head, Vector3(1.14, 0.5, 1.14), Vector3(0, 0.3, 0), metal, Vector3.ZERO, HEAD_FIT)
	for side in [-1.0, 1.0]:
		_shell(enemy, head, Vector3(0.12, 0.55, 0.9), Vector3(0.56 * side, -0.02, 0.04), metal, Vector3.ZERO, HEAD_FIT)
	if tier >= 2:
		_shell(enemy, head, Vector3(0.12, 0.42, 0.1), Vector3(0, 0.02, -0.58), metal, Vector3.ZERO, HEAD_FIT)
	if tier >= 3:
		_shell(enemy, head, Vector3(0.12, 0.28, 0.95), Vector3(0, 0.64, 0), trim, Vector3.ZERO, HEAD_FIT)
	if tier >= 4:
		for side in [-1.0, 1.0]:
			_shell(enemy, head, Vector3(0.13, 0.42, 0.13), Vector3(0.55 * side, 0.72, 0.0), trim, Vector3(0, 0, -0.55 * side), HEAD_FIT)
	if tier >= 5:
		for x in [-0.32, 0.0, 0.32]:
			_shell(enemy, head, Vector3(0.12, 0.3, 0.12), Vector3(x, 0.7, -0.45), trim, Vector3.ZERO, HEAD_FIT)


static func _chest(enemy: Enemy, torso: Dictionary, tier: int, metal: Material, trim: Material) -> void:
	_shell(enemy, torso, Vector3(1.1, 0.72, 1.18), Vector3(0, 0.12, 0), metal, Vector3.ZERO, CHEST_FIT)
	_shell(enemy, torso, Vector3(1.14, 0.1, 1.22), Vector3(0, -0.26, 0), trim, Vector3.ZERO, CHEST_FIT)
	for side in [-1.0, 1.0]:
		_shell(enemy, torso, Vector3(0.34, 0.18, 1.02), Vector3(0.56 * side, 0.42, 0), metal, Vector3.ZERO, CHEST_FIT)
		if tier >= 3:
			_shell(enemy, torso, Vector3(0.36, 0.05, 1.06), Vector3(0.56 * side, 0.52, 0), trim, Vector3.ZERO, CHEST_FIT)
	if tier >= 4:
		_shell(enemy, torso, Vector3(0.18, 0.18, 0.06), Vector3(0, 0.18, -0.6), trim, Vector3.ZERO, CHEST_FIT)


## Gauntlets, or a weapon in the tier's metal for enemies that hold one.
static func _arm(enemy: Enemy, body: Dictionary, tier: int, metal: Material, trim: Material) -> void:
	var weapons: Array = enemy._weapon_parts()
	if not weapons.is_empty():
		for part in weapons:
			if is_instance_valid(part):
				_set_material(part, trim if tier >= 4 else metal)
		return
	for hand in body.get("hands", []):
		_shell(enemy, hand, Vector3(1.22, 1.22, 1.1), Vector3.ZERO, metal, Vector3.ZERO, HAND_FIT)
		_shell(enemy, hand, Vector3(1.32, 1.32, 0.32), Vector3(0, 0, 0.5), trim, Vector3.ZERO, HAND_FIT)


## Casters: robes in the tier's cloth, trim at the collar and hem, a circlet
## for a helmet, bracers or a tiered weapon for gloves.
static func _robe(enemy: Enemy, body: Dictionary, pieces: Array, info: Dictionary, tier: int, metal: Material, trim: Material) -> void:
	if body.has("torso") and (pieces.has("chest") or pieces.has("legs")):
		var robe: Material = (body.torso.part as MeshInstance3D).mesh.surface_get_material(0)
		var cloth := Look.block_material(info.cloth)
		for part in enemy._meshes:
			if is_instance_valid(part) and part.mesh and part.mesh.surface_get_material(0) == robe:
				_set_material(part, cloth)
		_shell(enemy, body.torso, Vector3(1.08, 0.08, 1.12), Vector3(0, 0.44, 0), trim)
		_shell(enemy, body.torso, Vector3(1.08, 0.08, 1.12), Vector3(0, -0.44, 0), trim)
	if pieces.has("helmet") and body.has("head"):
		_shell(enemy, body.head, Vector3(1.08, 0.12, 1.08), Vector3(0, 0.2, 0), metal)
		if tier >= 3:
			_shell(enemy, body.head, Vector3(0.14, 0.14, 0.08), Vector3(0, 0.22, -0.56), trim)
	if pieces.has("gloves"):
		var weapons: Array = enemy._weapon_parts()
		if not weapons.is_empty():
			_arm(enemy, body, tier, metal, trim)
		else:
			for hand in body.get("hands", []):
				_shell(enemy, hand, Vector3(1.2, 0.5, 1.2), Vector3(0, 0, 0.3), trim)


## A suit of armor: its own metal becomes the tier's.
static func _reskin_suit(enemy: Enemy, info: Dictionary, metal: Material, trim: Material) -> void:
	for part in enemy._meshes:
		if not is_instance_valid(part) or part.mesh == null:
			continue
		var material := part.mesh.surface_get_material(0) as StandardMaterial3D
		if material and material.metallic >= 0.5 and not material.emission_enabled:
			_set_material(part, metal)
	if info.glow:
		var body := _body_map(enemy)
		if body.has("torso"):
			_shell(enemy, body.torso, Vector3(1.14, 0.1, 1.22), Vector3(0, -0.26, 0), trim)
