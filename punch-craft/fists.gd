class_name Fists
extends Node3D
## First-person arms, built as voxel models (thousands of small cubes, drawn
## with one MultiMesh per material) and animated with tweens. Each arm pivots
## at the elbow, so poses rotate the whole forearm. Every fighter has their own
## hands (see _paint_*): gloves, finger and forearm wraps, sleeves, skin. When
## the ultimate is ready their hands glow with the fighter's effect.
## The player calls play_punch(), set_hurt() and set_power_state().

const HURT_COLOR := Color(0.7, 0.1, 0.08)
## Size of one voxel, in meters.
## Voxel size (2026-10-25: was 0.0085; finer, so wraps show every turn and
## fingers their joints and nails).
const VOXEL := 0.0045
## The hands render on their own layer, lit by their own soft light (the
## player's lantern sits right beside them and would wash them out).
const HAND_LAYER := 2
## Where the fist sits along the arm (local), for effects.
const FIST_POINT := Vector3(0, 0.0, -0.34)

## The hand rig (2026-10-24): every finger is three jointed segments and the
## thumb two, pivoting at the knuckles, so hands can open, point, cup and flick
## (hand idles). Closed, they fold into the fist (punches look as before).
## Painted for the right hand (the left mirrors it): +y is the back of the
## hand, -z points out past the knuckles. The Mauler's gloves are mittens: the
## padded front bends as one piece, and the thumb.
const FINGER_X := [-0.034, -0.0113, 0.0114, 0.034]
const FINGER_LENGTH := [1.0, 1.08, 1.0, 0.82]
const KNUCKLE := Vector2(0.008, -0.362)
const PHALANX := [0.03, 0.024, 0.02]
const FINGER_SIZE := Vector2(0.0162, 0.02)
const CURL_CLOSED := [-1.35, -1.45, -1.0]
const CURL_OPEN := [-0.06, -0.1, -0.05]
## Fingers fan out this far (yaw) on an open hand, index to pinky.
const SPREAD := [0.2, 0.07, -0.07, -0.24]
const THUMB_PIVOT := Vector3(-0.044, -0.016, -0.33)
const THUMB_LENGTH := [0.05, 0.035]
const THUMB_SIZE := Vector2(0.024, 0.022)
const THUMB_CLOSED := [Vector3(-0.39, 0.0, 0.0), Vector3(0.0, -1.4, 0.0)]
const THUMB_OPEN := [Vector3(-0.15, 0.55, 0.0), Vector3(0.0, 0.15, 0.0)]
const THUMB_UP := [Vector3(0.75, 0.25, 0.0), Vector3(0.15, 0.0, 0.0)]
const MITTEN_PIVOT := Vector3(0.0, 0.03, -0.37)
const MITTEN_OPEN := Vector3(0.6, 0.0, 0.0)
const MITTEN_THUMB_PIVOT := Vector3(-0.06, -0.02, -0.31)
const MITTEN_THUMB_OPEN := Vector3(0.0, 0.55, 0.0)
## Hands touch instead of passing through: spheres (arm space) per hand.
const CONTACT := [[Vector3(0, 0.0, -0.32), 0.042], [Vector3(0, 0.0, -0.37), 0.04]]
const CONTACT_GLOVE := [[Vector3(0, 0.0, -0.32), 0.066], [Vector3(0, 0.0, -0.39), 0.064]]
const CONTACT_TIPS := [Vector3(0, 0.0, -0.43), 0.03]
const SKIN := {
	"berserker": Color(0.56, 0.42, 0.35), "combo_master": Color(0.8, 0.6, 0.45),
	"counter_master": Color(0.55, 0.38, 0.29), "free_runner": Color(0.5, 0.34, 0.24),
	"wise_guy": Color(0.86, 0.64, 0.5),
	"elementalist": Color(0.74, 0.55, 0.43),
}
const DEFAULT_SKIN := Color(0.85, 0.62, 0.48)
const ACCENT := {
	"berserker": Color(1.0, 0.42, 0.12), "combo_master": Color(0.6, 0.4, 1.0),
	"counter_master": Color(0.35, 0.75, 1.0), "free_runner": Color(0.3, 1.0, 0.45),
	"wise_guy": Color(1.0, 0.75, 0.2),
	"elementalist": Color(0.95, 0.4, 0.7),
}
## The Catalyst's runes glow in his powers' colors (his picks; all of them
## under Prism, taking turns).
const POWER_COLORS := {
	"sigil_fire": Color(1.0, 0.45, 0.1), "sigil_frost": Color(0.55, 0.85, 1.0),
	"sigil_storm": Color(0.65, 0.45, 1.0), "sigil_blood": Color(0.95, 0.1, 0.15),
}

## Elbow position and rotation of the right arm at rest. The left arm mirrors it.
## Rotation is (pitch, yaw, roll): pitch tilts the forearm up, yaw swings it
## inward, roll twists the fist around the forearm.
const REST_POS := Vector3(0.24, -0.36, -0.1)
const REST_ROT := Vector3(0.5, 0.18, -0.5)

# Offsets from rest for the right arm (left arm uses the mirrored pose).
const POSES := {
	"jab": {
		"windup_pos": Vector3(0, -0.01, 0.05), "windup_rot": Vector3.ZERO,
		"strike_pos": Vector3(-0.12, 0.26, -0.32), "strike_rot": Vector3(-0.4, 0.15, 0.5),
	},
	"cross": {
		"windup_pos": Vector3(0.02, -0.02, 0.07), "windup_rot": Vector3(0, -0.1, 0),
		"strike_pos": Vector3(-0.16, 0.26, -0.34), "strike_rot": Vector3(-0.4, 0.25, 0.5),
	},
	# Elbow comes up and out, forearm sweeps across horizontally.
	"hook": {
		"windup_pos": Vector3(0.1, 0.04, 0.08), "windup_rot": Vector3(-0.1, -0.35, 0.2),
		"strike_pos": Vector3(0.04, 0.26, -0.3), "strike_rot": Vector3(-0.45, 1.3, -0.1),
	},
	# Elbow drops so the forearm points straight up, then the fist drives upward.
	"uppercut": {
		"windup_pos": Vector3(-0.02, -0.16, -0.12), "windup_rot": Vector3(0.6, 0.1, -1.1),
		"strike_pos": Vector3(-0.12, 0.12, -0.38), "strike_rot": Vector3(0.6, 0.2, -1.1),
	},
}

## 0 = standing still, 1 = sprinting. Drives the idle/walk bob.
var move_amount := 0.0
## Whose hands these are (a class id). Empty: the current class.
var fighter := ""
## The skin to wear (Skins): "auto" for the fighter's pick, "" for their own look.
var skin_id := "auto"
var _pal := {}

var _bob_time := 0.0
var _flinch_offset := Vector3.ZERO
## How far the arms have dropped out of view (a knockout).
var drop := 0.0
var _arms := {}
var _tweens := {}
## The rig: bone -> {parent, offset, closed, open}, and per hand the bone nodes.
var _rig := {}
var _bones := {"left": {}, "right": {}}
## Arms already built this session, per fighter, skin and side: the rig, and
## the meshes of the arm ("") and of each bone, as [[group, MultiMesh], ...].
## Built once; every other pair of these hands reuses them.
static var _cache := {}
## The meshes of the arm being built (as in _cache).
var _meshes := {}
## Tapers are painted as shells SHELL voxels thick; their hidden cores are
## kept as rectangles per z cell (z -> [Rect2i, ...]) and count as filled.
const SHELL := 3
var _cores := {}
## Voxels painted per bone (local cells): bone -> {Vector3i: [Color, group]}.
var _bone_cells := {}
## Voxels moved onto a bone (local positions): bone -> [[Vector3, Color, group]].
var _bone_extra := {}
## Each hand's shape right now (Shapes: f, f0-f3, t, tu, spread).
var _shape := {"left": {}, "right": {}}
var _accent := Color.WHITE
var _skin_color := DEFAULT_SKIN
## Voxels being painted for the arm under construction: Vector3i -> [Color, group].
var _grid := {}
## Shared materials: "skin" takes the hurt tint, "rim" glows when the
## ultimate is ready, "gear" is everything else.
var _materials := {}
## Per hand: glow effects (particles, light, animated bits).
var _fx := {}
var _ability_ready := false
var _ult_ready := false
## The Catalyst's runes flaring as a power or spell goes off: {side: [color, seconds left]}.
var _rune_flash := {}
const RUNE_FLASH := 0.45
var _hot_hand := ""
var _time := 0.0
var _bolt_timer := 0.0


