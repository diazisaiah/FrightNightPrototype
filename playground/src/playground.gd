extends "res://training.gd"
## The Playground (its own Godot project, synced from the game by
## playground/sync.py): the training ring with a dev panel for trying things
## fast. Fighters, hats, every emote, any enemy (veterans, bosses, the Dead
## League contenders) at any tier, forced special moves, powers, themes, god
## mode, frozen enemies and replaying the tips. F1 shows / hides the panel.
## It runs on its own save (the project has its own name, so its own user
## folder), never the game's.

const BASE := {
	"zombie": "res://zombie.tscn", "skeleton": "res://skeleton.tscn", "runner": "res://runner.tscn",
	"hulk": "res://hulk.tscn", "brawler": "res://brawler.tscn", "mage": "res://mage.tscn",
	"priest": "res://priest.tscn", "armor": "res://possessed_armor.tscn", "shieldbearer": "res://shieldbearer.tscn",
	"wraith": "res://wraith.tscn", "lich": "res://lich.tscn",
	"grave champion (boss)": "res://boss.tscn", "bone colossus (boss)": "res://colossus.tscn", "lich king (boss)": "res://lich_king.tscn",
}
const SPECIALS := ["leap_slam", "ground_slam", "charge", "dash", "zones", "miasma", "scream"]
const POWERS := ["", "sigil_fire", "sigil_frost", "sigil_storm", "sigil_blood", "sigil_quake", "sigil_gale", "sigil_iron", "sigil_doom"]
const CharacterLabScript = preload("res://playground/character_lab/character_lab_controller.gd")

static var _resume_lab_mode := ""

var _panel: Control
var _enemy_pick: OptionButton
var _tier := 1
## Spawned monsters' rank: "normal", "elite" or "champion".
var _rank := "normal"
var _god := true
var _frozen := false
var _theme_node: Node3D
## Hand idles: the last one clicked, replayed while Loop is on.
var _idle_pick := ""
var _idle_loop := false
## The training ring (ropes, canvas and the walls that hold the player in) and
## whether it's up. Off, you roam free like the enemies do.
var _ring: Node3D
var _ring_on := true
var _lab: PlaygroundCharacterLab
var _lab_status: Label
var _freeze_check: CheckBox
var _god_check: CheckBox
var _power_label: Label
## Upgrade tiers to test at: none, each contender's par build, everything.
const UPGRADE_TIERS := ["Fresh", "Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5", "Maxed"]
## Hotkeys (shown in the panel).
const HOTKEYS := "F1 panel   V third person   G god mode   K spawn   C clear   F freeze   U fill ultimate"


func _ready() -> void:
	# Everything unlocked, nothing interrupting.
	GameState.tutorial_done = true
	GameState.true_king_bout = false
	for id in Achievements.LIST:
		GameState.achievements[id] = true
	for tip in ["hat_first", "hat_rack", "hat_rack_tour", "power_select"]:
		GameState.tips_seen[tip] = true
	for id in IdleAnims.SHOP:
		GameState.idles_bought[id] = true
	for id in Skins.CATALOG:
		GameState.skins_owned[id] = true
	Enemy.max_attackers = 2
	$Moon.shadow_enabled = Settings.get_value("shadows")
	Look.tune_environment($WorldEnvironment.environment, "ring")
	_build_torches()
	_build_ring()
	_ring = $Decorations.get_child($Decorations.get_child_count() - 1)
	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.power_status_changed.connect(_hud.set_power_status)
	_player.class_event.connect(_hud.show_class_event)
	_player.knuckles_broken.connect(_player.restore)
	_hud.end_run_requested.connect(func() -> void: get_tree().quit())
	_hud.set_leave_text("Quit the playground")
	_hud.set_info("PLAYGROUND  ·  F1 panel")
	_set_god(true)
	_lab = CharacterLabScript.new()
	_lab.name = "CharacterLab"
	add_child(_lab)
	_lab.initialize(_player, _hud)
	_build_panel()
	if _resume_lab_mode != "":
		_lab.set_mode(_resume_lab_mode)
		_resume_lab_mode = ""
	Sfx.play_music("camp")


