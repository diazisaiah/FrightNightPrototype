class_name Threat
extends RefCounted
## What the HUD's projectile warning (ProjectileWarn) asks of anything that
## can hit you from range (2026-11-06). Arrows, fireballs and the Bone
## Sniper's draw are in the "threats" group and answer
## threat(target: Vector3) -> {from: Vector3, time: float, color: Color}: where
## it is now, how long until it reaches the target, and its color, or {} when
## it isn't coming for them (past them, flying wide, stuck in a wall).

## A slip works when it's pressed within its window before the hit
## (Player.DEFENSES slip: 0.3 s). The warning turns red this far out, so
## there's a beat to read it and press.
const SLIP_NOW := 0.5
## Further out than this and a shot isn't shown yet.
const SHOW_WITHIN := 1.8
## A shot passing wider than this misses (the player's hit radius, roughly).
const HIT_RADIUS := 1.1


## For anything flying straight: {} if it isn't coming at target.
static func of_projectile(position: Vector3, velocity: Vector3, target: Vector3, color: Color) -> Dictionary:
	var speed := velocity.length()
	if speed < 0.5:
		return {}
	var direction := velocity / speed
	var to := target - position
	var along := to.dot(direction)
	if along <= 0.0:
		return {}
	var wide := (to - direction * along).length()
	if wide > HIT_RADIUS:
		return {}
	return {"from": position, "time": along / speed, "color": color}
