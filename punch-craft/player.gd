class_name Player
extends CharacterBody3D
## First-person player: movement, mouse-look, punching, combos, boxing defense
## (slips, rolls, back step), counters, flinching and knuckle HP.

signal knuckles_changed(current: float, maximum: float)
signal combo_changed(count: int, multiplier: float)
signal knuckles_broken
## Emitted when an enemy hit lands cleanly, with the attacker's position.
signal attacked(from: Vector3)
## Emitted when the right defense dodges an attack. move is a DEFENSES key,
## prefixed "clean_" for a clean (late, precise) dodge; also "jump" and "ghost".
signal dodged(move: String)
## Emitted when a timed defense was the wrong one and the attack grazed.
signal grazed
## Exact knuckle HP lost to an enemy attack (not punch stamina costs).
signal damage_taken(amount: float)
## Emitted when a punch connects. kind is "hit", "setup" (heavy after an
## opposite-hand jab/cross), "counter", "blocked" or "evaded"; killed if it
## finished the enemy.
signal punch_landed(kind: String, killed: bool)
## Same moment as punch_landed, with the punch type (jab, cross, hook, uppercut).
signal punch_connected(type: String, kind: String)
## side is "left", "right" or "any": the hand that gets the counter bonus.
signal counter_ready_changed(ready: bool, side: String)
## One-line status of the class special, for the HUD.
signal class_status_changed(text: String)
## A class special just fired (e.g. "SHOCKWAVE!").
signal class_event(text: String)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025
const MAX_COMBO_MULTIPLIER := 4.0
const INPUT_BUFFER_TIME := 0.2

## Seconds after a successful dodge during which the next punch can counter.
const COUNTER_WINDOW := 1.5
const COUNTER_MULTIPLIER := 2.0
## Fraction of damage taken when a defense was timed but was the wrong one.
const GRAZE_MULTIPLIER := 0.4
## Seconds you can't punch after a clean hit.
const FLINCH_TIME := 0.35
const BACK_STEP_SPEED := 9.0

# Class specials.
const SUPER_ARMOR_RECHARGE := 8.0
const PERFECT_COUNTER_COOLDOWN := 12.0
const SHOCKWAVE_EVERY := 5
const SHOCKWAVE_RADIUS := 4.0
const SHOCKWAVE_STUN := 1.5
const COMBO_FREEZE_TIME := 1.0
const RUNNING_PUNCH_LUNGE := 6.0
const OPENER_MULTIPLIER := 2.0
const FINISHER_MULTIPLIER := 2.0
const FINISHER_HP_FRACTION := 0.3
## Sigil powers: a landing counts as a Ground Pound after this long in the air.
const GROUND_POUND_MIN_AIR_TIME := 0.3
## Chain Lightning fires on every this-many combo hits (Storm lowers it).
const CHAIN_LIGHTNING_EVERY := 5
## Plain jabs and crosses only build the combo this many hits in a row; past
## that they keep it alive but it won't grow until a set-up heavy, a counter,
## a dash jab or an air punch mixes it up.
const STRAIGHT_RUN_LIMIT := 4
## Max speed and time limit for gliding back to the spot a back step started from.
const BACK_STEP_RETURN_SPEED := 12.0
const BACK_STEP_RETURN_LIMIT := 0.35
## Second press of a movement key within this long of the first is a double tap.
const DOUBLE_TAP_TIME := 0.25
## Double tap W: a quick burst forward to close distance.
const FORWARD_DASH_SPEED := 14.0
const FORWARD_DASH_COOLDOWN := 0.5
## Head movement with each punch: [windup offset, windup roll, strike offset,
## strike roll] for a left-hand punch (mirrored for the right). Offsets are
## camera position (x right, y up, z back); roll tilts the view.
const PUNCH_HEAD := {
	"jab": [Vector3(0.0, 0.0, 0.03), 0.0, Vector3(0.04, -0.01, -0.07), -0.02],
	"cross": [Vector3(-0.05, 0.0, 0.05), 0.03, Vector3(0.08, -0.02, -0.12), -0.05],
	"hook": [Vector3(-0.07, -0.04, 0.02), 0.07, Vector3(0.1, -0.03, -0.05), -0.09],
	"uppercut": [Vector3(-0.05, -0.12, 0.03), 0.05, Vector3(0.04, 0.04, -0.06), -0.05],
}
## What double tapping each movement key does.
const DOUBLE_TAPS := {"move_forward": "forward_dash"}
## The "Double-tap A / D / S" dodge scheme adds these.
const DOUBLE_TAP_DODGES := {"move_left": "roll_left", "move_right": "roll_right", "move_back": "back_step"}
## Pressing a direction while holding Ctrl dodges. (Ctrl+W is left alone:
## browsers close the tab on it.) Shift is free to sprint in any direction.
const CTRL_DODGES := {"move_left": "roll_left", "move_right": "roll_right", "move_back": "back_step"}

# Keys: Q/E slip left/right, Ctrl+A/D roll left/right, Ctrl+S back step
# (double tap W dashes forward).
# window: seconds after the press during which an attack is dodged.
# recovery: extra seconds before another defense if nothing was dodged. Kept
# short so a missed dodge doesn't cost the rest of an enemy combo (the dummy's
# follow-up punches arrive ~0.55s apart).
# side: which hand counters afterwards.
const DEFENSES := {
	"slip_left": {"name": "SLIP", "window": 0.3, "recovery": 0.1, "side": "left"},
	"slip_right": {"name": "SLIP", "window": 0.3, "recovery": 0.1, "side": "right"},
	"roll_left": {"name": "ROLL", "window": 0.4, "recovery": 0.1, "side": "left"},
	"roll_right": {"name": "ROLL", "window": 0.4, "recovery": 0.1, "side": "right"},
	"back_step": {"name": "BACK STEP", "window": 0.35, "recovery": 0.15, "side": "any"},
}
## Weenie Hut Junior Mode looks for incoming attacks this far away.
const ASSIST_RANGE := 7.0
## After a graze you can defend again this soon, to react to the next punch.
const GRAZE_RECOVERY := 0.1
## A dodge whose attack lands within this long of the key press is "clean":
## a bigger slow-mo and +25% damage on the counter.
const CLEAN_DODGE_TIME := 0.12
const CLEAN_COUNTER_BONUS := 0.25

# Crypt item specials.
const RHYTHM_MAX := 1.0
const FROST_RADIUS := 3.5
const FROST_TIME := 2.0
const FROST_SLOW := 0.4
const DASH_JAB_WINDOW := 0.45
## The Stray's dash punches: a punch thrown within DASH_PUNCH_WINDOW of a
## forward dash. Left: a Spear Jab through everything in a line. Right: a
## Haymaker that blasts the target (and anyone beside it) back.
const DASH_PUNCH_WINDOW := 0.55
const SPEAR_JAB_MULTIPLIER := 1.8
const SPEAR_JAB_REACH := 5.0
const SPEAR_JAB_WIDTH := 1.0
const HAYMAKER_MULTIPLIER := 2.4
const HAYMAKER_KNOCKBACK := 3.5
const HAYMAKER_SPLASH := 2.6
const SPEAR_REACH := 4.0
const SPEAR_WIDTH := 0.9
const SHATTER_RADIUS := 2.5
const LAST_STAND_LOW := 0.3
const GHOST_TIME := 1.5
const SLIPKNOT_CHAIN := 3
const BONE_BREAKER_EVERY := 5
const LONG_COUNT_STUN := 3.0
const FOLLOW_UP_DELAY := 0.14

