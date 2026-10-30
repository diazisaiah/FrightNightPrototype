class_name Training
extends Node3D
## Training ground: an unkillable practice dummy for learning defense and
## counters. Starts with a guided tutorial the first time (T skips or restarts
## it). In free practice, number keys change its level; Up/Down change how much
## its attacks are telegraphed. No coins or XP; knuckles refill instead of
## ending the session.

const DUMMY_SCENE := preload("res://dummy.tscn")
const DUMMY_POSITION := Vector3(0, 0.05, -3.0)
## Boxing ring around the player's start and the dummy. Ropes block movement.
const RING_CENTER := Vector3(0, 0, -1.5)
const RING_HALF_SIZE := 4.0
const RING_ROPE_HEIGHTS := [0.5, 0.85, 1.2]
const TORCH_COUNT := 6
const TORCH_RADIUS := 7.0
## Seconds to show "done" before moving to the next tutorial step.
const STEP_PAUSE := 1.6
const GOAL_COLOR := Color(1.0, 0.82, 0.35)
const DONE_COLOR := Color(0.45, 1.0, 0.5)
const SINGLE_STRAIGHTS := [["jab"], ["cross"]]
const SINGLE_HOOKS := [["left_hook"], ["right_hook"]]
## The guided tutorial (2026-10-29: shorter and easier, and it ends in real
## fights). goals: {event: count} that all need reaching.
## dummy: "passive" stands still; otherwise it throws from combos.
## telegraph: Dummy.TELEGRAPHS index; slow: extra windup multiplier.
## fight: [[monster, count], ...] in place of the dummy (FIGHT_SCENES).
## Events: move (meters), jab/cross/hook/uppercut (landed), slip/roll/
## back_step/dodge (any), counter, combo (a 2+ hit combo fully dodged), ko.
## Each step: a short line, the keys as keycap chips ([keys, what]), and the
## glove color it teaches ("cue"). <move> tokens become the player's keys.
## The plan is STEPS_START, then the dodge steps for your mode, then STEPS_END.
const STEPS_START := [
	{"title": "MOVE", "goals": {"move": 5}, "dummy": "passive",
		"text": "Walk around the ring.",
		"keys": [["<move>", "Move"], ["<look>", "Look"], ["<sprint>", "Sprint"]]},
	{"title": "JAB AND CROSS", "goals": {"jab": 2, "cross": 2}, "dummy": "passive",
		"text": "Walk up and hit the dummy.",
		"keys": [["<jab>", "Jab"], ["<cross>", "Cross"]]},
	{"title": "SET IT UP", "goals": {"setup": 2}, "dummy": "passive", "costs": true,
		"text": "Hooks and uppercuts hit hard after a jab, a cross, or a slip or roll to that side. Thrown cold they're SLOPPY. Every punch costs knuckle HP.",
		"keys": [["<jab> / <cross>", "Set up"], ["<hook>", "Hook"], ["<uppercut>", "Uppercut"]]},
	{"title": "COMBOS", "goals": {"drill": 2}, "dummy": "passive", "costs": true,
		"text": "Throw each combo in order.",
		"drills": [["jab", "cross", "hook"], ["jab", "cross", "hook", "uppercut"]],
		"keys": [["<jab>", "Jab"], ["<cross>", "Cross"], ["<hook>", "Hook"], ["<uppercut>", "Uppercut"]]},
]
## Weenie Hut Junior Mode: one key a side picks the dodge for you.
const STEPS_JUNIOR := [
	{"title": "DODGE", "goals": {"dodge": 4},
		"text": "A glowing glove is a punch coming. Dodge just before it lands. Hooks: dodge away from the glove.",
		"keys": [["<slip>", "Dodge"]],
		"combos": [["jab"], ["cross"], ["left_hook"], ["right_hook"], ["uppercut"]], "telegraph": 1, "slow": 1.6},
]
## Pro Gamer Mode: each dodge on its own key.
const STEPS_PRO := [
	{"title": "SLIP", "goals": {"slip": 2}, "cue": "blue",
		"text": "A blue glove is a straight. Slip it just before it lands.",
		"keys": [["<slip>", "Slip"]],
		"combos": SINGLE_STRAIGHTS, "telegraph": 1, "slow": 1.6},
	{"title": "ROLL", "goals": {"roll": 2}, "cue": "orange",
		"text": "An orange glove is a hook. Roll away from it.",
		"keys": [["<roll>", "Roll"]],
		"combos": SINGLE_HOOKS, "telegraph": 1, "slow": 1.6},
	{"title": "BACK STEP", "goals": {"back_step": 2}, "cue": "red",
		"text": "A red glove is an uppercut or slam. Step back.",
		"keys": [["<back_step>", "Back step"]],
		"combos": [["uppercut"], ["slam"]], "telegraph": 1, "slow": 1.6},
]
const STEPS_END := [
	{"title": "COUNTER", "goals": {"counter": 2},
		"text": "After a dodge, punch with the hand that glows. Counters hit harder.",
		"keys": [["<slip>", "Dodge"], ["<jab> / <cross>", "Counter"]],
		"combos": SINGLE_STRAIGHTS, "telegraph": 1, "slow": 1.5},
	{"title": "READ THE COMBO", "goals": {"combo": 1, "counter": 1},
		"text": "The next glove lights up as each punch comes. Dodge them all, then counter.",
		"combos": [["jab", "cross"], ["jab", "right_hook"], ["cross", "left_hook"]], "telegraph": 1, "slow": 1.4},
	{"title": "ULTIMATE", "goals": {"ult": 1}, "ult": true,
		"combos": SINGLE_STRAIGHTS, "telegraph": 1, "slow": 1.4},
	{"title": "TAKE TURNS", "goals": {"ko": 2}, "fight": [["zombie", 2]],
		"text": "Two zombies. Only one fights at a time; the other waits its turn. Back step the slams, then hit back.",
		"keys": [["<back_step>", "Back step"]]},
	{"title": "SLIP THE ARROWS", "goals": {"slip": 2, "ko": 1}, "fight": [["skeleton", 1]],
		"text": "A skeleton shoots from range. Slip its arrows, then close in.",
		"keys": [["<slip>", "Slip"]]},
	{"title": "DODGE THE COMBO", "goals": {"dodge": 3, "ko": 1}, "fight": [["brawler", 1]],
		"text": "A brawler throws combos. Dodge every punch, then counter.",
		"keys": [["<slip>", "Dodge"], ["<jab> / <cross>", "Counter"]]},
]
## The monsters a fight step brings in.
const FIGHT_SCENES := {"zombie": "res://zombie.tscn", "skeleton": "res://skeleton.tscn", "brawler": "res://brawler.tscn"}
## In the fights, monsters go down in this many punches (a counter counts
## 1.5), and you in this many of their hits.
const FIGHT_HITS := 6
## The ultimate step, by class: [line, what the key does]. The meter starts full.
const ULT_TIPS := {
	"berserker": ["Walk up to the dummy, then:", "Inferno Uppercut"],
	"combo_master": ["Then alternate hands, fast.", "Temporal Break"],
	"counter_master": ["Every attack gets slipped and countered for you.", "Riposte Stance"],
	"free_runner": ["Look at the dummy, then:", "Highlight Reel"],
	"wise_guy": ["Look at the dummy and run your mouth:", "Big Mouth"],
	"elementalist": ["Then keep punching: the elements fly.", "Elemental Fists"],
}
const CUE_COLORS := {"blue": Color(0.35, 0.65, 1.0), "orange": Color(1.0, 0.6, 0.2), "red": Color(1.0, 0.3, 0.25)}

