class_name Controls
## Controls: picked schemes plus your own key bindings (Settings).
## Schemes (three independent choices):
##   punches - how hooks and uppercuts are thrown,
##   dodges  - how rolls, the back step and the forward dash are done,
##   slips   - Q / E, optionally also the mouse side buttons.
## In Weenie Hut Junior Mode Q / E dodge for you, so Space is jump and the
## dodge modifier isn't used.
## Bindings: any action in BINDABLE can be moved to another key or mouse
## button (Settings "bindings": {action: "k:<physical keycode>" | "m:<button>"});
## a binding replaces that action's keyboard and mouse inputs, and binding a
## key that another action uses swaps the two.
## Controllers (Xbox-style and PlayStation, see Pad) get their own default
## layout (PAD_LAYOUT) and their own bindings (Settings "pad_bindings":
## {action: "j:<button>" | "a:<axis>:<+/->"}), rebound the same way.
## apply() rewrites the InputMap; text() and key_name() give the key names for
## the HUD hints, the tutorial and the Temporal Break prompts (controller
## buttons while a controller is in use). Anything showing them listens to
## changed() and redraws when the layout, a binding or the device changes.

const PUNCH_MODES := {
	"modifiers": "Hold Shift / Ctrl + click",
	"wheel": "Scroll wheel (down hook, up uppercut)",
	"side_buttons": "Mouse side buttons (front hook, back uppercut)",
}
const DODGE_MODES := {
	"ctrl": "Ctrl + A / D / S",
	"space": "Space + A / D / S / W  (jump moves to C)",
	"double_tap": "Double-tap A / D / S",
	"keys": "Tab left roll / R right roll  (ultimate T)",
}
## Weenie Hut Junior Mode: Q / E dodge, and the game picks the slip, roll or
## back step that beats the incoming attack, as long as you pick its side.
## Pro Gamer Mode: every dodge is its own input (the schemes below).
const ASSIST_MODES := {
	"junior": "Weenie Hut Junior Mode  (Q / E dodge for you)",
	"pro": "Pro Gamer Mode  (slip, roll and back step yourself)",
}
const SLIP_MODES := {
	"qe": "Q / E",
	"qe_side": "Q / E or mouse side buttons (back left, front right)",
}

## Actions this scheme fills in (created if the project doesn't have them).
const ACTIONS := ["punch_hook", "punch_uppercut", "dodge_modifier", "jump", "slip_left", "slip_right",
		"roll_left_key", "roll_right_key", "back_step_key", "dash_key", "ultimate", "map",
		"look_left", "look_right", "look_up", "look_down", "pause", "emote"]
