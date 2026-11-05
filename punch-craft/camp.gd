extends Control
## Between-run camp (layout "Home + Play", 2026-11-05): a header with your
## progress and a settings gear; a rail down the left (Home, Fighter,
## Upgrades, Deck, Gear, Style, Shop, Goals); Home shows the fire with your
## fighters and the ways to play as picture cards on the right (Arena, Crypt,
## Dead League, then Training and Daily). The pages: Upgrades (the sealed coin
## web), Deck (level-up cards), Armory (kept Crypt gear), Cosmetics, Bounties,
## Shop and Attributes (with the Loadout and changing fighter). Built in code
## from the data in GameState.

const PAGES := ["Attributes", "Upgrades", "Armory", "Cosmetics", "Shop", "Bounties"]
## What the rail calls each page.
const RAIL_NAMES := {"Attributes": "Fighter", "Upgrades": "Upgrades", "Armory": "Gear",
	"Cosmetics": "Style", "Shop": "Shop", "Bounties": "Bounties"}
const RAIL_ICONS := {"Home": "flame", "Attributes": "glove", "Upgrades": "sigil", "Armory": "helmet",
	"Cosmetics": "crown", "Shop": "bag", "Bounties": "wanted"}
const RAIL_WIDTH := 112.0
const PLAY_WIDTH := 400.0
const WORLD := preload("res://world.gd")
const DUNGEON := preload("res://dungeon.gd")
const DETAIL_WIDTH := 340.0

var _xp_bar: ProgressBar
var _backdrop: CampBackdrop
## The menus (everything but the backdrop), hidden while the Crypt rises.
var _menus: Control
var _crypt_button: Button
var _level_label: Label
var _xp_label: Label
## Resource pills in the header: coins, souls, card draws and attribute points.
var _chips := {}
## The header amounts only animate after the first refresh.
var _shown_once := false
var _night_label: Label
var _tab_buttons := {}
var _league_button: Button
var _arena_button: Button
var _pages := {}
var _trees := {}
var _details := {}
var _sheet: GridContainer
var _sheet_scroll: ScrollContainer
var _reset_button: Button
var _deck: DeckPage
## The Fighter page: the ring, which attribute is picked ("" = the fighter),
## its detail, the ATTRIBUTES | DECK switch and the views it flips between.
var _ring: AttributeRing
var _attr_selected := "power"
var _attr_detail: VBoxContainer
var _points_pill: PanelContainer
var _points_label: Label
var _fighter_buttons: HBoxContainer
var _fighter_views := {}
var _fighter_tab_buttons := {}
var _deck_switch: Button
## Home: the play column (and its cards' lines, refreshed with the camp).
var _home: Control
var _mode_lines := {}
var _daily_button: Button


func _ready() -> void:
	Sfx.play_music("camp")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_ambience()
	theme = UiTheme.make()
	_build_ui()
	GameState.changed.connect(_refresh)
	Achievements.catch_up()
	_show_page("Home")
	_refresh()
	if GameState.crypt_reveal_pending:
		await _play_crypt_reveal()
	if GameState.upgrade_notice != "":
		var notice := GameDialog.open(self, "A NEW CLIMB", GameState.upgrade_notice, ["Let's go"])
		GameState.upgrade_notice = ""
		GameState.save_game()
		notice.chosen.connect(func(_index: int) -> void: _draw_then_tips.call_deferred())
	else:
		_draw_then_tips()


## Cards waiting from level-ups: the draw first, then camp's tips.
func _draw_then_tips() -> void:
	if not is_inside_tree():
		return
	if GameState.draws > 0 and not GameState.card_offer().is_empty():
		_open_draw().closed.connect(_camp_tips.call_deferred)
	else:
		_camp_tips()


func _open_draw() -> CardDraw:
	var draw := CardDraw.open(self)
	draw.closed.connect(_refresh)
	return draw


## Camp's mini tutorials (Tutorial), each once: after your first hat, the
## Hat Rack (in Cosmetics); a new passive or ultimate, the Loadout.
func _camp_tips() -> void:
	if not is_inside_tree():
		return
	if _onboarding_tips():
		return
	if not Tutorial.seen("hat_first") or GameState.hats.is_empty() or Tutorial.seen("hat_rack"):
		_ability_tip()
		return
	var first := Tutorial.open(self, "hat_rack", "YOUR FIRST HAT!", "Hats go on your Hat Rack, in Cosmetics.",
			_tab_buttons["Cosmetics"], func() -> bool: return _pages["Cosmetics"].visible, false)
	if first == null:
		return
	first.finished.connect(func() -> void:
		_show_cosmetic("Hats")
		Tutorial.open(self, "hat_rack_tour", "THE HAT RACK",
				"Every hat gives a small boost that's yours for good, worn or not.\n\n%s a hat to wear it, and hold %s in a fight to emote and show it off." % [Controls.tap_word(), Controls.key_name("emote")],
				_hat_grid, Callable(), false, true))


## New players (2026-11-05): the Arena (after the tutorial, or skipping it);
## your first upgrade once your first Arena fight is over (topped up with
## spare change if you can't afford it); the Dead League once you've won an
## Arena bout (it's locked till then); your first attribute points. True if
## one opened.
func _onboarding_tips() -> bool:
	# (Skipping the tutorial from the title screen counts: onboarded, not done.)
	if (GameState.tutorial_done or GameState.onboarded) and not _arena_done():
		if _arena_tip():
			return true
	if _upgrade_tip(false):
		return true
	if _league_tip(false):
		return true
	if GameState.attribute_points > 0:
		return Tutorial.open(self, "attribute_points", "ATTRIBUTE POINTS",
				"Every level gives %d points to spend in Attributes. Each point is a small boost, and 10, 20 and 30 in one attribute unlock a perk." % Attributes.POINTS_PER_LEVEL,
				_tab_buttons["Attributes"], Callable(), false) != null
	return false


## The Dead League opens once you've won an Arena bout (2026-11-05). Older
## saves with any bout won or seal broken are open.
func _league_open() -> bool:
	return GameState.nights_cleared > 0 or not GameState.arena_bouts.is_empty() \
			or GameState.dead_league_clears.values().has(true)


## True once an Arena bout has ended (win or knockout). Older saves count by
## their bout history.
func _arena_done() -> bool:
	if Tutorial.seen("arena_done"):
		return true
	for count in GameState.arena_bouts.values():
		if int(count) > 0:
			return true
	return false


func _arena_tip() -> Tutorial:
	if _arena_button == null:
		return null
	return Tutorial.open(self, "arena_intro", "THE ARENA",
			"To make money, you need to duke it out with the undead!\n\nStep into the Arena.",
			_arena_button, Callable(), false)


## After your first Arena fight (won or not), your first upgrade. Short of
## the coins, camp spares the change.
func _upgrade_tip(_chain: bool) -> bool:
	var cheapest := GameState.cheapest_upgrade()
	if not _arena_done() or not GameState.upgrade_levels.is_empty() or cheapest <= 0 or Tutorial.seen("first_upgrade"):
		return false
	var coins: int = GameState.resources.get("coins", 0)
	var broke := coins < cheapest
	if broke:
		GameState.add_resource("coins", cheapest - coins)
	_show_page("Upgrades")
	var upgrade := Tutorial.open(self, "first_upgrade", "YOUR FIRST UPGRADE",
			("Oh, you're broke? Fine, I'll spare some change.\n\n" if broke else "")
			+ "Coins buy upgrades on this web, and they work for every fighter. Buy your first one.",
			_details["upgrade"].buy, func() -> bool: return not GameState.upgrade_levels.is_empty(), false)
	if upgrade:
		upgrade.finished.connect(_league_tip.bind(true))
		return true
	return false


func _league_tip(chain: bool) -> bool:
	if _league_button == null or not _league_open():
		return false
	return Tutorial.open(self, "dead_league", "THE DEAD LEAGUE",
			"You proved your worth: the Dead League is open.\n\nFive contenders, one at a time. Challenge the next one whenever you like, as often as you like.\n\nBeating them is how you progress: each win breaks a seal, opening the next Arena division, new upgrades and more.",
			_league_button, Callable(), false, chain) != null


## Back from breaking the Bellman's seal: the menus fall away, the camera
## turns to the graveyard and the Crypt rises out of it. Plays once.
func _play_crypt_reveal() -> void:
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	_menus.modulate.a = 0.0
	await get_tree().create_timer(0.6).timeout
	await _backdrop.play_crypt_reveal()
	var words := VBoxContainer.new()
	words.anchor_left = 0.0
	words.anchor_right = 1.0
	words.anchor_top = 0.68
	words.anchor_bottom = 0.68
	words.add_theme_constant_override("separation", 4)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(words)
	var title := UiTheme.title_label("THE CRYPT HAS OPENED", 64, CryptDoor.GLOW.lightened(0.45))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	words.add_child(title)
	var line := UiTheme.title_label("Beating the Bellman opened the Crypt. Gear you find down there is yours if you gild it before you leave.", 22, UiTheme.TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.add_child(line)
	words.modulate.a = 0.0
	var show := words.create_tween()
	show.tween_property(words, "modulate:a", 1.0, 0.4)
	show.tween_interval(2.6)
	show.tween_property(words, "modulate:a", 0.0, 0.5)
	await show.finished
	words.queue_free()
	_backdrop.end_crypt_reveal()
	GameState.crypt_reveal_pending = false
	GameState.save_game()
	await create_tween().tween_property(_menus, "modulate:a", 1.0, 0.5).finished
	blocker.queue_free()
	# The new button gets a nudge.
	if _crypt_button:
		_crypt_button.pivot_offset = _crypt_button.size / 2.0
		var nudge := _crypt_button.create_tween()
		nudge.tween_property(_crypt_button, "scale", Vector2(1.15, 1.15), 0.18)
		nudge.tween_property(_crypt_button, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _build_ui() -> void:
	# The campfire scene behind everything, darkened so the menus read.
	var backdrop := CampBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_backdrop = backdrop
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.03, 0.12))
	gradient.set_color(1, Color(0.02, 0.02, 0.03, 0.75))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = gradient
	shade_texture.fill = GradientTexture2D.FILL_RADIAL
	shade_texture.fill_from = Vector2(0.62, 0.55)
	shade_texture.fill_to = Vector2(1.3, 0.55)
	shade.texture = shade_texture
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	_menus = margin

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_fit_width(_build_header()))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	body.add_child(_build_rail())

	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page_area)
	_home = _build_home()
	_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_area.add_child(_home)
	_add_page(page_area, "Upgrades", _build_tree_page("upgrade"))
	_add_page(page_area, "Armory", _build_armory_page())
	_add_page(page_area, "Cosmetics", _build_cosmetics_page())
	_add_page(page_area, "Bounties", _build_bounty_page())
	_add_page(page_area, "Shop", _build_shop_page())
	_add_page(page_area, "Attributes", _build_fighter_page())


## Holds a row at its natural size, shrunk to fit when the screen is narrower
## than it (points waiting, a long fighter name, new buttons), instead of
## pushing the whole camp off the right edge.
func _fit_width(content: Control) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(content)
	var fit := func() -> void:
		var natural := content.get_combined_minimum_size()
		var shrink := minf(1.0, holder.size.x / maxf(natural.x, 1.0)) if holder.size.x > 0.0 else 1.0
		content.scale = Vector2(shrink, shrink)
		content.position = Vector2.ZERO
		content.size = Vector2(holder.size.x / shrink if holder.size.x > 0.0 else natural.x, natural.y)
		holder.custom_minimum_size = Vector2(0, natural.y * shrink)
	holder.resized.connect(fit)
	content.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return holder


# --- Header ------------------------------------------------------------------

## The top bar (2026-11-05): solid, not see-through (it anchors the camp),
## tinted toward your fighter's color with a stripe of it along the bottom;
## "The Mauler: Lvl 1" in that color; the wordmark subtly alive.
var _header: PanelContainer
var _rail_panel: PanelContainer


func _build_header() -> Control:
	var panel := PanelContainer.new()
	_header = panel
	_theme_header()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER  # The title sits mid-height in the bar.
	var wordmark := TitleWordmark.new()
	wordmark.color = UiTheme.BLOOD.lightened(0.15)
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_child(wordmark)
	row.add_child(titles)

	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 3)
	progress.custom_minimum_size.x = 240
	_level_label = UiTheme.title_label("", 20)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size.y = 7
	_xp_label = _label("", 12, UiTheme.MUTED)
	progress.add_child(_level_label)
	progress.add_child(_xp_bar)
	progress.add_child(_xp_label)
	row.add_child(progress)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var tips := {
		"coins": "Coins",
		"souls": "Souls",
		"draws": "Card draws waiting",
		"attribute_points": "Attribute points",
	}
	for id in tips:
		var chip := ResourceChip.make(id)
		chip.tooltip_text = tips[id]
		row.add_child(chip)
		_chips[id] = chip
	_night_label = _label("", 22, UiTheme.GOLD)
	_night_label.tooltip_text = "Power: your whole build in one number"
	_night_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_night_label.add_theme_font_override("font", UiTheme.display_font())
	row.add_child(_night_label)
	row.add_child(_settings_button())

	return panel


