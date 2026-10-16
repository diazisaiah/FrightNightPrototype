class_name Mage
extends Skeleton
## Fire Mage: the skeleton's keep-away-and-shoot AI with fireballs instead of
## arrows. It stops and raises its hands while a fireball grows between them,
## the fireball flashes once it's ready, then it's thrown. Fireballs are slow:
## keep moving sideways to make them miss, or slip them as they arrive.
## (arrow_damage is the fireball's damage.)

const FIREBALL_SPEED := 11.0

var _orb: MeshInstance3D
var _orb_material: StandardMaterial3D
var _arms_pivots: Array[Node3D] = []


func _ready() -> void:
	_charge_sound = "fire"
	_flash_height = 1.6
	super()


func _shoot() -> void:
	_on_attacking()
	if _dead:
		return
	_drawing = false
	_cooldown = shot_cooldown
	var fireball := Fireball.new()
	get_parent().add_child(fireball)
	var from := _body.to_global(Vector3(0, 1.55, -0.55))
	var target := player.global_position + Vector3(0, 1.3, 0)
	fireball.launch(from, target, FIREBALL_SPEED, arrow_damage * damage_multiplier)
	Sfx.play_at("whoosh", from, 0.0, 0.6)


func _animate(delta: float, speed: float) -> void:
	_walk_time += delta * speed * 3.0
	var blend := minf(1.0, 10.0 * delta)
	# Both hands raised forward while casting, down at the sides otherwise.
	var arm_target := 1.9 if _drawing else 0.3
	for pivot in _arms_pivots:
		pivot.rotation.x = lerpf(pivot.rotation.x, arm_target, blend)
	# Robe sways while moving.
	_body.rotation.z = sin(_walk_time) * 0.05 * minf(speed, 1.0)
	# The fireball grows between the hands as the cast charges, flaring at the end.
	var charge := 1.0 - clampf(_draw_timer / draw_time, 0.0, 1.0) if _drawing else 0.0
	_orb.visible = _drawing
	_orb.scale = Vector3.ONE * lerpf(0.2, 1.0, charge)
	_orb_material.emission_energy_multiplier = 14.0 if _drawing and _flashed else 4.0


func _build_body() -> void:
	var robe := _material(Color(0.28, 0.07, 0.07))
	var trim := _material(Color(0.85, 0.55, 0.15), 0.5)
	var skin := _material(Color(0.55, 0.52, 0.48))
	var eyes := _glow_material(Fireball.COLOR)

	_part(_body, _box(Vector3(0.48, 1.0, 0.4)), robe, Vector3(0, 0.5, 0))
	_part(_body, _box(Vector3(0.42, 0.6, 0.3)), robe, Vector3(0, 1.28, 0))
	_part(_body, _box(Vector3(0.44, 0.05, 0.32)), trim, Vector3(0, 1.0, 0))
	_part(_body, _box(Vector3(0.26, 0.28, 0.26)), skin, Vector3(0, 1.72, 0))
	# Tall pointed hat.
	_part(_body, _box(Vector3(0.44, 0.04, 0.44)), robe, Vector3(0, 1.88, 0))
	_part(_body, _cylinder(0.12, 0.4), robe, Vector3(0, 2.1, 0))
	_part(_body, _box(Vector3(0.1, 0.18, 0.1)), robe, Vector3(0.03, 2.36, 0.03), Vector3(0, 0, -0.4))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.05, 0.035, 0.02)), eyes, Vector3(0.06 * side, 1.75, -0.135))

	for side in [-1.0, 1.0]:
		var arm := _pivot(_body, Vector3(0.25 * side, 1.5, 0))
		_part(arm, _box(Vector3(0.12, 0.55, 0.12)), robe, Vector3(0, -0.27, 0))
		_part(arm, _box(Vector3(0.08, 0.1, 0.08)), skin, Vector3(0, -0.58, 0))
		arm.rotation.x = 0.3
		_arms_pivots.append(arm)

	_orb_material = _glow_material(Fireball.COLOR)
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.2
	orb_mesh.height = 0.4
	_orb = _part(_body, orb_mesh, _orb_material, Vector3(0, 1.55, -0.55))
	_orb.visible = false


func _build_armor() -> void:
	var iron := _material(Color(0.4, 0.38, 0.42), 0.7)
	_part(_body, _box(Vector3(0.46, 0.4, 0.34)), iron, Vector3(0, 1.3, 0))
	_part(_body, _box(Vector3(0.3, 0.1, 0.3)), iron, Vector3(0, 1.9, 0))


## Casters wear their gear as tier-colored robes with trim.
func _gear_style() -> String:
	return "robe"