var _dummy: Dummy
## The steps this run (STEPS_START + your mode's dodges + STEPS_END).
var _plan: Array = []
## The monsters of the fight step under way.
var _fighters: Array[Enemy] = []
## The ring (ropes, canvas and the walls along the ropes).
var _ring: Node3D
var _torches: Array[OmniLight3D] = []
var _torch_time := 0.0
## Index into _plan, or -1 in free practice.
var _step := -1
var _progress := {}
var _step_done := false
var _last_position := Vector3.ZERO
var _coach: PanelContainer
var _coach_step: Label
var _coach_title: Label
var _coach_text: Label
var _coach_keys: HFlowContainer
var _coach_goals: VBoxContainer
var _coach_warning: Label
## Free practice: dummy level and telegraph, with their keys.
var _practice: PanelContainer
var _practice_rows: VBoxContainer
var _warning_tween: Tween
var _skip_cap: PanelContainer
## Combo drills: the chip row, which drill, and how far into it.
var _drill_row: HFlowContainer
var _drill := 0
var _drill_at := 0

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _ready() -> void:
	add_to_group("map_scene")  # A tap of the controller emote button opens the map.
	Sfx.play_music("camp")
	Enemy.max_attackers = 1
	$Moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	Look.tune_environment($WorldEnvironment.environment, "ring")
	_build_torches()
	_build_ring()
	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	Sfx.stop_ambience()
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.power_status_changed.connect(_hud.set_power_status)
	_player.class_event.connect(_hud.show_class_event)
	_player.knuckles_broken.connect(_on_knuckles_broken)
	_player.dodged.connect(_on_dodged)
	_player.punch_connected.connect(_on_punch_connected)
	_player.ult.used.connect(func(_c: String) -> void: _add_progress("ult"))
	_player.attacked.connect(_on_attacked.unbind(1))
	_hud.end_run_requested.connect(_go_to_camp)
	_hud.set_leave_text("Leave training")
	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)

	_dummy = DUMMY_SCENE.instantiate()
	_dummy.setup(_player, false)
	_dummy.position = DUMMY_POSITION
	$Enemies.add_child(_dummy)
	_dummy.combo_done.connect(_on_combo_done)
	_build_coach()
	Controls.watch(self, _refresh_keys)
	if GameState.tutorial_done:
		_end_tutorial()
		_hud.announce("Training")
	else:
		_start_step(0)
		_hud.announce("Tutorial")


