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
	"berserker": "Leap at the nearest monster with a flaming uppercut that launches it and sets it alight.",
	"combo_master": "Time stops. Your punches land when it resumes, all at once. Alternate hands to buy back time.",
	"counter_master": "For a few seconds every attack is slipped for you and answered with a counter hook.",
	"free_runner": "Dash from monster to monster in view, punching each, and finish with a leaping haymaker.",
	"wise_guy": "Insult the monster you're looking at: it comes only for you, hits harder and takes double from you.",
	"elementalist": "For 10s every punch can throw a fireball, an icicle, lightning or a blood heal.",
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
## Inferno II: the flame shockwave off the hit (radius, burn seconds).
const INFERNO_II_RADIUS := 5.0
const INFERNO_II_BURN := 3.0
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
## Temporal Break: a hit grows the combo by 1 (every other one by 2 with the epic).
const TIME_STOP_COMBO_GAIN := 1
const TIME_STOP_STUN := 1.0
const TIME_COLOR := Color(0.65, 0.85, 1.0)
## Impact sparks left hanging in stopped time, at most.
const TIME_SPARKS := 60
# Counter Master
## Riposte Stance (2026-11-06: 1.5s longer, per the user).
const RIPOSTE_TIME := 5.5
# Alternate ultimates (Abilities, 2026-10-24).
const SHIELD_HITS := 3
const SHIELD_TIME := 12.0
const SHIELD_RADIUS := 4.0
const SHIELD_BLAST := 2.0
## Aura Farm (was Flow State, 2026-11-06): how long it lasts, and what dodges heal (share of max HP).
const FARM_TIME := 15.0
const FARM_HEAL := Vector2(0.01, 0.02)
const FARM_HEAL_II := Vector2(0.02, 0.03)
## Cash Out (was Unbroken): the least combo it needs, and how long its shield lasts.
const CASH_MIN := 5
## The start of the shield, in percent of max knuckle HP (8 with Cash Out II); every hit landed in the combo adds 1%.
const CASH_BASE := 5.0
const CASH_BASE_II := 8.0
const CASH_TIME := 15.0
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
## Aura Farm's seconds left, and whether the Riposte stance is playing as a third-person shot.
var _farm := 0.0
## Cash Out: the shield left (knuckle HP) and its seconds.
var _cash := 0.0
var _cash_time := 0.0
var _cash_max := 1.0
var _field: AuraField
var _riposte_shot := false
## Which stance clip the body is in (-1 none, 0 still, 1 walking) and when a reaction clip ends.
var _stance_state := -1
var _reaction_until := 0.0
## Brimstone Shield: hits left, damage soaked, seconds left.
var _shield_hits := 0
var _shield_soaked := 0.0
var _shield_time := 0.0
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


## Punches, dodges and the ultimate key are locked: an ultimate has the controls,
## or the Riposte Stance is a shot (you can still walk and look in that one).
func input_locked() -> bool:
	return busy() or (_riposte_shot and player.cinematic)


func add(amount: float) -> void:
	if busy() or _riposte > 0.0 or _farm > 0.0 or _cash_time > 0.0 or spellfists > 0.0 or _shield_hits > 0 or hype > 0.0 or player.unbroken_time > 0.0:
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
	# Haggler (Dead Money Coin): keeps a share of the meter (stacks with Surge).
	meter = minf(MAX_METER, meter + MAX_METER * GameState.get_effect("haggler"))
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
	if _farm > 0.0:
		var share: Vector2 = FARM_HEAL_II if _card("untouchable_flow") else FARM_HEAL
		var healed := player.max_knuckles * (share.y if clean else share.x)
		player.heal(healed)
		DamagePopup.spawn(player.get_parent(), "+%d" % roundi(healed), Color(0.4, 1.0, 0.65), 40, player.global_position + player._flat_forward() + Vector3(0, 1.7, 0))
		HitFx.burst(player.get_parent(), player.global_position + Vector3.UP * 1.0, Vector3.UP, Color(0.4, 1.0, 0.65), 8, 2.5, true, 0.04)


## A clean hit drains the meter, except the Mauler's: he's built to take
## hits (Inferno even needs one), and the rest of a combo after his super
## armor shouldn't empty it.
func on_hit() -> void:
	if GameState.is_player_class("berserker"):
		return
	add(-HIT_LOSS)


# --- Firing -----------------------------------------------------------------------

func activate() -> void:
	if busy() or _riposte > 0.0 or _farm > 0.0:
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
	if _riposte > 0.0:
		_riposte_dodge(attack, attacker as Enemy)
		return "dodged"
	if busy():
		return "dodged"
	if _shield_hits > 0:
		_shield_absorb(amount, attacker as Enemy)
		return "armored"
	return ""


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.01)
	if _riposte > 0.0:
		_riposte -= real_delta
		_set_status("RIPOSTE STANCE  %.1fs" % maxf(_riposte, 0.0) if _riposte > 0.0 else "")
		if _riposte_shot:
			if _riposte > 0.0 and player.cinematic:
				# A follow camera behind you; looking up and down tilts it.
				player.cine_focus = player.global_position + Vector3.UP * 1.25
				player.cine_orbit.y = clampf(0.22 - player._camera.rotation.x * 0.7, -0.1, 0.9)
				_update_stance(Vector2(player.velocity.x, player.velocity.z).length() > 0.6)
			else:
				_riposte_shot = false
				player.end_cinematic()
	# Highlight Reel's shot: the camera follows him a beat behind, so the dashes streak.
	if mode == "reel" and player.cinematic:
		player.cine_focus = player.cine_focus.lerp(player.global_position + Vector3.UP * 1.0, 1.0 - exp(-9.0 * real_delta))
	if _farm > 0.0:
		_farm -= real_delta
		_set_status("AURA FARM  %.0fs" % maxf(_farm, 0.0) if _farm > 0.0 else "")
	if _cash_time > 0.0:
		_cash_time -= real_delta
		if _cash_time <= 0.0 or _cash <= 0.0:
			_cash = 0.0
			_cash_time = 0.0
			_set_status("")
			if is_instance_valid(_field):
				_field.finish()
		else:
			_set_status("CASH OUT  shield %d  %.0fs" % [roundi(_cash), maxf(_cash_time, 0.0)])
	_update_slabs(real_delta)
	if _shield_hits > 0:
		_shield_time -= real_delta
		_set_status("BRIMSTONE SHIELD  %d  -  %.0fs" % [_shield_hits, maxf(_shield_time, 0.0)])
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


## Inferno II: the hit sets off a shockwave of flame (2026-11-06: made big, the
## user wanted the card to be way more apparent). Everything close is knocked
## down and ignited (0.5x your base damage a burn tick; bosses reel, knock_down
## caps them), and it looks like it: rings of fire racing out along the ground,
## pillars of flame, a flash, a shake and a callout.
func _inferno_shockwave(center: Vector3, except: Enemy) -> void:
	var parent := player.get_parent()
	_shockwave_fx(parent, center)
	Sfx.play("heavy", 4.0, 0.45)
	Sfx.play("counter", 0.0, 0.5)
	TimeFx.slowmo(0.3, 0.3)
	player._shake = maxf(player._shake, 0.4)
	DamagePopup.spawn(parent, "INFERNO II!", Color(1.0, 0.6, 0.15), 64, center + Vector3(0, 3.0, 0))
	for enemy in _alive_enemies():
		if enemy == except or enemy.global_position.distance_to(center) > INFERNO_II_RADIUS:
			continue
		var away := enemy.global_position - center
		away.y = 0.0
		enemy.ignite(GameState.get_damage(), INFERNO_II_BURN)
		enemy.knock_down(INFERNO_STUN, away.normalized() * 4.0, true)


