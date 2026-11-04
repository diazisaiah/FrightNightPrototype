class_name LockOn
extends Node
## Lock-on camera (a child of Player; GAME_DESIGN.md, "Lock-on camera plan").
##
## Picks a target (the enemy that is attacking, else the nearest one in front),
## turns the body and the camera toward it, and lets punches that are close
## enough and roughly facing it land on it. Three strengths:
##   soft   - a gentle pull that eases off while you steer yourself
##   blend  - turns on its own, smoothed, with a short auto-step (touch default)
##   hard   - snaps to the target and holds it
## Settings "lock_on": auto (blend on touch, off elsewhere), off, soft, blend,
## hard. F (or the LOCK button on touch) cycles targets by hand; with the
## setting on "off" it also works as a temporary lock.

const ACQUIRE := 12.0
const KEEP := 14.0
const PICK_EVERY := 0.12
## After a kill, the next target locks after this beat.
const NEXT_BEAT := 0.35
## While you steer yourself the pull is scaled down for this long (seconds).
const NUDGE_TIME := 0.35

## turn: how fast it eases (1/s); max: degrees a second at most; arc: how far
## off-center a punch may still land (degrees); step: auto-step (metres);
## nudged: how much of the pull is left while you steer yourself.
const LEVELS := {
	"soft": {"turn": 4.0, "max": 200.0, "arc": 25.0, "step": 0.0, "nudged": 0.0},
	"blend": {"turn": 9.0, "max": 500.0, "arc": 35.0, "step": 0.4, "nudged": 0.35},
	"hard": {"turn": 20.0, "max": 900.0, "arc": 45.0, "step": 0.6, "nudged": 1.0},
}

var player: Player
var target: Enemy
var _manual := false
var _session := false
var _pick_t := 0.0
var _nudge_t := 99.0
var _reticle: Control
## Looking up or down with the stick while locked (radians added to the aim).
var pitch_bias := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("lock_cycle"):
		InputMap.add_action("lock_cycle")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F
		InputMap.action_add_event("lock_cycle", key)
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	_reticle = Control.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reticle.draw.connect(_draw_reticle)
	layer.add_child(_reticle)


func _process(_delta: float) -> void:
	# Pause menus and popups freeze the player, so the reticle hides itself.
	var layer := _reticle.get_parent() as CanvasLayer
	layer.visible = not get_tree().paused


## The strength in use right now: "off", "soft", "blend" or "hard".
func level() -> String:
	var chosen := str(Settings.get_value("lock_on"))
	if chosen == "auto":
		chosen = "blend" if TouchUi.enabled else "off"
	if chosen == "off" and _session:
		return "blend"
	return chosen


## True while the view is locked on something (touch hides the look stick).
func in_combat() -> bool:
	return target != null and level() != "off"


## You turned the view yourself (mouse or stick): ease the pull for a moment.
func nudge() -> void:
	_nudge_t = 0.0


## Called by Player every frame it is fighting.
func steer(delta: float) -> void:
	_nudge_t += delta
	if Input.is_action_just_pressed("lock_cycle"):
		cycle()
	var lv := level()
	if lv == "off":
		if target != null:
			target = null
			_manual = false
		pitch_bias = 0.0
		_reticle.queue_redraw()
		return
	_pick_t -= delta
	if _pick_t <= 0.0:
		_pick_t = PICK_EVERY
		_choose()
	_reticle.queue_redraw()
	if target == null:
		pitch_bias = 0.0
	if target == null or player.ult.busy() or player.emote != "":
		return
	var cfg: Dictionary = LEVELS[lv]
	var strength := 1.0
	if _nudge_t < NUDGE_TIME:
		strength = float(cfg.nudged)
	if strength <= 0.0:
		return
	var camera: Camera3D = player._camera
	var from := camera.global_position
	var to := target.aim_point()
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length() < 0.3:
		return
	var yaw_error := wrapf(atan2(-flat.x, -flat.y) - player.rotation.y, -PI, PI)
	if absf(yaw_error) > deg_to_rad(1.5):
		var step := yaw_error * (1.0 - exp(-float(cfg.turn) * strength * delta))
		var cap := deg_to_rad(float(cfg.max)) * delta
		player.rotate_y(clampf(step, -cap, cap))
	var want_pitch := clampf(atan2(to.y - from.y, flat.length()) + pitch_bias, -0.9, 0.9)
	var pitch_error := want_pitch - camera.rotation.x
	if absf(pitch_error) > deg_to_rad(1.0):
		camera.rotation.x += pitch_error * (1.0 - exp(-float(cfg.turn) * 0.6 * strength * delta))
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


