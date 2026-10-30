class_name SettingsPanel
extends PanelContainer
## The settings window (title screen and pause menu). A tab rail on the left
## (Sound, Controls, Display, Save data), and each setting as its own row: an
## icon, a name and a one-line hint, with chunky gold sliders, sliding
## switches, and the control schemes as tiles you click instead of dropdowns.
## Changes apply and save immediately.

signal closed

## Seconds the "really erase?" state of the reset button lasts.
const CONFIRM_TIME := 4.0
const TABS := [["SOUND", "note"], ["CONTROLS", "glove"], ["DISPLAY", "sun"], ["SAVE DATA", "skull"]]
## Each choice setting's options as [title, detail] tiles.
const CHOICES := {
	"assist_mode": {
		"junior": ["Weenie Hut Junior", "Q / E dodges, the game picks how"],
		"pro": ["Pro Gamer", "Slip, roll and back step yourself"],
	},
	"punch_mode": {
		"modifiers": ["Shift / Ctrl + click", "Hold a key, then punch"],
		"wheel": ["Scroll wheel", "Down hook, up uppercut"],
		"side_buttons": ["Mouse side buttons", "Front hook, back uppercut"],
	},
	"dodge_mode": {
		"ctrl": ["Ctrl + A / D / S", "Hold Ctrl with a direction"],
		"space": ["Space + A / D / S / W", "Jump moves to C"],
		"double_tap": ["Double-tap A / D / S", "Tap a direction twice"],
		"keys": ["Tab / R", "Roll left / right, ultimate on T"],
		"shift_qe": ["Shift + Q / E", "Roll left / right, double-tap S back step"],
	},
	"slip_mode": {
		"qe": ["Q / E", "Slip left / right"],
		"qe_side": ["Q / E + side buttons", "Back left, front right"],
	},
	"render_scale": {
		"auto": ["Auto", "Fits your screen"],
		"full": ["Full", "Sharpest"],
		"low": ["Low", "Fastest"],
	},
}

## False in the pause menu: no erasing your save mid-run.
var show_save_data := true

var _controls := {}
var _pages := {}
var _tab_buttons := {}
var _content: ScrollContainer
var _reset_button: Button
var _reset_armed := false
var _reset_timer: SceneTreeTimer
## Save codes: the copy button and the code it shows; the paste box, its
## load button (two clicks, like erasing) and what happened.
var _copy_button: Button
var _code_shown: LineEdit
var _code_box: LineEdit
var _load_button: Button
var _load_armed := false
var _code_note: Label
## Only shows when two control choices collide.
var _scheme_note: Label
## Key bindings: the list of rows (rebuilt when the mode changes), the
## action waiting for a key, and its button.
var _bind_list: VBoxContainer
var _listening := ""
var _listen_button: Button
## True while the waiting binding is a controller one.
var _listen_pad := false
## The last letters typed (for TONY_CODE and CATALYST_CODE).
var _typed := ""
static var _knob: ImageTexture


