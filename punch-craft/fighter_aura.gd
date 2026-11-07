class_name FighterAura
extends Node3D
## The aura a fighter's body wears while their ultimate is ready (2026-11-06,
## the user's idea, from the trailer's key art): glowing eyes in their color,
## their own light, and each fighter's own effect. It lives on the third-person
## body (PlayerBody), so it shows in emotes and in a third-person ultimate;
## the Player turns it on while the meter is full and for the whole shot.
##   Mauler: glowing red eyes, embers rising intensely off him and his gloves.
##   Answer: crackling blue lightning.   Blur: a violet swirl.
##   Stray: a green double swirl.   Tony: gold glints.   Catalyst: rune embers
##   and an orb of fire over his fist.
## flare() makes it burn brighter for a moment (the Inferno crouch).

const STYLE := {
	"berserker": {"eyes": Color(1.0, 0.08, 0.05), "light": Color(1.0, 0.3, 0.08)},
	"counter_master": {"eyes": Color(0.4, 0.88, 1.0), "light": Color(0.3, 0.75, 1.0)},
	"combo_master": {"eyes": Color(0.72, 0.5, 1.0), "light": Color(0.6, 0.4, 1.0)},
	"free_runner": {"eyes": Color(0.35, 1.0, 0.55), "light": Color(0.25, 0.95, 0.45)},
	"wise_guy": {"eyes": Color(1.0, 0.82, 0.3), "light": Color(1.0, 0.75, 0.2)},
	"elementalist": {"eyes": Color(1.0, 0.5, 0.8), "light": Color(1.0, 0.45, 0.25)},
}
const FADE_SPEED := 3.0
const FLARE_DECAY := 1.4
## Where the glove is on the elbow pivot (down the forearm).
const GLOVE := Vector3(0, -0.36, 0)
## And the foot, down the shin.
const FOOT := Vector3(0, -0.4, 0)

var fighter := ""
var _body: PlayerBody
var _eye_material: StandardMaterial3D
var _eyes: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _emitters: Array[CPUParticles3D] = []
var _spinners: Array = []
var _bolts: Array[Node3D] = []
var _bolt_time := 0.0
var _orb: Node3D
var _want := false
var _level := 0.0
var _flare := 0.0
var _rng := RandomNumberGenerator.new()


## Builds the aura on a body whose pivots exist (after it entered the tree).
func setup(body: PlayerBody, id: String) -> void:
	_body = body
	fighter = id
	_rng.seed = hash(id)
	var style: Dictionary = STYLE.get(id, STYLE.berserker)
	visible = false
	body.add_child(self)
	_build_eyes(style.eyes)
	_light = OmniLight3D.new()
	_light.light_color = style.light
	_light.omni_range = 3.2
	_light.light_energy = 0.0
	_light.position = Vector3(0, 1.0, 0.4)
	_light.visible = false
	add_child(_light)
	match id:
		"berserker":
			_embers(self, Vector3(0, 0.95, 0), 0.52, 1.5, 1.0)
			for key in ["le", "re"]:
				if body._joints.has(key):
					_embers(body._joints[key], GLOVE, 0.12, 1.0, 0.42)
		"counter_master":
			for i in 7:
				var bolt := Node3D.new()
				add_child(bolt)
				_bolts.append(bolt)
		"combo_master":
			_swirl(0.5, Color(0.7, 0.45, 1.0), 2.6)
			for key in ["le", "re"]:
				if body._joints.has(key):
					_trail(body._joints[key], Color(0.7, 0.45, 1.0))
		"free_runner":
			_swirl(0.45, Color(0.3, 1.0, 0.5), 3.0)
			_swirl(0.62, Color(0.55, 1.0, 0.7), -2.2)
			# Glowing feet, a neon trail off each heel.
			for key in ["lk", "rk"]:
				if body._joints.has(key):
					_trail(body._joints[key], Color(0.3, 1.0, 0.5), FOOT, 44)
		"wise_guy":
			_glints(Color(1.0, 0.82, 0.3))
		"elementalist":
			_embers(self, Vector3(0, 0.95, 0), 0.5, 1.3, 0.8, Color(1.0, 0.5, 0.8))
			_make_orb(body)
	for emitter in _emitters:
		emitter.emitting = false


## On while the fighter's ultimate is ready (or its shot is playing).
func set_on(on: bool) -> void:
	_want = on


## A moment of burning brighter.
func flare(amount := 1.0) -> void:
	_flare = maxf(_flare, amount)


func _process(delta: float) -> void:
	_level = move_toward(_level, 1.0 if _want else 0.0, delta * FADE_SPEED)
	_flare = maxf(0.0, _flare - delta * FLARE_DECAY)
	var shown := _level > 0.01
	if shown != visible:
		visible = shown
		for emitter in _emitters:
			emitter.emitting = shown and _want
	if not shown:
		return
	var boost := 1.0 + _flare
	if _eye_material:
		_eye_material.emission_energy_multiplier = 6.0 * _level * boost
	if _light:
		_light.visible = true
		_light.light_energy = 1.3 * _level * (1.0 + _flare * 1.0)
	for emitter in _emitters:
		emitter.emitting = _want
		emitter.speed_scale = 1.0 + _flare * 1.1
	for node: Node3D in _spinners:
		node.rotate_y(float(node.get_meta("spin")) * delta)
	if _orb:
		_orb.rotate_y(delta * 2.0)
		_orb.rotate_x(delta * 1.3)
		_orb.scale = Vector3.ONE * (1.0 + _flare * 0.4) * (0.94 + 0.06 * sin(Time.get_ticks_msec() * 0.012))
	if not _bolts.is_empty():
		_bolt_time -= delta
		if _bolt_time <= 0.0:
			_bolt_time = 0.09
			_rebuild_bolts()


