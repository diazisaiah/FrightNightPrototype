class_name Hud
extends CanvasLayer
## In-run HUD: knuckle HP, level/XP, coins, night progress, combo, kill feed, damage
## flash, the pause menu (P or Esc) and the end-of-run summary.

signal end_run_requested
signal back_to_camp_requested
## The player chose to push on into the next night after beating the boss.
signal continue_requested
## The dawn screen's "Descend into the Crypt" button.
signal crypt_requested
## The player decided on a found item: equip it, or salvage it for coins.
signal item_decided(equip: bool)
## Gild this worn find at a Crypt altar.
signal gild_chosen(item: Dictionary)
## The Crypt merchant's shop: a ware's index, or -1 for the heal.
signal ware_chosen(index: int)

var _can_pause := true
var _announce_tween: Tween
var _flash_tween: Tween
var _combo_tween: Tween
var _crosshair_tween: Tween
var _knuckle_ratio := 1.0
var _pulse_time := 0.0

@onready var _knuckle_bar: ProgressBar = %KnuckleBar
@onready var _knuckle_label: Label = %KnuckleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_bar: ProgressBar = %XpBar
@onready var _resource_label: Label = %ResourceLabel
@onready var _combo_label: Label = %ComboLabel
@onready var _feed: VBoxContainer = %Feed
@onready var _controls_label: Label = %ControlsLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _summary_panel: Control = %SummaryPanel
@onready var _summary_title: Label = %SummaryTitle
@onready var _summary_details: Label = %SummaryDetails
@onready var _wave_label: Label = %WaveLabel
@onready var _announcement: Label = %Announcement
@onready var _damage_flash: TextureRect = %DamageFlash
@onready var _low_health_vignette: TextureRect = %LowHealthVignette
@onready var _crosshair: ColorRect = %Crosshair
@onready var _counter_label: Label = %CounterLabel
@onready var _level_panel: Label = %LevelPanel
@onready var _class_label: Label = %ClassLabel
@onready var _boss_bar: ProgressBar = %BossBar
@onready var _boss_name: Label = %BossName
## Fills with kills; the boss rises when it's full. Shares the boss bar's spot.
var _night_bar: ProgressBar
var _night_bar_label: Label
## "F  Open chest" etc. near the bottom of the screen.
var _prompt: Label
## What the player is wearing (Crypt runs).
var _equipment_box: VBoxContainer
var _knuckle_ghost: ProgressBar
var _knuckle_ticks: Control
var _ghost_tween: Tween
var _crypt_button: Button
var _ult_label: Label
var _ult_bar: ProgressBar
var _ult_gauge: UltGauge
var _ult_fill: StyleBoxFlat
var _ult_name := ""
var _ult_status := ""
var _ult_ready := false
var _passive_chip: PanelContainer
var _passive_icon: IconView
var _passive_name: Label
var _passive_value: Label
var _passive_ready := false
## The Endless powers' chip, over the passive's: Quake's recharge, Gale
## charges, Iron plates.
## The selected powers, bottom right.
var _power_tiles: PowerTiles
var _time_stop: Control
var _time_clock: Control
var _time_keys: Label
var _time_name: Label
var _time_hits: Label
var _time_fraction := 1.0
var _time_tint: ColorRect
var _item_panel: PanelContainer
## Coins (and silver in the Crypt) as icon pills in the top-right corner.
var _resource_chips := {}
var _resources_shown := false
## Icon-capable text drawn inside the announcement, prompt and summary.
var _announce_text: IconLabel
var _prompt_text: IconLabel
var _summary_text: IconLabel
## Covers the screen during a knockout: tinted red, then black.
var _ko_cover: ColorRect
## Big centered speech line (a boss's taunt or last words).
var _speech: RichTextLabel
var _speech_tween: Tween


func _ready() -> void:
	add_to_group("hud")
	_pause_panel.hide()
	_summary_panel.hide()
	# Key names follow the bindings and whether you're on a controller.
	Controls.watch(self, func() -> void:
		if _ult_gauge:
			_refresh_ult_label()
		if _controls_page and _controls_page.is_visible_in_tree():
			show_controls())
	%ResumeButton.pressed.connect(set_paused.bind(false))
	%GiveUpButton.pressed.connect(_on_give_up_pressed)
	%CampButton.pressed.connect(back_to_camp_requested.emit)
	_add_settings_button()
	_build_pause_tabs()
	_add_crypt_button()
	%ContinueButton.pressed.connect(continue_requested.emit)
	show_controls()
	add_child(PostFx.new())
	_style_hud()
	_build_night_bar()
	_build_crypt_ui()
	_build_resource_row()
	_build_knockout_cover()
	_place_top_row()
	GameState.changed.connect(_refresh_progress)
	Settings.changed.connect(show_controls)
	_refresh_progress()


func _process(delta: float) -> void:
	_pulse_time += delta
	# No crosshair while the camera's out for an emote.
	var camera := get_viewport().get_camera_3d()
	_crosshair.visible = camera == null or not camera.is_in_group("emote_cam")
	# Edges throb red when knuckles are under 30%.
	var danger := clampf((0.3 - _knuckle_ratio) / 0.3, 0.0, 1.0)
	_low_health_vignette.self_modulate.a = danger * (0.5 + 0.25 * sin(_pulse_time * 6.0))
	if _counter_label.visible:
		_counter_label.modulate.a = 0.6 + 0.4 * sin(_pulse_time * 14.0)
	_layout_top()


## Clicking or tabbing away mid-fight pauses it, so nothing hits you while
## you're gone (in the browser this also covers switching tabs).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _can_pause and not get_tree().paused:
		set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	if _can_pause and event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


## "Descend into the Crypt" on the dawn screen, once the Crypt has been found.
func _add_crypt_button() -> void:
	_crypt_button = Button.new()
	_crypt_button.text = "Descend into the Crypt"
	_crypt_button.custom_minimum_size = Vector2(0, 44)
	_crypt_button.add_theme_font_size_override("font_size", 20)
	_crypt_button.add_theme_color_override("font_color", Color(0.8, 0.6, 1.0))
	_crypt_button.visible = false
	var continue_button: Button = %ContinueButton
	continue_button.get_parent().add_child(_crypt_button)
	continue_button.get_parent().move_child(_crypt_button, continue_button.get_index() + 1)
	_crypt_button.pressed.connect(crypt_requested.emit)


