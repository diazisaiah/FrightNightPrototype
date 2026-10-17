class_name PlayerBody
extends Node3D
## The player's own fighter, head to toe: seen only when the camera pulls out
## to third person for an emote (Emotes). Built from voxel blocks like the
## enemies, dressed after each fighter's card (the Mauler's red trunks, the
## Blur's violet sash, the Answer's white belt, the Stray's red headband, Tony's
## tracksuit), wearing the hat picked on the Hat Rack (GameState.worn_hat).
## Joints are pivots (see Emotes for which way they turn). Faces -Z.

## [skin, top, sleeves, pants, belt, shoes, gloves, cuffs, hair, eyes (glow, or
## black for none), bulk (width scale)].
const LOOKS := {
	"berserker": {"top": "skin", "sleeve": "skin", "pants": Color(0.62, 0.07, 0.06), "belt": Color(0.92, 0.9, 0.85),
		"shins": "skin", "shoes": Color(0.5, 0.06, 0.05), "glove": Color(0.66, 0.07, 0.06), "cuff": Color(0.92, 0.89, 0.82),
		"hair": Color(0.1, 0.08, 0.08), "eyes": Color(1.0, 0.45, 0.1), "bulk": 1.18},
	"combo_master": {"top": Color(0.1, 0.1, 0.17), "sleeve": Color(0.1, 0.1, 0.17), "pants": Color(0.08, 0.08, 0.12),
		"belt": Color(0.5, 0.3, 0.88), "shoes": Color(0.06, 0.06, 0.08), "glove": Color(0.12, 0.1, 0.16),
		"cuff": Color(0.85, 0.8, 0.7), "hair": Color(0.06, 0.05, 0.07), "eyes": Color(0.7, 0.45, 1.0), "bulk": 0.95},
	"counter_master": {"top": Color(0.07, 0.07, 0.09), "sleeve": Color(0.07, 0.07, 0.09), "pants": Color(0.07, 0.07, 0.09),
		"belt": Color(0.88, 0.88, 0.9), "shoes": Color(0.05, 0.05, 0.06), "glove": Color(0.16, 0.38, 0.88),
		"cuff": Color(0.06, 0.1, 0.22), "hair": Color(0.05, 0.05, 0.06), "eyes": Color(0.45, 0.85, 1.0), "bulk": 1.0},
	"free_runner": {"top": Color(0.13, 0.13, 0.15), "sleeve": "skin", "pants": Color(0.1, 0.1, 0.12),
		"belt": Color(0.2, 0.75, 0.35), "shoes": Color(0.08, 0.08, 0.09), "glove": Color(0.82, 0.8, 0.76),
		"cuff": Color(0.82, 0.8, 0.76), "hair": Color(0.06, 0.05, 0.05), "eyes": Color(0.35, 1.0, 0.45), "bulk": 0.95},
	"wise_guy": {"top": Color(0.07, 0.07, 0.08), "sleeve": Color(0.07, 0.07, 0.08), "pants": Color(0.07, 0.07, 0.08),
		"belt": Color(0.07, 0.07, 0.08), "shoes": Color(0.92, 0.92, 0.9), "glove": Color(0.9, 0.88, 0.84),
		"cuff": Color(0.9, 0.88, 0.84), "hair": Color(0.07, 0.07, 0.08), "eyes": Color.BLACK, "bulk": 1.08},
}
const HEAD := 0.3
## The body renders on its own layer: the lantern at your eyes would blow it
## out from inside the head, so a soft fill on the emote camera lights it.
const LAYER := 1 << 9
## Eases between poses as a dance starts and stops.
const BLEND_TIME := 0.18

var fighter := ""
var _look := {}
var _skin := Color()
var _joints := {}
var _hat: Node3D
## Things that sit on top of the head (hair, beanie): a hat goes above them.
var _crown := 0.0
var _beanie: Node3D

var _keys: Array = []
var _key := 0
var _key_time := 0.0
var _from := {}
var _playing := ""
## The current key's length when it isn't its own (easing into a dance).
var _blend := -1.0


func _init(class_id := "") -> void:
	fighter = class_id


func _ready() -> void:
	if fighter == "":
		fighter = GameState.player_class
	_look = LOOKS.get(fighter, LOOKS.counter_master)
	_skin = Fists.SKIN.get(fighter, Fists.DEFAULT_SKIN)
	scale = Vector3.ONE * 0.92
	_build()
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


