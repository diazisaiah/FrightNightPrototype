class_name GameDialog
extends CanvasLayer
## The game's own message box: dims the screen and shows a titled card with
## buttons. Replaces Godot's window-style dialogs so every popup matches.

signal chosen(index: int)


## Shows a card over everything. buttons: labels, the first is the gold one.
## Emits chosen(index) and closes when one is pressed.
static func open(parent: Node, title: String, body: String, buttons: Array = ["OK"]) -> GameDialog:
	var dialog := GameDialog.new()
	dialog.layer = 90
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(dialog)
	dialog._build(title, body, buttons)
	return dialog


func _build(title: String, body: String, buttons: Array) -> void:
	var previous_mouse := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.06, 0.055, 0.08, 0.98), Color(UiTheme.GOLD, 0.55), 2, 12, 26.0, 18))
	card.custom_minimum_size.x = 460
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)
	var heading := UiTheme.title_label(title, 34, UiTheme.GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	if body != "":
		if "{" in body:
			var icons := IconLabel.new()
			icons.text = body
			icons.font_size = 18
			column.add_child(icons)
		else:
			var text := Label.new()
			text.text = body
			text.add_theme_font_size_override("font_size", 18)
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.custom_minimum_size.x = 460
			column.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	for i in buttons.size():
		var button := Button.new()
		button.text = buttons[i]
		button.custom_minimum_size = Vector2(160, 46)
		if i == 0:
			button.theme_type_variation = "PrimaryButton"
		button.pressed.connect(func() -> void:
			Sfx.play("tick")
			Input.mouse_mode = previous_mouse
			chosen.emit(i)
			queue_free())
		row.add_child(button)
	# Pop in.
	card.pivot_offset = card.get_combined_minimum_size() / 2.0
	card.scale = Vector2(0.92, 0.92)
	card.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "color:a", 0.6, 0.2)
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
