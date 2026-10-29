class_name DeadLeagueBoss
extends Boss
## One code-built undead prizefighter with five profiles, each modeled after
## its Dead League portrait in simple blocks on a rigged skeleton (BossRig,
## the Character Lab's): the Bellman's bell and molten ribs, the Headless's
## floating flaming skull, Sister Southpaw's veil and gold chain, the Plague
## Doctor's beak and vials, the Coffin King's crown and gold chains. Every one
## glows at the edges in its accent color (a rim overlay), trails wisps of it,
## and carries its own light.

const ROUND_HP := [1.0, 1.16, 1.34]
## Extra windup per contender (2026-10-28: with the big readable swings the
## Plague Doctor and the Coffin King were almost impossible to react to).
const WINDUP_PAD := [0.0, 0.0, 0.0, 0.06, 0.075]
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
## The True Coffin King (the secret boss) and the contenders he tags in:
## scaled to a near-maxed build (Progression.true_par). Partners fight at his
## level with this share of his HP. Round 5 he goes Insano: combos of six to
## eight punches, super armor through every punch of them, quicker tells.
const TRUE_PARTNER_HP := 0.6
const INSANO_COLOR := Color(0.9, 0.12, 0.4)
const INSANO_WINDUP := 0.85
const INSANO_COMBOS := [
	["jab", "cross", "left_hook", "right_hook", "jab", "cross", "uppercut"],
	["left_hook", "right_hook", "left_hook", "right_hook", "cross", "slam"],
	["jab", "jab", "cross", "left_hook", "cross", "right_hook", "left_hook", "uppercut"],
	["cross", "left_hook", "uppercut", "cross", "left_hook", "slam"],
	["jab", "cross", "jab", "cross", "left_hook", "right_hook", "slam"],
]
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
var insano := false
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
	windup_pad = WINDUP_PAD[profile_index]
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


## The True Coffin King's bout: call after configure, before adding to the
## tree. A partner keeps its own moves and tells (quicker ones from the King
## where his are quicker) but hits as hard as he does.
func empower(bout_round: int, partner := false) -> void:
	var king := DeadLeagueRules.boss(DeadLeagueRules.BOSS_COUNT - 1)
	var build := Progression.true_par()
	var step := clampi(bout_round, 1, ROUND_HP.size()) - 1
	max_hp = king.hp * ROUND_HP[step] * build.damage / Progression.BASE_DAMAGE * (TRUE_PARTNER_HP if partner else 1.0)
	attack_damage = king.damage * ROUND_DAMAGE[step] * build.ehp / Progression.BASE_KNUCKLES
	windup_scale = minf(windup_scale, king.windup * (1.0 - 0.045 * step))
	move_speed = maxf(move_speed, 2.5 * king.speed)
	_base_windup = windup_scale
	_base_speed = move_speed
	if not partner:
		display_name = "THE TRUE COFFIN KING"


## Insano style (the True Coffin King's last round).
func go_insano() -> void:
	insano = true
	windup_scale *= INSANO_WINDUP
	_base_windup = windup_scale
	var aura := CPUParticles3D.new()
	aura.amount = 36
	aura.lifetime = 0.6
	aura.position = Vector3(0, 1.2, 0)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	aura.emission_box_extents = Vector3(0.5, 0.8, 0.35) * BODY_SCALE[profile_index]
	aura.direction = Vector3.UP
	aura.spread = 20.0
	aura.gravity = Vector3(0, 2.5, 0)
	aura.initial_velocity_min = 1.2
	aura.initial_velocity_max = 2.6
	var mote := BoxMesh.new()
	mote.size = Vector3.ONE * 0.08
	mote.material = _glow_material(INSANO_COLOR)
	aura.mesh = mote
	add_child(aura)
	DamagePopup.spawn(get_parent(), "INSANO STYLE!", INSANO_COLOR, 70, global_position + Vector3(0, 3.4, 0))
	Sfx.play_at("growl", global_position + Vector3.UP * 2.0, 6.0, 0.6)


## Insano: armored through the last punch of a combo too.
func _combo_armored() -> bool:
	if insano:
		return _state in [State.WINDUP, State.STRIKE]
	return super()


func _pick_combo() -> Array:
	var pools := [
		[["jab", "cross"], ["cross", "left_hook"], ["jab", "cross", "slam"], ["left_hook", "right_hook"], ["slam"]],
		[["jab", "cross", "jab"], ["cross", "left_hook"], ["jab", "right_hook", "cross"], ["left_hook", "cross"]],
		[["jab", "left_hook"], ["jab", "cross", "left_hook"], ["left_hook", "cross", "left_hook"], ["cross", "left_hook", "uppercut"]],
		[["jab", "jab", "uppercut"], ["jab", "cross", "left_hook", "uppercut"], ["cross", "left_hook", "cross"],
			["jab", "cross", "jab", "cross"], ["left_hook", "uppercut", "cross"], ["jab", "cross", "slam"]],
		[["jab", "cross", "left_hook", "right_hook"], ["cross", "left_hook", "uppercut"], ["left_hook", "right_hook", "slam"], ["slam", "jab", "cross"]],
	]
	if insano:
		return INSANO_COMBOS.pick_random()
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


func _animate(delta: float, speed: float) -> void:
	super(delta, speed)
	_look_time += delta
	if _float_head and _skull_shot == null:
		# Rises over the neck as it winds up a Skull Toss.
		var lift := 0.25 * minf(_step_time / SKULL_WIND, 1.0) if _step == "wind" else 0.0
		_float_head.position.y = _float_base + sin(_look_time * 2.2) * 0.035 + lift
		_float_head.rotation.z = sin(_look_time * 1.3) * 0.08


# --- The look ------------------------------------------------------------------