## The enemy a punch should land on when the straight ray found nothing: the
## locked one, if it is in reach and roughly in front. May step you toward it.
func punch_target(reach: float) -> Enemy:
	var lv := level()
	if target == null or lv == "off" or not _valid(target):
		return null
	var cfg: Dictionary = LEVELS[lv]
	var to := target.global_position - player.global_position
	to.y = 0.0
	var distance := to.length()
	var in_reach := reach + 0.5
	if distance > in_reach + float(cfg.step):
		return null
	var forward := -player.global_basis.z
	forward.y = 0.0
	if distance > 0.01 and forward.normalized().angle_to(to.normalized()) > deg_to_rad(float(cfg.arc)):
		return null
	if distance > in_reach and float(cfg.step) > 0.0:
		player.move_and_collide(to.normalized() * (distance - in_reach + 0.1))
	return target


## The LOCK button (and F): lock the best target, or move to the next one.
## After the last one it goes back to choosing by itself.
func cycle() -> void:
	var list := _candidates()
	if list.is_empty():
		target = null
		_manual = false
		_session = false
		return
	var index := list.find(target)
	if target == null or index == -1:
		target = list[0]
		_manual = true
		if str(Settings.get_value("lock_on")) == "off":
			_session = true
	elif index + 1 < list.size():
		target = list[index + 1]
		_manual = true
	else:
		target = null
		_manual = false
		_session = false
		_pick_t = 1.0  # Let go for a second before it picks again.


## Everything in range, best first (attacker, then near and in front).
func _candidates() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not _valid(enemy):
			continue
		if enemy.global_position.distance_to(player.global_position) <= ACQUIRE:
			list.append(enemy)
	list.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _score(a) < _score(b))
	return list


## Alive, in the scene, shown and running (the tutorial's dummy steps out of
## the ring for the live fights: hidden and switched off).
func _valid(enemy: Enemy) -> bool:
	return enemy != null and is_instance_valid(enemy) and enemy.is_inside_tree() and not enemy.is_dead() 			and enemy.is_visible_in_tree() and enemy.can_process() and enemy.is_in_group("enemies")


func _score(enemy: Enemy) -> float:
	var to := enemy.global_position - player.global_position
	to.y = 0.0
	var distance := to.length()
	var forward := -player.global_basis.z
	forward.y = 0.0
	var angle := 0.0
	if distance > 0.01:
		angle = forward.normalized().angle_to(to.normalized())
	var score := distance * (1.0 + angle / PI)
	if enemy.takes_turns and enemy.in_turn():
		score -= 3.0
	return score


func _choose() -> void:
	if target != null and not _valid(target):
		target = null
		_manual = false
		_pick_t = NEXT_BEAT
		return
	if target != null and target.global_position.distance_to(player.global_position) > KEEP:
		target = null
		_manual = false
	var list := _candidates()
	if list.is_empty():
		return
	if target == null:
		target = list[0]
	elif not _manual and list[0] != target and _score(list[0]) < _score(target) * 0.7:
		target = list[0]


func _draw_reticle() -> void:
	if get_tree().paused:
		return
	if target == null or level() == "off" or not is_instance_valid(target) or target.is_dead():
		return
	var camera: Camera3D = player._camera
	if camera == null or not camera.current:
		return
	var point := target.aim_point()
	if camera.is_position_behind(point):
		return
	var center := camera.unproject_position(point)
	var distance := camera.global_position.distance_to(point)
	var radius := clampf(34.0 / maxf(distance, 1.0) * 3.0, 14.0, 40.0)
	var color := Color(1.0, 0.85, 0.35, 0.85)
	_reticle.draw_arc(center, radius, 0.0, TAU, 28, color, 2.0)
	for i in 4:
		var angle := i * PI * 0.5 + PI * 0.25
		var direction := Vector2(cos(angle), sin(angle))
		_reticle.draw_line(center + direction * (radius + 2.0), center + direction * (radius + 8.0), color, 2.0)
	var width := 54.0
	var fraction := clampf(target.hp / maxf(target.max_hp, 1.0), 0.0, 1.0)
	var bar := Rect2(center + Vector2(-width * 0.5, radius + 12.0), Vector2(width, 5.0))
	_reticle.draw_rect(bar, Color(0, 0, 0, 0.6))
	_reticle.draw_rect(Rect2(bar.position, Vector2(width * fraction, bar.size.y)), Color(0.9, 0.25, 0.2, 0.9))
