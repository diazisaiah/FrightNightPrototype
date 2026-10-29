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
## The Endless powers' readouts for the HUD's power chip: [[root, text], ...].
signal power_status_changed(status: Array)
## A class special just fired (e.g. "SHOCKWAVE!").
signal class_event(text: String)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const JUMP_VELOCITY := 4.8
## Head Stomp (and the Parkour card) jump this much higher: a plain jump
## peaks around 1.2m, short of a monster's head (about 1.8m).
const STOMP_JUMP := 1.3
## A stomp counts from this far beside a monster, with your feet this far
## below the top of its head to this far above it, on the way down.
const STOMP_REACH := 1.0
const STOMP_BAND := Vector2(-0.35, 0.6)
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
const PERFECT_COUNTER_COOLDOWN := 12.0
## Perfect Counter's extra multiplier (2026-10-24: was an instant KO).
const PERFECT_COUNTER_BONUS := 2.5
const GRUDGE_MULT := 3.0
const WRECKING_DAMAGE := 1.1
const WRECKING_RADIUS := 1.8
const BERSERKER_MAX := 0.6
const PHANTOM_COOLDOWN := 3.0
const PHANTOM_BEHIND := 1.3
const DODGE_CHAIN_STEP := 0.4
const DODGE_CHAIN_MAX := 6
const ECHO_SHARE := 0.3
const ECHO_DELAY := 0.25
const ECHO_COMBO := 0.05
const PUNCH_REACH := 2.5
## The Blur's Long Reach, plus this per point of passive power (2026-10-29:
## was 3.8m + 0.1, up to 4.7m).
const LONG_REACH := 3.2
const LONG_REACH_PER_POWER := 0.05
const STOMP_STUN := 1.0
const STOMP_DAMAGE := 1.5
const MOMENTUM_BUILD := 2.0
const MOMENTUM_MAX := 1.0
const MUSCLE_EVERY := 15.0
const MUSCLE_HOLD := 2.0
const MUSCLE_RANGE := 8.0
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
## Seconds between landing shockwaves (Quaking boots), so hopping can't spam them.
const GROUND_POUND_COOLDOWN := 4.0
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
## Moves with a key of their own (Controls): rolls, the back step and the dash.
## Critical hits: x1.5 damage (plus crit_damage), at most a 50% chance.
const CRIT_MULTIPLIER := 1.5
const MAX_CRIT_CHANCE := 0.5
## After this many sloppy heavies in a row, a tip says how to set them up
## (at most once every SLOPPY_TIP_EVERY seconds).
const SLOPPY_TIP_AFTER := 3
const SLOPPY_TIP_EVERY := 25.0
## Right-stick look speed at full tilt (radians a second, before Settings).
const STICK_LOOK_SPEED := 3.4
const DEDICATED_MOVES := {"roll_left_key": "roll_left", "roll_right_key": "roll_right", "back_step_key": "back_step", "dash_key": "forward_dash"}
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
## 2026-10-29: was 5m (10m with Spear Line), skeletons speared from afar.
const SPEAR_JAB_REACH := 3.5
## Seconds before each dash punch comes back (2026-10-29: none before, so
## Haymakers kept everything knocked back and away). On cooldown, a dash
## punch is a plain one.
const SPEAR_JAB_COOLDOWN := 2.0
const HAYMAKER_COOLDOWN := 4.0
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
	# A contender's shoulder charge: roll out of its way (or step out of the lane).
	"charge": ["roll_left", "roll_right"],
	# A contender's judgment circle or vial: no dodge beats it, only leaving it.
	"zone": [],
	# A Banshee's shriek: back step out of the cone.
	"scream": ["back_step"],
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
## Sloppy (not set up) hooks and uppercuts in a row, and when the tip last showed.
var _sloppy_run := 0
var _sloppy_tip_time := -100.0
## The last punch was a set-up heavy (a set-up hook sets up an uppercut).
var _last_set_up := false
## Jabs in a row from the same hand (a double jab keeps the combo).
var _jab_run := 0
## Who the last punch landed on: switching to a new enemy can start on
## either hand without dropping the combo.
var _last_target_id := 0
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
## Tony's Fuggedaboudit: seconds until it can wave off another hit.
var _fugget_cooldown := 0.0
const FUGGET_TIME := 10.0
const FUGGET_METER := 8.0
var _air_time := 0.0
var _perfect_cooldown := 0.0
## Passives (Abilities; the equipped one per fighter).
## Grudge: the monster that last hit the Mauler, marked for a triple punch.
var _grudge: Enemy
var _grudge_mark: Node3D
## Dodge Chain: dodges in a row, spent on the next punch.
var _dodge_chain_charge := 0
## Phantom Step: cooldown between teleports.
var _phantom_cooldown := 0.0
## Ghost Walk: Phantom Step on melee attacks, every few seconds.
## Speed lines in the view (MoveFx.speed_lines), for the Blur and the Stray.
var _speed_lines: CPUParticles3D
## Blood Feud: hits the grudge monster has landed since it was marked.
var _grudge_hits := 0
## Bounce House: bounces since you last touched the floor.
var _stomp_chain := 0
## Fuggedaboudit II's second wave-off.
var _fugget_spare := false
## The attack being dodged (for the cards that care what it was).
var _dodged_attack := ""
## Momentum: built by sprinting (0-1), spent by the next punch that lands.
var _momentum := 0.0
var _momentum_idle := 0.0
## Head Stomp: no double stomps off the same head.
var _stomp_cooldown := 0.0
## The Muscle: seconds until Cousin Vinnie grabs someone.
var _muscle_timer := 6.0
## Unbroken (the Blur's alternate ultimate): seconds left.
var unbroken_time := 0.0
var _combo_freeze := 0.0
var _class_status := "-"
var _pound_cooldown := 0.0
var _lean_tween: Tween
## Time each movement key was last pressed, for double taps.
var _last_tap := {}
## A movement key that just triggered a dodge stops moving the player until
## it's released, so holding the second tap doesn't drift you out of range.
## Controller sprint, latched by clicking the stick.
var _pad_sprint := false
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
## The tutorial's fights: every attack hits for this (before a graze), so six
## take you down. 0: off.
var fixed_hit := 0.0
## Standing on a prop (a chest, an altar, a table, a building): after
## PERCH_TIME you're shoved off (2026-10-29: perched up there, you could hit
## monsters with reach or spells while they couldn't reach you).
const PERCH_TIME := 1.0
const PERCH_SHOVE := 6.0
var _perch_time := 0.0
## The shove off a perch, easing out (walking would cancel a plain velocity).
var _shove := Vector3.ZERO
var _spear_cooldown := 0.0
var _haymaker_cooldown := 0.0
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
## The fighter's cards and attribute perks in play.
var cards: CardPlay
## The Endless powers' fight state (Gale charges, Iron plates, Quake).
var powers: PowerPlay
## An emote's own effects while it runs: Intense Yelling's aura, rocks and
## lightning (PowerUpFx), Overexerted's poop (PoopFx).
var _emote_fx: Node3D
var _power_status := []
## Seconds left in a forward dash (Ghost Step slips attacks in it).
var dash_time := 0.0

## Emotes: hold the emote key for the wheel (EmoteWheel), let go on a dance.
## The camera pulls out to third person around your fighter (PlayerBody) until
## you move, punch, dodge, jump, fire the ultimate or get hit. A quick tap
## repeats the last dance (on a controller it opens the map where there is one).
const EMOTE_CAM_DISTANCE := 2.7
const EMOTE_CAM_TIME := 0.35
const EMOTE_TAP := 0.25
## The camera looks at this height on your fighter.
const EMOTE_FOCUS := 1.1
const EMOTE_STOPS := ["punch_left", "punch_right", "punch_hook", "punch_uppercut", "slip_left", "slip_right",
		"jump", "ultimate", "roll_left_key", "roll_right_key", "back_step_key", "dash_key"]
## The dance going on ("" for none).
var emote := ""
var _last_emote := "default"
var _body: PlayerBody
var _emote_cam: Camera3D
## Where the emote camera sits: yaw around you (0 = behind) and pitch (up).
var _emote_orbit := Vector2.ZERO
## 0 = first person, 1 = all the way out.
var _emote_out := 0.0
var _wheel: EmoteWheel
## How long the emote key has been held (-1: the wheel is closed).
var _wheel_time := -1.0
var _wheel_pad := false

