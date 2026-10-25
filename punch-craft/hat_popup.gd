class_name HatPopup
extends CanvasLayer
## A hat just popped off: the game pauses on a card with the hat turning in
## the middle, sparkles and a sunburst in its rarity color, its name, a joke,
## its boost, and one button: GIMME THAT. Pressing it collects the hat (or
## turns a duplicate into Souls) and the game resumes.

## Popups that came in while one was already open.
static var _queue: Array[String] = []
static var _open := false

var _id := ""
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _hat: Node3D
var _burst: Control
var _time := 0.0


static func open(tree: SceneTree, id: String) -> void:
	if id == "" or tree == null:
		return
	if _open:
		_queue.append(id)
		return
	_open = true
	var popup := HatPopup.new()
	popup._id = id
	popup.layer = 95
	popup.process_mode = Node.PROCESS_MODE_ALWAYS
	(tree.current_scene if tree.current_scene else tree.root).add_child(popup)


func _ready() -> void:
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	Sfx.play("unlock", 0.0, 1.1)


func _input(event: InputEvent) -> void:
	# Esc mustn't unpause the game underneath the card.
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	if _hat:
		_hat.rotation.y = _time * 1.2
		_hat.position.y = sin(_time * 2.0) * 0.04
	if _burst:
		_burst.rotation = _time * 0.25
		_burst.pivot_offset = _burst.size / 2.0


func _build() -> void:
	var info := Hats.info(_id)
	var tint := Hats.color(_id)
	var duplicate := GameState.hats.has(_id)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(560, 600)
	center.add_child(stack)
	# A slow sunburst in the rarity color behind the card.
	_burst = Control.new()
	_burst.size = Vector2(900, 900)
	_burst.position = stack.custom_minimum_size / 2.0 - _burst.size / 2.0
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.draw.connect(func() -> void:
		var c := _burst.size / 2.0
		for i in 16:
			var a := i * TAU / 16.0
			var points := PackedVector2Array([c, c + Vector2.from_angle(a - 0.08) * 450.0, c + Vector2.from_angle(a + 0.08) * 450.0])
			_burst.draw_colored_polygon(points, Color(tint, 0.13 if i % 2 == 0 else 0.06)))
	stack.add_child(_burst)
	var card := PanelContainer.new()
	var style := UiTheme.card(26.0)
	style.border_color = Color(tint, 0.9)
	style.shadow_color = Color(tint, 0.35)
	style.shadow_size = 22
	card.add_theme_stylebox_override("panel", style)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var heading := UiTheme.heading("ALREADY GOT ONE, YA GREEDY GHOUL" if duplicate else "%s HAT" % Items.RARITIES[info.rarity].name.to_upper(),
			24 if duplicate else 28, tint.lightened(0.2))
	column.add_child(heading)
	column.add_child(_preview(tint))
	var title := UiTheme.heading(info.name.to_upper(), 46, UiTheme.TEXT)
	column.add_child(title)
	var desc := Label.new()
	desc.text = info.desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", UiTheme.MUTED)
	column.add_child(desc)
	var boost := IconLabel.new()
	boost.font_size = 22
	if duplicate:
		boost.text = "+%d {souls}" % Hats.DUPLICATE_SOULS[info.rarity]
		boost.color = Color(0.55, 0.95, 0.9)
	elif _id in Hats.LEGENDARIES:
		var owned := Hats.LEGENDARIES.filter(func(id: String) -> bool: return GameState.hats.has(id)).size()
		boost.text = "YONKERS  %d / 4" % (owned + 1)
		boost.color = tint.lightened(0.2)
	else:
		boost.text = Hats.boost_text(_id)
		boost.color = UiTheme.GOOD
	column.add_child(boost)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	column.add_child(gap)
	var button := Button.new()
	button.text = "GIMME THAT"
	button.theme_type_variation = "PrimaryButton"
	button.custom_minimum_size = Vector2(280, 60)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_override("font", UiTheme.display_font())
	button.add_theme_font_size_override("font_size", 30)
	button.pressed.connect(_collect)
	column.add_child(button)
	# Sparkles twinkling around the card.
	var sparkles := CPUParticles2D.new()
	sparkles.amount = 40
	sparkles.lifetime = 1.4
	sparkles.position = stack.custom_minimum_size / 2.0
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = Vector2(300, 320)
	sparkles.gravity = Vector2(0, -20)
	sparkles.initial_velocity_min = 5.0
	sparkles.initial_velocity_max = 30.0
	sparkles.scale_amount_min = 2.0
	sparkles.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.lightened(0.6), 0.0))
	ramp.add_point(0.3, Color(tint.lightened(0.4), 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	sparkles.color_ramp = ramp
	stack.add_child(sparkles)
	# Pop in.
	stack.pivot_offset = stack.custom_minimum_size / 2.0
	stack.scale = Vector2(0.6, 0.6)
	stack.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(stack, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(stack, "modulate:a", 1.0, 0.18)


## The hat turning in a little 3D window, with sparkles.
func _preview(tint: Color) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(320, 230)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.8
	view.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, -0.5, 0)
	key.light_energy = 1.3
	view.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = tint
	rim.light_energy = 3.0
	rim.position = Vector3(0, 0.8, -1.2)
	view.add_child(rim)
	var holder := Node3D.new()
	view.add_child(holder)
	_hat = Hats.build(_id, 1.0)
	holder.add_child(_hat)
	Hats.sparkles(holder, tint, 0.9)
	var camera := Camera3D.new()
	camera.fov = 40
	camera.look_at_from_position(Vector3(0, 0.9, 3.0), Vector3(0, 0.42, 0))
	view.add_child(camera)
	return frame


func _collect() -> void:
	var result := GameState.add_hat(_id)
	Sfx.play("coin", 0.0, 1.2)
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	_open = false
	queue_free()
	if result == "tony":
		TonyUnlock.open(get_tree())
	elif not _queue.is_empty():
		HatPopup.open(get_tree(), _queue.pop_front())
