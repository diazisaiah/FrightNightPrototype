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
				cost += node.cost * pow(node.cost_growth, level)
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
	quit()


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
			levels.append([node.cost * pow(node.cost_growth, level), id])
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