## The HUD's look: a beveled knuckle bar with a damage trail and segment
## ticks, and the display face on the big text.
func _style_hud() -> void:
	var fill := UiTheme.box(Color(0.78, 0.12, 0.1), Color(1.0, 0.45, 0.35), 0, 4)
	fill.border_width_top = 3
	_knuckle_bar.add_theme_stylebox_override("fill", fill)
	var back := UiTheme.raised(Color(0.05, 0.02, 0.03, 0.85), Color(0, 0, 0, 0.9), 2, 5, 0.0, 6)
	_knuckle_ghost = ProgressBar.new()
	_knuckle_ghost.show_percentage = false
	_knuckle_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knuckle_ghost.add_theme_stylebox_override("background", back)
	_knuckle_ghost.add_theme_stylebox_override("fill", UiTheme.box(Color(1.0, 0.85, 0.75, 0.75), Color.TRANSPARENT, 0, 4))
	_knuckle_ghost.max_value = _knuckle_bar.max_value
	_knuckle_ghost.value = _knuckle_bar.value
	var bar_parent := _knuckle_bar.get_parent()
	bar_parent.add_child(_knuckle_ghost)
	bar_parent.move_child(_knuckle_ghost, _knuckle_bar.get_index())
	_knuckle_ghost.anchor_left = _knuckle_bar.anchor_left
	_knuckle_ghost.anchor_right = _knuckle_bar.anchor_right
	_knuckle_ghost.anchor_top = _knuckle_bar.anchor_top
	_knuckle_ghost.anchor_bottom = _knuckle_bar.anchor_bottom
	_knuckle_ghost.offset_left = _knuckle_bar.offset_left
	_knuckle_ghost.offset_right = _knuckle_bar.offset_right
	_knuckle_ghost.offset_top = _knuckle_bar.offset_top
	_knuckle_ghost.offset_bottom = _knuckle_bar.offset_bottom
	_knuckle_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	# Ticks every 10 knuckle HP.
	_knuckle_ticks = Control.new()
	_knuckle_ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_knuckle_ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knuckle_bar.add_child(_knuckle_ticks)
	_knuckle_bar.move_child(_knuckle_ticks, 0)
	_knuckle_ticks.draw.connect(func() -> void:
		var steps := int(_knuckle_bar.max_value / 10.0)
		for i in range(1, steps + 1):
			var x := _knuckle_ticks.size.x * (i * 10.0) / maxf(_knuckle_bar.max_value, 1.0)
			_knuckle_ticks.draw_line(Vector2(x, 3), Vector2(x, _knuckle_ticks.size.y - 3), Color(0, 0, 0, 0.35), 2.0))
	for label in [_announcement, _wave_label, _combo_label, _counter_label]:
		label.add_theme_font_override("font", UiTheme.display_font())
	for label in [_knuckle_label, _level_label, _class_label]:
		label.add_theme_font_override("font", UiTheme.bold_font())


## A Settings button in the pause menu, opening the shared settings window.
func _add_settings_button() -> void:
	var button := Button.new()
	button.text = "Settings"
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 20)
	var resume: Button = %ResumeButton
	resume.get_parent().add_child(button)
	resume.get_parent().move_child(button, resume.get_index() + 1)
	button.pressed.connect(func() -> void:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.process_mode = Node.PROCESS_MODE_ALWAYS
		var panel := SettingsPanel.new()
		panel.show_save_data = false
		# The pause card steps aside while Settings is open.
		var menu_card: Control = resume.get_parent().get_parent()
		menu_card.visible = false
		panel.closed.connect(func() -> void:
			menu_card.visible = true
			center.queue_free())
		center.add_child(panel)
		_pause_panel.add_child(center))


## The pause menu's two tabs: the menu itself, and the controls.
var _pause_menu: Control
var _controls_page: VBoxContainer
var _tab_buttons := {}


func _build_pause_tabs() -> void:
	var box: VBoxContainer = %ResumeButton.get_parent()
	box.custom_minimum_size.x = 400
	# Sit the menu on a card. (Reparenting drops the scene owner, which the
	# %UniqueName lookups need, so it's restored after.)
	var center := box.get_parent()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(28.0))
	center.remove_child(box)
	center.add_child(card)
	card.add_child(box)
	for node in [box] + box.find_children("*", "", true, false):
		node.owner = self
	for button in [%ResumeButton, %GiveUpButton]:
		button.custom_minimum_size = Vector2(0, 50)
	var title: Label = box.get_node("Title")
	title.text = "PAUSED"
	title.add_theme_font_override("font", UiTheme.display_font())
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	box.move_child(tabs, title.get_index() + 1)
	var group := ButtonGroup.new()
	for page in ["MENU", "CONTROLS"]:
		var tab := Button.new()
		tab.text = page
		tab.toggle_mode = true
		tab.button_group = group
		tab.theme_type_variation = "TabButton"
		tab.add_theme_font_size_override("font_size", 22)
		tab.pressed.connect(_show_pause_page.bind(page))
		tabs.add_child(tab)
		_tab_buttons[page] = tab
	_pause_menu = box
	_controls_page = VBoxContainer.new()
	_controls_page.add_theme_constant_override("separation", 6)
	box.add_child(_controls_page)
	_show_pause_page("MENU")


func _show_pause_page(page: String) -> void:
	_tab_buttons[page].button_pressed = true
	for child in _pause_menu.get_children():
		if child is Button:
			child.visible = page == "MENU" and child.get_meta("shown", true)
	_controls_page.visible = page == "CONTROLS"
	if page == "CONTROLS":
		show_controls()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_panel.visible = paused
	# The big floor/bout announcement would show through the menu.
	_announcement.visible = not paused
	if _announce_text:
		_announce_text.visible = not paused
	if paused:
		_show_pause_page("MENU")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func set_knuckles(current: float, maximum: float) -> void:
	_knuckle_bar.max_value = maximum
	_knuckle_bar.value = current
	if _knuckle_ghost:
		_knuckle_ghost.max_value = maximum
		# Damage leaves a pale trail that drains after a moment; healing jumps.
		if _ghost_tween:
			_ghost_tween.kill()
		if current >= _knuckle_ghost.value:
			_knuckle_ghost.value = current
		else:
			_ghost_tween = create_tween()
			_ghost_tween.tween_interval(0.35)
			_ghost_tween.tween_property(_knuckle_ghost, "value", current, 0.45).set_trans(Tween.TRANS_QUAD)
		_knuckle_ticks.queue_redraw()
	_knuckle_label.text = "%d / %d" % [ceili(current), roundi(maximum)]
	_knuckle_ratio = current / maximum if maximum > 0.0 else 0.0


