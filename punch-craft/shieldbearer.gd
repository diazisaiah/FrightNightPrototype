class_name Shieldbearer
extends Boxer
## A skeleton soldier behind a tower shield (Crypt). The shield stops jabs,
## crosses and uppercuts from the front; hooks wrap around it, and any
## counter gets through. It shoves with the shield (slip it, then counter)
## and chops overhead with its blade (back step).

const COMBOS := [["bash"], ["bash"], ["bash", "bash"], ["slam"], ["bash", "slam"]]


func blocks_punch(punch_type: String, counter: bool) -> bool:
	# Staggered, it's dropped its guard.
	return not counter and punch_type != "hook" and _stagger_timer <= 0.0


## The shield arm swings in across the body and stays upright: the shield
## covers it, facing the player. A bash shoves it straight out, still upright.
func _arm_pose(arm: String) -> Array:
	if arm != "left":
		return super(arm)
	if _attack == "bash" and _state == State.STRIKE:
		return [Vector3(-0.3, -0.55, 0), -0.45, Vector3(1.8, 0, 0)]
	if _attack == "bash" and _state == State.WINDUP:
		return [Vector3(-0.7, -0.7, 0), 0.25, Vector3(2.1, 0, 0)]
	return [Vector3(-0.5, -0.8, 0), 0.0, Vector3(2.0, 0, 0)]


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.6, 1.1)


func _build_body() -> void:
	_body.scale = Vector3.ONE * 1.05
	var bone := _material(Color(0.82, 0.8, 0.72))
	var iron := _material(Color(0.3, 0.3, 0.33), 0.75)
	var eyes := _glow_material(Color(0.4, 0.85, 1.0))
	for side in [-1.0, 1.0]:
		_part(_body, _cylinder(0.045, 0.9), bone, Vector3(0.11 * side, 0.45, 0))
	_part(_body, _box(Vector3(0.34, 0.12, 0.18)), bone, Vector3(0, 0.93, 0))
	_part(_body, _cylinder(0.04, 0.5), bone, Vector3(0, 1.18, 0))
	for i in 3:
		_part(_body, _box(Vector3(0.38 - i * 0.04, 0.045, 0.22)), bone, Vector3(0, 1.42 - i * 0.1, 0))
	# Rusted helm over the skull.
	_part(_body, _box(Vector3(0.3, 0.3, 0.3)), bone, Vector3(0, 1.72, 0))
	_part(_body, _box(Vector3(0.34, 0.16, 0.34)), iron, Vector3(0, 1.84, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.05, 0.04, 0.02)), eyes, Vector3(0.07 * side, 1.72, -0.155))
	_build_arms(bone, Color(0.8, 0.78, 0.7), 1.48, 0.27)
	# A tall tower shield strapped along the left forearm (which it holds
	# upright), covering head to knees.
	_hold_weapon("left", _box(Vector3(0.75, 0.08, 1.15)), Color(0.32, 0.25, 0.18), Vector3(0, 0.14, -0.5))
	_hold_weapon("left", _box(Vector3(0.8, 0.1, 0.08)), Color(0.4, 0.4, 0.44), Vector3(0, 0.15, -1.05))
	# A short blade in the right hand.
	_hold_weapon("right", _box(Vector3(0.05, 0.02, 0.7)), Color(0.7, 0.7, 0.75), Vector3(0, 0, -0.85))


func _build_armor() -> void:
	var iron := _material(Color(0.35, 0.33, 0.35), 0.7)
	_part(_body, _box(Vector3(0.42, 0.42, 0.28)), iron, Vector3(0, 1.32, 0))
