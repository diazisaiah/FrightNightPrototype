class_name CardDraw
extends CanvasLayer
## The level-up draw: three cards from the fighter's deck flip face up and you
## keep one, then the next draw if more are waiting. Reroll (Souls) or come
## back later.

signal closed

const FLIP_TIME := 0.18
const FLIP_GAP := 0.12
const TILE := Vector2(236, 330)

var _row: HBoxContainer
var _sub: Label
var _reroll: Button
var _busy := false


static func open(parent: Node) -> CardDraw:
	var draw := CardDraw.new()
	draw.layer = 60
	parent.add_child(draw)
	return draw


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)
	var heading := UiTheme.heading("LEVEL UP  ·  PICK A CARD", 40)
	column.add_child(heading)
	_sub = UiTheme.title_label("", 18, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 22)
	_row.custom_minimum_size.y = TILE.y
	column.add_child(_row)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(200, 44)
	_reroll.tooltip_text = "Three new cards. Costs one more each time on the same draw."
	_reroll.pressed.connect(_do_reroll)
	buttons.add_child(_reroll)
	var later := Button.new()
	later.text = "Later"
	later.custom_minimum_size = Vector2(140, 44)
	later.pressed.connect(_close)
	buttons.add_child(later)
	_deal()


## Lays out the offer face down, then flips the cards one by one.
func _deal() -> void:
	var offer := GameState.card_offer()
	if offer.is_empty():
		if GameState.draws <= 0:
			_close.call_deferred()
			return
		# Nothing left to draw (the rest is behind seals): the draws wait.
		_sub.text = "Every card in your deck is yours. Break another seal for more."
		_reroll.visible = false
		return
	_busy = true
	for child in _row.get_children():
		child.queue_free()
	var waiting := GameState.usable_draws()
	_sub.text = "%s  ·  %d draw%s waiting" % [GameState.fighter_name(), waiting, "" if waiting == 1 else "s"]
	_refresh_reroll()
	var holders := []
	for id in offer:
		# Each card sits in a fixed-size holder so flipping (scale) doesn't shift the row.
		var holder := Control.new()
		holder.custom_minimum_size = TILE
		_row.add_child(holder)
		var back := CardTile.make(GameState.player_class, id, "back", TILE)
		back.disabled = true
		holder.add_child(back)
		back.pivot_offset = TILE / 2.0
		holders.append([holder, back, id])
	Sfx.play("whoosh", -6.0, 0.8)
	for entry in holders:
		await get_tree().create_timer(FLIP_GAP).timeout
		if not is_inside_tree():
			return
		await _flip(entry[0], entry[1], entry[2])
	_busy = false


func _flip(holder: Control, back: CardTile, id: String) -> void:
	var shrink := back.create_tween()
	shrink.tween_property(back, "scale:x", 0.0, FLIP_TIME / 2.0).set_trans(Tween.TRANS_SINE)
	await shrink.finished
	back.queue_free()
	var face := CardTile.make(GameState.player_class, id, "offer", TILE)
	face.pivot_offset = TILE / 2.0
	face.scale.x = 0.0
	holder.add_child(face)
	face.pressed.connect(_take.bind(id, face))
	Sfx.play("tell", -8.0, 1.5 + randf() * 0.2)
	var grow := face.create_tween()
	grow.tween_property(face, "scale:x", 1.0, FLIP_TIME / 2.0).set_trans(Tween.TRANS_SINE)
	await grow.finished


func _take(id: String, face: CardTile) -> void:
	if _busy or not GameState.take_card(id):
		return
	_busy = true
	Sfx.play("unlock", -4.0, 1.2)
	for holder in _row.get_children():
		var tile := holder.get_child(holder.get_child_count() - 1) as Control
		if tile == null:
			continue
		var tween := tile.create_tween()
		if tile == face:
			tween.tween_property(tile, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "modulate", Color(1.4, 1.3, 1.0), 0.15)
		else:
			tween.tween_property(tile, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	if GameState.draws > 0 and not GameState.card_offer().is_empty():
		_deal()
	else:
		_close()


func _do_reroll() -> void:
	if _busy:
		return
	if GameState.reroll_offer():
		Sfx.play("coin", -6.0, 0.8)
		_deal()


func _refresh_reroll() -> void:
	var cost := GameState.reroll_cost()
	_reroll.text = "Reroll  ·  %d Soul%s" % [cost, "" if cost == 1 else "s"]
	_reroll.disabled = GameState.souls < cost


func _close() -> void:
	closed.emit()
	queue_free()
