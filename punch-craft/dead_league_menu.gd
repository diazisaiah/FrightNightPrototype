extends Control
## Dead League fight card: five sequential 1v1 bosses over generated key art.

const KEY_ART := preload("res://art/dead_league/dead_league_key_art.png")

var _selected := 0
var _cards: Array[Button] = []
var _detail_name: Label
var _detail_copy: Label
var _best: Label
var _fight: Button
var _readiness: Label
## Five pips: how ready your build is for the selected contender.
var _ready_pips: HBoxContainer
## "POWER 182  vs  240" and a tug-of-war bar between the two.
var _power_line: Label
var _power_bar: Control
var _power_mine := 0
var _power_theirs := 0
var _power_color := Color.WHITE


func _ready() -> void:
	Sfx.play_music("league")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_ambience()
	theme = UiTheme.make()
	_selected = clampi(GameState.dead_league_bout, 0, DeadLeagueRules.BOSS_COUNT - 1)
	if not GameState.dead_league_unlocked(_selected):
		_selected = 0
	_build_ui()
	_refresh_selection()


func _build_ui() -> void:
	var art := TextureRect.new()
	art.texture = KEY_ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	# Contenders you can't face yet stand in shadow.
	for i in range(1, DeadLeagueRules.BOSS_COUNT):
		if GameState.dead_league_unlocked(i):
			continue
		var shadow := TextureRect.new()
		shadow.texture = load("res://art/dead_league/locked_%d.png" % i)
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shadow)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.012, 0.025, 0.34)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -8)
	titles.add_child(UiTheme.title_label("DEAD LEAGUE", 48, UiTheme.GOLD))
	var subtitle := _label("BREAK THE SEALS  ·  YOUR BUILD  ·  THREE ROUNDS", 17, Color(0.75, 0.86, 1.0))
	titles.add_child(subtitle)
	header.add_child(titles)
	var header_space := Control.new()
	header_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_space)
	# Champions can watch the crowning again.
	if GameState.dead_league_clears.get("coffin_king", false):
		var crowning := Button.new()
		crowning.text = "Watch the ending"
		crowning.custom_minimum_size = Vector2(170, 42)
		crowning.pressed.connect(func() -> void: Ending.open(self))
		header.add_child(crowning)
	if Achievements.has("true_ending"):
		var secret := Button.new()
		secret.text = "Watch the true ending?"
		secret.custom_minimum_size = Vector2(200, 42)
		secret.pressed.connect(func() -> void: SecretEnding.open(self))
		header.add_child(secret)
		# The secret boss: five rounds, every contender tagged in.
		var true_king := Button.new()
		true_king.text = "TRUE COFFIN KING"
		true_king.theme_type_variation = "PrimaryButton"
		true_king.custom_minimum_size = Vector2(200, 42)
		true_king.tooltip_text = "Five rounds. He tags in the whole League. Bring a maxed build."
		true_king.pressed.connect(func() -> void:
			GameState.dead_league_bout = DeadLeagueRules.BOSS_COUNT - 1
			GameState.true_king_bout = true
			Loading.go("res://dead_league_arena.tscn"))
		header.add_child(true_king)
	var back := Button.new()
	back.text = "Back to camp"
	back.custom_minimum_size = Vector2(150, 42)
	back.pressed.connect(_back)
	header.add_child(back)

	var hero_space := Control.new()
	hero_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(hero_space)


	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 8)
	column.add_child(cards)
	for i in DeadLeagueRules.BOSS_COUNT:
		var profile := DeadLeagueRules.boss(i)
		var card := Button.new()
		card.custom_minimum_size = Vector2(210, 86)
		card.toggle_mode = true
		card.text = "%02d\n%s" % [profile.number, profile.name]
		card.add_theme_font_size_override("font_size", 16)
		card.tooltip_text = profile.tagline
		card.disabled = not GameState.dead_league_unlocked(i)
		card.visible = not card.disabled  # Contenders appear once you can face them.
		card.pressed.connect(_select.bind(i))
		cards.add_child(card)
		_cards.append(card)

	var detail := PanelContainer.new()
	detail.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.025, 0.02, 0.04, 0.94), Color(UiTheme.GOLD, 0.65), 2, 9, 14.0))
	column.add_child(detail)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 18)
	detail.add_child(detail_row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_name = UiTheme.title_label("", 29)
	copy.add_child(_detail_name)
	_detail_copy = _label("", 16)
	_detail_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_detail_copy)
	_best = _label("", 15, UiTheme.GOLD)
	copy.add_child(_best)
	detail_row.add_child(copy)
	var fighter := VBoxContainer.new()
	fighter.custom_minimum_size.x = 235
	fighter.add_child(_label("YOUR FIGHTER", 13, UiTheme.MUTED))
	fighter.add_child(UiTheme.title_label(GameState.fighter_name(), 22, GameState.fighter_color()))
	_power_line = _label("", 17, UiTheme.TEXT)
	_power_line.add_theme_font_override("font", UiTheme.display_font())
	fighter.add_child(_power_line)
	_power_bar = Control.new()
	_power_bar.custom_minimum_size = Vector2(230, 12)
	_power_bar.draw.connect(_draw_power_bar)
	fighter.add_child(_power_bar)
	_readiness = _label("", 15, UiTheme.TEXT)
	_readiness.add_theme_font_override("font", UiTheme.bold_font())
	fighter.add_child(_readiness)
	detail_row.add_child(fighter)
	_fight = Button.new()
	_fight.theme_type_variation = "PrimaryButton"
	_fight.text = "ENTER THE RING"
	_fight.custom_minimum_size = Vector2(220, 66)
	_fight.add_theme_font_size_override("font_size", 21)
	_fight.pressed.connect(_start_bout)
	detail_row.add_child(_fight)


