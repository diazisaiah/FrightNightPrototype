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
	match id:
		"default":
			# Arm pumps over bouncing knees, then the arm swing with a kick.
			var pump := {"pos": Vector3(0, -0.05, 0), "lh": Vector3(0.3, 0, 0), "lk": Vector3(-0.6, 0, 0),
					"rh": Vector3(0.3, 0, 0), "rk": Vector3(-0.6, 0, 0),
					"rs": Vector3(1.4, 0, -0.35), "re": Vector3(1.3, 0, 0), "ls": Vector3(-0.25, 0, -0.2), "le": Vector3(0.9, 0, 0),
					"torso": Vector3(0, -0.25, 0), "head": Vector3(0, -0.1, 0)}
			var up := {"lh": Vector3(0.1, 0, 0), "lk": Vector3(-0.2, 0, 0), "rh": Vector3(0.1, 0, 0), "rk": Vector3(-0.2, 0, 0),
					"rs": Vector3(0.5, 0, 0.1), "re": Vector3(1.7, 0, 0), "ls": Vector3(0.5, 0, -0.1), "le": Vector3(1.7, 0, 0)}
			var swing := {"pos": Vector3(0.04, -0.03, 0), "ls": Vector3(0.6, 0, -1.0), "le": Vector3(0.5, 0, 0),
					"rs": Vector3(0.9, 0, -0.6), "re": Vector3(0.8, 0, 0), "torso": Vector3(0, 0.3, 0.1),
					"rh": Vector3(0.55, 0, 0.3), "rk": Vector3(-0.4, 0, 0), "lh": Vector3(0.15, 0, 0), "lk": Vector3(-0.3, 0, 0)}
			var middle := with(up, {"pos": Vector3(0, -0.04, 0), "lh": Vector3(0.25, 0, 0), "lk": Vector3(-0.5, 0, 0),
					"rh": Vector3(0.25, 0, 0), "rk": Vector3(-0.5, 0, 0)})
			return [[0.22, pump], [0.22, up], [0.22, mirror(pump)], [0.22, up],
					[0.22, pump], [0.22, up], [0.22, mirror(pump)], [0.22, up],
					[0.2, swing], [0.2, middle], [0.2, mirror(swing)], [0.2, middle],
					[0.2, swing], [0.2, middle], [0.2, mirror(swing)], [0.2, middle]]
		"dab":
			var ready := {"pos": Vector3(0, -0.02, 0), "lk": Vector3(-0.1, 0, 0), "rk": Vector3(-0.1, 0, 0)}
			var dab := {"pos": Vector3(0, -0.04, 0), "ls": Vector3(1.35, 0, 0.6), "le": Vector3(2.3, 0, 0),
					"rs": Vector3(1.75, 0, 1.25), "re": Vector3(0.05, 0, 0),
					"torso": Vector3(-0.2, -0.3, -0.2), "head": Vector3(-0.55, -0.5, -0.2),
					"lh": Vector3(0.1, 0, -0.1), "rh": Vector3(0, 0, 0.18), "lk": Vector3(-0.2, 0, 0)}
			return [[0.3, ready], [0.12, dab], [0.65, dab], [0.28, ready],
					[0.12, mirror(dab)], [0.65, mirror(dab)], [0.3, ready]]
		"nae_nae":
			# One hand up and waving, the other loose, rocking side to side.
			var base := {"pos": Vector3(0, -0.04, 0), "rs": Vector3(3.0, 0, 0.15), "re": Vector3(0.2, 0, 0),
					"ls": Vector3(0.5, 0, -0.2), "le": Vector3(1.3, 0, 0), "torso": Vector3(0.14, 0, 0.1),
					"lh": Vector3(0.25, 0, 0), "lk": Vector3(-0.5, 0, 0), "rh": Vector3(0.25, 0, 0), "rk": Vector3(-0.5, 0, 0)}
			var rock_a := with(base, {"pos": Vector3(-0.05, -0.06, 0), "rs": Vector3(3.0, 0, 0.45),
					"torso": Vector3(0.16, 0.1, 0.18), "head": Vector3(0.1, 0.1, 0.15), "le": Vector3(1.0, 0, 0)})
			var rock_b := with(base, {"pos": Vector3(0.05, -0.02, 0), "rs": Vector3(3.0, 0, -0.2),
					"torso": Vector3(0.12, -0.1, -0.05), "head": Vector3(0.1, -0.1, -0.1), "le": Vector3(1.5, 0, 0)})
			return [[0.32, rock_a], [0.32, rock_b]]
		"floss":
			# Straight arms swing side to side, swapping front and back; hips go the other way.
			var left_front := {"pos": Vector3(0.07, 0, 0), "ls": Vector3(0.35, 0, -0.6), "le": Vector3(0.05, 0, 0),
					"rs": Vector3(-0.35, 0, -0.6), "re": Vector3(0.05, 0, 0),
					"torso": Vector3(0, 0, 0.12), "lh": Vector3(0, 0, -0.12), "rh": Vector3(0, 0, -0.12)}
			var right_back := {"pos": Vector3(-0.07, 0, 0), "ls": Vector3(-0.35, 0, 0.6), "le": Vector3(0.05, 0, 0),
					"rs": Vector3(0.35, 0, 0.6), "re": Vector3(0.05, 0, 0),
					"torso": Vector3(0, 0, -0.12), "lh": Vector3(0, 0, 0.12), "rh": Vector3(0, 0, 0.12)}
			var left_back := with(left_front, {"ls": Vector3(-0.35, 0, -0.6), "rs": Vector3(0.35, 0, -0.6)})
			var right_front := with(right_back, {"ls": Vector3(0.35, 0, 0.6), "rs": Vector3(-0.35, 0, 0.6)})
			return [[0.17, left_front], [0.17, right_back], [0.17, left_back], [0.17, right_front]]
		"take_the_l":
			# An L on the forehead, hopping knee to knee.
			var l_hand := {"ls": Vector3(2.25, 0, 0.4), "le": Vector3(1.25, 0, 0), "head": Vector3(0, 0.15, 0), "torso": Vector3(0, 0, 0.05)}
			var kick_left := with(l_hand, {"pos": Vector3(0, 0.05, 0), "lh": Vector3(0.9, 0, -0.5), "lk": Vector3(-1.4, 0, 0),
					"rs": Vector3(-0.25, 0, 0.3), "re": Vector3(0.4, 0, 0)})
			var land := with(l_hand, {"pos": Vector3(0, -0.04, 0), "lh": Vector3(0.2, 0, 0), "lk": Vector3(-0.4, 0, 0),
					"rh": Vector3(0.2, 0, 0), "rk": Vector3(-0.4, 0, 0), "rs": Vector3(0.15, 0, 0.3), "re": Vector3(0.4, 0, 0)})
			var kick_right := with(l_hand, {"pos": Vector3(0, 0.05, 0), "rh": Vector3(0.9, 0, 0.5), "rk": Vector3(-1.4, 0, 0),
					"rs": Vector3(0.55, 0, 0.3), "re": Vector3(0.4, 0, 0)})
			return [[0.2, kick_left], [0.2, land], [0.2, kick_right], [0.2, land]]
		"griddy":
			# Heel taps with swinging arms, then the goggles.
			var step := {"pos": Vector3(0, -0.05, 0), "lh": Vector3(0.6, 0, 0), "lk": Vector3(-0.15, 0, 0),
					"rh": Vector3(-0.2, 0, 0), "rk": Vector3(-0.35, 0, 0),
					"ls": Vector3(-0.5, 0, -0.2), "le": Vector3(1.4, 0, 0), "rs": Vector3(0.9, 0, 0.2), "re": Vector3(1.4, 0, 0),
					"torso": Vector3(-0.15, 0.15, 0)}
			var goggles := {"pos": Vector3(0, -0.06, 0), "ls": Vector3(2.45, 0, 0.5), "le": Vector3(2.5, 0, 0),
					"rs": Vector3(2.45, 0, -0.5), "re": Vector3(2.5, 0, 0), "torso": Vector3(0.08, 0, 0),
					"lh": Vector3(0.25, 0, 0), "lk": Vector3(-0.5, 0, 0), "rh": Vector3(0.25, 0, 0), "rk": Vector3(-0.5, 0, 0)}
			return [[0.2, step], [0.2, mirror(step)], [0.2, step], [0.2, mirror(step)],
					[0.2, step], [0.2, mirror(step)], [0.2, step], [0.2, mirror(step)],
					[0.16, goggles], [0.24, with(goggles, {"pos": Vector3(0, -0.1, 0), "head": Vector3(0, 0, 0.18)})],
					[0.24, with(goggles, {"pos": Vector3(0, -0.03, 0), "head": Vector3(0, 0, -0.18)})],
					[0.24, with(goggles, {"pos": Vector3(0, -0.1, 0), "head": Vector3(0, 0, 0.18)})]]
		"horse_ride":
			# Wide stance, wrists crossed on the reins, hopping; then the lasso.
			var reins := {"pos": Vector3(0, -0.09, 0), "lh": Vector3(0.2, 0, -0.28), "lk": Vector3(-0.5, 0, 0),
					"rh": Vector3(0.2, 0, 0.28), "rk": Vector3(-0.5, 0, 0),
					"ls": Vector3(1.0, 0, 0.38), "le": Vector3(0.5, 0, 0), "rs": Vector3(1.0, 0, -0.38), "re": Vector3(0.5, 0, 0),
					"torso": Vector3(-0.1, 0, 0)}
			var hop_left := with(reins, {"pos": Vector3(0, -0.03, 0), "lh": Vector3(0.65, 0, -0.28), "lk": Vector3(-1.0, 0, 0)})
			var hop_right := mirror(hop_left)
			var keys := [[0.2, reins], [0.2, hop_left], [0.2, reins], [0.2, hop_right],
					[0.2, reins], [0.2, hop_left], [0.2, reins], [0.2, hop_right]]
			var lasso := [Vector3(2.9, 0, 0.45), Vector3(2.9, 0.4, 0.0), Vector3(2.9, 0, -0.3), Vector3(2.9, -0.4, 0.0)]
			for i in 8:
				var base: Dictionary = [reins, hop_left, reins, hop_right][i % 4]
				keys.append([0.2, with(base, {"rs": lasso[i % 4], "re": Vector3(0.35, 0, 0), "head": Vector3(0.15, 0, 0)})])
			return keys
		"running_man":
			var knee_up := {"pos": Vector3(0, 0.02, 0), "lh": Vector3(1.2, 0, 0), "lk": Vector3(-1.4, 0, 0),
					"rh": Vector3(-0.15, 0, 0), "rk": Vector3(-0.2, 0, 0),
					"ls": Vector3(-0.5, 0, -0.1), "le": Vector3(1.5, 0, 0), "rs": Vector3(0.75, 0, 0.1), "re": Vector3(1.5, 0, 0),
					"torso": Vector3(-0.1, 0, 0)}
			var drop := {"pos": Vector3(0, -0.07, 0), "lh": Vector3(0.3, 0, 0), "lk": Vector3(-0.6, 0, 0),
					"rh": Vector3(0.3, 0, 0), "rk": Vector3(-0.6, 0, 0),
					"ls": Vector3(0.15, 0, -0.1), "le": Vector3(1.5, 0, 0), "rs": Vector3(0.15, 0, 0.1), "re": Vector3(1.5, 0, 0),
					"torso": Vector3(-0.1, 0, 0)}
			return [[0.2, knee_up], [0.2, drop], [0.2, mirror(knee_up)], [0.2, drop]]
		"bros_shuffle":
			# Fists bouncing at the chest, knock-kneed sway, one fist pumping up.
			var pump := {"pos": Vector3(-0.04, -0.06, 0), "rs": Vector3(2.6, 0, 0.25), "re": Vector3(0.7, 0, 0),
					"ls": Vector3(0.25, 0, -0.15), "le": Vector3(1.6, 0, 0), "torso": Vector3(0, 0.1, -0.12),
					"head": Vector3(0, 0, 0.1), "lh": Vector3(0.2, 0, 0.14), "lk": Vector3(-0.45, 0, 0),
					"rh": Vector3(0.15, 0, -0.06), "rk": Vector3(-0.3, 0, 0)}
			var chest := {"pos": Vector3(0, -0.01, 0), "ls": Vector3(0.65, 0, -0.1), "le": Vector3(1.9, 0, 0),
					"rs": Vector3(0.65, 0, 0.1), "re": Vector3(1.9, 0, 0), "lh": Vector3(0.05, 0, 0.06), "rh": Vector3(0.05, 0, -0.06),
					"lk": Vector3(-0.1, 0, 0), "rk": Vector3(-0.1, 0, 0)}
			return [[0.2, pump], [0.2, chest], [0.2, mirror(pump)], [0.2, chest]]
	return [[0.5, {}]]
