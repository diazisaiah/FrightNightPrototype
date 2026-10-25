class_name Achievements
## Achievements, each unlocking an emote (2026-10-23: The Default is free,
## every other dance is earned). Earned ones are saved in
## GameState.achievements; earning one pops a toast (Toast). Old saves get
## the ones they'd already earned, quietly, on load.

const LIST := {
	"first_hat": {"name": "Hat Trick", "desc": "Pop your first hat.", "emote": "dab"},
	"crypt_floor": {"name": "Grave Diver", "desc": "Clear a Crypt floor.", "emote": "griddy"},
	"first_contender": {"name": "Seal Breaker", "desc": "Beat a Dead League contender.", "emote": "floss"},
	"combo_25": {"name": "Flurry", "desc": "Land a 25-hit combo.", "emote": "running_man"},
	"drill": {"name": "Drill Sergeant", "desc": "Finish a daily drill.", "emote": "nae_nae"},
	"veteran": {"name": "Veteran Slayer", "desc": "Knock out a veteran monster.", "emote": "take_the_l"},
	"endless_50": {"name": "No End in Sight", "desc": "Reach 50 knockouts in the Endless Arena.", "emote": "horse_ride"},
	"legendary_hat": {"name": "Legend", "desc": "Find a legendary hat.", "emote": "bros_shuffle"},
	"untouched": {"name": "Untouchable", "desc": "Beat a Dead League contender without getting hit.", "emote": "boo_yah"},
}
## Dances everyone has.
const FREE_EMOTES := ["default"]


static func has(id: String) -> bool:
	return GameState.achievements.has(id)


## The dances you can do, in wheel order.
static func emotes() -> Array:
	return Emotes.ORDER.filter(func(emote: String) -> bool: return emote_unlocked(emote))


static func emote_unlocked(emote: String) -> bool:
	if emote in FREE_EMOTES or GameState.emotes_bought.has(emote):
		return true
	for id in LIST:
		if LIST[id].emote == emote and has(id):
			return true
	return false


## Earns one (once): saves, and shows a toast unless quiet.
static func earn(id: String, quiet := false) -> void:
	if has(id) or not LIST.has(id):
		return
	GameState.achievements[id] = true
	if quiet:
		return
	GameState.save_game()
	var info: Dictionary = LIST[id]
	Toast.show_on(GameState.get_tree(), "ACHIEVEMENT:  %s" % String(info.name).to_upper(),
			"%s   New emote: %s" % [info.desc, Emotes.name_of(info.emote)])


## What an older save had already done.
static func catch_up() -> void:
	if not GameState.hats.is_empty():
		earn("first_hat", true)
	if Hats.LEGENDARIES.any(func(hat: String) -> bool: return GameState.hats.has(hat)):
		earn("legendary_hat", true)
	if not GameState.dead_league_clears.is_empty():
		earn("first_contender", true)
	# Champions from before the Coffin Crown existed get it too.
	if GameState.dead_league_clears.get("coffin_king", false) and not GameState.hats.has("coffin_crown"):
		GameState.hats["coffin_crown"] = 1
		GameState.save_game()
	if GameState.crypt_floors_cleared > 0:
		earn("crypt_floor", true)
	if not GameState.drills.is_empty():
		earn("drill", true)