func set_combo(count: int, multiplier: float) -> void:
	_combo_label.text = "" if count < 2 else "%d HITS   x%.2f" % [count, multiplier]
	if count < 2:
		return
	# Gets hotter and pops harder the longer the combo runs.
	var heat := clampf((count - 2) / 10.0, 0.0, 1.0)
	_combo_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3).lerp(Color(1, 0.25, 0.1), heat))
	_combo_label.pivot_offset = _combo_label.size / 2
	_combo_label.scale = Vector2.ONE * (1.25 + heat * 0.25)
	if _combo_tween:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Crosshair pops when a punch lands; color shows what kind of hit it was.
func hit_marker(kind: String, killed: bool) -> void:
	var colors := {
		"hit": Color.WHITE,
		"setup": Color(1, 0.55, 0.15),
		"counter": Color(1, 0.8, 0.25),
		"blocked": Color(0.55, 0.55, 0.6),
		"evaded": Color(0.4, 0.7, 1.0),
	}
	_crosshair.color = colors.get(kind, Color.WHITE)
	_crosshair.scale = Vector2.ONE * (4.0 if killed else 2.5)
	_crosshair.rotation = PI / 4 if killed else 0.0
	if _crosshair_tween:
		_crosshair_tween.kill()
	_crosshair_tween = create_tween()
	_crosshair_tween.tween_property(_crosshair, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_crosshair_tween.parallel().tween_property(_crosshair, "rotation", 0.0, 0.18)
	_crosshair_tween.tween_property(_crosshair, "color", Color(1, 1, 1, 0.85), 0.1)


## side is the hand that gets the counter: "left", "right" or "any".
func set_counter_ready(ready: bool, side: String) -> void:
	_counter_label.visible = ready
	if ready:
		_counter_label.text = {"left": "<  COUNTER", "right": "COUNTER  >"}.get(side, "COUNTER!")


## move is a Player.DEFENSES key.
func show_dodge(move: String) -> void:
	flash(Color(0.3, 0.7, 1.0), 0.45)
	if move == "jump":
		announce_small("JUMPED!")
	elif move == "ghost":
		announce_small("GHOST!", Color(0.7, 0.75, 1.0))
	elif move.begins_with("clean_"):
		flash(Color(1.0, 0.85, 0.3), 0.5)
		announce_small("CLEAN " + Player.DEFENSES[move.trim_prefix("clean_")].name + "!", Color(1.0, 0.85, 0.3))
	else:
		announce_small(Player.DEFENSES[move].name + "!")


func show_graze() -> void:
	flash(Color(1.0, 0.55, 0.1), 0.35)
	announce_small("GRAZE", Color(1.0, 0.6, 0.2))


## The passive's readout from the player ("" for nothing to count): shown on
## the passive chip, bottom left, lit gold when it's READY.
func set_class_status(text: String) -> void:
	_class_label.visible = false
	var info := Abilities.info(GameState.player_class, GameState.passive())
	if info.is_empty():
		return
	if _passive_chip == null:
		_build_passive_chip()
	_passive_icon.icon = info.icon
	_passive_name.text = String(info.name).to_upper()
	_passive_value.text = text
	_passive_value.visible = text != ""
	var ready := text == "READY"
	_passive_value.add_theme_color_override("font_color", UiTheme.GOLD if ready else UiTheme.TEXT)
	_passive_icon.color = UiTheme.GOLD if ready else GameState.fighter_color().lightened(0.2)
	if ready and not _passive_ready:
		_passive_chip.pivot_offset = _passive_chip.size / 2.0
		_passive_chip.scale = Vector2.ONE * 1.15
		_passive_chip.create_tween().tween_property(_passive_chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_passive_ready = ready


func _build_passive_chip() -> void:
	_passive_chip = PanelContainer.new()
	_passive_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passive_chip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_passive_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_passive_chip.offset_left = 20.0
	_passive_chip.offset_top = -64.0
	_passive_chip.offset_bottom = -24.0
	_passive_chip.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.03, 0.06, 0.7), Color(GameState.fighter_color(), 0.5), 1, 8, 8.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passive_chip.add_child(row)
	_passive_icon = IconView.new()
	_passive_icon.custom_minimum_size = Vector2(24, 24)
	_passive_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_passive_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_passive_icon)
	_passive_name = _make_label(15, UiTheme.MUTED)
	_passive_name.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(_passive_name)
	_passive_value = _make_label(17, UiTheme.TEXT)
	_passive_value.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(_passive_value)
	add_child(_passive_chip)
	# Under the pause and dawn screens.
	move_child(_passive_chip, mini(_pause_panel.get_index(), _summary_panel.get_index()))


## The selected powers' tiles ([[root, readout, ready, pips], ...] from
## PowerPlay.status; empty hides them). When one goes off the screen edges
## flash its color.
func set_power_status(status: Array) -> void:
	if _power_tiles == null:
		if status.is_empty():
			return
		_power_tiles = PowerTiles.new()
		_power_tiles.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_power_tiles.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_power_tiles.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_power_tiles.offset_right = -24.0
		_power_tiles.offset_bottom = -48.0
		_power_tiles.went_off.connect(func(color: Color) -> void: flash(color, 0.35))
		add_child(_power_tiles)
		move_child(_power_tiles, mini(_pause_panel.get_index(), _summary_panel.get_index()))
	_power_tiles.set_status(status)


func show_class_event(text: String) -> void:
	announce_small(text, Color(1, 0.8, 0.3))


## Replaces the wave readout (used by the training ground).
func set_info(text: String) -> void:
	_wave_label.text = text


func set_leave_text(text: String) -> void:
	%GiveUpButton.text = text


## Normal progression is irrelevant in fixed-kit modes such as Dead League.
func set_progress_visible(show: bool) -> void:
	_progress_shown = show
	_level_label.visible = show
	_xp_bar.visible = show
	_resource_label.visible = false
	for chip in _resource_chips.values():
		chip.visible = show


## A quick, smaller announcement for in-fight moments.
func announce_small(text: String, color := Color(0.45, 0.8, 1.0)) -> void:
	_set_announcement(text, color, 34)
	_announcement.modulate.a = 1.0
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(0.35)
	_announce_tween.tween_property(_announcement, "modulate:a", 0.0, 0.3)


## Bout progress: kills toward the Grave Champion, and how strong new enemies are.
func set_night_progress(title: String, kills: int, needed: int, strength: float, boss_risen: bool) -> void:
	_wave_label.text = title
	_night_bar.max_value = needed
	_night_bar.value = mini(kills, needed)
	_night_bar_label.text = "%d / %d" % [mini(kills, needed), needed]
	_night_bar.visible = not boss_risen


## Lines everything up on one row across the top: the knuckle bar, the
## bout/boss bar and the coins all share TOP_ROW. The info line ("BOUT 3",
## "FLOOR 1") sits in that row when no center bar is up, under it otherwise.
const TOP_ROW := 20.0
const TOP_ROW_HEIGHT := 30.0
var _progress_shown := true


