extends Node
## Store-page shots. SH_MODE picks the shot, SH_OUT the file.
func _put(prop: String, value: Variant) -> void:
	if GameState.get(prop) != null:
		GameState.set(prop, value)
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
func _snap() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SH_OUT"))
	print("SHOT ", img.get_size())
func _state() -> void:
	_put("tutorial_done", true)
	_put("onboarded", true)
	_put("nights_cleared", 3)
	_put("crypt_unlocked", true)
	_put("crypt_reveal_pending", false)
	_put("player_class", OS.get_environment("SH_CLASS") if OS.get_environment("SH_CLASS") != "" else "berserker")
	_put("tony_unlocked", false)
	GameState.fighters_bought.erase("elementalist")
	GameState.resources["coins"] = 1240
	_put("souls", 30)
	_put("arena_bouts", {"1": 3, "2": 1})
	GameState.tips_seen = {}
	for tip in ["arena_intro", "arena_done", "first_upgrade", "dead_league", "attribute_points", "crypt_gilding", "hat_first", "hat_rack", "hat_rack_tour", "power_select", "ability_new", "ability_"]:
		GameState.tips_seen[tip] = true
	GameState.armory.clear()
	for pick in [["drowned", "gloves", "rare"], ["deadweight", "wraps", "epic"], ["dead_money", "boots", "uncommon"], ["drowned", "charm", "legendary"], ["deadweight", "gloves", "common"]]:
		var set_id: String = pick[0] if ItemModels.SETS.has(pick[0]) else ItemModels.SETS.keys()[0]
		GameState.add_to_armory(Gear.make(set_id, pick[1], pick[2], 3))
	if not GameState.armory.is_empty():
		GameState.equip_from_armory(int(GameState.armory[0].uid))
	GameState.hats = {"party_hat": 1, "bucket": 2, "wig_blue": 1, "coffin_crown": 1}
func _arena() -> Node:
	_put("arena_division", 1)
	_put("arena_bout_pick", 2)
	var arena: Node = preload("res://world.tscn").instantiate()
	add_child(arena)
	arena.get_node("Player").set("invulnerable", true)
	return arena
func _face_nearest(arena: Node) -> void:
	var player: Node3D = arena.get_node("Player")
	var best: Node3D = null
	for e in arena.get_node("Enemies").get_children():
		if e is Node3D and (best == null or e.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = e
	if best:
		player.look_at(Vector3(best.global_position.x, player.global_position.y, best.global_position.z))
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_state()
	var mode := OS.get_environment("SH_MODE")
	match mode:
		"title":
			add_child((load("res://title.tscn") as PackedScene).instantiate())
			await _frames(340)
		"emote":
			var hat := OS.get_environment("SH_HAT")
			var emote := OS.get_environment("SH_EMOTE")
			GameState.hats[hat] = 1
			GameState.worn_hat = hat
			GameState.emotes_bought[emote] = true
			GameState.emote_loadout = [emote]
			GameState.emote_loadout_set = true
			var arena := _arena()
			await _frames(900)
			var player: Player = arena.get_node("Player")
			player.global_position = Vector3(0, 0.1, 6)
			player.rotation = Vector3.ZERO
			player.call("start_emote", emote)
			var out := OS.get_environment("SH_OUT").trim_suffix(".png")
			for k in 7:
				for i in 14:
					player.call("start_emote", emote) if player.get("emote") == "" else null
					await get_tree().physics_frame
				await _frames(2)
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s_t%d.png" % [out, k])
			get_tree().quit()
			return
		"hatrack":
			for h in ["traffic_cone","lampshade","propeller_beanie","bucket","party_hat","chef_toque","fruit_hat","tinfoil_hat","witch_hat","pumpkin_helmet","paper_crown","viking_helmet","top_hat","shower_cap","bowler","wig_blue","wig_blonde","hard_hat","pirate_tricorn","straw_hat"]:
				GameState.hats[h] = 1
			GameState.worn_hat = "propeller_beanie"
			var camp: Node = (load("res://camp.tscn") as PackedScene).instantiate()
			add_child(camp)
			await _frames(110)
			camp.call("_show_page", "Cosmetics")
			await _frames(60)
		"emote_stage":
			GameState.hats["bucket"] = 1
			GameState.worn_hat = "bucket"
			GameState.emotes_bought["floss"] = true
			GameState.emotes_bought["horse_ride"] = true
			GameState.emotes_bought["take_the_l"] = true
			var camp: Node = (load("res://camp.tscn") as PackedScene).instantiate()
			add_child(camp)
			await _frames(110)
			camp.call("_show_page", "Cosmetics")
			camp.call("_show_cosmetic", "Emotes")
			await _frames(30)
			camp.get("_emote_stage").call("play", OS.get_environment("SH_EMOTE"))
			camp.call("_refresh_emotes")
			await _frames(45)
		"picker":
			var t: Node = (load("res://title.tscn") as PackedScene).instantiate()
			add_child(t)
			await _frames(60)
			t.call("_open_classes")
			await _frames(45)
		"fight", "ult":
			var arena := _arena()
			await _frames(1000)
			_face_nearest(arena)
			await _frames(8)
			if mode == "ult":
				var ult = arena.get_node("Player").get("ult")
				ult.set("meter", Ult.MAX_METER)
				ult.meter_changed.emit(Ult.MAX_METER, true)
				await _frames(90)
		"crypt":
			var crypt: Node = preload("res://dungeon.tscn").instantiate()
			add_child(crypt)
			await _frames(260)
		"warn":
			Settings.values["lock_on"] = "blend"
			var arena := _arena()
			await _frames(800)
			var player: Player = arena.get_node("Player")
			var forward := -player._camera.global_transform.basis.z
			forward.y = 0
			forward = forward.normalized()
			var right := forward.cross(Vector3.UP)
			var here := player.global_position + Vector3(0, 1.2, 0)
			var arrow := Arrow.new()
			arena.add_child(arrow)
			arrow.launch(here + right * 7.0 + Vector3(0, 0.1, 0), here, 6.0, 5.0)
			await _frames(75)
		_:
			var camp: Node = (load("res://camp.tscn") as PackedScene).instantiate()
			add_child(camp)
			await _frames(110)
			if mode != "camp_Home":
				camp.call("_show_page", mode.trim_prefix("camp_"))
				await _frames(50)
	await _snap()
	get_tree().quit()
