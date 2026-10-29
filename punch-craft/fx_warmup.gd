class_name FxWarmup
## Compiles the effects' shaders while the loading screen (or the VS card)
## still covers a fight. Browsers can't keep compiled shaders between visits,
## so an effect's first appearance used to stall the fight mid-swing (a
## power's first burst, an ultimate's first use: 50-170ms on a desktop with no
## shader cache, far more in a browser; 2026-10-29). Each effect plays once,
## tiny, just ahead of the camera, for a few frames.

const FRAMES := 4


static func run(world: Node3D, player: Player) -> void:
	var camera := player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	var holder := Node3D.new()
	holder.name = "FxWarmup"
	world.add_child(holder)
	var at := camera.global_position - camera.global_basis.z * 3.0
	holder.global_position = at
	var white := Color(1, 1, 1, 0.05)
	HitFx.burst(holder, at, Vector3.UP, white, 1, 0.01, false, 0.01)
	HitFx.burst(holder, at, Vector3.UP, white, 1, 0.01, true, 0.01)
	HitFx.flash(holder, at, white, 0.01)
	HitFx.ring(holder, at, white, 0.01)
	HitFx.coins(holder, at, 10101)
	DamagePopup.spawn(holder, ".", white, 8, at)
	Powers._bolt(holder, at, at + Vector3(0.01, 0, 0))
	var glow := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.01
	box.material = Enemy._glow_material(white)
	glow.mesh = box
	holder.add_child(glow)
	# Temporal Break's frozen sparks and its shell.
	player.ult._frozen_spark(at).reparent(holder)
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.01
	sphere.height = 0.02
	shell.mesh = sphere
	shell.material_override = Ult.time_shell_material()
	holder.add_child(shell)
	# The fighter's own ultimate.
	match GameState.ultimate():
		"the_family":
			var goon := Goon.new()
			goon.warm = true
			holder.add_child(goon)
			goon.scale = Vector3.ONE * 0.01
		"flame_burst":
			player.ult._burst_fx(holder, at, 0.01)
	for i in FRAMES:
		await world.get_tree().process_frame
	if is_instance_valid(holder):
		holder.queue_free()
