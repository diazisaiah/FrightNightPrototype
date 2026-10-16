extends CanvasLayer
## Controllers (autoload "Pad"): Xbox-style and PlayStation (DualSense /
## DualShock) pads, on desktop and in the browser.
## - active: true once the last input came from a controller (any key, click
##   or mouse move switches back), so hints show the right buttons.
## - The menu cursor: whenever the mouse isn't captured for a fight (menus,
##   camp, the pause screen), the left stick moves an on-screen pointer, A /
##   Cross clicks (hold to drag, e.g. panning the upgrade web), the right
##   stick scrolls and zooms, and B / Circle backs out (ui_cancel).
## - Button names (Xbox: A B X Y LB RB LT RT; PlayStation: Cross Circle
##   Square Triangle L1 R1 L2 R2) and rumble.

signal active_changed(on: bool)

const CURSOR_SPEED := 900.0
const CURSOR_DEADZONE := 0.2
const SCROLL_EVERY := 0.09
const XBOX_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "LS click",
	JOY_BUTTON_RIGHT_STICK: "RS click", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_GUIDE: "Guide",
}
const PS_BUTTONS := {
	JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_BACK: "Create", JOY_BUTTON_START: "Options", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down", JOY_BUTTON_DPAD_LEFT: "D-pad left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad right", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_TOUCHPAD: "Touchpad",
}

var active := false
## Settings is waiting for a controller button to bind: A / Cross is a
## button to bind then, not a cursor click.
var listening := false
## "playstation" or "xbox": which names to show.
var kind := "xbox"
var device := 0
var _cursor: Control
var _cursor_pos := Vector2(640, 360)
var _clicking := false
var _scroll_timer := 0.0
## For double-clicks (buying a web node): when and where A last went down.
var _last_press := -10.0
var _last_press_at := Vector2.ZERO
## The last frame a fight was running (Player marks it): no cursor then.
var _fight_frame := -100


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor = Control.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)
	Input.joy_connection_changed.connect(func(id: int, connected: bool) -> void:
		if connected:
			device = id
			_detect_kind())


## Player calls this every frame it's fighting: the cursor stays away.
func mark_fighting() -> void:
	_fight_frame = Engine.get_process_frames()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		if event.device != device:
			device = event.device
			_detect_kind()
		_set_active(true)
	elif event is InputEventKey or (event is InputEventMouseButton and not event.has_meta("pad")) \
			or (event is InputEventMouseMotion and not event.has_meta("pad") and event.relative.length() > 2.0):
		_set_active(false)
	# A / Cross clicks with the menu cursor (and isn't also a focus "accept").
	if _cursor.visible and not listening and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
		get_viewport().set_input_as_handled()
		if event.pressed != _clicking:
			_clicking = event.pressed
			_send_button(MOUSE_BUTTON_LEFT, event.pressed)


func _process(delta: float) -> void:
	var show := active and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and Engine.get_process_frames() - _fight_frame > 2
	if show != _cursor.visible:
		_cursor.visible = show
		if show:
			_cursor_pos = get_viewport().get_visible_rect().size / 2.0
		elif _clicking:
			_clicking = false
			_send_button(MOUSE_BUTTON_LEFT, false)
	if not show:
		return
	var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
	var dpad := Vector2(float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP)))
	if stick.length() < CURSOR_DEADZONE:
		stick = Vector2.ZERO
	var move := stick * stick.length() + dpad * 0.35
	if move != Vector2.ZERO:
		var bounds := get_viewport().get_visible_rect().size
		var before := _cursor_pos
		_cursor_pos = (_cursor_pos + move * CURSOR_SPEED * delta).clamp(Vector2.ZERO, bounds - Vector2.ONE)
		_send_motion(_cursor_pos - before)
		_cursor.queue_redraw()
	# The right stick scrolls lists and zooms the webs.
	var scroll := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	_scroll_timer -= delta
	if absf(scroll) > 0.5 and _scroll_timer <= 0.0:
		_scroll_timer = SCROLL_EVERY
		var wheel := MOUSE_BUTTON_WHEEL_DOWN if scroll > 0.0 else MOUSE_BUTTON_WHEEL_UP
		_send_button(wheel, true)
		_send_button(wheel, false)


func _set_active(on: bool) -> void:
	if on == active:
		return
	active = on
	if on:
		_detect_kind()
	active_changed.emit(on)


func _detect_kind() -> void:
	var name_lower := Input.get_joy_name(device).to_lower()
	var guid := Input.get_joy_guid(device).to_lower()
	var sony := false
	for word in ["ps5", "ps4", "ps3", "dualsense", "dualshock", "sony", "playstation", "054c"]:
		if name_lower.contains(word) or guid.contains(word):
			sony = true
	# Sony pads on Windows often just say "Wireless Controller".
	if name_lower.begins_with("wireless controller"):
		sony = true
	kind = "playstation" if sony else "xbox"


## A joypad event's name for this controller: "Cross", "RB", "Left stick up".
func input_name(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		var names: Dictionary = PS_BUTTONS if kind == "playstation" else XBOX_BUTTONS
		return names.get(event.button_index, "Button %d" % event.button_index)
	if event is InputEventJoypadMotion:
		var ps := kind == "playstation"
		match event.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "L2" if ps else "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "R2" if ps else "RT"
			JOY_AXIS_LEFT_X:
				return "Left stick " + ("right" if event.axis_value > 0.0 else "left")
			JOY_AXIS_LEFT_Y:
				return "Left stick " + ("down" if event.axis_value > 0.0 else "up")
			JOY_AXIS_RIGHT_X:
				return "Right stick " + ("right" if event.axis_value > 0.0 else "left")
			JOY_AXIS_RIGHT_Y:
				return "Right stick " + ("down" if event.axis_value > 0.0 else "up")
		return "Axis %d" % event.axis
	return "-"


## A short buzz: weak and strong motor (0-1) for seconds. Off in Settings.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if active and Settings.get_value("vibration"):
		Input.start_joy_vibration(device, weak, strong, seconds)


func _send_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.set_meta("pad", true)
	var window := _to_window(_cursor_pos)
	event.position = window
	event.global_position = window
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if _clicking else 0
	Input.parse_input_event(event)


func _send_button(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.set_meta("pad", true)
	var window := _to_window(_cursor_pos)
	event.position = window
	event.global_position = window
	event.button_index = button
	event.pressed = pressed
	if button == MOUSE_BUTTON_LEFT:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		if pressed:
			var now := Time.get_ticks_msec() / 1000.0
			event.double_click = now - _last_press < 0.4 and _cursor_pos.distance_to(_last_press_at) < 12.0
			_last_press = -10.0 if event.double_click else now
			_last_press_at = _cursor_pos
	Input.parse_input_event(event)


## Viewport (canvas) coordinates to window coordinates, for injected events.
func _to_window(at: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * at


func _draw_cursor() -> void:
	var tip := _cursor_pos
	var arrow := PackedVector2Array([tip, tip + Vector2(0, 26), tip + Vector2(7, 20), tip + Vector2(12, 31),
			tip + Vector2(17, 29), tip + Vector2(12, 18), tip + Vector2(21, 18)])
	var shadow := PackedVector2Array()
	for point in arrow:
		shadow.append(point + Vector2(2, 3))
	_cursor.draw_colored_polygon(shadow, Color(0, 0, 0, 0.45))
	_cursor.draw_colored_polygon(arrow, UiTheme.GOLD.lightened(0.15) if not _clicking else UiTheme.GOLD.darkened(0.2))
	_cursor.draw_polyline(arrow + PackedVector2Array([tip]), Color(0.05, 0.04, 0.06), 2.0)