@onready var _camera: Camera3D = $Camera3D
@onready var _punch_ray: RayCast3D = $Camera3D/PunchRay
@onready var _fists: Fists = $Camera3D/Fists
@onready var _camera_rest: Vector3 = _camera.position


func _ready() -> void:
	_punch_ray.add_exception(self)
	max_knuckles = GameState.get_max_knuckles()
	knuckles = max_knuckles
	_punch_ray.target_position = Vector3(0, 0, -(LONG_REACH + LONG_REACH_PER_POWER * GameState.passive_power()) if GameState.has_passive("long_reach") else -PUNCH_REACH)
	_camera.fov = Settings.fov()
	Settings.changed.connect(func() -> void: _camera.fov = Settings.fov())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The lantern lights the world, not the hands (they have their own light).
	$Camera3D/Lantern.light_cull_mask &= ~(Fists.HAND_LAYER | PlayerBody.LAYER)
	ult = Ult.new()
	ult.player = self
	add_child(ult)
	GameState.ult_share = 0.0
	cards = CardPlay.new()
	cards.player = self
	add_child(cards)
	powers = PowerPlay.new()
	powers.player = self
	add_child(powers)
	# Speed lines: the Blur's long combos, the Stray's momentum and Hype Train.
	if GameState.player_class in ["combo_master", "free_runner"]:
		_speed_lines = MoveFx.speed_lines(_camera, GameState.fighter_color().lightened(0.3))
	_body = PlayerBody.new()
	_body.visible = false
	add_child(_body)
	_emote_cam = Camera3D.new()
	_emote_cam.top_level = true
	_emote_cam.near = 0.05
	_emote_cam.add_to_group("emote_cam")
	add_child(_emote_cam)
	var fill := OmniLight3D.new()
	fill.light_cull_mask = PlayerBody.LAYER
	fill.light_color = Color(1.0, 0.9, 0.82)
	fill.light_energy = 0.9
	fill.omni_range = 8.0
	fill.position = Vector3(0.6, 0.5, 0)
	_emote_cam.add_child(fill)
	var wheel_layer := CanvasLayer.new()
	wheel_layer.layer = 40
	add_child(wheel_layer)
	_wheel = EmoteWheel.new()
	wheel_layer.add_child(_wheel)


## Fight input is live: the mouse is captured, or you're on a controller.
func _live_input() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Pad.active


## Right-stick look: a curve for fine aim near the middle, then fast turns.
func _stick_look(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.15)
	if look == Vector2.ZERO:
		return
	look *= look.length()
	var speed: float = STICK_LOOK_SPEED * float(Settings.get_value("stick_sensitivity")) * delta
	rotate_y(-look.x * speed)
	_camera.rotate_x(-look.y * speed * 0.7 * (-1.0 if Settings.get_value("invert_y") else 1.0))
	_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action("emote") and not event.is_echo():
		if event.is_pressed():
			_open_wheel(event is InputEventJoypadButton or event is InputEventJoypadMotion)
		else:
			_close_wheel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := MOUSE_SENSITIVITY * Settings.mouse_sensitivity()
		if _wheel_time >= 0.0:
			_wheel.steer(_wheel.pointer + event.relative)
			return
		if emote != "":
			_orbit_emote_cam(event.relative * sensitivity)
			return
		rotate_y(-event.relative.x * sensitivity)
		_camera.rotate_x(-event.relative.y * sensitivity)
		_camera.rotation.x = clampf(_camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clicking back into the window after alt-tabbing recaptures the mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif _live_input():
		# Hook/uppercut buttons (scroll wheel or side buttons by scheme, or
		# your own keys; empty in the Shift/Ctrl + click scheme otherwise).
		for type in ["hook", "uppercut"]:
			if event.is_action_pressed("punch_" + type):
				_stop_emote()
				if ult.mode == "time_stop":
					ult.answer_direct(type)
				elif not ult.busy():
					_buffered_hand = "left" if _last_punch_hand == "right" else "right"
					_buffered_type = type
					_buffer_timer = INPUT_BUFFER_TIME
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_update_camera_shake(delta)
	_update_emote(delta)
	if not active:
		return
	Pad.mark_fighting()
	if _wheel_time >= 0.0:
		_steer_wheel(delta)
	elif emote != "":
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.15)
		_orbit_emote_cam(look * STICK_LOOK_SPEED * float(Settings.get_value("stick_sensitivity")) * delta)
	else:
		_stick_look(delta)
	if emote != "" and _live_input() and _emote_interrupted():
		_stop_emote()
	if ult.busy():
		return  # Temporal Break / Highlight Reel take over the controls.

	_cooldown -= delta
	_flinch_timer -= delta
	dash_time -= delta
	cards.tick(delta)
	powers.tick(delta)
	var power_status := powers.status()
	if power_status != _power_status:
		_power_status = power_status
		power_status_changed.emit(power_status)
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

	if _live_input():
		if Pad.active and Input.is_action_just_pressed("sprint"):
			_pad_sprint = not _pad_sprint
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


## Hand idles (IdleAnims): after IDLE_DELAY seconds of doing nothing the
## hands play the equipped idle, then again every IDLE_GAP seconds or so.
## Any input cuts it off (looking around doesn't).
const IDLE_DELAY := 5.0
const IDLE_GAP := Vector2(7.0, 11.0)
var _idle_for := 0.0
var _idle_next := IDLE_DELAY


func _update_idle(delta: float) -> void:
	var doing := not active or emote != "" or ult.busy() or Input.is_anything_pressed() \
			or Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.2 \
			or Vector2(velocity.x, velocity.z).length() > 0.5
	if doing:
		_idle_for = 0.0
		_idle_next = IDLE_DELAY
		if _fists.idle_playing:
			_fists.stop_idle()
		return
	_idle_for += delta
	if _idle_for >= _idle_next and not _fists.idle_playing:
		var id := GameState.idle_anim()
		_fists.play_idle(id)
		_idle_next = _idle_for + IdleAnims.length(id) + randf_range(IDLE_GAP.x, IDLE_GAP.y)


func _physics_process(delta: float) -> void:
	_update_idle(delta)
	# Ultimates take the controls, except Temporal Break (the Blur moves in it).
	if ult.busy() and ult.mode != "time_stop":
		velocity = Vector3.ZERO
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var direction := Vector3.ZERO
	var speed := WALK_SPEED
	if active:
		if _jump_requested and is_on_floor():
			velocity.y = JUMP_VELOCITY * (1.0 + GameState.get_effect("jump_bonus")) * _stomp_jump()
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
		# On a controller, clicking the stick latches sprint until you stop.
		if input_dir.length() < 0.2:
			_pad_sprint = false
		if Input.is_action_pressed("sprint") or _pad_sprint or ult.hype > 0.0:
			speed = SPRINT_SPEED * GameState.get_sprint_multiplier()
		speed *= GameState.get_move_speed_multiplier() * cards.move_mult()
		if ult.hype > 0.0:
			speed *= Ult.HYPE_SPEED

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

	if _shove.length() > 0.1:
		velocity.x = _shove.x
		velocity.z = _shove.z
		_shove = _shove.move_toward(Vector3.ZERO, PERCH_SHOVE * 3.0 * delta)
	var was_airborne := not is_on_floor()
	move_and_slide()
	_check_perch(delta)
	if dash_time > 0.0:
		for i in get_slide_collision_count():
			var bumped := get_slide_collision(i).get_collider() as Enemy
			if bumped:
				cards.dash_contact(bumped)
	if is_on_floor():
		_stomp_chain = 0
	_check_head_stomp()
	if ult.hype > 0.0:
		_hype_bowl()
	_fists.move_amount = minf(Vector2(velocity.x, velocity.z).length() / SPRINT_SPEED, 1.0)
	_check_ground_pound(was_airborne, delta)


