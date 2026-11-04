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
## Finger drag (px) that points the emote wheel all the way; short, because the
## EMOTE button sits near the top edge and there's little room to drag up.
const WHEEL_DRAG := 38.0
## A quick flick that began in a stick zone still counts as a punch swipe.
const FLICK_TIME := 0.22

## Big square buttons along the bottom (dash, run, back step): half a side.
const SQUARE_HALF := 42.0
## Gap between buttons.
const GAP := 12.0

## id: [action or method, label, shape ("c" circle, "s" square), radius or half side, arrow]
const BUTTONS := {
	"interact": ["interact", "USE", "c", BUTTON_RADIUS, ""],
	"ultimate": ["ultimate", "ULT", "star", BUTTON_RADIUS + 12.0, ""],
	"jump": ["jump", "JUMP", "s", BUTTON_RADIUS, ""],
	"dash": ["dash", "DASH", "s", SQUARE_HALF, "up"],
	"sprint": ["sprint", "RUN", "s", SQUARE_HALF, "up2"],
	"back_step": ["back_step", "BACK", "s", SQUARE_HALF, "down"],
	"lock": ["lock_cycle", "LOCK", "c", SMALL_RADIUS, ""],
	"map": ["map", "MAP", "c", SMALL_RADIUS, ""],
	"emote": ["emote", "EMOTE", "c", SMALL_RADIUS, ""],
	"pause": ["pause", "II", "c", SMALL_RADIUS, ""],
}
## Where the small buttons sit in the top row (steps left of PAUSE).
const TOP_STEP := {"pause": 0, "emote": 1, "lock": 2, "map": 3}

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
## While EMOTE is held: where the finger has dragged, up to length 1 (the wheel).
var wheel_vec := Vector2.ZERO
## Desktop test mode ("?touchmouse"): the engine's own emulation is used instead.
var _mouse_test := false
## The finger acting as the mouse in menus (-1: none), and where it last was.
var _menu_finger := -1
var _menu_pos := Vector2.ZERO
var _menu_start := Vector2.ZERO
var _menu_dragging := false
var _menu_cancelled := false
var _menu_scroll: ScrollContainer
var _fingers := {}
var _pinch_gap := 0.0
## Recent finger paths for the punch trails: [{pts, age}] once a finger lifts.
var _fading: Array = []
var _box := StyleBoxFlat.new()
const TRAIL_FADE := 0.3
const TRAIL_POINTS := 22


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
		_mouse_test = true
	else:
		# Menus get their taps from _menu_touch, never from the engine's emulation.
		Input.emulate_mouse_from_touch = false
	# Phones are wider than 16:9: show more world instead of black bars.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)
	_canvas.visible = false


func _process(delta: float) -> void:
	# A phone has no pointer to capture; menus (and the HUD's resume) would
	# otherwise leave the mouse "captured", which eats taps.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _find_player()
	# Menus and popups pause the game, so that's the signal (a phone browser
	# can't capture the mouse, so the mouse mode says nothing there).
	var now_live := player != null and player.active and not get_tree().paused
	if now_live != live:
		live = now_live
		_canvas.visible = live
		# While fighting, touches must not also click: left click is a punch.
		if _mouse_test:
			Input.emulate_mouse_from_touch = not live
		if _menu_finger != -1:
			_send_pointer(_menu_pos, 0, false, true)  # Don't leave a press hanging.
			_menu_finger = -1
		_fingers.clear()
		if not live:
			_release_all()
		elif _sprint_on:
			Input.action_press("sprint")  # RUN stays on across pauses.
	_player = player
	if not live:
		return
	_size = get_viewport().get_visible_rect().size
	_apply_sticks()
	for fade in _fading:
		fade.age += delta
	_fading = _fading.filter(func(f: Dictionary) -> bool: return f.age < TRAIL_FADE)
	_canvas.queue_redraw()


## True when the touch layer is what you are playing with right now.
func active() -> bool:
	return enabled and live


func _find_player() -> Player:
	if is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	return get_tree().get_first_node_in_group("fight_player") as Player


# --- Layout --------------------------------------------------------------------------

## Settings: button size, and the left-handed layout (mirrored).
func _scale() -> float:
	return float(Settings.get_value("touch_scale"))


func _swapped() -> bool:
	return bool(Settings.get_value("touch_swap"))


