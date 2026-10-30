class_name FighterBody
extends PlayerBody
## The fighters' bodies (2026-10-30): all six rebuilt clean in large cubes
## (the revamp, prototyped in the playground 2026-10-29), on PlayerBody's
## pivots (hips, torso, head, shoulders, elbows, hips, knees, plus ankles
## lf / rf, and the chest and neck for emotes), poses, emotes, skins and hats. PlayerBody's own small-cube
## sculpture is only a fallback now. Each fighter has its own overall size
## (SIZE), its cubes the same size in the world as everyone else's.
##
## The rules (the user's, from the prototype passes):
## - No per-voxel jitter, mottling, crease speckle or random wear. Every cell
##   is a base, shadow or highlight color placed on purpose.
## - No two parts overlap (the neck, chin, beard and long hair keep clear of
##   the trunk): overlapping cubes read as speckle.
## - Detail is sized in lines (trim, piping, wrap bands): one cube.
## - Wraps and tape are painted on the forearm, not built over it.
## - Hair is built in named zones (top, front, sides, back, puff, short),
##   split at the hat line; a hat's fit profile says where it sits and which
##   zones it hides (big hair swaps to a short cut under a cap or crown).
## (The Answer was also tried at tiny and medium cube sizes; voxel_scale.)

const SCALES := {
	"tiny": {"voxel": 0.016, "line": 0.032, "lift": 0.016, "name": "Tiny Cube Revamp"},
	# Between the two (2026-10-29: large read too toy-like): the large design
	# at two thirds the cube, about 8k cubes.
	"medium": {"voxel": 0.024, "line": 0.024, "lift": 0.024, "name": "Medium Cube Revamp"},
	"large": {"voxel": 0.036, "line": 0.036, "lift": 0.036, "name": "Large Cube Revamp"},
}
## How a hat sits on the head: seat (height on the head pivot), size (times
## the head's width with its hair) and the hair zones it hides.
const HAT_FIT := {
	# Down on the skull to just over the brows; the sides and back show under it.
	"cap": {"seat": 0.315, "size": 0.96, "hide": ["top", "front"]},
	# On top of the hair, all of it showing.
	"crown": {"seat": 0.395, "size": 1.05, "hide": []},
	# Helmets and masks round the whole head, the face's raised cubes (brow,
	# nose) inside the front plate.
	"mask": {"seat": 0.33, "size": 1.22, "hide": ["top", "front", "sides", "back"]},
	# Wigs and bald caps replace the hair.
	"wig": {"seat": 0.33, "size": 0.87, "hide": ["top", "front", "sides", "back"]},
}
## The fighters rebuilt here, and what dresses each: torso, leg, face,
## hair, arm.
const DRESS := {
	"counter_master": ["_answer_torso", "_answer_leg", "_answer_face", "_answer_hair", "_answer_arm"],
	"berserker": ["_mauler_torso", "_mauler_leg", "_mauler_face", "_mauler_hair", "_mauler_arm"],
	"combo_master": ["_blur_torso", "_blur_leg", "_blur_face", "_blur_hair", "_blur_arm"],
	"free_runner": ["_stray_torso", "_stray_leg", "_stray_face", "_stray_hair", "_stray_arm"],
	"elementalist": ["_catalyst_torso", "_catalyst_leg", "_catalyst_face", "_catalyst_hair", "_catalyst_arm"],
	"wise_guy": ["_tony_torso", "_tony_leg", "_tony_face", "_tony_hair", "_tony_arm"],
}
## The revamp's own changes to a fighter's build (BUILDS): the Blur's jaw
## fuller and his head a touch bigger (it read tiny and pinched).
const BUILD_TWEAKS := {"combo_master": {"jaw": 0.65, "face": 1.0}}
## The chest and neck pivots' heights on the torso (2026-10-30, for emotes:
## body rolls bend at the chest, head bobs at the neck). The trunk is drawn
## whole on the torso; its cubes from CHEST_Y up ride the chest once baked.
const CHEST_Y := 0.22
const NECK_Y := 0.52
## Overall size (PlayerBody's is 0.92 for all): the Mauler big and tall, the
## Blur small and lean.
const SIZE := {"berserker": 1.06, "counter_master": 0.92, "combo_master": 0.83, "free_runner": 0.93,
	"elementalist": 1.0, "wise_guy": 0.88}
const HAT_KIND := {
	"paper_crown": "crown", "coffin_crown": "crown", "frost_tiara": "crown", "quake_headband": "crown",
	"storm_ears": "crown", "party_hat": "crown",
	"iron_mask": "mask", "doom_mask": "mask", "monkey_mask": "mask", "speed_mask": "mask", "reaper_hood": "mask",
	"wig_black": "wig", "wig_blonde": "wig", "wig_blue": "wig", "wig_white": "wig", "fast_quills": "wig",
	"golden_quills": "wig", "gale_flattop": "wig", "blood_hairline": "wig", "bald_cap": "wig",
}

## "tiny", "medium" or "large"; set before the body enters the tree.
var voxel_scale := "large"
var _v := VOXEL
var _line := 0.032
var _lift := 0.016
var _revamp := false
## Hair zones by name: top, front, sides, back.
var _zones := {}
## Zone node -> its name.
var _zone_of := {}
## The top of the hair and its half width (crowns sit on it).
var _crown_at := 0.52
var _crown_half := 0.17
## Hair zones a crown hides: big hair (the Blur's curls, the Stray's locs)
## goes under it, so the crown sits down on the head like everyone's.
var _crown_hides: Array = []
## Where the top of the hair splits for a crown (above it goes under the
## crown); past the hair, no split.
var _crown_cut := 9.0
## Big hair that swaps to a short cut (the "short" zone) under a cap or
## crown, instead of being cut down or squeezed (the Blur).
var _short_under_hats := false
## The Stray's headband (off under any hat).
var _headband: Node3D
static var _cubes := {}


func _b(key: String) -> float:
	if BUILD_TWEAKS.has(fighter) and BUILD_TWEAKS[fighter].has(key):
		return BUILD_TWEAKS[fighter][key]
	return super._b(key)


static func hat_kind(id: String) -> String:
	if HAT_KIND.has(id):
		return HAT_KIND[id]
	return "wig" if Hats.info(id).get("bald", false) else "cap"


static func scale_name(id: String) -> String:
	return SCALES.get(id, SCALES.tiny).name


## The head's measurements a hat fits to (head pivot space).
func head_profile() -> Dictionary:
	var fw := 0.15 * _b("face")
	return {"skull_top": 0.345, "hair_top": _crown_at, "brow": 0.25, "half_width": fw, "hair_half_width": _crown_half, "front": -0.15}


func _cache_key() -> String:
	return "revamp_%s/%s" % [voxel_scale, super._cache_key()]


# --- The hat ------------------------------------------------------------------------

func wear_hat(id: String) -> void:
	if not _revamp:
		super.wear_hat(id)
		return
	if _hat and is_instance_valid(_hat):
		_hat.queue_free()
	_hat = null
	var bare := id == "" or not Hats.CATALOG.has(id)
	var fit: Dictionary = {} if bare else HAT_FIT[hat_kind(id)]
	var short: bool = _short_under_hats and not bare and hat_kind(id) in ["cap", "crown"]
	for zone in _zones:
		if zone.begins_with("short") or short:
			# A cap shows the short cut below its brim; a crown all of it.
			(_zones[zone] as Node3D).visible = short and (zone == "short" or (zone == "short_high" and hat_kind(id) == "crown"))
			continue
		(_zones[zone] as Node3D).visible = bare or not (_zone_hidden(zone, fit.hide) or (hat_kind(id) == "crown" and _zone_hidden(zone, _crown_hides)))
	# The Stray keeps his headband under any hat; over a mask it goes round
	# the outside of the mask.
	var mask := not bare and hat_kind(id) == "mask"
	if _headband:
		_headband.visible = not mask
	if bare:
		return
	# Crowns sit on the hair (whatever its size); the rest fit the skull.
	var crown := hat_kind(id) == "crown"
	var half: float = _crown_half if crown else 0.15 * _b("face") + 0.03
	var u: float = half * 2.0 * fit.size * (Hats.FRUIT_SIZE if id == "fruit_hat" else 1.0)
	_hat = Node3D.new()
	_hat.name = "HatSocket"
	_hat.position = Vector3(0, _crown_at - 0.125 if crown else fit.seat, 0)
	_hat.add_child(Hats.build(id, u))
	_joints.head.add_child(_hat)
	_set_layer(_hat)
	var spin := _hat.get_node_or_null("Hat/Spin")
	if spin:
		spin.create_tween().set_loops().tween_property(spin, "rotation:y", TAU, 0.6).from(0.0)
	if mask and _headband:
		_mask_band(_hat.get_node("Hat"), u)
	if Hats.info(id).rarity == "legendary":
		Hats.sparkles(_hat, Hats.color(id), 0.25)


## The Stray's headband tied round the outside of a mask (in the hat's own
## units, wide enough for every mask), knotted behind, tails trailing.
func _mask_band(hat: Node3D, u: float) -> void:
	var red := _p("band")
	var y := -0.1
	Hats._b(hat, u, Vector3(1.32, 0.13, 0.07), Vector3(0, y, -0.62), red)
	Hats._b(hat, u, Vector3(1.32, 0.13, 0.07), Vector3(0, y, 0.66), red)
	for side in [-1.0, 1.0]:
		Hats._b(hat, u, Vector3(0.07, 0.13, 1.35), Vector3(0.66 * side, y, 0.02), red)
	Hats._b(hat, u, Vector3(0.18, 0.17, 0.1), Vector3(-0.1, y, 0.72), red.darkened(0.15))
	Hats._b(hat, u, Vector3(0.14, 0.04, 0.7), Vector3(-0.35, y - 0.15, 1.0), red, Vector3(0.35, -0.6, 0))
	Hats._b(hat, u, Vector3(0.12, 0.04, 0.55), Vector3(-0.15, y - 0.35, 0.95), red.darkened(0.12), Vector3(0.8, -0.3, 0))


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_revamp = DRESS.has(fighter)
	if not _revamp:
		super._build()
		return
	# Only the Answer was tried at other cube sizes.
	if fighter != "counter_master":
		voxel_scale = "large"
	var s: Dictionary = SCALES.get(voxel_scale, SCALES.tiny)
	scale = Vector3.ONE * SIZE[fighter]
	# The same cube size in the world on every fighter, whatever their size.
	_v = s.voxel * 0.92 / SIZE[fighter]
	_line = s.line * 0.92 / SIZE[fighter]
	_lift = s.lift * 0.92 / SIZE[fighter]
	var dress: Array = DRESS[fighter]
	var b := _bulk()
	var hips := _pivot("hips", self, Vector3(0, _hip_height(), 0))
	var torso := _pivot("torso", hips, Vector3(0, 0.1, 0))
	call(dress[0], hips, torso)
	var chest := _pivot("chest", torso, Vector3(0, CHEST_Y, 0))
	var neck := _pivot("neck", chest, Vector3(0, NECK_Y - CHEST_Y, 0))
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var hip := _pivot(key + "h", hips, Vector3(0.1 * b * side, 0.0, 0))
		var knee := _pivot(key + "k", hip, Vector3(0, -0.44, 0))
		call(dress[1], hip, knee, side)
	var head := _pivot("head", neck, Vector3(0, 0.57 - NECK_Y, 0))
	_skull(head)
	call(dress[2], head)
	call(dress[3], head)
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var shoulder := _pivot(key + "s", chest, Vector3((0.22 * b + 0.07) * side, 0.49 - CHEST_Y, 0))
		var elbow := _pivot(key + "e", shoulder, Vector3(0, -0.29, 0))
		call(dress[4], shoulder, elbow, side)
	for node in _parts:
		_ops.append(["bake", node, {}])


