class_name Hats
## The hat collection. Now and then an enemy spawns wearing a hat; uppercut
## it off (or finish the enemy with an uppercut) and it's yours, for a small
## permanent boost. Four legendary Yonker caps do nothing on their own; all
## four unlock Tony. Some are won, never dropped (TROPHIES): the Coffin Crown,
## a hat for maxing each power, and four legendaries for big milestones
## (check_awards). Hats are built from blocks, sized to the wearer's head.

## Share of enemies that spawn wearing a hat.
const HAT_CHANCE := 0.02
## Legendary share of hats: starts here and grows with every hat that spawns
## without being one (bad-luck protection), resetting when one does. Always a
## legendary you're missing. ~22 hats per legendary; at a 2% hat rate
## (2026-10-16) about 125 bouts for all four.
const LEGENDARY_BASE := 0.01
const LEGENDARY_STEP := 0.0025
const RARITY_WEIGHTS := {"common": 60.0, "uncommon": 25.0, "rare": 11.0, "epic": 4.0}
## Chance an uppercut pops the hat off (finishing with one always does).
const POP_CHANCE := {"common": 0.6, "uncommon": 0.45, "rare": 0.3, "epic": 0.2, "legendary": 0.12}
## Souls for a hat you already own.
const DUPLICATE_SOULS := {"common": 1, "uncommon": 2, "rare": 3, "epic": 5, "legendary": 10}
## Skeletons love the Fruit Hat: when one rolls a hat, this often it's that.
const SKELETON_FRUIT := 0.25
## Hats are built in head widths, times this (bigger reads better and funnier).
const SIZE := 1.4
const FRUIT_SIZE := 1.3
const LEGENDARIES := ["yonker_brim", "yonker_no_brim", "brim_no_yonker", "no_yonker_no_brim"]
## Won, never dropped: the Coffin Crown for beating the Coffin King (Ending),
## and the hats check_awards hands out.
const TROPHIES := ["coffin_crown", "fire_cap", "gale_flattop", "storm_ears", "iron_mask", "frost_tiara",
	"doom_mask", "blood_hairline", "quake_headband", "golden_quills", "bald_cap", "speed_mask", "wig_white",
	"fat_plumber_cap", "tall_plumber_cap", "very_tall_plumber_cap", "very_fat_plumber_cap"]
## The plumber quest's caps (the Hot Plumber Hat first): all five for the
## overalls skin and the jump emote.
const PLUMBER_CAPS := ["fire_cap", "fat_plumber_cap", "tall_plumber_cap", "very_tall_plumber_cap", "very_fat_plumber_cap"]
## The caps monsters wear in overalls (with the overalls' color). Only go
## down to an uppercut.
const OVERALLS := {
	"fat_plumber_cap": Color(0.16, 0.3, 0.75), "tall_plumber_cap": Color(0.16, 0.3, 0.75),
	"very_tall_plumber_cap": Color(0.12, 0.1, 0.24), "very_fat_plumber_cap": Color(0.42, 0.16, 0.55),
}
## Share of wraiths, ghoul brawlers and bruisers in a missing plumber cap,
## once you own the Fat Plumber Cap.
const PLUMBER_CHANCE := 0.04
## Max every node of a power for its hat (each +10% to that power).
const POWER_HATS := {
	"sigil_fire": "fire_cap", "sigil_gale": "gale_flattop", "sigil_storm": "storm_ears", "sigil_iron": "iron_mask",
	"sigil_frost": "frost_tiara", "sigil_doom": "doom_mask", "sigil_blood": "blood_hairline", "sigil_quake": "quake_headband",
}
## The Bald Hero Cap: this much base damage, or one punch for this many times it.
const BALD_DAMAGE := 250.0
const MASSIVE_HIT := 15.0
## The Speedster Cowl: move and punch speed bonuses this high.
const SPEEDSTER_MOVE := 0.3
const SPEEDSTER_PUNCH := 0.3
## Awarded and waiting on their popup.
static var _pending := {}