## Each contender's build on the rig (BossRig), in its own (unscaled) units:
## leg, torso, arm and head sizes, how it holds its guard, its idle.
const SHAPES := [
	{"foot": Vector3(0.26, 0.12, 0.36), "lower_leg": 0.42, "upper_leg": 0.4, "hip": 0.36, "torso_h": 0.81,
		"shoulder": 0.9, "upper_arm": 0.36, "forearm": 0.32, "head": Vector3(0.4, 0.38, 0.38), "guard": 0.78, "style": "heavy"},
	{"foot": Vector3(0.18, 0.1, 0.28), "lower_leg": 0.44, "upper_leg": 0.42, "hip": 0.3, "torso_h": 0.68,
		"shoulder": 0.68, "upper_arm": 0.34, "forearm": 0.32, "head": Vector3(0.3, 0.3, 0.3), "guard": 0.92, "style": "float"},
	{"foot": Vector3(0.16, 0.1, 0.26), "lower_leg": 0.43, "upper_leg": 0.42, "hip": 0.28, "torso_h": 0.6,
		"shoulder": 0.56, "upper_arm": 0.31, "forearm": 0.29, "head": Vector3(0.24, 0.28, 0.24), "guard": 1.18, "style": "sway", "southpaw": true},
	{"foot": Vector3(0.17, 0.1, 0.28), "lower_leg": 0.42, "upper_leg": 0.4, "hip": 0.3, "torso_h": 0.66,
		"shoulder": 0.64, "upper_arm": 0.33, "forearm": 0.31, "head": Vector3(0.34, 0.36, 0.32), "guard": 0.85, "style": "hunch"},
	{"foot": Vector3(0.2, 0.12, 0.3), "lower_leg": 0.42, "upper_leg": 0.42, "hip": 0.36, "torso_h": 0.74,
		"shoulder": 0.8, "upper_arm": 0.35, "forearm": 0.32, "head": Vector3(0.32, 0.32, 0.3), "guard": 0.9, "style": "proud"},
]


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