func _fill(node: Node3D, from: Vector3, to: Vector3, color: Variant, inside: Callable, tint_only := false) -> void:
	if not _grids.has(node):
		_grids[node] = {}
		_parts.append(node)
	var lo := Vector3i((from / _v).floor())
	_ops.append(["fill", node, lo, Vector3i((to / _v).ceil()), color, inside, tint_only, lo.x])


## As PlayerBody's, at this scale's voxel, and the colors exactly as given.
func _run_fill(op: Array, start: int) -> bool:
	if not _revamp:
		return super._run_fill(op, start)
	var grid: Dictionary = _grids[op[1]]
	var lo: Vector3i = op[2]
	var hi: Vector3i = op[3]
	var color: Variant = op[4]
	var inside: Callable = op[5]
	var tint_only: bool = op[6]
	var carve := typeof(color) == TYPE_NIL
	var x: int = op[7]
	while x < hi.x:
		for y in range(lo.y, hi.y):
			for z in range(lo.z, hi.z):
				var cell := Vector3i(x, y, z)
				if tint_only and not grid.has(cell):
					continue
				var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * _v
				if not inside.call(p):
					continue
				if carve:
					grid.erase(cell)
				else:
					grid[cell] = (color as Callable).call(p) if color is Callable else color
		x += 1
		if Time.get_ticks_msec() - start >= build_budget_ms:
			op[7] = x
			return x >= hi.x
	return true


## Cubes for the cells with an open side, in their painted colors (no crease
## or edge shading: the light does that).
func _run_bake(op: Array, start: int) -> bool:
	if not _revamp:
		return super._run_bake(op, start)
	var node: Node3D = op[1]
	var grid: Dictionary = _grids[node]
	var cells: Array = []
	for cell: Vector3i in grid:
		for n in SIDES:
			if not grid.has(cell + n):
				cells.append(cell)
				break
	if not _cubes.has(_v):
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * _v * 1.01
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.85
		cube.material = material
		_cubes[_v] = cube
	if node == _joints.get("torso") and _joints.has("chest"):
		var chest: Node3D = _joints.chest
		var waist: Array = []
		var ribs: Array = []
		for cell: Vector3i in cells:
			(ribs if (cell.y + 0.5) * _v >= chest.position.y else waist).append(cell)
		_bake_cells(node, grid, waist, Vector3.ZERO)
		_bake_cells(chest, grid, ribs, -chest.position)
	else:
		_bake_cells(node, grid, cells, Vector3.ZERO)
	_grids.erase(node)
	return true


func _bake_cells(node: Node3D, grid: Dictionary, cells: Array, offset: Vector3) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _cubes[_v]
	multimesh.instance_count = cells.size()
	for k in cells.size():
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, (Vector3(cells[k]) + Vector3(0.5, 0.5, 0.5)) * _v + offset))
		multimesh.set_instance_color(k, grid[cells[k]])
	_attach(node, multimesh)
	_baked.append([get_path_to(node), multimesh])


func _tiny() -> bool:
	return voxel_scale == "tiny"


## The value for this scale.
func _pick(tiny: Variant, medium: Variant, large: Variant) -> Variant:
	return {"tiny": tiny, "medium": medium}.get(voxel_scale, large)


func _hi(color: Color) -> Color:
	return color.lightened(0.16)


func _sh(color: Color) -> Color:
	return color.darkened(0.28)


## A box mirrored to a side: x0..x1 measured outward from the middle.
func _side_block(node: Node3D, side: float, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Variant, r := 0.0) -> void:
	_block(node, Vector3(minf(x0 * side, x1 * side), y0, z0), Vector3(maxf(x0 * side, x1 * side), y1, z1), color, r)


# --- The Answer: trunk and clothes ----------------------------------------------------

## The trunk's half width and depth at height y: a firm waist widening to a
## broad, square chest, sloping in to the neck.
## (Drawn at the Answer's build, scaled by each fighter's chest and waist.)
func _hx(y: float) -> float:
	var c := _r("chest")
	if y < 0.26:
		return lerpf(0.17 * _r("waist"), 0.235 * c, clampf((y + 0.04) / 0.3, 0.0, 1.0))
	if y < 0.5:
		return lerpf(0.235 * c, 0.268 * c, (y - 0.26) / 0.24)
	return lerpf(0.268 * c, 0.19 * c, clampf((y - 0.5) / 0.12, 0.0, 1.0))


func _hz(y: float) -> float:
	var c := lerpf(1.0, _r("chest"), 0.7)
	if y < 0.26:
		return lerpf(0.115 * lerpf(1.0, _r("waist"), 0.7), 0.135 * c, clampf((y + 0.04) / 0.3, 0.0, 1.0))
	if y < 0.5:
		return lerpf(0.135 * c, 0.148 * c, (y - 0.26) / 0.24)
	return lerpf(0.148 * c, 0.12 * c, clampf((y - 0.5) / 0.12, 0.0, 1.0))


## A build measurement against the Answer's (whose numbers the shapes were
## drawn at).
func _r(key: String) -> float:
	return _b(key) / float(BUILDS.counter_master[key])


## Open round the neck and under the chin, so no two parts ever overlap
## there (on large cubes that showed as speckle).
func _neck_clear(p: Vector3) -> bool:
	if p.y > 0.5 and Vector2(p.x, p.z - 0.015).length() < 0.066 * _r("neck") + 0.034:
		return false
	return not (p.y > 0.55 and p.z < 0.0 and absf(p.x) < 0.15 * _b("face") - 0.03) and _off_head(p)


