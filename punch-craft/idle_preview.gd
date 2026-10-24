class_name IdlePreview
extends SubViewportContainer
## A small live view of a fighter's hands playing a hand idle on a loop
## (IdleAnims): the Loadout's idle cards and the Soul Shop.

const GAP := 1.0

var idle_id := ""
## A class id; empty: the current fighter.
var fighter := ""

var _fists: Fists
var _wait := 0.5


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.55, 0.62)
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0, 0.08, 0.12)
	viewport.add_child(camera)
	_fists = Fists.new()
	_fists.fighter = fighter if fighter != "" else GameState.player_class
	_fists.silent = true
	camera.add_child(_fists)


func _process(delta: float) -> void:
	if _fists == null or _fists.idle_playing:
		return
	_wait -= delta
	if _wait <= 0.0:
		_fists.play_idle(idle_id)
		_wait = GAP
