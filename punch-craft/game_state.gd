extends Node
## Persistent progression (autoloaded as GameState). Shared: coins, Champion
## Souls, the armory, the upgrade web and what's been cleared. Per class: level, XP, stat and
## skill points, stats and that class's own skill web. Saved to disk.

signal changed
signal leveled_up(new_level: int)

const SAVE_PATH := "user://save.json"
## Test runs set FRIGHT_NIGHT_SAVE (e.g. "user://test_save.json") so they can
## never overwrite the player's real save; they also skip the old-save import.
var save_path: String = OS.get_environment("FRIGHT_NIGHT_SAVE") if OS.get_environment("FRIGHT_NIGHT_SAVE") != "" else SAVE_PATH
## Bump when saved data stops being compatible; older saves are ignored.
const SAVE_VERSION := 2
const STAT_POINTS_PER_LEVEL := 3
## What one stat point is worth (Damage, Durability; Defense is 1 per point).
const DAMAGE_PER_POINT := 0.5
const KNUCKLES_PER_POINT := 6.0
const SKILL_POINTS_PER_LEVEL := 1
## Caps on what upgrades, skills and gear can add (2026-10-15: dodge and
## counter windows grew too forgiving).
const MAX_DODGE_WINDOW_BONUS := 0.25
const MAX_COUNTER_WINDOW_BONUS := 0.5
const MAX_ARMOR_PIERCE := 0.75