func _select(index: int) -> void:
	if GameState.dead_league_unlocked(index):
		_selected = index
		_refresh_selection()


func _refresh_selection() -> void:
	var profile := DeadLeagueRules.boss(_selected)
	for i in _cards.size():
		_cards[i].set_pressed_no_signal(i == _selected)
		if i == _selected:
			_cards[i].add_theme_color_override("font_color", profile.accent.lightened(0.2))
		else:
			_cards[i].remove_theme_color_override("font_color")
	_detail_name.text = "%02d  %s  —  %s" % [profile.number, profile.name, profile.tagline]
	_detail_name.add_theme_color_override("font_color", profile.accent.lightened(0.18))
	_detail_copy.text = profile.bio
	var result: Dictionary = GameState.dead_league_best.get(profile.id, {})
	_best.text = "BEST  —  %s  ·  %d PTS" % [result.get("grade", "—"), int(result.get("score", 0))] if not result.is_empty() else "BEST  —  UNRANKED"
	# POWER against POWER: the contender is rated on the build it's tuned for.
	_power_mine = PowerRating.player()
	_power_theirs = PowerRating.contender(_selected)
	var verdict := PowerRating.verdict(_power_mine, _power_theirs)
	var ratio: float = verdict[1]
	_power_color = UiTheme.BAD if ratio < 0.88 else (UiTheme.GOLD if ratio < 0.97 else UiTheme.GOOD)
	_power_line.text = "POWER  %d   vs   %d" % [_power_mine, _power_theirs]
	_readiness.text = verdict[0]
	_readiness.add_theme_color_override("font_color", _power_color)
	_power_bar.queue_redraw()


## Your share of the combined POWER, from the left, against the contender's
## from the right; the notch in the middle is an even fight.
func _draw_power_bar() -> void:
	var area := _power_bar.size
	var share := clampf(float(_power_mine) / maxf(_power_mine + _power_theirs, 1.0), 0.04, 0.96)
	var accent: Color = DeadLeagueRules.boss(_selected).accent
	_power_bar.draw_rect(Rect2(Vector2.ZERO, area), Color(0, 0, 0, 0.6))
	_power_bar.draw_rect(Rect2(1, 1, (area.x - 2) * share, area.y - 2), _power_color)
	_power_bar.draw_rect(Rect2(1 + (area.x - 2) * share, 1, (area.x - 2) * (1.0 - share), area.y - 2), accent.darkened(0.25))
	_power_bar.draw_rect(Rect2(area.x / 2.0 - 1.0, -3, 2, area.y + 6), Color.WHITE)


func _start_bout() -> void:
	GameState.dead_league_bout = _selected
	GameState.true_king_bout = false
	Loading.go("res://dead_league_arena.tscn")


func _back() -> void:
	Loading.go("res://camp.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _label(text: String, size: int, color := UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

