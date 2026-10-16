class_name Wraith
extends Boxer
## A floating ghost (Crypt). It drifts straight through walls and punches go
## through it, except right after it attacks, when it's solid for a moment,
## or with a counter. So: roll its claw, then punish.

## Solid for this long after each attack.
const OPEN_TIME := 1.4
const HOVER_HEIGHT := 0.35
const COMBOS := [["claw"], ["claw"], ["claw", "claw"]]

var _open := 0.0
var _ghost_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	super()
	# No gravity and no collisions with the world: it floats through walls.
	_gravity = 0.0
	collision_mask = 0
	global_position.y = HOVER_HEIGHT


func phased(_punch_type: String, counter: bool) -> bool:
	return not counter and _open <= 0.0 and _stagger_timer <= 0.0


func _think(delta: float) -> Vector3:
	_open -= delta
	velocity.y = 0.0
	return super(delta)


func _strike(distance: float) -> void:
	super(distance)
	_open = OPEN_TIME


func _pick_combo() -> Array:
	return COMBOS.pick_random()


func _idle_time() -> float:
	return randf_range(0.4, 0.9)


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	# See-through while phased; nearly solid while it's open.
	var solid := _open > 0.0 or _stagger_timer > 0.0
	var alpha := 0.85 if solid else 0.3 + 0.08 * sin(Time.get_ticks_msec() * 0.004)
	for material in _ghost_materials:
		material.albedo_color.a = lerpf(material.albedo_color.a, alpha, minf(1.0, 10.0 * delta))
	_body.position.y = HOVER_HEIGHT * 0.3 * sin(Time.get_ticks_msec() * 0.002)


func _ghost(color: Color) -> StandardMaterial3D:
	var material := _material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.35
	material.emission_enabled = true
	material.emission = color * 0.4
	_ghost_materials.append(material)
	return material


func _build_body() -> void:
	var shroud := _ghost(Color(0.55, 0.65, 0.8))
	var dark := _ghost(Color(0.15, 0.17, 0.25))
	var eyes := _glow_material(Color(0.6, 0.9, 1.0))
	# A tattered shroud tapering to nothing below the waist.
	_part(_body, _box(Vector3(0.5, 0.7, 0.35)), shroud, Vector3(0, 1.25, 0))
	_part(_body, _box(Vector3(0.36, 0.5, 0.26)), shroud, Vector3(0, 0.72, 0))
	_part(_body, _box(Vector3(0.2, 0.35, 0.16)), shroud, Vector3(0, 0.35, 0.04))
	_part(_body, _box(Vector3(0.36, 0.38, 0.36)), dark, Vector3(0, 1.75, 0.02))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.03, 0.02)), eyes, Vector3(0.07 * side, 1.76, -0.17))
	_build_arms(shroud, Color(0.75, 0.85, 1.0), 1.48, 0.29)


func _build_armor() -> void:
	pass  # Nothing to armor.


## Casters wear their gear as tier-colored robes with trim.
func _gear_style() -> String:
	return "robe"