func _ready() -> void:
	if fighter == "":
		fighter = GameState.player_class
	if skin_id == "auto":
		skin_id = GameState.skin(fighter)
	_pal = Skins.palette(fighter, skin_id)
	_accent = _pal.get("glow", ACCENT.get(fighter, Color(1.0, 0.8, 0.4)))
	_skin_color = SKIN.get(fighter, DEFAULT_SKIN)
	for group in ["skin", "gear", "rim", "rune_left", "rune_right"]:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.roughness = 0.8
		if group in ["rim", "rune_left", "rune_right"]:
			material.emission_enabled = true
			material.emission = _accent
			material.emission_energy_multiplier = 0.0
		_materials[group] = material
	_arms["left"] = _build_arm(-1.0)
	_arms["right"] = _build_arm(1.0)
	var fill := OmniLight3D.new()
	fill.light_cull_mask = HAND_LAYER
	fill.light_color = Color(1.0, 0.92, 0.85)
	# Off to the side and a little behind, so the wraps' turns and the
	# fingers catch light on one side and shade on the other.
	fill.light_energy = 0.55
	fill.omni_range = 2.0
	fill.position = Vector3(0.35, 0.3, 0.05)
	add_child(fill)
	set_hurt(0.0)


## Builds a fighter's hands ahead of time (behind the loading screen), so
## the pair in the next scene appears at once (_cache).
static func warm(tree: SceneTree, class_id: String) -> void:
	var fists := Fists.new()
	fists.fighter = class_id
	fists.silent = true
	fists.visible = false
	tree.root.add_child(fists)
	fists.queue_free()


func _process(delta: float) -> void:
	_time += delta
	_bob_time += delta * lerpf(1.5, 10.0, move_amount)
	var amplitude := lerpf(0.004, 0.02, move_amount)
	_flinch_offset = _flinch_offset.move_toward(Vector3.ZERO, 0.6 * delta)
	position = Vector3(cos(_bob_time * 0.5) * amplitude, sin(_bob_time) * amplitude, 0) + _flinch_offset + Vector3(0, -drop, drop * 0.3)
	_update_effects(delta)
	if idle_playing:
		_run_idle(delta)
	elif _closing:
		# Fingers ease back into fists after an idle is cut off.
		var fist := IdleAnims.shape("fist")
		var done := true
		for hand in ["left", "right"]:
			var shape := IdleAnims.blend(_shape[hand], fist, minf(1.0, 14.0 * delta))
			_apply_shape(hand, shape)
			if float(shape.get("f", 1.0)) < 0.99 or float(shape.get("t", 1.0)) < 0.99:
				done = false
		_closing = not done
	if is_instance_valid(_idle_prop) and _idle_prop.visible:
		_idle_prop.rotation.x += delta * 14.0 if _idle_prop.get_child_count() == 1 else 0.0
		_idle_prop.rotation.y += delta * 3.0


## Knocks both fists down and back when the player takes a clean hit.
func flinch() -> void:
	_flinch_offset = Vector3(0, -0.08, 0.1)


## What the fighter's hands should show. ult: the meter is full (the hands
## glow). ability and hot_hand ("left", "right", "any": a counter is ready)
## add small touches.
## A power or spell just went off: the Catalyst's runes on that hand (both
## for "" or "any") flare in its color for a moment. Not a glow that stays:
## that's only for a ready ultimate.
func flash_runes(color: Color, hand := "") -> void:
	if fighter != "elementalist":
		return
	for side in (["left", "right"] if hand in ["", "any"] else [hand]):
		_rune_flash[side] = [color, RUNE_FLASH]


func set_power_state(ability: bool, ult: bool, hot_hand := "") -> void:
	_ability_ready = ability
	_ult_ready = ult
	_hot_hand = hot_hand