## The look of it: two rings of fire racing out to the full radius, pillars of
## flame rising behind them, a flash of light and a heavy burst.
func _shockwave_fx(parent: Node, center: Vector3, radius := INFERNO_II_RADIUS, pillars := true, soft := false) -> void:
	var ground := Vector3(center.x, center.y + 0.08, center.z)
	HitFx.burst(parent, ground + Vector3.UP * 0.3, Vector3.UP, FIRE_COLOR, 70, 12.0, true, 0.07)
	HitFx.burst(parent, ground + Vector3.UP * 0.2, Vector3.UP, Color(1.0, 0.8, 0.3), 40, 8.0, true, 0.04)
	for ring: Array in [[0.0, 0.5, Color(0.9, 0.3, 0.04)], [0.1, 0.7, Color(0.95, 0.6, 0.15)]]:
		var material := _fire_material(ring[2], 0.35 if soft else 0.75)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.78
		torus.outer_radius = 1.0
		torus.material = material
		var node := MeshInstance3D.new()
		node.mesh = torus
		node.position = ground
		node.scale = Vector3(0.3, 1.0 if soft else 3.0, 0.3)
		parent.add_child(node)
		var tween := node.create_tween().set_parallel()
		tween.tween_property(node, "scale", Vector3(radius, 1.2 if soft else 4.0, radius), ring[1]).set_delay(ring[0]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.35).set_delay(ring[0] + ring[1] - 0.2)
		tween.chain().tween_callback(node.queue_free)
	for i in (14 if pillars else 0):
		var angle := TAU * i / 14.0 + randf() * 0.35
		var reach := randf_range(1.2, radius - 0.3)
		var material := _fire_material(Color(0.9, 0.32, 0.05).lerp(Color(0.95, 0.6, 0.15), randf()), 0.6)
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 1.0, 0.4)
		box.material = material
		# The pillar grows from its base: the cube sits half a unit up its holder.
		var pillar := Node3D.new()
		var cube := MeshInstance3D.new()
		cube.mesh = box
		cube.position = Vector3(0, 0.5, 0)
		pillar.add_child(cube)
		pillar.position = ground + Vector3(cos(angle) * reach, 0, sin(angle) * reach)
		pillar.scale = Vector3(1, 0.05, 1)
		parent.add_child(pillar)
		var delay := reach / radius * 0.35
		var rise := pillar.create_tween()
		rise.tween_property(pillar, "scale", Vector3(0.5, randf_range(1.4, 2.6), 0.5), 0.22).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		rise.tween_property(material, "albedo_color:a", 0.0, 0.4)
		rise.tween_callback(pillar.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.5, 0.15)
	flash.omni_range = 9.0
	flash.light_energy = 0.0
	flash.position = ground + Vector3.UP * 1.2
	parent.add_child(flash)
	var glow := flash.create_tween()
	glow.tween_property(flash, "light_energy", 3.0 if soft else 9.0, 0.08)
	glow.tween_property(flash, "light_energy", 0.0, 0.6)
	glow.tween_callback(flash.queue_free)


## Bright, see-through, added to the light: flames.
static func _fire_material(color: Color, alpha := 0.75) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color, alpha)
	return material


## The Inferno Uppercut as a third-person shot (2026-11-06, the user's
## experiment: Settings > Display > Third-person ultimates). Three body clips
## (Emotes format; the body is posed by phase, so slow motion can't put them
## out of step): the leap with the legs tucked, landing in a deep crouch in
## front of the monster, then exploding upward with the uppercut using the
## whole body. The Mauler's aura (FighterAura) burns the whole time.
const INFERNO_CLIP := {
	"name": "Inferno leap", "length": 3.0, "loop": false, "plant": false,
	"keys": [
		{"t": 0.0, "pose": {"torso": [-14.3, 20.1, 0], "head": [8, 0, 0], "ls": [55, 0, -14], "le": [108, 0, 0], "rs": [-20, 0, 12], "re": [100, 0, 0],
			"lh": [42, 0, 0], "lk": [-84, 0, 0], "rh": [26, 0, 0], "rk": [-62, 0, 0], "pos": [0, -23, 0]}},
		{"t": 0.2, "pose": {"torso": [-10, 20.1, 0], "head": [8, 0, 0], "ls": [55, 0, -14], "le": [108, 0, 0], "rs": [-24, 0, 12], "re": [100, 0, 0],
			"lh": [62, 0, 0], "lk": [-104, 0, 0], "rh": [14, 0, 0], "rk": [-72, 0, 0], "pos": [0, 4, 0]}},
		{"t": 0.4, "pose": {"torso": [-20, 20.1, 0], "head": [0, 0, 0], "ls": [60, 0, -12], "le": [108, 0, 0], "rs": [-28, 0, 14], "re": [100, 0, 0],
			"lh": [18, 0, 0], "lk": [-30, 0, 0], "rh": [-6, 0, 0], "rk": [-24, 0, 0], "pos": [0, -3, 0]}},
		{"t": 3.0, "pose": {"torso": [-20, 20.1, 0], "head": [0, 0, 0], "ls": [60, 0, -12], "le": [108, 0, 0], "rs": [-28, 0, 14], "re": [100, 0, 0],
			"lh": [18, 0, 0], "lk": [-30, 0, 0], "rh": [-6, 0, 0], "rk": [-24, 0, 0], "pos": [0, -3, 0]}},
	],
}
const INFERNO_CROUCH_CLIP := {
	"name": "Inferno crouch", "length": 3.0, "loop": false, "plant": false,
	"keys": [
		{"t": 0.28, "pose": {"torso": [-30, 22, 0], "head": [-14, 0, 0], "ls": [66, 0, -14], "le": [110, 0, 0], "rs": [-42, 0, 16], "re": [100, 0, 0],
			"lh": [50, 0, 0], "lk": [-97, 0, 0], "rh": [42, 0, 0], "rk": [-92, 0, 0], "pos": [0, -30, 0]}},
		{"t": 3.0, "pose": {"torso": [-30, 22, 0], "head": [-14, 0, 0], "ls": [66, 0, -14], "le": [110, 0, 0], "rs": [-42, 0, 16], "re": [100, 0, 0],
			"lh": [50, 0, 0], "lk": [-97, 0, 0], "rh": [42, 0, 0], "rk": [-92, 0, 0], "pos": [0, -30, 0]}},
	],
}
const INFERNO_EXPLODE_CLIP := {
	"name": "Inferno explode", "length": 3.0, "loop": false, "plant": false,
	"keys": [
		{"t": 0.0, "pose": {"torso": [-30, 22, 0], "head": [-14, 0, 0], "ls": [66, 0, -14], "le": [110, 0, 0], "rs": [-42, 0, 16], "re": [100, 0, 0],
			"lh": [50, 0, 0], "lk": [-97, 0, 0], "rh": [42, 0, 0], "rk": [-92, 0, 0], "pos": [0, -30, 0]}},
		{"t": 0.14, "ease": "snap", "pose": {"torso": [16, -24, 0], "head": [18, 0, 0], "ls": [-25, 0, -10], "le": [60, 0, 0], "rs": [172, 0, 6], "re": [26, 0, 0],
			"lh": [-14, 0, 0], "lk": [-6, 0, 0], "rh": [-6, 0, 0], "rk": [-16, 0, 0], "pos": [0, 10, 0]}},
		{"t": 0.55, "pose": {"torso": [10, -18, 0], "head": [14, 0, 0], "ls": [-20, 0, -12], "le": [70, 0, 0], "rs": [168, 0, 6], "re": [30, 0, 0],
			"lh": [10, 0, 0], "lk": [-40, 0, 0], "rh": [4, 0, 0], "rk": [-30, 0, 0], "pos": [0, 6, 0]}},
		{"t": 1.0, "pose": {"torso": [4, -12, 0], "head": [6, 0, 0], "ls": [20, 0, -12], "le": [90, 0, 0], "rs": [150, 0, 6], "re": [40, 0, 0],
			"lh": [24, 0, 0], "lk": [-50, 0, 0], "rh": [10, 0, 0], "rk": [-36, 0, 0], "pos": [0, 0, 0]}},
		{"t": 3.0, "pose": {"torso": [4, -12, 0], "head": [6, 0, 0], "ls": [20, 0, -12], "le": [90, 0, 0], "rs": [150, 0, 6], "re": [40, 0, 0],
			"lh": [24, 0, 0], "lk": [-50, 0, 0], "rh": [10, 0, 0], "rk": [-36, 0, 0], "pos": [0, 0, 0]}},
	],
}
## The crouch on landing, the climb, and how long the camera stays out after.
const INFERNO_CROUCH_TIME := 0.5
const INFERNO_RISE_TIME := 0.85
const INFERNO_RISE_HEIGHT := 1.7
const INFERNO_SHOT_HOLD := 0.8


## The leap and the flaming uppercut at one monster, as a shot when the
## setting is on: the camera pulls out, you can't be touched, then it comes
## back and you stay untouchable half a second more.
func _inferno_at(target: Enemy) -> void:
	var shot := player.cinematic_enabled()
	if shot:
		mode = "inferno"
		player._aura.flare(0.6)
		player.start_cinematic(Emotes.parse(INFERNO_CLIP), player.global_position + Vector3.UP * 1.2, Vector2(0.6, 0.3), 3.6)
	await _inferno_run(target, shot)
	if shot:
		await _wait(INFERNO_SHOT_HOLD)
		player.end_cinematic()
	mode = ""


## One step of the leap (t 0-1): the arc, trailing fire, and in the shot the
## camera behind and above you, swinging toward your side as you close in.
func _leap_step(t: float, from: Vector3, to: Vector3, shot: bool) -> void:
	player.global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.8
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.DOWN, FIRE_COLOR, 2, 1.0, true, 0.04)
	if shot:
		player.cine_focus = player.global_position + Vector3.UP * 1.2
		player.cine_orbit = Vector2(lerpf(0.6, 1.0, t), lerpf(0.3, 0.18, t))
		player.cine_distance = lerpf(3.6, 3.0, t)


