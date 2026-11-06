extends RefCounted
## The Lab's scripted player (2026-11-06). It plays the benchmark the way a
## person does: walks up, faces the nearest monster, alternates jab and cross,
## reads wound-up attacks and dodges them, throws the counter, and uses the
## ultimate when it's charged and the fight is worth it. Two skill levels:
##   "average": slow turns, late reactions, skips some dodges, sometimes picks
##              the wrong one.
##   "good":    quick turns, early clean slips, almost never misses.
## It uses the same entry points as the touch controls (touch_punch,
## touch_dodge, touch_move) plus the move actions, so every passive and
## ultimate sees ordinary input. It does not play the class-specific tricks
## (head stomps, dash punches): those need a person, or a bot per fighter.

const SKILLS := {
	"average": {"turn": 7.0, "lead": 0.24, "jitter": 0.08, "skip": 0.3, "wrong": 0.15, "gap": 0.3, "ult_wait": 1.5, "hook": 0.0},
	"good": {"turn": 16.0, "lead": 0.09, "jitter": 0.03, "skip": 0.04, "wrong": 0.0, "gap": 0.17, "ult_wait": 0.3, "hook": 0.25},
}
const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint"]
## Within this of a monster the bot stops walking in; closer than BACK, it steps back.
const BACK_DISTANCE := 1.1
const NEAR_CROWD := 8.0
const SEED := 4242

var player: Player
var skill: Dictionary
var name := "average"
var _rng := RandomNumberGenerator.new()
var _punch_clock := 0.0
var _punch_count := 0
var _hand := "left"
var _stop_clock := 0.0
var _ult_clock := 0.0
## What the bot decided about the attack each monster is winding up:
## {enemy id: {"attack", "act", "move", "lead", "done"}}.
var _plans := {}


func _init(for_player: Player, skill_name: String) -> void:
	player = for_player
	name = skill_name if SKILLS.has(skill_name) else "average"
	skill = SKILLS[name]
	_rng.seed = SEED


## One physics step. enemies is every monster in the fight.
func step(delta: float, enemies: Array) -> void:
	var alive: Array = []
	for enemy in enemies:
		# $Enemies also holds hit particles and damage labels.
		if is_instance_valid(enemy) and enemy.has_method("is_dead") and not enemy.is_dead():
			alive.append(enemy)
	if not player.active or alive.is_empty():
		release()
		return
	if player.ult.mode == "time_stop":
		release()
		_time_stop(delta)
		return
	if player.ult.busy():
		release()
		return
	var target = _nearest(alive)
	var distance := _flat_distance(target)
	_aim(target, delta)
	_walk(distance)
	_defend(alive)
	_attack(target, distance, delta)
	_ultimate(alive, delta)


## Lets go of every key the bot holds.
func release() -> void:
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _flat_distance(enemy) -> float:
	var offset: Vector3 = enemy.global_position - player.global_position
	return Vector2(offset.x, offset.z).length()


func _nearest(alive: Array):
	var best = alive[0]
	var best_distance := INF
	for enemy in alive:
		var distance := _flat_distance(enemy)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


## Turns toward the monster at the skill's turn speed (radians a second).
func _aim(target, delta: float) -> void:
	var camera: Camera3D = player._camera
	var from: Vector3 = camera.global_position
	var to: Vector3 = target.aim_point()
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length() < 0.3:
		return
	var want := atan2(-flat.x, -flat.y)
	var error := wrapf(want - player.rotation.y, -PI, PI)
	var limit: float = float(skill.turn) * delta
	player.rotate_y(clampf(error, -limit, limit))
	var want_pitch := clampf(atan2(to.y - from.y, flat.length()), -0.9, 0.9)
	camera.rotation.x = move_toward(camera.rotation.x, want_pitch, limit)


func _facing(target) -> bool:
	var to: Vector3 = target.global_position - player.global_position
	var flat := Vector2(to.x, to.z)
	if flat.length() < 0.1:
		return true
	var error := absf(wrapf(atan2(-flat.x, -flat.y) - player.rotation.y, -PI, PI))
	return error < 0.3


func _reach() -> float:
	if GameState.has_passive("long_reach"):
		return Player.LONG_REACH + Player.LONG_REACH_PER_POWER * GameState.passive_power()
	return Player.PUNCH_REACH