func play_punch(type: String, hand: String, impact_time: float, total_time: float) -> void:
	var arm: Node3D = _arms[hand]
	var mirror := -1.0 if hand == "left" else 1.0
	var pose: Dictionary = POSES[type]
	var rest_pos := _mirror_pos(REST_POS, mirror)
	var rest_rot := _mirror_rot(REST_ROT, mirror)

	if _tweens.has(hand):
		(_tweens[hand] as Tween).kill()

	var windup_time := impact_time * 0.35
	var strike_time := impact_time - windup_time
	var recover_time := maxf(total_time - impact_time, 0.08)

	var tween := create_tween()
	tween.tween_property(arm, "position", rest_pos + _mirror_pos(pose.windup_pos, mirror), windup_time) \
			.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(arm, "rotation", rest_rot + _mirror_rot(pose.windup_rot, mirror), windup_time)
	tween.tween_property(arm, "position", rest_pos + _mirror_pos(pose.strike_pos, mirror), strike_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(arm, "rotation", rest_rot + _mirror_rot(pose.strike_rot, mirror), strike_time)
	tween.tween_property(arm, "position", rest_pos, recover_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(arm, "rotation", rest_rot, recover_time)
	_tweens[hand] = tween
	# The Blur's punches leave violet afterimages along the way.
	if fighter == "combo_master":
		for i in 3:
			get_tree().create_timer(windup_time + strike_time * (0.3 + i * 0.3), false).timeout.connect(_afterimage.bind(arm))


# --- Idles (IdleAnims) --------------------------------------------------------------

## True while an idle is playing.
var idle_playing := false
## No idle sounds (previews).
var silent := false
var _idle_prop: Node3D
## Props gripped in the fists for the whole idle (IdleAnims hold).
var _held: Array[Node3D] = []
## The idle, as segments: {t0, t1, from: {hand: [pos, rot, shape]}, to, spec}.
var _idle_segments: Array = []
var _idle_time := 0.0
var _idle_index := -1
## Where the prop flies from and to this segment: [hand, anchor, lift], and
## whether it arcs.
var _prop_from: Array = []
var _prop_to: Array = []
var _prop_arc := false
## A hand's fingers are easing back into a fist.
var _closing := false


## Plays a hand idle once through (IdleAnims), then back to rest. It runs in
## _process (not tweens) so the hands can stop where they touch.
func play_idle(id: String) -> void:
	var anim: Dictionary = IdleAnims.ANIMS.get(id, {})
	if anim.is_empty():
		return
	stop_idle(false)
	for hand in ["left", "right"]:
		if _tweens.has(hand):
			(_tweens[hand] as Tween).kill()
	var state := {"left": [Vector3.ZERO, Vector3.ZERO, "fist"], "right": [Vector3.ZERO, Vector3.ZERO, "fist"]}
	var segments: Array = []
	var clock := 0.0
	for key in anim.keys + [[0.3, {"r": IdleAnims.REST, "l": IdleAnims.REST}]]:
		var spec: Dictionary = key[1]
		var from := state.duplicate(true)
		for hand in ["left", "right"]:
			var short := "l" if hand == "left" else "r"
			if spec.has(short):
				state[hand] = _idle_target(spec[short], state[hand][2])
		segments.append({"t0": clock, "t1": clock + float(key[0]), "from": from, "to": state.duplicate(true), "spec": spec})
		clock += float(key[0])
	_idle_segments = segments
	_idle_time = 0.0
	_idle_index = -1
	idle_playing = true
	if anim.has("prop"):
		_idle_prop = _make_prop(anim.prop)
		_idle_prop.visible = false
		add_child(_idle_prop)
	if anim.has("hold"):
		for hand in ["left", "right"]:
			var held := _make_prop(anim.hold)
			held.position = _mirror_pos(Vector3(0, -0.005, -0.36), -1.0 if hand == "left" else 1.0)
			held.rotation = Vector3(-0.35, 0, 0)
			(_arms[hand] as Node3D).add_child(held)
			_held.append(held)


## A key's target for one hand: [pose, shape, nudge] (IdleAnims.POSES) or
## [pos, rot, shape]; a missing shape keeps the last one.
func _idle_target(target: Array, last_shape: String) -> Array:
	if target[0] is String:
		var pose: Array = IdleAnims.POSES[target[0]]
		var nudge: Vector3 = target[2] if target.size() > 2 else Vector3.ZERO
		return [pose[0] + nudge, pose[1], target[1] if target.size() > 1 else last_shape]
	return [target[0], target[1], target[2] if target.size() > 2 else last_shape]


## Cuts an idle off: hands back to rest quickly, fingers closing, any prop gone.
func stop_idle(ease_back := true) -> void:
	_clear_prop()
	if not idle_playing:
		return
	idle_playing = false
	_closing = true
	if not ease_back:
		return
	for hand in ["left", "right"]:
		var arm: Node3D = _arms[hand]
		var mirror := -1.0 if hand == "left" else 1.0
		var tween := create_tween()
		tween.tween_property(arm, "position", _mirror_pos(REST_POS, mirror), 0.12)
		tween.parallel().tween_property(arm, "rotation", _mirror_rot(REST_ROT, mirror), 0.12)
		_tweens[hand] = tween


func _run_idle(delta: float) -> void:
	_idle_time += delta
	var last: Dictionary = _idle_segments[-1]
	if _idle_time >= float(last.t1):
		_end_idle()
		return
	var index := 0
	while float(_idle_segments[index].t1) <= _idle_time:
		index += 1
	var segment: Dictionary = _idle_segments[index]
	if index != _idle_index:
		_idle_index = index
		_on_segment(segment.spec)
	var u := smoothstep(0.0, 1.0, (_idle_time - float(segment.t0)) / maxf(float(segment.t1) - float(segment.t0), 0.001))
	for hand in ["left", "right"]:
		var from: Array = segment.from[hand]
		var to: Array = segment.to[hand]
		var mirror := -1.0 if hand == "left" else 1.0
		var arm: Node3D = _arms[hand]
		arm.position = _mirror_pos(REST_POS, mirror) + _mirror_pos((from[0] as Vector3).lerp(to[0], u), mirror)
		arm.rotation = _mirror_rot(REST_ROT, mirror) + _mirror_rot((from[1] as Vector3).lerp(to[1], u), mirror)
		_apply_shape(hand, IdleAnims.blend(IdleAnims.shape(from[2]), IdleAnims.shape(to[2]), u))
	_resolve_contact()
	_move_prop(u)


func _on_segment(spec: Dictionary) -> void:
	if spec.has("sfx") and not silent:
		Sfx.play(spec.sfx[0], spec.sfx[1], spec.sfx[2])
	if spec.get("trail", false):
		for hand in ["left", "right"]:
			if spec.has("l" if hand == "left" else "r"):
				_afterimage(_arms[hand])
	if is_instance_valid(_idle_prop):
		if spec.has("prop"):
			var to: Array = spec.prop
			_prop_from = _prop_to if _idle_prop.visible else to
			_prop_to = to
			_prop_arc = to.size() > 3 and to[3]
			_idle_prop.visible = true
		else:
			# Nothing new: it stays in the hand it landed in.
			_prop_from = _prop_to
			_prop_arc = false
		if spec.get("hide_prop", false):
			_idle_prop.visible = false


func _end_idle() -> void:
	idle_playing = false
	_clear_prop()
	for hand in ["left", "right"]:
		var mirror := -1.0 if hand == "left" else 1.0
		(_arms[hand] as Node3D).position = _mirror_pos(REST_POS, mirror)
		(_arms[hand] as Node3D).rotation = _mirror_rot(REST_ROT, mirror)
		_apply_shape(hand, IdleAnims.shape("fist"))


## The hands push apart where they'd pass through each other, so they touch.
func _resolve_contact() -> void:
	var spheres: Array = (CONTACT_GLOVE if _rig.has("mitten") else CONTACT).duplicate()
	var left_arm: Node3D = _arms.left
	var right_arm: Node3D = _arms.right
	var lefts := spheres.duplicate()
	var rights := spheres.duplicate()
	if float(_shape.left.get("f", 1.0)) < 0.6:
		lefts.append(CONTACT_TIPS)
	if float(_shape.right.get("f", 1.0)) < 0.6:
		rights.append(CONTACT_TIPS)
	for attempt in 3:
		var moved := false
		for a in lefts:
			for b in rights:
				var ca := left_arm.transform * _mirror_pos(a[0], -1.0)
				var cb := right_arm.transform * (b[0] as Vector3)
				var gap := cb - ca
				var overlap: float = float(a[1]) + float(b[1]) - gap.length()
				if overlap > 0.0005:
					var push := (gap.normalized() if gap.length() > 0.0001 else Vector3.RIGHT) * overlap * 0.5
					left_arm.position -= push
					right_arm.position += push
					moved = true
		if not moved:
			return


## Where a prop sits on a hand: [hand ("l"/"r"), anchor, lift].
func _anchor_point(spec: Array) -> Vector3:
	var hand := "left" if spec[0] == "l" else "right"
	var point: Vector3 = {"palm": Vector3(0, -0.055, -0.34), "top": Vector3(0, 0.05, -0.33),
			"tip": Vector3(0, -0.01, -0.44), "index": Vector3(-0.034, 0.005, -0.44), "thumb": Vector3(-0.035, 0.02, -0.4)}.get(spec[1], Vector3(0, 0, -0.34))
	if spec[1] == "fling":
		# Flicked off the fingertip, off into the distance.
		point = Vector3(-0.034, 0.005, -0.44)
		return (_arms[hand] as Node3D).transform * _mirror_pos(point, -1.0 if hand == "left" else 1.0) + Vector3(-0.25, 0.2, -1.1)
	return (_arms[hand] as Node3D).transform * _mirror_pos(point, -1.0 if hand == "left" else 1.0) + Vector3(0, float(spec[2]), 0)


func _move_prop(u: float) -> void:
	if not is_instance_valid(_idle_prop) or not _idle_prop.visible or _prop_to.is_empty():
		return
	var point := _anchor_point(_prop_from).lerp(_anchor_point(_prop_to), u)
	if _prop_arc:
		point.y += 0.14 * sin(PI * u)
	_idle_prop.position = point


func _clear_prop() -> void:
	for held in _held:
		if is_instance_valid(held):
			held.queue_free()
	_held.clear()
	if is_instance_valid(_idle_prop):
		_idle_prop.queue_free()
	_idle_prop = null
	_prop_from = []
	_prop_to = []


## coin: a spinning gold coin. skull: a little bone skull. flame: a flame
## with a glow and rising sparks.
func _make_prop(kind: String) -> Node3D:
	var prop := Node3D.new()
	var part := func(mesh: PrimitiveMesh, material: Material, at := Vector3.ZERO) -> void:
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = at
		instance.layers = HAND_LAYER
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prop.add_child(instance)
	match kind:
		"coin":
			var coin := CylinderMesh.new()
			coin.top_radius = 0.02
			coin.bottom_radius = 0.02
			coin.height = 0.004
			coin.radial_segments = 12
			var gold := _glow(Color(1.0, 0.8, 0.2), 0.6)
			gold.metallic = 0.8
			part.call(coin, gold)
		"booger":
			var green := StandardMaterial3D.new()
			green.albedo_color = Color(0.45, 0.62, 0.18)
			green.roughness = 0.2
			var blob := BoxMesh.new()
			blob.size = Vector3(0.011, 0.009, 0.011)
			part.call(blob, green)
		"bone":
			# A long bone gripped like a drumstick: a shaft out past the
			# knuckles with a knobbed end each side.
			var white := StandardMaterial3D.new()
			white.albedo_color = Color(0.88, 0.85, 0.76)
			var shaft := BoxMesh.new()
			shaft.size = Vector3(0.014, 0.014, 0.2)
			part.call(shaft, white, Vector3(0, 0, -0.06))
			for end in [0.04, -0.16]:
				for side in [-1.0, 1.0]:
					var knob := BoxMesh.new()
					knob.size = Vector3(0.016, 0.02, 0.022)
					part.call(knob, white, Vector3(0.008 * side, 0, end))
		"skull":
			var bone := StandardMaterial3D.new()
			bone.albedo_color = Color(0.86, 0.83, 0.74)
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.08, 0.06, 0.06)
			var box := BoxMesh.new()
			box.size = Vector3(0.05, 0.045, 0.05)
			part.call(box, bone)
			var jaw := BoxMesh.new()
			jaw.size = Vector3(0.035, 0.015, 0.035)
			part.call(jaw, bone, Vector3(0, -0.028, 0.006))
			for side in [-1.0, 1.0]:
				var eye := BoxMesh.new()
				eye.size = Vector3(0.012, 0.012, 0.004)
				part.call(eye, dark, Vector3(0.011 * side, 0.004, 0.026))
		"flame":
			var color := Color(1.0, 0.5, 0.12)
			var core := BoxMesh.new()
			core.size = Vector3(0.028, 0.04, 0.028)
			part.call(core, _glow(color, 4.0))
			var light := OmniLight3D.new()
			light.light_cull_mask = HAND_LAYER
			light.light_color = color
			light.light_energy = 0.6
			light.omni_range = 0.4
			prop.add_child(light)
			var sparks := CPUParticles3D.new()
			sparks.amount = 16
			sparks.lifetime = 0.4
			sparks.direction = Vector3.UP
			sparks.spread = 25.0
			sparks.gravity = Vector3(0, 0.3, 0)
			sparks.initial_velocity_min = 0.05
			sparks.initial_velocity_max = 0.15
			sparks.layers = HAND_LAYER
			var bit := BoxMesh.new()
			bit.size = Vector3.ONE * 0.008
			bit.material = _glow(Color(1.0, 0.7, 0.2), 3.0)
			sparks.mesh = bit
			prop.add_child(sparks)
	return prop


## 0 = healthy, 1 = knuckles about to break: bare skin reddens.
func set_hurt(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	(_materials.skin as StandardMaterial3D).albedo_color = Color.WHITE.lerp(Color(1.0, 0.45, 0.4), amount * 0.8)


# --- Building the voxel arm --------------------------------------------------------

## Paints one arm into a voxel grid (in right-arm coordinates; the thumb is on
## -X, the inner side), then turns its visible surface into cubes. side is 1
## for the right arm, -1 for the left.
func _build_arm(side: float) -> Node3D:
	var arm := Node3D.new()
	arm.position = _mirror_pos(REST_POS, side)
	arm.rotation = _mirror_rot(REST_ROT, side)
	add_child(arm)
	var key := "%s|%s|%d" % [fighter, skin_id, side]
	if _cache.has(key):
		var built: Dictionary = _cache[key]
		_rig = built.rig
		for entry in built.meshes.get("", []):
			_attach(arm, entry[0], entry[1])
		_build_bones(arm, side, built.meshes)
		_build_effect(arm, side)
		return arm
	_grid.clear()
	_cores = {}
	_rig = {}
	_bone_cells.clear()
	_bone_extra.clear()
	_meshes = {}
	match fighter:
		"berserker":
			_paint_mauler()
		"combo_master":
			_paint_blur()
		"counter_master":
			_paint_answer()
		"free_runner":
			_paint_stray(side < 0.0)
		"wise_guy":
			_paint_tony(side < 0.0)
		"elementalist":
			_paint_catalyst(side < 0.0)
		_:
			_paint_forearm(_skin_fn(), "skin")
			_paint_fist(_skin_fn(), _skin_fn())
	if fighter == "berserker":
		_rig_mitten()
	_attach_loose_voxels()
	_bake(arm, side)
	_build_bones(arm, side)
	_cache[key] = {"rig": _rig, "meshes": _meshes}
	_grid.clear()
	_cores = {}
	_bone_cells.clear()
	_bone_extra.clear()
	_build_effect(arm, side)
	return arm


## Fills every voxel whose center is inside the box (meters) with color(p) in a
## group. soft: how much of each edge to shave off, for padded shapes. The
## color is only worked out for voxels that end up showing (_color_of).
func _fill(from: Vector3, to: Vector3, color: Callable, group := "gear", soft := 0.0) -> void:
	var lo := Vector3i((from / VOXEL).floor())
	var hi := Vector3i((to / VOXEL).ceil())
	var center := (from + to) / 2.0
	var half := (to - from) / 2.0
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			for z in range(lo.z, hi.z):
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * VOXEL
				if p.x < from.x or p.x > to.x or p.y < from.y or p.y > to.y or p.z < from.z or p.z > to.z:
					continue
				if soft > 0.0:
					# Shave the edges and corners, like a padded box.
					var d := ((p - center).abs() - (half - Vector3.ONE * soft)).max(Vector3.ZERO)
					if d.length() > soft:
						continue
				_grid[Vector3i(x, y, z)] = [color, group]


## A box tapering along Z from half-size a (at z0) to b (at z1), centered on y_mid.
func _fill_taper(z0: float, z1: float, a: Vector2, b: Vector2, y_mid: float, color: Callable, group := "gear") -> void:
	var steps := maxi(1, int((z1 - z0) / VOXEL))
	for i in steps:
		var z := z0 + i * VOXEL
		var t := float(i) / steps
		var h := a.lerp(b, t)
		_fill_shell(Vector3(-h.x, y_mid - h.y, z), Vector3(h.x, y_mid + h.y, z + VOXEL * 1.01), color, group)


## Like _fill, but only the outer SHELL voxels of the box's sides (x and y);
## the rest is recorded as a core (filled, never shown).
func _fill_shell(from: Vector3, to: Vector3, color: Callable, group: String) -> void:
	var lo := Vector3i(((from / VOXEL) - Vector3.ONE * 0.5).ceil())
	var hi := Vector3i(((to / VOXEL) - Vector3.ONE * 0.5).floor())
	var core := Rect2i(lo.x + SHELL, lo.y + SHELL, hi.x - lo.x + 1 - SHELL * 2, hi.y - lo.y + 1 - SHELL * 2)
	var hollow := core.size.x > 0 and core.size.y > 0
	for z in range(lo.z, hi.z + 1):
		if hollow:
			if not _cores.has(z):
				_cores[z] = []
			_cores[z].append(core)
		for y in range(lo.y, hi.y + 1):
			var middle := hollow and y >= core.position.y and y < core.end.y
			var x := lo.x
			while x <= hi.x:
				if middle and x == core.position.x:
					x = core.end.x
					continue
				_grid[Vector3i(x, y, z)] = [color, group]
				x += 1


## True if a cell is painted, or inside a taper's hidden core.
static func _filled_at(grid: Dictionary, cores: Dictionary, cell: Vector3i) -> bool:
	if grid.has(cell):
		return true
	var rects = cores.get(cell.z)
	if rects == null:
		return false
	for rect in rects:
		if (rect as Rect2i).has_point(Vector2i(cell.x, cell.y)):
			return true
	return false


## How a surface voxel is lit: lighter where nothing is above it and on
## edges, darker underneath and in creases (counted from the cells around).
const SHADE_NEAR := [
	Vector3i(-2, 0, 0), Vector3i(2, 0, 0), Vector3i(0, -2, 0), Vector3i(0, 2, 0), Vector3i(0, 0, -2), Vector3i(0, 0, 2),
	Vector3i(-2, -2, 0), Vector3i(2, 2, 0), Vector3i(-2, 2, 0), Vector3i(2, -2, 0),
]
const SIDES := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


static func _shade(cells: Dictionary, cell: Vector3i, color: Color, cores := {}) -> Color:
	var filled := 0
	var core := not cores.is_empty()
	for n in SHADE_NEAR:
		var at: Vector3i = cell + n
		if cells.has(at) or (core and _filled_at(cells, cores, at)):
			filled += 1
	var crease := clampf((filled - 5.0) / 3.5, -1.0, 1.0)
	color = color.darkened(0.3 * crease) if crease > 0.0 else color.lightened(-0.08 * crease)
	var up := cell + Vector3i(0, 1, 0)
	var down := cell + Vector3i(0, -1, 0)
	if not (cells.has(up) or (core and _filled_at(cells, cores, up))):
		color = color.lightened(0.05)
	elif not (cells.has(down) or (core and _filled_at(cells, cores, down))):
		color = color.darkened(0.1)
	return color


## A MultiMesh of cubes at positions ([[Vector3, Color], ...] by index), filled
## in one go.
static func _cubes(positions: Array, colors: Array, cube: Mesh) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = positions.size()
	var buffer := PackedFloat32Array()
	buffer.resize(positions.size() * 16)
	var k := 0
	for i in positions.size():
		var p: Vector3 = positions[i]
		var c: Color = colors[i]
		buffer[k] = 1.0
		buffer[k + 3] = p.x
		buffer[k + 5] = 1.0
		buffer[k + 7] = p.y
		buffer[k + 10] = 1.0
		buffer[k + 11] = p.z
		buffer[k + 12] = c.r
		buffer[k + 13] = c.g
		buffer[k + 14] = c.b
		buffer[k + 15] = c.a
		k += 16
	multimesh.buffer = buffer
	return multimesh


## Turns the painted grid into cubes: only voxels with an open side are kept,
## one MultiMesh per material group.
func _bake(arm: Node3D, side: float) -> void:
	var grid := _grid
	var cores := _cores
	var positions := {}
	var colors := {}
	for cell in grid:
		var open := false
		for n in SIDES:
			var at: Vector3i = cell + n
			if not grid.has(at) and not _filled_at(grid, cores, at):
				open = true
				break
		if not open:
			continue
		var entry: Array = grid[cell]
		var group: String = entry[1]
		if not positions.has(group):
			positions[group] = []
			colors[group] = []
		positions[group].append(Vector3((cell.x + 0.5) * VOXEL * side, (cell.y + 0.5) * VOXEL, (cell.z + 0.5) * VOXEL))
		colors[group].append(_shade(grid, cell, _color_of(cell, entry), cores))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * VOXEL * 1.02
	for group in positions:
		var multimesh := _cubes(positions[group], colors[group], cube)
		_meshes[""] = _meshes.get("", []) + [[group, multimesh]]
		_attach(arm, group, multimesh)


## A painted voxel's color: set, or worked out from where it sits.
static func _color_of(cell: Vector3i, entry: Array) -> Color:
	var color = entry[0]
	return color if color is Color else (color as Callable).call((Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL)


## Puts a baked mesh on a node in this pair of hands' own material for its
## group (they take the hurt tint and the ultimate's glow).
func _attach(node: Node3D, group: String, multimesh: MultiMesh) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = _materials[group]
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.layers = HAND_LAYER
	node.add_child(instance)


# --- Color helpers ----------------------------------------------------------------

## A little per-voxel variation so surfaces read as textured blocks.
func _vary(color: Color, p: Vector3, amount := 0.06) -> Color:
	amount *= 0.3
	var h := absf(sin(p.x * 1271.3 + p.y * 3117.7 + p.z * 1771.1) * 43758.5453)
	h -= floorf(h)
	return color.darkened(h * amount) if h > 0.5 else color.lightened((0.5 - h) * amount)


func _solid(color: Color, amount := 0.06) -> Callable:
	return func(p: Vector3) -> Color: return _vary(color, p, amount)


## A part's color in this fighter's palette (Skins).
func _p(key: String) -> Color:
	return _pal.get(key, Color.MAGENTA)


func _skin_fn() -> Callable:
	return func(p: Vector3) -> Color:
		var c := _skin_color
		# Creases between the fingers and across the finger joints.
		if p.z < -0.346:
			var gap := fposmod(p.x + 0.0455, 0.0227)
			if gap < VOXEL * 0.9 or (absf(p.y - 0.0) < VOXEL * 0.6 and p.z < -0.385):
				c = c.darkened(0.25)
		return _vary(c, p, 0.05)


## Tape or cloth wound around the arm: a strip width wide spiralling up it
## (slant 1: each turn climbs one width; 0: flat rings), each turn shaded from
## its overlapping edge to its tucked one, a dark seam between turns. colors
## take turns, one per turn.
func _wrap(colors: Array, width: float, slant := 1.0, seam := Color.TRANSPARENT) -> Callable:
	return func(p: Vector3) -> Color:
		var u := (p.z + atan2(p.y, p.x) / TAU * width * slant) / width
		var t := u - floorf(u)
		var c: Color = colors[posmod(int(floorf(u)), colors.size())]
		if t * width < VOXEL * 0.95:
			return seam if seam.a > 0.0 else c.darkened(0.22)
		return c.lightened(0.07 * (1.0 - t)).darkened(0.07 * t)


## Bands along the arm: colors repeat every len(colors) * width meters of z.
func _bands(colors: Array, width: float, edge := Color.TRANSPARENT) -> Callable:
	return func(p: Vector3) -> Color:
		var i := int(floorf(p.z / width)) % colors.size()
		var c: Color = colors[i if i >= 0 else i + colors.size()]
		if edge.a > 0.0 and fposmod(p.z, width) < VOXEL:
			c = edge
		return _vary(c, p, 0.08)


# --- The parts every hand shares ---------------------------------------------------

## Forearm from just behind the wrist back past the elbow.
func _paint_forearm(color: Callable, group := "skin", scale := 1.0, z0 := -0.24, z1 := 0.32) -> void:
	_fill_taper(z0, z1, Vector2(0.036, 0.032) * scale, Vector2(0.047, 0.042) * scale, 0.0, color, group)


func _paint_wrist(color: Callable, group := "skin", grow := 0.0) -> void:
	_fill(Vector3(-0.042 - grow, -0.037 - grow, -0.29), Vector3(0.042 + grow, 0.037 + grow, -0.235), color, group)


## A bare hand: the palm block, then four fingers of three segments and a
## thumb of two (the rig), painted where they sit in a closed fist so a
## fighter's colors land where they always did. hand/fingers: colors;
## knuckles: the first finger segments (e.g. taped), if different.
func _paint_fist(hand: Callable, fingers: Callable, hand_group := "skin", fingers_group := "skin", knuckles := Callable(), knuckle_group := "") -> void:
	_fill(Vector3(-0.047, -0.03, -0.358), Vector3(0.047, 0.034, -0.285), hand, hand_group, 0.006)
	# The thumb's root, on the inner side of the palm.
	_fill(Vector3(-0.058, -0.03, -0.345), Vector3(-0.036, -0.004, -0.3), hand, hand_group, 0.004)
	for i in 4:
		var parent := ""
		for j in 3:
			var bone := "f%d_%d" % [i, j]
			var offset := Vector3(FINGER_X[i], KNUCKLE.x, KNUCKLE.y) if j == 0 else Vector3(0, 0, -PHALANX[j - 1] * FINGER_LENGTH[i])
			_rig[bone] = {"parent": parent, "offset": offset, "closed": Vector3(CURL_CLOSED[j], 0, 0), "open": Vector3(CURL_OPEN[j], 0, 0)}
			var color := knuckles if j == 0 and knuckles.is_valid() else fingers
			var group := knuckle_group if j == 0 and knuckle_group != "" else fingers_group
			_paint_bone(bone, PHALANX[j] * FINGER_LENGTH[i], FINGER_SIZE, color, group)
			parent = bone
	_rig["t_0"] = {"parent": "", "offset": THUMB_PIVOT, "closed": THUMB_CLOSED[0], "open": THUMB_OPEN[0]}
	_rig["t_1"] = {"parent": "t_0", "offset": Vector3(0, 0, -THUMB_LENGTH[0]), "closed": THUMB_CLOSED[1], "open": THUMB_OPEN[1]}
	_paint_bone("t_0", THUMB_LENGTH[0], THUMB_SIZE, hand, hand_group)
	_paint_bone("t_1", THUMB_LENGTH[1], THUMB_SIZE, hand, hand_group)


## A ring around a finger bone, near its base (part of that bone, so it
## moves with the finger). Glows with the ultimate (rim).
func _ring(bone: String, color: Color) -> void:
	var cells: Dictionary = _bone_cells.get(bone, {})
	var half := FINGER_SIZE * 0.5
	for x in range(-4, 4):
		for y in range(-4, 4):
			for z in range(-3, 0):
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * VOXEL + Vector3(0, 0, -0.01)
				var outside := absf(p.x) > half.x - 0.001 or absf(p.y) > half.y - 0.001
				if outside and absf(p.x) <= half.x + VOXEL * 1.2 and absf(p.y) <= half.y + VOXEL * 1.2:
					cells[Vector3i((p / VOXEL).floor())] = [_vary(color, p, 0.05), "rim"]
	_bone_cells[bone] = cells


## A bone's closed-fist transform (painting space).
func _closed_transform(bone: String) -> Transform3D:
	var info: Dictionary = _rig[bone]
	var local := Transform3D(Basis.from_euler(info.closed), info.offset)
	return (_closed_transform(info.parent) if info.parent != "" else Transform3D.IDENTITY) * local


## Fills a bone: a padded box from its pivot out along -Z, colored by where
## each voxel sits in the closed fist.
func _paint_bone(bone: String, length: float, size: Vector2, color: Callable, group: String) -> void:
	var closed := _closed_transform(bone)
	var cells := {}
	var half := Vector3(size.x * 0.5, size.y * 0.5, length * 0.5 + 0.002)
	var center := Vector3(0, 0, -length * 0.5)
	var lo := Vector3i(((center - half) / VOXEL).floor())
	var hi := Vector3i(((center + half) / VOXEL).ceil())
	for x in range(lo.x, hi.x):
		for y in range(lo.y, hi.y):
			for z in range(lo.z, hi.z):
				var p := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5)) * VOXEL
				var d := ((p - center).abs() - (half - Vector3.ONE * 0.004)).max(Vector3.ZERO)
				if (p - center).abs().x > half.x or (p - center).abs().y > half.y or (p - center).abs().z > half.z or d.length() > 0.004:
					continue
				var c: Color = color.call(closed * p)
				# A crease where each segment meets the one before.
				if p.z > -VOXEL * 1.1 and bone != "t_0":
					c = c.darkened(0.28)
				# Nails on the bare fingertips (the back of the hand is +y).
				elif group == "skin" and (bone.ends_with("_2") or bone == "t_1") and p.y > half.y - VOXEL * 1.2 						and p.z < -length * 0.35 and absf(p.x) < half.x - VOXEL * 0.6:
					c = c.lerp(Color(0.96, 0.84, 0.8), 0.45).lightened(0.08)
				cells[Vector3i(x, y, z)] = [c, group]
	_bone_cells[bone] = cells


## The Mauler's gloves: the padded front and the thumb come off the painted
## glove as two bones (closed = as painted).
func _rig_mitten() -> void:
	_rig["mitten"] = {"parent": "", "offset": MITTEN_PIVOT, "closed": Vector3.ZERO, "open": MITTEN_OPEN}
	_rig["t_0"] = {"parent": "", "offset": MITTEN_THUMB_PIVOT, "closed": Vector3.ZERO, "open": MITTEN_THUMB_OPEN}
	var parts := {"mitten": {}, "t_0": {}}
	for cell in _grid.keys():
		var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL
		if p.x < -0.05 and p.z < -0.3 and p.z > -0.41:
			parts.t_0[cell] = _grid[cell]
		elif p.z < MITTEN_PIVOT.z:
			parts.mitten[cell] = _grid[cell]
	for bone in parts:
		var cells: Dictionary = parts[bone]
		var to_bone := _closed_transform(bone).affine_inverse()
		var extra: Array = _bone_extra.get(bone, [])
		for cell in cells:
			for n in SIDES:
				if not cells.has(cell + n):
					var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL
					extra.append([to_bone * p, _shade(cells, cell, _color_of(cell, cells[cell])), cells[cell][1]])
					break
		_bone_extra[bone] = extra
		for cell in cells:
			_grid.erase(cell)


## Anything painted out past the palm onto the fingers (taped knuckles, a ring,
## runes) rides on the nearest finger bone.
func _attach_loose_voxels() -> void:
	if not _rig.has("f0_0"):
		return
	var ends := {}
	for bone in _rig:
		var closed := _closed_transform(bone)
		ends[bone] = [closed.origin, closed * Vector3(0, 0, -0.02)]
	for cell in _grid.keys():
		var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL
		if p.z > -0.36 or p.z < -0.45:
			continue
		var best := ""
		var best_distance := 0.03
		for bone in ends:
			var a: Vector3 = ends[bone][0]
			var b: Vector3 = ends[bone][1]
			var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.000001), 0.0, 1.0)
			var distance := p.distance_to(a.lerp(b, t))
			if distance < best_distance:
				best_distance = distance
				best = bone
		if best == "":
			continue
		if not _bone_extra.has(best):
			_bone_extra[best] = []
		var entry: Array = _grid[cell]
		_bone_extra[best].append([_closed_transform(best).affine_inverse() * p, _color_of(cell, entry), entry[1]])
		_grid.erase(cell)


