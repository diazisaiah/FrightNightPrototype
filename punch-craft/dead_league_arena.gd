extends Node3D
## Upgrade-free three-round boss bout using the game's real combat and HUD.

const BOSS_SCENE := preload("res://dead_league_boss.tscn")
## Far enough back that the whole boss is in view at the opening bell.
const BOSS_POSITION := Vector3(0, 0.05, -4.3)
## Seconds after the final knockdown before the results.
const VICTORY_LINGER := 2.6
const RING_CENTER := Vector3(0, 0, -1.5)
const RING_HALF_SIZE := 4.0
const RING_ROPE_HEIGHTS := [0.5, 0.85, 1.2]
const TORCH_COUNT := 8
const TORCH_RADIUS := 7.0
const ROUND_BREAK := 2.2
const CORNER_RECOVERY := 0.18

var _boss: DeadLeagueBoss
var _round := 1
var _elapsed := 0.0
var _damage_taken := 0.0
var _perfect_dodges := 0
var _counters := 0
var _grazes := 0
var _punch_types := {}
var _bout_finished := false
var _torches: Array[OmniLight3D] = []
var _torch_time := 0.0

@onready var _player: Player = $Player
@onready var _hud: Hud = $HUD


func _enter_tree() -> void:
	# Parent _enter_tree runs before the Player's _ready, so its max knuckles and
	# damage are normalized from the first frame instead of changing underneath it.
	GameState.begin_dead_league()


func _ready() -> void:
	# Each contender has a theme of their own.
	Sfx.play_music("boss_" + DeadLeagueRules.boss(GameState.dead_league_bout).id)
	Enemy.max_attackers = 1
	$Moon.shadow_enabled = Settings.get_value("shadows") and not Settings.use_web_profile()
	Look.tune_environment($WorldEnvironment.environment, "ring")
	_build_torches()
	_build_ring()
	_build_graveyard()
	Look.batch_meshes($Decorations, true)
	_connect_hud()
	_player.damage_taken.connect(func(amount: float) -> void: _damage_taken += amount)
	_player.dodged.connect(_on_dodged)
	_player.grazed.connect(func() -> void: _grazes += 1)
	_player.punch_connected.connect(_on_punch_connected)
	_player.knuckles_broken.connect(_on_knuckles_broken)
	_player.knuckles_changed.emit(_player.knuckles, _player.max_knuckles)
	_hud.set_progress_visible(false)
	_hud.get_node("%LevelPanel").visible = false
	_hud.set_leave_text("Forfeit bout")
	# The VS card first; the contender steps into the ring when it's done.
	_player.active = false
	var intro := VsIntro.play(self, GameState.dead_league_bout)
	await intro.finished
	if not is_inside_tree():
		return
	_player.active = true
	_hud.announce("ROUND 1")
	var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
	_hud.say(profile.name, DeadLeagueRules.taunt(GameState.dead_league_bout), profile.accent.lightened(0.3))
	_spawn_boss()


func _connect_hud() -> void:
	_player.knuckles_changed.connect(_hud.set_knuckles)
	_player.combo_changed.connect(_hud.set_combo)
	_hud.bind_ult(_player.ult)
	_player.attacked.connect(_hud.flash_damage.unbind(1))
	_player.dodged.connect(_hud.show_dodge)
	_player.grazed.connect(_hud.show_graze)
	_player.punch_landed.connect(_hud.hit_marker)
	_player.counter_ready_changed.connect(_hud.set_counter_ready)
	_player.class_status_changed.connect(_hud.set_class_status)
	_player.class_event.connect(_hud.show_class_event)
	_hud.end_run_requested.connect(_go_to_league)
	_hud.back_to_camp_requested.connect(_go_to_league)
	_hud.continue_requested.connect(_rematch)


func _process(delta: float) -> void:
	_torch_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 2.3 + sin(_torch_time * 10.0 + i * 1.7) * 0.28
	if _bout_finished or _boss == null:
		return  # Not during the VS card.
	_elapsed += delta
	var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
	_hud.set_info("ROUND %d" % _round)


func _spawn_boss() -> void:
	var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
	_boss = BOSS_SCENE.instantiate() as DeadLeagueBoss
	_boss.configure(GameState.dead_league_bout, _round)
	_boss.setup(_player, false)
	_boss.position = BOSS_POSITION
	_boss.arena_center = RING_CENTER
	_boss.arena_limit = RING_HALF_SIZE - 0.6
	$Enemies.add_child(_boss)
	_boss.died.connect(_on_boss_died)
	_boss.health_changed.connect(_hud.set_boss_health)
	_hud.show_boss(profile.name, _boss.hp, _boss.max_hp)


