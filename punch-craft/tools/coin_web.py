"""Generates the UPGRADES block of game_state.gd: the coin upgrade web (v6).
Run: python punch-craft/tools/coin_web.py > /tmp/upgrades.gd.txt, then paste
it over `const UPGRADES := {...}` (or let the patch step do it).

Layout (x = columns right, y = rows down):
- A center node, then four straight spokes, one tier per ring (1-6). Each tier
  is stronger and pricier than the last, and only shows once the one before
  it is maxed: DAMAGE east, HEALTH west, DEFENSE south, MONEY north.
- Short side lines branch off the spokes with related stats: off damage,
  heavies, counters, armor pierce, boss damage and crits; off health, heals
  and toughness; off defense, dodging; off money, XP and pay.
- Powers branch off the spokes as straight lines too: FIRE off damage tier 2,
  STORM off damage tier 4, FROST off defense tier 3, BLOOD off health tier 5,
  each opening with its contender's seal and ending in a Coffin King capstone.
- The five Trophies hang off the defense spoke's west side, one per seal.
"""
import sys

# Spoke tiers: price of level 1 by ring, and what a level gives.
SPOKE_BASE = {1: 20, 2: 120, 3: 330, 4: 800, 5: 2000, 6: 5200}
SPOKE_GROWTH = 1.45
# Side nodes: price of level 1 by ring.
SIDE_BASE = {1: 30, 2: 160, 3: 420, 4: 950, 5: 2300, 6: 9000}
SIDE_GROWTH = 1.6
# Every price in a ring is scaled so each ring costs about 4-6 good bouts of
# that tier's pay (ring 1 about 2.5), on the pay ladder where each division
# pays ~5x the last (checked by balance_regression).
PRICE_SCALE = {1: 3.78, 2: 3.75, 3: 5.93, 4: 14.1, 5: 44.1, 6: 83.8}

NODES = []


def node(nid, name, icon, pos, requires, ring, levels, effects, desc, cost=None, growth=None, medallion=False):
    NODES.append(dict(id=nid, name=name, icon=icon, pos=pos, requires=requires, ring=ring, levels=levels,
                      effects=effects, desc=desc, cost=cost if cost is not None else SIDE_BASE[ring],
                      growth=growth if growth is not None else (SIDE_GROWTH if levels > 1 else 1.0), medallion=medallion))


def line(ids, start, step, requires):
    """Positions for a straight line of nodes."""
    out = []
    x, y = start
    for i, nid in enumerate(ids):
        out.append(((x + step[0] * i, y + step[1] * i), requires if i == 0 else ids[i - 1]))
    return out


# --- Center ---
node("wrapped_knuckles", "Taped Up", "wraps", (0, 0), [], 1, 1, {"damage": 1, "max_knuckles": 5},
     "Tape and cloth. Every road out of here starts with your hands.", cost=15)

# --- Spokes ---
SPOKES = {
    "dmg": ((1, 0), "damage", [1, 1.2, 2, 3, 4, 6], 5,
            ["Bricks for Hands", "Iron Fists", "Sledge Fists", "Wrecking Fists", "Anvil Hands", "Hands of the Damned"],
            ["fist", "fist", "hammer", "hammer", "anvil", "anvil"], "Every punch hits harder."),
    "hp": ((-1, 0), "max_knuckles", [6, 9, 13, 19, 27, 38], 5,
           ["Leather Knuckles", "Rawhide", "Thick Skin", "Iron Knuckles", "Grave Hide", "Undying Hide"],
           ["heart", "heart_plus", "heart", "heart_plus", "heartbeat", "heartbeat"], "More knuckle HP: every punch and hit costs some."),
    "def": ((0, 1), "defense", [0.6, 0.8, 1.2, 1.7, 2.4, 3.2], 5,
            ["Mouthguard", "High Guard", "Ribcage Armor", "Bone Plating", "Tombstone Chin", "Iron Coffin"],
            ["tooth", "shield", "bones", "chestplate", "helmet", "shield"], "Hits take less knuckle HP."),
    "gold": ((0, -1), "coin_bonus", [0.05, 0.06, 0.07, 0.08, 0.09, 0.12], 3,
             ["Grave Robber", "Grave Tax", "Grave Gold", "Loan Shark", "Undertaker's Cut", "King's Ransom"],
             ["shovel", "bag", "chest", "bag", "chest", "crown"], "More coins from every kill."),
}
for key, (step, effect, values, levels, names, icons, desc) in SPOKES.items():
    prev = "wrapped_knuckles"
    for t in range(6):
        ring = t + 1
        nid = "%s_%d" % (key, ring)
        node(nid, names[t], icons[t], (step[0] * ring, step[1] * ring), [prev], ring, levels, {effect: values[t]}, desc,
             cost=SPOKE_BASE[ring] * (1.5 if key == "def" else 1.0) * (1.3 if key == "gold" else 1.0), growth=SPOKE_GROWTH)
        prev = nid