func _ready() -> void:
	theme = UiTheme.make()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var view := get_viewport_rect().size
	custom_minimum_size = Vector2(minf(960.0, view.x - 40.0), minf(620.0, view.y - 40.0))
	add_theme_stylebox_override("panel", UiTheme.card(0.0))
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)

	# Header: the title, and Done.
	var header_margin := _margin(28, 18, 22, 14)
	frame.add_child(header_margin)
	var header := HBoxContainer.new()
	header_margin.add_child(header)
	var title := UiTheme.title_label("SETTINGS", 46, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = "PrimaryButton"
	done.custom_minimum_size = Vector2(150, 46)
	done.add_theme_font_size_override("font_size", 20)
	done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close)
	header.add_child(done)
	var rule := ColorRect.new()
	rule.color = Color(UiTheme.GOLD, 0.35)
	rule.custom_minimum_size.y = 2
	frame.add_child(rule)

	# Body: the tab rail, and the open page.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	frame.add_child(body)
	var rail_panel := PanelContainer.new()
	rail_panel.custom_minimum_size.x = 220
	var rail_style := UiTheme.box(Color(0, 0, 0, 0.35), Color.TRANSPARENT, 0, 0, 0.0)
	rail_style.corner_radius_bottom_left = 12
	rail_panel.add_theme_stylebox_override("panel", rail_style)
	body.add_child(rail_panel)
	var rail_margin := _margin(12, 16, 12, 16)
	rail_panel.add_child(rail_margin)
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	rail_margin.add_child(rail)
	var group := ButtonGroup.new()
	for tab in TABS:
		if tab[0] == "SAVE DATA" and not show_save_data:
			continue
		var button := _tab_button(tab[0], tab[1], group)
		rail.add_child(button)
		_tab_buttons[tab[0]] = button
	var rail_space := Control.new()
	rail_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.add_child(rail_space)
	var defaults := Button.new()
	defaults.text = "Restore defaults"
	defaults.custom_minimum_size.y = 40
	defaults.pressed.connect(func() -> void:
		Settings.reset_defaults()
		_refresh()
		Sfx.play("tell", -6.0))
	rail.add_child(defaults)

	_content = KeptScroll.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_content)
	var pages_margin := _margin(22, 18, 24, 18)
	pages_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(pages_margin)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_margin.add_child(pages)

	var sound := _page(pages, "SOUND")
	_slider(sound, "master", "note", "Master volume", "Everything at once", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(sound, "effects", "burst", "Effects", "Punches, hits and the crowd", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(sound, "music", "note", "Music", "The soundtrack", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(sound, "ambience", "wind", "Ambience", "Wind and the night", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_toggle(sound, "muted", "skull", "Mute all sound", "Silence, even the bell")

	var controls := _page(pages, "CONTROLS")
	_slider(controls, "mouse_sensitivity", "crosshair", "Mouse sensitivity", "How fast you look around", 0.25, 3.0, 0.05, "x%.2f", 1.0)
	_slider(controls, "fov", "eye", "Field of view", "How wide you see", 60.0, 100.0, 1.0, "%d", 1.0)
	_choice(controls, "assist_mode", "slip", "Mode", "How dodging works")
	_choice(controls, "punch_mode", "crossed_gloves", "Hooks and uppercuts", "How you throw them")
	_choice(controls, "dodge_mode", "swoosh", "Rolls and back step", "Pro Gamer Mode keys, and the dash")
	_choice(controls, "slip_mode", "wing_boot", "Slips", "Pro Gamer Mode keys")
	_scheme_note = _label("", 14, UiTheme.BAD)
	_scheme_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(_scheme_note)
	_slider(controls, "stick_sensitivity", "crosshair", "Controller look speed", "How fast the right stick turns you", 0.3, 3.0, 0.05, "x%.2f", 1.0)
	_toggle(controls, "invert_y", "eye", "Invert controller look", "Push up to look down")
	_toggle(controls, "vibration", "quake", "Controller vibration", "Rumble when you get hit")
	_build_bindings(controls)

	var display := _page(pages, "DISPLAY")
	_slider(display, "screen_shake", "quake", "Screen shake", "Shake on big hits", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(display, "slow_motion", "hourglass", "Slow motion", "Hit freezes and slow-mo on counters and knockouts. 0 turns both off", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_toggle(display, "fullscreen", "chevrons", "Fullscreen", "Fill the whole screen")
	_choice(display, "render_scale", "spark", "3D resolution", "Lower runs faster")
	_toggle(display, "post_effects", "moon", "Film effects", "Grain, vignette and color grade")
	_toggle(display, "shadows", "flame", "Torch shadows", "Turn off if the game runs slowly")

	if show_save_data:
		var data := _page(pages, "SAVE DATA")
		_build_save_codes(data)
		var slot := _row(data, "cracked_skull", "Erase all progress", "Every fighter, upgrade and unlock. Can't be undone.", UiTheme.BAD)
		_reset_button = Button.new()
		_reset_button.custom_minimum_size = Vector2(240, 44)
		_reset_button.pressed.connect(_on_reset_pressed)
		slot.add_child(_reset_button)
		_disarm_reset()

	_show_tab("SOUND", false)
	_refresh()


## While a binding is listening, the next key or mouse button is the new
## binding (Esc cancels).
func _input(event: InputEvent) -> void:
	if visible and _listening == "" and event is InputEventKey and event.pressed and not event.echo:
		_type_secret(event)
	if _listening == "" or not visible:
		return
	var pressed: bool
	if _listen_pad:
		# Buttons and the triggers (the sticks stay move and look).
		pressed = (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion \
				and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and event.axis_value > 0.6)
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_stop_listening()
			_refresh()
			return
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
			get_viewport().set_input_as_handled()
			_stop_listening()
			_refresh()
			return
	else:
		pressed = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed and not event.has_meta("pad"))
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_stop_listening()
			_refresh()
			return
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	Controls.bind(_listening, event)
	Sfx.play("tick", -6.0, 1.2)
	_stop_listening()
	_refresh()


## Secrets: typing FUGGEDABOUDIT anywhere in Settings unlocks Tony, and
## ABRACADABRA the Catalyst (as if bought in the Soul Shop).
const TONY_CODE := "fuggedaboudit"
const CATALYST_CODE := "abracadabra"


func _type_secret(event: InputEventKey) -> void:
	var letter := String.chr(event.unicode).to_lower() if event.unicode > 0 else ""
	if letter.length() != 1 or letter < "a" or letter > "z":
		return
	_typed = (_typed + letter).right(maxi(TONY_CODE.length(), CATALYST_CODE.length()))
	var fighter := ""
	if _typed.ends_with(TONY_CODE) and not GameState.tony_unlocked:
		GameState.unlock_tony()
		fighter = "wise_guy"
	elif _typed.ends_with(CATALYST_CODE) and not GameState.fighters_bought.has("elementalist"):
		GameState.unlock_catalyst()
		fighter = "elementalist"
	if fighter != "":
		_typed = ""
		var screen := TonyUnlock.open(get_tree(), fighter)
		# The title's fighter picker was built without him: rebuild it.
		var scene := get_tree().current_scene
		if scene and scene.scene_file_path.ends_with("title.tscn"):
			screen.closed.connect(Loading.reload)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	_stop_listening()
	Sfx.play("whoosh", -8.0, 1.3)
	closed.emit()


# --- Tabs ---------------------------------------------------------------------------

func _tab_button(text: String, icon: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(0, 52)
	var normal := UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 8)
	var hover := UiTheme.box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 8)
	var on := UiTheme.box(Color(UiTheme.GOLD, 0.14), UiTheme.GOLD, 0, 8)
	on.border_width_left = 4
	for state in ["normal", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var glyph := IconView.new()
	glyph.icon = icon
	glyph.custom_minimum_size = Vector2(28, 28)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var label := UiTheme.title_label(text, 20, UiTheme.MUTED)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	button.toggled.connect(func(on_now: bool) -> void:
		label.add_theme_color_override("font_color", UiTheme.GOLD.lightened(0.25) if on_now else UiTheme.MUTED)
		glyph.color = UiTheme.GOLD if on_now else UiTheme.MUTED
		glyph.queue_redraw())
	button.pressed.connect(func() -> void:
		Sfx.play("tick", -8.0)
		_show_tab(text, true))
	glyph.color = UiTheme.MUTED
	return button


func _show_tab(tab: String, animate: bool) -> void:
	for other in _tab_buttons:
		_tab_buttons[other].set_pressed_no_signal(other == tab)
		_tab_buttons[other].toggled.emit(other == tab)
	for page in _pages:
		_pages[page].visible = page == tab
	_content.scroll_vertical = 0
	if animate:
		var page: Control = _pages[tab]
		page.modulate.a = 0.0
		page.create_tween().tween_property(page, "modulate:a", 1.0, 0.18)


func _page(parent: Control, tab: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(page)
	_pages[tab] = page
	return page


# --- Rows ---------------------------------------------------------------------------

## A setting's card: icon, name and hint on the left; returns the box on the
## right where its control goes.
func _row(page: Control, icon: String, title: String, hint: String, tint := UiTheme.GOLD) -> HBoxContainer:
	var card := _card(page)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	_row_head(row, icon, title, hint, tint)
	var slot := HBoxContainer.new()
	slot.add_theme_constant_override("separation", 12)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slot)
	return slot


func _card(page: Control) -> PanelContainer:
	var card := PanelContainer.new()
	var calm := UiTheme.box(Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.07), 1, 10, 14.0)
	var lit := UiTheme.box(Color(1, 1, 1, 0.06), Color(UiTheme.GOLD, 0.35), 1, 10, 14.0)
	card.add_theme_stylebox_override("panel", calm)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.mouse_entered.connect(func() -> void: card.add_theme_stylebox_override("panel", lit))
	card.mouse_exited.connect(func() -> void: card.add_theme_stylebox_override("panel", calm))
	page.add_child(card)
	return card


func _row_head(row: HBoxContainer, icon: String, title: String, hint: String, tint: Color) -> void:
	var glyph := IconView.new()
	glyph.icon = icon
	glyph.color = tint
	glyph.custom_minimum_size = Vector2(36, 36)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", 0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name_label := _label(title, 19)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	texts.add_child(name_label)
	texts.add_child(_label(hint, 14, UiTheme.MUTED))


func _slider(page: Control, key: String, icon: String, title: String, hint: String, low: float, high: float, step: float, value_format: String, display_scale: float) -> void:
	var slot := _row(page, icon, title, hint)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size = Vector2(250, 28)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var groove := UiTheme.box(Color(0, 0, 0, 0.55), Color(1, 1, 1, 0.08), 1, 5)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	var fill := UiTheme.box(UiTheme.GOLD.darkened(0.1), Color.TRANSPARENT, 0, 5)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	var fill_lit: StyleBoxFlat = fill.duplicate()
	fill_lit.bg_color = UiTheme.GOLD.lightened(0.1)
	slider.add_theme_stylebox_override("slider", groove)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_lit)
	slider.add_theme_icon_override("grabber", _knob_texture())
	slider.add_theme_icon_override("grabber_highlight", _knob_texture())
	slot.add_child(slider)
	var pill := PanelContainer.new()
	pill.custom_minimum_size = Vector2(76, 0)
	pill.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.45), Color(UiTheme.GOLD, 0.4), 1, 14, 5.0))
	slot.add_child(pill)
	var value_label := UiTheme.title_label("", 18, UiTheme.GOLD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(value_label)
	var show := func(value: float) -> void:
		value_label.text = value_format % (roundi(value * display_scale) if value_format.contains("%d") else value * display_scale)
	slider.value_changed.connect(func(value: float) -> void:
		show.call(value)
		Settings.set_value(key, value))
	# A blip on release, so you can hear the new volume.
	if key in ["master", "effects"]:
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("hit", -4.0))
	_controls[key] = {"slider": slider, "show": show}


