extends Node
## Player preferences (autoloaded as Settings): sound volumes, mouse, field of
## view, screen shake and fullscreen. Kept in their own file so resetting the
## save doesn't touch them.

signal changed

const PATH := "user://settings.cfg"
## Test runs point this elsewhere (FRIGHT_NIGHT_SETTINGS) so they never touch the real settings.
var path: String = OS.get_environment("FRIGHT_NIGHT_SETTINGS") if OS.get_environment("FRIGHT_NIGHT_SETTINGS") != "" else PATH
## Audio buses made at startup; Sfx plays on Effects, ambience on Ambience,
## the soundtrack on Music.
const BUSES := ["Effects", "Ambience", "Music"]
const DEFAULTS := {
	"master": 0.8, "effects": 1.0, "ambience": 0.7, "music": 0.6, "muted": false,
	"mouse_sensitivity": 1.0, "fov": 75.0, "screen_shake": 1.0, "fullscreen": false,
	"post_effects": true, "shadows": true,
	# Control scheme (see Controls).
	"punch_mode": "modifiers", "dodge_mode": "space", "slip_mode": "qe",
	# "junior" (Weenie Hut Junior Mode: Q / E pick the right dodge) or "pro".
	"assist_mode": "junior",
	# How much dodges, counters and finishers slow time (0 = never).
	"slow_motion": 1.0,
	# 3D resolution: "auto" (browser: fits the screen, drops if the frame rate
	# does), "full" or "low".
	"render_scale": "auto",
	# Your own key bindings (Controls.bind): {action: "k:<key>" | "m:<button>"}.
	"bindings": {},
	# Controllers: your own button bindings, look speed, invert, rumble.
	"pad_bindings": {}, "stick_sensitivity": 1.0, "invert_y": false, "vibration": true,
}

var values := DEFAULTS.duplicate()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# One look everywhere: every menu, HUD screen, dropdown and dialog. Merged
	# into Godot's default theme, since a theme set on the window stops at
	# CanvasLayers (the HUD).
	ThemeDB.get_default_theme().merge_with(UiTheme.make())
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			# Web sample playback has a Godot bug when add_bus() appends at -1:
			# Master can be disconnected from the browser audio destination. Growing
			# bus_count creates the same bus without hitting that broken path.
			var index := AudioServer.bus_count
			AudioServer.bus_count = index + 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	_load()
	_apply_web_defaults()
	apply()
	get_tree().node_added.connect(_on_node_added)


func get_value(key: String):
	return values.get(key, DEFAULTS[key])


func set_value(key: String, value) -> void:
	values[key] = value
	apply()
	save()
	changed.emit()


func mouse_sensitivity() -> float:
	return get_value("mouse_sensitivity")


func fov() -> float:
	return get_value("fov")


func screen_shake() -> float:
	return get_value("screen_shake")


## The environment flag lets the automated performance probe exercise the
## browser quality path from a native Compatibility-renderer build.
# --- Browser performance ---------------------------------------------------------
## Auto resolution aims for about this many 3D pixels (1280 x 720), so a big or
## high-DPI browser window doesn't render 2-4x the pixels.
const WEB_PIXEL_BUDGET := 1280.0 * 720.0
const MIN_RENDER_SCALE := 0.4
## At most this many scenery lights (torches, candles, glows) are on at once in
## the browser: the nearest to the camera. Lights on characters aren't touched.
const WEB_LIGHT_BUDGET := 6
const WEB_LIGHT_RANGE := 18.0

var _scenery_lights: Array = []
## The nearest-lights budget (on in the browser; the web bench turns it off to compare).
var light_budget := true
var _light_timer := 0.0
var _fps_timer := 0.0
var _fps_frames := 0
## Lowered while the browser can't hold its frame rate, raised back slowly.
var _quality_drop := 0.0
var _good_windows := 0