## A whole cube clear of the jaw (torso space; the head pivot is 0.57 up):
## collars, scarves and the hood keep out of it.
func _off_head(p: Vector3) -> bool:
	# (The Catalyst's beard reaches down his chest.)
	if p.y < (0.3 if fighter == "elementalist" else 0.5):
		return true
	var h := p - Vector3(0, 0.57, 0)
	for d: Vector3 in [Vector3.ZERO, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
		if _in_jaw(h + d * _v) or _in_beard(h + d * _v):
			return false
	return true


## The Catalyst's beard (head space): from the cheeks to a broad point on
## the chest, higher at the sides (the mouth under the moustache).
func _in_beard(p: Vector3) -> bool:
	if fighter != "elementalist" or p.y > 0.13 or p.y < -0.2:
		return false
	var fw := 0.15 * _b("face")
	var t := clampf((0.13 - p.y) / 0.33, 0.0, 1.0)
	var half := lerpf(fw, 0.06, t * t)
	return absf(p.x) <= half and p.y < 0.07 + absf(p.x) * 0.5 and p.z >= -0.19 and p.z <= lerpf(0.06, -0.06, t)


func _in_trunk(p: Vector3, grow := 0.0) -> bool:
	if p.y < -0.04 or p.y > 0.62:
		return false
	var h := Vector2(_hx(p.y), _hz(p.y)) + Vector2.ONE * grow
	var local := Vector2(absf(p.x), absf(p.z))
	if local.x > h.x or local.y > h.y:
		return false
	var r := 0.05 + grow
	return (local - (h - Vector2.ONE * r)).max(Vector2.ZERO).length() <= r


## The hood's top edge: low at the front, bunched high at the back.
func _hood_top(z: float) -> float:
	return 0.655 + 0.065 * clampf((z + 0.02) / 0.2, 0.0, 1.0)


func _answer_torso(hips: Node3D, torso: Node3D) -> void:
	var cloth := _p("cloth")
	var white := _p("piping")
	var belt := _p("belt")
	# The sleeveless hoodie: black, two white lapel lines from the hood down to
	# the belt, white round the armholes, the pec ledge catching the light.
	var hoodie := func(p: Vector3) -> Color:
		if _tiny():
			var lapel := lerpf(0.04, 0.105, clampf(p.y / 0.56, 0.0, 1.0))
			if p.z < 0.0 and absf(absf(p.x) - lapel) <= _line * 0.5:
				return white
		# Large: the hood's two drawstrings hanging down the chest, their tips gray.
		elif p.z < 0.0 and absf(absf(p.x) - 0.054) <= _line * 0.5 and p.y > 0.33 and p.y < 0.6:
			return white.darkened(0.35) if p.y < 0.33 + _v else white
		if p.y > 0.36 and absf(p.x) > _hx(p.y) - _line:
			return white
		return cloth
	_fill(torso, Vector3(-0.3, -0.05, -0.2), Vector3(0.3, 0.63, 0.2), hoodie, func(p: Vector3) -> bool:
		return _in_trunk(p) and _neck_clear(p))
	# The chest plane standing out from the ribs.
	_block(torso, Vector3(-0.2, 0.34, -_hz(0.42) - _lift), Vector3(0.2, 0.5, -0.05), hoodie, 0.02)
	# The hood down round the neck: open at the front, bunched behind, its
	# edge trimmed white.
	var hood := func(p: Vector3) -> Color:
		return white if p.y > _hood_top(p.z) - _line and p.z > -0.02 else cloth
	_fill(torso, Vector3(-0.24, 0.48, -0.12), Vector3(0.24, 0.76, 0.26), hood, func(p: Vector3) -> bool:
		var r := Vector2(p.x, p.z - 0.04).length()
		return p.y > 0.5 and p.y < _hood_top(p.z) and r > 0.11 and r < 0.2 and p.z > -0.03 and _off_head(p))
	_block(torso, Vector3(-0.15, 0.46, 0.1), Vector3(0.15, 0.68, 0.24), cloth, 0.05)
	# The white belt, its lower edge in shadow, knotted in front, two short tails.
	var band := func(p: Vector3) -> Color:
		return _sh(belt) if p.y < -0.04 + _v else belt
	_fill(torso, Vector3(-0.3, -0.05, -0.2), Vector3(0.3, 0.06, 0.2), band, func(p: Vector3) -> bool:
		return p.y <= 0.05 and _in_trunk(p, _lift))
	var front := -_hz(0.0) - _lift
	_block(torso, Vector3(-0.045, -0.05, front - _lift), Vector3(0.045, 0.065, front + 0.02), belt, 0.01)
	var thick := maxf(_v, 0.024)
	for side in [-1.0, 1.0]:
		_side_block(torso, side, 0.008, 0.044, -0.17, -0.04, front - _lift - thick, front - _lift, belt)
	# The pants' seat, then the hoodie's front hanging below the belt in two
	# panels, split up the middle, trimmed white at the hem and the split.
	_block(hips, Vector3(-0.19, -0.11, -0.125), Vector3(0.19, 0.12, 0.135), cloth, 0.05)
	if not _tiny():
		return
	var hem := -0.28
	var slit := func(p: Vector3) -> float:
		return _v * 0.5 + clampf(-p.y, 0.0, 0.3) * 0.2 if _tiny() else _v
	var panel := func(p: Vector3) -> Color:
		if p.y < hem + _line or (_tiny() and absf(p.x) < slit.call(p) + _line):
			return white
		return cloth
	_fill(hips, Vector3(-0.34, -0.3, -0.3), Vector3(0.34, 0.08, 0.06), panel, func(p: Vector3) -> bool:
		var flare := 1.0 + clampf(-p.y, 0.0, 0.3) * 0.6
		var rx := 0.215 * flare
		var rz := 0.155 * flare
		var d := (p.x * p.x) / (rx * rx) + (p.z * p.z) / (rz * rz)
		return p.z < 0.02 and p.y > hem and p.y < 0.07 and d <= 1.0 and d >= 0.6 and absf(p.x) > slit.call(p))


## A white lightning bolt zigzagging diagonally down the leg, round from
## the front-outer side by offset (arc length); y_offset puts the knee's
## part on the same bolt as the hip's.
func _bolt(side: float, offset: float, y_offset: float) -> Callable:
	var cloth := _p("cloth")
	var white := _p("piping")
	if not _tiny():
		return _bolt_cells(side, y_offset)
	var period := 0.12 if _tiny() else 0.144
	var amp := 0.03 if _tiny() else 0.036
	return func(p: Vector3) -> Color:
		var y := p.y + y_offset
		var s := atan2(p.z, p.x * side) * 0.112
		var t := fposmod(y / period, 1.0)
		var zig := (t if t < 0.5 else 1.0 - t) * 2.0 * amp
		for o: float in ([offset, offset + 0.24] if _tiny() else [offset]):
			if absf(s - (o + y * 0.12 + zig)) <= _line * 0.5:
				return white
		return cloth


## The large scale's bolt: one cell wide down the outside of the leg,
## stepping back a column every three rows across three columns, then
## jumping forward again, repeating.
func _bolt_cells(side: float, y_offset: float) -> Callable:
	var cloth := _p("cloth")
	var white := _p("piping")
	return func(p: Vector3) -> Color:
		if p.x * side < 0.06:
			return cloth
		var row := floori((p.y + y_offset) / _v)
		var col := floori(p.z / _v)
		var at := posmod(-floori(row / 3.0), 3) - 1
		# Each step's top row reaches back to the last one, so the steps join.
		var last := posmod(-floori((row + 1) / 3.0), 3) - 1
		if posmod(row, 3) == 2:
			return white if col >= mini(at, last) and col <= maxi(at, last) else cloth
		return white if col == at else cloth


func _answer_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var cloth := _p("cloth")
	# Baggy black pants with the lightning down the outside.
	_taper(hip, -0.44, 0.04, Vector2(0.112, 0.116), Vector2(0.114, 0.118), _bolt(side, -0.03, 0.0), 0.045)
	# Below the knee the pants bunch in folds, each flaring to a lit lip over
	# the crease under it, then gather into a white cuff at the ankle.
	var bolt := _bolt(side, -0.03, -0.44)
	var folds := [[0.03, -0.12, 0.1], [-0.12, -0.235, 0.094]] if _tiny() else [[0.03, -0.17, 0.096]]
	for fold: Array in folds:
		var top: float = fold[0]
		var bottom: float = fold[1]
		var half: float = fold[2]
		var paint := func(p: Vector3) -> Color:
			if p.y < bottom + _v and _tiny():
				return cloth.lightened(0.08)
			if p.y > top - _v:
				return _sh(cloth)
			return bolt.call(p)
		_taper(knee, bottom, top, Vector2(half + _lift, half + _lift + 0.004), Vector2(half, half + 0.004), paint, 0.04)
	var gather: float = folds[-1][1]
	_taper(knee, -0.3, gather, Vector2(0.074, 0.078), Vector2(0.084, 0.088), cloth, 0.03)
	if _tiny():
		_taper(knee, -0.335, -0.285, Vector2(0.07 + _lift * 0.5, 0.074 + _lift * 0.5), Vector2(0.07 + _lift * 0.5, 0.074 + _lift * 0.5), _p("ankle"), 0.02)
	else:
		# One row, flush with the pants.
		_taper(knee, -0.33, -0.3, Vector2(0.072, 0.072), Vector2(0.072, 0.072), _p("ankle"))
	# The shoe on its own ankle pivot (lf / rf, new; nothing else moves it),
	# so a stance can turn the foot without twisting the shin.
	_answer_shoe(_pivot(("l" if side < 0 else "r") + "f", knee, Vector3(0, -ANKLE, 0)), side)


## The ankle pivot's height below the knee.
const ANKLE := 0.4


## Built in the knee's measurements, moved up onto the ankle pivot.
func _answer_shoe(foot: Node3D, side: float) -> void:
	var knee := Node3D.new()
	knee.name = "Shoe"
	knee.position = Vector3(0, ANKLE, 0)
	foot.add_child(knee)
	var shoe := _p("shoes")
	var sole := _p("sole")
	var trim := _p("accent")
	var w := 0.066
	# A white sole, the black upper and toe box, a padded collar, laces, and
	# a white stripe along the outside.
	_block(knee, Vector3(-w - 0.006, -0.46, -0.178), Vector3(w + 0.006, -0.43, 0.086), sole)
	_block(knee, Vector3(-w, -0.44, -0.16), Vector3(w, -0.37, 0.08), shoe, 0.02)
	_block(knee, Vector3(-w + 0.004, -0.44, -0.17), Vector3(w - 0.004, -0.395, -0.09), shoe, 0.02)
	_taper(knee, -0.38, -0.33, Vector2(w, w), Vector2(w - 0.004, w - 0.004), shoe, 0.02, Vector3(0, 0, 0.012))
	var laces := [-0.418, -0.386, -0.354] if _tiny() else [-0.41]
	for y: float in laces:
		_block(knee, Vector3(-0.03, y, -0.15), Vector3(0.03, y + _v, -0.11), trim)
	_side_block(knee, side, w - 0.004, w + _v * 0.6, -0.43, -0.43 + _line, -0.14, 0.06, trim)


func _answer_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var skin := _skin
	var cloth := _p("cloth")
	var white := _p("piping")
	# A big square deltoid under the hoodie's shoulder (trimmed white at its
	# edge), the upper arm with biceps and triceps, the elbow.
	var delt_lo := Vector3(0.012 * side, -0.035, 0) - Vector3(0.095, 0.09, 0.09)
	var delt_hi := Vector3(0.012 * side, -0.035, 0) + Vector3(0.095, 0.09, 0.09)
	_block(shoulder, delt_lo, delt_hi, skin, 0.045)
	var lo := delt_lo - Vector3.ONE * _lift
	var hi := delt_hi + Vector3.ONE * _lift
	var cap := func(p: Vector3) -> Color:
		return white if p.y < -0.015 + _line else cloth
	_fill(shoulder, lo, hi, cap, func(p: Vector3) -> bool:
		return p.y > -0.015 and _in_rounded(p, lo, hi, 0.045 + _lift))
	_taper(shoulder, -0.28, -0.06, Vector2(0.06, 0.058), Vector2(0.072, 0.07), skin, 0.028)
	_block(shoulder, Vector3(-0.054, -0.23, -0.082), Vector3(0.054, -0.09, -0.01), skin, 0.03)
	_block(shoulder, Vector3(-0.05 + 0.006 * side, -0.22, 0.01), Vector3(0.05 + 0.006 * side, -0.07, 0.074), skin, 0.03)
	_block(elbow, Vector3(-0.055, -0.05, -0.048), Vector3(0.055, 0.04, 0.062), skin, 0.03)
	# The forearm, wrapped blue from the wrist most of the way up (painted
	# on, not built over it), banded white from the wrist up.
	var blue := _p("wrap")
	var light := _p("wrap_light")
	var forearm := func(p: Vector3) -> Color:
		if p.y > -0.05:
			return skin
		return light if floori((p.y + 0.2) / _line) % 3 == 0 else blue
	_taper(elbow, -0.2, 0.0, Vector2(0.056, 0.054), Vector2(0.068, 0.066), forearm, 0.025)
	_answer_fist(elbow, side)


func _answer_fist(elbow: Node3D, side: float) -> void:
	var glove := _p("glove")
	# A square black glove: the knuckle row lit along the top, the thumb
	# across the front, the fingers split by shadow (tiny cubes only).
	var big := 1.0 if _tiny() else 1.3
	var paint := func(p: Vector3) -> Color:
		if p.y > -0.2 - _line and p.z < -0.02:
			return glove.lightened(0.08)
		return glove
	_block(elbow, Vector3(-0.056 * big, -0.2 - 0.13 * big, -0.062 * big), Vector3(0.056 * big, -0.2, 0.048 * big), paint, 0.02 if _tiny() else 0.0)
	_side_block(elbow, -side, -0.01, 0.06 * big, -0.2 - 0.12 * big, -0.2 - 0.082 * big, -0.062 * big - _v, -0.062 * big + 0.02, glove.lightened(0.08), 0.01)
	if _tiny():
		for x: float in [-0.028, 0.0, 0.028]:
			_block(elbow, Vector3(x - _v * 0.5, -0.33, -0.066), Vector3(x + _v * 0.5, -0.27, -0.05), _sh(glove))


# --- The Answer: head ----------------------------------------------------------------

## Everyone's head: a neck (thick on the big men, in shadow under the jaw),
## a square skull, the jaw narrowing to the chin (square on the Mauler,
## pointed on the Blur), flat ears.
func _skull(head: Node3D) -> void:
	var skin := _skin
	var fw := 0.15 * _b("face")
	var n := _r("neck")
	_taper(head, -0.07, 0.13, Vector2(0.066, 0.062) * n, Vector2(0.06, 0.056) * n, _sh(skin), 0.02, Vector3(0, 0, 0.015))
	_block(head, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), skin, 0.03)
	_fill(head, Vector3(-fw, 0.015, -0.15), Vector3(fw, 0.17, 0.12), skin, func(p: Vector3) -> bool: return _in_jaw(p))
	for side in [-1.0, 1.0]:
		_side_block(head, side, fw - 0.01, fw + 0.022, 0.15, 0.235, -0.02, 0.045, skin, 0.01)


func _in_jaw(p: Vector3) -> bool:
	var fw := 0.15 * _b("face")
	var t := clampf((p.y - 0.015) / 0.155, 0.0, 1.0)
	var half := lerpf(lerpf(0.03, fw - 0.005, _b("jaw")), fw, smoothstep(0.0, 0.6, t))
	return p.y >= 0.015 and p.y <= 0.17 and absf(p.x) <= half and p.z >= -0.15 and p.z <= lerpf(0.02, 0.12, t)


