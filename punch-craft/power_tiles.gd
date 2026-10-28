class_name PowerTiles
extends HBoxContainer
## The HUD's selected powers, bottom right: a tile each with the power's icon,
## glowing in its color while it can go off and dim while it recovers, with
## its countdown (or Gale's charges, Iron's plates as pips) underneath.
## Fed by PowerPlay.status(); `went_off` fires when a ready tile spends.

signal went_off(color: Color)

const TILE := Vector2(56, 56)
const PIP := Vector2(9, 9)

## root -> {glow, icon, style, name, value, pips, ready}
var _tiles := {}
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 12)


## status: [[root, readout, ready, [have, max] or []], ...]
func set_status(status: Array) -> void:
	var roots: Array = status.map(func(entry: Array) -> String: return entry[0])
	if roots != _tiles.keys():
		_rebuild(roots)
	for entry in status:
		_update(_tiles[entry[0]], entry)
	visible = not status.is_empty()


func _process(delta: float) -> void:
	_time += delta
	# Ready tiles breathe.
	var beat := 0.5 + 0.5 * sin(_time * 4.0)
	for root in _tiles:
		var tile: Dictionary = _tiles[root]
		var style: StyleBoxFlat = tile.style
		if tile.ready:
			style.shadow_size = int(8 + 6 * beat)
			style.shadow_color.a = 0.45 + 0.3 * beat


func _rebuild(roots: Array) -> void:
	for child in get_children():
		child.queue_free()
	_tiles.clear()
	for root in roots:
		var color: Color = SkillTreeView.BRANCHES[root].color
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 3)
		add_child(column)
		var glow := PanelContainer.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_corner_radius_all(16)
		style.shadow_color = Color(color, 0.6)
		glow.add_theme_stylebox_override("panel", style)
		column.add_child(glow)
		var icon := IconView.new()
		icon.icon = GameState.UPGRADES[root].icon
		icon.custom_minimum_size = TILE
		glow.add_child(icon)
		var name_label := _label(12, UiTheme.MUTED)
		name_label.text = String(SkillTreeView.BRANCHES[root].name).to_upper()
		column.add_child(name_label)
		var value := _label(15, UiTheme.TEXT)
		column.add_child(value)
		var pips := HBoxContainer.new()
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 4)
		column.add_child(pips)
		_tiles[root] = {"glow": glow, "icon": icon, "style": style, "value": value, "pips": pips, "ready": true, "color": color}


func _update(tile: Dictionary, entry: Array) -> void:
	var color: Color = tile.color
	var ready: bool = entry[2]
	if tile.ready and not ready:
		_pop(tile.glow)
		went_off.emit(color)
	tile.ready = ready
	var icon: IconView = tile.icon
	var style: StyleBoxFlat = tile.style
	icon.color = color if ready else color.darkened(0.45)
	icon.border_color = color.lightened(0.2) if ready else Color(1, 1, 1, 0.15)
	icon.tile_color = Color(color.darkened(0.7), 0.85) if ready else Color(0.05, 0.05, 0.07, 0.75)
	if not ready:
		style.shadow_size = 0
	var value: Label = tile.value
	value.text = entry[1]
	value.visible = entry[1] != ""
	value.add_theme_color_override("font_color", UiTheme.GOLD if entry[1] == "READY" else UiTheme.TEXT)
	var pips: HBoxContainer = tile.pips
	var counts: Array = entry[3]
	pips.visible = not counts.is_empty()
	if counts.is_empty():
		return
	while pips.get_child_count() < int(counts[1]):
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	while pips.get_child_count() > int(counts[1]):
		var extra := pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	for i in pips.get_child_count():
		(pips.get_child(i) as ColorRect).color = color.lightened(0.15) if i < int(counts[0]) else Color(1, 1, 1, 0.15)


func _pop(node: Control) -> void:
	node.pivot_offset = node.size / 2.0
	var pop := node.create_tween()
	pop.tween_property(node, "scale", Vector2.ONE * 1.25, 0.07)
	pop.tween_property(node, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
