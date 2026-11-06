extends Node3D
## Title screen: the Dead League's ring at midnight, in the game's own blocky
## look. The next contender waits in its corner under a spotlight, the dead
## stand watching beyond the iron fence, braziers burn at the corners and the
## mausoleum door glows behind, with mist, wisps, bats and the odd lightning
## strike. Nothing pops in or out: everything holds its place and breathes.
## Under the animated FRIGHT NIGHT logo the menu picks the class, opens
## Settings, or goes to camp.

const SKY_TOP := Color(0.012, 0.014, 0.035)
const SKY_HORIZON := Color(0.1, 0.07, 0.16)
const FOG_COLOR := Color(0.07, 0.07, 0.12)
const MOON_COLOR := Color(0.95, 0.92, 0.8)
const MOONLIGHT := Color(0.6, 0.7, 1.0)
const BLOOD := Color(0.82, 0.1, 0.07)
const STONE := Color(0.36, 0.36, 0.4)
const TITLE_TEXT := "FRIGHT NIGHT"
const TITLE_SIZE := 118
const SUBTITLE := "BARE-KNUCKLE BOXING IN THE GRAVEYARD"
const LIGHTNING_GAP := Vector2(9.0, 18.0)
const RING_CENTER := Vector3(1.6, 0, -9.0)
const RING_HALF := 3.4
const CAMERA_HOME := Vector3(-0.9, 2.5, -2.4)
const CAMERA_LOOK := Vector3(1.9, 1.7, -14.0)
const MENU := [["PLAY", "_on_play"], ["FIGHTER", "_open_classes"], ["SETTINGS", "_open_settings"], ["CREDITS", "_open_credits"], ["QUIT", "_on_quit"]]

var _time := 0.0
var _camera: Camera3D
var _env: Environment
var _moonlight: DirectionalLight3D
var _torches: Array[OmniLight3D] = []
## The Dead League stage behind the ring (2026-11-06): the place of the
## contender you're climbing toward, as DeadLeagueStages builds it for the
## arena. Empty if that contender has none (the old graveyard is the fallback).
var _stage := {}
## The contender's own color: the logo, its drips and the menu marker wear it.
var _title_color := BLOOD
var _indoors := false
var _ambient_base := 0.35
var _moon_base := 0.55
var _bats: Array[Dictionary] = []
## The contender in the ring and the dead watching it: they hold their places
## and only breathe (driven here, their own AI stays off).
var _actors: Array[Dictionary] = []
var _decor: Node3D
## The contender's routine in the ring: hops, quick double hops, pauses in its
## guard and the odd punch at nothing, picked at random (_drive_contender).
var _contender := {}
const CONTENDER_PUNCHES := ["jab", "cross", "left_hook", "right_hook", "uppercut"]
var _lightning_timer := 4.0
var _flash := 0.0
var _leaving := false

var _ui: Control
var _letters: Array[Label] = []
var _letter_home: Array[Vector2] = []
var _title_ready := false
var _drip_timer := 1.5
var _subtitle: Label
var _menu_buttons: Array[Button] = []
var _class_label: Label
var _class_icon: IconView
var _flash_rect: ColorRect
var _fade: ColorRect
var _overlay: ColorRect
var _class_panel: Control
## Fighter select: card size and layout, and the parts that appear once a card
## is picked.
const CARD_SIZE := Vector2(286, 548)
const CARD_TOP := 104.0
const CARD_GAP := 16.0
## More fighters than this go in two rows.
const MAX_ROW := 5
const CARD_SLIDE_TIME := 0.45
var _cards := {}
var _card_left := 0.0
## How far the fighter screen is shifted right of its 1280-wide layout, to sit
## in the middle on screens wider than 16:9 (2026-11-05).
var _class_ox := 0.0
## Cards shrink when five fighters share the row.
var _card_scale := 1.0
## The fighter whose card is open ("" while all four show).
var _picked := ""
var _demo: DemoReel
var _demo_shade: TextureRect
var _detail: PanelContainer
var _detail_box: VBoxContainer
## Opened from camp's Change fighter: Back goes back to camp.
var _from_camp := false
var _detail_tagline: Label
## The four star rows (2026-11-06, replaces the stat bars) and the perk strip.
var _detail_stats: VBoxContainer
var _detail_perk_box: StitchPanel
var _detail_perk_tag: PanelContainer
var _detail_perk_name: Label
## The perk's pros (green) and cons (red), a line each.
var _detail_perk_lines: VBoxContainer
## The < tab on the panel's right edge: hides the panel to show the clip.
var _detail_tab: Button
var _stats_hidden := false
var _detail_ult_tag: Label
var _detail_ult_name: Label
var _detail_ult_how: Label
var _choose_button: Button
var _caption: VBoxContainer
var _caption_tag: Label
var _caption_move: Label
var _caption_how: Label
var _settings_holder: Control
var _class_heading: Label
var _class_back: Button
var _tutorial_offer: Control
var _mode_offer: Control
## First start: PLAY goes class picker -> control mode -> tutorial offer
## instead of to camp.
var _onboarding := false


## Which contender stands in the ring: the one you're climbing toward (the
## Coffin King once the crown is yours). TITLE_BOSS forces one in tests.
static func boss_index() -> int:
	var forced := OS.get_environment("TITLE_BOSS")
	if forced != "":
		return clampi(int(forced), 0, DeadLeagueRules.BOSS_COUNT - 1)
	return mini(Progression.current_tier() - 1, DeadLeagueRules.BOSS_COUNT - 1)


func _ready() -> void:
	if WebBench.start_if_requested(get_tree()):
		return
	_title_color = DeadLeagueRules.boss(boss_index()).accent.lightened(0.05)
	Sfx.play_music("title")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Controls.watch(self, func() -> void:
		if _detail_ult_tag:
			_detail_ult_tag.text = "ULTIMATE")
	get_tree().paused = false
	TimeFx.clear()
	_build_world()
	_build_ui()
	Sfx.play_ambience("wind", -8.0)
	GameState.changed.connect(_refresh_class)  # e.g. after resetting the save.
	_lightning_timer = randf_range(3.0, 6.0)
	# Camp's Change fighter lands straight on the fighter picker.
	if GameState.title_opens_fighters:
		GameState.title_opens_fighters = false
		_from_camp = true
		_open_classes.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	_move_camera(delta)
	_animate_world(delta)
	_animate_title(delta)
	_update_lightning(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _picked != "":
		_unpick_fighter()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and (_class_panel.visible or _tutorial_offer.visible or _mode_offer.visible):
		_close_panels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and not _overlay.visible and _title_ready and not _leaving:
		_on_play()


# --- The graveyard ----------------------------------------------------------------

func _build_world() -> void:
	_env = Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY_TOP
	sky_material.sky_horizon_color = SKY_HORIZON
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.015)
	sky_material.ground_horizon_color = SKY_HORIZON
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.3, 0.33, 0.5)
	_env.ambient_light_energy = 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 1.1
	_env.glow_bloom = 0.12
	_env.fog_enabled = true
	_env.fog_light_color = FOG_COLOR
	_env.fog_density = 0.032
	_env.fog_sky_affect = 0.35
	Look.tune_environment(_env, "night")
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"  # DeadLeagueStages finds these by name.
	world_env.environment = _env
	add_child(world_env)

	_moonlight = DirectionalLight3D.new()
	_moonlight.light_color = MOONLIGHT
	_moonlight.light_energy = 0.55
	_moonlight.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	_moonlight.rotation = Vector3(deg_to_rad(-22), deg_to_rad(155), 0)
	_moonlight.name = "Moon"
	add_child(_moonlight)

	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.position = CAMERA_HOME
	add_child(_camera)
	_camera.look_at(CAMERA_LOOK)

	_build_set()
	_build_ring()
	_build_contender()
	if _stage.is_empty():
		_build_braziers()
		_build_crowd()
		_build_bats()
		Look.batch_meshes(_decor, true)
	else:
		# The same grade as the Dead League ring, so the contender looks here
		# as he does in the fight.
		Look.tune_environment(_env, "ring")
		_indoors = _env.background_mode == Environment.BG_COLOR
		_ambient_base = _env.ambient_light_energy
		_moon_base = _moonlight.light_energy


