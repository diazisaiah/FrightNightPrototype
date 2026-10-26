class_name CardPlay
extends Node
## The fighter's level-up cards (Cards) and attribute perks (Attributes) in a
## fight. The player calls in at a handful of moments (a punch thrown or
## landed, a dodge, a hit taken, a dash) and this does what the cards say.
## Cards are GameState effects; perks are GameState.perk ids. Effects that
## change a passive or ultimate live with them (player.gd, ult.gd), and the
## Catalyst's power cards hear every power go off (Powers.listener).

const GRANITE_TIME := 2.0
const GET_UP_HP := 0.15
const GET_UP_TIME := 2.0
const BERSERK_TIME := 8.0
const BLUR_STEP_TIME := 2.0
const PRECISION_TIME := 0.5
const ENRAGE_TIME := 4.0
const SCARE_TIME := 2.0
const TIME_SLOW_TIME := 3.0
const FREE_RUN_TIME := 5.0
const WARD_STACKS := 3

var player: Player
var _cache := {}

# Once a bout.
var _get_up_used := false
var _berserk_used := false
# Timers (seconds left).
var _granite := 0.0
var untouchable := 0.0
var _berserk := 0.0
var _blur_step := 0.0
var _precision := 0.0
var _mirror := 0.0
var _crowd := 0.0
var _slick_cooldown := 0.0
var _afterglow := 0.0
var _attune_speed := 0.0
var _last_word := 0.0
var _unbroken_after := 0.0
var _body_cooldown := 0.0
# Counts and flags.
var _payback := false
var _guard := false
var _never := 0
var _landed := 0
var _counters := 0
var _two_answers := 0
var _free_flow_used := false
var _ricochet := 0.0
var _fifty_done := false
var _moving := 0.0
var _free_running := false
var _was_unbroken := false
var _ward := 0.0
var _powers_gone := 0
var _spectrum: Array[String] = []
var _casting := false
var _sting_from: Enemy
var _sting_time := -10.0
var _vault_target: Enemy
var _dash_hits := {}
## The punch being landed (punch_mod to after_punch).
var _ctx := {}


func _ready() -> void:
	GameState.changed.connect(_forget)
	Powers.listener = _on_power
	start_bout()


func _exit_tree() -> void:
	if Powers.listener == _on_power:
		Powers.listener = Callable()


func _forget() -> void:
	_cache.clear()


func fx(key: String) -> float:
	if not _cache.has(key):
		_cache[key] = GameState.get_effect(key)
	return _cache[key]


func perk(id: String) -> bool:
	var key := "perk/" + id
	if not _cache.has(key):
		_cache[key] = 1.0 if GameState.perk(id) else 0.0
	return _cache[key] > 0.0


## A new bout (a night, a Crypt floor): once-a-bout cards are ready again and
## Ultimate Surge starts the meter a quarter full.
func start_bout() -> void:
	_get_up_used = false
	_berserk_used = false
	_berserk = 0.0
	untouchable = 0.0
	_counters = 0
	_landed = 0
	_ward = 0.0
	_powers_gone = 0
	if fx("ult_surge") > 0.0 and player and player.ult:
		player.ult.meter = maxf(player.ult.meter, Ult.MAX_METER * 0.25)
		player.ult.add(0.0)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Every frame ------------------------------------------------------------------

func tick(delta: float) -> void:
	_granite -= delta
	untouchable -= delta
	_blur_step -= delta
	_precision -= delta
	_mirror -= delta
	_crowd -= delta
	_slick_cooldown -= delta
	_afterglow -= delta
	_attune_speed -= delta
	_last_word -= delta
	_unbroken_after -= delta
	_body_cooldown -= delta
	if _berserk > 0.0:
		_berserk -= delta
		if _berserk <= 0.0:
			player.class_event.emit("BERSERK ENDS")
	if player.combo == 0:
		_fifty_done = false
	# Perpetual Motion: the combo timer holds while you dodge.
	if player._defense != "" and fx("perpetual_motion") > 0.0:
		player._combo_freeze = maxf(player._combo_freeze, 0.05)
	# Unbroken II: the combo timer runs long for a while after Unbroken.
	if player.unbroken_time > 0.0:
		_was_unbroken = true
	elif _was_unbroken:
		_was_unbroken = false
		if fx("unbroken_ii") > 0.0:
			_unbroken_after = 5.0
	# Free Running: nonstop moving readies a big punch.
	if fx("free_running") > 0.0 and not _free_running:
		if Vector2(player.velocity.x, player.velocity.z).length() > Player.WALK_SPEED * 0.6:
			_moving += delta
			if _moving >= FREE_RUN_TIME:
				_moving = 0.0
				_free_running = true
				player.class_event.emit("FREE RUNNING  -  next punch x3")
		else:
			_moving = 0.0


