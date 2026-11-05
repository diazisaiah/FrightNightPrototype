class_name CampCast
extends Node3D
## The fighters round the camp fire (2026-11-04, the user's idea): each sits
## the way they are, on a loop, and they take turns talking: the one talking
## nods and gestures, the rest turn their heads to them.
##   The Mauler: on a big stump, eating a hunk of meat.
##   The Answer: cross-legged on the ground, calm, hands on his knees.
##   The Blur: lounging back against a log, hands behind his head, yawning.
##   The Stray: on the log seat, elbows on knees, one leg always bouncing.
##   Tony (once he's found): on a crate by the Mauler with a deli sandwich.
##   The Catalyst (once bought): off on a rock, reading a big tome that glows.
## Real FighterBody voxel bodies (their skins; only the fighter you play
## wears your hat), posed with Emotes clips made here. Fire at the origin.

## Where each sits (on the floor), the seat height under them, and what they
## sit on. They face the fire, turned by "turn" (radians).
const SEATS := {
	"berserker": {"at": Vector3(-1.75, 0, -0.85), "seat": 0.5, "on": "stump"},
	# Tony sits by the Answer, clear of the fire from the camera.
	"wise_guy": {"at": Vector3(0.17, 0, -1.99), "seat": 0.45, "on": "crate"},
	"counter_master": {"at": Vector3(0.9, 0, -1.74), "seat": 0.0, "on": ""},
	# The Blur's back to the log behind him (CampBackdrop's at (2.12, -1.22)).
	"combo_master": {"at": Vector3(1.65, 0, -0.95), "seat": 0.06, "on": ""},
	# The Stray on the front edge of the other log, legs in front of it.
	"free_runner": {"at": Vector3(-1.78, 0, 0.94), "seat": 0.36, "on": ""},
	"elementalist": {"at": Vector3(0.95, 0, -3.5), "seat": 0.4, "on": "rock", "turn": 0.45},
}
## The arm each gestures with while talking ("" for head only).
const GESTURE := {"berserker": "l", "wise_guy": "l", "counter_master": "r", "combo_master": "", "free_runner": "l"}
## How long each speaks.
const TURN := Vector2(3.5, 5.5)

var bodies := {}
var _speaker := ""
var _turn_left := 1.5
var _time := 0.0
var _look := {}
## The food in a hand (the Mauler's meat, Tony's sub): aimed at the mouth as
## it comes up, held up and out otherwise.
var _food := {}
## Checking poses in stills: CAMP_CAST_FREEZE=<seconds> holds every clip there.
var _freeze := float(OS.get_environment("CAMP_CAST_FREEZE")) if OS.get_environment("CAMP_CAST_FREEZE") != "" else -1.0


func _ready() -> void:
	process_priority = 10  # After the bodies pose, so the head turns sit on top.
	var cast: Array[String] = ["berserker", "counter_master", "combo_master", "free_runner"]
	if GameState.tony_unlocked:
		cast.append("wise_guy")
	if GameState.fighters_bought.get("elementalist", false):
		cast.append("elementalist")
	for fighter in cast:
		_seat(fighter)


func _seat(fighter: String) -> void:
	var spot: Dictionary = SEATS[fighter]
	var at: Vector3 = spot.at
	_furniture(spot)
	var body := FighterBody.new(fighter, "auto")
	body.build_budget_ms = 4
	body.position = at
	body.rotation.y = atan2(at.x, at.z) + float(spot.get("turn", 0.0))
	add_child(body)
	if fighter != GameState.player_class:
		body.wear_hat("")
	var drop := (float(spot.seat) / body.scale.y + 0.08 - body._hip_height()) * 100.0
	body.play_clip(Emotes.parse(call("_" + fighter, drop)), _freeze if _freeze >= 0.0 else randf() * 3.0)
	_props(fighter, body)
	bodies[fighter] = body
	_look[fighter] = 0.0


