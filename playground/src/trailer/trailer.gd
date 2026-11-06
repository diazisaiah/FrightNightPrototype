extends "res://playground/character_lab/key_art.gd"
## Official trailer, part 1 (2026-10-31): the intro of "Ringside Ghosts", cut
## to the song's measured hits (song seconds are trailer seconds):
##   0.00  the hero wakes in the graveyard, weak (heartbeat thumps 0.98, 1.97)
##   5.27  BIG HIT: the Bellman, arms up, the bell tolls; thumps 5.61 5.79 6.05 6.26
##   6.7   monsters claw up out of the graves as it builds
##  14.99  dun-dun-dun-dun-dun: he points, the horde sprints at the hero
##  16.0   the hero doesn't run: he waits for them, gloves up, grinning
##  18.55  the drum fill: Warm Up; 19.86 20.05 20.18 20.39 fill hits
##  20.57  the drop: he snaps into his stance, then first person: slips,
##         counters, knock outs.
## Renders on a fixed clock, so every frame is the same every time:
##   godot --path <project> res://playground/trailer/trailer.tscn --resolution 1920x1080
##         --write-movie out.avi --fixed-fps 30 -- --to=26 [--from=0]
## Everything on screen is the game's own code: bodies, bosses, monsters, fists.

const RevampBodyT = preload("res://fighter_body.gd")
const BossScene := preload("res://dead_league_boss.tscn")
const VIEW := Vector2i(1920, 1080)
const FPS := 30.0
const PLAYER_AT := Vector3(0, 0, -12)
const BELL_AT := Vector3(0, 0, 7.2)
const HERO := "counter_master"
const HERO_COLOR := Color(0.35, 0.7, 1.0)
## Close-up monsters, one per cut of the rise: [x, z, kind, rise time].
const FEATURE := [
	[-2.0, 4.2, "zombie", 6.85], [2.4, 5.2, "skeleton", 7.5], [-3.6, 6.2, "zombie", 8.15],
	[3.4, 3.4, "brawler", 8.8], [0.9, 3.6, "zombie", 9.45],
]
const KINDS := ["zombie", "skeleton", "zombie", "brawler", "skeleton", "bruiser", "zombie", "wraith"]
## Hits that shake the camera.
const BEATS := [5.27, 5.61, 5.79, 6.05, 6.26, 14.99, 15.35, 15.51, 15.66, 15.98, 19.86, 20.05, 20.18, 20.39, 20.57]

const EYE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float lid = 1.0;
uniform float blur = 0.0;
uniform float pulse = 0.0;
uniform float fade = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen, uv, blur * 4.0).rgb;
	vec3 c2 = textureLod(screen, uv + vec2(blur * 0.014, blur * 0.004), blur * 4.0).rgb;
	c = mix(c, c2, 0.5 * min(blur, 1.0));
	float d = abs(uv.y - 0.5);
	float edge = lid * 0.55 * (1.0 - 0.5 * pow(abs(uv.x - 0.5) * 2.0, 2.0));
	float m = 1.0 - smoothstep(edge - 0.05, edge, d);
	float r = length((uv - 0.5) * vec2(1.3, 1.0));
	c = mix(c, vec3(0.55, 0.0, 0.02), pulse * smoothstep(0.25, 0.8, r));
	COLOR = vec4(c * m * (1.0 - fade), 1.0);
}
"""

const IMPACT_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float lines = 0.0;
uniform float split = 0.0;
uniform float tint_a = 0.0;
uniform vec3 tint = vec3(0.4, 0.7, 1.0);
uniform float seed = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = length(d * vec2(1.78, 1.0));
	vec2 off = normalize(d + vec2(0.00001)) * split * r;
	vec3 c = vec3(texture(screen, uv + off).r, texture(screen, uv).g, texture(screen, uv - off).b);
	float ang = atan(d.y, d.x);
	float ray = step(0.55, hash(floor(ang * 36.0) + seed));
	float streak = ray * smoothstep(0.22, 0.85, r) * lines;
	c = mix(c, vec3(1.0), streak);
	c = mix(c, tint, tint_a * smoothstep(0.15, 0.9, r));
	COLOR = vec4(c, 1.0);
}
"""