## The Bellman, from his portrait: a stone brute in chunky slabs, molten
## seams and an open ribcage over a glowing core, a big gold bell on chains,
## a toothy stone skull with burning eyes, red-and-white wrapped forearms and
## huge red fists, a riveted belt and a knotted red sash. Ball joints at the
## shoulders and elbows, with a molten ring where the stone meets.
func _build_bellman() -> void:
	var stone := _material(Color(0.47, 0.45, 0.44))
	var stone_light := _material(Color(0.58, 0.56, 0.53))
	var stone_dark := _material(Color(0.3, 0.29, 0.29))
	var dark := _material(Color(0.06, 0.04, 0.04))
	var molten := _glow_material(Color(1.0, 0.45, 0.08))
	molten.emission_energy_multiplier = 1.8
	var core := _glow_material(Color(1.0, 0.7, 0.25))
	core.emission_energy_multiplier = 2.2
	var eyes := _glow_material(Color(1.0, 0.15, 0.08))
	var gold := _material(Color(0.86, 0.62, 0.22), 0.7)
	var gold_dark := _material(Color(0.6, 0.42, 0.14), 0.7)
	var iron := _material(Color(0.16, 0.15, 0.16), 0.6)
	var red := _material(Color(0.66, 0.1, 0.08))
	var red_dark := _material(Color(0.42, 0.06, 0.05))
	var white := _material(Color(0.86, 0.82, 0.76))
	var bone := _material(Color(0.86, 0.8, 0.68))
	_rig_body(SHAPES[0], Color(0.75, 0.08, 0.06))

	# Legs: blocky feet with toes, shins with a lighter plate, knee
	# boulders, stone thighs with a molten seam.
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.18 * side
		_on("foot" + s, _box(Vector3(0.26, 0.12, 0.36)), stone_dark, Vector3(x, 0.06, -0.04))
		for t in 3:
			_on("foot" + s, _box(Vector3(0.07, 0.07, 0.06)), stone, Vector3(x + (t - 1) * 0.08, 0.045, -0.24))
		_on("shin" + s, _box(Vector3(0.24, 0.36, 0.26)), stone_dark, Vector3(x, 0.31, 0))
		_on("shin" + s, _box(Vector3(0.17, 0.24, 0.04)), stone_light, Vector3(x, 0.33, -0.14))
		_on("shin" + s, _box(Vector3(0.28, 0.16, 0.29)), stone, Vector3(x, 0.54, -0.02), Vector3(0.12, 0, 0.08 * side))
		_on("thigh" + s, _box(Vector3(0.29, 0.34, 0.31)), stone, Vector3(x, 0.77, 0))
		_on("thigh" + s, _box(Vector3(0.02, 0.2, 0.012)), molten, Vector3(x + 0.05 * side, 0.78, -0.16), Vector3(0, 0, 0.3 * side))

	# Hips: the iron belt with gold rivets and a buckle, the knotted sash and
	# its tails, the loincloth (banded front, long back) and tattered strips.
	_on("pelvis", _box(Vector3(0.82, 0.13, 0.52)), iron, Vector3(0, 1.0, 0))
	for i in 6:
		var rx: float = -0.32 + i * 0.128
		if absf(rx) > 0.08:
			_on("pelvis", _box(Vector3(0.035, 0.035, 0.02)), gold, Vector3(rx, 1.0, -0.265))
	_on("pelvis", _box(Vector3(0.17, 0.15, 0.04)), gold, Vector3(0, 1.0, -0.27))
	_on("pelvis", _box(Vector3(0.08, 0.07, 0.02)), dark, Vector3(0, 1.0, -0.292))
	_on("pelvis", _box(Vector3(0.16, 0.14, 0.1)), red, Vector3(0.26, 0.98, -0.25))
	for tail in [[0.22, 0.12], [0.31, -0.1]]:
		_on("sash", _box(Vector3(0.08, 0.36, 0.03)), red, Vector3(tail[0], 0.8, -0.29), Vector3(0, 0, tail[1]))
	_on("sash", _box(Vector3(0.34, 0.42, 0.04)), red, Vector3(0, 0.72, -0.25))
	for y: float in [0.86, 0.62]:
		_on("sash", _box(Vector3(0.345, 0.04, 0.045)), white, Vector3(0, y, -0.25))
	_on("sash", _box(Vector3(0.5, 0.5, 0.04)), red_dark, Vector3(0, 0.7, 0.27))
	_tatters("legs", 0.92, 0.42, 0.28, [red, red_dark, white, red], 14, Vector2(0.22, 0.4))

	# The open chest: stone ribs over a molten glow between stone flanks,
	# over a dark gut.
	_on("spine", _box(Vector3(0.62, 0.18, 0.42)), stone_dark, Vector3(0, 1.08, 0.02))
	_on("spine", _box(Vector3(0.48, 0.34, 0.06)), molten, Vector3(0, 1.3, -0.17))
	_on("spine", _sphere(0.12), core, Vector3(0, 1.3, -0.1))
	for i in 4:
		_on("spine", _box(Vector3(0.46 - i * 0.04, 0.045, 0.05)), stone_light, Vector3(0, 1.17 + i * 0.085, -0.215))
	_on("spine", _box(Vector3(0.06, 0.34, 0.05)), stone_light, Vector3(0, 1.3, -0.22))
	for side: float in [-1.0, 1.0]:
		_on("spine", _box(Vector3(0.2, 0.38, 0.44)), stone, Vector3(0.34 * side, 1.29, 0.02))
	_on("spine", _box(Vector3(0.9, 0.5, 0.2)), stone_dark, Vector3(0, 1.3, 0.2))
	_on("spine", _box(Vector3(0.015, 0.3, 0.012)), molten, Vector3(0.12, 1.28, 0.306), Vector3(0, 0, -0.5))
	_on("spine", _box(Vector3(0.015, 0.2, 0.012)), molten, Vector3(-0.2, 1.22, 0.306), Vector3(0, 0, 0.3))

	# The chest: slab pecs with a molten seam and cracks, shoulder-blade
	# slabs, spine nubs, the traps, and boulder shoulders on the collarbones.
	_on("chest", _box(Vector3(0.88, 0.3, 0.44)), stone, Vector3(0, 1.6, 0.02))
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.34, 0.18, 0.18)), stone_light, Vector3(0.2 * side, 1.56, -0.17), Vector3(0, -0.12 * side, 0))
		_on("chest", _box(Vector3(0.13, 0.015, 0.012)), molten, Vector3(0.2 * side, 1.55, -0.264), Vector3(0, 0, 0.35 * side))
		_on("chest", _box(Vector3(0.32, 0.28, 0.08)), stone, Vector3(0.21 * side, 1.5, 0.31), Vector3(0, 0, 0.1 * side))
		var s := "_l" if side < 0.0 else "_r"
		_on("clavicle" + s, _box(Vector3(0.36, 0.26, 0.4)), stone, Vector3(0.47 * side, 1.66, 0))
		_on("clavicle" + s, _box(Vector3(0.24, 0.12, 0.26)), stone_light, Vector3(0.5 * side, 1.82, 0.02), Vector3(0, 0, 0.2 * side))
		_on("clavicle" + s, _box(Vector3(0.012, 0.16, 0.012)), molten, Vector3(0.42 * side, 1.66, -0.205), Vector3(0, 0, 0.4 * side))
	_on("chest", _box(Vector3(0.03, 0.18, 0.02)), molten, Vector3(0, 1.56, -0.26))
	_on("chest", _box(Vector3(0.9, 0.3, 0.2)), stone_dark, Vector3(0, 1.6, 0.2))
	for i in 3:
		_on("chest", _box(Vector3(0.08, 0.07, 0.08)), stone, Vector3(0, 1.2 + i * 0.13, 0.33))
	_on("chest", _box(Vector3(0.52, 0.16, 0.32)), stone_dark, Vector3(0, 1.74, 0.04))

	# The bell, hung low on the chest (below the ribs): hanger, band, a heavy
	# lip and a clapper, on gold chains from both shoulders, and a chain
	# draped across the collar.
	_on("chest", _box(Vector3(0.1, 0.07, 0.1)), iron, Vector3(0, 1.18, -0.42))
	_on("chest", _cylinder_tapered(0.12, 0.23, 0.3), gold, Vector3(0, 1.0, -0.44))
	_on("chest", _cylinder_tapered(0.18, 0.18, 0.03), gold_dark, Vector3(0, 1.03, -0.44))
	_on("chest", _cylinder_tapered(0.25, 0.25, 0.05), gold_dark, Vector3(0, 0.88, -0.44))
	_on("chest", _sphere(0.055), iron, Vector3(0, 0.86, -0.44))
	for side: float in [-1.0, 1.0]:
		_chain_on("chest", Vector3(0.36 * side, 1.72, -0.16), Vector3(0.04 * side, 1.18, -0.42), 9, gold)
	_chain_on("chest", Vector3(-0.3, 1.76, -0.17), Vector3(0.3, 1.76, -0.17), 8, gold)

	# The neck, and the skull: a cracked stone cranium with a heavy brow,
	# burning eyes in dark sockets, cheekbones, and a jaw full of teeth.
	_on("neck", _box(Vector3(0.2, 0.14, 0.2)), stone, Vector3(0, 1.8, 0))
	_on("head", _box(Vector3(0.4, 0.32, 0.38)), stone, Vector3(0, 2.02, -0.04))
	_on("head", _box(Vector3(0.45, 0.07, 0.1)), stone_dark, Vector3(0, 2.05, -0.22))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.12, 0.09, 0.03)), dark, Vector3(0.1 * side, 1.97, -0.235))
		_on("head", _box(Vector3(0.065, 0.045, 0.02)), eyes, Vector3(0.1 * side, 1.97, -0.25))
		_on("head", _box(Vector3(0.12, 0.06, 0.09)), stone_light, Vector3(0.15 * side, 1.91, -0.18))
	_on("head", _box(Vector3(0.05, 0.06, 0.02)), dark, Vector3(0, 1.92, -0.235))
	_on("head", _box(Vector3(0.33, 0.11, 0.3)), stone_dark, Vector3(0, 1.83, -0.08))
	for row in [[1.875, 0.0], [1.84, 0.02]]:
		for t in 5:
			_on("head", _box(Vector3(0.035, 0.045, 0.02)), bone, Vector3(-0.1 + t * 0.05 + row[1] * 0.5, row[0], -0.235))
	_on("head", _box(Vector3(0.015, 0.15, 0.01)), molten, Vector3(0.08, 2.08, -0.226), Vector3(0, 0, 0.4))
	_on("head", _box(Vector3(0.1, 0.06, 0.12)), stone_dark, Vector3(-0.1, 2.19, 0.02), Vector3(0, 0, 0.2))

	# Arms: a stone ball joint with a molten ring, a chunky upper arm, a
	# ball elbow, a forearm wrapped white with red bands, a huge red fist.
	for arm in ["left", "right"]:
		var side := -1.0 if arm == "left" else 1.0
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _sphere(0.14), stone_dark, Vector3.ZERO)
		_at("upper_arm" + s, _cylinder_tapered(0.146, 0.146, 0.03), molten, Vector3(0, -0.06, 0))
		_at("upper_arm" + s, _box(Vector3(0.23, 0.26, 0.23)), stone, Vector3(0, -0.2, 0))
		_at("upper_arm" + s, _box(Vector3(0.14, 0.16, 0.12)), stone_dark, Vector3(0.05 * side, -0.16, 0.06))
		_at("forearm" + s, _sphere(0.12), stone_dark, Vector3.ZERO)
		_at("forearm" + s, _cylinder_tapered(0.125, 0.125, 0.025), molten, Vector3(0, -0.02, 0))
		_at("forearm" + s, _box(Vector3(0.2, 0.26, 0.2)), white, Vector3(0, -0.17, 0))
		for k in 3:
			_at("forearm" + s, _box(Vector3(0.21, 0.035, 0.21)), red, Vector3(0, -0.08 - k * 0.075, 0))
		_at("forearm" + s, _box(Vector3(0.045, 0.13, 0.02)), white, Vector3(0.11 * side, -0.12, 0.05), Vector3(0, 0, 0.2 * side))
		_fist(arm, Vector3(0.27, 0.22, 0.26))


