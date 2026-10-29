class_name Ult
extends Node
## Class ultimates and the meter that charges them. Reading the fight fills it
## fastest (dodges, counters, set-up heavies, combos); wild jabs barely do and
## getting hit drains it. The configured ultimate action fires it when full:
##   Berserker       Inferno Uppercut: any time the meter is full, a flaming
##                   uppercut that launches the nearest enemy (your Grudge
##                   target, if it's in reach) and sets it alight.
##                   His meter fills faster (INFERNO_GAIN) and hits never drain it.
##   Combo Master    Temporal Break: enemies freeze, punch prompts appear; each right
##                   one lands a hit, grows the combo and buys back some time,
##                   but the clock runs faster and faster.
##   Counter Master  Riposte Stance: for a few seconds every attack is slipped
##                   automatically and answered with a counter hook.
##   Free Runner     Highlight Reel: lightning-dash from enemy to enemy in view,
##                   punching each, and finish with a leaping haymaker.
##   Wise Guy        Big Mouth: Tony insults the monster he's looking at; it's
##                   enraged, comes only for him, hits 50% harder and takes
##                   double damage from him. Refills very fast; a KO on an
##                   enraged monster refunds half the meter.

signal meter_changed(value: float, ready: bool)
## A short line under the meter ("RIPOSTE  2.4s", "INFERNO READY ..."); "" clears it.
signal status_changed(text: String)
## Temporal Break's clock and prompt, every frame while it runs.
signal time_stop_changed(running: bool, fraction: float, keys: String, punch_name: String, hits: int)
## An ultimate just went off.
signal used(class_id: String)
## Tony said something (an insult, a quip, a KO line): the HUD shows it.
signal spoke(line: String)

const MAX_METER := 100.0
## Meter per event. Dodges, counters and set-ups are scaled by the combo
## multiplier; a plain hit is not, so mashing fills it slowly.
const GAIN := {
	"hit": 1.0, "setup": 3.0, "running": 4.0,
	"dodge": 5.0, "clean_dodge": 10.0, "counter": 8.0, "clean_counter": 12.0,
}
const HIT_LOSS := 10.0
const NAMES := {
	"berserker": "INFERNO UPPERCUT", "combo_master": "TEMPORAL BREAK",
	"counter_master": "RIPOSTE STANCE", "free_runner": "HIGHLIGHT REEL",
	"wise_guy": "BIG MOUTH",
	"elementalist": "ELEMENTAL FISTS",
}
## One line each, for the class picker.
const DESCRIPTIONS := {
	"berserker": "With a full meter, leap at the nearest enemy with a flaming uppercut that launches it and sets it alight.",
	"combo_master": "Stop time. Move freely and throw the punches shown as fast as you can: each one lands, grows your combo and buys a little more time.",
	"counter_master": "Riposte Stance: for 4 seconds every attack is slipped for you and answered with a counter hook.",
	"free_runner": "Streak like lightning from enemy to enemy in view, punching each, and finish with a leaping haymaker.",
	"wise_guy": "Insult the monster you're looking at. It comes only for you, hits 50% harder and takes double damage from you. Refills fast.",
	"elementalist": "For 10 seconds every punch can throw a fireball, an icicle, lightning or a blood heal.",
}
## The equipped ultimate's name (Abilities), for the HUD.
static func equipped_name() -> String:
	var entry := Abilities.info(GameState.player_class, GameState.ultimate())
	return String(entry.get("name", NAMES.get(GameState.player_class, "ULTIMATE"))).to_upper()


const FIRE_COLOR := Color(1.0, 0.3, 0.05)
const LIGHTNING_COLOR := Color(0.6, 0.85, 1.0)

# Berserker
const INFERNO_DAMAGE := 3.0
const INFERNO_RANGE := 3.5
## Inferno Uppercut leaps at its target from this far (2026-10-24).
const INFERNO_LEAP := 7.0
const INFERNO_LEAP_TIME := 0.42
const INFERNO_SPLASH := 2.6
## The Mauler's meter fills this much faster.
const INFERNO_GAIN := 1.3
const INFERNO_LAUNCH := 7.0
const INFERNO_STUN := 1.6
const INFERNO_BURN_TIME := 4.0
# Combo Master
## 2026-10-24: twice as long, and the Blur can move during it.
## 2026-10-29: no prompts. Punches land on what you aim at, but the damage
## is held until time resumes, then lands all at once (a monster killed
## mid-stop used to die frozen, and a Dead League boss could linger into the
## next round). The other hand from your last punch (it glows) buys back
## time, half what a prompt did.
## Diminishing returns (2026-10-29: a fast player kept it running): each
## refund is smaller than the last, refunds never push the clock past where
## it started, and a Temporal Break soon after the last one is shorter.
const TIME_STOP_START := 6.0
const TIME_STOP_REFUND := 0.25
const TIME_STOP_REFUND_DECAY := 0.8
## A Temporal Break within this long of the last one's end lasts
## TIME_STOP_REPEAT as long, stacking, down to TIME_STOP_REPEAT_MIN.
const TIME_STOP_FATIGUE := 30.0
const TIME_STOP_REPEAT := 0.75
const TIME_STOP_REPEAT_MIN := 0.5
## Each hit makes the clock run this much faster.
const TIME_STOP_SPEEDUP := 0.12
const TIME_STOP_RANGE := 12.0
const TIME_STOP_COMBO_GAIN := 2
const TIME_STOP_STUN := 1.0
const TIME_COLOR := Color(0.65, 0.85, 1.0)
## Impact sparks left hanging in stopped time, at most.
const TIME_SPARKS := 60
# Counter Master
const RIPOSTE_TIME := 4.0
# Alternate ultimates (Abilities, 2026-10-24).
const SHIELD_HITS := 3
const SHIELD_TIME := 12.0
const SHIELD_RADIUS := 4.0
const SHIELD_BLAST := 2.0
const FLOW_TIME := 10.0
const UNBROKEN_TIME := 10.0
const HYPE_TIME := 6.0
const HYPE_SPEED := 1.6
const HYPE_DAMAGE := 2.0
const FAMILY_TIME := 10.0
const FAMILY_SIZE := 3
## The Catalyst. Elemental Fists: each landed punch rolls each element
## (SPELL_CHANCE; Elemental Fists II raises it to SPELL_CHANCE_MAX).
const SPELL_TIME := 10.0
const SPELL_CHANCE := 0.2
const SPELL_CHANCE_MAX := 0.25
const SPELL_FIRE := 1.6
const SPELL_ICE := 1.1
const SPELL_LIGHTNING := 3.0
const SPELL_JUMPS := 3
const SPELL_HEAL := 0.3
## Flame Burst: a ring of fire around him.
## Flame Burst (2026-10-28: made a real explosion): a fireball, a shockwave
## across the ground, a ring of flame pillars and debris; regular monsters it
## doesn't knock out are blasted up and away (BURST_LAUNCH), then land down.
const BURST_RADIUS := 9.0
const BURST_LAUNCH := 16.0
const BURST_LIFT := 10.0
## (2026-10-29: was 5x, too little for a blast that whites out the screen.)
const BURST_DAMAGE := 10.0
## Everything in the blast, bosses too, is stunned while the flash blinds you.
const BURST_STUN := 1.0
const BURST_BURN := 0.8
const BURST_BURN_TIME := 5.0
const BURST_COLOR := Color(1.0, 0.4, 0.06)
const RIPOSTE_RANGE := 3.2
# Free Runner
const REEL_TARGETS := 5
const REEL_RANGE := 14.0
const REEL_DASH_TIME := 0.09
const REEL_PAUSE := 0.12
const REEL_DAMAGE := 2.5
const REEL_FINISHER := 5.0
const REEL_STAND_OFF := 1.2
# Wise Guy
## Big Mouth refills this many times faster than other ultimates.
const MOUTH_GAIN := 3.0
const MOUTH_RANGE := 16.0
const MOUTH_TIME := 8.0
## Share of the meter back when an enraged monster goes down.
const MOUTH_REFUND := 0.5