## The corner zone where a stick starts: "move" is the left one, "look" the
## right one (the other way round when left-handed).
func _zone(role: String) -> Rect2:
	var left_side := (role == "move") != _swapped()
	# Small and low: a punch gesture that begins higher up or further in must
	# not turn into a stick.
	var width := _size.x * 0.22
	return Rect2(0 if left_side else _size.x - width, _size.y * 0.64, width, _size.y * 0.36)


## Half the button's size (radius for circles, half a side for squares).
func _half(id: String) -> float:
	return float(BUTTONS[id][3]) * _scale()


## Layout: the right thumb's side has ULT and JUMP stacked over a bottom row of
## big squares (DASH nearest the edge, RUN beside it, BACK beyond); USE sits
## on the left above the move stick; the small buttons run along the top.
func _button_center(id: String) -> Vector2:
	var s := _scale()
	var sq := SQUARE_HALF * s
	var edge := 26.0 + sq
	var bottom_y := _size.y * 0.64 - 14.0 - sq  # Just above the stick zones.
	var jump_y := bottom_y - sq - GAP - BUTTON_RADIUS * s
	var ult_r := _half("ultimate")
	var p := Vector2.ZERO  # Distance from the right edge, y.
	match id:
		"dash":
			p = Vector2(edge, bottom_y)
		"sprint":
			p = Vector2(edge + sq * 2.0 + GAP, bottom_y)
		"back_step":
			p = Vector2(edge + (sq * 2.0 + GAP) * 2.0, bottom_y)
		"jump":
			p = Vector2(edge, jump_y)
		"ultimate":
			p = Vector2(edge + BUTTON_RADIUS * s + GAP + ult_r, jump_y - 8.0)
		"interact":
			# Left side, above the move stick (so the mirror puts it on the right).
			return _mirror_x(Vector2(26.0 + BUTTON_RADIUS * s, jump_y), true)
		_:
			# Small buttons along the top right, left of the coin counter.
			var step: int = TOP_STEP[id]
			return Vector2(_size.x - 150.0 - step * (SMALL_RADIUS * s * 2.0 + 12.0), 64.0)
	return _mirror_x(Vector2(_size.x - p.x, p.y), false)


## Left-handed layout: everything flips sideways.
func _mirror_x(pos: Vector2, _left_side: bool) -> Vector2:
	if _swapped():
		pos.x = _size.x - pos.x
	return pos


## LOCK only shows when the lock-on camera is on.
func _button_shown(id: String) -> bool:
	if id == "lock":
		return _player != null and _player.lock != null and _player.lock.level() != "off"
	if id == "map":
		return _map_label() != ""
	return true


## MAP opens the Crypt map when there is one; in the Practice ring the same
## button steps the dummy up a level (and skips the tutorial), so it's NEXT
## there. Nowhere else it does anything, so it hides.
## The MAP button's name in hints.
func map_name() -> String:
	var label := _map_label()
	return label if label != "" else "MAP"


func _map_label() -> String:
	if not get_tree().get_nodes_in_group("map_scene").is_empty():
		return "MAP"
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.contains("training"):
		return "NEXT"
	return ""


## Locked onto an enemy: the view follows it, so the look stick goes away and
## the whole screen is punch zones.
func _combat() -> bool:
	return _player != null and _player.lock != null and _player.lock.in_combat()


func _button_at(pos: Vector2) -> String:
	for id in BUTTONS:
		if not _button_shown(id):
			continue
		var offset: Vector2 = (pos - _button_center(id)).abs()
		var reach := _half(id) + 8.0
		if BUTTONS[id][2] == "s":
			if maxf(offset.x, offset.y) <= reach:
				return id
		elif offset.length() <= reach + 2.0:
			return id
	return ""


# --- Input ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not live:
		if not _mouse_test:
			_menu_touch(event)
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