func _layout_top() -> void:
	var bar_up := _night_bar.visible or _boss_bar.visible
	_wave_label.offset_top = TOP_ROW + TOP_ROW_HEIGHT + 4.0 if bar_up else TOP_ROW - 4.0
	_wave_label.offset_bottom = _wave_label.offset_top + 40.0
	_wave_label.add_theme_font_size_override("font_size", 18 if bar_up else 24)


func _place_top_row() -> void:
	# Knuckles end at 300px and the center bar starts 240px left of center, so
	# they keep a gap down to ~1100px wide windows.
	for bar in [_knuckle_bar, _knuckle_ghost]:
		bar.offset_top = TOP_ROW
		bar.offset_bottom = TOP_ROW + TOP_ROW_HEIGHT
		bar.offset_right = 300.0
	_boss_bar.offset_left = -240.0
	_boss_bar.offset_right = 240.0
	_boss_bar.offset_top = TOP_ROW
	_boss_bar.offset_bottom = TOP_ROW + TOP_ROW_HEIGHT
	_boss_name.add_theme_font_override("font", UiTheme.display_font())
	_boss_name.add_theme_font_size_override("font_size", 18)
	_knuckle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_knuckle_label.add_theme_font_size_override("font_size", 16)
	_knuckle_label.visible = true
	# Level and XP: a compact line under the knuckles.
	_level_label.offset_top = TOP_ROW + TOP_ROW_HEIGHT + 4.0
	_level_label.offset_bottom = _level_label.offset_top + 22.0
	_level_label.offset_right = 70.0
	_level_label.add_theme_font_size_override("font_size", 15)
	_xp_bar.offset_left = 70.0
	_xp_bar.offset_right = _knuckle_bar.offset_right
	_xp_bar.offset_top = TOP_ROW + TOP_ROW_HEIGHT + 12.0
	_xp_bar.offset_bottom = _xp_bar.offset_top + 6.0
	_level_label.visible = _progress_shown
	_xp_bar.visible = _progress_shown
	# The class line sits bottom left.
	_class_label.offset_top = -52.0
	_class_label.offset_bottom = -26.0
	_class_label.add_theme_font_size_override("font_size", 17)


func _build_night_bar() -> void:
	_night_bar = ProgressBar.new()
	_night_bar.show_percentage = false
	_night_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_night_bar.offset_left = -240.0
	_night_bar.offset_right = 240.0
	_night_bar.offset_top = TOP_ROW
	_night_bar.offset_bottom = TOP_ROW + TOP_ROW_HEIGHT
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0, 0, 0, 0.55)
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.55, 0.3, 0.85)
	fill.set_corner_radius_all(4)
	_night_bar.add_theme_stylebox_override("background", background)
	_night_bar.add_theme_stylebox_override("fill", fill)
	add_child(_night_bar)
	_night_bar_label = Label.new()
	_night_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_night_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_night_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_night_bar_label.add_theme_font_size_override("font_size", 16)
	_night_bar_label.add_theme_font_override("font", UiTheme.display_font())
	_night_bar_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_night_bar_label.add_theme_constant_override("outline_size", 5)
	_night_bar.add_child(_night_bar_label)
	_night_bar.visible = false


func show_boss(boss_name: String, current: float, maximum: float) -> void:
	_boss_name.text = boss_name
	_boss_bar.visible = true
	_night_bar.visible = false
	set_boss_health(current, maximum)


func set_boss_health(current: float, maximum: float) -> void:
	_boss_bar.max_value = maximum
	_boss_bar.value = current


func hide_boss() -> void:
	_boss_bar.visible = false


## Big text in the middle of the screen that fades out.
func announce(text: String) -> void:
	_set_announcement(text, Color(0.9, 0.25, 0.2), 48)
	_announcement.modulate.a = 1.0
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.5)
	_announce_tween.tween_property(_announcement, "modulate:a", 0.0, 0.8)


## The announcement's text lives in an IconLabel inside it, so rewards can
## show their icons ("+40 {coins}").
func _set_announcement(text: String, color: Color, font_size: int) -> void:
	if _announce_text == null:
		_announce_text = IconLabel.new()
		_announce_text.font = UiTheme.display_font()
		_announce_text.outline = 10
		_announce_text.alignment = BoxContainer.ALIGNMENT_CENTER
		_announce_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_announcement.add_child(_announce_text)
	_announcement.text = ""
	_announce_text.font_size = font_size
	_announce_text.color = color
	_announce_text.text = text


func _build_knockout_cover() -> void:
	_ko_cover = ColorRect.new()
	_ko_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ko_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ko_cover.color = Color(0, 0, 0, 0)
	_ko_cover.hide()
	add_child(_ko_cover)
	# Under the summary and pause screens, over everything else.
	move_child(_ko_cover, _pause_panel.get_index())
	# Rich text, so censored words can sit under a black bleep bar.
	_speech = RichTextLabel.new()
	_speech.bbcode_enabled = true
	_speech.fit_content = true
	_speech.scroll_active = false
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_theme_font_size_override("normal_font_size", 26)
	_speech.add_theme_color_override("font_outline_color", Color.BLACK)
	_speech.add_theme_constant_override("outline_size", 6)
	_speech.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_speech.offset_left = -460
	_speech.offset_right = 460
	_speech.offset_top = 110
	_speech.modulate.a = 0.0
	add_child(_speech)
	move_child(_speech, _ko_cover.get_index())