var _clock := 0.0
var _end := 26.0
var _frame := 0
var _shot := -1
var _eye: ColorRect
var _eye_mat: ShaderMaterial
var _flash_rect: ColorRect
var _impact_mat: ShaderMaterial
var _imp_kind := ""
var _imp_time := -10.0
var _imp_seed := 0.0
var _last_dodge := -10.0
var _ko_fx: Array = []
var _bell: Node3D
var _rig: BossRig
var _hero: Node3D
var _fists: Fists
var _mobs: Array = []
var _hero_light: SpotLight3D
var _fight: Array = []
var _banner: Label
var _jolts: Array = []
var _aura: Array = []
var _aura_frame := -1
var _aura_eyes: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--to="):
			_end = float(arg.substr(5))
		elif arg.begins_with("--from="):
			_clock = float(arg.substr(7))
	_view = SubViewport.new()
	_view.size = VIEW
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var layer := CanvasLayer.new()
	add_child(layer)
	var shown := TextureRect.new()
	shown.texture = _view.get_texture()
	shown.set_anchors_preset(Control.PRESET_FULL_RECT)
	shown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shown.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(shown)
	_eye = ColorRect.new()
	_eye.set_anchors_preset(Control.PRESET_FULL_RECT)
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = Shader.new()
	_eye_mat.shader.code = EYE_SHADER
	_eye.material = _eye_mat
	layer.add_child(_eye)
	var impact := ColorRect.new()
	impact.set_anchors_preset(Control.PRESET_FULL_RECT)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_impact_mat = ShaderMaterial.new()
	_impact_mat.shader = Shader.new()
	_impact_mat.shader.code = IMPACT_SHADER
	impact.material = _impact_mat
	layer.add_child(impact)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash_rect)
	_world = Node3D.new()
	_view.add_child(_world)
	_build_set()
	for spot: Vector3 in [Vector3(-3.6, 0, -9.2), Vector3(3.6, 0, -9.2), Vector3(-5.5, 0, -14.5), Vector3(5.5, 0, -14.5)]:
		_torch(spot)
	_make_floor()
	_hero_ground()
	_hero_light = SpotLight3D.new()
	_hero_light.light_color = Color(0.7, 0.85, 1.0)
	_hero_light.light_energy = 0.0
	_hero_light.spot_range = 14.0
	_hero_light.spot_angle = 35.0
	_hero_light.position = PLAYER_AT + Vector3(0, 7.0, -3.0)
	_hero_light.rotation_degrees = Vector3(-72, 0, 0)
	_hero_light.shadow_enabled = true
	_world.add_child(_hero_light)
	_make_hero()
	_make_player()
	_make_bellman()
	_make_mobs()
	_fists = Fists.new()
	_fists.fighter = HERO
	_camera.add_child(_fists)
	_fists.visible = false
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.visible = false
	layer.add_child(_banner)
	_direct(_clock)


func _monsters() -> void:
	pass


## The hero's end of the graveyard: a longer field, graves round the edges
## (the middle kept clear to fight in), grass, dead trees, mist.
func _hero_ground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var far := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	plane.material = Look.block_material(Color(0.09, 0.085, 0.1))
	far.mesh = plane
	far.position.y = -0.03
	_world.add_child(far)
	var here := Node3D.new()
	here.position = PLAYER_AT
	_world.add_child(here)
	Scenery.ground_patches(here, 14.0, 30, rng)
	Scenery.grass(here, 14.0, 260, rng, 3.5)
	for i in 34:
		var x := rng.randf_range(-16.0, 16.0)
		var z := rng.randf_range(-9.0, 9.0)
		if Vector2(x, z).length() < 6.0:
			continue
		var grave := Scenery.gravestone(_world, [0, 2, 3, 5][rng.randi_range(0, 3)], rng)
		grave.position = PLAYER_AT + Vector3(x, 0, z)
		grave.rotation.y = rng.randf_range(-0.4, 0.4)
	for spot: Vector3 in [Vector3(-9, 0, -4), Vector3(10, 0, 3), Vector3(-11, 0, 8)]:
		Scenery.dead_tree(_world, rng, 6.5).position = PLAYER_AT + spot
	var mist := Scenery.mist(_world, PLAYER_AT + Vector3(0, 0.3, 4.0), Vector3(14, 0.35, 10), 90)
	mist.preprocess = 16.0


func _process(delta: float) -> void:
	_clock += 1.0 / FPS
	_frame += 1
	_direct(_clock)
	if _clock >= _end:
		print("fp total: thrown %d landed %d" % [_thrown, _landed])
		get_tree().quit()


# --- Cast ---------------------------------------------------------------------------------

func _make_hero() -> void:
	_hero = RevampBodyT.new(HERO, "")
	_hero.voxel_scale = "large"
	_hero.build_budget_ms = 100000
	_hero.position = PLAYER_AT
	_hero.rotation.y = PI
	_world.add_child(_hero)
	_hero.finish_build()
	_hero.wear_hat("")
	_hero.visible = false


func _make_bellman() -> void:
	_bell = BossScene.instantiate() as DeadLeagueBoss
	_bell.configure(0, 3)
	_bell.setup(null, false)
	_bell.position = BELL_AT + Vector3(0, 0.12, 0)
	_world.add_child(_bell)
	for i in 8:
		await get_tree().process_frame
	_bell.set_physics_process(false)
	_bell.set_process(false)
	_rig = _bell._rig
	_rig.set_motion(Vector3.ZERO, _bell.global_basis, true)
	_rig.advance(0.0)
	var low := INF
	for geometry in _bell.find_children("*", "GeometryInstance3D", true, false):
		var box: AABB = (geometry as GeometryInstance3D).global_transform * (geometry as GeometryInstance3D).get_aabb()
		low = minf(low, box.position.y)
	if low < INF:
		_bell.position.y += 0.12 - low
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.35, 0.15)
	glow.light_energy = 3.0
	glow.omni_range = 7.0
	glow.position = BELL_AT + Vector3(0, 2.4, -2.0)
	_world.add_child(glow)


func _make_mobs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for f in FEATURE.size():
		var spec: Array = FEATURE[f]
		_add_mob(spec[2], Vector3(spec[0], 0, spec[1]), spec[3], 15.5 + f * 0.04, rng)
	for i in 46:
		var spot := Vector3(rng.randf_range(-15.0, 15.0), 0, rng.randf_range(2.0, 22.0))
		if Vector2(spot.x - BELL_AT.x, spot.z - BELL_AT.z).length() < 2.6:
			spot.x += 3.4
		var rise := 6.6 + 8.0 * pow(rng.randf(), 1.3)
		_add_mob(KINDS[i % KINDS.size()], spot, rise, 15.55 + rng.randf() * 0.5, rng)


