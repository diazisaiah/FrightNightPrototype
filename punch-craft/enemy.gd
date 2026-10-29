class_name Enemy
extends CharacterBody3D
## Base for everything that fights back. Handles HP, armor, knockback, stagger,
## hit flash and death. Subclasses build their body in _build_body(), add armor
## pieces in _build_armor(), and choose a movement velocity each frame in _think().

signal died(enemy: Enemy)

const FLASH_TIME := 0.08
const STAGGER_TIME := 0.5
## No stun-locks, from anything (2026-10-28): every hold on a monster (punch
## staggers, stuns, knockdowns, delays and scares) counts as control. A
## monster is held at most CONTROL_MAX at a stretch (punch staggers alone at
## most STAGGER_CHAIN_MAX), and once it's free it shrugs off all control for
## as long as it was just held (at least CONTROL_GRACE_MIN): so it's never
## held more than half the time, whatever the fighter, power or card. Hits
## still land. Ultimates force through (they're rare). Bosses have their
## poise instead.
const CONTROL_MAX := 2.0
const STAGGER_CHAIN_MAX := 1.0
const CONTROL_GRACE_MIN := 1.0
## Boss poise: after a stagger or stun ends, a boss shrugs off the next ones
## for this long (hits still land). Without it the Mauler's hooks, which need
## no set-up and all stagger, kept a boss from ever attacking.
const BOSS_POISE := 3.0
const KNOCKBACK_DECAY := 12.0
const TURN_SPEED := 8.0
const RECOIL_DISTANCE := 0.18
const RECOIL_RECOVERY := 1.2
const SPARK_COLOR := Color(1.0, 0.7, 0.3)
const HEAD_MULTIPLIER := 1.3
const HEAD_COLOR := Color(1.0, 0.85, 0.2)
const BODY_COLOR := Color(0.65, 0.85, 1.0)
## Elite enemies (Crypt): tougher, richer, with a trait and a glowing aura.
const ELITE_HP := 2.0
const ELITE_REWARD := 3
const ELITE_COLOR := Color(1.0, 0.6, 0.15)
const ELITE_TRAITS := ["Swift", "Brutal", "Ironclad", "Hulking"]
## Champions (the Arena, Plague Division and up): an elite with two traits,
## much more health and a violet aura.
const CHAMPION_HP := 3.5
const CHAMPION_REWARD := 6
const CHAMPION_COLOR := Color(0.75, 0.3, 1.0)
## Ironclad elites: flat armor plus a share of every hit shrugged off, so they
## stay tough however hard the player hits.
const IRONCLAD_ARMOR := 5.0
const IRONCLAD_REDUCTION := 0.35
## Status effects from Crypt items.
const FROST_COLOR := Color(0.55, 0.85, 1.0)
const POISON_COLOR := Color(0.45, 0.9, 0.25)
const BLEED_COLOR := Color(0.85, 0.08, 0.08)
const MAX_POISON_STACKS := 5
const POISON_TIME := 4.0
const MAX_BLEED_STACKS := 5
const BLEED_TIME := 6.0
## Walking into something for this long makes an enemy step around it.
const STUCK_TIME := 0.25
const DETOUR_TIME := 1.0
## Each body shot adds this much "body damage" (0-1), which fades over time
## and slows everything the enemy does, up to MAX_BODY_SLOW.
const BODY_DAMAGE_PER_HIT := 0.2
const BODY_DAMAGE_DECAY := 0.15
const MAX_BODY_SLOW := 0.35
const WINDED_THRESHOLD := 0.6
## Every attack flashes this long before it lands: the cue to dodge.
const TELL_FLASH_TIME := 0.22
## Read the Tell (a Technique perk): tells flash this much sooner.
const READ_TELL := 0.08
## Heavy Hands (a Power perk): staggers last this much longer.
const HEAVY_HANDS := 1.3
## Time slowed for every monster (cards: The Last Word, Fifty Before They
## Blink): they run at this pace until slow_until (msec).
const TIME_SLOW := 0.4
static var slow_until := 0
const HEAL_COLOR := Color(0.35, 1.0, 0.45)
## Attack turns: only a few melee enemies may attack the player at once; the
## rest hang back at WAIT_DISTANCE, circling, until one finishes its combo
## and steps out (resting TURN_REST seconds before it may go again).
## Punching an enemy pulls it into the fight (it takes a turn from another).
## Bosses and ranged enemies don't take turns.
const WAIT_DISTANCE := 3.8
const TURN_REST := Vector2(1.2, 2.4)
## Seconds a turn lasts if the enemy never gets to attack (stuck, chased off).
const TURN_TIMEOUT := 4.0

@export var display_name := "Enemy"
## Color of the chips that fly off when punched.
@export var hit_color := Color(0.3, 0.45, 0.2)
## Punches landing above this height (meters from the feet) are head shots.
@export var head_height := 1.55
## Bosses take a big chunk from a Counter Master's perfect counter instead of a KO.
@export var is_boss := false
@export var max_hp := 20.0
@export var move_speed := 2.5
@export var coin_reward := 3
@export var xp_reward := 4
## Flat damage blocked from every punch, armored or not.
@export var base_armor := 0.0
@export_group("Armored variant")
## Flat damage blocked from every punch when armored.
@export var armor_value := 4.0
@export var armor_bonus_hp := 20.0

var hp := 0.0
var armor := 0.0
## Extra flat block on head shots (a helmet, see EnemyGear).
var head_armor := 0.0
var armored := false
## {tier, pieces} from EnemyGear, or empty.
var gear := {}
## Tony's Big Mouth: enraged, it comes only for him (ignoring the take-turns
## rule), deals TAUNT_DEALT x damage and takes TAUNT_TAKEN x from his punches.
const TAUNT_DEALT := 1.5
const TAUNT_TAKEN := 2.0
var _taunt_time := 0.0
var _taunt_fx: Node3D
## The hat this enemy wears (Hats.CATALOG id), or "".
var hat := ""
## The first hatted monster you meet (Tutorial "hat_first"): the game freezes
## on its hat, and it can only be finished by an uppercut (so the hat comes off).
var hat_lesson := false
var _lesson_check := 0.0
var _lesson_label: Label3D
var _hat_node: Node3D
var player: Player
## Multiplies the damage this enemy's attacks deal. Grows with the wave.
var damage_multiplier := 1.0
## The space this enemy fights in (the graveyard, or a Crypt room): enemies
## that keep their distance stay within arena_limit of arena_center.
## Share of damage ignored after armor (0-1), e.g. Ironclad elites.
var damage_reduction := 0.0
var arena_center := Vector3.ZERO
var arena_limit := 38.0

