class_name Priest
extends Boxer
## Grave Priest: a robed healer with a staff. While other enemies are alive it
## keeps away from the player and, every few seconds, raises its staff and
## heals the enemies around it (the staff glows green as it channels; any
## stagger interrupts it). Once it's the last one standing it turns and fights,
## swinging its staff at head height: roll under it.

const FLEE_DISTANCE := 9.0
## Stays roughly this far behind its allies, away from the player.
const SUPPORT_DISTANCE := 3.5
const HEAL_RADIUS := 8.0
const HEAL_FRACTION := 0.2
const HEAL_INTERVAL := 4.0
const CHANNEL_TIME := 1.1

var _heal_cooldown := 2.0
var _channel := 0.0
var _heal_glow: StandardMaterial3D
var _support_strafe := 1.0
var _strafe_timer := 0.0


func _pick_combo() -> Array:
	return ["staff"]


func _idle_time() -> float:
	return randf_range(0.6, 1.1)


func _think(delta: float) -> Vector3:
	var allies := _allies()
	if allies.is_empty() and _channel <= 0.0:
		return super(delta)  # Alone: fight.
	# Drop any attack it was in the middle of.
	if _state != State.IDLE:
		_queue.clear()
		_cue_label.visible = false
		_enter(State.IDLE, 0.5)
	var offset := _to_player()
	_turn_toward(offset, delta)

	if _channel > 0.0:
		_channel -= delta
		if _channel <= 0.0:
			_release_heal(allies)
		return Vector3.ZERO
	_heal_cooldown -= delta
	if _heal_cooldown <= 0.0 and _wounded_near(allies):
		_channel = CHANNEL_TIME
		Sfx.play_at("heal", global_position + Vector3.UP * 2.0, -4.0, 0.7)
		return Vector3.ZERO
	return _support_move(offset, allies, delta)


func _on_staggered() -> void:
	if _channel > 0.0:
		_channel = 0.0
		_heal_cooldown = HEAL_INTERVAL * 0.5
		DamagePopup.spawn(get_parent(), "INTERRUPTED", Color(0.8, 0.8, 0.8), 40, global_position + Vector3(0, 2.2, 0))
	super()


## Other living enemies (the priest only fights once they're all gone).
func _allies() -> Array[Enemy]:
	var allies: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy != self and not enemy.is_dead():
			allies.append(enemy)
	return allies


func _wounded_near(allies: Array[Enemy]) -> bool:
	for ally in allies:
		if ally.hp < ally.max_hp and ally.global_position.distance_to(global_position) <= HEAL_RADIUS:
			return true
	return false


func _release_heal(allies: Array[Enemy]) -> void:
	_heal_cooldown = HEAL_INTERVAL
	var healed := 0
	for ally in allies:
		if ally.global_position.distance_to(global_position) <= HEAL_RADIUS:
			if ally.heal(ally.max_hp * HEAL_FRACTION) > 0.0:
				healed += 1
	var at := global_position + Vector3.UP * 2.2
	HitFx.burst(get_parent(), at, Vector3.UP, HEAL_COLOR, 30, 5.0, true, 0.06)
	Sfx.play_at("heal", at, -2.0, 1.2)
	if healed > 0:
		DamagePopup.spawn(get_parent(), "HEAL", HEAL_COLOR, 44, at + Vector3.UP * 0.3)