## Ground, sky and moon, graves, dead trees, the mausoleum and the mist, from
## the same Scenery pieces as the Dead League arena.
func _build_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var web := Settings.use_web_profile()
	_decor = Node3D.new()
	_decor.name = "Decorations"
	add_child(_decor)
	var ground := MeshInstance3D.new()
	ground.name = "Mesh"
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	plane.material = Look.block_material(Color(0.12, 0.14, 0.11))
	ground.mesh = plane
	var ground_root := Node3D.new()
	ground_root.name = "Ground"
	ground_root.add_child(ground)
	add_child(ground_root)
	_stage = DeadLeagueStages.build(DeadLeagueRules.boss(boss_index()).id, self, RING_CENTER)
	if not _stage.is_empty():
		for light in _stage.lights:
			_torches.append(light)
		return
	Scenery.night_sky(_decor, rng, Vector3(44, 27, -66))
	Scenery.ground_patches(_decor, 24.0, 24 if web else 40, rng)
	# The iron fence around the ring (open on the camera's side).
	for n in range(1, 4):
		var run := Scenery.fence(_decor, 15.0)
		var angle := n * PI / 2.0
		var along := Vector3(cos(angle), 0, -sin(angle))
		run.rotation.y = angle
		run.position = RING_CENTER + along.cross(Vector3.UP) * 7.5 - along * 7.5
	# Graves in loose rows beyond the fence, kept off the camera's side.
	for n in (26 if web else 44):
		var angle := rng.randf_range(PI * 0.95, TAU * 1.05)
		var node := Node3D.new()
		node.position = RING_CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(8.5, 17.0)
		node.rotation.y = rng.randf_range(-0.3, 0.3) + angle + PI / 2.0
		_decor.add_child(node)
		Scenery.gravestone(node, rng.randi_range(0, 5), rng)
	for spot in [Vector3(-9, 0, -16), Vector3(12, 0, -20), Vector3(-14, 0, -27), Vector3(9, 0, -31), Vector3(-6, 0, -33)]:
		var node := Node3D.new()
		node.position = spot
		_decor.add_child(node)
		Scenery.dead_tree(node, rng, rng.randf_range(5.0, 7.5))
	# The mausoleum behind the ring, its doorway burning.
	var mausoleum := Node3D.new()
	mausoleum.position = RING_CENTER + Vector3(-0.8, 0, -13.0)
	mausoleum.scale = Vector3.ONE * 2.0
	_decor.add_child(mausoleum)
	Scenery.crypt(mausoleum, rng)
	var doorway := Look.fire_light(Color(1.0, 0.45, 0.15), 2.6, 10.0, false)
	doorway.position = mausoleum.position + Vector3(0, 1.8, 3.6)
	add_child(doorway)
	_torches.append(doorway)
	Scenery.mist(_decor, RING_CENTER + Vector3(0, 0.3, -2.0), Vector3(28, 0.3, 24), 16 if web else 34)
	Scenery.wisps(_decor, RING_CENTER + Vector3(0, 1.4, -4.0), Vector3(12, 1.0, 10), Color(0.45, 1.0, 0.75), 14 if web else 26)


## The ring: canvas, posts and red ropes, with a spotlight on it.
func _build_ring() -> void:
	var canvas := Enemy._material(Color(0.24, 0.24, 0.29))
	var post := Enemy._material(Color(0.12, 0.12, 0.15), 0.75)
	var rope := Enemy._material(Color(0.72, 0.08, 0.06))
	var size := RING_HALF * 2.0
	var holder := Node3D.new()
	_decor.add_child(holder)
	Scenery.box(holder, Vector3(size + 0.6, 0.5, size + 0.6), RING_CENTER + Vector3(0, 0.25, 0), Enemy._material(Color(0.1, 0.09, 0.11)))
	Scenery.box(holder, Vector3(size, 0.04, size), RING_CENTER + Vector3(0, 0.52, 0), canvas)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Scenery.box(holder, Vector3(0.16, 1.6, 0.16), RING_CENTER + Vector3(x * RING_HALF, 1.3, z * RING_HALF), post)
	for height in [1.0, 1.35, 1.7]:
		for side in [-1.0, 1.0]:
			Scenery.box(holder, Vector3(size, 0.05, 0.05), RING_CENTER + Vector3(0, height, side * RING_HALF), rope)
			Scenery.box(holder, Vector3(0.05, 0.05, size), RING_CENTER + Vector3(side * RING_HALF, height, 0), rope)
	var spot := SpotLight3D.new()
	spot.position = RING_CENTER + Vector3(0, 9.0, 0.5)
	spot.rotation = Vector3(-PI / 2.0 + 0.08, 0, 0)
	spot.spot_angle = 32.0
	spot.spot_range = 16.0
	spot.light_energy = 4.0
	spot.light_color = Color(1.0, 0.92, 0.82)
	add_child(spot)
	Look.batch_meshes(holder, true)


## Fire braziers hanging from tall posts at the ring's corners.
func _build_braziers() -> void:
	var iron := Enemy._material(Color(0.12, 0.11, 0.12), 0.7)
	var web := Settings.use_web_profile()
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var base := RING_CENTER + Vector3(x * 5.6, 0, z * 5.6)
			Scenery.box(_decor, Vector3(0.18, 4.2, 0.18), base + Vector3(0, 2.1, 0), iron)
			Scenery.box(_decor, Vector3(1.0, 0.12, 0.12), base + Vector3(-x * 0.45, 4.1, 0), iron)
			var cage := base + Vector3(-x * 0.9, 3.0, 0)
			for k in 4:
				Scenery.box(_decor, Vector3(0.03, 1.0, 0.03), cage + Vector3(0, 0.55, 0) + Vector3(cos(k * PI / 2.0), 0, sin(k * PI / 2.0)) * 0.22, iron)
			Scenery.box(_decor, Vector3(0.5, 0.06, 0.5), cage, iron)
			Look.flame(_decor, cage + Vector3(0, 0.12, 0), 0.9, not web)
			var light := Look.fire_light(Color(1.0, 0.5, 0.2), 2.2, 9.0, false)
			light.position = cage + Vector3(0, 0.5, 0)
			add_child(light)
			_torches.append(light)


## The contender you're climbing toward, waiting in the far corner in its
## guard (the Coffin King once the crown is yours).
func _build_contender() -> void:
	var index := boss_index()
	var boss: DeadLeagueBoss = load("res://dead_league_boss.tscn").instantiate()
	boss.configure(index, 1)
	add_child(boss)
	boss.set_physics_process(false)
	boss.position = RING_CENTER + Vector3(0.5, 0.54, -0.4)
	boss.look_at(CAMERA_HOME * Vector3(1, 0, 1) + Vector3(0, boss.position.y, 0), Vector3.UP)
	_contender = {"boss": boss, "home": boss.position, "facing": boss.rotation.y, "x": 0.0, "queue": [], "move": {}, "last": ""}


