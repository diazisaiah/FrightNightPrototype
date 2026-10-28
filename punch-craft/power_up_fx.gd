class_name PowerUpFx
extends Node3D
## Intense Yelling (the Over Nine Thousand emote): a golden aura around the
## fighter that swells the longer the yell is held. From ROCKS_AT seconds
## rocks tear off the ground around you and float up; from LIGHTNING_AT
## lightning strikes nearby. Held a full minute the first time (POOP_AT), it
## all cuts out and goes wrong: Pushed Too Hard, and the Overexerted emote.
## Rides on the player; freed when the emote ends.

const ROCKS_AT := 3.0
const LIGHTNING_AT := 6.0
## Seconds to the aura's full size.
const FULL_AT := 9.0
const POOP_AT := 60.0
const COLOR := Color(1.0, 0.84, 0.3)
const ROCK_COLORS := [Color(0.42, 0.38, 0.34), Color(0.33, 0.3, 0.28), Color(0.5, 0.45, 0.38)]

var _time := 0.0
var _aura: CPUParticles3D
var _shell: MeshInstance3D
var _shell_material: StandardMaterial3D
var _light: OmniLight3D
var _rock_wait := 0.0
var _bolt_wait := 0.0


func _ready() -> void:
	_aura = CPUParticles3D.new()
	_aura.amount = 40 if Settings.use_web_profile() else 70
	_aura.lifetime = 0.7
	# Flame-like streaks rising from a ring round the body (an outline, not
	# a wall in front of it).
	_aura.position = Vector3(0, 0.15, 0)
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_aura.emission_ring_axis = Vector3.UP
	_aura.emission_ring_height = 0.3
	_aura.emission_ring_radius = 0.5
	_aura.emission_ring_inner_radius = 0.42
	_aura.direction = Vector3.UP
	_aura.spread = 15.0
	_aura.gravity = Vector3(0, 3.0, 0)
	_aura.initial_velocity_min = 1.0
	_aura.initial_velocity_max = 2.4
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	_aura.scale_amount_curve = shrink
	var mote := BoxMesh.new()
	mote.size = Vector3(0.035, 0.16, 0.035)
	mote.material = Enemy._glow_material(COLOR)
	_aura.mesh = mote
	add_child(_aura)
	_shell = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.5
	capsule.height = 2.1
	_shell.mesh = capsule
	_shell.position = Vector3(0, 1.0, 0)
	_shell_material = StandardMaterial3D.new()
	_shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shell_material.albedo_color = Color(COLOR, 0.05)
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 1.0
	_light.omni_range = 4.0
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)
	Sfx.play_at("growl", global_position + Vector3.UP * 1.6, -2.0, 1.4)


func _process(delta: float) -> void:
	_time += delta
	if _time >= POOP_AT and not Achievements.has("pushed_too_hard"):
		Achievements.earn("pushed_too_hard")
		var fighter := get_parent() as Player
		if fighter:
			fighter.start_emote.call_deferred("overexerted")
		set_process(false)
		return
	var grow := clampf(_time / FULL_AT, 0.0, 1.0)
	var flicker := 1.0 + 0.06 * sin(_time * 40.0)
	_shell.scale = Vector3(1.0 + grow * 0.9, 1.0 + grow * 0.45, 1.0 + grow * 0.9) * flicker
	_shell_material.albedo_color = Color(COLOR, 0.05 + 0.07 * grow)
	_aura.emission_ring_radius = 0.5 + grow * 0.5
	_aura.emission_ring_inner_radius = 0.42 + grow * 0.45
	_aura.initial_velocity_max = 2.4 + grow * 3.0
	_aura.scale_amount_min = 1.0 + grow * 0.5
	_aura.scale_amount_max = 1.4 + grow
	_light.light_energy = (1.0 + grow * 5.0) * flicker
	_light.omni_range = 4.0 + grow * 4.0
	if _time >= ROCKS_AT:
		_rock_wait -= delta
		if _rock_wait <= 0.0:
			_rock_wait = lerpf(0.3, 0.06, grow)
			_rock()
	if _time >= LIGHTNING_AT:
		_bolt_wait -= delta
		if _bolt_wait <= 0.0:
			_bolt_wait = randf_range(0.25, 0.7) * lerpf(1.0, 0.5, grow)
			_strike()


## A chunk of ground tears loose and drifts up, tumbling.
func _rock() -> void:
	var world := get_parent().get_parent()
	if world == null:
		return
	var rock := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var size := randf_range(0.08, 0.26)
	mesh.size = Vector3(size, size * randf_range(0.6, 1.0), size * randf_range(0.7, 1.1))
	mesh.material = Look.block_material(ROCK_COLORS.pick_random(), 0.0)
	rock.mesh = mesh
	world.add_child(rock)
	var angle := randf() * TAU
	var spot := global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(0.9, 2.8)
	rock.global_position = spot + Vector3(0, 0.05, 0)
	var rise := randf_range(1.6, 4.0)
	var time := randf_range(1.4, 2.4)
	var tween := rock.create_tween().set_parallel()
	tween.tween_property(rock, "global_position", spot + Vector3(randf_range(-0.3, 0.3), rise, randf_range(-0.3, 0.3)), time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(rock, "rotation", Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), time)
	tween.tween_property(rock, "scale", Vector3.ONE * 0.01, 0.35).set_delay(time - 0.35)
	tween.chain().tween_callback(rock.queue_free)
	if randf() < 0.3:
		HitFx.burst(world, spot + Vector3(0, 0.1, 0), Vector3.UP, ROCK_COLORS[0], 5, 2.0, false, 0.05)


## Lightning comes down somewhere around you.
func _strike() -> void:
	var world := get_parent().get_parent()
	if world == null:
		return
	var angle := randf() * TAU
	var spot := global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.2, 4.0)
	Powers._bolt(world, spot + Vector3(randf_range(-1, 1), 7.0, randf_range(-1, 1)), spot + Vector3(0, 0.05, 0))
	HitFx.burst(world, spot + Vector3(0, 0.1, 0), Vector3.UP, Powers.CHAIN_COLOR, 12, 4.0, true, 0.05)
	HitFx.flash(world, spot + Vector3(0, 0.3, 0), Powers.CHAIN_COLOR, 0.6)
	Sfx.play_at("zap", spot, 0.0, randf_range(0.6, 0.9))