var player: Player
var meter := 0.0
## "time_stop" or "reel" while one of those has the controls.
var mode := ""

var _riposte := 0.0
## Riposte counters back; Flow State only dodges.
var _riposte_counters := true
## Brimstone Shield: hits left, damage soaked, seconds left.
var _shield_hits := 0
var _shield_soaked := 0.0
var _shield_time := 0.0
var _shield_ring: MeshInstance3D
## Hype Train: seconds left (the player reads it for speed and bowling).
var hype := 0.0
## Elemental Fists time left.
var spellfists := 0.0
var _status := ""
# Temporal Break
var _time_left := 0.0
var _time_full := 0.0
var _refund := 0.0
## Seconds left in which another Temporal Break comes back shorter, and how
## many came back to back.
var _stop_fatigue := 0.0
var _stop_repeats := 0
var _hits := 0
## Damage waiting on each monster: {enemy: [damage, sparks]}.
var _held := {}
var _stop_hand := ""
var _punch_wait := 0.0
var _spark_count := 0
var _frozen: Array[Node] = []
var _struck: Array[Enemy] = []
var _target_index := 0


## Empowered ultimate (gear and such; the epic cards change each ultimate
## their own way, below).
func _power() -> float:
	return GameState.get_effect("ult_power")


## Whether the fighter has a card (an effect) for their ultimate.
func _card(effect: String) -> bool:
	return GameState.has_effect(effect)


func is_full() -> bool:
	return meter >= MAX_METER


## True while an ultimate has taken over movement and punching.
func busy() -> bool:
	return mode != ""


func add(amount: float) -> void:
	if busy() or _riposte > 0.0 or spellfists > 0.0 or _shield_hits > 0 or hype > 0.0 or player.unbroken_time > 0.0:
		return  # No charging while an ultimate runs.
	var was_full := is_full()
	if amount > 0.0:
		amount *= 1.0 + GameState.get_effect("ult_gain")  # Ultimate Surge.
		if GameState.is_player_class("wise_guy"):
			amount *= MOUTH_GAIN
		elif GameState.is_player_class("berserker"):
			amount *= INFERNO_GAIN
	meter = clampf(meter + amount, 0.0, MAX_METER)
	GameState.ult_share = meter / MAX_METER
	meter_changed.emit(meter, is_full())
	if is_full() and not was_full:
		Sfx.play("tell", -2.0, 0.8)
		player.class_event.emit(equipped_name() + " READY  -  " + Controls.text("ultimate"))


## Fills the meter (tutorial).
func fill() -> void:
	meter = MAX_METER
	GameState.ult_share = 1.0
	meter_changed.emit(meter, true)


## Ultimate Surge (a card) gives a quarter back.
func _spend() -> void:
	meter = MAX_METER * 0.25 if _card("ult_surge") else 0.0
	GameState.ult_share = meter / MAX_METER
	meter_changed.emit(meter, false)
	used.emit(GameState.player_class)


# --- Charging (called by the player) ---------------------------------------------

func on_punch(kind: String, clean: bool, running: bool) -> void:
	var multiplier := player.get_combo_multiplier()
	match kind:
		"counter":
			# Answered (the Answer's card): counters fill it faster.
			add(GAIN["clean_counter" if clean else "counter"] * multiplier * (1.0 + GameState.get_effect("counter_ult")))
		"setup":
			add(GAIN.setup * multiplier)
		"hit":
			add(GAIN.running if running else GAIN.hit)


func on_dodge(clean: bool) -> void:
	add(GAIN["clean_dodge" if clean else "dodge"] * player.get_combo_multiplier())


## A clean hit drains the meter, except the Mauler's: he's built to take
## hits (Inferno even needs one), and the rest of a combo after his super
## armor shouldn't empty it.
func on_hit() -> void:
	if GameState.is_player_class("berserker"):
		return
	add(-HIT_LOSS)


# --- Firing -----------------------------------------------------------------------

func activate() -> void:
	if busy() or _riposte > 0.0:
		return
	if not is_full():
		_set_status("Ultimate not charged  (%d%%)" % int(meter), 1.2)
		return
	if _shield_hits > 0 or hype > 0.0 or player.unbroken_time > 0.0 or spellfists > 0.0:
		return
	match GameState.ultimate():
		"inferno":
			_try_inferno()
		"temporal_break":
			_start_time_stop()
		"riposte":
			_start_riposte()
		"highlight_reel":
			_start_reel()
		"big_mouth":
			_big_mouth()
		"bulwark":
			_start_shield()
		"flow_state":
			_start_flow()
		"unbroken":
			_start_unbroken()
		"hype_train":
			_start_hype()
		"the_family":
			_start_family()
		"elemental_fists":
			_start_spellfists()
		"flame_burst":
			_flame_burst()