func _add_mob(kind: String, spot: Vector3, rise: float, charge: float, rng: RandomNumberGenerator) -> void:
	var monster: Enemy = load("res://%s.tscn" % kind).instantiate()
	monster.setup(null, false, {"hat": ""})
	monster.scale = Vector3.ONE * 1.1
	monster.visible = false
	monster.position = spot
	_world.add_child(monster)
	monster.set_physics_process(false)
	monster.set_process(false)
	monster.remove_from_group("enemies")
	var angle := rng.randf_range(-1.25, 1.25)
	var radius := rng.randf_range(5.5, 10.5)
	_mobs.append({
		"node": monster, "spot": spot, "rise": rise, "charge": charge, "angle": angle, "radius": radius,
		"speed": rng.randf_range(4.2, 6.0), "dirt": false, "turn": rng.randf_range(-0.6, 0.6),
		"phase": rng.randf_range(0.0, TAU),
	})


func _update_mobs(t: float) -> void:
	for mob in _mobs:
		var node: Enemy = mob.node
		if t < mob.rise:
			node.visible = false
			continue
		node.visible = true
		if not mob.dirt:
			mob.dirt = true
			HitFx.burst(_world, mob.spot + Vector3(0, 0.1, 0), Vector3.UP, Color(0.18, 0.14, 0.11), 6, 1.6, false, 0.06)
		var u := clampf((t - mob.rise) / 0.9, 0.0, 1.0)
		var lift := 1.0 - pow(1.0 - u, 3.0)
		var speed := 0.0
		if t >= mob.charge:
			# They close in on him (the crowd tightens as the fight goes on), and
			# once there they keep shuffling, swaying and pressing in.
			var squeeze := lerpf(1.0, 0.68, clampf((t - 19.0) / 7.0, 0.0, 1.0))
			var stop: Vector3 = PLAYER_AT + Vector3(sin(mob.angle), 0, cos(mob.angle)) * mob.radius * squeeze
			var heading: Vector3 = stop - mob.spot
			var length := heading.length()
			var run: float = minf((t - mob.charge) * mob.speed, length)
			node.position = mob.spot + heading.normalized() * run
			if run >= length - 0.05:
				var sway := Vector3(sin(t * 1.3 + mob.phase), 0, cos(t * 0.9 + mob.phase * 1.7)) * 0.55
				node.position += sway
				var at: Vector3 = PLAYER_AT - node.position
				node.rotation.y = atan2(-at.x, -at.z) + sin(t * 2.0 + mob.phase) * 0.25
				speed = 2.2
			else:
				node.rotation.y = atan2(-heading.x, -heading.z)
				speed = mob.speed
		else:
			node.position = mob.spot
			# They turn to the hero on the second dun.
			if t >= 15.35:
				var at2: Vector3 = PLAYER_AT - mob.spot
				node.rotation.y = atan2(-at2.x, -at2.z)
			else:
				node.rotation.y = mob.turn
		node.position.y = -2.6 * (1.0 - lift)
		node._animate(1.0 / FPS, speed)


# --- The camera -----------------------------------------------------------------------------

func _cam(pos: Vector3, target: Vector3, fov := 55.0, roll := 0.0, shake := 1.0) -> void:
	_camera.fov = fov
	var jolt := 0.0
	for beat: float in BEATS + _jolts:
		if _clock >= beat and _clock - beat < 0.5:
			jolt += exp(-(_clock - beat) * 9.0)
	jolt *= 0.06 * shake
	var wobble := Vector3(sin(_frame * 2.1), cos(_frame * 2.9), sin(_frame * 1.7)) * jolt
	_camera.position = pos + wobble
	var up := Vector3.UP
	_camera.look_at(target + wobble, up)
	if roll != 0.0:
		_camera.rotate_object_local(Vector3(0, 0, 1), roll)


func _flash(color: Color, strength: float) -> void:
	_flash_rect.color = Color(color, strength)


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _bell_pose(t: float) -> void:
	if _rig == null:
		return
	_rig.set_motion(Vector3.ZERO, _bell.global_basis, true)
	var raise := 0.0
	if t >= 5.27 and t < 14.9:
		raise = 0.7 * clampf((t - 5.27) / 0.2, 0.0, 1.0)
	elif t < 5.27:
		raise = 0.0
	_rig.play("slam_load", 1.0, "", 0.5, raise)
	_rig.advance(1.0 / FPS)
	if t >= 14.95:
		# Pointing at the hero: the right arm snaps out straight, the left drops.
		var snap := clampf((t - 14.95) / 0.07, 0.0, 1.0)
		_rig.play("slam_load", 1.0, "", 0.5, 0.0)
		_rig.advance(0.0)
		_rig._set_rot("upper_arm_r", Vector3(1.5, -0.05, 0.02), snap)
		_rig._set_rot("forearm_r", Vector3(0.02, 0, 0), snap)
		_rig._add_rot("chest", Vector3(-0.05 * snap, -0.1 * snap, 0))
		_rig._set_rot("upper_arm_l", Vector3(0.2, 0.0, -0.5), snap)


const POSE_AT := 20.57                    # the drop: he lands in the fight pose
const WARM_FREEZE := 5.6                  # (Warm Up's own time at the landing)
const WARM_START := POSE_AT - WARM_FREEZE
const AURA_START := WARM_START + 5.3      # the aura comes in with the jump
const FP_START := POSE_AT + 1.0           # one second of pose, then first person
const CAM_AURA := 18.5                    # the jump is coming: the cameras change
var _emote_on := false
var _warm_clip: Dictionary
var _frozen: Dictionary