## Which defenses beat each enemy attack. An enemy's jab comes from its left
## hand, on the player's right, so it is slipped to the right, and so on.
const ANSWERS := {
	"jab": ["slip_right"],
	"cross": ["slip_left"],
	"left_hook": ["roll_right"],
	"right_hook": ["roll_left"],
	"uppercut": ["back_step"],
	"slam": ["back_step"],
	"arrow": ["slip_left", "slip_right"],
	"haymaker": ["roll_left", "roll_right"],
	"staff": ["roll_left", "roll_right"],
	"thrust": ["slip_left", "slip_right"],
	"slash": ["roll_left", "roll_right"],
	"fireball": ["slip_left", "slip_right"],
	"bash": ["slip_left", "slip_right"],
	"claw": ["roll_left", "roll_right"],
	"sweep": ["roll_left", "roll_right"],
	"bite": ["back_step"],
	# A Hulk's ground smash can't be slipped: jump over it or get out of range.
	"quake": [],
}

# mult: damage multiplier (heavy punches only get it after a setup).
# knuckle_cost: knuckle HP every landed punch costs, whatever it hits.
# impact: seconds from click until the hit lands. cooldown: seconds before the
# next punch. knockback: push speed given to the enemy. hitstop: freeze-frame
# length on impact. heavy: hooks/uppercuts, which stagger when set up.
const PUNCHES := {
	"jab": {"mult": 1.0, "knuckle_cost": 1.0, "impact": 0.09, "cooldown": 0.28, "shake": 0.015, "knockback": 2.0, "hitstop": 0.03, "heavy": false},
	"cross": {"mult": 1.3, "knuckle_cost": 1.0, "impact": 0.11, "cooldown": 0.34, "shake": 0.02, "knockback": 3.0, "hitstop": 0.04, "heavy": false},
	"hook": {"mult": 2.0, "knuckle_cost": 2.0, "impact": 0.18, "cooldown": 0.5, "shake": 0.035, "knockback": 5.0, "hitstop": 0.07, "heavy": true},
	"uppercut": {"mult": 2.6, "knuckle_cost": 3.0, "impact": 0.22, "cooldown": 0.62, "shake": 0.045, "knockback": 4.0, "hitstop": 0.08, "heavy": true},
}
## Counter Master: chance a counter costs no knuckle HP.
const COUNTER_MASTER_FREE_CHANCE := 0.5

## False once the run is over (knuckles broke or the player gave up).
var active := true
## True after a win: nothing can hurt you while the crowd roars.
var invulnerable := false
## How long knock_out() plays before the screen is fully black.
const KNOCKOUT_TIME := 2.6
var max_knuckles := 0.0
var knuckles := 0.0
var combo := 0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _last_hand := ""
## Hand of the last punch thrown; hook/uppercut buttons use the other one.
var _last_punch_hand := "right"
## Side of an assisted (Weenie Hut Junior) dodge still waiting for its attack.
var _assist_side := ""
## "spear" / "haymaker" while the Stray's dash punch is landing.
var _dash_style := ""
var _last_type := ""
var _combo_timer := 0.0
var _cooldown := 0.0
var _buffered_hand := ""
var _buffered_type := ""
var _buffer_timer := 0.0
var _shake := 0.0
var _defense := ""
var _defense_timer := 0.0
var _defense_cooldown := 0.0
var _counter_timer := 0.0
var _counter_side := ""
var _flinch_timer := 0.0
var _dash := Vector3.ZERO
var _jump_requested := false
var _back_step_origin := Vector3.INF
var _return_time := 0.0
var _armor_charges := 0
## Tony's Fuggedaboudit: seconds until it can wave off another hit.
var _fugget_cooldown := 0.0
const FUGGET_TIME := 10.0
const FUGGET_METER := 8.0
var _armor_recharge := 0.0
## True when the ready counter came from super armor (Retaliation).
var _counter_from_armor := false
var _air_time := 0.0
var _perfect_cooldown := 0.0
var _combo_freeze := 0.0
var _class_status := ""
var _lean_tween: Tween
## Time each movement key was last pressed, for double taps.
var _last_tap := {}
## A movement key that just triggered a dodge stops moving the player until
## it's released, so holding the second tap doesn't drift you out of range.
var _suppressed_move := ""
var _forward_dash_cooldown := 0.0
var _defense_window := 0.0
## The ready counter came from a clean dodge.
var _clean_counter := false
## Combo multiplier added by Rhythm (dodges), lost when hit.
var _rhythm := 0.0
## Plain jabs/crosses in a row (see STRAIGHT_RUN_LIMIT).
var _straight_run := 0
## Did the last landed punch raise the combo? (Lightning only fires on growth.)
var _combo_grew := false
var _mix_hint_time := -100.0
## Whoever attacked last (Thunderhead strikes them on a clean dodge).
var _last_attacker: Enemy
var _dash_jab_time := 0.0
var _ghost_time := 0.0
var _dodge_chain := 0
var _hook_count := 0
var _iron_will_ready := true
var _long_count_ready := true
## The next punch's knuckle cost is waived (Champion's Hands follow-ups).
var _free_punch := false
## Multiplies what each punch costs in knuckle HP (Night 1 halves it).
var punch_cost_scale := 1.0
## Camera offsets, combined each frame: dodge leans and punch head movement.
var _lean_pos := Vector3.ZERO
var _lean_roll := 0.0
## The knockout fall: the view drops to the floor and tips over.
var _ko_pos := Vector3.ZERO
var _ko_roll := 0.0
var _punch_pos := Vector3.ZERO
var _punch_roll := 0.0
var _head_tween: Tween
var _fov_tween: Tween
## The class ultimate and its meter.
var ult: Ult

@onready var _camera: Camera3D = $Camera3D
@onready var _punch_ray: RayCast3D = $Camera3D/PunchRay
@onready var _fists: Fists = $Camera3D/Fists
@onready var _camera_rest: Vector3 = _camera.position