func _unhandled_input(event: InputEvent) -> void:
	# Controller: the map button skips the tutorial, then cycles the dummy.
	if event.is_action_pressed("map") and not event is InputEventKey:
		if _step >= 0:
			_finish_tutorial()
		else:
			_set_dummy_level(_dummy.level % Dummy.MAX_LEVEL + 1)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_T:
		if _step >= 0:
			_finish_tutorial()
		else:
			_start_step(0)
			_hud.announce("Tutorial")
		return
	if _step >= 0:
		return  # The tutorial sets up the dummy.
	var level: int = event.physical_keycode - KEY_0
	if level >= 1 and level <= Dummy.MAX_LEVEL:
		_set_dummy_level(level)
	elif event.physical_keycode == KEY_UP or event.physical_keycode == KEY_DOWN:
		# The list runs from most warning (top) to least, so Up = more warning.
		var step := -1 if event.physical_keycode == KEY_UP else 1
		_dummy.set_telegraph(_dummy.telegraph + step)
		_update_info()
		_hud.announce_small("Telegraph: " + Dummy.TELEGRAPHS[_dummy.telegraph - 1].name.get_slice("  ", 0))


func _set_dummy_level(level: int) -> void:
	_dummy.set_level(level)
	if level != Dummy.RING_LEVEL:
		_dummy.global_position = DUMMY_POSITION
		_dummy.velocity = Vector3.ZERO
	_update_info()
	_hud.announce_small("Dummy level %d" % level)


func _process(delta: float) -> void:
	_torch_time += delta
	if _step >= 0 and not _step_done and _plan[_step].goals.has("move"):
		var moved := _player.global_position - _last_position
		moved.y = 0.0
		_last_position = _player.global_position
		_add_progress("move", moved.length())
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25


func _exit_tree() -> void:
	TimeFx.clear()


func _on_knuckles_broken() -> void:
	_player.restore()
	_hud.add_feed("Knuckles broke - refilled (training)", Color(1, 0.6, 0.4))


# --- Tutorial ---------------------------------------------------------------------

## The steps for your control mode.
static func plan() -> Array:
	return STEPS_START + (STEPS_JUNIOR if Controls.junior() else STEPS_PRO) + STEPS_END