## Menus, pause screens and popups: the first finger acts as the mouse. A move
## to the spot comes first so buttons see the pointer arrive, then press and
## release. Sent straight to the viewport in its own coordinates, so it never
## depends on the engine's touch-to-mouse conversion (which flips with the
## fight controls and could be left in the wrong state).
##
## Dragging scrolls whatever scrollable list is under the finger (even over
## cards, which would swallow the drag), unless it began on a slider or the
## like; that drag goes on as a mouse drag (the upgrade web pans with it).
## Two fingers pinch: spreading zooms in, squeezing zooms out (mouse wheel).
func _menu_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = event.position
			if _menu_finger == -1:
				_menu_finger = event.index
				_menu_pos = event.position
				_menu_start = event.position
				_menu_dragging = false
				_menu_cancelled = false
				_send_pointer(event.position, 0, true, false)
				_send_pointer(event.position, 0, true, true)
			else:
				_cancel_click()
				_pinch_gap = _finger_gap()
		else:
			_fingers.erase(event.index)
			if event.index == _menu_finger:
				_menu_finger = -1
				if not _menu_cancelled:
					_send_pointer(event.position, 0, false, true)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_fingers[event.index] = event.position
		if _fingers.size() >= 2:
			_pinch()
		elif event.index == _menu_finger and not _menu_cancelled:
			var rel: Vector2 = event.position - _menu_pos
			_menu_pos = event.position
			if not _menu_dragging and event.position.distance_to(_menu_start) > 12.0:
				_menu_dragging = true
				_menu_scroll = _scroll_under()
				if _menu_scroll != null:
					_cancel_click()
					return
			if _menu_scroll != null and is_instance_valid(_menu_scroll):
				_menu_scroll.scroll_vertical -= int(roundf(rel.y))
				_menu_scroll.scroll_horizontal -= int(roundf(rel.x))
			else:
				_send_pointer(event.position, 1, true, false, rel)
		elif event.index == _menu_finger and _menu_scroll != null and is_instance_valid(_menu_scroll):
			var rel2: Vector2 = event.position - _menu_pos
			_menu_pos = event.position
			_menu_scroll.scroll_vertical -= int(roundf(rel2.y))
			_menu_scroll.scroll_horizontal -= int(roundf(rel2.x))


## The scrollable list under the finger, unless the drag began on a slider.
func _scroll_under() -> ScrollContainer:
	var node: Node = get_viewport().gui_get_hovered_control()
	if node is Range or node is TextEdit or node is LineEdit:
		return null
	while node != null:
		if node is ScrollContainer and node.is_visible_in_tree():
			return node
		node = node.get_parent()
	return null


## Stops the press from counting as a click (a drag or pinch is under way).
func _cancel_click() -> void:
	if _menu_cancelled:
		return
	_menu_cancelled = true
	_send_pointer(Vector2(-900, -900), 0, false, true)


func _finger_gap() -> float:
	var points: Array = _fingers.values()
	return (points[0] as Vector2).distance_to(points[1]) if points.size() >= 2 else 0.0


func _pinch() -> void:
	_cancel_click()
	var gap := _finger_gap()
	if absf(gap - _pinch_gap) < 28.0:
		return
	var points: Array = _fingers.values()
	var middle: Vector2 = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
	var wheel := MOUSE_BUTTON_WHEEL_UP if gap > _pinch_gap else MOUSE_BUTTON_WHEEL_DOWN
	_pinch_gap = gap
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = wheel
		ev.pressed = pressed
		ev.factor = 1.0
		ev.position = middle
		ev.global_position = middle
		get_viewport().push_input(ev, true)


## kind 0: a mouse move (button == false) or a left button (button == true);
## kind 1: a move while the button is down.
func _send_pointer(pos: Vector2, kind: int, down: bool, button: bool, rel := Vector2.ZERO) -> void:
	var ev: InputEvent
	if button:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = down
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		ev = click
	else:
		var move := InputEventMouseMotion.new()
		move.relative = rel
		move.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == 1 else 0
		ev = move
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)


func _touch_down(index: int, pos: Vector2) -> void:
	var touch := {"start": pos, "origin": pos, "pos": pos, "t": Time.get_ticks_msec() / 1000.0, "fired": false,
			"role": "punch", "side": "left" if pos.x < _size.x * 0.5 else "right", "trail": [pos]}
	var button := _button_at(pos)
	if button != "":
		touch.role = "button"
		touch.button = button
		_press_button(button)
	elif _zone("move").has_point(pos) and not _has_role("move"):
		touch.role = "move"
	elif _zone("look").has_point(pos) and not _has_role("look"):
		touch.role = "look"
	_touches[index] = touch