## An enemy attack reaches the player. attack is an ANSWERS key. Returns
## "dodged" (right defense), "grazed" (a timed but wrong defense), "armored"
## (an ultimate shield or other guard absorbed it) or "hit".
## attacker: the enemy throwing it, for melee attacks (Thorns hits it back).
func receive_attack(amount: float, from: Vector3, attack: String, attacker: Node3D = null) -> String:
	_stop_emote()
	if fixed_hit > 0.0:
		amount = fixed_hit
	_last_attacker = attacker as Enemy
	# Wise Up: an enraged monster hits Tony harder.
	if _last_attacker and _last_attacker.is_taunted():
		amount *= Enemy.TAUNT_DEALT
	# Dead Weight: a Doom-marked monster hits softer.
	if _last_attacker and _last_attacker.is_doomed():
		amount *= 1.0 - Powers.dead_weight()
	if not active:
		return "dodged"
	# Get Up: back on your feet, untouchable for a moment.
	if cards.untouchable > 0.0:
		return "dodged"
	var intercepted := ult.intercept_attack(attack, attacker, amount)
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
	elif attack == "zone":
		pass  # Standing in it: no dodge helps.
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
			_dodged_attack = attack
			_on_dodge(move, since_press <= CLEAN_DODGE_TIME)
			_dodged_attack = ""
			if attack in ["arrow", "fireball"]:
				_phantom_step(attacker)
			return "dodged"
		_defense_cooldown = minf(_defense_cooldown, GRAZE_RECOVERY)
		Sfx.play("block", -6.0, 0.7)
		grazed.emit()
		_dodge_chain = 0
		_take_damage(amount * GRAZE_MULTIPLIER * (1.0 - GameState.get_effect("graze_reduction")), attacker)
		return "grazed"
	# Cards that slip an undefended attack for you.
	var slipped := cards.auto_slip(attack, attacker as Enemy)
	if slipped != "":
		Sfx.play("slip", -2.0, 1.2)
		dodged.emit("ghost")
		if slipped != "READ IT":
			_ready_counter("any")
		DamagePopup.spawn(get_parent(), slipped, Color(0.6, 0.9, 1.0), 40, global_position + _flat_forward() * 1.2 + Vector3(0, 1.6, 0))
		return "dodged"
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
	if GameState.is_player_class("wise_guy") and GameState.has_passive("fuggedaboudit") and (_fugget_cooldown <= 0.0 or _fugget_spare):
		# Fuggedaboudit II: two in a row, then the recharge.
		if _fugget_cooldown <= 0.0 and GameState.has_effect("fuggedaboudit_ii"):
			_fugget_spare = true
		else:
			_fugget_spare = false
		var recharge := FUGGET_TIME - 0.25 * _pp() - 3.0 * GameState.get_effect("fuggedaboudit_ii")
		_fugget_cooldown = maxf(3.0, recharge)
		Sfx.play("block", -2.0, 1.25)
		class_event.emit("FUGGEDABOUDIT!")
		ult.say(Insults.quip())
		var made := GameState.get_effect("made_man")
		if made > 0.0 and _last_attacker and not _last_attacker.is_dead():
			_last_attacker.stun(made)
		ult.add(FUGGET_METER)
		return "armored"
	_shake = maxf(_shake, 0.08)
	_flinch_timer = FLINCH_TIME * (1.0 - GameState.get_effect("flinch_reduction")) * cards.flinch_scale()
	_buffered_hand = ""
	_on_hit_passives(attacker)
	_set_combo(cards.combo_after_hit(combo))
	_fists.flinch()
	Sfx.play("hurt")
	attacked.emit(from)
	Pad.rumble(0.35, 0.6, 0.18)
	# Rhythm and dodge chains are lost on a clean hit.
	_rhythm = 0.0
	_dodge_chain = 0
	ult.on_hit()
	_take_damage(amount, attacker)
	cards.on_hit(attacker as Enemy)
	return "hit"


## Knuckle damage from an attack; Thorns hits the attacker back for what it cost.
## What a knockout heals (Blood, Bloodsoaked gear, the Fruit Hat): only a
## monster your own punch put down. Powers' blasts, burns and chains heal
## nothing (2026-10-29: Fire and Blood healed you once per monster in a burst).
func kill_heal(enemy: Enemy) -> float:
	return GameState.heal_amount("heal_on_kill", max_knuckles) if enemy and enemy.has_meta("punched_out") else 0.0


func _take_damage(amount: float, attacker: Node3D) -> void:
	amount = powers.hit_amount(amount, attacker as Enemy)
	amount = cards.hit_amount(amount, attacker as Enemy)
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


## A new Crypt floor: The Long Count is ready again, and once-a-bout cards.
func on_floor_start() -> void:
	_long_count_ready = true
	cards.start_bout()
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
	unbroken_time = 0.0
	_rhythm = 0.0
	_dodge_chain = 0
	_ghost_time = 0.0
	_set_combo(0)
	_clear_counter()
	_flinch_timer = 0.0
	_perfect_cooldown = 0.0
	cards.start_bout()


## Between Dead League rounds: keep the bout's attrition, but clear any stale
## combo/counter state and recover a small corner-rest share of max knuckles.
func prepare_bout_round(recovery_fraction: float) -> void:
	active = true
	unbroken_time = 0.0
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
	if knuckles <= 0.0:
		cards.save_from_knockout()
	cards.on_knuckles()
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
	_stop_emote(true)
	Pad.rumble(0.8, 1.0, 0.6)
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


# --- Emotes --------------------------------------------------------------------------

func _open_wheel(pad: bool) -> void:
	if _wheel_time >= 0.0 or ult.busy():
		return
	_wheel_time = 0.0
	_wheel_pad = pad
	_wheel.refresh_dances()
	_wheel.steer(Vector2.ZERO)
	_wheel.hint = "Let go to dance  -  tap for %s" % Emotes.name_of(_last_emote)


## Letting go of the emote key: dance the picked one. A quick tap with nothing
## picked repeats the last dance (stops a dance; on a controller, opens the map
## where there is one and Map has no button of its own).
func _close_wheel() -> void:
	if _wheel_time < 0.0:
		return
	var held := _wheel_time
	_wheel_time = -1.0
	_wheel.visible = false
	var pick := _wheel.picked()
	if pick != "":
		start_emote(pick)
	elif held <= EMOTE_TAP:
		if emote != "":
			_stop_emote()
		elif not (_wheel_pad and _tap_map()):
			start_emote(_last_emote)


func _steer_wheel(delta: float) -> void:
	_wheel_time += delta
	_wheel.visible = _wheel_time > 0.12 or _wheel.selected >= 0
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down", 0.2)
	if stick.length() > 0.5:
		_wheel.steer(stick * EmoteWheel.RADIUS)


func _tap_map() -> bool:
	if Controls._primary_pad("map") != null or get_tree().get_nodes_in_group("map_scene").is_empty():
		return false
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = "map"
		event.pressed = pressed
		Input.parse_input_event(event)
	return true


## Starts a dance (an Emotes id) and pulls the camera out.
func start_emote(id: String) -> void:
	if not active or ult.busy() or not Emotes.NAMES.has(id) or not Achievements.emote_unlocked(id):
		return
	if _emote_out <= 0.0:
		_emote_orbit = Vector2(PI * 0.78, 0.18)
		_emote_cam.global_transform = _camera.global_transform
	emote = id
	_last_emote = id
	_buffered_hand = ""
	if _emote_fx:
		_emote_fx.queue_free()
		_emote_fx = null
	if id == "intense_yelling":
		_emote_fx = PowerUpFx.new()
	elif id == "overexerted":
		_emote_fx = PoopFx.new()
	if _emote_fx:
		add_child(_emote_fx)
	_pad_sprint = false
	_body.finish_build()
	_body.visible = true
	_body.play(id)
	_fists.visible = false
	_emote_cam.fov = _camera.fov
	_emote_cam.make_current()


## Ends the dance; the camera glides back in (snap: at once).
func _stop_emote(snap := false) -> void:
	if emote == "" and not snap:
		return
	emote = ""
	_body.stop()
	if _emote_fx:
		_emote_fx.queue_free()
		_emote_fx = null
	if snap:
		_emote_out = 0.0
		_finish_emote_cam()


func _emote_interrupted() -> bool:
	for action in EMOTE_STOPS:
		if Input.is_action_just_pressed(action):
			return true
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.3


func _orbit_emote_cam(turn: Vector2) -> void:
	_emote_orbit.x -= turn.x
	_emote_orbit.y = clampf(_emote_orbit.y + turn.y * (-1.0 if Settings.get_value("invert_y") else 1.0), -0.25, 1.1)


## Moves the emote camera between your eyes and its orbit spot.
func _update_emote(delta: float) -> void:
	if emote != "" and (not active or ult.busy()):
		_stop_emote(not active)
	if emote == "" and _emote_out <= 0.0:
		return
	_emote_out = move_toward(_emote_out, 1.0 if emote != "" else 0.0, delta / EMOTE_CAM_TIME)
	if emote == "" and _emote_out <= 0.0:
		_finish_emote_cam()
		return
	var blend := smoothstep(0.0, 1.0, _emote_out)
	_emote_cam.global_transform = _camera.global_transform.interpolate_with(_emote_orbit_spot(), blend)


