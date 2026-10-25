class_name PlayerBody
extends Node3D
## The player's own fighter, head to toe: seen only when the camera pulls out
## to third person for an emote (Emotes). Sculpted in small voxels after each
## fighter's voxel model (art/fighter_*_voxel_model.png): the Mauler's open
## vest, red sash and gloves; the Answer's hoodie, white belt and lightning
## pants; the Blur's curls, crop top and balloon pants; the Stray's locs,
## headband and torn gi; Tony's tracksuit; the Catalyst's beard and robe.
## Wears the hat picked on the Hat Rack (GameState.worn_hat).
## Also dances on the Emotes stage in Cosmetics.
## Joints are pivots (see Emotes for which way they turn). Faces -Z.

## Hair, eyes (their glow, or black for plain brown ones) and bulk (width
## scale, which spaces the joints). The outfit's colors are the fighter's
## palette (Skins), which a skin can change.
const LOOKS := {
	"berserker": {"hair": Color(0.1, 0.08, 0.08), "eyes": Color(1.0, 0.45, 0.1), "bulk": 1.18},
	"combo_master": {"hair": Color(0.14, 0.12, 0.2), "eyes": Color(0.7, 0.45, 1.0), "bulk": 1.08},
	"counter_master": {"hair": Color(0.05, 0.05, 0.06), "eyes": Color(0.45, 0.85, 1.0), "bulk": 1.12},
	"free_runner": {"hair": Color(0.24, 0.16, 0.12), "eyes": Color(0.35, 1.0, 0.45), "bulk": 1.1},
	"wise_guy": {"hair": Color(0.07, 0.07, 0.08), "eyes": Color.BLACK, "bulk": 1.08},
	"elementalist": {"hair": Color(0.93, 0.93, 0.91), "eyes": Color.BLACK, "bulk": 1.15},
}
const HEAD := 0.3
## The body renders on its own layer: the lantern at your eyes would blow it
## out from inside the head, so a soft fill on the emote camera lights it.
const LAYER := 1 << 9
## Eases between poses as a dance starts and stops.
const BLEND_TIME := 0.18

var fighter := ""
## The skin (Skins) to wear: "auto" for the fighter's pick, "" for their own look.
var skin_id := "auto"
var _look := {}
var _pal := {}
var _skin := Color()
var _joints := {}
var _hat: Node3D
## Hats sit at this height on the head (just over the skull). Hair above it
## is built on its own part, hidden while a hat's on, so the hat sits down
## in the hair instead of floating on top of it.
const HAT_SEAT := 0.37
var _hair_top: Node3D
var _beanie: Node3D

var _keys: Array = []
var _key := 0
var _key_time := 0.0
var _from := {}
## The pose as the dance sets it (legs get _plant_feet on top).
var _values := {}
const LEGS := ["lh", "lk", "rh", "rk"]
const LEG_LENGTH := 0.89
var _playing := ""
## The current key's length when it isn't its own (easing into a dance).
var _blend := -1.0


func _init(class_id := "", skin := "auto") -> void:
	fighter = class_id
	skin_id = skin


func _ready() -> void:
	if fighter == "":
		fighter = GameState.player_class
	_look = LOOKS.get(fighter, LOOKS.counter_master)
	if skin_id == "auto":
		skin_id = GameState.skin(fighter)
	_pal = Skins.palette(fighter, skin_id)
	_skin = Fists.SKIN.get(fighter, Fists.DEFAULT_SKIN)
	scale = Vector3.ONE * 0.92
	_build()
	if _cache.has(_cache_key()):
		_ops.clear()
		for part in _cache[_cache_key()]:
			_attach(get_node(part[0]), part[1])
	else:
		get_tree().process_frame.connect(_build_step)
	wear_hat(GameState.worn_hat)
	_apply({})
	set_process(false)


## Starts a dance (an Emotes id), easing in from wherever the body is.
func play(id: String) -> void:
	_playing = id
	_keys = Emotes.keys(id)
	_key = -1
	_next_key(BLEND_TIME)
	set_process(true)


## Back to standing.
func stop() -> void:
	_playing = ""
	_keys = [[BLEND_TIME, {}]]
	_key = -1
	_next_key(BLEND_TIME)


func playing() -> String:
	return _playing


func _process(delta: float) -> void:
	_key_time += delta
	var length: float = _blend if _blend > 0.0 else _keys[_key][0]
	var t := clampf(_key_time / maxf(length, 0.001), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var target: Dictionary = _keys[_key][1]
	for joint in _from:
		var to: Vector3 = target.get(joint, Emotes.REST.get(joint, Vector3.ZERO))
		_set_joint(joint, (_from[joint] as Vector3).lerp(to, t))
	_plant_feet()
	if _key_time >= length:
		if _playing == "" and _key >= _keys.size() - 1:
			set_process(false)
			return
		_next_key()


func _next_key(first_length := -1.0) -> void:
	_from = {}
	for joint in Emotes.JOINTS + ["pos"]:
		_from[joint] = _get_joint(joint)
	_key = (_key + 1) % _keys.size()
	_key_time = 0.0
	_blend = first_length


## Snaps straight to a pose.
func _apply(pose: Dictionary) -> void:
	for joint in Emotes.JOINTS + ["pos"]:
		_set_joint(joint, pose.get(joint, Emotes.REST.get(joint, Vector3.ZERO)))
	_plant_feet()


func _set_joint(joint: String, value: Vector3) -> void:
	_values[joint] = value
	if joint == "pos":
		_joints.hips.position = Vector3(0, _hip_height(), 0) + value
	elif _joints.has(joint) and not joint in LEGS:
		_joints[joint].rotation = value


func _get_joint(joint: String) -> Vector3:
	return _values.get(joint, Vector3.ZERO)


## Keeps the feet on the canvas: when the hips drop, the knees bend; when
## they sway sideways, the legs lean to stay planted. Poses only say where
## the hips go (and any kick on top).
func _plant_feet() -> void:
	var pos: Vector3 = _values.get("pos", Vector3.ZERO)
	var bend := acos(clampf(1.0 - maxf(-pos.y, 0.0) / LEG_LENGTH, -1.0, 1.0))
	var lean := -asin(clampf(pos.x / LEG_LENGTH, -1.0, 1.0))
	for side in ["l", "r"]:
		_joints[side + "h"].rotation = _values.get(side + "h", Vector3.ZERO) + Vector3(bend, 0, lean)
		_joints[side + "k"].rotation = _values.get(side + "k", Vector3.ZERO) + Vector3(-2.0 * bend, 0, 0)


func _hip_height() -> float:
	return 0.9


# --- The hat ------------------------------------------------------------------------

## Puts on a hat from the collection ("" for none).
func wear_hat(id: String) -> void:
	if _hat and is_instance_valid(_hat):
		_hat.queue_free()
	_hat = null
	var bare := id == "" or not Hats.CATALOG.has(id)
	if _beanie:
		_beanie.visible = bare
	if _hair_top:
		_hair_top.visible = bare
	if bare:
		return
	var u := HEAD * _bulk() * Hats.SIZE * (Hats.FRUIT_SIZE if id == "fruit_hat" else 1.0)
	_hat = Hats.build(id, u)
	_hat.position = Vector3(0, HAT_SEAT, 0)
	_joints.head.add_child(_hat)
	_set_layer(_hat)
	var spin := _hat.get_node_or_null("Spin")
	if spin:
		spin.create_tween().set_loops().tween_property(spin, "rotation:y", TAU, 0.6).from(0.0)
	if Hats.info(id).rarity == "legendary":
		Hats.sparkles(_hat, Hats.color(id), 0.25)


# --- Building -----------------------------------------------------------------------

## Bodies are sculpted in voxels at this grain from rounded parts: a skull,
## a jaw and cheekbones; muscles; cloth with folds, ragged hems, knots and
## tails; hair in curls, locs or spikes. Each part's cells are painted, then
## baked to small cubes in flat vertex colors, darker in the creases and
## lighter on the edges. The painting is spread over frames (build_budget_ms
## a frame) and kept per fighter for the session.
const VOXEL := 0.016
## Each fighter's build (scales): chest, waist, arm, forearm, thigh, calf,
## neck; jaw (1 square, 0 pointed) and face (the head's width).
const BUILDS := {
	"berserker": {"chest": 1.3, "waist": 1.12, "arm": 1.62, "forearm": 1.62, "thigh": 1.35, "calf": 1.4, "neck": 1.7, "jaw": 1.0, "face": 1.0},
	"counter_master": {"chest": 1.08, "waist": 0.92, "arm": 1.22, "forearm": 1.2, "thigh": 1.05, "calf": 1.05, "neck": 1.05, "jaw": 0.5, "face": 0.95},
	"combo_master": {"chest": 0.98, "waist": 0.84, "arm": 1.1, "forearm": 1.1, "thigh": 0.95, "calf": 0.95, "neck": 0.95, "jaw": 0.3, "face": 0.92},
	"free_runner": {"chest": 1.03, "waist": 0.88, "arm": 1.18, "forearm": 1.15, "thigh": 1.0, "calf": 1.05, "neck": 1.0, "jaw": 0.45, "face": 0.95},
	"wise_guy": {"chest": 1.05, "waist": 1.02, "arm": 1.1, "forearm": 1.08, "thigh": 1.0, "calf": 1.0, "neck": 1.15, "jaw": 0.85, "face": 1.0},
	"elementalist": {"chest": 1.22, "waist": 1.0, "arm": 1.42, "forearm": 1.42, "thigh": 1.1, "calf": 1.1, "neck": 1.35, "jaw": 0.75, "face": 1.0},
}
const SIDES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const GOLDEN := 2.39996
## Baked parts per fighter: [[path from the body, MultiMesh], ...].
static var _cache := {}
static var _cube: BoxMesh
static var _near: Array = []
## Milliseconds of painting a frame while the body builds.
var build_budget_ms := 6
var _grids := {}
var _parts: Array = []
var _ops: Array = []
var _op := 0
var _baked: Array = []


func _bulk() -> float:
	return float(_look.get("bulk", 1.0))


func _b(key: String) -> float:
	return float(BUILDS.get(fighter, BUILDS.counter_master).get(key, 1.0))


func _color(key: String) -> Color:
	var value = _look.get(key, Color.WHITE)
	return _skin if value is String else value


## A part's color in this fighter's palette (Skins).
func _p(key: String) -> Color:
	return _pal.get(key, Color.MAGENTA)


func _cache_key() -> String:
	return fighter + "/" + skin_id


func _build() -> void:
	var b := _bulk()
	var hips := _pivot("hips", self, Vector3(0, _hip_height(), 0))
	var torso := _pivot("torso", hips, Vector3(0, 0.1, 0))
	_trunk(hips, torso)
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var hip := _pivot(key + "h", hips, Vector3(0.1 * b * side, 0.0, 0))
		var knee := _pivot(key + "k", hip, Vector3(0, -0.44, 0))
		_leg(hip, knee, side)
	_dress_torso(hips, torso)
	var head := _pivot("head", torso, Vector3(0, 0.57, 0))
	_head(head)
	_face(head)
	var hair_from := _ops.size()
	_hair(head)
	_split_hair(head, hair_from)
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var shoulder := _pivot(key + "s", torso, Vector3((0.22 * b + 0.07) * side, 0.49, 0))
		var elbow := _pivot(key + "e", shoulder, Vector3(0, -0.29, 0))
		_arm(shoulder, elbow, side)
	for node in _parts:
		_ops.append(["bake", node, {}])


## Moves the hair above HAT_SEAT (painted by the ops from index from on) to
## its own part, so a hat can hide it.
func _split_hair(head: Node3D, from: int) -> void:
	_hair_top = Node3D.new()
	_hair_top.name = "HairTop"
	head.add_child(_hair_top)
	_grids[_hair_top] = {}
	_parts.append(_hair_top)
	var ops := _ops.slice(0, from)
	for op in _ops.slice(from):
		ops.append(op)
		if op[0] != "fill" or op[1] != head:
			continue
		var inside: Callable = op[5]
		var top: Array = op.duplicate()
		op[5] = func(p: Vector3) -> bool: return p.y < HAT_SEAT and inside.call(p)
		top[1] = _hair_top
		top[5] = func(p: Vector3) -> bool: return p.y >= HAT_SEAT and inside.call(p)
		ops.append(top)
	_ops = ops


## Paints a little more each frame; bakes each part once it's painted.
func _build_step() -> void:
	var start := Time.get_ticks_msec()
	while _op < _ops.size():
		var op: Array = _ops[_op]
		var done := true
		match op[0]:
			"fill":
				done = _run_fill(op, start)
			"px":
				_run_px(op)
			"bake":
				done = _run_bake(op, start)
		if not done:
			return
		_op += 1
		if Time.get_ticks_msec() - start >= build_budget_ms:
			return
	get_tree().process_frame.disconnect(_build_step)
	_cache[_cache_key()] = _baked
	_ops.clear()
	_grids.clear()


## Turns a part's painted cells into cubes (only those with an open side):
## darker where the cells around close in (creases), lighter where they fall
## away (edges), lit a little on top and shaded underneath.
func _run_bake(op: Array, start: int) -> bool:
	var node: Node3D = op[1]
	var state: Dictionary = op[2]
	var grid: Dictionary = _grids[node]
	if state.is_empty():
		state.keys = grid.keys()
		state.i = 0
		state.cells = []
		state.colors = []
		if _near.is_empty():
			for x in [-2, 0, 2]:
				for y in [-2, 0, 2]:
					for z in [-2, 0, 2]:
						if x != 0 or y != 0 or z != 0:
							_near.append(Vector3i(x, y, z))
	var keys: Array = state.keys
	var cells: Array = state.cells
	var colors: Array = state.colors
	var i: int = state.i
	while i < keys.size():
		var cell: Vector3i = keys[i]
		i += 1
		var open := false
		for n in SIDES:
			if not grid.has(cell + n):
				open = true
				break
		if not open:
			continue
		var filled := 0
		for n in _near:
			if grid.has(cell + n):
				filled += 1
		var color: Color = grid[cell]
		var crease := clampf((filled - 17) / 8.0, -1.0, 1.0)
		color = color.darkened(0.32 * crease) if crease > 0.0 else color.lightened(-0.12 * crease)
		if not grid.has(cell + Vector3i(0, 1, 0)):
			color = color.lightened(0.04)
		elif not grid.has(cell + Vector3i(0, -1, 0)):
			color = color.darkened(0.12)
		cells.append(cell)
		colors.append(color)
		if cells.size() % 256 == 0 and Time.get_ticks_msec() - start >= build_budget_ms:
			state.i = i
			return false
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE * VOXEL * 1.01
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.85
		_cube.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _cube
	multimesh.instance_count = cells.size()
	for k in cells.size():
		multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY, (Vector3(cells[k]) + Vector3(0.5, 0.5, 0.5)) * VOXEL))
		multimesh.set_instance_color(k, colors[k])
	_attach(node, multimesh)
	_baked.append([get_path_to(node), multimesh])
	_grids.erase(node)
	return true


