class_name Runner
extends Boxer
## Fast zombie that sprints at the player and throws one big looping haymaker.
## The arm swings way back and the fist glows orange: roll under it (either
## way). A dodged haymaker leaves it wide open.


func _pick_combo() -> Array:
	return ["haymaker"]


func _idle_time() -> float:
	return randf_range(0.2, 0.6)


func _build_body() -> void:
	_body.scale = Vector3(0.95, randf_range(1.02, 1.1), 0.95)
	var skin := _material(Color(0.45, 0.5, 0.36))
	var shirt := _material(Color(0.35, 0.18, 0.12))
	var pants := _material(Color(0.18, 0.2, 0.25))
	var eyes := _glow_material(Color(1.0, 0.45, 0.1))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.15, 0.9, 0.17)), pants, Vector3(0.12 * side, 0.45, 0))
	# Hunched forward, like it's always mid-sprint.
	_part(_body, _box(Vector3(0.44, 0.6, 0.26)), shirt, Vector3(0, 1.22, -0.04), Vector3(-0.15, 0, 0))
	_part(_body, _box(Vector3(0.28, 0.3, 0.28)), skin, Vector3(0, 1.7, -0.1))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.04, 0.02)), eyes, Vector3(0.07 * side, 1.74, -0.245))
	_build_arms(skin, Color(0.5, 0.55, 0.4), 1.45, 0.28)


func _build_armor() -> void:
	var iron := _material(Color(0.45, 0.46, 0.5), 0.8)
	_part(_body, _box(Vector3(0.34, 0.16, 0.34)), iron, Vector3(0, 1.86, -0.1))
	_part(_body, _box(Vector3(0.5, 0.42, 0.32)), iron, Vector3(0, 1.25, -0.04), Vector3(-0.15, 0, 0))