func _start_step(index: int) -> void:
	if index == 0:
		_plan = plan()
	_step = index
	_step_done = false
	_progress.clear()
	_last_position = _player.global_position
	var step: Dictionary = _plan[index]
	_dummy.set_level(2)
	_dummy.global_position = DUMMY_POSITION
	_dummy.velocity = Vector3.ZERO
	_dummy.passive = step.get("dummy", "") == "passive"
	_dummy.combo_pool = step.get("combos", [])
	_dummy.set_telegraph(step.get("telegraph", 1))
	_dummy.windup_scale *= step.get("slow", 1.0)
	_player.restore()
	_clear_fight()
	if step.has("fight"):
		_start_fight(step.fight)
	_coach.visible = true
	_practice.visible = false
	_hud.get_node("%LevelPanel").visible = false
	_hud.set_info("TUTORIAL")
	_coach_step.text = "STEP %d / %d" % [index + 1, _plan.size()]
	_coach_title.text = step.title
	_coach_title.add_theme_color_override("font_color", GOAL_COLOR)
	if step.has("ult"):
		_coach_text.text = ULT_TIPS[GameState.player_class][0]
	else:
		_coach_text.text = step.text
	_fill_keys(_step_keys(step), step.get("cue", ""))
	_pop(_coach)
	if step.has("ult"):
		_player.ult.fill()
	_coach_warning.text = " "
	_drill_row.visible = false
	if step.has("drills"):
		_start_drill(0)
	_update_goals()


## A fight step: the dummy steps out, the ring comes down (so they move as
## they do in the Arena: one fights while the rest circle, waiting their turn),
## and real monsters come in, at FIGHT_HITS both ways.
func _start_fight(fight: Array) -> void:
	_show_dummy(false)
	_show_ring(false)
	_player.fixed_hit = _player.max_knuckles / FIGHT_HITS
	var spot := 0
	for entry in fight:
		for i in int(entry[1]):
			var enemy: Enemy = load(FIGHT_SCENES[entry[0]]).instantiate()
			enemy.setup(_player, false, {"hp": 1.0, "damage": 1.0, "speed": 1.0, "reward": 0.0, "xp": 0.0, "position": 0.0, "hat": "", "gear": {}})
			var ahead := -_player.global_basis.z
			ahead.y = 0.0
			ahead = ahead.normalized() if ahead.length() > 0.1 else Vector3.FORWARD
			enemy.position = _player.global_position + ahead.rotated(Vector3.UP, -0.5 + 1.0 * spot) * 7.0 + Vector3(0, 0.1, 0)
			$Enemies.add_child(enemy)
			enemy.hits_to_ko = FIGHT_HITS
			if enemy is Boxer:
				# A weak brawler: slow, clear tells.
				enemy.windup_scale *= 1.5
			enemy.died.connect(func(_e: Enemy) -> void: _add_progress("ko"))
			_fighters.append(enemy)
			spot += 1


## The fight's over (or skipped): its monsters go, the dummy comes back.
func _clear_fight() -> void:
	for enemy in _fighters:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_fighters.clear()
	_player.fixed_hit = 0.0
	_show_dummy(true)
	_show_ring(true)


## The ring up (with its walls) or down.
func _show_ring(on: bool) -> void:
	if _ring == null or _ring.visible == on:
		return
	_ring.visible = on
	for shape in _ring.find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred("disabled", not on)
	if on and _player.global_position.distance_to(RING_CENTER) > RING_HALF_SIZE:
		# Back in the ring for the dummy.
		_player.global_position = Vector3(0, 0.1, 0)


func _show_dummy(on: bool) -> void:
	_dummy.visible = on
	_dummy.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_dummy.add_to_group("enemies")
		_dummy.collision_layer = _dummy.get_meta("layer", _dummy.collision_layer)
	elif _dummy.is_in_group("enemies"):
		_dummy.remove_from_group("enemies")
		_dummy.set_meta("layer", _dummy.collision_layer)
		_dummy.collision_layer = 0


## The keycaps a step shows (the ultimate step: the class's ultimate).
func _step_keys(step: Dictionary) -> Array:
	if step.has("ult"):
		return [["<ultimate>", ULT_TIPS[GameState.player_class][1]]]
	return step.get("keys", [])


## Every key on the coach and practice cards follows the bindings and
## whether you're on a controller.
func _refresh_keys() -> void:
	if _skip_cap:
		_skip_cap.get_child(0).text = Controls.key_name("map") if Controls.pad() else "T"
	if _step >= 0:
		_fill_keys(_step_keys(_plan[_step]), _plan[_step].get("cue", ""))
	elif _practice and _practice.visible:
		_update_info()