func _finish_emote_cam() -> void:
	if _emote_cam.current:
		_camera.make_current()
	_body.visible = false
	_fists.visible = true


## The orbit spot, pulled in where a wall is in the way.
func _emote_orbit_spot() -> Transform3D:
	var focus := global_position + Vector3.UP * EMOTE_FOCUS
	var yaw := rotation.y + _emote_orbit.x
	var pitch := _emote_orbit.y
	var away := (Vector3(sin(yaw), 0, cos(yaw)) * cos(pitch) + Vector3.UP * sin(pitch)) * EMOTE_CAM_DISTANCE
	var spot := focus + away
	var query := PhysicsRayQueryParameters3D.create(focus, spot, 1 | Scenery.LAYER, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		spot = hit.position - away.normalized() * 0.25
	return Transform3D(Basis.IDENTITY, spot).looking_at(focus, Vector3.UP)


## The hand of the last punch that landed.
func last_hand() -> String:
	return _last_hand


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
	# Dedicated keys (the Tab / R scheme, or your own bindings) work in any scheme.
	for key in DEDICATED_MOVES:
		if Input.is_action_just_pressed(key):
			_do_move(DEDICATED_MOVES[key])
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
	_forward_dash_cooldown = FORWARD_DASH_COOLDOWN * cards.recovery_scale()
	_dash_jab_time = DASH_PUNCH_WINDOW if GameState.has_passive("dash_punches") else DASH_JAB_WINDOW
	_dash = -global_basis.z * FORWARD_DASH_SPEED * cards.dash_scale()
	_dash.y = 0.0
	dash_time = 0.3
	cards.on_dash()
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
	_defense_cooldown = window + defense.recovery * cards.recovery_scale()
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
	if GameState.has_passive("dodge_chain"):
		# Stored Answers: chains go up to 10.
		var most := 10 if GameState.has_effect("stored_answers") else DODGE_CHAIN_MAX
		_dodge_chain_charge = mini(_dodge_chain_charge + 1, most)
		if _dodge_chain_charge >= 2:
			class_event.emit("CHAIN x%d" % _dodge_chain_charge)
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
	powers.on_dodge(clean)
	cards.on_dodge(clean, _dodged_attack, _last_attacker)


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
	counter_ready_changed.emit(true, side)


func _clear_counter() -> void:
	_clean_counter = false
	if _counter_side == "":
		return
	_counter_timer = 0.0
	_counter_side = ""
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
	cards.before_punch()
	var punch: Dictionary = PUNCHES[type]
	var speed := GameState.get_punch_speed() * cards.speed_mult()
	var impact: float = punch.impact / speed
	_cooldown = punch.cooldown / speed
	_fists.play_punch(type, hand, impact, _cooldown)
	_animate_head(type, hand, impact, _cooldown)
	# Free Runner moves are judged when the punch starts.
	var airborne := not is_on_floor()
	var style := _dash_punch_style(type, airborne)
	await get_tree().create_timer(impact, false).timeout
	if active:
		powers.on_punch_thrown(type, hand, GameState.get_damage() * float(punch.mult))
		_dash_style = style
		_land_punch(type, hand, style != "", airborne)
		_dash_style = ""


## The Stray's dash punch this punch becomes ("spear", "haymaker" or ""),
## starting its cooldown. Only the straights: a jab spears, a cross is the
## haymaker. Hooks and uppercuts out of a dash are just hooks and uppercuts.
func _dash_punch_style(type: String, airborne: bool) -> String:
	if not GameState.has_passive("dash_punches") or _dash_jab_time <= 0.0 or airborne or type not in ["jab", "cross"]:
		return ""
	if type == "jab":
		if _spear_cooldown > 0.0:
			return ""
		_spear_cooldown = SPEAR_JAB_COOLDOWN
	else:
		if _haymaker_cooldown > 0.0:
			return ""
		_haymaker_cooldown = HAYMAKER_COOLDOWN
	_dash_jab_time = 0.0
	return "spear" if type == "jab" else "haymaker"


## Punches something that isn't a monster (group "punchable", with a
## punched(type, hand, player) method) if one is in reach and in front.
func _punch_thing(type: String, hand: String) -> bool:
	var eye := _camera.global_position
	var forward := -_camera.global_basis.z
	for node in get_tree().get_nodes_in_group("punchable"):
		var to: Vector3 = (node as Node3D).global_position - eye
		if to.length() <= PUNCH_REACH + 0.5 and forward.dot(to.normalized()) > 0.75:
			node.punched(type, hand, self)
			return true
	return false


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
		# A punchable thing in reach (the Headless's thrown skull) comes first.
		if _punch_thing(type, hand):
			return
		_punch_ray.force_raycast_update()
		target = _punch_ray.get_collider() as Enemy
		hit_point = _punch_ray.get_collision_point()
	if target == null and _dash_style == "spear":
		var line := _enemies_in_line(_spear_reach(), SPEAR_JAB_WIDTH)
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
		_pay_for_punch(PUNCHES[type], false, type)
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
	# jab or cross from the other hand (jab -> right uppercut, jab-cross-hook...),
	# and a set-up hook sets up an uppercut from the other hand (jab, cross,
	# hook, uppercut). The Berserker's heavy punches don't need a setup.
	var after_straight := _last_type in ["jab", "cross"]
	var after_hook := type == "uppercut" and _last_type == "hook" and _last_set_up
	var set_up: bool = punch.heavy and (GameState.is_player_class("berserker") \
			or (combo > 0 and hand != _last_hand and (after_straight or after_hook)))
	# A counter only counts with the hand on the side you dodged to.
	var counter := is_counter_ready() and (_counter_side == "any" or _counter_side == hand)
	var clean := counter and _clean_counter
	_clear_counter()
	# A jab thrown out of a forward dash (Lunging / Spear Jab).
	var dash_jab := type == "jab" and _dash_jab_time > 0.0
	if dash_jab:
		_dash_jab_time = 0.0
	var target_was_low := target.hp < target.max_hp * FINISHER_HP_FRACTION
	var target_was_fresh := target.hp >= target.max_hp

	# Alternating hands builds the combo; the same hand twice starts it over,
	# except a double jab (jab, jab), after which the other hand must come
	# next. Triple Jab (Blur skill) allows a third jab. Moving on to a new
	# enemy can start on either hand.
	var new_target := target.get_instance_id() != _last_target_id
	_last_target_id = target.get_instance_id()
	var jab_repeat := type == "jab" and _last_type == "jab" and hand == _last_hand and not new_target
	_jab_run = _jab_run + 1 if jab_repeat else (1 if type == "jab" else 0)
	var jabs_allowed := 2
	if hand == _last_hand and not new_target and not (jab_repeat and _jab_run <= jabs_allowed) and unbroken_time <= 0.0:
		combo = 0
	_last_hand = hand
	_last_type = type
	_last_set_up = set_up
	_combo_timer = GameState.get_combo_window() * cards.combo_window_scale()
	var plain := type in ["jab", "cross"] and not counter and not dash_jab and is_on_floor()
	_straight_run = _straight_run + 1 if plain else 0
	_combo_grew = _straight_run <= STRAIGHT_RUN_LIMIT or unbroken_time > 0.0
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
	if GameState.has_passive("dash_punches"):
		var jump_threshold := FINISHER_HP_FRACTION
		if _dash_style == "spear":
			raw_damage *= SPEAR_JAB_MULTIPLIER + 0.08 * _pp()
			caption = "SPEAR JAB!"
		elif _dash_style == "haymaker":
			raw_damage *= HAYMAKER_MULTIPLIER + 0.08 * _pp()
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
	# Perfect Counter: a matching-hand hook/uppercut counter hits x2.5 harder
	# (2026-10-24: it used to KO outright, and the Answer outclassed everyone).
	var perfect_punch: bool = punch.heavy or GameState.has_effect("perfect_any_punch")
	# The Last Word and Riposte II make every counter a Perfect Counter.
	var free_perfect := counter and cards.free_perfect()
	if counter and (free_perfect or (perfect_punch and GameState.has_passive("perfect_counter") and _perfect_cooldown <= 0.0)):
		raw_damage *= PERFECT_COUNTER_BONUS
		caption = "PERFECT COUNTER!"
		if not free_perfect:
			_perfect_cooldown = PERFECT_COUNTER_COOLDOWN - 0.3 * _pp()
		class_event.emit("PERFECT COUNTER!")
		# Checkmate: a weakened monster goes down (a boss loses a chunk).
		if GameState.has_effect("checkmate") and target.hp < target.max_hp * 0.4:
			raw_damage = maxf(raw_damage, target.max_hp * 0.15 + target.armor if target.is_boss else target.hp + target.armor + 1.0)
			crush = true
			caption = "CHECKMATE!"

	var card := cards.punch_mod(target, type, counter, airborne, set_up, hit_point, forced != null)
	raw_damage *= card.mult
	if card.caption != "":
		caption = card.caption if caption == "" else caption + "\n" + card.caption

	var passive := _passive_punch(target, forced != null)
	raw_damage *= passive.mult
	if passive.caption != "":
		caption = passive.caption if caption == "" else caption + "\n" + passive.caption

	# Weak spots (e.g. a Possessed Armor's sides, for hooks) hit harder and ignore armor.
	var weak := target.weak_spot_multiplier(type)
	if weak > 1.0:
		raw_damage *= weak
		caption = "WEAK SPOT!" if caption == "" else caption + "\nWEAK SPOT"

	# A hook or uppercut with nothing setting it up does jab damage for 2-3x
	# the knuckle cost. Say so, and after a few in a row, say how to fix it.
	if punch.heavy and not set_up and not counter and caption == "" and forced == null:
		caption = "SLOPPY"
		_sloppy_run += 1
		var now := Time.get_ticks_msec() / 1000.0
		if _sloppy_run >= SLOPPY_TIP_AFTER and now - _sloppy_tip_time > SLOPPY_TIP_EVERY:
			_sloppy_tip_time = now
			_sloppy_run = 0
			class_event.emit("SET IT UP  -  %s or %s first, then the hook or uppercut" % [Controls.text("jab"), Controls.text("cross")])
	elif punch.heavy:
		_sloppy_run = 0
	# Critical hits (Lucky Shot, Dirty Shot; Glass Breaker hits harder).
	if forced == null and randf() < minf(GameState.get_effect("crit_chance"), MAX_CRIT_CHANCE):
		raw_damage *= CRIT_MULTIPLIER + GameState.get_effect("crit_damage")
		caption = "CRIT!" if caption == "" or caption == "SLOPPY" else caption + "\nCRIT!"

	raw_damage *= bonus
	if forced_caption != "":
		caption = forced_caption if caption == "" else forced_caption + "\n" + caption
	var push := target.global_position - global_position if forced else -_camera.global_basis.z
	push.y = 0.0
	push = push.normalized() * punch.knockback * (1.5 if counter else 1.0) * card.push
	if _dash_style == "haymaker":
		push *= HAYMAKER_KNOCKBACK
	# How the target flies if this punch finishes it (see Enemy.finisher).
	var finish_level := 2 if clean or caption == "PERFECT COUNTER!" else (1 if counter else 0)
	var finish_dir := push.normalized() if push.length() > 0.01 else -global_basis.z
	target.finisher = {"type": _dash_style if _dash_style != "" else type, "hand": hand,
			"level": finish_level, "dir": finish_dir, "player": self}
	# Dive Kick: jump punches stagger.
	var dive_kick := airborne and GameState.has_effect("dive_kick")
	var big := forced != null and bonus > 1.0
	var spear_line := _dash_style == "spear" and GameState.has_effect("spear_line")
	var staggers: bool = set_up or counter or dive_kick or crush or big or _dash_style == "haymaker" or passive.stagger or card.stagger or spear_line
	var dealt := target.take_hit(raw_damage, hit_point, push, staggers, caption, weak > 1.0, crush)
	# One absurd punch wins the Bald Hero Cap.
	if dealt >= Hats.MASSIVE_HIT * GameState.get_damage():
		Hats.award(get_tree(), "bald_cap")
	var killed := target.is_dead()
	if killed:
		# Your punch put it down (kill heals count only these: kill_heal).
		target.set_meta("punched_out", true)
	if not killed:
		target.finisher = {}
	if _dash_style == "haymaker" and not killed:
		target.knock_down(0.9, push)
	_dash_punch_splash(target, raw_damage, hand)
	_after_punch_passives(target, raw_damage, killed, push, forced != null)
	_punch_specials(type, hand, target, raw_damage, counter, dash_jab, killed)
	cards.after_punch(target, type, hand, raw_damage, dealt, counter, killed, airborne, set_up, forced != null)
	ult.on_landed(target, dealt, hand)

	var kind := "hit"
	if counter:
		kind = "counter"
		Bounties.event("counter")
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
	if GameState.has_passive("rapid_combos") and _combo_grew and combo > 0 \
			and combo % _shockwave_every() == 0:
		_shockwave()
	_pay_for_punch(punch, counter, type)


## The Stray's dash punches carry on past the target: a Spear Jab runs through
## everything in its line, a Haymaker blasts back whoever stands beside it.
func _dash_punch_splash(target: Enemy, damage: float, hand: String) -> void:
	if _dash_style == "spear":
		var line := GameState.has_effect("spear_line")
		for enemy in _enemies_in_line(_spear_reach(), SPEAR_JAB_WIDTH):
			if enemy == target or enemy.is_dead():
				continue
			var forward := _flat_forward()
			enemy.finisher = {"type": "spear", "hand": hand, "level": 0, "dir": forward, "player": self}
			enemy.take_hit(damage * 0.8, enemy.global_position + Vector3(0, 1.2, 0), forward * 3.0, line, "SPEAR")
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
				enemy.knock_down(0.9, away)
				if GameState.has_effect("spear_line"):
					_bowl_into(enemy, damage * 0.3)


## Spear Line: the blasted monster flies into whoever's behind it.
func _bowl_into(flier: Enemy, damage: float) -> void:
	await get_tree().create_timer(0.2, false).timeout
	if not is_instance_valid(flier):
		return
	for enemy in _enemies_near(flier.global_position, 1.6):
		if enemy != flier:
			enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), Vector3.ZERO, true, "BOWLED")
			if not enemy.is_dead():
				enemy.knock_down(0.7, enemy.global_position - flier.global_position)