# --- Speed ------------------------------------------------------------------------

## Punch speed on top of GameState.get_punch_speed (the punch about to land is
## combo + 1).
func speed_mult() -> float:
	var bonus := 0.0
	var combo := player.combo
	if combo >= 4:
		bonus += fx("second_gear")
	if combo < 5:
		bonus += fx("speed_bag")
	if perk("tempo"):
		bonus += minf(0.02 * combo, 0.2)
	if _blur_step > 0.0:
		bonus += 0.3
	if _attune_speed > 0.0:
		bonus += 0.1
	if fx("red_mist") > 0.0 and GameState.has_passive("berserker") and player.max_knuckles > 0.0:
		bonus += 0.4 * clampf(1.0 - player.knuckles / player.max_knuckles, 0.0, 1.0)
	return 1.0 + bonus


func move_mult() -> float:
	var bonus := 0.0
	if _blur_step > 0.0:
		bonus += 0.3
	if fx("blur") > 0.0 and player.combo >= 30:
		bonus += 0.2
	return 1.0 + bonus


## Quick Feet: dodges and dashes come back sooner.
func recovery_scale() -> float:
	return 0.8 if perk("quick_feet") else 1.0


func dash_scale() -> float:
	return 1.0 + fx("dash_reach")


func combo_window_scale() -> float:
	return 2.0 if _unbroken_after > 0.0 else 1.0


# --- Getting hit ------------------------------------------------------------------

## An attack nobody defended that a card slips for you: "" or what slipped it.
func auto_slip(attack: String, _attacker: Enemy) -> String:
	if attack in ["quake", "zone"]:
		return ""
	if _crowd > 0.0:
		return "READ IT"
	if _mirror > 0.0:
		_mirror = 0.0
		return "MIRROR MATCH"
	if _guard:
		_guard = false
		return "IN RHYTHM"
	if player.dash_time > 0.0 and fx("ghost_step") > 0.0:
		if fx("ghost_step") >= 2.0:
			player._forward_dash_cooldown = 0.0
		return "GHOST STEP"
	if fx("blur") > 0.0 and player.combo >= 30 and randf() < 0.2:
		return "BLUR"
	if player.is_sprinting():
		if fx("never_where") > 0.0:
			_never += 1
			if _never % 3 == 0:
				return "NOT THERE"
		if fx("slick") >= 2.0 and _slick_cooldown <= 0.0:
			_slick_cooldown = 3.0
			return "SLICK"
	return ""


## Raw damage of an attack after the cards that soften it.
func hit_amount(amount: float, attacker: Enemy) -> float:
	var cut := fx("hit_guard")
	if fx("crowd_guard") > 0.0:
		cut += minf(fx("crowd_guard") * _near_count(4.0), 0.25)
	if fx("juggernaut") > 0.0 and player.knuckles > player.max_knuckles * 0.5:
		cut += 0.25
	if fx("untouchable_tony") > 0.0 and attacker and not attacker.is_taunted() and _any_enraged():
		cut += 0.25
	amount *= maxf(0.2, 1.0 - cut)
	if _granite > 0.0:
		amount *= 0.5
	if _berserk > 0.0:
		amount *= 0.5
	# Slick: hits while sprinting only graze.
	if fx("slick") > 0.0 and player.is_sprinting():
		amount *= 0.5
	# Ward soaks what it can (it's in knuckle HP; amount is before defense).
	if _ward > 0.0 and amount > 0.0:
		var loss := GameState.get_knuckle_loss_multiplier()
		var soak := minf(_ward, amount * loss)
		_ward -= soak
		amount -= soak / loss
		if _ward <= 0.0:
			DamagePopup.spawn(player.get_parent(), "WARD BROKEN", Color(0.95, 0.45, 0.75), 36, player.global_position + player._flat_forward() + Vector3(0, 1.5, 0))
	return amount


