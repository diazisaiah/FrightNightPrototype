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
const ORDER := ["default", "dab", "nae_nae", "floss", "take_the_l", "griddy", "horse_ride", "running_man", "bros_shuffle"]
const NAMES := {
	"default": "The Default", "dab": "Dab", "nae_nae": "Nae Nae", "floss": "Floss",
	"take_the_l": "Take the L", "griddy": "Griddy", "horse_ride": "Horse Ride",
	"running_man": "Running Man", "bros_shuffle": "Bros. Shuffle",
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
	return [[0.5, {}]]