## The face in whole voxels, drawn for each scale: angry slanted brows, white
## eyes with dark pupils toward the nose, a straight nose, a flat mouth.
func _answer_face(head: Node3D) -> void:
	var skin := _skin
	var dark := Color(0.06, 0.05, 0.06)
	var white := Color(0.96, 0.95, 0.93)
	var iris: Color = _look.eyes
	var mouth := skin.darkened(0.55)
	if _tiny():
		_px(head, 2, 11, 5, 12, white)
		_px(head, 2, 11, 3, 12, dark)
		_px(head, 3, 12, 3, 12, iris)
		_px(head, 1, 12, 1, 12, dark, 1)
		_px(head, 1, 13, 5, 13, dark, 1)
		_px(head, 4, 14, 6, 14, dark, 1)
		_px(head, 0, 8, 0, 10, skin, 1)
		_px(head, 0, 7, 0, 7, _sh(skin))
		_px(head, 0, 4, 1, 4, mouth)
		_px(head, 6, 3, 7, 6, _sh(skin))
	elif voxel_scale == "medium":
		# Pupils in the middle of each eye (at the inner edge they read cross-eyed).
		_px(head, 2, 7, 4, 8, white)
		_px(head, 3, 7, 3, 8, dark)
		_px(head, 1, 8, 1, 8, dark, 1)
		_px(head, 1, 9, 4, 9, dark, 1)
		_px(head, 0, 5, 0, 6, skin, 1)
		_px(head, 0, 3, 0, 3, skin.darkened(0.3))
	else:
		_px(head, 1, 5, 2, 5, white)
		_px(head, 1, 5, 1, 5, dark)
		_px(head, 1, 6, 3, 6, dark, 1)
		_px(head, 0, 4, 0, 4, skin, 1)
		_px(head, 0, 2, 0, 2, skin.darkened(0.28))


func _zone(head: Node3D, id: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Hair" + id.capitalize()
	head.add_child(node)
	_zones[id] = node
	_zone_of[node] = id
	return node


## The part of a zone above HAT_CUT ("sides_high"...), made on first use.
func _zone_high(node: Node3D) -> Node3D:
	var id: String = _zone_of[node] + "_high"
	if not _zones.has(id):
		var high := Node3D.new()
		high.name = node.name + "High"
		node.get_parent().add_child(high)
		_zones[id] = high
	return _zones[id]


## Hidden under a hat that hides these zones. A hat hiding the top hides
## every zone's high part too.
static func _zone_hidden(zone: String, hide: Array) -> bool:
	if zone in hide or zone.trim_suffix("_high") in hide:
		return true
	# The high parts and the puff (big hair's outer volume) go under any hat
	# that covers the top.
	return (zone.ends_with("_high") or zone == "puff") and "top" in hide


## Inside the skull or jaw (head pivot space).
func _in_skull(p: Vector3) -> bool:
	var fw := 0.15 * _b("face")
	if _in_rounded(p, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), 0.03):
		return true
	return _in_jaw(p) or _in_band(p)


## The Stray's headband (on the head, so the hair keeps out of it).
func _in_band(p: Vector3) -> bool:
	if fighter != "free_runner" or p.y < 0.252 or p.y >= 0.324:
		return false
	var fw := 0.15 * _b("face")
	return _in_rounded(p, Vector3(-fw, 0.13, -0.15) - Vector3.ONE * _v, Vector3(fw, 0.345, 0.155) + Vector3.ONE * _v, 0.03 + _v)


## A block of hair that leaves the skull's own cells alone: hair and skull
## share the head's grid, and a hair cube on a skin cube flickers.
## Hair above it splits off onto its zone's high part (a cap or crown
## hides it, so no hair pokes out through the hat; the hair below shows
## under the brim).
const HAT_CUT := 0.3


func _lock(node: Node3D, from: Vector3, to: Vector3, color: Color, r := 0.0) -> void:
	var lo := from.min(to)
	var hi := from.max(to)
	if lo.y < 0.05:
		# Long hair: kept a cube clear of the trunk (the head pivot is 0.57 up).
		var inside := func(p: Vector3) -> bool:
			return _in_rounded(p, lo, hi, r) and not _in_skull(p) and not _in_trunk(p + Vector3(0, 0.57, 0), _lift * 2.0)
		_fill(node, lo, hi, color, inside)
		return
	var id: String = _zone_of.get(node, "")
	var cut: float = HAT_CUT if id in ["front", "sides", "back", "short"] else (_crown_cut if id == "top" else 9.0)
	if cut > 5.0:
		_fill(node, lo, hi, color, func(p: Vector3) -> bool:
			return _in_rounded(p, lo, hi, r) and not _in_skull(p))
		return
	_fill(node, lo, hi, color, func(p: Vector3) -> bool:
		return p.y < cut and _in_rounded(p, lo, hi, r) and not _in_skull(p))
	_fill(_zone_high(node), lo, hi, color, func(p: Vector3) -> bool:
		return p.y >= cut and _in_rounded(p, lo, hi, r) and not _in_skull(p))


func _side_lock(node: Node3D, side: float, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, color: Color, r := 0.0) -> void:
	_lock(node, Vector3(x0 * side, y0, z0), Vector3(x1 * side, y1, z1), color, r)


## Squared black hair in four zones, all one flat black (no sheen). The top
## is a grid of square clumps, each raised to a height from a drawn height
## map (a crest at the crown, stepping down to the edges); bangs in squared
## clumps swept a little to one side, on whole cells on the large scale;
## sides in two tiers over the ears with sideburns; the back in layers
## stepping down to the nape. The large scale uses fewer, bigger clumps.
func _answer_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var w := fw + 0.03
	var top := _zone(head, "top")
	var heights := [
		[0.40, 0.43, 0.44, 0.45, 0.43, 0.40],
		[0.43, 0.47, 0.49, 0.48, 0.47, 0.42],
		[0.44, 0.49, 0.52, 0.50, 0.48, 0.44],
		[0.44, 0.48, 0.51, 0.52, 0.49, 0.44],
		[0.42, 0.46, 0.49, 0.48, 0.46, 0.42],
		[0.39, 0.42, 0.44, 0.43, 0.42, 0.39],
	] if _tiny() else [
		[0.41, 0.44, 0.45, 0.41],
		[0.45, 0.50, 0.49, 0.45],
		[0.45, 0.51, 0.52, 0.46],
		[0.42, 0.46, 0.46, 0.42],
	] if voxel_scale == "medium" else [
		[0.42, 0.45, 0.41],
		[0.46, 0.52, 0.47],
		[0.42, 0.46, 0.42],
	]
	var n: int = heights.size()
	var z0 := -0.175
	var z1 := 0.185
	var cw := 2.0 * w / n
	var cd := (z1 - z0) / n
	# The hairline: on the large scale up at the top of the forehead.
	var line: float = _pick(0.3, 0.312, 0.324)
	_crown_at = 0.52
	_crown_half = w
	_lock(top, Vector3(-w, line, z0), Vector3(w, 0.39, z1), hair, 0.03)
	for row in n:
		for col in n:
			var x := -w + col * cw
			var z := z0 + row * cd
			_lock(top, Vector3(x - 0.002, maxf(0.33, line), z - 0.002), Vector3(x + cw + 0.002, heights[row][col], z + cd + 0.002), hair)
	var bangs := _zone(head, "front")
	if _tiny():
		for c: Array in [[-0.11, 0.055, 0.285], [-0.055, 0.055, 0.255], [0.0, 0.055, 0.25], [0.055, 0.055, 0.265], [0.11, 0.055, 0.295]]:
			var x: float = c[0]
			var half: float = c[1] * 0.5
			var bottom: float = c[2]
			var knee := lerpf(bottom, 0.36, 0.45)
			_lock(bangs, Vector3(x - half, knee, -0.19), Vector3(x + half, 0.37, -0.13), hair)
			# The tip: narrower, swept toward the fighter's left.
			_lock(bangs, Vector3(x - half * 0.6 - 0.012, bottom, -0.185), Vector3(x + half * 0.6 - 0.012, knee + 0.01, -0.135), hair)
	else:
		# [x0, x1, bottom], one cell proud of the forehead: a short fringe
		# along the hairline, one lock dipping a row, swept to his left. Two
		# rows of forehead show above the brows.
		for c: Array in [[-0.144, 0.144, line], [-0.072, 0.0, 0.288]]:
			_lock(bangs, Vector3(c[0], c[2], -0.18), Vector3(c[1], 0.37, -0.12), hair)
	var sides := _zone(head, "sides")
	for side in [-1.0, 1.0]:
		var lead := -0.13 if _tiny() else -0.1
		_side_lock(sides, side, fw - 0.02, w + 0.008, 0.3, 0.38, lead, 0.15, hair, 0.01)
		_side_lock(sides, side, fw - 0.02, w - 0.008, 0.235, 0.31, -0.1, 0.12, hair, 0.01)
		_side_lock(sides, side, fw - 0.012, fw + 0.014, 0.17, 0.25, -0.07, -0.025, hair)
	var back := _zone(head, "back")
	_lock(back, Vector3(-w - 0.005, 0.27, 0.06), Vector3(w + 0.005, 0.38, 0.2), hair, 0.02)
	var layers := [
		[0.18, 0.28, [[-0.165, -0.085], [-0.085, 0.0], [0.0, 0.085], [0.085, 0.165]]],
		[0.09, 0.19, [[-0.12, -0.04], [-0.04, 0.04], [0.04, 0.12]]],
	] if _tiny() else [
		[0.17, 0.28, [[-0.165, -0.055], [-0.055, 0.055], [0.055, 0.165]]],
		[0.085, 0.18, [[-0.11, 0.0], [0.0, 0.11]]],
	] if voxel_scale == "medium" else [
		[0.16, 0.28, [[-0.16, 0.0], [0.0, 0.16]]],
		[0.08, 0.17, [[-0.09, 0.09]]],
	]
	for layer: Array in layers:
		var i := 0
		for span: Array in layer[2]:
			# Neighbors step in and out a little, like layered locks.
			var depth := 0.2 - (i % 2) * 0.012
			_lock(back, Vector3(span[0], layer[0], 0.06), Vector3(span[1], layer[1], depth), hair, 0.01)
			i += 1


# --- Shared by the other fighters ---------------------------------------------------

## A strip from a to b (width across across, thick through), squared off.
func _strip(node: Node3D, a: Vector3, b: Vector3, width: float, thick: float, color: Variant, across := Vector3.UP) -> void:
	var axis := b - a
	var wide := (across - axis * across.dot(axis) / axis.length_squared()).normalized()
	var face := wide.cross(axis).normalized()
	var pad := Vector3.ONE * (width + thick)
	_fill(node, a.min(b) - pad, a.max(b) + pad, color, func(p: Vector3) -> bool:
		var t := (p - a).dot(axis) / axis.length_squared()
		if t < 0.0 or t > 1.0:
			return false
		var d := p - (a + axis * t)
		return absf(d.dot(wide)) <= width * 0.5 and absf(d.dot(face)) <= thick * 0.5)


## A bare trunk (pecs standing out, shadow lines across the abs), for the
## fighters whose chest shows.
func _bare_trunk(torso: Node3D, abs_top: float) -> void:
	var skin := _skin
	var c := _r("chest")
	var body := func(p: Vector3) -> Color:
		if p.z < 0.0 and absf(p.x) < 0.1 * c and p.y < abs_top:
			for y: float in [0.1, 0.19, 0.28]:
				if p.y >= y and p.y < y + _v:
					return _sh(skin)
		return skin
	_fill(torso, Vector3(-0.4, -0.05, -0.25), Vector3(0.4, 0.63, 0.25), body, func(p: Vector3) -> bool:
		return _in_trunk(p) and _neck_clear(p))
	var pec := func(p: Vector3) -> Color:
		return _sh(skin) if p.y < 0.34 + _v else skin
	var lo := Vector3(-0.2 * c, 0.34, -_hz(0.42) - _lift)
	var hi := Vector3(0.2 * c, 0.5, -0.05)
	_fill(torso, lo, hi, pec, func(p: Vector3) -> bool: return _in_rounded(p, lo, hi, 0.0) and _off_head(p))


