class_name WebBench
extends Node
## Browser benchmark: open the web build with ?bench in the URL. Visits each
## scene (a night with a crowd, the Crypt, camp, Dead League) and prints frame
## rate, worst frame, draw calls and the 3D resolution scale to the browser
## console. Uses its own save and settings, so a player's progress is safe.
## ?bench=fx instead fires each ultimate and power in a crowd (FX_ULTS,
## FX_POWERS) and prints the same numbers for each.

const SCENES := ["res://world.tscn", "res://dungeon.tscn", "res://camp.tscn", "res://dead_league_arena.tscn", "res://title.tscn"]
const SETTLE := 2.0
const MEASURE := 5.0

## [fighter, ultimate] for the fx pass; then each power, every half second.
const FX_ULTS := [["berserker", "inferno"], ["berserker", "bulwark"], ["counter_master", "riposte"], ["counter_master", "flow_state"],
	["combo_master", "temporal_break"], ["combo_master", "unbroken"], ["free_runner", "highlight_reel"], ["free_runner", "hype_train"],
	["wise_guy", "big_mouth"], ["wise_guy", "the_family"], ["elementalist", "elemental_fists"], ["elementalist", "flame_burst"]]
const FX_POWERS := ["fire", "frost", "chain", "pound", "quake", "cyclone", "doom", "blood", "pyre", "vinnie"]

static var running := false
static var fx := false


## Starts the bench if the page URL asks for it (title screen, web only).
static func start_if_requested(tree: SceneTree) -> bool:
	if running or not OS.has_feature("web"):
		return false
	var query = JavaScriptBridge.eval("window.location.search", true)
	if not (query is String and (query as String).contains("bench")):
		return false
	running = true
	fx = (query as String).contains("bench=fx")
	GameState.save_path = "user://bench_save.json"
	Settings.path = "user://bench_settings.cfg"
	var bench := Node.new()
	bench.set_script(load("res://web_bench.gd"))
	bench.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(bench)
	return true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.reset_progress()
	GameState.onboarded = true
	GameState.tutorial_done = true
	GameState.crypt_unlocked = true
	print("BENCH start  screen %s" % get_tree().root.size)
	if fx:
		await _fx_pass()
		print("BENCH done")
		return
	# Pass 1: the browser optimizations off (full resolution, every light on).
	# Pass 2: on (auto resolution, nearest lights only).
	for optimized in [false, true]:
		Settings.values["render_scale"] = "auto" if optimized else "full"
		Settings.light_budget = optimized
		if not optimized:
			for light in Settings._scenery_lights:
				if is_instance_valid(light):
					light.visible = true
		Settings.apply_render_scale()
		print("BENCH --- optimizations %s ---" % ("ON" if optimized else "OFF"))
		await _pass()
	print("BENCH done")


func _pass() -> void:
	for scene in SCENES:
		get_tree().change_scene_to_file(scene)
		await get_tree().create_timer(0.5).timeout
		var player = get_tree().current_scene.get("_player")
		if player:
			player.max_knuckles = 9000.0
			player.knuckles = 9000.0
		if scene == "res://world.tscn" and player:
			_crowd(player)
		await get_tree().create_timer(SETTLE).timeout
		await _measure(scene.get_file().get_basename())


func _fx_pass() -> void:
	var player := await _fx_scene("berserker", "inferno")
	await _measure("crowd")
	for pair in FX_ULTS:
		player = await _fx_scene(pair[0], pair[1])
		player.ult.fill()
		player.ult.activate()
		await _measure(pair[1])
	player = await _fx_scene("elementalist", "flame_burst")
	for power in FX_POWERS:
		var timer := Timer.new()
		timer.wait_time = 0.5
		timer.timeout.connect(func() -> void: _fire(power, player))
		add_child(timer)
		timer.start()
		_fire(power, player)
		await _measure(power)
		timer.queue_free()


## The fighter with that ultimate, every upgrade maxed, in a night with a
## crowd that can't go down.
func _fx_scene(fighter: String, ult: String) -> Player:
	GameState.reset_progress()
	GameState.onboarded = true
	GameState.tutorial_done = true
	GameState.set_player_class(fighter)
	GameState._classes[fighter].level = 60
	GameState.loadouts[fighter] = {"ultimate": ult}
	for id in GameState.UPGRADES:
		GameState.upgrade_levels[id] = int(GameState.UPGRADES[id].max_level)
	get_tree().change_scene_to_file("res://world.tscn")
	await get_tree().create_timer(0.5).timeout
	var player: Player = get_tree().current_scene.get("_player")
	player.invulnerable = true
	_crowd(player, 12, 100000.0)
	await get_tree().create_timer(SETTLE).timeout
	get_tree().paused = false
	return player


func _fire(power: String, player: Player) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Enemy) -> bool: return not e.is_dead())
	if enemies.is_empty():
		return
	var target: Enemy = enemies.pick_random()
	match power:
		"fire": Powers.fire_burst(target, 1.0)
		"frost": Powers.frost_burst(target, 0.5)
		"chain": Powers.chain_lightning(target, 1.0, 4)
		"pound": Powers.ground_pound(player, 1.0)
		"quake": Powers.ground_pound(player, 1.0, 5.0, true)
		"cyclone": Powers.cyclone(player)
		"doom": Powers.doom_mark(target)
		"blood": Powers.blood_drain(target, player)
		"pyre": Powers.pyre(target)
		"vinnie": target.get_parent().add_child(Goon.make(target, 2.0))


func _crowd(player: Node3D, count := 8, hp := 0.0) -> void:
	var holder := get_tree().current_scene.get_node_or_null("Enemies")
	for i in count:
		var enemy: Enemy = load("res://zombie.tscn" if i % 2 == 0 else "res://brawler.tscn").instantiate()
		enemy.setup(player, false)
		if hp > 0.0:
			enemy.max_hp = hp
			enemy.hp = hp
		enemy.position = player.global_position + Vector3(cos(i * 0.8), 0, sin(i * 0.8)) * (4.0 + i * 0.3)
		(holder if holder else get_tree().current_scene).add_child(enemy)


func _measure(label: String) -> void:
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var worst := 0
	var draws := 0.0
	while Time.get_ticks_usec() - start < int(MEASURE * 1000000.0):
		await get_tree().process_frame
		# A hidden browser tab pauses the game (focus out).
		if fx and get_tree().paused:
			get_tree().paused = false
		frames += 1
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	if fx:
		print("BENCH %-18s fps %5.1f  worst %5.1fms  draws %4d  nodes %d" % [label, frames / seconds, worst / 1000.0, draws / maxf(frames, 1), get_tree().get_node_count()])
		return
	print("BENCH %-18s fps %5.1f  worst %5.1fms  draws %4d  scale %.2f" % [
		label, frames / seconds, worst / 1000.0, draws / maxf(frames, 1), Settings.render_scale()])