func _touch_move(index: int, pos: Vector2) -> void:
	if not _touches.has(index):
		return
	var touch: Dictionary = _touches[index]
	touch.pos = pos
	if touch.role == "punch":
		touch.trail.append(pos)
		if touch.trail.size() > TRAIL_POINTS:
			touch.trail.pop_front()
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
	if touch.role == "punch":
		_fading.append({"pts": touch.trail, "age": 0.0})
	match touch.role:
		"punch":
			var held: float = Time.get_ticks_msec() / 1000.0 - float(touch.t)
			if not touch.fired and pos.distance_to(touch.start) <= TAP_DISTANCE and held <= TAP_TIME:
				_punch(touch.side, "jab" if touch.side == "left" else "cross")
		"button":
			_release_button(touch.button)
		"move", "look":
			# A quick flick that started on a stick still throws the punch.
			var flick: Vector2 = pos - touch.origin
			var quick: float = Time.get_ticks_msec() / 1000.0 - float(touch.t)
			if quick <= FLICK_TIME and flick.length() >= SWIPE_DISTANCE:
				_swipe(touch.side, flick)


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
			var radius := STICK_RADIUS * _scale()
			var v: Vector2 = (touch.pos - touch.start) / radius
			if v.length() > 1.0:
				v = v.normalized()
				# The base follows the thumb so a long drag keeps working.
				touch.start = touch.pos - v * radius
			return v
	return Vector2.ZERO


func _apply_sticks() -> void:
	_move_vec = _stick_vector("move")
	_look_vec = _stick_vector("look")
	if Settings.get_value("invert_y"):
		_look_vec.y = -_look_vec.y
	wheel_vec = _emote_drag()
	_set_axes("move_left", "move_right", "move_forward", "move_back", _move_vec)
	_set_axes("look_left", "look_right", "look_up", "look_down", _look_vec)


