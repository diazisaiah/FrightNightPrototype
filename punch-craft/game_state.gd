extends Node
## Persistent progression (autoloaded as GameState). Shared: coins, Champion
## Souls, the armory, the upgrade web and what's been cleared. Per class: level,
## XP, attributes (Attributes) and that fighter's cards (Cards). Saved to disk.

signal changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://save.json"
## Test runs set FRIGHT_NIGHT_SAVE (e.g. "user://test_save.json") so they can
## never overwrite the player's real save; they also skip the old-save import.
var save_path: String = OS.get_environment("FRIGHT_NIGHT_SAVE") if OS.get_environment("FRIGHT_NIGHT_SAVE") != "" else SAVE_PATH
## Bump when saved data stops being compatible; older saves are ignored.
const SAVE_VERSION := 2
## Caps on what upgrades, cards, attributes and gear can add (2026-10-15: dodge and
## counter windows grew too forgiving).
const MAX_DODGE_WINDOW_BONUS := 0.25
const MAX_COUNTER_WINDOW_BONUS := 0.5
## Combo time gear can add (2026-10-28, for the White Strong Guy Wig).
const MAX_COMBO_WINDOW_BONUS := 1.0
## The power hats (Hats.POWER_HATS): each one's boost and the power numbers
## it raises, by 10% (the Golden Fleece Cap's all_power_boost, every power).
const HAT_BOOSTS := {
	"sigil_fire": ["boost_fire", ["fire_punch", "burn"]], "sigil_storm": ["boost_storm", ["chain_damage"]],
	"sigil_frost": ["boost_frost", ["frost_punch", "brittle"]], "sigil_blood": ["boost_blood", ["heal_on_kill", "counter_heal"]],
	"sigil_quake": ["boost_quake", ["quake_power", "quake_damage"]], "sigil_gale": ["boost_gale", ["gale", "gale_damage"]],
	"sigil_iron": ["boost_iron", ["plate_guard"]], "sigil_doom": ["boost_doom", ["doom"]],
}
const MAX_ARMOR_PIERCE := 0.75

# Each class changes how you fight. mods multiply (or add, for defense and
# combo_window) the base numbers; missing keys mean no change. Class specials
# are implemented in player.gd.
const CLASSES := {
	"berserker": {
		"name": "Berserker", "icon": "hammer",
		"fighter": "The Mauler", "color": Color(1.0, 0.42, 0.12),
		"tagline": "Takes the hit. Gives it back.",
		"traits": [["skull", "Grudge", "Hit him once. Regret it."], ["burst", "Massive Damage", "Break bones."], ["flame", "Inferno Uppercut", "Launch them to hell."]],
		"bars": {"Power": 95, "Defense": 80, "Speed": 40, "Combo": 35, "Counter": 55},
		"desc": "Big damage, tough knuckles. Holds a grudge: whatever hits him is marked, and his next punch on it hits triple and staggers. Hooks and uppercuts need no setup. Combos grow slower.",
		"mods": {"damage": 1.3, "knuckles": 1.25, "defense": 3.0, "combo_step": 0.6},
	},
	"counter_master": {
		"name": "Counter Master", "icon": "target",
		"fighter": "The Answer", "color": Color(0.31, 0.83, 1.0),
		"tagline": "Every attack is a question.",
		"traits": [["shield", "Perfect Defense", "Read their move."], ["target", "Counter Focus", "Turn their strength against them."], ["star", "Perfect Counter", "Counter for x2.5."]],
		"bars": {"Power": 55, "Defense": 70, "Speed": 60, "Combo": 45, "Counter": 100},
		"desc": "Less damage and knuckles. Counters deal x3, dodge windows are wider, and counters have a 50% chance to cost no knuckle HP. Perfect counter: dodge, then a hook or uppercut with the matching hand deals x2.5 more (12s cooldown).",
		"mods": {"damage": 0.85, "knuckles": 0.9, "counter": 3.0, "dodge_window": 1.4},
	},
	"combo_master": {
		"name": "Combo Master", "icon": "bolt",
		"fighter": "The Blur", "color": Color(0.58, 0.4, 1.0),
		"tagline": "Fifty hits before they blink.",
		"traits": [["swoosh", "Rapid Combos", "Keep them guessing."], ["bolt", "Fast Hands", "Speed is survival."], ["clock", "Temporal Break", "Time stops for you."]],
		"bars": {"Power": 45, "Defense": 50, "Speed": 95, "Combo": 100, "Counter": 50},
		"desc": "Faster punches, less damage. Combos grow faster and last longer. Every 5th hit in a combo stuns nearby enemies and freezes the combo timer for 1s.",
		"mods": {"damage": 0.75, "punch_speed": 1.35, "combo_step": 1.5, "combo_window": 1.0},
	},
	"free_runner": {
		"name": "Free Runner", "icon": "boot",
		"fighter": "The Stray", "color": Color(0.25, 0.9, 0.42),
		"tagline": "Never where they swing.",
		"traits": [["boot", "Agile Movement", "Never stay still."], ["swoosh", "Dash Punches", "Spear through. Blast back."], ["chain", "Highlight Reel", "Keep it going."]],
		"bars": {"Power": 60, "Defense": 50, "Speed": 100, "Combo": 60, "Counter": 50},
		"desc": "Faster sprint, normal stats. Dash forward and punch: a left Spear Jab hits everything in a straight line, a right Haymaker blasts enemies back. Jump punches deal x2 to enemies under 30% HP.",
		"mods": {"sprint": 1.35},
	},
	"wise_guy": {
		"name": "Wise Guy", "icon": "rage",
		"fighter": "Tony", "color": Color(1.0, 0.72, 0.18),
		"tagline": "Ey. I'm fightin' here.",
		"traits": [["rage", "Big Mouth", "Taunt a monster into a duel."], ["burst", "Wise Up", "Hits harder. Bleeds more."], ["shield", "Fuggedaboudit", "Ignore one hit every 10s."]],
		"bars": {"Power": 65, "Defense": 35, "Speed": 60, "Combo": 55, "Counter": 85},
		"desc": "Found out too late that processed meat is a carcinogen. He's punching his way out of the underworld for one more bite of that deli sandwich. Big Mouth refills fast: insult a monster and it comes only for Tony, hitting 50% harder and taking double damage from him. Fuggedaboudit waves off one hit every 10s.",
		"mods": {"knuckles": 0.9},
	},
	"elementalist": {
		"name": "Elementalist", "icon": "flame",
		"fighter": "The Catalyst", "color": Color(0.95, 0.4, 0.7),
		"tagline": "Why cast it when you can punch it?",
		"traits": [["flame", "Dual Sigil", "Two powers at once."], ["bolt", "Elemental Fists", "Fire, ice, storm and blood."], ["burst", "Flame Burst", "Set the ring alight."]],
		"bars": {"Power": 60, "Defense": 60, "Speed": 55, "Combo": 55, "Counter": 55},
		"desc": "An old wizard who put his spells into his fists. Runs two powers at once. His ultimate turns punches into fireballs, icicles, lightning and blood.",
		"mods": {"damage": 0.9},
	},
}
## Tony: the secret fighter, playable once all four Yonker hats are collected
## (tony_unlocked). Hidden from the class picker until then.
const SECRET_CLASSES := ["wise_guy"]
## Fighters bought in the Soul Shop (SoulShop.FIGHTERS): hidden until bought.
const SHOP_CLASSES := ["elementalist"]
## The Catalyst: power numbers his passive amplifies (not counts or switches).
const AMPLIFIED := [
	"fire_punch", "burn", "burn_time", "fire_chance", "fire_radius", "frost_punch", "frost_time", "frost_radius",
	"brittle", "frost_chance", "chain_damage", "heal_on_kill", "counter_heal", "last_stand",
	"quake_power", "quake_damage", "quake_radius", "quake_chance", "gale", "gale_damage", "doom", "doom_time", "doom_chance",
]
## Attunement: how much stronger the one power is (plus passive power).
const ATTUNE := 1.5
## Prism: how many powers at once (their base nodes).
const PRISM_SLOTS := 4
## Every power's Sigil, in climb order: the four elements (Dead League
## seals), then the four Endless powers (each division's endless bout).
const POWER_ROOTS := ["sigil_fire", "sigil_frost", "sigil_storm", "sigil_blood", "sigil_quake", "sigil_gale", "sigil_iron", "sigil_doom"]
const DEFAULT_CLASS := "berserker"

const RESOURCE_NAMES := {
	"coins": "Coins",
}

## Card respecs, in Souls: a reroll costs one more each time on the same
## draw; a swap by the card's rarity; a full redraft returns every card.
const REROLL_SOULS := 1
const SWAP_SOULS := {"common": 2, "rare": 3, "epic": 5, "legendary": 8}
const REDRAFT_SOULS := 15
## Passive power (Abilities.POWER_TEXT): a point every few levels, up to a cap.
const PASSIVE_POWER_EVERY := 4
const PASSIVE_POWER_MAX := 9

# The upgrade web (bought with coins).
# pos: cell in the tree view (x = column from center, y = row).
# requires: nodes that must be at least level 1 first.
# cost: price of level 1; each further level costs cost_growth times more.
# effects: added once per level owned.
# ring: which seal layer the node sits in (1 is open from the start; each Dead
# League win opens the next; 6 = after the Coffin King). medallion: drawn as a
# big round node (powers, capstones, trophies, ultimate nodes).