## The bar's colors for the fighter you're playing: a dark base leaning a
## little toward their color, their color faint round the edge and solid in
## the bottom stripe, and their color in the XP bar.
func _theme_header() -> void:
	if _header == null:
		return
	var tint := GameState.fighter_color()
	var style := UiTheme.raised(UiTheme.PANEL.lerp(tint.darkened(0.75), 0.3), Color(tint, 0.4), 1, 10, 12.0)
	style.bg_color.a = 1.0
	style.border_width_bottom = 3
	style.border_color = Color(tint, 0.45)
	_header.add_theme_stylebox_override("panel", style)
	# The rail takes the same colors, its stripe down the right side.
	if _rail_panel:
		var rail := UiTheme.raised(UiTheme.PANEL.lerp(tint.darkened(0.75), 0.3), Color(tint, 0.4), 1, 10, 0.0)
		rail.bg_color.a = 1.0
		rail.border_width_right = 3
		rail.border_color = Color(tint, 0.45)
		_rail_panel.add_theme_stylebox_override("panel", rail)
		# The lit page's glow and underline in the fighter's color, not gold.
		var lit := UiTheme.box(Color(tint, 0.1), tint, 0, 0, 0.0)
		lit.border_width_bottom = 3
		lit.shadow_color = Color(tint, 0.25)
		lit.shadow_size = 6
		lit.content_margin_left = 12
		lit.content_margin_right = 12
		lit.content_margin_top = 10
		lit.content_margin_bottom = 10
		for page in _tab_buttons:
			_tab_buttons[page].add_theme_stylebox_override("pressed", lit)
			_tab_buttons[page].add_theme_stylebox_override("hover_pressed", lit)
		_highlight_rail()
	if _xp_bar:
		var fill := UiTheme.box(tint.darkened(0.1), tint.lightened(0.2), 0, 4)
		_xp_bar.add_theme_stylebox_override("fill", fill)


## The rail's lit page: your fighter's color, a touch lighter.
func _rail_lit() -> Color:
	return GameState.fighter_color().lightened(0.15)


## Recolors the lit rail page (after a fighter change).
func _highlight_rail() -> void:
	for page in _tab_buttons:
		var button: Button = _tab_buttons[page]
		if not button.button_pressed:
			continue
		var label: Label = button.get_meta("label", null)
		if label:
			label.add_theme_color_override("font_color", _rail_lit())
		var icon: IconView = button.get_meta("icon", null)
		if icon:
			icon.color = _rail_lit()


## The gear in the header: the title screen (settings, change fighter).
func _settings_button() -> Button:
	var gear := Button.new()
	gear.custom_minimum_size = Vector2(46, 46)
	gear.tooltip_text = "Settings and title screen"
	gear.pressed.connect(func() -> void:
		GameState.save_game()
		Loading.go("res://title.tscn"))
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.draw.connect(func() -> void:
		var c := icon.size / 2.0
		var ink := UiTheme.TEXT
		for i in 8:
			var a := TAU * i / 8.0
			icon.draw_line(c + Vector2.from_angle(a) * 7.0, c + Vector2.from_angle(a) * 12.0, ink, 4.5)
		icon.draw_circle(c, 8.5, ink)
		icon.draw_circle(c, 3.6, UiTheme.PANEL_LIGHT))
	gear.add_child(icon)
	return gear


## The rail down the left: Home, then a button per page, icon over name.
func _build_rail() -> Control:
	var panel := PanelContainer.new()
	_rail_panel = panel
	panel.custom_minimum_size.x = RAIL_WIDTH
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	panel.add_child(list)
	var group := ButtonGroup.new()
	for page in ["Home"] + PAGES:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = "TabButton"
		# Equal shares of the rail's height, so hidden pages (Gear, Bounties)
		# re-spread the rest instead of leaving gaps.
		button.custom_minimum_size = Vector2(0, 60)
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.text = ""
		button.tooltip_text = RAIL_NAMES.get(page, page)
		button.pressed.connect(_show_page.bind(page))
		var stack := VBoxContainer.new()
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.add_theme_constant_override("separation", 2)
		var icon := IconView.new()
		icon.icon = RAIL_ICONS[page]
		# (2026-11-05: 64 -> 50, so seven pages fit without the names
		# running into the next icon.)
		icon.custom_minimum_size = Vector2(50, 50)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.tile_color = Color.TRANSPARENT
		stack.add_child(icon)
		var name_label := UiTheme.title_label(RAIL_NAMES.get(page, page), 16, UiTheme.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(name_label)
		button.add_child(stack)
		button.set_meta("label", name_label)
		button.set_meta("icon", icon)
		list.add_child(button)
		_tab_buttons[page] = button
	return panel


## Home: the fire on the left (empty space over the backdrop) and the ways to
## play on the right, each a picture card with how far you've got.
func _build_home() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var play := VBoxContainer.new()
	play.custom_minimum_size.x = PLAY_WIDTH
	play.add_theme_constant_override("separation", 10)
	row.add_child(play)
	play.add_child(UiTheme.title_label("PLAY", 22, UiTheme.MUTED))
	_arena_button = _mode_card(play, "arena", "ARENA", "FIGHT", preload("res://art/ui/mode_arena.jpg"), _pick_division)
	_crypt_button = _mode_card(play, "crypt", "CRYPT", "DESCEND", preload("res://art/ui/mode_crypt.jpg"), _pick_crypt_floors)
	_league_button = _mode_card(play, "league", "DEAD LEAGUE", "CHALLENGE", preload("res://art/ui/mode_league.jpg"), _start_dead_league)
	if GameState.crypt_new and GameState.crypt_unlocked:
		_crypt_button.add_child(_new_badge())
	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 10)
	play.add_child(small)
	var training := Button.new()
	training.text = "Training" if GameState.tutorial_done else "Tutorial"
	training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	training.custom_minimum_size.y = 46
	training.pressed.connect(_start_training)
	small.add_child(training)
	_daily_button = Button.new()
	_daily_button.text = "Daily"
	_daily_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_button.custom_minimum_size.y = 46
	_daily_button.tooltip_text = "Pad Work, Slip Line and Heavy Bags: score runs that pay coins and XP once a day."
	_daily_button.pressed.connect(_pick_drill)
	small.add_child(_daily_button)
	if DRILLS.any(func(id: String) -> bool: return GameState.drill_ready(id)):
		_daily_button.add_child(_new_badge("READY"))
	return row


## A play card: the place's picture under a dark fade, its name, a line of
## progress, pips, and the action word in gold. Locked, it greys out.
func _mode_card(parent: Control, id: String, title: String, action: String, picture: Texture2D, on_press: Callable) -> Button:
	var card := Button.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(PLAY_WIDTH, 112)
	card.clip_contents = true
	card.pressed.connect(on_press)
	var face := UiTheme.raised(Color(0.04, 0.035, 0.05, 0.95), Color(1, 1, 1, 0.14), 2, 12)
	var hover := UiTheme.raised(Color(0.04, 0.035, 0.05, 0.95), UiTheme.GOLD, 2, 12)
	for state in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state, face)
	for state in ["hover", "pressed", "hover_pressed", "focus"]:
		card.add_theme_stylebox_override(state, hover)
	var art := TextureRect.new()
	art.texture = picture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 2
	art.offset_top = 2
	art.offset_right = -2
	art.offset_bottom = -2
	card.add_child(art)
	var fade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.025, 0.04, 0.95))
	gradient.add_point(0.55, Color(0.03, 0.025, 0.04, 0.6))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.03, 0.025, 0.04, 0.1))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(fade)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 18
	text.offset_right = -16
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	card.add_child(text)
	var name_label := UiTheme.title_label(title, 32, UiTheme.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name_label)
	var line := _label("", 15, Color(0.86, 0.82, 0.9))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(line)
	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 5)
	text.add_child(pips)
	var go := UiTheme.title_label(action + " ›", 18, UiTheme.GOLD)
	go.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	go.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	go.grow_vertical = Control.GROW_DIRECTION_BEGIN
	go.offset_right = -16
	go.offset_bottom = -10
	card.add_child(go)
	parent.add_child(card)
	_mode_lines[id] = {"card": card, "line": line, "pips": pips, "go": go, "art": art}
	return card


## The play cards' lines, pips and locks.
func _refresh_home() -> void:
	if _mode_lines.is_empty():
		return
	var division := clampi(GameState.arena_division, 1, Progression.current_tier())
	var won := mini(int(GameState.arena_bouts.get(str(division), 0)), Progression.BOUTS_PER_DIVISION)
	var next_bout := mini(won + 1, Progression.BOUTS_PER_DIVISION)
	_set_mode("arena", "%s  ·  bout %d of %d" % [Themes.arena(division).name, next_bout, Progression.BOUTS_PER_DIVISION],
			won, Progression.BOUTS_PER_DIVISION, true)
	_set_mode("crypt", "Gild the gear you find to keep it" if GameState.crypt_unlocked else "Break the Bellman's seal to open it",
			0, 0, GameState.crypt_unlocked)
	var seals := Progression.seals_broken()
	var league_line := "Win your first Arena bout to open it"
	if _league_open():
		league_line = "All five seals broken" if seals >= DeadLeagueRules.BOSS_COUNT \
				else "Next: %s" % String(DeadLeagueRules.boss(seals).name).capitalize()
	_set_mode("league", league_line, seals, DeadLeagueRules.BOSS_COUNT, _league_open())
	if _daily_button:
		var badge := _daily_button.get_child(_daily_button.get_child_count() - 1) if _daily_button.get_child_count() > 0 else null
		if badge and not DRILLS.any(func(id: String) -> bool: return GameState.drill_ready(id)):
			badge.queue_free()


func _set_mode(id: String, line: String, done: int, total: int, open: bool) -> void:
	var parts: Dictionary = _mode_lines[id]
	(parts.line as Label).text = line
	var pips: HBoxContainer = parts.pips
	for child in pips.get_children():
		child.queue_free()
	for i in total:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(24, 6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD if i < done else Color(1, 1, 1, 0.18), Color.TRANSPARENT, 0, 3))
		pips.add_child(pip)
	(parts.go as Control).visible = open
	# Locked ones are hidden, not greyed (the Arena card is always there).
	var card: Button = parts.card
	var appearing := open and not card.visible and _shown_once
	if id != "arena":
		card.visible = open
	if appearing:
		card.pivot_offset = card.size / 2.0
		var pulse := card.create_tween()
		pulse.tween_property(card, "scale", Vector2(1.06, 1.06), 0.2)
		pulse.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


## A small pulsing "NEW" tag on a button's corner.
func _new_badge(text := "NEW") -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.box(CryptDoor.GLOW, Color.TRANSPARENT, 0, 8, 3.0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.display_font())
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(label)
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.offset_left = -10.0 - 8.0 * text.length()
	badge.offset_right = 4
	badge.offset_top = -12
	badge.offset_bottom = 8
	var pulse := badge.create_tween().set_loops()
	pulse.tween_property(badge, "modulate:a", 0.55, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(badge, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return badge


## Something waiting on a tab (card draws, attribute points): a pulsing
## count on its corner, like Daily's READY.
func _set_tab_count(page: String, count: int) -> void:
	_set_count_on(_tab_buttons[page], count)


func _set_count_on(button: Button, count: int) -> void:
	var old := button.get_node_or_null("Count")
	if old:
		old.free()
	if count > 0:
		var badge := _new_badge(str(count))
		badge.name = "Count"
		button.add_child(badge)


func _add_page(area: Control, page_name: String, page: Control) -> void:
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(page)
	_pages[page_name] = page


func _show_page(page_name: String) -> void:
	if _home:
		_home.visible = page_name == "Home"
	for page in _pages:
		_pages[page].visible = page == page_name
	for page in _tab_buttons:
		var on: bool = page == page_name
		_tab_buttons[page].set_pressed_no_signal(on)
		var label: Label = _tab_buttons[page].get_meta("label", null)
		if label:
			label.add_theme_color_override("font_color", _rail_lit() if on else UiTheme.TEXT)
		var icon: IconView = _tab_buttons[page].get_meta("icon", null)
		if icon:
			icon.color = _rail_lit() if on else Color(0.74, 0.71, 0.8)
	if page_name == "Cosmetics":
		_show_cosmetic(_cosmetic_tab)


# --- Upgrade / skill trees -------------------------------------------------------

func _build_tree_page(kind: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var canvas := PanelContainer.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# See-through, so the web floats over the campfire.
	canvas.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.02, 0.02, 0.04, 0.28), Color(UiTheme.GOLD, 0.18), 1, 10))
	row.add_child(canvas)
	var tree := SkillTreeView.new()
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.add_child(tree)
	tree.setup(kind)
	tree.node_selected.connect(_on_node_selected.bind(kind).unbind(1))
	tree.node_activated.connect(_buy_selected.bind(kind).unbind(1))
	_trees[kind] = tree

	row.add_child(_build_detail_panel(kind))
	# Start with the tree's first node selected.
	tree.select(GameState.tree(kind).keys()[0])
	return row