## How long a hit makes you flinch (1 = the usual).
func flinch_scale() -> float:
	if fx("juggernaut") > 0.0 and player.knuckles > player.max_knuckles * 0.5:
		return 0.0
	return maxf(0.0, 1.0 - fx("no_flinch"))


## The combo you keep after a hit (Bounce Back).
func combo_after_hit(combo: int) -> int:
	var kept := floori(combo * fx("bounce_back"))
	if kept > 0:
		player._combo_timer = maxf(player._combo_timer, 1.0)
	return kept


## After a clean hit landed on you.
func on_hit(attacker: Enemy) -> void:
	_payback = fx("payback") > 0.0
	if perk("granite_chin"):
		_granite = GRANITE_TIME
	if fx("hit_ult") > 0.0:
		player.ult.add(fx("hit_ult"))
	if attacker == null or attacker.is_dead():
		return
	if fx("shrug_rage") > 0.0:
		attacker.taunt(fx("shrug_rage"))
	if fx("elemental_body") > 0.0 and _body_cooldown <= 0.0:
		_body_cooldown = 1.0
		_set_off_random(attacker)


## Knuckle HP changed: Berserk wakes below half.
func on_knuckles() -> void:
	if fx("berserk") > 0.0 and not _berserk_used and player.knuckles > 0.0 and player.knuckles < player.max_knuckles * 0.5:
		_berserk_used = true
		_berserk = BERSERK_TIME
		player.class_event.emit("BERSERK!  x2 damage, half damage taken")
		Sfx.play("growl", 0.0, 0.7)
		HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.UP, Color(1.0, 0.15, 0.05), 40, 6.0, true, 0.06)


## Get Up: once a bout a knockout leaves you standing. True if it did.
func save_from_knockout() -> bool:
	if not perk("get_up") or _get_up_used:
		return false
	_get_up_used = true
	player.knuckles = player.max_knuckles * GET_UP_HP
	untouchable = GET_UP_TIME
	player.class_event.emit("GET UP!")
	TimeFx.slowmo(0.4, 0.4)
	Sfx.play("counter", 0.0, 0.7)
	return true


# --- Throwing and landing punches ------------------------------------------------------------

## Before a punch flies: Ricochet dashes you at the next monster.
func before_punch() -> void:
	if _ricochet <= 0.0:
		return
	var reach := 5.0 * _ricochet
	_ricochet = 0.0
	var target := _nearest(player.global_position, reach, [])
	if target == null:
		return
	var to := target.global_position - player.global_position
	to.y = 0.0
	player.rotation.y = atan2(-to.x, -to.z)
	player._camera.rotation.x = -0.05
	var run := to.length() - 1.2
	if run > 0.2:
		# Dashes decay at 45 m/s/s: this speed covers the gap.
		player._dash = to.normalized() * sqrt(2.0 * 45.0 * run)
		HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, to.normalized(), Color(0.7, 0.5, 1.0), 16, 4.0, true, 0.04)


