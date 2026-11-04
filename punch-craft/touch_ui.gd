extends CanvasLayer
## Touch controls (autoload "TouchUi") for phones and tablets, landscape.
## Shown only while a fight is live (a Player that is active and the game
## not paused); menus use the normal touch-to-mouse emulation.
##
## - Left stick (bottom-left zone) moves, right stick (bottom-right zone)
##   looks. Both float: they appear where the thumb lands in their zone.
## - The rest of each half of the screen is that hand's punch zone:
##   tap = straight (left jab, right cross); swipe toward the midline = hook;
##   up = uppercut; away from the midline = slip; down = roll. A swipe fires
##   the moment it passes SWIPE_DISTANCE; a tap fires on release.
## - Round buttons: sprint (toggle), back step, interact, jump, dash,
##   ultimate, plus map / emote / pause across the top.
## It sends the same actions keys and pads do (move_*, look_*, jump, ...) and
## calls Player.touch_punch / touch_dodge for the gestures, so every combo
## rule stays the same.
## Turn it on: the "mobile" export feature, "--touch" on the command line, or
## "?touch" on a web page's address (to try it in a desktop browser).

const SWIPE_DISTANCE := 46.0
const TAP_DISTANCE := 26.0
const TAP_TIME := 0.32
const STICK_RADIUS := 88.0
const STICK_DEAD := 0.12
const BUTTON_RADIUS := 34.0
const SMALL_RADIUS := 25.0

## name: [action or method, column, row, radius, label]
const BUTTONS := {
	"interact": ["interact", "L", 0.18, BUTTON_RADIUS, "USE"],
	"back_step": ["back_step", "L", 0.34, BUTTON_RADIUS, "BACK"],
	"sprint": ["sprint", "L", 0.50, BUTTON_RADIUS, "RUN"],
	"ultimate": ["ultimate", "R", 0.18, BUTTON_RADIUS + 4.0, "ULT"],
	"jump": ["jump", "R", 0.34, BUTTON_RADIUS, "JUMP"],
	"dash": ["dash", "R", 0.50, BUTTON_RADIUS, "DASH"],
	"map": ["map", "T", -1.0, SMALL_RADIUS, "MAP"],
	"emote": ["emote", "T", 0.0, SMALL_RADIUS, "EMOTE"],
	"pause": ["pause", "T", 1.0, SMALL_RADIUS, "II"],
}

## True when touch controls are turned on for this run.
var enabled := false
## True while the fight controls are on screen.
var live := false

var _canvas: Control
var _player: Player
var _size := Vector2(1280, 720)
## Touch index -> {role, start, pos, t, fired, side, button}
var _touches := {}
var _move_vec := Vector2.ZERO
var _look_vec := Vector2.ZERO
var _sprint_on := false
var _held_buttons := {}


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args() or "--touch" in OS.get_cmdline_args()
	if not enabled and OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search", true)
		enabled = search is String and "touch" in search
	if not enabled:
		set_process(false)
		set_process_input(false)
		return
	# Try it with a mouse: "--touch-mouse", or "?touchmouse" on a web page.
	var search_text = JavaScriptBridge.eval("window.location.search", true) if OS.has_feature("web") else ""
	if "--touch-mouse" in OS.get_cmdline_args() or (search_text is String and "touchmouse" in search_text):
		Input.emulate_touch_from_mouse = true
	# Phones are wider than 16:9: show more world instead of black bars.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_canvas.visible = false


func _process(_delta: float) -> void:
	var player := _find_player()
	# Menus and popups pause the game, so that's the signal (a phone browser
	# can't capture the mouse, so the mouse mode says nothing there).
	var now_live := player != null and player.active and not get_tree().paused
	if now_live != live:
		live = now_live
		_canvas.visible = live
		# While fighting, touches must not also click: left click is a punch.
		Input.emulate_mouse_from_touch = not live
		if not live:
			_release_all()
	_player = player
	if not live:
		return
	_size = get_viewport().get_visible_rect().size
	_apply_sticks()
	if _sprint_on and _move_vec.length() < 0.2:
		_set_sprint(false)
	_canvas.queue_redraw()


