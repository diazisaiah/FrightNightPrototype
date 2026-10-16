class_name Arrow
extends Area3D
## Glowing skeleton arrow. Flies straight; hurts the player on contact and
## sticks into anything else for a few seconds.

const STUCK_TIME := 3.0

var damage := 5.0
var _velocity := Vector3.ZERO
var _life := 5.0
var _stuck := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3  # World and player.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 0.08, 0.6)
	shape.shape = box
	add_child(shape)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.012
	shaft_mesh.bottom_radius = 0.012
	shaft_mesh.height = 0.65
	shaft_mesh.material = Enemy._material(Color(0.45, 0.35, 0.25))
	shaft.mesh = shaft_mesh
	shaft.rotation.x = PI / 2
	add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.035
	tip_mesh.height = 0.12
	tip_mesh.material = Enemy._glow_material(Color(0.4, 0.85, 1.0))
	tip.mesh = tip_mesh
	tip.rotation.x = PI / 2
	tip.position.z = -0.33
	add_child(tip)

	# Lights up the fog as it flies, so it can be seen (and slipped) in the dark.
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 1.5
	light.omni_range = 3.0
	add_child(light)

	body_entered.connect(_on_body_entered)


## Call after adding to the tree.
func launch(from: Vector3, target: Vector3, speed: float, arrow_damage: float) -> void:
	global_position = from
	_velocity = (target - from).normalized() * speed
	damage = arrow_damage
	# Point along its flight (unless it's flying straight up or down, or nowhere).
	if _velocity.normalized().cross(Vector3.UP).length() > 0.01:
		look_at(from + _velocity, Vector3.UP)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if not _stuck:
		global_position += _velocity * delta


func _on_body_entered(body: Node3D) -> void:
	if _stuck:
		return
	if body is Player:
		# A slipped arrow keeps flying past.
		if body.receive_attack(damage, global_position - _velocity, "arrow") != "dodged":
			queue_free()
	else:
		_stuck = true
		_life = STUCK_TIME
		set_deferred("monitoring", false)
