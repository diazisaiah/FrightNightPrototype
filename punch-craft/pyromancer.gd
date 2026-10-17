class_name Pyromancer
extends Mage
## Pyromancer (deeper tiers, the fire mage's big brother): throws fireballs
## like the mage, and every other cast calls down fire circles instead: one
## under you and two around you, bursting after a fuse. Keep moving.

const CIRCLES := 3
const CIRCLE_FUSE := 1.3
const CIRCLE_DAMAGE := 1.2

var _marks: Telegraphs
var _casts := 0


func _ready() -> void:
	super()
	_marks = Telegraphs.new(self)
	add_child(_marks)


func _die(push: Vector3) -> void:
	_marks.clear()
	super(push)


func _shoot() -> void:
	_casts += 1
	if _casts % 2 == 1:
		super()
		return
	_on_attacking()
	if _dead:
		return
	_drawing = false
	_cooldown = shot_cooldown
	Sfx.play_at("fire", global_position + Vector3.UP * 1.6, 2.0, 0.9)
	var center := player.global_position
	center.y = global_position.y
	var spots := [center]
	var start := randf() * TAU
	for i in CIRCLES - 1:
		var a := start + i * TAU / (CIRCLES - 1)
		spots.append(center + Vector3(cos(a), 0, sin(a)) * 2.4)
	for i in spots.size():
		_marks.spawn_zone(spots[i], CIRCLE_FUSE + (0.2 if i == 0 else 0.0), arrow_damage * CIRCLE_DAMAGE * damage_multiplier,
				Fireball.COLOR)


func _build_body() -> void:
	super()
	# A burning crown of flame over the hat brim, and a black-and-ember robe.
	var flame := _glow_material(Color(1.0, 0.5, 0.1))
	for i in 5:
		var a := i * TAU / 5.0
		_part(_body, _box(Vector3(0.06, 0.16, 0.06)), flame, Vector3(sin(a) * 0.17, 1.96, cos(a) * 0.17))
	var ember := _material(Color(0.12, 0.05, 0.05))
	_part(_body, _box(Vector3(0.5, 0.3, 0.42)), ember, Vector3(0, 0.15, 0))
	_part(_body, _box(Vector3(0.46, 0.06, 0.34)), _glow_material(Color(1.0, 0.45, 0.1)), Vector3(0, 0.32, 0))
