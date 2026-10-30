class_name BenchProbe
extends Node
## WebBench's script timer: one probe runs first in every frame and physics
## step (lowest priority), one runs last (highest), so the time between them
## is everything the game's scripts did in that frame or step.

static var process_us := 0
static var physics_us := 0
static var _start := 0
static var _physics_start := 0

var last := false


func _init(is_last := false) -> void:
	last = is_last
	process_priority = 100000 if last else -100000
	process_physics_priority = 100000 if last else -100000
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if last:
		process_us += Time.get_ticks_usec() - _start
	else:
		_start = Time.get_ticks_usec()


func _physics_process(_delta: float) -> void:
	if last:
		physics_us += Time.get_ticks_usec() - _physics_start
	else:
		_physics_start = Time.get_ticks_usec()