## The dead, standing in the fog beyond the fence, watching the ring.
func _build_crowd() -> void:
	var cast := ["zombie", "skeleton", "zombie", "possessed_armor", "zombie", "skeleton", "hulk", "zombie"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for n in cast.size():
		var enemy: Node3D = load("res://%s.tscn" % cast[n]).instantiate()
		add_child(enemy)
		enemy.set_physics_process(false)
		var angle := lerpf(PI * 1.12, PI * 1.88, float(n) / (cast.size() - 1)) + rng.randf_range(-0.05, 0.05)
		enemy.position = RING_CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(8.6, 10.5)
		enemy.look_at(RING_CENTER * Vector3(1, 0, 1), Vector3.UP)
		# Shuffling side to side on the spot, each to its own beat.
		_actors.append({"enemy": enemy, "time": rng.randf() * 10.0, "home": enemy.position, "facing": enemy.rotation.y,
				"sway": rng.randf_range(0.2, 0.3), "rate": rng.randf_range(0.7, 0.95), "pace": 0.6})


func _build_bats() -> void:
	var black := _material(Color(0.03, 0.03, 0.04))
	for i in 7:
		var bat := Node3D.new()
		add_child(bat)
		_box(bat, Vector3(0.12, 0.08, 0.22), Vector3.ZERO, black)
		var wings: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			bat.add_child(pivot)
			_box(pivot, Vector3(0.38, 0.02, 0.2), Vector3(side * 0.2, 0, 0), black)
			wings.append(pivot)
		bat.scale = Vector3.ONE * randf_range(0.9, 1.5)
		_bats.append({
			"node": bat, "wings": wings, "center": Vector3(randf_range(-10, 6), randf_range(9, 16), randf_range(-45, -25)),
			"radius": randf_range(4, 10), "speed": randf_range(0.4, 0.8) * (1.0 if randf() < 0.5 else -1.0),
			"phase": randf() * TAU, "flap": randf_range(14, 20),
		})


func _move_camera(delta: float) -> void:
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position() / viewport.get_visible_rect().size - Vector2(0.5, 0.5)
	var target := CAMERA_HOME + Vector3(sin(_time * 0.08) * 0.6 + mouse.x * 0.5, sin(_time * 0.17) * 0.08 - mouse.y * 0.2, sin(_time * 0.06) * 0.4)
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 2.0))
	_camera.look_at(CAMERA_LOOK + Vector3(sin(_time * 0.07) * 0.5 + mouse.x * 0.8, 0, 0))


func _animate_world(delta: float) -> void:
	for i in _torches.size():
		_torches[i].light_energy = 2.0 + sin(_time * 11.0 + i * 1.7) * 0.3 + sin(_time * 23.0 + i) * 0.15
	for bat in _bats:
		var angle: float = _time * bat.speed + bat.phase
		var node: Node3D = bat.node
		var next: Vector3 = bat.center + Vector3(cos(angle), sin(angle * 2.3) * 0.15, sin(angle)) * bat.radius
		var heading := next - node.position
		node.position = next
		if heading.length() > 0.001:
			node.look_at(next + heading, Vector3.UP)
		var flap := sin(_time * bat.flap) * 0.9
		bat.wings[0].rotation.z = flap
		bat.wings[1].rotation.z = -flap
	for actor in _actors:
		var enemy: Node3D = actor.enemy
		if not is_instance_valid(enemy):
			continue
		actor.time += delta
		var beat: float = actor.time * actor.rate
		# Hop side to side across their own facing, turning a little with it.
		var side := Vector3(cos(actor.facing), 0, -sin(actor.facing))
		enemy.position = actor.home + side * sin(beat) * actor.sway
		# Hops: up off the ground twice per side-to-side, snapping down hard.
		enemy.position.y += pow(absf(sin(beat * 2.0)), 0.6) * actor.get("hop", 0.0)
		enemy.rotation.y = actor.facing + sin(beat) * 0.15
		if enemy.has_method("_animate"):
			enemy._animate(delta, actor.pace)
	if not _contender.is_empty():
		_drive_contender(delta)


## Plays the contender's current move, and picks the next when it's done:
## hop... hophop... a punch or two... a breather... hop.
func _drive_contender(delta: float) -> void:
	var c := _contender
	var boss: DeadLeagueBoss = c.boss
	if not is_instance_valid(boss):
		return
	if c.move.is_empty() or c.move.time >= c.move.duration:
		if not c.move.is_empty() and c.move.kind == "punch":
			boss._state = DeadLeagueBoss.State.IDLE
		if c.queue.is_empty():
			_plan_contender()
		c.move = c.queue.pop_front()
		c.move.time = 0.0
		c.move.from = c.x
		if c.move.kind == "punch":
			boss._attack = c.move.attack
			if _stage.has("crowd") and is_instance_valid(_stage.crowd):
				(_stage.crowd as Crowd).cheer(0.45)
	var move: Dictionary = c.move
	move.time += delta
	var t := clampf(move.time / move.duration, 0.0, 1.0)
	var lift := 0.0
	var pace := 0.0
	match move.kind:
		"hop":
			c.x = lerpf(move.from, move.to, t)
			lift = sin(PI * t) * move.height
			pace = 0.9
		"punch":
			# Wind up, snap it out, then settle back into the guard.
			var windup: float = move.duration * 0.5
			if move.time < windup:
				boss._state = DeadLeagueBoss.State.WINDUP
			elif move.time < move.duration * 0.75:
				boss._state = DeadLeagueBoss.State.STRIKE
			else:
				boss._state = DeadLeagueBoss.State.IDLE
	var side := Vector3(cos(c.facing), 0, -sin(c.facing))
	boss.position = c.home + side * c.x + Vector3(0, lift, 0)
	boss.rotation.y = c.facing + c.x * 0.25
	boss._animate(delta, pace)


## Queues the next beat of the routine, never two punches in a row.
func _plan_contender() -> void:
	var c := _contender
	var roll := randf()
	var kind := "rest"
	if roll < 0.32:
		kind = "hop"
	elif roll < 0.55:
		kind = "double"
	elif roll >= 0.8 and c.last != "punch":
		kind = "punch"
	c.last = kind
	match kind:
		"hop":
			c.queue.append({"kind": "hop", "to": randf_range(-0.38, 0.38), "height": randf_range(0.08, 0.13), "duration": 0.34})
			c.queue.append({"kind": "rest", "duration": randf_range(0.15, 0.4)})
		"double":
			var to := randf_range(-0.38, 0.38)
			c.queue.append({"kind": "hop", "to": lerpf(c.x, to, 0.5), "height": 0.07, "duration": 0.22})
			c.queue.append({"kind": "hop", "to": to, "height": 0.07, "duration": 0.22})
			c.queue.append({"kind": "rest", "duration": randf_range(0.2, 0.5)})
		"punch":
			for n in (1 if randf() < 0.6 else 2):
				c.queue.append({"kind": "punch", "duration": 0.55, "attack": CONTENDER_PUNCHES.pick_random()})
			c.queue.append({"kind": "rest", "duration": randf_range(0.5, 0.9)})
		_:
			c.queue.append({"kind": "rest", "duration": randf_range(0.6, 1.4)})


## Lightning: a double flicker that lights the scene and the logo, then thunder.
func _update_lightning(delta: float) -> void:
	if _indoors:
		return  # No sky to flash in a hall or a pit.
	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(LIGHTNING_GAP.x, LIGHTNING_GAP.y)
		_strike()
	_flash = maxf(0.0, _flash - delta * 3.5)
	_moonlight.light_energy = _moon_base + _flash * 3.5
	_env.ambient_light_energy = _ambient_base + _flash * 1.6
	_flash_rect.color.a = _flash * 0.18


