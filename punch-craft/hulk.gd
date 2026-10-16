class_name Hulk
extends Enemy
## Hulking zombie. Doesn't swing at the player: it raises both fists and
## smashes the ground in front of it, sending out a shockwave. A red ring on
## the ground shows where it will hit. Get out of the ring (sprint) or be in
## the air when it lands (jump); slips and rolls don't help. A jumped smash
## readies a counter, and it's left wide open after every smash.

enum State { CHASE, WINDUP, RECOVER }

const SCALE := 1.45
const RING_COLOR := Color(1.0, 0.15, 0.1)
## The smash lands this far in front of the hulk.
const SMASH_REACH := 1.2

@export var attack_damage := 12.0
## Starts a smash once the player is this close.
@export var attack_range := 2.6
@export var smash_radius := 5.0
@export var windup_time := 1.0
@export var recover_time := 1.4

var _state := State.CHASE
var _state_timer := 0.0
var _flashed := false
var _walk_time := 0.0
var _smash_center := Vector3.ZERO
var _arms: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _eyes: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D


func _ready() -> void:
	super()
	_hp_label.position.y = 3.0


func incoming_attack() -> String:
	return "quake" if _state == State.WINDUP else ""


func attack_eta() -> float:
	return _state_timer if _state == State.WINDUP else INF


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	match _state:
		State.CHASE:
			_turn_toward(offset, delta)
			if not has_turn():
				return _wait_move(offset, delta, move_speed)
			if distance <= attack_range:
				_start_smash()
				return Vector3.ZERO
			return offset.normalized() * move_speed
		State.WINDUP:
			_state_timer -= delta
			if not _flashed and _state_timer <= TELL_FLASH_TIME:
				_flashed = true
				_flash_tell(RING_COLOR, 2.2)
			if _state_timer <= 0.0:
				_smash()
		State.RECOVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				end_turn()
				_enter(State.CHASE, 0.0)
	return Vector3.ZERO


func _on_staggered() -> void:
	# Heavy punches stagger it out of the smash.
	_hide_ring()
	_enter(State.RECOVER, 0.4)


func _die(push: Vector3) -> void:
	_hide_ring()
	super(push)


func _start_smash() -> void:
	_enter(State.WINDUP, windup_time)
	# Locked in when the windup starts: the hulk commits to a spot.
	_smash_center = global_position - global_basis.z * SMASH_REACH
	_smash_center.y = global_position.y
	_show_ring()
	Sfx.play_at("growl", global_position + Vector3.UP * 2.4, 2.0, 0.6)


func _smash() -> void:
	_on_attacking()
	_hide_ring()
	_enter(State.RECOVER, recover_time)
	Sfx.play_at("quake", _smash_center, 4.0)
	_shockwave_fx()
	var to_player := player.global_position - _smash_center
	to_player.y = 0.0
	var distance := to_player.length()
	if distance <= smash_radius * 2.5:
		player.shake(0.12 * (1.0 - distance / (smash_radius * 2.5)) + 0.02)
	if distance <= smash_radius:
		player.receive_attack(attack_damage * damage_multiplier, _smash_center, "quake", self)


func _enter(state: State, time: float) -> void:
	_state = state
	_state_timer = time
	_flashed = false


# --- Ground ring and shockwave -------------------------------------------------------

func _show_ring() -> void:
	if _ring == null:
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.92
		mesh.outer_radius = 1.0
		mesh.rings = 48
		mesh.material = _ring_material
		_ring = MeshInstance3D.new()
		_ring.mesh = mesh
		_ring.top_level = true
		add_child(_ring)
	_ring.global_position = _smash_center + Vector3.UP * 0.05
	_ring.scale = Vector3(smash_radius, 0.4, smash_radius)
	_ring.visible = true


func _hide_ring() -> void:
	if _ring:
		_ring.visible = false


func _update_ring() -> void:
	if _ring == null or not _ring.visible:
		return
	if _flashed:
		_ring_material.albedo_color = Color(1.0, 0.85, 0.6, 0.95)
	else:
		# Fades in and pulses faster as the smash gets closer.
		var progress := 1.0 - clampf(_state_timer / windup_time, 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 20.0, progress))
		_ring_material.albedo_color = Color(RING_COLOR, lerpf(0.15, 0.6, progress) * (0.7 + 0.3 * pulse))


