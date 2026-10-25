class_name BoneSniper
extends Skeleton
## Bone Sniper (deeper tiers, the skeleton's big brother): a hooded archer
## with a long draw. While it draws, a lane lights from its bow to you,
## tracking you until the string flashes, then the shot goes down the lane
## at once. Step out of the lane before it locks, or slip it.

const LANE_WIDTH := 0.9
const SHOT_DAMAGE := 1.6

var _marks: Telegraphs
var _aim := Vector3.FORWARD


func _ready() -> void:
	super()
	_marks = Telegraphs.new(self)
	add_child(_marks)


func _think(delta: float) -> Vector3:
	var move := super(delta)
	if _drawing:
		if _draw_timer > tell_time():
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			if to_player.length() > 0.1:
				_aim = to_player.normalized()
		_marks.show_lane(global_position, global_position + _aim * (max_range + 6.0), LANE_WIDTH, Color(0.45, 1.0, 0.55))
		_marks.pulse(1.0 - _draw_timer / draw_time)
	else:
		_marks.hide_mark()
	return move


func _on_staggered() -> void:
	super()
	_marks.hide_mark()


func _die(push: Vector3) -> void:
	_marks.clear()
	super(push)


func _shoot() -> void:
	_on_attacking()
	if _dead:
		return
	_drawing = false
	_cooldown = shot_cooldown
	_marks.hide_mark()
	var from := _body.to_global(Vector3(0, 1.45, -0.7))
	Sfx.play_at("twang", from, 4.0, 0.7)
	# The bolt streaks down the lane.
	var reach := max_range + 6.0
	var streak := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, reach)
	mesh.material = _glow_material(Color(0.5, 1.0, 0.6))
	streak.mesh = mesh
	get_parent().add_child(streak)
	streak.global_transform = Transform3D(Basis.looking_at(_aim, Vector3.UP), from + _aim * reach * 0.5)
	streak.create_tween().tween_property(streak, "scale", Vector3(0.1, 0.1, 1.0), 0.25).finished.connect(streak.queue_free)
	var offset := player.global_position - global_position
	offset.y = 0.0
	var along := offset.dot(_aim)
	var across := absf(offset.cross(_aim).y)
	if along > 0.0 and along <= reach and across <= LANE_WIDTH * 0.5 + 0.3:
		player.receive_attack(arrow_damage * SHOT_DAMAGE * damage_multiplier, global_position, "arrow", self)


func _build_body() -> void:
	super()
	# A dark hood and a long green-glowing bow.
	var hood := _material(Color(0.12, 0.14, 0.1))
	_part(_body, _box(Vector3(0.34, 0.34, 0.34)), hood, Vector3(0, 1.74, 0.03))
	_part(_body, _box(Vector3(0.36, 0.5, 0.06)), hood, Vector3(0, 1.45, 0.16))
	_part(_bow_arm, _box(Vector3(0.03, 0.03, 1.25)), _glow_material(Color(0.45, 1.0, 0.55)), Vector3(0, -0.6, 0))
