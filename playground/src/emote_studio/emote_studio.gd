extends Node3D
## Emote Studio (2026-10-30): where emotes are made and cleaned up. Your
## fighter in the middle, the dance's keys on a timeline, the source clip's
## frames beside him and its tracked skeleton over him.
##
## - Import a clip tracked in emote_lab (Emote Tracker.bat): it lands on the
##   rig (EmoteRetarget) as a new dance, already keyed.
## - Pick a joint (click it on the body, or the list), drag it on the body or
##   use the sliders: a limb points where you drag it, the rest turns. Editing
##   between keys makes a key there.
## - Save writes punch-craft/emotes/<id>.json, the file the game plays.
##
## Keys: Space play, K key the pose, Del delete key, , . previous / next key,
## Left / Right a frame, M mirror the pose, Ctrl+C / Ctrl+V copy / paste a
## pose, Ctrl+Z / Ctrl+Y undo / redo, Ctrl+S save. Right-drag orbits, the
## wheel zooms.
##
## Shots for review: -- --shot --emote=<id> [--times=0,0.25] [--import=<file>]
## [--save] [--fighter=<id>] [--clean [--yaw=0]] saves PNGs in user://emote_studio/ and quits;
## -- --render --emote=<id> [--seconds=3] writes a frame per 1/30s (a test clip);
## -- --selftest [--emotes=a,b] checks the import round trip on game dances.

const FIGHTERS := ["counter_master", "berserker", "combo_master", "free_runner", "elementalist", "wise_guy"]
const FIGHTER_NAMES := {"berserker": "The Mauler", "counter_master": "The Answer", "combo_master": "The Blur",
	"free_runner": "The Stray", "elementalist": "The Catalyst", "wise_guy": "Tony"}
## The joint list, in groups.
const GROUPS := [
	["Body", ["pos", "hips", "torso", "chest", "neck", "head"]],
	["Left arm", ["ls", "le"]], ["Right arm", ["rs", "re"]],
	["Left leg", ["lh", "lk", "lf"]], ["Right leg", ["rh", "rk", "rf"]],
]
const JOINT_NAMES := {"pos": "Hips (move)", "hips": "Hips (turn)", "torso": "Waist", "chest": "Chest", "neck": "Neck",
	"head": "Head", "ls": "L shoulder", "le": "L elbow", "rs": "R shoulder", "re": "R elbow", "lh": "L hip",
	"lk": "L knee", "lf": "L ankle", "rh": "R hip", "rk": "R knee", "rf": "R ankle"}
## Limbs aimed by dragging (their bone points at the mouse), and hinges.
const AIMED := ["ls", "rs", "lh", "rh"]
const HINGES := ["le", "re", "lk", "rk"]
const FPS := 30.0
const OUT := "user://emote_studio/"
const PANEL_W := 300.0
const TIMELINE_H := 170.0
const GOLD := Color(0.95, 0.76, 0.3)

var _repo := ""
var _id := ""
var _data := {}
var _clip := {}
var _time := 0.0
var _playing := false
var _speed := 1.0
var _joint := "ls"
var _fighter := "counter_master"
var _undo: Array = []
var _redo: Array = []
var _dirty := false
var _clipboard := {}
## The source clip: its track, its joints per frame (ghost), its reference strip.
var _track := {}
var _ghost_frames: Array = []
var _ghost_scale := 1.0
var _sheet: Texture2D
var _show_ghost := true
var _show_ref := true

var _body: FighterBody
var _camera: Camera3D
var _yaw := 0.0
var _pitch := -0.08
var _distance := 5.8
var _orbiting := false
var _dragging_joint := false
var _drag_offset := Vector3.ZERO

var _ui: Control
var _emote_pick: OptionButton
var _name_edit: LineEdit
var _length_spin: SpinBox
var _loop_check: CheckBox
var _loop_start_spin: SpinBox
var _plant_check: CheckBox
var _bpm_spin: SpinBox
var _source_pick: OptionButton
var _import_mirror: CheckBox
var _import_smooth: HSlider
var _import_detail: HSlider
var _import_travel: CheckBox
var _import_depth: HSlider
var _import_square: CheckBox
var _import_legs: HSlider
var _joint_buttons := {}
var _joint_title: Label
var _sliders: Array = []
var _slider_labels: Array = []
var _ease_pick: OptionButton
var _status: Label
var _time_label: Label
var _play_button: Button
var _timeline: Timeline
var _ref_rect: TextureRect
var _ref_atlas: AtlasTexture
var _ghost_mesh: ImmediateMesh
var _marker: MeshInstance3D
var _syncing := false


func _ready() -> void:
	_repo = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	if not DirAccess.dir_exists_absolute(_game_dir()):
		# Run from the game project itself (not the playground's copy).
		_repo = ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	_stage()
	_build_ui()
	_set_fighter(_arg("fighter", _fighter))
	_refresh_emote_list()
	var first := _arg("emote", "default")
	_load_emote(first if FileAccess.file_exists(_game_dir().path_join(first + ".json")) else "default")
	if _arg("import", "") != "":
		# Import options for a headless run (the panel's own defaults otherwise).
		_import_square.button_pressed = _arg("square", "1") == "1"
		_import_smooth.value = float(_arg("smooth", str(_import_smooth.value)))
		_import_detail.value = float(_arg("detail", str(_import_detail.value)))
		_import(_arg("import", ""))
		if "--save" in OS.get_cmdline_user_args():
			_save()
	var args := OS.get_cmdline_user_args()
	if "--shot" in args:
		await _shots()
		get_tree().quit()
	elif "--render" in args:
		await _render_clip()
		get_tree().quit()
	elif "--selftest" in args:
		var ok := true
		for id in _arg("emotes", "floss,default,dab,running_man,boo_yah").split(","):
			ok = load("res://playground/emote_studio/emote_retarget_test.gd").run(_body, id) and ok
		print("RETARGET ROUND TRIP: ", "PASS" if ok else "FAIL")
		get_tree().quit()


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.split("=", true, 1)[1]
	return fallback


func _game_dir() -> String:
	return _repo.path_join("punch-craft/emotes")


func _sources_dir() -> String:
	return _repo.path_join("emote_lab/sources")


# --- The stage ---------------------------------------------------------------------------