## What the cards do to the punch about to land: {mult, stagger, caption, push}.
func punch_mod(target: Enemy, type: String, counter: bool, airborne: bool, set_up: bool, hit_point: Vector3, forced: bool) -> Dictionary:
	var result := {"mult": 1.0, "stagger": false, "caption": "", "push": 1.0}
	var first := not target.has_meta("met")
	target.set_meta("met", true)
	var was_staggered := target.is_staggered()
	if not was_staggered:
		target.set_meta("lock_spent", 0.0)
	_ctx = {"target": target, "taunted": target.is_taunted(), "hp": target.hp, "staggered": was_staggered}
	if forced and not counter:
		return result
	var bonus := 0.0
	if _payback:
		_payback = false
		bonus += fx("payback")
	if fx("mob_bonus") > 0.0:
		bonus += fx("mob_bonus") * mini(_near_count(3.0), 4)
	if was_staggered:
		bonus += fx("staggered_bonus")
	if counter and target.combo_finished():
		bonus += fx("closing")
	var facing := target.facing(player.global_position)
	if facing < 0.3:
		bonus += fx("cheap_shot")
	if airborne:
		bonus += fx("hang_time")
	if airborne or player.global_position.y > target.global_position.y + 0.5:
		bonus += fx("high_ground")
	if target.incoming_attack() != "":
		bonus += fx("opportunist")
	if target.is_taunted() and target.hit_zone(hit_point) == "body":
		bonus += fx("below_belt")
	if first:
		bonus += fx("first_punch")
	if float(target.get_meta("vinnie_until", 0.0)) > _now():
		bonus += fx("vinnie_bonus")
	if _afterglow > 0.0:
		bonus += fx("afterglow")
	if float(target.get_meta("resonant_until", 0.0)) > _now():
		bonus += 0.2
	if fx("spectrum") > 0.0 and GameState.has_passive("prism"):
		bonus += minf(0.1 * _spectrum.size(), 0.4)
	result.mult = 1.0 + bonus
	var captions: Array[String] = []
	if first and facing < 0.5 and fx("blindside") > 0.0:
		result.mult *= fx("blindside")
		captions.append("BLINDSIDE!")
	if target == _vault_target:
		_vault_target = null
		result.mult *= 2.0
	if _free_running and not forced:
		_free_running = false
		result.mult *= 3.0
		result.stagger = true
		captions.append("FREE RUNNING!")
	if counter and _precision > 0.0 and perk("precision"):
		_precision = 0.0
		result.mult *= 2.0
		captions.append("PRECISION!")
	if perk("knockout_blow") and not forced and player._combo_grew and player.combo > 0 and player.combo % 6 == 0:
		result.mult *= 2.0
		result.stagger = true
		captions.append("KNOCKOUT BLOW!")
	if _berserk > 0.0:
		result.mult *= 2.0
	# Spear Hands: Long Reach's punches at the edge of reach.
	if fx("spear_hands") > 0.0 and GameState.has_passive("long_reach") \
			and target.global_position.distance_to(player.global_position) > Player.PUNCH_REACH:
		result.mult *= 1.3
		result.push = 2.5
	if airborne and fx("dive_kick") >= 2.0:
		result.push = maxf(result.push, 3.0)
	if set_up and target.is_taunted() and fx("wake_up_call") >= 2.0:
		result.push = maxf(result.push, 3.0)
	result.caption = "\n".join(captions)
	return result