## The controller layout: [action, button] or [action, axis, direction].
## Sticks move and look, X / Y (Square / Triangle) jab and cross, the
## triggers hook and uppercut, the bumpers dodge, A jumps, B uses, the D-pad
## rolls / back steps / dashes, clicking the right stick fires the ultimate,
## View / Create holds for the emote wheel (a tap opens the Crypt map); in
## Weenie Hut Junior Mode D-pad down does too (it's free there).
const PAD_LAYOUT := [
	["move_forward", JOY_AXIS_LEFT_Y, -1], ["move_back", JOY_AXIS_LEFT_Y, 1],
	["move_left", JOY_AXIS_LEFT_X, -1], ["move_right", JOY_AXIS_LEFT_X, 1],
	["look_left", JOY_AXIS_RIGHT_X, -1], ["look_right", JOY_AXIS_RIGHT_X, 1],
	["look_up", JOY_AXIS_RIGHT_Y, -1], ["look_down", JOY_AXIS_RIGHT_Y, 1],
	["sprint", JOY_BUTTON_LEFT_STICK], ["jump", JOY_BUTTON_A],
	["punch_left", JOY_BUTTON_X], ["punch_right", JOY_BUTTON_Y],
	["punch_hook", JOY_AXIS_TRIGGER_LEFT, 1], ["punch_uppercut", JOY_AXIS_TRIGGER_RIGHT, 1],
	["slip_left", JOY_BUTTON_LEFT_SHOULDER], ["slip_right", JOY_BUTTON_RIGHT_SHOULDER],
	["roll_left_key", JOY_BUTTON_DPAD_LEFT], ["roll_right_key", JOY_BUTTON_DPAD_RIGHT],
	["back_step_key", JOY_BUTTON_DPAD_DOWN], ["dash_key", JOY_BUTTON_DPAD_UP],
	["ultimate", JOY_BUTTON_RIGHT_STICK], ["interact", JOY_BUTTON_B],
	["emote", JOY_BUTTON_BACK], ["pause", JOY_BUTTON_START],
]
## Actions you can rebind, in the order Settings lists them: [action, name,
## name in Pro Gamer Mode ("" = same), shown in Weenie Hut Junior Mode].
const BINDABLE := [
	["move_forward", "Move forward", "", true],
	["move_back", "Move back", "", true],
	["move_left", "Move left", "", true],
	["move_right", "Move right", "", true],
	["sprint", "Sprint", "Sprint  (and hook modifier)", true],
	["jump", "Jump", "", true],
	["punch_left", "Jab", "", true],
	["punch_right", "Cross", "", true],
	["punch_hook", "Hook", "", true],
	["punch_uppercut", "Uppercut", "", true],
	["slip_left", "Dodge left", "Slip left", true],
	["slip_right", "Dodge right", "Slip right", true],
	["dodge_modifier", "", "Dodge modifier  (hold + direction)", false],
	["roll_left_key", "", "Roll left", false],
	["roll_right_key", "", "Roll right", false],
	["back_step_key", "", "Back step", false],
	["dash_key", "Dash forward", "", true],
	["ultimate", "Ultimate", "", true],
	["interact", "Use", "", true],
	["map", "Map  (Crypt)", "", true],
	["emote", "Emote  (hold for the wheel)", "", true],
	["pause", "Pause", "", true],
]


## True in Weenie Hut Junior Mode.
static func junior() -> bool:
	return Settings.get_value("assist_mode") == "junior"


static func punches() -> String:
	return Settings.get_value("punch_mode")


static func dodges() -> String:
	return Settings.get_value("dodge_mode")


static func slips() -> String:
	# Side buttons can't do both jobs; the punches win.
	if punches() == "side_buttons":
		return "qe"
	return Settings.get_value("slip_mode")


## Hooks and uppercuts are their own buttons (thrown with the hand that
## didn't punch last), not Shift/Ctrl + click.
static func direct_punches() -> bool:
	return punches() != "modifiers"


static func bindings() -> Dictionary:
	var saved = Settings.get_value("bindings")
	return saved if saved is Dictionary else {}


static func pad_bindings() -> Dictionary:
	var saved = Settings.get_value("pad_bindings")
	return saved if saved is Dictionary else {}


## A controller is what you're playing with right now (Pad).
static func pad() -> bool:
	return Pad.active


## Calls redraw now and whenever the key names could change: a binding or
## scheme (Settings.changed) or switching between keyboard and controller.
## Disconnects when owner leaves the tree.
static func watch(owner: Node, redraw: Callable) -> void:
	var on_settings := func() -> void: redraw.call()
	var on_device := func(_on: bool) -> void: redraw.call()
	Settings.changed.connect(on_settings)
	Pad.active_changed.connect(on_device)
	owner.tree_exiting.connect(func() -> void:
		Settings.changed.disconnect(on_settings)
		Pad.active_changed.disconnect(on_device))