func _ready() -> void:
	_punch_ray.add_exception(self)
	max_knuckles = GameState.get_max_knuckles()
	knuckles = max_knuckles
	if GameState.is_player_class("berserker"):
		_armor_charges = _max_armor_charges()
	_camera.fov = Settings.fov()
	Settings.changed.connect(func() -> void: _camera.fov = Settings.fov())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The lantern lights the world, not the hands (they have their own light).
	$Camera3D/Lantern.light_cull_mask &= ~Fists.HAND_LAYER
	ult = Ult.new()
	ult.player = self
	add_child(ult)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := MOUSE_SENSITIVITY * Settings.mouse_sensitivity()
		rotate_y(-event.relative.x * sensitivity)
		_camera.rotate_x(-event.relative.y * sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clicking back into the window after alt-tabbing recaptures the mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif Controls.direct_punches() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Hook/uppercut buttons (scroll wheel or side buttons, by scheme).
		for type in ["hook", "uppercut"]:
			if event.is_action_pressed("punch_" + type):
				if ult.mode == "time_stop":
					ult.answer_direct(type)
				elif not ult.busy():
					_buffered_hand = "left" if _last_punch_hand == "right" else "right"
					_buffered_type = type
					_buffer_timer = INPUT_BUFFER_TIME
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_camera_shake(delta)
	if not active:
		return
	if ult.busy():
		return  # Temporal Break / Highlight Reel take over the controls.

	_cooldown -= delta
	_flinch_timer -= delta
	_dash_jab_time -= delta
	_ghost_time -= delta
	_defense_cooldown -= delta
	_defense_timer -= delta
	if _defense_timer <= 0.0:
		_defense = ""
		_assist_side = ""
	if _counter_timer > 0.0:
		_counter_timer -= delta
		if _counter_timer <= 0.0:
			_clear_counter()
	if combo > 0:
		if _combo_freeze > 0.0:
			_combo_freeze -= delta
		else:
			_combo_timer -= delta
			if _combo_timer <= 0.0:
				_set_combo(0)
	_update_class_timers(delta)

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_action_just_pressed("slip_left"):
			_dodge_key("left")
		elif Input.is_action_just_pressed("slip_right"):
			_dodge_key("right")
		elif Input.is_action_just_pressed("jump"):
			_jump_requested = true
		_check_movement_moves()
		if Input.is_action_just_pressed("ultimate"):
			ult.activate()
		if Input.is_action_just_pressed("punch_left"):
			_buffer_punch("left")
		elif Input.is_action_just_pressed("punch_right"):
			_buffer_punch("right")

	_buffer_timer -= delta
	if _buffered_hand != "" and _buffer_timer <= 0.0:
		_buffered_hand = ""
	if _buffered_hand != "" and _cooldown <= 0.0 and _flinch_timer <= 0.0:
		_punch(_buffered_type, _buffered_hand)
		_buffered_hand = ""


func _physics_process(delta: float) -> void:
	if ult.busy():
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var direction := Vector3.ZERO
	var speed := WALK_SPEED
	if active:
		if _jump_requested and is_on_floor():
			velocity.y = JUMP_VELOCITY * (1.0 + GameState.get_effect("jump_bonus"))
		_jump_requested = false
		if _suppressed_move != "" and not Input.is_action_pressed(_suppressed_move):
			_suppressed_move = ""
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if _suppressed_move != "":
			match _suppressed_move:
				"move_left", "move_right":
					input_dir.x = 0.0
				"move_back":
					input_dir.y = minf(input_dir.y, 0.0)
			input_dir = input_dir.normalized() if input_dir.length() > 1.0 else input_dir
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if Input.is_action_pressed("sprint"):
			speed = SPRINT_SPEED * GameState.get_sprint_multiplier()
		speed *= GameState.get_move_speed_multiplier()

	if _dash.length_squared() > 0.01:
		velocity.x = _dash.x
		velocity.z = _dash.z
		_dash = _dash.move_toward(Vector3.ZERO, 45.0 * delta)
	elif _back_step_origin != Vector3.INF and _defense != "back_step":
		_return_from_back_step(delta)
	elif direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	var was_airborne := not is_on_floor()
	move_and_slide()
	_fists.move_amount = minf(Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED, 1.0)
	_check_ground_pound(was_airborne, delta)


## An enemy attack reaches the player. attack is an ANSWERS key. Returns
## "dodged" (right defense), "grazed" (a timed but wrong defense), "armored"
## (Berserker super armor absorbed it) or "hit".
## attacker: the enemy throwing it, for melee attacks (Thorns hits it back).
func receive_attack(amount: float, from: Vector3, attack: String, attacker: Node3D = null) -> String:
	_last_attacker = attacker as Enemy
	# Wise Up: an enraged monster hits Tony harder.
	if _last_attacker and _last_attacker.is_taunted():
		amount *= Enemy.TAUNT_DEALT
	if not active:
		return "dodged"
	var intercepted := ult.intercept_attack(attack, attacker)
	if intercepted != "":
		return intercepted
	if attack == "quake":
		if not is_on_floor():
			# Jumped the shockwave: counts as a dodge, with a counter from either hand.
			TimeFx.slowmo(0.7, 0.15)
			Sfx.play("slip")
			dodged.emit("jump")
			_ready_counter("any")
			return "dodged"
	elif _defense != "":
		var move := _defense
		# Pressed late, right before the hit: a clean dodge.
		var since_press := _defense_window - _defense_timer
		_defense = ""
		_defense_timer = 0.0
		# Weenie Hut Junior Mode forgives a different attack than predicted, as
		# long as the key went to a side that beats it.
		if not move in ANSWERS.get(attack, []) and _assist_side != "":
			var swapped := _assisted_move(attack, _assist_side)
			if swapped != "":
				move = swapped
		_assist_side = ""
		if move in ANSWERS.get(attack, []):
			_on_dodge(move, since_press <= CLEAN_DODGE_TIME)
			return "dodged"
		_defense_cooldown = minf(_defense_cooldown, GRAZE_RECOVERY)
		Sfx.play("block", -6.0, 0.7)
		grazed.emit()
		_dodge_chain = 0
		_take_damage(amount * GRAZE_MULTIPLIER * (1.0 - GameState.get_effect("graze_reduction")), attacker)
		return "grazed"
	# Gravewalker Boots: right after a dodge, the next attack hits your ghost.
	if _ghost_time > 0.0:
		_ghost_time = 0.0
		Sfx.play("slip", -4.0, 1.3)
		dodged.emit("ghost")
		return "dodged"
	# Iron Will: the first hit in each room is blocked.
	if _iron_will_ready and GameState.has_effect("iron_will"):
		_iron_will_ready = false
		Sfx.play("block", -2.0, 0.8)
		class_event.emit("IRON WILL")
		return "armored"
	# Tony: Fuggedaboudit waves off one hit every 10s, with a quip.
	if GameState.is_player_class("wise_guy") and _fugget_cooldown <= 0.0:
		_fugget_cooldown = maxf(3.0, FUGGET_TIME - GameState.get_effect("fugget_cut"))
		Sfx.play("block", -2.0, 1.25)
		class_event.emit("FUGGEDABOUDIT!")
		ult.say(Insults.quip())
		var patch_up := GameState.get_effect("fugget_heal")
		if patch_up > 0.0:
			heal(max_knuckles * patch_up)
		ult.add(FUGGET_METER)
		return "armored"
	if _armor_charges > 0:
		# Berserker super armor: takes the damage, but no flinch or hit feedback,
		# and gets to counter.
		_armor_charges -= 1
		_armor_recharge = _armor_recharge_time()
		_take_damage(amount * (1.0 - GameState.get_effect("armor_absorb_reduction")), attacker)
		_ready_counter("any")
		_counter_from_armor = true
		ult.on_super_armor(attacker)
		return "armored"
	_shake = maxf(_shake, 0.08)
	_flinch_timer = FLINCH_TIME * (1.0 - GameState.get_effect("flinch_reduction"))
	_buffered_hand = ""
	_set_combo(0)
	_fists.flinch()
	Sfx.play("hurt")
	attacked.emit(from)
	# Rhythm and dodge chains are lost on a clean hit.
	_rhythm = 0.0
	_dodge_chain = 0
	ult.on_hit()
	_take_damage(amount, attacker)
	return "hit"


## Knuckle damage from an attack; Thorns hits the attacker back for what it cost.
func _take_damage(amount: float, attacker: Node3D) -> void:
	var before := knuckles
	hurt_knuckles(amount)
	var lost := before - knuckles
	if lost > 0.0:
		damage_taken.emit(lost)
	var thorns := GameState.get_effect("thorns")
	var enemy := attacker as Enemy
	if thorns > 0.0 and enemy and not enemy.is_dead() and before > knuckles:
		enemy.take_hit((before - knuckles) * thorns, enemy.global_position + Vector3(0, 1.2, 0), Vector3.ZERO, false, "THORNS", true)


## A Crypt room's fight starts: Iron Will is ready again.
func on_room_start() -> void:
	_iron_will_ready = true


## A new Crypt floor: The Long Count is ready again.
func on_floor_start() -> void:
	_long_count_ready = true
	on_room_start()


func heal(amount: float) -> void:
	if not active or amount <= 0.0:
		return
	# Bloodbath (Blood capstone): double healing under half knuckle HP.
	if GameState.has_effect("bloodbath") and knuckles < max_knuckles * 0.5:
		amount *= 2.0
	knuckles = minf(max_knuckles, knuckles + amount)
	knuckles_changed.emit(knuckles, max_knuckles)
	_fists.set_hurt(1.0 - knuckles / max_knuckles)


## Back to full knuckles and fighting again (used by the training ground).
func restore() -> void:
	active = true
	knuckles = max_knuckles
	knuckles_changed.emit(knuckles, max_knuckles)
	_fists.set_hurt(0.0)


## Like the start of a new run: full knuckles, no combo or pending counter,
## class specials ready (used when continuing into the next night).
func start_fresh() -> void:
	restore()
	_rhythm = 0.0
	_dodge_chain = 0
	_ghost_time = 0.0
	_set_combo(0)
	_clear_counter()
	_flinch_timer = 0.0
	_perfect_cooldown = 0.0
	if GameState.is_player_class("berserker"):
		_armor_charges = _max_armor_charges()


## Between Dead League rounds: keep the bout's attrition, but clear any stale
## combo/counter state and recover a small corner-rest share of max knuckles.
func prepare_bout_round(recovery_fraction: float) -> void:
	active = true
	heal(max_knuckles * recovery_fraction)
	_set_combo(0)
	_clear_counter()
	_flinch_timer = 0.0
	_defense = ""
	_defense_timer = 0.0


## Re-reads max knuckle HP after equipment changes. Gaining max HP also
## gains that much current HP; losing it only caps it.
func refresh_max_knuckles() -> void:
	var new_max := GameState.get_max_knuckles()
	knuckles = clampf(knuckles + maxf(0.0, new_max - max_knuckles), 0.0, new_max)
	max_knuckles = new_max
	knuckles_changed.emit(knuckles, max_knuckles)


## Shakes the camera (e.g. a nearby ground smash).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Knuckle damage from enemy hits. Defense reduces it; Glass Jaw raises it;
## Grit lowers it while knuckles are low.
func hurt_knuckles(amount: float) -> void:
	var taken := amount * GameState.get_knuckle_loss_multiplier() * (1.0 + GameState.get_effect("damage_taken"))
	if knuckles < max_knuckles * LAST_STAND_LOW:
		taken *= 1.0 - GameState.get_effect("grit")
	_lose_knuckles(taken)


func _lose_knuckles(amount: float) -> void:
	if not active or invulnerable:
		return
	knuckles = maxf(0.0, knuckles - amount)
	if knuckles <= 0.0 and _long_count_ready and GameState.has_effect("long_count"):
		# The Long Count: back up at 1 HP, and everything nearby is stunned.
		_long_count_ready = false
		knuckles = 1.0
		class_event.emit("THE LONG COUNT!")
		TimeFx.slowmo(0.4, 0.4)
		Sfx.play("counter", 0.0, 0.6)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and not enemy.is_dead() and enemy.global_position.distance_to(global_position) < 25.0:
				enemy.stun(LONG_COUNT_STUN)
	knuckles_changed.emit(knuckles, max_knuckles)
	_fists.set_hurt(1.0 - knuckles / max_knuckles)
	if knuckles <= 0.0:
		active = false
		_set_combo(0)
		_clear_counter()
		knuckles_broken.emit()


## The first-person knockout: a woozy stagger, then the legs go and the view
## tips over onto the floor. The HUD handles the red, then black. Takes
## KNOCKOUT_TIME.
func knock_out() -> void:
	active = false
	_set_combo(0)
	_clear_counter()
	var side := -1.0 if randf() < 0.5 else 1.0
	var floor_drop := -(_camera_rest.y - 0.22)
	var fall := create_tween()
	# Woozy: the head lolls the other way and sinks a little.
	fall.tween_property(self, "_ko_roll", -0.14 * side, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fall.parallel().tween_property(self, "_ko_pos", Vector3(0, -0.18, 0), 0.45).set_trans(Tween.TRANS_SINE)
	fall.parallel().tween_property(_fists, "drop", 0.2, 0.45)
	# Then the legs go: over sideways and down.
	fall.tween_property(self, "_ko_roll", 1.4 * side, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(self, "_ko_pos", Vector3(0.3 * side, floor_drop, 0.1), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(_camera, "rotation:x", 0.12, 0.7)
	fall.parallel().tween_property(_fists, "drop", 1.3, 0.45).set_delay(0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Hitting the canvas: a thud, a jolt and a small bounce.
	fall.tween_callback(func() -> void:
		_shake = 0.05
		Sfx.play("death", 2.0, 0.6))
	fall.tween_property(self, "_ko_roll", 1.28 * side, 0.1).set_ease(Tween.EASE_OUT)
	fall.parallel().tween_property(self, "_ko_pos:y", floor_drop + 0.05, 0.1).set_ease(Tween.EASE_OUT)
	fall.tween_property(self, "_ko_roll", 1.4 * side, 0.18).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(self, "_ko_pos:y", floor_drop, 0.18).set_ease(Tween.EASE_IN)


func get_combo_multiplier() -> float:
	var base := 1.0 if combo <= 1 else 1.0 + GameState.get_combo_step() * (combo - 1)
	return minf(base + _rhythm, MAX_COMBO_MULTIPLIER)


## True during a back step, which may carry the player out of reach of the
## attack it's dodging; attackers should still resolve against it.
func is_back_stepping() -> bool:
	return _defense == "back_step"


func is_counter_ready() -> bool:
	return _counter_timer > 0.0


# --- Defense ---------------------------------------------------------------------

## Rolls, the back step and the forward dash, by the dodge scheme (Controls):
## modifier (Ctrl or Space) + A/D/S (Space + W dashes too), or double taps.
## Double-tapping W always dashes.
func _check_movement_moves() -> void:
	_forward_dash_cooldown -= get_process_delta_time()
	var scheme := Controls.dodges()
	if scheme == "keys":
		# Rolls on their own keys (Tab / R).
		if Input.is_action_just_pressed("roll_left_key"):
			_do_move("roll_left")
			return
		if Input.is_action_just_pressed("roll_right_key"):
			_do_move("roll_right")
			return
	if scheme != "double_tap" and Input.is_action_pressed("dodge_modifier"):
		var moves := CTRL_DODGES.duplicate()
		if scheme == "space":
			moves["move_forward"] = "forward_dash"
		var modifier_now := Input.is_action_just_pressed("dodge_modifier")
		for key in moves:
			# The direction pressed with the modifier held, or the other way round.
			if Input.is_action_just_pressed(key) or (modifier_now and Input.is_action_pressed(key)):
				# The dodge key doesn't walk you anywhere until it's released.
				if key != "move_forward":
					_suppressed_move = key
				_do_move(moves[key])
				return
	var taps := DOUBLE_TAPS.duplicate()
	if scheme == "double_tap":
		taps.merge(DOUBLE_TAP_DODGES)
	var now := Time.get_ticks_msec() / 1000.0
	for key in taps:
		if not Input.is_action_just_pressed(key):
			continue
		if now - _last_tap.get(key, -10.0) <= DOUBLE_TAP_TIME:
			_last_tap[key] = -10.0  # A third tap starts a new double tap.
			_do_move(taps[key])
		else:
			_last_tap[key] = now


func _do_move(move: String) -> void:
	if move == "forward_dash":
		_forward_dash()
	else:
		_try_defense(move)


func _forward_dash() -> void:
	if _forward_dash_cooldown > 0.0 or _flinch_timer > 0.0:
		return
	_forward_dash_cooldown = FORWARD_DASH_COOLDOWN
	_dash_jab_time = DASH_PUNCH_WINDOW if GameState.is_player_class("free_runner") else DASH_JAB_WINDOW
	_dash = -global_basis.z * FORWARD_DASH_SPEED
	_dash.y = 0.0
	Sfx.play("whoosh", -6.0, 0.7)
	if _fov_tween:
		_fov_tween.kill()
	_fov_tween = create_tween()
	_fov_tween.tween_property(_camera, "fov", Settings.fov() + 8.0, 0.08)
	_fov_tween.tween_property(_camera, "fov", Settings.fov(), 0.25)


## Q / E. In Pro Gamer Mode a slip; in Weenie Hut Junior Mode the dodge that
## beats the attack coming in, as long as it goes to that side (back steps
## and "either side" dodges accept both keys).
func _dodge_key(side: String) -> void:
	if not Controls.junior():
		_try_defense("slip_" + side)
		return
	var move := "slip_" + side
	var attack := _incoming_attack()
	if attack != "":
		var pick := _assisted_move(attack, side)
		if pick != "":
			move = pick
	_try_defense(move)
	if _defense == move:
		_assist_side = side


## The most urgent attack being wound up at the player, by an enemy in reach.
func _incoming_attack() -> String:
	var best := ""
	var soonest := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var attack := enemy.incoming_attack()
		if attack == "" or enemy.global_position.distance_to(global_position) > ASSIST_RANGE:
			continue
		var eta := enemy.attack_eta()
		if eta < soonest:
			soonest = eta
			best = attack
	return best


## The answer to attack that dodges toward side ("" if none goes that way).
func _assisted_move(attack: String, side: String) -> String:
	for move in ANSWERS.get(attack, []):
		var move_side: String = DEFENSES[move].side
		if move_side == side or move_side == "any":
			return move
	return ""


func _try_defense(move: String) -> void:
	if _defense_cooldown > 0.0:
		return
	var defense: Dictionary = DEFENSES[move]
	var window: float = defense.window * GameState.get_dodge_window_multiplier()
	_defense = move
	_defense_timer = window
	_defense_window = window
	_defense_cooldown = window + defense.recovery
	_animate_defense(move)
	Sfx.play("whoosh", -6.0, 0.8 if move.begins_with("slip") else 0.6)


## After a back step's window (or as soon as it dodges), glide back to where
## it started so the player is in range to counter.
func _return_from_back_step(delta: float) -> void:
	var to_origin := _back_step_origin - global_position
	to_origin.y = 0.0
	_return_time += delta
	if to_origin.length() < 0.05 or _return_time > BACK_STEP_RETURN_LIMIT:
		_back_step_origin = Vector3.INF
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var speed := minf(to_origin.length() / delta, BACK_STEP_RETURN_SPEED)
	velocity.x = to_origin.normalized().x * speed
	velocity.z = to_origin.normalized().z * speed


## clean: pressed late, right before the hit landed.
func _on_dodge(move: String, clean := false) -> void:
	_defense_cooldown = 0.0  # A dodge can be chained straight into the next one.
	if move == "back_step":
		_dash = Vector3.ZERO  # Dodged: head straight back in to counter.
	Sfx.play("slip")
	_ready_counter(DEFENSES[move].side)
	if clean:
		TimeFx.slowmo(0.5, 0.2)
		Sfx.play("tell", -2.0, 1.4)
		_clean_counter = true
		heal(GameState.heal_amount("clean_read", max_knuckles))
		_thunderhead()
		ult.on_dodge(true)
		dodged.emit("clean_" + move)
	else:
		ult.on_dodge(false)
		TimeFx.slowmo(0.7, 0.15)
		dodged.emit(move)
	_on_dodge_specials(move)


## Item specials that trigger on a successful dodge.
func _on_dodge_specials(move: String) -> void:
	var rhythm := GameState.get_effect("rhythm")
	if rhythm > 0.0:
		_rhythm = minf(_rhythm + rhythm, RHYTHM_MAX)
		combo_changed.emit(combo, get_combo_multiplier())
	if move != "back_step" and randf() < GameState.get_effect("frost_slip"):
		HitFx.burst(get_parent(), global_position + Vector3(0, 1.0, 0), Vector3.UP, Enemy.FROST_COLOR, 24, 4.0, true, 0.06)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= FROST_RADIUS:
				enemy.chill(FROST_TIME, FROST_SLOW)
	_dodge_chain += 1
	var slipknot := GameState.get_effect("slipknot")
	if slipknot > 0.0 and _dodge_chain >= SLIPKNOT_CHAIN:
		_dodge_chain = 0
		heal(slipknot * max_knuckles / 100.0)
		class_event.emit("SLIPKNOT")
	if GameState.has_effect("gravewalker"):
		_ghost_time = GHOST_TIME


func _ready_counter(side: String) -> void:
	_counter_timer = COUNTER_WINDOW + GameState.get_counter_window_bonus()
	_counter_side = side
	_counter_from_armor = false
	counter_ready_changed.emit(true, side)


func _clear_counter() -> void:
	_clean_counter = false
	if _counter_side == "":
		return
	_counter_timer = 0.0
	_counter_side = ""
	_counter_from_armor = false
	counter_ready_changed.emit(false, "")


## Camera motion for each defense: slips lean, rolls dip under and come up to
## the side, the back step hops backward.
func _animate_defense(move: String) -> void:
	if _lean_tween:
		_lean_tween.kill()
	_lean_tween = create_tween()
	var window: float = DEFENSES[move].window
	var side := -1.0 if move.ends_with("left") else 1.0
	match move:
		"slip_left", "slip_right":
			_lean_tween.tween_property(self, "_lean_pos", Vector3(0.45 * side, -0.2, 0), 0.08) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_lean_tween.parallel().tween_property(self, "_lean_roll", -0.18 * side, 0.08)
			_lean_tween.tween_interval(window - 0.08)
		"roll_left", "roll_right":
			# Down and across in a U, ending on the dodge side.
			_lean_tween.tween_property(self, "_lean_pos", Vector3(0.15 * side, -0.55, 0), 0.12) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_lean_tween.parallel().tween_property(self, "_lean_roll", -0.25 * side, 0.12)
			_lean_tween.tween_property(self, "_lean_pos", Vector3(0.5 * side, -0.25, 0), window - 0.12) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"back_step":
			_back_step_origin = global_position
			_return_time = 0.0
			_dash = global_basis.z * BACK_STEP_SPEED
			_dash.y = 0.0
			_lean_tween.tween_property(self, "_lean_pos", Vector3(0, -0.1, 0.15), 0.1)
			_lean_tween.tween_interval(window - 0.1)
	_lean_tween.tween_property(self, "_lean_pos", Vector3.ZERO, 0.2).set_trans(Tween.TRANS_SINE)
	_lean_tween.parallel().tween_property(self, "_lean_roll", 0.0, 0.2)


# --- Punching ---------------------------------------------------------------------

func _buffer_punch(hand: String) -> void:
	# Punch type is decided at click time so Shift/Ctrl only need to be held when clicking.
	_buffered_hand = hand
	_buffered_type = _punch_type_for(hand)
	_buffer_timer = INPUT_BUFFER_TIME


func _punch_type_for(hand: String) -> String:
	if Controls.direct_punches():
		# Hooks and uppercuts have their own buttons in this scheme.
		return "jab" if hand == "left" else "cross"
	if Input.is_action_pressed("uppercut_modifier"):
		return "uppercut"
	if Input.is_action_pressed("sprint"):
		return "hook"
	return "jab" if hand == "left" else "cross"


func _punch(type: String, hand: String) -> void:
	_last_punch_hand = hand
	var punch: Dictionary = PUNCHES[type]
	var speed := GameState.get_punch_speed()
	var impact: float = punch.impact / speed
	_cooldown = punch.cooldown / speed
	_fists.play_punch(type, hand, impact, _cooldown)
	_animate_head(type, hand, impact, _cooldown)
	# Free Runner moves are judged when the punch starts.
	var airborne := not is_on_floor()
	var style := ""
	# Only the straights: a jab spears, a cross is the haymaker. Hooks and
	# uppercuts out of a dash are just hooks and uppercuts.
	if GameState.is_player_class("free_runner") and _dash_jab_time > 0.0 and not airborne and type in ["jab", "cross"]:
		style = "spear" if type == "jab" else "haymaker"
		_dash_jab_time = 0.0
	await get_tree().create_timer(impact, false).timeout
	if active:
		_dash_style = style
		_land_punch(type, hand, style != "", airborne)
		_dash_style = ""


## forced: hit this enemy instead of whatever the punch ray finds (ultimates).
## bonus multiplies the damage; forced_caption goes above the number.
func _land_punch(type: String, hand: String, _dashing := false, airborne := false, forced: Enemy = null, bonus := 1.0, forced_caption := "") -> void:
	var target := forced
	var hit_point := Vector3.ZERO
	if target:
		if target.is_dead():
			return
		hit_point = target.global_position + Vector3(0, 1.3, 0)
	else:
		_punch_ray.force_raycast_update()
		target = _punch_ray.get_collider() as Enemy
		hit_point = _punch_ray.get_collision_point()
	if target == null and _dash_style == "spear":
		var line := _enemies_in_line(SPEAR_JAB_REACH, SPEAR_JAB_WIDTH)
		if not line.is_empty():
			target = line[0]
			hit_point = target.global_position + Vector3(0, 1.3, 0)
	if target == null:
		Sfx.play("whoosh", -10.0, 1.3)
		return  # Whiffs cost nothing and don't affect the combo.

	var counter_ready := is_counter_ready() and (_counter_side == "any" or _counter_side == hand)
	if target.phased(type, counter_ready):
		# Straight through a Wraith: costs nothing, like a whiff.
		Sfx.play("whoosh", -6.0, 1.6)
		DamagePopup.spawn(get_parent(), "PHASED", Color(0.7, 0.75, 1.0), 36, hit_point)
		return
	if target.blocks_punch(type, counter_ready):
		# Into a Shieldbearer's shield: the combo breaks and it still costs.
		Sfx.play("block", -2.0, 0.9)
		DamagePopup.spawn(get_parent(), "SHIELD", Color(0.75, 0.75, 0.8), 40, hit_point)
		_set_combo(0)
		punch_landed.emit("blocked", false)
		_pay_for_punch(PUNCHES[type], false)
		return
	target.take_turn()  # Punching an enemy pulls it into the fight.
	if target.try_evade(type, hand):
		# The enemy slipped it: no damage, combo broken, and expect a counter.
		Sfx.play("whoosh", -4.0, 1.1)
		_set_combo(0)
		punch_landed.emit("evaded", false)
		return

	var punch: Dictionary = PUNCHES[type]
	# Heavy punches only get their multiplier and stagger when they follow a
	# jab or cross from the other hand (jab -> right uppercut, jab-cross-hook...).
	# The Berserker's heavy punches don't need a setup.
	var set_up: bool = punch.heavy and (GameState.is_player_class("berserker") \
			or (combo > 0 and hand != _last_hand and _last_type in ["jab", "cross"]))
	# A counter only counts with the hand on the side you dodged to.
	var counter := is_counter_ready() and (_counter_side == "any" or _counter_side == hand)
	var retaliation := counter and _counter_from_armor
	var clean := counter and _clean_counter
	_clear_counter()
	# A jab thrown out of a forward dash (Lunging / Spear Jab).
	var dash_jab := type == "jab" and _dash_jab_time > 0.0
	if dash_jab:
		_dash_jab_time = 0.0
	var target_was_low := target.hp < target.max_hp * FINISHER_HP_FRACTION
	var target_was_fresh := target.hp >= target.max_hp

	# Alternating hands builds the combo; the same hand twice starts it over
	# (except jab, jab with the Double Jab skill).
	var double_jab: bool = type == "jab" and _last_type == "jab" and GameState.has_effect("double_jab")
	if hand == _last_hand and not double_jab:
		combo = 0
	_last_hand = hand
	_last_type = type
	_combo_timer = GameState.get_combo_window()
	var plain := type in ["jab", "cross"] and not counter and not dash_jab and is_on_floor()
	_straight_run = _straight_run + 1 if plain else 0
	_combo_grew = _straight_run <= STRAIGHT_RUN_LIMIT
	if _combo_grew:
		_set_combo(combo + 1)
	else:
		_set_combo(combo)
		var now := Time.get_ticks_msec() / 1000.0
		if _straight_run == STRAIGHT_RUN_LIMIT + 1 and now - _mix_hint_time > 10.0:
			_mix_hint_time = now
			class_event.emit("MIX IT UP  -  hooks, uppercuts and counters grow the combo")

	var raw_damage: float = GameState.get_damage() * get_combo_multiplier()
	if not punch.heavy or set_up:
		raw_damage *= punch.mult
	if set_up:
		raw_damage *= GameState.get_heavy_multiplier()
	if counter:
		raw_damage *= GameState.get_counter_multiplier(COUNTER_MULTIPLIER)
	if retaliation:
		raw_damage *= 1.0 + GameState.get_effect("retaliation_bonus")
	if target_was_low:
		raw_damage *= 1.0 + GameState.get_effect("finisher_bonus")
	if target.is_boss:
		raw_damage *= 1.0 + GameState.get_effect("boss_damage")
	# Risk specials: Glass Jaw, Blood Price, and Last Stand (more as knuckles fall).
	var missing := 1.0 - knuckles / max_knuckles
	raw_damage *= 1.0 + GameState.get_effect("glass_jaw") + GameState.get_effect("blood_price") \
			+ GameState.get_effect("last_stand") * missing
	if clean:
		raw_damage *= 1.0 + CLEAN_COUNTER_BONUS
	if dash_jab:
		raw_damage *= 1.0 + GameState.get_effect("lunging_jab")

	var caption := ""
	if set_up:
		caption = type.to_upper() + "!"
	if GameState.is_player_class("free_runner"):
		var jump_threshold := FINISHER_HP_FRACTION + GameState.get_effect("finisher_threshold")
		if _dash_style == "spear":
			raw_damage *= SPEAR_JAB_MULTIPLIER + GameState.get_effect("opener_bonus")
			caption = "SPEAR JAB!"
		elif _dash_style == "haymaker":
			raw_damage *= HAYMAKER_MULTIPLIER + GameState.get_effect("opener_bonus")
			caption = "HAYMAKER!"
		elif airborne and target.hp < target.max_hp * jump_threshold:
			raw_damage *= FINISHER_MULTIPLIER
			caption = "JUMP PUNCH!"
	if dash_jab and (GameState.has_effect("lunging_jab") or GameState.has_effect("spear_jab")):
		caption = "LUNGE!"
	if counter:
		caption = "CLEAN COUNTER!" if clean else "COUNTER!"
	# Executioner: a counter finishes off a weakened non-boss enemy.
	var crush := false
	if counter and not target.is_boss and target.hp < target.max_hp * GameState.get_effect("executioner"):
		raw_damage = target.hp + target.armor + 1.0
		crush = true
		caption = "EXECUTED!"
	# Bone Breaker: every 5th hook ignores all armor and reduction, and staggers.
	if type == "hook" and GameState.has_effect("bone_breaker"):
		_hook_count += 1
		if _hook_count % BONE_BREAKER_EVERY == 0:
			crush = true
			caption = "BONE BREAKER!"
	# Counter Master: a matching-hand hook/uppercut counter knocks out instantly.
	var perfect_punch: bool = punch.heavy or GameState.has_effect("perfect_any_punch")
	if counter and perfect_punch and GameState.is_player_class("counter_master") and _perfect_cooldown <= 0.0:
		raw_damage = target.get_knockout_damage()
		caption = "PERFECT KO!"
		_perfect_cooldown = PERFECT_COUNTER_COOLDOWN - GameState.get_effect("perfect_cooldown_cut")
		class_event.emit("PERFECT COUNTER!")

	# Weak spots (e.g. a Possessed Armor's sides, for hooks) hit harder and ignore armor.
	var weak := target.weak_spot_multiplier(type)
	if weak > 1.0:
		raw_damage *= weak
		caption = "WEAK SPOT!" if caption == "" else caption + "\nWEAK SPOT"

	raw_damage *= bonus
	if forced_caption != "":
		caption = forced_caption if caption == "" else forced_caption + "\n" + caption
	var push := target.global_position - global_position if forced else -_camera.global_basis.z
	push.y = 0.0
	push = push.normalized() * punch.knockback * (1.5 if counter else 1.0)
	if _dash_style == "haymaker":
		push *= HAYMAKER_KNOCKBACK
	# How the target flies if this punch finishes it (see Enemy.finisher).
	var finish_level := 2 if clean or caption == "PERFECT KO!" else (1 if counter else 0)
	var finish_dir := push.normalized() if push.length() > 0.01 else -global_basis.z
	target.finisher = {"type": _dash_style if _dash_style != "" else type, "hand": hand,
			"level": finish_level, "dir": finish_dir, "player": self}
	# Dive Kick: jump punches stagger.
	var dive_kick := airborne and GameState.has_effect("dive_kick")
	var big := forced != null and bonus > 1.0
	var staggers := set_up or counter or dive_kick or crush or big or _dash_style == "haymaker"
	var dealt := target.take_hit(raw_damage, hit_point, push, staggers, caption, weak > 1.0, crush)
	var killed := target.is_dead()
	if not killed:
		target.finisher = {}
	_dash_punch_splash(target, raw_damage, hand)
	_punch_specials(type, hand, target, raw_damage, counter, dash_jab, killed)

	var kind := "hit"
	if counter:
		kind = "counter"
	elif set_up:
		kind = "setup"
	elif dealt <= 0.0:
		kind = "blocked"
	_play_impact(punch, kind, killed)
	if forced == null:  # An ultimate's own punches don't recharge it.
		ult.on_punch(kind, clean, _dash_style != "")
	punch_landed.emit(kind, killed)
	punch_connected.emit(type, kind)
	_trigger_powers(target, raw_damage, set_up or counter, counter)
	# A same-hand repeat resets the combo to zero; zero is divisible by every
	# number, but it is not a combo milestone. Stalled straight-punch strings
	# likewise do not get free repeated shockwaves.
	if GameState.is_player_class("combo_master") and _combo_grew and combo > 0 \
			and combo % _shockwave_every() == 0:
		_shockwave()
	_pay_for_punch(punch, counter)


## The Stray's dash punches carry on past the target: a Spear Jab runs through
## everything in its line, a Haymaker blasts back whoever stands beside it.
func _dash_punch_splash(target: Enemy, damage: float, hand: String) -> void:
	if _dash_style == "spear":
		for enemy in _enemies_in_line(SPEAR_JAB_REACH, SPEAR_JAB_WIDTH):
			if enemy == target or enemy.is_dead():
				continue
			var forward := _flat_forward()
			enemy.finisher = {"type": "spear", "hand": hand, "level": 0, "dir": forward, "player": self}
			enemy.take_hit(damage * 0.8, enemy.global_position + Vector3(0, 1.2, 0), forward * 3.0, false, "SPEAR")
			if not enemy.is_dead():
				enemy.finisher = {}
	elif _dash_style == "haymaker":
		HitFx.ring(get_parent(), target.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.35), HAYMAKER_SPLASH)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or enemy == target or enemy.is_dead():
				continue
			var away := enemy.global_position - global_position
			away.y = 0.0
			if away.length() > HAYMAKER_SPLASH + 1.5 or away.normalized().dot(_flat_forward()) < 0.2:
				continue
			enemy.finisher = {"type": "haymaker", "hand": hand, "level": 0, "dir": away.normalized(), "player": self}
			enemy.take_hit(damage * 0.4, enemy.global_position + Vector3(0, 1.2, 0), away.normalized() * 9.0, true, "KNOCKED BACK")
			if not enemy.is_dead():
				enemy.finisher = {}


## Living enemies in a line straight ahead, nearest first.
func _enemies_in_line(reach: float, width: float) -> Array[Enemy]:
	var forward := _flat_forward()
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var along := offset.dot(forward)
		if along > 0.0 and along <= reach and (offset - forward * along).length() <= width:
			found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))
	return found


func _flat_forward() -> Vector3:
	var forward := -_camera.global_basis.z
	forward.y = 0.0
	return forward.normalized()


## Every landed punch costs a fixed amount of knuckle HP (Defense doesn't help);
## Hard Knuckles and the Counter Master sometimes make it free.
func _pay_for_punch(punch: Dictionary, counter: bool) -> void:
	var free_chance := GameState.get_effect("free_punch_chance")
	if counter and GameState.is_player_class("counter_master"):
		var counter_free := COUNTER_MASTER_FREE_CHANCE + GameState.get_effect("counter_free_bonus")
		free_chance = 1.0 - (1.0 - free_chance) * (1.0 - counter_free)
	if randf() < free_chance or _free_punch:
		_free_punch = false
		return
	var cost: float = punch.knuckle_cost
	if punch.heavy:
		cost = maxf(1.0, cost - GameState.get_effect("heavy_cost_cut"))
	cost += GameState.get_effect("blood_cost")
	_lose_knuckles(cost * punch_cost_scale)


## Item specials that trigger when a punch lands.
func _punch_specials(type: String, hand: String, target: Enemy, damage: float, counter: bool, dash_jab: bool, killed: bool) -> void:
	var base := GameState.get_damage()
	if not killed:
		if type == "jab" and GameState.has_effect("venom"):
			target.poison(base * GameState.get_effect("venom"))
		if type == "hook" and GameState.has_effect("serrated"):
			target.bleed(base * GameState.get_effect("serrated"))
	# Shatter: a counter bursts onto everything around the target.
	var shatter := GameState.get_effect("shatter")
	if counter and shatter > 0.0:
		var center := target.global_position
		HitFx.burst(get_parent(), center + Vector3(0, 1.2, 0), Vector3.UP, Color(0.85, 0.9, 1.0), 30, 6.0, true, 0.06)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy and enemy != target and not enemy.is_dead() and enemy.global_position.distance_to(center) <= SHATTER_RADIUS:
				var away := enemy.global_position - center
				away.y = 0.0
				enemy.take_hit(damage * shatter, enemy.global_position + Vector3(0, 1.2, 0), away.normalized() * 4.0, false, "SHATTER")
	# Spear Jab: a dash jab runs through everything in a line.
	if dash_jab and GameState.has_effect("spear_jab"):
		var forward := -_camera.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if not enemy or enemy == target or enemy.is_dead():
				continue
			var offset := enemy.global_position - global_position
			offset.y = 0.0
			var along := offset.dot(forward)
			if along > 0.0 and along <= SPEAR_REACH and (offset - forward * along).length() <= SPEAR_WIDTH:
				enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.2, 0), forward * 3.0, false, "SPEAR")
	# Champion's Hands: a counter throws a free follow-up with the other hand.
	if counter and GameState.has_effect("champions_hands"):
		var other := "right" if hand == "left" else "left"
		get_tree().create_timer(FOLLOW_UP_DELAY, false).timeout.connect(_follow_up.bind(other))


