extends SceneTree
## Balance report (dev tool): prints par per tier, what each seal ring adds,
## and every class's POWER at every tier with the expected build (par upgrades,
## attributes for its level, the typical hand of cards) against the contender
## it's about to face. Run with the test save:
##   FRIGHT_NIGHT_SAVE=user://test_save.json FRIGHT_NIGHT_SETTINGS=user://test_settings.cfg \
##   godot --headless --path . -s res://balance_report.gd


func _initialize() -> void:
	var gs = root.get_node("GameState")
	gs.tony_unlocked = true
	var prog = load("res://progression.gd")
	var rating = load("res://power_rating.gd")
	print("\n== PAR (what enemies are tuned to) ==")
	var last := {}
	for t in prog.TIER_COUNT + 1:
		var p: Dictionary = prog.par(t)
		var grow := "" if last.is_empty() else "   (x%.2f dmg, x%.2f ehp)" % [p.damage / last.damage, p.ehp / last.ehp]
		print("tier %d  lv %2d  dmg %5.1f  knuckles %5.0f  def %4.1f  ehp %5.0f  level x%.2f%s" % [t, prog.PAR_LEVEL[t], p.damage, p.knuckles, p.defense, p.ehp, p.factor, grow])
		last = p
	print("\n== WHAT EACH RING ADDS (all levels) ==")
	for ring in range(1, 7):
		var fx := {}
		var cost := 0.0
		for id in gs.UPGRADES:
			var node: Dictionary = gs.UPGRADES[id]
			if int(node.get("ring", 1)) != ring:
				continue
			for level in int(node.max_level):
				cost += gs.price_at(node, level)
				for effect in node.effects:
					fx[effect] = fx.get(effect, 0.0) + float(node.effects[effect])
		print("ring %d  cost %6d  dmg +%4.1f  knuckles +%3d  def +%4.1f" % [ring, cost, fx.get("damage", 0.0), fx.get("max_knuckles", 0.0), fx.get("defense", 0.0)])
	print("\n== CLASS POWER vs CONTENDER (par upgrades + attributes + typical cards for the level) ==")
	print("(you / contender rated as your class; 1.00 = exactly par)")
	var header := "tier"
	for cls in gs.CLASSES:
		header += "  %20s" % cls.substr(0, 14)
	print(header)
	for t in range(1, prog.TIER_COUNT + 1):
		var line := "%4d" % t
		for cls in gs.CLASSES:
			set_build(gs, prog, cls, t)
			var mine: float = rating.player()
			var theirs: float = rating.contender(t - 1)
			line += "  %6d / %6d %4.2f" % [mine, theirs, mine / theirs]
		print(line)
	print("\n== CARD HAND UPLIFT (typical hand vs none, at tier 5 par) ==")
	for cls in gs.CLASSES:
		set_build(gs, prog, cls, 5, false)
		var without: float = rating.player()
		set_build(gs, prog, cls, 5)
		var with_all: float = rating.player()
		print("%-15s POWER %4d -> %4d   x%.2f" % [cls, without, with_all, with_all / without])
	_gear_report(gs, prog, rating)
	quit()