# Each class changes how you fight. mods multiply (or add, for defense and
# combo_window) the base numbers; missing keys mean no change. Class specials
# are implemented in player.gd.
const CLASSES := {
	"berserker": {
		"name": "Berserker", "icon": "hammer",
		"fighter": "The Mauler", "color": Color(1.0, 0.42, 0.12),
		"tagline": "Takes the hit. Gives it back.",
		"traits": [["shield", "Super Armor", "Keep swinging."], ["burst", "Massive Damage", "Break bones."], ["flame", "Inferno Uppercut", "Launch them to hell."]],
		"bars": {"Power": 95, "Defense": 80, "Speed": 40, "Combo": 35, "Counter": 55},
		"desc": "Big damage, tough knuckles. Super armor eats one clean hit with no flinch and readies a counter (recharges every 8s). Hooks and uppercuts need no setup. Combos grow slower.",
		"mods": {"damage": 1.3, "knuckles": 1.25, "defense": 3.0, "combo_step": 0.6},
	},
	"counter_master": {
		"name": "Counter Master", "icon": "target",
		"fighter": "The Answer", "color": Color(0.31, 0.83, 1.0),
		"tagline": "Every attack is a question.",
		"traits": [["shield", "Perfect Defense", "Read their move."], ["target", "Counter Focus", "Turn their strength against them."], ["star", "Perfect Counter", "One hit. Game over."]],
		"bars": {"Power": 55, "Defense": 70, "Speed": 60, "Combo": 45, "Counter": 100},
		"desc": "Less damage and knuckles. Counters deal x3, dodge windows are wider, and counters have a 50% chance to cost no knuckle HP. Perfect counter: dodge, then a hook or uppercut with the matching hand KOs instantly (12s cooldown).",
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
}
## Tony: the secret fighter, playable once all four Yonker hats are collected
## (tony_unlocked). Hidden from the class picker until then.
const SECRET_CLASSES := ["wise_guy"]
const DEFAULT_CLASS := "berserker"

const RESOURCE_NAMES := {
	"coins": "Coins",
}

const STATS := {
	"damage": {"name": "Damage", "icon": "burst", "desc": "+0.5 punch damage per point"},
	"defense": {"name": "Defense", "icon": "shield", "desc": "Less knuckle damage from enemy hits"},
	"durability": {"name": "Durability", "icon": "heart", "desc": "+6 max knuckle HP per point"},
	"looting": {"name": "Looting", "icon": "coin", "desc": "+5% coins from kills per point"},
}

# Upgrade tree (bought with coins) and skill tree (bought with skill points).
# pos: cell in the tree view (x = column from center, y = row).
# requires: nodes that must be at least level 1 first.
# cost: price of level 1; each further level costs cost_growth times more.
# effects: added once per level owned.
# class: (skills only) node belongs to that class's column and only shows,
# and only counts, while playing that class.
# ring: which seal layer the node sits in (1 is open from the start; each Dead
# League win opens the next; 6 = after the Coffin King). medallion: drawn as a
# big round node (powers, capstones, trophies, ultimate nodes).

# Both trees are webs around a center node (x = columns right, y = rows down),
# with upgrade types mixed together, in five sealed rings (see Progression).
# Four Sigil nodes each unlock a power (Fire, Frost, Storm, Blood) when their
# ring opens; the nodes past a sigil upgrade that power in different ways
# (damage, duration, reach, how often it triggers).
const UPGRADES := {
	"wrapped_knuckles": {
		"name": "Taped Up", "icon": "wraps", "pos": Vector2(0, 0), "requires": [], "ring": 1,
		"desc": "Tape and cloth. Every road out of here starts with your hands.",
		"max_level": 1, "cost": 33, "cost_growth": 1.0, "effects": {"damage": 1, "max_knuckles": 5},
	},
	"dmg_1": {
		"name": "Bricks for Hands", "icon": "fist", "pos": Vector2(1, 0), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 44, "cost_growth": 1.45, "effects": {"damage": 1},
	},
	"dmg_2": {
		"name": "Iron Fists", "icon": "fist", "pos": Vector2(2, 0), "requires": ["dmg_1"], "ring": 2,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 96, "cost_growth": 1.45, "effects": {"damage": 1.2},
	},
	"dmg_3": {
		"name": "Sledge Fists", "icon": "hammer", "pos": Vector2(3, 0), "requires": ["dmg_2"], "ring": 3,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 148, "cost_growth": 1.45, "effects": {"damage": 2},
	},
	"dmg_4": {
		"name": "Wrecking Fists", "icon": "hammer", "pos": Vector2(4, 0), "requires": ["dmg_3"], "ring": 4,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 256, "cost_growth": 1.45, "effects": {"damage": 3},
	},
	"dmg_5": {
		"name": "Anvil Hands", "icon": "anvil", "pos": Vector2(5, 0), "requires": ["dmg_4"], "ring": 5,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 600, "cost_growth": 1.45, "effects": {"damage": 4},
	},
	"dmg_6": {
		"name": "Hands of the Damned", "icon": "anvil", "pos": Vector2(6, 0), "requires": ["dmg_5"], "ring": 6,
		"desc": "Every punch hits harder.",
		"max_level": 5, "cost": 1144, "cost_growth": 1.45, "effects": {"damage": 6},
	},
	"hp_1": {
		"name": "Leather Knuckles", "icon": "heart", "pos": Vector2(-1, 0), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 44, "cost_growth": 1.45, "effects": {"max_knuckles": 6},
	},
	"hp_2": {
		"name": "Rawhide", "icon": "heart_plus", "pos": Vector2(-2, 0), "requires": ["hp_1"], "ring": 2,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 96, "cost_growth": 1.45, "effects": {"max_knuckles": 9},
	},
	"hp_3": {
		"name": "Thick Skin", "icon": "heart", "pos": Vector2(-3, 0), "requires": ["hp_2"], "ring": 3,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 148, "cost_growth": 1.45, "effects": {"max_knuckles": 13},
	},
	"hp_4": {
		"name": "Iron Knuckles", "icon": "heart_plus", "pos": Vector2(-4, 0), "requires": ["hp_3"], "ring": 4,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 256, "cost_growth": 1.45, "effects": {"max_knuckles": 19},
	},
	"hp_5": {
		"name": "Grave Hide", "icon": "heartbeat", "pos": Vector2(-5, 0), "requires": ["hp_4"], "ring": 5,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 600, "cost_growth": 1.45, "effects": {"max_knuckles": 27},
	},
	"hp_6": {
		"name": "Undying Hide", "icon": "heartbeat", "pos": Vector2(-6, 0), "requires": ["hp_5"], "ring": 6,
		"desc": "More knuckle HP: every punch and hit costs some.",
		"max_level": 5, "cost": 1144, "cost_growth": 1.45, "effects": {"max_knuckles": 38},
	},
	"def_1": {
		"name": "Mouthguard", "icon": "tooth", "pos": Vector2(0, 1), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 66, "cost_growth": 1.45, "effects": {"defense": 0.6},
	},
	"def_2": {
		"name": "High Guard", "icon": "shield", "pos": Vector2(0, 2), "requires": ["def_1"], "ring": 2,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 144, "cost_growth": 1.45, "effects": {"defense": 0.8},
	},
	"def_3": {
		"name": "Ribcage Armor", "icon": "bones", "pos": Vector2(0, 3), "requires": ["def_2"], "ring": 3,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 223, "cost_growth": 1.45, "effects": {"defense": 1.2},
	},
	"def_4": {
		"name": "Bone Plating", "icon": "chestplate", "pos": Vector2(0, 4), "requires": ["def_3"], "ring": 4,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 384, "cost_growth": 1.45, "effects": {"defense": 1.7},
	},
	"def_5": {
		"name": "Tombstone Chin", "icon": "helmet", "pos": Vector2(0, 5), "requires": ["def_4"], "ring": 5,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 900, "cost_growth": 1.45, "effects": {"defense": 2.4},
	},
	"def_6": {
		"name": "Iron Coffin", "icon": "shield", "pos": Vector2(0, 6), "requires": ["def_5"], "ring": 6,
		"desc": "Hits take less knuckle HP.",
		"max_level": 5, "cost": 1716, "cost_growth": 1.45, "effects": {"defense": 3.2},
	},
	"gold_1": {
		"name": "Grave Robber", "icon": "shovel", "pos": Vector2(0, -1), "requires": ["wrapped_knuckles"], "ring": 1,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 57, "cost_growth": 1.45, "effects": {"coin_bonus": 0.05},
	},
	"gold_2": {
		"name": "Grave Tax", "icon": "bag", "pos": Vector2(0, -2), "requires": ["gold_1"], "ring": 2,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 125, "cost_growth": 1.45, "effects": {"coin_bonus": 0.06},
	},
	"gold_3": {
		"name": "Grave Gold", "icon": "chest", "pos": Vector2(0, -3), "requires": ["gold_2"], "ring": 3,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 193, "cost_growth": 1.45, "effects": {"coin_bonus": 0.07},
	},
	"gold_4": {
		"name": "Loan Shark", "icon": "bag", "pos": Vector2(0, -4), "requires": ["gold_3"], "ring": 4,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 333, "cost_growth": 1.45, "effects": {"coin_bonus": 0.08},
	},
	"gold_5": {
		"name": "Undertaker's Cut", "icon": "chest", "pos": Vector2(0, -5), "requires": ["gold_4"], "ring": 5,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 780, "cost_growth": 1.45, "effects": {"coin_bonus": 0.09},
	},
	"gold_6": {
		"name": "King's Ransom", "icon": "crown", "pos": Vector2(0, -6), "requires": ["gold_5"], "ring": 6,
		"desc": "More coins from every kill.",
		"max_level": 3, "cost": 1487, "cost_growth": 1.45, "effects": {"coin_bonus": 0.12},
	},
	"heavy_hitter": {
		"name": "Haymaker", "icon": "hammer", "pos": Vector2(2, 1), "requires": ["dmg_2"], "ring": 2,
		"desc": "Set-up hooks and uppercuts hit harder.",
		"max_level": 3, "cost": 128, "cost_growth": 1.6, "effects": {"heavy_bonus": 0.08},
	},
	"heavy_bag": {
		"name": "Rib Shot", "icon": "gut", "pos": Vector2(2, 2), "requires": ["heavy_hitter"], "ring": 3,
		"desc": "Set-up heavies cave things in.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"heavy_bonus": 0.12},
	},
	"counterpuncher": {
		"name": "Counterpuncher", "icon": "counter_arrow", "pos": Vector2(3, 1), "requires": ["dmg_3"], "ring": 3,
		"desc": "Counters hit harder.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"counter_bonus": 0.2},
	},
	"return_fire": {
		"name": "Return Fire", "icon": "counter_arrow", "pos": Vector2(3, 2), "requires": ["counterpuncher"], "ring": 4,
		"desc": "Counters hit much harder.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"counter_bonus": 0.3},
	},
	"armor_breaker": {
		"name": "Can Opener", "icon": "broken_shield", "pos": Vector2(4, 1), "requires": ["dmg_4"], "ring": 4,
		"desc": "Punch straight through enemy armor.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"armor_pierce": 0.15},
	},
	"giant_killer": {
		"name": "Bigger They Fall", "icon": "crown", "pos": Vector2(4, 2), "requires": ["armor_breaker"], "ring": 5,
		"desc": "Bosses and champions take extra damage.",
		"max_level": 3, "cost": 690, "cost_growth": 1.6, "effects": {"boss_damage": 0.15},
	},
	"weighted_wraps": {
		"name": "Lead Tape", "icon": "dumbbell", "pos": Vector2(5, 1), "requires": ["dmg_5"], "ring": 5,
		"desc": "Hooks and uppercuts cost less knuckle HP.",
		"max_level": 1, "cost": 690, "cost_growth": 1.0, "effects": {"heavy_cost_cut": 1},
	},
	"lucky_shot": {
		"name": "Lucky Shot", "icon": "star", "pos": Vector2(3, -1), "requires": ["dmg_3"], "ring": 3,
		"desc": "Some punches land just right: critical hits.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"crit_chance": 0.04},
	},
	"dirty_shot": {
		"name": "Dirty Shot", "icon": "slash", "pos": Vector2(3, -2), "requires": ["lucky_shot"], "ring": 4,
		"desc": "Even more critical hits.",
		"max_level": 2, "cost": 304, "cost_growth": 1.6, "effects": {"crit_chance": 0.04},
	},
	"glass_breaker": {
		"name": "Glass Breaker", "icon": "burst", "pos": Vector2(3, -3), "requires": ["dirty_shot"], "ring": 4,
		"desc": "Critical hits hit even harder.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"crit_damage": 0.25},
	},
	"sigil_fire": {
		"name": "Hellfire", "icon": "flame", "pos": Vector2(2, -1), "requires": ["dmg_2"], "ring": 2, "medallion": true,
		"desc": "Awakens FIRE: set-up heavies and counters burst into flame.",
		"max_level": 1, "cost": 320, "cost_growth": 1.0, "effects": {"fire_punch": 0.3, "burn": 0.25},
	},
	"hotter_flames": {
		"name": "Brimstone", "icon": "thermometer", "pos": Vector2(2, -2), "requires": ["sigil_fire"], "ring": 2,
		"desc": "Bigger fire bursts.",
		"max_level": 3, "cost": 128, "cost_growth": 1.6, "effects": {"fire_punch": 0.2},
	},
	"lingering_flames": {
		"name": "Slow Burn", "icon": "clock", "pos": Vector2(2, -3), "requires": ["hotter_flames"], "ring": 3,
		"desc": "Burns last longer.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"burn_time": 1.5},
	},
	"searing": {
		"name": "Scorch", "icon": "burst", "pos": Vector2(2, -4), "requires": ["lingering_flames"], "ring": 3,
		"desc": "Burns hurt more.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"burn": 0.2},
	},
	"kindling": {
		"name": "Firestarter", "icon": "match", "pos": Vector2(2, -5), "requires": ["searing"], "ring": 4,
		"desc": "Any punch can burst into flame.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"fire_chance": 0.06},
	},
	"wildfire": {
		"name": "Wildfire", "icon": "ripple", "pos": Vector2(2, -6), "requires": ["kindling"], "ring": 4,
		"desc": "Fire spreads farther.",
		"max_level": 2, "cost": 304, "cost_growth": 1.6, "effects": {"fire_radius": 1.0},
	},
	"pyre": {
		"name": "Pyre", "icon": "pyre", "pos": Vector2(2, -7), "requires": ["wildfire"], "ring": 6, "medallion": true,
		"desc": "Burning enemies explode when they die.",
		"max_level": 1, "cost": 1980, "cost_growth": 1.0, "effects": {"pyre": 1},
	},
	"sigil_storm": {
		"name": "Thunderclap", "icon": "bolt", "pos": Vector2(4, -1), "requires": ["dmg_4"], "ring": 4, "medallion": true,
		"desc": "Awakens STORM: combos arc lightning.",
		"max_level": 1, "cost": 608, "cost_growth": 1.0, "effects": {"chain_lightning": 2},
	},
	"forked": {
		"name": "Forked Lightning", "icon": "fork", "pos": Vector2(4, -2), "requires": ["sigil_storm"], "ring": 4,
		"desc": "Lightning jumps to one more enemy.",
		"max_level": 2, "cost": 304, "cost_growth": 1.6, "effects": {"chain_lightning": 1},
	},
	"overcharge": {
		"name": "Overcharge", "icon": "battery", "pos": Vector2(4, -3), "requires": ["forked"], "ring": 4,
		"desc": "Lightning hits harder.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"chain_damage": 0.15},
	},
	"static_shock": {
		"name": "Static Shock", "icon": "spark", "pos": Vector2(4, -4), "requires": ["overcharge"], "ring": 4,
		"desc": "Lightning staggers.",
		"max_level": 1, "cost": 304, "cost_growth": 1.0, "effects": {"chain_stun": 1},
	},
	"conductor": {
		"name": "Lightning Rod", "icon": "magnet", "pos": Vector2(4, -5), "requires": ["static_shock"], "ring": 5,
		"desc": "Every counter arcs lightning.",
		"max_level": 1, "cost": 690, "cost_growth": 1.0, "effects": {"chain_on_counter": 1},
	},
	"storm": {
		"name": "Perfect Storm", "icon": "storm", "pos": Vector2(4, -6), "requires": ["conductor"], "ring": 5,
		"desc": "Lightning comes every 4th combo hit.",
		"max_level": 1, "cost": 690, "cost_growth": 1.0, "effects": {"chain_every_cut": 1},
	},
	"thunderhead": {
		"name": "Thunderhead", "icon": "thunderhead", "pos": Vector2(4, -7), "requires": ["storm"], "ring": 6, "medallion": true,
		"desc": "Clean dodges call lightning on the attacker.",
		"max_level": 1, "cost": 1980, "cost_growth": 1.0, "effects": {"thunderhead": 1},
	},
	"ice_bath": {
		"name": "Ice Bath", "icon": "bucket", "pos": Vector2(-2, -1), "requires": ["hp_2"], "ring": 2,
		"desc": "Recover a little every tenth of the bout.",
		"max_level": 2, "cost": 128, "cost_growth": 1.6, "effects": {"wave_heal": 1},
	},
	"iron_will": {
		"name": "Chin Check", "icon": "anchor", "pos": Vector2(-2, 1), "requires": ["hp_2"], "ring": 2,
		"desc": "Shake off clean hits faster.",
		"max_level": 2, "cost": 128, "cost_growth": 1.6, "effects": {"flinch_reduction": 0.15},
	},
	"calloused": {
		"name": "Calloused", "icon": "tape", "pos": Vector2(-3, -1), "requires": ["hp_3"], "ring": 3,
		"desc": "Some punches don't hurt your hands at all.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"free_punch_chance": 0.05},
	},
	"thick_skull": {
		"name": "Thick Skull", "icon": "helmet", "pos": Vector2(-3, 1), "requires": ["hp_3"], "ring": 3,
		"desc": "Grazes (right timing, wrong dodge) hurt less.",
		"max_level": 2, "cost": 189, "cost_growth": 1.6, "effects": {"graze_reduction": 0.15},
	},
	"second_wind": {
		"name": "Second Wind", "icon": "wind", "pos": Vector2(-4, -1), "requires": ["hp_4"], "ring": 4,
		"desc": "Recover more every tenth of the bout.",
		"max_level": 2, "cost": 304, "cost_growth": 1.6, "effects": {"wave_heal": 1},
	},
	"sigil_blood": {
		"name": "Blood Moon", "icon": "drop", "pos": Vector2(-5, -1), "requires": ["hp_5"], "ring": 5, "medallion": true,
		"desc": "Awakens BLOOD: every kill heals you.",
		"max_level": 1, "cost": 1380, "cost_growth": 1.0, "effects": {"heal_on_kill": 1},
	},
	"vampiric_knuckles": {
		"name": "Bloodsucker", "icon": "fang", "pos": Vector2(-5, -2), "requires": ["sigil_blood"], "ring": 5,
		"desc": "Kills heal more.",
		"max_level": 3, "cost": 690, "cost_growth": 1.6, "effects": {"heal_on_kill": 0.5},
	},
	"bloodletting": {
		"name": "Bloodletting", "icon": "heartbeat", "pos": Vector2(-5, -3), "requires": ["vampiric_knuckles"], "ring": 5,
		"desc": "Counters heal you.",
		"max_level": 3, "cost": 690, "cost_growth": 1.6, "effects": {"counter_heal": 0.5},
	},
	"blood_rage": {
		"name": "Seeing Red", "icon": "blood_burst", "pos": Vector2(-5, -4), "requires": ["bloodletting"], "ring": 5,
		"desc": "The closer you are to dropping, the harder you hit.",
		"max_level": 3, "cost": 690, "cost_growth": 1.6, "effects": {"last_stand": 0.15},
	},
	"bloodbath": {
		"name": "Bloodbath", "icon": "bloodbath", "pos": Vector2(-5, -5), "requires": ["blood_rage"], "ring": 6, "medallion": true,
		"desc": "Healing doubled under half knuckle HP.",
		"max_level": 1, "cost": 1980, "cost_growth": 1.0, "effects": {"bloodbath": 1},
	},
	"cornerman": {
		"name": "Cornerman", "icon": "medkit", "pos": Vector2(-1, 1), "requires": ["def_1"], "ring": 1,
		"desc": "Recover a little every tenth of the bout.",
		"max_level": 3, "cost": 66, "cost_growth": 1.6, "effects": {"wave_heal": 1},
	},
	"footwork_drills": {
		"name": "Jump Rope", "icon": "footprints", "pos": Vector2(1, 1), "requires": ["def_1"], "ring": 1,
		"desc": "A touch more time to dodge.",
		"max_level": 2, "cost": 66, "cost_growth": 1.6, "effects": {"dodge_window": 0.04},
	},
	"bob_and_weave": {
		"name": "Bob and Weave", "icon": "slip", "pos": Vector2(1, 2), "requires": ["def_2"], "ring": 2,
		"desc": "A little longer to land a counter.",
		"max_level": 2, "cost": 128, "cost_growth": 1.6, "effects": {"counter_window": 0.1},
	},
	"rope_a_dope": {
		"name": "Rope-a-Dope", "icon": "anchor", "pos": Vector2(1, 4), "requires": ["def_4"], "ring": 4,
		"desc": "Grazes hurt less.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"graze_reduction": 0.1},
	},
	"sigil_frost": {
		"name": "Deathchill", "icon": "snowflake", "pos": Vector2(1, 3), "requires": ["def_3"], "ring": 3, "medallion": true,
		"desc": "Awakens FROST: set-up heavies and counters freeze.",
		"max_level": 1, "cost": 378, "cost_growth": 1.0, "effects": {"frost_punch": 0.4},
	},
	"deep_freeze": {
		"name": "Deep Freeze", "icon": "shard", "pos": Vector2(2, 3), "requires": ["sigil_frost"], "ring": 3,
		"desc": "Frozen enemies are slower.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"frost_punch": 0.1},
	},
	"permafrost": {
		"name": "Permafrost", "icon": "hourglass", "pos": Vector2(3, 3), "requires": ["deep_freeze"], "ring": 3,
		"desc": "Freezes last longer.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"frost_time": 1.0},
	},
	"frost_nova": {
		"name": "Frost Nova", "icon": "nova", "pos": Vector2(4, 3), "requires": ["permafrost"], "ring": 3,
		"desc": "Freezes reach farther.",
		"max_level": 2, "cost": 189, "cost_growth": 1.6, "effects": {"frost_radius": 1.0},
	},
	"brittle": {
		"name": "Brittle Bones", "icon": "broken_shield", "pos": Vector2(5, 3), "requires": ["frost_nova"], "ring": 4,
		"desc": "Frozen enemies take extra damage from everything.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"brittle": 0.1},
	},
	"cold_snap": {
		"name": "Cold Snap", "icon": "icicle", "pos": Vector2(6, 3), "requires": ["brittle"], "ring": 4,
		"desc": "Any punch can freeze.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"frost_chance": 0.08},
	},
	"frost_shatter": {
		"name": "Shatter", "icon": "shatter", "pos": Vector2(7, 3), "requires": ["cold_snap"], "ring": 6, "medallion": true,
		"desc": "Frozen enemies burst into frost when they die.",
		"max_level": 1, "cost": 1980, "cost_growth": 1.0, "effects": {"frost_shatter": 1},
	},
	"bellmans_bell": {
		"name": "The Bellman's Bell", "icon": "belt", "pos": Vector2(-1, 2), "requires": ["def_2"], "ring": 2, "medallion": true,
		"desc": "Trophy: it still rings when you hit things.",
		"max_level": 3, "cost": 205, "cost_growth": 1.6, "effects": {"damage": 1.5, "max_knuckles": 10},
	},
	"headless_helm": {
		"name": "Headless Helm", "icon": "helmet", "pos": Vector2(-1, 3), "requires": ["def_3"], "ring": 3, "medallion": true,
		"desc": "Trophy: no head, no problem.",
		"max_level": 3, "cost": 302, "cost_growth": 1.6, "effects": {"damage": 2, "max_knuckles": 15, "defense": 1},
	},
	"southpaws_rosary": {
		"name": "Southpaw's Veil", "icon": "medal", "pos": Vector2(-1, 4), "requires": ["def_4"], "ring": 4, "medallion": true,
		"desc": "Trophy: a little of her left hand, now yours.",
		"max_level": 3, "cost": 486, "cost_growth": 1.6, "effects": {"damage": 3, "max_knuckles": 20, "defense": 1.5},
	},
	"plague_censer": {
		"name": "Plague Censer", "icon": "bucket", "pos": Vector2(-1, 5), "requires": ["def_5"], "ring": 5, "medallion": true,
		"desc": "Trophy: the cure smells terrible.",
		"max_level": 3, "cost": 1104, "cost_growth": 1.6, "effects": {"damage": 4, "max_knuckles": 30, "defense": 2},
	},
	"coffin_crown": {
		"name": "The Coffin Crown", "icon": "crown", "pos": Vector2(-1, 6), "requires": ["def_6"], "ring": 6, "medallion": true,
		"desc": "Trophy: heavy is the head. Raw power for the endless dark.",
		"max_level": 5, "cost": 3168, "cost_growth": 1.6, "effects": {"damage": 5, "max_knuckles": 40, "defense": 3},
	},
	"sparring_partner": {
		"name": "Sparring Partner", "icon": "crossed_gloves", "pos": Vector2(1, -1), "requires": ["gold_1"], "ring": 1,
		"desc": "Learn faster: more XP.",
		"max_level": 3, "cost": 66, "cost_growth": 1.6, "effects": {"xp_bonus": 0.1},
	},
	"light_feet": {
		"name": "Twinkle Toes", "icon": "chevrons", "pos": Vector2(-1, -1), "requires": ["gold_1"], "ring": 1,
		"desc": "Faster on your feet.",
		"max_level": 2, "cost": 66, "cost_growth": 1.6, "effects": {"move_speed": 0.05},
	},
	"running_shoes": {
		"name": "Cemetery Sprint", "icon": "wing_boot", "pos": Vector2(1, -2), "requires": ["gold_2"], "ring": 2,
		"desc": "Faster sprinting.",
		"max_level": 2, "cost": 128, "cost_growth": 1.6, "effects": {"sprint_bonus": 0.1},
	},
	"quick_wraps": {
		"name": "Snap Wraps", "icon": "fast_fist", "pos": Vector2(-1, -2), "requires": ["gold_2"], "ring": 2,
		"desc": "Lighter wraps for faster hands.",
		"max_level": 3, "cost": 128, "cost_growth": 1.6, "effects": {"punch_speed": 0.04},
	},
	"bounty": {
		"name": "Crowd Pleaser", "icon": "wanted", "pos": Vector2(1, -3), "requires": ["gold_3"], "ring": 3,
		"desc": "Bigger milestone bonuses in the Arena.",
		"max_level": 2, "cost": 189, "cost_growth": 1.6, "effects": {"wave_bonus": 0.25},
	},
	"rhythm": {
		"name": "Speed Bag", "icon": "note", "pos": Vector2(-1, -3), "requires": ["gold_3"], "ring": 3,
		"desc": "Combos build faster.",
		"max_level": 3, "cost": 189, "cost_growth": 1.6, "effects": {"combo_step": 0.05},
	},
	"night_owl": {
		"name": "Film Study", "icon": "moon", "pos": Vector2(1, -4), "requires": ["gold_4"], "ring": 4,
		"desc": "Learn from every fight: more XP.",
		"max_level": 3, "cost": 304, "cost_growth": 1.6, "effects": {"xp_bonus": 0.15},
	},
	"dawn_patrol": {
		"name": "Prize Fighter", "icon": "sun", "pos": Vector2(1, -5), "requires": ["gold_5"], "ring": 5,
		"desc": "Bigger Arena purses.",
		"max_level": 2, "cost": 690, "cost_growth": 1.6, "effects": {"dawn_bonus": 0.25},
	},
}

const SKILL_TREES := {
	"berserker": {
		"fury": {
			"name": "Fury", "icon": "horns", "pos": Vector2(0, 0), "requires": [],
			"desc": "The Mauler's heart. Every path starts here.",
			"max_level": 1, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.02, "knuckles_percent": 0.02},
		},
		"sledgehammer": {
			"name": "Sledgehammer", "icon": "hammer", "pos": Vector2(1, 0), "requires": ["fury"],
			"desc": "Everything you throw lands heavier.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.02},
		},
		"rib_breaker": {
			"name": "Rib Breaker", "icon": "gut", "pos": Vector2(2, 0), "requires": ["sledgehammer"],
			"desc": "Hooks and uppercuts cave things in.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"heavy_bonus": 0.08},
		},
		"lights_out": {
			"name": "Lights Out", "icon": "skull", "pos": Vector2(3, 0), "requires": ["rib_breaker"],
			"desc": "Hurt things die faster around you.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"finisher_bonus": 0.24},
		},
		"wrecking_ball": {
			"name": "Wrecking Ball", "icon": "anvil", "pos": Vector2(4, 0), "requires": ["lights_out"], "ring": 2, "medallion": true,
			"desc": "Hooks and uppercuts hit like a falling piano.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"heavy_bonus": 0.17, "damage_percent": 0.03},
		},
		"thick_hide": {
			"name": "Thick Hide", "icon": "heart", "pos": Vector2(-1, 0), "requires": ["fury"],
			"desc": "More meat between you and the floor.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"knuckles_percent": 0.03},
		},
		"iron_jaw": {
			"name": "Iron Jaw", "icon": "tooth", "pos": Vector2(-2, 0), "requires": ["thick_hide"],
			"desc": "Clean hits barely move you.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"flinch_reduction": 0.16},
		},
		"bloodthirst": {
			"name": "Bloodthirst", "icon": "fang", "pos": Vector2(-3, 0), "requires": ["iron_jaw"],
			"desc": "Every kill patches you up.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"heal_on_kill": 0.75},
		},
		"juggernaut": {
			"name": "Juggernaut", "icon": "chestplate", "pos": Vector2(-4, 0), "requires": ["bloodthirst"], "ring": 4, "medallion": true,
			"desc": "Super armor holds an extra hit, and hits it soaks hurt half as much.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"armor_charges": 1, "armor_absorb_reduction": 0.34},
		},
		"short_fuse": {
			"name": "Short Fuse", "icon": "clock", "pos": Vector2(0, -1), "requires": ["fury"],
			"desc": "Super armor comes back sooner.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"armor_recharge_cut": 0.5},
		},
		"unbreakable": {
			"name": "Unbreakable", "icon": "shield", "pos": Vector2(0, -2), "requires": ["short_fuse"],
			"desc": "Super armor holds more hits before it breaks.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"armor_charges": 1},
		},
		"payback": {
			"name": "Payback", "icon": "counter_arrow", "pos": Vector2(0, -3), "requires": ["unbreakable"],
			"desc": "Hit back harder after super armor eats a punch.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"retaliation_bonus": 0.61},
		},
		"berserk": {
			"name": "Berserk", "icon": "rage", "pos": Vector2(0, -4), "requires": ["payback"], "ring": 6, "medallion": true,
			"desc": "The closer you are to dropping, the harder you hit.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"last_stand": 0.21},
		},
		"fury_surge": {
			"name": "Ultimate Surge", "icon": "spark", "pos": Vector2(1, 1), "requires": ["fury"], "ring": 3, "medallion": true,
			"desc": "Your ultimate meter fills 25% faster.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"ult_gain": 0.25},
		},
		"fury_ult_power": {
			"name": "Inferno II", "icon": "flame", "pos": Vector2(-1, 1), "requires": ["fury"], "ring": 5, "medallion": true,
			"desc": "Ultimate: the Inferno Uppercut hits 50% harder, reaches farther and burns longer.",
			"max_level": 1, "cost": 3, "cost_growth": 1.0, "effects": {"ult_power": 1},
		},
	},
	"counter_master": {
		"read_the_fight": {
			"name": "Read the Fight", "icon": "eye", "pos": Vector2(0, 0), "requires": [],
			"desc": "The Answer's eye. Every path starts here.",
			"max_level": 1, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.02, "counter_window": 0.1},
		},
		"counterpunch": {
			"name": "Counterpunch", "icon": "counter_arrow", "pos": Vector2(1, 0), "requires": ["read_the_fight"],
			"desc": "Counters hit harder.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"counter_bonus": 0.19},
		},
		"cold_blood": {
			"name": "Cold Blood", "icon": "snowflake", "pos": Vector2(2, 0), "requires": ["counterpunch"],
			"desc": "Calm hands. Heavy hands.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.04},
		},
		"precision_strike": {
			"name": "Precision Strike", "icon": "crosshair", "pos": Vector2(3, 0), "requires": ["cold_blood"],
			"desc": "Perfect counters work with any punch from the matching hand, not just hooks and uppercuts.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"perfect_any_punch": 1},
		},
		"executioner": {
			"name": "Executioner", "icon": "axe", "pos": Vector2(4, 0), "requires": ["precision_strike"], "ring": 2, "medallion": true,
			"desc": "Perfect counters cut a big chunk out of bosses.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"boss_ko_bonus": 0.1},
		},
		"ghost": {
			"name": "Ghost", "icon": "ghost", "pos": Vector2(-1, 0), "requires": ["read_the_fight"],
			"desc": "A little more time to get out of the way.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"dodge_window": 0.02},
		},
		"thick_skull": {
			"name": "Thick Skull", "icon": "helmet", "pos": Vector2(-2, 0), "requires": ["ghost"],
			"desc": "Grazes (right timing, wrong dodge) hurt less.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"graze_reduction": 0.2},
		},
		"iron_chin": {
			"name": "Iron Chin", "icon": "heart", "pos": Vector2(-3, 0), "requires": ["thick_skull"],
			"desc": "More knuckle HP.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"knuckles_percent": 0.1},
		},
		"free_flow": {
			"name": "Free Flow", "icon": "flow", "pos": Vector2(-4, 0), "requires": ["iron_chin"], "ring": 4, "medallion": true,
			"desc": "Counters often cost no knuckle HP, and you can take more.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"counter_free_bonus": 0.34, "knuckles_percent": 0.07},
		},
		"perfect_timing": {
			"name": "Perfect Timing", "icon": "stopwatch", "pos": Vector2(0, -1), "requires": ["read_the_fight"],
			"desc": "Perfect counters come back sooner.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"perfect_cooldown_cut": 1.0},
		},
		"patience": {
			"name": "Patience", "icon": "hourglass", "pos": Vector2(0, -2), "requires": ["perfect_timing"],
			"desc": "A little longer to land your counter after a dodge.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"counter_window": 0.15},
		},
		"snap_back": {
			"name": "Snap Back", "icon": "fast_fist", "pos": Vector2(0, -3), "requires": ["patience"],
			"desc": "Faster hands to punish with.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"punch_speed": 0.06},
		},
		"checkmate": {
			"name": "Checkmate", "icon": "crown", "pos": Vector2(0, -4), "requires": ["snap_back"], "ring": 6, "medallion": true,
			"desc": "Counters become the whole fight.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"counter_bonus": 0.69, "damage_percent": 0.06},
		},
		"read_the_fight_surge": {
			"name": "Ultimate Surge", "icon": "spark", "pos": Vector2(1, 1), "requires": ["read_the_fight"], "ring": 3, "medallion": true,
			"desc": "Your ultimate meter fills 25% faster.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"ult_gain": 0.25},
		},
		"read_the_fight_ult_power": {
			"name": "Riposte II", "icon": "counter_arrow", "pos": Vector2(-1, 1), "requires": ["read_the_fight"], "ring": 5, "medallion": true,
			"desc": "Ultimate: Riposte Stance lasts 2 seconds longer.",
			"max_level": 1, "cost": 3, "cost_growth": 1.0, "effects": {"ult_power": 1},
		},
	},
	"combo_master": {
		"flow_state": {
			"name": "Flow State", "icon": "wave", "pos": Vector2(0, 0), "requires": [],
			"desc": "The Blur's rhythm. Every path starts here.",
			"max_level": 1, "cost": 1, "cost_growth": 1.0, "effects": {"combo_window": 0.12, "punch_speed": 0.02},
		},
		"fast_hands": {
			"name": "Fast Hands", "icon": "fast_fist", "pos": Vector2(1, 0), "requires": ["flow_state"],
			"desc": "Faster punches.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"punch_speed": 0.02},
		},
		"flow": {
			"name": "Build-Up", "icon": "chevrons", "pos": Vector2(2, 0), "requires": ["fast_hands"],
			"desc": "Combos build faster.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"combo_step": 0.03},
		},
		"double_jab": {
			"name": "Triple Jab", "icon": "double_fist", "pos": Vector2(3, 0), "requires": ["flow"],
			"desc": "Jab, jab, jab keeps the combo going, and every punch hits a bit harder.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"double_jab": 1, "damage_percent": 0.04},
		},
		"thousand_fists": {
			"name": "Thousand Fists", "icon": "infinity", "pos": Vector2(4, 0), "requires": ["double_jab"], "ring": 2, "medallion": true,
			"desc": "Even faster hands, and combos climb even quicker.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"punch_speed": 0.07, "combo_step": 0.03},
		},
		"endurance": {
			"name": "Endurance", "icon": "heartbeat", "pos": Vector2(-1, 0), "requires": ["flow_state"],
			"desc": "More knuckle HP.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"knuckles_percent": 0.03},
		},
		"hard_knuckles": {
			"name": "Hard Knuckles", "icon": "brass", "pos": Vector2(-2, 0), "requires": ["endurance"],
			"desc": "Some punches don't hurt your hands at all.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"free_punch_chance": 0.08},
		},
		"iron_jaw": {
			"name": "Iron Jaw", "icon": "tooth", "pos": Vector2(-3, 0), "requires": ["hard_knuckles"],
			"desc": "Clean hits barely slow you down.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"flinch_reduction": 0.32},
		},
		"second_wind": {
			"name": "Second Wind", "icon": "wind", "pos": Vector2(-4, 0), "requires": ["iron_jaw"], "ring": 4, "medallion": true,
			"desc": "Catch your breath as the bout goes on, and take more.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"wave_heal": 2.0, "knuckles_percent": 0.07},
		},
		"wide_wave": {
			"name": "Wide Wave", "icon": "ripple", "pos": Vector2(0, -1), "requires": ["flow_state"],
			"desc": "Shockwaves reach farther.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"shockwave_radius": 0.5},
		},
		"rolling_thunder": {
			"name": "Rolling Thunder", "icon": "quake", "pos": Vector2(0, -2), "requires": ["wide_wave"],
			"desc": "Shockwaves hit everything they stun.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"shockwave_damage": 0.75},
		},
		"aftershock": {
			"name": "Aftershock", "icon": "spiral", "pos": Vector2(0, -3), "requires": ["rolling_thunder"],
			"desc": "Shockwaves stun for longer.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"shockwave_stun": 0.5},
		},
		"flurry": {
			"name": "Flurry", "icon": "storm", "pos": Vector2(0, -4), "requires": ["aftershock"], "ring": 6, "medallion": true,
			"desc": "A shockwave every 4th combo hit instead of every 5th, and they hit harder.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"shockwave_every_cut": 1, "shockwave_damage": 0.75},
		},
		"flow_state_surge": {
			"name": "Ultimate Surge", "icon": "spark", "pos": Vector2(1, 1), "requires": ["flow_state"], "ring": 3, "medallion": true,
			"desc": "Your ultimate meter fills 25% faster.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"ult_gain": 0.25},
		},
		"flow_state_ult_power": {
			"name": "Temporal Break II", "icon": "hourglass", "pos": Vector2(-1, 1), "requires": ["flow_state"], "ring": 5, "medallion": true,
			"desc": "Ultimate: Temporal Break starts with 1.5 more seconds on the clock.",
			"max_level": 1, "cost": 3, "cost_growth": 1.0, "effects": {"ult_power": 1},
		},
	},
	"free_runner": {
		"light_step": {
			"name": "Light Step", "icon": "feather", "pos": Vector2(0, 0), "requires": [],
			"desc": "The Stray's stride. Every path starts here.",
			"max_level": 1, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.02, "move_speed": 0.03, "sprint_bonus": 0.03},
		},
		"momentum": {
			"name": "Momentum", "icon": "chevrons", "pos": Vector2(1, 0), "requires": ["light_step"],
			"desc": "Dash punches (Spear Jab and Haymaker) hit even harder.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"opener_bonus": 0.19},
		},
		"opportunist": {
			"name": "Opportunist", "icon": "target", "pos": Vector2(2, 0), "requires": ["momentum"],
			"desc": "Hurt things die faster around you.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"finisher_bonus": 0.1},
		},
		"cheap_shot": {
			"name": "Cheap Shot", "icon": "slash", "pos": Vector2(3, 0), "requires": ["opportunist"],
			"desc": "Fight dirty. Everything hits harder.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"damage_percent": 0.08},
		},
		"blindside": {
			"name": "Blindside", "icon": "dive", "pos": Vector2(4, 0), "requires": ["cheap_shot"], "ring": 2, "medallion": true,
			"desc": "Dash punches land like a truck, and so does everything else.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"opener_bonus": 0.34, "damage_percent": 0.07},
		},
		"rubber_legs": {
			"name": "Rubber Legs", "icon": "heart", "pos": Vector2(-1, 0), "requires": ["light_step"],
			"desc": "More knuckle HP.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"knuckles_percent": 0.03},
		},
		"slick": {
			"name": "Slick", "icon": "slip", "pos": Vector2(-2, 0), "requires": ["rubber_legs"],
			"desc": "A little more time to get out of the way.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"dodge_window": 0.03},
		},
		"hard_knuckles": {
			"name": "Hard Knuckles", "icon": "brass", "pos": Vector2(-3, 0), "requires": ["slick"],
			"desc": "Some punches don't hurt your hands at all.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"free_punch_chance": 0.12},
		},
		"ghost_step": {
			"name": "Ghost Step", "icon": "ghost", "pos": Vector2(-4, 0), "requires": ["hard_knuckles"], "ring": 4, "medallion": true,
			"desc": "Grazes barely touch you, and you can take more.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"graze_reduction": 0.34, "knuckles_percent": 0.07},
		},
		"stride": {
			"name": "Stride", "icon": "wing_boot", "pos": Vector2(0, -1), "requires": ["light_step"],
			"desc": "Faster on your feet, faster sprinting.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"sprint_bonus": 0.04, "move_speed": 0.01},
		},
		"acrobat": {
			"name": "Acrobat", "icon": "wing", "pos": Vector2(0, -2), "requires": ["stride"],
			"desc": "Higher jumps: more time for jump punches.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"jump_bonus": 0.1},
		},
		"high_ground": {
			"name": "High Ground", "icon": "mountain", "pos": Vector2(0, -3), "requires": ["acrobat"],
			"desc": "Jump punch finishers work on healthier enemies.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"finisher_threshold": 0.12},
		},
		"dive_kick": {
			"name": "Dive Kick", "icon": "dive", "pos": Vector2(0, -4), "requires": ["high_ground"], "ring": 6, "medallion": true,
			"desc": "Jump punches stagger whatever they hit, and everything hits harder.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"dive_kick": 1, "damage_percent": 0.07},
		},
		"light_step_surge": {
			"name": "Ultimate Surge", "icon": "spark", "pos": Vector2(1, 1), "requires": ["light_step"], "ring": 3, "medallion": true,
			"desc": "Your ultimate meter fills 25% faster.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"ult_gain": 0.25},
		},
		"light_step_ult_power": {
			"name": "Highlight Reel II", "icon": "bolt", "pos": Vector2(-1, 1), "requires": ["light_step"], "ring": 5, "medallion": true,
			"desc": "Ultimate: the Highlight Reel hits 3 more enemies, 30% harder.",
			"max_level": 1, "cost": 3, "cost_growth": 1.0, "effects": {"ult_power": 1},
		},
	},
	"wise_guy": {
		"wise_guy": {
			"name": "Wise Guy", "icon": "rage", "pos": Vector2(0, 0), "requires": [],
			"desc": "Tony's attitude. Every path starts here.",
			"max_level": 1, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.02, "knuckles_percent": 0.02},
		},
		"heavy_hands": {
			"name": "Heavy Hands", "icon": "fist", "pos": Vector2(1, 0), "requires": ["wise_guy"],
			"desc": "Hooks and uppercuts hit harder.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"heavy_bonus": 0.06},
		},
		"knuckle_sandwich": {
			"name": "Knuckle Sandwich", "icon": "burst", "pos": Vector2(2, 0), "requires": ["heavy_hands"],
			"desc": "Everything hits harder. Extra mustard.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"damage_percent": 0.04},
		},
		"last_word": {
			"name": "Last Word", "icon": "skull", "pos": Vector2(3, 0), "requires": ["knuckle_sandwich"],
			"desc": "Hurt things die faster around you.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"finisher_bonus": 0.24},
		},
		"bada_bing": {
			"name": "Bada Bing", "icon": "hammer", "pos": Vector2(4, 0), "requires": ["last_word"], "ring": 2, "medallion": true,
			"desc": "Hooks and uppercuts land like a cement shoe.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"heavy_bonus": 0.17, "damage_percent": 0.03},
		},
		"tough_guy": {
			"name": "Tough Guy", "icon": "heart", "pos": Vector2(-1, 0), "requires": ["wise_guy"],
			"desc": "More knuckle HP.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"knuckles_percent": 0.03},
		},
		"shrug_it_off": {
			"name": "Shrug It Off", "icon": "shield", "pos": Vector2(-2, 0), "requires": ["tough_guy"],
			"desc": "Fuggedaboudit comes back faster.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"fugget_cut": 1.5},
		},
		"deli_run": {
			"name": "Deli Run", "icon": "medkit", "pos": Vector2(-3, 0), "requires": ["shrug_it_off"],
			"desc": "Every KO, a little sandwich.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"heal_on_kill": 0.75},
		},
		"made_man": {
			"name": "Made Man", "icon": "crown", "pos": Vector2(-4, 0), "requires": ["deli_run"], "ring": 4, "medallion": true,
			"desc": "Fuggedaboudit patches you up, and you can take more.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"fugget_heal": 0.07, "knuckles_percent": 0.07},
		},
		"trash_talk": {
			"name": "Trash Talk", "icon": "note", "pos": Vector2(0, -1), "requires": ["wise_guy"],
			"desc": "Insulted monsters stay mad longer.",
			"max_level": 3, "cost": 1, "cost_growth": 1.0, "effects": {"insult_time": 0.5},
		},
		"below_the_belt": {
			"name": "Below the Belt", "icon": "gut", "pos": Vector2(0, -2), "requires": ["trash_talk"],
			"desc": "Hit insulted monsters even harder.",
			"max_level": 2, "cost": 1, "cost_growth": 1.0, "effects": {"wise_up": 0.13},
		},
		"hustle": {
			"name": "Hustle", "icon": "bag", "pos": Vector2(0, -3), "requires": ["below_the_belt"],
			"desc": "Insulted monsters pay out more coins.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"hustle": 0.81},
		},
		"say_it_to_my_face": {
			"name": "Say It To My Face", "icon": "counter_arrow", "pos": Vector2(0, -4), "requires": ["hustle"], "ring": 6, "medallion": true,
			"desc": "Insulted monsters take a beating, and so does anyone you counter.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"wise_up": 0.28, "counter_bonus": 0.34},
		},
		"wise_guy_surge": {
			"name": "Ultimate Surge", "icon": "spark", "pos": Vector2(1, 1), "requires": ["wise_guy"], "ring": 3, "medallion": true,
			"desc": "Your ultimate meter fills 25% faster.",
			"max_level": 1, "cost": 2, "cost_growth": 1.0, "effects": {"ult_gain": 0.25},
		},
		"wise_guy_ult_power": {
			"name": "Big Mouth II", "icon": "rage", "pos": Vector2(-1, 1), "requires": ["wise_guy"], "ring": 5, "medallion": true,
			"desc": "Ultimate: Big Mouth enrages a second monster, and the duel lasts 3s longer.",
			"max_level": 1, "cost": 3, "cost_growth": 1.0, "effects": {"ult_power": 1},
		},
	},
}

