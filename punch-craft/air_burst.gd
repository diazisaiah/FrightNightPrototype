class_name AirBurst
extends Node3D
## Gale: a burst of air thrown from a punch, flying straight ahead through
## everything in its line (each monster once). Buffet makes it stagger;
## Updraft (an uppercut's burst) knocks monsters off their feet.

const SPEED := 24.0
const RANGE := 8.0
const HIT_RADIUS := 0.8
const PUSH := 4.0

var damage := 1.0
var direction := Vector3.FORWARD
var lift := false

var _range := RANGE
var _travelled := 0.0
var _hit := {}
var _shell: MeshInstance3D


static func fling(world: Node, from: Vector3, toward: Vector3, burst_damage: float, uppercut := false) -> void:
	var burst := AirBurst.new()
	burst.damage = burst_damage
	burst.direction = toward.normalized()
	burst.lift = uppercut and GameState.has_effect("updraft")
	world.add_child(burst)
	burst.global_position = from


func _ready() -> void:
	_range = RANGE + GameState.get_effect("gale_range")
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP)
	# A flat, see-through crescent of wind with a brighter edge.
	_shell = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.9, 0.12, 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(Powers.GALE_COLOR, 0.45)
	material.emission_enabled = true
	material.emission = Powers.GALE_COLOR
	material.emission_energy_multiplier = 2.5
	mesh.material = material
	_shell.mesh = mesh
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	for side: float in [-1.0, 1.0]:
		var tip := MeshInstance3D.new()
		var tip_mesh := BoxMesh.new()
		tip_mesh.size = Vector3(0.3, 0.1, 0.22)
		tip_mesh.material = material
		tip.mesh = tip_mesh
		tip.position = Vector3(0.5 * side, 0, 0.14)
		tip.rotation.y = -0.5 * side
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tip)
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 30.0
	trail.initial_velocity_min = 0.5
	trail.initial_velocity_max = 1.5
	trail.gravity = Vector3.ZERO
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.06
	bit.material = Enemy._glow_material(Powers.GALE_COLOR)
	trail.mesh = bit
	add_child(trail)
	Sfx.play_at("whoosh", global_position, -6.0, 1.4)


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	global_position += direction * step
	_travelled += step
	_shell.scale.x = 1.0 + _travelled / _range * 0.6
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or _hit.has(enemy):
			continue
		var offset := enemy.global_position + Vector3(0, 1.1, 0) - global_position
		if Vector2(offset.x, offset.z).length() > HIT_RADIUS or absf(offset.y) > 1.4:
			continue
		_hit[enemy] = true
		var at := enemy.global_position + Vector3(0, 1.1, 0)
		enemy.take_hit(damage, at, direction * PUSH, GameState.has_effect("gale_stagger"), "GALE")
		if lift and not enemy.is_dead() and not enemy.is_boss:
			enemy.knock_down(0.7, direction + Vector3.UP)
		HitFx.burst(get_parent(), at, direction, Powers.GALE_COLOR, 16, 4.0, true, 0.05)
	if _travelled >= _range:
		queue_free()
