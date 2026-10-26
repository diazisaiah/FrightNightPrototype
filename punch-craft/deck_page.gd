class_name DeckPage
extends HBoxContainer
## Camp's Deck page: the fighter's cards (Cards), drawn ones face up with their
## ranks and the rest face down by rarity. Legendaries still behind a seal
## stay hidden. Draw, swap a card, or redraft the lot (Souls).

signal draw_requested

var _title: Label
var _count: Label
var _draw: Button
var _redraft: Button
var _grid: HFlowContainer
var _selected := ""
var _detail := {}


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.02, 0.02, 0.04, 0.55), Color(UiTheme.GOLD, 0.18), 1, 10, 12.0))
	add_child(left)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	left.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -2)
	_title = UiTheme.title_label("DECK", 26, UiTheme.GOLD)
	titles.add_child(_title)
	_count = _label("", 13, UiTheme.MUTED)
	titles.add_child(_count)
	top.add_child(titles)
	_redraft = Button.new()
	_redraft.tooltip_text = "Every card back in the deck, a draw for each."
	_redraft.pressed.connect(_ask_redraft)
	top.add_child(_redraft)
	_draw = Button.new()
	_draw.theme_type_variation = "PrimaryButton"
	_draw.custom_minimum_size = Vector2(150, 44)
	_draw.add_theme_font_size_override("font_size", 18)
	_draw.pressed.connect(func() -> void: draw_requested.emit())
	top.add_child(_draw)
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	add_child(_build_detail())
	GameState.changed.connect(refresh)
	refresh()


func _build_detail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var rarity := _label("", 12, UiTheme.MUTED)
	rarity.add_theme_font_override("font", UiTheme.bold_font())
	box.add_child(rarity)
	var name_label := UiTheme.title_label("", 26)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var rank := _label("", 14, UiTheme.GOLD)
	box.add_child(rank)
	box.add_child(HSeparator.new())
	box.add_child(_label("NOW", 12, UiTheme.MUTED))
	var now := _label("", 16)
	now.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(now)
	var next_title := _label("NEXT RANK", 12, UiTheme.MUTED)
	box.add_child(next_title)
	var next := _label("", 16, UiTheme.GOOD)
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(next)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var swap := Button.new()
	swap.custom_minimum_size.y = 44
	swap.tooltip_text = "Give back one rank of this card for a fresh draw."
	swap.pressed.connect(_swap)
	box.add_child(swap)
	_detail = {"rarity": rarity, "name": name_label, "rank": rank, "now": now, "next_title": next_title, "next": next, "swap": swap}
	return panel


func refresh() -> void:
	if not is_inside_tree():
		return
	var fighter := GameState.player_class
	var deck := Cards.deck(fighter)
	var draws := GameState.usable_draws()
	_title.text = "DECK  ·  %s" % GameState.fighter_name().to_upper()
	var shown := 0
	for id in deck:
		if Cards.available(deck[id], GameState.card_seals()):
			shown += Cards.copies(deck[id])
	_count.text = "%d of %d cards drawn" % [GameState.cards_kept(), shown]
	_draw.text = "DRAW  (%d)" % draws if draws > 0 else "DRAW"
	_draw.disabled = draws <= 0
	_redraft.text = "Redraft  ·  %d Souls" % GameState.REDRAFT_SOULS
	_redraft.disabled = GameState.cards_kept() == 0 or GameState.souls < GameState.REDRAFT_SOULS
	for child in _grid.get_children():
		child.queue_free()
	# Drawn first, by rarity (rarest first), then the rest face down.
	var ids: Array = deck.keys().filter(func(id: String) -> bool:
		return GameState.card_rank(id) > 0 or Cards.available(deck[id], GameState.card_seals()))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var owned_a := GameState.card_rank(a) > 0
		var owned_b := GameState.card_rank(b) > 0
		if owned_a != owned_b:
			return owned_a
		return Cards.RARITY_ORDER.find(deck[a].rarity) > Cards.RARITY_ORDER.find(deck[b].rarity))
	if _selected == "" or not _selected in ids:
		_selected = ids[0] if not ids.is_empty() else ""
	for id in ids:
		var owned := GameState.card_rank(id) > 0
		var tile := CardTile.make(fighter, id, "owned" if owned else "back")
		tile.pressed.connect(func() -> void:
			_selected = id
			_refresh_detail())
		_grid.add_child(tile)
	_refresh_detail()


func _refresh_detail() -> void:
	var card := Cards.info(GameState.player_class, _selected)
	if card.is_empty():
		return
	var rank := GameState.card_rank(_selected)
	var copies := Cards.copies(card)
	var rim := Cards.rarity_color(card.rarity)
	_detail.rarity.text = "%s  ·  %s" % [String(card.rarity).to_upper(), "  ·  ".join(card.get("tags", [])).to_upper()]
	_detail.rarity.add_theme_color_override("font_color", rim)
	var swap: Button = _detail.swap
	if rank <= 0:
		_detail.name.text = "FACE DOWN"
		_detail.rank.text = "Not drawn yet"
		_detail.now.text = "A %s card still in the deck." % String(card.rarity)
		_detail.next_title.visible = false
		_detail.next.visible = false
		swap.visible = false
		return
	_detail.name.text = String(card.name).to_upper()
	_detail.rank.text = "Rank %s of %s" % [Cards.roman(rank), Cards.roman(copies)] if copies > 1 else "Owned"
	_detail.now.text = Cards.text(card, rank)
	var more := rank < copies
	_detail.next_title.visible = more
	_detail.next.visible = more
	if more:
		_detail.next.text = Cards.text(card, rank + 1)
	swap.visible = true
	var cost := GameState.swap_cost(_selected)
	swap.text = "Swap  ·  %d Souls" % cost
	var waiting := GameState.usable_draws() > 0
	swap.disabled = GameState.souls < cost or waiting
	swap.tooltip_text = "Draw your waiting cards first." if waiting else "Give back one rank of this card for a fresh draw."


func _swap() -> void:
	if GameState.swap_card(_selected):
		Sfx.play("unlock", -6.0, 1.2)
		draw_requested.emit()


func _ask_redraft() -> void:
	var dialog := GameDialog.open(self, "REDRAFT?", "Every card goes back in the deck, and you draw again, one card for each you had.", ["Redraft  ·  %d Souls" % GameState.REDRAFT_SOULS, "Keep my cards"])
	dialog.chosen.connect(func(index: int) -> void:
		if index == 0 and GameState.redraft():
			Sfx.play("unlock", -6.0, 0.9)
			draw_requested.emit())


func _label(text: String, font_size: int, color := UiTheme.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