func _shockwave_fx() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.85, 0.7, 0.5, 0.8)
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.material = material
	var wave := MeshInstance3D.new()
	wave.mesh = mesh
	get_parent().add_child(wave)
	wave.global_position = _smash_center + Vector3.UP * 0.15
	wave.scale = Vector3(0.5, 1.0, 0.5)
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3(smash_radius, 1.5, smash_radius), 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(wave.queue_free)
	var dust := Color(0.35, 0.3, 0.25)
	HitFx.burst(get_parent(), _smash_center + Vector3.UP * 0.2, Vector3.UP, dust, 40, 6.0, false, 0.12)


# --- Body ---------------------------------------------------------------------------

func _animate(delta: float, speed: float) -> void:
	_update_ring()
	_walk_time += delta * speed * 1.6
	var leg_swing := sin(_walk_time) * 0.4 * minf(speed, 1.0)
	_legs[0].rotation.x = leg_swing
	_legs[1].rotation.x = -leg_swing

	# Arms: hanging forward while walking, raised high overhead in the windup,
	# slammed down into the ground after.
	var arm_target := PI / 3 + sin(_walk_time * 0.5) * 0.1
	var lean := 0.0
	match _state:
		State.WINDUP:
			var progress := 1.0 - clampf(_state_timer / windup_time, 0.0, 1.0)
			arm_target = lerpf(PI * 0.6, PI * 1.05, minf(1.0, progress * 1.6))
			lean = -0.2 * minf(1.0, progress * 1.6)
		State.RECOVER:
			arm_target = PI * 0.15
			lean = 0.35
	var blend := minf(1.0, (25.0 if _state == State.RECOVER else 10.0) * delta)
	for arm in _arms:
		arm.rotation.x = lerpf(arm.rotation.x, arm_target, blend)
	_body.rotation.x = lerpf(_body.rotation.x, lean, blend)
	if _state == State.WINDUP and _flashed:
		_eyes.emission_energy_multiplier = 18.0
	else:
		_eyes.emission_energy_multiplier = lerpf(_eyes.emission_energy_multiplier, 4.0, blend)


func _build_body() -> void:
	_body.scale = Vector3.ONE * SCALE
	var skin := _material(Color(0.33, 0.42, 0.3))
	var rags := _material(Color(0.25, 0.2, 0.16))
	var bone := _material(Color(0.78, 0.75, 0.66))
	_eyes = _glow_material(Color(1.0, 0.25, 0.08))

	for side in [-1.0, 1.0]:
		var leg := _pivot(_body, Vector3(0.17 * side, 0.85, 0))
		_part(leg, _box(Vector3(0.24, 0.85, 0.26)), rags, Vector3(0, -0.42, 0))
		_legs.append(leg)
	# Barrel chest and a hunched head set low between the shoulders.
	_part(_body, _box(Vector3(0.78, 0.75, 0.48)), skin, Vector3(0, 1.25, 0))
	_part(_body, _box(Vector3(0.6, 0.25, 0.42)), rags, Vector3(0, 0.9, 0))
	_part(_body, _box(Vector3(0.3, 0.3, 0.3)), skin, Vector3(0, 1.72, -0.08))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.04, 0.02)), _eyes, Vector3(0.07 * side, 1.75, -0.235))
		# Bones poking out of the shoulders.
		_part(_body, _box(Vector3(0.05, 0.16, 0.05)), bone, Vector3(0.36 * side, 1.68, 0.05), Vector3(0, 0, -0.4 * side))

	for side in [-1.0, 1.0]:
		var arm := _pivot(_body, Vector3(0.5 * side, 1.5, 0))
		_part(arm, _box(Vector3(0.22, 0.7, 0.22)), skin, Vector3(0, -0.35, 0))
		# Huge fists.
		_part(arm, _box(Vector3(0.3, 0.28, 0.3)), skin, Vector3(0, -0.8, 0))
		arm.rotation.x = PI / 3
		_arms.append(arm)


func _build_armor() -> void:
	var iron := _material(Color(0.45, 0.46, 0.5), 0.8)
	_part(_body, _box(Vector3(0.82, 0.55, 0.52)), iron, Vector3(0, 1.3, 0))
	_part(_body, _box(Vector3(0.36, 0.18, 0.36)), iron, Vector3(0, 1.88, -0.08))


func _hand_nodes() -> Array:
	return _arms