var _body: Node3D
var _hp_label: Label3D
var _meshes: Array[MeshInstance3D] = []
var _knockback := Vector3.ZERO
var _stagger_timer := 0.0
## How long it's been held this stretch, and the grace left after one (see
## CONTROL_MAX).
var _control_run := 0.0
var _control_grace := 0.0
## Held still without a stagger (delay, scare): no moving, no attacking.
var _hold_time := 0.0
## The pivot the body falls over on (knock_down), and its fall.
var _topple: Node3D
var _topple_tween: Tween
var _squash_tween: Tween
## Stars circling the head while it's stunned.
var _daze_fx: Node3D
## Bosses: staggers and stuns don't take until this runs out (BOSS_POISE).
var _poise_time := 0.0
var _flash_timer := 0.0
var _dead := false
var _recoil := 0.0
var _body_damage := 0.0
var _burn_per_second := 0.0
var _burn_time := 0.0
## Burning and frozen looks (flames off the body; frost on it, ice drifting).
var _burn_fx: Node3D
var _frost_fx: Node3D
var _frost_overlay: StandardMaterial3D
var _burn_tick := 0.0
var _scaling := {}
var _chill_time := 0.0
## Bosses (Arena, Crypt, Dead League) shake off a freeze in half a second
## (2026-10-17): chained Frost kept them slowed through whole fights.
const BOSS_CHILL_TIME := 0.5
var _chill_amount := 0.0
var _poison_stacks := 0
var _poison_per_stack := 0.0
var _poison_time := 0.0
var _poison_tick := 0.0
var _bleed_stacks := 0
var _bleed_per_stack := 0.0
var _bleed_time := 0.0
## Doom (Death Mark): seconds left on the mark, what it took meanwhile, and
## the skull floating over it.
var _doom_time := 0.0
var _doom_store := 0.0
var _doom_fx: Node3D
var _stuck_time := 0.0
## Which way an enemy steps around an obstacle; it keeps going the same way
## round until that's blocked too.
var _detour_side := 1.0
var _detour_time := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## How many melee enemies may attack at once (set by the level: 1 early, 2 later).
static var max_attackers := 1
static var _attackers: Array = []
## False for enemies that fight from range (they never wait their turn).
var takes_turns := true
var _turn_rest := 0.0
## How the killing blow should send the body flying, set by the player just
## before a punch lands: {type, hand, level (0 plain, 1 counter, 2 clean or
## perfect), dir, player}. Empty = no launch (burns, poison...).
var finisher := {}
var _flying := false
var _fly_time := 0.0
var _fly_spin := Vector3.ZERO
var _fly_level := 0
var _fly_trail := 0.0
var _bowled: Array = []
var _turn_age := 0.0

static var _flash_material: StandardMaterial3D


## Call before adding to the tree. scaling holds wave multipliers:
## "hp", "damage", "speed" and "reward" (all default to 1).
func setup(target: Player, is_armored: bool, scaling := {}) -> void:
	player = target
	armored = is_armored
	_scaling = scaling


func _ready() -> void:
	add_to_group("enemies")
	# The body sits on a pivot at the feet, so knock_down can topple it
	# while the monster's own animation keeps posing the body.
	_topple = Node3D.new()
	add_child(_topple)
	_body = Node3D.new()
	_topple.add_child(_body)
	_build_body()
	armor = base_armor
	# Tiered gear for where on the Climb it spawns (EnemyGear). The old
	# "armored" spawns now mean at least a helmet and chest plate.
	var style := _gear_style()
	var on_climb := style != "none" and float(_scaling.get("position", -1.0)) >= 0.0
	# The plumber quest: with the Fat Plumber Cap, now and then one in
	# overalls and a plumber cap of its own (no other gear).
	var plumber: String = _scaling.get("hat", "") if Hats.OVERALLS.has(_scaling.get("hat", "")) else ""
	if on_climb and plumber == "" and not _scaling.has("hat"):
		plumber = Hats.plumber_for(self)
	if style != "none" and plumber == "":
		gear = _scaling.gear if _scaling.has("gear") else EnemyGear.roll(float(_scaling.get("position", -1.0)), armored, is_boss)
	if not gear.is_empty():
		EnemyGear.dress(self, gear, style)
		armored = gear.pieces.has("chest") or gear.pieces.has("helmet")
	# Now and then, a hat (Arena and Crypt only).
	if on_climb:
		hat = plumber if plumber != "" else _scaling.hat if _scaling.has("hat") else Hats.roll(self is Skeleton)
		if plumber != "":
			EnemyGear.overalls(self, Hats.OVERALLS[plumber])
		if hat != "":
			_wear_hat()
	if armored and style != "none" and gear.is_empty():
		armor += armor_value
		max_hp += armor_bonus_hp
		coin_reward *= 2
		xp_reward = roundi(xp_reward * 1.5)
		_build_armor()
	max_hp *= _scaling.get("hp", 1.0)
	move_speed *= _scaling.get("speed", 1.0)
	damage_multiplier = _scaling.get("damage", 1.0)
	coin_reward = roundi(coin_reward * _scaling.get("reward", 1.0))
	xp_reward = roundi(xp_reward * _scaling.get("xp", _scaling.get("reward", 1.0)))
	if not gear.is_empty():
		# Gear blocks a share of the punch you're expected to throw here.
		EnemyGear.apply_stats(self, gear, Progression.BASE_DAMAGE * float(_scaling.get("hp", 1.0)))
	hp = max_hp

	_hp_label = Label3D.new()
	_hp_label.position.y = 2.35
	# Same size on screen at any distance, so it never fills the view up close.
	_hp_label.fixed_size = true
	_hp_label.pixel_size = 0.0012
	_hp_label.font_size = 28
	_hp_label.outline_size = 10
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.visible = false
	add_child(_hp_label)
	# Once subclasses have added their parts too, rebuild them all as voxels.
	_voxelize_parts.call_deferred()


## Swaps each plain part for its voxel version (see Voxel). Parts keep their
## nodes, so animation, hit flashes and the elite glow still work.
func _voxelize_parts() -> void:
	for part in _meshes:
		if not is_instance_valid(part) or part.mesh == null or part.has_meta("base_color"):
			continue
		var material := part.mesh.surface_get_material(0)
		var voxels := Voxel.voxelize(part.mesh, material)
		if voxels == null:
			continue
		part.set_meta("base_color", (material as StandardMaterial3D).albedo_color)
		part.set_meta("base_material", material)
		part.mesh = voxels


