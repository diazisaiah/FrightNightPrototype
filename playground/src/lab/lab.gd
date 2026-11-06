extends "res://training.gd"
## The Lab (2026-11-06): a phone-friendly playground for testing away from the
## computer. Big buttons: pick a fighter, a level (Easy, Medium or Hard sets
## upgrades, attributes, level and cards to a point on the climb), a passive,
## an ultimate and a power, then run the BENCHMARK (the same 15 enemies in 5
## groups and then a Dead League boss, every time, with the numbers measured)
## or a FREE FIGHT. Results can be copied as text. It runs on the playground's
## own save, never the game's.
## Test runs: -- --lab-test=<fighter>,<level 0-2> plays the benchmark with
## instant kills (to check the flow), prints the result and quits.
## -- --lab-test=<fighter>,<level> --lab-bot=average|good plays it with the
## scripted player instead (lab_bot.gd), no cheats.
## The fight is in an open 30 m arena (not the 8 m ring): the monsters walk in
## from 10 m away, so dashes, projectiles, auras and crowds have room.
## Besides damage, the benchmark measures what utility abilities do: damage
## avoided (dodged, slipped or soaked by a shield), knuckles healed, seconds
## monsters spend stunned or held, distance moved, and what happened inside
## each ultimate's window.

const LEVELS := [
	{"name": "Easy", "tier": 1, "boss": 0},
	{"name": "Medium", "tier": 3, "boss": 2},
	{"name": "Hard", "tier": 5, "boss": 4},
]
## The benchmark's enemies, in order. ":elite" makes it an elite.
const GROUPS := [
	{"name": "Crowd", "units": ["zombie", "zombie", "zombie", "zombie", "zombie"]},
	{"name": "Rush", "units": ["runner", "runner", "runner", "skeleton"]},
	{"name": "Bruisers", "units": ["brawler", "hulk"]},
	{"name": "Casters", "units": ["mage", "priest", "armor"]},
	{"name": "Elite", "units": ["brawler:elite"]},
]
const SCENES := {
	"zombie": "res://zombie.tscn", "skeleton": "res://skeleton.tscn", "runner": "res://runner.tscn",
	"hulk": "res://hulk.tscn", "brawler": "res://brawler.tscn", "mage": "res://mage.tscn",
	"priest": "res://priest.tscn", "armor": "res://possessed_armor.tscn",
	"boss": "res://boss.tscn",
}
const LabBot := preload("res://playground/lab/lab_bot.gd")
const ARENA_HALF := 15.0
## Monsters spawn on a circle this far from the middle; each group's angle
## (degrees clockwise from straight ahead) and spread are fixed.
const SPAWN_RADIUS := 10.0
const GROUP_ANGLES := [0.0, 75.0, -50.0, 160.0, 0.0]
const GROUP_SPREAD := [16.0, 20.0, 24.0, 22.0, 0.0]
const BOSS_DISTANCE := 8.0
const BOTS := ["", "average", "good"]
## How long (seconds) each ultimate's effect is credited to it.
const ULT_WINDOWS := {
	"inferno": 3.0, "bulwark": 12.0, "riposte": 4.0, "flow_state": 10.0, "temporal_break": 4.0,
	"unbroken": 10.0, "highlight_reel": 3.0, "hype_train": 6.0, "big_mouth": 8.0,
	"the_family": 10.0, "elemental_fists": 10.0, "flame_burst": 3.0,
}
const POWER_LIST := ["", "sigil_fire", "sigil_frost", "sigil_storm", "sigil_blood", "sigil_quake", "sigil_gale", "sigil_iron", "sigil_doom"]
const GROUP_TIMEOUT := 120.0
const BOSS_TIMEOUT := 180.0
const HISTORY_PATH := "user://lab_history.json"
const HISTORY_KEEP := 10
const ROW_HEIGHT := 60.0

## What's picked (kept across the scene reloads that start a run).
static var _cfg := {"fighter": "berserker", "level": 0, "passive": 0, "ult": 0, "power": 0, "cards": true, "bot": 0}
## "", "bench" or "free": what this load of the scene starts.
static var _go := ""

