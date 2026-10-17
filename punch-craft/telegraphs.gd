class_name Telegraphs
extends Node3D
## Danger marked on the floor, for any enemy's big moves: a ring or a lane
## that fades in and pulses faster as the hit comes (one at a time), circles
## that burst after a fuse (and can leave poison behind), and shockwaves.
## Add one as a child of the enemy; hits are thrown by that enemy.

const DANGER := Color(1.0, 0.2, 0.08)
const POISON := Color(0.35, 1.0, 0.3)
const ZONE_RADIUS := 1.25

var enemy: Enemy
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
## Bursting circles: {center, radius, fuse, total, linger, tick, damage,
## tick_damage, color, node, fill, edge, poison}.
var _zones: Array = []


func _init(owner_enemy: Enemy) -> void:
	enemy = owner_enemy
	name = "Telegraphs"


func _physics_process(delta: float) -> void:
	_update_zones(delta)


# --- The mark (one ring or lane) ---

func show_ring(center: Vector3, radius: float, color := DANGER) -> void:
	_ensure_mark()
	if not _mark.mesh is CylinderMesh:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.01
		disc.radial_segments = 32
		disc.material = _mark_material
		_mark.mesh = disc
	_mark.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 1, radius)), center + Vector3.UP * 0.05)
	_mark_material.albedo_color = Color(color, _mark_material.albedo_color.a)
	_mark.visible = true


func show_lane(from: Vector3, to: Vector3, width: float, color := DANGER) -> void:
	_ensure_mark()
	if not _mark.mesh is BoxMesh:
		var box := BoxMesh.new()
		box.size = Vector3(1, 0.01, 1)
		box.material = _mark_material
		_mark.mesh = box
	var flat := to - from
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	var mid := from + flat * 0.5
	mid.y = enemy.global_position.y + 0.05
	var basis := Basis.looking_at(flat.normalized(), Vector3.UP).scaled(Vector3(width, 1, flat.length()))
	_mark.global_transform = Transform3D(basis, mid)
	_mark_material.albedo_color = Color(color, _mark_material.albedo_color.a)
	_mark.visible = true


## Fades the mark in and pulses it faster as the hit gets close (0-1).
func pulse(progress: float) -> void:
	if _mark == null or not _mark.visible:
		return
	progress = clampf(progress, 0.0, 1.0)
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 22.0, progress))
	_mark_material.albedo_color.a = lerpf(0.15, 0.55, progress) * (0.7 + 0.3 * beat)


func hide_mark() -> void:
	if _mark:
		_mark.visible = false


func _ensure_mark() -> void:
	if _mark:
		return
	_mark_material = material(Color(DANGER, 0.3))
	_mark = MeshInstance3D.new()
	_mark.top_level = true
	add_child(_mark)


# --- Bursting circles ---

## A circle that bursts after fuse seconds for damage; with linger, it leaves
## a cloud that deals tick_damage every half second you stand in it.
func spawn_zone(center: Vector3, fuse: float, damage: float, color := DANGER, radius := ZONE_RADIUS, linger := 0.0, tick_damage := 0.0) -> void:
	var node := Node3D.new()
	node.top_level = true
	add_child(node)
	node.global_position = center + Vector3.UP * 0.04
	var fill := material(Color(color, 0.0))
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 32
	disc.material = fill
	var disc_node := MeshInstance3D.new()
	disc_node.mesh = disc
	node.add_child(disc_node)
	var edge := material(Color(color, 0.8))
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.93
	ring.outer_radius = radius
	ring.rings = 40
	ring.material = edge
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.scale = Vector3(1, 0.3, 1)
	node.add_child(ring_node)
	_zones.append({"center": center, "radius": radius, "fuse": fuse, "total": fuse, "linger": linger, "tick": 0.5,
			"damage": damage, "tick_damage": tick_damage, "color": color, "node": node, "fill": fill, "edge": edge,
			"poison": linger > 0.0})


