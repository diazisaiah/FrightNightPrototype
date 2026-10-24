class_name Bounties
## Bounties (2026-10-24): three tasks at a time ("Knock out 8 skeletons",
## "Find a hat", "Clear 2 Crypt floors"...) that pay coins and/or Souls plus
## bounty XP. Each rolls a rarity: rarer ones ask more and pay more. Bounty
## XP levels your mastery, which shifts the odds toward rarer bounties.
## Finishing one rolls the next. Only things you've unlocked are rolled.

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS := {
	"common": Color(0.8, 0.8, 0.8), "uncommon": Color(0.35, 0.9, 0.45), "rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.8, 0.45, 1.0), "legendary": Color(1.0, 0.62, 0.12),
}
## Odds at mastery 1, and how much each mastery level moves them.
const WEIGHTS := [55.0, 27.0, 12.0, 5.0, 1.0]
const WEIGHT_SHIFT := [-3.0, 0.5, 1.2, 0.9, 0.4]
const MIN_COMMON := 8.0
const MAX_MASTERY := 25
## Rewards by rarity. Coins are times the pay where you are on the climb.
const COINS := [150, 300, 600, 1100, 2000]
const SOULS := [0, 1, 3, 6, 12]
const XP := [10, 22, 45, 90, 180]
## Uncommon bounties pay Souls this often (rarer always do).
const UNCOMMON_SOUL_CHANCE := 0.5
const SLOTS := 3
const SWAP_SOULS := 2
## The fights bounties count in (not training).
const FIGHT_SCENES := ["world.tscn", "dungeon.tscn", "dead_league_arena.tscn"]

## counts: the target per rarity. best: progress is the best single value
## (a combo, a grade), not a running total. one: wording for a target of 1.
const TASKS := {
	"kos": {"text": "Knock out %d monsters", "event": "ko", "counts": [20, 40, 80, 140, 220]},
	"kind": {"text": "Knock out %d %s", "event": "ko", "counts": [8, 15, 25, 40, 60]},
	"elites": {"text": "Knock out %d elites", "one": "Knock out an elite", "event": "ko", "counts": [2, 4, 7, 11, 16]},
	"champions": {"text": "Knock out %d champions", "one": "Knock out a champion", "event": "ko", "counts": [1, 2, 3, 4, 6]},
	"veterans": {"text": "Knock out %d veterans", "event": "ko", "counts": [3, 6, 10, 15, 22]},
	"hats": {"text": "Find %d hats", "one": "Find a hat", "event": "hat", "counts": [1, 1, 2, 3, 4]},
	"grave_champion": {"text": "Beat the Grave Champion %d times", "one": "Beat the Grave Champion", "event": "arena_boss", "counts": [1, 2, 3, 4, 6]},
	"crypt": {"text": "Clear %d Crypt floors", "one": "Clear a Crypt floor", "event": "crypt_floor", "counts": [1, 2, 3, 5, 8]},
	"league": {"text": "Win %d Dead League bouts", "one": "Win a Dead League bout", "event": "league_win", "counts": [1, 1, 2, 3, 4]},
	"counters": {"text": "Land %d counters", "event": "counter", "counts": [10, 20, 35, 60, 100]},
	"combo": {"text": "Land a %d-hit combo", "event": "combo", "counts": [10, 15, 20, 28, 36], "best": true},
	"grade": {"text": "Win an Arena bout with %s or better", "event": "grade", "counts": [2, 3, 3, 4, 5], "best": true},
	"drills": {"text": "Finish %d daily drills", "one": "Finish a daily drill", "event": "drill", "counts": [1, 1, 2, 3, 4]},
}
## Arena grades, worst to best (a grade bounty's target is an index here).
const GRADES := ["D", "C", "B", "A", "S", "S+"]
## Plural names for "Knock out 8 skeletons".
const KIND_NAMES := {
	"zombie": "zombies", "skeleton": "skeletons", "runner": "runners", "hulk": "hulks", "brawler": "brawlers",
	"mage": "mages", "priest": "priests", "armor": "possessed armors", "shieldbearer": "shieldbearers",
	"wraith": "wraiths", "lich": "liches", "mimic": "mimics",
}