# --- Off the damage spoke (east, y = 0) ---
# South lines (rows 1-2): heavies, counters, armor, bosses.
node("heavy_hitter", "Haymaker", "hammer", (2, 1), ["dmg_2"], 2, 3, {"heavy_bonus": 0.08}, "Set-up hooks and uppercuts hit harder.")
node("heavy_bag", "Rib Shot", "gut", (2, 2), ["heavy_hitter"], 3, 3, {"heavy_bonus": 0.12}, "Set-up heavies cave things in.")
node("counterpuncher", "Counterpuncher", "counter_arrow", (3, 1), ["dmg_3"], 3, 3, {"counter_bonus": 0.2}, "Counters hit harder.")
node("return_fire", "Return Fire", "counter_arrow", (3, 2), ["counterpuncher"], 4, 3, {"counter_bonus": 0.3}, "Counters hit much harder.")
node("armor_breaker", "Can Opener", "broken_shield", (4, 1), ["dmg_4"], 4, 3, {"armor_pierce": 0.15}, "Punch straight through enemy armor.")
node("giant_killer", "Bigger They Fall", "crown", (4, 2), ["armor_breaker"], 5, 3, {"boss_damage": 0.15}, "Bosses and champions take extra damage.")
node("weighted_wraps", "Lead Tape", "dumbbell", (5, 1), ["dmg_5"], 5, 1, {"heavy_cost_cut": 1}, "Hooks and uppercuts cost less knuckle HP.")
# North of tier 3: crits.
node("lucky_shot", "Lucky Shot", "star", (3, -1), ["dmg_3"], 3, 3, {"crit_chance": 0.04}, "Some punches land just right: critical hits.")
node("dirty_shot", "Dirty Shot", "slash", (3, -2), ["lucky_shot"], 4, 2, {"crit_chance": 0.04}, "Even more critical hits.")
node("glass_breaker", "Glass Breaker", "burst", (3, -3), ["dirty_shot"], 4, 3, {"crit_damage": 0.25}, "Critical hits hit even harder.")
# FIRE, straight north off tier 2.
fire = ["sigil_fire", "hotter_flames", "lingering_flames", "searing", "kindling", "wildfire", "pyre"]
spots = line(fire, (2, -1), (0, -1), ["dmg_2"])
node("sigil_fire", "Hellfire", "flame", spots[0][0], spots[0][1], 2, 1, {"fire_punch": 0.3, "burn": 0.25},
     "Awakens FIRE: set-up heavies and counters burst into flame.", cost=SIDE_BASE[2] * 2.5, medallion=True)
node("hotter_flames", "Brimstone", "thermometer", spots[1][0], [spots[1][1]], 2, 3, {"fire_punch": 0.2}, "Bigger fire bursts.")
node("lingering_flames", "Slow Burn", "clock", spots[2][0], [spots[2][1]], 3, 3, {"burn_time": 1.5}, "Burns last longer.")
node("searing", "Scorch", "burst", spots[3][0], [spots[3][1]], 3, 3, {"burn": 0.2}, "Burns hurt more.")
node("kindling", "Firestarter", "match", spots[4][0], [spots[4][1]], 4, 3, {"fire_chance": 0.06}, "Any punch can burst into flame.")
node("wildfire", "Wildfire", "ripple", spots[5][0], [spots[5][1]], 4, 2, {"fire_radius": 1.0}, "Fire spreads farther.")
node("pyre", "Pyre", "pyre", spots[6][0], [spots[6][1]], 6, 1, {"pyre": 1}, "Burning enemies explode when they die.", medallion=True)
# STORM, straight north off tier 4.
storm = ["sigil_storm", "forked", "overcharge", "static_shock", "conductor", "storm", "thunderhead"]
spots = line(storm, (4, -1), (0, -1), ["dmg_4"])
node("sigil_storm", "Thunderclap", "bolt", spots[0][0], spots[0][1], 4, 1, {"chain_lightning": 2},
     "Awakens STORM: combos arc lightning.", cost=SIDE_BASE[4] * 2.0, medallion=True)