## The Headless, from its portrait: a skeleton boxer in navy wraps. An open
## ribcage over navy cloth, blue ghost-fire off the shoulders and the neck
## stump, the skull floating above in its own flame, a heavy wrapped sash
## over a long ragged navy-and-white skirt, bandaged arms and shins.
func _build_headless() -> void:
	var bone := _material(Color(0.86, 0.84, 0.78))
	var bone_old := _material(Color(0.7, 0.68, 0.62))
	var bandage := _material(Color(0.8, 0.79, 0.76))
	var navy := _material(Color(0.12, 0.16, 0.36))
	var navy_dark := _material(Color(0.06, 0.08, 0.18))
	var dark := _material(Color(0.03, 0.04, 0.07))
	var flame := _glow_material(Color(0.3, 0.75, 1.0))
	var eyes := _glow_material(Color(0.5, 0.95, 1.0))
	_rig_body(SHAPES[1], Color(0.16, 0.22, 0.46))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.15 * side
		_on("foot" + s, _box(Vector3(0.18, 0.08, 0.28)), bandage, Vector3(x, 0.04, -0.03))
		_on("foot" + s, _box(Vector3(0.12, 0.04, 0.06)), bone, Vector3(x, 0.03, -0.19))
		_on("shin" + s, _box(Vector3(0.13, 0.36, 0.13)), bandage, Vector3(x, 0.3, 0))
		for y: float in [0.2, 0.38]:
			_on("shin" + s, _box(Vector3(0.135, 0.05, 0.135)), navy, Vector3(x, y, 0))
		_on("shin" + s, _box(Vector3(0.12, 0.08, 0.12)), bone, Vector3(x, 0.52, -0.01))
		_on("thigh" + s, _box(Vector3(0.1, 0.36, 0.1)), bone_old, Vector3(x, 0.74, 0))
	# A thick wrapped sash, its knot and tails, over the long ragged skirt.
	_on("pelvis", _box(Vector3(0.62, 0.14, 0.42)), navy_dark, Vector3(0, 1.0, 0))
	_on("pelvis", _box(Vector3(0.63, 0.04, 0.43)), bandage, Vector3(0, 1.05, 0))
	_on("pelvis", _box(Vector3(0.14, 0.12, 0.08)), navy, Vector3(0.18, 0.98, -0.21))
	for tail in [[0.15, 0.12], [0.22, -0.1]]:
		_on("sash", _box(Vector3(0.08, 0.34, 0.03)), bandage if tail[0] < 0.2 else navy, Vector3(tail[0], 0.8, -0.24), Vector3(0, 0, tail[1]))
	_tatters("legs", 1.0, 0.33, 0.24, [navy, bandage, navy, navy_dark], 20, Vector2(0.42, 0.62), 421)
	# A wrapped waist and spine, the ribcage over dark cloth.
	_on("spine", _box(Vector3(0.36, 0.26, 0.26)), navy_dark, Vector3(0, 1.15, 0.01))
	for i in 3:
		_on("spine", _box(Vector3(0.37, 0.035, 0.27)), navy if i % 2 == 0 else bandage, Vector3(0, 1.07 + i * 0.08, 0.01))
	_on("chest", _box(Vector3(0.42, 0.34, 0.26)), dark, Vector3(0, 1.45, 0.02))
	_on("chest", _box(Vector3(0.05, 0.3, 0.05)), bone, Vector3(0, 1.45, -0.13))
	for i in 5:
		var y := 1.32 + i * 0.065
		var w := 0.2 - absf(i - 2.5) * 0.015
		for side: float in [-1.0, 1.0]:
			_on("chest", _box(Vector3(w * 0.85, 0.032, 0.045)), bone, Vector3(w * 0.5 * side, y, -0.13), Vector3(0, 0, -0.18 * side))
			_on("chest", _box(Vector3(0.04, 0.032, 0.24)), bone_old, Vector3(w * side, y - 0.02, 0.0))
	_on("chest", _box(Vector3(0.44, 0.3, 0.06)), navy, Vector3(0, 1.45, 0.16))
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_on("chest", _box(Vector3(0.24, 0.05, 0.06)), bone, Vector3(0.14 * side, 1.62, -0.1), Vector3(0, 0, -0.15 * side))
		_on("clavicle" + s, _box(Vector3(0.2, 0.18, 0.24)), navy, Vector3(0.36 * side, 1.46, 0))
		_on("clavicle" + s, _box(Vector3(0.21, 0.05, 0.25)), bandage, Vector3(0.36 * side, 1.41, 0))
		_flame_stack(_rig.bone("clavicle" + s), Vector3(0.02 * side, 0.1, 0.02), 0.1, flame)
	# The neck stump burns; the skull floats above it.
	_on("neck", _box(Vector3(0.3, 0.1, 0.28)), navy, Vector3(0, 1.64, 0))
	_on("neck", _box(Vector3(0.14, 0.06, 0.14)), dark, Vector3(0, 1.7, 0))
	_flame_stack(_rig.bone("neck"), Vector3(0, 0.02, 0), 0.13, flame)
	# Floating just over the neck stump's flame (it used to sit down in the chest).
	_float_head = _skull(_rig.bone("neck"), Vector3(0, 0.44, -0.02), 0.3, bone, dark, eyes)
	# Its resting height, for the bob (set here: _animate runs before the
	# deferred _finish_look, and a base of 0 sank it into the chest).
	_float_base = _float_head.position.y
	_flame_stack(_float_head, Vector3(0, 0.18, 0.05), 0.12, flame)
	for arm in ["left", "right"]:
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _sphere(0.07), bone, Vector3.ZERO)
		_at("upper_arm" + s, _box(Vector3(0.13, 0.28, 0.13)), bandage, Vector3(0, -0.17, 0))
		_at("upper_arm" + s, _box(Vector3(0.135, 0.05, 0.135)), navy, Vector3(0, -0.1, 0))
		_at("forearm" + s, _box(Vector3(0.09, 0.07, 0.09)), bone, Vector3(0, 0.0, 0))
		_at("forearm" + s, _box(Vector3(0.14, 0.26, 0.14)), bandage, Vector3(0, -0.15, 0))
		for k in 3:
			_at("forearm" + s, _box(Vector3(0.145, 0.03, 0.145)), navy, Vector3(0, -0.07 - k * 0.08, 0))
		_fist(arm, Vector3(0.18, 0.16, 0.18))


