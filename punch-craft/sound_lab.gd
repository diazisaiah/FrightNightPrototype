extends Node
## Sound Lab (dev tool, not in the shipped game): the training ring with the
## dummy fighting back, plus a panel (F1) for swapping each game sound live.
## Candidates come from ../audio_lab/slots.json (suggestions from the sound
## packs) and anything dropped in ../audio_lab/drop/ (loose files show up for
## every sound; files in drop/<sound>/ only for that one). Picks save to
## ../audio_lab/picks.json and come back next launch.
## Run it with ../audio_lab/Sound Lab.bat.

const TRAINING := "res://training.tscn"
const AUDIO_EXTENSIONS := ["ogg", "wav", "mp3"]
## The ones a fight with the dummy plays, listed first.
const FIGHT_SOUNDS := ["hit", "heavy", "counter", "block", "whoosh", "slip", "hurt", "tell"]
const ORIGINAL := "(original synth)"
const GAIN_STEP := 2.0

var _lab := ""
## sound -> [candidate path or ORIGINAL]
var _candidates := {}
## sound -> {"index": int, "gain": float}
var _choice := {}
var _original := {}
var _cache := {}
var _layer: CanvasLayer
var _panel: PanelContainer
var _rows: VBoxContainer
var _labels := {}
var _gain_labels := {}


