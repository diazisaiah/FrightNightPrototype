extends Node3D
## Body revamp lineup (2026-10-29): the four base fighters rebuilt in large
## cubes (fighter_body.gd) side by side, on the Character Lab's animation rig,
## under the same camera, light and floor. Pick a view, a pose (any of the
## lab's 50 states, held or looping), a hat, a silhouette check, or swap in
## the current production bodies for reference.
## Run with -- --capture (review shots) or -- --poses (five poses), then quit.

const AvatarScript = preload("res://playground/character_lab/fighter_avatar.gd")
const RevampBody = preload("res://fighter_body.gd")
const FIGHTERS := ["berserker", "counter_master", "combo_master", "free_runner", "elementalist", "wise_guy"]
const NAMES := {"berserker": "The Mauler", "counter_master": "The Answer", "combo_master": "The Blur", "free_runner": "The Stray", "elementalist": "The Catalyst", "wise_guy": "Tony"}
## Pose shots (-- --poses): [action, phase, body turn, camera, look-at height].
const POSE_SHOTS := [
	["guard", 0.5, -0.6, Vector3(0.0, 1.45, -4.5), 0.95],
	["cross_right", 0.42, -1.25, Vector3(0.0, 1.3, -4.5), 0.95],
	["uppercut_right", 0.5, -0.3, Vector3(0.0, 0.45, -4.3), 1.0],
	["slip_left", 0.5, 0.55, Vector3(0.0, 2.1, -4.3), 0.9],
	["taunt", 0.55, 0.3, Vector3(0.0, 1.25, -4.3), 0.95],
]
const VIEWS := {"Front": 0.0, "Three-quarter": -0.7, "Side": -PI / 2.0, "Back": PI}
const HATS := {"No hat": "", "Cap": "pocket_trainer_cap", "Crown": "paper_crown", "Mask": "iron_mask", "Wig": "wig_black"}
const SPACING := 1.1
const OUT := "user://character_lab_captures/"

var _avatars: Array = []
var _labels: Array = []
var _view := "Front"
var _hat := ""
var _pose := "guard"
var _playing := false
var _turntable := false
## "large" (the revamp) or "" (the current production bodies).
var _variant := "large"
var _yaw := 0.0
var _panel: Control
var _camera: Camera3D


func _ready() -> void:
	_stage()
	_build_avatars()
	_build_panel()
	_set_pose("guard")
	if "--capture" in OS.get_cmdline_user_args():
		_panel.visible = false
		await _capture_all()
		get_tree().quit()
	elif "--poses" in OS.get_cmdline_user_args():
		_panel.visible = false
		await _capture_poses()
		get_tree().quit()


func _process(delta: float) -> void:
	if _turntable:
		_yaw += delta * 0.6
	for avatar in _avatars:
		avatar.rotation.y = VIEWS[_view] + _yaw


# --- The stage -----------------------------------------------------------------------

func _stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 160, 0)
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 1.5
	key.shadow_enabled = true
	key.light_cull_mask = 0xFFFFF
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -150, 0)
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 0.55
	fill.light_cull_mask = 0xFFFFF
	add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -10, 0)
	rim.light_color = Color(0.75, 0.85, 1.0)
	rim.light_energy = 0.7
	rim.light_cull_mask = 0xFFFFF
	add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(9, 6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.31, 0.34)
	material.roughness = 1.0
	plane.material = material
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	add_child(_camera)
	_frame_camera()
	_camera.make_current()


func _frame_camera() -> void:
	var across := SPACING * (_avatars.size() - 1) if _avatars.size() > 1 else SPACING * 0.6
	_camera.position = Vector3(0, 1.25, -3.9 - across * 0.95)
	_camera.look_at(Vector3(0, 1.12, 0), Vector3.UP)


func _build_avatars() -> void:
	for avatar in _avatars:
		avatar.queue_free()
	for label in _labels:
		label.queue_free()
	_avatars.clear()
	_labels.clear()
	for i in FIGHTERS.size():
		var avatar: PlaygroundFighterAvatar = AvatarScript.new(FIGHTERS[i], "")
		avatar.body_variant = _variant
		# Facing the camera (at -Z), left to right in the order above.
		avatar.position = Vector3((i - (FIGHTERS.size() - 1) * 0.5) * -SPACING, 0, 0)
		add_child(avatar)
		_avatars.append(avatar)
		var label := Label3D.new()
		label.text = NAMES[FIGHTERS[i]] + ("" if _variant != "" else " (current)")
		label.font_size = 48
		label.outline_size = 14
		label.pixel_size = 0.0022
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var tall := _tall(avatar)
		label.position = avatar.position + Vector3(0, 2.1 * tall + 0.12, 0)
		add_child(label)
		_labels.append(label)
		var cubes := Label3D.new()
		cubes.text = "%d cubes" % _cube_count(avatar)
		cubes.font_size = 30
		cubes.outline_size = 10
		cubes.pixel_size = 0.0022
		cubes.modulate = Color(0.8, 0.82, 0.88)
		cubes.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cubes.position = avatar.position + Vector3(0, 2.1 * tall + 0.02, 0)
		add_child(cubes)
		_labels.append(cubes)
	if _camera:
		_frame_camera()
	_set_hat(_hat)
	_set_pose(_pose)


## How tall this fighter stands against the usual body (0.92).
func _tall(avatar: PlaygroundFighterAvatar) -> float:
	return avatar._production_body.scale.y / 0.92


func _cube_count(avatar: PlaygroundFighterAvatar) -> int:
	var total := 0
	for node in avatar._production_geometry():
		if node is MultiMeshInstance3D:
			total += (node as MultiMeshInstance3D).multimesh.instance_count
	return total


