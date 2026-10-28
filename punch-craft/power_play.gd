class_name PowerPlay
extends Node
## The Endless powers' state in a fight: Gale charges, Iron plates, Quake's
## landings and stomps, Unbreakable's recharge. The player calls in at a
## few moments (a punch thrown or landed, a dodge, a hit taken, a landing);
## Doom's marks live on the monsters (Enemy.doom). Effects come from the
## selected powers (GameState.get_effect).

## Gale: charges held at most (Deep Lungs adds).
const GALE_MAX := 3
## Iron: plates at most (Plating adds), and landed punches per plate (Forge cuts).
const IRON_MAX := 3
const FORGE_EVERY := 5
const UNBREAKABLE_COOLDOWN := 60.0
const STAGGER := 0.6
const SHRAPNEL_RADIUS := 2.5
## Quake: the landing shockwave's reach and recharge; a Drumbeat stomp's own.
const QUAKE_RADIUS := 3.0
const QUAKE_COOLDOWN := 4.0
const STOMP_COOLDOWN := 1.0
const QUAKE_MIN_AIR := 0.3
## Seconds before a punch can set a power off again, on top of its chance (so
## they land as moments, not a constant fizz). The Catalyst's cards set them
## off regardless.
const COOLDOWNS := {"sigil_fire": 1.5, "sigil_frost": 3.0, "sigil_storm": 1.5, "sigil_blood": 2.0, "sigil_doom": 4.0}
## The power each one's effect switches on.
const COOLDOWN_EFFECTS := {"sigil_fire": "fire_punch", "sigil_frost": "frost_punch", "sigil_storm": "chain_lightning",
	"sigil_blood": "counter_heal", "sigil_doom": "doom"}

var player: Player
var gale := 0
var plates := 0
var _forged := 0
var _unbreakable := 0.0
var _quake_cooldown := 0.0
var _stomp_cooldown := 0.0
var _cache := {}
var _cooldown := {}


func _ready() -> void:
	GameState.changed.connect(_forget)


func _forget() -> void:
	_cache.clear()


func fx(key: String) -> float:
	if not _cache.has(key):
		_cache[key] = GameState.get_effect(key)
	return _cache[key]


func tick(delta: float) -> void:
	for root in _cooldown:
		_cooldown[root] -= delta
	_unbreakable -= delta
	_quake_cooldown -= delta
	_stomp_cooldown -= delta


## For the HUD's power chip: [power root, readout] per running power with
## something to count.
func status() -> Array:
	var out := []
	for root in COOLDOWNS:
		if fx(COOLDOWN_EFFECTS[root]) > 0.0:
			var left: float = _cooldown.get(root, 0.0)
			out.append([root, "READY" if left <= 0.0 else "%ds" % ceili(left)])
	if fx("quake_power") > 0.0:
		out.append(["sigil_quake", "READY" if _quake_cooldown <= 0.0 else "%ds" % ceili(_quake_cooldown)])
	if fx("gale") > 0.0:
		out.append(["sigil_gale", "%d/%d" % [gale, gale_max()]])
	if fx("plate_guard") > 0.0:
		out.append(["sigil_iron", "%d/%d" % [plates, plates_max()]])
	return out


## Off cooldown (a power without one always is).
func ready(root: String) -> bool:
	return _cooldown.get(root, 0.0) <= 0.0


## It went off: starts its cooldown.
func spend(root: String) -> void:
	_cooldown[root] = COOLDOWNS.get(root, 0.0)


# --- Gale -----------------------------------------------------------------------

func gale_max() -> int:
	return GALE_MAX + int(fx("gale_charges"))


## A dodge charges Gale (a clean one twice; Tailwind one more) and, clean
## (or any, with Anvil), forges an Iron plate.
func on_dodge(clean: bool) -> void:
	if fx("gale") > 0.0:
		var gain := (2 if clean else 1) + (1 if fx("gale_tailwind") > 0.0 else 0)
		gale = mini(gale + gain, gale_max())
	if fx("plate_guard") > 0.0 and (clean or fx("iron_anvil") > 0.0):
		forge_plate()