## Cloth over the trunk, one cube out, where keep() says (paint() colors it).
func _trunk_shell(torso: Node3D, paint: Callable, keep: Callable, grow := 1.0) -> void:
	_fill(torso, Vector3(-0.45, -0.1, -0.3), Vector3(0.45, 0.7, 0.3), paint, func(p: Vector3) -> bool:
		return _in_trunk(p, _lift * grow) and not _in_trunk(p, _lift * (grow - 1.0)) and _neck_clear(p) and keep.call(p))


## A band round the waist, outside everything, and its knot.
func _waist_band(torso: Node3D, color: Color, grow: float, knot: Vector3) -> void:
	var band := func(p: Vector3) -> Color:
		return _sh(color) if p.y < -0.04 + _v else color
	_fill(torso, Vector3(-0.45, -0.06, -0.3), Vector3(0.45, 0.07, 0.3), band, func(p: Vector3) -> bool:
		return p.y <= 0.05 and _in_trunk(p, _lift * grow))
	_block(torso, knot - Vector3(0.045, 0.055, 0.03), knot + Vector3(0.045, 0.055, 0.03), color)


## Where the forearm ends and the fist starts (elbow space) on the Mauler,
## the Blur and the Stray: longer than the Answer's 0.2, which read short.
const WRIST := -0.25


## Arms: a big square deltoid (under a cloth shoulder, trimmed, if cap is a
## color), the upper arm with biceps and triceps, the elbow, the forearm
## painted by forearm (wraps and tape are paint, not built over it).
func _arm_shape(shoulder: Node3D, elbow: Node3D, side: float, forearm: Callable, cap: Variant = null, trim := Color.WHITE) -> void:
	var skin := _skin
	var a := _r("arm")
	var f := _r("forearm")
	var center := Vector3(0.012 * side, -0.035, 0)
	var half := Vector3(0.095, 0.09, 0.09) * a
	_block(shoulder, center - half, center + half, skin, 0.045)
	if cap != null:
		var cloth: Color = cap
		var lo := center - half - Vector3.ONE * _lift
		var hi := center + half + Vector3.ONE * _lift
		var shoulder_paint := func(p: Vector3) -> Color:
			return trim if p.y < -0.015 + _line else cloth
		_fill(shoulder, lo, hi, shoulder_paint, func(p: Vector3) -> bool:
			return p.y > -0.015 and _in_rounded(p, lo, hi, 0.045 + _lift))
	_taper(shoulder, -0.28, -0.06, Vector2(0.06, 0.058) * a, Vector2(0.072, 0.07) * a, skin, 0.028)
	_block(shoulder, Vector3(-0.054 * a, -0.23, -0.082 * a), Vector3(0.054 * a, -0.09, -0.01), skin, 0.03)
	_block(shoulder, Vector3(-0.05 * a + 0.006 * side, -0.22, 0.01), Vector3(0.05 * a + 0.006 * side, -0.07, 0.074 * a), skin, 0.03)
	_block(elbow, Vector3(-0.055 * f, -0.05, -0.048 * f), Vector3(0.055 * f, 0.04, 0.062 * f), skin, 0.03)
	_taper(elbow, WRIST, 0.0, Vector2(0.056, 0.054) * f, Vector2(0.068, 0.066) * f, forearm, 0.025)


## A square fist, its knuckle row lit, the thumb across the front; cuff
## colors the wrist row, fingers (fingerless gloves) the curled fingers.
func _fist(elbow: Node3D, side: float, glove: Color, cuff: Variant = null, fingers: Variant = null, big := 1.3) -> void:
	var front := -0.062 * big
	var paint := func(p: Vector3) -> Color:
		if cuff != null and p.y > WRIST - _v:
			return cuff
		if fingers != null and p.z < front + _v and p.y < WRIST - 0.04 * big:
			return fingers
		if p.y > WRIST - _line and p.z < -0.02:
			return glove.lightened(0.08)
		return glove
	_block(elbow, Vector3(-0.056 * big, WRIST - 0.13 * big, front), Vector3(0.056 * big, WRIST, 0.048 * big), paint)
	_side_block(elbow, -side, -0.01, 0.06 * big, WRIST - 0.12 * big, WRIST - 0.082 * big, front - _v, front + 0.02, fingers if fingers != null else glove.lightened(0.08), 0.01)


## A shoe on its own ankle pivot (lf / rf): sole, upper and toe box, a
## collar up to top (a boot's shaft painted by shaft), laces, a stripe
## down the outside.
func _shoe_on(knee: Node3D, side: float, upper: Color, sole: Color, toe: Color, stripe: Color, laces: Color, top := -0.33, shaft: Variant = null) -> void:
	var foot := _pivot(("l" if side < 0 else "r") + "f", knee, Vector3(0, -ANKLE, 0))
	var shoe := Node3D.new()
	shoe.name = "Shoe"
	shoe.position = Vector3(0, ANKLE, 0)
	foot.add_child(shoe)
	var w := 0.066 * maxf(_r("calf"), 1.0)
	_block(shoe, Vector3(-w - 0.006, -0.46, -0.178), Vector3(w + 0.006, -0.43, 0.086), sole)
	_block(shoe, Vector3(-w, -0.44, -0.16), Vector3(w, -0.37, 0.08), upper, 0.02)
	_block(shoe, Vector3(-w + 0.004, -0.44, -0.17), Vector3(w - 0.004, -0.395, -0.09), toe, 0.02)
	_taper(shoe, -0.38, top, Vector2(w, w), Vector2(w - 0.004, w - 0.004), shaft if shaft != null else upper, 0.02, Vector3(0, 0, 0.012))
	_block(shoe, Vector3(-0.03, -0.41, -0.15), Vector3(0.03, -0.41 + _v, -0.11), laces)
	_side_block(shoe, side, w - 0.004, w + _v * 0.6, -0.43, -0.43 + _line, -0.14, 0.06, stripe)


## A patch box (in a leg's own space, x measured outward) for painting.
func _in_box(p: Vector3, side: float, box: Array) -> bool:
	var x := p.x * side
	return x >= box[0] and x <= box[1] and p.y >= box[2] and p.y <= box[3] and (p.z < 0.0) == (box[4] < 0.0)


# --- The Mauler ----------------------------------------------------------------------

## A bare chest under an open black vest trimmed white, the red sash
## knotted in front with long tails, black trunks.
func _mauler_torso(hips: Node3D, torso: Node3D) -> void:
	var vest := _p("vest")
	var trim := _p("trim")
	var c := _r("chest")
	_bare_trunk(torso, 0.34)
	var open := func(p: Vector3) -> float:
		return lerpf(0.07, 0.17 * c, clampf(p.y / 0.5, 0.0, 1.0))
	var vest_paint := func(p: Vector3) -> Color:
		if p.z < 0.0 and absf(p.x) < open.call(p) + _line:
			return trim
		if p.y > 0.36 and absf(p.x) > _hx(p.y) + _lift - _line:
			return trim
		if p.y < 0.06 + _line:
			return trim
		return vest
	_trunk_shell(torso, vest_paint, func(p: Vector3) -> bool:
		return p.y > 0.06 and not (p.z < 0.0 and absf(p.x) < open.call(p)))
	var front := -_hz(0.0) - 2.0 * _lift
	_waist_band(torso, _p("sash"), 2.0, Vector3(0, 0.005, front - 0.02))
	for side in [-1.0, 1.0]:
		_side_block(torso, side, 0.008, 0.06, -0.36 + (0.05 if side > 0 else 0.0), -0.04, front - _v, front, _p("sash"))
	var w := _r("waist")
	_block(hips, Vector3(-0.19 * w, -0.11, -0.125 * w), Vector3(0.19 * w, 0.12, 0.135 * w), _p("trunks"))


## Huge thighs and calves, wide black trunks to mid-thigh with a white hem,
## high black boots with red laces up the front, a white band at the top,
## red soles.
func _mauler_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var skin := _skin
	var t := _r("thigh")
	var k := _r("calf")
	_taper(hip, -0.44, 0.02, Vector2(0.062, 0.064) * t, Vector2(0.088, 0.09) * t, skin, 0.03)
	_block(hip, Vector3(-0.06 * t, -0.3, -0.1 * t), Vector3(0.06 * t, -0.08, -0.02), skin, 0.03)
	var trunks := func(p: Vector3) -> Color:
		return _p("trim") if p.y < -0.24 + _v else _p("trunks")
	_taper(hip, -0.24, 0.04, Vector2(0.09 * t + _lift, 0.092 * t + _lift), Vector2(0.088 * t + _lift, 0.09 * t + _lift), trunks, 0.03)
	_block(knee, Vector3(-0.055 * k, -0.05, -0.055 * k), Vector3(0.055 * k, 0.04, 0.05 * k), skin, 0.03)
	_taper(knee, -0.24, 0.0, Vector2(0.05, 0.052) * k, Vector2(0.06, 0.062) * k, skin, 0.025)
	_block(knee, Vector3(-0.045 * k, -0.2, 0.0), Vector3(0.045 * k, -0.05, 0.075 * k), skin, 0.03)
	var top := -0.2
	var boot := func(p: Vector3) -> Color:
		if p.y > top - _v:
			return _p("band")
		if p.z < -0.03 and p.y > -0.4 and absf(p.x) < 0.04:
			var row := floori(p.y / _v)
			var col := floori(p.x / _v)
			return _p("accent") if (posmod(row, 2) == 0) == (col == 0) else _p("shoes")
		return _p("shoes")
	_shoe_on(knee, side, _p("shoes"), _p("sole"), _p("shoes"), _p("sole"), _p("accent"), top, boot)


## Big arms, white tape round the wrists, huge red gloves.
func _mauler_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var skin := _skin
	var tape := func(p: Vector3) -> Color:
		if p.y > WRIST + 0.1:
			return skin
		return _p("tape_dark") if posmod(floori((p.y - WRIST) / _v), 3) == 2 else _p("tape")
	_arm_shape(shoulder, elbow, side, tape, _p("vest"), _p("trim"))
	# The glove: a padded block, the knuckle pad standing out in front (lit),
	# the thumb on the inside, laces on the palm, a taped cuff.
	var red := _p("glove")
	var glove := func(p: Vector3) -> Color:
		return _p("tape") if p.y > WRIST - 0.036 else red
	var d := WRIST + 0.2
	_block(elbow, Vector3(-0.126, -0.48 + d, -0.15), Vector3(0.126, WRIST, 0.108), glove)
	_block(elbow, Vector3(-0.108, -0.46 + d, -0.186), Vector3(0.108, -0.29 + d, -0.15), red.lightened(0.07))
	_side_block(elbow, -side, 0.126, 0.162, -0.4 + d, -0.28 + d, -0.11, 0.0, red)
	_block(elbow, Vector3(-0.018, -0.3 + d, 0.108), Vector3(0.018, WRIST - 0.036, 0.144), _p("laces"))