# How each effect reads in the UI. Percent effects are stored as fractions.
const EFFECT_FORMATS := {
	"insult_time": "Enraged monsters stay mad %ss longer",
	"wise_up": "+%s%% damage to enraged monsters",
	"fugget_cut": "Fuggedaboudit recharges %ss faster",
	"fugget_heal": "Fuggedaboudit restores %s%% knuckle HP",
	"hustle": "+%s%% coins from enraged KOs",
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
	"body_bonus": "+%s%% body shot slowdown",
	"liver_shot": "Body shots stagger WINDED enemies",
	"combo_window": "+%ss combo time",
	"double_jab": "A third jab in a row keeps the combo too",
	"free_punch_chance": "%s%% chance a punch costs no knuckle HP",
	"wave_heal": "Restore %s%% knuckle HP every tenth of the bout (and every Crypt room)",
	"finisher_bonus": "+%s%% damage to enemies under 30%% HP",
	"dodge_window": "+%s%% dodge windows (up to +25%% in all)",
	"flinch_reduction": "-%s%% flinch time",
	"graze_reduction": "-%s%% graze damage",
	"counter_bonus": "+%s counter multiplier",
	"counter_window": "+%ss to land a counter (up to +0.5s in all)",
	"armor_charges": "+%s super armor charge(s)",
	"armor_recharge_cut": "Super armor recharges %ss faster",
	"retaliation_bonus": "+%s%% damage on super armor counters",
	"perfect_cooldown_cut": "Perfect counter cooldown -%ss",
	"counter_free_bonus": "+%s%% chance counters are free",
	"boss_ko_bonus": "Perfect counters take +%s%% of a boss's HP",
	"shockwave_radius": "+%sm shockwave radius",
	"shockwave_stun": "+%ss shockwave stun",
	"shockwave_every_cut": "Shockwave every %s fewer hits",
	"opener_bonus": "+%s dash punch multiplier",
	"finisher_threshold": "Jump punch finishers work on enemies with +%s%% more HP",
	"sprint_bonus": "+%s%% sprint speed",
	"fire_punch": "Fire deals %s%% of the hit to enemies nearby",
	"chain_lightning": "Lightning arcs to %s enemies",
	"ground_pound": "Landing shockwave deals %sx your base damage",
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
	"pound_radius": "+%sm shockwave radius",
	"pound_stun": "Shockwave launches and stuns",
	"seal": "Breaks the seal: opens the upgrades beyond",
	"damage_percent": "+%s%% damage",
	"knuckles_percent": "+%s%% max knuckle HP",
	"armor_absorb_reduction": "-%s%% damage from hits absorbed by super armor",
	"perfect_any_punch": "Perfect counters work with any punch",
	"shockwave_damage": "Shockwaves deal %sx your base damage",
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
}
const PERCENT_EFFECTS := [
	"wise_up", "fugget_heal", "hustle",
	"armor_pierce", "crit_chance", "crit_damage", "move_speed", "coin_bonus", "heavy_bonus", "wave_bonus", "boss_damage", "dawn_bonus", "punch_speed",
	"body_bonus", "free_punch_chance", "finisher_bonus", "dodge_window", "flinch_reduction", "graze_reduction",
	"retaliation_bonus", "counter_free_bonus", "boss_ko_bonus", "finisher_threshold", "sprint_bonus",
	"fire_punch", "xp_bonus", "chain_damage", "fire_chance", "frost_punch", "frost_chance", "brittle",
	"damage_percent", "knuckles_percent", "armor_absorb_reduction", "jump_bonus",
	"shatter", "lunging_jab", "thorns", "grit", "frost_slip", "executioner", "glass_jaw", "damage_taken",
	"last_stand", "blood_price", "ult_gain",
]
## Effects that are on/off: their text has no number.
const FLAG_EFFECTS := [
	"liver_shot", "double_jab", "chain_stun", "pound_stun", "seal", "chain_on_counter", "perfect_any_punch", "dive_kick",
	"iron_will", "spear_jab", "bone_breaker", "long_count", "champions_hands", "gravewalker", "lantern",
	"pyre", "thunderhead", "frost_shatter", "bloodbath", "ult_power",
]