## True when the touch layer is what you are playing with right now.
func active() -> bool:
	return enabled and live


func _find_player() -> Player:
	if is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	return get_tree().get_first_node_in_group("fight_player") as Player


# --- Layout --------------------------------------------------------------------------

func _left_zone() -> Rect2:
	return Rect2(0, _size.y * 0.5, _size.x * 0.27, _size.y * 0.5)


func _right_zone() -> Rect2:
	return Rect2(_size.x * 0.73, _size.y * 0.5, _size.x * 0.27, _size.y * 0.5)


func _button_center(id: String) -> Vector2:
	var spec: Array = BUTTONS[id]
	match spec[1]:
		"L":
			return Vector2(58.0 + 12.0, _size.y * float(spec[2]) + 60.0)
		"R":
			return Vector2(_size.x - 70.0, _size.y * float(spec[2]) + 60.0)
	# Map, emote and pause in a row at the top right, left of the ULT button.
	return Vector2(_size.x - 135.0 - (1.0 - float(spec[2])) * 60.0, 50.0)


func _button_at(pos: Vector2) -> String:
	for id in BUTTONS:
		if pos.distance_to(_button_center(id)) <= float(BUTTONS[id][3]) + 10.0:
			return id
	return ""


# --- Input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not live:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index, event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
		get_viewport().set_input_as_handled()


func _touch_down(index: int, pos: Vector2) -> void:
	var touch := {"start": pos, "pos": pos, "t": Time.get_ticks_msec() / 1000.0, "fired": false,
			"role": "punch", "side": "left" if pos.x < _size.x * 0.5 else "right"}
	var button := _button_at(pos)
	if button != "":
		touch.role = "button"
		touch.button = button
		_press_button(button)
	elif _left_zone().has_point(pos) and not _has_role("move"):
		touch.role = "move"
	elif _right_zone().has_point(pos) and not _has_role("look"):
		touch.role = "look"
	_touches[index] = touch


