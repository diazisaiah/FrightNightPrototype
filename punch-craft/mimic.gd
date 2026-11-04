class_name Mimic
extends Enemy
## A chest that isn't (Crypt). Wakes when the player comes close: bony legs
## unfold and it stands up. Shut, it's invincible: punches clang off its lid
## (Crypt revamp, 2026-11-04). Every few seconds it opens up and a tongue in a
## boxing glove throws a punch combo, read and dodged like any boxer's (the
## same tells and colors). Open, it can be hit, and it stays open a moment
## after the combo, longer if you dodged all of it. Beaten, it coughs up a
## real chest. An elite mimic (a cursed chest you chose to fight) is a
## champion: two traits, gold and chains, longer combos, opening more often.

enum State { WAKING, SHUT, OPENING, WINDUP, STRIKE, GAPING, CLOSING }

const WAKE_TIME := 0.8
const STAND_HEIGHT := 0.75
const OPEN_TIME := 0.35
const CLOSE_TIME := 0.25
const STRIKE_TIME := 0.15
## Open after its combo; a combo you dodged all of leaves it open longer.
const GAPE_TIME := 1.1
const DODGED_GAPE := 1.0
## How long it stays shut between combos (elites: 70% of it).
const SHUT_TIME := Vector2(2.0, 3.2)
## (+x swings the lid up and back from its hinge.)
const LID_OPEN := 1.4
const COMBOS := [
	["jab", "cross"], ["jab", "jab", "cross"], ["cross", "left_hook"], ["jab", "right_hook"],
	["left_hook", "right_hook"], ["jab", "cross", "uppercut"], ["cross", "left_hook", "uppercut"],
]
const ELITE_COMBOS := [
	["jab", "cross", "left_hook", "right_hook"], ["jab", "jab", "cross", "uppercut"],
	["left_hook", "right_hook", "cross", "uppercut"], ["cross", "left_hook", "cross", "right_hook"],
]
## The tongue's pose per attack: [yaw, pitch, length], wound up then thrown.
## (+yaw swings it to the mimic's left; the root sits above the rim, so it
## never passes through the chest.)
const POSES := {
	"guard": [0.0, 0.1, 0.45],
	"jab": [[0.35, 0.1, 0.3], [-0.05, 0.12, 1.5]],
	"cross": [[-0.35, 0.1, 0.3], [0.05, 0.12, 1.5]],
	"left_hook": [[1.2, 0.15, 0.9], [-0.4, 0.15, 1.3]],
	"right_hook": [[-1.2, 0.15, 0.9], [0.4, 0.15, 1.3]],
	"uppercut": [[0.0, -0.45, 0.5], [0.0, 0.8, 1.2]],
	"gape": [0.0, -0.5, 0.85],
}
const GLOVE_RED := Color(0.78, 0.1, 0.08)

@export var attack_damage := 10.0
@export var attack_range := 2.4
## Swift elites shorten their windups (Enemy._apply_trait looks for this).
var windup_scale := 1.0
var elite := false

var _state := State.WAKING
var _state_timer := WAKE_TIME
var _queue: Array[String] = []
var _attack := ""
var _flashed := false
var _dodged_all := true
var _lid: Node3D
var _legs: Array[Node3D] = []
var _chest: Node3D
var _tongue: Node3D
var _tongue_flesh: MeshInstance3D
var _glove: Node3D
var _glove_material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _pose := Vector3(0.0, 0.1, 0.0)
var _walk_time := 0.0
var _clang_cooldown := 0.0
var _circle_sign := 1.0
var _gape_time := 0.0


## Shut (waking, between combos, snapping shut): nothing gets through.
func is_shut() -> bool:
	return _state in [State.WAKING, State.SHUT, State.CLOSING]


func blocks_punch(_punch_type: String, _counter: bool) -> bool:
	return is_shut()


func block_caption() -> String:
	return "SHUT TIGHT"


