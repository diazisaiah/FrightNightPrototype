class_name Ending
extends CanvasLayer
## Beating the Coffin King for the first time: the lights go down, your
## fighter dances in the Coffin Crown while the announcer calls the new
## champion, then the credits roll. Click or press anything to skip to the
## end; Continue goes on to the results.

signal finished

const CREDITS_TIME := 14.0
## Clicks this soon after it opens are still punches from the fight.
const GRACE_MS := 1500

var _stage: EmotePreview
var _words: VBoxContainer
var _roll_area: Control
var _continue: Button
var _skipped := false
var _opened_at := 0


static func open(parent: Node) -> Ending:
	var ending := Ending.new()
	ending.layer = 80
	ending.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(ending)
	return ending


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_opened_at = Time.get_ticks_msec()
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.0, 0.02, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	dim.create_tween().tween_property(dim, "color:a", 0.93, 0.8)
	_confetti()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = UiTheme.make()
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	center.add_child(row)
	_stage = EmotePreview.new(GameState.player_class, 3.9)
	_stage.emote_id = "default"
	_stage.custom_minimum_size = Vector2(400, 560)
	row.add_child(_stage)
	_stage.body.wear_hat("coffin_crown")
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(580, 560)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	_words = VBoxContainer.new()
	_words.add_theme_constant_override("separation", 10)
	column.add_child(_words)
	_roll_area = Control.new()
	_roll_area.clip_contents = true
	_roll_area.custom_minimum_size = Vector2(580, 0)
	_roll_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roll_area.visible = false
	column.add_child(_roll_area)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.theme_type_variation = "PrimaryButton"
	_continue.custom_minimum_size = Vector2(220, 52)
	_continue.add_theme_font_size_override("font_size", 22)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.visible = false
	_continue.pressed.connect(_finish)
	column.add_child(_continue)
	_play()


func _play() -> void:
	for i in 3:
		Sfx.play("bell", -2.0)
		await _wait(0.35)
	await _wait(0.4)
	await _say("THE COFFIN KING IS DOWN!", 52, UiTheme.GOLD, 1.6)
	await _say("Ladies, gentlemen and gentle corpses...", 26, UiTheme.TEXT, 1.5)
	await _say("Your new champion of the Dead League:", 26, UiTheme.TEXT, 0.9)
	if _skipped:
		return
	Sfx.play("clear")
	await _say(GameState.fighter_name().to_upper(), 76, GameState.fighter_color().lightened(0.15), 2.2)
	if _skipped:
		return
	Sfx.play("unlock")
	await _say("THE COFFIN CROWN IS YOURS", 34, Items.RARITIES.legendary.color, 0.5)
	await _say("%s\nWear it from Cosmetics." % Hats.boost_text("coffin_crown"), 18, UiTheme.GOOD, 2.8)
	if _skipped:
		return
	await _roll_credits()
	if not _skipped:
		_show_end()


## Waits, cut short by a skip.
func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipped and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


## A line of the announcer fading in, then a pause.
func _say(text: String, font_size: int, color: Color, hold: float) -> void:
	if _skipped:
		return
	var label := UiTheme.title_label(text, font_size, color) if font_size >= 34 else _text(text, font_size, color)
	_fit(label)
	label.modulate.a = 0.0
	_words.add_child(label)
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.35)
	await _wait(hold)