func _stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.12, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	for spec in [[Vector3(-40, 160, 0), Color(1.0, 0.95, 0.88), 1.4, true], [Vector3(-15, -150, 0), Color(0.78, 0.86, 1.0), 0.55, false],
			[Vector3(-20, -10, 0), Color(0.75, 0.85, 1.0), 0.6, false]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		light.shadow_enabled = spec[3]
		light.light_cull_mask = 0xFFFFF
		add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.27, 0.27, 0.31)
	material.roughness = 1.0
	plane.material = material
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	# Floor lines every half meter, so travel and height read.
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-6, 7):
		grid.surface_add_vertex(Vector3(i * 0.5, 0.002, -3))
		grid.surface_add_vertex(Vector3(i * 0.5, 0.002, 3))
		grid.surface_add_vertex(Vector3(-3, 0.002, i * 0.5))
		grid.surface_add_vertex(Vector3(3, 0.002, i * 0.5))
	grid.surface_end()
	var grid_node := MeshInstance3D.new()
	grid_node.mesh = grid
	grid_node.material_override = _unshaded(Color(0.4, 0.4, 0.46))
	add_child(grid_node)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	_camera.cull_mask = 0xFFFFF
	add_child(_camera)
	_camera.make_current()
	_place_camera()
	_ghost_mesh = ImmediateMesh.new()
	var ghost := MeshInstance3D.new()
	ghost.mesh = _ghost_mesh
	var ghost_material := _unshaded(Color(0.35, 0.9, 1.0))
	ghost_material.no_depth_test = true
	ghost_material.vertex_color_use_as_albedo = true
	ghost.material_override = ghost_material
	add_child(ghost)
	_marker = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	_marker.mesh = ball
	var marker_material := _unshaded(GOLD)
	marker_material.no_depth_test = true
	_marker.material_override = marker_material
	add_child(_marker)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _place_camera() -> void:
	var target := Vector3(0, 0.95, 0)
	var dir := Vector3(sin(_yaw) * cos(_pitch), sin(-_pitch), -cos(_yaw) * cos(_pitch))
	_camera.position = target + dir * _distance
	_camera.look_at(target, Vector3.UP)
	# Shift the view so the fighter sits in the middle of the free space
	# (between the side panels, above the timeline).
	_camera.h_offset = 0.0
	_camera.v_offset = -0.42


func _set_fighter(id: String) -> void:
	_fighter = id if id in FIGHTERS else "counter_master"
	if _body:
		_body.queue_free()
	_body = FighterBody.new(_fighter, "")
	add_child(_body)
	_body.finish_build()
	_ghost_scale = 1.0
	if not _track.is_empty():
		_fit_ghost()


# --- The dance ---------------------------------------------------------------------------

func _refresh_emote_list() -> void:
	_emote_pick.clear()
	var ids: Array = []
	for file in DirAccess.get_files_at(_game_dir()):
		if file.ends_with(".json"):
			ids.append(file.get_basename())
	ids.sort()
	for id in ids:
		_emote_pick.add_item(id)
	_select_in(_emote_pick, _id)


func _select_in(options: OptionButton, text: String) -> void:
	for i in options.item_count:
		if options.get_item_text(i) == text:
			options.select(i)
			return