## Called by the player before an attack resolves. Returns "" to let it through,
## or what happened instead.
func intercept_attack(attack: String, attacker: Node3D, amount := 0.0) -> String:
	if busy():
		return "dodged"
	if _riposte > 0.0:
		_riposte_dodge(attack, attacker as Enemy)
		return "dodged"
	if _shield_hits > 0:
		_shield_absorb(amount, attacker as Enemy)
		return "armored"
	return ""


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if _riposte > 0.0:
		_riposte -= real_delta
		var label := "RIPOSTE STANCE" if _riposte_counters else "FLOW STATE"
		_set_status("%s  %.1fs" % [label, maxf(_riposte, 0.0)] if _riposte > 0.0 else "")
	if _shield_hits > 0:
		_shield_time -= real_delta
		_set_status("BRIMSTONE SHIELD  %d  -  %.0fs" % [_shield_hits, maxf(_shield_time, 0.0)])
		if is_instance_valid(_shield_ring):
			_shield_ring.global_position = player.global_position + Vector3(0, 0.05, 0)
			_shield_ring.rotation.y += real_delta * 2.0
		if _shield_time <= 0.0:
			_shield_break()
	if spellfists > 0.0:
		spellfists -= real_delta
		_set_status("ELEMENTAL FISTS  %.1fs" % maxf(spellfists, 0.0) if spellfists > 0.0 else "")
	if hype > 0.0:
		hype -= real_delta
		_set_status("HYPE TRAIN  %.1fs" % maxf(hype, 0.0) if hype > 0.0 else "")
	if player.unbroken_time > 0.0:
		_set_status("UNBROKEN  %.1fs" % maxf(player.unbroken_time, 0.0))
	elif _status.begins_with("UNBROKEN"):
		_set_status("")
	if mode == "time_stop":
		_update_time_stop(real_delta)
	elif _stop_fatigue > 0.0:
		_stop_fatigue -= real_delta


# --- Wise Guy: Big Mouth --------------------------------------------------------------

func _big_mouth() -> void:
	# Big Mouth II: everyone in front of him.
	var targets := _looked_at(99 if _card("big_mouth_ii") else 1 + int(_power()))
	if targets.is_empty():
		_set_status("Nobody to yell at", 1.2)
		return
	_spend()
	say(Insults.insult())
	var duration := MOUTH_TIME + 3.0 * _power()
	for enemy in targets:
		enemy.taunt(duration)
		enemy.died.connect(_on_duel_won, CONNECT_ONE_SHOT)
	player._kick_fov(4.0)


## Tony talks: the HUD shows it, with a bleep over the censored ones.
func say(line: String) -> void:
	spoke.emit(line)
	if Insults.censored(line):
		Sfx.play("bleep", -6.0)


## An enraged monster went down: half the meter back and a KO line.
func _on_duel_won(_enemy: Enemy) -> void:
	if not is_instance_valid(player):
		return
	meter = clampf(meter + MAX_METER * MOUTH_REFUND, 0.0, MAX_METER)
	meter_changed.emit(meter, is_full())
	say(Insults.knockout())


## The monsters closest to where Tony's looking (within 60 degrees), nearest
## to the center of his view first.
func _looked_at(count: int) -> Array[Enemy]:
	var forward := -player._camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var scored := []
	for enemy in _alive_enemies():
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		var distance := to.length()
		if distance > MOUTH_RANGE or distance < 0.01:
			continue
		var angle := forward.angle_to(to / distance)
		if angle < deg_to_rad(60.0):
			scored.append([angle + distance * 0.01, enemy])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var picked: Array[Enemy] = []
	for entry in scored.slice(0, count):
		picked.append(entry[1])
	return picked


func _set_status(text: String, clear_after := 0.0) -> void:
	if text == _status:
		return
	_status = text
	status_changed.emit(text)
	if clear_after > 0.0:
		get_tree().create_timer(clear_after, false, false, true).timeout.connect(func() -> void:
			if _status == text:
				_set_status(""))


func _face(target: Node3D) -> void:
	var to := target.global_position - player.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	player.rotation.y = atan2(-to.x, -to.z)
	player._camera.rotation.x = -0.05


func _alive_enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead() and not enemy.is_queued_for_deletion():
			list.append(enemy)
	return list


func _nearest(range_limit: float) -> Enemy:
	var best: Enemy = null
	var best_distance := range_limit
	for enemy in _alive_enemies():
		var distance := enemy.global_position.distance_to(player.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, false, true).timeout


# --- Berserker: Inferno Uppercut ----------------------------------------------------

## Fires whenever the meter is full: at the Mauler's Grudge target if it's in
## reach, otherwise the nearest enemy.
func _try_inferno() -> void:
	var reach := INFERNO_LEAP * (1.0 + 0.3 * _power())
	var target: Enemy = player._grudge
	if not is_instance_valid(target) or target.is_dead() or target.global_position.distance_to(player.global_position) > reach:
		target = _nearest(reach)
	if target == null:
		_set_status("Nothing in reach", 1.2)
		return
	_spend()
	_set_status("")
	await _inferno_at(target)
	# Inferno II: then at a second monster.
	if _card("inferno_ii") and player.active:
		var second: Enemy = null
		for enemy in _alive_enemies():
			if enemy != target and enemy.global_position.distance_to(player.global_position) <= reach \
					and (second == null or enemy.global_position.distance_to(player.global_position) < second.global_position.distance_to(player.global_position)):
				second = enemy
		if second:
			await _wait(0.25)
			if is_instance_valid(second) and not second.is_dead():
				await _inferno_at(second)


## The leap and the flaming uppercut, at one monster.
func _inferno_at(target: Enemy) -> void:
	_face(target)
	# The leap: an arc up and in, trailing fire, to right in front of it.
	mode = "inferno"
	Sfx.play("whoosh", 2.0, 0.5)
	player._kick_fov(10.0)
	var from := player.global_position
	var flat := target.global_position - from
	flat.y = 0.0
	var to := from + flat - flat.normalized() * 1.1 if flat.length() > 1.1 else from
	var leap := player.create_tween()
	leap.tween_method(func(t: float) -> void:
		player.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.8
		HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.DOWN, FIRE_COLOR, 2, 1.0, true, 0.04),
		0.0, 1.0, INFERNO_LEAP_TIME)
	await leap.finished
	mode = ""
	if not is_instance_valid(target) or target.is_dead():
		return
	TimeFx.slowmo(0.4, 0.3)
	Sfx.play("heavy", 4.0, 0.5)
	player._fists.play_punch("uppercut", "right", 0.1, 0.45)
	player._animate_head("uppercut", "right", 0.1, 0.45)
	var glove := player._camera.global_position + player._camera.global_basis * Vector3(0.3, -0.4, -0.9)
	HitFx.burst(player.get_parent(), glove, Vector3.UP, FIRE_COLOR, 16, 1.5, true, 0.025)
	# Landing: a ring of fire round him scorches whoever's close.
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP * 0.2, Vector3.UP, FIRE_COLOR, 30, 6.0, true, 0.06)
	for enemy in _alive_enemies():
		if enemy != target and enemy.global_position.distance_to(player.global_position) <= INFERNO_SPLASH:
			enemy.take_hit(GameState.get_damage() * 1.5, enemy.global_position + Vector3(0, 1.0, 0), (enemy.global_position - player.global_position).normalized() * 4.0, true, "SCORCHED")
			enemy.ignite(GameState.get_damage(), INFERNO_BURN_TIME)
	await _wait(0.1)
	if not is_instance_valid(target) or target.is_dead():
		return
	var boss := target.is_boss
	player._free_punch = true
	player._land_punch("uppercut", "right", false, false, target, INFERNO_DAMAGE * (1.0 + 0.5 * _power()), "INFERNO UPPERCUT!")
	var at := target.global_position + Vector3(0, 1.2, 0)
	HitFx.burst(player.get_parent(), at, Vector3.UP, FIRE_COLOR, 40, 8.0, true, 0.06)
	HitFx.burst(player.get_parent(), at, Vector3.UP, Color(1.0, 0.6, 0.15), 20, 6.0, true, 0.03)
	player._shake = maxf(player._shake, 0.12)
	player._kick_fov(9.0)
	if not is_instance_valid(target) or target.is_dead():
		return
	target.ignite(GameState.get_damage() * 2.0, INFERNO_BURN_TIME + 2.0 * _power())
	# Wraiths float and bosses are too heavy: they just reel.
	if not boss and target.collision_mask != 0:
		target.velocity.y = INFERNO_LAUNCH * 1.4
		target.global_position.y += 0.1
	target.knock_down(INFERNO_STUN, target.global_position - player.global_position, true)


