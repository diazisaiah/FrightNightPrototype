class_name SkillTreeView
extends Control
## A pannable, zoomable web of nodes from GameState.tree(kind), drawn over a
## faint constellation of rings. Each Sigil's branch glows in its power's
## color with the power's name beside it; links light up and carry sparks
## once owned, and a "?" marks where unrevealed nodes wait. Hovering a node
## shows a card with its name and price; buying one bursts it, sends a pulse
## down the link, and springs the newly revealed nodes into view.
## Drag empty space to pan, scroll to zoom, right-click to re-center. The skill
## web is rebuilt whenever the class changes, since each class has its own.

signal node_selected(id: String)
## A node was double-clicked (buy it).
signal node_activated(id: String)

const SPACING := 84.0
## Far enough out to see the whole web (it grew with the seal rings and the
## Endless powers), close enough to read a node.
const MIN_ZOOM := 0.2
const MAX_ZOOM := 2.0
const GRID_SPACING := 28.0
## The powers' colors and names, keyed by their Sigil node: the four
## elements in the corners, the four Endless powers north, east, south, west.
const BRANCHES := {
	"sigil_fire": {"name": "FIRE", "color": Color(1.0, 0.5, 0.16)},
	"sigil_storm": {"name": "STORM", "color": Color(0.6, 0.62, 1.0)},
	"sigil_frost": {"name": "FROST", "color": Color(0.5, 0.92, 1.0)},
	"sigil_blood": {"name": "BLOOD", "color": Color(0.95, 0.24, 0.3)},
	"sigil_quake": {"name": "QUAKE", "color": Color(0.8, 0.62, 0.46)},
	"sigil_gale": {"name": "GALE", "color": Color(0.55, 1.0, 0.75)},
	"sigil_iron": {"name": "IRON", "color": Color(0.78, 0.82, 0.9)},
	"sigil_doom": {"name": "DOOM", "color": Color(0.36, 0.12, 0.55)},
}

## "upgrade" or "skill".
var kind := "upgrade"
var selected_id := ""

var _views := {}
## Node id -> the Sigil branch it grows from ("" for none).
var _branch := {}
var _map: Control
var _links: Control
## What moves: link sparks, the turning "?" dashes and purchase pulses, drawn
## every frame over _links, which only redraws when the web changes
## (2026-10-28: redrawing the whole web every frame held camp to a few fps in
## browsers). Paths cached by the last _links draw.
var _fx: Control
var _spark_paths: Array = []
var _charge_paths := {}
var _unknown_spots: Array = []
var _pan := Vector2.ZERO
var _zoom := 1.0
var _dragging := false
## Once the player pans or zooms, resizes stop re-centering the map.
var _user_moved := false
## Class whose skill web is currently built (skills only).
var _built_for := ""
## Time for the sparks flowing along owned links.
var _flow := 0.0
## Which nodes were showing at the last refresh (to animate new ones in).
var _was_visible := {}
## After the first refresh, newly shown nodes grow in.
var _ready_to_animate := false
## Node id -> 0..1 progress of a pulse running down the links into it.
var _charges := {}
var _hover_card: PanelContainer
var _hover_name: Label
var _hover_level: Label
var _hover_cost: IconLabel
var _hover_id := ""
var _progress_label: Label
var _progress_bar: ProgressBar
var _background: GradientTexture2D
## One grid cell with its dot, tiled across the map in one draw (the web
## used to draw every dot on its own: thousands of draw calls, and the camp
## crawled at 1 fps in browsers).
var _grid_cell: ImageTexture
const GRID_CELL := 32