func _build_detail_panel(kind: String) -> Control:
	var accent: Color = _trees[kind].accent()
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = DETAIL_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	box.add_child(top)
	var icon := IconView.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.color = accent
	top.add_child(icon)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var branch_label := _label("", 11, accent)
	var name_label := UiTheme.title_label("", 26)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var level_label := _label("", 14, accent)
	titles.add_child(branch_label)
	titles.add_child(name_label)
	titles.add_child(level_label)
	top.add_child(titles)

	var desc := _label("", 14, UiTheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)
	box.add_child(HSeparator.new())

	box.add_child(_label("NOW", 12, UiTheme.MUTED))
	var now := _label("", 16)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(now)
	box.add_child(_label("NEXT LEVEL", 12, UiTheme.MUTED))
	var next := _label("", 16, UiTheme.GOOD)
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	# The price, with resource icons, in a dark well.
	var cost_row := PanelContainer.new()
	cost_row.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), Color(accent, 0.2), 1, 8, 8.0))
	var cost_box := HBoxContainer.new()
	cost_box.add_theme_constant_override("separation", 10)
	cost_row.add_child(cost_box)
	cost_box.add_child(_label("COST", 12, UiTheme.MUTED))
	var cost := IconLabel.new()
	cost.font_size = 20
	cost.outline = 3
	cost.font = UiTheme.display_font()
	cost.alignment_h = BoxContainer.ALIGNMENT_END
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_box.add_child(cost)
	box.add_child(cost_row)

	var buy := Button.new()
	buy.theme_type_variation = "PrimaryButton"
	buy.custom_minimum_size.y = 48
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(_buy_selected.bind(kind))
	box.add_child(buy)

	_details[kind] = {
		"icon": icon, "name": name_label, "level": level_label, "desc": desc, "branch": branch_label,
		"now": now, "next": next, "cost": cost, "cost_row": cost_row, "buy": buy,
	}
	return panel


func _on_node_selected(kind: String) -> void:
	_refresh_detail(kind)


func _buy_selected(kind: String) -> void:
	var tree: SkillTreeView = _trees[kind]
	var id := GameState.shown_node(kind, tree.selected_id)
	var node: Dictionary = GameState.tree(kind)[id]
	var before := GameState.node_level(kind, id)
	# An owned power's button selects it instead (one power at a time).
	if kind == "upgrade" and SkillTreeView.BRANCHES.has(id) and before > 0:
		if GameState.select_power(id):
			Sfx.play("unlock", -6.0, 1.3)
			tree.celebrate(id)
			_refresh_detail(kind)
		return
	if GameState.buy_node(kind, id):
		if kind == "upgrade" and SkillTreeView.BRANCHES.has(id) and GameState.power_pick == "":
			_refresh_detail(kind)
			_power_tip(kind)
		tree.celebrate(id)
		_pulse_detail(kind)
		var awakened: bool = node.get("medallion", false) and before == 0
		var maxed: bool = node.max_level > 1 and GameState.node_level(kind, id) >= node.max_level
		if awakened or maxed:
			Sfx.play("unlock", -5.0)
		else:
			Sfx.play("coin" if kind == "upgrade" else "clear", -6.0)
	elif GameState.node_state(kind, id) != "maxed":
		# Can't buy it yet: shake the node, the price, and the resource it needs.
		Sfx.play("deny", -12.0)
		tree.deny(id)
		_shake(_details[kind].cost_row)
		if GameState.node_sealed_by(kind, id) == "":
			_chips.coins.deny()


## The first power bought: a pointer at Select until it's picked.
func _power_tip(kind: String) -> void:
	var buy: Button = _details[kind].buy
	var power_name: String = _trees[kind].branch_name(_trees[kind].selected_id).capitalize()
	Tutorial.open(self, "power_select", "NEW POWER",
			"Powers are big upgrades you make stronger as you climb. You can only have one selected at a time, so pick the one you want working.\n\nSelect %s here." % power_name,
			buy, func() -> bool: return GameState.power_pick != "", false, true)


# --- Loadout ---------------------------------------------------------------------------

var _loadout_button: Button
var _loadout_layer: CanvasLayer
var _loadout_opened := false


## How many passives and ultimates the fighter has unlocked.
func _ability_choices() -> int:
	var count := 0
	for entry in Abilities.passives(GameState.player_class) + Abilities.ultimates(GameState.player_class):
		if Abilities.unlocked(GameState.player_class, entry.id, GameState.level):
			count += 1
	return count


## A newly unlocked ability: point at the Loadout.
func _ability_tip() -> void:
	if _loadout_button == null:
		return
	for slot in ["passive", "ultimate"]:
		var list: Array = Abilities.passives(GameState.player_class) if slot == "passive" else Abilities.ultimates(GameState.player_class)
		for i in range(1, list.size()):
			var entry: Dictionary = list[i]
			if not Abilities.unlocked(GameState.player_class, entry.id, GameState.level):
				continue
			if Tutorial.seen("ability_" + entry.id):
				continue
			_show_page("Attributes")  # The Loadout button is on the Fighter page.
			if Tutorial.open(self, "ability_" + entry.id, "NEW %s: %s" % [slot.to_upper(), String(entry.name).to_upper()],
					"%s\n\nEquip it in your Loadout. Its cards join your deck." % entry.desc,
					_loadout_button, func() -> bool: return _loadout_opened, false) != null:
				return


func _open_loadout() -> void:
	_loadout_opened = true
	if _loadout_layer:
		_loadout_layer.queue_free()
	_loadout_layer = CanvasLayer.new()
	_loadout_layer.layer = 50
	add_child(_loadout_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loadout_layer.add_child(dim)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_loadout())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var heading := UiTheme.title_label("LOADOUT  ·  %s" % GameState.fighter_name().to_upper(), 40, UiTheme.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	for slot in ["passive", "ultimate"]:
		var label := UiTheme.title_label(slot.to_upper(), 20, UiTheme.MUTED)
		column.add_child(label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(row)
		var list: Array = Abilities.passives(GameState.player_class) if slot == "passive" else Abilities.ultimates(GameState.player_class)
		var equipped := GameState.passive() if slot == "passive" else GameState.ultimate()
		for entry in list:
			if Abilities.unlocked(GameState.player_class, entry.id, GameState.level):
				row.add_child(_ability_card(slot, entry, entry.id == equipped))
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = "PrimaryButton"
	done.custom_minimum_size = Vector2(180, 48)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close_loadout)
	column.add_child(done)


## The hand idles the fighter can pick, each playing on a loop.
func _refresh_idles() -> void:
	if _idle_grid == null:
		return
	for child in _idle_grid.get_children():
		child.queue_free()
	var grid := _idle_grid
	var tint := GameState.fighter_color()
	for id in IdleAnims.choices(GameState.player_class):
		var equipped: bool = id == GameState.idle_anim()
		var card := Button.new()
		card.custom_minimum_size = Vector2(230, 170)
		# Equipped: lit in the fighter's colour with a gold rim. The rest sit grey
		# and dim (a gold-tinted fighter like Tony made them all look equipped).
		card.add_theme_stylebox_override("normal", UiTheme.raised(Color(tint.darkened(0.78), 0.98) if equipped else Color(0.06, 0.05, 0.08, 0.96),
			UiTheme.GOLD if equipped else Color(1, 1, 1, 0.16), 3 if equipped else 2, 12))
		card.add_theme_stylebox_override("hover", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
		card.add_theme_stylebox_override("pressed", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 8
		inside.offset_right = -8
		inside.offset_top = 8
		inside.offset_bottom = -8
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inside)
		var preview := IdlePreview.new()
		preview.idle_id = id
		preview.custom_minimum_size = Vector2(214, 118)
		inside.add_child(preview)
		var name_label := _label(IdleAnims.name_of(id) + ("   ·   EQUIPPED" if equipped else ""), 15, UiTheme.GOLD if equipped else UiTheme.TEXT)
		name_label.add_theme_font_override("font", UiTheme.bold_font())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(name_label)
		card.pressed.connect(func() -> void:
			if GameState.equip_idle(id):
				Sfx.play("unlock", -8.0, 1.4)
				_refresh_idles())
		grid.add_child(card)


func _close_loadout() -> void:
	if _loadout_layer:
		_loadout_layer.queue_free()
		_loadout_layer = null
	_refresh()


func _ability_card(slot: String, entry: Dictionary, equipped: bool) -> Button:
	var tint: Color = GameState.fighter_color()
	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 230)
	# Equipped: lit in the fighter's colour with a gold rim. The rest sit grey
	# and dim (a gold-tinted fighter like Tony made them all look equipped).
	card.add_theme_stylebox_override("normal", UiTheme.raised(Color(tint.darkened(0.78), 0.98) if equipped else Color(0.06, 0.05, 0.08, 0.96),
		UiTheme.GOLD if equipped else Color(1, 1, 1, 0.16), 3 if equipped else 2, 12))
	card.add_theme_stylebox_override("hover", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
	card.add_theme_stylebox_override("pressed", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
	var inside := VBoxContainer.new()
	inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inside.offset_left = 14
	inside.offset_right = -14
	inside.offset_top = 12
	inside.offset_bottom = -12
	inside.add_theme_constant_override("separation", 8)
	inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not equipped:
		inside.modulate = Color(1, 1, 1, 0.6)
	card.add_child(inside)
	var icon := IconView.new()
	icon.icon = entry.icon
	icon.color = tint.lightened(0.2)
	icon.custom_minimum_size = Vector2(54, 54)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inside.add_child(icon)
	var name_label := UiTheme.title_label(String(entry.name).to_upper(), 20, UiTheme.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inside.add_child(name_label)
	var desc := _label(entry.desc, 13, UiTheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size.x = 220
	inside.add_child(desc)
	if equipped:
		var tag := _label("EQUIPPED", 13, UiTheme.GOLD)
		tag.add_theme_font_override("font", UiTheme.bold_font())
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(tag)
	card.pressed.connect(func() -> void:
		if GameState.equip_ability(slot, entry.id):
			Sfx.play("unlock", -6.0, 1.3)
			_open_loadout())
	return card


## The detail panel's icon pops after a purchase.
func _pulse_detail(kind: String) -> void:
	var icon: IconView = _details[kind].icon
	icon.pivot_offset = icon.size / 2.0
	icon.scale = Vector2.ONE * 1.25
	var tween := icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(control: Control) -> void:
	var home := control.position.x
	var tween := control.create_tween()
	control.modulate = Color(1.5, 0.6, 0.6)
	for i in 5:
		tween.tween_property(control, "position:x", home + (6.0 if i % 2 == 0 else -6.0), 0.035)
	tween.tween_property(control, "position:x", home, 0.035)
	tween.parallel().tween_property(control, "modulate", Color.WHITE, 0.3)


func _refresh_detail(kind: String) -> void:
	var id: String = _trees[kind].selected_id
	if id == "" or not _details.has(kind):
		return
	id = GameState.shown_node(kind, id)
	var node: Dictionary = GameState.tree(kind)[id]
	var detail: Dictionary = _details[kind]
	var level := GameState.node_level(kind, id)
	var maxed: bool = level >= node.max_level
	var tree: SkillTreeView = _trees[kind]
	var tint := tree.branch_color(id)

	detail.icon.icon = node.icon
	detail.icon.color = tint.lightened(0.2) if level > 0 else UiTheme.TEXT.darkened(0.15)
	detail.icon.tile_color = tint.darkened(0.75) if level > 0 else UiTheme.PANEL_LIGHT
	detail.icon.border_color = tint if level > 0 else UiTheme.BORDER
	var where := tree.branch_name(id)
	var role := "UPGRADE" if kind == "upgrade" else "SKILL"
	if SkillTreeView.BRANCHES.has(id):
		role = "POWER  ·  AWAKENS %s" % where
	elif node.has("medallion"):
		role = ("TROPHY" if node.icon in ["belt", "helmet", "medal", "bucket", "crown"] else "CAPSTONE") if kind == "upgrade" else "ULTIMATE"
	if GameState.node_ring(kind, id) > 1:
		role += "  ·  RING %d" % GameState.node_ring(kind, id) if GameState.node_ring(kind, id) <= 5 else "  ·  CROWN RING"
	elif node.requires.is_empty():
		role = "CORE"
	elif node.max_level == 1:
		role = "KEYSTONE"
	detail.branch.text = ("%s POWER  ·  %s" % [where, role]) if where != "" and not SkillTreeView.BRANCHES.has(id) else role
	if kind == "upgrade" and not GameState.power_active(id):
		detail.branch.text += "  ·  NOT SELECTED"
	detail.branch.add_theme_color_override("font_color", tint)
	detail.level.add_theme_color_override("font_color", tint)
	detail.name.text = node.name
	detail.level.text = "Level %d / %d" % [level, node.max_level] if node.max_level > 1 else ("Owned" if level > 0 else "Not owned")
	detail.desc.text = node.desc
	detail.now.text = GameState.effect_text(node.effects, level) if level > 0 else "Nothing yet"
	detail.next.text = "Maxed out" if maxed else GameState.effect_text(node.effects, level + 1)
	detail.cost_row.visible = not maxed

	var cost := GameState.node_cost(kind, id)
	var have := GameState.node_currency(kind)
	var holder := GameState.node_sealed_by(kind, id)
	var cost_text := "%d {coins}" % cost
	var can_pay := have >= cost and holder == ""
	detail.cost.color = UiTheme.TEXT if can_pay else UiTheme.BAD.lightened(0.1)
	detail.cost.text = cost_text

	var buy: Button = detail.buy
	if kind == "upgrade" and SkillTreeView.BRANCHES.has(id) and level > 0:
		# Owned powers: pick the one that works.
		var picked := GameState.power_selected(id)
		var prism := GameState.is_player_class("elementalist") and GameState.passive() == "prism"
		buy.text = ("Selected (base)" if prism else "Selected") if picked else "Select"
		buy.disabled = picked
		detail.cost_row.visible = false
		return
	if maxed:
		buy.text = "Maxed"
		buy.disabled = true
	elif holder != "":
		buy.text = "Sealed - " + GameState.node_seal_text(kind, id).replace(holder, holder.capitalize())
		buy.disabled = true
	elif have < cost:
		buy.text = "Need %d more" % (cost - have)
		buy.disabled = true
	else:
		buy.text = "Buy" if node.max_level == 1 else "Buy level %d" % (level + 1)
		buy.disabled = false


# --- Attributes ------------------------------------------------------------------

## Fighter (camp pass 2): ATTRIBUTES | DECK over the page. Attributes is the
## ring (AttributeRing) with its detail beside it; Deck is the deck page.
func _build_fighter_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	top.add_child(_fighter_switch())
	_points_pill = PanelContainer.new()
	_points_pill.add_theme_stylebox_override("panel", UiTheme.box(Color(0.54, 0.29, 0.9, 0.22), Color(0.54, 0.29, 0.9, 0.7), 1, 16, 6.0))
	_points_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_points_label = UiTheme.title_label("", 15, Color(0.85, 0.72, 1.0))
	_points_label.add_theme_constant_override("outline_size", 0)
	_points_pill.add_child(_points_label)
	top.add_child(_points_pill)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_fighter_buttons = HBoxContainer.new()
	_fighter_buttons.add_theme_constant_override("separation", 10)
	top.add_child(_fighter_buttons)
	if _ability_choices() > 2:
		_loadout_button = Button.new()
		_loadout_button.text = "Loadout"
		_loadout_button.tooltip_text = "Pick your fighter's passive and ultimate."
		_loadout_button.pressed.connect(_open_loadout)
		_fighter_buttons.add_child(_loadout_button)
	var change := Button.new()
	change.text = "Change fighter"
	change.tooltip_text = "Pick another fighter on the title screen."
	change.pressed.connect(func() -> void:
		GameState.save_game()
		Loading.go("res://title.tscn"))
	_fighter_buttons.add_child(change)
	_reset_button = Button.new()
	_reset_button.tooltip_text = "Every attribute point back."
	_reset_button.pressed.connect(func() -> void:
		if GameState.reset_attributes():
			Sfx.play("coin", -6.0, 0.8)
		else:
			_chips.coins.deny())
	_fighter_buttons.add_child(_reset_button)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stack)
	var attributes := HBoxContainer.new()
	attributes.add_theme_constant_override("separation", 14)
	attributes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(attributes)
	var canvas := PanelContainer.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.02, 0.02, 0.04, 0.28), Color(UiTheme.GOLD, 0.18), 1, 12))
	attributes.add_child(canvas)
	_ring = AttributeRing.new()
	_ring.picked.connect(func(attribute: String) -> void:
		_attr_selected = attribute
		_refresh_attr_detail())
	canvas.add_child(_ring)
	var detail := PanelContainer.new()
	detail.custom_minimum_size.x = DETAIL_WIDTH
	detail.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.055, 0.05, 0.07, 0.72), Color(UiTheme.GOLD, 0.2), 1, 12, 18.0))
	attributes.add_child(detail)
	_attr_detail = VBoxContainer.new()
	_attr_detail.add_theme_constant_override("separation", 10)
	detail.add_child(_attr_detail)
	_sheet = GridContainer.new()
	_sheet.columns = 2
	_sheet.add_theme_constant_override("h_separation", 16)
	_sheet.add_theme_constant_override("v_separation", 6)
	_sheet_scroll = KeptScroll.new()
	_sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet_scroll.add_child(_sheet)
	_fighter_views["attributes"] = attributes
	_deck = DeckPage.new()
	_deck.draw_requested.connect(_open_draw)
	_deck.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_deck)
	_fighter_views["deck"] = _deck
	_set_fighter_tab("attributes")
	return column