func _process(delta: float) -> void:
	_time += delta
	_turn_left -= delta
	var talkers := bodies.keys().filter(func(f: String) -> bool: return GESTURE.has(f))
	if _turn_left <= 0.0 and talkers.size() > 1:
		var next: String = _speaker
		while next == _speaker:
			next = talkers.pick_random()
		_speaker = next
		_turn_left = randf_range(TURN.x, TURN.y)
	for fighter in bodies:
		var body: FighterBody = bodies[fighter]
		if _freeze >= 0.0:
			body._time = _freeze
		var joints: Dictionary = body._joints
		if not joints.has("head"):
			continue
		var head: Node3D = joints.head
		if fighter == _speaker:
			head.rotation.x += sin(_time * 5.0) * 0.06
			_look[fighter] = lerpf(_look[fighter], 0.0, delta * 2.0)
			var arm: String = GESTURE.get(fighter, "")
			if arm != "":
				var s: Node3D = joints[arm + "s"]
				var e: Node3D = joints[arm + "e"]
				s.rotation.x += 0.35 + sin(_time * 3.1) * 0.25
				s.rotation.z += (0.2 if arm == "r" else -0.2) * (0.5 + 0.5 * sin(_time * 2.3))
				e.rotation.x += 0.5 + sin(_time * 4.3) * 0.35
		elif _speaker != "" and fighter != "elementalist" and bodies.has(_speaker):
			var other: FighterBody = bodies[_speaker]
			var local := body.global_basis.inverse() * (other.global_position - body.global_position)
			var want := clampf(atan2(-local.x, -local.z), -1.1, 1.1)
			_look[fighter] = lerpf(_look[fighter], want, delta * 3.0)
		head.rotation.y += _look[fighter]
		if _food.has(fighter):
			_aim_food(_food[fighter], body, head)


## Points the food (built along -Z from the fist, its tip FOOD_TIP out) at
## the mouth as the hand comes up, and slides it along that line so the tip
## stops at the lips instead of going into the face.
func _aim_food(food: Node3D, body: FighterBody, head: Node3D) -> void:
	food.position = food.get_meta("grip")
	var mouth := head.global_transform * Vector3(0, 0.08, -0.2)
	var at := food.global_position
	var up_and_out := at + body.global_basis * Vector3(0, 0.3, -1.0)
	var near := clampf((0.8 - at.distance_to(mouth)) / 0.3, 0.0, 1.0)
	var target := up_and_out.lerp(mouth, near)
	if target.distance_to(at) > 0.01:
		food.look_at(target, Vector3.UP)
	var tip: float = food.get_meta("tip") * body.scale.x
	var slide := minf(at.distance_to(mouth) - tip, 0.0) * near
	food.global_position = at + (mouth - at).normalized() * slide


# --- Poses (Emotes clip format: degrees, pos in cm, see Emotes) ---------------------

static func _make(length: float, keys: Array) -> Dictionary:
	return {"length": length, "loop": true, "plant": false, "keys": keys}


## Sitting on something: thighs level, shins down, feet flat.
static func _sit(drop: float, extra := {}) -> Dictionary:
	var pose := {"pos": [0, drop, 6], "lh": [86, 0, -7], "rh": [86, 0, 7], "lk": [-86, 0, 0], "rk": [-86, 0, 0],
		"torso": [-6, 0, 0]}
	pose.merge(extra, true)
	return pose


## The Mauler: a bite of the meat, chew, rest it on his knee.
static func _berserker(drop: float) -> Dictionary:
	var base := {"ls": [38, 0, -12], "le": [62, 0, 0]}
	var rest := {"rs": [38, 0, 10], "re": [78, 0, 0], "rhand": [8, -45, -70, 0]}
	var bite := {"rs": [70, 0, 10], "re": [110, 0, 0], "rhand": [10, -80, -215, 100]}
	return _make(4.4, [
		{"t": 0.0, "pose": _sit(drop, base.merged(rest).merged({"head": [0, 0, 0], "torso": [-8, 0, 0]}))},
		{"t": 0.9, "pose": _sit(drop, base.merged(bite).merged({"head": [-6, 0, 0], "torso": [-12, 0, 0]}))},
		{"t": 1.3, "pose": _sit(drop, base.merged(bite).merged({"head": [8, 0, 0], "torso": [-10, 0, 0]})), "ease": "snap"},
		{"t": 1.9, "pose": _sit(drop, base.merged(rest).merged({"head": [2, 0, 0], "torso": [-8, 0, 0]}))},
		{"t": 2.4, "pose": {"head": [-3, 0, 0]}},
		{"t": 2.7, "pose": {"head": [3, 0, 0]}},
		{"t": 3.0, "pose": {"head": [-3, 0, 0]}},
		{"t": 3.3, "pose": {"head": [3, 0, 0]}},
		{"t": 3.6, "pose": {"head": [0, 0, 0]}},
	])


