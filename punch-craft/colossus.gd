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


func _build_body() -> void:
	_body.scale = Vector3.ONE * COLOSSUS_SCALE
	var bone := _material(Color(0.78, 0.75, 0.66))
	var dark_bone := _material(Color(0.55, 0.52, 0.45))
	var eyes := _glow_material(Color(0.4, 0.9, 1.0))
	_core = _glow_material(Color(0.45, 0.95, 1.0))
	for side in [-1.0, 1.0]:
		_part(_body, _cylinder(0.06, 0.9), bone, Vector3(0.14 * side, 0.45, 0))
	_part(_body, _box(Vector3(0.42, 0.14, 0.22)), dark_bone, Vector3(0, 0.95, 0))
	_part(_body, _cylinder(0.05, 0.5), bone, Vector3(0, 1.2, 0))
	# Ribcage around the glowing core: the weak spot.
	_part(_body, _box(Vector3(0.2, 0.2, 0.2)), _core, Vector3(0, 1.3, 0))
	for i in 4:
		_part(_body, _box(Vector3(0.5 - i * 0.04, 0.045, 0.3)), bone, Vector3(0, 1.48 - i * 0.1, 0))
	_part(_body, _box(Vector3(0.34, 0.32, 0.34)), bone, Vector3(0, 1.75, 0))
	_part(_body, _box(Vector3(0.26, 0.08, 0.26)), dark_bone, Vector3(0, 1.57, -0.04))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.07, 0.06, 0.02)), eyes, Vector3(0.08 * side, 1.77, -0.175))
	_build_arms(bone, Color(0.6, 0.57, 0.5), 1.5, 0.34)


func _build_armor() -> void:
	var iron := _material(Color(0.3, 0.28, 0.3), 0.7)
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.22, 0.12, 0.3)), iron, Vector3(0.36 * side, 1.56, 0))
