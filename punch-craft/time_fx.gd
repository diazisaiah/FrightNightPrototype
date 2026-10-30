extends Node
## Freeze-frames and slow motion (autoloaded as TimeFx). Overlapping effects
## don't fight: the slowest active one wins, and each runs on real time.

const HITSTOP_SCALE := 0.03
## Hit freezes run this share of what's asked (2026-10-30: halved; on a slow
## computer a freeze lasts at least a frame, and they read as lag).
const HITSTOP_SHARE := 0.5

var _effects: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Settings' "Slow motion" slider scales hit freezes too (0 turns them off).
func hitstop(duration: float) -> void:
	var strength: float = Settings.get_value("slow_motion")
	if strength <= 0.0:
		return
	_push(HITSTOP_SCALE, duration * HITSTOP_SHARE * strength)


## Settings' "Slow motion" slider scales how much it slows (0 turns it off).
func slowmo(time_scale: float, duration: float) -> void:
	var strength: float = Settings.get_value("slow_motion")
	if strength <= 0.0:
		return
	_push(lerpf(1.0, time_scale, strength), duration)


## Drops all effects and restores normal speed (e.g. when leaving a run).
func clear() -> void:
	_effects.clear()
	Engine.time_scale = 1.0


func _push(time_scale: float, duration: float) -> void:
	if duration <= 0.0:
		return
	_effects.append({"scale": time_scale, "until": _now() + duration})
	_apply()


func _process(_delta: float) -> void:
	if not _effects.is_empty():
		_apply()


func _apply() -> void:
	var now := _now()
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return effect.until > now)
	var time_scale := 1.0
	for effect in _effects:
		time_scale = minf(time_scale, effect.scale)
	Engine.time_scale = time_scale


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