## The screen during a knockout: a red tint as you go down, then black.
## Matches Player.KNOCKOUT_TIME.
func knockout_fade() -> void:
	_can_pause = false
	_set_ult_visible(false)
	hide_boss()
	_combo_label.text = ""
	_knuckle_ratio = 1.0  # The low-health throb stops; the fade takes over.
	_ko_cover.show()
	_ko_cover.color = Color(0.55, 0.0, 0.02, 0.0)
	var tween := _ko_cover.create_tween()
	tween.tween_property(_ko_cover, "color", Color(0.55, 0.0, 0.02, 0.2), 0.5)
	tween.tween_interval(0.9)
	tween.tween_property(_ko_cover, "color", Color(0.0, 0.0, 0.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## Someone speaking, big across the top: a boss's taunt or last words.
func say(speaker: String, line: String, color := Color.WHITE, hold := 3.5) -> void:
	var body := line.replace("[", "(").replace("]", ")")
	# Grawlix: a black bleep bar with the symbols in yellow.
	var regex := RegEx.new()
	regex.compile("[*^%#@$&]+[*^%#@$&!]*")
	var shown := ""
	var last := 0
	for found in regex.search_all(body):
		shown += body.substr(last, found.get_start() - last)
		shown += "[bgcolor=#000000][color=#ffd34d]%s[/color][/bgcolor]" % found.get_string()
		last = found.get_end()
	shown += body.substr(last)
	_speech.text = "[center][color=#%s]%s%s[/color][/center]" % [color.to_html(false), ("%s:  " % speaker) if speaker != "" else "", shown]
	if _speech_tween:
		_speech_tween.kill()
	_speech_tween = _speech.create_tween()
	_speech_tween.tween_property(_speech, "modulate:a", 1.0, 0.25)
	_speech_tween.tween_interval(hold)
	_speech_tween.tween_property(_speech, "modulate:a", 0.0, 0.6)


func flash_damage() -> void:
	flash(Color(0.8, 0.05, 0.05), 0.6)


## Colored flash around the screen edges that fades out.
func flash(color: Color, strength: float) -> void:
	color.a = strength
	_damage_flash.self_modulate = color
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "self_modulate:a", 0.0, 0.45)


## A line in the kill feed; resource tokens like {coins} show as icons.
func add_feed(text: String, color := Color.WHITE) -> void:
	var label := IconLabel.new()
	label.font_size = 20
	label.outline = 6
	label.color = color
	label.alignment_h = BoxContainer.ALIGNMENT_BEGIN
	label.text = text
	_feed.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


## Dawn screen after a boss: pauses the game and offers to continue into the
## next night or go back to camp.
## crypt: also offer to go straight down into the Crypt.
func show_night_cleared(title: String, details: String, continue_text: String, crypt := false) -> void:
	show_summary(title, details)
	get_tree().paused = true
	%ContinueButton.text = continue_text
	%ContinueButton.visible = true
	%CampButton.text = "Return to camp"
	_crypt_button.visible = crypt


## Closes the dawn screen and goes back to fighting.
func resume_after_summary() -> void:
	_summary_panel.hide()
	_ko_cover.hide()
	_set_fight_ui(true)
	%ContinueButton.visible = false
	_crypt_button.visible = false
	_set_ult_visible(true)
	%CampButton.text = "Back to camp"
	_can_pause = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func show_summary(title: String, details: String) -> void:
	%ContinueButton.visible = false
	if _crypt_button:
		_crypt_button.visible = false
	_set_ult_visible(false)
	_can_pause = false
	get_tree().paused = false
	_pause_panel.hide()
	_combo_label.text = ""
	_summary_title.text = title
	if _summary_text == null:
		_summary_text = IconLabel.new()
		_summary_text.font_size = 20
		_summary_text.outline = 4
		_summary_details.get_parent().add_child(_summary_text)
		_summary_details.get_parent().move_child(_summary_text, _summary_details.get_index() + 1)
		_summary_details.visible = false
	_summary_text.text = details
	_summary_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The results card after a bout or a run: a big title, a stamped grade,
## medals that light up, and rewards that count up. data:
##   title, title_color, subtitle, grade, grade_color,
##   medals: [[label, earned]], rewards: {resource id: amount}, note, note_color.
## continue_text shows the Continue button and pauses (bout and floor wins).
var _results: VBoxContainer
## The fight's own readouts, hidden while a results card is up.
var _fight_ui: Array[Control] = []
var _night_bar_shown := false


func _set_fight_ui(on: bool) -> void:
	_level_label.visible = on and _progress_shown
	_xp_bar.visible = on and _progress_shown
	for node in _fight_ui + [_knuckle_bar, _knuckle_ghost, _knuckle_ticks, _wave_label, _feed, _counter_label, _speech]:
		if is_instance_valid(node):
			node.visible = on
	if on:
		_night_bar.visible = _night_bar_shown
	else:
		_night_bar_shown = _night_bar.visible
		_night_bar.visible = false
		hide_boss()


func show_results(data: Dictionary, continue_text := "", crypt := false, camp_text := "Return to camp") -> void:
	show_summary(data.title, "")
	_set_fight_ui(false)
	_summary_text.visible = false
	_summary_title.add_theme_font_override("font", UiTheme.display_font())
	_summary_title.add_theme_font_size_override("font_size", 68)
	_summary_title.add_theme_color_override("font_color", data.get("title_color", UiTheme.GOLD))
	_summary_title.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02))
	_summary_title.add_theme_constant_override("outline_size", 12)
	if _results:
		_results.queue_free()
	_results = VBoxContainer.new()
	_results.add_theme_constant_override("separation", 12)
	_results.alignment = BoxContainer.ALIGNMENT_CENTER
	var box := _summary_title.get_parent()
	box.add_child(_results)
	box.move_child(_results, _summary_title.get_index() + 1)
	var delay := 0.25
	if data.get("subtitle", "") != "":
		var subtitle := _results_label(data.subtitle, 24, UiTheme.MUTED)
		_results.add_child(subtitle)
	if data.get("grade", "") != "":
		var grade := UiTheme.title_label(data.grade, 104, data.get("grade_color", _grade_color(data.grade)))
		grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_results.add_child(grade)
		_stamp(grade, delay)
		delay += 0.45
	var medals: Array = data.get("medals", [])
	if not medals.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		_results.add_child(row)
		for medal in medals:
			var pill := _medal(medal[0], medal[1])
			row.add_child(pill)
			_pop(pill, delay, medal[1])
			delay += 0.12
	var rewards: Dictionary = data.get("rewards", {})
	if not rewards.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		_results.add_child(row)
		for id in rewards:
			var chip := ResourceChip.make(id, 36.0, 28)
			row.add_child(chip)
			chip.set_amount(0, false)
			var amount := int(rewards[id])
			var count := create_tween()
			count.tween_interval(delay)
			count.tween_callback(func() -> void:
				chip.set_amount(amount, true)
				if amount > 0:
					Sfx.play("coin"))
			delay += 0.15
	if data.get("note", "") != "":
		var note := _results_label(data.note, 24, data.get("note_color", UiTheme.GOLD))
		_results.add_child(note)
		_pop(note, delay + 0.2, false)
	if continue_text != "":
		get_tree().paused = true
		%ContinueButton.text = continue_text
		%ContinueButton.visible = true
		%ContinueButton.theme_type_variation = "PrimaryButton"
		_crypt_button.visible = crypt
	%CampButton.text = camp_text
	for button in [%ContinueButton, _crypt_button, %CampButton]:
		button.custom_minimum_size.x = 340
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _results_label(text: String, size: int, color: Color) -> Label:
	var label := UiTheme.title_label(text, size, color)
	label.remove_theme_font_override("font")
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 680
	return label


