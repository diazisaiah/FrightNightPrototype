class_name PlayPicker
extends Control
## Where you pick an Arena or a Crypt floor (2026-11-05). The mode's card on
## Home slides across to the left while the side rail fades away, and the
## room it leaves fills with a card per unlocked place (a zoomed-out shot of
## the arena, its division, what the bout asks and how you stack up). Pick
## one and the cards become its bouts. Back steps out the same way.
##
## Levels are dictionaries: {heading, sub, options, pick}. An option is
## {name, place, art, tint, accent, number, detail, lines, pips, value}; pick
## is called with the value and returns the next level ({} when it started a
## scene).

signal closed

const SLIDE := 0.4
const CARD := Vector2(232, 318)
const ART_HEIGHT := 156.0

var _camp: Control
var _rail: Control
var _home: Control
var _source: Control

var _mode_card: Control
var _back: Button
var _content: VBoxContainer
var _levels: Array = []
var _closing := false
var _slide: Tween


## Opens the picker over body (the rail and the page area). level is the first
## page; source is the Home card that slides left.
static func open(camp: Control, body: Control, rail: Control, home: Control, source: Control,
		mode_title: String, mode_line: String, picture: Texture2D, level: Dictionary) -> PlayPicker:
	var picker := PlayPicker.new()
	picker._camp = camp
	picker._rail = rail
	picker._home = home
	picker._source = source
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	camp.add_child(picker)
	picker._place_over(body)
	picker._build(mode_title, mode_line, picture)
	picker._push(level, false)
	picker._animate_in()
	return picker


func _place_over(body: Control) -> void:
	var rect := body.get_global_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	global_position = rect.position
	size = rect.size
	body.resized.connect(func() -> void:
		if is_instance_valid(self):
			var now := body.get_global_rect()
			global_position = now.position
			size = now.size
			_layout())


func _left_width() -> float:
	return clampf(size.x * 0.27, 230.0, 300.0)


func _build(mode_title: String, mode_line: String, picture: Texture2D) -> void:
	_mode_card = Panel.new()
	_mode_card.clip_contents = true
	_mode_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_card.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.04, 0.035, 0.05, 0.95), Color(UiTheme.GOLD, 0.7), 2, 12))
	add_child(_mode_card)
	var art := TextureRect.new()
	art.texture = picture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_card.add_child(art)
	var fade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.025, 0.04, 0.05))
	gradient.add_point(0.5, Color(0.03, 0.025, 0.04, 0.5))
	gradient.set_color(gradient.get_point_count() - 1, Color(0.03, 0.025, 0.04, 0.96))
	var fade_texture := GradientTexture2D.new()
	fade_texture.gradient = gradient
	fade_texture.fill_from = Vector2(0, 0)
	fade_texture.fill_to = Vector2(0, 1)
	fade.texture = fade_texture
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mode_card.add_child(fade)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 16
	text.offset_right = -14
	text.offset_bottom = -16
	text.alignment = BoxContainer.ALIGNMENT_END
	text.add_theme_constant_override("separation", 4)
	_mode_card.add_child(text)
	var title := UiTheme.title_label(mode_title, 34, UiTheme.TEXT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(title)
	var line := Label.new()
	line.text = mode_line
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color(0.86, 0.82, 0.9))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(line)

	_back = Button.new()
	_back.text = "Back"
	_back.focus_mode = Control.FOCUS_NONE
	_back.pressed.connect(back)
	add_child(_back)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	resized.connect(_layout)


## The finished spots: the mode card and Back down the left, the cards to the
## right.
func _target_card() -> Rect2:
	return Rect2(0, 0, _left_width(), minf(236.0, maxf(size.y - 54.0, 120.0)))


func _layout() -> void:
	if _closing:
		return
	if _slide == null or not _slide.is_running():
		var rect := _target_card()
		_mode_card.position = rect.position
		_mode_card.size = rect.size
	_back.position = Vector2(0, _target_card().size.y + 10.0)
	_back.size = Vector2(_left_width(), 44.0)
	var x := _left_width() + 20.0
	_content.position = Vector2(x, 0)
	_content.size = Vector2(maxf(size.x - x, 100.0), size.y)


