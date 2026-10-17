class_name Sprinter
extends Runner
## Sprinter (deeper tiers, the runner's big brother): throws its looping
## haymaker twice in a row (roll both), and bull-rushes back in when you get
## away: a lane lights toward you first.


func _ready() -> void:
	special_kit = ["dash"]
	special_every = 6.0
	special_first = 2.5
	super()


func _pick_combo() -> Array:
	return ["haymaker", "haymaker"]


func _build_body() -> void:
	super()
	# A red bandana with trailing tails, and eyes burning yellow.
	var red := _material(Color(0.7, 0.08, 0.06))
	_part(_body, _box(Vector3(0.31, 0.07, 0.31)), red, Vector3(0, 1.79, -0.1))
	_part(_body, _box(Vector3(0.05, 0.22, 0.03)), red, Vector3(0.04, 1.68, 0.07), Vector3(0.5, 0, 0.2))
	_part(_body, _box(Vector3(0.05, 0.18, 0.03)), red, Vector3(-0.04, 1.69, 0.07), Vector3(0.6, 0, -0.2))
	var eyes := _glow_material(Color(1.0, 0.85, 0.2))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.065, 0.045, 0.02)), eyes, Vector3(0.07 * side, 1.74, -0.25))
