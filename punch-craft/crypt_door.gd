class_name CryptDoor
extends Node3D
## The Crypt's entrance: a small stone crypt with a glowing doorway behind an
## iron gate and a purple beam into the sky. It stands in the graveyard behind
## camp once the Bellman's seal is broken (CampBackdrop); rise() plays it
## pushing up out of the earth, open() lifts the gate.

const GLOW := Color(0.6, 0.3, 1.0)
const SUNK := -5.2

var _gate: Node3D
var _light: OmniLight3D
var _beam: MeshInstance3D
var _time := 0.0


func _init() -> void:
	var stone := Enemy._material(Color(0.3, 0.29, 0.33))
	var dark := Enemy._material(Color(0.15, 0.14, 0.17))
	_part(self, Enemy._box(Vector3(4.2, 0.3, 3.2)), dark, Vector3(0, 0.15, 0))
	_part(self, Enemy._box(Vector3(3.6, 2.8, 2.4)), stone, Vector3(0, 1.7, -0.2))
	for x in [-1.45, 1.45]:
		_part(self, Enemy._cylinder(0.22, 3.0), stone, Vector3(x, 1.8, 1.15))
	_part(self, Enemy._box(Vector3(3.8, 0.35, 0.8)), stone, Vector3(0, 3.45, 1.05))
	var roof := PrismMesh.new()
	roof.size = Vector3(4.0, 1.1, 3.0)
	_part(self, roof, dark, Vector3(0, 4.15, -0.1))
	# The doorway glows behind an iron gate.
	_part(self, Enemy._box(Vector3(1.6, 2.3, 0.05)), Enemy._glow_material(GLOW), Vector3(0, 1.45, 1.0))
	_gate = Node3D.new()
	add_child(_gate)
	var iron := Enemy._material(Color(0.08, 0.08, 0.09), 0.7)
	for i in 6:
		_part(_gate, Enemy._box(Vector3(0.06, 2.3, 0.06)), iron, Vector3(-0.65 + i * 0.26, 1.45, 1.08))
	_part(_gate, Enemy._box(Vector3(1.7, 0.08, 0.08)), iron, Vector3(0, 2.2, 1.08))
	_part(_gate, Enemy._box(Vector3(1.7, 0.08, 0.08)), iron, Vector3(0, 0.7, 1.08))
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 3.0
	_light.omni_range = 9.0
	_light.position = Vector3(0, 1.6, 2.2)
	add_child(_light)
	# A beam of light into the sky that shows through the fog.
	var beam := CylinderMesh.new()
	beam.top_radius = 1.4
	beam.bottom_radius = 0.7
	beam.height = 60.0
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.albedo_color = Color(GLOW, 0.14)
	beam_material.set("disable_fog", true)
	_beam = _part(self, beam, beam_material, Vector3(0, 30.0, 0))
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = (3.0 + sin(_time * 3.3) * 0.8) * (1.4 if _gate.position.y > 1.0 else 1.0)


## Standing, gate open: how it looks once the Crypt is open.
func show_open() -> void:
	position.y = 0.0
	_gate.position.y = 2.4
	_light.omni_range = 14.0


## Sunk out of sight, waiting to rise.
func hide_sunk() -> void:
	position.y = SUNK
	_beam.visible = false


## Pushes up out of the earth over `seconds`.
func rise(seconds: float) -> Tween:
	_beam.visible = false
	var tween := create_tween()
	tween.tween_property(self, "position:y", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## Lifts the gate and lights the beam.
func open() -> Tween:
	_beam.visible = true
	_light.omni_range = 14.0
	var tween := create_tween()
	tween.tween_property(_gate, "position:y", 2.4, 1.2).set_trans(Tween.TRANS_SINE)
	return tween


func _part(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3) -> MeshInstance3D:
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	parent.add_child(part)
	return part