func _spear_reach() -> float:
	return SPEAR_JAB_REACH * (1.5 if GameState.has_effect("spear_line") else 1.0)


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
func _pay_for_punch(punch: Dictionary, counter: bool, type := "") -> void:
	var free_chance := GameState.get_effect("free_punch_chance")
	if counter and GameState.is_player_class("counter_master"):
		free_chance = 1.0 - (1.0 - free_chance) * (1.0 - COUNTER_MASTER_FREE_CHANCE)
	# Light Hands (the Blur's card): straights, and hooks at rank II.
	if type in ["jab", "cross"] or (type == "hook" and GameState.get_effect("light_hooks") > 0.0):
		free_chance = 1.0 - (1.0 - free_chance) * (1.0 - GameState.get_effect("light_hands"))
	if randf() < free_chance or _free_punch:
		_free_punch = false
		return
	var cost: float = punch.knuckle_cost
	if punch.heavy:
		cost = maxf(1.0, cost - GameState.get_effect("heavy_cost_cut"))
	cost += GameState.get_effect("blood_cost")
	cost *= cards.cost_scale()
	if cost > 0.0:
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

## Sigil powers: heavies and counters (big hits) set off Fire, Frost and
## Doom's mark, as does any hit by chance (Kindling, Cold Snap, Hex); every
## Nth combo hit (and with Conductor, every counter) sets off Chain
## Lightning; Blood heals on counters; Iron forges and Quake stomps (PowerPlay).
func _trigger_powers(target: Enemy, damage: float, big_hit: bool, counter := false) -> void:
	# Each power has a cooldown on top of its chance (PowerPlay.COOLDOWNS).
	var fire := GameState.get_effect("fire_punch")
	if fire > 0.0 and powers.ready("sigil_fire") and (big_hit or randf() < GameState.get_effect("fire_chance")):
		powers.spend("sigil_fire")
		Powers.fire_burst(target, damage * fire)
	if GameState.get_effect("frost_punch") > 0.0 and not target.is_dead() and powers.ready("sigil_frost") \
			and (big_hit or randf() < GameState.get_effect("frost_chance")):
		powers.spend("sigil_frost")
		Powers.frost_burst(target)
	var jumps := int(GameState.get_effect("chain_lightning"))
	var every := CHAIN_LIGHTNING_EVERY - int(GameState.get_effect("chain_every_cut"))
	if jumps > 0 and powers.ready("sigil_storm") \
			and ((_combo_grew and combo % every == 0) or (counter and GameState.has_effect("chain_on_counter"))):
		powers.spend("sigil_storm")
		# Lightning gets only half of the combo bonus.
		var multiplier := get_combo_multiplier()
		Powers.chain_lightning(target, damage / multiplier * (1.0 + (multiplier - 1.0) * 0.5), jumps)
	if counter and GameState.get_effect("counter_heal") > 0.0 and powers.ready("sigil_blood"):
		powers.spend("sigil_blood")
		heal(GameState.heal_amount("counter_heal", max_knuckles))
		Powers.blood_drain(target, self)
		Powers.went_off("sigil_blood", target)
	if GameState.get_effect("doom") > 0.0 and not target.is_dead() and powers.ready("sigil_doom") \
			and (big_hit or randf() < GameState.get_effect("doom_chance")):
		powers.spend("sigil_doom")
		Powers.doom_mark(target)
	powers.on_landed()


