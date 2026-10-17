extends "res://training.gd"
## Daily drills (GameState.drill_pick): score runs in the training ring that
## get harder the longer you last. The first run of each drill each day pays
## coins and XP for your score (GameState.claim_drill); after that it's
## practice, chasing your best.
##   pads  - Pad Work: the coach calls a combo as punch chips; throw it in
##           order (hooks and uppercuts set up) before the clock runs out.
##           Combos get longer and the clock shorter. Three misses and done.
##   slip  - Slip Line: the dummy throws; dodge it. Faster, less warning,
##           longer combos as you go. Counters score extra. Three hits and done.
##   bags  - Heavy Bags: 60 seconds to knock bags off the rack. Points for
##           the damage you do (set-up heavies hit hardest) and every bag
##           you knock off; each bag on the rack is tougher than the last.

const BAG_SCENE := preload("res://heavy_bag.tscn")
const LIVES := 3
const BAG_TIME := 60.0
const BAG_SLOTS := [Vector3(-1.5, 0.05, -2.9), Vector3(0, 0.05, -3.3), Vector3(1.5, 0.05, -2.9)]
const RACK_HEIGHT := 2.75
## Pad Work: seconds for a combo at level 1, how much faster each level gets,
## and the floor (no human makes a 6-punch combo in 0.9s).
const PADS_TIME := 7.0
const PADS_SPEEDUP := 0.95
const PADS_FLOOR := 0.9
## Slip Line: dodges per level; the dummy's windup shrinks each level.
const SLIP_PER_LEVEL := 5
const SLIP_SPEEDUP := 0.965
const SLIP_FLOOR := 0.3
## Heavy Bags: a bag's HP in your punches (base damage), +this per bag.
const BAG_HP := 14.0
const BAG_HP_STEP := 2.5
const NAMES := {"pads": "PAD WORK", "slip": "SLIP LINE", "bags": "HEAVY BAGS"}

var _kind := "pads"
var _score := 0
var _lives := LIVES
var _level := 1
var _running := false
var _done := false
var _claim := {}
# Pad Work.
var _pad_combo: Array = []
## Which hand throws each punch of the combo ("left" / "right").
var _pad_hands: Array = []
var _pad_at := 0
var _pad_time := 0.0
var _pad_clock := 0.0
# Slip Line.
var _dodges := 0
# Heavy Bags.
var _bag_clock := BAG_TIME
var _bags_knocked := 0
# UI.
var _ui: CanvasLayer
var _score_label: Label
var _level_label: Label
var _lives_row: HBoxContainer
var _chips: HBoxContainer
var _clock_bar: ProgressBar
var _clock_label: Label


func _ready() -> void:
	_kind = GameState.drill_pick if NAMES.has(GameState.drill_pick) else "pads"
	Sfx.play_music("arena")
	Enemy.max_attackers = 1
	$Moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	Look.tune_environment($WorldEnvironment.environment, "ring")
	_build_torches()
	_build_ring()
	Sfx.stop_ambience()
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
	_hud.end_run_requested.connect(_go_to_camp)
	_hud.set_leave_text("Leave the drill")
	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)
	_hud.set_info(NAMES[_kind])
	_hud.get_node("%LevelPanel").visible = false
	# Drills are about the punches, not your knuckles: punches cost nothing.
	_player.punch_cost_scale = 0.0
	_player.punch_connected.connect(_on_drill_punch)
	_player.dodged.connect(_on_drill_dodge)
	_player.attacked.connect(_on_drill_hit.unbind(1))
	if _kind == "bags":
		_build_rack()
	else:
		_dummy = DUMMY_SCENE.instantiate()
		_dummy.setup(_player, false)
		_dummy.position = DUMMY_POSITION
		$Enemies.add_child(_dummy)
		_dummy.passive = true
		_dummy.set_level(2)
		# Its name tag would sit on the combo chips: hide it.
		_dummy._hp_label.modulate.a = 0.0
	_build_drill_ui()
	_countdown()


func _unhandled_input(_event: InputEvent) -> void:
	pass  # No training keys here.


