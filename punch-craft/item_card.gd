class_name ItemCard
extends PanelContainer
## A gear card (2026-11-04): the item's model turning in a little 3D window
## (ItemModels, lit like the hat popup), its name in its rarity color, what it
## is, and its stats colored against what's worn. Used for Crypt drops, the
## gilding altar, the merchant and the camp shop.
##
## The card's color and effects climb with rarity:
##   common     a thin grey frame, nothing else
##   uncommon   a green frame, a faint glow, a soft light under the item
##   rare       a blue frame, a soft glow, slow light rays behind the item
##   epic       a thick purple frame, a pulsing glow, brighter rays, purple
##              sparkles drifting over the window (and on the model)
##   legendary  a thick gold frame, a strong pulse, bright fast rays, gold
##              sparkles, and a light sweep across the card every few seconds
##
## It keeps animating while the game is paused (drops pause the Crypt).

const WIDTH := 300.0
const STAGE := Vector2(268, 170)
## Effects per rarity: frame width, glow size, glow pulse, rays (count,
## strength, turn speed), 2D sparkles, a light sweep.
const FX := {
	"common": {"border": 1, "glow": 0, "pulse": 0.0, "rays": 0, "ray_alpha": 0.0, "spin": 0.0, "sparkles": 0, "sweep": false},
	"uncommon": {"border": 2, "glow": 4, "pulse": 0.0, "rays": 0, "ray_alpha": 0.0, "spin": 0.0, "sparkles": 0, "sweep": false},
	"rare": {"border": 2, "glow": 8, "pulse": 0.0, "rays": 10, "ray_alpha": 0.07, "spin": 0.12, "sparkles": 0, "sweep": false},
	"epic": {"border": 3, "glow": 14, "pulse": 0.35, "rays": 12, "ray_alpha": 0.12, "spin": 0.2, "sparkles": 16, "sweep": false},
	"legendary": {"border": 3, "glow": 22, "pulse": 0.5, "rays": 16, "ray_alpha": 0.17, "spin": 0.32, "sparkles": 30, "sweep": true},
}
const SWEEP_EVERY := 3.2

var item := {}
var tag := ""
var compare := {}

var _rarity := "common"
var _tint := Color.WHITE
var _style: StyleBoxFlat
var _time := 0.0
var _model: Node3D
var _turn: Node3D
var _rays: Control
var _sweep: Control


## A card for item, headed by tag ("NEW", "WORN NOW", "FOR SALE" ...).
## compare: the worn item its stats are colored against (green better, red
## worse, gold special).
static func make(for_item: Dictionary, heading: String, against := {}) -> ItemCard:
	var card := ItemCard.new()
	card.item = for_item
	card.tag = heading
	card.compare = against
	return card


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	clip_contents = true
	_rarity = String(item.get("rarity", "common"))
	if not FX.has(_rarity):
		_rarity = "epic" if _rarity == "cursed" else "rare"
	_tint = Items.rarity_color(item)
	custom_minimum_size = Vector2(WIDTH, 0)
	var fx: Dictionary = FX[_rarity]
	_style = StyleBoxFlat.new()
	_style.bg_color = _tint.darkened(0.88)
	_style.border_color = _tint if _rarity != "common" else Color(_tint, 0.6)
	_style.set_border_width_all(int(fx.border))
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(14)
	_style.shadow_color = Color(_tint, 0.45)
	_style.shadow_size = int(fx.glow)
	add_theme_stylebox_override("panel", _style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	column.add_child(_header())
	column.add_child(_stage(fx))
	var name_label := _label(String(item.get("name", "")), 22, _tint.lightened(0.15))
	name_label.add_theme_font_override("font", UiTheme.display_font())
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(name_label)
	var kind := _label(Items.kind_text(item), 14, Color(1, 1, 1, 0.7))
	column.add_child(kind)
	_add_stats(column)
	if fx.sweep:
		_sweep = Control.new()
		_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sweep.draw.connect(_draw_sweep)
		add_child(_sweep)


func _process(delta: float) -> void:
	_time += delta
	if _turn:
		_turn.rotation.y = _time * 1.1
		_turn.position.y = sin(_time * 2.0) * 0.03
	var fx: Dictionary = FX[_rarity]
	if float(fx.pulse) > 0.0 and _style:
		var beat := 0.5 + 0.5 * sin(_time * 3.0)
		_style.shadow_size = int(float(fx.glow) * (1.0 - fx.pulse + fx.pulse * beat * 2.0))
		_style.shadow_color = Color(_tint, 0.35 + 0.25 * beat)
	if _rays:
		_rays.queue_redraw()
	if _sweep:
		_sweep.queue_redraw()


# --- Parts ------------------------------------------------------------------------

func _header() -> Control:
	var row := HBoxContainer.new()
	var tag_label := _label(tag, 12, Color(1, 1, 1, 0.6))
	tag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tag_label)
	var rarity_name: String = Items.RARITIES.get(item.get("rarity", "common"), {"name": ""}).name
	var chip := _label(rarity_name.to_upper(), 12, _tint)
	chip.add_theme_font_override("font", UiTheme.bold_font())
	row.add_child(chip)
	return row