## The spring up (u 0-1): the body climbs and falls back, the camera on it.
func _rise_step(u: float, base_y: float) -> void:
	player.global_position.y = base_y + sin(u * PI) * INFERNO_RISE_HEIGHT
	player.cine_focus = player.global_position + Vector3.UP * 1.2


## Landing in front of it: a deep crouch, the aura flaring, the camera dropping
## low and pushing in. Real-time wait, whatever slow motion is doing.
func _inferno_crouch() -> void:
	player._body.play_clip(Emotes.parse(INFERNO_CROUCH_CLIP))
	player._aura.flare(1.4)
	var floor_spot := player.global_position + Vector3.UP * 0.15
	HitFx.burst(player.get_parent(), floor_spot, Vector3.UP, FIRE_COLOR, 26, 3.5, true, 0.05)
	HitFx.burst(player.get_parent(), floor_spot, Vector3.UP, Color(1.0, 0.8, 0.3), 14, 2.0, true, 0.03)
	Sfx.play("heavy", 0.0, 0.4)
	TimeFx.slowmo(0.5, INFERNO_CROUCH_TIME)
	var low := player.create_tween().set_parallel()
	low.tween_property(player, "cine_focus", player.global_position + Vector3.UP * 0.9, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	low.tween_property(player, "cine_orbit", Vector2(PI * 0.42, -0.04), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	low.tween_property(player, "cine_distance", 2.0, INFERNO_CROUCH_TIME).set_trans(Tween.TRANS_SINE)
	await _wait(INFERNO_CROUCH_TIME)


func _inferno_run(target: Enemy, shot: bool) -> void:
	_face(target)
	# The leap: an arc up and in, trailing fire, to right in front of it.
	mode = "inferno"
	Sfx.play("whoosh", 2.0, 0.5)
	if not shot:
		player._kick_fov(10.0)
	var from := player.global_position
	var flat := target.global_position - from
	flat.y = 0.0
	var to := from + flat - flat.normalized() * 1.1 if flat.length() > 1.1 else from
	var leap := player.create_tween()
	leap.tween_method(_leap_step.bind(from, to, shot), 0.0, 1.0, INFERNO_LEAP_TIME)
	await leap.finished
	if not shot:
		mode = ""
	if not is_instance_valid(target) or target.is_dead():
		return
	if shot:
		await _inferno_crouch()
		if not is_instance_valid(target) or target.is_dead():
			return
		# Up through the hit with the whole body, the camera pulling back and
		# tilting up with him, then drifting round to show the launch.
		player._body.play_clip(Emotes.parse(INFERNO_EXPLODE_CLIP))
		player._aura.flare(1.6)
		var rise := player.create_tween()
		rise.tween_method(_rise_step.bind(player.global_position.y), 0.0, 1.0, INFERNO_RISE_TIME)
		var cam := player.create_tween().set_parallel()
		cam.tween_property(player, "cine_orbit", Vector2(PI * 0.5, 0.3), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam.tween_property(player, "cine_distance", 3.5, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		cam.chain().tween_property(player, "cine_orbit", Vector2(PI * 0.7, 0.14), INFERNO_SHOT_HOLD + 0.3).set_trans(Tween.TRANS_SINE)
		cam.parallel().tween_property(player, "cine_distance", 4.0, INFERNO_SHOT_HOLD + 0.3).set_trans(Tween.TRANS_SINE)
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
	await _wait(0.12)
	if not is_instance_valid(target) or target.is_dead():
		return
	var boss := target.is_boss
	player._free_punch = true
	player._land_punch("uppercut", "right", false, false, target, INFERNO_DAMAGE * (1.0 + 0.5 * _power()), "INFERNO UPPERCUT!")
	var at := target.global_position + Vector3(0, 1.2, 0)
	# Inferno II: the hit sets off a shockwave of flame.
	if _card("inferno_ii"):
		_inferno_shockwave(target.global_position, target)
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
	# The shot (the user's idea, 2026-11-06): from above and the side, his hand
	# goes up like a stop sign and a sphere that starts inside it drains the
	# colour out of the world as it grows and freezes the monsters; then first
	# person, and the clock starts.
	var shot := player.cinematic_enabled()
	if shot:
		mode = "time_stop_intro"
		await _time_stop_intro()
		if not is_instance_valid(player):
			return
	mode = "time_stop"
	TimeFx.clear()
	targets = _alive_enemies().filter(func(e: Enemy) -> bool:
		return e.global_position.distance_to(player.global_position) <= TIME_STOP_RANGE)
	targets.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_to(player.global_position) < b.global_position.distance_to(player.global_position))
	_struck.assign(targets)
	_target_index = 0
	if not shot:
		_freeze(true)
		_grade_spread(Vector2(0.5, 0.55), 0.45)
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
	if not shot:
		_time_wave(true)
		Sfx.play("tell", 0.0, 0.5)
		Sfx.play("counter", -2.0, 0.45)
		player._kick_fov(-10.0)
		player.shake(0.08)
	player.class_event.emit("TEMPORAL BREAK!" if repeat >= 1.0 else "TEMPORAL BREAK  -%d%%" % roundi((1.0 - repeat) * 100.0))


## The Blur's hand goes up like a stop sign.
const TIME_HAND_CLIP := {"name": "Time stop", "length": 3.0, "loop": false, "plant": false, "keys": [
	{"t": 0.0, "pose": {"torso": [0, 0, 0], "head": [0, 0, 0], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, 0, 0]}},
	{"t": 0.45, "ease": "ease", "pose": {"torso": [6, 0, 0], "head": [-8, 0, 0], "ls": [26, 0, -12], "le": [30, 0, 0], "rs": [112, 0, 6], "re": [14, 0, 0],
		"lh": [8, 0, 0], "lk": [-14, 0, 0], "rh": [-4, 0, 0], "rk": [-10, 0, 0], "pos": [0, -2, 0]}},
	{"t": 3.0, "pose": {"torso": [6, 0, 0], "head": [-8, 0, 0], "ls": [26, 0, -12], "le": [30, 0, 0], "rs": [112, 0, 6], "re": [14, 0, 0],
		"lh": [8, 0, 0], "lk": [-14, 0, 0], "rh": [-4, 0, 0], "rk": [-10, 0, 0], "pos": [0, -2, 0]}},
]}
## How long the grey sphere takes to cover the screen.
const TIME_SPREAD := 0.9
var _grade: TimeGrade


func _grade_node() -> TimeGrade:
	if _grade == null or not is_instance_valid(_grade):
		_grade = TimeGrade.new()
		player.add_child(_grade)
	return _grade


## Where his raised hand is on the screen right now (screen UV).
func _hand_uv() -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var joint: Node3D = player._body._joints.get("re")
	if camera == null or joint == null:
		return Vector2(0.5, 0.45)
	var hand := joint.global_transform * FighterAura.GLOVE
	return camera.unproject_position(hand) / get_viewport().get_visible_rect().size


## One step of the sphere (t 0-1): the circle grows out of the hand.
func _grade_step(t: float, from_hand: bool, center: Vector2) -> void:
	var eased := 1.0 - pow(1.0 - t, 2.2)
	_grade_node().set_circle(_hand_uv() if from_hand else center, eased * TimeGrade.FULL)


## The colour drains out from a point, over time (the circle grows to cover everything).
func _grade_spread(center: Vector2, seconds: float) -> void:
	var tween := player.create_tween()
	tween.tween_method(_grade_step.bind(false, center), 0.0, 1.0, seconds)


## Time resumes: the grey world shrinks back to the middle of the screen and goes.
func _grade_release() -> void:
	if _grade == null or not is_instance_valid(_grade):
		return
	var tween := player.create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(_grade):
			_grade.set_circle(Vector2(0.5, 0.55), (1.0 - t) * TimeGrade.FULL), 0.0, 1.0, 0.3)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_grade):
			_grade.set_circle(Vector2(0.5, 0.5), 0.0))