func _process(delta: float) -> void:
	if not use_web_profile():
		return
	_light_timer -= delta
	if _light_timer <= 0.0 and light_budget:
		_light_timer = 0.25
		_budget_lights()
	_fps_frames += 1
	_fps_timer += delta
	if _fps_timer >= 2.0:
		var fps := _fps_frames / _fps_timer
		_fps_frames = 0
		_fps_timer = 0.0
		if get_value("render_scale") == "auto":
			# Only real lag lowers it: many browsers cap at 30 (power saving,
			# hidden tabs), which isn't worth blurring the picture for.
			if fps < 26.0:
				_quality_drop = minf(_quality_drop + 0.1, 0.5)
				_good_windows = 0
			elif fps >= 29.0:
				_good_windows += 1
				if _good_windows >= 3:
					_good_windows = 0
					_quality_drop = maxf(_quality_drop - 0.05, 0.0)
		apply_render_scale()


## The 3D resolution scale for the main view (and SubViewports that ask).
func render_scale() -> float:
	match get_value("render_scale"):
		"full":
			return 1.0
		"low":
			return 0.5
	if not use_web_profile():
		return 1.0
	var pixels := float(get_tree().root.size.x * get_tree().root.size.y) if get_tree() else WEB_PIXEL_BUDGET
	var fit := sqrt(WEB_PIXEL_BUDGET / maxf(pixels, 1.0))
	return clampf(minf(fit, 1.0) - _quality_drop, MIN_RENDER_SCALE, 1.0)


func apply_render_scale() -> void:
	if get_tree() == null:
		return
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = render_scale()


func _on_node_added(node: Node) -> void:
	if not node is Light3D or node is DirectionalLight3D:
		return
	# Lights on characters (the lantern, enemy auras) and in SubViewports stay.
	var parent := node.get_parent()
	while parent:
		if parent is CharacterBody3D or parent is SubViewport:
			return
		parent = parent.get_parent()
	_scenery_lights.append(node)


## Keeps only the nearest few scenery lights on (browser only).
func _budget_lights() -> void:
	var camera := get_viewport().get_camera_3d()
	_scenery_lights = _scenery_lights.filter(func(light) -> bool: return is_instance_valid(light) and light.is_inside_tree())
	if camera == null or _scenery_lights.is_empty():
		return
	var from := camera.global_position
	var sorted := _scenery_lights.duplicate()
	sorted.sort_custom(func(a: Light3D, b: Light3D) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	for i in sorted.size():
		var light: Light3D = sorted[i]
		light.visible = i < WEB_LIGHT_BUDGET and light.global_position.distance_to(from) < WEB_LIGHT_RANGE


func use_web_profile() -> bool:
	return OS.has_feature("web") or OS.get_environment("FRIGHT_NIGHT_FORCE_WEB_PROFILE") == "1"


func apply() -> void:
	Controls.apply()
	apply_render_scale()
	_set_volume("Master", get_value("master"))
	_set_volume("Effects", get_value("effects"))
	_set_volume("Ambience", get_value("ambience"))
	_set_volume("Music", get_value("music"))
	AudioServer.set_bus_mute(0, get_value("muted") or get_value("master") <= 0.001)
	var fullscreen: bool = get_value("fullscreen")
	var mode := DisplayServer.window_get_mode()
	var is_fullscreen := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_fullscreen and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	_apply_web_defaults()
	apply()
	save()
	changed.emit()


func save() -> void:
	var file := ConfigFile.new()
	for key in values:
		file.set_value("settings", key, values[key])
	file.save(path)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key in DEFAULTS:
		values[key] = file.get_value("settings", key, DEFAULTS[key])
	# Settings saved before Weenie Hut Junior Mode existed (2026-10-14) move
	# to the new default dodge scheme, Space + direction, once.
	if not file.has_section_key("settings", "assist_mode"):
		values["dodge_mode"] = DEFAULTS["dodge_mode"]


func _apply_web_defaults() -> void:
	if use_web_profile():
		values["post_effects"] = false
		values["shadows"] = false


func _set_volume(bus: String, amount: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(amount, 0.0001)))
	AudioServer.set_bus_mute(index, amount <= 0.001)