## Sister Southpaw, from her portrait: a torn black habit with a ragged
## violet-glowing hem, the white band across the brow, the veil, long dark
## hair, pale skin and violet eyes, a gold chain at the throat, bandaged
## forearms and fists, dark stockings with wrapped knees. A southpaw stance.
func _build_southpaw() -> void:
	var habit := _material(Color(0.1, 0.07, 0.12))
	var habit_light := _material(Color(0.18, 0.13, 0.2))
	var violet := _material(Color(0.36, 0.14, 0.52))
	var glow := _glow_material(Color(0.62, 0.25, 0.95))
	glow.emission_energy_multiplier = 0.9
	var white := _material(Color(0.9, 0.88, 0.86))
	var skin := _material(Color(0.84, 0.76, 0.78))
	var hair := _material(Color(0.1, 0.06, 0.12))
	var gold := _material(Color(0.88, 0.66, 0.24), 0.7)
	var dark := _material(Color(0.05, 0.03, 0.06))
	var eyes := _glow_material(Color(0.8, 0.45, 1.0))
	_rig_body(SHAPES[2], Color(0.86, 0.82, 0.88))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.14 * side
		_on("foot" + s, _box(Vector3(0.15, 0.1, 0.26)), dark, Vector3(x, 0.05, -0.03))
		_on("shin" + s, _box(Vector3(0.13, 0.34, 0.14)), habit, Vector3(x, 0.3, 0))
		_on("shin" + s, _box(Vector3(0.145, 0.06, 0.15)), white, Vector3(x, 0.47, 0))
		_on("thigh" + s, _box(Vector3(0.15, 0.22, 0.16)), skin, Vector3(x, 0.62, 0))
		_on("thigh" + s, _box(Vector3(0.155, 0.05, 0.165)), habit, Vector3(x, 0.55, 0))
	# The habit's skirt, torn at the hem, a few strips glowing violet.
	_on("pelvis", _box(Vector3(0.42, 0.1, 0.3)), dark, Vector3(0, 1.0, 0))
	_tatters("legs", 1.02, 0.28, 0.22, [habit, habit, violet, habit_light, habit, glow], 22, Vector2(0.38, 0.56), 438)
	_on("spine", _box(Vector3(0.36, 0.3, 0.25)), habit, Vector3(0, 1.15, 0))
	_on("chest", _box(Vector3(0.42, 0.3, 0.27)), habit, Vector3(0, 1.4, 0))
	_on("chest", _box(Vector3(0.32, 0.12, 0.06)), habit_light, Vector3(0, 1.39, -0.14))
	_on("chest", _box(Vector3(0.34, 0.07, 0.29)), white, Vector3(0, 1.55, 0))
	_chain_on("chest", Vector3(-0.1, 1.56, -0.15), Vector3(0, 1.43, -0.17), 4, gold)
	_chain_on("chest", Vector3(0.1, 1.56, -0.15), Vector3(0, 1.43, -0.17), 4, gold)
	for side: float in [-1.0, 1.0]:
		_on("clavicle_l" if side < 0.0 else "clavicle_r", _box(Vector3(0.14, 0.12, 0.2)), habit, Vector3(0.26 * side, 1.39, 0))
	# The veil hangs down the back and sways.
	_on("cape", _box(Vector3(0.34, 0.6, 0.04)), habit, Vector3(0, 1.28, 0.17))
	_on("cape", _box(Vector3(0.3, 0.12, 0.045)), violet, Vector3(0, 0.96, 0.17))
	# Face, eyes, lips, the white band, the veil's hood and hair.
	_on("neck", _box(Vector3(0.12, 0.08, 0.12)), white, Vector3(0, 1.6, 0))
	_on("head", _box(Vector3(0.22, 0.26, 0.22)), skin, Vector3(0, 1.69, -0.01))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.06, 0.025, 0.02)), eyes, Vector3(0.05 * side, 1.71, -0.122))
		_on("head", _box(Vector3(0.07, 0.015, 0.02)), dark, Vector3(0.05 * side, 1.74, -0.122), Vector3(0, 0, 0.2 * side))
		_on("head", _box(Vector3(0.05, 0.38, 0.27)), habit, Vector3(0.14 * side, 1.68, 0.03))
		_on("head", _box(Vector3(0.05, 0.36, 0.06)), hair, Vector3(0.1 * side, 1.6, -0.09))
	_on("head", _box(Vector3(0.07, 0.02, 0.02)), dark, Vector3(0, 1.615, -0.122))
	_on("head", _box(Vector3(0.27, 0.06, 0.25)), white, Vector3(0, 1.8, -0.01))
	_on("head", _box(Vector3(0.32, 0.1, 0.3)), habit, Vector3(0, 1.87, 0.01))
	_on("head", _box(Vector3(0.28, 0.4, 0.05)), hair, Vector3(0, 1.62, 0.13))
	for arm in ["left", "right"]:
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _box(Vector3(0.14, 0.17, 0.14)), habit, Vector3(0, -0.08, 0))
		_at("upper_arm" + s, _box(Vector3(0.15, 0.04, 0.15)), violet, Vector3(0, -0.17, 0))
		_at("upper_arm" + s, _box(Vector3(0.09, 0.15, 0.09)), skin, Vector3(0, -0.24, 0))
		_at("forearm" + s, _box(Vector3(0.11, 0.26, 0.11)), white, Vector3(0, -0.14, 0))
		for k in 2:
			_at("forearm" + s, _box(Vector3(0.115, 0.025, 0.115)), habit_light, Vector3(0, -0.08 - k * 0.1, 0))
		_fist(arm, Vector3(0.14, 0.13, 0.14))