func _process(delta: float) -> void:
	_flow += delta
	for id in _charges.keys():
		_charges[id] += delta / 0.45
		if _charges[id] >= 1.0:
			_charges.erase(id)
	# Sparks and pulses redraw every frame, or every other frame in the browser
	# (always while a purchase pulse is running). The links themselves only
	# when the web changes (refresh).
	var throttle := Settings.use_web_profile() and _charges.is_empty() and Engine.get_process_frames() % 2 == 1
	if _fx and is_visible_in_tree() and not throttle:
		_fx.queue_redraw()
	if _hover_id != "":
		_place_hover_card()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(tree_kind: String) -> void:
	kind = tree_kind
	var gradient := Gradient.new()
	gradient.set_color(0, Color(accent(), 0.1))
	gradient.set_color(1, Color(0, 0, 0, 0))
	var cell := Image.create(GRID_CELL, GRID_CELL, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	for x in range(-1, 2):
		for y in range(-1, 2):
			if absi(x) + absi(y) < 2:
				cell.set_pixel(GRID_CELL / 2 + x, GRID_CELL / 2 + y, Color(1, 1, 1, 0.035))
	_grid_cell = ImageTexture.create_from_image(cell)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_background = GradientTexture2D.new()
	_background.gradient = gradient
	_background.fill = GradientTexture2D.FILL_RADIAL
	_background.fill_from = Vector2(0.5, 0.5)
	_background.fill_to = Vector2(1.0, 0.5)
	_background.width = 256
	_background.height = 256
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	_links = Control.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.draw.connect(_draw_map)
	_map.add_child(_links)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_map.add_child(_fx)
	_build_nodes()

	_build_progress()
	_build_hover_card()

	resized.connect(_on_resized)
	refresh()
	_ready_to_animate = true


## Gold for the coin web; the fighter's own color for skills.
func accent() -> Color:
	return UiTheme.GOLD if kind == "upgrade" else GameState.fighter_color().lightened(0.15)


func branch_color(id: String) -> Color:
	var branch: String = _branch.get(id, "")
	return BRANCHES[branch].color if branch != "" else accent()


func branch_name(id: String) -> String:
	var branch: String = _branch.get(id, "")
	return BRANCHES[branch].name if branch != "" else ""


func _build_nodes() -> void:
	for id in _views:
		_views[id].queue_free()
	_views.clear()
	_was_visible.clear()
	_built_for = _view_key()
	var nodes := GameState.tree(kind)
	_branch.clear()
	for id in nodes:
		_branch[id] = _find_branch(nodes, id)
	for id in nodes:
		var node: Dictionary = nodes[id]
		# The Trophies show through the center node (GameState.center_stage).
		if node.get("center", false):
			continue
		var view := TreeNodeView.new()
		view.id = id
		view.icon = node.icon
		view.title = node.name
		view.max_level = node.max_level
		view.accent = accent()
		view.tint = branch_color(id)
		var node_shape := "minor"
		if node.requires.is_empty():
			node_shape = "root"
		elif node.get("medallion", false):
			node_shape = "sigil"
		elif node.max_level == 1 and kind != "upgrade":
			node_shape = "keystone"
		view.setup_shape(node_shape)
		view.position = _cell_center(node.pos) - view.size / 2.0
		view.selected.connect(select)
		view.activated.connect(node_activated.emit)
		view.hovered.connect(_on_hovered)
		_map.add_child(view)
		_views[id] = view
	selected_id = nodes.keys()[0]
	if _background:
		_background.gradient.set_color(0, Color(accent(), 0.1))


## Skill webs rebuild for another fighter or passive (nodes adapt to it).
func _view_key() -> String:
	return "%s/%s" % [GameState.player_class, GameState.passive()]


## The Sigil a node grows from, walking back along its requirements.
func _find_branch(nodes: Dictionary, id: String) -> String:
	var current := id
	for i in 20:
		if BRANCHES.has(current):
			return current
		var requires: Array = nodes[current].requires
		if requires.is_empty():
			return ""
		current = requires[0]
	return ""


func select(id: String) -> void:
	selected_id = id
	refresh()
	node_selected.emit(id)


func refresh() -> void:
	if kind == "skill" and _built_for != _view_key():
		_build_nodes()
		recenter()
	var owned := 0
	var total := 0
	var delay := 0.0
	for id in _views:
		var view: TreeNodeView = _views[id]
		view.level = GameState.node_level(kind, id)
		view.state = GameState.node_state(kind, id)
		view.affordable = GameState.can_buy_node(kind, id)
		view.sealed_by = GameState.node_sealed_by(kind, id)
		if kind == "upgrade" and id == GameState.CENTER_STAGES[0]:
			var stage := GameState.center_stage()
			var levels := GameState.center_levels()
			view.icon = GameState.UPGRADES[stage].icon
			view.title = GameState.UPGRADES[stage].name
			view.max_level = levels.y
			view.level = levels.x
			view.state = "maxed" if levels.x >= levels.y else ("owned" if levels.x > 0 else "available")
			view.affordable = GameState.can_buy_node(kind, stage)
		view.is_selected = id == selected_id
		view.visible = view.state != "hidden"
		if view.visible and not _was_visible.get(id, false) and _ready_to_animate:
			view.reveal(0.25 + delay)
			delay += 0.08
		_was_visible[id] = view.visible
		view.refresh()
		total += 1
		if view.level > 0:
			owned += 1
	if _progress_label:
		_progress_label.text = "%d / %d" % [owned, total]
		_progress_bar.max_value = total
		_progress_bar.value = owned
	if _hover_id != "":
		_fill_hover_card(_hover_id)
	_links.queue_redraw()


## A node was just bought: burst it and run a pulse down the link into it.
func celebrate(id: String) -> void:
	if kind == "upgrade" and id in GameState.CENTER_STAGES:
		var level := GameState.node_level(kind, id)
		var max_level := int(GameState.UPGRADES[id].max_level)
		_views[GameState.CENTER_STAGES[0]].celebrate("MAX" if level >= max_level else "LV %d" % GameState.center_levels().x)
		return
	if not _views.has(id):
		return
	var level := GameState.node_level(kind, id)
	var node: Dictionary = GameState.tree(kind)[id]
	var text := "MAX" if level >= node.max_level and node.max_level > 1 else ("UNLOCKED" if node.max_level == 1 else "LV %d" % level)
	if BRANCHES.has(id) and level == 1:
		text = BRANCHES[id].name + " AWAKENS"
	_views[id].celebrate(text)
	_charges[id] = 0.0


## Can't buy it: the node shakes red.
func deny(id: String) -> void:
	if kind == "upgrade" and id in GameState.CENTER_STAGES:
		id = GameState.CENTER_STAGES[0]
	if _views.has(id):
		_views[id].deny()


## Frames the revealed part of the web: centered, zoomed out (not in) to fit.
func recenter() -> void:
	_user_moved = false
	var bounds := Rect2()
	var first := true
	for id in _views:
		var view: TreeNodeView = _views[id]
		if GameState.node_state(kind, id) == "hidden":
			continue
		var at := _cell_center(GameState.tree(kind)[id].pos)
		if first:
			bounds = Rect2(at, Vector2.ZERO)
			first = false
		else:
			bounds = bounds.expand(at)
	# Room for the nodes themselves, the "?" beyond them, and the overlays.
	bounds = bounds.grow_individual(SPACING * 0.9 + 60.0, SPACING * 0.9, SPACING * 0.9 + 60.0, SPACING * 0.9)
	var room := size - Vector2(40, 90)
	_zoom = 1.0
	if bounds.size.x > 0.0 and bounds.size.y > 0.0 and room.x > 0.0 and room.y > 0.0:
		_zoom = clampf(minf(room.x / bounds.size.x, room.y / bounds.size.y), 0.35, 1.0)
	_pan = size / 2.0 + Vector2(0, 6) - bounds.get_center() * _zoom
	_apply_transform()


func _on_resized() -> void:
	if not _user_moved:
		recenter()


func _cell_center(cell: Vector2) -> Vector2:
	return cell * SPACING


func _apply_transform() -> void:
	_map.position = _pan
	_map.scale = Vector2.ONE * _zoom
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(event.position, 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					recenter()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_user_moved = true
		_pan += event.relative
		_apply_transform()
		accept_event()


func _zoom_at(point: Vector2, factor: float) -> void:
	_user_moved = true
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	# Keep the point under the cursor fixed while zooming.
	_pan = point - (point - _pan) * (new_zoom / _zoom)
	_zoom = new_zoom
	_apply_transform()


# --- Drawing ---------------------------------------------------------------------

func _draw() -> void:
	# A soft glow of the web's color around the center node.
	var glow_radius := 520.0 * _zoom
	draw_texture_rect(_background, Rect2(_pan - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0), false)
	# Dot grid that moves with the map: one tiled draw.
	var step := GRID_SPACING * _zoom
	var scale := step / GRID_CELL
	var offset := Vector2(fposmod(_pan.x, step), fposmod(_pan.y, step)) - Vector2.ONE * step * 1.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale)
	draw_texture_rect(_grid_cell, Rect2(Vector2.ZERO, (size + Vector2.ONE * step * 3.0) / scale), true)
	draw_set_transform(Vector2.ZERO)


## Everything under the nodes, in map coordinates: rings, branch glows and
## names, links, and the "?" of nodes still to find.
func _draw_map() -> void:
	var tree: Dictionary = GameState.tree(kind)
	var color := accent()
	# The upgrade web's seal rings: every node sits on the ring of the seal
	# that opens it, brighter once that seal is broken.
	if kind == "upgrade":
		for ring in range(1, 7):
			var open := ring <= Progression.open_ring()
			var radius := (ring + 0.5) * SPACING
			var segments := 72
			# Every other segment, as one batch of lines.
			var dashes := PackedVector2Array()
			for i in segments:
				if i % 2 == 0:
					for k in 4:
						dashes.append(Vector2.from_angle(TAU * (i + k / 4.0) / segments) * radius)
						dashes.append(Vector2.from_angle(TAU * (i + (k + 1) / 4.0) / segments) * radius)
			_links.draw_multiline(dashes, Color(color, 0.16 if open else 0.06), 1.5, true)
	# Constellation rings and spokes around the center (fighter skill webs).
	for ring in ([] if kind == "upgrade" else [1.5, 3.0, 4.5]):
		var radius: float = ring * SPACING
		_links.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(color, 0.05), 1.0, true)
		for i in 24:
			var a: float = TAU * i / 24.0 + ring
			var dir := Vector2.from_angle(a)
			_links.draw_line(dir * (radius - 3.0), dir * (radius + 3.0), Color(color, 0.08), 1.0)
	for i in (0 if kind == "upgrade" else 8):
		var dir := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		_links.draw_dashed_line(dir * 40.0, dir * 4.8 * SPACING, Color(color, 0.035), 1.0, 6.0)

	# Branch clouds behind each power's revealed nodes, and the power's name.
	for id in tree:
		var branch: String = _branch[id]
		if branch == "" or not _views.has(id) or not _views[id].visible:
			continue
		var tint: Color = BRANCHES[branch].color
		var owned_node := GameState.node_level(kind, id) > 0
		var at := _cell_center(tree[id].pos)
		_links.draw_circle(at, 48.0, Color(tint, 0.06 if owned_node else 0.03))
	for branch in BRANCHES:
		if not tree.has(branch) or not _views[branch].visible:
			continue
		var at := _cell_center(tree[branch].pos)
		var font := UiTheme.display_font()
		var label: String = BRANCHES[branch].name
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		# The name sits between the Sigil and the core (every diamond points
		# straight out, its branches filling the other sides).
		var away := -at.normalized() if at.length() > 1.0 else Vector2.UP
		var reach: float = _views[branch].extent() / 2.0 + 16.0 + absf(away.x) * label_size.x / 2.0 + absf(away.y) * 12.0
		var spot: Vector2 = at + away * reach + Vector2(-label_size.x / 2.0, 8.0)
		var tint: Color = BRANCHES[branch].color
		var lit := GameState.node_level(kind, branch) > 0
		_links.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(tint, 0.55 if lit else 0.25))

	# Links. Owned ones are batched by color (a polyline each cost two draws
	# per link). Their paths are kept for _draw_fx.
	var batches := {}
	_spark_paths.clear()
	_charge_paths.clear()
	_unknown_spots.clear()
	for id in tree:
		if not _views.has(id):
			continue
		var view: TreeNodeView = _views[id]
		var owned := GameState.node_level(kind, id) > 0
		var tint := branch_color(id)
		for required in tree[id].requires:
			var from_view: TreeNodeView = _views[required]
			if not from_view.visible:
				continue
			# Along the ring when both sit on it, else straight (the seal rings
			# never cut a link across on a slant).
			var path := _link_path(_cell_center(tree[required].pos), _cell_center(tree[id].pos))
			var out_dir := (path[1] - path[0]).normalized()
			var in_dir := (path[path.size() - 1] - path[path.size() - 2]).normalized()
			if not view.visible:
				# Not revealed yet: a faint dashed line to a "?".
				var faint := _trim_path(path, _inset(from_view, out_dir) + 4.0, 18.0)
				_dashed_path(faint, Color(0.6, 0.6, 0.7, 0.18), 1.5, 4.0)
				_draw_unknown(path[path.size() - 1])
				continue
			var trimmed := _trim_path(path, _inset(from_view, out_dir) + 4.0, _inset(view, in_dir) + 4.0)
			var tip: Vector2 = trimmed[trimmed.size() - 1]
			var shaft := _trim_path(trimmed, 0.0, 6.0)
			if owned:
				# A soft glow under owned links, with sparks flowing along them.
				_batch(batches, [Color(tint, 0.2), 9.0], shaft)
				_batch(batches, [tint.lightened(0.2), 2.5], shaft)
				_spark_paths.append([trimmed, _path_length(trimmed)])
			else:
				var ready := GameState.can_buy_node(kind, id)
				var line_color := Color(UiTheme.READY, 0.55) if ready else Color(0.6, 0.6, 0.7, 0.4)
				_dashed_path(shaft, line_color, 2.0, 7.0)
			# For the bright pulse running into a node that was just bought.
			_charge_paths[id] = [trimmed, tint]
			var link_color := tint.lightened(0.2) if owned else Color(0.6, 0.6, 0.7, 0.45)
			var direction := (tip - trimmed[trimmed.size() - 2]).normalized()
			var side := Vector2(-direction.y, direction.x) * 5.0
			_links.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 9.0 + side, tip - direction * 9.0 - side]), link_color)
	# The owned links' glows, then their cores on top.
	for glow in [true, false]:
		for key in batches:
			if (float(key[1]) > 5.0) == glow:
				_links.draw_multiline(batches[key], key[0], key[1], true)


