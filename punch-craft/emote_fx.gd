class_name EmoteFx
extends Node3D
## Effects timed to a dance: the dance file's "fx" list, each {"t": seconds
## into the dance, "do": what}. "dust" is a puff at a foot (x / z: where, in
## meters from the fighter; big: a stomp's burst); "aura" is a few soft motes
## rising round the fighter for "for" seconds. Replays each time the dance
## loops. Rides on the player; freed when the emote ends.

const DUST := Color(0.78, 0.7, 0.55)
const AURA := Color(0.85, 0.92, 1.0)

var _events: Array = []
var _length := 1.0
var _time := 0.0
var _next := 0


func setup(id: String) -> EmoteFx:
	var data := Emotes.raw(id)
	_events = data.get("fx", []).duplicate()
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_length = maxf(float(data.get("length", 1.0)), 0.01)
	return self


func _process(delta: float) -> void:
	advance(delta)


## Moves the clock on, firing what comes due (the Emote Studio steps it by hand).
func advance(delta: float) -> void:
	_time += delta
	_fire_due()
	if _time >= _length:
		_time -= _length
		_next = 0
		_fire_due()


func _fire_due() -> void:
	while _next < _events.size() and float(_events[_next].t) <= _time:
		_fire(_events[_next])
		_next += 1


func _fire(event: Dictionary) -> void:
	match String(event.get("do", "")):
		"dust":
			_dust(event)
		"aura":
			_aura(float(event.get("for", 1.5)))


func _dust(event: Dictionary) -> void:
	var world := get_parent().get_parent() if get_parent() else null
	if world == null:
		return
	var spot := to_global(Vector3(float(event.get("x", 0.0)), 0.03, float(event.get("z", 0.0))))
	var big := bool(event.get("big", false))
	HitFx.burst(world, spot, Vector3.UP, DUST, 22 if big else 9, 2.0 if big else 1.2, false, 0.045)


func _aura(seconds: float) -> void:
	var motes := CPUParticles3D.new()
	motes.amount = 14 if Settings.use_web_profile() else 24
	motes.lifetime = 0.8
	motes.position = Vector3(0, 0.15, 0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_height = 0.3
	motes.emission_ring_radius = 0.7
	motes.emission_ring_inner_radius = 0.58
	motes.direction = Vector3.UP
	motes.spread = 12.0
	motes.gravity = Vector3(0, 2.0, 0)
	motes.initial_velocity_min = 0.6
	motes.initial_velocity_max = 1.6
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	motes.scale_amount_curve = shrink
	var mote := BoxMesh.new()
	mote.size = Vector3(0.022, 0.11, 0.022)
	mote.material = Enemy._glow_material(AURA)
	motes.mesh = mote
	add_child(motes)
	var light := OmniLight3D.new()
	light.light_color = AURA
	light.light_energy = 0.7
	light.omni_range = 3.0
	light.position = Vector3(0, 1.1, 0)
	add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, seconds)
	tween.tween_callback(light.queue_free)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(motes):
		motes.emitting = false
		await get_tree().create_timer(1.0).timeout
	if is_instance_valid(motes):
		motes.queue_free()