func _process(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25
	if _god:
		_player.knuckles = _player.max_knuckles
	if _idle_loop and _idle_pick != "" and not _player._fists.idle_playing:
		_player._fists.play_idle(_idle_pick)
	if _lab_status and _lab:
		_lab_status.text = _lab.status_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_panel.visible = not _panel.visible
		if not _panel.visible and _lab:
			_lab.finish_hand_preview()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panel.visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
		_lab.toggle_third_person()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and _hotkey(event.physical_keycode):
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_TOUCHPAD, JOY_BUTTON_MISC1]:
		# These buttons are intentionally absent from the production control map.
		# Controllers that do not expose either can use the panel's mode selector.
		_lab.toggle_third_person()
		get_viewport().set_input_as_handled()
	elif _lab and _lab.handle_input(event):
		get_viewport().set_input_as_handled()


## The quick keys (HOTKEYS); true if it was one.
func _hotkey(key: Key) -> bool:
	match key:
		KEY_G:
			_god_check.button_pressed = not _god_check.button_pressed
			_hud.announce_small("God mode " + ("on" if _god else "off"), UiTheme.GOLD)
		KEY_K:
			_spawn(1)
		KEY_C:
			_clear()
		KEY_F:
			_freeze_check.button_pressed = not _freeze_check.button_pressed
			_hud.announce_small("Enemies " + ("frozen" if _frozen else "moving"), UiTheme.GOLD)
		KEY_U:
			_player.ult.fill()
		_:
			return false
	return true


# --- The panel ---------------------------------------------------------------------

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.raised(Color(UiTheme.PANEL, 0.94), UiTheme.GOLD, 2, 10, 12.0))
	_panel.position = Vector2(12, 90)
	# As tall as the window allows.
	var tall := maxf(get_viewport().get_visible_rect().size.y - 110.0, 360.0)
	_panel.custom_minimum_size = Vector2(330, tall)
	layer.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(320, tall - 10.0)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UiTheme.title_label("PLAYGROUND", 24, UiTheme.GOLD))
	box.add_child(_note("F1 hides this. Click the ring to fight. Click a heading to fold it."))
	var keys := _note(HOTKEYS)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 300
	box.add_child(keys)

	_section(box, "FIGHTER")
	var fighters := _options(GameState.CLASSES.keys(), GameState.player_class, _switch_fighter)
	box.add_child(fighters)
	var skins: Array = [""] + Skins.of(GameState.player_class)
	box.add_child(_options(skins, GameState.skin(), _switch_skin))

	_section(box, "UPGRADES (test at a power level)")
	var tiers := GridContainer.new()
	tiers.columns = 4
	box.add_child(tiers)
	for i in UPGRADE_TIERS.size():
		tiers.add_child(_button(UPGRADE_TIERS[i], func() -> void: _set_upgrade_tier(i)))
	_power_label = _note("POWER %d" % PowerRating.player())
	box.add_child(_power_label)

	_section(box, "PASSIVE")
	box.add_child(_ability_options("passive"))
	_section(box, "ULTIMATE")
	box.add_child(_ability_options("ultimate"))

	_section(box, "HAT")
	var hats: Array = [""] + Hats.CATALOG.keys()
	box.add_child(_options(hats, GameState.worn_hat, func(id: String) -> void:
		if id != "":
			GameState.hats[id] = maxi(int(GameState.hats.get(id, 0)), 1)
		GameState.worn_hat = id
		_player._body.wear_hat(id)))

	_section(box, "EMOTES")
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	for id in Emotes.ORDER:
		grid.add_child(_button(Emotes.name_of(id), func() -> void:
			_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_player.start_emote(id)))

	_section(box, "HAND IDLES (plays now; equips if this fighter can wear it)")
	box.add_child(_check("Loop the last one", false, func(on: bool) -> void: _idle_loop = on))
	var idle_grid := GridContainer.new()
	idle_grid.columns = 2
	box.add_child(idle_grid)
	for id in IdleAnims.BASE.values() + IdleAnims.SHOP:
		idle_grid.add_child(_button(IdleAnims.name_of(id), func() -> void:
			_idle_pick = id
			GameState.equip_idle(id)
			_player._fists.play_idle(id)))

	_build_character_lab_panel(box)

	_section(box, "SPAWN")
	var kinds: Array = BASE.keys() + Veterans.SCENES.keys()
	for i in DeadLeagueRules.BOSS_COUNT:
		kinds.append("contender: " + DeadLeagueRules.boss(i).name.to_lower())
	_enemy_pick = _options(kinds, "zombie", func(_id: String) -> void: pass)
	box.add_child(_enemy_pick)
	var tier := _options(["tier 1", "tier 2", "tier 3", "tier 4", "tier 5"], "tier 1", func(id: String) -> void:
		_tier = int(id.get_slice(" ", 1)))
	box.add_child(tier)
	box.add_child(_options(["normal", "elite", "champion"], _rank, func(id: String) -> void: _rank = id))
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	spawn_row.add_child(_button("Spawn", func() -> void: _spawn(1)))
	spawn_row.add_child(_button("Spawn 5", func() -> void: _spawn(5)))
	spawn_row.add_child(_button("Clear", _clear))
	_freeze_check = _check("Freeze enemies", false, func(on: bool) -> void:
		_frozen = on
		for enemy in $Enemies.get_children():
			enemy.set_physics_process(not on))
	box.add_child(_freeze_check)

	_section(box, "DEAD LEAGUE")
	box.add_child(_button("True Coffin King (maxes this fighter)", _true_coffin_king))

	_section(box, "FORCE A SPECIAL (nearest boxer)")
	var special_grid := GridContainer.new()
	special_grid.columns = 2
	box.add_child(special_grid)
	for kind in SPECIALS:
		special_grid.add_child(_button(kind, func() -> void: _force_special(kind)))

	_section(box, "POWER (whole line, selected)")
	box.add_child(_options(POWERS, GameState.power_pick, func(root: String) -> void: _give_power(root)))

	_section(box, "PLAYER")
	_god_check = _check("God mode", true, _set_god)
	box.add_child(_god_check)
	box.add_child(_button("Fill ultimate", func() -> void: _player.ult.fill()))
	box.add_child(_button("+5 levels", func() -> void:
		for i in 5:
			GameState.add_xp(GameState.xp_to_next() - GameState.xp)))
	box.add_child(_button("Replay the tips", func() -> void:
		GameState.tips_seen = {}
		_hud.announce_small("Tips will show again", UiTheme.GOLD)))

	_section(box, "RING")
	box.add_child(_check("Ring (ropes hold you in)", true, _set_ring))

	_section(box, "ARENA THEME (backdrop)")
	var themes: Array = Themes.ARENA.map(func(theme: Dictionary) -> String: return theme.id)
	box.add_child(_options(["ring"] + themes, "ring", _set_theme))