## The upgrade web's layout version. Saves from an older one get everything
## they spent on upgrades back (coins and sigils) to rebuy in the new web.
const UPGRADE_VERSION := 6
## Version 5 prices ([cost, growth] per node), for the version-6 respec
## (the spoke web, 2026-10-16).
const V5_PRICES := {"wrapped_knuckles": [15, 1.0], "calluses": [20, 1.7], "iron_fists": [20, 1.8], "pickpocket": [55, 1.8], "running_shoes": [140, 2.0], "thick_skin": [125, 2.0], "quick_wraps": [160, 1.9], "heavy_hitter": [140, 1.9], "armor_breaker": [140, 2.0], "guard": [210, 1.9], "giant_killer": [790, 2.0], "sigil_blood": [2310, 1.0], "vampiric_knuckles": [1540, 1.9], "bloodletting": [1540, 1.9], "blood_rage": [1850, 2.0], "sigil_fire": [275, 1.0], "hotter_flames": [250, 1.9], "wildfire": [220, 2.0], "lingering_flames": [220, 1.9], "searing": [275, 1.9], "kindling": [330, 2.0], "brass_tape": [30, 1.8], "light_feet": [30, 2.2], "rhythm": [65, 1.9], "ice_bath": [245, 2.0], "night_owl": [395, 1.9], "iron_will": [140, 2.0], "bounty": [245, 2.2], "weighted_wraps": [990, 1.0], "dawn_patrol": [1540, 2.2], "sigil_storm": [660, 1.0], "forked": [595, 1.9], "storm": [1650, 1.0], "overcharge": [660, 1.9], "conductor": [1320, 1.0], "static_shock": [1320, 1.0], "mouthguard": [40, 1.8], "grave_robber": [50, 1.8], "cornerman": [90, 1.8], "skull_cracker": [200, 2.0], "sigil_frost": [350, 1.0], "deep_freeze": [315, 1.9], "permafrost": [280, 1.9], "frost_nova": [280, 2.0], "brittle": [420, 2.0], "cold_snap": [385, 2.0], "road_work": [40, 1.8], "footwork_drills": [130, 2.0], "heavy_bag": [130, 2.0], "sparring_partner": [110, 1.9], "champions_belt": [530, 2.0], "bone_plating": [925, 1.9], "grave_gold": [790, 2.0], "pyre": [9000, 1.0], "thunderhead": [9000, 1.0], "frost_shatter": [9000, 1.0], "bloodbath": [9000, 1.0], "bellmans_bell": [375, 1.6], "headless_helm": [480, 1.6], "southpaws_rosary": [900, 1.6], "plague_censer": [2100, 1.6], "coffin_crown": [4500, 1.6]}
## Version 4 prices ([cost, growth] per node), for the version-5 respec.
const V4_PRICES := {"wrapped_knuckles": [15, 1.0], "calluses": [20, 1.7], "iron_fists": [20, 1.8], "pickpocket": [55, 1.8], "running_shoes": [140, 2.0], "thick_skin": [125, 2.0], "quick_wraps": [160, 1.9], "heavy_hitter": [140, 1.9], "armor_breaker": [140, 2.0], "guard": [210, 1.9], "giant_killer": [790, 2.0], "sigil_blood": [2310, 1.0], "vampiric_knuckles": [1540, 1.9], "bloodletting": [1540, 1.9], "blood_rage": [1850, 2.0], "sigil_fire": [275, 1.0], "hotter_flames": [250, 1.9], "wildfire": [220, 2.0], "lingering_flames": [220, 1.9], "searing": [275, 1.9], "kindling": [330, 2.0], "brass_tape": [30, 1.8], "light_feet": [30, 2.2], "rhythm": [65, 1.9], "ice_bath": [245, 2.0], "night_owl": [395, 1.9], "iron_will": [140, 2.0], "bounty": [245, 2.2], "weighted_wraps": [990, 1.0], "dawn_patrol": [1540, 2.2], "sigil_storm": [660, 1.0], "forked": [595, 1.9], "storm": [1650, 1.0], "overcharge": [660, 1.9], "conductor": [1320, 1.0], "static_shock": [1320, 1.0], "mouthguard": [40, 1.8], "grave_robber": [50, 1.8], "cornerman": [90, 1.8], "skull_cracker": [200, 2.0], "sigil_frost": [350, 1.0], "deep_freeze": [315, 1.9], "permafrost": [280, 1.9], "frost_nova": [280, 2.0], "brittle": [420, 2.0], "cold_snap": [385, 2.0], "road_work": [40, 1.8], "footwork_drills": [130, 2.0], "heavy_bag": [130, 2.0], "sparring_partner": [110, 1.9], "champions_belt": [530, 2.0], "bone_plating": [925, 1.9], "grave_gold": [790, 2.0], "pyre": [9000, 1.0], "thunderhead": [9000, 1.0], "frost_shatter": [9000, 1.0], "bloodbath": [9000, 1.0], "bellmans_bell": [375, 1.6], "headless_helm": [480, 1.6], "southpaws_rosary": [900, 1.6], "plague_censer": [2100, 1.6], "coffin_crown": [4500, 1.6]}
## The fighter skill webs' version. Version 2 (2026-10-15) rebuilt every web
## (fewer, stronger nodes); older saves get every skill point back.
const SKILL_VERSION := 2
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