func _hero_pose(t: float) -> void:
	_hero.visible = t >= 11.0 and t < FP_START
	if t < WARM_START:
		return
	if not _emote_on:
		_emote_on = true
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://emotes/warm_up.json"))
		data["loop"] = false
		_warm_clip = Emotes.parse(data)
		_frozen = Emotes.sample(_warm_clip, WARM_FREEZE)
		_hero.play_clip(_warm_clip, minf(t - WARM_START, WARM_FREEZE))
	if t >= POSE_AT:
		# Landed: held perfectly still in the pose for a second.
		_hero.set_process(false)
		_hero._apply(_frozen)
	if t >= AURA_START:
		_aura_update(1.0, t)


## The Answer's aura (key art's: glowing eyes, his blue light, lightning arcs
## that re-roll every few frames so they crackle).
func _aura_update(flare: float, t: float) -> void:
	if t >= FP_START:
		for node in _aura:
			if is_instance_valid(node):
				node.visible = false
		return
	var step := _frame / 3
	if step == _aura_frame:
		return
	_aura_frame = step
	for node in _aura:
		if is_instance_valid(node):
			node.queue_free()
	_aura.clear()
	var before := _cast.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = step
	var at := PLAYER_AT
	_lightning(at, 1.0, HERO_COLOR, rng)
	_lightning(at + Vector3(0, 0.15, 0), 1.15, HERO_COLOR, rng)
	_glints(at, 1.0, HERO_COLOR, rng)
	for i in range(before, _cast.size()):
		_aura.append(_cast[i])
	if _aura_eyes == null:
		_eyes(_hero, HERO_COLOR)
		_aura_eyes = _cast[_cast.size() - 1]
		for spot: Vector3 in [Vector3(0.7, 1.7, 1.0), Vector3(0, 0.3, -0.4)]:
			var light := OmniLight3D.new()
			light.light_color = HERO_COLOR
			light.light_energy = 5.0
			light.omni_range = 3.0
			light.position = at + spot
			_world.add_child(light)
	_flash(HERO_COLOR, 0.0)


# --- The cut --------------------------------------------------------------------------------

## One function is the whole edit: it reads the clock and sets up the camera.
func _direct(t: float) -> void:
	_bell_pose(t)
	_update_mobs(t)
	_update_impact(t)
	_hero_pose(t)
	_fists.visible = t < 5.27
	_flash_rect.color.a = maxf(0.0, _flash_rect.color.a - 0.09)
	_hero_light.light_energy = clampf((t - 18.5) / 2.0, 0.0, 1.0) * 6.0
	_set_eye(3.0, 0.0, 0.0, 0.0)
	var fighting := t >= FP_START
	if fighting != _fp_on:
		_fp_on = fighting
		_player.visible = fighting
		_hud.visible = fighting
		_player.active = fighting
		_player.set_process(fighting)
		_player.set_physics_process(fighting)
		if fighting:
			_player._camera.make_current()
		else:
			_camera.make_current()
	if t < 5.27:
		_wake(t)
	elif t < 6.87:
		_bell_hits(t)
	elif t < 10.14:
		_rise(t)
	elif t < 14.99:
		_build(t)
	elif t < 16.0:
		_point(t)
	elif t < CAM_AURA:
		_charge(t)
	elif t < POSE_AT:
		_warm_up(t)
	else:
		_stance(t)


func _set_eye(lid: float, blur: float, pulse: float, fade: float) -> void:
	_eye_mat.set_shader_parameter("lid", lid)
	_eye_mat.set_shader_parameter("blur", blur)
	_eye_mat.set_shader_parameter("pulse", pulse)
	_eye_mat.set_shader_parameter("fade", fade)


## 0 - 5.27: opening your eyes on the heartbeat, too weak to stand.
func _wake(t: float) -> void:
	var lid := 0.0
	if t < 0.95:
		lid = 0.0
	elif t < 1.5:
		lid = 0.22 * _ease(clampf((t - 0.98) / 0.12, 0.0, 1.0)) * (1.0 - _ease(clampf((t - 1.3) / 0.2, 0.0, 1.0)))
	elif t < 2.7:
		lid = 0.55 * _ease(clampf((t - 1.97) / 0.15, 0.0, 1.0)) * (1.0 - 0.7 * _ease(clampf((t - 2.3) / 0.35, 0.0, 1.0)))
	else:
		lid = _ease(clampf((t - 2.8) / 0.9, 0.0, 1.0)) * 2.2
		if t > 3.95 and t < 4.25:
			lid *= 1.0 - sin((t - 3.95) / 0.3 * PI) * 0.75
	var blur := lerpf(1.0, 0.12, _ease(clampf((t - 1.0) / 3.8, 0.0, 1.0)))
	var pulse := 0.0
	for beat: float in [0.98, 1.97]:
		if t >= beat:
			pulse = maxf(pulse, 0.9 * exp(-(t - beat) * 4.5))
	if t >= 2.6:
		var phase := fmod(t - 2.6, 0.654)
		pulse = maxf(pulse, 0.7 * exp(-phase * 6.0))
	_set_eye(lid, blur, pulse, 0.0)
	_hero.visible = false
	# Flat on your back among the graves, the moon above, then pushing up.
	var rise := _ease(clampf((t - 3.0) / 1.8, 0.0, 1.0))
	var sway := sin(t * 1.6) * 0.1 + sin(t * 4.1) * 0.03
	var pos := PLAYER_AT + Vector3(0.3, lerpf(0.28, 1.5, rise), 0.0)
	var look := Vector3(-3.0, lerpf(14.0, 1.7, rise), PLAYER_AT.z + lerpf(2.0, 30.0, rise))
	if t > 4.6:
		look = Vector3(0, 1.0 + 5.0 * _ease(clampf((t - 4.6) / 0.6, 0.0, 1.0)), 30.0)
	_cam(pos, look, 62.0, sway * (1.0 - rise * 0.6), 0.0)
	_fists.visible = rise > 0.2
	_fists.drop = 0.18 * (1.0 - rise * 0.3)
	_fists.position = Vector3(sin(t * 9.0), cos(t * 11.0), 0) * 0.006
	_flash(Color(1, 1, 1), 0.0)