## The Plague Doctor, from his portrait: a long, mossy, tattered hooded
## coat, a bone-white beak mask with glowing green lenses, a mantle and
## strap, a belt of glowing vials, a pouch and a flask, wrapped forearms
## with rusty bands, and dark gloves.
func _build_plague_doctor() -> void:
	var coat := _material(Color(0.22, 0.22, 0.18))
	var coat_dark := _material(Color(0.12, 0.13, 0.1))
	var moss := _material(Color(0.24, 0.3, 0.14))
	var beak := _material(Color(0.86, 0.8, 0.64))
	var leather := _material(Color(0.32, 0.2, 0.11))
	var wrap := _material(Color(0.78, 0.74, 0.64))
	var rust := _material(Color(0.42, 0.22, 0.12))
	var brass := _material(Color(0.62, 0.5, 0.25), 0.7)
	var dark := _material(Color(0.03, 0.04, 0.03))
	var potion := _glow_material(Color(0.35, 1.0, 0.4))
	var lenses := _glow_material(Color(0.45, 1.0, 0.45))
	_rig_body(SHAPES[3], Color(0.1, 0.12, 0.08))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.15 * side
		_on("foot" + s, _box(Vector3(0.17, 0.1, 0.28)), leather, Vector3(x, 0.05, -0.03))
		_on("shin" + s, _box(Vector3(0.15, 0.1, 0.16)), leather, Vector3(x, 0.15, 0))
		_on("shin" + s, _box(Vector3(0.14, 0.32, 0.15)), coat_dark, Vector3(x, 0.32, 0))
		_on("thigh" + s, _box(Vector3(0.17, 0.36, 0.18)), coat_dark, Vector3(x, 0.72, 0))
	# The long coat's tails, down near the floor.
	_tatters("legs", 1.0, 0.32, 0.25, [coat, coat_dark, moss, coat], 22, Vector2(0.62, 0.8), 455)
	# The belt: buckle, vials and corks, a pouch and a flask.
	_on("pelvis", _box(Vector3(0.6, 0.09, 0.4)), leather, Vector3(0, 1.0, 0))
	_on("pelvis", _box(Vector3(0.09, 0.08, 0.03)), brass, Vector3(0, 1.0, -0.21))
	for i in 5:
		var x := -0.25 + i * 0.1 + (0.06 if i >= 3 else 0.0)
		_on("sash", _box(Vector3(0.05, 0.11, 0.05)), potion, Vector3(x, 0.92, -0.22))
		_on("sash", _box(Vector3(0.03, 0.03, 0.03)), leather, Vector3(x, 0.99, -0.22))
	_on("sash", _box(Vector3(0.16, 0.16, 0.08)), leather, Vector3(0.25, 0.88, -0.12))
	_on("sash", _sphere(0.06), potion, Vector3(-0.26, 0.86, -0.15))
	# The coat over a strap, lapels and brass buttons.
	_on("spine", _box(Vector3(0.52, 0.3, 0.34)), coat, Vector3(0, 1.14, 0))
	_on("chest", _box(Vector3(0.56, 0.32, 0.36)), coat, Vector3(0, 1.42, 0))
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.1, 0.32, 0.03)), coat_dark, Vector3(0.1 * side, 1.38, -0.19), Vector3(0, 0, 0.15 * side))
	for i in 3:
		_on("spine", _box(Vector3(0.03, 0.03, 0.02)), brass, Vector3(-0.04, 1.06 + i * 0.09, -0.18))
	_on("chest", _box(Vector3(0.06, 0.56, 0.03)), leather, Vector3(0.04, 1.36, -0.2), Vector3(0, 0, 0.6))
	_on("chest", _box(Vector3(0.07, 0.07, 0.035)), brass, Vector3(0.04, 1.36, -0.215))
	# The mantle and hood over the shoulders, a tattered cape behind.
	for side: float in [-1.0, 1.0]:
		_on("clavicle_l" if side < 0.0 else "clavicle_r", _box(Vector3(0.24, 0.14, 0.38)), coat_dark, Vector3(0.28 * side, 1.5, 0))
	_on("cape", _box(Vector3(0.6, 0.2, 0.42)), coat_dark, Vector3(0, 1.58, 0.02))
	_on("cape", _box(Vector3(0.54, 0.7, 0.05)), coat, Vector3(0, 1.15, 0.21))
	for i in 5:
		_on("cape", _box(Vector3(0.1, 0.22, 0.05)), coat_dark if i % 2 == 0 else moss, Vector3(-0.22 + i * 0.11, 0.72, 0.21))
	# Hood, mask, lenses and the long beak.
	_on("head", _box(Vector3(0.36, 0.38, 0.36)), coat_dark, Vector3(0, 1.74, 0.03))
	_on("head", _box(Vector3(0.3, 0.12, 0.3)), coat_dark, Vector3(0, 1.94, 0.06), Vector3(-0.25, 0, 0))
	_on("head", _box(Vector3(0.38, 0.06, 0.05)), coat, Vector3(0, 1.9, -0.15))
	_on("head", _box(Vector3(0.26, 0.26, 0.06)), beak, Vector3(0, 1.71, -0.13))
	for side: float in [-1.0, 1.0]:
		_on("head", _box(Vector3(0.09, 0.09, 0.03)), dark, Vector3(0.065 * side, 1.75, -0.165))
		_on("head", _box(Vector3(0.06, 0.06, 0.03)), lenses, Vector3(0.065 * side, 1.75, -0.18))
	_on("head", _box(Vector3(0.16, 0.14, 0.24)), beak, Vector3(0, 1.65, -0.27), Vector3(0.3, 0, 0))
	_on("head", _box(Vector3(0.11, 0.1, 0.22)), beak, Vector3(0, 1.57, -0.44), Vector3(0.45, 0, 0))
	_on("head", _box(Vector3(0.07, 0.07, 0.12)), beak, Vector3(0, 1.5, -0.57), Vector3(0.65, 0, 0))
	_on("head", _box(Vector3(0.02, 0.02, 0.2)), dark, Vector3(0, 1.62, -0.36), Vector3(0.35, 0, 0))
	for arm in ["left", "right"]:
		var s := "_l" if arm == "left" else "_r"
		_at("upper_arm" + s, _box(Vector3(0.16, 0.3, 0.16)), coat, Vector3(0, -0.16, 0))
		_at("forearm" + s, _box(Vector3(0.19, 0.1, 0.19)), coat_dark, Vector3(0, -0.04, 0))
		_at("forearm" + s, _box(Vector3(0.13, 0.22, 0.13)), wrap, Vector3(0, -0.18, 0))
		for k in 3:
			_at("forearm" + s, _box(Vector3(0.135, 0.025, 0.135)), rust, Vector3(0, -0.11 - k * 0.07, 0))
		_fist(arm, Vector3(0.16, 0.15, 0.16))