## Each class's own progress: {class_id: {level, xp, stat_points, skill_points,
## stats: {stat: points}, skills: {id: level}}}. The properties below read and
## write the current class's entry.
var _classes := {}

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
var stat_points: int:
	get:
		return _current().stat_points
	set(value):
		_current().stat_points = value
var skill_points: int:
	get:
		return _current().skill_points
	set(value):
		_current().skill_points = value
var stats: Dictionary:
	get:
		return _current().stats


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

## The upgrade web, or the current class's skill web.
func tree(kind: String) -> Dictionary:
	return UPGRADES if kind == "upgrade" else SKILL_TREES[player_class]


func class_level(id: String) -> int:
	return _classes[id].level


func _current() -> Dictionary:
	return _classes[player_class]


func _levels(kind: String) -> Dictionary:
	return upgrade_levels if kind == "upgrade" else _current().skills


func _new_class_progress() -> Dictionary:
	var class_stats := {}
	for stat in STATS:
		class_stats[stat] = 0
	return {"level": 1, "xp": 0, "stat_points": 0, "skill_points": 0, "stats": class_stats, "skills": {}}


# --- Derived values -------------------------------------------------------

## Total of one effect from owned upgrades, the current class's skills and
## any equipped Crypt items.
func get_effect(effect: String) -> float:
	var total := 0.0
	for kind in ["upgrade", "skill"]:
		var nodes := tree(kind)
		var owned := _levels(kind)
		for id in owned:
			total += nodes[id].effects.get(effect, 0) * owned[id]
	for slot in equipped:
		total += equipped[slot].effects.get(effect, 0.0)
	for blessing in blessings:
		total += blessing.effects.get(effect, 0.0)
	for id in hats:
		if Hats.CATALOG.has(id):
			total += float(Hats.CATALOG[id].effects.get(effect, 0.0))
	return total