func _follow_up(hand: String) -> void:
	if not active:
		return
	var type := "jab" if hand == "left" else "cross"
	_free_punch = true
	_fists.play_punch(type, hand, 0.06, 0.2)
	_land_punch(type, hand)


# --- Sigil powers -----------------------------------------------------------------

## Sigil powers: heavies and counters (big hits) set off Fire and Frost, as
## does any hit by chance (Kindling, Cold Snap); every Nth combo hit (and with
## Conductor, every counter) sets off Chain Lightning; Blood heals on counters.
func _trigger_powers(target: Enemy, damage: float, big_hit: bool, counter := false) -> void:
	var fire := GameState.get_effect("fire_punch")
	if fire > 0.0 and (big_hit or randf() < GameState.get_effect("fire_chance")):
		Powers.fire_burst(target, damage * fire)
	if GameState.get_effect("frost_punch") > 0.0 and not target.is_dead() 			and (big_hit or randf() < GameState.get_effect("frost_chance")):
		Powers.frost_burst(target)
	var jumps := int(GameState.get_effect("chain_lightning"))
	var every := CHAIN_LIGHTNING_EVERY - int(GameState.get_effect("chain_every_cut"))
	if jumps > 0 and ((_combo_grew and combo % every == 0) or (counter and GameState.has_effect("chain_on_counter"))):
		# Lightning gets only half of the combo bonus.
		var multiplier := get_combo_multiplier()
		Powers.chain_lightning(target, damage / multiplier * (1.0 + (multiplier - 1.0) * 0.5), jumps)
	if counter:
		heal(GameState.heal_amount("counter_heal", max_knuckles))