## Tony: the sandwich in both hands, a big bite now and then.
static func _wise_guy(drop: float) -> Dictionary:
	var rest := {"ls": [30, 0, -10], "le": [55, 0, 0], "rs": [40, 0, 8], "re": [85, 0, 0], "rhand": [5, -45, -70, 0]}
	var bite := {"ls": [30, 0, -10], "le": [55, 0, 0], "rs": [72, 0, 8], "re": [115, 0, 0], "rhand": [5, -75, -175, 100]}
	return _make(5.2, [
		{"t": 0.0, "pose": _sit(drop, rest.merged({"head": [0, 0, 0]}))},
		{"t": 2.2, "pose": _sit(drop, rest.merged({"head": [2, 0, 0]}))},
		{"t": 3.0, "pose": _sit(drop, bite.merged({"head": [-5, 0, 0], "torso": [-12, 0, 0]}))},
		{"t": 3.4, "pose": _sit(drop, bite.merged({"head": [7, 0, 0], "torso": [-10, 0, 0]})), "ease": "snap"},
		{"t": 4.1, "pose": _sit(drop, rest.merged({"head": [-3, 0, 0]}))},
		{"t": 4.6, "pose": {"head": [3, 0, 0]}},
	])


## The Answer: cross-legged, back straight, hands on his knees, breathing.
static func _counter_master(drop: float) -> Dictionary:
	var legs := {"pos": [0, drop, 0], "lh": [72, 28, -58], "rh": [72, -28, 58], "lk": [-142, 0, 0], "rk": [-142, 0, 0],
		"ls": [30, 0, -12], "le": [48, 0, 0], "rs": [30, 0, 12], "re": [48, 0, 0]}
	return _make(4.0, [
		{"t": 0.0, "pose": legs.merged({"chest": [0, 0, 0], "head": [-4, 0, 0]})},
		{"t": 2.0, "pose": legs.merged({"chest": [4, 0, 0], "head": [0, 0, 0]})},
	])


## The Blur: leaning back on the log, hands behind his head, one knee up;
## now and then a long yawn and a stretch.
static func _combo_master(drop: float) -> Dictionary:
	var lounge := {"pos": [0, drop, 0], "lh": [96, 0, -10], "lk": [-10, 0, 0], "lf": [10, 0, 0], "rh": [118, 0, 8], "rk": [-88, 0, 0],
		"torso": [26, 0, 0], "chest": [6, 0, 0], "head": [-18, 0, 0],
		"ls": [150, 0, -40], "le": [110, 0, 0], "rs": [150, 0, 40], "re": [110, 0, 0],
		"lhand": [-55, 15, 75, 100], "rhand": [55, 15, 75, 100]}
	var yawn := lounge.merged({"head": [8, 0, 0], "chest": [14, 0, 0],
		"rs": [172, 0, 20], "re": [10, 0, 0], "rhand": [55, 15, 75, 0]}, true)
	return _make(9.0, [
		{"t": 0.0, "pose": lounge},
		{"t": 5.5, "pose": lounge},
		{"t": 6.4, "pose": yawn},
		{"t": 7.4, "pose": yawn},
		{"t": 8.3, "pose": lounge},
	])


## The Stray: elbows on his knees, one leg bouncing, looking all over.
static func _free_runner(drop: float) -> Dictionary:
	var base := {"torso": [-24, 0, 0], "ls": [52, 0, -4], "le": [74, 0, 0], "rs": [52, 0, 4], "re": [74, 0, 0],
		"rh": [80, 0, 9], "rk": [-72, 0, 0]}
	var keys: Array = []
	var length := 5.28
	var bounces := 24
	for i in bounces:
		var t := length * i / bounces
		keys.append({"t": t, "pose": {"rf": [-24, 0, 0], "rk": [-66, 0, 0]}, "ease": "ease"})
		keys.append({"t": t + length / bounces / 2.0, "pose": {"rf": [0, 0, 0], "rk": [-72, 0, 0]}, "ease": "ease"})
	var start := _sit(drop, base.merged({"head": [6, -32, 0]}))
	start.erase("rk")  # The bounce keys own the right knee.
	keys.append({"t": 0.0, "pose": start})
	keys.append({"t": 1.4, "pose": {"head": [6, -32, 0]}})
	keys.append({"t": 2.0, "pose": {"head": [0, 26, 0]}})
	keys.append({"t": 3.6, "pose": {"head": [0, 26, 0]}})
	keys.append({"t": 4.3, "pose": {"head": [10, 0, 0]}})
	return _make(length, keys)