## A sliding on/off switch: gold and to the right when on.
func _toggle(page: Control, key: String, icon: String, title: String, hint: String) -> void:
	var slot := _row(page, icon, title, hint)
	var switch := Button.new()
	switch.toggle_mode = true
	switch.flat = true
	switch.focus_mode = Control.FOCUS_NONE
	switch.custom_minimum_size = Vector2(68, 34)
	switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	switch.set_meta("slide", 0.0)
	switch.draw.connect(func() -> void:
		var t: float = switch.get_meta("slide")
		var rect := Rect2(Vector2.ZERO, switch.size)
		var track := Color(0, 0, 0, 0.55).lerp(UiTheme.GOLD.darkened(0.15), t)
		switch.draw_style_box(UiTheme.box(track, Color(1, 1, 1, 0.12).lerp(UiTheme.GOLD, t), 1, int(rect.size.y / 2.0)), rect)
		var radius := rect.size.y / 2.0 - 4.0
		var x := lerpf(rect.size.y / 2.0, rect.size.x - rect.size.y / 2.0, t)
		switch.draw_circle(Vector2(x, rect.size.y / 2.0 + 1.5), radius, Color(0, 0, 0, 0.35))
		switch.draw_circle(Vector2(x, rect.size.y / 2.0), radius, Color(0.95, 0.93, 0.9)))
	switch.toggled.connect(func(on: bool) -> void:
		Settings.set_value(key, on)
		Sfx.play("tick", -8.0)
		_slide(switch, on))
	slot.add_child(switch)
	_controls[key] = {"toggle": switch}