## The finger on the EMOTE button, dragged: the wheel points where it went.
func _emote_drag() -> Vector2:
	for touch in _touches.values():
		if touch.role == "button" and touch.button == "emote":
			return ((touch.pos - touch.start) / (WHEEL_DRAG * _scale())).limit_length(1.0)
	return Vector2.ZERO


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
		"lock":
			if _player:
				_player.lock.cycle()
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
	if Input.is_action_pressed("sprint"):
		Input.action_release("sprint")  # RUN itself stays toggled (_sprint_on).
	for id in _held_buttons.keys():
		_release_button(id)
	for action in ["move_left", "move_right", "move_forward", "move_back",
			"look_left", "look_right", "look_up", "look_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- Drawing -------------------------------------------------------------------------

func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	var color := GameState.fighter_color()
	_canvas.modulate = Color(1, 1, 1, float(Settings.get_value("touch_opacity")))
	_draw_stick("move", _zone("move"), "MOVE", color, false)
	_draw_stick("look", _zone("look"), "LOOK" if not _combat() else "UP / DOWN", color, _combat())
	for id in BUTTONS:
		if not _button_shown(id):
			continue
		var pressed: bool = _held_buttons.has(id) or (id == "sprint" and _sprint_on) or (id == "lock" and _combat())
		for touch in _touches.values():
			if touch.role == "button" and touch.button == id:
				pressed = true
		_draw_button(id, pressed, color, font)
	_draw_trails(color)


func _draw_button(id: String, pressed: bool, color: Color, font: Font) -> void:
	var spec: Array = BUTTONS[id]
	var center := _button_center(id)
	var half := _half(id)
	var fill := color.darkened(0.7)
	fill.a = 0.5
	var edge := color.lightened(0.2)
	edge.a = 0.9
	if pressed:
		fill = color
		fill.a = 0.62
		edge = color.lightened(0.55)
		edge.a = 1.0
	if spec[2] == "star":
		var ready := _player != null and _player.ult != null and _player.ult.is_full()
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		if ready:
			# A glow: soft stars growing outward, breathing.
			for i in 4:
				var halo := color.lightened(0.4)
				halo.a = (0.16 - i * 0.03) * (0.6 + 0.8 * pulse)
				_canvas.draw_colored_polygon(_star(center, half * (1.18 + i * 0.1), 12), halo)
			fill = color
			fill.a = 0.75
			edge = Color(1, 0.95, 0.7, 1.0)
		var outline := _star(center, half, 12)
		_canvas.draw_colored_polygon(outline, fill)
		outline.append(outline[0])
		_canvas.draw_polyline(outline, edge, 3.0, true)
	elif spec[2] == "s":
		_box.bg_color = fill
		_box.border_color = edge
		_box.set_border_width_all(3)
		_box.set_corner_radius_all(int(half * 0.35))
		_canvas.draw_style_box(_box, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0))
	else:
		_canvas.draw_circle(center, half, fill)
		_canvas.draw_arc(center, half, 0.0, TAU, 40, edge, 3.0, true)
	var ink := Color(1, 1, 1, 0.95)
	var label: String = spec[1]
	if id == "map":
		label = _map_label()
	var arrow: String = spec[4]
	if arrow != "":
		var unit := half * 0.34
		var up := arrow != "down"
		var rows: Array = [-unit * 0.15, unit * 0.9] if arrow == "up2" else [unit * 0.1]
		for y in rows:
			var tip := Vector2(0, (-unit if up else unit) * 0.6)
			var pts := PackedVector2Array([Vector2(-unit, -tip.y * 0.1 + (unit * 0.6 if up else -unit * 0.6)) + Vector2(0, y - unit * 0.55),
					tip + Vector2(0, y - unit * 0.55), Vector2(unit, (unit * 0.6 if up else -unit * 0.6)) + Vector2(0, y - unit * 0.55)])
			for i in pts.size():
				pts[i] += center + Vector2(0, -half * 0.12)
			_canvas.draw_polyline(pts, ink, maxf(4.0, half * 0.1), true)
		var small := 11
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, small).x
		_canvas.draw_string(font, center + Vector2(-width * 0.5, half * 0.78), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1, 1, 1, 0.75))
	elif id == "pause":
		var bar := Vector2(5, half * 0.7)
		_canvas.draw_rect(Rect2(center + Vector2(-8, -bar.y * 0.5), bar), ink)
		_canvas.draw_rect(Rect2(center + Vector2(3, -bar.y * 0.5), bar), ink)
	else:
		var fs := 15 if half > 30.0 else 11
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		_canvas.draw_string(font, center + Vector2(-width * 0.5, fs * 0.36), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## The punch fingers: a glow in your fighter's colour with a fading trail, and
## the trails of fingers that just lifted.
## A star with this many points (outer radius, inner about 0.74 of it).
func _star(center: Vector2, radius: float, points: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := radius if i % 2 == 0 else radius * 0.74
		var a := -PI * 0.5 + PI * float(i) / float(points)
		out.append(center + Vector2(cos(a), sin(a)) * r)
	return out


func _draw_trails(color: Color) -> void:
	for touch in _touches.values():
		if touch.role == "punch":
			_trail(touch.trail, color, 1.0)
			var glow := color.lightened(0.25)
			glow.a = 0.42
			_canvas.draw_circle(touch.pos, 24.0, glow)
			glow.a = 0.9
			_canvas.draw_arc(touch.pos, 24.0, 0.0, TAU, 28, glow, 2.5, true)
	for fade in _fading:
		_trail(fade.pts, color, 1.0 - float(fade.age) / TRAIL_FADE)


func _trail(points: Array, color: Color, strength: float) -> void:
	var n := points.size()
	for i in range(1, n):
		var k := float(i) / float(n)
		var c := color.lightened(0.35)
		c.a = k * 0.8 * strength
		_canvas.draw_line(points[i - 1], points[i], c, 3.0 + 14.0 * k, true)


func _draw_stick(role: String, zone: Rect2, label: String, color: Color, dim := false) -> void:
	var base := zone.position + zone.size * Vector2(0.5, 0.58)
	var knob_offset := Vector2.ZERO
	for touch in _touches.values():
		if touch.role == role:
			base = touch.start
			knob_offset = (touch.pos - touch.start).limit_length(STICK_RADIUS * _scale())
	var idle := knob_offset == Vector2.ZERO
	var radius := STICK_RADIUS * _scale()
	if dim:
		# Locked on: only up and down work, so it greys out.
		color = color.lerp(Color(0.6, 0.6, 0.65), 0.75)
	var ring := color.lightened(0.2)
	var well := color.darkened(0.7)
	well.a = 0.18 if idle else 0.3
	ring.a = 0.4 if idle else 0.85
	_canvas.draw_circle(base, radius, well)
	_canvas.draw_arc(base, radius, 0.0, TAU, 48, ring, 3.0, true)
	var knob := color
	knob.a = 0.35 if idle else 0.8
	_canvas.draw_circle(base + knob_offset, 34.0 * _scale(), knob)
	ring.a = 0.8 if not idle else 0.5
	_canvas.draw_arc(base + knob_offset, 34.0 * _scale(), 0.0, TAU, 28, ring, 2.0, true)
	if idle:
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		_canvas.draw_string(font, base + Vector2(-width * 0.5, 4), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
