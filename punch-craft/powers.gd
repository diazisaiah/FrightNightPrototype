class_name Powers
## Sigil powers bought in the upgrade web (Fire Fists, Chain Lightning, Frost
## Fists; Blood is just healing; the Endless powers' Quake shockwave, Gale air
## bursts and Doom marks; Iron lives in PowerPlay) plus Ground Pound from
## Crypt boots, and the upgrades that change them.
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
const QUAKE_COLOR := Color(0.82, 0.6, 0.42)
## Fault Line: the crack runs this far ahead, this wide.
const FAULT_REACH := 6.0
const FAULT_WIDTH := 1.3
## Aftershock: cracked ground slows what stands in it.
const AFTERSHOCK_TIME := 3.0
const AFTERSHOCK_SLOW := 0.4
const GALE_COLOR := Color(0.6, 1.0, 0.8)
const CYCLONE_RADIUS := 3.5
const DOOM_COLOR := Color(0.36, 0.1, 0.55)
const DOOM_TIME := 3.0
## Dead Weight: how much less a marked monster deals, by level (2026-10-29: it
## slowed them with a chill, which froze bosses white).
const DEAD_WEIGHT := [0.25, 0.3, 0.35]
## Reaper and Pall look this far for the next monster to mark.
const DOOM_REACH := 6.0

## Hears every power go off: (root, target) (CardPlay, for the Catalyst's cards).
static var listener: Callable


static func went_off(root: String, target: Enemy) -> void:
	if listener.is_valid():
		listener.call(root, target)
	_callout(root, target)


## The word over the target when a power goes off (so you know what just
## happened), and a ring at its feet, in the power's color.
const CALLOUTS := {"sigil_fire": "IGNITE!", "sigil_frost": "FREEZE!", "sigil_storm": "CHAIN!", "sigil_blood": "DRAIN!", "sigil_doom": "DOOMED!"}


static func _callout(root: String, target: Enemy) -> void:
	if not CALLOUTS.has(root) or target == null or not is_instance_valid(target) or target.get_parent() == null:
		return
	var color: Color = SkillTreeView.BRANCHES[root].color
	var world := target.get_parent()
	var head := target.global_position + Vector3(0, 2.4 * target._body.scale.y + 0.3, 0)
	DamagePopup.spawn(world, CALLOUTS[root], color.lightened(0.25), 64, head)
	HitFx.ring(world, target.global_position + Vector3(0, 0.15, 0), Color(color, 0.8), 2.2)


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
## With the Quake power (quake): its reach, knockdowns, stuns, Fault Line and
## Aftershock.
static func ground_pound(player: Node3D, damage: float, radius := POUND_RADIUS, quake := false) -> void:
	var world := player.get_parent()
	var center := player.global_position
	var color := QUAKE_COLOR if quake else POUND_COLOR
	for i in 8:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 8.0)
		HitFx.burst(world, center + direction * 0.6 + Vector3(0, 0.1, 0), direction + Vector3.UP * 0.4, color, 6, 6.0, false, 0.08)
	if quake:
		HitFx.ring(world, center + Vector3(0, 0.1, 0), color, radius)
	Sfx.play_at("quake", center)
	var forward := Vector3.ZERO
	if quake and GameState.has_effect("fault_line") and player.has_method("_flat_forward"):
		forward = player._flat_forward()
		for i in 6:
			var at := center + forward * (1.0 + i * FAULT_REACH / 6.0) + Vector3(0, 0.1, 0)
			HitFx.burst(world, at, Vector3.UP, color, 6, 4.0, false, 0.07)
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		var along := offset.dot(forward)
		var in_fault := forward != Vector3.ZERO and along > 0.0 and along <= FAULT_REACH + 1.0 \
				and (offset - forward * along).length() <= FAULT_WIDTH
		if offset.length() > radius and not in_fault:
			continue
		var push := offset.normalized() * POUND_KNOCKBACK
		enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), push, true, "QUAKE")
		if quake and not enemy.is_dead():
			if GameState.has_effect("quake_knockdown") and not enemy.is_boss:
				enemy.knock_down(1.0, push)
			elif GameState.has_effect("quake_stun"):
				enemy.stun(1.0)
	if quake:
		if GameState.has_effect("quake_aftershock"):
			_aftershock(world, center, radius)
		went_off("sigil_quake", null)


## Aftershock (Quake capstone): the ground stays cracked; anything in it is slowed.
static func _aftershock(world: Node, center: Vector3, radius: float) -> void:
	var zone := Node3D.new()
	world.add_child(zone)
	zone.global_position = center
	var tween := zone.create_tween()
	for i in roundi(AFTERSHOCK_TIME / 0.25):
		tween.tween_callback(func() -> void:
			var spot := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6)) * radius
			HitFx.burst(world, center + spot + Vector3(0, 0.1, 0), Vector3.UP, QUAKE_COLOR, 3, 1.5, false, 0.06)
			for node in zone.get_tree().get_nodes_in_group("enemies"):
				var enemy := node as Enemy
				if enemy and not enemy.is_dead() and enemy.global_position.distance_to(center) <= radius:
					enemy.chill(0.4, AFTERSHOCK_SLOW, true))
		tween.tween_interval(0.25)
	tween.tween_callback(zone.queue_free)


