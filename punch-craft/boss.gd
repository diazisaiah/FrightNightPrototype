class_name Boss
extends Boxer
## The Grave Champion: a giant armored boxer and the last wave of every night.
## Throws long combos and slams. Below half HP it gets faster and raises zombies.

## Asks the world to raise this many zombies around the boss.
signal summon_requested(count: int)
signal health_changed(current: float, maximum: float)

const SCALE := 1.5
const ENRAGE_FRACTION := 0.5
const ENRAGED_WINDUP_SCALE := 0.8
const SUMMON_COUNT := 3
const COMBOS := [
	["jab", "cross"], ["jab", "cross", "left_hook"], ["jab", "jab", "right_hook", "uppercut"],
	["left_hook", "right_hook", "slam"], ["cross", "left_hook", "cross"], ["slam"],
	["jab", "cross", "left_hook", "right_hook"],
]
const ENRAGED_COMBOS := [
	["jab", "cross", "left_hook", "uppercut"], ["jab", "jab", "cross", "right_hook", "slam"],
	["left_hook", "right_hook", "left_hook", "uppercut"], ["slam", "jab", "cross"],
]

var _enraged := false


func _init() -> void:
	combo_armor = true  # Counters can't break a boss's combo, only punish its end.


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	# Too heavy to be knocked around much.
	var dealt := super(raw_damage, hit_point, push * 0.3, stagger, caption, pierce, crush)
	health_changed.emit(maxf(hp, 0.0), max_hp)
	if not _enraged and hp > 0.0 and hp <= max_hp * ENRAGE_FRACTION:
		_enrage()
	return dealt


func heal(amount: float) -> float:
	var restored := super(amount)
	health_changed.emit(hp, max_hp)
	return restored


func _enrage() -> void:
	_enraged = true
	windup_scale = ENRAGED_WINDUP_SCALE
	move_speed *= 1.2
	DamagePopup.spawn(get_parent(), "ENRAGED", Color(0.8, 0.3, 1.0), 64, global_position + Vector3(0, 3.2, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.4, 4.0, 0.6)
	summon_requested.emit(SUMMON_COUNT)


func _pick_combo() -> Array:
	return (ENRAGED_COMBOS if _enraged else COMBOS).pick_random()


func _idle_time() -> float:
	return randf_range(0.4, 0.8) if _enraged else randf_range(0.7, 1.3)


func _update_label() -> void:
	pass  # The HUD shows the boss health bar instead.


func _build_body() -> void:
	_body.scale = Vector3.ONE * SCALE
	var skin := _material(Color(0.3, 0.28, 0.33))
	var cloth := _material(Color(0.12, 0.08, 0.16))
	var bone := _material(Color(0.82, 0.8, 0.72))
	var eyes := _glow_material(Color(0.75, 0.3, 1.0))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.2, 0.9, 0.22)), cloth, Vector3(0.14 * side, 0.45, 0))
	_part(_body, _box(Vector3(0.6, 0.6, 0.34)), skin, Vector3(0, 1.22, 0))
	_part(_body, _box(Vector3(0.3, 0.32, 0.3)), skin, Vector3(0, 1.72, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.07, 0.045, 0.02)), eyes, Vector3(0.07 * side, 1.76, -0.155))
		# Bone horns.
		_part(_body, _box(Vector3(0.05, 0.22, 0.05)), bone, Vector3(0.12 * side, 1.98, 0), Vector3(0, 0, -0.35 * side))
	_build_arms(skin, Color(0.25, 0.05, 0.3), 1.45, 0.34)


func _build_armor() -> void:
	var iron := _material(Color(0.22, 0.2, 0.25), 0.85)
	_part(_body, _box(Vector3(0.66, 0.5, 0.4)), iron, Vector3(0, 1.28, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.24, 0.14, 0.3)), iron, Vector3(0.36 * side, 1.52, 0))