func _strike() -> void:
	_flash = 1.0
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func() -> void: _flash = 0.25)
	tween.tween_interval(0.07)
	tween.tween_callback(func() -> void: _flash = 0.9)
	get_tree().create_timer(randf_range(0.5, 1.3)).timeout.connect(func() -> void:
		Sfx.play("quake", -6.0, 0.45)
		Sfx.play("wave", -18.0, 0.5))
	for letter in _letters:
		letter.modulate = Color(2.2, 2.2, 2.4)
		letter.create_tween().tween_property(letter, "modulate", Color.WHITE, 0.6)


# --- UI ---------------------------------------------------------------------------

func _build_ui() -> void:
	add_child(PostFx.new())
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UiTheme.make()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.texture = _radial_texture(Color(0, 0, 0, 0), Color(0, 0, 0, 0.85), 0.45)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(vignette)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0.8, 0.85, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash_rect)

	_build_logo()
	_build_menu()
	_build_footer()

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, UiTheme.POPUP_DIM)
	_overlay.visible = false
	_ui.add_child(_overlay)
	_build_class_panel()
	_settings_holder = CenterContainer.new()
	_settings_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_holder.visible = false
	_ui.add_child(_settings_holder)
	_build_tutorial_offer()
	_build_mode_offer()
	var settings := SettingsPanel.new()
	settings.closed.connect(_close_panels)
	_settings_holder.add_child(settings)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)
	_fade.create_tween().tween_property(_fade, "color:a", 0.0, 1.6).set_delay(0.2)


## FRIGHT NIGHT, one label per letter so each can drop in, bob and drip.
func _build_logo() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position.y = 70.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(holder)
	var widths: Array[float] = []
	var total := 0.0
	for letter in TITLE_TEXT:
		var width := UiTheme.display_font().get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
		width = TITLE_SIZE * 0.32 if letter == " " else width + 2.0
		widths.append(width)
		total += width
	var x := -total / 2.0
	for i in TITLE_TEXT.length():
		var label := Label.new()
		label.text = TITLE_TEXT[i]
		label.add_theme_font_override("font", UiTheme.display_font())
		label.add_theme_font_size_override("font_size", TITLE_SIZE)
		label.add_theme_color_override("font_color", _title_color)
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.01, 0.01))
		label.add_theme_constant_override("outline_size", 20)
		label.add_theme_color_override("font_shadow_color", Color(_title_color.darkened(0.55), 0.6))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 8)
		label.add_theme_constant_override("shadow_outline_size", 28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(label)
		var home := Vector2(x, 0)
		x += widths[i]
		_letters.append(label)
		_letter_home.append(home)
		label.pivot_offset = Vector2(widths[i] / 2.0, TITLE_SIZE * 0.7)
		label.position = home + Vector2(0, -260)
		label.rotation = randf_range(-0.6, 0.6)
		label.modulate.a = 0.0
		var tween := label.create_tween().set_parallel()
		var delay := 0.5 + i * 0.07
		tween.tween_property(label, "position", home, 0.75).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "rotation", 0.0, 0.6).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 1.0, 0.25).set_delay(delay)
		if TITLE_TEXT[i] != " ":
			tween.tween_callback(Sfx.play.bind("hit", -14.0, 0.7 + i * 0.04)).set_delay(delay + 0.3)
	get_tree().create_timer(0.5 + TITLE_TEXT.length() * 0.07 + 0.8).timeout.connect(func() -> void:
		_title_ready = true
		_strike())

	_subtitle = Label.new()
	_subtitle.text = SUBTITLE
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
	_subtitle.add_theme_color_override("font_outline_color", Color.BLACK)
	_subtitle.add_theme_constant_override("outline_size", 6)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.size = Vector2(900, 30)
	_subtitle.position = Vector2(-450, TITLE_SIZE + 22)
	_subtitle.modulate.a = 0.0
	holder.add_child(_subtitle)
	_subtitle.create_tween().tween_property(_subtitle, "modulate:a", 1.0, 1.2).set_delay(1.9)


func _animate_title(delta: float) -> void:
	if not _title_ready:
		return
	for i in _letters.size():
		var label := _letters[i]
		label.position = _letter_home[i] + Vector2(0, sin(_time * 1.6 + i * 0.55) * 5.0)
		label.rotation = sin(_time * 1.1 + i * 0.9) * 0.025
	# Blood drips off the letters now and then.
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(0.4, 1.1)
		var label := _letters[randi() % _letters.size()]
		if label.text != " ":
			_drip(label)