func _add_progress(event: String, amount := 1.0) -> void:
	if _step < 0 or _step_done:
		return
	var goals: Dictionary = _plan[_step].goals
	if not goals.has(event):
		return
	_progress[event] = minf(_progress.get(event, 0.0) + amount, goals[event])
	_update_goals()
	for goal in goals:
		if _progress.get(goal, 0.0) < goals[goal]:
			return
	_complete_step()


func _update_goals() -> void:
	for child in _coach_goals.get_children():
		child.queue_free()
	var goals: Dictionary = _plan[_step].goals
	for goal in goals:
		var have: float = _progress.get(goal, 0.0)
		var need: int = goals[goal]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := UiTheme.title_label(("Move" if goal == "move" else _goal_name(goal)).to_upper(), 18,
				DONE_COLOR if have >= need else UiTheme.TEXT)
		name_label.custom_minimum_size.x = 150
		row.add_child(name_label)
		for k in need:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(18, 18)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var lit := k < int(have)
			var color := DONE_COLOR if have >= need else GOAL_COLOR
			pip.add_theme_stylebox_override("panel", UiTheme.box(color if lit else Color(0, 0, 0, 0.45), Color(color, 0.8), 2, 9))
			row.add_child(pip)
		_coach_goals.add_child(row)


func _goal_name(goal: String) -> String:
	match goal:
		"back_step":
			return "Back steps"
		"combo":
			return "Combos dodged"
		"clean":
			return "Clean dodges"
		"counter":
			return "Counters"
		"dodge":
			return "Dodges"
		"ult":
			return "Ultimates"
		"cross":
			return "Crosses"
		"setup":
			return "Set-up heavies"
		"drill":
			return "Combos"
		"ko":
			return "Knockouts"
	return goal.capitalize() + "s"


func _complete_step() -> void:
	_step_done = true
	_dummy.passive = true
	_coach_title.text = "NICE!"
	_coach_title.add_theme_color_override("font_color", DONE_COLOR)
	_pop(_coach_title)
	_hud.announce_small("NICE!", DONE_COLOR)
	Sfx.play("tell", -4.0, 1.2)
	var finished := _step
	await get_tree().create_timer(STEP_PAUSE).timeout
	if _step != finished or not _step_done:
		return  # Skipped or restarted meanwhile.
	if _step + 1 < _plan.size():
		_start_step(_step + 1)
	else:
		# The first time through, it pays for your first upgrade.
		var first := not GameState.tutorial_done
		var pay := GameState.cheapest_upgrade() if first else 0
		if pay > 0:
			GameState.add_resource("coins", pay)
		_finish_tutorial()
		_hud.announce("Tutorial complete")
		if pay > 0:
			_hud.announce_small("+%d {coins}   ·   Enough for your first upgrade" % pay, UiTheme.GOLD)


func _finish_tutorial() -> void:
	GameState.tutorial_done = true
	GameState.save_game()
	_end_tutorial()


## Free practice: the dummy's level and telegraph are up to the player.
func _end_tutorial() -> void:
	_step = -1
	_clear_fight()
	_coach.visible = false
	_dummy.passive = false
	_dummy.combo_pool = []
	_dummy.set_level(_dummy.level)
	_dummy.set_telegraph(_dummy.telegraph)
	_update_info()


func _on_dodged(move: String) -> void:
	if move.begins_with("clean_"):
		_add_progress("clean")
		move = move.trim_prefix("clean_")
	_add_progress("dodge")
	if move.begins_with("slip"):
		_add_progress("slip")
	elif move.begins_with("roll"):
		_add_progress("roll")
	elif move == "back_step":
		_add_progress("back_step")


func _on_punch_connected(type: String, kind: String) -> void:
	_add_progress(type)
	if kind == "counter":
		_add_progress("counter")
	if kind == "setup":
		_add_progress("setup")
	if _step >= 0 and _plan[_step].get("costs", false):
		_show_cost(Player.PUNCHES[type].knuckle_cost, Player.PUNCHES[type].heavy and kind != "setup")
	if _step >= 0 and _plan[_step].has("drills") and not _step_done:
		_drill_punch(type, kind)


# --- Combo drills ------------------------------------------------------------------

## The combo being drilled: punch chips that light up as each one lands in
## order (hooks and uppercuts must be set up). A wrong or sloppy punch, or a
## broken combo, starts it over.
func _start_drill(index: int) -> void:
	var drills: Array = _plan[_step].drills
	_drill = index % drills.size()
	_drill_at = 0
	_fill_drill()


