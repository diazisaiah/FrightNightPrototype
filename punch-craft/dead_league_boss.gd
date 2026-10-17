class_name DeadLeagueBoss
extends Boss
## One code-built undead prizefighter with five profiles, each modeled after
## the Dead League key art: the Bellman's bell and molten ribs, the Headless's
## floating flaming skull, Sister Southpaw's veil and gold chain, the Plague
## Doctor's beak and vials, the Coffin King's crown and gold chains. Every one
## glows at the edges in its accent color (a rim overlay), trails wisps of it,
## and carries its own light.

const ROUND_HP := [1.0, 1.16, 1.34]
const ROUND_DAMAGE := [1.0, 1.08, 1.17]
## Body scale per profile: the Bellman and the Coffin King are the big ones.
const BODY_SCALE := [1.45, 1.25, 1.2, 1.22, 1.38]
const RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 rim_color : source_color = vec4(1.0);
uniform float rim_power = 4.0;
uniform float rim_strength = 0.45;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = rim_color.rgb * rim * rim_strength;
}
"""

## The high guard: upper arm angle, inward turn, elbow bend. The upper arm
## reaches forward and the forearm bends up, so the fists sit out in front of
## the face rather than tucked in at the shoulders.
const GUARD_SHOULDER := -0.25
const GUARD_SPREAD := 0.3
const GUARD_ELBOW := 1.45

var profile_index := 0
var round_number := 1
## The Headless's skull floats free above its shoulders.
var _float_head: Node3D
var _float_base := 0.0
var _look_time := 0.0


## Must be called before adding the boss to the scene tree.
func configure(index: int, bout_round: int) -> void:
	profile_index = clampi(index, 0, DeadLeagueRules.BOSS_COUNT - 1)
	round_number = clampi(bout_round, 1, DeadLeagueRules.ROUND_COUNT)
	var profile := DeadLeagueRules.boss(profile_index)
	display_name = profile.name
	# Tuned for a fresh fighter (2 damage, 50 knuckle HP), then scaled to the
	# par build for this contender's tier (Progression): with about 85% of
	# the unsealed upgrades and decent tier gear, it's a fair fight.
	var par := Progression.par(profile_index + 1)
	max_hp = profile.hp * ROUND_HP[round_number - 1] * par.damage / Progression.BASE_DAMAGE
	attack_damage = profile.damage * ROUND_DAMAGE[round_number - 1] * par.ehp / Progression.BASE_KNUCKLES
	move_speed = 2.5 * profile.speed * (1.0 + 0.04 * (round_number - 1))
	windup_scale = profile.windup * (1.0 - 0.045 * (round_number - 1))
	coin_reward = 0
	xp_reward = 0
	base_armor = 0.0
	armor_value = 0.0
	armor_bonus_hp = 0.0
	is_boss = true
	hit_color = profile.accent


func _ready() -> void:
	super()
	# After the parts are voxelized (also deferred, queued first).
	_finish_look.call_deferred()


func _pick_combo() -> Array:
	var pools := [
		[["jab", "cross"], ["cross", "left_hook"], ["jab", "cross", "slam"], ["left_hook", "right_hook"], ["slam"]],
		[["jab", "cross", "jab"], ["cross", "left_hook"], ["jab", "right_hook", "cross"], ["left_hook", "cross"]],
		[["jab", "left_hook"], ["jab", "cross", "left_hook"], ["left_hook", "cross", "left_hook"], ["cross", "left_hook", "uppercut"]],
		[["jab"], ["cross"], ["jab", "uppercut"], ["cross", "left_hook", "uppercut"], ["jab", "cross", "slam"]],
		[["jab", "cross", "left_hook", "right_hook"], ["cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "slam"], ["slam", "jab", "cross"]],
	]
	var pool: Array = pools[profile_index]
	if _enraged:
		pool = pool + [["jab", "cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "left_hook", "slam"]]
	return pool.pick_random()


func _idle_time() -> float:
	var base: float = [0.95, 0.7, 0.62, 0.85, 0.58][profile_index]
	return randf_range(base * 0.75, base * 1.2) * (0.75 if _enraged else 1.0)


func _enrage() -> void:
	# Dead League is always a fair 1v1: the champion speeds up, but never summons.
	_enraged = true
	windup_scale *= 0.88
	move_speed *= 1.12
	DamagePopup.spawn(get_parent(), "FINAL BELL", DeadLeagueRules.boss(profile_index).accent, 58,
			global_position + Vector3(0, 3.2, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.4, 2.0, 0.7)


func _build_armor() -> void:
	# Arena profiles configure without the normal random armored variant.
	pass


## Guard with the fists held up at head height and out in front, like the
## key art, instead of tucked against the chin. Punches use the normal boxer poses.
func _arm_pose(arm: String) -> Array:
	if not (_state in [State.WINDUP, State.STRIKE]) or not _uses_arm(arm):
		var side := -1.0 if arm == "left" else 1.0
		return [Vector3(GUARD_SHOULDER, GUARD_SPREAD * side, 0), 0.0, Vector3(GUARD_ELBOW, 0, 0)]
	return super(arm)


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	_look_time += delta
	if _float_head:
		_float_head.position.y = _float_base + sin(_look_time * 2.2) * 0.035
		_float_head.rotation.z = sin(_look_time * 1.3) * 0.08
	# Specials: crouch into a leap, lean into a charge, wobble when dazed.
	var lean := 0.0
	match _step:
		"crouch":
			lean = 0.25
		"air", "cast":
			lean = -0.15
		"aim":
			lean = 0.3
		"dash":
			lean = 0.45
		"dazed":
			lean = -0.12
			_body.rotation.z = sin(_look_time * 9.0) * 0.14
	_body.rotation.x = lerpf(_body.rotation.x, lean, minf(1.0, 12.0 * delta))


# --- The look ------------------------------------------------------------------

func _build_body() -> void:
	_body.scale = Vector3.ONE * BODY_SCALE[profile_index]
	match profile_index:
		0:
			_build_bellman()
		1:
			_build_headless()
		2:
			_build_southpaw()
		3:
			_build_plague_doctor()
		4:
			_build_coffin_king()


## The Bellman: a hulking stone brute. Molten ribs glow through a cracked
## chest, a gold bell hangs on chains across it, and his forearms are wrapped
## red and white up to huge red fists.
func _build_bellman() -> void:
	var stone := _material(Color(0.47, 0.45, 0.44))
	var stone_dark := _material(Color(0.3, 0.29, 0.29))
	var cloth := _material(Color(0.42, 0.08, 0.07))
	var gold := _material(Color(0.86, 0.62, 0.22), 0.7)
	var iron := _material(Color(0.16, 0.15, 0.16), 0.6)
	var white := _material(Color(0.86, 0.82, 0.76))
	var red := _material(Color(0.72, 0.1, 0.08))
	var molten := _glow_material(Color(1.0, 0.45, 0.08))
	molten.emission_energy_multiplier = 1.8
	var eyes := _glow_material(Color(1.0, 0.15, 0.08))
	var dark := _material(Color(0.06, 0.04, 0.04))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.26, 0.5, 0.28)), stone_dark, Vector3(0.17 * side, 0.25, 0))
		_part(_body, _box(Vector3(0.24, 0.42, 0.26)), stone, Vector3(0.17 * side, 0.7, 0))
	_part(_body, _box(Vector3(0.78, 0.12, 0.46)), iron, Vector3(0, 0.96, 0))
	_tatters(_body, 0.94, 0.4, 0.26, [cloth, stone_dark, cloth, red], 16, Vector2(0.3, 0.55))
	# Chest: a dark cracked plate with molten ribs glowing through it.
	_part(_body, _box(Vector3(0.86, 0.68, 0.48)), stone, Vector3(0, 1.32, 0))
	_part(_body, _box(Vector3(0.5, 0.46, 0.04)), dark, Vector3(0, 1.3, -0.245))
	for i in 4:
		_part(_body, _box(Vector3(0.44 - i * 0.04, 0.045, 0.03)), molten, Vector3(0, 1.16 + i * 0.1, -0.265))
	_part(_body, _box(Vector3(0.05, 0.4, 0.03)), molten, Vector3(0, 1.3, -0.266))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.3, 0.2, 0.34)), stone_dark, Vector3(0.42 * side, 1.62, 0))
	# The bell, hung on gold chains from both shoulders.
	# A big bell, hung low in front of the gut so it reads against the ribs.
	_part(_body, _box(Vector3(0.1, 0.06, 0.1)), iron, Vector3(0, 1.14, -0.4))
	_part(_body, _cylinder_tapered(0.11, 0.22, 0.3), gold, Vector3(0, 0.97, -0.42))
	_part(_body, _cylinder_tapered(0.235, 0.235, 0.05), gold, Vector3(0, 0.81, -0.42))
	_part(_body, _box(Vector3(0.07, 0.09, 0.07)), iron, Vector3(0, 0.75, -0.42))
	for side in [-1.0, 1.0]:
		_chain(_body, Vector3(0.36 * side, 1.66, -0.12), Vector3(0.04 * side, 1.16, -0.4), 8, gold)
	_chain(_body, Vector3(-0.42, 1.7, 0.1), Vector3(0.42, 1.7, 0.1), 9, gold)
	# A blocky stone skull with a heavy brow and burning red eyes.
	_skull(_body, Vector3(0, 1.86, -0.06), 0.38, stone, dark, eyes)
	_build_arms(stone, Color(0.75, 0.08, 0.06), 1.5, 0.42)
	_bulk_arms(stone, stone_dark, white, red, 1.6, 1.7, 3)


## The Headless: no head on the neck, just ghost-fire. The skull floats above
## it in blue flame. Bandaged bone-white arms and a ragged navy skirt.
func _build_headless() -> void:
	var bone := _material(Color(0.84, 0.82, 0.76))
	var bandage := _material(Color(0.78, 0.76, 0.72))
	var navy := _material(Color(0.1, 0.14, 0.3))
	var navy_dark := _material(Color(0.05, 0.07, 0.15))
	var sash := _material(Color(0.86, 0.85, 0.82))
	var dark := _material(Color(0.03, 0.04, 0.07))
	var flame := _glow_material(Color(0.3, 0.75, 1.0))
	var eyes := _glow_material(Color(0.5, 0.95, 1.0))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.18, 0.9, 0.2)), navy_dark, Vector3(0.13 * side, 0.45, 0))
	_tatters(_body, 1.02, 0.34, 0.24, [navy, navy_dark, navy], 18, Vector2(0.4, 0.75))
	_part(_body, _box(Vector3(0.62, 0.1, 0.4)), sash, Vector3(0, 1.0, 0))
	_part(_body, _box(Vector3(0.1, 0.32, 0.03)), sash, Vector3(0.16, 0.84, -0.2))
	# A ragged dark torso with bone ribs showing.
	_part(_body, _box(Vector3(0.6, 0.6, 0.36)), navy_dark, Vector3(0, 1.3, 0))
	for i in 4:
		_part(_body, _box(Vector3(0.42 - i * 0.03, 0.045, 0.03)), bone, Vector3(0, 1.16 + i * 0.1, -0.185))
	_part(_body, _box(Vector3(0.06, 0.42, 0.03)), bone, Vector3(0, 1.3, -0.19))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.22, 0.14, 0.28)), bandage, Vector3(0.32 * side, 1.58, 0))
		# Blue fire licking off the shoulders.
		_flame_stack(_body, Vector3(0.34 * side, 1.7, 0.02), 0.11, flame)
	# The neck stump burns; the skull floats above it.
	_part(_body, _box(Vector3(0.18, 0.08, 0.18)), dark, Vector3(0, 1.62, 0))
	_flame_stack(_body, Vector3(0, 1.68, 0), 0.14, flame)
	_float_head = _skull(_body, Vector3(0, 2.02, -0.02), 0.3, bone, dark, eyes)
	_flame_stack(_float_head, Vector3(0, 0.18, 0.05), 0.12, flame)
	_build_arms(bandage, Color(0.12, 0.16, 0.32), 1.46, 0.34)
	_bulk_arms(bandage, bandage, bandage, _material(Color(0.62, 0.6, 0.57)), 1.2, 1.35, 4)


## Sister Southpaw: a nun in a torn violet habit, white band across the brow
## and long dark hair under the veil, a gold chain around the neck.
func _build_southpaw() -> void:
	var habit := _material(Color(0.1, 0.06, 0.14))
	var violet := _material(Color(0.3, 0.12, 0.45))
	var white := _material(Color(0.9, 0.88, 0.86))
	var skin := _material(Color(0.82, 0.74, 0.72))
	var hair := _material(Color(0.12, 0.07, 0.16))
	var gold := _material(Color(0.88, 0.66, 0.24), 0.7)
	var dark := _material(Color(0.05, 0.03, 0.06))
	var eyes := _glow_material(Color(0.8, 0.45, 1.0))

	# A long habit to the floor, widening toward a torn violet hem.
	_part(_body, _box(Vector3(0.5, 0.5, 0.34)), habit, Vector3(0, 0.72, 0))
	_part(_body, _box(Vector3(0.6, 0.34, 0.42)), habit, Vector3(0, 0.34, 0))
	_tatters(_body, 0.45, 0.33, 0.24, [violet, habit, violet, violet], 20, Vector2(0.28, 0.45))
	_part(_body, _box(Vector3(0.56, 0.6, 0.34)), habit, Vector3(0, 1.28, 0))
	_part(_body, _box(Vector3(0.42, 0.08, 0.36)), white, Vector3(0, 1.56, 0))
	# A gold chain around the neck.
	_chain(_body, Vector3(-0.14, 1.54, -0.17), Vector3(0, 1.3, -0.19), 4, gold)
	_chain(_body, Vector3(0.14, 1.54, -0.17), Vector3(0, 1.3, -0.19), 4, gold)
	# Face, eyes, the white band, the veil and hair.
	_part(_body, _box(Vector3(0.24, 0.28, 0.24)), skin, Vector3(0, 1.74, -0.01))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.07, 0.03, 0.02)), eyes, Vector3(0.06 * side, 1.75, -0.135))
	_part(_body, _box(Vector3(0.08, 0.02, 0.02)), dark, Vector3(0, 1.65, -0.13))
	_part(_body, _box(Vector3(0.3, 0.075, 0.28)), white, Vector3(0, 1.86, -0.02))
	_part(_body, _box(Vector3(0.36, 0.12, 0.34)), habit, Vector3(0, 1.94, 0.01))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.06, 0.4, 0.3)), habit, Vector3(0.16 * side, 1.74, 0.03))
		_part(_body, _box(Vector3(0.05, 0.42, 0.06)), hair, Vector3(0.11 * side, 1.56, -0.1))
	_part(_body, _box(Vector3(0.38, 0.62, 0.06)), habit, Vector3(0, 1.6, 0.19))
	_part(_body, _box(Vector3(0.3, 0.5, 0.05)), hair, Vector3(0, 1.55, 0.15))
	_build_arms(habit, Color(0.4, 0.16, 0.55), 1.46, 0.32)
	_bulk_arms(habit, habit, white, violet, 1.1, 1.2, 2)


## The Plague Doctor: a hooded, tattered coat, a long bone beak with round
## green lenses, wrapped forearms, and a belt of glowing potions.
func _build_plague_doctor() -> void:
	var coat := _material(Color(0.24, 0.24, 0.18))
	var coat_dark := _material(Color(0.13, 0.14, 0.11))
	var beak := _material(Color(0.86, 0.8, 0.64))
	var leather := _material(Color(0.32, 0.2, 0.11))
	var wrap := _material(Color(0.8, 0.78, 0.7))
	var brass := _material(Color(0.62, 0.5, 0.25), 0.7)
	var dark := _material(Color(0.03, 0.04, 0.03))
	var potion := _glow_material(Color(0.35, 1.0, 0.4))
	var lenses := _glow_material(Color(0.45, 1.0, 0.45))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.18, 0.9, 0.2)), coat_dark, Vector3(0.13 * side, 0.45, 0))
	_tatters(_body, 1.02, 0.34, 0.26, [coat, coat_dark, coat], 18, Vector2(0.38, 0.62))
	_part(_body, _box(Vector3(0.6, 0.62, 0.38)), coat, Vector3(0, 1.3, 0))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.12, 0.5, 0.03)), coat_dark, Vector3(0.13 * side, 1.32, -0.2), Vector3(0, 0, 0.12 * side))
	# The belt, its buckle and a row of glowing vials.
	_part(_body, _box(Vector3(0.64, 0.09, 0.42)), leather, Vector3(0, 1.02, 0))
	_part(_body, _box(Vector3(0.08, 0.07, 0.03)), brass, Vector3(0, 1.02, -0.22))
	for i in 4:
		var x := -0.24 + i * 0.13 + (0.06 if i >= 2 else 0.0)
		_part(_body, _box(Vector3(0.05, 0.11, 0.05)), potion, Vector3(x, 0.94, -0.22))
		_part(_body, _box(Vector3(0.03, 0.03, 0.03)), leather, Vector3(x, 1.01, -0.22))
	_part(_body, _box(Vector3(0.16, 0.16, 0.08)), leather, Vector3(0.24, 0.86, -0.1))
	# The mantle over the shoulders.
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.26, 0.12, 0.36)), coat_dark, Vector3(0.24 * side, 1.6, 0))
	# Hood, mask, lenses and the long beak.
	_part(_body, _box(Vector3(0.36, 0.38, 0.34)), coat_dark, Vector3(0, 1.78, 0.03))
	_part(_body, _box(Vector3(0.26, 0.26, 0.06)), beak, Vector3(0, 1.76, -0.13))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.09, 0.09, 0.03)), dark, Vector3(0.07 * side, 1.79, -0.165))
		_part(_body, _box(Vector3(0.06, 0.06, 0.03)), lenses, Vector3(0.07 * side, 1.79, -0.18))
	_part(_body, _box(Vector3(0.16, 0.14, 0.24)), beak, Vector3(0, 1.69, -0.27), Vector3(0.3, 0, 0))
	_part(_body, _box(Vector3(0.11, 0.1, 0.22)), beak, Vector3(0, 1.6, -0.45), Vector3(0.45, 0, 0))
	_part(_body, _box(Vector3(0.07, 0.07, 0.12)), beak, Vector3(0, 1.52, -0.58), Vector3(0.65, 0, 0))
	_build_arms(coat, Color(0.1, 0.12, 0.08), 1.46, 0.33)
	_bulk_arms(coat, coat_dark, wrap, _material(Color(0.6, 0.58, 0.5)), 1.15, 1.25, 3)


## The Coffin King: a crowned skull, a red and white robe and cape, gold
## chains, a gold skull buckle and gold gauntlets.
func _build_coffin_king() -> void:
	var bone := _material(Color(0.84, 0.8, 0.7))
	var red := _material(Color(0.55, 0.06, 0.07))
	var red_dark := _material(Color(0.32, 0.03, 0.05))
	var white := _material(Color(0.88, 0.85, 0.8))
	var gold := _material(Color(0.95, 0.7, 0.25), 0.8)
	var dark := _material(Color(0.04, 0.02, 0.02))
	var jewels := _glow_material(Color(1.0, 0.12, 0.1))
	var eyes := _glow_material(Color(1.0, 0.2, 0.1))

	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.2, 0.9, 0.22)), red_dark, Vector3(0.14 * side, 0.45, 0))
	_tatters(_body, 1.0, 0.38, 0.26, [red, red_dark, white, red], 20, Vector2(0.45, 0.8))
	# Robe, white trim down the front, and the cape behind.
	_part(_body, _box(Vector3(0.68, 0.66, 0.4)), red, Vector3(0, 1.3, 0))
	_part(_body, _box(Vector3(0.12, 0.66, 0.03)), white, Vector3(0, 1.3, -0.21))
	_part(_body, _box(Vector3(0.86, 1.4, 0.06)), red_dark, Vector3(0, 1.0, 0.25))
	_part(_body, _box(Vector3(0.9, 0.08, 0.08)), gold, Vector3(0, 1.66, 0.24))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.3, 0.16, 0.36)), white, Vector3(0.36 * side, 1.62, 0))
	# The gold skull buckle.
	_part(_body, _box(Vector3(0.7, 0.09, 0.42)), gold, Vector3(0, 1.0, 0))
	_part(_body, _box(Vector3(0.16, 0.14, 0.04)), gold, Vector3(0, 1.0, -0.23))
	for side in [-1.0, 1.0]:
		_part(_body, _box(Vector3(0.035, 0.035, 0.02)), dark, Vector3(0.035 * side, 1.02, -0.252))
	# Chains draped across the chest.
	_chain(_body, Vector3(-0.3, 1.6, -0.2), Vector3(0.0, 1.3, -0.22), 6, gold)
	_chain(_body, Vector3(0.3, 1.6, -0.2), Vector3(0.0, 1.3, -0.22), 6, gold)
	_chain(_body, Vector3(-0.32, 1.5, -0.21), Vector3(0.32, 1.5, -0.21), 9, gold)
	# The crowned skull.
	var head := _skull(_body, Vector3(0, 1.82, -0.02), 0.32, bone, dark, eyes)
	var crown_y := 0.2
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.36, 0.08, 0.04)), gold, Vector3(0, crown_y, 0.165 * side))
		_part(head, _box(Vector3(0.04, 0.08, 0.36)), gold, Vector3(0.165 * side, crown_y, 0))
	for i in 5:
		var x := -0.14 + i * 0.07
		var tall := 0.14 if i == 2 else 0.1
		_part(head, _box(Vector3(0.045, tall, 0.045)), gold, Vector3(x, crown_y + 0.04 + tall / 2.0, -0.165))
		_part(head, _box(Vector3(0.03, 0.03, 0.02)), jewels, Vector3(x, crown_y, -0.19))
	_build_arms(red, Color(0.92, 0.66, 0.22), 1.5, 0.38)
	_bulk_arms(red, white, white, red, 1.4, 1.6, 3)


# --- Building blocks ---------------------------------------------------------------

## A blocky skull: cranium, brow, dark sockets with glowing eyes, nose, a jaw
## with teeth. Returns its node (so a crown can sit on it).
func _skull(parent: Node3D, center: Vector3, size: float, bone: Material, dark: Material, eye: Material) -> Node3D:
	var head := Node3D.new()
	head.position = center
	parent.add_child(head)
	_part(head, _box(Vector3(1.0, 0.8, 0.92) * size), bone, Vector3(0, 0.08 * size, 0))
	_part(head, _box(Vector3(1.06, 0.14, 0.2) * size), bone, Vector3(0, 0.16 * size, -0.4 * size))
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.28, 0.2, 0.06) * size), dark, Vector3(0.24 * side * size, 0.0, -0.45 * size))
		_part(head, _box(Vector3(0.14, 0.09, 0.05) * size), eye, Vector3(0.24 * side * size, 0.0, -0.48 * size))
	_part(head, _box(Vector3(0.1, 0.12, 0.05) * size), dark, Vector3(0, -0.16 * size, -0.46 * size))
	_part(head, _box(Vector3(0.84, 0.26, 0.8) * size), bone, Vector3(0, -0.38 * size, -0.05 * size))
	_part(head, _box(Vector3(0.66, 0.035, 0.05) * size), dark, Vector3(0, -0.3 * size, -0.46 * size))
	for x in [-0.2, 0.0, 0.2]:
		_part(head, _box(Vector3(0.03, 0.16, 0.05) * size), dark, Vector3(x * size, -0.36 * size, -0.46 * size))
	return head


## Gold (or iron) links from a to b, every other link turned a quarter.
func _chain(parent: Node3D, a: Vector3, b: Vector3, links: int, material: Material) -> void:
	var along := (b - a).normalized()
	var length := a.distance_to(b)
	var basis := Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.95 else Vector3.FORWARD)
	for i in links:
		var link := _part(parent, _box(Vector3(0.05, 0.03, length / links * 1.15)), material, a.lerp(b, (i + 0.5) / links))
		link.basis = basis * Basis(Vector3.FORWARD, PI / 2.0 if i % 2 == 1 else 0.0)


## A ragged skirt or hem: strips of cloth hanging around the hips.
func _tatters(parent: Node3D, top: float, radius_x: float, radius_z: float, materials: Array, count: int, lengths: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404 + profile_index * 17
	for i in count:
		var angle := TAU * i / count
		var length := rng.randf_range(lengths.x, lengths.y)
		var width := TAU * maxf(radius_x, radius_z) / count * 1.15
		var at := Vector3(cos(angle) * radius_x, top - length / 2.0, sin(angle) * radius_z)
		_part(parent, _box(Vector3(width, length, 0.04)), materials[i % materials.size()], at, Vector3(rng.randf_range(-0.08, 0.08), -angle + PI / 2.0, 0))


## Ghost-fire: a few glowing blocks stacked and staggered upward.
func _flame_stack(parent: Node3D, base: Vector3, size: float, material: Material) -> void:
	for i in 4:
		var s := size * (1.0 - i * 0.2)
		var jitter := Vector3((i % 2) * 0.3 - 0.15, 0, ((i + 1) % 2) * 0.2 - 0.1) * size
		_part(parent, _box(Vector3(s, s * 1.3, s)), material, base + Vector3(0, i * size * 0.9, 0) + jitter, Vector3(0, i * 0.4, 0))


## The thin boxer arms made into a prizefighter's: a heavy upper arm and
## shoulder, a thick forearm banded with wraps, and a bigger fist.
func _bulk_arms(arm: Material, pad: Material, wrap: Material, stripe: Material, thickness: float, fist: float, stripes: int) -> void:
	for side in ["left", "right"]:
		var pivot: Node3D = _arms[side]
		var elbow: Node3D = _forearms[side]
		_part(pivot, _box(Vector3(0.15, 0.15, 0.26) * thickness), arm, Vector3(0, 0, -0.12))
		_part(pivot, _box(Vector3(0.22, 0.14, 0.22) * thickness), pad, Vector3(0, 0.05, 0.02))
		_part(elbow, _box(Vector3(0.16, 0.16, 0.24) * thickness), wrap, Vector3(0, 0, -0.12))
		for k in stripes:
			_part(elbow, _box(Vector3(0.17, 0.17, 0.035) * thickness), stripe, Vector3(0, 0, -0.04 - k * 0.07))
		for child in elbow.get_children():
			var part := child as MeshInstance3D
			if part and part.mesh and part.mesh.surface_get_material(0) == _gloves[side]:
				part.scale = Vector3.ONE * fist
				part.position.z -= 0.03 * fist


static func _cylinder_tapered(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := _cylinder(top, height)
	mesh.bottom_radius = bottom
	mesh.radial_segments = 10
	return mesh


## After voxelizing: the accent rim glow on every part, wisps rising off the
## body, and a light of the boss's color.
func _finish_look() -> void:
	if _float_head:
		_float_base = _float_head.position.y  # Now relative to the torso.
	var accent: Color = DeadLeagueRules.boss(profile_index).accent
	var rim := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = RIM_SHADER
	rim.shader = shader
	rim.set_shader_parameter("rim_color", accent)
	for part in _meshes:
		if is_instance_valid(part):
			part.material_overlay = rim
			part.set_meta("elite_overlay", rim)
	var wisps := CPUParticles3D.new()
	wisps.amount = 14 if Settings.use_web_profile() else 28
	wisps.lifetime = 1.6
	wisps.position = Vector3(0, 1.1, 0)
	wisps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wisps.emission_box_extents = Vector3(0.45, 0.8, 0.3) * BODY_SCALE[profile_index]
	wisps.direction = Vector3.UP
	wisps.spread = 25.0
	wisps.gravity = Vector3(0, 0.6, 0)
	wisps.initial_velocity_min = 0.2
	wisps.initial_velocity_max = 0.6
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.05
	mote.material = _glow_material(accent)
	wisps.mesh = mote
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	wisps.scale_amount_curve = shrink
	add_child(wisps)
	var light := OmniLight3D.new()
	light.light_color = accent
	# Behind and above: it edges the silhouette and pools color on the canvas,
	# while the ring's white spotlight shows the boss's real colors.
	light.light_energy = 1.3
	light.omni_range = 4.0
	light.position = Vector3(0, 2.4, 0.9)
	add_child(light)


## No gear overlays: contenders have built-in defense (tuned in configure).
func _gear_style() -> String:
	return "none"


# --- Specials -----------------------------------------------------------------------

## Each contender's signature moves, on top of the boxing:
##   leap_slam - crouches, leaps onto where you stand (a red ring marks it)
##               and lands in a shockwave: get out of the ring or jump it.
##   charge    - squares up, a lane lights the canvas toward you (it tracks
##               you, then locks), then a shoulder charge to the ropes: step
##               out of the lane or roll it. It hits the ropes dazed: punish it.
##   zones     - leaps to the far edge and calls down judgment circles, one
##               under you and more around the ring; they burst after a fuse.
##   miasma    - leaps to the edge and lobs vials around you: they burst, then
##               leave poison clouds that sting while you stand in them.
## Armored while they happen (hits land but don't stagger), except dazed.
const KITS := [["leap_slam"], ["charge"], ["zones", "charge"], ["miasma", "leap_slam"], ["leap_slam", "charge", "zones"]]
const SPECIAL_NAMES := {"leap_slam": "DEATH FROM ABOVE", "charge": "GHOST CHARGE", "zones": "JUDGMENT", "miasma": "MIASMA"}
## Seconds between specials per contender in round 1; each later round
## brings them 12% sooner, the final bell 30% sooner.
const SPECIAL_EVERY := [9.0, 8.5, 8.0, 8.0, 7.0]
const FIRST_SPECIAL := 5.0
const DANGER := Color(1.0, 0.2, 0.08)
const MIASMA_COLOR := Color(0.35, 1.0, 0.3)
const CROUCH_TIME := 0.45
const LEAP_TIME := 0.95
const SLAM_RADIUS := 1.9
const SLAM_DAMAGE := 1.6
const CHARGE_WINDUP := 1.15
## The lane stops tracking you this long before the dash.
const CHARGE_LOCK := 0.4
const CHARGE_SPEED := 13.0
const CHARGE_WIDTH := 1.3
const CHARGE_DAMAGE := 1.9
const DAZED_TIME := 1.5
const ZONE_RADIUS := 1.25
const ZONE_FUSE := 1.4
const ZONE_DAMAGE := 1.3
const MIASMA_LINGER := 3.5
## Poison cloud damage (x attack damage) every half second you stand in one.
const MIASMA_TICK := 0.22
const RECOVER_TIME := 0.9

var _special := ""
var _last_special := ""
var _step := ""
var _step_time := 0.0
var _special_cooldown := FIRST_SPECIAL
var _repeats := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _charge_dir := Vector3.FORWARD
var _charge_end := Vector3.ZERO
var _charge_hit := false
## The charge lane has stopped tracking you.
var _locked := false
var _mark: MeshInstance3D
var _mark_material: StandardMaterial3D
## Judgment circles and vials: {center, fuse, linger, tick, node, fill, edge, poison}.
var _zones: Array = []


func _think(delta: float) -> Vector3:
	if _special != "":
		return _run_special(delta)
	_special_cooldown -= delta
	# Between combos (not in the open window after one: that's yours to punish).
	if _special_cooldown <= 0.0 and _state == State.IDLE:
		var kit: Array = KITS[profile_index].filter(func(kind: String) -> bool: return kind != _last_special)
		_start_special((kit if not kit.is_empty() else KITS[profile_index]).pick_random())
		return Vector3.ZERO
	return super(delta)


func _physics_process(delta: float) -> void:
	super(delta)
	_update_zones(delta)


func take_hit(raw_damage: float, hit_point: Vector3, push: Vector3, stagger: bool, caption := "", pierce := false, crush := false) -> float:
	if _special != "" and _step != "dazed":
		stagger = false
		push = Vector3.ZERO
	return super(raw_damage, hit_point, push, stagger, caption, pierce, crush)


func _on_staggered() -> void:
	if _special != "":
		_end_special()
	super()


func _die(push: Vector3) -> void:
	_clear_specials()
	super(push)


func incoming_attack() -> String:
	if _special == "":
		return super()
	if _special == "leap_slam" and _step in ["crouch", "air"]:
		return "quake"
	if _special == "charge" and _step in ["aim", "dash"]:
		return "charge"
	return ""


func attack_eta() -> float:
	if _special == "":
		return super()
	match _step:
		"crouch":
			return CROUCH_TIME - _step_time + LEAP_TIME
		"air":
			return LEAP_TIME - _step_time
		"aim":
			return CHARGE_WINDUP - _step_time
		"dash":
			return 0.0
	return INF


func _start_special(kind: String) -> void:
	_special = kind
	_last_special = kind
	_queue.clear()
	_cue_label.visible = false
	_enter(State.IDLE, 0.0)
	_repeats = 1 if kind in ["leap_slam", "charge"] and (_enraged or round_number == 3) and randf() < 0.5 else 0
	var accent: Color = DeadLeagueRules.boss(profile_index).accent
	DamagePopup.spawn(get_parent(), SPECIAL_NAMES[kind], accent, 46, global_position + Vector3(0, 3.0, 0))
	# The marks can be under your feet, out of view: say what to do.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var how := {
			"leap_slam": "GET OUT OF THE RED  -  or jump it (%s)" % Controls.text("jump"),
			"charge": "STEP OUT OF THE LANE  -  or roll (%s)" % Controls.text("roll"),
			"zones": "STAY OUT OF THE CIRCLES",
			"miasma": "STAY OUT OF THE POISON",
		}
		hud.announce_small(how[kind], DANGER.lightened(0.3))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.4, 3.0, 0.8)
	match kind:
		"leap_slam":
			_begin_leap(_clamp_to_ring(player.global_position))
		"charge":
			_begin_charge()
		"zones", "miasma":
			_begin_leap(_far_edge())


func _end_special() -> void:
	_special = ""
	_step = ""
	_hide_mark()
	collision_mask |= 2
	_special_cooldown = SPECIAL_EVERY[profile_index] * (1.0 - 0.12 * (round_number - 1)) * (0.7 if _enraged else 1.0) * randf_range(0.85, 1.15)
	_enter(State.IDLE, _idle_time() * 0.5)


func _set_step(step: String) -> void:
	_step = step
	_step_time = 0.0


func _run_special(delta: float) -> Vector3:
	_step_time += delta
	match _step:
		"crouch":
			_turn_toward(_leap_to - global_position, delta)
			if _special == "leap_slam":
				# It follows you until it jumps.
				_leap_to = _clamp_to_ring(player.global_position)
				_show_mark_ring(_leap_to, SLAM_RADIUS, DANGER)
			if _step_time >= CROUCH_TIME:
				_leap_from = global_position
				velocity.y = _gravity * LEAP_TIME * 0.5
				collision_mask &= ~2  # Over you, not into you.
				Sfx.play_at("whoosh", global_position, 2.0, 0.6)
				_set_step("air")
			return Vector3.ZERO
		"air":
			if _special == "leap_slam":
				_pulse_mark(_step_time / LEAP_TIME)
			if (_step_time >= LEAP_TIME * 0.6 and is_on_floor()) or _step_time >= LEAP_TIME + 0.5:
				_land()
				return Vector3.ZERO
			var flat := _leap_to - _leap_from
			flat.y = 0.0
			return flat / LEAP_TIME
		"aim":
			if _step_time < CHARGE_WINDUP - CHARGE_LOCK:
				_aim_charge()
			elif not _locked:
				_locked = true
				_flash_tell(DANGER, 2.4)
			_turn_toward(_charge_dir, delta * 3.0)
			_pulse_mark(_step_time / CHARGE_WINDUP)
			if _step_time >= CHARGE_WINDUP:
				_charge_hit = false
				collision_mask &= ~2
				_hide_mark()
				Sfx.play_at("whoosh", global_position, 4.0, 0.5)
				_set_step("dash")
			return Vector3.ZERO
		"dash":
			_check_charge_hit()
			var past := (global_position - _charge_end).dot(_charge_dir) >= 0.0
			if past or _step_time > 1.6:
				collision_mask |= 2
				Sfx.play_at("block", global_position, 2.0, 0.6)
				player.shake(0.05)
				if _repeats > 0:
					_repeats -= 1
					_begin_charge(0.75)
				else:
					DamagePopup.spawn(get_parent(), "DAZED", Color(1.0, 0.9, 0.5), 40, global_position + Vector3(0, 2.8, 0))
					_set_step("dazed")
				return Vector3.ZERO
			return _charge_dir * CHARGE_SPEED
		"cast":
			_turn_toward(player.global_position - global_position, delta)
			if _step_time >= 0.7:
				_set_step("recover")
			return Vector3.ZERO
		"dazed":
			if _step_time >= DAZED_TIME:
				_end_special()
			return Vector3.ZERO
		"recover":
			_turn_toward(player.global_position - global_position, delta)
			if _step_time >= RECOVER_TIME:
				if _repeats > 0:
					_repeats -= 1
					_begin_leap(_clamp_to_ring(player.global_position))
				else:
					_end_special()
			return Vector3.ZERO
	_end_special()
	return Vector3.ZERO


# --- Leaps ---

func _begin_leap(to: Vector3) -> void:
	_leap_to = to
	if _special == "leap_slam":
		_show_mark_ring(_leap_to, SLAM_RADIUS, DANGER)
	_set_step("crouch")


func _land() -> void:
	collision_mask |= 2
	velocity.y = 0.0
	Sfx.play_at("quake", global_position, 3.0 if _special == "leap_slam" else -2.0, 0.8)
	var dust := Color(0.35, 0.3, 0.25)
	HitFx.burst(get_parent(), global_position + Vector3.UP * 0.2, Vector3.UP, dust, 30, 5.0, false, 0.1)
	if _special == "leap_slam":
		_hide_mark()
		_shockwave(global_position, SLAM_RADIUS, DANGER)
		var flat := player.global_position - global_position
		flat.y = 0.0
		player.shake(0.12 if flat.length() < SLAM_RADIUS * 2.0 else 0.04)
		if flat.length() <= SLAM_RADIUS:
			player.receive_attack(attack_damage * SLAM_DAMAGE, global_position, "quake", self)
		_set_step("recover")
	else:
		_cast_zones()
		_set_step("cast")


## The ring edge point farthest from you (where it leaps to cast from).
func _far_edge() -> Vector3:
	var best := arena_center
	var best_distance := -1.0
	for i in 8:
		var a := i * TAU / 8.0
		var spot := arena_center + Vector3(clampf(cos(a) * 1.5, -1.0, 1.0), 0, clampf(sin(a) * 1.5, -1.0, 1.0)) * arena_limit
		var distance := spot.distance_to(player.global_position)
		if distance > best_distance:
			best_distance = distance
			best = spot
	best.y = global_position.y
	return best


func _clamp_to_ring(point: Vector3) -> Vector3:
	return Vector3(clampf(point.x, arena_center.x - arena_limit, arena_center.x + arena_limit), global_position.y,
			clampf(point.z, arena_center.z - arena_limit, arena_center.z + arena_limit))


# --- The charge ---

func _begin_charge(windup_scale_now := 1.0) -> void:
	_set_step("aim")
	_locked = false
	_step_time = CHARGE_WINDUP * (1.0 - windup_scale_now)
	_aim_charge()


## Points the lane at you, from here to the ropes.
func _aim_charge() -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.1:
		_charge_dir = to_player.normalized()
	var reach := INF
	for axis in [0, 2]:
		var d: float = _charge_dir[axis]
		if absf(d) < 0.001:
			continue
		var wall: float = arena_center[axis] + arena_limit * signf(d)
		reach = minf(reach, (wall - global_position[axis]) / d)
	reach = maxf(reach, 1.0)
	_charge_end = global_position + _charge_dir * reach
	_show_mark_lane(global_position, _charge_end, CHARGE_WIDTH, DANGER)


func _check_charge_hit() -> void:
	if _charge_hit:
		return
	var flat := player.global_position - global_position
	flat.y = 0.0
	if flat.length() < 0.6 + CHARGE_WIDTH * 0.5:
		_charge_hit = true
		var result := player.receive_attack(attack_damage * CHARGE_DAMAGE, global_position, "charge", self)
		if result == "hit":
			player.shake(0.15)


# --- Judgment circles and miasma ---

func _cast_zones() -> void:
	_flash_tell(DeadLeagueRules.boss(profile_index).accent, 2.6)
	var poison := _special == "miasma"
	Sfx.play_at("fire" if not poison else "draw", global_position, 2.0, 0.8 if poison else 1.1)
	var spots: Array[Vector3] = [_clamp_to_ring(player.global_position)]
	var count := (3 if poison else 2 + round_number + (1 if _enraged else 0))
	var tries := 0
	while spots.size() < count and tries < 60:
		tries += 1
		var spot: Vector3
		if poison:
			# Vials land around you, boxing you in.
			var a := randf() * TAU
			spot = _clamp_to_ring(player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 2.6))
		else:
			spot = arena_center + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * arena_limit
			spot.y = global_position.y
		var clear := true
		for other in spots:
			if other.distance_to(spot) < ZONE_RADIUS * 1.6:
				clear = false
		if clear:
			spots.append(spot)
	for i in spots.size():
		# The one under you goes off last, so there's time to read it.
		_spawn_zone(spots[i], ZONE_FUSE + (0.25 if i == 0 else 0.0) + (0.15 * i if not poison else 0.0), poison)


func _spawn_zone(center: Vector3, fuse: float, poison: bool) -> void:
	var color := MIASMA_COLOR if poison else DANGER
	var node := Node3D.new()
	node.top_level = true
	add_child(node)
	node.global_position = center + Vector3.UP * 0.04
	var fill := _zone_material(Color(color, 0.0))
	var disc := CylinderMesh.new()
	disc.top_radius = ZONE_RADIUS
	disc.bottom_radius = ZONE_RADIUS
	disc.height = 0.01
	disc.radial_segments = 32
	disc.material = fill
	var disc_node := MeshInstance3D.new()
	disc_node.mesh = disc
	node.add_child(disc_node)
	var edge := _zone_material(Color(color, 0.8))
	var ring := TorusMesh.new()
	ring.inner_radius = ZONE_RADIUS * 0.93
	ring.outer_radius = ZONE_RADIUS
	ring.rings = 40
	ring.material = edge
	var ring_node := MeshInstance3D.new()
	ring_node.mesh = ring
	ring_node.scale = Vector3(1, 0.3, 1)
	node.add_child(ring_node)
	_zones.append({"center": center, "fuse": fuse, "total": fuse, "linger": MIASMA_LINGER if poison else 0.0,
			"tick": 0.5, "node": node, "fill": fill, "edge": edge, "poison": poison})


func _update_zones(delta: float) -> void:
	for zone in _zones.duplicate():
		if not is_instance_valid(zone.node):
			_zones.erase(zone)
			continue
		var color: Color = MIASMA_COLOR if zone.poison else DANGER
		if zone.fuse > 0.0:
			zone.fuse -= delta
			var progress: float = 1.0 - zone.fuse / zone.total
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 22.0, progress))
			zone.fill.albedo_color = Color(color, lerpf(0.08, 0.4, progress) * (0.7 + 0.3 * pulse))
			if zone.fuse <= 0.0:
				_burst_zone(zone)
			continue
		if zone.poison and zone.linger > 0.0:
			zone.linger -= delta
			zone.tick -= delta
			zone.fill.albedo_color = Color(color, 0.25 * clampf(zone.linger, 0.0, 1.0))
			zone.edge.albedo_color = Color(color, 0.5 * clampf(zone.linger, 0.0, 1.0))
			if zone.tick <= 0.0:
				zone.tick = 0.5
				if _inside(zone.center) and player.active:
					player._take_damage(attack_damage * MIASMA_TICK, self)
					DamagePopup.spawn(get_parent(), "POISON", MIASMA_COLOR, 28, player.global_position + Vector3(0, 1.4, 0))
			if zone.linger <= 0.0:
				zone.node.queue_free()
				_zones.erase(zone)
			continue
		zone.node.queue_free()
		_zones.erase(zone)


func _burst_zone(zone: Dictionary) -> void:
	var color: Color = MIASMA_COLOR if zone.poison else DANGER
	var at: Vector3 = zone.center
	Sfx.play_at("fire" if zone.poison else "quake", at, 0.0, 1.3 if zone.poison else 1.6)
	HitFx.burst(get_parent(), at + Vector3.UP * 0.2, Vector3.UP, color, 26, 7.0, true, 0.07)
	_shockwave(at, ZONE_RADIUS, color)
	if _inside(at) and player.active:
		player.receive_attack(attack_damage * (ZONE_DAMAGE * 0.7 if zone.poison else ZONE_DAMAGE), at, "zone", self)
	if zone.poison:
		zone.fill.albedo_color = Color(color, 0.25)
		var cloud := CPUParticles3D.new()
		cloud.amount = 10 if Settings.use_web_profile() else 18
		cloud.lifetime = 1.4
		cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		cloud.emission_sphere_radius = ZONE_RADIUS * 0.8
		cloud.gravity = Vector3(0, 0.25, 0)
		cloud.initial_velocity_min = 0.05
		cloud.initial_velocity_max = 0.2
		cloud.scale_amount_min = 2.0
		cloud.scale_amount_max = 4.0
		var puff := BoxMesh.new()
		puff.size = Vector3.ONE * 0.12
		var puff_material := _zone_material(Color(color, 0.35))
		puff.material = puff_material
		cloud.mesh = puff
		cloud.position.y = 0.5
		zone.node.add_child(cloud)


func _inside(center: Vector3) -> bool:
	var flat := player.global_position - center
	flat.y = 0.0
	return flat.length() <= ZONE_RADIUS + 0.25


func _clear_specials() -> void:
	_hide_mark()
	for zone in _zones:
		if is_instance_valid(zone.node):
			zone.node.queue_free()
	_zones.clear()
	_special = ""
	_step = ""


# --- Canvas marks ---

func _zone_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	material.albedo_color = color
	return material


func _ensure_mark() -> void:
	if _mark:
		return
	_mark_material = _zone_material(Color(DANGER, 0.3))
	_mark = MeshInstance3D.new()
	_mark.top_level = true
	add_child(_mark)


func _show_mark_ring(center: Vector3, radius: float, color: Color) -> void:
	_ensure_mark()
	if not _mark.mesh is CylinderMesh:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.01
		disc.radial_segments = 32
		disc.material = _mark_material
		_mark.mesh = disc
	_mark.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 1, radius)), center + Vector3.UP * 0.05)
	_mark_material.albedo_color = Color(color, _mark_material.albedo_color.a)
	_mark.visible = true


func _show_mark_lane(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	_ensure_mark()
	if not _mark.mesh is BoxMesh:
		var box := BoxMesh.new()
		box.size = Vector3(1, 0.01, 1)
		box.material = _mark_material
		_mark.mesh = box
	var flat := to - from
	flat.y = 0.0
	var mid := from + flat * 0.5
	mid.y = global_position.y + 0.05
	var basis := Basis.looking_at(flat.normalized(), Vector3.UP).scaled(Vector3(width, 1, flat.length()))
	_mark.global_transform = Transform3D(basis, mid)
	_mark_material.albedo_color = Color(color, _mark_material.albedo_color.a)
	_mark.visible = true


## Fades the mark in and pulses it faster as the hit gets close.
func _pulse_mark(progress: float) -> void:
	if _mark == null or not _mark.visible:
		return
	progress = clampf(progress, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * lerpf(6.0, 22.0, progress))
	_mark_material.albedo_color.a = lerpf(0.15, 0.55, progress) * (0.7 + 0.3 * pulse)


func _hide_mark() -> void:
	if _mark:
		_mark.visible = false


func _shockwave(at: Vector3, radius: float, color: Color) -> void:
	var material := _zone_material(Color(color.lightened(0.3), 0.8))
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.8
	mesh.outer_radius = 1.0
	mesh.material = material
	var wave := MeshInstance3D.new()
	wave.mesh = mesh
	get_parent().add_child(wave)
	wave.global_position = at + Vector3.UP * 0.15
	wave.scale = Vector3(0.4, 1.0, 0.4)
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3(radius, 1.5, radius), 0.22).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.32)
	tween.tween_callback(wave.queue_free)