static func mastery() -> int:
	var level := 1
	var xp := GameState.bounty_xp
	while level < MAX_MASTERY and xp >= xp_for(level):
		xp -= xp_for(level)
		level += 1
	return level


## XP from this mastery level to the next.
static func xp_for(level: int) -> int:
	return roundi(60.0 * pow(level, 1.4))


## [XP into this level, XP this level needs].
static func mastery_progress() -> Array:
	var xp := GameState.bounty_xp
	for level in range(1, mastery()):
		xp -= xp_for(level)
	return [xp, xp_for(mastery())]


## The rarity odds at your mastery (0-1 each).
static func odds(level := -1) -> Array:
	if level < 0:
		level = mastery()
	var weights: Array = []
	for i in RARITIES.size():
		weights.append(maxf(MIN_COMMON if i == 0 else 0.0, WEIGHTS[i] + WEIGHT_SHIFT[i] * (level - 1)))
	var total: float = weights.reduce(func(sum: float, w: float) -> float: return sum + w, 0.0)
	return weights.map(func(w: float) -> float: return w / total)


## Bounties show once you've won a bout (locked things stay hidden).
static func unlocked() -> bool:
	return GameState.nights_cleared >= 1


## The three bounties, rolled if any slots are empty.
static func active() -> Array:
	if unlocked():
		while GameState.bounties.size() < SLOTS:
			GameState.bounties.append(roll())
	return GameState.bounties


## Kinds you've knocked out (so their bounties make sense).
static func seen_kinds() -> Array:
	return GameState.kills.keys().filter(func(kind: String) -> bool: return KIND_NAMES.has(kind))


static func _available(id: String) -> bool:
	match id:
		"kind":
			return not seen_kinds().is_empty()
		"elites":
			return GameState.crypt_unlocked or GameState.nights_cleared >= 1
		"champions":
			return Progression.current_tier() >= 4
		"veterans":
			return int(GameState.kills.get("_veteran", 0)) > 0
		"hats":
			return not GameState.hats.is_empty()
		"crypt":
			return GameState.crypt_unlocked
	return true


static func roll() -> Dictionary:
	var taken := GameState.bounties.map(func(b: Dictionary) -> String: return "%s/%s" % [b.id, b.param])
	var choices: Array = []
	for id in TASKS:
		if not _available(id):
			continue
		if id == "kind":
			for kind in seen_kinds():
				if not "kind/%s" % kind in taken:
					choices.append([id, kind])
		elif not "%s/" % id in taken:
			choices.append([id, ""])
	var pick: Array = choices.pick_random() if not choices.is_empty() else ["kos", ""]
	var tier := _roll_rarity()
	var task: Dictionary = TASKS[pick[0]]
	var souls: int = SOULS[tier]
	if RARITIES[tier] == "uncommon" and randf() >= UNCOMMON_SOUL_CHANCE:
		souls = 0
	return {
		"id": pick[0], "param": pick[1], "rarity": RARITIES[tier], "target": int(task.counts[tier]), "progress": 0,
		"coins": roundi(COINS[tier] * Progression.pay(GameState.climb_position())), "souls": souls, "xp": XP[tier],
	}


static func _roll_rarity() -> int:
	var roll_value := randf()
	var chances := odds()
	for i in chances.size():
		roll_value -= chances[i]
		if roll_value <= 0.0:
			return i
	return 0


static func text(bounty: Dictionary) -> String:
	var task: Dictionary = TASKS[bounty.id]
	match bounty.id:
		"kind":
			return task.text % [bounty.target, KIND_NAMES.get(bounty.param, bounty.param)]
		"grade":
			return task.text % GRADES[bounty.target]
	if int(bounty.target) == 1 and task.has("one"):
		return task.one
	return task.text % bounty.target