func _on_boss_died(_enemy: Enemy) -> void:
	if _bout_finished:
		return
	if _round >= DeadLeagueRules.ROUND_COUNT:
		# The last round: the bell, their last words, and a few seconds to
		# soak it in before the results.
		_bout_finished = true
		_player.invulnerable = true
		_hud.hide_boss()
		Sfx.play("bell")
		_hud.announce("K.O.!")
		var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
		await get_tree().create_timer(0.9).timeout
		if not is_inside_tree():
			return
		_hud.say("", DeadLeagueRules.DEFEAT_LINES[profile.id], profile.accent.lightened(0.35), 2.6)
		await get_tree().create_timer(VICTORY_LINGER).timeout
		if not is_inside_tree():
			return
		_player.active = false
		_finish_victory()
		return
	_player.active = false
	_hud.hide_boss()
	_hud.announce("ROUND %d WON" % _round)
	_round += 1
	await get_tree().create_timer(ROUND_BREAK).timeout
	if not is_inside_tree() or _bout_finished:
		return
	_player.prepare_bout_round(CORNER_RECOVERY)
	_player.global_position = Vector3(0, 0.1, 0)
	_player.rotation = Vector3.ZERO
	_hud.announce("ROUND %d" % _round)
	_hud.say(DeadLeagueRules.boss(GameState.dead_league_bout).name, DeadLeagueRules.taunt(GameState.dead_league_bout),
			DeadLeagueRules.boss(GameState.dead_league_bout).accent.lightened(0.3))
	_spawn_boss()


func _on_knuckles_broken() -> void:
	if _bout_finished:
		return
	_bout_finished = true
	_hud.knockout_fade()
	_player.knock_out()
	await get_tree().create_timer(Player.KNOCKOUT_TIME).timeout
	if not is_inside_tree():
		return
	if is_instance_valid(_boss):
		_boss.set_physics_process(false)
	var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
	_hud.show_results({
		"title": "KNOCKED OUT",
		"title_color": UiTheme.BAD,
		"subtitle": "%s   ·   ROUND %d" % [profile.name, _round],
	}, "Rematch", false, "League menu")


func _finish_victory() -> void:
	_bout_finished = true
	_player.invulnerable = false
	_hud.hide_boss()
	var stats := {
		"elapsed": _elapsed,
		"damage_taken": _damage_taken,
		"perfect_dodges": _perfect_dodges,
		"counters": _counters,
		"grazes": _grazes,
		"variety": _punch_types.size(),
		"max_knuckles": _player.max_knuckles,
		"power_ratio": float(PowerRating.player()) / maxf(PowerRating.contender(GameState.dead_league_bout), 1.0),
	}
	var points := DeadLeagueRules.score(stats)
	var grade := DeadLeagueRules.grade(points)
	var profile := DeadLeagueRules.boss(GameState.dead_league_bout)
	var first_clear := GameState.record_dead_league_result(profile.id, grade, points)
	var best := int(GameState.dead_league_best.get(profile.id, {}).get("score", 0)) == points
	var last := GameState.dead_league_bout + 1 >= DeadLeagueRules.BOSS_COUNT
	var note := "NEW PERSONAL BEST" if best else ""
	# How much the grade was scaled for your build against theirs.
	var factor := DeadLeagueRules.build_factor(stats.power_ratio)
	if absf(factor - 1.0) >= 0.03:
		var adjust := "UNDERDOG BONUS  +%d%%" % roundi((factor - 1.0) * 100.0) if factor > 1.0 else "OVERPOWERED  %d%%" % roundi((factor - 1.0) * 100.0)
		note = adjust if note == "" else note + "
" + adjust
	if first_clear:
		note = _seal_broken_text(GameState.dead_league_bout)
	_hud.show_results({
		"title": "THE CROWN IS YOURS" if first_clear and last else "VICTORY",
		"subtitle": "%s   ·   %s" % [profile.name, _format_time(_elapsed)],
		"grade": grade,
		"medals": [
			["CLEAN  x%d" % _perfect_dodges, _perfect_dodges >= 3],
			["COUNTERS  x%d" % _counters, _counters >= 3],
			["FULL ARSENAL", _punch_types.size() >= 4],
			["UNTOUCHED", _damage_taken <= 0.0],
		],
		"note": note,
	}, "Rematch", false, "League menu")


