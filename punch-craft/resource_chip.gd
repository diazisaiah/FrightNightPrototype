class_name ResourceChip
extends PanelContainer
## A pill with a resource icon and an amount (camp header, HUD). Changing the
## amount counts up or down, pops the icon, and floats the difference
## (+40 in green, -120 in red) down out of the pill.

var resource := "coins"
var amount := 0
## Shown after the number (e.g. " pts"); empty for none.
var suffix := ""

var _icon: ResIcon
var _label: Label
var _shown := 0.0
var _count_tween: Tween
var _pop_tween: Tween


static func make(id: String, icon_size := 30.0, font_size := 22) -> ResourceChip:
	var chip := ResourceChip.new()
	chip.resource = id
	chip._build(icon_size, font_size)
	return chip


func _build(icon_size: float, font_size: int) -> void:
	var color := ResIcon.color_of(resource)
	var style := UiTheme.box(Color(0.03, 0.025, 0.04, 0.72), Color(color, 0.35), 1, int(icon_size / 2.0) + 4)
	style.content_margin_left = 4
	style.content_margin_right = 14
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)
	tooltip_text = ResIcon.name_of(resource)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = ResIcon.make(resource, icon_size)
	_icon.pivot_offset = Vector2(icon_size, icon_size) / 2.0
	row.add_child(_icon)
	_label = Label.new()
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UiTheme.display_font())
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color.lightened(0.35))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_show(0)


## Sets the amount; animate shows the change (count, pop, floating number).
func set_amount(value: int, animate := true) -> void:
	var before := amount
	amount = value
	if not animate or value == before or not is_inside_tree():
		_shown = value
		_show(value)
		return
	if _count_tween:
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(func(v: float) -> void:
		_shown = v
		_show(roundi(v)), _shown, float(value), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop()
	_float_difference(value - before)


## Bounces the icon (also used to draw the eye to a resource).
func pop() -> void:
	if _pop_tween:
		_pop_tween.kill()
	_pop_tween = create_tween().set_parallel()
	_icon.scale = Vector2.ONE * 1.35
	_icon.glow = 1.0
	_pop_tween.tween_property(_icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_tween.tween_property(_icon, "glow", 0.0, 0.5)


## A red shake: not enough of this resource.
func deny() -> void:
	var start := position
	var tween := create_tween()
	modulate = Color(1.4, 0.6, 0.6)
	for i in 4:
		tween.tween_property(self, "position:x", start.x + (5.0 if i % 2 == 0 else -5.0), 0.04)
	tween.tween_property(self, "position:x", start.x, 0.04)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.3)


func _show(value: int) -> void:
	_label.text = _format(value) + suffix


func _float_difference(difference: int) -> void:
	var label := Label.new()
	label.text = ("+%s" % _format(difference)) if difference > 0 else ("-%s" % _format(-difference))
	label.add_theme_font_override("font", UiTheme.display_font())
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiTheme.GOOD if difference > 0 else UiTheme.BAD)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.top_level = true
	add_child(label)
	# Drops out under the pill (the pills sit along the top of the screen).
	label.global_position = global_position + Vector2(size.x - 40.0, size.y - 8.0)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "global_position:y", label.global_position.y + 22.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)


## 1234 -> "1,234".
static func _format(value: int) -> String:
	var digits := str(absi(value))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.substr(digits.length() - 3) + result
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + result
