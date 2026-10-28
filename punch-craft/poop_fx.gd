class_name PoopFx
extends Node3D
## Overexerted (the Pushed Too Hard emote): Intense Yelling with no aura,
## straight to the part where it all goes wrong. Each time the dance comes
## round to the end of the strain, a poop drops out behind the fighter.
## Rides on the player; freed when the emote ends.

## Seconds into each loop of the dance the poop drops (the end of the strain).
const DROP_AT := 1.2
const BROWN := Color(0.42, 0.26, 0.12)
const STINK := Color(0.55, 0.65, 0.2)

var _time := 0.0
var _cycle := 1.0
var _dropped := false


func _ready() -> void:
	_cycle = 0.0
	for key in Emotes.keys("overexerted"):
		_cycle += float(key[0])


func _process(delta: float) -> void:
	_time += delta
	var t := fposmod(_time, maxf(_cycle, 0.1))
	if t >= DROP_AT and not _dropped:
		_dropped = true
		var fighter := get_parent() as Node3D
		if fighter and fighter.get_parent():
			drop(fighter.get_parent(), fighter.global_position + fighter.global_basis.z * 0.22 + Vector3.UP * 0.75)
	elif t < DROP_AT:
		_dropped = false


## A poop falls from at to the floor, plops, steams green for a while, then
## shrinks away.
static func drop(world: Node, at: Vector3) -> void:
	var poop := Node3D.new()
	world.add_child(poop)
	poop.global_position = at
	var tiers := [[0.22, 0.0], [0.17, 0.4], [0.12, 0.8], [0.06, 1.2]]
	for i in tiers.size():
		var part := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var width: float = tiers[i][0]
		mesh.size = Vector3(width, 0.07, width)
		mesh.material = Look.block_material(BROWN if i % 2 == 0 else BROWN.darkened(0.15), 0.1)
		part.mesh = mesh
		part.position = Vector3(0, 0.035 + i * 0.06, 0)
		part.rotation.y = tiers[i][1]
		poop.add_child(part)
	var floor_y := at.y - 0.75
	var tween := poop.create_tween()
	tween.tween_property(poop, "global_position:y", floor_y, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Sfx.play_at("heavy", poop.global_position, -6.0, 1.8)
		var stink := CPUParticles3D.new()
		stink.amount = 10
		stink.lifetime = 1.4
		stink.position = Vector3(0, 0.2, 0)
		stink.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		stink.emission_sphere_radius = 0.12
		stink.direction = Vector3.UP
		stink.gravity = Vector3(0, 0.4, 0)
		stink.initial_velocity_min = 0.2
		stink.initial_velocity_max = 0.5
		var puff := BoxMesh.new()
		puff.size = Vector3(0.03, 0.12, 0.03)
		puff.material = Enemy._glow_material(STINK)
		stink.mesh = puff
		poop.add_child(stink))
	tween.tween_property(poop, "scale", Vector3(1.3, 0.7, 1.3), 0.08)
	tween.tween_property(poop, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(5.0)
	tween.tween_property(poop, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(poop.queue_free)
