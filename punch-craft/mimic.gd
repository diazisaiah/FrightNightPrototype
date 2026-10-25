class_name Mimic
extends Enemy
## A chest that isn't (Crypt). Wakes when the player comes close: bony legs
## unfold and it stands up, lid gaping. It scuttles in and bites: the lid
## yawns open and flashes red, then it lunges and snaps shut. Back step it.
## Beaten, it coughs up a real chest.

enum State { WAKING, CHASE, WINDUP, BITE, RECOVER }

const WAKE_TIME := 0.8
const STAND_HEIGHT := 0.75
const LUNGE_SPEED := 9.0
const SLIPPED_OPEN_TIME := 1.0

@export var attack_damage := 10.0
@export var attack_range := 2.2
@export var windup_time := 0.8
@export var recover_time := 0.9

var _state := State.WAKING
var _state_timer := WAKE_TIME
var _flashed := false
var _lid: Node3D
var _legs: Array[Node3D] = []
var _chest: Node3D
var _tongue: MeshInstance3D
var _walk_time := 0.0
var _extra_open := 0.0


func incoming_attack() -> String:
	return "bite" if _state == State.WINDUP else ""


func attack_eta() -> float:
	return _state_timer if _state == State.WINDUP else INF


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	_state_timer -= delta
	match _state:
		State.WAKING:
			if _state_timer <= 0.0:
				_enter(State.CHASE, 0.0)
			return Vector3.ZERO
		State.CHASE:
			_turn_toward(offset, delta)
			if not has_turn():
				return _wait_move(offset, delta, move_speed)
			if distance <= attack_range:
				_enter(State.WINDUP, windup_time)
				Sfx.play_at("growl", global_position + Vector3.UP, -2.0, 1.5)
				return Vector3.ZERO
			return offset.normalized() * move_speed
		State.WINDUP:
			_turn_toward(offset, delta)
			if not _flashed and _state_timer <= tell_time():
				_flashed = true
				_flash_tell(Boxer.BACK_STEP_COLOR, 1.3)
			if _state_timer <= 0.0:
				_bite(distance)
		State.BITE:
			if _state_timer <= 0.0:
				_enter(State.RECOVER, recover_time + _extra_open)
			return -global_basis.z * LUNGE_SPEED * clampf(_state_timer / 0.15, 0.0, 1.0)
		State.RECOVER:
			if _state_timer <= 0.0:
				end_turn()
				_enter(State.CHASE, 0.0)
	return Vector3.ZERO


func _bite(distance: float) -> void:
	_on_attacking()
	if _dead:
		return
	_enter(State.BITE, 0.15)
	Sfx.play_at("block", global_position + Vector3.UP, 0.0, 0.6)
	if distance <= attack_range + 0.8 or player.is_back_stepping():
		var result := player.receive_attack(attack_damage * damage_multiplier, global_position, "bite", self)
		# Bit empty air: stays open longer.
		_extra_open = SLIPPED_OPEN_TIME if result == "dodged" else 0.0


func _on_staggered() -> void:
	if _state != State.WAKING:
		_enter(State.RECOVER, 0.5)


func _enter(state: State, time: float) -> void:
	_state = state
	_state_timer = time
	_flashed = false


func _animate(delta: float, speed: float) -> void:
	var blend := minf(1.0, 10.0 * delta)
	# Stands up on its legs while waking.
	var stand := 1.0 - clampf(_state_timer / WAKE_TIME, 0.0, 1.0) if _state == State.WAKING else 1.0
	_chest.position.y = lerpf(_chest.position.y, STAND_HEIGHT * stand, blend)
	for i in _legs.size():
		_legs[i].scale.y = maxf(0.05, stand)
	_walk_time += delta * speed * 4.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_walk_time + i * PI / 2.0) * 0.4 * minf(speed, 1.0)
	# The lid: gaping while it chases, yawning wide in the windup, snapped shut on the bite.
	var lid_target := -0.6
	match _state:
		State.WAKING:
			lid_target = -0.6 * stand
		State.WINDUP:
			lid_target = -1.5
		State.BITE:
			lid_target = 0.0
		State.RECOVER:
			lid_target = -0.3
	_lid.rotation.x = lerpf(_lid.rotation.x, lid_target, minf(1.0, (30.0 if _state == State.BITE else 10.0) * delta))
	_tongue.visible = _state in [State.CHASE, State.WINDUP]


func _build_body() -> void:
	var wood := _material(Color(0.35, 0.22, 0.12))
	var trim := _material(Color(0.85, 0.65, 0.2), 0.7)
	var bone := _material(Color(0.8, 0.77, 0.68))
	var flesh := _material(Color(0.55, 0.12, 0.15))
	var eyes := _glow_material(Color(1.0, 0.25, 0.15))
	# Spindly bone legs under the chest.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg := _pivot(_body, Vector3(0.4 * x, STAND_HEIGHT, 0.25 * z))
			_part(leg, _cylinder(0.04, STAND_HEIGHT), bone, Vector3(0, -STAND_HEIGHT / 2.0, 0))
			leg.scale.y = 0.05
			_legs.append(leg)
	_chest = Node3D.new()
	_body.add_child(_chest)
	# Twice the size of a normal chest, so it stands at punching height.
	_part(_chest, _box(Vector3(1.2, 0.7, 0.8)), wood, Vector3(0, 0.35, 0))
	_part(_chest, _box(Vector3(1.24, 0.08, 0.84)), trim, Vector3(0, 0.66, 0))
	_part(_chest, _box(Vector3(1.0, 0.3, 0.6)), flesh, Vector3(0, 0.62, 0))
	for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		_part(_chest, _box(Vector3(0.07, 0.1, 0.05)), bone, Vector3(x, 0.74, -0.38))
	_tongue = _part(_chest, _box(Vector3(0.2, 0.05, 0.6)), flesh, Vector3(0, 0.72, -0.5))
	_lid = _pivot(_chest, Vector3(0, 0.7, 0.4))
	_part(_lid, _box(Vector3(1.2, 0.3, 0.8)), wood, Vector3(0, 0.15, -0.4))
	_part(_lid, _box(Vector3(0.18, 0.18, 0.06)), trim, Vector3(0, 0.05, -0.82))
	for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		_part(_lid, _box(Vector3(0.07, 0.1, 0.05)), bone, Vector3(x, -0.04, -0.78))
	for side in [-1.0, 1.0]:
		_part(_lid, _box(Vector3(0.1, 0.06, 0.02)), eyes, Vector3(0.25 * side, 0.18, -0.81))


func _build_armor() -> void:
	pass


## No gear overlays: it's a chest.
func _gear_style() -> String:
	return "none"