## The shot: the camera high and to the side looking down, the hand up, the
## sphere growing out of it, the monsters freezing as it passes, a beat on the
## grey frozen world, then back to first person.
func _time_stop_intro() -> void:
	TimeFx.clear()
	player.start_cinematic(Emotes.parse(TIME_HAND_CLIP), player.global_position + Vector3.UP * 1.2, Vector2(PI * 0.5, 0.8), 3.9)
	player._aura.flare(1.0)
	Sfx.play("tell", 0.0, 0.5)
	var look := player.create_tween().set_parallel()
	look.tween_property(player, "cine_distance", 3.2, 2.1).set_trans(Tween.TRANS_SINE)
	look.tween_property(player, "cine_orbit", Vector2(PI * 0.66, 0.72), 2.1).set_trans(Tween.TRANS_SINE)
	await _wait(0.55)
	if not is_instance_valid(player):
		return
	# The sphere, out of the palm.
	Sfx.play("counter", 0.0, 0.45)
	Sfx.play("heavy", -4.0, 0.5)
	player._shake = maxf(player._shake, 0.1)
	HitFx.ring(player.get_parent(), player.global_position + Vector3(0, 1.6, 0) + player._flat_forward() * 0.5, Color(TIME_COLOR, 0.9), 2.0)
	var spread := player.create_tween()
	spread.tween_method(_grade_step.bind(true, Vector2.ZERO), 0.0, 1.0, TIME_SPREAD)
	await _wait(TIME_SPREAD * 0.4)
	if not is_instance_valid(player):
		return
	_freeze(true)
	await _wait(TIME_SPREAD * 0.6 + 0.4)
	if is_instance_valid(player):
		player.end_cinematic()


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
	player._set_combo(player.combo + TIME_STOP_COMBO_GAIN + (1 if _card("temporal_break_ii") and _hits % 2 == 0 else 0))
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
	_grade_release()
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
	# The user's idea (2026-11-06): see The Answer do his work in third person,
	# in his aura. The whole stance plays as the shot, the camera drifting round
	# him, controls locked (he does it all himself), and ends with it.
	if player.cinematic_enabled():
		_riposte_shot = true
		_stance_state = -1
		player._aura.flare(1.2)
		# Behind you, following: you can walk and look while it runs.
		player.start_cinematic(Emotes.parse(_riposte_clip({})), player.global_position + Vector3.UP * 1.25, Vector2(0.0, 0.22), 3.0)
		HitFx.ring(player.get_parent(), player.global_position + Vector3.UP * 0.2, Color(0.4, 0.8, 1.0, 0.8), 3.0)


## The Answer's guard, and a body clip for each thing the stance does: a slip, a
## roll, a back step, a hook. Each leaves the guard again when it's done.
const GUARD := {"torso": [-18, 14, 0], "head": [8, 0, 0], "ls": [84, 0, -8], "le": [120, 0, 0], "rs": [88, 0, 8], "re": [120, 0, 0],
	"lh": [50, 0, 0], "lk": [-97, 0, 0], "rh": [38, 0, 0], "rk": [-88, 0, 0], "pos": [0, -14, 0]}


## The crouched stance, walking: the legs trade places slowly, the guard stays up.
func _stance_clip(moving: bool) -> Dictionary:
	if not moving:
		return _riposte_clip({}, true)
	var a := GUARD.merged({"lh": [60, 0, 0], "lk": [-92, 0, 0], "rh": [28, 0, 0], "rk": [-104, 0, 0], "pos": [0, -13, 0]}, true)
	var b := GUARD.merged({"lh": [28, 0, 0], "lk": [-104, 0, 0], "rh": [60, 0, 0], "rk": [-92, 0, 0], "pos": [0, -13, 0]}, true)
	return Emotes.parse({"name": "Riposte walk", "length": 0.7, "loop": true, "plant": false, "keys": [
		{"t": 0.0, "pose": a}, {"t": 0.35, "pose": b}]})


## The body's clip for standing or walking in the stance, unless a reaction is playing.
func _update_stance(moving: bool) -> void:
	if Time.get_ticks_msec() / 1000.0 < _reaction_until:
		_stance_state = -1
		return
	var state := 1 if moving else 0
	if state != _stance_state:
		_stance_state = state
		player._body.play_clip(_stance_clip(moving))


func _riposte_clip(peak: Dictionary, hold := false) -> Dictionary:
	var move := GUARD.merged(peak, true)
	if hold:
		return Emotes.parse({"name": "Riposte guard", "length": 3.0, "loop": false, "plant": false, "keys": [
			{"t": 0.0, "pose": GUARD}, {"t": 3.0, "pose": GUARD}]})
	return Emotes.parse({"name": "Riposte", "length": 3.0, "loop": false, "plant": false, "keys": [
		{"t": 0.0, "pose": GUARD},
		{"t": 0.1, "ease": "snap", "pose": move},
		{"t": 0.34, "pose": GUARD},
		{"t": 3.0, "pose": GUARD},
	]})


## What the body does for a slip, roll or back step.
func _riposte_peak(move: String) -> Dictionary:
	var side := -1.0 if move.ends_with("left") else 1.0
	if move.begins_with("slip"):
		return {"torso": [-14, 0, -16.0 * side], "head": [4, 0, -12.0 * side], "pos": [10.0 * side, -12, 0]}
	if move.begins_with("roll"):
		return {"torso": [-40, 0, -10.0 * side], "head": [-6, 0, 0], "pos": [8.0 * side, -24, 0]}
	return {"torso": [-4, 0, 0], "head": [4, 0, 0], "pos": [0, -12, 12]}


## Slips the attack and, if the attacker is in reach, answers with a hook.
func _riposte_dodge(attack: String, attacker: Enemy) -> void:
	var answers: Array = Player.ANSWERS.get(attack, [])
	var move: String = answers[0] if not answers.is_empty() else "back_step"
	player._animate_defense(move)
	if _riposte_shot and player.cinematic:
		_reaction_until = Time.get_ticks_msec() / 1000.0 + 0.4
		player._body.play_clip(_riposte_clip(_riposte_peak(move)))
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
	var hand := "right" if player._counter_side != "left" else "left"
	if _riposte_shot and player.cinematic:
		# In the shot the camera stays behind you: only the body turns to the monster.
		var to := enemy.global_position - player.global_position
		to.y = 0.0
		player._body.rotation.y = wrapf(atan2(-to.x, -to.z) - player.rotation.y, -PI, PI)
		player._body.create_tween().tween_property(player._body, "rotation:y", 0.0, 0.4).set_delay(0.2)
		var hook := {"torso": [-12, 28, 0], "rs": [96, 0, -52], "re": [95, 0, 0]} if hand == "right" else {"torso": [-12, -28, 0], "ls": [96, 0, 52], "le": [95, 0, 0]}
		_reaction_until = Time.get_ticks_msec() / 1000.0 + 0.45
		player._body.play_clip(_riposte_clip(hook))
	else:
		_face(enemy)
	player._fists.play_punch("hook", hand, 0.08, 0.3)
	player._animate_head("hook", hand, 0.08, 0.3)
	await _wait(0.08)
	if is_instance_valid(enemy) and not enemy.is_dead() and player.active:
		player._land_punch("hook", hand, false, false, enemy, 1.0, "RIPOSTE!")


# --- Alternate ultimates (Abilities) ---------------------------------------------------

## The Mauler's Brimstone Shield (2026-11-06, a third-person shot like the
## Inferno Uppercut's): he lifts a leg and stomps, and one slab of igneous rock
## per hit it can take rises round him and turns, molten lava flowing and
## glowing through the cracks. Then it's first person again with the slabs still
## turning round you: each hit that lands breaks one (a boss's punch breaks
## two), and when the last breaks, or the time runs out, the shield detonates
## (in first person, so the camera doesn't go out and in twice).
##
## The body's moves (Emotes format): a knee lifted high, fists up; then the stomp.
const BULWARK_LIFT_CLIP := {
	"name": "Brimstone lift", "length": 3.0, "loop": false, "plant": false,
	"keys": [
		{"t": 0.0, "pose": {"torso": [0, 0, 0], "head": [0, 0, 0], "ls": [34, 0, -6], "le": [100, 0, 0], "rs": [34, 0, 6], "re": [100, 0, 0],
			"lh": [0, 0, 0], "lk": [0, 0, 0], "rh": [0, 0, 0], "rk": [0, 0, 0], "pos": [0, 0, 0]}},
		{"t": 0.5, "pose": {"torso": [8, -8, 0], "head": [-8, 0, 0], "ls": [95, 0, -24], "le": [115, 0, 0], "rs": [95, 0, 24], "re": [115, 0, 0],
			"lh": [-4, 0, 0], "lk": [-10, 0, 0], "rh": [102, 0, 0], "rk": [-108, 0, 0], "pos": [0, -1, 0]}},
		{"t": 3.0, "pose": {"torso": [8, -8, 0], "head": [-8, 0, 0], "ls": [95, 0, -24], "le": [115, 0, 0], "rs": [95, 0, 24], "re": [115, 0, 0],
			"lh": [-4, 0, 0], "lk": [-10, 0, 0], "rh": [102, 0, 0], "rk": [-108, 0, 0], "pos": [0, -1, 0]}},
	],
}
const BULWARK_STOMP_CLIP := {
	"name": "Brimstone stomp", "length": 3.0, "loop": false, "plant": false,
	"keys": [
		{"t": 0.0, "pose": {"torso": [8, -8, 0], "head": [-8, 0, 0], "ls": [95, 0, -24], "le": [115, 0, 0], "rs": [95, 0, 24], "re": [115, 0, 0],
			"lh": [-4, 0, 0], "lk": [-10, 0, 0], "rh": [102, 0, 0], "rk": [-108, 0, 0], "pos": [0, -1, 0]}},
		{"t": 0.1, "ease": "snap", "pose": {"torso": [-20, 0, 0], "head": [10, 0, 0], "ls": [26, 0, -14], "le": [92, 0, 0], "rs": [26, 0, 14], "re": [92, 0, 0],
			"lh": [38, 0, 0], "lk": [-76, 0, 0], "rh": [30, 0, 0], "rk": [-70, 0, 0], "pos": [0, -16, 0]}},
		{"t": 3.0, "pose": {"torso": [-20, 0, 0], "head": [10, 0, 0], "ls": [26, 0, -14], "le": [92, 0, 0], "rs": [26, 0, 14], "re": [92, 0, 0],
			"lh": [38, 0, 0], "lk": [-76, 0, 0], "rh": [30, 0, 0], "rk": [-70, 0, 0], "pos": [0, -16, 0]}},
	],
}
const BULWARK_LIFT_TIME := 0.55
const BULWARK_HOLD := 1.1
## The slabs: the radius they turn at, how fast, and how they're built.
const SLAB_ORBIT := 2.3
const SLAB_SPIN := 0.9
const SLAB_CELL := 0.19
const SLAB_COLS := 7
const SLAB_ROWS := 8
## Lava that pulses up the cracks (the vertex colors are the lava's own).
const LAVA_SHADER := "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvarying float h;\nvoid vertex() { h = VERTEX.y; }\nvoid fragment() {\n\tfloat pulse = 0.55 + 0.5 * sin(h * 7.0 - TIME * 3.2 + COLOR.r * 6.0);\n\tALBEDO = COLOR.rgb * (0.7 + 0.55 * pulse);\n}\n"

