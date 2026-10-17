class_name Bulwark
extends Shieldbearer
## Bulwark (deeper tiers, the shieldbearer's big brother): a horned knight
## behind a gold-rimmed shield. Everything the shieldbearer does, plus a
## shield rush: a lane lights toward you, then it drives forward behind the
## shield. Step out of the lane or roll it.


func _ready() -> void:
	special_kit = ["dash"]
	special_every = 7.0
	special_first = 3.0
	super()


func _announce_special(kind: String) -> void:
	DamagePopup.spawn(get_parent(), "SHIELD RUSH" if kind == "dash" else SPECIAL_NAMES[kind], _special_tint(), 36,
			global_position + Vector3(0, 2.6 * _body.scale.y, 0))


func _special_tint() -> Color:
	return Color(1.0, 0.75, 0.3)


func _build_body() -> void:
	super()
	_body.scale = Vector3.ONE * 1.12
	var horn := _material(Color(0.88, 0.84, 0.72))
	var gold := _material(Color(0.95, 0.72, 0.22), 0.8)
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.07, 0.24, 0.07)), horn, Vector3(0.2 * side, 1.98, 0), Vector3(0, 0, -0.55 * side))
		_part(_body, _box(Vector3(0.05, 0.14, 0.05)), horn, Vector3(0.29 * side, 2.12, 0), Vector3(0, 0, -0.15 * side))
	_part(_body, _box(Vector3(0.36, 0.05, 0.36)), gold, Vector3(0, 1.93, 0))
	# Gold rim round the shield.
	_hold_weapon("left", _box(Vector3(0.82, 0.1, 0.06)), Color(0.95, 0.72, 0.22), Vector3(0, 0.15, 0.06))