func _load_emote(id: String) -> void:
	var path := _game_dir().path_join(id + ".json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_id = id
	_data = data if data is Dictionary else {"name": id.capitalize(), "length": 2.0, "loop": true, "plant": true, "keys": []}
	_undo.clear()
	_redo.clear()
	_dirty = false
	_time = 0.0
	_track = {}
	_ghost_frames = []
	_sheet = null
	if _data.has("source"):
		_load_source(String(_data.source))
	_changed(false)
	_select_in(_emote_pick, id)
	_say("Opened %s." % id)


## Call after any change to the dance: rebuilds what plays, refreshes the panels.
func _changed(edited := true) -> void:
	_data["keys"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	_clip = Emotes.parse(_data)
	if edited:
		_dirty = true
	_syncing = true
	_name_edit.text = String(_data.get("name", ""))
	_length_spin.value = float(_data.length)
	_loop_check.button_pressed = bool(_data.get("loop", true))
	_loop_start_spin.value = float(_data.get("loop_start", 0.0))
	_plant_check.button_pressed = bool(_data.get("plant", true))
	_bpm_spin.value = float(_data.get("bpm", 0.0))
	_syncing = false
	_sync_joint_panel()
	_timeline.queue_redraw()


func _remember() -> void:
	_undo.append(JSON.stringify(_data))
	if _undo.size() > 200:
		_undo.pop_front()
	_redo.clear()


func _undo_step(back: bool) -> void:
	var from: Array = _undo if back else _redo
	var to: Array = _redo if back else _undo
	if from.is_empty():
		return
	to.append(JSON.stringify(_data))
	_data = JSON.parse_string(from.pop_back())
	_changed()


func _save() -> void:
	# A key at the very end would sit on the loop's first key (2026-10-30: the
	# Dab and Nae Nae closed their loops with a copy of it); the end flows into
	# the first key by itself.
	var length := float(_data.length)
	_data["keys"] = _data["keys"].filter(func(key: Dictionary) -> bool: return float(key.t) < length - 0.0005)
	var text := _serialize(_data)
	for dir in [_game_dir(), ProjectSettings.globalize_path("res://emotes")]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var file := FileAccess.open(dir.path_join(_id + ".json"), FileAccess.WRITE)
		if file:
			file.store_string(text)
	Emotes.reload()
	_dirty = false
	_refresh_emote_list()
	_say("Saved punch-craft/emotes/%s.json" % _id)


## The file as the game keeps it: a line per key, degrees to a tenth.
static func _serialize(data: Dictionary) -> String:
	var lines: Array = ["{"]
	for field in data:
		if field != "keys":
			lines.append("\t%s: %s," % [JSON.stringify(field), JSON.stringify(data[field])])
	lines.append("\t\"keys\": [")
	var keys: Array = []
	for key: Dictionary in data["keys"]:
		var parts: Array = ["\"t\": " + _num(float(key.t))]
		if String(key.get("ease", "smooth")) != "smooth":
			parts.append("\"ease\": " + JSON.stringify(key.ease))
		var joints: Array = []
		for joint in Emotes.JOINTS + ["pos"] + Emotes.HANDS:
			if key.pose.has(joint):
				var v: Array = key.pose[joint]
				joints.append("\"%s\": [%s]" % [joint, ", ".join(v.map(func(n: Variant) -> String: return _num(float(n))))])
		parts.append("\"pose\": {" + ", ".join(joints) + "}")
		keys.append("\t\t{" + ", ".join(parts) + "}")
	lines.append(",\n".join(keys))
	lines.append("\t]")
	lines.append("}")
	return "\n".join(lines) + "\n"


static func _num(x: float) -> String:
	x = snappedf(x, 0.001)
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(x)


func _key_at(t: float) -> int:
	for i in _data["keys"].size():
		if absf(float(_data["keys"][i].t) - t) < 0.5 / FPS:
			return i
	return -1


## The dance's pose at a time, as the file writes it (degrees, cm).
func _file_pose(t: float) -> Dictionary:
	var pose := {}
	var sampled := Emotes.sample(_clip, t) if not _clip.is_empty() else {}
	for joint: String in sampled:
		if joint.ends_with("_w"):
			continue
		if joint in Emotes.HANDS:
			var v: Vector3 = sampled[joint] * 100.0
			pose[joint] = [snappedf(v.x, 1.0), snappedf(v.y, 1.0), snappedf(v.z, 1.0), snappedf(sampled.get(joint + "_w", Vector3.ONE).x * 100.0, 1.0)]
			continue
		pose[joint] = _to_file(joint, sampled[joint])
	return pose


static func _to_file(joint: String, v: Vector3) -> Array:
	v = v * 100.0 if joint == "pos" else v * (180.0 / PI)
	return [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]


static func _from_file(joint: String, a: Array) -> Vector3:
	var v := Vector3(a[0], a[1], a[2])
	return v / 100.0 if joint == "pos" else v * (PI / 180.0)


## The key at the playhead, made (holding the pose there) if there's none.
func _key_here() -> Dictionary:
	var i := _key_at(_time)
	if i >= 0:
		return _data["keys"][i]
	var t := _snap(_time)
	var key := {"t": t, "pose": _file_pose(t)}
	_data["keys"].append(key)
	_time = t
	return key


func _snap(t: float) -> float:
	var bpm := float(_data.get("bpm", 0.0))
	var step := 60.0 / bpm / 4.0 if bpm > 0.0 else 1.0 / FPS
	return clampf(snappedf(t, step), 0.0, float(_data.length) - 1.0 / FPS)


## Sets a joint at the playhead (radians / meters), keying it.
func _set_joint_value(joint: String, value: Vector3) -> void:
	var key := _key_here()
	key.pose[joint] = _to_file(joint, value)
	_changed()


func _joint_value(joint: String) -> Vector3:
	var sampled := Emotes.sample(_clip, _time) if not _clip.is_empty() else {}
	return sampled.get(joint, Emotes.REST.get(joint, Vector3.ZERO))


# --- Every frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _playing:
		_time += delta * _speed
		var length := float(_data.length)
		if _time >= length:
			_time = fmod(_time, length) if _data.get("loop", true) else length
			if not _data.get("loop", true):
				_playing = false
	_pose_body()
	_draw_ghost()
	_show_reference()
	_place_marker()
	_time_label.text = "%.2fs / %.2fs%s" % [_time, float(_data.length), "  (unsaved)" if _dirty else ""]
	_play_button.text = "Pause" if _playing else "Play"
	_timeline.queue_redraw()
	if _playing and not _dragging_joint:
		_sync_joint_panel()


func _pose_body() -> void:
	if not _body:
		return
	var pose := Emotes.sample(_clip, _time) if not _clip.is_empty() else {}
	_body._apply(pose, bool(_data.get("plant", true)))


func _place_marker() -> void:
	var node := _joint_node(_joint)
	_marker.visible = node != null
	if node:
		_marker.global_position = node.global_position


func _joint_node(joint: String) -> Node3D:
	if not _body:
		return null
	return _body._joints.get("hips" if joint == "pos" else joint)


# --- The source clip ---------------------------------------------------------------------

func _source_files() -> Array:
	var out: Array = []
	if DirAccess.dir_exists_absolute(_sources_dir()):
		for file in DirAccess.get_files_at(_sources_dir()):
			if file.ends_with(".track.json"):
				out.append(file)
	out.sort()
	return out


func _load_source(file: String) -> bool:
	var path := _sources_dir().path_join(file)
	if not FileAccess.file_exists(path):
		_say("Source %s isn't in emote_lab/sources." % file)
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return false
	_track = data
	_sheet = null
	var sheet: Variant = _track.get("sheet")
	if sheet is Dictionary:
		var image := Image.new()
		if image.load_jpg_from_buffer(Marshalls.base64_to_raw(sheet.jpg)) == OK:
			_sheet = ImageTexture.create_from_image(image)
	_ghost_frames = EmoteRetarget.landmark_frames(_track, 1.0, _import_depth.value if _import_depth else EmoteRetarget.DEPTH,
			_import_square.button_pressed if _import_square else true)
	_fit_ghost()
	return true


func _fit_ghost() -> void:
	var tracked := 0.0
	for joints: Array in _ghost_frames:
		for side in 2:
			tracked += (joints[EmoteRetarget.HIP[side]] - joints[EmoteRetarget.KNEE[side]]).length() \
					+ (joints[EmoteRetarget.KNEE[side]] - joints[EmoteRetarget.ANKLE[side]]).length()
	tracked /= maxf(_ghost_frames.size() * 2.0, 1.0)
	_ghost_scale = EmoteRetarget.RIG_LEG / maxf(tracked, 0.1)


## The source clip's time for the dance's time (the dance may be retimed).
func _source_time() -> float:
	var ref: Dictionary = _data.get("ref", {})
	return (_time - float(ref.get("offset", 0.0))) * float(ref.get("speed", 1.0))


func _show_reference() -> void:
	var sheet: Variant = _track.get("sheet")
	_ref_rect.visible = _show_ref and _sheet != null and sheet is Dictionary
	if not _ref_rect.visible:
		return
	var times: Array = sheet.times
	var t := _source_time()
	var index := 0
	for i in times.size():
		if float(times[i]) <= t + 0.001:
			index = i
	_ref_atlas.atlas = _sheet
	_ref_atlas.region = Rect2((index % int(sheet.cols)) * float(sheet.w), (index / int(sheet.cols)) * float(sheet.h), float(sheet.w), float(sheet.h))


## The tracked skeleton at this time, over the fighter (hips on his hips).
func _draw_ghost() -> void:
	_ghost_mesh.clear_surfaces()
	if not _show_ghost or _ghost_frames.is_empty() or not _body:
		return
	var frames: Array = _track.frames
	var t := _source_time()
	var index := 0
	for i in frames.size():
		if float(frames[i].t) - float(frames[0].t) <= t + 0.001:
			index = i
	var joints: Array = _ghost_frames[index]
	var hips: Vector3 = (joints[EmoteRetarget.HIP[0]] + joints[EmoteRetarget.HIP[1]]) * 0.5
	var anchor: Vector3 = _body._joints.hips.global_position
	var scale := _ghost_scale * _body.scale.x
	var bones := [[11, 12], [11, 13], [13, 15], [12, 14], [14, 16], [11, 23], [12, 24], [23, 24], [23, 25], [25, 27],
			[24, 26], [26, 28], [27, 29], [29, 31], [27, 31], [28, 30], [30, 32], [28, 32], [7, 8], [0, 7], [0, 8]]
	_ghost_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for bone in bones:
		var left: bool = bone[0] % 2 == 1 and bone[1] % 2 == 1
		_ghost_mesh.surface_set_color(Color(0.35, 0.9, 1.0) if left else Color(1.0, 0.55, 0.3))
		_ghost_mesh.surface_add_vertex(anchor + (joints[bone[0]] - hips) * scale)
		_ghost_mesh.surface_add_vertex(anchor + (joints[bone[1]] - hips) * scale)
	_ghost_mesh.surface_end()


func _import(file: String) -> void:
	if not _load_source(file):
		return
	if _source_pick:
		_select_in(_source_pick, file)
	var track := _track.duplicate()
	if _import_mirror and _import_mirror.button_pressed != bool(_track.get("mirror", false)):
		track.mirror = _import_mirror.button_pressed
	var options := {
		"smooth": _import_smooth.value if _import_smooth else 1.5,
		"tolerance": _import_detail.value if _import_detail else 6.0,
		"travel": _import_travel.button_pressed if _import_travel else false,
		"legs": _import_legs.value if _import_legs else EmoteRetarget.LEG_GAIN,
		"depth": _import_depth.value if _import_depth else EmoteRetarget.DEPTH,
		"square": _import_square.button_pressed if _import_square else true,
	}
	var data := EmoteRetarget.to_emote(track, _body, options)
	if data.is_empty():
		_say("Nothing tracked in %s." % file)
		return
	if not _data.is_empty() and _id == String(_track.get("id", "")):
		_remember()
	_id = String(_track.get("id", file.get_basename().get_basename()))
	_data = data
	_time = 0.0
	_changed()
	_say("Imported %s: %d keys over %.2fs. Save to keep it." % [file, data["keys"].size(), float(data.length)])


# --- Input -------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_distance = maxf(_distance - 0.25, 1.5)
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_distance = minf(_distance + 0.25, 9.0)
			_place_camera()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var picked := _pick_joint(mb.position)
				if picked != "":
					_select_joint(picked)
					_dragging_joint = true
					_playing = false
					_remember()
			else:
				_dragging_joint = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbiting:
			_yaw -= mm.relative.x * 0.008
			_pitch = clampf(_pitch + mm.relative.y * 0.006, -1.2, 0.5)
			_place_camera()
		elif _dragging_joint:
			_drag_joint(mm)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _key(event: InputEventKey) -> void:
	var ctrl := event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_SPACE:
			_playing = not _playing
		KEY_K:
			_remember()
			var key := _key_here()
			key.pose = _file_pose(float(key.t))
			_changed()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_key()
		KEY_COMMA:
			_step_key(-1)
		KEY_PERIOD:
			_step_key(1)
		KEY_LEFT:
			_playing = false
			_time = clampf(_time - 1.0 / FPS, 0.0, float(_data.length))
			_sync_joint_panel()
		KEY_RIGHT:
			_playing = false
			_time = clampf(_time + 1.0 / FPS, 0.0, float(_data.length))
			_sync_joint_panel()
		KEY_M:
			_mirror_pose()
		KEY_C:
			if ctrl:
				_clipboard = _file_pose(_time)
				_say("Copied the pose at %.2fs." % _time)
		KEY_V:
			if ctrl and not _clipboard.is_empty():
				_remember()
				_key_here().pose = _clipboard.duplicate(true)
				_changed()
		KEY_Z:
			if ctrl:
				_undo_step(not event.shift_pressed)
		KEY_Y:
			if ctrl:
				_undo_step(false)
		KEY_S:
			if ctrl:
				_save()
		_:
			return
	get_viewport().set_input_as_handled()


## The joint nearest the click on screen (within 40 px), "" for none.
func _pick_joint(at: Vector2) -> String:
	var best := ""
	var best_d := 40.0
	for joint in Emotes.JOINTS:
		var node := _joint_node(joint)
		if not node or _camera.is_position_behind(node.global_position):
			continue
		var d := _camera.unproject_position(node.global_position).distance_to(at)
		if d < best_d:
			best_d = d
			best = joint
	return best


## Dragging the picked joint: a limb points its bone at the mouse, a hinge
## bends toward it, the hips move with it, anything else turns (left-right
## turns it, up-down tips it; Shift: left-right tilts it).
func _drag_joint(event: InputEventMouseMotion) -> void:
	var node := _joint_node(_joint)
	if not node:
		return
	var value := _joint_value(_joint)
	# What the body adds on top of the dance's value (planted legs, level feet).
	var offset := (node.rotation if _joint != "pos" else Vector3.ZERO) - value
	if _joint == "pos":
		var per_pixel := _distance * 0.0012 / _body.scale.x
		var right := _camera.global_basis.x
		var move := (right * event.relative.x - Vector3.UP * event.relative.y) * per_pixel
		_set_joint_value("pos", value + Vector3(move.x, move.y, move.z))
		return
	if _joint in AIMED or _joint in HINGES:
		var plane := Plane(-_camera.global_basis.z, node.global_position)
		var mouse := get_viewport().get_mouse_position()
		var hit: Variant = plane.intersects_ray(_camera.project_ray_origin(mouse), _camera.project_ray_normal(mouse))
		if hit == null:
			return
		var parent_basis := (node.get_parent() as Node3D).global_basis.orthonormalized()
		var want := (parent_basis.inverse() * ((hit as Vector3) - node.global_position)).normalized()
		var rotation := node.rotation
		if _joint in AIMED:
			var current := (Basis.from_euler(rotation) * Vector3.DOWN).normalized()
			var turn := Quaternion(current, want) if current.dot(want) > -0.999 else Quaternion(Vector3.RIGHT, PI)
			rotation = (Basis(turn) * Basis.from_euler(rotation)).get_euler()
		else:
			# The hinge's own frame: the parent bone's.
			var local := Basis.from_euler(Vector3(0, rotation.y, rotation.z)).inverse() * want
			var bend := atan2(-local.z, -local.y)
			rotation.x = clampf(bend, 0.0, 2.7) if _joint in ["le", "re"] else clampf(bend, -2.7, 0.0)
		_set_joint_value(_joint, rotation - offset)
	else:
		var turn := Vector3(event.relative.y * 0.01, event.relative.x * 0.01, 0)
		if event.shift_pressed:
			turn = Vector3(0, 0, -event.relative.x * 0.01)
		_set_joint_value(_joint, value + turn)
	_sync_joint_panel()


func _select_joint(joint: String) -> void:
	_joint = joint
	for j in _joint_buttons:
		(_joint_buttons[j] as Button).button_pressed = j == joint
	_sync_joint_panel()


func _step_key(direction: int) -> void:
	_playing = false
	var times: Array = _data["keys"].map(func(k: Dictionary) -> float: return float(k.t))
	if times.is_empty():
		return
	var pick: float = times[0] if direction > 0 else times[-1]
	if direction > 0:
		for t in times:
			if t > _time + 0.001:
				pick = t
				break
	else:
		for i in range(times.size() - 1, -1, -1):
			if times[i] < _time - 0.001:
				pick = times[i]
				break
	_time = pick
	_sync_joint_panel()


func _delete_key() -> void:
	var i := _key_at(_time)
	if i < 0:
		return
	_remember()
	_data["keys"].remove_at(i)
	_changed()


func _mirror_pose() -> void:
	_remember()
	var key := _key_here()
	key.pose = _mirror_file_pose(key.pose)
	_changed()


func _mirror_dance() -> void:
	_remember()
	for key: Dictionary in _data["keys"]:
		key.pose = _mirror_file_pose(key.pose)
	_changed()


## A key's pose (as the file writes it) left to right.
static func _mirror_file_pose(pose: Dictionary) -> Dictionary:
	var out := {}
	for joint: String in pose:
		var a: Array = pose[joint]
		var other := joint
		if joint[0] in ["l", "r"] and (joint.length() == 2 or joint in Emotes.HANDS):
			other = ("r" if joint[0] == "l" else "l") + joint.substr(1)
		if joint == "pos" or joint in Emotes.HANDS:
			var flipped := a.duplicate()
			flipped[0] = -float(a[0])
			out[other] = flipped
		else:
			out[other] = [a[0], -float(a[1]), -float(a[2])]
	return out


## Changes the dance's length; stretch: the keys (and the source clip) move
## with it, so the whole dance plays faster or slower.
func _set_length(length: float, stretch: bool) -> void:
	_remember()
	var old := float(_data.length)
	length = maxf(length, 0.1)
	if stretch and old > 0.0:
		var k := length / old
		for key: Dictionary in _data["keys"]:
			key.t = snappedf(float(key.t) * k, 0.001)
		_data.loop_start = snappedf(float(_data.get("loop_start", 0.0)) * k, 0.001)
		var ref: Dictionary = _data.get("ref", {"offset": 0.0, "speed": 1.0})
		ref.speed = float(ref.get("speed", 1.0)) / k
		ref.offset = float(ref.get("offset", 0.0)) * k
		_data.ref = ref
		_time *= k
	else:
		_data["keys"] = _data["keys"].filter(func(key: Dictionary) -> bool: return float(key.t) < length)
	_data.length = snappedf(length, 0.001)
	_changed()


# --- The panels --------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_ui.add_child(_left_panel())
	_ui.add_child(_right_panel())
	_ui.add_child(_bottom_panel())
	_ref_atlas = AtlasTexture.new()
	_ref_rect = TextureRect.new()
	_ref_rect.texture = _ref_atlas
	_ref_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ref_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ref_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ref_rect.anchor_left = 1.0
	_ref_rect.anchor_right = 1.0
	_ref_rect.offset_left = -PANEL_W - 250
	_ref_rect.offset_right = -PANEL_W - 12
	_ref_rect.offset_top = 12
	_ref_rect.offset_bottom = 330
	_ui.add_child(_ref_rect)


func _panel(left: bool) -> VBoxContainer:
	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.11, 0.92)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bg.add_theme_stylebox_override("panel", style)
	bg.anchor_left = 0.0 if left else 1.0
	bg.anchor_right = 0.0 if left else 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0.0 if left else -PANEL_W
	bg.offset_right = PANEL_W if left else 0.0
	bg.offset_bottom = -TIMELINE_H
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bg.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)
	box.set_meta("root", bg)
	return box


