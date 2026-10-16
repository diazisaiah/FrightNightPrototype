class_name Minimap
extends Control
## Crypt map. Rooms appear once visited (bright) or next to a visited room
## (dim outline), with icons for chests, elites, the boss and the stairs.
## Small in the corner, centered on the player; Tab shows the whole floor.

const SMALL_SIZE := Vector2(190, 190)
const SMALL_SCALE := 1.6
const LARGE_MARGIN := 80.0
const BACKGROUND := Color(0.02, 0.02, 0.03, 0.75)
const ROOM_COLOR := Color(0.55, 0.52, 0.5)
const KNOWN_COLOR := Color(0.55, 0.52, 0.5, 0.35)
const CORRIDOR_COLOR := Color(0.45, 0.42, 0.4, 0.8)
const CURRENT_COLOR := Color(0.85, 0.8, 0.7)
const PLAYER_COLOR := Color(1.0, 0.9, 0.5)
const ICON_COLORS := {
	"chest": Color(1.0, 0.8, 0.3), "boss": Color(1.0, 0.25, 0.2), "elite": Color(1.0, 0.6, 0.15),
	"stairs": Color(0.7, 0.4, 1.0), "ware": Color(0.85, 0.85, 0.9), "heal": Color(0.9, 0.3, 0.3),
	"shrine": Color(0.6, 0.85, 1.0),
}

## Rooms from the dungeon (shared dictionaries, so visits show up live).
var rooms: Array[Dictionary] = []
var room_at := {}
var extra_icons: Array[Dictionary] = []
var player_position := Vector3.ZERO
var player_yaw := 0.0
var expanded := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_layout()


func set_expanded(on: bool) -> void:
	expanded = on
	_apply_layout()
	queue_redraw()


func _apply_layout() -> void:
	if expanded:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		offset_left = LARGE_MARGIN
		offset_right = -LARGE_MARGIN
		offset_top = LARGE_MARGIN
		offset_bottom = -LARGE_MARGIN
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -SMALL_SIZE.x - 20.0
		offset_right = -20.0
		offset_top = 64.0
		offset_bottom = 64.0 + SMALL_SIZE.y


func update_player(at: Vector3, yaw: float) -> void:
	player_position = at
	player_yaw = yaw
	queue_redraw()


## A room has been seen if it was visited or is next to a visited room.
func _known(room: Dictionary) -> bool:
	if room.visited:
		return true
	for direction in room.doors:
		var neighbor: Dictionary = room_at.get(room.cell + direction, {})
		if not neighbor.is_empty() and neighbor.visited:
			return true
	return false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.15), false, 1.0)
	if rooms.is_empty():
		return
	var scale := SMALL_SCALE
	var origin := Vector2(player_position.x, player_position.z)
	if expanded:
		# Fit every known room.
		var bounds := Rect2()
		var first := true
		for room in rooms:
			if not _known(room):
				continue
			var rect := _room_rect(room)
			bounds = rect if first else bounds.merge(rect)
			first = false
		bounds = bounds.grow(6.0)
		scale = minf(size.x / bounds.size.x, size.y / bounds.size.y)
		origin = bounds.get_center()
	var to_map := func(world: Vector2) -> Vector2:
		return size / 2.0 + (world - origin) * scale
	# Corridors between known rooms.
	for room in rooms:
		if not _known(room):
			continue
		for direction in room.doors:
			if direction.x < 0 or direction.y < 0:
				continue
			var other: Dictionary = room_at[room.cell + direction]
			if not _known(other):
				continue
			var a: Vector2 = to_map.call(Vector2(room.center.x, room.center.z))
			var b: Vector2 = to_map.call(Vector2(other.center.x, other.center.z))
			draw_line(a, b, CORRIDOR_COLOR, maxf(2.0, 3.0 * scale))
	# Rooms, then their icons.
	for room in rooms:
		if not _known(room):
			continue
		var rect := _room_rect(room)
		var map_rect := Rect2(to_map.call(rect.position), rect.size * scale)
		if room.visited:
			var inside := rect.has_point(Vector2(player_position.x, player_position.z))
			draw_rect(map_rect, CURRENT_COLOR if inside else ROOM_COLOR)
			for solid in room.solids:
				var solid_pos: Vector2 = Vector2(room.center.x, room.center.z) + solid.position
				draw_rect(Rect2(to_map.call(solid_pos), solid.size * scale), BACKGROUND)
		else:
			draw_rect(map_rect, KNOWN_COLOR, false, 1.5)
		var icon := ""
		if room.type == "boss":
			icon = "boss"
		elif room.elite and room.state != "cleared":
			icon = "elite"
		elif room.type == "chest" and not room.visited:
			icon = "chest"  # Once visited, the chest itself shows (until opened).
		if icon != "":
			_draw_icon(icon, map_rect.get_center(), maxf(4.0, 5.0 * scale / SMALL_SCALE))
	for icon in extra_icons:
		_draw_icon(icon.kind, to_map.call(Vector2(icon.at.x, icon.at.z)), 4.0)
	# The player: an arrow pointing where they face.
	var center: Vector2 = to_map.call(Vector2(player_position.x, player_position.z))
	var forward := Vector2(-sin(player_yaw), -cos(player_yaw))
	var right := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([
		center + forward * 8.0, center - forward * 5.0 + right * 5.0, center - forward * 5.0 - right * 5.0,
	]), PLAYER_COLOR)


func _room_rect(room: Dictionary) -> Rect2:
	var half: Vector2 = room.size / 2.0
	return Rect2(Vector2(room.center.x, room.center.z) - half, room.size)


func _draw_icon(kind: String, at: Vector2, radius: float) -> void:
	var color: Color = ICON_COLORS[kind]
	match kind:
		"boss":
			draw_circle(at, radius + 1.5, color)
			draw_circle(at, radius * 0.45, BACKGROUND)
		"chest":
			draw_rect(Rect2(at - Vector2(radius, radius * 0.7), Vector2(radius * 2.0, radius * 1.4)), color)
		"elite":
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -radius - 1), at + Vector2(radius + 1, 0),
					at + Vector2(0, radius + 1), at + Vector2(-radius - 1, 0)]), color)
		"ware", "heal", "shrine":
			draw_circle(at, radius * 0.8, color)
		"stairs":
			for i in 3:
				draw_rect(Rect2(at + Vector2(-radius, -radius + i * radius * 0.7), Vector2(radius * 2.0 - i * radius * 0.6, radius * 0.45)), color)
