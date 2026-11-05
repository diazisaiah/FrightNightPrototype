extends Node
## QA tool: run with SWEEP_OUT=<folder> and --resolution WxH; see GAME_DESIGN.md, QA pass 2.
var out := OS.get_environment("SWEEP_OUT")
func _s(name: String, frames := 25) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func _gear(rarity: String, slot: String) -> Dictionary:
	return Gear.make("drowned" if ItemModels.SETS.has("drowned") else ItemModels.SETS.keys()[0], slot, rarity, 4)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.nights_cleared = 3
	GameState.arena_division = 1
	GameState.arena_bouts = {"1": 1}
	GameState.arena_bout_pick = 2
	GameState.tutorial_done = true
	GameState.onboarded = true
	for tip in ["arena_intro", "arena_done", "first_upgrade", "dead_league", "attribute_points", "crypt_gilding", "hat_first", "ability_", "hat_rack", "hat_rack_tour", "power_select"]:
		GameState.tips_seen[tip] = true
	GameState.equip(_gear("rare", "gloves"))
	GameState.equip(_gear("epic", "wraps"))
	var arena: Node = preload("res://world.tscn").instantiate()
	add_child(arena)
	var player: Node = arena.get_node("Player")
	player.set("invulnerable", true)
	var hud: Hud = arena.get_node("HUD")
	for i in 420:
		await get_tree().process_frame
	await _s("f01_fight", 5)
	hud.set_paused(true)
	await _s("f02_pause_menu")
	hud.call("_show_pause_page", "CONTROLS")
	await _s("f03_pause_controls")
	hud.call("_show_pause_page", "MENU")
	hud.set_paused(false)
	await get_tree().process_frame
	hud.show_item_offer(_gear("epic", "boots"), GameState.equipped.get("boots", {}), 120)
	await _s("f04_item_offer", 40)
	hud.call("_close_item_panel")
	hud.show_gild_menu([{"item": GameState.equipped.gloves, "souls": 0, "silver": 25, "gilded": false, "affordable": true}, {"item": GameState.equipped.wraps, "souls": 0, "silver": 40, "gilded": true, "affordable": true}], 90)
	await _s("f05_gild", 40)
	hud.call("_close_item_panel")
	hud.show_merchant([{"item": _gear("legendary", "charm"), "price": 120, "sold": false}, {"item": _gear("uncommon", "boots"), "price": 35, "sold": false}, {"item": _gear("rare", "gloves"), "price": 60, "sold": true}], {"price": 30, "percent": 50, "used": false}, 140, "Ask about the toilet")
	await _s("f06_merchant", 40)
	hud.call("_close_item_panel")
	hud.show_worn_gear()
	await _s("f07_worn_gear", 40)
	hud.call("_close_item_panel")
	hud.show_results({"title": "BOUT 2 WON", "subtitle": "GRAVEDIGGER DIVISION", "grade": "A", "medals": [["CLEAN  x5", true], ["COUNTERS  x2", false], ["FULL ARSENAL", true], ["UNTOUCHED", false]], "rewards": {"coins": 420, "xp": 30, "souls": 2}, "note": "FIRST WIN BONUS  +300 COINS", "note_color": UiTheme.GOLD}, "Next bout", true)
	await _s("f08_results", 50)
	arena.queue_free()
	await get_tree().process_frame
	get_tree().quit()
