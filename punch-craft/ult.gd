class_name Ult
extends Node
## Class ultimates and the meter that charges them. Reading the fight fills it
## fastest (dodges, counters, set-up heavies, combos); wild jabs barely do and
## getting hit drains it. The configured ultimate action fires it when full:
##   Berserker       Inferno Uppercut: with a full meter super armor's counter
##                   window is longer; using the ultimate in that window throws a flaming
##                   uppercut that launches the enemy and sets it alight.
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
}
## One line each, for the class picker.
const DESCRIPTIONS := {
	"berserker": "With a full meter, take a hit on super armor, then use your ultimate: a flaming uppercut that launches the enemy and sets it alight.",
	"combo_master": "Stop time. Throw the punches shown as fast as you can: each one lands, grows your combo and buys a little more time.",
	"counter_master": "Riposte Stance: for 4 seconds every attack is slipped for you and answered with a counter hook.",
	"free_runner": "Streak like lightning from enemy to enemy in view, punching each, and finish with a leaping haymaker.",
	"wise_guy": "Insult the monster you're looking at. It comes only for you, hits 50% harder and takes double damage from you. Refills fast.",
}
const FIRE_COLOR := Color(1.0, 0.3, 0.05)
const LIGHTNING_COLOR := Color(0.6, 0.85, 1.0)

# Berserker
const INFERNO_WINDOW_SCALE := 2.0
const INFERNO_DAMAGE := 3.0
const INFERNO_RANGE := 3.5
const INFERNO_LAUNCH := 7.0
const INFERNO_STUN := 1.6
const INFERNO_BURN_TIME := 4.0
# Combo Master
const TIME_STOP_START := 3.0
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
var _inferno_attacker: Enemy
var _status := ""
# Temporal Break
var _time_left := 0.0
var _refund := 0.0
var _hits := 0
var _prompt: Dictionary = {}
var _frozen: Array[Node] = []
var _struck: Array[Enemy] = []
var _target_index := 0


## 1 with the fighter's sigil ultimate upgrade (the "... II" skill), else 0.
func _power() -> float:
	return GameState.get_effect("ult_power")


func is_full() -> bool:
	return meter >= MAX_METER


## True while an ultimate has taken over movement and punching.
func busy() -> bool:
	return mode != ""


func add(amount: float) -> void:
	if busy() or _riposte > 0.0:
		return  # No charging while an ultimate runs.
	var was_full := is_full()
	if amount > 0.0:
		amount *= 1.0 + GameState.get_effect("ult_gain")  # Ultimate Surge.
		if GameState.is_player_class("wise_guy"):
			amount *= MOUTH_GAIN
	meter = clampf(meter + amount, 0.0, MAX_METER)
	meter_changed.emit(meter, is_full())
	if is_full() and not was_full:
		Sfx.play("tell", -2.0, 0.8)
		player.class_event.emit(NAMES[GameState.player_class] + " READY  -  " + Controls.text("ultimate"))


## Fills the meter (tutorial).
func fill() -> void:
	meter = MAX_METER
	meter_changed.emit(meter, true)


func _spend() -> void:
	meter = 0.0
	meter_changed.emit(meter, false)
	used.emit(GameState.player_class)


# --- Charging (called by the player) ---------------------------------------------

func on_punch(kind: String, clean: bool, running: bool) -> void:
	var multiplier := player.get_combo_multiplier()
	match kind:
		"counter":
			add(GAIN["clean_counter" if clean else "counter"] * multiplier)
		"setup":
			add(GAIN.setup * multiplier)
		"hit":
			add(GAIN.running if running else GAIN.hit)


func on_dodge(clean: bool) -> void:
	add(GAIN["clean_dodge" if clean else "dodge"] * player.get_combo_multiplier())


func on_hit() -> void:
	add(-HIT_LOSS)


# --- Firing -----------------------------------------------------------------------

func activate() -> void:
	if busy() or _riposte > 0.0:
		return
	if not is_full():
		_set_status("Ultimate not charged  (%d%%)" % int(meter), 1.2)
		return
	match GameState.player_class:
		"berserker":
			_try_inferno()
		"combo_master":
			_start_time_stop()
		"counter_master":
			_start_riposte()
		"free_runner":
			_start_reel()
		"wise_guy":
			_big_mouth()


## Called by the player before an attack resolves. Returns "" to let it through,
## or what happened instead.
func intercept_attack(attack: String, attacker: Node3D) -> String:
	if busy():
		return "dodged"
	if _riposte > 0.0:
		_riposte_dodge(attack, attacker as Enemy)
		return "dodged"
	return ""


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if _riposte > 0.0:
		_riposte -= real_delta
		_set_status("RIPOSTE STANCE  %.1fs" % maxf(_riposte, 0.0) if _riposte > 0.0 else "")
	if mode == "time_stop":
		_update_time_stop(real_delta)