## After a punch lands (and after its damage).
func after_punch(target: Enemy, type: String, hand: String, raw: float, dealt: float, counter: bool, killed: bool, airborne: bool, set_up: bool, forced: bool) -> void:
	var base := GameState.get_damage()
	var was_taunted: bool = _ctx.get("taunted", false)
	var hp_before: float = _ctx.get("hp", 0.0)
	var was_staggered: bool = _ctx.get("staggered", false)
	_ctx = {}
	# The Power perk Follow Through: a knockout carries on.
	if killed and perk("follow_through") and dealt > hp_before:
		var next := _nearest(target.global_position, 3.0, [target])
		if next:
			next.take_hit((dealt - hp_before) * 0.5, next.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "FOLLOW THROUGH")
	if counter:
		_counter_landed(target, hand, killed)
	if forced:
		return
	_landed += 1
	var combo := player.combo
	# The Mauler.
	if type == "hook" and fx("cleave") > 0.0:
		_cleave(target, raw)
	if fx("avalanche") > 0.0 and _landed % 4 == 0:
		_avalanche()
	# The Answer: a jab on a monster you just dodged.
	if type == "jab" and target == _sting_from and _now() - _sting_time <= 1.0 and fx("sting_delay") > 0.0 and not killed:
		_sting_from = null
		target.delay(fx("sting_delay"), "STUNG")
	# The Blur.
	if fx("pierce_hit") > 0.0:
		var behind := _behind(target, 2.0)
		if behind:
			behind.take_hit(raw * fx("pierce_hit"), behind.global_position + Vector3(0, 1.2, 0), player._flat_forward() * 2.0, false, "THROUGH")
	if fx("thousand_fists") > 0.0 and combo >= int(fx("thousand_fists")) and not killed:
		_extra_hit(target, raw * 0.5)
	if killed and combo > 1 and fx("ricochet") > 0.0:
		player._combo_timer = GameState.get_combo_window()
		_ricochet = fx("ricochet")
	if player._combo_grew and fx("rhythm_guard") > 0.0 and combo % int(fx("rhythm_guard")) == 0:
		_guard = true
	if not killed and was_staggered and fx("stun_lock") > 0.0 and target.is_staggered():
		var spent := float(target.get_meta("lock_spent", 0.0))
		var add := minf(0.35, fx("stun_lock") - spent)
		if add > 0.0:
			target.extend_stagger(add)
			target.set_meta("lock_spent", spent + add)
	if player._combo_grew and fx("flurry") > 0.0 and combo > 0 and combo % 25 == 0 and not killed:
		_flurry(target)
	if fx("fifty") > 0.0 and combo >= 50 and not _fifty_done:
		_fifty_done = true
		_slow_time("FIFTY BEFORE THEY BLINK")
	# The Stray.
	if airborne and fx("parkour") > 0.0:
		player._forward_dash_cooldown = 0.0
	# Tony.
	if fx("say_it") > 0.0 and _landed % int(fx("say_it")) == 0 and not killed:
		target.taunt(ENRAGE_TIME)
	if set_up and was_taunted and fx("wake_up_call") > 0.0 and not killed:
		target.stun(0.6)
	if target.is_boss and fx("respect") > 0.0 and not target.has_meta("respected") and not killed:
		target.set_meta("respected", true)
		target.taunt(ENRAGE_TIME * 1.5)
	if was_taunted and not killed and fx("capo") > 0.0 and not target.has_meta("capo"):
		_capo(target)
	if killed and was_taunted:
		_enraged_down(target)
	# The Catalyst.
	if fx("runic_wraps") > 0.0 and _landed % int(fx("runic_wraps")) == 0 and not killed:
		_set_off_random(target, raw)
	if fx("focus") > 0.0 and GameState.selected_powers().size() == 1 and randf() < fx("focus") and not killed:
		_set_off(GameState.selected_powers()[0], target, raw)


func _counter_landed(target: Enemy, hand: String, killed: bool) -> void:
	_counters += 1
	if fx("turnabout") > 0.0:
		var strong := fx("turnabout") >= 2.0
		if not killed:
			target.stun(1.2 if strong else 0.6)
		if strong:
			for enemy in _enemies():
				if enemy != target and enemy.global_position.distance_to(target.global_position) <= 2.0:
					enemy.stun(Enemy.STAGGER_TIME)
	if fx("last_word") > 0.0 and _counters % 10 == 0:
		_last_word = TIME_SLOW_TIME
		_slow_time("THE LAST WORD")
	if killed and _two_answers < int(fx("two_answers")):
		_two_answers += 1
		player._ready_counter(_other(hand))
		player.class_event.emit("TWO ANSWERS")
	else:
		_two_answers = 0
		if fx("free_flow") > 0.0 and not _free_flow_used and not player.is_counter_ready():
			_free_flow_used = true
			player._ready_counter(_other(hand))
	if fx("mirror_match") > 0.0:
		_mirror = 1.0


## Follow-up counters (Two Answers, Free Flow) go to the other hand, a
## one-two (the same hand twice would break the combo anyway).
static func _other(hand: String) -> String:
	return "right" if hand == "left" else "left"


## Perfect Counters off cooldown: The Last Word's slow, Riposte II's stance.
func free_perfect() -> bool:
	if _last_word > 0.0:
		return true
	return fx("riposte_ii") > 0.0 and player.ult._riposte > 0.0 and player.ult._riposte_counters


## Iron Knuckles and Second Breath: what a punch costs (1 = the usual).
func cost_scale() -> float:
	if fx("second_breath") > 0.0 and player.knuckles < player.max_knuckles * fx("second_breath"):
		return 0.0
	return 0.8 if perk("iron_knuckles") else 1.0


