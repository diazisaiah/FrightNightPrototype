extends CanvasLayer
## Settings > Display > Performance (2026-11-06): a small readout at the
## bottom of the screen for testing on a phone. Frames a second, the game's
## memory (and the most it has reached this session), draw calls and nodes.
## A phone browser that runs out of memory reloads the page, so the peak is
## what to watch: note the screen it climbs on.

var _label: Label
var _timer := 0.0
var _peak_mb := 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -4.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.8))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	var mb := OS.get_static_memory_usage() / 1048576.0
	_peak_mb = maxf(_peak_mb, mb)
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_label.text = "%d fps  ·  mem %d MB (peak %d)  ·  video %d MB  ·  %d draws  ·  %d nodes  ·  3D x%.2f" % [
		Engine.get_frames_per_second(), mb, _peak_mb, video,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Settings.render_scale(),
	]