const CATALOG := {
	"party_hat": {"name": "Party Hat", "rarity": "common", "effects": {"damage_percent": 0.01},
		"desc": "Somebody's birthday. Not anymore."},
	"traffic_cone": {"name": "Traffic Cone", "rarity": "common", "effects": {"knuckles_percent": 0.02},
		"desc": "Stolen from a construction site. In the underworld."},
	"shower_cap": {"name": "Shower Cap", "rarity": "common", "effects": {"dodge_window": 0.02},
		"desc": "Ready for the rain of blows."},
	"propeller_beanie": {"name": "Propeller Beanie", "rarity": "common", "effects": {"move_speed": 0.03},
		"desc": "Doesn't fly. Doesn't help. Spins, though."},
	"lampshade": {"name": "Lampshade", "rarity": "common", "effects": {"coin_bonus": 0.03},
		"desc": "The life of the funeral."},
	"bucket": {"name": "Bucket", "rarity": "common", "effects": {"defense": 0.5},
		"desc": "It's a bucket."},
	"wig_black": {"name": "Strong Guy Wig (Black)", "rarity": "common", "effects": {"damage_percent": 0.015},
		"desc": "Spiky. Suspiciously heroic."},
	"wig_blonde": {"name": "Strong Guy Wig (Blonde)", "rarity": "uncommon", "effects": {"damage_percent": 0.025, "ult_gain": 0.02},
		"desc": "Took three episodes of screaming to put on."},
	"wig_blue": {"name": "Strong Guy Wig (Blue)", "rarity": "rare", "effects": {"damage_percent": 0.035, "ult_gain": 0.03},
		"desc": "Dyed. Don't tell anyone."},
	"wig_white": {"name": "Strong Guy Wig (White)", "rarity": "legendary", "effects": {"window_cap_up": 0.05, "window_boost": 0.05},
		"desc": "Won by maxing your dodge, counter and combo windows. It moves on its own. So do you."},
	"bowler": {"name": "Bowler Hat", "rarity": "uncommon", "effects": {"counter_bonus": 0.05},
		"desc": "Very proper. Very dead."},
	"chef_toque": {"name": "Chef's Toque", "rarity": "uncommon", "effects": {"xp_bonus": 0.04},
		"desc": "Kiss the cook. He's undead."},
	"viking_helmet": {"name": "Viking Helmet", "rarity": "uncommon", "effects": {"heavy_bonus": 0.04},
		"desc": "Horns sold separately. Horns included."},
	"pirate_tricorn": {"name": "Pirate Tricorn", "rarity": "uncommon", "effects": {"coin_bonus": 0.05},
		"desc": "Arr. Then death. Then arr again."},
	"top_hat": {"name": "Top Hat", "rarity": "rare", "effects": {"damage_percent": 0.03},
		"desc": "There's a bunny in it. Don't ask about the magician."},
	"tinfoil_hat": {"name": "Tinfoil Hat", "rarity": "rare", "effects": {"dodge_window": 0.04},
		"desc": "They can't read your dodges now."},
	"hard_hat": {"name": "Hard Hat", "rarity": "rare", "effects": {"knuckles_percent": 0.04},
		"desc": "The gravedigger's. He won't be needing it."},
	"paper_crown": {"name": "Paper Crown", "rarity": "epic", "effects": {"xp_bonus": 0.06, "coin_bonus": 0.03},
		"desc": "From a fast-food joint. You are royalty now."},
	"witch_hat": {"name": "Witch's Hat", "rarity": "epic", "effects": {"ult_gain": 0.06},
		"desc": "Still warm. Don't think about it."},
	"reaper_hood": {"name": "Grim Reaper's Hood", "rarity": "epic", "effects": {"damage_percent": 0.04, "defense": 1.0},
		"desc": "He left it at the coat check."},
	"fruit_hat": {"name": "Fruit Hat", "rarity": "epic", "effects": {"knuckles_percent": 0.04, "heal_on_kill": 1.0},
		"desc": "Five servings a day. Too late for this guy."},
	"fast_quills": {"name": "Fast Guy Fleece Cap", "rarity": "epic", "effects": {"move_speed": 0.05, "punch_speed": 0.04},
		"desc": "Blue, spiky, and already gone."},
	"pocket_trainer_cap": {"name": "Bootleg Trainer Cap", "rarity": "rare", "effects": {"xp_bonus": 0.04, "coin_bonus": 0.03},
		"desc": "Catch 'em? Punch 'em."},
	"straw_hat": {"name": "Straw Hat", "rarity": "epic", "effects": {"knuckles_percent": 0.04, "damage_percent": 0.03},
		"desc": "Stretchy guy's. He'll want it back."},
	"rebel_cap": {"name": "Rebellious Guy Hat", "rarity": "epic", "effects": {"punch_speed": 0.04, "damage_percent": 0.03},
		"desc": "Good grief."},
	"monkey_mask": {"name": "Big Monkey Mask", "rarity": "epic", "effects": {"damage_percent": 0.03, "dodge_window": 0.03},
		"desc": "Ook. The dead find it deeply unsettling."},
	"yonker_brim": {"name": "Yonker with Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"yonker_no_brim": {"name": "Yonker with No Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"brim_no_yonker": {"name": "Brim with No Yonker", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"no_yonker_no_brim": {"name": "No Yonker with No Brim", "rarity": "legendary", "effects": {},
		"desc": "Does nothing. Yet."},
	"coffin_crown": {"name": "Coffin Crown", "rarity": "legendary", "effects": {"damage_percent": 0.05, "knuckles_percent": 0.05},
		"desc": "Off the Coffin King's head. Heavy is the head."},
	# Won by maxing a power.
	"fire_cap": {"name": "Hot Plumber Hat", "rarity": "epic", "effects": {"boost_fire": 0.1},
		"desc": "Won by maxing Fire. Fixes pipes. Sets them on fire."},
	"gale_flattop": {"name": "Air Force Flattop", "rarity": "epic", "effects": {"boost_gale": 0.1}, "bald": true,
		"desc": "Won by maxing Gale. Takes an hour and a can of spray a morning."},
	"storm_ears": {"name": "Bootleg Mouse Ears", "rarity": "epic", "effects": {"boost_storm": 0.1},
		"desc": "Won by maxing Storm. Not from the official store."},
	"iron_mask": {"name": "Armored Faceplate", "rarity": "epic", "effects": {"boost_iron": 0.1},
		"desc": "Won by maxing Iron. Built in a cave. With a box of scraps."},
	"frost_tiara": {"name": "Snow Queen Tiara", "rarity": "epic", "effects": {"boost_frost": 0.1},
		"desc": "Won by maxing Frost. The cold never bothered her anyway."},
	"doom_mask": {"name": "Evil Doctor Mask", "rarity": "epic", "effects": {"boost_doom": 0.1},
		"desc": "Won by maxing Doom. Speaks of himself in the third person."},
	"blood_hairline": {"name": "Drawn-On Hairline", "rarity": "epic", "effects": {"boost_blood": 0.1}, "bald": true,
		"desc": "Won by maxing Blood. Marker. Two coats. Very convincing."},
	"quake_headband": {"name": "Earth Warrior Headband", "rarity": "epic", "effects": {"boost_quake": 0.1},
		"desc": "Won by maxing Quake. She sees with her feet."},
	# Won for the big milestones.
	"golden_quills": {"name": "Golden Fast Guy Fleece Cap", "rarity": "legendary", "effects": {"all_power_boost": 0.1},
		"desc": "Won by maxing every power. Seven shiny rocks not included."},
	"bald_cap": {"name": "Bald Hero Cap", "rarity": "legendary", "effects": {"damage_percent": 0.1, "crit_damage": 0.25}, "bald": true,
		"desc": "Won with a huge base damage or one absurd punch. Ok."},
	"speed_mask": {"name": "Speedster Cowl", "rarity": "legendary", "effects": {"move_speed": 0.08, "punch_speed": 0.06},
		"desc": "Won with big move and punch speed. Was here a second ago."},
	# The plumber quest.
	"fat_plumber_cap": {"name": "Fat Plumber Cap", "rarity": "epic", "effects": {"defense": 0.5, "damage_percent": 0.03},
		"desc": "Off the plumber you made clean up after you."},
	"tall_plumber_cap": {"name": "Tall Plumber Cap", "rarity": "epic", "effects": {"move_speed": 0.04, "punch_speed": 0.03},
		"desc": "The other brother. Gets less credit."},
	"very_tall_plumber_cap": {"name": "Very Tall \"Plumber\" Cap", "rarity": "epic", "effects": {"dodge_window": 0.03, "move_speed": 0.02},
		"desc": "Not a plumber. Never was."},
	"very_fat_plumber_cap": {"name": "Very Fat \"Plumber\" Cap", "rarity": "epic", "effects": {"damage_percent": 0.03, "knuckles_percent": 0.03},
		"desc": "Also not a plumber. Wants your coins."},
}


static func info(id: String) -> Dictionary:
	return CATALOG.get(id, {})


static func color(id: String) -> Color:
	return Items.RARITIES[CATALOG[id].rarity].color


## The boost line for the popup and the Hat Rack.
static func boost_text(id: String) -> String:
	var effects: Dictionary = CATALOG[id].effects
	if effects.is_empty():
		return "Collect all four Yonkers..."
	return GameState.effect_text(effects, 1)


## Every node of a power bought to the max.
static func power_maxed(root: String) -> bool:
	if GameState.upgrade_levels.get(root, 0) <= 0:
		return false
	for id in GameState.UPGRADES:
		if GameState.power_of(id) == root and GameState.upgrade_levels.get(id, 0) < int(GameState.UPGRADES[id].max_level):
			return false
	return true


## The won hats the build qualifies for right now.
static func earned_now() -> Array:
	var ids := []
	for root in POWER_HATS:
		if power_maxed(root):
			ids.append(POWER_HATS[root])
	if POWER_HATS.keys().all(power_maxed):
		ids.append("golden_quills")
	if GameState.get_effect("dodge_window") >= GameState.MAX_DODGE_WINDOW_BONUS \
			and GameState.get_effect("counter_window") >= GameState.MAX_COUNTER_WINDOW_BONUS \
			and GameState.get_effect("combo_window") >= GameState.MAX_COMBO_WINDOW_BONUS:
		ids.append("wig_white")
	if GameState.get_effect("move_speed") >= SPEEDSTER_MOVE and GameState.get_effect("punch_speed") >= SPEEDSTER_PUNCH:
		ids.append("speed_mask")
	if GameState.get_damage() >= BALD_DAMAGE:
		ids.append("bald_cap")
	return ids


## Hands out every won hat you qualify for and don't have (each with its
## popup, or quietly).
static func check_awards(tree: SceneTree, quiet := false) -> void:
	for id in earned_now():
		award(tree, id, quiet)


static func award(tree: SceneTree, id: String, quiet := false) -> void:
	if GameState.hats.has(id) or _pending.has(id):
		return
	if quiet or tree == null:
		GameState.add_hat(id)
		return
	_pending[id] = true
	HatPopup.open(tree, id)


## The plumber cap (if any) a freshly spawned monster wears: a wraith the
## tall one, a ghoul brawler the very tall one, a bruiser the very fat one,
## while you own the Fat Plumber Cap and not that one.
static func plumber_for(enemy: Enemy) -> String:
	if not GameState.hats.has("fat_plumber_cap"):
		return ""
	var id := ""
	if enemy is Wraith:
		id = "tall_plumber_cap"
	elif enemy is Brawler:
		id = "very_tall_plumber_cap"
	elif enemy is GraveBruiser:
		id = "very_fat_plumber_cap"
	if id == "" or GameState.hats.has(id) or randf() >= PLUMBER_CHANCE:
		return ""
	return id


## Which hat (if any) a freshly spawned enemy wears. Bumps the bad-luck
## counter for non-legendary hats.
static func roll(skeleton: bool) -> String:
	# Hat Trick (a Fortune perk): twice as many hats.
	if randf() >= HAT_CHANCE * (2.0 if GameState.perk("hat_trick") else 1.0):
		return ""
	var missing := LEGENDARIES.filter(func(id: String) -> bool: return not GameState.hats.has(id))
	var legendary_chance := LEGENDARY_BASE + LEGENDARY_STEP * GameState.hat_pity
	if not missing.is_empty() and randf() < legendary_chance:
		GameState.hat_pity = 0
		return missing.pick_random()
	GameState.hat_pity += 1
	if skeleton and randf() < SKELETON_FRUIT:
		return "fruit_hat"
	var total := 0.0
	for weight in RARITY_WEIGHTS.values():
		total += weight
	var pick := randf() * total
	var rarity := "common"
	for key in RARITY_WEIGHTS:
		pick -= RARITY_WEIGHTS[key]
		if pick <= 0.0:
			rarity = key
			break
	var pool := CATALOG.keys().filter(func(id: String) -> bool: return CATALOG[id].rarity == rarity and not id in TROPHIES)
	return pool.pick_random()


# --- Building them ------------------------------------------------------------------

## A hat as a Node3D: its origin sits on top of the head, u is the head's width.
static func build(id: String, u: float) -> Node3D:
	var hat := Node3D.new()
	hat.name = "Hat"
	match id:
		"party_hat":
			for i in 5:
				var w := 0.62 - i * 0.13
				_b(hat, u, Vector3(w, 0.14, w), Vector3(0, 0.07 + i * 0.14, 0), Color(1.0, 0.3, 0.7) if i % 2 == 0 else Color(1.0, 0.85, 0.2))
			_b(hat, u, Vector3(0.16, 0.16, 0.16), Vector3(0, 0.78, 0), Color(0.95, 0.95, 1.0))
		"traffic_cone":
			_b(hat, u, Vector3(1.0, 0.06, 1.0), Vector3(0, 0.03, 0), Color(1.0, 0.45, 0.05))
			for i in 5:
				var w := 0.72 - i * 0.12
				_b(hat, u, Vector3(w, 0.16, w), Vector3(0, 0.14 + i * 0.16, 0), Color(0.95, 0.95, 0.95) if i == 2 else Color(1.0, 0.45, 0.05))
		"shower_cap":
			_b(hat, u, Vector3(1.12, 0.26, 1.12), Vector3(0, 0.1, 0), Color(0.6, 0.85, 1.0))
			_b(hat, u, Vector3(1.2, 0.08, 1.2), Vector3(0, -0.02, 0), Color(0.85, 0.95, 1.0))
		"propeller_beanie":
			var colors := [Color(0.95, 0.2, 0.2), Color(0.2, 0.45, 1.0), Color(1.0, 0.85, 0.15), Color(0.2, 0.8, 0.3)]
			for i in 4:
				var x := -0.27 if i % 2 == 0 else 0.27
				var z := -0.27 if i < 2 else 0.27
				_b(hat, u, Vector3(0.54, 0.24, 0.54), Vector3(x, 0.1, z), colors[i])
			_b(hat, u, Vector3(0.06, 0.2, 0.06), Vector3(0, 0.32, 0), Color(0.3, 0.3, 0.3))
			var blades := Node3D.new()
			blades.name = "Spin"
			blades.position = Vector3(0, 0.43, 0) * u
			hat.add_child(blades)
			_b(blades, u, Vector3(0.9, 0.03, 0.14), Vector3.ZERO, Color(1.0, 0.85, 0.15))
			_b(blades, u, Vector3(0.14, 0.03, 0.9), Vector3.ZERO, Color(0.95, 0.2, 0.2))
		"lampshade":
			_b(hat, u, Vector3(0.95, 0.22, 0.95), Vector3(0, 0.1, 0), Color(0.95, 0.88, 0.7), Vector3(0, 0, 0.12))
			_b(hat, u, Vector3(0.72, 0.24, 0.72), Vector3(0.03, 0.32, 0), Color(0.95, 0.88, 0.7), Vector3(0, 0, 0.12))
			_b(hat, u, Vector3(0.98, 0.04, 0.98), Vector3(0, 0.0, 0), Color(0.75, 0.45, 0.2), Vector3(0, 0, 0.12))
		"bucket":
			_b(hat, u, Vector3(1.08, 0.62, 1.08), Vector3(0, 0.06, 0), Color(0.62, 0.64, 0.68), Vector3.ZERO, false, 0.35)
			_b(hat, u, Vector3(1.14, 0.06, 1.14), Vector3(0, -0.24, 0), Color(0.48, 0.5, 0.54), Vector3.ZERO, false, 0.35)
			_b(hat, u, Vector3(0.05, 0.05, 1.2), Vector3(0, 0.4, 0), Color(0.35, 0.35, 0.38), Vector3(0, 0, 0.0), false, 0.7)
		"bowler":
			_b(hat, u, Vector3(1.32, 0.05, 1.32), Vector3(0, 0.02, 0), Color(0.08, 0.07, 0.08))
			_b(hat, u, Vector3(0.92, 0.32, 0.92), Vector3(0, 0.2, 0), Color(0.1, 0.09, 0.1))
			_b(hat, u, Vector3(0.94, 0.07, 0.94), Vector3(0, 0.08, 0), Color(0.45, 0.1, 0.1))
		"chef_toque":
			_b(hat, u, Vector3(1.04, 0.18, 1.04), Vector3(0, 0.09, 0), Color(0.96, 0.96, 0.96))
			_b(hat, u, Vector3(1.22, 0.42, 1.22), Vector3(0, 0.42, 0), Color(1.0, 1.0, 1.0))
			_b(hat, u, Vector3(0.9, 0.12, 0.9), Vector3(0, 0.68, 0), Color(1.0, 1.0, 1.0))
		"viking_helmet":
			_b(hat, u, Vector3(1.12, 0.32, 1.12), Vector3(0, 0.12, 0), Color(0.55, 0.56, 0.6), Vector3.ZERO, false, 0.7)
			_b(hat, u, Vector3(0.12, 0.36, 1.14), Vector3(0, 0.14, 0), Color(0.75, 0.6, 0.3))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.16, 0.42, 0.16), Vector3(0.6 * side, 0.32, 0), Color(0.95, 0.9, 0.78), Vector3(0, 0, -0.6 * side))
				_b(hat, u, Vector3(0.1, 0.2, 0.1), Vector3(0.75 * side, 0.55, 0), Color(0.95, 0.9, 0.78), Vector3(0, 0, -0.1 * side))
		"pirate_tricorn":
			_b(hat, u, Vector3(1.45, 0.07, 1.1), Vector3(0, 0.04, 0), Color(0.07, 0.06, 0.07))
			_b(hat, u, Vector3(0.95, 0.3, 0.85), Vector3(0, 0.2, 0), Color(0.08, 0.07, 0.08))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.14, 0.3, 1.0), Vector3(0.7 * side, 0.18, 0), Color(0.07, 0.06, 0.07), Vector3(0, 0, -0.5 * side))
			_b(hat, u, Vector3(0.2, 0.18, 0.04), Vector3(0, 0.22, -0.44), Color(0.95, 0.95, 0.92))
		"top_hat":
			_b(hat, u, Vector3(1.36, 0.05, 1.36), Vector3(0, 0.02, 0), Color(0.06, 0.05, 0.07))
			_b(hat, u, Vector3(0.86, 0.78, 0.86), Vector3(0, 0.43, 0), Color(0.08, 0.07, 0.09))
			_b(hat, u, Vector3(0.88, 0.1, 0.88), Vector3(0, 0.12, 0), Color(0.75, 0.1, 0.12))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.12, 0.42, 0.06), Vector3(0.12 * side, 0.98, 0), Color(0.98, 0.98, 0.98), Vector3(0, 0, -0.18 * side))
				_b(hat, u, Vector3(0.06, 0.3, 0.07), Vector3(0.12 * side, 0.98, -0.01), Color(1.0, 0.65, 0.75), Vector3(0, 0, -0.18 * side))
		"tinfoil_hat":
			for i in 4:
				var w := 1.0 - i * 0.22
				_b(hat, u, Vector3(w, 0.16, w), Vector3(0, 0.08 + i * 0.15, 0), Color(0.86, 0.88, 0.92), Vector3(0.12 * (i % 2), 0.4 * i, 0.08 * ((i + 1) % 2)), false, 0.35)
			_b(hat, u, Vector3(0.14, 0.16, 0.14), Vector3(0.05, 0.68, 0), Color(0.9, 0.92, 0.95), Vector3(0.3, 0, 0.3), false, 0.35)
		"hard_hat":
			_b(hat, u, Vector3(1.1, 0.34, 1.1), Vector3(0, 0.15, 0), Color(1.0, 0.82, 0.1))
			_b(hat, u, Vector3(1.18, 0.05, 1.3), Vector3(0, 0.0, -0.08), Color(1.0, 0.78, 0.08))
			_b(hat, u, Vector3(0.12, 0.12, 0.2), Vector3(0, 0.2, -0.58), Color(1.0, 0.95, 0.7), Vector3.ZERO, true)
		"coffin_crown":
			# An open ring of gold plates on a darker rim, six coffin-shaped
			# points (narrow foot, wide shoulders, narrow head) each set with a
			# violet gem, and a little skull on the front.
			var gold := Color(1.0, 0.8, 0.3)
			for i in 8:
				var a := i * TAU / 8.0 + TAU / 16.0
				var at := Vector3(sin(a), 0.0, cos(a))
				_b(hat, u, Vector3(0.44, 0.26, 0.07), at * 0.52 + Vector3(0, 0.15, 0), gold, Vector3(0, a, 0), false, 0.5)
				_b(hat, u, Vector3(0.47, 0.07, 0.1), at * 0.54 + Vector3(0, 0.03, 0), gold.darkened(0.35), Vector3(0, a, 0), false, 0.5)
			for i in 6:
				var a := i * TAU / 6.0
				var at := Vector3(sin(a), 0.0, cos(a)) * 0.53
				var turn := Vector3(0, a, 0)
				_b(hat, u, Vector3(0.15, 0.1, 0.07), at + Vector3(0, 0.32, 0), gold, turn, false, 0.5)
				_b(hat, u, Vector3(0.25, 0.15, 0.07), at + Vector3(0, 0.44, 0), gold, turn, false, 0.5)
				_b(hat, u, Vector3(0.15, 0.11, 0.07), at + Vector3(0, 0.57, 0), gold, turn, false, 0.5)
				_b(hat, u, Vector3(0.08, 0.08, 0.08), at * 1.04 + Vector3(0, 0.44, 0), Color(0.65, 0.2, 0.95), turn, true)
			_b(hat, u, Vector3(0.18, 0.16, 0.05), Vector3(0, 0.14, -0.58), Color(0.95, 0.93, 0.86))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.05, 0.05, 0.02), Vector3(0.045 * side, 0.16, -0.61), Color(0.05, 0.05, 0.05))
		"paper_crown":
			_b(hat, u, Vector3(1.06, 0.2, 1.06), Vector3(0, 0.1, 0), Color(1.0, 0.82, 0.25))
			for i in 8:
				var a := i * TAU / 8.0
				_b(hat, u, Vector3(0.16, 0.22, 0.05), Vector3(sin(a) * 0.5, 0.3, cos(a) * 0.5), Color(1.0, 0.75, 0.15), Vector3(0, a, 0))
			_b(hat, u, Vector3(0.12, 0.1, 0.03), Vector3(0, 0.1, -0.54), Color(0.9, 0.15, 0.15))
		"witch_hat":
			_b(hat, u, Vector3(1.65, 0.05, 1.65), Vector3(0, 0.02, 0), Color(0.2, 0.08, 0.28))
			var lean := 0.0
			for i in 5:
				var w := 0.9 - i * 0.16
				lean += 0.04 * i
				_b(hat, u, Vector3(w, 0.22, w), Vector3(lean, 0.14 + i * 0.21, 0), Color(0.22, 0.09, 0.3))
			_b(hat, u, Vector3(0.92, 0.08, 0.92), Vector3(0, 0.08, 0), Color(0.55, 0.85, 0.3))
			_b(hat, u, Vector3(0.16, 0.12, 0.03), Vector3(0, 0.08, -0.47), Color(1.0, 0.85, 0.3))
		"reaper_hood":
			var cloth := Color(0.05, 0.045, 0.06)
			_b(hat, u, Vector3(1.24, 0.3, 1.2), Vector3(0, 0.08, 0.04), cloth)
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.14, 0.95, 1.2), Vector3(0.62 * side, -0.35, 0.04), cloth)
			_b(hat, u, Vector3(1.24, 0.95, 0.16), Vector3(0, -0.35, 0.6), cloth)
			_b(hat, u, Vector3(0.6, 0.3, 0.5), Vector3(0, 0.25, 0.5), cloth, Vector3(0.4, 0, 0))
		"fruit_hat":
			_fruit_hat(hat, u)
		"monkey_mask":
			_monkey_mask(hat, u)
		"fast_quills":
			_quills(hat, u)
		"pocket_trainer_cap":
			_trainer_cap(hat, u)
		"straw_hat":
			_straw_hat(hat, u)
		"rebel_cap":
			_rebel_cap(hat, u)
		"wig_black":
			_strong_wig(hat, u, Color(0.13, 0.13, 0.16), false)
		"wig_blonde":
			_strong_wig(hat, u, Color(1.0, 0.86, 0.28), true)
		"wig_blue":
			_strong_wig(hat, u, Color(0.25, 0.6, 1.0), true)
		"wig_white":
			_strong_wig(hat, u, Color(0.92, 0.94, 1.0), true)
		"fire_cap":
			_plumber_cap(hat, u, Color(0.97, 0.97, 0.96), "flame")
		"fat_plumber_cap":
			_plumber_cap(hat, u, Color(0.86, 0.1, 0.1), "wrench", 1.2)
		"tall_plumber_cap":
			_plumber_cap(hat, u, Color(0.1, 0.62, 0.2), "plunger", 1.0, 1.5)
		"very_tall_plumber_cap":
			_plumber_cap(hat, u, Color(0.42, 0.16, 0.6), "drop", 1.0, 2.1)
		"very_fat_plumber_cap":
			_plumber_cap(hat, u, Color(1.0, 0.85, 0.15), "coin", 1.45, 0.9)
		"gale_flattop":
			_flattop(hat, u)
		"storm_ears":
			_mouse_ears(hat, u)
		"iron_mask":
			_faceplate(hat, u)
		"frost_tiara":
			_tiara(hat, u)
		"doom_mask":
			_doctor_mask(hat, u)
		"blood_hairline":
			_drawn_hairline(hat, u)
		"quake_headband":
			_earth_headband(hat, u)
		"golden_quills":
			_quills(hat, u, Color(1.0, 0.82, 0.18))
		"bald_cap":
			# The head's own bald dome (its hair comes off), and a shine.
			_b(hat, u, Vector3(0.2, 0.025, 0.07), Vector3(0.16, -0.02, -0.22), Color(1, 1, 1), Vector3(0, 0.5, 0), true)
			_b(hat, u, Vector3(0.08, 0.025, 0.05), Vector3(0.05, -0.02, -0.3), Color(1, 1, 1), Vector3(0, 0.5, 0), true)
		"speed_mask":
			_speed_cowl(hat, u)
		"yonker_brim", "yonker_no_brim":
			_yonker_cap(hat, u, id == "yonker_brim")
		"brim_no_yonker":
			_b(hat, u, Vector3(0.9, 0.05, 0.62), Vector3(0, 0.2, -0.62), Color(0.08, 0.12, 0.3))
		"no_yonker_no_brim":
			pass  # It's nothing. The legendary sparkle is the only clue.
	return hat


