class_name ItemModels
## The Crypt gear's 3D models (Crypt revamp plan, 2026-11-03): 5 sets x 4
## pieces, sculpted as smooth shapes (signed distance fields blended into each
## other) and sampled into fine cubes, CUBE on a side: about 90 cubes along a
## glove, enough for a rolled thumb, curled knuckles, a raised ring on the
## punching face and laced cuffs.
##
## A piece is a list of shapes, each painted with one of its set's palette roles
## (primary, secondary, metal, accent, trim). Rarity recolors the same model:
## common is dull and dingy with tatter spots; uncommon cleaner and muted; rare
## full color; epic saturated with small purple sparkles; legendary saturated
## with dramatic gold sparkles. Built meshes are cached.
##
## Origin at the piece's center; its front faces -Z.

## Cube edge in meters (the fighters use 0.036): about 90 along a glove.
const CUBE := 0.004

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]

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


const SPARKLE := {"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.82, 0.3)}


## A piece as a Node3D: the voxel body plus its rarity's sparkles.
static func build(set_id: String, piece: String, rarity := "rare", cube := CUBE) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [set_id, piece]
	var key := "%s/%s/%s/%.4f" % [set_id, piece, rarity, cube]
	if not _cache.has(key):
		var shapes := _shapes(set_id, piece)
		if shapes.is_empty():
			return root
		var cells := _rasterize(shapes, _palette(set_id, rarity), cube)
		if rarity == "common":
			_tatter(cells)
		_cache[key] = {"mesh": _mesh(cells, cube, rarity), "cells": cells}
	var built: Dictionary = _cache[key]
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = built.mesh
	root.add_child(body)
	if SPARKLE.has(rarity):
		root.add_child(_sparkles(built.cells, cube, rarity))
	return root


## An item's model: its set (item.set, else the set its stats lean to) and
## its slot, in its rarity. An empty Node3D for things with no model.
static func build_for_item(item: Dictionary, cube := CUBE) -> Node3D:
	var rarity: String = item.get("rarity", "rare")
	if not rarity in RARITIES:
		rarity = "epic" if rarity == "cursed" else "rare"
	return build(set_for(item), String(item.get("slot", "")), rarity, cube)


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

## Shapes are dictionaries:
##   op: "add" (default), "cut" (carves away) or "paint" (recolors what's there)
##   kind: "ball" (ellipsoid: at, r), "capsule" (a, b, r), "box" (at, half,
##     round), "tube" (cylinder along axis: at, r, h, axis "x"/"y"/"z"),
##     "ring" (torus: at, R, r, axis)
##   role: palette role; blend: how softly an "add" melts into what's before
##     it (meters, default 0.012).
static func _shapes(set_id: String, piece: String) -> Array:
	match "%s/%s" % [set_id, piece]:
		"deadweight/gloves":
			return _deadweight_gloves()
	return []


## A red boxing glove lying on its side, like a real one: a big rounded fist,
## the slim thumb lying along the palm side from the cuff to the curled
## fingers (a small dark notch under it), and a plain dark cuff with a white
## edge. The set shows in the colors, not in ornaments.
static func _deadweight_gloves() -> Array:
	return [
		# The fist: back of the hand and the curled fingers.
		{"kind": "ball", "at": Vector3(0, -0.01, 0.0), "r": Vector3(0.07, 0.066, 0.1), "role": "primary"},
		{"kind": "ball", "at": Vector3(0, 0.0, -0.072), "r": Vector3(0.076, 0.076, 0.074), "role": "primary", "blend": 0.02},
		# The wrist tapers into the cuff; a white edge at its end.
		{"kind": "capsule", "a": Vector3(0, -0.006, 0.07), "b": Vector3(0, -0.006, 0.15), "r": 0.054, "role": "secondary", "blend": 0.014},
		{"kind": "tube", "at": Vector3(0, -0.006, 0.158), "r": 0.057, "h": 0.016, "axis": "z", "role": "trim", "blend": 0.0},
		# The thumb lies along the palm side as a ridge, its tip joined to
		# the curled fingers.
		{"kind": "capsule", "a": Vector3(0.006, 0.052, 0.055), "b": Vector3(0.012, 0.08, -0.012), "r": 0.022, "role": "primary", "blend": 0.01},
		{"kind": "capsule", "a": Vector3(0.012, 0.08, -0.012), "b": Vector3(0.008, 0.066, -0.07), "r": 0.02, "role": "primary", "blend": 0.01},
		# A thin dark slit under the front of the thumb, where it meets the fingers.
		{"op": "cut", "kind": "capsule", "a": Vector3(0.034, 0.064, -0.002), "b": Vector3(0.03, 0.058, -0.05), "r": 0.0055},
		{"op": "paint", "kind": "capsule", "a": Vector3(0.034, 0.064, -0.002), "b": Vector3(0.03, 0.058, -0.05), "r": 0.009, "role": "secondary"},
	]


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




# --- Cubes ------------------------------------------------------------------------

static var _cache := {}


## {Vector3i: Color} for every cube inside the blended shapes.
static func _rasterize(shapes: Array, palette: Dictionary, cube: float) -> Dictionary:
	var low := Vector3.INF
	var high := -Vector3.INF
	var boxes: Array = []
	for s: Dictionary in shapes:
		var b := _bounds(s)
		boxes.append(b)
		if s.get("op", "add") != "add":
			continue
		low = low.min(b.position)
		high = high.max(b.end)
	var first := Vector3i((low / cube).floor()) - Vector3i.ONE
	var last := Vector3i((high / cube).ceil()) + Vector3i.ONE
	var cells := {}
	for x in range(first.x, last.x):
		# Only the shapes this slab of cubes can touch.
		var px := (x + 0.5) * cube
		var slab: Array = []
		for i in shapes.size():
			if px >= boxes[i].position.x and px <= boxes[i].end.x:
				slab.append(i)
		if slab.is_empty():
			continue
		for y in range(first.y, last.y):
			var py := (y + 0.5) * cube
			var row: Array = slab.filter(func(i: int) -> bool: return py >= boxes[i].position.y and py <= boxes[i].end.y)
			if row.is_empty():
				continue
			for z in range(first.z, last.z):
				var p := Vector3(px, py, (z + 0.5) * cube)
				var d := INF
				var role := ""
				var nearest := INF
				var paint := ""
				for i: int in row:
					if p.z < boxes[i].position.z or p.z > boxes[i].end.z:
						continue
					var s: Dictionary = shapes[i]
					var op: String = s.get("op", "add")
					var e := _sdf(s, p)
					if op == "paint":
						if e <= 0.0:
							paint = s.role
						continue
					if op == "cut":
						d = maxf(d, -e)
						continue
					var k: float = s.get("blend", 0.012)
					d = e if d == INF else (_smin(d, e, k) if k > 0.0 else minf(d, e))
					if e <= nearest + 0.002:
						nearest = e
						role = s.role
				if d > 0.0:
					continue
				cells[Vector3i(x, y, z)] = palette.get(paint if paint != "" else role, Color.MAGENTA)
	return cells


static func _smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


static func _sdf(s: Dictionary, p: Vector3) -> float:
	match s.kind:
		"ball":
			var r: Vector3 = s.r
			var q := p - (s.at as Vector3)
			var k0 := (q / r).length()
			var k1 := (q / (r * r)).length()
			return k0 * (k0 - 1.0) / maxf(k1, 0.0001)
		"capsule":
			var a: Vector3 = s.a
			var ab: Vector3 = (s.b as Vector3) - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			return (p - (a + ab * t)).length() - float(s.r)
		"box":
			var q := ((p - (s.at as Vector3)).abs() - (s.half as Vector3))
			var rounding: float = s.get("round", 0.0)
			return q.max(Vector3.ZERO).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - rounding
		"tube":
			var q := _axis(p - (s.at as Vector3), s.get("axis", "y"))
			var dx := Vector2(q.x, q.z).length() - float(s.r)
			var dy := absf(q.y) - float(s.h) / 2.0
			return minf(maxf(dx, dy), 0.0) + Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
		"ring":
			var q := _axis(p - (s.at as Vector3), s.get("axis", "y"))
			return Vector2(Vector2(q.x, q.z).length() - float(s.R), q.y).length() - float(s.r)
	return INF


## p turned so the shape's axis lies along y.
static func _axis(p: Vector3, axis: String) -> Vector3:
	match axis:
		"x":
			return Vector3(p.y, p.x, p.z)
		"z":
			return Vector3(p.x, p.z, p.y)
	return p


static func _bounds(s: Dictionary) -> AABB:
	var pad := Vector3.ONE * float(s.get("blend", 0.012))
	match s.kind:
		"ball":
			return AABB(s.at - s.r - pad, (s.r + pad) * 2.0)
		"capsule":
			var r := Vector3.ONE * float(s.r) + pad
			var lo: Vector3 = (s.a as Vector3).min(s.b)
			var hi: Vector3 = (s.a as Vector3).max(s.b)
			return AABB(lo - r, hi - lo + r * 2.0)
		"box":
			var h: Vector3 = s.half + Vector3.ONE * float(s.get("round", 0.0)) + pad
			return AABB(s.at - h, h * 2.0)
	var big := Vector3.ONE * (maxf(float(s.get("R", 0.0)) + float(s.get("r", 0.0)), maxf(float(s.get("r", 0.0)), float(s.get("h", 0.0)))) + pad.x)
	return AABB(s.at - big, big * 2.0)

static func _tatter(cells: Dictionary) -> void:
	var holes: Array = []
	for c: Vector3i in cells:
		if _open_sides(cells, c) >= 2 and Voxel._hash(c.x, c.y, c.z, 41) < 0.07:
			holes.append(c)
	for c in holes:
		cells.erase(c)
	for c: Vector3i in cells:
		if Voxel._hash(c.x, c.y, c.z, 43) < 0.12:
			cells[c] = (cells[c] as Color).darkened(0.35)


static func _open_sides(cells: Dictionary, c: Vector3i) -> int:
	var open := 0
	for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if not cells.has(c + n):
			open += 1
	return open




static func _mesh(cells: Dictionary, cube: float, rarity: String) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var faces := [
		[Vector3i(1, 0, 0), Vector3(1, 0, 0)], [Vector3i(-1, 0, 0), Vector3(-1, 0, 0)],
		[Vector3i(0, 1, 0), Vector3(0, 1, 0)], [Vector3i(0, -1, 0), Vector3(0, -1, 0)],
		[Vector3i(0, 0, 1), Vector3(0, 0, 1)], [Vector3i(0, 0, -1), Vector3(0, 0, -1)],
	]
	var cell := Vector3.ONE * cube
	for c: Vector3i in cells:
		if _open_sides(cells, c) == 0:
			continue
		var tint := _shade(cells, c, rarity)
		var center := (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cube
		for face in faces:
			if cells.has(c + face[0]):
				continue
			Voxel._add_face(verts, normals, colors, center, cell, face[1], tint)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85 if rarity in ["common", "uncommon"] else 0.65
	mesh.surface_set_material(0, material)
	return mesh


## A cube's shade: darker in creases (where the surface folds in), a touch
## lighter on top. Common and uncommon gear gets a faint mottle; the rest is
## clean.
const CREASE_PROBES := [
	Vector3i(3, 0, 0), Vector3i(-3, 0, 0), Vector3i(0, 3, 0), Vector3i(0, -3, 0), Vector3i(0, 0, 3), Vector3i(0, 0, -3),
	Vector3i(2, 2, 2), Vector3i(-2, 2, 2), Vector3i(2, -2, 2), Vector3i(-2, -2, 2),
	Vector3i(2, 2, -2), Vector3i(-2, 2, -2), Vector3i(2, -2, -2), Vector3i(-2, -2, -2),
	Vector3i(5, 0, 0), Vector3i(-5, 0, 0), Vector3i(0, 5, 0), Vector3i(0, -5, 0), Vector3i(0, 0, 5), Vector3i(0, 0, -5),
]


static func _shade(cells: Dictionary, c: Vector3i, rarity: String) -> Color:
	var color: Color = cells[c]
	if rarity in ["common", "uncommon"]:
		var noise := Voxel._hash(c.x, c.y, c.z, 1)
		color = color.darkened(noise * 0.06)
	var around := 0
	for o: Vector3i in CREASE_PROBES:
		if cells.has(c + o):
			around += 1
	var enclosed := around / float(CREASE_PROBES.size())
	if enclosed > 0.62:
		color = color.darkened(clampf((enclosed - 0.62) * 1.1, 0.0, 0.35))
	elif enclosed < 0.35:
		color = color.lightened(clampf((0.35 - enclosed) * 0.25, 0.0, 0.07))
	if not cells.has(c + Vector3i(0, 1, 0)):
		color = color.lightened(0.025)
	return color


static func _sparkles(cells: Dictionary, cube: float, rarity: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Sparkles"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SPARKLE[rarity]
	material.emission_enabled = true
	material.emission = SPARKLE[rarity]
	material.emission_energy_multiplier = 2.5 if rarity == "legendary" else 1.6
	# A set number of specks, whatever the cube size: 14 epic, 26 legendary.
	var surface := 0
	for c: Vector3i in cells:
		if _open_sides(cells, c) > 0:
			surface += 1
	var chance := (26.0 if rarity == "legendary" else 14.0) / maxf(surface, 1.0)
	var size := 0.011 if rarity == "legendary" else 0.008
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = material
	for c: Vector3i in cells:
		if _open_sides(cells, c) == 0 or Voxel._hash(c.x, c.y, c.z, 53) >= chance:
			continue
		for n in [Vector3i(0, 1, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1)]:
			if not cells.has(c + n):
				var speck := MeshInstance3D.new()
				speck.mesh = mesh
				speck.position = (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cube + Vector3(n) * (cube * 0.5 + size * 0.4)
				speck.rotation = Vector3(0.6, 0.8, 0.0)
				node.add_child(speck)
				break
	return node
