class_name PropKit
extends RefCounted
## Batched set dressing (2026-11-04, the places update): every box added is
## kept as a transform under its material, and flush() draws each material as
## one MultiMesh, so a whole hall of stone, candles and banners costs a few
## draw calls on a phone. Materials are shared by color, so pieces built in
## different places still batch together.
##   var kit := PropKit.new()
##   kit.box(size, pos, kit.stone(color)); kit.pillar(...); kit.flush(parent)

var _boxes := {}  # Material -> Array[Transform3D]
var _materials := {}


func box(size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	if not _boxes.has(material):
		var list: Array[Transform3D] = []
		_boxes[material] = list
	(_boxes[material] as Array[Transform3D]).append(Scenery._box_transform(size, pos, rot))


## A box placed in a frame (a node-free transform), for props built in local space.
func box_in(frame: Transform3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	if not _boxes.has(material):
		var list: Array[Transform3D] = []
		_boxes[material] = list
	(_boxes[material] as Array[Transform3D]).append(frame * Scenery._box_transform(size, pos, rot))


func flush(parent: Node3D) -> void:
	for material in _boxes:
		Scenery._box_batch(parent, material, _boxes[material])
	_boxes.clear()


# --- Shared materials ---------------------------------------------------------------

func stone(color: Color) -> Material:
	return _shared("stone %s" % color, func() -> Material: return Look.block_material(color))


func bricks(color: Color) -> Material:
	return _shared("bricks %s" % color, func() -> Material: return Look.patterned_material(color, Look.bricks()))


func tiles(color: Color) -> Material:
	return _shared("tiles %s" % color, func() -> Material: return Look.patterned_material(color, Look.tiles()))


func metal(color: Color, metallic := 0.7) -> Material:
	return _shared("metal %s %s" % [color, metallic], func() -> Material: return Look.block_material(color, metallic))


func glow(color: Color, energy := 4.0) -> Material:
	return _shared("glow %s %s" % [color, energy], func() -> Material:
		var material := Enemy._glow_material(color)
		material.emission_energy_multiplier = energy
		return material)


func _shared(key: String, make: Callable) -> Material:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]


# --- Pieces -------------------------------------------------------------------------
# Each takes a frame: its origin on the floor, -Z facing the room's middle.

## A square stone pillar with a base and a capital.
func pillar(frame: Transform3D, height: float, width: float, color: Color) -> void:
	var body := bricks(color)
	var trim := stone(color.darkened(0.25))
	box_in(frame, Vector3(width + 0.3, 0.4, width + 0.3), Vector3(0, 0.2, 0), trim)
	box_in(frame, Vector3(width, height - 0.8, width), Vector3(0, height / 2.0, 0), body)
	box_in(frame, Vector3(width + 0.3, 0.4, width + 0.3), Vector3(0, height - 0.2, 0), trim)


## A hanging banner on a wooden pole, its cloth in color with a darker hem
## and a sigil band in trim.
func banner(frame: Transform3D, width: float, length: float, color: Color, trim: Color) -> void:
	var cloth := stone(color)
	box_in(frame, Vector3(width + 0.3, 0.09, 0.09), Vector3(0, 0, 0), stone(Color(0.16, 0.1, 0.06)))
	box_in(frame, Vector3(width, length, 0.04), Vector3(0, -length / 2.0, 0), cloth)
	box_in(frame, Vector3(width * 0.6, 0.25, 0.04), Vector3(0, -length - 0.12, 0), cloth)
	box_in(frame, Vector3(width, 0.08, 0.05), Vector3(0, -length * 0.3, 0), stone(trim))
	box_in(frame, Vector3(0.18, 0.18, 0.05), Vector3(0, -length * 0.55, 0), stone(trim), Vector3(0, 0, PI / 4))


## A few candles of different heights on the floor or a ledge (glowing tips,
## no light: lights are budgeted separately).
func candles(frame: Transform3D, rng: RandomNumberGenerator, count: int, flame: Color) -> void:
	var wax := stone(Color(0.82, 0.78, 0.66))
	var tip := glow(flame.lightened(0.3), 5.0)
	for i in count:
		var spot := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.2, 0.2))
		var h := rng.randf_range(0.12, 0.42)
		box_in(frame, Vector3(0.07, h, 0.07), spot + Vector3(0, h / 2.0, 0), wax)
		box_in(frame, Vector3(0.035, 0.07, 0.035), spot + Vector3(0, h + 0.04, 0), tip)


## An upright coffin leaning on a wall, lid on.
func coffin(frame: Transform3D, wood: Color) -> void:
	var dark := stone(wood.darkened(0.35))
	var lid := stone(wood)
	box_in(frame, Vector3(0.72, 1.9, 0.38), Vector3(0, 1.0, 0), dark, Vector3(-0.08, 0, 0))
	box_in(frame, Vector3(0.62, 1.8, 0.06), Vector3(0, 1.0, -0.21), lid, Vector3(-0.08, 0, 0))
	box_in(frame, Vector3(0.82, 0.06, 0.06), Vector3(0, 1.45, -0.26), stone(Color(0.5, 0.4, 0.22)), Vector3(-0.08, 0, 0))


## Stepped stone stands running along frame's X, length long: tiers rising
## away from the room (along +Z), each depth deep and rise high. Returns the
## spots (frames, facing -Z) where spectators stand, spacing apart.
func stands(frame: Transform3D, length: float, tiers: int, depth: float, rise: float, color: Color, spacing := 1.15) -> Array[Transform3D]:
	var seats: Array[Transform3D] = []
	var step := stone(color)
	var lip := stone(color.darkened(0.3))
	for tier in tiers:
		var h := rise * (tier + 1)
		var z := depth * (tier + 0.5)
		box_in(frame, Vector3(length, h, depth), Vector3(0, h / 2.0, z), step)
		box_in(frame, Vector3(length, 0.08, 0.12), Vector3(0, h + 0.04, z - depth / 2.0 + 0.06), lip)
		var count := int(length / spacing)
		for i in count:
			var x := -length / 2.0 + spacing * (i + 0.5)
			seats.append(frame * Transform3D(Basis.IDENTITY, Vector3(x, h, z + 0.1)))
	return seats


## A fire bowl on a short iron stand (the flame itself is Look.flame).
func brazier(frame: Transform3D, iron_color := Color(0.1, 0.09, 0.1)) -> Vector3:
	var iron := metal(iron_color)
	box_in(frame, Vector3(0.14, 1.0, 0.14), Vector3(0, 0.5, 0), iron)
	box_in(frame, Vector3(0.5, 0.06, 0.5), Vector3(0, 0.03, 0), iron)
	box_in(frame, Vector3(0.7, 0.2, 0.7), Vector3(0, 1.1, 0), iron)
	box_in(frame, Vector3(0.5, 0.06, 0.5), Vector3(0, 1.22, 0), stone(Color(0.15, 0.06, 0.03)))
	return frame * Vector3(0, 1.32, 0)