## The navy Yonker cap: a dome with a stitched white Y, brim optional.
static func _yonker_cap(hat: Node3D, u: float, brim: bool) -> void:
	var navy := Color(0.08, 0.12, 0.3)
	_b(hat, u, Vector3(1.1, 0.3, 1.1), Vector3(0, 0.12, 0), navy)
	_b(hat, u, Vector3(0.82, 0.12, 0.82), Vector3(0, 0.32, 0), navy)
	_b(hat, u, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.4, 0), navy)
	if brim:
		_b(hat, u, Vector3(0.9, 0.05, 0.62), Vector3(0, 0.0, -0.78), navy)
	# The Y.
	var white := Color(0.97, 0.97, 0.97)
	_b(hat, u, Vector3(0.05, 0.12, 0.03), Vector3(0, 0.08, -0.56), white)
	_b(hat, u, Vector3(0.05, 0.1, 0.03), Vector3(-0.05, 0.18, -0.56), white, Vector3(0, 0, 0.6))
	_b(hat, u, Vector3(0.05, 0.1, 0.03), Vector3(0.05, 0.18, -0.56), white, Vector3(0, 0, -0.6))


## The strong guy's hair: a cap down the back of the head, bangs over the
## brow and big blocky spikes. The base (black) look fans out every way; the
## powered-up colors stand straight up and taller.
static func _strong_wig(hat: Node3D, u: float, tint: Color, powered: bool) -> void:
	var shade := tint.darkened(0.25)
	_b(hat, u, Vector3(1.08, 0.24, 1.08), Vector3(0, 0.02, 0.02), tint)
	_b(hat, u, Vector3(1.08, 0.62, 0.22), Vector3(0, -0.26, 0.46), shade)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.14, 0.42, 0.7), Vector3(0.5 * side, -0.14, 0.12), shade)
	# Bangs: three points hanging over the brow.
	for i in 3:
		var x := (i - 1) * 0.26
		_spike(hat, u, Vector3(x, -0.02, -0.5), Vector3(PI - 0.25, 0, x * 0.9), 0.32, 0.2, tint)
	# The spikes: [base, tilt (x back, z out), length].
	var spikes := [
		[Vector3(0, 0.12, 0.0), Vector3(0.35, 0, 0), 0.7],
		[Vector3(-0.3, 0.1, 0.05), Vector3(0.2, 0, 0.75), 0.62],
		[Vector3(0.3, 0.1, 0.05), Vector3(0.2, 0, -0.75), 0.62],
		[Vector3(-0.42, 0.0, 0.2), Vector3(0.5, 0, 1.25), 0.55],
		[Vector3(0.42, 0.0, 0.2), Vector3(0.5, 0, -1.25), 0.55],
		[Vector3(-0.18, 0.08, 0.35), Vector3(1.0, 0, 0.45), 0.58],
		[Vector3(0.18, 0.08, 0.35), Vector3(1.0, 0, -0.45), 0.58],
		[Vector3(0, 0.0, 0.48), Vector3(1.35, 0, 0), 0.52],
		[Vector3(-0.2, 0.1, -0.25), Vector3(-0.35, 0, 0.4), 0.45],
		[Vector3(0.2, 0.1, -0.25), Vector3(-0.35, 0, -0.4), 0.45],
	]
	for i in spikes.size():
		var spike: Array = spikes[i]
		var tilt: Vector3 = spike[1]
		var length: float = spike[2]
		tilt *= 0.45 if powered else 0.8
		length *= 1.45 if powered else 1.15
		_spike(hat, u, spike[0], tilt, length, 0.4, tint if i % 2 == 0 else tint.lightened(0.08))


