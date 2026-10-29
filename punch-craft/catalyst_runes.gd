class_name CatalystRunes
extends Node3D
## The Catalyst's runes: one per power his passive runs (GameState.selected_powers),
## floating in a small arc above his hands, each glowing its power's
## color. One power (Attunement): one big rune. Two (Dual Sigil): two medium.
## Four (Prism): four small. Each turns slowly, and burns bright while its
## power can go off, dim while it recovers (PowerPlay). Rides on the camera.

## Size and spots (camera space) by how many runes there are.
const LAYOUTS := {
	1: [0.085, [Vector3(0, -0.2, -0.8)]],
	2: [0.065, [Vector3(-0.15, -0.2, -0.8), Vector3(0.15, -0.2, -0.8)]],
	3: [0.055, [Vector3(-0.2, -0.19, -0.8), Vector3(0, -0.22, -0.8), Vector3(0.2, -0.19, -0.8)]],
	4: [0.045, [Vector3(-0.25, -0.18, -0.8), Vector3(-0.085, -0.22, -0.8), Vector3(0.085, -0.22, -0.8), Vector3(0.25, -0.18, -0.8)]],
}
const DIM := 0.25

var player: Player
var _roots: Array = []
var _runes: Array[Node3D] = []
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var picks: Array = GameState.selected_powers()
	if picks != _roots:
		_build(picks)
	var ready_by_root := {}
	if player and player.powers:
		for entry in player.powers.status():
			ready_by_root[entry[0]] = entry[2]
	for i in _runes.size():
		var rune := _runes[i]
		rune.rotation.z += delta * (0.6 if i % 2 == 0 else -0.6)
		rune.position.y = rune.get_meta("rest_y") + sin(_time * 2.0 + i) * 0.008
		var ready: bool = ready_by_root.get(_roots[i], true)
		var glow: float = rune.get_meta("glow")
		glow = lerpf(glow, (0.85 + 0.15 * sin(_time * 5.0 + i)) if ready else DIM, minf(1.0, 8.0 * delta))
		rune.set_meta("glow", glow)
		for material: StandardMaterial3D in rune.get_meta("materials"):
			material.albedo_color.a = glow * 0.75
			material.emission_energy_multiplier = 0.6 + glow * 2.4


func _build(picks: Array) -> void:
	for rune in _runes:
		rune.queue_free()
	_runes.clear()
	_roots = picks.duplicate()
	if picks.is_empty():
		return
	var layout: Array = LAYOUTS.get(picks.size(), LAYOUTS[4])
	var size: float = layout[0]
	var spots: Array = layout[1]
	for i in picks.size():
		var rune := _rune(SkillTreeView.BRANCHES[picks[i]].color, size)
		rune.position = spots[mini(i, spots.size() - 1)]
		rune.set_meta("rest_y", rune.position.y)
		add_child(rune)
		_runes.append(rune)


## A glowing sigil: an outer ring, an inner diamond and four spokes, all in
## the power's color.
func _rune(color: Color, size: float) -> Node3D:
	var rune := Node3D.new()
	var materials := []
	var ring := TorusMesh.new()
	ring.inner_radius = size * 0.82
	ring.outer_radius = size
	ring.rings = 24
	ring.ring_segments = 6
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.rotation.x = PI / 2.0
	ring_node.material_override = _glow(color, materials)
	rune.add_child(ring_node)
	for k in 4:
		var spoke := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(size * 0.08, size * 0.5, size * 0.04)
		spoke.mesh = bar
		spoke.position = Vector3.UP.rotated(Vector3.BACK, k * PI / 2.0) * size * 0.55
		spoke.rotation.z = k * PI / 2.0
		spoke.material_override = _glow(color, materials)
		rune.add_child(spoke)
	var diamond := MeshInstance3D.new()
	var core := BoxMesh.new()
	core.size = Vector3(size * 0.34, size * 0.34, size * 0.04)
	diamond.mesh = core
	diamond.rotation.z = PI / 4.0
	diamond.material_override = _glow(color.lightened(0.3), materials)
	rune.add_child(diamond)
	rune.set_meta("materials", materials)
	rune.set_meta("glow", 1.0)
	return rune


func _glow(color: Color, materials: Array) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.no_depth_test = false
	materials.append(material)
	return material