## On a prop for PERCH_TIME: shoved off it, away from its middle.
func _check_perch(delta: float) -> void:
	var prop: Node3D = null
	if is_on_floor():
		# What's underfoot (standing still, there's no slide collision to read).
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.3, 1 | Scenery.LAYER)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var body := hit.get("collider") as Node3D
		if body and body.has_meta("prop"):
			prop = body
	if prop == null:
		_perch_time = 0.0
		return
	_perch_time += delta
	if _perch_time < PERCH_TIME:
		return
	_perch_time = 0.0
	var away := global_position - prop.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.05 else -_flat_forward()
	_shove = away * PERCH_SHOVE
	velocity.y = 3.0
	Sfx.play("whoosh", -6.0, 0.8)


## Thunderhead (Storm capstone): a clean dodge strikes the attacker, then arcs.
func _thunderhead() -> void:
	if not GameState.has_effect("thunderhead") or not is_instance_valid(_last_attacker) or _last_attacker.is_dead():
		return
	var damage := GameState.get_damage() * 2.0
	_last_attacker.take_hit(damage, _last_attacker.global_position + Vector3(0, 1.3, 0), Vector3.ZERO, true, "THUNDER")
	Powers.chain_lightning(_last_attacker, damage, maxi(2, int(GameState.get_effect("chain_lightning"))))


func _check_ground_pound(was_airborne: bool, delta: float) -> void:
	_pound_cooldown -= delta
	if not is_on_floor():
		_air_time += delta
		return
	if was_airborne and active and powers.on_land(_air_time):
		_air_time = 0.0
		return
	var pound := GameState.get_effect("ground_pound")
	if was_airborne and active and pound > 0.0 and _air_time >= GROUND_POUND_MIN_AIR_TIME and _pound_cooldown <= 0.0:
		_pound_cooldown = GROUND_POUND_COOLDOWN
		Powers.ground_pound(self, GameState.get_damage() * pound)
		_shake = maxf(_shake, 0.09)
		_kick_fov(5.0)
	_air_time = 0.0


# --- Class specials ---------------------------------------------------------------

## Combo Master: every 5th hit stuns everything nearby and freezes the combo timer.
func _shockwave() -> void:
	var damage := GameState.get_damage() * 0.2 * _pp()
	# Aftershock: the stun hits too, and holds the combo longer.
	var aftershock := GameState.has_effect("aftershock")
	if aftershock:
		damage += GameState.get_damage()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy and not enemy.is_dead() and enemy.global_position.distance_to(global_position) <= SHOCKWAVE_RADIUS:
			# Rolling Thunder: the shockwave hits too.
			if damage > 0.0:
				var away := enemy.global_position - global_position
				away.y = 0.0
				enemy.take_hit(damage, enemy.global_position + Vector3(0, 1.0, 0), away.normalized() * 3.0, false, "SHOCK")
			if not enemy.is_dead():
				enemy.stun(SHOCKWAVE_STUN)
	_combo_freeze = 2.0 if aftershock else COMBO_FREEZE_TIME
	HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, Color(1, 0.8, 0.3), 40, 7.0, true, 0.06)
	Sfx.play("counter", -2.0, 0.7)
	_kick_fov(5.0)
	class_event.emit("SHOCKWAVE!")


# --- Passives (Abilities) --------------------------------------------------------------

## Passive power from levels (GameState.passive_power).
func _pp() -> float:
	return GameState.passive_power()


## What the equipped passive does to the punch about to land: {mult, caption,
## stagger}. Spends grudges, dodge chains and momentum.
func _passive_punch(target: Enemy, forced: bool) -> Dictionary:
	var result := {"mult": 1.0, "caption": "", "stagger": false}
	if forced:
		return result
	match GameState.passive():
		"grudge":
			if target == _grudge and is_instance_valid(_grudge):
				result.mult = GRUDGE_MULT + 0.15 * _pp()
				result.caption = "GRUDGE!"
				result.stagger = true
				# Blood Feud: every hit it landed adds to it, and it rocks the crowd.
				if GameState.has_effect("blood_feud"):
					result.mult += _grudge_hits
					for enemy in _enemies_near(target.global_position, 3.0):
						if enemy != target:
							enemy.stun(Enemy.STAGGER_TIME * 0.6)
					if _grudge_hits > 0:
						result.caption = "BLOOD FEUD x%d!" % (_grudge_hits + 1)
				_clear_grudge()
		"berserker":
			result.mult = _berserker_mult()
		"dodge_chain":
			if _dodge_chain_charge > 0:
				result.mult = 1.0 + (DODGE_CHAIN_STEP + 0.05 * _pp()) * _dodge_chain_charge
				result.caption = "CHAIN x%d!" % _dodge_chain_charge
				result.stagger = _dodge_chain_charge >= 3
				# Stored Answers: one dodge a punch.
				_dodge_chain_charge = _dodge_chain_charge - 1 if GameState.has_effect("stored_answers") else 0
		"momentum":
			if _momentum > 0.1:
				result.mult = _momentum_mult()
				result.caption = "MOMENTUM x%.1f!" % result.mult
				result.stagger = _momentum >= 0.9
				# Full Tilt: a punch spends only half.
				_momentum = _momentum * 0.5 if GameState.has_effect("full_tilt") else 0.0
	return result


func _berserker_mult() -> float:
	if not GameState.has_passive("berserker") or max_knuckles <= 0.0:
		return 1.0
	return 1.0 + (BERSERKER_MAX + 0.05 * _pp()) * clampf(1.0 - knuckles / max_knuckles, 0.0, 1.0)


func _momentum_mult() -> float:
	var most := MOMENTUM_MAX * (2.0 if GameState.has_effect("full_tilt") else 1.0)
	return 1.0 + (most + 0.1 * _pp()) * _momentum


func _take_bonus() -> float:
	return 0.25 + 0.03 * _pp() if GameState.has_passive("the_take") else 0.0


## Card hooks reach for these.
func is_sprinting() -> bool:
	return (Input.is_action_pressed("sprint") or _pad_sprint or ult.hype > 0.0) and Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 0.5


## After a punch lands: echoes and wrecking balls.
func _after_punch_passives(target: Enemy, damage: float, killed: bool, push: Vector3, forced: bool) -> void:
	if forced:
		return
	match GameState.passive():
		"echo_fists":
			_echo(target, damage)
		"wrecking_ball":
			if killed:
				_wrecking_ball(target.global_position, push)


## A violet echo of the punch, a beat later (Double Echo: it echoes again, for half).
func _echo(target: Enemy, damage: float, again := true) -> void:
	# The echo is a violet ghost of the fist, flying in a beat behind.
	var side := -1.0 if _last_hand == "left" else 1.0
	var from := _camera.global_position + _camera.global_basis * Vector3(0.25 * side, -0.3, -0.5)
	MoveFx.ghost_fist(get_parent(), from, target.global_position + Vector3(0, 1.3, 0), Color(0.7, 0.45, 1.0), ECHO_DELAY)
	await get_tree().create_timer(ECHO_DELAY, false).timeout
	if not is_instance_valid(target) or target.is_dead() or not active:
		return
	var at := target.global_position + Vector3(0, 1.3, 0)
	var echo := damage * (ECHO_SHARE + 0.04 * _pp())
	target.take_hit(echo, at, Vector3.ZERO, false, "ECHO")
	HitFx.burst(get_parent(), at, Vector3.UP, Color(0.7, 0.45, 1.0), 10, 3.0, true, 0.04)
	Sfx.play_at("hit", at, -6.0, 1.5)
	if again and GameState.has_effect("double_echo"):
		_echo(target, damage * 0.5, false)


