extends Node3D
## Banner pose (2026-10-29): the four revamp bodies (revamp_body.gd) posed
## like the Fright Night four-fighter banner (store_assets/fright-night-
## banner.png), as a reference for new art: the Blur lunging in from the
## left, the Mauler front and center driving both gloves at the camera, the
## Answer in a high guard behind him, the Stray low on the right throwing a
## punch, headband tails streaming. Rendered off screen at the banner's
## size (2172x724, wider than most screens) and shown fitted in the window.
##   res://playground/character_lab/banner_pose.tscn -- --capture
## saves a moody version (dark, each fighter rim-lit in their color) and a
## plain studio one, then quits.

const RevampBody = preload("res://playground/character_lab/revamp_body.gd")
const OUT := "user://character_lab_captures/"
const SIZE := Vector2i(2172, 724)
## Each fighter: where they stand (x as seen on screen, + to the right; the
## camera faces them, so it's flipped into the world), their turn, their rim light, and the pose
## (PlayerBody joints, Emotes conventions; lf / rf are the ankle pivots).
const CAST := {
	"combo_master": {
		"at": Vector3(-1.85, 0, 0.55), "turn": 0.5, "rim": Color(0.62, 0.3, 1.0),
		"pose": {
			"pos": Vector3(0, -0.14, 0), "torso": Vector3(-0.3, 0.35, 0.08), "head": Vector3(0.2, -0.3, 0),
			"ls": Vector3(1.55, 0, -0.05), "le": Vector3(0.1, 0, 0),
			"rs": Vector3(0.9, 0, 0.35), "re": Vector3(2.1, 0, 0),
			"lh": Vector3(0.4, 0, -0.05), "lk": Vector3(-0.2, 0, 0), "rh": Vector3(-0.4, 0, 0.05), "rk": Vector3(0.0, 0, 0),
			"lf": Vector3(0, 0.1, 0), "rf": Vector3(0, -0.6, 0),
		},
	},
	"berserker": {
		"at": Vector3(-0.5, 0, -0.45), "turn": -0.1, "rim": Color(1.0, 0.38, 0.1),
		"pose": {
			# One punch: a right cross driving at the camera, the hips and
			# shoulders turned into it, the left glove up guarding the chin.
			"pos": Vector3(0, -0.1, 0), "torso": Vector3(-0.32, 0.42, 0), "head": Vector3(0.3, -0.35, 0),
			"ls": Vector3(1.05, 0, -0.2), "le": Vector3(2.1, 0, 0),
			"rs": Vector3(1.6, 0, -0.12), "re": Vector3(0.12, 0, 0),
			"lh": Vector3(0.3, 0, -0.1), "lk": Vector3(-0.15, 0, 0), "rh": Vector3(-0.25, 0, 0.08), "rk": Vector3(0.0, 0, 0),
			"lf": Vector3(0, 0.05, 0), "rf": Vector3(0, -0.55, 0),
		},
	},
	"counter_master": {
		"at": Vector3(0.75, 0, 0.45), "turn": -0.3, "rim": Color(0.3, 0.6, 1.0),
		"pose": {
			"pos": Vector3(0, -0.06, 0), "torso": Vector3(-0.2, 0.2, 0), "head": Vector3(0.05, -0.15, 0),
			"ls": Vector3(1.2, 0, 0.05), "le": Vector3(2.25, 0, 0),
			"rs": Vector3(1.05, 0, -0.1), "re": Vector3(2.35, 0, 0),
			"lh": Vector3(0.35, 0, 0), "lk": Vector3(-0.3, 0, 0), "rh": Vector3(-0.2, 0, 0), "rk": Vector3(-0.2, 0, 0),
			"lf": Vector3(0, 0.0, 0), "rf": Vector3(0, -0.6, 0),
		},
	},
	"free_runner": {
		"at": Vector3(1.95, 0, 0.0), "turn": -0.55, "rim": Color(0.3, 1.0, 0.45),
		"pose": {
			"pos": Vector3(0, -0.2, 0), "torso": Vector3(-0.32, -0.4, -0.1), "head": Vector3(0.28, 0.25, 0),
			"ls": Vector3(1.0, 0, -0.3), "le": Vector3(2.0, 0, 0),
			"rs": Vector3(1.6, 0, -0.15), "re": Vector3(0.12, 0, 0),
			"lh": Vector3(0.45, 0, -0.15), "lk": Vector3(-0.2, 0, 0), "rh": Vector3(-0.45, 0, 0.12), "rk": Vector3(0.0, 0, 0),
			"lf": Vector3(0, 0.15, 0), "rf": Vector3(0, -0.65, 0),
		},
	},
}