# --- Dodges and dashes -------------------------------------------------------------------

func on_dodge(clean: bool, attack: String, attacker: Enemy) -> void:
	_crowd = fx("crowd_reader")
	_free_flow_used = false
	if fx("perpetual_motion") > 0.0:
		player._combo_freeze = maxf(player._combo_freeze, 1.0)
	if attacker == null or attacker.is_dead():
		if clean:
			_clean_dodge(null)
		return
	_sting_from = attacker
	_sting_time = _now()
	if clean:
		_clean_dodge(attacker)
	if attack in ["arrow", "fireball", "bolt"] and fx("return_sender") > 0.0:
		attacker.take_hit(GameState.get_damage() * fx("return_sender"), attacker.global_position + Vector3(0, 1.3, 0), Vector3.ZERO, true, "RETURN TO SENDER")
	if fx("afterimage") > 0.0:
		_afterimage(attacker, int(fx("afterimage")))


func _clean_dodge(attacker: Enemy) -> void:
	if fx("read_twice") > 0.0:
		player._perfect_cooldown = maxf(0.0, player._perfect_cooldown - fx("read_twice"))
	if perk("blur_step"):
		_blur_step = BLUR_STEP_TIME
	if perk("precision"):
		_precision = PRECISION_TIME
	if perk("clean_break") and attacker:
		attacker.delay(0.5, "STUMBLED")


func on_dash() -> void:
	_dash_hits.clear()


## The dash ran into a monster: Shoulder Charge knocks it down, Vault goes over.
func dash_contact(enemy: Enemy) -> void:
	if _dash_hits.has(enemy) or enemy.is_dead():
		return
	_dash_hits[enemy] = true
	var forward := player._flat_forward()
	# Shoulder Charge: knocks it back and hurts, but never stuns (dashing into
	# a boss again and again would hold it still).
	if fx("shoulder") > 0.0:
		var strong := fx("shoulder") >= 2.0
		enemy.take_hit(GameState.get_damage() * (2.0 if strong else 1.0), enemy.global_position + Vector3(0, 1.1, 0),
				forward * (10.0 if strong else 6.0), false, "SHOULDER CHARGE")
	if fx("vault") > 0.0 and not enemy.is_dead():
		var spot := player.teleport_spot(enemy, enemy.global_position + forward * 1.3)
		if spot == Vector3.INF:
			return  # Its back's to a wall: nowhere to land.
		player._dash = Vector3.ZERO
		player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
		player.rotation.y = atan2(forward.x, forward.z)
		HitFx.burst(player.get_parent(), enemy.global_position + Vector3(0, 2.2, 0), Vector3.UP, Color(0.35, 0.95, 0.5), 18, 3.0, true, 0.05)
		Sfx.play("whoosh", -2.0, 1.4)
		if fx("vault") >= 2.0:
			_vault_target = enemy


# --- The Catalyst's powers -------------------------------------------------------------------

## A power went off on a target (Powers.listener).
func _on_power(root: String, target: Enemy) -> void:
	_afterglow = 1.0
	# The Catalyst's runes flare in the power's color.
	player._fists.flash_runes(Fists.POWER_COLORS.get(root, Color.WHITE), player.last_hand())
	if fx("ward") > 0.0:
		var cap := fx("ward") * player.max_knuckles * WARD_STACKS
		_ward = minf(_ward + fx("ward") * player.max_knuckles, cap)
	if GameState.has_passive("attunement") and root == GameState.power_pick and fx("deep_attunement") > 0.0:
		_attune_speed = 2.0
	# Spectrum: different powers in a row.
	if root in _spectrum:
		_spectrum = [root]
	else:
		_spectrum.append(root)
	if target and is_instance_valid(target) and not target.is_dead():
		var last: Array = target.get_meta("last_power", ["", -10.0])
		target.set_meta("last_power", [root, _now()])
		if last[0] != "" and last[0] != root and _now() - float(last[1]) <= 2.0:
			if fx("resonance") > 0.0:
				target.stun(Enemy.STAGGER_TIME)
				if fx("resonance") >= 2.0:
					target.set_meta("resonant_until", _now() + 3.0)
			if fx("sigil_weave") > 0.0 and GameState.has_passive("dual_sigil"):
				HitFx.burst(target.get_parent(), target.global_position + Vector3(0, 1.2, 0), Vector3.UP, Color(0.95, 0.45, 0.75), 30, 5.0, true, 0.06)
				target.take_hit(GameState.get_damage() * 2.0, target.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, true, "SIGIL WEAVE")
	if _casting:
		return
	_casting = true
	if fx("twin_cast") > 0.0 and randf() < fx("twin_cast"):
		_set_off(root, target)
	_powers_gone += 1
	if fx("grand_unification") > 0.0 and _powers_gone % 20 == 0:
		player.class_event.emit("GRAND UNIFICATION")
		for power in GameState.owned_powers():
			_set_off(power, target)
	_casting = false


