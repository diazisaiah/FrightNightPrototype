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
## - Both thumbs swiping down at once: back step; both up at once: dash
##   (2026-11-05, the DASH and BACK buttons went: they covered the screen and
##   the tutorial).
## - Hold a finger still in a punch zone: use (doors, chests, stairs).
## - RUN (toggle) and JUMP sit beside the sticks, on their inner sides. The
##   HUD's ultimate gauge is the ultimate's button: tap it (it blazes and says
##   TAP! when charged). Map / emote / pause / lock across the top.
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

## The square buttons beside the sticks (RUN, JUMP): half a side.
const SQUARE_HALF := 36.0
## A finger held this still this long in a punch zone uses (interact).
const HOLD_TIME := 0.45
## Gap between buttons.
const GAP := 12.0

## id: [action or method, label, shape ("c" circle, "s" square), radius or half side, arrow]
const BUTTONS := {
	# The HUD's gauge is this one's button (_ult_rect); nothing drawn here.
	"ultimate": ["ultimate", "ULT", "hud", 0.0, ""],
	"jump": ["jump", "JUMP", "s", SQUARE_HALF, ""],
	"sprint": ["sprint", "RUN", "s", SQUARE_HALF, "up2"],
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
## Where the passive chip and power tiles sit on touch: "ult" (under the
## ultimate bar) or "health" (under the health bar). "?hud=health" to try it.
var hud_layout := "ult"
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
## A down (or up) swipe waiting to see if the other thumb joins: both thumbs
## down is the back step, both up the dash; alone it's a roll (uppercut).
var _pending_down := ""
var _pending_down_t := 0.0
var _pending_up := ""
var _pending_up_t := 0.0
const BACK_STEP_WINDOW := 0.07
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
	if OS.has_feature("web"):
		var query = JavaScriptBridge.eval("window.location.search", true)
		if query is String and "hud=health" in query:
			hud_layout = "health"
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
		if live:
			_show_gesture_tip()
		if not live:
			_release_all()
		elif _sprint_on:
			Input.action_press("sprint")  # RUN stays on across pauses.
	_player = player
	if not live:
		return
	_size = get_viewport().get_visible_rect().size
	_apply_sticks()
	var now := Time.get_ticks_msec() / 1000.0
	if _pending_down != "" and now - _pending_down_t > BACK_STEP_WINDOW:
		if _player:
			_player.touch_dodge(_pending_down, "roll")
		_pending_down = ""
	if _pending_up != "" and now - _pending_up_t > BACK_STEP_WINDOW:
		_punch(_pending_up, "uppercut")
		_pending_up = ""
	_check_holds(now)
	for fade in _fading:
		fade.age += delta
	_fading = _fading.filter(func(f: Dictionary) -> bool: return f.age < TRAIL_FADE)
	_canvas.queue_redraw()


## The first few fights: a reminder of the gestures that replaced buttons.
func _show_gesture_tip() -> void:
	var shown := int(Settings.get_value("touch_tips_shown"))
	if shown >= 3:
		return
	Settings.set_value("touch_tips_shown", shown + 1)
	Toast.show_on(get_tree(), "TOUCH MOVES", "Double swipe up: dash   ·   Double swipe down: back step\nHold a finger still: use   ·   Tap the ULT bar when it glows")


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


## The HUD's ultimate gauge on screen (a little padded), or an empty rect.
func _ult_rect() -> Rect2:
	var gauge := get_tree().get_first_node_in_group("ult_gauge") as Control
	if gauge == null or not gauge.is_visible_in_tree():
		return Rect2()
	return gauge.get_global_rect().grow(10.0)


## Layout (2026-11-05): RUN just inside the move stick, JUMP just inside the
## look stick, both level with the sticks; the small buttons along the top;
## the HUD's ultimate gauge is the ultimate. The rest is punch zones.
func _button_center(id: String) -> Vector2:
	var s := _scale()
	var sq := SQUARE_HALF * s
	var stick_y := _size.y * (0.64 + 0.36 * 0.58)
	var inner := _size.x * 0.22 + GAP + sq
	match id:
		"sprint":
			return _mirror_x(Vector2(inner, stick_y), true)
		"jump":
			return _mirror_x(Vector2(_size.x - inner, stick_y), false)
		"ultimate":
			return _ult_rect().get_center()
	# Small buttons along the top right, left of the coin counter.
	var slot: int = TOP_STEP[id]
	return Vector2(_size.x - 150.0 - slot * (SMALL_RADIUS * s * 2.0 + 12.0), 64.0)


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
		if BUTTONS[id][2] == "hud":
			if _ult_rect().has_point(pos):
				return id
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
	var touch := {"start": pos, "origin": pos, "pos": pos, "t": Time.get_ticks_msec() / 1000.0, "fired": false, "use": false,
			"role": "punch", "side": "left" if pos.x < _size.x * 0.5 else "right", "trail": [pos]}
	var button := _button_at(pos)
	if button != "":
		touch.role = "button"
		touch.button = button
		_press_button(button)
	elif _zone("move").has_point(pos):
		# A stick zone never throws a punch or dodge; a second finger there does nothing.
		touch.role = "move" if not _has_role("move") else "none"
	elif _zone("look").has_point(pos):
		touch.role = "look" if not _has_role("look") else "none"
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
	if touch.use:
		_send_action("interact", false)
	match touch.role:
		"punch":
			var held: float = Time.get_ticks_msec() / 1000.0 - float(touch.t)
			if not touch.fired and pos.distance_to(touch.start) <= TAP_DISTANCE and held <= TAP_TIME:
				_punch(touch.side, "jab" if touch.side == "left" else "cross")
		"button":
			_release_button(touch.button)


## A punch finger held still for HOLD_TIME uses (presses interact until it lifts).
func _check_holds(now: float) -> void:
	for touch in _touches.values():
		if touch.role != "punch" or touch.fired or touch.use:
			continue
		if now - float(touch.t) >= HOLD_TIME and (touch.pos as Vector2).distance_to(touch.start) <= TAP_DISTANCE:
			touch.use = true
			touch.fired = true
			_send_action("interact", true)


## How far a still finger is toward a use (0 until it's clearly a hold).
func _hold_progress(touch: Dictionary) -> float:
	if touch.fired or touch.role != "punch" or (touch.pos as Vector2).distance_to(touch.start) > TAP_DISTANCE:
		return 0.0
	var held := Time.get_ticks_msec() / 1000.0 - float(touch.t)
	return clampf((held - TAP_TIME * 0.6) / (HOLD_TIME - TAP_TIME * 0.6), 0.0, 1.0)


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
	var now := Time.get_ticks_msec() / 1000.0
	if kind == "hook":
		_punch(side, kind)
	elif kind == "uppercut":
		# Both thumbs swiping up together is the dash, so an up swipe waits a
		# moment to see if the other side joins in.
		if _pending_up != "" and _pending_up != side and now - _pending_up_t <= BACK_STEP_WINDOW:
			_pending_up = ""
			if _player:
				_player.touch_move("forward_dash")
		else:
			_pending_up = side
			_pending_up_t = now
	elif kind == "roll" and _player:
		# Both thumbs swiping down together is the back step, so a down swipe
		# waits a moment to see if the other side joins in.
		if _pending_down != "" and _pending_down != side and now - _pending_down_t <= BACK_STEP_WINDOW:
			_pending_down = ""
			_player.touch_move("back_step")
		else:
			_pending_down = side
			_pending_down_t = now
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
		"lock":
			if _player:
				_player.lock.cycle()
		"jump", "ultimate", "map", "pause", "emote":
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
	if Input.is_action_pressed("interact"):
		_send_action("interact", false)
	_pending_up = ""
	_pending_down = ""
	for action in ["move_left", "move_right", "move_forward", "move_back",
			"look_left", "look_right", "look_up", "look_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- Drawing -------------------------------------------------------------------------

func _draw_controls() -> void:
	var accent := _vivid(GameState.fighter_color())
	_canvas.modulate = Color(1, 1, 1, float(Settings.get_value("touch_opacity")))
	_draw_stick("move", _zone("move"), "MOVE", accent, false)
	_draw_stick("look", _zone("look"), "LOOK" if not _combat() else "UP / DOWN", accent, _combat())
	for id in BUTTONS:
		if not _button_shown(id) or BUTTONS[id][2] == "hud":
			continue
		var pressed: bool = _held_buttons.has(id) or (id == "sprint" and _sprint_on) or (id == "lock" and _combat())
		for touch in _touches.values():
			if touch.role == "button" and touch.button == id:
				pressed = true
		_draw_button(id, pressed, accent)
	_draw_trails(accent)


# --- Look: taped-glove style. Dark leather tinted with the fighter's colour,
# stitched edges, a strip of athletic tape carrying each label. The fighter's
# colour is pushed to full saturation for stitching, icons and caps. ----------------------

const TAPE := Color(0.94, 0.9, 0.8)
const TAPE_INK := Color(0.2, 0.13, 0.1)


## The fighter's colour at full strength.
func _vivid(color: Color) -> Color:
	return Color.from_hsv(color.h, clampf(color.s * 1.15 + 0.1, 0.0, 1.0), 1.0)


func _leather(accent: Color, light: float) -> Color:
	return Color.from_hsv(accent.h, clampf(accent.s * 0.8, 0.0, 1.0), light)


## A rounded rectangle as a polygon (radius = half the short side: a circle).
func _rrect(rect: Rect2, radius: float, segments := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	for corner in corners:
		for k in segments + 1:
			var a: float = float(corner[1]) + (PI * 0.5) * float(k) / float(segments)
			out.append((corner[0] as Vector2) + Vector2(cos(a), sin(a)) * r)
	return out


## A dashed line along a closed outline, like stitching.
func _stitch(points: PackedVector2Array, color: Color, width := 1.6, dash := 4.0, gap := 3.5) -> void:
	var run := 0.0
	var drawing := true
	for i in points.size():
		var from := points[i]
		var to := points[(i + 1) % points.size()]
		var length := from.distance_to(to)
		var travelled := 0.0
		while travelled < length:
			var span := (dash if drawing else gap) - run
			var step := minf(span, length - travelled)
			if drawing:
				_canvas.draw_line(from.lerp(to, travelled / length), from.lerp(to, (travelled + step) / length), color, width, true)
			travelled += step
			run += step
			if run >= (dash if drawing else gap) - 0.01:
				run = 0.0
				drawing = not drawing


## Leather: a soft shadow, a top-to-bottom gradient, a dark edge.
func _leather_panel(rect: Rect2, radius: float, accent: Color, pressed: bool) -> void:
	var points := _rrect(rect, radius)
	_canvas.draw_colored_polygon(_rrect(Rect2(rect.position + Vector2(0, 4), rect.size), radius), Color(0, 0, 0, 0.4))
	var top := _leather(accent, 0.34)
	var bottom := _leather(accent, 0.16)
	if pressed:
		top = accent
		bottom = accent.darkened(0.35)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, clampf((point.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	_canvas.draw_polygon(points, colors)
	var loop := points.duplicate()
	loop.append(points[0])
	_canvas.draw_polyline(loop, accent.darkened(0.55), 2.0, true)
	var inset := _rrect(rect.grow(-4.5), maxf(radius - 4.5, 2.0))
	_stitch(inset, accent.lightened(0.2) if not pressed else TAPE, 1.6)


## The tape strip across the lower part of a button, a touch crooked.
func _tape_strip(center: Vector2, width: float, height: float, label: String, size: int, accent: Color) -> void:
	var angle := deg_to_rad(-3.0)
	var half := Vector2(width, height) * 0.5
	var pts := PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		pts.append(center + corner.rotated(angle))
	_canvas.draw_colored_polygon(pts, TAPE.lerp(accent, 0.08))
	_canvas.draw_line(pts[3], pts[2], Color(0, 0, 0, 0.25), 1.5, true)
	_canvas.draw_line(pts[0], pts[1], Color(1, 1, 1, 0.35), 1.0, true)
	var font := UiTheme.display_font()
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	_canvas.draw_set_transform(center + Vector2(0, size * 0.34).rotated(angle), angle, Vector2.ONE)
	_canvas.draw_string(font, Vector2(-text_width * 0.5, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TAPE_INK)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A fat arrow, pointing up (down when flip is true).
func _arrow(center: Vector2, size: float, flip: bool, ink: Color) -> void:
	var pts := PackedVector2Array([Vector2(0, -size), Vector2(size * 0.85, size * 0.05), Vector2(size * 0.34, size * 0.05),
			Vector2(size * 0.34, size * 0.9), Vector2(-size * 0.34, size * 0.9), Vector2(-size * 0.34, size * 0.05),
			Vector2(-size * 0.85, size * 0.05)])
	for i in pts.size():
		pts[i] = center + Vector2(pts[i].x, -pts[i].y if flip else pts[i].y)
	_canvas.draw_colored_polygon(pts, ink)


func _chevron(center: Vector2, size: float, ink: Color, width: float) -> void:
	_canvas.draw_polyline(PackedVector2Array([center + Vector2(-size, size * 0.4), center + Vector2(0, -size * 0.5),
			center + Vector2(size, size * 0.4)]), ink, width, true)


func _draw_button(id: String, pressed: bool, accent: Color) -> void:
	var spec: Array = BUTTONS[id]
	var center := _button_center(id)
	var half := _half(id)
	var shape: String = spec[2]
	var label: String = spec[1]
	if id == "map":
		label = _map_label()
	if pressed:
		center += Vector2(0, 2)
	var icon := accent if not pressed else _leather(accent, 0.12)
	if shape == "c":
		_draw_tape_disc(id, center, half, label, accent, pressed)
		return
	_leather_panel(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), half * 0.3, accent, pressed)
	var up_pos := center + Vector2(0, -half * 0.24)
	match id:
		"dash":
			_arrow(up_pos, half * 0.36, false, icon)
		"back_step":
			_arrow(up_pos, half * 0.36, true, icon)
		"sprint":
			_chevron(up_pos + Vector2(0, -half * 0.12), half * 0.3, icon, 4.5)
			_chevron(up_pos + Vector2(0, half * 0.2), half * 0.3, icon, 4.5)
		"jump":
			_chevron(up_pos + Vector2(0, -half * 0.02), half * 0.32, icon, 4.5)
			_canvas.draw_line(up_pos + Vector2(-half * 0.28, half * 0.3), up_pos + Vector2(half * 0.28, half * 0.3), icon, 3.5, true)
		"interact":
			_canvas.draw_arc(up_pos, half * 0.26, 0.0, TAU, 20, icon, 3.5, true)
			_canvas.draw_circle(up_pos, half * 0.09, icon)
	_tape_strip(center + Vector2(0, half * 0.5), half * 2.0 + 4.0, half * 0.5, label, 13, accent)


## The small round buttons: a disc of tape ringed in the fighter's colour.
func _draw_tape_disc(id: String, center: Vector2, radius: float, label: String, accent: Color, pressed: bool) -> void:
	_canvas.draw_circle(center + Vector2(0, 3), radius, Color(0, 0, 0, 0.4))
	_canvas.draw_circle(center, radius, accent if pressed else TAPE.lerp(accent, 0.08))
	_canvas.draw_arc(center, radius - 1.5, 0.0, TAU, 32, accent.darkened(0.1), 3.0, true)
	var ink := TAPE_INK if not pressed else _leather(accent, 0.12)
	if id == "pause":
		var bar := Vector2(radius * 0.2, radius * 0.7)
		_canvas.draw_rect(Rect2(center + Vector2(-radius * 0.34, -bar.y * 0.5), bar), ink)
		_canvas.draw_rect(Rect2(center + Vector2(radius * 0.14, -bar.y * 0.5), bar), ink)
		return
	var font := UiTheme.display_font()
	var size := 12
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	_canvas.draw_string(font, center + Vector2(-width * 0.5, size * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


## The punch fingers: a glow in your fighter's colour with a fading trail, and
## the trails of fingers that just lifted.
func _draw_trails(color: Color) -> void:
	for touch in _touches.values():
		if touch.role == "punch":
			_trail(touch.trail, color, 1.0)
			var glow := color.lightened(0.25)
			glow.a = 0.42
			_canvas.draw_circle(touch.pos, 24.0, glow)
			glow.a = 0.9
			_canvas.draw_arc(touch.pos, 24.0, 0.0, TAU, 28, glow, 2.5, true)
			# Holding still to use: a ring fills round the finger, USE once done.
			var hold := 1.0 if touch.use else _hold_progress(touch)
			if hold > 0.0:
				_canvas.draw_arc(touch.pos, 40.0, -PI * 0.5, -PI * 0.5 + TAU * hold, 36, TAPE, 5.0, true)
				if touch.use:
					var font := UiTheme.display_font()
					var w := font.get_string_size("USE", HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
					var at: Vector2 = touch.pos + Vector2(-w * 0.5, -48)
					_canvas.draw_string_outline(font, at, "USE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.6))
					_canvas.draw_string(font, at, "USE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TAPE)
	for fade in _fading:
		_trail(fade.pts, color, 1.0 - float(fade.age) / TRAIL_FADE)


func _trail(points: Array, color: Color, strength: float) -> void:
	var n := points.size()
	for i in range(1, n):
		var k := float(i) / float(n)
		var c := color.lightened(0.35)
		c.a = k * 0.8 * strength
		_canvas.draw_line(points[i - 1], points[i], c, 3.0 + 14.0 * k, true)


func _draw_stick(role: String, zone: Rect2, label: String, accent: Color, dim := false) -> void:
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
		accent = accent.lerp(Color(0.62, 0.62, 0.66), 0.75)
	# A leather disc ringed with stitching; the cap is the fighter's colour.
	_canvas.draw_circle(base, radius, Color(_leather(accent, 0.18), 0.5 if idle else 0.68))
	var ring := PackedVector2Array()
	for i in 56:
		ring.append(base + Vector2.from_angle(i * TAU / 56.0) * (radius - 4.5))
	_stitch(ring, Color(accent.lightened(0.15), 0.75 if not idle else 0.5), 1.8, 5.0, 4.0)
	_canvas.draw_arc(base, radius, 0.0, TAU, 56, Color(accent.darkened(0.5), 0.9), 2.0, true)
	var knob_center := base + knob_offset
	var knob_radius := 32.0 * _scale()
	_canvas.draw_circle(knob_center + Vector2(0, 4), knob_radius, Color(0, 0, 0, 0.4))
	_canvas.draw_circle(knob_center, knob_radius, Color(accent, 0.95 if not idle else 0.8))
	_canvas.draw_circle(knob_center + Vector2(-4, -6), knob_radius * 0.55, Color(accent.lightened(0.45), 0.55))
	_canvas.draw_arc(knob_center, knob_radius, 0.0, TAU, 32, accent.darkened(0.4), 2.0, true)
	if idle:
		var font := UiTheme.display_font()
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		_canvas.draw_string(font, knob_center + Vector2(-width * 0.5, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, _leather(accent, 0.12))