var _view: SubViewport
var _env: Environment
var _key: DirectionalLight3D
var _rims: Array = []
var _floor: MeshInstance3D


func _ready() -> void:
	_view = SubViewport.new()
	_view.size = SIZE
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	var shown := TextureRect.new()
	shown.texture = _view.get_texture()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	layer.add_child(shown)
	_stage()
	for fighter in CAST:
		_cast(fighter, CAST[fighter])
	if "--capture" in OS.get_cmdline_user_args():
		await _snap("banner_pose_moody.png")
		_studio()
		await _snap("banner_pose_studio.png")
		get_tree().quit()


func _cast(fighter: String, spec: Dictionary) -> void:
	var body = RevampBody.new(fighter, "")
	body.voxel_scale = "large"
	body.build_budget_ms = 100000
	var at: Vector3 = spec.at * Vector3(-1, 1, 1)
	body.position = at
	body.rotation.y = spec.turn
	_view.add_child(body)
	body.finish_build()
	body.wear_hat("")
	body._apply(spec.pose)
	for ankle in ["lf", "rf"]:
		if body._joints.has(ankle) and spec.pose.has(ankle):
			(body._joints[ankle] as Node3D).rotation = spec.pose[ankle]
	# The fighter's color from behind and to the side, like the banner's glow.
	var rim := OmniLight3D.new()
	rim.light_color = spec.rim
	rim.light_energy = 6.0
	rim.omni_range = 3.2
	rim.light_cull_mask = 0xFFFFF
	rim.position = at + Vector3(0.6 * signf(at.x + 0.01), 1.6, 1.0)
	_view.add_child(rim)
	_rims.append(rim)


func _stage() -> void:
	var environment := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.03, 0.03, 0.08)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.45, 0.45, 0.65)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.12, 0.1, 0.22)
	_env.fog_density = 0.012
	environment.environment = _env
	_view.add_child(environment)
	_key = DirectionalLight3D.new()
	_key.rotation_degrees = Vector3(-35, 165, 0)
	_key.light_color = Color(0.85, 0.85, 1.0)
	_key.light_energy = 1.0
	_key.shadow_enabled = true
	_key.light_cull_mask = 0xFFFFF
	_view.add_child(_key)
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.11, 0.15)
	material.roughness = 1.0
	plane.material = material
	_floor.mesh = plane
	_view.add_child(_floor)
	var camera := Camera3D.new()
	camera.fov = 26.0
	# Pulled back so all four stand whole in the middle, room above their
	# heads for the title.
	camera.position = Vector3(0.0, 1.15, -6.6)
	_view.add_child(camera)
	camera.look_at(Vector3(0.0, 1.25, 0.2), Vector3.UP)
	camera.make_current()


## The same poses on a plain gray studio set (no colored light, no fog).
func _studio() -> void:
	_env.background_color = Color(0.16, 0.17, 0.2)
	_env.ambient_light_color = Color(0.62, 0.64, 0.7)
	_env.ambient_light_energy = 0.9
	_env.fog_enabled = false
	_key.light_energy = 1.5
	_key.light_color = Color(1.0, 0.95, 0.88)
	(_floor.mesh.material as StandardMaterial3D).albedo_color = Color(0.3, 0.31, 0.34)
	for rim in _rims:
		rim.visible = false


func _snap(file: String) -> void:
	for i in 4:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + file)
	_view.get_texture().get_image().save_png(path)
	print("BANNER_POSE ", path)
