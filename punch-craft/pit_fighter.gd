class_name PitFighter
extends Brawler
## Pit Fighter (deeper tiers, the brawler's big brother): a dead champion
## who boxes like the brawler and finishes with a leap: a red ring follows
## you until it jumps, then it lands in a shockwave. Get out or jump it.


func _ready() -> void:
	special_kit = ["leap_slam"]
	special_every = 8.0
	special_first = 4.0
	super()


func _idle_time() -> float:
	return randf_range(0.4, 0.9)


func _build_body() -> void:
	super()
	# A title belt with a big gold plate, a red headband and spiked shoulders.
	var gold := _material(Color(0.95, 0.72, 0.22), 0.8)
	var red := _material(Color(0.7, 0.06, 0.06))
	var iron := _material(Color(0.25, 0.25, 0.28), 0.7)
	_part(_body, _box(Vector3(0.54, 0.12, 0.32)), red, Vector3(0, 0.95, 0))
	_part(_body, _box(Vector3(0.22, 0.16, 0.04)), gold, Vector3(0, 0.95, -0.17))
	_part(_body, _box(Vector3(0.3, 0.06, 0.3)), red, Vector3(0, 1.8, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.2, 0.1, 0.24)), iron, Vector3(0.33 * side, 1.52, 0))
		for k in 2:
			_part(_body, _box(Vector3(0.04, 0.1, 0.04)), gold, Vector3(0.33 * side, 1.61, -0.06 + k * 0.12))