## Tony joins the roster (the fourth Yonker, or the secret code in Settings).
func unlock_tony() -> void:
	tony_unlocked = true
	_commit()


## Collects a popped hat. Returns "new", "duplicate" (turned into Souls) or
## "tony" (the fourth Yonker: Tony unlocks).
func add_hat(id: String) -> String:
	if not Hats.CATALOG.has(id):
		return ""
	if hats.has(id):
		hats[id] = int(hats[id]) + 1
		souls += Hats.DUPLICATE_SOULS[Hats.CATALOG[id].rarity]
		_commit()
		return "duplicate"
	hats[id] = 1
	var result := "new"
	if not tony_unlocked and Hats.LEGENDARIES.all(func(legend: String) -> bool: return hats.has(legend)):
		tony_unlocked = true
		result = "tony"
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


## Ends a Crypt run. escaped (left by the exit stairs): gilded finds join the
## armory and stay worn; finds that weren't gilded are lost (that slot goes
## back to what you came in with). Knocked out: only what you came in with.
func end_crypt_run(escaped: bool) -> Array:
	var kept: Array = []
	if escaped:
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
	else:
		equipped = _run_entry.duplicate()
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
	return CLASSES.keys().filter(func(id: String) -> bool: return not id in SECRET_CLASSES or tony_unlocked)


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
	return (2.0 + stats.damage * DAMAGE_PER_POINT + get_effect("damage")) * get_class_mod("damage") * (1.0 + get_effect("damage_percent"))