## The window: the rarity's backdrop (glow, rays, sparkles) behind the model
## turning in its own little 3D world.
func _stage(fx: Dictionary) -> Control:
	var stage := Control.new()
	stage.custom_minimum_size = STAGE
	stage.clip_contents = true
	var back := Panel.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.35), Color(_tint, 0.25 if _rarity != "common" else 0.12), 1, 8, 0.0))
	stage.add_child(back)
	_rays = Control.new()
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_backdrop.bind(fx))
	stage.add_child(_rays)
	stage.add_child(_viewport())
	if int(fx.sparkles) > 0:
		stage.add_child(_sparkles_2d(int(fx.sparkles)))
	return stage


func _viewport() -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.8)
	env.environment.ambient_light_energy = 0.8
	view.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, -0.5, 0)
	key.light_energy = 1.3
	view.add_child(key)
	if _rarity != "common":
		var rim := OmniLight3D.new()
		rim.light_color = _tint
		rim.light_energy = 1.5 + 0.5 * ItemModels.RARITIES.find(_rarity)
		rim.position = Vector3(0, 0.6, -1.4)
		view.add_child(rim)
	_turn = Node3D.new()
	view.add_child(_turn)
	if Items.SLOTS.has(String(item.get("slot", ""))):
		_model = ItemModels.build_for_item(item)
		_turn.add_child(_model)
		# Centered and sized to the window, whatever its shape.
		var bounds := HatPopup._bounds(_model, Transform3D.IDENTITY)
		if bounds.size != Vector3.ZERO:
			var fit := 1.28 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
			_model.scale = Vector3.ONE * fit
			_model.position = -bounds.get_center() * fit
	var camera := Camera3D.new()
	camera.fov = 34
	camera.look_at_from_position(Vector3(0, 0.55, 2.4), Vector3.ZERO)
	view.add_child(camera)
	return frame


## Behind the model: a soft light rising from the bottom (uncommon and up),
## turning rays (rare and up), brighter and faster with rarity.
func _draw_backdrop(fx: Dictionary) -> void:
	var area := _rays.size
	if _rarity == "common":
		return
	# The glow under the item.
	var glow_steps := 6
	for i in glow_steps:
		var t := float(i) / glow_steps
		var h := area.y * (0.55 - 0.45 * t)
		_rays.draw_rect(Rect2(0, area.y - h, area.x, h), Color(_tint, 0.035))
	var count := int(fx.rays)
	if count <= 0:
		return
	var center := area / 2.0
	var reach := area.length()
	var turn := _time * float(fx.spin)
	var alpha := float(fx.ray_alpha) * (1.0 + 0.25 * sin(_time * 2.2))
	for i in count:
		var a := turn + i * TAU / count
		var points := PackedVector2Array([center, center + Vector2.from_angle(a - 0.09) * reach, center + Vector2.from_angle(a + 0.09) * reach])
		_rays.draw_colored_polygon(points, Color(_tint.lightened(0.2), alpha if i % 2 == 0 else alpha * 0.5))


## Legendary: a band of light crossing the card every SWEEP_EVERY seconds.
func _draw_sweep() -> void:
	var area := _sweep.size
	var t := fmod(_time, SWEEP_EVERY) / 0.9
	if t > 1.0:
		return
	var x := lerpf(-area.y, area.x + area.y, t)
	var width := 46.0
	var points := PackedVector2Array([Vector2(x, 0), Vector2(x + width, 0), Vector2(x + width - area.y * 0.6, area.y), Vector2(x - area.y * 0.6, area.y)])
	_sweep.draw_colored_polygon(points, Color(1.0, 0.95, 0.8, 0.13))


## Sparkles drifting up over the window, in the rarity's sparkle color.
func _sparkles_2d(amount: int) -> CPUParticles2D:
	var tint: Color = ItemModels.SPARKLE.get(_rarity, _tint)
	var sparkles := CPUParticles2D.new()
	sparkles.amount = amount
	sparkles.lifetime = 1.6
	sparkles.preprocess = 1.6
	sparkles.position = STAGE / 2.0
	sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkles.emission_rect_extents = STAGE / 2.0
	sparkles.gravity = Vector2(0, -18)
	sparkles.initial_velocity_min = 4.0
	sparkles.initial_velocity_max = 20.0
	sparkles.scale_amount_min = 1.5
	sparkles.scale_amount_max = 3.5 if _rarity == "legendary" else 2.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint, 0.0))
	ramp.add_point(0.3, Color(tint.lightened(0.2), 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	sparkles.color_ramp = ramp
	return sparkles


## Each stat: green if better than the worn item's, red if worse, gold for a
## special; then what the worn item has that this one would lose.
func _add_stats(column: VBoxContainer) -> void:
	var worn: Dictionary = compare.get("effects", {})
	var effects: Dictionary = item.get("effects", {})
	for entry in Items.effect_entries(item):
		var line := _label(entry[0], 16, UiTheme.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var effect: String = entry[1]
		if Items.is_special(effect):
			line.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
		elif not compare.is_empty():
			var mine: float = effects.get(effect, 0.0)
			var theirs: float = worn.get(effect, 0.0)
			if mine > theirs + 0.001:
				line.add_theme_color_override("font_color", Color(0.5, 0.95, 0.5))
			elif mine < theirs - 0.001:
				line.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
		column.add_child(line)
	for effect in worn:
		if not effects.has(effect):
			var lost := _label("Lose: " + GameState.effect_text({effect: worn[effect]}, 1), 14, Color(1.0, 0.45, 0.4, 0.85))
			lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(lost)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
