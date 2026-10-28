class_name Colossus
extends Boss
## The Bone Colossus (floor 2 boss): a giant skeleton built from a hundred
## graves. Slow, huge slams (back step) and wide sweeps of its arm (roll).
## Its head is far out of reach, but the glowing core in its ribcage is the
## weak spot: punches aimed up into it do double damage through its armor. Below half
## HP it speeds up; it doesn't summon.

const COLOSSUS_SCALE := 2.2
const CORE_MULTIPLIER := 2.0
## The core's height on the (unscaled) body.
const CORE_LOW := 1.1
const CORE_HIGH := 1.5
const COLOSSUS_COMBOS := [["slam"], ["sweep"], ["sweep", "slam"], ["slam", "sweep"], ["sweep", "sweep"]]
const ENRAGED_COLOSSUS_COMBOS := [["sweep", "slam"], ["slam", "sweep", "slam"], ["sweep", "sweep", "slam"]]

var _core: StandardMaterial3D


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	# The core sits in the ribcage, well above the player's eye line: aim up.
	var height := to_local(hit_point).y / _body.scale.y
	if height > CORE_LOW and height < CORE_HIGH:
		raw_damage *= CORE_MULTIPLIER
		pierce = true
		caption = "CORE!" if caption == "" else caption + "\nCORE"
	return super(raw_damage, hit_point, push * 0.3, stagger, caption, pierce, crush)