## Thunderhead (Storm capstone): a clean dodge strikes the attacker, then arcs.
func _thunderhead() -> void:
	if not GameState.has_effect("thunderhead") or not is_instance_valid(_last_attacker) or _last_attacker.is_dead():
		return
	var damage := GameState.get_damage() * 2.0
	_last_attacker.take_hit(damage, _last_attacker.global_position + Vector3(0, 1.3, 0), Vector3.ZERO, true, "THUNDER")
	Powers.chain_lightning(_last_attacker, damage, maxi(2, int(GameState.get_effect("chain_lightning"))))


func _check_ground_pound(was_airborne: bool, delta: float) -> void:
	if not is_on_floor():
		_air_time += delta
		return
	var pound := GameState.get_effect("ground_pound")
	if was_airborne and active and pound > 0.0 and _air_time >= GROUND_POUND_MIN_AIR_TIME:
		Powers.ground_pound(self, GameState.get_damage() * pound)
		_shake = maxf(_shake, 0.09)
		_kick_fov(5.0)
	_air_time = 0.0


# --- Class specials ---------------------------------------------------------------

## Combo Master: every 5th hit stuns everything nearby and freezes the combo timer.
func _shockwave() -> void:
	var radius := SHOCKWAVE_RADIUS + GameState.get_effect("shockwave_radius")
	var stun := SHOCKWAVE_STUN + GameState.get_effect("shockwave_stun")
	var damage := GameState.get_damage() * GameState.get_effect("shockwave_damage")
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= radius:
			# Rolling Thunder: the shockwave hits too.
			if damage > 0.0:
				var away := enemy.global_position - global_position
				away.y = 0.0
				enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), away.normalized() * 3.0, false, "SHOCK")
			if not enemy.is_dead():
				enemy.stun(stun)
	_combo_freeze = COMBO_FREEZE_TIME
	HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, Color(1, 0.8, 0.3), 40, 7.0, true, 0.06)
	Sfx.play("counter", -2.0, 0.7)
	_kick_fov(5.0)
	class_event.emit("SHOCKWAVE!")


