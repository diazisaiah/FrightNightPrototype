class_name ProjectileWarn
extends Control
## The side-of-screen warning for shots you can't see (2026-11-06). While the
## view is locked on, anything flying at you (arrows, fireballs, a Bone
## Sniper's draw) puts a little plate on the edge of the screen it's coming
## from: chevrons pointing out toward it, its color in the glow, swelling as it
## closes in. When it's time to slip (Threat.SLIP_NOW) the plate turns red,
## pulses fast and says SLIP. Shots out in front, in view, don't need one.

const FRONT_CONE := deg_to_rad(24.0)
const PLATE := Vector2(74, 104)
const RED := Color(1.0, 0.18, 0.12)

var _time := 0.0
var _plates: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	_plates = _gather()
	queue_redraw()


## [{side: -1 | 1, behind: 0-1, time, color}] for the shots to show, nearest first.
func _gather() -> Array:
	var out: Array = []
	var player := get_tree().get_first_node_in_group("fight_player") as Player
	if player == null or not player.active or get_tree().paused:
		return out
	if player.lock == null or not player.lock.in_combat():
		return out
	var camera := get_viewport().get_camera_3d()
	if camera == null or camera.is_in_group("emote_cam"):
		return out
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		return out
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var here := player.global_position + Vector3(0, 1.2, 0)
	for node in get_tree().get_nodes_in_group("threats"):
		if not is_instance_valid(node) or not node.has_method("threat"):
			continue
		var info: Dictionary = node.threat(here)
		if info.is_empty() or float(info.time) > Threat.SHOW_WITHIN:
			continue
		var offset: Vector3 = info.from - here
		offset.y = 0.0
		if offset.length() < 0.01:
			continue
		offset = offset.normalized()
		var angle := atan2(offset.dot(right), offset.dot(forward))  # 0 ahead, + to the right.
		if absf(angle) < FRONT_CONE:
			continue  # You can see it coming.
		out.append({"side": 1.0 if angle > 0.0 else -1.0, "behind": clampf((absf(angle) - FRONT_CONE) / (PI - FRONT_CONE), 0.0, 1.0),
			"time": info.time, "color": info.color})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.time < b.time)
	return out.slice(0, 4)


func _draw() -> void:
	var taken := {}
	for plate in _plates:
		var side: float = plate.side
		# Plates on the same side stack lower rather than overlap.
		var slot := int(taken.get(side, 0))
		taken[side] = slot + 1
		var y := size.y * lerpf(0.3, 0.52, plate.behind) + slot * (PLATE.y + 8.0)
		var urgency := clampf(1.0 - float(plate.time) / Threat.SHOW_WITHIN, 0.0, 1.0)
		var now: bool = float(plate.time) <= Threat.SLIP_NOW
		var beat := 0.5 + 0.5 * sin(_time * (26.0 if now else 9.0 * (0.4 + urgency)))
		var tint: Color = RED if now else Color(plate.color).lerp(Color(1.0, 0.8, 0.3), 0.5)
		var grow := 1.0 + 0.12 * urgency + (0.1 * beat if now else 0.0)
		var plate_size := PLATE * grow
		var x := 10.0 if side < 0.0 else size.x - 10.0 - plate_size.x
		var rect := Rect2(Vector2(x, y), plate_size)
		# The glow, then the leather plate (dyed to the warning's color).
		for i in 4:
			var spread := 5.0 + i * 7.0
			draw_style_box(UiTheme.box(Color(tint, (0.14 + 0.2 * beat * float(now) + 0.1 * urgency) * (1.0 - i * 0.22)), Color.TRANSPARENT, 0, int(14 + spread)), rect.grow(spread))
		draw_style_box(StitchPanel.leather(12.0, 0.0, tint.darkened(0.15)), rect)
		StitchPanel.dashed_rect(self, rect.grow(-4.0), 8.0, Color(tint.lightened(0.5), 0.8 if now else 0.5))
		# Chevrons pointing out to the edge it comes from, three of them,
		# the nearest lighting first as it closes.
		var mid := rect.get_center()
		var out := side
		for k in 3:
			var cx := mid.x + out * (6.0 + k * 10.0) * grow - out * 4.0
			var lit := clampf(urgency * 3.0 - (2 - k), 0.0, 1.0) if not now else 1.0
			var line_color := Color(1.0, 0.9, 0.85, 0.25 + 0.75 * lit) if now else Color(tint.lightened(0.45), 0.25 + 0.75 * lit)
			var h := 15.0 * grow
			draw_polyline(PackedVector2Array([Vector2(cx - out * 7.0, mid.y - 12.0 - h * 0.35), Vector2(cx + out * 3.0, mid.y - 12.0), Vector2(cx - out * 7.0, mid.y - 12.0 + h * 0.35)]), line_color, 3.0, true)
		var font := UiTheme.display_font()
		var label := "SLIP!" if now else "%.1f" % float(plate.time)
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at := Vector2(mid.x - width / 2.0, rect.end.y - 16.0)
		draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.9))
		draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1) if now else Color(0.95, 0.9, 0.8))