## The Coffin King, from his portrait: a crowned skull, a red cape with an
## ermine collar, gold chains over a bare ribcage, a gold belt with a skull
## buckle over a red robe and gold-trimmed tabard, bone legs in gold
## greaves, and huge gold gloves with red cuffs.
func _build_coffin_king() -> void:
	var bone := _material(Color(0.86, 0.82, 0.72))
	var bone_old := _material(Color(0.7, 0.66, 0.56))
	var red := _material(Color(0.58, 0.06, 0.07))
	var red_dark := _material(Color(0.32, 0.03, 0.05))
	var white := _material(Color(0.9, 0.87, 0.82))
	var gold := _material(Color(0.95, 0.7, 0.25), 0.8)
	var dark := _material(Color(0.04, 0.02, 0.02))
	var jewels := _glow_material(Color(1.0, 0.12, 0.1))
	var eyes := _glow_material(Color(1.0, 0.2, 0.1))
	_rig_body(SHAPES[4], Color(0.95, 0.7, 0.25))

	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		var x := 0.18 * side
		_on("foot" + s, _box(Vector3(0.2, 0.12, 0.3)), gold, Vector3(x, 0.06, -0.03))
		_on("foot" + s, _box(Vector3(0.19, 0.06, 0.19)), red, Vector3(x, 0.15, 0))
		_on("shin" + s, _box(Vector3(0.1, 0.34, 0.1)), bone, Vector3(x, 0.33, 0))
		_on("shin" + s, _box(Vector3(0.18, 0.12, 0.18)), gold, Vector3(x, 0.24, 0))
		_on("shin" + s, _box(Vector3(0.15, 0.08, 0.13)), gold, Vector3(x, 0.53, -0.02))
		_on("thigh" + s, _box(Vector3(0.11, 0.36, 0.11)), bone_old, Vector3(x, 0.74, 0))
	# The robe's skirt, the gold-trimmed tabard, the belt and its skull.
	_tatters("legs", 1.0, 0.36, 0.26, [red, red_dark, red, gold], 20, Vector2(0.42, 0.62), 472)
	_on("sash", _box(Vector3(0.24, 0.56, 0.04)), red, Vector3(0, 0.72, -0.25))
	for side: float in [-1.0, 1.0]:
		_on("sash", _box(Vector3(0.03, 0.56, 0.045)), gold, Vector3(0.12 * side, 0.72, -0.25))
	_on("sash", _box(Vector3(0.24, 0.04, 0.045)), gold, Vector3(0, 0.45, -0.25))
	_on("sash", _box(Vector3(0.1, 0.14, 0.046)), gold, Vector3(0, 0.66, -0.25))
	_on("pelvis", _box(Vector3(0.66, 0.12, 0.42)), gold, Vector3(0, 1.0, 0))
	_on("pelvis", _box(Vector3(0.67, 0.04, 0.43)), dark, Vector3(0, 1.0, 0))
	_skull(_rig.bone("pelvis"), Vector3(0, 1.0, -0.23) - _rig.rest_origin("pelvis"), 0.17, gold, dark, jewels)
	# The bare spine and ribcage, gold chains draped over it.
	_on("spine", _box(Vector3(0.36, 0.26, 0.24)), dark, Vector3(0, 1.16, 0.04))
	for i in 3:
		_on("spine", _box(Vector3(0.08, 0.06, 0.08)), bone, Vector3(0, 1.08 + i * 0.08, -0.02))
	_on("chest", _box(Vector3(0.48, 0.36, 0.28)), dark, Vector3(0, 1.5, 0.02))
	_on("chest", _box(Vector3(0.06, 0.32, 0.05)), bone, Vector3(0, 1.5, -0.14))
	for i in 5:
		var y := 1.36 + i * 0.07
		var w := 0.23 - absf(i - 2.5) * 0.015
		for side: float in [-1.0, 1.0]:
			_on("chest", _box(Vector3(w * 0.85, 0.035, 0.045)), bone, Vector3(w * 0.5 * side, y, -0.14), Vector3(0, 0, -0.18 * side))
			_on("chest", _box(Vector3(0.045, 0.035, 0.26)), bone_old, Vector3(w * side, y - 0.02, 0.0))
	_chain_on("chest", Vector3(-0.26, 1.66, -0.18), Vector3(0.0, 1.42, -0.2), 6, gold)
	_chain_on("chest", Vector3(0.26, 1.66, -0.18), Vector3(0.0, 1.42, -0.2), 6, gold)
	_chain_on("chest", Vector3(-0.28, 1.54, -0.19), Vector3(0.28, 1.54, -0.19), 9, gold)
	for side: float in [-1.0, 1.0]:
		_on("chest", _box(Vector3(0.08, 0.08, 0.03)), gold, Vector3(0.26 * side, 1.66, -0.19))
	# The cape and its ermine collar, red shoulders trimmed in fur.
	_on("cape", _box(Vector3(0.9, 1.25, 0.06)), red, Vector3(0, 1.08, 0.26))
	_on("cape", _box(Vector3(0.86, 1.2, 0.02)), red_dark, Vector3(0, 1.1, 0.225))
	for i in 6:
		_on("cape", _box(Vector3(0.14, 0.26, 0.06)), red if i % 2 == 0 else red_dark, Vector3(-0.36 + i * 0.145, 0.36, 0.26))
	_on("chest", _box(Vector3(0.76, 0.14, 0.2)), white, Vector3(0, 1.72, 0.14))
	for side: float in [-1.0, 1.0]:
		var s := "_l" if side < 0.0 else "_r"
		_on("chest", _box(Vector3(0.18, 0.14, 0.34)), white, Vector3(0.27 * side, 1.7, 0.0))
		_on("clavicle" + s, _box(Vector3(0.28, 0.2, 0.34)), red, Vector3(0.42 * side, 1.56, 0))
		_on("clavicle" + s, _box(Vector3(0.3, 0.06, 0.36)), white, Vector3(0.42 * side, 1.46, 0))
		for k in 3:
			_on("chest", _box(Vector3(0.03, 0.03, 0.02)), dark, Vector3((0.18 + k * 0.12) * side, 1.74 - (k % 2) * 0.04, 0.03 - k * 0.06))
	# The crowned skull: a red cap and a ring of gold spikes with jewels.
	var head := _skull(_rig.bone("head"), Vector3(0, 1.84, -0.02) - _rig.rest_origin("head"), 0.32, bone, dark, eyes)
	_part(head, _box(Vector3(0.3, 0.08, 0.3)), red, Vector3(0, 0.17, 0))
	var crown_y := 0.2
	for side: float in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.36, 0.08, 0.04)), gold, Vector3(0, crown_y, 0.165 * side))
		_part(head, _box(Vector3(0.04, 0.08, 0.36)), gold, Vector3(0.165 * side, crown_y, 0))
	for i in 5:
		var x := -0.14 + i * 0.07
		var tall := 0.17 if i == 2 else (0.13 if i % 2 == 0 else 0.1)
		_part(head, _box(Vector3(0.045, tall, 0.045)), gold, Vector3(x, crown_y + 0.04 + tall / 2.0, -0.165))
		_part(head, _box(Vector3(0.045, tall * 0.8, 0.045)), gold, Vector3(x, crown_y + 0.04 + tall * 0.4, 0.165))
		_part(head, _box(Vector3(0.03, 0.03, 0.02)), jewels, Vector3(x, crown_y, -0.19))
	for side: float in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.045, 0.12, 0.045)), gold, Vector3(0.165 * side, crown_y + 0.1, 0))
	for arm in ["left", "right"]:
		var s := "_l" if arm == "left" else "_r"
		var hand := "hand" + s
		_at("upper_arm" + s, _box(Vector3(0.17, 0.3, 0.17)), red, Vector3(0, -0.16, 0))
		_at("forearm" + s, _box(Vector3(0.19, 0.08, 0.19)), white, Vector3(0, -0.02, 0))
		_at("forearm" + s, _box(Vector3(0.15, 0.22, 0.15)), red, Vector3(0, -0.16, 0))
		_fist(arm, Vector3(0.28, 0.24, 0.28))
		_at(hand, _box(Vector3(0.27, 0.06, 0.27)), red, Vector3(0, -0.01, 0))
		_at(hand, _box(Vector3(0.28, 0.03, 0.28)), white, Vector3(0, 0.03, 0))


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


