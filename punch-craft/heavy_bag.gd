class_name HeavyBag
extends Enemy
## A heavy bag on a chain, for the Heavy Bags drill: it never moves or hits
## back, sways when punched, and flies off the rack when its HP runs out.


func _init() -> void:
	takes_turns = false


func _build_body() -> void:
	var leather := _material(Color(0.42, 0.12, 0.1))
	var band := _material(Color(0.12, 0.1, 0.1))
	var steel := _material(Color(0.35, 0.36, 0.4), 0.6)
	_part(_body, _cylinder(0.32, 1.25), leather, Vector3(0, 1.12, 0))
	_part(_body, _cylinder(0.33, 0.08), band, Vector3(0, 0.6, 0))
	_part(_body, _cylinder(0.33, 0.08), band, Vector3(0, 1.64, 0))
	_part(_body, _cylinder(0.2, 0.08), band, Vector3(0, 1.78, 0))
	# The chain up to the rack.
	_part(_body, _box(Vector3(0.04, 0.95, 0.04)), steel, Vector3(0, 2.28, 0))


func _gear_style() -> String:
	return "none"


func has_turn() -> bool:
	return false


## Bags don't slide or flinch: they swing on the chain.
func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, _stagger: bool, caption := "", pierce := false, crush := false) -> float:
	var dealt := super(raw_damage, hit_point, Vector3.ZERO, false, caption, pierce, crush)
	if not is_dead():
		var swing := clampf(dealt / maxf(max_hp, 1.0) * 3.0, 0.08, 0.45)
		var away := to_local(global_position + push.normalized())
		var tween := create_tween()
		tween.tween_property(_body, "rotation", Vector3(away.z * swing, 0, -away.x * swing), 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(_body, "rotation", Vector3.ZERO, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return dealt