func _ready() -> void:
	# Never touch the real save or settings from here.
	GameState.save_path = "user://sound_lab_save.json"
	Settings.path = "user://sound_lab_settings.cfg"
	GameState.tutorial_done = true
	_lab = ProjectSettings.globalize_path("res://").path_join("../audio_lab").simplify_path()
	for sound in Sfx.sounds():
		_original[sound] = Sfx.stream(sound)
	_scan()
	_load_picks()
	add_child(load(TRAINING).instantiate())
	_build_panel()
	_set_open(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_set_open(not _panel.visible)
		get_viewport().set_input_as_handled()
	elif _panel.visible and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _set_open(open: bool) -> void:
	_panel.visible = open
	get_tree().paused = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


# --- Candidates -------------------------------------------------------------------

func _scan() -> void:
	var suggested := {}
	var json = JSON.parse_string(FileAccess.get_file_as_string(_lab.path_join("slots.json")))
	if json is Dictionary:
		suggested = json
	var loose := _audio_files(_lab.path_join("drop"))
	for sound in _ordered_sounds():
		var list: Array = [ORIGINAL]
		for path in _audio_files(_lab.path_join("drop").path_join(sound)):
			list.append(path)
		for path in loose:
			list.append(path)
		for path in suggested.get(sound, []):
			list.append(_lab.path_join(path))
		var previous: String = _current_path(sound) if _choice.has(sound) else ORIGINAL
		_candidates[sound] = list
		if not _choice.has(sound):
			_choice[sound] = {"index": 0, "gain": 0.0}
		_choice[sound].index = maxi(0, list.find(previous))


func _audio_files(dir: String) -> Array:
	var found := []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	for file in DirAccess.get_files_at(dir):
		if file.get_extension().to_lower() in AUDIO_EXTENSIONS:
			found.append(dir.path_join(file))
	found.sort()
	return found


func _ordered_sounds() -> Array:
	var order := FIGHT_SOUNDS.duplicate()
	for sound in Sfx.sounds():
		if not order.has(sound):
			order.append(sound)
	return order


func _current_path(sound: String) -> String:
	return _candidates[sound][_choice[sound].index]


func _stream_for(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var audio: AudioStream
	match path.get_extension().to_lower():
		"ogg":
			audio = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			audio = AudioStreamWAV.load_from_file(path)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = FileAccess.get_file_as_bytes(path)
			audio = mp3
	_cache[path] = audio
	return audio


func _apply(sound: String) -> void:
	var path := _current_path(sound)
	var audio: AudioStream = _original[sound] if path == ORIGINAL else _stream_for(path)
	if audio == null:
		audio = _original[sound]
	# Looping sounds (the wind) keep looping with a recorded file.
	if sound == "wind" and audio is AudioStreamOggVorbis:
		audio.loop = true
	Sfx.set_stream(sound, audio, _choice[sound].gain)


# --- Picks ------------------------------------------------------------------------

func _load_picks() -> void:
	var picks_file := _lab.path_join("picks.json")
	var json = JSON.parse_string(FileAccess.get_file_as_string(picks_file)) if FileAccess.file_exists(picks_file) else null
	if not json is Dictionary:
		for sound in _candidates:
			_apply(sound)
		return
	for sound in _candidates:
		var pick: Dictionary = json.get(sound, {})
		var file: String = pick.get("file", ORIGINAL)
		var path := file if file == ORIGINAL else _lab.path_join(file)
		_choice[sound].index = maxi(0, _candidates[sound].find(path))
		_choice[sound].gain = float(pick.get("gain_db", 0.0))
		_apply(sound)


func _save_picks() -> void:
	var out := {}
	for sound in _candidates:
		var path := _current_path(sound)
		out[sound] = {"file": path if path == ORIGINAL else path.trim_prefix(_lab + "/"), "gain_db": _choice[sound].gain}
	var file := FileAccess.open(_lab.path_join("picks.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(out, "\t"))


# --- Panel ------------------------------------------------------------------------

func _build_panel() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.card(18.0))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -60
	_panel.offset_top = 20
	_panel.offset_right = -20
	_panel.offset_bottom = -20
	_layer.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_panel.add_child(column)
	column.add_child(UiTheme.title_label("SOUND LAB", 34, UiTheme.GOLD))
	var help := Label.new()
	help.text = "F1 hides this and lets you fight the dummy (number keys change its level).\n▶ previews. < > swaps the sound. − + trims volume. Picks save on their own."
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", UiTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	footer.add_child(_button("Rescan drop folder", func() -> void:
		_scan()
		_fill_rows()))
	footer.add_child(_button("Open drop folder", func() -> void:
		DirAccess.make_dir_recursive_absolute(_lab.path_join("drop"))
		OS.shell_open(_lab.path_join("drop"))))
	footer.add_child(_button("All original", func() -> void:
		for sound in _candidates:
			_choice[sound] = {"index": 0, "gain": 0.0}
			_apply(sound)
		_save_picks()
		_fill_rows()))
	_fill_rows()


func _fill_rows() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_rows.add_child(_section("HEARD IN THE FIGHT"))
	for sound in _ordered_sounds():
		_rows.add_child(_row(sound))
		if sound == FIGHT_SOUNDS[-1]:
			_rows.add_child(_section("EVERYTHING ELSE (PREVIEW WITH ▶)"))


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	return label


func _row(sound: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_button("▶", func() -> void: Sfx.play(sound), 40))
	var name_label := Label.new()
	name_label.text = sound.to_upper()
	name_label.custom_minimum_size.x = 90
	row.add_child(name_label)
	row.add_child(_button("<", func() -> void: _step(sound, -1), 34))
	var pick := Label.new()
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	pick.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_labels[sound] = pick
	row.add_child(pick)
	row.add_child(_button(">", func() -> void: _step(sound, 1), 34))
	row.add_child(_button("−", func() -> void: _trim(sound, -GAIN_STEP), 34))
	var gain := Label.new()
	gain.custom_minimum_size.x = 58
	gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain_labels[sound] = gain
	row.add_child(gain)
	row.add_child(_button("+", func() -> void: _trim(sound, GAIN_STEP), 34))
	_refresh(sound)
	return row


func _button(text: String, action: Callable, width := 0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	if width > 0:
		button.custom_minimum_size.x = width
	button.pressed.connect(action)
	return button


func _step(sound: String, by: int) -> void:
	var count: int = _candidates[sound].size()
	_choice[sound].index = posmod(_choice[sound].index + by, count)
	_apply(sound)
	_save_picks()
	_refresh(sound)
	Sfx.play(sound)


func _trim(sound: String, by: float) -> void:
	_choice[sound].gain = clampf(_choice[sound].gain + by, -24.0, 12.0)
	_apply(sound)
	_save_picks()
	_refresh(sound)
	Sfx.play(sound)


func _refresh(sound: String) -> void:
	var path := _current_path(sound)
	var count: int = _candidates[sound].size()
	var label: Label = _labels[sound]
	label.text = "%d/%d  %s" % [_choice[sound].index + 1, count, path if path == ORIGINAL else path.get_file().get_basename()]
	label.add_theme_color_override("font_color", UiTheme.MUTED if path == ORIGINAL else UiTheme.TEXT)
	_gain_labels[sound].text = "%+d dB" % int(_choice[sound].gain)