# --- Combo Master: Temporal Break --------------------------------------------------------

func _start_time_stop() -> void:
	var targets := _alive_enemies().filter(func(e: Enemy) -> bool:
		return e.global_position.distance_to(player.global_position) <= TIME_STOP_RANGE)
	if targets.is_empty():
		_set_status("No enemies near", 1.2)
		return
	_spend()
	mode = "time_stop"
	TimeFx.clear()
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	_struck.assign(targets)
	_target_index = 0
	_freeze(true)
	_stop_repeats = _stop_repeats + 1 if _stop_fatigue > 0.0 else 0
	var repeat := maxf(pow(TIME_STOP_REPEAT, _stop_repeats), TIME_STOP_REPEAT_MIN)
	_time_full = (TIME_STOP_START + 1.5 * _power()) * (1.3 if _card("temporal_break_ii") else 1.0) * repeat
	_time_left = _time_full
	_refund = TIME_STOP_REFUND
	_hits = 0
	_held.clear()
	_stop_hand = ""
	_punch_wait = 0.0
	_spark_count = 0
	_time_wave(true)
	Sfx.play("tell", 0.0, 0.5)
	Sfx.play("counter", -2.0, 0.45)
	player._kick_fov(-10.0)
	player.shake(0.08)
	player.class_event.emit("TEMPORAL BREAK!" if repeat >= 1.0 else "TEMPORAL BREAK  -%d%%" % roundi((1.0 - repeat) * 100.0))


## Freezes every enemy and everything they've thrown (bolts, arrows, fireballs).
func _freeze(on: bool) -> void:
	if on:
		_frozen.clear()
		var parents := {}
		for enemy in _alive_enemies():
			_frozen.append(enemy)
			parents[enemy.get_parent()] = true
		for parent in parents:
			for child in parent.get_children():
				if child is Area3D:
					_frozen.append(child)
		for node in _frozen:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		for node in _frozen:
			if is_instance_valid(node):
				node.process_mode = Node.PROCESS_MODE_INHERIT
		_frozen.clear()


## A hook or uppercut button pressed during Temporal Break (direct-punch schemes).
func answer_direct(type: String) -> void:
	if mode != "time_stop":
		return
	_stop_punch(_next_hand(), type)


## The hand that buys back time next (either, to start).
func _next_hand() -> String:
	return "left" if _stop_hand == "right" else "right"


func _update_time_stop(real_delta: float) -> void:
	_time_left -= real_delta * (1.0 + TIME_STOP_SPEEDUP * _hits)
	_punch_wait -= real_delta
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Pad.active:
		if Input.is_action_just_pressed("punch_left"):
			_stop_punch("left")
		elif Input.is_action_just_pressed("punch_right"):
			_stop_punch("right")
	if _time_left <= 0.0:
		_end_time_stop()
		return
	player._fists.set_next_hand("any" if _stop_hand == "" else _next_hand())
	time_stop_changed.emit(true, clampf(_time_left / maxf(_time_full, 0.01), 0.0, 1.0), "", "ALTERNATE HANDS" if _hits < 4 else "", _hits)


## A punch in stopped time: it lands on what you aim at (or the nearest
## frozen monster in reach), and its damage waits in _held, with a spark
## frozen where it hit. The other hand from last time buys back time.
func _stop_punch(hand: String, type := "") -> void:
	if _punch_wait > 0.0:
		return
	if type == "":
		type = player._punch_type_for(hand)
	var punch: Dictionary = Player.PUNCHES[type]
	_punch_wait = punch.cooldown / GameState.get_punch_speed() * 0.6
	player._fists.play_punch(type, hand, 0.05, 0.14)
	player._animate_head(type, hand, 0.05, 0.14)
	var target := _stop_target()
	if target == null:
		Sfx.play("whoosh", -8.0, 1.3)
		return
	if hand != _stop_hand:
		_time_left = minf(_time_left + _refund, _time_full)
		_refund *= TIME_STOP_REFUND_DECAY
	_stop_hand = hand
	_hits += 1
	player._last_hand = ""  # Every punch counts toward the combo, whatever the hand.
	player._last_punch_hand = hand
	player._combo_timer = GameState.get_combo_window()
	player._set_combo(player.combo + TIME_STOP_COMBO_GAIN + (1 if _card("temporal_break_ii") else 0))
	var damage: float = GameState.get_damage() * player.get_combo_multiplier() * punch.mult
	var at := target.global_position + Vector3(randf_range(-0.3, 0.3), 1.3 + randf_range(-0.35, 0.35), randf_range(-0.3, 0.3))
	var entry: Array = _held.get(target, [0.0, []])
	# Armor counts per punch, as it would have.
	entry[0] += maxf(0.0, damage - target.armor * (1.0 - GameState.get_armor_pierce()))
	if _spark_count < TIME_SPARKS:
		_spark_count += 1
		entry[1].append(_frozen_spark(at))
	_held[target] = entry
	DamagePopup.spawn(player.get_parent(), "%.1f" % damage, TIME_COLOR, 36, at)
	Sfx.play("hit", -2.0, minf(1.0 + _hits * 0.04, 2.2))
	player._shake = maxf(player._shake, 0.03)


