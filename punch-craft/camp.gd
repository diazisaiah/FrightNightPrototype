extends Control
## Between-run camp: a header with your progress on the Climb and the run
## buttons, and four pages — Upgrades (the sealed coin web), Skills (skill
## point web), Armory (kept Crypt gear) and Stats (stat points and a sheet). The class is chosen on the title screen
## (Menu button). Built in code because it's generated from the data in GameState.

const PAGES := ["Upgrades", "Skills", "Armory", "Hats", "Stats"]
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
## Resource pills in the header: coins, souls, skill and stat points.
var _chips := {}
## The header amounts only animate after the first refresh.
var _shown_once := false
var _night_label: Label
var _tab_buttons := {}
var _pages := {}
var _trees := {}
var _details := {}
var _stat_rows := {}
var _sheet: GridContainer
var _stats_title: Label


func _ready() -> void:
	Sfx.play_music("camp")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.stop_ambience()
	theme = UiTheme.make()
	_build_ui()
	GameState.changed.connect(_refresh)
	_show_page("Upgrades")
	_refresh()
	if GameState.crypt_reveal_pending:
		await _play_crypt_reveal()
	if GameState.upgrade_notice != "":
		var notice := GameDialog.open(self, "A NEW CLIMB", GameState.upgrade_notice, ["Let's go"])
		GameState.upgrade_notice = ""
		GameState.save_game()
		notice.chosen.connect(func(_index: int) -> void: _camp_tips.call_deferred())
	else:
		_camp_tips()


## Camp's mini tutorials (Tutorial), each once: after your first hat, the
## Hat Rack.
func _camp_tips() -> void:
	if not is_inside_tree() or not Tutorial.seen("hat_first") or GameState.hats.is_empty():
		return
	var first := Tutorial.open(self, "hat_rack", "YOUR FIRST HAT!", "Every hat you take ends up on your Hat Rack. Open it here.",
			_tab_buttons["Hats"], func() -> bool: return _pages["Hats"].visible, false)
	if first == null:
		return
	first.finished.connect(func() -> void:
		Tutorial.open(self, "hat_rack_tour", "THE HAT RACK",
				"Every hat gives a small boost that's yours for good, worn or not, so collect them all!\n\nClick a hat to wear it, and hold %s in a fight to emote and show it off." % Controls.key_name("emote"),
				_hat_grid, Callable(), false, true))


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
	var line := UiTheme.title_label("The Bellman's last toll cracked the graveyard open. What you find down there, you keep.", 22, UiTheme.TEXT)
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
	column.add_child(_build_header())
	column.add_child(_build_tabs())

	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(page_area)
	_add_page(page_area, "Upgrades", _build_tree_page("upgrade"))
	_add_page(page_area, "Skills", _build_tree_page("skill"))
	_add_page(page_area, "Armory", _build_armory_page())
	_add_page(page_area, "Hats", _build_hat_rack())
	_add_page(page_area, "Stats", _build_stats_page())


# --- Header ------------------------------------------------------------------

func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.raised(Color(UiTheme.PANEL, 0.88), Color(UiTheme.GOLD, 0.25), 1, 10, 12.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(UiTheme.title_label("FRIGHT NIGHT", 30, UiTheme.BLOOD.lightened(0.15)))
	titles.add_child(_label("Camp", 14, UiTheme.MUTED))
	row.add_child(titles)

	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 3)
	progress.custom_minimum_size.x = 240
	_level_label = _label("", 16)
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
		"skill_points": "Skill points",
		"stat_points": "Stat points",
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

	return panel


