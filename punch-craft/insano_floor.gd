class_name InsanoFloor
extends Node3D
## The True Coffin King's Insano round: big parts of the ring (half of it, two
## opposite corners, the edges or the middle) glow, then burn for a while.
## There's always somewhere safe. Only the player is hurt.

const COLOR := Color(0.9, 0.12, 0.4)
## Seconds between patterns, of warning, and of burning.
const EVERY := Vector2(3.0, 4.5)
const WARN := 1.3
const BURN := 2.6
const TICK := 0.4
## Each tick takes this share of the King's punch.
const TICK_SHARE := 0.35

var center := Vector3.ZERO
var half := 4.0
var player: Player
## The King (his punch sets the burn).
var king: Node3D

var _wait := 2.0
var _zones: Array[Dictionary] = []
var _phase := ""
var _phase_time := 0.0
var _tick := 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_phase_time -= delta
	match _phase:
		"":
			_wait -= delta
			if _wait <= 0.0:
				_lay(_pattern())
		"warn":
			var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(8.0, 22.0, 1.0 - _phase_time / WARN))
			for zone in _zones:
				(zone.fill as StandardMaterial3D).albedo_color.a = lerpf(0.12, 0.42, 1.0 - _phase_time / WARN) * (0.7 + 0.3 * beat)
			if _phase_time <= 0.0:
				_ignite()
		"burn":
			_tick -= delta
			if _tick <= 0.0:
				_tick = TICK
				if player.active and _standing_in():
					var hit: float = (float(king.get("attack_damage")) if is_instance_valid(king) else 6.0) * TICK_SHARE
					player._take_damage(hit, null)
					DamagePopup.spawn(get_parent(), "BURN", COLOR, 26, player.global_position + Vector3(0, 1.4, 0))
			if _phase_time <= 0.0:
				_clear()


## Stops (the round's over) and clears the floor.
func stop() -> void:
	_clear()
	set_physics_process(false)


## Rectangles (x0, z0, x1, z1 as shares of the half size, -1 to 1) covering
## about half the ring.
func _pattern() -> Array:
	var patterns := [
		[Rect2(-1, -1, 1, 2)], [Rect2(0, -1, 1, 2)], [Rect2(-1, -1, 2, 1)], [Rect2(-1, 0, 2, 1)],
		[Rect2(-1, -1, 1, 1), Rect2(0, 0, 1, 1)], [Rect2(0, -1, 1, 1), Rect2(-1, 0, 1, 1)],
		[Rect2(-1, -1, 2, 0.45), Rect2(-1, 0.55, 2, 0.45), Rect2(-1, -0.55, 0.45, 1.1), Rect2(0.55, -0.55, 0.45, 1.1)],
		[Rect2(-0.6, -0.6, 1.2, 1.2)],
	]
	return patterns.pick_random()


func _lay(rects: Array) -> void:
	_clear()
	for rect in rects:
		var r: Rect2 = rect
		var size := Vector3(r.size.x * half, 0.03, r.size.y * half)
		var at := center + Vector3((r.position.x + r.size.x / 2.0) * half, 0.04, (r.position.y + r.size.y / 2.0) * half)
		var fill := Telegraphs.material(Color(COLOR, 0.12))
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = fill
		var plate := MeshInstance3D.new()
		plate.mesh = mesh
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plate)
		plate.global_position = at
		_zones.append({"node": plate, "fill": fill, "at": at, "size": size})
	_phase = "warn"
	_phase_time = WARN
	Sfx.play("tell", -2.0, 0.7)


func _ignite() -> void:
	_phase = "burn"
	_phase_time = BURN
	_tick = 0.0
	Sfx.play("fire", 0.0, 0.7)
	for zone in _zones:
		var fill: StandardMaterial3D = zone.fill
		fill.albedo_color = Color(1.0, 0.3, 0.5, 0.55)
		fill.emission_enabled = true
		fill.emission = COLOR
		fill.emission_energy_multiplier = 2.5
		var flames := CPUParticles3D.new()
		flames.amount = 10 if Settings.use_web_profile() else 20
		flames.lifetime = 0.7
		flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		flames.emission_box_extents = Vector3(zone.size.x / 2.0, 0.02, zone.size.z / 2.0)
		flames.direction = Vector3.UP
		flames.spread = 10.0
		flames.gravity = Vector3(0, 2.0, 0)
		flames.initial_velocity_min = 0.8
		flames.initial_velocity_max = 2.0
		var mote := BoxMesh.new()
		mote.size = Vector3(0.06, 0.2, 0.06)
		mote.material = Enemy._glow_material(COLOR)
		flames.mesh = mote
		(zone.node as Node3D).add_child(flames)


func _standing_in() -> bool:
	var at := player.global_position
	for zone in _zones:
		var c: Vector3 = zone.at
		var size: Vector3 = zone.size
		if absf(at.x - c.x) <= size.x / 2.0 and absf(at.z - c.z) <= size.z / 2.0 and at.y < c.y + 0.6:
			return true
	return false


func _clear() -> void:
	for zone in _zones:
		if is_instance_valid(zone.node):
			(zone.node as Node3D).queue_free()
	_zones.clear()
	_phase = ""
	_wait = randf_range(EVERY.x, EVERY.y)