func _attach(node: Node3D, multimesh: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.layers = LAYER
	node.add_child(instance)


# --- Shapes -----------------------------------------------------------------------

## Paints the cells in from-to that inside() accepts. color: a Color (with a
## little variation), a Callable(position) -> Color, or null to carve cells
## away. tint_only: only recolors cells already painted.
func _fill(node: Node3D, from: Vector3, to: Vector3, color: Variant, inside: Callable, tint_only := false) -> void:
	if not _grids.has(node):
		_grids[node] = {}
		_parts.append(node)
	var lo := Vector3i((from / VOXEL).floor())
	_ops.append(["fill", node, lo, Vector3i((to / VOXEL).ceil()), color, inside, tint_only, lo.x])


func _run_fill(op: Array, start: int) -> bool:
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
				var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL
				if not inside.call(p):
					continue
				if carve:
					grid.erase(cell)
				elif color is Callable:
					grid[cell] = (color as Callable).call(p)
				else:
					grid[cell] = _vary(color, p)
		x += 1
		if Time.get_ticks_msec() - start >= build_budget_ms:
			op[7] = x
			return x >= hi.x
	return true


## A box with its edges rounded by r.
func _block(node: Node3D, from: Vector3, to: Vector3, color: Variant, r := 0.0, rot := Vector3.ZERO) -> void:
	var center := (from + to) * 0.5
	var half := ((to - from) * 0.5).abs().max(Vector3.ONE * VOXEL * 0.5)
	var inverse := Basis.from_euler(rot).inverse()
	var span := half if rot == Vector3.ZERO else Vector3.ONE * half.length()
	_fill(node, center - span, center + span, color, func(p: Vector3) -> bool:
		var local := (inverse * (p - center)).abs()
		if local.x > half.x or local.y > half.y or local.z > half.z:
			return false
		return r <= 0.0 or (local - (half - Vector3.ONE * r)).max(Vector3.ZERO).length() <= r)


func _in_rounded(p: Vector3, from: Vector3, to: Vector3, r: float) -> bool:
	var half := (to - from).abs() * 0.5
	var local := (p - (from + to) * 0.5).abs()
	if local.x > half.x or local.y > half.y or local.z > half.z:
		return false
	return (local - (half - Vector3.ONE * r)).max(Vector3.ZERO).length() <= r


## Tapers along Y from half-sizes h0 (x, z) at y0 to h1 at y1, edges rounded by r.
func _taper(node: Node3D, y0: float, y1: float, h0: Vector2, h1: Vector2, color: Variant, r := 0.0, offset := Vector3.ZERO) -> void:
	var big := h0.max(h1)
	_fill(node, offset + Vector3(-big.x, y0, -big.y), offset + Vector3(big.x, y1, big.y), color, func(p: Vector3) -> bool:
		var t := clampf((p.y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
		var h := h0.lerp(h1, t)
		var local := Vector2(absf(p.x - offset.x), absf(p.z - offset.z))
		if local.x > h.x or local.y > h.y:
			return false
		var corner := (local - (h - Vector2.ONE * r)).max(Vector2.ZERO)
		return r <= 0.0 or corner.length() <= r)


## A tapering spike from base along dir: radius r0 at the base to r1 at the tip.
func _spike(node: Node3D, base: Vector3, dir: Vector3, length: float, r0: float, r1: float, color: Variant) -> void:
	var tip := base + dir.normalized() * length
	var pad := Vector3.ONE * maxf(r0, r1)
	_fill(node, base.min(tip) - pad, base.max(tip) + pad, color, func(p: Vector3) -> bool:
		var t := clampf((p - base).dot(tip - base) / (length * length), 0.0, 1.0)
		return p.distance_to(base.lerp(tip, t)) <= lerpf(r0, r1, t))


func _blob(node: Node3D, center: Vector3, radii: Vector3, color: Variant) -> void:
	_fill(node, center - radii, center + radii, color, func(p: Vector3) -> bool:
		return ((p - center) / radii).length_squared() <= 1.0)


## A limb from a to b (its cross-section an ellipse, radii ra at a to rb at b
## in x and z), swelling by bulge around t = at, its ends rounded. wobble
## ruffles the surface (cloth folds).
func _limb(node: Node3D, a: Vector3, b: Vector3, ra: Vector2, rb: Vector2, color: Variant, bulge := 0.0, at := 0.5, wobble := 0.0) -> void:
	var pad := Vector3.ONE * maxf(maxf(ra.x, ra.y), maxf(rb.x, rb.y)) * (1.0 + absf(bulge) + wobble)
	_fill(node, a.min(b) - pad, a.max(b) + pad, color, func(p: Vector3) -> bool:
		return _in_limb(p, a, b, ra, rb, bulge, at, wobble))


func _in_limb(p: Vector3, a: Vector3, b: Vector3, ra: Vector2, rb: Vector2, bulge := 0.0, at := 0.5, wobble := 0.0) -> bool:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var s := (t - at) / 0.45
	var r := ra.lerp(rb, t) * (1.0 + bulge * maxf(0.0, 1.0 - s * s))
	var q := p - (a + ab * t)
	if wobble > 0.0:
		r *= 1.0 + wobble * sin(p.y * 70.0 + atan2(q.z, q.x) * 3.0)
	var end := minf(r.x, r.y)
	return (q.x * q.x) / (r.x * r.x) + (q.z * q.z) / (r.y * r.y) + (q.y * q.y) / (end * end) <= 1.0


## A strip of cloth from top to bottom, width wide along across (as near as it
## can be), thick through, rippling, its end frayed.
func _ribbon(node: Node3D, top: Vector3, bottom: Vector3, width: float, thick: float, color: Variant, across := Vector3.RIGHT, wave := 0.012) -> void:
	var axis := bottom - top
	var side := (across - axis * across.dot(axis) / axis.length_squared()).normalized()
	var face := side.cross(axis).normalized()
	var pad := Vector3.ONE * (width + thick + wave * 2.0)
	_fill(node, top.min(bottom) - pad, top.max(bottom) + pad, color, func(p: Vector3) -> bool:
		var t := (p - top).dot(axis) / axis.length_squared()
		if t < 0.0 or t > 1.0 or (t > 0.82 and _noise(p) > 0.55):
			return false
		var d := p - (top + axis * t) - face * sin(t * 7.0) * wave
		return absf(d.dot(side)) <= width * 0.5 and absf(d.dot(face)) <= thick * 0.5)


## A stitched X patch on a surface facing -Z.
func _cross(node: Node3D, at: Vector3, size: float, color: Color) -> void:
	for turn in [0.75, -0.75]:
		_block(node, at - Vector3(size, 0.007, 0.01), at + Vector3(size, 0.007, 0.01), color, 0.0, Vector3(0, 0, turn))


## A flat patch on the front surface (-Z) at depth z: recolors the surface.
func _front(node: Node3D, x0: float, y0: float, x1: float, y1: float, z: float, color: Variant, out := 0.0) -> void:
	_block(node, Vector3(x0, y0, z - 0.004 - out), Vector3(x1, y1, z + VOXEL * 1.2), color)


## A plain box (details); kept for the glow path below.
func _paint(node: Node3D, from: Vector3, to: Vector3, color: Variant, rot := Vector3.ZERO) -> void:
	_block(node, from, to, color, 0.0, rot)


## Recolors whole voxels on the front of the face: cols and rows count voxels
## from the middle (col 0 is just right of center), mirrored to the left side
## unless told not to; out stands that many voxels proud.
func _px(head: Node3D, c0: int, r0: int, c1: int, r1: int, color: Color, out := 0, mirror := true) -> void:
	_ops.append(["px", head, c0, r0, c1, r1, color, out, mirror])


func _run_px(op: Array) -> void:
	var grid: Dictionary = _grids[op[1]]
	var color: Color = op[6]
	var out: int = op[7]
	var cols := []
	for c in range(op[2], op[4] + 1):
		cols.append(c)
		if op[8]:
			cols.append(-1 - c)
	for c in cols:
		for r in range(op[3], op[5] + 1):
			for z in range(-16, 2):
				if grid.has(Vector3i(c, r, z)):
					for k in range(z - out, z + 1):
						grid[Vector3i(c, r, k)] = color
					break


func _vary(color: Color, p: Vector3) -> Color:
	var h := absf(sin(p.x * 1271.3 + p.y * 3117.7 + p.z * 1771.1) * 43758.5453)
	h -= floorf(h)
	return color.darkened(h * 0.05) if h > 0.5 else color.lightened((0.5 - h) * 0.05)


## A repeatable 0..1 value for each block of size voxels.
func _noise(p: Vector3, size := 1.0) -> float:
	var q := (p / (VOXEL * size)).floor()
	var h := sin(q.x * 127.1 + q.y * 311.7 + q.z * 74.7) * 43758.5453
	return h - floorf(h)


## Bands around a limb along Y: colors repeat every width.
func _bands(colors: Array, width: float, slant := 0.0) -> Callable:
	return func(p: Vector3) -> Color:
		var i := int(floorf((p.y + p.x * slant) / width)) % colors.size()
		return _vary(colors[i if i >= 0 else i + colors.size()], p)


## Cloth in base, mottled lighter and darker in patches.
func _cloth(base: Color, mottle := 0.07) -> Callable:
	return func(p: Vector3) -> Color: return _cloth_at(p, base, mottle)


func _cloth_at(p: Vector3, base: Color, mottle := 0.07) -> Color:
	var n := _noise(p, 3.0)
	return _vary(base.lightened(mottle) if n > 0.78 else (base.darkened(mottle) if n < 0.2 else base), p)


## Frayed trim.
func _rag(p: Vector3, base := Color(0.88, 0.86, 0.8)) -> Color:
	return _vary(base.darkened(0.2) if _noise(p) > 0.7 else base, p)


## A jagged web of cracks (cells near the edges of wobbly blocks).
func _crack(p: Vector3) -> bool:
	var q := p + Vector3(sin(p.y * 37.0 + p.z * 11.0), sin(p.z * 29.0 + p.x * 17.0), sin(p.x * 31.0 + p.y * 13.0)) * 0.012
	return (q / 0.09).floor() != ((q + Vector3.ONE * VOXEL * 0.3) / 0.09).floor()


func _blood(p: Vector3, chance := 0.07) -> bool:
	return _noise(p, 2.0) > 1.0 - chance


## The torso's half width and depth at height y: a narrow waist widening to
## a broad chest, sloping in to the neck.
func _torso_radius(y: float) -> Vector2:
	var c := _b("chest")
	var w := _b("waist")
	var t := clampf(y / 0.42, 0.0, 1.0)
	var r := Vector2(lerpf(0.158 * w, 0.228 * c, t), lerpf(0.108 * w, 0.132 * c, t))
	if y > 0.46:
		var k := (y - 0.46) / 0.18
		r *= Vector2(1.0 - 0.32 * k * k, 1.0 - 0.25 * k)
	return r


## Inside the torso grown by grow (cloth over it).
func _in_torso(p: Vector3, grow := 0.0) -> bool:
	if p.y < -0.04 or p.y > 0.64:
		return false
	var r := _torso_radius(p.y) + Vector2(grow, grow)
	return (p.x * p.x) / (r.x * r.x) + (p.z * p.z) / (r.y * r.y) <= 1.0


## Inside the torso or the pecs on it, grown by grow (cloth wraps the chest).
func _in_chest(p: Vector3, grow := 0.0) -> bool:
	if _in_torso(p, grow):
		return true
	var c := _b("chest")
	var chest := _torso_radius(0.445)
	for side in [-1.0, 1.0]:
		var center := Vector3(0.085 * c * side, 0.445, -(chest.y - 0.03))
		if ((p - center) / (Vector3(0.09 * c, 0.068, 0.05) + Vector3.ONE * grow)).length_squared() <= 1.0:
			return true
	return false


## A shell of cloth over the torso, from grow out, where keep() says.
func _torso_cloth(torso: Node3D, grow: float, color: Variant, keep: Callable) -> void:
	_fill(torso, Vector3(-0.42, -0.06, -0.26), Vector3(0.42, 0.66, 0.26), color, func(p: Vector3) -> bool:
		return _in_chest(p, grow + 0.012) and not _in_torso(p, grow - 0.03) and keep.call(p))


# --- The body -------------------------------------------------------------------

## The pelvis and trunk, then the muscle on them: pecs, abs in pairs,
## obliques, lats, shoulder blades and traps (clothes go over later).
func _trunk(hips: Node3D, torso: Node3D) -> void:
	var c := _b("chest")
	var w := _b("waist")
	var skin := _skin
	_blob(hips, Vector3(0, 0.03, 0), Vector3(0.175 * w, 0.1, 0.112 * w), skin)
	for side in [-1.0, 1.0]:
		_blob(hips, Vector3(0.085 * side, -0.01, 0.045), Vector3(0.095 * w, 0.1, 0.08 * w), skin)
	_fill(torso, Vector3(-0.36, -0.05, -0.22), Vector3(0.36, 0.65, 0.22), skin, func(p: Vector3) -> bool: return _in_torso(p))
	for side in [-1.0, 1.0]:
		var chest := _torso_radius(0.445)
		_blob(torso, Vector3(0.085 * c * side, 0.445, -(chest.y - 0.03)), Vector3(0.09 * c, 0.068, 0.05), skin)
		var back := _torso_radius(0.33)
		_blob(torso, Vector3((back.x - 0.04) * side, 0.33, 0.015), Vector3(0.06 * c, 0.15, 0.09 * c), skin)
		_blob(torso, Vector3(0.07 * c * side, 0.43, chest.y - 0.035), Vector3(0.075 * c, 0.09, 0.045), skin)
		for row in 3:
			var y := 0.315 - row * 0.068
			_blob(torso, Vector3(0.036 * side, y, -(_torso_radius(y).y - 0.008)), Vector3(0.033, 0.03, 0.022), skin)
		var waist := _torso_radius(0.14)
		_blob(torso, Vector3((waist.x - 0.03) * side, 0.14, -0.04), Vector3(0.04, 0.1, 0.06), skin)
	_blob(torso, Vector3(0, 0.555, 0.02), Vector3(0.17 * c, 0.065, 0.085 * c), skin)


func _leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var t := _b("thigh")
	var c := _b("calf")
	var skin := _skin
	# The thigh with the quads swelling at the front and a teardrop above the
	# knee; the kneecap; the shin and the calf behind.
	_limb(hip, Vector3(0, 0.02, 0), Vector3(0, -0.43, 0), Vector2(0.088, 0.09) * t, Vector2(0.058, 0.06) * t, skin, 0.06, 0.3)
	_blob(hip, Vector3(0.012 * side, -0.16, -0.035 * t), Vector3(0.064, 0.13, 0.055) * t, skin)
	_blob(hip, Vector3(-0.03 * side, -0.31, -0.022 * t), Vector3(0.04, 0.08, 0.042) * t, skin)
	_blob(knee, Vector3(0, 0.0, -0.012), Vector3(0.054, 0.05, 0.052) * c, skin)
	_limb(knee, Vector3(0, -0.02, 0), Vector3(0, -0.37, 0), Vector2(0.054, 0.056) * c, Vector2(0.036, 0.04) * c, skin, 0.15, 0.22)
	_blob(knee, Vector3(0.006 * side, -0.12, 0.03 * c), Vector3(0.05, 0.1, 0.045) * c, skin)
	_dress_leg(hip, knee, side)
	_shoe(knee, side)


func _arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var a := _b("arm")
	var f := _b("forearm")
	var skin := _skin
	# A round deltoid, the upper arm with biceps in front and triceps behind,
	# the elbow, a forearm thick below the elbow and narrow at the wrist.
	_blob(shoulder, Vector3(0.012 * side, -0.02, 0), Vector3(0.08, 0.085, 0.08) * a, skin)
	_limb(shoulder, Vector3(0, -0.04, 0), Vector3(0, -0.28, 0), Vector2(0.058, 0.06) * a, Vector2(0.045, 0.048) * a, skin, 0.12, 0.4)
	_blob(shoulder, Vector3(0, -0.15, -0.028 * a), Vector3(0.05, 0.08, 0.046) * a, skin)
	_blob(shoulder, Vector3(0.006 * side, -0.13, 0.03 * a), Vector3(0.048, 0.09, 0.042) * a, skin)
	_blob(elbow, Vector3(0, 0.0, 0.01), Vector3(0.048, 0.045, 0.048) * f, skin)
	_limb(elbow, Vector3(0, -0.01, 0), Vector3(0, -0.2, 0), Vector2(0.056, 0.054) * f, Vector2(0.04, 0.036) * f, skin, 0.15, 0.25)
	_dress_arm(shoulder, elbow, side)
	_hand(elbow, side)


func _shoe(knee: Node3D, side: float) -> void:
	var shoe := _p("shoes")
	var sole := _p("sole")
	var trim := _p("accent")
	var w := 0.06 * maxf(_b("calf"), 1.0)
	# A thick sole, the toe box rounding over the toes, heel and padded
	# collar, a tongue, laces up the front, a stripe down the outside.
	_block(knee, Vector3(-w - 0.006, -0.458, -0.172), Vector3(w + 0.006, -0.432, 0.082), sole, 0.02)
	_blob(knee, Vector3(0, -0.428, -0.11), Vector3(w, 0.04, 0.068), shoe)
	_block(knee, Vector3(-w, -0.44, -0.08), Vector3(w, -0.37, 0.078), shoe, 0.03)
	var top := -0.22 if fighter in ["berserker", "elementalist"] else -0.33
	_limb(knee, Vector3(0, -0.4, 0.012), Vector3(0, top, 0.012), Vector2(w + 0.004, w + 0.008), Vector2(w - 0.002, w + 0.002), shoe)
	_block(knee, Vector3(-0.026, -0.42, -0.105), Vector3(0.026, -0.335, -0.06), shoe.lightened(0.1), 0.01, Vector3(-0.5, 0, 0))
	for i in 4:
		var y := -0.405 + i * 0.018
		var z := -0.098 + i * 0.012
		_block(knee, Vector3(-0.03, y, z - 0.012), Vector3(0.03, y + 0.008, z + 0.002), trim)
	_block(knee, Vector3(w * side - 0.006, -0.428, -0.1), Vector3(w * side + 0.006, -0.406, 0.06), trim, 0.0, Vector3(0.2, 0, 0))
	if fighter == "elementalist":
		# Wrapped boots, white straps around them.
		for y in [-0.36, -0.3, -0.24]:
			_limb(knee, Vector3(0, y, 0.012), Vector3(0, y + 0.018, 0.012), Vector2(w + 0.008, w + 0.012), Vector2(w + 0.008, w + 0.012), _p("straps"))
	if fighter == "berserker":
		# High boots: red laces criss-crossing up the front, a white band at the top.
		for i in 6:
			var y := -0.37 + i * 0.024
			_block(knee, Vector3(-0.034, y, -w - 0.018), Vector3(0.034, y + 0.01, -w + 0.004), trim, 0.0, Vector3(0, 0, 0.35 * (1 - 2 * (i % 2))))
		_limb(knee, Vector3(0, -0.25, 0.012), Vector3(0, -0.215, 0.012), Vector2(w + 0.01, w + 0.014), Vector2(w + 0.01, w + 0.014), _p("band"))


func _hand(elbow: Node3D, side: float) -> void:
	var skin := _skin
	if fighter == "berserker":
		# A huge padded glove, blood-spattered: the knuckle pad, the thumb on
		# the inside, laces on the palm, a taped white cuff.
		var red := _p("glove")
		var cracks := _p("cracks")
		var glove := func(p: Vector3) -> Color:
			if cracks.a > 0.0 and _crack(p):
				return cracks
			if _blood(p, 0.16):
				return _vary(_p("glove_blood"), p)
			return _vary(red.lightened(0.12) if _noise(p, 3.0) > 0.8 else red, p)
		_block(elbow, Vector3(-0.13, -0.5, -0.155), Vector3(0.13, -0.22, 0.11), glove, 0.075)
		_blob(elbow, Vector3(0, -0.44, -0.115), Vector3(0.115, 0.065, 0.065), glove)
		_blob(elbow, Vector3(-0.12 * side, -0.34, -0.055), Vector3(0.05, 0.08, 0.055), glove)
		_block(elbow, Vector3(-0.004, -0.46, -0.15), Vector3(0.004, -0.24, -0.13), red.darkened(0.35))
		_block(elbow, Vector3(-0.016, -0.25, 0.09), Vector3(0.016, -0.17, 0.11), _p("laces"))
		var tape := _bands([_p("tape"), _p("tape_dark")], 0.016)
		_limb(elbow, Vector3(0, -0.15, 0), Vector3(0, -0.235, 0), Vector2(0.09, 0.092), Vector2(0.096, 0.098), func(p: Vector3) -> Color:
			return _vary(_p("blood"), p) if _blood(p, 0.2) else tape.call(p))
		return
	var gloves := {"counter_master": "glove", "combo_master": "glove", "free_runner": "glove", "wise_guy": "tape", "elementalist": "hand_tape"}
	var back: Color = _p(gloves[fighter]) if gloves.has(fighter) else skin
	var fingers: Color = back if fighter == "counter_master" else skin
	# The back of the fist, a row of knuckles, fingers curled under, the
	# thumb across them.
	_block(elbow, Vector3(-0.05, -0.31, -0.045), Vector3(0.05, -0.205, 0.042), back, 0.022)
	for i in 4:
		var x := -0.036 + i * 0.024
		_blob(elbow, Vector3(x, -0.304, -0.034), Vector3(0.014, 0.016, 0.016), back.lightened(0.06))
		_limb(elbow, Vector3(x, -0.298, -0.05), Vector3(x, -0.335, -0.05), Vector2(0.012, 0.016), Vector2(0.011, 0.015), fingers)
	_limb(elbow, Vector3(-0.045 * side, -0.24, -0.042), Vector3(-0.012 * side, -0.305, -0.066), Vector2(0.015, 0.015), Vector2(0.013, 0.013), fingers)
	if fighter in ["combo_master", "free_runner", "counter_master"]:
		_limb(elbow, Vector3(0, -0.198, 0), Vector3(0, -0.216, 0), Vector2(0.052, 0.049), Vector2(0.052, 0.049), _p("glove_cuff"))
	if fighter == "wise_guy":
		_box(elbow, Vector3(0.026, 0.016, 0.03), Color(1.0, 0.78, 0.22), Vector3(0.036 * side, -0.315, -0.04), Vector3.ZERO, true)


# --- The head ---------------------------------------------------------------------

func _head(head: Node3D) -> void:
	var skin := _skin
	var fw := 0.15 * _b("face")
	var jaw := _b("jaw")
	var n := _b("neck")
	# The neck (thick on the big men), a rounded skull, the jaw tapering to the
	# chin (square on the Mauler), cheekbones, ears with a bowl and a lobe.
	_limb(head, Vector3(0, -0.07, 0.015), Vector3(0, 0.12, 0.015), Vector2(0.062, 0.058) * n, Vector2(0.055, 0.052) * minf(n, 1.25), skin.darkened(0.04))
	_block(head, Vector3(-fw, 0.13, -0.15), Vector3(fw, 0.345, 0.155), skin, 0.065)
	_fill(head, Vector3(-fw, 0.015, -0.16), Vector3(fw, 0.17, 0.12), skin, func(p: Vector3) -> bool:
		var t := clampf((p.y - 0.025) / 0.13, 0.0, 1.0)
		var half := lerpf(lerpf(0.04, fw - 0.025, jaw), fw - 0.004, t * t)
		return absf(p.x) <= half and p.z >= -0.148 + (1.0 - t) * 0.012 and p.z <= lerpf(0.0, 0.11, t))
	for side in [-1.0, 1.0]:
		_blob(head, Vector3((fw - 0.04) * side, 0.16, -0.122), Vector3(0.04, 0.026, 0.03), skin)
		var x: float = (fw + 0.006) * side
		_block(head, Vector3(x - 0.012, 0.145, -0.012), Vector3(x + 0.012, 0.235, 0.045), skin, 0.012)
		_block(head, Vector3(x + 0.008 * side - 0.005, 0.165, 0.0), Vector3(x + 0.008 * side + 0.005, 0.215, 0.03), skin.darkened(0.28))
		_blob(head, Vector3(x, 0.145, 0.02), Vector3(0.012, 0.016, 0.014), skin)


## Faces are drawn in whole voxels like the cards' models: brows, eyes
## (white, pupil, iris, white), a nose standing out, a mouth.
func _face(head: Node3D) -> void:
	var eyes: Color = _look.eyes
	var skin := _skin
	var dark := Color(0.06, 0.05, 0.06)
	var iris: Color = _look.get("iris", Color(0.36, 0.24, 0.14)) if eyes == Color.BLACK else eyes
	var mouth := skin.darkened(0.55)
	match fighter:
		"berserker":
			# A scar down through the right brow.
			_px(head, 6, 9, 6, 16, skin.lightened(0.2), 0, false)
		"wise_guy":
			var stubble := func(p: Vector3) -> Color:
				return _vary(Color(0.42, 0.4, 0.4) if _noise(p) > 0.55 else _skin.darkened(0.18), p)
			var jaw := func(p: Vector3) -> bool: return true
			_fill(head, Vector3(-0.2, 0.02, -0.2), Vector3(0.2, 0.118, 0.0), stubble, jaw, true)
	_px(head, 2, 11, 5, 12, Color(0.96, 0.95, 0.93))
	_px(head, 3, 11, 3, 12, dark)
	_px(head, 4, 11, 4, 12, iris)
	_px(head, 4, 12, 4, 12, iris.lightened(0.35))
	var brow: Color = Color(0.9, 0.9, 0.88) if fighter == "elementalist" else dark
	if fighter in ["berserker", "counter_master", "combo_master"]:
		_px(head, 1, 12, 2, 13, brow, 1)
		_px(head, 3, 13, 6, 14, brow, 1)
	else:
		_px(head, 2, 13, 5, 13, dark)
		_px(head, 1, 14, 6, 14, brow, 1)
	# The nose: the bridge, a tip standing out (more on the big noses), the wings.
	_px(head, 0, 10, 0, 11, skin, 1)
	_px(head, 0, 8, 0, 9, Color(0.86, 0.48, 0.42) if fighter == "wise_guy" else skin, 2 if fighter in ["berserker", "wise_guy", "elementalist"] else 1)
	_px(head, 1, 8, 1, 8, skin.darkened(0.05), 1)
	match fighter:
		"berserker", "counter_master", "combo_master":
			# A flat, hard frown.
			_px(head, 0, 5, 1, 5, mouth)
			_px(head, 2, 4, 2, 4, mouth)
			_px(head, 0, 4, 1, 4, skin.darkened(0.08), 1)
		"free_runner":
			# A wide grin, teeth showing.
			_px(head, 0, 5, 2, 5, mouth)
			_px(head, 0, 4, 1, 4, Color(0.95, 0.94, 0.9))
			_px(head, 2, 4, 2, 4, mouth)
			_px(head, 0, 3, 1, 3, mouth)
		"wise_guy":
			# A smirk up on one side.
			_px(head, 0, 5, 1, 5, Color(0.2, 0.08, 0.06))
			_px(head, -3, 5, -3, 5, Color(0.2, 0.08, 0.06), 0, false)
			_px(head, 2, 6, 2, 6, Color(0.2, 0.08, 0.06), 0, false)
		"elementalist":
			# A full white beard from the cheeks to a broad point on the chest,
			# a big moustache over it.
			var white := Color(0.94, 0.94, 0.92)
			var beard := func(p: Vector3) -> Color:
				return _vary(white.darkened(0.12) if fposmod(p.x * 37.0 + sin(p.y * 30.0) * 0.4, 0.032) < 0.009 else white, p)
			_fill(head, Vector3(-0.18, -0.22, -0.23), Vector3(0.18, 0.16, 0.06), beard, func(p: Vector3) -> bool:
				var t := clampf((0.15 - p.y) / 0.36, 0.0, 1.0)
				var half := lerpf(0.158, 0.035, t * t) + sin(p.y * 60.0) * 0.008
				return p.y < 0.15 and absf(p.x) <= half and p.z >= -0.17 - 0.035 * sin(t * PI) and p.z <= lerpf(0.05, -0.07, t))
			_px(head, 0, 6, 4, 7, white, 1)
			_px(head, 4, 5, 5, 5, white, 1)
			_px(head, 0, 5, 1, 5, Color(0.3, 0.15, 0.12))
		_:
			_px(head, 0, 5, 1, 5, mouth)


## Hair hugging the skull, grown by grow, above a hairline: brow height at
## the front, back lower down, sideburns at the temples, the ears kept clear.
func _cap(head: Node3D, color: Variant, grow: float, brow := 0.245, back := 0.13) -> void:
	var fw := 0.15 * _b("face")
	var from := Vector3(-fw, 0.13, -0.15) - Vector3.ONE * grow
	var to := Vector3(fw, 0.345, 0.155) + Vector3.ONE * grow
	_fill(head, from, to, color, func(p: Vector3) -> bool:
		if not _in_rounded(p, from, to, 0.065 + grow):
			return false
		var line := lerpf(brow, back, smoothstep(-0.12, 0.12, p.z))
		if absf(p.x) > fw - 0.035:
			if p.z < -0.02 and p.z > -0.1:
				line = 0.17
			elif p.z >= -0.02 and p.z < 0.06:
				line = 0.24
		return p.y >= line)


func _hair(head: Node3D) -> void:
	var hair := _color("hair")
	var fw := 0.15 * _b("face")
	var streaks := func(p: Vector3) -> Color:
		return _vary(hair.lightened(0.12) if _noise(Vector3(p.x, p.y * 0.25, p.z)) > 0.82 else hair, p)
	match fighter:
		"berserker":
			# Thick and short: a squared-off top, ragged at the edges, swept
			# forward over the brow in heavy points.
			_cap(head, streaks, 0.02, 0.25, 0.12)
			_fill(head, Vector3(-fw - 0.03, 0.3, -0.2), Vector3(fw + 0.03, 0.44, 0.19), streaks, func(p: Vector3) -> bool:
				var edge := (_noise(p, 2.0) - 0.5) * 0.03
				return _in_rounded(p, Vector3(-fw - 0.022, 0.3, -0.172), Vector3(fw + 0.022, 0.405 + edge, 0.172), 0.035))
			for i in 5:
				var x := lerpf(-fw + 0.03, fw - 0.03, i / 4.0)
				_spike(head, Vector3(x, 0.36, -0.15), Vector3(x * 0.4, -0.55, -1.0), 0.075 + (i % 2) * 0.02, 0.03, 0.008, hair)
		"counter_master":
			# Full and spiky: points all over the crown swept up and back, bangs
			# falling over the brow to his left, locks over the ears.
			_cap(head, streaks, 0.022, 0.25, 0.12)
			_blob(head, Vector3(0, 0.35, 0.02), Vector3(fw + 0.03, 0.07, 0.18), streaks)
			for i in 22:
				var y := 1.0 - 1.1 * (i + 0.5) / 22.0
				var ring := sqrt(maxf(0.0, 1.0 - y * y))
				var dir := Vector3(cos(i * GOLDEN) * ring, y, maxf(sin(i * GOLDEN) * ring, -0.4))
				var out := (dir + Vector3(0, 0.6, 0.5)).normalized()
				_spike(head, Vector3(0, 0.3, 0.02) + dir * Vector3(fw, 0.07, 0.15), out, 0.1 + (i % 4) * 0.025, 0.035, 0.006, hair.lightened(0.05 * (i % 3)))
			for i in 6:
				var x := -0.12 + i * 0.048
				_spike(head, Vector3(x, 0.33, -0.155), Vector3(x - 0.35, -1.0, -0.25), 0.085 + (i % 3) * 0.02, 0.03, 0.006, hair.lightened(0.05 * (i % 2)))
			for side in [-1.0, 1.0]:
				_spike(head, Vector3((fw + 0.01) * side, 0.27, -0.02), Vector3(0.2 * side, -1.0, 0.3), 0.08, 0.03, 0.008, hair)
		"combo_master":
			# A huge mass of curls, bigger than the head: curls on curls all
			# over, hanging over the brow and down past the ears.
			_cap(head, hair, 0.03, 0.25, 0.1)
			_blob(head, Vector3(0, 0.34, 0.04), Vector3(fw + 0.09, 0.17, 0.21), hair)
			for i in 70:
				var y := 1.0 - 1.8 * (i + 0.5) / 70.0
				var ring := sqrt(maxf(0.0, 1.0 - y * y))
				var dir := Vector3(cos(i * GOLDEN) * ring, y, sin(i * GOLDEN) * ring)
				if dir.z < -0.35 and dir.y < 0.35:
					continue
				var tint := hair.lightened(0.08) if dir.y > 0.3 and i % 3 == 0 else hair.darkened(0.05 * (i % 2))
				_blob(head, Vector3(0, 0.33, 0.04) + dir * Vector3(fw + 0.1, 0.19, 0.22), Vector3.ONE * (0.038 + (i % 4) * 0.008), tint)
			for i in 7:
				var x := -0.13 + i * 0.043
				_blob(head, Vector3(x, 0.27 + (i % 2) * 0.012, -0.175), Vector3(0.03, 0.045, 0.03), hair.lightened(0.04 * (i % 2)))
				_spike(head, Vector3(x, 0.27, -0.18), Vector3(x * 0.5, -1.0, -0.2), 0.06, 0.022, 0.006, hair)
			for side in [-1.0, 1.0]:
				for k in 3:
					_blob(head, Vector3((fw + 0.04) * side, 0.2 - k * 0.05, -0.06 + k * 0.02), Vector3(0.035, 0.04, 0.035), hair.darkened(0.04 * k))
		"free_runner":
			# A bush of thick locs standing up and out, each bending at the end;
			# the red headband knotted at the back, its long tails flying.
			_cap(head, hair, 0.025, 0.25, 0.12)
			_blob(head, Vector3(0, 0.33, 0.03), Vector3(fw + 0.04, 0.09, 0.19), hair)
			for i in 34:
				var y := 1.0 - 1.25 * (i + 0.5) / 34.0
				var ring := sqrt(maxf(0.0, 1.0 - y * y))
				var dir := Vector3(cos(i * GOLDEN) * ring, y, sin(i * GOLDEN) * ring)
				if dir.z < -0.55:
					dir = Vector3(dir.x, dir.y + 0.4, -0.55).normalized()
				var base := Vector3(0, 0.32, 0.03) + dir * Vector3(fw + 0.02, 0.07, 0.17)
				var out := (dir + Vector3.UP * 0.5).normalized()
				var bend := (out + dir * 0.6 + Vector3(0, -0.2, 0)).normalized()
				var length := 0.08 + (i % 4) * 0.018
				var tint := hair.lightened(0.06 * (i % 3))
				_spike(head, base, out, length, 0.03, 0.024, tint)
				_spike(head, base + out * length, bend, length * 0.8, 0.025, 0.012, tint.darkened(0.06))
			var red := _p("band")
			_fill(head, Vector3(-fw - 0.05, 0.24, -0.2), Vector3(fw + 0.05, 0.31, 0.21), _cloth(red, 0.1), func(p: Vector3) -> bool:
				return p.y > 0.25 and p.y < 0.298 + sin(p.x * 40.0) * 0.003 and _in_rounded(p, Vector3(-fw - 0.03, 0.1, -0.18), Vector3(fw + 0.03, 0.4, 0.185), 0.09))
			_blob(head, Vector3(-0.03, 0.275, 0.195), Vector3(0.035, 0.03, 0.025), red.darkened(0.1))
			_ribbon(head, Vector3(-0.04, 0.275, 0.2), Vector3(-0.44, 0.17, 0.5), 0.045, 0.016, _cloth(red, 0.1), Vector3.UP, 0.03)
			_ribbon(head, Vector3(-0.02, 0.265, 0.2), Vector3(-0.3, 0.0, 0.48), 0.04, 0.016, _cloth(red.darkened(0.1), 0.1), Vector3.UP, 0.03)
		"wise_guy":
			# Short at the sides under a knit beanie with a folded brim.
			_cap(head, hair, 0.012, 0.22, 0.12)
			_beanie = Node3D.new()
			_beanie.name = "Beanie"
			head.add_child(_beanie)
			var knit := func(p: Vector3) -> Color:
				return _p("beanie_a") if fposmod(atan2(p.z, p.x) * 8.0, 1.0) < 0.5 else _p("beanie_b")
			_fill(_beanie, Vector3(-fw - 0.05, 0.25, -0.21), Vector3(fw + 0.05, 0.47, 0.21), knit, func(p: Vector3) -> bool:
				return p.y > 0.255 and ((p - Vector3(0, 0.27, 0.005)) / Vector3(fw + 0.03, 0.17, 0.18)).length_squared() <= 1.0)
			_fill(_beanie, Vector3(-fw - 0.05, 0.23, -0.21), Vector3(fw + 0.05, 0.31, 0.21), _p("brim"), func(p: Vector3) -> bool:
				return p.y > 0.24 and p.y < 0.3 and _in_rounded(p, Vector3(-fw - 0.034, 0.1, -0.185), Vector3(fw + 0.034, 0.4, 0.19), 0.08))
		"elementalist":
			# Long white hair swept back from a high brow, waving down past the
			# shoulders, locks behind the ears.
			var strand := func(p: Vector3) -> Color:
				return _vary(hair.darkened(0.1) if fposmod(p.x * 41.0 + sin(p.y * 20.0) * 0.3, 0.04) < 0.012 else hair, p)
			_cap(head, strand, 0.022, 0.29, 0.1)
			_fill(head, Vector3(-fw - 0.07, -0.22, 0.0), Vector3(fw + 0.07, 0.37, 0.27), strand, func(p: Vector3) -> bool:
				var t := clampf((0.36 - p.y) / 0.55, 0.0, 1.0)
				var half := fw + 0.025 + t * 0.03 + sin(p.y * 25.0) * 0.008
				var back := 0.17 + t * 0.06 + sin(p.y * 18.0 + p.x * 20.0) * 0.012
				return absf(p.x) <= half and p.z >= lerpf(0.02, 0.1, t) and p.z <= back and p.y >= -0.18 + absf(p.x) * 0.4 + (_noise(p, 1.5) - 0.5) * 0.04)
			for side in [-1.0, 1.0]:
				_limb(head, Vector3((fw + 0.02) * side, 0.24, 0.07), Vector3((fw + 0.04) * side, -0.08, 0.1), Vector2(0.03, 0.04), Vector2(0.022, 0.03), strand, 0.0, 0.5, 0.05)
			# Wild locks streaming back and up off the crown.
			for i in 26:
				var y := 1.0 - 1.3 * (i + 0.5) / 26.0
				var ring := sqrt(maxf(0.0, 1.0 - y * y))
				var dir := Vector3(cos(i * GOLDEN) * ring, y, sin(i * GOLDEN) * ring)
				if dir.z < -0.2:
					continue
				var base := Vector3(0, 0.3, 0.04) + dir * Vector3(fw + 0.02, 0.06, 0.15)
				var out := (dir + Vector3(0, 0.15, 0.9)).normalized()
				_spike(head, base, out, 0.14 + (i % 4) * 0.035, 0.04, 0.012, hair.darkened(0.08 * (i % 3)))


# --- Clothes ----------------------------------------------------------------------

## Baggy pants: full through the thigh and knee in folds, gathered toward
## the ankle (to: where they end on the shin).
func _pants(hip: Node3D, knee: Node3D, cloth: Variant, full := 1.0, to := -0.3) -> void:
	var t := _b("thigh")
	_limb(hip, Vector3(0, 0.03, 0), Vector3(0, -0.44, 0), Vector2(0.1, 0.104) * t, Vector2(0.1, 0.104) * t * full, cloth, 0.1 * full, 0.65, 0.06)
	_limb(knee, Vector3(0, 0.02, 0), Vector3(0, to, 0), Vector2(0.1, 0.104) * t * full, Vector2(0.066, 0.07), cloth, 0.1 * full, 0.2, 0.08)


## The pants' seat and waist.
func _seat(hips: Node3D, cloth: Variant) -> void:
	var w := _b("waist")
	_blob(hips, Vector3(0, 0.03, 0), Vector3(0.195 * w, 0.12, 0.13 * w), cloth)
	for side in [-1.0, 1.0]:
		_blob(hips, Vector3(0.085 * side, -0.01, 0.05), Vector3(0.11 * w, 0.11, 0.095 * w), cloth)


## Two front panels hanging from the belt to mid-thigh, split down the
## middle, trimmed (ragged when torn).
func _flaps(hips: Node3D, cloth: Color, trim: Color, torn: bool) -> void:
	var w := _b("waist")
	var body := _cloth(cloth)
	var hem := func(p: Vector3) -> float:
		return -0.27 + ((_noise(p, 1.5) - 0.5) * 0.05 if torn else 0.0)
	var slit := func(p: Vector3) -> float:
		return 0.012 + clampf(-p.y, 0.0, 0.3) * 0.15
	var paint1 := func(p: Vector3) -> Color:
		if p.y < hem.call(p) + 0.025 or absf(p.x) < slit.call(p) + 0.022:
			return _rag(p, trim) if torn else _vary(trim, p)
		return body.call(p)
	var shape1 := func(p: Vector3) -> bool:
		var flare := 1.0 + clampf(-p.y, 0.0, 0.3) * 0.7
		var rx := (0.195 * w + 0.03) * flare
		var rz := (0.13 * w + 0.03) * flare
		var d := (p.x * p.x) / (rx * rx) + (p.z * p.z) / (rz * rz)
		return p.z < 0.02 and p.y > hem.call(p) and p.y < 0.06 and d <= 1.0 and d >= 0.55 and absf(p.x) > slit.call(p)
	_fill(hips, Vector3(-0.34, -0.33, -0.27), Vector3(0.34, 0.08, 0.06), paint1, shape1)


## A cloth belt around the waist, knotted at knot (-1 left side .. 1 right),
## its two tails hanging tail long.
func _sash(torso: Node3D, color: Color, knot: float, tail := 0.26) -> void:
	_torso_cloth(torso, 0.032, _cloth(color, 0.1), func(p: Vector3) -> bool:
		return p.y > -0.035 + sin(p.x * 30.0) * 0.004 and p.y < 0.065)
	var r := _torso_radius(0.015) + Vector2(0.03, 0.03)
	var x := knot * r.x
	var z := -sqrt(maxf(0.0, 1.0 - knot * knot)) * r.y
	_blob(torso, Vector3(x, 0.015, z), Vector3(0.042, 0.04, 0.03), color.darkened(0.1))
	_ribbon(torso, Vector3(x - 0.012, 0.0, z - 0.008), Vector3(x - 0.04 + knot * 0.04, -tail, z - 0.03), 0.045, 0.016, _cloth(color, 0.1))
	_ribbon(torso, Vector3(x + 0.012, 0.0, z - 0.008), Vector3(x + 0.025 + knot * 0.06, -tail * 0.82, z - 0.02), 0.04, 0.016, _cloth(color.darkened(0.08), 0.1))


func _dress_torso(hips: Node3D, torso: Node3D) -> void:
	var c := _b("chest")
	match fighter:
		"berserker":
			# An open dark vest with ragged white trim (front, armholes, hem),
			# spattered; the red sash knotted in front, its tails hanging;
			# trunks; blood on the skin.
			var vest := _p("vest")
			var trim := _p("trim")
			var open := func(p: Vector3) -> float:
				return lerpf(0.05, 0.16 * c, clampf(p.y / 0.5, 0.0, 1.0)) + (_noise(p, 1.5) - 0.5) * 0.025
			var paint2 := func(p: Vector3) -> Color:
				var r := _torso_radius(p.y)
				if (p.z < 0.0 and absf(p.x) < open.call(p) + 0.022) or p.y < 0.022 + _noise(p, 1.5) * 0.016 or (p.y > 0.38 and absf(p.x) > r.x - 0.004) or (p.y > 0.62 and p.z > 0.0):
					return _rag(p, trim)
				return _vary(_p("blood").darkened(0.1), p) if _blood(p) else _cloth_at(p, vest)
			var shape2 := func(p: Vector3) -> bool:
				return not (p.z < 0.0 and absf(p.x) < open.call(p))
			_torso_cloth(torso, 0.022, paint2, shape2)
			var spots := func(p: Vector3) -> bool: return _blood(p, 0.03)
			_fill(torso, Vector3(-0.4, -0.05, -0.25), Vector3(0.4, 0.6, 0.0), _p("blood"), spots, true)
			_sash(torso, _p("sash"), 0.0, 0.27)
			_seat(hips, _p("trunks"))
		"counter_master":
			# A sleeveless hoodie zipped up the front, a small V at the neck,
			# white piping down the zip, round the armholes and the hem; the
			# hood down around the neck; the white belt; the hoodie's long
			# front hanging below it.
			var black := _p("cloth")
			var white := _p("piping")
			var vee := func(p: Vector3) -> bool:
				return p.z < 0.0 and p.y > 0.44 and absf(p.x) < (p.y - 0.44) * 0.55
			var paint3 := func(p: Vector3) -> Color:
				var r := _torso_radius(p.y)
				var zig := 0.005 * signf(sin(p.y * 60.0))
				if p.z < 0.0 and (absf(absf(p.x) - 0.024 - zig) < 0.008 or (p.y > 0.42 and absf(p.x) < (p.y - 0.44) * 0.55 + 0.022)):
					return _vary(white, p)
				if (p.y > 0.36 and absf(p.x) > r.x - 0.012) or p.y < 0.01:
					return _vary(white, p)
				return _cloth_at(p, black)
			var shape3 := func(p: Vector3) -> bool: return not vee.call(p)
			_torso_cloth(torso, 0.02, paint3, shape3)
			var paint4 := func(p: Vector3) -> Color:
				var r := Vector2(p.x, p.z - 0.03).length()
				return _vary(white, p) if r > 0.152 or p.y > 0.685 else _cloth_at(p, black)
			var shape4 := func(p: Vector3) -> bool:
				var r := Vector2(p.x, (p.z - 0.03) * 0.9).length()
				return p.y > 0.54 and p.y < 0.7 + 0.05 * clampf(p.z / 0.15, 0.0, 1.0) and r > 0.085 and r < 0.17 and p.z > -0.04 + (p.y - 0.55) * 0.3
			_fill(torso, Vector3(-0.24, 0.5, -0.14), Vector3(0.24, 0.76, 0.26), paint4, shape4)
			_blob(torso, Vector3(0, 0.57, 0.15), Vector3(0.14, 0.09, 0.05), black)
			_sash(torso, _p("belt"), 0.0, 0.12)
			_seat(hips, black)
			_flaps(hips, black, white, false)
		"combo_master":
			# A sleeveless crop top up to a high collar, violet piping; bare abs
			# below; the violet sash knotted at his left hip, tails hanging.
			var black := _p("top")
			var violet := _p("trim")
			var paint5 := func(p: Vector3) -> Color:
				var r := _torso_radius(p.y)
				if p.y < 0.31 or (p.y > 0.36 and absf(p.x) > r.x - 0.01):
					return _vary(violet, p)
				return _cloth_at(p, black)
			var shape5 := func(p: Vector3) -> bool: return p.y > 0.29 + (_noise(p, 1.5) - 0.5) * 0.02
			_torso_cloth(torso, 0.018, paint5, shape5)
			_limb(torso, Vector3(0, 0.56, 0.01), Vector3(0, 0.69, 0.01), Vector2(0.086, 0.08), Vector2(0.078, 0.073), func(p: Vector3) -> Color:
				return _vary(violet, p) if p.y > 0.67 else _cloth_at(p, black))
			_sash(torso, _p("sash"), -0.8, 0.32)
			_seat(hips, _p("pants"))
		"free_runner":
			# A sleeveless black gi crossed at the chest, ragged white trim at
			# the lapels, armholes and hem; a red scarf round the neck, an end
			# hanging; the red belt with white cloth hanging in front; the gi's
			# torn skirt.
			var gi := _p("gi")
			var white := _p("trim")
			var vee := func(p: Vector3) -> float:
				return (p.y - 0.28) * 0.42 + (_noise(p, 1.5) - 0.5) * 0.02
			var paint6 := func(p: Vector3) -> Color:
				var r := _torso_radius(p.y)
				if (p.z < 0.0 and p.y > 0.26 and absf(p.x) < vee.call(p) + 0.03) or (p.y > 0.36 and absf(p.x) > r.x - 0.018) or p.y < 0.02 + _noise(p, 1.5) * 0.02:
					return _rag(p, white)
				return _cloth_at(p, gi)
			var shape6 := func(p: Vector3) -> bool: return not (p.z < 0.0 and p.y > 0.28 and absf(p.x) < vee.call(p))
			_torso_cloth(torso, 0.02, paint6, shape6)
			var red := _p("band")
			_fill(torso, Vector3(-0.22, 0.5, -0.22), Vector3(0.22, 0.7, 0.22), _cloth(red, 0.1), func(p: Vector3) -> bool:
				var r := Vector2(p.x, p.z * 1.1).length() * (1.0 + 0.08 * sin(atan2(p.z, p.x) * 5.0 + p.y * 40.0))
				return p.y > 0.53 and p.y < 0.66 and r > 0.075 and r < 0.135)
			_ribbon(torso, Vector3(-0.05, 0.58, -0.13), Vector3(-0.1, 0.32, -0.17), 0.06, 0.018, _cloth(red, 0.1))
			_sash(torso, red, 0.0, 0.08)
			var r0 := _torso_radius(0.0)
			for x in [-0.03, 0.03]:
				_ribbon(torso, Vector3(x, 0.0, -r0.y - 0.045), Vector3(x * 1.4, -0.3, -r0.y - 0.06), 0.05, 0.014, func(p: Vector3) -> Color: return _rag(p, white))
			_seat(hips, gi)
			_flaps(hips, gi, white, true)
		"wise_guy":
			# A track jacket half zipped over a white tee: the zip piped white
			# down the front, a stand-up collar, pocket flaps, a ribbed hem;
			# the gold chain.
			var black := _p("jacket")
			var white := _p("zip")
			var tee := func(p: Vector3) -> bool: return true
			_torso_cloth(torso, 0.004, _p("tee"), tee)
			var vee := func(p: Vector3) -> bool:
				return p.z < 0.0 and p.y > 0.36 and absf(p.x) < (p.y - 0.36) * 0.45 + 0.012
			var jacket := func(p: Vector3) -> Color:
				if p.z < 0.0 and (absf(p.x) < 0.008 or (p.y > 0.34 and absf(p.x) < (p.y - 0.36) * 0.45 + 0.026)):
					return _vary(white, p)
				if p.y < 0.035:
					return _p("rib_a") if fposmod(atan2(p.z, p.x) * 9.0, 1.0) < 0.5 else _p("rib_b")
				return _cloth_at(p, black, 0.05)
			var zipped := func(p: Vector3) -> bool: return not vee.call(p)
			_torso_cloth(torso, 0.026, jacket, zipped)
			_limb(torso, Vector3(0, 0.55, 0.03), Vector3(0, 0.67, 0.03), Vector2(0.105, 0.1), Vector2(0.098, 0.094), func(p: Vector3) -> Color:
				return _vary(white, p) if p.z < -0.06 and absf(p.x) < 0.03 else _cloth_at(p, black, 0.05))
			for side in [-1.0, 1.0]:
				var r := _torso_radius(0.12)
				_block(torso, Vector3(0.1 * side - 0.035, 0.11, -r.y - 0.05), Vector3(0.1 * side + 0.035, 0.13, -r.y - 0.03), black.lightened(0.04), 0.004)
			for i in 11:
				var a := -1.1 + i * 0.22
				_box(torso, Vector3(0.026, 0.026, 0.026), Color(1.0, 0.78, 0.22), Vector3(sin(a) * 0.075, 0.6 - cos(a) * 0.075, -_torso_radius(0.52).y - 0.03), Vector3.ZERO, true)
			_seat(hips, black)
		"elementalist":
			# An open dark robe with ragged white edges over a bare chest, a
			# dark sash striped white, the robe hanging torn to the knee.
			var robe := _p("robe")
			var trim := _p("trim")
			var open := func(p: Vector3) -> float:
				return lerpf(0.07, 0.15 * c, clampf(p.y / 0.5, 0.0, 1.0)) + (_noise(p, 1.5) - 0.5) * 0.025
			var paint8 := func(p: Vector3) -> Color:
				if (p.z < 0.0 and absf(p.x) < open.call(p) + 0.024) or (p.y > 0.62 and p.z > 0.0):
					return _rag(p, trim)
				return _cloth_at(p, robe)
			var shape8 := func(p: Vector3) -> bool: return not (p.z < 0.0 and absf(p.x) < open.call(p))
			_torso_cloth(torso, 0.022, paint8, shape8)
			_sash(torso, _p("sash"), 0.0, 0.12)
			var stripe := func(p: Vector3) -> bool: return p.y > 0.008 and p.y < 0.024
			_torso_cloth(torso, 0.034, _p("sash_stripe"), stripe)
			_seat(hips, robe)
			_flaps(hips, robe, trim, true)


func _dress_leg(hip: Node3D, knee: Node3D, side: float) -> void:
	var t := _b("thigh")
	match fighter:
		"berserker":
			# Wide dark trunks to mid-thigh, a ragged white hem, spattered.
			var hem := func(p: Vector3) -> float:
				return -0.235 + (_noise(p, 1.5) - 0.5) * 0.04
			var paint9 := func(p: Vector3) -> Color:
				if p.y < hem.call(p) + 0.028:
					return _rag(p, _p("trim"))
				return _vary(_p("trunk_spots"), p) if _blood(p, 0.1) else _cloth_at(p, _p("trunks"))
			var shape9 := func(p: Vector3) -> bool:
				return p.y > hem.call(p) and _in_limb(p, Vector3(0, 0.03, 0), Vector3(0, -0.3, 0), Vector2(0.1, 0.104) * t, Vector2(0.106, 0.11) * t, 0.0, 0.5, 0.05)
			_fill(hip, Vector3(-0.2, -0.3, -0.2), Vector3(0.2, 0.08, 0.2), paint9, shape9)
			var spots := func(p: Vector3) -> bool: return _blood(p, 0.03)
			_fill(hip, Vector3(-0.2, -0.45, -0.2), Vector3(0.2, 0.0, 0.2), _p("blood"), spots, true)
		"counter_master":
			# Baggy black pants slashed with white lightning; a white cuff at the ankle.
			var black := _p("cloth")
			var white := _p("piping")
			var bolt := func(p: Vector3) -> Color:
				var a := atan2(p.z, p.x * side)
				var jag := absf(fposmod(p.y * 5.0, 1.0) - 0.5) * 0.9
				if absf(a + 0.95 - jag) < 0.2 or absf(a - 1.75 - jag) < 0.17:
					return _vary(white, p)
				return _cloth_at(p, black, 0.04)
			_pants(hip, knee, bolt)
			_limb(knee, Vector3(0, -0.29, 0), Vector3(0, -0.335, 0), Vector2(0.068, 0.072), Vector2(0.064, 0.068), _p("ankle"))
		"combo_master":
			# Balloon pants with big pale patches, gathered at the shin into
			# white and violet leg wraps.
			var cloth := func(p: Vector3) -> Color:
				var n := _noise(p + Vector3(0, p.x * 0.6, 0), 6.0)
				if n > 0.82:
					return _vary(_p("patch"), p)
				if n > 0.72:
					return _vary(_p("patch_mid"), p)
				return _vary(_p("pants"), p)
			_pants(hip, knee, cloth, 1.15, -0.22)
			_limb(knee, Vector3(0, -0.19, 0), Vector3(0, -0.36, 0), Vector2(0.064, 0.068), Vector2(0.05, 0.054), _bands([_p("band_a"), _p("band_b"), _p("band_c")], 0.016))
		"free_runner":
			# Baggy pants torn off at mid-shin (ragged), patched with white
			# crosses; red wraps at the ankle.
			var gi := _p("gi")
			var hem := func(p: Vector3) -> float:
				return -0.2 + (_noise(p, 1.5) - 0.5) * 0.07
			_limb(hip, Vector3(0, 0.03, 0), Vector3(0, -0.44, 0), Vector2(0.1, 0.104) * t, Vector2(0.104, 0.108) * t, _cloth(gi), 0.1, 0.65, 0.07)
			var paint10 := func(p: Vector3) -> Color:
				return _rag(p, _p("hem")) if p.y < hem.call(p) + 0.02 else _cloth_at(p, gi)
			var shape10 := func(p: Vector3) -> bool:
				return p.y > hem.call(p) and _in_limb(p, Vector3(0, 0.02, 0), Vector3(0, -0.28, 0), Vector2(0.104, 0.108) * t, Vector2(0.085, 0.09), 0.1, 0.25, 0.08)
			_fill(knee, Vector3(-0.15, -0.3, -0.15), Vector3(0.15, 0.08, 0.15), paint10, shape10)
			_cross(hip, Vector3(0.02 * side, -0.16, -0.118 * t), 0.03, _p("trim"))
			if side > 0:
				_cross(knee, Vector3(-0.02, -0.08, -0.105 * t), 0.025, _p("trim"))
			_limb(knee, Vector3(0, -0.27, 0), Vector3(0, -0.36, 0), Vector2(0.05, 0.054), Vector2(0.046, 0.05), _bands([_p("band"), _p("band").darkened(0.24)], 0.016, 0.3))
		"wise_guy":
			# Loose track pants, two white stripes down the outside, gathered
			# at the ankle.
			var stripes := func(p: Vector3) -> Color:
				var a := atan2(p.z, p.x * side)
				if absf(a + 0.5) < 0.08 or absf(a + 0.2) < 0.08:
					return _vary(_p("stripe"), p)
				return _cloth_at(p, _p("jacket"), 0.05)
			_pants(hip, knee, stripes, 0.95, -0.33)
		"elementalist":
			# Wide dark hakama to the knee, frayed white at the hem, a white
			# stripe down the front; bare shins.
			var hem := func(p: Vector3) -> float:
				return -0.38 + (_noise(p, 1.5) - 0.5) * 0.05
			var paint12 := func(p: Vector3) -> Color:
				var a := atan2(p.z, p.x * side)
				if p.y < hem.call(p) + 0.03 or absf(a + 1.2) < 0.1:
					return _rag(p, _p("trim"))
				return _cloth_at(p, _p("robe"))
			var shape12 := func(p: Vector3) -> bool:
				return p.y > hem.call(p) and _in_limb(p, Vector3(0, 0.03, 0), Vector3(0, -0.42, 0), Vector2(0.104, 0.108) * t, Vector2(0.115, 0.12) * t, 0.06, 0.6, 0.07)
			_fill(hip, Vector3(-0.22, -0.45, -0.22), Vector3(0.22, 0.08, 0.22), paint12, shape12)


func _dress_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	var a := _b("arm")
	var f := _b("forearm")
	match fighter:
		"berserker":
			# White tape up the forearm, spattered; blood on the arm.
			var tape := _bands([_p("tape"), _p("tape_dark")], 0.016, 0.3)
			_limb(elbow, Vector3(0, -0.06, 0), Vector3(0, -0.2, 0), Vector2(0.064, 0.062) * f, Vector2(0.05, 0.048) * f, func(p: Vector3) -> Color:
				return _vary(_p("blood"), p) if _blood(p, 0.14) else tape.call(p))
			var spots := func(p: Vector3) -> bool: return _blood(p, 0.04)
			_fill(shoulder, Vector3(-0.2, -0.32, -0.2), Vector3(0.2, 0.1, 0.2), _p("blood"), spots, true)
		"counter_master":
			# The hoodie over the top of the shoulder, piped white; blue wraps
			# up the forearm, banded navy and white, a loose end.
			var paint11 := func(p: Vector3) -> Color:
				return _vary(_p("piping"), p) if p.y < -0.005 else _cloth_at(p, _p("cloth"))
			var shape11 := func(p: Vector3) -> bool:
				return p.y > -0.02 and ((p - Vector3(0.012 * side, -0.02, 0)) / (Vector3(0.08, 0.085, 0.08) * a + Vector3.ONE * 0.016)).length_squared() <= 1.0
			_fill(shoulder, Vector3(-0.15, -0.05, -0.15), Vector3(0.15, 0.12, 0.15), paint11, shape11)
			var blue := _p("wrap")
			_limb(elbow, Vector3(0, -0.04, 0), Vector3(0, -0.215, 0), Vector2(0.066, 0.064) * f, Vector2(0.052, 0.05) * f, _bands([blue, blue, _p("wrap_dark"), _p("wrap_light")], 0.016, 0.25))
			_ribbon(elbow, Vector3(0.05 * side, -0.07, 0.0), Vector3(0.075 * side, -0.16, -0.01), 0.026, 0.012, blue, Vector3.BACK)
		"combo_master":
			# White wraps up the forearm, banded violet.
			_limb(elbow, Vector3(0, -0.05, 0), Vector3(0, -0.215, 0), Vector2(0.064, 0.062) * f, Vector2(0.05, 0.048) * f, _bands([_p("band_b"), _p("band_c"), _p("band_a")], 0.016, 0.3))
		"free_runner":
			# Thick white wraps in rings, skin between.
			for i in 4:
				var y := -0.04 - i * 0.042
				_limb(elbow, Vector3(0, y, 0), Vector3(0, y - 0.03, 0), Vector2(0.066, 0.064) * f * (1.0 - i * 0.06), Vector2(0.062, 0.06) * f * (1.0 - i * 0.06), func(p: Vector3) -> Color:
					return _rag(p, _p("tape")))
		"wise_guy":
			# Puffy jacket sleeves, two white stripes down the outside front,
			# gathered into ribbed cuffs.
			var sleeve := func(p: Vector3) -> Color:
				var ang := atan2(p.z, p.x * side)
				if absf(ang + 0.75) < 0.08 or absf(ang + 0.45) < 0.08:
					return _vary(_p("stripe"), p)
				return _cloth_at(p, _p("jacket"), 0.05)
			_blob(shoulder, Vector3(0.012 * side, -0.02, 0), Vector3(0.08, 0.085, 0.08) * a + Vector3.ONE * 0.022, sleeve)
			_limb(shoulder, Vector3(0, -0.04, 0), Vector3(0, -0.3, 0), Vector2(0.08, 0.082) * a, Vector2(0.07, 0.072) * a, sleeve, 0.1, 0.4, 0.05)
			_limb(elbow, Vector3(0, 0.02, 0), Vector3(0, -0.16, 0), Vector2(0.078, 0.076) * f, Vector2(0.066, 0.064) * f, sleeve, 0.1, 0.4, 0.06)
			_limb(elbow, Vector3(0, -0.155, 0), Vector3(0, -0.2, 0), Vector2(0.058, 0.055) * f, Vector2(0.052, 0.05) * f, func(p: Vector3) -> Color:
				return _p("rib_a") if fposmod(atan2(p.z, p.x) * 6.0, 1.0) < 0.5 else _p("rib_b"))
		"elementalist":
			# Short robe sleeves, wide and torn; white wraps up the forearm
			# with a key pattern, fire orange on the left, violet on the right.
			var robe := _p("robe")
			_blob(shoulder, Vector3(0.012 * side, -0.02, 0), Vector3(0.08, 0.085, 0.08) * a + Vector3.ONE * 0.02, _cloth(robe))
			var hem := func(p: Vector3) -> float:
				return -0.17 + (_noise(p, 1.5) - 0.5) * 0.05
			var paint13 := func(p: Vector3) -> Color:
				return _rag(p, _p("trim")) if p.y < hem.call(p) + 0.022 else _cloth_at(p, robe)
			var shape13 := func(p: Vector3) -> bool:
				return p.y > hem.call(p) and _in_limb(p, Vector3(0, -0.02, 0), Vector3(0, -0.2, 0), Vector2(0.084, 0.086) * a, Vector2(0.1, 0.1) * a, 0.0, 0.5, 0.06)
			_fill(shoulder, Vector3(-0.2, -0.24, -0.2), Vector3(0.2, 0.06, 0.2), paint13, shape13)
			var ink := _p("ink_left") if side < 0 else _p("ink_right")
			var key := ["XXX.", "..X.", "X.X.", "XXX."]
			_limb(elbow, Vector3(0, -0.05, 0), Vector3(0, -0.21, 0), Vector2(0.064, 0.062) * f, Vector2(0.05, 0.048) * f, func(p: Vector3) -> Color:
				var row := int(floorf((p.y + 0.17) / VOXEL))
				if row >= 0 and row < 4:
					var col := int(floorf(atan2(p.z, p.x) * 0.06 / VOXEL)) % 4
					if String(key[3 - row])[col if col >= 0 else col + 4] == "X":
						return _vary(ink, p)
				return _vary(_p("tape_a") if fposmod(p.y, 0.032) < 0.016 else _p("tape_b"), p))


## A smooth glowing block (eyes, the chain, rings); everything else is painted.
func _box(parent: Node3D, size: Vector3, tint: Color, pos: Vector3, rot := Vector3.ZERO, glow := false) -> void:
	if not glow:
		_paint(parent, pos - size * 0.5, pos + size * 0.5, tint, rot)
		return
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Enemy._glow_material(tint)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation = rot
	part.layers = LAYER
	parent.add_child(part)


func _pivot(id: String, parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = id
	pivot.position = pos
	parent.add_child(pivot)
	_joints[id] = pivot
	return pivot


func _set_layer(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = LAYER
	for child in node.get_children():
		_set_layer(child)
