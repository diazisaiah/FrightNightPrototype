extends RefCounted
## Round trip for EmoteRetarget (Emote Studio -- --selftest): a known dance
## on the fighter is written out as if the tracker had seen it (MediaPipe's
## joints, from the body's own joints frame by frame), imported back, and the
## two compared: how far the hands, feet and head land from where the dance
## put them, measured from the hips (the shape of the pose; the old hand-made
## dances slide their standing foot, which the import's planted feet won't
## copy), plus how far the hips' height is off. Prints the misses in cm and
## PASS / FAIL.

const FPS := 30.0
## The worst a hand, foot or head may miss by, averaged over the dance (cm).
const MAX_MEAN_MISS := 3.0


static func run(body: PlayerBody, id: String) -> bool:
	var clip := Emotes.clip(id)
	var track := {"id": id, "mirror": false, "aspect": 1.0, "length": clip.length, "frames": []}
	var truth: Array = []
	var frames := int(clip.length * FPS)
	for i in frames:
		var t := i / FPS
		body._apply(Emotes.sample(clip, t), clip.plant)
		truth.append(_ends(body))
		track.frames.append(_seen(body, t))
	var data := EmoteRetarget.to_emote(track, body, {"smooth": 0.0, "tolerance": 2.0, "travel": false, "depth": 1.0, "square": false})
	var back := Emotes.parse(data)
	var total := 0.0
	var worst := 0.0
	var count := 0
	var by_part := {}
	var hips_off := 0.0
	for i in frames:
		body._apply(Emotes.sample(back, i / FPS), back.plant)
		var ends := _ends(body)
		hips_off += absf(ends.hips.y - truth[i].hips.y) * 100.0 / frames
		for part in ends:
			if part == "hips":
				continue
			var miss: float = (ends[part] - truth[i][part]).length() * 100.0
			total += miss
			worst = maxf(worst, miss)
			by_part[part] = by_part.get(part, 0.0) + miss / frames
			count += 1
	body._apply({})
	var mean := total / maxf(count, 1)
	var parts: Array = []
	for part in by_part:
		parts.append("%s %.1f" % [part, by_part[part]])
	print("[retarget %s] %d keys; mean miss %.1f cm, worst %.1f cm (%s); hips height off %.1f cm" % [id, data["keys"].size(), mean, worst, ", ".join(parts), hips_off])
	return mean <= MAX_MEAN_MISS and hips_off <= MAX_MEAN_MISS


## Where the hands, feet and head are from the hips, and the hips, in the
## body's own space.
static func _ends(body: PlayerBody) -> Dictionary:
	var j: Dictionary = body._joints
	var hips := body.to_local(j.hips.global_position)
	return {
		"l hand": body.to_local(j.le.global_transform * Vector3(0, -0.26, 0)) - hips,
		"r hand": body.to_local(j.re.global_transform * Vector3(0, -0.26, 0)) - hips,
		"l foot": body.to_local(j.lf.global_transform * Vector3(0, -0.06, -0.14)) - hips,
		"r foot": body.to_local(j.rf.global_transform * Vector3(0, -0.06, -0.14)) - hips,
		"head": body.to_local(j.head.global_transform * Vector3(0, 0.3, 0)) - hips,
		"hips": hips,
	}


## One frame as MediaPipe reports it: its 33 joints in meters round the hips
## (x to the picture's right, y down, z away from the camera), and where they
## fall in a picture of the dancer from the front.
static func _seen(body: PlayerBody, t: float) -> Dictionary:
	var j: Dictionary = body._joints
	var at := {}
	at[0] = j.head.global_transform * Vector3(0, 0.2 - 0.19 * tan(EmoteRetarget.NOSE_PITCH), -0.19)
	at[7] = j.head.global_transform * Vector3(-0.16, 0.2, 0)
	at[8] = j.head.global_transform * Vector3(0.16, 0.2, 0)
	for side in 2:
		var s := "l" if side == 0 else "r"
		at[11 + side] = j[s + "s"].global_position
		at[13 + side] = j[s + "e"].global_position
		at[15 + side] = j[s + "e"].global_transform * Vector3(0, -0.26, 0)
		# Pinky, index and thumb at the fist too (the face reach aims its middle).
		for k in [17, 19, 21]:
			at[k + side] = at[15 + side]
		at[23 + side] = j[s + "h"].global_position
		at[25 + side] = j[s + "k"].global_position
		at[27 + side] = j[s + "f"].global_position
		at[29 + side] = j[s + "f"].global_transform * Vector3(0, -0.06, 0.07)
		at[31 + side] = j[s + "f"].global_transform * Vector3(0, -0.06, -0.14)
	var hips: Vector3 = (at[23] + at[24]) * 0.5
	var world: Array = []
	var image: Array = []
	for i in 33:
		var p: Vector3 = body.to_local(at.get(i, at[0]))
		var rel := (p - body.to_local(hips))
		world.append([-rel.x, -rel.y, rel.z, 1.0])
		# A 2.4 m tall picture, the fighter's left on its right.
		image.append([0.5 - p.x / 2.4, 1.0 - (p.y + 0.1) / 2.4])
	return {"t": t, "world": world, "image": image}
