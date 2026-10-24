class_name Abilities
## Each fighter's passives and ultimates (2026-10-24): three passives and two
## ultimates, the first of each free, the rest unlocked by class level, swapped
## in camp's Loadout (never mid-run). GameState.loadouts holds the picks.
##
## Skill webs adapt: the nodes that fed a fighter's default passive (PASSIVE
## NODES) give "passive power" to whichever passive is equipped instead (one
## point a level, three for a capstone). The Mauler's default changed (Grudge
## replaced super armor), so his always do.

const PASSIVES := {
	"berserker": [
		{"id": "grudge", "name": "Grudge", "icon": "skull", "level": 1,
			"desc": "Whatever hits you is marked with a red skull. Your next punch on it deals triple damage and staggers."},
		{"id": "wrecking_ball", "name": "Wrecking Ball", "icon": "hammer", "level": 5,
			"desc": "Monsters you knock out fly like bowling balls, smashing every monster they hit."},
		{"id": "berserker", "name": "Berserker", "icon": "rage", "level": 15,
			"desc": "The lower your knuckles, the harder you hit: up to +60% damage near empty."},
	],
	"counter_master": [
		{"id": "perfect_counter", "name": "Perfect Counter", "icon": "star", "level": 1,
			"desc": "Dodge, then a hook or uppercut with the matching hand: a counter that deals x2.5 more (every 12s)."},
		{"id": "phantom_step", "name": "Phantom Step", "icon": "swoosh", "level": 5,
			"desc": "Dodge an arrow, fireball or bolt and you appear behind whoever threw it, counter ready."},
		{"id": "dodge_chain", "name": "Dodge Chain", "icon": "target", "level": 15,
			"desc": "Every dodge in a row charges your next punch (+40% a dodge, up to 6). It spends it all."},
	],
	"combo_master": [
		{"id": "rapid_combos", "name": "Rapid Combos", "icon": "swoosh", "level": 1,
			"desc": "Every 5th hit in a combo stuns everything nearby and holds the combo timer for 1s."},
		{"id": "echo_fists", "name": "Echo Fists", "icon": "bolt", "level": 5,
			"desc": "Every punch repeats a beat later as a violet echo for 30% of its damage."},
		{"id": "long_reach", "name": "Long Reach", "icon": "fist", "level": 15,
			"desc": "Your punches reach much farther: hit them before they're in range to hit you."},
	],
	"free_runner": [
		{"id": "dash_punches", "name": "Dash Punches", "icon": "swoosh", "level": 1,
			"desc": "Dash and punch: a left Spear Jab hits everything in a line, a right Haymaker blasts them back."},
		{"id": "head_stomp", "name": "Head Stomp", "icon": "boot", "level": 5,
			"desc": "Land on a monster's head to bounce off it, stunning it. Chain bounces head to head."},
		{"id": "momentum", "name": "Momentum", "icon": "chain", "level": 15,
			"desc": "Sprinting builds momentum (up to x2). Your next punch that lands spends it all as a multiplier."},
	],
	"wise_guy": [
		{"id": "fuggedaboudit", "name": "Fuggedaboudit", "icon": "shield", "level": 1,
			"desc": "Wave off one hit every 10s, with a quip."},
		{"id": "the_muscle", "name": "The Muscle", "icon": "fist", "level": 5,
			"desc": "Every 15s Cousin Vinnie, a ghostly goon, grabs the nearest monster and holds it for 2s."},
		{"id": "the_take", "name": "The Take", "icon": "coin", "level": 15,
			"desc": "Tony gets his cut: +25% coins from everything, and enraged monsters pay double."},
	],
	"elementalist": [
		{"id": "dual_sigil", "name": "Dual Sigil", "icon": "flame", "level": 1,
			"desc": "Select two of your powers at once. Both work, with all their upgrades."},
		{"id": "attunement", "name": "Attunement", "icon": "target", "level": 5,
			"desc": "One power, amplified: its damage, reach and chances are half again as strong."},
		{"id": "prism", "name": "Prism", "icon": "star", "level": 15,
			"desc": "All your powers at once, but only their base effect: no upgrades."},
	],
}

