class_name Dummy
extends Boxer
## Training dummy with unlimited HP. Level 1 slams, level 2 throws boxing
## punches singly and in combos, level 3 also slips the player's punches and
## counters, level 4 throws level 2 punches but moves around the ring.
## Telegraph settings control how much warning each attack gives.

## A combo finished. dodged_all: every attack in it was dodged.
signal combo_done(dodged_all: bool, length: int)

const MAX_LEVEL := 4
## Level that moves around the ring.
const RING_LEVEL := 4
const FOOTWORK_SPEED := 2.2
const EVADE_CHANCE := 0.35
const EVADE_TIME := 0.3
const COMBOS := [
	["jab"], ["cross"], ["left_hook"], ["right_hook"], ["uppercut"],
	["jab", "cross"], ["jab", "jab", "cross"], ["jab", "right_hook"],
	["jab", "cross", "left_hook"], ["cross", "left_hook", "uppercut"],
]
## How much warning each attack gives, from most to least. hint: show the
## key to press; glow: light the glove in the defense color; windup_scale:
## multiplies windup times.
const TELEGRAPHS := [
	{"name": "Full  (key hint + color, slow)", "hint": true, "glow": true, "windup_scale": 1.3},
	{"name": "Color only", "hint": false, "glow": true, "windup_scale": 1.0},
	{"name": "Pose only  (read the arm)", "hint": false, "glow": false, "windup_scale": 1.0},
	{"name": "Fight speed  (pose only, fast)", "hint": false, "glow": false, "windup_scale": 0.75},
]
## Shown in the training HUD, one per level.
const LEVEL_DESCRIPTIONS := [
	"Slams  (back step)",
	"Jabs, crosses, hooks, uppercuts + combos",
	"Also slips your punches and counters",
	"Ring: moves toward you  (level 2 punches)",
]

var level := 1
## 1-based index into TELEGRAPHS.
var telegraph := 1

var _last_damage := 0.0
## Tutorial: stands still and never attacks.
var passive := false
## Tutorial: combos to pick from instead of the level's.
var combo_pool: Array = []
var _combo_length := 0
var _combo_clean := true


func _ready() -> void:
	super()
	# Name/last-hit sits lower; the attack hint goes above it, bigger.
	_hp_label.position.y = 2.15
	set_level(level)
	set_telegraph(telegraph)


func set_telegraph(new_telegraph: int) -> void:
	telegraph = clampi(new_telegraph, 1, TELEGRAPHS.size())
	var tells: Dictionary = TELEGRAPHS[telegraph - 1]
	show_hints = tells.hint
	glow_tells = tells.glow
	windup_scale = tells.windup_scale
	if not show_hints:
		_cue_label.visible = false


func set_level(new_level: int) -> void:
	level = clampi(new_level, 1, MAX_LEVEL)
	footwork = level == RING_LEVEL
	move_speed = FOOTWORK_SPEED
	_queue.clear()
	_cue_label.visible = false
	_enter(State.IDLE, 1.0)
	_update_label()


# Unlimited HP. Only the ring level gets knocked back (a little).
func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	var knockback := push * 0.5 if level == RING_LEVEL else Vector3.ZERO
	var dealt := super(raw_damage, hit_point, knockback, stagger, caption, pierce, crush)
	hp = max_hp
	_last_damage = dealt
	_update_label()
	return dealt


# A perfect counter shows as a big hit instead of a million damage.
func get_knockout_damage() -> float:
	return 999.0


func try_evade(_punch_type: String, hand: String) -> bool:
	if level != 3 or not (_state in [State.IDLE, State.RECOVER]) or randf() >= EVADE_CHANCE:
		return false
	# Slip away from the punching hand, then fire back.
	_evade_side = 1.0 if hand == "left" else -1.0
	_queue.clear()
	_enter(State.EVADE, EVADE_TIME)
	DamagePopup.spawn(get_parent(), "SLIPPED", SLIP_COLOR, 44, global_position + Vector3(0, 1.6, 0))
	return true


func _pick_combo() -> Array:
	if not combo_pool.is_empty():
		return combo_pool.pick_random()
	return ["slam"] if level == 1 else COMBOS.pick_random()


func _start_combo() -> void:
	if passive:
		_enter(State.IDLE, 0.3)
		return
	super()
	_combo_length = _queue.size() + 1
	_combo_clean = true


func _strike(distance: float) -> void:
	super(distance)
	if _last_result != "dodged":
		_combo_clean = false
	if _queue.is_empty():
		combo_done.emit(_combo_clean, _combo_length)


func _on_staggered() -> void:
	super()
	_combo_clean = false


func _update_label() -> void:
	_hp_label.text = "Training Dummy  -  Level %d\nLast hit %.1f" % [level, _last_damage]
	_hp_label.visible = true


func _build_body() -> void:
	var wood := _material(Color(0.3, 0.2, 0.12))
	var burlap := _material(Color(0.62, 0.5, 0.32))
	var paint := _material(Color(0.08, 0.06, 0.05))
	var cord := _material(Color(0.45, 0.35, 0.2))

	_part(_body, _cylinder(0.35, 0.08), wood, Vector3(0, 0.04, 0))
	_part(_body, _cylinder(0.08, 0.9), wood, Vector3(0, 0.45, 0))
	_part(_body, _box(Vector3(0.5, 0.65, 0.3)), burlap, Vector3(0, 1.2, 0))
	_part(_body, _box(Vector3(0.52, 0.05, 0.32)), cord, Vector3(0, 1.05, 0))
	_part(_body, _box(Vector3(0.3, 0.32, 0.3)), burlap, Vector3(0, 1.72, 0))
	# Painted X eyes and a mouth.
	for side in [-1.0, 1.0]:
		for tilt in [-0.7, 0.7]:
			_part(_body, _box(Vector3(0.07, 0.015, 0.01)), paint, Vector3(0.07 * side, 1.77, -0.152), Vector3(0, 0, tilt))
	_part(_body, _box(Vector3(0.12, 0.015, 0.01)), paint, Vector3(0, 1.64, -0.152))
	_build_arms(burlap, Color(0.7, 0.08, 0.06))


## No gear overlays: a training dummy.
func _gear_style() -> String:
	return "none"