## A heavy brow, small hard eyes, a frown.
func _mauler_face(head: Node3D) -> void:
	var skin := _skin
	var dark := Color(0.06, 0.05, 0.06)
	_px(head, 1, 5, 2, 5, Color(0.96, 0.95, 0.93))
	_px(head, 1, 5, 1, 5, dark)
	_px(head, 1, 6, 3, 6, dark, 1)
	_px(head, 0, 6, 0, 6, skin, 1)
	_px(head, 0, 4, 0, 4, skin, 1)
	_px(head, 0, 2, 0, 2, skin.darkened(0.35))
	_px(head, 1, 1, 1, 1, skin.darkened(0.35))


## A thick flat top, low at the front in a few points, short at the sides.
func _mauler_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var w := fw + 0.025
	_crown_at = 0.46
	_crown_half = w
	_lock(_zone(head, "top"), Vector3(-w, 0.3, -0.175), Vector3(w, 0.46, 0.185), hair, 0.02)
	var bangs := _zone(head, "front")
	_lock(bangs, Vector3(-0.144, 0.288, -0.18), Vector3(0.144, 0.4, -0.12), hair)
	for x: float in [-0.108, 0.036]:
		_lock(bangs, Vector3(x, 0.252, -0.18), Vector3(x + 0.072, 0.3, -0.12), hair)
	var sides := _zone(head, "sides")
	for side in [-1.0, 1.0]:
		_side_lock(sides, side, fw - 0.02, w, 0.25, 0.4, -0.1, 0.15, hair)
	_lock(_zone(head, "back"), Vector3(-w, 0.2, 0.06), Vector3(w, 0.4, 0.19), hair)


# --- The Blur ------------------------------------------------------------------------

## Lean: a sleeveless black crop top to a high collar, trimmed violet, bare
## abs below, the violet sash knotted at his left hip, its tails hanging.
func _blur_torso(hips: Node3D, torso: Node3D) -> void:
	var top := _p("top")
	var violet := _p("trim")
	_bare_trunk(torso, 0.31)
	var crop := func(p: Vector3) -> Color:
		if p.y < 0.31 + _line or (p.y > 0.36 and absf(p.x) > _hx(p.y) + _lift - _line):
			return violet
		return top
	_trunk_shell(torso, crop, func(p: Vector3) -> bool: return p.y > 0.31)
	var neck := 0.066 * _r("neck")
	var collar := func(p: Vector3) -> Color:
		return violet if p.y > 0.69 - _v else top
	_fill(torso, Vector3(-0.2, 0.5, -0.2), Vector3(0.2, 0.7, 0.2), collar, func(p: Vector3) -> bool:
		var r := Vector2(p.x, p.z - 0.015).length()
		return p.y > 0.55 and p.y < 0.69 and r > neck + 0.035 and r < neck + 0.035 + 2.0 * _v and _off_head(p))
	var front := -_hz(0.0) - _lift
	var sash := _p("sash")
	_waist_band(torso, sash, 1.0, Vector3(-_hx(0.0) * 0.6, 0.005, front - 0.02))
	_block(torso, Vector3(-0.17, -0.3, front - 3.0 * _lift), Vector3(-0.11, -0.03, front - 2.0 * _lift), sash)
	_block(torso, Vector3(-0.12, -0.22, front - 3.0 * _lift), Vector3(-0.07, -0.03, front - 2.0 * _lift), sash.darkened(0.15))
	var w := _r("waist")
	_block(hips, Vector3(-0.2 * w, -0.11, -0.13 * w), Vector3(0.2 * w, 0.12, 0.14 * w), _p("pants"))


## Balloon pants with big pale patches, gathered at the shin into white
## and violet leg wraps; black shoes with a violet stripe.
func _blur_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var pants := _p("pants")
	var t := _r("thigh")
	# [x0, x1 outward, y0, y1, front (-1) or back (1)]: drawn, not random.
	var thigh_patch := [0.0, 0.12, -0.32, -0.2, -1.0] if side < 0 else [0.04, 0.14, -0.12, -0.02, -1.0]
	var thigh := func(p: Vector3) -> Color:
		return _p("patch") if _in_box(p, side, thigh_patch) else pants
	_taper(hip, -0.44, 0.04, Vector2(0.125, 0.128) * t, Vector2(0.118, 0.122) * t, thigh, 0.04)
	var knee_patch := [-0.04, 0.08, -0.14, -0.06, -1.0] if side > 0 else [0.06, 0.14, -0.1, -0.02, 1.0]
	var shin := func(p: Vector3) -> Color:
		if p.y > 0.03 - _v:
			return _sh(pants)
		return _p("patch") if _in_box(p, side, knee_patch) else pants
	_taper(knee, -0.17, 0.03, Vector2(0.118 * t + _lift, 0.122 * t + _lift), Vector2(0.114 * t, 0.118 * t), shin, 0.04)
	var wraps := func(p: Vector3) -> Color:
		return _p("band_a") if posmod(floori(p.y / _v), 3) == 1 else _p("band_b")
	_taper(knee, -0.36, -0.17, Vector2(0.06, 0.064), Vector2(0.068, 0.072), wraps, 0.02)
	_shoe_on(knee, side, _p("shoes"), _p("sole"), _p("shoes"), _p("accent"), _p("accent"))


## Lean arms, white wraps banded violet, black gloves with a violet cuff.
func _blur_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var skin := _skin
	var wraps := func(p: Vector3) -> Color:
		if p.y > WRIST + 0.15:
			return skin
		return _p("band_a") if posmod(floori((p.y - WRIST) / _v), 3) == 1 else _p("band_b")
	_arm_shape(shoulder, elbow, side, wraps)
	_fist(elbow, side, _p("glove"), _p("glove_cuff"), null, 1.15)


## Narrowed eyes, violet, under the fringe.
func _blur_face(head: Node3D) -> void:
	var skin := _skin
	_px(head, 1, 5, 2, 5, Color(0.96, 0.95, 0.93))
	_px(head, 1, 5, 1, 5, _look.eyes)
	_px(head, 1, 6, 3, 6, Color(0.06, 0.05, 0.06), 1)
	_px(head, 0, 4, 0, 4, skin, 1)
	_px(head, 0, 2, 0, 2, skin.darkened(0.25))


## A huge mass of curls, bigger than the head: a round block with square
## curls set round it in two rings and across the top, a fringe of points
## over the brow, the sides down past the ears.
func _blur_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var w := fw + 0.07
	var curl := 0.1
	# Under a cap or crown the curls give way to a short cut (below); the
	# crown sits on it like the Answer's.
	_short_under_hats = true
	_crown_at = 0.52
	_crown_half = fw + 0.03
	var top := _zone(head, "top")
	_lock(top, Vector3(-w, 0.3, -0.16), Vector3(w, 0.58, 0.25), hair, 0.07)
	# Square curls round the mass, every other one stepped up, each ring
	# turned half a step from the last; the lowest ring leaves the face open.
	for ring in 3:
		var y := 0.34 + ring * 0.1
		for i in 12:
			var a := (i + ring * 0.5) * TAU / 12.0
			if cos(a) < -0.55 and ring == 0:
				continue
			var at := Vector3(sin(a) * (w + 0.035), y + (i % 2) * 0.035, 0.045 + cos(a) * 0.235)
			_lock(top, at - Vector3.ONE * curl * 0.5, at + Vector3.ONE * curl * 0.5, hair)
	for x: float in [-0.08, 0.0, 0.08]:
		for z: float in [-0.07, 0.03, 0.13]:
			var lift := 0.03 if (x == 0.0) != (z == 0.03) else 0.0
			_lock(top, Vector3(x - curl * 0.5, 0.54, z - curl * 0.5), Vector3(x + curl * 0.5, 0.61 + lift, z + curl * 0.5), hair)
	var bangs := _zone(head, "front")
	for c: Array in [[-0.18, -0.072, 0.288], [-0.072, 0.036, 0.288], [0.036, 0.18, 0.324], [-0.036, 0.036, 0.252]]:
		_lock(bangs, Vector3(c[0], c[2], -0.19), Vector3(c[1], 0.42, -0.12), hair)
	# Snug to the head at the sides and back (what shows under a hat), the
	# puffed-out volume over it its own zone (gone under a hat).
	var sides := _zone(head, "sides")
	var puff := _zone(head, "puff")
	for side in [-1.0, 1.0]:
		_side_lock(sides, side, fw - 0.02, fw + 0.05, 0.2, 0.42, -0.08, 0.18, hair)
		_side_lock(puff, side, fw - 0.02, w, 0.2, 0.42, -0.1, 0.2, hair, 0.02)
	_lock(_zone(head, "back"), Vector3(-fw - 0.02, 0.12, 0.08), Vector3(fw + 0.02, 0.42, 0.21), hair)
	_lock(puff, Vector3(-w + 0.02, 0.15, 0.08), Vector3(w - 0.02, 0.42, 0.26), hair, 0.04)
	# The short cut: a close crop with a squared top, tidy at the sides and
	# back, a short fringe.
	var short := _zone(head, "short")
	# (A whole cube out from the skull, or it makes no cubes at all.)
	var c := fw + _v * 1.2
	_lock(short, Vector3(-c, 0.3, -0.17), Vector3(c, 0.42, 0.18), hair, 0.02)
	for side in [-1.0, 1.0]:
		_side_lock(short, side, fw - 0.02, c, 0.2, 0.36, -0.1, 0.15, hair)
	_lock(short, Vector3(-c, 0.14, 0.06), Vector3(c, 0.36, 0.155 + _v * 1.2), hair)
	_lock(short, Vector3(-0.15, 0.3, -0.19), Vector3(0.15, 0.4, -0.13), hair)


# --- The Stray -----------------------------------------------------------------------

## A sleeveless black gi crossed at the chest, trimmed white; a red scarf
## round the neck, an end hanging; the red belt with white cloth hanging.
func _stray_torso(hips: Node3D, torso: Node3D) -> void:
	var gi := _p("gi")
	var white := _p("trim")
	var red := _p("band")
	_bare_trunk(torso, 0.2)
	var vee := func(p: Vector3) -> float:
		return (p.y - 0.2) * 0.5
	var paint := func(p: Vector3) -> Color:
		if (p.z < 0.0 and p.y > 0.18 and absf(p.x) < vee.call(p) + _line) or (p.y > 0.36 and absf(p.x) > _hx(p.y) + _lift - _line):
			return white
		return gi
	_trunk_shell(torso, paint, func(p: Vector3) -> bool:
		return not (p.z < 0.0 and p.y > 0.2 and absf(p.x) < vee.call(p)))
	var neck := 0.066 * _r("neck")
	_fill(torso, Vector3(-0.22, 0.48, -0.22), Vector3(0.22, 0.66, 0.22), red, func(p: Vector3) -> bool:
		var r := Vector2(p.x, p.z - 0.015).length()
		return p.y > 0.52 and p.y < 0.63 and r > neck + 0.035 and r < neck + 0.035 + 2.0 * _v and _off_head(p))
	var chest := -_hz(0.45) - 2.0 * _lift
	_block(torso, Vector3(-0.1, 0.3, chest), Vector3(-0.03, 0.54, chest + _v), red)
	var front := -_hz(0.0) - 2.0 * _lift
	_waist_band(torso, red, 2.0, Vector3(0, 0.005, front - 0.02))
	# Two thin white strips hanging from under the knot, apart, uneven.
	for side in [-1.0, 1.0]:
		_side_block(torso, side, 0.036, 0.072, -0.3 + (0.07 if side > 0 else 0.0), -0.04, front - _v, front, white)
	var w := _r("waist")
	_block(hips, Vector3(-0.2 * w, -0.11, -0.13 * w), Vector3(0.2 * w, 0.12, 0.14 * w), gi)