## The knocked-out monster bowls through the ones behind it.
func _wrecking_ball(from: Vector3, push: Vector3) -> void:
	var direction := push.normalized() if push.length() > 0.01 else -global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var hit := {}
	for step in 3:
		await get_tree().create_timer(0.12, false).timeout
		if not is_inside_tree():
			return
		var at := from + direction * (1.6 + 1.6 * step)
		for node in _enemies_near(at, WRECKING_RADIUS):
			var enemy := node as Enemy
			if enemy == null or enemy.is_dead() or hit.has(enemy):
				continue
			hit[enemy] = true
			enemy.take_hit(GameState.get_damage() * (WRECKING_DAMAGE + 0.2 * _pp()), enemy.global_position + Vector3(0, 1.0, 0),
					direction * 6.0, true, "STRIKE!")
			HitFx.burst(get_parent(), enemy.global_position + Vector3(0, 1.0, 0), direction, Color(1.0, 0.55, 0.2), 14, 5.0, false, 0.05)
			# Bowled over (Strike!: and kept down for 2s).
			if not enemy.is_dead():
				enemy.knock_down(1.3 if GameState.has_effect("strike") else 0.9, direction)
		if not hit.is_empty() and step == 0:
			Sfx.play_at("heavy", at, 0.0, 0.7)
	if GameState.has_effect("strike") and hit.size() >= 3:
		ult.add(Ult.MAX_METER * 0.25)
		class_event.emit("STRIKE!  x%d" % hit.size())


func _enemies_near(at: Vector3, radius: float) -> Array:
	var found := []
	var parent := get_parent()
	for holder in [parent.get_node_or_null("Enemies"), parent]:
		if holder == null:
			continue
		for node in holder.get_children():
			var enemy := node as Enemy
			if enemy and not enemy.is_dead() and Vector2(enemy.global_position.x - at.x, enemy.global_position.z - at.z).length() <= radius:
				found.append(enemy)
		if not found.is_empty():
			break
	return found


## Took a clean hit: the Mauler holds a grudge; a dodge chain breaks.
func _on_hit_passives(attacker: Node3D) -> void:
	_dodge_chain_charge = 0
	_momentum = 0.0
	var enemy := attacker as Enemy
	if GameState.has_passive("grudge") and enemy and not enemy.is_dead():
		# Blood Feud counts the marked monster's hits.
		_grudge_hits = _grudge_hits + 1 if enemy == _grudge else 0
		var hits := _grudge_hits
		_clear_grudge()
		_grudge_hits = hits
		_grudge = enemy
		# A red skull over its head, bigger with every hit it lands on you.
		_grudge_mark = MoveFx.skull(Color(1.0, 0.12, 0.08))
		_grudge_mark.position.y = enemy.top_height() + 0.55
		enemy.add_child(_grudge_mark)
		var size := 0.55 + 0.15 * mini(_grudge_hits, 4)
		_grudge_mark.scale = Vector3.ONE * size * 1.5
		_grudge_mark.create_tween().tween_property(_grudge_mark, "scale", Vector3.ONE * size, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _clear_grudge() -> void:
	if is_instance_valid(_grudge_mark):
		_grudge_mark.queue_free()
	_grudge_mark = null
	_grudge = null
	_grudge_hits = 0


## Where a jump past a monster (Phantom Step, Vault) can land: the spot
## behind it, pulled in short of any wall on the way. INF if the monster has
## its back to a wall (no room behind it): stay put.
func teleport_spot(enemy: Enemy, spot: Vector3) -> Vector3:
	var from := global_position + Vector3.UP
	var to := Vector3(spot.x, global_position.y, spot.z) + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | Scenery.LAYER)  # The world and its buildings.
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return spot
	var flat := to - from
	flat.y = 0.0
	var landing: Vector3 = hit.position - flat.normalized() * 0.6
	var past := enemy.global_position - global_position
	past.y = 0.0
	# Not past the monster: there's no room behind it.
	if (landing - global_position).dot(past.normalized()) <= past.length() + 0.3:
		return Vector3.INF
	return Vector3(landing.x, spot.y, landing.z)


## Phantom Step: dodged a thrown attack, so appear behind whoever threw it.
## True if it did.
func _phantom_step(attacker: Node3D) -> bool:
	var enemy := attacker as Enemy
	if not GameState.has_passive("phantom_step") or _phantom_cooldown > 0.0 or enemy == null or enemy.is_dead():
		return false
	# Ghost Walk (a card): back twice as fast, and the thrower reels.
	var ghost := GameState.has_effect("ghost_walk")
	_phantom_cooldown = maxf(1.0, PHANTOM_COOLDOWN - 0.2 * _pp()) * (0.5 if ghost else 1.0)
	if ghost:
		enemy.stun(1.0)
	var away := enemy.global_position - global_position
	away.y = 0.0
	var spot := teleport_spot(enemy, enemy.global_position + away.normalized() * PHANTOM_BEHIND)
	if spot != Vector3.INF:
		HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, Color(0.45, 0.85, 1.0), 20, 3.0, true, 0.05)
		var was := global_position
		global_position = Vector3(spot.x, enemy.global_position.y + 0.1, spot.z)
		MoveFx.afterimage(get_parent(), was, Color(0.45, 0.85, 1.0))
		MoveFx.streak(get_parent(), was + Vector3.UP, global_position + Vector3.UP, Color(0.45, 0.85, 1.0), 0.1, 0.4)
		_kick_fov(6.0)
		look_at(Vector3(enemy.global_position.x, global_position.y, enemy.global_position.z), Vector3.UP)
		_camera.rotation.x = -0.05
		HitFx.burst(get_parent(), global_position + Vector3.UP, Vector3.UP, Color(0.45, 0.85, 1.0), 20, 3.0, true, 0.05)
	Sfx.play("slip", 0.0, 1.5)
	_ready_counter("any")
	class_event.emit("PHANTOM STEP!")
	return true


func _update_passive_timers(delta: float) -> void:
	_phantom_cooldown = maxf(0.0, _phantom_cooldown - delta)
	_spear_cooldown = maxf(0.0, _spear_cooldown - delta)
	_haymaker_cooldown = maxf(0.0, _haymaker_cooldown - delta)
	if is_instance_valid(_grudge_mark):
		_grudge_mark.rotation.y += delta * 2.0
		_grudge_mark.position.y = _grudge.top_height() + 0.55 + 0.06 * sin(Time.get_ticks_msec() * 0.005) if is_instance_valid(_grudge) else _grudge_mark.position.y
	_update_speed_lines()
	_stomp_cooldown = maxf(0.0, _stomp_cooldown - delta)
	if unbroken_time > 0.0:
		unbroken_time -= delta
		_combo_timer = maxf(_combo_timer, 0.5)
	if is_instance_valid(_grudge) and _grudge.is_dead():
		_clear_grudge()
	match GameState.passive():
		"momentum":
			var running := (Input.is_action_pressed("sprint") or _pad_sprint) and Vector2(velocity.x, velocity.z).length() > WALK_SPEED + 0.5
			if running:
				_momentum = minf(_momentum + delta / MOMENTUM_BUILD, 1.0)
				_momentum_idle = 0.0
			else:
				_momentum_idle += delta
				if _momentum_idle > 1.5:
					_momentum = maxf(0.0, _momentum - delta * 0.5)
		"the_muscle":
			_muscle_timer -= delta
			if _muscle_timer <= 0.0:
				_muscle_timer = maxf(6.0, MUSCLE_EVERY - 0.8 * _pp())
				_cousin_vinnie()
				if GameState.has_effect("whole_crew"):
					_cousin_vinnie(true)


## Hype Train: every monster the Stray runs into goes flying.
var _bowled := {}


func _hype_bowl() -> void:
	var now := Time.get_ticks_msec()
	var ahead := Vector3(velocity.x, 0, velocity.z)
	if ahead.length() < 1.0:
		return
	for enemy in _enemies_near(global_position + ahead.normalized() * 0.6, 1.3):
		if now - int(_bowled.get(enemy, 0)) < 600:
			continue
		_bowled[enemy] = now
		enemy.take_hit(GameState.get_damage() * (Ult.HYPE_DAMAGE + 0.5 * ult._power()) * get_combo_multiplier(),
				enemy.global_position + Vector3(0, 1.0, 0), ahead.normalized() * 10.0 + Vector3.UP * 2.0, true, "BOWLED!")
		if not enemy.is_dead():
			enemy.knock_down(1.0, ahead)
		ult.on_bowled()
		_set_combo(combo + 1)
		_combo_timer = GameState.get_combo_window()
		Sfx.play("heavy", -2.0, 0.8)
		_shake = maxf(_shake, 0.05)


