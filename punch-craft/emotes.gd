class_name Emotes
## The emote catalog: meme dances the player's fighter (PlayerBody) does while
## the camera pulls out to third person. Hold the emote key for the wheel.
##
## A dance is a loop of keyframes [seconds, pose]: each pose is eased into
## over its seconds, then the next one starts. A pose sets joint rotations
## (radians, Vector3 x/y/z) and "pos" (a hip offset in meters); joints it
## doesn't name go back to REST. The body faces -Z:
##   shoulders ls/rs: +x raises the arm forward (3.0 is straight up), z swings
##     it sideways (+z toward the fighter's right, +X: outward for the right
##     arm, across the body for the left).
##   elbows le/re: +x bends the forearm forward / up.
##   hips lh/rh: +x lifts the thigh forward; knees lk/rk: -x bends.
##   torso and head: +x leans back, +y turns left, +z tilts left.
## mirror() flips a pose left to right, so most dances write one side.

const JOINTS := ["hips", "torso", "head", "ls", "le", "rs", "re", "lh", "lk", "rh", "rk"]
const REST := {
	"ls": Vector3(0.05, 0, -0.12), "le": Vector3(0.25, 0, 0),
	"rs": Vector3(0.05, 0, 0.12), "re": Vector3(0.25, 0, 0),
}
## Wheel order (clockwise from the top).
const ORDER := ["default", "dab", "nae_nae", "floss", "take_the_l", "griddy", "horse_ride", "running_man", "bros_shuffle", "boo_yah", "intense_yelling", "overexerted", "plumber_jump"]
const NAMES := {
	"default": "The Default", "dab": "Dab", "nae_nae": "Nae Nae", "floss": "Floss",
	"take_the_l": "Take the L", "griddy": "Griddy", "horse_ride": "Horse Ride",
	"running_man": "Running Man", "bros_shuffle": "Bros. Shuffle", "boo_yah": "Boo-Yah",
	"intense_yelling": "Intense Yelling", "overexerted": "Overexerted", "plumber_jump": "Plumber Jump",
}


static func name_of(id: String) -> String:
	return NAMES.get(id, id.capitalize())


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


## A pose built on another one (later keys win).
static func with(base: Dictionary, changes: Dictionary) -> Dictionary:
	var pose := base.duplicate()
	pose.merge(changes, true)
	return pose


