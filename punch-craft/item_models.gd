class_name ItemModels
## The Crypt gear's 3D models (Crypt revamp plan, 2026-11-03): 5 sets x 4
## pieces, each built from simple shapes sampled into small cubes. Gear uses
## CUBE, half the fighters' edge (an eighth of their volume), so small things
## like studs, straps and emblems have room to show.
##
## A piece is a list of shapes, each painted with one of its set's palette roles
## (primary, secondary, metal, accent, trim). Rarity recolors the same model:
## common is dull and dingy with tatter spots; uncommon cleaner and muted; rare
## full color; epic saturated with small purple sparkles; legendary saturated
## with dramatic gold sparkles.
##
## Origin at the piece's center; its front faces -Z (toward a camera at -Z).

## Cube edge in meters. The fighters use 0.036 (FighterBody "large").
const CUBE := 0.018

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]

## Palette roles per set.
const SETS := {
	"deadweight": {"name": "Deadweight", "primary": Color(0.62, 0.12, 0.1), "secondary": Color(0.24, 0.17, 0.14),
		"metal": Color(0.44, 0.44, 0.48), "accent": Color(0.9, 0.38, 0.18), "trim": Color(0.7, 0.68, 0.64)},
}

const SPARKLE := {"epic": Color(0.75, 0.45, 1.0), "legendary": Color(1.0, 0.82, 0.3)}


## A piece as a Node3D: the voxel body plus its rarity's sparkles.
static func build(set_id: String, piece: String, rarity := "rare", cube := CUBE) -> Node3D:
	var root := Node3D.new()
	root.name = "%s_%s" % [set_id, piece]
	var shapes := _shapes(set_id, piece)
	if shapes.is_empty():
		return root
	var palette := _palette(set_id, rarity)
	var cells := _rasterize(shapes, palette, cube)
	if rarity == "common":
		_tatter(cells)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh(cells, cube, rarity)
	root.add_child(body)
	if SPARKLE.has(rarity):
		root.add_child(_sparkles(cells, cube, rarity))
	return root


# --- The pieces -----------------------------------------------------------------

## Shapes: [kind, center, size, role] with kind box, ball (ellipsoid), tube
## (cylinder along y), cut (removes cubes, size as a box) or paint (recolors
## cubes already there, size as a box: plates and bands that follow a curve).
static func _shapes(set_id: String, piece: String) -> Array:
	match "%s/%s" % [set_id, piece]:
		"deadweight/gloves":
			# A heavy red boxing mitt standing on its cuff, the curled fist
			# bulging forward: the striking face plated in studded iron, a
			# buckled strap round the wrist, the thumb tucked along the front.
			var shapes := [
				["tube", Vector3(0, -0.095, 0.01), Vector3(0.1, 0.08, 0.1), "secondary"],
				["tube", Vector3(0, -0.08, 0.01), Vector3(0.112, 0.022, 0.112), "metal"],
				["box", Vector3(0, -0.08, -0.05), Vector3(0.036, 0.036, 0.018), "trim"],
				["tube", Vector3(0, -0.052, 0.005), Vector3(0.118, 0.018, 0.118), "accent"],
				["ball", Vector3(0, 0.01, 0.0), Vector3(0.13, 0.14, 0.14), "primary"],
				["ball", Vector3(0, 0.035, -0.06), Vector3(0.13, 0.13, 0.12), "primary"],
				["ball", Vector3(0, 0.075, -0.025), Vector3(0.12, 0.08, 0.14), "primary"],
				["ball", Vector3(-0.058, -0.012, -0.075), Vector3(0.045, 0.07, 0.05), "primary"],
				# The iron plate wraps the knuckles' curve (paints the surface).
				["paint", Vector3(0, 0.045, -0.1), Vector3(0.11, 0.06, 0.06), "metal"],
			]
			# Studs across the plate, and a seam over the back of the hand.
			for i in 3:
				shapes.append(["box", Vector3(-0.036 + i * 0.036, 0.045, -0.123), Vector3(0.012, 0.012, 0.012), "trim"])
			shapes.append(["box", Vector3(0, 0.03, 0.068), Vector3(0.018, 0.09, 0.018), "accent"])
			return shapes
	return []


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

## {Vector3i: Color} for every filled cube; later shapes paint over earlier.
static func _rasterize(shapes: Array, palette: Dictionary, cube: float) -> Dictionary:
	var low := Vector3.INF
	var high := -Vector3.INF
	for s in shapes:
		if s[0] in ["cut", "paint"]:
			continue
		low = low.min(s[1] - s[2] / 2.0)
		high = high.max(s[1] + s[2] / 2.0)
	var first := Vector3i((low / cube).floor())
	var last := Vector3i((high / cube).ceil())
	var cells := {}
	for x in range(first.x, last.x):
		for y in range(first.y, last.y):
			for z in range(first.z, last.z):
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * cube
				for s in shapes:
					if _inside(s[0], p - s[1], s[2]):
						if s[0] == "cut":
							cells.erase(Vector3i(x, y, z))
						elif s[0] == "paint":
							if cells.has(Vector3i(x, y, z)):
								cells[Vector3i(x, y, z)] = palette[s[3]]
						elif not palette.has(s[3]):
							push_error("ItemModels: no palette role %s" % s[3])
						else:
							cells[Vector3i(x, y, z)] = palette[s[3]]
	return cells


static func _inside(kind: String, p: Vector3, size: Vector3) -> bool:
	var h := size / 2.0
	match kind:
		"box", "cut", "paint":
			return absf(p.x) <= h.x and absf(p.y) <= h.y and absf(p.z) <= h.z
		"ball":
			return (p.x * p.x) / (h.x * h.x) + (p.y * p.y) / (h.y * h.y) + (p.z * p.z) / (h.z * h.z) <= 1.0
		"tube":
			return absf(p.y) <= h.y and (p.x * p.x) / (h.x * h.x) + (p.z * p.z) / (h.z * h.z) <= 1.0
	return false


## Common gear: worn through in spots, and grimy.
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
	material.roughness = 0.8 if rarity in ["common", "uncommon"] else 0.6
	mesh.surface_set_material(0, material)
	return mesh


## A cube's shade: a little noise, darker on edges and corners (cleaner at
## higher rarities).
static func _shade(cells: Dictionary, c: Vector3i, rarity: String) -> Color:
	var color: Color = cells[c]
	var noise := Voxel._hash(c.x, c.y, c.z, 1)
	var spread := 0.1 if rarity in ["common", "uncommon"] else 0.06
	color = color.darkened(noise * spread) if noise > 0.5 else color.lightened((0.5 - noise) * spread)
	var open := _open_sides(cells, c)
	if open >= 3:
		color = color.darkened(0.18)
	elif open == 2:
		color = color.darkened(0.08)
	return color


## Glowing specks just off the surface: small purple ones (epic), more and
## bigger gold ones (legendary).
static func _sparkles(cells: Dictionary, cube: float, rarity: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Sparkles"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SPARKLE[rarity]
	material.emission_enabled = true
	material.emission = SPARKLE[rarity]
	material.emission_energy_multiplier = 2.5 if rarity == "legendary" else 1.6
	var chance := 0.09 if rarity == "legendary" else 0.05
	var size := cube * (0.7 if rarity == "legendary" else 0.5)
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
				speck.position = (Vector3(c) + Vector3(0.5, 0.5, 0.5) + Vector3(n) * 0.75) * cube
				speck.rotation = Vector3(0.6, 0.8, 0.0)
				node.add_child(speck)
				break
	return node
