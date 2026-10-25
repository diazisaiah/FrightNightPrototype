class_name Zombie
extends Enemy
## Shambles toward the player and slams with both arms. The arms go up during
## the windup, then its eyes flash red right before they come down.

enum State { CHASE, WINDUP, RECOVER }

const SLIPPED_STUMBLE_TIME := 0.6

@export var attack_damage := 6.0
@export var attack_range := 1.7
@export var windup_time := 0.6
@export var recover_time := 0.8

var _state := State.CHASE
var _state_timer := 0.0
var _walk_time := 0.0
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: StandardMaterial3D
var _flashed := false


func incoming_attack() -> String:
	return "slam" if _state == State.WINDUP else ""


func attack_eta() -> float:
	return _state_timer if _state == State.WINDUP else INF


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	_turn_toward(offset, delta)
	match _state:
		State.CHASE:
			if not has_turn():
				return _wait_move(offset, delta, move_speed)
			if distance <= attack_range:
				_enter(State.WINDUP, windup_time)
				Sfx.play_at("growl", global_position + Vector3.UP * 1.6, -4.0, randf_range(0.85, 1.1))
				return Vector3.ZERO
			return offset.normalized() * move_speed
		State.WINDUP:
			_state_timer -= delta
			if not _flashed and _state_timer <= tell_time():
				_flashed = true
				_flash_tell(Boxer.BACK_STEP_COLOR, 1.7)
			if _state_timer <= 0.0:
				_on_attacking()
				if _dead:
					return Vector3.ZERO
				# Only connects if the player is still in reach when the arms come down.
				var recovery := recover_time
				if distance <= attack_range + 0.4 or player.is_back_stepping():
					var result := player.receive_attack(attack_damage * damage_multiplier, global_position, "slam", self)
					if result == "dodged":
						recovery += SLIPPED_STUMBLE_TIME  # Dodged: it overcommits and is left open.
				_enter(State.RECOVER, recovery)
		State.RECOVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				end_turn()
				_enter(State.CHASE, 0.0)
	return Vector3.ZERO


func _on_staggered() -> void:
	_enter(State.RECOVER, 0.3)


func _enter(state: State, time: float) -> void:
	_state = state
	_state_timer = time
	_flashed = false


func _animate(delta: float, speed: float) -> void:
	_walk_time += delta * speed * 2.5
	var leg_swing := sin(_walk_time) * 0.5 * minf(speed, 1.0)
	_legs[0].rotation.x = leg_swing
	_legs[1].rotation.x = -leg_swing

	# Arm angle: PI/2 points straight forward, higher raises them overhead.
	var arm_target := PI / 2 + sin(_walk_time * 0.5) * 0.1
	var lean := 0.0
	match _state:
		State.WINDUP:
			# Rears back as the arms go up, then crashes forward into the slam.
			arm_target = PI * 0.9
			lean = 0.28
		State.RECOVER:
			arm_target = PI / 3
			lean = -0.3
	var blend := minf(1.0, 12.0 * delta)
	for arm in _arms:
		arm.rotation.x = lerpf(arm.rotation.x, arm_target, blend)
	_body.rotation.x = lerpf(_body.rotation.x, lean, blend)
	# Eyes flare once the slam is wound up: the cue to back step.
	if _state == State.WINDUP and _flashed:
		_eyes.emission_energy_multiplier = 16.0
	else:
		_eyes.emission_energy_multiplier = lerpf(_eyes.emission_energy_multiplier, 4.0, blend)


func _build_body() -> void:
	_body.scale = Vector3.ONE * randf_range(0.95, 1.1)
	var skin := _material(Color(0.36, 0.47, 0.33))
	var shirt := _material(Color(0.22, 0.26, 0.3))
	var pants := _material(Color(0.2, 0.17, 0.22))
	var eyes := _glow_material(Color(1.0, 0.2, 0.08))
	_eyes = eyes

	for side in [-1.0, 1.0]:
		var leg := _pivot(_body, Vector3(0.13 * side, 0.9, 0))
		_part(leg, _box(Vector3(0.18, 0.9, 0.2)), pants, Vector3(0, -0.45, 0))
		_legs.append(leg)

	_part(_body, _box(Vector3(0.5, 0.65, 0.28)), shirt, Vector3(0, 1.25, 0))
	_part(_body, _box(Vector3(0.32, 0.34, 0.32)), skin, Vector3(0, 1.77, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.07, 0.045, 0.02)), eyes, Vector3(0.08 * side, 1.8, -0.165))

	for side in [-1.0, 1.0]:
		var arm := _pivot(_body, Vector3(0.33 * side, 1.5, 0))
		_part(arm, _box(Vector3(0.14, 0.62, 0.14)), skin, Vector3(0, -0.31, 0))
		arm.rotation.x = PI / 2
		_arms.append(arm)


func _build_armor() -> void:
	var iron := _material(Color(0.45, 0.46, 0.5), 0.8)
	_part(_body, _box(Vector3(0.38, 0.2, 0.38)), iron, Vector3(0, 1.92, 0))
	_part(_body, _box(Vector3(0.56, 0.5, 0.34)), iron, Vector3(0, 1.3, 0))
	for arm in _arms:
		_part(arm, _box(Vector3(0.2, 0.18, 0.2)), iron, Vector3(0, -0.05, 0))


func _hand_nodes() -> Array:
	return _arms
