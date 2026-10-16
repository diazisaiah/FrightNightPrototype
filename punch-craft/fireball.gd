class_name Fireball
extends Area3D
## A Fire Mage's fireball. Slower than an arrow and flies straight at where the
## player was, so it can be outrun sideways, or slipped (either side) when it
## arrives. Bursts on contact with anything.

const COLOR := Color(1.0, 0.45, 0.1)
## A Lich's bolts are the same thing in purple. Set before adding to the tree.
const BOLT_COLOR := Color(0.7, 0.35, 1.0)

var damage := 7.0
var color := COLOR
var _velocity := Vector3.ZERO
var _life := 6.0
var _core: MeshInstance3D
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # World and player.
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	_core = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = Enemy._glow_material(color)
	_core.mesh = mesh
	add_child(_core)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 5.0
	add_child(light)

	# A trail of embers.
	var trail := CPUParticles3D.new()
	trail.amount = 24
	trail.lifetime = 0.4
	trail.local_coords = false
	var ember := BoxMesh.new()
	ember.size = Vector3.ONE * 0.06
	ember.material = Enemy._glow_material(color.lightened(0.3))
	trail.mesh = ember
	trail.spread = 180.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.8
	trail.gravity = Vector3(0, 1.0, 0)
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.2
	add_child(trail)

	body_entered.connect(_on_body_entered)


## Call after adding to the tree.
func launch(from: Vector3, target: Vector3, speed: float, fireball_damage: float) -> void:
	global_position = from
	_velocity = (target - from).normalized() * speed
	damage = fireball_damage


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_time += delta
	_core.scale = Vector3.ONE * (1.0 + 0.15 * sin(_time * 30.0))
	global_position += _velocity * delta


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		# A slipped fireball keeps flying past.
		if body.receive_attack(damage, global_position - _velocity, "fireball") == "dodged":
			return
	_burst()


func _burst() -> void:
	HitFx.burst(get_parent(), global_position, -_velocity.normalized() + Vector3.UP, color, 20, 4.0, true, 0.07)
	Sfx.play_at("fire", global_position, -4.0)
	queue_free()
