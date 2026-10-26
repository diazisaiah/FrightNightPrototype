class_name MoveFx
## Effects that make the passives and ultimates read (2026-10-25, pass 2): a
## streak along a blink, a fading afterimage, Echo Fists' ghost fist, the
## swoosh of an automatic slip, speed lines in the view and the Grudge skull.
## HitFx has the hit sparks, flashes and rings.


## A glowing streak from one point to another that fades out.
static func streak(parent: Node, from: Vector3, to: Vector3, color: Color, width := 0.08, life := 0.35) -> void:
	if from.is_equal_approx(to):
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, from.distance_to(to))
	var material := _clear(color, 4.0)
	mesh.material = material
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(line)
	line.global_position = (from + to) / 2.0
	line.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var tween := line.create_tween().set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, life)
	tween.tween_property(line, "scale", Vector3(0.2, 0.2, 1.0), life)
	tween.chain().tween_callback(line.queue_free)


## A see-through silhouette left standing where you were, fading out.
static func afterimage(parent: Node, at: Vector3, color: Color, life := 0.45) -> void:
	var ghost := Node3D.new()
	parent.add_child(ghost)
	ghost.global_position = at
	var material := _clear(Color(color, 0.45), 2.0)
	for part in [[Vector3(0.42, 0.75, 0.24), Vector3(0, 1.15, 0)], [Vector3(0.28, 0.28, 0.26), Vector3(0, 1.68, 0)],
			[Vector3(0.36, 0.8, 0.22), Vector3(0, 0.4, 0)]]:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = material
		block.mesh = mesh
		block.position = part[1]
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ghost.add_child(block)
	var tween := ghost.create_tween().set_parallel()
	tween.tween_property(material, "albedo_color:a", 0.0, life)
	tween.tween_property(ghost, "scale", Vector3(1.15, 1.05, 1.15), life)
	tween.chain().tween_callback(ghost.queue_free)


## A see-through fist that flies from from to to in time, then pops.
static func ghost_fist(parent: Node, from: Vector3, to: Vector3, color: Color, time: float) -> void:
	var fist := Node3D.new()
	parent.add_child(fist)
	fist.global_position = from
	if not from.is_equal_approx(to):
		fist.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var material := _clear(Color(color, 0.6), 3.0)
	# A palm, four knuckles in a row up front, and a thumb across.
	var parts := [[Vector3(0.15, 0.12, 0.13), Vector3.ZERO], [Vector3(0.06, 0.05, 0.1), Vector3(-0.09, -0.03, -0.04)]]
	for k in 4:
		parts.append([Vector3(0.036, 0.05, 0.05), Vector3(-0.057 + k * 0.038, 0.035, -0.085)])
	for part in parts:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = material
		block.mesh = mesh
		block.position = part[1]
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fist.add_child(block)
	fist.scale = Vector3.ONE * 0.6
	var tween := fist.create_tween()
	tween.tween_property(fist, "global_position", to, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(fist, "scale", Vector3.ONE * 1.3, time)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.1)
	tween.tween_callback(fist.queue_free)


## A swoosh across the view (an attack slipping past): streaks sweep from one
## side of the camera to the other. side: -1 sweeps toward the left, 1 right.
static func swoosh(camera: Camera3D, side: float, color: Color) -> void:
	var sweep := Node3D.new()
	camera.add_child(sweep)
	var material := _clear(Color(color, 0.7), 3.0)
	for i in 6:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.5 - i * 0.04, 0.012, 0.012)
		mesh.material = material
		line.mesh = mesh
		line.position = Vector3(0, -0.25 + i * 0.1, -1.2 - i * 0.04)
		line.rotation.z = (i - 2.5) * 0.06 * side
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sweep.add_child(line)
	sweep.position.x = -0.9 * side
	var tween := sweep.create_tween().set_parallel()
	tween.tween_property(sweep, "position:x", 0.9 * side, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22).set_delay(0.06)
	tween.chain().tween_callback(sweep.queue_free)


## Speed lines rushing past the edges of the view, on the camera. Turn them
## on and off with emitting; speed_scale sets how hard they rush.
static func speed_lines(camera: Camera3D, color: Color) -> CPUParticles3D:
	var lines := CPUParticles3D.new()
	lines.amount = 36
	lines.lifetime = 0.35
	lines.local_coords = true
	lines.emitting = false
	lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	lines.emission_ring_axis = Vector3(0, 0, 1)
	lines.emission_ring_radius = 1.5
	lines.emission_ring_inner_radius = 0.9
	lines.emission_ring_height = 0.5
	lines.position = Vector3(0, 0, -3.0)
	lines.direction = Vector3(0, 0, 1)
	lines.spread = 0.0
	lines.gravity = Vector3.ZERO
	lines.initial_velocity_min = 10.0
	lines.initial_velocity_max = 14.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, 0.9)
	mesh.material = _clear(Color(color, 0.55), 2.0)
	lines.mesh = mesh
	camera.add_child(lines)
	return lines


## The Grudge mark: a glowing red skull to float over the marked monster.
static func skull(color: Color) -> Node3D:
	var head := Node3D.new()
	var bone := Enemy._glow_material(color)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.0, 0.0)
	for part in [[Vector3(0.32, 0.26, 0.28), Vector3(0, 0.05, 0), bone], [Vector3(0.22, 0.1, 0.2), Vector3(0, -0.12, -0.02), bone]]:
		_block(head, part[0], part[1], part[2])
	for side in [-1.0, 1.0]:
		for face in [-1.0, 1.0]:
			_block(head, Vector3(0.08, 0.08, 0.02), Vector3(0.07 * side, 0.06, 0.141 * face), dark)
	for face in [-1.0, 1.0]:
		_block(head, Vector3(0.04, 0.05, 0.02), Vector3(0, -0.02, 0.141 * face), dark)
	return head


static func _block(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	block.mesh = mesh
	block.position = pos
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(block)


## A see-through glowing material that ignores the lights.
static func _clear(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
