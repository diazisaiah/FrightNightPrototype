class_name EmotePreview
extends SubViewportContainer
## A little live stage: your fighter (wearing your hat) doing a dance on a
## loop. The Soul Shop's emote cards and Cosmetics → Emotes.

## The dance to play once on stage ("" for none yet; see play()).
var emote_id := ""
var body: PlayerBody
var _camera: Camera3D


## distance: how far the camera stands (further shows more around the body).
func _init(fighter := "", distance := 4.2) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.66)
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.5, 0)
	viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	var eye := Vector3(0, 1.1, -distance)
	_camera.transform = Transform3D(Basis.looking_at(Vector3(0, 0.92, 0) - eye), eye)
	viewport.add_child(_camera)
	body = PlayerBody.new(fighter)
	body.build_budget_ms = 12
	body.rotation.y = -0.35
	viewport.add_child(body)


func _ready() -> void:
	# The body settles into its rest pose when it's ready, so the dance
	# starts after that.
	if emote_id != "":
		body.play(emote_id)


func play(id: String) -> void:
	emote_id = id
	if is_inside_tree():
		body.play(id)
