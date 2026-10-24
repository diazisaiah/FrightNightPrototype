# Fright Night Playground

A separate Godot project for trying things fast: fighters, hats, every emote, any enemy (veterans, bosses, the Dead League contenders) at any tier, forced special moves, powers, arena themes, god mode and frozen enemies.

It runs the game's own code. `sync.py` mirrors `punch-craft/` into `playground/project/` (generated, not committed) and adds the playground's files from `src/`. The project has its own name, so it has **its own save**: your real save is never touched.

## Run it

- Windows: double-click `run_playground.bat` (add `-e` to open it in the Godot editor instead).
- Bash: `bash playground/run_playground.sh` (or `-e`).

Both sync first, so the playground always has the latest code. If Godot lives somewhere else, set `GODOT` to its console exe.

## In the playground

- **F1** shows or hides the panel. Click the ring to fight.
- **Fighter**: switches class (reloads the ring).
- **Hat**: wears any hat.
- **Emotes**: every dance, unlocked.
- **Spawn**: any enemy at tier 1-5, five at once, or clear them. Freeze enemies to inspect them.
- **Force a special**: makes the nearest boxer use any special move.
- **Power**: gives a whole power line and selects it.
- **Player**: god mode, fill the ultimate, +5 levels, replay the mini tutorials.
- **Ring**: untick it to take the ring down (ropes and walls) and roam free like the enemies.
- **Arena theme**: builds a division's backdrop around the ring.

Add tools by editing `src/playground.gd`.