## The fast guy's fleece cap: a blue hood with a rolled edge round the face,
## pointed ears with tan insides, and quills swept back, the top one biggest.
static func _quills(hat: Node3D, u: float, fleece := Color(0.08, 0.5, 0.9)) -> void:
	var shade := fleece.darkened(0.18)
	var edge := fleece.lightened(0.1)
	# The hood: over the top, down the sides and the back of the head.
	_b(hat, u, Vector3(1.12, 0.28, 1.1), Vector3(0, 0.04, 0.02), fleece)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.14, 0.55, 0.95), Vector3(0.56 * side, -0.22, 0.04), shade)
		_b(hat, u, Vector3(0.12, 0.55, 0.12), Vector3(0.58 * side, -0.22, -0.47), edge)
	_b(hat, u, Vector3(1.12, 0.65, 0.18), Vector3(0, -0.24, 0.52), shade)
	_b(hat, u, Vector3(1.18, 0.11, 0.13), Vector3(0, 0.0, -0.52), edge)
	# Ears, tan inside.
	for side in [-1.0, 1.0]:
		_spike(hat, u, Vector3(0.36 * side, 0.16, -0.12), Vector3(-0.15, 0, -0.35 * side), 0.38, 0.3, fleece)
		_spike(hat, u, Vector3(0.36 * side, 0.18, -0.2), Vector3(-0.15, 0, -0.35 * side), 0.26, 0.16, Color(0.95, 0.88, 0.58))
	# [base, tilt (x back and down, z out), length, width]: the big one up top.
	var quills := [
		[Vector3(0, 0.22, 0.05), Vector3(1.05, 0, 0), 1.05, 0.6],
		[Vector3(0, -0.05, 0.42), Vector3(1.55, 0, 0), 0.85, 0.5],
		[Vector3(-0.32, -0.25, 0.4), Vector3(1.75, 0, 0.5), 0.7, 0.42],
		[Vector3(0.32, -0.25, 0.4), Vector3(1.75, 0, -0.5), 0.7, 0.42],
		[Vector3(0, -0.45, 0.48), Vector3(2.0, 0, 0), 0.55, 0.38],
	]
	for i in quills.size():
		var quill: Array = quills[i]
		_spike(hat, u, quill[0], quill[1], quill[2], quill[3], fleece if i % 2 == 0 else shade)


