class_name SecretEnding
extends CanvasLayer
## The plumber quest's secret credits: beat the Coffin King as Tony in the
## Plumber Overalls and the Fat Plumber Cap. Tony jumps and shuffles, swings
## the Coffin King round by the ankles and throws him out of the building, a
## little mushroom man brings bad news about the princess and gets
## uppercut into orbit. A nod, not a copy: no emblems, costumes or lines
## lifted from anyone (GAME_DESIGN.md, "Parody, not copies"). True Ending? (Princess Plum is a secret boss for
## later.) Press anything to skip to the end.

signal finished

## Clicks this soon after it opens are still punches from the fight.
const GRACE_MS := 1500
const SPOTLIGHT := Color(1.0, 0.92, 0.75)
## A brown bolete of a man, not anyone's red-and-white one.
const MUSHROOM_CAP := Color(0.5, 0.3, 0.15)
const MUSHROOM_GILLS := Color(0.86, 0.78, 0.6)

var _viewport: SubViewport
var _camera: Camera3D
var _tony: PlayerBody
var _king: Node3D
var _mushroom: Node3D
var _card: VBoxContainer
var _continue: Button
var _skipped := false
var _opened_at := 0


## Tony, in the overalls and wearing the Fat Plumber Cap.
static func qualifies() -> bool:
	return GameState.player_class == "wise_guy" and GameState.skin("wise_guy") == "plumber_overalls" \
			and GameState.worn_hat == "fat_plumber_cap"


static func open(parent: Node) -> SecretEnding:
	var ending := SecretEnding.new()
	ending.layer = 81
	ending.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(ending)
	return ending


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_opened_at = Time.get_ticks_msec()
	var black := ColorRect.new()
	black.color = Color(0.01, 0.0, 0.02)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	view.add_child(_viewport)
	_build_stage()
	_card = VBoxContainer.new()
	_card.add_theme_constant_override("separation", 12)
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.theme = UiTheme.make()
	_card.visible = false
	add_child(_card)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.theme_type_variation = "PrimaryButton"
	_continue.custom_minimum_size = Vector2(220, 52)
	_continue.add_theme_font_size_override("font_size", 22)
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_finish)
	_play()


# --- The stage ------------------------------------------------------------------------

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.03, 0.02, 0.05)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.4, 0.38, 0.48)
	environment.environment.glow_enabled = true
	_viewport.add_child(environment)
	var spot := SpotLight3D.new()
	spot.light_color = SPOTLIGHT
	spot.light_energy = 6.0
	spot.spot_range = 14.0
	spot.spot_angle = 38.0
	spot.position = Vector3(0, 7.5, -1.0)
	spot.rotation = Vector3(-PI / 2.0, 0, 0)
	_viewport.add_child(spot)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.6, 2.6, 0)
	fill.light_energy = 0.45
	_viewport.add_child(fill)
	# The ring: canvas, an apron and the bottom rope along the back.
	_box(_viewport, Vector3(9, 0.2, 7), Vector3(0, -0.1, 0.5), Color(0.82, 0.8, 0.74))
	_box(_viewport, Vector3(9.4, 0.5, 7.4), Vector3(0, -0.45, 0.5), Color(0.35, 0.08, 0.1))
	for y in [0.55, 1.0, 1.45]:
		_box(_viewport, Vector3(9, 0.05, 0.05), Vector3(0, y, 4.0), Color(0.75, 0.12, 0.12))
	for x in [-4.5, 4.5]:
		_box(_viewport, Vector3(0.22, 1.7, 0.22), Vector3(x, 0.85, 4.0), Color(0.6, 0.6, 0.64))
	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.position = Vector3(0.3, 1.9, -6.8)
	_viewport.add_child(_camera)
	_camera.look_at(Vector3(0.3, 1.0, 0.5))
	_build_cast()


## Who's on stage (PrincessRescue has its own).
func _build_cast() -> void:
	_tony = PlayerBody.new("wise_guy", "plumber_overalls")
	_tony.build_budget_ms = 12
	_tony.position = Vector3(-1.2, 0, 0)
	_viewport.add_child(_tony)
	_tony.wear_hat("fat_plumber_cap")
	var king: Node3D = load("res://dead_league_boss.tscn").instantiate()
	king.configure(DeadLeagueRules.BOSS_COUNT - 1, 1)
	king.position = Vector3(1.6, 0, 0.6)
	king.rotation.y = PI * 0.15
	_viewport.add_child(king)
	king.set_physics_process(false)
	king.set_process(false)
	# A prop: nothing in the arena should count it as a fighter.
	king.remove_from_group("enemies")
	_king = king
	_rig_play("dazed", 99.0)
	_mushroom = _build_mushroom()
	_mushroom.position = Vector3(5.5, 0, 0.2)
	_mushroom.visible = false
	_viewport.add_child(_mushroom)