func _update_zones(delta: float) -> void:
	for zone in _zones.duplicate():
		if not is_instance_valid(zone.node):
			_zones.erase(zone)
			continue
		var color: Color = zone.color
		if zone.fuse > 0.0:
			zone.fuse -= delta
			var progress: float = 1.0 - zone.fuse / zone.total
			var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 22.0, progress))
			zone.fill.albedo_color = Color(color, lerpf(0.08, 0.4, progress) * (0.7 + 0.3 * beat))
			if zone.fuse <= 0.0:
				_burst(zone)
			continue
		if zone.linger > 0.0:
			zone.linger -= delta
			zone.tick -= delta
			zone.fill.albedo_color = Color(color, 0.25 * clampf(zone.linger, 0.0, 1.0))
			zone.edge.albedo_color = Color(color, 0.5 * clampf(zone.linger, 0.0, 1.0))
			if zone.tick <= 0.0:
				zone.tick = 0.5
				var player := enemy.player
				if is_instance_valid(player) and player.active and inside(zone.center, zone.radius):
					player._take_damage(zone.tick_damage, enemy)
					DamagePopup.spawn(enemy.get_parent(), "POISON", color, 28, player.global_position + Vector3(0, 1.4, 0))
			if zone.linger <= 0.0:
				zone.node.queue_free()
				_zones.erase(zone)
			continue
		zone.node.queue_free()
		_zones.erase(zone)


func _burst(zone: Dictionary) -> void:
	var color: Color = zone.color
	var at: Vector3 = zone.center
	var world := enemy.get_parent()
	Sfx.play_at("fire" if zone.poison else "quake", at, 0.0, 1.3 if zone.poison else 1.6)
	HitFx.burst(world, at + Vector3.UP * 0.2, Vector3.UP, color, 26, 7.0, true, 0.07)
	shockwave(at, zone.radius, color)
	var player := enemy.player
	if is_instance_valid(player) and player.active and inside(at, zone.radius):
		player.receive_attack(zone.damage, at, "zone", enemy)
	if zone.poison:
		zone.fill.albedo_color = Color(color, 0.25)
		var cloud := CPUParticles3D.new()
		cloud.amount = 10 if Settings.use_web_profile() else 18
		cloud.lifetime = 1.4
		cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cloud.emission_sphere_radius = zone.radius * 0.8
		cloud.gravity = Vector3(0, 0.25, 0)
		cloud.initial_velocity_min = 0.05
		cloud.initial_velocity_max = 0.2
		cloud.scale_amount_min = 2.0
		cloud.scale_amount_max = 4.0
		var puff := BoxMesh.new()
		puff.size = Vector3.ONE * 0.12
		puff.material = material(Color(color, 0.35))
		cloud.mesh = puff
		cloud.position.y = 0.5
		zone.node.add_child(cloud)


## The player is inside a circle (with a little give).
func inside(center: Vector3, radius := ZONE_RADIUS) -> bool:
	var player := enemy.player
	if not is_instance_valid(player):
		return false
	var flat := player.global_position - center
	flat.y = 0.0
	return flat.length() <= radius + 0.25


func clear() -> void:
	hide_mark()
	for zone in _zones:
		if is_instance_valid(zone.node):
			zone.node.queue_free()
	_zones.clear()


# --- Effects ---

func shockwave(at: Vector3, radius: float, color := DANGER) -> void:
	var wave_material := material(Color(color.lightened(0.3), 0.8))
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.material = wave_material
	var wave := MeshInstance3D.new()
	wave.mesh = mesh
	enemy.get_parent().add_child(wave)
	wave.global_position = at + Vector3.UP * 0.15
	wave.scale = Vector3(0.4, 1.0, 0.4)
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3(radius, 1.5, radius), 0.22).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wave_material, "albedo_color:a", 0.0, 0.32)
	tween.tween_callback(wave.queue_free)


static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_color = color
	return result
