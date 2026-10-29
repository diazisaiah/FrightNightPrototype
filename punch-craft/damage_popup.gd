class_name DamagePopup
## Floating text that rises and fades, used for damage numbers.
##
## Numbers stack (2026-10-29: echoes, powers, chains and burns buried the
## screen): a number ("12.3", or a caption over one, "ECHO\n4.1") landing
## within MERGE_DISTANCE of a live one with the same caption and color, within
## MERGE_GAP of its last hit, adds to it instead of popping its own, for up to
## MERGE_LIFE.

const MERGE_DISTANCE := 1.2
const MERGE_GAP := 0.4
const MERGE_LIFE := 1.6

## Live stacks: {label, caption, color, at, value, last, born} (seconds).
static var _stacks: Array = []


static func spawn(parent: Node, text: String, color: Color, font_size: int, at: Vector3) -> void:
	var lines := text.split("\n")
	var number := String(lines[lines.size() - 1])
	# (Heals, "+12", pop on their own.)
	var stacks := number.is_valid_float() and not number.begins_with("+")
	var caption := "\n".join(lines.slice(0, lines.size() - 1)) if stacks else ""
	var now := Time.get_ticks_msec() / 1000.0
	if stacks:
		_stacks = _stacks.filter(func(stack: Dictionary) -> bool:
			return is_instance_valid(stack.label) and now - stack.born < MERGE_LIFE)
		for stack in _stacks:
			if stack.caption == caption and stack.color == color and now - stack.last < MERGE_GAP \
					and (stack.at as Vector3).distance_to(at) < MERGE_DISTANCE:
				stack.value += number.to_float()
				stack.last = now
				var label: Label3D = stack.label
				label.text = ("%s\n%.1f" % [caption, stack.value]) if caption != "" else "%.1f" % stack.value
				label.font_size = maxi(label.font_size, font_size)
				_play(label, label.global_position, label.font_size)
				return
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
	if stacks:
		_stacks.append({"label": label, "caption": caption, "color": color, "at": at,
				"value": number.to_float(), "last": now, "born": now})


## Pops in big, settles, drifts up and fades. Big numbers pop harder. A stack
## that grows pops again from where it is.
static func _play(label: Label3D, start: Vector3, font_size: int) -> void:
	if label.has_meta("tween"):
		var old: Tween = label.get_meta("tween")
		if old and old.is_valid():
			old.kill()
	label.modulate.a = 1.0
	var punch := clampf(font_size / 60.0, 1.0, 1.7)
	label.scale = Vector3.ONE * 1.8 * punch
	var drift := Vector3(randf_range(-0.25, 0.25), 0.8, 0)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "global_position", start + drift, 0.8) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tween.tween_callback(label.queue_free)
	label.set_meta("tween", tween)