## The ATTRIBUTES | DECK switch: a pill with the open side filled gold.
func _fighter_switch() -> Control:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.025, 0.04, 0.7), UiTheme.BORDER, 1, 22, 4.0))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	pill.add_child(row)
	var group := ButtonGroup.new()
	for tab in [["attributes", "ATTRIBUTES"], ["deck", "DECK"]]:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_override("font", UiTheme.display_font())
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_constant_override("outline_size", 0)
		var flat := UiTheme.box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 18, 0.0)
		flat.content_margin_left = 18
		flat.content_margin_right = 18
		flat.content_margin_top = 6
		flat.content_margin_bottom = 5
		var lit := UiTheme.box(UiTheme.GOLD, Color.TRANSPARENT, 0, 18, 0.0)
		lit.content_margin_left = 18
		lit.content_margin_right = 18
		lit.content_margin_top = 6
		lit.content_margin_bottom = 5
		for state in ["normal", "hover", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, flat)
		for state in ["pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, lit)
		button.add_theme_color_override("font_color", UiTheme.MUTED)
		button.add_theme_color_override("font_hover_color", UiTheme.TEXT)
		for state in ["font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, Color(0.14, 0.09, 0.02))
		button.pressed.connect(_set_fighter_tab.bind(tab[0]))
		row.add_child(button)
		_fighter_tab_buttons[tab[0]] = button
		if tab[0] == "deck":
			_deck_switch = button
	return pill


func _set_fighter_tab(tab: String) -> void:
	for id in _fighter_views:
		_fighter_views[id].visible = id == tab
	for id in _fighter_tab_buttons:
		_fighter_tab_buttons[id].set_pressed_no_signal(id == tab)
	if _fighter_buttons:
		_fighter_buttons.visible = tab == "attributes"
	if _points_pill:
		_points_pill.visible = tab == "attributes" and GameState.attribute_points > 0


## Opens Fighter on its Deck tab (the draw offer, tips).
func _show_deck() -> void:
	_show_page("Attributes")
	_set_fighter_tab("deck")


## The detail beside the ring: the picked attribute's perks and a spend
## button, or the fighter's stats when they are picked.
func _refresh_attr_detail() -> void:
	if _attr_detail == null:
		return
	for child in _attr_detail.get_children():
		_attr_detail.remove_child(child)
		if child != _sheet_scroll:
			child.queue_free()
	if _attr_selected == "" or not Attributes.LIST.has(_attr_selected):
		_attr_detail.add_child(UiTheme.title_label(GameState.fighter_name().to_upper(), 28, UiTheme.GOLD))
		_attr_detail.add_child(_label("Level %d  ·  %s" % [GameState.level, GameState.CLASSES[GameState.player_class].name], 14, UiTheme.MUTED))
		_attr_detail.add_child(_sheet_scroll)
		return
	var info: Dictionary = Attributes.LIST[_attr_selected]
	var tint: Color = info.color
	var have := int(GameState.attributes.get(_attr_selected, 0))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_attr_detail.add_child(head)
	var icon := IconView.new()
	icon.icon = info.icon
	icon.color = tint
	icon.custom_minimum_size = Vector2(46, 46)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.add_child(UiTheme.title_label(String(info.name).to_upper(), 28, tint.lightened(0.1)))
	names.add_child(_label("%d / %d points" % [have, Attributes.MAX], 14, UiTheme.MUTED))
	head.add_child(names)
	_attr_detail.add_child(_label("Every point: " + info.text, 14, Color(0.84, 0.81, 0.88)))
	for i in info.perks.size():
		var perk: Array = info.perks[i]
		var need: int = Attributes.PERK_AT[i]
		var on := have >= need
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.8), 0.9) if on else Color(0, 0, 0, 0.3), Color(tint, 0.85 if on else 0.12), 1, 8, 10.0))
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		box.add_child(inner)
		var line := HBoxContainer.new()
		inner.add_child(line)
		var perk_name := UiTheme.title_label(String(perk[1]), 17, UiTheme.TEXT if on else UiTheme.MUTED)
		perk_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(perk_name)
		line.add_child(_label("EARNED" if on else "AT %d" % need, 12, tint.lightened(0.2) if on else UiTheme.MUTED))
		var text := _label(String(perk[2]), 13, UiTheme.TEXT if on else UiTheme.MUTED.darkened(0.15))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(text)
		_attr_detail.add_child(box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_attr_detail.add_child(spacer)
	var points := GameState.attribute_points
	var spend := Button.new()
	spend.theme_type_variation = "PrimaryButton"
	spend.custom_minimum_size = Vector2(0, 46)
	spend.add_theme_font_size_override("font_size", 18)
	spend.text = "Spend a point  ·  %d left" % points
	spend.disabled = points <= 0 or have >= Attributes.MAX
	var which := _attr_selected
	spend.pressed.connect(func() -> void:
		if GameState.spend_attribute(which):
			Sfx.play("clear", -8.0, 1.2))
	_attr_detail.add_child(spend)




func _refresh_attributes() -> void:
	var points := GameState.attribute_points
	var spent := 0
	for attribute in Attributes.LIST:
		spent += int(GameState.attributes.get(attribute, 0))
	if _ring:
		_ring.refresh()
	if _points_label:
		_points_label.text = "%d POINT%s TO SPEND" % [points, "" if points == 1 else "S"]
		_points_pill.visible = points > 0 and _fighter_views.get("attributes", null) != null and _fighter_views["attributes"].visible
	var cost := Attributes.reset_cost()
	_reset_button.text = "Reset  ·  %d coins" % cost
	_reset_button.disabled = spent == 0
	_refresh_attr_detail()


func _refresh_sheet() -> void:
	# Out of the grid now, not at the end of the frame: for a frame it would
	# hold both sets of rows and stretch the page.
	for child in _sheet.get_children():
		_sheet.remove_child(child)
		child.queue_free()
	var damage := GameState.get_damage()
	var lines := [
		["Fighter", "%s  (%s)" % [GameState.fighter_name(), GameState.CLASSES[GameState.player_class].name]],
		["Jab damage", "%.1f  (head %.1f)" % [damage, damage * (Enemy.HEAD_MULTIPLIER + GameState.get_effect("head_bonus"))]],
		["Max knuckle HP", "%d" % roundi(GameState.get_max_knuckles())],
		["Passive", "%s  ·  %s" % [String(Abilities.info(GameState.player_class, GameState.passive()).get("name", "")),
				Abilities.power_text(GameState.passive(), GameState.passive_power()) if GameState.passive_power() > 0.0 else "grows with levels"]],
		["Punch cost", "Jab/cross 1, hook 2, uppercut 3"],
		["Defense", "%d" % roundi(GameState.get_defense())],
		["Punch speed", "x%.2f" % GameState.get_punch_speed()],
		["Combo growth", "+%.2f per hit" % GameState.get_combo_step()],
		["Combo time", "%.1fs" % GameState.get_combo_window()],
		["Counter", "x%.2f" % GameState.get_counter_multiplier(Player.COUNTER_MULTIPLIER)],
		["Dodge windows", "x%.2f  (+%d/%d%%)" % [GameState.get_dodge_window_multiplier(),
				roundi(minf(GameState.get_effect("dodge_window"), GameState.MAX_DODGE_WINDOW_BONUS) * 100.0), roundi(GameState.MAX_DODGE_WINDOW_BONUS * 100.0)]],
		["Counter window", "%.2fs  (+%.2f/%.2fs)" % [Player.COUNTER_WINDOW + GameState.get_counter_window_bonus(),
				GameState.get_counter_window_bonus(), GameState.MAX_COUNTER_WINDOW_BONUS]],
		["Armor ignored", "%d%%" % roundi(GameState.get_armor_pierce() * 100.0)],
		["Coins", "x%.2f" % GameState.get_coin_multiplier()],
		["XP", "x%.2f" % (1.0 + GameState.get_effect("xp_bonus"))],
	]
	for line in lines:
		_sheet.add_child(_label(line[0], 14, UiTheme.MUTED))
		_sheet.add_child(_label(line[1], 14))


# --- Class ------------------------------------------------------------------------

# --- Refresh & navigation --------------------------------------------------------

func _refresh() -> void:
	_level_label.text = "%s:  Lvl %d" % [GameState.fighter_name(), GameState.level]
	_level_label.add_theme_color_override("font_color", GameState.fighter_color().lightened(0.1))
	_theme_header()
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	_xp_label.text = "%d / %d XP" % [GameState.xp, GameState.xp_to_next()]
	_chips.coins.set_amount(GameState.resources.get("coins", 0), _shown_once)
	_refresh_bounties()
	_chips.souls.set_amount(GameState.souls, _shown_once)
	_chips.draws.set_amount(GameState.usable_draws(), _shown_once)
	_chips.attribute_points.set_amount(GameState.attribute_points, _shown_once)
	_shown_once = true
	# Your POWER: every stat, upgrade, skill and item in one number.
	var power := PowerRating.player()
	_night_label.text = "POWER  %d" % power
	_night_label.add_theme_color_override("font_color", UiTheme.GOLD)
	# Over 9,000: the Intense Yelling emote. Builds that qualify win hats.
	if power >= Achievements.POWER_YELL:
		Achievements.earn("power_9001")
	Hats.check_awards(get_tree())
	_refresh_armory()
	_refresh_hat_rack()
	_refresh_shop()

	for kind in _trees:
		var tree: SkillTreeView = _trees[kind]
		# Switching class hides the old class column; move the selection off it.
		tree.refresh()  # Rebuilds the skill web if the class changed.
		if not GameState.tree(kind).has(tree.selected_id) or GameState.node_state(kind, tree.selected_id) == "hidden":
			tree.selected_id = GameState.tree(kind).keys()[0]
			tree.refresh()
		_refresh_detail(kind)
	# The Fighter button counts everything waiting: attribute points and card draws.
	_set_tab_count("Attributes", GameState.attribute_points + GameState.usable_draws())
	if _deck_switch:
		_set_count_on(_deck_switch, GameState.usable_draws())
	_refresh_home()
	_refresh_attributes()
	_refresh_sheet()


## Arena: pick a division (each opens with the seal before it).
func _pick_division() -> void:
	var options := []
	for i in Progression.TIER_COUNT:
		var bouts := mini(int(GameState.arena_bouts.get(str(i + 1), 0)), Progression.BOUTS_PER_DIVISION)
		# Runs pick up at your next unbeaten bout: recommend for that one.
		var next_bout := clampi(bouts + 1, 1, Progression.BOUTS_PER_DIVISION)
		options.append({"name": Progression.TIERS[i].division.to_upper(), "pips": [bouts, Progression.BOUTS_PER_DIVISION],
			"open": i + 1 <= Progression.current_tier(), "tier": i + 1, "value": i + 1,
			"lines": _power_lines(PowerRating.arena_power(i + 1, next_bout))})
	_pick("UNDERWORLD ARENA", options, func(division: int) -> void:
		GameState.arena_division = division
		_pick_bout(division))


## A pick card's POWER readout (2026-11-03): the recommended POWER, then yours
## with the Dead League's verdict and colors.
func _power_lines(recommended: int) -> Array:
	var mine := PowerRating.player()
	var verdict := PowerRating.verdict(mine, recommended)
	var ratio: float = verdict[1]
	var color: Color = UiTheme.BAD if ratio < 0.88 else (UiTheme.GOLD if ratio < 0.97 else UiTheme.GOOD)
	return [["REC. POWER  %d" % recommended, UiTheme.MUTED], ["YOU  %d" % mine, color], [verdict[0], color]]


## Then the bout: any you've won (to farm it) or the next one. Harder bouts
## pay more. With nothing won yet it goes straight in.
func _pick_bout(division: int) -> void:
	var won := mini(int(GameState.arena_bouts.get(str(division), 0)), Progression.BOUTS_PER_DIVISION)
	if won == 0:
		GameState.arena_bout_pick = 1
		_start_run()
		return
	var options := []
	var base := Progression.pay(Progression.arena_position(division, 1))
	for bout in range(1, mini(won + 1, Progression.BOUTS_PER_DIVISION) + 1):
		var state := "WON" if bout <= won else "NEXT"
		if bout == Progression.BOUTS_PER_DIVISION:
			# The third bout is endless: 50 knockouts win it, then it's for a score.
			options.append({"name": "ENDLESS", "number": "%d" % bout, "tier": division, "open": true, "value": bout,
				"detail": "%s   ·   BEST %d" % [state, GameState.endless_best_in(division)],
				"lines": _power_lines(PowerRating.arena_power(division, bout))})
			continue
		options.append({"name": "BOUT %d" % bout, "number": "%d" % bout, "tier": division, "open": true, "value": bout,
			"detail": state + "   ·   x%s pay" % String.num(Progression.pay(Progression.arena_position(division, bout)) / base, 2),
			"lines": _power_lines(PowerRating.arena_power(division, bout))})
	_pick("%s DIVISION" % Progression.TIERS[division - 1].division.to_upper(), options, func(bout: int) -> void:
		GameState.arena_bout_pick = bout
		_start_run())


## Crypt: pick a pair of floors to start on (one pair per contender beaten),
## or, once floor 10 is beaten, the endless floors from a checkpoint.
func _pick_crypt_floors() -> void:
	var options := []
	for i in Progression.TIER_COUNT:
		var first := Progression.crypt_start_floor(i + 1)
		options.append({"name": "FLOORS %d-%d" % [first, first + 1], "open": Progression.crypt_floor_open(first), "tier": i + 1, "value": i + 1,
			"lines": _power_lines(PowerRating.crypt_power(first))})
	var checkpoints := Progression.crypt_checkpoints()
	if not checkpoints.is_empty():
		options.append({"name": "ENDLESS", "number": "%d+" % checkpoints[0], "number_size": 48, "open": true, "tier": Progression.TIER_COUNT,
			"value": 0, "detail": "Checkpoints: %s" % ", ".join(checkpoints.map(func(f: int) -> String: return str(f))),
			"lines": _power_lines(PowerRating.crypt_power(checkpoints[0]))})
	_pick("THE CRYPT", options, func(tier: int) -> void:
		if tier == 0:
			_pick_crypt_checkpoint(checkpoints)
			return
		GameState.crypt_tier = tier
		GameState.crypt_start_pick = 0
		_start_crypt())


## The endless floors: start from floor 11 or any checkpoint reached (15, 20 ...).
func _pick_crypt_checkpoint(checkpoints: Array) -> void:
	if checkpoints.size() == 1:
		GameState.crypt_start_pick = checkpoints[0]
		_start_crypt()
		return
	var options := []
	for floor_number in checkpoints:
		options.append({"name": "FLOOR %d" % floor_number, "number": "%d" % floor_number, "number_size": 48,
			"open": true, "tier": Progression.TIER_COUNT, "value": floor_number, "lines": _power_lines(PowerRating.crypt_power(floor_number))})
	_pick("ENDLESS CRYPT", options, func(floor_number: int) -> void:
		GameState.crypt_start_pick = floor_number
		_start_crypt(), "Start from a checkpoint")


## A row of big cards, one per tier, edged in that tier's contender's color.
## Sealed ones show who holds the seal. options: {name, open, tier, value, pips}.
func _pick(title: String, options: Array, callback: Callable, subtitle := "") -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var close := func() -> void: layer.queue_free()
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close.call())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	var heading := UiTheme.title_label(title, 48, UiTheme.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	if subtitle != "":
		var sub := _label(subtitle, 16, UiTheme.MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)
	for option in options:
		if not option.open:
			continue  # Sealed tiers aren't shown until they open.
		var accent: Color = DeadLeagueRules.boss(option.tier - 1).accent
		var card := Button.new()
		var card_size: Vector2 = option.get("card_size", Vector2(210, 290) if option.has("lines") else Vector2(200, 230))
		card.custom_minimum_size = card_size
		card.disabled = not option.open
		var face := UiTheme.raised(Color(0.06, 0.05, 0.08, 0.96), Color(accent, 0.75), 2, 12)
		var hover := UiTheme.raised(Color(accent.darkened(0.75), 0.98), accent.lightened(0.2), 3, 12)
		hover.shadow_color = Color(accent, 0.4)
		hover.shadow_size = 14
		var sealed := UiTheme.raised(Color(0.03, 0.03, 0.04, 0.96), Color(UiTheme.BORDER, 0.6), 2, 12)
		card.add_theme_stylebox_override("normal", face)
		card.add_theme_stylebox_override("hover", hover)
		card.add_theme_stylebox_override("pressed", hover)
		card.add_theme_stylebox_override("disabled", sealed)
		row.add_child(card)
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		inside.add_theme_constant_override("separation", 10)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inside)
		var number := UiTheme.title_label(option.get("number", "%d" % option.tier), option.get("number_size", 64), accent.lightened(0.2) if option.open else UiTheme.BORDER)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(number)
		var label := UiTheme.title_label(option.name, 22, UiTheme.TEXT if option.open else UiTheme.MUTED.darkened(0.3))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(label)
		if option.has("detail"):
			var detail := _label(option.detail, 14, UiTheme.MUTED)
			detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size.x = card_size.x - 24
			inside.add_child(detail)
		for line in option.get("lines", []):
			var extra := _label(line[0], 15, line[1])
			extra.add_theme_font_override("font", UiTheme.bold_font())
			extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inside.add_child(extra)
		if not option.open:
			var holder := _label("SEALED BY\n" + DeadLeagueRules.boss(option.tier - 2).name, 13, UiTheme.SIGIL)
			holder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inside.add_child(holder)
		elif option.has("pips"):
			var pips := HBoxContainer.new()
			pips.alignment = BoxContainer.ALIGNMENT_CENTER
			pips.add_theme_constant_override("separation", 6)
			pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for k in option.pips[1]:
				var pip := Panel.new()
				pip.custom_minimum_size = Vector2(16, 16)
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var won: bool = k < option.pips[0]
				pip.add_theme_stylebox_override("panel", UiTheme.box(accent if won else Color(0, 0, 0, 0.4), Color(accent, 0.8), 2, 8))
				pips.add_child(pip)
			inside.add_child(pips)
		var value = option.value
		card.pressed.connect(func() -> void:
			Sfx.play("tick")
			close.call()
			callback.call(value))