func _drip(label: Label) -> void:
	var drop := ColorRect.new()
	drop.color = _title_color.darkened(0.15)
	drop.size = Vector2(5, 9)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.position = label.position + Vector2(label.size.x * randf_range(0.3, 0.7), TITLE_SIZE * 0.95)
	label.get_parent().add_child(drop)
	var tween := drop.create_tween()
	tween.tween_property(drop, "size:y", 16.0, 0.6)
	tween.tween_property(drop, "position:y", drop.position.y + 70.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(drop, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(drop.queue_free)


## The version in the corner: "v0.9.0" on released builds (itch), with "DEV"
## on the builds from every change (GitHub Pages, the editor).
func _build_version() -> void:
	var version := Label.new()
	var number: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	version.text = "v%s" % number if OS.has_feature("release") else "v%s  DEV BUILD" % number
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(UiTheme.MUTED, 0.6))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -260
	version.offset_right = -18
	version.offset_top = -30
	version.offset_bottom = -10
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(version)


func _build_menu() -> void:
	_build_version()
	var menu := Control.new()
	menu.position = Vector2(90, 300)
	_ui.add_child(menu)
	var row := 0
	for entry in MENU:
		if entry[0] == "QUIT" and OS.has_feature("web"):
			continue
		var button := Button.new()
		button.text = entry[0]
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", UiTheme.display_font())
		button.add_theme_font_size_override("font_size", 38)
		button.add_theme_color_override("font_color", Color(0.85, 0.82, 0.86))
		button.add_theme_color_override("font_hover_color", UiTheme.GOLD)
		button.add_theme_color_override("font_pressed_color", BLOOD.lightened(0.3))
		button.add_theme_color_override("font_outline_color", Color.BLACK)
		button.add_theme_constant_override("outline_size", 8)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.size = Vector2(330, 56)
		var home := Vector2(0, row * 58)
		button.position = home + Vector2(-420, 0)
		button.modulate.a = 0.0
		button.pressed.connect(func() -> void:
			Sfx.play("hit", -6.0, 0.8)
			call(entry[1]))
		button.mouse_entered.connect(func() -> void:
			Sfx.play("whoosh", -16.0, 1.7)
			button.create_tween().tween_property(button, "position:x", home.x + 22.0, 0.12))
		button.mouse_exited.connect(func() -> void:
			button.create_tween().tween_property(button, "position:x", home.x, 0.15))
		menu.add_child(button)
		var tween := button.create_tween().set_parallel()
		tween.tween_property(button, "position", home, 0.5).set_delay(1.6 + row * 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(button, "modulate:a", 1.0, 0.4).set_delay(1.6 + row * 0.12)
		_menu_buttons.append(button)
		row += 1
	# A blood-red bar beside the menu.
	var bar := ColorRect.new()
	bar.color = _title_color
	bar.position = Vector2(-22, 10)
	bar.size = Vector2(5, row * 58 - 20)
	bar.modulate.a = 0.0
	menu.add_child(bar)
	bar.create_tween().tween_property(bar, "modulate:a", 0.8, 0.8).set_delay(1.6)


func _build_footer() -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.position = Vector2(90, -96)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(box)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	_class_icon = IconView.new()
	_class_icon.custom_minimum_size = Vector2(54, 54)
	_class_icon.color = UiTheme.GOLD
	box.add_child(_class_icon)
	_class_label = Label.new()
	_class_label.add_theme_font_size_override("font_size", 18)
	_class_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_class_label.add_theme_constant_override("outline_size", 6)
	box.add_child(_class_label)
	for node in [box]:
		node.modulate.a = 0.0
		node.create_tween().tween_property(node, "modulate:a", 1.0, 1.0).set_delay(2.2)
	_refresh_class()


func _refresh_class() -> void:
	var id := GameState.player_class
	var info: Dictionary = GameState.CLASSES[id]
	_class_icon.icon = info.icon
	_class_icon.color = GameState.fighter_color(id)
	_class_label.text = "%s   -   %s   -   Level %d\nUltimate: %s" % [GameState.fighter_name(id).to_upper(), info.name, GameState.class_level(id), Abilities.info(id, GameState.ultimate(id)).get("name", Ult.NAMES[id].capitalize())]
	for card_id in _cards:
		var card: Dictionary = _cards[card_id]
		card.level.text = "LV %d" % GameState.class_level(card_id)
		card.badge.visible = GameState.is_player_class(card_id)


# --- Fighter select -----------------------------------------------------------------
# Four cards in the style of the character pitches. Clicking one slides it to
# the left, fades the others, and plays that fighter's demo reel behind it with
# its details; Back slides it home, Choose plays as that fighter.

func _build_class_panel() -> void:
	_class_panel = Control.new()
	_class_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_class_panel.visible = false
	_ui.add_child(_class_panel)

	_demo = DemoReel.new()
	# The right side of the screen, so the fight sits beside the details.
	_demo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_demo.anchor_left = 0.4
	_demo.visible = false
	_demo.caption_changed.connect(_on_demo_caption)
	_class_panel.add_child(_demo)
	# Darkens the left side so the card and details read over the reel.
	_demo_shade = TextureRect.new()
	_demo_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_demo_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_shade.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.02, 0.04, 0.97))
	gradient.set_color(1, Color(0.02, 0.02, 0.04, 0.0))
	gradient.add_point(0.4, Color(0.02, 0.02, 0.04, 0.92))
	gradient.add_point(0.56, Color(0.02, 0.02, 0.04, 0.0))
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(1, 0)
	_demo_shade.texture = shade
	_demo_shade.modulate.a = 0.0
	_class_panel.add_child(_demo_shade)

	_class_heading = Label.new()
	_class_heading.text = "CHOOSE YOUR FIGHTER"
	_class_heading.add_theme_font_size_override("font_size", 40)
	_class_heading.add_theme_color_override("font_color", BLOOD.lightened(0.1))
	_class_heading.add_theme_color_override("font_outline_color", Color.BLACK)
	_class_heading.add_theme_constant_override("outline_size", 12)
	_class_heading.add_theme_font_override("font", UiTheme.display_font())
	_class_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_ox = maxf(0.0, (get_viewport().get_visible_rect().size.x - 1280.0) / 2.0)
	_class_heading.position = Vector2(_class_ox, 30)
	_class_heading.size = Vector2(1280, 56)
	_class_panel.add_child(_class_heading)

	# Up to five fighters in a row (the cards shrink a little); six or more in
	# two rows (three a row for six).
	var ids := GameState.class_ids()
	var columns := ids.size() if ids.size() <= MAX_ROW else ceili(ids.size() / 2.0)
	var rows := ceili(ids.size() / float(columns))
	var fit_wide := (1240.0 - CARD_GAP * (columns - 1)) / (CARD_SIZE.x * columns)
	var fit_tall := (720.0 - CARD_TOP - 12.0 - CARD_GAP * (rows - 1)) / (CARD_SIZE.y * rows)
	_card_scale = minf(1.0, minf(fit_wide, fit_tall))
	var width := CARD_SIZE.x * _card_scale
	var height := CARD_SIZE.y * _card_scale
	var i := 0
	for id in ids:
		var row := i / columns
		var in_row := mini(columns, ids.size() - row * columns)
		var start_x := _class_ox + (1280.0 - width * in_row - CARD_GAP * (in_row - 1)) / 2.0
		var card := _fighter_card(id)
		card.scale = Vector2.ONE * _card_scale
		card.position = Vector2(start_x + (i % columns) * (width + CARD_GAP), CARD_TOP + row * (height + CARD_GAP))
		_cards[id].home = card.position
		_class_panel.add_child(card)
		i += 1
	# A picked card slides to the left edge, full size, beside its details.
	_card_left = _class_ox + ((1280.0 - width * columns - CARD_GAP * (columns - 1)) / 2.0 if rows == 1 else 24.0)
	get_viewport().size_changed.connect(_recentre_classes)

	_class_back = Button.new()
	_class_back.text = "Back"
	_class_back.position = Vector2(24, 30)
	_class_back.custom_minimum_size = Vector2(120, 44)
	_class_back.add_theme_font_size_override("font_size", 19)
	_class_back.pressed.connect(_close_panels)
	_class_panel.add_child(_class_back)

	_build_fighter_detail()
	_build_demo_caption()


func _fighter_card(id: String) -> Control:
	var info: Dictionary = GameState.CLASSES[id]
	var accent := GameState.fighter_color(id)
	var card := Panel.new()
	card.size = CARD_SIZE
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.07, 0.065, 0.09), accent.darkened(0.25), 2, 12))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var art := TextureRect.new()
	art.texture = load("res://art/fighter_%s.jpg" % id)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(2, 2)
	art.size = Vector2(CARD_SIZE.x - 4, 330)
	card.add_child(art)
	# Fade the art into the card.
	var fade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.07, 0.065, 0.09, 0.0))
	gradient.set_color(1, Color(0.07, 0.065, 0.09, 1.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	fade.texture = texture
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(0, 200)
	fade.size = Vector2(CARD_SIZE.x, 134)
	card.add_child(fade)
	var level := _card_text("", 15, Color.WHITE)
	level.position = Vector2(CARD_SIZE.x - 70, 12)
	level.size = Vector2(56, 24)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card.add_child(level)
	var badge := _card_text("PLAYING", 14, Color(0.1, 0.07, 0.02))
	var badge_box := PanelContainer.new()
	badge_box.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD, Color.TRANSPARENT, 0, 4, 4.0))
	badge_box.position = Vector2(12, 12)
	badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_box.add_child(badge)
	card.add_child(badge_box)
	# "THE" above the name, for the fighters who go by a title (not Tony).
	var the := _card_text("THE", 22, accent.lightened(0.1))
	the.position = Vector2(18, 268)
	the.visible = String(info.fighter).begins_with("The ")
	card.add_child(the)
	var name_label := _card_text(String(info.fighter).trim_prefix("The ").to_upper(), 54, accent.lightened(0.12))
	name_label.add_theme_constant_override("outline_size", 12)
	name_label.add_theme_font_override("font", UiTheme.display_font())
	the.add_theme_font_override("font", UiTheme.display_font())
	name_label.position = Vector2(14, 286)
	card.add_child(name_label)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.box(Color(accent.darkened(0.7), 0.6), Color(accent, 0.6), 1, 8, 5.0))
	tag.position = Vector2(18, 360)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(_card_text(String(info.name).to_upper(), 14, accent.lightened(0.3)))
	card.add_child(tag)
	var traits: Array = info.traits
	for t in traits.size():
		var row_y := 404.0 + t * 46.0
		var icon := IconView.new()
		icon.icon = traits[t][0]
		icon.color = accent
		icon.tile_color = Color(0, 0, 0, 0.3)
		icon.border_color = accent.darkened(0.2)
		icon.position = Vector2(18, row_y)
		icon.size = Vector2(36, 36)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		var trait_name := _card_text(traits[t][1], 18, Color.WHITE)
		trait_name.add_theme_font_override("font", UiTheme.bold_font())
		trait_name.position = Vector2(64, row_y - 3)
		card.add_child(trait_name)
		var trait_line := _card_text(traits[t][2], 14, Color(0.8, 0.78, 0.84))
		trait_line.position = Vector2(64, row_y + 19)
		card.add_child(trait_line)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pick_fighter(id))
	# Hover: grows 3% about its middle. The pivot stays at the corner (moving
	# it on a shrunk card shifted the card for good: two rows, 2026-10-29), so
	# it slides up-left by half the growth instead.
	card.mouse_entered.connect(func() -> void:
		if _picked == "":
			var home: Vector2 = _cards[id].home
			var hover := card.create_tween().set_parallel()
			hover.tween_property(card, "scale", Vector2.ONE * 1.03 * _card_scale, 0.1)
			hover.tween_property(card, "position", home - card.size * _card_scale * 0.015, 0.1)
			Sfx.play("whoosh", -18.0, 1.6))
	card.mouse_exited.connect(func() -> void:
		if _picked == "":
			var back := card.create_tween().set_parallel()
			back.tween_property(card, "scale", Vector2.ONE * _card_scale, 0.1)
			back.tween_property(card, "position", _cards[id].home, 0.1))
	_cards[id] = {"panel": card, "level": level, "badge": badge_box}
	return card