## Baggy black pants torn off at mid-shin (the hem notched every other
## cube), white X patches; bare shins, red wraps at the ankle; white shoes.
func _stray_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var gi := _p("gi")
	var white := _p("trim")
	var t := _r("thigh")
	# An X of five cubes, on the left thigh and the right knee.
	var cross := func(p: Vector3, at: Vector2) -> bool:
		var c := Vector2i(floori((p.x * side - at.x) / _v), floori((p.y - at.y) / _v))
		return p.z < 0.0 and absi(c.x) == absi(c.y) and absi(c.x) <= 1
	var thigh := func(p: Vector3) -> Color:
		return white if side < 0 and cross.call(p, Vector2(0.02, -0.2)) else gi
	_taper(hip, -0.44, 0.04, Vector2(0.11, 0.114) * t, Vector2(0.112, 0.116) * t, thigh, 0.04)
	var pants := func(p: Vector3) -> Color:
		if p.y < -0.2 + 2.0 * _v:
			return _p("hem")
		return white if side > 0 and cross.call(p, Vector2(0.0, -0.08)) else gi
	_fill(knee, Vector3(-0.2, -0.25, -0.2), Vector3(0.2, 0.05, 0.2), pants, func(p: Vector3) -> bool:
		var notch := _v if posmod(floori(p.x / _v) + floori(p.z / _v), 2) == 0 else 0.0
		return p.y > -0.2 + notch and p.y < 0.03 and _in_rounded(p, Vector3(-0.108, -0.25, -0.112), Vector3(0.108, 0.03, 0.112), 0.035))
	var k := _r("calf")
	_taper(knee, -0.3, -0.18, Vector2(0.048, 0.05) * k, Vector2(0.054, 0.056) * k, _skin, 0.02)
	var wraps := func(p: Vector3) -> Color:
		return _p("band").darkened(0.25) if posmod(floori(p.y / _v), 2) == 0 else _p("band")
	_taper(knee, -0.36, -0.28, Vector2(0.06, 0.064), Vector2(0.06, 0.064), wraps, 0.02)
	_shoe_on(knee, side, _p("shoes"), _p("sole"), Color(0.1, 0.1, 0.11), _p("accent"), Color(0.1, 0.1, 0.11))


## Muscled arms, thick white wraps in rings, green fingerless gloves.
func _stray_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var skin := _skin
	var rings := func(p: Vector3) -> Color:
		if p.y > WRIST + 0.12:
			return skin
		return _p("tape") if posmod(floori((p.y - WRIST) / _v), 2) == 0 else skin
	_arm_shape(shoulder, elbow, side, rings)
	_fist(elbow, side, _p("glove"), _p("glove_cuff"))


## Level brows, a small closed mouth (a toothy grin with smile lines read
## goofy).
func _stray_face(head: Node3D) -> void:
	var skin := _skin
	var dark := Color(0.06, 0.05, 0.06)
	_px(head, 1, 5, 2, 5, Color(0.96, 0.95, 0.93))
	_px(head, 1, 5, 1, 5, dark)
	_px(head, 1, 6, 3, 6, dark, 1)
	_px(head, 0, 4, 0, 4, skin, 1)
	_px(head, 0, 2, 0, 2, skin.darkened(0.3))


## A bush of thick square locs standing up off the crown (a drawn height
## map, alternating high and low), tufts out over the ears, locs down the
## back; the red headband round the brow, knotted behind, tails trailing.
func _stray_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var w := fw + 0.03
	_crown_at = HAT_CUT + 0.125
	_crown_half = fw + 0.03
	_crown_hides = ["top"]
	var top := _zone(head, "top")
	_lock(top, Vector3(-w, 0.324, -0.17), Vector3(w, 0.42, 0.19), hair, 0.02)
	var heights := [
		[0.50, 0.57, 0.52, 0.58],
		[0.58, 0.52, 0.62, 0.54],
		[0.53, 0.61, 0.55, 0.60],
		[0.56, 0.50, 0.58, 0.52],
	]
	var cw := 2.0 * w / 4.0
	var cd := 0.36 / 4.0
	for row in 4:
		for col in 4:
			var x := -w + col * cw
			var z := -0.17 + row * cd
			_lock(top, Vector3(x + 0.008, 0.38, z + 0.008), Vector3(x + cw - 0.008, heights[row][col], z + cd - 0.008), hair)
	var bangs := _zone(head, "front")
	for x: float in [-0.11, 0.03]:
		_lock(bangs, Vector3(x, 0.324, -0.19), Vector3(x + 0.07, 0.4, -0.13), hair)
	var sides := _zone(head, "sides")
	for side in [-1.0, 1.0]:
		for i in 3:
			var z := -0.08 + i * 0.1
			_side_lock(sides, side, w - 0.02, w + 0.06, 0.34 + (i % 2) * 0.03, 0.42 + (i % 2) * 0.03, z, z + 0.07, hair)
		# Locs hanging down the side of the head, over and behind the ear
		# (these show under a hat).
		for z: float in [-0.09, 0.0, 0.09]:
			_side_lock(sides, side, fw - 0.01, fw + 0.035, 0.16 + (0.03 if z == 0.0 else 0.0), 0.3, z, z + 0.06, hair)
	var back := _zone(head, "back")
	_lock(back, Vector3(-w, 0.324, 0.1), Vector3(w, 0.42, 0.2), hair)
	for x: float in [-0.13, -0.05, 0.03, 0.11]:
		_lock(back, Vector3(x - 0.03, 0.08 + (0.04 if x > 0.0 else 0.0), 0.13), Vector3(x + 0.03, 0.252, 0.2), hair)
	# The headband, knot and tails: their own part, off under any hat.
	var red := _p("band")
	_headband = Node3D.new()
	_headband.name = "Headband"
	head.add_child(_headband)
	_fill(_headband, Vector3(-0.25, 0.24, -0.25), Vector3(0.25, 0.34, 0.25), red, func(p: Vector3) -> bool:
		return _in_band(p) and not _in_skull_only(p))
	_block(_headband, Vector3(-0.08, 0.25, 0.17), Vector3(0.0, 0.33, 0.22), red.darkened(0.15))
	_strip(_headband, Vector3(-0.04, 0.29, 0.21), Vector3(-0.32, 0.16, 0.5), 0.06, _v, red)
	_strip(_headband, Vector3(-0.01, 0.27, 0.21), Vector3(-0.17, 0.02, 0.46), 0.05, _v, red.darkened(0.12))


## The skull and jaw alone (not the band).
func _in_skull_only(p: Vector3) -> bool:
	var fw := 0.15 * _b("face")
	return _in_rounded(p, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), 0.03) or _in_jaw(p)


# --- The Catalyst --------------------------------------------------------------------

## A barrel chest under an open dark robe trimmed white, the sash dark with
## a white stripe, knotted in front.
func _catalyst_torso(hips: Node3D, torso: Node3D) -> void:
	var robe := _p("robe")
	var trim := _p("trim")
	var c := _r("chest")
	_bare_trunk(torso, 0.34)
	var open := func(p: Vector3) -> float:
		return lerpf(0.09, 0.19 * c, clampf(p.y / 0.5, 0.0, 1.0))
	var paint := func(p: Vector3) -> Color:
		if p.z < 0.0 and absf(p.x) < open.call(p) + _line:
			return trim
		if p.y > 0.36 and absf(p.x) > _hx(p.y) + _lift - _line:
			return trim
		return robe
	_trunk_shell(torso, paint, func(p: Vector3) -> bool:
		return p.y > 0.04 and not (p.z < 0.0 and absf(p.x) < open.call(p)))
	var front := -_hz(0.0) - 2.0 * _lift
	var sash := func(p: Vector3) -> Color:
		return _p("sash_stripe") if p.y > 0.005 and p.y < 0.005 + _v else _p("sash")
	_fill(torso, Vector3(-0.45, -0.06, -0.3), Vector3(0.45, 0.07, 0.3), sash, func(p: Vector3) -> bool:
		return p.y <= 0.05 and _in_trunk(p, _lift * 2.0))
	_block(torso, Vector3(-0.05, -0.05, front - 0.05), Vector3(0.05, 0.06, front), _p("sash"))
	for side in [-1.0, 1.0]:
		_side_block(torso, side, 0.01, 0.055, -0.22 + (0.05 if side > 0 else 0.0), -0.04, front - _v, front, _p("sash"))
	var w := _r("waist")
	_block(hips, Vector3(-0.2 * w, -0.11, -0.13 * w), Vector3(0.2 * w, 0.12, 0.14 * w), robe)


## Wide dark hakama to the knee, a white hem; bare shins; black boots bound
## with white straps.
func _catalyst_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var t := _r("thigh")
	var k := _r("calf")
	var hakama := func(p: Vector3) -> Color:
		return _p("trim") if p.y < -0.42 + _v else _p("robe")
	_taper(hip, -0.42, 0.04, Vector2(0.125, 0.13) * t, Vector2(0.115, 0.12) * t, hakama, 0.04)
	_block(knee, Vector3(-0.055 * k, -0.06, -0.055 * k), Vector3(0.055 * k, 0.03, 0.05 * k), _skin, 0.03)
	_taper(knee, -0.24, 0.0, Vector2(0.05, 0.052) * k, Vector2(0.058, 0.06) * k, _skin, 0.025)
	var top := -0.22
	var boot := func(p: Vector3) -> Color:
		return _p("straps") if posmod(floori(p.y / _v), 3) == 0 else _p("shoes")
	_shoe_on(knee, side, _p("shoes"), _p("sole"), _p("shoes"), _p("straps"), _p("straps"), top, boot)


## Big arms; the robe's short sleeve over the shoulder; white wraps up the
## forearm with a key pattern in his ink (fire orange left, violet right).
func _catalyst_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var skin := _skin
	var ink := _p("ink_left") if side < 0 else _p("ink_right")
	var wraps := func(p: Vector3) -> Color:
		if p.y > WRIST + 0.17:
			return skin
		var row := posmod(floori((p.y - WRIST) / _v), 4)
		var col := floori((p.x + p.z) / _v)
		if row == 1 or (row == 2 and posmod(col, 2) == 0):
			return ink
		return _p("tape_a") if row != 3 else _p("tape_b")
	_arm_shape(shoulder, elbow, side, wraps, _p("robe"), _p("trim"))
	_fist(elbow, side, _p("hand_tape"), _p("tape_b"))