## The Muscle: Cousin Vinnie grabs the nearest monster and holds it. second:
## The Whole Crew's second grab, and the two heads cracked together.
func _cousin_vinnie(second := false) -> void:
	var nearest: Enemy
	for enemy in _enemies_near(global_position, MUSCLE_RANGE):
		if second and float(enemy.get_meta("vinnie_until", 0.0)) > Time.get_ticks_msec() / 1000.0:
			continue
		if nearest == null or enemy.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
			nearest = enemy
	if nearest == null:
		if not second:
			_muscle_timer = 1.0
		return
	var hold := MUSCLE_HOLD + 0.1 * _pp() + (1.0 if GameState.has_effect("vinnie_bonus") else 0.0)
	nearest.stun(hold)
	nearest.set_meta("vinnie_until", Time.get_ticks_msec() / 1000.0 + hold)
	var goon := Goon.make(nearest, hold)
	get_parent().add_child(goon)
	if second:
		DamagePopup.spawn(get_parent(), "HEADS TOGETHER!", Color(0.5, 1.0, 0.6), 44, nearest.global_position + Vector3(0, 2.4, 0))
		for enemy in _enemies_near(global_position, MUSCLE_RANGE):
			if float(enemy.get_meta("vinnie_until", 0.0)) > Time.get_ticks_msec() / 1000.0:
				enemy.take_hit(GameState.get_damage() * 2.0, enemy.global_position + Vector3(0, 1.6, 0), Vector3.ZERO, true, "CRACK")
		return
	DamagePopup.spawn(get_parent(), "VINNIE GOT HIM!", Color(0.5, 1.0, 0.6), 40, nearest.global_position + Vector3(0, 2.4, 0))
	ult.say(["Hold him still, Vinnie.", "Vinnie! Little help.", "That's my cousin. Say hi."].pick_random())


## Head Stomp: came down on a monster's head, so bounce off it, stunning it.
## Parkour (a card) bounces any fighter off heads, with a short stun. Lands
## on top count, and so does coming down within reach of the head (capsule
## tops are round, so a true landing is rare).
func _check_head_stomp() -> void:
	if not _can_stomp() or _stomp_cooldown > 0.0:
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var enemy := hit.get_collider() as Enemy
		if enemy and not enemy.is_dead() and hit.get_normal().y > 0.6:
			_stomp(enemy)
			return
	if is_on_floor() or velocity.y > 0.5:
		return
	for node in _enemies_near(global_position, STOMP_REACH):
		var enemy := node as Enemy
		var above := global_position.y - (enemy.global_position.y + enemy.top_height())
		if above >= STOMP_BAND.x and above <= STOMP_BAND.y:
			_stomp(enemy)
			return


func _can_stomp() -> bool:
	return GameState.has_passive("head_stomp") or GameState.has_effect("parkour")


func _stomp_jump() -> float:
	return STOMP_JUMP if _can_stomp() else 1.0


func _stomp(enemy: Enemy) -> void:
	_stomp_cooldown = 0.35
	velocity.y = JUMP_VELOCITY * 1.15 * _stomp_jump()
	var head := enemy.global_position + Vector3(0, enemy.top_height(), 0)
	if not GameState.has_passive("head_stomp"):
		enemy.stun(0.5)
		Sfx.play("heavy", -4.0, 1.4)
		return
	enemy.stun(STOMP_STUN + 0.1 * _pp())
	enemy.squash()
	# Bounce House: each bounce in a chain hits harder; three give the dash back.
	var bounce := 1.0
	if GameState.has_effect("bounce_house"):
		bounce = pow(1.5, _stomp_chain)
		_stomp_chain += 1
		if _stomp_chain == 3:
			_forward_dash_cooldown = 0.0
			class_event.emit("BOUNCE HOUSE!")
	enemy.take_hit(GameState.get_damage() * STOMP_DAMAGE * bounce * get_combo_multiplier(), head,
			Vector3.ZERO, true, "STOMP!")
	_set_combo(combo + 1)
	_combo_timer = GameState.get_combo_window()
	Sfx.play("heavy", -2.0, 1.3)
	HitFx.burst(get_parent(), head, Vector3.UP, Color(0.4, 1.0, 0.5), 16, 4.0, true, 0.05)


## The Blur: from 10 hits in a combo, faster the longer it runs. The Stray:
## as Momentum builds, and all through Hype Train.
func _update_speed_lines() -> void:
	if _speed_lines == null:
		return
	var rush := 0.0
	if GameState.is_player_class("combo_master") and combo >= 10:
		rush = 0.7 + minf(combo, 50) / 50.0
	elif GameState.is_player_class("free_runner"):
		if ult.hype > 0.0:
			rush = 1.6
		elif GameState.has_passive("momentum") and _momentum > 0.25:
			rush = 0.5 + _momentum
	_speed_lines.emitting = rush > 0.0 and active
	_speed_lines.speed_scale = maxf(rush, 0.5)


## "2s", or "OK" once it's back.
static func _cooldown_text(seconds: float) -> String:
	return "OK" if seconds <= 0.0 else "%ds" % ceili(seconds)


func _shockwave_every() -> int:
	return SHOCKWAVE_EVERY


func _update_class_timers(delta: float) -> void:
	_perfect_cooldown = maxf(0.0, _perfect_cooldown - delta)
	_fugget_cooldown = maxf(0.0, _fugget_cooldown - delta)
	_update_passive_timers(delta)
	# What the passive is doing now, for the HUD's passive chip ("" for
	# nothing to count).
	var status := ""
	match GameState.passive():
		"grudge":
			status = "MARKED" if is_instance_valid(_grudge) and not _grudge.is_dead() else ""
		"berserker":
			status = "+%d%%" % roundi((_berserker_mult() - 1.0) * 100.0)
		"perfect_counter":
			status = "READY" if _perfect_cooldown <= 0.0 else "%ds" % ceili(_perfect_cooldown)
		"phantom_step":
			status = "READY" if _phantom_cooldown <= 0.0 else "%ds" % ceili(_phantom_cooldown)
		"dash_punches":
			# Left: Spear Jab. Right: Haymaker.
			if _spear_cooldown <= 0.0 and _haymaker_cooldown <= 0.0:
				status = "READY"
			else:
				status = "L %s  R %s" % [_cooldown_text(_spear_cooldown), _cooldown_text(_haymaker_cooldown)]
		"dodge_chain":
			status = "x%d" % _dodge_chain_charge
		"rapid_combos":
			status = "%d hits" % (_shockwave_every() - combo % _shockwave_every())
		"momentum":
			status = "x%.1f" % _momentum_mult()
		"fuggedaboudit":
			status = "READY" if _fugget_cooldown <= 0.0 else "%ds" % ceili(_fugget_cooldown)
		"the_muscle":
			status = "%ds" % ceili(maxf(_muscle_timer, 0.0))
		"the_take":
			status = "+%d%%" % roundi(_take_bonus() * 100.0)
	if status != _class_status:
		_class_status = status
		class_status_changed.emit(status)
	_update_hand_effects()


## Tells the fists what to show: special ready, ultimate ready, counter hand.
func _update_hand_effects() -> void:
	var ability := false
	match GameState.passive():
		"grudge":
			ability = is_instance_valid(_grudge) and not _grudge.is_dead()
		"perfect_counter":
			ability = _perfect_cooldown <= 0.0
		"phantom_step":
			ability = _phantom_cooldown <= 0.0
		"dodge_chain":
			ability = _dodge_chain_charge >= 3
		"rapid_combos", "echo_fists":
			ability = combo >= 3
		"momentum":
			ability = _momentum >= 0.9
		"fuggedaboudit":
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
	# Unbroken: nothing drops the combo while it lasts (getting hit, a slipped
	# punch and a shield used to; 2026-10-29). A knockout still does.
	if unbroken_time > 0.0 and active and value < combo:
		return
	combo = value
	if combo >= 25:
		Achievements.earn("combo_25")
	if combo >= 10:
		Bounties.event("combo", combo)
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
