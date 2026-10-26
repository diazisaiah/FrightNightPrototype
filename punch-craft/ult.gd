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
const TIME_STOP_START := 6.0
const TIME_STOP_REFUND := 0.5
const TIME_STOP_REFUND_DECAY := 0.9
## Each hit makes the clock run this much faster.
const TIME_STOP_SPEEDUP := 0.12
const TIME_STOP_MISS := 0.5
const TIME_STOP_RANGE := 12.0
const TIME_STOP_COMBO_GAIN := 2
const TIME_STOP_STUN := 1.0
const PROMPTS := [
	{"type": "jab", "hand": "left", "keys": "LMB", "name": "JAB"},
	{"type": "cross", "hand": "right", "keys": "RMB", "name": "CROSS"},
	{"type": "hook", "hand": "left", "keys": "SHIFT + LMB", "name": "LEFT HOOK"},
	{"type": "hook", "hand": "right", "keys": "SHIFT + RMB", "name": "RIGHT HOOK"},
	{"type": "uppercut", "hand": "left", "keys": "CTRL + LMB", "name": "LEFT UPPERCUT"},
	{"type": "uppercut", "hand": "right", "keys": "CTRL + RMB", "name": "RIGHT UPPERCUT"},
]
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
const BURST_RADIUS := 6.0
const BURST_DAMAGE := 5.0
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
var _refund := 0.0
var _hits := 0
var _prompt: Dictionary = {}
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
	target.knock_down(INFERNO_STUN, target.global_position - player.global_position)


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
	_time_left = (TIME_STOP_START + 1.5 * _power()) * (1.3 if _card("temporal_break_ii") else 1.0)
	_refund = TIME_STOP_REFUND
	_hits = 0
	_next_prompt()
	Sfx.play("tell", 0.0, 0.5)
	player.class_event.emit("TEMPORAL BREAK!")


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


func _next_prompt() -> void:
	# Prompt keys follow the control scheme (Controls); PROMPTS is the classic set.
	var options := Controls.qte_prompts().filter(func(p: Dictionary) -> bool: return p.name != _prompt.get("name", ""))
	_prompt = options.pick_random()


## A hook or uppercut button pressed during Temporal Break (direct-punch schemes).
func answer_direct(type: String) -> void:
	if mode != "time_stop":
		return
	_answer_prompt("left" if player._last_punch_hand == "right" else "right", type)


func _update_time_stop(real_delta: float) -> void:
	_time_left -= real_delta * (1.0 + TIME_STOP_SPEEDUP * _hits)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Pad.active:
		if Input.is_action_just_pressed("punch_left"):
			_answer_prompt("left")
		elif Input.is_action_just_pressed("punch_right"):
			_answer_prompt("right")
	if _time_left <= 0.0:
		_end_time_stop()
		return
	time_stop_changed.emit(true, clampf(_time_left / TIME_STOP_START, 0.0, 1.0), _prompt.keys, _prompt.name, _hits)


func _answer_prompt(hand: String, type := "") -> void:
	if type == "":
		type = player._punch_type_for(hand)
	if type != _prompt.type or (hand != _prompt.hand and _prompt.hand != "any"):
		_time_left -= TIME_STOP_MISS
		Sfx.play("block", -2.0, 0.7)
		player._shake = maxf(player._shake, 0.04)
		return
	var target := _next_target()
	player._fists.play_punch(type, hand, 0.05, 0.14)
	player._animate_head(type, hand, 0.05, 0.14)
	_hits += 1
	player._last_hand = ""  # Every prompt counts toward the combo, whatever the hand.
	player._last_punch_hand = hand
	player._combo_timer = GameState.get_combo_window()
	player._set_combo(player.combo + TIME_STOP_COMBO_GAIN + (1 if _card("temporal_break_ii") else 0))
	_time_left += _refund
	_refund *= TIME_STOP_REFUND_DECAY
	Sfx.play("hit", 0.0, minf(1.0 + _hits * 0.04, 2.2))
	if target:
		var punch: Dictionary = Player.PUNCHES[type]
		var damage: float = GameState.get_damage() * player.get_combo_multiplier() * punch.mult
		var at := target.global_position + Vector3(0, 1.3, 0) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), 0)
		target.take_hit(damage, at, Vector3.ZERO, false)
		HitFx.burst(player.get_parent(), at, Vector3.UP, Color(1, 0.8, 0.3), 12, 4.0, true, 0.05)
	_next_prompt()


## Punches go round the frozen enemies, nearest first.
func _next_target() -> Enemy:
	for i in _struck.size():
		var enemy := _struck[(_target_index + i) % _struck.size()]
		if is_instance_valid(enemy) and not enemy.is_dead():
			_target_index = (_target_index + i + 1) % _struck.size()
			return enemy
	return null


func _end_time_stop() -> void:
	mode = ""
	_freeze(false)
	time_stop_changed.emit(false, 0.0, "", "", _hits)
	for enemy in _struck:
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy.stun(TIME_STOP_STUN)
	_struck.clear()
	player._combo_timer = GameState.get_combo_window()
	Sfx.play("counter", 0.0, 0.6)
	player._kick_fov(6.0)
	player.class_event.emit("%d HITS!" % _hits)


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
	# Brimstone Wall: twice the hits.
	_shield_hits = (SHIELD_HITS + int(_power())) * (2 if _card("brimstone_wall") else 1)
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
	_shield_hits -= 1
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
				enemy.knock_down(0.8, away)
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


## Flame Burst: fire bursts out in a ring; everything in it is hit and burns.
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
	Sfx.play("fire", 4.0, 0.6)
	Sfx.play("quake", -2.0, 0.8)
	player.shake(0.08)
	player._kick_fov(10.0)
	HitFx.flash(world, center + Vector3(0, 1.0, 0), BURST_COLOR, 3.0)
	for i in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0)
		for ring in [0.35, 0.7, 1.0]:
			HitFx.burst(world, center + direction * radius * ring + Vector3(0, 0.3, 0), direction + Vector3.UP * 0.8,
					BURST_COLOR if ring < 1.0 else Color(1.0, 0.75, 0.25), 6, 4.0, true, 0.08)
	for node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - center
		offset.y = 0.0
		if offset.length() > radius:
			continue
		enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), offset.normalized() * 6.0, true, "FLAME BURST")
		enemy.ignite(burn, BURST_BURN_TIME)
	player.class_event.emit("FLAME BURST")


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
		var query := PhysicsRayQueryParameters3D.create(eye, enemy.global_position + Vector3(0, 1.2, 0), 1)
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
				target.knock_down(1.2, target.global_position - player.global_position)
			player._shake = maxf(player._shake, 0.1)
			player._kick_fov(8.0)
		else:
			player._land_punch(type, hand, false, false, target, REEL_DAMAGE * (1.0 + 0.3 * _power()), "HIGHLIGHT!")
		# Director's Cut: every hit stuns.
		if _card("directors_cut") and is_instance_valid(target) and not target.is_dead():
			target.stun(1.0)
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