func _animate_in() -> void:
	_layout()
	# The Home card, where it was; then across.
	var from := _source.get_global_rect()
	_mode_card.global_position = from.position
	_mode_card.size = from.size
	_slide = create_tween().set_parallel()
	var target := _target_card()
	_slide.tween_property(_mode_card, "position", target.position, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_mode_card, "size", target.size, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(_rail, "modulate:a", 0.0, 0.25)
	_slide.tween_property(_home, "modulate:a", 0.0, 0.2)
	_back.modulate.a = 0.0
	_slide.tween_property(_back, "modulate:a", 1.0, 0.3).set_delay(0.2)
	_content.modulate.a = 0.0
	_slide.tween_property(_content, "modulate:a", 1.0, 0.3).set_delay(0.18)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _closing:
		get_viewport().set_input_as_handled()
		back()


## One step back: the bouts become the arenas again; from the first page the
## card slides home and the rail returns.
func back() -> void:
	if _closing:
		return
	Sfx.play("tick", -8.0)
	if _levels.size() > 1:
		_levels.pop_back()
		_show_level(_levels[_levels.size() - 1])
		return
	close()


func close() -> void:
	if _closing:
		return
	_closing = true
	if _slide:
		_slide.kill()
	var tween := create_tween().set_parallel()
	var from := _source.get_global_rect()
	tween.tween_property(_mode_card, "global_position", from.position, SLIDE * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_mode_card, "size", from.size, SLIDE * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_content, "modulate:a", 0.0, 0.15)
	tween.tween_property(_back, "modulate:a", 0.0, 0.15)
	tween.tween_property(_rail, "modulate:a", 1.0, 0.3).set_delay(0.12)
	tween.tween_property(_home, "modulate:a", 1.0, 0.3).set_delay(0.12)
	tween.chain().tween_callback(func() -> void:
		closed.emit()
		queue_free())


# --- Pages ---------------------------------------------------------------------------

func _push(level: Dictionary, animate := true) -> void:
	_levels.append(level)
	_show_level(level, animate)


func _show_level(level: Dictionary, animate := true) -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var heading := UiTheme.title_label(String(level.heading), 30, UiTheme.GOLD)
	_content.add_child(heading)
	if String(level.get("sub", "")) != "":
		var sub := Label.new()
		sub.text = level.sub
		sub.add_theme_font_size_override("font_size", 15)
		sub.add_theme_color_override("font_color", UiTheme.MUTED)
		_content.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.custom_minimum_size.y = CARD.y + 40.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var holder := MarginContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("margin_top", 10)
	holder.add_theme_constant_override("margin_bottom", 10)
	holder.add_theme_constant_override("margin_left", 4)
	holder.add_theme_constant_override("margin_right", 8)
	holder.add_child(row)
	scroll.add_child(holder)
	for option in level.options:
		row.add_child(_option_card(option, level))
	if animate:
		_content.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(_content, "modulate:a", 1.0, 0.2)


## A place or bout: the picture across the top with its name on it, then what
## it asks and how you stack up, the progress pips at the foot.
func _option_card(option: Dictionary, level: Dictionary) -> Control:
	var accent: Color = option.get("accent", UiTheme.GOLD)
	var card := Button.new()
	card.custom_minimum_size = CARD
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_NONE
	var face := UiTheme.raised(Color(0.05, 0.045, 0.07, 0.92), Color(accent, 0.8), 2, 12)
	var hover := UiTheme.raised(Color(accent.darkened(0.8), 0.96), accent.lightened(0.25), 3, 12)
	hover.shadow_color = Color(accent, 0.4)
	hover.shadow_size = 14
	for state in ["normal", "disabled"]:
		card.add_theme_stylebox_override(state, face)
	for state in ["hover", "pressed", "hover_pressed"]:
		card.add_theme_stylebox_override(state, hover)
	var width := CARD.x
	if option.get("art") != null:
		var art := TextureRect.new()
		art.texture = option.art
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.position = Vector2(3, 3)
		art.size = Vector2(width - 6.0, ART_HEIGHT)
		if option.has("tint"):
			art.modulate = Color.WHITE.lerp(option.tint, 0.6)
		card.add_child(art)
		var shade := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0.03, 0.025, 0.04, 0.0))
		gradient.set_color(gradient.get_point_count() - 1, Color(0.03, 0.025, 0.04, 0.92))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0, 0.35)
		texture.fill_to = Vector2(0, 1)
		shade.texture = texture
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.position = art.position
		shade.size = art.size
		card.add_child(shade)
	if option.get("art") == null:
		# No picture (the drills): a block of the card's color to carry the big word.
		var block := Panel.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.position = Vector2(3, 3)
		block.size = Vector2(width - 6.0, ART_HEIGHT)
		block.add_theme_stylebox_override("panel", UiTheme.box(accent.darkened(0.78), Color.TRANSPARENT, 0, 10))
		card.add_child(block)
	if option.has("number"):
		var number := UiTheme.title_label(String(option.number), 54, accent.lightened(0.2))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.position = Vector2(14, 10)
		card.add_child(number)
	var name_label := UiTheme.title_label(String(option.name), 26, UiTheme.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(14, ART_HEIGHT - 40.0)
	name_label.size = Vector2(width - 24.0, 36.0)
	name_label.clip_text = true
	card.add_child(name_label)
	var y := ART_HEIGHT + 12.0
	for text in [option.get("place", ""), option.get("detail", "")]:
		if String(text) == "":
			continue
		var small := Label.new()
		small.text = text
		small.add_theme_font_size_override("font_size", 13)
		small.add_theme_color_override("font_color", UiTheme.MUTED)
		small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		small.position = Vector2(14, y)
		var tall := String(text).length() > 27
		small.size = Vector2(width - 28.0, 40.0 if tall else 20.0)
		card.add_child(small)
		y += 42.0 if tall else 22.0
	y += 4.0
	for line in option.get("lines", []):
		var extra := Label.new()
		extra.text = line[0]
		extra.add_theme_font_size_override("font_size", 14)
		extra.add_theme_font_override("font", UiTheme.bold_font())
		extra.add_theme_color_override("font_color", line[1])
		extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra.position = Vector2(14, y)
		card.add_child(extra)
		y += 22.0
	if option.has("pips"):
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 6)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.position = Vector2(14, CARD.y - 28.0)
		for k in option.pips[1]:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(22, 8)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pip.add_theme_stylebox_override("panel", UiTheme.box(accent if k < option.pips[0] else Color(1, 1, 1, 0.16), Color.TRANSPARENT, 0, 4))
			pips.add_child(pip)
		card.add_child(pips)
	var value = option.value
	card.pressed.connect(func() -> void:
		Sfx.play("tick")
		_pick(level, value))
	return card


func _pick(level: Dictionary, value: Variant) -> void:
	var next: Variant = level.pick.call(value)
	if next is Dictionary and not (next as Dictionary).is_empty():
		_push(next)
	else:
		# It started a scene: nothing more to show.
		_closing = true