## Adds a path's segments to a batch keyed by [color, width].
func _batch(batches: Dictionary, key: Array, points: PackedVector2Array) -> void:
	if not batches.has(key):
		batches[key] = PackedVector2Array()
	var segments: PackedVector2Array = batches[key]
	for i in points.size() - 1:
		segments.append(points[i])
		segments.append(points[i + 1])
	batches[key] = segments


## A link's points: an arc when both ends sit on the same seal ring of the
## upgrade web, otherwise a straight line.
func _link_path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var ra := a.length()
	var rb := b.length()
	if kind != "upgrade" or ra < SPACING * 0.5 or absf(ra - rb) > SPACING * 0.1:
		return PackedVector2Array([a, b])
	var from := a.angle()
	var sweep := wrapf(b.angle() - from, -PI, PI)
	var steps := maxi(2, ceili(absf(sweep) * ra / 8.0))
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(Vector2.from_angle(from + sweep * i / steps) * ra)
	return points


func _path_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total


## The point a share t (0-1) of the way along a path.
func _point_along(points: PackedVector2Array, t: float) -> Vector2:
	var goal := _path_length(points) * clampf(t, 0.0, 1.0)
	for i in points.size() - 1:
		var step := points[i].distance_to(points[i + 1])
		if goal <= step:
			return points[i].lerp(points[i + 1], goal / maxf(step, 0.001))
		goal -= step
	return points[points.size() - 1]