func _process(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.2 + sin(_torch_time * 11.0 + i * 1.7) * 0.25
	if not _running:
		return
	match _kind:
		"pads":
			_pad_clock -= delta
			_clock_bar.value = maxf(_pad_clock, 0.0) / _pad_time * 100.0
			if _pad_clock <= 0.0:
				_pad_miss("TOO SLOW")
		"bags":
			_bag_clock -= delta
			_clock_bar.value = maxf(_bag_clock, 0.0) / BAG_TIME * 100.0
			_clock_label.text = "%d" % ceili(maxf(_bag_clock, 0.0))
			if _bag_clock <= 0.0:
				_finish()


func _countdown() -> void:
	await get_tree().create_timer(0.6).timeout
	for word in ["3", "2", "1"]:
		if not is_inside_tree():
			return
		_hud.announce_small(word)
		Sfx.play("tick", 0.0, 1.2)
		await get_tree().create_timer(0.7).timeout
	_hud.announce("GO!")
	Sfx.play("bell")
	_running = true
	match _kind:
		"pads":
			_next_pad()
		"slip":
			# It follows you round the ring, throwing level 2 punches.
			_dummy.passive = false
			_dummy.set_level(Dummy.RING_LEVEL)
			_set_slip_level(1)
		"bags":
			pass


# --- Pad Work -----------------------------------------------------------------------

## A combo for this level: 2 punches at first, up to 6. Hooks and uppercuts
## join from level 3, always placed where they can be set up.
## A combo that follows the combo rules, tracking hands: the jab is the left,
## the cross the right, a hook or uppercut comes from the hand that didn't
## punch last. Hands alternate (one double jab allowed), and every hook or
## uppercut is set up (after a jab or cross, or an uppercut after a hook).
## Fills _pad_hands too.
func _make_combo() -> Array:
	var length := clampi(2 + (_level - 1) / 3, 2, 6)
	var heavies := _level >= 3
	var combo := [["jab", "cross"].pick_random()]
	var hand := "left" if combo[0] == "jab" else "right"
	_pad_hands = [hand]
	while combo.size() < length:
		var last: String = combo[-1]
		var other := "right" if hand == "left" else "left"
		var straight := "jab" if other == "left" else "cross"
		var options := [straight, straight]
		if last == "jab" and (combo.size() < 2 or combo[-2] != "jab"):
			options.append("jab")  # The double jab (the right hand comes next).
		if heavies and last in ["jab", "cross"]:
			options.append_array(["hook", "uppercut"])
		elif heavies and last == "hook":
			options.append("uppercut")
		var pick: String = options.pick_random()
		if not (pick == "jab" and last == "jab"):
			hand = other
		combo.append(pick)
		_pad_hands.append(hand)
	return combo


func _next_pad() -> void:
	_pad_combo = _make_combo()
	_pad_at = 0
	_pad_time = maxf(PADS_TIME * pow(PADS_SPEEDUP, _level - 1) * (0.6 + 0.1 * _pad_combo.size()), PADS_FLOOR)
	_pad_clock = _pad_time
	_fill_chips()


func _on_drill_punch(type: String, kind: String) -> void:
	if not _running:
		return
	match _kind:
		"pads":
			_pad_punch(type, kind)
		"slip":
			if kind == "counter":
				_add_score(30 + 3 * _level, "COUNTER")
		"bags":
			pass


func _pad_punch(type: String, _kind_of_hit: String) -> void:
	var heavy: bool = Player.PUNCHES[type].heavy
	# Only the input is judged: the punch the coach called (and, with Shift /
	# Ctrl + click hooks, the hand). The combo itself is built to the rules.
	var right: bool = type == _pad_combo[_pad_at]
	if right and heavy and not Controls.direct_punches() and not Controls.pad():
		right = _player.last_hand() == _pad_hands[_pad_at]
	if not right:
		_pad_miss("WRONG PUNCH")
		return
	_add_score(25 if heavy else 10)
	_pad_at += 1
	if _pad_at >= _pad_combo.size():
		var speed := _pad_clock / _pad_time
		_add_score(roundi((40 + 15 * _pad_combo.size()) * (1.0 + speed) * (1.0 + 0.05 * _level)), "COMBO!")
		Sfx.play("coin", -4.0, 1.3)
		_level += 1
		_update_drill_ui()
		_next_pad()
		return
	_fill_chips()


func _pad_miss(why: String) -> void:
	_lose_life(why)
	if _running:
		_next_pad()


# --- Slip Line ----------------------------------------------------------------------

## The dummy's attacks for a level: single punches, then combos, then long
## ones; the warning thins out and the windups shrink.
func _set_slip_level(level: int) -> void:
	_level = level
	var pool: Array = [["jab"], ["cross"], ["left_hook"], ["right_hook"], ["uppercut"]]
	if level >= 3:
		pool.append_array([["jab", "cross"], ["jab", "right_hook"], ["cross", "left_hook"]])
	if level >= 6:
		pool.append_array([["jab", "cross", "left_hook"], ["cross", "left_hook", "uppercut"], ["jab", "jab", "cross"]])
	if level >= 10:
		pool.append_array([["jab", "cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "uppercut"]])
	_dummy.combo_pool = pool
	_dummy.set_telegraph(clampi(1 + (level - 1) / 3, 1, Dummy.TELEGRAPHS.size()))
	_dummy.windup_scale = maxf(Dummy.TELEGRAPHS[_dummy.telegraph - 1].windup_scale * pow(SLIP_SPEEDUP, level - 1), SLIP_FLOOR)
	_update_drill_ui()


func _on_drill_dodge(move: String) -> void:
	if not _running or _kind != "slip" or move in ["jump", "ghost"]:
		return
	var clean := move.begins_with("clean_")
	_add_score((25 if clean else 12) + 2 * _level, "CLEAN!" if clean else "")
	_dodges += 1
	if _dodges % SLIP_PER_LEVEL == 0:
		_set_slip_level(_level + 1)
		_hud.announce_small("LEVEL %d" % _level)


func _on_drill_hit() -> void:
	if not _running:
		return
	_player.restore()
	if _kind == "slip":
		_lose_life("HIT")


# --- Heavy Bags ---------------------------------------------------------------------

func _build_rack() -> void:
	var wood := Enemy._material(Color(0.28, 0.18, 0.1))
	var iron := Enemy._material(Color(0.2, 0.2, 0.22), 0.6)
	for x in [-2.6, 2.6]:
		_add_mesh($Decorations, Enemy._box(Vector3(0.18, RACK_HEIGHT + 0.2, 0.18)), wood, Vector3(x, (RACK_HEIGHT + 0.2) / 2.0, -3.1))
	_add_mesh($Decorations, Enemy._box(Vector3(5.4, 0.16, 0.16)), iron, Vector3(0, RACK_HEIGHT + 0.1, -3.1))
	for slot in BAG_SLOTS.size():
		_hang_bag(slot)


func _hang_bag(slot: int) -> void:
	var bag: HeavyBag = BAG_SCENE.instantiate()
	bag.max_hp = GameState.get_damage() * (BAG_HP + BAG_HP_STEP * _bags_knocked)
	bag.setup(_player, false)
	bag.position = BAG_SLOTS[slot]
	$Enemies.add_child(bag)
	bag.died.connect(func(_e: Enemy) -> void: _on_bag_knocked(slot))
	# Score the damage each punch does (in your base punches, so a set-up
	# uppercut is worth far more than a jab).
	bag.set_meta("hp_before", bag.max_hp)


func _on_bag_knocked(slot: int) -> void:
	if _done:
		return
	_bags_knocked += 1
	_level = _bags_knocked + 1
	_add_score(100 + 25 * _bags_knocked, "KNOCKED OFF!")
	Sfx.play("coin", -2.0, 1.1)
	_update_drill_ui()
	await get_tree().create_timer(0.9).timeout
	if is_inside_tree() and not _done:
		_hang_bag(slot)


func _physics_process(_delta: float) -> void:
	if _kind != "bags" or not _running:
		return
	# Damage points: each bag's HP drop since last frame, in base punches.
	for node in $Enemies.get_children():
		var bag := node as HeavyBag
		if bag == null:
			continue
		var before: float = bag.get_meta("hp_before", bag.max_hp)
		var now := maxf(bag.hp, 0.0)
		if now < before:
			_add_score(roundi((before - now) / maxf(GameState.get_damage(), 0.1) * 10.0))
			bag.set_meta("hp_before", now)


# --- Score, lives, end ----------------------------------------------------------------

func _add_score(points: int, shout := "") -> void:
	_score += points
	_score_label.text = "%d" % _score
	_score_label.pivot_offset = _score_label.size / 2.0
	var pop := _score_label.create_tween()
	pop.tween_property(_score_label, "scale", Vector2(1.18, 1.18), 0.06)
	pop.tween_property(_score_label, "scale", Vector2.ONE, 0.12)
	if shout != "":
		_hud.announce_small("%s  +%d" % [shout, points])


func _lose_life(why: String) -> void:
	_lives -= 1
	Sfx.play("deny", 0.0, 0.9)
	_hud.announce_small(why)
	_update_drill_ui()
	if _lives <= 0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	_running = false
	if _dummy:
		_dummy.passive = true
	Sfx.play("bell")
	_hud.announce("TIME!" if _kind == "bags" else "DONE!")
	_claim = GameState.claim_drill(_kind, _score, _level)
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree():
		_show_results()


# --- UI -------------------------------------------------------------------------------

func _build_drill_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var top := VBoxContainer.new()
	top.anchor_left = 0.5
	top.anchor_right = 0.5
	top.offset_left = -300
	top.offset_right = 300
	top.offset_top = 70
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)
	_score_label = UiTheme.title_label("0", 56, UiTheme.GOLD)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_constant_override("outline_size", 10)
	top.add_child(_score_label)
	_level_label = UiTheme.title_label("", 18, UiTheme.TEXT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_level_label)
	_lives_row = HBoxContainer.new()
	_lives_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_lives_row.add_theme_constant_override("separation", 6)
	top.add_child(_lives_row)
	_clock_bar = ProgressBar.new()
	_clock_bar.show_percentage = false
	_clock_bar.custom_minimum_size = Vector2(360, 10)
	_clock_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_clock_bar.value = 100.0
	_clock_bar.visible = _kind != "slip"
	top.add_child(_clock_bar)
	_clock_label = UiTheme.title_label("", 22, UiTheme.TEXT)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.visible = _kind == "bags"
	top.add_child(_clock_label)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("separation", 6)
	top.add_child(_chips)
	_update_drill_ui()


func _update_drill_ui() -> void:
	_level_label.text = ("BAG %d" if _kind == "bags" else "LEVEL %d") % _level
	for child in _lives_row.get_children():
		child.queue_free()
	if _kind != "bags":
		for i in LIVES:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(16, 16)
			var lit := i < _lives
			pip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BAD if lit else Color(0, 0, 0, 0.45), Color(UiTheme.BAD, 0.8), 2, 8))
			_lives_row.add_child(pip)


## The Pad Work combo as chips: done ones green, the next one gold. Each
## chip also shows its key.
func _fill_chips() -> void:
	for child in _chips.get_children():
		child.queue_free()
	for i in _pad_combo.size():
		var type: String = _pad_combo[i]
		var done := i < _pad_at
		var next := i == _pad_at
		var color := DONE_COLOR if done else (GOAL_COLOR if next else Color(1, 1, 1, 0.3))
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiTheme.box(Color(color, 0.22) if done or next else Color(0, 0, 0, 0.5), color, 2, 6, 8.0))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", -2)
		chip.add_child(column)
		var title := type.to_upper()
		if type in ["hook", "uppercut"] and not Controls.direct_punches() and not Controls.pad():
			title = "%s %s" % ["L" if _pad_hands[i] == "left" else "R", title]  # Shift / Ctrl + that hand's click.
		var name_label := UiTheme.title_label(title, 22, color.lightened(0.2) if done or next else UiTheme.MUTED)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var key := _coach_label(13, UiTheme.MUTED)
		key.text = Controls.text(type)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.autowrap_mode = TextServer.AUTOWRAP_OFF
		column.add_child(key)
		_chips.add_child(chip)