## A heading; click it to fold everything under it (up to the next heading).
func _section(box: VBoxContainer, title: String) -> void:
	var header := Button.new()
	header.text = "▾  " + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_override("font", UiTheme.display_font())
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", UiTheme.MUTED)
	header.set_meta("section", true)
	header.pressed.connect(func() -> void:
		var open := header.text.begins_with("▸")
		header.text = ("▾  " if open else "▸  ") + title
		var past := false
		for child in box.get_children():
			if child == header:
				past = true
			elif past:
				if child.has_meta("section"):
					break
				(child as CanvasItem).visible = open)
	box.add_child(header)


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(pressed)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _check(text: String, on: bool, toggled: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = on
	check.toggled.connect(toggled)
	check.focus_mode = Control.FOCUS_NONE
	return check


func _options(items: Array, current: String, chosen: Callable) -> OptionButton:
	var options := OptionButton.new()
	for i in items.size():
		options.add_item(String(items[i]) if items[i] != "" else "(none)")
		options.set_item_metadata(i, items[i])
		if items[i] == current:
			options.select(i)
	options.item_selected.connect(func(index: int) -> void: chosen.call(options.get_item_metadata(index)))
	options.focus_mode = Control.FOCUS_NONE
	return options


func _slider(minimum: float, maximum: float, step: float, value: float, changed: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(changed)
	slider.focus_mode = Control.FOCUS_NONE
	return slider


func _build_character_lab_panel(box: VBoxContainer) -> void:
	_section(box, "CHARACTER LAB  ·  V CAMERA TOGGLE")
	box.add_child(_note("V or controller Share/Touchpad toggles. PgUp/PgDn zoom; inspect with right-drag/right stick."))
	_lab_status = _note("Character Lab is starting…")
	_lab_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lab_status.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_lab_status)

	box.add_child(_options(PlaygroundCharacterLab.MODES, "first_person", func(id: String) -> void:
		_lab.set_mode(id)))
	var skins: Array = [""] + Skins.of(GameState.player_class)
	box.add_child(_options(skins, GameState.skin(), _switch_skin))
	# The body revamp prototype (2026-10-29, the Answer only so far): play in
	# third person as either voxel scale, or compare them side by side.
	box.add_child(_note("Body (revamp prototype: the Answer)"))
	box.add_child(_options(["current", "tiny", "medium", "large"], "current", func(id: String) -> void:
		_lab.avatar.body_variant = "" if id == "current" else id
		_lab.avatar.rebuild(GameState.player_class, GameState.skin())))
	box.add_child(_button("Voxel scale comparison (side by side)", func() -> void:
		get_tree().change_scene_to_file("res://playground/character_lab/voxel_compare.tscn")))

	var camera_row := HBoxContainer.new()
	camera_row.add_child(_note("Distance"))
	camera_row.add_child(_slider(1.8, 6.5, 0.1, _lab.camera_distance, func(value: float) -> void:
		_lab.set_camera_distance(value)))
	box.add_child(camera_row)
	var shoulder_row := HBoxContainer.new()
	shoulder_row.add_child(_note("Shoulder"))
	shoulder_row.add_child(_slider(-0.8, 0.8, 0.05, _lab.camera_shoulder, func(value: float) -> void:
		_lab.camera_shoulder = value))
	box.add_child(shoulder_row)
	var smooth_row := HBoxContainer.new()
	smooth_row.add_child(_note("Smoothing"))
	smooth_row.add_child(_slider(2.0, 24.0, 1.0, _lab.camera_smoothing, func(value: float) -> void:
		_lab.camera_smoothing = value))
	box.add_child(smooth_row)
	box.add_child(_check("Camera-relative movement", true, func(on: bool) -> void:
		_lab.camera_relative = on))
	var facing_row := HBoxContainer.new()
	facing_row.add_child(_note("Body facing"))
	facing_row.add_child(_options(["camera_aim", "movement_direction", "locked_target"], _lab.facing_mode, func(id: String) -> void:
		_lab.facing_mode = id))
	box.add_child(facing_row)
	box.add_child(_check("Hide gameplay HUD", false, _lab.set_hud_hidden))

	var views := HBoxContainer.new()
	box.add_child(views)
	for view in ["front", "three_quarter", "side", "back"]:
		views.add_child(_button(view.replace("three_quarter", "3/4").capitalize(), func() -> void:
			_lab.set_mode("inspect")
			_lab.set_view_preset(view)))

	box.add_child(_check("Turntable", false, func(on: bool) -> void: _lab.turntable = on))
	box.add_child(_check("Neutral review lighting", false, _lab.set_neutral_lighting))
	box.add_child(_check("Silhouette-only geometry check", false, func(on: bool) -> void:
		_lab.avatar.set_silhouette(on)))
	box.add_child(_check("Skeleton / joint debug", false, func(on: bool) -> void:
		_lab.avatar.set_skeleton_debug(on)))

	box.add_child(_note("ANIMATION PREVIEW"))
	var speed_row := HBoxContainer.new()
	speed_row.add_child(_note("Speed"))
	speed_row.add_child(_options(["0.25x", "0.5x", "1x", "1.5x"], "1x", func(id: String) -> void:
		_lab.avatar.playback_speed = float(id.trim_suffix("x"))))
	box.add_child(speed_row)
	var playback := HBoxContainer.new()
	playback.add_child(_check("Loop", false, func(on: bool) -> void: _lab.avatar.loop_action = on))
	playback.add_child(_check("Pause", false, func(on: bool) -> void: _lab.avatar.paused = on))
	playback.add_child(_button("Restart", _lab.avatar.restart_action))
	playback.add_child(_button("Next", _lab.next_preview))
	box.add_child(playback)
	box.add_child(_options(PlaygroundFighterAvatar.ACTIONS, "guard", _lab.play_preview))

	var attack_grid := GridContainer.new()
	attack_grid.columns = 3
	box.add_child(attack_grid)
	for action in ["jab_left", "cross_right", "hook_left", "hook_right", "uppercut_left", "uppercut_right"]:
		attack_grid.add_child(_button(action.replace("_", " ").capitalize(), func() -> void:
			_lab.play_preview(action)))

	var defense_grid := GridContainer.new()
	defense_grid.columns = 3
	box.add_child(defense_grid)
	for action in ["block", "slip_left", "slip_right", "roll_left", "roll_right", "back_step", "guard_break", "taunt", "get_up"]:
		defense_grid.add_child(_button(action.replace("_", " ").capitalize(), func() -> void:
			_lab.play_preview(action)))

	box.add_child(_note("REAL GAMEPLAY PUNCHES (uses production timing / hit checks)"))
	var real_attack_grid := GridContainer.new()
	real_attack_grid.columns = 3
	box.add_child(real_attack_grid)
	for spec in [["jab", "left"], ["cross", "right"], ["hook", "left"], ["hook", "right"], ["uppercut", "left"], ["uppercut", "right"]]:
		real_attack_grid.add_child(_button((String(spec[0]) + " " + String(spec[1])).capitalize(), func() -> void:
			_lab.trigger_gameplay_punch(String(spec[0]), String(spec[1]))))

	box.add_child(_note("DAMAGE / KNOCKDOWN PREVIEW"))
	var damage_direction_row := HBoxContainer.new()
	damage_direction_row.add_child(_note("Direction"))
	damage_direction_row.add_child(_options(["front", "left", "right", "back"], "front", func(id: String) -> void:
		_lab.hit_direction = id))
	box.add_child(damage_direction_row)
	var hit_grid := GridContainer.new()
	hit_grid.columns = 3
	box.add_child(hit_grid)
	hit_grid.add_child(_button("Light hit", func() -> void: _lab.trigger_hit(_lab.hit_direction, false)))
	hit_grid.add_child(_button("Heavy hit", func() -> void: _lab.trigger_hit(_lab.hit_direction, true)))
	hit_grid.add_child(_button("Guard break", func() -> void: _lab.play_preview("guard_break")))
	hit_grid.add_child(_button("Knockdown", func() -> void: _lab.trigger_knockdown(_lab.hit_direction)))
	hit_grid.add_child(_button("Get up face-up", func() -> void: _lab.trigger_get_up(false)))
	hit_grid.add_child(_button("Get up face-down", func() -> void: _lab.trigger_get_up(true)))

	var ult_row := HBoxContainer.new()
	box.add_child(ult_row)
	ult_row.add_child(_button("Ultimate 1", func() -> void: _lab.preview_ultimate(1)))
	ult_row.add_child(_button("Ultimate 2", func() -> void: _lab.preview_ultimate(2)))

	box.add_child(_note("REFERENCE / CAPTURE"))
	box.add_child(_options(["off", "default_voxel", "default_art", "alternate_voxel", "alternate_art", "first_person_hands"], "off", func(id: String) -> void:
		_lab.set_reference(id)))
	var opacity_row := HBoxContainer.new()
	opacity_row.add_child(_note("Reference opacity"))
	opacity_row.add_child(_slider(0.15, 1.0, 0.05, 1.0, _lab.set_reference_opacity))
	box.add_child(opacity_row)
	box.add_child(_note("FIRST-PERSON HAND / GLOVE REVIEW"))
	var hand_grid := GridContainer.new()
	hand_grid.columns = 3
	box.add_child(hand_grid)
	for pose in ["relaxed", "guard", "left_punch", "right_punch", "open", "ultimate_ready"]:
		hand_grid.add_child(_button(pose.replace("_", " ").capitalize(), func() -> void:
			_lab.preview_hands(pose)))
	var capture_row := HBoxContainer.new()
	box.add_child(capture_row)
	capture_row.add_child(_button("Capture 4 views", _lab.capture_views))
	capture_row.add_child(_button("Default / Alt", _lab.toggle_skin_comparison))
	capture_row.add_child(_button("+ Remote", func() -> void: _lab.spawn_remote()))
	capture_row.add_child(_button("Clear remotes", _lab.clear_remotes))


func _switch_fighter(id: String) -> void:
	if id == GameState.player_class:
		return
	_resume_lab_mode = "inspect" if _lab and _lab.mode == "inspect" else "third_person" if _lab and _lab.mode == "third_person" else ""
	GameState.set_player_class(id)
	get_tree().reload_current_scene()


## Every passive or ultimate the fighter has, by name, locked or not.
func _ability_options(slot: String) -> OptionButton:
	var fighter := GameState.player_class
	var entries: Array = Abilities.passives(fighter) if slot == "passive" else Abilities.ultimates(fighter)
	var current := GameState.passive() if slot == "passive" else GameState.ultimate()
	var options := OptionButton.new()
	options.focus_mode = Control.FOCUS_NONE
	for i in entries.size():
		options.add_item(String(entries[i].get("name", entries[i].id)))
		options.set_item_metadata(i, entries[i].id)
		if entries[i].id == current:
			options.select(i)
	options.item_selected.connect(func(index: int) -> void: _equip_ability(slot, options.get_item_metadata(index)))
	return options


## Equips it whatever the fighter's level (raising the class level to its
## unlock if needed), then reloads the ring so the ultimate and passive start
## fresh.
func _equip_ability(slot: String, id: String) -> void:
	var fighter := GameState.player_class
	var entry := Abilities.info(fighter, id)
	if entry.is_empty():
		return
	var info: Dictionary = GameState._classes[fighter]
	info.level = maxi(int(info.level), int(entry.get("level", 1)))
	var picks: Dictionary = GameState.loadouts.get(fighter, {})
	picks[slot] = id
	GameState.loadouts[fighter] = picks
	_resume_lab_mode = "inspect" if _lab and _lab.mode == "inspect" else "third_person" if _lab and _lab.mode == "third_person" else ""
	get_tree().reload_current_scene()


## Upgrades as at a point on the climb (then the ring reloads): none, the
## par build for contender tier t (85% of the open rings' levels, cheapest
## first, the fighter at that tier's level, the contenders before it beaten),
## or every node maxed.
func _set_upgrade_tier(index: int) -> void:
	GameState.upgrade_levels = {}
	var info: Dictionary = GameState._classes[GameState.player_class]
	if index == UPGRADE_TIERS.size() - 1:
		for id in GameState.UPGRADES:
			GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
		info.level = maxi(int(info.level), Progression.PAR_LEVEL[Progression.TIER_COUNT])
		for i in DeadLeagueRules.BOSS_COUNT:
			GameState.dead_league_clears[DeadLeagueRules.boss(i).id] = true
	elif index > 0:
		var levels := []
		for id in GameState.UPGRADES:
			var node: Dictionary = GameState.UPGRADES[id]
			if int(node.get("ring", 1)) > index or GameState.power_of(id) != "" or node.has("endless"):
				continue
			for level in int(node.max_level):
				levels.append([GameState.price_at(node, level), id])
		levels.sort_custom(func(a, b) -> bool: return a[0] < b[0])
		for i in ceili(levels.size() * Progression.PAR_SHARE):
			var id: String = levels[i][1]
			GameState.upgrade_levels[id] = int(GameState.upgrade_levels.get(id, 0)) + 1
		info.level = Progression.PAR_LEVEL[index]
		GameState.dead_league_clears = {}
		for i in index - 1:
			GameState.dead_league_clears[DeadLeagueRules.boss(i).id] = true
	else:
		info.level = 1
		GameState.dead_league_clears = {}
	_resume_lab_mode = "inspect" if _lab and _lab.mode == "inspect" else "third_person" if _lab and _lab.mode == "third_person" else ""
	get_tree().reload_current_scene()


func _switch_skin(id: String) -> void:
	if id == GameState.skin():
		return
	if id != "":
		GameState.skins_owned[id] = true
	GameState.equip_skin(GameState.player_class, id)
	_lab.set_skin(id)


# --- Doing things ---

func _spawn(count: int) -> void:
	var pick: String = _enemy_pick.get_item_metadata(_enemy_pick.selected)
	for i in count:
		var enemy: Enemy
		if pick.begins_with("contender: "):
			var index := 0
			for k in DeadLeagueRules.BOSS_COUNT:
				if DeadLeagueRules.boss(k).name.to_lower() == pick.trim_prefix("contender: "):
					index = k
			var boss: DeadLeagueBoss = load("res://dead_league_boss.tscn").instantiate()
			boss.configure(index, 1)
			boss.arena_center = Vector3(0, 0, -1.5)
			boss.arena_limit = 3.4 if _ring_on else 38.0
			enemy = boss
			enemy.setup(_player, false)
		else:
			var path: String = BASE.get(pick, "")
			var scene: PackedScene = load(path) if path != "" else Veterans.SCENES[pick]
			enemy = scene.instantiate()
			enemy.setup(_player, false, Progression.enemy_scaling(_tier - 1 + 0.4))
			enemy.arena_center = Vector3(0, 0, -1.5)
			enemy.arena_limit = 6.0 if _ring_on else 38.0
		var ahead := -_player.global_basis.z
		ahead.y = 0.0
		enemy.position = _player.global_position + ahead.normalized() * 5.0 + Vector3((i - count / 2.0) * 1.4, 0.1, 0)
		$Enemies.add_child(enemy)
		if not pick.begins_with("contender: "):
			_rank_up(enemy)
		if _frozen:
			enemy.set_physics_process(false)


## Makes it an elite or a champion (as the Arena does), per the rank picked.
func _rank_up(enemy: Enemy) -> void:
	if _rank == "elite":
		enemy.make_elite(Enemy.ELITE_TRAITS.pick_random())
		enemy.set_meta("elite", true)
	elif _rank == "champion":
		var traits: Array = Enemy.ELITE_TRAITS.duplicate()
		traits.shuffle()
		enemy.make_champion(traits.slice(0, 2))


## Maxes this fighter (web, level, every card at full rank, every attribute,
## every contender beaten) and steps into the ring with the True Coffin King.
## Leaving the fight comes back here.
func _true_coffin_king() -> void:
	var fighter := GameState.player_class
	for id in GameState.UPGRADES:
		GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
	for i in DeadLeagueRules.BOSS_COUNT:
		GameState.dead_league_clears[DeadLeagueRules.boss(i).id] = true
	var info: Dictionary = GameState._classes[fighter]
	info.level = maxi(int(info.level), Attributes.MAX * Attributes.LIST.size() / Attributes.POINTS_PER_LEVEL + 1)
	info.attribute_points = 0
	for attribute in Attributes.LIST:
		info.attributes[attribute] = Attributes.MAX
	for id in Cards.deck(fighter):
		info.cards[id] = Cards.copies(Cards.deck(fighter)[id])
	info.draws = 0
	info.offer = []
	if GameState.power_pick == "":
		GameState.select_power("sigil_fire")
	GameState.save_game()
	load("res://dead_league_arena.gd").leave_to = "res://playground/playground.tscn"
	GameState.dead_league_bout = DeadLeagueRules.BOSS_COUNT - 1
	GameState.true_king_bout = true
	Loading.go("res://dead_league_arena.tscn")


func _clear() -> void:
	for enemy in $Enemies.get_children():
		enemy.queue_free()


func _force_special(kind: String) -> void:
	var best: Boxer
	for node in $Enemies.get_children():
		var boxer := node as Boxer
		if boxer and not boxer.is_dead() and (best == null or boxer.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position)):
			best = boxer
	if best == null:
		_hud.announce_small("Spawn a boxer first (brawler, a veteran, a contender...)", UiTheme.BAD)
		return
	best._special = ""
	best._start_special(kind)