## The Catalyst: head down in the tome on his lap, a page turned now and then.
static func _elementalist(drop: float) -> Dictionary:
	var read := {"torso": [-14, 0, 0], "head": [-26, 0, 0],
		"ls": [40, 0, 18], "le": [58, 0, 0], "rs": [40, 0, -18], "re": [58, 0, 0]}
	var turn := read.merged({"rs": [58, 0, -42], "re": [86, 0, 0], "head": [-24, -10, 0]}, true)
	return _make(7.5, [
		{"t": 0.0, "pose": _sit(drop, read)},
		{"t": 4.2, "pose": _sit(drop, read)},
		{"t": 4.8, "pose": _sit(drop, turn)},
		{"t": 5.5, "pose": _sit(drop, read)},
	])


# --- Seats and props ------------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	var material := Look.block_material(color) if glow <= 0.0 else Enemy._glow_material(color)
	if glow > 0.0:
		material.emission_energy_multiplier = glow
	return Scenery.box(parent, size, pos, material, rot)


func _furniture(spot: Dictionary) -> void:
	var at: Vector3 = spot.at
	var h: float = spot.seat
	match spot.on:
		"stump":
			var bark := Color(0.22, 0.14, 0.08)
			for k in 3:
				_box(self, Vector3(0.78, h, 0.78), at + Vector3(0, h / 2.0, 0), bark if k == 0 else bark.darkened(0.15), Vector3(0, k * PI / 6.0, 0))
			_box(self, Vector3(0.7, 0.03, 0.7), at + Vector3(0, h + 0.005, 0), Color(0.55, 0.42, 0.26))
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				_box(self, Vector3(0.16, 0.14, 0.5), at + Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), bark, Vector3(0.2, -a + PI / 2.0, 0))
			# An axe left in the stump's edge, and a bone on the ground.
			_box(self, Vector3(0.05, 0.6, 0.05), at + Vector3(0.28, h + 0.25, 0.22), Color(0.3, 0.2, 0.1), Vector3(0, 0, -0.5))
			_box(self, Vector3(0.04, 0.2, 0.22), at + Vector3(0.18, h + 0.04, 0.22), Color(0.5, 0.5, 0.55), Vector3(0, 0, -0.5))
			_box(self, Vector3(0.3, 0.05, 0.05), at + Vector3(-0.3, 0.03, 0.55), Color(0.85, 0.82, 0.72), Vector3(0, 0.8, 0))
		"crate":
			_box(self, Vector3(0.6, h, 0.6), at + Vector3(0, h / 2.0, 0), Color(0.3, 0.2, 0.11), Vector3(0, 0.3, 0))
			_box(self, Vector3(0.62, 0.05, 0.62), at + Vector3(0, h - 0.06, 0), Color(0.2, 0.13, 0.07), Vector3(0, 0.3, 0))
		"rock":
			_box(self, Vector3(0.7, h, 0.6), at + Vector3(0, h / 2.0, 0), Color(0.3, 0.3, 0.33), Vector3(0, 0.6, 0.06))
			_box(self, Vector3(0.45, 0.2, 0.4), at + Vector3(0.35, 0.1, 0.2), Color(0.26, 0.26, 0.29), Vector3(0, 0.2, 0))


