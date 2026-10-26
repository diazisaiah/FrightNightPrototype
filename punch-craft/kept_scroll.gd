class_name KeptScroll
extends ScrollContainer
## A scroll box that keeps its place when what's inside is rebuilt or
## briefly resized (spending a point, buying, equipping). A plain
## ScrollContainer clamps to the top the moment its content shrinks, and
## stays there when the content comes back.

## Where the player left each bar.
var _want := {}


func _ready() -> void:
	for bar in [get_v_scroll_bar(), get_h_scroll_bar()]:
		_want[bar] = bar.value
		bar.value_changed.connect(_on_value.bind(bar))
		bar.changed.connect(_on_range.bind(bar))


func _on_value(value: float, bar: ScrollBar) -> void:
	# Pushed down to the end because the content shrank: not the player's doing.
	if value < _want[bar] and value >= _end(bar) - 1.0:
		return
	_want[bar] = value


## The content changed size: back to where the player was, as far as it goes.
func _on_range(bar: ScrollBar) -> void:
	if bar.value < _want[bar] and _end(bar) > bar.value:
		_restore.call_deferred(bar)


func _restore(bar: ScrollBar) -> void:
	var want: float = _want[bar]
	bar.value = minf(want, _end(bar))
	_want[bar] = want


func _end(bar: ScrollBar) -> float:
	return maxf(bar.max_value - bar.page, 0.0)