## Walks in until in reach, backs off when too close, sprints across gaps.
func _walk(distance: float) -> void:
	var forward := distance > _reach() - 0.5
	var back := distance < BACK_DISTANCE
	_hold("move_forward", forward)
	_hold("move_back", back)
	_hold("sprint", distance > 7.0)


func _hold(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


## Reads each wound-up attack once, decides whether and how to answer it, and
## answers it when its time is within the skill's lead.
func _defend(alive: Array) -> void:
	var soonest := INF
	var soonest_enemy = null
	var seen := {}
	for enemy in alive:
		var attack: String = enemy.incoming_attack()
		var id: int = enemy.get_instance_id()
		if attack == "" or _flat_distance(enemy) > Player.ASSIST_RANGE:
			continue
		seen[id] = true
		var plan: Dictionary = _plans.get(id, {})
		if plan.is_empty() or plan.attack != attack:
			plan = _decide(attack)
			_plans[id] = plan
		if plan.done or not plan.act:
			continue
		var eta: float = enemy.attack_eta()
		if eta <= plan.lead and eta < soonest:
			soonest = eta
			soonest_enemy = enemy
	for id in _plans.keys():
		if not seen.has(id):
			_plans.erase(id)
	if soonest_enemy == null:
		return
	var chosen: Dictionary = _plans[soonest_enemy.get_instance_id()]
	if chosen.move == "jump":
		player._jump_requested = true
		chosen.done = true
	elif player._defense_cooldown <= 0.0:
		_do_defense(chosen.move)
		chosen.done = true


func _decide(attack: String) -> Dictionary:
	var answers: Array = Player.ANSWERS.get(attack, [])
	var move := ""
	if attack == "quake":
		move = "jump"
	elif not answers.is_empty():
		move = answers[_rng.randi() % answers.size()]
		if _rng.randf() < float(skill.wrong):
			var wrong: Array = Player.DEFENSES.keys().filter(func(key: String) -> bool: return not key in answers)
			if not wrong.is_empty():
				move = wrong[_rng.randi() % wrong.size()]
	var act := move != "" and _rng.randf() >= float(skill.skip)
	var lead: float = float(skill.lead) + float(skill.jitter) * _rng.randf_range(-1.0, 1.0)
	if move == "jump":
		lead = 0.35
	return {"attack": attack, "act": act, "move": move, "lead": maxf(lead, 0.02), "done": false}


func _do_defense(move: String) -> void:
	if move == "back_step":
		player.touch_move("back_step")
		return
	var parts := move.split("_")
	if parts.size() == 2:
		player.touch_dodge(parts[1], parts[0])


func _attack(target, distance: float, delta: float) -> void:
	_punch_clock -= delta
	if player.is_counter_ready():
		var side: String = player._counter_side
		player.touch_punch(side if side in ["left", "right"] else "left", "hook")
		return
	if _punch_clock > 0.0 or distance > _reach() or not _facing(target):
		return
	_punch_clock = float(skill.gap)
	_punch_count += 1
	var type := "jab" if _hand == "left" else "cross"
	if float(skill.hook) > 0.0 and _punch_count % 4 == 0:
		type = "hook"
	player.touch_punch(_hand, type)
	_hand = "right" if _hand == "left" else "left"


## Temporal Break: alternate hands to buy back time.
func _time_stop(delta: float) -> void:
	_stop_clock -= delta
	if _stop_clock > 0.0:
		return
	_stop_clock = 0.15
	_hand = "right" if _hand == "left" else "left"
	player.touch_punch(_hand, "jab" if _hand == "left" else "cross")


## Presses the ultimate once it's charged and the fight is worth it: a boss, a
## crowd of three, or knuckles under 40%.
func _ultimate(alive: Array, delta: float) -> void:
	if not player.ult.is_full():
		_ult_clock = 0.0
		return
	_ult_clock += delta
	if _ult_clock < float(skill.ult_wait):
		return
	var near := 0
	var boss := false
	for enemy in alive:
		if _flat_distance(enemy) <= NEAR_CROWD:
			near += 1
		if enemy.is_boss:
			boss = true
	var hurt: bool = player.knuckles < player.max_knuckles * 0.4
	if boss or near >= 3 or hurt:
		player.ult.activate()
		_ult_clock = 0.0
