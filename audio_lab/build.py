"""Builds audio_lab/index.html: every game sound slot with its current synth
version beside suggested replacements, plus the full pack library.
Run from anywhere: python audio_lab/build.py"""
import json
import os

LAB = os.path.dirname(os.path.abspath(__file__))
I, U, R, V = "impact-sounds", "interface-sounds", "rpg-audio", "voiceover-pack-fighter"


def series(pack, stem, n=5, start=0, width=3):
    return [f"{pack}/{stem}{str(i).zfill(width)}.ogg" for i in range(start, start + n)]


# (slot, where the game uses it, suggestions)
SLOTS = [
    ("hit", "Light punch lands", series(I, "impactPunch_medium_")),
    ("heavy", "Heavy punch / haymaker lands", series(I, "impactPunch_heavy_")),
    ("counter", "Counter punch", series(I, "impactPunch_heavy_", 3) + series(I, "impactSoft_heavy_", 2)),
    ("block", "Punch hits a guard", series(I, "impactPlate_medium_", 3) + series(I, "impactSoft_medium_", 3)),
    ("whoosh", "Punch swing (miss)", [f"{R}/cloth{i}.ogg" for i in range(1, 5)] + [f"{R}/clothBelt.ogg", f"{R}/clothBelt2.ogg"]),
    ("slip", "Player slips/dodges", [f"{R}/cloth{i}.ogg" for i in range(1, 5)] + [f"{R}/knifeSlice.ogg"]),
    ("hurt", "Player gets hit", series(I, "impactSoft_medium_") + series(I, "impactPunch_medium_", 2)),
    ("death", "Enemy drops", series(I, "impactSoft_heavy_", 3) + series(I, "impactWood_heavy_", 3)),
    ("growl", "Monster growl", []),
    ("draw", "Bow draw / creak", [f"{R}/creak{i}.ogg" for i in range(1, 4)] + [f"{R}/drawKnife{i}.ogg" for i in range(1, 4)]),
    ("twang", "Arrow release", [f"{U}/pluck_001.ogg", f"{U}/pluck_002.ogg", f"{R}/metalClick.ogg"]),
    ("coin", "Silver / knuckles pickup", [f"{R}/handleCoins.ogg", f"{R}/handleCoins2.ogg"] + series(I, "impactGlass_light_", 3)),
    ("wave", "New wave gong", series(I, "impactBell_heavy_")),
    ("clear", "Wave cleared", [f"{U}/confirmation_00{i}.ogg" for i in range(1, 5)]),
    ("fire", "Fire attacks", []),
    ("zap", "Lightning / magic zap", [f"{U}/glitch_00{i}.ogg" for i in range(1, 5)]),
    ("quake", "Big stomp / boss slam", series(I, "impactWood_heavy_", 3) + series(I, "impactMining_", 3)),
    ("tell", "Enemy attack warning (also Tony's deli bell)", series(I, "impactBell_heavy_", 3) + series(I, "impactMetal_light_", 3)),
    ("heal", "Healing", []),
    ("tick", "Menu hover / tick", [f"{U}/tick_00{i}.ogg" for i in (1, 2, 4)] + [f"{U}/click_00{i}.ogg" for i in range(1, 6)]),
    ("unlock", "Unlock / popup open", [f"{U}/maximize_00{i}.ogg" for i in range(1, 7)] + [f"{U}/confirmation_00{i}.ogg" for i in (2, 4)]),
    ("deny", "Can't afford / denied", [f"{U}/error_00{i}.ogg" for i in range(1, 9)]),
    ("bell", "Boxing ring bell", series(I, "impactBell_heavy_")),
    ("bleep", "Tony's censor beep", []),
    ("wind", "Ambient wind loop", []),
]

ANNOUNCER = ["round_1", "round_2", "round_3", "final_round", "fight", "begin", "ready", "prepare_yourself",
             "combo", "combo_breaker", "flawless_victory", "winner", "you_win", "you_lose", "loser", "game_over",
             "sudden_death", "time", "choose_your_character", "survival_mode", "championship_mode",
             "1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]

library = {}
for pack in (I, U, R, V):
    library[pack] = sorted(os.listdir(os.path.join(LAB, "packs", pack)))

data = {
    "slots": [{"id": s, "use": u, "current": f"current/{s}.wav", "picks": [f"packs/{p}" for p in sug]} for s, u, sug in SLOTS],
    "announcer": [f"packs/{V}/{n}.ogg" for n in ANNOUNCER],
    "library": {k: [f"packs/{k}/{f}" for f in v] for k, v in library.items()},
}

with open(os.path.join(LAB, "template.html"), encoding="utf-8") as f:
    page = f.read().replace("/*DATA*/null", json.dumps(data))
with open(os.path.join(LAB, "index.html"), "w", encoding="utf-8") as f:
    f.write(page)
print("built", sum(len(v) for v in library.values()), "pack sounds,", len(SLOTS), "slots")

# The in-game Sound Lab (punch-craft/sound_lab.gd) reads the same suggestions.
with open(os.path.join(LAB, "slots.json"), "w", encoding="utf-8") as f:
    json.dump({s: [f"packs/{p}" for p in sug] for s, _, sug in SLOTS}, f, indent=1)
