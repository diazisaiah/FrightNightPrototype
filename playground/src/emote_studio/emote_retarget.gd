class_name EmoteRetarget
## Turns a tracked clip (emote_lab's <id>.track.json: MediaPipe's 33 joints in
## 3D for every frame) into an emote (Emotes' file format) on the fighter's
## rig: smooths the tracking, works out every joint's rotation frame by frame,
## puts the hips at the right height (the lowest foot on the canvas, lifted
## for jumps), then keeps only the keys the motion needs.
##
## MediaPipe's world joints are in meters round the hips: x to the picture's
## right, y down, z away from the camera. A dancer facing the camera has their
## left on the picture's right; the fighter faces -Z with his left at -X, so a
## joint maps to (-x, -y, z). A mirrored (selfie) clip swaps left and right.

## MediaPipe's joint numbers.
const NOSE := 0
const EAR := [7, 8]
const SHOULDER := [11, 12]
const ELBOW := [13, 14]
const WRIST := [15, 16]
const HIP := [23, 24]
const KNEE := [25, 26]
const ANKLE := [27, 28]
const HEEL := [29, 30]
const TOE := [31, 32]
## The nose sits below and ahead of the ears: a level head reads this much
## pitched down.
const NOSE_PITCH := 0.32
## The fighter's thigh and shin (FighterBody: knee 0.44 under the hip, ankle
## 0.4 under the knee).
const RIG_LEG := 0.84
## A hop must lift the lower foot at least this far (meters) to count.
const JUMP_MIN := 0.04


## The emote file for a track. options: smooth (frames of blur, 0 none),
## tolerance (degrees a key may be off before another is kept), travel (keep
## side to side movement across the floor), loop.
static func to_emote(track: Dictionary, body: PlayerBody, options := {}) -> Dictionary:
	var frames := landmark_frames(track, float(options.get("smooth", 1.5)))
	if frames.is_empty():
		return {}
	var poses: Array = []
	var previous := {}
	for joints: Array in frames:
		var pose := _pose(joints, previous)
		previous = pose
		poses.append(pose)
	_unwrap(poses)
	_place_hips(poses, frames, track, body, bool(options.get("travel", true)))
	var times: Array = track.frames.map(func(f: Dictionary) -> float: return float(f.t))
	var keep := _reduce(poses, times, float(options.get("tolerance", 6.0)))
	var keys: Array = []
	for i in keep:
		var pose := {}
		for joint in poses[i]:
			var v: Vector3 = poses[i][joint]
			v = v * 100.0 if joint == "pos" else v * (180.0 / PI)
			pose[joint] = [snappedf(v.x, 0.1), snappedf(v.y, 0.1), snappedf(v.z, 0.1)]
		keys.append({"t": snappedf(times[i] - times[0], 0.001), "pose": pose})
	return {
		"name": String(track.get("id", "new")).capitalize(),
		"length": snappedf(maxf(float(track.get("length", times[-1] - times[0])), times[-1] - times[0] + 0.03), 0.001),
		"loop": bool(options.get("loop", true)), "plant": false,
		"source": String(track.get("id", "")) + ".track.json",
		"keys": keys,
	}