## The keyframes of a dance: [[seconds, pose], ...], looped.
static func keys(id: String) -> Array:
	# Tightened 2026-10-17: big, readable shapes from the front (sideways hip
	# sway, arms in the frontal plane), crisp timing. Hip drops and sways keep
	# the feet planted (PlayerBody bends the knees), so poses only move "pos".
	match id:
		"_swing":
			# The secret ending's giant swing: leaning back, both arms out
			# front holding on.
			return [[0.3, {"pos": Vector3(0, -0.12, 0.06), "torso": Vector3(0.32, 0, 0), "head": Vector3(-0.1, 0, 0),
					"ls": Vector3(1.4, 0, 0.12), "le": Vector3(0.1, 0, 0), "rs": Vector3(1.4, 0, -0.12), "re": Vector3(0.1, 0, 0)}]]
		"_uppercut":
			# Wound down low, then up through the chin, rising onto the toes.
			var load_up := {"pos": Vector3(0, -0.16, 0), "torso": Vector3(-0.25, 0.35, 0),
					"rs": Vector3(-0.3, 0, 0.2), "re": Vector3(1.9, 0, 0), "ls": Vector3(0.9, 0, -0.2), "le": Vector3(2.0, 0, 0)}
			var rise := {"pos": Vector3(0, 0.05, 0), "torso": Vector3(0.15, -0.3, 0), "head": Vector3(0.2, 0, 0),
					"rs": Vector3(2.9, 0, 0.1), "re": Vector3(1.0, 0, 0), "ls": Vector3(0.9, 0, -0.2), "le": Vector3(2.0, 0, 0)}
			return [[0.35, load_up], [0.12, rise], [1.5, rise]]
		"default":
			# Bouncing arm pumps, then the swing: both arms across to one side
			# while the other leg kicks out.
			var pump := {"pos": Vector3(0.03, -0.09, 0), "rs": Vector3(1.9, 0, -0.45), "re": Vector3(1.2, 0, 0),
					"ls": Vector3(0.1, 0, -0.35), "le": Vector3(1.4, 0, 0), "torso": Vector3(0, -0.2, -0.06), "head": Vector3(0.05, -0.15, 0)}
			var up := {"pos": Vector3(0, -0.02, 0), "rs": Vector3(0.6, 0, 0.1), "re": Vector3(1.8, 0, 0),
					"ls": Vector3(0.6, 0, -0.1), "le": Vector3(1.8, 0, 0)}
			var swing := {"pos": Vector3(-0.08, -0.05, 0), "ls": Vector3(0.5, 0, -1.25), "le": Vector3(0.3, 0, 0),
					"rs": Vector3(1.0, 0, -0.75), "re": Vector3(0.6, 0, 0), "torso": Vector3(0, 0.35, 0.12),
					"rh": Vector3(0.15, 0, 0.75), "rk": Vector3(-0.35, 0, 0), "head": Vector3(0, 0.2, 0.08)}
			var middle := with(up, {"pos": Vector3(0, -0.08, 0)})
			return [[0.2, pump], [0.18, up], [0.2, mirror(pump)], [0.18, up],
					[0.2, pump], [0.18, up], [0.2, mirror(pump)], [0.18, up],
					[0.18, swing], [0.18, middle], [0.18, mirror(swing)], [0.18, middle],
					[0.18, swing], [0.18, middle], [0.18, mirror(swing)], [0.18, middle]]
		"dab":
			var ready := {"pos": Vector3(0, -0.04, 0), "rs": Vector3(0.3, 0, 0.2), "ls": Vector3(0.3, 0, -0.2)}
			var dab := {"pos": Vector3(0.05, -0.08, 0), "ls": Vector3(1.4, 0, 0.75), "le": Vector3(2.4, 0, 0),
					"rs": Vector3(1.8, 0, 1.3), "re": Vector3(0.0, 0, 0),
					"torso": Vector3(-0.25, -0.35, -0.25), "head": Vector3(-0.6, -0.55, -0.25)}
			return [[0.25, ready], [0.1, dab], [0.6, dab], [0.22, ready],
					[0.1, mirror(dab)], [0.6, mirror(dab)], [0.25, ready]]
		"nae_nae":
			# One hand high and waving side to side, the other loose and low,
			# the whole body rocking hip to hip with a bounce on every beat.
			var rock_a := {"pos": Vector3(-0.12, -0.12, 0), "rs": Vector3(2.9, 0, 0.85), "re": Vector3(0.35, 0, 0),
					"ls": Vector3(0.3, 0, -0.6), "le": Vector3(0.9, 0, 0), "torso": Vector3(0.2, 0.15, 0.26),
					"head": Vector3(0.15, 0.12, -0.2), "rh": Vector3(0.35, 0, -0.3), "rk": Vector3(-0.7, 0, 0)}
			var mid := {"pos": Vector3(0, -0.04, 0), "rs": Vector3(3.0, 0, 0.12), "re": Vector3(0.25, 0, 0),
					"ls": Vector3(0.35, 0, -0.3), "le": Vector3(1.1, 0, 0), "torso": Vector3(0.18, 0, 0)}
			var rock_b := {"pos": Vector3(0.12, -0.12, 0), "rs": Vector3(2.9, 0, -0.6), "re": Vector3(0.35, 0, 0),
					"ls": Vector3(0.45, 0, -0.1), "le": Vector3(1.4, 0, 0), "torso": Vector3(0.2, -0.15, -0.26),
					"head": Vector3(0.15, -0.12, 0.2), "lh": Vector3(0.35, 0, 0.3), "lk": Vector3(-0.7, 0, 0)}
			return [[0.22, rock_a], [0.12, mid], [0.22, rock_b], [0.12, mid]]
		"floss":
			# Straight arms swing wide side to side, swapping front and back;
			# the hips swing the other way.
			var left_front := {"pos": Vector3(0.11, -0.03, 0), "ls": Vector3(0.45, 0, -0.95), "le": Vector3(0.05, 0, 0),
					"rs": Vector3(-0.45, 0, -0.95), "re": Vector3(0.05, 0, 0), "torso": Vector3(0, 0, 0.14)}
			var right_back := {"pos": Vector3(-0.11, -0.03, 0), "ls": Vector3(-0.45, 0, 0.95), "le": Vector3(0.05, 0, 0),
					"rs": Vector3(0.45, 0, 0.95), "re": Vector3(0.05, 0, 0), "torso": Vector3(0, 0, -0.14)}
			var left_back := with(left_front, {"ls": Vector3(-0.45, 0, -0.95), "rs": Vector3(0.45, 0, -0.95)})
			var right_front := with(right_back, {"ls": Vector3(0.45, 0, 0.95), "rs": Vector3(-0.45, 0, 0.95)})
			return [[0.15, left_front], [0.15, right_back], [0.15, left_back], [0.15, right_front]]
		"take_the_l":
			# An L on the forehead, hopping knee to knee out to the sides.
			var l_hand := {"ls": Vector3(2.3, 0, 0.45), "le": Vector3(1.3, 0, 0), "head": Vector3(0, 0.15, 0.08)}
			var kick_left := with(l_hand, {"pos": Vector3(0.06, 0.04, 0), "lh": Vector3(0.6, 0, -0.75), "lk": Vector3(-1.3, 0, 0),
					"rs": Vector3(-0.2, 0, 0.55), "re": Vector3(0.5, 0, 0), "torso": Vector3(0, 0, -0.12)})
			var land := with(l_hand, {"pos": Vector3(0, -0.08, 0), "rs": Vector3(0.2, 0, 0.35), "re": Vector3(0.5, 0, 0)})
			var kick_right := with(l_hand, {"pos": Vector3(-0.06, 0.04, 0), "rh": Vector3(0.6, 0, 0.75), "rk": Vector3(-1.3, 0, 0),
					"rs": Vector3(0.6, 0, 0.55), "re": Vector3(0.5, 0, 0), "torso": Vector3(0, 0, 0.12)})
			return [[0.18, kick_left], [0.16, land], [0.18, kick_right], [0.16, land]]
		"griddy":
			# Heel taps with arms pumping, then the goggles.
			var step := {"pos": Vector3(0.05, -0.08, 0), "lh": Vector3(0.65, 0, -0.1), "lk": Vector3(-0.1, 0, 0),
					"rh": Vector3(-0.15, 0, 0),
					"ls": Vector3(-0.6, 0, -0.35), "le": Vector3(1.5, 0, 0), "rs": Vector3(1.1, 0, 0.35), "re": Vector3(1.5, 0, 0),
					"torso": Vector3(-0.2, 0.2, -0.08)}
			var goggles := {"pos": Vector3(0, -0.1, 0), "ls": Vector3(2.5, 0, 0.55), "le": Vector3(2.55, 0, 0),
					"rs": Vector3(2.5, 0, -0.55), "re": Vector3(2.55, 0, 0), "torso": Vector3(0.08, 0, 0)}
			return [[0.17, step], [0.17, mirror(step)], [0.17, step], [0.17, mirror(step)],
					[0.17, step], [0.17, mirror(step)], [0.17, step], [0.17, mirror(step)],
					[0.14, goggles], [0.2, with(goggles, {"pos": Vector3(0.06, -0.14, 0), "head": Vector3(0, 0, 0.22)})],
					[0.2, with(goggles, {"pos": Vector3(-0.06, -0.04, 0), "head": Vector3(0, 0, -0.22)})],
					[0.2, with(goggles, {"pos": Vector3(0.06, -0.14, 0), "head": Vector3(0, 0, 0.22)})]]
		"horse_ride":
			# Wide stance, wrists crossed on the reins, hopping foot to foot;
			# then the lasso overhead.
			var reins := {"pos": Vector3(0, -0.13, 0), "lh": Vector3(0, 0, -0.32), "rh": Vector3(0, 0, 0.32),
					"ls": Vector3(1.05, 0, 0.42), "le": Vector3(0.5, 0, 0), "rs": Vector3(1.05, 0, -0.42), "re": Vector3(0.5, 0, 0),
					"torso": Vector3(-0.12, 0, 0)}
			var hop_left := with(reins, {"pos": Vector3(0.05, 0.02, 0), "lh": Vector3(0.95, 0, -0.4), "lk": Vector3(-1.4, 0, 0)})
			var hop_right := mirror(hop_left)
			var keys := [[0.18, reins], [0.18, hop_left], [0.18, reins], [0.18, hop_right],
					[0.18, reins], [0.18, hop_left], [0.18, reins], [0.18, hop_right]]
			var lasso := [Vector3(2.9, 0, 0.5), Vector3(2.9, 0.5, 0.0), Vector3(2.9, 0, -0.35), Vector3(2.9, -0.5, 0.0)]
			for i in 8:
				var base: Dictionary = [reins, hop_left, reins, hop_right][i % 4]
				keys.append([0.18, with(base, {"rs": lasso[i % 4], "re": Vector3(0.35, 0, 0), "head": Vector3(0.15, 0, 0)})])
			return keys
		"running_man":
			var knee_up := {"pos": Vector3(0, 0.0, 0), "lh": Vector3(1.3, 0, 0), "lk": Vector3(-1.5, 0, 0),
					"rh": Vector3(-0.2, 0, 0),
					"ls": Vector3(-0.6, 0, -0.2), "le": Vector3(1.6, 0, 0), "rs": Vector3(0.9, 0, 0.2), "re": Vector3(1.6, 0, 0),
					"torso": Vector3(-0.12, 0, 0)}
			var drop := {"pos": Vector3(0, -0.11, 0),
					"ls": Vector3(0.15, 0, -0.2), "le": Vector3(1.5, 0, 0), "rs": Vector3(0.15, 0, 0.2), "re": Vector3(1.5, 0, 0),
					"torso": Vector3(-0.12, 0, 0)}
			return [[0.17, knee_up], [0.17, drop], [0.17, mirror(knee_up)], [0.17, drop]]
		"bros_shuffle":
			# Fists bouncing at the chest, knock-kneed sway, one fist pumping up.
			var pump := {"pos": Vector3(-0.07, -0.1, 0), "rs": Vector3(2.7, 0, 0.3), "re": Vector3(0.7, 0, 0),
					"ls": Vector3(0.3, 0, -0.25), "le": Vector3(1.7, 0, 0), "torso": Vector3(0, 0.12, -0.16),
					"head": Vector3(0, 0, 0.14), "lh": Vector3(0, 0, 0.12), "rh": Vector3(0, 0, -0.06)}
			var chest := {"pos": Vector3(0, -0.03, 0), "ls": Vector3(0.7, 0, -0.12), "le": Vector3(2.0, 0, 0),
					"rs": Vector3(0.7, 0, 0.12), "re": Vector3(2.0, 0, 0), "lh": Vector3(0, 0, 0.08), "rh": Vector3(0, 0, -0.08)}
			return [[0.18, pump], [0.16, chest], [0.18, mirror(pump)], [0.16, chest]]
		"intense_yelling":
			# Powering up: a wide squat, fists clenched down at the sides,
			# chest out, head thrown back yelling, the whole body shaking.
			# (PowerUpFx grows the aura, the rocks and the lightning.)
			var yell := {"pos": Vector3(0, -0.14, 0), "lh": Vector3(0.05, 0, -0.32), "rh": Vector3(0.05, 0, 0.32),
					"ls": Vector3(-0.35, 0, -0.5), "le": Vector3(0.55, 0, 0), "rs": Vector3(-0.35, 0, 0.5), "re": Vector3(0.55, 0, 0),
					"torso": Vector3(0.16, 0, 0), "head": Vector3(0.42, 0, 0)}
			var shake_a := with(yell, {"pos": Vector3(0.012, -0.15, 0), "torso": Vector3(0.17, 0.02, 0.03), "head": Vector3(0.44, 0.03, 0.02)})
			var shake_b := with(yell, {"pos": Vector3(-0.012, -0.13, 0), "torso": Vector3(0.15, -0.02, -0.03), "head": Vector3(0.4, -0.03, -0.02)})
			return [[0.05, shake_a], [0.05, shake_b], [0.05, shake_a], [0.05, yell], [0.05, shake_b], [0.05, shake_a]]
		"overexerted":
			# Intense Yelling with no aura, straight to the end: the strain,
			# then (PoopFx drops it at 1.2s) the slump of a man relieved.
			var yell := {"pos": Vector3(0, -0.14, 0), "lh": Vector3(0.05, 0, -0.32), "rh": Vector3(0.05, 0, 0.32),
					"ls": Vector3(-0.35, 0, -0.5), "le": Vector3(0.55, 0, 0), "rs": Vector3(-0.35, 0, 0.5), "re": Vector3(0.55, 0, 0),
					"torso": Vector3(0.16, 0, 0), "head": Vector3(0.42, 0, 0)}
			var shake_a := with(yell, {"pos": Vector3(0.015, -0.16, 0), "torso": Vector3(0.18, 0.03, 0.04), "head": Vector3(0.46, 0.04, 0.03)})
			var shake_b := with(yell, {"pos": Vector3(-0.015, -0.12, 0), "torso": Vector3(0.14, -0.03, -0.04), "head": Vector3(0.38, -0.04, -0.03)})
			var relief := {"pos": Vector3(0, -0.06, 0), "torso": Vector3(-0.22, 0, 0), "head": Vector3(-0.3, 0, 0),
					"ls": Vector3(-0.05, 0, -0.15), "le": Vector3(0.1, 0, 0), "rs": Vector3(-0.05, 0, 0.15), "re": Vector3(0.1, 0, 0)}
			var strain := []
			for i in 12:
				strain.append([0.1, shake_a if i % 2 == 0 else shake_b])
			return strain + [[0.25, relief], [1.6, with(relief, {"head": Vector3(-0.35, 0.2, 0)})]]
		"plumber_jump":
			# The plumber's jump: a crouch, then straight up, one fist punched
			# at the sky, the other arm down, one knee tucked; hang there, land.
			var crouch := {"pos": Vector3(0, -0.16, 0), "lh": Vector3(0.6, 0, 0), "lk": Vector3(-1.1, 0, 0),
					"rh": Vector3(0.6, 0, 0), "rk": Vector3(-1.1, 0, 0), "torso": Vector3(-0.2, 0, 0),
					"ls": Vector3(-0.4, 0, -0.2), "le": Vector3(0.6, 0, 0), "rs": Vector3(-0.4, 0, 0.2), "re": Vector3(0.6, 0, 0)}
			var jump := {"pos": Vector3(0, 0.6, 0), "rs": Vector3(3.0, 0, 0.12), "re": Vector3(0.05, 0, 0),
					"ls": Vector3(-0.25, 0, -0.3), "le": Vector3(0.1, 0, 0),
					"rh": Vector3(1.3, 0, 0), "rk": Vector3(-1.5, 0, 0), "lh": Vector3(-0.1, 0, 0), "lk": Vector3(-0.2, 0, 0),
					"torso": Vector3(0.05, 0, 0), "head": Vector3(0.2, 0, 0)}
			var apex := with(jump, {"pos": Vector3(0, 0.66, 0)})
			return [[0.25, crouch], [0.18, jump], [0.3, apex], [0.22, crouch], [0.35, {}]]
		"boo_yah":
			# The supervillain's "Oh yeah!": whip round into a T, sway; lean
			# back, hips out, hands wiggling low; claws up by the face; both
			# fists pumping overhead; a double biceps flex; smug hip swivels,
			# fists at the hips.
			var wind := {"pos": Vector3(0, -0.06, 0), "hips": Vector3(0, 0.9, 0), "torso": Vector3(0, 0.5, 0), "head": Vector3(0, 0.3, 0),
					"ls": Vector3(1.2, 0, 0.9), "le": Vector3(1.6, 0, 0), "rs": Vector3(1.2, 0, -0.9), "re": Vector3(1.6, 0, 0)}
			var tee := {"ls": Vector3(0.1, 0, -1.5), "le": Vector3(0.1, 0, 0), "rs": Vector3(0.1, 0, 1.5), "re": Vector3(0.1, 0, 0),
					"torso": Vector3(0.06, 0, 0), "head": Vector3(0.1, 0, 0.15)}
			var sway := with(tee, {"pos": Vector3(0.07, -0.03, 0), "torso": Vector3(0.06, 0, -0.12), "head": Vector3(0.05, 0, -0.2),
					"ls": Vector3(0.1, 0, -1.35), "rs": Vector3(0.1, 0, 1.65)})
			# Hips thrust forward (the legs angle back to keep the feet put).
			var lean := {"pos": Vector3(0.04, -0.08, -0.14), "lh": Vector3(-0.16, 0, 0), "rh": Vector3(-0.16, 0, 0),
					"torso": Vector3(0.58, 0.1, 0.06), "head": Vector3(-0.42, 0.15, 0.12),
					"ls": Vector3(0.45, 0, -0.4), "le": Vector3(0.5, 0, 0), "rs": Vector3(0.3, 0, 0.5), "re": Vector3(0.7, 0, 0)}
			var wiggle := with(lean, {"pos": Vector3(-0.03, -0.1, -0.14), "torso": Vector3(0.58, -0.05, -0.04),
					"ls": Vector3(0.3, 0, -0.5), "le": Vector3(0.75, 0, 0), "rs": Vector3(0.45, 0, 0.4), "re": Vector3(0.45, 0, 0)})
			var claws := {"pos": Vector3(0.03, -0.06, -0.08), "lh": Vector3(-0.1, 0, 0), "rh": Vector3(-0.1, 0, 0),
					"torso": Vector3(0.3, -0.15, 0.08), "head": Vector3(-0.1, 0.12, 0.12),
					"ls": Vector3(0.3, 0, -0.5), "le": Vector3(2.4, 0, 0), "rs": Vector3(0.3, 0, 0.5), "re": Vector3(2.4, 0, 0)}
			var claws_b := with(claws, {"pos": Vector3(-0.03, -0.08, -0.08), "torso": Vector3(0.3, 0.12, -0.06), "head": Vector3(-0.1, -0.1, -0.1)})
			var yeah := {"pos": Vector3(0, 0.02, -0.05), "lh": Vector3(-0.06, 0, 0), "rh": Vector3(-0.06, 0, 0),
					"torso": Vector3(0.35, 0, 0), "head": Vector3(0.45, 0, 0),
					"ls": Vector3(2.85, 0, -0.35), "le": Vector3(0.5, 0, 0), "rs": Vector3(2.85, 0, 0.35), "re": Vector3(0.5, 0, 0)}
			var yeah_down := with(yeah, {"pos": Vector3(0, -0.08, -0.05), "le": Vector3(1.1, 0, 0), "re": Vector3(1.1, 0, 0), "head": Vector3(0.3, 0, 0)})
			var flex := {"pos": Vector3(0, -0.08, -0.06), "lh": Vector3(-0.07, 0, 0), "rh": Vector3(-0.07, 0, 0),
					"torso": Vector3(0.12, 0, 0), "head": Vector3(0, 0, 0.12),
					"ls": Vector3(1.57, 0, -1.4), "le": Vector3(2.0, 0, 0), "rs": Vector3(1.57, 0, 1.4), "re": Vector3(2.0, 0, 0)}
			var flex_pop := with(flex, {"pos": Vector3(0.07, -0.1, -0.08), "torso": Vector3(0.12, 0, -0.1), "head": Vector3(0, 0.15, -0.12)})
			var swivel := {"pos": Vector3(0.09, -0.07, -0.06), "lh": Vector3(-0.08, 0, 0), "rh": Vector3(-0.08, 0, 0),
					"torso": Vector3(0.1, 0.15, -0.14), "head": Vector3(-0.05, -0.2, 0.15),
					"ls": Vector3(0.25, 0, -0.45), "le": Vector3(1.3, 0, 0), "rs": Vector3(0.25, 0, 0.45), "re": Vector3(1.3, 0, 0)}
			return [[0.2, wind], [0.14, tee], [0.3, sway], [0.3, mirror(sway)], [0.3, sway],
					[0.2, lean], [0.15, wiggle], [0.15, lean], [0.15, wiggle],
					[0.18, claws], [0.15, claws_b], [0.15, claws],
					[0.15, yeah], [0.14, yeah_down], [0.14, yeah], [0.14, yeah_down],
					[0.18, flex], [0.2, flex_pop], [0.2, flex],
					[0.16, swivel], [0.16, mirror(swivel)], [0.16, swivel], [0.16, mirror(swivel)]]
	return [[0.5, {}]]
