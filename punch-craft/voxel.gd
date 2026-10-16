class_name Voxel
## Turns a simple part (a box, cylinder, sphere or capsule mesh with a plain
## color) into a voxel mesh: small cubes filling the same shape, each a
## slightly different shade, darker along edges and corners, with grime
## specks and the odd raised cube. Only faces that can be seen are built, and
## the result is cached per shape and color, so each part is made once.

## Largest and smallest cube size, in meters (before the enemy's own scale).
const MAX_VOXEL := 0.04
const MIN_VOXEL := 0.016

static var _cache := {}
static var _materials := {}


## The voxel version of mesh painted in material's color, or null when the
## part shouldn't be voxelized (glowing, see-through, or an unsupported shape).
static func voxelize(mesh: Mesh, material: Material) -> ArrayMesh:
	var base := material as StandardMaterial3D
	if base == null or base.emission_enabled or base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	var shape := ""
	var size := Vector3.ZERO
	var radii := Vector2.ZERO
	if mesh is BoxMesh:
		shape = "box"
		size = (mesh as BoxMesh).size
	elif mesh is CylinderMesh:
		shape = "cylinder"
		var cylinder := mesh as CylinderMesh
		radii = Vector2(cylinder.bottom_radius, cylinder.top_radius)
		var r := maxf(radii.x, radii.y)
		size = Vector3(r * 2.0, cylinder.height, r * 2.0)
	elif mesh is SphereMesh:
		shape = "sphere"
		var sphere := mesh as SphereMesh
		size = Vector3(sphere.radius * 2.0, sphere.height, sphere.radius * 2.0)
	elif mesh is CapsuleMesh:
		shape = "capsule"
		var capsule := mesh as CapsuleMesh
		size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
	else:
		return null
	var key := "%s|%s|%s|%s|%.2f" % [shape, size.snapped(Vector3.ONE * 0.001), radii.snapped(Vector2.ONE * 0.001), base.albedo_color.to_html(), base.metallic]
	if _cache.has(key):
		return _cache[key]
	var result := _build(shape, size, radii, base)
	_cache[key] = result
	return result


## Builds the voxel parts of these enemy scenes up front (while a level
## loads), so the first one of a kind to spawn mid-fight doesn't hitch.
static func prewarm(parent: Node, scenes: Array) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, -500, 0)
	holder.visible = false
	parent.add_child(holder)
	for scene in scenes:
		var enemy := (scene as PackedScene).instantiate() as Enemy
		if enemy == null:
			continue
		enemy.setup(null, false)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		holder.add_child(enemy)
		enemy.remove_from_group("enemies")
		enemy._voxelize_parts()
	holder.queue_free()


## One shared vertex-colored material per finish (matte or metal).
static func _material_for(base: StandardMaterial3D) -> StandardMaterial3D:
	var metal := base.metallic > 0.0
	if not _materials.has(metal):
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.metallic = base.metallic
		material.roughness = 0.45 if metal else 0.85
		material.metallic_specular = 0.4
		_materials[metal] = material
	return _materials[metal]


