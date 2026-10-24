class_name SpellBolt
extends Node3D
## The Catalyst's Elemental Fists (Ult): a fireball or icicle flung from a
## punch, flying straight ahead. A fireball bursts on the first monster it
## meets, burning everything around; an icicle pierces through the line,
## freezing each one it passes.

const SPEED := 20.0
const RANGE := 18.0
const HIT_RADIUS := 0.9
const FIRE_SPLASH := 1.8
const FIRE_BURN_TIME := 3.0
const ICE_SLOW := 0.5
const ICE_TIME := 2.5
const FIRE_COLOR := Color(1.0, 0.45, 0.08)
const ICE_COLOR := Color(0.6, 0.9, 1.0)

var kind := "fire"
var damage := 1.0
var direction := Vector3.FORWARD
## The monster the punch already hit (skipped).
var skip: Node = null

var _travelled := 0.0
var _hit := {}


static func fling(world: Node, from: Vector3, toward: Vector3, bolt_kind: String, bolt_damage: float, punched: Node) -> void:
	var bolt := SpellBolt.new()
	bolt.kind = bolt_kind
	bolt.damage = bolt_damage
	bolt.direction = toward.normalized()
	bolt.skip = punched
	world.add_child(bolt)
	bolt.global_position = from


func _ready() -> void:
	var color := FIRE_COLOR if kind == "fire" else ICE_COLOR
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 4.0
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.22, 0.22) if kind == "fire" else Vector3(0.07, 0.07, 0.5)
	mesh.material = glow
	body.mesh = mesh
	add_child(body)
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 20.0
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 1.0
	trail.gravity = Vector3(0, 1.0, 0) if kind == "fire" else Vector3.ZERO
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.06
	bit.material = glow
	trail.mesh = bit
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 1.2
	add_child(trail)
	Sfx.play_at("fire" if kind == "fire" else "zap", global_position, -6.0, 1.3 if kind == "fire" else 0.7)


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	global_position += direction * step
	_travelled += step
	if kind == "fire":
		rotation.z += delta * 8.0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy == skip or _hit.has(enemy):
			continue
		var offset := enemy.global_position + Vector3(0, 1.1, 0) - global_position
		if Vector2(offset.x, offset.z).length() > HIT_RADIUS or absf(offset.y) > 1.3:
			continue
		if kind == "fire":
			_burst(enemy)
			return
		_hit[enemy] = true
		enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.1, 0), direction * 2.0, false, "ICICLE")
		enemy.chill(ICE_TIME, ICE_SLOW)
		HitFx.burst(get_parent(), enemy.global_position + Vector3(0, 1.1, 0), direction, ICE_COLOR, 14, 3.0, true, 0.05)
	if _travelled >= RANGE:
		if kind == "fire":
			_burst(null)
		else:
			queue_free()


## Bursts into flame: the monster it hit and everything around it burn.
func _burst(struck: Enemy) -> void:
	var world := get_parent()
	var at := global_position
	HitFx.burst(world, at, Vector3.UP, FIRE_COLOR, 30, 5.0, true, 0.08)
	HitFx.flash(world, at, FIRE_COLOR, 0.8)
	Sfx.play_at("fire", at, 0.0, 0.9)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position + Vector3(0, 1.1, 0) - at
		if enemy != struck and offset.length() > FIRE_SPLASH:
			continue
		enemy.take_hit(damage if enemy == struck else damage * 0.5, enemy.global_position + Vector3(0, 1.1, 0), direction * 2.5, false, "FIREBALL")
		enemy.ignite(damage * 0.3, FIRE_BURN_TIME)
	queue_free()