node("forked", "Forked Lightning", "fork", spots[1][0], [spots[1][1]], 4, 2, {"chain_lightning": 1}, "Lightning jumps to one more enemy.")
node("overcharge", "Overcharge", "battery", spots[2][0], [spots[2][1]], 4, 3, {"chain_damage": 0.15}, "Lightning hits harder.")
node("static_shock", "Static Shock", "spark", spots[3][0], [spots[3][1]], 4, 1, {"chain_stun": 1}, "Lightning staggers.")
node("conductor", "Lightning Rod", "magnet", spots[4][0], [spots[4][1]], 5, 1, {"chain_on_counter": 1}, "Every counter arcs lightning.")
node("storm", "Perfect Storm", "storm", spots[5][0], [spots[5][1]], 5, 1, {"chain_every_cut": 1}, "Lightning comes every 4th combo hit.")
node("thunderhead", "Thunderhead", "thunderhead", spots[6][0], [spots[6][1]], 6, 1, {"thunderhead": 1}, "Clean dodges call lightning on the attacker.", medallion=True)

# --- Off the health spoke (west, y = 0) ---
node("ice_bath", "Ice Bath", "bucket", (-2, -1), ["hp_2"], 2, 2, {"wave_heal": 1}, "Recover a little every tenth of the bout.")
node("iron_will", "Chin Check", "anchor", (-2, 1), ["hp_2"], 2, 2, {"flinch_reduction": 0.15}, "Shake off clean hits faster.")
node("calloused", "Calloused", "tape", (-3, -1), ["hp_3"], 3, 3, {"free_punch_chance": 0.05}, "Some punches don't hurt your hands at all.")
node("thick_skull", "Thick Skull", "helmet", (-3, 1), ["hp_3"], 3, 2, {"graze_reduction": 0.15}, "Grazes (right timing, wrong dodge) hurt less.")
node("second_wind", "Second Wind", "wind", (-4, -1), ["hp_4"], 4, 2, {"wave_heal": 1}, "Recover more every tenth of the bout.")
# BLOOD, straight north off tier 5.
blood = ["sigil_blood", "vampiric_knuckles", "bloodletting", "blood_rage", "bloodbath"]
spots = line(blood, (-5, -1), (0, -1), ["hp_5"])
node("sigil_blood", "Blood Moon", "drop", spots[0][0], spots[0][1], 5, 1, {"heal_on_kill": 1},
     "Awakens BLOOD: every kill heals you.", cost=SIDE_BASE[5] * 2.0, medallion=True)
node("vampiric_knuckles", "Bloodsucker", "fang", spots[1][0], [spots[1][1]], 5, 3, {"heal_on_kill": 0.5}, "Kills heal more.")
node("bloodletting", "Bloodletting", "heartbeat", spots[2][0], [spots[2][1]], 5, 3, {"counter_heal": 0.5}, "Counters heal you.")
node("blood_rage", "Seeing Red", "blood_burst", spots[3][0], [spots[3][1]], 5, 3, {"last_stand": 0.15}, "The closer you are to dropping, the harder you hit.")
node("bloodbath", "Bloodbath", "bloodbath", spots[4][0], [spots[4][1]], 6, 1, {"bloodbath": 1}, "Healing doubled under half knuckle HP.", medallion=True)

# --- Off the defense spoke (south, x = 0) ---
node("cornerman", "Cornerman", "medkit", (-1, 1), ["def_1"], 1, 3, {"wave_heal": 1}, "Recover a little every tenth of the bout.")
node("footwork_drills", "Jump Rope", "footprints", (1, 1), ["def_1"], 1, 2, {"dodge_window": 0.04}, "A touch more time to dodge.")
node("bob_and_weave", "Bob and Weave", "slip", (1, 2), ["def_2"], 2, 2, {"counter_window": 0.1}, "A little longer to land a counter.")
node("rope_a_dope", "Rope-a-Dope", "anchor", (1, 4), ["def_4"], 4, 3, {"graze_reduction": 0.1}, "Grazes hurt less.")
# FROST, straight east off tier 3 (row 3).
frost = ["sigil_frost", "deep_freeze", "permafrost", "frost_nova", "brittle", "cold_snap", "frost_shatter"]
spots = line(frost, (1, 3), (1, 0), ["def_3"])
node("sigil_frost", "Deathchill", "snowflake", spots[0][0], spots[0][1], 3, 1, {"frost_punch": 0.4},
     "Awakens FROST: set-up heavies and counters freeze.", cost=SIDE_BASE[3] * 2.0, medallion=True)