func _slide(switch: Button, on: bool, animate := true) -> void:
	var target := 1.0 if on else 0.0
	if not animate:
		switch.set_meta("slide", target)
		switch.queue_redraw()
		return
	var tween := switch.create_tween()
	tween.tween_method(func(v: float) -> void:
		switch.set_meta("slide", v)
		switch.queue_redraw(), float(switch.get_meta("slide")), target, 0.14).set_trans(Tween.TRANS_QUAD)


## The options as tiles you click, two or three to a row, the picked one lit.
func _choice(page: Control, key: String, icon: String, title: String, hint: String) -> void:
	var card := _card(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	_row_head(head, icon, title, hint, UiTheme.GOLD)
	var options: Dictionary = CHOICES[key]
	var grid := GridContainer.new()
	grid.columns = 3 if options.size() == 3 else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var group := ButtonGroup.new()
	var tiles := {}
	for id in options:
		var tile := _tile(options[id][0], options[id][1], group)
		tile.pressed.connect(func() -> void:
			Settings.set_value(key, id)
			Sfx.play("tick", -8.0)
			_refresh())
		grid.add_child(tile)
		tiles[id] = tile
	_controls[key] = {"tiles": tiles}


func _tile(title: String, detail: String, group: ButtonGroup) -> Button:
	var tile := Button.new()
	tile.toggle_mode = true
	tile.button_group = group
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(0, 66)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UiTheme.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.1), 1, 8)
	var hover := UiTheme.box(Color(1, 1, 1, 0.06), Color(UiTheme.GOLD, 0.45), 1, 8)
	var picked := UiTheme.box(Color(UiTheme.GOLD, 0.16), UiTheme.GOLD, 2, 8)
	picked.shadow_color = Color(UiTheme.GOLD, 0.25)
	picked.shadow_size = 8
	tile.add_theme_stylebox_override("normal", normal)
	tile.add_theme_stylebox_override("hover", hover)
	tile.add_theme_stylebox_override("pressed", picked)
	tile.add_theme_stylebox_override("hover_pressed", picked)
	var texts := VBoxContainer.new()
	texts.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texts.offset_left = 14
	texts.offset_right = -10
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(texts)
	var name_label := _label(title, 17)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var detail_label := _label(detail, 13, UiTheme.MUTED)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(detail_label)
	tile.toggled.connect(func(on: bool) -> void:
		name_label.add_theme_color_override("font_color", UiTheme.GOLD.lightened(0.3) if on else UiTheme.TEXT))
	return tile