func _fill_drill() -> void:
	for child in _drill_row.get_children():
		child.queue_free()
	var drills: Array = _plan[_step].get("drills", [])
	_drill_row.visible = not drills.is_empty()
	if drills.is_empty():
		return
	var combo: Array = drills[_drill]
	for i in combo.size():
		if i > 0:
			var arrow := _coach_label(18, UiTheme.MUTED)
			arrow.text = "->"
			arrow.autowrap_mode = TextServer.AUTOWRAP_OFF
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_drill_row.add_child(arrow)
		var chip := PanelContainer.new()
		var done := i < _drill_at
		var next := i == _drill_at
		var color := DONE_COLOR if done else (GOAL_COLOR if next else Color(1, 1, 1, 0.25))
		chip.add_theme_stylebox_override("panel", UiTheme.box(Color(color, 0.22) if done or next else Color(0, 0, 0, 0.4), color, 2, 6, 6.0))
		var label := UiTheme.title_label(String(combo[i]).to_upper(), 18, color.lightened(0.2) if done or next else UiTheme.MUTED)
		chip.add_child(label)
		_drill_row.add_child(chip)


func _drill_punch(type: String, kind: String) -> void:
	var combo: Array = _plan[_step].drills[_drill]
	var heavy: bool = Player.PUNCHES[type].heavy
	var right: bool = type == combo[_drill_at] and (not heavy or kind == "setup") and _player.combo == _drill_at + 1
	if not right:
		# A fresh start can begin right away with this punch.
		var restart: bool = type == combo[0] and _player.combo <= 1
		_drill_at = 1 if restart else 0
		_coach_warning.text = "SLOPPY: set it up first" if heavy and kind != "setup" and type == combo[_drill_at] else "Start over: %s first" % String(combo[0]).to_upper()
		_coach_warning.add_theme_color_override("font_color", Color(1, 0.55, 0.4))
		_coach_warning.modulate.a = 1.0
		_fill_drill()
		_shake_node(_drill_row)
		return
	_drill_at += 1
	if _drill_at >= combo.size():
		Sfx.play("coin", -4.0, 1.4)
		_coach_warning.text = "NICE!"
		_coach_warning.add_theme_color_override("font_color", DONE_COLOR)
		_coach_warning.modulate.a = 1.0
		_add_progress("drill")
		if not _step_done:
			_start_drill(_drill + 1)
		return
	_fill_drill()


func _shake_node(node: Control) -> void:
	var tween := node.create_tween()
	for i in 4:
		tween.tween_property(node, "position:x", node.position.x + (6.0 if i % 2 == 0 else -6.0), 0.04)
	tween.tween_property(node, "position:x", node.position.x, 0.04)