func _show_results() -> void:
	# The fight's over: with the player still "fighting", the controller's menu
	# cursor stays hidden (Pad) and the buttons can't be reached.
	_player.active = false
	# The card must stay clickable: pausing (Esc / Start, or the browser losing
	# focus when the mouse is released) froze it while the cursor still moved.
	_hud._can_pause = false
	if get_tree().paused:
		_hud.set_paused(false)
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(24.0))
	card.custom_minimum_size.x = 460
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	for line in [
		[NAMES[_kind], 26, UiTheme.MUTED],
		["%d" % _score, 72, UiTheme.GOLD],
		["NEW BEST!" if _claim.get("new_best", false) else "BEST  %d" % int(_claim.get("best", _score)), 22, DONE_COLOR if _claim.get("new_best", false) else UiTheme.TEXT],
		[("BAGS KNOCKED OFF  %d" % _bags_knocked) if _kind == "bags" else ("REACHED LEVEL %d" % _level), 18, UiTheme.MUTED],
	]:
		var label := UiTheme.title_label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	var reward := IconLabel.new()
	reward.font_size = 24
	if _claim.get("paid", false):
		reward.text = "TODAY'S REWARD   +%d {coins}   +%d {xp}" % [_claim.coins, _claim.xp]
		reward.color = UiTheme.GOOD
	else:
		reward.text = "PRACTICE  -  today's reward is claimed"
		reward.color = UiTheme.MUTED
	column.add_child(reward)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	var again := Button.new()
	again.text = "Again"
	again.theme_type_variation = "PrimaryButton"
	again.custom_minimum_size = Vector2(180, 52)
	again.pressed.connect(Loading.reload)
	buttons.add_child(again)
	var back := Button.new()
	back.text = "Back to camp"
	back.custom_minimum_size = Vector2(180, 52)
	back.pressed.connect(_go_to_camp)
	buttons.add_child(back)
	again.grab_focus.call_deferred()