var _menu: CanvasLayer
var _tools: CanvasLayer
var _tools_panel: PanelContainer
var _result_layer: CanvasLayer
var _passive_row: HFlowContainer
var _ult_row: HFlowContainer
var _power_button: Button
var _history_layer: CanvasLayer
var _bench_running := false
var _down := false
var _stats := {}
var _tracked := {}
var _wave: Array = []
var _bench_clock := 0.0
var _god_on := false
var _frozen_on := false
var _elite_on := false
var _test_mode := false
var _shot := ""
var _idle := false
var _free_kind := ""
var _bot: RefCounted
var _bot_arg := -1
var _ult_until := -1.0
var _last_knuckles := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	GameState.tutorial_done = true
	GameState.true_king_bout = false
	GameState.tony_unlocked = true
	for tip in ["hat_first", "hat_rack", "hat_rack_tour", "power_select"]:
		GameState.tips_seen[tip] = true
	Enemy.max_attackers = 2
	$Moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	Look.tune_environment($WorldEnvironment.environment, "ring")
	_build_torches()
	_spread_torches()
	_build_ring()
	$WorldEnvironment.environment.fog_density = 0.02
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
	_player.knuckles_broken.connect(_on_lab_broken)
	_player.damage_taken.connect(_on_damage_taken)
	_player.dodged.connect(func(_m: String) -> void: _count("dodges"))
	_player.grazed.connect(func() -> void: _count("grazes"))
	_player.punch_landed.connect(_on_punch_landed)
	_player.combo_changed.connect(func(count: int, _m: float, _r: float) -> void:
		if _bench_running:
			_stats.best_combo = maxi(int(_stats.best_combo), count))
	_player.ult.used.connect(func(_c: String) -> void:
		_count("ults")
		if _bench_running:
			_ult_until = _bench_clock + float(ULT_WINDOWS.get(GameState.ultimate(), 3.0)))
	_player.attack_resolved.connect(_on_attack_resolved)
	_player.class_event.connect(func(text: String) -> void:
		if _bench_running:
			_stats.events[text] = int(_stats.events.get(text, 0)) + 1)
	_hud.end_run_requested.connect(_back_to_menu)
	_hud.set_leave_text("Lab menu")
	_hud.set_info("LAB")
	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)
	Sfx.play_music("camp")
	Sfx.stop_ambience()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-free="):
			_free_kind = arg.trim_prefix("--lab-free=")
			_go = "free"
		if arg.begins_with("--lab-bot="):
			_bot_arg = maxi(BOTS.find(arg.trim_prefix("--lab-bot=")), 0)
		if arg == "--lab-idle":
			_idle = true
		if arg.begins_with("--lab-shot="):
			_shot = arg.trim_prefix("--lab-shot=")
		if arg.begins_with("--lab-test="):
			var parts := arg.trim_prefix("--lab-test=").split(",")
			_cfg.fighter = parts[0]
			_cfg.level = int(parts[1]) if parts.size() > 1 else 0
			_test_mode = true
			_apply_build()
			_go = "bench"
	if _go == "":
		_show_menu()
		if _shot != "":
			_take_shot()
	else:
		_begin(_go)


## Test hook: saves the screen to --lab-shot=<path>, then quits.
func _take_shot() -> void:
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot)
	get_tree().quit()