func _card_text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The panel beside the picked card: tagline, stat bars, the ultimate, and
## Back / Choose.
func _build_fighter_detail() -> void:
	# A dyed, see-through leather panel (StitchPanel), recolored for the picked
	# fighter (2026-11-06).
	_detail = StitchPanel.new(12.0)
	_detail.add_theme_stylebox_override("panel", StitchPanel.leather(12.0, 18.0))
	_detail.position = Vector2(_card_left + CARD_SIZE.x + 34, CARD_TOP + 8)
	_detail.custom_minimum_size = Vector2(470, 0)
	_detail.modulate.a = 0.0
	_detail.visible = false
	_class_panel.add_child(_detail)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	_detail.add_child(_detail_box)
	_detail_tagline = _card_text("", 30, Color.WHITE)
	_detail_tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_tagline.custom_minimum_size.x = 430
	_detail_tagline.add_theme_constant_override("outline_size", 10)
	_detail_tagline.add_theme_font_override("font", UiTheme.display_font())
	_detail_box.add_child(_detail_tagline)
	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 6)
	_detail_box.add_child(_detail_stats)
	# The perk: a stitched strip with a PERK tag in the fighter's color.
	_detail_perk_box = StitchPanel.new(9.0)
	_detail_box.add_child(_detail_perk_box)
	var perk_row := HBoxContainer.new()
	perk_row.add_theme_constant_override("separation", 12)
	_detail_perk_box.add_child(perk_row)
	_detail_perk_tag = PanelContainer.new()
	_detail_perk_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_perk_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_perk_name = _card_text("", 20, Color(0.1, 0.06, 0.02))
	_detail_perk_name.add_theme_constant_override("outline_size", 0)
	_detail_perk_name.add_theme_font_override("font", UiTheme.display_font())
	_detail_perk_tag.add_child(_detail_perk_name)
	perk_row.add_child(_detail_perk_tag)
	_detail_perk_lines = VBoxContainer.new()
	_detail_perk_lines.add_theme_constant_override("separation", 0)
	_detail_perk_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_perk_lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	perk_row.add_child(_detail_perk_lines)
	var ult_box := VBoxContainer.new()
	ult_box.add_theme_constant_override("separation", 2)
	_detail_box.add_child(ult_box)
	_detail_ult_tag = _card_text("ULTIMATE", 15, UiTheme.GOLD)
	ult_box.add_child(_detail_ult_tag)
	_detail_ult_name = _card_text("", 28, Color.WHITE)
	_detail_ult_name.add_theme_font_override("font", UiTheme.display_font())
	ult_box.add_child(_detail_ult_name)
	_detail_ult_how = _card_text("", 16, Color(0.85, 0.82, 0.9))
	_detail_ult_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_ult_how.custom_minimum_size.x = 430
	ult_box.add_child(_detail_ult_how)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	_detail_box.add_child(buttons)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(110, 46)
	back.add_theme_font_size_override("font_size", 19)
	back.pressed.connect(_unpick_fighter)
	buttons.add_child(back)
	_choose_button = Button.new()
	_choose_button.theme_type_variation = "PrimaryButton"
	_choose_button.custom_minimum_size = Vector2(300, 46)
	_choose_button.add_theme_font_size_override("font_size", 19)
	_choose_button.pressed.connect(_choose_picked)
	buttons.add_child(_choose_button)
	# The tab that hides the panel (the card stays) so the whole clip shows,
	# and brings it back. Big enough for a thumb.
	_detail_tab = Button.new()
	_detail_tab.text = "<"
	_detail_tab.size = Vector2(44, 88)
	_detail_tab.custom_minimum_size = Vector2(44, 88)
	_detail_tab.focus_mode = Control.FOCUS_NONE
	_detail_tab.add_theme_font_override("font", UiTheme.display_font())
	_detail_tab.add_theme_font_size_override("font_size", 30)
	_detail_tab.add_theme_constant_override("outline_size", 8)
	_detail_tab.add_theme_color_override("font_outline_color", Color.BLACK)
	_detail_tab.visible = false
	_detail_tab.pressed.connect(_toggle_stats)
	_class_panel.add_child(_detail_tab)


## Along the bottom right, over the reel: which move is playing.
func _build_demo_caption() -> void:
	_caption = VBoxContainer.new()
	_caption.add_theme_constant_override("separation", 2)
	_caption.position = Vector2(820, 548)
	_caption.size = Vector2(430, 0)
	_caption.modulate.a = 0.0
	_class_panel.add_child(_caption)
	_caption_tag = _card_text("", 15, UiTheme.GOLD)
	_caption.add_child(_caption_tag)
	_caption_move = _card_text("", 34, Color.WHITE)
	_caption_move.add_theme_constant_override("outline_size", 10)
	_caption_move.add_theme_font_override("font", UiTheme.display_font())
	_caption.add_child(_caption_move)
	_caption_how = _card_text("", 15, Color(0.88, 0.86, 0.92))
	_caption_how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_how.custom_minimum_size.x = 430
	_caption.add_child(_caption_how)


func _on_demo_caption(tag: String, move: String, how: String) -> void:
	_caption_tag.text = tag.to_upper()
	_caption_move.text = move.to_upper()
	_caption_how.text = how
	_caption.modulate.a = 0.0
	_caption.create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)