func _left_panel() -> Control:
	var box := _panel(true)
	box.add_child(_title("EMOTE STUDIO"))
	box.add_child(_button("Back to the playground", func() -> void:
		get_tree().change_scene_to_file("res://playground/playground.tscn")))
	box.add_child(_title("DANCE"))
	_emote_pick = OptionButton.new()
	_emote_pick.item_selected.connect(func(i: int) -> void: _load_emote(_emote_pick.get_item_text(i)))
	box.add_child(_emote_pick)
	_name_edit = _line("Name", func(text: String) -> void:
		_remember()
		_data.name = text
		_changed())
	box.add_child(_name_edit.get_parent())
	var row := HBoxContainer.new()
	row.add_child(_button("Save", _save))
	row.add_child(_button("Revert", func() -> void: _load_emote(_id)))
	row.add_child(_button("New", _new_dance))
	box.add_child(row)
	_length_spin = _spin("Length (s)", 0.1, 30.0, 0.01, func(v: float) -> void: _set_length(v, false))
	box.add_child(_length_spin.get_parent())
	var stretch := HBoxContainer.new()
	stretch.add_child(_button("Faster", func() -> void: _set_length(float(_data.length) * 0.9, true)))
	stretch.add_child(_button("Slower", func() -> void: _set_length(float(_data.length) / 0.9, true)))
	box.add_child(stretch)
	_loop_check = _check("Loop", func(on: bool) -> void:
		_remember()
		_data.loop = on
		_changed())
	box.add_child(_loop_check)
	_loop_start_spin = _spin("Intro before the loop (s)", 0.0, 30.0, 0.01, func(v: float) -> void:
		_remember()
		_data.loop_start = v
		_changed())
	box.add_child(_loop_start_spin.get_parent())
	_plant_check = _check("Feet planted (hips drop on bent knees)", func(on: bool) -> void:
		_remember()
		_data.plant = on
		_changed())
	box.add_child(_plant_check)
	_bpm_spin = _spin("Beat grid (BPM, 0 off)", 0.0, 240.0, 1.0, func(v: float) -> void:
		_data.bpm = v
		_timeline.queue_redraw())
	box.add_child(_bpm_spin.get_parent())
	box.add_child(_button("Mirror the whole dance", _mirror_dance))

	box.add_child(_title("IMPORT A TRACKED CLIP"))
	box.add_child(_note("Track a clip in emote_lab (Emote Tracker.bat), save it in emote_lab/sources/."))
	_source_pick = OptionButton.new()
	box.add_child(_source_pick)
	box.add_child(_button("Refresh list", _refresh_sources))
	_import_mirror = _check("Mirrored (selfie) clip", func(_on: bool) -> void: pass)
	box.add_child(_import_mirror)
	_import_travel = _check("Keep travel across the floor", func(_on: bool) -> void: pass)
	_import_travel.button_pressed = false
	box.add_child(_import_travel)
	_import_square = _check("Square to the camera (takes out its angle)", func(_on: bool) -> void: pass)
	_import_square.button_pressed = true
	box.add_child(_import_square)
	_import_depth = _hslider("Depth trust (the tracker's shaky axis)", 0.0, 1.0, 0.05, EmoteRetarget.DEPTH)
	box.add_child(_import_depth.get_parent())
	_import_legs = _hslider("Leg moves bigger by", 1.0, 2.5, 0.1, EmoteRetarget.LEG_GAIN)
	box.add_child(_import_legs.get_parent())
	_import_smooth = _hslider("Smoothing", 0.0, 4.0, 0.25, 1.5)
	box.add_child(_import_smooth.get_parent())
	_import_detail = _hslider("Fewer keys (degrees off allowed)", 1.0, 20.0, 0.5, 6.0)
	box.add_child(_import_detail.get_parent())
	box.add_child(_button("Import as a new dance", func() -> void:
		if _source_pick.item_count > 0:
			_import(_source_pick.get_item_text(_source_pick.selected))))
	_refresh_sources()

	box.add_child(_title("VIEW"))
	var fighter := OptionButton.new()
	for id in FIGHTERS:
		fighter.add_item(FIGHTER_NAMES[id])
	fighter.item_selected.connect(func(i: int) -> void: _set_fighter(FIGHTERS[i]))
	box.add_child(fighter)
	var views := HBoxContainer.new()
	for v in [["Front", 0.0], ["3/4", -0.7], ["Side", -PI / 2.0], ["Back", PI]]:
		var yaw: float = v[1]
		views.add_child(_button(v[0], func() -> void:
			_yaw = yaw
			_place_camera()))
	box.add_child(views)
	var ghost := _check("Tracked skeleton", func(on: bool) -> void: _show_ghost = on)
	ghost.button_pressed = true
	box.add_child(ghost)
	var ref := _check("Source frames", func(on: bool) -> void: _show_ref = on)
	ref.button_pressed = true
	box.add_child(ref)
	_status = _note("")
	_status.add_theme_color_override("font_color", GOLD)
	box.add_child(_status)
	return box.get_meta("root")