## Every frame's 33 joints in the fighter's space (Vector3s), gaps filled
## from the frames either side, blurred over time to take out the tracker's
## jitter.
static func landmark_frames(track: Dictionary, smooth: float) -> Array:
	var raw: Array = track.get("frames", [])
	var mirror: bool = track.get("mirror", false)
	var out: Array = []
	var found: Array = []
	for f: Dictionary in raw:
		if not f.has("world"):
			out.append(null)
			continue
		var joints: Array = []
		joints.resize(33)
		for i in 33:
			var p: Array = f.world[_swap(i) if mirror else i]
			joints[i] = Vector3(p[0] if mirror else -p[0], -p[1], p[2])
		out.append(joints)
		found.append(out.size() - 1)
	if found.is_empty():
		return []
	# Gaps: the nearest tracked frames, blended.
	for i in out.size():
		if out[i] != null:
			continue
		var before := -1
		var after := -1
		for k in found:
			if k < i:
				before = k
			elif after < 0:
				after = k
		if before < 0 or after < 0:
			out[i] = (out[after if before < 0 else before] as Array).duplicate()
		else:
			var u := float(i - before) / float(after - before)
			var joints: Array = []
			for j in 33:
				joints.append((out[before][j] as Vector3).lerp(out[after][j], u))
			out[i] = joints
	if smooth <= 0.0:
		return out
	var reach := int(ceil(smooth * 2.5))
	var blurred: Array = []
	for i in out.size():
		var joints: Array = []
		for j in 33:
			var sum := Vector3.ZERO
			var weight := 0.0
			for k in range(maxi(i - reach, 0), mini(i + reach, out.size() - 1) + 1):
				var w := exp(-0.5 * pow((k - i) / smooth, 2.0))
				sum += (out[k][j] as Vector3) * w
				weight += w
			joints.append(sum / weight)
		blurred.append(joints)
	return blurred


## MediaPipe's joint on the other side (left 11 <-> right 12, and so on).
static func _swap(i: int) -> int:
	if i == 0:
		return 0
	if i <= 10:
		# Eyes and ears 1-6 swap 1<->4, 2<->5, 3<->6; ears 7<->8; mouth 9<->10.
		if i <= 6:
			return i + 3 if i <= 3 else i - 3
		return i + 1 if i % 2 == 1 else i - 1
	return i + 1 if i % 2 == 1 else i - 1


