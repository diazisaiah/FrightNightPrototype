class_name Tutorial
extends CanvasLayer
## Freeze-frame mini tutorials. The screen dims except for a spotlight on one
## thing (a spot in the world, like a hat on a monster, or a button) and a card
## explains it. Two kinds:
##   - a card with "Got it": the game pauses until you press it;
##   - a pointer (until is set): no button, only the spotlit control can be
##     clicked, and it closes once until() is true (e.g. "press Select").
## Each plays once per save (GameState.tips_seen), and only one per scene, so
## a round is never interrupted twice (follow-ups in a chain pass chain = true).

signal finished

const SHADE := Color(0, 0, 0, 0.66)
const CARD_WIDTH := 440.0

static var _active: Tutorial
## The scene that last showed a tip: one per round.
static var _scene_id := 0

var _target: Object
var _until: Callable
var _pause := true
var _was_paused := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _shades: Array[ColorRect] = []
var _frame: Panel
var _card: PanelContainer
var _time := 0.0
var _title := ""
var _body := ""
var _button := ""


static func seen(id: String) -> bool:
	return GameState.tips_seen.has(id)


## Shows a tip once per save. target: a Node3D (spotlit on screen) or a
## Control (framed), or null for none. until: for a pointer, closes when it
## returns true. pause: freeze the game while it's up (cards; pointers in
## menus pass false so the menu still works). Returns null if it won't show.
static func open(host: Node, id: String, title: String, body: String, target: Object = null, until := Callable(),
		pause := true, chain := false) -> Tutorial:
	if seen(id) or _active != null or host == null or not host.is_inside_tree():
		return null
	var scene := host.get_tree().current_scene
	if scene and scene.get_instance_id() == _scene_id and not chain:
		return null
	GameState.mark_tip(id)
	_scene_id = scene.get_instance_id() if scene else 0
	var tip := Tutorial.new()
	tip._title = title
	tip._body = body
	tip._target = target
	tip._until = until
	tip._pause = pause and not until.is_valid()
	tip._button = "" if until.is_valid() else "Got it"
	tip.layer = 96
	tip.process_mode = Node.PROCESS_MODE_ALWAYS
	_active = tip
	(scene if scene else host.get_tree().root).add_child(tip)
	return tip


func _ready() -> void:
	_was_paused = get_tree().paused
	_mouse_mode = Input.mouse_mode
	if _pause:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 4:
		var shade := ColorRect.new()
		shade.color = SHADE
		shade.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(shade)
		_shades.append(shade)
	_frame = Panel.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0), UiTheme.GOLD, 3, 12))
	add_child(_frame)
	_build_card()
	Sfx.play("tell", -4.0, 1.2)
	_layout()


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiTheme.raised(Color(UiTheme.PANEL, 0.97), UiTheme.GOLD, 2, 12, 20.0))
	_card.custom_minimum_size.x = CARD_WIDTH
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_card.add_child(column)
	column.add_child(UiTheme.title_label(_title, 28, UiTheme.GOLD))
	var body := Label.new()
	body.text = _body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = CARD_WIDTH - 40.0
	body.add_theme_font_size_override("font_size", 17)
	column.add_child(body)
	if _button != "":
		var button := Button.new()
		button.text = _button
		button.theme_type_variation = "PrimaryButton"
		button.custom_minimum_size = Vector2(160, 46)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.pressed.connect(close)
		column.add_child(button)
		button.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	# Pause and Esc mustn't reach the game underneath a frozen card.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_time += delta
	_layout()
	if _until.is_valid() and _until.call():
		close()


## The spotlight: where the target is on screen right now.
func _spot() -> Rect2:
	if _target == null or not is_instance_valid(_target):
		return Rect2()
	if _target is Control:
		var control := _target as Control
		return control.get_global_rect().grow(8.0) if control.is_visible_in_tree() else Rect2()
	if _target is Node3D:
		var camera := get_viewport().get_camera_3d()
		var at: Vector3 = (_target as Node3D).global_position
		if camera == null or camera.is_position_behind(at):
			return Rect2()
		var center := camera.unproject_position(at)
		var radius := clampf(260.0 / maxf(camera.global_position.distance_to(at), 1.0), 50.0, 140.0)
		return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return Rect2()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var hole := _spot()
	if hole.size == Vector2.ZERO:
		hole = Rect2(screen / 2.0, Vector2.ZERO)
	hole = hole.intersection(Rect2(Vector2.ZERO, screen)) if hole.size != Vector2.ZERO else hole
	_set_rect(_shades[0], Rect2(0, 0, screen.x, hole.position.y))
	_set_rect(_shades[1], Rect2(0, hole.end.y, screen.x, screen.y - hole.end.y))
	_set_rect(_shades[2], Rect2(0, hole.position.y, hole.position.x, hole.size.y))
	_set_rect(_shades[3], Rect2(hole.end.x, hole.position.y, screen.x - hole.end.x, hole.size.y))
	_frame.visible = hole.size != Vector2.ZERO
	_set_rect(_frame, hole)
	_frame.modulate.a = 0.6 + 0.4 * sin(_time * 5.0)
	# The card sits below the spotlight, or above it when there's no room.
	var card_size := _card.get_combined_minimum_size()
	var x := clampf(hole.get_center().x - card_size.x / 2.0, 16.0, screen.x - card_size.x - 16.0)
	var y := hole.end.y + 18.0
	if y + card_size.y > screen.y - 16.0:
		y = hole.position.y - card_size.y - 18.0
	if hole.size == Vector2.ZERO:
		y = screen.y / 2.0 - card_size.y / 2.0
	_card.position = Vector2(x, clampf(y, 16.0, screen.y - card_size.y - 16.0))


func _set_rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = Vector2(maxf(rect.size.x, 0.0), maxf(rect.size.y, 0.0))


func close() -> void:
	if _active == self:
		_active = null
	if _pause:
		get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	finished.emit()
	queue_free()