# --- Wise Guy: Big Mouth --------------------------------------------------------------

func _big_mouth() -> void:
	var targets := _looked_at(1 + int(_power()))
	if targets.is_empty():
		_set_status("Nobody to yell at", 1.2)
		return
	_spend()
	say(Insults.insult())
	var duration := MOUTH_TIME + GameState.get_effect("insult_time") + 3.0 * _power()
	for enemy in targets:
		enemy.taunt(duration)
		enemy.died.connect(_on_duel_won, CONNECT_ONE_SHOT)
	player._kick_fov(4.0)


## Tony talks: the HUD shows it, with a bleep over the censored ones.
func say(line: String) -> void:
	spoke.emit(line)
	if Insults.censored(line):
		Sfx.play("bleep", -6.0)


## An enraged monster went down: half the meter back, a KO line, and Hustle's coins.
func _on_duel_won(enemy: Enemy) -> void:
	if not is_instance_valid(player):
		return
	meter = clampf(meter + MAX_METER * MOUTH_REFUND, 0.0, MAX_METER)
	meter_changed.emit(meter, is_full())
	say(Insults.knockout())
	var hustle := GameState.get_effect("hustle")
	if hustle > 0.0 and is_instance_valid(enemy):
		GameState.add_resource("coins", roundi(enemy.coin_reward * hustle))


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

## Super armor just took a hit: with a full meter, the counter window doubles.
func on_super_armor(attacker: Node3D) -> void:
	if not GameState.is_player_class("berserker") or not is_full():
		return
	_inferno_attacker = attacker as Enemy
	player._counter_timer *= INFERNO_WINDOW_SCALE
	HitFx.burst(player.get_parent(), player.global_position + Vector3(0, 1.2, 0), Vector3.UP, FIRE_COLOR, 24, 3.0, true, 0.06)
	var key := Controls.text("ultimate")
	player.class_event.emit("INFERNO!  Press " + key)
	_set_status("INFERNO READY  -  press " + key, player._counter_timer)


func _try_inferno() -> void:
	if not (player.is_counter_ready() and player._counter_from_armor):
		_set_status("Take a hit on super armor, then press " + Controls.text("ultimate"), 2.0)
		return
	var target := _inferno_attacker
	if not is_instance_valid(target) or target.is_dead() \
			or target.global_position.distance_to(player.global_position) > INFERNO_RANGE * (1.0 + 0.4 * _power()):
		target = _nearest(INFERNO_RANGE * (1.0 + 0.4 * _power()))
	if target == null:
		_set_status("Nothing in reach", 1.2)
		return
	_spend()
	_set_status("")
	_face(target)
	TimeFx.slowmo(0.45, 0.25)
	Sfx.play("heavy", 2.0, 0.6)
	player._fists.play_punch("uppercut", "right", 0.1, 0.45)
	player._animate_head("uppercut", "right", 0.1, 0.45)
	var glove := player._camera.global_position + player._camera.global_basis * Vector3(0.3, -0.4, -0.9)
	HitFx.burst(player.get_parent(), glove, Vector3.UP, FIRE_COLOR, 16, 1.5, true, 0.025)
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
		target.velocity.y = INFERNO_LAUNCH
		target.global_position.y += 0.1
	target.stun(INFERNO_STUN)


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
	_time_left = TIME_STOP_START + 1.5 * _power()
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
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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
	player._set_combo(player.combo + TIME_STOP_COMBO_GAIN)
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
	_riposte = RIPOSTE_TIME + 2.0 * _power()
	Sfx.play("tell", 0.0, 1.1)
	player.class_event.emit("RIPOSTE STANCE")


## Slips the attack and, if the attacker is in reach, answers with a hook.
func _riposte_dodge(attack: String, attacker: Enemy) -> void:
	var answers: Array = Player.ANSWERS.get(attack, [])
	var move: String = answers[0] if not answers.is_empty() else "back_step"
	player._animate_defense(move)
	player._on_dodge(move, true)
	if attacker and not attacker.is_dead() \
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
	return found.slice(0, REEL_TARGETS + 3 * int(_power()))


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
			player._shake = maxf(player._shake, 0.1)
			player._kick_fov(8.0)
		else:
			player._land_punch(type, hand, false, false, target, REEL_DAMAGE * (1.0 + 0.3 * _power()), "HIGHLIGHT!")
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