# --- Pieces ------------------------------------------------------------------------

## Eyes glowing in the fighter's color, over the face's eye cubes.
func _build_eyes(color: Color) -> void:
	if not _body._joints.has("head") or not "_v" in _body:
		return
	var v: float = _body._v
	# Just in front of the face plane (the face cells end at the outer cube edge).
	var front := -(floorf(0.15 / v - 0.5) + 1.0) * v - 0.006
	_eye_material = StandardMaterial3D.new()
	_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_material.albedo_color = color
	_eye_material.emission_enabled = true
	_eye_material.emission = color
	_eye_material.emission_energy_multiplier = 0.0
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0 * v, v, 0.008)
		mesh.material = _eye_material
		eye.mesh = mesh
		eye.position = Vector3(2.0 * v * side, 5.5 * v, front)
		_body._joints.head.add_child(eye)
		_eyes.append(eye)
		eye.visible = true


## A cube mesh for particles: bright, see-through, added to the light.
static func _cube(size: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = material
	return mesh


func _share() -> float:
	return 0.6 if Settings.use_web_profile() else 1.0


func _particles(parent: Node3D, at: Vector3, amount: int, life: float, size: float, colors: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(4, roundi(amount * _share()))
	p.lifetime = life
	p.mesh = _cube(size)
	p.local_coords = false
	p.position = at
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(colors)
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / float(colors.size() - 1))
	ramp.offsets = offsets
	p.color_ramp = ramp
	parent.add_child(p)
	_emitters.append(p)
	return p


## Embers rising off a spot (the Mauler: intense, off his body and gloves).
func _embers(parent: Node3D, at: Vector3, radius: float, life: float, rate: float, tint := Color(1.0, 0.5, 0.1)) -> void:
	var p := _particles(parent, at, roundi(90.0 * rate), life, 0.045, [Color(1.0, 0.95, 0.5, 0.0), Color(1.0, 0.85, 0.3, 1.0), tint, Color(0.9, 0.2, 0.05, 0.0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 22.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.9
	p.gravity = Vector3(0, 0.7, 0)


## A spinning ring of sparks climbing the body (the node turns, so they curl).
func _swirl(radius: float, color: Color, spin: float) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0, 0.1, 0)
	holder.set_meta("spin", spin)
	add_child(holder)
	_spinners.append(holder)
	var p := _particles(holder, Vector3.ZERO, 46, 1.3, 0.04, [Color(color, 0.0), Color(color.lightened(0.3), 1.0), Color(color, 0.0)])
	p.local_coords = true
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.9
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 4.0
	p.initial_velocity_min = 0.9
	p.initial_velocity_max = 1.3
	p.gravity = Vector3.ZERO


## A fading trail off a glove.
func _trail(parent: Node3D, color: Color, at := GLOVE, amount := 24) -> void:
	var p := _particles(parent, at, amount, 0.5, 0.05, [Color(color.lightened(0.4), 0.0), Color(color.lightened(0.2), 0.9), Color(color, 0.0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.gravity = Vector3.ZERO


## Gold glints twinkling round Tony.
func _glints(color: Color) -> void:
	var p := _particles(self, Vector3(0, 1.0, 0), 18, 0.9, 0.035, [Color(color, 0.0), Color(color.lightened(0.4), 1.0), Color(color, 0.0)])
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.75
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0, 0.1, 0)


## The Catalyst's orb of fire over his right fist.
func _make_orb(body: PlayerBody) -> void:
	if not body._joints.has("re"):
		return
	_orb = Node3D.new()
	_orb.position = GLOVE + Vector3(0, -0.16, 0)
	body._joints.re.add_child(_orb)
	for layer: Array in [[0.16, Color(1.0, 0.35, 0.06)], [0.1, Color(1.0, 0.65, 0.2)], [0.05, Color(1.0, 0.95, 0.65)]]:
		var cube := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * float(layer[0])
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = layer[1]
		material.emission_enabled = true
		material.emission = layer[1]
		material.emission_energy_multiplier = 4.0
		mesh.material = material
		cube.mesh = mesh
		_orb.add_child(cube)


## The Answer's bolts: jagged lines of thin cubes, redrawn a dozen times a second.
func _rebuild_bolts() -> void:
	for bolt in _bolts:
		for child in bolt.get_children():
			child.queue_free()
		var angle := _rng.randf() * TAU
		var point := Vector3(cos(angle) * 0.3, _rng.randf_range(0.5, 1.5), sin(angle) * 0.25)
		var heading := Vector3(cos(angle), _rng.randf_range(-0.2, 0.7), sin(angle) * 0.6).normalized()
		for step in 5:
			var turn := Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.6, 0.6))
			var next := point + (heading + turn).normalized() * _rng.randf_range(0.12, 0.22)
			bolt.add_child(_segment(point, next))
			point = next


static var _bolt_material: StandardMaterial3D


func _segment(from: Vector3, to: Vector3) -> MeshInstance3D:
	if _bolt_material == null:
		_bolt_material = StandardMaterial3D.new()
		_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bolt_material.albedo_color = Color(0.75, 0.95, 1.0)
		_bolt_material.emission_enabled = true
		_bolt_material.emission = Color(0.5, 0.85, 1.0)
		_bolt_material.emission_energy_multiplier = 7.0
	var length := from.distance_to(to)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.025, length)
	mesh.material = _bolt_material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (from + to) / 2.0
	node.transform = Transform3D(Basis.looking_at(to - from, Vector3.UP), (from + to) / 2.0)
	return node
