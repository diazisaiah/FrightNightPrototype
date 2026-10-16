class_name TonyUnlock
extends CanvasLayer
## The fourth Yonker: the screen goes black, a deli bell dings, and Tony
## steps out. "TONY WANTS HIS SANDWICH." He's playable from now on.

var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE


static func open(tree: SceneTree) -> void:
	var screen := TonyUnlock.new()
	screen.layer = 96
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	(tree.current_scene if tree.current_scene else tree.root).add_child(screen)


func _ready() -> void:
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var art := TextureRect.new()
	art.texture = load("res://art/fighter_wise_guy.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.anchor_left = 0.5
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	art.modulate.a = 0.0
	add_child(art)
	var words := VBoxContainer.new()
	words.anchor_top = 0.5
	words.anchor_bottom = 0.5
	words.anchor_right = 0.55
	words.offset_left = 72
	words.offset_top = -170
	words.offset_bottom = 170
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 10)
	add_child(words)
	var small := UiTheme.title_label("NEW FIGHTER", 22, UiTheme.GOLD)
	words.add_child(small)
	var big := UiTheme.title_label("TONY WANTS\nHIS SANDWICH", 72, Color(0.95, 0.2, 0.15))
	big.add_theme_constant_override("outline_size", 14)
	words.add_child(big)
	var who := UiTheme.title_label("TONY  ·  WISE GUY", 30, UiTheme.TEXT)
	words.add_child(who)
	var button := Button.new()
	button.text = "FUGGEDABOUDIT"
	button.theme_type_variation = "PrimaryButton"
	button.custom_minimum_size = Vector2(300, 58)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_override("font", UiTheme.display_font())
	button.add_theme_font_size_override("font_size", 28)
	button.pressed.connect(_close)
	words.add_child(button)
	for node in words.get_children():
		node.modulate.a = 0.0
	# Black, the deli bell, then Tony.
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, 0.5)
	tween.tween_callback(func() -> void: Sfx.play("tell", 2.0, 1.6))
	tween.tween_interval(0.25)
	tween.tween_callback(func() -> void: Sfx.play("tell", 2.0, 1.6))
	tween.tween_interval(0.5)
	tween.tween_property(art, "modulate:a", 1.0, 0.6)
	for node in words.get_children():
		tween.tween_property(node, "modulate:a", 1.0, 0.25)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _close() -> void:
	Sfx.play("unlock", 0.0, 1.0)
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	queue_free()