# The web sits around a center node (x = columns right, y = rows down),
# with upgrade types mixed together, in five sealed rings (see Progression).
# Four Sigil nodes each unlock a power (Fire, Frost, Storm, Blood) when their
# ring opens. Each sits in its own corner of the web (needing nothing but its
# seal), with three branches upgrading it different ways (damage, duration,
# reach, how often it triggers) that meet at its capstone.
const UPGRADES := {
	# Seal rings (2026-10-28): every node sits on the ring of the seal that
	# opens it (ring + 0.5 cells out), evenly spaced around it: 8 nodes on
	# rings 1 and 4, 12 on rings 2 and 3, 16 on rings 5 and 6. The spokes run
	# straight out (damage east, defense south, knuckle HP west, coins north);
	# side nodes hang off a spoke along their ring. Prices round to two
	# figures (price_at).
	"wrapped_knuckles": {
		"name": "Taped Up", "icon": "wraps", "pos": Vector2(0, 0), "requires": [], "ring": 1,
		"desc": "Tape and cloth. Every road out of here starts with your hands.",
		"max_level": 1, "cost": 60, "cost_growth": 1, "effects": {"damage": 1, "max_knuckles": 5},
	},
	"dmg_1": {
		"name": "Bricks for Hands", "icon": "fist", "pos": Vector2(1.5, 0), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 80, "cost_growth": 1.22, "effects": {"damage": 1},
	},
	"dmg_2": {
		"name": "Iron Fists", "icon": "fist", "pos": Vector2(2.5, 0), "requires": ["dmg_1"], "ring": 2,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 400, "cost_growth": 1.22, "effects": {"damage": 1},
	},
	"dmg_3": {
		"name": "Sledge Fists", "icon": "hammer", "pos": Vector2(3.5, 0), "requires": ["dmg_2"], "ring": 3,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 1600, "cost_growth": 1.22, "effects": {"damage": 2},
	},
	"dmg_4": {
		"name": "Wrecking Fists", "icon": "hammer", "pos": Vector2(4.5, 0), "requires": ["dmg_3"], "ring": 4,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 8000, "cost_growth": 1.22, "effects": {"damage": 3},
	},
	"dmg_5": {
		"name": "Anvil Hands", "icon": "anvil", "pos": Vector2(5.5, 0), "requires": ["dmg_4"], "ring": 5,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 60000, "cost_growth": 1.22, "effects": {"damage": 4},
	},
	"dmg_6": {
		"name": "Hands of the Damned", "icon": "anvil", "pos": Vector2(6.5, 0), "requires": ["dmg_5"], "ring": 6,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 300000, "cost_growth": 1.22, "effects": {"damage": 6},
	},
	"hp_1": {
		"name": "Leather Knuckles", "icon": "heart", "pos": Vector2(-1.5, 0), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 80, "cost_growth": 1.22, "effects": {"max_knuckles": 5},
	},
	"hp_2": {
		"name": "Rawhide", "icon": "heart_plus", "pos": Vector2(-2.5, 0), "requires": ["hp_1"], "ring": 2,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 400, "cost_growth": 1.22, "effects": {"max_knuckles": 10},
	},
	"hp_3": {
		"name": "Thick Skin", "icon": "heart", "pos": Vector2(-3.5, 0), "requires": ["hp_2"], "ring": 3,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 1600, "cost_growth": 1.22, "effects": {"max_knuckles": 15},
	},
	"hp_4": {
		"name": "Iron Knuckles", "icon": "heart_plus", "pos": Vector2(-4.5, 0), "requires": ["hp_3"], "ring": 4,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 8000, "cost_growth": 1.22, "effects": {"max_knuckles": 20},
	},
	"hp_5": {
		"name": "Grave Hide", "icon": "heartbeat", "pos": Vector2(-5.5, 0), "requires": ["hp_4"], "ring": 5,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 60000, "cost_growth": 1.22, "effects": {"max_knuckles": 30},
	},
	"hp_6": {
		"name": "Undying Hide", "icon": "heartbeat", "pos": Vector2(-6.5, 0), "requires": ["hp_5"], "ring": 6,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 300000, "cost_growth": 1.22, "effects": {"max_knuckles": 40},
	},
	"def_1": {
		"name": "Mouthguard", "icon": "tooth", "pos": Vector2(0, 1.5), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 120, "cost_growth": 1.22, "effects": {"defense": 0.5},
	},
	"def_2": {
		"name": "High Guard", "icon": "shield", "pos": Vector2(0, 2.5), "requires": ["def_1"], "ring": 2,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 600, "cost_growth": 1.22, "effects": {"defense": 1},
	},
	"def_3": {
		"name": "Ribcage Armor", "icon": "bones", "pos": Vector2(0, 3.5), "requires": ["def_2"], "ring": 3,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 2400, "cost_growth": 1.22, "effects": {"defense": 1},
	},
	"def_4": {
		"name": "Bone Plating", "icon": "chestplate", "pos": Vector2(0, 4.5), "requires": ["def_3"], "ring": 4,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 12000, "cost_growth": 1.22, "effects": {"defense": 2},
	},
	"def_5": {
		"name": "Tombstone Chin", "icon": "helmet", "pos": Vector2(0, 5.5), "requires": ["def_4"], "ring": 5,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 90000, "cost_growth": 1.22, "effects": {"defense": 2},
	},
	"def_6": {
		"name": "Iron Coffin", "icon": "shield", "pos": Vector2(0, 6.5), "requires": ["def_5"], "ring": 6,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 450000, "cost_growth": 1.22, "effects": {"defense": 3},
	},
	"gold_1": {
		"name": "Grave Robber", "icon": "shovel", "pos": Vector2(-0, -1.5), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 100, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"gold_2": {
		"name": "Grave Tax", "icon": "bag", "pos": Vector2(-0, -2.5), "requires": ["gold_1"], "ring": 2,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 500, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"gold_3": {
		"name": "Grave Gold", "icon": "chest", "pos": Vector2(-0, -3.5), "requires": ["gold_2"], "ring": 3,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 2000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"gold_4": {
		"name": "Loan Shark", "icon": "bag", "pos": Vector2(-0, -4.5), "requires": ["gold_3"], "ring": 4,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 10000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.1},
	},
	"gold_5": {
		"name": "Undertaker's Cut", "icon": "chest", "pos": Vector2(-0, -5.5), "requires": ["gold_4"], "ring": 5,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 75000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.1},
	},
	"gold_6": {
		"name": "King's Ransom", "icon": "crown", "pos": Vector2(-0, -6.5), "requires": ["gold_5"], "ring": 6,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 380000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.15},
	},
	"heavy_hitter": {
		"name": "Haymaker", "icon": "hammer", "pos": Vector2(2.17, 1.25), "requires": ["dmg_2"], "ring": 2,
		"desc": "Set-up hooks and uppercuts hit harder.",
		"max_level": 5, "cost": 550, "cost_growth": 1.3, "effects": {"heavy_bonus": 0.15},
	},
	"counterpuncher": {
		"name": "Counterpuncher", "icon": "counter_arrow", "pos": Vector2(3.03, -1.75), "requires": ["dmg_3"], "ring": 3,
		"desc": "Counters hit harder.",
		"max_level": 5, "cost": 2000, "cost_growth": 1.3, "effects": {"counter_bonus": 0.3},
	},
	"rhythm": {
		"name": "Speed Bag", "icon": "note", "pos": Vector2(2.17, -1.25), "requires": ["dmg_2"], "ring": 2,
		"desc": "Combos build faster.",
		"max_level": 3, "cost": 550, "cost_growth": 1.3, "effects": {"combo_step": 0.05},
	},
	"lucky_shot": {
		"name": "Lucky Shot", "icon": "star", "pos": Vector2(3.03, 1.75), "requires": ["dmg_3"], "ring": 3,
		"desc": "Punches crit more often.",
		"max_level": 5, "cost": 2000, "cost_growth": 1.3, "effects": {"crit_chance": 0.05},
	},
	"glass_breaker": {
		"name": "Glass Breaker", "icon": "burst", "pos": Vector2(3.18, 3.18), "requires": ["dmg_4"], "ring": 4,
		"desc": "Critical hits hit even harder.",
		"max_level": 3, "cost": 9400, "cost_growth": 1.3, "effects": {"crit_damage": 0.25},
	},
	"armor_breaker": {
		"name": "Can Opener", "icon": "broken_shield", "pos": Vector2(3.18, -3.18), "requires": ["dmg_4"], "ring": 4,
		"desc": "Punch straight through enemy armor.",
		"max_level": 3, "cost": 9400, "cost_growth": 1.3, "effects": {"armor_pierce": 0.15},
	},
	"giant_killer": {
		"name": "Bigger They Fall", "icon": "crown", "pos": Vector2(3.89, 3.89), "requires": ["knuckle_dusters"], "ring": 5,
		"desc": "Bosses and champions take extra damage.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"boss_damage": 0.15},
	},
	"weighted_wraps": {
		"name": "Lead Tape", "icon": "dumbbell", "pos": Vector2(3.89, -3.89), "requires": ["heavy_hands"], "ring": 5,
		"desc": "Hooks and uppercuts cost less knuckle HP.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"heavy_cost_cut": 1},
	},
	"footwork_drills": {
		"name": "Jump Rope", "icon": "footprints", "pos": Vector2(1.06, 1.06), "requires": ["def_1"], "ring": 1,
		"desc": "A touch more time to dodge.",
		"max_level": 2, "cost": 130, "cost_growth": 1.3, "effects": {"dodge_window": 0.05},
	},
	"bob_and_weave": {
		"name": "Bob and Weave", "icon": "slip", "pos": Vector2(1.25, 2.17), "requires": ["def_2"], "ring": 2,
		"desc": "A little longer to land a counter.",
		"max_level": 2, "cost": 550, "cost_growth": 1.3, "effects": {"counter_window": 0.1},
	},
	"thick_skull": {
		"name": "Thick Skull", "icon": "helmet", "pos": Vector2(1.75, 3.03), "requires": ["def_3"], "ring": 3,
		"desc": "Grazes (right timing, wrong dodge) hurt less.",
		"max_level": 2, "cost": 2000, "cost_growth": 1.3, "effects": {"graze_reduction": 0.15},
	},
	"rope_a_dope": {
		"name": "Rope-a-Dope", "icon": "anchor", "pos": Vector2(-3.18, 3.18), "requires": ["def_4"], "ring": 4,
		"desc": "Grazes hurt less.",
		"max_level": 3, "cost": 9400, "cost_growth": 1.3, "effects": {"graze_reduction": 0.1},
	},
	"bellmans_bell": {
		"name": "The Bellman's Bell", "icon": "belt", "pos": Vector2(0, 0), "requires": ["wrapped_knuckles"], "center": true, "ring": 2,
		"desc": "Trophy: it still rings when you hit things.",
		"max_level": 3, "cost": 900, "cost_growth": 1.3, "effects": {"damage": 2, "max_knuckles": 10},
	},
	"headless_helm": {
		"name": "Headless Helm", "icon": "helmet", "pos": Vector2(0, 0), "requires": ["bellmans_bell"], "center": true, "ring": 3,
		"desc": "Trophy: no head, no problem.",
		"max_level": 3, "cost": 3500, "cost_growth": 1.3, "effects": {"damage": 2, "max_knuckles": 15, "defense": 1},
	},
	"southpaws_rosary": {
		"name": "Southpaw's Veil", "icon": "medal", "pos": Vector2(0, 0), "requires": ["headless_helm"], "center": true, "ring": 4,
		"desc": "Trophy: a little of her left hand, now yours.",
		"max_level": 3, "cost": 15000, "cost_growth": 1.3, "effects": {"damage": 3, "max_knuckles": 20, "defense": 2},
	},
	"plague_censer": {
		"name": "Plague Censer", "icon": "bucket", "pos": Vector2(0, 0), "requires": ["southpaws_rosary"], "center": true, "ring": 5,
		"desc": "Trophy: the cure smells terrible.",
		"max_level": 3, "cost": 110000, "cost_growth": 1.3, "effects": {"damage": 4, "max_knuckles": 30, "defense": 2},
	},
	"coffin_crown": {
		"name": "The Coffin Crown", "icon": "crown", "pos": Vector2(0, 0), "requires": ["plague_censer"], "center": true, "ring": 6,
		"desc": "Trophy: heavy is the head. Raw power for the endless dark.",
		"max_level": 5, "cost": 800000, "cost_growth": 1.3, "effects": {"damage": 5, "max_knuckles": 40, "defense": 3},
	},
	"cornerman": {
		"name": "Cornerman", "icon": "medkit", "pos": Vector2(-1.06, 1.06), "requires": ["hp_1"], "ring": 1,
		"desc": "Recover a little every tenth of the bout.",
		"max_level": 3, "cost": 130, "cost_growth": 1.3, "effects": {"wave_heal": 1},
	},
	"ice_bath": {
		"name": "Ice Bath", "icon": "bucket", "pos": Vector2(-2.17, 1.25), "requires": ["hp_2"], "ring": 2,
		"desc": "Recover a little every tenth of the bout.",
		"max_level": 2, "cost": 550, "cost_growth": 1.3, "effects": {"wave_heal": 1},
	},
	"second_wind": {
		"name": "Second Wind", "icon": "wind", "pos": Vector2(-3.03, 1.75), "requires": ["hp_3"], "ring": 3,
		"desc": "Heal more between waves.",
		"max_level": 2, "cost": 2000, "cost_growth": 1.3, "effects": {"wave_heal": 1},
	},
	"iron_will": {
		"name": "Chin Check", "icon": "anchor", "pos": Vector2(-2.17, -1.25), "requires": ["hp_2"], "ring": 2,
		"desc": "Shake off clean hits faster.",
		"max_level": 2, "cost": 550, "cost_growth": 1.3, "effects": {"flinch_reduction": 0.15},
	},
	"calloused": {
		"name": "Calloused", "icon": "tape", "pos": Vector2(-3.03, -1.75), "requires": ["hp_3"], "ring": 3,
		"desc": "Some punches don't hurt your hands at all.",
		"max_level": 3, "cost": 2000, "cost_growth": 1.3, "effects": {"free_punch_chance": 0.05},
	},
	"light_feet": {
		"name": "Twinkle Toes", "icon": "chevrons", "pos": Vector2(-1.06, -1.06), "requires": ["gold_1"], "ring": 1,
		"desc": "Faster on your feet.",
		"max_level": 2, "cost": 130, "cost_growth": 1.3, "effects": {"move_speed": 0.05},
	},
	"running_shoes": {
		"name": "Cemetery Sprint", "icon": "wing_boot", "pos": Vector2(-1.25, -2.17), "requires": ["gold_2"], "ring": 2,
		"desc": "Faster sprinting.",
		"max_level": 2, "cost": 550, "cost_growth": 1.3, "effects": {"sprint_bonus": 0.1},
	},
	"quick_wraps": {
		"name": "Snap Wraps", "icon": "fast_fist", "pos": Vector2(1.25, -2.17), "requires": ["gold_2"], "ring": 2,
		"desc": "Lighter wraps for faster hands.",
		"max_level": 3, "cost": 550, "cost_growth": 1.3, "effects": {"punch_speed": 0.05},
	},
	"bounty": {
		"name": "Crowd Pleaser", "icon": "wanted", "pos": Vector2(-1.75, -3.03), "requires": ["gold_3"], "ring": 3,
		"desc": "Bigger milestone bonuses in the Arena.",
		"max_level": 2, "cost": 2000, "cost_growth": 1.3, "effects": {"wave_bonus": 0.25},
	},
	"sparring_partner": {
		"name": "Sparring Partner", "icon": "crossed_gloves", "pos": Vector2(1.06, -1.06), "requires": ["gold_1"], "ring": 1,
		"desc": "Learn faster: more XP.",
		"max_level": 3, "cost": 130, "cost_growth": 1.3, "effects": {"xp_bonus": 0.1},
	},
	"night_owl": {
		"name": "Film Study", "icon": "moon", "pos": Vector2(1.75, -3.03), "requires": ["gold_3"], "ring": 3,
		"desc": "Learn even more from every fight.",
		"max_level": 3, "cost": 2000, "cost_growth": 1.3, "effects": {"xp_bonus": 0.15},
	},
	"dawn_patrol": {
		"name": "Prize Fighter", "icon": "sun", "pos": Vector2(-3.89, -3.89), "requires": ["tip_jar"], "ring": 5,
		"desc": "Bigger Arena purses.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"dawn_bonus": 0.25},
	},
	# Rings 5 and 6: in-between nodes halfway to the diagonals (2026-10-28).
	"knuckle_dusters": {
		"name": "Knuckle Dusters", "icon": "brass", "pos": Vector2(5.08, 2.1), "requires": ["dmg_5"], "ring": 5,
		"desc": "A little more damage.",
		"max_level": 2, "cost": 30000, "cost_growth": 1.22, "effects": {"damage": 2},
	},
	"heavy_hands": {
		"name": "Heavy Hands", "icon": "fist", "pos": Vector2(5.08, -2.1), "requires": ["dmg_5"], "ring": 5,
		"desc": "A little more damage.",
		"max_level": 2, "cost": 30000, "cost_growth": 1.22, "effects": {"damage": 2},
	},
	"iron_jaw": {
		"name": "Iron Jaw", "icon": "tooth", "pos": Vector2(2.1, 5.08), "requires": ["def_5"], "ring": 5,
		"desc": "A little more defense.",
		"max_level": 2, "cost": 45000, "cost_growth": 1.22, "effects": {"defense": 1},
	},
	"stone_wall": {
		"name": "Stone Wall", "icon": "shield", "pos": Vector2(-2.1, 5.08), "requires": ["def_5"], "ring": 5,
		"desc": "A little more defense.",
		"max_level": 2, "cost": 45000, "cost_growth": 1.22, "effects": {"defense": 1},
	},
	"scar_tissue": {
		"name": "Scar Tissue", "icon": "heart", "pos": Vector2(-5.08, 2.1), "requires": ["hp_5"], "ring": 5,
		"desc": "A little more knuckle HP.",
		"max_level": 2, "cost": 30000, "cost_growth": 1.22, "effects": {"max_knuckles": 15},
	},
	"old_wounds": {
		"name": "Old Wounds", "icon": "heart_plus", "pos": Vector2(-5.08, -2.1), "requires": ["hp_5"], "ring": 5,
		"desc": "A little more knuckle HP.",
		"max_level": 2, "cost": 30000, "cost_growth": 1.22, "effects": {"max_knuckles": 15},
	},
	"tip_jar": {
		"name": "Tip Jar", "icon": "coin", "pos": Vector2(-2.1, -5.08), "requires": ["gold_5"], "ring": 5,
		"desc": "A few more coins.",
		"max_level": 2, "cost": 37000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"back_pay": {
		"name": "Back Pay", "icon": "bag", "pos": Vector2(2.1, -5.08), "requires": ["gold_5"], "ring": 5,
		"desc": "A few more coins.",
		"max_level": 2, "cost": 37000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"coffin_nails": {
		"name": "Coffin Nails", "icon": "double_fist", "pos": Vector2(6.01, 2.49), "requires": ["dmg_6"], "ring": 6,
		"desc": "A little more damage.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.22, "effects": {"damage": 3},
	},
	"death_grip": {
		"name": "Death Grip", "icon": "glove", "pos": Vector2(6.01, -2.49), "requires": ["dmg_6"], "ring": 6,
		"desc": "A little more damage.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.22, "effects": {"damage": 3},
	},
	"crypt_door": {
		"name": "Crypt Door", "icon": "shield", "pos": Vector2(2.49, 6.01), "requires": ["def_6"], "ring": 6,
		"desc": "A little more defense.",
		"max_level": 2, "cost": 230000, "cost_growth": 1.22, "effects": {"defense": 1.5},
	},
	"vault_guard": {
		"name": "Vault Guard", "icon": "helmet", "pos": Vector2(-2.49, 6.01), "requires": ["def_6"], "ring": 6,
		"desc": "A little more defense.",
		"max_level": 2, "cost": 230000, "cost_growth": 1.22, "effects": {"defense": 1.5},
	},
	"grave_skin": {
		"name": "Grave Skin", "icon": "heart", "pos": Vector2(-6.01, 2.49), "requires": ["hp_6"], "ring": 6,
		"desc": "A little more knuckle HP.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.22, "effects": {"max_knuckles": 20},
	},
	"deathless": {
		"name": "Deathless", "icon": "heart_plus", "pos": Vector2(-6.01, -2.49), "requires": ["hp_6"], "ring": 6,
		"desc": "A little more knuckle HP.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.22, "effects": {"max_knuckles": 20},
	},
	"gold_teeth": {
		"name": "Gold Teeth", "icon": "coin", "pos": Vector2(-2.49, -6.01), "requires": ["gold_6"], "ring": 6,
		"desc": "A few more coins.",
		"max_level": 2, "cost": 190000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	"royal_treasury": {
		"name": "Royal Treasury", "icon": "chest", "pos": Vector2(2.49, -6.01), "requires": ["gold_6"], "ring": 6,
		"desc": "A few more coins.",
		"max_level": 2, "cost": 190000, "cost_growth": 1.22, "effects": {"coin_bonus": 0.05},
	},
	# New side upgrades for the even rings (2026-10-28).
	"head_movement": {
		"name": "Head Movement", "icon": "slip", "pos": Vector2(-1.25, 2.17), "requires": ["def_2"], "ring": 2,
		"desc": "A wider window to dodge.",
		"max_level": 2, "cost": 550, "cost_growth": 1.3, "effects": {"dodge_window": 0.05},
	},
	"rolling_guard": {
		"name": "Rolling Guard", "icon": "spiral", "pos": Vector2(-1.75, 3.03), "requires": ["def_3"], "ring": 3,
		"desc": "A longer window to counter.",
		"max_level": 2, "cost": 2000, "cost_growth": 1.3, "effects": {"counter_window": 0.1},
	},
	"iron_lungs": {
		"name": "Iron Lungs", "icon": "heartbeat", "pos": Vector2(-3.18, -3.18), "requires": ["hp_4"], "ring": 4,
		"desc": "Heal more between waves.",
		"max_level": 2, "cost": 9400, "cost_growth": 1.3, "effects": {"wave_heal": 1},
	},
	"unflinching": {
		"name": "Unflinching", "icon": "muscle", "pos": Vector2(-3.89, 3.89), "requires": ["scar_tissue"], "ring": 5,
		"desc": "Hits knock you off balance less.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"flinch_reduction": 0.15},
	},
	"granite_chin": {
		"name": "Granite Chin", "icon": "helmet", "pos": Vector2(4.6, 4.6), "requires": ["crypt_door"], "ring": 6,
		"desc": "Grazes hurt less.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.3, "effects": {"graze_reduction": 0.1},
	},
	"grave_wind": {
		"name": "Grave Wind", "icon": "wind", "pos": Vector2(-4.6, 4.6), "requires": ["grave_skin"], "ring": 6,
		"desc": "Heal more between waves.",
		"max_level": 3, "cost": 150000, "cost_growth": 1.3, "effects": {"wave_heal": 1},
	},
	"kings_purse": {
		"name": "King's Purse", "icon": "crown", "pos": Vector2(-4.6, -4.6), "requires": ["gold_teeth"], "ring": 6,
		"desc": "Bigger wave bonuses.",
		"max_level": 2, "cost": 150000, "cost_growth": 1.3, "effects": {"wave_bonus": 0.25},
	},
	"old_master": {
		"name": "Old Master", "icon": "medal", "pos": Vector2(4.6, -4.6), "requires": ["royal_treasury"], "ring": 6,
		"desc": "Learn more from every fight.",
		"max_level": 3, "cost": 150000, "cost_growth": 1.3, "effects": {"xp_bonus": 0.15},
	},
	# The four powers, one in each corner (2026-10-27; out to the same
	# distance as the Endless powers, 9 cells, 2026-10-28): a Sigil that needs only
	# its seal, three branches out of it, and a capstone where they meet
	# (every branch maxed first).
	"sigil_fire": {
		"name": "Hellfire", "icon": "flame", "pos": Vector2(6.36, -6.36), "requires": [], "ring": 2, "medallion": true,
		"desc": "Awakens FIRE: set-up heavies and counters burst into flame.",
		"max_level": 1, "cost": 1356, "cost_growth": 1.0, "effects": {"fire_punch": 0.3, "burn": 0.25},
	},
	"hotter_flames": {
		"name": "Brimstone", "icon": "thermometer", "pos": Vector2(5.44, -7.28), "requires": ["sigil_fire"], "ring": 2,
		"desc": "Bigger fire bursts.",
		"max_level": 3, "cost": 542, "cost_growth": 1.3, "effects": {"fire_punch": 0.2},
	},
	"fire_heart": {
		"name": "Furnace Heart", "icon": "flame", "pos": Vector2(5.44, -9.12), "requires": ["hotter_flames"], "ring": 3,
		"desc": "Even bigger fire bursts.",
		"max_level": 3, "cost": 1991, "cost_growth": 1.3, "effects": {"fire_punch": 0.15},
	},
	"wildfire": {
		"name": "Wildfire", "icon": "ripple", "pos": Vector2(7.28, -9.12), "requires": ["fire_heart"], "ring": 4,
		"desc": "Fire spreads farther.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"fire_radius": 1.0},
	},
	"lingering_flames": {
		"name": "Slow Burn", "icon": "clock", "pos": Vector2(7.28, -7.28), "requires": ["sigil_fire"], "ring": 2,
		"desc": "Burns last longer.",
		"max_level": 3, "cost": 542, "cost_growth": 1.3, "effects": {"burn_time": 1.5},
	},
	"searing": {
		"name": "Scorch", "icon": "burst", "pos": Vector2(8.2, -8.2), "requires": ["lingering_flames"], "ring": 3,
		"desc": "Burns hurt more.",
		"max_level": 3, "cost": 1991, "cost_growth": 1.3, "effects": {"burn": 0.2},
	},
	"kindling": {
		"name": "Firestarter", "icon": "match", "pos": Vector2(7.28, -5.44), "requires": ["sigil_fire"], "ring": 2,
		"desc": "Any punch can burst into flame.",
		"max_level": 3, "cost": 542, "cost_growth": 1.3, "effects": {"fire_chance": 0.06},
	},
	"tinderbox": {
		"name": "Tinderbox", "icon": "match", "pos": Vector2(9.12, -5.44), "requires": ["kindling"], "ring": 3,
		"desc": "More punches burst into flame.",
		"max_level": 2, "cost": 1991, "cost_growth": 1.3, "effects": {"fire_chance": 0.04},
	},
	"ember_rain": {
		"name": "Ember Rain", "icon": "ripple", "pos": Vector2(9.12, -7.28), "requires": ["tinderbox"], "ring": 4,
		"desc": "Fire bursts reach a little farther.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"fire_radius": 0.5},
	},
	"pyre": {
		"name": "Pyre", "icon": "pyre", "pos": Vector2(9.12, -9.12), "requires": ["wildfire", "searing", "ember_rain"], "ring": 6, "medallion": true,
		"desc": "Burning enemies explode when they die.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"pyre": 1},
	},
	"sigil_frost": {
		"name": "Deathchill", "icon": "snowflake", "pos": Vector2(-6.36, 6.36), "requires": [], "ring": 3, "medallion": true,
		"desc": "Awakens FROST: set-up heavies and counters freeze.",
		"max_level": 1, "cost": 3982, "cost_growth": 1.0, "effects": {"frost_punch": 0.4},
	},
	"deep_freeze": {
		"name": "Deep Freeze", "icon": "shard", "pos": Vector2(-5.44, 7.28), "requires": ["sigil_frost"], "ring": 3,
		"desc": "Frozen enemies are slower.",
		"max_level": 3, "cost": 1991, "cost_growth": 1.3, "effects": {"frost_punch": 0.1},
	},
	"brittle": {
		"name": "Brittle Bones", "icon": "broken_shield", "pos": Vector2(-5.44, 9.12), "requires": ["deep_freeze"], "ring": 4,
		"desc": "Frozen enemies take extra damage from everything.",
		"max_level": 3, "cost": 9376, "cost_growth": 1.3, "effects": {"brittle": 0.1},
	},
	"black_ice": {
		"name": "Black Ice", "icon": "shard", "pos": Vector2(-7.28, 9.12), "requires": ["brittle"], "ring": 5,
		"desc": "Frozen enemies take even more damage.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"brittle": 0.05},
	},
	"permafrost": {
		"name": "Permafrost", "icon": "hourglass", "pos": Vector2(-7.28, 7.28), "requires": ["sigil_frost"], "ring": 3,
		"desc": "Freezes last longer.",
		"max_level": 3, "cost": 1991, "cost_growth": 1.3, "effects": {"frost_time": 1.0},
	},
	"frost_nova": {
		"name": "Frost Nova", "icon": "nova", "pos": Vector2(-8.2, 8.2), "requires": ["permafrost"], "ring": 4,
		"desc": "Freezes reach farther.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"frost_radius": 1.0},
	},
	"cold_snap": {
		"name": "Cold Snap", "icon": "icicle", "pos": Vector2(-7.28, 5.44), "requires": ["sigil_frost"], "ring": 3,
		"desc": "Any punch can freeze.",
		"max_level": 3, "cost": 1991, "cost_growth": 1.3, "effects": {"frost_chance": 0.08},
	},
	"hoarfrost": {
		"name": "Hoarfrost", "icon": "snowflake", "pos": Vector2(-9.12, 5.44), "requires": ["cold_snap"], "ring": 4,
		"desc": "Freezes last a little longer.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"frost_time": 0.5},
	},
	"glacier": {
		"name": "Glacier", "icon": "icicle", "pos": Vector2(-9.12, 7.28), "requires": ["hoarfrost"], "ring": 5,
		"desc": "More punches freeze.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"frost_chance": 0.04},
	},
	"frost_shatter": {
		"name": "Shatter", "icon": "shatter", "pos": Vector2(-9.12, 9.12), "requires": ["black_ice", "frost_nova", "glacier"], "ring": 6, "medallion": true,
		"desc": "Frozen enemies burst into frost when they die.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"frost_shatter": 1},
	},
	"sigil_storm": {
		"name": "Thunderclap", "icon": "bolt", "pos": Vector2(6.36, 6.36), "requires": [], "ring": 4, "medallion": true,
		"desc": "Awakens STORM: combos arc lightning.",
		"max_level": 1, "cost": 18753, "cost_growth": 1.0, "effects": {"chain_lightning": 2},
	},
	"forked": {
		"name": "Forked Lightning", "icon": "fork", "pos": Vector2(7.28, 5.44), "requires": ["sigil_storm"], "ring": 4,
		"desc": "Lightning jumps to one more enemy.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"chain_lightning": 1},
	},
	"overcharge": {
		"name": "Overcharge", "icon": "battery", "pos": Vector2(9.12, 5.44), "requires": ["forked"], "ring": 5,
		"desc": "Lightning hits harder.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"chain_damage": 0.15},
	},
	"high_voltage": {
		"name": "High Voltage", "icon": "battery", "pos": Vector2(9.12, 7.28), "requires": ["overcharge"], "ring": 5,
		"desc": "Lightning hits harder still.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"chain_damage": 0.1},
	},
	"static_shock": {
		"name": "Static Shock", "icon": "spark", "pos": Vector2(7.28, 7.28), "requires": ["sigil_storm"], "ring": 4,
		"desc": "Lightning staggers.",
		"max_level": 1, "cost": 9376, "cost_growth": 1.3, "effects": {"chain_stun": 1},
	},
	"conductor": {
		"name": "Lightning Rod", "icon": "magnet", "pos": Vector2(8.2, 8.2), "requires": ["static_shock"], "ring": 5,
		"desc": "Every counter arcs lightning.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"chain_on_counter": 1},
	},
	"ball_lightning": {
		"name": "Ball Lightning", "icon": "spark", "pos": Vector2(5.44, 7.28), "requires": ["sigil_storm"], "ring": 4,
		"desc": "Lightning jumps to one more enemy.",
		"max_level": 1, "cost": 9376, "cost_growth": 1.3, "effects": {"chain_lightning": 1},
	},
	"storm": {
		"name": "Perfect Storm", "icon": "storm", "pos": Vector2(5.44, 9.12), "requires": ["ball_lightning"], "ring": 5,
		"desc": "Lightning comes every 4th combo hit.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"chain_every_cut": 1},
	},
	"tesla_coil": {
		"name": "Tesla Coil", "icon": "bolt", "pos": Vector2(7.28, 9.12), "requires": ["storm"], "ring": 5,
		"desc": "Lightning hits harder.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"chain_damage": 0.1},
	},
	"thunderhead": {
		"name": "Thunderhead", "icon": "thunderhead", "pos": Vector2(9.12, 9.12), "requires": ["high_voltage", "conductor", "tesla_coil"], "ring": 6, "medallion": true,
		"desc": "Clean dodges call lightning on the attacker.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"thunderhead": 1},
	},
	"sigil_blood": {
		"name": "Blood Moon", "icon": "drop", "pos": Vector2(-6.36, -6.36), "requires": [], "ring": 5, "medallion": true,
		"desc": "Awakens BLOOD: every kill heals you.",
		"max_level": 1, "cost": 135240, "cost_growth": 1.0, "effects": {"heal_on_kill": 1},
	},
	"vampiric_knuckles": {
		"name": "Bloodsucker", "icon": "fang", "pos": Vector2(-7.28, -5.44), "requires": ["sigil_blood"], "ring": 5,
		"desc": "Kills heal more.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"heal_on_kill": 0.5},
	},
	"blood_bank": {
		"name": "Blood Bank", "icon": "drop", "pos": Vector2(-9.12, -5.44), "requires": ["vampiric_knuckles"], "ring": 5,
		"desc": "Kills heal even more.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"heal_on_kill": 0.5},
	},
	"transfusion": {
		"name": "Transfusion", "icon": "heartbeat", "pos": Vector2(-9.12, -7.28), "requires": ["blood_bank"], "ring": 5,
		"desc": "Counters heal more.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"counter_heal": 0.3},
	},
	"bloodletting": {
		"name": "Bloodletting", "icon": "heartbeat", "pos": Vector2(-7.28, -7.28), "requires": ["sigil_blood"], "ring": 5,
		"desc": "Counters heal you.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"counter_heal": 0.5},
	},
	"open_vein": {
		"name": "Open Vein", "icon": "fang", "pos": Vector2(-8.2, -8.2), "requires": ["bloodletting"], "ring": 5,
		"desc": "Counters heal more.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"counter_heal": 0.3},
	},
	"blood_rage": {
		"name": "Seeing Red", "icon": "blood_burst", "pos": Vector2(-5.44, -7.28), "requires": ["sigil_blood"], "ring": 5,
		"desc": "The closer you are to dropping, the harder you hit.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"last_stand": 0.15},
	},
	"death_wish": {
		"name": "Death Wish", "icon": "skull", "pos": Vector2(-5.44, -9.12), "requires": ["blood_rage"], "ring": 5,
		"desc": "Even harder the closer you are to dropping.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"last_stand": 0.1},
	},
	"red_tide": {
		"name": "Red Tide", "icon": "blood_burst", "pos": Vector2(-7.28, -9.12), "requires": ["death_wish"], "ring": 5,
		"desc": "Kills heal more.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"heal_on_kill": 0.3},
	},
	"bloodbath": {
		"name": "Bloodbath", "icon": "bloodbath", "pos": Vector2(-9.12, -9.12), "requires": ["transfusion", "open_vein", "red_tide"], "ring": 6, "medallion": true,
		"desc": "Healing doubled under half knuckle HP.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"bloodbath": 1},
	},
	# The four Endless powers (2026-10-28; Sigils 9 cells out): each opens when that division's
	# endless bout is won (1 to 4), a diamond off one edge of the web: a
	# Sigil, three branches, and a capstone where they meet.
	"sigil_quake": {
		"name": "Earthbreaker", "icon": "quake", "pos": Vector2(-0, -9), "requires": [], "ring": 1, "medallion": true, "endless": 1,
		"desc": "Awakens QUAKE: land from a jump in a shockwave.",
		"max_level": 1, "cost": 600, "cost_growth": 1.0, "effects": {"quake_power": 0.8},
	},
	"quake_force": {
		"name": "Heavy Landing", "icon": "hammer", "pos": Vector2(-1.3, -9), "requires": ["sigil_quake"], "ring": 1,
		"desc": "Harder shockwaves.",
		"max_level": 3, "cost": 180, "cost_growth": 1.3, "effects": {"quake_damage": 0.2},
	},
	"bedrock": {
		"name": "Bedrock", "icon": "mountain", "pos": Vector2(-2.6, -10.3), "requires": ["quake_force"], "ring": 2,
		"desc": "Even harder shockwaves.",
		"max_level": 2, "cost": 542, "cost_growth": 1.3, "effects": {"quake_damage": 0.15},
	},
	"seismic": {
		"name": "Seismic", "icon": "quake", "pos": Vector2(-1.3, -11.6), "requires": ["bedrock"], "ring": 3,
		"desc": "Shockwaves knock monsters down.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"quake_knockdown": 1},
	},
	"wide_stance": {
		"name": "Wide Stance", "icon": "ripple", "pos": Vector2(-0, -10.3), "requires": ["sigil_quake"], "ring": 1,
		"desc": "Shockwaves reach farther.",
		"max_level": 2, "cost": 180, "cost_growth": 1.3, "effects": {"quake_radius": 0.75},
	},
	"fault_line": {
		"name": "Fault Line", "icon": "chevrons", "pos": Vector2(-0, -11.6), "requires": ["wide_stance"], "ring": 2,
		"desc": "Shockwaves also crack forward in a line.",
		"max_level": 1, "cost": 542, "cost_growth": 1.3, "effects": {"fault_line": 1},
	},
	"drumbeat": {
		"name": "Drumbeat", "icon": "note", "pos": Vector2(1.3, -9), "requires": ["sigil_quake"], "ring": 1,
		"desc": "Landed punches can stomp.",
		"max_level": 3, "cost": 180, "cost_growth": 1.3, "effects": {"quake_chance": 0.04},
	},
	"short_fuse": {
		"name": "Short Fuse", "icon": "stopwatch", "pos": Vector2(2.6, -10.3), "requires": ["drumbeat"], "ring": 2,
		"desc": "Shockwaves come back sooner.",
		"max_level": 2, "cost": 542, "cost_growth": 1.3, "effects": {"quake_cooldown": 0.75},
	},
	"tremor": {
		"name": "Tremor", "icon": "spiral", "pos": Vector2(1.3, -11.6), "requires": ["short_fuse"], "ring": 3,
		"desc": "Shockwaves stun.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"quake_stun": 1},
	},
	"aftershock": {
		"name": "Aftershock", "icon": "quake", "pos": Vector2(-0, -12.9), "requires": ["seismic", "fault_line", "tremor"], "ring": 6, "medallion": true,
		"desc": "The ground stays cracked and slows monsters.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"quake_aftershock": 1},
	},
	"sigil_gale": {
		"name": "Windcaller", "icon": "wind", "pos": Vector2(9, 0), "requires": [], "ring": 2, "medallion": true, "endless": 2,
		"desc": "Awakens GALE: dodges charge punches with air bursts.",
		"max_level": 1, "cost": 1356, "cost_growth": 1.0, "effects": {"gale": 0.5},
	},
	"gust": {
		"name": "Gust", "icon": "swoosh", "pos": Vector2(9, -1.3), "requires": ["sigil_gale"], "ring": 2,
		"desc": "Harder air bursts.",
		"max_level": 3, "cost": 542, "cost_growth": 1.3, "effects": {"gale_damage": 0.15},
	},
	"gale_force": {
		"name": "Gale Force", "icon": "wind", "pos": Vector2(10.3, -2.6), "requires": ["gust"], "ring": 3,
		"desc": "Even harder air bursts.",
		"max_level": 2, "cost": 1991, "cost_growth": 1.3, "effects": {"gale_damage": 0.1},
	},
	"buffet": {
		"name": "Buffet", "icon": "wave", "pos": Vector2(11.6, -1.3), "requires": ["gale_force"], "ring": 4,
		"desc": "Air bursts stagger.",
		"max_level": 1, "cost": 9376, "cost_growth": 1.3, "effects": {"gale_stagger": 1},
	},
	"deep_lungs": {
		"name": "Deep Lungs", "icon": "feather", "pos": Vector2(10.3, 0), "requires": ["sigil_gale"], "ring": 2,
		"desc": "Hold more charges.",
		"max_level": 2, "cost": 542, "cost_growth": 1.3, "effects": {"gale_charges": 1},
	},
	"tailwind": {
		"name": "Tailwind", "icon": "wing", "pos": Vector2(11.6, 0), "requires": ["deep_lungs"], "ring": 3,
		"desc": "Dodges give one more charge.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"gale_tailwind": 1},
	},
	"long_wind": {
		"name": "Long Wind", "icon": "chevrons", "pos": Vector2(9, 1.3), "requires": ["sigil_gale"], "ring": 2,
		"desc": "Air bursts fly farther.",
		"max_level": 1, "cost": 542, "cost_growth": 1.3, "effects": {"gale_range": 3.0},
	},
	"crosswind": {
		"name": "Crosswind", "icon": "fork", "pos": Vector2(10.3, 2.6), "requires": ["long_wind"], "ring": 3,
		"desc": "Hooks fire a fan of three.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"crosswind": 1},
	},
	"updraft": {
		"name": "Updraft", "icon": "wing", "pos": Vector2(11.6, 1.3), "requires": ["crosswind"], "ring": 4,
		"desc": "Uppercut bursts knock monsters off their feet.",
		"max_level": 1, "cost": 9376, "cost_growth": 1.3, "effects": {"updraft": 1},
	},
	"cyclone": {
		"name": "Cyclone", "icon": "spiral", "pos": Vector2(12.9, 0), "requires": ["buffet", "tailwind", "updraft"], "ring": 6, "medallion": true,
		"desc": "Your last charge blows everything nearby back.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"cyclone": 1},
	},
	"sigil_iron": {
		"name": "Forgeborn", "icon": "anvil", "pos": Vector2(0, 9), "requires": [], "ring": 3, "medallion": true, "endless": 3,
		"desc": "Awakens IRON: punches and clean dodges forge plates that cut damage.",
		"max_level": 1, "cost": 3982, "cost_growth": 1.0, "effects": {"plate_guard": 0.08},
	},
	"plating": {
		"name": "Plating", "icon": "chestplate", "pos": Vector2(1.3, 9), "requires": ["sigil_iron"], "ring": 3,
		"desc": "One more plate.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"iron_plates": 1},
	},
	"tempered": {
		"name": "Tempered", "icon": "shield", "pos": Vector2(2.6, 10.3), "requires": ["plating"], "ring": 4,
		"desc": "Each plate cuts more.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"plate_guard": 0.005},
	},
	"riveted": {
		"name": "Riveted", "icon": "anchor", "pos": Vector2(1.3, 11.6), "requires": ["tempered"], "ring": 5,
		"desc": "A boss's hit breaks only one plate.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"riveted": 1},
	},
	"forge": {
		"name": "Forge", "icon": "hammer", "pos": Vector2(0, 10.3), "requires": ["sigil_iron"], "ring": 3,
		"desc": "Plates forge sooner.",
		"max_level": 2, "cost": 1991, "cost_growth": 1.3, "effects": {"iron_forge": 1},
	},
	"anvil": {
		"name": "Anvil", "icon": "anvil", "pos": Vector2(0, 11.6), "requires": ["forge"], "ring": 4,
		"desc": "Any dodge forges a plate.",
		"max_level": 1, "cost": 9376, "cost_growth": 1.3, "effects": {"iron_anvil": 1},
	},
	"spikes": {
		"name": "Spikes", "icon": "broken_shield", "pos": Vector2(-1.3, 9), "requires": ["sigil_iron"], "ring": 3,
		"desc": "A breaking plate staggers the attacker.",
		"max_level": 1, "cost": 1991, "cost_growth": 1.3, "effects": {"iron_spikes": 1},
	},
	"barbs": {
		"name": "Barbs", "icon": "axe", "pos": Vector2(-2.6, 10.3), "requires": ["spikes"], "ring": 4,
		"desc": "Breaking plates hit back.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"iron_barbs": 0.5},
	},
	"shrapnel": {
		"name": "Shrapnel", "icon": "burst", "pos": Vector2(-1.3, 11.6), "requires": ["barbs"], "ring": 5,
		"desc": "Breaking plates hit everything around you.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"shrapnel": 1},
	},
	"unbreakable": {
		"name": "Unbreakable", "icon": "helmet", "pos": Vector2(0, 12.9), "requires": ["riveted", "anvil", "shrapnel"], "ring": 6, "medallion": true,
		"desc": "Full plates: a knockout blow leaves you on 1 knuckle HP.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"unbreakable": 1},
	},
	"sigil_doom": {
		"name": "Death Mark", "icon": "skull", "pos": Vector2(-9, 0), "requires": [], "ring": 4, "medallion": true, "endless": 4,
		"desc": "Awakens DOOM: heavies and counters mark a monster to take a share of it again.",
		"max_level": 1, "cost": 18753, "cost_growth": 1.0, "effects": {"doom": 0.3},
	},
	"dread": {
		"name": "Dread", "icon": "cracked_skull", "pos": Vector2(-9, 1.3), "requires": ["sigil_doom"], "ring": 4,
		"desc": "Marks store more.",
		"max_level": 3, "cost": 9376, "cost_growth": 1.3, "effects": {"doom": 0.1},
	},
	"death_knell": {
		"name": "Death Knell", "icon": "skull", "pos": Vector2(-10.3, 2.6), "requires": ["dread"], "ring": 5,
		"desc": "Marks store even more.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"doom": 0.05},
	},
	"reckoning": {
		"name": "Reckoning", "icon": "burst", "pos": Vector2(-11.6, 1.3), "requires": ["death_knell"], "ring": 5,
		"desc": "The burst staggers, bosses too.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"reckoning": 1},
	},
	"long_shadow": {
		"name": "Long Shadow", "icon": "hourglass", "pos": Vector2(-10.3, 0), "requires": ["sigil_doom"], "ring": 4,
		"desc": "Marks last longer.",
		"max_level": 2, "cost": 9376, "cost_growth": 1.3, "effects": {"doom_time": 1.0},
	},
	"dead_weight": {
		"name": "Dead Weight", "icon": "anchor", "pos": Vector2(-11.6, 0), "requires": ["long_shadow"], "ring": 5,
		"desc": "Marked monsters hit softer.",
		"max_level": 3, "cost": 36000, "cost_growth": 1.3, "effects": {"dead_weight": 1},
	},
	"hex": {
		"name": "Hex", "icon": "eye", "pos": Vector2(-9, -1.3), "requires": ["sigil_doom"], "ring": 4,
		"desc": "Any punch can mark.",
		"max_level": 3, "cost": 9376, "cost_growth": 1.3, "effects": {"doom_chance": 0.06},
	},
	"evil_eye": {
		"name": "Evil Eye", "icon": "eye", "pos": Vector2(-10.3, -2.6), "requires": ["hex"], "ring": 5,
		"desc": "More punches mark.",
		"max_level": 2, "cost": 36000, "cost_growth": 1.3, "effects": {"doom_chance": 0.04},
	},
	"pall": {
		"name": "Pall", "icon": "ghost", "pos": Vector2(-11.6, -1.3), "requires": ["evil_eye"], "ring": 5,
		"desc": "A mark also lands on the nearest other monster.",
		"max_level": 1, "cost": 36000, "cost_growth": 1.3, "effects": {"pall": 1},
	},
	"reaper": {
		"name": "Reaper", "icon": "skull", "pos": Vector2(-12.9, 0), "requires": ["reckoning", "dead_weight", "pall"], "ring": 6, "medallion": true,
		"desc": "A Doom burst that knocks out jumps the mark on.",
		"max_level": 1, "cost": 503100, "cost_growth": 1.0, "effects": {"reaper": 1},
	},
}

# How each effect reads in the UI. Percent effects are stored as fractions.
const EFFECT_FORMATS := {
	"insult_time": "Enraged monsters stay mad %ss longer",
	"damage": "+%s damage",
	"defense": "+%s defense",
	"max_knuckles": "+%s max knuckle HP",
	"move_speed": "+%s%% move speed",
	"armor_pierce": "Ignore %s%% of enemy armor",
	"crit_chance": "%s%% chance of a critical hit (x1.5 damage)",
	"crit_damage": "+%s%% critical hit damage",
	"combo_step": "+%s combo multiplier per hit",
	"coin_bonus": "+%s%% coins from kills",
	"heavy_bonus": "+%s%% set-up hook & uppercut damage",
	"wave_bonus": "+%s%% Arena milestone bonus",
	"heal_on_kill": "Kills restore %s%% of your knuckle HP",
	"heavy_cost_cut": "Hooks and uppercuts cost %s less knuckle HP",
	"boss_damage": "+%s%% damage to bosses",
	"dawn_bonus": "+%s%% Arena purse",
	"punch_speed": "+%s%% punch speed",
	"head_bonus": "+%s head shot multiplier",
	"combo_window": "+%ss combo time",
	"free_punch_chance": "%s%% chance a punch costs no knuckle HP",
	"wave_heal": "Restore %s%% knuckle HP every tenth of the bout (and every Crypt room)",
	"finisher_bonus": "+%s%% damage to enemies under 30%% HP",
	"dodge_window": "+%s%% dodge window",
	"flinch_reduction": "-%s%% flinch time",
	"graze_reduction": "-%s%% graze damage",
	"counter_bonus": "+%s counter multiplier",
	"counter_window": "+%ss counter window",
	"passive_power": "+%s passive power",
	"spell_time": "+%ss Elemental Fists",
	"sprint_bonus": "+%s%% sprint speed",
	"fire_punch": "Fire deals %s%% of the hit to enemies nearby",
	"chain_lightning": "Lightning arcs to %s enemies",
	"ground_pound": "Landing shockwave (every 4s) deals %sx your base damage",
	"xp_bonus": "+%s%% XP",
	"fire_radius": "+%sm fire radius",
	"burn": "Burned enemies take %sx your base damage per second",
	"burn_time": "Burns last +%ss",
	"fire_chance": "%s%% chance any punch bursts into flame",
	"chain_on_counter": "Counters arc lightning",
	"frost_punch": "Frozen enemies are %s%% slower",
	"frost_time": "Freeze lasts +%ss",
	"frost_radius": "+%sm freeze radius",
	"frost_chance": "%s%% chance any punch freezes",
	"brittle": "Frozen enemies take +%s%% damage",
	"counter_heal": "Counters restore %s%% knuckle HP",
	"chain_damage": "+%s%% lightning damage",
	"chain_every_cut": "Lightning every %s fewer combo hits",
	"chain_stun": "Lightning staggers",
	"seal": "Breaks the seal: opens the upgrades beyond",
	"damage_percent": "+%s%% damage",
	"knuckles_percent": "+%s%% max knuckle HP",
	"perfect_any_punch": "Perfect counters work with any punch",
	"jump_bonus": "+%s%% jump height",
	"dive_kick": "Jump punches stagger",
	# Crypt item specials.
	"shatter": "Counters burst for %s%% damage around the target",
	"venom": "Jabs poison: %sx base damage per second per stack (max 5)",
	"serrated": "Hooks cause bleeding: each attack a bleeding enemy throws costs it %sx your base damage per stack",
	"lunging_jab": "Dash into a jab: +%s%% damage",
	"thorns": "Attackers take %s%% of the damage they deal you",
	"iron_will": "The first hit in each room is blocked",
	"grit": "Below 30%% knuckle HP, take %s%% less damage",
	"frost_slip": "%s%% chance a slip or roll chills nearby enemies",
	"spear_jab": "Dash into a jab: it spears every enemy in a line",
	"clean_read": "Clean dodges restore %s%% knuckle HP",
	"rhythm": "Each dodge adds +%s to your combo multiplier (lost when hit)",
	"executioner": "Counters finish off non-boss enemies under %s%% HP",
	"glass_jaw": "+%s%% damage",
	"damage_taken": "+%s%% damage taken",
	"last_stand": "Up to +%s%% damage as your knuckle HP falls",
	"blood_price": "+%s%% damage",
	"blood_cost": "Every punch costs %s more knuckle HP",
	"bone_breaker": "Every 5th hook ignores all armor and damage reduction, and staggers",
	"long_count": "Once per floor, survive a knockout at 1 HP and stun everything for 3s",
	"champions_hands": "Counters throw a free follow-up punch",
	"slipknot": "3 dodges in a row without being hit restore %s%% knuckle HP",
	"gravewalker": "After a dodge, the next attack within 1.5s hits your ghost instead",
	"lantern": "Elites and bosses drop an extra chest",
	"pyre": "Burning enemies explode when they die",
	"thunderhead": "Clean dodges strike the attacker with lightning",
	"frost_shatter": "Frozen enemies burst into frost when they die",
	"bloodbath": "Healing doubled under half knuckle HP",
	"ult_gain": "+%s%% ultimate meter gain",
	"ult_power": "Empowered ultimate",
	"boost_fire": "Fire +%s%% stronger",
	"boost_storm": "Storm +%s%% stronger",
	"boost_frost": "Frost +%s%% stronger",
	"boost_blood": "Blood heals +%s%% more",
	"boost_quake": "Quake +%s%% stronger",
	"boost_gale": "Gale +%s%% stronger",
	"boost_iron": "Iron plates +%s%% stronger",
	"boost_doom": "Doom +%s%% stronger",
	"all_power_boost": "Every power +%s%% stronger",
	"window_cap_up": "Dodge, counter and combo caps +%s%%",
	"window_boost": "Dodge, counter and combo windows +%s%%",
	"quake_power": "Jump landings send a shockwave: %sx your base damage",
	"quake_damage": "+%sx shockwave damage",
	"quake_radius": "+%sm shockwave reach",
	"quake_knockdown": "Shockwaves knock monsters down",
	"fault_line": "Shockwaves also crack forward in a line",
	"quake_chance": "%s%% chance a landed punch stomps",
	"quake_cooldown": "Shockwaves come back %ss sooner",
	"quake_stun": "Shockwaves stun for 1s",
	"quake_aftershock": "The ground stays cracked 3s and slows monsters",
	"gale": "Air bursts deal %s%% of the punch",
	"gale_damage": "+%s%% air burst damage",
	"gale_stagger": "Air bursts stagger",
	"gale_charges": "+%s max charges",
	"gale_tailwind": "Dodges give one more charge",
	"gale_range": "Air bursts fly %sm farther",
	"crosswind": "Hooks fire a fan of three",
	"updraft": "Uppercut bursts knock monsters off their feet",
	"cyclone": "Your last charge blows everything nearby back",
	"plate_guard": "Each plate cuts damage taken by %s%%",
	"iron_plates": "+%s max plates",
	"riveted": "A boss's hit breaks only one plate",
	"iron_forge": "Plates forge %s punches sooner",
	"iron_anvil": "Any dodge forges a plate",
	"iron_spikes": "A breaking plate staggers the attacker",
	"iron_barbs": "Breaking plates hit back for %sx your base damage",
	"shrapnel": "Breaking plates hit everything around you",
	"unbreakable": "Full plates: a knockout blow leaves you on 1 knuckle HP (once a minute)",
	"doom": "Marked monsters take %s%% of what you dealt them again",
	"doom_time": "Marks last %ss longer",
	"reckoning": "The Doom burst staggers, bosses too",
	"dead_weight": "Marked monsters deal 25 / 30 / 35% less damage",
	"doom_chance": "%s%% chance any punch marks",
	"pall": "Marks also land on the nearest other monster",
	"reaper": "A Doom burst that knocks out jumps the mark on",
}
const PERCENT_EFFECTS := [
	"armor_pierce", "crit_chance", "crit_damage", "move_speed", "coin_bonus", "heavy_bonus", "wave_bonus", "boss_damage", "dawn_bonus", "punch_speed",
	"free_punch_chance", "finisher_bonus", "dodge_window", "flinch_reduction", "graze_reduction",
	"sprint_bonus",
	"fire_punch", "xp_bonus", "chain_damage", "fire_chance", "frost_punch", "frost_chance", "brittle",
	"damage_percent", "knuckles_percent", "jump_bonus",
	"shatter", "lunging_jab", "thorns", "grit", "frost_slip", "executioner", "glass_jaw", "damage_taken",
	"last_stand", "blood_price", "ult_gain",
	"quake_chance", "gale", "gale_damage", "plate_guard", "doom", "doom_chance",
	"boost_fire", "boost_storm", "boost_frost", "boost_blood", "boost_quake", "boost_gale", "boost_iron", "boost_doom",
	"all_power_boost", "window_cap_up", "window_boost",
]
## Effects that are on/off: their text has no number.
const FLAG_EFFECTS := [
	"chain_stun", "seal", "chain_on_counter", "perfect_any_punch", "dive_kick",
	"iron_will", "spear_jab", "bone_breaker", "long_count", "champions_hands", "gravewalker", "lantern",
	"pyre", "thunderhead", "frost_shatter", "bloodbath", "ult_power",
	"quake_knockdown", "fault_line", "quake_stun", "quake_aftershock", "gale_stagger", "gale_tailwind", "crosswind",
	"updraft", "cyclone", "riveted", "iron_anvil", "iron_spikes", "shrapnel", "unbreakable", "reckoning",
	"dead_weight", "pall", "reaper",
]

## The upgrade web's layout version. Saves from an older one get everything
## they spent on upgrades back (coins and sigils) to rebuy in the new web.
const UPGRADE_VERSION := 8
## Version 5 prices ([cost, growth] per node), for the version-6 respec
## (the spoke web, 2026-10-16).
## Prices before the 2026-10-17 taming (v6), for the refund of the difference.
const V7_PRICES := {"wrapped_knuckles": [63, 1.0], "dmg_1": [84, 1.22], "dmg_2": [407, 1.22], "dmg_3": [1564, 1.22], "dmg_4": [7896, 1.22], "dmg_5": [58800, 1.22], "dmg_6": [290680, 1.22], "hp_1": [84, 1.22], "hp_2": [407, 1.22], "hp_3": [1564, 1.22], "hp_4": [7896, 1.22], "hp_5": [58800, 1.22], "hp_6": [290680, 1.22], "def_1": [126, 1.22], "def_2": [610, 1.22], "def_3": [2346, 1.22], "def_4": [11844, 1.22], "def_5": [88200, 1.22], "def_6": [436020, 1.22], "gold_1": [109, 1.22], "gold_2": [529, 1.22], "gold_3": [2033, 1.22], "gold_4": [10265, 1.22], "gold_5": [76440, 1.22], "gold_6": [377884, 1.22], "heavy_hitter": [542, 1.3], "heavy_bag": [1991, 1.3], "counterpuncher": [1991, 1.3], "return_fire": [9376, 1.3], "armor_breaker": [9376, 1.3], "giant_killer": [67620, 1.3], "weighted_wraps": [67620, 1.0], "lucky_shot": [1991, 1.3], "dirty_shot": [9376, 1.3], "glass_breaker": [9376, 1.3], "ice_bath": [542, 1.3], "iron_will": [542, 1.3], "calloused": [1991, 1.3], "thick_skull": [1991, 1.3], "second_wind": [9376, 1.3], "cornerman": [126, 1.3], "footwork_drills": [126, 1.3], "bob_and_weave": [542, 1.3], "rope_a_dope": [9376, 1.3], "bellmans_bell": [868, 1.3], "headless_helm": [3185, 1.3], "southpaws_rosary": [15002, 1.3], "plague_censer": [108192, 1.3], "coffin_crown": [804960, 1.3], "sparring_partner": [126, 1.3], "light_feet": [126, 1.3], "running_shoes": [542, 1.3], "quick_wraps": [542, 1.3], "bounty": [1991, 1.3], "rhythm": [1991, 1.3], "night_owl": [9376, 1.3], "dawn_patrol": [67620, 1.3], "sigil_fire": [1356, 1.0], "hotter_flames": [542, 1.3], "fire_heart": [1991, 1.3], "wildfire": [9376, 1.3], "lingering_flames": [542, 1.3], "searing": [1991, 1.3], "kindling": [542, 1.3], "tinderbox": [1991, 1.3], "ember_rain": [9376, 1.3], "pyre": [503100, 1.0], "sigil_frost": [3982, 1.0], "deep_freeze": [1991, 1.3], "brittle": [9376, 1.3], "black_ice": [36000, 1.3], "permafrost": [1991, 1.3], "frost_nova": [9376, 1.3], "cold_snap": [1991, 1.3], "hoarfrost": [9376, 1.3], "glacier": [36000, 1.3], "frost_shatter": [503100, 1.0], "sigil_storm": [18753, 1.0], "forked": [9376, 1.3], "overcharge": [36000, 1.3], "high_voltage": [36000, 1.3], "static_shock": [9376, 1.3], "conductor": [36000, 1.3], "ball_lightning": [9376, 1.3], "storm": [36000, 1.3], "tesla_coil": [36000, 1.3], "thunderhead": [503100, 1.0], "sigil_blood": [135240, 1.0], "vampiric_knuckles": [36000, 1.3], "blood_bank": [36000, 1.3], "transfusion": [36000, 1.3], "bloodletting": [36000, 1.3], "open_vein": [36000, 1.3], "blood_rage": [36000, 1.3], "death_wish": [36000, 1.3], "red_tide": [36000, 1.3], "bloodbath": [503100, 1.0], "sigil_quake": [600, 1.0], "quake_force": [180, 1.3], "bedrock": [542, 1.3], "seismic": [1991, 1.3], "wide_stance": [180, 1.3], "fault_line": [542, 1.3], "drumbeat": [180, 1.3], "short_fuse": [542, 1.3], "tremor": [1991, 1.3], "aftershock": [503100, 1.0], "sigil_gale": [1356, 1.0], "gust": [542, 1.3], "gale_force": [1991, 1.3], "buffet": [9376, 1.3], "deep_lungs": [542, 1.3], "tailwind": [1991, 1.3], "long_wind": [542, 1.3], "crosswind": [1991, 1.3], "updraft": [9376, 1.3], "cyclone": [503100, 1.0], "sigil_iron": [3982, 1.0], "plating": [1991, 1.3], "tempered": [9376, 1.3], "riveted": [36000, 1.3], "forge": [1991, 1.3], "anvil": [9376, 1.3], "spikes": [1991, 1.3], "barbs": [9376, 1.3], "shrapnel": [36000, 1.3], "unbreakable": [503100, 1.0], "sigil_doom": [18753, 1.0], "dread": [9376, 1.3], "death_knell": [36000, 1.3], "reckoning": [36000, 1.3], "long_shadow": [9376, 1.3], "dead_weight": [36000, 1.3], "hex": [9376, 1.3], "evil_eye": [36000, 1.3], "pall": [36000, 1.3], "reaper": [503100, 1.0]}
## Merged nodes (2026-10-28): a save's levels in the first fold into the second.
const MERGED_UPGRADES := {"dirty_shot": "lucky_shot", "heavy_bag": "heavy_hitter", "return_fire": "counterpuncher"}
const V6_PRICES := {"wrapped_knuckles": [57, 1.0], "dmg_1": [76, 1.45], "dmg_2": [450, 1.45], "dmg_3": [1957, 1.45], "dmg_4": [11280, 1.45], "dmg_5": [88200, 1.45], "dmg_6": [435760, 1.45], "hp_1": [76, 1.45], "hp_2": [450, 1.45], "hp_3": [1957, 1.45], "hp_4": [11280, 1.45], "hp_5": [88200, 1.45], "hp_6": [435760, 1.45], "def_1": [113, 1.45], "def_2": [675, 1.45], "def_3": [2935, 1.45], "def_4": [16920, 1.45], "def_5": [132300, 1.45], "def_6": [653640, 1.45], "gold_1": [98, 1.45], "gold_2": [585, 1.45], "gold_3": [2544, 1.45], "gold_4": [14664, 1.45], "gold_5": [114660, 1.45], "gold_6": [566488, 1.45], "heavy_hitter": [600, 1.6], "heavy_bag": [2491, 1.6], "counterpuncher": [2491, 1.6], "return_fire": [13395, 1.6], "armor_breaker": [13395, 1.6], "giant_killer": [101430, 1.6], "weighted_wraps": [101430, 1.0], "lucky_shot": [2491, 1.6], "dirty_shot": [13395, 1.6], "glass_breaker": [13395, 1.6], "sigil_fire": [1500, 1.0], "hotter_flames": [600, 1.6], "lingering_flames": [2491, 1.6], "searing": [2491, 1.6], "kindling": [13395, 1.6], "wildfire": [13395, 1.6], "pyre": [754200, 1.0], "sigil_storm": [26790, 1.0], "forked": [13395, 1.6], "overcharge": [13395, 1.6], "static_shock": [13395, 1.0], "conductor": [101430, 1.0], "storm": [101430, 1.0], "thunderhead": [754200, 1.0], "ice_bath": [600, 1.6], "iron_will": [600, 1.6], "calloused": [2491, 1.6], "thick_skull": [2491, 1.6], "second_wind": [13395, 1.6], "sigil_blood": [202860, 1.0], "vampiric_knuckles": [101430, 1.6], "bloodletting": [101430, 1.6], "blood_rage": [101430, 1.6], "bloodbath": [754200, 1.0], "cornerman": [113, 1.6], "footwork_drills": [113, 1.6], "bob_and_weave": [600, 1.6], "rope_a_dope": [13395, 1.6], "sigil_frost": [4981, 1.0], "deep_freeze": [2491, 1.6], "permafrost": [2491, 1.6], "frost_nova": [2491, 1.6], "brittle": [13395, 1.6], "cold_snap": [13395, 1.6], "frost_shatter": [754200, 1.0], "bellmans_bell": [960, 1.6], "headless_helm": [3985, 1.6], "southpaws_rosary": [21432, 1.6], "plague_censer": [162288, 1.6], "coffin_crown": [1206720, 1.6], "sparring_partner": [113, 1.6], "light_feet": [113, 1.6], "running_shoes": [600, 1.6], "quick_wraps": [600, 1.6], "bounty": [2491, 1.6], "rhythm": [2491, 1.6], "night_owl": [13395, 1.6], "dawn_patrol": [101430, 1.6]}
const V5_PRICES := {"wrapped_knuckles": [15, 1.0], "calluses": [20, 1.7], "iron_fists": [20, 1.8], "pickpocket": [55, 1.8], "running_shoes": [140, 2.0], "thick_skin": [125, 2.0], "quick_wraps": [160, 1.9], "heavy_hitter": [140, 1.9], "armor_breaker": [140, 2.0], "guard": [210, 1.9], "giant_killer": [790, 2.0], "sigil_blood": [2310, 1.0], "vampiric_knuckles": [1540, 1.9], "bloodletting": [1540, 1.9], "blood_rage": [1850, 2.0], "sigil_fire": [275, 1.0], "hotter_flames": [250, 1.9], "wildfire": [220, 2.0], "lingering_flames": [220, 1.9], "searing": [275, 1.9], "kindling": [330, 2.0], "brass_tape": [30, 1.8], "light_feet": [30, 2.2], "rhythm": [65, 1.9], "ice_bath": [245, 2.0], "night_owl": [395, 1.9], "iron_will": [140, 2.0], "bounty": [245, 2.2], "weighted_wraps": [990, 1.0], "dawn_patrol": [1540, 2.2], "sigil_storm": [660, 1.0], "forked": [595, 1.9], "storm": [1650, 1.0], "overcharge": [660, 1.9], "conductor": [1320, 1.0], "static_shock": [1320, 1.0], "mouthguard": [40, 1.8], "grave_robber": [50, 1.8], "cornerman": [90, 1.8], "skull_cracker": [200, 2.0], "sigil_frost": [350, 1.0], "deep_freeze": [315, 1.9], "permafrost": [280, 1.9], "frost_nova": [280, 2.0], "brittle": [420, 2.0], "cold_snap": [385, 2.0], "road_work": [40, 1.8], "footwork_drills": [130, 2.0], "heavy_bag": [130, 2.0], "sparring_partner": [110, 1.9], "champions_belt": [530, 2.0], "bone_plating": [925, 1.9], "grave_gold": [790, 2.0], "pyre": [9000, 1.0], "thunderhead": [9000, 1.0], "frost_shatter": [9000, 1.0], "bloodbath": [9000, 1.0], "bellmans_bell": [375, 1.6], "headless_helm": [480, 1.6], "southpaws_rosary": [900, 1.6], "plague_censer": [2100, 1.6], "coffin_crown": [4500, 1.6]}
## Version 4 prices ([cost, growth] per node), for the version-5 respec.
const V4_PRICES := {"wrapped_knuckles": [15, 1.0], "calluses": [20, 1.7], "iron_fists": [20, 1.8], "pickpocket": [55, 1.8], "running_shoes": [140, 2.0], "thick_skin": [125, 2.0], "quick_wraps": [160, 1.9], "heavy_hitter": [140, 1.9], "armor_breaker": [140, 2.0], "guard": [210, 1.9], "giant_killer": [790, 2.0], "sigil_blood": [2310, 1.0], "vampiric_knuckles": [1540, 1.9], "bloodletting": [1540, 1.9], "blood_rage": [1850, 2.0], "sigil_fire": [275, 1.0], "hotter_flames": [250, 1.9], "wildfire": [220, 2.0], "lingering_flames": [220, 1.9], "searing": [275, 1.9], "kindling": [330, 2.0], "brass_tape": [30, 1.8], "light_feet": [30, 2.2], "rhythm": [65, 1.9], "ice_bath": [245, 2.0], "night_owl": [395, 1.9], "iron_will": [140, 2.0], "bounty": [245, 2.2], "weighted_wraps": [990, 1.0], "dawn_patrol": [1540, 2.2], "sigil_storm": [660, 1.0], "forked": [595, 1.9], "storm": [1650, 1.0], "overcharge": [660, 1.9], "conductor": [1320, 1.0], "static_shock": [1320, 1.0], "mouthguard": [40, 1.8], "grave_robber": [50, 1.8], "cornerman": [90, 1.8], "skull_cracker": [200, 2.0], "sigil_frost": [350, 1.0], "deep_freeze": [315, 1.9], "permafrost": [280, 1.9], "frost_nova": [280, 2.0], "brittle": [420, 2.0], "cold_snap": [385, 2.0], "road_work": [40, 1.8], "footwork_drills": [130, 2.0], "heavy_bag": [130, 2.0], "sparring_partner": [110, 1.9], "champions_belt": [530, 2.0], "bone_plating": [925, 1.9], "grave_gold": [790, 2.0], "pyre": [9000, 1.0], "thunderhead": [9000, 1.0], "frost_shatter": [9000, 1.0], "bloodbath": [9000, 1.0], "bellmans_bell": [375, 1.6], "headless_helm": [480, 1.6], "southpaws_rosary": [900, 1.6], "plague_censer": [2100, 1.6], "coffin_crown": [4500, 1.6]}
## Version 4 seal rings per node (for refunding version-3 saves at their
## pre-ring prices).
const V4_RINGS := {"wrapped_knuckles": 1, "calluses": 1, "iron_fists": 1, "pickpocket": 2, "running_shoes": 3, "thick_skin": 2, "quick_wraps": 3, "heavy_hitter": 2, "armor_breaker": 3, "guard": 3, "giant_killer": 4, "sigil_blood": 5, "vampiric_knuckles": 5, "bloodletting": 5, "blood_rage": 5, "sigil_fire": 2, "hotter_flames": 2, "wildfire": 2, "lingering_flames": 2, "searing": 2, "kindling": 2, "brass_tape": 1, "light_feet": 1, "rhythm": 2, "ice_bath": 3, "night_owl": 4, "iron_will": 2, "bounty": 3, "weighted_wraps": 4, "dawn_patrol": 5, "sigil_storm": 4, "forked": 4, "storm": 4, "overcharge": 4, "conductor": 4, "static_shock": 4, "mouthguard": 1, "grave_robber": 1, "cornerman": 1, "skull_cracker": 1, "sigil_frost": 3, "deep_freeze": 3, "permafrost": 3, "frost_nova": 3, "brittle": 3, "cold_snap": 3, "road_work": 1, "footwork_drills": 1, "heavy_bag": 1, "sparring_partner": 1, "champions_belt": 3, "bone_plating": 4, "grave_gold": 4, "pyre": 6, "thunderhead": 6, "frost_shatter": 6, "bloodbath": 6, "bellmans_bell": 2, "headless_helm": 3, "southpaws_rosary": 4, "plague_censer": 5, "coffin_crown": 6}
## Version 4 max levels per node (old refunds are clamped to them).
const V4_LEVELS := {"wrapped_knuckles": 1, "calluses": 5, "iron_fists": 5, "pickpocket": 3, "running_shoes": 2, "thick_skin": 3, "quick_wraps": 3, "heavy_hitter": 3, "armor_breaker": 3, "guard": 3, "giant_killer": 3, "sigil_blood": 1, "vampiric_knuckles": 3, "bloodletting": 3, "blood_rage": 3, "sigil_fire": 1, "hotter_flames": 3, "wildfire": 2, "lingering_flames": 3, "searing": 3, "kindling": 3, "brass_tape": 3, "light_feet": 2, "rhythm": 3, "ice_bath": 2, "night_owl": 3, "iron_will": 2, "bounty": 2, "weighted_wraps": 1, "dawn_patrol": 2, "sigil_storm": 1, "forked": 2, "storm": 1, "overcharge": 3, "conductor": 1, "static_shock": 1, "mouthguard": 3, "grave_robber": 3, "cornerman": 3, "skull_cracker": 2, "sigil_frost": 1, "deep_freeze": 3, "permafrost": 3, "frost_nova": 2, "brittle": 3, "cold_snap": 3, "road_work": 3, "footwork_drills": 2, "heavy_bag": 2, "sparring_partner": 3, "champions_belt": 3, "bone_plating": 3, "grave_gold": 2, "pyre": 1, "thunderhead": 1, "frost_shatter": 1, "bloodbath": 1, "bellmans_bell": 3, "headless_helm": 3, "southpaws_rosary": 3, "plague_censer": 3, "coffin_crown": 5}
## The fighter level-up version. Version 2 (2026-10-15) rebuilt every skill
## web; version 3 (2026-10-25) replaced the webs and stats with card draws and
## attributes: older saves get a draw a level and every stat point back.
const SKILL_VERSION := 3
## Version 3 raised the existing web from roughly 17,000 to 40,950 coins
## before adding the four new 600-coin capstones. Version-2 saves are respecced
## at their approximate old purchase value so the higher prices actually create
## progression instead of leaving an already-maxed save maxed forever.
const V2_REFUND_SCALE := 0.415
## Nodes that left the web in version 2: [cost, cost_growth, sigil_cost].
const RETIRED_UPGRADES := {
	"seal_east": [50, 1.0, 1], "seal_far_east": [150, 1.0, 1], "seal_southwest": [100, 1.0, 1],
	"seal_west": [50, 1.0, 1], "seal_north": [75, 1.0, 1], "seal_south": [75, 1.0, 1],
	"fire_fists": [150, 1.0, 0], "scorch": [120, 1.7, 0], "chain_lightning": [150, 1.0, 0],
	"ground_pound": [150, 1.0, 0], "tremor": [90, 1.7, 0], "launch": [200, 1.0, 0],
	"wide_quake": [80, 1.8, 0], "vampiric_knuckles": [120, 1.8, 0],
}

## Upgrades from the old single-level tree, mapped to the new nodes and levels.
const LEGACY_UPGRADES := {
	"iron_fists_1": ["iron_fists", 1], "iron_fists_2": ["iron_fists", 2],
	"armor_breaker_1": ["armor_breaker", 1], "armor_breaker_2": ["armor_breaker", 2],
	"light_feet_1": ["light_feet", 1], "light_feet_2": ["light_feet", 2],
}

var player_class := DEFAULT_CLASS
## Highest night beaten (its boss defeated). The next run is the night after.
var nights_cleared := 0
## Souls: dropped by Grave Champions and Crypt floor bosses, spent on gear
## (gilding finds to keep them, reforging kept items).
var souls := 0
## Kept gear (gilded Crypt finds), each with a unique "uid". equipped holds
## the worn ones (by slot) and is used in every mode.
var armory: Array = []
var _next_uid := 1
## Underworld Arena: the division picked at camp, and bouts cleared per division.
var arena_division := 1
## The bout picked in camp for the next Arena run (0 = your next unbeaten one).
## Not saved.
var arena_bout_pick := 0
var arena_bouts := {}
## The Crypt bracket picked at camp (runs start on its first floor).
var crypt_tier := 1
## Collected hats: id -> how many popped (duplicates turned into Souls).
var hats := {}
## The hat your fighter wears (seen when you emote), "" for none. Cosmetic:
## every hat's boost counts once it's on the rack.
var worn_hat := ""
## Mini tutorials already shown (Tutorial): {id: true}.
var tips_seen := {}
## The Soul Shop (SoulShop): its offers, when they were stocked (fights_done
## then) and rerolls since; what's been bought.
var shop_stock: Array = []
var shop_restock_at := -1
var shop_rerolls := 0
var emotes_bought := {}
var fighters_bought := {}
## Fights finished (each return to camp from the Arena, Crypt or Dead League).
var fights_done := 0
## Bounties (Bounties): the three active ones, bounty XP (mastery), and
## knockouts by kind (bounties only ask for kinds you've met).
var bounties: Array = []
## Hand idles (IdleAnims): each fighter's pick, and the ones bought.
var idle_picks := {}
var idles_bought := {}
## Skins (Skins): the ones owned, and each fighter's pick ("" for their own look).
var skins_owned := {}
var skin_picks := {}
var bounty_xp := 0
var kills := {}
## Ability picks per fighter (Abilities): {class: {"passive": id, "ultimate": id}}.
var loadouts := {}
## Each division's best endless-bout score: {"division": score}.
var endless_bests := {}
## Achievements earned (Achievements): {id: true}.
var achievements := {}
## The one power that works (2026-10-23): a sigil node's id ("" for none).
## Owning several powers, you pick one; only its line of upgrades counts.
var power_pick := ""
## The Catalyst's second pick (Dual Sigil): the one before the latest.
var power_pick_2 := ""
## Living Conduit's extra pick.
var power_pick_3 := ""
## Prism's fourth pick.
var power_pick_4 := ""
## Daily drills: {drill: {"best": score, "day": "YYYY-MM-DD" of the last paid run}}.
var drills := {}
## The drill picked in camp for the drills scene (not saved).
var drill_pick := "pads"
## What a score is worth: a run scoring this pays about one good Arena bout
## of your division. Pad Work and Slip Line have no cap (the longer you last,
## the more you earn); Heavy Bags is a timed DPS check, capped at 1.5 bouts.
const DRILL_GOOD_SCORE := {"pads": 1700.0, "slip": 1200.0, "bags": 4000.0}
const DRILL_CAP := {"bags": 1.5}
## Hats spawned since the last legendary (bad-luck protection, see Hats).
var hat_pity := 0
## All four Yonkers collected: Tony is playable.
var tony_unlocked := false
## The loadout worn when a Crypt run started (restored on a knockout).
var _run_entry := {}
var resources := {}
## Owned upgrade levels {id: level}. Shared by every class.
var upgrade_levels := {}
## Deepest Crypt floor beaten. The first win on each floor pays extra Souls.
var crypt_floors_cleared := 0
## Items worn this Crypt run {slot: item} (see Items). Not saved: they're lost
## when the run ends.
var equipped := {}
## Shrine blessings this Crypt run (each an item-like {name, effects}).
var blessings: Array = []
## Times the Crypt has been cleared (floor 5's boss beaten).
var crypt_wins := 0
## Finished the training tutorial (otherwise Training starts with it).
var tutorial_done := false
## Set when loading refunded an old upgrade web; camp shows it once.
var upgrade_notice := ""
## Has been through the first-time start (class pick, tutorial offer).
var onboarded := false
## The Crypt opens when the Bellman's seal breaks (his first defeat).
var crypt_unlocked := false
## Camp still has to play the Crypt rising behind it (once).
var crypt_reveal_pending := false
## The camp's Crypt button wears a NEW badge until the first descent.
var crypt_new := false
## Dead League progression. Results persist; the active flag and selected bout
## are session-only so entering the ring never mutates the player's build.
var dead_league_best := {}
var dead_league_clears := {}
var dead_league_bout := 0
var dead_league_active := false

## Each class's own progress: {class_id: {level, xp, attribute_points,
## attributes: {attribute: points}, cards: {id: rank}, draws (waiting),
## offer (the three cards on the table), rerolls (on this offer)}}. The
## properties below read and write the current class's entry.
var _classes := {}
## How full the ultimate is (0-1), kept up by Ult for the cards that care.
var ult_share := 0.0

var level: int:
	get:
		return _current().level
	set(value):
		_current().level = value
var xp: int:
	get:
		return _current().xp
	set(value):
		_current().xp = value
var attribute_points: int:
	get:
		return _current().attribute_points
	set(value):
		_current().attribute_points = value
var attributes: Dictionary:
	get:
		return _current().attributes
var cards: Dictionary:
	get:
		return _current().cards
var draws: int:
	get:
		return _current().draws
	set(value):
		_current().draws = value


func _ready() -> void:
	_reset_fields()
	load_game()
	# Ctrl is the dodge/uppercut key, and browsers close the tab on Ctrl+W
	# (pages can't block it). Ask before leaving so a stray W doesn't end a run.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.addEventListener('beforeunload', function (e) { e.preventDefault(); e.returnValue = ''; });")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# --- Trees and classes --------------------------------------------------------

## The upgrade web.
func tree(_kind := "upgrade") -> Dictionary:
	return UPGRADES


func class_level(id: String) -> int:
	return _classes[id].level


func _current() -> Dictionary:
	return _classes[player_class]


func _levels(_kind := "upgrade") -> Dictionary:
	return upgrade_levels


func _new_class_progress() -> Dictionary:
	var points := {}
	for attribute in Attributes.LIST:
		points[attribute] = 0
	return {"level": 1, "xp": 0, "attribute_points": 0, "attributes": points, "cards": {}, "draws": 0, "offer": [], "rerolls": 0}


# --- Derived values -------------------------------------------------------

## Total of one effect from owned upgrades, the current fighter's cards and
## attributes, equipped Crypt items, blessings and hats.
func get_effect(effect: String) -> float:
	var total := 0.0
	var amplify := effect in AMPLIFIED and is_player_class("elementalist")
	for id in upgrade_levels:
		# Only the selected power's line counts.
		if not power_active(id):
			continue
		var amount: float = UPGRADES[id].effects.get(effect, 0) * upgrade_levels[id]
		if amplify and amount != 0.0 and power_of(id) != "":
			amount *= _power_scale(power_of(id))
		if amount != 0.0 and power_of(id) != "":
			amount *= _hat_boost(power_of(id), effect)
		total += amount
	var progress := _current()
	var deck := Cards.deck(player_class)
	for id in progress.cards:
		var values = deck.get(id, {}).get("effects", {}).get(effect)
		if values != null:
			total += float(values[mini(int(progress.cards[id]), values.size()) - 1])
	for attribute in progress.attributes:
		total += float(Attributes.LIST[attribute].per_point.get(effect, 0.0)) * int(progress.attributes[attribute])
	for slot in equipped:
		total += equipped[slot].effects.get(effect, 0.0)
	for blessing in blessings:
		total += blessing.effects.get(effect, 0.0)
	for id in hats:
		if Hats.CATALOG.has(id):
			total += float(Hats.CATALOG[id].effects.get(effect, 0.0))
	# Tony's The Take: his cut of every coin.
	if effect == "coin_bonus" and has_passive("the_take"):
		total += 0.25 + 0.03 * passive_power()
	return total


## A power hat's lift on one of its power's numbers (HAT_BOOSTS), 1 if none.
func _hat_boost(root: String, effect: String) -> float:
	var entry: Array = HAT_BOOSTS.get(root, [])
	if entry.is_empty() or not effect in entry[1]:
		return 1.0
	return 1.0 + _hats_total(entry[0]) + _hats_total("all_power_boost")


## One effect summed over the hats owned (straight from the catalog).
func _hats_total(effect: String) -> float:
	var total := 0.0
	for id in hats:
		if Hats.CATALOG.has(id):
			total += float(Hats.CATALOG[id].effects.get(effect, 0.0))
	return total


# --- Powers: one at a time ---------------------------------------------------------------

## The power (sigil node id) an upgrade belongs to, or "" for none.
static var _power_cache := {}


static func power_of(id: String) -> String:
	if _power_cache.is_empty():
		for node_id in UPGRADES:
			var current: String = node_id
			var root := ""
			for i in 20:
				if SkillTreeView.BRANCHES.has(current):
					root = current
					break
				var requires: Array = UPGRADES[current].requires
				if requires.is_empty():
					break
				current = requires[0]
			_power_cache[node_id] = root
	return _power_cache.get(id, "")


## Not part of a power, or part of the selected one. The Catalyst: two
## selected (Dual Sigil), or every owned power's base node (Prism).
func power_active(id: String) -> bool:
	var root := power_of(id)
	if root == "":
		return true
	if is_player_class("elementalist"):
		match passive():
			"dual_sigil":
				return root == power_pick or root == power_pick_2
			"prism":
				return id == root and root in prism_picks()
	return root == power_pick


## Whether an owned power is one of the picks (the camp's Select button).
func power_selected(root: String) -> bool:
	if is_player_class("elementalist"):
		match passive():
			"dual_sigil":
				return root == power_pick or root == power_pick_2
			"prism":
				return root in prism_picks()
	return root == power_pick


## Prism's four: the picks, topped up with owned powers in climb order.
func prism_picks() -> Array:
	var picks := []
	for root in [power_pick, power_pick_2, power_pick_3, power_pick_4]:
		if root != "" and upgrade_levels.get(root, 0) > 0 and not root in picks:
			picks.append(root)
	for root in owned_powers():
		if picks.size() >= PRISM_SLOTS:
			break
		if not root in picks:
			picks.append(root)
	return picks.slice(0, PRISM_SLOTS)


## How many powers can be selected at once: two under Dual Sigil, four
## under Prism. (Living Conduit added one until 2026-10-29.)
func power_slots() -> int:
	if not is_player_class("elementalist"):
		return 1
	match passive():
		"prism":
			return PRISM_SLOTS
		"dual_sigil":
			return 2
	return 1


## Picks which owned power works. With more than one slot the newest pick
## joins the others (the oldest drops out).
func select_power(root: String) -> bool:
	if not SkillTreeView.BRANCHES.has(root) or upgrade_levels.get(root, 0) <= 0:
		return false
	var slots := power_slots()
	var picks := [root]
	var older: Array = prism_picks() if is_player_class("elementalist") and passive() == "prism" \
			else [power_pick, power_pick_2, power_pick_3, power_pick_4]
	for pick in older:
		if pick != "" and not pick in picks:
			picks.append(pick)
	power_pick = root
	power_pick_2 = picks[1] if slots > 1 and picks.size() > 1 else ""
	power_pick_3 = picks[2] if slots > 2 and picks.size() > 2 else ""
	power_pick_4 = picks[3] if slots > 3 and picks.size() > 3 else ""
	_commit()
	return true


## Selected powers, attuned (or newest) first.
func selected_powers() -> Array:
	var picks := []
	for root in [power_pick, power_pick_2, power_pick_3]:
		if root != "" and power_selected(root) and not root in picks:
			picks.append(root)
	if is_player_class("elementalist") and passive() == "prism":
		return prism_picks()
	return picks


## The Catalyst's scale on a power's numbers (AMPLIFIED): passive power under
## Dual Sigil, x1.5+ for the attuned power, a little more under Prism; his
## cards on top (Conduit, Deep Attunement, Archmage).
func _power_scale(root: String) -> float:
	if not is_player_class("elementalist"):
		return 1.0
	var cards_amp := get_effect("conduit")
	if ult_share > 0.5:
		cards_amp += get_effect("archmage")
	match passive():
		"attunement":
			if root != power_pick:
				return 1.0 + cards_amp
			return ATTUNE + 0.05 * passive_power() + 0.25 * get_effect("deep_attunement") + cards_amp
		"prism":
			return 1.0 + 0.04 * passive_power() + cards_amp
	return 1.0 + 0.05 * passive_power() + cards_amp


## Owned powers, in climb order.
func owned_powers() -> Array:
	return POWER_ROOTS.filter(func(root: String) -> bool: return upgrade_levels.get(root, 0) > 0)


# --- Loadouts: passives and ultimates ------------------------------------------------

## The equipped passive of the fighter being played (the default if the pick
## isn't unlocked).
func passive(class_id := "") -> String:
	return _equipped(class_id if class_id != "" else player_class, "passive")


func ultimate(class_id := "") -> String:
	return _equipped(class_id if class_id != "" else player_class, "ultimate")


func has_passive(id: String) -> bool:
	return passive() == id


func has_ultimate(id: String) -> bool:
	return ultimate() == id


func _equipped(class_id: String, slot: String) -> String:
	var pick: String = loadouts.get(class_id, {}).get(slot, "")
	var level_now := class_level(class_id) if _classes.has(class_id) else 1
	if pick != "" and Abilities.unlocked(class_id, pick, level_now):
		return pick
	return Abilities.default_passive(class_id) if slot == "passive" else Abilities.default_ultimate(class_id)


## Equips a passive or ultimate the fighter has unlocked.
func equip_ability(slot: String, id: String) -> bool:
	if not Abilities.unlocked(player_class, id, level):
		return false
	var picks: Dictionary = loadouts.get(player_class, {})
	picks[slot] = id
	loadouts[player_class] = picks
	_commit()
	return true


## The current fighter's hand idle (their own unless they've picked another).
func idle_anim() -> String:
	var id: String = idle_picks.get(player_class, "")
	return id if id in IdleAnims.choices(player_class) else IdleAnims.base_for(player_class)


func equip_idle(id: String) -> bool:
	if not id in IdleAnims.choices(player_class):
		return false
	idle_picks[player_class] = id
	_commit()
	return true


## A fighter's skin ("" for their own look; the current fighter by default).
func skin(class_id := "") -> String:
	var fighter := player_class if class_id == "" else class_id
	var id: String = skin_picks.get(fighter, "")
	return id if skins_owned.has(id) and String(Skins.CATALOG.get(id, {}).get("fighter", "")) == fighter else ""


## Wears a skin you own on its fighter ("" back to their own look).
func equip_skin(class_id: String, id: String) -> bool:
	if id != "" and (not skins_owned.has(id) or Skins.CATALOG[id].fighter != class_id):
		return false
	skin_picks[class_id] = id
	_commit()
	return true


## What strengthens the equipped passive (Abilities.POWER_TEXT): a point
## every few levels.
func passive_power() -> float:
	return float(mini((level - 1) / PASSIVE_POWER_EVERY, PASSIVE_POWER_MAX))


## A kept item straight into the armory (the Soul Shop's gear).
func add_to_armory(item: Dictionary) -> void:
	item.uid = _next_uid
	_next_uid += 1
	item.erase("found")
	armory.append(item)
	changed.emit()


## Marks a mini tutorial as shown (and saves).
func mark_tip(id: String) -> void:
	tips_seen[id] = true
	_commit()


## Tony joins the roster (the fourth Yonker, or the secret code in Settings).
func unlock_tony() -> void:
	tony_unlocked = true
	_commit()


## The Catalyst's secret code: as if he'd been bought in the Soul Shop.
func unlock_catalyst() -> void:
	fighters_bought["elementalist"] = true
	_commit()


## A drill run ended: records the best score and, on the first run of the day,
## pays coins and XP for the score (scaled to your Arena division's pay).
## Returns {paid, coins, xp, best, new_best}.
func claim_drill(drill: String, score: int, _level: int) -> Dictionary:
	Achievements.earn("drill")
	Bounties.event("drill")
	var record: Dictionary = drills.get(drill, {"best": 0, "day": ""})
	var today := Time.get_date_string_from_system()
	var result := {"paid": false, "coins": 0, "xp": 0, "best": int(record.best), "new_best": score > int(record.best)}
	record.best = maxi(int(record.best), score)
	result.best = record.best
	if record.day != today and score > 0:
		record.day = today
		var share: float = score / float(DRILL_GOOD_SCORE.get(drill, 1500.0))
		if DRILL_CAP.has(drill):
			share = minf(share, float(DRILL_CAP[drill]))
		var x := climb_position()
		result.coins = roundi(770.0 * Progression.pay(x) * share)
		result.xp = roundi(250.0 * Progression.xp_pay(x) * share)
		result.paid = true
		resources["coins"] = resources.get("coins", 0) + result.coins
		add_xp(result.xp)
	drills[drill] = record
	_commit()
	return result


## How far up the climb you've fought: the furthest Arena bout you've
## reached (the next one after your best win) or Crypt floor you've cleared,
## whichever is further. Daily drills pay at this point on the pay ladder.
func climb_position() -> float:
	var x := 0.0
	for division in range(1, Progression.current_tier() + 1):
		var won := int(arena_bouts.get(str(division), 0))
		if won > 0 or division == 1:
			x = maxf(x, Progression.arena_position(division, mini(won + 1, Progression.BOUTS_PER_DIVISION)))
	if crypt_floors_cleared > 0:
		x = maxf(x, Progression.crypt_position(crypt_floors_cleared, 1.0))
	return x


## Where the drills pay from, for the picker: "GRAVEDIGGER DIVISION  ·  BOUT 2".
func climb_place() -> String:
	var x := climb_position()
	var division := clampi(floori(x) + 1, 1, Progression.TIER_COUNT)
	var bout := clampi(roundi((x - (division - 1)) * Progression.BOUTS_PER_DIVISION) + 1, 1, Progression.BOUTS_PER_DIVISION)
	return "%s DIVISION  ·  BOUT %d" % [Progression.TIERS[division - 1].division.to_upper(), bout]


## True when this drill's daily reward hasn't been claimed today.
func drill_ready(drill: String) -> bool:
	return drills.get(drill, {}).get("day", "") != Time.get_date_string_from_system()


## Puts on a hat you own, or takes it off when it's already on ("" for none).
func wear_hat(id: String) -> void:
	worn_hat = "" if id == worn_hat or not hats.has(id) else id
	_commit()


## Collects a popped hat. Returns "new", "duplicate" (turned into Souls) or
## "tony" (the fourth Yonker: Tony unlocks).
func add_hat(id: String) -> String:
	if not Hats.CATALOG.has(id):
		return ""
	Bounties.event("hat")
	if hats.has(id):
		hats[id] = int(hats[id]) + 1
		souls += Hats.DUPLICATE_SOULS[Hats.CATALOG[id].rarity]
		_commit()
		return "duplicate"
	hats[id] = 1
	Achievements.earn("first_hat")
	if id in Hats.LEGENDARIES:
		Achievements.earn("legendary_hat")
	var result := "new"
	if not tony_unlocked and Hats.LEGENDARIES.all(func(legend: String) -> bool: return hats.has(legend)):
		tony_unlocked = true
		result = "tony"
	# All five plumber caps: the Plumber Jump, and Tony's overalls.
	if id in Hats.PLUMBER_CAPS and Hats.PLUMBER_CAPS.all(func(cap: String) -> bool: return hats.has(cap)) and not skins_owned.has("plumber_overalls"):
		skins_owned["plumber_overalls"] = true
		Achievements.earn("plumber_caps")
		Toast.show_on(get_tree(), "SKIN: PLUMBER OVERALLS", "Tony's. Wear it from Cosmetics.")
	_commit()
	return result


func add_blessing(blessing: Dictionary) -> void:
	blessings.append(blessing)
	changed.emit()


## Wears an item, replacing whatever was in its slot. A kept item that's
## swapped out stays in the armory.
func equip(item: Dictionary) -> void:
	if not item.has("uid"):
		item.uid = _next_uid
		_next_uid += 1
	equipped[item.slot] = item
	changed.emit()


## Starts a Crypt run: remembers the loadout you came in with.
func begin_crypt_run() -> void:
	_run_entry = equipped.duplicate()
	blessings.clear()


## Ends a Crypt run, by the exit stairs or knocked out alike (2026-10-17:
## gilding is for keeps, even when you go down): gilded finds join the armory
## and stay worn; finds that weren't gilded are lost (that slot goes back to
## what you came in with). Returns the kept finds.
func end_crypt_run(_escaped: bool) -> Array:
	var kept: Array = []
	for slot in equipped.keys():
		var item: Dictionary = equipped[slot]
		if not item.get("found", false):
			continue
		if item.get("gilded", false):
			item.erase("found")
			armory.append(item)
			kept.append(item)
		elif _run_entry.has(slot):
			equipped[slot] = _run_entry[slot]
		else:
			equipped.erase(slot)
	_run_entry = {}
	blessings.clear()
	_commit()
	return kept


## Gilds a found item so it can be kept, paying Souls (silver is paid by the
## Crypt run itself).
func gild(item: Dictionary) -> bool:
	var cost: int = Progression.GILD_SOULS.get(item.rarity, 2)
	if souls < cost or item.get("gilded", false):
		return false
	souls -= cost
	item.gilded = true
	changed.emit()
	return true


func armory_item(uid: int) -> Dictionary:
	for item in armory:
		if int(item.get("uid", 0)) == uid:
			return item
	return {}


## Wears a kept item from the armory.
func equip_from_armory(uid: int) -> void:
	var item := armory_item(uid)
	if not item.is_empty():
		equipped[item.slot] = item
		_commit()


func unequip(slot: String) -> void:
	equipped.erase(slot)
	_commit()


## Reforges a kept item for Souls: its numbers grow and it counts as deeper.
func reforge(uid: int) -> bool:
	var item := armory_item(uid)
	if item.is_empty():
		return false
	var cost := Progression.reforge_cost(item)
	if souls < cost:
		return false
	souls -= cost
	for effect in item.effects:
		if not Items.is_special(effect):
			item.effects[effect] = snappedf(float(item.effects[effect]) * Progression.REFORGE_GROWTH, 0.01)
	item.floor = int(item.get("floor", 1)) + Progression.REFORGE_FLOORS
	item.reforged = int(item.get("reforged", 0)) + 1
	_commit()
	return true


## Rerolls one regular stat on a kept item for Souls. Returns the new effect,
## or "" if it couldn't (not enough Souls, or nothing to swap to).
func reroll(uid: int, effect: String) -> String:
	var item := armory_item(uid)
	if item.is_empty():
		return ""
	var cost := Progression.reroll_cost(item)
	if souls < cost:
		return ""
	var picked := Items.reroll_effect(item, effect)
	if picked == "":
		return ""
	souls -= cost
	item.rerolls = int(item.get("rerolls", 0)) + 1
	# A worn copy is the same dictionary, so the fighter updates too.
	_commit()
	return picked


## Breaks a kept item down for coins.
func salvage(uid: int, coins: int) -> void:
	var item := armory_item(uid)
	if item.is_empty():
		return
	armory.erase(item)
	if equipped.get(item.slot, {}).get("uid", -1) == uid:
		equipped.erase(item.slot)
	resources["coins"] = resources.get("coins", 0) + coins
	_commit()


## Records a Crypt floor's boss as beaten. Returns true the first time.
func clear_crypt_floor(floor_number: int) -> bool:
	Achievements.earn("crypt_floor")
	Bounties.event("crypt_floor")
	var first_time := floor_number > crypt_floors_cleared
	crypt_floors_cleared = maxi(crypt_floors_cleared, floor_number)
	_commit()
	return first_time


func has_effect(effect: String) -> bool:
	return get_effect(effect) > 0.0


## A number from the current class's mods, or default if it doesn't change it.
func get_class_mod(key: String, default := 1.0) -> float:
	return CLASSES[player_class].mods.get(key, default)


func get_current_night() -> int:
	return nights_cleared + 1


## Records a night's boss as beaten. Returns true the first time.
func clear_night(night: int) -> bool:
	var first_time := night > nights_cleared
	nights_cleared = maxi(nights_cleared, night)
	_commit()
	return first_time


## Records an Arena bout won in a division. Returns true the first time.
func endless_best_in(division: int) -> int:
	return int(endless_bests.get(str(division), 0))


func clear_arena_bout(division: int, bout: int) -> bool:
	var best := int(arena_bouts.get(str(division), 0))
	var first_time := bout > best
	arena_bouts[str(division)] = maxi(best, bout)
	nights_cleared = maxi(nights_cleared, 1)
	_commit()
	return first_time


func add_souls(amount: int) -> void:
	souls += amount
	_commit()


## The Bellman's seal breaks: the Crypt opens, and camp shows it rising.
const CRYPT_SEAL := "bellman"


func unlock_crypt() -> void:
	crypt_unlocked = true
	crypt_reveal_pending = true
	crypt_new = true
	_commit()


## "The Mauler" etc.: the fighter you play as. class_id defaults to the current one.
## The fighters you can pick: Tony only once he's unlocked.
func class_ids() -> Array:
	return CLASSES.keys().filter(func(id: String) -> bool:
		return (not id in SECRET_CLASSES or tony_unlocked) and (not id in SHOP_CLASSES or fighters_bought.has(id)))


func fighter_name(class_id := "") -> String:
	return CLASSES[player_class if class_id == "" else class_id].fighter


func fighter_color(class_id := "") -> Color:
	return CLASSES[player_class if class_id == "" else class_id].color


func is_player_class(id: String) -> bool:
	return player_class == id


func set_player_class(id: String) -> void:
	if CLASSES.has(id):
		player_class = id
		_commit()


func get_damage() -> float:
	return (2.0 + get_effect("damage")) * get_class_mod("damage") * (1.0 + get_effect("damage_percent"))


func get_defense() -> float:
	return get_effect("defense") + get_class_mod("defense", 0.0)


## Multiplier on knuckle HP lost to enemy hits. Never reaches zero.
func get_knuckle_loss_multiplier() -> float:
	return 10.0 / (10.0 + get_defense())


func get_max_knuckles() -> float:
	return (50.0 + get_effect("max_knuckles")) * get_class_mod("knuckles") * (1.0 + get_effect("knuckles_percent"))


func get_move_speed_multiplier() -> float:
	return 1.0 + get_effect("move_speed")


## Share (0-0.75) of an enemy's armor your punches ignore.
func get_armor_pierce() -> float:
	return minf(get_effect("armor_pierce"), MAX_ARMOR_PIERCE)


## Damage multiplier for hooks and uppercuts.
func get_heavy_multiplier() -> float:
	return 1.0 + get_effect("heavy_bonus")


## Knuckle HP a kill restores. Heal effects are a percent of max knuckle HP,
## so they matter as much at the Coffin King as at the Bellman.
func get_heal_on_kill() -> float:
	return heal_amount("heal_on_kill")


## A heal effect (stored as a percent of max knuckle HP) in knuckle HP.
func heal_amount(effect: String, max_knuckles := -1.0) -> float:
	return get_effect(effect) * (get_max_knuckles() if max_knuckles < 0.0 else max_knuckles) / 100.0


func get_wave_bonus_multiplier() -> float:
	return 1.0 + get_effect("wave_bonus")


func get_combo_step() -> float:
	return (0.25 + get_effect("combo_step")) * get_class_mod("combo_step")


## Combo time: gear adds up to a cap; the White Strong Guy Wig raises the
## caps on combo, dodge and counter windows and stretches all three.
func get_combo_window() -> float:
	var bonus := minf(get_effect("combo_window"), MAX_COMBO_WINDOW_BONUS * (1.0 + get_effect("window_cap_up")))
	return (1.5 + bonus + get_class_mod("combo_window", 0.0)) * (1.0 + get_effect("window_boost"))


func get_punch_speed() -> float:
	return get_class_mod("punch_speed") * (1.0 + get_effect("punch_speed"))


## Dodge windows grow only so far: past that, dodging stops being a skill.
func get_dodge_window_multiplier() -> float:
	var cap := MAX_DODGE_WINDOW_BONUS * (1.0 + get_effect("window_cap_up"))
	return get_class_mod("dodge_window") * (1.0 + minf(get_effect("dodge_window"), cap)) * (1.0 + get_effect("window_boost"))


## Extra seconds to land a counter after a dodge (capped like dodge windows).
func get_counter_window_bonus() -> float:
	var bonus := minf(get_effect("counter_window"), MAX_COUNTER_WINDOW_BONUS * (1.0 + get_effect("window_cap_up")))
	# The Wig stretches the whole window, base and bonus.
	return bonus + (Player.COUNTER_WINDOW + bonus) * get_effect("window_boost")


func get_counter_multiplier(base: float) -> float:
	return get_class_mod("counter", base) + get_effect("counter_bonus")


func get_sprint_multiplier() -> float:
	return get_class_mod("sprint") * (1.0 + get_effect("sprint_bonus"))


func get_coin_multiplier() -> float:
	return 1.0 + get_effect("coin_bonus")


## The next Dead League bout is the True Coffin King's (the secret boss; set
## by the League menu, never saved).
var true_king_bout := false


func begin_dead_league() -> void:
	dead_league_active = true


func end_dead_league() -> void:
	dead_league_active = false


func dead_league_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var previous_id: String = DeadLeagueRules.boss(index - 1).id
	return bool(dead_league_clears.get(previous_id, false))


## Saves a personal best. Returns true on a contender's first clear, which
## breaks their seal (Progression).
func record_dead_league_result(boss_id: String, grade: String, score: int) -> bool:
	var first_clear := not bool(dead_league_clears.get(boss_id, false))
	if first_clear:
		dead_league_clears[boss_id] = true
		Achievements.earn("first_contender")
		if boss_id == CRYPT_SEAL and not crypt_unlocked:
			unlock_crypt()
	var previous: Dictionary = dead_league_best.get(boss_id, {})
	if previous.is_empty() or score > int(previous.get("score", -1)):
		dead_league_best[boss_id] = {"grade": grade, "score": score}
	_commit()
	return first_clear


## Rolls coins for a kill; fractional amounts become a chance at +1.
func roll_coins(base_amount: int) -> int:
	var total: float = base_amount * get_coin_multiplier()
	var amount := int(total)
	if randf() < total - amount:
		amount += 1
	return amount


func xp_to_next() -> int:
	return int(round(12.0 * pow(level, 1.75)))


# --- Gaining ---------------------------------------------------------------

## XP goes to the class being played.
func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		attribute_points += Attributes.POINTS_PER_LEVEL
		draws += 1
		leveled_up.emit(level)
	changed.emit()


func add_resource(resource: String, amount: int) -> void:
	resources[resource] = resources.get(resource, 0) + amount
	changed.emit()


# --- Spending ---------------------------------------------------------------

func spend_attribute(attribute: String) -> bool:
	if attribute_points <= 0 or not attributes.has(attribute) or int(attributes[attribute]) >= Attributes.MAX:
		return false
	attribute_points -= 1
	attributes[attribute] += 1
	_commit()
	return true


## Every attribute point back, for coins.
func reset_attributes() -> bool:
	var spent := 0
	for attribute in attributes:
		spent += int(attributes[attribute])
	var cost := Attributes.reset_cost()
	if spent == 0 or resources.get("coins", 0) < cost:
		return false
	resources["coins"] -= cost
	for attribute in attributes:
		attributes[attribute] = 0
	attribute_points += spent
	_commit()
	return true


## Whether an attribute perk is unlocked for the current fighter.
func perk(id: String) -> bool:
	var needs := Attributes.perk_needs(id)
	return int(attributes.get(needs[0], 0)) >= int(needs[1])


# --- Cards ------------------------------------------------------------------------

## A card's rank for the current fighter (0 if not drawn).
func card_rank(id: String) -> int:
	return int(cards.get(id, 0))


## The seals whose legendary cards this fighter can draw: broken, and the
## fighter at the level par puts there (Progression.PAR_LEVEL), so a new
## fighter in a late save doesn't draw every legendary at level 1.
func card_seals() -> Dictionary:
	var seals := {}
	for i in Cards.SEALS.size():
		var seal: String = Cards.SEALS[i]
		if dead_league_clears.get(seal, false) and level >= Progression.PAR_LEVEL[i + 1]:
			seals[seal] = true
	return seals


## The three cards on the table (drawn when a draw is waiting).
func card_offer() -> Array:
	var progress := _current()
	if progress.draws <= 0:
		return []
	if progress.offer.is_empty():
		progress.offer = Cards.draw(player_class, progress.cards, 3, card_seals())
		if progress.offer.is_empty():
			# The deck is spent (or everything's sealed): the draw waits.
			return []
		save_game()
	return progress.offer


## Keep one of the offered cards (a new card, or a rank up).
func take_card(id: String) -> bool:
	var progress := _current()
	if progress.draws <= 0 or not id in progress.offer:
		return false
	progress.cards[id] = card_rank(id) + 1
	progress.draws -= 1
	progress.offer = []
	progress.rerolls = 0
	_commit()
	return true


func reroll_cost() -> int:
	return REROLL_SOULS + int(_current().rerolls)


## Three new cards for this draw (different ones where the deck allows).
func reroll_offer() -> bool:
	var progress := _current()
	if progress.offer.is_empty() or souls < reroll_cost():
		return false
	souls -= reroll_cost()
	progress.rerolls += 1
	var shown: Array = progress.offer
	var hidden: Dictionary = progress.cards.duplicate()
	for id in shown:
		hidden[id] = Cards.copies(Cards.info(player_class, id))
	var fresh := Cards.draw(player_class, hidden, 3, card_seals())
	if fresh.size() < 3:
		for id in Cards.draw(player_class, progress.cards, 3, card_seals()):
			if fresh.size() < 3 and not id in fresh:
				fresh.append(id)
	progress.offer = fresh
	_commit()
	return true


func swap_cost(id: String) -> int:
	return int(SWAP_SOULS.get(Cards.info(player_class, id).get("rarity", "common"), 2))


## Give back one rank of a card for a fresh draw (without it on the table).
func swap_card(id: String) -> bool:
	var progress := _current()
	if card_rank(id) <= 0 or souls < swap_cost(id) or usable_draws() > 0:
		return false
	souls -= swap_cost(id)
	progress.cards[id] = card_rank(id) - 1
	if progress.cards[id] <= 0:
		progress.cards.erase(id)
	progress.draws += 1
	var without: Dictionary = progress.cards.duplicate()
	without[id] = Cards.copies(Cards.info(player_class, id))
	progress.offer = Cards.draw(player_class, without, 3, card_seals())
	if progress.offer.is_empty():
		progress.offer = Cards.draw(player_class, progress.cards, 3, card_seals())
	progress.rerolls = 0
	_commit()
	return true


## Every card back to the deck, a draw for each.
func redraft() -> bool:
	var progress := _current()
	var kept := 0
	for id in progress.cards:
		kept += int(progress.cards[id])
	if kept == 0 or souls < REDRAFT_SOULS:
		return false
	souls -= REDRAFT_SOULS
	progress.cards = {}
	progress.draws += kept
	progress.offer = []
	progress.rerolls = 0
	_commit()
	return true


## Draws the deck can fill now. Past about level 40 there are more draws than
## cards; the rest wait for a swap, a redraft or a seal.
func usable_draws() -> int:
	return mini(draws, Cards.left_in_deck(player_class, cards, card_seals()))


func cards_kept() -> int:
	var kept := 0
	for id in cards:
		kept += int(cards[id])
	return kept


## The center node stands for itself and the Trophies (2026-10-28): each
## contender beaten raises its level cap by that contender's Trophy, and it
## shows (and buys) the first stage not yet maxed, with its name and icon.
const CENTER_STAGES := ["wrapped_knuckles", "bellmans_bell", "headless_helm", "southpaws_rosary", "plague_censer", "coffin_crown"]


func center_stage() -> String:
	var last: String = CENTER_STAGES[0]
	for id in CENTER_STAGES:
		if not node_open("upgrade", id):
			break
		last = id
		if node_level("upgrade", id) < int(UPGRADES[id].max_level):
			return id
	return last


## [levels bought, level cap] across the center's open stages.
func center_levels() -> Vector2i:
	var levels := Vector2i.ZERO
	for id in CENTER_STAGES:
		levels.x += node_level("upgrade", id)
		if node_open("upgrade", id):
			levels.y += int(UPGRADES[id].max_level)
	return levels


## The node a web cell stands for: the center's current stage, or itself.
func shown_node(kind: String, id: String) -> String:
	return center_stage() if kind == "upgrade" and id == CENTER_STAGES[0] else id


func node_level(kind: String, id: String) -> int:
	return _levels(kind).get(id, 0)


## "maxed", "owned" (some levels), "available" (requirements met), or "hidden".
## Coin upgrades require every parent node to be maxed before they are revealed;
## fighter skills keep their looser rule and reveal after one rank in each parent.
func node_state(kind: String, id: String) -> String:
	var node: Dictionary = tree(kind)[id]
	var owned := node_level(kind, id)
	if owned >= node.max_level:
		return "maxed"
	if owned > 0:
		return "owned"
	for required in node.requires:
		var required_level := node_level(kind, required)
		if required_level == 0:
			return "hidden"
		if kind == "upgrade" and required_level < int(tree(kind)[required].max_level):
			return "hidden"
	if not node_open(kind, id):
		return "sealed"
	return "available"


## Share (0-1) of all upgrade levels in rings up to max_ring that you own.
func upgrade_share(max_ring: int) -> float:
	var total := 0
	var owned := 0
	for id in UPGRADES:
		if int(UPGRADES[id].get("ring", 1)) > max_ring:
			continue
		total += int(UPGRADES[id].max_level)
		owned += node_level("upgrade", id)
	return float(owned) / maxf(total, 1.0)


## A node's seal ring (1 = open from the start).
func node_ring(kind: String, id: String) -> int:
	return int(tree(kind)[id].get("ring", 1))


## True once the node's ring has been unsealed by Dead League wins (and an
## Endless power's Sigil, once its division's endless bout is won).
func node_open(kind: String, id: String) -> bool:
	var endless := int(tree(kind)[id].get("endless", 0))
	if endless > 0 and not endless_won(endless):
		return false
	return node_ring(kind, id) <= Progression.open_ring()


## A division's endless bout (its third) has been won.
func endless_won(division: int) -> bool:
	return int(arena_bouts.get(str(division), 0)) >= Progression.BOUTS_PER_DIVISION


## Price of the next level (coins for upgrades, skill points for skills).
func node_cost(kind: String, id: String) -> int:
	var node: Dictionary = tree(kind)[id]
	return price_at(node, node_level(kind, id))


## A node's price at a level (0 = the first), rounded to two figures (2026-10-28):
## 80, 100, 130, 160, 200... never 102 or 153.
static func price_at(node: Dictionary, level: int) -> int:
	return nice_price(node.cost * pow(node.cost_growth, level))


static func nice_price(value: float) -> int:
	if value < 100.0:
		return roundi(value / 10.0) * 10 if value >= 20.0 else roundi(value)
	var step := pow(10.0, floorf(log(value) / log(10.0)) - 1.0)
	return roundi(roundf(value / step) * step)


func node_currency(_kind := "upgrade") -> int:
	return resources.get("coins", 0)


## The contender whose seal still blocks this node ("" when it's open), or
## the endless bout for an Endless power.
func node_sealed_by(kind: String, id: String) -> String:
	if node_open(kind, id):
		return ""
	var endless := int(tree(kind)[id].get("endless", 0))
	if endless > 0 and not endless_won(endless):
		return "%s ENDLESS" % String(Progression.TIERS[endless - 1].division).to_upper()
	return Progression.seal_holder(node_ring(kind, id))


## What breaks the seal: "beat THE BELLMAN", "win the GRAVEDIGGER ENDLESS".
func node_seal_text(kind: String, id: String) -> String:
	var holder := node_sealed_by(kind, id)
	if holder == "":
		return ""
	return ("win the " if holder.ends_with(" ENDLESS") else "beat ") + holder


## The cheapest upgrade on the web you could buy now (0 if none): what
## finishing the tutorial pays.
func cheapest_upgrade() -> int:
	var cheapest := 0
	for id in UPGRADES:
		if node_state("upgrade", id) == "available":
			var cost := node_cost("upgrade", id)
			if cheapest == 0 or cost < cheapest:
				cheapest = cost
	return cheapest


func can_buy_node(kind: String, id: String) -> bool:
	var state := node_state(kind, id)
	return (state == "available" or state == "owned") \
			and node_currency(kind) >= node_cost(kind, id)


func buy_node(kind: String, id: String) -> bool:
	if not can_buy_node(kind, id):
		return false
	resources["coins"] -= node_cost(kind, id)
	_levels(kind)[id] = node_level(kind, id) + 1
	_commit()
	# Maxing a power (or all of them) wins its hat.
	if kind == "upgrade":
		Hats.check_awards(get_tree())
	return true


## e.g. "+6 damage, +3 defense" for a node's effects at the given level.
func effect_text(effects: Dictionary, at_level: int) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if effect in FLAG_EFFECTS:
			parts.append(EFFECT_FORMATS[effect])
			continue
		if effect == "passive_power":
			parts.append(Abilities.power_text(passive(), effects[effect] * at_level))
			continue
		var value: float = effects[effect] * at_level
		if effect in PERCENT_EFFECTS:
			value *= 100.0
		var shown := "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).rstrip("0")
		parts.append(EFFECT_FORMATS.get(effect, effect + " %s") % shown + _cap_note(effect))
	return ", ".join(parts)


## Capped effects show your total against the cap: "(0.3/0.5s)", "(maxed)".
func _cap_note(effect: String) -> String:
	var cap: float
	var unit: String
	var scale := 1.0
	match effect:
		"counter_window":
			cap = MAX_COUNTER_WINDOW_BONUS
			unit = "s"
		"dodge_window":
			cap = MAX_DODGE_WINDOW_BONUS
			unit = "%"
			scale = 100.0
		_:
			return ""
	var have := minf(get_effect(effect), cap)
	var cap_text := ("%.2f" % (cap * scale)).rstrip("0").rstrip(".") + unit
	if have >= cap - 0.001:
		return " (maxed)"
	return " (%s/%s)" % [("%.2f" % (have * scale)).rstrip("0").rstrip("."), cap_text]


# --- Saving -----------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"class": player_class,
		"nights_cleared": nights_cleared,
		"crypt_floors_cleared": crypt_floors_cleared,
		"crypt_wins": crypt_wins,
		"tutorial_done": tutorial_done,
		"onboarded": onboarded,
		"crypt_unlocked": crypt_unlocked,
		"crypt_reveal_pending": crypt_reveal_pending,
		"crypt_new": crypt_new,
		"dead_league_best": dead_league_best,
		"dead_league_clears": dead_league_clears,
		"souls": souls,
		"armory": armory,
		"equipped": equipped,
		"next_uid": _next_uid,
		"arena_division": arena_division,
		"arena_bouts": arena_bouts,
		"crypt_tier": crypt_tier,
		"hats": hats,
		"worn_hat": worn_hat,
		"tips_seen": tips_seen,
		"shop_stock": shop_stock,
		"shop_restock_at": shop_restock_at,
		"shop_rerolls": shop_rerolls,
		"emotes_bought": emotes_bought,
		"fighters_bought": fighters_bought,
		"fights_done": fights_done,
		"bounties": bounties,
		"idle_picks": idle_picks,
		"idles_bought": idles_bought,
		"skins_owned": skins_owned,
		"skin_picks": skin_picks,
		"bounty_xp": bounty_xp,
		"kills": kills,
		"loadouts": loadouts,
		"endless_bests": endless_bests,
		"achievements": achievements,
		"power_pick": power_pick,
		"power_pick_2": power_pick_2,
		"power_pick_3": power_pick_3,
		"power_pick_4": power_pick_4,
		"drills": drills,
		"hat_pity": hat_pity,
		"tony_unlocked": tony_unlocked,
		"upgrades": upgrade_levels,
		"upgrade_version": UPGRADE_VERSION,
		"skill_version": SKILL_VERSION,
		"resources": resources,
		"classes": _classes,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


## The game used to be called PunchCraft, which kept its save in a different
## user folder. Copy that save over the first time Fright Night runs.
func _bring_over_old_save() -> void:
	if save_path != SAVE_PATH or FileAccess.file_exists(SAVE_PATH):
		return
	var old_path := OS.get_user_data_dir().get_base_dir().path_join("PunchCraft/save.json")
	if FileAccess.file_exists(old_path):
		DirAccess.copy_absolute(old_path, ProjectSettings.globalize_path(SAVE_PATH))


func load_game() -> void:
	_bring_over_old_save()
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		push_warning("Save file is unreadable; starting fresh.")
		return
	if int(data.get("version", 1)) != SAVE_VERSION:
		push_warning("Save file is from an older version of the game; starting fresh.")
		return
	var saved_class: String = data.get("class", DEFAULT_CLASS)
	player_class = saved_class if CLASSES.has(saved_class) else DEFAULT_CLASS
	nights_cleared = int(data.get("nights_cleared", 0))
	crypt_floors_cleared = int(data.get("crypt_floors_cleared", 0))
	crypt_wins = int(data.get("crypt_wins", 0))
	tutorial_done = bool(data.get("tutorial_done", false))
	onboarded = bool(data.get("onboarded", true))  # Older saves: already playing.
	crypt_unlocked = bool(data.get("crypt_unlocked", crypt_floors_cleared > 0 or crypt_wins > 0))
	crypt_reveal_pending = bool(data.get("crypt_reveal_pending", false))
	crypt_new = bool(data.get("crypt_new", false))
	dead_league_best = data.get("dead_league_best", {}).duplicate(true) if data.get("dead_league_best", {}) is Dictionary else {}
	dead_league_clears = data.get("dead_league_clears", {}).duplicate(true) if data.get("dead_league_clears", {}) is Dictionary else {}
	# The Crypt now opens with the Bellman's seal: saves that beat him before
	# finding it get it now (and see it rise at camp).
	if bool(dead_league_clears.get(CRYPT_SEAL, false)) and not crypt_unlocked:
		crypt_unlocked = true
		crypt_reveal_pending = true
		crypt_new = true
	souls = int(data.get("souls", 0))
	armory = data.get("armory", []).duplicate(true) if data.get("armory", []) is Array else []
	for item in armory:
		if item is Dictionary:
			Items.retire_powers(item)
	_next_uid = int(data.get("next_uid", 1))
	var saved_equipped = data.get("equipped", {})
	equipped = {}
	if saved_equipped is Dictionary:
		for slot in saved_equipped:
			var uid := int(saved_equipped[slot].get("uid", -1)) if saved_equipped[slot] is Dictionary else -1
			var kept := armory_item(uid)
			if not kept.is_empty():
				equipped[slot] = kept
	arena_division = int(data.get("arena_division", 1))
	arena_bouts = data.get("arena_bouts", {}).duplicate() if data.get("arena_bouts", {}) is Dictionary else {}
	crypt_tier = int(data.get("crypt_tier", 1))
	hats = {}
	drills = data.get("drills", {}).duplicate(true) if data.get("drills", {}) is Dictionary else {}
	var saved_hats = data.get("hats", {})
	if saved_hats is Dictionary:
		for id in saved_hats:
			hats[id] = int(saved_hats[id])
	hat_pity = int(data.get("hat_pity", 0))
	tips_seen = data.get("tips_seen", {}).duplicate() if data.get("tips_seen", {}) is Dictionary else {}
	achievements = data.get("achievements", {}).duplicate() if data.get("achievements", {}) is Dictionary else {}
	power_pick = String(data.get("power_pick", ""))
	power_pick_2 = String(data.get("power_pick_2", ""))
	power_pick_3 = String(data.get("power_pick_3", ""))
	power_pick_4 = String(data.get("power_pick_4", ""))
	shop_stock = data.get("shop_stock", []).duplicate(true) if data.get("shop_stock", []) is Array else []
	for offer in shop_stock:
		if offer is Dictionary and offer.get("item") is Dictionary:
			Items.retire_powers(offer.item)
	shop_restock_at = int(data.get("shop_restock_at", -1))
	shop_rerolls = int(data.get("shop_rerolls", 0))
	emotes_bought = data.get("emotes_bought", {}).duplicate() if data.get("emotes_bought", {}) is Dictionary else {}
	fighters_bought = data.get("fighters_bought", {}).duplicate() if data.get("fighters_bought", {}) is Dictionary else {}
	fights_done = int(data.get("fights_done", 0))
	bounties = data.get("bounties", []).duplicate(true) if data.get("bounties", []) is Array else []
	bounty_xp = int(data.get("bounty_xp", 0))
	idle_picks = data.get("idle_picks", {}).duplicate() if data.get("idle_picks", {}) is Dictionary else {}
	idles_bought = data.get("idles_bought", {}).duplicate() if data.get("idles_bought", {}) is Dictionary else {}
	skins_owned = data.get("skins_owned", {}).duplicate() if data.get("skins_owned", {}) is Dictionary else {}
	skin_picks = data.get("skin_picks", {}).duplicate() if data.get("skin_picks", {}) is Dictionary else {}
	kills = data.get("kills", {}).duplicate() if data.get("kills", {}) is Dictionary else {}
	loadouts = data.get("loadouts", {}).duplicate(true) if data.get("loadouts", {}) is Dictionary else {}
	endless_bests = data.get("endless_bests", {}).duplicate() if data.get("endless_bests", {}) is Dictionary else {}
	# The one Endless Arena was the Crown Division's.
	if int(data.get("endless_best", 0)) > 0 and not endless_bests.has(str(Progression.TIER_COUNT)):
		endless_bests[str(Progression.TIER_COUNT)] = int(data.endless_best)
	worn_hat = String(data.get("worn_hat", ""))
	if not hats.has(worn_hat):
		worn_hat = ""
	tony_unlocked = bool(data.get("tony_unlocked", false))
	# Champion Sigils are gone: any saved (spent or not) become Souls.
	var old_sigils := int(data.get("sigils", 0))
	var saved_resources: Dictionary = data.get("resources", {})
	for resource in saved_resources:
		if RESOURCE_NAMES.has(resource):
			resources[resource] = int(saved_resources[resource])
	var saved_upgrade_version := int(data.get("upgrade_version", 1))
	if saved_upgrade_version < UPGRADE_VERSION and data.get("upgrades", {}) is Dictionary:
		if saved_upgrade_version == 7:
			# Seal rings (2026-10-28): same nodes, new spots and round prices.
			_load_upgrades(data.get("upgrades", {}))
			_refund_price_drop(data.get("upgrades", {}), V7_PRICES)
		elif saved_upgrade_version == 6:
			_load_upgrades(data.get("upgrades", {}))
			_refund_price_drop(data.get("upgrades", {}), V6_PRICES)
		elif saved_upgrade_version == 5:
			_respec_at(data.get("upgrades", {}), V5_PRICES)
		elif saved_upgrade_version == 4:
			_respec_at(data.get("upgrades", {}), V4_PRICES)
		elif saved_upgrade_version == 3:
			_respec_for_rings(data.get("upgrades", {}), old_sigils)
		elif saved_upgrade_version == 2:
			_refund_rebalanced_web(data.get("upgrades", {}), old_sigils)
		else:
			_refund_old_web(data.get("upgrades", {}), old_sigils)
	else:
		_load_upgrades(data.get("upgrades", {}))
	# Saves from before one-power-at-a-time keep their first power working.
	if not power_pick in owned_powers():
		var owned := owned_powers()
		power_pick = owned[0] if not owned.is_empty() else ""
	if not power_pick_2 in owned_powers() or power_pick_2 == power_pick:
		power_pick_2 = ""
	if not power_pick_3 in owned_powers() or power_pick_3 == power_pick or power_pick_3 == power_pick_2:
		power_pick_3 = ""
	if not power_pick_4 in owned_powers() or power_pick_4 in [power_pick, power_pick_2, power_pick_3]:
		power_pick_4 = ""

	var saved_classes: Dictionary = data.get("classes", {})
	if saved_classes.is_empty():
		# Older saves had one shared level: it becomes the current class's.
		_load_class_progress(player_class, data)
	else:
		for id in saved_classes:
			if CLASSES.has(id):
				_load_class_progress(id, saved_classes[id])

	# Version 3: skill webs and stats became card draws and attributes. Every
	# level gained comes back as a draw and its stat points as attribute points.
	if int(data.get("skill_version", 1)) < SKILL_VERSION:
		var leveled := false
		for id in _classes:
			var progress: Dictionary = _classes[id]
			var gained := int(progress.level) - 1
			leveled = leveled or gained > 0
			progress.cards = {}
			progress.draws = gained
			progress.offer = []
			progress.attributes = _new_class_progress().attributes
			progress.attribute_points = gained * Attributes.POINTS_PER_LEVEL
		if leveled:
			upgrade_notice = (upgrade_notice + "\n" if upgrade_notice != "" else "") \
					+ "Level-ups are now card draws and attributes. Every level you gained is a draw, and every stat point is an attribute point."
	# Armor Breaker went from flat armor to a share of it: convert kept gear.
	if saved_upgrade_version < 5:
		for item in armory:
			if item is Dictionary and item.get("effects", {}) is Dictionary and float(item.effects.get("armor_pierce", 0.0)) >= 1.0:
				item.effects.armor_pierce = snappedf(float(item.effects.armor_pierce) * 0.07, 0.01)
	# Nodes no longer connected to the center are removed and refunded.
	_refund_unreachable(UPGRADES, upgrade_levels, func(amount: int) -> void: resources["coins"] = resources.get("coins", 0) + amount)
	changed.emit()


func _load_class_progress(id: String, saved: Dictionary) -> void:
	var progress: Dictionary = _classes[id]
	progress.level = int(saved.get("level", 1))
	progress.xp = int(saved.get("xp", 0))
	progress.attribute_points = int(saved.get("attribute_points", 0))
	var saved_attributes = saved.get("attributes", {})
	if saved_attributes is Dictionary:
		for attribute in progress.attributes:
			var points := clampi(int(saved_attributes.get(attribute, 0)), 0, Attributes.MAX)
			progress.attributes[attribute] = points
	# Cards the deck no longer has come back as draws.
	progress.draws = int(saved.get("draws", 0))
	var saved_cards = saved.get("cards", {})
	if saved_cards is Dictionary:
		for card in saved_cards:
			var info := Cards.info(id, card)
			var rank := int(saved_cards[card])
			if info.is_empty():
				progress.draws += rank
			elif rank > 0:
				progress.cards[card] = mini(rank, Cards.copies(info))
				progress.draws += rank - progress.cards[card]
	var saved_offer = saved.get("offer", [])
	if saved_offer is Array:
		for card in saved_offer:
			if not Cards.info(id, String(card)).is_empty():
				progress.offer.append(String(card))
	progress.rerolls = int(saved.get("rerolls", 0))


## Souls given for each old Champion Sigil when sigils were retired.
const SOULS_PER_OLD_SIGIL := 3


## A node's price before ring scaling (what older saves paid): its version-4
## price without that version's ring multiplier.
func _pre_ring_cost(id: String) -> float:
	if not V4_PRICES.has(id):
		return 0.0
	return float(V4_PRICES[id][0]) / Progression.RING_COST.get(int(V4_RINGS.get(id, 1)), 1.0)


## The web was rebuilt: give back every coin spent on it.
func _refund_old_web(saved: Dictionary, old_sigils: int) -> void:
	var coins := 0
	for id in saved:
		var owned := int(saved[id])
		var price: Array = RETIRED_UPGRADES.get(id, [])
		if price.is_empty():
			if not UPGRADES.has(id):
				continue
			price = [_pre_ring_cost(id), UPGRADES[id].cost_growth, 0]
		for i in owned:
			coins += roundi(price[0] * pow(price[1], i))
	_give_respec(coins, old_sigils)


## Version 2 used the current node ids but much lower prices. Clear those
## purchases and return what they approximately cost then, not today's price;
## otherwise a maxed save would immediately be able to max the larger web again.
func _refund_rebalanced_web(saved: Dictionary, old_sigils: int) -> void:
	var current_value := 0
	for id in saved:
		if not V4_PRICES.has(id):
			continue
		for level in mini(int(saved[id]), int(V4_LEVELS.get(id, 1))):
			current_value += roundi(_pre_ring_cost(id) * pow(float(V4_PRICES[id][1]), level))
	_give_respec(roundi(current_value * V2_REFUND_SCALE), old_sigils)


## Version 3 -> 4 (the Climb): the web became five sealed rings with new
## prices. Clear it and refund what it cost at the old (pre-ring) prices;
## Champion Sigils become Souls.
func _respec_for_rings(saved: Dictionary, old_sigils: int) -> void:
	var coins := 0
	for id in saved:
		if not V4_PRICES.has(id):
			continue
		for level in mini(int(saved[id]), int(V4_LEVELS.get(id, 1))):
			coins += roundi(_pre_ring_cost(id) * pow(float(V4_PRICES[id][1]), level))
	_give_respec(coins, old_sigils)


## The web was rebuilt (version 4 -> 5: the revamp; 5 -> 6: the spoke web).
## Clear it and refund exactly what it cost at that version's prices.
func _respec_at(saved: Dictionary, prices: Dictionary) -> void:
	var coins := 0
	for id in saved:
		if not prices.has(id):
			continue
		var price: Array = prices[id]
		for level in int(saved[id]):
			coins += roundi(price[0] * pow(price[1], level))
	if coins > 0:
		resources["coins"] = resources.get("coins", 0) + coins
		upgrade_notice = "The upgrades were rebuilt: everything you spent is back.
+%d {coins}" % coins


## Prices came down (same web): keep every level, and pay back what each one
## cost over its new price.
func _refund_price_drop(saved: Dictionary, prices: Dictionary) -> void:
	var coins := 0
	for id in saved:
		if not prices.has(id) or not UPGRADES.has(id):
			continue
		var old: Array = prices[id]
		for level in mini(int(saved[id]), int(UPGRADES[id].max_level)):
			coins += maxi(0, roundi(old[0] * pow(old[1], level)) - price_at(UPGRADES[id], level))
	if coins > 0:
		resources["coins"] = resources.get("coins", 0) + coins
		upgrade_notice = "Upgrades got cheaper. You keep everything you bought, and get the difference back.\n+%d {coins}" % coins


func _give_respec(coins: int, old_sigils: int) -> void:
	var gained_souls := old_sigils * SOULS_PER_OLD_SIGIL
	if coins == 0 and gained_souls == 0:
		return
	resources["coins"] = resources.get("coins", 0) + coins
	souls += gained_souls
	upgrade_notice = "Your upgrades were refunded.
+%d {coins}     +%d {souls}" % [coins, gained_souls]


## Reads {id: level}, or the older list-of-ids format (single-level nodes).
func _load_upgrades(saved) -> void:
	if saved is Array:
		for id in saved:
			if UPGRADES.has(id):
				upgrade_levels[id] = 1
			elif LEGACY_UPGRADES.has(id):
				var mapped: Array = LEGACY_UPGRADES[id]
				upgrade_levels[mapped[0]] = maxi(upgrade_levels.get(mapped[0], 0), mapped[1])
	elif saved is Dictionary:
		for id in saved:
			if UPGRADES.has(id):
				upgrade_levels[id] = clampi(int(saved[id]) + upgrade_levels.get(id, 0), 0, UPGRADES[id].max_level)
			elif MERGED_UPGRADES.has(id):
				var into: String = MERGED_UPGRADES[id]
				upgrade_levels[into] = clampi(int(saved[id]) + upgrade_levels.get(into, 0), 0, UPGRADES[into].max_level)


## Owned nodes that are no longer connected to the center (e.g. after a layout
## change) are removed; refund gets their full price.
func _refund_unreachable(nodes: Dictionary, owned: Dictionary, refund: Callable) -> void:
	var removed := true
	while removed:
		removed = false
		for id in owned.keys():
			var connected := true
			for required in nodes[id].requires:
				if owned.get(required, 0) == 0:
					connected = false
			if connected:
				continue
			var total := 0
			for i in owned[id]:
				total += price_at(nodes[id], i)
			refund.call(total)
			owned.erase(id)
			removed = true


func reset_progress() -> void:
	_reset_fields()
	_commit()


# --- Save codes --------------------------------------------------------------------

## A save as text to keep somewhere safe (web saves live in browser storage
## and vanish if it's cleared): "FN1:<size>:<the save file, gzipped, base64>".
const SAVE_CODE_TAG := "FN1:"
const SAVE_CODE_MAX := 1 << 20


func save_code() -> String:
	save_game()
	var raw := FileAccess.get_file_as_string(save_path).to_utf8_buffer()
	return "%s%d:%s" % [SAVE_CODE_TAG, raw.size(), Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))]


## Loads a save code over this save (the old one is kept beside it as
## save_before_code.json). Returns "" when it worked, or why it didn't.
func load_save_code(code: String) -> String:
	code = code.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
	if not code.begins_with(SAVE_CODE_TAG):
		return "Not a Fright Night save code."
	var parts := code.substr(SAVE_CODE_TAG.length()).split(":", false, 1)
	if parts.size() != 2 or not parts[0].is_valid_int() or int(parts[0]) <= 0 or int(parts[0]) > SAVE_CODE_MAX:
		return "That code is damaged."
	var text := Marshalls.base64_to_raw(parts[1]).decompress(int(parts[0]), FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var json := JSON.new()
	if text == "" or json.parse(text) != OK or not json.data is Dictionary or not json.data.has("classes"):
		return "That code is damaged."
	var data: Dictionary = json.data
	if int(data.get("version", 1)) != SAVE_VERSION:
		return "That code is from another version."
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path),
				ProjectSettings.globalize_path(save_path.get_base_dir().path_join("save_before_code.json")))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return "Couldn't write the save."
	file.store_string(text)
	file.close()
	_reset_fields()
	load_game()
	changed.emit()
	return ""


