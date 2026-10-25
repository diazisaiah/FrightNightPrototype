class_name Skeleton
extends Enemy
## Keeps its distance and shoots glowing arrows. It stops to draw the bow
## before each shot, which is the moment to close in or sidestep; the string
## flashes right before it lets go.

const ARROW_SPEED := 16.0

@export var arrow_damage := 5.0
@export var min_range := 8.0
@export var max_range := 14.0
@export var draw_time := 0.8
@export var shot_cooldown := 2.4

var _cooldown := 1.0
var _draw_timer := 0.0
var _drawing := false
var _strafe_sign := 1.0
var _strafe_timer := 0.0
var _walk_time := 0.0
var _bow_arm: Node3D
var _draw_arm: Node3D
var _draw_elbow: Node3D
var _legs: Array[Node3D] = []
var _string: StandardMaterial3D
var _flashed := false
## Sound played when the shot starts charging.
var _charge_sound := "draw"
## Height of the tell flash.
var _flash_height := 1.45



func _init() -> void:
	takes_turns = false  # Fights from range: never waits for a turn.

func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	var direction := offset.normalized()
	_turn_toward(offset, delta)
	_cooldown -= delta

	if _drawing:
		_draw_timer -= delta
		if not _flashed and _draw_timer <= tell_time():
			_flashed = true
			_flash_tell(_tell_color(), _flash_height)
		if _draw_timer <= 0.0:
			_shoot()
		return Vector3.ZERO
	if _cooldown <= 0.0 and distance <= max_range + 4.0:
		_drawing = true
		_flashed = false
		_draw_timer = draw_time
		Sfx.play_at(_charge_sound, global_position + Vector3.UP * 1.5, -6.0)
		return Vector3.ZERO

	if distance > max_range:
		return direction * move_speed
	if distance < min_range:
		return -direction * move_speed * 0.8
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.0, 2.5)
		_strafe_sign = [-1.0, 1.0].pick_random()
	return direction.cross(Vector3.UP) * _strafe_sign * move_speed * 0.5


func _on_staggered() -> void:
	_drawing = false
	_cooldown = maxf(_cooldown, 0.8)


func _tell_color() -> Color:
	return Boxer.SLIP_COLOR


func _shoot() -> void:
	_on_attacking()
	if _dead:
		return
	_drawing = false
	_cooldown = shot_cooldown
	var arrow := Arrow.new()
	arrow.shooter = self
	get_parent().add_child(arrow)
	var from := _body.to_global(Vector3(0, 1.45, -0.7))
	var target := player.global_position + Vector3(0, 1.3, 0)
	arrow.launch(from, target, ARROW_SPEED, arrow_damage * damage_multiplier)
	Sfx.play_at("twang", from)


func _animate(delta: float, speed: float) -> void:
	_walk_time += delta * speed * 3.0
	var leg_swing := sin(_walk_time) * 0.45 * minf(speed, 1.0)
	_legs[0].rotation.x = leg_swing
	_legs[1].rotation.x = -leg_swing

	var blend := minf(1.0, 10.0 * delta)
	var bow_target := PI / 2 if _drawing else 0.4
	var draw_target := PI / 2 - 0.1 if _drawing else 0.15
	_bow_arm.rotation.x = lerpf(_bow_arm.rotation.x, bow_target, blend)
	_draw_arm.rotation.x = lerpf(_draw_arm.rotation.x, draw_target, blend)
	# The drawing hand starts at the string and is pulled back to the cheek,
	# the elbow folding as the draw completes.
	var pull := 1.0 - clampf(_draw_timer / draw_time, 0.0, 1.0) if _drawing else 0.0
	var elbow_target := lerpf(0.3, PI - 0.35, pull) if _drawing else 0.2
	_draw_elbow.rotation.x = lerpf(_draw_elbow.rotation.x, elbow_target, blend)
	# The bowstring glows faintly as it's drawn and flashes right before the shot.
	_string.emission_energy_multiplier = 12.0 if _drawing and _flashed else pull * 2.0


func _build_body() -> void:
	var bone := _material(Color(0.85, 0.83, 0.75))
	var wood := _material(Color(0.35, 0.24, 0.15))
	var dark := _material(Color(0.05, 0.05, 0.06))
	var eyes := _glow_material(Color(0.35, 0.8, 1.0))

	for side in [-1.0, 1.0]:
		var leg := _pivot(_body, Vector3(0.1 * side, 0.9, 0))
		_part(leg, _cylinder(0.04, 0.9), bone, Vector3(0, -0.45, 0))
		_legs.append(leg)

	_part(_body, _box(Vector3(0.3, 0.1, 0.15)), bone, Vector3(0, 0.92, 0))
	_part(_body, _cylinder(0.035, 0.55), bone, Vector3(0, 1.2, 0))
	for i in 3:
		_part(_body, _box(Vector3(0.36 - i * 0.04, 0.04, 0.2)), bone, Vector3(0, 1.42 - i * 0.1, 0))
	_part(_body, _box(Vector3(0.28, 0.28, 0.3)), bone, Vector3(0, 1.7, 0))
	_part(_body, _box(Vector3(0.2, 0.06, 0.2)), bone, Vector3(0, 1.53, -0.04))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.09, 0.08, 0.02)), dark, Vector3(0.07 * side, 1.72, -0.15))
		_part(_body, _box(Vector3(0.05, 0.045, 0.02)), eyes, Vector3(0.07 * side, 1.72, -0.158))

	# Left arm holds the bow; right arm draws the string.
	_bow_arm = _pivot(_body, Vector3(-0.22, 1.48, 0))
	_part(_bow_arm, _cylinder(0.03, 0.6), bone, Vector3(0, -0.3, 0))
	# The bow runs along the arm's local Z so it stands upright when the arm points forward.
	_part(_bow_arm, _box(Vector3(0.035, 0.035, 0.95)), wood, Vector3(0, -0.6, 0))
	_string = _glow_material(Color(0.4, 0.85, 1.0))
	_string.emission_energy_multiplier = 0.0
	_part(_bow_arm, _box(Vector3(0.012, 0.012, 0.9)), _string, Vector3(0, -0.52, 0))

	_draw_arm = _pivot(_body, Vector3(0.22, 1.48, 0))
	_part(_draw_arm, _cylinder(0.03, 0.3), bone, Vector3(0, -0.15, 0))
	_draw_elbow = _pivot(_draw_arm, Vector3(0, -0.3, 0))
	_part(_draw_elbow, _cylinder(0.028, 0.3), bone, Vector3(0, -0.15, 0))


func _build_armor() -> void:
	var rusty := _material(Color(0.4, 0.3, 0.25), 0.6)
	_part(_body, _box(Vector3(0.32, 0.14, 0.34)), rusty, Vector3(0, 1.88, 0))
	_part(_body, _box(Vector3(0.42, 0.4, 0.28)), rusty, Vector3(0, 1.3, 0))