func _grade_color(grade: String) -> Color:
	if grade.begins_with("S"):
		return Color(1.0, 0.82, 0.3)
	return {"A": Color(0.55, 0.95, 0.6), "B": Color(0.5, 0.8, 1.0), "C": Color(0.85, 0.85, 0.9)}.get(grade, Color(0.95, 0.5, 0.45))


func _medal(text: String, earned: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	var color := UiTheme.GOLD if earned else UiTheme.BORDER
	var style := UiTheme.box(Color(color, 0.18 if earned else 0.25), Color(color, 0.9 if earned else 0.6), 2, 18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", UiTheme.GOLD.lightened(0.3) if earned else UiTheme.MUTED.darkened(0.2))
	pill.add_child(label)
	return pill


## The grade slams down onto the card.
func _stamp(node: Control, delay: float) -> void:
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		node.pivot_offset = node.size / 2.0
		node.scale = Vector2(2.6, 2.6))
	tween.tween_property(node, "modulate:a", 1.0, 0.12)
	tween.parallel().tween_property(node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Sfx.play("heavy", 2.0, 0.8)
		flash(Color(1, 0.9, 0.6), 0.25))


func _pop(node: Control, delay: float, ding: bool) -> void:
	node.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		node.pivot_offset = node.size / 2.0
		node.scale = Vector2(1.3, 1.3)
		if ding:
			Sfx.play("tick", 0.0, 1.4))
	tween.tween_property(node, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_give_up_pressed() -> void:
	set_paused(false)
	end_run_requested.emit()


func _refresh_progress() -> void:
	_level_label.text = "LV %d" % GameState.level
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	if _resource_chips.has("coins"):
		_resource_chips.coins.set_amount(GameState.resources.get("coins", 0), _resources_shown)
		_resources_shown = true


func _build_resource_row() -> void:
	_resource_label.visible = false
	var row := HBoxContainer.new()
	_fight_ui.append(row)
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -400.0
	row.offset_right = -20.0
	row.offset_top = TOP_ROW - 1.0
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for id in ["souls", "silver", "coins"]:
		var chip := ResourceChip.make(id, 28.0, 21)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.visible = id == "coins"
		row.add_child(chip)
		_resource_chips[id] = chip


## Crypt runs: your Souls (spent on gilding at the altars) beside the silver,
## kept up to date as bosses drop them.
func show_souls() -> void:
	var chip: ResourceChip = _resource_chips.souls
	if chip.visible:
		return
	chip.visible = true
	chip.set_amount(GameState.souls, false)
	var update := func() -> void: chip.set_amount(GameState.souls, true)
	GameState.changed.connect(update)
	tree_exiting.connect(func() -> void: GameState.changed.disconnect(update))


## Crypt runs: shows the run's silver next to the coins.
func set_silver(amount: int) -> void:
	var chip: ResourceChip = _resource_chips.silver
	var first := not chip.visible
	chip.visible = true
	chip.set_amount(amount, not first)


## The pause menu's Controls tab (no hint bar in the fight itself).
func show_controls() -> void:
	_controls_label.visible = false
	if _controls_page == null:
		return
	for child in _controls_page.get_children():
		child.queue_free()
	for row in Controls.rows():
		var line := HBoxContainer.new()
		var what := Label.new()
		what.text = row[0]
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.add_theme_font_size_override("font_size", 19)
		what.add_theme_color_override("font_color", UiTheme.MUTED)
		line.add_child(what)
		var keys := Label.new()
		keys.text = row[1]
		keys.add_theme_font_override("font", UiTheme.bold_font())
		keys.add_theme_font_size_override("font_size", 19)
		line.add_child(keys)
		_controls_page.add_child(line)


# --- Crypt: prompts, equipment and found items -------------------------------

func set_prompt(text: String) -> void:
	_prompt.text = ""
	_prompt_text.text = text
	_prompt.visible = text != ""


## Puts the Crypt minimap in the top-right corner, with the worn items below it.
func add_minimap(map: Control) -> void:
	add_child(map)
	move_child(map, _item_panel.get_parent().get_index())  # Under item panels.
	_fight_ui.append(map)
	_equipment_box.offset_top = 270.0


## Lists the worn items {slot: item} along the right side.
func set_equipment(equipped: Dictionary) -> void:
	_equipment_box.visible = false
	for child in _equipment_box.get_children():
		child.queue_free()
	for slot in Items.SLOTS:
		if not equipped.has(slot):
			continue
		var item: Dictionary = equipped[slot]
		var mark := ""
		if item.get("found", false):
			mark = "  [GILDED]" if item.get("gilded", false) else "  [bound]"
		var line := _outlined_label("%s: %s%s" % [Items.SLOT_NAMES[slot], item.name, mark], 14)
		line.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if item.get("gilded", false) else Items.rarity_color(item))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_equipment_box.add_child(line)
	for blessing in GameState.blessings:
		var line := _outlined_label(blessing.name, 14)
		line.add_theme_color_override("font_color", Items.rarity_color(blessing))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_equipment_box.add_child(line)