## One of your selected powers, at random, on a target.
func _set_off_random(target: Enemy, damage := 0.0) -> void:
	var picks := GameState.selected_powers()
	if not picks.is_empty():
		_set_off(picks.pick_random(), target, damage)


## Sets off a power on a target as if a big punch had landed (damage: that
## punch, or a heavy's worth).
func _set_off(root: String, target: Enemy, damage := 0.0) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead():
		return
	if damage <= 0.0:
		damage = GameState.get_damage() * player.get_combo_multiplier() * 2.0
	match root:
		"sigil_fire":
			Powers.fire_burst(target, damage * _power_value(root, "fire_punch"))
		"sigil_frost":
			Powers.frost_burst(target, _power_value(root, "frost_punch"))
		"sigil_storm":
			Powers.chain_lightning(target, damage, maxi(2, int(_power_value(root, "chain_lightning"))))
		"sigil_blood":
			player.heal(maxf(GameState.heal_amount("counter_heal", player.max_knuckles), player.max_knuckles * 0.02))
			HitFx.burst(player.get_parent(), target.global_position + Vector3(0, 1.2, 0), Vector3.UP, Color(0.85, 0.05, 0.08), 16, 4.0, true, 0.05)
			Powers.went_off(root, target)


## A power's number, or its sigil's own when it isn't selected (Grand
## Unification sets off every power you own).
func _power_value(root: String, effect: String) -> float:
	var value := fx(effect)
	if value > 0.0:
		return value
	return float(GameState.UPGRADES.get(root, {}).get("effects", {}).get(effect, 0.0))


# --- Effects ------------------------------------------------------------------------------

## Haymaker Swing: a hook sweeps the arc in front.
func _cleave(target: Enemy, raw: float) -> void:
	var wide := fx("cleave") >= 2.0
	var forward := player._flat_forward()
	for enemy in _enemies():
		if enemy == target:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() > 3.0 or offset.normalized().dot(forward) < (0.2 if wide else 0.55):
			continue
		enemy.take_hit(raw * (1.0 if wide else 0.5), enemy.global_position + Vector3(0, 1.2, 0), offset.normalized() * 4.0, false, "SWING")


## Avalanche: everything in front is shoved back and staggered.
func _avalanche() -> void:
	var forward := player._flat_forward()
	var any := false
	for enemy in _enemies():
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length() > 3.5 or offset.normalized().dot(forward) < 0.3:
			continue
		any = true
		enemy.take_hit(GameState.get_damage() * 0.5, enemy.global_position + Vector3(0, 1.0, 0), offset.normalized() * 9.0, true, "AVALANCHE")
		if not enemy.is_dead():
			enemy.knock_down(0.8, offset)
	if any:
		Sfx.play("quake", -4.0, 1.1)
		player._shake = maxf(player._shake, 0.05)


func _extra_hit(target: Enemy, damage: float) -> void:
	await get_tree().create_timer(0.07, false).timeout
	if is_instance_valid(target) and not target.is_dead():
		target.take_hit(damage, target.global_position + Vector3(randf_range(-0.2, 0.2), 1.3, 0), Vector3.ZERO, false, "x2")


