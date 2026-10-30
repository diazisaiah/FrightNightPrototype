extends PlayerBody
## Body revamp prototype (2026-10-29, playground only): the Answer rebuilt
## clean at two voxel scales, to pick the direction for every fighter. It is
## the production PlayerBody with a new sculpture and paint: the same pivots
## (hips, torso, head, shoulders, elbows, hips, knees), poses, emotes, skins
## and hats. Other fighters fall back to the production body.
##
## The rules it tries out, for all six bodies later:
## - No per-voxel jitter, mottling, crease speckle or random wear. Every cell
##   is a base, shadow or highlight color placed on purpose.
## - Detail is sized in lines (trim, piping, wrap bands): two voxels on the
##   tiny scale, one on the medium and large, so all read as the same design.
##   Medium and large share the simplified design; the face, fringe and hair
##   clumps are drawn for each grid.
## - Overlays (belt, wraps, cuffs, hood trim) stand proud by a whole voxel.
## - Hair is built in named zones (top, front, sides, back), and a hat's fit
##   profile says where it sits and which zones it hides.

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
	# Helmets and masks over the whole head.
	"mask": {"seat": 0.3, "size": 0.87, "hide": ["top", "front", "sides", "back"]},
	# Wigs and bald caps replace the hair.
	"wig": {"seat": 0.33, "size": 0.87, "hide": ["top", "front", "sides", "back"]},
}
const HAT_KIND := {
	"paper_crown": "crown", "coffin_crown": "crown", "frost_tiara": "crown", "quake_headband": "crown",
	"storm_ears": "crown", "party_hat": "crown",
	"iron_mask": "mask", "doom_mask": "mask", "monkey_mask": "mask", "speed_mask": "mask", "reaper_hood": "mask",
	"wig_black": "wig", "wig_blonde": "wig", "wig_blue": "wig", "wig_white": "wig", "fast_quills": "wig",
	"golden_quills": "wig", "gale_flattop": "wig", "blood_hairline": "wig", "bald_cap": "wig",
}

## "tiny", "medium" or "large"; set before the body enters the tree.
var voxel_scale := "tiny"
var _v := VOXEL
var _line := 0.032
var _lift := 0.016
var _revamp := false
## Hair zones by name: top, front, sides, back.
var _zones := {}
static var _cubes := {}


static func hat_kind(id: String) -> String:
	if HAT_KIND.has(id):
		return HAT_KIND[id]
	return "wig" if Hats.info(id).get("bald", false) else "cap"


static func scale_name(id: String) -> String:
	return SCALES.get(id, SCALES.tiny).name


## The head's measurements a hat fits to (head pivot space).
func head_profile() -> Dictionary:
	var fw := 0.15 * _b("face")
	return {"skull_top": 0.345, "hair_top": 0.48, "brow": 0.25, "half_width": fw, "hair_half_width": fw + 0.03, "front": -0.15}


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
	for zone in _zones:
		(_zones[zone] as Node3D).visible = bare or not zone in fit.hide
	if bare:
		return
	var u: float = head_profile().hair_half_width * 2.0 * fit.size * (Hats.FRUIT_SIZE if id == "fruit_hat" else 1.0)
	_hat = Node3D.new()
	_hat.name = "HatSocket"
	_hat.position = Vector3(0, fit.seat, 0)
	_hat.add_child(Hats.build(id, u))
	_joints.head.add_child(_hat)
	_set_layer(_hat)
	var spin := _hat.get_node_or_null("Hat/Spin")
	if spin:
		spin.create_tween().set_loops().tween_property(spin, "rotation:y", TAU, 0.6).from(0.0)
	if Hats.info(id).rarity == "legendary":
		Hats.sparkles(_hat, Hats.color(id), 0.25)


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	var s: Dictionary = SCALES.get(voxel_scale, SCALES.tiny)
	_revamp = fighter == "counter_master"
	if not _revamp:
		super._build()
		return
	_v = s.voxel
	_line = s.line
	_lift = s.lift
	var b := _bulk()
	var hips := _pivot("hips", self, Vector3(0, _hip_height(), 0))
	var torso := _pivot("torso", hips, Vector3(0, 0.1, 0))
	_answer_torso(hips, torso)
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var hip := _pivot(key + "h", hips, Vector3(0.1 * b * side, 0.0, 0))
		var knee := _pivot(key + "k", hip, Vector3(0, -0.44, 0))
		_answer_leg(hip, knee, side)
	var head := _pivot("head", torso, Vector3(0, 0.57, 0))
	_answer_head(head)
	_answer_face(head)
	_answer_hair(head)
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var shoulder := _pivot(key + "s", torso, Vector3((0.22 * b + 0.07) * side, 0.49, 0))
		var elbow := _pivot(key + "e", shoulder, Vector3(0, -0.29, 0))
		_answer_arm(shoulder, elbow, side)
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
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _cubes[_v]
	multimesh.instance_count = cells.size()
	for k in cells.size():
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, (Vector3(cells[k]) + Vector3(0.5, 0.5, 0.5)) * _v))
		multimesh.set_instance_color(k, grid[cells[k]])
	_attach(node, multimesh)
	_baked.append([get_path_to(node), multimesh])
	_grids.erase(node)
	return true


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
func _hx(y: float) -> float:
	if y < 0.26:
		return lerpf(0.17, 0.235, clampf((y + 0.04) / 0.3, 0.0, 1.0))
	if y < 0.5:
		return lerpf(0.235, 0.268, (y - 0.26) / 0.24)
	return lerpf(0.268, 0.19, clampf((y - 0.5) / 0.12, 0.0, 1.0))