## A path with head pixels cut off its start and tail off its end.
func _trim_path(points: PackedVector2Array, head: float, tail: float) -> PackedVector2Array:
	var length := _path_length(points)
	if length <= head + tail + 1.0:
		var mid := _point_along(points, 0.5)
		return PackedVector2Array([mid, mid + (points[points.size() - 1] - points[0]).normalized()])
	var out := PackedVector2Array([_point_along(points, head / length)])
	var walked := 0.0
	for i in points.size() - 1:
		walked += points[i].distance_to(points[i + 1])
		if walked > head and walked < length - tail:
			out.append(points[i + 1])
	out.append(_point_along(points, (length - tail) / length))
	return out


## Dashes along a path, the pattern running on through its bends (one draw).
func _dashed_path(points: PackedVector2Array, color: Color, width: float, dash: float) -> void:
	var length := _path_length(points)
	var dashes := PackedVector2Array()
	var at := 0.0
	while at < length:
		dashes.append(_point_along(points, at / length))
		dashes.append(_point_along(points, minf(at + dash, length) / length))
		at += dash * 2.0
	if not dashes.is_empty():
		_links.draw_multiline(dashes, color, width, true)


## How far from a node's center its edge is, along direction.
func _inset(view: TreeNodeView, direction: Vector2) -> float:
	var half := view.extent() / 2.0
	if view.shape in ["root", "sigil"]:
		return half
	# Diagonal links leave from the box corner, straight ones from the edge.
	return half * (1.41 if absf(direction.x) > 0.1 and absf(direction.y) > 0.1 else 1.0)


