class_name GraveBruiser
extends Boxer
## Grave Bruiser (deeper tiers, the zombie's big brother): a hulking dead
## man who clubs with both arms (back step) and hooks, and tackles: a lane
## lights the ground toward you, then it bull-rushes a few meters. Step out
## of the lane or roll it.

const COMBOS := [["slam"], ["jab", "slam"], ["cross", "slam"], ["left_hook", "right_hook"], ["jab", "cross"]]


func _ready() -> void:
	special_kit = ["dash"]
	special_every = 7.0
	special_first = 3.0
	super()


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.7, 1.3)


func _build_body() -> void:
	_body.scale = Vector3.ONE * randf_range(1.12, 1.2)
	var skin := _material(Color(0.33, 0.42, 0.29))
	var shirt := _material(Color(0.24, 0.2, 0.16))
	var pants := _material(Color(0.16, 0.15, 0.2))
	var bone := _material(Color(0.8, 0.77, 0.68))
	var eyes := _glow_material(Color(1.0, 0.25, 0.08))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.22, 0.9, 0.24)), pants, Vector3(0.15 * side, 0.45, 0))
	_part(_body, _box(Vector3(0.66, 0.7, 0.38)), shirt, Vector3(0, 1.25, 0))
	# The shirt's torn open over a sunken chest.
	_part(_body, _box(Vector3(0.28, 0.4, 0.04)), skin, Vector3(0.08, 1.3, -0.19))
	for i in 3:
		_part(_body, _box(Vector3(0.22, 0.03, 0.03)), bone, Vector3(0.08, 1.2 + i * 0.09, -0.215))
	# A heavy head hunched low between bony shoulders.
	_part(_body, _box(Vector3(0.34, 0.32, 0.32)), skin, Vector3(0, 1.72, -0.06))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.08, 0.045, 0.02)), eyes, Vector3(0.08 * side, 1.75, -0.225))
		_part(_body, _box(Vector3(0.24, 0.16, 0.3)), bone, Vector3(0.36 * side, 1.6, 0))
	_part(_body, _box(Vector3(0.16, 0.05, 0.02)), _material(Color(0.1, 0.05, 0.04)), Vector3(0, 1.63, -0.225))
	_build_arms(skin, Color(0.3, 0.36, 0.24), 1.5, 0.36)


func _build_armor() -> void:
	var iron := _material(Color(0.42, 0.42, 0.46), 0.8)
	_part(_body, _box(Vector3(0.7, 0.5, 0.42)), iron, Vector3(0, 1.3, 0))
	_part(_body, _box(Vector3(0.38, 0.16, 0.36)), iron, Vector3(0, 1.9, -0.06))