func _process(delta: float) -> void:
	var rig = _king.get("_rig") if is_instance_valid(_king) else null
	if rig:
		rig.advance(delta)


func _rig_play(action: String, duration: float) -> void:
	var rig = _king.get("_rig")
	if rig:
		rig.set_motion(Vector3.ZERO, Basis.IDENTITY, true)
		rig.play(action, duration)


## A little mushroom man: a squat brown bolete cap with pale gills under
## it, a big grey moustache, a green waistcoat, brown trousers and boots.
func _build_mushroom() -> Node3D:
	var man := Node3D.new()
	var skin := Color(0.9, 0.78, 0.62)
	for side in [-1.0, 1.0]:
		_box(man, Vector3(0.14, 0.08, 0.2), Vector3(0.09 * side, 0.04, -0.02), Color(0.2, 0.12, 0.06))
		_box(man, Vector3(0.12, 0.2, 0.12), Vector3(0.09 * side, 0.18, 0), Color(0.42, 0.3, 0.18))
		_box(man, Vector3(0.09, 0.22, 0.09), Vector3(0.21 * side, 0.4, 0), skin)
	_box(man, Vector3(0.32, 0.28, 0.22), Vector3(0, 0.42, 0), Color(0.22, 0.45, 0.25))
	_box(man, Vector3(0.04, 0.2, 0.03), Vector3(0, 0.42, -0.115), Color(0.86, 0.8, 0.65))
	_box(man, Vector3(0.3, 0.28, 0.28), Vector3(0, 0.7, 0), skin)
	for side in [-1.0, 1.0]:
		_box(man, Vector3(0.05, 0.04, 0.02), Vector3(0.06 * side, 0.76, -0.145), Color(0.05, 0.05, 0.08))
		_box(man, Vector3(0.14, 0.06, 0.04), Vector3(0.07 * side, 0.64, -0.15), Color(0.7, 0.7, 0.72), Vector3(0, 0, -0.25 * side))
	# The cap: a low, broad bun-brown dome over pale gills.
	_box(man, Vector3(0.74, 0.06, 0.74), Vector3(0, 0.86, 0), MUSHROOM_GILLS)
	_box(man, Vector3(0.78, 0.18, 0.78), Vector3(0, 0.96, 0), MUSHROOM_CAP)
	_box(man, Vector3(0.58, 0.1, 0.58), Vector3(0, 1.08, 0), MUSHROOM_CAP.darkened(0.1))
	return man