func _process(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25
	if _god_on and not _bench_running:
		_player.knuckles = _player.max_knuckles


func _unhandled_input(_event: InputEvent) -> void:
	pass


# --- The menu ----------------------------------------------------------------------

func _show_menu() -> void:
	_player.active = false
	_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_menu = CanvasLayer.new()
	_menu.layer = 30
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_menu.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	var title := UiTheme.title_label("FRIGHT NIGHT LAB", 40, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var version := Label.new()
	version.text = "build %s" % ProjectSettings.get_setting("application/config/version", "?")
	version.add_theme_color_override("font_color", UiTheme.MUTED)
	head.add_child(version)

	var fighters: Array = GameState.CLASSES.keys()
	var group := ButtonGroup.new()
	var row := _row(box, "FIGHTER")
	for id in fighters:
		var info: Dictionary = GameState.CLASSES[id]
		row.add_child(_pick(String(info.fighter), group, id == _cfg.fighter, func() -> void: _choose_fighter(id), info.color, 150.0))

	group = ButtonGroup.new()
	row = _row(box, "LEVEL")
	for i in LEVELS.size():
		row.add_child(_pick(String(LEVELS[i].name).to_upper(), group, i == _cfg.level, func() -> void: _cfg.level = i, Color.WHITE, 190.0))
	var note := Label.new()
	note.text = "Easy: first climb build (boss Bellman)   Medium: mid climb (Southpaw)   Hard: late climb (Coffin King)"
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(note)

	_passive_row = _row(box, "PASSIVE")
	_ult_row = _row(box, "ULTIMATE")
	_fill_abilities()

	row = _row(box, "POWER")
	_power_button = Button.new()
	_power_button.custom_minimum_size = Vector2(300, ROW_HEIGHT)
	_power_button.focus_mode = Control.FOCUS_NONE
	_power_button.add_theme_font_size_override("font_size", 22)
	_power_button.pressed.connect(func() -> void:
		_cfg.power = (int(_cfg.power) + 1) % POWER_LIST.size()
		_refresh_power())
	row.add_child(_power_button)
	_refresh_power()
	var cards := Button.new()
	cards.toggle_mode = true
	cards.button_pressed = _cfg.cards
	cards.custom_minimum_size = Vector2(200, ROW_HEIGHT)
	cards.focus_mode = Control.FOCUS_NONE
	cards.add_theme_font_size_override("font_size", 22)
	cards.text = "CARDS: " + ("ON" if _cfg.cards else "OFF")
	cards.toggled.connect(func(on: bool) -> void:
		_cfg.cards = on
		cards.text = "CARDS: " + ("ON" if on else "OFF"))
	row.add_child(cards)

	var bot_button := Button.new()
	bot_button.custom_minimum_size = Vector2(300, ROW_HEIGHT)
	bot_button.focus_mode = Control.FOCUS_NONE
	bot_button.add_theme_font_size_override("font_size", 22)
	bot_button.text = _bot_text()
	bot_button.pressed.connect(func() -> void:
		_cfg.bot = (int(_cfg.bot) + 1) % BOTS.size()
		bot_button.text = _bot_text())
	row.add_child(bot_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var bench := _action("BENCHMARK", UiTheme.GOLD, func() -> void: _launch("bench"))
	bench.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(bench)
	var free := _action("FREE FIGHT", UiTheme.TEXT, func() -> void: _launch("free"))
	free.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(free)
	actions.add_child(_action("LAST RUNS", UiTheme.MUTED, _show_history))


func _row(box: VBoxContainer, title: String) -> HFlowContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	box.add_child(line)
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(120, ROW_HEIGHT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", UiTheme.MUTED)
	line.add_child(name_label)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	line.add_child(flow)
	return flow


func _pick(text: String, group: ButtonGroup, on: bool, pressed: Callable, color: Color, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = on
	button.custom_minimum_size = Vector2(width, ROW_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	if color != Color.WHITE:
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_pressed_color", color)
		button.add_theme_color_override("font_hover_color", color)
	button.pressed.connect(pressed)
	return button


func _action(text: String, color: Color, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 78)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.pressed.connect(pressed)
	return button


func _choose_fighter(id: String) -> void:
	_cfg.fighter = id
	_cfg.passive = 0
	_cfg.ult = 0
	_fill_abilities()


func _fill_abilities() -> void:
	for row in [_passive_row, _ult_row]:
		for child in row.get_children():
			child.queue_free()
	var fighter: String = _cfg.fighter
	var group := ButtonGroup.new()
	var passives: Array = Abilities.passives(fighter)
	for i in passives.size():
		_passive_row.add_child(_pick(String(passives[i].name), group, i == _cfg.passive, func() -> void: _cfg.passive = i, Color.WHITE, 250.0))
	group = ButtonGroup.new()
	var ults: Array = Abilities.ultimates(fighter)
	for i in ults.size():
		_ult_row.add_child(_pick(String(ults[i].name), group, i == _cfg.ult, func() -> void: _cfg.ult = i, Color.WHITE, 250.0))


func _bot_text() -> String:
	var who: String = BOTS[int(_cfg.bot)]
	return "PLAYER: " + ("YOU" if who == "" else who.to_upper() + " BOT")


func _power_name(root: String) -> String:
	return "None" if root == "" else String(SkillTreeView.BRANCHES[root].name)


func _refresh_power() -> void:
	_power_button.text = "POWER: %s  >" % _power_name(POWER_LIST[int(_cfg.power)]).to_upper()


# --- Starting a run ----------------------------------------------------------------

## Sets the fighter up as the level and picks say, then reloads the scene so
## the player, ultimate and passive start fresh.
func _apply_build() -> void:
	var fighter: String = _cfg.fighter
	GameState.set_player_class(fighter)
	var level: Dictionary = LEVELS[int(_cfg.level)]
	load("res://balance_report.gd").set_build(GameState, load("res://progression.gd"), fighter, int(level.tier), bool(_cfg.cards))
	var info: Dictionary = GameState._classes[fighter]
	var picks: Dictionary = GameState.loadouts.get(fighter, {})
	for slot in ["passive", "ult"]:
		var entries: Array = Abilities.passives(fighter) if slot == "passive" else Abilities.ultimates(fighter)
		var entry: Dictionary = entries[mini(int(_cfg[slot]), entries.size() - 1)]
		info.level = maxi(int(info.level), int(entry.get("level", 1)))
		picks["passive" if slot == "passive" else "ultimate"] = entry.id
	GameState.loadouts[fighter] = picks
	var root: String = POWER_LIST[int(_cfg.power)]
	GameState.power_pick = ""
	GameState.power_pick_2 = ""
	GameState.power_pick_3 = ""
	GameState.power_pick_4 = ""
	if root != "":
		if int(GameState.upgrade_levels.get(root, 0)) <= 0:
			GameState.upgrade_levels[root] = 1
		GameState.select_power(root)


func _launch(mode: String) -> void:
	_apply_build()
	_go = mode
	get_tree().paused = false
	get_tree().reload_current_scene()


func _back_to_menu() -> void:
	_go = ""
	get_tree().paused = false
	get_tree().reload_current_scene()


func _begin(mode: String) -> void:
	_player.active = true
	_hud.visible = true
	if not Controls.touch():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if mode == "bench":
		_run_bench()
	else:
		_build_tools()
		_hud.announce("Free fight  ·  pause for tools")
		if _free_kind != "":
			_free_spawn(_free_kind)
			if _shot != "":
				for i in 90:
					await get_tree().physics_frame
				await _take_shot()


## The open arena: a 30 m stone floor with distance rings at 5 and 10 m, a low
## wall and pillars round the edge, and walls so nobody leaves.
func _build_ring() -> void:
	var stone := Enemy._material(Color(0.2, 0.2, 0.23))
	var marker := Enemy._material(Color(0.5, 0.44, 0.3))
	var pillar_material := Enemy._material(Color(0.15, 0.15, 0.18), 0.6)
	var arena := Node3D.new()
	arena.position = RING_CENTER
	$Decorations.add_child(arena)
	_ring = arena
	var size := ARENA_HALF * 2.0
	_add_mesh(arena, Enemy._box(Vector3(size, 0.04, size)), stone, Vector3(0, 0.02, 0))
	for radius in [5.0, 10.0]:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.05
		torus.outer_radius = radius + 0.05
		_add_mesh(arena, torus, marker, Vector3(0, 0.05, 0))
	for side in [-1.0, 1.0]:
		_add_mesh(arena, Enemy._box(Vector3(size, 0.7, 0.4)), pillar_material, Vector3(0, 0.35, side * ARENA_HALF))
		_add_mesh(arena, Enemy._box(Vector3(0.4, 0.7, size)), pillar_material, Vector3(side * ARENA_HALF, 0.35, 0))
	for x in [-1.0, 0.0, 1.0]:
		for z in [-1.0, 0.0, 1.0]:
			if x != 0.0 or z != 0.0:
				_add_mesh(arena, Enemy._cylinder(0.4, 3.2), pillar_material, Vector3(x * ARENA_HALF, 1.6, z * ARENA_HALF))
	var walls := StaticBody3D.new()
	arena.add_child(walls)
	for side in [-1.0, 1.0]:
		for along_x in [true, false]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(size, 3.0, 0.4) if along_x else Vector3(0.4, 3.0, size)
			shape.shape = box
			shape.position = Vector3(0, 1.5, side * ARENA_HALF) if along_x else Vector3(side * ARENA_HALF, 1.5, 0)
			walls.add_child(shape)


## Torches out to the new walls, lighting more of the floor.
func _spread_torches() -> void:
	for light in _torches:
		var torch := light.get_parent() as Node3D
		torch.position *= (ARENA_HALF - 2.0) / TORCH_RADIUS
		light.omni_range = 18.0


## Fixed spawn spot i of n in group g.
func _spawn_spot(g: int, i: int, n: int) -> Vector3:
	var angle := deg_to_rad(float(GROUP_ANGLES[g]) + (i - (n - 1) / 2.0) * float(GROUP_SPREAD[g]))
	return RING_CENTER + Vector3(sin(angle), 0.1, -cos(angle)) * Vector3(SPAWN_RADIUS, 1.0, SPAWN_RADIUS)


## Back to the middle of the arena, full knuckles, facing the first spawn.
func _reset_player() -> void:
	_player.global_position = RING_CENTER + Vector3(0, 0.1, 0)
	_player.rotation.y = 0.0
	_player._camera.rotation.x = 0.0
	_player.velocity = Vector3.ZERO
	_player.restore()
	_last_knuckles = _player.knuckles
	_last_pos = _player.global_position


func _tier() -> int:
	return int(LEVELS[int(_cfg.level)].tier)


## One monster at a position, scaled like the Arena at this tier.
func _make_enemy(kind: String, at: Vector3) -> Enemy:
	var elite := kind.ends_with(":elite")
	kind = kind.trim_suffix(":elite")
	var enemy: Enemy = (load(SCENES[kind]) as PackedScene).instantiate()
	enemy.setup(_player, false, Progression.enemy_scaling(_tier() - 1 + 0.4))
	enemy.arena_center = RING_CENTER
	enemy.arena_limit = ARENA_HALF - 1.5
	enemy.position = at
	$Enemies.add_child(enemy)
	if elite:
		enemy.make_elite(Enemy.ELITE_TRAITS[0])
		enemy.set_meta("elite", true)
	_tracked[enemy] = enemy.hp
	return enemy


# --- The benchmark -----------------------------------------------------------------

func _count(key: String) -> void:
	if _bench_running:
		_stats[key] = int(_stats[key]) + 1


func _on_damage_taken(amount: float) -> void:
	if _bench_running and amount > 0.0:
		_stats.taken = float(_stats.taken) + amount
		_stats.hits = int(_stats.hits) + 1
		if _in_ult():
			_stats.ult_taken = float(_stats.ult_taken) + amount


func _on_punch_landed(kind: String, _killed: bool) -> void:
	if _bench_running:
		_stats.landed = int(_stats.landed) + 1
		if kind == "counter":
			_stats.counters = int(_stats.counters) + 1


func _in_ult() -> bool:
	return _bench_clock < _ult_until


func _on_attack_resolved(result: String, amount: float, _attack: String) -> void:
	if not _bench_running or result == "hit" or not _player.active:
		return
	var avoided := amount * (1.0 - Player.GRAZE_MULTIPLIER) if result == "grazed" else amount
	_stats.prevented = float(_stats.prevented) + avoided
	_stats.prevented_by[result] = float(_stats.prevented_by.get(result, 0.0)) + avoided
	if _in_ult():
		_stats.ult_prevented = float(_stats.ult_prevented) + avoided


## Every physics step of the fight: healing, distance, stun time.
func _sample(dt: float) -> void:
	var now: Vector3 = _player.global_position
	_stats.distance = float(_stats.distance) + Vector2(now.x - _last_pos.x, now.z - _last_pos.z).length()
	_last_pos = now
	var gain: float = _player.knuckles - _last_knuckles
	if gain > 0.001:
		_stats.healed = float(_stats.healed) + gain
		if _in_ult():
			_stats.ult_healed = float(_stats.ult_healed) + gain
	_last_knuckles = _player.knuckles
	if _in_ult():
		_stats.ult_time = float(_stats.ult_time) + dt
	for enemy in $Enemies.get_children():
		if enemy is Enemy and not enemy.is_dead() and (enemy._stagger_timer > 0.0 or enemy._hold_time > 0.0):
			_stats.cc = float(_stats.cc) + dt


func _on_lab_broken() -> void:
	if _bench_running:
		_down = true
	else:
		_player.restore()


func _run_bench() -> void:
	var level: Dictionary = LEVELS[int(_cfg.level)]
	_stats = {"taken": 0.0, "hits": 0, "dodges": 0, "grazes": 0, "counters": 0, "landed": 0, "best_combo": 0,
			"ults": 0, "events": {}, "groups": [], "dealt": 0.0,
			"prevented": 0.0, "prevented_by": {}, "healed": 0.0, "cc": 0.0, "distance": 0.0,
			"ult_dealt": 0.0, "ult_taken": 0.0, "ult_healed": 0.0, "ult_prevented": 0.0, "ult_time": 0.0}
	_bench_clock = 0.0
	_ult_until = -1.0
	var bot_index: int = _bot_arg if _bot_arg >= 0 else int(_cfg.bot)
	_bot = LabBot.new(_player, BOTS[bot_index]) if bot_index > 0 else null
	_reset_player()
	_down = false
	_bench_running = true
	_hud.announce("BENCHMARK")
	await get_tree().create_timer(2.5).timeout
	var outcome := "VICTORY"
	for g in GROUPS.size():
		var group: Dictionary = GROUPS[g]
		var units: Array = group.units
		_wave = []
		for i in units.size():
			_wave.append(_make_enemy(units[i], _spawn_spot(g, i, units.size())))
		var started := _bench_clock
		var dealt_before: float = _stats.dealt
		var taken_before: float = _stats.taken
		var result: String = await _wait_clear(GROUP_TIMEOUT)
		_stats.groups.append([group.name, _bench_clock - started, float(_stats.dealt) - dealt_before, float(_stats.taken) - taken_before])
		if result != "clear":
			outcome = "DEFEAT" if result == "down" else "TIMEOUT"
			break
		await get_tree().create_timer(1.2).timeout
	if outcome == "VICTORY":
		_reset_player()
		_hud.announce("BOSS")
		await get_tree().create_timer(1.5).timeout
		var boss: DeadLeagueBoss = load("res://dead_league_boss.tscn").instantiate()
		boss.configure(int(level.boss), 1)
		boss.arena_center = RING_CENTER
		boss.arena_limit = 9.0
		boss.setup(_player, false)
		boss.position = RING_CENTER + Vector3(0, 0.1, -BOSS_DISTANCE)
		$Enemies.add_child(boss)
		_tracked[boss] = boss.hp
		_wave = [boss]
		var started := _bench_clock
		var dealt_before: float = _stats.dealt
		var taken_before: float = _stats.taken
		var result: String = await _wait_clear(BOSS_TIMEOUT)
		_stats.groups.append(["Boss", _bench_clock - started, float(_stats.dealt) - dealt_before, float(_stats.taken) - taken_before])
		if result != "clear":
			outcome = "DEFEAT" if result == "down" else "TIMEOUT"
	_finish_bench(outcome)


## Waits until the wave is down, you're down, or the time is up; the clock only
## counts time in the fight (a pause doesn't).
func _wait_clear(limit: float) -> String:
	var elapsed := 0.0
	while true:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		elapsed += dt
		_bench_clock += dt
		_sample(dt)
		if _bot != null:
			_bot.step(dt, $Enemies.get_children())
		if _test_mode and not _idle and _bot == null and elapsed > 1.0:
			for enemy in _wave:
				if is_instance_valid(enemy) and not enemy.is_dead():
					enemy.take_hit(99999.0, enemy.global_position, Vector3.ZERO, false)
		for enemy in _tracked.keys():
			if is_instance_valid(enemy):
				var drop: float = float(_tracked[enemy]) - enemy.hp
				if drop > 0.0:
					_stats.dealt = float(_stats.dealt) + drop
					if _in_ult():
						_stats.ult_dealt = float(_stats.ult_dealt) + drop
				_tracked[enemy] = enemy.hp
		if _down:
			return "down"
		var alive := false
		for enemy in _wave:
			if is_instance_valid(enemy) and not enemy.is_dead():
				alive = true
		if not alive:
			return "clear"
		if elapsed > limit:
			return "timeout"
	return "clear"


func _finish_bench(outcome: String) -> void:
	_bench_running = false
	if _bot != null:
		_bot.release()
	var time := maxf(_bench_clock, 0.01)
	var fighter: String = _cfg.fighter
	var run := {
		"ver": str(ProjectSettings.get_setting("application/config/version", "?")),
		"fighter": fighter, "fighter_name": GameState.CLASSES[fighter].fighter,
		"level": LEVELS[int(_cfg.level)].name,
		"passive": Abilities.passives(fighter)[mini(int(_cfg.passive), Abilities.passives(fighter).size() - 1)].name,
		"ult": Abilities.ultimates(fighter)[mini(int(_cfg.ult), Abilities.ultimates(fighter).size() - 1)].name,
		"power": _power_name(POWER_LIST[int(_cfg.power)]), "cards": bool(_cfg.cards),
		"outcome": outcome, "time": time, "dealt": _stats.dealt, "dps": float(_stats.dealt) / time,
		"taken": _stats.taken, "hits": _stats.hits, "dodges": _stats.dodges, "grazes": _stats.grazes,
		"counters": _stats.counters, "landed": _stats.landed, "best_combo": _stats.best_combo, "ults": _stats.ults,
		"events": _stats.events, "groups": _stats.groups,
		"prevented": _stats.prevented, "prevented_by": _stats.prevented_by, "healed": _stats.healed,
		"cc": _stats.cc, "distance": _stats.distance, "ult_dealt": _stats.ult_dealt, "ult_taken": _stats.ult_taken,
		"ult_healed": _stats.ult_healed, "ult_prevented": _stats.ult_prevented, "ult_time": _stats.ult_time,
		"bot": BOTS[bot_index_used()] if bot_index_used() > 0 else "you",
		"knuckles": 0.0 if outcome == "DEFEAT" else _player.knuckles / maxf(_player.max_knuckles, 1.0),
		"date": Time.get_datetime_string_from_system(),
	}
	var history := _load_history()
	var previous := {}
	run["key"] = "%s|%s|%s|%s|%s|%s|%s" % [run.fighter, run.level, run.passive, run.ult, run.power, run.cards, run.bot]
	for i in range(history.size() - 1, -1, -1):
		if history[i].get("key") == run.key:
			previous = history[i]
			break
	history.append(run)
	_save_history(history)
	for enemy in $Enemies.get_children():
		enemy.queue_free()
	_player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _test_mode:
		print("LAB RESULT ", JSON.stringify(run))
		if _shot != "":
			_show_result(run, previous)
			await _take_shot()
		get_tree().quit()
		return
	_show_result(run, previous)


func bot_index_used() -> int:
	return _bot_arg if _bot_arg >= 0 else int(_cfg.bot)


func _group_text(g: Array) -> String:
	return "%s %.0fs" % [g[0], g[1]] + (" (dealt %d, took %d)" % [g[2], g[3]] if g.size() > 3 else "")


func _load_history() -> Array:
	if not FileAccess.file_exists(HISTORY_PATH):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(HISTORY_PATH))
	return parsed if parsed is Array else []


func _save_history(history: Array) -> void:
	# The last HISTORY_KEEP runs of each fighter.
	var kept: Array = []
	var counts := {}
	for i in range(history.size() - 1, -1, -1):
		var id := str(history[i].get("fighter", ""))
		counts[id] = int(counts.get(id, 0)) + 1
		if counts[id] <= HISTORY_KEEP:
			kept.push_front(history[i])
	var file := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(kept))


func _result_text(run: Dictionary) -> String:
	var lines: Array = []
	lines.append("LAB %s | %s | %s | passive %s | ultimate %s | power %s | cards %s | player %s" % [run.ver, run.fighter_name, run.level, run.passive, run.ult, run.power, "on" if run.cards else "off", run.get("bot", "you")])
	lines.append("%s  time %.1fs  dps %.1f  dealt %d  taken %d (%d hits)  knuckles left %d%%" % [run.outcome, run.time, run.dps, run.dealt, run.taken, run.hits, roundi(float(run.knuckles) * 100.0)])
	var groups: Array = []
	for g in run.groups:
		groups.append(_group_text(g))
	lines.append("Groups: " + ", ".join(groups))
	lines.append("Avoided %d (%s)  healed %d  enemy stun time %.0fs  distance %.0fm" % [run.get("prevented", 0.0), _avoided_text(run), run.get("healed", 0.0), run.get("cc", 0.0), run.get("distance", 0.0)])
	if int(run.ults) > 0:
		lines.append("Inside ultimate windows (%.0fs): dealt %d, took %d, avoided %d, healed %d" % [run.get("ult_time", 0.0), run.get("ult_dealt", 0.0), run.get("ult_taken", 0.0), run.get("ult_prevented", 0.0), run.get("ult_healed", 0.0)])
	lines.append("Dodges %d  grazes %d  counters %d  punches landed %d  best combo %d  ultimates %d" % [run.dodges, run.grazes, run.counters, run.landed, run.best_combo, run.ults])
	var events: Array = []
	for key in run.events:
		events.append("%s x%d" % [key, run.events[key]])
	if not events.is_empty():
		lines.append("Events: " + ", ".join(events))
	return "\n".join(lines)


func _avoided_text(run: Dictionary) -> String:
	var parts: Array = []
	var by: Dictionary = run.get("prevented_by", {})
	for key in by:
		parts.append("%s %d" % [key, by[key]])
	return ", ".join(parts) if not parts.is_empty() else "none"


func _delta(now: float, before: float, lower_is_better := false) -> String:
	if before <= 0.0001:
		return ""
	var change := (now - before) / before * 100.0
	if absf(change) < 0.5:
		return "  (same)"
	return "  (%+d%%)" % roundi(change)


func _delta_color(now: float, before: float, lower_is_better: bool) -> Color:
	if before <= 0.0001 or absf(now - before) / before < 0.005:
		return UiTheme.TEXT
	var better := now < before if lower_is_better else now > before
	return UiTheme.GOOD if better else UiTheme.BAD


func _show_result(run: Dictionary, previous: Dictionary) -> void:
	_hud.visible = false
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 40
	add_child(_result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.card(18.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var color := UiTheme.GOOD if run.outcome == "VICTORY" else UiTheme.BAD
	var head := UiTheme.title_label("%s  ·  %s" % [run.outcome, run.fighter_name.to_upper()], 40, color)
	box.add_child(head)
	var sub := Label.new()
	sub.text = "%s  ·  %s  ·  %s  ·  %s  ·  cards %s  ·  %s%s" % [run.level, run.passive, run.ult, run.power, "on" if run.cards else "off", String(run.get("bot", "you")).to_upper(), "" if previous.is_empty() else "   (compared with the last run of this exact build)"]
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	var rows := [
		["Time", "%.1fs" % run.time, run.time, previous.get("time", 0.0), true],
		["Damage per second", "%.1f" % run.dps, run.dps, previous.get("dps", 0.0), false],
		["Damage dealt", "%d" % run.dealt, run.dealt, previous.get("dealt", 0.0), false],
		["Damage taken", "%d" % run.taken, run.taken, previous.get("taken", 0.0), true],
		["Hits taken", "%d" % run.hits, run.hits, previous.get("hits", 0.0), true],
		["Knuckles left", "%d%%" % roundi(float(run.knuckles) * 100.0), run.knuckles, previous.get("knuckles", 0.0), false],
		["Clean dodges", "%d" % run.dodges, run.dodges, previous.get("dodges", 0.0), false],
		["Grazes", "%d" % run.grazes, run.grazes, previous.get("grazes", 0.0), true],
		["Counters", "%d" % run.counters, run.counters, previous.get("counters", 0.0), false],
		["Best combo", "%d" % run.best_combo, run.best_combo, previous.get("best_combo", 0.0), false],
		["Ultimates used", "%d" % run.ults, run.ults, previous.get("ults", 0.0), false],
		["Punches landed", "%d" % run.landed, run.landed, previous.get("landed", 0.0), false],
		["Damage avoided", "%d" % run.get("prevented", 0.0), run.get("prevented", 0.0), previous.get("prevented", 0.0), false],
		["Knuckles healed", "%d" % run.get("healed", 0.0), run.get("healed", 0.0), previous.get("healed", 0.0), false],
		["Enemy stun time", "%.0fs" % run.get("cc", 0.0), run.get("cc", 0.0), previous.get("cc", 0.0), false],
		["Distance moved", "%dm" % run.get("distance", 0.0), run.get("distance", 0.0), previous.get("distance", 0.0), false],
	]
	for r in rows:
		var name_label := Label.new()
		name_label.text = r[0]
		name_label.add_theme_color_override("font_color", UiTheme.MUTED)
		name_label.custom_minimum_size = Vector2(190, 0)
		grid.add_child(name_label)
		var value := Label.new()
		value.text = String(r[1]) + _delta(float(r[2]), float(r[3]), r[4])
		value.add_theme_color_override("font_color", _delta_color(float(r[2]), float(r[3]), r[4]))
		value.custom_minimum_size = Vector2(290, 0)
		grid.add_child(value)
	var groups := Label.new()
	var parts: Array = []
	for g in run.groups:
		parts.append(_group_text(g))
	groups.text = "Groups: " + ", ".join(parts)
	groups.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(groups)
	if int(run.ults) > 0:
		var windows := Label.new()
		windows.text = "Inside ultimate windows (%.0fs): dealt %d, took %d, avoided %d, healed %d" % [run.get("ult_time", 0.0), run.get("ult_dealt", 0.0), run.get("ult_taken", 0.0), run.get("ult_prevented", 0.0), run.get("ult_healed", 0.0)]
		windows.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(windows)
	if not run.events.is_empty():
		var events := Label.new()
		var list: Array = []
		for key in run.events:
			list.append("%s x%d" % [key, run.events[key]])
		events.text = "Passive and class events: " + ", ".join(list)
		events.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		events.add_theme_color_override("font_color", UiTheme.MUTED)
		box.add_child(events)
	var text := _result_text(run)
	var shown := TextEdit.new()
	shown.text = text
	shown.editable = false
	shown.custom_minimum_size = Vector2(0, 80)
	shown.add_theme_font_size_override("font_size", 14)
	shown.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(shown)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var copy := _action("COPY RESULTS", UiTheme.GOLD, func() -> void: pass)
	copy.pressed.connect(func() -> void:
		WebField.copy(text)
		DisplayServer.clipboard_set(text)
		copy.text = "COPIED")
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(copy)
	var again := _action("RUN AGAIN", UiTheme.TEXT, func() -> void: _launch("bench"))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(again)
	var menu := _action("MENU", UiTheme.MUTED, _back_to_menu)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(menu)


func _show_history() -> void:
	var history := _load_history()
	_history_layer = CanvasLayer.new()
	_history_layer.layer = 50
	add_child(_history_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_history_layer.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	_history_layer.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(UiTheme.title_label("LAST RUNS", 36, UiTheme.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var label := Label.new()
	var lines: Array = []
	for i in range(history.size() - 1, -1, -1):
		var run: Dictionary = history[i]
		lines.append("%s  %s  %s  %s  %s  time %.0fs  dps %.1f  taken %d  avoided %d  healed %d  (%s / %s / %s)" % [run.get("date", "").substr(5, 11).replace("T", " "), run.get("fighter_name", "?"), run.get("level", "?"), run.get("bot", "you"), run.get("outcome", "?"), float(run.get("time", 0.0)), float(run.get("dps", 0.0)), int(run.get("taken", 0.0)), int(run.get("prevented", 0.0)), int(run.get("healed", 0.0)), run.get("passive", "?"), run.get("ult", "?"), run.get("power", "?")])
	label.text = "No runs yet." if lines.is_empty() else "\n".join(lines)
	label.add_theme_font_size_override("font_size", 16)
	scroll.add_child(label)
	var close := _action("BACK", UiTheme.TEXT, func() -> void: _history_layer.queue_free())
	box.add_child(close)


# --- Free fight --------------------------------------------------------------------

func _build_tools() -> void:
	# The fight's touch controls take every tap on screen, so the tools show
	# while the game is paused (the pause button) instead of behind a button.
	_tools = CanvasLayer.new()
	_tools.layer = 25
	_tools.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tools)
	_tools_panel = PanelContainer.new()
	_tools_panel.visible = false
	_tools_panel.add_theme_stylebox_override("panel", UiTheme.card(10.0))
	_tools_panel.position = Vector2(20, 110)
	_tools.add_child(_tools_panel)
	var watcher := Timer.new()
	watcher.wait_time = 0.15
	watcher.autostart = true
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	watcher.timeout.connect(func() -> void: _tools_panel.visible = get_tree().paused)
	_tools.add_child(watcher)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_tools_panel.add_child(grid)
	for kind in ["zombie", "skeleton", "runner", "brawler", "hulk", "mage", "priest", "armor", "boss"]:
		grid.add_child(_tool(kind.to_upper() if kind != "boss" else "CHAMPION", func() -> void: _free_spawn(kind)))
	var elite := _tool("ELITE: OFF", func() -> void: pass)
	elite.toggle_mode = true
	elite.toggled.connect(func(on: bool) -> void:
		_elite_on = on
		elite.text = "ELITE: " + ("ON" if on else "OFF"))
	grid.add_child(elite)
	var god := _tool("GOD: OFF", func() -> void: pass)
	god.toggle_mode = true
	god.toggled.connect(func(on: bool) -> void:
		_god_on = on
		god.text = "GOD: " + ("ON" if on else "OFF"))
	grid.add_child(god)
	var freeze := _tool("FREEZE: OFF", func() -> void: pass)
	freeze.toggle_mode = true
	freeze.toggled.connect(func(on: bool) -> void:
		_frozen_on = on
		freeze.text = "FREEZE: " + ("ON" if on else "OFF")
		for enemy in $Enemies.get_children():
			enemy.set_physics_process(not on))
	grid.add_child(freeze)
	grid.add_child(_tool("FILL ULT", func() -> void: _player.ult.fill()))
	grid.add_child(_tool("CLEAR", func() -> void:
		for enemy in $Enemies.get_children():
			enemy.queue_free()))
	grid.add_child(_tool("MENU", _back_to_menu))


func _tool(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(pressed)
	return button


func _free_spawn(kind: String) -> void:
	var ahead := -_player.global_basis.z
	ahead.y = 0.0
	var at := _player.global_position + ahead.normalized() * 5.0 + Vector3(0, 0.1, 0)
	var enemy := _make_enemy(kind + (":elite" if _elite_on and kind != "boss" else ""), at)
	if _frozen_on:
		enemy.set_physics_process(false)
