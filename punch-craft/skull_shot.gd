class_name SkullShot
extends Node3D
## The Headless's Skull Toss: its burning skull flies at your face, bites,
## then floats home. Slip it (either side), or punch it out of the air: that
## hurts the Headless (SKULL_BONUS x the punch) and knocks the skull to the
## floor, and the body fights blind until the skull floats back up.

const SPEED := 7.0
## How hard it steers toward you in flight (it locks on late, so a slip works).
const HOMING := 2.5
const BITE_REACH := 0.8
const SKULL_BONUS := 3.0
const HOME_TIME := 0.55
const RISE_TIME := 0.8

var boss: DeadLeagueBoss
var _player: Player
var _head: Node3D
## fly (coming at you), home (back to the neck), down (on the floor), rise.
var _state := "fly"
var _velocity := Vector3.ZERO
var _time := 0.0
var _flames: CPUParticles3D


## Takes the boss's skull node and throws it at the player.
static func toss(from: DeadLeagueBoss, head: Node3D, at: Player) -> SkullShot:
	var shot := SkullShot.new()
	shot.boss = from
	shot._player = at
	from.get_parent().add_child(shot)
	shot.global_position = head.global_position
	shot._head = head
	head.reparent(shot)
	shot.add_to_group("punchable")
	shot._velocity = (shot._aim() - shot.global_position).normalized() * SPEED
	shot._flames = shot._trail()
	Sfx.play_at("whoosh", shot.global_position, 2.0, 0.6)
	return shot


func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss):
		queue_free()
		return
	_time += delta
	match _state:
		"fly":
			var want := (_aim() - global_position).normalized() * SPEED
			_velocity = _velocity.lerp(want, minf(1.0, HOMING * delta))
			global_position += _velocity * delta
			_head.rotation.x += delta * 9.0
			if global_position.distance_to(_aim()) <= BITE_REACH:
				_bite()
			elif _time > 3.0:
				_go_home()
		"down":
			# Sputtering on the floor, rocking a little.
			_head.rotation.z = sin(_time * 7.0) * 0.12


## Your face (a bit below the eyes).
func _aim() -> Vector3:
	return _player.global_position + Vector3(0, 1.45, 0)


func _bite() -> void:
	remove_from_group("punchable")
	if is_instance_valid(_player) and _player.active:
		var result := _player.receive_attack(boss.attack_damage * 1.2 * boss.damage_multiplier, global_position, "fireball", boss)
		if result != "dodged":
			Sfx.play_at("heavy", global_position, -2.0, 0.7)
	_go_home()


func _go_home() -> void:
	_state = "home"
	remove_from_group("punchable")
	var tween := create_tween()
	tween.tween_method(_home_step.bind(global_position), 0.0, 1.0, HOME_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_attach)


## Flies back along an arc to wherever the neck is now.
func _home_step(u: float, from: Vector3) -> void:
	if not is_instance_valid(boss):
		return
	var to := boss.skull_home()
	global_position = from.lerp(to, u) + Vector3.UP * sin(u * PI) * 0.6
	_head.rotation = _head.rotation.lerp(Vector3.ZERO, u)


## Punched out of the air: the Headless takes it, and the skull drops.
func punched(type: String, _hand: String, puncher: Player) -> void:
	if _state != "fly":
		return
	remove_from_group("punchable")
	var damage := GameState.get_damage() * puncher.get_combo_multiplier() * float(Player.PUNCHES[type].mult) * SKULL_BONUS
	boss.take_hit(damage, global_position, Vector3.ZERO, false, "SKULL SHOT!")
	Sfx.play("heavy", 0.0, 1.1)
	HitFx.burst(get_parent(), global_position, -_velocity.normalized(), DeadLeagueRules.boss(1).accent, 22, 5.0, true, 0.06)
	puncher.shake(0.08)
	_state = "down"
	_flames.emitting = false
	if boss.is_dead():
		_fall(true)
		return
	_fall(false)
	boss.skull_down()


## Down to the floor in a bounce, away from the punch.
func _fall(for_good: bool) -> void:
	var away := _velocity
	away.y = 0.0
	away = -away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var floor_y := boss.global_position.y + 0.18
	var land := global_position + away * 1.6
	land.y = floor_y
	var tween := create_tween()
	tween.tween_property(self, "global_position", Vector3(land.x, global_position.y + 0.4, land.z), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", floor_y, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Sfx.play_at("heavy", global_position, -6.0, 0.8)
		HitFx.burst(get_parent(), global_position, Vector3.UP, Color(0.45, 0.38, 0.3), 12, 2.0, false, 0.06))
	tween.tween_property(self, "global_position:y", floor_y + 0.2, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", floor_y, 0.12).set_ease(Tween.EASE_IN)
	if for_good:
		tween.tween_property(_head, "rotation:z", 1.3, 0.3)


## The blindness is over: the skull lifts off the floor and floats home.
func recall() -> void:
	if _state != "down":
		return
	_state = "rise"
	_flames.emitting = true
	var tween := create_tween()
	tween.tween_method(_home_step.bind(global_position), 0.0, 1.0, RISE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_attach)


func _attach() -> void:
	if is_instance_valid(boss):
		boss.skull_back(_head)
	queue_free()


## Blue fire trailing behind it.
func _trail() -> CPUParticles3D:
	var trail := CPUParticles3D.new()
	trail.amount = 20
	trail.lifetime = 0.35
	trail.local_coords = false
	var bit := BoxMesh.new()
	bit.size = Vector3.ONE * 0.08
	bit.material = Enemy._glow_material(DeadLeagueRules.boss(1).accent)
	trail.mesh = bit
	trail.spread = 180.0
	trail.initial_velocity_min = 0.2
	trail.initial_velocity_max = 0.7
	trail.gravity = Vector3(0, 1.2, 0)
	add_child(trail)
	return trail
