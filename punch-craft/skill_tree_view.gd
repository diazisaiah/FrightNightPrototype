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
const MIN_ZOOM := 0.5
const MAX_ZOOM := 1.6
const GRID_SPACING := 28.0
## The four powers' colors and names, keyed by their Sigil node.
const BRANCHES := {
	"sigil_fire": {"name": "FIRE", "color": Color(1.0, 0.5, 0.16)},
	"sigil_storm": {"name": "STORM", "color": Color(0.6, 0.62, 1.0)},
	"sigil_frost": {"name": "FROST", "color": Color(0.5, 0.92, 1.0)},
	"sigil_blood": {"name": "BLOOD", "color": Color(0.95, 0.24, 0.3)},
}

## "upgrade" or "skill".
var kind := "upgrade"
var selected_id := ""

var _views := {}
## Node id -> the Sigil branch it grows from ("" for none).
var _branch := {}
var _map: Control
var _links: Control
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


func _process(delta: float) -> void:
	_flow += delta
	for id in _charges.keys():
		_charges[id] += delta / 0.45
		if _charges[id] >= 1.0:
			_charges.erase(id)
	# Link sparks redraw every frame, or every other frame in the browser
	# (always while a purchase pulse is running).
	var throttle := Settings.use_web_profile() and _charges.is_empty() and Engine.get_process_frames() % 2 == 1
	if _links and is_visible_in_tree() and not throttle:
		_links.queue_redraw()
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
		elif node.max_level == 1:
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
		_zoom = clampf(minf(room.x / bounds.size.x, room.y / bounds.size.y), 0.7, 1.0)
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
					_zoom_at(event.position, 1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
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
	# Dot grid that moves with the map.
	var dot := Color(1, 1, 1, 0.035)
	var step := GRID_SPACING * _zoom
	var offset := Vector2(fposmod(_pan.x, step), fposmod(_pan.y, step))
	var x := offset.x
	while x < size.x:
		var y := offset.y
		while y < size.y:
			draw_circle(Vector2(x, y), 1.1, dot)
			y += step
		x += step


## Everything under the nodes, in map coordinates: rings, branch glows and
## names, links, and the "?" of nodes still to find.
func _draw_map() -> void:
	var tree: Dictionary = GameState.tree(kind)
	var color := accent()
	# Constellation rings and spokes around the center.
	for ring in [1.5, 3.0, 4.5]:
		var radius: float = ring * SPACING
		_links.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(color, 0.05), 1.0, true)
		for i in 24:
			var a: float = TAU * i / 24.0 + ring
			var dir := Vector2.from_angle(a)
			_links.draw_line(dir * (radius - 3.0), dir * (radius + 3.0), Color(color, 0.08), 1.0)
	for i in 8:
		var dir := Vector2.from_angle(TAU * i / 8.0 + PI / 8.0)
		_links.draw_dashed_line(dir * 40.0, dir * 4.8 * SPACING, Color(color, 0.035), 1.0, 6.0)

	# Branch clouds behind each power's revealed nodes, and the power's name.
	for id in tree:
		var branch: String = _branch[id]
		if branch == "" or not _views[id].visible:
			continue
		var tint: Color = BRANCHES[branch].color
		var owned_node := GameState.node_level(kind, id) > 0
		var at := _cell_center(tree[id].pos)
		for k in 3:
			_links.draw_circle(at, 64.0 - k * 16.0, Color(tint, (0.03 if owned_node else 0.015) * (k + 1)))
	for branch in BRANCHES:
		if not tree.has(branch) or not _views[branch].visible:
			continue
		var at := _cell_center(tree[branch].pos)
		var font := UiTheme.display_font()
		var label: String = BRANCHES[branch].name
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		# Corner powers: the name sits on the side toward the middle (its
		# branches fill the other sides).
		var away := Vector2(-signf(at.x), 0.0) if absf(at.x) > 1.0 and absf(at.y) > 1.0 else (at.normalized() if at.length() > 1.0 else Vector2.UP)
		var reach: float = _views[branch].extent() / 2.0 + 16.0 + absf(away.x) * label_size.x / 2.0 + absf(away.y) * 12.0
		var spot: Vector2 = at + away * reach + Vector2(-label_size.x / 2.0, 8.0)
		var tint: Color = BRANCHES[branch].color
		var lit := GameState.node_level(kind, branch) > 0
		_links.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(tint, 0.55 if lit else 0.25))

	# Links.
	for id in tree:
		var view: TreeNodeView = _views[id]
		var owned := GameState.node_level(kind, id) > 0
		var tint := branch_color(id)
		for required in tree[id].requires:
			var from_view: TreeNodeView = _views[required]
			if not from_view.visible:
				continue
			var a := _cell_center(tree[required].pos)
			var b := _cell_center(tree[id].pos)
			var direction := (b - a).normalized()
			var start := a + direction * (_inset(from_view, direction) + 4.0)
			var tip := b - direction * (_inset(view, direction) + 4.0)
			if not view.visible:
				# Not revealed yet: a faint dashed line to a "?".
				_links.draw_dashed_line(start, b - direction * 18.0, Color(0.6, 0.6, 0.7, 0.18), 1.5, 4.0)
				_draw_unknown(b)
				continue
			if owned:
				# A soft glow under owned links, with sparks flowing along them.
				_links.draw_line(start, tip - direction * 6.0, Color(tint, 0.2), 9.0, true)
				var length := start.distance_to(tip)
				for k in 2:
					var t := fposmod(_flow * 60.0 / maxf(length, 1.0) + k * 0.5, 1.0)
					_links.draw_circle(start.lerp(tip, t), 2.6, Color(1, 0.95, 0.8, 0.9 * sin(t * PI)))
				_links.draw_line(start, tip - direction * 6.0, tint.lightened(0.2), 2.5, true)
			else:
				var ready := GameState.can_buy_node(kind, id)
				var line_color := Color(UiTheme.READY, 0.55) if ready else Color(0.6, 0.6, 0.7, 0.4)
				_links.draw_dashed_line(start, tip - direction * 6.0, line_color, 2.0, 7.0)
			# A bright pulse running into a node that was just bought.
			if _charges.has(id):
				var t: float = _charges[id]
				var p := start.lerp(tip, t)
				_links.draw_circle(p, 9.0 * (1.0 - t * 0.5), Color(tint.lightened(0.5), 0.35))
				_links.draw_circle(p, 4.0, Color(1, 1, 1, 0.95))
			var link_color := tint.lightened(0.2) if owned else Color(0.6, 0.6, 0.7, 0.45)
			var side := Vector2(-direction.y, direction.x) * 5.0
			_links.draw_colored_polygon(PackedVector2Array([tip, tip - direction * 9.0 + side, tip - direction * 9.0 - side]), link_color)


## How far from a node's center its edge is, along direction.
func _inset(view: TreeNodeView, direction: Vector2) -> float:
	var half := view.extent() / 2.0
	if view.shape in ["root", "sigil"]:
		return half
	# Diagonal links leave from the box corner, straight ones from the edge.
	return half * (1.41 if absf(direction.x) > 0.1 and absf(direction.y) > 0.1 else 1.0)


## An unrevealed node: a faint dashed circle with a question mark.
func _draw_unknown(at: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_flow * 2.0 + at.x * 0.02)
	for i in 10:
		var a := TAU * i / 10.0 + _flow * 0.3
		_links.draw_arc(at, 16.0, a, a + TAU / 20.0, 4, Color(0.7, 0.7, 0.8, 0.25 + pulse * 0.1), 1.5, true)
	var font := UiTheme.display_font()
	var mark_size := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	_links.draw_string(font, at + Vector2(-mark_size.x / 2.0, 7.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.75, 0.85, 0.35 + pulse * 0.15))


# --- Overlay: progress, legend, hover card ---------------------------------------

func _build_progress() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -170.0
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
		_hover_cost.text = "SEALED  -  beat %s" % holder
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