## A frame of axes: x (the fighter's right), y (up), z (back), from a right
## direction and an up direction.
static func _frame(right: Vector3, up: Vector3) -> Basis:
	var x := right.normalized()
	var y := (up - x * up.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


## One frame's joint rotations (radians) from its 33 joints.
static func _pose(p: Array, previous: Dictionary) -> Dictionary:
	var hip_mid: Vector3 = (p[HIP[0]] + p[HIP[1]]) * 0.5
	var shoulder_mid: Vector3 = (p[SHOULDER[0]] + p[SHOULDER[1]]) * 0.5
	var pelvis := _frame(p[HIP[1]] - p[HIP[0]], shoulder_mid - hip_mid)
	var ribs := _frame(p[SHOULDER[1]] - p[SHOULDER[0]], shoulder_mid - hip_mid)
	var ear_mid: Vector3 = (p[EAR[0]] + p[EAR[1]]) * 0.5
	var ear_right: Vector3 = (p[EAR[1]] - p[EAR[0]]).normalized()
	var face: Vector3 = p[NOSE] - ear_mid
	var back := -(face - ear_right * face.dot(ear_right)).normalized()
	var skull := Basis(ear_right, back.cross(ear_right), back)
	skull = skull * Basis(Vector3.RIGHT, NOSE_PITCH)
	var pose := {}
	pose.hips = pelvis.get_euler()
	# The pelvis to the rib cage, half at the waist and half at the chest; the
	# rib cage to the head, half at the neck and half at the head.
	var bend := Quaternion(pelvis.inverse() * ribs)
	var half := Quaternion.IDENTITY.slerp(bend, 0.5)
	pose.torso = half.get_euler()
	pose.chest = half.get_euler()
	var nod := Quaternion.IDENTITY.slerp(Quaternion(ribs.inverse() * skull), 0.5)
	pose.neck = nod.get_euler()
	pose.head = nod.get_euler()
	for side in 2:
		var s := "l" if side == 0 else "r"
		var arm := _limb(ribs, p[SHOULDER[side]], p[ELBOW[side]], p[WRIST[side]], -1.0, previous.get(s + "s"))
		pose[s + "s"] = arm[0]
		pose[s + "e"] = Vector3(arm[1], 0, 0)
		var leg := _limb(pelvis, p[HIP[side]], p[KNEE[side]], p[ANKLE[side]], 1.0, previous.get(s + "h"))
		pose[s + "h"] = leg[0]
		pose[s + "k"] = Vector3(-leg[1], 0, 0)
		# The foot from flat on the floor: toes up or down, turned out or in
		# against the hips.
		var foot: Vector3 = p[TOE[side]] - p[HEEL[side]]
		var level := Vector2(foot.x, foot.z).length()
		var turn := wrapf(atan2(-foot.x, -foot.z) - pose.hips.y, -PI, PI)
		pose[s + "f"] = Vector3(atan2(foot.y, level), clampf(turn, -0.7, 0.7), 0)
	return pose


## A two-bone limb (shoulder or hip) in its parent's frame: [rotation of the
## upper bone, bend at the middle joint]. The bone hangs along -Y; the middle
## joint bends the lower bone toward -Z for arms (bend -1: forward / up) and
## +Z for legs (bend 1: the shin back). A nearly straight limb keeps the twist
## it had, or none.
static func _limb(parent: Basis, a: Vector3, b: Vector3, c: Vector3, bend: float, before: Variant) -> Array:
	var to_local := parent.inverse()
	var upper := (to_local * (b - a)).normalized()
	var lower := (to_local * (c - b)).normalized()
	var y := -upper
	var across := lower - upper * lower.dot(upper)
	var z := Vector3.ZERO
	if across.length() > 0.2:
		z = across.normalized() * bend
	elif before is Vector3:
		z = Basis.from_euler(before).z
	else:
		z = Vector3(0, 0, 1)
	z = (z - y * z.dot(y)).normalized()
	if z.length() < 0.5:
		z = Vector3(0, 0, 1) - y * y.z
		z = z.normalized() if z.length() > 0.01 else Vector3(1, 0, 0)
	var basis := Basis(y.cross(z), y, z)
	return [basis.get_euler(), acos(clampf(upper.dot(lower), -1.0, 1.0))]


## Keeps each angle continuous frame to frame (no jump from 179 to -179).
static func _unwrap(poses: Array) -> void:
	for i in range(1, poses.size()):
		for joint in poses[i]:
			if joint == "pos":
				continue
			var v: Vector3 = poses[i][joint]
			var before: Vector3 = poses[i - 1][joint]
			for c in 3:
				while v[c] - before[c] > PI:
					v[c] -= TAU
				while v[c] - before[c] < -PI:
					v[c] += TAU
			poses[i][joint] = v


## The hips' offset. The tracker gives every joint round the hips, so where
## the hips are comes from the feet: the foot taking the weight (the lower
## one, or both) stays where the fighter's feet stand at rest, the knees
## bending and the hips dropping or swaying over it. Lifted when the picture
## shows both feet off the floor (a jump), and moved across the floor as the
## dancer's feet travel in the picture.
static func _place_hips(poses: Array, frames: Array, track: Dictionary, body: PlayerBody, travel: bool) -> void:
	var raw: Array = track.frames
	var tracked_leg := 0.0
	for joints: Array in frames:
		for side in 2:
			tracked_leg += (joints[HIP[side]] - joints[KNEE[side]]).length() + (joints[KNEE[side]] - joints[ANKLE[side]]).length()
	tracked_leg /= frames.size() * 2.0
	var to_rig := RIG_LEG / maxf(tracked_leg, 0.1)
	body._apply({}, false)
	var rest := _stance(body)
	# The floor in the picture: where the lower foot usually is.
	var lows: Array = []
	var meters: Array = []
	var aspect := float(track.get("aspect", 1.0))
	for i in raw.size():
		var f: Dictionary = raw[i]
		if not f.has("image"):
			lows.append(null)
			meters.append(null)
			continue
		lows.append(maxf(f.image[ANKLE[0]][1], f.image[ANKLE[1]][1]))
		# Picture height per meter: shoulders to ankles, in the picture and in 3D.
		var top := (Vector2(f.image[SHOULDER[0]][0], f.image[SHOULDER[0]][1]) + Vector2(f.image[SHOULDER[1]][0], f.image[SHOULDER[1]][1])) * 0.5
		var bottom := (Vector2(f.image[ANKLE[0]][0], f.image[ANKLE[0]][1]) + Vector2(f.image[ANKLE[1]][0], f.image[ANKLE[1]][1])) * 0.5
		var joints: Array = frames[i]
		var height_3d: float = ((joints[SHOULDER[0]] + joints[SHOULDER[1]]) * 0.5 - (joints[ANKLE[0]] + joints[ANKLE[1]]) * 0.5).length()
		meters.append(height_3d / maxf(Vector2((top.x - bottom.x) * aspect, top.y - bottom.y).length(), 0.01))
	var sorted := lows.filter(func(v: Variant) -> bool: return v != null)
	sorted.sort()
	var floor_y: float = sorted[int(sorted.size() * 0.9)] if not sorted.is_empty() else 1.0
	var start_x := INF
	for i in poses.size():
		var pose: Dictionary = poses[i]
		pose.pos = Vector3.ZERO
		body._apply(pose, false)
		var stance := _stance(body)
		var offset := Vector3(rest.x - stance.x, rest.y - stance.y, rest.z - stance.z)
		if lows[i] != null:
			var lift: float = maxf((floor_y - lows[i]) * meters[i] * to_rig, 0.0)
			if lift >= JUMP_MIN:
				offset.y += lift
			if travel:
				var f: Dictionary = raw[i]
				var feet_x := _weighted(f.image[ANKLE[0]][0], f.image[ANKLE[1]][0], f.image[ANKLE[0]][1], f.image[ANKLE[1]][1], -0.01)
				if start_x == INF:
					start_x = feet_x
				offset.x += (feet_x - start_x) * aspect * meters[i] * to_rig * (1.0 if track.get("mirror", false) else -1.0)
		pose.pos = offset
	body._apply({})


## Where the body stands, in its own space: between the ankles, leaning to
## the lower one (the one taking the weight), at the lower one's height.
static func _stance(body: PlayerBody) -> Vector3:
	var l := body.to_local((body._joints.get("lf", body._joints.lk) as Node3D).global_position)
	var r := body.to_local((body._joints.get("rf", body._joints.rk) as Node3D).global_position)
	var x := _weighted(l.x, r.x, l.y, r.y, 0.03)
	var z := _weighted(l.z, r.z, l.y, r.y, 0.03)
	return Vector3(x, minf(l.y, r.y), z)


## a and b blended toward the lower of the two (height ha, hb; a negative
## softness for picture heights, which grow downward). A foot raised more
## than a few cm carries no weight.
static func _weighted(a: float, b: float, ha: float, hb: float, softness: float) -> float:
	var low := minf(ha, hb) if softness > 0.0 else maxf(ha, hb)
	var wa := exp(-absf(ha - low) / absf(softness))
	var wb := exp(-absf(hb - low) / absf(softness))
	return (a * wa + b * wb) / (wa + wb)


## The frames to keep as keys: the first and last, then wherever playing
## straight between the kept ones misses the motion by more than tolerance
## (degrees; centimeters for the hips).
static func _reduce(poses: Array, times: Array, tolerance: float) -> Array:
	var keep := {0: true, poses.size() - 1: true}
	_split(poses, times, 0, poses.size() - 1, tolerance, keep)
	var out := keep.keys()
	out.sort()
	return out


static func _split(poses: Array, times: Array, a: int, b: int, tolerance: float, keep: Dictionary) -> void:
	if b - a < 2:
		return
	var worst := -1
	var worst_error := tolerance
	for i in range(a + 1, b):
		var u := (float(times[i]) - float(times[a])) / maxf(float(times[b]) - float(times[a]), 0.0001)
		var error := 0.0
		for joint in poses[i]:
			var guess: Vector3 = (poses[a][joint] as Vector3).lerp(poses[b][joint], u)
			var miss: Vector3 = (poses[i][joint] - guess).abs()
			var scale := 100.0 if joint == "pos" else 180.0 / PI
			error = maxf(error, maxf(miss.x, maxf(miss.y, miss.z)) * scale)
		if error > worst_error:
			worst_error = error
			worst = i
	if worst < 0:
		return
	keep[worst] = true
	_split(poses, times, a, worst, tolerance, keep)
	_split(poses, times, worst, b, tolerance, keep)
