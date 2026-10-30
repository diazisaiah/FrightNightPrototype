class_name FxWarmup
## Compiles the effects' shaders while the loading screen (or the VS card)
## still covers a fight. Browsers can't keep compiled shaders between visits,
## so an effect's first appearance used to stall the fight mid-swing (a
## power's first burst, an ultimate's first use: 50-170ms on a desktop with no
## shader cache, far more in a browser; 2026-10-29). Each effect plays once,
## tiny, just ahead of the camera, for a few frames.
## 2026-10-30 (an itch player: "a half second pause on every hit"): a
## stand-in monster also takes a hit, a chill and a Doom mark, and each of
## your selected powers goes off on it, so the hit flash, the status looks,
## the knockout text and the powers' effects are compiled before the fight.

const FRAMES := 6


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
	await _stand_in(holder, at, player)
	for i in FRAMES:
		await world.get_tree().process_frame
	if is_instance_valid(holder):
		holder.queue_free()


## A zombie that can't die, out of the fight (not in "enemies"), hit and
## marked, with your powers going off on it.
static func _stand_in(holder: Node3D, at: Vector3, player: Player) -> void:
	var dummy: Enemy = load("res://zombie.tscn").instantiate()
	dummy.setup(player, false, {"hat": ""})
	dummy.max_hp = 1e9
	dummy.hp = 1e9
	holder.add_child(dummy)
	dummy.global_position = at
	dummy.remove_from_group("enemies")
	dummy.set_physics_process(false)
	await holder.get_tree().process_frame
	if not is_instance_valid(dummy):
		return
	dummy.take_hit(1.0, at + Vector3(0, 1.3, 0), Vector3.ZERO, true, "COUNTER!")
	dummy.take_hit(1.0, at + Vector3(0, 1.3, 0), Vector3.ZERO, false, "CRIT!")
	dummy.chill(0.5, 0.5, true)
	dummy.doom(0.5)
	for root in GameState.selected_powers():
		match root:
			"sigil_fire": Powers.fire_burst(dummy, 0.01)
			"sigil_frost": Powers.frost_burst(dummy)
			"sigil_storm": Powers.chain_lightning(dummy, 0.01, 0)
			"sigil_doom": Powers.doom_mark(dummy, false)
			"sigil_blood": Powers.blood_drain(dummy, player)
	DamagePopup.spawn(holder, "GOODNIGHT!", Color(1, 1, 1, 0.05), 86, at)