## A punch's knuckle cost floating off the knuckle bar (SET IT UP, COMBOS).
func _show_cost(cost: float, sloppy: bool) -> void:
	var label := UiTheme.title_label("-%d" % roundi(cost), 26, Color(1, 0.4, 0.35) if sloppy else Color(1, 0.85, 0.75))
	label.add_theme_constant_override("outline_size", 8)
	label.position = Vector2(310 + randf_range(-6, 6), 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y + 34.0, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _on_combo_done(dodged_all: bool, length: int) -> void:
	if dodged_all and length >= 2:
		_add_progress("combo")


## Got hit during the tutorial: say what it was and what would have dodged it.
func _on_attacked() -> void:
	if _step < 0 or _step_done or _plan[_step].has("fight"):
		return
	var cue: Dictionary = Boxer.CUES.get(_dummy._attack, {})
	if cue.is_empty():
		return
	# The answer in your controls (bindings, scheme, keyboard or controller).
	var hint := Controls.cue_hint(_dummy._attack)
	var parts: PackedStringArray = hint.split("  -  ")
	_coach_warning.text = "%s  ->  %s" % [parts[0], parts[1]] if parts.size() == 2 else hint
	_coach_warning.add_theme_color_override("font_color", cue.color.lightened(0.35))
	_coach_warning.modulate.a = 1.0
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_interval(2.0)
	_warning_tween.tween_property(_coach_warning, "modulate:a", 0.0, 0.6)


## The coach: the shared gold-edged card down the left, so the dummy and
## its attack hints stay in view.
func _build_coach() -> void:
	_coach = _side_card()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_coach.add_child(box)
	_coach_step = UiTheme.title_label("", 16, UiTheme.MUTED)
	box.add_child(_coach_step)
	_coach_title = UiTheme.title_label("", 36, GOAL_COLOR)
	box.add_child(_coach_title)
	_coach_text = _coach_label(18, UiTheme.TEXT)
	box.add_child(_coach_text)
	_coach_keys = HFlowContainer.new()
	_coach_keys.add_theme_constant_override("h_separation", 10)
	_coach_keys.add_theme_constant_override("v_separation", 8)
	box.add_child(_coach_keys)
	_drill_row = HFlowContainer.new()
	_drill_row.add_theme_constant_override("h_separation", 6)
	_drill_row.add_theme_constant_override("v_separation", 6)
	_drill_row.visible = false
	box.add_child(_drill_row)
	_coach_goals = VBoxContainer.new()
	_coach_goals.add_theme_constant_override("separation", 6)
	box.add_child(_coach_goals)
	_coach_warning = _coach_label(17, Color(1, 0.5, 0.4))
	box.add_child(_coach_warning)
	var skip := HBoxContainer.new()
	skip.add_theme_constant_override("separation", 8)
	_skip_cap = _keycap("T")
	skip.add_child(_skip_cap)
	var skip_text := _coach_label(14, UiTheme.MUTED)
	skip_text.text = "Skip the tutorial"
	skip_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	skip_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_child(skip_text)
	box.add_child(skip)

	_practice = _side_card()
	var practice_box := VBoxContainer.new()
	practice_box.add_theme_constant_override("separation", 10)
	_practice.add_child(practice_box)
	practice_box.add_child(UiTheme.title_label("PRACTICE", 36, GOAL_COLOR))
	_practice_rows = VBoxContainer.new()
	_practice_rows.add_theme_constant_override("separation", 10)
	practice_box.add_child(_practice_rows)
	_practice.visible = false


func _side_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card.offset_left = 20.0
	card.offset_right = 400.0
	card.offset_top = 104.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiTheme.card(18.0))
	_hud.add_child(card)
	# Under the rest of the HUD, so the pause menu and Settings cover it.
	_hud.move_child(card, 0)
	return card


## Keycaps for this step's inputs, and a swatch of the glove color it teaches.
func _fill_keys(keys: Array, cue: String) -> void:
	for child in _coach_keys.get_children():
		child.queue_free()
	if cue != "":
		var swatch := HBoxContainer.new()
		swatch.add_theme_constant_override("separation", 6)
		var chip := Panel.new()
		chip.custom_minimum_size = Vector2(26, 26)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var color: Color = CUE_COLORS[cue]
		chip.add_theme_stylebox_override("panel", UiTheme.box(color, color.lightened(0.4), 2, 6))
		swatch.add_child(chip)
		var label := UiTheme.title_label(cue.to_upper(), 18, color.lightened(0.2))
		swatch.add_child(label)
		_coach_keys.add_child(swatch)
	for pair in keys:
		var key_row := HBoxContainer.new()
		key_row.add_theme_constant_override("separation", 6)
		key_row.add_child(_keycap(Controls.fill(pair[0])))
		var what := _coach_label(16, UiTheme.MUTED)
		what.text = pair[1]
		what.autowrap_mode = TextServer.AUTOWRAP_OFF
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key_row.add_child(what)
		_coach_keys.add_child(key_row)


## A key drawn as a keycap: bone face, dark lip.
func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var face := UiTheme.box(Color(0.9, 0.88, 0.82), Color(0.35, 0.33, 0.3), 1, 5)
	face.border_width_bottom = 4
	face.content_margin_left = 9
	face.content_margin_right = 9
	face.content_margin_top = 2
	face.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", face)
	var label := Label.new()
	label.text = text.to_upper().replace(" OR ", " / ")
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.08, 0.06, 0.06))
	cap.add_child(label)
	return cap


func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(1.06, 1.06)
	node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _coach_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Free practice: what the dummy is doing and the keys that change it.