# --- Key bindings -------------------------------------------------------------------

func _build_bindings(page: Control) -> void:
	var card := _card(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	column.add_child(head)
	_row_head(head, "fist", "Bindings", "Click one, then press the new key, mouse button or controller button. Esc / Start cancels.", UiTheme.GOLD)
	var reset := Button.new()
	reset.text = "Reset keys"
	reset.focus_mode = Control.FOCUS_NONE
	reset.custom_minimum_size = Vector2(130, 38)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func() -> void:
		_stop_listening()
		Controls.reset_bindings()
		Sfx.play("tick", -8.0)
		_refresh())
	head.add_child(reset)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(spacer)
	for title in ["KEYBOARD", "CONTROLLER"]:
		var label := _label(title, 13, UiTheme.MUTED)
		label.custom_minimum_size.x = 170
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		columns.add_child(label)
	column.add_child(columns)
	_bind_list = VBoxContainer.new()
	_bind_list.add_theme_constant_override("separation", 4)
	column.add_child(_bind_list)


func _fill_bindings() -> void:
	if _bind_list == null:
		return
	for child in _bind_list.get_children():
		child.queue_free()
	var custom := Controls.bindings()
	var pad_custom := Controls.pad_bindings()
	for entry in Controls.bindable_rows():
		var action: String = entry[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var name_label := _label(entry[1], 16, UiTheme.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var shown := Controls.kb_name(action)
		if shown == "-":
			# Nothing of its own: say how it's done instead.
			shown = {"punch_hook": Controls.kb_hint("hook"), "punch_uppercut": Controls.kb_hint("uppercut")}.get(action, "Not set")
		row.add_child(_bind_button(action, false, shown, custom.has(action)))
		var on_pad := Controls.pad_name(action)
		row.add_child(_bind_button(action, true, on_pad if on_pad != "-" else "Not set", pad_custom.has(action)))
		_bind_list.add_child(row)


func _bind_button(action: String, for_pad: bool, shown: String, custom: bool) -> Button:
	var key := Button.new()
	var waiting := action == _listening and for_pad == _listen_pad
	key.text = ("Press a button..." if for_pad else "Press a key...") if waiting else shown
	key.focus_mode = Control.FOCUS_NONE
	key.custom_minimum_size = Vector2(170, 34)
	key.add_theme_font_size_override("font_size", 15)
	key.add_theme_color_override("font_color", UiTheme.GOLD.lightened(0.3) if custom else UiTheme.TEXT)
	key.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.12), 1, 6))
	key.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 1, 1, 0.06), Color(UiTheme.GOLD, 0.5), 1, 6))
	key.pressed.connect(func() -> void:
		_listening = action
		_listen_pad = for_pad
		_listen_button = key
		Pad.listening = for_pad
		key.text = "Press a button..." if for_pad else "Press a key...")
	return key