## The bone nodes under the arm (closed), each with its voxels baked on (or
## the meshes built before, when given).
func _build_bones(arm: Node3D, side: float, built := {}) -> void:
	var hand := "left" if side < 0.0 else "right"
	var nodes := {}
	for bone in _rig:
		var info: Dictionary = _rig[bone]
		var node := Node3D.new()
		node.position = _mirror_pos(info.offset, side)
		node.rotation = _mirror_rot(info.closed, side)
		(nodes[info.parent] if info.parent != "" else arm).add_child(node)
		nodes[bone] = node
		if not built.is_empty():
			for entry in built.get(bone, []):
				_attach(node, entry[0], entry[1])
			continue
		var voxels: Array = []
		var cells: Dictionary = _bone_cells.get(bone, {})
		for cell in cells:
			var open := false
			for n in SIDES:
				if not cells.has(cell + n):
					open = true
					break
			if not open:
				continue
			voxels.append([(Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL, _shade(cells, cell, cells[cell][0]), cells[cell][1]])
		voxels.append_array(_bone_extra.get(bone, []))
		_bake_voxels(node, voxels, side, bone)
	_bones[hand] = nodes
	_shape[hand] = IdleAnims.shape("fist")


## Voxels [[position, color, group]] as cubes under a node, one MultiMesh per group.
func _bake_voxels(node: Node3D, voxels: Array, side: float, bone: String) -> void:
	var positions := {}
	var colors := {}
	for voxel in voxels:
		var group: String = voxel[2]
		if not positions.has(group):
			positions[group] = []
			colors[group] = []
		positions[group].append(_mirror_pos(voxel[0], side))
		colors[group].append(voxel[1])
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * VOXEL * 1.02
	for group in positions:
		var multimesh := _cubes(positions[group], colors[group], cube)
		_meshes[bone] = _meshes.get(bone, []) + [[group, multimesh]]
		_attach(node, group, multimesh)


## Poses a hand's bones from a shape (IdleAnims.shape): f / f0-f3 finger curl
## (1 = fist), t thumb curl, tu thumb up (0-1), spread (0-1).
func _apply_shape(hand: String, shape: Dictionary) -> void:
	_shape[hand] = shape
	var side := -1.0 if hand == "left" else 1.0
	var nodes: Dictionary = _bones[hand]
	for bone in nodes:
		var info: Dictionary = _rig[bone]
		var rotation: Vector3
		if bone.begins_with("f"):
			var finger := int(bone.substr(1, 1))
			var curl: float = shape.get("f%d" % finger, shape.get("f", 1.0))
			rotation = (info.open as Vector3).lerp(info.closed, curl)
			if bone.ends_with("_0"):
				rotation.y = SPREAD[finger] * float(shape.get("spread", 0.0))
		elif bone.begins_with("t"):
			rotation = (info.open as Vector3).lerp(info.closed, float(shape.get("t", 1.0)))
			var up := float(shape.get("tu", 0.0))
			if up > 0.0 and not _rig.has("mitten"):
				rotation = rotation.lerp(THUMB_UP[0] if bone == "t_0" else THUMB_UP[1], up)
		else:
			rotation = (info.open as Vector3).lerp(info.closed, float(shape.get("f", 1.0)))
		(nodes[bone] as Node3D).rotation = _mirror_rot(rotation, side)


# --- The fighters ------------------------------------------------------------------

## The Mauler: big padded red boxing gloves with seams, a white taped cuff with
## red laces, and heavy bare forearms. When the ultimate is ready, cracks in
## the leather glow orange.
func _paint_mauler() -> void:
	var red := _p("glove").darkened(0.08)
	_paint_forearm(_skin_fn(), "skin", 1.25)
	# Cuff: white tape in bands, laced up the palm side.
	var cuff := _wrap([_p("tape")], 0.017)
	_fill_taper(-0.3, -0.2, Vector2(0.06, 0.054), Vector2(0.056, 0.05), 0.0, func(p: Vector3) -> Color:
		# Laces criss-crossing the palm side.
		if p.y < -0.044 and absf(fposmod(p.z + p.x * 1.5, 0.026) - 0.013) < VOXEL * 1.2:
			return _p("sash").darkened(0.25)
		return cuff.call(p))
	var leather := func(p: Vector3) -> Color:
		var c := red
		# Seam down the back of the glove and around the thumb.
		if absf(p.x) < VOXEL * 0.8 and p.y > 0.03:
			c = red.darkened(0.4)
		# Padded knuckles a shade lighter.
		if p.y > 0.035 and p.z < -0.37:
			c = red.lightened(0.15)
		return _vary(c, p, 0.08)
	_fill(Vector3(-0.066, -0.058, -0.435), Vector3(0.066, 0.064, -0.28), leather, "gear", 0.022)
	_fill(Vector3(-0.084, -0.05, -0.4), Vector3(-0.05, 0.004, -0.3), leather, "gear", 0.012)
	# Cracks in the leather: dark now, glowing when the Inferno is ready.
	for cell in _grid.keys():
		var entry: Array = _grid[cell]
		var p := (Vector3(cell) + Vector3(0.5, 0.5, 0.5)) * VOXEL
		if p.z < -0.29 and entry[1] == "gear" and p.y > -0.02:
			# A jagged web of cracks across the leather.
			var q := p + Vector3(sin(p.y * 97.0 + p.z * 41.0), sin(p.z * 83.0 + p.x * 59.0), sin(p.x * 71.0 + p.y * 47.0)) * 0.008
			var block := (q / 0.05).floor()
			var h := absf(sin(block.x * 127.1 + block.y * 311.7 + block.z * 74.7) * 43758.5)
			if h - floorf(h) < 0.45 and block != ((q + Vector3.ONE * VOXEL * 0.6) / 0.05).floor():
				_grid[cell] = [Color(_p("cracks"), 1.0), "rim"]


## The Blur: bare hands with purple wraps around every finger, over the
## knuckles and around the palm, a purple wrist wrap, and a dark sleeve with a
## glowing violet cuff.
func _paint_blur() -> void:
	var purple := _p("hand_wrap")
	var wrap := _wrap([purple], 0.014)
	_fill_taper(-0.2, 0.32, Vector2(0.05, 0.046), Vector2(0.056, 0.052), 0.0, func(p: Vector3) -> Color:
		var c := _p("top")
		if fposmod(p.z, 0.06) < VOXEL * 1.5:
			c = c.darkened(0.35)
		return _vary(c, p, 0.05))
	_fill_taper(-0.215, -0.198, Vector2(0.052, 0.048), Vector2(0.052, 0.048), 0.0, _solid(purple.lightened(0.3)), "rim")
	_paint_forearm(_skin_fn(), "skin", 1.0, -0.24, -0.2)
	_paint_wrist(wrap, "gear", 0.003)
	_paint_fist(_skin_fn(), wrap, "skin", "gear")
	# The wrap carries on around the hand, below the knuckles.
	_fill(Vector3(-0.049, -0.04, -0.336), Vector3(0.049, 0.038, -0.318), wrap, "gear")


## The Answer: black gloves taped white across the knuckles, and thick blue
## wraps from the wrist up the forearm in bands. The white bands glow blue
## when the ultimate is ready.
func _paint_answer() -> void:
	var blue := _p("wrap")
	var navy := _p("wrap_dark").darkened(0.5)
	var white := _p("wrap_light")
	var black := _p("glove")
	var tape := _p("glove_cuff")
	# Coat sleeve beyond the wraps.
	_fill_taper(0.12, 0.32, Vector2(0.056, 0.052), Vector2(0.06, 0.056), 0.0, _solid(_p("cloth")))
	# Forearm wraps: wide blue bands, thin navy ones, a white stripe now and then.
	_fill_taper(-0.29, 0.12, Vector2(0.046, 0.042), Vector2(0.053, 0.049), 0.0, _wrap([blue, blue, blue, navy.lightened(0.15)], 0.016, 1.0, blue.darkened(0.45)))
	for z in [-0.255, -0.18, -0.105, -0.03, 0.045]:
		_fill_taper(z, z + 0.0075, Vector2(0.049, 0.045), Vector2(0.05, 0.046), 0.0, _solid(white, 0.05), "rim")
	var glove := func(p: Vector3) -> Color:
		var c := black
		# White tape across the knuckles and around the hand.
		if (p.y > 0.024 and p.z < -0.345 and p.z > -0.375) or (p.z > -0.322 and p.z < -0.305):
			c = tape
		elif p.z < -0.346 and fposmod(p.x + 0.0455, 0.0227) < VOXEL * 0.9:
			c = Color(0.03, 0.03, 0.04)
		return _vary(c, p, 0.07)
	_paint_fist(glove, glove, "gear", "gear")


## The Stray: green fingerless gloves (the fingers stick out bare), white tape
## wraps up the forearm, a red bandana tied on the left one, and a dark hoodie
## sleeve with green trim.
func _paint_stray(left: bool) -> void:
	var green := _p("glove")
	var tape := _p("tape")
	_fill_taper(0.06, 0.32, Vector2(0.056, 0.052), Vector2(0.06, 0.056), 0.0, _solid(_p("gi")))
	_fill_taper(0.05, 0.062, Vector2(0.058, 0.054), Vector2(0.058, 0.054), 0.0, _solid(_accent), "rim")
	# Tape wraps: overlapping turns with darker edges, slightly ragged.
	_fill_taper(-0.29, 0.06, Vector2(0.044, 0.04), Vector2(0.05, 0.046), 0.0, _wrap([tape], 0.018))
	if left:
		var red := _p("band")
		_fill_taper(-0.2, -0.155, Vector2(0.052, 0.048), Vector2(0.053, 0.049), 0.0, _solid(red, 0.1))
		# Knot and two tails hanging off the outer side.
		_fill(Vector3(0.048, -0.02, -0.19), Vector3(0.066, 0.016, -0.165), _solid(red.darkened(0.15), 0.1))
		_fill(Vector3(0.058, -0.075, -0.19), Vector3(0.07, -0.02, -0.176), _solid(red, 0.1))
		_fill(Vector3(0.062, -0.065, -0.172), Vector3(0.074, -0.018, -0.16), _solid(red.darkened(0.1), 0.1))
	var glove := func(p: Vector3) -> Color:
		var c := green
		# Black edging around the finger holes and down the back.
		if (p.z < -0.338 and p.z > -0.35) or absf(p.x) < VOXEL * 0.7:
			c = Color(0.04, 0.06, 0.05)
		return _vary(c, p, 0.08)
	_paint_fist(glove, _skin_fn(), "gear", "skin")
	# The finger holes leave the fingers' first segments bare; the glove covers the rest.
	_fill(Vector3(-0.049, -0.04, -0.35), Vector3(0.049, 0.038, -0.337), glove, "gear")


## Tony: a black tracksuit sleeve with two white stripes, white tape wound
## around the wrist and over the knuckles, and a gold pinky ring.
func _paint_tony(_left: bool) -> void:
	var black := _p("jacket")
	var stripe := _p("stripe")
	_fill_taper(-0.22, 0.32, Vector2(0.05, 0.046), Vector2(0.06, 0.055), 0.0, func(p: Vector3) -> Color:
		# Two white stripes running down the top of the sleeve.
		if p.y > 0.03 and (absf(p.x - 0.012) < VOXEL * 0.8 or absf(p.x + 0.012) < VOXEL * 0.8):
			return _vary(stripe, p, 0.04)
		return _vary(black, p, 0.08))
	# Ribbed cuff.
	_fill_taper(-0.24, -0.205, Vector2(0.052, 0.048), Vector2(0.052, 0.048), 0.0, _solid(_p("rib_a")), "gear")
	var taped := _wrap([_p("tape")], 0.016)
	_paint_wrist(taped, "gear", 0.004)
	# Tape over the knuckles too (the first finger segments), fingertips bare.
	_paint_fist(taped, _skin_fn(), "gear", "skin", taped, "gear")
	# A gold pinky ring on each hand: Tony's got two.
	_ring("f3_0", Color(1.0, 0.78, 0.22))


## The Catalyst: a heavy old forearm (veins, white hairs) under a dark robe
## sleeve with white trim, white tape wraps up the forearm and over the
## knuckles, inscribed with runes (rune_left / rune_right) that glow in his
## powers' colors when the ultimate is ready.
func _paint_catalyst(left: bool) -> void:
	var skin := _skin_color
	_fill_taper(0.14, 0.32, Vector2(0.062, 0.058), Vector2(0.068, 0.064), 0.0, _solid(_p("robe")))
	_fill_taper(0.13, 0.148, Vector2(0.064, 0.06), Vector2(0.064, 0.06), 0.0, _solid(_p("trim")))
	# A vein snaking along the top of the forearm, and the odd white hair.
	var forearm := func(p: Vector3) -> Color:
		if p.y > 0.0 and absf(p.x - 0.018 * sin(p.z * 55.0)) < VOXEL * 0.7:
			return _vary(skin.darkened(0.2).lerp(Color(0.4, 0.45, 0.65), 0.2), p, 0.04)
		if fposmod(p.x * 13.0 + p.z * 31.0 + p.y * 7.0, 0.023) < 0.0014:
			return Color(0.92, 0.92, 0.9)
		return _vary(skin, p, 0.09)
	_fill_taper(-0.12, 0.13, Vector2(0.05, 0.046), Vector2(0.058, 0.054), 0.0, forearm, "skin")
	var taped := _wrap([_p("tape_b").darkened(0.12)], 0.017)
	_fill_taper(-0.29, -0.12, Vector2(0.046, 0.042), Vector2(0.05, 0.046), 0.0, taped)
	_paint_wrist(taped, "gear", 0.004)
	_paint_fist(taped, _skin_fn(), "gear", "skin")
	# Runes: little glyph marks around the wraps and across the knuckles.
	var group := "rune_left" if left else "rune_right"
	var rune := _solid(Color(0.35, 0.3, 0.28), 0.02)
	for ring in 3:
		var z := -0.27 + ring * 0.05
		for k in 7:
			if (k + ring) % 3 == 2:
				continue
			var a := TAU * k / 7.0 + ring * 0.4
			var at := Vector3(cos(a) * 0.049, sin(a) * 0.045, z)
			var tall := VOXEL * (3.0 if k % 2 == 0 else 1.6)
			_fill(at - Vector3(VOXEL, VOXEL, tall) * 0.9, at + Vector3(VOXEL, VOXEL, tall) * 0.9, rune, group)
	for i in 4:
		var x := -0.034 + i * 0.0227
		_fill(Vector3(x - 0.005, 0.041, -0.372 + (i % 2) * 0.006), Vector3(x + 0.005, 0.05, -0.352), rune, group)


# --- Ultimate-ready glow -----------------------------------------------------------

## Builds each hand's glow (hidden until the ultimate is ready): a light, plus
## embers (Mauler), violet speed streaks and a wrist ring (Blur), lightning
## (Answer) or green energy ribbons (Stray).
func _build_effect(arm: Node3D, side: float) -> void:
	var hand := "left" if side < 0.0 else "right"
	var fx := {}
	var light := OmniLight3D.new()
	light.light_cull_mask = HAND_LAYER
	light.light_color = _accent
	light.light_energy = 0.0
	light.omni_range = 0.6
	light.position = _mirror_pos(Vector3(0.0, 0.08, -0.3), side)
	arm.add_child(light)
	fx.light = light
	var particles := CPUParticles3D.new()
	particles.local_coords = false
	particles.position = _mirror_pos(FIST_POINT, side)
	particles.emitting = false
	particles.layers = HAND_LAYER
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.007
	bit.material = _glow(_accent, 1.4)
	particles.mesh = bit
	fx.bit = bit.material
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.07
	match fighter:
		"berserker":  # Embers and sparks rising off the gloves.
			particles.amount = 28
			particles.lifetime = 0.9
			particles.direction = Vector3(0, 1, 0)
			particles.spread = 40.0
			particles.gravity = Vector3(0, 0.3, 0)
			particles.initial_velocity_min = 0.05
			particles.initial_velocity_max = 0.3
			particles.scale_amount_min = 0.6
			particles.scale_amount_max = 1.8
		"combo_master":  # Speed streaks trailing back along the arm.
			var streak := BoxMesh.new()
			streak.size = Vector3(0.003, 0.003, 0.06)
			streak.material = _glow(_accent, 2.0)
			particles.mesh = streak
			particles.amount = 22
			particles.lifetime = 0.3
			particles.direction = Vector3(0, 0, 1)
			particles.spread = 15.0
			particles.gravity = Vector3.ZERO
			particles.initial_velocity_min = 0.4
			particles.initial_velocity_max = 0.9
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.062
			torus.outer_radius = 0.07
			torus.rings = 24
			torus.ring_segments = 4
			torus.material = _glow(_accent, 1.5)
			ring.mesh = torus
			ring.position = _mirror_pos(Vector3(0, 0, -0.255), side)
			ring.rotation = Vector3(PI / 2, 0, 0)
			ring.visible = false
			ring.layers = HAND_LAYER
			arm.add_child(ring)
			fx.ring = ring
		"counter_master":  # Sparks; the lightning itself is rebuilt every few frames.
			particles.amount = 20
			particles.lifetime = 0.25
			particles.spread = 180.0
			particles.gravity = Vector3.ZERO
			particles.initial_velocity_min = 0.2
			particles.initial_velocity_max = 0.6
			var bolts := Node3D.new()
			bolts.visible = false
			arm.add_child(bolts)
			var segments: Array[MeshInstance3D] = []
			var bolt_material := _glow(Color(0.75, 0.9, 1.0), 6.0)
			for i in 14:
				var segment := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.004, 0.004, 1.0)
				box.material = bolt_material
				segment.mesh = box
				segment.layers = HAND_LAYER
				bolts.add_child(segment)
				segments.append(segment)
			fx.bolts = bolts
			fx.segments = segments
			fx.side = side
		"elementalist":  # Sparks rising off the runes.
			particles.amount = 20
			particles.lifetime = 0.8
			particles.direction = Vector3.UP
			particles.spread = 50.0
			particles.gravity = Vector3(0, 0.4, 0)
			particles.initial_velocity_min = 0.05
			particles.initial_velocity_max = 0.25
		"wise_guy":  # Gold bling: sparkles drifting off the knuckles.
			particles.amount = 22
			particles.lifetime = 0.7
			particles.direction = Vector3.UP
			particles.spread = 60.0
			particles.gravity = Vector3(0, -0.4, 0)
			particles.initial_velocity_min = 0.1
			particles.initial_velocity_max = 0.35
		"free_runner":  # Green energy ribbons spinning around the forearm.
			particles.amount = 14
			particles.lifetime = 0.35
			particles.direction = Vector3(0, 0, 1)
			particles.spread = 25.0
			particles.gravity = Vector3.ZERO
			particles.initial_velocity_min = 0.3
			particles.initial_velocity_max = 0.7
			var ribbons := Node3D.new()
			ribbons.visible = false
			arm.add_child(ribbons)
			var ribbon_material := _glow(_accent.darkened(0.25), 1.2)
			var spinners: Array[Node3D] = []
			for r in 3:
				var spinner := Node3D.new()
				spinner.position = Vector3(0, 0, -0.27 + r * 0.09)
				spinner.rotation.z = r * 2.1
				ribbons.add_child(spinner)
				for k in 14:
					var piece := MeshInstance3D.new()
					var box := BoxMesh.new()
					box.size = Vector3(0.009, 0.009, 0.034)
					box.material = ribbon_material
					piece.mesh = box
					piece.layers = HAND_LAYER
					var angle := k * 0.2
					var radius := 0.07 + r * 0.01
					piece.position = Vector3(cos(angle) * radius, sin(angle) * radius, -k * 0.01)
					piece.rotation = Vector3(0, 0, angle)
					spinner.add_child(piece)
				spinners.append(spinner)
			fx.ribbons = ribbons
			fx.spinners = spinners
	arm.add_child(particles)
	fx.particles = particles
	_fx[hand] = fx


