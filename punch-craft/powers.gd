class_name Powers
## Sigil powers bought in the upgrade web (Fire Fists, Chain Lightning, Frost
## Fists; Blood is just healing) plus Ground Pound from Crypt boots, and the
## upgrades that change them.
## The player decides when they trigger; this does the damage and the effects.
## Power damage costs no knuckle HP.

const FIRE_RADIUS := 2.5
const FIRE_COLOR := Color(1.0, 0.5, 0.1)
const CHAIN_RANGE := 6.0
const PYRE_RADIUS := 3.0
const CHAIN_DAMAGE := 0.4
## Each jump hits this much as hard as the one before.
const CHAIN_FALLOFF := 0.75
const CHAIN_COLOR := Color(0.55, 0.85, 1.0)
const POUND_RADIUS := 3.5
const POUND_KNOCKBACK := 7.0
const POUND_COLOR := Color(0.75, 0.68, 0.55)
const BURN_TIME := 3.0
const FROST_RADIUS := 2.5
const FROST_TIME := 2.0
const MAX_FROST_SLOW := 0.85

## Hears every power go off: (root, target) (CardPlay, for the Catalyst's cards).
static var listener: Callable


static func went_off(root: String, target: Enemy) -> void:
	if listener.is_valid():
		listener.call(root, target)


## Flames burst from the punched enemy and burn everyone else nearby.
static func fire_burst(target: Enemy, damage: float) -> void:
	var world := target.get_parent()
	var center := target.global_position + Vector3(0, 1.1, 0)
	HitFx.burst(world, center, Vector3.UP, FIRE_COLOR, 36, 5.0, true, 0.09)
	HitFx.burst(world, center, Vector3.UP, Color(1.0, 0.85, 0.3), 18, 3.0, true, 0.05)
	_flash(world, center, FIRE_COLOR, 6.0)
	Sfx.play_at("fire", center)
	var radius := FIRE_RADIUS + GameState.get_effect("fire_radius")
	# Scorch: everything the fire touches (the target too) keeps burning.
	var burn_per_second := GameState.get_damage() * GameState.get_effect("burn")
	var burn_time := BURN_TIME + GameState.get_effect("burn_time")
	if burn_per_second > 0.0:
		target.ignite(burn_per_second, burn_time)
	for enemy in _enemies_near(target, target.global_position, radius):
		var push := (enemy.global_position - target.global_position).normalized() * 3.0
		_hit(enemy, damage, push, false, "BURN")
		if burn_per_second > 0.0 and not enemy.is_dead():
			enemy.ignite(burn_per_second, burn_time)
		HitFx.burst(world, enemy.global_position + Vector3(0, 1.0, 0), Vector3.UP, FIRE_COLOR, 12, 2.5, true, 0.07)
	went_off("sigil_fire", target)


## Frost Fists: the target and everything near it are frozen (slowed).
## slow: how much (the Frost upgrades' own by default).
static func frost_burst(target: Enemy, slow := -1.0) -> void:
	var world := target.get_parent()
	var center := target.global_position + Vector3(0, 1.1, 0)
	HitFx.burst(world, center, Vector3.UP, Enemy.FROST_COLOR, 30, 4.0, true, 0.06)
	HitFx.burst(world, center, Vector3.UP, Color(0.9, 0.97, 1.0), 14, 2.0, true, 0.04)
	_flash(world, center, Enemy.FROST_COLOR, 4.0)
	Sfx.play_at("zap", center, -4.0, 0.55)
	slow = minf(GameState.get_effect("frost_punch") if slow < 0.0 else slow, MAX_FROST_SLOW)
	var duration := FROST_TIME + GameState.get_effect("frost_time")
	var radius := FROST_RADIUS + GameState.get_effect("frost_radius")
	target.chill(duration, slow)
	for enemy in _enemies_near(target, target.global_position, radius):
		enemy.chill(duration, slow)
	went_off("sigil_frost", target)