func _hz(y: float) -> float:
	if y < 0.26:
		return lerpf(0.115, 0.135, clampf((y + 0.04) / 0.3, 0.0, 1.0))
	if y < 0.5:
		return lerpf(0.135, 0.148, (y - 0.26) / 0.24)
	return lerpf(0.148, 0.12, clampf((y - 0.5) / 0.12, 0.0, 1.0))


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
	# (Open round the neck and under the chin, so no two parts ever overlap
	# there: on the large scale that showed as speckle.)
	_fill(torso, Vector3(-0.3, -0.05, -0.2), Vector3(0.3, 0.63, 0.2), hoodie, func(p: Vector3) -> bool:
		if p.y > 0.5 and Vector2(p.x, p.z - 0.015).length() < 0.1:
			return false
		return _in_trunk(p) and not (p.y > 0.55 and p.z < 0.0 and absf(p.x) < 0.11))
	# The chest plane standing out from the ribs.
	_block(torso, Vector3(-0.2, 0.34, -_hz(0.42) - _lift), Vector3(0.2, 0.5, -0.05), hoodie, 0.02)
	# The hood down round the neck: open at the front, bunched behind, its
	# edge trimmed white.
	var hood := func(p: Vector3) -> Color:
		return white if p.y > _hood_top(p.z) - _line and p.z > -0.02 else cloth
	_fill(torso, Vector3(-0.24, 0.48, -0.12), Vector3(0.24, 0.76, 0.26), hood, func(p: Vector3) -> bool:
		var r := Vector2(p.x, p.z - 0.04).length()
		return p.y > 0.5 and p.y < _hood_top(p.z) and r > 0.11 and r < 0.2 and p.z > -0.03)
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

func _answer_head(head: Node3D) -> void:
	var skin := _skin
	var fw := 0.15 * _b("face")
	# A short thick neck (in shadow under the jaw), a square skull, a square
	# jaw narrowing a little to the chin, flat ears.
	_taper(head, -0.07, 0.13, Vector2(0.066, 0.062), Vector2(0.06, 0.056), _sh(skin), 0.02, Vector3(0, 0, 0.015))
	_block(head, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), skin, 0.03)
	_fill(head, Vector3(-fw, 0.015, -0.15), Vector3(fw, 0.17, 0.12), skin, func(p: Vector3) -> bool:
		var t := clampf((p.y - 0.015) / 0.155, 0.0, 1.0)
		var half := lerpf(0.085, fw, smoothstep(0.0, 0.6, t))
		return absf(p.x) <= half and p.z >= -0.15 and p.z <= lerpf(0.02, 0.12, t))
	for side in [-1.0, 1.0]:
		_side_block(head, side, fw - 0.01, fw + 0.022, 0.15, 0.235, -0.02, 0.045, skin, 0.01)


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
	return node


## Inside the skull or jaw (head pivot space).
func _in_skull(p: Vector3) -> bool:
	var fw := 0.15 * _b("face")
	if _in_rounded(p, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), 0.03):
		return true
	var t := clampf((p.y - 0.015) / 0.155, 0.0, 1.0)
	return p.y >= 0.015 and p.y <= 0.17 and absf(p.x) <= lerpf(0.085, fw, smoothstep(0.0, 0.6, t)) and p.z >= -0.15 and p.z <= lerpf(0.02, 0.12, t)


## A block of hair that leaves the skull's own cells alone: hair and skull
## share the head's grid, and a hair cube on a skin cube flickers.
func _lock(node: Node3D, from: Vector3, to: Vector3, color: Color, r := 0.0) -> void:
	var lo := from.min(to)
	var hi := from.max(to)
	_fill(node, lo, hi, color, func(p: Vector3) -> bool:
		return _in_rounded(p, lo, hi, r) and not _in_skull(p))


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