func _build_tabs() -> Control:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for page in PAGES:
		var button := Button.new()
		button.text = page
		button.toggle_mode = true
		button.button_group = group
		button.theme_type_variation = "TabButton"
		button.pressed.connect(_show_page.bind(page))
		tabs.add_child(button)
		_tab_buttons[page] = button
	# Run buttons on the right of the tab row: training, and the two kinds of
	# run (the graveyard's nights, or the Crypt's floors of rooms).
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	var menu := Button.new()
	menu.text = "Menu"
	menu.tooltip_text = "Title screen: change class, settings"
	menu.pressed.connect(func() -> void:
		GameState.save_game()
		Loading.go("res://title.tscn"))
	tabs.add_child(menu)
	var training := Button.new()
	training.text = "Training" if GameState.tutorial_done else "Tutorial"
	training.pressed.connect(_start_training)
	tabs.add_child(training)
	# Daily drills: score runs that pay once a day.
	var daily := Button.new()
	daily.text = "Daily"
	daily.tooltip_text = "Pad Work, Slip Line and Heavy Bags: score runs that pay coins and XP once a day."
	daily.pressed.connect(_pick_drill)
	tabs.add_child(daily)
	if DRILLS.any(func(id: String) -> bool: return GameState.drill_ready(id)):
		daily.add_child(_new_badge("READY"))
	var league := Button.new()
	league.text = "Dead League"
	league.tooltip_text = "1v1 bouts against the contenders. Each first win breaks a seal on your upgrade web."
	league.custom_minimum_size = Vector2(125, 40)
	league.add_theme_color_override("font_color", UiTheme.GOLD)
	league.pressed.connect(_start_dead_league)
	tabs.add_child(league)
	for mode in [["Arena", _pick_division], ["Crypt", _pick_crypt_floors]]:
		var start := Button.new()
		start.text = mode[0]
		start.theme_type_variation = "PrimaryButton"
		start.custom_minimum_size = Vector2(140, 40)
		start.add_theme_font_size_override("font_size", 19)
		start.pressed.connect(mode[1])
		tabs.add_child(start)
		# Locked things stay hidden: the Crypt appears with the Bellman's seal,
		# wearing a NEW badge until the first descent.
		if mode[0] == "Crypt":
			_crypt_button = start
			start.visible = GameState.crypt_unlocked
			if GameState.crypt_new:
				start.add_child(_new_badge())
	return tabs


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


func _add_page(area: Control, page_name: String, page: Control) -> void:
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(page)
	_pages[page_name] = page


func _show_page(page_name: String) -> void:
	for page in _pages:
		_pages[page].visible = page == page_name
		_tab_buttons[page].set_pressed_no_signal(page == page_name)


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
	var id := tree.selected_id
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
			_chips["coins" if kind == "upgrade" else "skill_points"].deny()


## The first power bought: a pointer at Select until it's picked.
func _power_tip(kind: String) -> void:
	var buy: Button = _details[kind].buy
	var power_name: String = _trees[kind].branch_name(_trees[kind].selected_id).capitalize()
	Tutorial.open(self, "power_select", "YOU UNLOCKED A POWER!",
			"Powers are big upgrades you make stronger as you climb. You can only have one selected at a time, so pick the one you want working.\n\nSelect %s here." % power_name,
			buy, func() -> bool: return GameState.power_pick != "", false, true)


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
	var cost_text := "%d {%s}" % [cost, "coins" if kind == "upgrade" else "skill_points"]
	var can_pay := have >= cost and holder == ""
	detail.cost.color = UiTheme.TEXT if can_pay else UiTheme.BAD.lightened(0.1)
	detail.cost.text = cost_text

	var buy: Button = detail.buy
	if kind == "upgrade" and SkillTreeView.BRANCHES.has(id) and level > 0:
		# Owned powers: pick the one that works.
		var picked := GameState.power_pick == id
		buy.text = "Selected" if picked else "Select"
		buy.disabled = picked
		detail.cost_row.visible = false
		return
	if maxed:
		buy.text = "Maxed"
		buy.disabled = true
	elif holder != "":
		buy.text = "Sealed - beat %s" % holder.capitalize()
		buy.disabled = true
	elif have < cost:
		buy.text = "Need %d more" % (cost - have)
		buy.disabled = true
	else:
		var verb := "Buy" if kind == "upgrade" else "Learn"
		buy.text = verb if node.max_level == 1 else "%s level %d" % [verb, level + 1]
		buy.disabled = false


# --- Stats ----------------------------------------------------------------------