## The bootleg trainer's cap: white front panels, red back, a red brim and
## button, and a green leaf patch on the front where a logo would go.
static func _trainer_cap(hat: Node3D, u: float) -> void:
	var white := Color(0.97, 0.97, 0.97)
	var red := Color(0.86, 0.14, 0.12)
	_b(hat, u, Vector3(1.1, 0.3, 0.56), Vector3(0, 0.12, -0.27), white)
	_b(hat, u, Vector3(1.1, 0.3, 0.56), Vector3(0, 0.12, 0.27), red)
	_b(hat, u, Vector3(0.82, 0.12, 0.42), Vector3(0, 0.32, -0.2), white)
	_b(hat, u, Vector3(0.82, 0.12, 0.42), Vector3(0, 0.32, 0.2), red)
	_b(hat, u, Vector3(0.12, 0.08, 0.12), Vector3(0, 0.41, 0), red)
	_b(hat, u, Vector3(0.94, 0.05, 0.66), Vector3(0, 0.0, -0.8), red, Vector3(-0.12, 0, 0))
	var green := Color(0.15, 0.55, 0.25)
	_b(hat, u, Vector3(0.2, 0.12, 0.03), Vector3(0, 0.15, -0.56), green, Vector3(0, 0, 0.6))
	_b(hat, u, Vector3(0.03, 0.12, 0.03), Vector3(-0.08, 0.06, -0.565), green, Vector3(0, 0, 0.6))


## The stretchy guy's straw hat: a wide round brim, a red band round the
## crown, and darker strands woven through.
static func _straw_hat(hat: Node3D, u: float) -> void:
	var straw := Color(0.9, 0.76, 0.46)
	var strand := straw.darkened(0.25)
	var red := Color(0.8, 0.12, 0.1)
	# Two squares a turn apart make the round brim and crown.
	for turn in [0.0, PI / 4.0]:
		_b(hat, u, Vector3(1.9, 0.06, 1.9), Vector3(0, 0.02, 0), straw, Vector3(0, turn, 0))
		_b(hat, u, Vector3(0.98, 0.4, 0.98), Vector3(0, 0.25, 0), straw, Vector3(0, turn, 0))
		_b(hat, u, Vector3(1.02, 0.13, 1.02), Vector3(0, 0.13, 0), red, Vector3(0, turn, 0))
		_b(hat, u, Vector3(0.78, 0.08, 0.78), Vector3(0, 0.48, 0), straw, Vector3(0, turn, 0))
	for i in 12:
		var a := i * TAU / 12.0
		var r := 0.7 + 0.12 * (i % 2)
		_b(hat, u, Vector3(0.04, 0.02, 0.14), Vector3(sin(a) * r, 0.06, cos(a) * r), strand, Vector3(0, a, 0))
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		_b(hat, u, Vector3(0.03, 0.14, 0.02), Vector3(sin(a) * 0.5, 0.34, cos(a) * 0.5), strand, Vector3(0, a, 0))


## The rebellious guy's hat: a tall peaked cap leaning forward, a drooping
## visor with a sheen, a gold chain across the front, a round gold button and
## a gold hand badge, and the back torn into jagged hair sweeping up and back.
static func _rebel_cap(hat: Node3D, u: float) -> void:
	var black := Color(0.1, 0.1, 0.13)
	var sheen := Color(0.32, 0.33, 0.38)
	var hair := Color(0.06, 0.06, 0.09)
	var hair_light := Color(0.13, 0.14, 0.22)
	var gold := Color(0.88, 0.68, 0.28)
	# The crown: a band, the body, and a top sloping down from a tall front.
	_b(hat, u, Vector3(1.1, 0.16, 1.1), Vector3(0, 0.08, 0), black)
	_b(hat, u, Vector3(1.1, 0.3, 0.82), Vector3(0, 0.27, -0.1), black)
	_b(hat, u, Vector3(1.14, 0.52, 0.12), Vector3(0, 0.33, -0.52), black, Vector3(-0.18, 0, 0))
	_b(hat, u, Vector3(1.12, 0.1, 0.95), Vector3(0, 0.46, -0.12), black, Vector3(0.34, 0, 0))
	_b(hat, u, Vector3(1.0, 0.03, 0.08), Vector3(0, 0.6, -0.55), sheen, Vector3(-0.18, 0, 0))
	# The visor, tipped down, with a highlight across it.
	_b(hat, u, Vector3(1.0, 0.05, 0.44), Vector3(0, 0.01, -0.74), black, Vector3(-0.35, 0, 0), false, 0.3)
	_b(hat, u, Vector3(0.86, 0.012, 0.07), Vector3(0, 0.04, -0.76), sheen, Vector3(-0.35, 0, 0))
	# The chain: links across the front, a gold knob at each end.
	for i in 11:
		var x := -0.5 + i * 0.1
		var link := Vector3(0.12, 0.04, 0.03) if i % 2 == 0 else Vector3(0.07, 0.065, 0.03)
		_b(hat, u, link, Vector3(x, 0.17, -0.6), gold, Vector3.ZERO, false, 0.6)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.09, 0.09, 0.09), Vector3(0.56 * side, 0.17, -0.5), gold, Vector3.ZERO, false, 0.6)
	# Seen from the front +x is on the left: the round button there, the badge on the right.
	var button := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.1 * u
	disc.bottom_radius = 0.1 * u
	disc.height = 0.06 * u
	disc.radial_segments = 20
	disc.rings = 1
	disc.material = Look.block_material(gold, 0.6)
	button.mesh = disc
	button.position = Vector3(0.15, 0.36, -0.62) * u
	button.rotation = Vector3(PI / 2.0 - 0.18, 0, 0)
	hat.add_child(button)
	_b(hat, u, Vector3(0.06, 0.06, 0.02), Vector3(0.19, 0.4, -0.66), gold.lightened(0.45), Vector3(-0.18, 0, 0))
	_b(hat, u, Vector3(0.2, 0.27, 0.05), Vector3(-0.2, 0.36, -0.62), gold, Vector3(-0.18, 0, 0), false, 0.6)
	_b(hat, u, Vector3(0.15, 0.21, 0.02), Vector3(-0.2, 0.36, -0.65), gold.darkened(0.3), Vector3(-0.18, 0, 0))
	_b(hat, u, Vector3(0.08, 0.07, 0.02), Vector3(-0.2, 0.32, -0.665), gold, Vector3(-0.18, 0, 0))
	for k in 4:
		_b(hat, u, Vector3(0.016, 0.07, 0.02), Vector3(-0.23 + k * 0.02, 0.39, -0.668), gold, Vector3(-0.18, 0, 0))
	# The hair: [base, tilt (x back, z out), length, width], jagged and swept back.
	var spikes := [
		[Vector3(0, 0.3, 0.25), Vector3(0.75, 0, 0), 0.8, 0.34],
		[Vector3(-0.25, 0.28, 0.25), Vector3(0.85, 0, 0.35), 0.72, 0.32],
		[Vector3(0.25, 0.28, 0.25), Vector3(0.85, 0, -0.35), 0.72, 0.32],
		[Vector3(-0.45, 0.18, 0.2), Vector3(0.9, 0, 0.9), 0.6, 0.3],
		[Vector3(0.45, 0.18, 0.2), Vector3(0.9, 0, -0.9), 0.6, 0.3],
		[Vector3(-0.15, 0.12, 0.45), Vector3(1.2, 0, 0.25), 0.65, 0.3],
		[Vector3(0.15, 0.12, 0.45), Vector3(1.2, 0, -0.25), 0.65, 0.3],
		[Vector3(0, 0.0, 0.5), Vector3(1.45, 0, 0), 0.55, 0.3],
		[Vector3(-0.5, 0.0, 0.15), Vector3(2.6, 0, 0.3), 0.42, 0.22],
		[Vector3(0.5, 0.0, 0.15), Vector3(2.6, 0, -0.3), 0.42, 0.22],
	]
	for i in spikes.size():
		var spike: Array = spikes[i]
		_spike(hat, u, spike[0], spike[1], spike[2], spike[3], hair if i % 3 else hair_light)