func _set_joint(joint: String, value: Vector3) -> void:
	if joint == "pos":
		_joints.hips.position = Vector3(0, _hip_height(), 0) + value
	elif _joints.has(joint):
		_joints[joint].rotation = value


func _get_joint(joint: String) -> Vector3:
	if joint == "pos":
		return _joints.hips.position - Vector3(0, _hip_height(), 0)
	return _joints[joint].rotation


func _hip_height() -> float:
	return 0.9


# --- The hat ------------------------------------------------------------------------

## Puts on a hat from the collection ("" for none).
func wear_hat(id: String) -> void:
	if _hat and is_instance_valid(_hat):
		_hat.queue_free()
	_hat = null
	if _beanie:
		_beanie.visible = id == ""
	if id == "" or not Hats.CATALOG.has(id):
		return
	var u := HEAD * _bulk() * Hats.SIZE * (Hats.FRUIT_SIZE if id == "fruit_hat" else 1.0)
	_hat = Hats.build(id, u)
	_hat.position = Vector3(0, HEAD + (0.0 if fighter == "wise_guy" else _crown), 0)
	_joints.head.add_child(_hat)
	_set_layer(_hat)
	var spin := _hat.get_node_or_null("Spin")
	if spin:
		spin.create_tween().set_loops().tween_property(spin, "rotation:y", TAU, 0.6).from(0.0)
	if Hats.info(id).rarity == "legendary":
		Hats.sparkles(_hat, Hats.color(id), 0.25)


# --- Building -----------------------------------------------------------------------

func _bulk() -> float:
	return float(_look.get("bulk", 1.0))


func _color(key: String) -> Color:
	var value = _look.get(key, Color.WHITE)
	return _skin if value is String else value


func _build() -> void:
	var b := _bulk()
	var hips := _pivot("hips", self, Vector3(0, _hip_height(), 0))
	# Legs.
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var hip := _pivot(key + "h", hips, Vector3(0.1 * b * side, 0.0, 0))
		_box(hip, Vector3(0.16 * b, 0.46, 0.18 * b), _color("pants"), Vector3(0, -0.22, 0))
		var knee := _pivot(key + "k", hip, Vector3(0, -0.44, 0))
		_box(knee, Vector3(0.14 * b, 0.4, 0.16 * b), _color("shins" if _look.has("shins") else "pants"), Vector3(0, -0.2, 0))
		_box(knee, Vector3(0.15 * b, 0.09, 0.26), _color("shoes"), Vector3(0, -0.41, -0.04))
		if fighter == "wise_guy":
			_box(hip, Vector3(0.02, 0.46, 0.04), Color(0.92, 0.92, 0.9), Vector3(0.081 * b * side, -0.22, 0))
			_box(knee, Vector3(0.02, 0.38, 0.04), Color(0.92, 0.92, 0.9), Vector3(0.071 * b * side, -0.2, 0))
	_box(hips, Vector3(0.38 * b, 0.16, 0.22 * b), _color("pants"), Vector3(0, 0.04, 0))
	# Torso.
	var torso := _pivot("torso", hips, Vector3(0, 0.1, 0))
	_box(torso, Vector3(0.44 * b, 0.5, 0.25 * b), _color("top"), Vector3(0, 0.3, 0))
	_box(torso, Vector3(0.45 * b, 0.07, 0.26 * b), _color("belt"), Vector3(0, 0.05, 0))
	_dress_torso(torso, b)
	# Head.
	var head := _pivot("head", torso, Vector3(0, 0.57, 0))
	_box(head, Vector3(0.1, 0.06, 0.1), _skin, Vector3(0, 0.02, 0))
	_box(head, Vector3(HEAD * b, HEAD, HEAD), _skin, Vector3(0, HEAD * 0.5 + 0.04, 0))
	_face(head, b)
	_hair(head, b)
	# Arms.
	for side in [-1.0, 1.0]:
		var key := "l" if side < 0 else "r"
		var shoulder := _pivot(key + "s", torso, Vector3((0.22 * b + 0.07) * side, 0.49, 0))
		_box(shoulder, Vector3(0.13 * b, 0.32, 0.14 * b), _color("sleeve"), Vector3(0, -0.14, 0))
		var elbow := _pivot(key + "e", shoulder, Vector3(0, -0.29, 0))
		_box(elbow, Vector3(0.12 * b, 0.24, 0.13 * b), _color("sleeve"), Vector3(0, -0.11, 0))
		_box(elbow, Vector3(0.14 * b, 0.07, 0.15 * b), _color("cuff"), Vector3(0, -0.24, 0))
		var glove := 0.17 if fighter in ["berserker", "counter_master", "combo_master"] else 0.13
		_box(elbow, Vector3(glove * b, glove + 0.01, glove * b + 0.02), _color("glove"), Vector3(0, -0.24 - glove * 0.5 - 0.02, -0.01))
		if fighter == "wise_guy":
			_box(shoulder, Vector3(0.02, 0.32, 0.04), Color(0.92, 0.92, 0.9), Vector3(0.066 * b * side, -0.14, 0))
			_box(elbow, Vector3(0.02, 0.2, 0.04), Color(0.92, 0.92, 0.9), Vector3(0.061 * b * side, -0.1, 0))
			if side < 0:
				_box(elbow, Vector3(0.03, 0.03, 0.03), Color(1.0, 0.78, 0.22), Vector3(-0.04, -0.37, -0.05), Vector3.ZERO, true)