static func apply() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
	_restore_project_defaults()
	match punches():
		"wheel":
			_add_mouse("punch_hook", MOUSE_BUTTON_WHEEL_DOWN)
			_add_mouse("punch_uppercut", MOUSE_BUTTON_WHEEL_UP)
		"side_buttons":
			_add_mouse("punch_hook", MOUSE_BUTTON_XBUTTON2)
			_add_mouse("punch_uppercut", MOUSE_BUTTON_XBUTTON1)
	if junior():
		# Q / E do every dodge, so Space is free to jump.
		_add_key("jump", KEY_SPACE)
	else:
		match dodges():
			"ctrl":
				_add_key("dodge_modifier", KEY_CTRL)
				_add_key("jump", KEY_SPACE)
			"space":
				_add_key("dodge_modifier", KEY_SPACE)
				_add_key("jump", KEY_C)
			"keys":
				_add_key("dodge_modifier", KEY_CTRL)
				_add_key("roll_left_key", KEY_TAB)
				_add_key("roll_right_key", KEY_R)
				_add_key("jump", KEY_SPACE)
			_:
				_add_key("jump", KEY_SPACE)
	_add_key("ultimate", KEY_T if not junior() and dodges() == "keys" else KEY_R)
	_add_key("slip_left", KEY_Q)
	_add_key("slip_right", KEY_E)
	if slips() == "qe_side":
		_add_mouse("slip_left", MOUSE_BUTTON_XBUTTON1)
		_add_mouse("slip_right", MOUSE_BUTTON_XBUTTON2)
	_add_key("map", KEY_M)
	if junior() or dodges() != "keys":
		_add_key("map", KEY_TAB)
	# P first (what hints show): in a browser, Esc also leaves full screen and
	# frees the mouse (Settings asks Chromium browsers to hand it to the game).
	_add_key("pause", KEY_P)
	_add_key("pause", KEY_ESCAPE)
	_add_key("emote", KEY_G)
	# The controller layout, then your own controller bindings over it. In
	# Weenie Hut Junior Mode the bumpers pick every dodge, so the D-pad only dashes.
	for entry in PAD_LAYOUT:
		if junior() and entry[0] in ["roll_left_key", "roll_right_key", "back_step_key"]:
			continue
		if junior() and entry[0] == "emote":
			# D-pad down first, so the hints show it.
			InputMap.action_add_event("emote", _pad_event(["emote", JOY_BUTTON_DPAD_DOWN]))
		InputMap.action_add_event(entry[0], _pad_event(entry))
	var pad_custom := pad_bindings()
	for action in pad_custom:
		var event := _decode(String(pad_custom[action]))
		if event == null or not InputMap.has_action(action):
			continue
		_erase_pad(action)
		InputMap.action_add_event(action, event)
	for action in pad_custom:
		var event := _decode(String(pad_custom[action]))
		for other in _bindable_ids():
			if event != null and other != action and _has_input(other, event):
				_erase_input(other, event)
	# Your own bindings replace an action's keyboard and mouse inputs.
	var custom := bindings()
	for action in custom:
		var event := _decode(String(custom[action]))
		if event == null or not InputMap.has_action(action):
			continue
		_erase_keyboard_mouse(action)
		InputMap.action_add_event(action, event)
	# An input bound elsewhere stops working for the defaults it shadowed.
	for action in custom:
		var event := _decode(String(custom[action]))
		if event == null:
			continue
		for other in _bindable_ids():
			if other != action and _has_input(other, event):
				_erase_input(other, event)


## The project's own default keys for the built-in actions (WASD, Shift,
## clicks, F), so clearing a binding brings them back.
static func _restore_project_defaults() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "punch_left", "punch_right", "interact"]:
		if not InputMap.has_action(action):
			continue
		var defaults: Array = ProjectSettings.get_setting("input/" + action, {}).get("events", [])
		InputMap.action_erase_events(action)
		for event in defaults:
			if event is InputEventKey or event is InputEventMouseButton:
				InputMap.action_add_event(action, event)


# --- Rebinding -----------------------------------------------------------------------