func _physics_process(delta: float) -> void:
	if _flying:
		_fly(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var desired := Vector3.ZERO
	var pace := 1.0
	if not _dead:
		_check_hat_lesson(delta)
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_set_flash(false)
		_track_control(delta)
		_stagger_timer -= delta
		_hold_time -= delta
		if _daze_fx:
			_daze_fx.rotation.y += delta * 6.0
			if _stagger_timer <= 0.0:
				_daze_fx.queue_free()
				_daze_fx = null
		_poise_time -= delta
		if _taunt_time > 0.0:
			_taunt_time -= delta
			if _taunt_time <= 0.0:
				_end_taunt()
		# Body damage slows everything: movement, windups, cooldowns.
		_body_damage = maxf(0.0, _body_damage - BODY_DAMAGE_DECAY * delta)
		pace = 1.0 - MAX_BODY_SLOW * _body_damage
		if _chill_time > 0.0:
			_chill_time -= delta
			pace *= 1.0 - _chill_amount
			if _chill_time <= 0.0:
				_set_frozen_look(false)
		if Time.get_ticks_msec() < slow_until:
			pace *= TIME_SLOW
		_update_statuses(delta)
		_turn_rest -= delta
		if _attackers.has(self):
			_turn_age += delta
			if _turn_age > TURN_TIMEOUT:
				end_turn()
		if _stagger_timer <= 0.0 and _hold_time <= 0.0 and is_instance_valid(player) and player.active:
			desired = _steer(_think(delta * pace) * pace, delta)

	if _burn_time > 0.0 and not _dead:
		_update_burn(delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	velocity.x = desired.x + _knockback.x
	velocity.z = desired.z + _knockback.z
	move_and_slide()
	_check_stuck(desired, delta)
	# Body snaps back on a hit, then eases forward again.
	_recoil = move_toward(_recoil, 0.0, RECOIL_RECOVERY * delta)
	_body.position.z = _recoil
	if not _dead:
		_animate(delta * pace, Vector2(desired.x, desired.z).length())


## Applies a punch and returns the damage dealt after armor. stagger cancels
## the enemy's current attack; caption (e.g. "COUNTER!") shows above the number.
## pierce ignores armor (weak spots).
## crush also ignores damage reduction (Bone Breaker).
func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	if _dead:
		return 0.0
	var head_shot := hit_zone(hit_point) == "head"
	# Brittle (Frost): frozen enemies take more from everything.
	if _chill_time > 0.0:
		raw_damage *= 1.0 + GameState.get_effect("brittle")
	if head_shot:
		raw_damage *= HEAD_MULTIPLIER + GameState.get_effect("head_bonus")
	# Wise Up: an enraged monster bleeds easier (Tony's punches only).
	if is_taunted() and not finisher.is_empty():
		raw_damage *= TAUNT_TAKEN
	var worn := armor + (head_armor if head_shot else 0.0)
	var effective_armor := 0.0 if pierce or crush else worn * (1.0 - GameState.get_armor_pierce())
	var damage := maxf(0.0, raw_damage - effective_armor) * (1.0 - (0.0 if crush else damage_reduction))
	if not head_shot and damage > 0.0:
		var was_winded := _body_damage >= WINDED_THRESHOLD
		_body_damage = minf(1.0, _body_damage + BODY_DAMAGE_PER_HIT)
		if not was_winded and _body_damage >= WINDED_THRESHOLD:
			DamagePopup.spawn(get_parent(), "WINDED", BODY_COLOR, 44, global_position + Vector3(0, 1.2, 0))
	hp -= damage
	if _doom_time > 0.0 and caption != "DOOM":
		_doom_store += damage
	_knockback = push
	_recoil = RECOIL_DISTANCE * (2.0 if stagger else 1.0)
	_set_flash(true)
	if stagger and not _can_stagger():
		stagger = false
	if stagger and not is_boss and (_control_grace > 0.0 or _control_run >= STAGGER_CHAIN_MAX - 0.05):
		stagger = false
	if stagger:
		var hold := STAGGER_TIME * (HEAVY_HANDS if GameState.perk("heavy_hands") else 1.0)
		if not is_boss:
			hold = minf(hold, STAGGER_CHAIN_MAX - _control_run)
		_stagger_timer = maxf(_stagger_timer, hold)
		_set_poise()
		_on_staggered()

	var parent := get_parent()
	var toward_player := -push
	if damage > 0.0:
		var size := 48 + mini(int(damage * 2), 48) + (8 if head_shot else 0)
		var text := "%.1f" % damage if caption == "" else "%s\n%.1f" % [caption, damage]
		var color := (HEAD_COLOR if head_shot else BODY_COLOR) if caption == "" else Color(1, 0.55, 0.15)
		DamagePopup.spawn(parent, text, color, size, hit_point)
		HitFx.burst(parent, hit_point, toward_player + Vector3.UP, hit_color, mini(10 + int(damage), 36), 5.0, false, 0.07)
		# A flash of light at the impact; heavy hits and counters ring out.
		HitFx.flash(parent, hit_point, Color(1.0, 0.8, 0.55, 0.8) if not head_shot else Color(1.0, 0.92, 0.5, 0.85), clampf(0.25 + damage * 0.01, 0.25, 0.55))
		if stagger:
			HitFx.ring(parent, hit_point, Color(1.0, 0.7, 0.35, 0.6) if caption == "" else Color(1.0, 0.55, 0.2, 0.7), 0.7 + minf(damage * 0.01, 0.4))
	else:
		DamagePopup.spawn(parent, "BLOCKED", Color(0.7, 0.7, 0.75), 40, hit_point)
	if armored or (head_shot and head_armor > 0.0):
		var spark: Color = EnemyGear.tier_info(gear).spark if not gear.is_empty() else SPARK_COLOR
		HitFx.burst(parent, hit_point, toward_player + Vector3.UP, spark, 8, 6.0, true, 0.025)

	if hp <= 0.0:
		_die(push)
	else:
		_update_label()
		# Uppercuts knock hats off; rarer hats hold on tighter.
		if hat != "" and finisher.get("type", "") == "uppercut" and randf() < Hats.POP_CHANCE[Hats.info(hat).rarity]:
			_pop_hat()
	return damage


func _clear_doom() -> void:
	_doom_time = 0.0
	if _doom_fx:
		_doom_fx.queue_free()
		_doom_fx = null


func is_dead() -> bool:
	return _dead


## Turns this enemy into an elite with a trait: Swift (faster, shorter
## windups), Brutal (hits much harder), Ironclad (armor plus 35% damage
## reduction), Hulking
## (bigger, much more HP). Call after it's in the tree.
func make_elite(trait_name: String) -> void:
	max_hp *= ELITE_HP
	_apply_trait(trait_name)
	hp = max_hp
	coin_reward *= ELITE_REWARD * _pickpocket()
	xp_reward *= ELITE_REWARD
	display_name = "%s %s" % [trait_name, display_name]
	_special_look(ELITE_COLOR, 1.6)
	_update_label()


## A champion: two different traits and CHAMPION_HP health.
func make_champion(traits: Array) -> void:
	max_hp *= CHAMPION_HP
	for trait_name in traits:
		_apply_trait(trait_name)
	hp = max_hp
	coin_reward *= CHAMPION_REWARD * _pickpocket()
	xp_reward *= CHAMPION_REWARD
	display_name = "Champion %s %s %s" % [traits[0], traits[1], display_name]
	set_meta("champion", true)
	_special_look(CHAMPION_COLOR, 2.4)
	_update_label()


## Pickpocket (a Fortune perk): elites and champions pay triple.
static func _pickpocket() -> int:
	return 3 if GameState.perk("pickpocket") else 1


func _apply_trait(trait_name: String) -> void:
	match trait_name:
		"Swift":
			move_speed *= 1.35
			if "windup_scale" in self:
				set("windup_scale", get("windup_scale") * 0.85)
		"Brutal":
			damage_multiplier *= 1.5
		"Ironclad":
			armor += IRONCLAD_ARMOR
			damage_reduction = IRONCLAD_REDUCTION
		"Hulking":
			max_hp *= 1.5
			_body.scale *= 1.2


## The glowing aura and tint of an elite or champion.
func _special_look(color: Color, energy: float) -> void:
	var aura := OmniLight3D.new()
	aura.light_color = color
	aura.light_energy = energy
	aura.omni_range = 3.0
	aura.position.y = 1.2
	add_child(aura)
	for mesh in _meshes:
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(color, 0.12)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_overlay = glow
		mesh.set_meta("elite_overlay", glow)


## Walking into a wall or block: slide sideways around it for a moment.
func _steer(desired: Vector3, delta: float) -> Vector3:
	if _detour_time <= 0.0 or desired.length_squared() < 0.01:
		return desired
	_detour_time -= delta
	var side_step := Vector3(-desired.z, 0, desired.x).normalized() * _detour_side
	return (desired.normalized() * 0.25 + side_step).normalized() * desired.length()


func _check_stuck(desired: Vector3, delta: float) -> void:
	var wanted := Vector2(desired.x, desired.z).length()
	if wanted < 0.5:
		_stuck_time = 0.0
		return
	var moved := Vector2(velocity.x, velocity.z).length()
	_stuck_time = _stuck_time + delta if moved < wanted * 0.35 else 0.0
	if _stuck_time < STUCK_TIME:
		return
	_stuck_time = 0.0
	if _detour_time > 0.0:
		# Blocked going this way round too: try the other side.
		_detour_side = -_detour_side
	_detour_time = DETOUR_TIME


## Slowed for a while (Frost Slip): amount 0-1 of its pace lost.
## How long a freeze holds: bosses shake it off in BOSS_CHILL_TIME.
func chill_length(duration: float) -> float:
	return minf(duration, BOSS_CHILL_TIME) if is_boss else duration


func chill(duration: float, amount: float, quiet := false) -> void:
	if _dead:
		return
	_chill_time = maxf(_chill_time, chill_length(duration))
	_chill_amount = maxf(_chill_amount, amount)
	_set_frozen_look(true)
	if quiet:
		return
	DamagePopup.spawn(get_parent(), "CHILLED", FROST_COLOR, 36, global_position + Vector3(0, 2.0, 0))
	HitFx.burst(get_parent(), global_position + Vector3(0, 1.2, 0), Vector3.UP, FROST_COLOR, 10, 2.0, true, 0.05)


## Doom marks it: when the mark runs out, a share of what it took meanwhile
## hits it again (Powers.doom_burst). Dead Weight slows it while marked.
func doom(seconds: float) -> void:
	if _dead:
		return
	if _doom_time <= 0.0:
		_doom_store = 0.0
		DamagePopup.spawn(get_parent(), "MARKED", Powers.DOOM_COLOR, 38, global_position + Vector3(0, top_height() + 0.3, 0))
	_doom_time = maxf(_doom_time, seconds)
	if GameState.has_effect("dead_weight"):
		chill(seconds, 0.3, true)
	if _doom_fx == null:
		_doom_fx = MoveFx.skull(Powers.DOOM_COLOR)
		_doom_fx.position.y = top_height() + 0.45
		_topple.add_child(_doom_fx)


func is_doomed() -> bool:
	return _doom_time > 0.0


## The mark goes off now (a fresh one from Powers.doom_mark).
func detonate_doom() -> void:
	if _doom_time <= 0.0:
		return
	var stored := _doom_store
	_clear_doom()
	Powers.doom_burst(self, stored)


## Adds a stack of poison (Venom): damage per second per stack, ignoring armor.
func poison(per_stack: float) -> void:
	if _dead:
		return
	_poison_stacks = mini(_poison_stacks + 1, MAX_POISON_STACKS)
	_poison_per_stack = maxf(_poison_per_stack, per_stack)
	_poison_time = POISON_TIME


## Adds a stack of bleeding (Serrated): every attack this enemy throws hurts it.
func bleed(per_stack: float) -> void:
	if _dead:
		return
	_bleed_stacks = mini(_bleed_stacks + 1, MAX_BLEED_STACKS)
	_bleed_per_stack = maxf(_bleed_per_stack, per_stack)
	_bleed_time = BLEED_TIME


## Subclasses call this when they throw an attack: bleeding hurts.
func _on_attacking() -> void:
	if _bleed_stacks <= 0 or _dead:
		return
	_status_damage(_bleed_stacks * _bleed_per_stack, BLEED_COLOR, "BLEED")


func _update_statuses(delta: float) -> void:
	if _doom_time > 0.0:
		_doom_time -= delta
		if _doom_fx:
			_doom_fx.rotation.y += delta * 3.0
		if _doom_time <= 0.0:
			_clear_doom()
			Powers.doom_burst(self, _doom_store)
	if _bleed_stacks > 0:
		_bleed_time -= delta
		if _bleed_time <= 0.0:
			_bleed_stacks = 0
	if _poison_stacks > 0:
		_poison_time -= delta
		_poison_tick += delta
		if _poison_tick >= 0.5:
			_poison_tick = 0.0
			_status_damage(_poison_stacks * _poison_per_stack * 0.5, POISON_COLOR)
		if _poison_time <= 0.0:
			_poison_stacks = 0


## Damage over time and the like: ignores armor, no stagger.
func _status_damage(amount: float, color: Color, caption := "") -> void:
	if _dead or amount <= 0.0:
		return
	hp -= amount
	var chest := global_position + Vector3(0, 1.3, 0)
	var text := "%.1f" % amount if caption == "" else "%s\n%.1f" % [caption, amount]
	DamagePopup.spawn(get_parent(), text, color, 34, chest)
	HitFx.burst(get_parent(), chest, Vector3.UP, color, 6, 1.5, true, 0.05)
	if hp <= 0.0:
		_die(Vector3.ZERO)
	else:
		_update_label()


## Sets the enemy burning: damage every half second for duration, ignoring
## armor. Re-igniting refreshes the burn rather than stacking it.
func ignite(damage_per_second: float, duration: float) -> void:
	if _dead:
		return
	_burn_per_second = maxf(_burn_per_second, damage_per_second)
	_burn_time = maxf(_burn_time, duration)
	if _burn_fx == null:
		_burn_fx = _status_particles(Powers.FIRE_COLOR, Color(1.0, 0.85, 0.3), 3.2, true)


func _update_burn(delta: float) -> void:
	_burn_time -= delta
	_burn_tick += delta
	if _burn_tick < 0.5:
		return
	_burn_tick = 0.0
	var damage := _burn_per_second * 0.5
	hp -= damage
	var chest := global_position + Vector3(0, 1.2, 0)
	DamagePopup.spawn(get_parent(), "%.1f" % damage, Powers.FIRE_COLOR, 36, chest)
	HitFx.burst(get_parent(), chest, Vector3.UP, Powers.FIRE_COLOR, 5, 1.5, true, 0.05)
	if hp <= 0.0:
		_die(Vector3.ZERO)
	else:
		_update_label()
	if _burn_time <= 0.0:
		_burn_per_second = 0.0
		_end_status_fx(_burn_fx)
		_burn_fx = null


## "head" or "body", from how high on the enemy the punch landed.
func hit_zone(hit_point: Vector3) -> String:
	var height := to_local(hit_point).y / maxf(_body.scale.y, 0.01)
	return "head" if height >= head_height else "body"


## Knocked silly (e.g. by a Combo Master shockwave): can't act for a while.
## force: an ultimate's (past the control grace, still within CONTROL_MAX).
func stun(duration: float, force := false) -> void:
	if _dead or not _can_stagger() or not _controllable(force):
		return
	duration = _control_for(duration)
	_stagger_timer = maxf(_stagger_timer, duration)
	_set_poise()
	_on_staggered()
	DamagePopup.spawn(get_parent(), "STUNNED", Color(1, 0.8, 0.3), 40, global_position + Vector3(0, 2.0, 0))
	if duration >= 0.6:
		_daze()


## Stars circling over its head until the stun wears off.
func _daze() -> void:
	if _daze_fx:
		return
	_daze_fx = Node3D.new()
	_daze_fx.position.y = top_height() + 0.2
	# On the toppling pivot, so the stars stay over the head when it's down.
	_topple.add_child(_daze_fx)
	var star := Enemy._glow_material(Color(1.0, 0.88, 0.3))
	for i in 3:
		var a := TAU * i / 3.0
		var bit := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, 0.1, 0.1)
		mesh.material = star
		bit.mesh = mesh
		bit.position = Vector3(cos(a), 0.04 * i, sin(a)) * 0.3
		bit.rotation = Vector3(0.6, a, 0.6)
		_daze_fx.add_child(bit)


## Stomped on: squashed flat for a moment, then it springs back.
func squash() -> void:
	if _dead or _topple == null:
		return
	if _squash_tween:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_topple, "scale", Vector3(1.3, 0.55, 1.3), 0.06).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_topple, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Knocked off its feet: it topples away from the blow, hits the ground with a