func _update_info() -> void:
	_hud.set_info("TRAINING")
	_hud.get_node("%LevelPanel").visible = false
	_practice.visible = true
	for child in _practice_rows.get_children():
		child.queue_free()
	var telegraph: String = Dummy.TELEGRAPHS[_dummy.telegraph - 1].name
	if Controls.pad():
		# On a controller, the map button cycles the dummy's level.
		_practice_row(Controls.key_name("map"), "DUMMY LEVEL %d" % _dummy.level, Dummy.LEVEL_DESCRIPTIONS[_dummy.level - 1])
		_practice_row("Keyboard", "TELEGRAPH", telegraph.get_slice("  (", 0) + "  (Up / Down)")
		return
	_practice_row("1 - %d" % Dummy.MAX_LEVEL, "DUMMY LEVEL %d" % _dummy.level, Dummy.LEVEL_DESCRIPTIONS[_dummy.level - 1])
	_practice_row("UP / DOWN", "TELEGRAPH", telegraph.get_slice("  (", 0))
	_practice_row("T", "TUTORIAL", "Start it again")


func _practice_row(keys: String, title: String, detail: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var cap := _keycap(keys)
	cap.custom_minimum_size.x = 96
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiTheme.title_label(title, 18, UiTheme.TEXT))
	var info := _coach_label(15, UiTheme.MUTED)
	info.text = detail
	texts.add_child(info)
	row.add_child(texts)
	_practice_rows.add_child(row)


func _go_to_camp() -> void:
	get_tree().paused = false
	Loading.go("res://camp.tscn")


func _build_ring() -> void:
	var canvas := Enemy._material(Color(0.32, 0.3, 0.34))
	var post_material := Enemy._material(Color(0.15, 0.15, 0.17), 0.6)
	var rope_material := Enemy._material(Color(0.7, 0.12, 0.1))
	var ring := Node3D.new()
	ring.position = RING_CENTER
	$Decorations.add_child(ring)
	_ring = ring

	var size := RING_HALF_SIZE * 2.0
	_add_mesh(ring, Enemy._box(Vector3(size, 0.04, size)), canvas, Vector3(0, 0.02, 0))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_add_mesh(ring, Enemy._cylinder(0.08, 1.4), post_material, Vector3(x * RING_HALF_SIZE, 0.7, z * RING_HALF_SIZE))
	for height in RING_ROPE_HEIGHTS:
		for side in [-1.0, 1.0]:
			_add_mesh(ring, Enemy._box(Vector3(size, 0.04, 0.04)), rope_material, Vector3(0, height, side * RING_HALF_SIZE))
			_add_mesh(ring, Enemy._box(Vector3(0.04, 0.04, size)), rope_material, Vector3(side * RING_HALF_SIZE, height, 0))

	# Invisible walls along the ropes keep both fighters inside.
	var walls := StaticBody3D.new()
	ring.add_child(walls)
	for side in [-1.0, 1.0]:
		for along_x in [true, false]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(size, 3.0, 0.2) if along_x else Vector3(0.2, 3.0, size)
			shape.shape = box
			shape.position = Vector3(0, 1.5, side * RING_HALF_SIZE) if along_x else Vector3(side * RING_HALF_SIZE, 1.5, 0)
			walls.add_child(shape)


func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3) -> void:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


func _build_torches() -> void:
	var wood := Enemy._material(Color(0.25, 0.17, 0.1))
	var flame := Enemy._glow_material(Color(1.0, 0.55, 0.15))
	for i in TORCH_COUNT:
		var torch := Node3D.new()
		var spot := Vector2.from_angle(TAU * i / TORCH_COUNT) * TORCH_RADIUS
		torch.position = Vector3(spot.x, 0, spot.y)
		$Decorations.add_child(torch)
		var pole := MeshInstance3D.new()
		var pole_mesh := Enemy._cylinder(0.05, 1.6)
		pole_mesh.material = wood
		pole.mesh = pole_mesh
		pole.position.y = 0.8
		torch.add_child(pole)
		var fire := MeshInstance3D.new()
		var fire_mesh := Enemy._box(Vector3(0.14, 0.18, 0.14))
		fire_mesh.material = flame
		fire.mesh = fire_mesh
		fire.position.y = 1.68
		torch.add_child(fire)
		fire.visible = false
		Look.flame(torch, Vector3(0, 1.68, 0))
		var light := Look.fire_light(Color(1.0, 0.6, 0.25), 2.2, 10.0)
		light.position.y = 1.9
		torch.add_child(light)
		_torches.append(light)
