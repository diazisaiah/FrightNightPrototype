class_name VsIntro
extends CanvasLayer
## The fighting-game "VS" card before a Dead League bout: your fighter's art
## slams in from the left, the contender's portrait from the right, both on
## tilted panels; VS crashes down between them with a flash and the bell;
## names and the contender's tagline sit under them. Then the panels slide
## away and the bout starts. Any key or click skips it.

signal finished

const SLIDE_IN := 0.38
const VS_AT := 0.42
const HOLD := 2.1
const SLIDE_OUT := 0.32
const TILT := 0.13

var _done := false
var _skippable := false
var _left: Control
var _right: Control
var _vs: Label
var _flash: ColorRect
var _shade: ColorRect
var _words: Array[Control] = []


static func play(parent: Node, boss_index: int) -> VsIntro:
	var intro := VsIntro.new()
	intro.layer = 60
	intro.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(intro)
	intro._build(boss_index)
	intro._run()
	return intro


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable or _done:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_finish()


func _build(index: int) -> void:
	var view := get_viewport().get_visible_rect().size
	var profile := DeadLeagueRules.boss(index)
	var accent: Color = profile.accent
	var mine := GameState.fighter_color()
	_shade = ColorRect.new()
	_shade.color = Color(0.01, 0.008, 0.015, 0.0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	# Two tilted panels meeting on a slant through the middle.
	_left = _panel(load("res://art/versus/fighter_%s.png" % GameState.player_class), mine, view, true)
	_right = _panel(load("res://art/dead_league/portrait_%d.png" % index), accent, view, false)
	# Names under each side.
	_words.append(_name_block(GameState.fighter_name().to_upper(), GameState.CLASSES[GameState.player_class].name.to_upper(), mine, view, true))
	_words.append(_name_block(profile.name, profile.tagline, accent, view, false))
	_vs = UiTheme.title_label("VS", 180, UiTheme.GOLD)
	_vs.add_theme_constant_override("outline_size", 22)
	_vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vs.size = Vector2(400, 260)
	_vs.position = view / 2.0 - _vs.size / 2.0
	_vs.pivot_offset = _vs.size / 2.0
	_vs.modulate.a = 0.0
	add_child(_vs)
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.95, 0.85, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


## A tilted, clipped panel holding the art, edged in its color. left: it
## comes in from the left and its inner edge leans to the right.
func _panel(texture: Texture2D, color: Color, view: Vector2, left: bool) -> Control:
	var holder := Control.new()
	holder.size = view
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var frame := Panel.new()
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", UiTheme.box(color.darkened(0.7), Color.TRANSPARENT, 0, 0))
	frame.size = Vector2(view.x * 0.6, view.y * 1.6)
	frame.pivot_offset = frame.size / 2.0
	frame.rotation = TILT if left else TILT
	frame.position = Vector2(-view.x * 0.08 if left else view.x * 0.48, -view.y * 0.3)
	holder.add_child(frame)
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Zoomed out to the whole 3:4 portrait (head to knees), nudged up so the
	# names underneath don't cover the fighters, edges feathered into the panel.
	var art_height := view.y * 0.9
	art.size = Vector2(art_height * 0.75, art_height)
	art.position = Vector2(frame.size.x * 0.5 - art.size.x * 0.5 + (view.x * 0.04 if left else -view.x * 0.04),
			frame.size.y * 0.5 - art.size.y * 0.5 - view.y * 0.06)
	art.pivot_offset = art.size / 2.0
	art.rotation = -TILT
	var feather := ShaderMaterial.new()
	feather.shader = Loading._feather_shader()
	art.material = feather
	frame.add_child(art)
	# The side's color washing up from the bottom.
	var wash := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color, 0.0))
	gradient.set_color(1, Color(color.darkened(0.3), 0.75))
	var texture_wash := GradientTexture2D.new()
	texture_wash.gradient = gradient
	texture_wash.fill_from = Vector2(0, 0.45)
	texture_wash.fill_to = Vector2(0, 1)
	wash.texture = texture_wash
	wash.size = frame.size
	frame.add_child(wash)
	# A bright edge along the panel.
	var edge := Panel.new()
	edge.add_theme_stylebox_override("panel", UiTheme.box(Color.TRANSPARENT, color.lightened(0.35), 5, 0))
	edge.size = frame.size
	edge.pivot_offset = frame.pivot_offset
	edge.rotation = frame.rotation
	edge.position = frame.position
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(edge)
	holder.position.x = -view.x if left else view.x
	return holder


func _name_block(title: String, subtitle: String, color: Color, view: Vector2, left: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.size = Vector2(view.x * 0.42, 120)
	box.position = Vector2(48 if left else view.x * 0.58 - 48, view.y - 150)
	box.alignment = BoxContainer.ALIGNMENT_END
	var name_label := UiTheme.title_label(title, 58, color.lightened(0.25))
	name_label.add_theme_constant_override("outline_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name_label)
	var sub := UiTheme.title_label(subtitle, 24, UiTheme.TEXT)
	sub.horizontal_alignment = name_label.horizontal_alignment
	box.add_child(sub)
	box.modulate.a = 0.0
	add_child(box)
	return box


func _run() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_shade, "color:a", 0.88, 0.2)
	tween.tween_property(_left, "position:x", 0.0, SLIDE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_right, "position:x", 0.0, SLIDE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("whoosh", -2.0, 0.7)
	await get_tree().create_timer(VS_AT, true, false, true).timeout
	if _done:
		return
	_skippable = true
	# VS crashes down.
	_vs.scale = Vector2(3.2, 3.2)
	var slam := create_tween().set_parallel()
	slam.tween_property(_vs, "modulate:a", 1.0, 0.1)
	slam.tween_property(_vs, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await slam.finished
	if _done:
		return
	Sfx.play("heavy", 4.0, 0.7)
	Sfx.play("bell")
	_flash.color.a = 0.55
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_shake()
	for i in _words.size():
		var word := _words[i]
		var reveal := create_tween()
		reveal.tween_interval(0.1 + i * 0.12)
		reveal.tween_property(word, "modulate:a", 1.0, 0.25)
	# VS keeps a slow throb while you look.
	var throb := create_tween().set_loops(4)
	throb.tween_property(_vs, "scale", Vector2(1.06, 1.06), 0.25).set_trans(Tween.TRANS_SINE)
	throb.tween_property(_vs, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(HOLD, true, false, true).timeout
	_finish()


func _shake() -> void:
	var shake := create_tween()
	for i in 6:
		var offset := Vector2(randf_range(-14, 14), randf_range(-10, 10)) * (1.0 - i / 6.0)
		shake.tween_property(self, "offset", offset, 0.03)
	shake.tween_property(self, "offset", Vector2.ZERO, 0.04)


func _finish() -> void:
	if _done:
		return
	_done = true
	var view := get_viewport().get_visible_rect().size
	var out := create_tween().set_parallel()
	out.tween_property(_left, "position:x", -view.x, SLIDE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(_right, "position:x", view.x, SLIDE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.tween_property(_shade, "color:a", 0.0, SLIDE_OUT)
	out.tween_property(_vs, "modulate:a", 0.0, SLIDE_OUT * 0.6)
	for word in _words:
		out.tween_property(word, "modulate:a", 0.0, SLIDE_OUT * 0.6)
	await out.finished
	finished.emit()
	queue_free()