func _enrage() -> void:
	_enraged = true
	windup_scale = ENRAGED_WINDUP_SCALE
	move_speed *= 1.2
	DamagePopup.spawn(get_parent(), "ENRAGED", Color(0.8, 0.3, 1.0), 64, global_position + Vector3(0, 4.5, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 3.0, 4.0, 0.45)


func _pick_combo() -> Array:
	return (ENRAGED_COLOSSUS_COMBOS if _enraged else COLOSSUS_COMBOS).pick_random()


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	_core.emission_energy_multiplier = 3.0 + 1.5 * sin(Time.get_ticks_msec() * 0.005)




const COLOSSUS := {
	"foot": Vector3(0.16, 0.08, 0.28), "lower_leg": 0.38, "upper_leg": 0.38, "hip": 0.32,
	"torso_h": 0.78, "shoulder": 0.8, "upper_arm": 0.38, "forearm": 0.36,
	"head": Vector3(0.34, 0.32, 0.34), "guard": 0.6, "style": "lumber", "pace": 0.7,
}


## A giant skeleton built from a hundred graves: mismatched leg bones, an
## open ribcage around the glowing core (the weak spot), shoulders heaped
## with skulls, broken shackles on the wrists, a cracked tombstone hung on a
## chain for a loincloth, and a huge skull with burning blue eyes.
func _build_body() -> void:
	_body.scale = Vector3.ONE * COLOSSUS_SCALE
	var bone := _material(Color(0.8, 0.77, 0.68))
	var bone_old := _material(Color(0.68, 0.64, 0.54))
	var dark_bone := _material(Color(0.5, 0.47, 0.4))
	var dark := _material(Color(0.05, 0.05, 0.06))
	var stone := _material(Color(0.42, 0.42, 0.44))
	var iron := _material(Color(0.2, 0.19, 0.2), 0.6)
	var eyes := _glow_material(Color(0.4, 0.9, 1.0))
	_core = _glow_material(Color(0.45, 0.95, 1.0))
	_rig_body(COLOSSUS, Color(0.66, 0.62, 0.54))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.16 * side
		_on("foot" + s, _box(Vector3(0.16, 0.06, 0.24)), bone_old, Vector3(x, 0.03, -0.03))
		for t in 3:
			_on("foot" + s, _box(Vector3(0.04, 0.04, 0.07)), bone, Vector3(x + (t - 1) * 0.05, 0.03, -0.18))
		_on("shin" + s, _box(Vector3(0.09, 0.34, 0.09)), bone, Vector3(x, 0.27, 0))
		_on("shin" + s, _box(Vector3(0.04, 0.3, 0.04)), dark_bone, Vector3(x + 0.05 * side, 0.27, 0.03))
		_on("shin" + s, _box(Vector3(0.13, 0.08, 0.12)), bone_old, Vector3(x, 0.47, -0.02))
		_on("thigh" + s, _box(Vector3(0.1, 0.36, 0.1)), bone, Vector3(x, 0.66, 0))
		_on("thigh" + s, _sphere(0.07), bone_old, Vector3(x, 0.84, 0))
	# The hips, and a cracked tombstone hung on a chain in front.
	_on("pelvis", _box(Vector3(0.4, 0.14, 0.24)), dark_bone, Vector3(0, 0.86, 0))
	for side: float in [-1.0, 1.0]:
		_on("pelvis", _box(Vector3(0.13, 0.15, 0.1)), bone_old, Vector3(0.19 * side, 0.9, 0), Vector3(0, 0, 0.3 * side))
	_on("sash", _box(Vector3(0.26, 0.32, 0.06)), stone, Vector3(0, 0.62, -0.17))
	_on("sash", _box(Vector3(0.2, 0.06, 0.065)), stone, Vector3(0, 0.8, -0.17))
	_on("sash", _box(Vector3(0.015, 0.16, 0.01)), dark, Vector3(0.03, 0.62, -0.204), Vector3(0, 0, 0.5))
	_on("sash", _box(Vector3(0.1, 0.02, 0.01)), dark, Vector3(0, 0.7, -0.204))
	for side: float in [-1.0, 1.0]:
		_chain_on("sash", Vector3(0.18 * side, 0.92, -0.1), Vector3(0.1 * side, 0.82, -0.17), 3, iron)
	# The spine, the core, and the open ribcage around it.
	for i in 4:
		_on("spine", _box(Vector3(0.1, 0.07, 0.1)), bone, Vector3(0, 0.96 + i * 0.09, 0.08))
	_on("spine", _box(Vector3(0.22, 0.22, 0.22)), _core, Vector3(0, 1.28, -0.02))
	for i in 5:
		var y := 1.54 - i * 0.085
		var w := 0.26 - absf(i - 1.5) * 0.025
		for side: float in [-1.0, 1.0]:
			_on("chest", _box(Vector3(0.05, 0.04, 0.3)), bone if i % 2 == 0 else bone_old, Vector3(w * side, y, 0.0))
			_on("chest", _box(Vector3(0.14, 0.04, 0.045)), bone, Vector3((w - 0.07) * side, y - 0.01, -0.15), Vector3(0, 0, 0.12 * side))
		_on("chest", _box(Vector3(w * 2.0, 0.04, 0.045)), bone_old, Vector3(0, y, 0.15))
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.34, 0.06, 0.07)), bone, Vector3(0.2 * side, 1.62, -0.06), Vector3(0, 0, -0.1 * side))
		_on("chest", _box(Vector3(0.18, 0.22, 0.04)), bone_old, Vector3(0.18 * side, 1.5, 0.17))
		# A heap of grave skulls on each shoulder.
		var s := "_l" if side < 0.0 else "_r"
		for k in 3:
			var at := Vector3((0.4 + 0.06 * (k % 2)) * side, 1.45 + 0.08 * (k / 2), -0.08 + k * 0.08)
			_on("clavicle" + s, _box(Vector3(0.12, 0.11, 0.12)), bone if k != 1 else bone_old, at, Vector3(0, 0.4 * k * side, 0))
			_on("clavicle" + s, _box(Vector3(0.08, 0.03, 0.02)), dark, at + Vector3(0, 0.0, -0.065).rotated(Vector3.UP, 0.4 * k * side))
	# The skull.
	_on("neck", _box(Vector3(0.08, 0.14, 0.08)), bone, Vector3(0, 1.68, 0.02))
	_on("head", _box(Vector3(0.34, 0.28, 0.34)), bone, Vector3(0, 1.86, -0.02))
	_on("head", _box(Vector3(0.36, 0.06, 0.1)), bone_old, Vector3(0, 1.9, -0.16))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.1, 0.08, 0.03)), dark, Vector3(0.08 * side, 1.84, -0.19))
		_on("head", _box(Vector3(0.06, 0.04, 0.02)), eyes, Vector3(0.08 * side, 1.84, -0.2))
		_on("head", _box(Vector3(0.09, 0.06, 0.1)), bone_old, Vector3(0.13 * side, 1.77, -0.13))
	_on("head", _box(Vector3(0.05, 0.06, 0.02)), dark, Vector3(0, 1.77, -0.19))
	_on("head", _box(Vector3(0.28, 0.08, 0.28)), bone_old, Vector3(0, 1.69, -0.04))
	for t in 6:
		_on("head", _box(Vector3(0.03, 0.04, 0.02)), bone, Vector3(-0.1 + t * 0.04, 1.73, -0.18))
	_on("head", _box(Vector3(0.015, 0.14, 0.01)), dark, Vector3(-0.08, 1.95, -0.172), Vector3(0, 0, -0.4))
	# Long bone arms: a ball shoulder, the humerus, an elbow knob, two
	# forearm bones, a broken shackle, and a fist of bone.
	for arm in ["left", "right"]:
		var side := -1.0 if arm == "left" else 1.0
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _sphere(0.1), bone_old, Vector3.ZERO)
		_at("upper_arm" + s, _box(Vector3(0.1, 0.32, 0.1)), bone, Vector3(0, -0.19, 0))
		_at("forearm" + s, _sphere(0.075), bone_old, Vector3.ZERO)
		for k: float in [-1.0, 1.0]:
			_at("forearm" + s, _box(Vector3(0.055, 0.32, 0.055)), bone if k < 0.0 else dark_bone, Vector3(k * 0.035, -0.17, 0))
		_at("forearm" + s, _box(Vector3(0.14, 0.06, 0.14)), iron, Vector3(0, -0.31, 0))
		_chain(_rig.bone("forearm" + s), Vector3(0.06 * side, -0.33, 0), Vector3(0.1 * side, -0.5, 0.04), 3, iron)
		var glove: StandardMaterial3D = _gloves[arm]
		_at("hand" + s, _box(Vector3(0.18, 0.12, 0.16)), glove, Vector3(0, -0.07, 0))
		for k in 4:
			_at("hand" + s, _box(Vector3(0.04, 0.1, 0.05)), glove, Vector3((k - 1.5) * 0.045, -0.17, -0.03))
		_at("hand" + s, _box(Vector3(0.05, 0.09, 0.05)), glove, Vector3(-side * 0.1, -0.08, -0.05))


func _build_armor() -> void:
	var iron := _material(Color(0.3, 0.28, 0.3), 0.7)
	for side: float in [-1.0, 1.0]:
		_on("clavicle_l" if side < 0.0 else "clavicle_r", _box(Vector3(0.28, 0.12, 0.34)), iron, Vector3(0.42 * side, 1.72, 0))


## The Colossus still wears its gear (the Champion, a Boss too, doesn't).
func _gear_style() -> String:
	return "plate"