const ULTIMATES := {
	"berserker": [
		{"id": "inferno", "name": "Inferno Uppercut", "icon": "flame", "level": 1,
			"desc": "Leap at the nearest monster with a flaming uppercut that launches it and sets it alight."},
		{"id": "bulwark", "name": "Brimstone Shield", "icon": "shield", "level": 10,
			"desc": "A burning shield soaks the next hits. When it breaks it explodes, hurting everything near you by what it took."},
	],
	"counter_master": [
		{"id": "riposte", "name": "Riposte Stance", "icon": "target", "level": 1,
			"desc": "For a few seconds every attack is slipped automatically and answered with a counter hook."},
		{"id": "flow_state", "name": "Flow State", "icon": "swoosh", "level": 10,
			"desc": "For a long while you dodge everything automatically. Punch freely; nothing touches you."},
	],
	"combo_master": [
		{"id": "temporal_break", "name": "Temporal Break", "icon": "clock", "level": 1,
			"desc": "Time stops. Move freely and hit the prompts: each lands a hit and buys back time."},
		{"id": "unbroken", "name": "Unbroken", "icon": "chain", "level": 10,
			"desc": "For 10s every hit grows your combo multiplier, and your combo can't drop."},
	],
	"free_runner": [
		{"id": "highlight_reel", "name": "Highlight Reel", "icon": "chain", "level": 1,
			"desc": "Lightning-dash from monster to monster in view, punching each, and finish with a leaping haymaker."},
		{"id": "hype_train", "name": "Hype Train", "icon": "boot", "level": 10,
			"desc": "For 6s you sprint 60% faster and bowl over every monster you run into."},
	],
	"wise_guy": [
		{"id": "big_mouth", "name": "Big Mouth", "icon": "rage", "level": 1,
			"desc": "Insult the monster you're looking at: it comes only for you, hits harder and takes double from you."},
		{"id": "the_family", "name": "The Family", "icon": "crown", "level": 10,
			"desc": "Three ghost goons in fedoras show up and brawl beside you for 10s."},
	],
	"elementalist": [
		{"id": "elemental_fists", "name": "Elemental Fists", "icon": "bolt", "level": 1,
			"desc": "For 10s every punch can throw a fireball, an icicle, lightning or a blood heal (15% each)."},
		{"id": "flame_burst", "name": "Flame Burst", "icon": "burst", "level": 10,
			"desc": "A ring of fire bursts out around you: big damage, and everything in it burns."},
	],
}

## What a point of passive power does for each passive: [per point, text].
const POWER_TEXT := {
	"grudge": [0.15, "+%sx Grudge damage"],
	"wrecking_ball": [0.3, "+%sx Wrecking Ball damage"],
	"berserker": [5.0, "+%s%% Berserker damage"],
	"phantom_step": [0.2, "-%ss Phantom Step cooldown"],
	"dodge_chain": [5.0, "+%s%% per chained dodge"],
	"echo_fists": [4.0, "+%s%% echo damage"],
	"long_reach": [0.1, "+%sm reach"],
	"head_stomp": [0.1, "+%ss stomp stun"],
	"momentum": [0.1, "+%sx max momentum"],
	"the_muscle": [0.8, "-%ss between Vinnie's grabs"],
	"the_take": [3.0, "+%s%% coins"],
	"attunement": [5.0, "+%s%% attuned power"],
	"prism": [4.0, "+%s%% power (every power)"],
}

## Skill web nodes that strengthen the passive (see above).
const PASSIVE_NODES := {
	"berserker": ["short_fuse", "unbreakable", "payback", "berserk"],
	"counter_master": ["perfect_timing", "precision_strike", "executioner"],
	"combo_master": ["wide_wave", "rolling_thunder", "aftershock", "flurry"],
	"free_runner": ["high_ground", "dive_kick"],
	"wise_guy": ["shrug_it_off", "made_man"],
	"elementalist": ["conduit", "resonance", "wellspring", "archmage"],
}


static func passives(class_id: String) -> Array:
	return PASSIVES.get(class_id, [])


static func ultimates(class_id: String) -> Array:
	return ULTIMATES.get(class_id, [])


static func info(class_id: String, id: String) -> Dictionary:
	for entry in passives(class_id) + ultimates(class_id):
		if entry.id == id:
			return entry
	return {}


static func default_passive(class_id: String) -> String:
	return passives(class_id)[0].id if not passives(class_id).is_empty() else ""


static func default_ultimate(class_id: String) -> String:
	return ultimates(class_id)[0].id if not ultimates(class_id).is_empty() else ""


## Unlocked at the fighter's level.
static func unlocked(class_id: String, id: String, class_level: int) -> bool:
	var entry := info(class_id, id)
	return not entry.is_empty() and class_level >= int(entry.level)


## Whether a skill node feeds the passive (and so adapts).
static func is_passive_node(class_id: String, node_id: String) -> bool:
	return node_id in PASSIVE_NODES.get(class_id, [])


## "+0.3x Grudge damage": what this much passive power does for a passive.
static func power_text(passive: String, points: float) -> String:
	if not POWER_TEXT.has(passive):
		return "+%s passive power" % _num(points)
	return POWER_TEXT[passive][1] % _num(points * float(POWER_TEXT[passive][0]))


static func _num(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")


## The skill web as it plays with this passive: nodes that adapt show the
## passive's icon and what they give it.
static func adapt_tree(class_id: String, nodes: Dictionary, passive: String) -> Dictionary:
	var view := {}
	var entry := info(class_id, passive)
	for id in nodes:
		var node: Dictionary = nodes[id]
		if not node_adapts(class_id, id, passive):
			view[id] = node
			continue
		var adapted := node.duplicate()
		adapted.effects = {"passive_power": node.effects.get("passive_power", 3 if int(node.get("ring", 1)) >= 6 else 1)}
		adapted.icon = entry.get("icon", node.icon)
		adapted.desc = "Powers %s." % entry.get("name", "your passive")
		view[id] = adapted
	return view


## Whether that node keeps its own effect (the default passive is on, and the
## fighter's default still uses it), or gives passive power instead.
static func node_adapts(class_id: String, node_id: String, passive: String) -> bool:
	if not is_passive_node(class_id, node_id):
		return false
	return class_id == "berserker" or passive != default_passive(class_id)