func _pick_fighter(id: String) -> void:
	if _picked != "":
		return
	_picked = id
	var info: Dictionary = GameState.CLASSES[id]
	var accent := GameState.fighter_color(id)
	Sfx.play("hit", -8.0, 0.7)
	Sfx.play("whoosh", -10.0, 0.8)
	for card_id in _cards:
		var card: Control = _cards[card_id].panel
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tween := card.create_tween()
		if card_id == id:
			# Grows to full size as it slides (a bottom-row card would spill off the screen if it popped).
			tween.set_parallel()
			tween.tween_property(card, "position", Vector2(_card_left, CARD_TOP), CARD_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale", Vector2.ONE, CARD_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			tween.tween_property(card, "modulate:a", 0.0, 0.25)
			tween.tween_callback(card.hide)
	_class_heading.create_tween().tween_property(_class_heading, "modulate:a", 0.0, 0.25)
	_class_back.hide()
	# Details.
	_detail_tagline.text = String(info.tagline).to_upper()
	_detail.add_theme_stylebox_override("panel", StitchPanel.leather(12.0, 18.0, accent))
	for child in _detail_stats.get_children():
		child.queue_free()
	var stars: Dictionary = info.stars
	var row_index := 0
	for stat in GameState.STAR_STATS:
		var attribute: Dictionary = Attributes.LIST[stat]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_stats.add_child(row)
		var icon := IconView.new()
		icon.icon = attribute.icon
		icon.color = attribute.color
		icon.tile_color = Color(0, 0, 0, 0.35)
		icon.border_color = Color(1, 1, 1, 0.12)
		icon.custom_minimum_size = Vector2(30, 30)
		row.add_child(icon)
		var label := _card_text(String(attribute.name).to_upper(), 19, Color(0.94, 0.91, 0.96))
		label.add_theme_font_override("font", UiTheme.bold_font())
		label.custom_minimum_size.x = 118
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var rating := StarRating.new()
		rating.count = int(stars.get(stat, 3))
		rating.color = accent.lightened(0.15)
		rating.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(rating)
		rating.pop(0.35 + 0.06 * row_index)
		row_index += 1
	_detail_perk_name.text = String(info.perk.name).to_upper()
	for child in _detail_perk_lines.get_children():
		child.queue_free()
	for line in info.perk.pros:
		_detail_perk_lines.add_child(_perk_line(line, UiTheme.GOOD))
	for line in info.perk.cons:
		_detail_perk_lines.add_child(_perk_line(line, UiTheme.BAD))
	_detail_perk_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0, 0, 0, 0.3), Color(accent, 0.6), 1, 9, 10.0))
	_detail_perk_tag.add_theme_stylebox_override("panel", UiTheme.box(accent, Color.TRANSPARENT, 0, 5, 5.0))
	_detail_ult_tag.add_theme_color_override("font_color", accent)
	# The ultimate they have on, not always the first.
	var ult := Abilities.info(id, GameState.ultimate(id))
	_detail_ult_name.text = String(ult.get("name", Ult.NAMES[id])).to_upper()
	_detail_ult_how.text = ult.get("desc", Ult.DESCRIPTIONS[id])
	_choose_button.text = "Choose %s" % info.fighter
	_detail.visible = true
	_detail.position.x = _card_left + CARD_SIZE.x + 64
	var detail_tween := _detail.create_tween().set_parallel()
	detail_tween.tween_property(_detail, "modulate:a", 1.0, 0.3).set_delay(0.2)
	detail_tween.tween_property(_detail, "position:x", _card_left + CARD_SIZE.x + 34, 0.4).set_delay(0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_stats_tab(accent)
	# The reel.
	_demo.visible = true
	_demo.modulate.a = 0.0
	_demo.play(id)
	_demo.create_tween().tween_property(_demo, "modulate:a", 1.0, 0.5).set_delay(0.15)
	_demo_shade.create_tween().tween_property(_demo_shade, "modulate:a", 1.0, 0.4)


## One perk line: a pro in green or a con in red.
func _perk_line(text: String, color: Color) -> Label:
	var label := _card_text(text, 18, color.lightened(0.15))
	label.add_theme_font_override("font", UiTheme.bold_font())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260
	return label


## The tab on the panel's right edge, in the panel's leather, once the panel
## has its size.
func _show_stats_tab(accent: Color) -> void:
	_stats_hidden = false
	_detail_tab.text = "<"
	var style := StitchPanel.leather(10.0, 0.0, accent)
	style.bg_color = Color(style.bg_color, 0.92)
	style.corner_radius_top_left = 0
	style.corner_radius_bottom_left = 0
	style.border_width_left = 0
	for state in ["normal", "hover", "pressed", "focus"]:
		var look := style.duplicate() as StyleBoxFlat
		if state == "hover":
			look.bg_color = look.bg_color.lightened(0.12)
		elif state == "pressed":
			look.bg_color = look.bg_color.darkened(0.15)
		_detail_tab.add_theme_stylebox_override(state, look)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_detail_tab.add_theme_color_override(color_name, accent.lightened(0.3))
	_detail_tab.modulate.a = 0.0
	_detail_tab.visible = true
	# Containers settle over a couple of frames; place it once they have.
	await get_tree().process_frame
	await get_tree().process_frame
	if _picked == "":
		return
	_detail_tab.position = _stats_tab_spot()
	_detail_tab.create_tween().tween_property(_detail_tab, "modulate:a", 1.0, 0.3).set_delay(0.3)


## Where the tab sits: on the panel's right edge, or on the card's when the
## panel is hidden; level with the panel's middle either way.
func _stats_tab_spot() -> Vector2:
	var y := _detail.position.y + _detail.size.y / 2.0 - _detail_tab.size.y / 2.0
	if _stats_hidden:
		return Vector2(_card_left + CARD_SIZE.x, y)
	return Vector2(_card_left + CARD_SIZE.x + 34 + _detail.get_combined_minimum_size().x - 2.0, y)


## Hides the stats panel to show the clip, or brings it back.
func _toggle_stats() -> void:
	if _picked == "":
		return
	_stats_hidden = not _stats_hidden
	Sfx.play("whoosh", -14.0, 1.4 if _stats_hidden else 1.1)
	_detail_tab.text = ">" if _stats_hidden else "<"
	var home := _card_left + CARD_SIZE.x + 34
	var tween := create_tween().set_parallel()
	tween.tween_property(_detail_tab, "position", _stats_tab_spot(), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _stats_hidden:
		_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tween.tween_property(_detail, "modulate:a", 0.0, 0.25)
		tween.tween_property(_detail, "position:x", home - 60.0, 0.3).set_trans(Tween.TRANS_CUBIC)
		tween.chain().tween_callback(func() -> void:
			if _stats_hidden:
				_detail.hide())
	else:
		_detail.show()
		_detail.mouse_filter = Control.MOUSE_FILTER_STOP
		tween.tween_property(_detail, "modulate:a", 1.0, 0.3)
		tween.tween_property(_detail, "position:x", home, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _unpick_fighter() -> void:
	if _picked == "":
		return
	var id := _picked
	_picked = ""
	_stats_hidden = false
	_detail_tab.hide()
	Sfx.play("whoosh", -10.0, 1.2)
	for card_id in _cards:
		var card: Control = _cards[card_id].panel
		var tween := card.create_tween()
		if card_id == id:
			tween.tween_property(card, "position", _cards[card_id].home, CARD_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(card, "scale", Vector2.ONE * _card_scale, CARD_SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.show()
			tween.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.2)
		tween.tween_callback(func() -> void: card.mouse_filter = Control.MOUSE_FILTER_STOP)
	_class_heading.create_tween().tween_property(_class_heading, "modulate:a", 1.0, 0.3).set_delay(0.2)
	_class_back.show()
	var detail_tween := _detail.create_tween()
	detail_tween.tween_property(_detail, "modulate:a", 0.0, 0.2)
	detail_tween.tween_callback(_detail.hide)
	_caption.create_tween().tween_property(_caption, "modulate:a", 0.0, 0.2)
	_demo_shade.create_tween().tween_property(_demo_shade, "modulate:a", 0.0, 0.3)
	var demo_tween := _demo.create_tween()
	demo_tween.tween_property(_demo, "modulate:a", 0.0, 0.3)
	demo_tween.tween_callback(func() -> void:
		if _picked == "":
			_demo.stop()
			_demo.hide())


## Snaps the picker back to its four cards (when it's closed).
func _reset_picker() -> void:
	_picked = ""
	_demo.stop()
	_demo.hide()
	_demo_shade.modulate.a = 0.0
	_detail.hide()
	_stats_hidden = false
	_detail_tab.hide()
	_caption.modulate.a = 0.0
	_class_heading.modulate.a = 1.0
	_class_back.show()
	for card_id in _cards:
		var card: Control = _cards[card_id].panel
		card.position = _cards[card_id].home
		card.modulate.a = 1.0
		card.scale = Vector2.ONE * _card_scale
		card.show()
		card.mouse_filter = Control.MOUSE_FILTER_STOP


func _choose_picked() -> void:
	if _picked == "":
		return
	GameState.set_player_class(_picked)
	Sfx.play("counter", -6.0, 1.1)
	_refresh_class()
	if _onboarding:
		_reset_picker()
		_show_mode_offer()
	else:
		_close_panels()


func _card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 230
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


# --- Menu actions -----------------------------------------------------------------

func _on_play() -> void:
	if _leaving:
		return
	if not GameState.onboarded:
		# First time: pick a fighter, then the tutorial offer.
		_onboarding = true
		_open_classes()
		return
	_go_to("res://camp.tscn")


func _go_to(scene: String) -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play("wave", -8.0, 0.7)
	Sfx.stop_ambience()
	GameState.save_game()
	Loading.go(scene)


## The screen got wider or narrower (a phone turning, a window resized): slide
## the fighter screen to stay centred.
func _recentre_classes() -> void:
	var now := maxf(0.0, (get_viewport().get_visible_rect().size.x - 1280.0) / 2.0)
	var delta := now - _class_ox
	if is_zero_approx(delta) or _class_panel == null:
		return
	_class_ox = now
	_class_heading.position.x += delta
	_card_left += delta
	for id in _cards:
		_cards[id].home.x += delta
		(_cards[id].panel as Control).position.x += delta
	if _detail:
		_detail.position.x += delta
	if _detail_tab:
		_detail_tab.position.x += delta


func _open_classes() -> void:
	_refresh_class()
	_reset_picker()
	_class_heading.text = "CHOOSE YOUR FIRST FIGHTER" if _onboarding else "CHOOSE YOUR FIGHTER"
	# Darker than for settings: the cards fill the screen, and the logo and
	# menu showing through behind them is clutter.
	_overlay.color.a = 0.95
	_overlay.visible = true
	_class_panel.visible = true
	_class_panel.modulate.a = 0.0
	_class_panel.create_tween().tween_property(_class_panel, "modulate:a", 1.0, 0.2)


func _open_credits() -> void:
	Credits.open(self)


func _open_settings() -> void:
	WebField.suspended = false
	_overlay.visible = true
	_settings_holder.visible = true
	_settings_holder.modulate.a = 0.0
	_settings_holder.create_tween().tween_property(_settings_holder, "modulate:a", 1.0, 0.2)


func _close_panels() -> void:
	# Opened from camp: leaving the picker goes back there, not to the menu.
	if _from_camp and _class_panel.visible and not _leaving:
		_from_camp = false
		_reset_picker()
		_go_to("res://camp.tscn")
		return
	if _class_panel.visible:
		_reset_picker()
	_onboarding = false
	_overlay.visible = false
	_overlay.color.a = 0.78
	_class_panel.visible = false
	_settings_holder.visible = false
	_tutorial_offer.visible = false
	_mode_offer.visible = false


# --- First start: control mode -----------------------------------------------------

## How dodging works (Settings, Controls, Mode), picked once on the first start.
func _build_mode_offer() -> void:
	_mode_offer = CenterContainer.new()
	_mode_offer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_offer.visible = false
	_ui.add_child(_mode_offer)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 640
	panel.add_theme_stylebox_override("panel", UiTheme.card(30.0))
	_mode_offer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UiTheme.heading("HOW DO YOU DODGE?", 40))
	for mode in [
		["junior", "WEENIE HUT JUNIOR MODE", ("Swipe out or down to dodge." if Controls.touch() else "Q / E dodge.") + " The game picks the right move."],
		["pro", "PRO GAMER MODE", "Slip, roll and back step yourself."],
	]:
		var pick := Button.new()
		pick.text = "%s\n%s" % [mode[1], mode[2]]
		pick.theme_type_variation = "PrimaryButton" if mode[0] == "junior" else ""
		pick.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pick.custom_minimum_size = Vector2(580, 70)
		pick.add_theme_font_size_override("font_size", 18)
		pick.pressed.connect(_choose_mode.bind(mode[0]))
		column.add_child(pick)
	var note := _card_label("You can change this any time in Settings, Controls.", 18, UiTheme.GOLD)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.x = 580
	column.add_child(note)


func _show_mode_offer() -> void:
	_class_panel.visible = false
	_mode_offer.visible = true
	_mode_offer.modulate.a = 0.0
	_mode_offer.create_tween().tween_property(_mode_offer, "modulate:a", 1.0, 0.2)


func _choose_mode(mode: String) -> void:
	Settings.set_value("assist_mode", mode)
	_mode_offer.visible = false
	_show_tutorial_offer()


# --- First start: tutorial offer ----------------------------------------------------

func _build_tutorial_offer() -> void:
	_tutorial_offer = CenterContainer.new()
	_tutorial_offer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tutorial_offer.visible = false
	_ui.add_child(_tutorial_offer)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 600
	panel.add_theme_stylebox_override("panel", UiTheme.card(30.0))
	_tutorial_offer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	column.add_child(UiTheme.heading("LEARN TO FIGHT THE DEAD?", 40))
	var text := _card_label("The basics on a dummy, then a few real monsters.", 18, UiTheme.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 540
	column.add_child(text)
	var play := Button.new()
	play.text = "Play the tutorial"
	play.theme_type_variation = "PrimaryButton"
	play.custom_minimum_size.y = 50
	play.add_theme_font_size_override("font_size", 20)
	play.pressed.connect(_finish_onboarding.bind("res://training.tscn"))
	column.add_child(play)
	var skip := Button.new()
	skip.text = "Skip"
	skip.custom_minimum_size.y = 44
	skip.add_theme_font_size_override("font_size", 18)
	skip.pressed.connect(_finish_onboarding.bind("res://camp.tscn"))
	column.add_child(skip)


func _show_tutorial_offer() -> void:
	Sfx.play("hit", -6.0, 0.8)
	_class_panel.visible = false
	_tutorial_offer.visible = true
	_tutorial_offer.modulate.a = 0.0
	_tutorial_offer.create_tween().tween_property(_tutorial_offer, "modulate:a", 1.0, 0.2)


func _finish_onboarding(scene: String) -> void:
	GameState.onboarded = true
	_go_to(scene)


func _on_quit() -> void:
	GameState.save_game()
	get_tree().quit()


# --- Helpers ----------------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.rotation = rot
	parent.add_child(instance)
	return instance


func _material(color: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.9
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


## A round gradient from inner (center) to outer (edges).
func _radial_texture(inner: Color, outer: Color, inner_stop := 0.0) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	if inner_stop > 0.0:
		gradient.add_point(inner_stop, inner)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