func _start_run() -> void:
	GameState.save_game()
	Loading.go("res://world.tscn")


const DRILLS := ["pads", "slip", "bags"]
const DRILL_CARDS := {
	"pads": ["PADS", "PAD WORK", "Throw the combo the coach calls"],
	"slip": ["SLIP", "SLIP LINE", "Dodge everything it throws"],
	"bags": ["BAGS", "HEAVY BAGS", "Knock bags off the rack in 60s"],
}


## Daily drills: pick one. Each pays once a day for your score; after that
## it's practice for a best score.
func _pick_drill() -> void:
	var options := []
	for id in DRILLS:
		var card: Array = DRILL_CARDS[id]
		var best := int(GameState.drills.get(id, {}).get("best", 0))
		var ready := GameState.drill_ready(id)
		options.append({"name": card[1], "number": card[0], "number_size": 40, "tier": 1, "open": true, "value": id,
			"card_size": Vector2(260, 290), "detail": card[2],
			"lines": [["REWARD READY" if ready else "PRACTICE", UiTheme.GOOD if ready else UiTheme.MUTED],
				["BEST  %d" % best, UiTheme.TEXT]]})
	_pick("DAILY DRILLS", options, func(id: String) -> void:
		GameState.drill_pick = id
		GameState.save_game()
		Loading.go("res://drills.tscn"), "Rewards pay at your furthest fight:  " + GameState.climb_place())


func _start_crypt() -> void:
	GameState.crypt_new = false
	GameState.save_game()
	Loading.go("res://dungeon.tscn")


func _start_training() -> void:
	GameState.save_game()
	Loading.go("res://training.tscn")


func _start_dead_league() -> void:
	if not _league_open():
		return
	GameState.save_game()
	Loading.go("res://dead_league_menu.tscn")


# --- Armory -------------------------------------------------------------------------