## Ghost-fire: a few glowing blocks stacked and staggered upward.
func _flame_stack(parent: Node3D, base: Vector3, size: float, material: Material) -> void:
	for i in 4:
		var s := size * (1.0 - i * 0.2)
		var jitter := Vector3((i % 2) * 0.3 - 0.15, 0, ((i + 1) % 2) * 0.2 - 0.1) * size
		_part(parent, _box(Vector3(s, s * 1.3, s)), material, base + Vector3(0, i * size * 0.9, 0) + jitter, Vector3(0, i * 0.4, 0))


## After voxelizing: the accent rim glow on every part, wisps rising off the
## body, and a light of the boss's color.
func _finish_look() -> void:
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
	if _rig:
		_rig.play("slip_left" if side.dot(global_basis.x) < 0.0 else "slip_right", PIVOT_TIME)
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


## The Headless winds up and throws; the Plague Doctor's needle.
func _set_step(step: String) -> void:
	super(step)
	if _rig == null:
		return
	match step:
		"wind":
			_rig.play("toss_load", SKULL_WIND + 0.2)
		"toss":
			_rig.play("toss", 0.5)
		"inject":
			_rig.play("inject", INJECT_TIME)


## The Plague Doctor lands his hop back: then the needle.
func _land() -> void:
	if _special != "adrenaline":
		super()
		return
	collision_mask |= 2
	velocity.y = 0.0
	Sfx.play_at("quake", global_position, -4.0, 0.9)
	_set_step("inject")


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