func _roll_credits() -> void:
	# The announcer bows out; the names go up.
	var fade := _words.create_tween()
	fade.tween_property(_words, "modulate:a", 0.0, 0.5)
	await _wait(0.5)
	if _skipped:
		return
	_words.visible = false
	_roll_area.visible = true
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size.x = 580
	_roll_area.add_child(list)
	_credit(list, "FRIGHT NIGHT", 52, UiTheme.GOLD)
	_credit(list, "A game by %s" % Credits.MADE_BY, 22, UiTheme.TEXT)
	_credit(list, "", 18, UiTheme.TEXT)
	_credit(list, "THE FIGHTERS", 26, UiTheme.GOLD.darkened(0.15))
	for id in GameState.class_ids():
		_credit(list, GameState.fighter_name(id), 20, GameState.fighter_color(id).lightened(0.2))
	_credit(list, "", 18, UiTheme.TEXT)
	_credit(list, "THE DEAD LEAGUE", 26, UiTheme.GOLD.darkened(0.15))
	for index in DeadLeagueRules.BOSS_COUNT:
		var profile := DeadLeagueRules.boss(index)
		_credit(list, String(profile.name), 20, Color(profile.accent).lightened(0.2))
	_credit(list, "", 18, UiTheme.TEXT)
	_credit(list, "BUILT WITH", 26, UiTheme.GOLD.darkened(0.15))
	_credit(list, "Godot Engine", 20, UiTheme.TEXT)
	_credit(list, "Anton by Vernon Adams", 20, UiTheme.TEXT)
	_credit(list, "", 18, UiTheme.TEXT)
	_credit(list, "THANK YOU FOR PLAYING", 40, UiTheme.GOLD)
	await get_tree().process_frame
	var height := _roll_area.size.y
	list.position.y = height
	var roll := list.create_tween()
	roll.tween_property(list, "position:y", (height - list.size.y) * 0.5, CREDITS_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _wait(CREDITS_TIME)


func _credit(list: VBoxContainer, text: String, font_size: int, color: Color) -> void:
	var label := UiTheme.title_label(text, font_size, color) if font_size >= 26 else _text(text, font_size, color)
	_fit(label)
	list.add_child(label)


## Skipped, or done: the champion's card and Continue.
func _show_end() -> void:
	_roll_area.visible = false
	for child in _words.get_children():
		child.queue_free()
	_words.visible = true
	_words.modulate.a = 1.0
	for line in [["CHAMPION OF THE DEAD LEAGUE", 40, UiTheme.GOLD],
			[GameState.fighter_name().to_upper(), 76, GameState.fighter_color().lightened(0.15)],
			["THE COFFIN CROWN IS YOURS", 30, Items.RARITIES.legendary.color]]:
		var label := UiTheme.title_label(line[0], line[1], line[2])
		_fit(label)
		_words.add_child(label)
	var boost := _text("%s\nWear it from Cosmetics." % Hats.boost_text("coffin_crown"), 18, UiTheme.GOOD)
	_fit(boost)
	_words.add_child(boost)
	_continue.visible = true
	_continue.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed)
	if not pressed or _continue.visible or Time.get_ticks_msec() - _opened_at < GRACE_MS:
		return
	get_viewport().set_input_as_handled()
	_skipped = true
	_show_end()


func _finish() -> void:
	finished.emit()
	queue_free()


## Gold flecks drifting down over everything.
func _confetti() -> void:
	var view := get_viewport().get_visible_rect().size
	var flecks := CPUParticles2D.new()
	flecks.position = Vector2(view.x * 0.5, -20)
	flecks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flecks.emission_rect_extents = Vector2(view.x * 0.55, 10)
	flecks.amount = 120
	flecks.lifetime = 6.0
	flecks.preprocess = 2.0
	flecks.direction = Vector2(0, 1)
	flecks.spread = 15.0
	flecks.gravity = Vector2(0, 60)
	flecks.initial_velocity_min = 40.0
	flecks.initial_velocity_max = 110.0
	flecks.angular_velocity_min = -180.0
	flecks.angular_velocity_max = 180.0
	flecks.scale_amount_min = 3.0
	flecks.scale_amount_max = 6.0
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.85, 0.3))
	colors.set_color(1, Color(1.0, 0.6, 0.15, 0.0))
	flecks.color_ramp = colors
	add_child(flecks)


## Centered in the column, wrapping when it's long.
func _fit(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 560


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 560
	return label
