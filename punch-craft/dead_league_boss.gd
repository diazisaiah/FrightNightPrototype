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
## Slipping your punches between combos, then countering (dodge it and counter
## back). Chance per contender (its profile's "evade"), +5% a round, +10% at
## the final bell; at most once every EVADE_COOLDOWN.
const EVADE_TIME := 0.3
const EVADE_COOLDOWN := 1.5
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

## Sister Southpaw: once a combo she may pivot behind you between punches
## (PIVOT_CHANCE, in PIVOT_TIME). She slips often, even at the end of her
## open window if you get greedy, and answers with a right-handed jab (a
## southpaw's jab), sometimes two.
const PIVOT_CHANCE := 0.4
const PIVOT_TIME := 0.55
const PIVOT_DISTANCE := 1.7
## The Plague Doctor heals this share of his max HP for every punch that
## lands (a graze: GRAZE_DOSE), half again in a Rampage. Below
## ADRENALINE_BELOW HP his Adrenaline Shot sets off RAMPAGE_TIME of faster,
## longer combos (then ADRENALINE_COOLDOWN before the next shot).
const DOSE := 0.04
const GRAZE_DOSE := 0.015
const INJECT_TIME := 1.0
const RAMPAGE_TIME := 7.0
const RAMPAGE_WINDUP := 0.75
const RAMPAGE_SPEED := 1.3
const ADRENALINE_BELOW := 0.7
const ADRENALINE_COOLDOWN := 20.0
## The Headless: winds up its Skull Toss this long, and fights blind (wild
## combos at whatever it's facing) this long after you punch the skull down.
## It throws it often (a charge only CHARGE_SHARE of the time), and from
## round 2 it catches the skull and throws it straight back: once in round 2,
## twice in round 3 (CATCH_WIND to wind up again).
const SKULL_WIND := 0.8
const CATCH_WIND := 0.5
const CHARGE_SHARE := 0.35
## How far the Plague Doctor hops back before his Adrenaline Shot.
const HOP_BACK := 3.5
const BLIND_TIME := 5.0
## The Coffin King gets quicker as he's hurt: near 0 HP, windups this much
## shorter (KING_HASTE) and pauses between combos this much shorter.
const KING_HASTE := 0.4
const KING_REST := 0.6
const OWN_SPECIAL_NAMES := {"skull_toss": "SKULL TOSS", "adrenaline": "ADRENALINE SHOT"}
const WILD_COMBOS := [
	["left_hook", "right_hook", "left_hook"], ["right_hook", "left_hook", "uppercut"],
	["jab", "cross", "left_hook", "right_hook"], ["cross", "cross", "slam"], ["left_hook", "uppercut", "right_hook"],
]
const RAMPAGE_COMBOS := [
	["jab", "cross", "jab", "cross", "uppercut"], ["left_hook", "right_hook", "left_hook", "right_hook", "slam"],
	["jab", "jab", "cross", "left_hook", "uppercut"], ["cross", "left_hook", "cross", "right_hook", "uppercut"],
]

var profile_index := 0
var round_number := 1
var _pivoted := false
var _rampage_time := 0.0
var _adrenaline_wait := 0.0
var _rampage_fx: CPUParticles3D
var _blind_time := 0.0
var _blind_dir := Vector3.FORWARD
var _blind_turn := 0.0
var _skull_shot: SkullShot
var _rethrows := 0
var _head_parent: Node3D
var _head_rest := Vector3.ZERO
var _base_windup := 1.0
var _base_speed := 1.0
var _king_stage := 0
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
	open_scale = profile.open
	coin_reward = 0
	xp_reward = 0
	base_armor = 0.0
	armor_value = 0.0
	armor_bonus_hp = 0.0
	is_boss = true
	hit_color = profile.accent
	special_kit = KITS[profile_index]
	special_first = FIRST_SPECIAL
	_base_windup = windup_scale
	_base_speed = move_speed


func _ready() -> void:
	super()
	# After the parts are voxelized (also deferred, queued first).
	_finish_look.call_deferred()