## An unrevealed node: a faint dashed circle with a question mark.
func _draw_unknown(at: Vector2) -> void:
	_unknown_spots.append(at)
	var font := UiTheme.display_font()
	var mark_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	_links.draw_string(font, at + Vector2(-mark_size.x / 2.0, 7.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.85, 0.45))


## What moves, every frame: two sparks along each owned link, the "?"
## markers' turning dashes, and the pulse into a node just bought. A few
## draws in all.
func _draw_fx() -> void:
	var sparks := PackedVector2Array()
	for entry in _spark_paths:
		var points: PackedVector2Array = entry[0]
		var length: float = entry[1]
		for k in 2:
			var t := fposmod(_flow * 60.0 / maxf(length, 1.0) + k * 0.5, 1.0)
			var reach := 2.2 * sin(t * PI) / maxf(length, 1.0)
			sparks.append(_point_along(points, clampf(t - reach, 0.0, 1.0)))
			sparks.append(_point_along(points, clampf(t + reach, 0.0, 1.0)))
	if not sparks.is_empty():
		_fx.draw_multiline(sparks, Color(1, 0.95, 0.8, 0.85), 4.5, true)
	var dashes := PackedVector2Array()
	for at: Vector2 in _unknown_spots:
		for i in 10:
			var a := TAU * i / 10.0 + _flow * 0.3
			for k in 3:
				dashes.append(at + Vector2.from_angle(a + TAU / 20.0 * k / 3.0) * 16.0)
				dashes.append(at + Vector2.from_angle(a + TAU / 20.0 * (k + 1) / 3.0) * 16.0)
	if not dashes.is_empty():
		_fx.draw_multiline(dashes, Color(0.7, 0.7, 0.8, 0.25 + 0.1 * (0.5 + 0.5 * sin(_flow * 2.0))), 1.5, true)
	for id in _charges:
		if not _charge_paths.has(id):
			continue
		var t: float = _charges[id]
		var p := _point_along(_charge_paths[id][0], t)
		_fx.draw_circle(p, 9.0 * (1.0 - t * 0.5), Color((_charge_paths[id][1] as Color).lightened(0.5), 0.35))
		_fx.draw_circle(p, 4.0, Color(1, 1, 1, 0.95))