## What beating contender index broke open: "SEAL BROKEN: Ring 2 + FIRE ...".
func _seal_broken_text(index: int) -> String:
	var tier: Dictionary = Progression.TIERS[index]
	if index + 1 >= Progression.TIER_COUNT:
		return "YOUR SOUL IS YOUR OWN AGAIN\nTHE CROWN RING AND THE ENDLESS DARK ARE OPEN"
	var parts := ["RING %d" % (index + 2)]
	if tier.power != "":
		parts.append(tier.power)
	parts.append(String(GameState.UPGRADES[tier.trophy].name).to_upper())
	if DeadLeagueRules.boss(index).id == GameState.CRYPT_SEAL:
		parts.append("THE CRYPT")
	return "SEAL BROKEN\n%s\nNEXT:  %s" % ["   ·   ".join(parts), DeadLeagueRules.boss(index + 1).name]


func _on_dodged(move: String) -> void:
	if move.begins_with("clean_"):
		_perfect_dodges += 1


func _on_punch_connected(type: String, kind: String) -> void:
	if kind not in ["blocked", "evaded"]:
		_punch_types[type] = true
	if kind == "counter":
		_counters += 1


func _rematch() -> void:
	get_tree().paused = false
	Loading.reload()


func _go_to_league() -> void:
	get_tree().paused = false
	Loading.go("res://dead_league_menu.tscn")


func _exit_tree() -> void:
	GameState.end_dead_league()
	TimeFx.clear()


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 60.0), floori(seconds) % 60]


func _build_ring() -> void:
	var canvas := Enemy._material(Color(0.24, 0.24, 0.29))
	var post_material := Enemy._material(Color(0.12, 0.12, 0.15), 0.75)
	var rope_material := Enemy._material(Color(0.72, 0.08, 0.06))
	var ring := Node3D.new()
	ring.position = RING_CENTER
	$Decorations.add_child(ring)
	var size := RING_HALF_SIZE * 2.0
	_add_mesh(ring, Enemy._box(Vector3(size, 0.04, size)), canvas, Vector3(0, 0.02, 0))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_add_mesh(ring, Enemy._cylinder(0.08, 1.5), post_material, Vector3(x * RING_HALF_SIZE, 0.75, z * RING_HALF_SIZE))
	for height in RING_ROPE_HEIGHTS:
		for side in [-1.0, 1.0]:
			_add_mesh(ring, Enemy._box(Vector3(size, 0.045, 0.045)), rope_material, Vector3(0, height, side * RING_HALF_SIZE))
			_add_mesh(ring, Enemy._box(Vector3(0.045, 0.045, size)), rope_material, Vector3(side * RING_HALF_SIZE, height, 0))
	var walls := StaticBody3D.new()
	ring.add_child(walls)
	for side in [-1.0, 1.0]:
		for along_x in [true, false]:
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(size, 3.0, 0.2) if along_x else Vector3(0.2, 3.0, size)
			shape.shape = box
			shape.position = Vector3(0, 1.5, side * RING_HALF_SIZE) if along_x else Vector3(side * RING_HALF_SIZE, 1.5, 0)
			walls.add_child(shape)


