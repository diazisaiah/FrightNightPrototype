class_name Controls
## Control schemes, picked in Settings so different layouts can be tried.
## Three independent choices:
##   punches - how hooks and uppercuts are thrown,
##   dodges  - how rolls, the back step and the forward dash are done,
##   slips   - Q / E, optionally also the mouse side buttons.
## apply() rewrites the InputMap to match; text() gives the key names for the
## HUD hints, the tutorial and the Temporal Break prompts.
## Jab/cross (LMB/RMB), WASD, Shift sprint and F use never change. The dedicated
## roll-key preset moves the ultimate from R to T because R becomes roll right.

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
		"roll_left_key", "roll_right_key", "ultimate"]


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


static func apply() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
	match punches():
		"wheel":
			_add_mouse("punch_hook", MOUSE_BUTTON_WHEEL_DOWN)
			_add_mouse("punch_uppercut", MOUSE_BUTTON_WHEEL_UP)
		"side_buttons":
			_add_mouse("punch_hook", MOUSE_BUTTON_XBUTTON2)
			_add_mouse("punch_uppercut", MOUSE_BUTTON_XBUTTON1)
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
	_add_key("ultimate", KEY_T if dodges() == "keys" else KEY_R)
	_add_key("slip_left", KEY_Q)
	_add_key("slip_right", KEY_E)
	if slips() == "qe_side":
		_add_mouse("slip_left", MOUSE_BUTTON_XBUTTON1)
		_add_mouse("slip_right", MOUSE_BUTTON_XBUTTON2)


## Key names for hints, by move: hook, uppercut, roll, back_step, dash,
## jump, slip.
static func text(move: String) -> String:
	match move:
		"hook":
			return {"modifiers": "Shift + click", "wheel": "Scroll down", "side_buttons": "Front side button"}[punches()]
		"uppercut":
			return {"modifiers": "Ctrl + click", "wheel": "Scroll up", "side_buttons": "Back side button"}[punches()]
		"roll":
			if junior():
				return "Q or E"
			return {"ctrl": "Ctrl + A/D", "space": "Space + A/D", "double_tap": "Double-tap A/D", "keys": "Tab/R"}[dodges()]
		"back_step":
			if junior():
				return "Q or E"
			return {"ctrl": "Ctrl + S", "space": "Space + S", "double_tap": "Double-tap S", "keys": "Ctrl + S"}[dodges()]
		"ultimate":
			return "T" if dodges() == "keys" else "R"
		"map":
			return "M" if dodges() == "keys" else "Tab"
		"dash":
			return "Space + W" if dodges() == "space" else "Double-tap W"
		"jump":
			return "C" if dodges() == "space" else "Space"
		"slip":
			if junior():
				return "Q or E"
			return "Q/E or side buttons" if slips() == "qe_side" else "Q/E"
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
	var prompts := [
		{"type": "jab", "hand": "left", "keys": "LMB", "name": "JAB"},
		{"type": "cross", "hand": "right", "keys": "RMB", "name": "CROSS"},
	]
	if direct_punches():
		prompts.append({"type": "hook", "hand": "any", "keys": text("hook").to_upper(), "name": "HOOK"})
		prompts.append({"type": "uppercut", "hand": "any", "keys": text("uppercut").to_upper(), "name": "UPPERCUT"})
	else:
		prompts.append({"type": "hook", "hand": "left", "keys": "SHIFT + LMB", "name": "LEFT HOOK"})
		prompts.append({"type": "hook", "hand": "right", "keys": "SHIFT + RMB", "name": "RIGHT HOOK"})
		prompts.append({"type": "uppercut", "hand": "left", "keys": "CTRL + LMB", "name": "LEFT UPPERCUT"})
		prompts.append({"type": "uppercut", "hand": "right", "keys": "CTRL + RMB", "name": "RIGHT UPPERCUT"})
	return prompts


## The bottom-of-screen controls line.
static func summary() -> String:
	var parts: Array[String] = ["Shift sprint", "LMB/RMB jab/cross"]
	if direct_punches():
		parts.append("%s hook" % text("hook"))
		parts.append("%s uppercut" % text("uppercut"))
	else:
		parts.append_array(["+Shift hook", "+Ctrl uppercut"])
	if junior():
		parts.append("Q/E dodge")
	else:
		parts.append_array(["%s slip" % text("slip"), "%s roll" % text("roll"), "%s back step" % text("back_step")])
	parts.append_array([
		"%s dash" % text("dash"), "%s jump" % text("jump"), "%s ultimate" % text("ultimate"), "F use", "Esc pause",
	])
	return "  |  ".join(parts)


## [what, keys] rows for the pause menu's Controls tab.
static func rows() -> Array:
	var list := [["Move", "W A S D"], ["Look", "Mouse"], ["Sprint", "Shift"], ["Jab  /  Cross", "Left / Right mouse"]]
	if direct_punches():
		list.append(["Hook", text("hook")])
		list.append(["Uppercut", text("uppercut")])
	else:
		list.append(["Hook", "Shift + punch"])
		list.append(["Uppercut", "Ctrl + punch"])
	if junior():
		list.append(["Dodge left  /  right", "Q / E"])
	else:
		list.append(["Slip", text("slip")])
		list.append(["Roll", text("roll")])
		list.append(["Back step", text("back_step")])
	list.append_array([["Dash", text("dash")], ["Jump", text("jump")], ["Ultimate", text("ultimate")], ["Use", "F"], ["Pause", "Esc"]])
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
			for key in (["Q", "E"] if side == "any" else ["Q" if side == "left" else "E"]):
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
			return "Q slip left"
		"slip_right":
			return "E slip right"
		"back_step":
			return text("back_step") + " back step"
	var right := move == "roll_right"
	match dodges():
		"ctrl":
			return ("Ctrl+D" if right else "Ctrl+A") + " roll"
		"space":
			return ("Space+D" if right else "Space+A") + " roll"
		"double_tap":
			return ("Double-tap D" if right else "Double-tap A") + " roll"
		"keys":
			return ("R" if right else "Tab") + " roll"
	return move