func _box(parent: Node, size: Vector3, pos: Vector3, tint: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = Look.block_material(tint, 0.0)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
	return part


# --- The scene ------------------------------------------------------------------------

func _play() -> void:
	await _wait(0.6)
	# Yahoo! Three jumps, then the shuffle.
	_tony.play("plumber_jump")
	for i in 3:
		await _wait(0.4)
		_say(_tony, "YAHOO!", Color(1.0, 0.85, 0.3), 0.8)
		Sfx.play("whoosh", -4.0, 1.4)
		await _wait(0.9)
	_tony.play("bros_shuffle")
	await _wait(2.6)
	if _skipped:
		return
	await _swing_throw()
	if _skipped:
		return
	await _mushroom_man()
	if not _skipped:
		_show_end()


## Tony walks over, takes the Coffin King by the ankles, spins him round
## faster and faster and lets go.
func _swing_throw() -> void:
	_tony.stop()
	var to_king := _king.position - _tony.position
	_tony.rotation.y = atan2(-to_king.x, -to_king.z)
	var walk := _tony.create_tween()
	walk.tween_property(_tony, "position", _king.position - to_king.normalized() * 1.25, 0.6)
	await _wait(0.6)
	# He goes down flat, feet first into Tony's hands.
	_rig_play("dazed", 99.0)
	var pivot := Node3D.new()
	pivot.position = _tony.position
	pivot.rotation.y = _tony.rotation.y
	_viewport.add_child(pivot)
	var held := _king.global_transform
	_viewport.remove_child(_king)
	pivot.add_child(_king)
	_king.global_transform = held
	_tony.play("_swing")
	var grab := _king.create_tween()
	grab.tween_property(_king, "transform", Transform3D(Basis.from_euler(Vector3(-PI / 2.0, 0, 0)), Vector3(0, 0.95, -0.5)), 0.35)
	await _wait(0.4)
	var spins := 0.0
	var speed := 3.0
	var lap := 0.0
	while spins < 3.4 * TAU and not _skipped:
		var step := speed * get_process_delta_time()
		speed = minf(speed + 9.0 * get_process_delta_time(), 18.0)
		spins += step
		lap += step
		pivot.rotation.y += step
		_tony.rotation.y = pivot.rotation.y
		_tony.position = pivot.position
		if lap >= TAU:
			lap -= TAU
			Sfx.play("whoosh", -2.0, 0.8 + speed * 0.03)
		await get_tree().process_frame
	if _skipped:
		return
	# Let go: out over the ropes, tumbling, gone with a twinkle.
	var flung := _king.global_transform
	pivot.remove_child(_king)
	_viewport.add_child(_king)
	_king.global_transform = flung
	pivot.queue_free()
	_tony.rotation.y = 0.0
	_tony.stop()
	Sfx.play("heavy", 0.0, 0.7)
	_say(_tony, "GET LOST, YOU MOOK!", Color(1.0, 0.35, 0.3), 2.6)
	var gone := Vector3(-6.0, 7.0, 16.0)
	var fly := _king.create_tween().set_parallel()
	fly.tween_property(_king, "position", gone, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(_king, "rotation", _king.rotation + Vector3(TAU * 2.0, TAU, 0), 1.4)
	fly.tween_property(_king, "scale", Vector3.ONE * 0.2, 1.4)
	await _wait(1.4)
	_king.visible = false
	_twinkle(gone)
	await _wait(1.4)


## The mushroom man hops in with the news, and goes out the way he came,
## only higher.
func _mushroom_man() -> void:
	_mushroom.visible = true
	_mushroom.rotation.y = PI * 0.5
	var target := _tony.position + Vector3(1.4, 0, 0)
	var steps := 6
	for i in steps:
		var hop := _mushroom.create_tween()
		var to := _mushroom.position.lerp(target, 1.0 / (steps - i))
		hop.tween_property(_mushroom, "position", to + Vector3(0, 0.18, 0), 0.12)
		hop.tween_property(_mushroom, "position", to, 0.12)
		await _wait(0.25)
		if _skipped:
			return
	_mushroom.rotation.y = PI * 0.15
	_tony.rotation.y = -PI * 0.3
	_say(_mushroom, "Ayo! Ya princess? Wrong castle, pal.", Color(0.95, 0.95, 1.0), 2.8, 1.65)
	await _wait(3.0)
	if _skipped:
		return
	_say(_tony, "Get the #%^* outta here!", Color(1.0, 0.85, 0.3), 2.4)
	Sfx.play("bleep", -4.0)
	await _wait(0.9)
	_tony.play("_uppercut")
	await _wait(0.4)
	Sfx.play("heavy")
	HitFx.burst(_viewport, _mushroom.position + Vector3(0, 0.7, 0), Vector3.UP, Color(1.0, 0.85, 0.3), 16, 4.0, true, 0.05)
	var gone := _mushroom.position + Vector3(2.5, 12.0, 8.0)
	var fly := _mushroom.create_tween().set_parallel()
	fly.tween_property(_mushroom, "position", gone, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fly.tween_property(_mushroom, "rotation", Vector3(TAU * 3.0, TAU, 0), 1.2)
	fly.tween_property(_mushroom, "scale", Vector3.ONE * 0.2, 1.2)
	await _wait(1.2)
	_mushroom.visible = false
	_twinkle(gone)
	await _wait(1.2)
	_tony.play("plumber_jump")
	await _wait(1.2)


## A line over someone's head, gone after hold seconds.
func _say(who: Node3D, text: String, color: Color, hold: float, height := 2.45) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 44
	label.outline_size = 12
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.width = 900
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_viewport.add_child(label)
	label.global_position = who.global_position + Vector3(0, height, 0)
	label.scale = Vector3.ONE * 0.6
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)


## A star glinting where something left the building.
func _twinkle(at: Vector3) -> void:
	var star := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.5, 0.5, 0.05)
	mesh.material = Enemy._glow_material(Color(1.0, 0.95, 0.6))
	star.mesh = mesh
	star.rotation.z = PI / 4.0
	_viewport.add_child(star)
	star.position = at
	Sfx.play("coin", 0.0, 1.8)
	var tween := star.create_tween()
	tween.tween_property(star, "scale", Vector3.ONE * 1.8, 0.15)
	tween.tween_property(star, "scale", Vector3.ONE * 0.01, 0.35)
	tween.tween_callback(star.queue_free)


## Waits, cut short by a skip.
func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipped and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()


# --- The end card ------------------------------------------------------------------------

func _show_end() -> void:
	if _card.visible:
		return
	_earn()
	_card.visible = true
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, _card.get_index())
	for line in _end_lines():
		var label := UiTheme.title_label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.add_child(label)
	_card.add_child(_continue)
	_continue.grab_focus.call_deferred()
	Sfx.play("unlock")


func _earn() -> void:
	Achievements.earn("true_ending")
	_tony.play("plumber_jump")


## The end card: [text, size, color] lines.
func _end_lines() -> Array:
	return [["TRUE ENDING?", 64, UiTheme.GOLD], ["Princess Plum is still out there.", 24, UiTheme.TEXT]]


func _input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventJoypadButton and event.pressed)
	if not pressed or _card.visible or Time.get_ticks_msec() - _opened_at < GRACE_MS:
		return
	get_viewport().set_input_as_handled()
	_skipped = true
	_show_end()


func _finish() -> void:
	finished.emit()
	queue_free()