func _reset_fields() -> void:
	player_class = DEFAULT_CLASS
	tutorial_done = false
	onboarded = false
	crypt_unlocked = false
	crypt_reveal_pending = false
	crypt_new = false
	nights_cleared = 0
	crypt_floors_cleared = 0
	crypt_wins = 0
	dead_league_best = {}
	dead_league_clears = {}
	dead_league_bout = 0
	dead_league_active = false
	equipped = {}
	blessings = []
	souls = 0
	armory = []
	_next_uid = 1
	arena_division = 1
	arena_bouts = {}
	crypt_tier = 1
	hats = {}
	worn_hat = ""
	tips_seen = {}
	shop_stock = []
	shop_restock_at = -1
	shop_rerolls = 0
	emotes_bought = {}
	fighters_bought = {}
	fights_done = 0
	bounties = []
	bounty_xp = 0
	idle_picks = {}
	idles_bought = {}
	skins_owned = {}
	skin_picks = {}
	kills = {}
	loadouts = {}
	endless_bests = {}
	achievements = {}
	power_pick = ""
	power_pick_2 = ""
	power_pick_3 = ""
	power_pick_4 = ""
	drills = {}
	hat_pity = 0
	tony_unlocked = false
	_run_entry = {}
	upgrade_levels = {}
	_classes = {}
	for id in CLASSES:
		_classes[id] = _new_class_progress()
	resources = {}
	for resource in RESOURCE_NAMES:
		resources[resource] = 0


func _commit() -> void:
	save_game()
	changed.emit()