## One blocky spike of hair: three blocks narrowing to a point along its +Y.
static func _spike(hat: Node3D, u: float, base: Vector3, tilt: Vector3, length: float, width: float, tint: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = base * u
	pivot.rotation = tilt
	hat.add_child(pivot)
	for k in 3:
		var w := width * (1.0 - k * 0.32)
		var h := length / 3.0
		_b(pivot, u, Vector3(w, h * 1.05, w), Vector3(0, h * (k + 0.5), 0), tint)


## A big rubber monkey head pulled over the whole head: brown fur, a tan face
## with a heavy brow, wide eyes, a big grinning muzzle and round ears.
static func _monkey_mask(hat: Node3D, u: float) -> void:
	var fur := Color(0.36, 0.22, 0.12)
	var fur_dark := Color(0.26, 0.15, 0.08)
	var face := Color(0.86, 0.68, 0.5)
	var dark := Color(0.08, 0.05, 0.04)
	# The head: bigger than the wearer's, down over the face.
	_b(hat, u, Vector3(1.04, 1.0, 1.0), Vector3(0, -0.3, 0.02), fur)
	_b(hat, u, Vector3(0.3, 0.16, 0.3), Vector3(0, 0.24, 0.05), fur_dark)  # A tuft on top.
	_b(hat, u, Vector3(0.16, 0.12, 0.16), Vector3(0.06, 0.34, 0.02), fur_dark)
	# The face plate, brow and eyes.
	_b(hat, u, Vector3(0.8, 0.66, 0.08), Vector3(0, -0.36, -0.5), face)
	_b(hat, u, Vector3(0.84, 0.12, 0.14), Vector3(0, -0.06, -0.52), fur_dark)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.18, 0.16, 0.04), Vector3(0.18 * side, -0.2, -0.55), Color(0.97, 0.95, 0.9))
		_b(hat, u, Vector3(0.09, 0.11, 0.04), Vector3(0.16 * side, -0.21, -0.57), dark)
		_b(hat, u, Vector3(0.03, 0.03, 0.02), Vector3(0.14 * side, -0.18, -0.59), Color(1, 1, 1))
	# The muzzle: a big snout with nostrils and a toothy grin.
	_b(hat, u, Vector3(0.6, 0.34, 0.24), Vector3(0, -0.56, -0.6), face.darkened(0.06))
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.07, 0.05, 0.03), Vector3(0.08 * side, -0.46, -0.73), dark)
	_b(hat, u, Vector3(0.44, 0.09, 0.03), Vector3(0, -0.62, -0.72), dark)
	_b(hat, u, Vector3(0.36, 0.05, 0.03), Vector3(0, -0.6, -0.735), Color(0.97, 0.95, 0.9))
	# Big round ears, tan inside.
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.2, 0.44, 0.4), Vector3(0.62 * side, -0.24, 0.02), fur)
		_b(hat, u, Vector3(0.06, 0.3, 0.26), Vector3(0.73 * side, -0.24, 0.0), face.darkened(0.1))


## A towering fruit basket on a ruffled hot-pink brim, ribbons trailing.
static func _fruit_hat(hat: Node3D, u: float) -> void:
	var pink := Color(1.0, 0.2, 0.6)
	var yellow := Color(1.0, 0.92, 0.35)
	_b(hat, u, Vector3(1.5, 0.07, 1.5), Vector3(0, 0.02, 0), pink)
	for i in 10:
		var a := i * TAU / 10.0
		_b(hat, u, Vector3(0.36, 0.14, 0.12), Vector3(sin(a) * 0.72, 0.06 + (i % 2) * 0.04, cos(a) * 0.72), pink if i % 2 == 0 else yellow, Vector3(0, a, 0.3))
	# Ribbons down one side.
	_b(hat, u, Vector3(0.14, 0.9, 0.08), Vector3(0.62, -0.42, 0.1), pink, Vector3(0, 0, 0.12))
	_b(hat, u, Vector3(0.12, 0.6, 0.08), Vector3(-0.66, -0.28, 0.05), yellow, Vector3(0, 0, -0.1))
	# The basket.
	_b(hat, u, Vector3(1.0, 0.34, 1.0), Vector3(0, 0.24, 0), Color(0.72, 0.5, 0.25))
	_b(hat, u, Vector3(1.06, 0.06, 1.06), Vector3(0, 0.4, 0), Color(0.6, 0.4, 0.18))
	# The fruit, piled up.
	_b(hat, u, Vector3(0.32, 0.32, 0.32), Vector3(-0.2, 0.58, -0.15), Color(1.0, 0.55, 0.1))  # Orange.
	_b(hat, u, Vector3(0.3, 0.3, 0.3), Vector3(0.22, 0.6, -0.12), Color(1.0, 0.62, 0.15))  # Orange.
	_b(hat, u, Vector3(0.26, 0.36, 0.26), Vector3(0.0, 0.72, 0.15), Color(0.95, 0.82, 0.3))  # Pear.
	_b(hat, u, Vector3(0.5, 0.12, 0.14), Vector3(0.05, 0.52, -0.4), Color(1.0, 0.9, 0.2), Vector3(0, 0.3, 0.2))  # Banana.
	for g in [Vector3(0.32, 0.5, 0.25), Vector3(0.4, 0.5, 0.15), Vector3(0.36, 0.42, 0.3), Vector3(0.44, 0.4, 0.22)]:
		_b(hat, u, Vector3(0.11, 0.11, 0.11), g, Color(0.4, 0.15, 0.45))  # Grapes.
	for g in [Vector3(-0.38, 0.48, 0.2), Vector3(-0.3, 0.42, 0.3), Vector3(-0.42, 0.4, 0.3)]:
		_b(hat, u, Vector3(0.11, 0.11, 0.11), g, Color(0.6, 0.85, 0.45))  # Green grapes.
	for c in [Vector3(-0.08, 0.6, -0.42), Vector3(0.0, 0.62, -0.46)]:
		_b(hat, u, Vector3(0.09, 0.09, 0.09), c, Color(0.85, 0.05, 0.1))  # Cherries.
	_b(hat, u, Vector3(0.2, 0.2, 0.16), Vector3(0.18, 0.46, -0.42), Color(0.85, 0.1, 0.15))  # Strawberry.
	# Pineapple leaves fanning out of the top.
	var leaf := Color(0.18, 0.55, 0.2)
	for i in 6:
		var a := i * TAU / 6.0
		_b(hat, u, Vector3(0.08, 0.42, 0.06), Vector3(sin(a) * 0.12, 1.0, cos(a) * 0.12), leaf, Vector3(cos(a) * 0.55, 0, -sin(a) * 0.55))
	_b(hat, u, Vector3(0.08, 0.5, 0.06), Vector3(0, 1.08, 0), leaf)