func get_defense() -> float:
	return stats.defense + get_effect("defense") + get_class_mod("defense", 0.0)


## Multiplier on knuckle HP lost to enemy hits. Never reaches zero.
func get_knuckle_loss_multiplier() -> float:
	return 10.0 / (10.0 + get_defense())


func get_max_knuckles() -> float:
	return (50.0 + KNUCKLES_PER_POINT * stats.durability + get_effect("max_knuckles")) * get_class_mod("knuckles") * (1.0 + get_effect("knuckles_percent"))


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


func get_combo_window() -> float:
	return 1.5 + get_effect("combo_window") + get_class_mod("combo_window", 0.0)


func get_punch_speed() -> float:
	return get_class_mod("punch_speed") * (1.0 + get_effect("punch_speed"))


## Dodge windows grow only so far: past that, dodging stops being a skill.
func get_dodge_window_multiplier() -> float:
	return get_class_mod("dodge_window") * (1.0 + minf(get_effect("dodge_window"), MAX_DODGE_WINDOW_BONUS))


## Extra seconds to land a counter after a dodge (capped like dodge windows).
func get_counter_window_bonus() -> float:
	return minf(get_effect("counter_window"), MAX_COUNTER_WINDOW_BONUS)


func get_counter_multiplier(base: float) -> float:
	return get_class_mod("counter", base) + get_effect("counter_bonus")


