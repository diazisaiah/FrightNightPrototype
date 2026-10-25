class_name CardTile
extends Button
## One level-up card (Cards): a rim in its rarity's color, its icon, name,
## rank pips and text. Face down it shows only its rarity. Used by the Deck
## page and the draw.
##   mode "owned": what it does at its rank now.
##   mode "offer": what taking it does (new, or the next rank).
##   mode "back": face down.

var fighter := ""
var card_id := ""
var mode := "owned"
var _inside: VBoxContainer


static func make(fighter_id: String, id: String, show: String, tile_size := Vector2(170, 236)) -> CardTile:
	var tile := CardTile.new()
	tile.fighter = fighter_id
	tile.card_id = id
	tile.mode = show
	tile.custom_minimum_size = tile_size
	tile.focus_mode = Control.FOCUS_NONE
	tile._build()
	return tile


func info() -> Dictionary:
	return Cards.info(fighter, card_id)


func _build() -> void:
	var card := info()
	var rarity: String = card.get("rarity", "common")
	var rim := Cards.rarity_color(rarity)
	var big := custom_minimum_size.x >= 210.0
	var face := Color(0.07, 0.06, 0.09, 0.97) if mode != "back" else Color(0.05, 0.045, 0.065, 0.97)
	add_theme_stylebox_override("normal", UiTheme.raised(face, Color(rim, 0.85 if mode != "back" else 0.45), 2 if mode != "back" else 1, 12))
	add_theme_stylebox_override("hover", UiTheme.raised(face.lightened(0.06), rim.lightened(0.25), 3, 12))
	add_theme_stylebox_override("pressed", UiTheme.raised(face.lightened(0.1), rim.lightened(0.35), 3, 12))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	clip_contents = true
	_inside = VBoxContainer.new()
	_inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_inside.set("offset_" + side, 10.0 if side == "left" else -10.0)
	_inside.offset_top = 10
	_inside.offset_bottom = -10
	_inside.add_theme_constant_override("separation", 6)
	_inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inside)
	var tag_line := _label(String(Items.RARITIES[rarity].name).to_upper() if Items.RARITIES.has(rarity) else rarity.to_upper(), 11, rim)
	tag_line.add_theme_font_override("font", UiTheme.bold_font())
	tag_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inside.add_child(tag_line)
	if mode == "back":
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_inside.add_child(spacer)
		var mark := UiTheme.title_label("?", 64 if big else 48, Color(rim, 0.55))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inside.add_child(mark)
		var spacer_2 := Control.new()
		spacer_2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_inside.add_child(spacer_2)
		return
	var tags: Array = card.get("tags", [])
	var tint: Color = Cards.TAG_COLORS.get(tags[0] if not tags.is_empty() else "", UiTheme.GOLD)
	var icon := IconView.new()
	icon.icon = card.get("icon", "star")
	icon.color = tint.lightened(0.15)
	icon.tile_color = tint.darkened(0.78)
	icon.border_color = Color(tint, 0.6)
	icon.custom_minimum_size = Vector2(64, 64) if big else Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_inside.add_child(icon)
	var name_label := UiTheme.title_label(String(card.get("name", card_id)).to_upper(), 20 if big else 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inside.add_child(name_label)
	var rank := GameState.card_rank(card_id) if fighter == GameState.player_class else 0
	var copies := Cards.copies(card)
	if copies > 1:
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 4)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lit := rank + (1 if mode == "offer" else 0)
		for i in copies:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(16, 6) if big else Vector2(12, 5)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var on := i < lit
			var fresh := mode == "offer" and i == lit - 1
			pip.add_theme_stylebox_override("panel", UiTheme.box(rim.lightened(0.35) if fresh else (rim if on else Color(0, 0, 0, 0.5)), Color(rim, 0.6), 1, 3))
			pips.add_child(pip)
		_inside.add_child(pips)
	var shown_rank := rank + 1 if mode == "offer" else maxi(rank, 1)
	var words := Cards.offer_text(card, rank) if mode == "offer" else Cards.text(card, shown_rank)
	# The long ones (most epics) go a size down on the small tiles.
	var body := _label(words, 13 if big else (10 if words.length() > 95 else 11), UiTheme.MUTED.lightened(0.15))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inside.add_child(body)
	var footer := ""
	if mode == "offer":
		footer = "NEW" if rank == 0 else "RANK %s" % Cards.roman(rank + 1)
	elif copies > 1:
		footer = "RANK %s" % Cards.roman(rank)
	if footer != "":
		var foot := _label(footer, 12, rim.lightened(0.2) if mode == "offer" and rank == 0 else UiTheme.GOLD)
		foot.add_theme_font_override("font", UiTheme.bold_font())
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_inside.add_child(foot)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