## 5.27 - 6.87: BONG. The Bellman, arms thrown up, on every thump.
func _bell_hits(t: float) -> void:
	_fists.visible = false
	var from := BELL_AT
	if t < 5.79:
		var u := (t - 5.27) / 0.52
		_cam(Vector3(0.2, 0.35, 3.4 + 0.9 * u), from + Vector3(0, 2.2, 0), 62.0, -0.05)
		if t < 5.33:
			_flash(Color(1, 0.85, 0.7), 0.9)
	elif t < 6.26:
		var u := (t - 5.79) / 0.47
		_cam(Vector3(1.5, 1.2, 5.4 - 0.3 * u), from + Vector3(0, 3.0, 0), 38.0, 0.08)
	else:
		var u := (t - 6.26) / 0.61
		_cam(Vector3(0.0, lerpf(1.0, 3.6, u), lerpf(2.4, -1.5, u)), from + Vector3(0, 2.4, 0), 55.0)
	for beat: float in [5.27, 5.61, 5.79, 6.05, 6.26]:
		if absf(t - beat) < 0.5 / FPS:
			HitFx.burst(_world, from + Vector3(0, 0.2, -0.8), Vector3.UP, Color(0.22, 0.17, 0.13), 30, 7.0, false, 0.1)
			HitFx.burst(_world, from + Vector3(0, 1.0, -0.5), Vector3.UP, Color(1.0, 0.45, 0.2), 14, 5.0, true, 0.06)


## 6.87 - 10.14: graves split open on every hi-hat tick.
func _rise(t: float) -> void:
	_fists.visible = false
	var cut := clampi(int((t - 6.87) / 1.09), 0, 2)
	var u := fmod(t - 6.87, 1.09) / 1.09
	if cut == 1:
		# Wide, beside the Bellman's raised arms: the field cracking open.
		_cam(BELL_AT + Vector3(1.4 - 0.8 * u, 2.9, -0.8), Vector3(-1.0, 0.5, -6.0), 55.0, 0.03)
	else:
		# Close-up low on a grave: the hand bursts out.
		var spec: Array = FEATURE[0 if cut == 0 else 2]
		var at := Vector3(spec[0], 0, spec[1])
		_cam(at + Vector3(0.6, 0.45, -2.0 + 0.7 * u), at + Vector3(0, 0.9, 0), 52.0, 0.05 * (cut - 1))


## 10.14 - 14.99: the build. Dollies, then the lonely hero, then faster cuts.
func _build(t: float) -> void:
	_fists.visible = false
	if t < 11.35:
		var u := (t - 10.14) / 1.21
		_cam(Vector3(0.0, 0.7, lerpf(-3.0, 3.5, u)), BELL_AT + Vector3(0, 1.8, 0), 62.0)
	elif t < 12.0:
		# Over the Bellman's shoulder: far down the graveyard, one small hero.
		var u := (t - 11.35) / 0.65
		_cam(BELL_AT + Vector3(1.7, 2.7 - 0.2 * u, -0.7), PLAYER_AT + Vector3(0, 1.3, 0), 30.0)
	else:
		# A new angle every beat (he is warming up through all of it).
		var n := int((t - 12.0) / 0.651)
		var u := fmod(t - 12.0, 0.651) / 0.651
		match n % 5:
			0:
				_cam(PLAYER_AT + Vector3(0.0, 1.45, 2.8 - 0.4 * u), PLAYER_AT + Vector3(0, 1.4, 0), 34.0)
			1:
				var spec: Array = FEATURE[1]
				_cam(Vector3(spec[0] + 0.4, 1.4, spec[1] - 1.1 + 0.3 * u), Vector3(spec[0], 1.6, spec[1]), 36.0, 0.1)
			2:
				_cam(BELL_AT + Vector3(0.9 - 0.3 * u, 2.9, -2.0), BELL_AT + Vector3(0, 3.0, 0), 34.0, -0.08)
			3:
				_cam(PLAYER_AT + Vector3(-1.2 + 0.5 * u, 0.5, 2.0), PLAYER_AT + Vector3(0, 0.9, 0), 40.0)
			4:
				_cam(PLAYER_AT + Vector3(0.0, 1.6, 1.8 - 0.4 * u), PLAYER_AT + Vector3(0, 1.58, 0), 24.0)