func _max_armor_charges() -> int:
	return 1 + int(GameState.get_effect("armor_charges"))


func _armor_recharge_time() -> float:
	return SUPER_ARMOR_RECHARGE - GameState.get_effect("armor_recharge_cut")


func _shockwave_every() -> int:
	return SHOCKWAVE_EVERY - int(GameState.get_effect("shockwave_every_cut"))


func _update_class_timers(delta: float) -> void:
	_perfect_cooldown = maxf(0.0, _perfect_cooldown - delta)
	_fugget_cooldown = maxf(0.0, _fugget_cooldown - delta)
	# Super armor charges come back one at a time.
	if GameState.is_player_class("berserker") and _armor_charges < _max_armor_charges():
		_armor_recharge -= delta
		if _armor_recharge <= 0.0:
			_armor_charges += 1
			_armor_recharge = _armor_recharge_time()
	var status: String = GameState.fighter_name()
	match GameState.player_class:
		"berserker":
			var max_charges := _max_armor_charges()
			if max_charges > 1:
				status += "  |  Super armor: %d / %d" % [_armor_charges, max_charges]
				if _armor_charges < max_charges:
					status += "  (next in %ds)" % ceili(_armor_recharge)
			else:
				status += "  |  Super armor: " + ("READY" if _armor_charges > 0 else "%ds" % ceili(_armor_recharge))
		"counter_master":
			status += "  |  Perfect counter: " + ("READY" if _perfect_cooldown <= 0.0 else "%ds" % ceili(_perfect_cooldown))
		"combo_master":
			status += "  |  Shockwave in %d hits" % (_shockwave_every() - combo % _shockwave_every())
		"free_runner":
			status += "  |  Dash (%s) then LMB spear / RMB haymaker  |  jump punch weak ones" % Controls.text("dash")
		"wise_guy":
			status += "  |  Fuggedaboudit: " + ("READY" if _fugget_cooldown <= 0.0 else "%ds" % ceili(_fugget_cooldown))
	if status != _class_status:
		_class_status = status
		class_status_changed.emit(status)
	_update_hand_effects()


