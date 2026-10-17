class_name Hazard
extends Node3D
## A light hazard of the deeper tiers, always marked and avoidable. Only the
## player is hurt by them.
##   toxic: a bubbling green puddle; standing in it stings every half second
##          (no flinch).
##   fire:  a cracked vent that glows, then every few seconds warns (a ring
##          brightens and pulses for a second) and erupts in a pillar of fire.

const TOXIC_COLOR := Color(0.45, 1.0, 0.2)
const FIRE_COLOR := Color(1.0, 0.45, 0.1)
const TICK := 0.5
const FIRE_EVERY := Vector2(4.0, 7.0)
const FIRE_WARN := 1.0

var kind := "toxic"
var radius := 1.4
## Damage of an eruption (fire) or a tick (toxic).
var damage := 4.0
var player: Player

var _timer := 0.0
var _warning := false
var _fill: StandardMaterial3D
var _edge: StandardMaterial3D
var _bubbles: CPUParticles3D


static func make(hazard_kind: String, at: Vector3, size: float, hit: float, target: Player) -> Hazard:
	var hazard := Hazard.new()
	hazard.kind = hazard_kind
	hazard.radius = size
	hazard.damage = hit
	hazard.player = target
	hazard.position = at
	return hazard


func _ready() -> void:
	var color := TOXIC_COLOR if kind == "toxic" else FIRE_COLOR
	_fill = Telegraphs.material(Color(color, 0.32 if kind == "toxic" else 0.12))
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius * 1.05
	disc.height = 0.02
	disc.radial_segments = 24
	disc.material = _fill
	var pool := MeshInstance3D.new()
	pool.mesh = disc
	pool.position.y = 0.02
	add_child(pool)
	_edge = Telegraphs.material(Color(color, 0.35))
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.92
	ring.outer_radius = radius
	ring.rings = 32
	ring.material = _edge
	var rim := MeshInstance3D.new()
	rim.mesh = ring
	rim.scale = Vector3(1, 0.25, 1)
	rim.position.y = 0.03
	add_child(rim)
	if kind == "fire":
		# The vent: a ring of cracked stones around a glowing hole.
		var stone := Look.block_material(Color(0.12, 0.1, 0.1))
		for i in 6:
			var a := i * TAU / 6.0
			Scenery.box(self, Vector3(0.45, 0.18, 0.3), Vector3(cos(a) * radius * 0.55, 0.09, sin(a) * radius * 0.55), stone, Vector3(0, -a, 0))
		var core := MeshInstance3D.new()
		var glow := BoxMesh.new()
		glow.size = Vector3(0.5, 0.05, 0.5)
		glow.material = Enemy._glow_material(FIRE_COLOR)
		core.mesh = glow
		core.position.y = 0.04
		add_child(core)
		_timer = randf_range(FIRE_EVERY.x, FIRE_EVERY.y)
	else:
		_bubbles = CPUParticles3D.new()
		_bubbles.amount = 4 if Settings.use_web_profile() else 8
		_bubbles.lifetime = 1.2
		_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_bubbles.emission_box_extents = Vector3(radius * 0.7, 0.02, radius * 0.7)
		_bubbles.gravity = Vector3(0, 0.4, 0)
		_bubbles.initial_velocity_min = 0.05
		_bubbles.initial_velocity_max = 0.2
		var bubble := BoxMesh.new()
		bubble.size = Vector3.ONE * 0.07
		bubble.material = Enemy._glow_material(TOXIC_COLOR)
		_bubbles.mesh = bubble
		_bubbles.position.y = 0.05
		add_child(_bubbles)
		_timer = TICK


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_timer -= delta
	if kind == "toxic":
		if _timer <= 0.0:
			_timer = TICK
			if player.active and _inside():
				player._take_damage(damage, null)
				DamagePopup.spawn(get_parent(), "TOXIC", TOXIC_COLOR, 26, player.global_position + Vector3(0, 1.4, 0))
		return
	# Fire: idle, then a one-second warning, then the eruption.
	if not _warning and _timer <= FIRE_WARN:
		_warning = true
	if _warning:
		var progress := 1.0 - clampf(_timer / FIRE_WARN, 0.0, 1.0)
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(8.0, 24.0, progress))
		_fill.albedo_color.a = lerpf(0.15, 0.5, progress) * (0.7 + 0.3 * beat)
		_edge.albedo_color.a = 0.9
	if _timer <= 0.0:
		_erupt()
		_warning = false
		_fill.albedo_color.a = 0.12
		_edge.albedo_color.a = 0.35
		_timer = randf_range(FIRE_EVERY.x, FIRE_EVERY.y)


func _erupt() -> void:
	var at := global_position
	Sfx.play_at("fire", at, 2.0, 0.8)
	HitFx.burst(get_parent(), at + Vector3.UP * 0.3, Vector3.UP, FIRE_COLOR, 28, 9.0, true, 0.09)
	var pillar := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = radius * 0.5
	column.bottom_radius = radius * 0.8
	column.height = 3.2
	var material := Telegraphs.material(Color(1.0, 0.6, 0.15, 0.75))
	material.emission_enabled = true
	material.emission = FIRE_COLOR
	material.emission_energy_multiplier = 3.0
	column.material = material
	pillar.mesh = column
	pillar.position.y = 1.6
	add_child(pillar)
	var tween := pillar.create_tween()
	tween.tween_property(pillar, "scale", Vector3(1.2, 1.0, 1.2), 0.15)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(pillar.queue_free)
	if player.active and _inside():
		player.receive_attack(damage, at, "zone", null)


func _inside() -> bool:
	var flat := player.global_position - global_position
	flat.y = 0.0
	return flat.length() <= radius + 0.15