## Powers, Thorns and blasts clang off a shut lid too.
func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false, armor_cut := 0.0) -> float:
	if is_shut() and not _dead:
		if _clang_cooldown <= 0.0:
			_clang_cooldown = 0.4
			DamagePopup.spawn(get_parent(), block_caption(), Color(0.75, 0.75, 0.8), 36, global_position + Vector3(0, 1.6, 0))
			Sfx.play_at("block", global_position + Vector3.UP, -6.0, 0.8)
		return 0.0
	return super(raw_damage, hit_point, push, stagger, caption, pierce, crush, armor_cut)


func incoming_attack() -> String:
	return _attack if _state in [State.WINDUP, State.STRIKE] else ""


func attack_eta() -> float:
	return _state_timer if _state == State.WINDUP else INF


func combo_finished() -> bool:
	return _queue.is_empty()


## An elite mimic (a cursed chest you chose to fight): a champion with two
## traits, gold corners, purple chains and eyes, longer combos.
func make_elite_mimic() -> void:
	elite = true
	var traits: Array = ELITE_TRAITS.duplicate()
	traits.shuffle()
	make_champion([traits[0], traits[1]])
	display_name = "%s %s Elite Mimic" % [traits[0], traits[1]]
	set_meta("elite", true)
	set_meta("elite_mimic", true)
	var gold := _material(Color(0.95, 0.72, 0.25), 0.8)
	var chain := _glow_material(Color(0.6, 0.2, 0.9))
	chain.emission_energy_multiplier = 2.0
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_part(_chest, _box(Vector3(0.16, 0.16, 0.16)), gold, Vector3(0.56 * x, 0.08, 0.36 * z))
	# Chains round the body, under the rim (clear of the lid).
	for y in [0.18, 0.46]:
		_part(_chest, _box(Vector3(1.26, 0.05, 0.86)), chain, Vector3(0, y, 0))
	_eye_material.albedo_color = Color(0.75, 0.3, 1.0)
	_eye_material.emission = Color(0.75, 0.3, 1.0)
	_update_label()


func _think(delta: float) -> Vector3:
	var offset := _to_player()
	var distance := offset.length()
	_state_timer -= delta
	_clang_cooldown -= delta
	match _state:
		State.WAKING:
			if _state_timer <= 0.0:
				_enter(State.SHUT, randf_range(0.8, 1.4))
			return Vector3.ZERO
		State.SHUT:
			_turn_toward(offset, delta)
			# Rested: claim a turn, close in, and open up once in reach.
			if _state_timer <= 0.0 and has_turn() and distance <= attack_range + 0.6:
				_enter(State.OPENING, OPEN_TIME)
				Sfx.play_at("growl", global_position + Vector3.UP, -2.0, 1.5)
				return Vector3.ZERO
			if not in_turn():
				return _wait_move(offset, delta, move_speed)
			if distance > attack_range - 0.3:
				return offset.normalized() * move_speed
			return offset.normalized().cross(Vector3.UP) * _circle_sign * move_speed * 0.5
		State.OPENING:
			_turn_toward(offset, delta)
			if _state_timer <= 0.0:
				_queue.assign((ELITE_COMBOS if elite else COMBOS).pick_random())
				_dodged_all = true
				var first: String = _queue.pop_front()
				_begin_attack(first, Boxer.FIRST_WINDUP[first])
		State.WINDUP:
			_turn_toward(offset, delta)
			if not _flashed and _state_timer <= tell_time():
				_flashed = true
				_glow(Boxer.CUES[_attack].color, Boxer.FLASH_GLOW)
				_flash_tell(Boxer.CUES[_attack].color, 1.35)
			if _state_timer <= 0.0:
				_strike(distance)
		State.STRIKE:
			if _state_timer <= 0.0:
				if _queue.is_empty():
					var open := GAPE_TIME
					if _dodged_all:
						# Exploit (the Answer's card): open longer still.
						open += DODGED_GAPE + GameState.get_effect("exploit")
					_enter(State.GAPING, open)
				else:
					_begin_attack(_queue.pop_front(), Boxer.FOLLOW_UP_WINDUP)
		State.GAPING:
			_gape_time += delta
			if _state_timer <= 0.0:
				_enter(State.CLOSING, CLOSE_TIME)
				Sfx.play_at("block", global_position + Vector3.UP, -4.0, 0.6)
		State.CLOSING:
			if _state_timer <= 0.0:
				end_turn()
				_circle_sign = [-1.0, 1.0].pick_random()
				_enter(State.SHUT, randf_range(SHUT_TIME.x, SHUT_TIME.y) * (0.7 if elite else 1.0))
	return Vector3.ZERO