func _stop_listening() -> void:
	_listening = ""
	_listen_button = null
	_listen_pad = false
	Pad.listening = false


func _refresh() -> void:
	_fill_bindings()
	if _scheme_note:
		var clash: bool = Settings.get_value("punch_mode") == "side_buttons" and Settings.get_value("slip_mode") == "qe_side"
		_scheme_note.text = "Side buttons are on hooks and uppercuts, so slips stay on Q / E." if clash else ""
		_scheme_note.visible = clash
	for key in _controls:
		var control: Dictionary = _controls[key]
		if control.has("tiles"):
			var current = Settings.get_value(key)
			for id in control.tiles:
				control.tiles[id].set_pressed_no_signal(id == current)
				control.tiles[id].toggled.emit(id == current)
		elif control.has("slider"):
			control.slider.set_value_no_signal(Settings.get_value(key))
			control.show.call(Settings.get_value(key))
		else:
			var on: bool = Settings.get_value(key)
			control.toggle.set_pressed_no_signal(on)
			_slide(control.toggle, on, false)


# --- Save data ----------------------------------------------------------------------

## Back up: copy your save as a code. Restore: paste one in and load it.
func _build_save_codes(page: Control) -> void:
	var copy_slot := _row(page, "chest", "Back up your save", "Copy the code. Keep it somewhere safe.")
	_copy_button = Button.new()
	_copy_button.text = "Copy save code"
	_copy_button.custom_minimum_size = Vector2(240, 44)
	_copy_button.pressed.connect(_copy_save_code)
	copy_slot.add_child(_copy_button)
	_code_shown = LineEdit.new()
	_code_shown.editable = false
	_code_shown.visible = false
	_code_shown.select_all_on_focus = true
	page.add_child(_code_shown)
	var load_slot := _row(page, "shovel", "Load a save code", "Replaces this save.")
	_code_box = LineEdit.new()
	_code_box.placeholder_text = "Paste a code"
	_code_box.custom_minimum_size = Vector2(220, 44)
	_code_box.text_changed.connect(func(_text: String) -> void:
		_disarm_load()
		_code_note.text = "")
	load_slot.add_child(_code_box)
	_load_button = Button.new()
	_load_button.custom_minimum_size = Vector2(130, 44)
	_load_button.pressed.connect(_on_load_pressed)
	load_slot.add_child(_load_button)
	_code_note = _label("", 14, UiTheme.MUTED)
	_code_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_code_note)
	_disarm_load()