## What a stopped-time punch lands on: the monster in the crosshair, or the
## nearest frozen one in reach and roughly ahead.
func _stop_target() -> Enemy:
	player._punch_ray.force_raycast_update()
	var aimed := player._punch_ray.get_collider() as Enemy
	if aimed and not aimed.is_dead():
		return aimed
	var forward := -player._camera.global_basis.z
	forward.y = 0.0
	var best: Enemy
	var best_distance := Player.PUNCH_REACH + 1.2
	for enemy in _struck:
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		if to.length() <= best_distance and forward.normalized().dot(to.normalized()) > 0.3:
			best = enemy
			best_distance = to.length()
	return best


static var _spark_mesh: QuadMesh


## A punch's flash, stopped mid-burst: it hangs there until time resumes.
func _frozen_spark(at: Vector3) -> MeshInstance3D:
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2.ONE * 0.55
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.albedo_texture = HitFx._radial([[0.0, Color(1, 1, 1, 1)], [0.2, Color(1, 1, 1, 0.9)], [0.45, Color(1, 1, 1, 0.25)], [1.0, Color(1, 1, 1, 0)]])
		material.albedo_color = Color(1.0, 0.9, 0.6)
		_spark_mesh.material = material
	var spark := MeshInstance3D.new()
	spark.mesh = _spark_mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.get_parent().add_child(spark)
	spark.global_position = at
	spark.scale = Vector3.ONE * randf_range(0.7, 1.3)
	return spark


func _end_time_stop() -> void:
	mode = ""
	_stop_fatigue = TIME_STOP_FATIGUE
	_freeze(false)
	time_stop_changed.emit(false, 0.0, "", "", _hits)
	player._fists.set_next_hand("")
	_time_wave(false)
	# Time snaps back: every held punch lands at once.
	var world := player.get_parent()
	for enemy in _held:
		var entry: Array = _held[enemy]
		for spark: Node3D in entry[1]:
			if is_instance_valid(spark):
				HitFx.burst(world, spark.global_position, Vector3.UP, Color(1.0, 0.85, 0.5), 6, 4.0, true, 0.05)
				spark.queue_free()
		if not is_instance_valid(enemy) or (enemy as Enemy).is_dead():
			continue
		var target := enemy as Enemy
		var at := target.global_position + Vector3(0, 1.3, 0)
		var away := target.global_position - player.global_position
		away.y = 0.0
		HitFx.burst(world, at, Vector3.UP, TIME_COLOR, 26, 6.0, true, 0.07)
		HitFx.ring(world, at, TIME_COLOR, 2.4)
		target.take_hit(entry[0], at, away.normalized() * 6.0, false, "TIME BREAK", true)
	_held.clear()
	for enemy in _struck:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.stun(TIME_STOP_STUN, true)
	_struck.clear()
	player._combo_timer = GameState.get_combo_window()
	Sfx.play("counter", 0.0, 0.6)
	Sfx.play("heavy", 0.0, 0.7)
	player._kick_fov(8.0)
	player.shake(0.14)
	player.class_event.emit("%d HITS!" % _hits)


static func time_shell_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(TIME_COLOR, 0.35)
	return material


## The wave that stops time (start) or lets it go (end): a pale shell
## sweeping out from you, or rushing back in.
func _time_wave(stopping: bool) -> void:
	var world := player.get_parent()
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	var material := time_shell_material()
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(shell)
	shell.global_position = player.global_position + Vector3(0, 1.0, 0)
	var far := Vector3.ONE * TIME_STOP_RANGE * 1.6
	shell.scale = Vector3.ONE * 0.3 if stopping else far
	var tween := shell.create_tween().set_parallel()
	tween.tween_property(shell, "scale", far if stopping else Vector3.ONE * 0.3, 0.45 if stopping else 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if stopping else Tween.EASE_IN)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5 if stopping else 0.3).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(shell.queue_free)
	HitFx.flash(world, player.global_position + Vector3(0, 1.4, 0) - player.global_basis.z, Color(TIME_COLOR, 0.9), 3.0)


# --- Counter Master: Riposte Stance -------------------------------------------------

func _start_riposte() -> void:
	_spend()
	_riposte_counters = true
	_riposte = (RIPOSTE_TIME + 2.0 * _power()) * (1.5 if _card("riposte_ii") else 1.0)
	Sfx.play("tell", 0.0, 1.1)
	player.class_event.emit("RIPOSTE STANCE")


## Slips the attack and, if the attacker is in reach, answers with a hook.
func _riposte_dodge(attack: String, attacker: Enemy) -> void:
	var answers: Array = Player.ANSWERS.get(attack, [])
	var move: String = answers[0] if not answers.is_empty() else "back_step"
	player._animate_defense(move)
	# The attack whips past: a swoosh across the view, toward the slip.
	MoveFx.swoosh(player._camera, -1.0 if move.ends_with("left") else (1.0 if move.ends_with("right") else [-1.0, 1.0].pick_random()), Color(0.4, 0.8, 1.0))
	player._on_dodge(move, true)
	if _riposte_counters and attacker and not attacker.is_dead() \
			and attacker.global_position.distance_to(player.global_position) <= RIPOSTE_RANGE:
		_riposte_counter(attacker)


func _riposte_counter(enemy: Enemy) -> void:
	await _wait(0.12)
	if not is_instance_valid(enemy) or enemy.is_dead() or not player.active:
		return
	_face(enemy)
	var hand := "right" if player._counter_side != "left" else "left"
	player._fists.play_punch("hook", hand, 0.08, 0.3)
	player._animate_head("hook", hand, 0.08, 0.3)
	await _wait(0.08)
	if is_instance_valid(enemy) and not enemy.is_dead() and player.active:
		player._land_punch("hook", hand, false, false, enemy, 1.0, "RIPOSTE!")


# --- Alternate ultimates (Abilities) ---------------------------------------------------

## The Mauler's Brimstone Shield: soaks the next hits, then bursts.
func _start_shield() -> void:
	_spend()
	# Brimstone Wall: one more hit.
	_shield_hits = SHIELD_HITS + int(_power()) + (1 if _card("brimstone_wall") else 0)
	_shield_soaked = 0.0
	_shield_time = SHIELD_TIME + 3.0 * _power()
	Sfx.play("unlock", 0.0, 0.6)
	player.class_event.emit("BRIMSTONE SHIELD")
	_shield_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.material = Enemy._glow_material(FIRE_COLOR)
	_shield_ring.mesh = ring
	_shield_ring.top_level = true
	player.add_child(_shield_ring)


