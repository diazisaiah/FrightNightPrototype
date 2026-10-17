class_name Banshee
extends Wraith
## Banshee (deeper tiers, the wraith's big sister): drifts through walls and
## claws like the wraith, and shrieks: a wide cone in front of her lights up,
## then the scream hits everything in it. Back step out of it, or get out of
## the cone. She's solid for a moment after, like after a claw.


func _ready() -> void:
	special_kit = ["scream"]
	special_every = 6.5
	special_first = 3.0
	super()


func _special_tint() -> Color:
	return Color(0.7, 0.9, 1.0)


func _shriek() -> void:
	super()
	_open = OPEN_TIME


func _build_body() -> void:
	super()
	# Long white hair streaming back, a gaping mouth, a pale cyan glow.
	var hair := _ghost(Color(0.92, 0.95, 1.0))
	for i in 5:
		var x := -0.16 + i * 0.08
		_part(_body, _box(Vector3(0.07, 0.7 + (i % 2) * 0.15, 0.05)), hair, Vector3(x, 1.5, 0.2), Vector3(0.35, 0, x * 0.6))
	_part(_body, _box(Vector3(0.4, 0.12, 0.38)), hair, Vector3(0, 1.95, 0.02))
	_part(_body, _box(Vector3(0.1, 0.12, 0.02)), _glow_material(Color(0.6, 0.9, 1.0)), Vector3(0, 1.64, -0.19))