## The key art's setting around the ring: an iron fence, rows of graves and
## dead trees, a glowing mausoleum behind the boss's corner, fire braziers
## hanging from posts, the moon, mist, and a spotlight over the canvas.
func _build_graveyard() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	var web := Settings.use_web_profile()
	var decor: Node3D = $Decorations
	($Ground/Mesh as MeshInstance3D).material_override = Look.block_material(Color(0.13, 0.15, 0.12))
	# Thin enough to see the graveyard, thick enough to fade it into the dark.
	var env: Environment = $WorldEnvironment.environment
	env.fog_density = 0.028
	env.ambient_light_energy = 0.42
	Scenery.night_sky(decor, rng, Vector3(18, 26, -60))
	Scenery.ground_patches(decor, 22.0, 24 if web else 40, rng)
	# Iron fence around the ring.
	# (A fence run goes along its own +X from its origin, so each side starts
	# half a side back along its direction.)
	for i in 4:
		var run := Scenery.fence(decor, 15.0)
		var angle := i * PI / 2.0
		var along := Vector3(cos(angle), 0, -sin(angle))
		var outward := along.cross(Vector3.UP)
		run.rotation.y = angle
		run.position = RING_CENTER + outward * 7.5 - along * 7.5
	# Graves in loose rows beyond the fence, and dead trees.
	for i in (22 if web else 40):
		var angle := rng.randf() * TAU
		var node := Node3D.new()
		node.position = RING_CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(8.5, 16.0)
		node.rotation.y = rng.randf_range(-0.3, 0.3) + angle + PI / 2.0
		decor.add_child(node)
		Scenery.gravestone(node, rng.randi_range(0, 5), rng)
	for i in (5 if web else 9):
		var angle := rng.randf() * TAU
		var node := Node3D.new()
		node.position = RING_CENTER + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(12.0, 18.0)
		decor.add_child(node)
		Scenery.dead_tree(node, rng, rng.randf_range(4.5, 7.5))
	# The mausoleum, its doorway burning, behind the boss.
	var mausoleum := Node3D.new()
	mausoleum.position = RING_CENTER + Vector3(0, 0, -14.0)
	mausoleum.scale = Vector3.ONE * 1.8
	decor.add_child(mausoleum)
	Scenery.crypt(mausoleum, rng)
	var doorway := Look.fire_light(Color(1.0, 0.45, 0.15), 2.5, 9.0, false)
	doorway.position = RING_CENTER + Vector3(0, 1.6, -11.5)
	decor.add_child(doorway)
	# Braziers hanging from tall posts at the four corners.
	var iron := Enemy._material(Color(0.12, 0.11, 0.12), 0.7)
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var post := RING_CENTER + Vector3(x * 6.2, 0, z * 6.2)
			_add_mesh(decor, Enemy._box(Vector3(0.18, 4.2, 0.18)), iron, post + Vector3(0, 2.1, 0))
			_add_mesh(decor, Enemy._box(Vector3(1.0, 0.12, 0.12)), iron, post + Vector3(-x * 0.45, 4.1, 0))
			var cage := post + Vector3(-x * 0.9, 3.0, 0)
			for k in 4:
				_add_mesh(decor, Enemy._box(Vector3(0.03, 1.0, 0.03)), iron, cage + Vector3(0, 0.55, 0) + Vector3(cos(k * PI / 2.0), 0, sin(k * PI / 2.0)) * 0.22)
			_add_mesh(decor, Enemy._box(Vector3(0.5, 0.06, 0.5)), iron, cage)
			Look.flame(decor, cage + Vector3(0, 0.12, 0), 0.9, not web)
			var light := Look.fire_light(Color(1.0, 0.5, 0.2), 2.4, 9.0, false)
			light.position = cage + Vector3(0, 0.5, 0)
			decor.add_child(light)
	Scenery.mist(decor, RING_CENTER + Vector3(0, 0.3, 0), Vector3(26, 0.3, 26), 14 if web else 30)
	# A spotlight straight down on the canvas, so the fighters read clearly.
	var spot := SpotLight3D.new()
	spot.position = RING_CENTER + Vector3(0, 8.0, 1.0)
	spot.rotation = Vector3(-PI / 2.0 + 0.1, 0, 0)
	spot.spot_angle = 38.0
	spot.spot_range = 14.0
	spot.light_energy = 2.2
	spot.light_color = Color(1.0, 0.92, 0.82)
	add_child(spot)


func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, material: Material, pos: Vector3) -> void:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


func _build_torches() -> void:
	var wood := Enemy._material(Color(0.2, 0.12, 0.07))
	var flame := Enemy._glow_material(Color(1.0, 0.38, 0.08))
	for i in TORCH_COUNT:
		var torch := Node3D.new()
		var spot := Vector2.from_angle(TAU * i / TORCH_COUNT) * TORCH_RADIUS
		torch.position = Vector3(spot.x + RING_CENTER.x, 0, spot.y + RING_CENTER.z)
		$Decorations.add_child(torch)
		_add_mesh(torch, Enemy._cylinder(0.055, 1.7), wood, Vector3(0, 0.85, 0))
		_add_mesh(torch, Enemy._box(Vector3(0.18, 0.28, 0.18)), flame, Vector3(0, 1.82, 0))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 1.82, 0)
		light.light_color = Color(1.0, 0.28, 0.06)
		light.light_energy = 2.3
		light.omni_range = 5.5
		torch.add_child(light)
		_torches.append(light)