func _touch_move(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	touch.pos = pos
	if touch.role == "punch" and not touch.fired:
		var delta: Vector2 = pos - touch.start
		if delta.length() >= SWIPE_DISTANCE:
			touch.fired = true
			_swipe(touch.side, delta)


func _touch_up(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	_touches.erase(index)
	match touch.role:
		"punch":
			var held: float = Time.get_ticks_msec() / 1000.0 - float(touch.t)
			if not touch.fired and pos.distance_to(touch.start) <= TAP_DISTANCE and held <= TAP_TIME:
				_punch(touch.side, "jab" if touch.side == "left" else "cross")
		"button":
			_release_button(touch.button)


func _has_role(role: String) -> bool:
	for touch in _touches.values():
		if touch.role == role:
			return true
	return false


## Which way a swipe went, from the hand's point of view.
static func swipe_kind(side: String, delta: Vector2) -> String:
	if absf(delta.x) > absf(delta.y):
		var toward_middle := delta.x > 0.0 if side == "left" else delta.x < 0.0
		return "hook" if toward_middle else "slip"
	return "uppercut" if delta.y < 0.0 else "roll"


func _swipe(side: String, delta: Vector2) -> void:
	var kind := swipe_kind(side, delta)
	if kind == "hook" or kind == "uppercut":
		_punch(side, kind)
	elif _player:
		_player.touch_dodge(side, kind)


func _punch(side: String, type: String) -> void:
	if _player:
		_player.touch_punch(side, type)


# --- Sticks --------------------------------------------------------------------------

func _stick_vector(role: String) -> Vector2:
	for touch in _touches.values():
		if touch.role == role:
			var v: Vector2 = (touch.pos - touch.start) / STICK_RADIUS
			if v.length() > 1.0:
				v = v.normalized()
				# The base follows the thumb so a long drag keeps working.
				touch.start = touch.pos - v * STICK_RADIUS
			return v
	return Vector2.ZERO


func _apply_sticks() -> void:
	_move_vec = _stick_vector("move")
	_look_vec = _stick_vector("look")
	_set_axes("move_left", "move_right", "move_forward", "move_back", _move_vec)
	_set_axes("look_left", "look_right", "look_up", "look_down", _look_vec)


func _set_axes(left: String, right: String, up: String, down: String, v: Vector2) -> void:
	if v.length() < STICK_DEAD:
		v = Vector2.ZERO
	_strength(left, maxf(-v.x, 0.0))
	_strength(right, maxf(v.x, 0.0))
	_strength(up, maxf(-v.y, 0.0))
	_strength(down, maxf(v.y, 0.0))


func _strength(action: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(action, value)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


# --- Buttons -------------------------------------------------------------------------

func _press_button(id: String) -> void:
	match id:
		"sprint":
			_set_sprint(not _sprint_on)
		"back_step":
			if _player:
				_player.touch_move("back_step")
		"dash":
			if _player:
				_player.touch_move("forward_dash")
		"jump", "ultimate", "interact", "map", "pause", "emote":
			_held_buttons[id] = true
			_send_action(BUTTONS[id][0], true)


func _release_button(id: String) -> void:
	if _held_buttons.has(id):
		_held_buttons.erase(id)
		_send_action(BUTTONS[id][0], false)


func _set_sprint(on: bool) -> void:
	_sprint_on = on
	if on:
		Input.action_press("sprint")
	elif Input.is_action_pressed("sprint"):
		Input.action_release("sprint")


## A real action event, so nodes listening in _unhandled_input hear it too.
func _send_action(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_all() -> void:
	for index in _touches.keys():
		var touch: Dictionary = _touches[index]
		if touch.role == "button":
			_release_button(touch.button)
	_touches.clear()
	_set_sprint(false)
	for id in _held_buttons.keys():
		_release_button(id)
	for action in ["move_left", "move_right", "move_forward", "move_back",
			"look_left", "look_right", "look_up", "look_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- Drawing -------------------------------------------------------------------------

func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	_draw_stick("move", _left_zone(), "MOVE")
	_draw_stick("look", _right_zone(), "LOOK")
	for id in BUTTONS:
		var center := _button_center(id)
		var radius: float = BUTTONS[id][3]
		var pressed: bool = _held_buttons.has(id) or (id == "sprint" and _sprint_on)
		for touch in _touches.values():
			if touch.role == "button" and touch.button == id:
				pressed = true
		_canvas.draw_circle(center, radius, Color(1, 1, 1, 0.30 if pressed else 0.12))
		_canvas.draw_arc(center, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 2.0)
		var label: String = BUTTONS[id][4]
		var fs := 13 if radius > 30.0 else 10
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		_canvas.draw_string(font, center + Vector2(-width * 0.5, fs * 0.35), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	for touch in _touches.values():
		if touch.role == "punch":
			_canvas.draw_circle(touch.pos, 18.0, Color(1, 0.8, 0.4, 0.25))


func _draw_stick(role: String, zone: Rect2, label: String) -> void:
	var base := zone.position + zone.size * Vector2(0.5, 0.58)
	var knob_offset := Vector2.ZERO
	for touch in _touches.values():
		if touch.role == role:
			base = touch.start
			knob_offset = (touch.pos - touch.start).limit_length(STICK_RADIUS)
	var idle := knob_offset == Vector2.ZERO
	_canvas.draw_circle(base, STICK_RADIUS, Color(1, 1, 1, 0.05 if idle else 0.09))
	_canvas.draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.22 if idle else 0.45), 2.0)
	_canvas.draw_circle(base + knob_offset, 34.0, Color(1, 1, 1, 0.16 if idle else 0.38))
	if idle:
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		_canvas.draw_string(font, base + Vector2(-width * 0.5, 4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))