## thud and a bounce, lies there, then hops back up. Out of the fight the whole
## time. Bosses are too heavy to fall (a stun, which their poise can refuse).
func knock_down(seconds: float, push: Vector3, force := false) -> void:
	if _dead:
		return
	if is_boss or not _can_stagger():
		stun(minf(seconds, 1.0), force)
		return
	# Recently held: it staggers back from the blow but keeps its feet.
	if not _controllable(force):
		_knockback = Vector3(push.x, 0.0, push.z).normalized() * 4.0
		return
	seconds = _control_for(seconds)
	_stagger_timer = maxf(_stagger_timer, seconds)
	_on_staggered()
	var away := global_basis.inverse() * Vector3(push.x, 0.0, push.z)
	away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
	# +x tips the top toward +z, -z toward +x: over, away from the blow.
	var fall := Vector3(away.z, 0.0, -away.x) * 1.45
	if _topple_tween:
		_topple_tween.kill()
	_topple_tween = create_tween()
	_topple_tween.tween_property(_topple, "rotation", fall * 1.06, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_topple_tween.tween_callback(func() -> void:
		var ground := global_position + global_basis * Vector3(-fall.z, 0.15, fall.x) * 0.7
		HitFx.burst(get_parent(), ground, Vector3.UP, Color(0.45, 0.38, 0.3), 14, 2.5, false, 0.07)
		Sfx.play_at("heavy", ground, -6.0, 0.6))
	_topple_tween.tween_property(_topple, "rotation", fall, 0.12).set_trans(Tween.TRANS_SINE)
	_topple_tween.tween_interval(maxf(seconds - 0.85, 0.15))
	# Back up: a quick hop and straight.
	_topple_tween.tween_property(_topple, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_topple_tween.parallel().tween_property(_topple, "position:y", 0.3, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_topple_tween.tween_property(_topple, "position:y", 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Control (CONTROL_MAX): time held this stretch while staggered or held;
## once free, the grace is as long as the hold was.
func _track_control(delta: float) -> void:
	if is_boss:
		return
	if _stagger_timer > 0.0 or _hold_time > 0.0:
		_control_run += delta
	elif _control_run > 0.0:
		_control_grace = maxf(CONTROL_GRACE_MIN, _control_run)
		_control_run = 0.0
	else:
		_control_grace -= delta


## Can be held right now (bosses: see their poise). force: an ultimate,
## past the grace but not past CONTROL_MAX.
func _controllable(force := false) -> bool:
	if is_boss:
		return true
	if _control_run >= CONTROL_MAX - 0.05:
		return false
	return force or _control_grace <= 0.0


## A hold trimmed to what's left of this stretch's CONTROL_MAX.
func _control_for(seconds: float) -> float:
	return seconds if is_boss else minf(seconds, CONTROL_MAX - _control_run)


## A boss holding its poise shrugs off staggers and stuns ("STEADY", once a
## poise). That includes hits during its stagger: they can't stretch it.
func _can_stagger() -> bool:
	if not is_boss or _poise_time <= 0.0:
		return true
	if not has_meta("steady_shown"):
		set_meta("steady_shown", true)
		DamagePopup.spawn(get_parent(), "STEADY", Color(0.8, 0.8, 0.85), 34, global_position + Vector3(0, 2.4 * _body.scale.y, 0))
	return false


func _set_poise() -> void:
	if is_boss:
		_poise_time = _stagger_timer + BOSS_POISE
		if has_meta("steady_shown"):
			remove_meta("steady_shown")


## Holds it still for a moment (no move, no attack) without a stagger: its
## next attack waits.
func delay(seconds: float, caption := "") -> void:
	if _dead or not _controllable():
		return
	if is_boss:
		if not _can_stagger():
			return
		_poise_time = seconds + BOSS_POISE
	else:
		seconds = _control_for(seconds)
	_hold_time = maxf(_hold_time, seconds)
	if caption != "":
		DamagePopup.spawn(get_parent(), caption, Color(0.6, 0.9, 1.0), 36, global_position + Vector3(0, 2.0 * _body.scale.y, 0))


## Scared off: backs away from where the scare came from and holds.
func scare(seconds: float, from: Vector3) -> void:
	if _dead:
		return
	var away := global_position - from
	away.y = 0.0
	_knockback = away.normalized() * 7.0
	_on_staggered()
	delay(seconds, "SCARED")


## How high its head reaches (the top of its collision shape), for stomps.
func top_height() -> float:
	for child in get_children():
		var shape := child as CollisionShape3D
		if shape and shape.shape is CapsuleShape3D:
			return shape.position.y + (shape.shape as CapsuleShape3D).height / 2.0
		if shape and shape.shape is BoxShape3D:
			return shape.position.y + (shape.shape as BoxShape3D).size.y / 2.0
	return 1.8


func is_staggered() -> bool:
	return _stagger_timer > 0.0 and not _dead


## How squarely it faces a point: 1 straight at it, -1 its back to it.
func facing(at: Vector3) -> float:
	var to := at - global_position
	to.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	if to.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return 1.0
	return forward.normalized().dot(to.normalized())


## Done with its combo: the attack thrown was its last (Closing Statement).
func combo_finished() -> bool:
	return true


## When a fully wound-up attack's tell flashes, before it lands.
static func tell_time() -> float:
	return TELL_FLASH_TIME + (READ_TELL if GameState.perk("read_the_tell") else 0.0)


## Every monster runs slow for a while (not the player).
static func slow_time(seconds: float) -> void:
	slow_until = maxi(slow_until, Time.get_ticks_msec() + roundi(seconds * 1000.0))


## Damage a Counter Master's perfect counter deals: enough to finish anything,
## or a big chunk of a boss.
func get_knockout_damage() -> float:
	if is_boss:
		return max_hp * 0.25 + armor
	return (hp + armor) + 1.0


## Called before a punch lands. Return true to dodge it (no damage).
func try_evade(_punch_type: String, _hand: String) -> bool:
	return false


## True if a punch passes straight through (a Wraith that isn't open).
func phased(_punch_type: String, _counter: bool) -> bool:
	return false


## True if a punch is stopped by a shield (a Shieldbearer's front).
func blocks_punch(_punch_type: String, _counter: bool) -> bool:
	return false


## Damage multiplier for a punch of this type hitting a weak spot (1 = none).
## Weak-spot hits also ignore armor.
func weak_spot_multiplier(_punch_type: String) -> float:
	return 1.0


## Restores HP (a Grave Priest's healing). Returns how much was restored.
func heal(amount: float) -> float:
	if _dead or hp >= max_hp:
		return 0.0
	var restored := minf(amount, max_hp - hp)
	hp += restored
	_update_label()
	var chest := global_position + Vector3(0, 1.2, 0)
	DamagePopup.spawn(get_parent(), "+%d" % ceili(restored), HEAL_COLOR, 44, chest + Vector3(0, 0.6, 0))
	HitFx.burst(get_parent(), chest, Vector3.UP, HEAL_COLOR, 12, 2.5, true, 0.05)
	return restored


## The flash that marks an attack as fully wound up: a burst of light in the
## color of the defense that beats it, plus a sharp "ting".
func _flash_tell(color: Color, height := 1.5) -> void:
	var at := global_position + Vector3.UP * height * _body.scale.y
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 3.5
	add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, tell_time() + 0.1)
	tween.tween_callback(light.queue_free)
	HitFx.burst(get_parent(), at, Vector3.UP, color, 8, 2.0, true, 0.04)
	Sfx.play_at("tell", at, -2.0)


# --- Overridden by subclasses -------------------------------------------------

func _build_body() -> void:
	pass


func _build_armor() -> void:
	pass


## Enraged by Tony for this long: steam, a red glow, and it's coming for him.
func taunt(seconds: float) -> void:
	if _dead:
		return
	# Trash Talk (Tony's card): they stay mad longer.
	_taunt_time = maxf(_taunt_time, seconds + GameState.get_effect("insult_time"))
	DamagePopup.spawn(get_parent(), "ENRAGED!", Color(1.0, 0.25, 0.15), 54, global_position + Vector3(0, 2.4 * _body.scale.y, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 1.6, 2.0, 0.8)
	if _taunt_fx == null:
		_taunt_fx = Node3D.new()
		_taunt_fx.position.y = 2.0 * _body.scale.y
		add_child(_taunt_fx)
		var steam := CPUParticles3D.new()
		steam.amount = 16
		steam.lifetime = 0.8
		steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		steam.emission_sphere_radius = 0.18
		steam.direction = Vector3.UP
		steam.spread = 25.0
		steam.gravity = Vector3(0, 1.5, 0)
		steam.initial_velocity_min = 0.6
		steam.initial_velocity_max = 1.2
		steam.scale_amount_min = 0.6
		steam.scale_amount_max = 1.4
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.3, 0.2, 0.9))
		ramp.set_color(1, Color(1.0, 0.9, 0.9, 0.0))
		steam.color_ramp = ramp
		var puff := BoxMesh.new()
		puff.size = Vector3.ONE * 0.09
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material = material
		steam.mesh = puff
		_taunt_fx.add_child(steam)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.2, 0.1)
		glow.light_energy = 1.6
		glow.omni_range = 2.5
		glow.position.y = -0.8
		_taunt_fx.add_child(glow)


func is_taunted() -> bool:
	return _taunt_time > 0.0 and not _dead


func _end_taunt() -> void:
	_taunt_time = 0.0
	if _taunt_fx:
		_taunt_fx.queue_free()
		_taunt_fx = null


## Puts the hat on the head (on top of any helmet).
func _wear_hat() -> void:
	var head: Dictionary = EnemyGear._body_map(self).get("head", {})
	if head.is_empty():
		hat = ""
		return
	var part: MeshInstance3D = head.part
	var size: Vector3 = (part.mesh as BoxMesh).size
	var lift := size.y * (0.56 if gear.get("pieces", []).has("helmet") else 0.5)
	# Hats run big: they should read across the room, and look silly.
	_hat_node = Hats.build(hat, maxf(size.x, 0.26) * Hats.SIZE * (Hats.FRUIT_SIZE if hat == "fruit_hat" else 1.0))
	_hat_node.transform = part.transform * Transform3D(Basis.IDENTITY, Vector3(0, lift, 0))
	part.get_parent().add_child(_hat_node)
	var spin := _hat_node.get_node_or_null("Spin")
	if spin:
		spin.create_tween().set_loops().tween_property(spin, "rotation:y", TAU, 0.6).from(0.0)
	if Hats.info(hat).rarity == "legendary":
		Hats.sparkles(_hat_node, Hats.color(hat), 0.3)


## The first time a hatted monster is close and on screen: freeze on its hat,
## explain uppercuts, and mark it (UPPERCUT IT! over its head).
func _check_hat_lesson(delta: float) -> void:
	if hat == "" or hat_lesson or Tutorial.seen("hat_first") or not is_instance_valid(player) or not player.active:
		return
	_lesson_check -= delta
	if _lesson_check > 0.0:
		return
	_lesson_check = 0.25
	var camera := get_viewport().get_camera_3d()
	var head := global_position + Vector3.UP * head_height * _body.scale.y
	if camera == null or global_position.distance_to(player.global_position) > 12.0 or not camera.is_position_in_frustum(head):
		return
	var uppercut := Controls.text("uppercut")
	var tip := Tutorial.open(self, "hat_first", "A MONSTER IN A HAT!",
			"Knock it off with an uppercut (%s) and the hat is yours to keep. Finish a hatted monster with an uppercut and the hat always comes off.\n\nThis one only goes down to an uppercut." % uppercut,
			_hat_node if _hat_node else self)
	if tip == null:
		return
	hat_lesson = true
	_lesson_label = Label3D.new()
	_lesson_label.text = "UPPERCUT IT!  (%s)" % uppercut
	_lesson_label.modulate = Color(1.0, 0.82, 0.35)
	_lesson_label.position.y = 2.75 * _body.scale.y
	_lesson_label.fixed_size = true
	_lesson_label.pixel_size = 0.0012
	_lesson_label.font_size = 34
	_lesson_label.outline_size = 10
	_lesson_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lesson_label.no_depth_test = true
	add_child(_lesson_label)


## The hat flies off spinning, then the game pauses for the popup.
func _pop_hat() -> void:
	var id := hat
	hat = ""
	if _lesson_label:
		_lesson_label.queue_free()
		_lesson_label = null
	if _hat_node == null or not is_instance_valid(_hat_node):
		HatPopup.open(get_tree(), id)
		return
	var flying := _hat_node
	_hat_node = null
	var world := get_parent()
	var at := flying.global_transform
	flying.get_parent().remove_child(flying)
	world.add_child(flying)
	flying.global_transform = at
	Hats.sparkles(flying, Hats.color(id), 0.35)
	DamagePopup.spawn(world, "HAT!", Hats.color(id), 60, at.origin + Vector3.UP * 0.6)
	Sfx.play("coin", 0.0, 1.4)
	var tween := flying.create_tween().set_parallel()
	tween.tween_property(flying, "global_position", at.origin + Vector3(randf_range(-0.6, 0.6), 1.8, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flying, "rotation", flying.rotation + Vector3(TAU, PI, 0.6), 0.45)
	tween.chain().tween_callback(func() -> void:
		if is_instance_valid(flying):
			flying.queue_free()
		HatPopup.open(world.get_tree(), id))


## A non-uppercut KO: the hat's gone in a puff.
func _lose_hat() -> void:
	hat = ""
	if _hat_node and is_instance_valid(_hat_node):
		HitFx.burst(get_parent(), _hat_node.global_position, Vector3.UP, Color(0.8, 0.8, 0.85), 18, 3.0, false, 0.05)
		DamagePopup.spawn(get_parent(), "poof", Color(0.75, 0.75, 0.8), 36, _hat_node.global_position + Vector3.UP * 0.3)
		_hat_node.queue_free()
	_hat_node = null


## How EnemyGear dresses this enemy: "plate", "robe", "suit", "bare" (its
## stats, nothing worn) or "none".
func _gear_style() -> String:
	return "plate"


## Nodes whose farthest box part is a hand (for gauntlets).
func _hand_nodes() -> Array:
	return []


## Parts of a held weapon (recolored to the gear tier instead of gauntlets).
func _weapon_parts() -> Array:
	return []


## Returns the horizontal velocity the enemy wants this frame.
func _think(_delta: float) -> Vector3:
	return Vector3.ZERO


func _animate(_delta: float, _speed: float) -> void:
	pass


## Called when a heavy punch staggers this enemy; cancel attacks here.
func _on_staggered() -> void:
	pass


# --- Helpers for subclasses ----------------------------------------------------

## Flat direction and distance to the player.
func _to_player() -> Vector3:
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset


func _turn_toward(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	return pivot


func _part(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	mesh.material = material
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
	_meshes.append(part)
	return part


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return mesh


## Every block in the game uses this: textured with the shared voxel grain.
static func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	return Look.block_material(color, metallic)


static func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0
	return material


# --- Internals -------------------------------------------------------------------

func _update_label() -> void:
	var text := "%s\n%d / %d" % [display_name, ceili(hp), int(max_hp)]
	# Armor isn't shown (2026-10-17): the gear on the body says it.
	var lines := []
	if damage_reduction >= 0.01:
		lines.append("-%d%% damage" % roundi(damage_reduction * 100))
	if not lines.is_empty():
		text += "\n" + "   ".join(lines)
	_hp_label.text = text
	_hp_label.visible = true


func _set_flash(on: bool) -> void:
	if on:
		_flash_timer = FLASH_TIME
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.albedo_color = Color(1, 1, 1, 0.3)
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in _meshes:
		if on:
			mesh.material_overlay = _flash_material
		else:
			mesh.material_overlay = _rest_overlay(mesh)


## The overlay a mesh wears when it isn't flashing: frost while frozen, the
## elite glow, or nothing.
func _rest_overlay(mesh: MeshInstance3D) -> Material:
	if _frost_fx and _frost_overlay:
		return _frost_overlay
	return mesh.get_meta("elite_overlay") if mesh.has_meta("elite_overlay") else null


## Frozen: an icy sheen over the whole body and ice drifting off it.
func _set_frozen_look(on: bool) -> void:
	if on == (_frost_fx != null) or (on and _dead):
		return
	if on:
		if _frost_overlay == null:
			_frost_overlay = StandardMaterial3D.new()
			_frost_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_frost_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_frost_overlay.albedo_color = Color(0.3, 0.65, 1.0, 0.3)
		_frost_fx = _status_particles(FROST_COLOR, Color(0.92, 0.98, 1.0), -0.6, false)
	else:
		_end_status_fx(_frost_fx)
		_frost_fx = null
	if _flash_timer <= 0.0:
		for mesh in _meshes:
			if is_instance_valid(mesh):
				mesh.material_overlay = _rest_overlay(mesh)


## A cloud of glowing motes around the body: flames rising (rise > 0) or ice
## drifting down, with a light in the same color.
func _status_particles(color: Color, core: Color, rise: float, flicker: bool) -> Node3D:
	var holder := Node3D.new()
	var height := top_height() * _body.scale.y
	holder.position.y = height * 0.5
	var motes := CPUParticles3D.new()
	motes.amount = 14 if Settings.use_web_profile() else 24
	motes.lifetime = 0.7 if rise > 0.0 else 1.2
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(0.32, height * 0.42, 0.26) * maxf(_body.scale.x, 1.0)
	motes.direction = Vector3.UP if rise > 0.0 else Vector3.DOWN
	motes.spread = 15.0
	motes.gravity = Vector3(0, rise, 0)
	motes.initial_velocity_min = 0.3 if rise > 0.0 else 0.05
	motes.initial_velocity_max = 1.0 if rise > 0.0 else 0.2
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	motes.scale_amount_curve = shrink
	var mote := BoxMesh.new()
	mote.size = Vector3(0.09, 0.2, 0.09) if rise > 0.0 else Vector3.ONE * 0.06
	mote.material = _glow_material(color)
	motes.mesh = mote
	holder.add_child(motes)
	var inner := CPUParticles3D.new()
	inner.amount = 6 if Settings.use_web_profile() else 10
	inner.lifetime = motes.lifetime * 0.8
	inner.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	inner.emission_box_extents = motes.emission_box_extents * 0.8
	inner.direction = motes.direction
	inner.gravity = motes.gravity
	inner.initial_velocity_min = motes.initial_velocity_min
	inner.initial_velocity_max = motes.initial_velocity_max
	inner.scale_amount_curve = shrink
	var spark := BoxMesh.new()
	spark.size = mote.size * 0.6
	spark.material = _glow_material(core)
	inner.mesh = spark
	holder.add_child(inner)
	# A light too, except in browsers (a crowd on fire would be a light each).
	if not Settings.use_web_profile():
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.4 if flicker else 0.8
		light.omni_range = 2.5
		holder.add_child(light)
		if flicker:
			light.create_tween().set_loops().tween_property(light, "light_energy", 0.7, 0.12).from(1.6)
	_topple.add_child(holder)
	return holder


## Stops the motes and lets the last ones finish before it goes.
func _end_status_fx(holder: Node3D) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	for child in holder.get_children():
		if child is CPUParticles3D:
			(child as CPUParticles3D).emitting = false
		elif child is OmniLight3D:
			child.queue_free()
	# Its own tween, so it goes with it if the monster goes first.
	var linger := holder.create_tween()
	linger.tween_interval(1.3)
	linger.tween_callback(holder.queue_free)


# --- Attack turns ---------------------------------------------------------------

## The attack this enemy is winding up or throwing at the player ("" if none).
func incoming_attack() -> String:
	return ""


## Seconds until that attack lands (lower = more urgent).
func attack_eta() -> float:
	return INF


## True if this enemy may attack now. Claims a free turn when it has rested.
func has_turn() -> bool:
	if not takes_turns or is_boss or is_taunted():
		return true
	_attackers = _attackers.filter(func(e) -> bool: return is_instance_valid(e) and not e._dead)
	if _attackers.has(self):
		return true
	if _turn_rest > 0.0 or _attackers.size() >= max_attackers:
		return false
	_attackers.append(self)
	_turn_age = 0.0
	return true


## Holding a turn right now (without trying to claim one).
func in_turn() -> bool:
	return not takes_turns or is_boss or _attackers.has(self)


## Done attacking: step back out and let another enemy in.
func end_turn() -> void:
	if _attackers.has(self):
		_attackers.erase(self)
		_turn_rest = randf_range(TURN_REST.x, TURN_REST.y)


## The player punched this enemy: it fights now, taking the turn of whoever
## has been attacking longest.
func take_turn() -> void:
	if not takes_turns or is_boss or _dead or _attackers.has(self):
		return
	_attackers = _attackers.filter(func(e) -> bool: return is_instance_valid(e) and not e._dead)
	if _attackers.size() >= max_attackers:
		var other: Enemy = _attackers.pop_front()
		other._turn_rest = 0.6
	_attackers.append(self)
	_turn_age = 0.0
	_turn_rest = 0.0


## Waiting for a turn: keep about WAIT_DISTANCE away, circling slowly.
func _wait_move(offset: Vector3, delta: float, speed: float) -> Vector3:
	var distance := offset.length()
	var direction := offset.normalized()
	if distance > WAIT_DISTANCE + 0.8:
		return direction * speed
	if distance < WAIT_DISTANCE - 0.6:
		return -direction * speed * 0.8
	_wait_circle -= delta
	if _wait_circle <= 0.0:
		_wait_circle = randf_range(1.0, 2.5)
		_wait_sign = [-1.0, 1.0].pick_random()
	return direction.cross(Vector3.UP) * _wait_sign * speed * 0.35


var _wait_circle := 0.0
var _wait_sign := 1.0


func _die(push: Vector3) -> void:
	if _topple_tween:
		_topple_tween.kill()
	if _squash_tween:
		_squash_tween.kill()
	if _topple:
		_topple.rotation = Vector3.ZERO
		_topple.position = Vector3.ZERO
		_topple.scale = Vector3.ONE
	if _daze_fx:
		_daze_fx.queue_free()
		_daze_fx = null
	_clear_doom()
	# The hat lesson's monster, and a plumber, only go down to an uppercut.
	if (hat_lesson or Hats.OVERALLS.has(hat)) and hat != "" and finisher.get("type", "") != "uppercut":
		hp = 1.0
		_update_label()
		DamagePopup.spawn(get_parent(), "UPPERCUT IT!", Color(1.0, 0.8, 0.3), 42, global_position + Vector3(0, 2.3 * _body.scale.y, 0))
		return
	if _lesson_label:
		_lesson_label.queue_free()
		_lesson_label = null
	if has_meta("veteran"):
		Achievements.earn("veteran")
	# Tony's The Take: an enraged monster pays double (Skim Off the Top: triple).
	if is_taunted() and GameState.has_passive("the_take"):
		coin_reward *= 3 if GameState.has_effect("skim") else 2
	_dead = true
	end_turn()
	# Finish a hatted enemy with an uppercut and the hat is always yours;
	# any other KO and it's gone in a puff.
	if hat != "":
		if finisher.get("type", "") == "uppercut":
			_pop_hat()
		else:
			_lose_hat()
	# Sigil capstones: burning enemies explode (Pyre), frozen ones shatter.
	if _burn_time > 0.0 and GameState.has_effect("pyre"):
		Powers.pyre(self)
	if _chill_time > 0.0 and GameState.has_effect("frost_shatter"):
		Powers.frost_burst(self)
	_end_status_fx(_burn_fx)
	_burn_fx = null
	_set_frozen_look(false)
	_set_flash(false)
	_hp_label.visible = false
	collision_layer = 0
	collision_mask = 1
	# Fling the body away from the punch (the Arena and Crypt burst the coins
	# they pay, HitFx.coins).
	_knockback = push * 2.5
	velocity.y = 3.0
	var chest := global_position + Vector3(0, 1.2, 0)
	HitFx.burst(get_parent(), chest, push + Vector3.UP, hit_color, 25, 5.0)
	Sfx.play_at("death", chest)
	Sfx.play("coin", -8.0)
	died.emit(self)
	if not finisher.is_empty():
		_launch(finisher)
		return
	# Crumple back, then break apart into cubes.
	var tween := create_tween()
	tween.tween_property(_body, "rotation:x", PI / 2, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		HitFx.shatter(get_parent(), _meshes, push, Color(0.55, 0.8, 1.0))
		_body.visible = false)
	tween.tween_interval(1.6)
	tween.tween_callback(queue_free)


# --- Finishing blows: the body flies ---------------------------------------------

## Launch strength by finisher level: plain, counter, clean / perfect counter.
const LAUNCH_POWER := [1.0, 1.8, 3.4]
const LAUNCH_MAX_TIME := 1.6


## Sends the body flying the way the killing punch went: uppercuts straight up,
## hooks sideways, straights and haymakers back. Counters exaggerate it; a clean
## or perfect counter is ridiculous (slow motion, spin, and it bowls through
## anything it hits).
func _launch(blow: Dictionary) -> void:
	var dir: Vector3 = blow.get("dir", -global_basis.z)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP)
	var level: int = blow.get("level", 0)
	var power: float = LAUNCH_POWER[level]
	var launch := Vector3.ZERO
	match blow.get("type", "jab"):
		"uppercut":
			launch = dir * 1.2 + Vector3.UP * 8.5
			_fly_spin = Vector3(-7.0, 0, randf_range(-2, 2))
		"hook":
			# A left hook swings left to right, so the body goes to the player's right.
			var across := right * (1.0 if blow.get("hand", "left") == "left" else -1.0)
			launch = across * 7.5 + dir * 2.0 + Vector3.UP * 3.0
			_fly_spin = Vector3(0, 9.0, 4.0) * (1.0 if blow.get("hand", "left") == "left" else -1.0)
		"haymaker":
			launch = dir * 13.0 + Vector3.UP * 4.5
			_fly_spin = Vector3(-9.0, randf_range(-3, 3), 0)
		"spear":
			launch = dir * 10.0 + Vector3.UP * 1.5
			_fly_spin = Vector3(-3.0, 0, 0)
		_:
			launch = dir * 6.0 + Vector3.UP * 2.8
			_fly_spin = Vector3(-5.0, 0, randf_range(-1.5, 1.5))
	launch.x *= power
	launch.z *= power
	launch.y *= lerpf(1.0, power, 0.7)
	_fly_spin *= power
	if is_boss:
		launch *= 0.55
	velocity = launch
	_knockback = Vector3.ZERO
	_flying = true
	_fly_time = 0.0
	_fly_level = level
	_bowled.clear()
	var at := global_position + Vector3(0, 1.2, 0)
	var who: Node3D = blow.get("player")
	match level:
		1:
			TimeFx.slowmo(0.75, 0.12)
			HitFx.ring(get_parent(), at, Color(1.0, 0.85, 0.4), 1.2)
			DamagePopup.spawn(get_parent(), "K.O.!", Color(1.0, 0.85, 0.35), 64, at + Vector3(0, 1.0, 0))
			if who and "_shake" in who:
				who._shake = maxf(who._shake, 0.1)
		2:
			TimeFx.slowmo(0.45, 0.25)
			HitFx.flash(get_parent(), at, Color(1.0, 0.95, 0.8), 0.9)
			HitFx.ring(get_parent(), at, Color(1.0, 0.6, 0.2), 1.8)
			HitFx.burst(get_parent(), at, launch.normalized(), Color(1.0, 0.8, 0.3), 40, 9.0, true, 0.06)
			DamagePopup.spawn(get_parent(), ["OBLITERATED!", "SENT TO THE MOON!", "GOODNIGHT!", "FATALITY!"].pick_random(),
					Color(1.0, 0.45, 0.2), 86, at + Vector3(0, 1.4, 0))
			Sfx.play_at("quake", at, 2.0, 1.4)
			Sfx.play("counter", 2.0, 0.7)
			if who and "_shake" in who:
				who._shake = maxf(who._shake, 0.22)


func _fly(delta: float) -> void:
	_fly_time += delta
	velocity.y -= _gravity * 0.85 * delta
	move_and_slide()
	_body.rotation += _fly_spin * delta
	# Clean / perfect counters: a spark trail, and it bowls through anything in its way.
	if _fly_level >= 2:
		_fly_trail -= delta
		if _fly_trail <= 0.0:
			_fly_trail = 0.05
			HitFx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Vector3.UP, Color(1.0, 0.7, 0.3), 3, 1.5, true, 0.05)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy == self or enemy.is_dead() or _bowled.has(enemy):
				continue
			if enemy.global_position.distance_to(global_position) < 1.4:
				_bowled.append(enemy)
				var shove := velocity
				shove.y = 0.0
				enemy.finisher = {"type": "jab", "hand": "left", "level": 1, "dir": shove.normalized(), "player": finisher.get("player")}
				enemy.take_hit(GameState.get_damage() * 3.0, enemy.global_position + Vector3(0, 1.2, 0), shove.normalized() * 8.0, true, "STRIKE!")
				if not enemy.is_dead():
					enemy.finisher = {}
	var landed := _fly_time > 0.2 and (is_on_floor() or is_on_wall())
	if landed or _fly_time > LAUNCH_MAX_TIME:
		_flying = false
		set_physics_process(false)
		var at := global_position + Vector3(0, 0.4, 0)
		HitFx.burst(get_parent(), at, Vector3.UP, Color(0.5, 0.45, 0.4), 10 + 10 * _fly_level, 3.0 + _fly_level, false, 0.06)
		if _fly_level >= 1:
			Sfx.play_at("death", at, 0.0, 0.7)
		HitFx.shatter(get_parent(), _meshes, velocity * 0.2, Color(0.55, 0.8, 1.0))
		_body.visible = false
		get_tree().create_timer(1.6, false).timeout.connect(queue_free)
