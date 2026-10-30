# Fright Night Playground

A separate Godot project for trying things fast: fighters, hats, every emote, any enemy (veterans, bosses, the Dead League contenders) at any tier, forced special moves, powers, arena themes, god mode, frozen enemies, and the six-fighter third-person Character Lab.

It runs the game's own code. `sync.py` mirrors `punch-craft/` into `playground/project/` (generated, not committed) and adds the playground's files from `src/`. The project has its own name, so it has **its own save**: your real save is never touched.

## Run it

- Windows: double-click `run_playground.bat` (add `-e` to open it in the Godot editor instead).
- Bash: `bash playground/run_playground.sh` (or `-e`).

Both sync first, so the playground always has the latest code. Opening `playground/project` straight from the Godot editor works too: its Playground Sync plugin (`addon/`) runs `sync.py` every time you press Play. If Godot lives somewhere else, set `GODOT` to its console exe.

## In the playground

- **F1** shows or hides the panel. Click the ring to fight.
- **V** toggles persistent first/third-person play. Controller Share/Misc or PlayStation Touchpad does the same when available. Mouse wheel or `Page Up` / `Page Down` zooms the test camera; right stick or right-drag orbits in inspect mode.
- **Fighter**: switches class (reloads the ring).
- **Hat**: wears any hat.
- **Emotes**: every dance, unlocked.
- **Hand idles**: every fighter's idle and every shop idle. Tick **Loop the last one** to keep replaying it. Click one to play it on your hands now; it's equipped too if this fighter can wear it (shop idles are all unlocked; another fighter's own idle just plays).
- **Character Lab**: inspect the current fighter and skin, orbit/zoom the camera, preview 50 locomotion/combat/damage/knockdown/ultimate states, compare approved reference art, review live first-person glove poses, capture four views, and spawn three command-driven remote avatars. Fighter changes reload only the isolated playground; skin changes update the body and production hands live without resetting the rig or clip.
- **Body revamp (the Answer)**: in the Character Lab section, **Body** swaps the Answer to the revamp prototype (`character_lab/revamp_body.gd`: clean large voxels, hair in zones, hat fit profiles, ankle pivots) for third-person play; **Voxel scale comparison** opens a side-by-side stage (views, any lab pose held or looping, test hats, silhouette, the tiny-cube version and the current body as options, capture). `-- --capture` on `voxel_compare.tscn` saves the review shots.
- **Spawn**: any enemy at tier 1-5, as a normal monster, an elite or a champion. Spawn five at once, or clear them. Freeze enemies to inspect them.
- **Dead League**: True Coffin King maxes the current fighter (web, level 51, every card at full rank, every attribute, every contender beaten) and starts his fight. Leaving the fight comes back to the playground.
- **Force a special**: makes the nearest boxer use any special move.
- **Power**: gives a whole power line and selects it.
- **Player**: god mode, fill the ultimate, +5 levels, replay the mini tutorials.
- **Ring**: untick it to take the ring down (ropes and walls) and roam free like the enemies.
- **Arena theme**: builds a division's backdrop around the ring.

Character Lab architecture, controls, fidelity matrix, measured four-avatar performance, tests, limitations, and production-migration boundary are documented in `src/character_lab/README.md`. Add general tools in `src/playground.gd`; keep character presentation modules in `src/character_lab/`.
