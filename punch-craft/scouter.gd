class_name Scouter
extends Label
## The Fancy Bluetooth Headpiece's readout (Crypt revamp, 2026-11-04): while
## you wear it, the POWER of the monster in your sights (PowerRating
## .monster_power) and how you measure up, under the crosshair.

const HAT := "bluetooth_headpiece"
const RANGE := 40.0
## World blocks and monsters (not the player).
const MASK := 1 | 4

var _target_id := 0
var _mine := 0
var _check := 0.0


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", UiTheme.display_font())
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 8)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -220.0
	offset_right = 220.0
	offset_top = 30.0
	offset_bottom = 62.0
	visible = false


func _process(delta: float) -> void:
	if GameState.worn_hat != HAT:
		visible = false
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1
	var enemy := _sighted()
	if enemy == null:
		visible = false
		_target_id = 0
		return
	if enemy.get_instance_id() != _target_id:
		_target_id = enemy.get_instance_id()
		_mine = PowerRating.player()
	var power := PowerRating.monster_power(enemy)
	var verdict := PowerRating.verdict(_mine, power)
	var ratio: float = verdict[1]
	text = "POWER %d   ·   %s" % [power, verdict[0]]
	add_theme_color_override("font_color", UiTheme.BAD if ratio < 0.88 else (UiTheme.GOLD if ratio < 0.97 else UiTheme.GOOD))
	visible = true


## The living monster the camera's looking at, within RANGE (walls block).
func _sighted() -> Enemy:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * RANGE, MASK)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var enemy := hit.collider as Enemy
	if enemy == null or enemy.is_dead():
		return null
	return enemy