## Runs from the player when close, otherwise hangs back behind its allies.
func _support_move(offset: Vector3, allies: Array[Enemy], delta: float) -> Vector3:
	var away := -offset.normalized()
	var desired := Vector3.ZERO
	if offset.length() < FLEE_DISTANCE:
		desired = away
	else:
		# Aim for a spot behind the nearest ally, on the far side from the player.
		var nearest: Enemy = allies[0]
		for ally in allies:
			if ally.global_position.distance_squared_to(global_position) < nearest.global_position.distance_squared_to(global_position):
				nearest = ally
		var from_player := nearest.global_position - player.global_position
		from_player.y = 0.0
		var spot := nearest.global_position + from_player.normalized() * SUPPORT_DISTANCE
		var to_spot := spot - global_position
		to_spot.y = 0.0
		if to_spot.length() > 1.0:
			desired = to_spot.normalized()
		else:
			_strafe_timer -= delta
			if _strafe_timer <= 0.0:
				_strafe_timer = randf_range(1.0, 2.0)
				_support_strafe = [-1.0, 1.0].pick_random()
			desired = away.cross(Vector3.UP) * _support_strafe * 0.4
	# Near the edge: slide along it instead of into the wall.
	var flat := Vector3(global_position.x - arena_center.x, 0, global_position.z - arena_center.z)
	if flat.length() > arena_limit:
		desired -= flat.normalized() * desired.dot(flat.normalized())
		desired += -flat.normalized() * 0.3
	return desired * move_speed


# Channeling: staff held up high.
func _arm_pose(arm: String) -> Array:
	if _channel > 0.0 and arm == "right":
		return [Vector3(2.3, 0.1, 0), 0.0, Vector3.ZERO]
	return super(arm)


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	# The crystal glows brighter until the heal goes off.
	if _channel > 0.0:
		var progress := 1.0 - _channel / CHANNEL_TIME
		_heal_glow.emission_energy_multiplier = lerpf(1.0, 10.0, progress)
	else:
		_heal_glow.emission_energy_multiplier = lerpf(_heal_glow.emission_energy_multiplier, 1.0, minf(1.0, 8.0 * delta))


func _build_body() -> void:
	_body.scale = Vector3(1.0, randf_range(1.0, 1.06), 1.0)
	var robe := _material(Color(0.14, 0.2, 0.16))
	var trim := _material(Color(0.55, 0.5, 0.3), 0.4)
	var skin := _material(Color(0.6, 0.62, 0.55))
	var eyes := _glow_material(HEAL_COLOR)

	# Long robe down to the ground.
	_part(_body, _box(Vector3(0.5, 0.95, 0.42)), robe, Vector3(0, 0.47, 0))
	_part(_body, _box(Vector3(0.44, 0.6, 0.32)), robe, Vector3(0, 1.25, 0))
	_part(_body, _box(Vector3(0.08, 1.3, 0.02)), trim, Vector3(0, 0.75, -0.215))
	# Hood with a pale face inside.
	_part(_body, _box(Vector3(0.36, 0.38, 0.36)), robe, Vector3(0, 1.73, 0.02))
	_part(_body, _box(Vector3(0.24, 0.26, 0.04)), skin, Vector3(0, 1.7, -0.15))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.05, 0.03, 0.02)), eyes, Vector3(0.06 * side, 1.74, -0.175))
	_build_arms(robe, Color(0.6, 0.62, 0.55), 1.48, 0.27)
	# Gnarled staff topped with a green crystal.
	_hold_weapon("right", _cylinder(0.035, 1.6), Color(0.3, 0.2, 0.12), Vector3(0, 0, -0.75), Vector3(-PI / 2, 0, 0))
	_heal_glow = _glow_material(HEAL_COLOR)
	_heal_glow.emission_energy_multiplier = 1.0
	_part(_hand("right"), _box(Vector3(0.14, 0.14, 0.14)), _heal_glow, arm_to_hand(Vector3(0, 0, -1.6)), Vector3(0.6, 0.6, 0))


func _build_armor() -> void:
	var bone := _material(Color(0.8, 0.78, 0.7))
	# A ribcage breastplate and a skull-cap.
	_part(_body, _box(Vector3(0.48, 0.42, 0.36)), bone, Vector3(0, 1.3, 0))
	_part(_body, _box(Vector3(0.38, 0.12, 0.38)), bone, Vector3(0, 1.94, 0.02))


## Casters wear their gear as tier-colored robes with trim.
func _gear_style() -> String:
	return "robe"