## The Locker (2026-11-05): the four worn slots in a strip on top, every kept
## piece below in an even grid with slot pills, and the one you tap on the
## right as its big turning card (stats against what's worn) with Wear,
## Level up and Sell. Only the detail card turns in 3D: a grid of live models
## would be too much for phones.
const ARMORY_FILTERS := ["All", "Gloves", "Wraps", "Boots", "Charm"]
const ARMORY_TILE := Vector2(132, 118)
var _armory_worn: HBoxContainer
var _armory_list: GridContainer
var _armory_title: Label
var _armory_detail: VBoxContainer
var _armory_pills := {}
var _armory_filter := "All"
var _armory_pick := -1  # The uid shown on the right (-1: the first worn or kept).


func _build_armory_page() -> Control:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	root.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	page.add_child(header)
	header.add_child(UiTheme.title_label("ARMORY", 26, UiTheme.GOLD))
	_armory_title = _label("", 15, UiTheme.MUTED)
	_armory_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_armory_title)
	_armory_worn = HBoxContainer.new()
	_armory_worn.add_theme_constant_override("separation", 10)
	page.add_child(_armory_worn)
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	page.add_child(left)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 6)
	left.add_child(pills)
	for filter_name in ARMORY_FILTERS:
		var pill := Button.new()
		pill.text = filter_name
		pill.toggle_mode = true
		pill.button_pressed = filter_name == _armory_filter
		pill.pressed.connect(func() -> void:
			_armory_filter = filter_name
			_refresh_armory())
		pills.add_child(pill)
		_armory_pills[filter_name] = pill
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	# Rows of four, lined up under the four worn slots.
	_armory_list = GridContainer.new()
	_armory_list.columns = Items.SLOTS.size()
	_armory_list.add_theme_constant_override("h_separation", 10)
	_armory_list.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_armory_list)
	var detail_scroll := KeptScroll.new()
	detail_scroll.custom_minimum_size.x = ItemCard.WIDTH + 16
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(detail_scroll)
	_armory_detail = VBoxContainer.new()
	_armory_detail.add_theme_constant_override("separation", 8)
	_armory_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(_armory_detail)
	return root


func _refresh_armory() -> void:
	# Locked until you bring back your first gear (2026-10-29).
	if _tab_buttons.has("Armory"):
		_tab_buttons["Armory"].visible = not GameState.armory.is_empty() or not GameState.equipped.is_empty()
	if _armory_list == null:
		return
	for box in [_armory_worn, _armory_list, _armory_detail]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for filter_name in _armory_pills:
		_armory_pills[filter_name].set_pressed_no_signal(filter_name == _armory_filter)
	_armory_title.text = "Kept %d" % GameState.armory.size()
	# Who's on the right: your pick if it's still yours, else the first worn
	# piece, else the first kept one.
	var shown := _armory_shown()
	for slot in Items.SLOTS:
		var item: Dictionary = GameState.equipped.get(slot, {})
		_armory_worn.add_child(_armory_tile(item, String(Items.SLOT_NAMES[slot]).to_upper(), shown, slot))
	var kept: Array = GameState.armory.filter(func(item: Dictionary) -> bool:
		return _armory_filter == "All" or Items.SLOT_NAMES.get(item.slot, "") == _armory_filter)
	if kept.is_empty():
		_armory_list.add_child(_label("Nothing kept yet. Gild finds in the Crypt to keep them." if GameState.armory.is_empty() else "No %s kept." % _armory_filter.to_lower(), 15, UiTheme.MUTED))
	for item in kept:
		_armory_list.add_child(_armory_tile(item, "WORN" if _is_worn(item) else "", shown))
	_armory_show_detail(shown)


func _is_worn(item: Dictionary) -> bool:
	return int(GameState.equipped.get(item.get("slot", ""), {}).get("uid", -1)) == int(item.get("uid", -2))


func _armory_shown() -> Dictionary:
	for item in GameState.armory:
		if int(item.get("uid", -2)) == _armory_pick:
			return item
	for slot in Items.SLOTS:
		if GameState.equipped.has(slot):
			return GameState.equipped[slot]
	return GameState.armory[0] if not GameState.armory.is_empty() else {}


## A small tile: the slot's icon in the rarity's color, the name, slot and
## level. Tap to show it on the right. An empty worn slot is a dashed box.
func _armory_tile(item: Dictionary, tag: String, shown: Dictionary, empty_slot := "") -> Control:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = ARMORY_TILE
	if item.is_empty():
		tile.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.14), 1, 10, 8.0))
		var empty := VBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(empty)
		var icon := IconView.new()
		icon.icon = Items.SLOT_ICONS[empty_slot]
		icon.color = Color(1, 1, 1, 0.25)
		icon.custom_minimum_size = Vector2(36, 36)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty.add_child(icon)
		var label := _label("%s\nempty" % Items.SLOT_NAMES[empty_slot], 12, UiTheme.MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(label)
		return tile
	var tint := Items.rarity_color(item)
	var picked: bool = int(item.get("uid", -2)) == int(shown.get("uid", -3))
	var worn := _is_worn(item)
	tile.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.82), 0.68),
			Color.WHITE if picked else (UiTheme.GOLD if worn else Color(tint, 0.85)), 3 if picked or worn else 2, 10, 8.0))
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var uid := int(item.get("uid", -1))
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_armory_pick = uid
			Sfx.play("tick")
			_refresh_armory())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var icon := IconView.new()
	icon.icon = Items.SLOT_ICONS.get(item.slot, "star")
	icon.color = tint.lightened(0.15)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(icon)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gap)
	if tag != "":
		var tag_label := _label(tag, 10, UiTheme.GOLD)
		tag_label.add_theme_font_override("font", UiTheme.bold_font())
		tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(tag_label)
	var name_label := _label(String(item.name), 13, tint.lightened(0.15))
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var kind := _label("%s  ·  Lv %d" % [Items.SLOT_NAMES.get(item.slot, ""), int(item.get("level", 1))], 11, UiTheme.MUTED)
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(kind)
	return tile


## The right side: the piece's big turning card (against what you wear in that
## slot, when it isn't that), then Wear / Take off, Level up and Sell.
func _armory_show_detail(item: Dictionary) -> void:
	if item.is_empty():
		_armory_detail.add_child(_label("Your gear shows here.", 15, UiTheme.MUTED))
		return
	var worn := _is_worn(item)
	var against: Dictionary = {} if worn else GameState.equipped.get(item.slot, {})
	var card := ItemCard.make(item, "WORN NOW" if worn else "KEPT", against)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_armory_detail.add_child(card)
	var uid := int(item.get("uid", -1))
	var kept := not GameState.armory_item(uid).is_empty()
	var wear := Button.new()
	wear.custom_minimum_size = Vector2(0, 40)
	if worn:
		wear.text = "Take off"
		wear.pressed.connect(func() -> void:
			GameState.unequip(item.slot)
			Sfx.play("tick"))
	else:
		wear.text = "Wear"
		wear.theme_type_variation = "PrimaryButton"
		wear.disabled = not kept
		wear.pressed.connect(func() -> void:
			GameState.equip_from_armory(uid)
			Sfx.play("unlock", -8.0, 1.3))
	_armory_detail.add_child(wear)
	if not kept:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_armory_detail.add_child(row)
	# Gear levels up for Souls, as far as the deepest floor you've beaten
	# allows (Gear.level_cap), and sells for gold (2026-11-04).
	var cost := Gear.level_up_cost(item)
	var capped := int(item.get("level", 1)) >= Gear.level_cap()
	var level_up := Button.new()
	level_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_up.custom_minimum_size.y = 40
	level_up.disabled = capped or GameState.souls < cost
	level_up.tooltip_text = "Beat deeper Crypt floors to level it further." if capped else ""
	IconLabel.on_button(level_up, "Max level" if capped else "Level up  %d {souls}" % cost, 15)
	level_up.pressed.connect(func() -> void:
		if GameState.level_up(uid):
			Sfx.play("unlock", -8.0, 1.2))
	row.add_child(level_up)
	var sell := Button.new()
	sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell.custom_minimum_size.y = 40
	sell.disabled = worn
	sell.tooltip_text = "Take it off first." if worn else ""
	IconLabel.on_button(sell, "Sell  +%d {coins}" % Gear.sell_price(item), 15)
	sell.pressed.connect(func() -> void:
		_armory_pick = -1
		GameState.sell(uid))
	row.add_child(sell)


# --- Hat Rack ----------------------------------------------------------------------

var _hat_title: Label
var _hat_grid: GridContainer


# --- Cosmetics -------------------------------------------------------------------------

const COSMETICS := ["Hats", "Emotes", "Hand Idles", "Skins"]
var _cosmetic_tab := "Hats"
var _cosmetic_pages := {}
var _cosmetic_buttons := {}
var _idle_grid: GridContainer
var _emote_grid: GridContainer
var _emote_title: Label
var _emote_stage: EmotePreview
var _emote_equip: Button
var _emote_slots: HBoxContainer


## The page style (2026-11-05): no big panel, the cards float over the camp.
func _clear_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 6.0))


## Every hat, common first up to legendary; the catalog's order within a rarity.
func _hats_by_rarity() -> Array:
	var order := ["common", "uncommon", "rare", "epic", "legendary"]
	var ids: Array = Hats.CATALOG.keys()
	var ranked: Array = []
	for i in ids.size():
		ranked.append([order.find(Hats.CATALOG[ids[i]].rarity), i, ids[i]])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return ranked.map(func(entry: Array) -> String: return entry[2])


## Hats, emotes, hand idles and skins, each on its own tab.
func _build_cosmetics_page() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(area)
	var group := ButtonGroup.new()
	var builders := {"Hats": _build_hat_rack, "Emotes": _build_emote_page, "Hand Idles": _build_idle_page, "Skins": _build_skins_page}
	for page_name in COSMETICS:
		var button := Button.new()
		button.text = page_name
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_show_cosmetic.bind(page_name))
		tabs.add_child(button)
		_cosmetic_buttons[page_name] = button
		var page: Control = (builders[page_name] as Callable).call()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		area.add_child(page)
		_cosmetic_pages[page_name] = page
	_show_cosmetic("Hats")
	return column


func _show_cosmetic(page_name: String) -> void:
	_cosmetic_tab = page_name
	for page in _cosmetic_pages:
		_cosmetic_pages[page].visible = page == page_name
		_cosmetic_buttons[page].set_pressed_no_signal(page == page_name)
	match page_name:
		"Emotes":
			_refresh_emotes()
		"Hand Idles":
			_refresh_idles()
		"Skins":
			_refresh_skins()


## Your fighter on a little stage doing the emote you click (wearing your hat),
## beside every emote you own.
func _build_emote_page() -> Control:
	var panel := PanelContainer.new()
	_clear_panel(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_emote_stage = EmotePreview.new(GameState.player_class, 5.4)
	_emote_stage.custom_minimum_size = Vector2(320, 0)
	row.add_child(_emote_stage)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	row.add_child(column)
	_emote_title = UiTheme.title_label("EMOTES", 26, UiTheme.GOLD)
	column.add_child(_emote_title)
	var tip := _label("%s to preview, then put up to %d on your wheel. Hold %s in a fight to open it." % [Controls.tap_word(), GameState.EMOTE_SLOTS, Controls.key_name("emote")], 13, UiTheme.MUTED)
	column.add_child(tip)
	Controls.watch(tip, func() -> void:
		tip.text = "%s to preview, then put up to %d on your wheel. Hold %s in a fight to open it." % [Controls.tap_word(), GameState.EMOTE_SLOTS, Controls.key_name("emote")])
	# The wheel: six slots, and the button that puts the emote on stage in or out.
	_emote_slots = HBoxContainer.new()
	_emote_slots.add_theme_constant_override("separation", 6)
	column.add_child(_emote_slots)
	_emote_equip = Button.new()
	_emote_equip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_emote_equip.pressed.connect(func() -> void:
		if Achievements.toggle_equipped(_emote_stage.body.playing()):
			Sfx.play("tick")
		else:
			Sfx.play("deny", -10.0)
		_refresh_emotes())
	column.add_child(_emote_equip)
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_emote_grid = GridContainer.new()
	_emote_grid.columns = 3
	_emote_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_emote_grid.add_theme_constant_override("h_separation", 10)
	_emote_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_emote_grid)
	return panel


