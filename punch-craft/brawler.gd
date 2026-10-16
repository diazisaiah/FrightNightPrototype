class_name Brawler
extends Boxer
## Ghoul Brawler: a dead prizefighter. Closes in with footwork and throws
## boxing combos; its wrapped fists glow in the defense color during windups.

const COMBOS := [
	["jab"], ["cross"], ["left_hook"], ["right_hook"], ["uppercut"],
	["jab", "cross"], ["jab", "jab", "cross"], ["jab", "right_hook"],
	["jab", "cross", "left_hook"], ["cross", "left_hook", "uppercut"],
	["left_hook", "right_hook"],
]


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.5, 1.2)


func _build_body() -> void:
	_body.scale = Vector3.ONE * randf_range(0.97, 1.08)
	var skin := _material(Color(0.42, 0.45, 0.4))
	var shorts := _material(Color(0.45, 0.08, 0.08))
	var belt := _material(Color(0.75, 0.62, 0.2), 0.6)
	var eyes := _glow_material(Color(0.6, 1.0, 0.4))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.17, 0.55, 0.19)), skin, Vector3(0.13 * side, 0.28, 0))
		_part(_body, _box(Vector3(0.19, 0.36, 0.21)), shorts, Vector3(0.13 * side, 0.73, 0))
	_part(_body, _box(Vector3(0.5, 0.08, 0.3)), belt, Vector3(0, 0.93, 0))
	_part(_body, _box(Vector3(0.52, 0.55, 0.3)), skin, Vector3(0, 1.24, 0))
	_part(_body, _box(Vector3(0.28, 0.3, 0.28)), skin, Vector3(0, 1.72, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.04, 0.02)), eyes, Vector3(0.07 * side, 1.76, -0.145))
	_build_arms(skin, Color(0.55, 0.5, 0.42))


func _build_armor() -> void:
	var iron := _material(Color(0.45, 0.46, 0.5), 0.8)
	_part(_body, _box(Vector3(0.34, 0.16, 0.34)), iron, Vector3(0, 1.88, 0))
	_part(_body, _box(Vector3(0.56, 0.45, 0.34)), iron, Vector3(0, 1.27, 0))