## Lightning jumps from the punched enemy to the nearest others, one after another.
static func chain_lightning(target: Enemy, damage: float, jumps: int) -> void:
	var world := target.get_parent()
	var from := target.global_position + Vector3(0, 1.3, 0)
	var hit: Array[Enemy] = [target]
	var jump_damage := damage * (CHAIN_DAMAGE + GameState.get_effect("chain_damage"))
	var stuns := GameState.has_effect("chain_stun")
	Sfx.play_at("zap", from)
	for i in jumps:
		var next := _nearest(target, from, CHAIN_RANGE, hit)
		if next == null:
			break
		var to := next.global_position + Vector3(0, 1.3, 0)
		_bolt(world, from, to)
		_hit(next, jump_damage, Vector3.ZERO, stuns, "ZAP")
		HitFx.burst(world, to, Vector3.UP, CHAIN_COLOR, 10, 3.0, true, 0.04)
		hit.append(next)
		from = to
		jump_damage *= CHAIN_FALLOFF
	went_off("sigil_storm", target)


## Landing shockwave around the player: damages, staggers and knocks back.
static func ground_pound(player: Node3D, damage: float) -> void:
	var world := player.get_parent()
	var center := player.global_position
	for i in 8:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		HitFx.burst(world, center + direction * 0.6 + Vector3(0, 0.1, 0), direction + Vector3.UP * 0.4, POUND_COLOR, 6, 6.0, false, 0.08)
	Sfx.play_at("quake", center)
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length() > POUND_RADIUS:
			continue
		enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), offset.normalized() * POUND_KNOCKBACK, true, "QUAKE")


## A power's hit. Overflow (the Catalyst's card): what's left over after a
## knockout spills onto the nearest monster.
static func _hit(enemy: Enemy, damage: float, push: Vector3, stagger: bool, caption: String) -> void:
	var before := enemy.hp
	var dealt := enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), push, stagger, caption)
	var overflow := GameState.get_effect("overflow")
	if overflow <= 0.0 or not enemy.is_dead() or dealt <= before:
		return
	var next := _nearest(enemy, enemy.global_position, 4.0, [enemy] as Array[Enemy])
	if next:
		_bolt(enemy.get_parent(), enemy.global_position + Vector3(0, 1.2, 0), next.global_position + Vector3(0, 1.2, 0))
		next.take_hit((dealt - before) * overflow, next.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false, "OVERFLOW")


static func _enemies_near(target: Enemy, center: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node in target.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and enemy != target and not enemy.is_dead() and enemy.global_position.distance_to(center) <= radius:
			result.append(enemy)
	return result


static func _nearest(origin: Enemy, from: Vector3, radius: float, exclude: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_distance := radius
	for node in origin.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or enemy in exclude:
			continue
		var distance := enemy.global_position.distance_to(from)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## A jagged glowing bolt between two points that fades out quickly.
static func _bolt(world: Node, from: Vector3, to: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CHAIN_COLOR
	material.emission_enabled = true
	material.emission = CHAIN_COLOR
	material.emission_energy_multiplier = 6.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bolt := Node3D.new()
	world.add_child(bolt)
	var points: Array[Vector3] = [from]
	var segments := 6
	for i in range(1, segments):
		var jitter := Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		points.append(from.lerp(to, float(i) / segments) + jitter)
	points.append(to)
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.05, a.distance_to(b))
		mesh.material = material
		segment.mesh = mesh
		bolt.add_child(segment)
		segment.global_position = (a + b) / 2.0
		if not a.is_equal_approx(b):
			segment.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	_flash(world, (from + to) / 2.0, CHAIN_COLOR, 3.0)
	var tween := bolt.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(bolt.queue_free)


## A short burst of light.
static func _flash(world: Node, at: Vector3, color: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = 6.0
	world.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)


## Pyre (Fire capstone): a burning enemy explodes as it dies, hurting and
## igniting everything within PYRE_RADIUS.
static func pyre(source: Enemy) -> void:
	var world := source.get_parent()
	var center := source.global_position + Vector3(0, 1.0, 0)
	HitFx.burst(world, center, Vector3.UP, FIRE_COLOR, 34, 6.0, true, 0.06)
	HitFx.ring(world, center, FIRE_COLOR, PYRE_RADIUS)
	Sfx.play_at("fire", center, 2.0, 0.8)
	var damage := GameState.get_damage() * 1.5
	for node in source.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == source or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(source.global_position) <= PYRE_RADIUS:
			enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, false, "PYRE")
			enemy.ignite(GameState.get_damage() * 0.5, 3.0)
