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
## apply() rewrites the InputMap; text() and key_name() give the key names for
## the HUD hints, the tutorial and the Temporal Break prompts.

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
		"roll_left_key", "roll_right_key", "back_step_key", "dash_key", "ultimate", "map"]
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
		_erase_keyboard_mouse(action)
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
	var custom := bindings().duplicate()
	var old := _primary(action)
	for other in _bindable_ids():
		if other != action and _has_input(other, event):
			var swap := _encode(old) if old else ""
			if swap != "":
				custom[other] = swap
			else:
				custom.erase(other)
	custom[action] = code
	Settings.set_value("bindings", custom)


static func reset_bindings() -> void:
	Settings.set_value("bindings", {})


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


## e.g. "Space", "Q", "Mouse 4", "Scroll up"; "-" when nothing is bound.
static func key_name(action: String) -> String:
	return input_name(_primary(action))


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


static func _encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return "k:%d" % code
	if event is InputEventMouseButton:
		return "m:%d" % event.button_index
	return ""


static func _decode(code: String) -> InputEvent:
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


## Replaces <hook>, <uppercut>, <roll>, <back_step>, <dash>, <jump> and
## <slip> in a hint with this scheme's keys.
static func fill(hint: String) -> String:
	for move in ["hook", "uppercut", "roll", "back_step", "dash", "jump", "slip", "ultimate"]:
		hint = hint.replace("<%s>" % move, text(move))
	return hint


## The Temporal Break prompts. With hook/uppercut buttons the hand isn't
## chosen, so those prompts accept either hand ("any").
static func qte_prompts() -> Array:
	var jab := key_name("punch_left").to_upper()
	var cross := key_name("punch_right").to_upper()
	var prompts := [
		{"type": "jab", "hand": "left", "keys": jab, "name": "JAB"},
		{"type": "cross", "hand": "right", "keys": cross, "name": "CROSS"},
	]
	if direct_punches():
		prompts.append({"type": "hook", "hand": "any", "keys": text("hook").to_upper(), "name": "HOOK"})
		prompts.append({"type": "uppercut", "hand": "any", "keys": text("uppercut").to_upper(), "name": "UPPERCUT"})
	else:
		var hook := key_name("sprint").to_upper()
		var upper := key_name("uppercut_modifier").to_upper()
		prompts.append({"type": "hook", "hand": "left", "keys": "%s + %s" % [hook, jab], "name": "LEFT HOOK"})
		prompts.append({"type": "hook", "hand": "right", "keys": "%s + %s" % [hook, cross], "name": "RIGHT HOOK"})
		prompts.append({"type": "uppercut", "hand": "left", "keys": "%s + %s" % [upper, jab], "name": "LEFT UPPERCUT"})
		prompts.append({"type": "uppercut", "hand": "right", "keys": "%s + %s" % [upper, cross], "name": "RIGHT UPPERCUT"})
	return prompts


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
		"%s use" % key_name("interact"), "Esc pause",
	])
	return "  |  ".join(parts)


## [what, keys] rows for the pause menu's Controls tab.
static func rows() -> Array:
	var move := "%s %s %s %s" % [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]
	var list := [["Move", move], ["Look", "Mouse"], ["Sprint", key_name("sprint")],
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
			["Use", key_name("interact")], ["Pause", "Esc"]])
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
	if _bound("roll_left_key"):
		return "%s roll" % key_name("roll_right_key" if right else "roll_left_key")
	var side := key_name("move_right" if right else "move_left")
	if dodges() == "double_tap":
		return "Double-tap %s roll" % side
	return "%s+%s roll" % [key_name("dodge_modifier"), side]