func _shield_absorb(amount: float, attacker: Enemy = null) -> void:
	# A boss's punch takes two hits off it.
	_shield_hits -= 2 if attacker and attacker.is_boss else 1
	_shield_soaked += amount
	# Brimstone Wall: every soaked hit burns the attacker back.
	if _card("brimstone_wall") and attacker and not attacker.is_dead():
		attacker.take_hit(GameState.get_damage(), attacker.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "BRIMSTONE")
	Sfx.play("block", 0.0, 0.7)
	player._shake = maxf(player._shake, 0.05)
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP * 1.2, Vector3.UP, FIRE_COLOR, 12, 3.0, true, 0.04)
	if _shield_hits <= 0:
		_shield_break()


## The shield bursts: everything near takes what it soaked, and burns.
func _shield_break() -> void:
	_shield_hits = 0
	_set_status("")
	if is_instance_valid(_shield_ring):
		_shield_ring.queue_free()
	var radius := SHIELD_RADIUS + 0.5 * _power()
	var damage := _shield_soaked * (SHIELD_BLAST + 0.5 * _power()) + GameState.get_damage() * 3.0
	Sfx.play("quake", 4.0, 0.7)
	player._shake = maxf(player._shake, 0.15)
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.UP, FIRE_COLOR, 60, 10.0, true, 0.08)
	HitFx.ring(player.get_parent(), player.global_position + Vector3.UP * 0.2, Color(FIRE_COLOR, 0.8), radius)
	for enemy in _alive_enemies():
		var away := enemy.global_position - player.global_position
		if away.length() <= radius:
			enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), away.normalized() * 8.0, true, "BRIMSTONE!")
			if not enemy.is_dead():
				enemy.ignite(GameState.get_damage() * 1.5, INFERNO_BURN_TIME)
				enemy.knock_down(0.8, away, true)
	player.class_event.emit("BRIMSTONE!")


## The Answer's Flow State: every attack slips past, for a long while.
func _start_flow() -> void:
	_spend()
	_riposte_counters = false
	_riposte = FLOW_TIME + 3.0 * _power()
	Sfx.play("tell", 0.0, 1.3)
	player.class_event.emit("FLOW STATE")


## The Blur's Unbroken: every hit builds the combo, which can't drop.
func _start_unbroken() -> void:
	_spend()
	player.unbroken_time = (UNBROKEN_TIME + 2.0 * _power()) * (1.5 if _card("unbroken_ii") else 1.0)
	Sfx.play("tell", 0.0, 0.9)
	player.class_event.emit("UNBROKEN")


## The Stray's Hype Train: faster, and anything in the way goes flying.
func _start_hype() -> void:
	_spend()
	hype = HYPE_TIME + _power()
	_express = 0.0
	Sfx.play("whoosh", 4.0, 0.6)
	player._kick_fov(12.0)
	player.class_event.emit("HYPE TRAIN!")


## Express (the Stray's card): every monster bowled over keeps the train going.
var _express := 0.0


func on_bowled() -> void:
	if hype > 0.0 and _card("express") and _express < 6.0:
		_express += 1.0
		hype += 1.0


## Tony's The Family: three ghost goons brawl beside him (Family Reunion: four,
## for longer).
func _start_family() -> void:
	_spend()
	say(["Boys. Get in here.", "You wanna meet the family?", "Ey! The whole family's here!"].pick_random())
	var reunion := _card("family_reunion")
	var seconds := FAMILY_TIME + 2.0 * _power() + (5.0 if reunion else 0.0)
	var size := FAMILY_SIZE + int(_power()) + (1 if reunion else 0)
	for i in size:
		var a := TAU * i / float(size)
		var at := player.global_position + Vector3(cos(a), 0, sin(a)) * 1.5
		player.get_parent().add_child(Goon.brawler(at, seconds, GameState.get_damage() * (0.8 + 0.2 * _power())))
	player.class_event.emit("THE FAMILY")


# --- The Catalyst ---------------------------------------------------------------------

func _start_spellfists() -> void:
	_spend()
	spellfists = SPELL_TIME + GameState.get_effect("spell_time") + 2.0 * _power()
	Sfx.play("fire", 0.0, 0.7)
	player._kick_fov(6.0)
	player.class_event.emit("ELEMENTAL FISTS")


## A punch landed during Elemental Fists: each element rolls on its own.
func on_landed(target: Enemy, dealt: float, hand: String) -> void:
	# Untouchable (the Answer's card): Flow State grows with every punch.
	if _riposte > 0.0 and not _riposte_counters and _card("untouchable_flow"):
		_riposte += 0.2
	if spellfists <= 0.0 or target == null or not is_instance_valid(target):
		return
	var chance := SPELL_CHANCE
	# Elemental Fists II: 25% each, and every spell finds a second monster.
	var twice := _card("elemental_fists_ii")
	if twice:
		chance = SPELL_CHANCE_MAX
	var other: Enemy = null
	if twice:
		for enemy in _alive_enemies():
			if enemy != target and enemy.global_position.distance_to(target.global_position) <= 8.0 \
					and (other == null or enemy.global_position.distance_to(target.global_position) < other.global_position.distance_to(target.global_position)):
				other = enemy
	var strength := GameState.get_damage() * (1.0 + 0.25 * _power())
	var camera: Camera3D = player._camera
	var side := -1.0 if hand == "left" else 1.0
	var fist := camera.global_position + camera.global_basis * Vector3(0.25 * side, -0.3, -0.6)
	var ahead := -camera.global_basis.z
	ahead.y = 0.0
	# Each spell flares the throwing hand's runes in its color.
	var colors := Fists.POWER_COLORS
	if randf() < chance:
		player._fists.flash_runes(colors.sigil_fire, hand)
		SpellBolt.fling(player.get_parent(), fist, ahead, "fire", strength * SPELL_FIRE, target)
		if other:
			SpellBolt.fling(player.get_parent(), fist, ahead, "fire", strength * SPELL_FIRE, other)
	if randf() < chance:
		player._fists.flash_runes(colors.sigil_frost, hand)
		SpellBolt.fling(player.get_parent(), fist, ahead, "ice", strength * SPELL_ICE, target)
		if other:
			SpellBolt.fling(player.get_parent(), fist, ahead, "ice", strength * SPELL_ICE, other)
	if randf() < chance and not target.is_dead():
		player._fists.flash_runes(colors.sigil_storm, hand)
		Powers.chain_lightning(target, strength * SPELL_LIGHTNING, SPELL_JUMPS)
	if randf() < chance and dealt > 0.0:
		player._fists.flash_runes(colors.sigil_blood, hand)
		var amount := maxf(1.0, dealt * SPELL_HEAL)
		player.heal(amount)
		var at := target.global_position + Vector3(0, 1.2, 0)
		HitFx.burst(player.get_parent(), at, (player.global_position - at).normalized(), Color(0.85, 0.05, 0.08), 16, 4.0, true, 0.05)
		_blood_stream(at, fist)
		DamagePopup.spawn(player.get_parent(), "+%d" % roundi(amount), Color(0.95, 0.2, 0.25), 36, at + Vector3(0, 0.5, 0))