func _refresh_sources() -> void:
	_source_pick.clear()
	for file in _source_files():
		_source_pick.add_item(file)
	if _source_pick.item_count == 0:
		_source_pick.add_item("(none in emote_lab/sources)")
		_source_pick.disabled = true
	else:
		_source_pick.disabled = false


func _new_dance() -> void:
	var n := 1
	while FileAccess.file_exists(_game_dir().path_join("new_%d.json" % n)):
		n += 1
	_id = "new_%d" % n
	_data = {"name": "New Dance", "length": 2.0, "loop": true, "plant": true, "keys": [{"t": 0, "pose": {}}]}
	_track = {}
	_ghost_frames = []
	_sheet = null
	_undo.clear()
	_time = 0.0
	_changed()
	_say("New dance %s (Save names the file)." % _id)


func _right_panel() -> Control:
	var box := _panel(false)
	box.add_child(_title("JOINT"))
	for group: Array in GROUPS:
		box.add_child(_note(group[0]))
		var grid := GridContainer.new()
		grid.columns = 3
		for joint: String in group[1]:
			var b := Button.new()
			b.text = JOINT_NAMES[joint]
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 12)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void: _select_joint(joint))
			_joint_buttons[joint] = b
			grid.add_child(b)
		box.add_child(grid)
	_joint_title = _title("")
	box.add_child(_joint_title)
	for axis in ["X (tip)", "Y (turn)", "Z (tilt)"]:
		var c := _sliders.size()
		var row := VBoxContainer.new()
		var label := _note(axis)
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = -180
		slider.max_value = 180
		slider.step = 0.5
		slider.focus_mode = Control.FOCUS_NONE
		slider.drag_started.connect(_remember)
		slider.value_changed.connect(func(v: float) -> void:
			if _syncing:
				return
			var value := _joint_value(_joint)
			value[c] = v / 100.0 if _joint == "pos" else deg_to_rad(v)
			_set_joint_value(_joint, value))
		row.add_child(slider)
		_sliders.append(slider)
		_slider_labels.append(label)
		box.add_child(row)
	box.add_child(_button("Reset this joint", func() -> void:
		_remember()
		_set_joint_value(_joint, Emotes.REST.get(_joint, Vector3.ZERO))))
	box.add_child(_title("KEY"))
	box.add_child(_note("Move out of this key:"))
	_ease_pick = OptionButton.new()
	for ease in Emotes.EASES:
		_ease_pick.add_item(ease)
	_ease_pick.item_selected.connect(func(i: int) -> void:
		var k := _key_at(_time)
		if k < 0:
			return
		_remember()
		if i == 0:
			_data["keys"][k].erase("ease")
		else:
			_data["keys"][k].ease = Emotes.EASES[i]
		_changed())
	box.add_child(_ease_pick)
	box.add_child(_note("smooth flows through, ease stops on the key, snap pops fast then settles, hold jumps."))
	var row := HBoxContainer.new()
	row.add_child(_button("Key pose (K)", func() -> void:
		_remember()
		var key := _key_here()
		key.pose = _file_pose(float(key.t))
		_changed()))
	row.add_child(_button("Delete (Del)", _delete_key))
	box.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_child(_button("Copy", func() -> void: _clipboard = _file_pose(_time)))
	row2.add_child(_button("Paste", func() -> void:
		if _clipboard.is_empty():
			return
		_remember()
		_key_here().pose = _clipboard.duplicate(true)
		_changed()))
	row2.add_child(_button("Mirror (M)", _mirror_pose))
	box.add_child(row2)
	box.add_child(_note("Click a joint on the body to pick it; drag it to pose. Right-drag orbits, wheel zooms. Space plays, , . jump between keys, arrows step a frame."))
	return box.get_meta("root")


