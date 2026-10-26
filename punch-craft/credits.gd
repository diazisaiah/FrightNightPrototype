class_name Credits
extends CanvasLayer
## Credits from the title menu: who made it, what it's built with, and the
## license notices the engine and font require, in one scrolling card.

const MADE_BY := "isaiahd0221"
const FONT_LICENSE := "res://fonts/Anton-OFL.txt"


static func open(parent: Node) -> Credits:
	var credits := Credits.new()
	credits.layer = 90
	credits.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(credits)
	return credits


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(26.0))
	card.custom_minimum_size = Vector2(720, 560)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	var heading := UiTheme.title_label("CREDITS", 44, UiTheme.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var scroll := KeptScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	_section(body, "FRIGHT NIGHT")
	_line(body, "A game by %s" % MADE_BY, UiTheme.TEXT, 22)
	_gap(body)
	_section(body, "BUILT WITH")
	_line(body, "Godot Engine %s (godotengine.org)" % Engine.get_version_info().string, UiTheme.TEXT, 18)
	_line(body, "Anton typeface by Vernon Adams (SIL Open Font License 1.1)", UiTheme.TEXT, 18)
	_line(body, "Sounds and music made in code for this game", UiTheme.TEXT, 18)
	_gap(body)
	_section(body, "THANKS")
	_line(body, "Everyone who stepped into the ring at midnight.", UiTheme.MUTED, 18)
	_gap(body)
	_section(body, "LICENSES")
	_line(body, "Godot Engine\n" + Engine.get_license_text(), UiTheme.MUTED, 13)
	if FileAccess.file_exists(FONT_LICENSE):
		_line(body, "Anton\n" + FileAccess.get_file_as_string(FONT_LICENSE), UiTheme.MUTED, 13)
	_line(body, "Godot Engine third-party components:\n" + _third_party(), UiTheme.MUTED, 13)
	var close := Button.new()
	close.text = "Back"
	close.theme_type_variation = "PrimaryButton"
	close.custom_minimum_size = Vector2(220, 52)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(queue_free)
	column.add_child(close)
	close.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


func _section(parent: Control, text: String) -> void:
	var label := UiTheme.title_label(text, 24, UiTheme.GOLD)
	parent.add_child(label)


func _line(parent: Control, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 640
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _gap(parent: Control) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	parent.add_child(gap)


## The engine's bundled libraries and their copyright holders.
func _third_party() -> String:
	var lines := []
	for component in Engine.get_copyright_info():
		var holders := []
		for part in component.parts:
			holders.append(", ".join(part.copyright))
		lines.append("%s: %s" % [component.name, "; ".join(holders)])
	return "\n".join(lines)