func _give_power(root: String) -> void:
	if root == "":
		GameState.power_pick = ""
		return
	for id in GameState.UPGRADES:
		if GameState.power_of(id) == root:
			GameState.upgrade_levels[id] = GameState.UPGRADES[id].max_level
	GameState.select_power(root)
	_hud.announce_small("%s line maxed and selected" % SkillTreeView.BRANCHES[root].name, UiTheme.GOLD)


func _set_god(on: bool) -> void:
	_god = on
	_player.invulnerable = false


## Takes the ring down (or puts it back): ropes, canvas and walls. Enemies
## that keep their distance get the whole space too.
func _set_ring(on: bool) -> void:
	_ring_on = on
	_ring.visible = on
	for body in _ring.find_children("*", "CollisionShape3D", true, false):
		body.set_deferred("disabled", not on)
	for enemy in $Enemies.get_children():
		if enemy is Enemy:
			enemy.arena_limit = (3.4 if enemy is DeadLeagueBoss else 6.0) if on else 38.0


func _set_theme(id: String) -> void:
	if _theme_node:
		_theme_node.queue_free()
		_theme_node = null
	if id == "ring":
		return
	var theme: Dictionary = Themes.ARENA.filter(func(t: Dictionary) -> bool: return t.id == id)[0]
	_theme_node = Node3D.new()
	$Decorations.add_child(_theme_node)
	if id != "graveyard":
		ArenaScenery.build(theme, _theme_node, RandomNumberGenerator.new())
	Themes.apply_environment($WorldEnvironment.environment, theme, $Moon)
	Sfx.play_music(theme.music)