## Tells the fists what to show: special ready, ultimate ready, counter hand.
func _update_hand_effects() -> void:
	var ability := false
	match GameState.player_class:
		"berserker":
			ability = _armor_charges > 0
		"counter_master":
			ability = _perfect_cooldown <= 0.0
		"combo_master":
			ability = combo >= 3
		"wise_guy":
			ability = _fugget_cooldown <= 0.0
	var hot := _counter_side if is_counter_ready() else ""
	_fists.set_power_state(ability, ult != null and ult.is_full(), hot)


func _play_impact(punch: Dictionary, kind: String, killed: bool) -> void:
	var hitstop: float = punch.hitstop
	var shake: float = punch.shake
	match kind:
		"counter":
			hitstop = 0.14
			shake = 0.07
			Sfx.play("counter")
			_kick_fov(6.0)
		"setup":
			Sfx.play("heavy")
			_kick_fov(3.0)
		"blocked":
			Sfx.play("block")
		_:
			Sfx.play("hit", 0.0, 1.0 + combo * 0.03)
	if killed:
		hitstop += 0.05
	TimeFx.hitstop(hitstop)
	_shake = maxf(_shake, shake)


func _kick_fov(amount: float) -> void:
	if _fov_tween:
		_fov_tween.kill()
	_camera.fov = Settings.fov() - amount
	_fov_tween = create_tween()
	_fov_tween.tween_property(_camera, "fov", Settings.fov(), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_combo(value: int) -> void:
	combo = value
	if combo == 0:
		_straight_run = 0
		_last_hand = ""
		_last_type = ""
	combo_changed.emit(combo, get_combo_multiplier())


## Head movement with a punch: load up during the windup, shift into the
## punch as it lands, then settle back to center.
func _animate_head(type: String, hand: String, impact: float, cooldown: float) -> void:
	var motion: Array = PUNCH_HEAD[type]
	var mirror := Vector3(1.0 if hand == "left" else -1.0, 1.0, 1.0)
	var roll_sign := 1.0 if hand == "left" else -1.0
	if _head_tween:
		_head_tween.kill()
	_head_tween = create_tween()
	_head_tween.tween_property(self, "_punch_pos", motion[0] * mirror, impact * 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_head_tween.parallel().tween_property(self, "_punch_roll", motion[1] * roll_sign, impact * 0.7)
	_head_tween.tween_property(self, "_punch_pos", motion[2] * mirror, impact * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_head_tween.parallel().tween_property(self, "_punch_roll", motion[3] * roll_sign, impact * 0.5)
	_head_tween.tween_property(self, "_punch_pos", Vector3.ZERO, maxf(cooldown, 0.2)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_head_tween.parallel().tween_property(self, "_punch_roll", 0.0, maxf(cooldown, 0.2))


func _update_camera_shake(delta: float) -> void:
	_camera.position = _camera_rest + _lean_pos + _punch_pos + _ko_pos
	_camera.rotation.z = _lean_roll + _punch_roll + _ko_roll
	_shake = move_toward(_shake, 0.0, delta * 0.25)
	var shake := _shake * Settings.screen_shake()
	_camera.h_offset = randf_range(-shake, shake)
	_camera.v_offset = randf_range(-shake, shake)
