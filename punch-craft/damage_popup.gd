class_name DamagePopup
## Floating text that rises and fades, used for damage numbers.
##
## Kept readable in a busy fight (2026-10-29: echoes, powers, chains and burns
## buried the screen):
## - Numbers stack: any number ("12.3", or a caption over one, "ECHO\n4.1")
##   landing within MERGE_DISTANCE of a live stack, within MERGE_GAP of its last
##   hit, adds to it and pops again, for up to MERGE_LIFE. One growing number a
##   monster, whatever hit it.
## - Callouts (a number's caption, or text like "STUNNED") repeat at most once
##   per CALLOUT_GAP near the same spot.
## - At most MAX_LIVE labels at once (WEB_MAX_LIVE in browsers); past that,
##   only big ones (font size BIG and up: K.O.!, a contender's call) still pop.

const MERGE_DISTANCE := 1.8
const MERGE_GAP := 0.5
const MERGE_LIFE := 2.0
const CALLOUT_GAP := 0.9
const CALLOUT_DISTANCE := 2.5
const MAX_LIVE := 14
const WEB_MAX_LIVE := 10
const BIG := 54

## Live stacks: {label, at, value, last, born}; recent callouts: {text, at,
## time} (seconds).
static var _stacks: Array = []
static var _callouts: Array = []
static var _live: Array = []


static func spawn(parent: Node, text: String, color: Color, font_size: int, at: Vector3) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# (Untyped: a freed label can't be passed as a Label3D.)
	_live = _live.filter(func(label) -> bool: return is_instance_valid(label))
	var lines := text.split("\n")
	var number := String(lines[lines.size() - 1])
	# (Heals, "+12", pop on their own.)
	var stacks := number.is_valid_float() and not number.begins_with("+")
	var caption := "\n".join(lines.slice(0, lines.size() - 1)) if stacks else text
	if caption != "":
		_callout(parent, caption, color, font_size if not stacks else maxi(28, font_size - 10), at, now, stacks)
	if not stacks:
		return
	_stacks = _stacks.filter(func(stack: Dictionary) -> bool:
		return is_instance_valid(stack.label) and now - stack.born < MERGE_LIFE)
	for stack in _stacks:
		if now - stack.last < MERGE_GAP and (stack.at as Vector3).distance_to(at) < MERGE_DISTANCE:
			stack.value += number.to_float()
			stack.last = now
			var label: Label3D = stack.label
			label.text = "%.1f" % stack.value
			label.font_size = clampi(maxi(label.font_size, font_size) + 2, 0, 96)
			_play(label, label.global_position, label.font_size)
			return
	if _full(font_size):
		return
	var label := _make(parent, number, color, font_size, at)
	_stacks.append({"label": label, "at": at, "value": number.to_float(), "last": now, "born": now})


## A word over the fight, unless the same one just went up nearby.
static func _callout(parent: Node, text: String, color: Color, font_size: int, at: Vector3, now: float, above: bool) -> void:
	_callouts = _callouts.filter(func(entry: Dictionary) -> bool: return now - entry.time < CALLOUT_GAP)
	for entry in _callouts:
		if entry.text == text and (entry.at as Vector3).distance_to(at) < CALLOUT_DISTANCE:
			return
	if _full(font_size):
		return
	_callouts.append({"text": text, "at": at, "time": now})
	_make(parent, text, color, font_size, at + (Vector3(0, 0.35, 0) if above else Vector3.ZERO))


## Forgets every label (a scene going away, or a test starting clean).
static func reset() -> void:
	_stacks.clear()
	_callouts.clear()
	_live.clear()


static func _full(font_size: int) -> bool:
	return font_size < BIG and _live.size() >= (WEB_MAX_LIVE if Settings.use_web_profile() else MAX_LIVE)


static func _make(parent: Node, text: String, color: Color, font_size: int, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = font_size
	# Same size on screen at any distance.
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_modulate = Color(0.05, 0.02, 0.02)
	label.outline_size = 16
	parent.add_child(label)
	var start := at + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.2), randf_range(-0.2, 0.2))
	label.global_position = start
	_play(label, start, font_size)
	_live.append(label)
	return label


## Pops in big, settles, drifts up and fades. Big numbers pop harder. A stack
## that grows pops again from where it is (drifting less, so it doesn't climb).
static func _play(label: Label3D, start: Vector3, font_size: int) -> void:
	var again := label.has_meta("tween")
	if again:
		var old: Tween = label.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	label.modulate.a = 1.0
	var punch := clampf(font_size / 60.0, 1.0, 1.7)
	label.scale = Vector3.ONE * (1.3 if again else 1.8) * punch
	var drift := Vector3(randf_range(-0.25, 0.25), 0.8, 0) * (0.25 if again else 1.0)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", start + drift, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.tween_callback(label.queue_free)
	label.set_meta("tween", tween)