## Binds action to event (a key or mouse button press). Another action using
## that input gets this action's old input instead.
static func bind(action: String, event: InputEvent) -> void:
	var code := _encode(event)
	if code == "":
		return
	var on_pad := _is_pad(event)
	var custom := (pad_bindings() if on_pad else bindings()).duplicate()
	var old := _primary_pad(action) if on_pad else _primary(action)
	for other in _bindable_ids():
		if other != action and _has_input(other, event):
			var swap := _encode(old) if old else ""
			if swap != "":
				custom[other] = swap
			else:
				custom.erase(other)
	custom[action] = code
	Settings.set_value("pad_bindings" if on_pad else "bindings", custom)


static func reset_bindings() -> void:
	Settings.values["bindings"] = {}
	Settings.set_value("pad_bindings", {})


## The rows Settings shows for the current mode: [[action, name], ...].
static func bindable_rows() -> Array:
	var rows := []
	for entry in BINDABLE:
		if junior() and not entry[3]:
			continue
		var name: String = entry[1] if junior() or entry[2] == "" else entry[2]
		rows.append([entry[0], name])
	return rows


static func _bindable_ids() -> Array:
	return BINDABLE.map(func(entry: Array) -> String: return entry[0])


## The first key or mouse button on an action (what hints show).
static func _primary(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event
	return null


## The first controller input on an action.
static func _primary_pad(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for event in InputMap.action_get_events(action):
		if _is_pad(event):
			return event
	return null


## What hints show for an action: its controller button while a controller is
## in use, otherwise its key ("Space", "Q", "Mouse 4"); "-" when unbound.
static func key_name(action: String) -> String:
	return pad_name(action) if pad() else kb_name(action)


static func kb_name(action: String) -> String:
	return input_name(_primary(action))


static func pad_name(action: String) -> String:
	var event := _primary_pad(action)
	if event == null and action == "map":
		event = _primary_pad("emote")  # A tap of the emote button opens the map.
	return Pad.input_name(event) if event else "-"


static func input_name(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		match code:
			KEY_SPACE:
				return "Space"
			KEY_CTRL:
				return "Ctrl"
			KEY_SHIFT:
				return "Shift"
			KEY_ALT:
				return "Alt"
			KEY_TAB:
				return "Tab"
			KEY_ESCAPE:
				return "Esc"
		# Physical keys are named by their US-layout place (where W A S D sit).
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "Middle click"
			MOUSE_BUTTON_WHEEL_UP:
				return "Scroll up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Scroll down"
			MOUSE_BUTTON_XBUTTON1:
				return "Back side button"
			MOUSE_BUTTON_XBUTTON2:
				return "Front side button"
		return "Mouse %d" % event.button_index
	return "-"


static func _is_pad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


static func _pad_event(entry: Array) -> InputEvent:
	if entry.size() == 3:
		var motion := InputEventJoypadMotion.new()
		motion.device = -1
		motion.axis = entry[1]
		motion.axis_value = float(entry[2])
		return motion
	var button := InputEventJoypadButton.new()
	button.device = -1
	button.button_index = entry[1]
	return button


static func _encode(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "j:%d" % event.button_index
	if event is InputEventJoypadMotion:
		return "a:%d:%s" % [event.axis, "+" if event.axis_value > 0.0 else "-"]
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return "k:%d" % code
	if event is InputEventMouseButton:
		return "m:%d" % event.button_index
	return ""


static func _decode(code: String) -> InputEvent:
	if code.begins_with("a:"):
		var parts := code.split(":")
		return _pad_event(["", int(parts[1]), 1 if parts[2] == "+" else -1])
	if code.begins_with("j:"):
		return _pad_event(["", code.substr(2).to_int()])
	var value := code.substr(2).to_int()
	if code.begins_with("k:"):
		var key := InputEventKey.new()
		key.physical_keycode = value
		return key
	if code.begins_with("m:"):
		var button := InputEventMouseButton.new()
		button.button_index = value
		return button
	return null


static func _same(a: InputEvent, b: InputEvent) -> bool:
	return a != null and b != null and _encode(a) == _encode(b)


static func _has_input(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	for existing in InputMap.action_get_events(action):
		if _same(existing, event):
			return true
	return false


static func _erase_input(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if _same(existing, event):
			InputMap.action_erase_event(action, existing)


static func _erase_pad(action: String) -> void:
	for existing in InputMap.action_get_events(action):
		if _is_pad(existing):
			InputMap.action_erase_event(action, existing)


static func _erase_keyboard_mouse(action: String) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey or existing is InputEventMouseButton:
			InputMap.action_erase_event(action, existing)


static func _bound(action: String) -> bool:
	return _primary(action) != null


# --- Hints ---------------------------------------------------------------------------

## Key names for hints, by move: hook, uppercut, roll, back_step, dash,
## jump, slip, ultimate, map.
static func text(move: String) -> String:
	var left := key_name("slip_left")
	var right := key_name("slip_right")
	match move:
		"jab":
			return key_name("punch_left")
		"cross":
			return key_name("punch_right")
		"sprint":
			return key_name("sprint")
		"look":
			return "Right stick" if pad() else "Mouse"
		"move":
			if pad():
				return "Left stick"
			return "%s %s %s %s" % [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]
	if pad():
		return _pad_text(move, left, right)
	match move:
		"hook":
			if direct_punches() or _bound("punch_hook"):
				return key_name("punch_hook")
			return "%s + click" % key_name("sprint")
		"uppercut":
			if direct_punches() or _bound("punch_uppercut"):
				return key_name("punch_uppercut")
			return "%s + click" % key_name("uppercut_modifier")
		"roll":
			if junior():
				return "%s or %s" % [left, right]
			if _bound("roll_left_key"):
				return "%s/%s" % [key_name("roll_left_key"), key_name("roll_right_key")]
			if dodges() == "double_tap":
				return "Double-tap %s/%s" % [key_name("move_left"), key_name("move_right")]
			return "%s + %s/%s" % [key_name("dodge_modifier"), key_name("move_left"), key_name("move_right")]
		"back_step":
			if junior():
				return "%s or %s" % [left, right]
			if _bound("back_step_key"):
				return key_name("back_step_key")
			if dodges() == "double_tap":
				return "Double-tap %s" % key_name("move_back")
			return "%s + %s" % [key_name("dodge_modifier"), key_name("move_back")]
		"ultimate":
			return key_name("ultimate")
		"map":
			return key_name("map")
		"dash":
			if _bound("dash_key"):
				return key_name("dash_key")
			if not junior() and dodges() == "space":
				return "%s + %s" % [key_name("dodge_modifier"), key_name("move_forward")]
			return "Double-tap %s" % key_name("move_forward")
		"jump":
			return key_name("jump")
		"slip":
			if junior():
				return "%s or %s" % [left, right]
			if slips() == "qe_side" and not bindings().has("slip_left"):
				return "%s/%s or side buttons" % [left, right]
			return "%s/%s" % [left, right]
	return move


## How a hook or uppercut is thrown on the keyboard ("Shift + click", or its key).
static func kb_hint(move: String) -> String:
	var action := "punch_" + move
	if direct_punches() or _bound(action):
		return kb_name(action)
	return "%s + click" % kb_name("sprint" if move == "hook" else "uppercut_modifier")


## text() on a controller: every move has a button of its own.
static func _pad_text(move: String, left: String, right: String) -> String:
	match move:
		"hook":
			return pad_name("punch_hook")
		"uppercut":
			return pad_name("punch_uppercut")
		"roll":
			if junior():
				return "%s or %s" % [left, right]
			return "%s / %s" % [pad_name("roll_left_key"), pad_name("roll_right_key")]
		"back_step":
			return "%s or %s" % [left, right] if junior() else pad_name("back_step_key")
		"dash":
			return pad_name("dash_key")
		"slip":
			return "%s or %s" % [left, right] if junior() else "%s / %s" % [left, right]
		"jump":
			return pad_name("jump")
		"ultimate":
			return pad_name("ultimate")
		"map":
			return pad_name("map")
	return move


## Replaces <hook>, <uppercut>, <roll>, <back_step>, <dash>, <jump> and
## <slip> in a hint with this scheme's keys.
static func fill(hint: String) -> String:
	for move in ["hook", "uppercut", "roll", "back_step", "dash", "jump", "slip", "ultimate", "jab", "cross", "move", "look", "sprint"]:
		hint = hint.replace("<%s>" % move, text(move))
	return hint


## The bottom-of-screen controls line.
static func summary() -> String:
	var parts: Array[String] = ["%s sprint" % key_name("sprint"), "%s/%s jab/cross" % [key_name("punch_left"), key_name("punch_right")]]
	parts.append("%s hook" % text("hook"))
	parts.append("%s uppercut" % text("uppercut"))
	if junior():
		parts.append("%s dodge" % text("slip"))
	else:
		parts.append_array(["%s slip" % text("slip"), "%s roll" % text("roll"), "%s back step" % text("back_step")])
	parts.append_array([
		"%s dash" % text("dash"), "%s jump" % text("jump"), "%s ultimate" % text("ultimate"),
		"%s use" % key_name("interact"), "%s emote" % key_name("emote"), "%s pause" % key_name("pause"),
	])
	return "  |  ".join(parts)


## [what, keys] rows for the pause menu's Controls tab.
static func rows() -> Array:
	var move := "%s %s %s %s" % [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]
	if pad():
		move = "Left stick"
	var list := [["Move", move], ["Look", "Right stick" if pad() else "Mouse"], ["Sprint", key_name("sprint") + ("  (click to toggle)" if pad() else "")],
			["Jab  /  Cross", "%s / %s" % [key_name("punch_left"), key_name("punch_right")]]]
	list.append(["Hook", text("hook")])
	list.append(["Uppercut", text("uppercut")])
	if junior():
		list.append(["Dodge left  /  right", "%s / %s" % [key_name("slip_left"), key_name("slip_right")]])
	else:
		list.append(["Slip", text("slip")])
		list.append(["Roll", text("roll")])
		list.append(["Back step", text("back_step")])
	list.append_array([["Dash", text("dash")], ["Jump", text("jump")], ["Ultimate", text("ultimate")],
			["Use", key_name("interact")], ["Emote  (hold for the wheel)", key_name("emote")], ["Pause", key_name("pause")]])
	return list


static func _add_key(action: String, key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


static func _add_mouse(action: String, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


## The key hint shown over an enemy's wind-up (training dummy), e.g.
## "LEFT HOOK  -  Space+D roll right", or just "-  E" in Weenie Hut Junior Mode.
static func cue_hint(attack: String) -> String:
	var title := attack.replace("_", " ").to_upper()
	var answers: Array = Player.ANSWERS.get(attack, [])
	if answers.is_empty():
		return title + "  -  jump it"
	if junior():
		var keys := []
		for move in answers:
			var side: String = Player.DEFENSES[move].side
			var left := key_name("slip_left")
			var right := key_name("slip_right")
			for key in ([left, right] if side == "any" else [left if side == "left" else right]):
				if not keys.has(key):
					keys.append(key)
		return title + "  -  " + " / ".join(keys)
	var names := []
	for move in answers:
		names.append(_move_keys(move))
	return title + "  -  " + " / ".join(names)


## One defense's keys in the current Pro scheme, e.g. "Space+D roll right".
static func _move_keys(move: String) -> String:
	match move:
		"slip_left":
			return "%s slip left" % key_name("slip_left")
		"slip_right":
			return "%s slip right" % key_name("slip_right")
		"back_step":
			return text("back_step") + " back step"
	var right := move == "roll_right"
	if pad():
		return "%s roll" % pad_name("roll_right_key" if right else "roll_left_key")
	if _bound("roll_left_key"):
		return "%s roll" % key_name("roll_right_key" if right else "roll_left_key")
	var side := key_name("move_right" if right else "move_left")
	if dodges() == "double_tap":
		return "Double-tap %s roll" % side
	return "%s+%s roll" % [key_name("dodge_modifier"), side]