func _update_effects(delta: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 7.0)
	var rim: StandardMaterial3D = _materials.rim
	rim.emission_energy_multiplier = (0.6 + pulse * 0.9) if _ult_ready else 0.0
	if fighter == "elementalist":
		var colors := _rune_colors()
		for i in 2:
			var rune: StandardMaterial3D = _materials["rune_left" if i == 0 else "rune_right"]
			rune.emission = colors[i]
			rune.emission_energy_multiplier = (0.5 + pulse * 0.7) if _ult_ready else 0.0
			var side := "left" if i == 0 else "right"
			var flash: Array = _rune_flash.get(side, [])
			var flare := 0.0
			if not flash.is_empty() and flash[1] > 0.0:
				flash[1] -= delta
				flare = clampf(flash[1] / RUNE_FLASH, 0.0, 1.0)
				rune.emission = flash[0]
				rune.emission_energy_multiplier = maxf(rune.emission_energy_multiplier, 4.0 * flare)
			# The hand's own light takes its rune's color too.
			var hand_fx: Dictionary = _fx.get(side, {})
			hand_fx["flare"] = flare
			if hand_fx.has("light"):
				(hand_fx.light as OmniLight3D).light_color = flash[0] if flare > 0.0 else colors[i]
				var sparks: StandardMaterial3D = hand_fx.bit
				sparks.albedo_color = colors[i]
				sparks.emission = colors[i]
	_bolt_timer -= delta
	var rebuild_bolts := _bolt_timer <= 0.0
	if rebuild_bolts:
		_bolt_timer = 0.06
	for hand in _fx:
		var fx: Dictionary = _fx[hand]
		# The Catalyst's pale tape washes out under a strong light.
		var light_scale := 0.3 if fighter == "elementalist" else 1.0
		(fx.light as OmniLight3D).light_energy = maxf((0.3 + pulse * 0.3) * light_scale if _ult_ready else 0.0, 0.5 * float(fx.get("flare", 0.0)))
		var particles: CPUParticles3D = fx.particles
		particles.emitting = _ult_ready
		match fighter:
			"combo_master":
				(fx.ring as MeshInstance3D).visible = _ult_ready
				(fx.ring as MeshInstance3D).rotation.y = _time * 3.0
			"counter_master":
				# Lightning on the ultimate; just sparks on a hand that's ready to counter.
				particles.emitting = _ult_ready or _hot_hand == hand or _hot_hand == "any"
				(fx.bolts as Node3D).visible = _ult_ready
				if _ult_ready and rebuild_bolts:
					_crackle(fx)
			"free_runner":
				(fx.ribbons as Node3D).visible = _ult_ready
				var spinners: Array = fx.spinners
				for i in spinners.size():
					(spinners[i] as Node3D).rotation.z += delta * (7.0 + i * 2.5) * (1.0 if i % 2 == 0 else -1.0)