func _begin_attack(attack: String, windup: float) -> void:
	_attack = attack
	_flashed = false
	_enter(State.WINDUP, maxf(windup * windup_scale, tell_time() + 0.15) + windup_pad)
	_glow(Boxer.CUES[attack].color, Boxer.PREVIEW_GLOW)
	Sfx.play_at("draw", global_position + Vector3.UP * 1.3, -4.0, 1.4)


func _strike(distance: float) -> void:
	_enter(State.STRIKE, STRIKE_TIME)
	_glow(Color.BLACK, 0.0)
	Sfx.play_at("whoosh", global_position + Vector3.UP * 1.3, -4.0, 1.1)
	if distance > attack_range + 0.6 and not player.is_back_stepping():
		return
	_on_attacking()
	if _dead:
		return
	var result := player.receive_attack(attack_damage * damage_multiplier, global_position, _attack, self)
	if result != "dodged":
		_dodged_all = false


## A counter (or any stagger) cuts its combo short and leaves it gaping.
func _on_staggered() -> void:
	if is_shut() or _state == State.OPENING:
		return
	_queue.clear()
	_glow(Color.BLACK, 0.0)
	_enter(State.GAPING, 0.8)


func _enter(state: State, time: float) -> void:
	_state = state
	_state_timer = time
	_flashed = false
	if state == State.GAPING:
		_gape_time = 0.0


## The glove lights up in the color of the dodge that beats its punch.
func _glow(color: Color, strength: float) -> void:
	if _glove_material == null:
		return
	_glove_material.emission = color
	_glove_material.emission_energy_multiplier = strength * 2.0


## Where the tongue should be this frame: [yaw, pitch, length].
func _tongue_target() -> Vector3:
	var guard: Array = POSES.guard
	match _state:
		State.OPENING:
			var t := 1.0 - clampf(_state_timer / OPEN_TIME, 0.0, 1.0)
			return Vector3(guard[0], guard[1], guard[2] * t)
		State.WINDUP:
			var cocked: Array = POSES[_attack][0]
			return Vector3(cocked[0], cocked[1], cocked[2])
		State.STRIKE:
			var thrown: Array = POSES[_attack][1]
			return Vector3(thrown[0], thrown[1], thrown[2])
		State.GAPING:
			var gape: Array = POSES.gape
			return Vector3(gape[0] + sin(_gape_time * 3.0) * 0.25, gape[1], gape[2])
	return Vector3(guard[0], guard[1], 0.0)


func _animate(delta: float, speed: float) -> void:
	var blend := minf(1.0, 10.0 * delta)
	# Stands up on its legs while waking.
	var stand := 1.0 - clampf(_state_timer / WAKE_TIME, 0.0, 1.0) if _state == State.WAKING else 1.0
	_chest.position.y = lerpf(_chest.position.y, STAND_HEIGHT * stand, blend)
	for i in _legs.size():
		_legs[i].scale.y = maxf(0.05, stand)
	_walk_time += delta * speed * 4.0
	for i in _legs.size():
		_legs[i].rotation.x = sin(_walk_time + i * PI / 2.0) * 0.4 * minf(speed, 1.0)
	# The lid: shut tight (a hop now and then), wide open while it fights.
	var lid_target := 0.0
	match _state:
		State.SHUT:
			lid_target = 0.08 * maxf(0.0, sin(_walk_time * 0.7)) if speed > 0.1 else 0.0
		State.OPENING, State.WINDUP, State.STRIKE, State.GAPING:
			lid_target = LID_OPEN
	var lid_rate := 30.0 if _state == State.CLOSING else 12.0
	_lid.rotation.x = lerpf(_lid.rotation.x, lid_target, minf(1.0, lid_rate * delta))
	# The tongue: out only while the lid is open; snapping out on a punch.
	var target := _tongue_target()
	var rate := 28.0 if _state == State.STRIKE else 12.0
	_pose = _pose.lerp(target, minf(1.0, rate * delta))
	_tongue.visible = not is_shut() and _pose.z > 0.05
	_tongue.rotation = Vector3(_pose.y, _pose.x, 0.0)
	var length := maxf(_pose.z, 0.01)
	_tongue_flesh.scale.z = length
	_tongue_flesh.position.z = -length / 2.0
	_glove.position.z = -length - 0.14