## A plumber's cap: a dome (w wide, h tall), a brim, and a square stitched
## patch on the front with a tool of the trade on it (flame, wrench,
## plunger, drop or coin). Deliberately no letters or round emblems.
static func _plumber_cap(hat: Node3D, u: float, cap: Color, icon: String, w := 1.0, h := 1.0) -> void:
	_b(hat, u, Vector3(1.1 * w, 0.3 * h, 1.1 * w), Vector3(0, -0.03 + 0.15 * h, 0), cap)
	_b(hat, u, Vector3(0.86 * w, 0.14, 0.86 * w), Vector3(0, -0.03 + 0.3 * h + 0.06, 0), cap)
	_b(hat, u, Vector3(0.12, 0.08, 0.12), Vector3(0, -0.03 + 0.3 * h + 0.15, 0), cap)
	_b(hat, u, Vector3(0.95 * w, 0.05, 0.6), Vector3(0, 0.0, -0.55 * w - 0.23), cap, Vector3(-0.1, 0, 0))
	var y := -0.03 + 0.15 * h + 0.05
	var z := -0.55 * w
	_b(hat, u, Vector3(0.36, 0.3, 0.03), Vector3(0, y, z - 0.015), cap.darkened(0.35))
	_b(hat, u, Vector3(0.31, 0.25, 0.03), Vector3(0, y, z - 0.025), Color(0.94, 0.92, 0.86))
	var front := z - 0.04
	match icon:
		"flame":
			var red := Color(0.95, 0.3, 0.08)
			_b(hat, u, Vector3(0.14, 0.07, 0.03), Vector3(0, y - 0.07, front), red)
			_b(hat, u, Vector3(0.1, 0.08, 0.03), Vector3(0.01, y - 0.0, front), red)
			_b(hat, u, Vector3(0.06, 0.08, 0.03), Vector3(0.03, y + 0.06, front), Color(1.0, 0.7, 0.15), Vector3(0, 0, 0.4))
			_b(hat, u, Vector3(0.05, 0.05, 0.03), Vector3(0, y - 0.05, front - 0.005), Color(1.0, 0.85, 0.3))
		"wrench":
			var steel := Color(0.35, 0.36, 0.4)
			_b(hat, u, Vector3(0.04, 0.2, 0.03), Vector3(0, y - 0.01, front), steel, Vector3(0, 0, 0.75))
			for side in [-1.0, 1.0]:
				_b(hat, u, Vector3(0.03, 0.06, 0.03), Vector3(-0.06 + 0.025 * side, y + 0.085 + 0.02 * side, front), steel, Vector3(0, 0, 0.75))
		"plunger":
			_b(hat, u, Vector3(0.03, 0.16, 0.03), Vector3(0, y + 0.03, front), Color(0.5, 0.32, 0.16))
			_b(hat, u, Vector3(0.14, 0.06, 0.03), Vector3(0, y - 0.07, front), Color(0.75, 0.12, 0.1))
		"drop":
			var blue := Color(0.2, 0.5, 0.95)
			_b(hat, u, Vector3(0.1, 0.1, 0.03), Vector3(0, y - 0.04, front), blue, Vector3(0, 0, PI / 4.0))
			_b(hat, u, Vector3(0.04, 0.08, 0.03), Vector3(0, y + 0.04, front), blue)
		"coin":
			var gold := Color(0.85, 0.62, 0.12)
			_b(hat, u, Vector3(0.14, 0.1, 0.03), Vector3(0, y, front), gold)
			_b(hat, u, Vector3(0.1, 0.14, 0.03), Vector3(0, y, front), gold)
			_b(hat, u, Vector3(0.02, 0.08, 0.03), Vector3(0, y, front - 0.005), gold.darkened(0.35))


## The blonde flat top: hair standing straight up off the head and flaring
## wider as it goes (a short cone upside down), dead flat on top with a rim,
## and a point dipping down to the forehead.
static func _flattop(hat: Node3D, u: float) -> void:
	var blonde := Color(0.92, 0.72, 0.38)
	var shade := blonde.darkened(0.25)
	var layers := 4
	for i in layers:
		var w := 0.9 + i * 0.12
		_b(hat, u, Vector3(w, 0.13, w * 0.92), Vector3(0, 0.0 + i * 0.12, 0.02), blonde if i % 2 == 0 else blonde.darkened(0.08))
	var top_y := (layers - 1) * 0.12 + 0.07
	var top_w := 0.9 + (layers - 1) * 0.12
	_b(hat, u, Vector3(top_w + 0.04, 0.04, (top_w + 0.04) * 0.92), Vector3(0, top_y, 0.02), blonde.lightened(0.15))
	_b(hat, u, Vector3(top_w - 0.16, 0.045, (top_w - 0.16) * 0.92), Vector3(0, top_y + 0.005, 0.02), blonde.darkened(0.05))
	# Strands running up the front.
	for i in 5:
		_b(hat, u, Vector3(0.03, 0.4, 0.03), Vector3(-0.3 + i * 0.15, 0.2, -0.5), shade, Vector3(-0.14, 0, (i - 2) * -0.12))
	# The point down to the forehead.
	for i in 3:
		_b(hat, u, Vector3(0.22 - i * 0.07, 0.07, 0.06), Vector3(0, -0.08 - i * 0.07, -0.47), blonde)


## Bootleg electric mouse ears: a cheap black plastic headband, two tall
## yellow ears with brown tips (a knock-off, so not quite right), and a
## little yellow bolt sticking up between them.
static func _mouse_ears(hat: Node3D, u: float) -> void:
	var yellow := Color(1.0, 0.85, 0.15)
	var tip := Color(0.32, 0.2, 0.1)
	_b(hat, u, Vector3(1.12, 0.06, 0.16), Vector3(0, 0.0, 0), Color(0.08, 0.08, 0.09))
	for side: float in [-1.0, 1.0]:
		var tilt := -0.42 * side
		var up := Vector3(-sin(tilt), cos(tilt), 0)
		var base := Vector3(0.34 * side, 0.02, 0)
		_b(hat, u, Vector3(0.24, 0.5, 0.1), base + up * 0.28, yellow, Vector3(0, 0, tilt))
		_b(hat, u, Vector3(0.18, 0.2, 0.11), base + up * 0.62, tip, Vector3(0, 0, tilt))
	# The bolt: three blocks zigzagging up.
	_b(hat, u, Vector3(0.06, 0.12, 0.05), Vector3(0.02, 0.1, 0), yellow, Vector3(0, 0, 0.5))
	_b(hat, u, Vector3(0.12, 0.05, 0.05), Vector3(0, 0.17, 0), yellow)
	_b(hat, u, Vector3(0.06, 0.12, 0.05), Vector3(-0.02, 0.24, 0), yellow, Vector3(0, 0, 0.5))


## The armored faceplate: a red helmet over the whole head, a gold face with
## glowing eye slits and a mouth line.
static func _faceplate(hat: Node3D, u: float) -> void:
	var red := Color(0.72, 0.08, 0.08)
	var gold := Color(0.9, 0.72, 0.28)
	_b(hat, u, Vector3(1.1, 1.0, 1.06), Vector3(0, -0.3, 0.03), red, Vector3.ZERO, false, 0.6)
	_b(hat, u, Vector3(0.3, 0.12, 0.9), Vector3(0, 0.22, 0.05), red.lightened(0.1), Vector3.ZERO, false, 0.6)
	_b(hat, u, Vector3(0.8, 0.74, 0.08), Vector3(0, -0.4, -0.52), gold, Vector3.ZERO, false, 0.7)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.22, 0.06, 0.03), Vector3(0.17 * side, -0.25, -0.57), Color(0.75, 0.95, 1.0), Vector3(0, 0, -0.12 * side), true)
		_b(hat, u, Vector3(0.12, 0.34, 0.06), Vector3(0.36 * side, -0.52, -0.5), gold.darkened(0.15), Vector3(0, 0, 0.12 * side), false, 0.7)
	_b(hat, u, Vector3(0.3, 0.03, 0.03), Vector3(0, -0.62, -0.57), Color(0.2, 0.12, 0.05))


