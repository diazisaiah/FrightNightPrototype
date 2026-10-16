class_name UiTheme
## Shared colors, fonts and the menu Theme: dark translucent panels with drop
## shadows and bone-gold edges, chunky buttons with a lit top and a dark lip,
## a gold glow on hover, and a heavy display face for titles.

const BG := Color(0.045, 0.045, 0.06)
const PANEL := Color(0.085, 0.08, 0.105)
const PANEL_LIGHT := Color(0.14, 0.13, 0.17)
const BORDER := Color(0.26, 0.24, 0.3)
const TEXT := Color(0.93, 0.91, 0.94)
const MUTED := Color(0.6, 0.58, 0.66)
const GOLD := Color(1.0, 0.76, 0.32)
const GOOD := Color(0.5, 0.86, 0.56)
const BAD := Color(0.95, 0.45, 0.4)
const SKILL := Color(0.55, 0.75, 1.0)
const SIGIL := Color(0.78, 0.5, 1.0)
const BLOOD := Color(0.82, 0.12, 0.08)
## Upgrade/skill nodes you can buy right now (bone white, so it never clashes
## with a branch or fighter color).
const READY := Color(0.95, 0.93, 0.84)

static var _display: FontVariation
static var _bold: FontVariation


static func box(bg: Color, border := Color.TRANSPARENT, border_width := 0, radius := 8, padding := 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


## A box that floats: a soft drop shadow under it.
static func raised(bg: Color, border := Color.TRANSPARENT, border_width := 1, radius := 10, padding := 0.0, shadow := 10) -> StyleBoxFlat:
	var style := box(bg, border, border_width, radius, padding)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, 4)
	return style


## Anton (fonts/, SIL Open Font License; see Anton-OFL.txt): the heavy
## condensed face for titles, names and big numbers, with a little tracking.
static func display_font() -> FontVariation:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = load("res://fonts/Anton-Regular.ttf")
		_display.spacing_glyph = 1
	return _display


## Bold for buttons and labels that need weight.
static func bold_font() -> FontVariation:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.6
	return _bold