func _build_stats_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	left.add_child(list)
	_stats_title = UiTheme.title_label("STATS", 26, UiTheme.GOLD)
	list.add_child(_stats_title)
	for stat in GameState.STATS:
		var info: Dictionary = GameState.STATS[stat]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL_LIGHT, UiTheme.BORDER, 1, 10, 12.0))
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 14)
		card.add_child(stat_row)
		var icon := IconView.new()
		icon.icon = info.icon
		icon.custom_minimum_size = Vector2(48, 48)
		stat_row.add_child(icon)
		var texts := VBoxContainer.new()
		texts.alignment = BoxContainer.ALIGNMENT_CENTER
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_child(_label(info.name, 18))
		texts.add_child(_label(info.desc, 13, UiTheme.MUTED))
		stat_row.add_child(texts)
		var value := _label("0", 26, UiTheme.GOLD)
		value.custom_minimum_size.x = 50
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat_row.add_child(value)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(48, 48)
		plus.add_theme_font_size_override("font_size", 22)
		plus.pressed.connect(GameState.spend_stat_point.bind(stat))
		stat_row.add_child(plus)
		list.add_child(card)
		_stat_rows[stat] = {"value": value, "plus": plus}

	var right := PanelContainer.new()
	right.custom_minimum_size.x = DETAIL_WIDTH
	row.add_child(right)
	var sheet_box := VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 10)
	right.add_child(sheet_box)
	sheet_box.add_child(UiTheme.title_label("YOUR FIGHTER", 26, UiTheme.GOLD))
	_sheet = GridContainer.new()
	_sheet.columns = 2
	_sheet.add_theme_constant_override("h_separation", 16)
	_sheet.add_theme_constant_override("v_separation", 6)
	sheet_box.add_child(_sheet)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_box.add_child(spacer)
	return row


func _refresh_sheet() -> void:
	for child in _sheet.get_children():
		child.queue_free()
	var damage := GameState.get_damage()
	var lines := [
		["Fighter", "%s  (%s)" % [GameState.fighter_name(), GameState.CLASSES[GameState.player_class].name]],
		["Jab damage", "%.1f  (head %.1f)" % [damage, damage * (Enemy.HEAD_MULTIPLIER + GameState.get_effect("head_bonus"))]],
		["Max knuckle HP", "%d" % roundi(GameState.get_max_knuckles())],
		["Punch cost", "Jab/cross 1, hook 2, uppercut 3"],
		["Damage taken", "%d%%" % roundi(GameState.get_knuckle_loss_multiplier() * 100.0)],
		["Punch speed", "x%.2f" % GameState.get_punch_speed()],
		["Combo growth", "+%.2f per hit" % GameState.get_combo_step()],
		["Combo time", "%.1fs" % GameState.get_combo_window()],
		["Counter", "x%.2f" % GameState.get_counter_multiplier(Player.COUNTER_MULTIPLIER)],
		["Dodge windows", "x%.2f" % GameState.get_dodge_window_multiplier()],
		["Armor ignored", "%d%%" % roundi(GameState.get_armor_pierce() * 100.0)],
		["Coins", "x%.2f" % GameState.get_coin_multiplier()],
	]
	for line in lines:
		_sheet.add_child(_label(line[0], 14, UiTheme.MUTED))
		_sheet.add_child(_label(line[1], 14))


# --- Class ------------------------------------------------------------------------

# --- Refresh & navigation --------------------------------------------------------

func _refresh() -> void:
	var class_name_text: String = GameState.fighter_name()
	_level_label.text = "Level %d   ·   %s" % [GameState.level, class_name_text]
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	_xp_label.text = "%d / %d XP" % [GameState.xp, GameState.xp_to_next()]
	_chips.coins.set_amount(GameState.resources.get("coins", 0), _shown_once)
	_chips.souls.set_amount(GameState.souls, _shown_once)
	_chips.skill_points.set_amount(GameState.skill_points, _shown_once)
	_chips.stat_points.set_amount(GameState.stat_points, _shown_once)
	_shown_once = true
	# Your POWER: every stat, upgrade, skill and item in one number.
	_night_label.text = "POWER  %d" % PowerRating.player()
	_night_label.add_theme_color_override("font_color", UiTheme.GOLD)
	_refresh_armory()
	_refresh_hat_rack()

	for kind in _trees:
		var tree: SkillTreeView = _trees[kind]
		# Switching class hides the old class column; move the selection off it.
		tree.refresh()  # Rebuilds the skill web if the class changed.
		if not GameState.tree(kind).has(tree.selected_id) or GameState.node_state(kind, tree.selected_id) == "hidden":
			tree.selected_id = GameState.tree(kind).keys()[0]
			tree.refresh()
		_refresh_detail(kind)
	_tab_buttons["Skills"].text = "Skills  (%d)" % GameState.skill_points if GameState.skill_points > 0 else "Skills"
	_tab_buttons["Stats"].text = "Stats  (%d)" % GameState.stat_points if GameState.stat_points > 0 else "Stats"

	_stats_title.text = "STATS  ·  %d TO SPEND" % GameState.stat_points if GameState.stat_points > 0 else "STATS"
	for stat in _stat_rows:
		_stat_rows[stat].value.text = "%d" % GameState.stats[stat]
		_stat_rows[stat].plus.disabled = GameState.stat_points <= 0
	_refresh_sheet()