func _sync_joint_panel() -> void:
	if not _joint_title:
		return
	_joint_title.text = JOINT_NAMES.get(_joint, _joint).to_upper()
	var v := _joint_value(_joint)
	_syncing = true
	for c in 3:
		var slider: HSlider = _sliders[c]
		if _joint == "pos":
			slider.min_value = -80
			slider.max_value = 80
			slider.value = v[c] * 100.0
			_slider_labels[c].text = "%s  %.1f cm" % [["X (side)", "Y (up)", "Z (back)"][c], v[c] * 100.0]
		else:
			slider.min_value = -180
			slider.max_value = 180
			slider.value = rad_to_deg(v[c])
			_slider_labels[c].text = "%s  %.1f°" % [["X (tip)", "Y (turn)", "Z (tilt)"][c], rad_to_deg(v[c])]
	var k := _key_at(_time)
	_ease_pick.disabled = k < 0
	if k >= 0:
		_ease_pick.select(maxi(Emotes.EASES.find(String(_data["keys"][k].get("ease", "smooth"))), 0))
	_syncing = false


func _bottom_panel() -> Control:
	var bg := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.08, 0.96)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	bg.add_theme_stylebox_override("panel", style)
	bg.anchor_top = 1.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_top = -TIMELINE_H
	var box := VBoxContainer.new()
	bg.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_play_button = _button("Play", func() -> void: _playing = not _playing)
	row.add_child(_play_button)
	row.add_child(_button("|<", func() -> void:
		_time = 0.0
		_sync_joint_panel()))
	row.add_child(_button("< key", func() -> void: _step_key(-1)))
	row.add_child(_button("key >", func() -> void: _step_key(1)))
	var speed := OptionButton.new()
	for s in ["0.25x", "0.5x", "1x"]:
		speed.add_item(s)
	speed.select(2)
	speed.focus_mode = Control.FOCUS_NONE
	speed.item_selected.connect(func(i: int) -> void: _speed = [0.25, 0.5, 1.0][i])
	row.add_child(speed)
	_time_label = _note("", false)
	row.add_child(_time_label)
	for child in row.get_children():
		child.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if child is Button:
			child.custom_minimum_size.x = 64
	box.add_child(row)
	_timeline = Timeline.new()
	_timeline.studio = self
	_timeline.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_timeline.custom_minimum_size = Vector2(0, 110)
	box.add_child(_timeline)
	return bg


