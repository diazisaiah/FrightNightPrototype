class_name Crowd
extends Node3D
## An audience of monsters that never fight (the Dead League stages). Each
## kind is baked once into a single mesh (all its voxel parts merged, no AI,
## no collision) in two poses, calm and arms up, and drawn as MultiMeshes, so
## a full crowd costs a handful of draw calls. They bob and sway; cheer()
## throws their arms up and makes them hop for a moment. They keep the real
## voxel bodies everywhere, phones included (the user, 2026-11-04).
##   var crowd := Crowd.new(); parent.add_child(crowd)
##   crowd.add("res://zombie.tscn", Transform3D(...)); ...; crowd.finish()

## Baked meshes, "scene|pose" -> ArrayMesh (kept for the session).
static var _baked := {}

var _pending: Array = []
var _members: Array = []
var _batches := {}  # scene path -> {"calm": MultiMesh, "cheer": MultiMesh}
var _time := 0.0


## Queues one spectator of the monster in scene at xform (facing its -Z).
func add(scene: String, xform: Transform3D, size := 1.0) -> void:
	_pending.append({"scene": scene, "xform": xform.scaled_local(Vector3.ONE * size)})


## Bakes the kinds and builds the MultiMeshes. Call once, inside the tree.
func finish() -> void:
	var counts := {}
	for entry in _pending:
		counts[entry.scene] = int(counts.get(entry.scene, 0)) + 1
	for scene in counts:
		var pair := {}
		for pose in ["calm", "cheer"]:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = _bake(self, scene, pose)
			multimesh.instance_count = counts[scene]
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = multimesh
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
			pair[pose] = multimesh
		_batches[scene] = pair
	var next := {}
	for entry in _pending:
		var slot: int = next.get(entry.scene, 0)
		next[entry.scene] = slot + 1
		_members.append({
			"batch": _batches[entry.scene], "base": entry.xform,
			"phase": randf() * TAU, "speed": randf_range(0.8, 1.3),
			"cheer_from": INF, "cheer_until": -1.0,
		})
	_pending.clear()
	_pose_all()


## Arms up and hopping for a second or so; strength is the share who join.
func cheer(strength := 1.0) -> void:
	for member in _members:
		if randf() <= strength:
			member.cheer_from = _time + randf() * 0.3
			member.cheer_until = member.cheer_from + randf_range(0.9, 1.8)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_pose_all()


## Each pose's MultiMesh draws only the members in that pose: they're packed
## to the front and visible_instance_count cut to them.
func _pose_all() -> void:
	var used := {}
	for member in _members:
		var t: float = _time * member.speed + member.phase
		var cheering: bool = _time >= member.cheer_from and _time < member.cheer_until
		var lift := absf(sin(t * 7.0)) * 0.22 if cheering else (sin(t * 1.6) * 0.5 + 0.5) * 0.04
		var sway := sin(t * (5.0 if cheering else 0.9)) * (0.1 if cheering else 0.05)
		var xform: Transform3D = member.base * Transform3D(Basis.from_euler(Vector3(0, 0, sway)), Vector3(0, lift, 0))
		var multimesh: MultiMesh = member.batch.cheer if cheering else member.batch.calm
		var slot: int = used.get(multimesh, 0)
		multimesh.set_instance_transform(slot, xform)
		used[multimesh] = slot + 1
	for scene in _batches:
		for pose in ["calm", "cheer"]:
			var multimesh: MultiMesh = _batches[scene][pose]
			multimesh.visible_instance_count = used.get(multimesh, 0)


## One monster's body as a single mesh: built by the real scene (so it looks
## exactly like the ones you fight), voxelized, posed, then every visible part
## merged by material and the monster thrown away.
static func _bake(holder: Node, scene: String, pose: String) -> ArrayMesh:
	var key := scene + "|" + pose
	if _baked.has(key):
		return _baked[key]
	var enemy := (load(scene) as PackedScene).instantiate() as Enemy
	enemy.setup(null, false)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	holder.add_child(enemy)
	enemy.remove_from_group("enemies")
	enemy._voxelize_parts()
	if pose == "cheer":
		for arm in enemy._hand_nodes():
			if arm is Node3D:
				var node := arm as Node3D
				node.rotation = Vector3(PI - 0.3, 0, 0.4 * signf(node.position.x))
	var tools := {}
	var inverse := enemy.global_transform.affine_inverse()
	for node in enemy.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.mesh == null or not part.is_visible_in_tree():
			continue
		var xform := inverse * part.global_transform
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface)
			if not tools.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material] = tool
			(tools[material] as SurfaceTool).append_from(part.mesh, surface, xform)
	var mesh := ArrayMesh.new()
	for material in tools:
		(tools[material] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	holder.remove_child(enemy)
	enemy.free()
	_baked[key] = mesh
	return mesh