# --- Overlay: progress, legend, hover card ---------------------------------------

func _build_progress() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Room for three-digit counts ("UPGRADES OWNED  120 / 160"); grows left
	# if it needs more.
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_left = -270.0
	box.offset_right = -14.0
	box.offset_top = 8.0
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var caption := Label.new()
	caption.text = "UPGRADES OWNED  " if kind == "upgrade" else "SKILLS LEARNED  "
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", UiTheme.MUTED)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	_progress_label = Label.new()
	_progress_label.add_theme_font_override("font", UiTheme.display_font())
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", accent())
	row.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size.y = 5
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UiTheme.box(accent(), Color.TRANSPARENT, 0, 3)
	_progress_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_progress_bar)


func _build_legend() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	row.offset_left = 14.0
	row.offset_top = -30.0
	row.offset_bottom = -10.0
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var entries := [["Owned", accent()], ["Can buy", UiTheme.READY], ["Can't afford", Color(0.45, 0.43, 0.5)]]
	entries.append(["Sealed", UiTheme.SIGIL])
	for entry in entries:
		var swatch := Control.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch_color: Color = entry[1]
		swatch.draw.connect(func() -> void:
			swatch.draw_style_box(UiTheme.box(swatch_color.darkened(0.6), swatch_color, 2, 3), Rect2(Vector2.ZERO, swatch.size)))
		row.add_child(swatch)
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", UiTheme.MUTED)
		row.add_child(label)


