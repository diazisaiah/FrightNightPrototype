class_name Emotes
## The emote catalog: dances the player's fighter (PlayerBody) does while the
## camera pulls out to third person. Hold the emote key for the wheel.
##
## Each dance is a file, emotes/<id>.json (2026-10-30), made in the
## playground's Emote Studio from a tracked clip of the real dance or by hand:
##   {"name": "Floss", "length": 0.6, "loop": true, "plant": true,
##    "keys": [{"t": 0, "pose": {"ls": [25.8, 0, -54.4], "pos": [11, -3, 0]}}, ...]}
## - t: seconds. length: the loop's length (the last key flows back into the
##   first). loop_start: seconds of intro that play once before the loop.
## - pose: joint rotations in degrees [x, y, z], "pos" the hip offset in cm.
##   A key can name only some joints; each joint flows through the keys that
##   name it, and one no key names stays at REST.
## - ease (on a key, for the move out of it): "smooth" (default, flows through
##   the keys without overshooting them), "ease" (stops at each key), "snap"
##   (fast out, settles in: pops and hits), "linear", "hold" (jumps).
## - plant: true drops and sways the hips with the feet kept on the canvas
##   (PlayerBody bends the knees and leans the legs; hand-made dances).
##   false: the legs are exactly as keyed (tracked dances, whose "pos"
##   already keeps the feet down).
##
## Joints are pivots; the body faces -Z:
##   hips: the whole body above the legs. torso: the waist bend. chest: the
##     rib cage over the waist (body rolls). neck, head: +x tips back.
##     torso, chest, neck and head: +x leans back, +y turns left, +z tilts left.
##   shoulders ls/rs: +x raises the arm forward (180 is straight up), z swings
##     it sideways (+z toward the fighter's right: outward for the right arm,
##     across the body for the left).
##   elbows le/re: +x bends the forearm forward / up.
##   hips lh/rh: +x lifts the thigh forward; knees lk/rk: -x bends.
##   ankles lf/rf: measured from flat on the floor, whatever the leg does:
##     +x lifts the toes (heel tap), -x points them (up on the toes), y turns
##     the foot out or in.
## mirror() flips a pose left to right.

const DIR := "res://emotes/"
const JOINTS := ["hips", "torso", "chest", "neck", "head", "ls", "le", "rs", "re", "lh", "lk", "lf", "rh", "rk", "rf"]
const REST := {
	"ls": Vector3(0.05, 0, -0.12), "le": Vector3(0.25, 0, 0),
	"rs": Vector3(0.05, 0, 0.12), "re": Vector3(0.25, 0, 0),
}
const EASES := ["smooth", "ease", "snap", "linear", "hold"]
## Wheel order (clockwise from the top).
const ORDER := ["default", "dab", "nae_nae", "floss", "take_the_l", "griddy", "horse_ride", "running_man", "bros_shuffle", "boo_yah", "intense_yelling", "overexerted", "plumber_jump"]

static var _clips := {}


static func name_of(id: String) -> String:
	return String(raw(id).get("name", id.capitalize()))


## The dance's file as written (empty if there's none).
static func raw(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## The dance, ready to play (sample()). Loaded once.
static func clip(id: String) -> Dictionary:
	if not _clips.has(id):
		_clips[id] = parse(raw(id))
	return _clips[id]


## Forgets loaded dances (the Emote Studio, after a save).
static func reload() -> void:
	_clips.clear()


## A dance file's contents made ready to play: each joint's keys in radians
## (pos in meters) with their slopes, and the loop wrapped round.
static func parse(data: Dictionary) -> Dictionary:
	var length := maxf(float(data.get("length", 1.0)), 0.01)
	var loop: bool = data.get("loop", true)
	var loop_start := clampf(float(data.get("loop_start", 0.0)), 0.0, length - 0.01)
	var keys: Array = data.get("keys", []).duplicate()
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.t) < float(b.t))
	var tracks := {}
	for joint in JOINTS + ["pos"]:
		var times: Array = []
		var values: Array = []
		var eases: Array = []
		for key: Dictionary in keys:
			var pose: Dictionary = key.get("pose", {})
			if not pose.has(joint):
				continue
			var a: Array = pose[joint]
			var v := Vector3(a[0], a[1], a[2])
			values.append(v / 100.0 if joint == "pos" else v * (PI / 180.0))
			times.append(float(key.t))
			eases.append(maxi(EASES.find(String(key.get("ease", "smooth"))), 0))
		if times.is_empty():
			continue
		if loop:
			_wrap(times, values, eases, loop_start, length)
		tracks[joint] = {"t": PackedFloat32Array(times), "v": values, "e": eases, "m": _slopes(times, values)}
	return {"length": length, "loop": loop, "loop_start": loop_start, "plant": bool(data.get("plant", true)), "tracks": tracks}