func _set_hat(id: String) -> void:
	_hat = id
	for avatar in _avatars:
		avatar._production_body.wear_hat(id)


func _set_pose(action: String) -> void:
	_pose = action
	for avatar in _avatars:
		avatar.loop_action = _playing
		avatar.preview(action)
		avatar.paused = not _playing
		if not _playing:
			avatar._action_time = avatar._action_duration * 0.5
			avatar._apply_pose()


# --- The panel -----------------------------------------------------------------------

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "BODY REVAMP: LARGE CUBES"
	box.add_child(title)
	box.add_child(_row("View", VIEWS.keys(), func(id: String) -> void:
		_view = id
		_yaw = 0.0))
	box.add_child(_row("Hat", HATS.keys(), func(id: String) -> void: _set_hat(HATS[id])))
	var poses := OptionButton.new()
	for action in PlaygroundFighterAvatar.ACTIONS:
		poses.add_item(action)
	poses.select(PlaygroundFighterAvatar.ACTIONS.find("guard"))
	poses.item_selected.connect(func(i: int) -> void: _set_pose(PlaygroundFighterAvatar.ACTIONS[i]))
	box.add_child(poses)
	box.add_child(_toggle("Play (loop the pose)", func(on: bool) -> void:
		_playing = on
		_set_pose(_pose)))
	box.add_child(_toggle("Turntable", func(on: bool) -> void:
		_turntable = on
		_yaw = 0.0))
	box.add_child(_toggle("Silhouette", func(on: bool) -> void:
		for avatar in _avatars:
			avatar.set_silhouette(on)))
	box.add_child(_toggle("Current bodies instead", func(on: bool) -> void:
		_variant = "" if on else "large"
		_build_avatars()))
	var capture := Button.new()
	capture.text = "Capture this view"
	capture.pressed.connect(func() -> void:
		_panel.visible = false
		await _snap("voxel_compare_%s.png" % Time.get_datetime_string_from_system().replace(":", "-"))
		_panel.visible = true)
	box.add_child(capture)
	var back := Button.new()
	back.text = "Back to the playground"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://playground/playground.tscn"))
	box.add_child(back)


func _row(label: String, items: Array, chosen: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.custom_minimum_size.x = 44
	row.add_child(name_label)
	for item in items:
		var button := Button.new()
		button.text = item
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: chosen.call(item))
		row.add_child(button)
	return row


func _toggle(text: String, toggled: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	check.toggled.connect(toggled)
	return check


# --- Captures ------------------------------------------------------------------------

func _snap(file: String) -> Image:
	for i in 4:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var path := ProjectSettings.globalize_path(OUT + file)
	image.save_png(path)
	print("VOXEL_COMPARE ", path)
	return image


## Every view in guard, each test hat at three-quarter, a silhouette, and a
## punch, plus two contact sheets.
func _capture_all() -> void:
	var views: Array[Image] = []
	for view in VIEWS:
		_view = view
		views.append(await _snap("voxel_compare_%s.png" % view.to_lower()))
	_sheet(views, "voxel_compare_views.png")
	_view = "Three-quarter"
	var hats: Array[Image] = []
	for hat in ["Cap", "Crown", "Mask", "Wig"]:
		_set_hat(HATS[hat])
		hats.append(await _snap("voxel_compare_hat_%s.png" % hat.to_lower()))
	_sheet(hats, "voxel_compare_hats.png")
	_set_hat("")
	_view = "Front"
	for avatar in _avatars:
		avatar.set_silhouette(true)
	await _snap("voxel_compare_silhouette.png")
	for avatar in _avatars:
		avatar.set_silhouette(false)
	_view = "Three-quarter"
	_set_pose("cross_right")
	await _snap("voxel_compare_cross.png")
	_set_pose("guard")
	# Each fighter close, three-quarter.
	_view = "Three-quarter"
	for i in _avatars.size():
		var subject: Vector3 = _avatars[i].position
		var tall := _tall(_avatars[i])
		_camera.position = subject + Vector3(-0.2, 1.55, -2.1) * tall
		_camera.look_at(subject + Vector3(0, 1.3 * tall, 0), Vector3.UP)
		await _snap("voxel_compare_close_%s.png" % FIGHTERS[i])
	_frame_camera()
	_view = "Front"
	_variant = ""
	_build_avatars()
	await _snap("voxel_compare_with_current.png")


## Five poses, each from its own angle, without the labels.
func _capture_poses() -> void:
	for label in _labels:
		label.visible = false
	var subject: Vector3 = _avatars[0].position
	for i in POSE_SHOTS.size():
		var shot: Array = POSE_SHOTS[i]
		_view = "Front"
		_yaw = shot[2]
		_set_pose(shot[0])
		for avatar in _avatars:
			avatar._action_time = avatar._action_duration * float(shot[1])
			avatar._apply_pose()
		# Pulled back to fit the whole lineup.
		_camera.position = subject + (shot[3] as Vector3) * 1.7
		_camera.look_at(subject + Vector3(0, shot[4], 0), Vector3.UP)
		await _snap("pose_%d_%s.png" % [i + 1, shot[0]])
	_frame_camera()


## Four shots in a 2x2 sheet at half size.
func _sheet(images: Array[Image], file: String) -> void:
	var w := images[0].get_width() / 2
	var h := images[0].get_height() / 2
	var sheet := Image.create(w * 2, h * 2, false, images[0].get_format())
	for i in images.size():
		var small := images[i].duplicate() as Image
		small.resize(w, h, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, w, h), Vector2i((i % 2) * w, (i / 2) * h))
	var path := ProjectSettings.globalize_path(OUT + file)
	sheet.save_png(path)
	print("VOXEL_COMPARE ", path)