var _slabs: Array[Node3D] = []
var _shield_root: Node3D
var _shield_light: OmniLight3D
var _shield_spin := 0.0
static var _rock_material: StandardMaterial3D
static var _lava_material: ShaderMaterial


func _start_shield() -> void:
	_spend()
	# Brimstone Wall: one more hit.
	var hits := SHIELD_HITS + int(_power()) + (1 if _card("brimstone_wall") else 0)
	var time := SHIELD_TIME + 3.0 * _power()
	Sfx.play("unlock", 0.0, 0.6)
	player.class_event.emit("BRIMSTONE SHIELD")
	if player.cinematic_enabled():
		mode = "bulwark"
		await _bulwark_shot(hits)
		mode = ""
	else:
		_raise_slabs(hits, 0.07)
		Sfx.play("quake", 0.0, 0.7)
	if not is_instance_valid(player):
		return
	_shield_soaked = 0.0
	_shield_time = time
	_shield_hits = hits


## The shot: the knee lifts (the camera behind and low, easing in), the stomp
## (a ring of fire along the ground, a shake, slow motion), the slabs rise while
## the camera swings round to his front to show them, then back to first person.
func _bulwark_shot(hits: int) -> void:
	var parent := player.get_parent()
	player._aura.flare(0.6)
	player.start_cinematic(Emotes.parse(BULWARK_LIFT_CLIP), player.global_position + Vector3.UP * 1.2, Vector2(0.95, 0.12), 3.5)
	var lift := player.create_tween().set_parallel()
	lift.tween_property(player, "cine_distance", 3.0, BULWARK_LIFT_TIME).set_trans(Tween.TRANS_SINE)
	lift.tween_property(player, "cine_orbit", Vector2(0.7, 0.0), BULWARK_LIFT_TIME).set_trans(Tween.TRANS_SINE)
	await _wait(BULWARK_LIFT_TIME)
	if not is_instance_valid(player):
		return
	player._body.play_clip(Emotes.parse(BULWARK_STOMP_CLIP))
	player._aura.flare(1.8)
	var ground := player.global_position + Vector3.UP * 0.05
	HitFx.burst(parent, ground + Vector3.UP * 0.1, Vector3.UP, FIRE_COLOR, 36, 5.0, true, 0.06)
	HitFx.burst(parent, ground + Vector3.UP * 0.1, Vector3.UP, Color(0.25, 0.2, 0.18), 24, 4.0, false, 0.09)
	_shockwave_fx(parent, ground, 3.4, false, true)
	Sfx.play("quake", 4.0, 0.6)
	Sfx.play("heavy", 2.0, 0.4)
	player._shake = maxf(player._shake, 0.3)
	TimeFx.slowmo(0.35, 0.35)
	_raise_slabs(hits, 0.08)
	var sweep := player.create_tween().set_parallel()
	sweep.tween_property(player, "cine_orbit", Vector2(PI * 0.88, 0.14), BULWARK_HOLD + 0.2).set_trans(Tween.TRANS_SINE)
	sweep.tween_property(player, "cine_distance", 4.2, BULWARK_HOLD + 0.2).set_trans(Tween.TRANS_SINE)
	await _wait(BULWARK_HOLD)
	if is_instance_valid(player):
		player.end_cinematic()


## One slab of igneous rock per hit, rising out of the ground round you.
func _raise_slabs(count: int, stagger: float) -> void:
	_clear_slabs()
	var parent := player.get_parent()
	_shield_root = Node3D.new()
	_shield_root.top_level = true
	parent.add_child(_shield_root)
	_shield_root.global_position = player.global_position
	_shield_light = OmniLight3D.new()
	_shield_light.light_color = Color(1.0, 0.45, 0.12)
	_shield_light.light_energy = 0.9
	_shield_light.omni_range = 4.5
	_shield_light.position = Vector3(0, 1.0, 0)
	_shield_root.add_child(_shield_light)
	_shield_spin = 0.0
	for i in count:
		var slab := _make_slab(1000 + i * 7)
		slab.set_meta("angle", TAU * i / float(count))
		slab.position = Vector3(0, -2.4, 0)
		_shield_root.add_child(slab)
		_slabs.append(slab)
		var rise := slab.create_tween()
		rise.tween_property(slab, "position:y", 0.0, 0.5).set_delay(i * stagger).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var timer := get_tree().create_timer(i * stagger + 0.1, false, false, true)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(slab) and is_instance_valid(parent):
				HitFx.burst(parent, slab.global_position + Vector3.UP * 0.15, Vector3.UP, Color(0.3, 0.22, 0.18), 8, 3.0, false, 0.07)
				HitFx.burst(parent, slab.global_position + Vector3.UP * 0.2, Vector3.UP, FIRE_COLOR, 8, 3.5, true, 0.04))


## Where each slab sits, every frame: turning round you, spaced evenly among
## those left (a break closes the gap).
func _update_slabs(real_delta: float) -> void:
	if _shield_root == null or not is_instance_valid(_shield_root):
		return
	_shield_spin += SLAB_SPIN * real_delta
	_shield_root.global_position = player.global_position
	for i in _slabs.size():
		var slab := _slabs[i]
		var goal := TAU * i / float(_slabs.size())
		slab.set_meta("angle", lerp_angle(float(slab.get_meta("angle")), goal, clampf(real_delta * 5.0, 0.0, 1.0)))
		var a := _shield_spin + float(slab.get_meta("angle"))
		slab.position = Vector3(sin(a) * SLAB_ORBIT, slab.position.y, cos(a) * SLAB_ORBIT)
		slab.rotation.y = a


func _clear_slabs() -> void:
	for slab in _slabs:
		if is_instance_valid(slab):
			slab.queue_free()
	_slabs.clear()
	if is_instance_valid(_shield_root):
		_shield_root.queue_free()
	_shield_root = null
	_shield_light = null


## A slab breaks: rock and sparks fly out from it.
func _break_slab(slab: Node3D) -> void:
	var parent := player.get_parent()
	var at := slab.global_position + Vector3.UP * 0.8
	var out := (slab.global_position - player.global_position)
	out.y = 0.0
	HitFx.burst(parent, at, out.normalized(), Color(0.22, 0.17, 0.15), 16, 6.0, false, 0.1)
	HitFx.burst(parent, at, Vector3.UP, FIRE_COLOR, 14, 5.0, true, 0.05)
	_slabs.erase(slab)
	slab.queue_free()


