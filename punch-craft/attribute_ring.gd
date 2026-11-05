class_name AttributeRing
extends Control
## The Fighter page's attribute ring (camp pass 2, 2026-11-05): the same
## near-transparent look as the Upgrades web. Your fighter stands in the
## middle (the live voxel body, small enough that no node covers the head),
## the five attributes are glowing round nodes round them, each with three
## perk dots (10, 20, 30 points) that light up. Tap a node to select it, the
## fighter for their stats. camp.gd shows the detail beside it.

signal picked(attribute: String)

const NODE_RADIUS := 40.0
## The fighter's camera: further back than the Soul Shop's, so the body is
## small and the top node clears the head.
const FIGHTER_DISTANCE := 7.0

## "" selects the fighter (stats).
var selected := "power"

var _preview: Control
var _hover := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	visibility_changed.connect(_on_visible)
	_on_visible()


## The body is built the first time the page is shown (building six hundred
## cubes at camp start-up would hitch it for nothing).
func _on_visible() -> void:
	if is_visible_in_tree() and _preview == null:
		_preview = EmotePreview.new(GameState.player_class, FIGHTER_DISTANCE, "auto", 0.92)
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_preview)
		move_child(_preview, 0)
		_place_preview()


func refresh() -> void:
	queue_redraw()


# --- Layout --------------------------------------------------------------------------

func _scale() -> float:
	return clampf(minf(size.x / 760.0, size.y / 560.0), 0.6, 1.25)


func _centre() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 + 24.0 * _scale())


## Where each attribute's node sits: round an ellipse, the first at the top.
func _node_at(index: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * index / float(Attributes.LIST.size())
	var s := _scale()
	var rx := minf(size.x * 0.36, 275.0 * s)
	var ry := minf(size.y * 0.34, 205.0 * s)
	return _centre() + Vector2(cos(angle) * rx, sin(angle) * ry)


func _place_preview() -> void:
	if _preview == null:
		return
	var s := _scale()
	_preview.size = Vector2(340, 430) * s
	_preview.position = _centre() - _preview.size / 2.0 + Vector2(0, 8.0 * s)


# --- Drawing -------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_preview()


func _draw() -> void:
	_place_preview()
	var s := _scale()
	var centre := _centre()
	var ry := minf(size.y * 0.34, 205.0 * s)
	# Two faint dashed rings, like the upgrade web's.
	for radius in [ry * 0.62, ry * 1.08]:
		for i in 60:
			if i % 2 == 0:
				draw_arc(centre, radius, TAU * i / 60.0, TAU * (i + 1) / 60.0, 3, Color(1, 1, 1, 0.12), 1.5, true)
	var font := UiTheme.display_font()
	var index := 0
	for attribute in Attributes.LIST:
		var info: Dictionary = Attributes.LIST[attribute]
		var tint: Color = info.color
		var at := _node_at(index)
		var radius := NODE_RADIUS * s
		var have := int(GameState.attributes.get(attribute, 0))
		var chosen: bool = attribute == selected
		draw_line(centre, at, Color(tint, 0.32), 2.0, true)
		# Glow, then the dark face and its ring.
		for layer in 3:
			draw_circle(at, radius + 6.0 + layer * 7.0, Color(tint, 0.10 - layer * 0.03))
		draw_circle(at, radius, Color(0.055, 0.04, 0.09, 0.82))
		draw_arc(at, radius, 0.0, TAU, 40, tint, 2.5, true)
		if chosen:
			draw_arc(at, radius + 5.0, 0.0, TAU, 40, Color(1, 1, 1, 0.9), 3.0, true)
		Icons.draw(self, info.icon, at, radius * 0.95, tint, Color(0.055, 0.04, 0.09))
		# The name above, the count in a pill below.
		var name_text := String(info.name).to_upper()
		var name_size := int(17 * s)
		var name_width := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
		var angle := -PI / 2.0 + TAU * index / float(Attributes.LIST.size())
		var name_at := at + Vector2(-name_width / 2.0, -radius - 44.0 * s)
		draw_string_outline(font, name_at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, 5, Color(0, 0, 0, 0.9))
		draw_string(font, name_at, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, tint.lightened(0.15))
		var count_text := "%d / %d" % [have, Attributes.MAX]
		var count_size := int(17 * s)
		var count_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size).x
		var pill := Rect2(at + Vector2(-count_width / 2.0 - 9.0, radius - 10.0 * s), Vector2(count_width + 18.0, 24.0 * s))
		draw_style_box(UiTheme.box(Color(0.045, 0.035, 0.07, 0.96), tint, 1, 12), pill)
		draw_string(font, pill.position + Vector2(9.0, 18.0 * s), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_size, Color.WHITE)
		# The three perk dots (10, 20, 30), round the node's outer side.
		for i in 3:
			var perk_angle := angle + (i - 1) * 0.5
			var dot := at + Vector2.from_angle(perk_angle) * (radius + 24.0 * s)
			var on := have >= int(Attributes.PERK_AT[i])
			if on:
				draw_circle(dot, 11.0 * s, Color(tint, 0.3))
			draw_circle(dot, 7.5 * s, tint if on else Color(0.04, 0.035, 0.06, 0.9))
			draw_arc(dot, 7.5 * s, 0.0, TAU, 16, Color.WHITE if on else Color(1, 1, 1, 0.3), 1.8, true)
		index += 1
	if selected == "":
		draw_arc(centre + Vector2(0, 8.0 * s), 150.0 * s, 0.0, TAU, 60, Color(1, 1, 1, 0.14), 2.0, true)
	var hint := "Tap an attribute for its perks. Tap your fighter for their stats."
	draw_string(UiTheme.bold_font(), Vector2(18, size.y - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(0.8, 0.77, 0.86, 0.85))


# --- Input ---------------------------------------------------------------------------

## The attribute whose node is at pos, "" for the fighter, "-" for neither.
func _hit(pos: Vector2) -> String:
	var s := _scale()
	var index := 0
	for attribute in Attributes.LIST:
		if pos.distance_to(_node_at(index)) <= (NODE_RADIUS + 14.0) * s:
			return attribute
		index += 1
	if _preview and Rect2(_preview.position + _preview.size * Vector2(0.2, 0.1), _preview.size * Vector2(0.6, 0.8)).has_point(pos):
		return ""
	return "-"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var over := _hit(event.position)
		mouse_default_cursor_shape = Control.CURSOR_ARROW if over == "-" else Control.CURSOR_POINTING_HAND
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit == "-":
			return
		selected = hit
		queue_redraw()
		picked.emit(hit)
		accept_event()