## Arena: pick a division (each opens with the seal before it).
func _pick_division() -> void:
	var options := []
	for i in Progression.TIER_COUNT:
		var bouts := mini(int(GameState.arena_bouts.get(str(i + 1), 0)), Progression.BOUTS_PER_DIVISION)
		options.append({"name": Progression.TIERS[i].division.to_upper(), "pips": [bouts, Progression.BOUTS_PER_DIVISION],
			"open": i + 1 <= Progression.current_tier(), "tier": i + 1, "value": i + 1})
	_pick("UNDERWORLD ARENA", options, func(division: int) -> void:
		GameState.arena_division = division
		_pick_bout(division))


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
		options.append({"name": "BOUT %d" % bout, "number": "%d" % bout, "tier": division, "open": true, "value": bout,
			"detail": ("WON" if bout <= won else "NEXT") + "   ·   x%s pay" % String.num(Progression.pay(Progression.arena_position(division, bout)) / base, 2)})
	_pick("%s DIVISION" % Progression.TIERS[division - 1].division.to_upper(), options, func(bout: int) -> void:
		GameState.arena_bout_pick = bout
		_start_run())


## Crypt: pick a pair of floors to start on (one pair per tier you've reached).
func _pick_crypt_floors() -> void:
	var options := []
	for i in Progression.TIER_COUNT:
		var first := Progression.crypt_start_floor(i + 1)
		options.append({"name": "FLOORS %d-%d" % [first, first + 1], "open": i + 1 <= Progression.current_tier(), "tier": i + 1, "value": i + 1})
	_pick("THE CRYPT", options, func(tier: int) -> void:
		GameState.crypt_tier = tier
		_start_crypt())


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
		var card_size: Vector2 = option.get("card_size", Vector2(200, 230))
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
	GameState.save_game()
	Loading.go("res://dead_league_menu.tscn")


# --- Armory -------------------------------------------------------------------------

var _armory_worn: VBoxContainer
var _armory_list: VBoxContainer
var _armory_title: Label


func _build_armory_page() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var worn_panel := PanelContainer.new()
	worn_panel.custom_minimum_size.x = 420
	row.add_child(worn_panel)
	var worn_box := VBoxContainer.new()
	worn_box.add_theme_constant_override("separation", 8)
	worn_panel.add_child(worn_box)
	worn_box.add_child(UiTheme.title_label("WORN", 24, UiTheme.GOLD))
	_armory_worn = VBoxContainer.new()
	_armory_worn.add_theme_constant_override("separation", 6)
	worn_box.add_child(_armory_worn)

	var kept_panel := PanelContainer.new()
	kept_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kept_panel)
	var kept_box := VBoxContainer.new()
	kept_box.add_theme_constant_override("separation", 8)
	kept_panel.add_child(kept_box)
	_armory_title = UiTheme.title_label("KEPT GEAR", 24, UiTheme.GOLD)
	kept_box.add_child(_armory_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kept_box.add_child(scroll)
	_armory_list = VBoxContainer.new()
	_armory_list.add_theme_constant_override("separation", 8)
	_armory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_armory_list)
	return row


func _refresh_armory() -> void:
	if _armory_list == null:
		return
	for child in _armory_worn.get_children() + _armory_list.get_children():
		child.queue_free()
	for slot in Items.SLOTS:
		var item: Dictionary = GameState.equipped.get(slot, {})
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var icon := IconView.new()
		icon.icon = Items.SLOT_ICONS[slot]
		icon.custom_minimum_size = Vector2(40, 40)
		icon.color = Items.rarity_color(item) if not item.is_empty() else UiTheme.MUTED
		line.add_child(icon)
		var text := _label(("%s:  %s" % [Items.SLOT_NAMES[slot], item.name]) if not item.is_empty() else "%s:  (empty)" % Items.SLOT_NAMES[slot], 15,
				Items.rarity_color(item) if not item.is_empty() else UiTheme.MUTED)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(text)
		if not item.is_empty():
			var off := Button.new()
			off.text = "Take off"
			off.pressed.connect(GameState.unequip.bind(slot))
			line.add_child(off)
		_armory_worn.add_child(line)
	_armory_title.text = "KEPT GEAR  (%d)" % GameState.armory.size()
	if GameState.armory.is_empty():
		_armory_list.add_child(_label("Nothing kept yet.", 15, UiTheme.MUTED))
	for item in GameState.armory:
		_armory_list.add_child(_armory_card(item))