## Pauses and shows a found item next to what's worn in its slot, with
## Equip / Salvage buttons (or custom ones: Buy / Leave it, Accept ...).
## Emits item_decided.
func show_item_offer(item: Dictionary, current: Dictionary, salvage_coins: int, accept_text := "", decline_text := "", accept_enabled := true) -> void:
	for child in _item_panel.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_item_panel.add_child(column)
	column.add_child(UiTheme.heading("YOU FOUND", 34))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	cards.add_child(_item_card(item, "NEW", current))
	if not current.is_empty():
		cards.add_child(_item_card(current, "WORN NOW"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	var equip := Button.new()
	equip.disabled = not accept_enabled
	IconLabel.on_button(equip, accept_text if accept_text != "" else "Equip" if current.is_empty() else "Swap")
	equip.custom_minimum_size = Vector2(200, 46)
	equip.pressed.connect(_decide_item.bind(true))
	buttons.add_child(equip)
	var salvage := Button.new()
	IconLabel.on_button(salvage, decline_text if decline_text != "" else "Salvage   +%d {coins}" % salvage_coins)
	salvage.custom_minimum_size = Vector2(200, 46)
	salvage.pressed.connect(_decide_item.bind(false))
	buttons.add_child(salvage)
	_can_pause = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_item_panel.show()


## A Crypt altar: each worn find with its price to gild. entries:
## [{item, souls, silver, gilded, affordable}].
func show_gild_menu(entries: Array, silver: int) -> void:
	for child in _item_panel.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_item_panel.add_child(column)
	column.add_child(UiTheme.heading("GILDING ALTAR", 34))
	var rules := IconLabel.new()
	rules.font_size = 15
	rules.text = "%d {souls}     %d {silver}" % [GameState.souls, silver]
	column.add_child(rules)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	for entry in entries:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(_item_card(entry.item, "GILDED" if entry.gilded else "BOUND"))
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 42)
		button.disabled = entry.gilded or not entry.affordable
		IconLabel.on_button(button, "Gilded" if entry.gilded else "Gild   %d {souls}  %d {silver}" % [entry.souls, entry.silver])
		var item: Dictionary = entry.item
		button.pressed.connect(func() -> void: gild_chosen.emit(item))
		box.add_child(button)
		cards.add_child(box)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(200, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func() -> void:
		_item_panel.hide()
		_can_pause = true
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	column.add_child(done)
	_can_pause = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_item_panel.show()


## The Crypt merchant's table. wares: [{item, price, sold}]; heal: {price,
## percent, used}. Each card has its price; Done closes it.
func show_merchant(wares: Array, heal: Dictionary, silver: int) -> void:
	for child in _item_panel.get_children():
		child.queue_free()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_item_panel.add_child(column)
	column.add_child(UiTheme.heading("MERCHANT", 34))
	var purse := IconLabel.new()
	purse.font_size = 16
	purse.text = "%d {silver}" % silver
	column.add_child(purse)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	for i in wares.size():
		var ware: Dictionary = wares[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.add_child(_item_card(ware.item, "SOLD" if ware.sold else "FOR SALE", GameState.equipped.get(ware.item.slot, {})))
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(0, 42)
		buy.disabled = ware.sold or silver < int(ware.price)
		IconLabel.on_button(buy, "Sold" if ware.sold else "Buy   %d {silver}" % ware.price)
		buy.pressed.connect(func() -> void: ware_chosen.emit(i))
		box.add_child(buy)
		cards.add_child(box)
	var kit := VBoxContainer.new()
	kit.add_theme_constant_override("separation", 6)
	var flask := PanelContainer.new()
	flask.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.08, 0.1, 0.95), Color(0.9, 0.25, 0.25), 2, 8, 14.0))
	flask.custom_minimum_size = Vector2(170, 0)
	flask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	flask.add_child(lines)
	lines.add_child(UiTheme.title_label("PATCH UP", 22, Color(1.0, 0.45, 0.4)))
	var restore := IconLabel.new()
	restore.font_size = 16
	restore.text = "+%d%% {knuckles}" % heal.percent
	lines.add_child(restore)
	kit.add_child(flask)
	var patch_up := Button.new()
	patch_up.custom_minimum_size = Vector2(0, 42)
	patch_up.disabled = heal.used or silver < int(heal.price)
	IconLabel.on_button(patch_up, "Used" if heal.used else "Buy   %d {silver}" % heal.price)
	patch_up.pressed.connect(func() -> void: ware_chosen.emit(-1))
	kit.add_child(patch_up)
	cards.add_child(kit)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size = Vector2(200, 44)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func() -> void:
		_item_panel.hide()
		_can_pause = true
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	column.add_child(done)
	_can_pause = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_item_panel.show()


func _decide_item(equip: bool) -> void:
	_item_panel.hide()
	_can_pause = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	item_decided.emit(equip)


## compare: the worn item to color the lines against (green = better, red =
## worse, gold = special).
func _item_card(item: Dictionary, tag: String, compare := {}) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = Items.rarity_color(item)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var tag_label := _outlined_label(tag, 12)
	tag_label.modulate = Color(1, 1, 1, 0.6)
	box.add_child(tag_label)
	var name_label := _outlined_label(item.name, 22)
	name_label.add_theme_color_override("font_color", Items.rarity_color(item))
	box.add_child(name_label)
	var kind := _outlined_label(Items.kind_text(item), 14)
	kind.modulate = Color(1, 1, 1, 0.75)
	box.add_child(kind)
	var worn: Dictionary = compare.get("effects", {})
	for entry in Items.effect_entries(item):
		var line := _outlined_label(entry[0], 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var effect: String = entry[1]
		if Items.is_special(effect):
			line.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		elif not compare.is_empty():
			var mine: float = item.effects[effect]
			var theirs: float = worn.get(effect, 0.0)
			if mine > theirs + 0.001:
				line.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
			elif mine < theirs - 0.001:
				line.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		box.add_child(line)
	# What the worn item has that this one would lose.
	for effect in worn:
		if not item.effects.has(effect):
			var lost := _outlined_label("Lose: " + GameState.effect_text({effect: worn[effect]}, 1), 14)
			lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lost.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 0.85))
			box.add_child(lost)
	return card


func _build_crypt_ui() -> void:
	_prompt = _outlined_label("", 20)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.offset_top = -196.0
	_prompt.offset_bottom = -164.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_prompt.visible = false
	add_child(_prompt)
	_prompt_text = IconLabel.new()
	_prompt_text.font_size = 20
	_prompt_text.color = Color(1.0, 0.9, 0.6)
	_prompt_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prompt.add_child(_prompt_text)

	_equipment_box = VBoxContainer.new()
	_equipment_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_equipment_box.offset_left = -360.0
	_equipment_box.offset_right = -20.0
	_equipment_box.offset_top = 70.0
	_equipment_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_equipment_box)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_item_panel = PanelContainer.new()
	_item_panel.add_theme_stylebox_override("panel", UiTheme.card(24.0))
	center.add_child(_item_panel)
	_item_panel.hide()


func _outlined_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Side panel of option lists with the current choice in each marked (training).
## Each section is [title, entries, current (1-based)].
func show_level_panel(sections: Array) -> void:
	var lines: Array[String] = []
	for section in sections:
		if not lines.is_empty():
			lines.append("")
		lines.append(section[0])
		var entries: Array = section[1]
		for i in entries.size():
			var marker := ">" if i + 1 == section[2] else "  "
			lines.append("%s %d  %s" % [marker, i + 1, entries[i]])
	_level_panel.text = "\n".join(lines)
	_level_panel.visible = true


# --- Ultimate -----------------------------------------------------------------------

