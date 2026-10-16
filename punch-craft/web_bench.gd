class_name WebBench
extends Node
## Browser benchmark: open the web build with ?bench in the URL. Visits each
## scene (a night with a crowd, the Crypt, camp, Dead League) and prints frame
## rate, worst frame, draw calls and the 3D resolution scale to the browser
## console. Uses its own save and settings, so a player's progress is safe.

const SCENES := ["res://world.tscn", "res://dungeon.tscn", "res://camp.tscn", "res://dead_league_arena.tscn", "res://title.tscn"]
const SETTLE := 2.0
const MEASURE := 5.0

static var running := false


## Starts the bench if the page URL asks for it (title screen, web only).
static func start_if_requested(tree: SceneTree) -> bool:
	if running or not OS.has_feature("web"):
		return false
	var query = JavaScriptBridge.eval("window.location.search", true)
	if not (query is String and (query as String).contains("bench")):
		return false
	running = true
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


func _crowd(player: Node3D) -> void:
	var holder := get_tree().current_scene.get_node_or_null("Enemies")
	for i in 8:
		var enemy: Enemy = load("res://zombie.tscn" if i % 2 == 0 else "res://brawler.tscn").instantiate()
		enemy.setup(player, false)
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
		frames += 1
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var seconds := (Time.get_ticks_usec() - start) / 1000000.0
	print("BENCH %-18s fps %5.1f  worst %5.1fms  draws %4d  scale %.2f" % [
		label, frames / seconds, worst / 1000.0, draws / maxf(frames, 1), Settings.render_scale()])
