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
const POWERS := ["", "sigil_fire", "sigil_frost", "sigil_storm", "sigil_blood"]

var _panel: Control
var _enemy_pick: OptionButton
var _tier := 1
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


func _ready() -> void:
	# Everything unlocked, nothing interrupting.
	GameState.tutorial_done = true
	for id in Achievements.LIST:
		GameState.achievements[id] = true
	for tip in ["hat_first", "hat_rack", "hat_rack_tour", "power_select"]:
		GameState.tips_seen[tip] = true
	for id in IdleAnims.SHOP:
		GameState.idles_bought[id] = true
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
	_player.class_event.connect(_hud.show_class_event)
	_player.knuckles_broken.connect(_player.restore)
	_hud.end_run_requested.connect(func() -> void: get_tree().quit())
	_hud.set_leave_text("Quit the playground")
	_hud.set_info("PLAYGROUND  ·  F1 panel")
	_set_god(true)
	_build_panel()
	Sfx.play_music("camp")


func _process(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25
	if _god:
		_player.knuckles = _player.max_knuckles
	if _idle_loop and _idle_pick != "" and not _player._fists.idle_playing:
		_player._fists.play_idle(_idle_pick)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_panel.visible = not _panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _panel.visible else Input.MOUSE_MODE_CAPTURED


# --- The panel ---------------------------------------------------------------------

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.raised(Color(UiTheme.PANEL, 0.94), UiTheme.GOLD, 2, 10, 12.0))
	_panel.position = Vector2(12, 90)
	_panel.custom_minimum_size = Vector2(330, 600)
	layer.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(320, 590)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(UiTheme.title_label("PLAYGROUND", 24, UiTheme.GOLD))
	box.add_child(_note("F1 hides this. Click the ring to fight."))

	_section(box, "FIGHTER")
	var fighters := _options(GameState.CLASSES.keys(), GameState.player_class, func(id: String) -> void:
		GameState.player_class = id
		GameState.save_game()
		get_tree().reload_current_scene())
	box.add_child(fighters)

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

	_section(box, "SPAWN")
	var kinds: Array = BASE.keys() + Veterans.SCENES.keys()
	for i in DeadLeagueRules.BOSS_COUNT:
		kinds.append("contender: " + DeadLeagueRules.boss(i).name.to_lower())
	_enemy_pick = _options(kinds, "zombie", func(_id: String) -> void: pass)
	box.add_child(_enemy_pick)
	var tier := _options(["tier 1", "tier 2", "tier 3", "tier 4", "tier 5"], "tier 1", func(id: String) -> void:
		_tier = int(id.get_slice(" ", 1)))
	box.add_child(tier)
	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	spawn_row.add_child(_button("Spawn", func() -> void: _spawn(1)))
	spawn_row.add_child(_button("Spawn 5", func() -> void: _spawn(5)))
	spawn_row.add_child(_button("Clear", _clear))
	box.add_child(_check("Freeze enemies", false, func(on: bool) -> void:
		_frozen = on
		for enemy in $Enemies.get_children():
			enemy.set_physics_process(not on)))

	_section(box, "FORCE A SPECIAL (nearest boxer)")
	var special_grid := GridContainer.new()
	special_grid.columns = 2
	box.add_child(special_grid)
	for kind in SPECIALS:
		special_grid.add_child(_button(kind, func() -> void: _force_special(kind)))

	_section(box, "POWER (whole line, selected)")
	box.add_child(_options(POWERS, GameState.power_pick, func(root: String) -> void: _give_power(root)))

	_section(box, "PLAYER")
	box.add_child(_check("God mode", true, _set_god))
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


func _section(box: VBoxContainer, title: String) -> void:
	var label := UiTheme.title_label(title, 15, UiTheme.MUTED)
	box.add_child(label)


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
		if _frozen:
			enemy.set_physics_process(false)


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