## [left, right] rune colors: his picks (Dual Sigil), the one (Attunement),
## or every owned power taking turns (Prism).
func _rune_colors() -> Array:
	var owned: Array = GameState.owned_powers()
	if owned.is_empty():
		return [_accent, _accent]
	if GameState.passive() == "prism":
		var step := int(_time * 1.5)
		return [POWER_COLORS[owned[step % owned.size()]], POWER_COLORS[owned[(step + 1) % owned.size()]]]
	var first: Color = POWER_COLORS.get(GameState.power_pick, _accent)
	var second: Color = POWER_COLORS.get(GameState.power_pick_2, first) if GameState.passive() == "dual_sigil" else first
	return [second, first]


## Two jagged bolts crawling along the arm's surface, rebuilt each flicker.
func _crackle(fx: Dictionary) -> void:
	var segments: Array = fx.segments
	var side: float = fx.side
	var used := 0
	for bolt in 2:
		var angle := randf() * TAU
		var point := Vector3(cos(angle) * 0.055, sin(angle) * 0.05, -0.4)
		for step in 7:
			if used >= segments.size():
				return
			angle += randf_range(-0.9, 0.9)
			var next := Vector3(cos(angle) * randf_range(0.05, 0.07), sin(angle) * randf_range(0.045, 0.065), point.z + randf_range(0.03, 0.06))
			var segment: MeshInstance3D = segments[used]
			var a := _mirror_pos(point, side)
			var b := _mirror_pos(next, side)
			segment.position = (a + b) / 2.0
			if not a.is_equal_approx(b):
				segment.basis = Basis.looking_at(b - a, Vector3.UP)
				segment.scale = Vector3(1, 1, a.distance_to(b))
			segment.visible = true
			point = next
			used += 1
	for i in range(used, segments.size()):
		(segments[i] as MeshInstance3D).visible = false


## A violet ghost of the fist where the arm is right now, fading fast.
func _afterimage(arm: Node3D) -> void:
	if not is_inside_tree():
		return
	var ghost := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.1, 0.08, 0.11)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(_accent, 0.4)
	box.material = material
	ghost.mesh = box
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.layers = HAND_LAYER
	add_child(ghost)
	ghost.transform = arm.transform * Transform3D(Basis.IDENTITY, FIST_POINT)
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.2)
	tween.tween_callback(ghost.queue_free)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _mirror_pos(offset: Vector3, mirror: float) -> Vector3:
	return Vector3(offset.x * mirror, offset.y, offset.z)


func _mirror_rot(offset: Vector3, mirror: float) -> Vector3:
	return Vector3(offset.x, offset.y * mirror, offset.z * mirror)