func _dress_torso(torso: Node3D, b: float) -> void:
	var front := -0.125 * b - 0.006
	match fighter:
		"berserker":
			# Pecs and abs on the bare chest.
			var shade := _skin.darkened(0.12)
			_box(torso, Vector3(0.18, 0.12, 0.02), shade, Vector3(-0.1, 0.42, front))
			_box(torso, Vector3(0.18, 0.12, 0.02), shade, Vector3(0.1, 0.42, front))
			for row in 2:
				_box(torso, Vector3(0.18, 0.07, 0.02), shade, Vector3(0, 0.24 - row * 0.09, front))
		"combo_master":
			# A sash knotted at the hip, tails hanging.
			_box(torso, Vector3(0.07, 0.2, 0.03), _color("belt"), Vector3(0.14, -0.06, front), Vector3(0, 0, 0.2))
			_box(torso, Vector3(0.12, 0.14, 0.03), _color("top").lightened(0.08), Vector3(0, 0.5, front))
		"counter_master":
			# The jacket's crossed lapels.
			_box(torso, Vector3(0.05, 0.42, 0.02), Color(0.2, 0.2, 0.24), Vector3(-0.05, 0.32, front), Vector3(0, 0, -0.35))
			_box(torso, Vector3(0.05, 0.42, 0.02), Color(0.2, 0.2, 0.24), Vector3(0.05, 0.32, front), Vector3(0, 0, 0.35))
		"free_runner":
			_box(torso, Vector3(0.08, 0.24, 0.03), _color("belt"), Vector3(-0.15, -0.08, front), Vector3(0, 0, -0.15))
		"wise_guy":
			# White tee in the open zip, white stripes down the front, the gold chain.
			_box(torso, Vector3(0.14, 0.2, 0.02), Color(0.92, 0.92, 0.9), Vector3(0, 0.44, front))
			_box(torso, Vector3(0.02, 0.36, 0.02), Color(0.92, 0.92, 0.9), Vector3(0, 0.2, front - 0.002))
			for i in 7:
				var a := -0.9 + i * 0.3
				_box(torso, Vector3(0.035, 0.035, 0.03), Color(1.0, 0.78, 0.22), Vector3(sin(a) * 0.09, 0.53 - cos(a) * 0.09 + 0.06, front - 0.01), Vector3.ZERO, true)


func _face(head: Node3D, b: float) -> void:
	var front := -HEAD * 0.5 - 0.006
	var y := HEAD * 0.5 + 0.06
	var eyes: Color = _look.eyes
	for side in [-1.0, 1.0]:
		if eyes == Color.BLACK:
			_box(head, Vector3(0.05, 0.035, 0.02), Color(0.08, 0.06, 0.05), Vector3(0.065 * side, y, front))
			_box(head, Vector3(0.08, 0.025, 0.02), Color(0.1, 0.07, 0.05), Vector3(0.065 * side, y + 0.045, front))  # Brows.
		else:
			_box(head, Vector3(0.07, 0.04, 0.02), Color(0.03, 0.03, 0.04), Vector3(0.065 * side, y, front))
			_box(head, Vector3(0.05, 0.03, 0.02), eyes, Vector3(0.065 * side, y, front - 0.004), Vector3.ZERO, true)
	match fighter:
		"wise_guy":
			_box(head, Vector3(0.06, 0.06, 0.04), Color(0.85, 0.35, 0.3), Vector3(0, y - 0.05, front - 0.01))  # The nose.
			_box(head, Vector3(HEAD * b - 0.02, 0.09, 0.02), _skin.darkened(0.3), Vector3(0, 0.1, front))  # Stubble.
		"berserker":
			_box(head, Vector3(0.12, 0.025, 0.02), Color(0.2, 0.08, 0.06), Vector3(0, 0.1, front))  # A scowl.