func _pick_combo() -> Array:
	var pools := [
		[["jab", "cross"], ["cross", "left_hook"], ["jab", "cross", "slam"], ["left_hook", "right_hook"], ["slam"]],
		[["jab", "cross", "jab"], ["cross", "left_hook"], ["jab", "right_hook", "cross"], ["left_hook", "cross"]],
		[["jab", "left_hook"], ["jab", "cross", "left_hook"], ["left_hook", "cross", "left_hook"], ["cross", "left_hook", "uppercut"]],
		[["jab", "jab", "uppercut"], ["jab", "cross", "left_hook", "uppercut"], ["cross", "left_hook", "cross"],
			["jab", "cross", "jab", "cross"], ["left_hook", "uppercut", "cross"], ["jab", "cross", "slam"]],
		[["jab", "cross", "left_hook", "right_hook"], ["cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "slam"], ["slam", "jab", "cross"]],
	]
	if _rampage_time > 0.0:
		return RAMPAGE_COMBOS.pick_random()
	var pool: Array = pools[profile_index]
	if _enraged:
		pool = pool + [["jab", "cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "left_hook", "slam"]]
	# The Coffin King strings more together the more he's hurt.
	if profile_index == 4 and _hurt() > 0.5:
		pool = pool + [["jab", "cross", "left_hook", "right_hook", "uppercut"], ["cross", "left_hook", "cross", "right_hook", "slam"]]
	return pool.pick_random()


## Contenders keep the pressure on (2026-10-24: shorter pauses, so combos come
## more often). Dodging a whole combo still leaves them open as long as ever.
var _evade_cooldown := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	_evade_cooldown -= delta
	_adrenaline_wait -= delta
	if _rampage_time > 0.0:
		_rampage_time -= delta
		if _rampage_time <= 0.0:
			_end_rampage()
	if _blind_time > 0.0:
		_blind_time -= delta
		if _blind_time <= 0.0 and is_instance_valid(_skull_shot) and not is_dead():
			_skull_shot.recall()
	if profile_index == 4 and not is_dead():
		_king_haste()


## Share of its HP gone (0 fresh, 1 down).
func _hurt() -> float:
	return 1.0 - clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


## Only between combos (never mid-combo, mid-special, reeling or left open).
## Sister Southpaw also slips at the tail of her open window: don't get greedy.
func try_evade(_punch_type: String, hand: String) -> bool:
	var greedy := profile_index == 2 and _state == State.RECOVER and _state_timer < 0.4
	if (_state != State.IDLE and not greedy) or _special != "" or _blind_time > 0.0 or _evade_cooldown > 0.0 \
			or _stagger_timer > 0.0 or is_dead():
		return false
	var chance: float = DeadLeagueRules.boss(profile_index).evade + 0.05 * (round_number - 1) + (0.1 if _enraged else 0.0)
	if randf() >= chance:
		return false
	_evade_cooldown = EVADE_COOLDOWN
	_evade_side = 1.0 if hand == "left" else -1.0
	_queue.clear()
	_enter(State.EVADE, EVADE_TIME)
	DamagePopup.spawn(get_parent(), "SLIPPED", SLIP_COLOR, 44, global_position + Vector3(0, 2.6, 0))
	return true


func _idle_time() -> float:
	var base: float = DeadLeagueRules.boss(profile_index).idle
	var rest := randf_range(base * 0.75, base * 1.2) * (0.75 if _enraged else 1.0)
	if _rampage_time > 0.0:
		rest *= 0.45
	if profile_index == 4:
		rest *= 1.0 - KING_REST * _hurt()
	return rest


func _recover_time() -> float:
	return randf_range(0.45, 0.8)


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
	if not _charging() and (not (_state in [State.WINDUP, State.STRIKE]) or not _uses_arm(arm)):
		var side := -1.0 if arm == "left" else 1.0
		return [Vector3(GUARD_SHOULDER, GUARD_SPREAD * side, 0), 0.0, Vector3(GUARD_ELBOW, 0, 0)]
	return super(arm)


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	_look_time += delta
	if _float_head and _skull_shot == null:
		# Rises over the neck as it winds up a Skull Toss.
		var lift := 0.25 * minf(_step_time / SKULL_WIND, 1.0) if _step == "wind" else 0.0
		_float_head.position.y = _float_base + sin(_look_time * 2.2) * 0.035 + lift
		_float_head.rotation.z = sin(_look_time * 1.3) * 0.08


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


# --- Specials (Boxer) ---------------------------------------------------------------

## Each contender's signature moves (see Boxer specials): the Bellman's
## leaping slam, the Headless's ghost charge, Sister Southpaw's judgment
## circles and charge, the Plague Doctor's miasma and slam, all of them for
## the Coffin King.
const KITS := [["leap_slam"], ["charge", "skull_toss"], ["zones", "charge"], ["miasma", "leap_slam", "adrenaline"], ["leap_slam", "charge", "zones"]]
## Seconds between specials per contender in round 1; each later round
## brings them 12% sooner, the final bell 30% sooner.
const SPECIAL_EVERY := [9.0, 6.5, 8.0, 9.0, 7.0]
const FIRST_SPECIAL := 5.0


## The ring is small and they fight up close: every move is always on, but
## the skull can only be thrown while it's on, and an Adrenaline Shot comes
## first whenever it's ready.
func _special_in_range(kind: String, _distance: float) -> bool:
	match kind:
		"skull_toss":
			return _skull_shot == null
		"charge":
			if profile_index == 1:
				return randf() < CHARGE_SHARE
		"adrenaline":
			return _adrenaline_ready()
	return not ("adrenaline" in special_kit and _adrenaline_ready())


func _adrenaline_ready() -> bool:
	return _rampage_time <= 0.0 and _adrenaline_wait <= 0.0 and hp < max_hp * ADRENALINE_BELOW


func _special_tint() -> Color:
	return DeadLeagueRules.boss(profile_index).accent


## In round 3 or after the final bell, a slam or charge can come twice.
func _special_repeats(kind: String) -> int:
	return 1 if kind in ["leap_slam", "charge"] and (_enraged or round_number == 3) and randf() < 0.5 else 0


func _special_delay() -> float:
	var delay: float = SPECIAL_EVERY[profile_index] * (1.0 - 0.12 * (round_number - 1)) * (0.7 if _enraged else 1.0) * randf_range(0.85, 1.15)
	return delay * (1.0 - 0.35 * _hurt()) if profile_index == 4 else delay


func _zone_count() -> int:
	return 2 + round_number + (1 if _enraged else 0)


func _announce_special(kind: String) -> void:
	DamagePopup.spawn(get_parent(), SPECIAL_NAMES.get(kind, OWN_SPECIAL_NAMES.get(kind, "")), _special_tint(), 46, global_position + Vector3(0, 3.0, 0))
	# The marks can be under your feet, out of view: say what to do.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var how := {
			"leap_slam": "GET OUT OF THE RED  -  or jump it (%s)" % Controls.text("jump"),
			"charge": "STEP OUT OF THE LANE  -  or roll (%s)" % Controls.text("roll"),
			"zones": "STAY OUT OF THE CIRCLES",
			"miasma": "STAY OUT OF THE POISON",
			"skull_toss": "PUNCH THE SKULL  -  or slip it",
			"adrenaline": "HE'S ABOUT TO RAMPAGE",
		}
		hud.announce_small(how.get(kind, ""), Telegraphs.DANGER.lightened(0.3))


# --- Signature moves ---------------------------------------------------------------

func _start_combo() -> void:
	_pivoted = false
	super()


func _begin_attack(attack: String, windup: float) -> void:
	if profile_index == 2 and _state == State.EVADE:
		# Sister Southpaw answers a slip with her jab: the right hand, quick,
		# sometimes doubled.
		attack = "cross"
		windup = 0.0
		_pivoted = false
		if randf() < 0.4:
			_queue.append("cross")
	elif _state == State.STRIKE and _blind_time <= 0.0:
		if profile_index == 2 and not _pivoted and randf() < PIVOT_CHANCE:
			_pivoted = true
			windup += _pivot_behind()
		elif profile_index == 3:
			# The Plague Doctor stutters: each follow-up comes early or late.
			windup *= randf_range(0.6, 1.5)
	super(attack, windup)


func _strike(distance: float) -> void:
	# Blind, it swings at whatever's in front of it.
	if _blind_time > 0.0 and facing(player.global_position) < 0.7:
		_last_result = ""
		_enter(State.STRIKE, STRIKE_TIME)
		_cue_label.visible = false
		Sfx.play_at("whoosh", global_position + Vector3.UP * 1.5, -4.0, 0.8)
		return
	super(distance)
	# The Plague Doctor's dose: every punch that lands patches him up.
	if profile_index == 3 and not is_dead():
		var dose := DOSE if _last_result == "hit" else GRAZE_DOSE if _last_result == "grazed" else 0.0
		if dose > 0.0:
			heal(max_hp * dose * (1.5 if _rampage_time > 0.0 else 1.0))


func _think(delta: float) -> Vector3:
	if _blind_time > 0.0:
		return _think_blind(delta)
	return super(delta)


## Sister Southpaw, mid-combo: around your side and behind you in a blink.
## Returns how much longer the next punch waits (time to turn and find her).
func _pivot_behind() -> float:
	var back := player.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else -_to_player().normalized()
	var side := back.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	var around := _clamp_to_arena(player.global_position + side * PIVOT_DISTANCE)
	var behind := _clamp_to_arena(player.global_position + back * PIVOT_DISTANCE)
	var accent: Color = DeadLeagueRules.boss(profile_index).accent
	MoveFx.afterimage(get_parent(), global_position, accent, 0.4)
	Sfx.play_at("whoosh", global_position, 2.0, 1.3)
	collision_mask &= ~2
	var tween := create_tween()
	tween.tween_property(self, "global_position", around, PIVOT_TIME * 0.5)
	tween.tween_property(self, "global_position", behind, PIVOT_TIME * 0.5)
	tween.tween_callback(func() -> void:
		collision_mask |= 2
		var to := _to_player()
		rotation.y = atan2(-to.x, -to.z)
		MoveFx.afterimage(get_parent(), global_position, accent, 0.3))
	DamagePopup.spawn(get_parent(), "PIVOT", accent, 40, behind + Vector3(0, 2.6, 0))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.announce_small("BEHIND YOU", accent.lightened(0.3))
	return PIVOT_TIME + 0.35


func _start_special(kind: String) -> void:
	super(kind)
	match kind:
		"skull_toss":
			_locked = false
			_rethrows = round_number - 1
			_set_step("wind")
		"adrenaline":
			# Hops back out of reach first, then the needle.
			_locked = false
			var away := -_to_player()
			away = away.normalized() if away.length() > 0.1 else global_basis.z
			_begin_leap(_clamp_to_arena(global_position + away * HOP_BACK))


func _run_special(delta: float) -> Vector3:
	match _step:
		"wind":
			_step_time += delta
			_turn_toward(_to_player(), delta)
			if not _locked and _step_time >= SKULL_WIND - tell_time():
				_locked = true
				_flash_tell(SLIP_COLOR, 2.1)
			if _step_time >= SKULL_WIND:
				_locked = false
				_throw_skull()
				_set_step("toss")
			return Vector3.ZERO
		"toss":
			# Waits on the skull (skull_back / skull_down end it).
			_step_time += delta
			_turn_toward(_to_player(), delta)
			if _step_time > 6.0:
				_end_special()
			return Vector3.ZERO
		"inject":
			_step_time += delta
			if not _locked and _step_time >= INJECT_TIME * 0.5:
				_locked = true
				var neck := global_position + Vector3.UP * 1.6 * _body.scale.y
				HitFx.burst(get_parent(), neck, Vector3.UP, DeadLeagueRules.boss(profile_index).accent, 24, 4.0, true, 0.06)
				Sfx.play_at("draw", neck, 2.0, 0.6)
			if _step_time >= INJECT_TIME:
				_locked = false
				_start_rampage()
				_end_special()
			return Vector3.ZERO
	return super(delta)


## The Plague Doctor lands his hop back: then the needle.
func _land() -> void:
	if _special != "adrenaline":
		super()
		return
	collision_mask |= 2
	velocity.y = 0.0
	Sfx.play_at("quake", global_position, -4.0, 0.9)
	_set_step("inject")


func _animate_special(delta: float) -> void:
	super(delta)
	if _step == "inject":
		# Head back, the needle in.
		_body.rotation.x = lerpf(_body.rotation.x, -0.3, minf(1.0, 10.0 * delta))
	elif _step == "wind":
		_body.rotation.x = lerpf(_body.rotation.x, -0.2, minf(1.0, 10.0 * delta))


# The Headless's skull.

func _throw_skull() -> void:
	if _float_head == null:
		return
	_head_parent = _float_head.get_parent()
	_head_rest = _float_head.position
	_skull_shot = SkullShot.toss(self, _float_head, player)


## Where the skull floats over the neck, in the world.
func skull_home() -> Vector3:
	if _head_parent == null:
		return global_position + Vector3.UP * 2.4
	return _head_parent.to_global(Vector3(_head_rest.x, _float_base, _head_rest.z))


func skull_back(head: Node3D) -> void:
	head.reparent(_head_parent, false)
	head.transform = Transform3D(Basis.IDENTITY, Vector3(_head_rest.x, _float_base, _head_rest.z))
	_skull_shot = null
	if _special != "skull_toss":
		return
	# Rounds 2 and 3: caught, and straight back at you.
	if _rethrows > 0 and not is_dead():
		_rethrows -= 1
		DamagePopup.spawn(get_parent(), "CAUGHT", DeadLeagueRules.boss(profile_index).accent, 42, global_position + Vector3(0, 3.0, 0))
		_locked = false
		_set_step("wind")
		_step_time = SKULL_WIND - CATCH_WIND
		return
	_end_special()


## Punched down: it fights blind until the skull floats back.
func skull_down() -> void:
	if _special == "skull_toss":
		_end_special()
	_blind_time = BLIND_TIME
	_queue.clear()
	_enter(State.IDLE, 0.3)
	DamagePopup.spawn(get_parent(), "BLIND", DeadLeagueRules.boss(profile_index).accent, 50, global_position + Vector3(0, 3.0, 0))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.announce_small("IT CAN'T SEE YOU  -  but it's swinging", Color(0.6, 0.85, 1.0))


## Blind: staggers about, turning every which way (now and then toward you,
## by sound), throwing wild combos at whatever's in front of it.
func _think_blind(delta: float) -> Vector3:
	_blind_turn -= delta
	if _blind_turn <= 0.0:
		_blind_turn = randf_range(0.4, 0.9)
		var toward := _to_player()
		var base := toward.normalized() if toward.length() > 0.1 else -global_basis.z
		_blind_dir = base.rotated(Vector3.UP, randf_range(-PI, PI) if randf() < 0.6 else randf_range(-0.3, 0.3))
	_turn_toward(_blind_dir, delta)
	_state_timer -= delta
	match _state:
		State.IDLE, State.RECOVER, State.EVADE:
			if _state_timer <= 0.0:
				_queue.assign(WILD_COMBOS.pick_random())
				_power_arm = ["left", "right"].pick_random()
				_begin_attack(_queue.pop_front(), FOLLOW_UP_WINDUP)
		State.WINDUP:
			if not _flashed and _state_timer <= tell_time():
				_flashed = true
				if glow_tells:
					_flash_tell(CUES[_attack].color)
			if _state_timer <= 0.0:
				_strike(_to_player().length())
		State.STRIKE:
			if _state_timer <= 0.0:
				if _queue.is_empty():
					_enter(State.RECOVER, randf_range(0.25, 0.5))
				else:
					_power_arm = _next_power_arm
					_begin_attack(_queue.pop_front(), FOLLOW_UP_WINDUP * 0.8)
					_previewed = true
	return Vector3.ZERO if _state == State.STRIKE else _blind_dir * move_speed * 0.45


# The Plague Doctor's Rampage.

func _start_rampage() -> void:
	_rampage_time = RAMPAGE_TIME
	windup_scale *= RAMPAGE_WINDUP
	move_speed *= RAMPAGE_SPEED
	var accent: Color = DeadLeagueRules.boss(profile_index).accent
	DamagePopup.spawn(get_parent(), "RAMPAGE!", accent, 60, global_position + Vector3(0, 3.2, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.0, 4.0, 0.8)
	if _rampage_fx == null:
		_rampage_fx = CPUParticles3D.new()
		_rampage_fx.amount = 30
		_rampage_fx.lifetime = 0.6
		_rampage_fx.position = Vector3(0, 1.2, 0)
		_rampage_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rampage_fx.emission_box_extents = Vector3(0.5, 0.8, 0.35) * BODY_SCALE[profile_index]
		_rampage_fx.direction = Vector3.UP
		_rampage_fx.spread = 20.0
		_rampage_fx.gravity = Vector3(0, 2.0, 0)
		_rampage_fx.initial_velocity_min = 1.0
		_rampage_fx.initial_velocity_max = 2.2
		var mote := BoxMesh.new()
		mote.size = Vector3.ONE * 0.07
		mote.material = _glow_material(accent)
		_rampage_fx.mesh = mote
		add_child(_rampage_fx)
	_rampage_fx.emitting = true


func _end_rampage() -> void:
	_rampage_time = 0.0
	windup_scale /= RAMPAGE_WINDUP
	move_speed /= RAMPAGE_SPEED
	_adrenaline_wait = ADRENALINE_COOLDOWN
	if _rampage_fx:
		_rampage_fx.emitting = false


## The Coffin King: quicker windups and footwork the more he's hurt.
func _king_haste() -> void:
	var hurt := _hurt()
	windup_scale = _base_windup * (1.0 - KING_HASTE * hurt) * (0.88 if _enraged else 1.0)
	move_speed = _base_speed * (1.0 + 0.3 * hurt) * (1.12 if _enraged else 1.0)
	var stage := mini(int(hurt * 3.0), 2)
	if stage > _king_stage:
		_king_stage = stage
		DamagePopup.spawn(get_parent(), "THE KING QUICKENS", DeadLeagueRules.boss(profile_index).accent, 46,
				global_position + Vector3(0, 3.4, 0))
