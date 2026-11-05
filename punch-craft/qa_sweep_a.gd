extends Node
## QA tool: run with SWEEP_OUT=<folder> and --resolution WxH; see GAME_DESIGN.md, QA pass 2.
## UI sweep A: title, fighter picker, settings tabs, credits, offers, camp pages,
## camp popups. SWEEP_W / SWEEP_H pick the window. Shots go to SWEEP_OUT.
var out := OS.get_environment("SWEEP_OUT")


func _s(name: String, frames := 30) -> void:
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.tutorial_done = true
	GameState.onboarded = true
	GameState.nights_cleared = 3
	GameState.crypt_unlocked = true
	GameState.crypt_reveal_pending = false
	GameState.tony_unlocked = true
	GameState.fighters_bought["elementalist"] = true
	GameState.resources["coins"] = 1240
	GameState.souls = 30
	GameState.arena_bouts = {"1": 3, "2": 1}
	for tip in ["ability_", "arena_intro", "attribute_points", "crypt_gilding", "dead_league", "first_upgrade", "hat_first", "hat_rack", "hat_rack_tour", "power_select", "sweep_tip"]:
		GameState.tips_seen[tip] = true
	GameState.armory.clear()
	for pick in [["drowned", "gloves", "rare"], ["deadweight", "wraps", "epic"], ["dead_money", "boots", "uncommon"], ["drowned", "charm", "legendary"], ["deadweight", "gloves", "common"]]:
		var set_id: String = pick[0] if ItemModels.SETS.has(pick[0]) else ItemModels.SETS.keys()[0]
		GameState.add_to_armory(Gear.make(set_id, pick[1], pick[2], 3))
	GameState.equip_from_armory(int(GameState.armory[0].uid))
	GameState.hats = {"party_hat": 1, "bucket": 2, "wig_blue": 1, "coffin_crown": 1}
	await _title()
	await _camp()
	get_tree().quit()


func _title() -> void:
	var title: Node = (load("res://title.tscn") as PackedScene).instantiate()
	add_child(title)
	await _s("t01_menu", 340)
	title.call("_open_classes")
	await _s("t02_picker", 40)
	title.call("_pick_fighter", "elementalist")
	await _s("t03_picked", 90)
	title.call("_unpick_fighter")
	await _frames(40)
	title.call("_close_panels")
	title.call("_open_settings")
	var panel: Node = title.get("_settings_holder").get_child(0) if title.get("_settings_holder").get_child_count() > 0 else null
	var settings: SettingsPanel = _find_settings(title)
	for tab in ["SOUND", "CONTROLS", "DISPLAY", "SAVE DATA", "CODES"]:
		if settings:
			settings.call("_show_tab", tab, false)
		await _s("t04_settings_%s" % tab.replace(" ", "_"), 20)
	title.call("_close_panels")
	Credits.open(title)
	await _s("t05_credits", 40)
	for c in get_tree().root.find_children("*", "Credits", true, false):
		c.queue_free()
	title.call("_close_panels")
	title.call("_show_mode_offer")
	await _s("t06_mode_offer", 25)
	title.call("_close_panels")
	title.call("_show_tutorial_offer")
	await _s("t07_tutorial_offer", 25)
	title.call("_close_panels")
	var unlock := TonyUnlock.open(get_tree(), "wise_guy")
	await _s("t08_unlock_tony", 80)
	unlock.queue_free()
	title.queue_free()
	await _frames(5)


func _find_settings(node: Node) -> SettingsPanel:
	for n in node.find_children("*", "SettingsPanel", true, false):
		return n
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _camp() -> void:
	var camp: Node = (load("res://camp.tscn") as PackedScene).instantiate()
	add_child(camp)
	await _frames(100)
	for page in ["Home", "Attributes", "Upgrades", "Armory", "Cosmetics", "Shop", "Bounties"]:
		camp.call("_show_page", page)
		await _s("c01_page_%s" % page, 30)
	camp.call("_show_page", "Attributes")
	camp.call("_set_fighter_tab", "deck")
	await _s("c02_fighter_deck", 30)
	camp.call("_set_fighter_tab", "attributes")
	for tab in ["Emotes", "Hand Idles", "Skins"]:
		camp.call("_show_page", "Cosmetics")
		camp.call("_show_cosmetic", tab)
		await _s("c03_style_%s" % tab.replace(" ", "_"), 30)
	camp.call("_show_page", "Home")
	await _frames(20)
	camp.call("_open_loadout")
	await _s("c04_loadout", 30)
	camp.call("_close_loadout")
	camp.call("_pick_division")
	await _s("c05_pick_arena", 70)
	var picker: PlayPicker = camp.get("_picker")
	if picker:
		picker.close()
		await _frames(40)
	camp.call("_pick_crypt_floors")
	await _s("c06_pick_crypt", 70)
	picker = camp.get("_picker")
	if picker:
		picker.close()
		await _frames(40)
	camp.call("_pick_drill")
	await _s("c07_pick_drills", 70)
	picker = camp.get("_picker")
	if picker:
		picker.close()
		await _frames(40)
	GameDialog.open(camp, "ERASE EVERYTHING?", "This can't be undone.", ["Erase", "Cancel"])
	await _s("c08_dialog", 40)
	for d in camp.find_children("*", "GameDialog", true, false):
		d.queue_free()
	for d in get_tree().root.find_children("*", "GameDialog", true, false):
		d.queue_free()
	await _frames(10)
	Tutorial.open(camp, "sweep_tip", "SAMPLE TIP", "This is what a tip looks like. It points at something and waits for you.", camp.get("_tab_buttons")["Shop"], Callable(), false)
	await _s("c09_tip", 40)
	Toast.show_on(get_tree(), "BOUNTY DONE:  KNOCK OUT 20 MONSTERS", "+300 coins   +22 bounty XP")
	await _s("c10_toast", 30)
	HatPopup.open(get_tree(), "wig_blue")
	await _s("c11_hat_popup", 60)
	camp.queue_free()