func _copy_save_code() -> void:
	var code := GameState.save_code()
	DisplayServer.clipboard_set(code)
	_code_shown.text = code
	_code_shown.visible = true
	_copy_button.text = "Copied"
	Sfx.play("coin", -6.0, 1.2)
	get_tree().create_timer(2.0, true).timeout.connect(func() -> void:
		if is_instance_valid(_copy_button):
			_copy_button.text = "Copy save code")


## Two clicks to load, like erasing.
func _on_load_pressed() -> void:
	if _code_box.text.strip_edges() == "":
		_code_note.text = "Paste a code first."
		return
	if not _load_armed:
		_load_armed = true
		_load_button.text = "Click again"
		_load_button.add_theme_color_override("font_color", UiTheme.BAD)
		Sfx.play("block", -6.0, 0.8)
		var armed_box := _code_box.text
		get_tree().create_timer(CONFIRM_TIME, true).timeout.connect(func() -> void:
			if is_instance_valid(_code_box) and _code_box.text == armed_box:
				_disarm_load())
		return
	var problem := GameState.load_save_code(_code_box.text)
	_disarm_load()
	if problem != "":
		_code_note.text = problem
		_code_note.add_theme_color_override("font_color", UiTheme.BAD)
		Sfx.play("deny", -6.0)
		return
	_code_note.text = "Loaded."
	_code_note.add_theme_color_override("font_color", UiTheme.GOOD)
	Sfx.play("unlock", -4.0)
	# The title screen was built from the old save.
	get_tree().create_timer(0.6, true).timeout.connect(Loading.reload)


func _disarm_load() -> void:
	_load_armed = false
	if _load_button:
		_load_button.text = "Load"
		_load_button.remove_theme_color_override("font_color")


## Two clicks to erase: the first arms the button for a few seconds.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Click again to ERASE"
		_reset_button.add_theme_color_override("font_color", UiTheme.BAD)
		_reset_button.add_theme_color_override("font_hover_color", UiTheme.BAD.lightened(0.3))
		Sfx.play("block", -6.0, 0.8)
		_reset_timer = get_tree().create_timer(CONFIRM_TIME, true)
		var armed_timer := _reset_timer
		armed_timer.timeout.connect(func() -> void:
			if _reset_timer == armed_timer:
				_disarm_reset())
		return
	GameState.reset_progress()
	_disarm_reset()
	_reset_button.text = "Progress erased"
	Sfx.play("death", -2.0, 0.7)


func _disarm_reset() -> void:
	_reset_armed = false
	_reset_timer = null
	_reset_button.text = "Erase progress"
	_reset_button.remove_theme_color_override("font_color")
	_reset_button.remove_theme_color_override("font_hover_color")


# --- Helpers ------------------------------------------------------------------------

func _label(text: String, font_size: int, color := UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


## The slider knob: a bone-white disc with a gold ring and a dark rim.
static func _knob_texture() -> ImageTexture:
	if _knob:
		return _knob
	var size := 26
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0 - Vector2(0.5, 0.5)
	for x in size:
		for y in size:
			var d := Vector2(x, y).distance_to(center)
			var color := Color(0, 0, 0, 0)
			if d <= 12.5:
				color = Color(0.05, 0.03, 0.02, 0.9)
			if d <= 11.0:
				color = UiTheme.GOLD
			if d <= 8.0:
				color = Color(0.96, 0.94, 0.88)
			# Soft edge.
			color.a *= clampf(12.5 - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, color)
	_knob = ImageTexture.create_from_image(image)
	return _knob
