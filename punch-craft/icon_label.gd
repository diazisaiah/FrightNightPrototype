class_name IconLabel
extends VBoxContainer
## Text with resource icons in it: write {coins}, {silver}, {xp}, {souls},
## {skill_points}, {stat_points} or {knuckles} and the token is drawn in
## place, e.g. "Room cleared   +40 {coins}". Lines split on \n.
## Use like a Label: set text, font_size, color, outline and alignment.

var text := "":
	set(value):
		if value == text:
			return
		text = value
		_rebuild()
var font_size := 18:
	set(value):
		font_size = value
		_rebuild()
var color := UiTheme.TEXT:
	set(value):
		color = value
		_rebuild()
var outline := 5
var font: Font = null
var alignment_h := BoxContainer.ALIGNMENT_CENTER:
	set(value):
		alignment_h = value
		_rebuild()


## Wraps a button's text in an IconLabel so the button can show icons.
static func on_button(button: Button, label_text: String, size := 18) -> IconLabel:
	var existing := button.get_node_or_null("IconText") as IconLabel
	var label := existing if existing else IconLabel.new()
	if not existing:
		label.name = "IconText"
		label.outline = 3
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(label)
	button.text = ""
	label.font_size = size
	label.color = UiTheme.TEXT if not button.disabled else UiTheme.MUTED
	label.text = label_text
	return label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if text == "":
		return
	var icon_size := float(font_size) * 1.25
	for line in text.split("\n"):
		var row := HBoxContainer.new()
		row.alignment = alignment_h
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 0)
		add_child(row)
		if line == "":
			row.custom_minimum_size.y = font_size
			continue
		var rest := line
		while rest != "":
			var open := rest.find("{")
			var close := rest.find("}", open) if open >= 0 else -1
			if open < 0 or close < 0:
				row.add_child(_piece(rest))
				break
			if open > 0:
				row.add_child(_piece(rest.substr(0, open)))
			var token := rest.substr(open + 1, close - open - 1)
			if ResIcon.INFO.has(token):
				var holder := MarginContainer.new()
				holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
				holder.add_theme_constant_override("margin_left", 3)
				holder.add_theme_constant_override("margin_right", 2)
				var icon := ResIcon.make(token, icon_size)
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				holder.add_child(icon)
				row.add_child(holder)
				holder.tooltip_text = ResIcon.name_of(token)
			else:
				row.add_child(_piece(rest.substr(open, close - open + 1)))
			rest = rest.substr(close + 1)


func _piece(piece: String) -> Label:
	var label := Label.new()
	label.text = piece
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", outline)
	return label