## "3 / 8", or "Not yet" for a grade.
static func progress_text(bounty: Dictionary) -> String:
	if bounty.id == "grade":
		return "Best: %s" % (GRADES[bounty.progress] if int(bounty.progress) > 0 else "-")
	return "%d / %d" % [mini(bounty.progress, bounty.target), bounty.target]


static func fraction(bounty: Dictionary) -> float:
	return clampf(float(bounty.progress) / maxf(float(bounty.target), 1.0), 0.0, 1.0)


## Swap one for a fresh roll (SWAP_SOULS).
static func swap(index: int) -> bool:
	if index < 0 or index >= GameState.bounties.size() or GameState.souls < SWAP_SOULS:
		return false
	GameState.souls -= SWAP_SOULS
	GameState.bounties.remove_at(index)
	GameState.bounties.insert(index, roll())
	GameState.save_game()
	return true


# --- Progress -------------------------------------------------------------------

## A knockout in the Arena or the Crypt: remembers the kind, then counts.
static func on_ko(enemy: Enemy) -> void:
	var kind: String = enemy.get_meta("kind", "")
	if kind != "":
		GameState.kills[kind] = int(GameState.kills.get(kind, 0)) + 1
	var veteran := enemy.has_meta("veteran")
	if veteran:
		GameState.kills["_veteran"] = int(GameState.kills.get("_veteran", 0)) + 1
	event("ko", 1, {"kind": kind, "elite": enemy.has_meta("elite"), "champion": enemy.has_meta("champion"), "veteran": veteran})
	if kind == "boss" and enemy is Boss and not enemy is DeadLeagueBoss:
		event("arena_boss")


## Something happened that bounties might count. Fight-only events (counters,
## combos) are ignored outside real fights.
static func event(kind: String, amount := 1, detail := {}) -> void:
	if not unlocked():
		return
	if kind in ["counter", "combo"] and not _in_fight():
		return
	var done: Array = []
	for bounty in active():
		var task: Dictionary = TASKS[bounty.id]
		if task.event != kind or not _matches(bounty, detail):
			continue
		if task.get("best", false):
			bounty.progress = maxi(int(bounty.progress), amount)
		else:
			bounty.progress = int(bounty.progress) + amount
		if int(bounty.progress) >= int(bounty.target):
			done.append(bounty)
	for bounty in done:
		_complete(bounty)


static func _matches(bounty: Dictionary, detail: Dictionary) -> bool:
	match bounty.id:
		"kind":
			return detail.get("kind", "") == bounty.param
		"elites":
			return detail.get("elite", false) or detail.get("champion", false)
		"champions":
			return detail.get("champion", false)
		"veterans":
			return detail.get("veteran", false)
	return true


static func _in_fight() -> bool:
	var scene := GameState.get_tree().current_scene if GameState.is_inside_tree() else null
	return scene != null and FIGHT_SCENES.any(func(path: String) -> bool: return scene.scene_file_path.ends_with(path))


static func _complete(bounty: Dictionary) -> void:
	var index := GameState.bounties.find(bounty)
	if index < 0:
		return
	var level_before := mastery()
	if int(bounty.coins) > 0:
		GameState.add_resource("coins", int(bounty.coins))
	if int(bounty.souls) > 0:
		GameState.souls += int(bounty.souls)
	GameState.bounty_xp += int(bounty.xp)
	GameState.bounties.remove_at(index)
	GameState.bounties.insert(index, roll())
	GameState.save_game()
	var pay := "+%d coins" % bounty.coins
	if int(bounty.souls) > 0:
		pay += "   +%d Souls" % bounty.souls
	Toast.show_on(GameState.get_tree(), "BOUNTY DONE:  %s" % text(bounty).to_upper(), "%s   +%d bounty XP" % [pay, bounty.xp])
	Sfx.play("clear", -4.0, 1.2)
	if mastery() > level_before:
		Toast.show_on(GameState.get_tree(), "BOUNTY MASTERY %d" % mastery(), "Rarer bounties come up more often.")