func _build_body() -> void:
	var wood := _material(Color(0.35, 0.22, 0.12))
	var trim := _material(Color(0.85, 0.65, 0.2), 0.7)
	var bone := _material(Color(0.8, 0.77, 0.68))
	var flesh := _material(Color(0.55, 0.12, 0.15))
	var tongue := _material(Color(0.82, 0.32, 0.36))
	_eye_material = _glow_material(Color(1.0, 0.25, 0.15))
	# Spindly bone legs under the chest.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg := _pivot(_body, Vector3(0.4 * x, STAND_HEIGHT, 0.25 * z))
			_part(leg, _cylinder(0.04, STAND_HEIGHT), bone, Vector3(0, -STAND_HEIGHT / 2.0, 0))
			leg.scale.y = 0.05
			_legs.append(leg)
	_chest = Node3D.new()
	_body.add_child(_chest)
	# Twice the size of a normal chest, so it stands at punching height.
	_part(_chest, _box(Vector3(1.2, 0.7, 0.8)), wood, Vector3(0, 0.35, 0))
	_part(_chest, _box(Vector3(1.24, 0.08, 0.84)), trim, Vector3(0, 0.66, 0))
	_part(_chest, _box(Vector3(1.0, 0.3, 0.6)), flesh, Vector3(0, 0.62, 0))
	# Teeth on the front rim, a gap in the middle for the tongue.
	for x in [-0.42, -0.24, 0.24, 0.42]:
		_part(_chest, _box(Vector3(0.07, 0.1, 0.05)), bone, Vector3(x, 0.74, -0.38))
	# The tongue, rooted above the rim, with a boxing glove on the end.
	_tongue = _pivot(_chest, Vector3(0, 0.83, -0.3))
	_tongue_flesh = _part(_tongue, _box(Vector3(0.14, 0.06, 1.0)), tongue, Vector3(0, 0, -0.5))
	_glove = _pivot(_tongue, Vector3(0, 0, -0.6))
	# Emissive from the start (lit up per tell), so it isn't swapped for a
	# shared voxel material.
	_glove_material = _material(GLOVE_RED)
	_glove_material.emission_enabled = true
	_glove_material.emission_energy_multiplier = 0.0
	_part(_glove, _box(Vector3(0.28, 0.24, 0.28)), _glove_material, Vector3(0, 0.02, -0.02))
	_part(_glove, _box(Vector3(0.07, 0.1, 0.14)), _glove_material, Vector3(-0.17, -0.02, 0.0))
	_part(_glove, _box(Vector3(0.22, 0.18, 0.08)), _material(Color(0.92, 0.9, 0.86)), Vector3(0, 0.0, 0.15))
	_tongue.visible = false
	_lid = _pivot(_chest, Vector3(0, 0.7, 0.4))
	_part(_lid, _box(Vector3(1.2, 0.3, 0.8)), wood, Vector3(0, 0.15, -0.4))
	_part(_lid, _box(Vector3(0.18, 0.18, 0.06)), trim, Vector3(0, 0.05, -0.82))
	for x in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		_part(_lid, _box(Vector3(0.07, 0.1, 0.05)), bone, Vector3(x, -0.04, -0.78))
	for side in [-1.0, 1.0]:
		_part(_lid, _box(Vector3(0.1, 0.06, 0.02)), _eye_material, Vector3(0.25 * side, 0.18, -0.81))


func _build_armor() -> void:
	pass


## No gear overlays: it's a chest.
func _gear_style() -> String:
	return "none"
