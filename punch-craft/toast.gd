class_name Toast
extends CanvasLayer
## A small banner that slides down from the top, holds a few seconds and
## slides away (achievements). Runs while paused; toasts queue up.

static var _queue: Array = []
static var _showing := false


static func show_on(tree: SceneTree, title: String, subtitle: String) -> void:
	if tree == null:
		return
	if _showing:
		_queue.append([title, subtitle])
		return
	_showing = true
	var toast := Toast.new()
	toast.layer = 97
	toast.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(toast)
	toast._build(title, subtitle)


func _build(title: String, subtitle: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.raised(Color(UiTheme.PANEL, 0.96), UiTheme.GOLD, 2, 12, 14.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	card.add_child(column)
	column.add_child(UiTheme.title_label(title, 22, UiTheme.GOLD))
	var line := Label.new()
	line.text = subtitle
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", UiTheme.TEXT)
	column.add_child(line)
	Sfx.play("unlock", -4.0, 1.2)
	await get_tree().process_frame
	var screen := get_viewport().get_visible_rect().size
	var width := card.get_combined_minimum_size().x
	card.position = Vector2((screen.x - width) / 2.0, -120.0)
	var tween := create_tween()
	tween.tween_property(card, "position:y", 18.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(3.6)
	tween.tween_property(card, "position:y", -140.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_done)


func _done() -> void:
	_showing = false
	queue_free()
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		Toast.show_on(get_tree(), next[0], next[1])