## Copies the loop's first keys one loop on (and, with no intro, its last
## key one loop back), so the end flows into the start.
static func _wrap(times: Array, values: Array, eases: Array, loop_start: float, length: float) -> void:
	var first := -1
	for i in times.size():
		if times[i] >= loop_start - 0.0001:
			first = i
			break
	if first < 0:
		return
	var period := length - loop_start
	var count := times.size() - first
	var last := times.size() - 1
	for i in 2:
		var k := first + i % count
		times.append(times[k] + period * (1 + i / count))
		values.append(values[k])
		eases.append(eases[k])
	if loop_start <= 0.0:
		times.push_front(times[last] - period)
		values.push_front(values[last])
		eases.push_front(eases[last])


## Each key's slope (per second) for the smooth curve: the average of the
## moves in and out, flat where the joint turns round (so it never swings past
## a key), and limited so the curve stays between its keys.
static func _slopes(times: Array, values: Array) -> Array:
	var slopes: Array = []
	var n := times.size()
	for i in n:
		if i == 0 or i == n - 1:
			slopes.append(Vector3.ZERO)
			continue
		var d0: Vector3 = (values[i] - values[i - 1]) / maxf(times[i] - times[i - 1], 0.0001)
		var d1: Vector3 = (values[i + 1] - values[i]) / maxf(times[i + 1] - times[i], 0.0001)
		var m := Vector3.ZERO
		for c in 3:
			if d0[c] * d1[c] > 0.0:
				var s := (d0[c] + d1[c]) * 0.5
				m[c] = signf(s) * minf(absf(s), 3.0 * minf(absf(d0[c]), absf(d1[c])))
		slopes.append(m)
	return slopes


## The pose at a time in the dance: joint -> rotation (radians), "pos" ->
## hip offset (meters). Joints the dance doesn't move are left out.
static func sample(dance: Dictionary, time: float) -> Dictionary:
	var t := time
	var length: float = dance.length
	if dance.loop and t >= length:
		t = dance.loop_start + fmod(t - dance.loop_start, length - dance.loop_start)
	var pose := {}
	for joint in dance.tracks:
		pose[joint] = _track_at(dance.tracks[joint], t)
	return pose


static func _track_at(track: Dictionary, t: float) -> Vector3:
	var times: PackedFloat32Array = track.t
	var values: Array = track.v
	var n := times.size()
	if n == 1 or t <= times[0]:
		return values[0]
	if t >= times[n - 1]:
		return values[n - 1]
	var i := times.bsearch(t, true) - 1
	var span := maxf(times[i + 1] - times[i], 0.0001)
	var u := (t - times[i]) / span
	var a: Vector3 = values[i]
	var b: Vector3 = values[i + 1]
	match track.e[i]:
		1:
			return a.lerp(b, u * u * (3.0 - 2.0 * u))
		2:
			return a.lerp(b, 1.0 - pow(1.0 - u, 3.0))
		3:
			return a.lerp(b, u)
		4:
			return a
	var u2 := u * u
	var u3 := u2 * u
	return a * (2.0 * u3 - 3.0 * u2 + 1.0) + track.m[i] * span * (u3 - 2.0 * u2 + u) \
			+ b * (-2.0 * u3 + 3.0 * u2) + track.m[i + 1] * span * (u3 - u2)


## The pose with left and right swapped.
static func mirror(pose: Dictionary) -> Dictionary:
	var flipped := {}
	for joint in pose:
		var value: Vector3 = pose[joint]
		var other: String = joint
		if joint.length() == 2 and joint[0] in ["l", "r"]:
			other = ("r" if joint[0] == "l" else "l") + joint[1]
		if joint == "pos":
			flipped[other] = Vector3(-value.x, value.y, value.z)
		else:
			flipped[other] = Vector3(value.x, -value.y, -value.z)
	return flipped