## 14.99 - 16.0: the dun-dun-dun: he points, they turn, they run.
func _point(t: float) -> void:
	_fists.visible = false
	if t < 15.35:
		_cam(BELL_AT + Vector3(-3.4, 4.2, -3.6 + 0.5 * (t - 14.99) / 0.36), BELL_AT + Vector3(0.0, 2.3, -1.4), 42.0, 0.03)
	elif t < 15.51:
		var spec: Array = FEATURE[0]
		_cam(Vector3(spec[0] + 0.8, 1.45, spec[1] - 1.4), Vector3(spec[0], 1.55, spec[1]), 34.0, -0.06)
	elif t < 15.66:
		var spec: Array = FEATURE[3]
		_cam(Vector3(spec[0] + 0.3, 0.45, spec[1] - 4.0), Vector3(spec[0], 0.8, spec[1]), 58.0, 0.12)
	elif t < 15.98:
		_cam(Vector3(0, 9.0, 0.0), Vector3(0, 0, 8.0), 62.0)
	else:
		_cam(Vector3(0.5, 0.9, 0.5), Vector3(0, 1.0, 9.0), 70.0, 0.04)


## 16.0 - 18.5: no running. He keeps stretching while they pour in on him.
func _charge(t: float) -> void:
	_fists.visible = false
	if t < 17.0:
		var u := (t - 16.0) / 1.0
		_cam(PLAYER_AT + Vector3(0.8, 1.75, -2.2 + 0.4 * u), PLAYER_AT + Vector3(-0.2, 1.4, 6.0), 44.0)
	elif t < 17.75:
		var u := (t - 17.0) / 0.75
		_cam(PLAYER_AT + Vector3(-1.5 + 0.3 * u, 0.6, -1.3), PLAYER_AT + Vector3(1.4, 1.4, 6.0), 46.0, 0.05)
	else:
		var u := (t - 17.75) / 0.75
		_cam(PLAYER_AT + Vector3(-3.0 + 0.4 * u, 1.2, -2.6), PLAYER_AT + Vector3(1.0, 1.2, 3.0), 40.0, 0.03)


## 18.5 - 20.57: stretching, then the jump and the landing in the fight pose.
func _warm_up(t: float) -> void:
	_fists.visible = false
	if t < 19.6:
		var u := (t - 18.5) / 1.1
		_cam(PLAYER_AT + Vector3(2.0 - 0.7 * u, 0.9, 3.6 - 0.9 * u), PLAYER_AT + Vector3(0, 1.15, 0), 38.0, -0.04)
	else:
		var u := (t - 19.6) / 0.97
		_cam(PLAYER_AT + Vector3(-2.4 + 0.6 * u, 1.1, 3.4 - 0.4 * u), PLAYER_AT + Vector3(0, 1.1, 0), 40.0, 0.03)


## 20.57 - 21.57: the drop. He lands in the pose, the aura flares, and he holds
## it for a second before first person.
func _stance(t: float) -> void:
	_fists.visible = false
	var u := t - POSE_AT
	if u < 0.5:
		_cam(PLAYER_AT + Vector3(0.9 - 0.4 * u, 1.0, 3.2 - 0.6 * u), PLAYER_AT + Vector3(0, 1.1, 0), 36.0)
	else:
		_cam(PLAYER_AT + Vector3(0.15, 1.62, 1.5), PLAYER_AT + Vector3(0, 1.62, 0), 24.0)
	if u < 0.06:
		_flash(HERO_COLOR, 0.8)
	if u >= 1.0:
		_fp(t)


# --- First person: the real game ---------------------------------------------------------

## The real Player and real monsters (their own AI, hit boxes, slow-mo, KOs).
## A bot stands in for the hands: it reads each windup, slips or rolls the
## right way at the last moment, then counters (an uppercut off a slip, a hook
## off a roll). Each cut is a new corner of the graveyard.
## foes: [kind, sideways offset, distance].
const FP := [
	# A jab and a cross, both slipped, then the counter knocks him out.
	{"t": FP_START, "yaw": 0.0, "kind": "brawler", "hp": 70.0, "mode": "dodge", "attacks": ["jab", "cross"], "delay": 0.3},
	# Jab, cross, hook, uppercut: the string that ends it.
	{"t": 24.02, "yaw": -0.8, "kind": "brawler", "hp": 4000.0, "mode": "combo", "attacks": [], "delay": 0.0},
	# A hook, rolled under, countered.
	{"t": 26.14, "yaw": 0.9, "kind": "pit_fighter", "hp": 30.0, "mode": "dodge", "attacks": ["right_hook"], "delay": 0.3},
	# The big one: a jab and a cross slipped, the counter sends him up.
	{"t": 27.82, "yaw": 2.3, "kind": "bruiser", "hp": 40.0, "mode": "dodge", "attacks": ["jab", "cross"], "delay": 0.3},
	# The string again, from the other side.
	{"t": 30.27, "yaw": 0.45, "kind": "pit_fighter", "hp": 4000.0, "mode": "combo", "attacks": [], "delay": 0.0},
	# A cross slipped, a left hook rolled, then the counter.
	{"t": 32.39, "yaw": -2.0, "kind": "brawler", "hp": 40.0, "mode": "dodge", "attacks": ["cross", "left_hook"], "delay": 0.3},
]
var _player: Player
var _hud: Hud
var _fp_on := false
var _fp_idx := -1
var _fp_fired := false
var _foes: Array = []
var _bot_cool := 0.0
var _bot_last := ""
var _landed := 0
var _thrown := 0
var _string_step := 0
var _ko_logged := {}