## One slab of rock: dark basalt cubes, bent round you, a few jagged cracks of
## glowing lava running through it. Two meshes (rock and lava), however many cubes.
func _make_slab(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock := SurfaceTool.new()
	var lava := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	lava.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vein := {}
	var main := rng.randi_range(2, SLAB_COLS - 3)
	var along := main
	for row in SLAB_ROWS:
		vein[Vector2i(along, row)] = true
		along = clampi(along + rng.randi_range(-1, 1), 0, SLAB_COLS - 1)
	# A short branch off it.
	var branch_row := rng.randi_range(2, SLAB_ROWS - 3)
	var side := -1 if rng.randf() < 0.5 else 1
	for step in rng.randi_range(2, 3):
		vein[Vector2i(clampi(main + side * step, 0, SLAB_COLS - 1), branch_row + (step % 2))] = true
	for col in SLAB_COLS:
		var edge := col == 0 or col == SLAB_COLS - 1
		var height := SLAB_ROWS - rng.randi_range(0, 2 if edge else 1)
		for row in height:
			var dx := (col - (SLAB_COLS - 1) / 2.0) * SLAB_CELL
			for layer in 2:
				var at := Vector3(dx, (row + 0.5) * SLAB_CELL, -dx * dx * 0.55 + (layer - 0.5) * SLAB_CELL)
				if vein.has(Vector2i(col, row)):
					# Through the whole slab, so the lava shows from inside too.
					var heat := rng.randf()
					_add_cube(lava, at, SLAB_CELL * 1.03, Color(1.0, 0.3 + 0.4 * heat, 0.03 + 0.1 * heat))
				elif (col == 0 or col == SLAB_COLS - 1 or row >= SLAB_ROWS - 2) and rng.randf() < 0.18:
					continue  # chipped, jagged edges
				else:
					var warm := _near_vein(vein, col, row)
					var shade := rng.randf_range(0.75, 1.35)
					var color := Color(0.34, 0.14, 0.08) * shade if warm else Color(0.2, 0.17, 0.15) * shade
					_add_cube(rock, at, SLAB_CELL * 0.98, Color(color, 1.0))
	if _rock_material == null:
		_rock_material = StandardMaterial3D.new()
		_rock_material.vertex_color_use_as_albedo = true
		_rock_material.roughness = 0.95
		_rock_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_lava_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = LAVA_SHADER
		_lava_material.shader = shader
	var holder := Node3D.new()
	var rock_node := MeshInstance3D.new()
	rock_node.mesh = rock.commit()
	rock_node.material_override = _rock_material
	holder.add_child(rock_node)
	var lava_node := MeshInstance3D.new()
	lava_node.mesh = lava.commit()
	lava_node.material_override = _lava_material
	holder.add_child(lava_node)
	return holder


func _near_vein(vein: Dictionary, col: int, row: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if vein.has(Vector2i(col, row) + d):
			return true
	return false


## One cube, with its own color on every vertex.
static func _add_cube(st: SurfaceTool, center: Vector3, size: float, color: Color) -> void:
	var h := size / 2.0
	for face: Array in [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
			[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
			[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var c := center + n * h
		var corners := [c - u * h - v * h, c + u * h - v * h, c + u * h + v * h, c - u * h + v * h]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(corners[index])


func _shield_absorb(amount: float, attacker: Enemy = null) -> void:
	# A boss's punch takes two hits off it.
	_shield_hits -= 2 if attacker and attacker.is_boss else 1
	_shield_soaked += amount
	# Brimstone Wall: every soaked hit burns the attacker back.
	if _card("brimstone_wall") and attacker and not attacker.is_dead():
		attacker.take_hit(GameState.get_damage(), attacker.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "BRIMSTONE")
	Sfx.play("block", 0.0, 0.7)
	player._shake = maxf(player._shake, 0.05)
	# One slab breaks for every hit it took (the one nearest what hit you).
	while _slabs.size() > maxi(_shield_hits, 0):
		var nearest := _slabs[0]
		if attacker and is_instance_valid(attacker):
			for slab in _slabs:
				if slab.global_position.distance_to(attacker.global_position) < nearest.global_position.distance_to(attacker.global_position):
					nearest = slab
		_break_slab(nearest)
	if _shield_hits <= 0:
		_shield_break()


## The shield detonates: what's left of the slabs flies apart, and everything
## near takes what it soaked, and burns.
func _shield_break() -> void:
	_shield_hits = 0
	_set_status("")
	for slab in _slabs.duplicate():
		_break_slab(slab)
	_clear_slabs()
	var radius := SHIELD_RADIUS + 0.5 * _power()
	var damage := _shield_soaked * (SHIELD_BLAST + 0.5 * _power()) + GameState.get_damage() * 3.0
	Sfx.play("quake", 4.0, 0.7)
	player._shake = maxf(player._shake, 0.3)
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.UP, FIRE_COLOR, 60, 10.0, true, 0.08)
	HitFx.ring(player.get_parent(), player.global_position + Vector3.UP * 0.2, Color(FIRE_COLOR, 0.8), radius)
	_shockwave_fx(player.get_parent(), player.global_position, radius, false, true)
	for enemy in _alive_enemies():
		var away := enemy.global_position - player.global_position
		if away.length() <= radius:
			enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), away.normalized() * 8.0, true, "BRIMSTONE!")
			if not enemy.is_dead():
				enemy.ignite(GameState.get_damage() * 1.5, INFERNO_BURN_TIME)
				enemy.knock_down(0.8, away, true)
	player.class_event.emit("BRIMSTONE!")


## The Answer's Aura Farm (was Flow State; the user's notes, 2026-11-06): for
## 15s every dodge heals 1% of your HP and a clean dodge 2% (Aura Farm II: 2%
## and 3%). The Answer's sustain.
func _start_flow() -> void:
	_spend()
	Sfx.play("tell", 0.0, 1.3)
	player.class_event.emit("AURA FARM")
	if player.cinematic_enabled():
		mode = "aura_farm"
		await _aura_farm_intro()
		mode = ""
	if not is_instance_valid(player):
		return
	_farm = FARM_TIME + _power()
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.UP, Color(0.4, 1.0, 0.65), 30, 4.0, true, 0.05)


## The intro (the user's idea, 2026-11-06): in third person from the front he walks
## forward slowly, tilts his head side to side (a neck crack), claps his gloves
## together, and it's first person again with the Aura Farm running.
const FARM_WALK_CLIP := {"name": "Farm walk", "length": 1.2, "loop": true, "plant": false, "keys": [
	{"t": 0.0, "pose": {"torso": [3, 0, 0], "head": [0, 0, 0], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [24, 0, 0], "lk": [-8, 0, 0], "rh": [-18, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 0.6, "pose": {"torso": [3, 0, 0], "head": [0, 0, 0], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [-18, 0, 0], "lk": [-4, 0, 0], "rh": [24, 0, 0], "rk": [-8, 0, 0], "pos": [0, -1, 0]}},
]}
const FARM_NECK_CLIP := {"name": "Farm neck", "length": 4.0, "loop": false, "plant": false, "keys": [
	{"t": 0.0, "pose": {"torso": [2, 0, 0], "head": [0, 0, 0], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	# One side only: slowly over, held, a small push for the crack, then level.
	{"t": 0.45, "ease": "ease", "pose": {"torso": [2, 0, 3], "head": [6, 0, 20], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 0.65, "pose": {"torso": [2, 0, 3], "head": [6, 0, 20], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 0.75, "ease": "snap", "pose": {"torso": [2, 0, 4], "head": [6, 0, 24], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 1.0, "pose": {"torso": [2, 0, 4], "head": [6, 0, 24], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 1.35, "pose": {"torso": [4, 0, 0], "head": [-2, 0, 0], "ls": [40, 0, -14], "le": [70, 0, 0], "rs": [40, 0, 14], "re": [70, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 4.0, "pose": {"torso": [4, 0, 0], "head": [-2, 0, 0], "ls": [40, 0, -14], "le": [70, 0, 0], "rs": [40, 0, 14], "re": [70, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
]}
## The gloves come together as he drops at the knees into a wide, split stance
## (one foot forward, one back, the knees bent) and holds it.
const FARM_CLAP_CLIP := {"name": "Farm clap", "length": 3.0, "loop": false, "plant": false, "keys": [
	{"t": 0.0, "pose": {"torso": [4, 0, 0], "head": [-2, 0, 0], "ls": [40, 0, -14], "le": [70, 0, 0], "rs": [40, 0, 14], "re": [70, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 0.22, "ease": "snap", "pose": {"torso": [-14, 8, 0], "head": [8, 0, 0], "ls": [86, 0, 20], "le": [106, 0, 0], "rs": [86, 0, -20], "re": [106, 0, 0],
		"lh": [46, 0, -20], "lk": [-92, 0, 0], "rh": [-8, 0, 22], "rk": [-70, 0, 0], "pos": [0, -26, 0]}},
	{"t": 3.0, "pose": {"torso": [-14, 8, 0], "head": [8, 0, 0], "ls": [86, 0, 20], "le": [106, 0, 0], "rs": [86, 0, -20], "re": [106, 0, 0],
		"lh": [46, 0, -20], "lk": [-92, 0, 0], "rh": [-8, 0, 22], "rk": [-70, 0, 0], "pos": [0, -26, 0]}},
]}


## The camera yaw nearest to the wanted one (front first, then a little to either
## side, then further round) with no monster near where the camera would sit.
func _clear_yaw(wanted: float, distance: float) -> float:
	var enemies := _alive_enemies()
	for turn in [0.0, 0.7, -0.7, 1.4, -1.4, 2.1, -2.1]:
		var yaw: float = wanted + turn
		var spot := player.global_position + Vector3(sin(yaw), 0, cos(yaw)) * (distance + 1.5)
		var clear := true
		for enemy in enemies:
			if enemy.global_position.distance_to(spot) < 2.6 or enemy.global_position.distance_to(player.global_position.lerp(spot, 0.5)) < 1.6:
				clear = false
				break
		if clear:
			return yaw
	return wanted


func _aura_farm_intro() -> void:
	var parent := player.get_parent()
	# From the front, low and wide; the camera is fixed in the world while he walks into it.
	var yaw := _clear_yaw(player.rotation.y + PI, 4.0)
	player.start_cinematic(Emotes.parse(FARM_WALK_CLIP), player.global_position + Vector3.UP * 1.15, Vector2(yaw, 0.04), 4.0)
	player.cine_world = true
	player._aura.flare(0.5)
	var from := player.global_position
	var step := player._flat_forward() * 1.0
	var walk := player.create_tween().set_parallel()
	walk.tween_method(func(t: float) -> void:
		player.global_position = from + step * t
		player.cine_focus = player.global_position + Vector3.UP * 1.15, 0.0, 1.0, 0.8)
	walk.tween_property(player, "cine_distance", 3.0, 0.8).set_trans(Tween.TRANS_SINE)
	await _wait(0.8)
	if not is_instance_valid(player):
		return
	# The neck crack, one side: slowly over, held, a crack.
	player._body.play_clip(Emotes.parse(FARM_NECK_CLIP))
	var push := player.create_tween().set_parallel()
	push.tween_property(player, "cine_distance", 2.5, 1.3).set_trans(Tween.TRANS_SINE)
	push.tween_property(player, "cine_orbit", Vector2(yaw - signf(sin(yaw - player.rotation.y - PI)) * 0.1, 0.02), 1.3).set_trans(Tween.TRANS_SINE)
	await _wait(0.78)
	Sfx.play("block", -4.0, 1.7)
	await _wait(0.57)
	if not is_instance_valid(player):
		return
	# The clap: gloves together as he drops at the knees into a split stance, the
	# aura flares and a ring of light goes out.
	player._body.play_clip(Emotes.parse(FARM_CLAP_CLIP))
	var drop := player.create_tween().set_parallel()
	drop.tween_property(player, "cine_orbit", Vector2(yaw, -0.06), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drop.tween_property(player, "cine_distance", 2.9, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await _wait(0.2)
	if not is_instance_valid(player):
		return
	var chest := player.global_position + player._flat_forward() * 0.35 + Vector3.UP * 1.1
	player._aura.flare(2.2)
	Sfx.play("counter", 0.0, 0.8)
	Sfx.play("heavy", -2.0, 0.9)
	player._shake = maxf(player._shake, 0.2)
	TimeFx.slowmo(0.5, 0.25)
	HitFx.ring(parent, chest, Color(0.4, 1.0, 0.65, 0.9), 2.4)
	HitFx.burst(parent, chest, Vector3.UP, Color(0.4, 1.0, 0.65), 36, 6.0, true, 0.05)
	HitFx.burst(parent, chest, Vector3.UP, Color(0.7, 0.95, 1.0), 20, 4.0, true, 0.03)
	await _wait(0.55)
	if is_instance_valid(player):
		player.end_cinematic()


## The Blur's Cash Out (was Unbroken; the user's notes, 2026-11-06): spend your
## combo (5 hits or more) for a shield worth 1% of your knuckle HP for every hit
## of it (1.5% with Cash Out II). While it's up a hit halves your combo instead
## of ending it.
func _start_unbroken() -> void:
	if player.combo < CASH_MIN:
		# Not spent: say so where you can see it.
		_set_status("Cash Out needs a %d-hit combo" % CASH_MIN, 1.4)
		DamagePopup.spawn(player.get_parent(), "NEEDS A %d-HIT COMBO" % CASH_MIN, Color(1.0, 0.82, 0.3), 44, player.global_position + player._flat_forward() * 1.4 + Vector3(0, 1.8, 0))
		Sfx.play("block", -2.0, 0.8)
		return
	var hits := player.combo
	_spend()
	player._skip_reboot = true
	player._set_combo(0)
	player._skip_reboot = false
	# The shield: (5 + the combo's hits)% of your max knuckle HP, 8 + hits with Cash Out II
	# (the user, 2026-11-07: percent, not flat).
	_cash = player.max_knuckles * 0.01 * ((CASH_BASE_II if _card("unbroken_ii") else CASH_BASE) + hits)
	_cash_max = _cash
	_cash_time = CASH_TIME + _power()
	Sfx.play("unlock", 0.0, 1.2)
	# No third-person shot for this one (the user): a pop-up and a green aura field.
	player.class_event.emit("CASH OUT  -  shield %d" % roundi(_cash))
	DamagePopup.spawn(player.get_parent(), "CASH OUT  +%d" % roundi(_cash), AuraField.COLOR, 56, player.global_position + player._flat_forward() * 1.4 + Vector3(0, 1.9, 0))
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP, Vector3.UP, AuraField.COLOR, 30, 5.0, true, 0.05)
	HitFx.ring(player.get_parent(), player.global_position + Vector3.UP * 0.2, Color(AuraField.COLOR, 0.8), 2.5)
	if is_instance_valid(_field):
		_field.queue_free()
	_field = AuraField.new()
	player.add_child(_field)
	_field.setup(player)


## Cash Out's shield is up.
func cash_up() -> bool:
	return _cash > 0.0


## The shield's knuckle HP left (the HP strap shows it in blue).
func shield() -> float:
	return _cash


## What gets through a hit after the shield soaks what it can.
func soak_cash(loss: float) -> float:
	if _cash <= 0.0 or loss <= 0.0:
		return loss
	var soaked := minf(_cash, loss)
	_cash -= soaked
	if is_instance_valid(_field):
		_field.set_strength(_cash / maxf(_cash_max, 0.01))
		_field.pulse()
	Sfx.play("block", -4.0, 1.3)
	DamagePopup.spawn(player.get_parent(), "-%d" % roundi(soaked), Color(1.0, 0.85, 0.35), 36, player.global_position + player._flat_forward() + Vector3(0, 1.6, 0))
	HitFx.burst(player.get_parent(), player.global_position + Vector3.UP * 1.2, Vector3.UP, Color(1.0, 0.82, 0.3), 8, 3.0, true, 0.04)
	if _cash <= 0.0:
		_cash_time = 0.0
		_set_status("")
		player.class_event.emit("SHIELD BROKEN")
		if is_instance_valid(_field):
			_field.finish()
	return loss - soaked


## The Stray's Hype Train: faster, and anything in the way goes flying.
func _start_hype() -> void:
	_spend()
	_express = 0.0
	player.class_event.emit("HYPE TRAIN!")
	# The user's idea (2026-11-07): the same third-person pose as Highlight Reel's start
	# (the crouch into the sprinting stance, feet blazing), then first person with the
	# train running, no lock-on and a wider view.
	if player.cinematic_enabled():
		mode = "hype_intro"
		await _reel_intro(0.55)
		await _wait(0.35)
		if not is_instance_valid(player):
			return
		player.end_cinematic()
		mode = ""
	hype = HYPE_TIME + _power()
	Sfx.play("whoosh", 4.0, 0.6)
	player._kick_fov(12.0)


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
	# The user's idea (2026-11-07): a third-person shot. He crouches into a sprinting
	# stance, his feet glow green, and he launches at each monster in turn with a neon
	# trail behind him, every hit a haymaker.
	var shot := player.cinematic_enabled()
	if shot:
		await _reel_intro()
		if not is_instance_valid(player):
			return
	# A long chain speeds up so the shot stays short.
	var pace := 1.0 / (1.0 + 0.12 * maxf(0.0, targets.size() - 5.0))
	for i in targets.size():
		var target := targets[i]
		if not is_instance_valid(target) or target.is_dead() or not player.active:
			continue
		var last := i == targets.size() - 1
		await _dash_to(target, last, shot, pace)
		if not is_instance_valid(target) or target.is_dead():
			continue
		var hand := "left" if i % 2 == 0 else "right"
		# Every punch is a haymaker (the finisher a hook, as it was).
		var type := "hook"
		if shot:
			player._body.play_clip(Emotes.parse(_reel_swing(hand, last)))
		else:
			player._fists.play_punch(type, hand, 0.06, 0.25)
			player._animate_head(type, hand, 0.06, 0.25)
		await _wait((0.12 if shot else 0.06) * pace)
		if not is_instance_valid(target) or target.is_dead():
			continue
		player._free_punch = true
		if last:
			player._land_punch(type, hand, false, false, target, REEL_FINISHER * (1.0 + 0.3 * _power()))
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
			HitFx.burst(player.get_parent(), target.global_position + Vector3(0, 1.3, 0), Vector3.UP, REEL_COLOR, 24, 6.0, true, 0.05)
			if shot:
				HitFx.ring(player.get_parent(), target.global_position + Vector3(0, 0.9, 0), REEL_COLOR, 1.8)
		await _wait(REEL_PAUSE * pace)
		# Back into the run for the next one.
		if shot and not last and is_instance_valid(player):
			player._body.play_clip(Emotes.parse(REEL_RUN_CLIP))
	if shot and is_instance_valid(player):
		await _wait(0.45)
		if is_instance_valid(player):
			player.end_cinematic()
	mode = ""


const REEL_COLOR := Color(0.35, 1.0, 0.55)
## The sprinting stance: low, leaning into it, arms swept back. Feet glow (the aura).
const REEL_POSE_CROUCH := {"torso": [-30, 0, 0], "head": [22, 0, 0], "ls": [-48, 0, -8], "le": [70, 0, 0], "rs": [-48, 0, 8], "re": [70, 0, 0],
	"lh": [42, 0, 0], "lk": [-76, 0, 0], "rh": [-20, 0, 0], "rk": [-34, 0, 0], "pos": [0, -16, 0]}
const REEL_CROUCH_CLIP := {"name": "Reel crouch", "length": 3.0, "loop": false, "plant": false, "keys": [
	{"t": 0.0, "pose": {"torso": [3, 0, 0], "head": [0, 0, 0], "ls": [18, 0, -6], "le": [28, 0, 0], "rs": [18, 0, 6], "re": [28, 0, 0],
		"lh": [2, 0, 0], "lk": [-4, 0, 0], "rh": [2, 0, 0], "rk": [-4, 0, 0], "pos": [0, -1, 0]}},
	{"t": 0.35, "ease": "ease", "pose": REEL_POSE_CROUCH},
	{"t": 3.0, "pose": REEL_POSE_CROUCH},
]}
## Running flat out: the legs trade places fast.
const REEL_RUN_POSE_A := {"torso": [-32, 0, 0], "head": [24, 0, 0], "ls": [-55, 0, -8], "le": [75, 0, 0], "rs": [-55, 0, 8], "re": [75, 0, 0],
	"lh": [58, 0, 0], "lk": [-82, 0, 0], "rh": [-38, 0, 0], "rk": [-52, 0, 0], "pos": [0, -12, 0]}
const REEL_RUN_POSE_B := {"torso": [-32, 0, 0], "head": [24, 0, 0], "ls": [-55, 0, -8], "le": [75, 0, 0], "rs": [-55, 0, 8], "re": [75, 0, 0],
	"lh": [-38, 0, 0], "lk": [-52, 0, 0], "rh": [58, 0, 0], "rk": [-82, 0, 0], "pos": [0, -12, 0]}
const REEL_RUN_CLIP := {"name": "Reel run", "length": 0.3, "loop": true, "plant": false, "keys": [
	{"t": 0.0, "pose": REEL_RUN_POSE_A},
	{"t": 0.15, "pose": REEL_RUN_POSE_B},
]}


## A haymaker: the body winds up away from the punching hand and swings the arm round
## wide (the finisher puts more of him into it).
func _reel_swing(hand: String, last: bool) -> Dictionary:
	var side := 1.0 if hand == "right" else -1.0
	var wind := {"torso": [-18, -34.0 * side, 0], "head": [10, 20.0 * side, 0], "pos": [0, -14, 0]}
	var swing := {"torso": [-20, (44.0 if last else 36.0) * side, 0], "head": [8, -16.0 * side, 0], "pos": [0, -14, 0]}
	if hand == "right":
		wind.merge({"rs": [70, 0, -110], "re": [60, 0, 0]})
		swing.merge({"rs": [92, 0, -54], "re": [98, 0, 0]})
	else:
		wind.merge({"ls": [70, 0, 110], "le": [60, 0, 0]})
		swing.merge({"ls": [92, 0, 54], "le": [98, 0, 0]})
	return {"name": "Reel haymaker", "length": 1.0, "loop": false, "plant": false, "keys": [
		{"t": 0.0, "pose": REEL_RUN_POSE_A},
		{"t": 0.07, "ease": "ease", "pose": REEL_POSE_CROUCH.merged(wind, true)},
		{"t": 0.14, "ease": "snap", "pose": REEL_POSE_CROUCH.merged(swing, true)},
		{"t": 1.0, "pose": REEL_POSE_CROUCH.merged(swing, true)},
	]}


## The shot opens: a crouch into the sprinting stance, the feet blazing, the camera
## behind and low.
func _reel_intro(hold := 0.55) -> void:
	var yaw := player.rotation.y
	player.start_cinematic(Emotes.parse(REEL_CROUCH_CLIP), player.global_position + Vector3.UP * 1.0, Vector2(yaw, 0.1), 3.6)
	player.cine_world = true
	player._aura.flare(1.8)
	HitFx.ring(player.get_parent(), player.global_position + Vector3.UP * 0.1, Color(REEL_COLOR, 0.8), 2.4)
	Sfx.play("whoosh", -2.0, 0.7)
	var pull := player.create_tween()
	pull.tween_property(player, "cine_distance", 3.0, 0.5).set_trans(Tween.TRANS_SINE)
	await _wait(hold)
	if is_instance_valid(player):
		player._body.play_clip(Emotes.parse(REEL_RUN_CLIP))
		player._aura.flare(2.2)


## Streaks to just in front of the target, leaving lightning behind. The
## finisher leaps in.
func _dash_to(target: Enemy, leap: bool, shot := false, pace := 1.0) -> void:
	var from := player.global_position
	var to := target.global_position - from
	to.y = 0.0
	var dest := target.global_position - to.normalized() * REEL_STAND_OFF if to.length() > REEL_STAND_OFF else from
	dest.y = maxf(from.y, target.global_position.y)
	_face(target)
	Sfx.play("whoosh", 0.0, 1.5)
	# Waist height, so it streaks past below the camera rather than through it.
	var ahead := (dest - from).normalized() * 0.5
	if not shot:
		_lightning(from + ahead + Vector3(0, 0.8, 0), dest + Vector3(0, 0.8, 0))
	_neon_trail(from, dest)
	# In the shot the dash is slower, so the streak can be seen.
	var time := REEL_DASH_TIME
	if shot:
		time = clampf(from.distance_to(dest) / 40.0, REEL_DASH_TIME, 0.22) * pace
	var tween := player.create_tween()
	tween.set_ignore_time_scale(true)
	if leap:
		var top := (from + dest) / 2.0 + Vector3(0, 1.2, 0)
		tween.tween_property(player, "global_position", top, time * 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(player, "global_position", dest, time * 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	else:
		tween.tween_property(player, "global_position", dest, time)
	await tween.finished


## The neon trail the Stray leaves behind (two glowing ribbons, one at his feet, one at
## his waist) that fades away.
func _neon_trail(from: Vector3, to: Vector3) -> void:
	for height: float in [0.1, 0.85]:
		var a := from + Vector3(0, height, 0)
		var b := to + Vector3(0, height, 0)
		var length := a.distance_to(b)
		if length < 0.2:
			continue
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = Color(REEL_COLOR.lightened(0.15), 0.9 if height < 0.5 else 0.55)
		var box := BoxMesh.new()
		box.size = Vector3(0.34 if height < 0.5 else 0.1, 0.06, length)
		box.material = material
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		player.get_parent().add_child(mesh)
		mesh.global_position = (a + b) / 2.0
		mesh.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
		var tween := mesh.create_tween()
		tween.set_ignore_time_scale(true)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(mesh.queue_free)


## A jagged glowing bolt between two points that flickers and fades.
func _lightning(from: Vector3, to: Vector3) -> void:
	var bolt := Node3D.new()
	player.get_parent().add_child(bolt)
	var material := Enemy._glow_material(REEL_COLOR)
	var core := Enemy._glow_material(Color(0.92, 1.0, 0.94))
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
	light.light_color = REEL_COLOR
	light.light_energy = 4.0
	light.omni_range = 5.0
	bolt.add_child(light)
	light.global_position = (from + to) / 2.0
	HitFx.burst(player.get_parent(), from, Vector3.UP, REEL_COLOR, 14, 3.0, true, 0.04)
	var tween := bolt.create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(bolt, "scale", Vector3(1, 1, 1), 0.12)
	tween.tween_callback(func() -> void: bolt.visible = false)
	tween.tween_interval(0.04)
	tween.tween_callback(func() -> void: bolt.visible = true)
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(bolt.queue_free)