## Bushy white brows, a big nose, a moustache over the beard.
func _catalyst_face(head: Node3D) -> void:
	var skin := _skin
	var white := _color("hair")
	_px(head, 1, 5, 2, 5, Color(0.96, 0.95, 0.93))
	_px(head, 1, 5, 1, 5, Color(0.06, 0.05, 0.06))
	_px(head, 1, 6, 3, 6, white, 1)
	_px(head, 0, 4, 0, 4, skin, 1)
	_px(head, 0, 3, 2, 3, white, 1)
	# The beard, from the cheeks to a broad point on the chest.
	_fill(head, Vector3(-0.25, -0.22, -0.22), Vector3(0.25, 0.14, 0.1), white, func(p: Vector3) -> bool: return _in_beard(p))


## Long white hair swept back off a high brow: a mass over the crown that
## climbs toward the back, swept sides leaving the temples, and the back
## falling in layers past the shoulders.
func _catalyst_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var w := fw + 0.035
	_crown_at = 0.53
	_crown_half = w
	var top := _zone(head, "top")
	_lock(top, Vector3(-w, 0.32, -0.15), Vector3(w, 0.44, 0.2), hair, 0.03)
	_lock(top, Vector3(-w + 0.02, 0.4, -0.06), Vector3(w - 0.02, 0.5, 0.22), hair, 0.02)
	for x: float in [-0.1, 0.0, 0.1]:
		_lock(top, Vector3(x - 0.04, 0.44, 0.04), Vector3(x + 0.04, 0.53, 0.24), hair)
	var sides := _zone(head, "sides")
	for side in [-1.0, 1.0]:
		_side_lock(sides, side, fw - 0.02, w + 0.02, 0.2, 0.42, -0.04, 0.22, hair, 0.02)
	var back := _zone(head, "back")
	# Layers falling down the back, each a little wider and further back.
	var layers := [[0.22, 0.42, w, 0.24], [0.06, 0.26, w + 0.02, 0.27], [-0.1, 0.1, w + 0.04, 0.29], [-0.24, -0.06, w, 0.29]]
	for l: Array in layers:
		_lock(back, Vector3(-l[2], l[0], 0.08), Vector3(l[2], l[1], l[3]), hair, 0.02)


# --- Tony ----------------------------------------------------------------------------

## The track jacket half zipped over a white tee, white trim down the V and
## the stand-up collar, a ribbed hem, pocket flaps, the gold chain. In the
## Plumber Overalls (the palette's "shirt" has alpha): a red flannel shirt
## under denim bib overalls on two straps, brass rivets.
func _tony_torso(hips: Node3D, torso: Node3D) -> void:
	var jacket := _p("jacket")
	var white := _p("zip")
	var neck := 0.066 * _r("neck")
	if _p("shirt").a > 0.0:
		var flannel := func(p: Vector3) -> Color: return _flannel_cell(p)
		_fill(torso, Vector3(-0.4, -0.05, -0.25), Vector3(0.4, 0.63, 0.25), flannel, func(p: Vector3) -> bool:
			return _in_trunk(p) and _neck_clear(p))
		var denim := func(p: Vector3) -> bool:
			if p.y < 0.28:
				return true
			if p.z < 0.0 and p.y < 0.46 and absf(p.x) < 0.12:
				return true
			return p.y < 0.62 and absf(absf(p.x) - 0.09) < _v * 0.75
		_trunk_shell(torso, func(p: Vector3) -> Color: return jacket, denim)
		var front := -_hz(0.44) - 2.0 * _lift
		for side in [-1.0, 1.0]:
			_side_block(torso, side, 0.07, 0.11, 0.42, 0.46, front - 0.01, front + _v, _p("zip"))
		_block(hips, Vector3(-0.2, -0.11, -0.13), Vector3(0.2, 0.12, 0.14), jacket)
		return
	_fill(torso, Vector3(-0.4, -0.05, -0.25), Vector3(0.4, 0.63, 0.25), _p("tee"), func(p: Vector3) -> bool:
		return _in_trunk(p) and _neck_clear(p))
	var vee := func(p: Vector3) -> float:
		return (p.y - 0.34) * 0.5
	var paint := func(p: Vector3) -> Color:
		if p.z < 0.0 and p.y > 0.32 and absf(p.x) < vee.call(p) + _line:
			return white
		if p.y < 0.0 + _v:
			return _p("rib_a")
		return jacket
	_trunk_shell(torso, paint, func(p: Vector3) -> bool:
		return not (p.z < 0.0 and p.y > 0.34 and absf(p.x) < vee.call(p)))
	# The collar standing up round the neck, its front edge white.
	var collar := func(p: Vector3) -> Color:
		return white if p.y > 0.68 - _v else jacket
	_fill(torso, Vector3(-0.22, 0.5, -0.22), Vector3(0.22, 0.7, 0.22), collar, func(p: Vector3) -> bool:
		var r := Vector2(p.x, p.z - 0.015).length()
		return p.y > 0.55 and p.y < 0.68 and r > neck + 0.035 and r < neck + 0.035 + 2.0 * _v and p.z > -0.04 and _off_head(p))
	var front := -_hz(0.12) - 2.0 * _lift
	for side in [-1.0, 1.0]:
		_side_block(torso, side, 0.06, 0.15, 0.1, 0.12 + _v, front, front + _v, jacket.lightened(0.06))
	# The gold chain: links down the V.
	var gold := Color(1.0, 0.78, 0.22)
	for i in 7:
		var a := -0.9 + i * 0.3
		var at := Vector3(sin(a) * 0.08, 0.58 - cos(a) * 0.09, -_hz(0.5) - _lift)
		_block(torso, at - Vector3.ONE * _v * 0.5, at + Vector3.ONE * _v * 0.5, gold)
	_block(hips, Vector3(-0.2, -0.11, -0.13), Vector3(0.2, 0.12, 0.14), jacket)


## Red flannel: dark lines every third cube, down and across.
func _flannel_cell(p: Vector3) -> Color:
	var shirt := _p("shirt")
	shirt.a = 1.0
	var across := posmod(floori(p.y / _v), 3) == 0
	var down := posmod(floori((p.x + p.z) / _v), 3) == 0
	return shirt.darkened(0.55 if across and down else (0.3 if across or down else 0.0))


## Loose track pants, two white stripes down the outside, gathered at the
## ankle; black sneakers. Overalls: denim, brown work boots.
func _tony_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var jacket := _p("jacket")
	var plumber := _p("shirt").a > 0.0
	var stripes := func(p: Vector3) -> Color:
		if not plumber and p.x * side >= 0.06 and posmod(floori(p.z / _v), 2) == 0 and absf(p.z) < 0.08:
			return _p("stripe")
		return jacket
	_taper(hip, -0.44, 0.04, Vector2(0.108, 0.112), Vector2(0.112, 0.116), stripes, 0.04)
	_taper(knee, -0.27, 0.03, Vector2(0.09, 0.094), Vector2(0.104, 0.108), stripes, 0.035)
	_taper(knee, -0.33, -0.27, Vector2(0.07, 0.074), Vector2(0.074, 0.078), _p("rib_b") if not plumber else jacket, 0.02)
	_shoe_on(knee, side, _p("shoes"), _p("sole"), _p("shoes"), _p("accent"), _p("accent"), -0.33)


## Puffy jacket sleeves to the wrist, two white stripes down the outside,
## ribbed cuffs; taped fists (fingers bare). Overalls: flannel sleeves.
func _tony_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var a := _r("arm")
	var f := _r("forearm")
	var plumber := _p("shirt").a > 0.0
	_arm_shape(shoulder, elbow, side, func(p: Vector3) -> Color: return _skin)
	var sleeve := func(p: Vector3) -> Color:
		if plumber:
			return _flannel_cell(p)
		if p.x * side >= 0.04 and posmod(floori(p.z / _v), 2) == 0 and absf(p.z) < 0.07:
			return _p("stripe")
		return _p("jacket")
	var center := Vector3(0.012 * side, -0.035, 0)
	var half := Vector3(0.095, 0.09, 0.09) * a + Vector3.ONE * _lift
	_block(shoulder, center - half, center + half, sleeve, 0.045)
	_taper(shoulder, -0.3, -0.04, Vector2(0.075, 0.075) * a + Vector2.ONE * _lift, Vector2(0.085, 0.083) * a + Vector2.ONE * _lift, sleeve, 0.03)
	_taper(elbow, WRIST + 0.06, 0.05, Vector2(0.06, 0.058) * f + Vector2.ONE * _lift, Vector2(0.07, 0.068) * f + Vector2.ONE * _lift, sleeve, 0.03)
	_taper(elbow, WRIST + 0.03, WRIST + 0.06, Vector2(0.06, 0.058) * f + Vector2.ONE * _lift * 0.5, Vector2(0.06, 0.058) * f + Vector2.ONE * _lift * 0.5, _p("rib_a") if not plumber else _p("rib_b"))
	_fist(elbow, side, _p("tape"), null, _skin)


## Heavy brows, a red nose, a smirk up one side, stubble.
func _tony_face(head: Node3D) -> void:
	var skin := _skin
	var dark := Color(0.06, 0.05, 0.06)
	var stubble := skin.lerp(Color(0.45, 0.43, 0.45), 0.5)
	_px(head, 0, 0, 3, 3, stubble)
	_px(head, 1, 5, 2, 5, Color(0.96, 0.95, 0.93))
	_px(head, 1, 5, 1, 5, dark)
	_px(head, 1, 6, 3, 6, dark, 1)
	_px(head, 0, 4, 0, 4, Color(0.86, 0.48, 0.42), 1)
	_px(head, 0, 2, 0, 2, skin.darkened(0.4))
	_px(head, -2, 3, -2, 3, skin.darkened(0.4), 0, false)


## Short dark hair at the sides and back under a knit beanie (ribbed, a
## folded brim); under a cap or crown the beanie comes off for a close crop.
func _tony_hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var c := fw + _v * 1.1
	_short_under_hats = true
	_crown_at = 0.52
	_crown_half = fw + 0.03
	var beanie := _zone(head, "top")
	var knit := func(p: Vector3) -> Color:
		if p.y < 0.31:
			return _p("brim")
		return _p("beanie_a") if posmod(floori(p.x / _v) + floori(p.z / _v), 2) == 0 else _p("beanie_b")
	_lock(beanie, Vector3(-fw - _v, 0.25, -0.15 - _v), Vector3(fw + _v, 0.44, 0.155 + _v), Color.WHITE, 0.05)
	_fill(beanie, Vector3(-0.3, 0.2, -0.3), Vector3(0.3, 0.5, 0.3), knit, func(p: Vector3) -> bool: return true, true)
	var sides := _zone(head, "sides")
	for side in [-1.0, 1.0]:
		_side_lock(sides, side, fw - 0.02, c, 0.18, 0.3, -0.07, 0.13, hair)
	_lock(_zone(head, "back"), Vector3(-c, 0.12, 0.06), Vector3(c, 0.3, 0.155 + _v * 1.1), hair)
	var short := _zone(head, "short")
	_lock(short, Vector3(-c, 0.28, -0.15), Vector3(c, 0.38, 0.155 + _v * 1.1), hair, 0.02)