## The blood heal: drops of blood stream from the monster back into the fist.
func _blood_stream(from: Vector3, to: Vector3) -> void:
	var world := player.get_parent()
	var blood := Enemy._glow_material(Color(0.85, 0.05, 0.1))
	for i in 7:
		var drop := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * (0.09 - i * 0.006)
		mesh.material = blood
		drop.mesh = mesh
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(drop)
		drop.global_position = from
		var bend := Vector3(randf_range(-0.4, 0.4), randf_range(0.2, 0.6), randf_range(-0.4, 0.4))
		var tween := drop.create_tween()
		tween.tween_interval(i * 0.035)
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(player):
				drop.global_position = from.lerp(to, t) + bend * sin(t * PI), 0.0, 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(drop.queue_free)


## Flame Burst: fire bursts out in a ring; everything in it is hit, burns and
## is stunned (bosses for BURST_STUN, the rest knocked down).
## Flame Burst II: it goes off again a moment later.
func _flame_burst() -> void:
	_spend()
	_burst_ring()
	if _card("flame_burst_ii"):
		await _wait(0.6)
		if is_instance_valid(player) and player.active:
			_burst_ring()


func _burst_ring() -> void:
	var world := player.get_parent()
	var center := player.global_position
	var radius := BURST_RADIUS + _power()
	var damage := GameState.get_damage() * BURST_DAMAGE * (1.0 + 0.25 * _power())
	var burn := GameState.get_damage() * BURST_BURN
	TimeFx.hitstop(0.09)
	Sfx.play("fire", 6.0, 0.5)
	Sfx.play("quake", 4.0, 0.6)
	Sfx.play("heavy", 4.0, 0.5)
	player.shake(0.3)
	player._kick_fov(18.0)
	_burst_fx(world, center, radius)
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length() > radius:
			continue
		var away := offset.normalized() if offset.length() > 0.1 else Vector3.FORWARD
		# Closer in, thrown harder.
		var force := lerpf(1.0, 0.55, offset.length() / radius)
		# Knocked out: the full fling.
		enemy.finisher = {"type": "haymaker", "hand": "right", "level": 1, "dir": away, "player": player}
		enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), away * BURST_LAUNCH * force, true, "FLAME BURST")
		if enemy.is_dead():
			continue
		enemy.finisher = {}
		enemy.ignite(burn, BURST_BURN_TIME)
		if enemy.is_boss:
			enemy.stun(BURST_STUN, true, true)
		else:
			# Blasted up and away, and down when it lands.
			enemy.velocity.y = BURST_LIFT * force
			enemy.knock_down(1.6, away, true)
	player.class_event.emit("FLAME BURST")