## Gale: an air burst from the fist, straight ahead (a fan of three for a
## Crosswind hook).
static func air_burst(player: Node3D, from: Vector3, forward: Vector3, damage: float, type: String) -> void:
	var angles := [0.0]
	if type == "hook" and GameState.has_effect("crosswind"):
		angles = [-0.3, 0.0, 0.3]
	for angle: float in angles:
		AirBurst.fling(player.get_parent(), from, forward.rotated(Vector3.UP, angle), damage, type == "uppercut")
	went_off("sigil_gale", null)


## Cyclone (Gale capstone): the last charge blows everything nearby back.
static func cyclone(player: Node3D) -> void:
	var world := player.get_parent()
	var center := player.global_position
	HitFx.ring(world, center + Vector3(0, 0.6, 0), GALE_COLOR, CYCLONE_RADIUS)
	HitFx.burst(world, center + Vector3(0, 1.0, 0), Vector3.UP, GALE_COLOR, 30, 6.0, true, 0.06)
	Sfx.play_at("whoosh", center, 2.0, 0.7)
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length() <= CYCLONE_RADIUS:
			enemy.take_hit(GameState.get_damage() * 0.5, enemy.global_position + Vector3(0, 1.0, 0), offset.normalized() * 9.0, true, "CYCLONE")


## How much less a marked monster deals (Dead Weight; 0 without it).
static func dead_weight() -> float:
	var level := roundi(GameState.get_effect("dead_weight"))
	return DEAD_WEIGHT[clampi(level, 1, DEAD_WEIGHT.size()) - 1] if level > 0 else 0.0


## Doom: marks a monster (Enemy.doom); Pall marks the nearest other too.
static func doom_mark(target: Enemy, spread := true) -> void:
	if target == null or target.is_dead():
		return
	# Marked already: it goes off now, then the new mark starts fresh (it used
	# to just reset the timer, so steady hitting never let it go off).
	if target.is_doomed():
		target.detonate_doom()
		if target.is_dead():
			return
	var seconds := DOOM_TIME + GameState.get_effect("doom_time")
	target.doom(seconds)
	if spread and GameState.has_effect("pall"):
		var next := _nearest(target, target.global_position, DOOM_REACH, [target] as Array[Enemy])
		if next:
			next.doom(seconds)
	went_off("sigil_doom", target)


## The mark runs out: a share of what the monster took while marked
## (stored) hits it again. Reckoning staggers it (bosses too); Reaper passes
## the mark on if this knocks it out.
static func doom_burst(target: Enemy, stored: float) -> void:
	var damage := stored * GameState.get_effect("doom")
	if damage <= 0.0 or target.is_dead():
		return
	var world := target.get_parent()
	var center := target.global_position + Vector3(0, 1.3, 0)
	HitFx.burst(world, center, Vector3.UP, DOOM_COLOR, 34, 5.0, true, 0.08)
	HitFx.ring(world, center, DOOM_COLOR, 1.4)
	_flash(world, center, DOOM_COLOR, 5.0)
	Sfx.play_at("heavy", center, 0.0, 0.6)
	var reckoning := GameState.has_effect("reckoning")
	if reckoning and target.is_boss:
		target._poise_time = 0.0
	target.take_hit(damage, center, Vector3.ZERO, reckoning, "DOOM", true)
	if target.is_dead() and GameState.has_effect("reaper"):
		var next := _nearest(target, target.global_position, DOOM_REACH, [target] as Array[Enemy])
		if next:
			_bolt(world, center, next.global_position + Vector3(0, 1.3, 0))
			doom_mark(next, false)


## Blood: red drops pulled out of the target into you, a red pulse when they
## land.
static func blood_drain(target: Enemy, player: Node3D) -> void:
	var world := target.get_parent()
	var from := target.global_position + Vector3(0, 1.2, 0)
	HitFx.burst(world, from, Vector3.UP, BLOOD_COLOR, 18, 3.0, true, 0.06)
	for i in 10:
		var drop := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * randf_range(0.06, 0.11)
		mesh.material = Enemy._glow_material(BLOOD_COLOR)
		drop.mesh = mesh
		world.add_child(drop)
		drop.global_position = from + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
		var lift := Vector3(randf_range(-0.6, 0.6), randf_range(0.4, 1.0), randf_range(-0.6, 0.6))
		var start := drop.global_position
		var drinker: WeakRef = weakref(player)
		var end := player.global_position + Vector3(0, 1.2, 0)
		var tween := drop.create_tween()
		tween.tween_interval(i * 0.025)
		tween.tween_method(func(t: float) -> void:
			var who := drinker.get_ref() as Node3D
			if who:
				end = who.global_position + Vector3(0, 1.2, 0)
			drop.global_position = start.lerp(end, t) + lift * sin(t * PI), 0.0, 1.0, 0.38)
		tween.tween_callback(drop.queue_free)
	var pulse := player.create_tween()
	pulse.tween_interval(0.45)
	pulse.tween_callback(func() -> void:
		HitFx.ring(player.get_parent(), player.global_position + Vector3(0, 0.15, 0), Color(BLOOD_COLOR, 0.8), 1.8)
		HitFx.burst(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), Vector3.UP, BLOOD_COLOR, 14, 2.5, true, 0.05))


const BLOOD_COLOR := Color(0.85, 0.05, 0.1)


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