func _title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_font_size_override("font_size", 15)
	return label


func _note(text: String, wrap := true) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	return label


func _button(text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(pressed)
	return b


func _check(text: String, toggled: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			toggled.call(on))
	return c


func _spin(text: String, lo: float, hi: float, step: float, changed: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	var label := _note(text, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = lo
	spin.max_value = hi
	spin.step = step
	spin.custom_minimum_size.x = 90
	spin.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			changed.call(v))
	row.add_child(spin)
	return spin


func _line(text: String, submitted: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_child(_note(text, false))
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_submitted.connect(func(t: String) -> void:
		submitted.call(t)
		edit.release_focus())
	row.add_child(edit)
	return edit


func _hslider(text: String, lo: float, hi: float, step: float, value: float) -> HSlider:
	var row := VBoxContainer.new()
	var label := _note("%s: %s" % [text, value])
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(v: float) -> void: label.text = "%s: %s" % [text, v])
	row.add_child(slider)
	return slider


func _say(text: String) -> void:
	if _status:
		_status.text = text
	print("[Emote Studio] ", text)


# --- Shots -------------------------------------------------------------------------------

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var times := _arg("times", "0,0.25,0.5,0.75").split(",")
	# --print: the legs, frame by frame (checking an import).
	if "--print" in OS.get_cmdline_user_args():
		for i in int(float(_data.length) * 10.0):
			var pose := Emotes.sample(_clip, i / 10.0)
			var line := "%.1f" % (i / 10.0)
			for j in ["pos", "hips", "lh", "lk", "lf", "rh", "rk", "rf"]:
				var v: Vector3 = pose.get(j, Vector3.ZERO)
				line += "  %s %s" % [j, (v * 100.0).round() if j == "pos" else (v * 180.0 / PI).round()]
			print(line)
	# --glitch: the fastest joint turns (degrees per 1/60 s), where a swing
	# flips or pops.
	if "--glitch" in OS.get_cmdline_user_args():
		var speeds: Array = []
		var before := {}
		for i in int(float(_data.length) * 60.0):
			var pose := Emotes.sample(_clip, i / 60.0)
			for joint in pose:
				if joint == "pos":
					continue
				var q := Quaternion.from_euler(pose[joint])
				if before.has(joint):
					speeds.append([rad_to_deg((before[joint] as Quaternion).angle_to(q)), i / 60.0, joint])
				before[joint] = q
		speeds.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for k in 15:
			print("glitch %.1f deg at %.2fs %s" % speeds[k])
	# --reach: how far each fist on the face misses its spot (cm).
	if "--reach" in OS.get_cmdline_user_args():
		for i in int(float(_data.length) * 10.0):
			var pose := Emotes.sample(_clip, i / 10.0)
			_body._apply(pose, bool(_data.get("plant", true)))
			var line := "reach %.1f" % (i / 10.0)
			for s in ["l", "r"]:
				if not pose.has(s + "hand"):
					continue
				var head: Node3D = _body._joints.head
				var spot := head.global_transform * (Vector3(0, 0.2, 0) + (pose[s + "hand"] as Vector3) * _body._ear_width())
				var fist := (_body._joints[s + "e"] as Node3D).global_transform * Vector3(0, -_body._fist_reach(), 0)
				line += "  %s w %.2f miss %.1f" % [s, pose[s + "hand_w"].x, (spot - fist).length() * 100.0]
			print(line)
	# --clean: just the fighter (and the tracked skeleton), front on.
	if "--clean" in OS.get_cmdline_user_args():
		_ui.visible = false
		_show_ref = false
		_marker.visible = false
		_camera.v_offset = 0.0
		_yaw = float(_arg("yaw", "0"))
		_place_camera()
	for i in 10:
		await get_tree().process_frame
	for t in times:
		_time = float(t) * float(_data.length)
		_process(0.0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path := OUT + "%s_%s_%s.png" % [_id, _fighter, t]
		get_viewport().get_texture().get_image().save_png(path)
		print("shot ", ProjectSettings.globalize_path(path))


## A test clip: the dance, front on, no panels, a PNG per 1/30s.
func _render_clip() -> void:
	var dir := OUT + "render_" + _id + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_ui.visible = false
	_ref_rect.visible = false
	_show_ghost = false
	_marker.visible = false
	_camera.v_offset = 0.0
	set_process(false)
	for i in 10:
		await get_tree().process_frame
	var seconds := float(_arg("seconds", str(_data.length)))
	for i in int(seconds * FPS):
		_time = fmod(i / FPS, float(_data.length))
		_pose_body()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(dir + "f%04d.png" % i)
	print("rendered ", ProjectSettings.globalize_path(dir))


# --- The timeline ------------------------------------------------------------------------

## Time across, the keys as diamonds (gold: the one at the playhead; bright:
## keys that move the picked joint), the loop's intro, the beat grid. Click to
## scrub; drag a key to move it; drag the end to change the length.
class Timeline:
	extends Control
	var studio: Node
	var _drag := -1
	var _drag_end := false
	## The length when the end started moving (the scale stays put while dragging).
	var _end_from := 1.0
	const MARGIN := 14.0

	func _x(t: float) -> float:
		return MARGIN + t / float(studio._data.length) * (size.x - 2.0 * MARGIN)

	func _t(x: float) -> float:
		return clampf((x - MARGIN) / (size.x - 2.0 * MARGIN), 0.0, 1.0) * float(studio._data.length)

	func _draw() -> void:
		var data: Dictionary = studio._data
		if data.is_empty():
			return
		var length := float(data.length)
		var font := get_theme_default_font()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.09, 0.13))
		var loop_start := float(data.get("loop_start", 0.0))
		if loop_start > 0.0:
			draw_rect(Rect2(MARGIN, 0, _x(loop_start) - MARGIN, size.y), Color(0.3, 0.25, 0.1, 0.35))
			draw_string(font, Vector2(MARGIN + 4, size.y - 6), "intro", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.7, 0.4))
		var bpm := float(data.get("bpm", 0.0))
		if bpm > 0.0:
			var beat := 60.0 / bpm
			var n := 0
			while n * beat <= length:
				var x := _x(n * beat)
				draw_line(Vector2(x, 18), Vector2(x, size.y), Color(0.45, 0.35, 0.6, 0.5 if n % 4 == 0 else 0.22), 1.0)
				n += 1
		var step := 0.1
		var i := 0
		while i * step <= length + 0.0001:
			var x := _x(i * step)
			var major := i % 5 == 0
			draw_line(Vector2(x, 0), Vector2(x, 8 if not major else 14), Color(0.6, 0.6, 0.65), 1.0)
			if major:
				draw_string(font, Vector2(x + 2, 13), "%.1f" % (i * step), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.65))
			i += 1
		draw_line(Vector2(_x(length), 0), Vector2(_x(length), size.y), Color(0.9, 0.4, 0.4), 2.0)
		draw_string(font, Vector2(MARGIN, 34), "keys", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.55))
		draw_string(font, Vector2(MARGIN, 72), JOINT_NAMES.get(studio._joint, ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.5, 0.5, 0.55))
		var here: int = studio._key_at(studio._time)
		for k in data["keys"].size():
			var key: Dictionary = data["keys"][k]
			var x := _x(float(key.t))
			var moves: bool = key.pose.has(studio._joint)
			var color := GOLD if k == here else Color(0.85, 0.85, 0.9)
			_diamond(Vector2(x, 46), 7.0, color)
			if moves:
				_diamond(Vector2(x, 84), 5.0, Color(0.4, 0.85, 1.0))
		var px := _x(studio._time)
		draw_line(Vector2(px, 0), Vector2(px, size.y), Color(1, 1, 1, 0.9), 2.0)

	func _diamond(at: Vector2, r: float, color: Color) -> void:
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), color)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				studio._playing = false
				_drag = -1
				_drag_end = absf(event.position.x - _x(float(studio._data.length))) < 6.0
				if not _drag_end and event.position.y > 30 and event.position.y < 62:
					for k in studio._data["keys"].size():
						if absf(_x(float(studio._data["keys"][k].t)) - event.position.x) < 8.0:
							_drag = k
							studio._remember()
							break
				if _drag_end:
					studio._remember()
					_end_from = float(studio._data.length)
				elif _drag < 0:
					studio._time = _t(event.position.x)
				else:
					studio._time = float(studio._data["keys"][_drag].t)
				studio._sync_joint_panel()
			else:
				if _drag >= 0 or _drag_end:
					studio._changed()
				_drag = -1
				_drag_end = false
		elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _drag_end:
				var t: float = (event.position.x - MARGIN) / (size.x - 2.0 * MARGIN) * _end_from
				studio._data.length = maxf(snappedf(t, 0.01), 0.1)
				studio._clip = Emotes.parse(studio._data)
			elif _drag >= 0:
				var t: float = studio._snap(_t(event.position.x))
				studio._data["keys"][_drag].t = t
				studio._time = t
				studio._clip = Emotes.parse(studio._data)
				studio._dirty = true
			else:
				studio._time = _t(event.position.x)
				studio._sync_joint_panel()
			queue_redraw()