func _build_hover_card() -> void:
	_hover_card = PanelContainer.new()
	_hover_card.add_theme_stylebox_override("panel", UiTheme.raised(Color(0.04, 0.035, 0.05, 0.95), Color(accent(), 0.5), 1, 8, 10.0, 8))
	_hover_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.visible = false
	add_child(_hover_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_card.add_child(box)
	_hover_name = UiTheme.title_label("", 18)
	box.add_child(_hover_name)
	_hover_level = Label.new()
	_hover_level.add_theme_font_size_override("font_size", 12)
	box.add_child(_hover_level)
	_hover_cost = IconLabel.new()
	_hover_cost.font_size = 15
	_hover_cost.outline = 3
	_hover_cost.alignment_h = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(_hover_cost)


func _on_hovered(id: String, on: bool) -> void:
	if on:
		_hover_id = id
		_fill_hover_card(id)
		_hover_card.visible = true
		_hover_card.reset_size()
		_place_hover_card()
	elif _hover_id == id:
		_hover_id = ""
		_hover_card.visible = false


func _fill_hover_card(id: String) -> void:
	id = GameState.shown_node(kind, id)
	var node: Dictionary = GameState.tree(kind)[id]
	var level := GameState.node_level(kind, id)
	var tint := branch_color(id)
	_hover_name.text = node.name
	_hover_name.add_theme_color_override("font_color", tint.lightened(0.3) if level > 0 else UiTheme.TEXT)
	var where := branch_name(id)
	var level_text := ("Level %d / %d" % [level, node.max_level]) if node.max_level > 1 else ("Owned" if level > 0 else "Not owned")
	_hover_level.text = ("%s POWER  ·  %s" % [where, level_text]) if where != "" else level_text
	_hover_level.add_theme_color_override("font_color", tint if where != "" else UiTheme.MUTED)
	if level >= node.max_level:
		_hover_cost.color = UiTheme.GOOD
		_hover_cost.text = "Maxed out"
		return
	var holder := GameState.node_sealed_by(kind, id)
	if holder != "":
		_hover_cost.color = UiTheme.SIGIL.lightened(0.2)
		_hover_cost.text = "SEALED  -  %s" % GameState.node_seal_text(kind, id)
		return
	var cost := GameState.node_cost(kind, id)
	var currency := "coins" if kind == "upgrade" else "skill_points"
	var text := "%d {%s}" % [cost, currency]
	_hover_cost.color = UiTheme.TEXT if GameState.can_buy_node(kind, id) else UiTheme.BAD.lightened(0.15)
	_hover_cost.text = text


func _place_hover_card() -> void:
	if not _views.has(_hover_id):
		return
	var view: TreeNodeView = _views[_hover_id]
	var node_rect := view.get_global_rect()
	var spot := node_rect.position - global_position + Vector2(node_rect.size.x + 12.0, -6.0)
	var card := _hover_card.get_combined_minimum_size()
	if spot.x + card.x > size.x - 8.0:
		spot.x = node_rect.position.x - global_position.x - card.x - 12.0
	spot.y = clampf(spot.y, 8.0, size.y - card.y - 8.0)
	_hover_card.position = spot