## The explosion: a fireball swelling out of you, a shockwave racing across the
## ground to the edge, flame pillars around it, debris and smoke thrown out,
## and a flash that lights the whole place.
func _burst_fx(world: Node, center: Vector3, radius: float) -> void:
	var web := Settings.use_web_profile()
	var light := OmniLight3D.new()
	light.light_color = BURST_COLOR
	light.light_energy = 14.0
	light.omni_range = radius * 2.2
	world.add_child(light)
	light.global_position = center + Vector3(0, 2.0, 0)
	var dim := light.create_tween()
	dim.tween_property(light, "light_energy", 0.0, 0.9).set_ease(Tween.EASE_OUT)
	dim.tween_callback(light.queue_free)
	# The fireball: a hot core inside a swelling orange ball.
	for layer in [[BURST_COLOR, 1.0, 0.75], [Color(1.0, 0.85, 0.4), 0.6, 0.95]]:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		var hot := Telegraphs.material(Color(layer[0], layer[2]))
		hot.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sphere.material = hot
		ball.mesh = sphere
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(ball)
		ball.global_position = center + Vector3(0, 1.0, 0)
		ball.scale = Vector3.ONE * 0.3
		var size: float = radius * 0.55 * float(layer[1])
		var grow := ball.create_tween().set_parallel()
		grow.tween_property(ball, "scale", Vector3(size, size * 0.8, size), 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		grow.tween_property(hot, "albedo_color:a", 0.0, 0.55).set_delay(0.15)
		grow.chain().tween_callback(ball.queue_free)
	# The shockwave across the ground.
	var wave := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 6
	var wave_material := Telegraphs.material(Color(1.0, 0.7, 0.3, 0.9))
	wave_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material = wave_material
	wave.mesh = ring
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(wave)
	wave.global_position = center + Vector3(0, 0.12, 0)
	wave.scale = Vector3(0.5, 0.3, 0.5)
	var spread := wave.create_tween().set_parallel()
	spread.tween_property(wave, "scale", Vector3(radius, 0.3, radius), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	spread.tween_property(wave_material, "albedo_color:a", 0.0, 0.5).set_delay(0.15)
	spread.chain().tween_callback(wave.queue_free)
	# Flame pillars round the blast, a beat after it.
	var pillars := 8 if web else 12
	for i in pillars:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / pillars + randf() * 0.3)
		var spot := center + direction * radius * randf_range(0.45, 0.8)
		var pillar := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 0.25
		column.bottom_radius = 0.6
		column.height = 1.0
		column.radial_segments = 8
		var flame := Telegraphs.material(Color(1.0, 0.55, 0.15, 0.8))
		flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		column.material = flame
		pillar.mesh = column
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(pillar)
		pillar.global_position = spot
		pillar.scale = Vector3(1, 0.05, 1)
		var height := randf_range(3.5, 5.5)
		var rise := pillar.create_tween()
		rise.tween_interval(0.08 + i * 0.015)
		rise.tween_property(pillar, "scale", Vector3(1, height, 1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.parallel().tween_property(pillar, "position:y", spot.y + height * 0.5, 0.18)
		rise.tween_property(flame, "albedo_color:a", 0.0, 0.4)
		rise.tween_callback(pillar.queue_free)
		HitFx.burst(world, spot + Vector3(0, 0.3, 0), Vector3.UP, BURST_COLOR, 5 if web else 9, 6.0, true, 0.09)
	# Embers and smoke thrown outward, and chunks of ground.
	for i in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		HitFx.burst(world, center + direction * 1.2 + Vector3(0, 0.6, 0), direction + Vector3.UP * 0.5,
				Color(1.0, 0.75, 0.25) if i % 2 == 0 else Color(0.25, 0.22, 0.2), 6, 9.0, i % 2 == 0, 0.09)
	for i in (6 if web else 12):
		var rock := MeshInstance3D.new()
		var chunk := BoxMesh.new()
		var size := randf_range(0.12, 0.3)
		chunk.size = Vector3(size, size * 0.7, size)
		chunk.material = Look.block_material(Color(0.3, 0.26, 0.22), 0.0)
		rock.mesh = chunk
		world.add_child(rock)
		var direction := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		var from := center + direction * randf_range(0.5, 2.0)
		rock.global_position = from
		var land := from + direction * randf_range(3.0, radius)
		var arc := rock.create_tween()
		arc.tween_method(func(t: float) -> void:
			rock.global_position = from.lerp(land, t) + Vector3.UP * sin(t * PI) * 3.0
			rock.rotation += Vector3(0.2, 0.15, 0.1), 0.0, 1.0, randf_range(0.6, 0.9))
		arc.tween_property(rock, "scale", Vector3.ONE * 0.01, 0.3)
		arc.tween_callback(rock.queue_free)
	HitFx.flash(world, center + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.5), 6.0)


# --- Free Runner: Highlight Reel ----------------------------------------------------

## Up to REEL_TARGETS enemies in front and in sight, nearest first.
func _reel_targets() -> Array[Enemy]:
	var forward := -player._camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var eye := player._camera.global_position
	var space := player.get_world_3d().direct_space_state
	var found: Array[Enemy] = []
	for enemy in _alive_enemies():
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		if to.length() > REEL_RANGE or (to.length() > 1.5 and to.normalized().dot(forward) < 0.25):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, enemy.global_position + Vector3(0, 1.2, 0), 1 | Scenery.LAYER)
		query.exclude = [player.get_rid()]
		if not space.intersect_ray(query).is_empty():
			continue  # Behind a wall.
		found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	# Director's Cut: three more.
	return found.slice(0, REEL_TARGETS + 3 * int(_power()) + (3 if _card("directors_cut") else 0))


func _start_reel() -> void:
	var targets := _reel_targets()
	if targets.is_empty():
		_set_status("No targets in view", 1.2)
		return
	_spend()
	mode = "reel"
	player.class_event.emit("HIGHLIGHT REEL!")
	Sfx.play("tell", 0.0, 1.4)
	for i in targets.size():
		var target := targets[i]
		if not is_instance_valid(target) or target.is_dead() or not player.active:
			continue
		var last := i == targets.size() - 1
		await _dash_to(target, last)
		if not is_instance_valid(target) or target.is_dead():
			continue
		var hand := "left" if i % 2 == 0 else "right"
		var type := "hook" if last else ("jab" if hand == "left" else "cross")
		player._fists.play_punch(type, hand, 0.06, 0.25)
		player._animate_head(type, hand, 0.06, 0.25)
		await _wait(0.06)
		if not is_instance_valid(target) or target.is_dead():
			continue
		player._free_punch = true
		if last:
			player._land_punch(type, hand, false, false, target, REEL_FINISHER * (1.0 + 0.3 * _power()), "HAYMAKER!")
			if is_instance_valid(target) and not target.is_dead():
				target.knock_down(1.2, target.global_position - player.global_position, true)
			player._shake = maxf(player._shake, 0.1)
			player._kick_fov(8.0)
		else:
			player._land_punch(type, hand, false, false, target, REEL_DAMAGE * (1.0 + 0.3 * _power()), "HIGHLIGHT!")
		# Director's Cut: every hit stuns.
		if _card("directors_cut") and is_instance_valid(target) and not target.is_dead():
			target.stun(1.0, true)
		if is_instance_valid(target):
			HitFx.burst(player.get_parent(), target.global_position + Vector3(0, 1.3, 0), Vector3.UP, LIGHTNING_COLOR, 24, 6.0, true, 0.05)
		await _wait(REEL_PAUSE)
	mode = ""


## Streaks to just in front of the target, leaving lightning behind. The
## finisher leaps in.
func _dash_to(target: Enemy, leap: bool) -> void:
	var from := player.global_position
	var to := target.global_position - from
	to.y = 0.0
	var dest := target.global_position - to.normalized() * REEL_STAND_OFF if to.length() > REEL_STAND_OFF else from
	dest.y = maxf(from.y, target.global_position.y)
	_face(target)
	Sfx.play("whoosh", 0.0, 1.5)
	# Waist height, so it streaks past below the camera rather than through it.
	var ahead := (dest - from).normalized() * 0.5
	_lightning(from + ahead + Vector3(0, 0.8, 0), dest + Vector3(0, 0.8, 0))
	var tween := player.create_tween()
	tween.set_ignore_time_scale(true)
	if leap:
		var top := (from + dest) / 2.0 + Vector3(0, 1.2, 0)
		tween.tween_property(player, "global_position", top, REEL_DASH_TIME * 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(player, "global_position", dest, REEL_DASH_TIME * 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		tween.tween_property(player, "global_position", dest, REEL_DASH_TIME)
	await tween.finished


## A jagged glowing bolt between two points that flickers and fades.
func _lightning(from: Vector3, to: Vector3) -> void:
	var bolt := Node3D.new()
	player.get_parent().add_child(bolt)
	var material := Enemy._glow_material(LIGHTNING_COLOR)
	var core := Enemy._glow_material(Color(0.9, 0.97, 1.0))
	var segments := maxi(4, int(from.distance_to(to) / 0.6))
	var side := (to - from).cross(Vector3.UP).normalized()
	var points: Array[Vector3] = [from]
	for i in range(1, segments):
		var t := float(i) / segments
		points.append(from.lerp(to, t) + side * randf_range(-0.3, 0.3) + Vector3.UP * randf_range(-0.25, 0.25))
	points.append(to)
	for i in segments:
		for layer in [[0.045, material], [0.018, core]]:
			var a := points[i]
			var b := points[i + 1]
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(layer[0], layer[0], a.distance_to(b) + 0.04)
			box.material = layer[1]
			mesh.mesh = box
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bolt.add_child(mesh)
			mesh.global_position = (a + b) / 2.0
			if not a.is_equal_approx(b):
				mesh.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var light := OmniLight3D.new()
	light.light_color = LIGHTNING_COLOR
	light.light_energy = 4.0
	light.omni_range = 5.0
	bolt.add_child(light)
	light.global_position = (from + to) / 2.0
	HitFx.burst(player.get_parent(), from, Vector3.UP, LIGHTNING_COLOR, 14, 3.0, true, 0.04)
	var tween := bolt.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(bolt, "scale", Vector3(1, 1, 1), 0.12)
	tween.tween_callback(func() -> void: bolt.visible = false)
	tween.tween_interval(0.04)
	tween.tween_callback(func() -> void: bolt.visible = true)
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(bolt.queue_free)