func _refresh_emotes() -> void:
	if _emote_grid == null:
		return
	if _emote_stage.body.skin_id != GameState.skin():
		_emote_stage.wear(GameState.skin())
	var dancer := _emote_stage.body
	dancer.wear_hat(GameState.worn_hat)
	for child in _emote_grid.get_children():
		child.queue_free()
	var owned := Achievements.emotes()
	_emote_title.text = "EMOTES   %d / %d" % [owned.size(), Emotes.ORDER.size()]
	var tint := GameState.fighter_color()
	if not dancer.playing() in owned and not owned.is_empty():
		_emote_stage.play(owned[0])
	var wheel := Achievements.equipped_emotes()
	for child in _emote_slots.get_children():
		_emote_slots.remove_child(child)
		child.queue_free()
	_emote_slots.add_child(_label("WHEEL", 13, UiTheme.MUTED))
	for slot in GameState.EMOTE_SLOTS:
		var filled := slot < wheel.size()
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(82, 30)
		chip.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.04, 0.08, 0.6), Color(UiTheme.GOLD, 0.85) if filled else Color(1, 1, 1, 0.12), 2 if filled else 1, 8, 4.0))
		var chip_label := _label(Emotes.name_of(wheel[slot]) if filled else "-", 11, UiTheme.TEXT if filled else UiTheme.MUTED)
		chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_label.clip_text = true
		chip.add_child(chip_label)
		_emote_slots.add_child(chip)
	var on_stage: String = dancer.playing()
	var on_wheel := wheel.has(on_stage)
	_emote_equip.text = ("Take %s off the wheel" if on_wheel else "Put %s on the wheel") % Emotes.name_of(on_stage)
	_emote_equip.disabled = on_stage == "" or (not on_wheel and wheel.size() >= GameState.EMOTE_SLOTS) or (on_wheel and wheel.size() <= 1)
	for id in owned:
		var showing: bool = id == dancer.playing()
		var card := Button.new()
		card.text = Emotes.name_of(id) + ("   *" if wheel.has(id) else "")
		card.custom_minimum_size = Vector2(0, 64)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_override("font", UiTheme.bold_font())
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_color_override("font_color", UiTheme.GOLD if showing else UiTheme.TEXT)
		card.add_theme_stylebox_override("normal", UiTheme.raised(Color(0.06, 0.05, 0.08, 0.68), UiTheme.GOLD if showing else Color(tint, 0.5), 3 if showing else 2, 10))
		card.add_theme_stylebox_override("hover", UiTheme.raised(Color(tint.darkened(0.75), 0.8), tint.lightened(0.2), 3, 10))
		card.add_theme_stylebox_override("pressed", UiTheme.raised(Color(tint.darkened(0.75), 0.8), tint.lightened(0.2), 3, 10))
		card.pressed.connect(func() -> void:
			_emote_stage.play(id)
			_refresh_emotes())
		_emote_grid.add_child(card)


func _build_idle_page() -> Control:
	var panel := PanelContainer.new()
	_clear_panel(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiTheme.title_label("HAND IDLES", 26, UiTheme.GOLD))
	column.add_child(_label("What your hands do while you wait. Click one to equip it.", 13, UiTheme.MUTED))
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_idle_grid = GridContainer.new()
	_idle_grid.columns = 4
	_idle_grid.add_theme_constant_override("h_separation", 12)
	_idle_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_idle_grid)
	return panel


var _skin_grid: HFlowContainer
var _skin_note: Label


## Your fighter's looks (Skins): their own and the skins you've bought, each
## dancing on its card. Click one to wear it.
func _build_skins_page() -> Control:
	var panel := PanelContainer.new()
	_clear_panel(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(UiTheme.title_label("SKINS", 26, UiTheme.GOLD))
	_skin_note = _label("", 13, UiTheme.MUTED)
	column.add_child(_skin_note)
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_skin_grid = HFlowContainer.new()
	_skin_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skin_grid.add_theme_constant_override("h_separation", 12)
	_skin_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_skin_grid)
	return panel


func _refresh_skins() -> void:
	if _skin_grid == null:
		return
	for child in _skin_grid.get_children():
		child.queue_free()
	var fighter := GameState.player_class
	var owned: Array = Skins.of(fighter).filter(func(id: String) -> bool: return GameState.skins_owned.has(id))
	var for_sale := Skins.of(fighter).filter(func(id: String) -> bool: return not id in Skins.EARN_ONLY and not GameState.skins_owned.has(id))
	_skin_note.text = "Click one to wear it." + ("" if for_sale.is_empty() else "  More in the Soul Shop.")
	var tint := GameState.fighter_color()
	for id in [""] + owned:
		var wearing: bool = id == GameState.skin()
		var card := Button.new()
		card.custom_minimum_size = Vector2(240, 330)
		card.add_theme_stylebox_override("normal", UiTheme.raised(Color(0.06, 0.05, 0.08, 0.68), UiTheme.GOLD if wearing else Color(tint, 0.5), 3 if wearing else 2, 12))
		card.add_theme_stylebox_override("hover", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
		card.add_theme_stylebox_override("pressed", UiTheme.raised(Color(tint.darkened(0.75), 0.98), tint.lightened(0.2), 3, 12))
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.offset_left = 8
		inside.offset_right = -8
		inside.offset_top = 8
		inside.offset_bottom = -8
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(inside)
		var stage := EmotePreview.new(fighter, 3.6, id)
		stage.emote_id = "default"
		stage.custom_minimum_size = Vector2(224, 260)
		inside.add_child(stage)
		var name_label := _label(Skins.name_of(id) + ("   ·   WEARING" if wearing else ""), 15, UiTheme.GOLD if wearing else UiTheme.TEXT)
		name_label.add_theme_font_override("font", UiTheme.bold_font())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inside.add_child(name_label)
		card.pressed.connect(func() -> void:
			if GameState.equip_skin(fighter, id):
				Sfx.play("unlock", -8.0, 1.4)
				_refresh_skins())
		_skin_grid.add_child(card)


## Every hat on a peg: owned ones in color with their boost, missing ones as
## silhouettes.
func _build_hat_rack() -> Control:
	var panel := PanelContainer.new()
	_clear_panel(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_hat_title = UiTheme.title_label("HAT RACK", 26, UiTheme.GOLD)
	_hat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_hat_title)
	var tip := _label("%s a hat to wear it. Hold %s in a fight to emote and see it." % [Controls.tap_word(), Controls.key_name("emote")], 13, UiTheme.MUTED)
	column.add_child(tip)
	Controls.watch(tip, func() -> void:
		tip.text = "%s a hat to wear it. Hold %s in a fight to emote and see it." % [Controls.tap_word(), Controls.key_name("emote")])
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_hat_grid = GridContainer.new()
	_hat_grid.columns = 7
	_hat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hat_grid.add_theme_constant_override("h_separation", 10)
	_hat_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_hat_grid)
	return panel


func _refresh_hat_rack() -> void:
	if _hat_grid == null:
		return
	for child in _hat_grid.get_children():
		child.queue_free()
	var owned := 0
	for id in _hats_by_rarity():
		if GameState.hats.has(id):
			owned += 1
		_hat_grid.add_child(_hat_card(id))
	_hat_title.text = "HAT RACK   %d / %d" % [owned, Hats.CATALOG.size()]


func _hat_card(id: String) -> Control:
	var info := Hats.info(id)
	var have := GameState.hats.has(id)
	var tint := Hats.color(id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.8), 0.6) if have else Color(0, 0, 0, 0.35),
			Color(tint, 0.8) if have else Color(1, 1, 1, 0.08), 2 if have else 1, 10, 8.0))
	card.tooltip_text = (info.desc + "\nClick to wear it (you'll see it when you emote).") if have else "???"
	if have:
		var worn := GameState.worn_hat == id
		if worn:
			card.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.7), 0.8), UiTheme.GOLD, 3, 10, 8.0))
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.wear_hat(id)
				Sfx.play("tick")
				_refresh_hat_rack())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var thumb := TextureRect.new()
	thumb.texture = load("res://art/hats/%s.png" % id)
	thumb.custom_minimum_size = Vector2(0, 96)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not have:
		thumb.modulate = Color(0, 0, 0, 0.85)  # A silhouette.
	column.add_child(thumb)
	var name_label := _label(info.name if have else "???", 13, UiTheme.TEXT if have else UiTheme.MUTED)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	if have:
		var yonker := id in Hats.LEGENDARIES
		var boost := _label("Does nothing. Yet." if yonker else Hats.boost_text(id), 11, tint.lightened(0.3) if yonker else UiTheme.GOOD)
		boost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(boost)
		if GameState.worn_hat == id:
			var wearing := _label("WEARING", 12, UiTheme.GOLD)
			wearing.add_theme_font_override("font", UiTheme.bold_font())
			wearing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(wearing)
		if int(GameState.hats[id]) > 1:
			var count := _label("x%d" % int(GameState.hats[id]), 12, UiTheme.MUTED)
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(count)
	return card


# --- Bounties --------------------------------------------------------------------------

## The Shop look (2026-11-05): no big panel; the mastery bar with its XP and
## the rarity odds as pills on top; five even cards in a row, the last two
## locked slots until bought (Bounties.EXTRA_SLOT_SOULS); each card's button
## (Swap, Unlock) under it, outside the frame.
const BOUNTY_CARD := Vector2(204, 236)
var _bounty_grid: HBoxContainer
var _bounty_mastery: Label
var _bounty_xp: Label
var _bounty_bar: ProgressBar
var _bounty_odds: HBoxContainer


func _build_bounty_page() -> Control:
	var panel := PanelContainer.new()
	_clear_panel(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	column.add_child(header)
	header.add_child(UiTheme.title_label("BOUNTIES", 26, UiTheme.GOLD))
	_bounty_mastery = _label("", 18, UiTheme.TEXT)
	_bounty_mastery.add_theme_font_override("font", UiTheme.bold_font())
	_bounty_mastery.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_bounty_mastery)
	_bounty_bar = ProgressBar.new()
	_bounty_bar.show_percentage = false
	_bounty_bar.custom_minimum_size = Vector2(260, 10)
	_bounty_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_bounty_bar)
	_bounty_xp = _label("", 14, UiTheme.MUTED)
	_bounty_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_bounty_xp)
	_bounty_odds = HBoxContainer.new()
	_bounty_odds.add_theme_constant_override("separation", 6)
	column.add_child(_bounty_odds)
	_bounty_grid = HBoxContainer.new()
	_bounty_grid.add_theme_constant_override("separation", 12)
	column.add_child(_bounty_grid)
	var note := _label("Finish one and the next rolls in. Rarer bounties pay more; mastery makes them come up more often.", 13, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	return panel


func _refresh_bounties() -> void:
	if _bounty_grid == null:
		return
	_tab_buttons["Bounties"].visible = Bounties.unlocked()
	if not Bounties.unlocked():
		return
	var progress := Bounties.mastery_progress()
	_bounty_mastery.text = "Mastery %d" % Bounties.mastery()
	_bounty_bar.max_value = progress[1]
	_bounty_bar.value = progress[0]
	_bounty_xp.text = "%d / %d XP" % progress
	for box in [_bounty_odds, _bounty_grid]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	var odds := Bounties.odds()
	for i in Bounties.RARITIES.size():
		var rarity: String = Bounties.RARITIES[i]
		var tint: Color = Bounties.RARITY_COLORS[rarity]
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.82), 0.6), Color(tint, 0.6), 1, 12, 5.0))
		var text := _label("%s  %d%%" % [rarity.capitalize(), roundi(odds[i] * 100.0)], 13, tint.lightened(0.1))
		text.add_theme_font_override("font", UiTheme.bold_font())
		pill.add_child(text)
		_bounty_odds.add_child(pill)
	var active := Bounties.active()
	for i in active.size():
		_bounty_grid.add_child(_bounty_card(i, active[i]))
	for extra in range(GameState.bounty_slots_bought, Bounties.EXTRA_SLOT_SOULS.size()):
		_bounty_grid.add_child(_bounty_locked(extra))


## A card with its button under it, outside the frame (the Shop's way).
func _bounty_holder(card: Control, button: Button) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	holder.add_child(card)
	button.custom_minimum_size = Vector2(BOUNTY_CARD.x, 38)
	holder.add_child(button)
	return holder