## A label in the display face with an outline and a shadow.
static func title_label(text: String, size: int, color := TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", display_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.02))
	label.add_theme_constant_override("outline_size", maxi(4, size / 6))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_y", maxi(2, size / 14))
	return label


## A menu heading: the display face in gold, centered.
static func heading(text: String, size := 40, color := GOLD) -> Label:
	var label := title_label(text, size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## The card every menu sits on: near-black, a gold edge and a soft shadow
## (the Dead League panel, results and dialogs use the same one).
static func card(padding := 22.0) -> StyleBoxFlat:
	return raised(Color(0.05, 0.045, 0.07, 0.97), Color(GOLD, 0.55), 2, 12, padding, 16)


## A section heading inside a card: small display caps over a thin gold rule.
static func section(text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var label := title_label(text.to_upper(), 18, GOLD.lightened(0.15))
	label.add_theme_constant_override("outline_size", 3)
	box.add_child(label)
	var rule := ColorRect.new()
	rule.color = Color(GOLD, 0.3)
	rule.custom_minimum_size.y = 1
	box.add_child(rule)
	return box


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_y", "Label", 1)

	# Buttons: a lit top edge and a dark lip at the bottom, lifting on hover.
	theme.set_font("font", "Button", bold_font())
	theme.set_stylebox("normal", "Button", _button(PANEL_LIGHT, BORDER))
	theme.set_stylebox("hover", "Button", _button(Color(0.2, 0.18, 0.24), GOLD.darkened(0.3), GOLD))
	theme.set_stylebox("pressed", "Button", _button(GOLD.darkened(0.62), GOLD, Color.TRANSPARENT, true))
	theme.set_stylebox("disabled", "Button", _button(PANEL, BORDER.darkened(0.25)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_hover_pressed_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	theme.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "Button", 3)

	# Big gold call-to-action button.
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", _button(GOLD.darkened(0.08), GOLD.lightened(0.2), Color.TRANSPARENT, false, GOLD.darkened(0.55)))
	theme.set_stylebox("hover", "PrimaryButton", _button(GOLD.lightened(0.08), GOLD.lightened(0.45), GOLD, false, GOLD.darkened(0.5)))
	theme.set_stylebox("pressed", "PrimaryButton", _button(GOLD.darkened(0.3), GOLD, Color.TRANSPARENT, true))
	theme.set_stylebox("disabled", "PrimaryButton", _button(PANEL_LIGHT, BORDER))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		theme.set_color(state, "PrimaryButton", Color(0.1, 0.06, 0.02))
	theme.set_constant("outline_size", "PrimaryButton", 0)

	# Page tabs: flat, with a glowing gold underline on the open one.
	theme.set_type_variation("TabButton", "Button")
	var tab_normal := box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0.0)
	_set_margins(tab_normal, 18, 10)
	var tab_pressed := box(Color(1, 0.8, 0.4, 0.06), GOLD, 0, 0, 0.0)
	tab_pressed.border_width_bottom = 3
	tab_pressed.shadow_color = Color(GOLD, 0.25)
	tab_pressed.shadow_size = 6
	_set_margins(tab_pressed, 18, 10)
	var tab_hover := box(Color(1, 1, 1, 0.05), Color.TRANSPARENT, 0, 0, 0.0)
	_set_margins(tab_hover, 18, 10)
	theme.set_stylebox("normal", "TabButton", tab_normal)
	theme.set_stylebox("hover", "TabButton", tab_hover)
	theme.set_stylebox("pressed", "TabButton", tab_pressed)
	theme.set_stylebox("hover_pressed", "TabButton", tab_pressed)
	theme.set_color("font_color", "TabButton", MUTED)
	theme.set_color("font_hover_color", "TabButton", TEXT)
	theme.set_color("font_pressed_color", "TabButton", GOLD.lightened(0.3))
	theme.set_color("font_hover_pressed_color", "TabButton", GOLD.lightened(0.3))
	theme.set_font_size("font_size", "TabButton", 19)

	theme.set_stylebox("panel", "PanelContainer", raised(Color(PANEL, 0.9), Color(BORDER, 0.9), 1, 10, 18.0))
	theme.set_stylebox("panel", "Panel", raised(Color(PANEL, 0.9), Color(BORDER, 0.9), 1, 10))
	var bar_back := box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.6), 1, 4)
	theme.set_stylebox("background", "ProgressBar", bar_back)
	var bar_fill := box(SKILL, Color(SKILL.lightened(0.4), 0.8), 0, 4)
	bar_fill.border_width_top = 2
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	var line := StyleBoxLine.new()
	line.color = Color(GOLD, 0.25)
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	theme.set_constant("separation", "HSeparator", 18)
	# Sliders and toggles in gold.
	var groove := box(Color(0, 0, 0, 0.45), Color(BORDER, 0.8), 1, 4)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", groove)
	var filled := box(GOLD.darkened(0.2), Color.TRANSPARENT, 0, 4)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_font("font", "CheckButton", bold_font())
	theme.set_stylebox("normal", "CheckButton", _button(Color(PANEL_LIGHT, 0.7), Color(BORDER, 0.6)))
	theme.set_stylebox("hover", "CheckButton", _button(Color(0.2, 0.18, 0.24, 0.8), GOLD.darkened(0.4)))
	theme.set_stylebox("pressed", "CheckButton", _button(Color(PANEL_LIGHT, 0.7), Color(BORDER, 0.6)))
	theme.set_stylebox("hover_pressed", "CheckButton", _button(Color(0.2, 0.18, 0.24, 0.8), GOLD.darkened(0.4)))
	theme.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	# Tooltips.
	theme.set_stylebox("panel", "TooltipPanel", raised(Color(0.05, 0.045, 0.06, 0.96), GOLD.darkened(0.4), 1, 6, 8.0, 6))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	# Dropdown lists and right-click menus.
	var menu := raised(Color(0.06, 0.055, 0.075, 0.98), Color(GOLD, 0.45), 1, 8, 6.0, 8)
	theme.set_stylebox("panel", "PopupMenu", menu)
	var menu_hover := box(Color(GOLD, 0.16), Color(GOLD, 0.5), 1, 5)
	_set_margins(menu_hover, 8, 4)
	theme.set_stylebox("hover", "PopupMenu", menu_hover)
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", GOLD.lightened(0.3))
	theme.set_color("font_disabled_color", "PopupMenu", MUTED.darkened(0.3))
	theme.set_constant("v_separation", "PopupMenu", 10)
	theme.set_constant("item_start_padding", "PopupMenu", 12)
	theme.set_constant("item_end_padding", "PopupMenu", 16)
	theme.set_font("font", "PopupMenu", bold_font())
	theme.set_stylebox("panel", "PopupPanel", raised(Color(0.05, 0.045, 0.07, 0.98), Color(GOLD, 0.6), 2, 10, 16.0))
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("modulate_arrow", "OptionButton", GOLD)
	# Windows (any dialog that slips through) match the panels.
	theme.set_stylebox("embedded_border", "Window", raised(Color(PANEL, 0.98), Color(GOLD, 0.5), 2, 10, 0.0))
	theme.set_stylebox("embedded_unfocused_border", "Window", raised(Color(PANEL, 0.98), Color(GOLD, 0.35), 2, 10, 0.0))
	theme.set_font("title_font", "Window", display_font())
	theme.set_color("title_color", "Window", GOLD)
	theme.set_stylebox("panel", "AcceptDialog", box(Color(PANEL, 0.98), Color.TRANSPARENT, 0, 10, 16.0))
	# Scrollbars: a thin gold thumb in a dark groove.
	for bar in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0, 4, 2.0))
		theme.set_stylebox("grabber", bar, box(Color(GOLD, 0.35), Color.TRANSPARENT, 0, 4))
		theme.set_stylebox("grabber_highlight", bar, box(Color(GOLD, 0.6), Color.TRANSPARENT, 0, 4))
		theme.set_stylebox("grabber_pressed", bar, box(GOLD, Color.TRANSPARENT, 0, 4))
	# Text fields.
	var field := box(Color(0, 0, 0, 0.45), Color(BORDER, 0.9), 1, 6)
	_set_margins(field, 10, 6)
	var field_focus := box(Color(0, 0, 0, 0.55), GOLD.darkened(0.2), 1, 6)
	_set_margins(field_focus, 10, 6)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_font("font", "CheckBox", bold_font())
	theme.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	return theme


## glow: color of a soft halo (hover); sunk: pressed (no lip, pushed down).
static func _button(bg: Color, border: Color, glow := Color.TRANSPARENT, sunk := false, lip := Color(0, 0, 0, 0.55)) -> StyleBoxFlat:
	var style := box(bg, border, 1, 7)
	style.border_width_bottom = 1 if sunk else 4
	style.border_color = border
	if not sunk:
		# The bottom edge reads as a dark lip under a lit face.
		style.border_blend = false
	style.expand_margin_bottom = 0.0
	_set_margins(style, 16, 8)
	if sunk:
		style.content_margin_top = 11
	if glow.a > 0.0:
		style.shadow_color = Color(glow, 0.35)
		style.shadow_size = 8
	else:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
	if not sunk and lip.a > 0.0:
		# Draw the lip by darkening the bottom border.
		style.border_color = border
		style.set_border_width_all(1)
		style.border_width_bottom = 4
		style.border_color = border.lerp(lip, 0.6)
	return style


static func _padded(style: StyleBoxFlat) -> StyleBoxFlat:
	_set_margins(style, 14, 8)
	return style


static func _set_margins(style: StyleBox, horizontal: float, vertical: float) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