func _make_player() -> void:
	GameState.player_class = HERO
	# No cards equipped: a card's follow-up counter was carrying over from one
	# fight into the next and flattening the monster in a single jab.
	(GameState._classes[HERO] as Dictionary).cards = {}
	_player = preload("res://player.tscn").instantiate()
	_player.position = PLAYER_AT + Vector3(0, 0.05, 0)
	_world.add_child(_player)
	var lantern: Light3D = _player.get_node("Camera3D/Lantern")
	lantern.light_energy *= 0.12
	_player.punch_landed.connect(_on_punch_landed)
	_player.dodged.connect(_on_dodged)
	_make_hud()
	_player.active = false
	_player.visible = false
	_player.set_process(false)
	_player.set_physics_process(false)


## The game's own HUD, wired up the way the World does it: the knuckle bar,
## combo counter, ultimate gauge, crosshair, the COUNTER prompt and the SLIP /
## ROLL / CLEAN call-outs and flashes.
func _make_hud() -> void:
	_hud = preload("res://hud.tscn").instantiate()
	_hud.layer = 3
	add_child(_hud)
	_hud._can_pause = false
	_hud.set_progress_visible(false)
	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.power_status_changed.connect(_hud.set_power_status)
	_hud.set_knuckles(_player.knuckles, _player.max_knuckles)
	_hud.set_combo(0, 1.0)
	_hud.visible = false


func _make_floor() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(240, 2, 240)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	_world.add_child(floor_body)


## Every slip and roll: a cold blue wash and a little colour split.
func _on_dodged(move: String) -> void:
	_last_dodge = _clock
	_imp_kind = "clean" if move.begins_with("clean") else "dodge"
	_imp_time = _clock
	_imp_seed = float(_frame)
	_flash(HERO_COLOR, 0.18)


## A counter lands: a snap of white speed lines, a ring and lightning on the
## victim, and the knockout gets all of it, bigger and longer.
func _on_punch_landed(kind: String, killed: bool) -> void:
	_landed += 1
	if _foes.is_empty() or not is_instance_valid(_foes[0]):
		return
	var foe: Node3D = _foes[0]
	var at := foe.global_position + Vector3(0, 1.3, 0)
	if killed:
		_imp_kind = "ko"
	elif kind == "counter" or _clock - _last_dodge < 1.8:
		_imp_kind = "counter"
	else:
		return
	_imp_time = _clock
	_imp_seed = float(_frame)
	var big := killed
	_flash(Color(0.85, 0.95, 1.0) if big else HERO_COLOR, 0.55 if big else 0.2)
	HitFx.ring(_world, at, HERO_COLOR.lightened(0.4), 2.4 if big else 1.6)
	HitFx.burst(_world, at, Vector3.UP, HERO_COLOR, 30 if big else 16, 9.0 if big else 6.0, true, 0.07)
	HitFx.flash(_world, at, Color(0.8, 0.95, 1.0), 0.9 if big else 0.4)
	_player.shake(0.3 if big else 0.15)
	_jolts.append(_clock)
	# Lightning arcing off the body, crackling for a third of a second.
	var rng := RandomNumberGenerator.new()
	rng.seed = _frame
	var before := _cast.size()
	_lightning(foe.global_position, 1.1, HERO_COLOR, rng)
	if big:
		_lightning(foe.global_position + Vector3(0, 0.2, 0), 1.4, Color.WHITE, rng)
	for i in range(before, _cast.size()):
		_ko_fx.append({"node": _cast[i], "born": _clock})


func _update_impact(t: float) -> void:
	var age := t - _imp_time
	var lines := 0.0
	var split := 0.0
	var tint_a := 0.0
	var tint := HERO_COLOR
	match _imp_kind:
		"dodge", "clean":
			tint_a = (0.5 if _imp_kind == "clean" else 0.32) * exp(-age * 6.0)
			split = 0.008 * exp(-age * 9.0)
		"counter":
			lines = 0.8 * exp(-age * 7.0)
			split = 0.014 * exp(-age * 9.0)
			tint = Color(1.0, 0.8, 0.4)
			tint_a = 0.3 * exp(-age * 8.0)
		"ko":
			lines = 1.0 * exp(-age * 3.5)
			split = 0.022 * exp(-age * 6.0)
			tint = Color(1.0, 1.0, 1.0)
			tint_a = 0.55 * exp(-age * 5.0)
	_impact_mat.set_shader_parameter("lines", lines)
	_impact_mat.set_shader_parameter("split", split)
	_impact_mat.set_shader_parameter("tint_a", tint_a)
	_impact_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_impact_mat.set_shader_parameter("seed", _imp_seed + floorf(age * 12.0))
	for entry in _ko_fx.duplicate():
		if t - entry.born > 0.33 or not is_instance_valid(entry.node):
			if is_instance_valid(entry.node):
				entry.node.queue_free()
			_ko_fx.erase(entry)


func _fp(t: float) -> void:
	_hero.visible = false
	_fists.visible = false
	var idx := 0
	for i in FP.size():
		if t >= FP[i].t:
			idx = i
	if idx != _fp_idx:
		_fp_start(idx)
	# The monster's scripted attack string (its own windups and combo queue).
	var shot: Dictionary = FP[idx]
	if not _fp_fired and not shot.attacks.is_empty() and t - shot.t >= shot.delay and not _foes.is_empty():
		_fp_fired = true
		var foe: Boxer = _foes[0]
		var attacks: Array = shot.attacks
		foe._armor_shown = false
		foe._queue.assign(attacks.slice(1))
		foe._power_arm = "left"
		foe._begin_attack(attacks[0], Boxer.FIRST_WINDUP[attacks[0]])