func _bounty_card(index: int, bounty: Dictionary) -> Control:
	var tint: Color = Bounties.RARITY_COLORS[bounty.rarity]
	var card := PanelContainer.new()
	card.custom_minimum_size = BOUNTY_CARD
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.82), 0.68), Color(tint, 0.85), 2, 10, 12.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var rarity := _label(String(bounty.rarity).to_upper(), 12, tint)
	rarity.add_theme_font_override("font", UiTheme.bold_font())
	rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rarity)
	var icon := IconView.new()
	icon.icon = "wanted"
	icon.color = tint
	icon.custom_minimum_size = Vector2(26, 26)
	top.add_child(icon)
	var task := _label(Bounties.text(bounty), 17, UiTheme.TEXT)
	task.add_theme_font_override("font", UiTheme.bold_font())
	task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	task.custom_minimum_size.x = BOUNTY_CARD.x - 24
	column.add_child(task)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.max_value = 1.0
	bar.value = Bounties.fraction(bounty)
	column.add_child(bar)
	column.add_child(_label(Bounties.progress_text(bounty), 13, UiTheme.MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var reward := IconLabel.new()
	reward.font_size = 15
	reward.text = "+%d {coins}" % bounty.coins
	column.add_child(reward)
	var extra := IconLabel.new()
	extra.font_size = 15
	extra.text = ("+%d {souls}   " % bounty.souls if int(bounty.souls) > 0 else "") + "+%d XP" % bounty.xp
	column.add_child(extra)
	var swap := Button.new()
	IconLabel.on_button(swap, "Swap   %d {souls}" % Bounties.SWAP_SOULS)
	swap.disabled = GameState.souls < Bounties.SWAP_SOULS
	swap.tooltip_text = "Roll a different bounty."
	swap.pressed.connect(func() -> void:
		if Bounties.swap(index):
			Sfx.play("coin", -4.0, 0.8)
			_refresh())
	return _bounty_holder(card, swap)


## A slot not bought yet: a padlock, with its price. Only the next one can
## be bought.
func _bounty_locked(extra: int) -> Control:
	var price := int(Bounties.EXTRA_SLOT_SOULS[extra])
	var next := extra == GameState.bounty_slots_bought
	var card := PanelContainer.new()
	card.custom_minimum_size = BOUNTY_CARD
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), Color(1, 1, 1, 0.22 if next else 0.1), 1, 10, 12.0))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var icon := IconView.new()
	icon.icon = "lock"
	icon.color = Color(1, 1, 1, 0.55 if next else 0.25)
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var title := _label("EXTRA SLOT", 15, UiTheme.TEXT if next else UiTheme.MUTED)
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := _label("One more bounty at a time." if next else "Unlock the one before first.", 12, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var unlock := Button.new()
	IconLabel.on_button(unlock, "Unlock   %d {souls}" % price)
	unlock.disabled = not next or GameState.souls < price
	if next:
		unlock.theme_type_variation = "PrimaryButton" if GameState.souls >= price else ""
	unlock.pressed.connect(func() -> void:
		if Bounties.buy_slot():
			Sfx.play("unlock", -6.0, 1.1)
			_refresh()
		else:
			Sfx.play("deny", -10.0))
	return _bounty_holder(card, unlock)


# --- Soul Shop -------------------------------------------------------------------------

var _shop_grid: HFlowContainer  # Cosmetics: emotes, idles, skins, fighters (top row).
var _shop_gear: HFlowContainer  # Gear (second row).
var _shop_reroll: Button
var _shop_restock: Label
var _shop_free_shown := false
const SHOP_FILTERS := {"All": [], "Emotes": ["emote"], "Gear": ["gear"], "Idles": ["idle"], "Skins": ["skin", "fighter"]}
var _shop_filter := "All"
var _shop_pills := {}
const SHOP_CARD := Vector2(188, 290)
const SHOP_BUY := 44.0


func _build_shop_page() -> Control:
	var panel := PanelContainer.new()
	# No big panel: the cards float over the camp (2026-11-05).
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 10.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	column.add_child(header)
	header.add_child(UiTheme.title_label("SOUL SHOP", 26, UiTheme.GOLD))
	_shop_reroll = Button.new()
	_shop_reroll.pressed.connect(func() -> void:
		if SoulShop.reroll():
			Sfx.play("coin", -4.0, 0.8)
			_refresh_shop()
		else:
			Sfx.play("deny", -10.0))
	header.add_child(_shop_reroll)
	# "New stock in: 19:42", counting down to the free refresh (2026-11-04).
	_shop_restock = _label("", 15, UiTheme.MUTED)
	_shop_restock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shop_restock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_shop_restock)
	header.move_child(_shop_restock, 1)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_tick_shop)
	panel.add_child(tick)
	# Filter pills: All, Emotes, Gear, Idles, Skins.
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 6)
	column.add_child(pills)
	_shop_pills.clear()
	for filter_name in SHOP_FILTERS:
		var pill := Button.new()
		pill.text = filter_name
		pill.toggle_mode = true
		pill.button_pressed = filter_name == _shop_filter
		pill.pressed.connect(func() -> void:
			_shop_filter = filter_name
			_refresh_shop())
		pills.add_child(pill)
		_shop_pills[filter_name] = pill
	# Cards wrap onto more rows when the screen's too narrow for them all.
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 12)
	scroll.add_child(rows)
	_shop_grid = HFlowContainer.new()
	_shop_gear = HFlowContainer.new()
	for flow in [_shop_grid, _shop_gear]:
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		rows.add_child(flow)
	return panel


func _refresh_shop() -> void:
	if _shop_grid == null:
		return
	for flow in [_shop_grid, _shop_gear]:
		for child in flow.get_children():
			flow.remove_child(child)
			child.queue_free()
	var offers := SoulShop.stock()
	var kinds: Array = SHOP_FILTERS[_shop_filter]
	for filter_name in _shop_pills:
		_shop_pills[filter_name].set_pressed_no_signal(filter_name == _shop_filter)
	for i in offers.size():
		if kinds.is_empty() or offers[i].kind in kinds:
			(_shop_gear if offers[i].kind == "gear" else _shop_grid).add_child(_shop_card(i, offers[i]))
	if _shop_grid.get_child_count() + _shop_gear.get_child_count() == 0:
		_shop_grid.add_child(_label("Nothing here today.", 16, UiTheme.MUTED))
	var free := SoulShop.free_refresh_ready()
	_shop_reroll.text = "Refresh  (free)" if free else "Refresh  (%d Souls)" % SoulShop.reroll_price()
	_shop_reroll.disabled = not free and GameState.souls < SoulShop.reroll_price()
	var old_badge := _shop_reroll.get_node_or_null("Free")
	if old_badge:
		old_badge.free()
	if free:
		var badge := _new_badge("!")
		badge.name = "Free"
		_shop_reroll.add_child(badge)
	_shop_free_shown = free
	_tick_shop()
	_chips.souls.set_amount(GameState.souls, true)


## Every second: the countdown to the free refresh, and its "!" on the
## button and the Shop tab once it's ready.
func _tick_shop() -> void:
	if _shop_restock == null:
		return
	var free := SoulShop.free_refresh_ready()
	if free:
		_shop_restock.text = "New stock ready!"
		_shop_restock.add_theme_color_override("font_color", UiTheme.GOLD)
	else:
		_shop_restock.text = "New stock in: %s" % SoulShop.time_text(SoulShop.free_refresh_left())
		_shop_restock.add_theme_color_override("font_color", UiTheme.MUTED)
	if _tab_buttons.has("Shop"):
		var flag := (_tab_buttons["Shop"] as Button).get_node_or_null("Flag")
		if free and flag == null:
			var badge := _new_badge("!")
			badge.name = "Flag"
			_tab_buttons["Shop"].add_child(badge)
		elif not free and flag != null:
			flag.free()
	if free != _shop_free_shown:
		_refresh_shop()


func _shop_card(index: int, offer: Dictionary) -> Control:
	if offer.kind == "gear":
		return _gear_shop_card(index, offer)
	var tint := UiTheme.SIGIL
	var title := ""
	var what := ""
	var lines := ""
	var icon_name := "star"
	match offer.kind:
		"emote":
			title = Emotes.name_of(offer.id)
			what = "EMOTE"
		"gear":
			var item: Dictionary = offer.item
			tint = Items.RARITIES[item.rarity].color
			title = item.name
			what = "%s  %s" % [String(item.rarity).to_upper(), String(item.slot).to_upper()]
			lines = GameState.effect_text(item.effects, 1)
			icon_name = {"gloves": "glove", "wraps": "wraps", "boots": "boot", "charm": "medal"}.get(item.slot, "chest")
		"idle":
			title = IdleAnims.name_of(offer.id)
			what = "HAND IDLE"
			lines = "What your hands do while you wait."
		"skin":
			title = Skins.name_of(offer.id)
			what = "SKIN  ·  %s" % GameState.fighter_name(Skins.CATALOG[offer.id].fighter).to_upper()
			lines = Skins.CATALOG[offer.id].desc
			tint = GameState.fighter_color(Skins.CATALOG[offer.id].fighter)
		"fighter":
			title = GameState.fighter_name(offer.id)
			what = "FIGHTER"
			icon_name = GameState.CLASSES[offer.id].icon
			tint = GameState.fighter_color(offer.id)
			lines = GameState.CLASSES[offer.id].tagline
	var card := PanelContainer.new()
	card.custom_minimum_size = SHOP_CARD - Vector2(0, SHOP_BUY)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(tint.darkened(0.8), 0.68), Color(tint, 0.8), 2, 10, 8.0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	# Emotes and hand idles: with the taller cards beside them, the preview and
	# its name sit centered between the card's top and the buy button.
	var centered: bool = offer.kind in ["emote", "idle", "skin", "gear", "fighter"]
	if centered:
		var top_gap := Control.new()
		top_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(top_gap)
	if offer.kind == "idle":
		var preview := IdlePreview.new()
		preview.idle_id = offer.id
		preview.custom_minimum_size = Vector2(160, 96)
		column.add_child(preview)
	elif offer.kind == "emote":
		var stage := EmotePreview.new(GameState.player_class, 5.0, "auto", 1.2)
		stage.emote_id = offer.id
		stage.custom_minimum_size = Vector2(160, 140)
		column.add_child(stage)
	elif offer.kind == "skin":
		var stage := EmotePreview.new(Skins.CATALOG[offer.id].fighter, 4.1, offer.id, 1.2)
		stage.emote_id = "default"
		stage.custom_minimum_size = Vector2(160, 140)
		column.add_child(stage)
	else:
		var icon := IconView.new()
		icon.icon = icon_name
		icon.color = tint.lightened(0.2)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var name_label := _label(title, 15, UiTheme.TEXT)
	name_label.add_theme_font_override("font", UiTheme.bold_font())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var kind_label := _label(what, 11, tint.lightened(0.2))
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kind_label)
	var detail := _label(lines, 12, UiTheme.GOOD if offer.kind == "gear" else UiTheme.MUTED)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if centered else Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	if centered:
		var bottom_gap := Control.new()
		bottom_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(bottom_gap)
	var buy := Button.new()
	buy.custom_minimum_size.y = 36
	if offer.sold:
		buy.text = "SOLD"
		buy.disabled = true
	elif GameState.souls < int(offer.price):
		buy.text = "%d Souls" % int(offer.price)
		buy.disabled = true
	else:
		buy.text = "Buy  ·  %d Souls" % int(offer.price)
		buy.theme_type_variation = "PrimaryButton"
	buy.pressed.connect(func() -> void:
		if SoulShop.buy(index):
			Sfx.play("unlock", -6.0, 1.2)
			if offer.kind == "gear":
				_refresh_armory()
			_refresh_shop())
	return _with_buy(card, buy)


## A shop card with its Buy button under it, outside the frame, all one size.
func _with_buy(card: Control, buy: Button) -> Control:
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = SHOP_CARD
	holder.add_theme_constant_override("separation", 6)
	holder.add_child(card)
	buy.custom_minimum_size.y = 38
	holder.add_child(buy)
	return holder


## A gear offer: the ItemCard's turning model and rarity effects (compact, so it
## matches the other offers' size) with the Buy button under it.
func _gear_shop_card(index: int, offer: Dictionary) -> Control:
	var item: Dictionary = offer.item
	var card := ItemCard.make(item, "SOLD" if offer.sold else "FOR SALE", GameState.equipped.get(item.slot, {}), true)
	card.min_height = SHOP_CARD.y - SHOP_BUY
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var buy := Button.new()
	buy.custom_minimum_size.y = 36
	if offer.sold:
		buy.text = "SOLD"
		buy.disabled = true
	elif GameState.souls < int(offer.price):
		buy.text = "%d Souls" % int(offer.price)
		buy.disabled = true
	else:
		buy.text = "Buy  ·  %d Souls" % int(offer.price)
		buy.theme_type_variation = "PrimaryButton"
	buy.pressed.connect(func() -> void:
		if SoulShop.buy(index):
			Sfx.play("unlock", -6.0, 1.2)
			_refresh_armory()
			_refresh_shop())
	return _with_buy(card, buy)


## Reroll: pick which stat to change, then see what it became.
func _pick_reroll(uid: int) -> void:
	var item := GameState.armory_item(uid)
	var stats := Items.rerollable(item)
	var buttons: Array = stats.map(func(effect: String) -> String: return GameState.effect_text({effect: item.effects[effect]}, 1))
	buttons.append("Cancel")
	var dialog := GameDialog.open(self, "REROLL A STAT", item.name, buttons)
	dialog.chosen.connect(func(index: int) -> void:
		if index >= stats.size():
			return
		var picked := GameState.reroll(uid, stats[index])
		if picked == "":
			return
		Sfx.play("unlock", -8.0, 1.4)
		var now := GameState.armory_item(uid)
		GameDialog.open(self, "REROLLED", GameState.effect_text({picked: now.effects[picked]}, 1), ["Nice"]))


func _label(text: String, font_size: int, color := UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