func get_sprint_multiplier() -> float:
	return get_class_mod("sprint") * (1.0 + get_effect("sprint_bonus"))


func get_coin_multiplier() -> float:
	return 1.0 + 0.05 * stats.looting + get_effect("coin_bonus")


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
		stat_points += STAT_POINTS_PER_LEVEL
		skill_points += SKILL_POINTS_PER_LEVEL
		leveled_up.emit(level)
	changed.emit()


func add_resource(resource: String, amount: int) -> void:
	resources[resource] = resources.get(resource, 0) + amount
	changed.emit()


# --- Spending ---------------------------------------------------------------

func spend_stat_point(stat: String) -> bool:
	if stat_points <= 0 or not stats.has(stat):
		return false
	stat_points -= 1
	stats[stat] += 1
	_commit()
	return true


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


## True once the node's ring has been unsealed by Dead League wins.
func node_open(kind: String, id: String) -> bool:
	return node_ring(kind, id) <= Progression.open_ring()


## Price of the next level (coins for upgrades, skill points for skills).
func node_cost(kind: String, id: String) -> int:
	var node: Dictionary = tree(kind)[id]
	return roundi(node.cost * pow(node.cost_growth, node_level(kind, id)))


func node_currency(kind: String) -> int:
	return resources.get("coins", 0) if kind == "upgrade" else skill_points


## The contender whose seal still blocks this node ("" when it's open).
func node_sealed_by(kind: String, id: String) -> String:
	return "" if node_open(kind, id) else Progression.seal_holder(node_ring(kind, id))


func can_buy_node(kind: String, id: String) -> bool:
	var state := node_state(kind, id)
	return (state == "available" or state == "owned") \
			and node_currency(kind) >= node_cost(kind, id)


func buy_node(kind: String, id: String) -> bool:
	if not can_buy_node(kind, id):
		return false
	var cost := node_cost(kind, id)
	if kind == "upgrade":
		resources["coins"] -= cost
	else:
		skill_points -= cost
	_levels(kind)[id] = node_level(kind, id) + 1
	_commit()
	return true


## e.g. "+6 damage, +3 defense" for a node's effects at the given level.
func effect_text(effects: Dictionary, at_level: int) -> String:
	var parts: Array[String] = []
	for effect in effects:
		if effect in FLAG_EFFECTS:
			parts.append(EFFECT_FORMATS[effect])
			continue
		var value: float = effects[effect] * at_level
		if effect in PERCENT_EFFECTS:
			value *= 100.0
		var shown := "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else ("%.2f" % value).rstrip("0")
		parts.append(EFFECT_FORMATS.get(effect, effect + " %s") % shown)
	return ", ".join(parts)


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
	var saved_hats = data.get("hats", {})
	if saved_hats is Dictionary:
		for id in saved_hats:
			hats[id] = int(saved_hats[id])
	hat_pity = int(data.get("hat_pity", 0))
	tony_unlocked = bool(data.get("tony_unlocked", false))
	# Champion Sigils are gone: any saved (spent or not) become Souls.
	var old_sigils := int(data.get("sigils", 0))
	var saved_resources: Dictionary = data.get("resources", {})
	for resource in saved_resources:
		if RESOURCE_NAMES.has(resource):
			resources[resource] = int(saved_resources[resource])
	var saved_upgrade_version := int(data.get("upgrade_version", 1))
	if saved_upgrade_version < UPGRADE_VERSION and data.get("upgrades", {}) is Dictionary:
		if saved_upgrade_version == 5:
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

	var saved_classes: Dictionary = data.get("classes", {})
	if saved_classes.is_empty():
		# Older saves had one shared level: it becomes the current class's.
		_load_class_progress(player_class, data)
	else:
		for id in saved_classes:
			if CLASSES.has(id):
				_load_class_progress(id, saved_classes[id])

	# Skill web v2: every class's web was rebuilt, so every point comes back.
	if int(data.get("skill_version", 1)) < SKILL_VERSION:
		var refunded := false
		for id in _classes:
			var progress: Dictionary = _classes[id]
			if not progress.skills.is_empty() or progress.skill_points > 0:
				refunded = refunded or not progress.skills.is_empty()
			progress.skills = {}
			progress.skill_points = (int(progress.level) - 1) * SKILL_POINTS_PER_LEVEL
		if refunded:
			upgrade_notice = (upgrade_notice + "
" if upgrade_notice != "" else "") + "The skill webs were rebuilt: every skill point is back."
	# Armor Breaker went from flat armor to a share of it: convert kept gear.
	if saved_upgrade_version < 5:
		for item in armory:
			if item is Dictionary and item.get("effects", {}) is Dictionary and float(item.effects.get("armor_pierce", 0.0)) >= 1.0:
				item.effects.armor_pierce = snappedf(float(item.effects.armor_pierce) * 0.07, 0.01)
	# Nodes no longer connected to the center are removed and refunded.
	_refund_unreachable(UPGRADES, upgrade_levels, func(amount: int) -> void: resources["coins"] = resources.get("coins", 0) + amount)
	for id in _classes:
		var progress: Dictionary = _classes[id]
		_refund_unreachable(SKILL_TREES[id], progress.skills, func(amount: int) -> void: progress.skill_points += amount)
	changed.emit()


func _load_class_progress(id: String, saved: Dictionary) -> void:
	var progress: Dictionary = _classes[id]
	progress.level = int(saved.get("level", 1))
	progress.xp = int(saved.get("xp", 0))
	progress.stat_points = int(saved.get("stat_points", 0))
	progress.skill_points = int(saved.get("skill_points", 0))
	var saved_stats: Dictionary = saved.get("stats", {})
	for stat in progress.stats:
		progress.stats[stat] = int(saved_stats.get(stat, 0))
	# Skills: {id: level}, or an old list of ids. Skills this class's web
	# doesn't have give their points back.
	var web: Dictionary = SKILL_TREES[id]
	var saved_skills = saved.get("skills", {})
	if saved_skills is Array:
		progress.skill_points += saved_skills.size()
	elif saved_skills is Dictionary:
		for skill in saved_skills:
			var owned := int(saved_skills[skill])
			if web.has(skill):
				progress.skills[skill] = clampi(owned, 0, web[skill].max_level)
			else:
				progress.skill_points += owned


## Souls given for each old Champion Sigil when sigils were retired.
const SOULS_PER_OLD_SIGIL := 3


## A node's price before ring scaling (what older saves paid).
func _pre_ring_cost(id: String) -> float:
	var node: Dictionary = UPGRADES[id]
	return node.cost / Progression.RING_COST.get(int(node.get("ring", 1)), 1.0)


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
		if not UPGRADES.has(id):
			continue
		var node: Dictionary = UPGRADES[id]
		var owned := clampi(int(saved[id]), 0, node.max_level)
		for level in owned:
			current_value += roundi(_pre_ring_cost(id) * pow(node.cost_growth, level))
	_give_respec(roundi(current_value * V2_REFUND_SCALE), old_sigils)


## Version 3 -> 4 (the Climb): the web became five sealed rings with new
## prices. Clear it and refund what it cost at the old (pre-ring) prices;
## Champion Sigils become Souls.
func _respec_for_rings(saved: Dictionary, old_sigils: int) -> void:
	var coins := 0
	for id in saved:
		if not UPGRADES.has(id):
			continue
		var owned := clampi(int(saved[id]), 0, UPGRADES[id].max_level)
		for level in owned:
			coins += roundi(_pre_ring_cost(id) * pow(UPGRADES[id].cost_growth, level))
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
				upgrade_levels[id] = clampi(int(saved[id]), 0, UPGRADES[id].max_level)


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
				total += roundi(nodes[id].cost * pow(nodes[id].cost_growth, i))
			refund.call(total)
			owned.erase(id)
			removed = true


func reset_progress() -> void:
	_reset_fields()
	_commit()


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