static func _build(shape: String, size: Vector3, radii: Vector2, base: StandardMaterial3D) -> ArrayMesh:
	var smallest := minf(size.x, minf(size.y, size.z))
	var target := clampf(smallest / 3.0, MIN_VOXEL, MAX_VOXEL)
	var counts := Vector3i(maxi(1, roundi(size.x / target)), maxi(1, roundi(size.y / target)), maxi(1, roundi(size.z / target)))
	var cell := Vector3(size.x / counts.x, size.y / counts.y, size.z / counts.z)
	var half := size / 2.0
	# Which cells are inside the shape.
	var filled := {}
	for x in counts.x:
		for y in counts.y:
			for z in counts.z:
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * cell - half
				if _inside(shape, p, size, radii):
					filled[Vector3i(x, y, z)] = true
	if filled.is_empty():
		return null
	# A few cubes pushed out of the top and sides, for a chunky outline.
	var bumps := {}
	for c in filled:
		var h := _hash(c.x, c.y, c.z, 7)
		if h < 0.05:
			for n in [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
				if not filled.has(c + n) and not bumps.has(c + n):
					bumps[c + n] = 0.45
					break
	var color: Color = base.albedo_color
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var faces := [
		[Vector3i(1, 0, 0), Vector3(1, 0, 0)], [Vector3i(-1, 0, 0), Vector3(-1, 0, 0)],
		[Vector3i(0, 1, 0), Vector3(0, 1, 0)], [Vector3i(0, -1, 0), Vector3(0, -1, 0)],
		[Vector3i(0, 0, 1), Vector3(0, 0, 1)], [Vector3i(0, 0, -1), Vector3(0, 0, -1)],
	]
	for c in filled:
		var tint := _shade(color, c, counts, filled)
		var center := (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cell - half
		for face in faces:
			if filled.has(c + face[0]) or bumps.has(c + face[0]):
				continue
			_add_face(verts, normals, colors, center, cell, face[1], tint)
	for c in bumps:
		var tint := _shade(color, c, counts, filled).darkened(0.05)
		var squash: float = bumps[c]
		var size_b := cell * squash
		var center := (Vector3(c) + Vector3(0.5, 0.5, 0.5)) * cell - half
		# Sit the bump against the face it grew from.
		for face in faces:
			if filled.has(c - face[0]):
				center -= Vector3(face[0]) * (cell - size_b) / 2.0
				break
		for face in faces:
			if filled.has(c + face[0]):
				continue
			_add_face(verts, normals, colors, center, size_b, face[1], tint)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, _material_for(base))
	return result


static func _inside(shape: String, p: Vector3, size: Vector3, radii: Vector2) -> bool:
	match shape:
		"box":
			return true
		"cylinder":
			var t := clampf(p.y / size.y + 0.5, 0.0, 1.0)
			var r := lerpf(radii.x, radii.y, t)
			return Vector2(p.x, p.z).length() <= r + 0.0001
		"sphere":
			return Vector3(p.x / (size.x / 2.0), p.y / (size.y / 2.0), p.z / (size.z / 2.0)).length() <= 1.0
		"capsule":
			var r := size.x / 2.0
			var reach := maxf(0.0, size.y / 2.0 - r)
			return Vector3(p.x, clampf(p.y, -reach, reach) - p.y, p.z).length() <= r
	return false


## A voxel's shade: noise, grime, darker toward edges and corners, a little
## lighter on top.
static func _shade(color: Color, c: Vector3i, counts: Vector3i, filled: Dictionary) -> Color:
	var noise := _hash(c.x, c.y, c.z, 1)
	var tint := color.darkened(noise * 0.12) if noise > 0.5 else color.lightened((0.5 - noise) * 0.1)
	if _hash(c.x, c.y, c.z, 3) < 0.05:
		tint = tint.darkened(0.3)  # Grime.
	var open := 0
	for n in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if not filled.has(c + n):
			open += 1
	if open >= 3:
		tint = tint.darkened(0.22)  # Corner.
	elif open == 2:
		tint = tint.darkened(0.12)  # Edge.
	if c.y == counts.y - 1:
		tint = tint.lightened(0.04)
	return tint


static func _add_face(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, center: Vector3, cell: Vector3, normal: Vector3, color: Color) -> void:
	var h := cell / 2.0
	# Two axes spanning the face.
	var u := Vector3(normal.y, normal.z, normal.x).abs()
	var v := normal.cross(u)
	var c := center + normal * h
	var du := u * h
	var dv := v * h
	var a := c - du - dv
	var b := c + du - dv
	var d := c + du + dv
	var e := c - du + dv
	# Wind so the face points along the normal.
	if (b - a).cross(d - a).dot(normal) > 0.0:
		for p in [a, d, b, a, e, d]:
			verts.append(p)
	else:
		for p in [a, b, d, a, d, e]:
			verts.append(p)
	for i in 6:
		normals.append(normal)
		colors.append(color)


static func _hash(x: int, y: int, z: int, salt: int) -> float:
	var h := sin(x * 127.1 + y * 311.7 + z * 74.7 + salt * 19.19) * 43758.5453
	return h - floorf(h)