## Builds the ultimate meter (bottom center) and the Temporal Break overlay, and
## listens to the player's ultimate.
func bind_ult(ult: Ult) -> void:
	_ult_label = _make_label(20, Color(0.85, 0.85, 0.9))
	_ult_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ult_label.offset_left = -300.0
	_ult_label.offset_right = 300.0
	_ult_label.offset_top = -146.0
	_ult_label.offset_bottom = -118.0
	add_child(_ult_label)
	_ult_bar = ProgressBar.new()
	_ult_bar.show_percentage = false
	_ult_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ult_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_bar.offset_left = -170.0
	_ult_bar.offset_right = 170.0
	_ult_bar.offset_top = -114.0
	_ult_bar.offset_bottom = -100.0
	_ult_bar.max_value = Ult.MAX_METER
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	back.set_corner_radius_all(4)
	back.border_color = Color(0, 0, 0, 0.8)
	back.set_border_width_all(1)
	_ult_fill = StyleBoxFlat.new()
	_ult_fill.set_corner_radius_all(4)
	_ult_bar.add_theme_stylebox_override("background", back)
	_ult_bar.add_theme_stylebox_override("fill", _ult_fill)
	add_child(_ult_bar)
	_ult_label.visible = false
	_ult_bar.visible = false
	_ult_gauge = UltGauge.new()
	_ult_gauge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_ult_gauge.offset_left = -210.0
	_ult_gauge.offset_right = 210.0
	_ult_gauge.offset_top = -132.0
	_ult_gauge.offset_bottom = -68.0
	_ult_gauge.color = GameState.fighter_color().lightened(0.1)
	add_child(_ult_gauge)
	# Under the pause and dawn screens, not on top of their buttons.
	var below := mini(_pause_panel.get_index(), _summary_panel.get_index())
	move_child(_ult_label, below)
	move_child(_ult_bar, below + 1)
	move_child(_ult_gauge, below + 2)
	_build_time_stop()
	_ult_name = Ult.equipped_name()
	ult.spoke.connect(func(line: String) -> void: say("TONY", line, GameState.fighter_color("wise_guy").lightened(0.2), 2.4))
	ult.meter_changed.connect(_set_ult_meter)
	ult.status_changed.connect(_set_ult_status)
	ult.time_stop_changed.connect(_show_time_stop)
	_set_ult_meter(ult.meter, ult.is_full())


func _set_ult_visible(on: bool) -> void:
	if _ult_gauge:
		_ult_gauge.visible = on


func _set_ult_meter(value: float, ready: bool) -> void:
	_ult_bar.value = value
	_ult_gauge.value = value / Ult.MAX_METER * 100.0
	_ult_gauge.full = ready
	_ult_ready = ready
	_ult_fill.bg_color = Color(1.0, 0.75, 0.2) if ready else Color(0.55, 0.45, 0.85)
	_refresh_ult_label()


func _set_ult_status(text: String) -> void:
	_ult_status = text
	_refresh_ult_label()


func _refresh_ult_label() -> void:
	_ult_gauge.title = _ult_name
	_ult_gauge.status = _ult_status
	_ult_gauge.key = Controls.text("ultimate")
	if _ult_status != "":
		_ult_label.text = _ult_status
		_ult_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	elif _ult_ready:
		_ult_label.text = "%s   [%s]" % [_ult_name, Controls.text("ultimate")]
		_ult_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		_ult_label.text = ""
		_ult_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.88))


func _build_time_stop() -> void:
	_time_stop = Control.new()
	_time_stop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_stop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_stop.visible = false
	add_child(_time_stop)
	move_child(_time_stop, 0)
	# The world drains to a cold grey, darkest at the edges.
	_time_tint = ColorRect.new()
	_time_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_time_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = TIME_STOP_SHADER
	var tint_material := ShaderMaterial.new()
	tint_material.shader = shader
	_time_tint.material = tint_material
	_time_stop.add_child(_time_tint)
	_time_clock = Control.new()
	_time_clock.set_anchors_preset(Control.PRESET_CENTER)
	_time_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_clock.position.y -= 170.0
	_time_clock.draw.connect(_draw_time_clock)
	_time_stop.add_child(_time_clock)
	_time_keys = _make_label(46, Color(1.0, 0.9, 0.4))
	_time_name = _make_label(24, Color(0.9, 0.92, 1.0))
	_time_hits = _make_label(30, Color(1.0, 0.6, 0.25))
	for entry in [[_time_keys, 90.0], [_time_name, 146.0], [_time_hits, -290.0]]:
		var label: Label = entry[0]
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.offset_left = -300.0
		label.offset_right = 300.0
		label.offset_top = entry[1]
		label.offset_bottom = entry[1] + 50.0
		_time_stop.add_child(label)


const TIME_STOP_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount = 1.0;
void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 cold = vec3(grey * 0.82, grey * 0.94, grey * 1.18);
	float edge = smoothstep(0.3, 0.75, length(UV - 0.5));
	// Glows keep their color (the hand to punch next, the frozen sparks).
	float glow = smoothstep(0.7, 0.95, max(color.r, max(color.g, color.b))) * smoothstep(0.15, 0.4, max(color.r, max(color.g, color.b)) - min(color.r, min(color.g, color.b)));
	color = mix(color, cold, amount * 0.9 * (1.0 - glow));
	color = mix(color, vec3(0.03, 0.06, 0.18), edge * 0.55 * amount);
	COLOR = vec4(color, 1.0);
}
"""


func _show_time_stop(running: bool, fraction: float, keys: String, punch_name: String, hits: int) -> void:
	var tint := _time_tint.material as ShaderMaterial
	if running and not _time_stop.visible:
		# The color drains out over a moment.
		tint.set_shader_parameter("amount", 0.0)
		create_tween().tween_method(func(v: float) -> void: tint.set_shader_parameter("amount", v), 0.0, 1.0, 0.3)
	elif not running and _time_stop.visible:
		# Time snaps back: a white flash.
		var flash := ColorRect.new()
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.color = Color(0.9, 0.95, 1.0, 0.6)
		add_child(flash)
		var fade := flash.create_tween()
		fade.tween_property(flash, "color:a", 0.0, 0.35)
		fade.tween_callback(flash.queue_free)
	_time_stop.visible = running
	if not running:
		return
	_time_fraction = fraction
	_time_keys.text = keys
	_time_name.text = punch_name
	_time_hits.text = ("%d HIT" % hits + ("" if hits == 1 else "S")) if hits > 0 else "TEMPORAL BREAK"
	_time_clock.queue_redraw()


## A ring that empties clockwise as Temporal Break runs out, red when nearly gone.
func _draw_time_clock() -> void:
	var radius := 54.0
	_time_clock.draw_circle(Vector2.ZERO, radius + 8.0, Color(0.03, 0.03, 0.08, 0.7))
	_time_clock.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1, 1, 1, 0.15), 10.0, true)
	var color := Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.2, 0.15), clampf(1.0 - _time_fraction * 2.0, 0.0, 1.0))
	_time_clock.draw_arc(Vector2.ZERO, radius, -PI / 2.0, -PI / 2.0 + TAU * _time_fraction, 64, color, 10.0, true)


func _make_label(font_size: int, color: Color) -> Label:
	var label := _outlined_label("", font_size)
	label.add_theme_color_override("font_color", color)
	return label