## Every punch thrown with a charge spends it on an air burst, straight
## ahead from that fist. The last one, with Cyclone, blows everything back.
func on_punch_thrown(type: String, hand: String, punch_damage: float) -> void:
	if gale <= 0 or fx("gale") <= 0.0:
		return
	gale -= 1
	var camera: Camera3D = player._camera
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var side := camera.global_basis.x * (0.25 if hand == "right" else -0.25)
	var from := camera.global_position + forward * 0.6 + side + Vector3(0, -0.25, 0)
	Powers.air_burst(player, from, forward, punch_damage * (fx("gale") + fx("gale_damage")), type)
	if gale == 0 and fx("cyclone") > 0.0:
		Powers.cyclone(player)


# --- Iron -----------------------------------------------------------------------

func plates_max() -> int:
	return IRON_MAX + int(fx("iron_plates"))


func forge_plate() -> void:
	if plates >= plates_max():
		return
	plates += 1
	Sfx.play("block", -8.0, 1.5)
	HitFx.burst(player.get_parent(), player.global_position + Vector3(0, 1.0, 0), Vector3.UP, Fists.POWER_COLORS.sigil_iron, 10, 2.0, true, 0.04)
	Powers.went_off("sigil_iron", null)


## A hit lands: each plate cuts the damage, then it breaks one (a boss's
## hit two, one with Riveted). Spikes stagger the attacker, Barbs hit it
## back, Shrapnel hits everything around. Unbreakable: with every plate up,
## a knockout blow leaves 1 knuckle HP (once a minute).
func hit_amount(amount: float, attacker: Enemy) -> float:
	if plates <= 0 or fx("plate_guard") <= 0.0:
		return amount
	var full := plates >= plates_max()
	amount *= maxf(0.0, 1.0 - plates * fx("plate_guard"))
	var boss := attacker != null and attacker.is_boss
	var broken := mini(plates, 2 if boss and fx("riveted") <= 0.0 else 1)
	plates -= broken
	var world := player.get_parent()
	var at := player.global_position + Vector3(0, 1.2, 0)
	HitFx.burst(world, at, Vector3.UP, Fists.POWER_COLORS.sigil_iron, 18 * broken, 4.0, true, 0.06)
	Sfx.play("block", -2.0, 0.7)
	var barbs := GameState.get_damage() * fx("iron_barbs") * broken
	if attacker and is_instance_valid(attacker) and not attacker.is_dead():
		if fx("iron_spikes") > 0.0:
			attacker.stun(STAGGER)
		if barbs > 0.0:
			attacker.take_hit(barbs, attacker.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "BARBS")
	if fx("shrapnel") > 0.0:
		for node in player.get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and enemy != attacker and not enemy.is_dead() and enemy.global_position.distance_to(player.global_position) <= SHRAPNEL_RADIUS:
				enemy.take_hit(maxf(barbs, GameState.get_damage() * 0.5), enemy.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "SHRAPNEL")
	if full and fx("unbreakable") > 0.0 and _unbreakable <= 0.0 and amount >= player.knuckles:
		amount = maxf(0.0, player.knuckles - 1.0)
		_unbreakable = UNBREAKABLE_COOLDOWN
		player.class_event.emit("UNBREAKABLE")
	return amount


# --- Landed punches: Iron's forge, Quake's Drumbeat -----------------------------

func on_landed() -> void:
	if fx("plate_guard") > 0.0:
		_forged += 1
		if _forged >= maxi(1, FORGE_EVERY - int(fx("iron_forge"))):
			_forged = 0
			forge_plate()
	if fx("quake_power") > 0.0 and _stomp_cooldown <= 0.0 and randf() < fx("quake_chance"):
		_stomp_cooldown = STOMP_COOLDOWN
		stomp()


# --- Quake ----------------------------------------------------------------------

## Landed from a jump (in the air at least QUAKE_MIN_AIR): the shockwave, if
## it's back. True while Quake runs (Quaking boots then only add reach).
func on_land(air_time: float) -> bool:
	if fx("quake_power") <= 0.0:
		return false
	if air_time >= QUAKE_MIN_AIR and _quake_cooldown <= 0.0:
		_quake_cooldown = maxf(1.0, QUAKE_COOLDOWN - fx("quake_cooldown"))
		stomp()
	return true


func stomp() -> void:
	var radius := QUAKE_RADIUS + fx("quake_radius") + (1.0 if fx("ground_pound") > 0.0 else 0.0)
	Powers.ground_pound(player, GameState.get_damage() * (fx("quake_power") + fx("quake_damage")), radius, true)
	player.shake(0.09)