func _hair(head: Node3D, b: float) -> void:
	var hair := _color("hair")
	var top := HEAD + 0.04
	match fighter:
		"berserker":
			_box(head, Vector3(HEAD * b + 0.01, 0.05, HEAD + 0.01), hair, Vector3(0, top, 0.01))
			_crown = 0.03
		"combo_master":
			_box(head, Vector3(HEAD * b + 0.02, 0.07, HEAD + 0.02), hair, Vector3(0, top, 0.01))
			for i in 6:
				var x := -0.11 + (i % 3) * 0.11
				var z := -0.07 if i < 3 else 0.07
				_box(head, Vector3(0.08, 0.12, 0.08), hair, Vector3(x, top + 0.07, z), Vector3(0.3 * signf(z), 0, -x * 2.5))
			_crown = 0.12
		"counter_master":
			_box(head, Vector3(HEAD * b + 0.02, 0.06, HEAD + 0.02), hair, Vector3(0, top, 0.01))
			_box(head, Vector3(HEAD * b + 0.02, 0.06, 0.04), hair, Vector3(0, top - 0.05, -HEAD * 0.5 - 0.01))
			_crown = 0.04
		"free_runner":
			# A big mop of locs, and the red headband with its tails.
			for x in [-1, 0, 1]:
				for z in [-1, 0, 1]:
					_box(head, Vector3(0.14, 0.12, 0.14), hair, Vector3(x * 0.12, top + 0.05 + (0.03 if x == 0 and z == 0 else 0.0), z * 0.12))
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.06, 0.18, 0.12), hair, Vector3(0.18 * side, top - 0.1, 0.06))
			var red := Color(0.75, 0.08, 0.08)
			_box(head, Vector3(HEAD * b + 0.03, 0.05, HEAD + 0.03), red, Vector3(0, top - 0.06, 0))
			_box(head, Vector3(0.04, 0.2, 0.03), red, Vector3(-0.04, top - 0.16, HEAD * 0.5 + 0.03), Vector3(0.6, 0, 0.2))
			_box(head, Vector3(0.04, 0.24, 0.03), red, Vector3(0.04, top - 0.18, HEAD * 0.5 + 0.04), Vector3(0.7, 0, -0.15))
			_crown = 0.14
		"wise_guy":
			_box(head, Vector3(HEAD * b + 0.02, 0.05, HEAD + 0.02), hair, Vector3(0, top - 0.06, 0.02))
			_beanie = Node3D.new()
			head.add_child(_beanie)
			_box(_beanie, Vector3(HEAD * b + 0.04, 0.12, HEAD + 0.04), Color(0.08, 0.08, 0.09), Vector3(0, top + 0.01, 0))
			_box(_beanie, Vector3(HEAD * b + 0.05, 0.05, HEAD + 0.05), Color(0.12, 0.12, 0.13), Vector3(0, top - 0.04, 0))


func _pivot(id: String, parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = id
	pivot.position = pos
	parent.add_child(pivot)
	_joints[id] = pivot
	return pivot


## One block of the body, voxelized like the enemies' parts (glowing ones stay smooth).
func _box(parent: Node3D, size: Vector3, tint: Color, pos: Vector3, rot := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = Enemy._glow_material(tint) if glow else Look.block_material(tint)
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	if not glow:
		var voxels := Voxel.voxelize(mesh, material)
		if voxels:
			part.mesh = voxels
	part.position = pos
	part.rotation = rot
	part.layers = LAYER
	parent.add_child(part)
	return part


func _set_layer(node: Node) -> void:
	if node is VisualInstance3D:
		node.layers = LAYER
	for child in node.get_children():
		_set_layer(child)
