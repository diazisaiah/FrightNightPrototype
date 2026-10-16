class_name PossessedArmor
extends Boxer
## An empty suit of plate armor with a cursed sword. Hits hard and its plate
## blocks most punches, but the joints at its sides are open: hooks hit them
## for big damage that ignores armor (the glowing seams show where).
## Thrusts are slipped (either side), then answered with a hook; the wide
## horizontal slash is rolled under. A thrust is telegraphed by the whole suit
## turning side-on, sword arm drawn away from the player, then twisting back
## square as the blade drives forward.

const COMBOS := [
	["thrust"], ["slash"], ["thrust", "slash"], ["thrust", "thrust"], ["slash", "thrust"],
]
const WEAK_SPOT_MULTIPLIER := 2.0
const SEAM_COLOR := Color(0.7, 0.3, 1.0)
## How far the suit turns away (sword side back) while winding up a thrust.
const THRUST_TURN := -1.25


func weak_spot_multiplier(punch_type: String) -> float:
	return WEAK_SPOT_MULTIPLIER if punch_type == "hook" else 1.0


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	# Thrust: turn side-on during the windup, snap back square on the strike.
	var turn := THRUST_TURN if _attack == "thrust" and _state == State.WINDUP else 0.0
	var rate := 30.0 if _state == State.STRIKE else 7.0
	_body.rotation.y = lerpf(_body.rotation.y, turn, minf(1.0, rate * delta))


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.7, 1.3)


func _build_body() -> void:
	_body.scale = Vector3.ONE * 1.08
	var steel := _material(Color(0.38, 0.39, 0.43), 0.85)
	var dark_steel := _material(Color(0.2, 0.2, 0.24), 0.85)
	var void_material := _material(Color(0.02, 0.01, 0.03))
	var seams := _glow_material(SEAM_COLOR)
	var eyes := _glow_material(Color(0.75, 0.35, 1.0))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.19, 0.9, 0.22)), dark_steel, Vector3(0.14 * side, 0.45, 0))
		_part(_body, _box(Vector3(0.21, 0.14, 0.25)), steel, Vector3(0.14 * side, 0.55, -0.02))
	_part(_body, _box(Vector3(0.46, 0.2, 0.3)), dark_steel, Vector3(0, 0.95, 0))
	# Breastplate, with the open joints glowing down both sides: the weak spots.
	_part(_body, _box(Vector3(0.54, 0.6, 0.34)), steel, Vector3(0, 1.3, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.03, 0.42, 0.24)), seams, Vector3(0.285 * side, 1.25, 0))
		# Pauldrons.
		_part(_body, _box(Vector3(0.22, 0.12, 0.3)), steel, Vector3(0.32 * side, 1.6, 0), Vector3(0, 0, -0.25 * side))
	# Helm with a dark visor slit and eyes glowing inside.
	_part(_body, _box(Vector3(0.3, 0.34, 0.32)), steel, Vector3(0, 1.8, 0))
	_part(_body, _box(Vector3(0.24, 0.06, 0.02)), void_material, Vector3(0, 1.82, -0.162))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.05, 0.03, 0.02)), eyes, Vector3(0.06 * side, 1.82, -0.166))
	_part(_body, _box(Vector3(0.04, 0.12, 0.3)), dark_steel, Vector3(0, 2.02, 0))
	_build_arms(dark_steel, Color(0.3, 0.3, 0.34), 1.5, 0.34)
	# A long sword in the right gauntlet, pointing along the arm, and a crossguard.
	_hold_weapon("right", _box(Vector3(0.05, 0.02, 1.0)), Color(0.75, 0.76, 0.8), Vector3(0, 0, -1.05))
	_hold_weapon("right", _box(Vector3(0.28, 0.05, 0.05)), Color(0.4, 0.3, 0.2), Vector3(0, 0, -0.56))


func _build_armor() -> void:
	# Extra plates on an already armored suit.
	var gilded := _material(Color(0.55, 0.45, 0.22), 0.9)
	_part(_body, _box(Vector3(0.58, 0.3, 0.38)), gilded, Vector3(0, 1.42, 0))
	_part(_body, _box(Vector3(0.34, 0.08, 0.36)), gilded, Vector3(0, 1.98, 0))


## A suit of armor: the gear tier reskins its own metal.
func _gear_style() -> String:
	return "suit"