## Flurry: eight lightning-fast hits.
func _flurry(target: Enemy) -> void:
	player.class_event.emit("FLURRY!")
	var damage := GameState.get_damage() * player.get_combo_multiplier() * 0.5
	for i in 8:
		await get_tree().create_timer(0.05, false).timeout
		if not is_instance_valid(target) or target.is_dead():
			return
		var at := target.global_position + Vector3(randf_range(-0.25, 0.25), randf_range(1.0, 1.6), 0)
		target.take_hit(damage, at, Vector3.ZERO, i == 7, "FLURRY" if i == 7 else "")
		HitFx.burst(player.get_parent(), at, Vector3.UP, Color(0.7, 0.5, 1.0), 6, 3.0, true, 0.03)
		Sfx.play_at("hit", at, -6.0, 1.3 + i * 0.08)


## Afterimage: a violet copy punches the attacker.
func _afterimage(attacker: Enemy, times: int) -> void:
	for i in times:
		await get_tree().create_timer(0.15, false).timeout
		if not is_instance_valid(attacker) or attacker.is_dead():
			return
		var at := attacker.global_position + Vector3(0, 1.3, 0)
		HitFx.burst(player.get_parent(), at, Vector3.UP, Color(0.7, 0.45, 1.0), 14, 3.0, true, 0.05)
		attacker.take_hit(GameState.get_damage(), at, Vector3.ZERO, false, "AFTERIMAGE")


## Time slows for every monster (not for you).
func _slow_time(caption: String) -> void:
	Enemy.slow_time(TIME_SLOW_TIME)
	TimeFx.slowmo(0.6, 0.25)
	player.class_event.emit(caption)
	Sfx.play("tell", 0.0, 0.6)


## Capo: the enraged monster turns on its neighbor.
func _capo(enemy: Enemy) -> void:
	enemy.set_meta("capo", true)
	var other := _nearest(enemy.global_position, 6.0, [enemy])
	if other == null:
		return
	var to := other.global_position - enemy.global_position
	to.y = 0.0
	enemy.rotation.y = atan2(-to.x, -to.z)
	enemy.delay(2.0, "CAPO'S ORDERS")
	other.take_hit(GameState.get_damage() * 3.0, other.global_position + Vector3(0, 1.2, 0), to.normalized() * 5.0, true, "SLUGGED")


## An enraged monster went down: Bada Bing, Skim and Last Word.
func _enraged_down(target: Enemy) -> void:
	var enrage := int(fx("bada_bing"))
	if fx("skim") > 0.0 and GameState.has_passive("the_take"):
		enrage = maxi(enrage, 1)
	var exclude: Array[Enemy] = [target]
	for i in enrage:
		var next := _nearest(target.global_position, 10.0, exclude)
		if next == null:
			break
		exclude.append(next)
		next.taunt(ENRAGE_TIME)
	if fx("last_word_tony") > 0.0:
		for enemy in _enemies():
			if enemy.global_position.distance_to(target.global_position) <= 4.0:
				enemy.scare(SCARE_TIME, player.global_position)
		player.ult.say(["Who's next?", "Anybody else?", "That's what I thought."].pick_random())


# --- Looking around ------------------------------------------------------------------------

func _enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead():
			list.append(enemy)
	return list


func _near_count(radius: float) -> int:
	var count := 0
	for enemy in _enemies():
		if enemy.global_position.distance_to(player.global_position) <= radius:
			count += 1
	return count


func _any_enraged() -> bool:
	for enemy in _enemies():
		if enemy.is_taunted():
			return true
	return false


func _nearest(from: Vector3, radius: float, exclude: Array) -> Enemy:
	var best: Enemy = null
	var best_distance := radius
	for enemy in _enemies():
		if enemy in exclude:
			continue
		var distance := enemy.global_position.distance_to(from)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## The monster right behind the target, from where you stand.
func _behind(target: Enemy, reach: float) -> Enemy:
	var forward := player._flat_forward()
	var best: Enemy = null
	var best_distance := reach
	for enemy in _enemies():
		if enemy == target:
			continue
		var offset := enemy.global_position - target.global_position
		offset.y = 0.0
		if offset.length() <= best_distance and offset.normalized().dot(forward) > 0.3:
			best = enemy
			best_distance = offset.length()
	return best