## The gear system's reach (Crypt revamp, 2026-11-04): a berserker on par
## upgrades, attributes and cards facing each contender, in par's own gear,
## then a full set (the best of the five) at each rarity from the deepest
## Crypt floor open by then (its top level), against the contender's POWER;
## then what selling that gear pays against the ring you're saving for.
static func _gear_report(gs, prog, rating) -> void:
	print("\n== GEAR vs CONTENDER (berserker; full set = best of the five, top level of the deepest open floor) ==")
	print("tier  floor lv   par gear      common    uncommon        rare        epic   legendary   contender")
	for t in range(2, prog.TIER_COUNT + 1):
		var floor_number: int = (t - 1) * prog.FLOORS_PER_TIER
		var level: int = Gear.level_range(floor_number).y
		set_build(gs, prog, "berserker", t)
		var line := "%4d  %5d %2d   %8d" % [t, floor_number, level, rating.player()]
		for rarity in Gear.RARITIES:
			var best := 0
			for set_id in Gear.PIECES:
				gs.equipped = {}
				for slot in Gear.SLOTS:
					gs.equipped[slot] = Gear.make(set_id, slot, rarity, level)
				best = maxi(best, rating.player())
			line += "  %10d" % best
		print(line + "  %10d" % rating.contender(t - 1))
	print("\n== TYPICAL KIT vs PAR (berserker; a random set per slot at the rarity you'd usually keep, mid level; average of 60 kits) ==")
	var kept := {2: "uncommon", 3: "rare", 4: "rare", 5: "epic"}
	seed(77)
	for t in range(2, prog.TIER_COUNT + 1):
		var floor_number: int = (t - 1) * prog.FLOORS_PER_TIER
		var levels: Vector2i = Gear.level_range(floor_number)
		set_build(gs, prog, "berserker", t)
		var par_power: int = rating.player()
		var total := 0.0
		for k in 60:
			gs.equipped = {}
			for slot in Gear.SLOTS:
				gs.equipped[slot] = Gear.make(Gear.PIECES.keys().pick_random(), slot, kept[t], (levels.x + levels.y) / 2)
			total += rating.player()
		var typical := total / 60.0
		print("tier %d  %-9s par %6d   typical kit %6d  (x%.2f par, x%.2f contender %d)" % [t, kept[t], par_power, typical, typical / par_power, typical / rating.contender(t - 1), rating.contender(t - 1)])
	print("\n== GEAR vs CRYPT FLOOR (berserker at the floor's tier, rare set at the floor's middle level) ==")
	for floor_number in [2, 4, 6, 8, 10]:
		var t := clampi(ceili(floor_number / float(prog.FLOORS_PER_TIER)) + 1, 1, prog.TIER_COUNT)
		var levels: Vector2i = Gear.level_range(floor_number)
		set_build(gs, prog, "berserker", t)
		var plain: int = rating.player()
		var best := 0
		for set_id in Gear.PIECES:
			gs.equipped = {}
			for slot in Gear.SLOTS:
				gs.equipped[slot] = Gear.make(set_id, slot, "rare", (levels.x + levels.y) / 2)
			best = maxi(best, rating.player())
		print("floor %2d  rec %6d   par build %6d   with a rare set %6d" % [floor_number, rating.crypt_power(floor_number), plain, best])
	print("\n== SELLING GEAR vs RING COSTS (gold for one gilded piece at the floor's middle level) ==")
	var ring_cost := {}
	for id in gs.UPGRADES:
		var node: Dictionary = gs.UPGRADES[id]
		var ring := int(node.get("ring", 1))
		for lv in int(node.max_level):
			ring_cost[ring] = ring_cost.get(ring, 0.0) + gs.price_at(node, lv)
	for floor_number in [2, 4, 6, 8, 10, 15]:
		var levels: Vector2i = Gear.level_range(floor_number)
		var mid := (levels.x + levels.y) / 2
		var ring := clampi(ceili(floor_number / float(prog.FLOORS_PER_TIER)) + 1, 1, 6)
		var line := "floor %2d  lv %2d" % [floor_number, mid]
		for rarity in Gear.RARITIES:
			line += "  %s %8d" % [rarity.substr(0, 3), Gear.sell_price({"level": mid, "rarity": rarity})]
		print(line + "   ring %d costs %9d" % [ring, ring_cost.get(ring, 0.0)])


## The par build for tier t on this class (with the typical hand of cards
## for its level, or none).
static func set_build(gs, prog, cls: String, tier: int, cards := true) -> void:
	gs.player_class = cls
	gs.dead_league_clears = {}
	var bosses := ["bellman", "headless", "southpaw", "plague_doctor", "coffin_king"]
	for i in tier - 1:
		gs.dead_league_clears[bosses[i]] = true
	# Upgrades: the same cheapest power levels par assumes.
	var levels := []
	for id in gs.UPGRADES:
		var node: Dictionary = gs.UPGRADES[id]
		if int(node.get("ring", 1)) > tier or not prog._is_power(node):
			continue
		for level in int(node.max_level):
			levels.append([gs.price_at(node, level), id])
	levels.sort_custom(func(a, b) -> bool: return a[0] < b[0])
	var owned := {}
	for i in ceili(levels.size() * prog.PAR_SHARE):
		owned[levels[i][1]] = owned.get(levels[i][1], 0) + 1
	gs.upgrade_levels = owned
	# The decent gloves and wraps par assumes for the tier.
	var gear: Dictionary = prog._par_gear(tier)
	gs.equipped = {"gloves": {"effects": {"damage": gear.damage}}, "wraps": {"effects": {"max_knuckles": gear.knuckles, "defense": gear.defense}}}
	gs.hats = {}
	gs.blessings = []
	# Attributes: the level's points split evenly, like par.
	var level: int = prog.PAR_LEVEL[tier]
	var per := roundi(prog.par_points(level))
	if not gs._classes.has(cls):
		gs._classes[cls] = gs._new_class_progress()
	var progress: Dictionary = gs._classes[cls]
	progress.level = level
	progress.attribute_points = 0
	for attribute in progress.attributes:
		progress.attributes[attribute] = per if attribute in prog.PAR_ATTRIBUTES else 0
	progress.cards = Cards.typical_hand(cls, level - 1, tier - 1) if cards else {}
	progress.draws = 0
	progress.offer = []
