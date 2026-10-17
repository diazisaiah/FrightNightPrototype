class_name BoneCrusher
extends Boxer
## Bone Crusher (deeper tiers, the hulk's big brother): a giant in bone
## plate that boxes, then caps its combos with a ground slam: both fists go
## up, a ring lights around it, and the canvas cracks. Get out of the ring or
## jump it, then punish it while it's bent over.

const COMBOS := [["jab", "cross"], ["cross", "jab"], ["jab", "jab", "cross"], ["right_hook", "left_hook"]]


func _ready() -> void:
	special_kit = ["ground_slam"]
	special_every = 4.5
	special_first = 2.0
	super()


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.6, 1.1)


func _build_body() -> void:
	_body.scale = Vector3.ONE * 1.45
	var hide := _material(Color(0.3, 0.3, 0.34))
	var bone := _material(Color(0.85, 0.82, 0.72))
	var dark := _material(Color(0.07, 0.06, 0.06))
	var eyes := _glow_material(Color(1.0, 0.55, 0.1))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.24, 0.9, 0.26)), hide, Vector3(0.16 * side, 0.45, 0))
		_part(_body, _box(Vector3(0.26, 0.2, 0.3)), bone, Vector3(0.16 * side, 0.55, -0.02))  # Knee guards.
	_part(_body, _box(Vector3(0.72, 0.74, 0.44)), hide, Vector3(0, 1.28, 0))
	# Bone plates: a breastplate of ribs and huge shoulder bones.
	for i in 4:
		_part(_body, _box(Vector3(0.6 - i * 0.06, 0.06, 0.06)), bone, Vector3(0, 1.12 + i * 0.13, -0.24))
	_part(_body, _box(Vector3(0.08, 0.5, 0.06)), bone, Vector3(0, 1.3, -0.25))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.32, 0.22, 0.4)), bone, Vector3(0.42 * side, 1.62, 0))
		_part(_body, _box(Vector3(0.08, 0.26, 0.08)), bone, Vector3(0.5 * side, 1.82, 0.05), Vector3(0, 0, -0.5 * side))
	# A skull helm over a small head, eyes burning in the sockets.
	_part(_body, _box(Vector3(0.34, 0.34, 0.34)), bone, Vector3(0, 1.8, -0.04))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.1, 0.08, 0.02)), dark, Vector3(0.08 * side, 1.82, -0.215))
		_part(_body, _box(Vector3(0.06, 0.04, 0.02)), eyes, Vector3(0.08 * side, 1.82, -0.225))
	_part(_body, _box(Vector3(0.2, 0.05, 0.02)), dark, Vector3(0, 1.7, -0.215))
	_build_arms(hide, Color(0.85, 0.82, 0.72), 1.5, 0.4)


func _build_armor() -> void:
	var iron := _material(Color(0.35, 0.33, 0.36), 0.8)
	_part(_body, _box(Vector3(0.76, 0.5, 0.48)), iron, Vector3(0, 1.32, 0))