func _fp_start(idx: int) -> void:
	_fp_idx = idx
	_fp_fired = false
	_string_step = 0
	seed(9000 + idx)
	print("fp shot %d: thrown %d landed %d" % [idx - 1, _thrown, _landed])
	for old in _foes:
		if is_instance_valid(old):
			old.queue_free()
	_foes.clear()
	var shot: Dictionary = FP[idx]
	var yaw: float = shot.yaw
	var f := Vector3(sin(yaw), 0, cos(yaw))
	_player.rotation = Vector3(0, atan2(-f.x, -f.z), 0)
	_player._camera.rotation = Vector3.ZERO
	_player.position = PLAYER_AT + Vector3(0, 0.05, 0)
	_player.velocity = Vector3.ZERO
	_player._clear_counter()
	_player._defense = ""
	_player._defense_cooldown = 0.0
	_player._cooldown = 0.0
	# (No punch left buffered from the last fight to land on this one.)
	_player._buffered_hand = ""
	_player._buffered_type = ""
	_player._buffer_timer = 0.0
	var foe: Boxer = load("res://%s.tscn" % shot.kind).instantiate()
	foe.setup(_player, false, {"hat": ""})
	foe.position = PLAYER_AT + f * 2.1
	foe.rotation.y = atan2(f.x, f.z)
	foe.move_speed = 0.8
	foe.windup_scale = 0.55   # quicker reads, so each slip lands in a short shot
	_world.add_child(foe)
	foe._state_timer = 999.0   # it only throws what the shot scripts
	foe._turn_rest = 0.0
	foe.takes_turns = false
	foe.max_hp = shot.hp
	foe.hp = shot.hp
	_foes.append(foe)


func _physics_process(delta: float) -> void:
	if not _fp_on or _player == null or _fp_idx < 0:
		return
	_bot_cool -= delta
	var p := _player
	# (The bot isn't pressing keys, so the hands would drift into an idle.)
	p._idle_for = 0.0
	p._idle_next = 99.0
	if p._fists.idle_playing:
		p._fists.stop_idle(false)
	var shot: Dictionary = FP[_fp_idx]
	var eye := p._camera.global_position
	var foe: Boxer = _foes[0] if not _foes.is_empty() and is_instance_valid(_foes[0]) else null
	var live := foe != null and not foe.is_dead()
	var flying := foe != null and foe.is_dead() and foe._flying and foe._fly_time < 0.8
	if foe != null and (live or flying):
		var to := foe.global_position + Vector3(0, 1.35, 0) - eye
		var want_yaw := atan2(-to.x, -to.z)
		p.rotation.y = lerp_angle(p.rotation.y, want_yaw, clampf(delta * (14.0 if live else 6.0), 0.0, 1.0))
		var want_pitch := atan2(to.y, Vector2(to.x, to.z).length())
		p._camera.rotation.x = lerpf(p._camera.rotation.x, want_pitch, clampf(delta * 10.0, 0.0, 1.0))
		var flat := Vector3(to.x, 0, to.z)
		if live and flat.length() > 1.7 and p._defense == "":
			p.global_position += flat.normalized() * minf(4.0 * delta, flat.length() - 1.7)
	if foe != null and foe.is_dead() and not _ko_logged.has(_fp_idx):
		_ko_logged[_fp_idx] = true
		print("KO shot %d at +%.2f step=%d hp=%.1f foe=%s" % [_fp_idx, _clock - float(shot.t), _string_step, foe.hp, foe.name])
	if not live:
		return
	var incoming: String = foe.incoming_attack()
	# Dodge fights: slip or roll each punch at the last moment, then counter.
	if shot.mode == "dodge":
		if incoming != "" and p._defense == "" and p._defense_cooldown <= 0.0:
			var moves: Array = Player.ANSWERS.get(incoming, [])
			if not moves.is_empty() and foe.attack_eta() > 0.0 and foe.attack_eta() <= 0.1:
				_bot_last = moves[0]
				p._try_defense(moves[0])
			return
		# Counter once the last punch of the string has been slipped.
		var over: bool = foe._queue.is_empty() and foe._state != Boxer.State.WINDUP
		if p._counter_side != "" and p._counter_timer > 0.0 and _bot_cool <= 0.0 and p._cooldown <= 0.0 \
				and (over or p._counter_timer < 0.35) and p._defense == "":
			p._buffered_hand = p._counter_side if p._counter_side in ["left", "right"] else "right"
			p._buffered_type = "uppercut" if _bot_last.begins_with("slip") else "hook"
			p._buffer_timer = 0.2
			_bot_cool = 0.3
			_thrown += 1
		return
	# The string: jab, cross, hook, uppercut (the last one finishes him).
	if _clock - shot.t > 0.15 and p._cooldown <= 0.0 and _bot_cool <= 0.0 and _string_step < 4:
		var string := [["jab", "left"], ["cross", "right"], ["hook", "left"], ["uppercut", "right"]]
		var step: Array = string[_string_step]
		if step[0] == "uppercut":
			foe.hp = minf(foe.hp, 1.0)
		p._buffered_type = step[0]
		p._buffered_hand = step[1]
		p._buffer_timer = 0.25
		_string_step += 1
		_bot_cool = 0.05
		_thrown += 1