## The snow queen's tiara: platinum hair swept up under a silver band of ice
## crystals, a snowflake up front, and a braid over one shoulder.
static func _tiara(hat: Node3D, u: float) -> void:
	var hair := Color(0.96, 0.9, 0.7)
	var silver := Color(0.82, 0.88, 0.95)
	var ice := Color(0.55, 0.88, 1.0)
	# Platinum hair swept back off the face, a little volume on top.
	_b(hat, u, Vector3(1.08, 0.22, 1.06), Vector3(0, 0.05, 0.06), hair)
	_b(hat, u, Vector3(0.86, 0.14, 0.7), Vector3(0, 0.2, 0.14), hair.darkened(0.06))
	for i in 5:
		_b(hat, u, Vector3(0.03, 0.04, 0.9), Vector3(-0.3 + i * 0.15, 0.17, 0.08), hair.darkened(0.14))
	for i in 8:
		var a := i * TAU / 8.0
		_b(hat, u, Vector3(0.36, 0.05, 0.04), Vector3(sin(a) * 0.52, 0.12, cos(a) * 0.52), silver, Vector3(0, a, 0), false, 0.6)
	for x: float in [-0.32, -0.16, 0.16, 0.32]:
		_b(hat, u, Vector3(0.07, 0.2 - absf(x) * 0.25, 0.04), Vector3(x, 0.24, -0.5 + absf(x) * 0.15), ice, Vector3.ZERO, true)
	for turn in [0.0, PI / 3.0, -PI / 3.0]:
		_b(hat, u, Vector3(0.06, 0.36, 0.04), Vector3(0, 0.34, -0.54), ice, Vector3(0, 0, turn), true)
	_b(hat, u, Vector3(0.1, 0.1, 0.05), Vector3(0, 0.34, -0.55), Color(0.92, 0.98, 1.0), Vector3(0, 0, PI / 4.0), true)
	# The braid: down the left side, over the shoulder.
	for i in 6:
		_b(hat, u, Vector3(0.18 - i * 0.015, 0.16, 0.18 - i * 0.015), Vector3(-0.5 - i * 0.02, -0.15 - i * 0.17, 0.05 - i * 0.07), hair if i % 2 == 0 else hair.darkened(0.1), Vector3(0.3, 0, 0.2))


## The evil doctor's mask: a riveted iron face with dark eye holes and a
## mouth grille, inside a green hood.
static func _doctor_mask(hat: Node3D, u: float) -> void:
	var green := Color(0.12, 0.42, 0.2)
	var iron := Color(0.62, 0.64, 0.68)
	_b(hat, u, Vector3(1.24, 0.3, 1.2), Vector3(0, 0.08, 0.04), green)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.14, 1.0, 1.2), Vector3(0.62 * side, -0.38, 0.04), green)
	_b(hat, u, Vector3(1.24, 1.0, 0.16), Vector3(0, -0.38, 0.6), green)
	_b(hat, u, Vector3(0.88, 0.84, 0.1), Vector3(0, -0.36, -0.52), iron, Vector3.ZERO, false, 0.8)
	_b(hat, u, Vector3(0.9, 0.1, 0.12), Vector3(0, -0.1, -0.55), iron.darkened(0.15), Vector3.ZERO, false, 0.8)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.16, 0.07, 0.03), Vector3(0.17 * side, -0.24, -0.58), Color(0.04, 0.04, 0.05))
		for k in 3:
			_b(hat, u, Vector3(0.04, 0.04, 0.02), Vector3(0.36 * side, -0.1 - k * 0.25, -0.58), iron.lightened(0.15), Vector3.ZERO, false, 0.8)
	for k in 4:
		_b(hat, u, Vector3(0.04, 0.12, 0.03), Vector3(-0.12 + k * 0.08, -0.6, -0.58), Color(0.08, 0.08, 0.09))


## A drawn-on hairline: the head bare (its hair comes off), marker-black
## painted over the top and down the sides, bald temples either side of a
## sharp triangle widow's peak, and square black sunglasses.
static func _drawn_hairline(hat: Node3D, u: float) -> void:
	# Painted on, so head-sized (hats are built SIZE times bigger to read):
	# in head widths, the scalp's sides sit at about 0.53 and its back at 0.52.
	u /= SIZE
	var ink := Color(0.04, 0.035, 0.04)
	# Over the top of the scalp, a touch under the hat seat.
	_b(hat, u, Vector3(0.92, 0.05, 0.86), Vector3(0, -0.05, 0.06), ink)
	# The peak: a triangle pointing down the forehead.
	for i in 4:
		_b(hat, u, Vector3(0.36 - i * 0.09, 0.07, 0.03), Vector3(0, -0.12 - i * 0.07, -0.53), ink)
	# Painted down the sides of the head to above the ears, and the back.
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.03, 0.36, 0.78), Vector3(0.55 * side, -0.24, 0.08), ink)
		_b(hat, u, Vector3(0.08, 0.06, 0.78), Vector3(0.51 * side, -0.07, 0.08), ink)
	_b(hat, u, Vector3(1.08, 0.42, 0.03), Vector3(0, -0.25, 0.54), ink)
	# Square sunglasses resting on the face, arms back to the ears.
	var lens := Color(0.03, 0.03, 0.04)
	var frame := Color(0.5, 0.5, 0.52)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.26, 0.19, 0.03), Vector3(0.19 * side, -0.42, -0.56), lens, Vector3.ZERO, false, 0.9)
		_b(hat, u, Vector3(0.03, 0.03, 0.5), Vector3(0.55 * side, -0.38, -0.3), frame, Vector3.ZERO, false, 0.8)
	_b(hat, u, Vector3(0.16, 0.035, 0.03), Vector3(0, -0.37, -0.575), frame, Vector3.ZERO, false, 0.8)


## The earth warrior's hair and headband: black hair with bangs over the
## brow, a bun up top, a green band trimmed yellow, its ends tied behind.
static func _earth_headband(hat: Node3D, u: float) -> void:
	var hair := Color(0.06, 0.05, 0.06)
	var green := Color(0.28, 0.55, 0.22)
	var yellow := Color(0.95, 0.82, 0.3)
	_b(hat, u, Vector3(1.08, 0.26, 1.06), Vector3(0, 0.06, 0.04), hair)
	_b(hat, u, Vector3(0.36, 0.26, 0.36), Vector3(0, 0.3, 0.18), hair)
	_b(hat, u, Vector3(0.4, 0.06, 0.4), Vector3(0, 0.2, 0.18), green)
	_b(hat, u, Vector3(1.12, 0.1, 1.1), Vector3(0, -0.07, 0), green)
	_b(hat, u, Vector3(1.13, 0.025, 1.11), Vector3(0, -0.02, 0), yellow)
	for i in 4:
		_b(hat, u, Vector3(0.2, 0.26, 0.06), Vector3(-0.3 + i * 0.2, -0.2, -0.53), hair, Vector3(0.15, 0, (i - 1.5) * 0.15))
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.06, 0.34, 0.03), Vector3(0.1 * side, -0.25, 0.58), green, Vector3(0.3, 0, 0.3 * side))


## The speedster's cowl: red over the head and upper face, white eye lenses,
## gold lightning bolts for ears.
static func _speed_cowl(hat: Node3D, u: float) -> void:
	var red := Color(0.8, 0.08, 0.08)
	var gold := Color(1.0, 0.8, 0.2)
	_b(hat, u, Vector3(1.12, 0.3, 1.1), Vector3(0, 0.08, 0.02), red)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.14, 0.8, 1.0), Vector3(0.56 * side, -0.3, 0.04), red)
	_b(hat, u, Vector3(1.12, 0.85, 0.16), Vector3(0, -0.3, 0.52), red)
	_b(hat, u, Vector3(0.86, 0.36, 0.08), Vector3(0, -0.24, -0.52), red)
	for side in [-1.0, 1.0]:
		_b(hat, u, Vector3(0.17, 0.07, 0.03), Vector3(0.16 * side, -0.24, -0.57), Color(0.97, 0.97, 0.97), Vector3(0, 0, -0.15 * side))
		_b(hat, u, Vector3(0.05, 0.2, 0.05), Vector3(0.64 * side, -0.08, 0.02), gold, Vector3(0, 0, 0.6 * side))
		_b(hat, u, Vector3(0.05, 0.2, 0.05), Vector3(0.66 * side, -0.22, 0.02), gold, Vector3(0, 0, -0.6 * side))
		_b(hat, u, Vector3(0.05, 0.2, 0.05), Vector3(0.68 * side, -0.36, 0.02), gold, Vector3(0, 0, 0.6 * side))


## One block of a hat: size and position in head widths.
static func _b(parent: Node3D, u: float, size: Vector3, pos: Vector3, tint: Color, rot := Vector3.ZERO, glow := false, metal := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size * u
	mesh.material = Enemy._glow_material(tint) if glow else Look.block_material(tint, metal)
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = pos * u
	part.rotation = rot
	parent.add_child(part)
	return part


## A sparkle cloud in the hat's rarity color (legendaries on enemies, the popup).
static func sparkles(parent: Node3D, tint: Color, radius := 0.35) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 18
	particles.lifetime = 1.2
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = radius
	particles.gravity = Vector3(0, 0.3, 0)
	particles.initial_velocity_min = 0.05
	particles.initial_velocity_max = 0.2
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(tint.lightened(0.5), 0.0))
	ramp.add_point(0.3, Color(tint.lightened(0.3), 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(tint, 0.0))
	particles.color_ramp = ramp
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.035
	var material := Enemy._glow_material(tint)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	particles.mesh = mesh
	parent.add_child(particles)
	return particles