func _armory_card(item: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.06, 0.055, 0.08, 0.92), Items.rarity_color(item).darkened(0.2), 1, 8, 10.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var worn: bool = GameState.equipped.get(item.slot, {}).get("uid", -1) == item.get("uid", -2)
	var forged := int(item.get("reforged", 0))
	texts.add_child(_label("%s%s%s" % [item.name, "  +%d" % forged if forged > 0 else "", "   (worn)" if worn else ""], 17, Items.rarity_color(item)))
	texts.add_child(_label("%s  ·  floor %d" % [Items.kind_text(item), int(item.get("floor", 1))], 12, UiTheme.MUTED))
	var effects := _label("   ".join(Items.effect_lines(item)), 13)
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(effects)
	row.add_child(texts)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	var uid := int(item.uid)
	var wear := Button.new()
	wear.text = "Worn" if worn else "Wear"
	wear.custom_minimum_size = Vector2(170, 36)
	wear.disabled = worn
	wear.pressed.connect(GameState.equip_from_armory.bind(uid))
	buttons.add_child(wear)
	var cost := Progression.reforge_cost(item)
	var forge := Button.new()
	forge.disabled = GameState.souls < cost
	forge.custom_minimum_size = Vector2(170, 36)
	IconLabel.on_button(forge, "Reforge  %d {souls}" % cost, 15)
	forge.pressed.connect(func() -> void:
		if GameState.reforge(uid):
			Sfx.play("unlock", -8.0, 1.2))
	buttons.add_child(forge)
	var reroll_cost := Progression.reroll_cost(item)
	var reroll := Button.new()
	reroll.custom_minimum_size = Vector2(170, 36)
	reroll.disabled = GameState.souls < reroll_cost or Items.rerollable(item).is_empty()
	IconLabel.on_button(reroll, "Reroll  %d {souls}" % reroll_cost, 15)
	reroll.pressed.connect(_pick_reroll.bind(uid))
	buttons.add_child(reroll)
	var value := roundi(DUNGEON.SALVAGE_COINS.get(item.rarity, 10) * Progression.pay(int(item.get("floor", 1)) / 2.0))
	var scrap := Button.new()
	scrap.custom_minimum_size = Vector2(170, 36)
	IconLabel.on_button(scrap, "Salvage  +%d {coins}" % value, 15)
	scrap.pressed.connect(GameState.salvage.bind(uid, value))
	buttons.add_child(scrap)
	return card


# --- Hat Rack ----------------------------------------------------------------------

var _hat_title: Label
var _hat_yonkers: Label
var _hat_grid: GridContainer


## Every hat on a peg: owned ones in color with their boost, missing ones as
## silhouettes.
func _build_hat_rack() -> Control:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_hat_title = UiTheme.title_label("HAT RACK", 26, UiTheme.GOLD)
	_hat_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_hat_title)
	_hat_yonkers = UiTheme.title_label("", 22, Items.RARITIES.legendary.color)
	header.add_child(_hat_yonkers)
	var tip := _label("Click a hat to wear it. Hold %s in a fight to emote and see it." % Controls.key_name("emote"), 13, UiTheme.MUTED)
	column.add_child(tip)
	Controls.watch(tip, func() -> void:
		tip.text = "Click a hat to wear it. Hold %s in a fight to emote and see it." % Controls.key_name("emote"))
	var scroll := ScrollContainer.new()
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
	for id in Hats.CATALOG:
		if GameState.hats.has(id):
			owned += 1
		_hat_grid.add_child(_hat_card(id))
	_hat_title.text = "HAT RACK   %d / %d" % [owned, Hats.CATALOG.size()]
	var yonkers := Hats.LEGENDARIES.filter(func(id: String) -> bool: return GameState.hats.has(id)).size()
	_hat_yonkers.text = "YONKERS  %d / 4" % yonkers
	_hat_yonkers.visible = yonkers > 0


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
		var boost := _label("Does nothing. Yet." if info.rarity == "legendary" else Hats.boost_text(id), 11, tint.lightened(0.3) if info.rarity == "legendary" else UiTheme.GOOD)
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