node("deep_freeze", "Deep Freeze", "shard", spots[1][0], [spots[1][1]], 3, 3, {"frost_punch": 0.1}, "Frozen enemies are slower.")
node("permafrost", "Permafrost", "hourglass", spots[2][0], [spots[2][1]], 3, 3, {"frost_time": 1.0}, "Freezes last longer.")
node("frost_nova", "Frost Nova", "nova", spots[3][0], [spots[3][1]], 3, 2, {"frost_radius": 1.0}, "Freezes reach farther.")
node("brittle", "Brittle Bones", "broken_shield", spots[4][0], [spots[4][1]], 4, 3, {"brittle": 0.1}, "Frozen enemies take extra damage from everything.")
node("cold_snap", "Cold Snap", "icicle", spots[5][0], [spots[5][1]], 4, 3, {"frost_chance": 0.08}, "Any punch can freeze.")
node("frost_shatter", "Shatter", "shatter", spots[6][0], [spots[6][1]], 6, 1, {"frost_shatter": 1}, "Frozen enemies burst into frost when they die.", medallion=True)
# The Trophies, west of the defense spoke, one per seal.
TROPHY = [
    ("bellmans_bell", "The Bellman's Bell", "belt", 2, 3, {"damage": 1.5, "max_knuckles": 10}, "Trophy: it still rings when you hit things."),
    ("headless_helm", "Headless Helm", "helmet", 3, 3, {"damage": 2, "max_knuckles": 15, "defense": 1}, "Trophy: no head, no problem."),
    ("southpaws_rosary", "Southpaw's Veil", "medal", 4, 3, {"damage": 3, "max_knuckles": 20, "defense": 1.5}, "Trophy: a little of her left hand, now yours."),
    ("plague_censer", "Plague Censer", "bucket", 5, 3, {"damage": 4, "max_knuckles": 30, "defense": 2}, "Trophy: the cure smells terrible."),
    ("coffin_crown", "The Coffin Crown", "crown", 6, 5, {"damage": 5, "max_knuckles": 40, "defense": 3}, "Trophy: heavy is the head. Raw power for the endless dark."),
]
for tid, name, icon, ring, levels, effects, desc in TROPHY:
    node(tid, name, icon, (-1, ring), ["def_%d" % ring], ring, levels, effects, desc, cost=SIDE_BASE[ring] * 1.6, growth=1.6, medallion=True)

# --- Off the money spoke (north, x = 0) ---
node("sparring_partner", "Sparring Partner", "crossed_gloves", (1, -1), ["gold_1"], 1, 3, {"xp_bonus": 0.1}, "Learn faster: more XP.")
node("light_feet", "Twinkle Toes", "chevrons", (-1, -1), ["gold_1"], 1, 2, {"move_speed": 0.05}, "Faster on your feet.")
node("running_shoes", "Cemetery Sprint", "wing_boot", (1, -2), ["gold_2"], 2, 2, {"sprint_bonus": 0.1}, "Faster sprinting.")
node("quick_wraps", "Snap Wraps", "fast_fist", (-1, -2), ["gold_2"], 2, 3, {"punch_speed": 0.04}, "Lighter wraps for faster hands.")
node("bounty", "Crowd Pleaser", "wanted", (1, -3), ["gold_3"], 3, 2, {"wave_bonus": 0.25}, "Bigger milestone bonuses in the Arena.")
node("rhythm", "Speed Bag", "note", (-1, -3), ["gold_3"], 3, 3, {"combo_step": 0.05}, "Combos build faster.")
node("night_owl", "Film Study", "moon", (1, -4), ["gold_4"], 4, 3, {"xp_bonus": 0.15}, "Learn from every fight: more XP.")
node("dawn_patrol", "Prize Fighter", "sun", (1, -5), ["gold_5"], 5, 2, {"dawn_bonus": 0.25}, "Bigger Arena purses.")


def gd(v):
    if isinstance(v, float):
        return repr(round(v, 4))
    return repr(v)


out = ["const UPGRADES := {\n"]
for n in NODES:
    n["cost"] = n["cost"] * PRICE_SCALE[n["ring"]]
    req = ", ".join('"%s"' % r for r in (n["requires"] if isinstance(n["requires"], list) else [n["requires"]]))
    fx = ", ".join('"%s": %s' % (k, gd(v)) for k, v in n["effects"].items())
    head = '"name": "%s", "icon": "%s", "pos": Vector2(%d, %d), "requires": [%s], "ring": %d' % (
        n["name"], n["icon"], n["pos"][0], n["pos"][1], req, n["ring"])
    if n["medallion"]:
        head += ', "medallion": true'
    desc = n["desc"].replace('"', '\\"')
    out.append('\t"%s": {\n\t\t%s,\n\t\t"desc": "%s",\n\t\t"max_level": %d, "cost": %d, "cost_growth": %s, "effects": {%s},\n\t},\n' % (
        n["id"], head, desc, n["levels"], round(n["cost"]), gd(float(n["growth"])), fx))
out.append("}\n")
# Sanity: no two nodes on one cell.
cells = {}
for n in NODES:
    assert n["pos"] not in cells, "%s and %s share %s" % (n["id"], cells[n["pos"]], n["pos"])
    cells[n["pos"]] = n["id"]
sys.stdout.write("".join(out))