## Props in their hands: the Mauler's meat, Tony's sandwich, the tome.
func _props(fighter: String, body: FighterBody) -> void:
	var joints: Dictionary = body._joints
	var hand := Vector3(0, -body._fist_reach(), -0.02)
	match fighter:
		"berserker":
			var meat := Node3D.new()
			meat.position = hand
			joints.re.add_child(meat)
			# The bone in his glove, the meat out front (-Z), aimed by _aim_food.
			_box(meat, Vector3(0.06, 0.06, 0.4), Vector3(0, 0, 0.0), Color(0.9, 0.87, 0.78))
			_box(meat, Vector3(0.11, 0.11, 0.08), Vector3(0, 0, 0.2), Color(0.9, 0.87, 0.78))
			_box(meat, Vector3(0.26, 0.24, 0.3), Vector3(0, 0, -0.32), Color(0.45, 0.2, 0.1))
			_box(meat, Vector3(0.2, 0.1, 0.26), Vector3(0.03, 0.1, -0.33), Color(0.6, 0.28, 0.12))
			meat.set_meta("grip", hand)
			meat.set_meta("tip", 0.47)
			_food[fighter] = meat
		"wise_guy":
			var sub := Node3D.new()
			sub.position = hand
			joints.re.add_child(sub)
			# A long sub held at one end, the far end (-Z) toward his mouth.
			var roll := Node3D.new()
			roll.position = Vector3(0, 0, -0.2)
			sub.add_child(roll)
			_box(roll, Vector3(0.1, 0.06, 0.38), Vector3(0, -0.05, 0), Color(0.78, 0.55, 0.28))
			_box(roll, Vector3(0.11, 0.03, 0.36), Vector3(0, -0.005, 0), Color(0.85, 0.35, 0.35))
			_box(roll, Vector3(0.12, 0.02, 0.36), Vector3(0, 0.02, 0), Color(0.4, 0.75, 0.25))
			_box(roll, Vector3(0.11, 0.015, 0.35), Vector3(0, 0.035, 0), Color(0.95, 0.8, 0.25))
			_box(roll, Vector3(0.1, 0.06, 0.38), Vector3(0, 0.07, 0), Color(0.8, 0.57, 0.3))
			sub.set_meta("grip", hand)
			sub.set_meta("tip", 0.39)
			_food[fighter] = sub
		"elementalist":
			var tome := Node3D.new()
			tome.position = Vector3(0, 0.06, -0.34)
			tome.rotation = Vector3(-0.35, 0, 0)
			joints.hips.add_child(tome)
			for side in [-1.0, 1.0]:
				_box(tome, Vector3(0.27, 0.05, 0.4), Vector3(side * 0.14, 0, 0), Color(0.3, 0.1, 0.35), Vector3(0, 0, side * 0.12))
				_box(tome, Vector3(0.24, 0.02, 0.36), Vector3(side * 0.13, 0.035, 0), Color(0.85, 0.75, 1.0), Vector3(0, 0, side * 0.12), 0.6)
			_box(tome, Vector3(0.05, 0.08, 0.42), Vector3(0, -0.01, 0), Color(0.75, 0.6, 0.2))
			var motes := CPUParticles3D.new()
			motes.amount = 10 if Settings.use_web_profile() else 24
			motes.lifetime = 2.4
			motes.position = Vector3(0, 0.08, 0)
			motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			motes.emission_box_extents = Vector3(0.2, 0.02, 0.15)
			motes.direction = Vector3.UP
			motes.spread = 25.0
			motes.gravity = Vector3(0, 0.12, 0)
			motes.initial_velocity_min = 0.15
			motes.initial_velocity_max = 0.45
			var mote := BoxMesh.new()
			mote.size = Vector3.ONE * 0.035
			var glow := Enemy._glow_material(Color(0.6, 0.75, 1.0))
			glow.emission_energy_multiplier = 2.5
			glow.vertex_color_use_as_albedo = true
			mote.material = glow
			motes.mesh = mote
			var ramp := Gradient.new()
			ramp.set_color(0, Color(0.7, 0.5, 1.0))
			ramp.add_point(0.5, Color(0.4, 0.8, 1.0))
			ramp.set_color(ramp.get_point_count() - 1, Color(0.4, 0.8, 1.0, 0.0))
			motes.color_ramp = ramp
			var shrink := Curve.new()
			shrink.add_point(Vector2(0, 1))
			shrink.add_point(Vector2(1, 0.2))
			motes.scale_amount_curve = shrink
			tome.add_child(motes)
